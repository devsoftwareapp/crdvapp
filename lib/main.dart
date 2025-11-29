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

// Tema yönetimi için
enum AppTheme { system, light, dark }

class ThemeManager with ChangeNotifier {
  AppTheme _currentTheme = AppTheme.system;

  AppTheme get currentTheme => _currentTheme;

  void setTheme(AppTheme theme) {
    _currentTheme = theme;
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (_currentTheme) {
      case AppTheme.light:
        return ThemeMode.light;
      case AppTheme.dark:
        return ThemeMode.dark;
      case AppTheme.system:
      default:
        return ThemeMode.system;
    }
  }
}

// PDF Klasörü Yöneticisi
class PdfFolderManager {
  static Future<Directory> getPdfFolder() async {
    final downloadDir = await getExternalStorageDirectory();
    final pdfReaderDir = Directory('${downloadDir?.path}/PDF Reader');
    
    if (!await pdfReaderDir.exists()) {
      await pdfReaderDir.create(recursive: true);
    }
    
    return pdfReaderDir;
  }

  static Future<File> copyToPdfFolder(String sourcePath, String fileName) async {
    final pdfDir = await getPdfFolder();
    final sourceFile = File(sourcePath);
    final destinationFile = File('${pdfDir.path}/$fileName');
    
    // Eğer dosya zaten varsa, ismine timestamp ekle
    if (await destinationFile.exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${p.withoutExtension(fileName)}_$timestamp.${p.extension(fileName)}';
      return await sourceFile.copy('${pdfDir.path}/$newFileName');
    }
    
    return await sourceFile.copy(destinationFile.path);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  
  // Uygulama başladığında PDF Reader klasörünü oluştur
  await PdfFolderManager.getPdfFolder();
  
  final initialIntent = await _getInitialIntent();
  
  runApp(PdfManagerApp(initialIntent: initialIntent));
}

class PdfManagerApp extends StatelessWidget {
  final Map<String, dynamic>? initialIntent;
  final ThemeManager _themeManager = ThemeManager();

  PdfManagerApp({super.key, this.initialIntent});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader',
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: Color(0xFFD32F2F),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFFD32F2F),
          unselectedItemColor: Colors.grey,
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Color(0xFFD32F2F),
          unselectedLabelColor: Colors.grey,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.0, color: Color(0xFFD32F2F)),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: Color(0xFFD32F2F),
        scaffoldBackgroundColor: Color(0xFF121212),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 2,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFFD32F2F),
          unselectedItemColor: Colors.grey[400],
        ),
        tabBarTheme: TabBarTheme(
          labelColor: Color(0xFFD32F2F),
          unselectedLabelColor: Colors.grey[400],
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(width: 2.0, color: Color(0xFFD32F2F)),
          ),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          color: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: _themeManager.themeMode,
      home: HomePage(initialIntent: initialIntent, themeManager: _themeManager),
    );
  }
}

class HomePage extends StatefulWidget {
  final Map<String, dynamic>? initialIntent;
  final ThemeManager themeManager;

  const HomePage({super.key, this.initialIntent, required this.themeManager});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<String> _pdfFiles = [];
  List<String> _favoriteFiles = [];
  List<String> _recentFiles = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  bool _permissionGranted = false;
  int _currentTabIndex = 0;
  int _currentHomeTabIndex = 0;
  late TabController _tabController;
  bool _isFabOpen = false;
  bool _isSearchMode = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

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
    _loadSearchHistory();
    
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
        await db.execute('''
          CREATE TABLE search_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            query TEXT UNIQUE,
            searched_date TEXT
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

  Future<void> _loadSearchHistory() async {
    if (_database == null) return;
    
    final List<Map<String, dynamic>> maps = await _database!.query(
      'search_history',
      orderBy: 'searched_date DESC',
      limit: 10
    );
    setState(() {
      _searchHistory = List.generate(maps.length, (i) => maps[i]['query']);
    });
  }

  Future<void> _addToSearchHistory(String query) async {
    if (_database == null) return;
    
    await _database!.insert(
      'search_history',
      {
        'query': query,
        'searched_date': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _loadSearchHistory();
  }

  Future<void> _clearSearchHistory() async {
    if (_database == null) return;
    
    await _database!.delete('search_history');
    await _loadSearchHistory();
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
      
      // PDF'i PDF Reader klasörüne kopyala
      final fileName = _extractFileNameFromUri(uri);
      final copiedFile = await PdfFolderManager.copyToPdfFolder(filePath, fileName);
      
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            fileUri: copiedFile.path,
            fileName: fileName,
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
        title: Text('Dosya Erişim İzni Gerekli', style: TextStyle(color: Color(0xFFD32F2F))),
        content: Text('Tüm PDF dosyalarını listelemek için dosya erişim izni gerekiyor. Ayarlardan izin verebilirsiniz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Vazgeç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD32F2F)),
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

  Future<void> _deleteFile(String filePath) async {
    final fileName = p.basename(filePath);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dosyayı Sil'),
        content: Text('"$fileName" dosyasını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              try {
                final file = File(filePath);
                await file.delete();
                
                setState(() {
                  _pdfFiles.remove(filePath);
                  _favoriteFiles.remove(filePath);
                  _recentFiles.remove(filePath);
                });
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dosya silindi: $fileName')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Silme hatası: $e')),
                );
              }
            },
            child: Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleFab() {
    setState(() {
      _isFabOpen = !_isFabOpen;
    });
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchController.clear();
        _searchFocusNode.unfocus();
      } else {
        Future.delayed(Duration(milliseconds: 300), () {
          _searchFocusNode.requestFocus();
        });
      }
    });
  }

  void _performSearch(String query) {
    if (query.trim().isNotEmpty) {
      _addToSearchHistory(query.trim());
    }
    setState(() {});
  }

  Widget _buildHomeTabContent() {
    List<String> displayedFiles = [];
    final searchQuery = _searchController.text.trim().toLowerCase();
    
    switch (_currentHomeTabIndex) {
      case 0: // Cihazda
        displayedFiles = _pdfFiles;
        if (_isSearchMode && searchQuery.isNotEmpty) {
          displayedFiles = _pdfFiles.where((file) => 
            p.basename(file).toLowerCase().contains(searchQuery)
          ).toList();
        }
        break;
      case 1: // Son Kullanılanlar
        displayedFiles = _recentFiles;
        break;
      case 2: // Favoriler
        displayedFiles = _favoriteFiles;
        break;
    }

    if (_currentHomeTabIndex == 0 && !_permissionGranted) {
      return _buildPermissionRequest();
    }
    if (_currentHomeTabIndex == 0 && _isLoading) {
      return _buildLoadingState();
    }
    if (displayedFiles.isEmpty) {
      return _buildEmptyState();
    }
    return _buildPdfList(displayedFiles);
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
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
                backgroundColor: Color(0xFFD32F2F),
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
          CircularProgressIndicator(color: Color(0xFFD32F2F)),
          SizedBox(height: 16),
          Text('PDF dosyaları taranıyor...', style: TextStyle(color: Color(0xFFD32F2F))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String emptyText = '';
    String emptySubtitle = '';
    IconData emptyIcon = Icons.search_off;
    
    switch (_currentHomeTabIndex) {
      case 0:
        emptyText = _isSearchMode && _searchController.text.isNotEmpty 
            ? 'Arama sonucu bulunamadı'
            : 'PDF dosyası bulunamadı';
        emptySubtitle = _isSearchMode && _searchController.text.isNotEmpty 
            ? 'Farklı bir kelime ile aramayı deneyin'
            : 'Dosya seçerek PDF ekleyebilirsiniz';
        emptyIcon = _isSearchMode && _searchController.text.isNotEmpty 
            ? Icons.search_off 
            : Icons.folder_open;
        break;
      case 1:
        emptyText = 'Henüz son açılan dosya yok';
        emptySubtitle = 'PDF dosyalarını açtıkça burada görünecekler';
        emptyIcon = Icons.history;
        break;
      case 2:
        emptyText = 'Henüz favori dosyanız yok';
        emptySubtitle = 'Beğendiğiniz dosyaları yıldız simgesine tıklayarak favorilere ekleyebilirsiniz';
        emptyIcon = Icons.star;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(emptyIcon, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            emptyText,
            style: TextStyle(fontSize: 18, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            emptySubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          if (_currentHomeTabIndex == 0) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _scanDeviceForPdfs,
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD32F2F)),
              child: Text('Yeniden Tara', style: TextStyle(color: Colors.white)),
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: _pickPdfFile,
              child: Text('Dosya Seç', style: TextStyle(color: Color(0xFFD32F2F))),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfList(List<String> files) {
    return Column(
      children: [
        if (_isSearchMode && _searchHistory.isNotEmpty && _currentHomeTabIndex == 0)
          _buildSearchHistory(),
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (_, i) => _buildFileItem(files[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHistory() {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Arama Geçmişi', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
                TextButton(
                  onPressed: _clearSearchHistory,
                  child: Text('Temizle', style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _searchHistory.map((query) => ActionChip(
                label: Text(query),
                onPressed: () {
                  _searchController.text = query;
                  _performSearch(query);
                },
                backgroundColor: Color(0xFFF5F5F5),
                labelStyle: TextStyle(color: Color(0xFFD32F2F)),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileItem(String filePath) {
    final fileName = p.basename(filePath);
    final isFavorited = _favoriteFiles.contains(filePath);
    final file = File(filePath);
    final fileSize = file.existsSync() ? file.lengthSync() : 0;
    final modifiedDate = file.existsSync() ? file.lastModifiedSync() : DateTime.now();

    String formatFileSize(int bytes) {
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }

    String formatDate(DateTime date) {
      return '${date.day}.${date.month}.${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 50,
          decoration: BoxDecoration(
            color: Color(0xFFD32F2F),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 24),
        ),
        title: Text(
          fileName, 
          style: TextStyle(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${formatFileSize(fileSize)} - ${formatDate(modifiedDate)}',
          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                PopupMenuItem(value: 'delete', child: Text('Sil', style: TextStyle(color: Colors.red))),
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
      case 'delete':
        _deleteFile(filePath);
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
      itemBuilder: (_, i) => _buildFileItem(_recentFiles[i]),
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
      itemBuilder: (_, i) => _buildFileItem(_favoriteFiles[i]),
    );
  }

  Widget _buildToolsTab() {
    final tools = [
      {
        'icon': Icons.edit, 
        'name': 'PDF Düzenle', 
        'color': Color(0xFFFFEBEE), 
        'onTap': () => _showComingSoon('PDF Düzenleme')
      },
      {
        'icon': Icons.volume_up, 
        'name': 'Sesli okuma', 
        'color': Color(0xFFF3E5F5), 
        'onTap': () => _showComingSoon('Sesli Okuma')
      },
      {
        'icon': Icons.edit_document, 
        'name': 'PDF Doldur & İmzala', 
        'color': Color(0xFFE8F5E8), 
        'onTap': () => _showComingSoon('PDF Doldur & İmzala')
      },
      {
        'icon': Icons.picture_as_pdf, 
        'name': 'PDF Oluştur', 
        'color': Color(0xFFE3F2FD), 
        'onTap': _pickPdfFile
      },
      {
        'icon': Icons.layers, 
        'name': 'Sayfaları organize et', 
        'color': Color(0xFFFFF3E0), 
        'onTap': () => _showComingSoon('Sayfa Organizasyonu')
      },
      {
        'icon': Icons.merge, 
        'name': 'Dosyaları birleştirme', 
        'color': Color(0xFFE0F2F1), 
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
                    child: Icon(tool['icon'] as IconData, color: Color(0xFFD32F2F), size: 30),
                  ),
                  SizedBox(height: 12),
                  Text(
                    tool['name'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFD32F2F)),
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
        backgroundColor: Color(0xFFD32F2F),
      ),
    );
  }

  Widget _buildFilesTab() {
    return ListView(
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text('Dosyalar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F))),
        ),
        
        // Bulut Depolama
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
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
          child: _buildCloudItem('Daha Fazla Dosya İçin Göz Atın', Icons.folder_open, true, _pickPdfFile),
        ),
      ],
    );
  }

  Future<void> _launchCloudService(String service) async {
    final urls = {
      'Google Drive': 'https://drive.google.com',
      'OneDrive': 'https://onedrive.live.com',
      'Dropbox': 'https://www.dropbox.com',
      'Gmail': 'https://gmail.com',
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
            ? Icon(icon as IconData, size: 24, color: Color(0xFFD32F2F))
            : Container(
                width: 24,
                height: 24,
                child: Placeholder(), // Gerçek uygulamada asset image kullanın
              ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFD32F2F)),
        onTap: () => onTap(),
      ),
    );
  }

  Widget _buildGmailItem() {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 24,
          height: 24,
          child: Placeholder(), // Gerçek uygulamada Gmail asset image kullanın
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('E-postalardaki PDF\'ler', style: TextStyle(fontWeight: FontWeight.w500)),
            Text('Gmail', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFFD32F2F)),
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
            backgroundColor: _isFabOpen ? Color(0xFFB71C1C) : Color(0xFFD32F2F),
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
          color: Theme.of(context).cardColor,
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
                color: Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, size: 20, color: Color(0xFFD32F2F)),
            ),
            SizedBox(width: 8),
            Text(text, style: TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFD32F2F))),
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
            height: 160,
            decoration: BoxDecoration(
              color: Color(0xFFD32F2F),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 20),
                  CircleAvatar(
                    backgroundColor: Colors.white,
                    radius: 30,
                    child: Icon(Icons.picture_as_pdf, size: 32, color: Color(0xFFD32F2F)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Dev Software',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'PDF Reader - Görüntüleyici & Editör',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          _buildDrawerItem(Icons.brightness_6, 'Tema Ayarları', _showThemeSettings),
          _buildDrawerItem(Icons.help, 'Yardım ve Destek', _showHelpSupport),
          Divider(),
          _buildDrawerSubItem('Diller', _showLanguageSettings),
          _buildDrawerSubItem('Gizlilik', _showPrivacyPolicy),
          _buildDrawerSubItem('PDF Reader Hakkında', _showAboutDialog),
        ],
      ),
    );
  }

  void _showThemeSettings() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tema Seçin', style: TextStyle(color: Color(0xFFD32F2F))),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption('Cihaz Varsayılanı', AppTheme.system, Icons.phone_android),
              SizedBox(height: 12),
              _buildThemeOption('Light Mode', AppTheme.light, Icons.light_mode),
              SizedBox(height: 12),
              _buildThemeOption('Dark Mode', AppTheme.dark, Icons.dark_mode),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(String title, AppTheme theme, IconData icon) {
    final isSelected = widget.themeManager.currentTheme == theme;
    
    return Card(
      color: isSelected ? Color(0xFFFFEBEE) : Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? Color(0xFFD32F2F) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? Color(0xFFD32F2F) : Colors.grey),
        title: Text(title, style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isSelected ? Color(0xFFD32F2F) : Theme.of(context).textTheme.bodyLarge?.color,
        )),
        trailing: isSelected ? Icon(Icons.check, color: Color(0xFFD32F2F)) : null,
        onTap: () {
          widget.themeManager.setTheme(theme);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title teması uygulandı')),
          );
        },
      ),
    );
  }

  void _showHelpSupport() {
    final TextEditingController messageController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Yardım ve Destek', style: TextStyle(color: Color(0xFFD32F2F))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sorununuzu veya önerinizi bize iletin:'),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  labelText: 'E-posta Adresiniz',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Mesajınız',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD32F2F)),
            onPressed: () {
              if (messageController.text.trim().isEmpty || emailController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lütfen tüm alanları doldurun')),
                );
                return;
              }
              
              final Uri emailLaunchUri = Uri(
                scheme: 'mailto',
                path: 'devsoftwaremail@gmail.com',
                queryParameters: {
                  'subject': 'PDF Reader Destek Talebi',
                  'body': 'E-posta: ${emailController.text}\n\nMesaj: ${messageController.text}',
                },
              );
              
              launchUrl(emailLaunchUri);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Mesajınız e-posta uygulamasına yönlendiriliyor...')),
              );
            },
            child: Text('Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showLanguageSettings() {
    _showComingSoon('Dil Ayarları');
  }

  void _showPrivacyPolicy() {
    _showComingSoon('Gizlilik Politikası');
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('PDF Reader Hakkında', style: TextStyle(color: Color(0xFFD32F2F))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PDF Reader v1.0.0', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Gelişmiş PDF görüntüleme ve yönetim uygulaması'),
              SizedBox(height: 16),
              Text('Kullanılan Teknolojiler:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• PDF.js - Mozilla'),
              Text('• Flutter Framework'),
              Text('• SQLite Database'),
              Text('• InAppWebView'),
              SizedBox(height: 16),
              Text('Lisans Bilgileri:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Bu uygulama açık kaynak kodlu teknolojiler kullanılarak geliştirilmiştir.'),
              SizedBox(height: 8),
              Text('© 2024 Dev Software'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Kapat', style: TextStyle(color: Color(0xFFD32F2F))),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Function onTap) {
    return ListTile(
      leading: Icon(icon, size: 24, color: Color(0xFFD32F2F)),
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

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Color(0xFFD32F2F),
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: _toggleSearchMode,
      ),
      title: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        style: TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'PDF dosyalarında ara...',
          hintStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        onChanged: (value) {
          setState(() {});
        },
        onSubmitted: _performSearch,
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              setState(() {});
            },
          ),
      ],
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Text(_tabTitles[_currentTabIndex]),
      actions: [
        if (_currentTabIndex == 0) ...[
          IconButton(
            icon: Icon(Icons.search),
            onPressed: _toggleSearchMode,
          ),
        ],
        IconButton(
          icon: Icon(Icons.menu, color: Colors.white),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ],
      bottom: _currentTabIndex == 0 
          ? PreferredSize(
              preferredSize: Size.fromHeight(48.0),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Color(0xFF1E1E1E) 
                    : Colors.white,
                child: TabBar(
                  controller: TabController(
                    length: 3,
                    vsync: this,
                    initialIndex: _currentHomeTabIndex,
                  ),
                  onTap: (index) => setState(() => _currentHomeTabIndex = index),
                  tabs: _homeTabTitles.map((title) => Tab(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.white 
                            : Color(0xFFD32F2F),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )).toList(),
                  indicatorColor: Color(0xFFD32F2F),
                  labelColor: Color(0xFFD32F2F),
                  unselectedLabelColor: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.grey[400] 
                      : Colors.grey,
                ),
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _isSearchMode ? _buildSearchAppBar() : _buildNormalAppBar(),
      drawer: _buildDrawer(),
      body: TabBarView(
        controller: _tabController,
        physics: _currentTabIndex == 0 
            ? PageScrollPhysics() // Sadece Ana Sayfa'da kaydırma
            : NeverScrollableScrollPhysics(), // Diğer tablarda kaydırma yok
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
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? Color(0xFF1E1E1E) 
            : Colors.white,
        selectedItemColor: Color(0xFFD32F2F),
        unselectedItemColor: Theme.of(context).brightness == Brightness.dark 
            ? Colors.grey[400] 
            : Colors.grey,
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
    _searchController.dispose();
    _searchFocusNode.dispose();
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
        backgroundColor: Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: () {
              if (widget.file != null) {
                Share.shareFiles([widget.file!.path], text: 'PDF Dosyası');
              } else if (widget.fileUri != null) {
                Share.shareFiles([widget.fileUri!], text: 'PDF Dosyası');
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.print),
            onPressed: () async {
              try {
                Uint8List data;
                if (widget.file != null) {
                  data = await widget.file!.readAsBytes();
                } else if (widget.fileUri != null) {
                  data = await File(widget.fileUri!).readAsBytes();
                } else {
                  throw Exception('No file available for printing');
                }
                await Printing.layoutPdf(onLayout: (_) => data);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Yazdırma hatası: $e')),
                );
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
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD32F2F)),
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
                        CircularProgressIndicator(color: Color(0xFFD32F2F)),
                        SizedBox(height: 20),
                        Text('PDF Yükleniyor...', style: TextStyle(color: Color(0xFFD32F2F))),
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
