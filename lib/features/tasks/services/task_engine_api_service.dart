import 'package:dio/dio.dart';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/tasks/models/work_task.dart';

class TaskEngineApiService {
  TaskEngineApiService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<List<WorkTask>> fetchTasks({
    required String businessId,
    required String userId,
    required String role,
  }) async {
    if (ApiConstants.useMockApi) return const <WorkTask>[];

    final response = await _dio.get<List<dynamic>>(
      '/tasks',
      queryParameters: <String, dynamic>{
        'businessId': businessId,
        'userId': userId,
        'role': role,
      },
    );

    final data = response.data ?? const <dynamic>[];
    return data
        .whereType<Map>()
        .map((value) => WorkTask.fromMap(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  Future<void> upsertTasks({
    required String businessId,
    required List<WorkTask> tasks,
  }) async {
    if (ApiConstants.useMockApi) return;

    await _dio.post<void>(
      '/tasks/bulk-upsert',
      data: <String, dynamic>{
        'businessId': businessId,
        'tasks': tasks.map((task) => task.toMap()).toList(growable: false),
      },
    );
  }

  Future<void> flushSyncQueue({
    required String businessId,
    required String userId,
    required List<Map<String, dynamic>> commands,
  }) async {
    if (ApiConstants.useMockApi || commands.isEmpty) return;

    await _dio.post<void>(
      '/tasks/sync-queue/flush',
      data: <String, dynamic>{
        'businessId': businessId,
        'userId': userId,
        'commands': commands,
      },
    );
  }
}
