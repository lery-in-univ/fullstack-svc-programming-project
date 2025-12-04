import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../widgets/app_intro_header.dart';
import '../widgets/session/session_state_view.dart';

class HomePage extends StatefulWidget {
  final SessionManager sessionManager;

  const HomePage({super.key, required this.sessionManager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    widget.sessionManager.addListener(_onSessionStateChanged);
  }

  @override
  void dispose() {
    widget.sessionManager.removeListener(_onSessionStateChanged);
    super.dispose();
  }

  void _onSessionStateChanged() {
    if (widget.sessionManager.isFullyReady) {
      // LSP 초기화 완료 → IDE 화면으로 자동 이동
      Navigator.pushReplacementNamed(context, '/ide');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart Mobile IDE'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AppIntroHeader(),
              SessionStateView(
                state: widget.sessionManager.state,
                onInitialize: widget.sessionManager.initializeSession,
                errorMessage: widget.sessionManager.errorMessage,
                websocketErrorMessage: widget.sessionManager.websocketErrorMessage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
