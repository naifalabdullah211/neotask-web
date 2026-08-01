import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

import '../models/automation_rule_model.dart';
import '../models/custom_form_model.dart';
import '../models/task_model.dart';

class WorkflowService {
  WorkflowService._();

  static final _db = FirebaseFirestore.instance;
  static const _uuid = Uuid();

  static Stream<List<AutomationRule>> watchAutomationRules() {
    return _db.collection('automation_rules').snapshots().map((snapshot) {
      final rules = snapshot.docs
          .map((doc) => AutomationRule.fromMap(doc.data()))
          .toList();
      rules.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return rules;
    });
  }

  static Stream<List<AutomationRun>> watchAutomationRuns() {
    return _db
        .collection('automation_runs')
        .orderBy('executedAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AutomationRun.fromMap(doc.data()))
              .toList(),
        );
  }

  static Future<void> saveAutomationRule(AutomationRule rule) {
    return _db
        .collection('automation_rules')
        .doc(rule.ruleId)
        .set(rule.toMap());
  }

  static Future<void> setAutomationRuleActive(
    AutomationRule rule,
    bool active,
  ) {
    return _db.collection('automation_rules').doc(rule.ruleId).update({
      'isActive': active,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deleteAutomationRule(String ruleId) {
    return _db.collection('automation_rules').doc(ruleId).delete();
  }

  static Stream<List<CustomFormDefinition>> watchForms() {
    return _db.collection('custom_forms').snapshots().map((snapshot) {
      final forms = snapshot.docs
          .map((doc) => CustomFormDefinition.fromMap(doc.data()))
          .toList();
      forms.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return forms;
    });
  }

  static Future<CustomFormDefinition?> loadPublicForm(String formId) async {
    final snapshot = await _db.collection('custom_forms').doc(formId).get();
    if (!snapshot.exists) return null;
    final form = CustomFormDefinition.fromMap(snapshot.data()!);
    return form.isActive ? form : null;
  }

  static Future<void> saveForm(CustomFormDefinition form) {
    return _db.collection('custom_forms').doc(form.formId).set(form.toMap());
  }

  static Future<void> setFormActive(String formId, bool active) {
    return _db.collection('custom_forms').doc(formId).update({
      'isActive': active,
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  static Stream<List<CustomFormResponse>> watchFormResponses(String formId) {
    return _db
        .collection('custom_forms')
        .doc(formId)
        .collection('responses')
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CustomFormResponse.fromMap(doc.data()))
              .toList(),
        );
  }

  static Future<void> submitPublicForm({
    required CustomFormDefinition form,
    required Map<String, dynamic> answers,
  }) {
    final responseId = _uuid.v4();
    return _db
        .collection('custom_forms')
        .doc(form.formId)
        .collection('responses')
        .doc(responseId)
        .set({
          'responseId': responseId,
          'formId': form.formId,
          'answers': answers,
          'submittedAt': DateTime.now().toIso8601String(),
          'source': 'publicLink',
        });
  }

  /// Creates real Firebase Authentication accounts and Firestore profiles.
  /// The callable verifies the manager role again on the server and returns
  /// per-row results so one duplicate does not hide the outcome of the rest.
  static Future<Map<String, dynamic>> importEmployees(
    List<Map<String, dynamic>> employees,
  ) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'bulkImportEmployees',
    );
    final response = await callable.call<Map<String, dynamic>>({
      'employees': employees,
    });
    return Map<String, dynamic>.from(response.data);
  }

  /// Imports validated tasks in chunks below Firestore's batch limit and
  /// writes an append-only task history row for every created task.
  static Future<String> importTasks({
    required List<AppTask> tasks,
    required String managerUid,
    required String sourceFileName,
  }) async {
    final jobId = _uuid.v4();
    for (var offset = 0; offset < tasks.length; offset += 200) {
      final end = (offset + 200).clamp(0, tasks.length).toInt();
      final batch = _db.batch();
      for (final task in tasks.sublist(offset, end)) {
        batch.set(_db.collection('tasks').doc(task.taskId), task.toMap());
        final historyId = _uuid.v4();
        batch.set(_db.collection('task_history').doc(historyId), {
          'historyId': historyId,
          'taskId': task.taskId,
          'action': 'statusChange',
          'actorUid': managerUid,
          'note': 'تم إنشاء المهمة عبر الاستيراد الجماعي',
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit();
    }
    await _db.collection('import_jobs').doc(jobId).set({
      'jobId': jobId,
      'type': 'tasks',
      'sourceFileName': sourceFileName,
      'rowCount': tasks.length,
      'createdBy': managerUid,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'completed',
    });
    return jobId;
  }
}
