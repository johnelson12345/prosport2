import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/admin_dashboard.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/results_rankings_admin.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/reports_analytics.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/results_mngmt.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/tabulator_medal_tally.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/announcements.dart';
import 'package:tabulation_systemv7/services/auth.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';
import 'package:tabulation_systemv7/authentication/login.dart';
import 'package:tabulation_systemv7/widgets/update_notification.dart';

//big filedasdasddasda
class TabulatorMain extends StatefulWidget {
  const TabulatorMain({super.key});

  @override
  State<TabulatorMain> createState() => _TabulatorMainState();
}

class _TabulatorMainState extends State<TabulatorMain>
    with SingleTickerProviderStateMixin {
  String _selectedScreen = 'Dashboard';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _menuItems = [
    'Dashboard',
    'Results Mngmt',
    'Medal Tally',
    'Results and Rankings',
    'Reports',
  ];
  List<String> _filteredMenuItems = [];
  bool _isDrawerExpanded = true;

  User? _currentUser;
  String? _customPhotoURL;
  String? _activeSportsEventName;

  @override
  void initState() {
    super.initState();
    _filteredMenuItems = List.from(_menuItems);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();

    _searchController.addListener(() {
      _filterMenuItems();
    });

    _loadCurrentUser();
    _loadActiveSportsEvent();
  }

  void _loadCurrentUser() {
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadCustomPhotoURL();
    setState(() {});
  }

  Future<void> _loadCustomPhotoURL() async {
    if (_currentUser != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get()
            .timeout(const Duration(seconds: 5));
        if (userDoc.exists && userDoc.data() != null) {
          _customPhotoURL = userDoc.data()!['photoURL'];
          setState(() {});
        }
      } catch (e) {
        debugPrint('Error loading custom photoURL: $e');
      }
    }
  }

  ImageProvider? _getProfileImage() {
    if (_customPhotoURL != null) {
      try {
        // Check if it's base64
        if (_customPhotoURL!.startsWith('data:image')) {
          final base64String = _customPhotoURL!.split(',').last;
          // Clean up the base64 string - remove any whitespace or hidden characters
          final cleanBase64 = base64String.replaceAll(RegExp(r'\s'), '');
          final bytes = base64Decode(cleanBase64);
          debugPrint(
              'Successfully decoded base64 image, size: ${bytes.length} bytes');
          return MemoryImage(bytes);
        } else {
          return NetworkImage(_customPhotoURL!);
        }
      } catch (e) {
        debugPrint('Error decoding profile image: $e');
        return null;
      }
    } else if (_currentUser?.photoURL != null) {
      return NetworkImage(_currentUser!.photoURL!);
    }
    return null;
  }

  Future<void> _loadActiveSportsEvent() async {
    try {
      final sportsEventService = SportsEventService();
      final activeEventId = await sportsEventService.getActiveSportsEventId();
      if (activeEventId != null) {
        final eventDoc = await FirebaseFirestore.instance
            .collection('sports_events')
            .doc(activeEventId)
            .get();
        if (eventDoc.exists) {
          _activeSportsEventName = eventDoc.data()?['name'] as String?;
        }
      } else {
        _activeSportsEventName = null;
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error loading active sports event: $e');
      _activeSportsEventName = null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterMenuItems() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMenuItems = _menuItems
          .where((item) => item.toLowerCase().contains(query))
          .toList();
    });
  }

  Widget _buildFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Colors.grey,
            width: 0.5,
          ),
        ),
      ),
      child: const Center(
        child: Text(
          'PROSPORT EVALUATION SYSTEM © 2025 ALL RIGHTS RESERVED',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _getScreenWidget() {
    switch (_selectedScreen) {
      case 'Announcements':
        return AnnouncementsScreen();
      case 'Results Mngmt':
        return const ResultsVerification();
      case 'Reports':
        return const ReportsAnalytics();
      case 'Results and Rankings':
        return const ResultsAndRankingsAdminPage();

      case 'Medal Tally':
      return const TabulatorMedalTally();

        case 'Dashboard':
          return const AdminDashboard();
      default:
        return const Center(
          child: Text(
            'Welcome, Tabulator!',
            style: TextStyle(fontSize: 24),
          ),
        );
    }
  }

  void _onMenuSelected(String screen) async {
    setState(() {
      _selectedScreen = screen;
      _animationController.reset();
      _animationController.forward();
    });
    if (MediaQuery.of(context).size.width < 600) {
      Navigator.pop(context); // Close drawer on small screens
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color.fromARGB(255, 5, 18, 37),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 5, 18, 37),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.emoji_events,
                      color: Color.fromARGB(255, 5, 18, 37),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'PROSPORT EVAL',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search menu',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
              child: Text(
                'MAIN MENU',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredMenuItems.length,
                itemBuilder: (context, index) {
                  String item = _filteredMenuItems[index];
                  IconData iconData;
                  switch (item) {
                    case 'Dashboard':
                      iconData = Icons.dashboard;
                      break;
                    case 'Results Mngmt':
                      iconData = Icons.assignment;
                      break;
                    case 'Medal Tally':
                      iconData = Icons.workspace_premium;
                      break;
                    case 'Reports':
                      iconData = Icons.report;
                      break;
                    case 'Results and Rankings':
                      iconData = Icons.verified;
                      break;
                    default:
                      iconData = Icons.circle;
                  }

                  return Container(
                    color: _selectedScreen == item
                        ? Colors.white
                        : Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        iconData,
                        color: _selectedScreen == item
                            ? Colors.white
                            : const Color.fromARGB(255, 255, 255, 255),
                      ),
                      title: Text(
                        item,
                        style: TextStyle(
                          color: _selectedScreen == item
                              ? Colors.black
                              : Colors.white,
                          fontWeight: _selectedScreen == item
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      selected: _selectedScreen == item,
                      onTap: () => _onMenuSelected(item),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
            // User Profile Section - Above Logout
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Profile Image/Logo
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      image: _getProfileImage() != null
                          ? DecorationImage(
                              image: _getProfileImage()!,
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: _getProfileImage() == null
                        ? const Icon(
                            Icons.person,
                            color: Color.fromARGB(255, 5, 18, 37),
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // User Name
                        Text(
                          _currentUser?.displayName ?? 'User Name',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // User Email
                        Text(
                          _currentUser?.email ?? 'email@example.com',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Tournament Official Label
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Tabulator',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title:
                  const Text('Logout', style: TextStyle(color: Colors.white)),
              onTap: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AuthService().signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: _isDrawerExpanded ? 280 : 80,
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 5, 18, 37),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(_isDrawerExpanded ? 16 : 8),
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 5, 18, 37),
              ),
              child: _isDrawerExpanded
                  ? Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: Color.fromARGB(255, 5, 18, 37),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'PROSPORT EVAL',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isDrawerExpanded = !_isDrawerExpanded;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.emoji_events,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          icon: const Icon(Icons.menu, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isDrawerExpanded = !_isDrawerExpanded;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
            ),
            if (_isDrawerExpanded)
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  'MAIN MENU',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _filteredMenuItems.length,
                itemBuilder: (context, index) {
                  String item = _filteredMenuItems[index];
                  IconData iconData;
                  switch (item) {
                    case 'Dashboard':
                      iconData = Icons.dashboard;
                      break;
                    case 'Results Mngmt':
                      iconData = Icons.verified;
                      break;
                    case 'Medal Tally':
                      iconData = Icons.workspace_premium;
                      break;
                    case 'Reports':
                      iconData = Icons.report;
                      break;
                    case 'Results and Rankings':
                      iconData = Icons.verified;
                      break;
                    default:
                      iconData = Icons.circle;
                  }

                  return Container(
                    color: _selectedScreen == item
                        ? Colors.white
                        : Colors.transparent,
                    child: ListTile(
                      leading: Icon(
                        iconData,
                        color: _selectedScreen == item
                            ? const Color.fromARGB(255, 0, 0, 0)
                            : const Color.fromARGB(255, 255, 255, 255),
                      ),
                      title: _isDrawerExpanded
                          ? Text(
                              item,
                              style: TextStyle(
                                color: _selectedScreen == item
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: _selectedScreen == item
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            )
                          : null,
                      selected: _selectedScreen == item,
                      onTap: () => _onMenuSelected(item),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: _isDrawerExpanded
                          ? const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8)
                          : const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                    ),
                  );
                },
              ),
            ),
            // User Profile Section - Above Logout
            if (_isDrawerExpanded)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    // Profile Image/Logo
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        image: _getProfileImage() != null
                            ? DecorationImage(
                                image: _getProfileImage()!,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _getProfileImage() == null
                          ? const Icon(
                              Icons.person,
                              color: Color.fromARGB(255, 5, 18, 37),
                              size: 22,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // User Name
                          Text(
                            _currentUser?.displayName ?? 'User Name',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          // User Email
                          Text(
                            _currentUser?.email ?? '',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Tournament Official Label
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Tabulator',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: _isDrawerExpanded
                  ? const Text('Logout', style: TextStyle(color: Colors.white))
                  : null,
              onTap: () async {
                bool? confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await AuthService().signOut();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                }
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: _isDrawerExpanded
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 8)
                  : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth >= 600;

    if (isLargeScreen) {
      return Scaffold(
        body: Row(
          children: [
            _buildSidebar(),
            Expanded(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 26, 53, 94),
                    ),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            "Tabulator - $_selectedScreen",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _activeSportsEventName != null
                                  ? Colors.deepOrange.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: _activeSportsEventName != null
                                      ? Colors.deepOrange
                                      : Colors.grey,
                                  width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _activeSportsEventName != null
                                      ? Icons.emoji_events
                                      : Icons.event_busy,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _activeSportsEventName != null
                                        ? "Active Event: $_activeSportsEventName"
                                        : "No Active Event",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const UpdateNotification(),
                  Expanded(child: _getScreenWidget()),
                  _buildFooter(),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        appBar: AppBar(
          title: const SizedBox.shrink(),
          centerTitle: true,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 5, 18, 37),
            ),
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        drawer: _buildDrawer(),
        body: Column(
          children: [
            const UpdateNotification(),
            Expanded(child: _getScreenWidget()),
          ],
        ),
      );
    }
  }
}
