import 'dart:async';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/client_portal/services/client_portal_access_service.dart';
import 'package:chirag_accounting/features/clients/Bank/client_bank_screen.dart';
import 'package:chirag_accounting/features/clients/Products/client_products_screen.dart';
import 'package:chirag_accounting/features/compat/screens/client_uploads_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/client_reports_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/purchase_screen_compat.dart';
import 'package:chirag_accounting/features/compat/screens/sales_screen_compat.dart';
import 'package:chirag_accounting/features/clients/Chat/services/command_api_models.dart';
import 'package:chirag_accounting/features/clients/Chat/services/command_api_service.dart';
import 'package:chirag_accounting/features/clients/Chat/services/chat_command_engine.dart';
import 'package:chirag_accounting/features/clients/Chat/services/voice_command_service.dart';
import 'package:chirag_accounting/features/clients/Chat/services/tts/text_to_speech_service.dart';
import 'package:chirag_accounting/features/clients/Chat/widgets/chirag_voice_button.dart';
import 'package:chirag_accounting/features/client_portal/models/client_portal_module.dart';
import 'package:chirag_accounting/features/clients/services/document_hub_service.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/masters/presentation/pages/other_ledgers_screen.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';

enum ChatStage {
  accountantClient,
  caAuditor,
  superAdminReview,
  chiragAssociate,
}

enum ChatInputState {
  idle,
  listening,
  transcribing,
  sending,
  processing,
  awaitingConfirmation,
  success,
  error,
}

extension ChatStageExtension on ChatStage {
  String get label {
    switch (this) {
      case ChatStage.accountantClient:
        return 'Accountant <-> Client';
      case ChatStage.caAuditor:
        return 'CA/Auditor Review';
      case ChatStage.superAdminReview:
        return 'Super Admin Review';
      case ChatStage.chiragAssociate:
        return 'Chirag Associate Support';
    }
  }
}

class ClientChatScreen extends StatefulWidget {
  const ClientChatScreen({super.key});

  @override
  State<ClientChatScreen> createState() => _ClientChatScreenState();
}

class _ClientChatScreenState extends State<ClientChatScreen> {
  final TextEditingController _messageCtrl = TextEditingController();
  final TextToSpeechService _ttsService =
      TextToSpeechService.withDefaultProvider();
  final CommandApiService _commandApiService = CommandApiService();
  final String _chatSessionId = CommandApiService.generateSessionId();
  ChatStage _activeStage = ChatStage.accountantClient;
  bool _caAuditorEnabled = false;
  bool _superAdminEnabled = false;
  bool _chiragAssociateEnabled = false;
  String? _pendingConfirmationCommand;
  String? _pendingBackendCommandId;
  String? _conversationId;
  bool _autoSpeakEnabled = true;
  bool _voiceOutputAvailable = true;
  String _stateStatusText = 'Idle';

  final List<_ChatMessage> _messages = <_ChatMessage>[
    _ChatMessage(
      text:
          'Welcome. Start with Client and Accountant chat. Escalate to CA/Auditor for review, and add Super Admin for appointment-style approval if needed.',
      senderLabel: 'System',
      stage: ChatStage.accountantClient,
      time: DateTime.now(),
    ),
  ];

  @override
  void dispose() {
    _ttsService.stop();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  void _setStateStatus(ChatInputState state, String message) {
    if (!mounted) return;
    setState(() {
      _stateStatusText = message;
    });
  }

  bool _isConfirmationReply(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized == 'confirm' ||
        normalized == 'yes' ||
        normalized == 'haan' ||
        normalized == 'haan kar do' ||
        normalized == 'ok' ||
        normalized == 'okay' ||
        normalized == 'ji' ||
        normalized == 'bilkul' ||
        normalized == 'kar do' ||
        normalized == 'post karo' ||
        normalized == 'yes, do it';
  }

  bool _isCancellationReply(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized == 'cancel' ||
        normalized == 'no' ||
        normalized == 'nahi' ||
        normalized == 'nahi cancel karo' ||
        normalized == 'mat karo' ||
        normalized == 'rehne do';
  }

  Future<void> _sendMessage() async {
    await _handleCommandInput(
      _messageCtrl.text,
      inputType: CommandInputType.text,
    );
  }

  Future<void> _handleVoiceTranscript(String text) async {
    final transcript = text.trim();
    if (transcript.isEmpty) {
      _setStateStatus(ChatInputState.error, 'Voice transcript is empty.');
      return;
    }

    _messageCtrl.text = transcript;
    _messageCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _messageCtrl.text.length),
    );

    final auth = context.read<AuthController>();
    final role = auth.currentUser?.role;
    final clientId = auth.currentUser?.id;
    final allowedModuleIds = clientId != null && role == UserRole.client
        ? context
              .read<ClientPortalAccessService>()
              .visibleModules(clientId, ClientPortalPlatform.mobile)
              .map((module) => module.id)
              .toSet()
        : <String>{
            'sales',
            'purchase',
            'reports',
            'bank',
            'uploads',
            'customers',
          };

    final service = VoiceCommandService(
      customerService: context.read<CustomerService>(),
      productService: context.read<ProductService>(),
    );
    final decision = service.analyze(
      transcript: transcript,
      role: role,
      allowedModuleIds: allowedModuleIds,
    );

    if (decision.isDenied) {
      _setStateStatus(ChatInputState.error, decision.permissionDeniedReason!);
      await _appendCommandMessage(decision.permissionDeniedReason!);
      return;
    }

    switch (decision.route) {
      case VoiceCommandRoute.uiCommand:
        _setStateStatus(ChatInputState.processing, 'Executing UI command...');
        await _appendCommandMessage(decision.summary, speak: false);
        final handled = await _runVoiceUiCommand(decision);
        if (handled) {
          _messageCtrl.clear();
          _setStateStatus(ChatInputState.success, 'UI command executed.');
        } else {
          _setStateStatus(
            ChatInputState.success,
            'Voice transcript ready. Review or send.',
          );
        }
        return;
      case VoiceCommandRoute.erpCommand:
        await _handleCommandInput(
          transcript,
          inputType: CommandInputType.voice,
        );
        return;
      case VoiceCommandRoute.transcriptOnly:
        _setStateStatus(ChatInputState.success, decision.summary);
        return;
    }
  }

  Future<bool> _runVoiceUiCommand(VoiceCommandDecision decision) async {
    switch (decision.uiAction) {
      case VoiceUiAction.openBilling:
        await _appendCommandMessage(
          'Opening billing workspace...',
          speak: false,
        );
        await _openScreen(const SalesScreen());
        return true;
      case VoiceUiAction.openPurchase:
        await _appendCommandMessage(
          'Opening purchase workspace...',
          speak: false,
        );
        await _openScreen(const PurchaseScreen());
        return true;
      case VoiceUiAction.openReports:
        await _appendCommandMessage(
          'Opening reports workspace...',
          speak: false,
        );
        await _openScreen(const ClientReportsScreen());
        return true;
      case VoiceUiAction.openBanking:
        await _appendCommandMessage(
          'Opening banking workspace...',
          speak: false,
        );
        await _openScreen(const ClientBankScreen());
        return true;
      case VoiceUiAction.openUploads:
        await _appendCommandMessage(
          'Opening upload workspace...',
          speak: false,
        );
        await _openScreen(const ClientUploadsScreen());
        return true;
      case VoiceUiAction.searchCustomer:
        if (decision.matchedCustomerName != null) {
          await _appendCommandMessage(
            'Customer matched: ${decision.matchedCustomerName}',
            speak: false,
          );
          return true;
        }
        await _appendCommandMessage(
          'No matching customer was found in masters. Review the transcript and send manually.',
          speak: false,
        );
        return false;
      case null:
        return false;
    }
  }

  Future<void> _handleCommandInput(
    String rawText, {
    required CommandInputType inputType,
  }) async {
    final requestedText = rawText.trim();
    if (requestedText.isEmpty) return;

    if (_ttsService.isSpeaking) {
      await _ttsService.stop();
    }

    _setStateStatus(ChatInputState.sending, 'Sending command...');

    final auth = context.read<AuthController>();
    final role = auth.currentUser?.role;
    final clientId = auth.currentUser?.id;
    final sender = _senderLabelForRole(role);

    final botEnabled =
        clientId != null &&
        context
            .read<ClientPortalAccessService>()
            .profileFor(clientId)
            .documentHubAccess
            .enableWhatsAppCommands;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: requestedText,
          senderLabel: sender,
          stage: _activeStage,
          time: DateTime.now(),
        ),
      );
      _messageCtrl.clear();
    });

    _setStateStatus(ChatInputState.processing, 'Processing...');

    if (_pendingBackendCommandId != null) {
      await _handlePendingBackendConfirmation(requestedText);
      return;
    }

    if (_pendingConfirmationCommand != null) {
      await _handlePendingLocalConfirmation(
        requestedText,
        inputType: inputType,
        botEnabled: botEnabled,
      );
      return;
    }

    if (await _executeQuickNavigationCommand(requestedText)) {
      _setStateStatus(ChatInputState.success, 'Completed.');
      return;
    }

    if (ApiConstants.useMockApi) {
      await _appendCommandMessage(
        'Command Center is in local mode right now. Connect backend to run authoritative command APIs.',
      );
      await _runLocalFallback(
        requestedText,
        inputType: inputType,
        botEnabled: botEnabled,
      );
      return;
    }

    try {
      final response = await _commandApiService.sendCommand(
        CommandApiRequest(
          inputType: _mapInputType(inputType),
          transcript: requestedText,
          sessionId: _chatSessionId,
          conversationId: _conversationId,
          idempotencyKey: CommandApiService.generateIdempotencyKey(),
          context: const CommandContextPayload(
            screen: 'client_chat',
            module: 'command_center',
          ),
        ),
      );
      await _applyBackendResponse(response);
    } catch (error) {
      await _appendCommandMessage(
        'Backend unavailable: $error\nSwitched to local safe-mode assistance.',
      );
      await _runLocalFallback(
        requestedText,
        inputType: inputType,
        botEnabled: botEnabled,
      );
    }
  }

  CommandApiInputType _mapInputType(CommandInputType inputType) {
    switch (inputType) {
      case CommandInputType.text:
        return CommandApiInputType.text;
      case CommandInputType.voice:
        return CommandApiInputType.voice;
      case CommandInputType.ocr:
        return CommandApiInputType.ocr;
    }
  }

  Future<void> _appendCommandMessage(String text, {bool speak = true}) async {
    if (!mounted) return;
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          senderLabel: 'Command Center',
          stage: _activeStage,
          time: DateTime.now(),
        ),
      );
    });

    if (speak && _autoSpeakEnabled) {
      await _speakText(text);
    }
  }

  Future<void> _speakText(String text) async {
    final spoken = text.trim();
    if (spoken.isEmpty) return;
    try {
      await _ttsService.initialize();
      final lower = spoken.toLowerCase();
      final language =
          lower.contains('kya') ||
              lower.contains('batayiye') ||
              lower.contains('bilkul') ||
              lower.contains('invoice')
          ? 'hi-IN'
          : 'en-IN';
      await _ttsService.setLanguage(language);
      await _ttsService.setRate(0.46);
      await _ttsService.setVolume(1.0);
      await _ttsService.speak(spoken);
      if (!_voiceOutputAvailable && mounted) {
        setState(() {
          _voiceOutputAvailable = true;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _voiceOutputAvailable = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice output is unavailable on this device. Text responses are still working.',
          ),
        ),
      );
    }
  }

  Future<void> _applyBackendResponse(CommandApiResponse response) async {
    _pendingBackendCommandId = response.requiresConfirmation
        ? response.commandId
        : null;
    _pendingConfirmationCommand = null;
    if (response.conversationId.trim().isNotEmpty) {
      _conversationId = response.conversationId;
    }

    final decoratedMessage =
        '${response.message}\nStatus: ${response.status.name.toUpperCase()}'
        '${response.commandId.isNotEmpty ? '\nCommand ID: ${response.commandId}' : ''}';
    await _appendCommandMessage(decoratedMessage);

    if (response.requiresConfirmation) {
      _setStateStatus(
        ChatInputState.awaitingConfirmation,
        'Awaiting confirmation...',
      );
    } else if (response.status == CommandApiStatus.failed) {
      _setStateStatus(ChatInputState.error, 'Request failed.');
    } else {
      _setStateStatus(ChatInputState.success, 'Completed.');
    }
  }

  Future<void> _handlePendingBackendConfirmation(String requestedText) async {
    if (_pendingBackendCommandId == null) return;

    try {
      if (_isConfirmationReply(requestedText)) {
        final response = await _commandApiService.confirmCommand(
          commandId: _pendingBackendCommandId!,
          sessionId: _conversationId ?? _chatSessionId,
          conversationId: _conversationId,
          action: 'confirm',
        );
        _pendingBackendCommandId = null;
        await _applyBackendResponse(response);
        _setStateStatus(ChatInputState.success, 'Command confirmed.');
        return;
      }

      if (_isCancellationReply(requestedText)) {
        final response = await _commandApiService.cancelCommand(
          commandId: _pendingBackendCommandId!,
          sessionId: _conversationId ?? _chatSessionId,
          conversationId: _conversationId,
        );
        _pendingBackendCommandId = null;
        await _applyBackendResponse(response);
        _setStateStatus(ChatInputState.idle, 'Command cancelled.');
        return;
      }

      await _appendCommandMessage(
        'A backend confirmation is pending. Reply with Confirm or Cancel.',
      );
      _setStateStatus(
        ChatInputState.awaitingConfirmation,
        'Awaiting confirmation...',
      );
    } catch (error) {
      await _appendCommandMessage('Confirmation request failed: $error');
      _setStateStatus(ChatInputState.error, 'Confirmation failed.');
    }
  }

  Future<void> _handlePendingLocalConfirmation(
    String requestedText, {
    required CommandInputType inputType,
    required bool botEnabled,
  }) async {
    if (_isConfirmationReply(requestedText)) {
      await _appendCommandMessage(
        'Confirmation received. Executing command: $_pendingConfirmationCommand\nExecution is routed through existing backend-safe flow.',
      );
      _pendingConfirmationCommand = null;
      _setStateStatus(ChatInputState.success, 'Command confirmed.');
      return;
    }

    if (_isCancellationReply(requestedText)) {
      await _appendCommandMessage('Pending command cancelled safely.');
      _pendingConfirmationCommand = null;
      _setStateStatus(ChatInputState.idle, 'Command cancelled.');
      return;
    }

    await _appendCommandMessage(
      'A confirmation is pending. Reply with Confirm or Cancel before new commands.',
    );
    _setStateStatus(
      ChatInputState.awaitingConfirmation,
      'Awaiting confirmation...',
    );
  }

  Future<void> _runLocalFallback(
    String requestedText, {
    required CommandInputType inputType,
    required bool botEnabled,
  }) async {
    final navigated = await _executeQuickNavigationCommand(requestedText);
    if (navigated) {
      _setStateStatus(ChatInputState.success, 'Completed.');
      return;
    }

    final hubService = context.read<DocumentHubService>();
    final engine = ChatCommandEngine(documentHubService: hubService);
    final result = engine.process(
      input: requestedText,
      inputType: inputType,
      botEnabled: botEnabled,
    );

    var botReply = result.message;
    if (result.requiresConfirmation && result.confirmationKey != null) {
      _pendingConfirmationCommand = result.confirmationKey;
      botReply =
          '$botReply\n\nReply with Confirm to continue or Cancel to stop.';
      _setStateStatus(
        ChatInputState.awaitingConfirmation,
        'Awaiting confirmation...',
      );
    } else {
      _setStateStatus(ChatInputState.success, 'Completed.');
    }
    await _appendCommandMessage(botReply);
  }

  bool _containsAny(String value, List<String> tokens) {
    return tokens.any(value.contains);
  }

  bool _hasClientModuleAccess(String moduleId) {
    final user = context.read<AuthController>().currentUser;
    if (user?.role != UserRole.client) return true;
    return context
        .read<ClientPortalAccessService>()
        .visibleModules(user!.id, ClientPortalPlatform.mobile)
        .any((module) => module.id == moduleId);
  }

  Future<bool> _openClientModule({
    required String moduleId,
    required String label,
    required Widget screen,
  }) async {
    if (!_hasClientModuleAccess(moduleId)) {
      await _appendCommandMessage(
        '$label access has not been enabled for this client. Ask the administrator to enable it in Client Permissions.',
      );
      _setStateStatus(ChatInputState.error, 'Module access is not enabled.');
      return true;
    }
    await _openScreen(screen);
    return true;
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  Future<bool> _executeQuickNavigationCommand(String rawText) async {
    final command = rawText.trim().toLowerCase();

    final requestsReportDownload = _containsAny(command, <String>[
      'pdf',
      'excel',
      'xlsx',
      'download report',
      'export report',
    ]);

    if (_containsAny(command, <String>[
      'stock',
      'product',
      'inventory',
      'item master',
    ])) {
      await _appendCommandMessage(
        'Opening product and stock master...',
        speak: false,
      );
      return _openClientModule(
        moduleId: 'products',
        label: 'Products and stock',
        screen: const ClientProductsScreen(),
      );
    }

    if (_containsAny(command, <String>[
      'ledger',
      'account ledger',
      'party ledger',
    ])) {
      await _appendCommandMessage('Opening ledger master...', speak: false);
      return _openClientModule(
        moduleId: 'ledger',
        label: 'Ledger',
        screen: const OtherLedgersScreen(),
      );
    }

    if (_containsAny(command, <String>[
      'account book',
      'cash book',
      'bank book',
      'bank balance',
    ])) {
      await _appendCommandMessage(
        'Opening account books and banking...',
        speak: false,
      );
      return _openClientModule(
        moduleId: 'bank',
        label: 'Account books and banking',
        screen: const ClientBankScreen(),
      );
    }

    if (_containsAny(command, <String>[
      'sales kholo',
      'open sales',
      'sales open',
      'sales dikhao',
    ])) {
      await _appendCommandMessage('Haan, Sales open kar raha hoon.');
      await _openScreen(const SalesScreen());
      return true;
    }

    if (_containsAny(command, <String>[
      'purchase kholo',
      'open purchase',
      'purchase open',
      'purchase dikhao',
    ])) {
      await _appendCommandMessage('Haan, Purchase open kar raha hoon.');
      await _openScreen(const PurchaseScreen());
      return true;
    }

    if (_containsAny(command, <String>[
      'reports kholo',
      'open reports',
      'reports open',
      'report dikhao',
      'sales report',
      'purchase report',
      'gst report',
      'outstanding report',
      'profit and loss',
    ])) {
      await _appendCommandMessage(
        requestsReportDownload
            ? 'Opening your report. Use the PDF or Excel button to download the filtered client report.'
            : 'Opening your authorized client reports.',
        speak: false,
      );
      return _openClientModule(
        moduleId: 'reports',
        label: 'Reports',
        screen: const ClientReportsScreen(),
      );
    }

    if (_containsAny(command, <String>[
      'bank kholo',
      'open bank',
      'payment kholo',
      'receipt kholo',
    ])) {
      await _appendCommandMessage('Bilkul, Banking screen open kar raha hoon.');
      VoucherType? initialVoucherType;
      if (_containsAny(command, <String>['payment kholo', 'open payment'])) {
        initialVoucherType = VoucherType.payment;
      }
      if (_containsAny(command, <String>['receipt kholo', 'open receipt'])) {
        initialVoucherType = VoucherType.receipt;
      }
      await _openScreen(
        ClientBankScreen(initialVoucherType: initialVoucherType),
      );
      return true;
    }

    if (_containsAny(command, <String>[
      'upload kholo',
      'open upload',
      'document upload',
      'ocr kholo',
    ])) {
      await _appendCommandMessage('Bilkul, upload screen open kar raha hoon.');
      await _openScreen(const ClientUploadsScreen());
      return true;
    }

    return false;
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      withData: true,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'pdf',
        'csv',
        'xlsx',
        'xls',
        'xlsm',
        'json',
        'txt',
      ],
    );

    if (!mounted || result == null || result.files.isEmpty) return;

    final selected = result.files.single;
    final selectedPath = selected.path;
    final selectedBytes = selected.bytes;
    final fileName = selected.name.trim().isEmpty
        ? 'file'
        : selected.name.trim();
    final lower = fileName.toLowerCase();
    final kind = lower.endsWith('.pdf')
        ? 'PDF'
        : (lower.endsWith('.csv') ||
              lower.endsWith('.xlsx') ||
              lower.endsWith('.xls') ||
              lower.endsWith('.xlsm') ||
              lower.endsWith('.json') ||
              lower.endsWith('.txt'))
        ? 'Spreadsheet'
        : 'Image';

    final role = context.read<AuthController>().currentUser?.role;
    final sender = _senderLabelForRole(role);
    final counterpart = _counterpartLabelForRole(role);

    setState(() {
      _messages.add(
        _ChatMessage(
          text: 'Attached $kind file',
          senderLabel: sender,
          stage: _activeStage,
          time: DateTime.now(),
          attachmentName: fileName,
          attachmentKind: kind,
        ),
      );
      _messages.add(
        _ChatMessage(
          text:
              '$kind received. Auto-detecting, reviewing, and opening the related entry screen...',
          senderLabel: counterpart,
          stage: _activeStage,
          time: DateTime.now(),
        ),
      );
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientUploadsScreen(
          autoRouteAfterDetect: true,
          autoRouteSource: 'support-chat',
          initialFilePath: isUsableLocalFilePath(selectedPath)
              ? selectedPath
              : null,
          initialFileBytes: selectedBytes,
          initialFileName: fileName,
        ),
      ),
    );
  }

  String _senderLabelForRole(UserRole? role) {
    switch (role) {
      case UserRole.client:
        return 'Client';
      case UserRole.accountant:
        return 'Accountant';
      case UserRole.superAdmin:
        return 'Super Admin';
      default:
        return role?.displayName ?? 'User';
    }
  }

  String _counterpartLabelForRole(UserRole? role) {
    switch (_activeStage) {
      case ChatStage.accountantClient:
        return role == UserRole.client ? 'Accountant' : 'Client';
      case ChatStage.caAuditor:
        return 'CA/Auditor';
      case ChatStage.superAdminReview:
        return 'Super Admin';
      case ChatStage.chiragAssociate:
        return 'Chirag Associate';
    }
  }

  void _enableCaAuditor() {
    setState(() {
      _caAuditorEnabled = true;
      _activeStage = ChatStage.caAuditor;
      _messages.add(
        _ChatMessage(
          text: 'Conversation escalated to CA/Auditor.',
          senderLabel: 'System',
          stage: ChatStage.caAuditor,
          time: DateTime.now(),
        ),
      );
    });
  }

  void _enableSuperAdmin() {
    if (!_caAuditorEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'First escalate to CA/Auditor, then add Super Admin for appointment review.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _superAdminEnabled = true;
      _activeStage = ChatStage.superAdminReview;
      _messages.add(
        _ChatMessage(
          text: 'Conversation escalated to Super Admin for appointment review.',
          senderLabel: 'System',
          stage: ChatStage.superAdminReview,
          time: DateTime.now(),
        ),
      );
    });
  }

  void _enableChiragAssociate() {
    if (!_caAuditorEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'First escalate to CA/Auditor, then add Chirag Associate.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _chiragAssociateEnabled = true;
      _activeStage = ChatStage.chiragAssociate;
      _messages.add(
        _ChatMessage(
          text: 'Conversation escalated to Chirag Associate.',
          senderLabel: 'System',
          stage: ChatStage.chiragAssociate,
          time: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final messageMaxWidth = screenWidth * 0.78;
    final headerMaxHeight = (screenHeight * 0.36).clamp(220.0, 340.0);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Client Chat'), centerTitle: true),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(maxHeight: headerMaxHeight),
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Logged in as: ${user?.role.displayName ?? 'Client'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('Active stage: ${_activeStage.label}'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _activeStage = ChatStage.accountantClient,
                        ),
                        icon: const Icon(Icons.people_outline, size: 18),
                        label: const Text('Client + Accountant'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _caAuditorEnabled ? null : _enableCaAuditor,
                        icon: const Icon(
                          Icons.verified_user_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _caAuditorEnabled
                              ? 'CA/Auditor Added'
                              : 'Add CA/Auditor',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _superAdminEnabled
                            ? null
                            : _enableSuperAdmin,
                        icon: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _superAdminEnabled
                              ? 'Super Admin Added'
                              : 'Add Super Admin',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _chiragAssociateEnabled
                            ? null
                            : _enableChiragAssociate,
                        icon: const Icon(
                          Icons.support_agent_outlined,
                          size: 18,
                        ),
                        label: Text(
                          _chiragAssociateEnabled
                              ? 'Chirag Associate Added'
                              : 'Add Chirag Associate',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFD4DCE6)),
                    ),
                    child: Text(
                      'State: $_stateStatusText',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF243B53),
                      ),
                    ),
                  ),
                  if (_pendingBackendCommandId != null ||
                      _pendingConfirmationCommand != null) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _handleCommandInput(
                            'confirm',
                            inputType: CommandInputType.text,
                          ),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: const Text('Confirm'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _handleCommandInput(
                            'cancel',
                            inputType: CommandInputType.text,
                          ),
                          icon: const Icon(Icons.cancel_outlined, size: 18),
                          label: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        selected: _autoSpeakEnabled,
                        onSelected: (value) {
                          setState(() {
                            _autoSpeakEnabled = value;
                          });
                        },
                        avatar: const Icon(Icons.volume_up_outlined, size: 18),
                        label: Text(
                          _autoSpeakEnabled
                              ? 'Auto Speak ON'
                              : 'Auto Speak OFF',
                        ),
                      ),
                      if (!_voiceOutputAvailable)
                        const Chip(
                          label: Text('Voice output unavailable'),
                          avatar: Icon(Icons.volume_off_outlined, size: 18),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final item = _messages[index];
                final role = context.read<AuthController>().currentUser?.role;
                final myLabel = _senderLabelForRole(role);
                final isMe = item.senderLabel == myLabel;
                final align = isMe
                    ? Alignment.centerRight
                    : Alignment.centerLeft;
                final bg = isMe ? Colors.blue.shade100 : Colors.grey.shade200;
                return Align(
                  alignment: align,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(10),
                    constraints: BoxConstraints(maxWidth: messageMaxWidth),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.senderLabel} - ${item.stage.label}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (item.attachmentName != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blueGrey.shade100,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  item.attachmentKind == 'PDF'
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.image_outlined,
                                  size: 18,
                                  color: Colors.blueGrey.shade700,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    item.attachmentName!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(item.text)),
                            if (!isMe)
                              IconButton(
                                tooltip: 'Speak',
                                icon: const Icon(
                                  Icons.volume_up_outlined,
                                  size: 18,
                                ),
                                onPressed: () => _speakText(item.text),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach image/pdf',
                    onPressed: _pickAttachment,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type or speak command...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ChiragVoiceButton(
                    onTranscript: (text) {
                      unawaited(_handleVoiceTranscript(text));
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: () => _sendMessage(),
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final String senderLabel;
  final ChatStage stage;
  final DateTime time;
  final String? attachmentName;
  final String? attachmentKind;

  const _ChatMessage({
    required this.text,
    required this.senderLabel,
    required this.stage,
    required this.time,
    this.attachmentName,
    this.attachmentKind,
  });
}
