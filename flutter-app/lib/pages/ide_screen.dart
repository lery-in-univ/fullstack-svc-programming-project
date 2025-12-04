import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import '../services/api_client.dart';
import '../services/execution_api.dart';
import '../services/session_api.dart';
import '../services/ide_service.dart';
import '../models/key_event.dart';
import '../widgets/code_editor.dart';
import '../widgets/editor_toolbar.dart';
import '../widgets/editor_view.dart';
import '../widgets/results_view.dart';

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
  late final IdeService _ideService;
  final GlobalKey<CodeEditorState> _codeEditorKey = GlobalKey();

  // UI state
  int _currentTabIndex = 0;

  // Cursor position tracking (for Go to Definition)
  int _cursorLine = 0;
  int _cursorCharacter = 0;

  // LSP document URI
  String get _documentUri => 'file:///workspace/main.dart';

  @override
  void initState() {
    super.initState();

    // Create IdeService
    _ideService = IdeService(
      sessionApi: SessionApi(widget.apiClient),
      executionApi: ExecutionApi(widget.apiClient),
      lspService: widget.sessionManager.lspService,
    );
    _ideService.addListener(_onIdeServiceChanged);

    // Listen to LSP service state changes
    widget.sessionManager.lspService.addListener(_onLspServiceChanged);

    // Open LSP document
    _openDocumentInLsp();
  }

  @override
  void dispose() {
    _ideService.removeListener(_onIdeServiceChanged);
    widget.sessionManager.lspService.removeListener(_onLspServiceChanged);
    _ideService.dispose();
    super.dispose();
  }

  void _onIdeServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLspServiceChanged() {
    if (mounted) {
      setState(() {});

      // Open document when LSP is initialized
      if (widget.sessionManager.lspService.isInitialized) {
        _openDocumentInLsp();
      }
    }
  }

  // Open document in LSP
  Future<void> _openDocumentInLsp() async {
    final codeEditorState = _codeEditorKey.currentState;
    if (codeEditorState == null) return;

    await _ideService.openDocumentInLsp(_documentUri, codeEditorState.text);
  }

  // Cursor position changed handler
  void _onCursorPositionChanged(int line, int character) {
    setState(() {
      _cursorLine = line;
      _cursorCharacter = character;
    });
  }

  // Handle save
  Future<void> _handleSave() async {
    final codeEditorState = _codeEditorKey.currentState;
    if (codeEditorState == null) return;

    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) return;

    try {
      await _ideService.saveCode(sessionId, codeEditorState.text);
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
    }
  }

  // Handle execute
  Future<void> _handleExecute() async {
    final sessionId = widget.sessionManager.sessionId;
    if (sessionId == null) return;

    await _ideService.executeCode(sessionId);

    // Switch to results tab after execution starts
    if (mounted) {
      setState(() {
        _currentTabIndex = 1;
      });
    }
  }

  // Handle Go to Definition
  Future<void> _handleGoToDefinition() async {
    if (!widget.sessionManager.lspService.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LSP가 초기화되지 않았습니다')),
      );
      return;
    }

    try {
      final result = await _ideService.goToDefinition(
        uri: _documentUri,
        line: _cursorLine,
        character: _cursorCharacter,
      );

      if (result == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('정의를 찾을 수 없습니다')),
          );
        }
        return;
      }

      // Move cursor to definition
      final codeEditorState = _codeEditorKey.currentState;
      if (codeEditorState != null) {
        codeEditorState.moveCursorTo(
          result['line'] as int,
          result['character'] as int,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '정의로 이동: Ln ${result['line']}, Col ${result['character']}',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('정의 조회 실패: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Handle keyboard input
  void _handleKeyPress(KeyboardEvent event) {
    final codeEditorState = _codeEditorKey.currentState;
    if (codeEditorState == null) return;

    switch (event.type) {
      case KeyType.normal:
      case KeyType.space:
        codeEditorState.addCharacter(event.character);
        _ideService.markNeedsSave();
        break;
      case KeyType.backspace:
        codeEditorState.deleteLastCharacter();
        _ideService.markNeedsSave();
        break;
      case KeyType.shift:
        // Shift is handled internally by keyboard
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: EditorToolbar(
        ideService: _ideService,
        isLspReady: widget.sessionManager.lspService.isInitialized,
        onSave: _handleSave,
        onExecute: _handleExecute,
        onGoToDefinition: _handleGoToDefinition,
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          EditorView(
            editorKey: _codeEditorKey,
            onTextChanged: (_) => _ideService.markNeedsSave(),
            onCursorPositionChanged: _onCursorPositionChanged,
            onKeyPressed: _handleKeyPress,
          ),
          ResultsView(
            output: _ideService.output,
            error: _ideService.error,
            errorMessage: _ideService.errorMessage,
          ),
        ],
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
}
