import 'package:flutter/material.dart';

/// A text input display area that shows keyboard input
///
/// This widget displays the text that has been input via the keyboard
/// and provides a clear button to reset the text.
class TextInputArea extends StatefulWidget {
  /// Initial text to display
  final String initialText;

  /// Callback when text changes
  final void Function(String text)? onTextChanged;

  const TextInputArea({
    super.key,
    this.initialText = '',
    this.onTextChanged,
  });

  @override
  State<TextInputArea> createState() => TextInputAreaState();
}

class TextInputAreaState extends State<TextInputArea> {
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText;
  }

  /// Adds a character to the text
  void addCharacter(String character) {
    setState(() {
      _text += character;
    });
    widget.onTextChanged?.call(_text);
  }

  /// Removes the last character from the text
  void deleteLastCharacter() {
    if (_text.isNotEmpty) {
      setState(() {
        _text = _text.substring(0, _text.length - 1);
      });
      widget.onTextChanged?.call(_text);
    }
  }

  /// Clears all text
  void clear() {
    setState(() {
      _text = '';
    });
    widget.onTextChanged?.call(_text);
  }

  /// Gets the current text
  String get text => _text;

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
                'Input Text',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              if (_text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  iconSize: 20.0,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: clear,
                  tooltip: 'Clear text',
                ),
            ],
          ),
          const SizedBox(height: 8.0),
          Container(
            constraints: const BoxConstraints(minHeight: 100.0),
            child: SelectableText(
              _text.isEmpty ? 'Start typing with the keyboard below...' : _text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: _text.isEmpty
                        ? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                        : Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
