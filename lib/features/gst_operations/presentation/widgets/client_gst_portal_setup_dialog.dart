import 'package:flutter/material.dart';

import 'package:chirag_accounting/features/gst_operations/services/client_gst_portal_connection_service.dart';

class ClientGstPortalSetupDialog extends StatefulWidget {
  const ClientGstPortalSetupDialog({
    required this.title,
    required this.connectionType,
    super.key,
  });

  final String title;
  final ClientGstPortalConnectionType connectionType;

  @override
  State<ClientGstPortalSetupDialog> createState() =>
      _ClientGstPortalSetupDialogState();
}

class _ClientGstPortalSetupDialogState
    extends State<ClientGstPortalSetupDialog> {
  final _service = ClientGstPortalConnectionService();
  final _formKey = GlobalKey<FormState>();
  final _providerController = TextEditingController(text: 'Government Portal');
  final _baseUrlController = TextEditingController();
  final _credentialController = TextEditingController();
  final _thresholdController = TextEditingController();
  String _authType = 'token';
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _providerController.dispose();
    _baseUrlController.dispose();
    _credentialController.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final connection = await _service.load(widget.connectionType);
      if (!mounted) return;
      _providerController.text = connection.providerName ?? 'Government Portal';
      _baseUrlController.text = connection.baseUrl ?? '';
      _authType = connection.authType ?? 'token';
        _enabled = connection.enabled;
        _thresholdController.text = connection.applicabilityThreshold?.toString() ??
          (widget.connectionType == ClientGstPortalConnectionType.ewayBill
            ? '50000'
            : '');
    } catch (_) {
      _error = 'Unable to load the current portal setup.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.save(
        type: widget.connectionType,
        providerName: _providerController.text,
        baseUrl: _baseUrlController.text,
        authType: _authType,
        credential: _credentialController.text,
        enabled: _enabled,
        applicabilityThreshold: double.tryParse(_thresholdController.text.trim()),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Portal setup could not be saved. Check the details and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: _loading
            ? const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _providerController,
                        decoration: const InputDecoration(
                          labelText: 'Portal provider',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter the portal provider.'
                            : null,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          widget.connectionType == ClientGstPortalConnectionType.einvoicing
                              ? 'Enable e-Invoicing for this client'
                              : 'Enable E-Way Bill for this client',
                        ),
                        subtitle: const Text(
                          'Keep disabled until this client needs the facility.',
                        ),
                        value: _enabled,
                        onChanged: (value) => setState(() => _enabled = value),
                      ),
                      TextFormField(
                        controller: _thresholdController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: widget.connectionType ==
                                  ClientGstPortalConnectionType.einvoicing
                              ? 'Annual turnover applicability threshold'
                              : 'E-Way Bill value threshold',
                          prefixText: 'Rs ',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return null;
                          return double.tryParse(text) == null ||
                                  double.parse(text) < 0
                              ? 'Enter a valid amount.'
                              : null;
                        },
                      ),
                      TextFormField(
                        controller: _baseUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: 'API base URL'),
                        validator: (value) => Uri.tryParse(value?.trim() ?? '')
                                    ?.hasAbsolutePath ==
                                true
                            ? null
                            : 'Enter a valid API URL.',
                      ),
                      DropdownButtonFormField<String>(
                        value: _authType,
                        decoration: const InputDecoration(
                          labelText: 'Authentication type',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'token', child: Text('Token')),
                          DropdownMenuItem(value: 'api_key', child: Text('API key')),
                          DropdownMenuItem(
                            value: 'bearer',
                            child: Text('Bearer token'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _authType = value ?? 'token');
                        },
                      ),
                      TextFormField(
                        controller: _credentialController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Portal credential',
                        ),
                        validator: (value) => value == null || value.trim().isEmpty
                            ? 'Enter the portal credential.'
                            : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: const TextStyle(color: Color(0xFFB42318)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving...' : 'Save setup'),
        ),
      ],
    );
  }
}