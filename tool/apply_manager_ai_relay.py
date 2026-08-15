from pathlib import Path


def replace_once(path_str: str, old: str, new: str, label: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding='utf-8')
    if old not in text:
        if new in text:
            return
        raise SystemExit(f'missing relay target: {label}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def replace_between(path_str: str, start: str, end: str, replacement: str, label: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding='utf-8')
    start_i = text.find(start)
    if start_i < 0:
        if replacement.strip() in text:
            return
        raise SystemExit(f'missing relay start: {label}')
    end_i = text.find(end, start_i)
    if end_i < 0:
        raise SystemExit(f'missing relay end: {label}')
    path.write_text(text[:start_i] + replacement + text[end_i:], encoding='utf-8')


Path('lib/services/manager_ai_transport.dart').write_text("""export 'manager_ai_transport_stub.dart'\n    if (dart.library.html) 'manager_ai_transport_web.dart';\n""", encoding='utf-8')

Path('lib/services/manager_ai_transport_stub.dart').write_text(r"""import 'dart:convert';

import 'package:http/http.dart' as http;

class ManagerAiTransportResponse {
  const ManagerAiTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, dynamic> body;
}

class ManagerAiTransport {
  static const String _endpoint = String.fromEnvironment(
    'NEOTASK_AI_API_URL',
    defaultValue: 'https://project-0wvza.vercel.app/api/multi-agent',
  );

  static Future<ManagerAiTransportResponse> get({
    String languageCode = 'ar',
  }) async {
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: languageCode == 'en' ? const {'lang': 'en'} : null,
    );
    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 12));
    return ManagerAiTransportResponse(
      statusCode: response.statusCode,
      body: _decode(response.body),
    );
  }

  static Future<ManagerAiTransportResponse> post({
    required String firebaseToken,
    required Map<String, dynamic> body,
  }) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $firebaseToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 75));
    return ManagerAiTransportResponse(
      statusCode: response.statusCode,
      body: _decode(response.body),
    );
  }

  static Map<String, dynamic> _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } catch (_) {
      return const {};
    }
  }
}
""", encoding='utf-8')

Path('lib/services/manager_ai_transport_web.dart').write_text(r"""import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class ManagerAiTransportResponse {
  const ManagerAiTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, dynamic> body;
}

class ManagerAiTransport {
  static const String _relayOrigin =
      'https://neotask-agent-bridge-xo992u.v2.appdeploy.ai';
  static const String _relayUrl = '$_relayOrigin/?relay=1';

  static html.IFrameElement? _frame;
  static Future<html.IFrameElement>? _frameFuture;
  static StreamSubscription<html.MessageEvent>? _messageSubscription;
  static final Map<String, Completer<ManagerAiTransportResponse>> _pending = {};
  static int _counter = 0;

  static Future<ManagerAiTransportResponse> get({
    String languageCode = 'ar',
  }) {
    return _send(
      method: 'GET',
      languageCode: languageCode,
      timeout: const Duration(seconds: 15),
    );
  }

  static Future<ManagerAiTransportResponse> post({
    required String firebaseToken,
    required Map<String, dynamic> body,
  }) {
    return _send(
      method: 'POST',
      firebaseToken: firebaseToken,
      body: body,
      timeout: const Duration(seconds: 90),
    );
  }

  static Future<html.IFrameElement> _ensureFrame() {
    final existing = _frame;
    if (existing != null) return Future.value(existing);
    final loading = _frameFuture;
    if (loading != null) return loading;

    _listenForResponses();
    final completer = Completer<html.IFrameElement>();
    final frame = html.IFrameElement()
      ..src = _relayUrl
      ..title = 'NeoTask AI Relay'
      ..setAttribute('aria-hidden', 'true')
      ..style.position = 'fixed'
      ..style.width = '1px'
      ..style.height = '1px'
      ..style.left = '-10000px'
      ..style.top = '-10000px'
      ..style.opacity = '0'
      ..style.border = '0'
      ..style.pointerEvents = 'none';

    late StreamSubscription<html.Event> loadSubscription;
    loadSubscription = frame.onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete(frame);
      loadSubscription.cancel();
    });
    html.document.body?.append(frame);

    final future = completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        frame.remove();
        _frameFuture = null;
        throw TimeoutException('NeoTask AI relay did not load');
      },
    ).then((loaded) {
      _frame = loaded;
      _frameFuture = null;
      return loaded;
    });
    _frameFuture = future;
    return future;
  }

  static void _listenForResponses() {
    if (_messageSubscription != null) return;
    _messageSubscription = html.window.onMessage.listen((event) {
      if (event.origin != _relayOrigin || event.data is! String) return;
      Map<String, dynamic> message;
      try {
        final decoded = jsonDecode(event.data as String);
        if (decoded is! Map) return;
        message = Map<String, dynamic>.from(decoded);
      } catch (_) {
        return;
      }
      if (message['channel'] != 'neotask-ai-response') return;
      final id = message['id']?.toString() ?? '';
      final completer = _pending.remove(id);
      if (completer == null || completer.isCompleted) return;
      final ok = message['ok'] == true;
      final rawData = message['data'];
      final body = rawData is Map
          ? Map<String, dynamic>.from(rawData)
          : <String, dynamic>{
              if (!ok) 'error': 'relay-error',
            };
      completer.complete(
        ManagerAiTransportResponse(
          statusCode: ok ? 200 : (message['status'] as num?)?.toInt() ?? 503,
          body: body,
        ),
      );
    });
  }

  static Future<ManagerAiTransportResponse> _send({
    required String method,
    String languageCode = 'ar',
    String? firebaseToken,
    Map<String, dynamic>? body,
    required Duration timeout,
  }) async {
    final frame = await _ensureFrame();
    final contentWindow = frame.contentWindow;
    if (contentWindow == null) {
      _frame = null;
      throw StateError('NeoTask AI relay window unavailable');
    }

    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
    final completer = Completer<ManagerAiTransportResponse>();
    _pending[id] = completer;
    final message = <String, dynamic>{
      'channel': 'neotask-ai-request',
      'id': id,
      'method': method,
      'languageCode': languageCode == 'en' ? 'en' : 'ar',
      if (body != null) 'body': body,
      if (firebaseToken != null) 'firebaseToken': firebaseToken,
    };
    contentWindow.postMessage(jsonEncode(message), _relayOrigin);

    try {
      return await completer.future.timeout(timeout);
    } finally {
      _pending.remove(id);
    }
  }
}
""", encoding='utf-8')

service = 'lib/services/manager_ai_service.dart'
replace_once(
    service,
    "import 'dart:convert';\n\nimport 'package:firebase_auth/firebase_auth.dart';\nimport 'package:http/http.dart' as http;\n\nimport '../models/task_model.dart';\nimport 'firestore_service.dart';\n",
    "import 'dart:async';\n\nimport 'package:firebase_auth/firebase_auth.dart';\n\nimport '../models/task_model.dart';\nimport 'firestore_service.dart';\nimport 'manager_ai_transport.dart';\n",
    'manager ai imports',
)
replace_once(
    service,
    """  static const String _endpoint = String.fromEnvironment(
    'NEOTASK_AI_API_URL',
    defaultValue: 'https://project-0wvza.vercel.app/api/multi-agent',
  );

""",
    '',
    'remove direct endpoint',
)
replace_between(
    service,
    '  static Future<bool> isAvailable() async {',
    '\n  static Future<ManagerAiResult> send({',
    r'''  static Future<bool> isAvailable({String languageCode = 'ar'}) async {
    try {
      final response = await ManagerAiTransport.get(
        languageCode: languageCode,
      );
      return response.statusCode == 200 && response.body['status'] == 'ready';
    } catch (_) {
      return false;
    }
  }
''',
    'relay availability',
)
replace_between(
    service,
    '    final response = await http\n',
    '\n    if (response.statusCode != 200) {',
    r'''    ManagerAiTransportResponse response;
    try {
      response = await ManagerAiTransport.post(
        firebaseToken: token,
        body: {
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
        },
      );
    } on TimeoutException {
      throw ManagerAiException(
        languageCode == 'en'
            ? 'The AI relay timed out. NeoTask will retry automatically.'
            : 'انتهت مهلة اتصال الوكيل. سيعيد NeoTask المحاولة تلقائيًا.',
        connectionFailure: true,
      );
    } catch (_) {
      throw ManagerAiException(
        languageCode == 'en'
            ? 'NeoTask could not reach the AI relay right now.'
            : 'تعذر وصول NeoTask إلى قناة الوكيل الآن.',
        connectionFailure: true,
      );
    }

    final body = response.body;
''',
    'relay post',
)
replace_once(
    service,
    "      throw ManagerAiException(_messageForCode(code, languageCode));",
    """      throw ManagerAiException(
        _messageForCode(code, languageCode),
        connectionFailure: response.statusCode == 0 || response.statusCode >= 500,
      );""",
    'error connectivity classification',
)
replace_once(
    service,
    """class ManagerAiException implements Exception {
  const ManagerAiException(this.message);

  final String message;
""",
    """class ManagerAiException implements Exception {
  const ManagerAiException(
    this.message, {
    this.connectionFailure = false,
  });

  final String message;
  final bool connectionFailure;
""",
    'manager ai exception connection flag',
)

screen = 'lib/screens/manager/manager_ideas_screen.dart'
replace_once(
    screen,
    "import 'package:flutter/material.dart' hide Text;\n",
    "import 'dart:async';\n\nimport 'package:flutter/material.dart' hide Text;\n",
    'screen async import',
)
replace_once(
    screen,
    "  bool? _agentOnline;\n  _HistoryFilter _historyFilter = _HistoryFilter.all;",
    "  bool? _agentOnline;\n  Timer? _statusRetryTimer;\n  _HistoryFilter _historyFilter = _HistoryFilter.all;",
    'screen retry timer field',
)
replace_between(
    screen,
    '  Future<void> _checkAgentStatus() async {',
    '\n  @override\n  void dispose() {',
    r'''  Future<void> _checkAgentStatus() async {
    final languageCode = context.read<LocaleProvider>().languageCode;
    final online = await ManagerAiService.isAvailable(
      languageCode: languageCode,
    );
    if (!mounted) return;
    setState(() => _agentOnline = online);
    if (online) {
      _statusRetryTimer?.cancel();
      _statusRetryTimer = null;
    } else {
      _scheduleStatusRetry();
    }
  }

  void _scheduleStatusRetry() {
    _statusRetryTimer?.cancel();
    _statusRetryTimer = Timer(
      const Duration(seconds: 8),
      _checkAgentStatus,
    );
  }
''',
    'screen status retry',
)
replace_once(
    screen,
    """  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
""",
    """  void dispose() {
    _statusRetryTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
""",
    'screen dispose retry timer',
)
replace_once(
    screen,
    """    } on ManagerAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _agentOnline = false;
        _messages.add(_ChatMessage.error(error.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _agentOnline = false;
        _messages.add(
          _ChatMessage.error('تعذر الاتصال بالمساعد. حاول مرة أخرى.'),
        );
      });
""",
    """    } on ManagerAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _agentOnline = error.connectionFailure ? false : true;
        _messages.add(_ChatMessage.error(error.message));
      });
      if (error.connectionFailure) _scheduleStatusRetry();
    } catch (_) {
      if (!mounted) return;
      final english = context.read<LocaleProvider>().languageCode == 'en';
      setState(() {
        _agentOnline = null;
        _messages.add(
          _ChatMessage.error(
            english
                ? 'An unexpected assistant error occurred. NeoTask will recheck automatically.'
                : 'حدث خطأ غير متوقع في المساعد. سيعيد NeoTask الفحص تلقائيًا.',
          ),
        );
      });
      _scheduleStatusRetry();
""",
    'screen truthful failure state',
)

print('NeoTask manager AI iframe relay migration applied')
