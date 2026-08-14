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
3. Com --signing, configura a assinatura de release lendo android/key.properties
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

# compileSdk minimo exigido pelos plugins do projeto. O template do Flutter usa
# flutter.compileSdkVersion (36 hoje), mas flutter_secure_storage 11 exige 37 e
# o build falha em :app:checkReleaseAarMetadata sem esse ajuste.
DEFAULT_COMPILE_SDK = 37

INTERNET_PERMISSION = '    <uses-permission android:name="android.permission.INTERNET"/>'

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


def log(message: str) -> None:
    print(f"[prepare_android] {message}")


def fail(message: str) -> None:
    print(f"::error::{message}", file=sys.stderr)
    sys.exit(1)


def ensure_internet_permission() -> None:
    if not MANIFEST.exists():
        fail(f"AndroidManifest.xml não encontrado em {MANIFEST.relative_to(ROOT)}")

    text = MANIFEST.read_text(encoding="utf-8")
    if "android.permission.INTERNET" in text:
        log("permissão INTERNET já declarada no manifest principal.")
        return

    patched, count = re.subn(
        r"(<manifest\b[^>]*>)",
        lambda m: f"{m.group(1)}\n{INTERNET_PERMISSION}",
        text,
        count=1,
    )
    if count == 0:
        fail("não foi possível localizar a tag <manifest> para inserir a permissão INTERNET.")

    MANIFEST.write_text(patched, encoding="utf-8")
    log("permissão INTERNET adicionada ao manifest principal.")


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

    ensure_internet_permission()
    ensure_compile_sdk(args.compile_sdk)

    if args.signing:
        configure_signing()
    else:
        log("sem --signing: release usará a chave debug do template Flutter.")


if __name__ == "__main__":
    main()
