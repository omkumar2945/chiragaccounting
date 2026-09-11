import 'dart:math';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/services/api_client.dart';
import 'package:chirag_accounting/features/clients/Chat/services/command_api_models.dart';
import 'package:dio/dio.dart';

class CommandApiException implements Exception {
  const CommandApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class CommandApiService {
  CommandApiService({Dio? dio}) : _dio = dio ?? ApiClient.dio;

  final Dio _dio;

  Future<CommandApiResponse> sendCommand(CommandApiRequest request) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.command,
        data: request.toJson(),
      );
      return CommandApiResponse.fromJson(_extractPayload(response.data));
    } on DioException catch (error) {
      throw CommandApiException(ApiError.fromDioException(error).message);
    }
  }

  Future<CommandApiResponse> confirmCommand({
    required String commandId,
    required String sessionId,
    String? conversationId,
    String action = 'confirm',
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.commandConfirm,
        data: <String, dynamic>{
          'command_id': commandId,
          'session_id': sessionId,
          'conversation_id': conversationId ?? sessionId,
          'action': action,
        },
      );
      return CommandApiResponse.fromJson(_extractPayload(response.data));
    } on DioException catch (error) {
      throw CommandApiException(ApiError.fromDioException(error).message);
    }
  }

  Future<CommandApiResponse> cancelCommand({
    required String commandId,
    required String sessionId,
    String? conversationId,
    String reason = 'user_cancelled',
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.commandCancel,
        data: <String, dynamic>{
          'command_id': commandId,
          'session_id': sessionId,
          'conversation_id': conversationId ?? sessionId,
          'reason': reason,
        },
      );
      return CommandApiResponse.fromJson(_extractPayload(response.data));
    } on DioException catch (error) {
      throw CommandApiException(ApiError.fromDioException(error).message);
    }
  }

  Future<CommandApiResponse> getCommandStatus({required String commandId}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.commandStatus(commandId),
      );
      return CommandApiResponse.fromJson(_extractPayload(response.data));
    } on DioException catch (error) {
      throw CommandApiException(ApiError.fromDioException(error).message);
    }
  }

  static Map<String, dynamic> _extractPayload(dynamic raw) {
    if (raw is! Map) {
      throw const CommandApiException('Invalid command API response format.');
    }
    final map = Map<String, dynamic>.from(raw);
    final nested = map['data'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }
    return map;
  }

  static String generateSessionId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(999999).toString().padLeft(6, '0');
    return 'chat-session-$now-$random';
  }

  static String generateIdempotencyKey() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final random = Random.secure().nextInt(99999999).toString().padLeft(8, '0');
    return 'cmd-$now-$random';
  }
}
