part of '../main.dart';

class User {
  User(
      {required this.id,
      required this.email,
      required this.name,
      required this.role,
      required this.plates,
      this.phone = ''});
  final String id, email, name, role, phone;
  final List<Plate> plates;
  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['_id'] ?? json['id'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        name: (json['fullName'] ?? json['displayName'] ?? 'User').toString(),
        role: (json['role'] ?? 'user').toString(),
        phone: (json['phone'] ?? '').toString(),
        plates: ((json['licensePlates'] as List?) ?? <dynamic>[])
            .whereType<Map>()
            .map((e) => Plate.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class Plate {
  Plate(
      {required this.id,
      required this.number,
      required this.type,
      required this.isDefault});
  final String id, number, type;
  final bool isDefault;
  factory Plate.fromJson(Map<String, dynamic> json) => Plate(
        id: (json['_id'] ?? '').toString(),
        number: (json['plateNumber'] ?? '').toString(),
        type: (json['vehicleType'] ?? 'car').toString(),
        isDefault: json['isDefault'] == true,
      );
}
