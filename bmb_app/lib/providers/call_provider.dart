import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api/call_service.dart';
import '../services/connection/connection_service.dart' as svc;
import '../models/message_model.dart';
import '../models/tab_model.dart';

enum CallScreenState {
  idle,
  calling,
  connected,
  listening,
  processing,
  speaking,
  ended,
  error,
}

class CallProvider extends ChangeNotifier {
  late CallService _callService;
  CallScreenState _state = CallScreenState.idle;
  String _currentTabId = '';
  bool _isMuted = false;
  bool _isSilenced = false;
  bool _speakerOn = false;
  Duration _callDuration = Duration.zero;
  Timer? _durationTimer;
  final List<MessageModel> _callMessages = [];
  double _audioLevel = 0.0;

  CallScreenState get state => _state;
  String get currentTabId => _currentTabId;
  bool get isMuted => _isMuted;
  bool get isSilenced => _isSilenced;
  bool get speakerOn => _speakerOn;
  Duration get callDuration => _callDuration;
  List<MessageModel> get callMessages => List.unmodifiable(_callMessages);
  double get audioLevel => _audioLevel;

  bool get isInCall =>
      _state == CallScreenState.calling ||
      _state == CallScreenState.connected ||
      _state == CallScreenState.listening ||
      _state == CallScreenState.processing ||
      _state == CallScreenState.speaking;

  void initialize(svc.ConnectionService connectionService) {
    _callService = CallService(connectionService);

    _callService.stateStream.listen((callState) {
      switch (callState) {
        case CallState.idle:
          _setState(CallScreenState.idle);
          break;
        case CallState.calling:
          _setState(CallScreenState.calling);
          break;
        case CallState.connected:
          _setState(CallScreenState.connected);
          break;
        case CallState.listening:
          _setState(CallScreenState.listening);
          break;
        case CallState.processing:
          _setState(CallScreenState.processing);
          break;
        case CallState.speaking:
          _setState(CallScreenState.speaking);
          break;
        case CallState.ended:
          _setState(CallScreenState.ended);
          _stopDurationTimer();
          break;
        case CallState.error:
          _setState(CallScreenState.error);
          _stopDurationTimer();
          break;
      }
    });

    _callService.callMessageStream.listen((msg) {
      _callMessages.add(msg);
      notifyListeners();
    });

    _callService.audioLevelStream.listen((level) {
      _audioLevel = level;
      notifyListeners();
    });
  }

  void startCall(String tabId, {String? tabTitle}) {
    _currentTabId = tabId;
    _callMessages.clear();
    _callDuration = Duration.zero;

    _callService.startCall(tabId);
    _startDurationTimer();
  }

  void endCall() {
    _callService.endCall();
  }

  void mute() {
    _callService.mute();
    _isMuted = !_isMuted;
    notifyListeners();
  }

  void silence() {
    _callService.silence();
    _isSilenced = !_isSilenced;
    notifyListeners();
  }

  void toggleSpeaker() {
    _callService.toggleSpeaker();
    _speakerOn = !_speakerOn;
    notifyListeners();
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDuration = _callService.callDuration;
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _setState(CallScreenState newState) {
    _state = newState;
    notifyListeners();
  }

  void reset() {
    _stopDurationTimer();
    _state = CallScreenState.idle;
    _callMessages.clear();
    _isMuted = false;
    _isSilenced = false;
    _speakerOn = false;
    _callDuration = Duration.zero;
    _audioLevel = 0.0;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopDurationTimer();
    _callService.dispose();
    super.dispose();
  }
}
