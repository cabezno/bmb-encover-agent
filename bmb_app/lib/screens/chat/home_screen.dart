import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/connection_provider.dart';
import '../../models/tab_model.dart';
import '../../widgets/common/tab_bar_widget.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/task_queue_widget.dart';
import '../../widgets/common/console_panel.dart';
import '../../services/console_logger.dart';
import 'tab_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();
  bool _initialConnectAttempted = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  void _initializeServices() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatProv = Provider.of<ChatProvider>(context, listen: false);
      final connProv = Provider.of<ConnectionProvider>(context, listen: false);
      chatProv.initialize(connProv.service);
      chatProv.setConnectionState(connProv.isConnected);

      // Log initial state
      ConsoleLogger.state(
        'Estado de conexión: ${connProv.isConnected ? "Conectado" : "Desconectado"}',
        details: connProv.isConnected
            ? 'IP: ${connProv.connection.tailscaleIp}:${connProv.connection.port}'
            : 'Sin conexión activa',
      );

      // Listen for connection changes
      connProv.addListener(_onConnectionChange);

      // Auto-connect if paired but not connected
      if (connProv.isPaired && !connProv.isConnected && !_initialConnectAttempted) {
        _initialConnectAttempted = true;
        ConsoleLogger.info('Intentando conexión automática...');
        connProv.connect().then((success) {
          if (mounted) {
            if (success) {
              ConsoleLogger.state(
                'Conectado al servidor',
                details: '${connProv.connection.tailscaleIp}:${connProv.connection.port}',
              );
            } else {
              ConsoleLogger.error(
                'No se pudo conectar al servidor',
                details: 'Verifica que el servidor esté en ejecución en '
                    '${connProv.connection.tailscaleIp}:${connProv.connection.port}',
              );
            }
          }
        });
      }
    });
  }

  void _onConnectionChange() {
    if (!mounted) return;
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    chatProv.setConnectionState(connProv.isConnected);

    if (connProv.isConnected) {
      ConsoleLogger.state(
        'Conectado al servidor',
        details: '${connProv.connection.tailscaleIp}:${connProv.connection.port}',
      );
    } else {
      ConsoleLogger.state('Desconectado del servidor');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    ConsoleLogger.tool('Enviando mensaje: "$text"');
    Provider.of<ChatProvider>(context, listen: false).sendMessage(text);
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openCall() {
    final callProv = Provider.of<CallProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    callProv.startCall(chatProv.activeTab.id);
    ConsoleLogger.tool('Iniciando llamada de voz');
    Navigator.of(context).pushNamed('/call');
  }

  void _openSettings() {
    Navigator.of(context).pushNamed('/settings');
  }

  Future<void> _connectToServer() async {
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    ConsoleLogger.info('Conectando al servidor...');
    ConsoleLogger.state(
      'Conectando',
      details: '${connProv.connection.tailscaleIp}:${connProv.connection.port}',
    );
    final success = await connProv.connect();
    if (mounted) {
      if (success) {
        ConsoleLogger.state('Conexión establecida correctamente');
      } else {
        ConsoleLogger.error(
          'Error de conexión',
          details: 'No se pudo conectar a ${connProv.connection.tailscaleIp}:'
              '${connProv.connection.port}\n'
              'Error: ${connProv.errorMessage}\n\n'
              'Posibles causas:\n'
              '• El servidor no está en ejecución\n'
              '• La IP/puerto son incorrectos\n'
              '• El firewall está bloqueando la conexión',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatProvider, ConnectionProvider>(
      builder: (context, chatProv, connProv, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF0D0D0D),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0D0D0D),
            elevation: 0,
            title: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: connProv.isConnected
                        ? const Color(0xFF00E676)
                        : Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  connProv.isConnected
                      ? '${connProv.connection.tailscaleIp}:${connProv.connection.port}'
                      : 'Desconectado',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.call, color: Color(0xFF8300e9)),
                onPressed: connProv.isConnected ? _openCall : null,
                tooltip: 'Llamar al agente',
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white54),
                onPressed: _openSettings,
                tooltip: 'Configuración',
              ),
            ],
          ),
          body: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Custom Tab Bar
                  BMBTabBar(
                    tabs: chatProv.tabs,
                    activeIndex: chatProv.activeTabIndex,
                    onTabSelected: (index) {
                      chatProv.switchTab(index);
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    onTabClosed: (index) => chatProv.closeTab(index),
                    onAddTab: () => chatProv.createTab(),
                  ),

                  // Tab content or connect screen
                  Expanded(
                    child: connProv.isConnected
                        ? (chatProv.hasTabs
                            ? PageView.builder(
                                controller: _pageController,
                                onPageChanged: (index) {
                                  chatProv.switchTab(index);
                                },
                                itemCount: chatProv.tabCount,
                                itemBuilder: (context, index) {
                                  return TabScreen(
                                    tab: chatProv.tabs[index],
                                    scrollController: _scrollController,
                                  );
                                },
                              )
                            : const Center(
                                child: Text(
                                  'No hay tabs activos',
                                  style: TextStyle(color: Colors.white38),
                                ),
                              ))
                        : _buildConnectScreen(connProv),
                  ),

                  // Bottom input bar (only when connected)
                  if (connProv.isConnected)
                    _buildInputBar(chatProv, connProv),
                ],
              ),

              // Console panel overlay (always shows floating button)
              const ConsolePanel(),
            ],
          ),
        );
      },
    );
  }

  /// Screen shown when not connected to server
  Widget _buildConnectScreen(ConnectionProvider connProv) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8300e9).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFF8300e9).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFF8300e9),
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sin conexión al servidor',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Conéctate al agente BMB para empezar.\n'
              'Asegúrate de que el servidor esté en ejecución.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 32),

            // Server info
            if (connProv.isPaired)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Servidor',
                        connProv.connection.tailscaleIp.isNotEmpty
                            ? connProv.connection.tailscaleIp
                            : '—'),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                        'Puerto', connProv.connection.port.toString()),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                        'Dispositivo', connProv.connection.deviceName),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Connect button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed:
                    connProv.status == ConnectionStatus.connecting
                        ? null
                        : _connectToServer,
                icon: connProv.status == ConnectionStatus.connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(
                  connProv.status == ConnectionStatus.connecting
                      ? 'Conectando...'
                      : 'Conectar al Servidor',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8300e9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
              ),
            ),

            if (!connProv.isPaired) ...[
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/onboarding',
                    (route) => false,
                  );
                },
                child: const Text(
                  'Configurar conexión',
                  style: TextStyle(
                    color: Color(0xFF8300e9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],

            // Error message
            if (connProv.status == ConnectionStatus.error &&
                connProv.errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFE53935).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Color(0xFFE53935), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        connProv.errorMessage,
                        style: const TextStyle(
                          color: Color(0xFFE53935),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar(ChatProvider chatProv, ConnectionProvider connProv) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
        top: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
      ),
      child: Row(
        children: [
          // Voice / Live button
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFF8300e9)),
            onPressed: connProv.isConnected ? _openCall : null,
            tooltip: 'Llamada de voz',
          ),
          // Text field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Envía un mensaje…',
                  hintStyle:
                      TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Send button
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Color(0xFF8300e9)),
            onPressed:
                connProv.isConnected ? _sendMessage : null,
          ),
        ],
      ),
    );
  }
}
