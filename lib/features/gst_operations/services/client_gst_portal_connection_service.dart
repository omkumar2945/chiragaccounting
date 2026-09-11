import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/services/api_client.dart';

enum ClientGstPortalConnectionType { einvoicing, ewayBill }

extension on ClientGstPortalConnectionType {
  String get apiPath => switch (this) {
    ClientGstPortalConnectionType.einvoicing => 'einvoicing',
    ClientGstPortalConnectionType.ewayBill => 'eway_bill',
  };
}

class ClientGstPortalConnection {
  const ClientGstPortalConnection({
    required this.configured,
    this.enabled = false,
    this.providerName,
    this.baseUrl,
    this.authType,
    this.applicabilityThreshold,
  });

  final bool configured;
  final bool enabled;
  final String? providerName;
  final String? baseUrl;
  final String? authType;
  final double? applicabilityThreshold;

  factory ClientGstPortalConnection.fromJson(Map<String, dynamic> json) =>
      ClientGstPortalConnection(
        configured: json['configured'] == true,
        enabled: json['enabled'] == true,
        providerName: json['providerName']?.toString(),
        baseUrl: json['baseUrl']?.toString(),
        authType: json['authType']?.toString(),
        applicabilityThreshold: (json['applicabilityThreshold'] as num?)?.toDouble(),
      );
}

class ClientGstPortalConnectionService {
  ClientGstPortalConnectionService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<ClientGstPortalConnection> load(
    ClientGstPortalConnectionType type,
  ) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/gstzen/client-connections/${type.apiPath}',
    );
    return ClientGstPortalConnection.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }

  Future<ClientGstPortalConnection> save({
    required ClientGstPortalConnectionType type,
    required String providerName,
    required String baseUrl,
    required String authType,
    required String credential,
    required bool enabled,
    double? applicabilityThreshold,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '/gstzen/client-connections/${type.apiPath}',
      data: <String, dynamic>{
        'providerName': providerName,
        'baseUrl': baseUrl,
        'authType': authType,
        'credential': credential,
        'enabled': enabled,
        'applicabilityThreshold': ?applicabilityThreshold,
      },
    );
    return ClientGstPortalConnection.fromJson(
      response.data ?? const <String, dynamic>{},
    );
  }
}