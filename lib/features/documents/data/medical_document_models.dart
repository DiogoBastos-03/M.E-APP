import 'package:flutter/material.dart';
import 'dart:typed_data';

/// Documento médico emitido para o paciente (MedicalDocumentResponse).
class MedicalDocument {
  const MedicalDocument({
    required this.id,
    required this.documentType,
    required this.status,
    required this.issuedAt,
    required this.validationCode,
    required this.hasPdf,
    this.doctorId,
    this.externalDoctorName,
  });

  final String id;
  final String documentType; // ex.: RECEITA_SIMPLES
  final String status; // ex.: SIGNED
  final DateTime issuedAt;
  final String validationCode;
  final bool hasPdf;
  final String? doctorId;
  final String? externalDoctorName;

  bool get isFinal => status == 'SIGNED' || status == 'ISSUED';
  bool get isCanceled => status == 'CANCELED';

  /// Rótulo amigável do tipo.
  String get typeLabel {
    switch (documentType) {
      case 'RECEITA_SIMPLES':
        return 'Receita';
      case 'RECEITA_CONTROLE_ESPECIAL':
        return 'Receita de controle especial';
      case 'ATESTADO':
        return 'Atestado';
      case 'PEDIDO_EXAME':
        return 'Pedido de exame';
      case 'SOLICITACAO_PROCEDIMENTO':
        return 'Solicitação de procedimento';
      default:
        return 'Documento médico';
    }
  }

  IconData get typeIcon {
    switch (documentType) {
      case 'RECEITA_SIMPLES':
      case 'RECEITA_CONTROLE_ESPECIAL':
        return Icons.medication_outlined;
      case 'ATESTADO':
        return Icons.event_available_outlined;
      case 'PEDIDO_EXAME':
        return Icons.biotech_outlined;
      case 'SOLICITACAO_PROCEDIMENTO':
        return Icons.healing_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'SIGNED':
        return 'Assinado';
      case 'ISSUED':
        return 'Emitido';
      case 'CANCELED':
        return 'Cancelado';
      case 'AWAITING_SIGNATURE':
        return 'Aguardando assinatura';
      case 'DRAFT':
        return 'Rascunho';
      default:
        return status;
    }
  }

  factory MedicalDocument.fromJson(Map<String, dynamic> j) => MedicalDocument(
        id: j['id'] as String,
        documentType: (j['documentType'] as String?) ?? '',
        status: (j['status'] as String?) ?? '',
        issuedAt: DateTime.parse(j['issuedAt'] as String).toLocal(),
        validationCode: (j['validationCode'] as String?) ?? '',
        hasPdf: (j['hasPdf'] as bool?) ?? false,
        doctorId: j['doctorId'] as String?,
        externalDoctorName: j['externalDoctorName'] as String?,
      );
}

/// PDF do documento baixado (bytes + content-type).
class DocumentFile {
  const DocumentFile(this.bytes, this.contentType, this.fileName);
  final Uint8List bytes;
  final String contentType;
  final String fileName;
}
