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

  // Filter mode - 'date' or 'all'
  String _filterMode = 'date'; // 'date' or 'all'

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

  void _toggleFilterMode() {
    setState(() {
      _filterMode = _filterMode == 'date' ? 'all' : 'date';
      _selectedTournamentId = null;
      _selectedMatch = null;
      _isEditMode = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _filterMode == 'all'
              ? 'Showing all matches regardless of date'
              : 'Showing matches for selected date',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.deepOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
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

  // ============== FIXED METHODS FOR DOUBLE ELIMINATION ==============

  // Helper method to check if a match is a placeholder that cannot be played yet
  bool _isPlaceholderMatch(
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    
    // If match is already completed, it's definitely NOT a placeholder
    final status = match['status'] as String? ?? 'scheduled';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    
    if (status == 'completed' || hasScores) {
      return false;
    }

    // Get team information
    final team1 = match['team1'] as Map<String, dynamic>?;
    final team2 = match['team2'] as Map<String, dynamic>?;
    
    if (team1 == null || team2 == null) return true;

    final team1Id = team1['id']?.toString() ?? '';
    final team2Id = team2['id']?.toString() ?? '';
    final team1Name = team1['name']?.toString() ?? '';
    final team2Name = team2['name']?.toString() ?? '';

    // Check if teams are real participants (valid Firestore IDs)
    bool isTeam1Real = _isRealParticipant(team1Id, team1);
    bool isTeam2Real = _isRealParticipant(team2Id, team2);

    // If both teams are real participants, it's a real match
    if (isTeam1Real && isTeam2Real) {
      return false;
    }

    // If either team is a placeholder (winner/loser of previous match), 
    // check if that previous match is completed
    bool team1Ready = _isTeamReady(team1, match, allMatches);
    bool team2Ready = _isTeamReady(team2, match, allMatches);

    // Match can be played if both teams are ready
    return !(team1Ready && team2Ready);
  }

  // Check if a team is a real participant (not a placeholder)
  bool _isRealParticipant(String teamId, Map<String, dynamic>? team) {
    if (teamId.isEmpty) return false;
    
    // Check if it's a placeholder identifier
    if (teamId.contains('winner') || 
        teamId.contains('loser') || 
        teamId.contains('placeholder') ||
        teamId.contains('match_')) {
      return false;
    }
    
    // Check team object properties
    if (team != null) {
      final teamType = team['type']?.toString() ?? '';
      if (teamType == 'placeholder' || team['isPlaceholder'] == true) {
        return false;
      }
    }
    
    // Valid Firestore IDs are typically 20+ characters alphanumeric
    // But we'll be less strict - if it has a name and not placeholder patterns, consider it real
    return true;
  }

  // Check if a team is ready to play (source matches completed if placeholder)
  bool _isTeamReady(Map<String, dynamic>? team, 
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    
    if (team == null) return false;

    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? '';
    final teamType = team['type']?.toString() ?? '';

    // If it's a real participant, it's ready
    if (_isRealParticipant(teamId, team)) return true;

    // Check if it's a placeholder that depends on previous match
    int? sourceMatchNumber = _extractSourceMatchNumber(teamId, teamName);
    
    if (sourceMatchNumber == null) {
      // If we can't extract source match, assume it's not ready
      return false;
    }

    // Get tournament ID
    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    
    // Find source match
    final sourceMatch = allMatches.firstWhere(
      (m) => m['tournamentSetupId']?.toString() == tournamentId && 
             m['matchNumber'] == sourceMatchNumber,
      orElse: () => {},
    );

    if (sourceMatch.isEmpty) return false;

    // Check if source match is completed
    final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
    final sourceHasScores = sourceMatch['scores'] != null ||
        (sourceMatch['team1Score'] != null && sourceMatch['team2Score'] != null);
    
    return sourceStatus == 'completed' || sourceHasScores;
  }

  // Extract source match number from placeholder identifier
  int? _extractSourceMatchNumber(String teamId, String teamName) {
    // Try various patterns
    List<RegExp> patterns = [
      RegExp(r'match[_]?(\d+)[_]?(?:winner|loser)', caseSensitive: false),
      RegExp(r'(?:winner|loser)\s+match\s+(\d+)', caseSensitive: false),
      RegExp(r'(?:winner|loser)\s+of\s+match\s+(\d+)', caseSensitive: false),
      RegExp(r'(\d+)$'), // numbers at the end
    ];
    
    for (var pattern in patterns) {
      // Try on teamId
      if (teamId.isNotEmpty) {
        final match = pattern.firstMatch(teamId);
        if (match != null) {
          return int.tryParse(match.group(1) ?? '');
        }
      }
      
      // Try on teamName
      if (teamName.isNotEmpty) {
        final match = pattern.firstMatch(teamName);
        if (match != null) {
          return int.tryParse(match.group(1) ?? '');
        }
      }
    }
    
    return null;
  }

  // Get display name for a team (resolves placeholders if source match completed)
  String _getTeamDisplayName(Map<String, dynamic>? team,
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    
    if (team == null) return 'TBD';

    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? '';
    final teamType = team['type']?.toString() ?? '';

    // If it's a real participant, return the name
    if (_isRealParticipant(teamId, team)) {
      return team['displayName'] ?? teamName ?? 'Unknown Team';
    }

    // Try to resolve placeholder
    int? sourceMatchNumber = _extractSourceMatchNumber(teamId, teamName);
    
    if (sourceMatchNumber != null) {
      final tournamentId = match['tournamentSetupId']?.toString() ?? '';
      
      final sourceMatch = allMatches.firstWhere(
        (m) => m['tournamentSetupId']?.toString() == tournamentId && 
               m['matchNumber'] == sourceMatchNumber,
        orElse: () => {},
      );

      if (sourceMatch.isNotEmpty) {
        // Check if source match is completed
        final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
        final sourceHasScores = sourceMatch['scores'] != null ||
            (sourceMatch['team1Score'] != null && sourceMatch['team2Score'] != null);
        final sourceIsCompleted = sourceStatus == 'completed' || sourceHasScores;

        if (sourceIsCompleted) {
          // Determine if this is for winner or loser
          bool isWinner = teamId.contains('winner') || 
                         teamName.contains('Winner') ||
                         teamType.contains('winner');

          if (isWinner) {
            // Get winner from source match
            final winner = sourceMatch['winner']?.toString();
            if (winner != null) {
              // Find winning team
              final team1 = sourceMatch['team1'] as Map<String, dynamic>?;
              final team2 = sourceMatch['team2'] as Map<String, dynamic>?;
              
              if (team1 != null && team1['id']?.toString() == winner) {
                return team1['displayName'] ?? team1['name'] ?? 'Unknown Team';
              } else if (team2 != null && team2['id']?.toString() == winner) {
                return team2['displayName'] ?? team2['name'] ?? 'Unknown Team';
              }
            }
          } else {
            // Get loser from source match
            final winner = sourceMatch['winner']?.toString();
            final team1 = sourceMatch['team1'] as Map<String, dynamic>?;
            final team2 = sourceMatch['team2'] as Map<String, dynamic>?;
            
            if (winner != null && team1 != null && team2 != null) {
              if (team1['id']?.toString() == winner) {
                return team2['displayName'] ?? team2['name'] ?? 'Unknown Team';
              } else if (team2['id']?.toString() == winner) {
                return team1['displayName'] ?? team1['name'] ?? 'Unknown Team';
              }
            }
          }
        } else {
          // Source match not completed yet
          if (teamName.contains('Winner')) {
            return 'Winner of Match $sourceMatchNumber';
          } else if (teamName.contains('Loser')) {
            return 'Loser of Match $sourceMatchNumber';
          }
        }
      }
    }

    // Return placeholder text if can't resolve
    if (teamName.contains('Winner')) return teamName;
    if (teamName.contains('Loser')) return teamName;
    if (teamId.contains('winner')) return 'Winner (TBD)';
    if (teamId.contains('loser')) return 'Loser (TBD)';
    
    return teamName.isNotEmpty ? teamName : 'TBD';
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

  // ============== END OF FIXED METHODS ==============

  Future<void> _saveScore(String matchId, Map<String, dynamic> match) async {
    if (_isSaving) return;

    // Check if match is a placeholder (cannot be played yet)
    if (_isPlaceholderMatch(match, _allMatches)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save scores for placeholder matches - waiting for previous matches to complete'),
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
        'previousScores': matchups[matchIndex]['scores'],
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

  List<Map<String, dynamic>> _filterMatchesByMode(
      List<Map<String, dynamic>> allSchedules) {
    
    if (_filterMode == 'all') {
      // Return all matches regardless of date
      return allSchedules.where((schedule) {
        final tournamentId = schedule['tournamentSetupId'];
        if (tournamentId == null) return false;
        return _isUserAssignedToTournament(tournamentId);
      }).toList();
    } else {
      // Filter by selected date
      return allSchedules.where((schedule) {
        final tournamentId = schedule['tournamentSetupId'];
        if (tournamentId == null) return false;

        if (!_isUserAssignedToTournament(tournamentId)) return false;

        final dateTimeStr = schedule['dateTime'] ?? schedule['startTime'];
        final matchDateTime = _parseMatchDateTime(dateTimeStr);

        if (matchDateTime == null) return false;

        return matchDateTime.year == _selectedDate.year &&
            matchDateTime.month == _selectedDate.month &&
            matchDateTime.day == _selectedDate.day;
      }).toList();
    }
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
          // Filter mode toggle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterChip('Date', 'date'),
                _buildFilterChip('All', 'all'),
              ],
            ),
          ),
          if (_filterMode == 'date') _buildDateSelector(),
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
                    _filterMatchesByMode(allSchedules);

                // Separate real matches from placeholders
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

  Widget _buildFilterChip(String label, String mode) {
    final isSelected = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        if (_filterMode != mode) {
          _toggleFilterMode();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
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
    String subtitle = _filterMode == 'all' 
        ? 'All Matches' 
        : 'Matches for ${_displayDateFormat.format(_selectedDate)}';
    
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
          Row(
            children: [
              Text(
                _filterMode == 'all' ? 'All Matches' : 'Today\'s Schedule',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.deepOrange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatCard(
                'Available Matches',
                activeCount.toString(),
                Colors.deepOrange,
                Icons.play_circle_filled,
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                'Pending',
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
    final bracketType = tournamentInfo['bracketType'] ?? 'single';
    final bracketIcon = bracketType == 'double' 
        ? Icons.sports_esports 
        : Icons.emoji_events;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bracketType == 'double' 
                  ? Colors.purple.withOpacity(0.05)
                  : Colors.deepOrange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: bracketType == 'double'
                    ? Colors.purple.withOpacity(0.2)
                    : Colors.deepOrange.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: bracketType == 'double' 
                        ? Colors.purple 
                        : Colors.deepOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(bracketIcon, color: Colors.white, size: 14),
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
                      Row(
                        children: [
                          Text(
                            sport,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (bracketType == 'double') ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Double Elim',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: bracketType == 'double'
                        ? Colors.purple.shade100
                        : Colors.deepOrange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${matches.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: bracketType == 'double'
                          ? Colors.purple.shade700
                          : Colors.deepOrange.shade700,
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
    
    // Check if this is a double elimination match
    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    final tournamentInfo = _tournamentDetails[tournamentId];
    final isDoubleElim = tournamentInfo?['bracketType'] == 'double';

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
                color: hasScores 
                    ? Colors.green 
                    : (isDoubleElim ? Colors.purple.shade300 : Colors.deepOrange.shade200),
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
                      if (isDoubleElim) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            match['matchType']?.toString().toLowerCase() ?? 'DE',
                            style: TextStyle(
                              fontSize: 8,
                              color: Colors.purple.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
                              Icon(Icons.check_circle,
                                  size: 10, color: Colors.green.shade600),
                              const SizedBox(width: 2),
                              Text(
                                'Completed',
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
                  'Pending Matches',
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

    // Check if teams are ready
    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    final tournamentInfo = _tournamentDetails[tournamentId];
    final isDoubleElim = tournamentInfo?['bracketType'] == 'double';
    
    final isTeam1Ready = _isTeamReady(team1, match, _allMatches);
    final isTeam2Ready = _isTeamReady(team2, match, _allMatches);
    final isFullyResolved = isTeam1Ready && isTeam2Ready;

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
                  : (isDoubleElim ? Colors.purple.shade300 : Colors.blue.shade200),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          // Team 1 Logo
          _buildTeamLogo(
            isTeam1Ready ? team1Id : null,
            team1Name,
            size: 30,
            useGradient: !isTeam1Ready,
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
                    if (isDoubleElim) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          match['matchType']?.toString().toLowerCase() ?? 'DE',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
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
                          fontWeight: isTeam1Ready
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: isTeam1Ready
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
                          fontWeight: isTeam2Ready
                              ? FontWeight.w500
                              : FontWeight.normal,
                          color: isTeam2Ready
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

          // Team 2 Logo
          const SizedBox(width: 8),
          _buildTeamLogo(
            isTeam2Ready ? team2Id : null,
            team2Name,
            size: 30,
            useGradient: !isTeam2Ready,
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
            _filterMode == 'all'
                ? 'Showing all matches from all tournaments'
                : 'Choose from the matches on the left panel',
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

    // Check if this is a placeholder match
    final isPlaceholder = _isPlaceholderMatch(match, _allMatches);

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

                // Placeholder Warning
                if (isPlaceholder && !hasScores)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This match is waiting for previous matches to complete before it can be played',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                                    enabled: !isSavingThis && 
                                            (_isEditMode || !hasScores) && 
                                            !isPlaceholder,
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
                                    enabled: !isSavingThis && 
                                            (_isEditMode || !hasScores) && 
                                            !isPlaceholder,
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
                                    onTap: (_isEditMode || !hasScores) && !isPlaceholder
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
                                    onTap: (_isEditMode || !hasScores) && !isPlaceholder
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
                                    onTap: (_isEditMode || !hasScores) && !isPlaceholder
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
                              onPressed: (isSavingThis || 
                                        isPlaceholder || 
                                        (!_isEditMode && hasScores))
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
                              onPressed: (isSavingThis || 
                                        isPlaceholder || 
                                        (!_isEditMode && hasScores))
                                  ? null
                                  : () => _saveScore(matchId, match),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPlaceholder
                                    ? Colors.grey
                                    : (_isEditMode
                                        ? Colors.blue
                                        : (hasScores
                                            ? Colors.green
                                            : Colors.deepOrange)),
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
                                      isPlaceholder
                                          ? 'Cannot Score'
                                          : (_isEditMode
                                              ? 'Update Score'
                                              : (hasScores
                                                  ? 'Completed'
                                                  : 'Save Score')),
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

                      if (isPlaceholder && !hasScores)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info, color: Colors.orange.shade700, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This match will become available once previous matches are completed.',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
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
    );
  }

  // Winner button with logo
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
    String message = _filterMode == 'all'
        ? 'No matches found in any tournament'
        : 'No matches scheduled for ${_displayDateFormat.format(_selectedDate)}';
    
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
            'No matches found',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (_filterMode == 'date')
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
          if (_filterMode == 'all')
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _filterMode = 'date';
                });
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('Switch to Date View'),
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