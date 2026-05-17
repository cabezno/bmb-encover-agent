import 'dart:async';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../models/message_model.dart';
import '../../models/tab_model.dart';
import '../connection/connection_service.dart';

class ChatService {
  final ConnectionService _connectionService;
  final Map<String, List<MessageModel>> _messageHistory = {};
  final StreamController<MessageModel> _newMessageController =
      StreamController<MessageModel>.broadcast();
  final StreamController<bool> _typingController =
      StreamController<bool>.broadcast();

  Stream<MessageModel> get newMessageStream => _newMessageController.stream;
  Stream<bool> get typingStream => _typingController.stream;

  ChatService(this._connectionService) {
    _connectionService.messageStream.listen(_handleIncomingMessage);
  }

  List<MessageModel> getMessagesForTab(String tabId) {
    return _messageHistory[tabId] ?? [];
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
      case 'connected':
        _typingController.add(false);
        break;
      case 'chat_response':
      case 'message':
        final tabId = message['tab_id'] as String? ?? 'default';
        final msg = MessageModel(
          id: message['id'] as String?,
          text: message['text'] as String? ?? '',
          sender: MessageSender.agent,
          timestamp: message['timestamp'] != null
              ? DateTime.tryParse(message['timestamp'] as String)
              : null,
        );
        _addMessageToHistory(tabId, msg);
        _newMessageController.add(msg);
        break;
      case 'typing':
        _typingController.add(message['is_typing'] as bool? ?? false);
        break;
      case 'stream_chunk':
        // Handle streaming response chunks
        final tabId = message['tab_id'] as String? ?? 'default';
        final chunk = message['text'] as String? ?? '';
        _handleStreamChunk(tabId, chunk);
        break;
      case 'stream_end':
        final tabId = message['tab_id'] as String? ?? 'default';
        _finalizeStreamChunk(tabId, message);
        _typingController.add(false);
        break;
    }
  }

  String? _currentStreamBuffer;
  String? _currentStreamTabId;

  void _handleStreamChunk(String tabId, String chunk) {
    if (_currentStreamTabId != tabId) {
      _currentStreamBuffer = chunk;
      _currentStreamTabId = tabId;
    } else {
      _currentStreamBuffer = (_currentStreamBuffer ?? '') + chunk;
    }
  }

  void _finalizeStreamChunk(String tabId, Map<String, dynamic> metadata) {
    if (_currentStreamTabId == tabId && _currentStreamBuffer != null &&
        _currentStreamBuffer!.isNotEmpty) {
      final msg = MessageModel(
        text: _currentStreamBuffer!,
        sender: MessageSender.agent,
        metadata: metadata,
      );
      _addMessageToHistory(tabId, msg);
      _newMessageController.add(msg);
    }
    _currentStreamBuffer = null;
    _currentStreamTabId = null;
  }

  void _addMessageToHistory(String tabId, MessageModel message) {
    _messageHistory.putIfAbsent(tabId, () => []);
    _messageHistory[tabId]!.add(message);
  }

  void sendMessage({
    required String tabId,
    required String text,
    String? sessionId,
  }) {
    final userMessage = MessageModel(
      text: text,
      sender: MessageSender.user,
    );
    _addMessageToHistory(tabId, userMessage);
    _newMessageController.add(userMessage);

    // Send through WebSocket
    _connectionService.sendMessage({
      'type': 'message',
      'tab_id': tabId,
      'text': text,
      'session_id': sessionId ?? '',
    });
  }

  void sendVoiceMessage({
    required String tabId,
    required String audioBase64,
    String? sessionId,
  }) {
    final msg = MessageModel(
      text: '[Audio]',
      sender: MessageSender.user,
      type: MessageType.audio,
    );
    _addMessageToHistory(tabId, msg);
    _newMessageController.add(msg);

    _connectionService.sendMessage({
      'type': 'audio_message',
      'tab_id': tabId,
      'audio': audioBase64,
      'session_id': sessionId ?? '',
    });
  }

  void sendSystemMessage(String tabId, String text) {
    final msg = MessageModel(
      text: text,
      sender: MessageSender.system,
    );
    _addMessageToHistory(tabId, msg);
    _newMessageController.add(msg);
  }

  void clearHistory(String tabId) {
    _messageHistory[tabId]?.clear();
  }

  void dispose() {
    _newMessageController.close();
    _typingController.close();
  }
}
