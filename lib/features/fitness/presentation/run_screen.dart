import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/fitness_mock.dart';

/// Formata km sem zeros à toa: 5.0 -> "5", 2.50 -> "2.5", 2.25 -> "2.25".
String _fmtKm(double v) {
  final s = v.toStringAsFixed(2);
  return s.replaceAll(RegExp(r'\.?0+$'), '');
}

/// Corrida ao ar livre — TUDO MOCK, em memória (sem backend/rede).
/// Layout: mapa ocupando quase a tela toda + controle circular (play/stop).
/// O histórico NÃO fica aqui — vive na aba Fitness.
class RunScreen extends StatefulWidget {
  const RunScreen({super.key, required this.activity});
  final FitnessActivity activity;

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  bool _running = false;
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  double _distanceKm = 0;
  int _calories = 0;

  // Meta escolhida (MOCK, em memória). Distância em km / tempo em min.
  _GoalType _goal = _GoalType.livre;
  double? _goalDistanceKm;
  int? _goalMinutes;

  /// Resumo da meta mostrado acima do play (null = sem meta / Livre).
  String? get _goalSummary {
    switch (_goal) {
      case _GoalType.livre:
        return null;
      case _GoalType.distancia:
        return _goalDistanceKm == null ? null : 'Meta: ${_fmtKm(_goalDistanceKm!)} km';
      case _GoalType.tempo:
        return _goalMinutes == null ? null : 'Meta: $_goalMinutes min';
    }
  }

  /// Toque num chip de meta: Livre seleciona direto; Distância/Tempo abrem o
  /// bottom sheet de valor. Cancelar o sheet mantém a seleção anterior.
  Future<void> _onGoalTap(_GoalType g) async {
    if (g == _GoalType.livre) {
      setState(() => _goal = _GoalType.livre);
      return;
    }
    final isDistance = g == _GoalType.distancia;
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalValueSheet(
        distance: isDistance,
        current: isDistance ? _goalDistanceKm : _goalMinutes?.toDouble(),
      ),
    );
    if (value == null) return; // cancelado
    setState(() {
      _goal = g;
      if (isDistance) {
        _goalDistanceKm = value;
      } else {
        _goalMinutes = value.round();
      }
    });
  }

  // Contagem regressiva antes de iniciar (3-2-1-Vai!). null = sem contagem.
  int? _countdown;
  Timer? _countdownTimer;

  // Ritmo mock: ~3 m/s (~10,8 km/h) e ~62 kcal/km.
  static const double _kmPerSecond = 0.003;
  static const double _kcalPerKm = 62;

  @override
  void dispose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Toque no play: dispara a contagem regressiva; ao final, começa a corrida.
  void _startCountdown() {
    if (_countdown != null) return; // já contando
    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown! > 1) {
        setState(() => _countdown = _countdown! - 1);
      } else {
        t.cancel();
        setState(() => _countdown = 0); // 0 => "Vai!"
        Future.delayed(const Duration(milliseconds: 650), () {
          if (!mounted) return;
          setState(() => _countdown = null);
          _start();
        });
      }
    });
  }

  void _start() {
    setState(() {
      _running = true;
      _elapsed = Duration.zero;
      _distanceKm = 0;
      _calories = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        _distanceKm += _kmPerSecond;
        _calories = (_distanceKm * _kcalPerKm).round();
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    final registered = _distanceKm > 0;
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
      _distanceKm = 0;
      _calories = 0;
    });
    if (registered) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.tealDark,
        content: Text('Corrida registrada (mock).', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ));
    }
  }

  String get _timeLabel {
    final h = _elapsed.inHours;
    final mm = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  String get _paceLabel {
    if (_distanceKm <= 0) return "--'--\"";
    final secPerKm = _elapsed.inSeconds / _distanceKm;
    final m = secPerKm ~/ 60;
    final s = (secPerKm % 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: widget.activity.title),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Stack(
                  children: [
                    // Mapa: elemento principal, preenche a área toda.
                    Positioned.fill(child: const _Map()),
                    // Controles flutuantes (mock, sem função) — canto superior direito.
                    const Positioned(top: 12, right: 12, child: _MapControls()),
                    // Status do GPS (mock) — chip verde no topo, centralizado.
                    const Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(child: _GpsChip(status: _GpsStatus.ativo)),
                    ),
                    // Controle na parte de baixo, sobre o mapa.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16,
                      child: _running ? _runningControls() : _idleControls(),
                    ),
                    // Contagem regressiva (overlay sobre o mapa) ao iniciar.
                    if (_countdown != null)
                      Positioned.fill(child: _Countdown(value: _countdown!)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _idleControls() {
    final summary = _goalSummary;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GoalSelector(selected: _goal, onSelect: _onGoalTap),
        if (summary != null) ...[
          const SizedBox(height: 10),
          _GoalSummaryPill(text: summary),
        ],
        const SizedBox(height: 16),
        _CircleButton(
          size: 88,
          color: AppColors.brand,
          icon: Icons.play_arrow_rounded,
          iconSize: 48,
          onTap: _startCountdown,
        ),
      ],
    );
  }

  Widget _runningControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _metricsPanel(),
        const SizedBox(height: 16),
        _CircleButton(
          size: 72,
          color: AppColors.stateDanger,
          icon: Icons.stop_rounded,
          iconSize: 34,
          onTap: _stop,
        ),
      ],
    );
  }

  Widget _metricsPanel() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(_distanceKm.toStringAsFixed(2),
                  style: GoogleFonts.poppins(fontSize: 44, fontWeight: FontWeight.w700, color: AppColors.text, letterSpacing: -1.5)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('km',
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MetricTile(label: 'Tempo', value: _timeLabel, icon: Icons.timer_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(label: 'Ritmo', value: '$_paceLabel/km', icon: Icons.speed_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _MetricTile(label: 'Calorias', value: '$_calories', icon: Icons.local_fire_department_outlined)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.chevron_left, size: 22, color: AppColors.text),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
          ),
        ],
      ),
    );
  }
}

/// Mapa MOCK (estilizado com CustomPainter) — preenche toda a área.
/// Troque por um mapa real depois (google_maps_flutter / flutter_map): basta
/// substituir o CustomPaint por GoogleMap/FlutterMap e manter o overlay do ponto.
class _Map extends StatefulWidget {
  const _Map();

  @override
  State<_Map> createState() => _MapState();
}

class _MapState extends State<_Map> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFEA),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _MapPainter()),
          Center(child: _LocationDot(pulse: CurvedAnimation(parent: _pulse, curve: Curves.easeOut))),
        ],
      ),
    );
  }
}

/// Desenho estilizado de um mapa (quarteirões, ruas, avenidas e um traçado).
class _MapPainter extends CustomPainter {
  const _MapPainter();

  static const _street = Color(0xFFF6F4EF); // "asfalto claro" = fundo/ruas
  static const _blockA = Color(0xFFE7E3DB);
  static const _blockB = Color(0xFFECE8E1);
  static const _park = Color(0xFFD8E7D3);
  static const _water = Color(0xFFCFE0EA);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = _street;
    canvas.drawRect(Offset.zero & size, bg);

    // Quarteirões: grade de blocos arredondados; os vãos viram ruas.
    const cell = 60.0;
    const gap = 12.0;
    final block = Paint();
    for (int j = -1; cell * j < size.height + cell; j++) {
      for (int i = -1; cell * i < size.width + cell; i++) {
        final r = ((i * 73856093) ^ (j * 19349663)) & 0x7fffffff;
        final pick = r % 100;
        block.color = pick < 5
            ? _water
            : pick < 15
                ? _park
                : (pick.isEven ? _blockA : _blockB);
        final rect = Rect.fromLTWH(
          i * cell + gap / 2,
          j * cell + gap / 2,
          cell - gap,
          cell - gap,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(5)), block);
      }
    }

    // Avenidas mais largas (ruas principais).
    final avenue = Paint()
      ..color = _street
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, size.height * 0.44), Offset(size.width, size.height * 0.44), avenue);
    canvas.drawLine(Offset(size.width * 0.58, 0), Offset(size.width * 0.58, size.height), avenue);

    // Traçado da rota (passa pelo centro, onde fica o "você está aqui").
    final w = size.width, h = size.height;
    final route = Path()
      ..moveTo(w * 0.18, h * 0.80)
      ..cubicTo(w * 0.30, h * 0.60, w * 0.40, h * 0.66, w * 0.50, h * 0.50)
      ..cubicTo(w * 0.60, h * 0.34, w * 0.72, h * 0.44, w * 0.84, h * 0.24);
    // casing branco + traço coral por cima
    canvas.drawPath(route, Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(route, Paint()
      ..style = PaintingStyle.stroke
      ..color = AppColors.brand.withValues(alpha: 0.65)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) => false;
}

/// "Você está aqui": ponto coral com halo branco e pulso.
class _LocationDot extends StatelessWidget {
  const _LocationDot({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, _) {
              final t = pulse.value;
              final s = 26 + t * 62;
              return Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.brand.withValues(alpha: (1 - t) * 0.28),
                ),
              );
            },
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.brand),
          ),
        ],
      ),
    );
  }
}

/// Estados possíveis do sinal de GPS (MOCK por enquanto).
/// Fixo em [ativo]; pronto pra ligar no GPS real depois (ex.: Geolocator):
/// basta mapear o status do serviço de localização para um destes valores.
enum _GpsStatus {
  // Cada estado tem seu degradê (assinatura visual do app).
  ativo('GPS ativo', Color(0xFF1EA896), Color(0xFF4ADE80)), // verde da marca
  // ignore: unused_field
  procurando('Procurando sinal', Color(0xFFD97706), Color(0xFFFBBF24)), // âmbar (uso futuro)
  // ignore: unused_field
  semSinal('Sem sinal', Color(0xFFDC2626), Color(0xFFF87171)); // vermelho (uso futuro)

  const _GpsStatus(this.label, this.color, this.colorEnd);
  final String label;
  final Color color;
  final Color colorEnd;
}

/// Chip de status do GPS: fundo colorido (verde quando ativo), pill com sombra
/// suave e um pontinho pulsando pra transmitir "sinal vivo". MOCK.
class _GpsChip extends StatefulWidget {
  const _GpsChip({required this.status});
  final _GpsStatus status;

  @override
  State<_GpsChip> createState() => _GpsChipState();
}

class _GpsChipState extends State<_GpsChip> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.status.color, widget.status.colorEnd],
        ),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: widget.status.color.withValues(alpha: 0.32), blurRadius: 18, offset: const Offset(0, 7)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pontinho "vivo": pulso sutil (opacidade + halo) sobre o fundo colorido.
          SizedBox(
            width: 22,
            height: 22,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) {
                final t = _pulse.value; // 0..1..0
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 10 + t * 12,
                      height: 10 + t * 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: (1 - t) * 0.5),
                      ),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 11),
          Text(widget.status.label,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}

/// Degradê âmbar da meta (statePending #F59E0B → #FBBF24) — assinatura do seletor.
const Color _kGoalAmber = Color(0xFFF59E0B);
const Color _kGoalAmberEnd = Color(0xFFFBBF24);
const Color _kGoalAmberDark = Color(0xFFB45309); // texto/ícone sobre tint âmbar

/// Tipos de meta da corrida (MOCK).
enum _GoalType {
  livre('Livre'),
  distancia('Distância'),
  tempo('Tempo');

  const _GoalType(this.label);
  final String label;
}

/// Seletor de meta: chips Livre / Distância / Tempo. O chip selecionado ganha
/// o degradê âmbar (assinatura visual); os demais ficam neutros. MOCK.
class _GoalSelector extends StatelessWidget {
  const _GoalSelector({required this.selected, required this.onSelect});
  final _GoalType selected;
  final ValueChanged<_GoalType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final g in _GoalType.values)
            _GoalChip(
              label: g.label,
              selected: g == selected,
              onTap: () => onSelect(g),
            ),
        ],
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  const _GoalChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kGoalAmber, _kGoalAmberEnd],
                )
              : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          boxShadow: selected
              ? [BoxShadow(color: _kGoalAmber.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Pill que mostra a meta escolhida (ex.: "Meta: 5 km") acima do play.
class _GoalSummaryPill extends StatelessWidget {
  const _GoalSummaryPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _kGoalAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _kGoalAmber.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flag_rounded, size: 15, color: _kGoalAmberDark),
          const SizedBox(width: 6),
          Text(text,
              style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: _kGoalAmberDark)),
        ],
      ),
    );
  }
}

/// Bottom sheet de valor da meta (distância/tempo): presets comuns + custom. MOCK.
class _GoalValueSheet extends StatefulWidget {
  const _GoalValueSheet({required this.distance, this.current});
  final bool distance;
  final double? current;

  @override
  State<_GoalValueSheet> createState() => _GoalValueSheetState();
}

class _GoalValueSheetState extends State<_GoalValueSheet> {
  final TextEditingController _ctrl = TextEditingController();
  bool _custom = false;

  List<double> get _presets =>
      widget.distance ? const [1, 3, 5, 10, 21] : const [15, 30, 45, 60];
  String get _unit => widget.distance ? 'km' : 'min';
  String get _title => widget.distance ? 'Meta de distância' : 'Meta de tempo';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmCustom() {
    final raw = _ctrl.text.trim().replaceAll(',', '.');
    final v = double.tryParse(raw);
    if (v == null || v <= 0) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(999)),
            ),
          ),
          const SizedBox(height: 16),
          Text(_title,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 4),
          Text('Escolha um valor comum ou defina um personalizado.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final p in _presets)
                _PresetPill(
                  label: '${_fmtKm(p)} $_unit',
                  selected: !_custom &&
                      widget.current != null &&
                      (widget.current! - p).abs() < 0.001,
                  onTap: () => Navigator.of(context).pop(p),
                ),
              _PresetPill(
                label: 'Personalizado',
                icon: Icons.tune_rounded,
                selected: _custom,
                onTap: () => setState(() => _custom = !_custom),
              ),
            ],
          ),
          if (_custom) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    autofocus: true,
                    keyboardType: TextInputType.numberWithOptions(decimal: widget.distance),
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
                    decoration: InputDecoration(
                      hintText: widget.distance ? 'Ex.: 7.5' : 'Ex.: 40',
                      suffixText: _unit,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: AppColors.section,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _kGoalAmber, width: 1.4),
                      ),
                    ),
                    onSubmitted: (_) => _confirmCustom(),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _confirmCustom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_kGoalAmber, _kGoalAmberEnd],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text('Definir',
                        style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_kGoalAmber, _kGoalAmberEnd],
                )
              : null,
          color: selected ? null : AppColors.section,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? Colors.transparent : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : AppColors.textSecondary),
              const SizedBox(width: 6),
            ],
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.text)),
          ],
        ),
      ),
    );
  }
}

/// Overlay de contagem regressiva (3-2-1-Vai!) sobre o mapa, antes de iniciar.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.value});

  /// 3, 2, 1 mostram o número; 0 mostra "Vai!".
  final int value;

  @override
  Widget build(BuildContext context) {
    final text = value == 0 ? 'Vai!' : '$value';
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween<double>(begin: 0.6, end: 1).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Container(
            key: ValueKey(value),
            width: value == 0 ? null : 132,
            height: 132,
            padding: value == 0 ? const EdgeInsets.symmetric(horizontal: 36) : null,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.brand, AppColors.brandGradientEnd],
              ),
              shape: value == 0 ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: value == 0 ? BorderRadius.circular(999) : null,
              boxShadow: [
                BoxShadow(color: AppColors.brand.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 12)),
              ],
            ),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: value == 0 ? 44 : 68,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Controles flutuantes do mapa (mock, no-op): trocar tipo + recentralizar.
class _MapControls extends StatelessWidget {
  const _MapControls();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _RoundMapButton(icon: Icons.layers_outlined),
        SizedBox(height: 10),
        _RoundMapButton(icon: Icons.my_location),
      ],
    );
  }
}

class _RoundMapButton extends StatefulWidget {
  const _RoundMapButton({required this.icon});
  final IconData icon;

  @override
  State<_RoundMapButton> createState() => _RoundMapButtonState();
}

class _RoundMapButtonState extends State<_RoundMapButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: () {}, // mock: sem função por enquanto
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _pressed ? AppColors.section : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Icon(widget.icon, size: 21, color: AppColors.text),
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.brandDark),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(value,
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
          ),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Botão circular (play/stop) — só ícone, com brilho suave da cor.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.size,
    required this.color,
    required this.icon,
    required this.iconSize,
    required this.onTap,
  });

  final double size;
  final Color color;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}
