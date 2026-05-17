import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/connection_model.dart';

/// Parse result from a scanned QR code.
class QRParseResult {
  final String ip;
  final int port;
  final String pairToken;
  final String accessToken;

  QRParseResult({
    required this.ip,
    required this.port,
    required this.pairToken,
    required this.accessToken,
  });
}

class QRService {
  /// Parse a BMB QR code URI in format:
  ///   bmb://ip:port/pair?token=xxx&access=yyy
  static QRParseResult? parseQRUri(String rawData) {
    try {
      final uri = Uri.parse(rawData);

      // Scheme must be 'bmb'
      if (uri.scheme != 'bmb') return null;

      final ip = uri.host;
      final port = uri.port;
      final pairToken = uri.queryParameters['token'] ?? '';
      final accessToken = uri.queryParameters['access'] ?? '';

      if (ip.isEmpty || pairToken.isEmpty) return null;

      return QRParseResult(
        ip: ip,
        port: port > 0 ? port : 8765,
        pairToken: pairToken,
        accessToken: accessToken,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse legacy JSON-based QR payload (backward compat).
  static Map<String, dynamic>? parseQRPayload(String rawData) {
    try {
      final decoded = jsonDecode(rawData) as Map<String, dynamic>;
      if (decoded['type'] != 'pairing_request') return null;
      return {
        'ip': decoded['ip'] as String? ?? '',
        'port': decoded['port'] as int? ?? 8765,
        'deviceId': decoded['deviceId'] as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// POST /api/auth to pair with the BMB server using pair token or access token.
  /// Returns the api_key on success, null on failure.
  Future<String?> pairWithServer({
    required String ip,
    required int port,
    required String token,
    required String deviceName,
    String? accessToken,
  }) async {
    try {
      final uri = Uri.parse('http://$ip:$port/api/auth');
      final body = {
        'token': token,
        'device_name': deviceName,
        'device_type': 'flutter_app',
      };

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final apiKey = data['api_key'] as String? ?? data['status'] as String?;

        if (apiKey == null || apiKey.isEmpty) return null;

        // Save credentials
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('paired_ip', ip);
        await prefs.setInt('paired_port', port);
        await prefs.setString('api_key', apiKey);
        await prefs.setString('device_name', deviceName);
        if (accessToken != null && accessToken.isNotEmpty) {
          await prefs.setString('access_token', accessToken);
        }
        await prefs.setBool('is_paired', true);

        return apiKey;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Check if the app has already been paired with a server.
  static Future<bool> isPaired() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_paired') ?? false;
  }

  /// Retrieves stored pairing credentials.
  static Future<Map<String, dynamic>?> getStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final isPaired = prefs.getBool('is_paired') ?? false;
    if (!isPaired) return null;

    return {
      'ip': prefs.getString('paired_ip') ?? '',
      'port': prefs.getInt('paired_port') ?? 8765,
      'apiKey': prefs.getString('api_key') ?? '',
      'accessToken': prefs.getString('access_token') ?? '',
      'deviceName': prefs.getString('device_name') ?? '',
    };
  }

  /// Clears all stored pairing data.
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('paired_ip');
    await prefs.remove('paired_port');
    await prefs.remove('api_key');
    await prefs.remove('access_token');
    await prefs.remove('device_name');
    await prefs.remove('is_paired');
  }
}
