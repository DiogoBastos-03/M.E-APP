import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../access/data/access_models.dart';
import '../../home/data/home_models.dart';
import 'history_models.dart';

/// Consultas + histórico clínico + criação de consulta.
class HistoryRepository {
  HistoryRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  /// Histórico completo (prontuário + consultas + resumos + pedidos de exame).
  Future<ClinicalHistory> getHistory() async {
    final r = await _dio.get('$_p/medical-records/me/history');
    return ClinicalHistory.fromJson(r.data as Map<String, dynamic>);
  }

  /// Lista de médicos (para o formulário de agendamento).
  Future<List<DoctorLite>> getDoctors() async {
    final r = await _dio.get('$_p/doctors');
    return (r.data as List).cast<Map<String, dynamic>>().map(DoctorLite.fromJson).toList();
  }

  /// Cria uma consulta de verdade (POST /appointments).
  Future<Appointment> createAppointment({
    required String patientId,
    required String doctorId,
    required AppointmentType type,
    required DateTime start,
    required DateTime end,
  }) async {
    final r = await _dio.post('$_p/appointments', data: {
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentType': type.wire,
      'startDatetime': start.toUtc().toIso8601String(),
      'endDatetime': end.toUtc().toIso8601String(),
    });
    return Appointment.fromJson(r.data as Map<String, dynamic>);
  }
}
