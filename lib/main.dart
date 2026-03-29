import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'providers/bluetooth_provider.dart';
import 'ui/dashboard_screen.dart';
import 'services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable FBP logging to reduce noise in the console
  FlutterBluePlus.setLogLevel(LogLevel.none);
  
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BluetoothProvider())],
      child: const PerfumeControlApp(),
    ),
  );
}

class PerfumeControlApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  const PerfumeControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LI Perfume',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1),
          brightness: Brightness.dark,
        ),
      ),
      home: Consumer<BluetoothProvider>(
        builder: (context, provider, child) => DashboardScreen(provider: provider),
      ),
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return _AppUpdateWrapper(child: child!);
      },
    );
  }
}

class _AppUpdateWrapper extends StatefulWidget {
  final Widget child;
  const _AppUpdateWrapper({required this.child});

  @override
  State<_AppUpdateWrapper> createState() => _AppUpdateWrapperState();
}

class _AppUpdateWrapperState extends State<_AppUpdateWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  void _checkForUpdate() async {
    final info = await UpdateService.checkForUpdate();
    if (info.hasUpdate && mounted) {
      _showUpdateDialog(info);
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    // Use the global navigator key to get the correct context for showDialog
    final navContext = PerfumeControlApp.navigatorKey.currentContext;
    if (navContext == null) return;

    showDialog(
      context: navContext,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Обновление'),
        content: Text(
          'Доступна версия ${info.latestVersion}\n\n${info.releaseNotes.isNotEmpty ? info.releaseNotes : "Нажмите скачать для обновления"}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Позже'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              UpdateService.openDownload(info.downloadUrl);
            },
            child: const Text('Скачать'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
