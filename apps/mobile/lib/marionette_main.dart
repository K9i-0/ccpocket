import 'package:flutter/material.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'screens/session_list_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  MarionetteBinding.ensureInitialized();
  await NotificationService.instance.init();
  runApp(const CcpocketApp());
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
