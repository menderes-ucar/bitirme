import 'package:flutter/material.dart';

import 'customer_active_page.dart';
import 'customer_history_page.dart';
import 'customer_page.dart';
import 'customer_profile_page.dart';

class CustomerShellPage extends StatefulWidget {
  final String customerId;

  const CustomerShellPage({
    super.key,
    required this.customerId,
  });

  @override
  State<CustomerShellPage> createState() => _CustomerShellPageState();
}

class _CustomerShellPageState extends State<CustomerShellPage> {
  int index = 0;

  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);

  @override
  Widget build(BuildContext context) {
    final pages = [
      CustomerPage(customerId: widget.customerId),
      CustomerActivePage(customerId: widget.customerId),
      CustomerHistoryPage(customerId: widget.customerId),
      const CustomerProfilePage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 24,
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
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.map_rounded),
              label: 'Yolculuk',
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