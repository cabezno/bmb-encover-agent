/// SDK de llamadas de voz BMB — Conecta apps Flutter con BMB Backend.
///
/// Uso:
/// ```dart
/// final call = BMBCallClient(
///   host: '192.168.1.22',
///   port: 8644,
///   deviceId: 'android-phone',
/// );
///
/// await call.connect();
/// call.startCall();
///
/// // Escuchar eventos
/// call.onTranscript = (text) => print('Usuario: $text');
/// call.onResponse = (text) => print('BMB: $text');
/// call.onAudioData = (bytes) => playAudio(bytes);
/// call.onStateChange = (state) => updateUI(state);
///
/// // Enviar audio
/// call.sendAudio(pcmBytes);
///
/// await call.endCall();
/// await call.disconnect();
/// ```

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

/// Estados de la llamada
enum CallState {
  idle,
  connecting,
  connected,
  listening,
  processing,
  speaking,
  disconnected,
}

/// Eventos que emite el cliente
class CallEvent {
  final String type;
  final Map<String, dynamic> data;

  CallEvent(this.type, this.data);
}

/// Cliente de llamadas BMB
class BMBCallClient {
  final String host;
  final int port;
  final String deviceId;
  WebSocket? _ws;
  CallState _state = CallState.idle;
  String? _sessionId;
  Timer? _pingTimer;

  // Callbacks
  void Function(String text)? onTranscript;
  void Function(String text)? onResponse;
  void Function(Uint8List audio)? onAudioData;
  void Function(CallState state)? onStateChange;
  void Function(CallEvent event)? onEvent;
  void Function(String error)? onError;

  BMBCallClient({
    required this.host,
    this.port = 8644,
    this.deviceId = 'flutter-device',
  });

  CallState get state => _state;
  String? get sessionId => _sessionId;
  bool get isConnected => _state == CallState.connected ||
      _state == CallState.listening ||
      _state == CallState.processing ||
      _state == CallState.speaking;

  /// Conectar al servidor de llamadas BMB
  Future<bool> connect() async {
    _setState(CallState.connecting);
    final uri = Uri.parse('ws://$host:$port/ws/call?device=$deviceId');
    
    try {
      _ws = await WebSocket.connect(uri.toString());
      _setupListeners();
      _startPing();
      _setState(CallState.connected);
      return true;
    } catch (e) {
      _setState(CallState.disconnected);
      onError?.call('Error conectando: $e');
      return false;
    }
  }

  /// Configurar listeners del WebSocket
  void _setupListeners() {
    _ws?.listen(
      (data) {
        if (data is String) {
          _handleJson(data);
        } else if (data is List<int>) {
          _handleAudio(Uint8List.fromList(data));
        }
      },
      onError: (error) {
        onError?.call('WS Error: $error');
        _setState(CallState.disconnected);
      },
      onDone: () {
        _setState(CallState.disconnected);
      },
    );
  }

  /// Manejar mensajes JSON
  void _handleJson(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final type = data['type'] as String?;

      switch (type) {
        case 'connected':
          _sessionId = data['session_id'] as String?;
          _setState(CallState.connected);
          break;

        case 'state':
          final stateStr = data['state'] as String?;
          switch (stateStr) {
            case 'listening':
              _setState(CallState.listening);
              break;
            case 'processing':
              _setState(CallState.processing);
              break;
            case 'speaking':
              _setState(CallState.speaking);
              break;
          }
          break;

        case 'transcript':
          onTranscript?.call(data['text'] as String? ?? '');
          break;

        case 'response_text':
          onResponse?.call(data['text'] as String? ?? '');
          break;

        case 'pong':
          // Pong recibido, todo OK
          break;
      }

      onEvent?.call(CallEvent(type ?? 'unknown', data));
    } catch (e) {
      onError?.call('Error parseando JSON: $e');
    }
  }

  /// Manejar datos de audio binario
  void _handleAudio(Uint8List data) {
    // Header: tipo(4) + tamaño(4) + sample_rate(4) = 12 bytes
    if (data.length >= 12) {
      final header = data.sublist(0, 12);
      final audioData = data.sublist(12);
      onAudioData?.call(audioData);
    } else {
      onAudioData?.call(data);
    }
  }

  /// Enviar chunk de audio al servidor (PCM 16kHz 16-bit mono)
  void sendAudio(Uint8List pcmData) {
    if (_ws != null && _ws!.ready == WebSocketState.open) {
      _ws!.add(pcmData);
    }
  }

  /// Iniciar llamada
  void startCall() {
    _sendJson({'type': 'start_call'});
    _setState(CallState.listening);
  }

  /// Finalizar llamada
  Future<void> endCall() async {
    _sendJson({'type': 'end_call'});
    await disconnect();
  }

  /// Desconectar
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    await _ws?.close();
    _setState(CallState.disconnected);
  }

  /// Enviar JSON al servidor
  void _sendJson(Map<String, dynamic> data) {
    if (_ws != null && _ws!.ready == WebSocketState.open) {
      _ws!.add(jsonEncode(data));
    }
  }

  /// Ping periódico (cada 10s)
  void _startPing() {
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendJson({'type': 'ping'});
    });
  }

  void _setState(CallState newState) {
    _state = newState;
    onStateChange?.call(newState);
  }

  /// Limpiar recursos
  void dispose() {
    _pingTimer?.cancel();
    _ws?.close();
    _state = CallState.disconnected;
  }
}
