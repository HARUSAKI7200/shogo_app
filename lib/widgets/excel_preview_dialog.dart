import 'package:flutter/material.dart';
// (このファイルは元のコードから変更なし)
class ExcelPreviewDialog extends StatelessWidget {
    final String title;
    final List<List<String>> data;
    final List<String> headers;
    final String projectFolderPath;
    final String? subfolder;

    const ExcelPreviewDialog({super.key, required this.title, required this.data, required this.headers, required this.projectFolderPath, this.subfolder});

    @override
    Widget build(BuildContext context) {
        // ... (UIの実装)
        return AlertDialog(title: Text(title));
    }
}