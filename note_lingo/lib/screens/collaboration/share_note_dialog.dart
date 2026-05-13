// lib/screens/collaboration/share_note_dialog.dart
// Dialog for sharing notes with other users

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/collaboration_provider.dart';

class ShareNoteDialog extends StatefulWidget {
  final String noteId;
  final String noteTitle;

  const ShareNoteDialog({required this.noteId, required this.noteTitle});

  @override
  State<ShareNoteDialog> createState() => _ShareNoteDialogState();
}

class _ShareNoteDialogState extends State<ShareNoteDialog> {
  late TextEditingController _emailController;
  String _selectedAccessLevel = 'view';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _shareNote() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter an email address')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final provider = context.read<CollaborationProvider>();
      await provider.shareNote(
        widget.noteId,
        _emailController.text.trim(),
        _selectedAccessLevel,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Note shared with ${_emailController.text}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Share "${widget.noteTitle}"'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share with', style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 8),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'user@example.com',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            SizedBox(height: 16),
            Text('Access Level', style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 8),
            _AccessLevelSelector(
              selectedLevel: _selectedAccessLevel,
              onChanged: (level) {
                setState(() => _selectedAccessLevel = level);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _shareNote,
          child: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Share'),
        ),
      ],
    );
  }
}

class _AccessLevelSelector extends StatelessWidget {
  final String selectedLevel;
  final ValueChanged<String> onChanged;

  const _AccessLevelSelector({
    required this.selectedLevel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final levels = {
      'view': 'View Only (read-only)',
      'edit': 'Can Edit (full access)',
    };

    return Column(
      children: levels.entries.map((entry) {
        return RadioListTile<String>(
          title: Text(entry.value),
          subtitle: Text(
            _getAccessDescription(entry.key),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: entry.key,
          groupValue: selectedLevel,
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }

  String _getAccessDescription(String level) {
    switch (level) {
      case 'view':
        return 'Can only view, no editing';
      case 'edit':
        return 'Can view, edit, and delete';
      default:
        return '';
    }
  }
}
