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

// Yeni oluşturduğumuz dosyayı import ediyoruz
import 'tools_screen.dart';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  
  // Uygulama klasörünü oluştur
  await _createAppFolder();
  
  final initialIntent = await _getInitialIntent();
  
  runApp(PdfManagerApp(initialIntent: initialIntent));
}

Future<void> _createAppFolder() async {
  try {
    final path = '/storage/emulated/0/Download/PDF Reader';
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  } catch (e) {
    print('Klasör oluşturma hatası: $e');
  }
}

class PdfManagerApp extends StatelessWidget {
  final Map<String, dynamic>? initialIntent;
  final ThemeManager _themeManager = ThemeManager();

  PdfManagerApp({super.key, this.initialIntent});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: Color(0xFFD32F2F),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 2,
          systemOverlayStyle: SystemUiOverlayStyle.light,
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
          type: BottomNavigationBarType.fixed,
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
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[800],
          foregroundColor: Colors.white,
          elevation: 2,
          systemOverlayStyle: SystemUiOverlayStyle.light,
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
          backgroundColor: Colors.grey[800],
          selectedItemColor: Color(0xFFD32F2F),
          unselectedItemColor: Colors.grey[400],
          type: BottomNavigationBarType.fixed,
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
          color: Colors.grey[800],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      themeMode: _themeManager.themeMode,
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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  List<String> _pdfFiles = [];
  List<String> _favoriteFiles = [];
  List<String> _recentFiles = [];
  List<String> _searchHistory = [];
  bool _isLoading = false;
  bool _permissionGranted = false;
  int _currentTabIndex = 0;
  
  late TabController _mainTabController;
  late TabController _homeSubTabController;

  bool _isFabOpen = false;
  bool _isSearchMode = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Database? _database;
  final ThemeManager _themeManager = ThemeManager();

  final List<String> _tabTitles = ['Ana Sayfa', 'Araçlar', 'Dosyalar'];
  final List<String> _homeTabTitles = ['Cihazda', 'Son Kullanılanlar', 'Favoriler'];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: 3, vsync: this);
    _mainTabController.addListener(_handleTabChange);

    _homeSubTabController = TabController(length: 3, vsync: this);
    _homeSubTabController.addListener(() {
      setState(() {});
    });

    _initDatabase();
    _checkPermission();
    _loadSearchHistory();
    
    _intentChannel.setMethodCallHandler(_handleIntentMethodCall);
    
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
      _currentTabIndex = _mainTabController.index;
    });
  }

  Future<dynamic> _handleIntentMethodCall(MethodCall call) async {
    if (call.method == 'onNewIntent') {
      final intentData = Map<String, dynamic>.from(call.arguments);
      _processExternalPdfIntent(intentData);
    }
    return null;
  }

  void _handleInitialIntent() {
    if (widget.initialIntent != null && widget.initialIntent!.isNotEmpty) {
      _processExternalPdfIntent(widget.initialIntent!);
    }
  }

  void _processExternalPdfIntent(Map<String, dynamic> intentData) {
    final action = intentData['action'];
    final uri = intentData['uri'];
    try {
      if ((action == 'android.intent.action.VIEW' || action == 'android.intent.action.SEND') && uri != null) {
        _handleExternalPdfOpening(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ PDF açılırken hata: $e')),
        );
      }
    }
  }

  Future<void> _handleExternalPdfOpening(String uri) async {
    try {
      String sourcePath = uri;
      if (uri.startsWith('content://')) {
        sourcePath = await _pdfViewerChannel.invokeMethod('convertContentUri', {'uri': uri});
      }

      final downloadDir = Directory('/storage/emulated/0/Download/PDF Reader');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final fileName = _extractFileNameFromUri(uri);
      final newPath = '${downloadDir.path}/$fileName';
      
      try {
        final sourceFile = File(sourcePath);
        if (await sourceFile.exists()) {
          await sourceFile.copy(newPath);
        }
      } catch (e) {
         // Hata yok say
      }

      final fileToOpen = File(newPath).existsSync() ? newPath : sourcePath;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            fileUri: fileToOpen,
            fileName: fileName,
          ),
        ),
      );

    } catch (e) {
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
      // Hata yok say
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
    if (androidInfo.version.sdkInt >= 30) {
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
      _createAppFolder();
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
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Documents',
        '/storage/emulated/0/Android/media/com.whatsapp/WhatsApp/Media/WhatsApp Documents',
        (await getExternalStorageDirectory())?.path,
      ];

      for (var path in commonPaths) {
        if (path != null) {
          await _scanDirectory(path);
        }
      }
    } catch (e) {
      // Hata yok say
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
      // Erişim hatası vs. olabilir, yoksay
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dosya seçilirken hata: $e')),
      );
    }
  }

  // Bu metod artık ToolsScreen'den de erişilebilir
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

  Widget _buildHomeContent() {
    return TabBarView(
      controller: _homeSubTabController,
      physics: null, 
      children: [
        _buildDeviceFiles(),
        _buildRecentFiles(),
        _buildFavorites(),
      ],
    );
  }

  Widget _buildDeviceFiles() {
    List<String> displayedFiles = _pdfFiles;
    final searchQuery = _searchController.text.trim().toLowerCase();
    
    if (_isSearchMode && searchQuery.isNotEmpty) {
      displayedFiles = _pdfFiles.where((file) => 
        p.basename(file).toLowerCase().contains(searchQuery)
      ).toList();
    }

    if (!_permissionGranted) {
      return _buildPermissionRequest();
    }
    if (_isLoading) {
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            _isSearchMode && _searchController.text.isNotEmpty 
                ? 'Arama sonucu bulunamadı'
                : 'PDF dosyası bulunamadı',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
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
      ),
    );
  }

  Widget _buildPdfList(List<String> files) {
    return Column(
      children: [
        if (_isSearchMode && _searchHistory.isNotEmpty)
          _buildSearchHistory(),
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (_, i) => _buildFileItem(files[i], false),
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

  Widget _buildFileItem(String filePath, bool isFavorite) {
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
      return '${date.day}.${date.month}.${date.year} - ${date.hour}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}';
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
        title: Text(fileName, style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 2),
            Text(
              '${formatFileSize(fileSize)} - ${formatDate(modifiedDate)}',
              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
            ),
          ],
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
                PopupMenuItem(value: 'rename', child: Text('Yeniden Adlandır')),
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
      case 'rename':
        _showRenameDialog(filePath);
        break;
    }
  }

  void _showRenameDialog(String filePath) {
    final fileName = p.basename(filePath);
    final TextEditingController renameController = TextEditingController(text: p.withoutExtension(fileName));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dosyayı Yeniden Adlandır'),
        content: TextField(
          controller: renameController,
          decoration: InputDecoration(
            labelText: 'Yeni dosya adı',
            suffixText: '.pdf',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFD32F2F)),
            onPressed: () async {
              final newName = '${renameController.text}.pdf';
              final newPath = '${p.dirname(filePath)}/$newName';
              
              try {
                await File(filePath).rename(newPath);
                setState(() {
                  final index = _pdfFiles.indexOf(filePath);
                  if (index != -1) {
                    _pdfFiles[index] = newPath;
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Dosya yeniden adlandırıldı')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Yeniden adlandırma hatası: $e')),
                );
              }
            },
            child: Text('Kaydet', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
        Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text('Bulut Depolama', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildCloudItem('Google Drive', 'assets/icon/drive.png', false, () => _launchCloudService('Google Drive')),
        _buildCloudItem('OneDrive', 'assets/icon/onedrive.png', false, () => _launchCloudService('OneDrive')),
        _buildCloudItem('Dropbox', 'assets/icon/dropbox.png', false, () => _launchCloudService('Dropbox')),
        
        Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text('E-posta Entegrasyonu', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
        ),
        _buildGmailItem(),
        
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
            : Image.asset(icon as String, width: 24, height: 24),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.add, color: Color(0xFFD32F2F)),
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
        trailing: Icon(Icons.add, color: Color(0xFFD32F2F)),
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
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 24,
                      child: Image.asset('assets/icon/logo.png', width: 32, height: 32),
                    ),
                    SizedBox(height: 12),
                    Text('Dev Software', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('PDF Reader - Görüntüleyici & Editör', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ),
          _buildDrawerItem(Icons.info, 'PDF Reader Hakkında', _showAboutDialog),
          _buildDrawerItem(Icons.help, 'Yardım ve Destek', _showHelpSupport),
          Divider(),
          _buildDrawerSubItem('Diller', _showLanguageSettings),
          _buildDrawerSubItem('Gizlilik', _showPrivacyPolicy),
        ],
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dil Ayarları', style: TextStyle(color: Color(0xFFD32F2F))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              leading: Icon(Icons.language, color: Color(0xFFD32F2F)),
              title: Text('Uygulama Dili'),
              subtitle: Text('Yakında eklenecek'),
              onTap: () => _showComingSoon('Uygulama Dili'),
            ),
            Divider(),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Color(0xFFD32F2F)),
              title: Text('PDF Görüntüleyici Dili'),
              subtitle: Text('Yakında eklenecek'),
              onTap: () => _showComingSoon('PDF Görüntüleyici Dili'),
            ),
          ],
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
          icon: Image.asset('assets/icon/logo.png', width: 24, height: 24),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ],
      bottom: _currentTabIndex == 0 
          ? PreferredSize(
              preferredSize: Size.fromHeight(48.0),
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[800] 
                    : Colors.white,
                child: TabBar(
                  controller: _homeSubTabController,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: isDark ? Colors.grey[800] : Colors.white,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarColor: Colors.transparent, 
      ),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: _isSearchMode ? _buildSearchAppBar() : _buildNormalAppBar(),
        drawer: _buildDrawer(),
        body: TabBarView(
          controller: _mainTabController,
          physics: NeverScrollableScrollPhysics(),
          children: [
            _buildHomeContent(),
            ToolsScreen(
              onPickFile: _pickPdfFile,
              onOpenViewer: _openViewer, // YENİ: ToolsScreen'e viewer açma yetkisi verildi
            ),
            _buildFilesTab(),
          ],
        ),
        floatingActionButton: _buildFabMenu(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentTabIndex,
          onTap: (index) {
            _mainTabController.animateTo(index);
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

  @override
  void dispose() {
    _mainTabController.dispose();
    _homeSubTabController.dispose();
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
      return viewerUrl;
    } catch (e) {
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
              if (widget.file != null) {
                final data = await widget.file!.readAsBytes();
                await Printing.layoutPdf(onLayout: (_) => data);
              } else if (widget.fileUri != null) {
                final file = File(widget.fileUri!);
                if (await file.exists()) {
                   final data = await file.readAsBytes();
                   await Printing.layoutPdf(onLayout: (_) => data);
                }
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
