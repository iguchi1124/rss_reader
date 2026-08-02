import 'package:flutter/foundation.dart';

/// Base for ViewModels that update their state from asynchronous work.
///
/// A load or refresh can still be in flight when the screen is popped. Since
/// [notifyListeners] throws once [dispose] has run, notifications raised after
/// that point are dropped instead of crashing.
abstract class DisposableViewModel extends ChangeNotifier {
  bool _isDisposed = false;

  bool get isDisposed => _isDisposed;

  /// Notifies listeners unless this ViewModel is already disposed.
  @protected
  void safeNotifyListeners() {
    if (_isDisposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
