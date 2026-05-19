import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
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
  String _localIp = '';
  Timer? _tunnelRefreshTimer;

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
          _onDisconnected();
          break;
        case svc.ConnectionState.connecting:
          _status = ConnectionStatus.connecting;
          break;
        case svc.ConnectionState.connected:
          _status = ConnectionStatus.connected;
          _startTunnelRefresh();
          break;
        case svc.ConnectionState.error:
          _status = ConnectionStatus.error;
          _errorMessage = 'Connection failed';
          break;
      }
      notifyListeners();
    });
  }

  void _onDisconnected() {
    // Si perdimos conexion, esperar 3s y reconectar refrescando tunnel
    Future.delayed(const Duration(seconds: 3), () {
      if (_status == ConnectionStatus.disconnected && _apiKey.isNotEmpty) {
        connect(forceTunnelRefresh: true);
      }
    });
  }

  void _startTunnelRefresh() {
    _tunnelRefreshTimer?.cancel();
    _tunnelRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshTunnelUrl();
    });
  }

  Future<void> _refreshTunnelUrl() async {
    if (_localIp.isEmpty) return;
    try {
      final client = http.Client();
      final response = await client
          .get(Uri.parse('http://$_localIp:$_port/api/tunnel/refresh'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final tunnelUrl = data['tunnel_url']?.toString() ?? '';
        if (tunnelUrl.isNotEmpty) {
          final newIp = tunnelUrl.replaceAll('https://', '').replaceAll('http://', '');
          if (newIp != _ip) {
            _ip = newIp;
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('paired_ip', _ip);
            // Reconectar con nueva URL
            _connectionService.connect(_ip, _port, _apiKey);
          }
        }
      }
      client.close();
    } catch (_) {
      // No pasa nada, reintenta en 30s
    }
  }

  Future<void> loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    _apiKey = prefs.getString('api_key') ?? '';
    _ip = prefs.getString('paired_ip') ?? '';
    _port = prefs.getInt('paired_port') ?? 8643;
    _deviceName = prefs.getString('device_name') ?? '';
    _localIp = prefs.getString('local_ip') ?? '';

    if (_apiKey.isNotEmpty && _ip.isNotEmpty) {
      notifyListeners();
    }
  }

  Future<bool> pairViaQR({
    required String ip,
    required int port,
    required String deviceName,
    String? tunnelUrl,
    String? localIp,
  }) async {
    _status = ConnectionStatus.connecting;
    _errorMessage = '';
    _ip = tunnelUrl ?? ip;
    _port = port;
    _deviceName = deviceName;
    _localIp = localIp ?? ip;
    notifyListeners();

    // Pairing simplificado
    _apiKey = 'paired_' + DateTime.now().millisecondsSinceEpoch.toString();
    
    // Guardar credenciales
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_key', _apiKey);
    await prefs.setString('paired_ip', _ip);
    await prefs.setInt('paired_port', port);
    await prefs.setString('device_name', deviceName);
    await prefs.setString('local_ip', _localIp);

    // Auto-connect after pairing
    final connected = await connect();
    return connected;
  }

  Future<bool> connect({bool forceTunnelRefresh = false}) async {
    if (_apiKey.isEmpty) return false;

    _status = ConnectionStatus.connecting;
    notifyListeners();

    // Primero intentar con IP local (mas rapido en misma WiFi)
    if (_localIp.isNotEmpty && _ip != _localIp) {
      final localSuccess = await _connectionService.connect(
        _localIp, _port, _apiKey,
      );
      if (localSuccess) {
        _ip = _localIp;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('paired_ip', _ip);
        _status = ConnectionStatus.connected;
        notifyListeners();
        return true;
      }
    }

    // Si perdio conexion y tenemos IP local, refrescar tunnel
    if (forceTunnelRefresh && _localIp.isNotEmpty) {
      try {
        final client = http.Client();
        final refreshUrl = 'http://$_localIp:$_port/api/tunnel/refresh';
        final response = await client.get(Uri.parse(refreshUrl)).timeout(
          const Duration(seconds: 3),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          if (data['tunnel_url'] != null && data['tunnel_url'].toString().isNotEmpty) {
            _ip = data['tunnel_url'].toString().replaceAll('https://', '').replaceAll('http://', '');
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('paired_ip', _ip);
        }
        client.close();
      } catch (_) {}
    }

    final success = await _connectionService.connect(_ip, _port, _apiKey);

    if (success) {
      _status = ConnectionStatus.connected;
    } else {
      // Si fallo con tunnel y tenemos IP local, intentar con IP local directo
      if (_ip != _localIp && _localIp.isNotEmpty) {
        _ip = _localIp;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('paired_ip', _ip);
        final retry = await _connectionService.connect(_ip, _port, _apiKey);
        if (retry) {
          _status = ConnectionStatus.connected;
          notifyListeners();
          return true;
        }
      }
      _errorMessage = 'No se pudo conectar al servidor';
      _status = ConnectionStatus.error;
    }
    notifyListeners();
    return success;
  }

  Future<void> disconnect() async {
    _tunnelRefreshTimer?.cancel();
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
    await prefs.remove('local_ip');
    _apiKey = '';
    _ip = '';
    _port = 8643;
    _deviceName = '';
    _localIp = '';
    _status = ConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    _tunnelRefreshTimer?.cancel();
    _connectionService.dispose();
    super.dispose();
  }
}
