import 'package:flutter/foundation.dart';

/// `PartnerSalonOut` from the contract.
@immutable
class PartnerSalonOut {
  const PartnerSalonOut({required this.id, required this.name, required this.isOwner});

  final String id;
  final String name;
  final bool isOwner;

  factory PartnerSalonOut.fromJson(Map<String, dynamic> json) =>
      PartnerSalonOut(id: json['id'] as String, name: json['name'] as String, isOwner: json['is_owner'] as bool);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'is_owner': isOwner};

  @override
  bool operator ==(Object other) =>
      other is PartnerSalonOut && id == other.id && name == other.name && isOwner == other.isOwner;

  @override
  int get hashCode => Object.hash(id, name, isOwner);
}

/// `PartnerUserOut` from the contract. Returned only by login, so it is persisted (no secrets).
@immutable
class PartnerUserOut {
  const PartnerUserOut({required this.id, required this.fullName, required this.salons});

  final String id;
  final String? fullName;
  final List<PartnerSalonOut> salons;

  factory PartnerUserOut.fromJson(Map<String, dynamic> json) => PartnerUserOut(
    id: json['id'] as String,
    fullName: json['full_name'] as String?,
    salons: [for (final s in (json['salons'] as List<dynamic>)) PartnerSalonOut.fromJson(s as Map<String, dynamic>)],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'full_name': fullName,
    'salons': [for (final s in salons) s.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is PartnerUserOut && id == other.id && fullName == other.fullName && listEquals(salons, other.salons);

  @override
  int get hashCode => Object.hash(id, fullName, Object.hashAll(salons));
}
