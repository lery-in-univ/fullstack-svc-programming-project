import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/ide_screen.dart';
import 'services/api_client.dart';
import 'services/session_manager.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ApiClient apiClient;
  late final SessionManager sessionManager;

  @override
  void initState() {
    super.initState();
    apiClient = ApiClient();
    sessionManager = SessionManager(apiClient);
  }

  @override
  void dispose() {
    sessionManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dart Mobile IDE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: HomePage(sessionManager: sessionManager),
      routes: {
        '/ide': (context) => IdeScreen(
              sessionManager: sessionManager,
              apiClient: apiClient,
            ),
      },
    );
  }
}
