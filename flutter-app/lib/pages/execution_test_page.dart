import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/api_client.dart';
import '../services/execution_api.dart';

enum ExecutionStatus {
  idle,
  submitting,
  polling,
  completed,
  error,
}

class ExecutionTestPage extends StatefulWidget {
  final SessionManager sessionManager;
  final ApiClient apiClient;

  const ExecutionTestPage({
    super.key,
    required this.sessionManager,
    required this.apiClient,
  });

  @override
  State<ExecutionTestPage> createState() => _ExecutionTestPageState();
}

class _ExecutionTestPageState extends State<ExecutionTestPage> {
  late final ExecutionApi _executionApi;

  ExecutionStatus _status = ExecutionStatus.idle;
  String? _jobId;
  String? _currentStatus;
  String? _output;
  String? _error;
  int? _exitCode;
  String? _errorMessage;
  List<String> _statusHistory = [];

  @override
  void initState() {
    super.initState();
    _executionApi = ExecutionApi(widget.apiClient);
  }

  Future<void> _executeCode() async {
    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) {
      setState(() {
        _status = ExecutionStatus.error;
        _errorMessage = '세션이 초기화되지 않았습니다.';
      });
      return;
    }

    setState(() {
      _status = ExecutionStatus.submitting;
      _jobId = null;
      _currentStatus = null;
      _output = null;
      _error = null;
      _exitCode = null;
      _errorMessage = null;
      _statusHistory = [];
    });

    try {
      // 1. 실행 제출
      final jobCreated = await _executionApi.submitCode(sessionId);
      setState(() {
        _status = ExecutionStatus.polling;
        _jobId = jobCreated.id;
        _currentStatus = jobCreated.status;
        _statusHistory = [jobCreated.status];
      });

      // 2. 완료될 때까지 폴링
      final completedJob = await _executionApi.pollUntilComplete(
        jobCreated.id,
        onStatusUpdate: (job) {
          setState(() {
            _currentStatus = job.status;
            if (_statusHistory.isEmpty || _statusHistory.last != job.status) {
              _statusHistory.add(job.status);
            }
          });
        },
      );

      // 3. 완료 결과 표시
      setState(() {
        _status = ExecutionStatus.completed;
        _currentStatus = completedJob.status;
        _output = completedJob.output;
        _error = completedJob.error;
        _exitCode = completedJob.exitCode;
      });
    } catch (e) {
      setState(() {
        _status = ExecutionStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('코드 실행 테스트'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 세션 정보 카드
              _buildSessionInfoCard(),
              const SizedBox(height: 16),

              // 안내 카드
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '테스트 안내',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '버튼을 클릭하면 기본 "Hello, Dart!" 코드가 실행됩니다.\n'
                        '현재 세션으로 코드 실행 및 결과 조회를 테스트합니다.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 실행 버튼
              ElevatedButton.icon(
                onPressed: _canExecute ? _executeCode : null,
                icon: _status == ExecutionStatus.submitting ||
                        _status == ExecutionStatus.polling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(_getButtonText()),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16.0),
                ),
              ),
              const SizedBox(height: 24),

              // 실행 상태
              if (_status != ExecutionStatus.idle) ...[
                _buildStatusCard(),
                const SizedBox(height: 16),
              ],

              // Job ID
              if (_jobId != null) ...[
                _buildInfoCard('Job ID', _jobId!),
                const SizedBox(height: 16),
              ],

              // 상태 히스토리
              if (_statusHistory.isNotEmpty) ...[
                _buildStatusHistoryCard(),
                const SizedBox(height: 16),
              ],

              // 출력
              if (_output != null) ...[
                _buildOutputCard('출력', _output!, Colors.green),
                const SizedBox(height: 16),
              ],

              // 에러
              if (_error != null) ...[
                _buildOutputCard('에러', _error!, Colors.red),
                const SizedBox(height: 16),
              ],

              // Exit Code
              if (_exitCode != null) ...[
                _buildInfoCard('Exit Code', _exitCode.toString()),
                const SizedBox(height: 16),
              ],

              // 에러 메시지
              if (_errorMessage != null) ...[
                _buildOutputCard('오류', _errorMessage!, Colors.red),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool get _canExecute =>
      _status == ExecutionStatus.idle ||
      _status == ExecutionStatus.completed ||
      _status == ExecutionStatus.error;

  String _getButtonText() {
    switch (_status) {
      case ExecutionStatus.idle:
        return '코드 실행';
      case ExecutionStatus.submitting:
        return '실행 제출 중...';
      case ExecutionStatus.polling:
        return '실행 중 ($_currentStatus)...';
      case ExecutionStatus.completed:
        return '다시 실행';
      case ExecutionStatus.error:
        return '재시도';
    }
  }

  Widget _buildSessionInfoCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  '세션 활성화',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              'Session ID: ${widget.sessionManager.sessionId}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    IconData statusIcon;

    if (_status == ExecutionStatus.submitting ||
        _status == ExecutionStatus.polling) {
      statusColor = Colors.blue;
      statusIcon = Icons.sync;
    } else if (_status == ExecutionStatus.completed) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    }

    return Card(
      color: statusColor.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('상태'),
                  Text(
                    _currentStatus ?? _status.toString().split('.').last,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            SelectableText(
              value,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHistoryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('상태 히스토리',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            ...List.generate(_statusHistory.length, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Text('${index + 1}.'),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_statusHistory[index])),
                    if (index == _statusHistory.length - 1)
                      const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildOutputCard(String label, String content, Color color) {
    return Card(
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  label == '출력' ? Icons.terminal : Icons.error_outline,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Colors.white,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
