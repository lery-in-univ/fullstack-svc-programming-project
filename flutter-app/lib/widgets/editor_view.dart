import 'package:flutter/material.dart';
import '../models/key_event.dart';
import 'code_editor.dart';
import 'keyboard/qwerty_keyboard.dart';

class EditorView extends StatelessWidget {
  final GlobalKey<CodeEditorState> editorKey;
  final ValueChanged<String> onTextChanged;
  final Function(int, int) onCursorPositionChanged;
  final ValueChanged<KeyboardEvent> onKeyPressed;

  const EditorView({
    super.key,
    required this.editorKey,
    required this.onTextChanged,
    required this.onCursorPositionChanged,
    required this.onKeyPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // CodeEditor - takes remaining space
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CodeEditor(
                key: editorKey,
                onTextChanged: onTextChanged,
                onCursorPositionChanged: onCursorPositionChanged,
              ),
            ),
          ),
          QwertyKeyboard(onKeyPressed: onKeyPressed),
        ],
      ),
    );
  }
}
