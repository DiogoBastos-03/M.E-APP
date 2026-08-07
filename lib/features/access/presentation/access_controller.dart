import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/access_models.dart';
import '../data/access_repository.dart';

enum Loading { idle, loading, ready, error }

/// Estado da aba Acessos: pedidos pendentes, concessões ativas e auditoria,
/// mais o diretório (médicos/clínicas) para resolver nomes.
class AccessController extends ChangeNotifier {
  AccessController(this._repo);
  final AccessRepository _repo;

  // Pedidos pendentes
  Loading pendingState = Loading.idle;
  String? pendingError;
  List<AccessGrant> pending = [];

  // Concessões ativas
  Loading grantsState = Loading.idle;
  String? grantsError;
  List<AccessGrant> activeGrants = [];

  // Auditoria
  Loading logsState = Loading.idle;
  String? logsError;
  List<RecordAccessLog> logs = [];
  AccessAction? logFilter; // null = todas

  // Diretório
  final Map<String, DoctorLite> _docById = {};
  final Map<String, DoctorLite> _docByUserId = {};
  final Map<String, ClinicLite> _clinicById = {};
  bool _directoryLoaded = false;

  Future<void> loadAll() async {
    await _loadDirectory();
    await Future.wait([loadPending(), loadGrants(), loadLogs()]);
  }

  Future<void> refreshAll() => loadAll();

  Future<void> _loadDirectory() async {
    if (_directoryLoaded) return;
    try {
      final docs = await _repo.getDoctors();
      for (final d in docs) {
        _docById[d.id] = d;
        if (d.userId != null) _docByUserId[d.userId!] = d;
      }
    } catch (_) {/* diretório é best-effort */}
    try {
      final clinics = await _repo.getClinics();
      for (final c in clinics) {
        _clinicById[c.id] = c;
      }
    } catch (_) {}
    _directoryLoaded = true;
  }

  Future<void> loadPending() async {
    pendingState = Loading.loading;
    notifyListeners();
    try {
      await _loadDirectory();
      pending = await _repo.getPending();
      pendingState = Loading.ready;
    } on DioException catch (e) {
      pendingError = _msg(e);
      pendingState = Loading.error;
    }
    notifyListeners();
  }

  Future<void> loadGrants() async {
    grantsState = Loading.loading;
    notifyListeners();
    try {
      await _loadDirectory();
      final all = await _repo.getMyGrants();
      activeGrants = all
          .where((g) => g.active && g.status == AccessStatus.approved)
          .toList()
        ..sort((a, b) => (b.grantedAt ?? DateTime(0)).compareTo(a.grantedAt ?? DateTime(0)));
      grantsState = Loading.ready;
    } on DioException catch (e) {
      grantsError = _msg(e);
      grantsState = Loading.error;
    }
    notifyListeners();
  }

  Future<void> loadLogs() async {
    logsState = Loading.loading;
    notifyListeners();
    try {
      await _loadDirectory();
      logs = await _repo.getLogs();
      logs.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      logsState = Loading.ready;
    } on DioException catch (e) {
      logsError = _msg(e);
      logsState = Loading.error;
    }
    notifyListeners();
  }

  void setLogFilter(AccessAction? a) {
    logFilter = a;
    notifyListeners();
  }

  List<RecordAccessLog> get filteredLogs =>
      logFilter == null ? logs : logs.where((l) => l.action == logFilter).toList();

  /// Ações. Retornam null em sucesso ou uma mensagem de erro para a UI.
  Future<String?> approveAll(String id, {DateTime? expiresAt}) =>
      _action(() => _repo.approve(id, expiresAt: expiresAt));

  Future<String?> approvePartial(String id, List<RecordSection> sections, {DateTime? expiresAt}) =>
      _action(() => _repo.approve(id, sections: sections, expiresAt: expiresAt));

  Future<String?> deny(String id) => _action(() => _repo.deny(id));

  Future<String?> revoke(String id) => _action(() => _repo.revoke(id));

  Future<String?> _action(Future<AccessGrant> Function() call) async {
    try {
      await call();
      // Relê tudo do backend para refletir o novo estado.
      await Future.wait([loadPending(), loadGrants(), loadLogs()]);
      return null;
    } on DioException catch (e) {
      return _msg(e);
    }
  }

  // ---- resolução de nomes ----
  /// Nome do médico a partir do doctorId (ou null se desconhecido).
  String? doctorNameById(String? doctorId) =>
      doctorId == null ? null : _docById[doctorId]?.fullName;

  /// Nome do médico a partir do userId (ex.: quem publicou um exame).
  String? doctorNameByUserId(String? userId) =>
      userId == null ? null : _docByUserId[userId]?.fullName;

  /// Especialidade do médico a partir do userId.
  String? doctorSpecialtyByUserId(String? userId) =>
      userId == null ? null : _docByUserId[userId]?.specialty;

  Requester requesterFor(AccessGrant g) {
    if (g.doctorId != null && _docById.containsKey(g.doctorId)) {
      final d = _docById[g.doctorId]!;
      return Requester(
        name: d.fullName,
        subtitle: d.specialty ?? 'Médico(a)',
        crm: d.crm,
        initials: _initials(d.fullName),
      );
    }
    if (g.clinicId != null && _clinicById.containsKey(g.clinicId)) {
      final c = _clinicById[g.clinicId]!;
      return Requester(name: c.corporateName, subtitle: 'Clínica', initials: _initials(c.corporateName));
    }
    if (g.clinicId != null) {
      return const Requester(name: 'Clínica', subtitle: 'Clínica', initials: 'CL');
    }
    return const Requester(name: 'Médico(a)', subtitle: 'Profissional de saúde', initials: 'DR');
  }

  /// "Quem" para um registro de auditoria.
  ({String name, String initials}) accessorFor(RecordAccessLog log) {
    final uid = log.accessorUserId;
    if (uid != null && _docByUserId.containsKey(uid)) {
      final d = _docByUserId[uid]!;
      return (name: d.fullName, initials: _initials(d.fullName));
    }
    final role = switch (log.accessorRole) {
      'DOCTOR' => 'Um médico',
      'CLINIC_ADMIN' => 'Uma clínica',
      'SYS_ADMIN' => 'Administração do sistema',
      _ => 'Um profissional',
    };
    return (name: role, initials: 'ME');
  }

  String _initials(String name) {
    final parts = name
        .replaceAll(RegExp(r'^(Dr\.?a?\.?|Dra\.?)\s*', caseSensitive: false), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  String _msg(DioException e) {
    final code = e.response?.statusCode;
    if (code == 403) return 'Você não tem permissão para esta ação.';
    if (code == 404) return 'Registro não encontrado (talvez já tenha mudado).';
    if (code == 409) return 'Este pedido já foi decidido.';
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Não foi possível conectar ao servidor.';
    }
    return 'Algo deu errado (${code ?? e.type.name}).';
  }
}
