import 'package:flutter/material.dart';

import '../admin/admin_home_screen.dart';
import '../admin/admin_login_screen.dart';
import '../services/location_service.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../widgets/responsive.dart';
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
    if (repo.isAdmin.value) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AdminHomeScreen()));
    } else {
      openPage(context, const AdminLoginScreen());
    }
  }

  static const _destinations = [
    (
      Icons.local_gas_station_outlined,
      Icons.local_gas_station_rounded,
      'Essence',
    ),
    (Icons.local_pharmacy_outlined, Icons.local_pharmacy_rounded, 'Pharmacies'),
  ];

  /// Navigation latérale des grands écrans (étendue au-delà de 1100 px).
  Widget _rail(double width) {
    final extended = width >= 1100;
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 210,
      backgroundColor: Colors.white,
      indicatorColor: AppColors.okBg,
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      labelType: extended
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      selectedIconTheme: const IconThemeData(color: AppColors.greenDark),
      unselectedIconTheme: const IconThemeData(color: AppColors.muted),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.greenDark,
        fontWeight: FontWeight.w800,
        fontSize: 13.5,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.muted,
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
      leading: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.near_me_rounded, color: Colors.white),
            ),
            if (extended) ...[
              const SizedBox(width: 12),
              const Text(
                'Tracker Bénin',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ],
        ),
      ),
      destinations: [
        for (final d in _destinations)
          NavigationRailDestination(
            icon: Icon(d.$1),
            selectedIcon: Icon(d.$2),
            label: Text(d.$3),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= kWideBreakpoint;
    final page = _page(wide);
    if (!wide) return page;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            _rail(width),
            const VerticalDivider(width: 1),
            Expanded(child: page),
          ],
        ),
      ),
    );
  }

  Widget _page(bool wide) {
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
              onPressed: () => openPage(context, const ReportScreen()),
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Signaler'),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(
                    icon: Icon(d.$1),
                    selectedIcon: Icon(d.$2),
                    label: d.$3,
                  ),
              ],
            ),
    );
  }
}
