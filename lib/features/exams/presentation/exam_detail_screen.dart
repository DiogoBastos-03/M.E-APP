import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/exam_models.dart';
import 'exams_controller.dart';

const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
String _fmtDate(DateTime? d) => d == null ? '—' : '${d.day} de ${_months[d.month - 1]} de ${d.year}';
String _fmtSize(int? b) {
  if (b == null) return '';
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// Detalhe do exame: metadados + visualização do laudo + baixar/compartilhar.
class ExamDetailScreen extends StatefulWidget {
  const ExamDetailScreen({
    super.key,
    required this.exam,
    required this.controller,
    required this.publisher,
  });

  final ExamResult exam;
  final ExamsController controller;
  final String publisher;

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  ExamFile? _file;
  String? _error;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.exam.hasFile) {
      _load();
    } else {
      _loading = false; // sem arquivo: só observações
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = await widget.controller.download(widget.exam);
      if (!mounted) return;
      setState(() {
        _file = f;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o laudo. Tente novamente.';
        _loading = false;
      });
    }
  }

  Future<void> _shareOrSave() async {
    final f = _file;
    if (f == null) return;
    setState(() => _sharing = true);
    try {
      final dir = await getTemporaryDirectory();
      final safeName = f.fileName.isNotEmpty ? f.fileName : 'laudo';
      final path = '${dir.path}/$safeName';
      await File(path).writeAsBytes(f.bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: f.contentType)], subject: widget.exam.examType),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.stateDanger,
          content: Text('Não foi possível baixar/compartilhar o arquivo.',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: 'Resultado de exame'),
            _MetaCard(exam: exam, publisher: widget.publisher),
            Expanded(child: _viewer()),
            if (exam.hasFile) _actionBar(),
          ],
        ),
      ),
    );
  }

  Widget _viewer() {
    final exam = widget.exam;
    if (!exam.hasFile) {
      return _Message(
        icon: Icons.description_outlined,
        title: 'Sem arquivo de laudo',
        message: exam.notes?.isNotEmpty == true
            ? 'Este resultado foi registrado apenas com observações (acima).'
            : 'Este resultado não possui arquivo nem observações.',
      );
    }
    if (_loading) {
      return const _Message.loading();
    }
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        title: 'Erro ao carregar',
        message: _error!,
        onRetry: _load,
      );
    }
    final f = _file!;
    switch (f.kind) {
      case ExamFileKind.pdf:
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusInner),
            border: Border.all(color: AppColors.border),
          ),
          child: SfPdfViewer.memory(f.bytes),
        );
      case ExamFileKind.image:
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusInner),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Center(child: Image.memory(f.bytes, fit: BoxFit.contain)),
          ),
        );
      case ExamFileKind.text:
        return Container(
          margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusInner),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              utf8.decode(f.bytes, allowMalformed: true),
              style: GoogleFonts.robotoMono(fontSize: 13, height: 1.5, color: AppColors.text),
            ),
          ),
        );
      case ExamFileKind.other:
        return _Message(
          icon: Icons.insert_drive_file_outlined,
          title: 'Pré-visualização indisponível',
          message: 'Este tipo de arquivo (${f.contentType}) não pode ser exibido aqui. '
              'Use "Baixar / compartilhar" para abri-lo.',
        );
    }
  }

  Widget _actionBar() {
    final ready = _file != null && !_loading && _error == null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: (ready && !_sharing) ? _shareOrSave : null,
          icon: _sharing
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : const Icon(Icons.download_outlined),
          label: Text(_sharing ? 'Preparando...' : 'Baixar / compartilhar'),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.chevron_left, size: 22, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 12),
          Text(title,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.exam, required this.publisher});
  final ExamResult exam;
  final String publisher;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.science_outlined, color: AppColors.brandDark, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exam.examType,
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                    Text(_fmtDate(exam.resultDate),
                        style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(icon: Icons.person_outline, text: 'Publicado por $publisher'),
          if (exam.fileName != null)
            _MetaRow(
              icon: Icons.attach_file,
              text: '${exam.fileName}  ·  ${_fmtSize(exam.fileSizeBytes)}',
            ),
          if (exam.notes != null && exam.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.section,
                borderRadius: BorderRadius.circular(AppTheme.radiusInner),
              ),
              child: Text(exam.notes!,
                  style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: AppColors.text)),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.message, this.onRetry})
      : _loading = false;
  const _Message.loading()
      : icon = Icons.hourglass_empty,
        title = '',
        message = '',
        onRetry = null,
        _loading = true;

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.brand),
            const SizedBox(height: 14),
            Text('Carregando laudo...',
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(title,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Tentar de novo')),
            ],
          ],
        ),
      ),
    );
  }
}
