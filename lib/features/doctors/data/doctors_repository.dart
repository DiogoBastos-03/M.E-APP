import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'doctor_models.dart';

class DoctorsRepository {
  DoctorsRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  Future<DoctorPage> search({
    String? query,
    String? specialtyId,
    int page = 0,
    int size = 20,
    String sort = 'NAME',
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'size': size,
      'sort': sort,
      if (query != null && query.isNotEmpty) 'query': query,
      'specialtyId': ?specialtyId,
    };
    final r = await _dio.get('$_p/doctors', queryParameters: params);
    return DoctorPage.fromJson(r.data as Map<String, dynamic>);
  }

  Future<List<Specialty>> getSpecialties() async {
    final r = await _dio.get('$_p/specialties');
    return (r.data as List).cast<Map<String, dynamic>>().map(Specialty.fromJson).toList();
  }

  Future<DoctorListItem> getById(String doctorId) async {
    final r = await _dio.get('$_p/doctors/$doctorId');
    return DoctorListItem.fromJson(r.data as Map<String, dynamic>);
  }

  Future<Uint8List> getPhoto(String doctorId) async {
    final r = await _dio.get<List<int>>(
      '$_p/doctors/$doctorId/photo',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(r.data ?? const []);
  }

  Future<List<DoctorReview>> getMyReviews() async {
    final r = await _dio.get('$_p/reviews/my');
    return (r.data as List).cast<Map<String, dynamic>>().map(DoctorReview.fromJson).toList();
  }

  Future<DoctorReview> createReview({
    required String appointmentId,
    required int rating,
    String? comment,
  }) async {
    final r = await _dio.post('$_p/reviews', data: {
      'appointmentId': appointmentId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return DoctorReview.fromJson(r.data as Map<String, dynamic>);
  }

  Future<DoctorReview> updateReview({
    required String reviewId,
    required int rating,
    String? comment,
  }) async {
    final r = await _dio.patch('$_p/reviews/$reviewId', data: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
    return DoctorReview.fromJson(r.data as Map<String, dynamic>);
  }
}
