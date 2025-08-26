import 'dart.typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Sizeクラスを使用するために必要
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// tflite_flutterを使用した、確実なオフラインAIサービス
class OfflineAiService {
  late Interpreter _interpreter;
  late BertTokenizer _tokenizer;
  bool _isInitialized = false;

  static const List<String> _nifudaFields = [
    '製番', '項目番号', '品名', '形式', '個数', '図書番号', '摘要', '手配コード'
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      _tokenizer = BertTokenizer(await rootBundle.loadString('assets/models/vocab.txt'));
      _interpreter = await Interpreter.fromAsset('models/mobilebert_qa.tflite');
      _isInitialized = true;
      debugPrint("OfflineAiService (TFLite) initialized successfully.");
    } catch (e) {
      debugPrint("Error initializing OfflineAiService: $e");
      rethrow;
    }
  }

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
    }
  }

  Future<Map<String, dynamic>> processNifudaImage(Uint8List imageBytes) async {
    if (!_isInitialized) await initialize();

    // ★★★ エラー修正点 ★★★
    // metadataにダミーの値を設定
    final inputImage = InputImage.fromBytes(
      bytes: imageBytes,
      metadata: InputImageMetadata(
        size: const Size(1, 1),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.bgra8888,
        bytesPerRow: 1,
      ),
    );
    
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();
    
    final String rawText = recognizedText.text.replaceAll('\n', ' ');
    debugPrint("--- ML Kit Raw Text ---\n$rawText");
    if (rawText.isEmpty) return {};

    final Map<String, String> structuredData = {};
    for (final field in _nifudaFields) {
      final answer = await _answerQuestion(rawText, field);
      structuredData[field] = answer;
      debugPrint("Q: $field -> A: $answer");
    }
    return structuredData;
  }

  Future<String> _answerQuestion(String context, String question) async {
    const int maxLen = 384;
    final input = _tokenizer.encode(question, context, maxLen);
    
    final inputIds = [input.inputIds];
    final inputMask = [input.inputMask];
    final segmentIds = [input.segmentIds];

    final outputStartLogits = [List.filled(maxLen, 0.0)];
    final outputEndLogits = [List.filled(maxLen, 0.0)];

    final inputs = [inputIds, inputMask, segmentIds];
    final outputs = {0: outputEndLogits, 1: outputStartLogits};

    _interpreter.runForMultipleInputs(inputs, outputs);

    final answer = _tokenizer.decode(input, outputStartLogits[0], outputEndLogits[0]);
    return answer;
  }
}

// --- Helper classes for BERT Tokenization ---
// 不安定なtflite_flutter_helperの代わりに、必要な機能を自前で実装

class BertTokenizer {
  final Map<String, int> _vocab;
  
  BertTokenizer(String vocabContent) : _vocab = _parseVocab(vocabContent);

  static Map<String, int> _parseVocab(String content) {
    final vocab = <String, int>{};
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        vocab[line] = i;
      }
    }
    return vocab;
  }

  QAInput encode(String question, String context, int maxLen) {
    final queryTokens = _tokenize(question);
    if (queryTokens.length > 64) {
      queryTokens.removeRange(64, queryTokens.length);
    }
    
    final contextTokens = _tokenize(context);
    final maxContextLen = maxLen - queryTokens.length - 3; // for [CLS], [SEP], [SEP]
    if (contextTokens.length > maxContextLen) {
      contextTokens.removeRange(maxContextLen, contextTokens.length);
    }

    final tokens = ['[CLS]', ...queryTokens, '[SEP]', ...contextTokens, '[SEP]'];
    final segmentIds = List.filled(queryTokens.length + 2, 0) + List.filled(contextTokens.length + 1, 1);
    
    final inputIds = tokens.map((t) => _vocab[t] ?? _vocab['[UNK]']!).toList();
    final inputMask = List.filled(inputIds.length, 1);

    // Padding
    while (inputIds.length < maxLen) {
      inputIds.add(0);
      inputMask.add(0);
      segmentIds.add(0);
    }

    return QAInput(inputIds, inputMask, segmentIds, tokens);
  }

  List<String> _tokenize(String text) {
    // 非常に基本的な空白区切りのトークナイザー。日本語の精度向上のためには、より高度な形態素解析（例: MeCab, Sudachi）の導入が望ましい。
    return text.toLowerCase().trim().split(RegExp(r'\s+'));
  }

  String decode(QAInput input, List<double> startLogits, List<double> endLogits) {
    int maxStartIndex = 0;
    double maxStartLogit = -double.infinity;
    // 答えの開始位置を最も確率の高い場所として見つける
    for (int i = 0; i < input.inputTokens.length; i++) {
      if (startLogits[i] > maxStartLogit) {
        maxStartLogit = startLogits[i];
        maxStartIndex = i;
      }
    }

    int maxEndIndex = maxStartIndex;
    double maxEndLogit = -double.infinity;
    // 開始位置以降で、答えの終了位置を最も確率の高い場所として見つける
    for (int i = maxStartIndex; i < input.inputTokens.length; i++) {
      if (endLogits[i] > maxEndLogit) {
        maxEndLogit = endLogits[i];
        maxEndIndex = i;
      }
    }
    
    if (maxStartIndex > maxEndIndex || 
        maxEndIndex >= input.inputTokens.length || 
        input.inputTokens[maxStartIndex] == '[CLS]' ||
        input.inputTokens[maxStartIndex] == '[SEP]') {
       return '';
    }
    
    // 見つかった開始位置から終了位置までのトークンを結合して答えの文字列を復元
    final answerTokens = input.inputTokens.sublist(maxStartIndex, maxEndIndex + 1);
    return answerTokens.join(' ').replaceAll(' ##', '');
  }
}

class QAInput {
  final List<int> inputIds;
  final List<int> inputMask;
  final List<int> segmentIds;
  final List<String> inputTokens;
  QAInput(this.inputIds, this.inputMask, this.segmentIds, this.inputTokens);
}