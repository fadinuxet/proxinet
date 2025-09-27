class VenueSettings {
  final String venueId;
  final bool useDefaultSettings;
  final int locationRange; // in meters
  final int autoDisconnectTimer; // in minutes
  final String locationPrecision; // 'High', 'Medium', 'Low', 'City Level'
  final String customMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VenueSettings({
    required this.venueId,
    this.useDefaultSettings = true,
    this.locationRange = 1000,
    this.autoDisconnectTimer = 60,
    this.locationPrecision = 'City Level',
    this.customMessage = '',
    required this.createdAt,
    required this.updatedAt,
  });

  VenueSettings copyWith({
    String? venueId,
    bool? useDefaultSettings,
    int? locationRange,
    int? autoDisconnectTimer,
    String? locationPrecision,
    String? customMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VenueSettings(
      venueId: venueId ?? this.venueId,
      useDefaultSettings: useDefaultSettings ?? this.useDefaultSettings,
      locationRange: locationRange ?? this.locationRange,
      autoDisconnectTimer: autoDisconnectTimer ?? this.autoDisconnectTimer,
      locationPrecision: locationPrecision ?? this.locationPrecision,
      customMessage: customMessage ?? this.customMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'venueId': venueId,
      'useDefaultSettings': useDefaultSettings,
      'locationRange': locationRange,
      'autoDisconnectTimer': autoDisconnectTimer,
      'locationPrecision': locationPrecision,
      'customMessage': customMessage,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory VenueSettings.fromMap(Map<String, dynamic> map) {
    return VenueSettings(
      venueId: map['venueId'] ?? '',
      useDefaultSettings: map['useDefaultSettings'] ?? true,
      locationRange: map['locationRange'] ?? 1000,
      autoDisconnectTimer: map['autoDisconnectTimer'] ?? 60,
      locationPrecision: map['locationPrecision'] ?? 'City Level',
      customMessage: map['customMessage'] ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] ?? 0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] ?? 0),
    );
  }

  @override
  String toString() {
    return 'VenueSettings(venueId: $venueId, useDefaultSettings: $useDefaultSettings, locationRange: $locationRange, autoDisconnectTimer: $autoDisconnectTimer, locationPrecision: $locationPrecision, customMessage: $customMessage)';
  }
}
