import 'package:file_picker/file_picker.dart';
import 'package:chirag_accounting/core/utils/file_download.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/gst_notices/services/gst_notice_management_service.dart';
import 'package:chirag_accounting/shared/widgets/movable_resizable_dialog.dart';

class GstNoticeManagementScreen extends StatefulWidget {
  const GstNoticeManagementScreen({super.key});

  @override
  State<GstNoticeManagementScreen> createState() =>
      _GstNoticeManagementScreenState();
}

class _GstNoticeManagementScreenState extends State<GstNoticeManagementScreen> {
  String? _clientId;

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<AdminUserService>();
    final noticeService = context.watch<GstNoticeManagementService>();
    final clients = directory.users
        .where((user) => user.role.isClient)
        .toList(growable: false);
    final notices = _clientId == null
        ? noticeService.notices
        : noticeService.noticesForClient(_clientId!);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      appBar: AppBar(
        title: const Text('Client GST Notice Management'),
        backgroundColor: const Color(0xFF174C4F),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE4EFEC),
              border: Border.all(color: const Color(0xFF80CBC4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Paper uploads, OCR analysis and reply reports remain under the selected client. Client visibility is off by default and can only be enabled here by admin.',
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            initialValue: _clientId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Filter by client',
              prefixIcon: Icon(Icons.business_outlined),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All clients'),
              ),
              ...clients.map(
                (client) => DropdownMenuItem<String?>(
                  value: client.id,
                  child: Text(
                    client.firmName.isEmpty ? client.name : client.firmName,
                  ),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _clientId = value),
          ),
          const SizedBox(height: 16),
          if (notices.isEmpty)
            const _EmptyNoticePanel()
          else
            for (final notice in notices) _noticeCard(notice),
        ],
      ),
    );
  }

  Widget _noticeCard(GstManagedNotice notice) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: notice.clientVisible
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF3E0),
        child: Icon(
          notice.isLocked
              ? Icons.lock_outline
              : notice.source == GstManagedNoticeSource.paperUpload
              ? Icons.upload_file_outlined
              : Icons.cloud_outlined,
          color: notice.clientVisible
              ? const Color(0xFF2E7D32)
              : const Color(0xFFE65100),
        ),
      ),
      title: Text(
        notice.noticeNumber.isEmpty
            ? (notice.formNumber.isEmpty ? notice.fileName : notice.formNumber)
            : notice.noticeNumber,
      ),
      subtitle: Text(
        '${notice.clientName}${notice.gstin.isEmpty ? '' : ' | ${notice.gstin}'}\n'
        '${notice.formNumber.isEmpty ? 'GST notice' : notice.formNumber} | ${notice.status.label} | ${notice.clientVisible ? 'CLIENT VISIBLE' : 'ADMIN ONLY'}${notice.isLocked ? ' | LOCKED' : ''}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        _detail('Original file', notice.fileName),
        _detail('Tax period', notice.taxPeriod),
        _detail('Reply due', notice.dueDateText),
        _detail(
          'Added',
          DateFormat('dd MMM yyyy, hh:mm a').format(notice.createdAt),
        ),
        if (notice.presentationMode !=
            GstReplyPresentationMode.notPresented) ...[
          const SizedBox(height: 10),
          _detail('Reply presented', notice.presentationMode.label),
          if (notice.presentedAt != null)
            _detail(
              'Presented on',
              DateFormat('dd MMM yyyy').format(notice.presentedAt!),
            ),
          _detail('Ack / reference', notice.presentationReference),
        ],
        if (notice.riskFlags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              notice.riskFlags.map((risk) => '- $risk').join('\n'),
              style: const TextStyle(color: Color(0xFF9A3412)),
            ),
          ),
        ],
        if (notice.officerUpdates.isNotEmpty) ...[
          const Divider(height: 28),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Officer follow-up timeline',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          for (final update in notice.officerUpdates.reversed)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9F8),
                border: Border.all(color: const Color(0xFFD9E2E3)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat(
                      'dd MMM yyyy, hh:mm a',
                    ).format(update.recordedAt),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (update.resultOrRemarks.isNotEmpty)
                    Text('Result / remarks: ${update.resultOrRemarks}'),
                  if (update.nextQuery.isNotEmpty)
                    Text('Officer query: ${update.nextQuery}'),
                  if (update.nextAction.isNotEmpty)
                    Text('Next action: ${update.nextAction}'),
                  if (update.actionDueDateText.isNotEmpty)
                    Text('Action due: ${update.actionDueDateText}'),
                ],
              ),
            ),
        ],
        if (notice.hasFinalOrder) ...[
          const Divider(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              border: Border.all(color: const Color(0xFF66BB6A)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Final order - record locked',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(notice.finalOrderFileName),
                if (notice.finalOrderRemarks.isNotEmpty)
                  SelectableText(notice.finalOrderRemarks),
                if (notice.lockedAt != null)
                  Text(
                    'Locked ${DateFormat('dd MMM yyyy, hh:mm a').format(notice.lockedAt!)}',
                  ),
              ],
            ),
          ),
        ],
        const Divider(height: 28),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow client to view this notice'),
          subtitle: const Text(
            'Controls original document and reply report visibility in client GST login.',
          ),
          value: notice.clientVisible,
          onChanged: notice.isLocked
              ? null
              : (value) => context
                    .read<GstNoticeManagementService>()
                    .updateRecord(notice.id, clientVisible: value),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (notice.hasOriginalDocument)
              OutlinedButton.icon(
                onPressed: () => _saveOriginal(notice),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Original notice'),
              ),
            if (notice.hasFinalOrder)
              OutlinedButton.icon(
                onPressed: () => _saveFinalOrder(notice),
                icon: const Icon(Icons.download_for_offline_outlined),
                label: const Text('Final order copy'),
              ),
            if (!notice.isLocked) ...[
              FilledButton.icon(
                onPressed: () => _editReply(notice),
                icon: const Icon(Icons.edit_document),
                label: const Text('Edit reply & status'),
              ),
              OutlinedButton.icon(
                onPressed: () => _presentReply(notice),
                icon: const Icon(Icons.send_outlined),
                label: Text(
                  notice.presentationMode ==
                          GstReplyPresentationMode.notPresented
                      ? 'Present reply'
                      : 'Update presentation',
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _addOfficerAction(notice),
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('Next officer action'),
              ),
              FilledButton.icon(
                onPressed: () => _uploadFinalOrder(notice),
                icon: const Icon(Icons.lock_outline),
                label: const Text('Upload final order & lock'),
              ),
              OutlinedButton.icon(
                onPressed: () => _deleteNotice(notice),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ],
        ),
      ],
    ),
  );

  Widget _detail(String label, String value) => value.trim().isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(child: SelectableText(value)),
            ],
          ),
        );

  Future<void> _saveOriginal(GstManagedNotice notice) async {
    await downloadFile(
      fileName: notice.fileName,
      bytes: notice.originalDocumentBytes,
    );
  }

  Future<void> _saveFinalOrder(GstManagedNotice notice) async {
    await downloadFile(
      fileName: notice.finalOrderFileName,
      bytes: notice.finalOrderBytes,
    );
  }

  Future<void> _editReply(GstManagedNotice notice) async {
    final draft = TextEditingController(text: notice.draftReply);
    final report = TextEditingController(text: notice.replyReport);
    var status = notice.status;
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Reply: ${notice.clientName}'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<GstManagedNoticeStatus>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Notice status',
                      border: OutlineInputBorder(),
                    ),
                    items: GstManagedNoticeStatus.values
                        .where(
                          (value) => value != GstManagedNoticeStatus.closed,
                        )
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) setDialogState(() => status = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: draft,
                    minLines: 8,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Working draft',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: report,
                    minLines: 8,
                    maxLines: 16,
                    decoration: const InputDecoration(
                      labelText: 'Reply report for record / client',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save record'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await context.read<GstNoticeManagementService>().updateRecord(
        notice.id,
        draftReply: draft.text,
        replyReport: report.text,
        status: status,
      );
    }
    draft.dispose();
    report.dispose();
  }

  Future<void> _presentReply(GstManagedNotice notice) async {
    var mode = notice.presentationMode == GstReplyPresentationMode.notPresented
        ? GstReplyPresentationMode.online
        : notice.presentationMode;
    var presentedAt = notice.presentedAt ?? DateTime.now();
    final reference = TextEditingController(text: notice.presentationReference);
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Reply presentation'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<GstReplyPresentationMode>(
                  segments: const [
                    ButtonSegment(
                      value: GstReplyPresentationMode.online,
                      icon: Icon(Icons.cloud_upload_outlined),
                      label: Text('Online'),
                    ),
                    ButtonSegment(
                      value: GstReplyPresentationMode.physical,
                      icon: Icon(Icons.person_pin_circle_outlined),
                      label: Text('Physical'),
                    ),
                  ],
                  selected: <GstReplyPresentationMode>{mode},
                  onSelectionChanged: (value) =>
                      setDialogState(() => mode = value.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reference,
                  decoration: const InputDecoration(
                    labelText: 'ARN / acknowledgement / receiving reference',
                    border: OutlineInputBorder(),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Presentation date'),
                  trailing: Text(DateFormat('dd MMM yyyy').format(presentedAt)),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2017),
                      lastDate: DateTime(2200),
                      initialDate: presentedAt,
                    );
                    if (picked != null) {
                      setDialogState(() => presentedAt = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save presentation'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      await context.read<GstNoticeManagementService>().recordReplyPresentation(
        notice.id,
        mode: mode,
        presentedAt: presentedAt,
        reference: reference.text,
      );
    }
    reference.dispose();
  }

  Future<void> _addOfficerAction(GstManagedNotice notice) async {
    final remarks = TextEditingController();
    final query = TextEditingController();
    final action = TextEditingController();
    final dueDate = TextEditingController();
    final saved = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Officer result and next action'),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: remarks,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Officer result / remarks',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: query,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Next query raised by officer',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: action,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Required next action',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dueDate,
                  decoration: const InputDecoration(
                    labelText: 'Next action due date / hearing date',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Add to timeline'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      try {
        await context.read<GstNoticeManagementService>().addOfficerUpdate(
          notice.id,
          resultOrRemarks: remarks.text,
          nextQuery: query.text,
          nextAction: action.text,
          actionDueDateText: dueDate.text,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    remarks.dispose();
    query.dispose();
    action.dispose();
    dueDate.dispose();
  }

  Future<void> _uploadFinalOrder(GstManagedNotice notice) async {
    final selected = await FilePicker.pickFile(
      dialogTitle: 'Select final GST order copy',
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (selected == null || !mounted) return;
    final bytes = await selected.readAsBytes();
    final remarks = TextEditingController();
    final confirmed = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Upload final order and lock?'),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${selected.name} will become the final order copy. After confirmation this notice record cannot be edited or deleted.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarks,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Final result / order remarks',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.lock_outline),
            label: const Text('Upload and lock'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await context.read<GstNoticeManagementService>().uploadFinalOrder(
          notice.id,
          fileName: selected.name,
          bytes: bytes,
          remarks: remarks.text,
        );
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
    remarks.dispose();
  }

  Future<void> _deleteNotice(GstManagedNotice notice) async {
    final confirmed = await showMovableDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete GST notice record?'),
        content: Text(
          'This removes the uploaded file and reply record for ${notice.clientName}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<GstNoticeManagementService>().deleteRecord(notice.id);
    }
  }
}

class _EmptyNoticePanel extends StatelessWidget {
  const _EmptyNoticePanel();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFD9E2E3)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Column(
      children: [
        Icon(Icons.mark_email_unread_outlined, size: 42),
        SizedBox(height: 10),
        Text('No GST notice records for this selection.'),
      ],
    ),
  );
}

extension on GstManagedNoticeStatus {
  String get label => switch (this) {
    GstManagedNoticeStatus.received => 'Received',
    GstManagedNoticeStatus.drafting => 'Drafting reply',
    GstManagedNoticeStatus.reviewReady => 'Ready for review',
    GstManagedNoticeStatus.submitted => 'Reply submitted',
    GstManagedNoticeStatus.closed => 'Closed',
  };
}

extension on GstReplyPresentationMode {
  String get label => switch (this) {
    GstReplyPresentationMode.notPresented => 'Not presented',
    GstReplyPresentationMode.physical => 'Physically before officer',
    GstReplyPresentationMode.online => 'Online portal submission',
  };
}
