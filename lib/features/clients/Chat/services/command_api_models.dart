enum CommandApiInputType { text, voice, ocr }

enum CommandApiStatus {
  question,
  draftReady,
  pending,
  processing,
  needsInput,
  ambiguous,
  awaitingConfirmation,
  success,
  failed,
  cancelled,
}

class CommandContextPayload {
  const CommandContextPayload({
    required this.screen,
    required this.module,
    this.voucherId,
  });

  final String screen;
  final String module;
  final String? voucherId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'screen': screen,
      'module': module,
      'voucher_id': voucherId,
    };
  }
}

class CommandApiRequest {
  const CommandApiRequest({
    required this.inputType,
    required this.transcript,
    required this.sessionId,
    required this.context,
    this.conversationId,
    this.idempotencyKey,
    this.commandId,
  });

  final CommandApiInputType inputType;
  final String transcript;
  final String sessionId;
  final CommandContextPayload context;
  final String? conversationId;
  final String? idempotencyKey;
  final String? commandId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'input_type': inputType.name,
      'transcript': transcript,
      'session_id': sessionId,
      'conversation_id': conversationId,
      'client_context': context.toJson(),
      'idempotency_key': idempotencyKey,
      'command_id': commandId,
    };
  }
}

class CommandApiResponse {
  const CommandApiResponse({
    required this.status,
    required this.commandId,
    required this.conversationId,
    required this.message,
    required this.requiresConfirmation,
    this.intent,
    this.errorCode,
    this.data = const <String, dynamic>{},
  });

  final CommandApiStatus status;
  final String commandId;
  final String conversationId;
  final String message;
  final bool requiresConfirmation;
  final String? intent;
  final String? errorCode;
  final Map<String, dynamic> data;

  factory CommandApiResponse.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] as String? ?? '').trim().toLowerCase();
    final dynamic commandIdValue = json['command_id'] ?? json['commandId'];
    final dynamic conversationIdValue =
      json['conversation_id'] ?? json['conversationId'];
    final dynamic requiresConfirmationValue =
        json['requires_confirmation'] ?? json['requiresConfirmation'];
    final dynamic errorCodeValue = json['error_code'] ?? json['errorCode'];
    final dynamic dataValue = json['data'];
    return CommandApiResponse(
      status: _parseStatus(rawStatus),
      commandId: commandIdValue?.toString() ?? '',
      conversationId: conversationIdValue?.toString() ?? '',
      message: json['message']?.toString() ?? 'No response message',
      requiresConfirmation: requiresConfirmationValue == true,
      intent: json['intent']?.toString(),
      errorCode: errorCodeValue?.toString(),
      data: dataValue is Map<String, dynamic>
          ? dataValue
          : dataValue is Map
          ? Map<String, dynamic>.from(dataValue)
          : const <String, dynamic>{},
    );
  }

  static CommandApiStatus _parseStatus(String value) {
    switch (value) {
      case 'question':
        return CommandApiStatus.question;
      case 'draft_ready':
        return CommandApiStatus.draftReady;
      case 'pending':
        return CommandApiStatus.pending;
      case 'processing':
        return CommandApiStatus.processing;
      case 'needs_input':
        return CommandApiStatus.needsInput;
      case 'ambiguous':
        return CommandApiStatus.ambiguous;
      case 'awaiting_confirmation':
        return CommandApiStatus.awaitingConfirmation;
      case 'success':
      case 'completed':
        return CommandApiStatus.success;
      case 'cancelled':
        return CommandApiStatus.cancelled;
      case 'failed':
      default:
        return CommandApiStatus.failed;
    }
  }
}
