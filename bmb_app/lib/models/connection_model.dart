class ConnectionModel {
  final String tailscaleIp;
  final int port;
  final String apiKey;
  final String accessToken;
  final String deviceId;
  final String deviceName;
  final bool isConnected;

  ConnectionModel({
    this.tailscaleIp = '',
    this.port = 8765,
    this.apiKey = '',
    this.accessToken = '',
    this.deviceId = '',
    this.deviceName = '',
    this.isConnected = false,
  });

  ConnectionModel copyWith({
    String? tailscaleIp,
    int? port,
    String? apiKey,
    String? accessToken,
    String? deviceId,
    String? deviceName,
    bool? isConnected,
  }) {
    return ConnectionModel(
      tailscaleIp: tailscaleIp ?? this.tailscaleIp,
      port: port ?? this.port,
      apiKey: apiKey ?? this.apiKey,
      accessToken: accessToken ?? this.accessToken,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tailscaleIp': tailscaleIp,
      'port': port,
      'apiKey': apiKey,
      'accessToken': accessToken,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'isConnected': isConnected,
    };
  }

  factory ConnectionModel.fromJson(Map<String, dynamic> json) {
    return ConnectionModel(
      tailscaleIp: json['tailscaleIp'] as String? ?? '',
      port: json['port'] as int? ?? 8765,
      apiKey: json['apiKey'] as String? ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '',
      isConnected: json['isConnected'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ConnectionModel{tailscaleIp: $tailscaleIp, port: $port, '
        'deviceId: $deviceId, deviceName: $deviceName, isConnected: $isConnected}';
  }
}
