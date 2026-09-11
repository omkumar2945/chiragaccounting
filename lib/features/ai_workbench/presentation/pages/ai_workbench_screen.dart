// AI Workbench – Main Screen
//
// Central workspace for every document entering the system.
// No separate OCR/Upload page. Everything enters here.
//
// Layout:
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │  AppBar: "AI Workbench"  [search]  [stats badge]                    │
//   ├──────────────────────────────────────────────────────────────────────┤
//   │  DROP ZONE (top)                                                     │
//   │  [Camera] [PDF] [Images] [Browse/Drop] [Email] [WhatsApp]           │
//   ├──────────────────────────────────────────────────────────────────────┤
//   │  AI Stats bar: Processed | OCR Success | Duplicates | Masters | etc │
//   ├─────────────────┬────────────────────────────────────────────────────┤
//   │  Tabs sidebar   │  Job list for selected tab                        │
//   │  Inbox          │  Each job card shows:                             │
//   │  Processing     │    • File name + type badge                       │
//   │  Verification   │    • AI Thinking progress (if processing)         │
//   │  Approvals      │    • AI Decision (if done)                        │
//   │  Completed      │    • Action buttons                               │
//   │  Errors         │                                                   │
//   │  Archive        │                                                   │
//   └─────────────────┴────────────────────────────────────────────────────┘

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/admin/services/admin_user_service.dart';
import 'package:chirag_accounting/features/ai_workbench/models/workbench_job.dart';
import 'package:chirag_accounting/features/ai_workbench/services/workbench_queue_service.dart';
import 'package:chirag_accounting/features/ai_workbench/services/ocr_module_api_service.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_workspace_screen.dart';
import 'package:chirag_accounting/features/ai_workbench/presentation/pages/ai_batch_processing_screen.dart';
import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/services/customer_service.dart';
import 'package:chirag_accounting/features/services/vendor_service.dart';
import 'package:chirag_accounting/features/products/product_service.dart';
import 'package:chirag_accounting/features/services/smart_invoice_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────

enum _WbTab {
  inbox,
  processing,
  verification,
  approvals,
  completed,
  errors,
  archive,
}

extension _WbTabLabel on _WbTab {
  String get label {
    switch (this) {
      case _WbTab.inbox:
        return 'Inbox';
      case _WbTab.processing:
        return 'Processing';
      case _WbTab.verification:
        return 'Verification';
      case _WbTab.approvals:
        return 'Approvals';
      case _WbTab.completed:
        return 'Completed';
      case _WbTab.errors:
        return 'Errors';
      case _WbTab.archive:
        return 'Archive';
    }
  }

  IconData get icon {
    switch (this) {
      case _WbTab.inbox:
        return Icons.inbox_outlined;
      case _WbTab.processing:
        return Icons.sync_outlined;
      case _WbTab.verification:
        return Icons.rate_review_outlined;
      case _WbTab.approvals:
        return Icons.check_circle_outline;
      case _WbTab.completed:
        return Icons.done_all_outlined;
      case _WbTab.errors:
        return Icons.error_outline;
      case _WbTab.archive:
        return Icons.archive_outlined;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class AiWorkbenchScreen extends StatefulWidget {
  const AiWorkbenchScreen({super.key, this.title = 'AI Workbench'});

  final String title;

  @override
  State<AiWorkbenchScreen> createState() => _AiWorkbenchScreenState();
}

class _AiWorkbenchScreenState extends State<AiWorkbenchScreen>
    with SingleTickerProviderStateMixin {
  _WbTab _selectedTab = _WbTab.inbox;
  bool _dropZoneExpanded = true;
  String _searchQuery = '';
  bool _remoteSyncing = false;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncRemoteQueue());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Sync master lists into the queue service ─────────────────────────────

  void _syncMasters(WorkbenchQueueService svc) {
    try {
      final cs = context.read<CustomerService>();
      final vs = context.read<VendorService>();
      final ps = context.read<ProductService>();
      svc.customerNames = cs.customers.map((c) => c.customerName).toList();
      svc.customerGstins = cs.customers
          .map((c) => c.gstNumber)
          .where((g) => g.isNotEmpty)
          .toList();
      svc.vendorNames = vs.vendors.map((v) => v.vendorName).toList();
      svc.vendorGstins = vs.vendors
          .map((v) => v.gstNumber)
          .where((g) => g.isNotEmpty)
          .toList();
      svc.productMasterNames = ps.products.map((p) => p.productName).toList();
    } catch (_) {}
  }

  Future<void> _syncRemoteQueue() async {
    final api = OcrModuleApiService();
    if (!api.isConfigured || _remoteSyncing) return;
    final user = context.read<AuthController?>()?.currentUser;
    if (user == null) return;

    setState(() => _remoteSyncing = true);
    try {
      final directory = context.read<AdminUserService>();
      final requests = <Future<List<RemoteOcrDocument>>>[];
      if (user.role.isClient) {
        final access = directory.accountingAccessFor(user.id);
        final accountantId = access.assignedAccountantId.trim().isNotEmpty
            ? access.assignedAccountantId.trim()
            : access.assignedCaId.trim();
        if (accountantId.isNotEmpty) {
          requests.add(
            api.documents(
              clientId: user.id,
              assignedAccountantId: accountantId,
              clientRole: true,
            ),
          );
        }
      } else {
        for (final client in directory.users.where(
          (candidate) => candidate.role.isClient,
        )) {
          final access = directory.accountingAccessFor(client.id);
          if (access.assignedAccountantId == user.id ||
              access.assignedCaId == user.id) {
            requests.add(
              api.documents(
                clientId: client.id,
                assignedAccountantId: user.id,
                clientRole: false,
              ),
            );
          }
        }
      }
      final batches = await Future.wait(requests);
      if (!mounted) return;
      context.read<WorkbenchQueueService>().synchronizeRemoteDocuments(
        batches.expand((batch) => batch).toList(growable: false),
      );
    } catch (error) {
      _snack('OCR queue sync failed: $error');
    } finally {
      if (mounted) setState(() => _remoteSyncing = false);
    }
  }

  // ── File pickers ─────────────────────────────────────────────────────────

  Future<void> _pickCamera() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.camera);
      if (picked == null || !mounted) return;
      final bytes = await picked.readAsBytes();
      _routeFiles([
        BatchUploadFile(
          fileName: picked.name,
          filePath: kIsWeb ? null : picked.path,
          fileBytes: bytes,
        ),
      ]);
    } catch (e) {
      _snack('Camera error: $e');
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      _routeFiles(
        result.files
            .map(
              (f) => BatchUploadFile(
                fileName: f.name,
                filePath: f.path,
                fileBytes: f.bytes,
              ),
            )
            .toList(),
      );
    } catch (e) {
      _snack('PDF pick error: $e');
    }
  }

  Future<void> _pickImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      _routeFiles(
        result.files
            .map(
              (f) => BatchUploadFile(
                fileName: f.name,
                filePath: f.path,
                fileBytes: f.bytes,
              ),
            )
            .toList(),
      );
    } catch (e) {
      _snack('Image pick error: $e');
    }
  }

  Future<void> _pickAny() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      _routeFiles(
        result.files
            .map(
              (f) => BatchUploadFile(
                fileName: f.name,
                filePath: f.path,
                fileBytes: f.bytes,
              ),
            )
            .toList(),
      );
    } catch (e) {
      _snack('File pick error: $e');
    }
  }

  // ── Smart routing: 1 file → workspace, multiple → batch processing ───────

  Future<void> _routeFiles(List<BatchUploadFile> files) async {
    if (files.isEmpty) return;
    final svc = context.read<WorkbenchQueueService>();
    _syncMasters(svc);

    if (files.length == 1) {
      // Single file → immediately open AI Verification Workspace
      final f = files.first;
      final job = await svc.addJob(
        fileName: f.fileName,
        filePath: f.filePath,
        fileBytes: f.fileBytes,
        autoProcess: true,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AiWorkspaceScreen(jobId: job.id)),
      );
    } else {
      // Multiple files → AI Processing Center (batch mode)
      final batchId = await svc.addBatchJobs(files, autoProcess: true);
      if (!mounted) return;
      setState(() {
        _selectedTab = _WbTab.processing;
        _dropZoneExpanded = false;
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiBatchProcessingScreen(batchId: batchId),
        ),
      );
    }
    _snack(
      '${files.length} document${files.length == 1 ? '' : 's'} sent to AI',
    );
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Job list for selected tab ─────────────────────────────────────────────

  List<WorkbenchJob> _jobsForTab(WorkbenchQueueService svc) {
    List<WorkbenchJob> jobs;
    switch (_selectedTab) {
      case _WbTab.inbox:
        jobs = svc.inboxJobs;
        break;
      case _WbTab.processing:
        jobs = svc.processingJobs;
        break;
      case _WbTab.verification:
        jobs = svc.verificationJobs;
        break;
      case _WbTab.approvals:
        jobs = svc.approvedJobs;
        break;
      case _WbTab.completed:
        jobs = svc.completedJobs;
        break;
      case _WbTab.errors:
        jobs = svc.failedJobs;
        break;
      case _WbTab.archive:
        jobs = svc.archiveJobs;
        break;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      jobs = jobs.where((j) => j.fileName.toLowerCase().contains(q)).toList();
    }
    final user = context.read<AuthController?>()?.currentUser;
    if (user == null) return jobs;
    if (user.role.isClient) {
      jobs = jobs.where((job) => job.clientId == user.id).toList();
    } else if (user.role == UserRole.accountant) {
      jobs = jobs
          .where(
            (job) =>
                job.assignedAccountantId == user.id || job.clientId == null,
          )
          .toList();
    }
    return jobs;
  }

  int _countForTab(_WbTab tab, WorkbenchQueueService svc) {
    switch (tab) {
      case _WbTab.inbox:
        return svc.inboxJobs.length;
      case _WbTab.processing:
        return svc.processingJobs.length;
      case _WbTab.verification:
        return svc.verificationJobs.length;
      case _WbTab.approvals:
        return svc.approvedJobs.length;
      case _WbTab.completed:
        return svc.completedJobs.length;
      case _WbTab.errors:
        return svc.failedJobs.length;
      case _WbTab.archive:
        return svc.archiveJobs.length;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<WorkbenchQueueService>();
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: _buildAppBar(svc),
      body: Column(
        children: [
          // Drop zone
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _dropZoneExpanded
                ? _buildDropZone()
                : _buildDropZoneCollapsed(),
          ),
          // AI Stats bar
          _buildStatsBar(svc),
          // Main area
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTabSidebar(svc),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildJobList(svc)),
                    ],
                  )
                : Column(
                    children: [
                      _buildTabScrollRow(svc),
                      Expanded(child: _buildJobList(svc)),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        onPressed: () => setState(() => _dropZoneExpanded = !_dropZoneExpanded),
        icon: Icon(
          _dropZoneExpanded
              ? Icons.keyboard_arrow_up
              : Icons.add_circle_outline,
        ),
        label: Text(_dropZoneExpanded ? 'Collapse' : 'Upload Document'),
      ),
    );
  }

  AppBar _buildAppBar(WorkbenchQueueService svc) {
    return AppBar(
      backgroundColor: const Color(0xFF1A237E),
      foregroundColor: Colors.white,
      title: Text(
        widget.title,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
      ),
      actions: [
        if (svc.pendingCount > 0)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Badge(
              label: Text('${svc.pendingCount}'),
              child: const Icon(Icons.hourglass_empty_outlined),
            ),
          ),
        IconButton(
          icon: _remoteSyncing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.sync),
          tooltip: 'Sync OCR queue',
          onPressed: _remoteSyncing ? null : _syncRemoteQueue,
        ),
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Search Workbench'),
                content: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Search by file name...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                  onSubmitted: (_) => Navigator.pop(ctx),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _searchQuery = '');
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Search'),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Drop Zone ─────────────────────────────────────────────────────────────

  Widget _buildDropZone() {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxDropZoneHeight = (screenHeight * 0.30).clamp(170.0, 280.0);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxDropZoneHeight),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Drop anything here',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _dropBtn(
                    icon: Icons.camera_alt_outlined,
                    label: 'Camera',
                    color: const Color(0xFF1A237E),
                    onTap: _pickCamera,
                  ),
                  _dropBtn(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'PDF',
                    color: const Color(0xFFB71C1C),
                    onTap: _pickPdf,
                  ),
                  _dropBtn(
                    icon: Icons.image_outlined,
                    label: 'Images',
                    color: const Color(0xFF0D47A1),
                    onTap: _pickImages,
                  ),
                  _dropBtn(
                    icon: Icons.upload_file_outlined,
                    label: 'Browse / Drop',
                    color: const Color(0xFF1B5E20),
                    onTap: _pickAny,
                  ),
                  _dropBtn(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    color: Colors.blueGrey,
                    onTap: () => _snack('Email import coming soon'),
                  ),
                  _dropBtn(
                    icon: Icons.chat_outlined,
                    label: 'WhatsApp',
                    color: const Color(0xFF2E7D32),
                    onTap: () => _snack('WhatsApp import coming soon'),
                  ),
                  _dropBtn(
                    icon: Icons.cloud_outlined,
                    label: 'Google Drive',
                    color: Colors.orange.shade700,
                    onTap: () => _snack('Google Drive import coming soon'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropZoneCollapsed() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.upload_file_outlined,
            color: Color(0xFF1A237E),
            size: 18,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'AI Workbench - Drop or upload any document',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _dropZoneExpanded = true),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  Widget _dropBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Bar ─────────────────────────────────────────────────────────────

  Widget _buildStatsBar(WorkbenchQueueService svc) {
    return Container(
      color: const Color(0xFFF8F9FF),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _statChip('Processed', '${svc.totalProcessed}', Colors.indigo),
            const SizedBox(width: 12),
            _statChip(
              'Duplicates\nPrevented',
              '${svc.duplicatesPrevented}',
              Colors.orange,
            ),
            const SizedBox(width: 12),
            _statChip('Masters\nCreated', '${svc.mastersCreated}', Colors.teal),
            const SizedBox(width: 12),
            _statChip('GST Errors\nFound', '${svc.errorsFound}', Colors.red),
            const SizedBox(width: 12),
            _statChip(
              'In Queue',
              '${svc.pendingCount}',
              const Color(0xFF1A237E),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Tab sidebar (wide) ────────────────────────────────────────────────────

  Widget _buildTabSidebar(WorkbenchQueueService svc) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth = screenWidth < 960 ? 146.0 : 170.0;
    return SizedBox(
      width: sidebarWidth,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _WbTab.values
            .map((tab) => _tabItem(tab, _countForTab(tab, svc)))
            .toList(),
      ),
    );
  }

  Widget _buildTabScrollRow(WorkbenchQueueService svc) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: _WbTab.values
            .map(
              (tab) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _tabChip(tab, _countForTab(tab, svc)),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _tabItem(_WbTab tab, int count) {
    final selected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A237E).withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(
                  color: const Color(0xFF1A237E).withValues(alpha: 0.4),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(
              tab.icon,
              size: 18,
              color: selected ? const Color(0xFF1A237E) : Colors.black54,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tab.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                  color: selected ? const Color(0xFF1A237E) : Colors.black87,
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tab == _WbTab.errors
                      ? Colors.red
                      : const Color(0xFF1A237E),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tabChip(_WbTab tab, int count) {
    final selected = _selectedTab == tab;
    return InkWell(
      onTap: () => setState(() => _selectedTab = tab),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A237E) : const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : Colors.black87,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '($count)',
                style: TextStyle(
                  fontSize: 10,
                  color: selected ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Job List ──────────────────────────────────────────────────────────────

  Widget _buildJobList(WorkbenchQueueService svc) {
    final jobs = _jobsForTab(svc);
    final user = context.read<AuthController>().currentUser;
    final isClient = user?.role.isClient ?? false;

    if (jobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_selectedTab.icon, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _selectedTab == _WbTab.inbox
                  ? 'Drop a document above to get started'
                  : 'No documents in ${_selectedTab.label}',
              style: const TextStyle(color: Colors.black38, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: jobs.length,
      itemBuilder: (_, i) => _JobCard(
        key: ValueKey(jobs[i].id),
        job: jobs[i],
        onOpen: () => _openWorkspace(jobs[i]),
        onApprove: () => svc.approveJob(jobs[i].id),
        onReject: () => svc.rejectJob(jobs[i].id),
        onArchive: () => svc.archiveJob(jobs[i].id),
        onRetry: () => svc.retryJob(jobs[i].id),
        onComplete: () => _completeAccountantJob(svc, jobs[i]),
        clientMode: isClient,
        onRename: user == null
            ? null
            : () => _renameClientDocument(svc, jobs[i], user.id),
        onDelete: user == null
            ? null
            : () => _deleteClientDocument(svc, jobs[i], user.id),
      ),
    );
  }

  Future<void> _renameClientDocument(
    WorkbenchQueueService svc,
    WorkbenchJob job,
    String clientId,
  ) async {
    final controller = TextEditingController(text: job.fileName);
    final fileName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'File name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (fileName == null || !mounted) return;
    try {
      final remoteDocumentId = job.remoteDocumentId;
      if (remoteDocumentId != null && remoteDocumentId.isNotEmpty) {
        await OcrModuleApiService().rename(
          documentId: remoteDocumentId,
          clientId: clientId,
          assignedAccountantId: job.assignedAccountantId ?? '',
          fileName: fileName,
        );
      }
    } catch (error) {
      if (mounted) _snack('Document update failed: $error');
      return;
    }
    final updated = svc.updateClientDocument(
      jobId: job.id,
      clientId: clientId,
      fileName: fileName,
    );
    _snack(
      updated ? 'Document updated.' : 'Posted documents cannot be edited.',
    );
  }

  Future<void> _completeAccountantJob(
    WorkbenchQueueService svc,
    WorkbenchJob job,
  ) async {
    try {
      final remoteDocumentId = job.remoteDocumentId;
      if (remoteDocumentId != null && remoteDocumentId.isNotEmpty) {
        final clientId = job.clientId?.trim() ?? '';
        final accountantId = job.assignedAccountantId?.trim() ?? '';
        if (clientId.isEmpty || accountantId.isEmpty) {
          throw const FormatException(
            'Document assignment is incomplete. Refresh the OCR queue.',
          );
        }
        await OcrModuleApiService().complete(
          documentId: remoteDocumentId,
          clientId: clientId,
          assignedAccountantId: accountantId,
        );
      }
      svc.completeJob(job.id);
      _snack('Accounting entry completed. Client document is now locked.');
    } catch (error) {
      _snack('Could not complete document: $error');
    }
  }

  Future<void> _deleteClientDocument(
    WorkbenchQueueService svc,
    WorkbenchJob job,
    String clientId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Document?'),
        content: Text('Delete ${job.fileName} from the accountant queue?'),
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
    if (confirmed != true || !mounted) return;
    try {
      final remoteDocumentId = job.remoteDocumentId;
      if (remoteDocumentId != null && remoteDocumentId.isNotEmpty) {
        await OcrModuleApiService().delete(
          documentId: remoteDocumentId,
          clientId: clientId,
          assignedAccountantId: job.assignedAccountantId ?? '',
        );
      }
    } catch (error) {
      if (mounted) _snack('Document deletion failed: $error');
      return;
    }
    final deleted = svc.deleteClientDocument(jobId: job.id, clientId: clientId);
    _snack(
      deleted ? 'Document deleted.' : 'Posted documents cannot be deleted.',
    );
  }

  void _openWorkspace(WorkbenchJob job) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AiWorkspaceScreen(jobId: job.id)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _JobCard – single document card in the list
// ─────────────────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final WorkbenchJob job;
  final VoidCallback onOpen;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onArchive;
  final VoidCallback onRetry;
  final VoidCallback onComplete;
  final bool clientMode;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _JobCard({
    super.key,
    required this.job,
    required this.onOpen,
    required this.onApprove,
    required this.onReject,
    required this.onArchive,
    required this.onRetry,
    required this.onComplete,
    required this.clientMode,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _borderColor.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: job.result != null ? onOpen : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  _fileIcon(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.shortName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _timeLabel(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(),
                ],
              ),

              // AI Thinking progress (while processing)
              if (job.status == WorkbenchJobStatus.processing) ...[
                const SizedBox(height: 12),
                _AiThinkingProgress(
                  currentStage: job.currentStage,
                  completedStages: job.completedStages,
                ),
              ],

              // AI Decision (when result available)
              if (job.result != null) ...[
                const SizedBox(height: 10),
                _AiDecisionRow(job: job),
              ],

              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _metaChip('Channel', job.intakeChannelLabel, Colors.blue),
                  _metaChip('Queue', job.queueBucketLabel, Colors.blueGrey),
                  if (job.externalReference != null &&
                      job.externalReference!.isNotEmpty)
                    _metaChip('Ref', job.externalReference!, Colors.indigo),
                ],
              ),

              if (job.timeline.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Latest: ${job.timeline.last.title} · ${_timeOfDay(job.timeline.last.at)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (job.timeline.last.detail.trim().isNotEmpty)
                  Text(
                    job.timeline.last.detail,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],

              // Error message
              if (job.status == WorkbenchJobStatus.error &&
                  job.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.errorMessage!,
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              // Action buttons
              const SizedBox(height: 10),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Color get _borderColor {
    switch (job.status) {
      case WorkbenchJobStatus.verification:
        return Colors.orange;
      case WorkbenchJobStatus.approved:
        return Colors.green;
      case WorkbenchJobStatus.error:
        return Colors.red;
      case WorkbenchJobStatus.completed:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _fileIcon() {
    final ext = job.fileName.toLowerCase();
    final icon = ext.endsWith('.pdf')
        ? Icons.picture_as_pdf_outlined
        : (ext.endsWith('.jpg') ||
              ext.endsWith('.jpeg') ||
              ext.endsWith('.png') ||
              ext.endsWith('.webp'))
        ? Icons.image_outlined
        : Icons.insert_drive_file_outlined;
    final color = ext.endsWith('.pdf') ? Colors.red : Colors.indigo;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _statusBadge() {
    Color c;
    switch (job.status) {
      case WorkbenchJobStatus.inbox:
        c = Colors.grey;
        break;
      case WorkbenchJobStatus.processing:
        c = Colors.blue;
        break;
      case WorkbenchJobStatus.verification:
        c = Colors.orange;
        break;
      case WorkbenchJobStatus.approved:
        c = Colors.green;
        break;
      case WorkbenchJobStatus.completed:
        c = Colors.teal;
        break;
      case WorkbenchJobStatus.error:
        c = Colors.red;
        break;
      case WorkbenchJobStatus.archive:
        c = Colors.blueGrey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(
        job.status.label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }

  String _timeLabel() {
    final diff = DateTime.now().difference(job.uploadedAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (job.timeline.isNotEmpty)
          _actionBtn(
            'Timeline',
            Icons.timeline_outlined,
            Colors.deepPurple,
            () => _showTimelineSheet(context),
          ),
        if (job.result != null)
          _actionBtn('Open', Icons.open_in_new, Colors.indigo, onOpen),
        if (clientMode && job.canClientMutate(job.clientId ?? ''))
          _actionBtn('Rename', Icons.edit_outlined, Colors.blue, onRename!),
        if (clientMode && job.canClientMutate(job.clientId ?? ''))
          _actionBtn('Delete', Icons.delete_outline, Colors.red, onDelete!),
        if (clientMode && job.isPosted)
          _actionBtn('Locked', Icons.lock_outline, Colors.grey, () {}),
        if (!clientMode && job.status == WorkbenchJobStatus.verification)
          _actionBtn('Approve', Icons.check, Colors.green, onApprove),
        if (!clientMode && job.status == WorkbenchJobStatus.verification)
          _actionBtn('Reject', Icons.close, Colors.red, onReject),
        if (!clientMode && job.status == WorkbenchJobStatus.approved)
          _actionBtn('Complete', Icons.done_all, Colors.teal, onComplete),
        if (!clientMode && job.status == WorkbenchJobStatus.error)
          _actionBtn('Retry', Icons.refresh, Colors.orange, onRetry),
        if (!clientMode &&
            job.status != WorkbenchJobStatus.archive &&
            job.status != WorkbenchJobStatus.processing)
          _actionBtn(
            'Archive',
            Icons.archive_outlined,
            Colors.blueGrey,
            onArchive,
          ),
      ],
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _metaChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _timeOfDay(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showTimelineSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'Document Timeline${job.externalReference == null ? '' : ' · ${job.externalReference}'}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: job.timeline.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final e = job.timeline[i];
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F9FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFDDE4FF)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${e.at.day.toString().padLeft(2, '0')}/${e.at.month.toString().padLeft(2, '0')}/${e.at.year} ${_timeOfDay(e.at)}',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                            if (e.detail.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                e.detail,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _AiThinkingProgress – animated progress bars during pipeline execution
// ─────────────────────────────────────────────────────────────────────────────

class _AiThinkingProgress extends StatefulWidget {
  final SmartInvoiceStage currentStage;
  final List<SmartInvoiceStage> completedStages;

  const _AiThinkingProgress({
    required this.currentStage,
    required this.completedStages,
  });

  @override
  State<_AiThinkingProgress> createState() => _AiThinkingProgressState();
}

class _AiThinkingProgressState extends State<_AiThinkingProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  static const List<_StageLabel> _stages = [
    _StageLabel(SmartInvoiceStage.readingDocument, 'Reading OCR'),
    _StageLabel(SmartInvoiceStage.duplicateCheck, 'Checking Duplicate'),
    _StageLabel(SmartInvoiceStage.qrDetection, 'Reading QR'),
    _StageLabel(SmartInvoiceStage.gstValidation, 'Reading GST'),
    _StageLabel(SmartInvoiceStage.classification, 'Recognizing Layout'),
    _StageLabel(SmartInvoiceStage.masterMatching, 'Matching Customer'),
    _StageLabel(SmartInvoiceStage.productMatching, 'Matching Product'),
    _StageLabel(SmartInvoiceStage.taxValidation, 'Tax Validation'),
    _StageLabel(SmartInvoiceStage.confidenceCalc, 'Confidence'),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _stages.map((s) {
        final isDone = widget.completedStages.contains(s.stage);
        final isCurrent = widget.currentStage == s.stage;
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDone
                        ? Colors.green
                        : isCurrent
                        ? const Color(0xFF1A237E)
                        : Colors.black38,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: isDone
                    ? _doneBar()
                    : isCurrent
                    ? AnimatedBuilder(
                        animation: _pulse,
                        builder: (ctx, child) => LinearProgressIndicator(
                          value: _pulse.value,
                          backgroundColor: Colors.grey.shade200,
                          color: const Color(0xFF1A237E),
                          minHeight: 5,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      )
                    : _emptyBar(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _doneBar() => Container(
    height: 5,
    decoration: BoxDecoration(
      color: Colors.green,
      borderRadius: BorderRadius.circular(3),
    ),
  );

  Widget _emptyBar() => Container(
    height: 5,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(3),
    ),
  );
}

class _StageLabel {
  final SmartInvoiceStage stage;
  final String label;
  const _StageLabel(this.stage, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// _AiDecisionRow – compact result row on a job card
// ─────────────────────────────────────────────────────────────────────────────

class _AiDecisionRow extends StatelessWidget {
  final WorkbenchJob job;

  const _AiDecisionRow({required this.job});

  @override
  Widget build(BuildContext context) {
    final r = job.result!;
    final c = r.confidence;
    final overall = c.overall;
    final color = overall >= 0.95
        ? Colors.green
        : overall >= 0.75
        ? Colors.orange
        : Colors.red;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                'Detected: ${job.documentTypeLabel}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                '${(overall * 100).round()}%',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metricBadge('Queue', job.queueBucketLabel, Colors.blueGrey),
              _metricBadge(
                'Party Match',
                '${((r.partyMatch?.confidence ?? 0) * 100).round()}%',
                _scoreColor(r.partyMatch?.confidence ?? 0),
              ),
              _metricBadge(
                'Item Match',
                '${(_avgProductConfidence(r) * 100).round()}%',
                _scoreColor(_avgProductConfidence(r)),
              ),
              _metricBadge(
                'Duplicate Risk',
                '${(r.duplicateResult.score * 100).round()}%',
                _scoreColor(1 - r.duplicateResult.score),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _miniVerify(
                'Supplier',
                r.partyMatch != null && !r.partyMatch!.isNewMaster,
              ),
              _miniVerify(
                'Customer',
                r.partyMatch != null && !r.partyMatch!.isNewMaster,
              ),
              _miniVerify('Products', r.productMatches.isNotEmpty),
              _miniVerify('GST', r.gstResult.formatValid),
              _miniVerify('Duplicate', !r.duplicateResult.isDuplicate),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniVerify(String label, bool ok) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel_outlined,
          size: 12,
          color: ok ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  double _avgProductConfidence(SmartInvoiceResult r) {
    if (r.productMatches.isEmpty) return 0;
    final total = r.productMatches
        .map((match) => match.confidence)
        .reduce((a, b) => a + b);
    return total / r.productMatches.length;
  }

  Color _scoreColor(double score) {
    if (score >= 0.95) return Colors.green;
    if (score >= 0.80) return Colors.orange;
    return Colors.red;
  }

  Widget _metricBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
