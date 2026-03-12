import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class UpdateService {
  static const String _updateUrl =
      'https://api.github.com/repos/johnelson12345/tabulation_systemv7/releases/latest';
  static const String _lastCheckedKey = 'last_update_check';
  static const String _currentVersionKey = 'current_version';
  static const String _updateAvailableKey = 'update_available';
  static const String _updateDataKey = 'update_data';

  Timer? _periodicTimer;

  Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final response = await http.get(Uri.parse(_updateUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String?;
        final releaseNotes = data['body'] as String?;
        final downloadUrl = data['html_url'] as String?;

        if (latestVersion != null) {
          final packageInfo = await PackageInfo.fromPlatform();
          final currentVersion = packageInfo.version;

          // Store current version for future checks
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_currentVersionKey, currentVersion);

          // Check if there's a new version
          if (_isNewerVersion(currentVersion, latestVersion)) {
            final updateData = {
              'hasUpdate': true,
              'latestVersion': latestVersion,
              'currentVersion': currentVersion,
              'releaseNotes': releaseNotes,
              'downloadUrl': downloadUrl,
            };

            // Store update data
            await prefs.setBool(_updateAvailableKey, true);
            await prefs.setString(_updateDataKey, json.encode(updateData));

            return updateData;
          } else {
            // No update available, clear stored data
            await prefs.setBool(_updateAvailableKey, false);
            await prefs.remove(_updateDataKey);
          }
        }
      }
    } catch (e) {
      print('Error checking for updates: $e');
    }
    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts =
        latest.replaceAll('v', '').split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length && i < latestParts.length; i++) {
      if (latestParts[i] > currentParts[i]) {
        return true;
      } else if (latestParts[i] < currentParts[i]) {
        return false;
      }
    }
    return latestParts.length > currentParts.length;
  }

  Future<void> markUpdateChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckedKey, DateTime.now().toIso8601String());
  }

  Future<bool> shouldCheckForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final lastChecked = prefs.getString(_lastCheckedKey);
    if (lastChecked == null) return true;

    final lastCheckedDate = DateTime.parse(lastChecked);
    final now = DateTime.now();
    final difference = now.difference(lastCheckedDate);

    // Check for updates once every 6 hours for more frequent checks
    return difference.inHours >= 6;
  }

  Future<Map<String, dynamic>?> getStoredUpdateData() async {
    final prefs = await SharedPreferences.getInstance();
    final hasUpdate = prefs.getBool(_updateAvailableKey) ?? false;
    if (hasUpdate) {
      final updateDataString = prefs.getString(_updateDataKey);
      if (updateDataString != null) {
        return json.decode(updateDataString);
      }
    }
    return null;
  }

  Future<String?> getStoredCurrentVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_currentVersionKey);
  }

  void startPeriodicUpdateCheck() {
    // Check immediately on start
    checkForUpdates().then((_) => markUpdateChecked());

    // Then check every 6 hours
    _periodicTimer = Timer.periodic(const Duration(hours: 6), (timer) async {
      if (await shouldCheckForUpdates()) {
        await checkForUpdates();
        await markUpdateChecked();
      }
    });
  }

  void stopPeriodicUpdateCheck() {
    _periodicTimer?.cancel();
  }
}
