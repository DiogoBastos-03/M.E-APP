import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

// --------------------------------------------------------------------------- //
// Formatação de datas (sem dependência de intl)
// --------------------------------------------------------------------------- //
const _months = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
  'jul', 'ago', 'set', 'out', 'nov', 'dez'
];

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime? d) =>
    d == null ? '—' : '${two(d.day)}/${two(d.month)}/${d.year}';

String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String fmtDayGroup(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'HOJE';
  if (diff == 1) return 'ONTEM';
  return '${two(d.day)} DE ${_months[d.month - 1].toUpperCase()} DE ${d.year}';
}

/// Texto e cor do prazo restante de uma concessão.
({String text, Color color}) expiryLabel(DateTime? expiresAt) {
  if (expiresAt == null) return (text: 'Sem prazo de validade', color: AppColors.textSecondary);
  final days = expiresAt.difference(DateTime.now()).inDays;
  if (days < 0) return (text: 'Expirado', color: AppColors.stateDanger);
  if (days == 0) return (text: 'Expira hoje', color: AppColors.statePending);
  if (days == 1) return (text: 'Expira amanhã', color: AppColors.statePending);
  final color = days <= 7 ? AppColors.statePending : AppColors.tealDark;
  return (text: 'Expira em $days dias', color: color);
}

// --------------------------------------------------------------------------- //
// Componentes reutilizáveis
// --------------------------------------------------------------------------- //

/// Avatar quadrado arredondado com iniciais.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.initials,
    this.size = 42,
    this.background = AppColors.brandTint,
    this.foreground = AppColors.brandDark,
  });

  final String initials;
  final double size;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.38),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.poppins(
          fontSize: size * 0.31,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Chip de escopo (seção do prontuário).
class ScopeChip extends StatelessWidget {
  const ScopeChip(this.label, {super.key, this.onCard = false});
  final String label;
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onCard ? AppColors.card : AppColors.section,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Chip de estado com pontinho (Pendente / Ativo / etc.).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.dot,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: foreground)),
        ],
      ),
    );
  }
}

/// Cartão branco padrão da aba.
class AccessCard extends StatelessWidget {
  const AccessCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }
}

// --------------------------------------------------------------------------- //
// Estados: carregando / vazio / erro
// --------------------------------------------------------------------------- //
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(top: 60),
        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(minimumSize: const Size(140, 46)),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message, this.icon = Icons.check});
  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: AppColors.tealTint, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, size: 20, color: AppColors.tealDark),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
