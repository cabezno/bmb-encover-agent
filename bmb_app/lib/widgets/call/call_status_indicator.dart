import 'package:flutter/material.dart';
import '../../providers/call_provider.dart';

class CallStatusIndicator extends StatelessWidget {
  final CallScreenState state;
  final AnimationController pulseController;

  const CallStatusIndicator({
    super.key,
    required this.state,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, _) {
        return SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background pulse rings
              ..._buildPulseRings(),
              // Center icon
              _buildCenterIcon(),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildPulseRings() {
    final rings = <Widget>[];
    final pulseValue = pulseController.value;

    switch (state) {
      case CallScreenState.listening:
        // Pulsing red rings
        for (int i = 0; i < 3; i++) {
          final scale = 1.0 + (pulseValue * (0.3 * (i + 1)));
          final opacity = (1.0 - pulseValue) * (0.3 - (i * 0.08));
          rings.add(_buildRing(
            scale: scale,
            color: Colors.red.withOpacity(opacity.clamp(0.0, 0.3)),
          ));
        }
        break;

      case CallScreenState.processing:
        // Spinning purple rings
        for (int i = 0; i < 2; i++) {
          final scale = 1.0 + (pulseValue * (0.2 * (i + 1)));
          final opacity = 0.15 - (i * 0.05);
          rings.add(_buildRing(
            scale: scale,
            color: const Color(0xFF8300e9).withOpacity(opacity.clamp(0.0, 0.2)),
          ));
        }
        break;

      case CallScreenState.speaking:
        // Sound wave animation
        for (int i = 0; i < 3; i++) {
          final waveOffset = (pulseValue * 2 * 3.14159 * (i + 1) * 0.5);
          final scale = 1.0 + (waveOffset.abs() * 0.15);
          rings.add(_buildRing(
            scale: scale,
            color: const Color(0xFF00E676).withOpacity(0.15),
          ));
        }
        break;

      case CallScreenState.calling:
        rings.add(_buildRing(
          scale: 1.0 + (pulseValue * 0.15),
          color: const Color(0xFF8300e9).withOpacity(0.2),
        ));
        break;

      case CallScreenState.connected:
        rings.add(_buildRing(
          scale: 1.0,
          color: const Color(0xFF00E676).withOpacity(0.15),
        ));
        break;

      case CallScreenState.error:
        rings.add(_buildRing(
          scale: 1.0 + (pulseValue * 0.05),
          color: Colors.red.withOpacity(0.25),
        ));
        break;

      default:
        rings.add(_buildRing(
          scale: 1.0,
          color: Colors.white.withOpacity(0.05),
        ));
    }

    return rings;
  }

  Widget _buildRing({required double scale, required Color color}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCenterIcon() {
    IconData icon;
    Color color;

    switch (state) {
      case CallScreenState.idle:
        icon = Icons.call;
        color = Colors.white38;
      case CallScreenState.calling:
        icon = Icons.phone_in_talk;
        color = const Color(0xFF8300e9);
      case CallScreenState.connected:
        icon = Icons.check_circle;
        color = const Color(0xFF00E676);
      case CallScreenState.listening:
        icon = Icons.hearing;
        color = Colors.red;
      case CallScreenState.processing:
        icon = Icons.psychology;
        color = const Color(0xFF8300e9);
      case CallScreenState.speaking:
        icon = Icons.record_voice_over;
        color = const Color(0xFF00E676);
      case CallScreenState.ended:
        icon = Icons.call_end;
        color = Colors.white38;
      case CallScreenState.error:
        icon = Icons.error;
        color = Colors.red;
    }

    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.15),
        border: Border.all(color: color.withOpacity(0.4), width: 2),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }
}
