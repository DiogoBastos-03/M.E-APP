import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../access/presentation/access_controller.dart' show Loading;
import '../data/home_models.dart';
import '../data/home_repository.dart';

/// Estado da aba Início específico: perfil do paciente + consultas.
/// (Pendentes/ativos/auditoria vêm do AccessController compartilhado.)
class HomeController extends ChangeNotifier {
  HomeController(this._repo);
  final HomeRepository _repo;

  Loading state = Loading.idle;
  String? error;

  PatientProfile? patient;
  List<Appointment> appointments = [];

  /// Próxima consulta futura agendada (a mais próxima).
  Appointment? get nextAppointment {
    final upcoming = appointments.where((a) => a.isUpcoming).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Future<void> load() async {
    state = Loading.loading;
    notifyListeners();
    try {
      patient = await _repo.getPatient();
      appointments = await _repo.getAppointments(patient!.id);
      state = Loading.ready;
    } on DioException catch (e) {
      error = _msg(e);
      state = Loading.error;
    } catch (_) {
      error = 'Erro inesperado ao carregar seus dados.';
      state = Loading.error;
    }
    notifyListeners();
  }

  String _msg(DioException e) {
    final code = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Não foi possível conectar ao servidor.';
    }
    return 'Falha ao carregar (${code ?? e.type.name}).';
  }
}
