import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/connection_provider.dart';
import '../../themes/app_theme.dart';

/// Displays a large QR code that the companion app (mobile) scans to pair.
///
/// The screen:
/// 1. Connects to the server (via ConnectionProvider).
/// 2. Fetches pairing token from GET /api/pair/token.
/// 3. Shows the QR image at /api/pair/token?format=png using Image.network.
/// 4. Auto-refreshes every 10 seconds.
/// 5. Shows the tunnel URL below the QR.
class QRDisplayScreen extends StatefulWidget {
  const QRDisplayScreen({super.key});

  @override
  State<QRDisplayScreen> createState() => _QRDisplayScreenState();
}

class _QRDisplayScreenState extends State<QRDisplayScreen> {
  Timer? _refreshTimer;
  String? _tunnelUrl;
  String? _serverBaseUrl;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _connectAndFetch();
    // Auto-refresh every 10 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _refreshQR(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _connectAndFetch() async {
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);

    if (connProv.status == ConnectionStatus.disconnected ||
        connProv.status == ConnectionStatus.error) {
      setState(() {
        _isConnecting = true;
        _errorMessage = null;
      });

      final connected = await connProv.connect();
      if (!mounted) return;

      if (!connected) {
        setState(() {
          _isConnecting = false;
          _errorMessage = connProv.errorMessage.isNotEmpty
              ? connProv.errorMessage
              : 'No se pudo conectar al servidor';
        });
        return;
      }
    }

    setState(() {
      _isConnecting = false;
      _serverBaseUrl = 'http://${connProv.ip}:${connProv.port}';
      _tunnelUrl = _serverBaseUrl;
    });
  }

  Future<void> _refreshQR() async {
    // Just rebuild to trigger Image.network refresh with updated timestamp
    if (!mounted) return;
    setState(() {
      // Trigger rebuild by updating a dummy state value
    });

    // Optionally re-fetch tunnel URL from server
    try {
      final connProv = Provider.of<ConnectionProvider>(context, listen: false);
      if (connProv.isConnected) {
        // Tunnel URL could come from a separate endpoint; use server base for now
        _tunnelUrl = 'http://${connProv.ip}:${connProv.port}';
      }
    } catch (_) {}
  }

  String get _qrImageUrl {
    if (_serverBaseUrl == null) return '';
    // Add a timestamp to bust cache every refresh
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$_serverBaseUrl/api/pair/token?format=png&_=$ts';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Vincular Dispositivo'),
        backgroundColor: AppTheme.darkBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Refrescar QR',
            onPressed: _refreshQR,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8300e9), Color(0xFF5a00a0)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8300e9).withOpacity(0.3),
                        blurRadius: 24,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Escanea este código QR',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Usa la app móvil BMB para escanear\nel código y vincular tu dispositivo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),

                // Connection / error states
                if (_isConnecting) ...[
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF8300e9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Conectando al servidor...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ] else if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _connectAndFetch();
                      },
                      child: const Text('Reintentar'),
                    ),
                  ),
                ] else if (_serverBaseUrl != null) ...[
                  // QR Code image - large for Windows desktop
                  Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8300e9).withOpacity(0.15),
                          blurRadius: 32,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.network(
                        _qrImageUrl,
                        width: 300,
                        height: 300,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF8300e9),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.qr_code_2_rounded,
                                size: 80,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No se pudo cargar el QR',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.withOpacity(0.5),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tunnel URL display
                  if (_tunnelUrl != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.link,
                                size: 16,
                                color: const Color(0xFF00E676),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Servidor',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withOpacity(0.5),
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _tunnelUrl!,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF00E676),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El QR se actualiza automáticamente cada 10 segundos',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 32),

                // Bottom pairing info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.white.withOpacity(0.4),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Asegúrate de que el dispositivo móvil esté en la misma red WiFi que este equipo.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.4),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
