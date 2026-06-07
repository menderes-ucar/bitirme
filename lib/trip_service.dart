import 'dart:math';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

const kDemoSessionId = 'ridedemo';

class TripService {
  final _db = FirebaseFirestore.instance;

  Future<int> _getPricePer100m() async {
    final doc = await _db.collection('settings').doc('pricing').get();
    final data = doc.data() ?? {};

    final v100 = data['pricePer100m'];
    if (v100 is num) return v100.round();

    final vKm = data['pricePerKm'];
    if (vKm is num) return (vKm / 10).round();

    return 10;
  }

  String _clean(dynamic v, String fallback) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? fallback : s;
  }

  Future<Map<String, dynamic>> _customerData(String customerId) async {
    final doc = await _db.collection('users').doc(customerId).get();
    final data = doc.data() ?? {};

    return {
      'customerName': _clean(data['name'], 'Müşteri'),
      'customerEmail': _clean(data['email'], ''),
    };
  }

  Future<Map<String, dynamic>> _driverData(String driverId) async {
    final doc = await _db.collection('drivers').doc(driverId).get();
    final data = doc.data() ?? {};

    return {
      'driverName': _clean(data['name'], 'Şoför'),
      'driverPhone': _clean(data['phone'], ''),
      'vehicle': data['vehicle'],
    };
  }

  Future<String> createTrip({
    required String customerId,
    required String fromText,
    required String toText,
    double? pickupLat,
    double? pickupLng,
  }) async {
    final tripRef = _db.collection('trips').doc();
    final rnd = Random();

    final customer = await _customerData(customerId);

    final safePickupLat = pickupLat ?? 38.7225;
    final safePickupLng = pickupLng ?? 35.4875;

    final distanceM = 300 + rnd.nextInt(2200);
    final pricePer100m = await _getPricePer100m();
    final price = ((distanceM / 100).ceil()) * pricePer100m;
    final distanceKm = double.parse((distanceM / 1000).toStringAsFixed(2));

    await tripRef.set({
      'demoSessionId': kDemoSessionId,

      'customerId': customerId,
      'customerName': customer['customerName'],
      'customerEmail': customer['customerEmail'],

      'driverId': null,
      'driverName': null,
      'driverPhone': null,
      'vehicle': null,

      'fromText': fromText,
      'toText': toText,
      'pickupLat': safePickupLat,
      'pickupLng': safePickupLng,
      'fromLat': safePickupLat,
      'fromLng': safePickupLng,

      'distanceM': distanceM,
      'distanceKm': distanceKm,
      'pricePer100m': pricePer100m,
      'price': price,
      'status': 'queued',
      'tip': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return tripRef.id;
  }

  Future<void> autoAssignTrip(String tripId) async {
    final tripRef = _db.collection('trips').doc(tripId);
    final tripSnap = await tripRef.get();

    if (!tripSnap.exists) return;

    final t = tripSnap.data()!;
    final status = (t['status'] ?? '').toString();

    if (status != 'queued') return;
    if (t['driverId'] != null) return;

    final pickupLat = (t['pickupLat'] as num?)?.toDouble() ??
        (t['fromLat'] as num?)?.toDouble() ??
        38.7225;

    final pickupLng = (t['pickupLng'] as num?)?.toDouble() ??
        (t['fromLng'] as num?)?.toDouble() ??
        35.4875;

    final driversQ = await _db
        .collection('drivers')
        .where('isOnline', isEqualTo: true)
        .get();

    QueryDocumentSnapshot<Map<String, dynamic>>? nearestDriver;
    double nearestDistanceKm = double.infinity;

    for (final doc in driversQ.docs) {
      final d = doc.data();

      final driverStatus = (d['status'] ?? '').toString();
      final isApproved = d['isApproved'] == true;

      if (!isApproved) continue;
      if (driverStatus == 'passive' ||
          driverStatus == 'offline' ||
          driverStatus == 'pending') {
        continue;
      }

      final location = d['location'] as Map<String, dynamic>?;

      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) continue;

      final distKm = _distanceBetweenKm(
        lat1: pickupLat,
        lng1: pickupLng,
        lat2: lat,
        lng2: lng,
      );

      if (distKm < nearestDistanceKm) {
        nearestDistanceKm = distKm;
        nearestDriver = doc;
      }
    }

    if (nearestDriver == null) {
      await tripRef.update({
        'assignError':
        'Online sürücü bulundu ama konum yok veya uygun sürücü yok',
        'assignCheckedAt': FieldValue.serverTimestamp(),
      });
      return;
    }

    final driver = await _driverData(nearestDriver.id);

    await tripRef.update({
      'driverId': nearestDriver.id,
      'driverName': driver['driverName'],
      'driverPhone': driver['driverPhone'],
      'vehicle': driver['vehicle'],

      'status': 'assigned',
      'assignedBy': 'system',
      'assignedAt': FieldValue.serverTimestamp(),
      'driverDistanceKm': double.parse(nearestDistanceKm.toStringAsFixed(2)),
      'assignError': null,
    });
  }

  double _deg2rad(double deg) {
    return deg * (math.pi / 180);
  }

  double _distanceBetweenKm({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    const earthRadius = 6371.0;

    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }
  Future<bool> acceptTrip({
    required String tripId,
    required String driverId,
  }) async {
    final tripRef = _db.collection('trips').doc(tripId);
    final driver = await _driverData(driverId);

    return _db.runTransaction<bool>((tx) async {
      final snap = await tx.get(tripRef);

      if (!snap.exists) return false;

      final data = snap.data() as Map<String, dynamic>;
      final status = (data['status'] ?? '').toString();
      final currentDriverId = data['driverId'];

      if (status != 'queued' || currentDriverId != null) {
        return false;
      }

      tx.update(tripRef, {
        'driverId': driverId,
        'driverName': driver['driverName'],
        'driverPhone': driver['driverPhone'],
        'vehicle': driver['vehicle'],
        'status': 'assigned',
        'assignedBy': 'driver',
        'acceptedAt': FieldValue.serverTimestamp(),
        'assignedAt': FieldValue.serverTimestamp(),
      });

      return true;
    });
  }

  Future<void> rejectTrip({
    required String tripId,
    required String driverId,
  }) async {
    await _db.collection('trips').doc(tripId).set({
      'rejectedBy': {
        driverId: true,
      },
      'lastRejectedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> assignTrip({
    required String tripId,
    required String driverId,
  }) async {
    final tripRef = _db.collection('trips').doc(tripId);
    final driver = await _driverData(driverId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(tripRef);
      if (!snap.exists) return;

      final d = snap.data() as Map<String, dynamic>;
      final status = (d['status'] ?? '').toString();
      final currentDriver = d['driverId'];

      if (status == 'queued' && currentDriver == null) {
        tx.update(tripRef, {
          'driverId': driverId,
          'driverName': driver['driverName'],
          'driverPhone': driver['driverPhone'],
          'vehicle': driver['vehicle'],

          'status': 'assigned',
          'assignedBy': 'admin',
          'assignedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> reassignTrip({
    required String tripId,
    required String newDriverId,
  }) async {
    final driver = await _driverData(newDriverId);

    await _db.collection('trips').doc(tripId).update({
      'driverId': newDriverId,
      'driverName': driver['driverName'],
      'driverPhone': driver['driverPhone'],
      'vehicle': driver['vehicle'],

      'status': 'assigned',
      'assignedBy': 'admin',
      'reassignedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelTrip(String tripId) async {
    await _db.collection('trips').doc(tripId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateTripStatus(String tripId, String status) async {
    await _db.collection('trips').doc(tripId).update({
      'status': status,

      if (status == 'driver_arriving')
        'driverArrivingAt': FieldValue.serverTimestamp(),

      if (status == 'driver_arrived')
        'driverArrivedAt': FieldValue.serverTimestamp(),

      if (status == 'started') 'startedAt': FieldValue.serverTimestamp(),

      if (status == 'payment_pending')
        'paymentPendingAt': FieldValue.serverTimestamp(),

      if (status == 'paid') 'paidAt': FieldValue.serverTimestamp(),

      if (status == 'completed') 'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setTip({
    required String tripId,
    required int tip,
  }) async {
    await _db.collection('trips').doc(tripId).update({
      'tip': tip,
      'tipUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPaid(String tripId) async {
    await _db.collection('trips').doc(tripId).update({
      'paymentStatus': 'paid',
      'paidAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> sendAdminMessage({
    required String tripId,
    required String customerId,
    required String message,
  }) async {
    final customer = await _customerData(customerId);

    await _db.collection('support_messages').add({
      'tripId': tripId,
      'customerId': customerId,
      'customerName': customer['customerName'],
      'customerEmail': customer['customerEmail'],
      'message': message.trim(),
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> submitDriverReport({
    required String tripId,
    required String customerId,
    required String driverId,
    required String driverName,
    required String category,
    required String message,
  }) async {
    final customer = await _customerData(customerId);

    await _db.collection('driver_reports').add({
      'tripId': tripId,

      'customerId': customerId,
      'customerName': customer['customerName'],

      'driverId': driverId,
      'driverName': driverName,

      'category': category,
      'message': message.trim(),

      'status': 'open',

      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  Future<void> submitDriverRating({
    required String tripId,
    required String driverId,
    required int rating,
    String note = '',
  }) async {
    await _db.collection('trips').doc(tripId).update({
      'driverRating': rating,
      'driverRatingNote': note,
      'ratedAt': FieldValue.serverTimestamp(),
    });

    final driverRef = _db.collection('drivers').doc(driverId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(driverRef);

      final data = snap.data() ?? {};

      final total = (data['ratingTotal'] ?? 0) as num;
      final count = (data['ratingCount'] ?? 0) as num;

      final newTotal = total + rating;
      final newCount = count + 1;

      tx.set(driverRef, {
        'ratingTotal': newTotal,
        'ratingCount': newCount,
        'ratingAverage': newTotal / newCount,
      }, SetOptions(merge: true));
    });
  }
  Future<void> completeDemoPayment({
    required String tripId,
    required int fareAmount,
    required int tip,
  }) async {
    final totalPaid = fareAmount + tip;

    await _db.collection('trips').doc(tripId).update({
      'tip': tip,
      'fareAmount': fareAmount,
      'totalPaid': totalPaid,
      'paymentMethod': 'demo',
      'paymentStatus': 'paid',
      'status': 'completed',
      'paidAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}