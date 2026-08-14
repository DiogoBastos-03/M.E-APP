import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'medical_document_models.dart';

/// Documentos médicos do paciente. Downloads vão autenticados (o interceptor do
/// ApiClient injeta o Authorization: Bearer).
class MedicalDocumentsRepository {
  MedicalDocumentsRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  /// Documentos emitidos para o paciente logado.
  Future<List<MedicalDocument>> getMyDocuments() async {
    final r = await _dio.get('$_p/medical-documents/me');
    return (r.data as List)
        .cast<Map<String, dynamic>>()
        .map(MedicalDocument.fromJson)
        .toList();
  }

  /// Nome do médico emitente (endpoint acessível ao paciente logado).
  Future<String?> getDoctorName(String doctorId) async {
    final r = await _dio.get('$_p/doctors/$doctorId');
    final data = r.data as Map<String, dynamic>;
    return data['fullName'] as String?;
  }

  /// Baixa os BYTES do PDF do documento.
  Future<DocumentFile> downloadFile(MedicalDocument doc) async {
    final r = await _dio.get(
      '$_p/medical-documents/${doc.id}/file',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = r.data;
    final bytes = data is Uint8List ? data : Uint8List.fromList((data as List).cast<int>());
    final ct = r.headers.value('content-type') ?? 'application/pdf';
    final name = 'documento-${doc.validationCode.isNotEmpty ? doc.validationCode : doc.id}.pdf';
    return DocumentFile(bytes, ct, name);
  }
}
