# me_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## CI — build do APK

O workflow [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml) gera o APK Android.

**Quando roda:** push e PR na `main`, tags `v*` e manualmente em *Actions → Build APK → Run workflow*.

**Onde baixar:** na página da execução, seção **Artifacts** (retidos por 30 dias). Em tags `v*`, o APK também é anexado ao GitHub Release.

O artefato sai como `me-app-release-v1.0.0-build<n>-<sha>.apk`, com `versionCode` igual ao número da execução.

### Configuração embutida

A URL da API entra via `--dart-define=API_BASE_URL`, com default `https://api.mesaude.com`. Para gerar um APK apontando para outro ambiente, use o *Run workflow* manual e preencha o campo `api_base_url` (ou o campo `build_mode` para um APK de debug).

### Plataforma Android

O repositório ainda não versiona a pasta `android/` — o workflow a gera com `flutter create --platforms=android --org com.medev` a cada execução, resultando no `applicationId` `com.medev.me_app` (espelhando o bundle id do iOS). Quando quiser customizar ícone, permissões ou o `applicationId`, gere e commite a pasta uma vez:

```bash
flutter create --platforms=android --org com.medev --project-name me_app .
git add android && git commit -m "chore: adiciona plataforma Android"
```

O workflow detecta a pasta versionada e passa a usá-la como está.

Em ambos os casos, [`.github/scripts/prepare_android.py`](.github/scripts/prepare_android.py) aplica dois ajustes sobre a pasta:

- **Permissão `INTERNET`** no manifest principal — o template do Flutter só a declara em debug/profile, então sem isso o APK de release instala mas falha em toda chamada à API.
- **`compileSdk`** elevado para o valor de `ANDROID_COMPILE_SDK` (hoje `37`), definido no topo do workflow. O template compila contra o SDK 36, mas `flutter_secure_storage` exige 37 e o Gradle aborta em `:app:checkReleaseAarMetadata`. Quando algum plugin passar a pedir mais, suba esse número — `minSdk` e `targetSdk` continuam vindo do Flutter.

### Assinatura

Por padrão o release é assinado com a chave debug: o APK instala e roda, mas não serve para publicar na Play Store. Para assinar com o keystore de produção, cadastre os secrets abaixo e o workflow passa a usá-los automaticamente:

| Secret | Conteúdo |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore `.jks` em base64 (`base64 -w0 me-release.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | senha do keystore |
| `ANDROID_KEY_ALIAS` | alias da chave |
| `ANDROID_KEY_PASSWORD` | senha da chave |

