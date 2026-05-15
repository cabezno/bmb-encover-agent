import 'package:uuid/uuid.dart';

enum MessageSender { user, agent, system }

enum MessageType { text, audio, status }

class MessageModel {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final MessageType type;
  final String? audioPath;
  final Map<String, dynamic>? metadata;

  MessageModel({
    String? id,
    required this.text,
    required this.sender,
    DateTime? timestamp,
    this.type = MessageType.text,
    this.audioPath,
    this.metadata,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  bool get isMine => sender == MessageSender.user;

  MessageModel copyWith({
    String? text,
    MessageSender? sender,
    DateTime? timestamp,
    MessageType? type,
    String? audioPath,
    Map<String, dynamic>? metadata,
  }) {
    return MessageModel(
      id: id,
      text: text ?? this.text,
      sender: sender ?? this.sender,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      audioPath: audioPath ?? this.audioPath,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sender': sender.name,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'audioPath': audioPath,
    };
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String?,
      text: json['text'] as String? ?? '',
      sender: MessageSender.values.firstWhere(
        (e) => e.name == json['sender'],
        orElse: () => MessageSender.system,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      audioPath: json['audioPath'] as String?,
    );
  }

  @override
  String toString() => 'MessageModel{id: $id, sender: $sender, text: $text}';
}
