import 'api_client.dart';
import '../models/session_response.dart';

class SessionApi {
  final ApiClient apiClient;

  SessionApi(this.apiClient);

  /// POST / - 세션 생성
  Future<SessionResponse> createSession() async {
    final response = await apiClient.post('/');
    return SessionResponse.fromJson(response.data);
  }

  /// POST /sessions/{sessionId}/renew - 세션 갱신
  Future<void> renewSession(String sessionId) async {
    await apiClient.post('/sessions/$sessionId/renew');
  }
}
