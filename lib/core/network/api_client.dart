import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/token_storage.dart';

/// Cliente HTTP central do app.
///
/// - Aponta para [AppConfig.apiBaseUrl] (configurável).
/// - Injeta `Authorization: Bearer <token>` em todas as chamadas autenticadas.
/// - Em respostas 401, tenta renovar o token via POST /auth/refresh (uma vez),
///   e refaz a requisição original. Se a renovação falhar, dispara
///   [onSessionExpired] (logout) e propaga o erro.
class ApiClient {
  ApiClient({
    required this.storage,
    required this.onSessionExpired,
  }) {
    dio = Dio(_baseOptions());
    _refreshDio = Dio(_baseOptions()); // sem interceptor, evita recursão
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onError: _onError,
      ),
    );
  }

  final TokenStorage storage;
  final void Function() onSessionExpired;

  late final Dio dio;
  late final Dio _refreshDio;

  Future<bool>? _refreshing; // trava contra refresh concorrente

  BaseOptions _baseOptions() => BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        contentType: 'application/json',
        // Não lançar em 401/422 automaticamente? Mantemos padrão (lança) e
        // tratamos no onError.
      );

  bool _isAuthPath(String path) {
    return path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/logout');
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isAuthPath(options.path)) {
      final token = await storage.accessToken;
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final requestOptions = err.requestOptions;

    final isUnauthorized = response?.statusCode == 401;
    final alreadyRetried = requestOptions.extra['__retried__'] == true;

    // Só tenta refresh em 401 de rotas protegidas, uma única vez.
    if (isUnauthorized && !alreadyRetried && !_isAuthPath(requestOptions.path)) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        try {
          final newToken = await storage.accessToken;
          final opts = requestOptions;
          opts.extra['__retried__'] = true;
          opts.headers['Authorization'] = 'Bearer $newToken';
          final clone = await dio.fetch(opts);
          return handler.resolve(clone);
        } catch (e) {
          // cai para o tratamento padrão abaixo
        }
      } else {
        onSessionExpired();
      }
    }

    handler.next(err);
  }

  /// Renova o token. Serializa chamadas concorrentes numa única promise.
  Future<bool> _tryRefresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final refresh = await storage.refreshToken;
    if (refresh == null || refresh.isEmpty) return false;
    try {
      final res = await _refreshDio.post(
        '${AppConfig.apiPrefix}/auth/refresh',
        data: {'refreshToken': refresh},
      );
      final data = res.data as Map<String, dynamic>;
      final newAccess = data['token'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null || newAccess.isEmpty) return false;
      await storage.saveTokens(
        accessToken: newAccess,
        refreshToken: newRefresh ?? refresh,
      );
      return true;
    } on DioException {
      await storage.clear();
      return false;
    }
  }
}
