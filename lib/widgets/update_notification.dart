import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tabulation_systemv7/services/update_service.dart';

class UpdateNotification extends StatefulWidget {
  const UpdateNotification({super.key});

  @override
  State<UpdateNotification> createState() => _UpdateNotificationState();
}

class _UpdateNotificationState extends State<UpdateNotification> {
  final UpdateService _updateService = UpdateService();
  Map<String, dynamic>? _updateInfo;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadStoredUpdateData();
  }

  Future<void> _loadStoredUpdateData() async {
    final storedData = await _updateService.getStoredUpdateData();
    if (storedData != null) {
      setState(() => _updateInfo = storedData);
    } else {
      _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    if (!await _updateService.shouldCheckForUpdates()) return;

    setState(() => _isChecking = true);
    final updateInfo = await _updateService.checkForUpdates();
    setState(() {
      _updateInfo = updateInfo;
      _isChecking = false;
    });

    if (updateInfo != null) {
      await _updateService.markUpdateChecked();
    }
  }

  Future<void> _openDownloadUrl() async {
    if (_updateInfo?['downloadUrl'] != null) {
      final url = Uri.parse(_updateInfo!['downloadUrl']);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking || _updateInfo == null || !_updateInfo!['hasUpdate']) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.update, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _updateInfo = null),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Version ${_updateInfo!['latestVersion']} is available. You are currently on version ${_updateInfo!['currentVersion']}.',
            style: TextStyle(color: Colors.blue.shade600),
          ),
          if (_updateInfo!['releaseNotes'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'What\'s new:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _updateInfo!['releaseNotes'],
              style: TextStyle(color: Colors.blue.shade600),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => setState(() => _updateInfo = null),
                child: const Text('Remind Me Later'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _openDownloadUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Download Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
