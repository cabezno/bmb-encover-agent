import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectionProvider, SettingsProvider>(
      builder: (context, connProv, settings, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            elevation: 0,
            title: const Text(
              'Configuración',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white54),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildSectionHeader('Conexión'),
              _buildConnectionCard(connProv),
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

  Widget _buildConnectionCard(ConnectionProvider connProv) {
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
            connProv.isConnected ? 'Conectado' : 'Desconectado',
            valueColor: connProv.isConnected
                ? const Color(0xFF00E676)
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
            'Dispositivo',
            connProv.connection.deviceName.isNotEmpty
                ? connProv.connection.deviceName
                : '—',
          ),
          const SizedBox(height: 16),
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
          // TTS Model selector
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

          // Language selector
          _buildDropdownSetting(
            label: 'Idioma',
            value: settings.language,
            options: settings.languageOptions,
            onChanged: (v) => settings.setLanguage(v!),
            displayLabels: {'es': 'Español', 'en': 'English'},
          ),
          const SizedBox(height: 16),

          // Push to talk toggle
          _buildSwitchSetting(
            label: 'Push-to-Talk',
            subtitle: 'Mantén presionado para hablar',
            value: settings.pushToTalk,
            onChanged: (v) => settings.setPushToTalk(v),
          ),
          const SizedBox(height: 16),

          // Interrupt mode
          _buildSwitchSetting(
            label: 'Modo interrupción',
            subtitle: 'Permite interrumpir al agente mientras habla',
            value: settings.interruptMode,
            onChanged: (v) => settings.setInterruptMode(v),
          ),
          const SizedBox(height: 16),

          // Voice speed slider
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

          // Volume slider
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
