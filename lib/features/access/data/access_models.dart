import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Seções do prontuário (RecordSection do backend).
enum RecordSection {
  medicalInfo('MEDICAL_INFO', 'Dados médicos', 'Tipo sanguíneo, alergias e condições'),
  appointments('APPOINTMENTS', 'Consultas', 'Agendamentos e histórico de consultas'),
  consultationSummaries('CONSULTATION_SUMMARIES', 'Resumos de consulta', 'Anotações clínicas (SOAP)'),
  examRequests('EXAM_REQUESTS', 'Pedidos de exame', 'Exames solicitados pelo médico'),
  examResults('EXAM_RESULTS', 'Resultados de exames', 'Laudos e resultados de exames');

  const RecordSection(this.wire, this.label, this.hint);
  final String wire;
  final String label;
  final String hint;

  static RecordSection? fromWire(String w) {
    for (final s in values) {
      if (s.wire == w) return s;
    }
    return null;
  }

  static List<RecordSection> parseList(dynamic arr) {
    if (arr is! List) return const [];
    return arr
        .map((e) => fromWire(e.toString()))
        .whereType<RecordSection>()
        .toList();
  }
}

/// Status da concessão (AccessStatus do backend).
enum AccessStatus {
  pending('PENDING'),
  approved('APPROVED'),
  denied('DENIED'),
  revoked('REVOKED'),
  unknown('');

  const AccessStatus(this.wire);
  final String wire;

  static AccessStatus fromWire(String? w) {
    for (final s in values) {
      if (s.wire == w) return s;
    }
    return AccessStatus.unknown;
  }
}

/// Ação registrada na auditoria (RecordAccessLog.AccessAction).
enum AccessAction {
  view('VIEW', 'Visualizou', Icons.visibility_outlined, AppColors.tealDark),
  download('DOWNLOAD', 'Baixou', Icons.download_outlined, AppColors.statePending),
  upload('UPLOAD', 'Publicou', Icons.cloud_upload_outlined, AppColors.brand),
  create('CREATE', 'Criou', Icons.add_circle_outline, AppColors.tealDark),
  update('UPDATE', 'Atualizou', Icons.edit_outlined, AppColors.tealDark),
  delete('DELETE', 'Removeu', Icons.delete_outline, AppColors.stateDanger),
  unknown('', 'Acessou', Icons.circle_outlined, AppColors.textSecondary);

  const AccessAction(this.wire, this.label, this.icon, this.color);
  final String wire;
  final String label;
  final IconData icon;
  final Color color;

  static AccessAction fromWire(String? w) {
    for (final a in values) {
      if (a.wire == w) return a;
    }
    return AccessAction.unknown;
  }
}

/// Concessão / pedido de acesso (AccessGrantResponse).
class AccessGrant {
  const AccessGrant({
    required this.id,
    this.doctorId,
    this.clinicId,
    required this.sections,
    required this.status,
    this.requestMessage,
    this.grantedAt,
    this.respondedAt,
    this.expiresAt,
    this.revokedAt,
    required this.active,
  });

  final String id;
  final String? doctorId;
  final String? clinicId;
  final List<RecordSection> sections;
  final AccessStatus status;
  final String? requestMessage;
  final DateTime? grantedAt;
  final DateTime? respondedAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final bool active;

  static DateTime? _dt(dynamic v) =>
      (v is String && v.isNotEmpty) ? DateTime.tryParse(v)?.toLocal() : null;

  factory AccessGrant.fromJson(Map<String, dynamic> j) => AccessGrant(
        id: j['id'] as String,
        doctorId: j['doctorId'] as String?,
        clinicId: j['clinicId'] as String?,
        sections: RecordSection.parseList(j['sections']),
        status: AccessStatus.fromWire(j['status'] as String?),
        requestMessage: j['requestMessage'] as String?,
        grantedAt: _dt(j['grantedAt']),
        respondedAt: _dt(j['respondedAt']),
        expiresAt: _dt(j['expiresAt']),
        revokedAt: _dt(j['revokedAt']),
        // O backend serializa o campo como "isActive" (o OpenAPI/springdoc
        // reporta "active", mas o JSON real usa "isActive"). Lemos os dois
        // por segurança.
        active: (j['isActive'] as bool?) ?? (j['active'] as bool?) ?? false,
      );
}

/// Registro de auditoria (RecordAccessLogResponse).
class RecordAccessLog {
  const RecordAccessLog({
    required this.id,
    this.accessorUserId,
    required this.accessorRole,
    required this.section,
    required this.action,
    this.detail,
    required this.occurredAt,
  });

  final String id;
  final String? accessorUserId;
  final String accessorRole;
  final RecordSection? section;
  final AccessAction action;
  final String? detail;
  final DateTime occurredAt;

  factory RecordAccessLog.fromJson(Map<String, dynamic> j) => RecordAccessLog(
        id: j['id'] as String,
        accessorUserId: j['accessorUserId'] as String?,
        accessorRole: (j['accessorRole'] as String?) ?? '',
        section: RecordSection.fromWire((j['section'] as String?) ?? ''),
        action: AccessAction.fromWire(j['action'] as String?),
        detail: j['detail'] as String?,
        occurredAt:
            DateTime.tryParse((j['occurredAt'] as String?) ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// Dados leves de médico (DoctorResponse) e clínica (ClinicResponse) para
/// resolver nomes/especialidades a partir de doctorId / clinicId / userId.
class DoctorLite {
  const DoctorLite(this.id, this.userId, this.fullName, this.specialty, this.crm,
      {this.consultationPriceCents});
  final String id;
  final String? userId;
  final String fullName;
  final String? specialty;
  final String? crm;
  final int? consultationPriceCents;

  bool get acceptsTelemedicine => (consultationPriceCents ?? 0) > 0;

  factory DoctorLite.fromJson(Map<String, dynamic> j) => DoctorLite(
        j['id'] as String,
        j['userId'] as String?,
        (j['fullName'] as String?) ?? 'Médico',
        j['rqe'] as String?,
        j['crm'] as String?,
        consultationPriceCents: (j['consultationPriceCents'] as num?)?.toInt(),
      );
}

class ClinicLite {
  const ClinicLite(this.id, this.corporateName);
  final String id;
  final String corporateName;

  factory ClinicLite.fromJson(Map<String, dynamic> j) => ClinicLite(
        j['id'] as String,
        (j['corporateName'] as String?) ?? 'Clínica',
      );
}

/// Identificação do solicitante/detentor do acesso, resolvida via diretório.
class Requester {
  const Requester({required this.name, required this.subtitle, this.crm, this.initials = '?'});
  final String name;
  final String subtitle;
  final String? crm;
  final String initials;
}
