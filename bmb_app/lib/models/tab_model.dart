import 'package:uuid/uuid.dart';
import 'message_model.dart';

enum TabType { chat, research, code, live, console }

enum TabStatus { idle, processing, speaking, listening, error }

class TaskItemStatus {
  static const pending = 'pending';
  static const processing = 'processing';
  static const completed = 'completed';
  static const failed = 'failed';
}

class TaskItem {
  final String id;
  final String description;
  String status; // pending | processing | completed | failed

  TaskItem({
    String? id,
    required this.description,
    this.status = TaskItemStatus.pending,
  }) : id = id ?? const Uuid().v4();

  TaskItem copyWith({String? description, String? status}) {
    return TaskItem(
      id: id,
      description: description ?? this.description,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'status': status,
    };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String?,
        description: json['description'] as String? ?? '',
        status: json['status'] as String? ?? TaskItemStatus.pending,
      );
}

class TabModel {
  final String id;
  String title;
  final TabType type;
  final List<MessageModel> messages;
  bool isActive;
  TabStatus status;
  final List<TaskItem> taskQueue;

  TabModel({
    String? id,
    required this.title,
    required this.type,
    List<MessageModel>? messages,
    this.isActive = false,
    this.status = TabStatus.idle,
    List<TaskItem>? taskQueue,
  })  : id = id ?? const Uuid().v4(),
        messages = messages ?? [],
        taskQueue = taskQueue ?? [];

  int get pendingTaskCount =>
      taskQueue.where((t) => t.status == TaskItemStatus.pending).length;

  int get completedTaskCount =>
      taskQueue.where((t) => t.status == TaskItemStatus.completed).length;

  String get statusLabel {
    switch (status) {
      case TabStatus.idle:
        return 'Inactivo';
      case TabStatus.processing:
        return 'Procesando…';
      case TabStatus.speaking:
        return 'Hablando';
      case TabStatus.listening:
        return 'Escuchando';
      case TabStatus.error:
        return 'Error';
    }
  }

  void addMessage(MessageModel msg) {
    messages.add(msg);
  }

  void addTask(TaskItem task) {
    taskQueue.add(task);
  }

  void updateTaskStatus(String taskId, String newStatus) {
    final idx = taskQueue.indexWhere((t) => t.id == taskId);
    if (idx != -1) {
      taskQueue[idx].status = newStatus;
    }
  }

  TabModel copyWith({
    String? title,
    TabType? type,
    List<MessageModel>? messages,
    bool? isActive,
    TabStatus? status,
    List<TaskItem>? taskQueue,
  }) {
    return TabModel(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      messages: messages ?? List.from(this.messages),
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      taskQueue: taskQueue ?? List.from(this.taskQueue),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'isActive': isActive,
        'status': status.name,
        'messages': messages.map((m) => m.toJson()).toList(),
        'taskQueue': taskQueue.map((t) => t.toJson()).toList(),
    };

  factory TabModel.fromJson(Map<String, dynamic> json) => TabModel(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '',
        type: TabType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => TabType.chat,
        ),
        messages: (json['messages'] as List<dynamic>?)
                ?.map((m) => MessageModel.fromJson(m as Map<String, dynamic>))
                .toList() ??
            [],
        isActive: json['isActive'] as bool? ?? false,
        status: TabStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TabStatus.idle,
        ),
        taskQueue: (json['taskQueue'] as List<dynamic>?)
                ?.map((t) => TaskItem.fromJson(t as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
