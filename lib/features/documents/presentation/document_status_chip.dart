import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../data/medical_document_models.dart';

/// Chip de status do documento (assinado/emitido em teal, cancelado em vermelho).
class DocumentStatusChip extends StatelessWidget {
  const DocumentStatusChip({super.key, required this.doc});
  final MedicalDocument doc;

  @override
  Widget build(BuildContext context) {
    late final Color bg;
    late final Color fg;
    if (doc.isCanceled) {
      bg = const Color(0xFFFEECEC);
      fg = AppColors.stateDanger;
    } else if (doc.isFinal) {
      bg = AppColors.tealTint;
      fg = AppColors.tealDark;
    } else {
      bg = AppColors.section;
      fg = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(doc.statusLabel,
          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}
