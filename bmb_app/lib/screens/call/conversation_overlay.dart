import 'package:flutter/material.dart';
import '../../models/message_model.dart';

class ConversationOverlay extends StatelessWidget {
  final List<MessageModel> messages;
  final VoidCallback onDismiss;

  const ConversationOverlay({
    super.key,
    required this.messages,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity! > 200) {
          onDismiss();
        }
      },
      child: Container(
        color: const Color(0xFF0D0D0D),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Conversación',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${messages.length} mensajes',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),

            // Messages
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Text(
                        'No hay mensajes en esta llamada',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        return _buildMessageItem(messages[index]);
                      },
                    ),
            ),

            // Dismiss hint at bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                '⬇ Desliza hacia abajo para cerrar',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(MessageModel message) {
    final isUser = message.isMine;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender indicator for agent
          if (!isUser)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8, top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8300e9).withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.smart_toy,
                  size: 14, color: Color(0xFF8300e9)),
            ),

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF8300e9).withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF8300e9).withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sender indicator for user
          if (isUser)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(left: 8, top: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF8300e9).withOpacity(0.3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.person, size: 14, color: Color(0xFF8300e9)),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
