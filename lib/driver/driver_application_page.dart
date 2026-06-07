import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class DriverApplicationPage extends StatefulWidget {
  const DriverApplicationPage({super.key});

  @override
  State<DriverApplicationPage> createState() => _DriverApplicationPageState();
}

class _DriverApplicationPageState extends State<DriverApplicationPage> {
  final name = TextEditingController();
  final age = TextEditingController();
  final city = TextEditingController();
  final experience = TextEditingController();
  final phone = TextEditingController();
  final email = TextEditingController();

  final vehicleBrand = TextEditingController();
  final vehicleModel = TextEditingController();
  final plate = TextEditingController();

  bool loading = false;
  File? idImage;

  final picker = ImagePicker();

  static const Color turquoise = Color(0xFF40E0D0);
  static const Color dark = Color(0xFF050505);
  static const Color softBg = Color(0xFFF6FEFD);

  @override
  void dispose() {
    name.dispose();
    age.dispose();
    city.dispose();
    experience.dispose();
    phone.dispose();
    email.dispose();
    vehicleBrand.dispose();
    vehicleModel.dispose();
    plate.dispose();
    super.dispose();
  }

  Future<void> pickIdImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text(
                    'Kamera ile çek',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text(
                    'Galeriden yükle',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    final x = await picker.pickImage(
      source: source,
      imageQuality: 75,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (x == null) return;

    setState(() {
      idImage = File(x.path);
    });
  }

  Future<String> _uploadImage(String applicationId) async {
    if (idImage == null) {
      throw Exception('Kimlik fotoğrafı seçilmedi.');
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = FirebaseStorage.instance
        .ref()
        .child('driver_applications')
        .child(applicationId)
        .child(fileName);

    final task = await ref.putFile(
      idImage!,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return await task.ref.getDownloadURL();
  }

  Future<String> _readGenderCheck() async {
    if (idImage == null) return 'review_required';

    final input = InputImage.fromFile(idImage!);
    final recognizer = TextRecognizer();
    final result = await recognizer.processImage(input);
    final text = result.text.toUpperCase();
    await recognizer.close();

    if (text.contains(' K ') ||
        text.contains('KADIN') ||
        text.contains('FEMALE')) {
      return 'passed';
    }

    return 'review_required';
  }

  Future<void> submit() async {
    if (loading) return;

    if (name.text.trim().isEmpty ||
        age.text.trim().isEmpty ||
        city.text.trim().isEmpty ||
        experience.text.trim().isEmpty ||
        phone.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        vehicleBrand.text.trim().isEmpty ||
        vehicleModel.text.trim().isEmpty ||
        plate.text.trim().isEmpty ||
        idImage == null) {
      _msg('Tüm alanları doldurun.');
      return;
    }

    setState(() => loading = true);

    try {
      final ref =
      FirebaseFirestore.instance.collection('driver_applications').doc();

      final imageUrl = await _uploadImage(ref.id);
      final genderCheck = await _readGenderCheck();

      await ref.set({
        'applicationId': ref.id,
        'name': name.text.trim(),
        'age': int.tryParse(age.text.trim()) ?? 18,
        'city': city.text.trim(),
        'experienceYear': int.tryParse(experience.text.trim()) ?? 0,
        'phone': phone.text.trim(),
        'email': email.text.trim(),
        'vehicle': {
          'brand': vehicleBrand.text.trim(),
          'model': vehicleModel.text.trim(),
          'plate': plate.text.trim().toUpperCase(),
        },
        'idCardImageUrl': imageUrl,
        'genderCheckStatus': genderCheck,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Başvuru Gönderildi',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            content: const Text(
              'Başvurunuz admin onayına gönderildi. Onaylandıktan sonra hesabınız oluşturulacak.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: dark,
                  foregroundColor: turquoise,
                ),
                child: const Text('Tamam'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _msg('Hata: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: softBg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _hero(),
            const SizedBox(height: 18),

            _sectionTitle('Kişisel Bilgiler'),
            const SizedBox(height: 10),
            _input(name, 'Ad Soyad', Icons.person_outline),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _input(age, 'Yaş', Icons.cake_outlined)),
                const SizedBox(width: 10),
                Expanded(child: _input(city, 'Şehir', Icons.location_city)),
              ],
            ),
            const SizedBox(height: 12),
            _input(experience, 'Tecrübe Yılı', Icons.workspace_premium),
            const SizedBox(height: 12),
            _input(phone, 'Telefon', Icons.phone_outlined),
            const SizedBox(height: 12),
            _input(email, 'E-posta', Icons.email_outlined),

            const SizedBox(height: 20),

            _sectionTitle('Araç Bilgileri'),
            const SizedBox(height: 10),
            _input(vehicleBrand, 'Araç Markası', Icons.local_taxi),
            const SizedBox(height: 12),
            _input(vehicleModel, 'Araç Modeli', Icons.directions_car),
            const SizedBox(height: 12),
            _input(plate, 'Plaka', Icons.confirmation_number),

            const SizedBox(height: 20),

            _sectionTitle('Kimlik Doğrulama'),
            const SizedBox(height: 10),
            _idPicker(),

            const SizedBox(height: 24),

            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: loading ? null : submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: dark,
                  foregroundColor: turquoise,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: loading
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: turquoise,
                  ),
                )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  loading ? 'Gönderiliyor...' : 'Başvuruyu Gönder',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: dark,
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded, color: turquoise, size: 42),
          SizedBox(height: 14),
          Text(
            'Şoför Başvurusu',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Başvuru formunu doldur. Admin onayından sonra hesabın oluşturulacak.',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: dark,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: dark),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: turquoise.withOpacity(.20)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: turquoise, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _idPicker() {
    return GestureDetector(
      onTap: pickIdImage,
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: turquoise.withOpacity(.24)),
        ),
        child: idImage == null
            ? const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.badge_outlined, size: 58, color: dark),
            SizedBox(height: 10),
            Text(
              'Kimlik Fotoğrafı Çek / Yükle',
              style: TextStyle(
                color: dark,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Kadın doğrulaması admin onayına düşer.',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        )
            : ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Image.file(
            idImage!,
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}