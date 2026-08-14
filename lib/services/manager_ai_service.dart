import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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

class ManagerAiResult {
  const ManagerAiResult({
    required this.reply,
    this.action,
    this.requestId,
    this.mode,
    this.truthStatus,
    this.truthNote,
  });

  final String reply;
  final ManagerAiAction? action;
  final String? requestId;
  final String? mode;
  final String? truthStatus;
  final String? truthNote;
}

class ManagerAiService {
  static const String _endpoint = String.fromEnvironment(
    'NEOTASK_AI_API_URL',
    defaultValue: 'https://project-0wvza.vercel.app/api/agent',
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
            'agentRules': effectiveRules,
            'truthMode': true,
          }),
        )
        .timeout(const Duration(seconds: 35));

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const ManagerAiException('وصل رد غير صالح من خدمة المساعد');
    }

    if (response.statusCode != 200) {
      final code = body['error']?.toString() ?? '';
      throw ManagerAiException(_messageForCode(code));
    }

    final rawAction = body['action'];
    final action = rawAction is Map<String, dynamic>
        ? ManagerAiAction.fromMap(rawAction)
        : null;
    final mode = body['mode']?.toString() ?? '';
    final rawReply = body['reply']?.toString().trim().isNotEmpty == true
        ? body['reply'].toString().trim()
        : 'تم تحليل طلبك.';

    final truth = _classifyTruth(
      action: action,
      mode: mode,
      requestId: body['requestId']?.toString(),
    );

    return ManagerAiResult(
      reply: '${truth.label}\n$rawReply',
      action: action,
      requestId: body['requestId']?.toString(),
      mode: mode,
      truthStatus: truth.status,
      truthNote: truth.note,
    );
  }

  static _TruthClassification _classifyTruth({
    required ManagerAiAction? action,
    required String mode,
    required String? requestId,
  }) {
    if (action != null) {
      return const _TruthClassification(
        status: 'pending',
        label: '🟡 مقترح — لم يُنفذ بعد',
        note: 'أي تغيير ينتظر اعتماد المدير ثم نتيجة تنفيذ فعلية من NeoTask.',
      );
    }

    if (mode == 'resilient-local') {
      return const _TruthClassification(
        status: 'confirmed_local',
        label: '✅ محسوب من بيانات NeoTask المتاحة',
        note: 'النتيجة صادرة من المسار المحلي الحتمي وليست ادعاء تنفيذ.',
      );
    }

    if (mode == 'ai-gateway') {
      return _TruthClassification(
        status: 'ai_analysis',
        label: '🟡 تحليل AI — ليس دليل تنفيذ',
        note: requestId == null || requestId.isEmpty
            ? 'الرد تحليلي ويحتاج سجل NeoTask لإثبات أي تنفيذ.'
            : 'معرّف الاستجابة متاح، لكن التنفيذ لا يُثبت إلا بسجل NeoTask.',
      );
    }

    return const _TruthClassification(
      status: 'unverified',
      label: '🔴 غير متحقق',
      note: 'لم يصل تصنيف موثوق لمسار الاستجابة؛ لا تعتمد عليه كدليل تنفيذ.',
    );
  }

  static String _messageForCode(String code) {
    switch (code) {
      case 'manager-only':
        return 'هذه الميزة متاحة للمدير فقط';
      case 'rate-limit':
        return 'تم إرسال طلبات كثيرة. حاول بعد دقيقة';
      case 'agent-not-configured':
        return 'خدمة المساعد لم تكتمل تهيئتها بعد';
      case 'agent-provider-error':
        return 'تعذر الحصول على رد من محرك الذكاء الاصطناعي';
      case 'invalid-message':
        return 'الطلب فارغ أو طويل جدًا';
      case 'missing-token':
      case 'invalid-token':
        return 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى';
      default:
        return 'تعذر الاتصال بمساعد المدير الآن';
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
