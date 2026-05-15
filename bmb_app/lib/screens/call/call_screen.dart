import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/connection_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/call/call_status_indicator.dart';
import '../../widgets/call/voice_level_meter.dart';
import 'conversation_overlay.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _showConversation = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes.toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String _statusText(CallScreenState state) {
    switch (state) {
      case CallScreenState.idle:
        return 'Inactivo';
      case CallScreenState.calling:
        return 'Llamando…';
      case CallScreenState.connected:
        return 'Conectado';
      case CallScreenState.listening:
        return 'Escuchando…';
      case CallScreenState.processing:
        return 'Procesando…';
      case CallScreenState.speaking:
        return 'Hablando';
      case CallScreenState.ended:
        return 'Llamada finalizada';
      case CallScreenState.error:
        return 'Error en la llamada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer3<CallProvider, ChatProvider, SettingsProvider>(
      builder: (context, callProv, chatProv, settings, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          body: SafeArea(
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity! < -200) {
                  setState(() => _showConversation = true);
                } else if (details.primaryVelocity! > 200) {
                  setState(() => _showConversation = false);
                }
              },
              child: Stack(
                children: [
                  // Main call UI
                  if (!_showConversation)
                    _buildCallUI(callProv, chatProv, settings)
                  else
                    ConversationOverlay(
                      messages: callProv.callMessages,
                      onDismiss: () {
                        setState(() => _showConversation = false);
                      },
                    ),

                  // Dismiss hint
                  if (!_showConversation)
                    Positioned(
                      top: 8,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '⬆ Desliza para ver conversación',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCallUI(
      CallProvider callProv, ChatProvider chatProv, SettingsProvider settings) {
    return Column(
      children: [
        const Spacer(flex: 2),

        // Status indicator
        CallStatusIndicator(state: callProv.state, pulseController: _pulseController),
        const SizedBox(height: 24),

        // Agent info
        Text(
          'Agente BMB',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),

        // Status text
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _statusColor(callProv.state).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _statusText(callProv.state),
            style: TextStyle(
              fontSize: 13,
              color: _statusColor(callProv.state),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Timer
        Text(
          _formatDuration(callProv.callDuration),
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w300,
            color: Colors.white.withOpacity(0.7),
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 16),

        // Voice level meter (visible when listening/speaking)
        if (callProv.state == CallScreenState.listening ||
            callProv.state == CallScreenState.speaking)
          VoiceLevelMeter(level: callProv.audioLevel),
        const SizedBox(height: 24),

        // Last messages preview
        if (callProv.callMessages.isNotEmpty)
          _buildLastMessagesPreview(callProv),

        const Spacer(flex: 2),

        // Action buttons row
        _buildActionButtons(callProv),
        const SizedBox(height: 16),

        // Settings quick access
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white24, size: 20),
          onPressed: () => Navigator.of(context).pushNamed('/settings'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLastMessagesPreview(CallProvider callProv) {
    final recent = callProv.callMessages.length > 3
        ? callProv.callMessages.sublist(callProv.callMessages.length - 3)
        : callProv.callMessages;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: recent.map((msg) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${msg.isMine ? 'Tú' : 'Agente'}: ${msg.text.length > 60 ? '${msg.text.substring(0, 60)}…' : msg.text}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons(CallProvider callProv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mute button
          _buildCircleButton(
            icon: callProv.isMuted ? Icons.mic_off : Icons.mic,
            color: callProv.isMuted ? Colors.red : Colors.white38,
            onTap: () => callProv.mute(),
            label: 'Silenciar',
          ),
          const SizedBox(width: 20),

          // Hangup button
          _buildCircleButton(
            icon: Icons.call_end,
            color: Colors.red,
            size: 64,
            iconSize: 32,
            onTap: () {
              callProv.endCall();
              Navigator.of(context).pop();
            },
            label: 'Colgar',
          ),
          const SizedBox(width: 20),

          // Silence agent button
          _buildCircleButton(
            icon: callProv.isSilenced ? Icons.volume_up : Icons.volume_off,
            color: callProv.isSilenced
                ? const Color(0xFF8300e9)
                : Colors.white38,
            onTap: () => callProv.silence(),
            label: callProv.isSilenced ? 'Sonido' : 'Silencio',
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 56,
    double iconSize = 24,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Color _statusColor(CallScreenState state) {
    switch (state) {
      case CallScreenState.listening:
        return Colors.red;
      case CallScreenState.processing:
        return const Color(0xFF8300e9);
      case CallScreenState.speaking:
        return const Color(0xFF00E676);
      case CallScreenState.error:
        return Colors.red;
      default:
        return Colors.white54;
    }
  }
}
