import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../models/lsp_message.dart';

enum LspConnectionState {
  disconnected,
  connecting,
  connected,
  lspConnected,
  initialized,
  error,
}

class LspWebSocketService extends ChangeNotifier {
  IO.Socket? _socket;
  LspConnectionState _state = LspConnectionState.disconnected;
  String? _errorMessage;
  String? _sessionId;

  // LSP request/response handling
  int _nextId = 1;
  final Map<int, Completer<dynamic>> _pendingRequests = {};

  // Event stream for LSP messages
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  LspConnectionState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isConnected =>
      _state == LspConnectionState.connected ||
      _state == LspConnectionState.lspConnected ||
      _state == LspConnectionState.initialized;
  bool get isInitialized => _state == LspConnectionState.initialized;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  /// Connect to LSP WebSocket
  Future<void> connect({
    required String url,
    required String namespace,
    required String sessionId,
  }) async {
    if (_socket != null) {
      throw Exception('Already connected or connecting');
    }

    _state = LspConnectionState.connecting;
    _sessionId = sessionId;
    _errorMessage = null;
    notifyListeners();

    final connectCompleter = Completer<void>();
    final lspConnectCompleter = Completer<void>();

    try {
      _socket = IO.io(
        '$url$namespace',
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .enableForceNewConnection()
            .enableReconnection()
            .disableAutoConnect()
            .build(),
      );

      _setupEventHandlers(connectCompleter, lspConnectCompleter);
      _socket!.connect();

      debugPrint('[LspWebSocket] Connecting to $url$namespace');

      // Wait for WebSocket connection
      await connectCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('WebSocket connection timeout');
        },
      );

      // Send lsp-connect message
      _socket!.emit('lsp-connect', {'sessionId': sessionId});

      // Wait for lsp-connected response
      await lspConnectCompleter.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('LSP container connection timeout');
        },
      );
    } catch (e) {
      _state = LspConnectionState.error;
      _errorMessage = e.toString();
      _socket?.dispose();
      _socket = null;
      debugPrint('[LspWebSocket] Connection error: $e');
      notifyListeners();
      rethrow;
    }
  }

  void _setupEventHandlers(
    Completer<void> connectCompleter,
    Completer<void> lspConnectCompleter,
  ) {
    if (_socket == null) return;

    // WebSocket connection
    _socket!.onConnect((_) {
      debugPrint('[LspWebSocket] WebSocket connected');
      _state = LspConnectionState.connected;
      _errorMessage = null;
      notifyListeners();
      if (!connectCompleter.isCompleted) {
        connectCompleter.complete();
      }
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
      if (!connectCompleter.isCompleted) {
        connectCompleter.completeError(Exception('Connection error: $error'));
      }
    });

    _socket!.onError((error) {
      debugPrint('[LspWebSocket] Error: $error');
      _errorMessage = error.toString();
      notifyListeners();
    });

    // LSP-specific events
    _socket!.on('lsp-connected', (data) {
      debugPrint('[LspWebSocket] LSP container connected: $data');
      _state = LspConnectionState.lspConnected;
      notifyListeners();
      if (!lspConnectCompleter.isCompleted) {
        lspConnectCompleter.complete();
      }
    });

    _socket!.on('lsp-disconnected', (data) {
      debugPrint('[LspWebSocket] LSP disconnected: $data');
    });

    _socket!.on('lsp-error', (data) {
      debugPrint('[LspWebSocket] LSP error: $data');
      _errorMessage = data['error']?.toString();
      notifyListeners();
      if (!lspConnectCompleter.isCompleted) {
        lspConnectCompleter.completeError(
          Exception('LSP error: ${data['error']}'),
        );
      }
    });

    _socket!.on('lsp-message', (data) {
      final message = data['message'] as String;
      debugPrint(
          '[LspWebSocket] LSP message received (${message.length} bytes)');
      _handleLspMessage(message);
    });

    _socket!.on('pong', (data) {
      debugPrint('[LspWebSocket] Pong received: $data');
    });
  }

  /// Parse and handle LSP messages
  void _handleLspMessage(String raw) {
    final json = LspMessage.parse(raw);
    if (json == null) {
      debugPrint('[LspWebSocket] Failed to parse LSP message');
      return;
    }

    debugPrint('[LspWebSocket] Parsed message: ${json['method'] ?? 'response'}');

    // Handle responses (messages with 'id')
    if (json.containsKey('id')) {
      final id = json['id'] as int?;
      if (id != null) {
        final completer = _pendingRequests.remove(id);
        if (completer != null) {
          if (json.containsKey('error')) {
            final error = json['error'] as Map<String, dynamic>;
            completer.completeError(
              Exception('LSP error: ${error['message']} (${error['code']})'),
            );
          } else {
            completer.complete(json['result']);
          }
        }
      }
    }

    // Broadcast message to listeners
    _messageController.add(json);
  }

  /// Send LSP initialize request
  Future<Map<String, dynamic>> initializeLsp(String rootUri) async {
    if (_state != LspConnectionState.lspConnected) {
      throw Exception('LSP container not connected');
    }

    debugPrint('[LspWebSocket] Initializing LSP with rootUri: $rootUri');

    final id = _generateId();
    final request = LspMessage.createInitializeRequest(id, rootUri);

    final result = await _sendRequest<Map<String, dynamic>>(id, request);

    _state = LspConnectionState.initialized;
    notifyListeners();

    return result ?? {};
  }

  /// Send initialized notification
  Future<void> sendInitializedNotification() async {
    if (_state != LspConnectionState.initialized) {
      throw Exception('LSP not initialized');
    }

    final notification = LspMessage.createInitializedNotification();
    _sendNotification(notification);
  }

  /// Open document
  Future<void> openDocument(String uri, String content) async {
    if (_state != LspConnectionState.initialized) {
      throw Exception('LSP not initialized');
    }

    final notification = LspMessage.createDidOpenNotification(
      uri,
      'dart',
      1,
      content,
    );
    _sendNotification(notification);
    debugPrint('[LspWebSocket] Document opened: $uri');
  }

  /// Go to definition
  Future<List<dynamic>?> goToDefinition({
    required String uri,
    required int line,
    required int character,
  }) async {
    if (_state != LspConnectionState.initialized) {
      throw Exception('LSP not initialized');
    }

    debugPrint(
        '[LspWebSocket] Requesting definition at $uri:$line:$character');

    final id = _generateId();
    final request =
        LspMessage.createDefinitionRequest(id, uri, line, character);

    final result = await _sendRequest<dynamic>(id, request);

    if (result == null) {
      return null;
    }

    if (result is List) {
      return result;
    }

    return [result];
  }

  /// Helper methods
  int _generateId() => _nextId++;

  Future<T?> _sendRequest<T>(int id, Map<String, dynamic> message) {
    final completer = Completer<T?>();
    _pendingRequests[id] = completer;

    _sendLspMessage(message);

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _pendingRequests.remove(id);
        throw Exception('Request timeout');
      },
    );
  }

  void _sendNotification(Map<String, dynamic> message) {
    _sendLspMessage(message);
  }

  void _sendLspMessage(Map<String, dynamic> message) {
    if (!isConnected) {
      debugPrint('[LspWebSocket] Cannot send message - not connected');
      return;
    }

    final formatted = LspMessage.format(message);
    _socket!.emit('lsp-message', {'message': formatted});
  }

  /// Send ping test
  Future<void> sendPing(String message) async {
    if (!isConnected) {
      debugPrint('[LspWebSocket] Cannot send ping - not connected');
      return;
    }

    debugPrint('[LspWebSocket] Sending ping: $message');
    _socket!.emit('ping', {'message': message});
  }

  /// Disconnect and cleanup
  void disconnect() {
    debugPrint('[LspWebSocket] Disconnecting');
    _socket?.dispose();
    _socket = null;
    _state = LspConnectionState.disconnected;
    _sessionId = null;
    _pendingRequests.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
