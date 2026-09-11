import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/gst_library/services/gst_library_service.dart';
import 'package:chirag_accounting/features/gst_notices/presentation/pages/gst_notice_management_screen.dart';
import 'package:chirag_accounting/features/gst_scrutiny/presentation/pages/gst_scrutiny_center_screen.dart';

enum _LibraryViewFilter { all, act, section, judgement }

class GstLibraryScreen extends StatefulWidget {
  const GstLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.showAdminActions = false,
    this.initialSectionId,
  });

  final bool selectionMode;
  final bool showAdminActions;
  final String? initialSectionId;

  @override
  State<GstLibraryScreen> createState() => _GstLibraryScreenState();
}

class _GstLibraryScreenState extends State<GstLibraryScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  _LibraryViewFilter _filter = _LibraryViewFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<GstLibraryService>();
    var sections = service.searchSections(
      _searchCtrl.text,
      category: _filterCategoryKey(_filter),
    );

    if (widget.initialSectionId != null) {
      sections = <GstLibrarySection>[
        ...sections.where((section) => section.id == widget.initialSectionId),
        ...sections.where((section) => section.id != widget.initialSectionId),
      ];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectionMode ? 'Select GST Reference' : 'GST Library'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (widget.showAdminActions && !widget.selectionMode) ...[
            const _AdminQuickActionsCard(),
            const SizedBox(height: 12),
          ],
          _LibrarySummaryCard(
            sectionCount: service.sections.length,
            chapterCount: service.actChapters.length,
            amendmentCount: service.amendmentTimeline.length,
            judgementCount: service.judgements.length,
          ),
          const SizedBox(height: 12),
          _buildSearchPanel(),
          const SizedBox(height: 12),
          if (sections.isEmpty)
            const _EmptyLibraryState()
          else
            ...sections.map(
              (section) => _LibrarySectionTile(
                section: section,
                selectionMode: widget.selectionMode,
                onTap: () => _openSection(context, service, section),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search section, issue, court, order, outcome...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip(_LibraryViewFilter.all, 'All'),
                _buildFilterChip(_LibraryViewFilter.act, 'Act & Amendments'),
                _buildFilterChip(_LibraryViewFilter.section, 'Sections & Rules'),
                _buildFilterChip(_LibraryViewFilter.judgement, 'Judgements & Orders'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(_LibraryViewFilter value, String label) {
    return FilterChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  String _filterCategoryKey(_LibraryViewFilter filter) {
    switch (filter) {
      case _LibraryViewFilter.act:
        return 'act';
      case _LibraryViewFilter.judgement:
        return 'judgement';
      case _LibraryViewFilter.section:
        return 'section';
      case _LibraryViewFilter.all:
        return 'all';
    }
  }

  void _openSection(
    BuildContext context,
    GstLibraryService service,
    GstLibrarySection section,
  ) {
    if (widget.selectionMode) {
      Navigator.pop(context, section.id);
      return;
    }

    if (section.id == 'cgst-act-2017-complete') {
      showDialog<void>(
        context: context,
        builder: (_) => _ActReferenceDialog(
          chapters: service.actChapters,
          amendments: service.amendmentTimeline,
        ),
      );
      return;
    }

    if (section.id == 'gst-case-judgements-orders') {
      showDialog<void>(
        context: context,
        builder: (_) => _JudgementsDialog(service: service),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (_) => _SectionDetailDialog(section: section),
    );
  }
}

class _LibrarySummaryCard extends StatelessWidget {
  const _LibrarySummaryCard({
    required this.sectionCount,
    required this.chapterCount,
    required this.amendmentCount,
    required this.judgementCount,
  });

  final int sectionCount;
  final int chapterCount;
  final int amendmentCount;
  final int judgementCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryChip(label: 'Sections & Rules', value: '$sectionCount'),
            _SummaryChip(label: 'Act Chapters', value: '$chapterCount'),
            _SummaryChip(label: 'Amendments', value: '$amendmentCount'),
            _SummaryChip(label: 'Judgements', value: '$judgementCount'),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE3EC)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _LibrarySectionTile extends StatelessWidget {
  const _LibrarySectionTile({
    required this.section,
    required this.selectionMode,
    required this.onTap,
  });

  final GstLibrarySection section;
  final bool selectionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: Icon(_iconFor(section.category)),
            title: Text(section.displayName),
            subtitle: Text(section.summary),
            trailing: selectionMode
                ? const Icon(Icons.check_circle_outline)
                : const Icon(Icons.open_in_new_outlined),
            onTap: onTap,
          ),
          if (section.highlights.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: section.highlights
                      .map((point) => Chip(label: Text(point)))
                      .toList(growable: false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'act':
        return Icons.menu_book_outlined;
      case 'judgement':
        return Icons.gavel_outlined;
      default:
        return Icons.rule_folder_outlined;
    }
  }
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
        child: Column(
          children: const [
            Icon(Icons.search_off_outlined, size: 42),
            SizedBox(height: 10),
            Text(
              'No GST library item matches the current search/filter.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionDetailDialog extends StatelessWidget {
  const _SectionDetailDialog({required this.section});

  final GstLibrarySection section;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(section.displayName),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section.summary),
              if (section.highlights.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Included Working Coverage',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final point in section.highlights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.arrow_right, size: 18),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(point)),
                      ],
                    ),
                  ),
              ],
              if (section.keywords.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Issue Tags',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: section.keywords
                      .map((keyword) => Chip(label: Text(keyword)))
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ActReferenceDialog extends StatelessWidget {
  const _ActReferenceDialog({
    required this.chapters,
    required this.amendments,
  });

  final List<GstActChapter> chapters;
  final List<GstActAmendmentEntry> amendments;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 820,
        height: 680,
        child: Column(
          children: [
            AppBar(
              title: const Text('Full GST Act 2017 with Amendments'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Chapter-wise working coverage',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ...chapters.map(
                    (chapter) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chapter.title,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(chapter.sectionRange),
                            const SizedBox(height: 6),
                            Text(chapter.summary),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: chapter.focusAreas
                                  .map((item) => Chip(label: Text(item)))
                                  .toList(growable: false),
                            ),
                            const SizedBox(height: 8),
                            Text('Scrutiny use: ${chapter.scrutinyUse}'),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Amendment timeline',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  ...amendments.map(
                    (entry) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text('${entry.year} - ${entry.amendingInstrument}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Text(entry.summary),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: entry.affectedAreas
                                  .map((item) => Chip(label: Text(item)))
                                  .toList(growable: false),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    ),
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

class _AdminQuickActionsCard extends StatelessWidget {
  const _AdminQuickActionsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Admin GST Actions',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Open upload management and upgraded scrutiny drafting directly from GST Library.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GstLibraryScreen(
                        initialSectionId: 'cgst-act-2017-complete',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('Full GST Act 2017'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GstNoticeManagementScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Client Notice Upload System'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GstScrutinyCenterScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('Scrutiny Draft Reply Upgrade'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GstLibraryScreen(
                        initialSectionId: 'gst-case-judgements-orders',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.gavel_outlined),
                  label: const Text('Case Judgements & Orders'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JudgementsDialog extends StatefulWidget {
  const _JudgementsDialog({required this.service});

  final GstLibraryService service;

  @override
  State<_JudgementsDialog> createState() => _JudgementsDialogState();
}

class _JudgementsDialogState extends State<_JudgementsDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _court;
  String? _filedBy;
  String? _outcome;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final judgements = widget.service.searchJudgements(
      query: _searchCtrl.text,
      court: _court,
      filedBy: _filedBy,
      outcome: _outcome,
    );

    return Dialog(
      child: SizedBox(
        width: 860,
        height: 680,
        child: Column(
          children: [
            AppBar(
              title: const Text('GST Case Judgements, Filed/Won Orders'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search issue, case title, order reference or argument...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _FilterDropdown(
                        width: 240,
                        label: 'Court',
                        value: _court,
                        items: widget.service.judgementCourts,
                        onChanged: (value) => setState(() => _court = value),
                      ),
                      _FilterDropdown(
                        width: 220,
                        label: 'Filed By',
                        value: _filedBy,
                        items: widget.service.judgementFiledByOptions,
                        onChanged: (value) => setState(() => _filedBy = value),
                      ),
                      _FilterDropdown(
                        width: 260,
                        label: 'Outcome',
                        value: _outcome,
                        items: widget.service.judgementOutcomeOptions,
                        onChanged: (value) => setState(() => _outcome = value),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: judgements.isEmpty
                  ? const Center(child: Text('No judgement matches the current filters.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      itemCount: judgements.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final judgement = judgements[index];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  judgement.title,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(judgement.summary),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Chip(label: Text(judgement.court)),
                                    Chip(label: Text('${judgement.year}')),
                                    Chip(label: Text(judgement.topic)),
                                    Chip(label: Text('Filed by: ${judgement.filedBy}')),
                                    Chip(label: Text(judgement.outcome)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Order: ${judgement.orderReference}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 4),
                                Text(judgement.orderSummary),
                                const SizedBox(height: 6),
                                Text('Draft reply use: ${judgement.replyUse}'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.width,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final double width;
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? null
              : IconButton(
                  onPressed: () => onChanged(null),
                  icon: const Icon(Icons.close),
                ),
        ),
        items: items
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: Text(item, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        onChanged: onChanged,
      ),
    );
  }
}
