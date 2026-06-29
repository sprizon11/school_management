import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/notification_poller.dart';
import 'core/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SmartSchoolApp()));
}

class SmartSchoolApp extends ConsumerWidget {
  const SmartSchoolApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'SmartUp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // Clamp system text scaling so layouts stay intact on every device
        // and accessibility font setting (prevents overflow on small phones
        // and oversized text on large-font devices).
        final clamped = mq.textScaler.clamp(
          minScaleFactor: 0.9,
          maxScaleFactor: 1.15,
        );
        return MediaQuery(
          data: mq.copyWith(textScaler: clamped),
          child: NotificationPoller(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
