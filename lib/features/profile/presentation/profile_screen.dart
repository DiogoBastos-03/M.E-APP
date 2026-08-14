import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../access/presentation/access_controller.dart' show Loading;
import '../../access/presentation/widgets/access_common.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_models.dart';
import 'profile_controller.dart';

const _months = [
  'jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'
];
String _fmtDate(DateTime d) => '${d.day} de ${_months[d.month - 1]} de ${d.year}';

void _snack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: error ? AppColors.stateDanger : AppColors.tealDark,
    content: Text(msg, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
  ));
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ProfileController>();
    return SafeArea(
      bottom: false,
      child: _body(context, c),
    );
  }

  Widget _body(BuildContext context, ProfileController c) {
    if (c.state == Loading.loading || c.state == Loading.idle) {
      return const Center(child: CircularProgressIndicator(color: AppColors.brand));
    }
    if (c.state == Loading.error || c.patient == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ErrorState(message: c.error ?? 'Erro', onRetry: c.load),
      );
    }
    final p = c.patient!;
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: c.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _Header(patient: p),
          const SizedBox(height: 24),
          _PersonalSection(patient: p),
          const SizedBox(height: 22),
          _HealthSection(health: c.health),
          const SizedBox(height: 22),
          _SecuritySection(controller: c),
          const SizedBox(height: 22),
          _PrivacySection(controller: c),
          const SizedBox(height: 22),
          _LogoutButton(),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _Header extends StatelessWidget {
  const _Header({required this.patient});
  final PatientAccount patient;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.brand, AppColors.brandGradientEnd],
            ),
          ),
          child: Text(patient.initials,
              style: GoogleFonts.poppins(fontSize: 30, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
        const SizedBox(height: 14),
        Text(patient.fullName,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -0.4)),
        const SizedBox(height: 2),
        Text(patient.email,
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }
}

// --------------------------------------------------------------------------- //
class _PersonalSection extends StatelessWidget {
  const _PersonalSection({required this.patient});
  final PatientAccount patient;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'DADOS PESSOAIS',
      footnote: 'Definidos no seu cadastro.',
      child: Column(
        children: [
          _InfoTile(icon: Icons.badge_outlined, label: 'CPF', value: patient.cpfMasked),
          _divider(),
          _InfoTile(
            icon: Icons.cake_outlined,
            label: 'Nascimento',
            value: '${_fmtDate(patient.dateOfBirth)}  ·  ${patient.age} anos',
          ),
          _divider(),
          _InfoTile(
            icon: Icons.phone_outlined,
            label: 'Telefone',
            value: (patient.phoneNumber?.trim().isNotEmpty ?? false) ? patient.phoneNumber!.trim() : 'Não informado',
          ),
          if (patient.isMinor) ...[
            _divider(),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.brandTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Menor de idade',
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.brandDark)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _HealthSection extends StatelessWidget {
  const _HealthSection({required this.health});
  final HealthRecord? health;

  @override
  Widget build(BuildContext context) {
    final h = health;
    String vOr(String? s) => (s != null && s.trim().isNotEmpty) ? s.trim() : 'Não informado';
    return _Section(
      title: 'DADOS DE SAÚDE',
      footnote: 'Atualizado pelo seu médico.',
      child: Column(
        children: [
          _InfoTile(icon: Icons.water_drop_outlined, label: 'Tipo sanguíneo', value: h?.bloodTypeLabel ?? 'Não informado'),
          _divider(),
          _InfoTile(icon: Icons.warning_amber_rounded, label: 'Alergias', value: vOr(h?.allergies)),
          _divider(),
          _InfoTile(icon: Icons.monitor_heart_outlined, label: 'Condições crônicas', value: vOr(h?.chronicConditions)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _SecuritySection extends StatelessWidget {
  const _SecuritySection({required this.controller});
  final ProfileController controller;

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'CONTA E SEGURANÇA',
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.lock_outline,
            label: 'Alterar senha',
            onTap: () => _openChangePassword(context, controller),
          ),
          _divider(),
          _ActionTile(
            icon: Icons.shield_outlined,
            label: 'Autenticação em duas etapas',
            onTap: () => _openTwoFactor(context, controller),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _PrivacySection extends StatefulWidget {
  const _PrivacySection({required this.controller});
  final ProfileController controller;
  @override
  State<_PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends State<_PrivacySection> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await widget.controller.exportData();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${data.fileName}';
      await File(path).writeAsBytes(data.bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(path, mimeType: 'application/json')], subject: 'Meus dados (LGPD)'),
      );
    } catch (_) {
      if (mounted) _snack(context, 'Não foi possível baixar seus dados.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'PRIVACIDADE',
      footnote: 'Baixe uma cópia dos seus dados (LGPD).',
      child: _ActionTile(
        icon: Icons.download_outlined,
        label: 'Baixar meus dados',
        trailing: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand))
            : null,
        onTap: _busy ? null : _export,
      ),
    );
  }
}

// --------------------------------------------------------------------------- //
class _LogoutButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.card,
            title: Text('Sair da conta?', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: AppColors.text)),
            content: Text('Você precisará entrar novamente.',
                style: GoogleFonts.poppins(color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Sair', style: GoogleFonts.poppins(color: AppColors.stateDanger, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (ok == true && context.mounted) {
          await context.read<AuthController>().logout();
        }
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.stateDanger,
        side: const BorderSide(color: AppColors.border),
      ),
      icon: const Icon(Icons.logout, size: 18),
      label: Text('Sair', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
    );
  }
}

// --------------------------------------------------------------------------- //
// Sheets: alterar senha e 2FA
// --------------------------------------------------------------------------- //
final _pwRegex = {
  'maiúscula': RegExp(r'[A-Z]'),
  'minúscula': RegExp(r'[a-z]'),
  'número': RegExp(r'\d'),
  'caractere especial': RegExp(r'[^A-Za-z0-9]'),
};

void _openChangePassword(BuildContext context, ProfileController controller) {
  final ctrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  bool obscure = true;
  bool busy = false;
  String? err;

  _showSheet(context, (ctx, setSheet) {
    String? validate() {
      final v = ctrl.text;
      if (v.length < 8) return 'A senha deve ter ao menos 8 caracteres.';
      for (final e in _pwRegex.entries) {
        if (!e.value.hasMatch(v)) return 'A senha deve conter ao menos uma ${e.key}.';
      }
      if (confirmCtrl.text != v) return 'As senhas não coincidem.';
      return null;
    }

    Future<void> submit() async {
      final local = validate();
      if (local != null) {
        setSheet(() => err = local);
        return;
      }
      setSheet(() {
        busy = true;
        err = null;
      });
      final msg = await controller.changePassword(ctrl.text);
      if (msg == null) {
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) _snack(context, 'Senha alterada com sucesso.');
      } else {
        setSheet(() {
          busy = false;
          err = msg;
        });
      }
    }

    return _SheetContent(
      title: 'Alterar senha',
      children: [
        _SheetField(
          controller: ctrl,
          hint: 'Nova senha',
          obscure: obscure,
          onToggle: () => setSheet(() => obscure = !obscure),
        ),
        const SizedBox(height: 12),
        _SheetField(
          controller: confirmCtrl,
          hint: 'Confirmar nova senha',
          obscure: obscure,
        ),
        const SizedBox(height: 8),
        Text('Mín. 8 caracteres, com maiúscula, minúscula, número e caractere especial.',
            style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary, height: 1.4)),
        if (err != null) ...[
          const SizedBox(height: 10),
          Text(err!, style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.stateDanger)),
        ],
        const SizedBox(height: 18),
        _SheetPrimary(label: 'Salvar nova senha', busy: busy, onTap: submit),
      ],
    );
  });
}

void _openTwoFactor(BuildContext context, ProfileController controller) {
  // modo: null (escolha), 'enable', 'disable'
  String mode = 'choose';
  TwoFactorSetup? setup;
  final codeCtrl = TextEditingController();
  bool busy = false;
  String? err;

  _showSheet(context, (ctx, setSheet) {
    Future<void> startEnable() async {
      setSheet(() {
        busy = true;
        err = null;
      });
      try {
        final s = await controller.setupTwoFactor();
        setSheet(() {
          setup = s;
          mode = 'enable';
          busy = false;
          codeCtrl.clear();
        });
      } catch (_) {
        setSheet(() {
          busy = false;
          err = 'Não foi possível iniciar o 2FA.';
        });
      }
    }

    Future<void> confirmEnable() async {
      if (!RegExp(r'^\d{6}$').hasMatch(codeCtrl.text)) {
        setSheet(() => err = 'O código deve ter 6 dígitos.');
        return;
      }
      setSheet(() {
        busy = true;
        err = null;
      });
      final msg = await controller.activateTwoFactor(codeCtrl.text);
      if (msg == null) {
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) _snack(context, 'Verificação em duas etapas ativada.');
      } else {
        setSheet(() {
          busy = false;
          err = msg;
        });
      }
    }

    Future<void> confirmDisable() async {
      if (!RegExp(r'^\d{6}$').hasMatch(codeCtrl.text)) {
        setSheet(() => err = 'O código deve ter 6 dígitos.');
        return;
      }
      setSheet(() {
        busy = true;
        err = null;
      });
      final msg = await controller.disableTwoFactor(codeCtrl.text);
      if (msg == null) {
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) _snack(context, 'Verificação em duas etapas desativada.');
      } else {
        setSheet(() {
          busy = false;
          err = msg;
        });
      }
    }

    final List<Widget> children;
    if (mode == 'choose') {
      children = [
        Text('Proteja o acesso com um app autenticador (Google Authenticator, Authy, etc.).',
            style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 18),
        _SheetPrimary(label: 'Ativar 2FA', busy: busy, onTap: startEnable),
        const SizedBox(height: 10),
        _SheetSecondary(label: 'Desativar 2FA', onTap: () => setSheet(() {
          mode = 'disable';
          err = null;
          codeCtrl.clear();
        })),
      ];
    } else if (mode == 'enable') {
      children = [
        Text('Adicione a chave no seu app autenticador e digite o código gerado.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 14),
        _CopyBox(label: 'Segredo', value: setup?.secret ?? ''),
        const SizedBox(height: 10),
        _CopyBox(label: 'URL otpauth', value: setup?.otpauthUri ?? '', small: true),
        const SizedBox(height: 14),
        _SheetField(controller: codeCtrl, hint: '000000', code: true),
        if (err != null) ...[
          const SizedBox(height: 10),
          Text(err!, style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.stateDanger)),
        ],
        const SizedBox(height: 18),
        _SheetPrimary(label: 'Confirmar e ativar', busy: busy, onTap: confirmEnable),
      ];
    } else {
      children = [
        Text('Digite um código atual do seu app autenticador para desativar o 2FA.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
        const SizedBox(height: 14),
        _SheetField(controller: codeCtrl, hint: '000000', code: true),
        if (err != null) ...[
          const SizedBox(height: 10),
          Text(err!, style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.stateDanger)),
        ],
        const SizedBox(height: 18),
        _SheetPrimary(label: 'Desativar 2FA', busy: busy, onTap: confirmDisable),
      ];
    }

    return _SheetContent(title: 'Verificação em duas etapas', children: children);
  });
}

// --------------------------------------------------------------------------- //
// Widgets base
// --------------------------------------------------------------------------- //
Widget _divider() => const Divider(height: 18, color: AppColors.section);

void _showSheet(
  BuildContext context,
  Widget Function(BuildContext ctx, void Function(void Function()) setState) builder,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: StatefulBuilder(builder: (c, setState) => builder(c, setState)),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.footnote});
  final String title;
  final Widget child;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.6)),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: child,
        ),
        if (footnote != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 8),
            child: Text(footnote!, style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final empty = value == 'Não informado';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: empty ? AppColors.textSecondary : AppColors.text,
                      height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.icon, required this.label, this.onTap, this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.text),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text)),
            ),
            trailing ?? const Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _SheetContent extends StatelessWidget {
  const _SheetContent({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 18),
          Text(title, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  const _SheetField({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.onToggle,
    this.code = false,
  });
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final VoidCallback? onToggle;
  final bool code;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: code ? TextInputType.number : null,
      inputFormatters: code ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)] : null,
      style: GoogleFonts.poppins(
        fontSize: code ? 20 : 14,
        fontWeight: code ? FontWeight.w600 : FontWeight.w400,
        letterSpacing: code ? 8 : 0,
        color: AppColors.text,
      ),
      textAlign: code ? TextAlign.center : TextAlign.start,
      decoration: InputDecoration(
        hintText: hint,
        suffixIcon: onToggle == null
            ? null
            : IconButton(
                icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.textSecondary),
                onPressed: onToggle,
              ),
      ),
    );
  }
}

class _SheetPrimary extends StatelessWidget {
  const _SheetPrimary({required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        child: busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
            : Text(label),
      ),
    );
  }
}

class _SheetSecondary extends StatelessWidget {
  const _SheetSecondary({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.border)),
        child: Text(label),
      ),
    );
  }
}

class _CopyBox extends StatelessWidget {
  const _CopyBox({required this.label, required this.value, this.small = false});
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) _snack(context, '$label copiado.');
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.section,
              borderRadius: BorderRadius.circular(AppTheme.radiusInner),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(value,
                      maxLines: small ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.robotoMono(
                          fontSize: small ? 11 : 14,
                          letterSpacing: small ? 0 : 1.5,
                          color: AppColors.text)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
