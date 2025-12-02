import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/api_client.dart';
import '../services/execution_api.dart';
import '../services/session_api.dart';
import '../models/key_event.dart';
import '../widgets/keyboard/qwerty_keyboard.dart';
import '../widgets/code_editor.dart';

enum ExecutionStatus { idle, submitting, polling, completed, error }

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
  final GlobalKey<CodeEditorState> _codeEditorKey = GlobalKey();

  // UI 상태
  int _currentTabIndex = 0;

  // 코드 에디터 상태
  bool _needsSave = false;
  bool _isSaving = false;

  // 커서 위치 추적
  int _cursorLine = 0;
  int _cursorCharacter = 0;

  // LSP 문서 URI
  String get _documentUri => 'file:///workspace/main.dart';

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

    // WebSocket 상태 변화 리스너 추가
    widget.sessionManager.lspService.addListener(_onLspServiceChanged);

    // LSP 문서 열기
    _openDocumentInLsp();
  }

  @override
  void dispose() {
    widget.sessionManager.lspService.removeListener(_onLspServiceChanged);
    super.dispose();
  }

  void _onLspServiceChanged() {
    if (mounted) {
      setState(() {});

      // LSP 초기화 완료 시 문서 열기
      if (widget.sessionManager.lspService.isInitialized) {
        _openDocumentInLsp();
      }
    }
  }

  // LSP 문서 열기
  Future<void> _openDocumentInLsp() async {
    if (!widget.sessionManager.lspService.isInitialized) {
      return;
    }

    final codeEditorState = _codeEditorKey.currentState;
    if (codeEditorState == null) return;

    try {
      await widget.sessionManager.lspService.openDocument(
        _documentUri,
        codeEditorState.text,
      );
      debugPrint('[IDE] Document opened in LSP');
    } catch (e) {
      debugPrint('[IDE] Failed to open document in LSP: $e');
    }
  }

  // 커서 위치 변경 핸들러
  void _onCursorPositionChanged(int line, int character) {
    setState(() {
      _cursorLine = line;
      _cursorCharacter = character;
    });
  }

  bool get _canSave => _needsSave && !_isSaving;

  bool get _canExecute =>
      !_needsSave &&
      (_executionStatus == ExecutionStatus.idle ||
          _executionStatus == ExecutionStatus.completed ||
          _executionStatus == ExecutionStatus.error);

  Future<void> _saveCode() async {
    if (!_canSave) return;

    final codeEditorState = _codeEditorKey.currentState;
    if (codeEditorState == null) return;

    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _sessionApi.updateFile(sessionId, codeEditorState.text);
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
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
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
    final codeEditorState = _codeEditorKey.currentState;
    if (codeEditorState == null) return;

    switch (event.type) {
      case KeyType.normal:
      case KeyType.space:
        codeEditorState.addCharacter(event.character);
        setState(() {
          _needsSave = true;
        });
        break;
      case KeyType.backspace:
        codeEditorState.deleteLastCharacter();
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

  // Go to definition
  Future<void> _goToDefinition() async {
    if (!widget.sessionManager.lspService.isInitialized) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('LSP가 초기화되지 않았습니다')));
      return;
    }

    try {
      final definitions = await widget.sessionManager.lspService.goToDefinition(
        uri: _documentUri,
        line: _cursorLine,
        character: _cursorCharacter,
      );

      if (definitions == null || definitions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('정의를 찾을 수 없습니다')));
        }
        return;
      }

      // Extract location from first definition
      final firstDef = definitions[0] as Map<String, dynamic>;

      // LSP can return either Location or LocationLink
      // Location has 'range', LocationLink has 'targetRange' and 'targetSelectionRange'
      Map<String, dynamic> range;
      if (firstDef.containsKey('targetSelectionRange')) {
        // LocationLink format
        range = firstDef['targetSelectionRange'] as Map<String, dynamic>;
      } else if (firstDef.containsKey('range')) {
        // Location format
        range = firstDef['range'] as Map<String, dynamic>;
      } else {
        throw Exception('Invalid definition format');
      }

      final start = range['start'] as Map<String, dynamic>;
      final defLine = start['line'] as int;
      final defCharacter = start['character'] as int;

      // Move cursor to definition
      final codeEditorState = _codeEditorKey.currentState;
      if (codeEditorState != null) {
        codeEditorState.moveCursorTo(defLine, defCharacter);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정의로 이동: Ln $defLine, Col $defCharacter'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('정의 조회 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.location_searching),
            tooltip: 'Go to Definition',
            onPressed: widget.sessionManager.lspService.isInitialized
                ? _goToDefinition
                : null,
          ),
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: _isSaving ? '저장 중...' : '저장',
            onPressed: _canSave ? _saveCode : null,
          ),
          IconButton(
            icon:
                _executionStatus == ExecutionStatus.submitting ||
                    _executionStatus == ExecutionStatus.polling
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            tooltip: _getExecuteButtonText(),
            onPressed: _canExecute ? _executeCode : null,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [_buildEditorTab(), _buildResultsTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _currentTabIndex,
        onTap: (index) {
          setState(() {
            _currentTabIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.code), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.terminal), label: ''),
        ],
      ),
    );
  }

  Widget _buildEditorTab() {
    return SafeArea(
      child: Column(
        children: [
          // CodeEditor - 남은 공간 모두 차지
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CodeEditor(
                key: _codeEditorKey,
                onTextChanged: (_) {
                  setState(() {
                    _needsSave = true;
                  });
                },
                onCursorPositionChanged: _onCursorPositionChanged,
              ),
            ),
          ),
          QwertyKeyboard(onKeyPressed: _handleKeyPress),
        ],
      ),
    );
  }

  Widget _buildResultsTab() {
    // 출력이나 에러 중 존재하는 것만 표시
    final hasOutput = _output != null && _output!.isNotEmpty;
    final hasError = _error != null && _error!.isNotEmpty;
    final hasErrorMessage = _errorMessage != null;

    String displayContent = '';
    if (hasOutput) {
      displayContent = _output!;
    } else if (hasError) {
      displayContent = _error!;
    } else if (hasErrorMessage) {
      displayContent = _errorMessage!;
    } else {
      displayContent = '(결과 없음)';
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              displayContent,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
