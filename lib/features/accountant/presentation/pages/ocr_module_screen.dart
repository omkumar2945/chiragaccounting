import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workbench_screen.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';

class OcrModuleScreen extends StatelessWidget {
  const OcrModuleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (context.read<WorkbenchQueueService?>() != null) {
      return const AiWorkbenchScreen(title: 'Chirag OCR Entry');
    }

    return ChangeNotifierProvider(
      create: (_) => WorkbenchQueueService(),
      child: const AiWorkbenchScreen(title: 'Chirag OCR Entry'),
    );
  }
}
