import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo oficial do ME (wordmark "me" com o batimento cardíaco no "e").
/// Usa o arquivo de imagem real, mantendo a proporção (BoxFit.contain).
class MeLogo extends StatelessWidget {
  const MeLogo({super.key, this.height = 32});

  final double height;

  static const _asset = 'assets/images/logo-me-sem-fundo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _asset,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'me',
    );
  }
}

/// Selo branco arredondado com o logo dentro — usado sobre fundos coloridos
/// (ex.: o gradiente coral da tela de login) para garantir contraste.
class MeLogoSeal extends StatelessWidget {
  const MeLogoSeal({super.key, this.logoHeight = 76});

  final double logoHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: AppTheme.softShadow,
      ),
      child: MeLogo(height: logoHeight),
    );
  }
}
