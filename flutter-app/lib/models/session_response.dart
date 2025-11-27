class SessionResponse {
  final String sessionId;

  SessionResponse({required this.sessionId});

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(sessionId: json['sessionId'] as String);
  }
}
