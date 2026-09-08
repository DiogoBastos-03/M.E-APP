import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/me_logo.dart';
import '../../access/data/access_models.dart';
import '../../access/presentation/access_controller.dart';
import '../../access/presentation/decision_screen.dart';
import '../../access/presentation/widgets/access_common.dart';
import '../../home/data/home_models.dart';
import '../../home/presentation/home_controller.dart';
import '../../teleconsult/presentation/teleconsult_screen.dart';
import 'shell_controller.dart';

const _weekdays = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _monthsAbbr = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String _friendlyDateTime(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} de ${_monthsAbbr[d.month - 1]} • ${two(d.hour)}:${two(d.minute)}';

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}

/// Aba Início — "Meu Cofre". Painel principal do paciente com dados reais.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();

    if (home.state == Loading.loading && home.patient == null) {
      return const SafeArea(child: LoadingState());
    }
    if (home.state == Loading.error && home.patient == null) {
      return SafeArea(
        child: ErrorState(message: home.error ?? 'Erro ao carregar', onRetry: home.load),
      );
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () => Future.wait([
          context.read<HomeController>().load(),
          context.read<AccessController>().refreshAll(),
        ]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: const [
            _Header(),
            SizedBox(height: 20),
            _StatusCard(),
            SizedBox(height: 20),
            _StatTiles(),
            SizedBox(height: 24),
            _PendingPreview(),
            SizedBox(height: 24),
            _NextAppointmentCard(),
            SizedBox(height: 24),
            _AuditPreview(),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// 1) Cabeçalho
// --------------------------------------------------------------------------- //
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final patient = context.watch<HomeController>().patient;
    final name = patient?.firstName ?? '';
    final initials = patient?.initials ?? 'ME';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const MeLogo(height: 58),
            GestureDetector(
              onTap: () => context.read<ShellController>().setTab(ShellController.tabPerfil),
              child: InitialsAvatar(initials: initials, size: 44),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text('${_greeting()},',
            style: GoogleFonts.poppins(fontSize: 15, color: AppColors.textSecondary)),
        Text(name.isEmpty ? 'Bem-vindo' : name,
            style: GoogleFonts.poppins(
                fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.6)),
      ],
    );
  }

}

// --------------------------------------------------------------------------- //
// 2) Card de status (proteção)
// --------------------------------------------------------------------------- //
class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        // Base teal da marca (#0E7E70) com um leve gradiente para dar profundidade.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.tealDark, AppColors.teal],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Text(
                'MEU COFRE',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Seus dados estão sob o seu controle',
            style: GoogleFonts.poppins(
              fontSize: 18,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Nenhum acesso acontece sem a sua permissão — e tudo fica registrado.',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// 3) Resumo em números (stat tiles)
// --------------------------------------------------------------------------- //
class _StatTiles extends StatelessWidget {
  const _StatTiles();

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessController>();
    final home = context.watch<HomeController>();
    final shell = context.read<ShellController>();

    final pendingVal = access.pendingState == Loading.loading ? '…' : '${access.pending.length}';
    final activeVal = access.grantsState == Loading.loading ? '…' : '${access.activeGrants.length}';
    final next = home.nextAppointment;
    final nextVal = next == null ? '—' : '${next.start.day}/${two(next.start.month)}';

    return Row(
      children: [
        Expanded(
          child: _Tile(
            value: pendingVal,
            label: 'Pedidos\npendentes',
            icon: Icons.mark_email_unread_outlined,
            accent: AppColors.statePending,
            onTap: () => shell.openAccess(ShellController.segPedidos),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(
            value: activeVal,
            label: 'Acessos\nativos',
            icon: Icons.verified_user_outlined,
            accent: AppColors.tealDark,
            onTap: () => shell.openAccess(ShellController.segAtivos),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Tile(
            value: nextVal,
            label: 'Próxima\nconsulta',
            icon: Icons.event_outlined,
            accent: AppColors.brand,
            onTap: () => shell.setTab(ShellController.tabSaude),
          ),
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.value,
    required this.label,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
  final String value;
  final String label;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppTheme.radiusInner),
          border: Border.all(color: AppColors.border),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: accent),
            const SizedBox(height: 10),
            Text(value,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.poppins(fontSize: 11, height: 1.25, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// 4) Prévia de pedidos pendentes
// --------------------------------------------------------------------------- //
class _PendingPreview extends StatelessWidget {
  const _PendingPreview();

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessController>();
    final shell = context.read<ShellController>();

    if (access.pendingState == Loading.loading) {
      return const _SectionShell(title: 'Pedidos pendentes', child: LoadingMini());
    }
    if (access.pending.isEmpty) {
      return _SectionShell(
        title: 'Pedidos pendentes',
        child: _MiniEmpty(
          icon: Icons.check_circle_outline,
          text: 'Nenhum pedido esperando por você.',
        ),
      );
    }

    final preview = access.pending.take(2).toList();
    return _SectionShell(
      title: 'Pedidos pendentes',
      actionLabel: 'Ver todos',
      onAction: () => shell.openAccess(ShellController.segPedidos),
      child: Column(
        children: [
          for (final g in preview)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PendingCard(grant: g),
            ),
        ],
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.grant});
  final AccessGrant grant;

  @override
  Widget build(BuildContext context) {
    final access = context.read<AccessController>();
    final req = access.requesterFor(grant);
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
                MaterialPageRoute(builder: (_) => DecisionScreen(grant: grant, controller: access)),
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
// 5) Próxima consulta em destaque
// --------------------------------------------------------------------------- //
class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard();

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();
    final access = context.watch<AccessController>();
    final shell = context.read<ShellController>();
    final next = home.nextAppointment;

    return _SectionShell(
      title: 'Próxima consulta',
      child: next == null
          ? _MiniEmpty(icon: Icons.event_available_outlined, text: 'Você não tem consultas agendadas.')
          : GestureDetector(
              onTap: () => shell.setTab(ShellController.tabSaude),
              child: AccessCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration:
                              BoxDecoration(color: AppColors.brandTint, borderRadius: BorderRadius.circular(14)),
                          child: Icon(next.type.icon, color: AppColors.brandDark, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(access.doctorNameById(next.doctorId) ?? next.type.label,
                                  style: GoogleFonts.poppins(
                                      fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.text)),
                              const SizedBox(height: 2),
                              Text(_friendlyDateTime(next.start),
                                  style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        _TypePill(type: next.type),
                      ],
                    ),
                    if (next.roomIsOpen) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () => _enterRoom(context, next,
                              access.doctorNameById(next.doctorId) ?? 'Médico(a)'),
                          icon: const Icon(Icons.videocam_outlined, size: 18),
                          label: const Text('Entrar na consulta'),
                        ),
                      ),
                    ] else if (next.needsPayment) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Pagamento pendente',
                                style: GoogleFonts.poppins(fontSize: 12, color: AppColors.statePending)),
                          ),
                          Text('Ver na aba Saúde',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.brand)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

Future<void> _enterRoom(BuildContext context, Appointment appt, String doctorName) async {
  final patientName = appt.patientNameShared
      ? (context.read<HomeController>().patient?.fullName ?? 'Paciente')
      : 'Paciente';
  await Navigator.of(context).push<bool>(MaterialPageRoute(
    builder: (_) => TeleconsultScreen(
      appointmentId: appt.id,
      doctorName: doctorName,
      patientName: patientName,
    ),
  ));
  if (context.mounted) await context.read<HomeController>().load();
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});
  final AppointmentType type;

  @override
  Widget build(BuildContext context) {
    final tele = type == AppointmentType.telemedicine;
    final bg = tele ? AppColors.tealTint : AppColors.section;
    final fg = tele ? AppColors.tealDark : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 13, color: fg),
          const SizedBox(width: 5),
          Text(type.label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// 6) Prévia "Quem viu meus dados"
// --------------------------------------------------------------------------- //
class _AuditPreview extends StatelessWidget {
  const _AuditPreview();

  @override
  Widget build(BuildContext context) {
    final access = context.watch<AccessController>();
    final shell = context.read<ShellController>();

    Widget child;
    if (access.logsState == Loading.loading) {
      child = const LoadingMini();
    } else if (access.logs.isEmpty) {
      child = _MiniEmpty(icon: Icons.history, text: 'Ninguém acessou seus dados ainda.');
    } else {
      final preview = access.logs.take(3).toList();
      child = AccessCard(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          children: [
            for (int i = 0; i < preview.length; i++)
              _AuditMiniRow(
                log: preview[i],
                who: access.accessorFor(preview[i]).name,
                isLast: i == preview.length - 1,
              ),
          ],
        ),
      );
    }

    return _SectionShell(
      title: 'Quem viu meus dados',
      actionLabel: 'Ver tudo',
      onAction: () => shell.openAccess(ShellController.segAudit),
      child: child,
    );
  }
}

class _AuditMiniRow extends StatelessWidget {
  const _AuditMiniRow({required this.log, required this.who, required this.isLast});
  final RecordAccessLog log;
  final String who;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final act = log.action;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.section)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: act.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(act.icon, size: 16, color: act.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(who,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                Text('${act.label} • ${log.section?.label ?? 'seus dados'}',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(fmtTime(log.occurredAt),
              style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
// Auxiliares de seção
// --------------------------------------------------------------------------- //
class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.child, this.actionLabel, this.onAction});
  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
            if (actionLabel != null)
              GestureDetector(
                onTap: onAction,
                child: Text(actionLabel!,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.brand)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class LoadingMini extends StatelessWidget {
  const LoadingMini({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
}

class _MiniEmpty extends StatelessWidget {
  const _MiniEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.tealDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}
