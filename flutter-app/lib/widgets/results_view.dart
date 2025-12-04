import 'package:flutter/material.dart';

class ResultsView extends StatelessWidget {
  final String? output;
  final String? error;
  final String? errorMessage;

  const ResultsView({
    super.key,
    this.output,
    this.error,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    // Determine what to display
    final hasOutput = output != null && output!.isNotEmpty;
    final hasError = error != null && error!.isNotEmpty;
    final hasErrorMessage = errorMessage != null;

    String displayContent = '';
    if (hasOutput) {
      displayContent = output!;
    } else if (hasError) {
      displayContent = error!;
    } else if (hasErrorMessage) {
      displayContent = errorMessage!;
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
