import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_messenger.dart';

/// Missing or unopenable links are reported through a snack bar.
Future<void> openExternalLink(
  BuildContext context,
  String? url, {
  String emptyMessage = 'No link available.',
}) async {
  final messenger = AppMessenger.of(context);

  final uri = url == null ? null : Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    messenger.show(emptyMessage);
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched) {
    messenger.show('Could not open the link.');
  }
}
