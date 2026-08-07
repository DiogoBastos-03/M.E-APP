/// Configuração global do app.
///
/// A URL base da API é configurável: por padrão aponta para o backend local
/// (http://localhost:8080). Pode ser sobrescrita em tempo de build com:
///   flutter run --dart-define=API_BASE_URL=http://192.168.0.10:8080
class AppConfig {
  AppConfig._();

  /// URL base do backend M.E-API.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Prefixo comum das rotas da API.
  static const String apiPrefix = '/api/v1';

  // --- Auxílios de DEV (desligados por padrão; produção não é afetada) ---
  // Quando DEV_AUTOLOGIN=true, o app faz login automático no backend real ao
  // iniciar, usando DEV_EMAIL/DEV_PASSWORD. Útil para demonstrar/testar a casca
  // sem depender de digitação. Nunca ligado em builds normais.
  static const bool devAutoLogin =
      bool.fromEnvironment('DEV_AUTOLOGIN', defaultValue: false);
  static const String devEmail =
      String.fromEnvironment('DEV_EMAIL', defaultValue: '');
  static const String devPassword =
      String.fromEnvironment('DEV_PASSWORD', defaultValue: '');
}
