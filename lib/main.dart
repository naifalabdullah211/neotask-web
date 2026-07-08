import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/local_db_service.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/calendar_provider.dart';
import 'theme/app_theme.dart';
import 'screens/shared/splash_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDbService.init();
  runApp(const NeoTaskApp());
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
      ],
      child: MaterialApp(
        title: 'NeoTask',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
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
