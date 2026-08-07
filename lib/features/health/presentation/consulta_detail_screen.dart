import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../home/data/home_models.dart';
import '../data/history_models.dart';
import 'health_format.dart';

/// Detalhe da consulta com o resumo clínico em SOAP.
class ConsultaDetailScreen extends StatelessWidget {
  const ConsultaDetailScreen({
    super.key,
    required this.appointment,
    required this.summary,
    required this.doctorName,
  });

  final Appointment appointment;
  final ConsultationSummary summary;
  final String doctorName;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String, String?)>[
      ('S', 'Subjetivo', summary.subjective),
      ('O', 'Objetivo', summary.objective),
      ('A', 'Avaliação', summary.assessment),
      ('P', 'Plano', summary.plan),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.chevron_left, size: 22, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Resumo da consulta',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  Container(
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
                        Text(doctorName,
                            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(friendlyDateTime(appointment.start),
                            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(appointment.type.icon, size: 15, color: AppColors.textSecondary),
                            const SizedBox(width: 6),
                            Text(appointment.type.label,
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                            const SizedBox(width: 10),
                            if (summary.isSigned)
                              Row(children: [
                                const Icon(Icons.verified_outlined, size: 14, color: AppColors.tealDark),
                                const SizedBox(width: 4),
                                Text('Assinado',
                                    style: GoogleFonts.poppins(
                                        fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.tealDark)),
                              ]),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final r in rows)
                    if (r.$3 != null && r.$3!.trim().isNotEmpty)
                      _SoapBlock(letter: r.$1, title: r.$2, body: r.$3!),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoapBlock extends StatelessWidget {
  const _SoapBlock({required this.letter, required this.title, required this.body});
  final String letter;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Text(letter,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.tealDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(body,
                    style: GoogleFonts.poppins(fontSize: 13.5, height: 1.5, color: AppColors.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
