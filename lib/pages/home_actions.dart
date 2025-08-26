import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

import '../services/offline_ai_service.dart';
import '../services/excel_service.dart';
import '../utils/product_matcher.dart';
import 'camera_capture_page.dart';
import 'nifuda_ocr_confirm_page.dart';
import 'matching_result_page.dart';
import '../widgets/excel_preview_dialog.dart';
import '../widgets/custom_snackbar.dart';

// HomePageの状態を安全に操作するためのクラス
class HomeActions {
  final BuildContext context;
  final Function() getState; // HomePageのStateを取得
  final Function(void Function()) setState;

  // コンストラクタでHomePageのインスタンスを受け取る
  HomeActions({required this.context, required this.getState, required this.setState});

  // Stateのプロパティへのアクセサ
  dynamic get _state => getState();
  bool get _isLoading => _state._isLoading;
  String? get _currentProjectFolderPath => _state._currentProjectFolderPath;
  List<List<String>> get _nifudaData => _state._nifudaData;
  List<List<String>> get _productListKariData => _state._productListKariData;
  String get _projectTitle => _state._projectTitle;
  String get _selectedMatchingPattern => _state._selectedMatchingPattern;
  
  void _setLoading(bool loading) {
    setState(() => _state._isLoading = loading);
  }

  // --- 新規プロジェクト、保存、読み込み (既存ロジックを移植) ---
  Future<void> handleNewProject() async {
    // (元のhome_page.dartの_handleNewProjectのロジックをここに移植)
    final String? projectCode = await showDialog<String>(
        context: context,
        builder: (BuildContext dialogContext) {
          String? inputCode;
          return AlertDialog(
            title: const Text('新規プロジェクト作成'),
            content: TextField(
              autofocus: true,
              decoration: const InputDecoration(labelText: '製番を入力してください (例: QZ83941)'),
              onChanged: (value) => inputCode = value.trim(),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(dialogContext).pop(null), child: const Text('キャンセル')),
              ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(inputCode), child: const Text('作成')),
            ],
          );
        });

    if (projectCode != null && projectCode.isNotEmpty) {
      _setLoading(true);
      try {
        const String baseDcimPath = "/storage/emulated/0/DCIM";
        final String inspectionRelatedPath = p.join(baseDcimPath, "検品関係");
        final String projectFolderPath = p.join(inspectionRelatedPath, projectCode);
        
        final Directory projectDir = Directory(projectFolderPath);
        if (!await projectDir.exists()) await projectDir.create(recursive: true);

        setState(() {
          _state._projectTitle = projectCode;
          _state._currentProjectFolderPath = projectFolderPath;
          _state._nifudaData = [['製番', '項目番号', '品名', '形式', '個数', '図書番号', '摘要', '手配コード']];
          _state._productListKariData = [['ORDER No.', 'ITEM OF SPARE', '品名記号', '形格', '製品コード番号', '注文数', '記事', '備考']];
        });
        showCustomSnackBar(context, 'プロジェクト「$projectCode」が作成されました。');
      } catch (e) {
        showCustomSnackBar(context, 'プロジェクトフォルダの作成に失敗しました: $e', isError: true);
      } finally {
        _setLoading(false);
      }
    }
  }
  
  Future<void> handleSaveProject() async { /* ... 既存のsaveProjectActionのロジック ... */ }
  Future<void> handleLoadProject() async { /* ... 既存のloadProjectActionのロジック ... */ }

  // --- ★★★ 新しいオフライン荷札撮影処理 ★★★ ---
  Future<void> handleCaptureNifudaOffline() async {
    if (_isLoading) return;
    if (_currentProjectFolderPath == null) {
      showCustomSnackBar(context, 'まず「新規作成」でプロジェクトを作成してください。', isError: true);
      return;
    }
    _setLoading(true);

    final OfflineAiService aiService = OfflineAiService();
    
    // CameraCapturePageは Uint8List を返すように改修が必要
    final List<Map<String, dynamic>>? allAiResults =
        await Navigator.push<List<Map<String, dynamic>>>(
            context,
            MaterialPageRoute(
                builder: (_) => CameraCapturePage(
                    overlayText: '荷札を枠に合わせて撮影',
                    projectFolderPath: _currentProjectFolderPath!,
                    // 新しいオフラインサービスを渡す
                    aiService: (bytes) => aiService.processNifudaImage(bytes),
                )));

    if (allAiResults == null || allAiResults.isEmpty) {
      showCustomSnackBar(context, '荷札の撮影またはOCR処理がキャンセルされました。');
      _setLoading(false);
      return;
    }
    
    // OCR結果の確認フロー (既存のものを流用)
    final List<List<String>> allConfirmedRows = await _confirmOcrResults(allAiResults);
    
    if (allConfirmedRows.isNotEmpty) {
        setState(() => _nifudaData.addAll(allConfirmedRows));
        showCustomSnackBar(context, '${allConfirmedRows.length}件の荷札データがオフラインで追加されました。');
    }
    _setLoading(false);
  }

  // --- ★★★ 新しいExcel読込処理 ★★★ ---
  Future<void> handleLoadProductListFromExcel() async {
    if (_isLoading) return;
    _setLoading(true);
    
    final excelService = ExcelService();
    try {
      final filePath = await excelService.pickExcelFile();
      if (filePath == null) {
        showCustomSnackBar(context, 'ファイル選択がキャンセルされました。');
        return;
      }

      final data = await excelService.readProductListFromExcel(filePath);
      
      if (data.length > 1) { // ヘッダー以外のデータがあるか
        setState(() {
          _state._productListKariData = data;
        });
        showCustomSnackBar(context, '${data.length - 1}件の製品リストデータをExcelから読み込みました。');
      } else {
        showCustomSnackBar(context, 'Excelに有効なデータがありませんでした。', isError: true);
      }
    } catch (e) {
      showCustomSnackBar(context, 'Excel読込エラー: $e', isError: true);
    } finally {
      _setLoading(false);
    }
  }

  // --- リスト表示と照合処理 (既存ロジックを流用) ---
  void handleShowNifudaList() {
    if (_nifudaData.length <= 1) return;
    showDialog(context: context, builder: (_) => ExcelPreviewDialog(
        title: '荷札リスト', data: _nifudaData, headers: _nifudaData.first,
        projectFolderPath: _currentProjectFolderPath!, subfolder: '荷札リスト',
    ));
  }
  
  void handleShowProductList() {
     if (_productListKariData.length <= 1) return;
     showDialog(context: context, builder: (_) => ExcelPreviewDialog(
        title: '製品リスト', data: _productListKariData, headers: _productListKariData.first,
        projectFolderPath: _currentProjectFolderPath!, subfolder: '製品リスト',
    ));
  }
  
  void handleStartMatching() {
    // (既存のstartMatchingAndShowResultsActionのロジック)
    final nifudaHeaders = _nifudaData.first;
    final nifudaMapList = _nifudaData.sublist(1).map((row) => { for (int i = 0; i < nifudaHeaders.length; i++) nifudaHeaders[i]: row[i] }).toList();
    final productHeaders = _productListKariData.first;
    final productMapList = _productListKariData.sublist(1).map((row) => { for (int i = 0; i < productHeaders.length; i++) productHeaders[i]: row[i] }).toList();
    
    final matchingLogic = ProductMatcher();
    final Map<String, dynamic> rawResults = matchingLogic.match(nifudaMapList, productMapList, pattern: _selectedMatchingPattern);

    Navigator.push(context, MaterialPageRoute(builder: (_) => MatchingResultPage(
        matchingResults: rawResults, projectFolderPath: _currentProjectFolderPath!
    )));
  }

  // --- ヘルパー：OCR結果確認 ---
  Future<List<List<String>>> _confirmOcrResults(List<Map<String, dynamic>> allAiResults) async {
    List<List<String>> allConfirmedNifudaRows = [];
    for (int i = 0; i < allAiResults.length; i++) {
      final result = allAiResults[i];
      final Map<String, dynamic>? confirmedMap = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(builder: (_) => NifudaOcrConfirmPage(
            extractedData: result, imageIndex: i + 1, totalImages: allAiResults.length
        )),
      );
      if (confirmedMap != null) {
        allConfirmedNifudaRows.add(NifudaOcrConfirmPage.nifudaFields.map((field) => confirmedMap[field]?.toString() ?? '').toList());
      } else {
        showCustomSnackBar(context, '${i + 1}枚目の確認が破棄されました。');
      }
    }
    return allConfirmedNifudaRows;
  }
}