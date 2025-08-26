import 'package:flutter/material.dart';
// (このファイルは元のコードから変更なし)
class MatchingResultPage extends StatelessWidget {
    final Map<String, dynamic> matchingResults;
    final String projectFolderPath;

    const MatchingResultPage({super.key, required this.matchingResults, required this.projectFolderPath});

    @override
    Widget build(BuildContext context) {
        // ... (UIの実装)
        return Scaffold(appBar: AppBar(title: const Text('照合結果')));
    }
}