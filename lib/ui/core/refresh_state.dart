import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a refresh the user asked for is still running.
///
/// Deliberately separate from the providers holding feeds and articles: those
/// also reload after ordinary writes, and only an explicit refresh should put a
/// spinner in the app bar.
class RefreshState extends Notifier<bool> {
  @override
  bool build() => false;

  /// Returns false when a refresh is already running.
  bool start() {
    if (state) return false;
    state = true;
    return true;
  }

  void finish() => state = false;
}
