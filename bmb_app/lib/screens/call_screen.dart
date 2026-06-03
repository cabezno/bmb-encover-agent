/// Pantalla de llamada de voz en tiempo real con BMB.
///
/// Conecta al WebSocket de llamadas, graba audio del micrófono,
/// lo envía al servidor BMB, y reproduce las respuestas de voz.
///
/// Estados visuales:
/// - Conectando
/// - Escuchando (micrófono activo)
/// - Procesando (BMB piensa)
/// - Hablando (BMB responde)

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Importar el SDK de llamadas
import 'bmb_call_sdk.dart';

/// Pantalla de llamada
class CallScreen extends StatefulWidget {
  final String host;
  final int port;
  final String deviceId;

  const CallScreen({
    super.key,
    this.host = '192.168.1.22',
    this.port = 8644,
    this.deviceId = 'flutter-windows',
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  late BMBCallClient _client;
  bool _isCallActive = false;
  bool _isConnecting = false;
  CallState _callState = CallState.idle;
  String _lastTranscript = '';
  String _lastResponse = '';
  double _audioLevel = 0.0;
  Timer? _levelTimer;

  // Mensajes del chat durante la llamada
  final List<_CallMessage> _messages = [];

  // Animación del micrófono
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Controladores de audio
  // NOTA: Para implementar grabación y reproducción real,
  // necesitás los plugins:
  //   record: ^5.0.4
  //   audioplayers: ^5.2.1
  //   path_provider: ^2.1.1
  //
  // Agregalos al pubspec.yaml

  @override
  void initState() {
    super.initState();

    _client = BMBCallClient(
      host: widget.host,
      port: widget.port,
      deviceId: widget.deviceId,
    );

    // Configurar callbacks
    _client.onStateChange = _onStateChange;
    _client.onTranscript = (text) {
      setState(() {
        _lastTranscript = text;
        _messages.add(_CallMessage(
          text: text,
          isUser: true,
          time: DateTime.now(),
        ));
      });
    };
    _client.onResponse = (text) {
      setState(() {
        _lastResponse = text;
        _messages.add(_CallMessage(
          text: text,
          isUser: false,
          time: DateTime.now(),
        ));
      });
    };
    _client.onAudioData = _playAudio;
    _client.onError = (error) {
      _showError(error);
    };

    // Animación de pulso para el micrófono
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _levelTimer?.cancel();
    _pulseController.dispose();
    _client.dispose();
    super.dispose();
  }

  // ── Lógica de llamada ──────────────────────────────────────────

  Future<void> _startCall() async {
    setState(() => _isConnecting = true);

    final connected = await _client.connect();
    if (!connected || !mounted) {
      setState(() => _isConnecting = false);
      return;
    }

    _client.startCall();
    _startAudioCapture();
    _startLevelSimulation();

    setState(() {
      _isCallActive = true;
      _isConnecting = false;
      _messages.add(_CallMessage(
        text: '📞 Llamada iniciada',
        isUser: false,
        time: DateTime.now(),
        isSystem: true,
      ));
    });

    // Feedback táctil
    HapticFeedback.mediumImpact();
  }

  Future<void> _endCall() async {
    _levelTimer?.cancel();
    _stopAudioCapture();
    await _client.endCall();

    setState(() {
      _isCallActive = false;
      _callState = CallState.idle;
      _messages.add(_CallMessage(
        text: '📞 Llamada finalizada',
        isUser: false,
        time: DateTime.now(),
        isSystem: true,
      ));
    });

    HapticFeedback.mediumImpact();
  }

  // ── Audio (placeholder - implementar con plugins reales) ────────

  // TODO: Implementar con record package
  void _startAudioCapture() {
    // Ejemplo con record package:
    // _recorder = AudioRecorder();
    // _recorder.startStream(  
    //   const RecordConfig(
    //     encoder: AudioEncoder.pcm16bits,
    //     sampleRate: 16000,
    //     numChannels: 1,
    //   ),
    // ).listen((data) {
    //   _client.sendAudio(data);
    // });

    debugPrint('🎤 Captura de audio iniciada (placeholder)');
  }

  void _stopAudioCapture() {
    debugPrint('🛑 Captura de audio detenida');
  }

  void _playAudio(Uint8List audioData) {
    // TODO: Implementar con audioplayers package
    // final player = AudioPlayer();
    // final tempDir = await getTemporaryDirectory();
    // final file = File('${tempDir.path}/response_${DateTime.now().millisecondsSinceEpoch}.wav');
    // await file.writeAsBytes(audioData);
    // await player.play(DeviceFileSource(file.path));

    debugPrint('🔊 Reproduciendo audio: ${audioData.length} bytes');
  }

  // ── Simulación de nivel de audio (placeholder) ─────────────────

  void _startLevelSimulation() {
    _levelTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_callState == CallState.listening) {
        setState(() {
          _audioLevel = Random().nextDouble() * 0.8 + 0.2;
        });
      } else {
        setState(() => _audioLevel = 0.1);
      }
    });
  }

  // ── Handlers ────────────────────────────────────────────────────

  void _onStateChange(CallState state) {
    setState(() => _callState = state);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────

  String _getStateLabel() {
    switch (_callState) {
      case CallState.idle:
        return 'Inactivo';
      case CallState.connecting:
        return 'Conectando...';
      case CallState.connected:
        return 'Conectado';
      case CallState.listening:
        return 'Escuchando... 🎤';
      case CallState.processing:
        return 'Procesando... 🤔';
      case CallState.speaking:
        return 'Hablando... 🔊';
      case CallState.disconnected:
        return 'Desconectado';
    }
  }

  Color _getStateColor() {
    switch (_callState) {
      case CallState.listening:
        return Colors.green;
      case CallState.processing:
        return Colors.orange;
      case CallState.speaking:
        return Colors.blue;
      case CallState.connected:
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('BMB Llamada'),
        backgroundColor: const Color(0xFF0F0F23),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_isCallActive)
            IconButton(
              icon: const Icon(Icons.call_end, color: Colors.red),
              onPressed: _endCall,
              tooltip: 'Finalizar llamada',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Estado de la llamada ─────────────────────────
          _buildCallStatus(),

          // ── Mensajes ──────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : _buildMessages(),
          ),

          // ── Botón de llamada ──────────────────────────────
          _buildCallButton(),
        ],
      ),
    );
  }

  Widget _buildCallStatus() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Indicador de estado animado
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _callState == CallState.listening
                    ? _pulseAnimation.value
                    : 1.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getStateColor().withOpacity(0.2),
                    border: Border.all(
                      color: _getStateColor(),
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _getIconForState(),
                    color: _getStateColor(),
                    size: 40,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _getStateLabel(),
            style: TextStyle(
              color: _getStateColor(),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_callState == CallState.listening)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Habla ahora',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 14,
                ),
              ),
            ),
          if (_lastTranscript.isNotEmpty && _callState == CallState.processing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '"$_lastTranscript"',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (_lastResponse.isNotEmpty && _callState == CallState.speaking)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _lastResponse,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIconForState() {
    switch (_callState) {
      case CallState.listening:
        return Icons.mic;
      case CallState.processing:
        return Icons.psychology;
      case CallState.speaking:
        return Icons.volume_up;
      case CallState.connected:
        return Icons.headset_mic;
      case CallState.connecting:
        return Icons.wifi_find;
      default:
        return Icons.phone;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_in_talk,
            size: 60,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Presioná el botón para iniciar\nuna llamada con BMB',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        if (msg.isSystem) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              msg.text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          );
        }
        return Align(
          alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: msg.isUser
                  ? const Color(0xFF2D2D44)
                  : const Color(0xFF1B5E20).withOpacity(0.3),
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: msg.isUser ? const Radius.circular(4) : null,
                bottomLeft: !msg.isUser ? const Radius.circular(4) : null,
              ),
            ),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: Text(
              msg.text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallButton() {
    return Container(
      padding: const EdgeInsets.all(30),
      child: GestureDetector(
        onTap: _isCallActive ? _endCall : (_isConnecting ? null : _startCall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isCallActive ? Colors.red : Colors.green,
            boxShadow: [
              BoxShadow(
                color: (_isCallActive ? Colors.red : Colors.green)
                    .withOpacity(0.4),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            _isCallActive ? Icons.call_end : Icons.call,
            color: Colors.white,
            size: 36,
          ),
        ),
      ),
    );
  }
}

/// Modelo de mensaje
class _CallMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  final bool isSystem;

  _CallMessage({
    required this.text,
    required this.isUser,
    required this.time,
    this.isSystem = false,
  });
}

/// AnimatedBuilder personalizado para usar Animation
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required super.listenable,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, null);
  }
}
