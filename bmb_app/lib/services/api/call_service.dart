import 'dart:async';
import 'dart:convert';
import 'dart:math';
import '../connection/connection_service.dart';
import '../../models/message_model.dart';

enum CallState {
  idle,
  calling,
  connected,
  listening,
  processing,
  speaking,
  ended,
  error,
}

class CallService {
  final ConnectionService _connectionService;
  final StreamController<CallState> _stateController =
      StreamController<CallState>.broadcast();
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();
  final StreamController<MessageModel> _callMessageController =
      StreamController<MessageModel>.broadcast();
  final StreamController<String> _sttController =
      StreamController<String>.broadcast();

  Stream<CallState> get stateStream => _stateController.stream;
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<MessageModel> get callMessageStream => _callMessageController.stream;
  Stream<String> get sttStream => _sttController.stream;

  CallState _state = CallState.idle;
  CallState get currentState => _state;

  String _currentTabId = '';
  String get currentTabId => _currentTabId;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSilenced = false;
  bool get isSilenced => _isSilenced;

  bool _speakerOn = false;
  bool get speakerOn => _speakerOn;

  DateTime? _callStartTime;
  DateTime? get callStartTime => _callStartTime;
  Duration get callDuration {
    if (_callStartTime == null) return Duration.zero;
    return DateTime.now().difference(_callStartTime!);
  }

  final List<MessageModel> _messages = [];
  List<MessageModel> get messages => List.unmodifiable(_messages);

  Timer? _vadTimer;
  double _vadLevel = 0.0;

  CallService(this._connectionService) {
    _connectionService.messageStream.listen(_handleCallMessage);
  }

  void _handleCallMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'audio_chunk':
        // Handle incoming audio chunk
        final audioData = message['audio'] as String?;
        if (audioData != null) {
          // Play audio chunk
        }
        break;
      case 'speech_end':
        _setState(CallState.processing);
        break;
      case 'stt_partial':
        final text = message['text'] as String? ?? '';
        _sttController.add(text);
        break;
      case 'stt_final':
        final text = message['text'] as String? ?? '';
        _addCallMessage(MessageModel(
          text: text,
          sender: MessageSender.user,
          type: MessageType.text,
        ));
        _setState(CallState.processing);
        break;
      case 'agent_status':
        final status = message['status'] as String?;
        switch (status) {
          case 'listening':
            _setState(CallState.listening);
            break;
          case 'processing':
            _setState(CallState.processing);
            break;
          case 'speaking':
            _setState(CallState.speaking);
            break;
          case 'error':
            _setState(CallState.error);
            break;
        }
        break;
      case 'agent_response':
        final text = message['text'] as String? ?? '';
        _addCallMessage(MessageModel(
          text: text,
          sender: MessageSender.agent,
          type: MessageType.text,
        ));
        _setState(CallState.speaking);
        break;
      case 'call_end':
        _onCallEnded();
        break;
      case 'call_error':
        _setState(CallState.error);
        break;
    }
  }

  void _addCallMessage(MessageModel message) {
    _messages.add(message);
    _callMessageController.add(message);
  }

  void startCall(String tabId) {
    _currentTabId = tabId;
    _messages.clear();
    _callStartTime = DateTime.now();
    _setState(CallState.calling);

    _connectionService.sendMessage({
      'type': 'start_call',
      'tab_id': tabId,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Simulate connection established
    Future.delayed(const Duration(seconds: 1), () {
      if (_state == CallState.calling) {
        _setState(CallState.connected);
        _startVADSimulation();
      }
    });
  }

  void _startVADSimulation() {
    _vadTimer?.cancel();
    _vadTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_state == CallState.listening || _state == CallState.connected) {
        // Simulate audio level variation
        _vadLevel = Random().nextDouble() * 0.8;
        _audioLevelController.add(_vadLevel);
      }
    });
  }

  void _stopVADSimulation() {
    _vadTimer?.cancel();
    _vadTimer = null;
  }

  void mute() {
    _isMuted = !_isMuted;
    _connectionService.sendMessage({
      'type': 'mute',
      'muted': _isMuted,
    });
  }

  void silence() {
    _isSilenced = !_isSilenced;
    _connectionService.sendMessage({
      'type': 'silence',
      'silenced': _isSilenced,
    });
  }

  void toggleSpeaker() {
    _speakerOn = !_speakerOn;
  }

  void sendAudioChunk(String base64Audio) {
    _connectionService.sendMessage({
      'type': 'audio_chunk',
      'audio': base64Audio,
      'tab_id': _currentTabId,
    });
  }

  void sendVADEvent(bool isSpeaking) {
    _connectionService.sendMessage({
      'type': 'vad_event',
      'speaking': isSpeaking,
      'tab_id': _currentTabId,
    });
    if (isSpeaking) {
      _setState(CallState.listening);
    }
  }

  void _onCallEnded() {
    _stopVADSimulation();
    _callStartTime = null;
    _isMuted = false;
    _isSilenced = false;
    _setState(CallState.ended);
  }

  void endCall() {
    _connectionService.sendMessage({
      'type': 'end_call',
      'tab_id': _currentTabId,
    });
    _onCallEnded();

    // Reset after brief delay
    Future.delayed(const Duration(seconds: 2), () {
      _setState(CallState.idle);
    });
  }

  void _setState(CallState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _stopVADSimulation();
    _stateController.close();
    _audioLevelController.close();
    _callMessageController.close();
    _sttController.close();
  }
}
