import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionState { disconnected, connecting, connected, error }

class ConnectionService {
  WebSocketChannel? _channel;
  String? _ip;
  int? _port;
  String? _apiKey;
  ConnectionState _state = ConnectionState.disconnected;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _keepAliveTimer;
  Timer? _reconnectTimer;

  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<ConnectionState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  ConnectionState get currentState => _state;

  bool get isConnected => _state == ConnectionState.connected;
  String? get connectedIp => _ip;
  int? get connectedPort => _port;

  String get wsUrl {
    if (_ip == null || _port == null) return '';
    return 'ws://$_ip:$_port/ws?api_key=$_apiKey';
  }

  Future<bool> connect(String ip, int port, String apiKey) async {
    _ip = ip;
    _port = port;
    _apiKey = apiKey;
    _reconnectAttempts = 0;

    return _establishConnection();
  }

  Future<bool> _establishConnection() async {
    _setState(ConnectionState.connecting);

    try {
      final uri = Uri.parse(wsUrl);
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection to be ready
      await _channel!.ready;
      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;
      _startKeepAlive();

      _channel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data as String) as Map<String, dynamic>;
            _handleMessage(decoded);
          } catch (e) {
            // Ignore malformed messages
          }
        },
        onError: (error) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      _setState(ConnectionState.error);
      _scheduleReconnect();
      return false;
    }
  }

  void _handleMessage(Map<String, dynamic> message) {
    // Handle ping/pong
    if (message['type'] == 'ping') {
      sendMessage({'type': 'pong'});
      return;
    }
    _messageController.add(message);
  }

  void _handleDisconnect() {
    _stopKeepAlive();
    _setState(ConnectionState.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: min(2 * _reconnectAttempts, 10));
    _reconnectTimer = Timer(delay, () {
      if (_ip != null && _port != null && _apiKey != null) {
        _establishConnection();
      }
    });
  }

  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_state == ConnectionState.connected) {
        try {
          _channel?.sink.add(jsonEncode({'type': 'ping'}));
        } catch (_) {
          _handleDisconnect();
        }
      }
    });
  }

  void _stopKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
  }

  void _setState(ConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void sendMessage(Map<String, dynamic> message) {
    if (_state != ConnectionState.connected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(message));
    } catch (e) {
      _handleDisconnect();
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _stopKeepAlive();
    _reconnectAttempts = _maxReconnectAttempts; // prevent auto-reconnect
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    _setState(ConnectionState.disconnected);
  }

  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
  }
}
