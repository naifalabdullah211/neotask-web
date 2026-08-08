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
  });

  final String reply;
  final ManagerAiAction? action;
  final String? requestId;
}

class ManagerAiService {
  static const String _endpoint = String.fromEnvironment(
    'NEOTASK_AI_API_URL',
    defaultValue: 'https://project-0wvza.vercel.app/api/agent',
  );

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
            'agentRules': agentRules,
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
    return ManagerAiResult(
      reply: body['reply']?.toString().trim().isNotEmpty == true
          ? body['reply'].toString().trim()
          : 'تم تحليل طلبك.',
      action: rawAction is Map<String, dynamic>
          ? ManagerAiAction.fromMap(rawAction)
          : null,
      requestId: body['requestId']?.toString(),
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

class ManagerAiException implements Exception {
  const ManagerAiException(this.message);

  final String message;

  @override
  String toString() => message;
}
