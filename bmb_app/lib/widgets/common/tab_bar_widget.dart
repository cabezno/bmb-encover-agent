import 'package:flutter/material.dart';
import '../../models/tab_model.dart';
import '../../providers/chat_provider.dart';

class BMBTabBar extends StatelessWidget {
  final List<TabModel> tabs;
  final int activeIndex;
  final ValueChanged<int> onTabSelected;
  final ValueChanged<int> onTabClosed;
  final VoidCallback onAddTab;

  const BMBTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onTabSelected,
    required this.onTabClosed,
    required this.onAddTab,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                return _TabItem(
                  tab: tabs[index],
                  isActive: index == activeIndex,
                  onTap: () => onTabSelected(index),
                  onClose: tabs.length > 1
                      ? () => onTabClosed(index)
                      : null,
                );
              },
            ),
          ),
          // Add button
          Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: IconButton(
              icon: Icon(Icons.add, color: Colors.white.withOpacity(0.5), size: 18),
              onPressed: onAddTab,
              padding: EdgeInsets.zero,
              splashRadius: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final TabModel tab;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
    this.onClose,
  });

  IconData _tabIcon() {
    switch (tab.type) {
      case TabType.chat:
        return Icons.chat_bubble_outline;
      case TabType.research:
        return Icons.search;
      case TabType.code:
        return Icons.code;
      case TabType.live:
        return Icons.mic;
      case TabType.console:
        return Icons.terminal;
    }
  }

  Color _statusColor() {
    switch (tab.status) {
      case TabStatus.idle:
        return const Color(0xFF00E676);
      case TabStatus.processing:
        return const Color(0xFF8300e9);
      case TabStatus.speaking:
        return const Color(0xFF00E676);
      case TabStatus.listening:
        return Colors.red;
      case TabStatus.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onClose != null ? () => onClose!() : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF8300e9).withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(
                  color: const Color(0xFF8300e9).withOpacity(0.3))
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status dot
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _statusColor(),
              ),
            ),
            const SizedBox(width: 6),
            // Icon
            Icon(
              _tabIcon(),
              size: 14,
              color: isActive
                  ? const Color(0xFF8300e9)
                  : Colors.white.withOpacity(0.5),
            ),
            const SizedBox(width: 6),
            // Title
            Text(
              tab.title.length > 12
                  ? '${tab.title.substring(0, 12)}…'
                  : tab.title,
              style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? Colors.white
                    : Colors.white.withOpacity(0.5),
                fontWeight:
                    isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            // Close button (hover effect via long press)
            if (onClose != null) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: 12,
                color: Colors.white.withOpacity(0.2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
