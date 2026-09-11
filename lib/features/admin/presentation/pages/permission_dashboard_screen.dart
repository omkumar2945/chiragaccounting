import 'package:chirag_accounting/features/roles/models/permission_model.dart';
import 'package:chirag_accounting/features/roles/models/role_model.dart';
import 'package:chirag_accounting/features/roles/services/hierarchical_permission_evaluator.dart';
import 'package:flutter/material.dart';

class PermissionDashboardScreen extends StatefulWidget {
  const PermissionDashboardScreen({super.key});

  @override
  State<PermissionDashboardScreen> createState() =>
      _PermissionDashboardScreenState();
}

class _PermissionDashboardScreenState extends State<PermissionDashboardScreen> {
  static const _evaluator = HierarchicalPermissionEvaluator();

  UserRole _selectedRole = UserRole.superAdmin;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final modules = AppModule.values
        .where((module) {
          return module.displayName.toLowerCase().contains(
            _query.toLowerCase(),
          );
        })
        .toList(growable: false);
    final accessibleCount = AppModule.values
        .where((module) => _evaluator.canAccessModule(_selectedRole, module))
        .length;
    final editableCount = AppModule.values
        .where((module) => _evaluator.canEditModule(_selectedRole, module))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Permission Dashboard'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 900 ? 24.0 : 12.0;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              24,
            ),
            children: [
              _buildControls(),
              const SizedBox(height: 12),
              _buildSummary(accessibleCount, editableCount),
              const SizedBox(height: 12),
              if (modules.isEmpty)
                const _EmptyPermissions()
              else
                ...modules.map(_buildModuleRow),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<UserRole>(
              isExpanded: true,
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
              items: UserRole.values
                  .map(
                    (role) => DropdownMenuItem<UserRole>(
                      value: role,
                      child: Text(
                        role.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (role) {
                if (role != null) setState(() => _selectedRole = role);
              },
            ),
          ),
          SizedBox(
            width: 320,
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Find module',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(int accessibleCount, int editableCount) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _MetricTile(
          label: 'Role',
          value: _selectedRole.displayName,
          icon: Icons.admin_panel_settings_outlined,
        ),
        _MetricTile(
          label: 'Accessible modules',
          value: '$accessibleCount / ${AppModule.values.length}',
          icon: Icons.visibility_outlined,
        ),
        _MetricTile(
          label: 'Editable modules',
          value: '$editableCount / ${AppModule.values.length}',
          icon: Icons.edit_outlined,
        ),
      ],
    );
  }

  Widget _buildModuleRow(AppModule module) {
    final level = _evaluator.resolveModulePermission(_selectedRole, module);
    final color = _levelColor(level);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          child: Icon(_levelIcon(level)),
        ),
        title: Text(
          module.displayName,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(_levelDescription(level)),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            level.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Color _levelColor(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.none:
        return const Color(0xFFC62828);
      case PermissionLevel.view:
        return const Color(0xFF455A64);
      case PermissionLevel.limited:
        return const Color(0xFFEF6C00);
      case PermissionLevel.full:
        return const Color(0xFF2E7D32);
    }
  }

  IconData _levelIcon(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.none:
        return Icons.block_outlined;
      case PermissionLevel.view:
        return Icons.visibility_outlined;
      case PermissionLevel.limited:
        return Icons.rule_outlined;
      case PermissionLevel.full:
        return Icons.verified_user_outlined;
    }
  }

  String _levelDescription(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.none:
        return 'Module is hidden and all screen actions are denied.';
      case PermissionLevel.view:
        return 'Read, print, export, and share actions are available.';
      case PermissionLevel.limited:
        return 'Operational access without delete, lock, or unlock.';
      case PermissionLevel.full:
        return 'All module and screen actions are available.';
    }
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD8E2F0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0D47A1)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPermissions extends StatelessWidget {
  const _EmptyPermissions();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.search_off_outlined, size: 42, color: Colors.black38),
          SizedBox(height: 10),
          Text('No modules match this search.'),
        ],
      ),
    );
  }
}
