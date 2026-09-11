import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/inbox/models/inbox_item.dart';

class UniversalInboxApiService {
  UniversalInboxApiService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<InboxItem>> fetchInbox({
    required String businessId,
    required String userId,
  }) async {
    if (ApiConstants.useMockApi) return const <InboxItem>[];

    final response = await _dio.get<List<dynamic>>(
      '/inbox',
      queryParameters: <String, dynamic>{
        'businessId': businessId,
        'userId': userId,
      },
    );

    final data = response.data ?? const <dynamic>[];
    return data.whereType<Map>().map((value) {
      final map = Map<String, dynamic>.from(value);
      return InboxItem(
        id: map['id']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        message: map['message']?.toString() ?? '',
        channel: map['channel']?.toString() ?? '',
        createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
        referenceType: map['referenceType']?.toString() ?? '',
        referenceId: map['referenceId']?.toString() ?? '',
        isRead: map['isRead'] == true,
      );
    }).toList(growable: false);
  }

  Future<void> markAllRead({
    required String businessId,
    required String userId,
  }) async {
    if (ApiConstants.useMockApi) return;

    await _dio.post<void>(
      '/inbox/mark-all-read',
      data: <String, dynamic>{
        'businessId': businessId,
        'userId': userId,
      },
    );
  }
}
