import 'package:flutter/material.dart';

import '../services/repository.dart';
import '../theme.dart';
import 'catalog_admin_tabs.dart';
import 'duty_admin_tab.dart';
import 'reports_admin_tab.dart';
import 'reviews_admin_tab.dart';

/// Back office : signalements, stations, pharmacies et liste de garde.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await repo.signOutAdmin();
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administration'),
          actions: [
            IconButton(
              tooltip: 'Se déconnecter',
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout_rounded),
            ),
            const SizedBox(width: 8),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.symmetric(horizontal: 8),
            labelColor: AppColors.greenDark,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.green,
            indicatorWeight: 3,
            dividerColor: AppColors.line,
            labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            tabs: [
              Tab(text: 'Signalements'),
              Tab(text: 'Avis'),
              Tab(text: 'Garde de la semaine'),
              Tab(text: 'Stations'),
              Tab(text: 'Pharmacies'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ReportsAdminTab(),
            ReviewsAdminTab(),
            DutyAdminTab(),
            StationsAdminTab(),
            PharmaciesAdminTab(),
          ],
        ),
      ),
    );
  }
}
