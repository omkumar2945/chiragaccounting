import 'dart:async';

import 'package:chirag_accounting/core/constants/api_constants.dart';
import 'package:flutter/foundation.dart';

import 'package:chirag_accounting/core/events/app_event.dart';
import 'package:chirag_accounting/core/events/app_event_bus.dart';
import 'package:chirag_accounting/core/events/event_types.dart';
import 'package:chirag_accounting/features/tasks/models/work_task.dart';
import 'package:chirag_accounting/features/tasks/services/task_engine_api_service.dart';
import 'package:chirag_accounting/features/tasks/services/task_persistence_service.dart';
import 'package:chirag_accounting/features/workflow/models/universal_status.dart';

class TaskEngineService extends ChangeNotifier {
  TaskEngineService({
    TaskPersistenceService? persistenceService,
    TaskEngineApiService? apiService,
  })  : _persistenceService = persistenceService ?? TaskPersistenceService(),
        _apiService = apiService ?? TaskEngineApiService() {
    _restoreFromDisk();
    _sub = AppEventBus.instance.stream.listen(_onEvent);
    _syncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      _flushSyncQueue();
    });
  }

  final TaskPersistenceService _persistenceService;
  final TaskEngineApiService _apiService;
  final List<WorkTask> _tasks = <WorkTask>[];
  late final StreamSubscription<AppEvent> _sub;
  late final Timer _syncTimer;

  List<WorkTask> get tasks => List.unmodifiable(_tasks);

  int countByBucket(WorkQueueBucket bucket) {
    final now = DateTime.now();
    return _tasks.where((task) {
      if (bucket == WorkQueueBucket.overdue) {
        return task.dueDate.isBefore(now) && task.status != UniversalStatus.completed;
      }
      return task.bucket == bucket;
    }).length;
  }

  List<WorkTask> tasksForClient(String clientName) {
    final key = clientName.trim().toLowerCase();
    return _tasks
        .where((task) => task.clientName.trim().toLowerCase() == key)
        .toList(growable: false);
  }

  void markStatus(String taskId, UniversalStatus status) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;
    final old = _tasks[index];
    _tasks[index] = old.copyWith(status: status, bucket: _bucketForStatus(status));
    AppEventBus.instance.publish(
      AppEvent.create(
        eventType: EventTypes.taskUpdated,
        entityType: 'task',
        entityId: taskId,
        clientId: old.clientName,
        role: 'system',
        payload: <String, dynamic>{
          'status': status.name,
        },
      ),
    );
    _persistAndEnqueueSync(
      <String, dynamic>{
        'op': 'task.update',
        'taskId': taskId,
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void _onEvent(AppEvent event) {
    switch (event.eventType) {
      case EventTypes.salesInvoiceCreated:
        _createTaskFromInvoice(event);
        break;
      case EventTypes.purchaseBillCreated:
        _createTaskFromPurchase(event);
        break;
      case EventTypes.workflowStageChanged:
        _onWorkflowChanged(event);
        break;
      default:
        return;
    }
  }

  void _createTaskFromInvoice(AppEvent event) {
    _tasks.add(
      WorkTask(
        id: 'task-${event.eventId}',
        title: 'Verify Sales Invoice',
        clientName: event.payload['clientName']?.toString() ?? event.clientId,
        entityType: event.entityType,
        entityId: event.entityId,
        owner: 'Accountant',
        reviewer: 'CA',
        dueDate: DateTime.now().add(const Duration(hours: 24)),
        status: UniversalStatus.submitted,
        bucket: WorkQueueBucket.waitingAccountant,
        slaHours: 24,
        createdAt: DateTime.now(),
        remarks: 'Auto-created from sales.invoice.created',
      ),
    );
    _persistAndEnqueueSync(
      <String, dynamic>{
        'op': 'task.create',
        'taskId': _tasks.last.id,
        'source': event.eventType,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void _createTaskFromPurchase(AppEvent event) {
    _tasks.add(
      WorkTask(
        id: 'task-${event.eventId}',
        title: 'Review Purchase Bill',
        clientName: event.payload['vendorName']?.toString() ?? event.clientId,
        entityType: event.entityType,
        entityId: event.entityId,
        owner: 'Accountant',
        reviewer: 'Manager',
        dueDate: DateTime.now().add(const Duration(hours: 20)),
        status: UniversalStatus.submitted,
        bucket: WorkQueueBucket.waitingAccountant,
        slaHours: 20,
        createdAt: DateTime.now(),
        remarks: 'Auto-created from purchase.bill.created',
      ),
    );
    _persistAndEnqueueSync(
      <String, dynamic>{
        'op': 'task.create',
        'taskId': _tasks.last.id,
        'source': event.eventType,
        'createdAt': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  void _onWorkflowChanged(AppEvent event) {
    final taskId = event.payload['taskId']?.toString();
    final statusName = event.payload['status']?.toString();
    if (taskId == null || statusName == null) return;
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index < 0) return;
    final status = UniversalStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => _tasks[index].status,
    );
    _tasks[index] = _tasks[index].copyWith(
      status: status,
      bucket: _bucketForStatus(status),
    );
    _persistAndEnqueueSync(
      <String, dynamic>{
        'op': 'task.workflow_status',
        'taskId': taskId,
        'status': status.name,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  Future<void> _restoreFromDisk() async {
    final restored = await _persistenceService.loadTasks();
    if (restored.isEmpty) return;
    _tasks
      ..clear()
      ..addAll(restored);
    notifyListeners();
  }

  Future<void> _persistAndEnqueueSync(Map<String, dynamic> command) async {
    await _persistenceService.saveTasks(_tasks);
    await _persistenceService.enqueueSync(command);
  }

  Future<void> _flushSyncQueue() async {
    if (ApiConstants.useMockApi) return;
    final queue = await _persistenceService.loadSyncQueue();
    if (queue.isEmpty) return;
    try {
      await _apiService.flushSyncQueue(
        businessId: 'chirag-main',
        userId: 'system',
        commands: queue,
      );
      await _apiService.upsertTasks(
        businessId: 'chirag-main',
        tasks: _tasks,
      );
      await _persistenceService.clearSyncQueue();
    } catch (_) {
      // Keep queue for later retry.
    }
  }

  WorkQueueBucket _bucketForStatus(UniversalStatus status) {
    switch (status) {
      case UniversalStatus.draft:
        return WorkQueueBucket.pendingOcr;
      case UniversalStatus.submitted:
        return WorkQueueBucket.waitingAccountant;
      case UniversalStatus.verified:
        return WorkQueueBucket.waitingCa;
      case UniversalStatus.approved:
        return WorkQueueBucket.waitingApproval;
      case UniversalStatus.completed:
        return WorkQueueBucket.completedToday;
      case UniversalStatus.archived:
        return WorkQueueBucket.completedToday;
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    _syncTimer.cancel();
    super.dispose();
  }
}
