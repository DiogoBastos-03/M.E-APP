import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../access/data/access_models.dart';
import '../../access/presentation/access_controller.dart' show Loading;
import '../../home/data/home_models.dart';
import '../data/history_models.dart';
import '../data/history_repository.dart';

/// Estado das seções Consultas + Histórico da aba Saúde.
class HistoryController extends ChangeNotifier {
  HistoryController(this._repo);
  final HistoryRepository _repo;

  Loading state = Loading.idle;
  String? error;
  ClinicalHistory? history;

  Future<void> load() async {
    state = Loading.loading;
    notifyListeners();
    try {
      history = await _repo.getHistory();
      state = Loading.ready;
    } on DioException catch (e) {
      error = _msg(e);
      state = Loading.error;
    } catch (_) {
      error = 'Erro inesperado ao carregar seus dados clínicos.';
      state = Loading.error;
    }
    notifyListeners();
  }

  List<Appointment> get _all => history?.appointments ?? const [];

  /// Próximas: agendadas no futuro (ordem crescente).
  List<Appointment> get upcoming {
    final l = _all.where((a) => a.isUpcoming).toList()..sort((a, b) => a.start.compareTo(b.start));
    return l;
  }

  /// Anteriores: o resto (passadas/concluídas/canceladas), ordem decrescente.
  List<Appointment> get past {
    final l = _all.where((a) => !a.isUpcoming).toList()..sort((a, b) => b.start.compareTo(a.start));
    return l;
  }

  ConsultationSummary? summaryFor(String appointmentId) => history?.summaryFor(appointmentId);

  Future<List<DoctorLite>> loadDoctors() => _repo.getDoctors();

  /// Agenda uma consulta de verdade. Retorna null em sucesso ou msg de erro.
  Future<String?> schedule({
    required String patientId,
    required String doctorId,
    required AppointmentType type,
    required DateTime start,
  }) async {
    try {
      await _repo.createAppointment(
        patientId: patientId,
        doctorId: doctorId,
        type: type,
        start: start,
        end: start.add(const Duration(minutes: 30)),
      );
      await load();
      return null;
    } on DioException catch (e) {
      return _msg(e);
    }
  }

  String _msg(DioException e) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Não foi possível conectar ao servidor.';
    }
    return 'Falha ao processar (${code ?? e.type.name}).';
  }
}
