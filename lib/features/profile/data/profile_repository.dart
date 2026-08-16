import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'profile_models.dart';

/// Perfil do paciente: dados pessoais, prontuário (saúde), conta/segurança e LGPD.
class ProfileRepository {
  ProfileRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  Future<PatientAccount> getPatient() async {
    final r = await _dio.get('$_p/patients/me');
    return PatientAccount.fromJson(r.data as Map<String, dynamic>);
  }

  /// Prontuário do paciente. 404 = ainda não preenchido (retorna null).
  Future<HealthRecord?> getHealthRecord() async {
    try {
      final r = await _dio.get('$_p/medical-records/me');
      return HealthRecord.fromJson(r.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<HealthDeclaration> getHealthDeclaration() async {
    final r = await _dio.get('$_p/patients/me/health-declaration');
    return HealthDeclaration.fromJson(r.data as Map<String, dynamic>);
  }

  Future<HealthDeclaration> saveHealthDeclaration(HealthDeclaration declaration) async {
    final r = await _dio.put('$_p/patients/me/health-declaration', data: declaration.toJson());
    return HealthDeclaration.fromJson(r.data as Map<String, dynamic>);
  }

  /// Envia um exame do próprio paciente. O backend só aceita o patientId dele.
  Future<void> uploadExam({
    required String patientId,
    required String examType,
    required List<int> bytes,
    required String fileName,
    String? notes,
    DateTime? resultDate,
  }) async {
    final form = FormData.fromMap({
      'patientId': patientId,
      'examType': examType,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (resultDate != null)
        'resultDate': '${resultDate.year.toString().padLeft(4, '0')}'
            '-${resultDate.month.toString().padLeft(2, '0')}'
            '-${resultDate.day.toString().padLeft(2, '0')}',
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    await _dio.post('$_p/exam-results', data: form);
  }

  /// Altera a própria senha (paciente só altera a si mesmo).
  Future<void> changePassword(String userId, String newPassword) async {
    await _dio.put('$_p/users/$userId', data: {'newPassword': newPassword});
  }

  Future<TwoFactorSetup> setupTwoFactor() async {
    final r = await _dio.post('$_p/auth/2fa/setup');
    return TwoFactorSetup.fromJson(r.data as Map<String, dynamic>);
  }

  Future<void> activateTwoFactor(String code) async {
    await _dio.post('$_p/auth/2fa/activate', data: {'code': code});
  }

  Future<void> disableTwoFactor(String code) async {
    await _dio.post('$_p/auth/2fa/disable', data: {'code': code});
  }

  /// Export LGPD (JSON com Content-Disposition: attachment).
  Future<ExportedData> exportData() async {
    final r = await _dio.get(
      '$_p/patients/me/export',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = r.data;
    final bytes = data is Uint8List ? data : Uint8List.fromList((data as List).cast<int>());
    var name = 'meus-dados.json';
    final cd = r.headers.value('content-disposition');
    if (cd != null) {
      final m = RegExp(r'filename="?([^"]+)"?').firstMatch(cd);
      if (m != null) name = m.group(1)!;
    }
    return ExportedData(bytes, name);
  }
}
