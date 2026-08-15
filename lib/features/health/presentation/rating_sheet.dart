import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'history_controller.dart';

Future<bool?> showRatingSheet(
  BuildContext context, {
  required HistoryController controller,
  required String appointmentId,
  required String doctorName,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RatingSheet(
      controller: controller,
      appointmentId: appointmentId,
      doctorName: doctorName,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({
    required this.controller,
    required this.appointmentId,
    required this.doctorName,
  });

  final HistoryController controller;
  final String appointmentId;
  final String doctorName;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  late int _rating;
  late final TextEditingController _comment;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.controller.reviewFor(widget.appointmentId);
    _rating = existing?.rating ?? 0;
    _comment = TextEditingController(text: existing?.comment ?? '');
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final err = await widget.controller.review(
      appointmentId: widget.appointmentId,
      rating: _rating,
      comment: _comment.text.trim(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (err == null) {
      Navigator.of(context).pop(true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.stateDanger,
      content: Text(err, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Avaliar consulta',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 4),
            Text(widget.doctorName,
                style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            Row(
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: _submitting ? null : () => setState(() => _rating = i),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 34,
                      color: i <= _rating ? AppColors.statePending : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Comentário (opcional)',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.section,
                borderRadius: BorderRadius.circular(AppTheme.radiusInner),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _comment,
                maxLines: 4,
                maxLength: 1000,
                enabled: !_submitting,
                style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  counterText: '',
                  hintText: 'Como foi o atendimento?',
                  hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_rating == 0 || _submitting) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Enviar avaliação'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
