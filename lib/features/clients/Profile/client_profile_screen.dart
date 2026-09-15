import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:chirag_accounting/core/location/standard_address.dart';
import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:chirag_accounting/core/utils/file_picker_utils.dart';
import 'package:chirag_accounting/core/utils/mobile_number_utils.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/services/client_profile_service.dart';
import 'package:chirag_accounting/shared/widgets/address_location_form.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  static const int _logoTargetMinBytes = 200 * 1024;
  static const int _logoTargetMaxBytes = 300 * 1024;
  static const int _logoTargetBytes = 250 * 1024;
  static const int _logoMaxDimension = 1600;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _firmCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _registeredAddress = AddressFormController();

  final ClientProfileService _profileService = ClientProfileService();
  static const List<String> _invoiceFormats = [
    'Classic',
    'Modern',
    'Minimal',
    'Premium',
  ];

  bool _isLoading = true;
  bool _isSaving = false;

  String _logoPath = '';
  String _logoDataBase64 = '';
  String _logoFileName = '';
  String _invoiceFormat = 'Classic';
  String _gstCertificatePath = '';
  String _panCardPath = '';
  String _aadhaarCardPath = '';
  String _caMembershipCertificatePath = '';
  String _copCertificatePath = '';
  String _firmRegistrationCertificatePath = '';
  String _authorityLetterPath = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _firmCtrl.dispose();
    _gstinCtrl.dispose();
    _panCtrl.dispose();
    _aadhaarCtrl.dispose();
    _registeredAddress.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = context.read<AuthController>().currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    final stored = await _profileService.load(
      user.id,
      useAuthoritativeClientApi: user.role.isClient,
    );
    if (!mounted) return;

    _nameCtrl.text = stored?.name.isNotEmpty == true ? stored!.name : user.name;
    _emailCtrl.text = stored?.email.isNotEmpty == true
        ? stored!.email
        : user.email;
    _mobileCtrl.text = stored?.mobile.isNotEmpty == true
        ? stored!.mobile
        : user.mobile;
    _firmCtrl.text = stored?.firmName.isNotEmpty == true
        ? stored!.firmName
        : user.firmName;
    _gstinCtrl.text = stored?.gstin ?? '';
    _panCtrl.text = stored?.pan ?? '';
    _aadhaarCtrl.text = stored?.aadhaar ?? '';
    _registeredAddress.setValue(
      stored?.registeredLocation ??
          StandardAddress.fromLegacy(
            address: stored?.address ?? '',
            city: stored?.city ?? '',
            state: stored?.state ?? '',
            pincode: stored?.pincode ?? '',
            country: stored?.country ?? 'India',
          ),
    );
    _logoPath = stored?.logoPath ?? '';
    _logoDataBase64 = stored?.logoDataBase64 ?? '';
    _logoFileName = stored?.logoFileName ?? '';
    _invoiceFormat = stored?.invoiceFormat ?? 'Classic';
    _gstCertificatePath = stored?.gstCertificatePath ?? '';
    _panCardPath = stored?.panCardPath ?? '';
    _aadhaarCardPath = stored?.aadhaarCardPath ?? '';
    _caMembershipCertificatePath = stored?.caMembershipCertificatePath ?? '';
    _copCertificatePath = stored?.copCertificatePath ?? '';
    _firmRegistrationCertificatePath =
        stored?.firmRegistrationCertificatePath ?? '';
    _authorityLetterPath = stored?.authorityLetterPath ?? '';

    setState(() => _isLoading = false);
  }

  Future<void> _pickDoc(String type) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );

    if (!mounted || result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (!isUsableLocalFilePath(path)) return;

    setState(() {
      if (type == 'gst') _gstCertificatePath = path ?? '';
      if (type == 'pan') _panCardPath = path ?? '';
      if (type == 'aadhaar') _aadhaarCardPath = path ?? '';
      if (type == 'ca_membership') _caMembershipCertificatePath = path ?? '';
      if (type == 'cop') _copCertificatePath = path ?? '';
      if (type == 'firm_registration') {
        _firmRegistrationCertificatePath = path ?? '';
      }
      if (type == 'authority_letter') _authorityLetterPath = path ?? '';
    });
  }

  Future<void> _pickLogo() async {
    final isPracticeProfile =
        !(context.read<AuthController>().currentUser?.role.isClient ?? true);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: isPracticeProfile
          ? const ['png', 'jpg', 'jpeg', 'webp']
          : const ['png', 'jpg', 'jpeg', 'webp', 'pdf'],
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final fileName = file.name.toLowerCase();
    if (fileName.endsWith('.pdf')) {
      setState(() {
        _logoPath = path ?? '';
        _logoFileName = file.name;
        _logoDataBase64 = base64Encode(bytes);
      });
      return;
    }

    final cropped = await _cropProfileImage(bytes);
    if (!mounted || cropped == null) return;

    final processed = _processLogoImage(cropped, sourceName: file.name);
    if (processed == null) return;

    setState(() {
      _logoPath = path ?? '';
      _logoFileName = processed.fileName;
      _logoDataBase64 = base64Encode(processed.bytes);
    });
  }

  _ProcessedLogoImage? _processLogoImage(
    Uint8List bytes, {
    required String sourceName,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final oriented = img.bakeOrientation(decoded);
    final resized = _resizeForCompression(oriented);
    final encoded = _encodeLogo(resized);

    return _ProcessedLogoImage(
      bytes: encoded,
      fileName: _processedLogoFileName(sourceName),
    );
  }

  Future<Uint8List?> _cropProfileImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    final source = img.bakeOrientation(decoded);
    double left = 0;
    double top = 0;
    double width = 1;
    double height = 1;

    final crop = await showDialog<_CropSelection>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          void updateWidth(double value) {
            setDialog(() {
              width = value;
              left = math.min(left, 1 - width);
            });
          }

          void updateHeight(double value) {
            setDialog(() {
              height = value;
              top = math.min(top, 1 - height);
            });
          }

          return AlertDialog(
            title: const Text('Crop profile photo'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 330),
                      child: AspectRatio(
                        aspectRatio: source.width / source.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.memory(bytes, fit: BoxFit.fill),
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _CropOverlayPainter(
                                  left: left,
                                  top: top,
                                  width: width,
                                  height: height,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _cropSlider('Crop width', width, updateWidth),
                    _cropSlider('Crop height', height, updateHeight),
                    _cropSlider(
                      'Horizontal position',
                      left,
                      (value) =>
                          setDialog(() => left = value.clamp(0, 1 - width)),
                      max: 1 - width,
                    ),
                    _cropSlider(
                      'Vertical position',
                      top,
                      (value) =>
                          setDialog(() => top = value.clamp(0, 1 - height)),
                      max: 1 - height,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _CropSelection(
                    left: left,
                    top: top,
                    width: width,
                    height: height,
                  ),
                ),
                icon: const Icon(Icons.crop_rounded),
                label: const Text('Apply crop'),
              ),
            ],
          );
        },
      ),
    );
    if (crop == null) return null;

    final cropWidth = math.max(1, (source.width * crop.width).round());
    final cropHeight = math.max(1, (source.height * crop.height).round());
    final cropLeft = math.min(
      source.width - cropWidth,
      (source.width * crop.left).round(),
    );
    final cropTop = math.min(
      source.height - cropHeight,
      (source.height * crop.top).round(),
    );
    final cropped = img.copyCrop(
      source,
      x: cropLeft,
      y: cropTop,
      width: cropWidth,
      height: cropHeight,
    );
    return Uint8List.fromList(img.encodePng(cropped));
  }

  Widget _cropSlider(
    String label,
    double value,
    ValueChanged<double> onChanged, {
    double max = 1,
  }) {
    final effectiveMax = math.max(0.01, max);
    return Row(
      children: [
        SizedBox(width: 130, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(0, effectiveMax),
            min: 0,
            max: effectiveMax,
            onChanged: max <= 0 ? null : onChanged,
          ),
        ),
      ],
    );
  }

  img.Image _resizeForCompression(img.Image image) {
    if (image.width <= _logoMaxDimension && image.height <= _logoMaxDimension) {
      return image;
    }

    if (image.width >= image.height) {
      return img.copyResize(image, width: _logoMaxDimension);
    }

    return img.copyResize(image, height: _logoMaxDimension);
  }

  Uint8List _encodeLogo(img.Image image) {
    final candidates = <Uint8List>[];
    for (final dimension in <int>[
      _logoMaxDimension,
      1400,
      1200,
      1000,
      900,
      800,
    ]) {
      final resized = _fitToMaxDimension(image, dimension);
      for (final quality in <int>[92, 88, 84, 80, 76, 72, 68, 64]) {
        final encoded = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
        candidates.add(encoded);
        if (encoded.lengthInBytes >= _logoTargetMinBytes &&
            encoded.lengthInBytes <= _logoTargetMaxBytes) {
          return encoded;
        }
      }
    }

    candidates.sort(
      (a, b) => (a.lengthInBytes - _logoTargetBytes).abs().compareTo(
        (b.lengthInBytes - _logoTargetBytes).abs(),
      ),
    );
    return candidates.isNotEmpty
        ? candidates.first
        : Uint8List.fromList(img.encodeJpg(image, quality: 80));
  }

  img.Image _fitToMaxDimension(img.Image image, int maxDimension) {
    if (image.width <= maxDimension && image.height <= maxDimension) {
      return image;
    }

    if (image.width >= image.height) {
      return img.copyResize(image, width: maxDimension);
    }

    return img.copyResize(image, height: maxDimension);
  }

  String _processedLogoFileName(String sourceName) {
    final fileName = sourceName.trim().isEmpty
        ? 'client_logo'
        : sourceName.trim();
    final lastDot = fileName.lastIndexOf('.');
    final baseName = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
    return '$baseName.jpg';
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final addressValidation = validateAddressTaxIdentity(
      address: _registeredAddress.value,
      gstin: _gstinCtrl.text,
      pan: _panCtrl.text,
    );
    if (!addressValidation.isValid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(addressValidation.message)));
      return;
    }

    final user = context.read<AuthController>().currentUser;
    if (user == null) return;

    final requiresPracticeDocs = !user.role.isClient;
    if (requiresPracticeDocs) {
      final missingDocs = <String>[];
      if (_caMembershipCertificatePath.trim().isEmpty) {
        missingDocs.add('ICAI Membership Certificate');
      }
      if (_copCertificatePath.trim().isEmpty) {
        missingDocs.add('Certificate of Practice (COP)');
      }
      if (_firmRegistrationCertificatePath.trim().isEmpty) {
        missingDocs.add('CA Firm Registration Certificate');
      }
      if (_authorityLetterPath.trim().isEmpty) {
        missingDocs.add('Authorization / Engagement Letter');
      }

      if (missingDocs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please upload required CA/Auditor documents: ${missingDocs.join(', ')}',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final payload = ClientProfileData(
        clientId: user.id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        mobile: normalizeIndianMobile(_mobileCtrl.text),
        firmName: _firmCtrl.text.trim(),
        gstin: _gstinCtrl.text.trim().toUpperCase(),
        pan: _panCtrl.text.trim().toUpperCase(),
        aadhaar: _aadhaarCtrl.text.trim(),
        address: _registeredAddress.value.enteredAddress,
        city: _registeredAddress.value.cityName,
        state: _registeredAddress.value.stateName,
        pincode: _registeredAddress.value.pincode,
        country: _registeredAddress.value.countryName,
        registeredLocation: _registeredAddress.value,
        logoPath: _logoPath,
        logoDataBase64: _logoDataBase64,
        logoFileName: _logoFileName,
        invoiceFormat: _invoiceFormat,
        gstCertificatePath: _gstCertificatePath,
        panCardPath: _panCardPath,
        aadhaarCardPath: _aadhaarCardPath,
        caMembershipCertificatePath: _caMembershipCertificatePath,
        copCertificatePath: _copCertificatePath,
        firmRegistrationCertificatePath: _firmRegistrationCertificatePath,
        authorityLetterPath: _authorityLetterPath,
      );
      await _profileService.save(
        payload,
        useAuthoritativeClientApi: user.role.isClient,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully. Accountant update option can be enabled later.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Required field';
    return null;
  }

  String? _validateMobile(String? value) {
    return validateIndianMobile(value, required: true);
  }

  String? _validatePan(String? value) {
    final pan = (value ?? '').trim().toUpperCase();
    if (pan.isEmpty) return null;

    final panPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
    if (!panPattern.hasMatch(pan)) {
      return 'Enter a valid PAN (ABCDE1234F)';
    }

    final gstin = _gstinCtrl.text.trim().toUpperCase();
    if (gstin.isNotEmpty && gstin.length == 15) {
      final gstPan = gstin.substring(2, 12);
      if (gstPan != pan) {
        return 'PAN must match the PAN part of GSTIN';
      }
    }

    return null;
  }

  String? _validateGstin(String? value) {
    final gstin = (value ?? '').trim().toUpperCase();
    if (gstin.isEmpty) return null;

    final gstinPattern = RegExp(
      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$',
    );
    if (!gstinPattern.hasMatch(gstin)) {
      return 'Enter a valid GSTIN (15 characters)';
    }

    final pan = _panCtrl.text.trim().toUpperCase();
    if (pan.isNotEmpty && pan.length == 10) {
      final gstPan = gstin.substring(2, 12);
      if (gstPan != pan) {
        return 'GSTIN PAN part must match PAN';
      }
    }

    return null;
  }

  String _docName(String path) {
    if (path.trim().isEmpty) return 'Not uploaded';
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty);
    return segments.isNotEmpty ? segments.last : path;
  }

  Widget _buildLogoPreview() {
    if (_logoDataBase64.trim().isEmpty) {
      return const Icon(Icons.image_outlined, color: Color(0xFF1565C0));
    }

    final bytes = base64Decode(_logoDataBase64);
    final fileName = _logoFileName.toLowerCase();
    if (fileName.endsWith('.pdf')) {
      return const Icon(
        Icons.picture_as_pdf_outlined,
        color: Color(0xFF1565C0),
      );
    }

    return ClipOval(
      child: Image.memory(
        bytes,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.broken_image_outlined, color: Color(0xFF1565C0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    final showPracticeDocs = user != null && !user.role.isClient;
    final isPracticeUser = showPracticeDocs;
    final isAuthoritativeClient =
        user?.role.isClient == true && !ApiConstants.useMockApi;
    final profileTitle = isPracticeUser
        ? 'ICAI CA / Auditor Profile'
        : 'Client Profile Update';
    final logoTitle = isPracticeUser ? 'Profile Photo' : 'Client Logo';
    final identityTitle = isPracticeUser
        ? 'ICAI Professional Identity'
        : 'Brand Identity';

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(profileTitle),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Profile details can be updated by client now. Later we can enable accountant-assisted update flow.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              Text(
                identityTitle,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(
                      0xFF1565C0,
                    ).withValues(alpha: 0.1),
                    child: _buildLogoPreview(),
                  ),
                  title: Text(logoTitle),
                  subtitle: Text(
                    _docName(
                      _logoFileName.isNotEmpty ? _logoFileName : _logoPath,
                    ),
                  ),
                  trailing: OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Upload'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Invoice Format',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _invoiceFormats
                    .map(
                      (format) => ChoiceChip(
                        label: Text(format),
                        selected: _invoiceFormat == format,
                        onSelected: (_) {
                          setState(() => _invoiceFormat = format);
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 12),
              Text(
                'Selected format: $_invoiceFormat',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Client Name'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                readOnly: isAuthoritativeClient,
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _mobileCtrl,
                decoration: const InputDecoration(labelText: 'Mobile'),
                keyboardType: TextInputType.phone,
                inputFormatters: indianMobileInputFormatters(),
                readOnly: isAuthoritativeClient,
                validator: _validateMobile,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _firmCtrl,
                decoration: const InputDecoration(labelText: 'Firm Name'),
                validator: _required,
              ),
              const SizedBox(height: 10),
              AddressLocationForm(
                controller: _registeredAddress,
                title: 'Registered Office Address',
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _gstinCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'GSTIN'),
                validator: _validateGstin,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _panCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'PAN'),
                validator: _validatePan,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _aadhaarCtrl,
                decoration: const InputDecoration(labelText: 'Aadhaar Number'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 18),
              const Text(
                'Document Scan Upload',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _docTile(
                title: 'GST Certificate',
                subtitle: _docName(_gstCertificatePath),
                onPick: () => _pickDoc('gst'),
              ),
              _docTile(
                title: 'PAN Card',
                subtitle: _docName(_panCardPath),
                onPick: () => _pickDoc('pan'),
              ),
              _docTile(
                title: 'Aadhaar Card',
                subtitle: _docName(_aadhaarCardPath),
                onPick: () => _pickDoc('aadhaar'),
              ),
              if (showPracticeDocs) ...[
                const SizedBox(height: 8),
                const Text(
                  'Practicing CA / Auditor Documents',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _docTile(
                  title: 'ICAI Membership Certificate',
                  subtitle: _docName(_caMembershipCertificatePath),
                  onPick: () => _pickDoc('ca_membership'),
                ),
                _docTile(
                  title: 'Certificate of Practice (COP)',
                  subtitle: _docName(_copCertificatePath),
                  onPick: () => _pickDoc('cop'),
                ),
                _docTile(
                  title: 'CA Firm Registration Certificate',
                  subtitle: _docName(_firmRegistrationCertificatePath),
                  onPick: () => _pickDoc('firm_registration'),
                ),
                _docTile(
                  title: 'Authorization / Engagement Letter',
                  subtitle: _docName(_authorityLetterPath),
                  onPick: () => _pickDoc('authority_letter'),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveProfile,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_isSaving ? 'Saving...' : 'Save Profile Update'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _docTile({
    required String title,
    required String subtitle,
    required VoidCallback onPick,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.document_scanner_outlined),
          label: const Text('Scan/Upload'),
        ),
      ),
    );
  }
}

class _ProcessedLogoImage {
  final Uint8List bytes;
  final String fileName;

  const _ProcessedLogoImage({required this.bytes, required this.fileName});
}

class _CropSelection {
  const _CropSelection({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;
}

class _CropOverlayPainter extends CustomPainter {
  const _CropOverlayPainter({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  final double left;
  final double top;
  final double width;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final cropRect = Rect.fromLTWH(
      size.width * left,
      size.height * top,
      size.width * width,
      size.height * height,
    );
    final shade = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, shade);
    canvas.drawRect(
      cropRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) =>
      oldDelegate.left != left ||
      oldDelegate.top != top ||
      oldDelegate.width != width ||
      oldDelegate.height != height;
}
