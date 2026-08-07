import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../shell/presentation/shell_controller.dart';
import '../data/access_models.dart';
import 'access_controller.dart';
import 'decision_screen.dart';
import 'widgets/access_common.dart';

/// O segmento ativo vem do ShellController (permite deep-link vindo da Início).
class AccessTab extends StatelessWidget {
  const AccessTab({super.key});

  @override
  Widget build(BuildContext context) {
    final segment = context.watch<ShellController>().accessSegment;
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meus acessos',
                    style: GoogleFonts.poppins(
                        fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.6)),
                const SizedBox(height: 4),
                Text('Você decide quem entra e por quanto tempo.',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 16),
                _Segmented(
                  index: segment,
                  labels: const ['Pedidos', 'Ativos', 'Quem viu'],
                  onChanged: (i) => context.read<ShellController>().setAccessSegment(i),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: IndexedStack(
              index: segment,
              children: const [_PedidosView(), _AtivosView(), _AuditView()],
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Segmented control (pill)
// --------------------------------------------------------------------------- //
class _Segmented extends StatelessWidget {
  const _Segmented({required this.index, required this.labels, required this.onChanged});
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.brand : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(labels[i],
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: i == index ? Colors.white : AppColors.textSecondary,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// 1) PEDIDOS
// --------------------------------------------------------------------------- //
class _PedidosView extends StatelessWidget {
  const _PedidosView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AccessController>();
    Widget body;
    if (c.pendingState == Loading.loading) {
      body = const LoadingState();
    } else if (c.pendingState == Loading.error) {
      body = ErrorState(message: c.pendingError ?? 'Erro', onRetry: c.loadPending);
    } else if (c.pending.isEmpty) {
      body = const EmptyState(
        title: 'Nada esperando por você',
        message: 'Todos os pedidos foram decididos. Você é avisado quando chegar um novo.',
      );
    } else {
      body = Column(
        children: [
          for (final g in c.pending)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RequestCard(grant: g, req: c.requesterFor(g)),
            ),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: c.loadPending,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [body],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.grant, required this.req});
  final AccessGrant grant;
  final Requester req;

  @override
  Widget build(BuildContext context) {
    final c = context.read<AccessController>();
    return AccessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(initials: req.initials),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.name,
                        style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(req.subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                    Text('Pedido em ${fmtDate(grant.grantedAt)}',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const StatusChip(
                label: 'Pendente',
                background: Color(0xFFFEF3C7),
                foreground: Color(0xFFB45309),
                dot: AppColors.statePending,
              ),
            ],
          ),
          if (grant.requestMessage != null && grant.requestMessage!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('“${grant.requestMessage!}”',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, height: 1.55, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in grant.sections) ScopeChip(s.label)],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DecisionScreen(grant: grant, controller: c)),
              ),
              child: const Text('Revisar'),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// 2) ATIVOS
// --------------------------------------------------------------------------- //
class _AtivosView extends StatelessWidget {
  const _AtivosView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AccessController>();
    Widget body;
    if (c.grantsState == Loading.loading) {
      body = const LoadingState();
    } else if (c.grantsState == Loading.error) {
      body = ErrorState(message: c.grantsError ?? 'Erro', onRetry: c.loadGrants);
    } else if (c.activeGrants.isEmpty) {
      body = const EmptyState(
        title: 'Nenhum acesso ativo',
        message: 'Quando você aprovar um pedido, ele aparece aqui — e você pode revogar quando quiser.',
        icon: Icons.lock_outline,
      );
    } else {
      body = Column(
        children: [
          for (final g in c.activeGrants)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _GrantCard(grant: g, req: c.requesterFor(g)),
            ),
        ],
      );
    }
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: c.loadGrants,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [body],
      ),
    );
  }
}

class _GrantCard extends StatelessWidget {
  const _GrantCard({required this.grant, required this.req});
  final AccessGrant grant;
  final Requester req;

  @override
  Widget build(BuildContext context) {
    final c = context.read<AccessController>();
    final expiry = expiryLabel(grant.expiresAt);
    return AccessCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InitialsAvatar(
                initials: req.initials,
                background: AppColors.tealTint,
                foreground: AppColors.tealDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.name,
                        style: GoogleFonts.poppins(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                    Text(req.subtitle, style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const StatusChip(
                label: 'Ativo',
                background: AppColors.tealTint,
                foreground: AppColors.tealDark,
                dot: AppColors.tealDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final s in grant.sections) ScopeChip(s.label, onCard: true)],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.section),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Desde ${fmtDate(grant.grantedAt)}',
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                    const SizedBox(height: 2),
                    Text(expiry.text,
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: expiry.color)),
                  ],
                ),
              ),
              SizedBox(
                height: 38,
                child: OutlinedButton(
                  onPressed: () => _confirmRevoke(context, c),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.stateDanger,
                    side: const BorderSide(color: AppColors.stateDanger, width: 1.5),
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    textStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Revogar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRevoke(BuildContext context, AccessController c) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _RevokeSheet(name: req.name),
    );
    if (ok == true && context.mounted) {
      final err = await c.revoke(grant.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: err == null ? AppColors.tealDark : AppColors.stateDanger,
        content: Text(err ?? 'Acesso de ${req.name} revogado.',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ));
    }
  }
}

class _RevokeSheet extends StatelessWidget {
  const _RevokeSheet({required this.name});
  final String name;

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
            Text('Revogar o acesso de $name?',
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 8),
            Text('O profissional deixará de ver seus dados imediatamente. Você pode conceder acesso de novo depois.',
                style: GoogleFonts.poppins(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.stateDanger),
                child: const Text('Revogar acesso'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancelar',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// 3) QUEM VIU MEUS DADOS (auditoria)
// --------------------------------------------------------------------------- //
class _AuditView extends StatelessWidget {
  const _AuditView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AccessController>();

    final filters = <(_FilterKey, String, AccessAction?)>[
      (_FilterKey.all, 'Tudo', null),
      (_FilterKey.view, 'Visualizou', AccessAction.view),
      (_FilterKey.download, 'Baixou', AccessAction.download),
      (_FilterKey.upload, 'Publicou', AccessAction.upload),
    ];

    Widget body;
    if (c.logsState == Loading.loading) {
      body = const LoadingState();
    } else if (c.logsState == Loading.error) {
      body = ErrorState(message: c.logsError ?? 'Erro', onRetry: c.loadLogs);
    } else {
      final items = c.filteredLogs;
      if (items.isEmpty) {
        body = EmptyState(
          title: c.logs.isEmpty ? 'Nenhum acesso ainda' : 'Nada com este filtro',
          message: c.logs.isEmpty
              ? 'Quando alguém visualizar, baixar ou publicar algo seu, o registro aparece aqui.'
              : 'Nenhum acesso do tipo selecionado. Tente outro filtro.',
          icon: Icons.history,
        );
      } else {
        body = _AuditTimeline(items: items, controller: c);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final f in filters)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: f.$2,
                    selected: c.logFilter == f.$3,
                    onTap: () => c.setLogFilter(f.$3),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: c.loadLogs,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [body],
            ),
          ),
        ),
      ],
    );
  }
}

enum _FilterKey { all, view, download, upload }

class _AuditTimeline extends StatelessWidget {
  const _AuditTimeline({required this.items, required this.controller});
  final List<RecordAccessLog> items;
  final AccessController controller;

  @override
  Widget build(BuildContext context) {
    // agrupa por dia (items já vêm ordenados desc)
    final groups = <String, List<RecordAccessLog>>{};
    for (final l in items) {
      groups.putIfAbsent(fmtDayGroup(l.occurredAt), () => []).add(l);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10, top: 4),
            child: Text(entry.key,
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1, color: AppColors.textSecondary)),
          ),
          AccessCard(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                for (int i = 0; i < entry.value.length; i++)
                  _AuditRow(
                    log: entry.value[i],
                    who: controller.accessorFor(entry.value[i]).name,
                    isLast: i == entry.value.length - 1,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log, required this.who, required this.isLast});
  final RecordAccessLog log;
  final String who;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final act = log.action;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.section)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: act.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(act.icon, size: 18, color: act.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(who,
                    style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(log.section?.label ?? 'Seus dados',
                    style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(act.label,
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: act.color)),
                    const SizedBox(width: 8),
                    Text(fmtTime(log.occurredAt),
                        style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: Text(label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            )),
      ),
    );
  }
}
