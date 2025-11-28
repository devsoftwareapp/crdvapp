// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';

// Intent handling için
final MethodChannel _intentChannel = MethodChannel('app.channel.shared/data');
final MethodChannel _pdfViewerChannel = MethodChannel('pdf_viewer_channel');

// Initial intent'i almak için fonksiyon
Future<Map<String, dynamic>?> _getInitialIntent() async {
  try {
    final intentData = await _intentChannel.invokeMethod('getInitialIntent');
    return intentData != null ? Map<String, dynamic>.from(intentData) : null;
  } catch (e) {
    print('Intent error: $e');
    return null;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  
  final initialIntent = await _getInitialIntent();
  
  runApp(PdfManagerApp(initialIntent: initialIntent));
}

class PdfManagerApp extends StatelessWidget {
  final Map<String, dynamic>? initialIntent;

  const PdfManagerApp({super.key, this.initialIntent});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Color(0xFF1a237e), // Lacivert
        scaffoldBackgroundColor: Color(0xFFF9F9F9),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: HomePage(initialIntent: initialIntent),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? initialIntent;

  const HomePage({super.key, this.initialIntent});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<String> _pdfFiles = [];
  bool _isLoading = false;
  bool _permissionGranted = false;
  int _currentTabIndex = 0;
  int _currentHomeTabIndex = 0;
  late TabController _tabController;
  bool _isFabOpen = false;
  bool _isDrawerOpen = false;

  // Tab başlıkları
  final List<String> _tabTitles = ['Ana Sayfa', 'Araçlar', 'Dosyalar'];
  final List<String> _homeTabTitles = ['Cihazda', 'Son Kullanılanlar', 'Favoriler'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _checkPermission();
    
    // Intent listener'ı kur
    _intentChannel.setMethodCallHandler(_handleIntentMethodCall);
    
    // Intent'i işle - GECİKMELİ olarak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialIntent();
    });
  }

  void _handleTabChange() {
    setState(() {
      _currentTabIndex = _tabController.index;
    });
  }

  // Intent method call handler
  Future<dynamic> _handleIntentMethodCall(MethodCall call) async {
    print('📱 Method call received: ${call.method}');
    
    if (call.method == 'onNewIntent') {
      final intentData = Map<String, dynamic>.from(call.arguments);
      print('🔄 New intent received: $intentData');
      _processExternalPdfIntent(intentData);
    }
    
    return null;
  }

  // External intent işleme
  void _handleInitialIntent() {
    if (widget.initialIntent != null && widget.initialIntent!.isNotEmpty) {
      print('📱 Initial intent received: ${widget.initialIntent}');
      _processExternalPdfIntent(widget.initialIntent!);
    }
  }

  // External intent işleme
  void _processExternalPdfIntent(Map<String, dynamic> intentData) {
    final action = intentData['action'];
    final data = intentData['data'];
    final uri = intentData['uri'];
    
    print('📄 Processing EXTERNAL PDF intent: $uri');
    
    try {
      if ((action == 'android.intent.action.VIEW' || action == 'android.intent.action.SEND') && uri != null) {
        print('🎯 Opening external PDF: $uri');
        _openExternalPdf(uri);
      }
    } catch (e) {
      print('💥 External PDF intent processing error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ PDF açılırken hata: $e')),
        );
      }
    }
  }

  // External PDF açma
  void _openExternalPdf(String uri) async {
    try {
      String filePath = uri;
      
      // content:// URI ise file path'e çevir
      if (uri.startsWith('content://')) {
        print('🔄 Converting content URI to file path: $uri');
        filePath = await _pdfViewerChannel.invokeMethod('convertContentUri', {'uri': uri});
        print('✅ Converted file path: $filePath');
      }
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            fileUri: filePath,
            fileName: _extractFileNameFromUri(uri),
          ),
        ),
      );
    } catch (e) {
      print('❌ Open external PDF error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ PDF açılırken hata: $e')),
      );
    }
  }

  // URI'den dosya adını çıkar
  String _extractFileNameFromUri(String uri) {
    try {
      final uriObj = Uri.parse(uri);
      final segments = uriObj.pathSegments;
      if (segments.isNotEmpty) {
        String fileName = segments.last;
        if (fileName.contains('?')) {
          fileName = fileName.split('?').first;
        }
        if (!fileName.toLowerCase().endsWith('.pdf')) {
          fileName = '$fileName.pdf';
        }
        return fileName;
      }
    } catch (e) {
      print('Error parsing URI: $e');
    }
    return 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
  }

  Future<void> _checkPermission() async {
    Permission permission = await _getRequiredPermission();
    
    var status = await permission.status;
    setState(() {
      _permissionGranted = status.isGranted;
    });
    
    if (_permissionGranted) {
      _scanDeviceForPdfs();
    }
  }

  Future<Permission> _getRequiredPermission() async {
    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      return Permission.manageExternalStorage;
    }
    return Permission.storage;
  }

  Future<void> _requestPermission() async {
    Permission permission = await _getRequiredPermission();
    
    var status = await permission.request();
    setState(() {
      _permissionGranted = status.isGranted;
    });
    
    if (status.isGranted) {
      _scanDeviceForPdfs();
    } else if (status.isPermanentlyDenied) {
      _showPermissionDialog();
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dosya Erişim İzni Gerekli'),
        content: const Text('Tüm PDF dosyalarını listelemek için dosya erişim izni gerekiyor. Ayarlardan izin verebilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Ayarlara Git'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanDeviceForPdfs() async {
    setState(() {
      _isLoading = true;
      _pdfFiles.clear();
    });

    try {
      // Android'de yaygın PDF klasörleri
      final commonPaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/DCIM',
        '/storage/emulated/0/Pictures',
        (await getExternalStorageDirectory())?.path,
      ];

      for (var path in commonPaths) {
        if (path != null) {
          await _scanDirectory(path);
        }
      }
    } catch (e) {
      print('Scan error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _scanDirectory(String dirPath) async {
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final entities = dir.listSync(recursive: true);
        
        for (var entity in entities) {
          if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
            if (!_pdfFiles.contains(entity.path)) {
              setState(() {
                _pdfFiles.add(entity.path);
              });
            }
          }
        }
      }
    } catch (e) {
      print('Directory scan error for $dirPath: $e');
    }
  }

  void _openViewer(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dosya bulunamadı: ${p.basename(path)}')),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            file: file,
            fileName: p.basename(path),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF açılırken hata: $e')),
      );
    }
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
  }

  void _toggleDrawer() {
    setState(() {
      _isDrawerOpen = !_isDrawerOpen;
    });
  }

  Widget _buildHomeTabContent() {
    switch (_currentHomeTabIndex) {
      case 0: // Cihazda
        if (!_permissionGranted) {
          return _buildPermissionRequest();
        }
        if (_isLoading) {
          return _buildLoadingState();
        }
        if (_pdfFiles.isEmpty) {
          return _buildEmptyState();
        }
        return _buildPdfList();
      case 1: // Son Kullanılanlar
        return _buildRecentFiles();
      case 2: // Favoriler
        return _buildFavorites();
      default:
        return Container();
    }
  }

  Widget _buildPermissionRequest() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Dosyalarınıza Erişim İzni Verin',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Lütfen dosyalarınıza erişim izni verin\nAyarlar\'dan erişin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: _requestPermission,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1a237e),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              child: Text('Tüm Dosya Erişim İzni Ver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1a237e)),
          SizedBox(height: 16),
          Text('PDF dosyaları taranıyor...'),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'PDF dosyası bulunamadı',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _scanDeviceForPdfs,
            child: Text('Yeniden Tara'),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfList() {
    return ListView.builder(
      itemCount: _pdfFiles.length,
      itemBuilder: (_, i) => ListTile(
        leading: Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(p.basename(_pdfFiles[i])),
        subtitle: Text(_pdfFiles[i]),
        onTap: () => _openViewer(_pdfFiles[i]),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleFileAction(value, _pdfFiles[i]),
          itemBuilder: (BuildContext context) => [
            PopupMenuItem(value: 'favorite', child: Text('Favorilere Ekle')),
            PopupMenuItem(value: 'share', child: Text('Paylaş')),
            PopupMenuItem(value: 'print', child: Text('Yazdır')),
            PopupMenuItem(value: 'copy', child: Text('Kopyala')),
            PopupMenuItem(value: 'rename', child: Text('Yeniden Adlandır')),
          ],
        ),
      ),
    );
  }

  void _handleFileAction(String action, String filePath) {
    switch (action) {
      case 'favorite':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Favorilere eklendi')));
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paylaşılıyor...')));
        break;
      case 'print':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yazdırılıyor...')));
        break;
      case 'copy':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kopyalanıyor...')));
        break;
      case 'rename':
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Yeniden adlandırılıyor...')));
        break;
    }
  }

  Widget _buildRecentFiles() {
    return ListView(
      children: [
        _buildFileItem(
          'Welcome.pdf',
          'PDF • Demo Dosyası',
          Icons.picture_as_pdf,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildFavorites() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Henüz favori dosyanız yok',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Beğendiğiniz dosyaları yıldız simgesine tıklayarak\nfavorilere ekleyebilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(String title, String subtitle, IconData icon, Color color) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 50,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
          color: Colors.white,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleFileAction(value, title),
        itemBuilder: (BuildContext context) => [
          PopupMenuItem(value: 'favorite', child: Text('Favorilere Ekle')),
          PopupMenuItem(value: 'share', child: Text('Paylaş')),
          PopupMenuItem(value: 'print', child: Text('Yazdır')),
          PopupMenuItem(value: 'copy', child: Text('Kopyala')),
          PopupMenuItem(value: 'rename', child: Text('Yeniden Adlandır')),
        ],
      ),
    );
  }

  Widget _buildToolsTab() {
    final tools = [
      {'icon': Icons.edit, 'name': 'PDF\'yi Düzenle', 'color': Color(0xFFFFF0F0), 'iconColor': Color(0xFFE31C1C)},
      {'icon': Icons.volume_up, 'name': 'Sesli okuma', 'color': Color(0xFFF0F7FF), 'iconColor': Color(0xFF1a237e)},
      {'icon': Icons.edit_document, 'name': 'PDF\'yi Doldur & İmzala', 'color': Color(0xFFF6F0FF), 'iconColor': Color(0xFF8E24AA)},
      {'icon': Icons.picture_as_pdf, 'name': 'PDF Oluştur', 'color': Color(0xFFFFF0F0), 'iconColor': Color(0xFFD32F2F)},
      {'icon': Icons.layers, 'name': 'Sayfaları organize et', 'color': Color(0xFFF0FFF4), 'iconColor': Color(0xFF2E7D32)},
      {'icon': Icons.merge, 'name': 'Dosyaları birleştirme', 'color': Color(0xFFF3F4FF), 'iconColor': Color(0xFF3F51B5)},
    ];

    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tool['name']}'))),
            child: Container(
              padding: EdgeInsets.all(16),
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
                    child: Icon(tool['icon'] as IconData, color: tool['iconColor'] as Color, size: 30),
                  ),
                  SizedBox(height: 12),
                  Text(
                    tool['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

  Widget _buildFilesTab() {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Dosyalar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        ),
        
        // Bu aygıtta
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Bu aygıtta', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildCloudItem('Fotoğraflar', Icons.photo_library, true),
        
        // Bulut Depolama
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('Bulut Depolama', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildCloudItem('Google Drive', 'assets/icon/drive.png', false),
        _buildCloudItem('OneDrive', 'assets/icon/onedrive.png', false),
        _buildCloudItem('Dropbox', 'assets/icon/dropbox.png', false),
        
        // E-posta Entegrasyonu
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('E-posta Entegrasyonu', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildGmailItem(),
        
        // Daha fazla dosya
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: _buildCloudItem('Daha fazla dosyaya göz atın', Icons.folder_open, true),
        ),
      ],
    );
  }

  Widget _buildCloudItem(String title, dynamic icon, bool isIcon) {
    return ListTile(
      leading: isIcon 
          ? Icon(icon as IconData, size: 24, color: Colors.grey)
          : Image.asset(icon as String, width: 24, height: 24),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
      trailing: Icon(Icons.add, color: Colors.grey),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title ekleniyor'))),
    );
  }

  Widget _buildGmailItem() {
    return ListTile(
      leading: Image.asset('assets/icon/gmail.png', width: 24, height: 24),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('E-postalardaki PDF\'ler', style: TextStyle(fontWeight: FontWeight.w500)),
          Text('Gmail', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: Icon(Icons.add, color: Colors.grey),
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gmail PDF\'leri açılıyor'))),
    );
  }

  Widget _buildFabMenu() {
    if (_currentTabIndex != 0) return SizedBox.shrink();

    return Stack(
      children: [
        if (_isFabOpen) ...[
          Positioned(
            bottom: 70,
            right: 0,
            child: Column(
              children: [
                _buildSubFabItem('Tara', Icons.document_scanner),
                SizedBox(height: 12),
                _buildSubFabItem('HTML/Web', Icons.html),
                SizedBox(height: 12),
                _buildSubFabItem('Görsel', Icons.image),
              ],
            ),
          ),
        ],
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: _isFabOpen ? Color(0xFFD32F2F) : Color(0xFF1a237e),
            onPressed: _toggleFab,
            child: AnimatedRotation(
              turns: _isFabOpen ? 0.125 : 0,
              duration: Duration(milliseconds: 300),
              child: Icon(_isFabOpen ? Icons.close : Icons.add, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubFabItem(String text, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Color(0xFFF0F7FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, size: 20, color: Color(0xFF1a237e)),
          ),
          SizedBox(width: 8),
          Text(text, style: TextStyle(fontWeight: FontWeight.w500)),
          SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(0xFF1a237e),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('DS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Dev Software', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('PDF Reader ücretsiz sürümü', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(Icons.cloud, 'Bulut Depolama Alanı Yönet'),
          _buildDrawerItem(Icons.settings, 'Tercihler'),
          _buildDrawerItem(Icons.help, 'Yardım ve Destek'),
          Divider(),
          _buildDrawerSubItem('Diller'),
          _buildDrawerSubItem('Gizlilik'),
          _buildDrawerSubItem('PDF Reader Hakkında'),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title) {
    return ListTile(
      leading: Icon(icon, size: 24, color: Colors.grey),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(title)));
      },
    );
  }

  Widget _buildDrawerSubItem(String title) {
    return ListTile(
      title: Text(title, style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(title)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Image.asset('assets/icon/logo.png', width: 32, height: 32),
              SizedBox(width: 12),
              Text(_tabTitles[_currentTabIndex]),
            ],
          ),
          actions: [
            if (_currentTabIndex == 0) ...[
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Arama'))),
              ),
            ],
            IconButton(
              icon: Icon(Icons.notifications),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bildirimler'))),
            ),
            IconButton(
              icon: CircleAvatar(
                backgroundColor: Color(0xFF1a237e),
                child: Text('DS', style: TextStyle(color: Colors.white, fontSize: 12)),
                radius: 16,
              ),
              onPressed: _toggleDrawer,
            ),
          ],
          bottom: _currentTabIndex == 0 
              ? TabBar(
                  controller: TabController(
                    length: 3,
                    vsync: this,
                    initialIndex: _currentHomeTabIndex,
                  ),
                  onTap: (index) => setState(() => _currentHomeTabIndex = index),
                  tabs: _homeTabTitles.map((title) => Tab(text: title)).toList(),
                )
              : null,
        ),
        drawer: _buildDrawer(),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildHomeTabContent(),
            _buildToolsTab(),
            _buildFilesTab(),
          ],
        ),
        floatingActionButton: _buildFabMenu(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            _tabController.animateTo(index);
            setState(() => _currentTabIndex = index);
          },
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.build),
              label: 'Araçlar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder),
              label: 'Dosyalar',
            ),
          ],
        ),
      ),
    );
  }
}

class ViewerScreen extends StatefulWidget {
  final File? file;
  final String? fileUri;
  final String fileName;

  const ViewerScreen({
    super.key,
    this.file,
    this.fileUri,
    required this.fileName,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _controller;
  bool _loaded = false;

  String _viewerUrl() {
    try {
      String fileUri;
      
      if (widget.fileUri != null) {
        // External intent ile gelen URI
        fileUri = widget.fileUri!;
      } else if (widget.file != null) {
        // Internal dosya
        fileUri = Uri.file(widget.file!.path).toString();
      } else {
        throw Exception('No file or URI provided');
      }
      
      final encodedFileUri = Uri.encodeComponent(fileUri);
      final viewerUrl = 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=$encodedFileUri';
      
      print('🌐 Viewer URL: $viewerUrl');
      return viewerUrl;
    } catch (e) {
      print('❌ URI creation error: $e');
      return 'file:///android_asset/flutter_assets/assets/web/viewer.html';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        backgroundColor: Color(0xFF1a237e),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(_viewerUrl())),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowFileAccess: true,
              allowFileAccessFromFileURLs: true,
              allowUniversalAccessFromFileURLs: true,
              supportZoom: true,
            ),
            onLoadStop: (controller, url) {
              setState(() => _loaded = true);
            },
          ),
          if (!_loaded)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1a237e)),
                  SizedBox(height: 20),
                  Text('PDF Yükleniyor...'),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
