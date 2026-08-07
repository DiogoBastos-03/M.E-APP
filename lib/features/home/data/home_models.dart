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
class Appointment {
  const Appointment({
    required this.id,
    required this.doctorId,
    required this.type,
    required this.status,
    required this.start,
    required this.end,
    this.paymentStatus,
  });

  final String id;
  final String? doctorId;
  final AppointmentType type;
  final ApptStatus status;
  final DateTime start;
  final DateTime end;

  /// Status do pagamento da teleconsulta (PENDING/PAID/REFUNDED/CANCELED), se houver.
  final String? paymentStatus;

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
      paymentStatus: payment is Map<String, dynamic> ? payment['status'] as String? : null,
    );
  }

  bool get isUpcoming => status == ApptStatus.scheduled && start.isAfter(DateTime.now());
  bool get isPaymentPending => paymentStatus == 'PENDING';
}
