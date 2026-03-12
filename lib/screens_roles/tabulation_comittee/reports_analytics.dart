import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ReportsAnalytics extends StatefulWidget {
  const ReportsAnalytics({super.key});

  @override
  ReportsAnalyticsState createState() => ReportsAnalyticsState();
}

class ReportsAnalyticsState extends State<ReportsAnalytics> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Analytics data
  int totalTournaments = 0;
  int totalTeams = 0;
  int totalCategories = 0;
  int verifiedTournaments = 0;
  List<Map<String, dynamic>> tournamentData = [];
  Map<String, int> categoryCounts = {};
  Map<String, int> verificationStatus = {};

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    try {
      // Load tournaments
      final tournamentsSnapshot =
          await _firestore.collection('tournaments').get();

      // Create a Set to track unique tournaments based on ID
      final uniqueTournaments = <String, Map<String, dynamic>>{};

      // Normalize tournament IDs to ensure uniqueness
      for (var doc in tournamentsSnapshot.docs) {
        final data = doc.data();
        final tournamentId = data['id']?.toString() ?? doc.id;

        // Ensure unique tournament ID (set to 1 if exists)
        final normalizedId = tournamentId.isEmpty ? '1' : tournamentId;

        // Track unique tournaments by normalized ID
        if (!uniqueTournaments.containsKey(normalizedId)) {
          uniqueTournaments[normalizedId] = data;
        }
      }

      // Use unique tournaments for verification status
      totalTournaments = uniqueTournaments.length;

      // Count verified tournaments from unique tournaments
      verifiedTournaments = uniqueTournaments.values
          .where((data) => data['isVerified'] == true)
          .length;

      // Load teams
      final teamsSnapshot = await _firestore.collection('participants').get();
      totalTeams = teamsSnapshot.docs.length;

      // Load categories
      final categoriesSnapshot =
          await _firestore.collection('sports_categories').get();
      totalCategories = categoriesSnapshot.docs.length;

      // Process category distribution from unique tournaments
      categoryCounts.clear();
      for (var data in uniqueTournaments.values) {
        final category = data['category'] ?? 'Unknown';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      }

      // Process verification status with corrected counts
      verificationStatus = {
        'Verified': verifiedTournaments,
        'Pending': totalTournaments - verifiedTournaments,
      };

      setState(() {});
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (verificationStatus.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tournament Verification Status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: verificationStatus.entries.map((entry) {
                    final color =
                        entry.key == 'Verified' ? Colors.green : Colors.orange;
                    return PieChartSectionData(
                      color: color,
                      value: entry.value.toDouble(),
                      title: '${entry.key}\n${entry.value}',
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart() {
    if (categoryCounts.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tournaments by Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: categoryCounts.values.isNotEmpty
                      ? categoryCounts.values
                              .reduce((a, b) => a > b ? a : b)
                              .toDouble() +
                          2
                      : 10,
                  barGroups: categoryCounts.entries.map((entry) {
                    return BarChartGroupData(
                      x: categoryCounts.keys.toList().indexOf(entry.key),
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: Colors.deepOrange,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          final categories = categoryCounts.keys.toList();
                          if (value.toInt() < categories.length) {
                            return Transform.rotate(
                              angle: -45 * 3.14159 / 180,
                              child: Text(
                                categories[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalyticsData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tournament Analytics Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Statistics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Tournaments',
                      totalTournaments,
                      Colors.blue,
                      Icons.emoji_events,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Total Teams',
                      totalTeams,
                      Colors.green,
                      Icons.people,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Categories',
                      totalCategories,
                      Colors.purple,
                      Icons.category,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Verified',
                      verifiedTournaments,
                      Colors.orange,
                      Icons.verified,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Charts
              _buildPieChart(),
              const SizedBox(height: 20),
              _buildBarChart(),

              const SizedBox(height: 20),

              // Summary
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Summary Report',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('• Total Tournaments: $totalTournaments'),
                      Text('• Verified Tournaments: $verifiedTournaments'),
                      Text('• Total Teams: $totalTeams'),
                      Text('• Total Categories: $totalCategories'),
                      Text(
                          '• Verification Rate: ${totalTournaments > 0 ? ((verifiedTournaments / totalTournaments) * 100).toStringAsFixed(1) : 0}%'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
