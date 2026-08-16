import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/teleconsult_models.dart';
import '../data/teleconsult_repository.dart';

/// Entra na sala de vídeo da consulta. A interface do Jitsi abre por cima
/// desta tela; aqui fica só o estado de conexão e as recusas do backend.
class TeleconsultScreen extends StatefulWidget {
  const TeleconsultScreen({
    super.key,
    required this.appointmentId,
    required this.doctorName,
    required this.patientName,
    this.onPayRequested,
  });

  final String appointmentId;
  final String doctorName;
  final String patientName;
  final VoidCallback? onPayRequested;

  @override
  State<TeleconsultScreen> createState() => _TeleconsultScreenState();
}

class _TeleconsultScreenState extends State<TeleconsultScreen> {
  final JitsiMeet _jitsi = JitsiMeet();

  bool _loading = true;
  bool _paymentRequired = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  Future<void> _join() async {
    setState(() {
      _loading = true;
      _error = null;
      _paymentRequired = false;
    });

    final repo = TeleconsultRepository(context.read<AuthController>().api);
    try {
      final room = await repo.get(widget.appointmentId);
      if (!mounted) return;
      await _enterRoom(room);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _paymentRequired = e.response?.statusCode == 402;
        _error = _msg(e);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro inesperado ao abrir a sala.';
      });
    }
  }

  Future<void> _enterRoom(Teleconsultation room) async {
    final options = JitsiMeetConferenceOptions(
      serverURL: room.serverUrl,
      room: room.roomName,
      token: room.token,
      userInfo: JitsiMeetUserInfo(displayName: widget.patientName),
      configOverrides: {
        'subject': 'Consulta com ${widget.doctorName}',
        'prejoinPageEnabled': false,
        'startWithAudioMuted': false,
        'startWithVideoMuted': false,
        'disableDeepLinking': true,
      },
      featureFlags: {
        'invite.enabled': false,
        'add-people.enabled': false,
        'meeting-password.enabled': false,
        'security-options.enabled': false,
        'lobby-mode.enabled': false,
        'recording.enabled': false,
        'live-streaming.enabled': false,
        'video-share.enabled': false,
        'calendar.enabled': false,
        'call-integration.enabled': false,
        'welcomepage.enabled': false,
        'unsaferoomwarning.enabled': false,
        'chat.enabled': true,
        'tile-view.enabled': true,
        'pip.enabled': true,
      },
    );

    final listener = JitsiMeetEventListener(
      readyToClose: () {
        if (mounted) Navigator.of(context).pop(true);
      },
    );

    await _jitsi.join(options, listener);
    if (mounted) setState(() => _loading = false);
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.response?.statusCode == 403) return 'Você não tem acesso a esta consulta.';
    if (e.response?.statusCode == 400) return 'Esta consulta não é uma teleconsulta.';
    return 'Não foi possível abrir a sala.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(child: _body()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.brand),
          const SizedBox(height: 16),
          Text('Conectando à teleconsulta…',
              style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textSecondary)),
        ],
      );
    }

    final error = _error;
    if (error == null) {
      return Text('A consulta foi encerrada.',
          style: GoogleFonts.poppins(fontSize: 13.5, color: AppColors.textSecondary));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _paymentRequired ? const Color(0xFFFEF3C7) : AppColors.section,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: _paymentRequired ? const Color(0xFFF6E1BC) : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _paymentRequired ? 'Pagamento pendente' : 'A sala não está disponível',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _paymentRequired ? const Color(0xFFB45309) : AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(error,
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.5,
                  color: _paymentRequired
                      ? const Color(0xFFB45309)
                      : AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (_paymentRequired && widget.onPayRequested != null)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  widget.onPayRequested!();
                },
                child: const Text('Ir para o pagamento'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(onPressed: _join, child: const Text('Tentar de novo')),
            ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(false),
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
          Text('Teleconsulta',
              style: GoogleFonts.poppins(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text)),
        ],
      ),
    );
  }
}
