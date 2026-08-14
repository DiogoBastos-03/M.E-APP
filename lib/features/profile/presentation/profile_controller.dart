import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../access/presentation/access_controller.dart' show Loading;
import '../data/profile_models.dart';
import '../data/profile_repository.dart';

/// Estado da tela de Perfil do paciente.
class ProfileController extends ChangeNotifier {
  ProfileController(this._repo);
  final ProfileRepository _repo;

  Loading state = Loading.idle;
  String? error;
  PatientAccount? patient;
  HealthRecord? health;

  Future<void> load() async {
    state = Loading.loading;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.getPatient(),
        _repo.getHealthRecord(),
      ]);
      patient = results[0] as PatientAccount;
      health = results[1] as HealthRecord?;
      state = Loading.ready;
    } on DioException catch (e) {
      error = _msg(e, 'Não foi possível carregar seu perfil.');
      state = Loading.error;
    } catch (_) {
      error = 'Erro inesperado ao carregar seu perfil.';
      state = Loading.error;
    }
    notifyListeners();
  }

  /// null = sucesso; senão a mensagem de erro (do backend quando houver).
  Future<String?> changePassword(String newPassword) async {
    final id = patient?.userId;
    if (id == null) return 'Perfil não carregado.';
    try {
      await _repo.changePassword(id, newPassword);
      return null;
    } on DioException catch (e) {
      return _msg(e, 'Não foi possível alterar a senha.');
    }
  }

  Future<TwoFactorSetup> setupTwoFactor() => _repo.setupTwoFactor();

  Future<String?> activateTwoFactor(String code) async {
    try {
      await _repo.activateTwoFactor(code);
      return null;
    } on DioException catch (e) {
      return _msg(e, 'Código inválido. Tente novamente.');
    }
  }

  Future<String?> disableTwoFactor(String code) async {
    try {
      await _repo.disableTwoFactor(code);
      return null;
    } on DioException catch (e) {
      return _msg(e, 'Código inválido. Tente novamente.');
    }
  }

  Future<ExportedData> exportData() => _repo.exportData();

  String _msg(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Não foi possível conectar ao servidor.';
    }
    return fallback;
  }
}
