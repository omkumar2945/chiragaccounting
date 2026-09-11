import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/marketing/services/download_center_service.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';

class DownloadCenterSettingsScreen extends StatefulWidget {
  const DownloadCenterSettingsScreen({super.key});

  @override
  State<DownloadCenterSettingsScreen> createState() =>
      _DownloadCenterSettingsScreenState();
}

class _DownloadCenterSettingsScreenState
    extends State<DownloadCenterSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _androidUrl = TextEditingController();
  final _iosUrl = TextEditingController();
  final _webUrl = TextEditingController();
  final _androidVersion = TextEditingController();
  final _iosVersion = TextEditingController();
  final _releaseNotes = TextEditingController();

  MobileAppAvailability _androidStatus = MobileAppAvailability.comingSoon;
  MobileAppAvailability _iosStatus = MobileAppAvailability.comingSoon;
  bool _saving = false;
  bool _initialized = false;

  bool get _authorized {
    final role = context.read<AuthController>().currentUser?.role;
    return role == UserRole.admin ||
        role == UserRole.superAdmin ||
        role == UserRole.firmAdmin;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final settings = context.read<DownloadCenterService>().settings;
    _androidUrl.text = settings.androidUrl;
    _iosUrl.text = settings.iosUrl;
    _webUrl.text = settings.webAppUrl;
    _androidVersion.text = settings.androidVersion;
    _iosVersion.text = settings.iosVersion;
    _releaseNotes.text = settings.releaseNotes;
    _androidStatus = settings.androidStatus;
    _iosStatus = settings.iosStatus;
  }

  @override
  void dispose() {
    _androidUrl.dispose();
    _iosUrl.dispose();
    _webUrl.dispose();
    _androidVersion.dispose();
    _iosVersion.dispose();
    _releaseNotes.dispose();
    super.dispose();
  }

  String? _optionalUrlValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty || DownloadCenterSettings.isValidExternalUrl(text)) {
      return null;
    }
    return 'Enter a valid http or https URL';
  }

  Future<void> _save() async {
    if (!_authorized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin authorization is required.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await context.read<DownloadCenterService>().save(
        DownloadCenterSettings(
          androidUrl: _androidUrl.text.trim(),
          iosUrl: _iosUrl.text.trim(),
          webAppUrl: _webUrl.text.trim(),
          androidStatus: _androidStatus,
          iosStatus: _iosStatus,
          androidVersion: _androidVersion.text.trim(),
          iosVersion: _iosVersion.text.trim(),
          releaseNotes: _releaseNotes.text.trim(),
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download Center settings saved.')),
      );
    } on FormatException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(
        body: Center(
          child: Text('You are not authorized to manage Download Center.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text('Download Center Settings'),
        backgroundColor: const Color(0xFF0A3A86),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Public App Links',
                    style: TextStyle(
                      color: Color(0xFF12213A),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Public download buttons and QR codes update automatically from these settings.',
                    style: TextStyle(color: Color(0xFF667085)),
                  ),
                  const SizedBox(height: 18),
                  _settingsCard(
                    title: 'Web App',
                    icon: Icons.language_outlined,
                    color: const Color(0xFF2563EB),
                    children: [
                      TextFormField(
                        controller: _webUrl,
                        validator: _optionalUrlValidator,
                        decoration: const InputDecoration(
                          labelText: 'Web App URL',
                          hintText: 'https://app.example.com',
                          prefixIcon: Icon(Icons.link),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final android = _platformFields(
                        title: 'Android',
                        icon: Icons.android,
                        color: const Color(0xFF0F9F75),
                        urlController: _androidUrl,
                        versionController: _androidVersion,
                        status: _androidStatus,
                        onStatusChanged: (value) {
                          setState(() => _androidStatus = value);
                        },
                      );
                      final ios = _platformFields(
                        title: 'iOS',
                        icon: Icons.apple,
                        color: const Color(0xFF4F46E5),
                        urlController: _iosUrl,
                        versionController: _iosVersion,
                        status: _iosStatus,
                        onStatusChanged: (value) {
                          setState(() => _iosStatus = value);
                        },
                      );
                      if (constraints.maxWidth < 720) {
                        return Column(
                          children: [android, const SizedBox(height: 14), ios],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: android),
                          const SizedBox(width: 14),
                          Expanded(child: ios),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  _settingsCard(
                    title: 'Release Information',
                    icon: Icons.new_releases_outlined,
                    color: const Color(0xFF7C3AED),
                    children: [
                      TextFormField(
                        controller: _releaseNotes,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Release Notes (optional)',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _platformFields({
    required String title,
    required IconData icon,
    required Color color,
    required TextEditingController urlController,
    required TextEditingController versionController,
    required MobileAppAvailability status,
    required ValueChanged<MobileAppAvailability> onStatusChanged,
  }) {
    return _settingsCard(
      title: title,
      icon: icon,
      color: color,
      children: [
        DropdownButtonFormField<MobileAppAvailability>(
          initialValue: status,
          decoration: InputDecoration(labelText: '$title Status'),
          items: const [
            DropdownMenuItem(
              value: MobileAppAvailability.comingSoon,
              child: Text('Coming Soon'),
            ),
            DropdownMenuItem(
              value: MobileAppAvailability.available,
              child: Text('Available'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onStatusChanged(value);
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: urlController,
          validator: (value) {
            final baseError = _optionalUrlValidator(value);
            if (baseError != null) return baseError;
            if (status == MobileAppAvailability.available &&
                (value?.trim().isEmpty ?? true)) {
              return '$title URL is required when available';
            }
            return null;
          },
          decoration: InputDecoration(
            labelText: '$title App URL',
            hintText: 'https://...',
            prefixIcon: const Icon(Icons.link),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: versionController,
          decoration: InputDecoration(
            labelText: '$title Version (optional)',
            prefixIcon: const Icon(Icons.tag),
          ),
        ),
      ],
    );
  }

  Widget _settingsCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E8F2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F2A44),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF12213A),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
