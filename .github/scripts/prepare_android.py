#!/usr/bin/env python3
"""Prepara a pasta android/ para um build de APK no CI.

O script é idempotente e funciona tanto sobre um android/ recém-criado por
`flutter create` quanto sobre um android/ versionado no repositório.

1. Garante a permissão INTERNET no AndroidManifest.xml principal. O template do
   Flutter declara essa permissão apenas nos manifests de debug/profile, então
   um APK de release sem esse ajuste instala normalmente mas falha em toda
   chamada à API.
2. Eleva o compileSdk quando algum plugin exige mais que o padrão do template
   (flutter_secure_storage 11 exige 37; o template compila contra 36).
3. Eleva o compileSdk também nos módulos dos plugins (o jitsi_meet_flutter_sdk
   fixa 34, mas as dependências dele exigem 35+).
4. Escreve as regras de ProGuard que o R8 precisa para minificar o release com
   o SDK do Jitsi no classpath.
5. Com --signing, configura a assinatura de release lendo android/key.properties
   (escrito pelo workflow a partir dos secrets). Sem a flag, o release continua
   assinado com a chave debug, que é o padrão do template.

Uso:
    python3 .github/scripts/prepare_android.py [--compile-sdk 37] [--signing]
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "android" / "app" / "src" / "main" / "AndroidManifest.xml"
GRADLE_KTS = ROOT / "android" / "app" / "build.gradle.kts"
GRADLE_GROOVY = ROOT / "android" / "app" / "build.gradle"
GRADLE_PROPERTIES = ROOT / "android" / "gradle.properties"
ROOT_GRADLE_KTS = ROOT / "android" / "build.gradle.kts"
ROOT_GRADLE_GROOVY = ROOT / "android" / "build.gradle"
PROGUARD_RULES = ROOT / "android" / "app" / "proguard-rules.pro"

# API 26 e o minimo exigido pelo SDK do Jitsi (jitsi-meet-sdk 13.x). Abaixo
# disso o merge de manifest aborta em :app:processReleaseMainManifest.
MIN_SDK = 26

# compileSdk minimo exigido pelos plugins do projeto. O template do Flutter usa
# flutter.compileSdkVersion (36 hoje), mas flutter_secure_storage 11 exige 37 e
# o build falha em :app:checkReleaseAarMetadata sem esse ajuste.
DEFAULT_COMPILE_SDK = 37

INTERNET_PERMISSION = '    <uses-permission android:name="android.permission.INTERNET"/>'

# O SDK do Jitsi precisa de camera e microfone para a teleconsulta.
PERMISSIONS = (
    "android.permission.INTERNET",
    "android.permission.CAMERA",
    "android.permission.RECORD_AUDIO",
    "android.permission.MODIFY_AUDIO_SETTINGS",
)
TOOLS_NAMESPACE = 'xmlns:tools="http://schemas.android.com/tools"'

LOADER_KTS = """
// [CI] Assinatura de release lida de android/key.properties (ver .github/workflows/build-apk.yml).
val meKeystoreProperties = java.util.Properties()
val meKeystorePropertiesFile = rootProject.file("key.properties")
if (meKeystorePropertiesFile.exists()) {
    meKeystorePropertiesFile.inputStream().use { meKeystoreProperties.load(it) }
}
"""

SIGNING_KTS = """
    signingConfigs {
        create("release") {
            keyAlias = meKeystoreProperties.getProperty("keyAlias")
            keyPassword = meKeystoreProperties.getProperty("keyPassword")
            storeFile = meKeystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = meKeystoreProperties.getProperty("storePassword")
        }
    }
"""

LOADER_GROOVY = """
// [CI] Assinatura de release lida de android/key.properties (ver .github/workflows/build-apk.yml).
def meKeystoreProperties = new Properties()
def meKeystorePropertiesFile = rootProject.file('key.properties')
if (meKeystorePropertiesFile.exists()) {
    meKeystorePropertiesFile.withInputStream { meKeystoreProperties.load(it) }
}
"""

SIGNING_GROOVY = """
    signingConfigs {
        release {
            keyAlias meKeystoreProperties['keyAlias']
            keyPassword meKeystoreProperties['keyPassword']
            storeFile meKeystoreProperties['storeFile'] ? file(meKeystoreProperties['storeFile']) : null
            storePassword meKeystoreProperties['storePassword']
        }
    }
"""


# Marcador de idempotencia: se ja estiver no arquivo, o bloco nao e reinjetado.
SUBPROJECTS_MARKER = "[CI] compileSdk dos plugins"

SUBPROJECTS_KTS = """
// [CI] compileSdk dos plugins. O jitsi_meet_flutter_sdk fixa compileSdk 34, mas
// as dependencias dele (androidx.media3 1.8, androidx.core 1.16) exigem 35+ e o
// build morre em :jitsi_meet_flutter_sdk:checkReleaseAarMetadata. O ajuste feito
// em app/build.gradle.kts nao alcanca os modulos dos plugins, entao e aqui que
// ele precisa ser aplicado.
subprojects {
    afterEvaluate {
        val meAndroid = extensions.findByName("android") ?: return@afterEvaluate
        // O setter muda entre versoes do AGP; tenta os conhecidos, em ordem.
        val meSetters: List<() -> Unit> = listOf(
            { meAndroid.javaClass.getMethod("setCompileSdk", Integer::class.java)
                .invoke(meAndroid, __COMPILE_SDK__) },
            { meAndroid.javaClass.getMethod("setCompileSdkVersion", String::class.java)
                .invoke(meAndroid, "android-__COMPILE_SDK__") },
            { meAndroid.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType!!)
                .invoke(meAndroid, __COMPILE_SDK__) },
        )
        for (meSetter in meSetters) {
            try {
                meSetter()
                break
            } catch (_: Exception) {
                // Setter inexistente nesta versao do AGP - tenta o proximo.
            }
        }
    }
}
"""

SUBPROJECTS_GROOVY = """
// [CI] compileSdk dos plugins. O jitsi_meet_flutter_sdk fixa compileSdk 34, mas
// as dependencias dele (androidx.media3 1.8, androidx.core 1.16) exigem 35+ e o
// build morre em :jitsi_meet_flutter_sdk:checkReleaseAarMetadata.
subprojects {
    afterEvaluate { meProject ->
        if (meProject.extensions.findByName('android') != null) {
            meProject.android.compileSdkVersion __COMPILE_SDK__
        }
    }
}
"""

PROGUARD_MARKER = "# [CI] Regras do R8 para o SDK do Jitsi"

PROGUARD_BODY = """
# [CI] Regras do R8 para o SDK do Jitsi (ver .github/scripts/prepare_android.py).
# O SDK do Giphy, que entra como dependencia do Jitsi, referencia
# kotlinx.parcelize.Parcelize sem trazer a anotacao no classpath. O R8 trata
# classe ausente como erro e aborta :app:minifyReleaseWithR8.
-dontwarn kotlinx.parcelize.**
-dontwarn com.giphy.sdk.**

# Jitsi e a camada React Native embaixo dele carregam classes por reflexao; sem
# estes keeps o APK compila mas quebra em runtime ao abrir a teleconsulta.
-keep class org.jitsi.meet.** { *; }
-keep class org.webrtc.** { *; }
-keep class com.facebook.react.** { *; }
"""


def log(message: str) -> None:
    print(f"[prepare_android] {message}")


def fail(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)
    sys.exit(1)


def ensure_permissions() -> None:
    """Declara no manifest as permissoes que o app precisa em runtime.

    A pasta android/ e gerada pelo `flutter create` a cada build, entao o
    manifest volta ao template e estas permissoes tem de ser reinjetadas aqui.
    """
    if not MANIFEST.exists():
        fail(f"AndroidManifest.xml não encontrado em {MANIFEST.relative_to(ROOT)}")

    text = MANIFEST.read_text(encoding="utf-8")
    added = []

    for permission in PERMISSIONS:
        if permission in text:
            continue
        line = f'    <uses-permission android:name="{permission}"/>'
        text, count = re.subn(
            r"(<manifest\b[^>]*>)",
            lambda m: f"{m.group(1)}\n{line}",
            text,
            count=1,
        )
        if count == 0:
            fail("não foi possível localizar a tag <manifest> para inserir as permissões.")
        added.append(permission.rsplit(".", 1)[-1])

    MANIFEST.write_text(text, encoding="utf-8")
    if added:
        log(f"permissões adicionadas ao manifest: {', '.join(added)}.")
    else:
        log("permissões já declaradas no manifest principal.")


def ensure_manifest_label_override() -> None:
    """Resolve o conflito de android:label entre o app e o AAR do Jitsi.

    O SDK do Jitsi declara android:label no seu <application>. Sem
    tools:replace o merge de manifest aborta o build com
    "Attribute application@label value=... is also present at ...".
    """
    text = MANIFEST.read_text(encoding="utf-8")

    if TOOLS_NAMESPACE not in text:
        text, count = re.subn(
            r"(<manifest\b)",
            lambda m: f"{m.group(1)} {TOOLS_NAMESPACE}",
            text,
            count=1,
        )
        if count == 0:
            fail("não foi possível declarar o namespace tools no manifest.")

    if 'tools:replace="android:label"' not in text:
        match = re.search(r"<application\b", text)
        if match is None:
            fail("tag <application> não encontrada no manifest.")
        text, count = re.subn(
            r"(<application\b)",
            lambda m: f'{m.group(1)} tools:replace="android:label"',
            text,
            count=1,
        )
        if count == 0:
            fail("não foi possível aplicar tools:replace no <application>.")
        MANIFEST.write_text(text, encoding="utf-8")
        log("tools:replace=\"android:label\" aplicado ao <application>.")
        return

    MANIFEST.write_text(text, encoding="utf-8")
    log("tools:replace já presente no <application>.")


def ensure_min_sdk(min_sdk: int) -> None:
    """Eleva o minSdk do modulo app. O SDK do Jitsi exige API 26."""
    if GRADLE_KTS.exists():
        gradle_file = GRADLE_KTS
        pattern = r"minSdk\s*=\s*(?P<val>flutter\.minSdkVersion|\d+)"
        replacement = f"minSdk = {min_sdk}"
    elif GRADLE_GROOVY.exists():
        gradle_file = GRADLE_GROOVY
        pattern = r"minSdk(?:Version)?\s+(?P<val>flutter\.minSdkVersion|\d+)"
        replacement = f"minSdk {min_sdk}"
    else:
        fail("nenhum build.gradle(.kts) encontrado em android/app/.")

    text = gradle_file.read_text(encoding="utf-8")
    match = re.search(pattern, text)
    if match is None:
        fail(f"declaracao de minSdk nao encontrada em {gradle_file.name}.")

    current = match.group("val")
    if current.isdigit() and int(current) >= min_sdk:
        log(f"minSdk ja e {current} (>= {min_sdk}) — mantido.")
        return

    gradle_file.write_text(text[: match.start()] + replacement + text[match.end() :], encoding="utf-8")
    log(f"minSdk elevado de {current} para {min_sdk} em {gradle_file.name}.")


def ensure_compile_sdk(min_sdk: int) -> None:
    """Eleva o compileSdk do modulo app para pelo menos `min_sdk`.

    O template do Flutter usa `compileSdk = flutter.compileSdkVersion`, que hoje
    resolve para 36. flutter_secure_storage 11 exige 37 e o Gradle aborta em
    :app:checkReleaseAarMetadata. targetSdk e minSdk continuam vindo do Flutter:
    compileSdk so define contra quais APIs o codigo compila.
    """
    if GRADLE_KTS.exists():
        gradle_file = GRADLE_KTS
        pattern = r"compileSdk\s*=\s*(?P<val>flutter\.compileSdkVersion|\d+)"
        replacement = f"compileSdk = {min_sdk}"
    elif GRADLE_GROOVY.exists():
        gradle_file = GRADLE_GROOVY
        pattern = r"compileSdk(?:Version)?\s+(?P<val>flutter\.compileSdkVersion|\d+)"
        replacement = f"compileSdk {min_sdk}"
    else:
        fail("nenhum build.gradle(.kts) encontrado em android/app/.")

    text = gradle_file.read_text(encoding="utf-8")
    match = re.search(pattern, text)
    if match is None:
        fail(f"declaracao de compileSdk nao encontrada em {gradle_file.name}.")

    current = match.group("val")
    if current.isdigit() and int(current) >= min_sdk:
        log(f"compileSdk ja e {current} (>= {min_sdk}) — mantido.")
        return

    gradle_file.write_text(text[: match.start()] + replacement + text[match.end() :], encoding="utf-8")
    log(f"compileSdk elevado de {current} para {min_sdk} em {gradle_file.name}.")

    # O AGP avisa quando o compileSdk e mais novo que o maximo que ele conhece.
    # E so um aviso, mas polui o log do build; a flag abaixo o silencia.
    suppress_key = "android.suppressUnsupportedCompileSdk"
    properties = GRADLE_PROPERTIES.read_text(encoding="utf-8") if GRADLE_PROPERTIES.exists() else ""
    if suppress_key not in properties:
        if properties and not properties.endswith("\n"):
            properties += "\n"
        properties += f"{suppress_key}={min_sdk}\n"
        GRADLE_PROPERTIES.write_text(properties, encoding="utf-8")
        log(f"{suppress_key}={min_sdk} adicionado a gradle.properties.")


def ensure_subprojects_compile_sdk(compile_sdk: int) -> None:
    """Eleva o compileSdk de todos os modulos, nao so o do app.

    Cada plugin Flutter traz o proprio build.gradle dentro do .pub-cache, com o
    compileSdk fixo. O jitsi_meet_flutter_sdk usa 34, e as dependencias dele
    exigem 35+, entao o build falha em checkReleaseAarMetadata do modulo do
    plugin. Como o .pub-cache e recriado a cada build, a correcao vai no
    build.gradle raiz do android/, que alcanca todos os subprojetos.
    """
    if ROOT_GRADLE_KTS.exists():
        gradle_file, block = ROOT_GRADLE_KTS, SUBPROJECTS_KTS
    elif ROOT_GRADLE_GROOVY.exists():
        gradle_file, block = ROOT_GRADLE_GROOVY, SUBPROJECTS_GROOVY
    else:
        fail("nenhum build.gradle(.kts) encontrado na raiz de android/.")

    text = gradle_file.read_text(encoding="utf-8")
    if SUBPROJECTS_MARKER in text:
        log(f"compileSdk dos plugins ja forcado em {gradle_file.name} — mantido.")
        return

    if text and not text.endswith("\n"):
        text += "\n"
    text += block.replace("__COMPILE_SDK__", str(compile_sdk))
    gradle_file.write_text(text, encoding="utf-8")
    log(f"compileSdk dos plugins forcado para {compile_sdk} em {gradle_file.name}.")


def ensure_proguard_rules() -> None:
    """Escreve proguard-rules.pro e liga o arquivo ao buildType release.

    O release roda o R8, que aborta ao encontrar referencia a uma classe ausente
    (kotlinx.parcelize.Parcelize, vinda do SDK do Giphy que o Jitsi carrega).
    """
    if PROGUARD_RULES.exists():
        rules = PROGUARD_RULES.read_text(encoding="utf-8")
    else:
        rules = ""

    if PROGUARD_MARKER in rules:
        log("proguard-rules.pro ja contem as regras do Jitsi — mantido.")
    else:
        if rules and not rules.endswith("\n"):
            rules += "\n"
        PROGUARD_RULES.write_text(rules + PROGUARD_BODY, encoding="utf-8")
        log("regras do R8 escritas em app/proguard-rules.pro.")

    if GRADLE_KTS.exists():
        gradle_file = GRADLE_KTS
        line = '            proguardFiles("proguard-rules.pro")'
    elif GRADLE_GROOVY.exists():
        gradle_file = GRADLE_GROOVY
        line = "            proguardFiles 'proguard-rules.pro'"
    else:
        fail("nenhum build.gradle(.kts) encontrado em android/app/.")

    text = gradle_file.read_text(encoding="utf-8")
    if "proguard-rules.pro" in text:
        log(f"{gradle_file.name} ja referencia proguard-rules.pro — mantido.")
        return

    # O template declara `buildTypes { release { ... } }`; a forma
    # `getByName("release")` aparece em projetos ja customizados.
    pattern = r"buildTypes\s*\{\s*(?:getByName\(\s*\"release\"\s*\)|release)\s*\{"
    match = re.search(pattern, text)
    if match is None:
        fail(f"buildType release nao encontrado em {gradle_file.name}.")

    text = text[: match.end()] + "\n" + line + text[match.end() :]
    gradle_file.write_text(text, encoding="utf-8")
    log(f"proguard-rules.pro ligado ao buildType release em {gradle_file.name}.")


def configure_signing() -> None:
    if GRADLE_KTS.exists():
        gradle_file, loader, signing = GRADLE_KTS, LOADER_KTS, SIGNING_KTS
        debug_ref = 'signingConfigs.getByName("debug")'
        release_ref = 'signingConfigs.getByName("release")'
    elif GRADLE_GROOVY.exists():
        gradle_file, loader, signing = GRADLE_GROOVY, LOADER_GROOVY, SIGNING_GROOVY
        debug_ref = "signingConfigs.debug"
        release_ref = "signingConfigs.release"
    else:
        fail("nenhum build.gradle(.kts) encontrado em android/app/.")

    text = gradle_file.read_text(encoding="utf-8")

    if "key.properties" in text:
        log(f"{gradle_file.name} já lê key.properties — assinatura preservada como está.")
        return

    loader_block = loader.strip()
    signing_block = signing.strip("\n")

    patched, count = re.subn(
        r"^android\s*\{",
        lambda m: loader_block + "\n\n" + m.group(0) + "\n" + signing_block,
        text,
        count=1,
        flags=re.MULTILINE,
    )
    if count == 0:
        fail("bloco `android {` nao encontrado em " + gradle_file.name + ".")

    if debug_ref in patched:
        patched = patched.replace(debug_ref, release_ref, 1)
        log("buildType release apontado para a signingConfig release.")
    else:
        print(
            "::warning::não encontrei a referência à signingConfig debug no buildType release; "
            "confira manualmente se o APK saiu assinado com o keystore.",
            file=sys.stderr,
        )

    gradle_file.write_text(patched, encoding="utf-8")
    log(f"assinatura de release configurada em {gradle_file.name}.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--compile-sdk",
        type=int,
        default=DEFAULT_COMPILE_SDK,
        help=f"compileSdk minimo do modulo app (padrao: {DEFAULT_COMPILE_SDK})",
    )
    parser.add_argument(
        "--signing",
        action="store_true",
        help="configura a assinatura de release a partir de android/key.properties",
    )
    args = parser.parse_args()

    if not (ROOT / "android").is_dir():
        fail("pasta android/ não existe — rode `flutter create --platforms=android .` antes.")

    ensure_permissions()
    ensure_manifest_label_override()
    ensure_min_sdk(MIN_SDK)
    ensure_compile_sdk(args.compile_sdk)
    ensure_subprojects_compile_sdk(args.compile_sdk)
    ensure_proguard_rules()

    if args.signing:
        configure_signing()
    else:
        log("sem --signing: release usará a chave debug do template Flutter.")


if __name__ == "__main__":
    main()
