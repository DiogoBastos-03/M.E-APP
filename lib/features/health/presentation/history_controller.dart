import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../access/presentation/access_controller.dart' show Loading;
import '../../doctors/data/doctor_models.dart';
import '../../doctors/data/doctors_repository.dart';
import '../../home/data/home_models.dart';
import '../data/history_models.dart';
import '../data/history_repository.dart';

/// Estado das seções Consultas + Histórico da aba Saúde.
class HistoryController extends ChangeNotifier {
  HistoryController(this._repo, this._doctors);
  final HistoryRepository _repo;
  final DoctorsRepository _doctors;

  Loading state = Loading.idle;
  String? error;
  ClinicalHistory? history;

  final Map<String, DoctorReview> _reviewsByAppointment = {};

  DoctorReview? reviewFor(String appointmentId) => _reviewsByAppointment[appointmentId];

  Future<void> load() async {
    state = Loading.loading;
    notifyListeners();
    try {
      history = await _repo.getHistory();
      await _loadReviews();
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

  /// Horários livres do médico numa data.
  Future<List<AvailableSlot>> loadSlots(String doctorId, DateTime date) =>
      _repo.getAvailableSlots(doctorId, date);

  /// Agenda uma consulta de verdade no slot escolhido. Devolve a consulta
  /// criada em sucesso, ou a mensagem de erro. Envia exatamente o start/end do
  /// slot. A consulta criada é o único lugar onde o pagamento chega junto, e é
  /// o que permite mandar o paciente direto para o pagamento.
  Future<({String? error, Appointment? created})> schedule({
    required String patientId,
    required String doctorId,
    required AppointmentType type,
    required AvailableSlot slot,
    required bool sharePatientName,
  }) async {
    try {
      final created = await _repo.createAppointment(
        patientId: patientId,
        doctorId: doctorId,
        type: type,
        startIso: slot.startIso,
        endIso: slot.endIso,
        sharePatientName: sharePatientName,
      );
      await load();
      return (error: null, created: created);
    } on DioException catch (e) {
      return (error: _msg(e), created: null);
    }
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _doctors.getMyReviews();
      _reviewsByAppointment
        ..clear()
        ..addEntries(reviews.map((r) => MapEntry(r.appointmentId, r)));
    } catch (_) {
      return;
    }
  }

  /// Avalia uma consulta concluída. Retorna null em sucesso ou a mensagem de erro.
  Future<String?> review({
    required String appointmentId,
    required int rating,
    String? comment,
  }) async {
    try {
      final existing = _reviewsByAppointment[appointmentId];
      final saved = existing == null
          ? await _doctors.createReview(
              appointmentId: appointmentId,
              rating: rating,
              comment: comment,
            )
          : await _doctors.updateReview(
              reviewId: existing.id,
              rating: rating,
              comment: comment,
            );
      _reviewsByAppointment[appointmentId] = saved;
      notifyListeners();
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
