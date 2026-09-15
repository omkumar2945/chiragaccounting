import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chirag_accounting/features/authentication/controllers/auth_controller.dart';
import 'package:chirag_accounting/features/clients/Profile/client_profile_screen.dart';
import 'package:chirag_accounting/features/clients/Settings/client_settings_screen.dart';
import 'package:chirag_accounting/features/clients/services/client_profile_service.dart';
import 'package:chirag_accounting/features/dashboard/presentation/pages/dashboard_screen.dart';

class ProfileAvatarMenu extends StatelessWidget {
  const ProfileAvatarMenu({super.key, this.showDashboardOption = true});

  final bool showDashboardOption;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return FutureBuilder(
      future: ClientProfileService().load(
        user.id,
        useAuthoritativeClientApi: user.role.isClient,
      ),
      builder: (context, snapshot) {
        final base64Image = snapshot.data?.logoDataBase64 ?? '';
        ImageProvider<Object>? provider;
        if (base64Image.trim().isNotEmpty) {
          try {
            provider = MemoryImage(base64Decode(base64Image));
          } catch (_) {
            provider = null;
          }
        }

        return PopupMenuButton<String>(
          tooltip: 'Profile',
          onSelected: (value) {
            if (value == 'dashboard') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DashboardScreen()),
              );
            }
            if (value == 'profile') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientProfileScreen()),
              );
            }
            if (value == 'settings') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ClientSettingsScreen()),
              );
            }
          },
          itemBuilder: (_) => [
            if (showDashboardOption)
              const PopupMenuItem(
                value: 'dashboard',
                child: Row(
                  children: [
                    Icon(Icons.dashboard_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Dashboard'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, size: 18),
                  SizedBox(width: 8),
                  Text('Settings'),
                ],
              ),
            ),
          ],
          child: CircleAvatar(
            radius: 15,
            backgroundColor: Colors.white24,
            backgroundImage: provider,
            child: provider == null
                ? Text(
                    user.name.isEmpty ? 'U' : user.name[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }
}
