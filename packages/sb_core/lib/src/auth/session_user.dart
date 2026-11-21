import 'role.dart';

/// Active authenticated salon session user (derived from the partner login `user`).
class SessionUser {
  const SessionUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.salonId,
    required this.salonName,
    this.timeZone = defaultTimeZone,
    this.staffId,
  });

  /// Used until the API exposes the salon time zone to every account (plan Gap C).
  static const defaultTimeZone = 'Asia/Colombo';

  final String id;
  final String fullName;
  final Role role;
  final String salonId;
  final String salonName;
  final String timeZone;
  final String? staffId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'role': role.name,
    'salon_id': salonId,
    'salon_name': salonName,
    'time_zone': timeZone,
    if (staffId != null) 'staff_id': staffId,
  };

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: json['id'] as String,
    fullName: json['full_name'] as String? ?? '',
    role: Role.parse(json['role'] as String?) ?? Role.specialist,
    salonId: json['salon_id'] as String,
    salonName: json['salon_name'] as String,
    timeZone: json['time_zone'] as String? ?? defaultTimeZone,
    staffId: json['staff_id'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          fullName == other.fullName &&
          role == other.role &&
          salonId == other.salonId &&
          salonName == other.salonName &&
          timeZone == other.timeZone &&
          staffId == other.staffId;

  @override
  int get hashCode => Object.hash(id, fullName, role, salonId, salonName, timeZone, staffId);
}
