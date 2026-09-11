import 'package:chirag_accounting/features/clients/services/document_hub_service.dart';

enum CommandInputType { text, voice, ocr }

enum CommandRiskLevel { low, medium, high, veryHigh }

class CommandEngineResult {
  const CommandEngineResult({
    required this.message,
    required this.riskLevel,
    required this.requiresConfirmation,
    this.confirmationKey,
    this.executed = false,
  });

  final String message;
  final CommandRiskLevel riskLevel;
  final bool requiresConfirmation;
  final String? confirmationKey;
  final bool executed;
}

class ChatCommandEngine {
  const ChatCommandEngine({required DocumentHubService documentHubService})
      : _documentHubService = documentHubService;

  final DocumentHubService _documentHubService;

  CommandEngineResult process({
    required String input,
    required CommandInputType inputType,
    required bool botEnabled,
  }) {
    final normalized = _normalize(input);

    if (normalized.isEmpty) {
      return const CommandEngineResult(
        message: 'Command is empty. Please type or speak again.',
        riskLevel: CommandRiskLevel.low,
        requiresConfirmation: false,
      );
    }

    if (botEnabled && _documentHubService.isSupportedChatCommand(normalized)) {
      return CommandEngineResult(
        message: _documentHubService.handleChatCommand(normalized),
        riskLevel: CommandRiskLevel.low,
        requiresConfirmation: false,
        executed: true,
      );
    }

    if (_isVeryHighRisk(normalized)) {
      return CommandEngineResult(
        message:
            'This is a very high-risk command. Please confirm before execution: $normalized',
        riskLevel: CommandRiskLevel.veryHigh,
        requiresConfirmation: true,
        confirmationKey: normalized,
      );
    }

    if (_isHighRisk(normalized)) {
      return CommandEngineResult(
        message:
            'This command needs confirmation before posting or money-impacting actions: $normalized',
        riskLevel: CommandRiskLevel.high,
        requiresConfirmation: true,
        confirmationKey: normalized,
      );
    }

    if (_isMediumRisk(normalized)) {
      return CommandEngineResult(
        message:
            'Draft preparation request captured. Review details and confirm before final posting.',
        riskLevel: CommandRiskLevel.medium,
        requiresConfirmation: false,
      );
    }

    if (_isOpenOrViewCommand(normalized)) {
      return CommandEngineResult(
        message:
            'Navigation/report query captured from ${inputType.name}. It is safe to execute immediately.',
        riskLevel: CommandRiskLevel.low,
        requiresConfirmation: false,
      );
    }

    return const CommandEngineResult(
      message:
          'I understood your message, but this command is not mapped yet. Please use a supported command or continue with chat assistance.',
      riskLevel: CommandRiskLevel.low,
      requiresConfirmation: false,
    );
  }

  String _normalize(String value) {
    return value.trim().toLowerCase();
  }

  bool _containsAny(String value, List<String> tokens) {
    return tokens.any(value.contains);
  }

  bool _isOpenOrViewCommand(String value) {
    return _containsAny(value, <String>[
      'open',
      'khol',
      'show',
      'dikha',
      'outstanding',
      'sales',
      'purchase',
      'ledger',
      'report',
      'bank balance',
      'gst',
    ]);
  }

  bool _isMediumRisk(String value) {
    return _containsAny(value, <String>[
      'create sales',
      'create purchase',
      'invoice banao',
      'draft',
      'receipt banao',
    ]);
  }

  bool _isHighRisk(String value) {
    return _containsAny(value, <String>[
      'post',
      'payment',
      'journal',
      'credit note',
      'debit note',
      'confirm',
    ]);
  }

  bool _isVeryHighRisk(String value) {
    return _containsAny(value, <String>[
      'delete',
      'cancel eway',
      'cancel e-way',
      'einvoice',
      'e-invoice',
      'bulk post',
    ]);
  }
}
