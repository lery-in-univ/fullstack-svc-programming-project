import 'package:flutter/material.dart';

/// Code editor with cursor position tracking
class CodeEditor extends StatefulWidget {
  final String initialText;
  final void Function(String text)? onTextChanged;
  final void Function(int line, int character)? onCursorPositionChanged;

  const CodeEditor({
    super.key,
    this.initialText = '',
    this.onTextChanged,
    this.onCursorPositionChanged,
  });

  @override
  State<CodeEditor> createState() => CodeEditorState();
}

class CodeEditorState extends State<CodeEditor> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  int _currentLine = 0;
  int _currentCharacter = 0;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();

    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    widget.onTextChanged?.call(_controller.text);
    _updateCursorPosition();
  }

  void _updateCursorPosition() {
    final selection = _controller.selection;
    if (!selection.isValid) return;

    final text = _controller.text;
    final cursorOffset = selection.baseOffset;

    // Calculate line and character from cursor offset
    int line = 0;
    int character = 0;

    for (int i = 0; i < cursorOffset && i < text.length; i++) {
      if (text[i] == '\n') {
        line++;
        character = 0;
      } else {
        character++;
      }
    }

    if (_currentLine != line || _currentCharacter != character) {
      _currentLine = line;
      _currentCharacter = character;
      widget.onCursorPositionChanged?.call(line, character);
    }
  }

  /// Get current cursor position
  ({int line, int character}) get cursorPosition => (
        line: _currentLine,
        character: _currentCharacter,
      );

  /// Get current text
  String get text => _controller.text;

  /// Set text programmatically
  void setText(String text) {
    _controller.text = text;
  }

  /// Add character at cursor position (for keyboard input)
  void addCharacter(String character) {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid) {
      _controller.text = text + character;
      return;
    }

    final newText = text.replaceRange(
      selection.start,
      selection.end,
      character,
    );

    final newOffset = selection.baseOffset + character.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  /// Delete character before cursor (backspace)
  void deleteLastCharacter() {
    final selection = _controller.selection;
    final text = _controller.text;

    if (!selection.isValid || selection.baseOffset == 0) {
      return;
    }

    if (selection.isCollapsed) {
      // Delete single character before cursor
      final newText = text.replaceRange(
        selection.baseOffset - 1,
        selection.baseOffset,
        '',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset - 1),
      );
    } else {
      // Delete selection
      final newText = text.replaceRange(
        selection.start,
        selection.end,
        '',
      );
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    }
  }

  /// Move cursor to specific line and character
  void moveCursorTo(int line, int character) {
    final text = _controller.text;
    int offset = 0;
    int currentLine = 0;

    // Find offset for target line
    for (int i = 0; i < text.length; i++) {
      if (currentLine == line) {
        offset = i + character;
        break;
      }
      if (text[i] == '\n') {
        currentLine++;
      }
    }

    // Clamp offset to text length
    offset = offset.clamp(0, text.length);

    _controller.selection = TextSelection.collapsed(offset: offset);
    _updateCursorPosition();
  }

  /// Clear all text
  void clear() {
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Code Editor',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              // Show cursor position
              Text(
                'Ln $_currentLine, Col $_currentCharacter',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            maxLines: null,
            minLines: 10,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'void main() {\n  print("Hello, Dart!");\n}',
              hintStyle: TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
              ),
            ),
            onTap: _updateCursorPosition,
            onChanged: (_) {
              // Handled by _controller listener
            },
          ),
        ],
      ),
    );
  }
}
