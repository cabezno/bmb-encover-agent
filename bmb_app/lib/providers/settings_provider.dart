import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  // Voice settings
  String _ttsModel = 'auto';
  String _language = 'es';
  bool _pushToTalk = true;
  bool _interruptMode = true;
  double _voiceSpeed = 1.0;
  double _volume = 0.8;

  // Display settings
  bool _isDarkMode = true;
  bool _consoleVisible = false;

  // Getters
  String get ttsModel => _ttsModel;
  String get language => _language;
  bool get pushToTalk => _pushToTalk;
  bool get interruptMode => _interruptMode;
  double get voiceSpeed => _voiceSpeed;
  double get volume => _volume;
  bool get isDarkMode => _isDarkMode;
  bool get consoleVisible => _consoleVisible;

  List<String> get ttsModelOptions => ['piper', 'kokoro', 'auto'];
  List<String> get languageOptions => ['es', 'en'];

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _ttsModel = prefs.getString('tts_model') ?? 'auto';
      _language = prefs.getString('language') ?? 'es';
      _pushToTalk = prefs.getBool('push_to_talk') ?? true;
      _interruptMode = prefs.getBool('interrupt_mode') ?? true;
      _voiceSpeed = prefs.getDouble('voice_speed') ?? 1.0;
      _volume = prefs.getDouble('volume') ?? 0.8;
      _isDarkMode = prefs.getBool('is_dark_mode') ?? true;
      _consoleVisible = prefs.getBool('console_visible') ?? false;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is int) await prefs.setInt(key, value);
  }

  Future<void> setTtsModel(String model) async {
    _ttsModel = model;
    await _saveSetting('tts_model', model);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _saveSetting('language', lang);
    notifyListeners();
  }

  Future<void> setPushToTalk(bool value) async {
    _pushToTalk = value;
    await _saveSetting('push_to_talk', value);
    notifyListeners();
  }

  Future<void> setInterruptMode(bool value) async {
    _interruptMode = value;
    await _saveSetting('interrupt_mode', value);
    notifyListeners();
  }

  Future<void> setVoiceSpeed(double speed) async {
    _voiceSpeed = speed.clamp(0.5, 2.0);
    await _saveSetting('voice_speed', _voiceSpeed);
    notifyListeners();
  }

  Future<void> setVolume(double vol) async {
    _volume = vol.clamp(0.0, 1.0);
    await _saveSetting('volume', _volume);
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    await _saveSetting('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> setConsoleVisible(bool visible) async {
    _consoleVisible = visible;
    await _saveSetting('console_visible', visible);
    notifyListeners();
  }
}
