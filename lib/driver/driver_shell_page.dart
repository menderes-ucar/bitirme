import 'package:flutter/material.dart';

import 'driver_active_page.dart';
import 'driver_history_page.dart';
import 'driver_page.dart';
import 'driver_profile_page.dart';

class DriverShellPage extends StatefulWidget {
  final String driverId;

  const DriverShellPage({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverShellPage> createState() => _DriverShellPageState();
}

class _DriverShellPageState extends State<DriverShellPage> {
  int index = 0;

  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DriverPage(driverId: widget.driverId),
      DriverActivePage(driverId: widget.driverId),
      DriverHistoryPage(driverId: widget.driverId),
      DriverProfilePage(driverId: widget.driverId),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 22,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          onTap: (v) => setState(() => index = v),
          selectedItemColor: turquoise,
          unselectedItemColor: Colors.black45,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'Panel',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.local_taxi_rounded),
              label: 'Aktif',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Geçmiş',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }
}