import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/connection/qr_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final rawValue = barcode.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);

    // Parse the QR payload using QRService
    final parsed = QRService.parseQRPayload(rawValue);

    if (parsed == null) {
      // Try raw JSON parsing as fallback
      try {
        final decoded = jsonDecode(rawValue) as Map<String, dynamic>;
        if (decoded['type'] == 'pairing_request') {
          _handleParsedData(
            ip: decoded['ip'] as String? ?? '',
            port: decoded['port'] as int? ?? 8643,
            deviceId: decoded['deviceId'] as String? ?? '',
            rawValue: rawValue,
          );
          return;
        }
      } catch (_) {
        // Not JSON — try bmb:// URI format as fallback
        if (rawValue.startsWith('bmb://')) {
          try {
            final uri = Uri.parse(rawValue);
            _handleParsedData(
              ip: uri.host,
              port: uri.port > 0 ? uri.port : 8643,
              deviceId: uri.queryParameters['deviceId'] ?? '',
              rawValue: rawValue,
            );
            return;
          } catch (_) {}
        }
      }

      _showError('QR inválido. Debe contener datos de conexión JSON o bmb://');
      setState(() => _isProcessing = false);
      return;
    }

    _handleParsedData(
      ip: parsed['ip'] as String? ?? '',
      port: parsed['port'] as int? ?? 8643,
      deviceId: parsed['deviceId'] as String? ?? '',
      rawValue: rawValue,
    );
  }

  void _handleParsedData({
    required String ip,
    required int port,
    required String deviceId,
    required String rawValue,
  }) {
    if (ip.isEmpty) {
      _showError('El QR no contiene una IP válida');
      setState(() => _isProcessing = false);
      return;
    }

    final deviceName = deviceId.isNotEmpty
        ? deviceId
        : 'Android ${DateTime.now().millisecondsSinceEpoch}';

    // Connect using the parsed data
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    connProv.pairViaQR(
      ip: ip,
      port: port,
      deviceName: deviceName,
    ).then((success) {
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _isProcessing = false;
        });
        _showError(
          connProv.errorMessage.isNotEmpty
              ? connProv.errorMessage
              : 'No se pudo conectar a $ip:$port',
        );
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _toggleTorch() {
    _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Escanear QR',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleTorch,
            tooltip: 'Linterna',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            // FittedBox ensures the camera preview fills the screen
            fit: BoxFit.cover,
          ),

          // Scanner overlay — animated scan frame
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF8300e9).withOpacity(0.6),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white.withOpacity(0.3),
                      size: 64,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Apunta al código QR',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading overlay
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF8300e9),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Conectando...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
