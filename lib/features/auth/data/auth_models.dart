/// Resposta do backend em /auth/login, /auth/login/2fa e /auth/refresh.
/// Espelha o schema `AuthResponse` do OpenAPI.
class AuthResponse {
  const AuthResponse({
    this.token,
    this.refreshToken,
    this.type = 'Bearer',
    this.twoFactorRequired = false,
    this.challengeToken,
  });

  final String? token;
  final String? refreshToken;
  final String type;
  final bool twoFactorRequired;
  final String? challengeToken;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String?,
      refreshToken: json['refreshToken'] as String?,
      type: (json['type'] as String?) ?? 'Bearer',
      twoFactorRequired: (json['twoFactorRequired'] as bool?) ?? false,
      challengeToken: json['challengeToken'] as String?,
    );
  }
}
