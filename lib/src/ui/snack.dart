import 'package:flutter/material.dart';

/// Shows [message] in a SnackBar, replacing the one currently shown.
void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
