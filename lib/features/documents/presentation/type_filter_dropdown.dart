import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';

class TypeFilterOption {
  const TypeFilterOption(this.key, this.label);
  final String key;
  final String label;
}

/// Select/dropdown customizado, no padrão do app: gatilho arredondado com fundo
/// suave, painel flutuante ancorado abaixo com sombra leve, acento coral no
/// item selecionado e animação suave (fade + escala) ao abrir/fechar.
class TypeFilterDropdown extends StatefulWidget {
  const TypeFilterDropdown({
    super.key,
    required this.options,
    required this.selectedKey,
    required this.onChanged,
  });

  final List<TypeFilterOption> options;
  final String selectedKey;
  final ValueChanged<String> onChanged;

  @override
  State<TypeFilterDropdown> createState() => _TypeFilterDropdownState();
}

class _TypeFilterDropdownState extends State<TypeFilterDropdown>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final GlobalKey _triggerKey = GlobalKey();
  late final AnimationController _anim;
  OverlayEntry? _entry;
  double _width = 240;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 180));
  }

  bool get _isOpen => _entry != null;

  String get _selectedLabel => widget.options
      .firstWhere((o) => o.key == widget.selectedKey, orElse: () => widget.options.first)
      .label;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final box = _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    _width = box?.size.width ?? _width;
    _entry = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_entry!);
    _anim.forward();
    setState(() {});
  }

  Future<void> _close() async {
    if (_entry == null) return;
    await _anim.reverse();
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  void _select(String key) {
    widget.onChanged(key);
    _close();
  }

  @override
  void dispose() {
    _entry?.remove();
    _anim.dispose();
    super.dispose();
  }

  Widget _buildOverlay(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _close),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 8),
          child: Align(
            alignment: Alignment.topLeft,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(_anim.value);
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * -6),
                    child: Transform.scale(
                      scale: 0.98 + 0.02 * t,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  ),
                );
              },
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: _width,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A211E1C), blurRadius: 24, offset: Offset(0, 12)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final o in widget.options) _optionTile(o)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionTile(TypeFilterOption o) {
    final selected = o.key == widget.selectedKey;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _select(o.key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandTint : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(o.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: selected ? AppColors.brandDark : AppColors.text,
                  )),
            ),
            if (selected) const Icon(Icons.check_rounded, size: 18, color: AppColors.brandDark),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        key: _triggerKey,
        onTap: _toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.section,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _isOpen ? AppColors.brand : AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_selectedLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.text)),
              ),
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
