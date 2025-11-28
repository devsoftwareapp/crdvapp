// lib/tools.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'l10n/app_localizations.dart';

class ToolsPage extends StatefulWidget {
  final bool dark;

  const ToolsPage({super.key, required this.dark});

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.dark ? Colors.grey[900] : Colors.grey[100],
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildToolCard(
            AppLocalizations.of(context).translate('merge_pdf'),
            AppLocalizations.of(context).translate('merge_pdf_description'),
            Icons.merge,
            'merge.html',
          ),
          _buildToolCard(
            AppLocalizations.of(context).translate('edit_pages'),
            AppLocalizations.of(context).translate('edit_pages_description'),
            Icons.edit_document,
            'reorder_subtraction.html',
          ),
          _buildToolCard(
            AppLocalizations.of(context).translate('extract_text'),
            AppLocalizations.of(context).translate('extract_text_description'),
            Icons.text_fields,
            'ocr.html',
          ),
          _buildToolCard(
            AppLocalizations.of(context).translate('split_pdf'),
            AppLocalizations.of(context).translate('split_pdf_description'),
            Icons.call_split,
            'split.html',
          ),
          _buildToolCard(
            AppLocalizations.of(context).translate('compress_pdf'),
            AppLocalizations.of(context).translate('compress_pdf_description'),
            Icons.compress,
            'compress.html',
          ),
          _buildToolCard(
            AppLocalizations.of(context).translate('pdf_to_image'),
            AppLocalizations.of(context).translate('pdf_to_image_description'),
            Icons.image,
            'pdf_to_photo.html',
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
      String title, String subtitle, IconData icon, String htmlFile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final hasPermission = await _checkAllFilesAccessPermission();
          if (hasPermission) {
            _openToolPage(title, htmlFile);
          } else {
            await _showAllFilesAccessDialog(title, htmlFile);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: widget.dark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.dark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _checkAllFilesAccessPermission() async {
    final status = await Permission.manageExternalStorage.status;
    return status.isGranted;
  }

  Future<void> _showAllFilesAccessDialog(String title, String htmlFile) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Column(
          children: [
            Icon(Icons.folder_open, size: 48, color: Colors.red),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context).translate('permission_required'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Text(
          AppLocalizations.of(context).translate('permission_description'),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              final result = await Permission.manageExternalStorage.request();
              if (result.isGranted) _openToolPage(title, htmlFile);
            },
            child: Text(AppLocalizations.of(context).translate('allow')),
          ),
        ],
      ),
    );
  }

  void _openToolPage(String title, String htmlFile) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ToolWebView(
          toolName: title,
          htmlFile: htmlFile,
          dark: widget.dark,
        ),
      ),
    );
  }
}

class ToolWebView extends StatefulWidget {
  final String toolName;
  final String htmlFile;
  final bool dark;

  const ToolWebView({
    super.key,
    required this.toolName,
    required this.htmlFile,
    required this.dark,
  });

  @override
  State<ToolWebView> createState() => _ToolWebViewState();
}

class _ToolWebViewState extends State<ToolWebView> {
  InAppWebViewController? _controller;
  Directory? _pdfReaderManagerDir;

  @override
  void initState() {
    super.initState();
    _initializeDirectory();
  }

  Future<void> _initializeDirectory() async {
    try {
      bool hasPermission = await Permission.manageExternalStorage.isGranted;

      if (hasPermission) {
        final documentsDir = Directory('/storage/emulated/0/Documents');
        if (!await documentsDir.exists()) {
          await documentsDir.create(recursive: true);
          print('📁 Documents folder created.');
        }

        final target = Directory('${documentsDir.path}/pdfreadermanager');
        if (!await target.exists()) {
          await target.create(recursive: true);
          print('📁 pdfreadermanager folder created.');
        }

        _pdfReaderManagerDir = target;
      } else {
        final appDir = await getApplicationDocumentsDirectory();
        _pdfReaderManagerDir = Directory('${appDir.path}/pdfreadermanager');
        if (!await _pdfReaderManagerDir!.exists()) {
          await _pdfReaderManagerDir!.create(recursive: true);
        }
      }

      print('📂 Directory used: ${_pdfReaderManagerDir!.path}');
    } catch (e) {
      print('Folder creation error: $e');
    }
  }

  Future<void> _saveFile(String fileName, String base64Data) async {
    if (_pdfReaderManagerDir == null) await _initializeDirectory();

    try {
      // Base64 verisini temizle
      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:.*?base64,'), '');
      final bytes = base64.decode(cleanBase64);

      // Uygun dosya uzantısını belirle
      String extension = '';
      if (base64Data.contains('application/pdf')) {
        extension = '.pdf';
      } else if (base64Data.contains('image/png')) {
        extension = '.png';
      } else if (base64Data.contains('image/jpeg')) {
        extension = '.jpg';
      } else if (base64Data.contains('text/plain')) {
        extension = '.txt';
      }

      // Uzantı yoksa ekle
      if (!fileName.contains('.')) fileName += extension;

      final file = File('${_pdfReaderManagerDir!.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $fileName ${AppLocalizations.of(context).translate('saved_successfully')}\n${AppLocalizations.of(context).translate('location')}: ${file.path}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('File save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ ${AppLocalizations.of(context).translate('file_save_error')}: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // PDF → Görsel için özel kaydetme fonksiyonu
  Future<void> _saveImage(String fileName, String base64Data) async {
    if (_pdfReaderManagerDir == null) await _initializeDirectory();

    try {
      // Base64 verisini temizle
      final cleanBase64 = base64Data.replaceFirst(RegExp(r'^data:.*?base64,'), '');
      final bytes = base64.decode(cleanBase64);

      final file = File('${_pdfReaderManagerDir!.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $fileName ${AppLocalizations.of(context).translate('saved_successfully')}\n${AppLocalizations.of(context).translate('location')}: ${file.path}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      print('Image save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ ${AppLocalizations.of(context).translate('image_save_error')}: $e',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.toolName),
        backgroundColor: widget.dark ? Colors.black : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(
            'file:///android_asset/flutter_assets/assets/${widget.htmlFile}?dark=${widget.dark}',
          ),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowFileAccess: true,
          allowFileAccessFromFileURLs: true,
          allowUniversalAccessFromFileURLs: true,
          supportZoom: true,
          useHybridComposition: true,
        ),
        onWebViewCreated: (controller) {
          _controller = controller;

          // Genel dosya kaydetme handler'ı
          controller.addJavaScriptHandler(
            handlerName: 'saveFile',
            callback: (args) async {
              if (args.length >= 2) {
                final name = args[0] as String;
                final data = args[1] as String;
                await _saveFile(name, data);
              }
              return {'success': true};
            },
          );

          // PDF → Görsel için özel handler
          controller.addJavaScriptHandler(
            handlerName: 'saveImage',
            callback: (args) async {
              if (args.length >= 2) {
                final name = args[0] as String;
                final data = args[1] as String;
                await _saveImage(name, data);
              }
              return {'success': true};
            },
          );
        },
      ),
    );
  }
}
