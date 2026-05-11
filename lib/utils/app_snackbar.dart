import 'package:flutter/material.dart';

class AppSnackBar {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static void success(BuildContext context, String message) {
    _show(message, backgroundColor: Colors.green.shade600);
  }

  static void error(BuildContext context, String message) {
    _show(message, backgroundColor: Colors.red.shade700);
  }

  static void _show(String message, {required Color backgroundColor}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      return;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }
}
