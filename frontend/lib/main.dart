/// ProfessorOS – Main Entry Point.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart'; // Web URL formatting without #
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy(); // For cleaner web URLs (e.g. /auth/login instead of /#/auth/login)
  
  runApp(
    const ProviderScope(
      child: ProfessorOSApp(),
    ),
  );
}
