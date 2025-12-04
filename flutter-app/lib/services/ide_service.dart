import 'package:flutter/material.dart';
import 'session_api.dart';
import 'execution_api.dart';
import 'lsp_websocket_service.dart';

enum ExecutionStatus { idle, submitting, polling, completed, error }

class IdeService extends ChangeNotifier {
  final SessionApi _sessionApi;
  final ExecutionApi _executionApi;
  final LspWebSocketService _lspService;

  // Execution state
  ExecutionStatus _executionStatus = ExecutionStatus.idle;
  String? _output;
  String? _error;
  int? _exitCode;
  String? _errorMessage;

  // Save state
  bool _isSaving = false;
  bool _needsSave = false;

  IdeService({
    required SessionApi sessionApi,
    required ExecutionApi executionApi,
    required LspWebSocketService lspService,
  })  : _sessionApi = sessionApi,
        _executionApi = executionApi,
        _lspService = lspService;

  // Getters
  ExecutionStatus get executionStatus => _executionStatus;
  String? get output => _output;
  String? get error => _error;
  int? get exitCode => _exitCode;
  String? get errorMessage => _errorMessage;
  bool get isSaving => _isSaving;
  bool get needsSave => _needsSave;

  bool get canSave => _needsSave && !_isSaving;
  bool get canExecute =>
      !_needsSave &&
      (_executionStatus == ExecutionStatus.idle ||
          _executionStatus == ExecutionStatus.completed ||
          _executionStatus == ExecutionStatus.error);

  bool get isExecuting =>
      _executionStatus == ExecutionStatus.submitting ||
      _executionStatus == ExecutionStatus.polling;

  String get executeButtonText {
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

  // State management
  void markNeedsSave() {
    _needsSave = true;
    notifyListeners();
  }

  void markSaved() {
    _needsSave = false;
    notifyListeners();
  }

  // Save code
  Future<void> saveCode(String sessionId, String code) async {
    if (!canSave) return;

    _isSaving = true;
    notifyListeners();

    try {
      await _sessionApi.updateFile(sessionId, code);
      _needsSave = false;
      _isSaving = false;
      notifyListeners();
    } catch (e) {
      _isSaving = false;
      notifyListeners();
      rethrow;
    }
  }

  // Execute code
  Future<void> executeCode(String sessionId) async {
    if (!canExecute) return;

    _executionStatus = ExecutionStatus.submitting;
    _output = null;
    _error = null;
    _exitCode = null;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Submit execution
      final jobCreated = await _executionApi.submitCode(sessionId);
      _executionStatus = ExecutionStatus.polling;
      notifyListeners();

      // 2. Poll until complete
      final completedJob = await _executionApi.pollUntilComplete(
        jobCreated.id,
        onStatusUpdate: (_) {},
      );

      // 3. Update with results
      _executionStatus = ExecutionStatus.completed;
      _output = completedJob.output;
      _error = completedJob.error;
      _exitCode = completedJob.exitCode;
      notifyListeners();
    } catch (e) {
      _executionStatus = ExecutionStatus.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  // Open document in LSP
  Future<void> openDocumentInLsp(String uri, String content) async {
    if (!_lspService.isInitialized) {
      return;
    }

    try {
      await _lspService.openDocument(uri, content);
      debugPrint('[IdeService] Document opened in LSP');
    } catch (e) {
      debugPrint('[IdeService] Failed to open document in LSP: $e');
    }
  }

  // Go to definition
  Future<Map<String, dynamic>?> goToDefinition({
    required String uri,
    required int line,
    required int character,
  }) async {
    if (!_lspService.isInitialized) {
      throw Exception('LSP가 초기화되지 않았습니다');
    }

    try {
      final definitions = await _lspService.goToDefinition(
        uri: uri,
        line: line,
        character: character,
      );

      if (definitions == null || definitions.isEmpty) {
        return null;
      }

      // Extract location from first definition
      final firstDef = definitions[0] as Map<String, dynamic>;

      // LSP can return either Location or LocationLink
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

      return {
        'line': defLine,
        'character': defCharacter,
      };
    } catch (e) {
      debugPrint('[IdeService] Failed to get definition: $e');
      rethrow;
    }
  }
}
