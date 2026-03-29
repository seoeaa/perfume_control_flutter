import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/bluetooth_provider.dart';
import 'ui/dashboard_screen.dart';
import 'services/update_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => BluetoothProvider())],
      child: const PerfumeControlApp(),
    ),
  );
}

class PerfumeControlApp extends StatelessWidget {
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
      home: const DashboardScreen(),
      builder: (context, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkForUpdate(context);
        });
        return child!;
      },
    );
  }

  void _checkForUpdate(BuildContext context) async {
    final info = await UpdateService.checkForUpdate();
    if (info.hasUpdate && context.mounted) {
      showUpdateDialog(context, info);
    }
  }

  void showUpdateDialog(BuildContext context, UpdateInfo info) {
    showDialog(
      context: context,
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
}
