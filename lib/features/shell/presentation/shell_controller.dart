import 'package:flutter/foundation.dart';

/// Estado de navegação da casca: qual aba está ativa e, dentro de Acessos,
/// qual segmento. Permite que a aba Início faça "deep link" para uma seção
/// específica de Acessos.
class ShellController extends ChangeNotifier {
  // Índices das abas
  static const int tabInicio = 0;
  static const int tabAcessos = 1;
  static const int tabSaude = 2;
  static const int tabFitness = 3;
  // Perfil não aparece na barra inferior; é alcançado via avatar da Home.
  static const int tabPerfil = 4;

  // Segmentos da aba Acessos
  static const int segPedidos = 0;
  static const int segAtivos = 1;
  static const int segAudit = 2;

  int tabIndex = tabInicio;
  int accessSegment = segPedidos;

  void setTab(int i) {
    if (tabIndex != i) {
      tabIndex = i;
      notifyListeners();
    }
  }

  void setAccessSegment(int s) {
    if (accessSegment != s) {
      accessSegment = s;
      notifyListeners();
    }
  }

  /// Abre a aba Acessos já no segmento desejado.
  void openAccess(int segment) {
    accessSegment = segment;
    tabIndex = tabAcessos;
    notifyListeners();
  }
}
