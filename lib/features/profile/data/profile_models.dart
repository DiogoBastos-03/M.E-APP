import 'dart:typed_data';

/// Dados pessoais do paciente (PatientResponse).
class PatientAccount {
  const PatientAccount({
    required this.userId,
    required this.fullName,
    required this.cpfMasked,
    required this.email,
    required this.dateOfBirth,
    required this.isMinor,
    this.phoneNumber,
  });

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
