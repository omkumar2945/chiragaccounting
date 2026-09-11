import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chirag_accounting/features/tasks/models/work_task.dart';

class TaskPersistenceService {
  static const String _tasksKey = 'v4.task_engine.tasks';
  static const String _syncQueueKey = 'v4.task_engine.sync_queue';

  Future<List<WorkTask>> loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_tasksKey);
    if (raw == null || raw.trim().isEmpty) {
      return const <WorkTask>[];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((value) => WorkTask.fromMap(Map<String, dynamic>.from(value)))
          .toList(growable: false);
    } catch (_) {
      return const <WorkTask>[];
    }
  }

  Future<void> saveTasks(List<WorkTask> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = tasks.map((task) => task.toMap()).toList(growable: false);
    await prefs.setString(_tasksKey, jsonEncode(payload));
  }

  Future<void> enqueueSync(Map<String, dynamic> command) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await loadSyncQueue();
    queue.add(command);
    await prefs.setString(_syncQueueKey, jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> loadSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_syncQueueKey);
    if (raw == null || raw.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList(growable: true);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> clearSyncQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_syncQueueKey);
  }
}
