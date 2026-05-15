import 'package:flutter/material.dart';
import '../../models/tab_model.dart';
import '../../models/message_model.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/task_queue_widget.dart';

class TabScreen extends StatelessWidget {
  final TabModel tab;
  final ScrollController scrollController;

  const TabScreen({
    super.key,
    required this.tab,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: tab.messages.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: tab.messages.length + (tab.status == TabStatus.processing ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == tab.messages.length) {
                      return _buildTypingIndicator();
                    }
                    final message = tab.messages[index];
                    return MessageBubble(message: message);
                  },
                ),
        ),

        // Task queue panel (collapsible)
        if (tab.taskQueue.isNotEmpty)
          TaskQueueWidget(
            tasks: tab.taskQueue,
            pendingCount: tab.pendingTaskCount,
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 12),
          Text(
            'Inicia una conversación',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tab.type == TabType.chat
                ? 'Escribe un mensaje o presiona 🎤 para hablar'
                : 'Tab en modo ${tab.type.name}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Agent avatar placeholder
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF8300e9).withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.smart_toy, size: 16, color: Color(0xFF8300e9)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 600 + (index * 200)),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: const Color(0xFF8300e9),
        shape: BoxShape.circle,
      ),
    );
  }
}
