import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'trip_service.dart';

class TripTrackingPage extends StatelessWidget {
  final String tripId;

  const TripTrackingPage({
    super.key,
    required this.tripId,
  });
  Future<void> _openDriverReportSheet({
    required BuildContext context,
    required String tripId,
    required String customerId,
    required String driverId,
    required String driverName,
  }) async {
    final controller = TextEditingController();

    String category = 'Geç kaldı';

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Şoförü Raporla',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: category,
                      items: const [
                        DropdownMenuItem(
                          value: 'Geç kaldı',
                          child: Text('Geç kaldı'),
                        ),
                        DropdownMenuItem(
                          value: 'Kaba davrandı',
                          child: Text('Kaba davrandı'),
                        ),
                        DropdownMenuItem(
                          value: 'Araç temiz değildi',
                          child: Text('Araç temiz değildi'),
                        ),
                        DropdownMenuItem(
                          value: 'Tehlikeli sürüş',
                          child: Text('Tehlikeli sürüş'),
                        ),
                        DropdownMenuItem(
                          value: 'Yanlış rota',
                          child: Text('Yanlış rota'),
                        ),
                        DropdownMenuItem(
                          value: 'Diğer',
                          child: Text('Diğer'),
                        ),
                      ],
                      onChanged: (v) {
                        setState(() {
                          category = v ?? 'Diğer';
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: controller,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Açıklamanızı yazın...',
                      ),
                    ),

                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final text = controller.text.trim();

                          if (text.isEmpty) return;

                          await TripService().submitDriverReport(
                            tripId: tripId,
                            customerId: customerId,
                            driverId: driverId,
                            driverName: driverName,
                            category: category,
                            message: text,
                          );

                          if (!context.mounted) return;

                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Rapor admin paneline gönderildi.',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.warning_rounded),
                        label: const Text('Rapor Gönder'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);
  static const Color softBg = Color(0xFFF6FEFD);

  static const LatLng fallbackLocation = LatLng(38.7225, 35.4875);
  static Widget _paymentInfo(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: softBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: turquoise.withOpacity(.18),
        ),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: dark,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _tipButton({
    required int value,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          height: 48,
          decoration: BoxDecoration(
            color: selected ? turquoise : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? turquoise
                  : turquoise.withOpacity(.18),
            ),
          ),
          child: Center(
            child: Text(
              '₺$value',
              style: TextStyle(
                color: selected ? dark : dark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final service = TripService();

    return Scaffold(
      backgroundColor: softBg,
      appBar: AppBar(
        title: const Text(
          "Yolculuk Takibi",
          style: TextStyle(color: dark, fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .doc(tripId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Hata: ${snap.error}"));
          }

          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }

          final d = snap.data!.data()!;

          final from = (d['fromText'] ?? 'Kalkış noktası').toString();
          final to = (d['toText'] ?? 'Varış noktası').toString();
          final status = (d['status'] ?? 'queued').toString();
          final price = (d['price'] ?? 0).toString();
          final driverId = d['driverId']?.toString();
          final driverName =
          (d['driverName'] ?? 'Şoför').toString();
          final customerId = (d['customerId'] ?? 'customer1').toString();

          final pickupLat = (d['pickupLat'] as num?)?.toDouble();
          final pickupLng = (d['pickupLng'] as num?)?.toDouble();

          final pickup = pickupLat != null && pickupLng != null
              ? LatLng(pickupLat, pickupLng)
              : fallbackLocation;

          final distanceM = d['distanceM'];
          final distanceText = distanceM is num
              ? distanceM >= 1000
              ? "${(distanceM / 1000).toStringAsFixed(1)} km"
              : "${distanceM.round()} m"
              : "Hesaplanıyor";

          final isClosed =
              status == 'completed' || status == 'paid' || status == 'cancelled';
          int selectedTip = d['tip'] is num ? (d['tip'] as num).toInt() : 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _driverCard(driverId),
              const SizedBox(height: 12),
              _mapCard(pickup: pickup, driverId: driverId),
              const SizedBox(height: 12),
              _tripInfoCard(
                status: status,
                from: from,
                to: to,
                distanceText: distanceText,
                price: price,
              ),
              const SizedBox(height: 12),
              _supportInfoCard(),

              if (status == 'payment_pending') ...[
                const SizedBox(height: 14),

                StatefulBuilder(
                  builder: (context, setModalState) {

                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: turquoise.withOpacity(.20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.06),
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
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  color: turquoise.withOpacity(.12),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Icon(
                                  Icons.payments_rounded,
                                  color: turquoise,
                                  size: 30,
                                ),
                              ),

                              const SizedBox(width: 14),

                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ödeme Ekranı',
                                      style: TextStyle(
                                        color: dark,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Yolculuk tamamlandı. Ödemeyi onaylayabilirsiniz.',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: _paymentInfo(
                                  'Yolculuk',
                                  '₺$price',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _paymentInfo(
                                  'Bahşiş',
                                  '₺$selectedTip',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          const Text(
                            'Bahşiş Ekle',
                            style: TextStyle(
                              color: dark,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              _tipButton(
                                value: 0,
                                selected: selectedTip == 0,
                                onTap: () {
                                  setModalState(() {
                                    selectedTip = 0;
                                  });
                                },
                              ),
                              _tipButton(
                                value: 50,
                                selected: selectedTip == 50,
                                onTap: () {
                                  setModalState(() {
                                    selectedTip = 50;
                                  });
                                },
                              ),
                              _tipButton(
                                value: 100,
                                selected: selectedTip == 100,
                                onTap: () {
                                  setModalState(() {
                                    selectedTip = 100;
                                  });
                                },
                              ),
                              _tipButton(
                                value: 200,
                                selected: selectedTip == 200,
                                onTap: () {
                                  setModalState(() {
                                    selectedTip = 200;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          TextField(
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Özel bahşiş tutarı',
                              prefixIcon: const Icon(Icons.edit_rounded),
                              filled: true,
                              fillColor: softBg,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onChanged: (v) {
                              setModalState(() {
                                selectedTip = int.tryParse(v.trim()) ?? 0;
                              });
                            },
                          ),
                          const SizedBox(height: 22),

                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: dark,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Toplam Ödeme',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 6),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₺${(num.tryParse(price.toString()) ?? 0) + selectedTip}',
                                  style: const TextStyle(
                                    color: turquoise,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final fareAmount = int.tryParse(price.toString()) ?? 0;

                                final currentDriverId = driverId;

                                if (currentDriverId != null && currentDriverId.isNotEmpty) {
                                  await _showRatingDialog(
                                    context: context,
                                    tripId: tripId,
                                    driverId: currentDriverId,
                                  );
                                }

                                if (!context.mounted) return;

                                await service.completeDemoPayment(
                                  tripId: tripId,
                                  fareAmount: fareAmount,
                                  tip: selectedTip,
                                );
                                if (!context.mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: dark,
                                    content: Text(
                                      'Ödeme tamamlandı • ₺$selectedTip bahşiş bırakıldı',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: turquoise,
                                foregroundColor: dark,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              icon: const Icon(Icons.check_circle_rounded),
                              label: const Text(
                                'Ödemeyi Tamamla',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isClosed
                          ? null
                          : () async {
                        final ok = await _confirmCancel(context);
                        if (ok != true) return;

                        await service.cancelTrip(tripId);

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Yolculuk iptal edildi."),
                          ),
                        );

                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text("İptal Et"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(color: Colors.red.withOpacity(.45)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (driverId == null || driverId.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Henüz şoför atanmadı.'),
                            ),
                          );
                          return;
                        }

                        await _openDriverReportSheet(
                          context: context,
                          tripId: tripId,
                          customerId: customerId,
                          driverId: driverId,
                          driverName: driverName,
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text("Şoförü Raporla"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dark,
                        foregroundColor: turquoise,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _mapCard({
    required LatLng pickup,
    required String? driverId,
  }) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: driverId == null
          ? null
          : FirebaseFirestore.instance.collection('drivers').doc(driverId).get(),
      builder: (context, snap) {
        LatLng? driverLocation;

        final data = snap.data?.data();
        final loc = data?['location'] as Map<String, dynamic>?;

        final dLat = (loc?['lat'] as num?)?.toDouble();
        final dLng = (loc?['lng'] as num?)?.toDouble();

        if (dLat != null && dLng != null) {
          driverLocation = LatLng(dLat, dLng);
        }

        final markers = <Marker>{
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickup,
            infoWindow: const InfoWindow(title: 'Kalkış noktası'),
          ),
          if (driverLocation != null)
            Marker(
              markerId: const MarkerId('driver'),
              position: driverLocation,
              infoWindow: const InfoWindow(title: 'Sürücü'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
        };

        return Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: turquoise.withOpacity(.20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: driverLocation ?? pickup,
              zoom: 14,
            ),
            markers: markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
          ),
        );
      },
    );
  }

  Widget _tripInfoCard({
    required String status,
    required String from,
    required String to,
    required String distanceText,
    required String price,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _statusTitle(status),
            style: TextStyle(
              color: _statusColor(status),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _step(
                Icons.search_rounded,
                "Sürücü\nAranıyor",
                true,
              ),

              _line(status != 'queued'),

              _step(
                Icons.local_taxi_rounded,
                "Sürücü\nAtandı",
                status != 'queued',
              ),

              _line(
                status == 'driver_arriving' ||
                    status == 'driver_arrived' ||
                    status == 'started' ||
                    status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _step(
                Icons.navigation_rounded,
                "Sürücü\nGeliyor",
                status == 'driver_arriving' ||
                    status == 'driver_arrived' ||
                    status == 'started' ||
                    status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _line(
                status == 'driver_arrived' ||
                    status == 'started' ||
                    status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _step(
                Icons.location_on_rounded,
                "Size\nUlaştı",
                status == 'driver_arrived' ||
                    status == 'started' ||
                    status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _line(
                status == 'started' ||
                    status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _step(
                Icons.directions_car_rounded,
                "Yolculuk\nBaşladı",
                status == 'started' ||
                    status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _line(
                status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _step(
                Icons.payments_rounded,
                "Ödeme\nBekleniyor",
                status == 'payment_pending' ||
                    status == 'paid' ||
                    status == 'completed',
              ),

              _line(
                status == 'paid' ||
                    status == 'completed',
              ),

              _step(
                Icons.check_circle_rounded,
                "Tamamlandı",
                status == 'paid' ||
                    status == 'completed',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _smallInfo("Mesafe", distanceText),
              _smallInfo("Ücret", "₺$price"),
              _smallInfo("Durum", _statusShort(status)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _supportInfoCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: turquoise.withOpacity(.22)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: turquoise,
            child: Icon(Icons.support_agent_rounded, color: dark),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Şoförle ilgili bir sorun yaşarsanız rapor oluşturabilirsiniz.",
              style: TextStyle(color: dark, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
  Future<void> _showRatingDialog({
    required BuildContext context,
    required String tripId,
    required String driverId,
  }) async {
    int rating = 5;
    final note = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Şoförü Puanla'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                          (i) => IconButton(
                        icon: Icon(
                          i < rating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                        onPressed: () {
                          setState(() {
                            rating = i + 1;
                          });
                        },
                      ),
                    ),
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(
                      hintText: 'Yorum (isteğe bağlı)',
                    ),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    await TripService().submitDriverRating(
                      tripId: tripId,
                      driverId: driverId,
                      rating: rating,
                      note: note.text.trim(),
                    );

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  Future<bool?> _confirmCancel(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Yolculuk iptal edilsin mi?"),
        content: const Text("Bu işlemden sonra yolculuk iptal edilecek."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Vazgeç"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("İptal Et"),
          ),
        ],
      ),
    );
  }

  Future<void> _openAdminMessageSheet({
    required BuildContext context,
    required String tripId,
    required String customerId,
  }) async {
    final controller = TextEditingController();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              10,
              18,
              MediaQuery.of(context).viewInsets.bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Admin'e Mesaj Gönder",
                  style: TextStyle(
                    color: dark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: "Sorununuzu yazın...",
                    filled: true,
                    fillColor: softBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: dark,
                      foregroundColor: turquoise,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () async {
                      final text = controller.text.trim();
                      if (text.isEmpty) return;

                      await FirebaseFirestore.instance
                          .collection('support_messages')
                          .add({
                        'tripId': tripId,
                        'customerId': customerId,
                        'message': text,
                        'status': 'open',
                        'createdAt': FieldValue.serverTimestamp(),
                      });

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Mesaj gönderildi.")),
                      );
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text(
                      "Gönder",
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

    controller.dispose();
  }

  Widget _driverCard(String? driverId) {
    if (driverId == null || driverId.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _cardDecoration(),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: turquoise,
              child: Icon(Icons.search_rounded, color: dark, size: 34),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Size en yakın sürücü aranıyor...",
                style: TextStyle(
                  color: dark,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('drivers').doc(driverId).get(),
      builder: (context, snap) {
        final data = snap.data?.data();

        final name = (data?['name'] ?? _fallbackDriverName(driverId)).toString();
        final vehicle = data?['vehicle'] as Map<String, dynamic>?;

        final brand = (vehicle?['brand'] ?? 'Araç').toString();
        final model = (vehicle?['model'] ?? '').toString();
        final plate = (vehicle?['plate'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: turquoise,
                child: Icon(Icons.person, color: dark, size: 34),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: dark,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text("$brand $model"),
                    Text(
                      plate.isEmpty ? "Plaka bilgisi yok" : plate,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fallbackDriverName(String driverId) {
    if (driverId == 'driverA') return 'Elif Kaya';
    if (driverId == 'driverB') return 'Zeynep Aydın';
    return driverId;
  }

  static String _statusTitle(String s) {
    switch (s) {
      case 'queued':
        return 'Size en yakın sürücü aranıyor';

      case 'assigned':
        return 'Sürücü atandı';

      case 'driver_arriving':
        return 'Sürücü size doğru geliyor';

      case 'driver_arrived':
        return 'Sürücü bulunduğunuz konuma ulaştı';

      case 'started':
        return 'Yolculuk başladı';

      case 'payment_pending':
        return 'Ödeme onayı bekleniyor';

      case 'paid':
        return 'Ödeme tamamlandı';

      case 'completed':
        return 'Yolculuk tamamlandı';

      case 'cancelled':
        return 'Yolculuk iptal edildi';

      default:
        return s;
    }
  }

  static String _statusShort(String s) {
    switch (s) {
      case 'queued':
        return 'Aranıyor';

      case 'assigned':
        return 'Atandı';

      case 'driver_arriving':
        return 'Geliyor';

      case 'driver_arrived':
        return 'Ulaştı';

      case 'started':
        return 'Başladı';

      case 'payment_pending':
        return 'Ödeme';

      case 'paid':
        return 'Ödendi';

      case 'completed':
        return 'Tamamlandı';

      case 'cancelled':
        return 'İptal';

      default:
        return s;
    }
  }

  static Color _statusColor(String s) {
    switch (s) {
      case 'queued':
      case 'assigned':
        return turquoise;
      case 'driver_arriving':
        return Colors.blue;
      case 'driver_arrived':
        return Colors.orange;
      case 'started':
        return dark;
      case 'payment_pending':
        return Colors.deepOrange;
      case 'completed':
      case 'paid':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return Colors.red;
      default:
        return dark;
    }
  }

  static BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: turquoise.withOpacity(.22)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.06),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  static Widget _roundIcon(IconData icon) {
    return CircleAvatar(
      radius: 20,
      backgroundColor: softBg,
      child: Icon(icon, color: dark, size: 20),
    );
  }

  static Widget _step(IconData icon, String text, bool active) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: active ? turquoise : Colors.grey.shade300,
            child: Icon(
              icon,
              color: active ? dark : Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? dark : Colors.black38,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _line(bool active) {
    return Container(
      width: 18,
      height: 3,
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: active ? turquoise : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  static Widget _routeRow(Color color, String title, String value) {
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

  static Widget _smallInfo(String title, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: softBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: turquoise.withOpacity(.18)),
        ),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: dark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}