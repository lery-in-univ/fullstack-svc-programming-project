import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/api_client.dart';
import '../services/execution_api.dart';
import '../services/session_api.dart';
import '../models/key_event.dart';
import '../widgets/keyboard/qwerty_keyboard.dart';
import '../widgets/text_input_area.dart';

enum ExecutionStatus {
  idle,
  submitting,
  polling,
  completed,
  error,
}

class IdeScreen extends StatefulWidget {
  final SessionManager sessionManager;
  final ApiClient apiClient;

  const IdeScreen({
    super.key,
    required this.sessionManager,
    required this.apiClient,
  });

  @override
  State<IdeScreen> createState() => _IdeScreenState();
}

class _IdeScreenState extends State<IdeScreen> {
  late final ExecutionApi _executionApi;
  late final SessionApi _sessionApi;
  final GlobalKey<TextInputAreaState> _textInputKey = GlobalKey();

  // UI 상태
  int _currentTabIndex = 0;

  // 코드 에디터 상태
  bool _needsSave = false;
  bool _isSaving = false;

  // 실행 상태
  ExecutionStatus _executionStatus = ExecutionStatus.idle;
  String? _output;
  String? _error;
  int? _exitCode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _executionApi = ExecutionApi(widget.apiClient);
    _sessionApi = SessionApi(widget.apiClient);
  }

  bool get _canSave => _needsSave && !_isSaving;

  bool get _canExecute =>
      !_needsSave &&
      (_executionStatus == ExecutionStatus.idle ||
          _executionStatus == ExecutionStatus.completed ||
          _executionStatus == ExecutionStatus.error);

  Future<void> _saveCode() async {
    if (!_canSave) return;

    final textInputState = _textInputKey.currentState;
    if (textInputState == null) return;

    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _sessionApi.updateFile(sessionId, textInputState.text);
      setState(() {
        _needsSave = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('코드가 저장되었습니다'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('저장 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _executeCode() async {
    if (!_canExecute) return;

    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) return;

    setState(() {
      _executionStatus = ExecutionStatus.submitting;
      _output = null;
      _error = null;
      _exitCode = null;
      _errorMessage = null;
    });

    try {
      // 1. 실행 제출
      final jobCreated = await _executionApi.submitCode(sessionId);
      setState(() {
        _executionStatus = ExecutionStatus.polling;
      });

      // 2. 완료될 때까지 폴링
      final completedJob = await _executionApi.pollUntilComplete(
        jobCreated.id,
        onStatusUpdate: (_) {},
      );

      // 3. 완료 결과 표시 및 탭 전환
      setState(() {
        _executionStatus = ExecutionStatus.completed;
        _output = completedJob.output;
        _error = completedJob.error;
        _exitCode = completedJob.exitCode;
        _currentTabIndex = 1; // 결과 탭으로 전환
      });
    } catch (e) {
      setState(() {
        _executionStatus = ExecutionStatus.error;
        _errorMessage = e.toString();
      });
    }
  }

  void _handleKeyPress(KeyboardEvent event) {
    final textInputState = _textInputKey.currentState;
    if (textInputState == null) return;

    switch (event.type) {
      case KeyType.normal:
      case KeyType.space:
        textInputState.addCharacter(event.character);
        setState(() {
          _needsSave = true;
        });
        break;
      case KeyType.backspace:
        textInputState.deleteLastCharacter();
        setState(() {
          _needsSave = true;
        });
        break;
      case KeyType.shift:
        // Shift는 키보드 내부에서 처리
        break;
    }
  }

  String _getExecuteButtonText() {
    switch (_executionStatus) {
      case ExecutionStatus.idle:
        return '실행';
      case ExecutionStatus.submitting:
        return '제출 중...';
      case ExecutionStatus.polling:
        return '실행 중...';
      case ExecutionStatus.completed:
        return '다시 실행';
      case ExecutionStatus.error:
        return '재시도';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dart IDE'),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildEditorTab(),
          _buildResultsTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.code),
            label: 'Editor',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.output),
            label: 'Results',
          ),
        ],
      ),
    );
  }

  Widget _buildEditorTab() {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // TextInputArea
              TextInputArea(
                key: _textInputKey,
                onTextChanged: (_) {
                  setState(() {
                    _needsSave = true;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 저장/실행 버튼
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canSave ? _saveCode : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? '저장 중...' : '저장'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canExecute ? _executeCode : null,
                      icon: _executionStatus == ExecutionStatus.submitting ||
                              _executionStatus == ExecutionStatus.polling
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(_getExecuteButtonText()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 상태 안내
              if (_needsSave)
                Card(
                  color: Colors.orange.shade50,
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child:
                              Text('변경사항이 있습니다. 실행하려면 먼저 저장하세요.'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // QwertyKeyboard
              QwertyKeyboard(
                onKeyPressed: _handleKeyPress,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 출력
            _buildResultCard(
              '출력',
              _output ?? '(없음)',
              Icons.terminal,
              Colors.green,
            ),
            const SizedBox(height: 16),

            // 에러
            _buildResultCard(
              '에러',
              _error ?? '(없음)',
              Icons.error_outline,
              Colors.red,
            ),
            const SizedBox(height: 16),

            // Exit Code
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.exit_to_app),
                        const SizedBox(width: 8),
                        Text(
                          'Exit Code',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _exitCode?.toString() ?? '-',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 에러 메시지
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.error, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            '오류',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_errorMessage!),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(
    String title,
    String content,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
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
