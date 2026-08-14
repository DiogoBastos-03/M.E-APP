import '../../home/data/home_models.dart';

/// Horário livre do médico (AvailableSlotResponse).
/// Guarda as strings ISO cruas para reenviar EXATAMENTE no POST /appointments,
/// e as versões locais só para exibição.
class AvailableSlot {
  const AvailableSlot({
    required this.startIso,
    required this.endIso,
    required this.start,
    required this.end,
  });

  final String startIso;
  final String endIso;
  final DateTime start; // local, só para mostrar
  final DateTime end;

  /// "HH:mm" no fuso do aparelho.
  String get label =>
      '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

  factory AvailableSlot.fromJson(Map<String, dynamic> j) {
    final s = j['startDatetime'] as String;
    final e = j['endDatetime'] as String;
    return AvailableSlot(
      startIso: s,
      endIso: e,
      start: DateTime.parse(s).toLocal(),
      end: DateTime.parse(e).toLocal(),
    );
  }
}

/// Prontuário (MedicalRecordResponse).
class MedicalRecord {
  const MedicalRecord({
    required this.id,
    this.patientId,
    this.bloodType,
    this.allergies,
    this.chronicConditions,
    this.updatedAt,
  });

  final String id;
  final String? patientId;
  final String? bloodType; // ex.: O_POSITIVE
  final String? allergies;
  final String? chronicConditions;
  final DateTime? updatedAt;

  factory MedicalRecord.fromJson(Map<String, dynamic> j) => MedicalRecord(
        id: j['id'] as String,
        patientId: j['patientId'] as String?,
        bloodType: j['bloodType'] as String?,
        allergies: j['allergies'] as String?,
        chronicConditions: j['chronicConditions'] as String?,
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? '')?.toLocal(),
      );

  /// "O_POSITIVE" -> "O+"
  String? get bloodTypeLabel {
    if (bloodType == null) return null;
    final m = {
      'A_POSITIVE': 'A+', 'A_NEGATIVE': 'A−',
      'B_POSITIVE': 'B+', 'B_NEGATIVE': 'B−',
      'AB_POSITIVE': 'AB+', 'AB_NEGATIVE': 'AB−',
      'O_POSITIVE': 'O+', 'O_NEGATIVE': 'O−',
    };
    return m[bloodType] ?? bloodType;
  }
}

/// Resumo de consulta em SOAP (ConsultationSummaryResponse).
class ConsultationSummary {
  const ConsultationSummary({
    required this.id,
    required this.appointmentId,
    this.subjective,
    this.objective,
    this.assessment,
    this.plan,
    this.isSigned = false,
    this.signedAt,
  });

  final String id;
  final String appointmentId;
  final String? subjective;
  final String? objective;
  final String? assessment;
  final String? plan;
  final bool isSigned;
  final DateTime? signedAt;

  factory ConsultationSummary.fromJson(Map<String, dynamic> j) => ConsultationSummary(
        id: j['id'] as String,
        appointmentId: j['appointmentId'] as String,
        subjective: j['subjective'] as String?,
        objective: j['objective'] as String?,
        assessment: j['assessment'] as String?,
        plan: j['plan'] as String?,
        isSigned: (j['isSigned'] as bool?) ?? false,
        signedAt: DateTime.tryParse((j['signedAt'] as String?) ?? '')?.toLocal(),
      );

  bool _blank(String? s) => s == null || s.trim().isEmpty;
  bool get hasContent => !(_blank(subjective) && _blank(objective) && _blank(assessment) && _blank(plan));
}

/// Pedido de exame (ExamRequestResponse).
class ExamRequestItem {
  const ExamRequestItem({
    required this.id,
    required this.appointmentId,
    required this.examType,
    this.doctorId,
    this.externalDoctorName,
    this.notes,
    this.requestedAt,
  });

  final String id;
  final String appointmentId;
  final String examType;
  final String? doctorId;
  final String? externalDoctorName;
  final String? notes;
  final DateTime? requestedAt;

  factory ExamRequestItem.fromJson(Map<String, dynamic> j) => ExamRequestItem(
        id: j['id'] as String,
        appointmentId: (j['appointmentId'] as String?) ?? '',
        examType: (j['examType'] as String?) ?? 'Exame',
        doctorId: j['doctorId'] as String?,
        externalDoctorName: j['externalDoctorName'] as String?,
        notes: j['notes'] as String?,
        requestedAt: DateTime.tryParse((j['requestedAt'] as String?) ?? '')?.toLocal(),
      );
}

/// Histórico clínico completo (PatientClinicalHistoryResponse).
class ClinicalHistory {
  const ClinicalHistory({
    this.medicalRecord,
    required this.appointments,
    required this.summaries,
    required this.examRequests,
  });

  final MedicalRecord? medicalRecord;
  final List<Appointment> appointments;
  final List<ConsultationSummary> summaries;
  final List<ExamRequestItem> examRequests;

  static List<T> _mapList<T>(dynamic arr, T Function(Map<String, dynamic>) f) =>
      arr is List ? arr.cast<Map<String, dynamic>>().map(f).toList() : <T>[];

  factory ClinicalHistory.fromJson(Map<String, dynamic> j) => ClinicalHistory(
        medicalRecord: j['medicalRecord'] is Map<String, dynamic>
            ? MedicalRecord.fromJson(j['medicalRecord'] as Map<String, dynamic>)
            : null,
        appointments: _mapList(j['appointments'], Appointment.fromJson),
        summaries: _mapList(j['consultationSummaries'], ConsultationSummary.fromJson),
        examRequests: _mapList(j['examRequests'], ExamRequestItem.fromJson),
      );

  ConsultationSummary? summaryFor(String appointmentId) {
    for (final s in summaries) {
      if (s.appointmentId == appointmentId && s.hasContent) return s;
    }
    return null;
  }
}
