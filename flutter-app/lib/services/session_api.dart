import 'dart:convert';
import 'api_client.dart';
import '../models/session_response.dart';

class SessionApi {
  final ApiClient apiClient;

  SessionApi(this.apiClient);

  /// POST /sessions - 세션 생성
  Future<SessionResponse> createSession() async {
    final response = await apiClient.post('/sessions');
    return SessionResponse.fromJson(response.data);
  }

  /// POST /sessions/{sessionId}/renew - 세션 갱신
  Future<void> renewSession(String sessionId) async {
    await apiClient.post('/sessions/$sessionId/renew');
  }

  /// PUT /sessions/:sessionId/files - 파일 업데이트
  Future<Map<String, dynamic>> updateFile(
    String sessionId,
    String code,
  ) async {
    final base64Content = base64Encode(utf8.encode(code));
    final response = await apiClient.put(
      '/sessions/$sessionId/files',
      data: {'content': base64Content},
    );
    return response.data;
  }
}
