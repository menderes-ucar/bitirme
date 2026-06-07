import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../driver/driver_manage_page.dart';
import '../trip_service.dart';

const kDemoSessionId = 'ridedemo';

const Color kTurquoise = Color(0xFF40E0D0);
const Color kDark = Color(0xFF050505);
const Color kSoftBg = Color(0xFFF6FEFD);

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _db = FirebaseFirestore.instance;
  final _service = TripService();

  int tab = 0;

  String _statusText(String s) {
    switch (s) {
      case 'queued':
        return 'Sırada';
      case 'assigned':
        return 'Atandı';
      case 'driver_arriving':
        return 'Şoför geliyor';
      case 'started':
        return 'Başladı';
      case 'completed':
        return 'Bitti';
      case 'paid':
        return 'Ödendi';
      case 'cancelled':
        return 'İptal';
      default:
        return s;
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'queued':
        return kTurquoise;
      case 'assigned':
      case 'driver_arriving':
        return kDark;
      case 'started':
        return const Color(0xFF2563EB);
      case 'completed':
      case 'paid':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return Colors.red;
      default:
        return kDark;
    }
  }

  bool _matchTab(String status) {
    if (tab == 0) return status == 'queued';
    if (tab == 1) {
      return status == 'assigned' ||
          status == 'driver_arriving' ||
          status == 'started';
    }
    if (tab == 2) return status == 'completed';
    if (tab == 3) return status == 'paid';
    if (tab == 4) return status == 'cancelled';
    if (tab == 5) return false;
    if (tab == 6) return false;
    return true;
  }

  int _createdAtMs(Map<String, dynamic> d) {
    final ts = d['createdAt'];
    if (ts is Timestamp) return ts.millisecondsSinceEpoch;
    return 0;
  }

  String _driverName(String? id) {
    if (id == null || id.isEmpty) return 'Atanmadı';
    if (id == 'driverA') return 'Elif Kaya';
    if (id == 'driverB') return 'Zeynep Aydın';
    return id;
  }

  String _formatDistance(dynamic meters) {
    if (meters is num) {
      if (meters >= 1000) {
        return '${(meters / 1000).toStringAsFixed(1)} km';
      }
      return '${meters.round()} m';
    }
    return '—';
  }

  Future<void> _openPricingSheet() async {
    final ref = _db.collection('settings').doc('pricing');
    final snap = await ref.get();
    final current = snap.data()?['pricePer100m'] ?? 10;
    final c = TextEditingController(text: current.toString());

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tarife Belirle',
                  style: TextStyle(
                    color: kDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '100 metre başına ücret. Yeni talepler buna göre hesaplanır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: c,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '₺ / 100m',
                    filled: true,
                    fillColor: kSoftBg,
                    prefixIcon: const Icon(Icons.price_change_rounded, color: kDark),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(color: kTurquoise.withOpacity(.25)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: kTurquoise, width: 1.6),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDark,
                      foregroundColor: kTurquoise,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () async {
                      final v = int.tryParse(c.text.trim()) ?? 10;

                      await ref.set({
                        'pricePer100m': v,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      if (!context.mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tarife güncellendi: $v ₺/100m')),
                      );
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'Kaydet',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<List<_DriverPickItem>> _loadDrivers(
      Map<String, dynamic> trip,
      ) async {
    final fromLat = (trip['pickupLat'] as num?)?.toDouble();
    final fromLng = (trip['pickupLng'] as num?)?.toDouble();

    // TÜM DRIVERLARI ÇEK
    final snap = await _db.collection('drivers').get();

    final items = <_DriverPickItem>[];

    for (final doc in snap.docs) {
      final data = doc.data();

      final status = (data['status'] ?? 'active').toString();
      final isOnline = data['isOnline'] == true;

// pasif / offline sürücüleri gösterme
      if (status == 'passive' || status == 'offline' || !isOnline) continue;

      final name = (data['name'] ?? doc.id).toString();

      final loc =
      (data['location'] as Map<String, dynamic>?);

      final dLat = (loc?['lat'] as num?)?.toDouble();
      final dLng = (loc?['lng'] as num?)?.toDouble();

      double? distM;

      // konum varsa gerçek mesafe hesapla
      if (fromLat != null &&
          fromLng != null &&
          dLat != null &&
          dLng != null) {
        distM = _haversineMeters(
          fromLat,
          fromLng,
          dLat,
          dLng,
        );
      }

      items.add(
        _DriverPickItem(
          id: doc.id,
          name: name,
          distM: distM,
        ),
      );
    }

    // mesafeye göre sırala
    items.sort((a, b) {
      final da = a.distM ?? 9999999;
      final db = b.distM ?? 9999999;
      return da.compareTo(db);
    });

    return items;
  }
  double _haversineMeters(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const double earthRadius = 6371000;

    double toRad(double degree) {
      return degree * pi / 180;
    }

    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(toRad(lat1)) *
                cos(toRad(lat2)) *
                sin(dLon / 2) *
                sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }
  Future<void> _pickAndAssign({
    required String tripId,
    required Map<String, dynamic> trip,
    required bool reassign,
  }) async {
    final drivers = await _loadDrivers(trip);

    if (!mounted) return;

    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reassign ? 'Şoför Değiştir' : 'Şoför Ata',
                  style: const TextStyle(
                    color: kDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in drivers)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: kSoftBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: kTurquoise.withOpacity(.20)),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: kDark,
                        child: Icon(
                          Icons.person_rounded,
                          color: kTurquoise,
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          color: kDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      subtitle: Text(item.id),
                      trailing: Text(
                        item.distM == null
                            ? '—'
                            : item.distM! >= 1000
                            ? '${(item.distM! / 1000).toStringAsFixed(1)} km'
                            : '${item.distM!.round()} m',
                        style: const TextStyle(
                          color: kDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      onTap: () => Navigator.pop(context, item.id),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null) return;

    if (reassign) {
      await _service.reassignTrip(tripId: tripId, newDriverId: selected);
    } else {
      await _service.assignTrip(tripId: tripId, driverId: selected);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Şoför atandı: ${_driverName(selected)}')),
    );
  }

  Widget _tabBtn(String text, int i) {
    final selected = tab == i;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => tab = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kDark : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? kTurquoise : Colors.black54,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kTurquoise.withOpacity(.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String title, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: kDark,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kTurquoise.withOpacity(.22)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            color: kTurquoise,
            size: 48,
          ),
          SizedBox(height: 10),
          Text(
            'Kayıt yok',
            style: TextStyle(
              color: kDark,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Bu sekmede gösterilecek yolculuk bulunamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _db
        .collection('trips')
        .where('demoSessionId', isEqualTo: kDemoSessionId)
        .snapshots();

    return Scaffold(
      backgroundColor: kSoftBg,
      appBar: AppBar(
        title: const Text(
          'Admin Paneli',
          style: TextStyle(
            color: kDark,
            fontWeight: FontWeight.w900,
          ),
        ),
        centerTitle: true,

        actions: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.dashboard_customize_rounded,
              color: kDark,
            ),
            tooltip: 'Demo Menü',
          ),

          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            icon: const Icon(
              Icons.logout_rounded,
              color: kDark,
            ),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text("Hata: ${snap.error}"));
            }

            final docs = snap.data?.docs.toList() ?? [];

            docs.sort((a, b) {
              return _createdAtMs(b.data()).compareTo(_createdAtMs(a.data()));
            });

            final queued = docs.where((x) => x.data()['status'] == 'queued').length;
            final active = docs.where((x) {
              final s = x.data()['status'];
              return s == 'assigned' || s == 'driver_arriving' || s == 'started';
            }).length;
            final completed = docs.where((x) => x.data()['status'] == 'completed').length;

            final filtered = docs.where((x) {
              final s = (x.data()['status'] ?? '').toString();
              return _matchTab(s);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: kDark,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.20),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Canlı Operasyon Merkezi',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kadın yolcu ve kadın sürücü yolculuklarını yönetin.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _topAction(
                            icon: Icons.people_alt_rounded,
                            title: 'Sürücüler',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DriverManagePage(),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          _topAction(
                            icon: Icons.price_change_rounded,
                            title: 'Tarife',
                            onTap: _openPricingSheet,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    _statCard(
                      'Sırada',
                      '$queued',
                      Icons.schedule_rounded,
                      kTurquoise,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Aktif',
                      '$active',
                      Icons.local_taxi_rounded,
                      kDark,
                    ),
                    const SizedBox(width: 10),
                    _statCard(
                      'Biten',
                      '$completed',
                      Icons.verified_rounded,
                      const Color(0xFF16A34A),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: kTurquoise.withOpacity(.18)),
                  ),
                  child: Row(
                    children: [
                      _tabBtn('Sıra', 0),
                      _tabBtn('Aktif', 1),
                      _tabBtn('Bitti', 2),
                      _tabBtn('Ödendi', 3),
                      _tabBtn('İptal', 4),
                      _tabBtn('Başvurular', 5),
                      _tabBtn('Raporlar', 6),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (!snap.hasData)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (tab == 5)
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _db
                        .collection('users')
                        .where('role', isEqualTo: 'customer')
                        .where('approvalStatus', isEqualTo: 'pending')
                        .snapshots(),
                    builder: (context, customerSnap) {
                      if (!customerSnap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 30),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final customers = customerSnap.data!.docs;

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: _db
                            .collection('driver_applications')
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, driverSnap) {
                          if (!driverSnap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 30),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }

                          final drivers = driverSnap.data!.docs;

                          if (customers.isEmpty && drivers.isEmpty) {
                            return _empty();
                          }

                          return Column(
                            children: [
                              ...customers.map((e) => _customerApplicationCard(e)),
                              ...drivers.map((e) => _applicationCard(e)),
                            ],
                          );
                        },
                      );
                    },
                  )
                else if (tab == 6)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _db
                          .collection('driver_reports')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, reportSnap) {
                        if (!reportSnap.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final reports = reportSnap.data!.docs;

                        if (reports.isEmpty) {
                          return _empty();
                        }

                        return Column(
                          children: reports.map((doc) {
                            final d = doc.data();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: kTurquoise.withOpacity(.20),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['driverName'] ?? 'Şoför',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    'Kategori: ${d['category'] ?? '-'}',
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    d['message'] ?? '',
                                  ),

                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await doc.reference.update({
                                              'status': 'reviewed',
                                            });
                                          },
                                          child: const Text('İncelendi'),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            await doc.reference.update({
                                              'status': 'resolved',
                                            });
                                          },
                                          child: const Text('Çözüldü'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    )
                else if (filtered.isEmpty)
                    _empty()
                else
                  ...filtered.map((doc) {
                    final d = doc.data();
                    final tripId = doc.id;

                    final from = (d['fromText'] ?? '').toString();
                    final to = (d['toText'] ?? '').toString();
                    final customerId = (d['customerId'] ?? '').toString();
                    final driverId = d['driverId']?.toString();
                    final status = (d['status'] ?? '').toString();

                    final price = d['price'];
                    final tip = d['tip'];
                    final total = (price is num ? price : 0) + (tip is num ? tip : 0);

                    final canAssign = status == 'queued';
                    final canReassign = status == 'assigned' || status == 'driver_arriving';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: kTurquoise.withOpacity(.22)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.05),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$from → $to',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: kDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(.10),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _statusColor(status).withOpacity(.18),
                                  ),
                                ),
                                child: Text(
                                  _statusText(status),
                                  style: TextStyle(
                                    color: _statusColor(status),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          _kv('Talep No', tripId),
                          _kv('Yolcu', customerId),
                          _kv('Şoför', _driverName(driverId)),

                          _kv(
                            'Puan',
                            d['driverRating'] == null
                                ? 'Puanlanmadı'
                                : '⭐ ${d['driverRating']}',
                          ),

                          _kv('Mesafe', _formatDistance(d['distanceM'])),
                          _kv('Toplam', '₺$total', bold: true),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: !canAssign
                                      ? null
                                      : () => _pickAndAssign(
                                    tripId: tripId,
                                    trip: d,
                                    reassign: false,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kDark,
                                    side: BorderSide(color: kTurquoise.withOpacity(.55)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.person_add_alt_1),
                                  label: const Text('Ata'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: !canReassign
                                      ? null
                                      : () => _pickAndAssign(
                                    tripId: tripId,
                                    trip: d,
                                    reassign: true,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kDark,
                                    side: BorderSide(color: kTurquoise.withOpacity(.55)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.swap_horiz_rounded),
                                  label: const Text('Değiştir'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: status == 'cancelled' ||
                                      status == 'completed' ||
                                      status == 'paid'
                                      ? null
                                      : () => _service.cancelTrip(tripId),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: BorderSide(color: Colors.red.withOpacity(.35)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(Icons.close_rounded),
                                  label: const Text('İptal'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: kTurquoise.withOpacity(.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kTurquoise.withOpacity(.30)),
          ),
          child: Column(
            children: [
              Icon(icon, color: kTurquoise),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  color: kTurquoise,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _applicationCard(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final d = doc.data();

    final name = (d['name'] ?? '').toString();
    final city = (d['city'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();
    final imageUrl = (d['idCardImageUrl'] ?? '').toString();

    final age = d['age'];
    final exp = d['experienceYear'];

    final genderCheck =
    (d['genderCheckStatus'] ?? '').toString();

    final vehicle =
    d['vehicle'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: kTurquoise.withOpacity(.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.network(
              imageUrl,
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            name,
            style: const TextStyle(
              color: kDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 10),

          _kv('Şehir', city),
          _kv('Telefon', phone),
          _kv('Yaş', '$age'),
          _kv('Tecrübe', '$exp yıl'),

          _kv(
            'Araç',
            '${vehicle?['brand'] ?? ''} ${vehicle?['model'] ?? ''}',
          ),

          _kv(
            'Plaka',
            '${vehicle?['plate'] ?? ''}',
          ),

          _kv(
            'OCR Kontrol',
            genderCheck == 'passed'
                ? 'Kadın doğrulandı'
                : 'Manuel kontrol gerekli',
            bold: true,
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _db.collection('users').doc(doc.id).set({
                      'isApproved': true,
                      'approvalStatus': 'approved',
                      'approvedAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    await _db
                        .collection('drivers')
                        .doc(doc.id)
                        .set({
                      'isApproved': true,
                      'status': 'active',
                      'isOnline': false,
                    }, SetOptions(merge: true));

                    await doc.reference.update({
                      'status': 'approved',
                    });

                    if (!mounted) return;

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Şoför onaylandı',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Onayla'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await doc.reference.update({
                      'status': 'rejected',
                    });

                    if (!mounted) return;

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Başvuru reddedildi',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Reddet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _customerApplicationCard(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final d = doc.data();

    final name = (d['name'] ?? '').toString();
    final email = (d['email'] ?? '').toString();
    final imageUrl = (d['customerPhotoUrl'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: kTurquoise.withOpacity(.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kadın Yolcu Başvurusu',
            style: TextStyle(
              color: kDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 14),

          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.network(
                imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 160,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kSoftBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'Fotoğraf yok',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),

          const SizedBox(height: 14),

          _kv('Ad', name),
          _kv('E-posta', email),
          _kv('Durum', 'Admin onayı bekliyor', bold: true),

          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await _db.collection('users').doc(doc.id).set({
                      'isApproved': true,
                      'approvalStatus': 'approved',
                      'approvedAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    }, SetOptions(merge: true));

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kadın yolcu onaylandı'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('Onayla'),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await doc.reference.update({
                      'isApproved': false,
                      'approvalStatus': 'rejected',
                      'rejectedAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                    if (!mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kadın yolcu reddedildi'),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('Reddet'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DriverPickItem {
  final String id;
  final String name;
  final double? distM;

  _DriverPickItem({
    required this.id,
    required this.name,
    required this.distM,
  });
}