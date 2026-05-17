import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late TextEditingController _accessTokenController;
  bool _savingApiKey = false;
  bool _savingAccessToken = false;
  bool _testingConnection = false;
  bool _reconnecting = false;
  String? _apiKeyMessage;
  String? _accessTokenMessage;
  Color? _apiKeyMessageColor;
  Color? _accessTokenMessageColor;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _accessTokenController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connProv =
          Provider.of<ConnectionProvider>(context, listen: false);
      _apiKeyController.text = connProv.deepSeekApiKey;
      _accessTokenController.text = connProv.accessToken;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _accessTokenController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    setState(() {
      _savingApiKey = true;
      _apiKeyMessage = null;
    });

    final key = _apiKeyController.text.trim();
    final connProv =
        Provider.of<ConnectionProvider>(context, listen: false);
    await connProv.setDeepSeekApiKey(key);

    setState(() {
      _savingApiKey = false;
      _apiKeyMessage =
          key.isNotEmpty ? '✓ API Key guardada' : 'API Key eliminada';
      _apiKeyMessageColor = Colors.green;
    });
  }

  Future<void> _testDeepSeekConnection() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _apiKeyMessage = 'Primero ingresa una API Key';
        _apiKeyMessageColor = Colors.orange;
      });
      return;
    }

    setState(() {
      _testingConnection = true;
      _apiKeyMessage = 'Probando conexión...';
      _apiKeyMessageColor = Colors.grey;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.deepseek.com/v1/models'),
        headers: {
          'Authorization': 'Bearer $key',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _apiKeyMessage = '✓ Conexión exitosa con DeepSeek';
          _apiKeyMessageColor = Colors.green;
        });
      } else {
        setState(() {
          _apiKeyMessage =
              '✗ Error ${response.statusCode}. Verifica la API Key.';
          _apiKeyMessageColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _apiKeyMessage =
            '✗ Error de red. Verifica tu conexión a internet.';
        _apiKeyMessageColor = Colors.red;
      });
    }

    setState(() => _testingConnection = false);
  }

  Future<void> _saveAccessToken() async {
    setState(() {
      _savingAccessToken = true;
      _accessTokenMessage = null;
    });

    final token = _accessTokenController.text.trim();
    final connProv =
        Provider.of<ConnectionProvider>(context, listen: false);
    await connProv.setAccessToken(token);

    setState(() {
      _savingAccessToken = false;
      _accessTokenMessage = token.isNotEmpty
          ? '✓ Access Token guardado'
          : 'Access Token eliminado';
      _accessTokenMessageColor = Colors.green;
    });
  }

  Future<void> _reconnectToServer() async {
    setState(() => _reconnecting = true);

    final connProv =
        Provider.of<ConnectionProvider>(context, listen: false);

    // Disconnect first
    await connProv.disconnect();
    await Future.delayed(const Duration(milliseconds: 500));

    // Reconnect
    final success = await connProv.connect();

    if (!mounted) return;
    setState(() => _reconnecting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Reconectado al servidor'
              : '✗ Error: ${connProv.errorMessage}',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, SettingsProvider>(
      builder: (context, connProv, settings, _) {
        // Sync controllers if not yet populated
        if (_apiKeyController.text.isEmpty &&
            connProv.deepSeekApiKey.isNotEmpty) {
          _apiKeyController.text = connProv.deepSeekApiKey;
        }
        if (_accessTokenController.text.isEmpty &&
            connProv.accessToken.isNotEmpty) {
          _accessTokenController.text = connProv.accessToken;
        }

        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            elevation: 0,
            title: const Text(
              'Configuración',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white54),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildSectionHeader('API Keys'),
              _buildApiKeyCard(),
              const SizedBox(height: 24),

              _buildSectionHeader('Conexión'),
              _buildConnectionCard(connProv),
              const SizedBox(height: 24),

              _buildSectionHeader('Dispositivo'),
              _buildDeviceCard(connProv),
              const SizedBox(height: 24),

              _buildSectionHeader('Voz'),
              _buildVoiceSettings(settings),
              const SizedBox(height: 24),

              _buildSectionHeader('Pantalla'),
              _buildDisplaySettings(settings),
              const SizedBox(height: 24),

              _buildSectionHeader('Información'),
              _buildAboutSection(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF8300e9),
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildApiKeyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // DeepSeek API Key
          const Text(
            'API Key de DeepSeek',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Usada por el agente para respuestas inteligentes',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'sk-...',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.25)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _savingApiKey ? null : _saveApiKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8300e9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: _savingApiKey
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar',
                          style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          if (_apiKeyMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _apiKeyMessage!,
              style: TextStyle(
                color: _apiKeyMessageColor,
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testingConnection ? null : _testDeepSeekConnection,
              icon: _testingConnection
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF8300e9),
                      ),
                    )
                  : const Icon(Icons.wifi_tethering,
                      size: 16, color: Color(0xFF8300e9)),
              label: Text(
                _testingConnection
                    ? 'Probando...'
                    : 'Probar conexión con DeepSeek',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF8300e9),
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF8300e9)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Access Token
          const Text(
            'Access Token (password)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Token de acceso seguro configurado via BMB_ACCESS_TOKEN en el servidor',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _accessTokenController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Token de acceso',
                    hintStyle:
                        TextStyle(color: Colors.white.withOpacity(0.25)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _savingAccessToken ? null : _saveAccessToken,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8300e9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: _savingAccessToken
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar',
                          style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          if (_accessTokenMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _accessTokenMessage!,
              style: TextStyle(
                color: _accessTokenMessageColor,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionCard(ConnectionProvider connProv) {
    final lastAuthError = connProv.service.lastAuthError;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'Estado',
            _statusText(connProv),
            valueColor: connProv.isConnected
                ? const Color(0xFF00E676)
                : connProv.status == ConnectionStatus.connecting
                    ? Colors.orange
                    : Colors.red,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'IP',
            connProv.connection.tailscaleIp.isNotEmpty
                ? connProv.connection.tailscaleIp
                : '—',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Puerto',
            connProv.connection.port.toString(),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'API Key',
            connProv.connection.apiKey.isNotEmpty
                ? '${connProv.connection.apiKey.substring(0, (connProv.connection.apiKey.length > 12 ? 12 : connProv.connection.apiKey.length))}...'
                : '—',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Access Token',
            connProv.connection.accessToken.isNotEmpty
                ? '${connProv.connection.accessToken.substring(0, (connProv.connection.accessToken.length > 8 ? 8 : connProv.connection.accessToken.length))}...'
                : 'No configurado',
          ),
          if (lastAuthError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.red, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      lastAuthError,
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _reconnecting ? null : _reconnectToServer,
              icon: _reconnecting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh, size: 18, color: Colors.white),
              label: Text(
                _reconnecting
                    ? 'Reconectando...'
                    : 'Reconectar al servidor',
                style: const TextStyle(fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8300e9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await connProv.clearPairing();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/onboarding',
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.link_off, color: Colors.red, size: 18),
              label: const Text(
                'Desconectar y Olvidar',
                style: TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE53935)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText(ConnectionProvider connProv) {
    switch (connProv.status) {
      case ConnectionStatus.connected:
        return 'Conectado';
      case ConnectionStatus.connecting:
        return 'Conectando...';
      case ConnectionStatus.error:
        return 'Error';
      case ConnectionStatus.disconnected:
        return 'Desconectado';
    }
  }

  Widget _buildDeviceCard(ConnectionProvider connProv) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'Nombre',
            connProv.connection.deviceName.isNotEmpty
                ? connProv.connection.deviceName
                : '—',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'Tipo',
            'Flutter App (Android/iOS)',
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            'ID',
            connProv.connection.deviceId.isNotEmpty
                ? connProv.connection.deviceId
                : '—',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVoiceSettings(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildDropdownSetting(
            label: 'Modelo TTS',
            value: settings.ttsModel,
            options: settings.ttsModelOptions,
            onChanged: (v) => settings.setTtsModel(v!),
            displayLabels: {
              'piper': 'Piper',
              'kokoro': 'Kokoro',
              'auto': 'Automático',
            },
          ),
          const SizedBox(height: 16),
          _buildDropdownSetting(
            label: 'Idioma',
            value: settings.language,
            options: settings.languageOptions,
            onChanged: (v) => settings.setLanguage(v!),
            displayLabels: {'es': 'Español', 'en': 'English'},
          ),
          const SizedBox(height: 16),
          _buildSwitchSetting(
            label: 'Push-to-Talk',
            subtitle: 'Mantén presionado para hablar',
            value: settings.pushToTalk,
            onChanged: (v) => settings.setPushToTalk(v),
          ),
          const SizedBox(height: 16),
          _buildSwitchSetting(
            label: 'Modo interrupción',
            subtitle: 'Permite interrumpir al agente mientras habla',
            value: settings.interruptMode,
            onChanged: (v) => settings.setInterruptMode(v),
          ),
          const SizedBox(height: 16),
          _buildSliderSetting(
            label: 'Velocidad de voz',
            value: settings.voiceSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            displayValue: '${settings.voiceSpeed.toStringAsFixed(1)}x',
            onChanged: (v) => settings.setVoiceSpeed(v),
          ),
          const SizedBox(height: 16),
          _buildSliderSetting(
            label: 'Volumen',
            value: settings.volume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            displayValue: '${(settings.volume * 100).round()}%',
            onChanged: (v) => settings.setVolume(v),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    Map<String, String>? displayLabels,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 13,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF1A1A1A),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              items: options.map((opt) {
                return DropdownMenuItem(
                  value: opt,
                  child: Text(
                    displayLabels?[opt] ?? opt,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchSetting({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF8300e9),
        ),
      ],
    );
  }

  Widget _buildSliderSetting({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
              ),
            ),
            Text(
              displayValue,
              style: const TextStyle(
                color: Color(0xFF8300e9),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: const Color(0xFF8300e9),
          inactiveColor: Colors.white.withOpacity(0.1),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDisplaySettings(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildSwitchSetting(
            label: 'Modo oscuro',
            subtitle: 'Tema oscuro/purpura de BMB',
            value: settings.isDarkMode,
            onChanged: (_) => settings.toggleDarkMode(),
          ),
          const SizedBox(height: 16),
          _buildSwitchSetting(
            label: 'Consola visible',
            subtitle: 'Muestra la consola de depuración',
            value: settings.consoleVisible,
            onChanged: (v) => settings.setConsoleVisible(v),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Versión', '0.1.0'),
          const SizedBox(height: 8),
          _buildInfoRow('App', 'BMB Encover Agent'),
          const SizedBox(height: 8),
          _buildInfoRow('Framework', 'Flutter'),
          const SizedBox(height: 16),
          Text(
            '© 2026 BlackMagicBox. Todos los derechos reservados.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.25),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
