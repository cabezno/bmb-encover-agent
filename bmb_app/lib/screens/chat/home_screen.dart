import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/call_provider.dart';
import '../../providers/connection_provider.dart';
import '../../models/tab_model.dart';
import '../../widgets/common/tab_bar_widget.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/task_queue_widget.dart';
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

  @override
  void initState() {
    super.initState();
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    chatProv.initialize(connProv.service);
    chatProv.setConnectionState(connProv.isConnected);

    // Listen for connection changes
    connProv.addListener(_onConnectionChange);
  }

  void _onConnectionChange() {
    if (!mounted) return;
    final connProv = Provider.of<ConnectionProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    chatProv.setConnectionState(connProv.isConnected);
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
    Navigator.of(context).pushNamed('/call');
  }

  void _openSettings() {
    Navigator.of(context).pushNamed('/settings');
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
                      ? connProv.connection.tailscaleIp
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
          body: Column(
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

              // Tab content
              Expanded(
                child: chatProv.hasTabs
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
                      ),
              ),

              // Bottom input bar
              _buildInputBar(chatProv, connProv),
            ],
          ),
        );
      },
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
