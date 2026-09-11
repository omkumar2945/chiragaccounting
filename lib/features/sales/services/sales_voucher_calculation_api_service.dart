import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/sales/services/sales_voucher_calculation_contract.dart';

class SalesVoucherCalculationApiService {
  SalesVoucherCalculationApiService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<SalesVoucherCalculationResult> calculate(
    SalesVoucherCalculationRequest request,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/vouchers/sales/calculate',
      data: request.toMap(),
    );

    final payload = response.data;
    if (payload == null) {
      throw Exception('Empty calculation response from backend.');
    }

    final data = payload['data'];
    if (data is Map<String, dynamic>) {
      return SalesVoucherCalculationResult.fromMap(data);
    }
    return SalesVoucherCalculationResult.fromMap(payload);
  }
}
