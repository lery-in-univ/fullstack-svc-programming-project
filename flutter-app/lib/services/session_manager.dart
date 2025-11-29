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
  connectingWebSocket,
  lspInitializing,
  fullyReady,
  renewingSession,
  error,
}

class SessionManager extends ChangeNotifier {
  final SessionApi _sessionApi;
  final LspWebSocketService _lspService;

  SessionState _state = SessionState.notInitialized;
  String? _sessionId;
  String? _errorMessage;
  String? _websocketErrorMessage;
  Timer? _renewTimer;
  WebSocketInfo? _websocketInfo;

  SessionManager(ApiClient apiClient)
      : _sessionApi = SessionApi(apiClient),
        _lspService = LspWebSocketService();

  SessionState get state => _state;
  String? get sessionId => _sessionId;
  String? get errorMessage => _errorMessage;
  String? get websocketErrorMessage => _websocketErrorMessage;
  bool get isReady => _state == SessionState.ready;
  bool get isFullyReady => _state == SessionState.fullyReady;
  WebSocketInfo? get websocketInfo => _websocketInfo;
  LspWebSocketService get lspService => _lspService;

  /// 세션 초기화
  Future<void> initializeSession() async {
    _state = SessionState.initializing;
    _errorMessage = null;
    _websocketErrorMessage = null;
    notifyListeners();

    try {
      final response = await _sessionApi.createSession();
      _sessionId = response.sessionId;
      _websocketInfo = response.websocket;
      _state = SessionState.ready;
      _errorMessage = null;

      notifyListeners();

      // 자동으로 WebSocket 연결 시작
      await _connectWebSocket();
    } catch (e) {
      _state = SessionState.error;
      _errorMessage = e.toString();
      _sessionId = null;
      notifyListeners();
    }
  }

  /// WebSocket 자동 연결 (재시도 로직 포함)
  Future<void> _connectWebSocket() async {
    if (_websocketInfo == null || _sessionId == null) {
      _state = SessionState.error;
      _errorMessage = 'WebSocket info missing';
      notifyListeners();
      return;
    }

    _state = SessionState.connectingWebSocket;
    notifyListeners();

    const maxRetries = 10;
    const retryDelay = Duration(seconds: 1);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint(
            '[SessionManager] WebSocket connection attempt $attempt/$maxRetries');

        await _lspService.connect(
          url: _websocketInfo!.url,
          namespace: _websocketInfo!.namespace,
          sessionId: _sessionId!,
        );

        // WebSocket 연결 성공, LSP 초기화 시작
        await _initializeLsp();
        return; // 성공 시 함수 종료
      } catch (e) {
        final errorMessage = e.toString();
        final isContainerNotReady = errorMessage.contains('Container not ready');

        debugPrint(
            '[SessionManager] WebSocket connection attempt $attempt failed: $e');

        // "Container not ready" 에러가 아니거나 마지막 시도인 경우
        if (!isContainerNotReady || attempt == maxRetries) {
          _state = SessionState.error;
          if (attempt == maxRetries && isContainerNotReady) {
            _websocketErrorMessage =
                'LSP 컨테이너가 준비되지 않았습니다 ($maxRetries번 재시도 실패)';
          } else {
            _websocketErrorMessage = errorMessage;
          }
          debugPrint('[SessionManager] WebSocket connection failed: $e');
          notifyListeners();
          return;
        }

        // "Container not ready" 에러이고 재시도 가능한 경우 대기
        debugPrint(
            '[SessionManager] Container not ready, retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);

        // 재연결을 위해 기존 소켓 정리
        _lspService.disconnect();
      }
    }
  }

  /// LSP 자동 초기화
  Future<void> _initializeLsp() async {
    _state = SessionState.lspInitializing;
    notifyListeners();

    try {
      // LSP 초기화 요청
      final rootUri = 'file:///workspace';
      await _lspService.initializeLsp(rootUri);

      // initialized 알림 전송
      await _lspService.sendInitializedNotification();

      _state = SessionState.fullyReady;

      // 자동 갱신 타이머 시작 (LSP 초기화 완료 후)
      _startRenewTimer();

      notifyListeners();
    } catch (e) {
      _state = SessionState.error;
      _errorMessage = 'LSP initialization failed: ${e.toString()}';
      debugPrint('[SessionManager] LSP initialization failed: $e');
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
