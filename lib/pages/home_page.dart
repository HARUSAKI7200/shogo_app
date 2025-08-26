import 'package:flutter/material.dart';
import 'home_actions.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _projectTitle = '(新規プロジェクト)';
  String _selectedMatchingPattern = 'T社（製番・項目番号）';
  final List<String> _matchingPatterns = ['T社（製番・項目番号）', '汎用（図書番号優先）'];

  List<List<String>> _nifudaData = [
    ['製番', '項目番号', '品名', '形式', '個数', '図書番号', '摘要', '手配コード'],
  ];
  List<List<String>> _productListKariData = [
    ['ORDER No.', 'ITEM OF SPARE', '品名記号', '形格', '製品コード番号', '注文数', '記事', '備考'],
  ];
  bool _isLoading = false;
  String? _currentProjectFolderPath;

  late final HomeActions _actions;

  @override
  void initState() {
    super.initState();
    _actions = HomeActions(
      context: context,
      getState: () => this,
      setState: (fn) { if(mounted) setState(fn); },
    );
  }

  @override
  void dispose() {
    _actions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonColumnWidth = (MediaQuery.of(context).size.width * 0.5).clamp(280.0, 450.0);

    return Scaffold(
      appBar: AppBar(title: Text('シンコー府中輸出課 荷札照合アプリ (オフライン版) - $_projectTitle')),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: buttonColumnWidth,
                          child: _buildActionButton(label: '新規作成', onPressed: _actions.handleNewProject, icon: Icons.create_new_folder),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: buttonColumnWidth,
                      child: Row(
                        children: [
                          Expanded(child: _buildActionButton(label: '保存', onPressed: _actions.handleSaveProject, icon: Icons.save, isEnabled: _currentProjectFolderPath != null)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildActionButton(label: '読み込み', onPressed: _actions.handleLoadProject, icon: Icons.folder_open)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: buttonColumnWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildSectionHeader("荷札データ"),
                          _buildActionButton(label: '荷札を撮影して抽出 (オフライン)', onPressed: _actions.handleCaptureNifudaOffline, icon: Icons.camera_alt_outlined, isEnabled: _currentProjectFolderPath != null, isEmphasized: true),
                          const SizedBox(height: 10),
                          _buildActionButton(label: '荷札リスト (${_nifudaData.length > 1 ? _nifudaData.length - 1 : 0}件)', onPressed: _actions.handleShowNifudaList, icon: Icons.list_alt_rounded, isEnabled: _nifudaData.length > 1 && _currentProjectFolderPath != null),
                          const SizedBox(height: 20),

                          _buildSectionHeader("製品リストデータ"),
                          _buildActionButton(label: 'Excelファイルから製品リストを読込', onPressed: _actions.handleLoadProductListFromExcel, icon: Icons.file_upload, isEnabled: _currentProjectFolderPath != null),
                          const SizedBox(height: 10),
                          _buildActionButton(label: '製品リスト (${_productListKariData.length > 1 ? _productListKariData.length - 1 : 0}件)', onPressed: _actions.handleShowProductList, icon: Icons.inventory_2_outlined, isEnabled: _productListKariData.length > 1 && _currentProjectFolderPath != null),
                          const SizedBox(height: 20),
                          
                           _buildSectionHeader("照合処理"),
                          _buildMatchingPatternSelector(),
                          const SizedBox(height: 10),
                          _buildActionButton(label: '照合を開始する', onPressed: _actions.handleStartMatching, icon: Icons.compare_arrows_rounded, isEnabled: _nifudaData.length > 1 && _productListKariData.length > 1 && _currentProjectFolderPath != null, isEmphasized: true),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label, required IconData icon, required VoidCallback? onPressed,
    bool isEnabled = true, bool isEmphasized = false,
  }) {
    final ButtonStyle style = isEmphasized
        ? ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white)
        : ElevatedButton.styleFrom(backgroundColor: Colors.indigo[50], foregroundColor: Colors.indigo[700]);
              
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label, textAlign: TextAlign.center),
      onPressed: _isLoading ? null : (isEnabled ? onPressed : null),
      style: style.copyWith(minimumSize: MaterialStateProperty.all(const Size(double.infinity, 48))),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo[800])),
    );
  }

  Widget _buildMatchingPatternSelector() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: Colors.green.shade200)
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedMatchingPattern,
          items: _matchingPatterns.map((String pattern) {
            return DropdownMenuItem<String>(
              value: pattern,
              child: Text('照合パターン: $pattern', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600)),
            );
          }).toList(),
          onChanged: _isLoading ? null : (String? newValue) => setState(() => _selectedMatchingPattern = newValue ?? _selectedMatchingPattern),
          icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.green[700]),
          isDense: true,
          isExpanded: true,
        ),
      ),
    );
  }
}