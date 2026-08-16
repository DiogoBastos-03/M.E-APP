import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/profile_models.dart';
import 'profile_controller.dart';

/// Resumo de saúde do paciente: o que ele declara e o que o médico registrou,
/// lado a lado e com a origem sempre visível.
class HealthDeclarationSection extends StatelessWidget {
  const HealthDeclarationSection({
    super.key,
    required this.controller,
    required this.health,
  });

  final ProfileController controller;
  final HealthRecord? health;

  @override
  Widget build(BuildContext context) {
    final d = controller.declaration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('MINHA SAÚDE',
                style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary)),
            const Spacer(),
            InkWell(
              onTap: () => _edit(context),
              child: Text(d.isEmpty ? 'Preencher' : 'Editar',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.brand)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: AppColors.border),
            boxShadow: AppTheme.softShadow,
          ),
          padding: const EdgeInsets.all(18),
          child: d.isEmpty && (health?.bloodTypeLabel == null)
              ? _empty(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bloodRow(d),
                    _field('Alergias', d.allergies, health?.allergies),
                    _field('Condições crônicas', d.chronicConditions, health?.chronicConditions),
                    _field('Medicações em uso', d.medications, null),
                    if (d.hasEmergencyContact) _emergency(d),
                    if (d.notes?.trim().isNotEmpty ?? false)
                      _field('Observações', d.notes, null),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Conte o essencial sobre a sua saúde',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text)),
        const SizedBox(height: 6),
        Text('Tipo sanguíneo, alergias, condições e medicações em uso. Em uma emergência, '
            'isso é o que o profissional precisa saber primeiro.',
            style: GoogleFonts.poppins(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: () => _edit(context),
            child: const Text('Preencher agora'),
          ),
        ),
      ],
    );
  }

  Widget _bloodRow(HealthDeclaration d) {
    final label = d.bloodTypeLabel ?? health?.bloodTypeLabel;
    if (label == null) return const SizedBox.shrink();
    final fromPatient = d.bloodTypeLabel != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.brandDark)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tipo sanguíneo',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                _origin(fromPatient),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(String label, String? declared, String? clinical) {
    final hasDeclared = declared?.trim().isNotEmpty ?? false;
    final hasClinical = clinical?.trim().isNotEmpty ?? false;
    if (!hasDeclared && !hasClinical) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 4),
          if (hasDeclared) ...[
            Text(declared!.trim(),
                style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            _origin(true),
          ],
          if (hasClinical) ...[
            if (hasDeclared) const SizedBox(height: 8),
            Text(clinical!.trim(),
                style: GoogleFonts.poppins(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: 3),
            _origin(false),
          ],
        ],
      ),
    );
  }

  Widget _emergency(HealthDeclaration d) {
    final parts = [d.emergencyContactName, d.emergencyContactPhone]
        .where((p) => p?.trim().isNotEmpty ?? false)
        .map((p) => p!.trim())
        .join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          const Icon(Icons.emergency_outlined, size: 18, color: AppColors.stateDanger),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contato de emergência',
                    style: GoogleFonts.poppins(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
                const SizedBox(height: 2),
                Text(parts,
                    style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _origin(bool fromPatient) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(fromPatient ? Icons.person_outline : Icons.medical_services_outlined,
            size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(fromPatient ? 'informado por você' : 'registrado pelo seu médico',
            style: GoogleFonts.poppins(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HealthDeclarationSheet(controller: controller),
    );
  }
}

class _HealthDeclarationSheet extends StatefulWidget {
  const _HealthDeclarationSheet({required this.controller});
  final ProfileController controller;

  @override
  State<_HealthDeclarationSheet> createState() => _HealthDeclarationSheetState();
}

class _HealthDeclarationSheetState extends State<_HealthDeclarationSheet> {
  late String? _bloodType;
  late final TextEditingController _allergies;
  late final TextEditingController _conditions;
  late final TextEditingController _medications;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.controller.declaration;
    _bloodType = d.bloodType;
    _allergies = TextEditingController(text: d.allergies ?? '');
    _conditions = TextEditingController(text: d.chronicConditions ?? '');
    _medications = TextEditingController(text: d.medications ?? '');
    _contactName = TextEditingController(text: d.emergencyContactName ?? '');
    _contactPhone = TextEditingController(text: d.emergencyContactPhone ?? '');
  }

  @override
  void dispose() {
    _allergies.dispose();
    _conditions.dispose();
    _medications.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final err = await widget.controller.saveDeclaration(HealthDeclaration(
      bloodType: _bloodType,
      allergies: _allergies.text.trim(),
      chronicConditions: _conditions.text.trim(),
      medications: _medications.text.trim(),
      emergencyContactName: _contactName.text.trim(),
      emergencyContactPhone: _contactPhone.text.trim(),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      Navigator.of(context).pop();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.stateDanger,
      content: Text(err, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Meus dados de saúde',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
            const SizedBox(height: 4),
            Text('Fica marcado como informado por você. Seu médico continua registrando o '
                'prontuário clínico à parte.',
                style: GoogleFonts.poppins(
                    fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Tipo sanguíneo'),
                    const SizedBox(height: 8),
                    _bloodPicker(),
                    const SizedBox(height: 16),
                    _label('Alergias'),
                    const SizedBox(height: 8),
                    _input(_allergies, 'Medicamentos, alimentos, outras'),
                    const SizedBox(height: 16),
                    _label('Condições crônicas'),
                    const SizedBox(height: 8),
                    _input(_conditions, 'Diabetes, hipertensão, asma…'),
                    const SizedBox(height: 16),
                    _label('Medicações em uso'),
                    const SizedBox(height: 8),
                    _input(_medications, 'Nome e dose, se souber'),
                    const SizedBox(height: 16),
                    _label('Contato de emergência'),
                    const SizedBox(height: 8),
                    _input(_contactName, 'Nome', lines: 1),
                    const SizedBox(height: 8),
                    _input(_contactPhone, 'Telefone', lines: 1, phone: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text));

  Widget _bloodPicker() {
    final entries = HealthDeclaration.bloodTypes.entries.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in entries)
          GestureDetector(
            onTap: () => setState(() => _bloodType = _bloodType == e.key ? null : e.key),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _bloodType == e.key ? AppColors.brand : AppColors.card,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: _bloodType == e.key ? AppColors.brand : AppColors.border),
              ),
              child: Text(e.value,
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _bloodType == e.key ? Colors.white : AppColors.text)),
            ),
          ),
      ],
    );
  }

  Widget _input(TextEditingController c, String hint, {int lines = 3, bool phone = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: c,
        maxLines: lines,
        keyboardType: phone ? TextInputType.phone : TextInputType.multiline,
        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.text),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
