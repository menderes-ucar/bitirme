import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ridedemo/services/auth_service.dart';

import '../trip_service.dart';

const kDemoSessionId = 'ridedemo';

class DriverPage extends StatefulWidget {
  final String driverId;

  const DriverPage({
    super.key,
    required this.driverId,
  });

  @override
  State<DriverPage> createState() => _DriverPageState();
}

class _DriverPageState extends State<DriverPage> {
  final _db = FirebaseFirestore.instance;
  final _service = TripService();

  bool isOnline = false;
  StreamSubscription<Position>? _positionSub;

  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);
  static const Color softBg = Color(0xFFF6FEFD);
  static const Color cardBorder = Color(0xFFE5F8F6);

  String _clean(dynamic v, String fallback) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  String _driverName(Map<String, dynamic>? d) {
    return _clean(d?['name'], 'Şoför');
  }

  String _customerName(Map<String, dynamic> d) {
    return _clean(d['customerName'], 'Müşteri');
  }

  String _driverVehicleText(Map<String, dynamic>? vehicle) {
    if (vehicle == null) return 'Araç bilgisi yok';

    final brand = _clean(vehicle['brand'], '');
    final model = _clean(vehicle['model'], '');
    final plate = _clean(vehicle['plate'], '');

    final text = '$brand $model ${plate.isEmpty ? '' : '• $plate'}'.trim();
    return text.isEmpty ? 'Araç bilgisi yok' : text;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':
        return turquoise;
      case 'driver_arriving':
        return const Color(0xFF2563EB);
      case 'driver_arrived':
        return const Color(0xFFF97316);
      case 'started':
        return dark;
      case 'payment_pending':
        return Colors.deepOrange;
      case 'paid':
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return Colors.red;
      case 'queued':
        return Colors.orange;
      default:
        return dark;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'assigned':
        return 'Yeni Yolculuk Talebi';
      case 'driver_arriving':
        return 'Yolcuya Gidiyorsun';
      case 'driver_arrived':
        return 'Yolcuya Ulaştın';
      case 'started':
        return 'Yolculuk Devam Ediyor';
      case 'payment_pending':
        return 'Ödeme Onayı Bekleniyor';
      case 'paid':
        return 'Ödeme Tamamlandı';
      case 'completed':
        return 'Yolculuk Tamamlandı';
      case 'cancelled':
        return 'Yolculuk İptal Edildi';
      case 'queued':
        return 'Yeni Yolculuk İsteği';
      default:
        return status;
    }
  }

  String _distanceText(dynamic distanceM) {
    if (distanceM is num) {
      if (distanceM >= 1000) {
        return '${(distanceM / 1000).toStringAsFixed(1)} km';
      }
      return '${distanceM.round()} m';
    }
    return '—';
  }

  Future<void> _toggleOnline() async {
    if (isOnline) {
      await _positionSub?.cancel();

      await _db.collection('drivers').doc(widget.driverId).set({
        'isOnline': false,
        'status': 'offline',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) setState(() => isOnline = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konum izni olmadan çevrimiçi olunamaz.'),
        ),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition();

    await _db.collection('drivers').doc(widget.driverId).set({
      'isOnline': true,
      'status': 'active',
      'location': {
        'lat': pos.latitude,
        'lng': pos.longitude,
      },
      'lastLocationAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) async {
      await _db.collection('drivers').doc(widget.driverId).set({
        'location': {
          'lat': pos.latitude,
          'lng': pos.longitude,
        },
        'lastLocationAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    if (mounted) setState(() => isOnline = true);
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripsStream = _db.collection('trips').snapshots();
    final driverStream =
    _db.collection('drivers').doc(widget.driverId).snapshots();

    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: driverStream,
          builder: (context, driverSnap) {
            final driverData = driverSnap.data?.data();
            final remoteOnline = driverData?['isOnline'] == true;
            final displayOnline = isOnline || remoteOnline;

            final profileName = _driverName(driverData);

            final vehicle =
            driverData?['vehicle'] as Map<String, dynamic>?;

            final vehicleText = _driverVehicleText(vehicle);
            final ratingAverage =
            (driverData?['ratingAverage'] ?? 0).toDouble();
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tripsStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Hata: ${snap.error}',
                      style: const TextStyle(
                        color: dark,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  );
                }

                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allDocs = snap.data!.docs;

                final activeDocs = allDocs.where((doc) {
                  final d = doc.data();
                  final status = (d['status'] ?? '').toString();
                  final tripDriverId = d['driverId']?.toString();

                  final rejectedBy = d['rejectedBy'];
                  final rejected = rejectedBy is Map && rejectedBy[widget.driverId] == true;

                  final isMyActiveTrip =
                      tripDriverId == widget.driverId &&
                          status != 'cancelled' &&
                          status != 'paid' &&
                          status != 'completed';

                  final isAvailableRequest =
                      displayOnline &&
                          status == 'queued' &&
                          tripDriverId == null &&
                          !rejected;

                  return isMyActiveTrip || isAvailableRequest;
                }).toList();

                activeDocs.sort((a, b) {
                  final at = a.data()['createdAt'];
                  final bt = b.data()['createdAt'];
                  final am = at is Timestamp ? at.millisecondsSinceEpoch : 0;
                  final bm = bt is Timestamp ? bt.millisecondsSinceEpoch : 0;
                  return bm.compareTo(am);
                });

                final completedCount = allDocs.where((doc) {
                  final s = (doc.data()['status'] ?? '').toString();
                  return s == 'completed' || s == 'paid';
                }).length;

                final activeTotal = activeDocs.fold<num>(0, (sum, doc) {
                  final p = doc.data()['price'];
                  return sum + (p is num ? p : 0);
                });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                  children: [
                    _premiumHeader(
                      name: profileName,
                      vehicle: vehicleText,
                      isOnline: displayOnline,
                      ratingAverage: ratingAverage,
                    ),
                    const SizedBox(height: 14),
                    _onlineCard(displayOnline),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _statCard(
                          icon: Icons.payments_rounded,
                          title: 'Aktif Kazanç',
                          value: '₺$activeTotal',
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          icon: Icons.route_rounded,
                          title: 'Aktif Trip',
                          value: '${activeDocs.length}',
                        ),
                        const SizedBox(width: 10),
                        _statCard(
                          icon: Icons.verified_rounded,
                          title: 'Tamamlanan',
                          value: '$completedCount',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Canlı Yolculuklar',
                      style: TextStyle(
                        color: dark,
                        fontSize: 24,
                        letterSpacing: -.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayOnline
                          ? 'Sana atanan yolculuklar burada yönetilir.'
                          : 'Çevrimiçi olmadığın sürece yeni yolculuk alamazsın.',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (activeDocs.isEmpty)
                      _empty(
                        icon: Icons.local_taxi_outlined,
                        title: 'Aktif yolculuk yok',
                        subtitle:
                        'Yeni bir müşteri talebi atandığında burada görünecek.',
                      )
                    else
                      ...activeDocs.map((doc) {
                        final d = doc.data();

                        return _tripCard(
                          tripId: doc.id,
                          status: (d['status'] ?? '').toString(),
                          from: (d['fromText'] ?? '').toString(),
                          to: (d['toText'] ?? '').toString(),
                          customerName: _customerName(d),
                          price: d['price'] ?? 0,
                          distanceM: d['distanceM'],
                        );
                      }),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _premiumHeader({
    required String name,
    required String vehicle,
    required bool isOnline,
    required double ratingAverage,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.24),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: turquoise,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: dark,
                  size: 42,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoş geldin',
                      style: TextStyle(
                        color: Colors.white.withOpacity(.62),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '⭐ ${ratingAverage.toStringAsFixed(1)}',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.dashboard_customize_rounded,
                        color: turquoise,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  GestureDetector(
                    onTap: () async {
                      await AuthService().signOut();
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: turquoise,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.08),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withOpacity(.10),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF16A34A) : Colors.red,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isOnline
                            ? const Color(0xFF16A34A)
                            : Colors.red)
                            .withOpacity(.45),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isOnline
                        ? 'Sistem seni aktif sürücü olarak görüyor.'
                        : 'Şu anda çevrimdışısın.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.shield_rounded,
                  color: turquoise,
                  size: 22,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineCard(bool displayOnline) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: displayOnline
              ? const Color(0xFF16A34A).withOpacity(.28)
              : Colors.red.withOpacity(.20),
        ),
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
            radius: 25,
            backgroundColor: displayOnline
                ? const Color(0xFF16A34A).withOpacity(.12)
                : Colors.red.withOpacity(.10),
            child: Icon(
              displayOnline
                  ? Icons.power_settings_new_rounded
                  : Icons.pause_circle_rounded,
              color: displayOnline ? const Color(0xFF16A34A) : Colors.red,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayOnline ? 'Çevrimiçi mod açık' : 'Çevrimdışı mod',
                  style: TextStyle(
                    color: displayOnline ? const Color(0xFF16A34A) : Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayOnline
                      ? 'Yeni yolculuklar sana atanabilir.'
                      : 'Yolculuk almak için çevrimiçi ol.',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: displayOnline,
            activeColor: turquoise,
            onChanged: (_) => _toggleOnline(),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cardBorder),
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
            Icon(icon, color: turquoise),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: dark,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripCard({
    required String tripId,
    required String status,
    required String from,
    required String to,
    required String customerName,
    required dynamic price,
    required dynamic distanceM,
  }) {
    final color = _statusColor(status);

    final canGoCustomer = status == 'assigned';
    final canAcceptOrReject = status == 'queued';
    final canArrived = status == 'driver_arriving';
    final canStartTrip = status == 'driver_arrived';
    final canFinishTrip = status == 'started';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: turquoise.withOpacity(.18)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(.12),
            blurRadius: 24,
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
                radius: 22,
                backgroundColor: color.withOpacity(.12),
                child: Icon(
                  Icons.local_taxi_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _statusText(status),
                      style: TextStyle(
                        color: color,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Yolcu: $customerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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
          _routeRow(
            color: turquoise,
            title: 'Alış Noktası',
            value: from,
          ),
          const SizedBox(height: 12),
          _routeRow(
            color: dark,
            title: 'Varış Noktası',
            value: to,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _infoCard(
                icon: Icons.route_outlined,
                title: 'Mesafe',
                value: _distanceText(distanceM),
              ),
              const SizedBox(width: 8),
              _infoCard(
                icon: Icons.payments_outlined,
                title: 'Ücret',
                value: '₺$price',
              ),
              const SizedBox(width: 8),
              _infoCard(
                icon: Icons.timer_outlined,
                title: 'Durum',
                value: _statusText(status),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (canAcceptOrReject)
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final ok = await _service.acceptTrip(
                          tripId: tripId,
                          driverId: widget.driverId,
                        );

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              ok
                                  ? 'Yolculuk kabul edildi.'
                                  : 'Bu yolculuk başka şoför tarafından alınmış.',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: turquoise,
                        foregroundColor: dark,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text(
                        'Kabul Et',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _service.rejectTrip(
                          tripId: tripId,
                          driverId: widget.driverId,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(.45)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: const Text(
                        'Reddet',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (canAcceptOrReject) const SizedBox(height: 12),
          if (canGoCustomer)
            _primaryActionButton(
              icon: Icons.navigation_rounded,
              label: 'Yolcuya Git',
              background: dark,
              foreground: turquoise,
              onTap: () async {
                await _service.updateTripStatus(
                  tripId,
                  'driver_arriving',
                );
              },
            ),
          if (canArrived)
            _primaryActionButton(
              icon: Icons.location_on_rounded,
              label: 'Yolcuya Ulaştım',
              background: turquoise,
              foreground: dark,
              onTap: () async {
                await _service.updateTripStatus(
                  tripId,
                  'driver_arrived',
                );
              },
            ),
          if (canStartTrip)
            _primaryActionButton(
              icon: Icons.play_arrow_rounded,
              label: 'Yolculuğu Başlat',
              background: dark,
              foreground: turquoise,
              onTap: () async {
                await _service.updateTripStatus(
                  tripId,
                  'started',
                );
              },
            ),
          if (canFinishTrip)
            _primaryActionButton(
              icon: Icons.flag_rounded,
              label: 'Yolculuğu Bitir',
              background: turquoise,
              foreground: dark,
              onTap: () async {
                await _service.updateTripStatus(
                  tripId,
                  'payment_pending',
                );
              },
            ),
          if (status == 'payment_pending') _paymentWaitingBox(),
        ],
      ),
    );
  }

  Widget _primaryActionButton({
    required IconData icon,
    required String label,
    required Color background,
    required Color foreground,
    required Future<void> Function() onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        icon: Icon(icon),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _paymentWaitingBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.deepOrange.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.deepOrange.withOpacity(.28),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            color: Colors.deepOrange,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Yolcunun ödeme onayı bekleniyor...',
              style: TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeRow({
    required Color color,
    required String title,
    required String value,
  }) {
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
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(
                  color: dark,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: dark,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: turquoise.withOpacity(.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 54, color: turquoise),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: dark,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}