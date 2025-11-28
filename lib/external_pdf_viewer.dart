// lib/external_pdf_viewer.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class ExternalPdfViewer extends StatefulWidget {
  final String fileUri;
  final String fileName;
  final bool dark;
  final String locale;

  const ExternalPdfViewer({
    super.key,
    required this.fileUri,
    required this.fileName,
    required this.dark,
    required this.locale,
  });

  @override
  State<ExternalPdfViewer> createState() => _ExternalPdfViewerState();
}

class _ExternalPdfViewerState extends State<ExternalPdfViewer> {
  InAppWebViewController? _controller;
  bool _loaded = false;
  double _progress = 0;
  String? _pdfBase64Data;
  bool _isProcessing = false;
  bool _webViewInitialized = false;

  final MethodChannel _pdfChannel = MethodChannel('pdf_viewer_channel');

  @override
  void initState() {
    super.initState();
    _processPdf();
  }

  Future<void> _processPdf() async {
    try {
      print('🔧 Processing PDF: ${widget.fileUri}');
      
      setState(() {
        _isProcessing = true;
      });

      Uint8List pdfBytes;

      if (widget.fileUri.startsWith('content://')) {
        final result = await _pdfChannel.invokeMethod('readContentUri', {
          'uri': widget.fileUri
        });
        
        if (result != null && result is Uint8List) {
          pdfBytes = result;
          print('✅ Content URI converted to bytes, length: ${pdfBytes.length}');
        } else {
          throw Exception('Content URI could not be read');
        }
      } else if (widget.fileUri.startsWith('file://')) {
        final filePath = widget.fileUri.replaceFirst('file://', '');
        final file = File(filePath);
        if (await file.exists()) {
          pdfBytes = await file.readAsBytes();
          print('✅ File read as bytes, length: ${pdfBytes.length}');
        } else {
          throw Exception('File not found: $filePath');
        }
      } else {
        final file = File(widget.fileUri);
        if (await file.exists()) {
          pdfBytes = await file.readAsBytes();
          print('✅ File read as bytes, length: ${pdfBytes.length}');
        } else {
          throw Exception('File not found: ${widget.fileUri}');
        }
      }

      final base64 = base64Encode(pdfBytes);
      _pdfBase64Data = base64; // Sadece base64, data URI değil
      
      print('✅ PDF converted to Base64, length: ${_pdfBase64Data!.length}');
      
      setState(() {
        _isProcessing = false;
      });
      
    } catch (e) {
      print('❌ PDF processing error: $e');
      setState(() {
        _isProcessing = false;
        _loaded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ PDF processing error: $e')),
      );
    }
  }

  String _getPdfJsHtml() {
    if (_pdfBase64Data == null) return _getErrorHtml('Preparing PDF...');

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=yes" />
  <title>PDF Viewer</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }
    
    body {
      margin: 0;
      background: #1a1a1a;
      overflow: hidden;
      -webkit-user-select: none;
      user-select: none;
      touch-action: pan-y pinch-zoom;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      height: 100vh;
      position: fixed;
      width: 100%;
    }
    
    #viewerContainer {
      width: 100%;
      height: 100vh;
      overflow-y: auto;
      overflow-x: hidden;
      -webkit-overflow-scrolling: touch;
      padding: 10px 0;
    }
    
    .page {
      background: white;
      margin: 12px auto;
      border-radius: 12px;
      box-shadow: 0 8px 32px rgba(0,0,0,0.3);
      position: relative;
      max-width: 95%;
      transition: transform 0.2s ease;
    }
    
    .page canvas {
      display: block;
      width: 100%;
      height: auto;
      border-radius: 12px;
    }
    
    .loading {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 100vh;
      flex-direction: column;
      color: white;
      background: #1a1a1a;
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      z-index: 1000;
    }
    
    .spinner {
      width: 50px;
      height: 50px;
      border: 4px solid #333;
      border-top: 4px solid #e74c3c;
      border-radius: 50%;
      animation: spin 1s linear infinite;
      margin-bottom: 20px;
    }
    
    .progress-container {
      width: 80%;
      max-width: 280px;
      margin: 20px 0;
    }
    
    .progress-text {
      color: #ccc;
      margin-bottom: 12px;
      font-size: 16px;
      font-weight: 500;
      text-align: center;
    }
    
    .progress-bar {
      width: 100%;
      height: 6px;
      background: #333;
      border-radius: 3px;
      overflow: hidden;
    }
    
    .progress {
      height: 100%;
      background: #e74c3c;
      transition: width 0.3s ease;
      border-radius: 3px;
    }
    
    .error {
      color: #e74c3c;
      text-align: center;
      padding: 30px;
      background: #1a1a1a;
      height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-direction: column;
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
    }
    
    .controls {
      position: fixed;
      bottom: 20px;
      right: 20px;
      display: flex;
      flex-direction: column;
      gap: 12px;
      z-index: 1000;
    }
    
    .control-btn {
      width: 56px;
      height: 56px;
      border-radius: 28px;
      background: rgba(44, 62, 80, 0.95);
      color: white;
      border: none;
      font-size: 20px;
      font-weight: bold;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s ease;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
    }
    
    .control-btn:active {
      transform: scale(0.92);
      background: #2c3e50;
    }
    
    .control-btn.primary {
      background: #e74c3c;
    }
    
    .control-btn.primary:active {
      background: #c0392b;
    }
    
    .page-indicator {
      position: fixed;
      top: 20px;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(44, 62, 80, 0.95);
      color: white;
      padding: 12px 20px;
      border-radius: 25px;
      font-size: 14px;
      font-weight: 600;
      z-index: 1000;
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
      box-shadow: 0 4px 20px rgba(0,0,0,0.3);
    }
    
    .nav-controls {
      position: fixed;
      bottom: 20px;
      left: 20px;
      display: flex;
      gap: 12px;
      z-index: 1000;
    }
    
    .nav-btn {
      width: 56px;
      height: 56px;
      border-radius: 28px;
      background: rgba(44, 62, 80, 0.95);
      color: white;
      border: none;
      font-size: 18px;
      display: flex;
      align-items: center;
      justify-content: center;
      cursor: pointer;
      transition: all 0.2s ease;
      box-shadow: 0 4px 20px rgba(0,0,0,0.4);
      backdrop-filter: blur(10px);
      -webkit-backdrop-filter: blur(10px);
    }
    
    .nav-btn:active {
      transform: scale(0.92);
      background: #2c3e50;
    }
    
    .nav-btn:disabled {
      opacity: 0.5;
      transform: none;
    }
    
    @keyframes spin {
      0% { transform: rotate(0deg); }
      100% { transform: rotate(360deg); }
    }
    
    /* Mobile optimizations */
    @media (max-width: 768px) {
      .page {
        margin: 8px auto;
        max-width: 98%;
      }
      
      .control-btn, .nav-btn {
        width: 52px;
        height: 52px;
      }
      
      .page-indicator {
        top: 10px;
        padding: 10px 16px;
        font-size: 13px;
      }
    }
  </style>
</head>
<body>
  <div id="loading" class="loading">
    <div class="spinner"></div>
    <div class="progress-text">Loading PDF</div>
    <div class="progress-container">
      <div class="progress-bar">
        <div id="progress" class="progress" style="width: 0%"></div>
      </div>
    </div>
    <div id="progressText" style="color: #999; margin-top: 12px; font-size: 14px;">0%</div>
  </div>
  
  <div id="viewerContainer" style="display: none;">
    <div id="viewer"></div>
  </div>
  
  <div id="pageIndicator" class="page-indicator" style="display: none;">
    Page <span id="currentPage">1</span> of <span id="totalPages">1</span>
  </div>
  
  <div class="nav-controls">
    <button id="prevBtn" class="nav-btn" onclick="previousPage()" disabled>‹</button>
    <button id="nextBtn" class="nav-btn" onclick="nextPage()" disabled>›</button>
  </div>
  
  <div class="controls">
    <button class="control-btn" onclick="zoomOut()" title="Zoom Out">−</button>
    <button class="control-btn primary" onclick="resetZoom()" title="Reset Zoom">⤢</button>
    <button class="control-btn" onclick="zoomIn()" title="Zoom In">+</button>
  </div>
  
  <div id="error" class="error" style="display: none;"></div>

  <script>
    let currentScale = 1.0;
    const minScale = 0.3;
    const maxScale = 3.0;
    const scaleStep = 0.15;
    let pdfDoc = null;
    let currentPage = 1;
    let isPdfLoaded = false;

    const pdfBase64 = '$_pdfBase64Data';

    // Load PDF.js immediately
    const script = document.createElement('script');
    script.src = 'file:///android_asset/flutter_assets/assets/pdf.min.js';
    script.onload = function() {
      pdfjsLib.GlobalWorkerOptions.workerSrc = 'file:///android_asset/flutter_assets/assets/pdf.worker.min.js';
      
      if (pdfBase64 && !isPdfLoaded) {
        loadPdf();
      }
    };
    document.head.appendChild(script);

    function loadPdf() {
      if (!pdfBase64) {
        showError('PDF data not found');
        return;
      }

      try {
        console.log('Starting PDF load...');
        
        // Convert base64 to Uint8Array
        const pdfData = Uint8Array.from(atob(pdfBase64), c => c.charCodeAt(0));
        
        const loadingTask = pdfjsLib.getDocument({ 
          data: pdfData  // Use data instead of URL for better performance
        });

        loadingTask.onProgress = function(progress) {
          const percent = Math.round((progress.loaded / progress.total) * 100);
          updateProgress(percent);
        };

        loadingTask.promise.then(function(pdf) {
          pdfDoc = pdf;
          console.log('PDF loaded successfully, pages:', pdfDoc.numPages);
          
          hideLoading();
          updatePageIndicator();
          
          // Render all pages
          renderAllPages();
          
        }).catch(function(error) {
          console.error('PDF load error:', error);
          showError('Error loading PDF: ' + error.message);
        });
        
      } catch (error) {
        console.error('PDF load error:', error);
        showError('Error loading PDF: ' + error.message);
      }
    }

    async function renderAllPages() {
      if (!pdfDoc) return;
      
      try {
        for (let i = 1; i <= pdfDoc.numPages; i++) {
          await renderPage(i);
        }
        
        setZoom(currentScale);
        isPdfLoaded = true;
        
        // Notify Flutter
        if (window.flutter_inappwebview) {
          window.flutter_inappwebview.callHandler('onLoadComplete', pdfDoc.numPages);
        }
        
      } catch (error) {
        console.error('Page render error:', error);
      }
    }

    async function renderPage(pageNum) {
      try {
        const page = await pdfDoc.getPage(pageNum);

        // Calculate scale for mobile
        const viewport = page.getViewport({ scale: 1.8 });
        const canvas = document.createElement('canvas');
        const context = canvas.getContext('2d');

        canvas.width = viewport.width;
        canvas.height = viewport.height;

        await page.render({ canvasContext: context, viewport }).promise;

        // Mobile optimized styling
        canvas.style.width = '100%';
        canvas.style.height = 'auto';
        canvas.style.maxWidth = '100%';
        canvas.style.display = 'block';

        const pageDiv = document.createElement('div');
        pageDiv.className = 'page';
        pageDiv.setAttribute('data-page', pageNum);
        pageDiv.appendChild(canvas);
        document.getElementById('viewer').appendChild(pageDiv);
        
      } catch (error) {
        console.error('Page render error:', error);
      }
    }

    // Touch events for pinch zoom
    let initialDistance = null;
    let initialScale = 1.0;

    document.getElementById('viewerContainer').addEventListener('touchstart', function(e) {
      if (e.touches.length === 2) {
        e.preventDefault();
        initialDistance = getDistance(e.touches[0], e.touches[1]);
        initialScale = currentScale;
      }
    });

    document.getElementById('viewerContainer').addEventListener('touchmove', function(e) {
      if (e.touches.length === 2) {
        e.preventDefault();
        const currentDistance = getDistance(e.touches[0], e.touches[1]);
        const scaleFactor = currentDistance / initialDistance;
        const newScale = initialScale * scaleFactor;
        
        setZoom(Math.max(minScale, Math.min(maxScale, newScale)));
      }
    });

    document.getElementById('viewerContainer').addEventListener('touchend', function(e) {
      if (e.touches.length < 2) {
        initialDistance = null;
      }
    });

    function getDistance(touch1, touch2) {
      const dx = touch1.clientX - touch2.clientX;
      const dy = touch1.clientY - touch2.clientY;
      return Math.sqrt(dx * dx + dy * dy);
    }

    function setZoom(scale) {
      currentScale = Math.max(minScale, Math.min(maxScale, scale));
      const pages = document.querySelectorAll('.page');
      pages.forEach(page => {
        page.style.transform = 'scale(' + currentScale + ')';
      });
    }

    function zoomIn() {
      setZoom(currentScale + scaleStep);
    }

    function zoomOut() {
      setZoom(currentScale - scaleStep);
    }

    function resetZoom() {
      setZoom(1.0);
    }

    function updatePageIndicator() {
      document.getElementById('currentPage').textContent = currentPage;
      document.getElementById('totalPages').textContent = pdfDoc.numPages;
      document.getElementById('pageIndicator').style.display = 'block';
      
      document.getElementById('prevBtn').disabled = currentPage <= 1;
      document.getElementById('nextBtn').disabled = currentPage >= pdfDoc.numPages;
    }

    function nextPage() {
      if (currentPage < pdfDoc.numPages) {
        currentPage++;
        scrollToPage(currentPage);
      }
    }

    function previousPage() {
      if (currentPage > 1) {
        currentPage--;
        scrollToPage(currentPage);
      }
    }

    function scrollToPage(pageNumber) {
      const pages = document.querySelectorAll('.page');
      if (pages.length >= pageNumber) {
        const targetPage = pages[pageNumber - 1];
        const container = document.getElementById('viewerContainer');
        const pageTop = targetPage.offsetTop - (container.clientHeight / 2) + (targetPage.offsetHeight / 2);
        
        container.scrollTo({
          top: pageTop,
          behavior: 'smooth'
        });
        
        updatePageIndicator();
      }
    }

    function updateProgress(percent) {
      const progressBar = document.getElementById('progress');
      const progressText = document.getElementById('progressText');
      
      if (progressBar && progressText) {
        progressBar.style.width = percent + '%';
        progressText.textContent = percent + '%';
      }
    }

    function hideLoading() {
      const loading = document.getElementById('loading');
      const viewerContainer = document.getElementById('viewerContainer');
      
      if (loading) loading.style.display = 'none';
      if (viewerContainer) viewerContainer.style.display = 'block';
    }

    function showError(message) {
      const loading = document.getElementById('loading');
      const error = document.getElementById('error');
      
      if (loading) loading.style.display = 'none';
      if (error) {
        error.style.display = 'flex';
        error.textContent = message;
      }
    }

    // Handle scroll for page detection
    let scrollTimeout;
    document.getElementById('viewerContainer').addEventListener('scroll', function() {
      clearTimeout(scrollTimeout);
      scrollTimeout = setTimeout(function() {
        const pages = document.querySelectorAll('.page');
        const container = document.getElementById('viewerContainer');
        const scrollPosition = container.scrollTop + (container.clientHeight / 3);
        
        for (let i = 0; i < pages.length; i++) {
          const page = pages[i];
          const pageTop = page.offsetTop;
          const pageBottom = pageTop + page.offsetHeight;
          
          if (scrollPosition >= pageTop && scrollPosition < pageBottom) {
            currentPage = i + 1;
            updatePageIndicator();
            break;
          }
        }
      }, 100);
    });

    // Initialize when page loads
    if (pdfBase64) {
      // PDF.js will load and then trigger loadPdf
    }
  </script>
</body>
</html>
''';
  }

  String _getErrorHtml(String message) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PDF Viewer</title>
    <style>
        body {
            margin: 0;
            padding: 0;
            background: #1a1a1a;
            color: white;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            text-align: center;
        }
        .error {
            color: #e74c3c;
            font-size: 18px;
            padding: 30px;
        }
    </style>
</head>
<body>
    <div class="error">$message</div>
</body>
</html>
''';
  }

  Future<void> _shareFile() async {
    try {
      if (widget.fileUri.startsWith('file://')) {
        final filePath = widget.fileUri.replaceFirst('file://', '');
        await Share.shareXFiles([XFile(filePath)]);
      } else if (widget.fileUri.startsWith('content://')) {
        final result = await _pdfChannel.invokeMethod('readContentUri', {
          'uri': widget.fileUri
        });
        
        if (result != null && result is Uint8List) {
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.pdf');
          await tempFile.writeAsBytes(result);
          await Share.shareXFiles([XFile(tempFile.path)]);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ This file is not suitable for sharing')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Share error: $e')),
      );
    }
  }

  Future<void> _printFile() async {
    try {
      Uint8List pdfBytes;

      if (widget.fileUri.startsWith('file://')) {
        final filePath = widget.fileUri.replaceFirst('file://', '');
        final file = File(filePath);
        if (await file.exists()) {
          pdfBytes = await file.readAsBytes();
        } else {
          throw Exception('File not found');
        }
      } else if (widget.fileUri.startsWith('content://')) {
        final result = await _pdfChannel.invokeMethod('readContentUri', {
          'uri': widget.fileUri
        });
        
        if (result != null && result is Uint8List) {
          pdfBytes = result;
        } else {
          throw Exception('Content URI could not be read');
        }
      } else {
        throw Exception('Unsupported URI format');
      }

      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Print error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _printFile,
            tooltip: 'Print',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareFile,
            tooltip: 'Share',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.red),
            const SizedBox(height: 20),
            const Text('Processing PDF...'),
            const SizedBox(height: 10),
            Text(
              widget.fileUri.startsWith('content://') ? 'Processing Content URI' : 'Reading file',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    // WebView'i sadece bir kere oluştur, FutureBuilder kaldırıldı
    return Stack(
      children: [
        InAppWebView(
          initialData: InAppWebViewInitialData(
            data: _getPdfJsHtml(),
            mimeType: 'text/html',
            encoding: 'utf-8',
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            allowFileAccess: true,
            allowFileAccessFromFileURLs: true,
            allowUniversalAccessFromFileURLs: true,
            supportZoom: true,
            useHybridComposition: true,
            clearCache: false, // Cache'i temizleme
            cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK, // Önce cache kullan
            disableVerticalScroll: false,
            disableHorizontalScroll: false,
            builtInZoomControls: false,
            displayZoomControls: false,
          ),
          onWebViewCreated: (controller) {
            _controller = controller;
            _webViewInitialized = true;
            print('✅ WebView created for PDF');
            
            controller.addJavaScriptHandler(
              handlerName: 'onProgress',
              callback: (args) {
                if (mounted) {
                  setState(() {
                    _progress = (args[0] as num).toDouble();
                  });
                }
                print('📊 PDF Loading Progress: $_progress%');
              },
            );
            
            controller.addJavaScriptHandler(
              handlerName: 'onLoadComplete',
              callback: (args) {
                if (mounted) {
                  setState(() {
                    _loaded = true;
                    _progress = 100;
                  });
                }
                final pageCount = args[0];
                print('✅ PDF loaded successfully. Pages: $pageCount');
              },
            );
          },
          onLoadStop: (controller, url) {
            print('✅ WebView loading completed');
          },
          onLoadError: (controller, url, code, message) {
            print('❌ WebView load error: $message (code: $code)');
            if (mounted) {
              setState(() {
                _loaded = true;
              });
            }
          },
        ),
        
        if (!_loaded && !_isProcessing)
          Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.red),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading PDF...',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$_progress%',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
