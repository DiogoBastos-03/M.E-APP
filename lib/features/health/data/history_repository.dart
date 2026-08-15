import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
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

  /// Horários livres do médico numa data (janelas − bloqueios − consultas).
  Future<List<AvailableSlot>> getAvailableSlots(String doctorId, DateTime date) async {
    final ymd = '${date.year.toString().padLeft(4, '0')}'
        '-${date.month.toString().padLeft(2, '0')}'
        '-${date.day.toString().padLeft(2, '0')}';
    final r = await _dio.get(
      '$_p/doctors/$doctorId/schedule/available-slots',
      queryParameters: {'date': ymd},
    );
    return (r.data as List).cast<Map<String, dynamic>>().map(AvailableSlot.fromJson).toList();
  }

  /// Cria uma consulta de verdade (POST /appointments), usando exatamente as
  /// strings de início/fim do slot escolhido.
  Future<Appointment> createAppointment({
    required String patientId,
    required String doctorId,
    required AppointmentType type,
    required String startIso,
    required String endIso,
  }) async {
    final r = await _dio.post('$_p/appointments', data: {
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentType': type.wire,
      'startDatetime': startIso,
      'endDatetime': endIso,
    });
    return Appointment.fromJson(r.data as Map<String, dynamic>);
  }
}
