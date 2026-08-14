import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../access/data/access_models.dart';
import '../../home/data/home_models.dart';
import '../data/history_models.dart';
import 'history_controller.dart';

/// Formulário mínimo de agendamento — cria a consulta DE VERDADE (POST /appointments).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.controller, required this.patientId});
  final HistoryController controller;
  final String patientId;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<DoctorLite>? _doctors;
  String? _loadError;
  DoctorLite? _doctor;
  AppointmentType _type = AppointmentType.inPerson;
  DateTime? _date;
  bool _submitting = false;

  // Horários livres do médico na data escolhida.
  List<AvailableSlot>? _slots;
  bool _slotsLoading = false;
  String? _slotsError;
  AvailableSlot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    try {
      final d = await widget.controller.loadDoctors();
      if (!mounted) return;
      setState(() => _doctors = d);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Não foi possível carregar a lista de médicos.');
    }
  }

  bool get _teleUnavailable =>
      _type == AppointmentType.telemedicine && _doctor != null && !_doctor!.acceptsTelemedicine;

  bool get _canSubmit =>
      _doctor != null && _selectedSlot != null && !_teleUnavailable && !_submitting;

  /// (Re)carrega os slots livres do médico na data escolhida.
  Future<void> _loadSlots() async {
    setState(() {
      _selectedSlot = null;
      _slots = null;
      _slotsError = null;
    });
    final doctor = _doctor;
    final date = _date;
    if (doctor == null || date == null) return;
    setState(() => _slotsLoading = true);
    try {
      final slots = await widget.controller.loadSlots(doctor.id, date);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        _slotsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _slotsError = 'Não foi possível carregar os horários disponíveis.';
        _slotsLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    final slot = _selectedSlot!;
    setState(() => _submitting = true);
    final err = await widget.controller.schedule(
      patientId: widget.patientId,
      doctorId: _doctor!.id,
      type: _type,
      slot: slot,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.tealDark,
        content: Text('Consulta agendada com sucesso.', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.stateDanger,
        content: Text(err, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.card, shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.chevron_left, size: 22, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Agendar consulta',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  _label('Médico'),
                  const SizedBox(height: 8),
                  _doctorField(),
                  const SizedBox(height: 20),
                  _label('Tipo de consulta'),
                  const SizedBox(height: 8),
                  _typeToggle(),
                  if (_teleUnavailable) ...[
                    const SizedBox(height: 8),
                    Text('Este médico não oferece teleconsulta. Escolha Presencial ou outro médico.',
                        style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.stateDanger)),
                  ],
                  const SizedBox(height: 20),
                  _label('Data'),
                  const SizedBox(height: 8),
                  _pickerField(
                    icon: Icons.calendar_today_outlined,
                    text: _date == null
                        ? 'Escolha a data'
                        : '${_date!.day}/${_date!.month}/${_date!.year}',
                    onTap: _pickDate,
                  ),
                  const SizedBox(height: 20),
                  _label('Horários disponíveis'),
                  const SizedBox(height: 8),
                  _slotsSection(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Confirmar agendamento'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text));

  Widget _doctorField() {
    if (_loadError != null) {
      return Text(_loadError!, style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.stateDanger));
    }
    if (_doctors == null) {
      return const SizedBox(height: 40, child: Center(child: CircularProgressIndicator(color: AppColors.brand)));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DoctorLite>(
          isExpanded: true,
          value: _doctor,
          hint: Text('Selecione um médico', style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
          items: [
            for (final d in _doctors!)
              DropdownMenuItem(
                value: d,
                child: Text('${d.fullName}${d.specialty != null ? ' · ${d.specialty}' : ''}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text)),
              ),
          ],
          onChanged: (v) {
            setState(() => _doctor = v);
            _loadSlots();
          },
        ),
      ),
    );
  }

  Widget _typeToggle() {
    return Row(
      children: [
        for (final t in [AppointmentType.inPerson, AppointmentType.telemedicine])
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => setState(() => _type = t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: _type == t ? AppColors.brand : AppColors.card,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _type == t ? AppColors.brand : AppColors.border),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(t.icon, size: 16, color: _type == t ? Colors.white : AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(t.label,
                      style: GoogleFonts.poppins(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _type == t ? Colors.white : AppColors.text)),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _slotsSection() {
    if (_doctor == null || _date == null) {
      return _hintBox('Escolha o médico e a data para ver os horários livres.');
    }
    if (_slotsLoading) {
      return const SizedBox(
        height: 40,
        child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
      );
    }
    if (_slotsError != null) {
      return Text(_slotsError!,
          style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.stateDanger));
    }
    final slots = _slots ?? const <AvailableSlot>[];
    if (slots.isEmpty) {
      return _hintBox('Sem horários disponíveis neste dia.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final s in slots) _slotChip(s)],
    );
  }

  Widget _slotChip(AvailableSlot s) {
    final selected = _selectedSlot != null && _selectedSlot!.startIso == s.startIso;
    return GestureDetector(
      onTap: () => setState(() => _selectedSlot = s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.brand : AppColors.border),
        ),
        child: Text(s.label,
            style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.text)),
      ),
    );
  }

  Widget _hintBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text,
          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
    );
  }

  Widget _pickerField({required IconData icon, required String text, required VoidCallback onTap}) {
    final filled = !text.startsWith('Escolha');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.section,
          borderRadius: BorderRadius.circular(AppTheme.radiusInner),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(text,
              style: GoogleFonts.poppins(
                  fontSize: 14, color: filled ? AppColors.text : AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 180)),
    );
    if (d != null) {
      setState(() => _date = d);
      _loadSlots();
    }
  }
}
