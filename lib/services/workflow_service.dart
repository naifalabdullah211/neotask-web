import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
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

  /// Permanently deletes a form and every response submitted to it.
  ///
  /// Firestore does not cascade parent-document deletion to subcollections,
  /// so responses are removed in bounded batches before the form itself.
  static Future<void> deleteForm(String formId) async {
    final formRef = _db.collection('custom_forms').doc(formId);
    final responsesRef = formRef.collection('responses');

    while (true) {
      final snapshot = await responsesRef.limit(400).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final response in snapshot.docs) {
        batch.delete(response.reference);
      }
      await batch.commit();

      if (snapshot.docs.length < 400) break;
    }

    await formRef.delete();
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

  /// Creates real Firebase Authentication accounts without replacing the
  /// manager's current session. A named secondary Firebase app owns each
  /// temporary Auth session, while the manager's primary Firestore session
  /// creates the protected employee profile.
  static Future<Map<String, dynamic>> importEmployees(
    List<Map<String, dynamic>> employees,
  ) async {
    final results = <Map<String, dynamic>>[];
    var createdCount = 0;
    for (var index = 0; index < employees.length; index++) {
      final row = employees[index];
      final employeeNumber = (row['employeeNumber'] as String).trim();
      final compact = employeeNumber
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '');
      final email = '$compact@neotask.local';
      FirebaseApp? secondaryApp;
      fb_auth.UserCredential? credential;
      try {
        secondaryApp = await Firebase.initializeApp(
          name: 'bulk-${_uuid.v4()}',
          options: Firebase.app().options,
        );
        final secondaryAuth = fb_auth.FirebaseAuth.instanceFor(
          app: secondaryApp,
        );
        credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email,
          password: row['password'] as String,
        );
        final now = DateTime.now().toIso8601String();
        await _db.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'name': (row['name'] as String).trim(),
          'email': email,
          'employeeNumber': employeeNumber,
          'role': 'employee',
          'accountStatus': 'active',
          'approvedBy': fb_auth.FirebaseAuth.instance.currentUser!.uid,
          'approvedAt': now,
          'createdAt': now,
          'soundMessagesEnabled': true,
          'soundTasksEnabled': true,
          'remindersEnabled': true,
          'weeklyCapacityHours': 40,
        });
        createdCount++;
        results.add({
          'index': index,
          'success': true,
          'uid': credential.user!.uid,
        });
        try {
          await secondaryAuth.signOut();
        } catch (_) {
          // The named Firebase app is deleted below, so cleanup can continue.
        }
      } on fb_auth.FirebaseAuthException catch (error) {
        results.add({
          'index': index,
          'success': false,
          'error': error.code == 'email-already-in-use'
              ? 'الرقم الوظيفي موجود مسبقًا'
              : 'تعذر إنشاء الحساب',
        });
      } catch (_) {
        if (credential?.user != null) {
          try {
            await credential!.user!.delete();
          } catch (_) {
            // Best-effort rollback if Firestore profile creation failed.
          }
        }
        results.add({
          'index': index,
          'success': false,
          'error': 'تعذر إنشاء الحساب',
        });
      } finally {
        try {
          await secondaryApp?.delete();
        } catch (_) {
          // Do not abort the remaining rows because cleanup failed.
        }
      }
    }
    final managerUid = fb_auth.FirebaseAuth.instance.currentUser!.uid;
    final jobId = _uuid.v4();
    await _db.collection('import_jobs').doc(jobId).set({
      'jobId': jobId,
      'type': 'employees',
      'rowCount': employees.length,
      'createdCount': createdCount,
      'failedCount': employees.length - createdCount,
      'createdBy': managerUid,
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'completed',
    });
    return {
      'createdCount': createdCount,
      'failedCount': employees.length - createdCount,
      'results': results,
    };
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
