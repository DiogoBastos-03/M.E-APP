import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/fitness_mock.dart';
import 'run_screen.dart';

const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];
String _fmtDay(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Aba Fitness: histórico recente no topo + grade 2x2 de modalidades.
class FitnessTab extends StatelessWidget {
  const FitnessTab({super.key});

  @override
  Widget build(BuildContext context) {
    final history = kMockPastRuns; // MOCK
    // Tela travada (não rola como um todo): Column que preenche a altura.
    // Só o histórico (Expanded) rola internamente; a grade 2x2 fica fixa embaixo.
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fitness',
                style: GoogleFonts.poppins(
                    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.6)),
            const SizedBox(height: 4),
            Text('Registre suas atividades e acompanhe sua evolução.',
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 22),
            _SectionLabel('ATIVIDADES RECENTES'),
            const SizedBox(height: 10),
            Expanded(child: _History(runs: history)),
            const SizedBox(height: 20),
            _SectionLabel('ATIVIDADES'),
            const SizedBox(height: 10),
            _ActivityGrid(),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.poppins(
          fontSize: 11.5, fontWeight: FontWeight.w600, letterSpacing: 0.8, color: AppColors.textSecondary));
}

// --------------------------------------------------------------------------- //
// Histórico recente (rolagem horizontal de cards compactos)
// --------------------------------------------------------------------------- //
class _History extends StatelessWidget {
  const _History({required this.runs});
  final List<RunSession> runs;

  @override
  Widget build(BuildContext context) {
    if (runs.isEmpty) {
      // Estado vazio ancorado no topo da área (ListView p/ não esticar na vertical).
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.section,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.timeline_outlined, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Suas atividades recentes aparecerão aqui.',
                      style: GoogleFonts.poppins(fontSize: 12.5, height: 1.4, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Rolagem interna própria, limitada à área do Expanded (não rola a página).
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 2),
      itemCount: runs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _HistoryRow(run: runs[i]),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.run});
  final RunSession run;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.directions_run, size: 20, color: AppColors.brandDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Corrida',
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text('${_fmtDay(run.date)} · ${run.durationLabel}',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(run.distanceLabel,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Grade 2x2 de modalidades
// --------------------------------------------------------------------------- //
class _ActivityGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final a = kFitnessActivities;
    Widget row(int i, int j) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _ActivityCard(activity: a[i])),
            const SizedBox(width: 14),
            Expanded(child: j < a.length ? _ActivityCard(activity: a[j]) : const SizedBox()),
          ],
        );
    return Column(
      children: [
        row(0, 1),
        const SizedBox(height: 14),
        row(2, 3),
      ],
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final FitnessActivity activity;

  @override
  Widget build(BuildContext context) {
    final enabled = activity.enabled;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => RunScreen(activity: activity)),
                )
            : null,
        child: SizedBox(
          height: 176,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(color: AppColors.border),
              boxShadow: enabled ? AppTheme.softShadow : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _Cover(activity: activity)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Text(activity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.2)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Capa do card: usa a ilustração se existir; senão, placeholder gracioso.
class _Cover extends StatelessWidget {
  const _Cover({required this.activity});
  final FitnessActivity activity;

  @override
  Widget build(BuildContext context) {
    // Painel de marca por trás; a ilustração (fundo transparente) entra com
    // BoxFit.contain e um respiro, pra aparecer inteira e bem enquadrada.
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandTint, AppColors.card],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Image.asset(
              activity.cover,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Center(child: Icon(activity.icon, size: 42, color: AppColors.brandDark)),
            ),
          ),
          if (!activity.enabled)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('Em breve',
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}
