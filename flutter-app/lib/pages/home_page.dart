import 'package:flutter/material.dart';
import '../services/session_manager.dart';

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
    if (widget.sessionManager.isReady) {
      // 세션 준비 완료 → ExecutionTestPage로 자동 이동
      Navigator.pushReplacementNamed(context, '/execution-test');
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.sessionManager.state;

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
              // 앱 아이콘
              Icon(
                Icons.code,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),

              // 앱 제목
              Text(
                'Dart Mobile IDE',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A mobile development environment for Dart',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // 세션 상태에 따른 UI
              if (state == SessionState.notInitialized) ...[
                ElevatedButton.icon(
                  onPressed: () => widget.sessionManager.initializeSession(),
                  icon: const Icon(Icons.power_settings_new),
                  label: const Text('세션 초기화'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                  ),
                ),
              ] else if (state == SessionState.initializing) ...[
                const Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('세션을 생성하는 중...'),
                    ],
                  ),
                ),
              ] else if (state == SessionState.error) ...[
                Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error, color: Colors.red, size: 48),
                        const SizedBox(height: 8),
                        Text(
                          '오류 발생',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.sessionManager.errorMessage ?? '알 수 없는 오류',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => widget.sessionManager.initializeSession(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('재시도'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16.0),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // 키보드 데모 바로가기 (세션 없이도 접근 가능)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/keyboard-demo');
                },
                icon: const Icon(Icons.keyboard),
                label: const Text('키보드 데모'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
