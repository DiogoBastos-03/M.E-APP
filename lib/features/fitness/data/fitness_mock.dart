import 'package:flutter/material.dart';

/// ⚠️ DADOS MOCK — a área de Fitness ainda NÃO tem backend (será feito depois).
/// Tudo aqui é em memória, isolado e sem nenhuma chamada de rede. Quando os
/// endpoints existirem, troque este arquivo por um repository/controller reais
/// (ex.: FitnessRepository) mantendo os mesmos modelos.

/// Uma modalidade de atividade física.
class FitnessActivity {
  const FitnessActivity({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.enabled,
    required this.cover,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool enabled;

  /// Ilustração de capa do card. O arquivo pode ainda não existir — a UI cai
  /// num placeholder gracioso via errorBuilder até a arte ser adicionada.
  final String cover;
}

/// Modalidades. Só a corrida livre está ativa; as demais entram depois.
const List<FitnessActivity> kFitnessActivities = [
  FitnessActivity(
    id: 'outdoor_run',
    title: 'Corrida ao ar livre',
    description: 'Corrida livre com distância, tempo, ritmo e calorias em tempo real.',
    icon: Icons.directions_run,
    enabled: true,
    cover: 'assets/images/icone-corrida-ar-livre.png',
  ),
  FitnessActivity(
    id: 'bike',
    title: 'Bike',
    description: 'Em breve.',
    icon: Icons.directions_bike,
    enabled: false,
    cover: 'assets/images/icone-ciclismo.png',
  ),
  FitnessActivity(
    id: 'treadmill',
    title: 'Corrida em esteira',
    description: 'Em breve.',
    icon: Icons.directions_run,
    enabled: false,
    cover: 'assets/images/icone-esteira.png',
  ),
  FitnessActivity(
    id: 'swim',
    title: 'Natação',
    description: 'Em breve.',
    icon: Icons.pool,
    enabled: false,
    cover: 'assets/images/icone-natacao.png',
  ),
];

/// Uma corrida concluída (mock).
class RunSession {
  const RunSession({
    required this.date,
    required this.distanceKm,
    required this.duration,
    required this.calories,
  });

  final DateTime date;
  final double distanceKm;
  final Duration duration;
  final int calories;

  String get distanceLabel => '${distanceKm.toStringAsFixed(2)} km';

  String get durationLabel {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    final s = duration.inSeconds % 60;
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  /// Ritmo médio "min'seg\"/km".
  String get paceLabel {
    if (distanceKm <= 0) return "--'--\"/km";
    final secPerKm = duration.inSeconds / distanceKm;
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"/km";
  }
}

/// Histórico MOCK de corridas anteriores.
final List<RunSession> kMockPastRuns = [
  RunSession(
    date: DateTime.now().subtract(const Duration(days: 1)),
    distanceKm: 5.2,
    duration: const Duration(minutes: 28, seconds: 40),
    calories: 322,
  ),
  RunSession(
    date: DateTime.now().subtract(const Duration(days: 3)),
    distanceKm: 3.1,
    duration: const Duration(minutes: 17, seconds: 5),
    calories: 191,
  ),
  RunSession(
    date: DateTime.now().subtract(const Duration(days: 6)),
    distanceKm: 8.0,
    duration: const Duration(minutes: 46, seconds: 12),
    calories: 498,
  ),
];
