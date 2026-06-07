import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  User? get currentUser => _auth.currentUser;
  bool _isApprovedUser(Map<String, dynamic> data) {
    final isApproved = data['isApproved'] == true;

    final approvalStatus = (data['approvalStatus'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    return isApproved || approvalStatus == 'approved';
  }

  bool _needsApproval(String role) {
    final r = role.trim().toLowerCase();
    return r == 'customer' || r == 'driver';
  }
  Future<AppUser?> getCurrentAppUser() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      return null;
    }

    final data = doc.data()!;

    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final approved = _isApprovedUser(data);

    if (_needsApproval(role) && !approved) {
      throw Exception('Hesabınız admin onayı bekliyor.');
    }

    return AppUser.fromMap(user.uid, {
      ...data,
      'role': role,
      'isApproved': approved,
    });
  }

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('Kullanıcı bulunamadı.');
    }

    final doc = await _db.collection('users').doc(user.uid).get();

    if (!doc.exists) {
      await _auth.signOut();
      throw Exception('Kullanıcı rol kaydı bulunamadı.');
    }

    final data = doc.data()!;

    final role = (data['role'] ?? '').toString().trim().toLowerCase();
    final approved = _isApprovedUser(data);

    if (_needsApproval(role) && !approved) {
      throw Exception(
        'Hesap onaysız görünüyor. Firestore users/${user.uid} içinde isApproved=true ve approvalStatus=approved kontrol et.',
      );
    }



    return AppUser.fromMap(user.uid, {
      ...data,
      'role' : role,
      'isApproved': approved,
    });
  }

  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
    required String role,
    String? customerPhotoUrl,

    String? phone,
    String? city,
    int? age,
    int? experienceYear,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehiclePlate,
    String? driverIdPhotoUrl,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = cred.user;
    if (user == null) {
      throw Exception('Kayıt oluşturulamadı.');
    }

    final needsApproval = role == 'driver' || role == 'customer';

    final appUser = AppUser(
      uid: user.uid,
      email: email.trim(),
      name: name.trim(),
      role: role,
      driverId: role == 'driver' ? user.uid : null,
      isApproved: !needsApproval,
    );

    await _db.collection('users').doc(user.uid).set({
      ...appUser.toMap(),
      'uid': user.uid,
      'email': email.trim(),
      'name': name.trim(),
      'role': role,
      'driverId': role == 'driver' ? user.uid : null,
      'isApproved': !needsApproval,
      'approvalStatus': needsApproval ? 'pending' : 'approved',
      'customerPhotoUrl': customerPhotoUrl,
      'genderCheckStatus': role == 'customer' ? 'photo_uploaded' : null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (role == 'driver') {
      await _db.collection('drivers').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone,
        'city': city,
        'age': age,
        'experienceYear': experienceYear,
        'vehicle': {
          'brand': vehicleBrand,
          'model': vehicleModel,
          'plate': vehiclePlate,
        },
        'status': 'pending',
        'isApproved': false,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _db.collection('driver_applications').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone,
        'city': city,
        'age': age,
        'experienceYear': experienceYear,
        'idCardImageUrl': driverIdPhotoUrl,
        'genderCheckStatus': 'manual_required',
        'vehicle': {
          'brand': vehicleBrand,
          'model': vehicleModel,
          'plate': vehiclePlate,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await _auth.signOut();
    return appUser;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}