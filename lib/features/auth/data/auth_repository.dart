import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'auth_models.dart';

/// Acesso às rotas de autenticação do backend.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;
  Dio get _dio => _api.dio;

  /// POST /api/v1/auth/login  {email, password}
  Future<AuthResponse> login(String email, String password) async {
    final res = await _dio.post(
      '${AppConfig.apiPrefix}/auth/login',
      data: {'email': email, 'password': password},
    );
    return AuthResponse.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /api/v1/auth/logout  {refreshToken}
  Future<void> logout(String refreshToken) async {
    await _dio.post(
      '${AppConfig.apiPrefix}/auth/logout',
      data: {'refreshToken': refreshToken},
    );
  }
}
