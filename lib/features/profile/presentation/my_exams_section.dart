import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../access/presentation/access_controller.dart';
import '../../exams/data/exam_models.dart';
import '../../exams/presentation/exam_detail_screen.dart';
import '../../exams/presentation/exams_controller.dart';
import 'profile_controller.dart';

/// Exames do paciente, com envio pelo próprio app. A lista é a mesma da aba
/// Saúde; o que muda é o selo de origem em cada item.
class MyExamsSection extends StatelessWidget {
  const MyExamsSection({super.key, required this.controller});
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    final exams = context.watch<ExamsController>();
    final recent = exams.exams.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MEUS EXAMES',
                style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary)),
            const Spacer(),
            InkWell(
              onTap: () => _upload(context),
              child: Row(children: [
                const Icon(Icons.upload_file_outlined, size: 16, color: AppColors.brand),
                const SizedBox(width: 4),
                Text('Enviar',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.brand)),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow,
          ),
          padding: const EdgeInsets.all(18),
          child: recent.isEmpty
              ? Text('Você ainda não tem exames. Envie um laudo ou uma foto do resultado '
                  'para ter tudo em um lugar só.',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, height: 1.5, color: AppColors.textSecondary))
              : Column(
                  children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0) const Divider(height: 20, color: AppColors.border),
                      _ExamRow(exam: recent[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _upload(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
    );
    if (picked.isEmpty || !context.mounted) return;

    final file = picked.first;
    final bytes = await file.readAsBytes();
    if (!context.mounted) return;

    final examType = await _askExamType(context, file.name);
    if (examType == null || !context.mounted) return;

    final err = await controller.uploadExam(
      examType: examType,
      bytes: bytes,
      fileName: file.name,
    );
    if (!context.mounted) return;

    if (err != null) {
      _snack(context, err, error: true);
      return;
    }
    await context.read<ExamsController>().load();
    if (context.mounted) _snack(context, 'Exame enviado.');
  }

  Future<String?> _askExamType(BuildContext context, String fileName) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: Text('Que exame é esse?',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                hintText: 'Hemograma, raio-x do tórax…',
                hintStyle: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final t = ctrl.text.trim();
              Navigator.of(ctx).pop(t.isEmpty ? 'Exame' : t);
            },
            style: ElevatedButton.styleFrom(minimumSize: const Size(120, 46)),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.stateDanger : AppColors.tealDark,
      content: Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
    ));
  }
}

class _ExamRow extends StatelessWidget {
  const _ExamRow({required this.exam});
  final ExamResult exam;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExamDetailScreen(
            exam: exam,
            controller: context.read<ExamsController>(),
            publisher: exam.uploadedByPatient
                ? 'Você'
                : context.read<AccessController>().doctorNameByUserId(exam.uploadedByUserId) ??
                    'Profissional autorizado',
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: exam.uploadedByPatient ? AppColors.tealTint : AppColors.section,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              exam.hasFile ? Icons.description_outlined : Icons.science_outlined,
              size: 18,
              color: exam.uploadedByPatient ? AppColors.tealDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.examType,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(exam.uploadedByPatient ? 'enviado por você' : 'enviado pela clínica',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
