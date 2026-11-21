import 'package:flutter/foundation.dart';

@immutable
class PartnerSettingsOut {
  const PartnerSettingsOut({
    required this.salonId,
    required this.salonName,
    this.timeZone = 'Asia/Colombo',
  });

  final String salonId;
  final String salonName;
  final String? timeZone;

  factory PartnerSettingsOut.fromJson(Map<String, dynamic> json) => PartnerSettingsOut(
        salonId: (json['salon_id'] ?? json['id'] ?? '') as String,
        salonName: (json['salon_name'] ?? json['name'] ?? '') as String,
        timeZone: json['time_zone'] as String? ?? 'Asia/Colombo',
      );

  Map<String, dynamic> toJson() => {
        'salon_id': salonId,
        'salon_name': salonName,
        'time_zone': timeZone,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PartnerSettingsOut &&
          salonId == other.salonId &&
          salonName == other.salonName &&
          timeZone == other.timeZone;

  @override
  int get hashCode => Object.hash(salonId, salonName, timeZone);
}
