import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  ReportsAnalyticsState createState() => ReportsAnalyticsState();
}

class ReportsAnalyticsState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');

  // Helper method to get team name from team object
  String _getTeamName(dynamic team) {
    if (team == null) return 'TBD';

    // If team is a Map (new structured format)
    if (team is Map<String, dynamic>) {
      return team['name'] ?? 'TBD';
    }

    // If team is a String (fallback)
    if (team is String) {
      return team;
    }

    return 'TBD';
  }

  // Helper method to check if a team is a placeholder (Match X Winner)
  bool _isPlaceholderTeam(dynamic team) {
    if (team == null) return false;
    if (team is Map<String, dynamic>) {
      final type = team['type'] as String?;
      return type == 'placeholder' ||
          (team['name']?.toString().contains('Winner') ?? false);
    }
    return false;
  }

  // Build match display text using team1 and team2 objects
  String _buildMatchDisplayText(Map<String, dynamic> schedule) {
    final team1 = schedule['team1'];
    final team2 = schedule['team2'];
    final matchType = schedule['matchType'] ?? 'regular';

    String team1Name = _getTeamName(team1);
    String team2Name = _getTeamName(team2);

    // Check if it's a BYE match
    if (matchType == 'bye' || team2Name == 'BYE') {
      return '$team1Name - BYE';
    }

    // Check if it's a placeholder match (winner of previous matches)
    if (_isPlaceholderTeam(team1) && _isPlaceholderTeam(team2)) {
      // Try to extract source match numbers
      int? source1 = team1 is Map ? team1['sourceMatch'] as int? : null;
      int? source2 = team2 is Map ? team2['sourceMatch'] as int? : null;

      if (source1 != null && source2 != null) {
        return 'Winner of Match $source1 vs Winner of Match $source2';
      }
      return 'Winner Match';
    } else if (_isPlaceholderTeam(team1)) {
      int? source = team1 is Map ? team1['sourceMatch'] as int? : null;
      if (source != null) {
        return 'Winner of Match $source vs $team2Name';
      }
      return 'Winner Match vs $team2Name';
    } else if (_isPlaceholderTeam(team2)) {
      int? source = team2 is Map ? team2['sourceMatch'] as int? : null;
      if (source != null) {
        return '$team1Name vs Winner of Match $source';
      }
      return '$team1Name vs Winner Match';
    }

    // Regular match with actual team names
    return '$team1Name vs $team2Name';
  }

  // Check if match is a BYE
  bool _isByeMatch(Map<String, dynamic> schedule) {
    final matchType = schedule['matchType'] ?? 'regular';
    if (matchType == 'bye') return true;

    final team2 = schedule['team2'];
    if (team2 is Map<String, dynamic>) {
      return team2['name'] == 'BYE';
    }
    return false;
  }

  // Check if match is a winner match (has placeholders)
  bool _isWinnerMatch(Map<String, dynamic> schedule) {
    final team1 = schedule['team1'];
    final team2 = schedule['team2'];

    return _isPlaceholderTeam(team1) || _isPlaceholderTeam(team2);
  }

  // Analytics data
  int totalTournaments = 0;
  int totalTeams = 0;
  int totalCategories = 0;
  int verifiedTournaments = 0;
  int totalUsers = 0;
  int totalSchedules = 0;
  int gamesToday = 0;
  List<Map<String, dynamic>> teamSchedules = [];
  Map<String, int> categoryCounts = {};
  Map<String, int> verificationStatus = {};
  Map<String, int> userRoleCounts = {};
  Map<String, String> _userNames = {};
  Map<String, String> _userEmails = {};
  Map<String, List<dynamic>> _tournamentAssignedUsers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  String _getUserNamesString(List<dynamic>? userIds) {
    if (userIds == null || userIds.isEmpty) {
      return 'Not Assigned';
    }

    final List<String> names = [];
    for (var userId in userIds) {
      final userIdStr = userId?.toString();
      if (userIdStr != null && userIdStr.isNotEmpty) {
        final name =
            _userNames[userIdStr] ?? _userEmails[userIdStr] ?? userIdStr;
        names.add(name);
      }
    }

    if (names.isEmpty) return 'Not Assigned';
    return names.join(', ');
  }

  Future<void> _loadUserData() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = doc.id;
        final email = data['email']?.toString() ?? 'Unknown Email';
        final name = data['name']?.toString() ?? email.split('@')[0];
        _userNames[userId] = name;
        _userEmails[userId] = email;
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  Future<void> _loadTournamentAssignedUsers(List<String> tournamentIds) async {
    try {
      // First, get all tournaments to build a mapping
      final tournamentsSnapshot =
          await _firestore.collection('tournaments').get();

      // Build a map of both document IDs and custom 'id' fields to tournament data
      final Map<String, Map<String, dynamic>> tournamentDataById = {};

      for (var doc in tournamentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final customId = data['id']?.toString();

        // Map by document ID
        tournamentDataById[doc.id] = data;

        // Also map by custom 'id' field if it exists
        if (customId != null && customId.isNotEmpty) {
          tournamentDataById[customId] = data;
        }
      }

      // Now assign users for each tournament ID
      for (var tournamentId in tournamentIds) {
        if (_tournamentAssignedUsers.containsKey(tournamentId)) continue;

        final tournamentData = tournamentDataById[tournamentId];

        if (tournamentData != null) {
          final assignedUsers =
              tournamentData['assignedUsers'] as List<dynamic>?;
          if (assignedUsers != null) {
            _tournamentAssignedUsers[tournamentId] = assignedUsers;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading tournament assigned users: $e');
    }
  }

  Future<void> _loadAnalyticsData() async {
    try {
      setState(() => _isLoading = true);

      // Load user data first
      await _loadUserData();

      // Load tournaments
      final tournamentsSnapshot =
          await _firestore.collection('tournaments').get();

      // Create a Set to track unique tournaments based on ID
      final uniqueTournaments = <String, Map<String, dynamic>>{};

      for (var doc in tournamentsSnapshot.docs) {
        final data = doc.data();
        final tournamentId = data['id']?.toString() ?? doc.id;
        final normalizedId = tournamentId.isEmpty ? '1' : tournamentId;

        if (!uniqueTournaments.containsKey(normalizedId)) {
          uniqueTournaments[normalizedId] = data;
        }
      }

      totalTournaments = uniqueTournaments.length;

      verifiedTournaments = uniqueTournaments.values
          .where((data) => data['isVerified'] == true)
          .length;

      // Load team schedules from 'team_schedules' collection
      final schedulesSnapshot = await _firestore
          .collection('team_schedules')
          .orderBy('dateTime', descending: true)
          .get();
      totalSchedules = schedulesSnapshot.docs.length;

      // Build a map of tournament IDs to tournament data
      final Map<String, Map<String, dynamic>> tournamentDataMap = {};
      final List<String> tournamentIds = [];

      for (var doc in tournamentsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tournamentId = data['id']?.toString() ?? '';
        final docId = doc.id;

        if (tournamentId.isNotEmpty) {
          tournamentDataMap[tournamentId] = {
            'name': data['name'] ?? 'Unnamed Tournament',
            'category': data['category'] ?? data['categoryId'] ?? 'N/A',
            'assignedUsers': data['assignedUsers'],
          };
          tournamentIds.add(tournamentId);
        }
        if (docId.isNotEmpty && !tournamentDataMap.containsKey(docId)) {
          tournamentDataMap[docId] = {
            'name': data['name'] ?? 'Unnamed Tournament',
            'category': data['category'] ?? data['categoryId'] ?? 'N/A',
            'assignedUsers': data['assignedUsers'],
          };
          tournamentIds.add(docId);
        }
      }

      // Pre-load tournament assigned users
      await _loadTournamentAssignedUsers(tournamentIds);

      // Process team schedules
      teamSchedules = [];

      for (var doc in schedulesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tournamentId = data['tournamentSetupId']?.toString() ?? 'unknown';

        final tournamentInfo = tournamentDataMap[tournamentId];
        final tournamentName = tournamentInfo?['name'] ?? 'Unknown';
        String category = tournamentInfo?['category'] ?? 'N/A';

        // Override with schedule's own category if available
        if (data['category'] != null) category = data['category'] as String;
        if (data['categoryName'] != null)
          category = data['categoryName'] as String;

        List<dynamic>? assignedUsers = _tournamentAssignedUsers[tournamentId];
        if (assignedUsers == null) {
          assignedUsers = tournamentInfo?['assignedUsers'] as List<dynamic>?;
        }

        final assignedOfficial = _getUserNamesString(assignedUsers);

        // Get match data
        final matchNumber = data['matchNumber'] ?? 1;
        final matchType = data['matchType'] ?? 'regular';
        final nextMatchReference = data['nextMatchReference'];
        final team1 = data['team1'];
        final team2 = data['team2'];

        teamSchedules.add({
          'id': doc.id,
          'team1': team1,
          'team2': team2,
          'matchType': matchType,
          'category': category,
          'tournamentName': tournamentName,
          'tournamentId': tournamentId,
          'dateTime': data['dateTime'] ?? data['startTime'],
          'venue': data['venue'] ?? 'N/A',
          'assignedOfficial': assignedOfficial,
          'matchNumber': matchNumber,
          'nextMatchReference': nextMatchReference,
        });
      }

      // Sort all schedules by datetime for display
      teamSchedules.sort((a, b) {
        final aDateTime = a['dateTime']?.toString() ?? '';
        final bDateTime = b['dateTime']?.toString() ?? '';
        return aDateTime.compareTo(bDateTime);
      });

      // Load games today
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySnapshot = await _firestore
          .collection('team_schedules')
          .where('dateTime',
              isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('dateTime', isLessThan: endOfDay.toIso8601String())
          .get();
      gamesToday = todaySnapshot.docs.length;

      // Load teams count
      final teamsSnapshot = await _firestore.collection('participants').get();
      totalTeams = teamsSnapshot.docs.length;

      // Load categories
      final categoriesSnapshot =
          await _firestore.collection('sports_categories').get();
      totalCategories = categoriesSnapshot.docs.length;

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard(String title, int value, Color color, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 8,
        shadowColor: color.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 30, color: color),
              ),
              const SizedBox(height: 16),
              Text(
                value.toString(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color,
                  shadows: [
                    Shadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchTypeChip(Map<String, dynamic> schedule) {
    final matchNumber = schedule['matchNumber'] ?? 1;
    final isWinnerMatch = _isWinnerMatch(schedule);
    final isBye = _isByeMatch(schedule);

    Color chipColor;
    Color textColor;
    String label;
    IconData icon;

    if (isBye) {
      chipColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      label = 'Match $matchNumber • BYE';
      icon = Icons.skip_next;
    } else if (isWinnerMatch) {
      chipColor = Colors.amber.shade50;
      textColor = Colors.amber.shade800;
      label = 'Match $matchNumber • Winner';
      icon = Icons.emoji_events;
    } else {
      chipColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      label = 'Match $matchNumber';
      icon = Icons.sports_soccer;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: textColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulesTable() {
    if (_isLoading) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 20),
              Text(
                'Loading schedules...',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (teamSchedules.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(50),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sports_score,
                size: 80,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 20),
              Text(
                'No team schedules found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Schedules will appear here once created',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 30,
              offset: const Offset(0, 15),
              spreadRadius: -5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Enhanced Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade700,
                              Colors.blue.shade500
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sports_volleyball,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Team Schedules',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${teamSchedules.length} Matches',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Enhanced Table
                  SizedBox(
                    height: 600,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: DataTable(
                          columnSpacing: 40,
                          headingRowHeight: 70,
                          dataRowHeight: 130,
                          horizontalMargin: 24,
                          headingRowColor: MaterialStateProperty.all(
                            Colors.grey.shade50,
                          ),
                          showCheckboxColumn: false,
                          columns: [
                            _buildEnhancedColumn(
                                'Tournament', Icons.emoji_events),
                            _buildEnhancedColumn(
                                'Match Details', Icons.sports_score),
                            _buildEnhancedColumn('Category', Icons.category),
                            _buildEnhancedColumn(
                                'Scheduled', Icons.access_time),
                            _buildEnhancedColumn('Official', Icons.person),
                          ],
                          rows: teamSchedules.map((schedule) {
                            final tournamentName =
                                schedule['tournamentName'] ?? 'Unknown';
                            final assignedOfficial =
                                schedule['assignedOfficial'] ?? 'Not Assigned';
                            final matchDisplay =
                                _buildMatchDisplayText(schedule);
                            final isBye = _isByeMatch(schedule);

                            // Format dateTime
                            String scheduledTime = 'N/A';
                            if (schedule['dateTime'] != null) {
                              try {
                                final dateTime = DateTime.parse(
                                    schedule['dateTime'].toString());
                                scheduledTime = _dateFormat.format(dateTime);
                              } catch (e) {
                                scheduledTime = schedule['dateTime'].toString();
                              }
                            }

                            return DataRow(
                              cells: [
                                // Tournament Name column
                                DataCell(
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            Icons.tour,
                                            size: 20,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          tournamentName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.2,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Match Details column
                                DataCell(
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        _buildMatchTypeChip(schedule),
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isBye
                                                ? Colors.blue.shade50
                                                : Colors.purple.shade50,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            matchDisplay,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: isBye
                                                  ? Colors.blue.shade700
                                                  : Colors.purple.shade700,
                                              letterSpacing: 0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                        if (schedule['nextMatchReference'] !=
                                            null) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.trending_up,
                                                  size: 12,
                                                  color: Colors.amber.shade700,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '→ Match ${schedule['nextMatchReference']}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        Colors.amber.shade700,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),

                                // Category column
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.teal.shade50,
                                          Colors.teal.shade100,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.teal.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      schedule['category'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.teal.shade800,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),

                                // Scheduled time column
                                DataCell(
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.access_time_filled,
                                          size: 18,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            scheduledTime,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade700,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Official assigned column
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: assignedOfficial == 'Not Assigned'
                                          ? Colors.orange.shade50
                                          : Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            assignedOfficial == 'Not Assigned'
                                                ? Colors.orange.shade200
                                                : Colors.green.shade200,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          assignedOfficial == 'Not Assigned'
                                              ? Icons.person_outline
                                              : Icons.person,
                                          size: 14,
                                          color:
                                              assignedOfficial == 'Not Assigned'
                                                  ? Colors.orange.shade700
                                                  : Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            assignedOfficial,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: assignedOfficial ==
                                                      'Not Assigned'
                                                  ? Colors.orange.shade700
                                                  : Colors.green.shade700,
                                              letterSpacing: 0.2,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),

                  // Footer
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade400,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Showing ${teamSchedules.length} scheduled matches',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataColumn _buildEnhancedColumn(String label, IconData icon) {
    return DataColumn(
      label: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.blue.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadAnalyticsData,
        color: Colors.blue,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Statistics Cards with modern design
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildStatCard(
                      'Total Scheduled',
                      totalSchedules,
                      Colors.blue,
                      Icons.emoji_events,
                    ),
                    const SizedBox(width: 20),
                    _buildStatCard(
                      'Games Today',
                      gamesToday,
                      Colors.green,
                      Icons.today,
                    ),
                    const SizedBox(width: 20),
                    _buildStatCard(
                      'Games Played',
                      totalCategories,
                      Colors.purple,
                      Icons.sports_soccer,
                    ),
                    const SizedBox(width: 20),
                    _buildStatCard(
                      'Remaining',
                      verifiedTournaments,
                      Colors.orange,
                      Icons.pending_actions,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Enhanced Team Schedules Table
              _buildSchedulesTable(),
            ],
          ),
        ),
      ),
    );
  }
}
