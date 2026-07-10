import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/message_provider.dart';
import 'theme/app_theme.dart';
import 'screens/shared/splash_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? startupError;
  StackTrace? startupStack;

  try {
    // Firebase MUST be initialized before FirestoreService.init() since the
    // latter opens live snapshot listeners against Cloud Firestore.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // If Firebase.initializeApp() above failed to actually register a
    // default app (e.g. threw internally but was mis-caught, or on a
    // platform where FirebaseOptions are still placeholders), calling
    // FirestoreService.initPublic() will otherwise throw an UNCAUGHT
    // FirebaseException deep inside FirebaseFirestore.instance, which
    // previously escaped main() entirely and silently prevented runApp()
    // from ever being called (blank white screen with no visible error).
    // A timeout is also added as defense-in-depth in case Firestore's
    // snapshot listeners never resolve on a restricted network.
    //
    // NOTE: only the PUBLIC listeners (system/manager_lock + invitations)
    // are started here — the rest (users/tasks/messages/...) require an
    // authenticated session under the security rules and are started by
    // AuthProvider once sign-in succeeds (see restoreSession/login/
    // registerViaInvite/ensureManagerExists in auth_provider.dart).
    await FirestoreService.initPublic().timeout(const Duration(seconds: 20));
  } catch (e, st) {
    startupError = e;
    startupStack = st;
    if (kDebugMode) {
      debugPrint('Startup failed: $e\n$st');
    }
  }

  if (startupError != null) {
    runApp(_StartupErrorApp(error: startupError, stackTrace: startupStack));
    return;
  }

  runApp(const NeoTaskApp());
}

/// Shown instead of a silent blank screen if Firebase/Firestore
/// initialization fails or hangs. This makes startup failures diagnosable
/// directly from the deployed app instead of requiring server-side log
/// reproduction.
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
      ],
      child: MaterialApp(
        title: 'NeoTask',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
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
        home: const SplashRouter(),
      ),
    );
  }
}
