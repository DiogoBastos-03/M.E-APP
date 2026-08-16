import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../home/data/home_models.dart';

class PaymentsRepository {
  PaymentsRepository(this._api);
  final ApiClient _api;
  Dio get _dio => _api.dio;
  String get _p => AppConfig.apiPrefix;

  Future<PaymentInfo> getByAppointment(String appointmentId) async {
    final r = await _dio.get('$_p/payments/appointment/$appointmentId');
    return PaymentInfo.fromJson(r.data as Map<String, dynamic>);
  }

  /// Confirma o pagamento no provedor de testes. A rota só existe quando a API
  /// roda com PAYMENT_ALLOW_SIMULATION=true.
  Future<PaymentInfo> simulatePay(String paymentId) async {
    final r = await _dio.post('$_p/payments/mock/$paymentId/pay');
    return PaymentInfo.fromJson(r.data as Map<String, dynamic>);
  }
}
