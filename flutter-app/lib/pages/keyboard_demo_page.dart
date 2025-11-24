import 'package:flutter/material.dart';
import '../models/key_event.dart';
import '../widgets/keyboard/qwerty_keyboard.dart';
import '../widgets/text_input_area.dart';

/// Demo page showing the custom QWERTY keyboard in action
///
/// This page demonstrates the keyboard functionality by displaying
/// a text input area above the keyboard where typed text appears.
class KeyboardDemoPage extends StatefulWidget {
  const KeyboardDemoPage({super.key});

  @override
  State<KeyboardDemoPage> createState() => _KeyboardDemoPageState();
}

class _KeyboardDemoPageState extends State<KeyboardDemoPage> {
  final GlobalKey<TextInputAreaState> _textInputKey = GlobalKey();

  void _handleKeyPress(KeyboardEvent event) {
    final textInputState = _textInputKey.currentState;
    if (textInputState == null) return;

    switch (event.type) {
      case KeyType.normal:
      case KeyType.space:
        textInputState.addCharacter(event.character);
        break;
      case KeyType.backspace:
        textInputState.deleteLastCharacter();
        break;
      case KeyType.shift:
        // Shift is handled internally by the keyboard
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom QWERTY Keyboard Demo'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Instructions
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Text(
                            'Use the keyboard below to type. Press Shift for uppercase letters.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16.0),

                // Text input area
                TextInputArea(
                  key: _textInputKey,
                ),
                const SizedBox(height: 16.0),

                // Custom QWERTY keyboard
                QwertyKeyboard(
                  onKeyPressed: _handleKeyPress,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
