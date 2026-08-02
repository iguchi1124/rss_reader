import 'package:flutter/material.dart';

/// A [ScaffoldMessenger] and the inset the tab bar occupies, both read from the
/// context up front so callers can await between construction and [show].
///
/// The snack bars float. A fixed one anchors to the bottom of the nearest
/// Scaffold, and on phones that Scaffold is the one inside `HomeScreen`'s body,
/// which `extendBody` runs underneath the tab bar. Only a floating bar takes
/// the margin that clears it.
class AppMessenger {
  AppMessenger.of(BuildContext context)
    : _messenger = ScaffoldMessenger.of(context),
      _bottomInset = MediaQuery.paddingOf(context).bottom;

  final ScaffoldMessengerState _messenger;
  final double _bottomInset;

  void show(String message) {
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 16 + _bottomInset),
        ),
      );
  }
}
