import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final bool hasUpdate;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.hasUpdate,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateService {
  static const String _repo = 'seoeaa/perfume_control_flutter';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  // Version injected at build time via --dart-define=APP_VERSION=0.1.1
  static const String _buildVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '0.1.0',
  );

  static String get currentVersion => _buildVersion;

  static Future<UpdateInfo> checkForUpdate() async {
    final currentVersion = _buildVersion;

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        return UpdateInfo(
          latestVersion: currentVersion,
          currentVersion: currentVersion,
          hasUpdate: false,
          downloadUrl: '',
          releaseNotes: '',
        );
      }

      final data = json.decode(response.body);
      final tag = (data['tag_name'] as String?) ?? currentVersion;
      final latestVersion = tag.startsWith('v') ? tag.substring(1) : tag;

      // Find APK asset
      final assets = (data['assets'] as List?) ?? [];
      String downloadUrl = '';
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.endsWith('.apk')) {
          downloadUrl = (asset['browser_download_url'] as String?) ?? '';
          break;
        }
      }

      // If no APK asset, use release page
      if (downloadUrl.isEmpty) {
        downloadUrl =
            (data['html_url'] as String?) ??
            'https://github.com/$_repo/releases/latest';
      }

      final releaseNotes = (data['body'] as String?) ?? '';

      final hasUpdate = _compareVersions(latestVersion, currentVersion);

      return UpdateInfo(
        latestVersion: latestVersion,
        currentVersion: currentVersion,
        hasUpdate: hasUpdate,
        downloadUrl: downloadUrl,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      if (kDebugMode) print('Update check error: $e');
      return UpdateInfo(
        latestVersion: currentVersion,
        currentVersion: currentVersion,
        hasUpdate: false,
        downloadUrl: '',
        releaseNotes: '',
      );
    }
  }

  static bool _compareVersions(String latest, String current) {
    try {
      final latestParts = latest.split('.').map(int.parse).toList();
      final currentParts = current.split('.').map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<void> openDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
