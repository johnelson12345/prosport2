import 'package:flutter/material.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/all_tournaments.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/announcement.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/tournament_matrix_view.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/reports_analytics.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/results_mngmt.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/view_rewards.dart';
import 'package:tabulation_systemv7/screens_roles/viewer/accounts.dart';
import 'package:tabulation_systemv7/services/tabulator_dashboard_service.dart';
import 'package:tabulation_systemv7/services/auth.dart';
import 'package:tabulation_systemv7/authentication/login.dart';

class ViewerMainScreen extends StatefulWidget {
  const ViewerMainScreen({super.key});

  @override
  State<ViewerMainScreen> createState() => _ViewerMainScreenState();
}

class _ViewerMainScreenState extends State<ViewerMainScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleLogout(BuildContext context) async {
    final authService = AuthService();
    await authService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  static final List<Widget> _widgetOptions = <Widget>[
    const TabulatorHome(),
    // const SportsScreen(),
    const ResultsVerification(),
    const ReportsAnalytics(),
    const TabulatorSettings(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Viewer ",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false, // Prevent leading arrow
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                Colors.orange.shade600,
                Colors.deepOrange.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon:
                const Icon(Icons.account_circle_outlined, color: Colors.white),
            onSelected: (String value) {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AccountsScreen()),
                );
              } else if (value == 'logout') {
                _handleLogout(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person, color: Colors.deepPurple),
                  title: Text('Profile'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Logout'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Container(
          key: ValueKey<int>(_selectedIndex),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.deepPurple.shade50, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: _widgetOptions.elementAt(_selectedIndex),
        ),
      ),
    );
  }
}

// Tabulator Home Screen
class TabulatorHome extends StatelessWidget {
  const TabulatorHome({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome, Viewer!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explore live tournament results, brackets, and updates here.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildQuickActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<Map<String, dynamic>>(
              stream:
                  TabulatorDashboardService().getDashboardStatisticsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final stats = snapshot.data!;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard(
                        'Active Tournaments',
                        stats['activeTournaments'].toString(),
                        Icons.sports,
                      ),
                      _buildStatCard(
                        'Total Matches',
                        stats['totalMatches'].toString(),
                        Icons.sports_score,
                      ),
                      _buildStatCard(
                        'Pending Scores',
                        stats['pendingScores'].toString(),
                        Icons.pending,
                      ),
                    ],
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
                } else {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.deepPurple, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple,
          ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            // _buildActionCard(
            //   'Categories',
            //   Icons.score,
            //   Colors.green,
            //   () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const SportsScreen(),
            //       ),
            //     );
            //   },
            // ),
            _buildActionCard(
              'View Results',
              Icons.emoji_events,
              Colors.orange,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BracketsNewScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'Generate Reports',
              Icons.analytics,
              Colors.blue,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportsAnalytics(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'View Rewards',
              Icons.military_tech,
              Colors.purple,
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ViewRewardsScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'View Schedules',
              Icons.schedule,
              const Color.fromARGB(255, 174, 176, 39),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TournamentCalendarScreen(),
                  ),
                );
              },
            ),
            _buildActionCard(
              'View Announcements',
              Icons.schedule,
              const Color.fromARGB(255, 134, 49, 10),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnnouncementScreen(),
                  ),
                );
              },
            ),
            // _buildActionCard(
            //   'Manage Teams',
            //   Icons.people,
            //   Colors.purple,
            //   () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const ParticipantsManagementScreen(),
            //       ),
            //     );
            //   },
            // ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder screens for other tabulator pages
class TabulatorScoring extends StatelessWidget {
  const TabulatorScoring({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Scoring Interface',
        style: TextStyle(fontSize: 24, color: Colors.deepPurple),
      ),
    );
  }
}

class TabulatorResults extends StatelessWidget {
  const TabulatorResults({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Results Dashboard',
        style: TextStyle(fontSize: 24, color: Colors.deepPurple),
      ),
    );
  }
}

class TabulatorReports extends StatelessWidget {
  const TabulatorReports({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Reports & Analytics',
        style: TextStyle(fontSize: 24, color: Colors.deepPurple),
      ),
    );
  }
}

class TabulatorSettings extends StatelessWidget {
  const TabulatorSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Tabulator Settings',
        style: TextStyle(fontSize: 24, color: Colors.deepPurple),
      ),
    );
  }
}
