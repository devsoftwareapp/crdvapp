import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class ToolsScreen extends StatelessWidget {
  final VoidCallback onPickFile;

  const ToolsScreen({
    super.key, 
    required this.onPickFile,
  });

  void _openToolWebView(BuildContext context, String toolName, String htmlFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ToolWebViewScreen(
          toolName: toolName,
          htmlFile: htmlFile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = [
      // SOL TARAF - PDF İşlemleri
      {
        'icon': Icons.merge,
        'name': 'PDF\nBirleştirme',
        'color': const Color(0xFFFFEBEE),
        'onTap': () => _openToolWebView(context, 'PDF Birleştirme', 'birlestirme.html')
      },
      {
        'icon': Icons.edit,
        'name': 'PDF\nİmzala',
        'color': const Color(0xFFE8F5E8),
        'onTap': () => _openToolWebView(context, 'PDF İmzala', 'imza.html')
      },
      {
        'icon': Icons.photo_library,
        'name': 'Resimden\nPDF\'ye',
        'color': const Color(0xFFE3F2FD),
        'onTap': () => _openToolWebView(context, 'Resimden PDF\'ye', 'res_pdf.html')
      },
      {
        'icon': Icons.layers,
        'name': 'PDF Sayfalarını\nOrganize et',
        'color': const Color(0xFFFFF3E0),
        'onTap': () => _openToolWebView(context, 'PDF Sayfalarını Organize et', 'organize.html')
      },

      // SAĞ TARAF - Diğer Araçlar
      {
        'icon': Icons.volume_up,
        'name': 'Sesli\nOkuma',
        'color': const Color(0xFFF3E5F5),
        'onTap': () => _openToolWebView(context, 'Sesli Okuma', 'sesli_okuma.html')
      },
      {
        'icon': Icons.text_fields,
        'name': 'OCR\nMetin Çıkarma',
        'color': const Color(0xFFE0F2F1),
        'onTap': () => _openToolWebView(context, 'OCR Metin Çıkarma', 'ocr.html')
      },
      {
        'icon': Icons.picture_as_pdf,
        'name': 'PDF\'den\nResme',
        'color': const Color(0xFFFCE4EC),
        'onTap': () => _openToolWebView(context, 'PDF\'den Resme', 'pdf_res.html')
      },
      {
        'icon': Icons.add_remove,
        'name': 'PDF Sayfa\nEkle & Çıkar',
        'color': const Color(0xFFE8EAF6),
        'onTap': () => _openToolWebView(context, 'PDF Sayfa Ekle & Çıkar', 'ekle_cikar.html')
      },
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: tools.length,
      itemBuilder: (context, index) {
        final tool = tools[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: tool['onTap'] as Function(),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: tool['color'] as Color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(tool['icon'] as IconData, color: const Color(0xFFD32F2F), size: 30),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tool['name'] as String,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14, 
                      fontWeight: FontWeight.w600, 
                      color: Color(0xFFD32F2F),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ToolWebViewScreen extends StatefulWidget {
  final String toolName;
  final String htmlFile;

  const ToolWebViewScreen({
    super.key,
    required this.toolName,
    required this.htmlFile,
  });

  @override
  State<ToolWebViewScreen> createState() => _ToolWebViewScreenState();
}

class _ToolWebViewScreenState extends State<ToolWebViewScreen> {
  InAppWebViewController? _controller;
  bool _isLoading = true;

  String _getWebViewUrl() {
    return 'file:///android_asset/flutter_assets/assets/web/${widget.htmlFile}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toolName),
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_getWebViewUrl())),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              supportZoom: true,
              clearCache: true,
              cacheMode: CacheMode.LOAD_DEFAULT,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              print('🛠️ ${widget.toolName} WebView created: ${_getWebViewUrl()}');
            },
            onLoadStart: (controller, url) {
              print('🛠️ Loading started: $url');
              setState(() {
                _isLoading = true;
              });
            },
            onLoadStop: (controller, url) {
              print('✅ ${widget.toolName} loaded: $url');
              setState(() {
                _isLoading = false;
              });
            },
            onLoadError: (controller, url, code, message) {
              print('❌ ${widget.toolName} load error: $message (code: $code)');
              setState(() {
                _isLoading = false;
              });
            },
          ),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFFD32F2F)),
                  SizedBox(height: 20),
                  Text(
                    'Araç Yükleniyor...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
