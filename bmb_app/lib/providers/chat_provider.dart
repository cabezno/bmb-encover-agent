import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/tab_model.dart';
import '../models/message_model.dart';
import '../services/api/chat_service.dart';
import '../services/connection/connection_service.dart' as svc;

class ChatProvider extends ChangeNotifier {
  final List<TabModel> _tabs = [];
  int _activeTabIndex = 0;
  late ChatService _chatService;
  bool _isConnected = false;
  bool _useHttpApi = false;
  String? _lastError;

  List<TabModel> get tabs => List.unmodifiable(_tabs);
  int get activeTabIndex => _activeTabIndex;
  TabModel get activeTab =>
      _tabs.isNotEmpty ? _tabs[_activeTabIndex] : _createDefaultTab();
  int get tabCount => _tabs.length;
  bool get hasTabs => _tabs.isNotEmpty;
  bool get useHttpApi => _useHttpApi;
  String? get lastError => _lastError;

  ChatProvider() {
    _tabs.add(_createDefaultTab());
  }

  TabModel _createDefaultTab() {
    return TabModel(
      title: 'Chat',
      type: TabType.chat,
      isActive: true,
    );
  }

  void initialize(svc.ConnectionService connectionService) {
    _chatService = ChatService(connectionService);

    // Listen for errors from the chat service
    _chatService.errorStream.listen((error) {
      _lastError = error;
      notifyListeners();
    });
  }

  void setConnectionState(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  void toggleHttpApi(bool value) {
    _useHttpApi = value;
    notifyListeners();
  }

  void createTab({String? title, TabType? type}) {
    final newTab = TabModel(
      title: title ?? 'Nuevo ${_tabs.length + 1}',
      type: type ?? TabType.chat,
    );
    _tabs.add(newTab);
    _activeTabIndex = _tabs.length - 1;
    notifyListeners();
  }

  void closeTab(int index) {
    if (_tabs.length <= 1) return;
    _tabs.removeAt(index);
    if (_activeTabIndex >= _tabs.length) {
      _activeTabIndex = _tabs.length - 1;
    }
    notifyListeners();
  }

  void switchTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _activeTabIndex = index;
    notifyListeners();
  }

  void updateTabTitle(int index, String title) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs[index].title = title;
    notifyListeners();
  }

  void updateTabStatus(int index, TabStatus status) {
    if (index < 0 || index >= _tabs.length) return;
    _tabs[index].status = status;
    notifyListeners();
  }

  void sendMessage(String text) {
    if (!_isConnected || text.trim().isEmpty) return;
    final tab = activeTab;
    _lastError = null;
    tab.status = TabStatus.processing;
    notifyListeners();

    if (_useHttpApi) {
      // Use HTTP POST /api/chat for reliable communication
      _chatService.sendViaHttp(
        tabId: tab.id,
        text: text,
      ).then((success) {
        tab.status = success ? TabStatus.idle : TabStatus.error;
        if (!success) {
          _lastError = 'Error al enviar el mensaje por HTTP';
        }
        notifyListeners();
      });
    } else {
      // Use WebSocket for streaming
      _chatService.sendMessage(tabId: tab.id, text: text);
      tab.status = TabStatus.idle;
      notifyListeners();
    }
  }

  void addMessageToTab(String tabId, MessageModel message) {
    final tab = _tabs.firstWhere(
      (t) => t.id == tabId,
      orElse: () => _tabs.first,
    );
    tab.addMessage(message);
    notifyListeners();
  }

  void addSystemMessage(String text) {
    final tab = activeTab;
    final msg = MessageModel(text: text, sender: MessageSender.system);
    tab.addMessage(msg);
    notifyListeners();
  }

  void addToQueue(String description) {
    final tab = activeTab;
    tab.addTask(TaskItem(description: description));
    notifyListeners();
  }

  void updateTaskStatus(String taskId, String newStatus) {
    final tab = activeTab;
    tab.updateTaskStatus(taskId, newStatus);
    notifyListeners();
  }

  void detectTabEvolution(int index) {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    if (tab.type != TabType.research) return;

    final recentMessages = tab.messages
        .where((m) => m.sender == MessageSender.agent)
        .takeLast(3);

    bool hasCode = recentMessages.any((m) => m.text.contains('```'));
    if (hasCode) {
      _tabs[index] = tab.copyWith(
        title: '${tab.title} 💻',
        type: TabType.code,
      );
      addSystemMessage('Tab evolucionado a modo código');
      notifyListeners();
    }
  }

  void clearActiveTab() {
    final tab = activeTab;
    tab.messages.clear();
    tab.taskQueue.clear();
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _chatService.dispose();
    super.dispose();
  }
}

extension _TakeLast<T> on Iterable<T> {
  Iterable<T> takeLast(int count) {
    final list = toList();
    if (list.length <= count) return list;
    return list.sublist(list.length - count);
  }
}
