import 'dart:typed_data';

/// Dados pessoais do paciente (PatientResponse).
class PatientAccount {
  const PatientAccount({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.cpfMasked,
    required this.email,
    required this.dateOfBirth,
    required this.isMinor,
    this.phoneNumber,
  });

  final String id;
  final String userId;
  final String fullName;
  final String cpfMasked;
  final String email;
  final DateTime dateOfBirth;
  final bool isMinor;
  final String? phoneNumber;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  int get age {
    final now = DateTime.now();
    var a = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      a--;
    }
    return a;
  }

  factory PatientAccount.fromJson(Map<String, dynamic> j) => PatientAccount(
        id: j['id'] as String,
        userId: j['userId'] as String,
        fullName: (j['fullName'] as String?) ?? 'Paciente',
        cpfMasked: (j['cpfMasked'] as String?) ?? '—',
        email: (j['email'] as String?) ?? '',
        dateOfBirth: DateTime.parse(j['dateOfBirth'] as String),
        isMinor: (j['isMinor'] as bool?) ?? false,
        phoneNumber: j['phoneNumber'] as String?,
      );
}

/// Dados de saúde do prontuário (MedicalRecordResponse) — leitura p/ o paciente.
class HealthRecord {
  const HealthRecord({this.bloodType, this.allergies, this.chronicConditions, this.updatedAt});

  final String? bloodType; // ex.: O_POSITIVE
  final String? allergies;
  final String? chronicConditions;
  final DateTime? updatedAt;

  /// "O_POSITIVE" -> "O+"
  String? get bloodTypeLabel {
    if (bloodType == null) return null;
    const m = {
      'A_POSITIVE': 'A+', 'A_NEGATIVE': 'A−',
      'B_POSITIVE': 'B+', 'B_NEGATIVE': 'B−',
      'AB_POSITIVE': 'AB+', 'AB_NEGATIVE': 'AB−',
      'O_POSITIVE': 'O+', 'O_NEGATIVE': 'O−',
    };
    return m[bloodType] ?? bloodType;
  }

  factory HealthRecord.fromJson(Map<String, dynamic> j) => HealthRecord(
        bloodType: j['bloodType'] as String?,
        allergies: j['allergies'] as String?,
        chronicConditions: j['chronicConditions'] as String?,
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? '')?.toLocal(),
      );
}

/// O que o paciente declara sobre a própria saúde. Fica separado do prontuário
/// para que o médico saiba o que foi registrado por ele e o que veio do paciente.
class HealthDeclaration {
  const HealthDeclaration({
    this.bloodType,
    this.allergies,
    this.chronicConditions,
    this.medications,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.notes,
    this.updatedAt,
  });

  final String? bloodType;
  final String? allergies;
  final String? chronicConditions;
  final String? medications;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? notes;
  final DateTime? updatedAt;

  static const bloodTypes = <String, String>{
    'A_POSITIVE': 'A+', 'A_NEGATIVE': 'A−',
    'B_POSITIVE': 'B+', 'B_NEGATIVE': 'B−',
    'AB_POSITIVE': 'AB+', 'AB_NEGATIVE': 'AB−',
    'O_POSITIVE': 'O+', 'O_NEGATIVE': 'O−',
  };

  String? get bloodTypeLabel => bloodType == null ? null : bloodTypes[bloodType] ?? bloodType;

  bool get isEmpty =>
      bloodType == null &&
      (allergies?.trim().isEmpty ?? true) &&
      (chronicConditions?.trim().isEmpty ?? true) &&
      (medications?.trim().isEmpty ?? true) &&
      (emergencyContactName?.trim().isEmpty ?? true) &&
      (emergencyContactPhone?.trim().isEmpty ?? true) &&
      (notes?.trim().isEmpty ?? true);

  bool get hasEmergencyContact =>
      (emergencyContactName?.trim().isNotEmpty ?? false) ||
      (emergencyContactPhone?.trim().isNotEmpty ?? false);

  factory HealthDeclaration.fromJson(Map<String, dynamic> j) => HealthDeclaration(
        bloodType: j['bloodType'] as String?,
        allergies: j['allergies'] as String?,
        chronicConditions: j['chronicConditions'] as String?,
        medications: j['medications'] as String?,
        emergencyContactName: j['emergencyContactName'] as String?,
        emergencyContactPhone: j['emergencyContactPhone'] as String?,
        notes: j['notes'] as String?,
        updatedAt: DateTime.tryParse((j['updatedAt'] as String?) ?? '')?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'bloodType': bloodType,
        'allergies': allergies,
        'chronicConditions': chronicConditions,
        'medications': medications,
        'emergencyContactName': emergencyContactName,
        'emergencyContactPhone': emergencyContactPhone,
        'notes': notes,
      };

  HealthDeclaration copyWith({
    String? bloodType,
    String? allergies,
    String? chronicConditions,
    String? medications,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? notes,
    bool clearBloodType = false,
  }) =>
      HealthDeclaration(
        bloodType: clearBloodType ? null : (bloodType ?? this.bloodType),
        allergies: allergies ?? this.allergies,
        chronicConditions: chronicConditions ?? this.chronicConditions,
        medications: medications ?? this.medications,
        emergencyContactName: emergencyContactName ?? this.emergencyContactName,
        emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
        notes: notes ?? this.notes,
        updatedAt: updatedAt,
      );
}

/// Setup do 2FA (secret + URI otpauth para o app autenticador).
class TwoFactorSetup {
  const TwoFactorSetup(this.secret, this.otpauthUri);
  final String secret;
  final String otpauthUri;

  factory TwoFactorSetup.fromJson(Map<String, dynamic> j) =>
      TwoFactorSetup((j['secret'] as String?) ?? '', (j['otpauthUri'] as String?) ?? '');
}

/// Export LGPD (bytes do JSON + nome do arquivo).
class ExportedData {
  const ExportedData(this.bytes, this.fileName);
  final Uint8List bytes;
  final String fileName;
}
