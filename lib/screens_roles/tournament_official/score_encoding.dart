import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/modern_calendar.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';

class ScoreEncodingScreen extends StatefulWidget {
  const ScoreEncodingScreen({super.key});

  @override
  State<ScoreEncodingScreen> createState() => _ScoreEncodingScreenState();
}

class _ScoreEncodingScreenState extends State<ScoreEncodingScreen>
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

  // Edit mode flag
  bool _isEditMode = false;

  List<Map<String, dynamic>> _allMatches = [];

  // For better organization
  String? _selectedTournamentId;
  Map<String, dynamic>? _selectedMatch;

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
    if (user != null) {
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
      {double size = 40, bool useGradient = true}) {
    if (teamId != null && _teamLogos.containsKey(teamId)) {
      try {
        final base64String = _teamLogos[teamId]!;
        // Handle base64 string - remove data URL prefix if present
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
            border: Border.all(color: Colors.grey.shade300, width: 2),
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
      // Load logo if not cached
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

  Widget _buildModernDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _showModernDatePicker,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month,
                  size: 20,
                  color: Colors.deepOrange.shade400,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SELECTED DATE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade500,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _displayDateFormat.format(_selectedDate),
                    style: const TextStyle(
                      color: Color(0xFF2D3748),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showModernDatePicker() async {
    final DateTime now = DateTime.now();
    final DateTime firstDate = DateTime(now.year - 1, now.month, now.day);
    final DateTime lastDate = DateTime(now.year + 1, now.month, now.day);

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
        _selectedTournamentId = null;
        _selectedMatch = null;
        _isEditMode = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Date changed to ${_displayDateFormat.format(pickedDate)}',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          backgroundColor: Colors.deepOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _loadTournamentData() async {
    _tournamentService.getTournamentStream().listen((snapshot) {
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

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDate = pickedDate;
        _selectedTournamentId = null;
        _selectedMatch = null;
        _isEditMode = false;
      });
    }
  }

  DateTime? _parseMatchDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return null;

    try {
      // Handle format like "15/2/2026 12:00" (yours)
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

      // Handle ISO format
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

  bool _isPlaceholderMatch(
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    // First check if match is completed - completed matches should NOT be in future matches
    final status = match['status'] as String? ?? 'scheduled';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    final isCompleted = status == 'completed' || hasScores;

    // If match is completed, it's NOT a placeholder regardless of team types
    if (isCompleted) {
      return false;
    }

    // Get team identifiers - checking multiple possible field names
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

    // Check if either team is a placeholder
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

    // If neither team is a placeholder, it's a real match
    if (!isTeam1Placeholder && !isTeam2Placeholder) {
      return false;
    }

    // Get the tournament ID for this match to filter source matches
    final tournamentId = match['tournamentSetupId']?.toString() ?? '';

    // Filter matches to only those in the same tournament
    final tournamentMatches = allMatches
        .where((m) => m['tournamentSetupId']?.toString() == tournamentId)
        .toList();

    // Check team 1 placeholder
    if (isTeam1Placeholder) {
      // Try to extract source match number from various formats
      int? sourceMatchNumber;

      // Format: "match_1_winner"
      RegExp matchIdRegExp = RegExp(r'match[_]?(\d+)[_]?winner');
      final matchIdMatch = matchIdRegExp.firstMatch(team1Id);
      if (matchIdMatch != null) {
        sourceMatchNumber = int.tryParse(matchIdMatch.group(1) ?? '');
      }

      // Format: "Winner Match 1"
      if (sourceMatchNumber == null) {
        RegExp nameRegExp =
            RegExp(r'Winner\s+Match\s+(\d+)', caseSensitive: false);
        final nameMatch = nameRegExp.firstMatch(team1Name);
        if (nameMatch != null) {
          sourceMatchNumber = int.tryParse(nameMatch.group(1) ?? '');
        }
      }

      // Format: just the number at the end
      if (sourceMatchNumber == null) {
        RegExp numberRegExp = RegExp(r'(\d+)$');
        final numberMatch = numberRegExp.firstMatch(team1Id);
        if (numberMatch != null) {
          sourceMatchNumber = int.tryParse(numberMatch.group(1) ?? '');
        }
      }

      // If we found a source match number, check if that match is completed
      if (sourceMatchNumber != null) {
        final sourceMatch = tournamentMatches.firstWhere(
          (m) => m['matchNumber'] == sourceMatchNumber,
          orElse: () => {},
        );

        if (sourceMatch.isNotEmpty) {
          final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
          final sourceHasScores = sourceMatch['scores'] != null ||
              (sourceMatch['team1Score'] != null &&
                  sourceMatch['team2Score'] != null);
          final sourceIsCompleted =
              sourceStatus == 'completed' || sourceHasScores;

          // If source match is completed, this team is no longer a placeholder
          if (sourceIsCompleted) {
            isTeam1Placeholder = false;
          }
        }
      }
    }

    // Check team 2 placeholder similarly
    if (isTeam2Placeholder) {
      int? sourceMatchNumber;

      // Format: "match_2_winner"
      RegExp matchIdRegExp = RegExp(r'match[_]?(\d+)[_]?winner');
      final matchIdMatch = matchIdRegExp.firstMatch(team2Id);
      if (matchIdMatch != null) {
        sourceMatchNumber = int.tryParse(matchIdMatch.group(1) ?? '');
      }

      // Format: "Winner Match 2"
      if (sourceMatchNumber == null) {
        RegExp nameRegExp =
            RegExp(r'Winner\s+Match\s+(\d+)', caseSensitive: false);
        final nameMatch = nameRegExp.firstMatch(team2Name);
        if (nameMatch != null) {
          sourceMatchNumber = int.tryParse(nameMatch.group(1) ?? '');
        }
      }

      // Format: just the number at the end
      if (sourceMatchNumber == null) {
        RegExp numberRegExp = RegExp(r'(\d+)$');
        final numberMatch = numberRegExp.firstMatch(team2Id);
        if (numberMatch != null) {
          sourceMatchNumber = int.tryParse(numberMatch.group(1) ?? '');
        }
      }

      if (sourceMatchNumber != null) {
        final sourceMatch = tournamentMatches.firstWhere(
          (m) => m['matchNumber'] == sourceMatchNumber,
          orElse: () => {},
        );

        if (sourceMatch.isNotEmpty) {
          final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
          final sourceHasScores = sourceMatch['scores'] != null ||
              (sourceMatch['team1Score'] != null &&
                  sourceMatch['team2Score'] != null);
          final sourceIsCompleted =
              sourceStatus == 'completed' || sourceHasScores;

          if (sourceIsCompleted) {
            isTeam2Placeholder = false;
          }
        }
      }
    }

    // Also check nextMatchReference which might indicate this match depends on previous ones
    final nextMatchRef = match['nextMatchReference'];
    if (nextMatchRef != null && !isTeam1Placeholder && !isTeam2Placeholder) {
      // This match might be waiting for previous matches even if teams don't show as placeholders
      // For example, in your data, Match 1 and Match 2 have nextMatchReference: 3
      // That means Match 3 depends on them

      // Find all matches that reference this match as their next match
      final previousMatches = tournamentMatches
          .where((m) => m['nextMatchReference'] == match['matchNumber'])
          .toList();

      if (previousMatches.isNotEmpty) {
        // Check if all previous matches are completed
        bool allPreviousCompleted = true;
        for (var prevMatch in previousMatches) {
          final prevStatus = prevMatch['status'] as String? ?? 'scheduled';
          final prevHasScores = prevMatch['scores'] != null ||
              (prevMatch['team1Score'] != null &&
                  prevMatch['team2Score'] != null);
          final prevCompleted = prevStatus == 'completed' || prevHasScores;

          if (!prevCompleted) {
            allPreviousCompleted = false;
            break;
          }
        }

        // If not all previous matches are completed, this is still a placeholder
        if (!allPreviousCompleted) {
          return true;
        }
      }
    }

    // Return true if either team is still a placeholder
    return isTeam1Placeholder || isTeam2Placeholder;
  }

  String _getTeamDisplayName(Map<String, dynamic>? team,
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    if (team == null) return 'TBD';

    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? '';
    final teamType = team['type']?.toString() ?? '';

    // Check if it's a placeholder
    bool isPlaceholder = teamType == 'placeholder' ||
        teamId.contains('placeholder') ||
        teamId.contains('winner') ||
        teamId.contains('loser') ||
        teamName.contains('Winner') ||
        teamName.contains('Loser') ||
        team['isPlaceholder'] == true;

    if (!isPlaceholder) {
      // Regular team - return the actual name
      return team['displayName'] ?? teamName ?? 'Unknown Team';
    }

    // It's a placeholder - try to get the actual winner/loser from source match
    int? sourceMatchNumber;

    // Extract source match number from various formats
    // Format: "match_1_winner" or "match_1_loser"
    RegExp matchIdRegExp =
        RegExp(r'match[_]?(\d+)[_]?(?:winner|loser)', caseSensitive: false);
    final matchIdMatch = matchIdRegExp.firstMatch(teamId);
    if (matchIdMatch != null) {
      sourceMatchNumber = int.tryParse(matchIdMatch.group(1) ?? '');
    }

    // Format: "Winner Match 1" or "Loser Match 1"
    if (sourceMatchNumber == null) {
      RegExp nameRegExp =
          RegExp(r'(?:Winner|Loser)\s+Match\s+(\d+)', caseSensitive: false);
      final nameMatch = nameRegExp.firstMatch(teamName);
      if (nameMatch != null) {
        sourceMatchNumber = int.tryParse(nameMatch.group(1) ?? '');
      }
    }

    // Format: "Winner of Match 1"
    if (sourceMatchNumber == null) {
      RegExp ofRegExp = RegExp(r'(?:Winner|Loser)\s+of\s+Match\s+(\d+)',
          caseSensitive: false);
      final ofMatch = ofRegExp.firstMatch(teamName);
      if (ofMatch != null) {
        sourceMatchNumber = int.tryParse(ofMatch.group(1) ?? '');
      }
    }

    if (sourceMatchNumber != null) {
      // Get the tournament ID for this match to filter source matches
      final tournamentId = match['tournamentSetupId']?.toString() ?? '';

      // Filter matches to only those in the same tournament
      final tournamentMatches = allMatches
          .where((m) => m['tournamentSetupId']?.toString() == tournamentId)
          .toList();

      // Find the source match
      final sourceMatch = tournamentMatches.firstWhere(
        (m) => m['matchNumber'] == sourceMatchNumber,
        orElse: () => {},
      );

      if (sourceMatch.isNotEmpty) {
        // Check if source match is completed
        final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
        final sourceHasScores = sourceMatch['scores'] != null ||
            (sourceMatch['team1Score'] != null &&
                sourceMatch['team2Score'] != null);
        final sourceIsCompleted =
            sourceStatus == 'completed' || sourceHasScores;

        if (sourceIsCompleted) {
          // Get the winner or loser from source match
          final winner = sourceMatch['winner']?.toString();

          // Determine if this placeholder is for winner or loser
          bool isWinner = teamId.contains('winner') ||
              teamName.contains('Winner') ||
              teamType.contains('winner');

          if (isWinner && winner != null) {
            // Find the winning team in source match
            final team1 = sourceMatch['team1'] as Map<String, dynamic>?;
            final team2 = sourceMatch['team2'] as Map<String, dynamic>?;

            if (team1 != null && team1['id']?.toString() == winner) {
              return team1['displayName'] ?? team1['name'] ?? 'Unknown Team';
            } else if (team2 != null && team2['id']?.toString() == winner) {
              return team2['displayName'] ?? team2['name'] ?? 'Unknown Team';
            } else {
              // Try using team1Id/team2Id fields
              if (sourceMatch['team1Id']?.toString() == winner) {
                return sourceMatch['team1Name'] ?? 'Unknown Team';
              } else if (sourceMatch['team2Id']?.toString() == winner) {
                return sourceMatch['team2Name'] ?? 'Unknown Team';
              }
            }
          } else {
            // It's a loser placeholder - get the loser
            // Determine loser by finding which team didn't win
            final team1Id = sourceMatch['team1Id']?.toString() ??
                (sourceMatch['team1'] != null
                    ? sourceMatch['team1']['id']?.toString()
                    : '');
            final team2Id = sourceMatch['team2Id']?.toString() ??
                (sourceMatch['team2'] != null
                    ? sourceMatch['team2']['id']?.toString()
                    : '');

            if (winner != null) {
              if (team1Id == winner) {
                // Team 1 won, so loser is team 2
                return sourceMatch['team2Name'] ??
                    (sourceMatch['team2'] != null
                        ? sourceMatch['team2']['name']
                        : 'Unknown Team');
              } else if (team2Id == winner) {
                // Team 2 won, so loser is team 1
                return sourceMatch['team1Name'] ??
                    (sourceMatch['team1'] != null
                        ? sourceMatch['team1']['name']
                        : 'Unknown Team');
              }
            }
          }
        } else {
          // Source match not completed yet
          if (teamName.contains('Winner')) {
            return 'Winner of Match $sourceMatchNumber';
          } else if (teamName.contains('Loser')) {
            return 'Loser of Match $sourceMatchNumber';
          } else {
            return '${teamName.contains('Winner') ? 'Winner' : 'Team'} (Match $sourceMatchNumber)';
          }
        }
      }
    }

    // If we can't resolve, return a descriptive placeholder
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

  Future<void> _saveScore(String matchId, Map<String, dynamic> match) async {
    if (_isSaving) return;

    if (!_isEditMode && _isPlaceholderMatch(match, _allMatches)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save scores for placeholder matches'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};

    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = _getTeamId(team1);
    final team2Id = _getTeamId(team2);

    final score1Text = _scoreControllers['${matchId}_1']?.text ?? '';
    final score2Text = _scoreControllers['${matchId}_2']?.text ?? '';

    if (score1Text.isEmpty && score2Text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one score'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final score1 = int.tryParse(score1Text) ?? 0;
    final score2 = int.tryParse(score2Text) ?? 0;

    String? winner;
    if (_selectedWinners[matchId] != null &&
        _selectedWinners[matchId] != 'tie') {
      winner = _selectedWinners[matchId];
    } else if (_selectedWinners[matchId] == 'tie') {
      winner = 'tie';
    } else if (score1 > score2) {
      winner = team1Id ?? team1Name;
    } else if (score2 > score1) {
      winner = team2Id ?? team2Name;
    }

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
      if (!tournamentDoc.exists)
        throw Exception('Tournament document not found');

      final tournamentData = tournamentDoc.data() as Map<String, dynamic>;
      final matchups =
          List<Map<String, dynamic>>.from(tournamentData['matchups'] ?? []);

      final matchIndex = matchups.indexWhere((m) => m['id'] == matchId);
      if (matchIndex == -1) throw Exception('Match not found');

      // Create edit history entry
      final editHistory = List<Map<String, dynamic>>.from(
          matchups[matchIndex]['editHistory'] ?? []);
      editHistory.add({
        'timestamp': DateTime.now().toIso8601String(),
        'editedBy': _currentUserId,
        'previousScores': matchups[matchIndex]['sories'],
        'previousWinner': matchups[matchIndex]['winner'],
        'previousTeam1Score': matchups[matchIndex]['team1Score'],
        'previousTeam2Score': matchups[matchIndex]['team2Score'],
      });

      // Preserve existing data and update with new scores
      matchups[matchIndex] = {
        ...matchups[matchIndex],
        'scores': {
          team1Id ?? team1Name: score1,
          team2Id ?? team2Name: score2,
        },
        'winner': winner,
        'status': 'completed',
        'completedAt': matchups[matchIndex]['completedAt'] ??
            DateTime.now().toIso8601String(),
        'team1Score': score1,
        'team2Score': score2,
        'lastEditedAt': DateTime.now().toIso8601String(),
        'lastEditedBy': _currentUserId,
        'editHistory': editHistory,
      };

      await tournamentRef.update({'matchups': matchups});

      final updateData = {
        'scores': {
          team1Id ?? team1Name: score1,
          team2Id ?? team2Name: score2,
        },
        'winner': winner,
        'status': 'completed',
        'completedAt': match['completedAt'] ?? DateTime.now().toIso8601String(),
        'team1Score': score1,
        'team2Score': score2,
        'lastEditedAt': DateTime.now().toIso8601String(),
        'lastEditedBy': _currentUserId,
      };

      await _teamScheduleService.updateTeamSchedule(matchId, updateData);

      if (mounted) {
        String action = _isEditMode ? 'updated' : 'saved';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Score $action: $team1Name $score1 - $score2 $team2Name'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Exit edit mode after saving
        setState(() {
          _isEditMode = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  void _enterEditMode(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    final existingScores = match['scores'] as Map<String, dynamic>? ?? {};
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Id = _getTeamId(team1);
    final team2Id = _getTeamId(team2);
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);

    final score1 = existingScores[team1Id ?? team1Name] ??
        existingScores[team1Name] ??
        match['team1Score'] ??
        0;
    final score2 = existingScores[team2Id ?? team2Name] ??
        existingScores[team2Name] ??
        match['team2Score'] ??
        0;
    final existingWinner = match['winner'];

    // Initialize controllers with existing values
    if (!_scoreControllers.containsKey('${matchId}_1')) {
      _scoreControllers['${matchId}_1'] =
          TextEditingController(text: score1.toString());
    } else {
      _scoreControllers['${matchId}_1']?.text = score1.toString();
    }

    if (!_scoreControllers.containsKey('${matchId}_2')) {
      _scoreControllers['${matchId}_2'] =
          TextEditingController(text: score2.toString());
    } else {
      _scoreControllers['${matchId}_2']?.text = score2.toString();
    }

    if (existingWinner != null) {
      _selectedWinners[matchId] = existingWinner.toString();
    }

    setState(() {
      _selectedMatch = match;
      _isEditMode = true;
    });
  }

  List<Map<String, dynamic>> _filterMatchesByDateAndAssignment(
      List<Map<String, dynamic>> allSchedules) {
    return allSchedules.where((schedule) {
      // Get the tournament ID
      final tournamentId = schedule['tournamentSetupId'];
      if (tournamentId == null) return false;

      // Check if user is assigned to the tournament
      if (!_isUserAssignedToTournament(tournamentId)) return false;

      // Get match date
      final dateTimeStr = schedule['dateTime'] ?? schedule['startTime'];
      final matchDateTime = _parseMatchDateTime(dateTimeStr);

      if (matchDateTime == null) {
        print('Could not parse date for match: ${schedule['id']}');
        return false;
      }

      // Compare dates (ignore time)
      final isOnSelectedDate = matchDateTime.year == _selectedDate.year &&
          matchDateTime.month == _selectedDate.month &&
          matchDateTime.day == _selectedDate.day;

      return isOnSelectedDate;
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
              child: const Icon(Icons.scoreboard, color: Colors.deepOrange),
            ),
            const SizedBox(width: 12),
            const Text(
              'Score Encoding',
              style: TextStyle(
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          _buildDateSelector(),
          const SizedBox(width: 16),
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
                final userAssignedSchedules =
                    _filterMatchesByDateAndAssignment(allSchedules);

                final realMatches = userAssignedSchedules
                    .where((match) => !_isPlaceholderMatch(match, allSchedules))
                    .toList();
                final placeholderMatches = userAssignedSchedules
                    .where((match) => _isPlaceholderMatch(match, allSchedules))
                    .toList();

                if (userAssignedSchedules.isEmpty) {
                  return _buildEmptyState();
                }

                // Group matches by tournament
                Map<String, List<Map<String, dynamic>>> tournamentMatches = {};
                for (var match in realMatches) {
                  final tournamentId = match['tournamentSetupId'] ?? 'Unknown';
                  tournamentMatches
                      .putIfAbsent(tournamentId, () => [])
                      .add(match);
                }

                return Row(
                  children: [
                    // Left Panel - Tournament & Match List
                    Container(
                      width: 380,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          right: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMatchStats(
                              realMatches.length, placeholderMatches.length),
                          Expanded(
                            child: _buildTournamentMatchList(
                                tournamentMatches, placeholderMatches),
                          ),
                        ],
                      ),
                    ),

                    // Right Panel - Score Entry
                    Expanded(
                      child: _selectedMatch == null
                          ? _buildSelectionPrompt()
                          : _buildScoreEntryPanel(),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: _selectDate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.calendar_today,
                  size: 18, color: Colors.deepOrange.shade400),
              const SizedBox(width: 10),
              Text(
                _displayDateFormat.format(_selectedDate),
                style: const TextStyle(
                  color: Color(0xFF2D3748),
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchStats(int activeCount, int futureCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Schedule',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'Active Matches',
                activeCount.toString(),
                Colors.deepOrange,
                Icons.play_circle_filled,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Future Matches',
                futureCount.toString(),
                Colors.blue,
                Icons.schedule,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTournamentMatchList(
    Map<String, List<Map<String, dynamic>>> tournamentMatches,
    List<Map<String, dynamic>> placeholderMatches,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount:
          tournamentMatches.length + (placeholderMatches.isEmpty ? 0 : 1),
      itemBuilder: (context, index) {
        if (index < tournamentMatches.length) {
          final entry = tournamentMatches.entries.elementAt(index);
          return _buildTournamentSection(entry.key, entry.value);
        } else {
          return _buildFutureMatchesSection(placeholderMatches);
        }
      },
    );
  }

  Widget _buildTournamentSection(
      String tournamentId, List<Map<String, dynamic>> matches) {
    final tournamentName =
        _tournamentNames[tournamentId] ?? 'Unknown Tournament';
    final tournamentInfo = _tournamentDetails[tournamentId] ?? {};
    final sport = tournamentInfo['sport'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.deepOrange.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournamentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF2D3748),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        sport,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${matches.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepOrange.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...matches.map((match) => _buildMatchListItem(match)).toList(),
        ],
      ),
    );
  }

  Widget _buildMatchListItem(Map<String, dynamic> match) {
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
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);

    return InkWell(
      onTap: () {
        if (hasScores) {
          _showMatchOptionsDialog(match);
        } else {
          setState(() {
            _selectedMatch = match;
            _isEditMode = false;
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.deepOrange.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? Colors.deepOrange
                : (hasScores ? Colors.green.shade200 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: hasScores ? Colors.green : Colors.deepOrange.shade200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),

            // Team 1 Logo
            _buildTeamLogo(team1Id, team1Name, size: 30),
            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Match $matchNumber',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (matchTime.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time,
                                  size: 10, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                matchTime,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (hasScores)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_note,
                                  size: 10, color: Colors.green.shade600),
                              const SizedBox(width: 2),
                              Text(
                                'Editable',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team1Name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'vs',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          team2Name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
            _buildTeamLogo(team2Id, team2Name, size: 30),
          ],
        ),
      ),
    );
  }

  void _showMatchOptionsDialog(Map<String, dynamic> match) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Match Options'),
          content: const Text('What would you like to do with this match?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _selectedMatch = match;
                  _isEditMode = false;
                });
              },
              child: const Text('View Scores'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _enterEditMode(match);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              child: const Text('Edit Scores'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFutureMatchesSection(
      List<Map<String, dynamic>> placeholderMatches) {
    if (placeholderMatches.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child:
                      const Icon(Icons.schedule, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Future Matches',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${placeholderMatches.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ...placeholderMatches
              .map((match) => _buildFutureMatchItem(match))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildFutureMatchItem(Map<String, dynamic> match) {
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = _getTeamId(team1);
    final team2Id = _getTeamId(team2);
    final matchNumber = match['matchNumber'] ?? '#';

    // Check if this future match now has resolved teams (from previous matches)
    final isTeam1Resolved = !_isPlaceholderTeam(team1, match, _allMatches);
    final isTeam2Resolved = !_isPlaceholderTeam(team2, match, _allMatches);
    final isFullyResolved = isTeam1Resolved && isTeam2Resolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isFullyResolved ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: isFullyResolved
                  ? Colors.green.shade400
                  : Colors.blue.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // Team 1 Logo (shows actual logo if resolved, otherwise placeholder)
          _buildTeamLogo(
            isTeam1Resolved ? team1Id : null,
            team1Name,
            size: 30,
            useGradient: !isTeam1Resolved,
          ),
          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Match $matchNumber',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (isFullyResolved)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 10, color: Colors.green.shade600),
                            const SizedBox(width: 2),
                            Text(
                              'Ready',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        team1Name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isTeam1Resolved
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: isTeam1Resolved
                              ? Colors.grey.shade800
                              : Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'vs',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        team2Name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isTeam2Resolved
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: isTeam2Resolved
                              ? Colors.grey.shade800
                              : Colors.grey.shade500,
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

          // Team 2 Logo (shows actual logo if resolved, otherwise placeholder)
          const SizedBox(width: 8),
          _buildTeamLogo(
            isTeam2Resolved ? team2Id : null,
            team2Name,
            size: 30,
            useGradient: !isTeam2Resolved,
          ),

          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isFullyResolved
                  ? Colors.green.shade50
                  : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isFullyResolved ? 'Ready' : 'Waiting',
              style: TextStyle(
                fontSize: 9,
                color: isFullyResolved
                    ? Colors.green.shade700
                    : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to check if a team is a placeholder
  bool _isPlaceholderTeam(Map<String, dynamic>? team,
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    if (team == null) return true;

    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? '';
    final teamType = team['type']?.toString() ?? '';

    // Check if it's a placeholder
    bool isPlaceholder = teamType == 'placeholder' ||
        teamId.contains('placeholder') ||
        teamId.contains('winner') ||
        teamId.contains('loser') ||
        teamName.contains('Winner') ||
        teamName.contains('Loser') ||
        team['isPlaceholder'] == true;

    if (!isPlaceholder) return false;

    // Try to resolve if source match is completed
    int? sourceMatchNumber;
    RegExp matchIdRegExp =
        RegExp(r'match[_]?(\d+)[_]?(?:winner|loser)', caseSensitive: false);
    final matchIdMatch = matchIdRegExp.firstMatch(teamId);
    if (matchIdMatch != null) {
      sourceMatchNumber = int.tryParse(matchIdMatch.group(1) ?? '');
    }

    if (sourceMatchNumber == null) {
      RegExp nameRegExp =
          RegExp(r'(?:Winner|Loser)\s+Match\s+(\d+)', caseSensitive: false);
      final nameMatch = nameRegExp.firstMatch(teamName);
      if (nameMatch != null) {
        sourceMatchNumber = int.tryParse(nameMatch.group(1) ?? '');
      }
    }

    if (sourceMatchNumber != null) {
      final tournamentId = match['tournamentSetupId']?.toString() ?? '';
      final tournamentMatches = allMatches
          .where((m) => m['tournamentSetupId']?.toString() == tournamentId)
          .toList();

      final sourceMatch = tournamentMatches.firstWhere(
        (m) => m['matchNumber'] == sourceMatchNumber,
        orElse: () => {},
      );

      if (sourceMatch.isNotEmpty) {
        final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
        final sourceHasScores = sourceMatch['scores'] != null ||
            (sourceMatch['team1Score'] != null &&
                sourceMatch['team2Score'] != null);
        final sourceIsCompleted =
            sourceStatus == 'completed' || sourceHasScores;

        // If source match is completed, this team is no longer a placeholder
        if (sourceIsCompleted) {
          return false;
        }
      }
    }

    return true;
  }

  Widget _buildSelectionPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.deepOrange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.touch_app,
              size: 64,
              color: Colors.deepOrange,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select a match to encode scores',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose from the matches on the left panel',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreEntryPanel() {
    if (_selectedMatch == null) return const SizedBox();

    final match = _selectedMatch!;
    final matchId = match['id'] ?? '';
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = _getTeamId(team1);
    final team2Id = _getTeamId(team2);
    final matchNumber = match['matchNumber'] ?? '#';
    final bracket = match['bracket'] ?? 'Match';
    final matchTime = _formatMatchTime(match['dateTime'] ?? match['startTime']);

    final existingScores = match['scores'] as Map<String, dynamic>? ?? {};
    final score1 = existingScores[team1Id ?? team1Name] ??
        existingScores[team1Name] ??
        match['team1Score'] ??
        0;
    final score2 = existingScores[team2Id ?? team2Name] ??
        existingScores[team2Name] ??
        match['team2Score'] ??
        0;
    final existingWinner = match['winner'];
    final hasScores = score1 > 0 || score2 > 0 || existingScores.isNotEmpty;
    final isSavingThis = _savingMatchId == matchId;

    // Initialize controllers if not exists
    if (!_scoreControllers.containsKey('${matchId}_1')) {
      _scoreControllers['${matchId}_1'] =
          TextEditingController(text: score1.toString());
    }
    if (!_scoreControllers.containsKey('${matchId}_2')) {
      _scoreControllers['${matchId}_2'] =
          TextEditingController(text: score2.toString());
    }
    if (!_selectedWinners.containsKey(matchId) && existingWinner != null) {
      _selectedWinners[matchId] = existingWinner.toString();
    }

    return Container(
      color: const Color(0xFFF5F7FA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Edit Mode Indicator
                if (_isEditMode)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Edit Mode: You can modify the scores for this completed match',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          color: Colors.blue.shade700,
                          onPressed: () {
                            setState(() {
                              _isEditMode = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                // Match Header Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Match Info Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepOrange.shade400,
                                  Colors.deepOrange.shade600
                                ],
                              ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Text(
                              bracket.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Match $matchNumber',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D3748),
                            ),
                          ),
                          const Spacer(),
                          if (matchTime.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 18, color: Colors.grey.shade600),
                                  const SizedBox(width: 8),
                                  Text(
                                    matchTime,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Score Entry Area with Team Logos
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Team 1
                          Expanded(
                            child: Column(
                              children: [
                                // Team Logo
                                _buildTeamLogo(team1Id, team1Name, size: 120),
                                const SizedBox(height: 16),

                                // Team Name
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    team1Name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D3748),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Score Input
                                Container(
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.grey.shade300, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller:
                                        _scoreControllers['${matchId}_1'],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                          color: Colors.grey.shade400),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 16),
                                    ),
                                    enabled: !isSavingThis && _isEditMode,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // VS
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Text(
                                    'VS',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4A5568),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Team 2
                          Expanded(
                            child: Column(
                              children: [
                                // Team Logo
                                _buildTeamLogo(team2Id, team2Name, size: 120),
                                const SizedBox(height: 16),

                                // Team Name
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    team2Name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2D3748),
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Score Input
                                Container(
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: Colors.grey.shade300, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller:
                                        _scoreControllers['${matchId}_2'],
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2D3748),
                                    ),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                          color: Colors.grey.shade400),
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 16),
                                    ),
                                    enabled: !isSavingThis && _isEditMode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Winner Selection with Team Logos
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Winner',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4A5568),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildWinnerButtonWithLogo(
                                    label: team1Name,
                                    teamId: team1Id,
                                    isSelected: _selectedWinners[matchId] ==
                                        (team1Id ?? team1Name),
                                    color: Colors.deepOrange,
                                    onTap: _isEditMode
                                        ? () {
                                            setState(() {
                                              _selectedWinners[matchId] =
                                                  team1Id ?? team1Name;
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildWinnerButtonWithLogo(
                                    label: team2Name,
                                    teamId: team2Id,
                                    isSelected: _selectedWinners[matchId] ==
                                        (team2Id ?? team2Name),
                                    color: Colors.blue,
                                    onTap: _isEditMode
                                        ? () {
                                            setState(() {
                                              _selectedWinners[matchId] =
                                                  team2Id ?? team2Name;
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildWinnerButton(
                                    label: 'Tie',
                                    isSelected:
                                        _selectedWinners[matchId] == 'tie',
                                    color: Colors.purple,
                                    onTap: _isEditMode
                                        ? () {
                                            setState(() {
                                              _selectedWinners[matchId] = 'tie';
                                            });
                                          }
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: (isSavingThis || !_isEditMode)
                                  ? null
                                  : () {
                                      _scoreControllers['${matchId}_1']
                                          ?.clear();
                                      _scoreControllers['${matchId}_2']
                                          ?.clear();
                                      _selectedWinners.remove(matchId);
                                      setState(() {});
                                    },
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Reset',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: (isSavingThis || !_isEditMode)
                                  ? null
                                  : () => _saveScore(matchId, match),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isEditMode
                                    ? Colors.blue
                                    : (hasScores
                                        ? Colors.green
                                        : Colors.deepOrange),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isSavingThis
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isEditMode
                                          ? 'Update Score'
                                          : (hasScores
                                              ? 'Completed'
                                              : 'Save Score'),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                            ),
                          ),
                        ],
                      ),

                      if (hasScores && !_isEditMode) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade600, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Match completed',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (existingWinner != null &&
                                            existingWinner != 'tie')
                                          _buildTeamLogo(
                                            existingWinner == team1Id
                                                ? team1Id
                                                : team2Id,
                                            existingWinner == team1Id
                                                ? team1Name
                                                : team2Name,
                                            size: 24,
                                          ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Winner: ${existingWinner == 'tie' ? 'Tie' : (existingWinner == team1Id ? team1Name : team2Name)}',
                                            style: TextStyle(
                                              color: Colors.green.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (match['lastEditedAt'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          'Last edited: ${DateFormat('MMM dd, yyyy hh:mm a').format(DateTime.parse(match['lastEditedAt']))}',
                                          style: TextStyle(
                                            color: Colors.green.shade400,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () => _enterEditMode(match),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Add this new method for winner buttons with logos
  Widget _buildWinnerButtonWithLogo({
    required String label,
    required String? teamId,
    required bool isSelected,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildTeamLogo(teamId, label, size: 40),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle, color: color, size: 16),
                if (isSelected) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? color : Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWinnerButton({
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isSelected) Icon(Icons.check_circle, color: color, size: 18),
            if (isSelected) const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading matches',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(error, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Retry'),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child:
                Icon(Icons.sports_score, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            'No matches scheduled',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            'for ${_displayDateFormat.format(_selectedDate)}',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
            },
            icon: const Icon(Icons.today),
            label: const Text('View Today\'s Matches'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
