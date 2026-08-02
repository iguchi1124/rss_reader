import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Missing or unopenable links are reported through a snack bar.
Future<void> openExternalLink(
  BuildContext context,
  String? url, {
  String emptyMessage = 'No link available.',
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    messenger.showSnackBar(SnackBar(content: Text(emptyMessage)));
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open the link.')),
    );
  }
}
