class ESP32Watch {
  final String id;
  final String name;
  final String ipAddress;
  final String macAddress;
  final String color;
  final Map<String, dynamic> safeZone;
  bool isConnected;
  int batteryLevel;
  bool isSOSActive;
  String status;
  DateTime lastUpdate;
  Map<String, dynamic> location;

  ESP32Watch({
    required this.id,
    required this.name,
    this.ipAddress = '',
    this.macAddress = '',
    required this.color,
    required this.safeZone,
    this.isConnected = false,
    this.batteryLevel = 100,
    this.isSOSActive = false,
    this.status = 'offline',
    DateTime? lastUpdate,
    Map<String, dynamic>? location,
  }) : lastUpdate = lastUpdate ?? DateTime.now(),
       location = location ?? {'latitude': 0.0, 'longitude': 0.0};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ipAddress': ipAddress,
      'macAddress': macAddress,
      'color': color,
      'safeZone': safeZone,
      'isConnected': isConnected,
      'batteryLevel': batteryLevel,
      'isSOSActive': isSOSActive,
      'status': status,
      'lastUpdate': lastUpdate.toIso8601String(),
      'location': location,
    };
  }

  factory ESP32Watch.fromJson(Map<String, dynamic> json) {
    return ESP32Watch(
      id: json['id'] as String,
      name: json['name'] as String,
      ipAddress: json['ipAddress'] as String? ?? '',
      macAddress: json['macAddress'] as String? ?? '',
      color: json['color'] as String,
      safeZone: Map<String, dynamic>.from(json['safeZone'] as Map),
      isConnected: json['isConnected'] as bool? ?? false,
      batteryLevel: json['batteryLevel'] as int? ?? 100,
      isSOSActive: json['isSOSActive'] as bool? ?? false,
      status: json['status'] as String? ?? 'offline',
      lastUpdate:
          json['lastUpdate'] != null
              ? DateTime.parse(json['lastUpdate'] as String)
              : DateTime.now(),
      location: Map<String, dynamic>.from(
        json['location'] as Map? ?? {'latitude': 0.0, 'longitude': 0.0},
      ),
    );
  }
}
