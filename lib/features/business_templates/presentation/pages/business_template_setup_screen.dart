import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/business_templates/models/business_template_models.dart';
import 'package:chirag_accounting/features/business_templates/services/business_template_service.dart';

class BusinessTemplateSetupScreen extends StatefulWidget {
  const BusinessTemplateSetupScreen({
    required this.clientId,
    required this.clientName,
    this.onSaved,
    this.canManageExistingTemplate = true,
    this.hasVoucherEntries = false,
    super.key,
  });

  final String clientId;
  final String clientName;
  final ValueChanged<BusinessTemplateProfile>? onSaved;
  final bool canManageExistingTemplate;
  final bool hasVoucherEntries;

  @override
  State<BusinessTemplateSetupScreen> createState() =>
      _BusinessTemplateSetupScreenState();
}

class _BusinessTemplateSetupScreenState
    extends State<BusinessTemplateSetupScreen> {
  final BusinessTemplateService _service = BusinessTemplateService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customBusinessController =
      TextEditingController();
  final TextEditingController _taxSearchController = TextEditingController();
  final Set<String> _selectedBusinessTypes = <String>{};
  final Set<String> _selectedTemplateKeys = <String>{};
  final Set<BusinessNature> _selectedNatures = <BusinessNature>{};
  final Set<String> _enabledDocuments = <String>{};
  final Set<String> _enabledFields = <String>{};
  String _category = 'All';
  int _currentVersion = 0;
  bool _loading = true;
  bool _saving = false;

  bool get _editingLocked =>
      _currentVersion > 0 &&
      widget.hasVoucherEntries &&
      !widget.canManageExistingTemplate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customBusinessController.dispose();
    _taxSearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _service.loadProfile(widget.clientId);
    if (!mounted) return;
    setState(() {
      if (profile != null) {
        _selectedBusinessTypes.addAll(profile.businessTypes);
        _selectedTemplateKeys.addAll(profile.templateKeys);
        _selectedNatures.addAll(profile.businessNatures);
        _enabledDocuments.addAll(profile.enabledDocuments);
        _enabledFields.addAll(profile.enabledFields);
        _customBusinessController.text = profile.customBusinessName;
        _currentVersion = profile.version;
      }
      _loading = false;
    });
  }

  List<BusinessTypeOption> get _visibleBusinessTypes {
    final query = _searchController.text.trim().toLowerCase();
    return BusinessTemplateCatalog.businessTypes
        .where((option) {
          final categoryMatches =
              _category == 'All' || option.category == _category;
          final queryMatches =
              query.isEmpty ||
              option.name.toLowerCase().contains(query) ||
              option.category.toLowerCase().contains(query);
          return categoryMatches && queryMatches;
        })
        .toList(growable: false);
  }

  void _toggleBusinessType(BusinessTypeOption option, bool selected) {
    if (_editingLocked) return;
    setState(() {
      if (selected) {
        _selectedBusinessTypes.add(option.name);
      } else {
        _selectedBusinessTypes.remove(option.name);
      }
      _rebuildRecommendations();
    });
  }

  void _selectAllVisible() {
    if (_editingLocked) return;
    setState(() {
      _selectedBusinessTypes.addAll(
        BusinessTemplateCatalog.businessTypes
            .where((option) => option.name != 'Other / Custom Business')
            .map((option) => option.name),
      );
      _rebuildRecommendations();
    });
  }

  void _rebuildRecommendations() {
    _selectedTemplateKeys
      ..clear()
      ..addAll(
        BusinessTemplateCatalog.businessTypes
            .where((option) => _selectedBusinessTypes.contains(option.name))
            .map((option) => option.templateKey),
      );
    for (final key in _selectedTemplateKeys) {
      final template = BusinessTemplateCatalog.byKey(key);
      if (template != null) _selectedNatures.addAll(template.defaultNatures);
    }
    _enabledDocuments
      ..clear()
      ..addAll(
        BusinessTemplateService.suggestedDocuments(_selectedTemplateKeys),
      );
    _enabledFields
      ..clear()
      ..addAll(BusinessTemplateService.suggestedFields(_selectedTemplateKeys));
  }

  Future<void> _save() async {
    if (_editingLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voucher entries already exist. Admin permission is required to create a new template version.',
          ),
        ),
      );
      return;
    }
    if (_selectedBusinessTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one business type.')),
      );
      return;
    }
    if (_selectedBusinessTypes.contains('Other / Custom Business') &&
        _customBusinessController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the custom business name.')),
      );
      return;
    }
    setState(() => _saving = true);
    final profile = await _service.saveProfile(
      clientId: widget.clientId,
      templateKeys: _selectedTemplateKeys.toList(growable: false),
      businessTypes: _selectedBusinessTypes.toList(growable: false),
      businessNatures: _selectedNatures.toList(growable: false),
      enabledDocuments: _enabledDocuments.toList(growable: false),
      enabledFields: _enabledFields.toList(growable: false),
      customBusinessName: _customBusinessController.text,
      canUpdateExisting:
          _currentVersion == 0 ||
          !widget.hasVoucherEntries ||
          widget.canManageExistingTemplate,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _currentVersion = profile.version;
    });
    widget.onSaved?.call(profile);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Business template v${profile.version} saved and voucher configuration generated. Existing transactions and inventory data are unchanged.',
        ),
      ),
    );
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final categories = <String>[
      'All',
      ...BusinessTemplateCatalog.businessTypesByCategory.keys,
    ];
    return ColoredBox(
      color: const Color(0xFFF3F6FA),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return ListView(
            key: const ValueKey('business-template-page-scroll'),
            padding: EdgeInsets.all(wide ? 18 : 12),
            children: <Widget>[
              _header(wide),
              const SizedBox(height: 14),
              _statsRow(wide),
              const SizedBox(height: 16),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 6, child: _businessSelector(categories)),
                    const SizedBox(width: 14),
                    Expanded(flex: 5, child: _configurationPanel()),
                  ],
                )
              else ...<Widget>[
                _businessSelector(categories),
                const SizedBox(height: 14),
                _configurationPanel(),
              ],
              const SizedBox(height: 14),
              _itemMasterPanel(),
              const SizedBox(height: 14),
              _taxCodePanel(),
              const SizedBox(height: 14),
              _saveBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _header(bool wide) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF123C69), Color(0xFF1B5A9E)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF123C69).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          SizedBox(
            width: wide ? 620 : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize_outlined,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Universal Business Template System',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.clientName.isEmpty
                            ? 'Configure billing, masters and documents'
                            : widget.clientName,
                        style: const TextStyle(color: Color(0xFFDCE9F7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD166),
              borderRadius: BorderRadius.circular(30),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFFFFD166).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.history, size: 17, color: Color(0xFF123C69)),
                const SizedBox(width: 6),
                Text(
                  _currentVersion == 0
                      ? 'NEW SETUP'
                      : 'VERSION $_currentVersion',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF123C69),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Infographic KPI tiles summarising the live selection counts across all sections.
  Widget _statsRow(bool wide) {
    final stats = <(IconData, String, int, Color)>[
      (Icons.storefront_outlined, 'Activities', _selectedBusinessTypes.length, const Color(0xFF1565C0)),
      (Icons.category_outlined, 'Business Natures', _selectedNatures.length, const Color(0xFF7C4DFF)),
      (Icons.receipt_long_outlined, 'Billing Templates', _selectedTemplateKeys.length, const Color(0xFF00897B)),
      (Icons.article_outlined, 'Documents Enabled', _enabledDocuments.length, const Color(0xFFEF6C00)),
      (Icons.inventory_2_outlined, 'Item Fields', _enabledFields.length, const Color(0xFFD81B60)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = wide
            ? (constraints.maxWidth - 4 * 12) / 5
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            for (final stat in stats)
              SizedBox(
                width: tileWidth,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE1E8F2)),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: const Color(0xFF17324D).withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: stat.$4.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(stat.$1, size: 18, color: stat.$4),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${stat.$3}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: stat.$4,
                              ),
                            ),
                            Text(
                              stat.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF60758A),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _businessSelector(List<String> categories) {
    return _panel(
      title: 'Business Activities',
      subtitle: 'Search and select one or more activities',
      icon: Icons.storefront_outlined,
      step: 1,
      child: Column(
        children: <Widget>[
          TextField(
            key: const ValueKey('business-template-search'),
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search grocery, hardware, contractor, services...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              TextButton.icon(
                key: const ValueKey('select-all-business-templates'),
                onPressed: _editingLocked ? null : _selectAllVisible,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Select all templates'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _editingLocked
                    ? null
                    : () => setState(() {
                        _selectedBusinessTypes.clear();
                        _rebuildRecommendations();
                      }),
                child: const Text('Clear selection'),
              ),
            ],
          ),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final category = categories[index];
                return ChoiceChip(
                  label: Text(category),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 310),
            child: _visibleBusinessTypes.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No matching business type.'),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _visibleBusinessTypes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final option = _visibleBusinessTypes[index];
                      final selected = _selectedBusinessTypes.contains(
                        option.name,
                      );
                      return Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFE8F1FC)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          activeColor: const Color(0xFF1565C0),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          value: selected,
                          title: Text(
                            option.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${option.category}  |  ${BusinessTemplateCatalog.byKey(option.templateKey)?.name ?? option.templateKey}',
                          ),
                          onChanged: _editingLocked
                              ? null
                              : (value) =>
                                    _toggleBusinessType(option, value ?? false),
                        ),
                      );
                    },
                  ),
          ),
          if (_selectedBusinessTypes.contains(
            'Other / Custom Business',
          )) ...<Widget>[
            const SizedBox(height: 8),
            TextField(
              controller: _customBusinessController,
              readOnly: _editingLocked,
              decoration: const InputDecoration(
                labelText: 'Custom business name',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _configurationPanel() {
    final selectedTemplates = _selectedTemplateKeys
        .map(BusinessTemplateCatalog.byKey)
        .whereType<BusinessTemplateDefinition>()
        .toList(growable: false);
    return Column(
      children: <Widget>[
        _panel(
          title: 'Business Nature',
          subtitle: 'Multiple selections are supported',
          icon: Icons.category_outlined,
          step: 2,
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: BusinessNature.values
                .map((nature) {
                  return FilterChip(
                    label: Text(nature.label),
                    selected: _selectedNatures.contains(nature),
                    onSelected: _editingLocked
                        ? null
                        : (selected) => setState(() {
                            selected
                                ? _selectedNatures.add(nature)
                                : _selectedNatures.remove(nature);
                          }),
                  );
                })
                .toList(growable: false),
          ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Auto-selected Billing Templates',
          subtitle: '${selectedTemplates.length} reusable template(s)',
          icon: Icons.receipt_long_outlined,
          step: 3,
          child: selectedTemplates.isEmpty
              ? const Text(
                  'Select a business activity to configure billing automatically.',
                )
              : Column(
                  children: selectedTemplates
                      .map((template) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.description_outlined,
                            color: Color(0xFF1565C0),
                          ),
                          title: Text(
                            template.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${template.defaultPrintFormat} | ${template.stockTracking ? 'Stock enabled' : 'Service mode'}',
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
        ),
        const SizedBox(height: 12),
        _panel(
          title: 'Voucher & Document Centre',
          subtitle:
              'Standard vouchers stay enabled; optional documents are editable',
          icon: Icons.article_outlined,
          step: 4,
          child: Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final document in BusinessTemplateCatalog.standardVouchers)
                InputChip(
                  label: Text(document),
                  avatar: const Icon(Icons.lock_outline, size: 15),
                  selected: true,
                  onSelected: null,
                ),
              for (final document in BusinessTemplateCatalog.allDocuments)
                FilterChip(
                  label: Text(document),
                  selected: _enabledDocuments.contains(document),
                  onSelected: _editingLocked
                      ? null
                      : (selected) => setState(() {
                          selected
                              ? _enabledDocuments.add(document)
                              : _enabledDocuments.remove(document);
                        }),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemMasterPanel() {
    return _panel(
      title: 'Dynamic Item / Service Master',
      subtitle:
          'Core fields are protected; optional attributes can be enabled per client',
      icon: Icons.inventory_2_outlined,
      step: 5,
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: BusinessTemplateCatalog.itemMasterFields
            .map((field) {
              final selected =
                  field.required || _enabledFields.contains(field.label);
              return FilterChip(
                label: Text(field.label),
                avatar: field.required
                    ? const Icon(Icons.lock_outline, size: 15)
                    : null,
                selected: selected,
                onSelected: field.required || _editingLocked
                    ? null
                    : (value) => setState(() {
                        value
                            ? _enabledFields.add(field.label)
                            : _enabledFields.remove(field.label);
                      }),
              );
            })
            .toList(growable: false),
      ),
    );
  }

  Widget _taxCodePanel() {
    final suggestions = BusinessTemplateService.searchTaxCodes(
      _selectedTemplateKeys,
      _taxSearchController.text,
    );
    return _panel(
      title: 'HSN / SAC & GST Suggestions',
      subtitle:
          'Searchable recommendations; authorised users can override values in the item master',
      icon: Icons.percent_outlined,
      step: 6,
      child: Column(
        children: <Widget>[
          TextField(
            key: const ValueKey('hsn-sac-search'),
            controller: _taxSearchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search HSN, SAC, category or description',
              prefixIcon: Icon(Icons.manage_search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          if (suggestions.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No template suggestion. Use the HSN/SAC master to search or add an authorised override.',
              ),
            )
          else
            for (final suggestion in suggestions)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.verified_outlined,
                  color: Color(0xFF16795A),
                ),
                title: Text('${suggestion.code}  |  ${suggestion.category}'),
                subtitle: Text(suggestion.description),
                trailing: Text(
                  '${suggestion.gstRate.toStringAsFixed(0)}% GST',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF17324D).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Text(
            _editingLocked
                ? 'Voucher entries exist. This version is locked; ask an administrator to create a new version.'
                : 'Template changes create a full new version. Existing transactions, stock and audit records are never changed.',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _editingLocked
                  ? const Color(0xFF9A4D00)
                  : const Color(0xFF40566E),
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('save-business-template'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _saving || _editingLocked ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              _editingLocked
                  ? 'Admin Permission Required'
                  : _currentVersion == 0
                  ? 'Generate Vouchers'
                  : 'Generate Version ${_currentVersion + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
    required int step,
    IconData icon = Icons.dashboard_customize_outlined,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF17324D).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF123C69),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F1FC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF1565C0)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF17324D),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60758A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}
