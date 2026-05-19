import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class QRService {
  /// Generates a JSON payload that the server side would encode as a QR code.
  /// The payload contains connection info for pairing.
  static String generatePairingPayload({
    required String ip,
    required int port,
    String? deviceId,
  }) {
    final payload = {
      'type': 'pairing_request',
      'ip': ip,
      'port': port,
      'deviceId': deviceId ?? '',
    };
    return jsonEncode(payload);
  }

  /// Parses a scanned QR code payload and extracts connection info.
  static Map<String, dynamic>? parseQRPayload(String rawData) {
    try {
      final decoded = jsonDecode(rawData) as Map<String, dynamic>;
      if (decoded['type'] != 'pairing_request') return null;
      return {
        'ip': decoded['ip'] as String? ?? '',
        'port': decoded['port'] as int? ?? 8765,
        'deviceId': decoded['deviceId'] as String? ?? '',
        'tunnel_url': decoded['tunnel_url'] as String? ?? '',
        'local_ip': decoded['local_ip'] as String? ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  /// Simulates the pairing flow: scan QR -> POST to server -> receive apiKey.
  /// Returns the apiKey on success, null on failure.
  Future<String?> pairWithServer({
    required String ip,
    required int port,
    required String deviceName,
  }) async {
    try {
      // This simulates an HTTP POST to the BMB server's /api/pair endpoint.
      // In a real implementation, this would use http package.
      final uri = Uri.parse('http://$ip:$port/api/pair');
      // For now, we simulate a successful pairing with a mock response.
      // Replace with actual HTTP call in production.
      return await _simulatePairing(ip, port, deviceName);
    } catch (e) {
      return null;
    }
  }

  Future<String?> _simulatePairing(
      String ip, int port, String deviceName) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Generate a mock apiKey
    final apiKey = 'bmb_${DateTime.now().millisecondsSinceEpoch}_${deviceName.hashCode}';

    // Save pairing info
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('paired_ip', ip);
    await prefs.setInt('paired_port', port);
    await prefs.setString('api_key', apiKey);
    await prefs.setString('device_name', deviceName);
    await prefs.setBool('is_paired', true);

    return apiKey;
  }

  /// Checks if the app has already been paired with a server.
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
      'deviceName': prefs.getString('device_name') ?? '',
    };
  }

  /// Clears all stored pairing data.
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('paired_ip');
    await prefs.remove('paired_port');
    await prefs.remove('api_key');
    await prefs.remove('device_name');
    await prefs.remove('is_paired');
  }
}
