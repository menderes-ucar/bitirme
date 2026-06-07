import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final pass = TextEditingController();
  final name = TextEditingController();

  final phone = TextEditingController();
  final city = TextEditingController();
  final age = TextEditingController();
  final experienceYear = TextEditingController();
  final vehicleBrand = TextEditingController();
  final vehicleModel = TextEditingController();
  final vehiclePlate = TextEditingController();

  File? customerPhoto;
  File? driverIdPhoto;

  bool hidden = true;
  bool loading = false;
  bool registerMode = false;

  String selectedRole = 'customer';

  @override
  void dispose() {
    email.dispose();
    pass.dispose();
    name.dispose();

    phone.dispose();
    city.dispose();
    age.dispose();
    experienceYear.dispose();
    vehicleBrand.dispose();
    vehicleModel.dispose();
    vehiclePlate.dispose();

    super.dispose();
  }

  Future<void> _pickCustomerPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() {
      customerPhoto = File(picked.path);
    });
  }

  Future<void> _pickDriverIdPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );

    if (picked == null) return;

    setState(() {
      driverIdPhoto = File(picked.path);
    });
  }

  Future<String> _uploadFile({
    required File file,
    required String folder,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = FirebaseStorage.instance
        .ref()
        .child(folder)
        .child(fileName);

    await ref.putFile(file);

    return ref.getDownloadURL();
  }

  Future<void> _submit() async {
    if (loading) return;

    final e = email.text.trim();
    final p = pass.text.trim();
    final n = name.text.trim();

    if (e.isEmpty || p.isEmpty) {
      _msg('E-posta ve şifre boş olamaz.');
      return;
    }

    if (registerMode && n.isEmpty) {
      _msg('Ad soyad boş olamaz.');
      return;
    }

    if (registerMode && selectedRole == 'customer' && customerPhoto == null) {
      _msg('Kadın yolcu doğrulaması için fotoğraf yüklemelisin.');
      return;
    }

    if (registerMode && selectedRole == 'driver') {
      if (phone.text.trim().isEmpty ||
          city.text.trim().isEmpty ||
          age.text.trim().isEmpty ||
          experienceYear.text.trim().isEmpty ||
          vehicleBrand.text.trim().isEmpty ||
          vehicleModel.text.trim().isEmpty ||
          vehiclePlate.text.trim().isEmpty ||
          driverIdPhoto == null) {
        _msg('Şoför başvurusu için tüm bilgileri ve kimlik fotoğrafını eklemelisin.');
        return;
      }
    }

    setState(() => loading = true);

    try {
      if (registerMode) {
        String? customerPhotoUrl;
        String? driverIdPhotoUrl;

        if (selectedRole == 'customer' && customerPhoto != null) {
          customerPhotoUrl = await _uploadFile(
            file: customerPhoto!,
            folder: 'customer_photos',
          );
        }

        if (selectedRole == 'driver' && driverIdPhoto != null) {
          driverIdPhotoUrl = await _uploadFile(
            file: driverIdPhoto!,
            folder: 'driver_id_photos',
          );
        }

        await AuthService().register(
          email: e,
          password: p,
          name: n,
          role: selectedRole,
          customerPhotoUrl: customerPhotoUrl,
          phone: selectedRole == 'driver' ? phone.text.trim() : null,
          city: selectedRole == 'driver' ? city.text.trim() : null,
          age: selectedRole == 'driver' ? int.tryParse(age.text.trim()) : null,
          experienceYear: selectedRole == 'driver'
              ? int.tryParse(experienceYear.text.trim())
              : null,
          vehicleBrand:
          selectedRole == 'driver' ? vehicleBrand.text.trim() : null,
          vehicleModel:
          selectedRole == 'driver' ? vehicleModel.text.trim() : null,
          vehiclePlate:
          selectedRole == 'driver' ? vehiclePlate.text.trim() : null,
          driverIdPhotoUrl: driverIdPhotoUrl,
        );

        if (!mounted) return;

        _msg('Başvurunuz alındı. Admin onayından sonra giriş yapabilirsiniz.');

        setState(() {
          registerMode = false;
          selectedRole = 'customer';

          pass.clear();
          customerPhoto = null;
          driverIdPhoto = null;

          phone.clear();
          city.clear();
          age.clear();
          experienceYear.clear();
          vehicleBrand.clear();
          vehicleModel.clear();
          vehiclePlate.clear();
        });
      } else {
        await AuthService().signIn(
          email: e,
          password: p,
        );
      }
    } catch (err) {
      if (!mounted) return;
      _msg('Hata: $err');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _msg(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFF40E0D0);
    const dark = Color(0xFF050505);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF6FEFD),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        width: 118,
                        height: 118,
                        decoration: BoxDecoration(
                          color: mainColor.withOpacity(.16),
                          shape: BoxShape.circle,
                          border: Border.all(color: mainColor, width: 2),
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          size: 66,
                          color: dark,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        registerMode ? 'Hesap Oluştur' : 'Güvenli Yolculuk',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: dark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        registerMode
                            ? 'Yolcu veya şoför başvurusu oluştur'
                            : 'Yolcu ve şoför giriş sistemi',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 36),

                      if (registerMode) ...[
                        _roleSelector(),
                        const SizedBox(height: 18),
                        _input(
                          controller: name,
                          hint: 'Ad Soyad',
                          icon: Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        _input(
                          controller: email,
                          hint: 'E-posta',
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 14),
                        _passwordInput(),

                        if (selectedRole == 'customer') ...[
                          const SizedBox(height: 18),
                          _customerPhotoCard(),
                        ],

                        if (selectedRole == 'driver') ...[
                          const SizedBox(height: 18),
                          _input(
                            controller: phone,
                            hint: 'Telefon',
                            icon: Icons.phone_outlined,
                          ),
                          const SizedBox(height: 14),
                          _input(
                            controller: city,
                            hint: 'Şehir',
                            icon: Icons.location_city_outlined,
                          ),
                          const SizedBox(height: 14),
                          _input(
                            controller: age,
                            hint: 'Yaş',
                            icon: Icons.cake_outlined,
                          ),
                          const SizedBox(height: 14),
                          _input(
                            controller: experienceYear,
                            hint: 'Tecrübe Yılı',
                            icon: Icons.work_outline,
                          ),
                          const SizedBox(height: 14),
                          _input(
                            controller: vehicleBrand,
                            hint: 'Araç Markası',
                            icon: Icons.directions_car_outlined,
                          ),
                          const SizedBox(height: 14),
                          _input(
                            controller: vehicleModel,
                            hint: 'Araç Modeli',
                            icon: Icons.local_taxi_outlined,
                          ),
                          const SizedBox(height: 14),
                          _input(
                            controller: vehiclePlate,
                            hint: 'Plaka',
                            icon: Icons.confirmation_number_outlined,
                          ),
                          const SizedBox(height: 18),
                          _driverIdPhotoCard(),
                        ],
                      ],

                      if (!registerMode) ...[
                        _input(
                          controller: email,
                          hint: 'E-posta',
                          icon: Icons.email_outlined,
                        ),
                        const SizedBox(height: 14),
                        _passwordInput(),
                      ],

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: dark,
                            foregroundColor: mainColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: mainColor,
                            ),
                          )
                              : Text(
                            registerMode ? 'Başvuru Gönder' : 'Giriş Yap',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      TextButton(
                        onPressed: loading
                            ? null
                            : () {
                          setState(() {
                            registerMode = !registerMode;
                            selectedRole = 'customer';
                          });
                        },
                        child: Text(
                          registerMode
                              ? 'Zaten hesabın var mı? Giriş yap'
                              : 'Hesabın yok mu? Kayıt ol',
                          style: const TextStyle(
                            color: dark,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _driverIdPhotoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF40E0D0).withOpacity(.25),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFF40E0D0).withOpacity(.15),
            backgroundImage:
            driverIdPhoto == null ? null : FileImage(driverIdPhoto!),
            child: driverIdPhoto == null
                ? const Icon(
              Icons.badge_rounded,
              size: 42,
              color: Color(0xFF050505),
            )
                : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'Şoför Kimlik Fotoğrafı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Başvurunun incelenmesi için kimlik fotoğrafı zorunludur.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDriverIdPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDriverIdPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _customerPhotoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF40E0D0).withOpacity(.25),
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: const Color(0xFF40E0D0).withOpacity(.15),
            backgroundImage:
            customerPhoto == null ? null : FileImage(customerPhoto!),
            child: customerPhoto == null
                ? const Icon(
              Icons.person_search_rounded,
              size: 42,
              color: Color(0xFF050505),
            )
                : null,
          ),
          const SizedBox(height: 12),
          const Text(
            'Yolcu Doğrulama Fotoğrafı',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Güvenli yolculuk sistemi için yolcu hesabında fotoğraf zorunludur.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickCustomerPhoto(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Kamera'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickCustomerPhoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded),
                  label: const Text('Galeri'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roleSelector() {
    return Row(
      children: [
        _roleChip('customer', 'Yolcu', Icons.person_rounded),
        const SizedBox(width: 8),
        _roleChip('driver', 'Şoför', Icons.local_taxi_rounded),
      ],
    );
  }

  Widget _roleChip(String role, String label, IconData icon) {
    final selected = selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedRole = role),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF050505) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? const Color(0xFF40E0D0) : Colors.grey.shade200,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? const Color(0xFF40E0D0) : Colors.black54,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFF40E0D0) : Colors.black54,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordInput() {
    return _input(
      controller: pass,
      hint: 'Şifre',
      icon: Icons.lock_outline,
      obscure: hidden,
      suffix: IconButton(
        onPressed: () => setState(() => hidden = !hidden),
        icon: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          borderSide: BorderSide(
            color: Color(0xFF40E0D0),
            width: 1.5,
          ),
        ),
      ),
    );
  }
}