import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/me_chip.dart';
import '../../../core/widgets/me_logo.dart';
import 'auth_controller.dart';

/// Tela de login fiel ao modelo de design do ME.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Pré-preenchido com o PACIENTE de teste (Etapa 2). Para entrar como admin,
  // basta digitar admin@me.dev / Admin@12345.
  final _emailCtrl = TextEditingController(text: 'paciente@me.dev');
  final _passCtrl = TextEditingController(text: 'Paciente@12345');
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _errorDismissed = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorDismissed = false); // um novo erro volta a aparecer
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final ok = await auth.login(_emailCtrl.text, _passCtrl.text);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.tealDark,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Conectado ao backend! Token: ${auth.lastAccessTokenPreview}',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
          ),
        ),
      );
    }
    // Em caso de erro, a mensagem aparece no corpo via Consumer abaixo.
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bg, AppColors.brandTint],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Fica sem scroll em repouso (o Spacer absorve a folga); só rola
              // se o teclado reduzir muito a altura disponível — evitando overflow.
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // --- Bloco marca (topo) ---
                          const MeLogo(height: 54),
                          const SizedBox(height: 16),
                          Text(
                            'Sua saúde é sua.\nSó sua.',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Seu prontuário, exames e histórico num lugar só — '
                            'na sua conta. Quem quiser ver, pede a você.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const MeChip(
                            icon: Icons.lock_outline,
                            label: 'Criptografado e sob o seu controle',
                          ),
                          // Respiro flexível 1 (igual ao de baixo) → distribui a
                          // folga de forma equilibrada, sem um buraco único.
                          const Spacer(flex: 1),
                          // --- Bloco campos (centro) ---
                          if (auth.errorMessage != null && !_errorDismissed) ...[
                            _ErrorBanner(
                              message: auth.errorMessage!,
                              onClose: () => setState(() => _errorDismissed = true),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _LoginForm(
                            formKey: _formKey,
                            emailCtrl: _emailCtrl,
                            passCtrl: _passCtrl,
                            obscure: _obscure,
                            onToggleObscure: () =>
                                setState(() => _obscure = !_obscure),
                            onSubmit: _submit,
                          ),
                          // Respiro flexível 2 (igual ao de cima).
                          const Spacer(flex: 1),
                          // --- Bloco ações (base) ---
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.loading ? null : _submit,
                              child: auth.loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Entrar'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton.icon(
                              onPressed: auth.loading
                                  ? null
                                  : () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          behavior: SnackBarBehavior.floating,
                                          content: Text(
                                            'Login com Google chega numa próxima etapa.',
                                            style: GoogleFonts.poppins(),
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: const Text('Entrar com Google'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'Ao entrar você concorda com os Termos e a '
                              'Política de Privacidade.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('E-mail'),
          const SizedBox(height: 6),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'voce@exemplo.com',
              prefixIcon: Icon(Icons.mail_outline),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Informe seu e-mail.';
              if (!s.contains('@') || !s.contains('.')) {
                return 'E-mail inválido.';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _FieldLabel('Senha'),
          const SizedBox(height: 6),
          TextFormField(
            controller: passCtrl,
            obscureText: obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Informe sua senha.' : null,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.brandTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.stateDanger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.stateDanger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.stateDanger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.close, color: AppColors.stateDanger, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
