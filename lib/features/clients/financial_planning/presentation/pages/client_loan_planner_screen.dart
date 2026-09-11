import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/financial_planning/models/client_financial_planning_models.dart';
import 'package:chirag_accounting/features/clients/financial_planning/services/client_financial_planning_service.dart';

class ClientLoanPlannerScreen extends StatefulWidget {
  const ClientLoanPlannerScreen({super.key});

  @override
  State<ClientLoanPlannerScreen> createState() => _ClientLoanPlannerScreenState();
}

class _ClientLoanPlannerScreenState extends State<ClientLoanPlannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _planNameCtrl = TextEditingController();
  final _lenderCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '10');
  final _tenureCtrl = TextEditingController(text: '60');
  final _utilizedAmountCtrl = TextEditingController();
  final _utilizedDaysCtrl = TextEditingController(text: '30');
  final _notesCtrl = TextEditingController();
  final _vehicleModelCtrl = TextEditingController();
  final _maturityCtrl = TextEditingController();
  final _historyCtrl = TextEditingController();

  ClientLoanType _selectedType = ClientLoanType.home;
  DateTime _reminderDate = DateTime.now().add(const Duration(days: 30));
  DateTime? _maturityDate;
  bool _isClaimed = false;
  String _selectedVehicleMake = vehicleLoanCatalog.keys.first;
  String? _editingLoanId;

  @override
  void dispose() {
    _planNameCtrl.dispose();
    _lenderCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    _utilizedAmountCtrl.dispose();
    _utilizedDaysCtrl.dispose();
    _notesCtrl.dispose();
    _vehicleModelCtrl.dispose();
    _maturityCtrl.dispose();
    _historyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final service = context.watch<ClientFinancialPlanningService>();
    final loans = user == null
        ? const <LoanPlan>[]
        : service.loansForClient(user.id);
    final principal = double.tryParse(_principalCtrl.text.trim()) ?? 0;
    final rate = double.tryParse(_rateCtrl.text.trim()) ?? 0;
    final tenure = int.tryParse(_tenureCtrl.text.trim()) ?? 0;
    final utilizedAmount = double.tryParse(_utilizedAmountCtrl.text.trim()) ?? 0;
    final utilizedDays = int.tryParse(_utilizedDaysCtrl.text.trim()) ?? 0;
    final emi = _selectedType.usesDailyInterest
        ? service.calculateOdCcInterest(
            utilizedAmount: utilizedAmount,
            annualRate: rate,
            utilizedDays: utilizedDays,
          )
        : service.calculateLoanEmi(
            principal: principal,
            annualRate: rate,
            tenureMonths: tenure,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Loan Planner')),
      body: user == null
          ? const Center(child: Text('Client session not available.'))
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1080;
                final summary = _LoanSummaryHeader(
                  totalPlans: loans.length,
                  reminderDate: _reminderDate,
                  metricLabel:
                      _selectedType.usesDailyInterest ? 'Estimated Interest' : 'EMI',
                  metricValue: emi,
                );
                final form = _LoanEditorCard(
                  formKey: _formKey,
                  selectedType: _selectedType,
                  onTypeChanged: (value) {
                    setState(() {
                      _selectedType = value;
                      if (!_selectedType.requiresVehicleSelection) {
                        _vehicleModelCtrl.clear();
                      }
                    });
                  },
                  planNameCtrl: _planNameCtrl,
                  lenderCtrl: _lenderCtrl,
                  principalCtrl: _principalCtrl,
                  rateCtrl: _rateCtrl,
                  tenureCtrl: _tenureCtrl,
                  utilizedAmountCtrl: _utilizedAmountCtrl,
                  utilizedDaysCtrl: _utilizedDaysCtrl,
                  notesCtrl: _notesCtrl,
                  vehicleMake: _selectedVehicleMake,
                  onVehicleMakeChanged: (value) {
                    setState(() {
                      _selectedVehicleMake = value;
                      _vehicleModelCtrl.clear();
                    });
                  },
                  vehicleModelCtrl: _vehicleModelCtrl,
                  maturityCtrl: _maturityCtrl,
                  historyCtrl: _historyCtrl,
                  reminderDate: _reminderDate,
                  maturityDate: _maturityDate,
                  isClaimed: _isClaimed,
                  onPickReminder: _pickReminderDate,
                  onPickMaturity: _pickMaturityDate,
                  onToggleClaimed: (value) => setState(() => _isClaimed = value),
                  onReset: _resetForm,
                  onSave: () => _saveLoan(context, user),
                  editing: _editingLoanId != null,
                );
                final calculator = _LoanCalculatorCard(
                  selectedType: _selectedType,
                  principal: principal,
                  rate: rate,
                  tenureMonths: tenure,
                  utilizedAmount: utilizedAmount,
                  utilizedDays: utilizedDays,
                  computedValue: emi,
                );
                final history = _LoanHistorySection(
                  loans: loans,
                  onEdit: _editLoan,
                  onDelete: (plan) => context
                      .read<ClientFinancialPlanningService>()
                      .deleteLoan(plan),
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

  Future<void> _saveLoan(BuildContext context, dynamic user) async {
    if (!_formKey.currentState!.validate()) return;
    final plan = LoanPlan(
      id: _editingLoanId ?? 'loan-${DateTime.now().microsecondsSinceEpoch}',
      clientId: user.id,
      clientName: user.firmName,
      loanType: _selectedType,
      planName: _planNameCtrl.text.trim(),
      lenderName: _lenderCtrl.text.trim(),
      principalAmount: double.tryParse(_principalCtrl.text.trim()) ?? 0,
      annualInterestRate: double.tryParse(_rateCtrl.text.trim()) ?? 0,
      tenureMonths: int.tryParse(_tenureCtrl.text.trim()) ?? 0,
      reminderDate: _reminderDate,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      vehicleMake: _selectedType.requiresVehicleSelection
          ? _selectedVehicleMake
          : '',
      vehicleModel:
          _selectedType.requiresVehicleSelection ? _vehicleModelCtrl.text.trim() : '',
      utilizedAmount:
          _selectedType.usesDailyInterest ? double.tryParse(_utilizedAmountCtrl.text.trim()) ?? 0 : 0,
      utilizedDays:
          _selectedType.usesDailyInterest ? int.tryParse(_utilizedDaysCtrl.text.trim()) ?? 0 : 0,
      maturityDate: _maturityDate,
      isClaimed: _isClaimed,
    );
    await context.read<ClientFinancialPlanningService>().saveLoan(plan);
    if (!mounted) return;
    _resetForm();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loan plan saved and admin notification sent.')),
    );
  }

  void _editLoan(LoanPlan plan) {
    setState(() {
      _editingLoanId = plan.id;
      _selectedType = plan.loanType;
      _planNameCtrl.text = plan.planName;
      _lenderCtrl.text = plan.lenderName;
      _principalCtrl.text = plan.principalAmount.toStringAsFixed(0);
      _rateCtrl.text = plan.annualInterestRate.toStringAsFixed(2);
      _tenureCtrl.text = plan.tenureMonths.toString();
      _utilizedAmountCtrl.text = plan.utilizedAmount > 0
          ? plan.utilizedAmount.toStringAsFixed(0)
          : '';
      _utilizedDaysCtrl.text = plan.utilizedDays.toString();
      _notesCtrl.text = plan.notes;
      _reminderDate = plan.reminderDate;
      _maturityDate = plan.maturityDate;
      _maturityCtrl.text = plan.maturityDate == null
          ? ''
          : DateFormat('dd MMM yyyy').format(plan.maturityDate!);
      _historyCtrl.text = plan.notes;
      _isClaimed = plan.isClaimed;
      _selectedVehicleMake = plan.vehicleMake.isNotEmpty
          ? plan.vehicleMake
          : vehicleLoanCatalog.keys.first;
      _vehicleModelCtrl.text = plan.vehicleModel;
    });
  }

  void _resetForm() {
    setState(() {
      _editingLoanId = null;
      _selectedType = ClientLoanType.home;
      _planNameCtrl.clear();
      _lenderCtrl.clear();
      _principalCtrl.clear();
      _rateCtrl.text = '10';
      _tenureCtrl.text = '60';
      _utilizedAmountCtrl.clear();
      _utilizedDaysCtrl.text = '30';
      _notesCtrl.clear();
      _vehicleModelCtrl.clear();
      _maturityCtrl.clear();
      _historyCtrl.clear();
      _maturityDate = null;
      _isClaimed = false;
      _selectedVehicleMake = vehicleLoanCatalog.keys.first;
      _reminderDate = DateTime.now().add(const Duration(days: 30));
    });
  }
}

class _LoanSummaryHeader extends StatelessWidget {
  const _LoanSummaryHeader({
    required this.totalPlans,
    required this.reminderDate,
    required this.metricLabel,
    required this.metricValue,
  });

  final int totalPlans;
  final DateTime reminderDate;
  final String metricLabel;
  final double metricValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _TopMetricCard(label: 'Saved Loans', value: '$totalPlans')),
        const SizedBox(width: 12),
        Expanded(
          child: _TopMetricCard(
            label: metricLabel,
            value: 'Rs. ${metricValue.toStringAsFixed(0)}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TopMetricCard(
            label: 'Next Reminder',
            value: DateFormat('dd MMM yyyy').format(reminderDate),
          ),
        ),
      ],
    );
  }
}

class _LoanEditorCard extends StatelessWidget {
  const _LoanEditorCard({
    required this.formKey,
    required this.selectedType,
    required this.onTypeChanged,
    required this.planNameCtrl,
    required this.lenderCtrl,
    required this.principalCtrl,
    required this.rateCtrl,
    required this.tenureCtrl,
    required this.utilizedAmountCtrl,
    required this.utilizedDaysCtrl,
    required this.notesCtrl,
    required this.vehicleMake,
    required this.onVehicleMakeChanged,
    required this.vehicleModelCtrl,
    required this.maturityCtrl,
    required this.historyCtrl,
    required this.reminderDate,
    required this.maturityDate,
    required this.isClaimed,
    required this.onPickReminder,
    required this.onPickMaturity,
    required this.onToggleClaimed,
    required this.onReset,
    required this.onSave,
    required this.editing,
  });

  final GlobalKey<FormState> formKey;
  final ClientLoanType selectedType;
  final ValueChanged<ClientLoanType> onTypeChanged;
  final TextEditingController planNameCtrl;
  final TextEditingController lenderCtrl;
  final TextEditingController principalCtrl;
  final TextEditingController rateCtrl;
  final TextEditingController tenureCtrl;
  final TextEditingController utilizedAmountCtrl;
  final TextEditingController utilizedDaysCtrl;
  final TextEditingController notesCtrl;
  final String vehicleMake;
  final ValueChanged<String> onVehicleMakeChanged;
  final TextEditingController vehicleModelCtrl;
  final TextEditingController maturityCtrl;
  final TextEditingController historyCtrl;
  final DateTime reminderDate;
  final DateTime? maturityDate;
  final bool isClaimed;
  final VoidCallback onPickReminder;
  final VoidCallback onPickMaturity;
  final ValueChanged<bool> onToggleClaimed;
  final VoidCallback onReset;
  final VoidCallback onSave;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final models = vehicleLoanCatalog[vehicleMake] ?? const <String>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing ? 'Update Loan Plan' : 'Create Loan Plan',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ClientLoanType>(
                initialValue: selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Loan type',
                  border: OutlineInputBorder(),
                ),
                items: ClientLoanType.values
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
                  labelText: 'Loan name / purpose',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter loan name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: lenderCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bank / lender',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: principalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: selectedType.usesDailyInterest
                            ? 'Sanction limit'
                            : 'Principal amount',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        final amount = double.tryParse(value ?? '');
                        if (amount == null || amount <= 0) {
                          return 'Enter valid amount';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: rateCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Interest % p.a.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (selectedType.usesDailyInterest)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: utilizedAmountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Used amount',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: utilizedDaysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Used days',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                )
              else
                TextFormField(
                  controller: tenureCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tenure in months',
                    border: OutlineInputBorder(),
                  ),
                ),
              if (selectedType.requiresVehicleSelection) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: vehicleMake,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle make',
                    border: OutlineInputBorder(),
                  ),
                  items: vehicleLoanCatalog.keys
                      .map(
                        (make) => DropdownMenuItem(value: make, child: Text(make)),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) onVehicleMakeChanged(value);
                  },
                ),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return models;
                    return models.where(
                      (model) => model.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                    );
                  },
                  onSelected: (value) => vehicleModelCtrl.text = value,
                  fieldViewBuilder: (context, controller, focusNode, onSubmit) {
                    controller.text = vehicleModelCtrl.text;
                    controller.selection = TextSelection.fromPosition(
                      TextPosition(offset: controller.text.length),
                    );
                    controller.addListener(() {
                      vehicleModelCtrl.text = controller.text;
                    });
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle model',
                        border: OutlineInputBorder(),
                      ),
                    );
                  },
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
              TextFormField(
                controller: notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes / reminder details',
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

class _LoanCalculatorCard extends StatelessWidget {
  const _LoanCalculatorCard({
    required this.selectedType,
    required this.principal,
    required this.rate,
    required this.tenureMonths,
    required this.utilizedAmount,
    required this.utilizedDays,
    required this.computedValue,
  });

  final ClientLoanType selectedType;
  final double principal;
  final double rate;
  final int tenureMonths;
  final double utilizedAmount;
  final int utilizedDays;
  final double computedValue;

  @override
  Widget build(BuildContext context) {
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
                  child: const Icon(Icons.calculate_outlined, color: Color(0xFF1A4FD9)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'EMI / Interest Dashboard',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        selectedType.usesDailyInterest
                            ? 'OD/CC interest is based on utilized amount and used days.'
                            : 'Reducing-balance EMI estimate for the selected loan.',
                        style: const TextStyle(color: Color(0xFF5F7188)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _CalcLine(label: 'Loan type', value: selectedType.displayName),
            _CalcLine(
              label: selectedType.usesDailyInterest ? 'Used amount' : 'Principal',
              value: 'Rs. ${(selectedType.usesDailyInterest ? utilizedAmount : principal).toStringAsFixed(0)}',
            ),
            _CalcLine(label: 'Interest', value: '${rate.toStringAsFixed(2)}% p.a.'),
            if (selectedType.usesDailyInterest)
              _CalcLine(label: 'Used days', value: '$utilizedDays days')
            else
              _CalcLine(label: 'Tenure', value: '$tenureMonths months'),
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
                  Text(
                    selectedType.usesDailyInterest
                        ? 'Estimated Current Interest'
                        : 'Estimated Monthly EMI',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF5F7188),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Rs. ${computedValue.toStringAsFixed(0)}',
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

class _LoanHistorySection extends StatelessWidget {
  const _LoanHistorySection({
    required this.loans,
    required this.onEdit,
    required this.onDelete,
  });

  final List<LoanPlan> loans;
  final ValueChanged<LoanPlan> onEdit;
  final ValueChanged<LoanPlan> onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Saved Loan Plans',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (loans.isEmpty)
              const Text('No loan plans saved yet.')
            else
              ...loans.map(
                (plan) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(plan.planName),
                    subtitle: Text(
                      '${plan.loanType.displayName} · ${plan.lenderName.isEmpty ? 'No lender' : plan.lenderName}\nReminder ${DateFormat('dd MMM yyyy').format(plan.reminderDate)}${plan.maturityDate == null ? '' : ' · Maturity ${DateFormat('dd MMM yyyy').format(plan.maturityDate!)}'}${plan.isClaimed ? ' · Claimed' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 8,
                      children: [
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

class _TopMetricCard extends StatelessWidget {
  const _TopMetricCard({required this.label, required this.value});

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

class _CalcLine extends StatelessWidget {
  const _CalcLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF5F7188))),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
