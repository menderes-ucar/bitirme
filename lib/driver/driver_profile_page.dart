import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class DriverProfilePage extends StatelessWidget {
  final String driverId;

  const DriverProfilePage({
    super.key,
    required this.driverId,
  });

  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);
  static const Color softBg = Color(0xFFF6FEFD);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('drivers').doc(driverId).snapshots(),
          builder: (context, snap) {
            final d = snap.data?.data();

            final name = (d?['name'] ?? user?.email ?? '-').toString();
            final status = (d?['status'] ?? '-').toString();
            final isOnline = d?['isOnline'] == true;
            final isApproved = d?['isApproved'] == true;
            final phone = (d?['phone'] ?? '-').toString();
            final city = (d?['city'] ?? d?['address'] ?? '-').toString();
            final vehicle = d?['vehicle'] as Map<String, dynamic>?;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _profileHeader(
                  name: name,
                  email: user?.email ?? '-',
                  isOnline: isOnline,
                  isApproved: isApproved,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _statCard(Icons.verified_rounded, 'Onay', isApproved ? 'Onaylı' : 'Bekliyor'),
                    const SizedBox(width: 10),
                    _statCard(Icons.power_settings_new_rounded, 'Durum', isOnline ? 'Online' : 'Offline'),
                    const SizedBox(width: 10),
                    _statCard(Icons.star_rounded, 'Puan', '${((d?['ratingAverage'] ?? 0) as num).toStringAsFixed(1)}'),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Profil Bilgileri',
                  style: TextStyle(
                    color: dark,
                    fontSize: 24,
                    letterSpacing: -.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                _profileTile(Icons.badge_outlined, 'Şoför ID', driverId),
                _profileTile(Icons.person_outline, 'Ad Soyad', name),
                _profileTile(Icons.phone_outlined, 'Telefon', phone),
                _profileTile(Icons.location_city_outlined, 'Şehir / Adres', city),
                _profileTile(Icons.info_outline, 'Sistem Durumu', status),
                _profileTile(
                  Icons.directions_car_outlined,
                  'Araç',
                  vehicle == null
                      ? 'Araç bilgisi yok'
                      : '${vehicle['brand'] ?? ''} ${vehicle['model'] ?? ''}',
                ),
                _profileTile(
                  Icons.confirmation_number_outlined,
                  'Plaka',
                  vehicle == null ? '-' : '${vehicle['plate'] ?? '-'}',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dark,
                      foregroundColor: turquoise,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Çıkış Yap',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _profileHeader({
    required String name,
    required String email,
    required bool isOnline,
    required bool isApproved,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.24),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: turquoise,
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(Icons.person_rounded, color: dark, size: 58),
          ),
          const SizedBox(height: 16),
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _headerPill(
                isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                isOnline ? const Color(0xFF16A34A) : Colors.red,
              ),
              const SizedBox(width: 10),
              _headerPill(
                isApproved ? 'Onaylı Sürücü' : 'Onay Bekliyor',
                turquoise,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerPill(String text, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(.13),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.30)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: turquoise.withOpacity(.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: turquoise),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: dark,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: turquoise.withOpacity(.16)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: turquoise.withOpacity(.12),
            child: Icon(icon, color: turquoise, size: 22),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: dark,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}