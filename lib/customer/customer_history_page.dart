import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerHistoryPage extends StatelessWidget {
  final String customerId;

  const CustomerHistoryPage({
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
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs.where((doc) {
              final s = (doc.data()['status'] ?? '').toString();
              return s == 'completed' ||
                  s == 'paid' ||
                  s == 'cancelled';
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

            final totalSpent = docs.fold<num>(0, (sum, doc) {
              final p = doc.data()['price'];
              return sum + (p is num ? p : 0);
            });

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _header(
                  totalTrips: docs.length,
                  totalSpent: totalSpent,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Geçmiş Yolculuklar',
                  style: TextStyle(
                    color: dark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tamamlanan ve iptal edilen tüm sürüşlerin burada listelenir.',
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

                    return _historyCard(
                      from: (d['fromText'] ?? '-').toString(),
                      to: (d['toText'] ?? '-').toString(),
                      status: (d['status'] ?? '-').toString(),
                      price: d['price'],
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
    required num totalSpent,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yolculuk Geçmişi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Önceki yolculuk ve harcama özeti',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _summaryBox(
                Icons.route_rounded,
                'Toplam',
                '$totalTrips',
              ),
              const SizedBox(width: 10),
              _summaryBox(
                Icons.payments_rounded,
                'Harcama',
                '₺$totalSpent',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(
      IconData icon,
      String title,
      String value,
      ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          children: [
            Icon(icon, color: turquoise),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white60,
                fontWeight: FontWeight.w700,
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
    required dynamic createdAt,
  }) {
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
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: turquoise.withOpacity(.12),
                child: const Icon(
                  Icons.history_rounded,
                  color: turquoise,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _statusText(status),
                  style: const TextStyle(
                    color: dark,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ),
              Text(
                dateText,
                style: const TextStyle(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _route('Kalkış', from, turquoise),
          const SizedBox(height: 10),
          _route('Varış', to, dark),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.payments_rounded, color: turquoise),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Toplam Ücret',
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
                    fontSize: 17,
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

  Widget _route(
      String title,
      String value,
      Color color,
      ) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
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
          Icon(Icons.history_rounded, size: 56, color: turquoise),
          SizedBox(height: 12),
          Text(
            'Geçmiş yolculuk yok',
            style: TextStyle(
              color: dark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(String s) {
    switch (s) {
      case 'completed':
        return 'Tamamlandı';
      case 'paid':
        return 'Ödendi';
      case 'cancelled':
        return 'İptal Edildi';
      default:
        return s;
    }
  }
}