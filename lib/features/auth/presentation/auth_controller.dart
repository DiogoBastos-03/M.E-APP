import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Estado de autenticação do app. Monta a pilha de rede (ApiClient +
/// AuthRepository) e expõe login/logout. Notifica a UI a cada mudança.
class AuthController extends ChangeNotifier {
  AuthController() {
    storage = TokenStorage();
    api = ApiClient(storage: storage, onSessionExpired: _handleSessionExpired);
    repo = AuthRepository(api);
  }

  late final TokenStorage storage;
  late final ApiClient api;
  late final AuthRepository repo;

  AuthStatus status = AuthStatus.unknown;
  bool loading = false;
  String? errorMessage;

  /// Guardado só para exibir na UI de teste (confirma que veio token do back).
  String? lastAccessTokenPreview;

  /// Verifica se já há sessão salva ao abrir o app.
  Future<void> bootstrap() async {
    final has = await storage.hasSession;
    if (has) {
      final t = await storage.accessToken;
      lastAccessTokenPreview = _preview(t);
      status = AuthStatus.authenticated;
      notifyListeners();
      return;
    }

    // Auxílio de DEV: login automático no backend real (desligado por padrão).
    if (AppConfig.devAutoLogin && AppConfig.devEmail.isNotEmpty) {
      await login(AppConfig.devEmail, AppConfig.devPassword);
      return;
    }

    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final res = await repo.login(email.trim(), password);

      if (res.twoFactorRequired) {
        errorMessage =
            'Esta conta tem verificação em duas etapas (2FA), ainda não '
            'suportada nesta versão do app.';
        return false;
      }
      if (res.token == null || res.refreshToken == null) {
        errorMessage = 'Resposta de login inválida do servidor.';
        return false;
      }

      await storage.saveTokens(
        accessToken: res.token!,
        refreshToken: res.refreshToken!,
      );
      lastAccessTokenPreview = _preview(res.token);
      status = AuthStatus.authenticated;
      return true;
    } on DioException catch (e) {
      errorMessage = _mapDioError(e);
      return false;
    } catch (e) {
      errorMessage = 'Erro inesperado ao entrar. Tente novamente.';
      return false;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      final rt = await storage.refreshToken;
      if (rt != null && rt.isNotEmpty) {
        await repo.logout(rt);
      }
    } catch (_) {
      // logout local mesmo que a chamada remota falhe
    }
    await storage.clear();
    lastAccessTokenPreview = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _handleSessionExpired() {
    storage.clear();
    lastAccessTokenPreview = null;
    status = AuthStatus.unauthenticated;
    errorMessage = 'Sua sessão expirou. Entre novamente.';
    notifyListeners();
  }

  String _preview(String? token) {
    if (token == null || token.isEmpty) return '';
    if (token.length <= 24) return token;
    return '${token.substring(0, 18)}…${token.substring(token.length - 6)}';
  }

  String _mapDioError(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401) {
      return 'E-mail ou senha incorretos.';
    }
    if (code == 400 || code == 422) {
      final msg = _extractMessage(e.response?.data);
      return msg ?? 'Dados inválidos. Verifique e tente novamente.';
    }
    if (code == 429) {
      return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Não foi possível conectar ao servidor. Ele está no ar em '
          '${e.requestOptions.baseUrl}?';
    }
    return 'Falha ao entrar (${code ?? e.type.name}).';
  }

  String? _extractMessage(dynamic data) {
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    return null;
  }
}
