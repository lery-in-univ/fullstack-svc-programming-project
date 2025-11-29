class WebSocketInfo {
  final String url;
  final String namespace;
  final String path;

  WebSocketInfo({
    required this.url,
    required this.namespace,
    required this.path,
  });

  factory WebSocketInfo.fromJson(Map<String, dynamic> json) {
    return WebSocketInfo(
      url: json['url'] as String,
      namespace: json['namespace'] as String,
      path: json['path'] as String,
    );
  }
}

class SessionResponse {
  final String sessionId;
  final WebSocketInfo? websocket;

  SessionResponse({
    required this.sessionId,
    this.websocket,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      sessionId: json['sessionId'] as String,
      websocket: json['websocket'] != null
          ? WebSocketInfo.fromJson(json['websocket'] as Map<String, dynamic>)
          : null,
    );
  }
}
