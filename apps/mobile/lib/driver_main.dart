import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/session_list/session_list_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  enableFlutterDriverExtension();
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const ProviderScope(child: CcpocketApp()));
}

class CcpocketApp extends StatelessWidget {
  const CcpocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ccpocket',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SessionListScreen(),
    );
  }
}
