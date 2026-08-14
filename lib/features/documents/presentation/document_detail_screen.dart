import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/medical_document_models.dart';
import 'medical_documents_controller.dart';
import 'document_status_chip.dart';

const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
String _fmtDate(DateTime d) => '${d.day} de ${_months[d.month - 1]} de ${d.year}';

/// Detalhe do documento: metadados + visualização do PDF + baixar/compartilhar.
class DocumentDetailScreen extends StatefulWidget {
  const DocumentDetailScreen({
    super.key,
    required this.document,
    required this.controller,
    required this.doctorName,
  });

  final MedicalDocument document;
  final MedicalDocumentsController controller;
  final String doctorName;

  @override
  State<DocumentDetailScreen> createState() => _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends State<DocumentDetailScreen> {
  DocumentFile? _file;
  String? _error;
  bool _loading = true;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.document.hasPdf) {
      _load();
    } else {
      _loading = false;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = await widget.controller.download(widget.document);
      if (!mounted) return;
      setState(() {
        _file = f;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar o documento. Tente novamente.';
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
      final path = '${dir.path}/${f.fileName}';
      await File(path).writeAsBytes(f.bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: f.contentType)], subject: widget.document.typeLabel),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.stateDanger,
          content: Text('Não foi possível baixar/compartilhar o documento.',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        ));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: doc.typeLabel),
            _MetaCard(doc: doc, doctorName: widget.doctorName),
            Expanded(child: _viewer()),
            if (doc.hasPdf) _actionBar(),
          ],
        ),
      ),
    );
  }

  Widget _viewer() {
    final doc = widget.document;
    if (!doc.hasPdf) {
      return _Message(
        icon: Icons.hourglass_empty,
        title: 'PDF ainda não disponível',
        message: 'Este documento ainda não tem um PDF gerado.',
      );
    }
    if (_loading) return _Message.loading();
    if (_error != null) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        title: 'Erro ao carregar',
        message: _error!,
        onRetry: _load,
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: SfPdfViewer.memory(_file!.bytes),
    );
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
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.doc, required this.doctorName});
  final MedicalDocument doc;
  final String doctorName;

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
                child: Icon(doc.typeIcon, color: AppColors.brandDark, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(doc.typeLabel,
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
                    Text(_fmtDate(doc.issuedAt),
                        style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              DocumentStatusChip(doc: doc),
            ],
          ),
          const SizedBox(height: 12),
          _MetaRow(icon: Icons.person_outline, text: doctorName),
          if (doc.validationCode.isNotEmpty)
            _MetaRow(icon: Icons.verified_outlined, text: 'Código: ${doc.validationCode}'),
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
            Text('Carregando documento...',
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
