import 'api_client.dart';
import '../models/execution_job_created.dart';
import '../models/execution_job.dart';
import '../config/api_config.dart';

class ExecutionApi {
  final ApiClient apiClient;

  ExecutionApi(this.apiClient);

  /// POST /execution-jobs - 코드 실행 제출
  Future<ExecutionJobCreated> submitCode(String sessionId) async {
    final response = await apiClient.post(
      '/execution-jobs',
      data: {'sessionId': sessionId},
    );
    return ExecutionJobCreated.fromJson(response.data);
  }

  /// GET /execution-jobs/:jobId - 실행 상태 확인
  Future<ExecutionJob> getJobStatus(String jobId) async {
    final response = await apiClient.get('/execution-jobs/$jobId');
    return ExecutionJob.fromJson(response.data);
  }

  /// 완료될 때까지 폴링
  Future<ExecutionJob> pollUntilComplete(
    String jobId, {
    void Function(ExecutionJob)? onStatusUpdate,
  }) async {
    for (int i = 0; i < ApiConfig.maxPollingAttempts; i++) {
      final job = await getJobStatus(jobId);
      onStatusUpdate?.call(job);

      if (job.isTerminal) return job;

      await Future.delayed(ApiConfig.pollingInterval);
    }

    throw Exception('실행 시간 초과');
  }
}
