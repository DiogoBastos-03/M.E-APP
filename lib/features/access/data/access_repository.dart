import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../doctors/data/doctor_models.dart';
import 'access_models.dart';

/// Acesso às rotas de consentimento/auditoria do backend.
class AccessRepository {
  AccessRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  List<Map<String, dynamic>> _list(Response r) =>
      (r.data as List).cast<Map<String, dynamic>>();

  Future<List<AccessGrant>> getPending() async {
    final r = await _dio.get('$_p/access-requests/pending');
    return _list(r).map(AccessGrant.fromJson).toList();
  }

  Future<List<AccessGrant>> getMyGrants() async {
    final r = await _dio.get('$_p/access-grants/my');
    return _list(r).map(AccessGrant.fromJson).toList();
  }

  Future<List<RecordAccessLog>> getLogs({int limit = 200}) async {
    final r = await _dio.get('$_p/access-logs/my', queryParameters: {'limit': limit});
    return _list(r).map(RecordAccessLog.fromJson).toList();
  }

  static const int _directoryPageSize = 50;
  static const int _directoryMaxPages = 5;

  Future<List<DoctorListItem>> getDoctors() async {
    final all = <DoctorListItem>[];
    for (var page = 0; page < _directoryMaxPages; page++) {
      final r = await _dio.get('$_p/doctors', queryParameters: {
        'page': page,
        'size': _directoryPageSize,
      });
      final result = DoctorPage.fromJson(r.data as Map<String, dynamic>);
      all.addAll(result.content);
      if (!result.hasNext) break;
    }
    return all;
  }

  Future<List<ClinicLite>> getClinics() async {
    final r = await _dio.get('$_p/clinics');
    return _list(r).map(ClinicLite.fromJson).toList();
  }

  /// Aprova um pedido. Sem [sections] => aprova tudo o que foi solicitado.
  /// Com [sections] => aprovação parcial. [expiresAt] define o prazo (null = sem prazo).
  Future<AccessGrant> approve(
    String accessId, {
    List<RecordSection>? sections,
    DateTime? expiresAt,
  }) async {
    final body = <String, dynamic>{};
    if (sections != null) body['sections'] = sections.map((s) => s.wire).toList();
    if (expiresAt != null) body['expiresAt'] = _iso(expiresAt);
    final r = await _dio.patch('$_p/access-requests/$accessId/approve',
        data: body.isEmpty ? null : body);
    return AccessGrant.fromJson(r.data as Map<String, dynamic>);
  }

  Future<AccessGrant> deny(String accessId) async {
    final r = await _dio.patch('$_p/access-requests/$accessId/deny');
    return AccessGrant.fromJson(r.data as Map<String, dynamic>);
  }

  Future<AccessGrant> revoke(String accessId) async {
    final r = await _dio.patch('$_p/access-grants/$accessId/revoke');
    return AccessGrant.fromJson(r.data as Map<String, dynamic>);
  }

  String _iso(DateTime dt) => dt.toUtc().toIso8601String();
}
