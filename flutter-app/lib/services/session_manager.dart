import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'session_api.dart';
import 'lsp_websocket_service.dart';
import '../config/api_config.dart';
import '../models/session_response.dart';

enum SessionState {
  notInitialized,
  initializing,
  ready,
  renewingSession,
  error,
}

class SessionManager extends ChangeNotifier {
  final SessionApi _sessionApi;
  final LspWebSocketService _lspService;

  SessionState _state = SessionState.notInitialized;
  String? _sessionId;
  String? _errorMessage;
  Timer? _renewTimer;
  WebSocketInfo? _websocketInfo;

  SessionManager(ApiClient apiClient)
      : _sessionApi = SessionApi(apiClient),
        _lspService = LspWebSocketService();

  SessionState get state => _state;
  String? get sessionId => _sessionId;
  String? get errorMessage => _errorMessage;
  bool get isReady => _state == SessionState.ready;
  WebSocketInfo? get websocketInfo => _websocketInfo;
  LspWebSocketService get lspService => _lspService;

  /// 세션 초기화
  Future<void> initializeSession() async {
    _state = SessionState.initializing;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _sessionApi.createSession();
      _sessionId = response.sessionId;
      _websocketInfo = response.websocket;
      _state = SessionState.ready;
      _errorMessage = null;

      // 자동 갱신 타이머 시작
      _startRenewTimer();

      notifyListeners();
    } catch (e) {
      _state = SessionState.error;
      _errorMessage = e.toString();
      _sessionId = null;
      notifyListeners();
    }
  }

  /// 세션 갱신 타이머 시작
  void _startRenewTimer() {
    _renewTimer?.cancel();
    _renewTimer = Timer.periodic(ApiConfig.sessionRenewInterval, (_) {
      _renewSession();
    });
  }

  /// 세션 갱신
  Future<void> _renewSession() async {
    if (_sessionId == null || _state != SessionState.ready) return;

    try {
      await _sessionApi.renewSession(_sessionId!);
      debugPrint('[SessionManager] Session renewed: $_sessionId');
    } catch (e) {
      debugPrint('[SessionManager] Failed to renew session: $e');
      // 갱신 실패 시 에러 상태로 전환
      _state = SessionState.error;
      _errorMessage = '세션 갱신 실패: ${e.toString()}';
      _renewTimer?.cancel();
      notifyListeners();
    }
  }

  /// 세션 종료
  @override
  void dispose() {
    _renewTimer?.cancel();
    _lspService.dispose();
    super.dispose();
  }
}
