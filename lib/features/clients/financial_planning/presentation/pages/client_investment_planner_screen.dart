import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/financial_planning/models/client_financial_planning_models.dart';
import 'package:chirag_accounting/features/clients/financial_planning/services/client_financial_planning_service.dart';

class ClientInvestmentPlannerScreen extends StatefulWidget {
  const ClientInvestmentPlannerScreen({super.key});

  @override
  State<ClientInvestmentPlannerScreen> createState() => _ClientInvestmentPlannerScreenState();
}

class _ClientInvestmentPlannerScreenState
    extends State<ClientInvestmentPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _planNameCtrl = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _yearlyCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final _returnCtrl = TextEditingController(text: '12');
  final _tenureCtrl = TextEditingController(text: '120');
  final _batchAmountCtrl = TextEditingController();
  final _monthlyPremiumCtrl = TextEditingController();
  final _sumAssuredCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _maturityCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();

  ClientInvestmentType _selectedType = ClientInvestmentType.sip;
  DateTime _reminderDate = DateTime.now().add(const Duration(days: 30));
  DateTime? _maturityDate;
  bool _isClaimed = false;
  String? _attachmentPath;
  String? _attachmentName;
  String? _editingId;

  @override
  void dispose() {
    _planNameCtrl.dispose();
    _monthlyCtrl.dispose();
    _yearlyCtrl.dispose();
    _targetCtrl.dispose();
    _returnCtrl.dispose();
    _tenureCtrl.dispose();
    _batchAmountCtrl.dispose();
    _monthlyPremiumCtrl.dispose();
    _sumAssuredCtrl.dispose();
    _notesCtrl.dispose();
    _maturityCtrl.dispose();
    _historyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final service = context.watch<ClientFinancialPlanningService>();
    final plans = user == null
        ? const <InvestmentPlan>[]
        : service.investmentsForClient(user.id);
    final projection = service.calculateInvestmentProjection(
      monthlyContribution: double.tryParse(_monthlyCtrl.text.trim()) ?? 0,
      yearlyContribution: double.tryParse(_yearlyCtrl.text.trim()) ?? 0,
      annualReturnRate: double.tryParse(_returnCtrl.text.trim()) ?? 0,
      tenureMonths: int.tryParse(_tenureCtrl.text.trim()) ?? 0,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Investment Planner')),
      body: user == null
          ? const Center(child: Text('Client session not available.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1080;
                final summary = _InvestmentSummaryHeader(
                  totalPlans: plans.length,
                  reminderDate: _reminderDate,
                  projection: projection,
                );
                final form = _InvestmentEditorCard(
                  formKey: _formKey,
                  selectedType: _selectedType,
                  onTypeChanged: (value) => setState(() => _selectedType = value),
                  planNameCtrl: _planNameCtrl,
                  monthlyCtrl: _monthlyCtrl,
                  yearlyCtrl: _yearlyCtrl,
                  targetCtrl: _targetCtrl,
                  returnCtrl: _returnCtrl,
                  tenureCtrl: _tenureCtrl,
                  batchAmountCtrl: _batchAmountCtrl,
                  monthlyPremiumCtrl: _monthlyPremiumCtrl,
                  sumAssuredCtrl: _sumAssuredCtrl,
                  notesCtrl: _notesCtrl,
                  maturityCtrl: _maturityCtrl,
                  historyCtrl: _historyCtrl,
                  reminderDate: _reminderDate,
                  maturityDate: _maturityDate,
                  isClaimed: _isClaimed,
                  attachmentName: _attachmentName,
                  hasAttachment: _attachmentPath != null,
                  onPickReminder: _pickReminderDate,
                  onPickAttachment: _pickInvestmentAttachment,
                  onViewAttachment: _viewAttachment,
                  onDownloadAttachment: _downloadAttachment,
                  onPickMaturity: _pickMaturityDate,
                  onToggleClaimed: (value) => setState(() => _isClaimed = value),
                  onReset: _resetForm,
                  onSave: () => _savePlan(context, user),
                  editing: _editingId != null,
                );
                final calculator = _InvestmentCalculatorCard(
                  selectedType: _selectedType,
                  projection: projection,
                  targetAmount: double.tryParse(_targetCtrl.text.trim()) ?? 0,
                  tenureMonths: int.tryParse(_tenureCtrl.text.trim()) ?? 0,
                  monthlyAmount: double.tryParse(_monthlyCtrl.text.trim()) ?? 0,
                );
                final history = _InvestmentHistorySection(
                  plans: plans,
                  onEdit: _editPlan,
                  onViewAttachment: _viewSavedAttachment,
                  onDownloadAttachment: _downloadSavedAttachment,
                  onDelete: (plan) => context
                      .read<ClientFinancialPlanningService>()
                      .deleteInvestment(plan),
                );

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    summary,
                    const SizedBox(height: 16),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: form),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: calculator),
                        ],
                      )
                    else ...[
                      form,
                      const SizedBox(height: 16),
                      calculator,
                    ],
                    const SizedBox(height: 16),
                    history,
                  ],
                );
              },
            ),
    );
  }

  Future<void> _pickReminderDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _reminderDate,
    );
    if (picked == null) return;
    setState(() => _reminderDate = picked);
  }

  Future<void> _pickMaturityDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      initialDate: _maturityDate ?? DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _maturityDate = picked;
      _maturityCtrl.text = DateFormat('dd MMM yyyy').format(picked);
    });
  }

  Future<void> _pickInvestmentAttachment() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'png', 'jpg', 'jpeg'],
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final selectedFile = result.files.single;
    final sourcePath = selectedFile.path;
    if (sourcePath == null || sourcePath.isEmpty) return;

    final documentsDir = await getApplicationDocumentsDirectory();
    final storageDir = Directory('${documentsDir.path}/investment_attachments');
    if (!storageDir.existsSync()) {
      storageDir.createSync(recursive: true);
    }

    final safeName = '${DateTime.now().microsecondsSinceEpoch}_${selectedFile.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
    final targetPath = '${storageDir.path}/$safeName';
    await File(sourcePath).copy(targetPath);

    if (!mounted) return;
    setState(() {
      _attachmentPath = targetPath;
      _attachmentName = selectedFile.name;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Attachment saved: ${selectedFile.name}')),
    );
  }

  Future<void> _openAttachment(String attachmentPath) async {
    if (!File(attachmentPath).existsSync()) {
      throw const FileSystemException('Attachment file does not exist.');
    }

    if (Platform.isWindows) {
      await Process.run('explorer', [attachmentPath]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [attachmentPath]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [attachmentPath]);
    } else {
      throw UnsupportedError('Opening attachments is not supported on this platform.');
    }
  }

  Future<void> _viewAttachment() async {
    if (_attachmentPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachment is available to view yet.')),
      );
      return;
    }

    try {
      await _openAttachment(_attachmentPath!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the selected attachment.')),
        );
      }
    }
  }

  Future<void> _downloadAttachment() async {
    if (_attachmentPath == null || !File(_attachmentPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachment is available to download yet.')),
      );
      return;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${documentsDir.path}/investment_downloads');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }

    final targetPath = '${downloadDir.path}/${_attachmentName ?? 'investment_attachment'}';
    await File(_attachmentPath!).copy(targetPath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attachment exported to your documents folder.')),
      );
    }
  }

  Future<void> _viewSavedAttachment(InvestmentPlan plan) async {
    if (plan.attachmentPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This saved plan has no attachment to view.')),
      );
      return;
    }

    try {
      await _openAttachment(plan.attachmentPath!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the saved attachment.')),
        );
      }
    }
  }

  Future<void> _downloadSavedAttachment(InvestmentPlan plan) async {
    if (plan.attachmentPath == null || !File(plan.attachmentPath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This saved plan has no attachment to download.')),
      );
      return;
    }

    final documentsDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${documentsDir.path}/investment_downloads');
    if (!downloadDir.existsSync()) {
      downloadDir.createSync(recursive: true);
    }

    final targetPath = '${downloadDir.path}/${plan.attachmentName ?? 'investment_attachment'}';
    await File(plan.attachmentPath!).copy(targetPath);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved attachment exported to your documents folder.')),
      );
    }
  }

  Future<void> _savePlan(BuildContext context, dynamic user) async {
    if (!_formKey.currentState!.validate()) return;
    final plan = InvestmentPlan(
      id: _editingId ?? 'inv-${DateTime.now().microsecondsSinceEpoch}',
      clientId: user.id,
      clientName: user.firmName,
      investmentType: _selectedType,
      planName: _planNameCtrl.text.trim(),
      monthlyContribution: double.tryParse(_monthlyCtrl.text.trim()) ?? 0,
      yearlyContribution: double.tryParse(_yearlyCtrl.text.trim()) ?? 0,
      targetAmount: _selectedType.needsMaturityTarget
          ? double.tryParse(_targetCtrl.text.trim()) ?? 0
          : 0,
      expectedReturnRate: double.tryParse(_returnCtrl.text.trim()) ?? 0,
      tenureMonths: int.tryParse(_tenureCtrl.text.trim()) ?? 0,
      reminderDate: _reminderDate,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      batchAmount: _selectedType.needsChitFields
          ? double.tryParse(_batchAmountCtrl.text.trim()) ?? 0
          : 0,
      monthlyPremium: _selectedType.needsChitFields
          ? double.tryParse(_monthlyPremiumCtrl.text.trim()) ?? 0
          : 0,
      sumAssuredAmount: _selectedType.needsSumAssured
          ? double.tryParse(_sumAssuredCtrl.text.trim()) ?? 0
          : 0,
      maturityDate: _maturityDate,
      isClaimed: _isClaimed,
      attachmentPath: _attachmentPath,
      attachmentName: _attachmentName,
    );
    await context.read<ClientFinancialPlanningService>().saveInvestment(plan);
    if (!mounted) return;
    _resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Investment plan saved and admin notification sent.'),
      ),
    );
  }

  void _editPlan(InvestmentPlan plan) {
    setState(() {
      _editingId = plan.id;
      _selectedType = plan.investmentType;
      _planNameCtrl.text = plan.planName;
      _monthlyCtrl.text = plan.monthlyContribution > 0
          ? plan.monthlyContribution.toStringAsFixed(0)
          : '';
      _yearlyCtrl.text = plan.yearlyContribution > 0
          ? plan.yearlyContribution.toStringAsFixed(0)
          : '';
      _targetCtrl.text = plan.targetAmount > 0
          ? plan.targetAmount.toStringAsFixed(0)
          : '';
      _returnCtrl.text = plan.expectedReturnRate.toStringAsFixed(2);
      _tenureCtrl.text = plan.tenureMonths.toString();
      _batchAmountCtrl.text =
          plan.batchAmount > 0 ? plan.batchAmount.toStringAsFixed(0) : '';
      _monthlyPremiumCtrl.text = plan.monthlyPremium > 0
          ? plan.monthlyPremium.toStringAsFixed(0)
          : '';
      _sumAssuredCtrl.text = plan.sumAssuredAmount > 0
          ? plan.sumAssuredAmount.toStringAsFixed(0)
          : '';
      _notesCtrl.text = plan.notes;
      _reminderDate = plan.reminderDate;
      _maturityDate = plan.maturityDate;
      _maturityCtrl.text = plan.maturityDate == null
          ? ''
          : DateFormat('dd MMM yyyy').format(plan.maturityDate!);
      _historyCtrl.text = plan.notes;
      _isClaimed = plan.isClaimed;
      _attachmentPath = plan.attachmentPath;
      _attachmentName = plan.attachmentName;
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _selectedType = ClientInvestmentType.sip;
      _planNameCtrl.clear();
      _monthlyCtrl.clear();
      _yearlyCtrl.clear();
      _targetCtrl.clear();
      _returnCtrl.text = '12';
      _tenureCtrl.text = '120';
      _batchAmountCtrl.clear();
      _monthlyPremiumCtrl.clear();
      _sumAssuredCtrl.clear();
      _notesCtrl.clear();
      _maturityCtrl.clear();
      _historyCtrl.clear();
      _maturityDate = null;
      _isClaimed = false;
      _attachmentPath = null;
      _attachmentName = null;
      _reminderDate = DateTime.now().add(const Duration(days: 30));
    });
  }
}

class _InvestmentSummaryHeader extends StatelessWidget {
  const _InvestmentSummaryHeader({
    required this.totalPlans,
    required this.reminderDate,
    required this.projection,
  });

  final int totalPlans;
  final DateTime reminderDate;
  final double projection;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricCard(label: 'Saved Plans', value: '$totalPlans')),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Projected Value',
            value: 'Rs. ${projection.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Next Reminder',
            value: DateFormat('dd MMM yyyy').format(reminderDate),
          ),
        ),
      ],
    );
  }
}

class _InvestmentEditorCard extends StatelessWidget {
  const _InvestmentEditorCard({
    required this.formKey,
    required this.selectedType,
    required this.onTypeChanged,
    required this.planNameCtrl,
    required this.monthlyCtrl,
    required this.yearlyCtrl,
    required this.targetCtrl,
    required this.returnCtrl,
    required this.tenureCtrl,
    required this.batchAmountCtrl,
    required this.monthlyPremiumCtrl,
    required this.sumAssuredCtrl,
    required this.notesCtrl,
    required this.maturityCtrl,
    required this.historyCtrl,
    required this.reminderDate,
    required this.maturityDate,
    required this.isClaimed,
    required this.attachmentName,
    required this.hasAttachment,
    required this.onPickReminder,
    required this.onPickAttachment,
    required this.onViewAttachment,
    required this.onDownloadAttachment,
    required this.onPickMaturity,
    required this.onToggleClaimed,
    required this.onReset,
    required this.onSave,
    required this.editing,
  });

  final GlobalKey<FormState> formKey;
  final ClientInvestmentType selectedType;
  final ValueChanged<ClientInvestmentType> onTypeChanged;
  final TextEditingController planNameCtrl;
  final TextEditingController monthlyCtrl;
  final TextEditingController yearlyCtrl;
  final TextEditingController targetCtrl;
  final TextEditingController returnCtrl;
  final TextEditingController tenureCtrl;
  final TextEditingController batchAmountCtrl;
  final TextEditingController monthlyPremiumCtrl;
  final TextEditingController sumAssuredCtrl;
  final TextEditingController notesCtrl;
  final TextEditingController maturityCtrl;
  final TextEditingController historyCtrl;
  final DateTime reminderDate;
  final DateTime? maturityDate;
  final bool isClaimed;
  final String? attachmentName;
  final bool hasAttachment;
  final VoidCallback onPickReminder;
  final VoidCallback onPickAttachment;
  final VoidCallback onViewAttachment;
  final VoidCallback onDownloadAttachment;
  final VoidCallback onPickMaturity;
  final ValueChanged<bool> onToggleClaimed;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? 'Update Investment Plan' : 'Create Investment Plan',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ClientInvestmentType>(
                initialValue: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Investment type',
                  border: OutlineInputBorder(),
                ),
                items: ClientInvestmentType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) onTypeChanged(value);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: planNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Plan label',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter plan label'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: monthlyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Monthly amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: yearlyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Yearly amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedType.needsMaturityTarget)
                TextFormField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target / maturity value',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                TextFormField(
                  controller: sumAssuredCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'How much secured amount do you want?',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: returnCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Expected return %',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: tenureCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Tenure in months',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (selectedType.needsChitFields) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: batchAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Chit batch amount',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: monthlyPremiumCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly premium you can pay',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (selectedType.needsSumAssured &&
                  selectedType != ClientInvestmentType.healthInsurance) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: sumAssuredCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coverage / sum assured',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder date'),
                subtitle: Text(DateFormat('dd MMM yyyy').format(reminderDate)),
                trailing: OutlinedButton(
                  onPressed: onPickReminder,
                  child: const Text('Pick date'),
                ),
              ),
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Maturity / closure date'),
                subtitle: Text(maturityDate == null ? 'Not set' : DateFormat('dd MMM yyyy').format(maturityDate!)),
                trailing: OutlinedButton(
                  onPressed: onPickMaturity,
                  child: const Text('Set date'),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Claim / matured policy'),
                value: isClaimed,
                onChanged: onToggleClaimed,
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFDCE3EE)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Bond / policy document',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (hasAttachment && attachmentName != null)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Saved: $attachmentName',
                              style: const TextStyle(color: Color(0xFF1A4FD9)),
                            ),
                          ),
                          IconButton(
                            onPressed: onViewAttachment,
                            icon: const Icon(Icons.visibility_outlined),
                            tooltip: 'View attachment',
                          ),
                          IconButton(
                            onPressed: onDownloadAttachment,
                            icon: const Icon(Icons.download_outlined),
                            tooltip: 'Download attachment',
                          ),
                        ],
                      )
                    else
                      const Text('Upload a scanned bond or PDF for your record.'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: onPickAttachment,
                      icon: const Icon(Icons.attach_file_outlined),
                      label: const Text('Upload bond / PDF'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes / planning detail',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: historyCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'History / policy remarks',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  OutlinedButton(onPressed: onReset, child: const Text('Reset')),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onSave,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(editing ? 'Update Plan' : 'Save Plan'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvestmentCalculatorCard extends StatelessWidget {
  const _InvestmentCalculatorCard({
    required this.selectedType,
    required this.projection,
    required this.targetAmount,
    required this.tenureMonths,
    required this.monthlyAmount,
  });

  final ClientInvestmentType selectedType;
  final double projection;
  final double targetAmount;
  final int tenureMonths;
  final double monthlyAmount;

  @override
  Widget build(BuildContext context) {
    final gap = targetAmount > 0 ? (targetAmount - projection) : 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFE8F0FE),
                  ),
                  child: const Icon(Icons.savings_outlined, color: Color(0xFF1A4FD9)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Investment Dashboard',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        selectedType.displayName,
                        style: const TextStyle(color: Color(0xFF5F7188)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _ProjectionLine(label: 'Monthly amount', value: 'Rs. ${monthlyAmount.toStringAsFixed(0)}'),
            _ProjectionLine(label: 'Tenure', value: '$tenureMonths months'),
            _ProjectionLine(label: 'Projected corpus', value: 'Rs. ${projection.toStringAsFixed(0)}'),
            if (selectedType.needsMaturityTarget)
              _ProjectionLine(label: 'Gap to target', value: 'Rs. ${gap > 0 ? gap.toStringAsFixed(0) : '0'}'),
            const Divider(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F8FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Projection',
                    style: TextStyle(fontSize: 13, color: Color(0xFF5F7188), fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rs. ${projection.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvestmentHistorySection extends StatelessWidget {
  const _InvestmentHistorySection({
    required this.plans,
    required this.onEdit,
    required this.onViewAttachment,
    required this.onDownloadAttachment,
    required this.onDelete,
  });

  final List<InvestmentPlan> plans;
  final ValueChanged<InvestmentPlan> onEdit;
  final ValueChanged<InvestmentPlan> onViewAttachment;
  final ValueChanged<InvestmentPlan> onDownloadAttachment;
  final ValueChanged<InvestmentPlan> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved Investment Plans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (plans.isEmpty)
              const Text('No investment plans saved yet.')
            else
              ...plans.map(
                (plan) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(plan.planName),
                    subtitle: Text(
                      '${plan.investmentType.displayName}\nReminder ${DateFormat('dd MMM yyyy').format(plan.reminderDate)}${plan.maturityDate == null ? '' : ' · Maturity ${DateFormat('dd MMM yyyy').format(plan.maturityDate!)}'}${plan.isClaimed ? ' · Claimed' : ''}${plan.attachmentName == null ? '' : '\nAttachment: ${plan.attachmentName}'}',
                    ),
                    isThreeLine: plan.attachmentName != null,
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        if (plan.attachmentPath != null)
                          IconButton(
                            onPressed: () => onViewAttachment(plan),
                            icon: const Icon(Icons.visibility_outlined),
                            tooltip: 'View attachment',
                          ),
                        if (plan.attachmentPath != null)
                          IconButton(
                            onPressed: () => onDownloadAttachment(plan),
                            icon: const Icon(Icons.download_outlined),
                            tooltip: 'Download attachment',
                          ),
                        IconButton(
                          onPressed: () => onEdit(plan),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () => onDelete(plan),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE3EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF5F7188), fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _ProjectionLine extends StatelessWidget {
  const _ProjectionLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Color(0xFF5F7188)))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
