import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../admin/admin_page.dart';
import '../customer/customer_shell_page.dart';
import '../login_page.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';
import 'driver/driver_shell_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<AppUser?> _loadUser() {
    return AuthService().getCurrentAppUser();
  }

  Future<void> _syncDemoDriverDoc(AppUser appUser) async {
    final driverId = appUser.driverId ?? appUser.uid;

    final driverRef =
    FirebaseFirestore.instance.collection('drivers').doc(driverId);

    await driverRef.set({
      'uid': appUser.uid,
      'email': appUser.email,
      'name': appUser.name,
      'status': 'active',
      'isApproved': true,
      'isOnline': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _LoadingScreen();
        }

        if (!authSnap.hasData) {
          return const LoginPage();
        }

        return FutureBuilder<AppUser?>(
          future: _loadUser(),
          builder: (context, userSnap) {
            if (userSnap.connectionState == ConnectionState.waiting) {
              return const _LoadingScreen();
            }

            final appUser = userSnap.data;

            if (appUser == null) {
              return const _AuthErrorScreen();
            }

            return DemoRoleSelectorPage(appUser: appUser);
          },
        );
      },
    );
  }
}
class _AuthErrorScreen extends StatelessWidget {
  const _AuthErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kullanıcı kaydı okunamadı veya onay bilgisi eksik.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: () async {
                  await AuthService().signOut();
                },
                child: const Text('Çıkış yap'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class DemoRoleSelectorPage extends StatelessWidget {
  final AppUser appUser;

  const DemoRoleSelectorPage({
    super.key,
    required this.appUser,
  });

  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);
  static const Color softBg = Color(0xFFF6FEFD);

  Future<void> _openDriver(BuildContext context) async {
    final driverId = appUser.driverId ?? appUser.uid;

    await FirebaseFirestore.instance.collection('drivers').doc(driverId).set({
      'uid': appUser.uid,
      'email': appUser.email,
      'name': appUser.name,
      'status': 'active',
      'isApproved': true,
      'isOnline': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverShellPage(driverId: driverId),
      ),
    );
  }

  void _openCustomer(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerShellPage(customerId: appUser.uid),
      ),
    );
  }

  void _openAdmin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService().signOut();
            },
            icon: const Icon(Icons.logout_rounded, color: dark),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: dark,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Text(
                    'Hoş geldin, ${appUser.name}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _roleCard(
              icon: Icons.person_pin_circle_rounded,
              title: 'Yolcu Paneli',
              subtitle: 'Yolculuk iste, aktif yolculuğu takip et ve ödeme ekranını göster.',
              onTap: () => _openCustomer(context),
            ),
            _roleCard(
              icon: Icons.local_taxi_rounded,
              title: 'Şoför Paneli',
              subtitle: 'Yeni yolculukları gör, kabul et ve yolculuk akışını yönet.',
              onTap: () => _openDriver(context),
            ),
            _roleCard(
              icon: Icons.admin_panel_settings_rounded,
              title: 'Admin Paneli',
              subtitle: 'Yolculukları, şoför atamalarını ve başvuruları yönet.',
              onTap: () => _openAdmin(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: turquoise.withOpacity(.22)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: turquoise.withOpacity(.14),
                child: Icon(icon, color: turquoise, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: dark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: dark),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}