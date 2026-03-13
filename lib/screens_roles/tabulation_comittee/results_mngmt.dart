import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/modern_calendar.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';

class ResultsVerification extends StatefulWidget {
  const ResultsVerification({super.key});

  @override
  State<ResultsVerification> createState() => _ResultsVerificationState();
}

class _ResultsVerificationState extends State<ResultsVerification>
    with SingleTickerProviderStateMixin {
  final TeamScheduleService _teamScheduleService = TeamScheduleService();
  final TournamentService _tournamentService = TournamentService();
  final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _displayTimeFormat = DateFormat('hh:mm a');
  final Map<String, String> _teamLogos = {};

  DateTime _selectedDate = DateTime.now();
  String? _currentUserId;
  Map<String, String> _tournamentNames = {};
  Map<String, Map<String, dynamic>> _tournamentDetails = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _savingMatchId;
  String? _selectedTournamentId;
  Map<String, dynamic>? _selectedMatch;

  // Filter state
  String _searchQuery = '';
  String? _filterTournamentId;

  // Verification state
  bool _isEditMode = false;
  
  // Store verification status from Firebase
  Map<String, VerificationStatus> _verificationStatus = {};
  Map<String, List<Map<String, dynamic>>> _verificationHistory = {};

  List<Map<String, dynamic>> _allMatches = [];
  // Add this with the other filter state variables
bool _showAllDates = false; // New filter for all dates

  // Score input controllers
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, String?> _selectedWinners = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadTournamentData();
  }

  @override
  void dispose() {
    for (var controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<void> _loadTeamLogo(String teamId) async {
    if (_teamLogos.containsKey(teamId) || teamId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('participants')
          .doc(teamId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('imageBase64') && data['imageBase64'] != null) {
          setState(() {
            _teamLogos[teamId] = data['imageBase64'];
          });
        }
      }
    } catch (e) {
      print('Error loading team logo for $teamId: $e');
    }
  }

  Widget _buildTeamLogo(String? teamId, String teamName,
      {double size = 40, bool useGradient = true, bool showBorder = true}) {
    if (teamId != null && _teamLogos.containsKey(teamId)) {
      try {
        final base64String = _teamLogos[teamId]!;
        String cleanBase64 = base64String;
        if (base64String.contains(',')) {
          cleanBase64 = base64String.split(',').last;
        }

        final imageBytes = base64Decode(cleanBase64);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: showBorder ? Border.all(color: Colors.grey.shade300, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.memory(
              imageBytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildDefaultTeamLogo(teamName, size,
                    useGradient: useGradient);
              },
            ),
          ),
        );
      } catch (e) {
        print('Error decoding logo for $teamId: $e');
        return _buildDefaultTeamLogo(teamName, size, useGradient: useGradient);
      }
    } else {
      if (teamId != null && teamId.isNotEmpty) {
        _loadTeamLogo(teamId);
      }
      return _buildDefaultTeamLogo(teamName, size, useGradient: useGradient);
    }
  }

  Widget _buildDefaultTeamLogo(String teamName, double size,
      {bool useGradient = true}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: useGradient
            ? LinearGradient(
                colors: [
                  Colors.deepOrange.shade400,
                  Colors.deepOrange.shade600
                ],
              )
            : null,
        color: useGradient ? null : Colors.grey.shade300,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          useGradient
              ? (teamName.isNotEmpty
                  ? teamName.substring(0, 1).toUpperCase()
                  : '?')
              : '?',
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: useGradient ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  void _loadTournamentData() {
    _tournamentService.getTournamentStream().listen((snapshot) {
      if (!mounted) return;

      final Map<String, String> names = {};
      final Map<String, Map<String, dynamic>> details = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final tournamentId = data['id'] ?? doc.id;

        names[tournamentId] = data['name'] ?? 'Unnamed Tournament';

        List<String> assignedUsers = [];
        if (data['assignedUsers'] != null) {
          if (data['assignedUsers'] is List) {
            assignedUsers = List<String>.from(data['assignedUsers']);
          } else if (data['assignedUsers'] is String) {
            assignedUsers = [data['assignedUsers']];
          }
        }

        details[tournamentId] = {
          'docId': doc.id,
          'id': tournamentId,
          'name': data['name'] ?? 'Unnamed Tournament',
          'assignedUsers': assignedUsers,
          'venue': data['venue'] ?? 'Not specified',
          'sport': data['sport'] ?? 'Unknown',
          'category': data['category'] ?? 'Unknown',
          'gender': data['gender'] ?? 'Unknown',
          'status': data['status'] ?? 'Unknown',
          'matchups': data['matchups'] ?? [],
          'bracketType': data['bracketType'] ?? 'single',
          'eliminationType': data['eliminationType'] ?? 'Single Elimination',
        };

        // Load verification status from matchups
        final matchups = data['matchups'] as List? ?? [];
        for (var matchup in matchups) {
          final matchId = matchup['id'];
          if (matchId != null) {
            final verificationStatus = matchup['verificationStatus'];
            if (verificationStatus != null) {
              switch (verificationStatus.toString().toLowerCase()) {
                case 'verified':
                  _verificationStatus[matchId] = VerificationStatus.verified;
                  break;
                case 'ready':
                  _verificationStatus[matchId] = VerificationStatus.ready;
                  break;
                case 'pending':
                  _verificationStatus[matchId] = VerificationStatus.pending;
                  break;
              }
            }
            
            // Load verification history
            final history = matchup['verificationHistory'] as List? ?? [];
            if (history.isNotEmpty) {
              _verificationHistory[matchId] = List<Map<String, dynamic>>.from(history);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _tournamentNames = names;
          _tournamentDetails = details;
          _isLoading = false;
        });
      }
    }, onError: (error) {
      print('Error loading tournaments: $error');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  DateTime? _parseMatchDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return null;

    try {
      if (dateTimeStr.contains('/')) {
        final parts = dateTimeStr.split(' ');
        final dateParts = parts[0].split('/');
        if (dateParts.length == 3) {
          final day = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          final year = int.parse(dateParts[2]);

          if (parts.length > 1) {
            final timeParts = parts[1].split(':');
            final hour = int.parse(timeParts[0]);
            final minute = int.parse(timeParts[1]);
            return DateTime(year, month, day, hour, minute);
          } else {
            return DateTime(year, month, day);
          }
        }
      }

      if (dateTimeStr.contains('T')) {
        return DateTime.parse(dateTimeStr);
      }

      return null;
    } catch (e) {
      print('Error parsing date: $dateTimeStr - $e');
      return null;
    }
  }

  String _formatMatchTime(String? dateTimeStr) {
    final dateTime = _parseMatchDateTime(dateTimeStr);
    if (dateTime != null) {
      return _displayTimeFormat.format(dateTime);
    }
    return '';
  }

  // Determine match status based on scores and stored verification status
  VerificationStatus _determineMatchStatus(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';

    // First check if we have a stored verification status from Firebase
    if (_verificationStatus.containsKey(matchId)) {
      return _verificationStatus[matchId]!;
    }

    // Check if match is a placeholder
    if (_isPlaceholderMatch(match, _allMatches)) {
      return VerificationStatus.pending;
    }

    // Check if match has scores
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);

    // If match has scores, it's ready for verification
    if (hasScores) {
      return VerificationStatus.ready;
    }

    // Default to pending (no scores)
    return VerificationStatus.pending;
  }

  bool _isPlaceholderMatch(
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    final status = match['status'] as String? ?? 'scheduled';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    final isCompleted = status == 'completed' || hasScores;

    if (isCompleted) {
      return false;
    }

    final team1Id = match['team1Id']?.toString() ??
        (match['team1'] != null ? match['team1']['id']?.toString() : '') ??
        '';
    final team2Id = match['team2Id']?.toString() ??
        (match['team2'] != null ? match['team2']['id']?.toString() : '') ??
        '';

    final team1Name = match['team1Name']?.toString() ??
        (match['team1'] != null ? match['team1']['name']?.toString() : '') ??
        '';
    final team2Name = match['team2Name']?.toString() ??
        (match['team2'] != null ? match['team2']['name']?.toString() : '') ??
        '';

    bool isTeam1Placeholder = team1Id.contains('winner') ||
        team1Id.contains('loser') ||
        team1Name.contains('Winner') ||
        team1Name.contains('Loser') ||
        team1Id == 'match_1_winner' ||
        team1Id == 'match_2_winner' ||
        team1Id == 'match_3_winner' ||
        team1Id.contains('placeholder');

    bool isTeam2Placeholder = team2Id.contains('winner') ||
        team2Id.contains('loser') ||
        team2Name.contains('Winner') ||
        team2Name.contains('Loser') ||
        team2Id == 'match_1_winner' ||
        team2Id == 'match_2_winner' ||
        team2Id == 'match_3_winner' ||
        team2Id.contains('placeholder');

    return isTeam1Placeholder || isTeam2Placeholder;
  }

  String _getTeamDisplayName(Map<String, dynamic>? team,
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    if (team == null) return 'TBD';

    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? '';
    final teamType = team['type']?.toString() ?? '';

    bool isPlaceholder = teamType == 'placeholder' ||
        teamId.contains('placeholder') ||
        teamId.contains('winner') ||
        teamId.contains('loser') ||
        teamName.contains('Winner') ||
        teamName.contains('Loser') ||
        team['isPlaceholder'] == true;

    if (!isPlaceholder) {
      return team['displayName'] ?? teamName ?? 'Unknown Team';
    }

    // For placeholders, return descriptive text
    if (teamName.contains('Winner')) {
      return teamName;
    } else if (teamId.contains('winner')) {
      return 'Winner (Match ${teamId.replaceAll(RegExp(r'[^0-9]'), '')})';
    } else {
      return team['name'] ?? 'TBD';
    }
  }

  String? _getTeamId(Map<String, dynamic>? team) {
    if (team == null) return null;
    return team['id']?.toString();
  }

  bool _isUserAssignedToTournament(String tournamentId) {
    final tournamentInfo = _tournamentDetails[tournamentId];
    if (tournamentInfo == null) return false;
    final assignedUsers =
        tournamentInfo['assignedUsers'] as List<String>? ?? [];
    if (assignedUsers.isEmpty) return true;
    return _currentUserId != null && assignedUsers.contains(_currentUserId);
  }

  // Update match verification status in Firebase
  Future<void> _updateMatchVerificationStatus(
    String matchId, 
    Map<String, dynamic> match, 
    VerificationStatus newStatus
  ) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _savingMatchId = matchId;
    });

    try {
      final tournamentId = match['tournamentSetupId'];
      if (tournamentId == null) throw Exception('Tournament ID not found');

      final tournamentInfo = _tournamentDetails[tournamentId];
      if (tournamentInfo == null) throw Exception('Tournament info not found');

      final tournamentDocId = tournamentInfo['docId'];
      final tournamentRef = FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentDocId);

      final tournamentDoc = await tournamentRef.get();
      if (!tournamentDoc.exists) throw Exception('Tournament document not found');

      final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
      final matchups =
          List<Map<String, dynamic>>.from(tournamentData['matchups'] ?? []);

      final matchIndex = matchups.indexWhere((m) => m['id'] == matchId);
      if (matchIndex == -1) throw Exception('Match not found');

      // Create verification history entry
      final verificationHistory = List<Map<String, dynamic>>.from(
          matchups[matchIndex]['verificationHistory'] ?? []);
      
      verificationHistory.add({
        'timestamp': DateTime.now().toIso8601String(),
        'updatedBy': _currentUserId,
        'previousStatus': matchups[matchIndex]['verificationStatus'],
        'newStatus': newStatus.toString().split('.').last,
        'action': 'status_changed',
      });

      // Update match with new verification status
      matchups[matchIndex] = {
        ...matchups[matchIndex],
        'verificationStatus': newStatus.toString().split('.').last,
        'lastStatusUpdate': DateTime.now().toIso8601String(),
        'lastStatusUpdatedBy': _currentUserId,
        'verificationHistory': verificationHistory,
      };

      await tournamentRef.update({'matchups': matchups});

      // Update local state
      if (mounted) {
        setState(() {
          _verificationStatus[matchId] = newStatus;
          _verificationHistory[matchId] = verificationHistory;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Match marked as ${newStatus.toString().split('.').last}'),
            backgroundColor: _getStatusColor(newStatus),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingMatchId = null;
        });
      }
    }
  }

  Color _getStatusColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.verified:
        return Colors.green;
      case VerificationStatus.ready:
        return Colors.blue;
      case VerificationStatus.pending:
        return Colors.orange;
    }
  }

  // Get overall status counts regardless of filters
  Map<VerificationStatus, int> _getOverallStatusCounts() {
    final counts = {
      VerificationStatus.verified: 0,
      VerificationStatus.ready: 0,
      VerificationStatus.pending: 0,
    };

    for (var match in _allMatches) {
      // Only count matches user is assigned to
      final tournamentId = match['tournamentSetupId'];
      if (tournamentId != null && _isUserAssignedToTournament(tournamentId)) {
        final status = _determineMatchStatus(match);
        counts[status] = (counts[status] ?? 0) + 1;
      }
    }

    return counts;
  }

  List<Map<String, dynamic>> _filterMatches(
    List<Map<String, dynamic>> allSchedules) {
  return allSchedules.where((schedule) {
    // Filter by user assignment
    final tournamentId = schedule['tournamentSetupId'];
    if (tournamentId == null) return false;
    if (!_isUserAssignedToTournament(tournamentId)) return false;

    // Filter by selected tournament
    if (_filterTournamentId != null && _filterTournamentId != tournamentId) {
      return false;
    }

    // Filter by date (only if not showing all dates)
    if (!_showAllDates) {
      final dateTimeStr = schedule['dateTime'] ?? schedule['startTime'];
      final matchDateTime = _parseMatchDateTime(dateTimeStr);
      if (matchDateTime == null) return false;

      final isOnSelectedDate = matchDateTime.year == _selectedDate.year &&
          matchDateTime.month == _selectedDate.month &&
          matchDateTime.day == _selectedDate.day;

      if (!isOnSelectedDate) return false;
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final team1 = schedule['team1'] as Map<String, dynamic>? ?? {};
      final team2 = schedule['team2'] as Map<String, dynamic>? ?? {};
      final team1Name = _getTeamDisplayName(team1, schedule, _allMatches);
      final team2Name = _getTeamDisplayName(team2, schedule, _allMatches);
      final matchNumber = schedule['matchNumber']?.toString() ?? '';

      return team1Name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          team2Name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          matchNumber.contains(_searchQuery);
    }

    return true;
  }).toList();
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF2D3748)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified, color: Colors.deepOrange),
            ),
            const SizedBox(width: 12),
            const Text(
              'Results Verification',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          _buildCompactDateSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: _teamScheduleService.getAllTeamSchedules(limit: 10000),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final allSchedules = snapshot.data ?? [];
                _allMatches = allSchedules;
                final filteredMatches = _filterMatches(allSchedules);
                final overallCounts = _getOverallStatusCounts();

                return Column(
                  children: [
                    // Overall Status Summary (always visible)
                    _buildOverallStatusSummary(overallCounts),
                    
                    // Filter Bar
                    _buildFilterBar(),
                    
                    Expanded(
                      child: filteredMatches.isEmpty
                          ? _buildEmptyState()
                          : _buildMatchesList(filteredMatches),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildOverallStatusSummary(Map<VerificationStatus, int> counts) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overall Status Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildOverallStatusCard(
                'Verified',
                counts[VerificationStatus.verified]?.toString() ?? '0',
                Colors.green,
                Icons.verified,
              ),
              const SizedBox(width: 8),
              _buildOverallStatusCard(
                'Ready',
                counts[VerificationStatus.ready]?.toString() ?? '0',
                Colors.blue,
                Icons.play_circle_filled,
              ),
              const SizedBox(width: 8),
              _buildOverallStatusCard(
                'Pending',
                counts[VerificationStatus.pending]?.toString() ?? '0',
                Colors.orange,
                Icons.hourglass_empty,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatusCard(String label, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactDateSelector() {
  return InkWell(
    onTap: _showModernDatePicker,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 14,
            color: Colors.deepOrange.shade400,
          ),
          const SizedBox(width: 4),
          Text(
            _showAllDates ? 'All Dates' : _displayDateFormat.format(_selectedDate),
            style: const TextStyle(
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_drop_down,
            size: 16,
            color: Colors.grey.shade600,
          ),
        ],
      ),
    ),
  );
}

  Future<void> _showModernDatePicker() async {
  final DateTime now = DateTime.now();
  final DateTime firstDate = DateTime(now.year - 1, now.month, now.day);
  final DateTime lastDate = DateTime(now.year + 1, now.month, now.day);

  // Show options dialog first
  final String? action = await showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Select Date Option'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.calendar_month, color: Colors.deepOrange),
              title: const Text('Specific Date'),
              subtitle: const Text('Choose a specific date'),
              onTap: () => Navigator.pop(context, 'specific'),
            ),
            ListTile(
              leading: Icon(Icons.date_range, color: Colors.blue),
              title: const Text('All Dates'),
              subtitle: const Text('Show matches from all dates'),
              onTap: () => Navigator.pop(context, 'all'),
            ),
          ],
        ),
      );
    },
  );

  if (action == 'all' && mounted) {
    setState(() {
      _showAllDates = true;
    });
    return;
  }

  if (action == 'specific' && mounted) {
    final DateTime? pickedDate = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(24),
            child: ModernCalendarPicker(
              initialDate: _selectedDate,
              firstDate: firstDate,
              lastDate: lastDate,
              onDateSelected: (date) {
                Navigator.pop(context, date);
              },
            ),
          ),
        );
      },
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
        _showAllDates = false;
        _selectedMatch = null;
      });
    }
  }
}

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          // Search Field
          Expanded(
            flex: 2,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search teams or match #...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Tournament Filter
          Container(
            width: 200,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filterTournamentId,
                hint: const Text('All Tournaments', style: TextStyle(fontSize: 13)),
                icon: Icon(Icons.arrow_drop_down, color: Colors.grey.shade600),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All Tournaments', style: TextStyle(fontSize: 13)),
                  ),
                  ..._tournamentNames.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() {
                    _filterTournamentId = value;
                    _selectedMatch = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Filter Stats Summary (shows filtered counts)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildFilterStatChip('Verified', Colors.green),
                const SizedBox(width: 8),
                _buildFilterStatChip('Ready', Colors.blue),
                const SizedBox(width: 8),
                _buildFilterStatChip('Pending', Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterStatChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchesList(List<Map<String, dynamic>> matches) {
    // Group by tournament
    Map<String, List<Map<String, dynamic>>> tournamentMatches = {};
    for (var match in matches) {
      final tournamentId = match['tournamentSetupId'] ?? 'Unknown';
      tournamentMatches.putIfAbsent(tournamentId, () => []).add(match);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tournamentMatches.length,
      itemBuilder: (context, index) {
        final entry = tournamentMatches.entries.elementAt(index);
        return _buildTournamentSection(entry.key, entry.value);
      },
    );
  }

  Widget _buildTournamentSection(
      String tournamentId, List<Map<String, dynamic>> matches) {
    final tournamentName =
        _tournamentNames[tournamentId] ?? 'Unknown Tournament';
    final tournamentInfo = _tournamentDetails[tournamentId] ?? {};
    final sport = tournamentInfo['sport'] ?? 'Unknown';
    final venue = tournamentInfo['venue'] ?? 'Not specified';

    // Count statuses for this tournament
    int verifiedCount = 0;
    int readyCount = 0;
    int pendingCount = 0;

    for (var match in matches) {
      final status = _determineMatchStatus(match);
      switch (status) {
        case VerificationStatus.verified:
          verifiedCount++;
          break;
        case VerificationStatus.ready:
          readyCount++;
          break;
        case VerificationStatus.pending:
          pendingCount++;
          break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tournament Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournamentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$sport • $venue',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      _buildTournamentStat(Colors.green, verifiedCount),
                      const SizedBox(width: 8),
                      _buildTournamentStat(Colors.blue, readyCount),
                      const SizedBox(width: 8),
                      _buildTournamentStat(Colors.orange, pendingCount),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Matches List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: matches.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              return _buildMatchTile(matches[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentStat(Color color, int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    final isSelected = _selectedMatch?['id'] == matchId;
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = _getTeamId(team1);
    final team2Id = _getTeamId(team2);
    final matchTime = _formatMatchTime(match['dateTime'] ?? match['startTime']);
    final matchNumber = match['matchNumber'] ?? '#';
    final status = _determineMatchStatus(match);

    // Get existing scores if any
    final existingScores = match['scores'] as Map<String, dynamic>? ?? {};
    final score1 = existingScores[team1Id ?? team1Name] ??
        existingScores[team1Name] ??
        match['team1Score'] ??
        null;
    final score2 = existingScores[team2Id ?? team2Name] ??
        existingScores[team2Name] ??
        match['team2Score'] ??
        null;
    final hasScores = score1 != null && score2 != null;

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case VerificationStatus.verified:
        statusColor = Colors.green;
        statusIcon = Icons.verified;
        statusText = 'Verified';
        break;
      case VerificationStatus.ready:
        statusColor = Colors.blue;
        statusIcon = Icons.play_circle_filled;
        statusText = 'Ready';
        break;
      case VerificationStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'Pending';
        break;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _selectedMatch = match;
        });
        _showMatchDetailsDialog(match);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? statusColor.withOpacity(0.05) : Colors.white,
        ),
        child: Row(
          children: [
            // Status Indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Team 1 Logo
            _buildTeamLogo(team1Id, team1Name, size: 36),
            const SizedBox(width: 8),

            // Match Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Match $matchNumber',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (matchTime.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            matchTime,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team1Name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: hasScores ? Colors.grey.shade800 : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasScores)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$score1 - $score2',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          team2Name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: hasScores ? Colors.grey.shade800 : Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Team 2 Logo
            const SizedBox(width: 8),
            _buildTeamLogo(team2Id, team2Name, size: 36),

            const SizedBox(width: 12),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 12, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMatchDetailsDialog(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = _getTeamId(team1);
    final team2Id = _getTeamId(team2);
    final matchNumber = match['matchNumber'] ?? '#';
    final status = _determineMatchStatus(match);
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);

    // Get existing scores
    final existingScores = match['scores'] as Map<String, dynamic>? ?? {};
    final score1 = existingScores[team1Id ?? team1Name] ??
        existingScores[team1Name] ??
        match['team1Score'] ??
        '?';
    final score2 = existingScores[team2Id ?? team2Name] ??
        existingScores[team2Name] ??
        match['team2Score'] ??
        '?';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Match Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Match $matchNumber',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(status),
                  ],
                ),

                const SizedBox(height: 24),

                // Teams and Scores
                Row(
                  children: [
                    // Team 1
                    Expanded(
                      child: Column(
                        children: [
                          _buildTeamLogo(team1Id, team1Name, size: 70),
                          const SizedBox(height: 8),
                          Text(
                            team1Name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              score1.toString(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),

                    // Team 2
                    Expanded(
                      child: Column(
                        children: [
                          _buildTeamLogo(team2Id, team2Name, size: 70),
                          const SizedBox(height: 8),
                          Text(
                            team2Name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              score2.toString(),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Winner Info (if available)
                if (match['winner'] != null && match['winner'] != 'tie')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Winner: ${match['winner'] == team1Id ? team1Name : team2Name}',
                            style: TextStyle(
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (match['winner'] == 'tie')
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.handshake, color: Colors.purple),
                        SizedBox(width: 8),
                        Text(
                          'Match ended in a Tie',
                          style: TextStyle(
                            color: Colors.purple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Verification Status Toggle
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verification Status',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusToggleButton(
                              label: 'Verified',
                              icon: Icons.verified,
                              color: Colors.green,
                              isSelected: status == VerificationStatus.verified,
                              onTap: hasScores ? () {
                                _updateMatchVerificationStatus(
                                  matchId, 
                                  match, 
                                  VerificationStatus.verified
                                );
                                Navigator.pop(context);
                              } : null,
                              enabled: hasScores,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusToggleButton(
                              label: 'Ready',
                              icon: Icons.play_circle_filled,
                              color: Colors.blue,
                              isSelected: status == VerificationStatus.ready,
                              onTap: hasScores ? () {
                                _updateMatchVerificationStatus(
                                  matchId, 
                                  match, 
                                  VerificationStatus.ready
                                );
                                Navigator.pop(context);
                              } : null,
                              enabled: hasScores,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatusToggleButton(
                              label: 'Pending',
                              icon: Icons.hourglass_empty,
                              color: Colors.orange,
                              isSelected: status == VerificationStatus.pending,
                              onTap: () {
                                _updateMatchVerificationStatus(
                                  matchId, 
                                  match, 
                                  VerificationStatus.pending
                                );
                                Navigator.pop(context);
                              },
                              enabled: true,
                            ),
                          ),
                        ],
                      ),
                      if (!hasScores)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info, color: Colors.orange, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Verified and Ready statuses require scores to be entered',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Verification History (if available)
                if (_verificationHistory.containsKey(matchId) && _verificationHistory[matchId]!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history, size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 8),
                            Text(
                              'History',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._verificationHistory[matchId]!.take(3).map((entry) {
                          final timestamp = DateTime.parse(entry['timestamp']);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fiber_manual_record,
                                  size: 6,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${entry['action']} to ${entry['newStatus']}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat('MM/dd HH:mm').format(timestamp),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Close Button
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusToggleButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (enabled ? Colors.grey.shade300 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon, 
              color: enabled ? (isSelected ? color : Colors.grey.shade600) : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: enabled ? (isSelected ? color : Colors.grey.shade700) : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(VerificationStatus status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case VerificationStatus.verified:
        color = Colors.green;
        icon = Icons.verified;
        label = 'Verified';
        break;
      case VerificationStatus.ready:
        color = Colors.blue;
        icon = Icons.play_circle_filled;
        label = 'Ready';
        break;
      case VerificationStatus.pending:
        color = Colors.orange;
        icon = Icons.hourglass_empty;
        label = 'Pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports_score,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No matches found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try changing your filters or date',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error loading matches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (mounted) setState(() {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

enum VerificationStatus {
  verified,
  ready,
  pending,
}