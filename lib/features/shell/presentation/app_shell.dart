import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../access/data/access_repository.dart';
import '../../access/presentation/access_controller.dart';
import '../../access/presentation/access_tab.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../documents/data/medical_documents_repository.dart';
import '../../documents/presentation/medical_documents_controller.dart';
import '../../exams/data/exams_repository.dart';
import '../../exams/presentation/exams_controller.dart';
import '../../exams/presentation/saude_tab.dart';
import '../../health/data/history_repository.dart';
import '../../health/presentation/history_controller.dart';
import '../../home/data/home_repository.dart';
import '../../home/presentation/home_controller.dart';
import 'home_tab.dart';
import 'shell_controller.dart';
import 'tab_placeholder.dart';

/// Casca do app após o login: 4 abas com barra inferior.
/// Início e Acessos implementadas; Saúde/Perfil ainda placeholders.
///
/// Os controllers de Acessos e Início são compartilhados (providos aqui), para
/// que os números da Início e da aba Acessos venham da MESMA fonte e fiquem em
/// sincronia após aprovar/negar/revogar.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ShellController()),
        ChangeNotifierProvider(
          create: (ctx) =>
              AccessController(AccessRepository(ctx.read<AuthController>().api))..loadAll(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              HomeController(HomeRepository(ctx.read<AuthController>().api))..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              ExamsController(ExamsRepository(ctx.read<AuthController>().api))..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MedicalDocumentsController(
              MedicalDocumentsRepository(ctx.read<AuthController>().api))
            ..load(),
        ),
        ChangeNotifierProvider(
          create: (ctx) =>
              HistoryController(HistoryRepository(ctx.read<AuthController>().api))..load(),
        ),
      ],
      child: const _ShellScaffold(),
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold();

  static const _tabs = <Widget>[
    HomeTab(),
    AccessTab(),
    SaudeTab(),
    TabPlaceholder(
      title: 'Perfil',
      icon: Icons.person_outline,
      subtitle: 'Seus dados, segurança (2FA) e exportação LGPD.',
    ),
  ];

  static const _items = <_NavItem>[
    _NavItem('Início', Icons.home_outlined, Icons.home),
    _NavItem('Acessos', Icons.shield_outlined, Icons.shield),
    _NavItem('Saúde', Icons.favorite_border, Icons.favorite),
    _NavItem('Perfil', Icons.person_outline, Icons.person),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(index: shell.tabIndex, children: _tabs),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
          boxShadow: [
            BoxShadow(color: Color(0x0F211E1C), blurRadius: 24, offset: Offset(0, -8)),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavButton(
                      item: _items[i],
                      selected: shell.tabIndex == i,
                      onTap: () => context.read<ShellController>().setTab(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.brand : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(selected ? item.activeIcon : item.icon, size: 24, color: color),
          const SizedBox(height: 4),
          Text(
            item.label,
            style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 18 : 0,
            height: 3,
            decoration: BoxDecoration(color: AppColors.brand, borderRadius: BorderRadius.circular(999)),
          ),
        ],
      ),
    );
  }
}
