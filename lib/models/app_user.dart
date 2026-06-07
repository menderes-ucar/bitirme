class AppUser {
  final String uid;
  final String email;
  final String name;
  final String role;
  final String? driverId;
  final bool isApproved;

  const AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    this.driverId,
    required this.isApproved,
  });

  bool get isAdmin => role == 'admin';
  bool get isDriver => role == 'driver';
  bool get isCustomer => role == 'customer';

  factory AppUser.fromMap(
      String uid,
      Map<String, dynamic> map,
      ) {
    return AppUser(
      uid: uid,
      email: (map['email'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      role: (map['role'] ?? 'customer').toString(),
      driverId: map['driverId']?.toString(),
      isApproved: map['isApproved'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'driverId': driverId,
      'isApproved': isApproved,
    };
  }
}