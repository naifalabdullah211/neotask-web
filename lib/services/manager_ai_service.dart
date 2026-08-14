import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/task_model.dart';
import 'firestore_service.dart';

class ManagerAiAction {
  const ManagerAiAction({
    required this.type,
    required this.title,
    required this.payload,
    required this.requiresApproval,
    required this.employeeUid,
    required this.employeeNumber,
    required this.employeeName,
    required this.dueDate,
    required this.priority,
    required this.plannedHours,
    required this.category,
  });

  final String type;
  final String title;
  final String payload;
  final bool requiresApproval;
  final String employeeUid;
  final String employeeNumber;
  final String employeeName;
  final String dueDate;
  final String priority;
  final double plannedHours;
  final String category;

  bool get isTaskCreation =>
      type == 'create_task_draft' || type == 'create_initiative';

  bool get hasExecutionDetails =>
      employeeUid.trim().isNotEmpty &&
      employeeName.trim().isNotEmpty &&
      employeeNumber.trim().isNotEmpty &&
      DateTime.tryParse(dueDate) != null &&
      plannedHours > 0;

  factory ManagerAiAction.fromMap(Map<String, dynamic> map) {
    return ManagerAiAction(
      type: map['type']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      payload: map['payload']?.toString() ?? '',
      requiresApproval: map['requiresApproval'] != false,
      employeeUid: map['employeeUid']?.toString() ?? '',
      employeeNumber: map['employeeNumber']?.toString() ?? '',
      employeeName: map['employeeName']?.toString() ?? '',
      dueDate: map['dueDate']?.toString() ?? '',
      priority: map['priority']?.toString() ?? 'medium',
      plannedHours: (map['plannedHours'] as num?)?.toDouble() ?? 1,
      category: map['category']?.toString() ?? 'عام',
    );
  }
}

class ManagerAiDelegation {
  const ManagerAiDelegation({
    required this.id,
    required this.name,
    required this.status,
  });

  final String id;
  final String name;
  final String status;

  factory ManagerAiDelegation.fromMap(Map<String, dynamic> map) =>
      ManagerAiDelegation(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        status: map['status']?.toString() ?? 'completed',
      );
}

class ManagerAiResult {
  const ManagerAiResult({
    required this.reply,
    this.action,
    this.requestId,
    this.mode,
    this.truthStatus,
    this.truthNote,
    this.delegatedAgents = const [],
  });

  final String reply;
  final ManagerAiAction? action;
  final String? requestId;
  final String? mode;
  final String? truthStatus;
  final String? truthNote;
  final List<ManagerAiDelegation> delegatedAgents;
}

class ManagerAiService {
  static const String _endpoint = String.fromEnvironment(
    'NEOTASK_AI_API_URL',
    defaultValue: 'https://project-0wvza.vercel.app/api/multi-agent',
  );

  static const String _truthModeRule =
      'TRUTHMODE إلزامي: لا تدّعِ أن إجراءً تم تنفيذه أو حفظه أو إرساله أو '
      'تعديله إلا إذا كانت لديك نتيجة تنفيذ فعلية من NeoTask في نفس السياق. '
      'قبل اعتماد المدير استخدم ألفاظ مثل: مقترح، مسودة، جاهز للاعتماد، ولم '
      'يُنفذ بعد. إذا كانت المعلومة تحليلًا أو استنتاجًا فاذكر أنها استنتاج. '
      'إذا لم توجد بيانات كافية فقل غير متحقق بدل التخمين. لا تخترع موظفين أو '
      'مهام أو أرقامًا أو حالات. بيانات NeoTask الحية هي المصدر الوحيد للحقائق '
      'التشغيلية داخل النظام.';

  static Future<bool> isAvailable() async {
    try {
      final response = await http
          .get(Uri.parse(_endpoint))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['status'] == 'ready';
    } catch (_) {
      return false;
    }
  }

  static Future<ManagerAiResult> send({
    required String message,
    required List<Map<String, String>> history,
    required List<Map<String, dynamic>> teamContext,
    required List<String> agentRules,
    String languageCode = 'ar',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const ManagerAiException('يجب تسجيل الدخول أولًا');
    }

    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const ManagerAiException('تعذر التحقق من جلسة المستخدم');
    }

    final effectiveRules = <String>[
      ...agentRules.where((rule) => rule.trim().isNotEmpty),
      _truthModeRule,
    ];

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'message': message,
            'history': history,
            'teamContext': teamContext,
            'taskContext': _buildTaskContext(),
            'projectContext': _buildProjectContext(),
            'meetingContext': _buildMeetingContext(),
            'knowledgeContext': _buildKnowledgeContext(),
            'qualityContext': _buildQualityContext(),
            'agentRules': effectiveRules,
            'truthMode': true,
            'languageCode': languageCode == 'en' ? 'en' : 'ar',
          }),
        )
        .timeout(const Duration(seconds: 55));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ManagerAiException('وصل رد غير صالح من خدمة المساعد');
    }

    if (response.statusCode != 200) {
      final code = body['error']?.toString() ?? '';
      throw ManagerAiException(_messageForCode(code, languageCode));
    }

    final rawAction = body['action'];
    final action = rawAction is Map<String, dynamic>
        ? ManagerAiAction.fromMap(rawAction)
        : null;
    final mode = body['mode']?.toString() ?? '';
    final rawReply = body['reply']?.toString().trim().isNotEmpty == true
        ? body['reply'].toString().trim()
        : languageCode == 'en'
        ? 'Your request was analyzed.'
        : 'تم تحليل طلبك.';
    final rawDelegations = body['delegatedAgents'];
    final delegatedAgents = rawDelegations is List
        ? rawDelegations
              .whereType<Map>()
              .map(
                (item) => ManagerAiDelegation.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : const <ManagerAiDelegation>[];

    final truth = _classifyTruth(
      action: action,
      mode: mode,
      requestId: body['requestId']?.toString(),
      languageCode: languageCode,
    );
    final agentLine = delegatedAgents.isEmpty
        ? ''
        : languageCode == 'en'
        ? '\n🤖 Agents: ${delegatedAgents.map((agent) => agent.name).join(' ← ')}'
        : '\n🤖 الوكلاء: ${delegatedAgents.map((agent) => agent.name).join(' ← ')}';

    return ManagerAiResult(
      reply: '${truth.label}$agentLine\n$rawReply',
      action: action,
      requestId: body['requestId']?.toString(),
      mode: mode,
      truthStatus: truth.status,
      truthNote: truth.note,
      delegatedAgents: delegatedAgents,
    );
  }

  static List<Map<String, dynamic>> _buildTaskContext() {
    final tasks =
        FirestoreService.getAllTasks()
            .where((task) => !task.isPersonal)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return tasks
        .take(120)
        .map(
          (task) => {
            'taskId': task.taskId,
            'title': task.title,
            'assignedTo': task.assignedTo,
            'assignedBy': task.assignedBy,
            'dueDate': task.dueDate.toIso8601String(),
            'startDate': task.startDate.toIso8601String(),
            'status': task.status.name,
            'priority': task.priority.name,
            'plannedHours': task.plannedHours,
            'progressPercent': task.progressPercent,
            'category': task.category,
            'isOverdue': task.isOverdue,
            'updatedAt': task.updatedAt.toIso8601String(),
          },
        )
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _buildProjectContext() {
    final criteria = FirestoreService.getAllCriteria();
    return FirestoreService.getAllGoals()
        .take(60)
        .map((goal) {
          final items = criteria
              .where((item) => item.goalId == goal.goalId)
              .toList();
          final completed = items
              .where((item) => item.aggregateStatus.name == 'completed')
              .length;
          final inProgress = items
              .where((item) => item.aggregateStatus.name == 'inProgress')
              .length;
          return {
            'goalId': goal.goalId,
            'title': goal.title,
            'description': goal.description,
            'startDate': goal.startDate.toIso8601String(),
            'endDate': goal.endDate.toIso8601String(),
            'criteriaTotal': items.length,
            'criteriaCompleted': completed,
            'criteriaInProgress': inProgress,
            'criteria': items
                .take(30)
                .map(
                  (item) => {
                    'criterionId': item.criterionId,
                    'title': item.title,
                    'status': item.aggregateStatus.name,
                    'assignees': item.assignees,
                    'completion':
                        '${item.completionRatio.completed}/${item.completionRatio.total}',
                  },
                )
                .toList(growable: false),
          };
        })
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _buildMeetingContext() {
    final meetings = FirestoreService.getAllMeetings().toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return meetings
        .take(50)
        .map(
          (meeting) => {
            'meetingId': meeting.meetingId,
            'title': meeting.title,
            'startTime': meeting.startTime.toIso8601String(),
            'status': meeting.status.name,
            'location': meeting.location,
            'agendaItems': meeting.agendaItems.take(15).toList(),
            'minutes': meeting.minutes.length > 1200
                ? meeting.minutes.substring(0, 1200)
                : meeting.minutes,
            'decisions': meeting.decisions
                .take(30)
                .map(
                  (decision) => {
                    'text': decision.text,
                    'ownerUid': decision.ownerUid,
                    'ownerName': decision.ownerName,
                    'dueDate': decision.dueDate.toIso8601String(),
                    'linkedTaskId': decision.linkedTaskId,
                    'isCompleted': decision.isCompleted,
                  },
                )
                .toList(growable: false),
          },
        )
        .toList(growable: false);
  }

  static List<Map<String, dynamic>> _buildKnowledgeContext() {
    return FirestoreService.getAllDocuments()
        .take(50)
        .map((document) {
          final excerpt = document.content.trim();
          return {
            'documentId': document.documentId,
            'title': document.title,
            'kind': document.kind.name,
            'status': document.status.name,
            'department': document.department,
            'category': document.category,
            'tags': document.tags.take(12).toList(),
            'ownerName': document.ownerName,
            'reviewerName': document.reviewerName,
            'reviewDueDate': document.reviewDueDate?.toIso8601String(),
            'updatedAt': document.updatedAt.toIso8601String(),
            'contentExcerpt': excerpt.length > 1000
                ? excerpt.substring(0, 1000)
                : excerpt,
          };
        })
        .toList(growable: false);
  }

  static Map<String, dynamic> _buildQualityContext() {
    final tasks = FirestoreService.getAllTasks()
        .where((task) => !task.isPersonal)
        .toList();
    final criteria = FirestoreService.getAllCriteria();
    final documents = FirestoreService.getAllDocuments();
    final now = DateTime.now();
    return {
      'tasksTotal': tasks.length,
      'overdueTasks': tasks.where((task) => task.isOverdue).length,
      'rejectedTasks': tasks
          .where((task) => task.status.name == 'rejected')
          .length,
      'submittedForReview': tasks
          .where((task) => task.status.name == 'submitted')
          .length,
      'criteriaTotal': criteria.length,
      'criteriaNotStarted': criteria
          .where((item) => item.aggregateStatus.name == 'notStarted')
          .length,
      'criteriaInProgress': criteria
          .where((item) => item.aggregateStatus.name == 'inProgress')
          .length,
      'criteriaCompleted': criteria
          .where((item) => item.aggregateStatus.name == 'completed')
          .length,
      'documentsInReview': documents
          .where((doc) => doc.status.name == 'inReview')
          .length,
      'documentReviewsOverdue': documents.where((doc) {
        final due = doc.reviewDueDate;
        return doc.status.name == 'inReview' &&
            due != null &&
            due.isBefore(now);
      }).length,
    };
  }

  static _TruthClassification _classifyTruth({
    required ManagerAiAction? action,
    required String mode,
    required String? requestId,
    required String languageCode,
  }) {
    final english = languageCode == 'en';
    if (action != null) {
      return _TruthClassification(
        status: 'pending',
        label: english
            ? '🟡 Proposed — not executed yet'
            : '🟡 مقترح — لم يُنفذ بعد',
        note: english
            ? 'Any change waits for manager approval and an actual NeoTask execution result.'
            : 'أي تغيير ينتظر اعتماد المدير ثم نتيجة تنفيذ فعلية من NeoTask.',
      );
    }
    if (mode == 'resilient-local') {
      return _TruthClassification(
        status: 'confirmed_local',
        label: english
            ? '✅ Calculated from available NeoTask data'
            : '✅ محسوب من بيانات NeoTask المتاحة',
        note: english
            ? 'This result comes from deterministic local logic and is not an execution claim.'
            : 'النتيجة صادرة من المسار المحلي الحتمي وليست ادعاء تنفيذ.',
      );
    }
    if (mode == 'multi-agent' || mode == 'ai-gateway') {
      return _TruthClassification(
        status: 'ai_analysis',
        label: english
            ? '🟡 AI analysis — not execution evidence'
            : '🟡 تحليل AI — ليس دليل تنفيذ',
        note: requestId == null || requestId.isEmpty
            ? english
                  ? 'This is analysis; only the NeoTask audit log can prove execution.'
                  : 'الرد تحليلي ويحتاج سجل NeoTask لإثبات أي تنفيذ.'
            : english
            ? 'A response ID is available, but only the NeoTask audit log proves execution.'
            : 'معرّف الاستجابة متاح، لكن التنفيذ لا يُثبت إلا بسجل NeoTask.',
      );
    }
    return _TruthClassification(
      status: 'unverified',
      label: english ? '🔴 Unverified' : '🔴 غير متحقق',
      note: english
          ? 'The response path could not be verified; do not treat it as execution evidence.'
          : 'لم يصل تصنيف موثوق لمسار الاستجابة؛ لا تعتمد عليه كدليل تنفيذ.',
    );
  }

  static String _messageForCode(String code, String languageCode) {
    final english = languageCode == 'en';
    switch (code) {
      case 'manager-only':
        return english
            ? 'This feature is available to managers only'
            : 'هذه الميزة متاحة للمدير فقط';
      case 'rate-limit':
        return english
            ? 'Too many requests. Try again in a minute'
            : 'تم إرسال طلبات كثيرة. حاول بعد دقيقة';
      case 'invalid-message':
        return english
            ? 'The request is empty or too long'
            : 'الطلب فارغ أو طويل جدًا';
      case 'missing-token':
      case 'invalid-token':
        return english
            ? 'Your session expired. Sign in again'
            : 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى';
      default:
        return english
            ? 'The Manager AI Assistant is unavailable right now'
            : 'تعذر الاتصال بمساعد المدير الآن';
    }
  }
}

class _TruthClassification {
  const _TruthClassification({
    required this.status,
    required this.label,
    required this.note,
  });

  final String status;
  final String label;
  final String note;
}

class ManagerAiException implements Exception {
  const ManagerAiException(this.message);

  final String message;

  @override
  String toString() => message;
}
