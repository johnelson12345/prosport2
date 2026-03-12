import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tabulation_systemv7/services/auth.dart';
import 'package:tabulation_systemv7/authentication/login.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  _AccountsScreenState createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  String? _customPhotoURL;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = FirebaseAuth.instance.currentUser;
      if (_currentUser != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get()
            .timeout(const Duration(seconds: 5));
        if (userDoc.exists) {
          _customPhotoURL = userDoc['photoURL'];
        }
      }
    } catch (e) {
      // Handle error silently or log it
    } finally {
      setState(() => _isLoading = false);
    }
  }

  ImageProvider? _getProfileImage() {
    if (_customPhotoURL != null) {
      // Check if it's base64
      if (_customPhotoURL!.startsWith('data:image')) {
        final base64String = _customPhotoURL!.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } else {
        return NetworkImage(_customPhotoURL!);
      }
    } else if (_currentUser!.photoURL != null) {
      return NetworkImage(_currentUser!.photoURL!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Profile',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepOrange, Colors.orange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 60, color: Colors.grey.shade400),
                      const SizedBox(height: 20),
                      Text(
                        'No user logged in',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.deepOrange, Colors.orange.shade400],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              backgroundImage: _getProfileImage(),
                              child: (_customPhotoURL == null &&
                                      _currentUser!.photoURL == null)
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: Colors.grey.shade600,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.deepOrange,
                                  size: 24,
                                ),
                                onPressed: _changeProfilePicture,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: CircleBorder(),
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentUser!.displayName ?? 'No display name',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit,
                                color: Colors.deepOrange),
                            onPressed: _editDisplayName,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentUser!.email ?? 'No email provided',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildInfoCard(
                        icon: Icons.email,
                        title: 'Email Verified',
                        value: _currentUser!.emailVerified ? 'Yes' : 'No',
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        icon: Icons.calendar_today,
                        title: 'Account Created',
                        value: _currentUser!.metadata.creationTime
                                ?.toLocal()
                                .toString()
                                .split(' ')[0] ??
                            'Unknown',
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _authService.signOut();
                            if (!mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const LoginPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _editDisplayName() async {
    final TextEditingController nameController =
        TextEditingController(text: _currentUser!.displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Enter new display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(nameController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await _currentUser!.updateDisplayName(result);
        await _loadCurrentUser(); // Refresh user data
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update display name: $e')),
        );
      }
    }
  }

  Future<void> _changeProfilePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 300, // Compress image
      maxHeight: 300,
      imageQuality: 70, // Reduce quality
    );

    if (image != null) {
      try {
        setState(() => _isLoading = true);

        debugPrint(
            'Starting profile picture upload for user: ${_currentUser!.uid}');

        // Convert image to base64
        final bytes = await image.readAsBytes();
        final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        debugPrint('Image converted to base64 successfully');

        // Update Firestore user document with base64 image
        debugPrint('Updating Firestore user document...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .update({'photoURL': base64Image}).timeout(
                const Duration(seconds: 10));

        await _loadCurrentUser(); // Refresh user data

        debugPrint('Profile picture update completed successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated successfully')),
        );
      } catch (e) {
        debugPrint('Error updating profile picture: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile picture: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.deepOrange,
              size: 24,
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
