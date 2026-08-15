import 'dart:async';
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

  static Future<ManagerAiTransportResponse> get({String languageCode = 'ar'}) {
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

    final future = completer.future
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            frame.remove();
            _frameFuture = null;
            throw TimeoutException('NeoTask AI relay did not load');
          },
        )
        .then((loaded) {
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
          : <String, dynamic>{if (!ok) 'error': 'relay-error'};
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

    final id = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
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
