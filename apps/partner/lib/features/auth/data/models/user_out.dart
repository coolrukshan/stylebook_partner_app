import 'package:flutter/foundation.dart';

@immutable
class UserOut {
  const UserOut({
    required this.id,
    required this.phone,
    this.email,
    required this.fullName,
    this.avatarUrl,
    required this.role,
    this.createdAt,
  });

  final String id;
  final String phone;
  final String? email;
  final String fullName;
  final String? avatarUrl;
  final String role;
  final String? createdAt;

  factory UserOut.fromJson(Map<String, dynamic> json) => UserOut(
        id: json['id'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String?,
        fullName: (json['full_name'] ?? json['name'] ?? '') as String,
        avatarUrl: json['avatar_url'] as String?,
        role: json['role'] as String? ?? 'specialist',
        createdAt: json['created_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        if (email != null) 'email': email,
        'full_name': fullName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'role': role,
        if (createdAt != null) 'created_at': createdAt,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserOut &&
          id == other.id &&
          phone == other.phone &&
          email == other.email &&
          fullName == other.fullName &&
          avatarUrl == other.avatarUrl &&
          role == other.role &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(id, phone, email, fullName, avatarUrl, role, createdAt);
}
