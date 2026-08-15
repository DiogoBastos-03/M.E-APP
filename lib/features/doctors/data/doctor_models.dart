class Specialty {
  const Specialty(this.id, this.slug, this.name);
  final String id;
  final String slug;
  final String name;

  factory Specialty.fromJson(Map<String, dynamic> j) => Specialty(
        j['id'] as String,
        (j['slug'] as String?) ?? '',
        (j['name'] as String?) ?? 'Especialidade',
      );
}

class DoctorListItem {
  const DoctorListItem({
    required this.id,
    required this.fullName,
    this.userId,
    this.crm,
    this.rqe,
    this.specialties = const [],
    this.consultationPriceCents,
    this.photoUrl,
    this.photoUpdatedAt,
    this.ratingAvg,
    this.ratingCount = 0,
  });

  final String id;
  final String? userId;
  final String fullName;
  final String? crm;
  final String? rqe;
  final List<Specialty> specialties;
  final int? consultationPriceCents;
  final String? photoUrl;
  final DateTime? photoUpdatedAt;
  final double? ratingAvg;
  final int ratingCount;

  bool get acceptsTelemedicine => (consultationPriceCents ?? 0) > 0;

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  bool get hasRating => ratingCount > 0 && ratingAvg != null;

  String get specialtyLabel => specialties.isEmpty
      ? 'Especialidade não informada'
      : specialties.map((s) => s.name).join(' · ');

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final first = parts.first;
      return (first.length >= 2 ? first.substring(0, 2) : first).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  factory DoctorListItem.fromJson(Map<String, dynamic> j) => DoctorListItem(
        id: j['id'] as String,
        userId: j['userId'] as String?,
        fullName: (j['fullName'] as String?) ?? 'Médico',
        crm: j['crm'] as String?,
        rqe: j['rqe'] as String?,
        specialties: ((j['specialties'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(Specialty.fromJson)
            .toList(),
        consultationPriceCents: (j['consultationPriceCents'] as num?)?.toInt(),
        photoUrl: j['photoUrl'] as String?,
        photoUpdatedAt: j['photoUpdatedAt'] == null
            ? null
            : DateTime.tryParse(j['photoUpdatedAt'] as String),
        ratingAvg: (j['ratingAvg'] as num?)?.toDouble(),
        ratingCount: (j['ratingCount'] as num?)?.toInt() ?? 0,
      );
}

class DoctorPage {
  const DoctorPage({
    required this.content,
    required this.page,
    required this.totalElements,
    required this.hasNext,
  });

  final List<DoctorListItem> content;
  final int page;
  final int totalElements;
  final bool hasNext;

  factory DoctorPage.fromJson(Map<String, dynamic> j) => DoctorPage(
        content: ((j['content'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(DoctorListItem.fromJson)
            .toList(),
        page: (j['page'] as num?)?.toInt() ?? 0,
        totalElements: (j['totalElements'] as num?)?.toInt() ?? 0,
        hasNext: (j['hasNext'] as bool?) ?? false,
      );
}

class DoctorReview {
  const DoctorReview({
    required this.id,
    required this.appointmentId,
    required this.doctorId,
    required this.rating,
    required this.createdAt,
    this.comment,
  });

  final String id;
  final String appointmentId;
  final String doctorId;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  factory DoctorReview.fromJson(Map<String, dynamic> j) => DoctorReview(
        id: j['id'] as String,
        appointmentId: (j['appointmentId'] as String?) ?? '',
        doctorId: (j['doctorId'] as String?) ?? '',
        rating: (j['rating'] as num?)?.toInt() ?? 0,
        comment: j['comment'] as String?,
        createdAt:
            DateTime.tryParse((j['createdAt'] as String?) ?? '')?.toLocal() ??
                DateTime.fromMillisecondsSinceEpoch(0),
      );
}
