import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../health/presentation/health_format.dart';
import '../../home/data/home_models.dart';
import '../data/payments_repository.dart';

/// Pagamento da teleconsulta. Devolve `true` quando o pagamento é confirmado.
class PaymentScreen extends StatefulWidget {
  const PaymentScreen({
    super.key,
    required this.appointment,
    required this.doctorName,
  });

  final Appointment appointment;
  final String doctorName;

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late PaymentsRepository _repo;
  late PaymentInfo? _payment;
  bool _submitting = false;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _payment = widget.appointment.payment;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repo = PaymentsRepository(context.read<AuthController>().api);
  }

  Future<void> _pay() async {
    final payment = _payment;
    if (payment == null) return;

    setState(() => _submitting = true);
    try {
      final paid = await _repo.simulatePay(payment.id);
      if (!mounted) return;
      setState(() {
        _payment = paid;
        _confirmed = paid.isPaid;
        _submitting = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError(_msg(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showError('Erro inesperado ao confirmar o pagamento.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.stateDanger,
      content: Text(message, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
    ));
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.response?.statusCode == 404) {
      return 'A simulação de pagamento não está habilitada neste servidor.';
    }
    return 'Não foi possível confirmar o pagamento.';
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: [
                  if (payment == null)
                    _hintBox('Não encontramos o pagamento desta consulta.')
                  else ...[
                    _summary(payment),
                    const SizedBox(height: 16),
                    if (!_confirmed) _testEnvironmentNotice(),
                  ],
                ],
              ),
            ),
            if (payment != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _confirmed
                        ? () => Navigator.of(context).pop(true)
                        : (_submitting ? null : _pay),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : Text(_confirmed ? 'Voltar' : 'Simular pagamento'),
                  ),
                ),
              ),
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
            onTap: () => Navigator.of(context).pop(_confirmed),
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
          Text('Pagamento',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        ],
      ),
    );
  }

  Widget _summary(PaymentInfo payment) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: AppColors.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Teleconsulta',
              style: GoogleFonts.poppins(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(widget.doctorName,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text)),
          const SizedBox(height: 2),
          Text(friendlyDateTime(widget.appointment.start),
              style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          Text(brl(payment.amountCents),
              style: GoogleFonts.poppins(
                  fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.text)),
          const SizedBox(height: 10),
          if (_confirmed)
            Row(children: [
              const Icon(Icons.check_circle, size: 18, color: AppColors.tealDark),
              const SizedBox(width: 6),
              Text('Pagamento confirmado',
                  style: GoogleFonts.poppins(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.tealDark)),
            ])
          else if (payment.expiresAt != null)
            Text('Conclua até ${p2(payment.expiresAt!.hour)}:${p2(payment.expiresAt!.minute)} '
                'para garantir o horário.',
                style: GoogleFonts.poppins(fontSize: 12.5, color: AppColors.statePending)),
        ],
      ),
    );
  }

  Widget _testEnvironmentNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(AppTheme.radiusInner),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_outlined, size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ambiente de testes: nenhuma cobrança real é feita nesta etapa.',
              style: GoogleFonts.poppins(
                  fontSize: 12.5, height: 1.5, color: const Color(0xFFB45309)),
            ),
          ),
        ],
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
      child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: AppColors.textSecondary)),
    );
  }
}
