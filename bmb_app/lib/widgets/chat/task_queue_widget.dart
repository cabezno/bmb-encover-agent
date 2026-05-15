import 'package:flutter/material.dart';
import '../../models/tab_model.dart';

class TaskQueueWidget extends StatefulWidget {
  final List<TaskItem> tasks;
  final int pendingCount;

  const TaskQueueWidget({
    super.key,
    required this.tasks,
    required this.pendingCount,
  });

  @override
  State<TaskQueueWidget> createState() => _TaskQueueWidgetState();
}

class _TaskQueueWidgetState extends State<TaskQueueWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animController;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animController.forward();
      } else {
        _animController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Collapsed header / tap to expand
        GestureDetector(
          onTap: _toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white.withOpacity(0.4),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.task_alt,
                  size: 16,
                  color: const Color(0xFF8300e9).withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.pendingCount} tareas pendientes',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  '${widget.tasks.length} total',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded task list
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.tasks.length,
              itemBuilder: (context, index) {
                return _buildTaskItem(widget.tasks[index]);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskItem(TaskItem task) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Status icon with animation
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _statusIcon(task.status),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.description,
              style: TextStyle(
                color: _statusTextColor(task.status),
                fontSize: 13,
                decoration: task.status == TaskItemStatus.completed
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          if (task.status == TaskItemStatus.processing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFF8300e9)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case TaskItemStatus.pending:
        return Icon(
          Icons.radio_button_unchecked,
          size: 16,
          color: Colors.white.withOpacity(0.3),
          key: const ValueKey('pending'),
        );
      case TaskItemStatus.processing:
        return Icon(
          Icons.sync,
          size: 16,
          color: const Color(0xFF8300e9),
          key: const ValueKey('processing'),
        );
      case TaskItemStatus.completed:
        return Icon(
          Icons.check_circle,
          size: 16,
          color: const Color(0xFF00E676),
          key: const ValueKey('completed'),
        );
      case TaskItemStatus.failed:
        return Icon(
          Icons.error,
          size: 16,
          color: Colors.red,
          key: const ValueKey('failed'),
        );
      default:
        return const Icon(Icons.help_outline, size: 16);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case TaskItemStatus.completed:
        return Colors.white.withOpacity(0.4);
      case TaskItemStatus.failed:
        return Colors.red.withOpacity(0.7);
      default:
        return Colors.white.withOpacity(0.7);
    }
  }
}
