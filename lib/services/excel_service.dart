import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

class ExcelService {
  /// ファイルピッカーでユーザーにExcelファイルを選択させる
  Future<String?> pickExcelFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    return result?.files.single.path;
  }

  /// Excelファイルを読み込み、製品リストのデータ（List<List<String>>）を返す
  Future<List<List<String>>> readProductListFromExcel(String filePath) async {
    final bytes = File(filePath).readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);

    final List<List<String>> productData = [];
    final sheet = excel.tables[excel.tables.keys.first]; // 最初のシートを対象とする

    if (sheet == null) {
      throw Exception('Excelファイルにシートが見つかりません。');
    }

    // ヘッダー行を期待
    const List<String> expectedHeaders = [
      'ORDER No.', 'ITEM OF SPARE', '品名記号', '形格', '製品コード番号', '注文数', '記事', '備考'
    ];
    
    // 1行目をヘッダーとして読み込み
    final headerRow = sheet.rows.first;
    final headerStrings = headerRow.map((cell) => cell?.value.toString().trim() ?? '').toList();

    // ヘッダーが期待通りか簡易的にチェック
    if (headerStrings.isEmpty || !headerStrings.contains('ORDER No.')) {
        throw Exception('Excelのフォーマットが不正です。1行目に "ORDER No." を含むヘッダーが必要です。');
    }
    productData.add(expectedHeaders); // アプリ内部では固定ヘッダーを使う

    // 2行目以降のデータを読み込む
    for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final rowData = headerStrings.asMap().entries.map((entry) {
            final colIndex = entry.key;
            final header = entry.value;
            final cellValue = (colIndex < row.length) ? row[colIndex]?.value.toString() ?? '' : '';
            return MapEntry(header, cellValue);
        }).toList();

        final orderedRow = expectedHeaders.map((header) {
            final entry = rowData.firstWhere((e) => e.key == header, orElse: () => const MapEntry('', ''));
            return entry.value;
        }).toList();
        productData.add(orderedRow);
    }

    return productData;
  }
}