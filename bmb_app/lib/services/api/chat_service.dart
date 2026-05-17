import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
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
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  Stream<MessageModel> get newMessageStream => _newMessageController.stream;
  Stream<bool> get typingStream => _typingController.stream;
  Stream<String> get errorStream => _errorController.stream;

  ChatService(this._connectionService) {
    _connectionService.messageStream.listen(_handleIncomingMessage);
  }

  List<MessageModel> getMessagesForTab(String tabId) {
    return _messageHistory[tabId] ?? [];
  }

  void _handleIncomingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;

    switch (type) {
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
      case 'error':
        final errorText =
            message['message'] as String? ?? 'Error desconocido';
        _errorController.add(errorText);
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
    if (_currentStreamTabId == tabId &&
        _currentStreamBuffer != null &&
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

  /// Send a chat message via WebSocket (streaming path).
  /// For a more reliable non-streaming path, use sendViaHttp() instead.
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
      'type': 'chat_message',
      'tab_id': tabId,
      'text': text,
      'session_id': sessionId ?? '',
      'timestamp': DateTime.now().toIso8601String(),
      'message_id': userMessage.id,
    });
  }

  /// Send a chat message via HTTP POST /api/chat (functional REST path).
  /// This is the reliable path that works even when WS streaming has issues.
  Future<bool> sendViaHttp({
    required String tabId,
    required String text,
    String? sessionId,
  }) async {
    final ip = _connectionService.connectedIp;
    final port = _connectionService.connectedPort;
    if (ip == null || port == null) return false;

    final userMessage = MessageModel(
      text: text,
      sender: MessageSender.user,
    );
    _addMessageToHistory(tabId, userMessage);
    _newMessageController.add(userMessage);

    try {
      final uri = Uri.parse('http://$ip:$port/api/chat');
      final body = {
        'message': text,
        if (sessionId != null && sessionId.isNotEmpty)
          'session_id': sessionId,
      };

      _typingController.add(true);

      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      _typingController.add(false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final responseText = data['response'] as String? ??
            data['message'] as String? ??
            data['text'] as String? ??
            '';

        if (responseText.isNotEmpty) {
          final agentMessage = MessageModel(
            text: responseText,
            sender: MessageSender.agent,
            metadata: {'source': 'http_api'},
          );
          _addMessageToHistory(tabId, agentMessage);
          _newMessageController.add(agentMessage);
        }
        return true;
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        _errorController.add(
            'Error de autenticación (${response.statusCode}). '
            'Verifica el Access Token en Configuración.');
        return false;
      } else if (response.statusCode == 503) {
        _errorController.add(
            'Agente no disponible (503). El servidor está ocupado o '
            'reiniciando.');
        return false;
      } else {
        _errorController.add(
            'Error del servidor (${response.statusCode}): '
            '${response.body}');
        return false;
      }
    } on TimeoutException {
      _typingController.add(false);
      _errorController.add(
          'La solicitud tardó demasiado. El servidor podría estar '
          'sobrecargado.');
      return false;
    } catch (e) {
      _typingController.add(false);
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') ||
          errorStr.contains('SocketException')) {
        _errorController.add(
            'No se pudo conectar al servidor (${ip}:$port). '
            '¿Está en ejecución?');
      } else {
        _errorController.add('Error de conexión: $errorStr');
      }
      return false;
    }
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
    _errorController.close();
  }
}
