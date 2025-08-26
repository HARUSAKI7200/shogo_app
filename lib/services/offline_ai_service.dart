import 'dart.io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mediapipe/google_mediapipe.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// MediaPipeを使用した最新のオフラインAIサービス
class OfflineAiService {
  // 荷札の項目リスト（AIへの質問として使用）
  static const List<String> _nifudaFields = [
    '製番', '項目番号', '品名', '形式', '個数', '図書番号', '摘要', '手配コード'
  ];

  BertQuestionAnswerer? _questionAnswerer;

  /// AIサービスを初期化する
  Future<void> initialize() async {
    // すでに初期化済みなら何もしない
    if (_questionAnswerer != null) return;

    // アセットからモデルファイルを読み込み、一時ディレクトリにコピーする
    // (MediaPipeライブラリがファイルパスを要求するため)
    final modelPath = await _getAssetFile('assets/models/mobilebert_qa.tflite');
    
    // MediaPipeの質疑応答タスクを初期化
    _questionAnswerer = await BertQuestionAnswerer.create(
      BertQuestionAnswererOptions(baseOptions: BaseOptions(modelAssetPath: modelPath)),
    );
    debugPrint("OfflineAiService (MediaPipe) initialized successfully.");
  }

  /// アセットファイルをデバイスの一時記憶域にコピーして、そのパスを返すヘルパー
  Future<String> _getAssetFile(String asset) async {
    final byteData = await rootBundle.load(asset);
    final buffer = byteData.buffer;
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, p.basename(asset)));
    // 常に最新のモデルファイルを使用するため、一度書き込む
    await file.writeAsBytes(buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    return file.path;
  }

  /// 画像からテキストを抽出し、構造化されたMapを返す
  Future<Map<String, dynamic>> processNifudaImage(Uint8List imageBytes) async {
    // もし初期化されていなければ、ここで初期化する
    if (_questionAnswerer == null) {
      await initialize();
    }

    final inputImage = InputImage.fromBytes(bytes: imageBytes, metadata: null);

    // --- 第1段階：ML Kitで画像から全てのテキストをスキャン ---
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    
    // 改行をスペースに置換してAIの精度を上げる
    final String rawText = recognizedText.text.replaceAll('\n', ' '); 
    debugPrint("--- ML Kit Raw Text ---\n$rawText");
    if (rawText.isEmpty) {
      debugPrint("ML Kit found no text in the image.");
      return {};
    }

    // --- 第2段階：MediaPipeのオンデバイスAIでテキストを構造化（紐付け） ---
    final Map<String, String> structuredData = {};
    for (final field in _nifudaFields) {
      // MediaPipeを使って質疑応答を実行
      final List<QaAnswer> answers = await _questionAnswerer!.answer(context: rawText, question: field);
      
      // 最も確からしい答えを格納
      final bestAnswer = answers.isNotEmpty ? answers.first.text : '';
      structuredData[field] = bestAnswer;
      debugPrint("Q: $field -> A: $bestAnswer");
    }

    return structuredData;
  }
  
  /// リソースを解放する
  void dispose() {
    _questionAnswerer?.close();
    _questionAnswerer = null;
    debugPrint("OfflineAiService disposed.");
  }
}