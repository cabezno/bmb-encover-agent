import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/connection_model.dart';
import '../services/connection/connection_service.dart' as svc;
import '../services/connection/qr_service.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionProvider extends ChangeNotifier {
  final svc.ConnectionService _connectionService = svc.ConnectionService();
  ConnectionStatus _status = ConnectionStatus.disconnected;
  ConnectionModel _connection = ConnectionModel();
  String _errorMessage = '';
  // DeepSeek API key (for the agent, not the server)
  String _deepSeekApiKey = '';

  ConnectionStatus get status => _status;
  ConnectionModel get connection => _connection;
  String get errorMessage => _errorMessage;
  svc.ConnectionService get service => _connectionService;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isPaired => _connection.apiKey.isNotEmpty;
  String get deepSeekApiKey => _deepSeekApiKey;
  String get accessToken => _connection.accessToken;

  ConnectionProvider() {
    _connectionService.stateStream.listen((state) {
      switch (state) {
        case svc.ConnectionState.disconnected:
          _status = ConnectionStatus.disconnected;
          break;
        case svc.ConnectionState.connecting:
          _status = ConnectionStatus.connecting;
          break;
        case svc.ConnectionState.connected:
          _status = ConnectionStatus.connected;
          break;
        case svc.ConnectionState.error:
          _status = ConnectionStatus.error;
          _errorMessage = _connectionService.lastAuthError ?? 'Connection failed';
          break;
      }
      notifyListeners();
    });
  }

  Future<void> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('api_key') ?? '';
    final ip = prefs.getString('paired_ip') ?? '';
    final port = prefs.getInt('paired_port') ?? 8765;
    final deviceName = prefs.getString('device_name') ?? '';
    final deviceId = prefs.getString('device_id') ?? '';
    final accessToken = prefs.getString('access_token') ?? '';
    _deepSeekApiKey = prefs.getString('deepseek_api_key') ?? '';

    if (apiKey.isNotEmpty && ip.isNotEmpty) {
      _connection = ConnectionModel(
        tailscaleIp: ip,
        port: port,
        apiKey: apiKey,
        accessToken: accessToken,
        deviceName: deviceName,
        deviceId: deviceId,
      );
      notifyListeners();
    }
  }

  /// Save DeepSeek API key to SharedPreferences
  Future<void> setDeepSeekApiKey(String key) async {
    _deepSeekApiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deepseek_api_key', key);
    notifyListeners();
  }

  /// Save Access Token to SharedPreferences and connection model
  Future<void> setAccessToken(String token) async {
    _connection = _connection.copyWith(accessToken: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    notifyListeners();
  }

  /// Pair via scanned QR data (bmb:// URI parsed already)
  Future<bool> pairWithQRData({
    required String ip,
    required int port,
    required String pairToken,
    required String deviceName,
    String? accessToken,
  }) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = '';
    notifyListeners();

    final qrService = QRService();
    final apiKey = await qrService.pairWithServer(
      ip: ip,
      port: port,
      token: pairToken,
      deviceName: deviceName,
      accessToken: accessToken,
    );

    if (apiKey == null) {
      _status = ConnectionStatus.error;
      _errorMessage = 'No se pudo establecer el pairing con el servidor. '
          'Verifica que el servidor esté en ejecución y el QR sea válido.';
      notifyListeners();
      return false;
    }

    _connection = ConnectionModel(
      tailscaleIp: ip,
      port: port,
      apiKey: apiKey,
      accessToken: accessToken ?? '',
      deviceName: deviceName,
    );

    // Auto-connect after pairing
    final connected = await connect();
    return connected;
  }

  Future<bool> pairViaQR({
    required String ip,
    required int port,
    required String deviceName,
  }) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = '';
    notifyListeners();

    final qrService = QRService();
    final apiKey = await qrService.pairWithServer(
      ip: ip,
      port: port,
      token: '',  // legacy fallback — will fail gracefully
      deviceName: deviceName,
    );

    if (apiKey == null) {
      _status = ConnectionStatus.error;
      _errorMessage = 'No se pudo establecer el pairing';
      notifyListeners();
      return false;
    }

    _connection = ConnectionModel(
      tailscaleIp: ip,
      port: port,
      apiKey: apiKey,
      deviceName: deviceName,
    );

    final connected = await connect();
    return connected;
  }

  Future<bool> connect() async {
    if (_connection.apiKey.isEmpty) return false;

    _status = ConnectionStatus.connecting;
    notifyListeners();

    final success = await _connectionService.connect(
      _connection.tailscaleIp,
      _connection.port,
      _connection.apiKey,
      accessToken: _connection.accessToken.isNotEmpty
          ? _connection.accessToken
          : null,
    );

    if (success) {
      _connection = _connection.copyWith(isConnected: true);
      _status = ConnectionStatus.connected;
    } else {
      _errorMessage =
          _connectionService.lastAuthError ?? 'No se pudo conectar al servidor';
      _status = ConnectionStatus.error;
    }
    notifyListeners();
    return success;
  }

  Future<void> disconnect() async {
    _connectionService.disconnect();
    _connection = _connection.copyWith(isConnected: false);
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> clearPairing() async {
    await disconnect();
    await QRService.clearCredentials();
    _connection = ConnectionModel();
    _status = ConnectionStatus.disconnected;
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionService.dispose();
    super.dispose();
  }
}
