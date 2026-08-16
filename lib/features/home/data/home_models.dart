import 'package:flutter/material.dart';

/// Perfil do paciente (PatientResponse do backend).
class PatientProfile {
  const PatientProfile({required this.id, required this.fullName});
  final String id;
  final String fullName;

  factory PatientProfile.fromJson(Map<String, dynamic> j) => PatientProfile(
        id: j['id'] as String,
        fullName: (j['fullName'] as String?) ?? 'Paciente',
      );

  String get firstName {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    return parts.isEmpty ? fullName : parts.first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

enum AppointmentType {
  inPerson('IN_PERSON', 'Presencial', Icons.local_hospital_outlined),
  telemedicine('TELEMEDICINE', 'Telemedicina', Icons.videocam_outlined),
  unknown('', 'Consulta', Icons.event_outlined);

  const AppointmentType(this.wire, this.label, this.icon);
  final String wire;
  final String label;
  final IconData icon;

  static AppointmentType fromWire(String? w) =>
      values.firstWhere((t) => t.wire == w, orElse: () => AppointmentType.unknown);
}

enum ApptStatus {
  scheduled('SCHEDULED'),
  canceled('CANCELED'),
  completed('COMPLETED'),
  unknown('');

  const ApptStatus(this.wire);
  final String wire;

  static ApptStatus fromWire(String? w) =>
      values.firstWhere((s) => s.wire == w, orElse: () => ApptStatus.unknown);
}

/// Consulta (AppointmentResponse do backend).
enum PaymentState {
  pending('PENDING'),
  paid('PAID'),
  refunded('REFUNDED'),
  canceled('CANCELED'),
  expired('EXPIRED'),
  unknown('');

  const PaymentState(this.wire);
  final String wire;

  static PaymentState fromWire(String? w) =>
      PaymentState.values.firstWhere((s) => s.wire == w, orElse: () => PaymentState.unknown);
}

/// Pagamento da teleconsulta. Só acompanha a consulta quando o backend
/// responde ao próprio paciente.
class PaymentInfo {
  const PaymentInfo({
    required this.id,
    required this.amountCents,
    required this.currency,
    required this.status,
    this.checkoutUrl,
    this.expiresAt,
    this.paidAt,
  });

  final String id;
  final int amountCents;
  final String currency;
  final PaymentState status;
  final String? checkoutUrl;
  final DateTime? expiresAt;
  final DateTime? paidAt;

  bool get isPending => status == PaymentState.pending;
  bool get isPaid => status == PaymentState.paid;

  factory PaymentInfo.fromJson(Map<String, dynamic> j) => PaymentInfo(
        id: j['id'] as String,
        amountCents: (j['amountCents'] as num?)?.toInt() ?? 0,
        currency: (j['currency'] as String?) ?? 'BRL',
        status: PaymentState.fromWire(j['status'] as String?),
        checkoutUrl: j['checkoutUrl'] as String?,
        expiresAt: DateTime.tryParse((j['expiresAt'] as String?) ?? '')?.toLocal(),
        paidAt: DateTime.tryParse((j['paidAt'] as String?) ?? '')?.toLocal(),
      );
}

class Appointment {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.type,
    required this.status,
    required this.start,
    required this.end,
    this.payment,
    this.patientNameShared = false,
  });

  final String id;
  final String? doctorId;
  final AppointmentType type;
  final ApptStatus status;
  final DateTime start;
  final DateTime end;
  final PaymentInfo? payment;

  /// O paciente autorizou este médico a ver o nome dele nesta consulta.
  final bool patientNameShared;

  static DateTime _dt(dynamic v) =>
      DateTime.tryParse(v?.toString() ?? '')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory Appointment.fromJson(Map<String, dynamic> j) {
    final payment = j['payment'];
    return Appointment(
      id: j['id'] as String,
      doctorId: j['doctorId'] as String?,
      type: AppointmentType.fromWire(j['appointmentType'] as String?),
      status: ApptStatus.fromWire(j['status'] as String?),
      start: _dt(j['startDatetime']),
      end: _dt(j['endDatetime']),
      payment: payment is Map<String, dynamic> ? PaymentInfo.fromJson(payment) : null,
      patientNameShared: (j['patientNameShared'] as bool?) ?? false,
    );
  }

  /// Vale até o fim da consulta, não até o início: uma consulta em andamento
  /// continua sendo a próxima — é justamente quando o paciente precisa entrar.
  bool get isUpcoming => status == ApptStatus.scheduled && end.isAfter(DateTime.now());
  bool get isPaymentPending => payment?.isPending ?? false;

  bool get isTelemedicine => type == AppointmentType.telemedicine;
  bool get needsPayment => isTelemedicine && isPaymentPending;
  bool get isPaidTele => isTelemedicine && (payment?.isPaid ?? false);

  /// A sala abre 15 minutos antes e fecha 30 minutos depois — a mesma janela
  /// que o backend valida em GET /appointments/{id}/teleconsultation.
  bool get roomIsOpen {
    if (!isPaidTele || status != ApptStatus.scheduled) return false;
    final now = DateTime.now();
    return now.isAfter(start.subtract(const Duration(minutes: 15))) &&
        now.isBefore(end.add(const Duration(minutes: 30)));
  }
}
