import 'package:flutter/material.dart';

void showCustomSnackBar(BuildContext context, String message, {bool isError = false, int durationSeconds = 3, bool showAtTop = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
      margin: showAtTop
          ? EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height - 140, 
              left: 15,
              right: 15,
            )
          : const EdgeInsets.all(15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      duration: Duration(seconds: durationSeconds),
    ),
  );
}