import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import 'session_not_initialized_view.dart';
import 'session_loading_view.dart';
import 'session_error_view.dart';

class SessionStateView extends StatelessWidget {
  final SessionState state;
  final VoidCallback onInitialize;
  final String? errorMessage;
  final String? websocketErrorMessage;

  const SessionStateView({
    super.key,
    required this.state,
    required this.onInitialize,
    this.errorMessage,
    this.websocketErrorMessage,
  });

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case SessionState.notInitialized:
        return SessionNotInitializedView(onInitialize: onInitialize);

      case SessionState.initializing:
        return const SessionLoadingView(message: '세션을 생성하는 중...');

      case SessionState.connectingWebSocket:
        return const SessionLoadingView(message: 'WebSocket 연결 중...');

      case SessionState.lspInitializing:
        return const SessionLoadingView(message: 'LSP 초기화 중...');

      case SessionState.error:
        return SessionErrorView(
          errorMessage: errorMessage,
          websocketErrorMessage: websocketErrorMessage,
          onRetry: onInitialize,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
