import 'package:flutter/material.dart';
import '../services/ide_service.dart';

class EditorToolbar extends StatelessWidget implements PreferredSizeWidget {
  final IdeService ideService;
  final bool isLspReady;
  final VoidCallback onSave;
  final VoidCallback onExecute;
  final VoidCallback onGoToDefinition;

  const EditorToolbar({
    super.key,
    required this.ideService,
    required this.isLspReady,
    required this.onSave,
    required this.onExecute,
    required this.onGoToDefinition,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.location_searching),
          tooltip: 'Go to Definition',
          onPressed: isLspReady ? onGoToDefinition : null,
        ),
        IconButton(
          icon: ideService.isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
          tooltip: ideService.isSaving ? '저장 중...' : '저장',
          onPressed: ideService.canSave ? onSave : null,
        ),
        IconButton(
          icon: ideService.isExecuting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_arrow),
          tooltip: ideService.executeButtonText,
          onPressed: ideService.canExecute ? onExecute : null,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
