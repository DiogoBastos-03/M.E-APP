import 'dart:typed_data';

/// Resultado de exame (ExamResultResponse do backend).
class ExamResult {
  const ExamResult({
    required this.id,
    required this.examType,
    this.resultDate,
    this.notes,
    this.fileName,
    this.fileContentType,
    this.fileSizeBytes,
    required this.hasFile,
    this.uploadedByUserId,
    required this.createdAt,
  });

  final String id;
  final String examType;
  final DateTime? resultDate;
  final String? notes;
  final String? fileName;
  final String? fileContentType;
  final int? fileSizeBytes;
  final bool hasFile;
  final String? uploadedByUserId;
  final DateTime createdAt;

  static DateTime? _dt(dynamic v) =>
      (v is String && v.isNotEmpty) ? DateTime.tryParse(v)?.toLocal() : null;

  factory ExamResult.fromJson(Map<String, dynamic> j) => ExamResult(
        id: j['id'] as String,
        examType: (j['examType'] as String?) ?? 'Exame',
        resultDate: _dt(j['resultDate']),
        notes: j['notes'] as String?,
        fileName: j['fileName'] as String?,
        fileContentType: j['fileContentType'] as String?,
        fileSizeBytes: (j['fileSizeBytes'] as num?)?.toInt(),
        hasFile: (j['hasFile'] as bool?) ?? false,
        uploadedByUserId: j['uploadedByUserId'] as String?,
        createdAt: _dt(j['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// Considerado "novo" se publicado nos últimos 7 dias.
  bool get isNew => DateTime.now().difference(createdAt).inDays < 7;

  ExamFileKind get fileKind {
    final ct = (fileContentType ?? '').toLowerCase();
    if (ct.contains('pdf')) return ExamFileKind.pdf;
    if (ct.startsWith('image/')) return ExamFileKind.image;
    if (ct.startsWith('text/')) return ExamFileKind.text;
    return ExamFileKind.other;
  }
}

enum ExamFileKind { pdf, image, text, other }

/// Arquivo do laudo baixado (bytes + content-type real do cabeçalho).
class ExamFile {
  const ExamFile(this.bytes, this.contentType, this.fileName);
  final Uint8List bytes;
  final String contentType;
  final String fileName;

  ExamFileKind get kind {
    final ct = contentType.toLowerCase();
    if (ct.contains('pdf')) return ExamFileKind.pdf;
    if (ct.startsWith('image/')) return ExamFileKind.image;
    if (ct.startsWith('text/')) return ExamFileKind.text;
    return ExamFileKind.other;
  }
}
