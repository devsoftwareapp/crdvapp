// lib/main.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'tools.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

// IMPORT
import 'external_pdf_viewer.dart';

// Intent handling için import
import 'package:flutter/services.dart';

// Google Mobile Ads için import
import 'package:google_mobile_ads/google_mobile_ads.dart';

const List<Locale> kSupportedLocales = [
  Locale('en', 'US'),
  Locale('tr'),
  Locale('ar'),
  Locale('cs'),
  Locale('da'),
  Locale('de'),
  Locale('el'),
  Locale('en', 'GB'),
  Locale('es'),
  Locale('fa'),
  Locale('fi'),
  Locale('fr'),
  Locale('hi'),
  Locale('id'),
  Locale('it'),
  Locale('ja'),
  Locale('ko'),
  Locale('nl'),
  Locale('no'),
  Locale('pl'),
  Locale('pt', 'BR'),
  Locale('pt', 'PT'),
  Locale('ru'),
  Locale('sv'),
  Locale('th'),
  Locale('uk'),
  Locale('vi'),
  Locale('zh', 'CN'),
  Locale('zh', 'TW'),
];

Locale _localeFromCode(String code) {
  if (code == 'en_US') return const Locale('en', 'US');
  if (code == 'en_GB') return const Locale('en', 'GB');
  if (code == 'pt_BR') return const Locale('pt', 'BR');
  if (code == 'pt_PT') return const Locale('pt', 'PT');
  if (code == 'zh_CN') return const Locale('zh', 'CN');
  if (code == 'zh_TW') return const Locale('zh', 'TW');
  if (code.contains('_')) {
    final parts = code.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  }
  return Locale(code);
}

String _codeFromLocale(Locale locale) {
  if (locale.countryCode != null && locale.countryCode!.isNotEmpty) {
    return '${locale.languageCode}_${locale.countryCode}';
  }
  return locale.languageCode;
}

bool _isLocaleSupported(Locale locale) {
  for (final l in kSupportedLocales) {
    if (l.languageCode == locale.languageCode) {
      if ((l.countryCode == null || l.countryCode!.isEmpty) ||
          (locale.countryCode != null && locale.countryCode == l.countryCode)) {
        return true;
      }
    }
  }
  return false;
}

Future<Locale> _determineInitialLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final savedCode = prefs.getString('selected_locale');
  if (savedCode != null && savedCode.isNotEmpty) {
    return _localeFromCode(savedCode);
  }

  Locale deviceLocale;
  try {
    deviceLocale = ui.PlatformDispatcher.instance.locale;
  } catch (e) {
    deviceLocale = const Locale('en', 'US');
  }

  if (_isLocaleSupported(deviceLocale)) {
    return deviceLocale;
  }

  final langOnly = Locale(deviceLocale.languageCode);
  if (_isLocaleSupported(langOnly)) {
    return langOnly;
  }

  return const Locale('en', 'US');
}

// Intent handling için method channel
final MethodChannel _intentChannel = MethodChannel('app.channel.shared/data');

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
  
  // Google Mobile Ads'ı başlat - VERİLEN APP ID
  await MobileAds.instance.initialize();
  
  if (Platform.isAndroid) {
    await InAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  
  final initialLocale = await _determineInitialLocale();
  final initialIntent = await _getInitialIntent();
  
  runApp(PdfManagerApp(initialLocale: initialLocale, initialIntent: initialIntent));
}

class PdfManagerApp extends StatefulWidget {
  final Locale initialLocale;
  final Map<String, dynamic>? initialIntent;

  const PdfManagerApp({super.key, required this.initialLocale, this.initialIntent});

  @override
  State<PdfManagerApp> createState() => _PdfManagerAppState();
}

class _PdfManagerAppState extends State<PdfManagerApp> {
  ThemeMode _themeMode = ThemeMode.light;
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void toggleTheme(bool dark) {
    setState(() {
      _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_locale', _codeFromLocale(locale));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Reader & Manager',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.light,
        // Navigation bar teması - açık mod
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: Colors.red.withOpacity(0.2),
          iconTheme: MaterialStateProperty.all(const IconThemeData(color: Colors.black87)),
          labelTextStyle: MaterialStateProperty.all(const TextStyle(color: Colors.black87)),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
        // Navigation bar teması - koyu mod
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.black,
          indicatorColor: Colors.red.withOpacity(0.3),
          iconTheme: MaterialStateProperty.all(const IconThemeData(color: Colors.white70)),
          labelTextStyle: MaterialStateProperty.all(const TextStyle(color: Colors.white70)),
        ),
      ),
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomePage(
        dark: _themeMode == ThemeMode.dark,
        onThemeChanged: toggleTheme,
        setLocale: setLocale,
        currentLocale: _locale,
        initialIntent: widget.initialIntent,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final bool dark;
  final Function(bool) onThemeChanged;
  final Future<void> Function(Locale) setLocale;
  final Locale currentLocale;
  final Map<String, dynamic>? initialIntent;

  const HomePage({
    super.key,
    required this.dark,
    required this.onThemeChanged,
    required this.setLocale,
    required this.currentLocale,
    this.initialIntent,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _selectionMode = false;
  List<String> _selectedFiles = [];
  List<String> _allFiles = [];
  List<String> _folders = [];
  List<String> _favorites = [];
  List<String> _recent = [];
  String _searchQuery = '';
  String _sortMode = 'Name';
  String? _currentPath;
  Directory? _baseDir;
  Map<String, Color> _folderColors = {};
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Banner reklam için
  BannerAd? _bannerAd;
  bool _isBannerAdReady = false;

  // Dil verileri
  final List<Map<String, String>> _languages = [
    {'code': 'en_US', 'name': 'English (US)', 'native': 'English (US)'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
    {'code': 'cs', 'name': 'Czech', 'native': 'Čeština'},
    {'code': 'da', 'name': 'Danish', 'native': 'Dansk'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch'},
    {'code': 'el', 'name': 'Greek', 'native': 'Ελληνικά'},
    {'code': 'en_GB', 'name': 'English (UK)', 'native': 'English (UK)'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    {'code': 'fa', 'name': 'Persian', 'native': 'فارسی'},
    {'code': 'fi', 'name': 'Finnish', 'native': 'Suomi'},
    {'code': 'fr', 'name': 'French', 'native': 'Français'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'id', 'name': 'Indonesian', 'native': 'Bahasa Indonesia'},
    {'code': 'it', 'name': 'Italian', 'native': 'Italiano'},
    {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
    {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
    {'code': 'nl', 'name': 'Dutch', 'native': 'Nederlands'},
    {'code': 'no', 'name': 'Norwegian', 'native': 'Norsk'},
    {'code': 'pl', 'name': 'Polish', 'native': 'Polski'},
    {'code': 'pt_BR', 'name': 'Portuguese (Brazil)', 'native': 'Português (Brasil)'},
    {'code': 'pt_PT', 'name': 'Portuguese (Portugal)', 'native': 'Português (Portugal)'},
    {'code': 'ru', 'name': 'Russian', 'native': 'Русский'},
    {'code': 'sv', 'name': 'Swedish', 'native': 'Svenska'},
    {'code': 'tr', 'name': 'Turkish', 'native': 'Türkçe'},
    {'code': 'th', 'name': 'Thai', 'native': 'ไทย'},
    {'code': 'uk', 'name': 'Ukrainian', 'native': 'Українська'},
    {'code': 'vi', 'name': 'Vietnamese', 'native': 'Tiếng Việt'},
    {'code': 'zh_CN', 'name': 'Chinese (Simplified)', 'native': '中文 (简体)'},
    {'code': 'zh_TW', 'name': 'Chinese (Traditional)', 'native': '中文 (繁體)'},
  ];

  // Arama için TextController (drawer içindeki arama aktif)
  final TextEditingController _languageSearchController = TextEditingController();
  String _languageSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _initDir();
    _searchController.addListener(_onSearchChanged);
    _languageSearchController.addListener(_onLanguageSearchChanged);
    _loadBannerAd();
    
    // Intent'i işle - GECİKMELİ olarak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleInitialIntent();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _languageSearchController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // Banner reklam yükleme - SADECE ANDROID TEST BANNER ID
  void _loadBannerAd() {
    _bannerAd = BannerAd(
      // SADECE Android test banner ID
      adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          print('Banner reklam yüklenemedi: $error');
          ad.dispose();
        },
      ),
    )..load();
  }

  // YENİ METOD: External intent işleme
  void _handleInitialIntent() {
    if (widget.initialIntent != null && widget.initialIntent!.isNotEmpty) {
      print('📱 Initial intent received: ${widget.initialIntent}');
      
      final action = widget.initialIntent!['action'];
      final data = widget.initialIntent!['data'];
      
      if ((action == 'android.intent.action.VIEW' || action == 'android.intent.action.SEND') && data != null) {
        _processExternalPdfIntent(data.toString());
      }
    }
  }

  // YENİ METOD: External intent işleme
  void _processExternalPdfIntent(String data) async {
    print('📄 Processing EXTERNAL PDF intent: $data');
    
    try {
      // Doğrudan ExternalPdfViewer'a yönlendir
      if (data.startsWith('content://') || data.startsWith('file://')) {
        print('🎯 Opening external PDF viewer for: $data');
        
        final fileName = _extractFileNameFromUri(data);
        
        // Hemen ExternalPdfViewer'a git
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => ExternalPdfViewer(
              fileUri: data,
              fileName: fileName,
              dark: widget.dark,
              locale: _getPdfJsLocale(),
            ),
          ),
          (route) => false,
        );
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

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _onLanguageSearchChanged() {
    setState(() {
      _languageSearchQuery = _languageSearchController.text.toLowerCase();
    });
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  Future<void> _initDir() async {
    try {
      _baseDir = await getApplicationDocumentsDirectory();
      _currentPath = _baseDir!.path;

      await _loadLists();
      await _scanFilesAndFolders();
      
      print('✅ Directory initialized: $_currentPath');
    } catch (e) {
      print('❌ Directory initialization error: $e');
      _currentPath = '/data/data/com.example.pdfreadermanager/files';
    }
  }

  Future<void> _scanFilesAndFolders() async {
    if (_currentPath == null) {
      print('⚠️ _currentPath is null, skipping scan');
      return;
    }

    try {
      final List<String> pdfPaths = [];
      final List<String> folderPaths = [];

      final dir = Directory(_currentPath!);
      if (await dir.exists()) {
        final entities = dir.listSync();

        for (var e in entities) {
          if (e is File && e.path.toLowerCase().endsWith('.pdf')) {
            pdfPaths.add(e.path);
          } else if (e is Directory) {
            final folderName = p.basename(e.path);
            if (folderName != 'pdfreadermanager') {
              folderPaths.add(e.path);
            }
          }
        }
      }

      setState(() {
        _allFiles = pdfPaths;
        _folders = folderPaths;
      });
    } catch (e) {
      print('❌ Scan files error: $e');
    }
  }

  Future<void> _loadLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _favorites = prefs.getStringList('favorites') ?? [];
        _recent = prefs.getStringList('recent') ?? [];

        final colorKeys = prefs.getStringList('folderColorKeys') ?? [];
        final colorValues = prefs.getStringList('folderColorValues') ?? [];
        _folderColors = {};
        for (int i = 0; i < colorKeys.length; i++) {
          if (i < colorValues.length) {
            _folderColors[colorKeys[i]] = Color(int.parse(colorValues[i]));
          }
        }
      });
    } catch (e) {
      print('❌ Load lists error: $e');
    }
  }

  Future<void> _saveLists() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('favorites', _favorites);
      await prefs.setStringList('recent', _recent);

      await prefs.setStringList('folderColorKeys', _folderColors.keys.toList());
      await prefs.setStringList('folderColorValues',
          _folderColors.values.map((color) => color.value.toString()).toList());
    } catch (e) {
      print('❌ Save lists error: $e');
    }
  }

  Color _getFolderColor(String folderPath) {
    return _folderColors[folderPath] ?? Colors.amber;
  }

  Future<void> _setFolderColor(String folderPath, Color color) async {
    setState(() {
      _folderColors[folderPath] = color;
    });
    await _saveLists();
  }

  Locale _getLocaleFromCode(String code) => _localeFromCode(code);

  Future<void> _importFile() async {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      _scaffoldKey.currentState!.closeDrawer();
    }

    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (res != null && res.files.single.path != null) {
        final path = res.files.single.path!;
        final imported = File(path);
        final newPath = p.join(_currentPath ?? '', p.basename(path));
        await imported.copy(newPath);
        await _scanFilesAndFolders();

        setState(() {
          _selectedIndex = 0;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).translate('file_imported_successfully'))),
        );
      }
    } catch (e) {
      print('❌ Import file error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Dosya içe aktarılırken hata: $e')),
      );
    }
  }

  void _openViewer(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Dosya bulunamadı: ${p.basename(path)}')),
        );
        return;
      }
    
      final pdfJsLocale = _getPdfJsLocale();
      
      print("🌍 Opening INTERNAL PDF with locale: $pdfJsLocale");

      // MEVCUT ViewerScreen kullanılmaya devam ediyor
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ViewerScreen(
            file: file,
            fileName: p.basename(path),
            dark: widget.dark,
            locale: pdfJsLocale,
          ),
        ),
      );
      
      if (!_recent.contains(path)) {
        _recent.insert(0, path);
        await _saveLists();
      }
    } catch (e) {
      print('❌ Open viewer error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ PDF açılırken hata: $e')),
      );
    }
  }

  // PDF.js locale'ini al - KULLANICI SEÇİMİNE GÖRE
  String _getPdfJsLocale() {
    final localeMap = {
      'en_US': 'en-US', 'en_GB': 'en-GB', 'tr': 'tr', 'ar': 'ar',
      'cs': 'cs', 'da': 'da', 'de': 'de', 'el': 'el', 'es': 'es',
      'fa': 'fa', 'fi': 'fi', 'fr': 'fr', 'hi': 'hi', 'id': 'id',
      'it': 'it', 'ja': 'ja', 'ko': 'ko', 'nl': 'nl', 'no': 'no',
      'pl': 'pl', 'pt_BR': 'pt-BR', 'pt_PT': 'pt-PT', 'ru': 'ru',
      'sv': 'sv', 'th': 'th', 'uk': 'uk', 'vi': 'vi', 'zh_CN': 'zh-CN',
      'zh_TW': 'zh-TW'
    };
    
    // KULLANICI SEÇİMİNE GÖRE locale kullan
    final currentLocaleCode = _codeFromLocale(widget.currentLocale);
    final pdfJsLocale = localeMap[currentLocaleCode] ?? 'en-US';
    
    print("🌍 PDF.js Locale: $pdfJsLocale (User selected: $currentLocaleCode)");
    return pdfJsLocale;
  }

  Future<Map<String, dynamic>> _getFolderItemCount(String folderPath) async {
    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        return {'count': 0, 'date': '', 'time': ''};
      }
      
      final entities = await dir.list().toList();
      
      int count = 0;
      DateTime? latestModified;
      
      for (var entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.pdf')) {
          count++;
          final stat = await entity.stat();
          if (latestModified == null || stat.modified.isAfter(latestModified)) {
            latestModified = stat.modified;
          }
        }
      }
      
      String dateStr = '';
      String timeStr = '';
      
      if (latestModified != null) {
        dateStr = DateFormat('dd.MM.yyyy').format(latestModified!);
        timeStr = DateFormat('HH:mm').format(latestModified!);
      }
      
      return {
        'count': count,
        'date': dateStr,
        'time': timeStr,
      };
    } catch (e) {
      print('Error getting folder count: $e');
      return {'count': 0, 'date': '', 'time': ''};
    }
  }

  void _enterFolder(String folderPath) {
    setState(() {
      _currentPath = folderPath;
    });
    _scanFilesAndFolders();
  }

  void _renameFolder(String folderPath) async {
    final controller = TextEditingController(text: p.basename(folderPath));
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('rename_folder')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: AppLocalizations.of(context).translate('folder_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == p.basename(folderPath)) {
                Navigator.pop(context);
                return;
              }
              
              final newPath = p.join(p.dirname(folderPath), newName);
              try {
                await Directory(folderPath).rename(newPath);
                await _scanFilesAndFolders();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppLocalizations.of(context).translate('folder_created')} "$newName"')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${AppLocalizations.of(context).translate('rename_error')}: $e')),
                );
              }
              
              if (mounted) Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('rename')),
          ),
        ],
      ),
    );
  }

  void _changeFolderColor(String folderPath) async {
    final currentColor = _getFolderColor(folderPath);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('change_color')),
        content: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Colors.amber,
              Colors.red,
              Colors.blue,
              Colors.green,
              Colors.purple,
              Colors.orange,
              Colors.teal,
              Colors.pink,
              Colors.indigo,
              Colors.cyan,
              Colors.brown,
              Colors.grey,
            ].map((color) {
              return GestureDetector(
                onTap: () {
                  _setFolderColor(folderPath, color);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(20),
                    border: currentColor.value == color.value 
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
        ],
      ),
    );
  }

  void _deleteFolder(String folderPath) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('delete_folder')),
        content: Text('${AppLocalizations.of(context).translate('are_you_sure_delete')} "${p.basename(folderPath)}" ${AppLocalizations.of(context).translate('and_all_contents')}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await Directory(folderPath).delete(recursive: true);
                await _scanFilesAndFolders();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppLocalizations.of(context).translate('folder_deleted')} "${p.basename(folderPath)}"')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${AppLocalizations.of(context).translate('delete_error')}: $e')),
                );
              }
              
              if (mounted) Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _toggleFavorite(String filePath) {
    setState(() {
      if (_favorites.contains(filePath)) {
        _favorites.remove(filePath);
      } else {
        _favorites.add(filePath);
      }
    });
    _saveLists();
  }

  void _renameFile(String filePath) async {
    final controller = TextEditingController(text: p.basenameWithoutExtension(filePath));
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('rename_file')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: AppLocalizations.of(context).translate('file_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == p.basenameWithoutExtension(filePath)) {
                Navigator.pop(context);
                return;
              }
              
              final newPath = p.join(p.dirname(filePath), '$newName.pdf');
              try {
                await File(filePath).rename(newPath);
                
                // Update lists
                if (_favorites.contains(filePath)) {
                  _favorites.remove(filePath);
                  _favorites.add(newPath);
                }
                if (_recent.contains(filePath)) {
                  _recent.remove(filePath);
                  _recent.add(newPath);
                }
                if (_selectedFiles.contains(filePath)) {
                  _selectedFiles.remove(filePath);
                  _selectedFiles.add(newPath);
                }
                
                await _saveLists();
                await _scanFilesAndFolders();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppLocalizations.of(context).translate('file_renamed')} "$newName"')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${AppLocalizations.of(context).translate('rename_error')}: $e')),
                );
              }
              
              if (mounted) Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('rename')),
          ),
        ],
      ),
    );
  }

  void _printFile(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${AppLocalizations.of(context).translate('print_error')}: $e')),
      );
    }
  }

  void _shareFile(String filePath) async {
    try {
      await Share.shareXFiles([XFile(filePath)]);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ ${AppLocalizations.of(context).translate('share_error')}: $e')),
      );
    }
  }

  // DÜZELTİLMİŞ _moveFile METODU - ORİJİNAL HALİNE DÖNDÜRÜLDÜ
  Future<void> _moveFile(String filePath) async {
    final allFolders = await _getAllFolders();
    final foldersWithRoot = [_baseDir!.path, ...allFolders.where((folder) => folder != _baseDir!.path)];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('move_file')),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: foldersWithRoot.length,
            itemBuilder: (_, index) {
              final folder = foldersWithRoot[index];
              final isRoot = folder == _baseDir!.path;
              return ListTile(
                leading: Icon(
                    isRoot ? Icons.home : Icons.folder,
                    color: isRoot ? Colors.blue : _getFolderColor(folder)
                ),
                title: Text(
                    isRoot ? AppLocalizations.of(context).translate('all_files_root') : p.relative(folder, from: _baseDir!.path)
                ),
                subtitle: isRoot ? Text(AppLocalizations.of(context).translate('move_to_main_directory')) : null,
                onTap: () async {
                  final fileName = p.basename(filePath);
                  final newPath = p.join(folder, fileName);

                  if (p.dirname(filePath) == folder) {
                    if (mounted) Navigator.pop(context);
                    return;
                  }

                  try {
                    await File(filePath).rename(newPath);

                    if (_favorites.contains(filePath)) {
                      _favorites.remove(filePath);
                      _favorites.add(newPath);
                    }
                    if (_recent.contains(filePath)) {
                      _recent.remove(filePath);
                      _recent.add(newPath);
                    }
                    await _saveLists();
                    await _scanFilesAndFolders();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${AppLocalizations.of(context).translate('file_moved')} "${p.basename(filePath)}"')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ ${AppLocalizations.of(context).translate('move_error')}: $e')),
                    );
                  }
                  
                  if (mounted) Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
        ],
      ),
    );
  }

  // ORİJİNAL _getAllFolders METODU
  Future<List<String>> _getAllFolders() async {
    final List<String> folders = [];
    final dir = Directory(_baseDir!.path);

    await for (var entity in dir.list(recursive: true)) {
      if (entity is Directory) {
        final folderName = p.basename(entity.path);
        if (folderName != 'pdfreadermanager') {
          folders.add(entity.path);
        }
      }
    }

    return folders;
  }

  void _deleteFile(String filePath) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('delete_file')),
        content: Text('${AppLocalizations.of(context).translate('are_you_sure_delete')} "${p.basename(filePath)}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await File(filePath).delete();
                
                // Update lists
                if (_favorites.contains(filePath)) {
                  _favorites.remove(filePath);
                }
                if (_recent.contains(filePath)) {
                  _recent.remove(filePath);
                }
                if (_selectedFiles.contains(filePath)) {
                  _selectedFiles.remove(filePath);
                }
                
                await _saveLists();
                await _scanFilesAndFolders();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppLocalizations.of(context).translate('file_deleted')} "${p.basename(filePath)}"')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ ${AppLocalizations.of(context).translate('delete_error')}: $e')),
                );
              }
              
              if (mounted) Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('delete_files')),
        content: Text('${AppLocalizations.of(context).translate('are_you_sure_delete')} ${_selectedFiles.length} file(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              for (String path in _selectedFiles) {
                final file = File(path);
                if (await file.exists()) {
                  await file.delete();

                  if (_favorites.contains(path)) {
                    _favorites.remove(path);
                  }
                  if (_recent.contains(path)) {
                    _recent.remove(path);
                  }
                }
              }

              await _saveLists();
              await _scanFilesAndFolders();
              setState(() {
                _selectedFiles.clear();
                _selectionMode = false;
              });

              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_selectedFiles.length} ${AppLocalizations.of(context).translate('files_deleted')}')),
              );
            },
            child: Text(AppLocalizations.of(context).translate('delete'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _shareSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    final xFiles = _selectedFiles.map((path) => XFile(path)).toList();
    await Share.shareXFiles(xFiles);
  }

  Future<void> _printSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;

    for (String path in _selectedFiles) {
      final bytes = await File(path).readAsBytes();
      await Printing.layoutPdf(onLayout: (_) => bytes);
    }
  }

  void _selectAllFiles() {
    setState(() {
      if (_selectedFiles.length == _allFiles.length) {
        _selectedFiles.clear();
      } else {
        _selectedFiles = List.from(_allFiles);
      }
    });
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(AppLocalizations.of(context).translate('create_folder')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: AppLocalizations.of(context).translate('folder_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || _currentPath == null) return;
              final newFolder = Directory(p.join(_currentPath!, name));
              if (!(await newFolder.exists())) {
                await newFolder.create(recursive: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${AppLocalizations.of(context).translate('folder_created')} "$name"')),
                );
                await _scanFilesAndFolders();
              }
              if (mounted) Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context).translate('create')),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (_currentPath != null && _baseDir != null && _currentPath != _baseDir!.path) {
      setState(() {
        _currentPath = p.dirname(_currentPath!);
      });
      _scanFilesAndFolders();
    }
  }

  List<String> _getCurrentList() {
    List<String> base;
    switch (_selectedIndex) {
      case 0:
        base = _allFiles;
        break;
      case 1:
        base = _recent;
        break;
      case 2:
        base = _favorites;
        break;
      case 3:
        return [];
      default:
        base = [];
    }

    if (_searchQuery.isNotEmpty) {
      base = base
          .where((path) =>
              p.basename(path).toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    if (_sortMode == 'Size') {
      base.sort((a, b) {
        try {
          return File(b).lengthSync().compareTo(File(a).lengthSync());
        } catch (e) {
          return 0;
        }
      });
    } else if (_sortMode == 'Date') {
      base.sort((a, b) {
        try {
          return File(b).lastModifiedSync().compareTo(File(a).lastModifiedSync());
        } catch (e) {
          return 0;
        }
      });
    } else {
      base.sort((a, b) => p.basename(a).compareTo(p.basename(b)));
    }

    return base;
  }

  // Banner reklam widget'ı
  Widget _buildBannerAd() {
    if (_isBannerAdReady && _bannerAd != null) {
      return Container(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return Container(
        height: 50,
        alignment: Alignment.center,
        child: const Text('Reklam yükleniyor...'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = _getCurrentList();
    final titles = [
      AppLocalizations.of(context).translate('all_files'),
      AppLocalizations.of(context).translate('recent'),
      AppLocalizations.of(context).translate('favorites'),
      AppLocalizations.of(context).translate('tools')
    ];

    final filteredLanguages = _languageSearchQuery.isEmpty
        ? _languages
        : _languages.where((lang) =>
            lang['name']!.toLowerCase().contains(_languageSearchQuery) ||
            lang['native']!.toLowerCase().contains(_languageSearchQuery) ||
            lang['code']!.toLowerCase().contains(_languageSearchQuery))
        .toList();

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context).translate('search_files'),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: widget.dark ? Colors.white70 : Colors.black54,
                  ),
                ),
                style: TextStyle(
                  color: widget.dark ? Colors.white : Colors.black,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titles[_selectedIndex]),
                  if (_selectedIndex == 0 && _currentPath != null && _baseDir != null && _currentPath != _baseDir!.path)
                    Text(
                      p.relative(_currentPath!, from: _baseDir!.path),
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _stopSearch,
              )
            : (_selectedIndex == 0 && _currentPath != null && _baseDir != null && _currentPath != _baseDir!.path && !_selectionMode
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _goBack,
                  )
                : IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  )),
        actions: _isSearching
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                ),
              ]
            : (_selectionMode ? _buildSelectionModeActions() : _buildNormalModeActions()),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.red),
              child: Text('PDF Reader & Manager',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),

            // LANGUAGE
            ExpansionTile(
              leading: const Icon(Icons.language),
              title: Text(AppLocalizations.of(context).translate('language')),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                  child: TextField(
                    controller: _languageSearchController,
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).translate('search_language'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                      isDense: true,
                    ),
                  ),
                ),
                SizedBox(
                  height: 300,
                  child: filteredLanguages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context).translate('no_language_found'),
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filteredLanguages.length,
                          itemBuilder: (context, index) {
                            final language = filteredLanguages[index];
                            final code = language['code']!;
                            final locale = _getLocaleFromCode(code);
                            final isCurrent = widget.currentLocale.toString() == code || widget.currentLocale.toString().startsWith('$code-');
                            return ListTile(
                              leading: const Icon(Icons.flag),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(language['native']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text(language['name']!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                              trailing: isCurrent ? const Icon(Icons.check, color: Colors.green) : null,
                              onTap: () async {
                                await widget.setLocale(locale);
                                _languageSearchController.clear();
                                _languageSearchQuery = '';
                                _scaffoldKey.currentState?.closeDrawer();
                                setState(() {});
                              },
                            );
                          },
                        ),
                ),
              ],
            ),

            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(AppLocalizations.of(context).translate('about')),
              onTap: () {
                _scaffoldKey.currentState?.closeDrawer();
                showAboutDialog(
                  context: context,
                  applicationName: 'PDF Reader & Manager',
                  applicationVersion: '1.0.0 (1.0)',
                  applicationLegalese: AppLocalizations.of(context).translate('all_work_local'),
                  children: [
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).translate('developed_by'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: Text(AppLocalizations.of(context).translate('import_file')),
              onTap: _importFile,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.brightness_6),
              title: Text(AppLocalizations.of(context).translate('dark_light_mode')),
              value: widget.dark,
              onChanged: widget.onThemeChanged,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _selectedIndex == 3
                ? ToolsPage(dark: widget.dark)
                : (_selectedIndex == 0 ? _buildAllFilesView(files) : _buildListView(files)),
          ),
          // Banner reklam - her sayfada en altta gösterilecek
          if (_selectedIndex != 3) // Tools sayfasında reklam gösterme
            _buildBannerAd(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() {
            _selectedIndex = i;
            _selectionMode = false;
            _selectedFiles.clear();
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.folder),
            selectedIcon: const Icon(Icons.folder),
            label: AppLocalizations.of(context).translate('all_files'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            selectedIcon: const Icon(Icons.history),
            label: AppLocalizations.of(context).translate('recent'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_border),
            selectedIcon: const Icon(Icons.favorite),
            label: AppLocalizations.of(context).translate('favorites'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.build),
            selectedIcon: const Icon(Icons.build),
            label: AppLocalizations.of(context).translate('tools'),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0 ? FloatingActionButton(
        onPressed: _importFile,
        backgroundColor: Colors.red,
        child: const Icon(Icons.add, color: Colors.white),
      ) : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  List<Widget> _buildNormalModeActions() {
    return [
      if (_selectedIndex != 3)
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: _startSearch,
        ),

      if (_selectedIndex == 0)
        IconButton(
          icon: const Icon(Icons.create_new_folder_outlined),
          onPressed: _createFolder,
        ),

      if (_selectedIndex != 3)
        PopupMenuButton<String>(
          icon: const Icon(Icons.sort),
          onSelected: (val) => setState(() => _sortMode = val),
          itemBuilder: (_) => [
            PopupMenuItem(value: 'Name', child: Text(AppLocalizations.of(context).translate('sort_by_name'))),
            PopupMenuItem(value: 'Size', child: Text(AppLocalizations.of(context).translate('sort_by_size'))),
            PopupMenuItem(value: 'Date', child: Text(AppLocalizations.of(context).translate('sort_by_date'))),
          ],
        ),

      if (_selectedIndex != 3)
        IconButton(
          icon: const Icon(Icons.select_all_outlined),
          onPressed: () => setState(() => _selectionMode = true),
        ),
    ];
  }

  List<Widget> _buildSelectionModeActions() {
    return [
      IconButton(
        icon: const Icon(Icons.share),
        onPressed: _selectedFiles.isNotEmpty ? _shareSelectedFiles : null,
      ),
      IconButton(
        icon: const Icon(Icons.print),
        onPressed: _selectedFiles.isNotEmpty ? _printSelectedFiles : null,
      ),
      IconButton(
        icon: const Icon(Icons.delete),
        onPressed: _selectedFiles.isNotEmpty ? _deleteSelectedFiles : null,
      ),
      IconButton(
        icon: Icon(_selectedFiles.length == _allFiles.length ? Icons.deselect : Icons.select_all),
        onPressed: _selectAllFiles,
      ),
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(() {
          _selectionMode = false;
          _selectedFiles.clear();
        }),
      ),
    ];
  }

  Widget _buildAllFilesView(List<String> files) {
    if (_searchQuery.isNotEmpty && files.isEmpty && _folders.where((folderPath) =>
        p.basename(folderPath).toLowerCase().contains(_searchQuery.toLowerCase())
    ).isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '${AppLocalizations.of(context).translate('no_files_found')} "$_searchQuery"',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        ..._folders.where((folderPath) =>
            _searchQuery.isEmpty ||
                p.basename(folderPath).toLowerCase().contains(_searchQuery.toLowerCase())
        ).map((folderPath) => _buildFolderItem(folderPath)),

        ...files.map((filePath) => _buildFileItem(filePath)),
      ],
    );
  }

  Widget _buildFolderItem(String folderPath) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getFolderItemCount(folderPath),
      builder: (context, snapshot) {
        final itemCount = snapshot.hasData ? (snapshot.data!['count'] ?? 0) : 0;
        final dateStr = snapshot.hasData ? (snapshot.data!['date'] ?? '') : '';
        final timeStr = snapshot.hasData ? (snapshot.data!['time'] ?? '') : '';

        final subtitleText = dateStr.isNotEmpty && timeStr.isNotEmpty
            ? '• $itemCount  • $dateStr  • $timeStr'
            : '• $itemCount';

        return ListTile(
          leading: Icon(Icons.folder, color: _getFolderColor(folderPath)),
          title: Text(p.basename(folderPath)),
          subtitle: Text(subtitleText),
          trailing: _selectionMode ? null : PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'rename') {
                _renameFolder(folderPath);
              } else if (value == 'color') {
                _changeFolderColor(folderPath);
              } else if (value == 'delete') {
                _deleteFolder(folderPath);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'rename', child: Text(AppLocalizations.of(context).translate('rename'))),
              PopupMenuItem(value: 'color', child: Text(AppLocalizations.of(context).translate('change_color'))),
              PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context).translate('delete'))),
            ],
          ),
          onTap: () {
            if (_selectionMode) return;
            _enterFolder(folderPath);
          },
        );
      },
    );
  }

  Widget _buildListView(List<String> files) {
    if (_searchQuery.isNotEmpty && files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '${AppLocalizations.of(context).translate('no_files_found')} "$_searchQuery"',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: files.length,
      itemBuilder: (_, i) => _buildFileItem(files[i]),
    );
  }

  Widget _buildFileItem(String filePath) {
    try {
      final f = File(filePath);
      final sizeMb = (f.lengthSync() / 1024 / 1024).toStringAsFixed(2);
      final modified =
          DateFormat('dd.MM.yyyy HH:mm').format(f.lastModifiedSync());

      return ListTile(
        leading: _selectionMode
            ? Checkbox(
                value: _selectedFiles.contains(filePath),
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedFiles.add(filePath);
                    } else {
                      _selectedFiles.remove(filePath);
                    }
                  });
                },
              )
            : const Icon(Icons.picture_as_pdf, color: Colors.red),
        title: Text(p.basename(filePath)),
        subtitle: Text('$sizeMb MB • $modified'),
        trailing: _selectionMode ? null : Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                _favorites.contains(filePath)
                    ? Icons.favorite
                    : Icons.favorite_border,
                color: Colors.red,
              ),
              onPressed: () => _toggleFavorite(filePath),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'rename') {
                  _renameFile(filePath);
                } else if (value == 'edit') {
                  _openViewer(filePath);
                } else if (value == 'print') {
                  _printFile(filePath);
                } else if (value == 'share') {
                  _shareFile(filePath);
                } else if (value == 'move') {
                  _moveFile(filePath);
                } else if (value == 'delete') {
                  _deleteFile(filePath);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(AppLocalizations.of(context).translate('rename'))),
                PopupMenuItem(value: 'edit', child: Text(AppLocalizations.of(context).translate('edit'))),
                PopupMenuItem(value: 'print', child: Text(AppLocalizations.of(context).translate('print'))),
                PopupMenuItem(value: 'share', child: Text(AppLocalizations.of(context).translate('share'))),
                PopupMenuItem(value: 'move', child: Text(AppLocalizations.of(context).translate('move'))),
                PopupMenuItem(value: 'delete', child: Text(AppLocalizations.of(context).translate('delete'))),
              ],
            ),
          ],
        ),
        onTap: () {
          if (_selectionMode) {
            setState(() {
              _selectedFiles.contains(filePath)
                  ? _selectedFiles.remove(filePath)
                  : _selectedFiles.add(filePath);
            });
          } else {
            _openViewer(filePath);
          }
        },
        onLongPress: () {
          setState(() {
            _selectionMode = true;
            _selectedFiles.add(filePath);
          });
        },
      );
    } catch (e) {
      print('❌ Error building file item: $e');
      return ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: Text(p.basename(filePath)),
        subtitle: Text('Error: $e'),
      );
    }
  }
}

// ViewerScreen (Aynı kalıyor)
class ViewerScreen extends StatefulWidget {
  final File file;
  final String fileName;
  final bool dark;
  final String locale;

  const ViewerScreen({
    super.key,
    required this.file,
    required this.fileName,
    required this.dark,
    required this.locale,
  });

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  InAppWebViewController? _controller;
  bool _loaded = false;

  String _viewerUrl() {
    try {
      String fileUri = Uri.file(widget.file.path).toString();
      
      print('📁 File URI: $fileUri');
      print('📁 File path: ${widget.file.path}');
      print('📁 File exists: ${widget.file.existsSync()}');

      final dark = widget.dark ? 'true' : 'false';
      final locale = widget.locale;
      
      final encodedFileUri = Uri.encodeComponent(fileUri);
      final viewerUrl = 'file:///android_asset/flutter_assets/assets/web/viewer.html?file=$encodedFileUri&locale=$locale&dark=$dark';
      
      print('🌐 Viewer URL: $viewerUrl');
      
      return viewerUrl;
    } catch (e) {
      print('❌ URI creation error: $e');
      return 'file:///android_asset/flutter_assets/assets/web/viewer.html';
    }
  }

  @override
  void initState() {
    super.initState();
    _checkPdfFile();
  }

  void _checkPdfFile() {
    print('🔍 Checking PDF file...');
    print('📁 Path: ${widget.file.path}');
    print('✅ Exists: ${widget.file.existsSync()}');
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
            onPressed: () async {
              try {
                final bytes = await widget.file.readAsBytes();
                await Printing.layoutPdf(onLayout: (_) => bytes);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Yazdırma hatası: $e')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              try {
                Share.shareXFiles([XFile(widget.file.path)]);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('❌ Paylaşım hatası: $e')),
                );
              }
            },
          ),
        ],
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
              useHybridComposition: true,
              clearCache: true,
              cacheMode: CacheMode.LOAD_DEFAULT,
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              print('✅ WebView created');
            },
            onLoadStart: (controller, url) {
              print('🌐 Loading started: $url');
            },
            onLoadStop: (controller, url) {
              print('✅ Loading completed: $url');
              setState(() => _loaded = true);
            },
            onLoadError: (controller, url, code, message) {
              print('❌ Load error: $message (code: $code)');
            },
          ),
          if (!_loaded)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.red),
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
