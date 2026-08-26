import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Executes event-based automation while a manager is actively using NeoTask.
/// The hourly GitHub runner remains the offline safety net.
class AutomationRuntimeService {
  AutomationRuntimeService._();

  static final instance = AutomationRuntimeService._();
  static final _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _rulesSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _tasksSub;
  List<Map<String, dynamic>> _rules = const [];
  final Map<String, String> _statuses = {};
  bool _tasksReady = false;
  String? _managerUid;

  void start(String managerUid) {
    if (_managerUid == managerUid && _tasksSub != null) return;
    stop();
    _managerUid = managerUid;
    _rulesSub = _db
        .collection('automation_rules')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
          _rules = snapshot.docs.map((doc) => doc.data()).toList();
        });
    _tasksSub = _db.collection('tasks').snapshots().listen(
      _handleTasks,
      onError: (Object error) {
        if (kDebugMode) debugPrint('Automation live runner: $error');
      },
    );
  }

  void stop() {
    _rulesSub?.cancel();
    _tasksSub?.cancel();
    _rulesSub = null;
    _tasksSub = null;
    _rules = const [];
    _statuses.clear();
    _tasksReady = false;
    _managerUid = null;
  }

  void _handleTasks(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_tasksReady) {
      for (final doc in snapshot.docs) {
        _statuses[doc.id] = doc.data()['status'] as String? ?? '';
      }
      _tasksReady = true;
      return;
    }
    for (final change in snapshot.docChanges) {
      final task = change.doc.data();
      if (task == null) continue;
      final oldStatus = _statuses[change.doc.id];
      final newStatus = task['status'] as String? ?? '';
      _statuses[change.doc.id] = newStatus;
      if (change.type == DocumentChangeType.added) {
        unawaited(_process(task, change.doc.id, 'taskCreated'));
      } else if (change.type == DocumentChangeType.modified &&
          oldStatus != null &&
          oldStatus != newStatus) {
        unawaited(_process(task, change.doc.id, 'statusChanged'));
      } else if (change.type == DocumentChangeType.removed) {
        _statuses.remove(change.doc.id);
      }
    }
  }

  Future<void> _process(
    Map<String, dynamic> task,
    String taskId,
    String trigger,
  ) async {
    final managerUid = _managerUid;
    if (managerUid == null) return;
    for (final rule in _rules) {
      if (rule['trigger'] != trigger || !_conditionMatches(rule, task)) {
        continue;
      }
      final eventKey = trigger == 'taskCreated'
          ? 'created_${task['createdAt']}'
          : 'status_${task['status']}_${task['updatedAt']}';
      await _reserveAndExecute(
        rule: rule,
        task: task,
        taskId: taskId,
        trigger: trigger,
        eventKey: eventKey,
        managerUid: managerUid,
      );
    }
  }

  bool _conditionMatches(
    Map<String, dynamic> rule,
    Map<String, dynamic> task,
  ) {
    final field = rule['conditionField'] as String? ?? 'any';
    if (field == 'any') return true;
    final key = switch (field) {
      'assignee' => 'assignedTo',
      'progress' => 'progressPercent',
      _ => field,
    };
    final actual = task[key] ?? '';
    final expected = rule['conditionValue'] ?? '';
    return switch (rule['conditionOperator']) {
      'contains' => actual
          .toString()
          .toLowerCase()
          .contains(expected.toString().toLowerCase()),
      'greaterOrEqual' =>
        (num.tryParse(actual.toString()) ?? 0) >=
            (num.tryParse(expected.toString()) ?? 0),
      _ => actual.toString().toLowerCase() ==
          expected.toString().toLowerCase(),
    };
  }

  Future<void> _reserveAndExecute({
    required Map<String, dynamic> rule,
    required Map<String, dynamic> task,
    required String taskId,
    required String trigger,
    required String eventKey,
    required String managerUid,
  }) async {
    final rawId = '${rule['ruleId']}_${taskId}_$eventKey';
    final runId = rawId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final runRef = _db.collection('automation_runs').doc(runId);
    final startedAt = DateTime.now();
    final reserved = await _db.runTransaction((transaction) async {
      if ((await transaction.get(runRef)).exists) return false;
      transaction.set(runRef, {
        'runId': runId,
        'ruleId': rule['ruleId'],
        'ruleName': rule['name'],
        'taskId': taskId,
        'taskTitle': task['title'] ?? '',
        'action': rule['action'],
        'trigger': trigger,
        'source': 'manager-live',
        'actorUid': managerUid,
        'status': 'running',
        'executedAt': startedAt.toIso8601String(),
        'startedAt': startedAt.toIso8601String(),
      });
      return true;
    });
    if (!reserved) return;
    try {
      await _executeAction(rule, task, taskId, managerUid);
      final completedAt = DateTime.now();
      await runRef.update({
        'status': 'completed',
        'completedAt': completedAt.toIso8601String(),
        'durationMs': completedAt.difference(startedAt).inMilliseconds,
      });
    } catch (error) {
      final completedAt = DateTime.now();
      await runRef.update({
        'status': 'failed',
        'message': error.toString(),
        'completedAt': completedAt.toIso8601String(),
        'durationMs': completedAt.difference(startedAt).inMilliseconds,
      });
    }
  }

  Future<void> _executeAction(
    Map<String, dynamic> rule,
    Map<String, dynamic> task,
    String taskId,
    String managerUid,
  ) async {
    final action = rule['action'];
    if (action == 'notifyAssignee' || action == 'notifyManager') {
      final recipients = <String>{};
      if (action == 'notifyAssignee') {
        final uid = task['assignedTo'] as String? ?? '';
        if (uid.isNotEmpty) recipients.add(uid);
      } else {
        final users = await _db
            .collection('users')
            .where('accountStatus', isEqualTo: 'active')
            .get();
        for (final userDoc in users.docs) {
          final user = userDoc.data();
          if (user['role'] == 'manager' || user['employeeNumber'] == '400161') {
            recipients.add(userDoc.id);
          }
        }
      }
      final batch = _db.batch();
      for (final recipientUid in recipients) {
        final ref = _db.collection('notifications').doc(_uuid.v4());
        batch.set(ref, {
          'notificationId': ref.id,
          'recipientUid': recipientUid,
          'type': 'automation',
          'title': 'أتمتة: ${rule['name']}',
          'body': (rule['actionValue'] as String?)?.trim().isNotEmpty == true
              ? rule['actionValue']
              : 'تم تشغيل قاعدة على المهمة: ${task['title'] ?? ''}',
          'relatedPollId': null,
          'relatedTaskId': taskId,
          'payload': {'ruleId': rule['ruleId']},
          'createdAt': DateTime.now().toIso8601String(),
          'readAt': null,
        });
      }
      await batch.commit();
      return;
    }
    if (action == 'setPriority') {
      final value = rule['actionValue'];
      if (!const ['low', 'medium', 'high'].contains(value)) {
        throw StateError('قيمة الأولوية غير صالحة');
      }
      await _updateTaskWithHistory(
        taskId,
        managerUid,
        {'priority': value},
        'الأتمتة «${rule['name']}» غيّرت أولوية المهمة',
      );
      return;
    }
    if (action == 'reassign') {
      final targetId = rule['actionValue'] as String? ?? '';
      final target = await _db.collection('users').doc(targetId).get();
      final user = target.data();
      if (!target.exists ||
          user?['role'] != 'employee' ||
          user?['accountStatus'] != 'active') {
        throw StateError('الموظف المستهدف غير متاح');
      }
      await _updateTaskWithHistory(
        taskId,
        managerUid,
        {'assignedTo': targetId, 'viewedByEmployee': false},
        'الأتمتة «${rule['name']}» أعادت إسناد المهمة',
      );
    }
  }

  Future<void> _updateTaskWithHistory(
    String taskId,
    String managerUid,
    Map<String, dynamic> fields,
    String note,
  ) async {
    final now = DateTime.now().toIso8601String();
    final history = _db.collection('task_history').doc(_uuid.v4());
    final batch = _db.batch();
    batch.update(_db.collection('tasks').doc(taskId), {
      ...fields,
      'updatedAt': now,
    });
    batch.set(history, {
      'historyId': history.id,
      'taskId': taskId,
      'action': 'statusChange',
      'actorUid': managerUid,
      'note': note,
      'timestamp': now,
    });
    await batch.commit();
  }
}
