import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'teleconsult_models.dart';

class TeleconsultRepository {
  TeleconsultRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  Future<Teleconsultation> get(String appointmentId) async {
    final r = await _dio.get('$_p/appointments/$appointmentId/teleconsultation');
    return Teleconsultation.fromJson(r.data as Map<String, dynamic>);
  }
}
