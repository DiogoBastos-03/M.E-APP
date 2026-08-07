import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../access/presentation/access_controller.dart' show Loading;
import '../data/exam_models.dart';
import '../data/exams_repository.dart';

/// Estado da lista de exames.
class ExamsController extends ChangeNotifier {
  ExamsController(this._repo);
  final ExamsRepository _repo;

  Loading state = Loading.idle;
  String? error;
  List<ExamResult> exams = [];

  Future<void> load() async {
    state = Loading.loading;
    notifyListeners();
    try {
      final list = await _repo.getMyExams();
      list.sort((a, b) {
        final ad = a.resultDate ?? a.createdAt;
        final bd = b.resultDate ?? b.createdAt;
        return bd.compareTo(ad); // mais recentes primeiro
      });
      exams = list;
      state = Loading.ready;
    } on DioException catch (e) {
      error = _msg(e);
      state = Loading.error;
    } catch (_) {
      error = 'Erro inesperado ao carregar seus exames.';
      state = Loading.error;
    }
    notifyListeners();
  }

  Future<ExamFile> download(ExamResult exam) => _repo.downloadFile(exam);

  String _msg(DioException e) {
    final code = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Não foi possível conectar ao servidor.';
    }
    return 'Falha ao carregar exames (${code ?? e.type.name}).';
  }
}
