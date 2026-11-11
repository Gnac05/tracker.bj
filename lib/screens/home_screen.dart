import 'package:flutter/material.dart';

import '../admin/admin_home_screen.dart';
import '../admin/admin_login_screen.dart';
import '../services/location_service.dart';
import '../services/repository.dart';
import '../theme.dart';
import 'pharmacies_tab.dart';
import 'report_screen.dart';
import 'stations_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _openAdmin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => repo.isAdmin.value
            ? const AdminHomeScreen()
            : const AdminLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tab == 0 ? 'Stations-service' : 'Pharmacies de garde'),
            const SizedBox(height: 2),
            ListenableBuilder(
              listenable: location,
              builder: (context, _) => Row(
                children: [
                  Icon(
                    location.hasFix
                        ? Icons.near_me_rounded
                        : Icons.location_searching_rounded,
                    size: 13,
                    color: AppColors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    switch (location.state) {
                      LocationState.ready =>
                        'De la plus proche à la plus éloignée',
                      LocationState.loading => 'Recherche de votre position…',
                      _ => 'Position indisponible',
                    },
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Espace administrateur',
            onPressed: _openAdmin,
            icon: const Icon(Icons.admin_panel_settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: const [StationsTab(), PharmaciesTab()],
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ReportScreen())),
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Signaler'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_gas_station_outlined),
            selectedIcon: Icon(Icons.local_gas_station_rounded),
            label: 'Essence',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_pharmacy_outlined),
            selectedIcon: Icon(Icons.local_pharmacy_rounded),
            label: 'Pharmacies',
          ),
        ],
      ),
    );
  }
}
