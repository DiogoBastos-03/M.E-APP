import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'exam_models.dart';

/// Endpoints de resultados de exame. O download do laudo vai autenticado
/// (o interceptor do ApiClient injeta o Authorization: Bearer).
class ExamsRepository {
  ExamsRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  Future<List<ExamResult>> getMyExams() async {
    final r = await _dio.get('$_p/exam-results/my');
    return (r.data as List)
        .cast<Map<String, dynamic>>()
        .map(ExamResult.fromJson)
        .toList();
  }

  /// Baixa os BYTES do laudo (PDF/imagem/texto) autenticado.
  Future<ExamFile> downloadFile(ExamResult exam) async {
    final r = await _dio.get(
      '$_p/exam-results/${exam.id}/file',
      options: Options(responseType: ResponseType.bytes),
    );
    final data = r.data;
    final bytes = data is Uint8List ? data : Uint8List.fromList((data as List).cast<int>());
    final ct = r.headers.value('content-type') ??
        exam.fileContentType ??
        'application/octet-stream';
    return ExamFile(bytes, ct, exam.fileName ?? 'laudo');
  }
}
