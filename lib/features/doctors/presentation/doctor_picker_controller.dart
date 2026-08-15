import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../access/presentation/access_controller.dart' show Loading;
import '../data/doctor_models.dart';
import '../data/doctors_repository.dart';

class DoctorPickerController extends ChangeNotifier {
  DoctorPickerController(this._repo);
  final DoctorsRepository _repo;

  static const int _pageSize = 20;
  static const int minQueryLength = 2;
  static const Duration _debounceDelay = Duration(milliseconds: 350);

  Loading state = Loading.idle;
  String? error;

  List<DoctorListItem> items = [];
  List<Specialty> specialties = [];
  String? selectedSpecialtyId;
  String query = '';

  bool loadingMore = false;
  bool hasNext = false;
  int _page = 0;

  Timer? _debounce;
  int _seq = 0;
  bool _disposed = false;

  Future<void> init() async {
    unawaited(_loadSpecialties());
    await _reload();
  }

  void onQueryChanged(String value) {
    query = value;
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, _reload);
    notifyListeners();
  }

  void clearQuery() {
    _debounce?.cancel();
    query = '';
    _reload();
  }

  void selectSpecialty(String? specialtyId) {
    if (selectedSpecialtyId == specialtyId) return;
    selectedSpecialtyId = specialtyId;
    _debounce?.cancel();
    _reload();
  }

  Future<void> refresh() => _reload();

  Future<void> loadMore() async {
    if (loadingMore || !hasNext || state != Loading.ready) return;
    loadingMore = true;
    notifyListeners();

    final seq = _seq;
    try {
      final result = await _repo.search(
        query: _effectiveQuery,
        specialtyId: selectedSpecialtyId,
        page: _page + 1,
        size: _pageSize,
      );
      if (seq != _seq || _disposed) return;
      items = [...items, ...result.content];
      hasNext = result.hasNext;
      _page = result.page;
    } on DioException catch (e) {
      if (seq != _seq || _disposed) return;
      error = _msg(e);
    } catch (_) {
      if (seq != _seq || _disposed) return;
      error = 'Erro inesperado ao carregar mais médicos.';
    } finally {
      if (!_disposed) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  String? get _effectiveQuery {
    final q = query.trim();
    return q.length >= minQueryLength ? q : null;
  }

  Future<void> _loadSpecialties() async {
    try {
      final list = await _repo.getSpecialties();
      if (_disposed) return;
      specialties = list;
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  Future<void> _reload() async {
    final seq = ++_seq;
    state = Loading.loading;
    error = null;
    notifyListeners();

    try {
      final result = await _repo.search(
        query: _effectiveQuery,
        specialtyId: selectedSpecialtyId,
        page: 0,
        size: _pageSize,
      );
      if (seq != _seq || _disposed) return;
      items = result.content;
      hasNext = result.hasNext;
      _page = 0;
      state = Loading.ready;
    } on DioException catch (e) {
      if (seq != _seq || _disposed) return;
      error = _msg(e);
      state = Loading.error;
    } catch (_) {
      if (seq != _seq || _disposed) return;
      error = 'Erro inesperado ao buscar médicos.';
      state = Loading.error;
    }
    if (!_disposed) notifyListeners();
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) return data['message'] as String;
    if (e.response?.statusCode == 401) return 'Sessão expirada. Entre novamente.';
    return 'Não foi possível carregar a lista de médicos.';
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
