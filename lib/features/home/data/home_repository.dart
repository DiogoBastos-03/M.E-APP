import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'home_models.dart';

/// Endpoints usados pela aba Início específicos (perfil + consultas).
/// Pedidos/concessões/auditoria são reaproveitados do AccessController.
class HomeRepository {
  HomeRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  Future<PatientProfile> getPatient() async {
    final r = await _dio.get('$_p/patients/me');
    return PatientProfile.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<Appointment>> getAppointments(String patientId) async {
    final r = await _dio.get('$_p/appointments/patient/$patientId');
    return (r.data as List)
        .cast<Map<String, dynamic>>()
        .map(Appointment.fromJson)
        .toList();
  }
}
