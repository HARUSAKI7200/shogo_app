import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

Future<String> exportToExcelStorage({
  required String fileName,
  required String sheetName,
  required List<String> headers,
  required List<List<String>> rows,
  required String projectFolderPath,
  String? subfolder,
}) async {
  if (!Platform.isAndroid) {
    throw Exception('このファイル保存機能はAndroid専用です。');
  }

  var excel = Excel.createExcel();
  
  final String initialSheetName = excel.sheets.keys.first;
  Sheet sheetObject = excel[initialSheetName];

  final headerCells = headers.map((h) => TextCellValue(h)).toList();
  sheetObject.appendRow(headerCells);
  
  for (var row in rows) {
    sheetObject.appendRow(row.map((cell) => TextCellValue(cell)).toList());
  }

  excel.rename(initialSheetName, sheetName);

  var status = await Permission.storage.request();
  if (!status.isGranted) {
    if (!await Permission.manageExternalStorage.request().isGranted) {
       throw Exception('ストレージへのアクセス権限が拒否されました。');
    }
  }

  String directoryPathForMessage = "";
  Directory directory;
  try {
    String targetPath = projectFolderPath;
    if (subfolder != null) {
      targetPath = p.join(projectFolderPath, subfolder);
      directoryPathForMessage = p.join(p.basename(projectFolderPath), subfolder);
    } else {
      directoryPathForMessage = p.basename(projectFolderPath);
    }
    
    directory = Directory(targetPath);

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  } catch (e) {
      debugPrint('ディレクトリ作成エラー: $e');
      throw Exception('保存先ディレクトリの作成に失敗しました: $e');
  }

  final filePath = p.join(directory.path, fileName);
  final fileBytes = excel.save(fileName: fileName);

  if (fileBytes != null) {
    try {
      final file = File(filePath);
      await file.writeAsBytes(fileBytes);
    } catch (e) {
      throw Exception('ファイル書き込みに失敗しました: $filePath, エラー: $e');
    }
  } else {
    throw Exception('Excelファイルのエンコードに失敗しました。');
  }

  return '$directoryPathForMessage フォルダ内の $fileName';
}