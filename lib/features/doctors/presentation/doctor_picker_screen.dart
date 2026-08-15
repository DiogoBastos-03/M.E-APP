import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../access/presentation/access_controller.dart' show Loading;
import '../../access/presentation/widgets/access_common.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/doctor_models.dart';
import '../data/doctors_repository.dart';
import 'doctor_picker_controller.dart';
import 'widgets/doctor_card.dart';

class DoctorPickerScreen extends StatelessWidget {
  const DoctorPickerScreen({super.key, this.selectedDoctorId});

  final String? selectedDoctorId;

  @override
  Widget build(BuildContext context) {
    final repo = DoctorsRepository(context.read<AuthController>().api);
    return ChangeNotifierProvider(
      create: (_) => DoctorPickerController(repo)..init(),
      child: _DoctorPickerView(repository: repo, selectedDoctorId: selectedDoctorId),
    );
  }
}

class _DoctorPickerView extends StatefulWidget {
  const _DoctorPickerView({required this.repository, this.selectedDoctorId});

  final DoctorsRepository repository;
  final String? selectedDoctorId;

  @override
  State<_DoctorPickerView> createState() => _DoctorPickerViewState();
}

class _DoctorPickerViewState extends State<_DoctorPickerView> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      context.read<DoctorPickerController>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DoctorPickerController>();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: _searchField(c),
            ),
            if (c.specialties.isNotEmpty) _specialtyChips(c),
            Expanded(child: _body(c)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
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
          Text(
            'Escolher médico',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(DoctorPickerController c) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _search,
              onChanged: c.onQueryChanged,
              textInputAction: TextInputAction.search,
              style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintText: 'Buscar por nome',
                hintStyle: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          ),
          if (c.query.isNotEmpty)
            InkWell(
              onTap: () {
                _search.clear();
                c.clearQuery();
              },
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 18, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _specialtyChips(DoctorPickerController c) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: c.specialties.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _chip(
              label: 'Todas',
              selected: c.selectedSpecialtyId == null,
              onTap: () => c.selectSpecialty(null),
            );
          }
          final s = c.specialties[i - 1];
          return _chip(
            label: s.name,
            selected: c.selectedSpecialtyId == s.id,
            onTap: () => c.selectSpecialty(c.selectedSpecialtyId == s.id ? null : s.id),
          );
        },
      ),
    );
  }

  Widget _chip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      ),
    );
  }

  Widget _body(DoctorPickerController c) {
    if (c.state == Loading.loading && c.items.isEmpty) return const LoadingState();

    if (c.state == Loading.error && c.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          ErrorState(
            message: c.error ?? 'Não foi possível carregar a lista de médicos.',
            onRetry: c.refresh,
          ),
        ],
      );
    }

    if (c.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: const [
          EmptyState(
            title: 'Nenhum médico encontrado',
            message: 'Tente outro nome ou remova o filtro de especialidade.',
            icon: Icons.search_off,
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: c.refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        itemCount: c.items.length + (c.hasNext ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          if (i >= c.items.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
            );
          }
          final d = c.items[i];
          return DoctorCard(
            doctor: d,
            repository: widget.repository,
            selected: d.id == widget.selectedDoctorId,
            onTap: () => Navigator.of(context).pop<DoctorListItem>(d),
          );
        },
      ),
    );
  }
}
