import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/message_provider.dart';
import 'providers/document_provider.dart';
import 'providers/meeting_provider.dart';
import 'providers/contact_provider.dart';
import 'providers/favorite_provider.dart';
import 'providers/goal_provider.dart';
import 'providers/criterion_provider.dart';
import 'providers/poll_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/digest_provider.dart';
import 'providers/interface_style_provider.dart';
import 'screens/shared/splash_router.dart';
import 'utils/app_ready.dart';
import 'widgets/incoming_call_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  StackTrace? startupStack;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, st) {
    startupError = e;
    startupStack = st;
    if (kDebugMode) {
      debugPrint('Startup failed: $e\n$st');
    }
  }

  if (startupError != null) {
    runApp(_StartupErrorApp(error: startupError, stackTrace: startupStack));
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyAppReady());
    return;
  }

  runApp(const NeoTaskApp());
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.error, required this.stackTrace});

  final Object? error;
  final StackTrace? stackTrace;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'تعذّر تشغيل التطبيق (خطأ في التهيئة)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    error.toString(),
                    style: const TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  if (stackTrace != null) ...[
                    const SizedBox(height: 12),
                    SelectableText(
                      stackTrace.toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NeoTaskApp extends StatelessWidget {
  const NeoTaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
        ChangeNotifierProvider(create: (_) => MeetingProvider()),
        ChangeNotifierProvider(create: (_) => ContactProvider()),
        ChangeNotifierProvider(create: (_) => FavoriteProvider()),
        ChangeNotifierProvider(create: (_) => GoalProvider()),
        ChangeNotifierProvider(create: (_) => CriterionProvider()),
        ChangeNotifierProvider(create: (_) => PollProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => DigestProvider()),
        ChangeNotifierProvider(create: (_) => InterfaceStyleProvider()..load()),
      ],
      child: Consumer<InterfaceStyleProvider>(
        builder: (context, interfaceStyle, _) {
          return MaterialApp(
            title: 'NeoTask',
            debugShowCheckedModeBanner: false,
            theme: interfaceStyle.theme,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: const IncomingCallGate(child: SplashRouter()),
          );
        },
      ),
    );
  }
}
