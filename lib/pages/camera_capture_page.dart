import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shogo_app/widgets/custom_snackbar.dart';

class CameraCapturePage extends StatefulWidget {
  final String overlayText;
  final String projectFolderPath;

  const CameraCapturePage({
    super.key,
    required this.overlayText,
    required this.projectFolderPath,
  });

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isCameraInitialized = false;
  bool _isProcessingImage = false;
  
  final List<Uint8List> _capturedImages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      _controller = CameraController(backCamera, ResolutionPreset.high, enableAudio: false);
      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
      
      if (mounted) setState(() => _isCameraInitialized = true);

    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _takeAndProcessImage() async {
    if (!_isCameraInitialized || _controller == null || _controller!.value.isTakingPicture || _isProcessingImage) return;
    
    setState(() => _isProcessingImage = true);

    try {
      final XFile imageFile = await _controller!.takePicture();
      final bytesForProcessing = await imageFile.readAsBytes();

      _capturedImages.add(bytesForProcessing);
      setState(() {});
      showCustomSnackBar(context, '${_capturedImages.length} 枚目の画像をキャプチャしました。', showAtTop: true);

    } catch (e) {
      showCustomSnackBar(context, '撮影または処理に失敗: $e', isError: true, showAtTop: true);
    } finally {
      if(mounted) setState(() => _isProcessingImage = false);
    }
  }

  void _finishCapturingAndPop() {
    Navigator.pop(context, _capturedImages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('荷札の連続撮影 (${_capturedImages.length} 枚)')),
      body: _isCameraInitialized && _controller != null
          ? CameraPreview(_controller!)
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: Container(
        color: Colors.black.withOpacity(0.5),
        padding: const EdgeInsets.symmetric(horizontal:16.0, vertical: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.camera),
              label: const Text('撮影'),
              onPressed: _isProcessingImage ? null : _takeAndProcessImage,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('終了'),
              onPressed: _capturedImages.isEmpty ? null : _finishCapturingAndPop,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
            ),
          ],
        ),
      ),
    );
  }
}