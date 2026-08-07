import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/access_models.dart';
import 'access_controller.dart';
import 'widgets/access_common.dart';

/// Tela de decisão de um pedido de acesso: toggles de escopo, prazo e ações
/// (aprovar selecionados / aprovar tudo / negar) chamando o backend real.
class DecisionScreen extends StatefulWidget {
  const DecisionScreen({super.key, required this.grant, required this.controller});
  final AccessGrant grant;
  final AccessController controller;

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen> {
  late final Map<RecordSection, bool> _selected = {
    for (final s in widget.grant.sections) s: true,
  };
  // Opções de prazo (dias); null = sem prazo.
  final List<int?> _durations = const [7, 30, 90, null];
  int? _duration = 30;
  bool _busy = false;

  List<RecordSection> get _selectedSections =>
      _selected.entries.where((e) => e.value).map((e) => e.key).toList();

  DateTime? get _expiresAt =>
      _duration == null ? null : DateTime.now().add(Duration(days: _duration!));

  Future<void> _run(Future<String?> Function() action, String successMsg) async {
    setState(() => _busy = true);
    final err = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.tealDark,
        content: Text(successMsg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.stateDanger,
        content: Text(err, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final req = widget.controller.requesterFor(widget.grant);
    final g = widget.grant;
    final selectedCount = _selectedSections.length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // topo
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  _CircleBtn(icon: Icons.chevron_left, onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Text('Pedido de acesso',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                ],
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _busy,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _RequesterHeader(req: req, message: g.requestMessage),
                      const SizedBox(height: 24),
                      Text('O que será compartilhado',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 6),
                      Text('Desligue o que você não quiser liberar.',
                          style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      _ScopeList(
                        sections: g.sections,
                        selected: _selected,
                        onToggle: (s, v) => setState(() => _selected[s] = v),
                      ),
                      const SizedBox(height: 24),
                      Text('Prazo de validade',
                          style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                      const SizedBox(height: 12),
                      _DurationChips(
                        durations: _durations,
                        selected: _duration,
                        onSelect: (d) => setState(() => _duration = d),
                      ),
                      const SizedBox(height: 26),
                      // Aprovar selecionados
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_busy || selectedCount == 0)
                              ? null
                              : () => _run(
                                    () => widget.controller.approvePartial(g.id, _selectedSections, expiresAt: _expiresAt),
                                    'Acesso aprovado para ${req.name}.',
                                  ),
                          child: _busy
                              ? const _Spinner()
                              : Text(selectedCount == g.sections.length
                                  ? 'Aprovar selecionados'
                                  : 'Aprovar $selectedCount de ${g.sections.length}'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Aprovar tudo
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                    () => widget.controller.approveAll(g.id, expiresAt: _expiresAt),
                                    'Todos os acessos solicitados foram aprovados.',
                                  ),
                          child: const Text('Aprovar tudo'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Negar
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _busy ? null : _confirmDeny,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.stateDanger,
                            side: const BorderSide(color: AppColors.stateDanger, width: 1.5),
                          ),
                          child: const Text('Negar pedido'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeny() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusCard)),
      ),
      builder: (ctx) => _ConfirmSheet(
        title: 'Negar este pedido?',
        message: 'O profissional não terá acesso aos seus dados. Você pode ser solicitado novamente no futuro.',
        confirmLabel: 'Negar pedido',
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    if (ok == true) {
      await _run(() => widget.controller.deny(widget.grant.id), 'Pedido negado.');
    }
  }
}

class _RequesterHeader extends StatelessWidget {
  const _RequesterHeader({required this.req, required this.message});
  final Requester req;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brand, AppColors.brandGradientEnd],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.brand.withValues(alpha: 0.26), blurRadius: 32, offset: const Offset(0, 14)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(req.initials,
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.name,
                        style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(height: 3),
                    Text(req.subtitle,
                        style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.9))),
                    if (req.crm != null)
                      Text('CRM ${req.crm}',
                          style: GoogleFonts.poppins(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.78))),
                  ],
                ),
              ),
            ],
          ),
          if (message != null && message!.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(message!,
                  style: GoogleFonts.poppins(fontSize: 13, height: 1.6, color: Colors.white)),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScopeList extends StatelessWidget {
  const _ScopeList({required this.sections, required this.selected, required this.onToggle});
  final List<RecordSection> sections;
  final Map<RecordSection, bool> selected;
  final void Function(RecordSection, bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return AccessCard(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          for (int i = 0; i < sections.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                border: i == sections.length - 1
                    ? null
                    : const Border(bottom: BorderSide(color: AppColors.section)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sections[i].label,
                            style: GoogleFonts.poppins(
                                fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                        const SizedBox(height: 2),
                        Text(sections[i].hint,
                            style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Switch(
                    value: selected[sections[i]] ?? false,
                    onChanged: (v) => onToggle(sections[i], v),
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.tealDark,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({required this.durations, required this.selected, required this.onSelect});
  final List<int?> durations;
  final int? selected;
  final void Function(int?) onSelect;

  String _label(int? d) => d == null ? 'Sem prazo' : '$d dias';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in durations)
          _Chip(
            label: _label(d),
            selected: d == selected,
            onTap: () => onSelect(d),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.text,
            )),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 22, color: AppColors.text),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();
  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22, height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onConfirm,
  });
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
              ),
            ),
            const SizedBox(height: 18),
            Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            Text(message, style: GoogleFonts.poppins(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.stateDanger),
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
