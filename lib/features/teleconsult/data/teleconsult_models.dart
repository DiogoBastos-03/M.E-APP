class Teleconsultation {
  const Teleconsultation({
    required this.appointmentId,
    required this.roomName,
    required this.roomUrl,
    required this.serverUrl,
    required this.start,
    required this.end,
    this.token,
  });

  final String appointmentId;
  final String roomName;
  final String roomUrl;
  final String serverUrl;
  final String? token;
  final DateTime start;
  final DateTime end;

  factory Teleconsultation.fromJson(Map<String, dynamic> j) => Teleconsultation(
        appointmentId: (j['appointmentId'] as String?) ?? '',
        roomName: (j['roomName'] as String?) ?? '',
        roomUrl: (j['roomUrl'] as String?) ?? '',
        serverUrl: (j['serverUrl'] as String?) ?? '',
        token: j['token'] as String?,
        start: DateTime.tryParse((j['startDatetime'] as String?) ?? '')?.toLocal() ??
            DateTime.now(),
        end: DateTime.tryParse((j['endDatetime'] as String?) ?? '')?.toLocal() ??
            DateTime.now(),
      );
}
