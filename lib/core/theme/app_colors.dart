import 'package:flutter/material.dart';

/// Paleta oficial do ME (fiel ao modelo de design).
/// Fonte da verdade para cores em todo o app.
class AppColors {
  AppColors._();

  // Superfícies / neutros
  static const bg = Color(0xFFFFFDFB); // fundo geral
  static const card = Color(0xFFFFFFFF); // cartões
  static const section = Color(0xFFFBF6F3); // blocos internos / seções
  static const border = Color(0xFFEFE8E3); // bordas
  static const text = Color(0xFF211E1C); // texto principal
  static const textSecondary = Color(0xFF79716B); // texto secundário

  // Marca — coral
  static const brand = Color(0xFFEB5057);
  static const brandDark = Color(0xFFC23A45);
  static const brandTint = Color(0xFFFFECEA);
  static const brandGradientEnd = Color(0xFFF7826E); // usado no badge do logo

  // Apoio — teal
  static const teal = Color(0xFF1EA896);
  static const tealDark = Color(0xFF0E7E70);
  static const tealTint = Color(0xFFE5F4F0);

  // Estados semânticos
  static const stateActive = Color(0xFF0E7E70); // concedido / ativo
  static const statePending = Color(0xFFF59E0B); // pendente (âmbar)
  static const stateDanger = Color(0xFFDC2626); // negado / revogar / alerta
}
