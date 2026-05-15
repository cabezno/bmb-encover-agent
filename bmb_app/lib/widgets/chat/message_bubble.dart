import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    switch (message.sender) {
      case MessageSender.user:
        return _buildUserBubble();
      case MessageSender.agent:
        return _buildAgentBubble();
      case MessageSender.system:
        return _buildSystemBubble();
    }
  }

  Widget _buildUserBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildTimestamp(true),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF8300e9),
                    Color(0xFF6a00c4),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgentBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Agent avatar
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF8300e9).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.smart_toy,
              size: 16,
              color: Color(0xFF8300e9),
            ),
          ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildContent(),
                  const SizedBox(height: 4),
                  _buildTimestamp(false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemBubble() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (message.type == MessageType.audio) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 18,
            color: message.isMine ? Colors.white : const Color(0xFF8300e9),
          ),
          const SizedBox(width: 8),
          Container(
            width: 80,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      );
    }

    return Text(
      message.text,
      style: TextStyle(
        color: message.sender == MessageSender.user
            ? Colors.white
            : Colors.white.withOpacity(0.9),
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

  Widget _buildTimestamp(bool isRight) {
    return Text(
      '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
      style: TextStyle(
        color: Colors.white.withOpacity(0.25),
        fontSize: 10,
      ),
    );
  }
}
