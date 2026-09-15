import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';

class ProvisionedClientCredentials {
  const ProvisionedClientCredentials({
    required this.aggregate,
    required this.temporaryPassword,
  });

  final Map<String, dynamic> aggregate;
  final String temporaryPassword;
}

class AuthoritativeClientDataApi {
  AuthoritativeClientDataApi({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<Map<String, dynamic>>> listClients() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.clients,
      );
      final clients = _responseData(response)['clients'];
      if (clients is! List) return const <Map<String, dynamic>>[];
      return clients
          .whereType<Map>()
          .map((client) => Map<String, dynamic>.from(client))
          .toList(growable: false);
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> loadClient(String clientId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.clientAuthoritative(clientId),
      );
      return _responseData(response);
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> updateIdentity(
    String clientId,
    Map<String, dynamic> input,
  ) => _patch(clientId, ApiConstants.clientIdentity(clientId), 'client', input);

  Future<Map<String, dynamic>> updateProfile(
    String clientId,
    Map<String, dynamic> input,
  ) => _patch(clientId, ApiConstants.clientProfile(clientId), 'profile', input);

  Future<Map<String, dynamic>> updateCompliance(
    String clientId,
    Map<String, dynamic> input,
  ) => _patch(
    clientId,
    ApiConstants.clientCompliance(clientId),
    'compliance',
    input,
  );

  Future<Map<String, dynamic>> updateAssignments(
    String clientId,
    Map<String, dynamic> input,
  ) => _patch(
    clientId,
    ApiConstants.clientAssignments(clientId),
    'assignment',
    input,
  );

  Future<Map<String, dynamic>> updateAccess(
    String clientId,
    Map<String, dynamic> input,
  ) => _patch(clientId, ApiConstants.clientAccess(clientId), 'access', input);

  Future<ProvisionedClientCredentials> provisionCredentials(
    String clientId, {
    required bool onboarding,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.clientCredentials(clientId),
        data: <String, dynamic>{'action': onboarding ? 'onboard' : 'reset'},
      );
      final data = _responseData(response);
      final temporaryPassword =
          data.remove('temporaryPassword')?.toString() ?? '';
      if (temporaryPassword.isEmpty) {
        throw const FormatException(
          'The server did not return a temporary password.',
        );
      }
      return ProvisionedClientCredentials(
        aggregate: data,
        temporaryPassword: temporaryPassword,
      );
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Future<Map<String, dynamic>> updateWorkspace(
    String clientId,
    Map<String, dynamic> input,
  ) => _patch(
    clientId,
    ApiConstants.clientWorkspace(clientId),
    'workspace',
    input,
  );

  Future<Map<String, dynamic>> _patch(
    String clientId,
    String endpoint,
    String section,
    Map<String, dynamic> input,
  ) async {
    final current = await loadClient(clientId);
    final payload = Map<String, dynamic>.from(input);
    final version = _version(current[section]);
    if (version != null) payload['ifMatchVersion'] = version;

    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        endpoint,
        data: payload,
      );
      return _responseData(response);
    } on DioException catch (error) {
      throw ApiError.fromDioException(error);
    }
  }

  Map<String, dynamic> _responseData(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const FormatException('The server returned invalid client data.');
  }

  int? _version(Object? value) {
    if (value is! Map) return null;
    final version = value['version'];
    return version is int ? version : int.tryParse(version?.toString() ?? '');
  }
}
