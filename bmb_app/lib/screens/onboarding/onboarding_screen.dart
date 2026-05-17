import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../themes/app_theme.dart';
import '../../services/connection/qr_service.dart';
import '../qr/qr_scanner_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _showManualEntry = false;
  bool _isLoading = false;
  String? _errorMessage;

  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8765');
  final _tokenController = TextEditingController();
  final _deviceNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  /// Open QR scanner and parse result
  Future<void> _openQRScanner() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
      ),
    );

    if (result == null || !mounted) return;

    // Parse the bmb:// URI from the QR code
    final parsed = QRService.parseQRUri(result);

    if (parsed == null) {
      setState(() {
        _errorMessage =
            'QR inválido. El código debe tener formato:\n'
            'bmb://ip:port/pair?token=xxx&access=yyy';
      });
      return;
    }

    // Pre-fill manual entry fields from QR data
    setState(() {
      _showManualEntry = true;
      _ipController.text = parsed.ip;
      _portController.text = parsed.port.toString();
      _tokenController.text = parsed.pairToken;
      _errorMessage = null;
    });

    // Auto-connect with QR data
    await _handlePairWithQRData(parsed);
  }

  /// Handle pairing with parsed QR data
  Future<void> _handlePairWithQRData(QRParseResult parsed) async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    final deviceName = _deviceNameController.text.trim().isNotEmpty
        ? _deviceNameController.text.trim()
        : 'BMB App ${DateTime.now().millisecondsSinceEpoch}';

    final success = await connProv.pairWithQRData(
      ip: parsed.ip,
      port: parsed.port,
      pairToken: parsed.pairToken,
      deviceName: deviceName,
      accessToken: parsed.accessToken.isNotEmpty ? parsed.accessToken : null,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _errorMessage = connProv.errorMessage.isNotEmpty
            ? connProv.errorMessage
            : 'No se pudo conectar. Verifica que el servidor esté en ejecución.';
      });
    }
  }

  Future<void> _handlePair() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8765;
    final token = _tokenController.text.trim();
    final deviceName = _deviceNameController.text.trim().isNotEmpty
        ? _deviceNameController.text.trim()
        : 'BMB Agent ${DateTime.now().millisecondsSinceEpoch}';

    // If user entered a bmb:// URI, parse it
    QRParseResult? parsed;
    if (token.startsWith('bmb://')) {
      parsed = QRService.parseQRUri(token);
    } else if (token.isNotEmpty) {
      // Use user-entered token as pair token
      parsed = QRParseResult(
        ip: ip,
        port: port,
        pairToken: token,
        accessToken: '',
      );
    }

    if (parsed != null) {
      final success = await connProv.pairWithQRData(
        ip: parsed.ip,
        port: parsed.port,
        pairToken: parsed.pairToken,
        deviceName: deviceName,
        accessToken: parsed.accessToken.isNotEmpty ? parsed.accessToken : null,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (success) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        setState(() {
          _errorMessage = connProv.errorMessage.isNotEmpty
              ? connProv.errorMessage
              : 'No se pudo conectar. Verifica la IP y el puerto.';
        });
      }
      return;
    }

    // Legacy path: try simple IP-based pairing
    final success = await connProv.pairViaQR(
      ip: ip,
      port: port,
      deviceName: deviceName,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _errorMessage = connProv.errorMessage.isNotEmpty
            ? connProv.errorMessage
            : 'No se pudo conectar. Verifica la IP y el puerto.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo / Branding
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8300e9), Color(0xFF5a00a0)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8300e9).withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'BMB',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'BMB Encover Agent',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Conecta con tu agente remoto',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 48),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!_showManualEntry) ...[
                      // Scan QR Button
                      _buildActionButton(
                        icon: Icons.qr_code_scanner,
                        label: 'Escanear Código QR',
                        subtitle: 'Apunta la cámara al QR del servidor',
                        onTap: _isLoading ? null : _openQRScanner,
                      ),
                      const SizedBox(height: 16),
                      // Manual entry button
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showManualEntry = true;
                          });
                        },
                        icon: const Icon(Icons.keyboard, color: Colors.white54),
                        label: const Text(
                          'Ingresar IP Manualmente',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    ],

                    if (_showManualEntry) ...[
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            _buildTextField(
                              controller: _ipController,
                              label: 'Dirección IP (Tailscale)',
                              hint: '100.x.x.x',
                              icon: Icons.language,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Ingresa la IP';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(
                                    controller: _portController,
                                    label: 'Puerto',
                                    hint: '8765',
                                    icon: Icons.numbers,
                                    keyboardType: TextInputType.number,
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) {
                                        return 'Puerto requerido';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _buildTextField(
                                    controller: _deviceNameController,
                                    label: 'Nombre del dispositivo',
                                    hint: 'Mi Laptop',
                                    icon: Icons.devices,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _tokenController,
                              label: 'Token de pairing (o bmb:// URI)',
                              hint: 'Pega aquí el token o la URI completa',
                              icon: Icons.vpn_key,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handlePair,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFF8300e9),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<
                                              Color>(Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Conectar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8300e9).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF8300e9), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
        prefixIcon: Icon(icon, color: Colors.white.withOpacity(0.3)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8300e9)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
