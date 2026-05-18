import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/connection/connection_service.dart' as svc;

enum ConnectionStatus { disconnected, connecting, connected, error }

class ConnectionProvider extends ChangeNotifier {
  final svc.ConnectionService _connectionService = svc.ConnectionService();
  ConnectionStatus _status = ConnectionStatus.disconnected;
  String _ip = '';
  int _port = 8643;
  String _apiKey = '';
  String _deviceName = '';
  String _errorMessage = '';

  ConnectionStatus get status => _status;
  String get ip => _ip;
  int get port => _port;
  String get apiKey => _apiKey;
  String get deviceName => _deviceName;
  String get errorMessage => _errorMessage;
  svc.ConnectionService get service => _connectionService;
  bool get isConnected => _status == ConnectionStatus.connected;
  bool get isPaired => _apiKey.isNotEmpty;

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
          _errorMessage = 'Connection failed';
          break;
      }
      notifyListeners();
    });
  }

  Future<void> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key') ?? '';
    _ip = prefs.getString('paired_ip') ?? '';
    _port = prefs.getInt('paired_port') ?? 8643;
    _deviceName = prefs.getString('device_name') ?? '';

    if (_apiKey.isNotEmpty && _ip.isNotEmpty) {
      notifyListeners();
    }
  }

  Future<bool> pairViaQR({
    required String ip,
    required int port,
    required String deviceName,
  }) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = '';
    _ip = ip;
    _port = port;
    _deviceName = deviceName;
    notifyListeners();

    // Pairing simplificado: conecta directo, sin token
    _apiKey = 'paired_' + DateTime.now().millisecondsSinceEpoch.toString();
    
    // Guardar credenciales
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKey);
    await prefs.setString('paired_ip', ip);
    await prefs.setInt('paired_port', port);
    await prefs.setString('device_name', deviceName);

    // Auto-connect after pairing
    final connected = await connect();
    return connected;
  }

  Future<bool> connect() async {
    if (_apiKey.isEmpty) return false;

    _status = ConnectionStatus.connecting;
    notifyListeners();

    final success = await _connectionService.connect(
      _ip,
      _port,
      _apiKey,
    );

    if (success) {
      _status = ConnectionStatus.connected;
    } else {
      _errorMessage = 'No se pudo conectar al servidor';
      _status = ConnectionStatus.error;
    }
    notifyListeners();
    return success;
  }

  Future<void> disconnect() async {
    _connectionService.disconnect();
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  Future<void> clearPairing() async {
    await disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_key');
    await prefs.remove('paired_ip');
    await prefs.remove('paired_port');
    await prefs.remove('device_name');
    _apiKey = '';
    _ip = '';
    _port = 8643;
    _deviceName = '';
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectionService.dispose();
    super.dispose();
  }
}
