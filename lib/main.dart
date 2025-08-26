import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '照合テスト',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const OcrTestHomePage(),
    );
  }
}

class OcrTestHomePage extends StatefulWidget {
  const OcrTestHomePage({super.key});

  @override
  State<OcrTestHomePage> createState() => _OcrTestHomePageState();
}

class _OcrTestHomePageState extends State<OcrTestHomePage> {
  File? _imageFile;
  String _extractedText = '';
  String _structuredJson = ''; // いずれオンデバイスAIの結果を入れる場所
  bool _isProcessing = false;

  // ギャラリーから画像を選択する処理
  Future<void> _pickImage() async {
    setState(() {
      _imageFile = null;
      _extractedText = '';
      _structuredJson = '';
    });

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  // ML Kitを使って文字を抽出する処理
  Future<void> _extractText() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まず画像を選択してください。')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _extractedText = '文字を抽出中...';
    });

    try {
      final inputImage = InputImage.fromFile(_imageFile!);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.japanese);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      await textRecognizer.close();

      setState(() {
        _extractedText = recognizedText.text;
      });
    } catch (e) {
      setState(() {
        _extractedText = 'エラーが発生しました:\n$e';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  // ★★★ ここが将来オンデバイスAIを呼び出す場所 ★★★
  void _structureText() {
    if (_extractedText.isEmpty || _extractedText.startsWith('文字を抽出中') || _extractedText.startsWith('エラー')) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('まず文字を抽出してください。')),
      );
      return;
    }
    
    // 現時点では、抽出したテキストをそのまま表示するだけ
    setState(() {
      _structuredJson = '（ここにオンデバイスAIによる構造化結果が表示されます）\n\n-- 抽出された生テキスト --\n$_extractedText';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('照合テスト（オンデバイスAI検証）'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (_imageFile != null)
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Image.file(
                    _imageFile!,
                    height: 200,
                  ),
                )
              else
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '画像を選択してください',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              
              // --- ステップ1のボタン ---
              ElevatedButton.icon(
                icon: const Icon(Icons.image),
                label: const Text('1. ギャラリーから画像を選択'),
                onPressed: _pickImage,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
              const SizedBox(height: 12),

              // --- ステップ2のボタン ---
              ElevatedButton.icon(
                icon: const Icon(Icons.text_fields),
                label: const Text('2. 画像から文字を抽出 (ML Kit)'),
                onPressed: _isProcessing ? null : _extractText,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
              const SizedBox(height: 12),
              
              // --- ステップ3のボタン ---
               ElevatedButton.icon(
                icon: const Icon(Icons.account_tree),
                label: const Text('3. テキストを構造化 (オンデバイスAI)'),
                onPressed: _structureText, // ★将来のAI処理を呼び出す
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green[700], foregroundColor: Colors.white),
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 10),

              // --- 結果表示エリア ---
              if (_isProcessing) const CircularProgressIndicator(),

              if (_extractedText.isNotEmpty)
                _buildResultCard('ML Kit 抽出結果（生テキスト）', _extractedText),
              
              if (_structuredJson.isNotEmpty)
                _buildResultCard('オンデバイスAI 構造化結果 (JSON)', _structuredJson),

            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(String title, String content) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              const SizedBox(height: 8),
              SelectableText(content),
            ],
          ),
        ),
      ),
    );
  }
}