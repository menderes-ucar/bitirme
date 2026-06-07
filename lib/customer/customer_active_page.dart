import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../trip_tracking_page.dart';

class CustomerActivePage extends StatelessWidget {
  final String customerId;

  const CustomerActivePage({
    super.key,
    required this.customerId,
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
              .where('customerId', isEqualTo: customerId)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final docs = snap.data!.docs.where((doc) {
              final s = (doc.data()['status'] ?? '').toString();

              return s == 'queued' ||
                  s == 'assigned' ||
                  s == 'driver_arriving' ||
                  s == 'driver_arrived' ||
                  s == 'started' ||
                  s == 'payment_pending';
            }).toList();

            docs.sort((a, b) {
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];

              final am = at is Timestamp
                  ? at.millisecondsSinceEpoch
                  : 0;

              final bm = bt is Timestamp
                  ? bt.millisecondsSinceEpoch
                  : 0;

              return bm.compareTo(am);
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _hero(docs.length),

                const SizedBox(height: 20),

                const Text(
                  'Aktif Yolculuklar',
                  style: TextStyle(
                    color: dark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
            'Devam eden yolculuklarını ve ödeme bekleyen işlemleri buradan görebilirsin.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 16),

                if (docs.isEmpty)
                  _empty()
                else
                  ...docs.map((doc) {
                    final d = doc.data();

                    return _tripCard(
                      context: context,
                      tripId: doc.id,
                      from: (d['fromText'] ?? '-').toString(),
                      to: (d['toText'] ?? '-').toString(),
                      status: (d['status'] ?? '-').toString(),
                      price: d['price'],
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero(int count) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.local_taxi_rounded,
            color: turquoise,
            size: 42,
          ),

          const SizedBox(height: 14),

          const Text(
            'Yolculuk Merkezi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Şoför, rota ve ödeme sürecini anlık takip et.',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.route_rounded,
                  color: turquoise,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    '$count aktif yolculuk bulundu',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tripCard({
    required BuildContext context,
    required String tripId,
    required String from,
    required String to,
    required String status,
    required dynamic price,
  }) {
    final color = _statusColor(status);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TripTrackingPage(
              tripId: tripId,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: turquoise.withOpacity(.18),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withOpacity(.12),
                  child: Icon(
                    Icons.local_taxi_rounded,
                    color: color,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    _statusText(status),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _route(
              turquoise,
              'Kalkış',
              from,
            ),

            const SizedBox(height: 10),

            _route(
              dark,
              'Varış',
              to,
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: softBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.payments_rounded,
                    color: turquoise,
                  ),

                  const SizedBox(width: 10),

                  const Expanded(
                    child: Text(
                      'Tahmini Ücret',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  Text(
                    '₺${price ?? 0}',
                    style: const TextStyle(
                      color: dark,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TripTrackingPage(
                        tripId: tripId,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: dark,
                  foregroundColor: turquoise,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.map_rounded),
                label: const Text(
                  'Yolculuğu Aç',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _route(
      Color color,
      String title,
      String value,
      ) {
    return Row(
      children: [
        CircleAvatar(
          radius: 6,
          backgroundColor: color,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
              ),

              Text(
                value,
                style: const TextStyle(
                  color: dark,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.local_taxi_outlined,
            color: turquoise,
            size: 56,
          ),
          SizedBox(height: 12),
          Text(
            'Aktif yolculuk yok',
            style: TextStyle(
              color: dark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Yeni yolculuk başlatınca burada görünecek.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'queued':
        return Colors.orange;
      case 'assigned':
        return turquoise;
      case 'driver_arriving':
        return Colors.blue;
      case 'driver_arrived':
        return Colors.deepOrange;
      case 'started':
        return dark;
      case 'payment_pending':
        return Colors.green;
      default:
        return dark;
    }
  }

  String _statusText(String s) {
    switch (s) {
      case 'queued':
        return 'Sürücü Aranıyor';
      case 'assigned':
        return 'Sürücü Atandı';
      case 'driver_arriving':
        return 'Şoför Geliyor';
      case 'driver_arrived':
        return 'Şoför Geldi';
      case 'started':
        return 'Yolculuk Başladı';
      case 'payment_pending':
        return 'Ödeme Bekleniyor';
      default:
        return s;
    }
  }
}