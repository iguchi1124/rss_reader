import 'package:flutter/material.dart';

/// Adding the feed is left to [onSubmit]; this dialog only renders the failure
/// message beneath the field, and closes itself on success.
class AddFeedDialog extends StatefulWidget {
  const AddFeedDialog({super.key, required this.onSubmit});

  /// Returns null on success, or a message to display on failure.
  final Future<String?> Function(String url) onSubmit;

  @override
  State<AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<AddFeedDialog> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Enter a URL.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final error = await widget.onSubmit(url);
    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add feed'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isSubmitting,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _isSubmitting ? null : _submit(),
            decoration: InputDecoration(
              hintText: 'https://example.com/feed.xml',
              labelText: 'Feed or site URL',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Enter a site URL and its feed will be discovered automatically.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
