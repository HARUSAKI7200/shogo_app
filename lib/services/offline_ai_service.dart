import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// ML KitとオンデバイスAIモデルを組み合わせたオフラインOCRサービス
class OfflineAiService {
  /// 画像からテキストを抽出し、構造化されたMapを返す
  ///
  /// @param imageBytes 画像のバイトデータ
  /// @return 構造化された荷札データのMap
  Future<Map<String, dynamic>> processNifudaImage(Uint8List imageBytes) async {
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      metadata: null, // 必要に応じて設定
    );

    // --- 第1段階：ML Kitで画像から全てのテキストをスキャン ---
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    
    final String rawText = recognizedText.text;
    debugPrint("--- ML Kit Raw Text ---\n$rawText");

    // --- 第2段階：オンデバイスAIでテキストを構造化（紐付け） ---
    // ★★★
    // ★★★ ここに将来、TFLiteモデルや軽量LLMを呼び出す処理を実装します ★★★
    // ★★★
    // 今回は、ルールベースの簡易的な紐付けロジックで代用します。
    // これだけでも、ある程度の精度は期待できます。
    final structuredData = _structureTextWithRules(rawText);

    return structuredData;
  }
  
  /// ルールベースでテキストを構造化する簡易的な実装例
  Map<String, dynamic> _structureTextWithRules(String text) {
    final lines = text.split('\n');
    final Map<String, String> data = {
      '製番': '', '項目番号': '', '品名': '', '形式': '', 
      '個数': '', '図書番号': '', '摘要': '', '手配コード': ''
    };

    // 各行をキーワードで判定
    for (String line in lines) {
      if (line.contains('製番')) {
        data['製番'] = _getValueAfterKeyword(line, '製番');
      } else if (line.contains('項目番号')) {
        data['項目番号'] = _getValueAfterKeyword(line, '項目番号');
      } else if (line.contains('品名')) {
        data['品名'] = _getValueAfterKeyword(line, '品名');
      } else if (line.contains('形式')) {
        data['形式'] = _getValueAfterKeyword(line, '形式');
      } else if (line.contains('個数') || line.contains('数量')) {
        data['個数'] = _getValueAfterKeyword(line, '(個数|数量)');
      } else if (line.contains('図書番号')) {
        data['図書番号'] = _getValueAfterKeyword(line, '図書番号');
      } else if (line.contains('摘要') || line.contains('適用')) {
        data['摘要'] = _getValueAfterKeyword(line, '(摘要|適用)');
      } else if (line.contains('手配コード')) {
        data['手配コード'] = _getValueAfterKeyword(line, '手配コード');
      }
    }
    return data;
  }

  /// キーワード以降の文字列を抽出するヘルパー関数
  String _getValueAfterKeyword(String line, String keyword) {
    try {
      // 正規表現でキーワードと値の間のコロンやスペースを考慮
      final regex = RegExp('$keyword[:\\s]*+(.*)');
      final match = regex.firstMatch(line);
      return match?.group(1)?.trim() ?? '';
    } catch (e) {
      return '';
    }
  }
}