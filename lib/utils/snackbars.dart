import 'package:flutter/material.dart';

/// A short one-line message at the bottom of the screen.
void showInfoSnack(BuildContext context, String message) {
  // Replace rather than queue: tapping a placeholder button five times
  // shouldn't line up five snackbars that play one after another.
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}