import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../doctors/data/doctor_models.dart';
import '../../doctors/presentation/doctor_picker_screen.dart';
import '../../home/data/home_models.dart';
import '../../payments/presentation/payment_screen.dart';
import '../data/history_models.dart';
import 'health_format.dart';
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
  DoctorListItem? _doctor;
  AppointmentType _type = AppointmentType.inPerson;
  DateTime? _date;
  bool _submitting = false;

  // Horários livres do médico na data escolhida.
  List<AvailableSlot>? _slots;
  bool _slotsLoading = false;
  String? _slotsError;
  AvailableSlot? _selectedSlot;

  Future<void> _pickDoctor() async {
    final picked = await Navigator.of(context).push<DoctorListItem>(
      MaterialPageRoute(
        builder: (_) => DoctorPickerScreen(selectedDoctorId: _doctor?.id),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _doctor = picked);
    _loadSlots();
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
    final doctorName = _doctor!.fullName;

    final autorizou = await _confirmNameSharing(doctorName);
    if (autorizou != true || !mounted) return;

    setState(() => _submitting = true);
    final result = await widget.controller.schedule(
      patientId: widget.patientId,
      doctorId: _doctor!.id,
      type: _type,
      slot: slot,
      sharePatientName: true,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    final error = result.error;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.stateDanger,
        content: Text(error, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      ));
      return;
    }

    final created = result.created;
    Navigator.of(context).pop();

    if (created != null && created.needsPayment) {
      await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PaymentScreen(appointment: created, doctorName: doctorName),
      ));
      await widget.controller.load();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.tealDark,
      content: Text('Consulta agendada com sucesso.', style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
    ));
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
            if (_showsPrice) _priceSummary(),
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
                      : Text(_showsPrice ? 'Confirmar e pagar' : 'Confirmar agendamento'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// O nome do paciente só chega ao médico com autorização explícita, e ela é
  /// dada aqui, por consulta. Sem o aceite, nada é enviado ao servidor.
  Future<bool?> _confirmNameSharing(String doctorName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusCard)),
        title: Text('Compartilhar seu nome',
            style: GoogleFonts.poppins(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ao agendar, $doctorName passa a ver o seu nome nesta consulta.',
                style: GoogleFonts.poppins(fontSize: 13.5, height: 1.5, color: AppColors.text)),
            const SizedBox(height: 10),
            Text('Vale só para esta consulta. Seu prontuário, exames e histórico '
                'continuam privados até você liberar em Acessos.',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, height: 1.5, color: AppColors.textSecondary)),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: GoogleFonts.poppins(
                    fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(minimumSize: const Size(140, 46)),
            child: const Text('Autorizar e agendar'),
          ),
        ],
      ),
    );
  }

  bool get _showsPrice =>
      _type == AppointmentType.telemedicine &&
      _doctor?.consultationPriceCents != null &&
      _selectedSlot != null;

  Widget _priceSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.section,
          borderRadius: BorderRadius.circular(AppTheme.radiusInner),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Valor da teleconsulta',
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
                const Spacer(),
                Text(brl(_doctor!.consultationPriceCents!),
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.text)),
              ],
            ),
            const SizedBox(height: 4),
            Text('O pagamento é solicitado logo após a confirmação.',
                style: GoogleFonts.poppins(fontSize: 11.5, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text));

  Widget _doctorField() {
    final doctor = _doctor;
    if (doctor == null) {
      return _pickerField(
        icon: Icons.person_outline,
        text: 'Escolha o médico',
        onTap: _pickDoctor,
      );
    }
    return GestureDetector(
      onTap: _pickDoctor,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.section,
          borderRadius: BorderRadius.circular(AppTheme.radiusInner),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctor.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
                  const SizedBox(height: 2),
                  Text(doctor.specialtyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
                  if (doctor.acceptsTelemedicine) ...[
                    const SizedBox(height: 2),
                    Text('Teleconsulta ${brl(doctor.consultationPriceCents!)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.tealDark)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('Trocar',
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.brand)),
          ],
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
