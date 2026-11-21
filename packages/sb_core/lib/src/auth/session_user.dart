import 'role.dart';

/// Active authenticated salon session user.
class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.phone,
    this.avatarUrl,
    required this.role,
    required this.salonId,
    required this.salonName,
    required this.timeZone,
    this.staffId,
  });

  final String id;
  final String fullName;
  final String phone;
  final String? avatarUrl;
  final Role role;
  final String salonId;
  final String salonName;
  final String timeZone;
  final String? staffId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'role': role.name,
        'salon_id': salonId,
        'salon_name': salonName,
        'time_zone': timeZone,
        if (staffId != null) 'staff_id': staffId,
      };

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        phone: json['phone'] as String,
        avatarUrl: json['avatar_url'] as String?,
        role: Role.parse(json['role'] as String?) ?? Role.specialist,
        salonId: json['salon_id'] as String,
        salonName: json['salon_name'] as String,
        timeZone: json['time_zone'] as String? ?? 'Asia/Colombo',
        staffId: json['staff_id'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName &&
          phone == other.phone &&
          avatarUrl == other.avatarUrl &&
          role == other.role &&
          salonId == other.salonId &&
          salonName == other.salonName &&
          timeZone == other.timeZone &&
          staffId == other.staffId;

  @override
  int get hashCode => Object.hash(
        id,
        fullName,
        phone,
        avatarUrl,
        role,
        salonId,
        salonName,
        timeZone,
        staffId,
      );
}
