import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../access/presentation/access_controller.dart' show Loading;
import '../data/medical_document_models.dart';
import '../data/medical_documents_repository.dart';

/// Estado da lista de documentos médicos do paciente.
class MedicalDocumentsController extends ChangeNotifier {
  MedicalDocumentsController(this._repo);
  final MedicalDocumentsRepository _repo;

  Loading state = Loading.idle;
  String? error;
  List<MedicalDocument> documents = [];

  // cache doctorId -> nome
  final Map<String, String> _doctorNames = {};

  Future<void> load() async {
    state = Loading.loading;
    notifyListeners();
    try {
      final all = await _repo.getMyDocuments();
      // Só documentos finalizados: assinados/emitidos (+ cancelados, marcados).
      // Rascunhos e "aguardando assinatura" ficam de fora (médico ainda montando).
      final visible = all
          .where((d) => d.isFinal || d.isCanceled)
          .toList()
        ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt)); // mais recentes primeiro
      documents = visible;
      state = Loading.ready;
      notifyListeners();
      unawaited(_resolveDoctorNames());
    } on DioException catch (e) {
      error = _msg(e);
      state = Loading.error;
      notifyListeners();
    } catch (_) {
      error = 'Erro inesperado ao carregar seus documentos.';
      state = Loading.error;
      notifyListeners();
    }
  }

  Future<void> _resolveDoctorNames() async {
    final ids = documents
        .map((d) => d.doctorId)
        .whereType<String>()
        .where((id) => !_doctorNames.containsKey(id))
        .toSet();
    if (ids.isEmpty) return;
    await Future.wait(ids.map((id) async {
      try {
        final name = await _repo.getDoctorName(id);
        if (name != null && name.isNotEmpty) _doctorNames[id] = name;
      } catch (_) {
        // silencioso: cai no fallback ao exibir
      }
    }));
    notifyListeners();
  }

  /// Nome do emitente para exibição.
  String doctorNameFor(MedicalDocument doc) {
    final id = doc.doctorId;
    if (id != null && _doctorNames.containsKey(id)) return _doctorNames[id]!;
    if (doc.externalDoctorName != null && doc.externalDoctorName!.isNotEmpty) {
      return doc.externalDoctorName!;
    }
    return 'Médico emitente';
  }

  Future<DocumentFile> download(MedicalDocument doc) => _repo.downloadFile(doc);

  String _msg(DioException e) {
    final code = e.response?.statusCode;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Não foi possível conectar ao servidor.';
    }
    return 'Falha ao carregar documentos (${code ?? e.type.name}).';
  }
}
