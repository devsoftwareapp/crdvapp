// lib/main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:open_file/open_file.dart';
import 'package:sqflite/sqflite.dart';

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
        primaryColor: Color(0xFF2196F3), // Açık mavi
        scaffoldBackgroundColor: Color(0xFFF8F9FA),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2196F3),
          elevation: 1,
          titleTextStyle: TextStyle(
            color: Color(0xFF2196F3),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: Color(0xFF2196F3)),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Color(0xFF2196F3),
          unselectedItemColor: Colors.grey,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Color(0xFF2196F3),
          unselectedLabelColor: Colors.grey,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.0, color: Color(0xFF2196F3)),
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
  List<String> _favoriteFiles = [];
  List<String> _recentFiles = [];
  bool _isLoading = false;
  bool _permissionGranted = false;
  int _currentTabIndex = 0;
  int _currentHomeTabIndex = 0;
  late TabController _tabController;
  bool _isFabOpen = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Veritabanı için
  Database? _database;

  // Tab başlıkları
  final List<String> _tabTitles = ['Ana Sayfa', 'Araçlar', 'Dosyalar'];
  final List<String> _homeTabTitles = ['Cihazda', 'Son Kullanılanlar', 'Favoriler'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _initDatabase();
    _checkPermission();
    
    // Intent listener'ı kur
    _intentChannel.setMethodCallHandler(_handleIntentMethodCall);
    
    // Intent'i işle - GECİKMELİ olarak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialIntent();
    });
  }

  Future<void> _initDatabase() async {
    _database = await openDatabase(
      'pdf_reader.db',
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE favorites (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT UNIQUE,
            added_date TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE recents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            file_path TEXT UNIQUE,
            opened_date TEXT
          )
        ''');
      },
    );
    await _loadFavorites();
    await _loadRecents();
  }

  Future<void> _loadFavorites() async {
    if (_database == null) return;
    
    final List<Map<String, dynamic>> maps = await _database!.query('favorites');
    setState(() {
      _favoriteFiles = List.generate(maps.length, (i) => maps[i]['file_path']);
    });
  }

  Future<void> _loadRecents() async {
    if (_database == null) return;
    
    final List<Map<String, dynamic>> maps = await _database!.query('recents');
    setState(() {
      _recentFiles = List.generate(maps.length, (i) => maps[i]['file_path']);
    });
  }

  Future<void> _addToFavorites(String filePath) async {
    if (_database == null) return;
    
    await _database!.insert(
      'favorites',
      {
        'file_path': filePath,
        'added_date': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _loadFavorites();
  }

  Future<void> _removeFromFavorites(String filePath) async {
    if (_database == null) return;
    
    await _database!.delete(
      'favorites',
      where: 'file_path = ?',
      whereArgs: [filePath],
    );
    await _loadFavorites();
  }

  Future<void> _addToRecents(String filePath) async {
    if (_database == null) return;
    
    await _database!.insert(
      'recents',
      {
        'file_path': filePath,
        'opened_date': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _loadRecents();
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
        title: Text('Dosya Erişim İzni Gerekli', style: TextStyle(color: Color(0xFF2196F3))),
        content: Text('Tüm PDF dosyalarını listelemek için dosya erişim izni gerekiyor. Ayarlardan izin verebilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2196F3)),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text('Ayarlara Git', style: TextStyle(color: Colors.white)),
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

  Future<void> _pickPdfFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        String filePath = result.files.single.path!;
        await _addToRecents(filePath);
        _openViewer(filePath);
      }
    } catch (e) {
      print('File pick error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya seçilirken hata: $e')),
      );
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

      await _addToRecents(path);
      
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

  Future<void> _shareFile(String filePath) async {
    try {
      await Share.shareFiles([filePath], text: 'PDF Dosyası');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım hatası: $e')),
      );
    }
  }

  Future<void> _printFile(String filePath) async {
    try {
      final file = File(filePath);
      final data = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => data);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Yazdırma hatası: $e')),
      );
    }
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
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
        return _buildPdfList(_pdfFiles);
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2196F3)),
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
                backgroundColor: Color(0xFF2196F3),
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
          CircularProgressIndicator(color: Color(0xFF2196F3)),
          SizedBox(height: 16),
          Text('PDF dosyaları taranıyor...', style: TextStyle(color: Color(0xFF2196F3))),
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
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2196F3)),
            child: Text('Yeniden Tara', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(height: 8),
          TextButton(
            onPressed: _pickPdfFile,
            child: Text('Dosya Seç', style: TextStyle(color: Color(0xFF2196F3))),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfList(List<String> files) {
    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (_, i) => _buildFileItem(files[i], false),
    );
  }

  Widget _buildFileItem(String filePath, bool isFavorite) {
    final fileName = p.basename(filePath);
    final isFavorited = _favoriteFiles.contains(filePath);

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFFE3F2FD),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.picture_as_pdf, color: Color(0xFF2196F3), size: 24),
        ),
        title: Text(fileName, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          filePath.length > 50 ? '...${filePath.substring(filePath.length - 50)}' : filePath,
          style: TextStyle(fontSize: 12, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => _openViewer(filePath),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isFavorited ? Icons.star : Icons.star_border,
                color: isFavorited ? Colors.amber : Colors.grey,
              ),
              onPressed: () {
                if (isFavorited) {
                  _removeFromFavorites(filePath);
                } else {
                  _addToFavorites(filePath);
                }
              },
            ),
            PopupMenuButton<String>(
              onSelected: (value) => _handleFileAction(value, filePath),
              itemBuilder: (BuildContext context) => [
                PopupMenuItem(value: 'share', child: Text('Paylaş')),
                PopupMenuItem(value: 'print', child: Text('Yazdır')),
                PopupMenuItem(value: 'open', child: Text('Dosyayı Aç')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleFileAction(String action, String filePath) {
    switch (action) {
      case 'share':
        _shareFile(filePath);
        break;
      case 'print':
        _printFile(filePath);
        break;
      case 'open':
        OpenFile.open(filePath);
        break;
    }
  }

  Widget _buildRecentFiles() {
    if (_recentFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz son açılan dosya yok',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'PDF dosyalarını açtıkça burada görünecekler.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _recentFiles.length,
      itemBuilder: (_, i) => _buildFileItem(_recentFiles[i], false),
    );
  }

  Widget _buildFavorites() {
    if (_favoriteFiles.isEmpty) {
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

    return ListView.builder(
      itemCount: _favoriteFiles.length,
      itemBuilder: (_, i) => _buildFileItem(_favoriteFiles[i], true),
    );
  }

  Widget _buildToolsTab() {
    final tools = [
      {
        'icon': Icons.edit, 
        'name': 'PDF Düzenle', 
        'color': Color(0xFFE3F2FD), 
        'onTap': () => _showComingSoon('PDF Düzenleme')
      },
      {
        'icon': Icons.volume_up, 
        'name': 'Sesli okuma', 
        'color': Color(0xFFE8F5E8), 
        'onTap': () => _showComingSoon('Sesli Okuma')
      },
      {
        'icon': Icons.edit_document, 
        'name': 'PDF Doldur & İmzala', 
        'color': Color(0xFFF3E5F5), 
        'onTap': () => _showComingSoon('PDF Doldur & İmzala')
      },
      {
        'icon': Icons.picture_as_pdf, 
        'name': 'PDF Oluştur', 
        'color': Color(0xFFFFEBEE), 
        'onTap': _pickPdfFile
      },
      {
        'icon': Icons.layers, 
        'name': 'Sayfaları organize et', 
        'color': Color(0xFFE8F5E8), 
        'onTap': () => _showComingSoon('Sayfa Organizasyonu')
      },
      {
        'icon': Icons.merge, 
        'name': 'Dosyaları birleştirme', 
        'color': Color(0xFFE3F2FD), 
        'onTap': () => _showComingSoon('Dosya Birleştirme')
      },
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
            onTap: tool['onTap'] as Function(),
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
                    child: Icon(tool['icon'] as IconData, color: Color(0xFF2196F3), size: 30),
                  ),
                  SizedBox(height: 12),
                  Text(
                    tool['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2196F3)),
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

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Yakında eklenecek! 🚀'),
        backgroundColor: Color(0xFF2196F3),
      ),
    );
  }

  Widget _buildFilesTab() {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Dosyalar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2196F3))),
        ),
        
        // Bu aygıtta
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Bu aygıtta', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildCloudItem('Fotoğraflar', Icons.photo_library, true, () => _showComingSoon('Fotoğraflar')),
        
        // Bulut Depolama
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('Bulut Depolama', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildCloudItem('Google Drive', 'assets/icon/drive.png', false, () => _launchCloudService('Google Drive')),
        _buildCloudItem('OneDrive', 'assets/icon/onedrive.png', false, () => _launchCloudService('OneDrive')),
        _buildCloudItem('Dropbox', 'assets/icon/dropbox.png', false, () => _launchCloudService('Dropbox')),
        
        // E-posta Entegrasyonu
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('E-posta Entegrasyonu', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildGmailItem(),
        
        // Daha fazla dosya
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: _buildCloudItem('Daha fazla dosyaya göz atın', Icons.folder_open, true, _pickPdfFile),
        ),
      ],
    );
  }

  Future<void> _launchCloudService(String service) async {
    final urls = {
      'Google Drive': 'https://drive.google.com',
      'OneDrive': 'https://onedrive.live.com',
      'Dropbox': 'https://www.dropbox.com',
    };
    
    if (urls.containsKey(service)) {
      final url = Uri.parse(urls[service]!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showComingSoon(service);
      }
    }
  }

  Widget _buildCloudItem(String title, dynamic icon, bool isIcon, Function onTap) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: isIcon 
            ? Icon(icon as IconData, size: 24, color: Color(0xFF2196F3))
            : Image.asset(icon as String, width: 24, height: 24),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.add, color: Color(0xFF2196F3)),
        onTap: () => onTap(),
      ),
    );
  }

  Widget _buildGmailItem() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Image.asset('assets/icon/gmail.png', width: 24, height: 24),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('E-postalardaki PDF\'ler', style: TextStyle(fontWeight: FontWeight.w500)),
            Text('Gmail', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Icon(Icons.add, color: Color(0xFF2196F3)),
        onTap: () => _launchCloudService('Gmail'),
      ),
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
                _buildSubFabItem('Dosya Seç', Icons.attach_file, _pickPdfFile),
                SizedBox(height: 12),
                _buildSubFabItem('Tara', Icons.document_scanner, () => _showComingSoon('Tarama')),
                SizedBox(height: 12),
                _buildSubFabItem('Görsel', Icons.image, () => _showComingSoon('Görselden PDF')),
              ],
            ),
          ),
        ],
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: _isFabOpen ? Color(0xFF1976D2) : Color(0xFF2196F3),
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

  Widget _buildSubFabItem(String text, IconData icon, Function onTap) {
    return GestureDetector(
      onTap: () {
        _toggleFab();
        onTap();
      },
      child: Container(
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
                color: Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 20, color: Color(0xFF2196F3)),
            ),
            SizedBox(width: 8),
            Text(text, style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF2196F3))),
            SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: Color(0xFF2196F3),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 24,
                    child: Text('DS', style: TextStyle(color: Color(0xFF2196F3), fontWeight: FontWeight.bold)),
                  ),
                  SizedBox(height: 12),
                  Text('Dev Software', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('PDF Reader Premium', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
          ),
          _buildDrawerItem(Icons.cloud, 'Bulut Depolama Alanı Yönet', () => _showComingSoon('Bulut Depolama')),
          _buildDrawerItem(Icons.settings, 'Tercihler', () => _showComingSoon('Tercihler')),
          _buildDrawerItem(Icons.help, 'Yardım ve Destek', () => _showComingSoon('Yardım')),
          Divider(),
          _buildDrawerSubItem('Diller', () => _showComingSoon('Dil Seçenekleri')),
          _buildDrawerSubItem('Gizlilik', () => _showComingSoon('Gizlilik')),
          _buildDrawerSubItem('PDF Reader Hakkında', () => _showAboutDialog()),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF Reader Hakkında', style: TextStyle(color: Color(0xFF2196F3))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PDF Reader v1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Gelişmiş PDF yönetim ve okuma uygulaması'),
            SizedBox(height: 8),
            Text('© 2024 Dev Software'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat', style: TextStyle(color: Color(0xFF2196F3))),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Function onTap) {
    return ListTile(
      leading: Icon(icon, size: 24, color: Color(0xFF2196F3)),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildDrawerSubItem(String title, Function onTap) {
    return ListTile(
      title: Text(title, style: TextStyle(fontSize: 14)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
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
              onPressed: () => _showComingSoon('Arama'),
            ),
          ],
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () => _showComingSoon('Bildirimler'),
          ),
          IconButton(
            icon: CircleAvatar(
              backgroundColor: Color(0xFF2196F3),
              child: Text('DS', style: TextStyle(color: Colors.white, fontSize: 12)),
              radius: 16,
            ),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _database?.close();
    super.dispose();
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
  double _progress = 0;

  String _viewerUrl() {
    try {
      String fileUri;
      
      if (widget.fileUri != null) {
        fileUri = widget.fileUri!;
      } else if (widget.file != null) {
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
        title: Text(widget.fileName, style: TextStyle(fontSize: 16)),
        backgroundColor: Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              if (widget.file != null) {
                Share.shareFiles([widget.file!.path], text: 'PDF Dosyası');
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () async {
              if (widget.file != null) {
                final data = await widget.file!.readAsBytes();
                await Printing.layoutPdf(onLayout: (_) => data);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_loaded && _progress < 1.0)
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
            ),
          Expanded(
            child: Stack(
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
                  onProgressChanged: (controller, progress) {
                    setState(() {
                      _progress = progress / 100;
                    });
                  },
                  onLoadStop: (controller, url) {
                    setState(() {
                      _loaded = true;
                      _progress = 1.0;
                    });
                  },
                ),
                if (!_loaded)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF2196F3)),
                        SizedBox(height: 20),
                        Text('PDF Yükleniyor...', style: TextStyle(color: Color(0xFF2196F3))),
                      ],
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
