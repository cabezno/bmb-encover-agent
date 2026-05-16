import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

/// A log entry from the agent.
class ConsoleLog {
  final DateTime timestamp;
  final String level; // 'info', 'warn', 'error', 'tool', 'state'
  final String message;
  final String? details;

  ConsoleLog({
    required this.timestamp,
    required this.level,
    required this.message,
    this.details,
  });

  Color get color {
    switch (level) {
      case 'error':
        return const Color(0xFFE53935);
      case 'warn':
        return const Color(0xFFFFA726);
      case 'tool':
        return const Color(0xFF42A5F5);
      case 'state':
        return const Color(0xFF66BB6A);
      default:
        return Colors.white70;
    }
  }

  String get icon {
    switch (level) {
      case 'error':
        return '❌';
      case 'warn':
        return '⚠️';
      case 'tool':
        return '🔧';
      case 'state':
        return '🔄';
      default:
        return 'ℹ️';
    }
  }

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

/// Singleton provider for console logs — enables adding logs from anywhere.
class ConsoleLogProvider extends ChangeNotifier {
  static final ConsoleLogProvider _instance = ConsoleLogProvider._();
  factory ConsoleLogProvider() => _instance;
  ConsoleLogProvider._();

  final List<ConsoleLog> _logs = [];
  static const int _maxLogs = 500;

  List<ConsoleLog> get logs => List.unmodifiable(_logs);

  void log({
    required String level,
    required String message,
    String? details,
  }) {
    final entry = ConsoleLog(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      details: details,
    );
    _logs.add(entry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
    notifyListeners();
  }

  void info(String message, {String? details}) =>
      log(level: 'info', message: message, details: details);
  void warn(String message, {String? details}) =>
      log(level: 'warn', message: message, details: details);
  void error(String message, {String? details}) =>
      log(level: 'error', message: message, details: details);
  void tool(String message, {String? details}) =>
      log(level: 'tool', message: message, details: details);
  void state(String message, {String? details}) =>
      log(level: 'state', message: message, details: details);

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}

/// Console panel overlay widget.
/// Displays agent logs in real time with slide-up animation.
/// The floating toggle button is always rendered; the panel
/// slides up on tap or when forced by settings.
class ConsolePanel extends StatefulWidget {
  const ConsolePanel({super.key});

  @override
  State<ConsolePanel> createState() => _ConsolePanelState();
}

class _ConsolePanelState extends State<ConsolePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _panelVisible = false;
  bool _autoScroll = true;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Defer initial check to after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWithSettings());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _syncWithSettings();
    }
  }

  void _syncWithSettings() {
    if (!mounted) return;
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.consoleVisible && !_panelVisible) {
      _panelVisible = true;
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void show() {
    setState(() => _panelVisible = true);
    _slideController.forward();
  }

  void hide() {
    _slideController.reverse().then((_) {
      if (mounted) setState(() => _panelVisible = false);
    });
  }

  void toggle() {
    if (_panelVisible) {
      hide();
    } else {
      show();
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      _autoScroll = (currentScroll >= maxScroll - 20);
    }
  }

  void _scrollToBottom() {
    if (!_autoScroll || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The dismiss barrier (behind the panel, over content)
        if (_panelVisible)
          GestureDetector(
            onTap: hide,
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

        // Floating toggle button (bottom-left, always visible)
        Positioned(
          left: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.small(
            backgroundColor: _panelVisible
                ? const Color(0xFF8300e9)
                : const Color(0xFF1A1A1A),
            onPressed: toggle,
            child: Icon(
              _panelVisible ? Icons.close : Icons.terminal,
              color: Colors.white,
              size: 20,
            ),
            tooltip: _panelVisible ? 'Cerrar consola' : 'Abrir consola',
            elevation: 4,
          ),
        ),

        // Console panel overlay
        if (_panelVisible)
          Positioned(
            left: 8,
            right: 8,
            bottom: 76 + MediaQuery.of(context).padding.bottom,
            height: MediaQuery.of(context).size.height * 0.45,
            child: SlideTransition(
              position: _slideAnimation,
              child: GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity != null &&
                      details.primaryVelocity! > 300) {
                    hide();
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0D0D).withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8300e9).withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8300e9).withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header bar
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8300e9).withOpacity(0.15),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.terminal,
                                color: Color(0xFF8300e9), size: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Consola del Agente',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            // Log count badge
                            Consumer<ConsoleLogProvider>(
                              builder: (context, logProv, _) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${logProv.logs.length}',
                                    style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                            // Clear button
                            GestureDetector(
                              onTap: () => ConsoleLogProvider().clear(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Limpiar',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Swipe down hint
                            const Icon(Icons.keyboard_arrow_down,
                                color: Colors.white38, size: 18),
                          ],
                        ),
                      ),
                      // Logs list
                      Expanded(
                        child: Consumer<ConsoleLogProvider>(
                          builder: (context, logProv, _) {
                            _scrollToBottom();
                            if (logProv.logs.isEmpty) {
                              return Center(
                                child: Text(
                                  'No hay logs. Los eventos del agente aparecerán aquí.',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.2),
                                    fontSize: 11,
                                  ),
                                ),
                              );
                            }
                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              itemCount: logProv.logs.length,
                              itemBuilder: (context, index) {
                                final log = logProv.logs[index];
                                return _buildLogEntry(log);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLogEntry(ConsoleLog log) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: GestureDetector(
        onLongPress: () {
          if (log.details != null) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1A1A1A),
                title: Text(
                  '${log.icon} ${log.message}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                content: SingleChildScrollView(
                  child: SelectableText(
                    log.details!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cerrar',
                        style: TextStyle(color: Color(0xFF8300e9))),
                  ),
                ],
              ),
            );
          }
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Text(
                log.formattedTime,
                style: const TextStyle(
                  color: Colors.white24,
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            Text(log.icon, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                log.message,
                style: TextStyle(
                  color: log.color,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                maxLines: log.details != null ? 1 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
