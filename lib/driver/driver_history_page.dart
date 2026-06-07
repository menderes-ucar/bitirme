import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DriverHistoryPage extends StatelessWidget {
  final String driverId;

  const DriverHistoryPage({
    super.key,
    required this.driverId,
  });

  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);
  static const Color softBg = Color(0xFFF6FEFD);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('trips')
              .where('driverId', isEqualTo: driverId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs.where((doc) {
              final s = (doc.data()['status'] ?? '').toString();
              return s == 'completed' || s == 'paid' || s == 'cancelled';
            }).toList();

            docs.sort((a, b) {
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];
              final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
              final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
              return bm.compareTo(am);
            });

            final totalEarned = docs.fold<num>(0, (sum, doc) {
              final p = doc.data()['price'];
              return sum + (p is num ? p : 0);
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _header(
                  totalTrips: docs.length,
                  totalEarned: totalEarned,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Geçmiş Yolculuklar',
                  style: TextStyle(
                    color: dark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tamamlanan, ödenen ve iptal edilen yolculuklar burada görünür.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                if (docs.isEmpty)
                  _empty()
                else
                  ...docs.map((doc) {
                    final d = doc.data();
                    return _historyCard(
                      from: (d['fromText'] ?? 'Kalkış').toString(),
                      to: (d['toText'] ?? 'Varış').toString(),
                      status: (d['status'] ?? '-').toString(),
                      price: d['price'],
                      distanceM: d['distanceM'],
                      createdAt: d['createdAt'],
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header({
    required int totalTrips,
    required num totalEarned,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.22),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sürüş Özeti',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Geçmiş performans ve kazanç takibi',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _summaryBox(
                icon: Icons.route_rounded,
                title: 'Toplam Trip',
                value: '$totalTrips',
              ),
              const SizedBox(width: 10),
              _summaryBox(
                icon: Icons.payments_rounded,
                title: 'Kazanç',
                value: '₺$totalEarned',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBox({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Column(
          children: [
            Icon(icon, color: turquoise),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard({
    required String from,
    required String to,
    required String status,
    required dynamic price,
    required dynamic distanceM,
    required dynamic createdAt,
  }) {
    final color = _statusColor(status);
    final distanceText = distanceM is num
        ? distanceM >= 1000
        ? '${(distanceM / 1000).toStringAsFixed(1)} km'
        : '${distanceM.round()} m'
        : '—';

    final dateText = createdAt is Timestamp
        ? '${createdAt.toDate().day}.${createdAt.toDate().month}.${createdAt.toDate().year}'
        : 'Tarih yok';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: turquoise.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.10),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: color.withOpacity(.12),
                child: Icon(Icons.local_taxi_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                dateText,
                style: const TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _routeRow(turquoise, 'Kalkış', from),
          const SizedBox(height: 10),
          _routeRow(dark, 'Varış', to),
          const SizedBox(height: 16),
          Row(
            children: [
              _infoBox(Icons.route_outlined, 'Mesafe', distanceText),
              const SizedBox(width: 8),
              _infoBox(Icons.payments_outlined, 'Ücret', '₺${price ?? 0}'),
              const SizedBox(width: 8),
              _infoBox(Icons.verified_rounded, 'Durum', _statusText(status)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _routeRow(Color color, String title, String value) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.w700)),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: dark, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoBox(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: softBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: turquoise.withOpacity(.16)),
        ),
        child: Column(
          children: [
            Icon(icon, color: turquoise, size: 20),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: dark, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: turquoise.withOpacity(.20)),
      ),
      child: const Column(
        children: [
          Icon(Icons.history_rounded, color: turquoise, size: 56),
          SizedBox(height: 12),
          Text(
            'Geçmiş yolculuk yok',
            style: TextStyle(color: dark, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Tamamlanan yolculukların burada listelenecek.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
      case 'paid':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return Colors.red;
      default:
        return dark;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'completed':
        return 'Tamamlandı';
      case 'paid':
        return 'Ödendi';
      case 'cancelled':
        return 'İptal Edildi';
      default:
        return status;
    }
  }
}