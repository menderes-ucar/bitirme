import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const kDemoSessionId = 'ridedemo';

const Color kTurquoise = Color(0xFF40E0D0);
const Color kDark = Color(0xFF050505);
const Color kSoftBg = Color(0xFFF6FEFD);

class DriverManagePage extends StatelessWidget {
  const DriverManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    final stream = db.collection('drivers').snapshots();

    return Scaffold(
      backgroundColor: kSoftBg,
      appBar: AppBar(
        backgroundColor: kSoftBg,
        foregroundColor: kDark,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        title: const Text(
          'Sürücü Yönetimi',
          style: TextStyle(
            color: kDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kDark,
        foregroundColor: kTurquoise,
        elevation: 0,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DriverFormPage(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Yeni Sürücü',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text('Hata: ${snap.error}'));
            }

            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;

            final onlineCount =
                docs.where((e) => e.data()['isOnline'] == true).length;

            final approvedCount =
                docs.where((e) => e.data()['isApproved'] == true).length;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _hero(
                  total: docs.length,
                  online: onlineCount,
                  approved: approvedCount,
                ),
                const SizedBox(height: 22),
                const Text(
                  'Sürücü Listesi',
                  style: TextStyle(
                    color: kDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Onaylı, çevrimiçi ve pasif sürücüleri buradan yönet.',
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

                    final name = (d['name'] ?? doc.id).toString();
                    final age = (d['age'] ?? '').toString();
                    final exp =
                    (d['experienceYear'] ?? d['experienceYears'] ?? '')
                        .toString();
                    final phone = (d['phone'] ?? '').toString();
                    final status = (d['status'] ?? 'active').toString();
                    final isOnline = d['isOnline'] == true;
                    final isApproved = d['isApproved'] == true;
                    final vehicle =
                    (d['vehicle'] as Map?)?.cast<String, dynamic>();

                    final brand = (vehicle?['brand'] ?? '').toString();
                    final model = (vehicle?['model'] ?? '').toString();
                    final plate = (vehicle?['plate'] ?? '').toString();

                    return _driverCard(
                      context: context,
                      db: db,
                      driverId: doc.id,
                      data: d,
                      name: name,
                      age: age,
                      exp: exp,
                      phone: phone,
                      status: status,
                      isOnline: isOnline,
                      isApproved: isApproved,
                      vehicleText:
                      '${brand.isEmpty ? 'Araç' : brand} ${model.isEmpty ? '' : model} ${plate.isEmpty ? '' : '• $plate'}',
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hero({
    required int total,
    required int online,
    required int approved,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kDark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.24),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.admin_panel_settings_rounded,
            color: kTurquoise,
            size: 42,
          ),
          const SizedBox(height: 14),
          const Text(
            'Sürücü Yönetimi',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kadın sürücü havuzunu ve operasyon durumlarını yönetin.',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _summaryBox(Icons.people_alt_rounded, 'Toplam', '$total'),
              const SizedBox(width: 10),
              _summaryBox(Icons.power_settings_new_rounded, 'Online', '$online'),
              const SizedBox(width: 10),
              _summaryBox(Icons.verified_rounded, 'Onaylı', '$approved'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBox(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(.10)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kTurquoise),
            const SizedBox(height: 7),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
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

  Widget _driverCard({
    required BuildContext context,
    required FirebaseFirestore db,
    required String driverId,
    required Map<String, dynamic> data,
    required String name,
    required String age,
    required String exp,
    required String phone,
    required String status,
    required bool isOnline,
    required bool isApproved,
    required String vehicleText,
  }) {
    final statusColor = isOnline
        ? const Color(0xFF16A34A)
        : status == 'pending'
        ? Colors.orange
        : status == 'passive'
        ? Colors.red
        : Colors.black54;

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => _showDriverDetails(context, driverId, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: kTurquoise.withOpacity(.18)),
          boxShadow: [
            BoxShadow(
              color: statusColor.withOpacity(.10),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: kDark,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: kTurquoise,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: kDark,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vehicleText.trim().isEmpty
                            ? 'Araç bilgisi yok'
                            : vehicleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: kDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _statusPill(status, isOnline, isApproved),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _miniInfo(Icons.cake_outlined, 'Yaş', age.isEmpty ? '—' : age),
                const SizedBox(width: 8),
                _miniInfo(
                  Icons.workspace_premium_outlined,
                  'Tecrübe',
                  exp.isEmpty ? '—' : '$exp yıl',
                ),
                const SizedBox(width: 8),
                _miniInfo(
                  Icons.verified_rounded,
                  'Onay',
                  isApproved ? 'Onaylı' : 'Bekliyor',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DriverFormPage(
                            driverId: driverId,
                            initial: data,
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kDark,
                      side: BorderSide(color: kTurquoise.withOpacity(.45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text(
                      'Düzenle',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Sürücü silinsin mi?'),
                          content: const Text(
                            'Bu işlem sürücüyü panelden kaldırır ve hesabın şoför rolünü kapatır.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Vazgeç'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );

                      if (ok != true) return;

                      await db.collection('drivers').doc(driverId).delete();

                      await db.collection('users').doc(driverId).set({
                        'role': 'customer',
                        'driverId': FieldValue.delete(),
                        'isApproved': false,
                        'driverDeleted': true,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      await db.collection('driver_applications').doc(driverId).set({
                        'status': 'deleted',
                        'deletedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true));

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Sürücü silindi ve şoför rolü kapatıldı.',
                          ),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(.35)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text(
                      'Sil',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: kSoftBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kTurquoise.withOpacity(.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: kTurquoise, size: 20),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: kDark,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _statusPill(
      String status,
      bool isOnline,
      bool isApproved,
      ) {
    String text;
    Color color;

    if (!isApproved || status == 'pending') {
      text = 'Onay Bekliyor';
      color = Colors.orange;
    } else if (status == 'break') {
      text = 'Molada';
      color = Colors.blue;
    } else if (status == 'passive') {
      text = 'Pasif';
      color = Colors.red;
    } else if (isOnline) {
      text = 'Çevrimiçi';
      color = const Color(0xFF16A34A);
    } else {
      text = 'Çevrimdışı';
      color = Colors.black54;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 10,
        ),
      ),
    );
  }

  static String _statusTr(String s) {
    switch (s) {
      case 'active':
        return 'Aktif';
      case 'break':
        return 'Molada';
      case 'passive':
        return 'Pasif';
      case 'pending':
        return 'Onay Bekliyor';
      default:
        return s;
    }
  }

  static void _showDriverDetails(
      BuildContext context,
      String driverId,
      Map<String, dynamic> d,
      ) {
    final name = (d['name'] ?? driverId).toString();
    final age = _clean(d['age']);
    final exp = _clean(d['experienceYear'] ?? d['experienceYears']);
    final phone = _clean(d['phone']);
    final address = _clean(d['city'] ?? d['address']);
    final status = (d['status'] ?? 'active').toString();
    final isOnline = d['isOnline'] == true;
    final isApproved = d['isApproved'] == true;

    final vehicle = (d['vehicle'] as Map?)?.cast<String, dynamic>();
    final brand = _clean(vehicle?['brand']);
    final model = _clean(vehicle?['model']);
    final plate = _clean(vehicle?['plate']);
    final type = _clean(vehicle?['type']);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: kDark,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: kTurquoise,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: kDark,
                        size: 38,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isOnline ? 'Çevrimiçi' : _statusTr(status),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isApproved
                          ? Icons.verified_rounded
                          : Icons.pending_actions_rounded,
                      color: kTurquoise,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _detailRow('ID', driverId),
              _detailRow('Yaş', age),
              _detailRow('Tecrübe', '$exp yıl'),
              _detailRow('Telefon', phone),
              _detailRow('Şehir/Adres', address),
              _detailRow('Araç Tipi', type),
              _detailRow('Marka', brand),
              _detailRow('Model', model),
              _detailRow('Plaka', plate),
              const SizedBox(height: 14),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDark,
                    foregroundColor: kTurquoise,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DriverFormPage(
                          driverId: driverId,
                          initial: d,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text(
                    'Düzenle',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _clean(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    return s.isEmpty ? '—' : s;
  }

  static Widget _detailRow(String k, String v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: kSoftBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kTurquoise.withOpacity(.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              k,
              style: const TextStyle(
                color: Colors.black45,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              v,
              softWrap: true,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                color: kDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: kTurquoise.withOpacity(.20)),
      ),
      child: const Column(
        children: [
          Icon(Icons.people_alt_outlined, color: kTurquoise, size: 56),
          SizedBox(height: 12),
          Text(
            'Henüz sürücü yok',
            style: TextStyle(
              color: kDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Yeni sürücü eklemek için sağ alttaki butonu kullan.',
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
}

class DriverFormPage extends StatefulWidget {
  final String? driverId;
  final Map<String, dynamic>? initial;

  const DriverFormPage({
    super.key,
    this.driverId,
    this.initial,
  });

  @override
  State<DriverFormPage> createState() => _DriverFormPageState();
}

class _DriverFormPageState extends State<DriverFormPage> {
  final _db = FirebaseFirestore.instance;

  late final TextEditingController _name;
  late final TextEditingController _age;
  late final TextEditingController _address;
  late final TextEditingController _exp;
  late final TextEditingController _phone;

  late final TextEditingController _vehicleType;
  late final TextEditingController _brand;
  late final TextEditingController _model;
  late final TextEditingController _plate;

  String _status = 'active';
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    final d = widget.initial ?? {};
    final vehicle = (d['vehicle'] as Map?)?.cast<String, dynamic>() ?? {};

    _name = TextEditingController(text: (d['name'] ?? '').toString());
    _age = TextEditingController(text: (d['age'] ?? '').toString());
    _address = TextEditingController(
      text: (d['city'] ?? d['address'] ?? '').toString(),
    );
    _exp = TextEditingController(
      text: (d['experienceYear'] ?? d['experienceYears'] ?? '').toString(),
    );
    _phone = TextEditingController(text: (d['phone'] ?? '').toString());

    _vehicleType =
        TextEditingController(text: (vehicle['type'] ?? '').toString());
    _brand = TextEditingController(text: (vehicle['brand'] ?? '').toString());
    _model = TextEditingController(text: (vehicle['model'] ?? '').toString());
    _plate = TextEditingController(text: (vehicle['plate'] ?? '').toString());

    _status = (d['status'] ?? 'active').toString();
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _address.dispose();
    _exp.dispose();
    _phone.dispose();
    _vehicleType.dispose();
    _brand.dispose();
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: kDark),
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(
        color: Colors.black54,
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: kTurquoise.withOpacity(.20)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: kTurquoise, width: 1.6),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    final name = _name.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İsim zorunlu')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final payload = <String, dynamic>{
        'demoSessionId': kDemoSessionId,
        'name': name,
        'age': int.tryParse(_age.text.trim()),
        'city': _address.text.trim(),
        'address': _address.text.trim(),
        'experienceYear': int.tryParse(_exp.text.trim()),
        'phone': _phone.text.trim(),
        'status': _status,
        'isApproved': _status != 'pending',
        'vehicle': {
          'type': _vehicleType.text.trim(),
          'brand': _brand.text.trim(),
          'model': _model.text.trim(),
          'plate': _plate.text.trim().toUpperCase(),
        },
        'stats': {
          'rating': 4.8,
          'totalTrips': 0,
          'totalPassengers': 0,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      payload.removeWhere((k, v) => v == null);

      final id = widget.driverId;

      if (id == null) {
        await _db.collection('drivers').add({
          ...payload,
          'isOnline': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await _db.collection('drivers').doc(id).set(
          payload,
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedildi')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.driverId != null;

    return Scaffold(
      backgroundColor: kSoftBg,
      appBar: AppBar(
        backgroundColor: kSoftBg,
        foregroundColor: kDark,
        elevation: 0,
        centerTitle: true,
        title: Text(
          isEdit ? 'Sürücü Düzenle' : 'Yeni Sürücü',
          style: const TextStyle(
            color: kDark,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _formHero(isEdit),
            const SizedBox(height: 18),
            _sectionTitle('Kişisel Bilgiler'),
            const SizedBox(height: 10),
            TextField(
              controller: _name,
              decoration: _dec('Ad Soyad', Icons.person_outline),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: _dec('Telefon', Icons.phone_outlined),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _age,
                    keyboardType: TextInputType.number,
                    decoration: _dec('Yaş', Icons.cake_outlined),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _exp,
                    keyboardType: TextInputType.number,
                    decoration:
                    _dec('Tecrübe', Icons.workspace_premium_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _address,
              maxLines: 2,
              decoration: _dec('Şehir / Adres', Icons.location_on_outlined),
            ),
            const SizedBox(height: 18),
            _sectionTitle('Araç Bilgileri'),
            const SizedBox(height: 10),
            TextField(
              controller: _vehicleType,
              decoration: _dec('Araç Tipi', Icons.directions_car_outlined),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _brand,
                    decoration: _dec('Marka', Icons.local_taxi_outlined),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _model,
                    decoration: _dec('Model', Icons.car_rental_outlined),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: _dec('Plaka', Icons.confirmation_number_outlined),
            ),
            const SizedBox(height: 18),
            _sectionTitle('Durum'),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: _dec('Sürücü Durumu', Icons.verified_outlined),
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Aktif')),
                DropdownMenuItem(value: 'break', child: Text('Molada')),
                DropdownMenuItem(value: 'passive', child: Text('Pasif')),
                DropdownMenuItem(value: 'pending', child: Text('Onay Bekliyor')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _status = v);
              },
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 58,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kDark,
                  foregroundColor: kTurquoise,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: _saving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kTurquoise,
                  ),
                )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _saving ? 'Kaydediliyor...' : 'Kaydet',
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

  Widget _formHero(bool isEdit) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: kDark,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.24),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: kTurquoise,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(
              isEdit ? Icons.edit_rounded : Icons.person_add_alt_1_rounded,
              color: kDark,
              size: 38,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              isEdit
                  ? 'Sürücü bilgilerini güncelle'
                  : 'Yeni kadın sürücü kaydı oluştur',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
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
        color: kDark,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}