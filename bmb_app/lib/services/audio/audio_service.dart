import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

/// AudioService handles audio recording and playback.
/// On desktop platforms, recording may not be available, only playback.
class AudioService {
  bool _isRecording = false;
  bool _isPlaying = false;
  double _currentAudioLevel = 0.0;
  Timer? _levelTimer;

  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();
  final StreamController<Uint8List> _audioDataController =
      StreamController<Uint8List>.broadcast();

  Stream<double> get audioLevelStream => _audioLevelController.stream;
  Stream<Uint8List> get audioDataStream => _audioDataController.stream;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  double get currentAudioLevel => _currentAudioLevel;
  bool get canRecord => !kIsWeb; // Desktop/mobile can record

  /// Start recording audio input.
  Future<bool> record() async {
    if (_isRecording || !canRecord) return false;

    _isRecording = true;
    _startLevelSimulation();
    return true;
  }

  /// Stop recording.
  Future<Uint8List?> stop() async {
    if (!_isRecording) return null;

    _isRecording = false;
    _stopLevelSimulation();

    // Return dummy data for now - real implementation would use platform channels
    return Uint8List(0);
  }

  /// Play audio data.
  Future<void> play(Uint8List audioData) async {
    if (_isPlaying) return;
    _isPlaying = true;

    // Simulate playback completion
    await Future.delayed(const Duration(seconds: 1));
    _isPlaying = false;
  }

  /// Stop playback.
  void stopPlayback() {
    _isPlaying = false;
  }

  void _startLevelSimulation() {
    _levelTimer?.cancel();
    _levelTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!_isRecording) return;
      _currentAudioLevel = Random().nextDouble() * 0.7 + 0.1;
      _audioLevelController.add(_currentAudioLevel);
    });
  }

  void _stopLevelSimulation() {
    _levelTimer?.cancel();
    _levelTimer = null;
    _currentAudioLevel = 0.0;
    _audioLevelController.add(0.0);
  }

  void dispose() {
    _stopLevelSimulation();
    _audioLevelController.close();
    _audioDataController.close();
  }
}
