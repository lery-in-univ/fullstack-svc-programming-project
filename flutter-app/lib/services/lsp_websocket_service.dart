import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum LspConnectionState {
  disconnected,
  connecting,
  connected,
  error,
}

class LspWebSocketService extends ChangeNotifier {
  IO.Socket? _socket;
  LspConnectionState _state = LspConnectionState.disconnected;
  String? _errorMessage;
  String? _sessionId;

  LspConnectionState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _state == LspConnectionState.connected;

  /// Connect to LSP WebSocket
  Future<void> connect({
    required String url,
    required String namespace,
    required String sessionId,
  }) async {
    if (_socket != null) {
      debugPrint('[LspWebSocket] Already connected or connecting');
      return;
    }

    _state = LspConnectionState.connecting;
    _sessionId = sessionId;
    _errorMessage = null;
    notifyListeners();

    try {
      _socket = IO.io(
        '$url$namespace',
        IO.OptionBuilder()
            .setTransports(['websocket']) // Force WebSocket only (no polling)
            .enableForceNewConnection()
            .enableReconnection()
            .disableAutoConnect()
            .build(),
      );

      _setupEventHandlers();
      _socket!.connect();

      debugPrint('[LspWebSocket] Connecting to $url$namespace');
    } catch (e) {
      _state = LspConnectionState.error;
      _errorMessage = e.toString();
      debugPrint('[LspWebSocket] Connection error: $e');
      notifyListeners();
    }
  }

  void _setupEventHandlers() {
    if (_socket == null) return;

    // Connection lifecycle events
    _socket!.onConnect((_) {
      debugPrint('[LspWebSocket] Connected');
      _state = LspConnectionState.connected;
      _errorMessage = null;
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      debugPrint('[LspWebSocket] Disconnected');
      _state = LspConnectionState.disconnected;
      notifyListeners();
    });

    _socket!.onConnectError((error) {
      debugPrint('[LspWebSocket] Connection error: $error');
      _state = LspConnectionState.error;
      _errorMessage = error.toString();
      notifyListeners();
    });

    _socket!.onError((error) {
      debugPrint('[LspWebSocket] Error: $error');
      _errorMessage = error.toString();
      notifyListeners();
    });

    // LSP-specific events
    _socket!.on('lsp-connected', (data) {
      debugPrint('[LspWebSocket] LSP connected: $data');
    });

    _socket!.on('lsp-disconnected', (data) {
      debugPrint('[LspWebSocket] LSP disconnected: $data');
    });

    _socket!.on('lsp-error', (data) {
      debugPrint('[LspWebSocket] LSP error: $data');
      _errorMessage = data['error']?.toString();
      notifyListeners();
    });

    _socket!.on('lsp-message', (data) {
      debugPrint('[LspWebSocket] LSP message received: $data');
      // TODO: Handle LSP messages (will implement in later phase)
    });

    // Ping-pong test event
    _socket!.on('pong', (data) {
      debugPrint('[LspWebSocket] Pong received: $data');
    });
  }

  /// Send ping test
  Future<void> sendPing(String message) async {
    if (!isConnected) {
      debugPrint('[LspWebSocket] Cannot send ping - not connected');
      return;
    }

    debugPrint('[LspWebSocket] Sending ping: $message');
    debugPrint('[LspWebSocket] Socket connected: ${_socket?.connected}');
    debugPrint('[LspWebSocket] Socket id: ${_socket?.id}');

    // Try different payload formats
    _socket!.emit('ping', {'message': message});
    debugPrint('[LspWebSocket] Ping emitted with object payload');

    // Also try with just the string
    await Future.delayed(const Duration(milliseconds: 100));
    _socket!.emit('ping', message);
    debugPrint('[LspWebSocket] Ping emitted with string payload');
  }

  /// Initialize LSP connection (after WebSocket connected)
  Future<void> initializeLsp() async {
    if (!isConnected || _sessionId == null) {
      debugPrint('[LspWebSocket] Cannot initialize LSP - not ready');
      return;
    }

    debugPrint('[LspWebSocket] Initializing LSP for session $_sessionId');
    _socket!.emit('lsp-connect', {'sessionId': _sessionId});
  }

  /// Send LSP message
  Future<void> sendLspMessage(String message) async {
    if (!isConnected) {
      debugPrint('[LspWebSocket] Cannot send LSP message - not connected');
      return;
    }

    debugPrint('[LspWebSocket] Sending LSP message: $message');
    _socket!.emit('lsp-message', {'message': message});
  }

  /// Disconnect and cleanup
  void disconnect() {
    debugPrint('[LspWebSocket] Disconnecting');
    _socket?.dispose();
    _socket = null;
    _state = LspConnectionState.disconnected;
    _sessionId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
