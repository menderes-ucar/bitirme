import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_google_places_hoc081098/flutter_google_places_hoc081098.dart';
import 'package:flutter_google_places_hoc081098/google_maps_webservice_places.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:ridedemo/services/auth_service.dart';
import '../trip_service.dart';
import '../trip_tracking_page.dart';

class CustomerPage extends StatefulWidget {
  final String customerId;

  const CustomerPage({
    super.key,
    required this.customerId,
  });

  @override
  State<CustomerPage> createState() => _CustomerPageState();
}

class _CustomerPageState extends State<CustomerPage> {
  final _service = TripService();
  static const String googleApiKey = "AIzaSyAj2ZuoVjtoPxpfu5Op9G7Ax2hCu84kz3Q";
  double? destinationLat;
  double? destinationLng;
  final _from = TextEditingController(text: "----");
  final _to = TextEditingController(text: "----");

  bool loading = false;
  double? pickupLat;
  double? pickupLng;
  static const double defaultLat = 38.7225;
  static const double defaultLng = 35.4875;
  GoogleMapController? mapController;

  final Set<Marker> markers = {};
  bool loadingLocation = false;
  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);
  static const Color softBg = Color(0xFFF6FEFD);

  Future<void> _requestTrip() async {
    if (loading) return;

    setState(() => loading = true);

    try {
      final tripId = await _service.createTrip(
        customerId: widget.customerId,
        fromText: _from.text.trim(),
        toText: _to.text.trim(),

        pickupLat: pickupLat ?? defaultLat,
        pickupLng: pickupLng ?? defaultLng,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripTrackingPage(tripId: tripId),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<String> _addressFromLatLng(
      double lat,
      double lng,
      ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
            '?latlng=$lat,$lng'
            '&language=tr'
            '&region=tr'
            '&key=$googleApiKey',
      );

      final res = await http.get(url);

      if (res.statusCode != 200) {
        return 'Adres bulunamadı';
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      final status = (data['status'] ?? '').toString();

      if (status != 'OK') {
        return 'Adres bulunamadı';
      }

      final results = data['results'] as List<dynamic>?;

      if (results == null || results.isEmpty) {
        return 'Adres bulunamadı';
      }

      final first = results.first as Map<String, dynamic>;
      final formattedAddress = (first['formatted_address'] ?? '').toString().trim();

      if (formattedAddress.isEmpty) {
        return 'Adres bulunamadı';
      }

      return formattedAddress;
    } catch (_) {
      return 'Adres bulunamadı';
    }
  }

  Future<void> _getCurrentLocation() async {
    if (loadingLocation) return;

    setState(() => loadingLocation = true);

    try {
      LocationPermission permission =
      await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Konum izni verilmedi');
      }

      final pos = await Geolocator.getCurrentPosition();

      pickupLat = pos.latitude;
      pickupLng = pos.longitude;
      final current = LatLng(
        pos.latitude,
        pos.longitude,
      );

      markers.clear();

      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: current,
          infoWindow: const InfoWindow(
            title: 'Konumunuz',
          ),
        ),
      );

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(current, 15),
      );
      final address = await _addressFromLatLng(
        pos.latitude,
        pos.longitude,
      );

      _from.text = address;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konum alındı ✅'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum alınamadı: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loadingLocation = false);
      }
    }
  }
  Future<void> _searchPlace({required bool isPickup}) async {
    final prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: googleApiKey,
      mode: Mode.overlay,
      language: 'tr',
      components: [Component(Component.country, 'tr')],
    );

    if (prediction == null || prediction.placeId == null) return;

    final places = GoogleMapsPlaces(apiKey: googleApiKey);
    final detail = await places.getDetailsByPlaceId(prediction.placeId!);

    final loc = detail.result.geometry?.location;
    if (loc == null) return;

    final latLng = LatLng(loc.lat, loc.lng);
    final address = detail.result.formattedAddress ?? prediction.description ?? '';

    if (isPickup) {
      pickupLat = latLng.latitude;
      pickupLng = latLng.longitude;
      _from.text = address;

      markers.removeWhere((m) => m.markerId.value == 'pickup');
      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: latLng,
          infoWindow: const InfoWindow(title: 'Kalkış'),
        ),
      );
    } else {
      destinationLat = latLng.latitude;
      destinationLng = latLng.longitude;
      _to.text = address;

      markers.removeWhere((m) => m.markerId.value == 'destination');
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Varış'),
        ),
      );
    }

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(latLng, 15),
    );

    if (mounted) setState(() {});
  }
  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                children: [
                  PopupMenuButton<String>(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (v) async {
                      if (v == 'demo_menu') {
                        Navigator.pop(context);
                      }

                      if (v == 'logout') {
                        await AuthService().signOut();
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout_rounded),
                            SizedBox(width: 10),
                            Text('Çıkış Yap'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'demo_menu',
                        child: Row(
                          children: [
                            Icon(Icons.dashboard_customize_rounded),
                            SizedBox(width: 10),
                            Text(' Menüye Dön'),
                          ],
                        ),
                      ),
                    ],
                    child: _circleButton(Icons.menu_rounded),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Nereye gidiyorsunuz?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: dark,
                        ),
                      ),
                    ),
                  ),
                  Stack(
                    children: [
                      _circleButton(Icons.notifications_none_rounded),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: turquoise,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: turquoise.withOpacity(.22)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _locationInput(
                      color: turquoise,
                      title: "Kalkış Konumu",
                      controller: _from,
                      trailing: "Konumu Kullan",
                    ),
                    Divider(color: Colors.grey.shade200),
                    _locationInput(
                      color: dark,
                      title: "Varış Konumu",
                      controller: _to,
                      trailingIcon: Icons.add,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(38.7225, 35.4875),
                      zoom: 13,
                    ),

                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,

                    zoomControlsEnabled: false,

                    markers: markers,

                    onMapCreated: (controller) {
                      mapController = controller;
                    },

                    onTap: (latLng) async {
                      destinationLat = latLng.latitude;
                      destinationLng = latLng.longitude;

                      markers.removeWhere(
                            (e) => e.markerId.value == 'destination',
                      );

                      markers.add(
                        Marker(
                          markerId: const MarkerId('destination'),
                          position: latLng,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueAzure,
                          ),
                          infoWindow: const InfoWindow(title: 'Varış'),
                        ),
                      );

                      setState(() {
                        _to.text = 'Adres alınıyor...';
                      });

                      final address = await _addressFromLatLng(
                        latLng.latitude,
                        latLng.longitude,
                      );

                      if (!mounted) return;

                      setState(() {
                        _to.text = address;
                      });
                    },
                  ),
                  Positioned(
                    top: 130,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: turquoise.withOpacity(.20),
                          shape: BoxShape.circle,
                          border: Border.all(color: turquoise, width: 2),
                        ),
                        child: const Center(
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: turquoise,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    right: 18,
                    bottom: 26,
                    child: FloatingActionButton(
                      backgroundColor: Colors.white,
                      foregroundColor: dark,
                      onPressed: _getCurrentLocation,
                      child: const Icon(Icons.my_location_rounded),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: softBg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: turquoise.withOpacity(.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: turquoise.withOpacity(.12),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.local_taxi_rounded,
                            color: turquoise,
                            size: 30,
                          ),
                        ),

                        const SizedBox(width: 14),
                      ],
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: loading ? null : _requestTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dark,
                        foregroundColor: turquoise,
                        disabledBackgroundColor: Colors.grey.shade300,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        loading ? "Yolculuk isteniyor..." : "Yolculuk İste",
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withOpacity(.06)),
      ),
      child: Icon(icon, color: dark, size: 25),
    );
  }

  Widget _locationInput({
    required Color color,
    required String title,
    required TextEditingController controller,
    String? trailing,
    IconData? trailingIcon,
  }) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 14),
        Expanded(
          child: GestureDetector(
            onTap: () => _searchPlace(isPickup: title == "Kalkış Konumu"),
            child: AbsorbPointer(
              child: TextField(
                controller: controller,
                style: const TextStyle(
                  color: dark,
                  fontWeight: FontWeight.w800,
                ),
                decoration: InputDecoration(
                  labelText: title,
                  labelStyle: TextStyle(
                    color: Colors.black.withOpacity(.55),
                    fontWeight: FontWeight.w700,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ),
        if (trailing != null)
          GestureDetector(
            onTap: _getCurrentLocation,
            child: Text(
              loadingLocation ? "Alınıyor..." : trailing,
              style: const TextStyle(
                color: turquoise,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        if (trailingIcon != null)
          GestureDetector(
            onTap: () => _searchPlace(isPickup: false),
            child: CircleAvatar(
              backgroundColor: dark,
              child: Icon(trailingIcon, color: turquoise),
            ),
          ),
      ],
    );
  }

  Widget _infoBox(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: softBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: turquoise.withOpacity(.18)),
        ),
        child: Column(
          children: [
            Icon(icon, color: turquoise, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withOpacity(.55),
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
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}