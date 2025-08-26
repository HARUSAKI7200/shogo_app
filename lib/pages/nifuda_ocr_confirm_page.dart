import 'package:flutter/material.dart';

class NifudaOcrConfirmPage extends StatelessWidget {
  final Map<String, dynamic> extractedData;
  final int imageIndex;
  final int totalImages;

  static const List<String> nifudaFields = [
    '製番', '項目番号', '品名', '形式', '個数', '図書番号', '摘要', '手配コード'
  ];

  const NifudaOcrConfirmPage({
    super.key,
    required this.extractedData,
    required this.imageIndex,
    required this.totalImages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('荷札OCR結果確認 ($imageIndex / $totalImages)'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: DataTable(
                    columns: const [
                        DataColumn(label: Text('項目', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('抽出結果', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: nifudaFields.map((field) {
                        return DataRow(
                            cells: [
                                DataCell(Text(field)),
                                DataCell(Text(extractedData[field]?.toString() ?? '')),
                            ],
                        );
                    }).toList(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('この結果を破棄'),
                      onPressed: () => Navigator.pop(context, null),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('この内容で確定'),
                      onPressed: () => Navigator.pop(context, extractedData),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}