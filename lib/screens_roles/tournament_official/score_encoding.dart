import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';

class ScoreEncodingScreen extends StatefulWidget {
  const ScoreEncodingScreen({super.key});

  @override
  State<ScoreEncodingScreen> createState() => _ScoreEncodingScreenState();
}

class _ScoreEncodingScreenState extends State<ScoreEncodingScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final TournamentService _tournamentService = TournamentService();
  final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');
  final DateFormat _displayTimeFormat = DateFormat('hh:mm a');
  final Map<String, String> _teamLogos = {};
  
  late AnimationController _animationController;
  final ScrollController _leftPanelScrollController = ScrollController();
  final ScrollController _rightPanelScrollController = ScrollController();

  DateTime _selectedDate = DateTime.now();
  String? _currentUserId;
  Map<String, String> _tournamentNames = {};
  Map<String, Map<String, dynamic>> _tournamentDetails = {};
  bool _isLoading = true;

  String _filterMode = 'date';

  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _filteredMatches = [];

  String? _selectedTournamentId;
  Map<String, dynamic>? _selectedMatch;

  String? _currentEditingMatchId;
  final Map<String, MatchScoreState> _matchScoreStates = {};
  
  // Mobile view state
  bool _isMobileView = false;
  bool _showMatchList = true;
  bool _showScoreEntry = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadCurrentUser();
    _loadTournamentData();
    _checkScreenSize();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _leftPanelScrollController.dispose();
    _rightPanelScrollController.dispose();
    for (var state in _matchScoreStates.values) {
      state.dispose();
    }
    super.dispose();
  }

  void _checkScreenSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final screenWidth = MediaQuery.of(context).size.width;
        setState(() {
          _isMobileView = screenWidth < 800;
        });
      }
    });
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
    } catch (e) {}
  }

  Widget _buildTeamLogo(String? teamId, String teamName,
      {double size = 40, bool useGradient = true}) {
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

  void _selectMatch(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    
    if (!_matchScoreStates.containsKey(matchId)) {
      _matchScoreStates[matchId] = MatchScoreState.fromMatch(match);
    }
    
    setState(() {
      _selectedMatch = match;
      _currentEditingMatchId = matchId;
      if (_isMobileView) {
        _showMatchList = false;
        _showScoreEntry = true;
      }
    });
  }

  void _backToMatchList() {
    setState(() {
      _showMatchList = true;
      _showScoreEntry = false;
      _selectedMatch = null;
      _currentEditingMatchId = null;
    });
  }

  MatchScoreState? _getCurrentMatchState() {
    if (_currentEditingMatchId == null) return null;
    return _matchScoreStates[_currentEditingMatchId];
  }

  void _updateScore(String matchId, String team, String value) {
    final state = _matchScoreStates[matchId];
    if (state != null) {
      state.updateScore(team, value);
    }
  }

  void _updateWinner(String matchId, String winner) {
    final state = _matchScoreStates[matchId];
    if (state != null) {
      state.updateWinner(winner);
    }
  }

  void _resetScores(String matchId) {
    final state = _matchScoreStates[matchId];
    if (state != null) {
      state.reset();
    }
  }

  void _enterEditMode(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    final state = _matchScoreStates[matchId];
    if (state != null) {
      state.setEditMode(true);
      setState(() {});
    }
  }

  void _exitEditMode(String matchId) {
    final state = _matchScoreStates[matchId];
    if (state != null) {
      state.setEditMode(false);
      setState(() {});
    }
  }

  Future<void> _saveScore(String matchId, Map<String, dynamic> match) async {
    final state = _matchScoreStates[matchId];
    if (state == null || state.isSaving) return;

    state.setSaving(true);

    try {
      final team1Obj = match['team1'] as Map<String, dynamic>? ?? {};
      final team2Obj = match['team2'] as Map<String, dynamic>? ?? {};

      String team1Id = team1Obj['id']?.toString() ?? match['team1Id']?.toString() ?? '';
      String team2Id = team2Obj['id']?.toString() ?? match['team2Id']?.toString() ?? '';
      String team1Name = team1Obj['displayName']?.toString() ?? team1Obj['name']?.toString() ?? 
                         match['team1DisplayName']?.toString() ?? match['team1Name']?.toString() ?? '';
      String team2Name = team2Obj['displayName']?.toString() ?? team2Obj['name']?.toString() ??
                         match['team2DisplayName']?.toString() ?? match['team2Name']?.toString() ?? '';

      final score1 = state.score1;
      final score2 = state.score2;
      final winner = state.selectedWinner;

      if (score1 == 0 && score2 == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter scores'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        state.setSaving(false);
        return;
      }

      final tournamentId = match['tournamentSetupId']?.toString();
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
      final matchups = List<Map<String, dynamic>>.from(tournamentData['matchups'] ?? []);

      final matchIndex = matchups.indexWhere((m) => m['id'] == matchId);
      if (matchIndex == -1) throw Exception('Match not found');

      final Map<String, dynamic> scoresMap = {};
      if (team1Id.isNotEmpty && !team1Id.contains('match_')) {
        scoresMap[team1Id] = score1;
      } else {
        scoresMap[team1Name] = score1;
      }
      
      if (team2Id.isNotEmpty && !team2Id.contains('match_')) {
        scoresMap[team2Id] = score2;
      } else {
        scoresMap[team2Name] = score2;
      }

      final Map<String, dynamic> updatedMatch = Map<String, dynamic>.from(matchups[matchIndex]);
      updatedMatch['scores'] = scoresMap;
      updatedMatch['winner'] = winner;
      updatedMatch['status'] = 'completed';
      updatedMatch['team1Score'] = score1;
      updatedMatch['team2Score'] = score2;
      updatedMatch['lastEditedAt'] = DateTime.now().toIso8601String();
      updatedMatch['lastEditedBy'] = _currentUserId;

      matchups[matchIndex] = updatedMatch;

      await tournamentRef.update({
        'matchups': matchups,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final allMatchesIndex = _allMatches.indexWhere((m) => m['id'] == matchId);
      if (allMatchesIndex != -1) {
        _allMatches[allMatchesIndex] = {
          ..._allMatches[allMatchesIndex],
          ...updatedMatch,
        };
      }

      final filteredIndex = _filteredMatches.indexWhere((m) => m['id'] == matchId);
      if (filteredIndex != -1) {
        _filteredMatches[filteredIndex] = {
          ..._filteredMatches[filteredIndex],
          ...updatedMatch,
        };
      }

      state.updateFromMatch(updatedMatch);
      state.setEditMode(false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Score saved: $team1Name $score1 - $score2 $team2Name'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving scores: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      state.setSaving(false);
      if (mounted) setState(() {});
    }
  }

  bool _isPlaceholderMatch(Map<String, dynamic> match) {
    final status = match['status'] as String? ?? 'scheduled';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    
    if (status == 'completed' || hasScores) return false;

    final team1 = match['team1'] as Map<String, dynamic>?;
    final team2 = match['team2'] as Map<String, dynamic>?;
    
    if (team1 == null || team2 == null) return true;

    final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString() ?? '';
    final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString() ?? '';

    bool isTeam1Real = _isRealParticipant(team1Id, team1);
    bool isTeam2Real = _isRealParticipant(team2Id, team2);

    if (isTeam1Real && isTeam2Real) return false;

    bool team1Ready = _isTeamReady(team1, match);
    bool team2Ready = _isTeamReady(team2, match);

    return !(team1Ready && team2Ready);
  }

  bool _isRealParticipant(String teamId, Map<String, dynamic>? team) {
    if (teamId.isEmpty) return false;
    
    if (teamId.contains('winner') || teamId.contains('loser') || 
        teamId.contains('placeholder') || teamId.contains('match_')) {
      return false;
    }
    
    if (team != null) {
      final teamType = team['type']?.toString() ?? '';
      if (teamType == 'placeholder' || team['isPlaceholder'] == true) return false;
      
      final teamName = team['name']?.toString() ?? '';
      final teamDisplayName = team['displayName']?.toString() ?? '';
      
      if (teamName.contains('Winner') || teamName.contains('Loser') || 
          teamName.contains('TBD') || teamName.contains('Match')) return false;
      
      if (teamDisplayName.contains('Winner') || teamDisplayName.contains('Loser') || 
          teamDisplayName.contains('TBD') || teamDisplayName.contains('Match')) return false;
    }
    
    return teamId.length > 5 && !teamId.contains('match_');
  }

  bool _isTeamReady(Map<String, dynamic>? team, Map<String, dynamic> match) {
    if (team == null) return false;

    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? '';

    if (_isRealParticipant(teamId, team)) return true;

    int? sourceMatchNumber;
    
    if (team['sourceMatch'] != null) {
      sourceMatchNumber = team['sourceMatch'] as int?;
    }
    
    if (sourceMatchNumber == null) {
      sourceMatchNumber = _extractSourceMatchNumber(teamId, teamName);
    }
    
    if (sourceMatchNumber == null) return false;

    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    
    final sourceMatch = _allMatches.firstWhere(
      (m) => m['tournamentSetupId']?.toString() == tournamentId && 
             m['matchNumber'] == sourceMatchNumber,
      orElse: () => <String, dynamic>{},
    );

    if (sourceMatch.isEmpty) return false;

    final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
    final sourceHasScores = sourceMatch['scores'] != null ||
        (sourceMatch['team1Score'] != null && sourceMatch['team2Score'] != null);
    final sourceWinner = sourceMatch['winner'] as String?;
    final hasWinner = sourceWinner != null && sourceWinner.isNotEmpty;
    
    return (sourceStatus == 'completed' || sourceHasScores) && hasWinner;
  }

  int? _extractSourceMatchNumber(String teamId, String teamName) {
    List<RegExp> patterns = [
      RegExp(r'match[_]?(\d+)[_]?(?:winner|loser)', caseSensitive: false),
      RegExp(r'(?:winner|loser)\s+match\s+(\d+)', caseSensitive: false),
      RegExp(r'(?:winner|loser)\s+of\s+match\s+(\d+)', caseSensitive: false),
      RegExp(r'from\s+match\s+(\d+)', caseSensitive: false),
      RegExp(r'(\d+)$'),
    ];
    
    for (var pattern in patterns) {
      if (teamId.isNotEmpty) {
        final match = pattern.firstMatch(teamId);
        if (match != null) {
          return int.tryParse(match.group(1) ?? '');
        }
      }
      
      if (teamName.isNotEmpty) {
        final match = pattern.firstMatch(teamName);
        if (match != null) {
          return int.tryParse(match.group(1) ?? '');
        }
      }
    }
    
    return null;
  }

  String _getTeamDisplayName(Map<String, dynamic>? team,
      Map<String, dynamic> match, List<Map<String, dynamic>> allMatches) {
    
    if (team == null) {
      if (match.containsKey('team1Name') && match['team1'] == team) {
        return match['team1Name']?.toString() ?? match['team1DisplayName']?.toString() ?? 'TBD';
      }
      if (match.containsKey('team2Name') && match['team2'] == team) {
        return match['team2Name']?.toString() ?? match['team2DisplayName']?.toString() ?? 'TBD';
      }
      return 'TBD';
    }

    final teamId = team['id']?.toString() ?? '';
    final teamName = team['name']?.toString() ?? '';
    final teamDisplayName = team['displayName']?.toString() ?? '';
    final teamType = team['type']?.toString() ?? '';

    if (_isRealParticipant(teamId, team)) {
      String realName = teamDisplayName.isNotEmpty ? teamDisplayName : teamName;
      return realName;
    }

    if (teamId.contains('winner') || teamId.contains('loser') || 
        teamName.contains('Winner') || teamName.contains('Loser') ||
        teamType == 'placeholder') {
      
      int? sourceMatchNumber;
      
      if (team['sourceMatch'] != null) {
        sourceMatchNumber = team['sourceMatch'] as int?;
      }
      
      if (sourceMatchNumber == null) {
        sourceMatchNumber = _extractSourceMatchNumber(teamId, teamName);
      }
      
      if (sourceMatchNumber != null) {
        final tournamentId = match['tournamentSetupId']?.toString() ?? '';
        
        final sourceMatch = allMatches.firstWhere(
          (m) => m['tournamentSetupId']?.toString() == tournamentId && 
                 m['matchNumber'] == sourceMatchNumber,
          orElse: () => <String, dynamic>{},
        );

        if (sourceMatch.isNotEmpty) {
          final sourceStatus = sourceMatch['status'] as String? ?? 'scheduled';
          final sourceHasScores = sourceMatch['scores'] != null ||
              (sourceMatch['team1Score'] != null && sourceMatch['team2Score'] != null);
          final sourceWinner = sourceMatch['winner'] as String?;
          final hasWinner = sourceWinner != null && sourceWinner.isNotEmpty;

          if (sourceStatus == 'completed' || (sourceHasScores && hasWinner)) {
            bool isWinner = teamId.contains('winner') || 
                           teamName.contains('Winner') ||
                           teamType.contains('winner');

            if (isWinner) {
              String? winnerName = _getWinnerNameFromMatch(sourceMatch, sourceWinner);
              if (winnerName != null && winnerName.isNotEmpty && !winnerName.contains('Winner')) {
                return winnerName;
              }
            } else {
              String? loserName = _getLoserNameFromMatch(sourceMatch, sourceWinner);
              if (loserName != null && loserName.isNotEmpty && !loserName.contains('Loser')) {
                return loserName;
              }
            }
          } else {
            String type = teamName.contains('Winner') || teamId.contains('winner') ? 'Winner' : 'Loser';
            return '$type of Match $sourceMatchNumber';
          }
        }
      }
    }

    if (teamDisplayName.isNotEmpty && 
        !teamDisplayName.contains('Winner') && 
        !teamDisplayName.contains('Loser')) {
      return teamDisplayName;
    }
    
    if (teamName.isNotEmpty && 
        !teamName.contains('Winner') && 
        !teamName.contains('Loser')) {
      return teamName;
    }

    return teamDisplayName.isNotEmpty ? teamDisplayName : 'TBD';
  }

  String? _getWinnerNameFromMatch(Map<String, dynamic> match, String? winnerId) {
    if (winnerId == null || winnerId.isEmpty) return null;
    
    final team1 = match['team1'] as Map<String, dynamic>?;
    final team2 = match['team2'] as Map<String, dynamic>?;
    
    if (team1 != null) {
      final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
      if (team1Id == winnerId) {
        return team1['displayName']?.toString() ?? team1['name']?.toString() ?? 'Unknown Team';
      }
    }
    
    if (team2 != null) {
      final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();
      if (team2Id == winnerId) {
        return team2['displayName']?.toString() ?? team2['name']?.toString() ?? 'Unknown Team';
      }
    }
    
    if (match['team1Id']?.toString() == winnerId) {
      return match['team1DisplayName']?.toString() ?? match['team1Name']?.toString() ?? 'Unknown Team';
    }
    
    if (match['team2Id']?.toString() == winnerId) {
      return match['team2DisplayName']?.toString() ?? match['team2Name']?.toString() ?? 'Unknown Team';
    }
    
    return _getTeamNameFromId(winnerId);
  }

  String? _getLoserNameFromMatch(Map<String, dynamic> match, String? winnerId) {
    if (winnerId == null || winnerId.isEmpty) return null;
    
    final team1 = match['team1'] as Map<String, dynamic>?;
    final team2 = match['team2'] as Map<String, dynamic>?;
    
    if (team1 != null && team2 != null) {
      final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
      final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();
      
      if (team1Id == winnerId && team2Id != null) {
        return team2['displayName']?.toString() ?? team2['name']?.toString() ?? 'Unknown Team';
      }
      
      if (team2Id == winnerId && team1Id != null) {
        return team1['displayName']?.toString() ?? team1['name']?.toString() ?? 'Unknown Team';
      }
    }
    
    final team1Id = match['team1Id']?.toString();
    final team2Id = match['team2Id']?.toString();
    
    if (team1Id == winnerId && team2Id != null) {
      return match['team2DisplayName']?.toString() ?? match['team2Name']?.toString() ?? 'Unknown Team';
    }
    
    if (team2Id == winnerId && team1Id != null) {
      return match['team1DisplayName']?.toString() ?? match['team1Name']?.toString() ?? 'Unknown Team';
    }
    
    return null;
  }

  String? _getTeamNameFromId(String? teamId) {
    if (teamId == null || teamId.isEmpty) return null;
    
    for (var match in _allMatches) {
      final team1 = match['team1'] as Map<String, dynamic>?;
      final team2 = match['team2'] as Map<String, dynamic>?;
      
      if (team1 != null) {
        final id = team1['id']?.toString() ?? match['team1Id']?.toString();
        if (id == teamId) {
          String? name = team1['displayName']?.toString() ?? team1['name']?.toString() ??
                        match['team1DisplayName']?.toString() ?? match['team1Name']?.toString();
          if (name != null && !name.contains('Winner') && !name.contains('Loser')) {
            return name;
          }
        }
      }
      
      if (team2 != null) {
        final id = team2['id']?.toString() ?? match['team2Id']?.toString();
        if (id == teamId) {
          String? name = team2['displayName']?.toString() ?? team2['name']?.toString() ??
                        match['team2DisplayName']?.toString() ?? match['team2Name']?.toString();
          if (name != null && !name.contains('Winner') && !name.contains('Loser')) {
            return name;
          }
        }
      }
    }
    return null;
  }

  bool _isUserAssignedToTournament(String tournamentId) {
    final tournamentInfo = _tournamentDetails[tournamentId];
    if (tournamentInfo == null) return false;
    final assignedUsers = tournamentInfo['assignedUsers'] as List<String>? ?? [];
    if (assignedUsers.isEmpty) return true;
    return _currentUserId != null && assignedUsers.contains(_currentUserId);
  }

  bool _isTournamentCompleted(String tournamentId) {
    final tournamentMatches = _allMatches
        .where((match) => match['tournamentSetupId']?.toString() == tournamentId)
        .toList();
    
    if (tournamentMatches.isEmpty) return false;
    
    for (var match in tournamentMatches) {
      final status = match['status'] as String? ?? 'scheduled';
      final hasScores = match['scores'] != null ||
          (match['team1Score'] != null && match['team2Score'] != null);
      
      if (status != 'completed' && !hasScores) return false;
    }
    
    return true;
  }

  int _getHighestRound(List<Map<String, dynamic>> matches) {
    int highestRound = 0;
    for (var match in matches) {
      final round = match['round'] as int? ?? 0;
      if (round > highestRound) highestRound = round;
    }
    return highestRound;
  }

  List<Map<String, dynamic>> _filterMatchesByMode(List<Map<String, dynamic>> allSchedules) {
    if (_filterMode == 'all') {
      return allSchedules.where((schedule) {
        final tournamentId = schedule['tournamentSetupId'];
        if (tournamentId == null) return false;
        return _isUserAssignedToTournament(tournamentId);
      }).toList();
    } else {
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
    super.build(context);
    
    // For mobile view, show either match list or score entry
    if (_isMobileView) {
      if (_showScoreEntry && _selectedMatch != null) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: _buildMobileScoreEntryAppBar(),
          body: _buildMobileScoreEntryPanel(),
        );
      } else {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          appBar: _buildMobileAppBar(),
          body: _buildMobileMatchList(),
        );
      }
    }
    
    // Desktop view with split panel
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildDesktopAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tournaments')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                final List<Map<String, dynamic>> allSchedules = [];
                
                for (var doc in snapshot.data!.docs) {
                  final tournamentData = doc.data() as Map<String, dynamic>;
                  final tournamentId = tournamentData['id'] ?? doc.id;
                  final tournamentName = tournamentData['name'] ?? 'Unnamed Tournament';
                  
                  final matchups = tournamentData['matchups'] as List<dynamic>? ?? [];
                  
                  for (var matchup in matchups) {
                    final match = Map<String, dynamic>.from(matchup as Map);
                    
                    match['tournamentSetupId'] = tournamentId;
                    match['tournamentName'] = tournamentName;
                    match['sport'] = tournamentData['sport'] ?? 'Unknown';
                    match['category'] = tournamentData['category'] ?? 'Unknown';
                    match['gender'] = tournamentData['gender'] ?? 'Unknown';
                    match['venue'] = tournamentData['venue'] ?? 'Not specified';
                    
                    allSchedules.add(match);
                  }
                }

                if (_allMatches.isEmpty || _allMatches.length != allSchedules.length) {
                  _allMatches = allSchedules;
                  _filteredMatches = _filterMatchesByMode(allSchedules);
                }

                if (_filteredMatches.isEmpty) {
                  return _buildEmptyState();
                }

                return Row(
                  children: [
                    _buildDesktopLeftPanel(),
                    Expanded(
                      child: _selectedMatch == null
                          ? _buildSelectionPrompt()
                          : _buildDesktopScoreEntryPanel(),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // Mobile App Bar
  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
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
            child: const Icon(Icons.scoreboard, color: Colors.deepOrange, size: 20),
          ),
          const SizedBox(width: 10),
          const Text(
            'Score Encoding',
            style: TextStyle(
              color: Color(0xFF2D3748),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        _buildMobileFilterChip(),
        if (_filterMode == 'date') _buildMobileDateSelector(),
        const SizedBox(width: 8),
      ],
    );
  }

  PreferredSizeWidget _buildMobileScoreEntryAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF2D3748)),
        onPressed: _backToMatchList,
      ),
      title: Text(
        _selectedMatch?['matchNumber'] != null 
            ? 'Match ${_selectedMatch?['matchNumber']}' 
            : 'Enter Scores',
        style: const TextStyle(
          color: Color(0xFF2D3748),
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildMobileFilterChip() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMobileChipButton('Date', 'date'),
          _buildMobileChipButton('All', 'all'),
        ],
      ),
    );
  }

  Widget _buildMobileChipButton(String label, String mode) {
    final isSelected = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        if (_filterMode != mode) {
          setState(() {
            _filterMode = mode;
            _filteredMatches = _filterMatchesByMode(_allMatches);
            _selectedMatch = null;
            _currentEditingMatchId = null;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade700,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDateSelector() {
    return GestureDetector(
      onTap: _selectDate,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: Colors.deepOrange.shade400),
            const SizedBox(width: 6),
            Text(
              _displayDateFormat.format(_selectedDate),
              style: const TextStyle(
                color: Color(0xFF2D3748),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Desktop App Bar
  PreferredSizeWidget _buildDesktopAppBar() {
    return AppBar(
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
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDesktopFilterChip('Date', 'date'),
              _buildDesktopFilterChip('All', 'all'),
            ],
          ),
        ),
        if (_filterMode == 'date') _buildDesktopDateSelector(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDesktopFilterChip(String label, String mode) {
    final isSelected = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        if (_filterMode != mode) {
          setState(() {
            _filterMode = mode;
            _filteredMatches = _filterMatchesByMode(_allMatches);
            _selectedMatch = null;
            _currentEditingMatchId = null;
          });
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

  Widget _buildDesktopDateSelector() {
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
              Icon(Icons.calendar_today, size: 18, color: Colors.deepOrange.shade400),
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

  // Mobile Match List
  Widget _buildMobileMatchList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tournaments')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error.toString());
        }

        final List<Map<String, dynamic>> allSchedules = [];
        
        for (var doc in snapshot.data!.docs) {
          final tournamentData = doc.data() as Map<String, dynamic>;
          final tournamentId = tournamentData['id'] ?? doc.id;
          final tournamentName = tournamentData['name'] ?? 'Unnamed Tournament';
          
          final matchups = tournamentData['matchups'] as List<dynamic>? ?? [];
          
          for (var matchup in matchups) {
            final match = Map<String, dynamic>.from(matchup as Map);
            
            match['tournamentSetupId'] = tournamentId;
            match['tournamentName'] = tournamentName;
            match['sport'] = tournamentData['sport'] ?? 'Unknown';
            match['category'] = tournamentData['category'] ?? 'Unknown';
            match['gender'] = tournamentData['gender'] ?? 'Unknown';
            match['venue'] = tournamentData['venue'] ?? 'Not specified';
            
            allSchedules.add(match);
          }
        }

        if (_allMatches.isEmpty || _allMatches.length != allSchedules.length) {
          _allMatches = allSchedules;
          _filteredMatches = _filterMatchesByMode(allSchedules);
        }

        if (_filteredMatches.isEmpty) {
          return _buildEmptyState();
        }

        return _buildMobileMatchListContent();
      },
    );
  }

  Widget _buildMobileMatchListContent() {
    final realMatches = _filteredMatches
        .where((match) => !_isPlaceholderMatch(match))
        .toList();
    final placeholderMatches = _filteredMatches
        .where((match) => _isPlaceholderMatch(match))
        .toList();

    Map<String, List<Map<String, dynamic>>> tournamentMatches = {};
    for (var match in realMatches) {
      final tournamentId = match['tournamentSetupId'] ?? 'Unknown';
      tournamentMatches.putIfAbsent(tournamentId, () => []).add(match);
    }

    return Column(
      children: [
        _buildMobileMatchStats(realMatches.length, placeholderMatches.length),
        Expanded(
          child: ListView.builder(
            controller: _leftPanelScrollController,
            padding: const EdgeInsets.all(12),
            itemCount: tournamentMatches.length + (placeholderMatches.isNotEmpty ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < tournamentMatches.length) {
                final entry = tournamentMatches.entries.elementAt(index);
                return _buildMobileTournamentSection(entry.key, entry.value);
              } else {
                return _buildMobileFutureMatchesSection(placeholderMatches);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileMatchStats(int activeCount, int futureCount) {
    String subtitle = _filterMode == 'all' 
        ? 'All Matches' 
        : 'Matches for ${_displayDateFormat.format(_selectedDate)}';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  fontSize: 16,
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
                    fontSize: 10,
                    color: Colors.deepOrange.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMobileStatCard(
                'Available',
                activeCount.toString(),
                Colors.deepOrange,
                Icons.play_circle_filled,
              ),
              const SizedBox(width: 8),
              _buildMobileStatCard(
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

  Widget _buildMobileStatCard(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileTournamentSection(String tournamentId, List<Map<String, dynamic>> matches) {
    final tournamentName = _tournamentNames[tournamentId] ?? 'Unknown Tournament';
    final tournamentInfo = _tournamentDetails[tournamentId] ?? {};
    final sport = tournamentInfo['sport'] ?? 'Unknown';
    final bracketType = tournamentInfo['bracketType'] ?? 'single';
    final bracketIcon = bracketType == 'double' ? Icons.sports_esports : Icons.emoji_events;
    final isCompleted = _isTournamentCompleted(tournamentId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: bracketType == 'double' ? Colors.purple : Colors.deepOrange,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Icon(bracketIcon, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournamentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
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
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (bracketType == 'double') ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Double Elim',
                                style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          if (isCompleted) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 7, color: Colors.green.shade700),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 7,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: bracketType == 'double'
                        ? Colors.purple.shade100
                        : Colors.deepOrange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${matches.length}',
                    style: TextStyle(
                      fontSize: 10,
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
          const SizedBox(height: 6),
          ...matches.map((match) => _buildMobileMatchListItem(match)).toList(),
        ],
      ),
    );
  }

  Widget _buildMobileMatchListItem(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    final isSelected = _selectedMatch?['id'] == matchId;
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
    final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();
    final matchTime = _formatMatchTime(match['dateTime'] ?? match['startTime']);
    final matchNumber = match['matchNumber'] ?? '#';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    
    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    final tournamentInfo = _tournamentDetails[tournamentId];
    final isDoubleElim = tournamentInfo?['bracketType'] == 'double';
    
    final tournamentMatches = _allMatches
        .where((m) => m['tournamentSetupId']?.toString() == tournamentId)
        .toList();
    final highestRound = _getHighestRound(tournamentMatches);
    
    final isFinalMatch = match['isGrandFinal'] == true || 
                         match['matchType']?.toString().toLowerCase() == 'grand_final' ||
                         match['matchType']?.toString().toLowerCase() == 'final' ||
                         match['bracket']?.toString().toLowerCase() == 'grand' ||
                         match['bracket']?.toString().toLowerCase() == 'final' ||
                         match['round'] == highestRound;

    final isChampionMatch = isFinalMatch && hasScores && match['winner'] != null && match['winner'] != 'tie';

    return InkWell(
      onTap: () {
        if (hasScores) {
          _showMobileMatchOptionsDialog(match);
        } else {
          _selectMatch(match);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isChampionMatch 
              ? Colors.amber.withOpacity(0.1)
              : (isFinalMatch 
                  ? Colors.amber.withOpacity(0.05)
                  : (isSelected ? Colors.deepOrange.withOpacity(0.05) : Colors.white)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isChampionMatch
                ? Colors.amber.shade500
                : (isFinalMatch
                    ? Colors.amber.shade300
                    : (isSelected
                        ? Colors.deepOrange
                        : (hasScores ? Colors.green.shade200 : Colors.grey.shade200))),
            width: isChampionMatch ? 3 : (isFinalMatch ? 2 : (isSelected ? 2 : 1)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 35,
              decoration: BoxDecoration(
                color: isChampionMatch
                    ? Colors.amber
                    : (isFinalMatch
                        ? Colors.amber
                        : (hasScores 
                            ? Colors.green 
                            : (isDoubleElim ? Colors.purple.shade300 : Colors.deepOrange.shade200))),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),

            _buildTeamLogo(team1Id, team1Name, size: 28),
            const SizedBox(width: 6),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isChampionMatch)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events, size: 8, color: Colors.amber.shade700),
                              const SizedBox(width: 2),
                              Text(
                                'CHAMPION',
                                style: TextStyle(
                                  fontSize: 7,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          isFinalMatch ? 'CHAMPIONSHIP' : 'Match $matchNumber',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isFinalMatch ? FontWeight.bold : FontWeight.w600,
                            color: isFinalMatch ? Colors.amber.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      const SizedBox(width: 4),
                      if (matchTime.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 8, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                matchTime,
                                style: TextStyle(fontSize: 8, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      if (hasScores && !isChampionMatch)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 8, color: Colors.green.shade600),
                              const SizedBox(width: 2),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  fontSize: 7,
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
                            fontSize: 11,
                            fontWeight: isChampionMatch && match['winner'] == team1Id ? FontWeight.bold : FontWeight.w500,
                            color: isChampionMatch && match['winner'] == team1Id ? Colors.amber.shade800 : null,
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
                            fontSize: 9,
                            color: isChampionMatch ? Colors.amber.shade600 : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          team2Name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isChampionMatch && match['winner'] == team2Id ? FontWeight.bold : FontWeight.w500,
                            color: isChampionMatch && match['winner'] == team2Id ? Colors.amber.shade800 : null,
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

            const SizedBox(width: 6),
            _buildTeamLogo(team2Id, team2Name, size: 28),
            
            if (isChampionMatch) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFutureMatchesSection(List<Map<String, dynamic>> placeholderMatches) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Icon(Icons.schedule, color: Colors.white, size: 12),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Pending Matches',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${placeholderMatches.length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ...placeholderMatches.map((match) => _buildMobileFutureMatchItem(match)).toList(),
        ],
      ),
    );
  }

  Widget _buildMobileFutureMatchItem(Map<String, dynamic> match) {
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
    final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();
    final matchNumber = match['matchNumber'] ?? '#';

    final isTeam1Ready = _isTeamReady(team1, match);
    final isTeam2Ready = _isTeamReady(team2, match);
    final isFullyResolved = isTeam1Ready && isTeam2Ready;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
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
            width: 3,
            height: 35,
            decoration: BoxDecoration(
              color: isFullyResolved ? Colors.green.shade400 : Colors.blue.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),

          _buildTeamLogo(isTeam1Ready ? team1Id : null, team1Name, size: 28, useGradient: !isTeam1Ready),
          const SizedBox(width: 6),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Match $matchNumber',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    if (isFullyResolved)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 8, color: Colors.green.shade600),
                            const SizedBox(width: 2),
                            Text(
                              'Ready',
                              style: TextStyle(
                                fontSize: 7,
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
                          fontSize: 11,
                          fontWeight: isTeam1Ready ? FontWeight.w500 : FontWeight.normal,
                          color: isTeam1Ready ? Colors.grey.shade800 : Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('vs', style: TextStyle(fontSize: 9, color: Colors.grey.shade400)),
                    ),
                    Expanded(
                      child: Text(
                        team2Name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isTeam2Ready ? FontWeight.w500 : FontWeight.normal,
                          color: isTeam2Ready ? Colors.grey.shade800 : Colors.grey.shade500,
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

          const SizedBox(width: 6),
          _buildTeamLogo(isTeam2Ready ? team2Id : null, team2Name, size: 28, useGradient: !isTeam2Ready),

          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: isFullyResolved ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isFullyResolved ? 'Ready' : 'Waiting',
              style: TextStyle(
                fontSize: 8,
                color: isFullyResolved ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Mobile Score Entry Panel
  Widget _buildMobileScoreEntryPanel() {
    if (_selectedMatch == null || _currentEditingMatchId == null) return const SizedBox();

    final match = _selectedMatch!;
    final matchId = _currentEditingMatchId!;
    final state = _matchScoreStates[matchId];
    
    if (state == null) return const SizedBox();

    final team1Obj = match['team1'] as Map<String, dynamic>?;
    final team2Obj = match['team2'] as Map<String, dynamic>?;
    
    String team1Id = '';
    String team2Id = '';
    String team1Name = '';
    String team2Name = '';

    if (team1Obj != null) {
      team1Id = team1Obj['id']?.toString() ?? '';
      team1Name = team1Obj['displayName']?.toString() ?? team1Obj['name']?.toString() ?? '';
    } else {
      team1Id = match['team1Id']?.toString() ?? '';
      team1Name = match['team1DisplayName']?.toString() ?? match['team1Name']?.toString() ?? '';
    }

    if (team2Obj != null) {
      team2Id = team2Obj['id']?.toString() ?? '';
      team2Name = team2Obj['displayName']?.toString() ?? team2Obj['name']?.toString() ?? '';
    } else {
      team2Id = match['team2Id']?.toString() ?? '';
      team2Name = match['team2DisplayName']?.toString() ?? match['team2Name']?.toString() ?? '';
    }

    final matchNumber = match['matchNumber'] ?? '#';
    final bracket = match['bracket'] ?? 'Match';
    final matchTime = _formatMatchTime(match['dateTime'] ?? match['startTime']);
    final isPlaceholder = _isPlaceholderMatch(match);
    
    final tournamentMatches = _allMatches
        .where((m) => m['tournamentSetupId']?.toString() == match['tournamentSetupId']?.toString())
        .toList();
    final highestRound = _getHighestRound(tournamentMatches);
    
    final isFinalMatch = match['isGrandFinal'] == true || 
                         match['matchType']?.toString().toLowerCase() == 'grand_final' ||
                         match['matchType']?.toString().toLowerCase() == 'final' ||
                         match['bracket']?.toString().toLowerCase() == 'grand' ||
                         match['bracket']?.toString().toLowerCase() == 'final' ||
                         match['round'] == highestRound;

    final hasScores = state.score1 > 0 || state.score2 > 0;
    final isChampionMatch = isFinalMatch && hasScores && state.selectedWinner != null && state.selectedWinner != 'tie';

    return SingleChildScrollView(
      controller: _rightPanelScrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.isEditMode)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Mode: You can modify the scores for this completed match',
                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.blue.shade700,
                    onPressed: () => _exitEditMode(matchId),
                  ),
                ],
              ),
            ),

          if (isPlaceholder && !hasScores)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This match is waiting for previous matches to complete before it can be played',
                      style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: isFinalMatch
                            ? LinearGradient(colors: [Colors.amber.shade400, Colors.amber.shade600])
                            : LinearGradient(colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isFinalMatch ? '🏆 CHAMPIONSHIP 🏆' : bracket.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Match $matchNumber',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                    ),
                  ],
                ),

                if (matchTime.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(matchTime, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Mobile score entry - stacked layout
                ListenableBuilder(
                  listenable: state,
                  builder: (context, _) {
                    return Column(
                      children: [
                        // Team 1
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch
                                  ? Colors.amber.shade400
                                  : Colors.grey.shade200,
                              width: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _buildTeamLogo(team1Id, team1Name, size: 50),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          team1Name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? FontWeight.bold : FontWeight.w600,
                                            color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch ? Colors.amber.shade800 : Color(0xFF2D3748),
                                          ),
                                          maxLines: 2,
                                        ),
                                        if (state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.emoji_events, size: 12, color: Colors.amber.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'CHAMPION',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber.shade700,
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
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: TextField(
                                  controller: state.score1Controller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(color: Colors.grey.shade400),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  enabled: !state.isSaving && (state.isEditMode || !hasScores) && !isPlaceholder,
                                  onChanged: (value) => _updateScore(matchId, 'team1', value),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // VS indicator
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isChampionMatch ? Colors.amber.shade700 : Color(0xFF4A5568),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Team 2
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch
                                  ? Colors.amber.shade400
                                  : Colors.grey.shade200,
                              width: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  _buildTeamLogo(team2Id, team2Name, size: 50),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          team2Name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) ? FontWeight.bold : FontWeight.w600,
                                            color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch ? Colors.amber.shade800 : Color(0xFF2D3748),
                                          ),
                                          maxLines: 2,
                                        ),
                                        if (state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.amber.shade100,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.emoji_events, size: 12, color: Colors.amber.shade700),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'CHAMPION',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.amber.shade700,
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
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: TextField(
                                  controller: state.score2Controller,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(color: Colors.grey.shade400),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  enabled: !state.isSaving && (state.isEditMode || !hasScores) && !isPlaceholder,
                                  onChanged: (value) => _updateScore(matchId, 'team2', value),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Winner selection - horizontal scroll for mobile
                ListenableBuilder(
                  listenable: state,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Select Winner',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                              ),
                              if (isChampionMatch) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.emoji_events, size: 12, color: Colors.amber.shade700),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Champion',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildMobileWinnerButton(
                                  label: team1Name,
                                  teamId: team1Id,
                                  isSelected: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name),
                                  color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch
                                      ? Colors.amber
                                      : Colors.deepOrange,
                                  showCrown: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch,
                                  onTap: (state.isEditMode || !hasScores) && !isPlaceholder
                                      ? () => _updateWinner(matchId, team1Id.isNotEmpty ? team1Id : team1Name)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                _buildMobileWinnerButton(
                                  label: team2Name,
                                  teamId: team2Id,
                                  isSelected: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name),
                                  color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch
                                      ? Colors.amber
                                      : Colors.blue,
                                  showCrown: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch,
                                  onTap: (state.isEditMode || !hasScores) && !isPlaceholder
                                      ? () => _updateWinner(matchId, team2Id.isNotEmpty ? team2Id : team2Name)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                _buildMobileWinnerButton(
                                  label: 'Tie',
                                  teamId: null,
                                  isSelected: state.selectedWinner == 'tie',
                                  color: Colors.purple,
                                  showCrown: false,
                                  onTap: (state.isEditMode || !hasScores) && !isPlaceholder
                                      ? () => _updateWinner(matchId, 'tie')
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: (state.isSaving || isPlaceholder || (!state.isEditMode && hasScores))
                            ? null
                            : () => _resetScores(matchId),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Reset', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (state.isSaving || isPlaceholder || (!state.isEditMode && hasScores))
                            ? null
                            : () => _saveScore(matchId, match),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPlaceholder
                              ? Colors.grey
                              : (state.isEditMode
                                  ? Colors.blue
                                  : (hasScores
                                      ? (isChampionMatch ? Colors.amber : Colors.green)
                                      : Colors.deepOrange)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: state.isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                isPlaceholder
                                    ? 'Cannot Score'
                                    : (state.isEditMode
                                        ? 'Update'
                                        : (hasScores
                                            ? (isChampionMatch ? '🏆' : 'Completed')
                                            : 'Save')),
                                style: const TextStyle(fontSize: 14),
                              ),
                      ),
                    ),
                  ],
                ),

                if (hasScores && !state.isEditMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isChampionMatch ? Colors.amber.shade50 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isChampionMatch ? Colors.amber.shade200 : Colors.green.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isChampionMatch ? Icons.emoji_events : Icons.check_circle,
                          color: isChampionMatch ? Colors.amber.shade600 : Colors.green.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isChampionMatch ? 'CHAMPION!' : 'Match completed',
                                style: TextStyle(
                                  color: isChampionMatch ? Colors.amber.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isChampionMatch
                                    ? 'Winner: ${state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? team1Name : team2Name}'
                                    : 'Winner: ${state.selectedWinner == 'tie' ? 'Tie' : (state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? team1Name : team2Name)}',
                                style: TextStyle(
                                  color: isChampionMatch ? Colors.amber.shade600 : Colors.green.shade600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isChampionMatch)
                          IconButton(
                            onPressed: () => _enterEditMode(match),
                            icon: const Icon(Icons.edit, size: 18),
                            color: Colors.blue,
                          ),
                      ],
                    ),
                  ),
                ],

                if (isPlaceholder && !hasScores)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info, color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This match will become available once previous matches are completed.',
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
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
    );
  }

  Widget _buildMobileWinnerButton({
    required String label,
    required String? teamId,
    required bool isSelected,
    required Color color,
    required bool showCrown,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) Icon(Icons.check_circle, color: color, size: 16),
            if (isSelected) const SizedBox(width: 6),
            if (showCrown && isSelected) ...[
              Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileMatchOptionsDialog(Map<String, dynamic> match) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Match Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'What would you like to do with this match?',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _selectMatch(match);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('View Scores'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _enterEditMode(match);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Edit Scores'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Desktop Left Panel
  Widget _buildDesktopLeftPanel() {
    final realMatches = _filteredMatches
        .where((match) => !_isPlaceholderMatch(match))
        .toList();
    final placeholderMatches = _filteredMatches
        .where((match) => _isPlaceholderMatch(match))
        .toList();

    Map<String, List<Map<String, dynamic>>> tournamentMatches = {};
    for (var match in realMatches) {
      final tournamentId = match['tournamentSetupId'] ?? 'Unknown';
      tournamentMatches.putIfAbsent(tournamentId, () => []).add(match);
    }

    return Container(
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
          _buildDesktopMatchStats(realMatches.length, placeholderMatches.length),
          Expanded(
            child: ListView.builder(
              controller: _leftPanelScrollController,
              padding: const EdgeInsets.all(16),
              itemCount: tournamentMatches.length + (placeholderMatches.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < tournamentMatches.length) {
                  final entry = tournamentMatches.entries.elementAt(index);
                  return _buildDesktopTournamentSection(entry.key, entry.value);
                } else {
                  return _buildDesktopFutureMatchesSection(placeholderMatches);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopMatchStats(int activeCount, int futureCount) {
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
              _buildDesktopStatCard(
                'Available Matches',
                activeCount.toString(),
                Colors.deepOrange,
                Icons.play_circle_filled,
              ),
              const SizedBox(width: 12),
              _buildDesktopStatCard(
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

  Widget _buildDesktopStatCard(String label, String value, Color color, IconData icon) {
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

  Widget _buildDesktopTournamentSection(String tournamentId, List<Map<String, dynamic>> matches) {
    final tournamentName = _tournamentNames[tournamentId] ?? 'Unknown Tournament';
    final tournamentInfo = _tournamentDetails[tournamentId] ?? {};
    final sport = tournamentInfo['sport'] ?? 'Unknown';
    final bracketType = tournamentInfo['bracketType'] ?? 'single';
    final bracketIcon = bracketType == 'double' ? Icons.sports_esports : Icons.emoji_events;
    final isCompleted = _isTournamentCompleted(tournamentId);

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
                    color: bracketType == 'double' ? Colors.purple : Colors.deepOrange,
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
                          if (isCompleted) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 8, color: Colors.green.shade700),
                                  const SizedBox(width: 2),
                                  Text(
                                    'Completed',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ...matches.map((match) => _buildDesktopMatchListItem(match)).toList(),
        ],
      ),
    );
  }

  Widget _buildDesktopMatchListItem(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    final isSelected = _selectedMatch?['id'] == matchId;
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
    final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();
    final matchTime = _formatMatchTime(match['dateTime'] ?? match['startTime']);
    final matchNumber = match['matchNumber'] ?? '#';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    
    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    final tournamentInfo = _tournamentDetails[tournamentId];
    final isDoubleElim = tournamentInfo?['bracketType'] == 'double';
    
    final tournamentMatches = _allMatches
        .where((m) => m['tournamentSetupId']?.toString() == tournamentId)
        .toList();
    final highestRound = _getHighestRound(tournamentMatches);
    
    final isFinalMatch = match['isGrandFinal'] == true || 
                         match['matchType']?.toString().toLowerCase() == 'grand_final' ||
                         match['matchType']?.toString().toLowerCase() == 'final' ||
                         match['bracket']?.toString().toLowerCase() == 'grand' ||
                         match['bracket']?.toString().toLowerCase() == 'final' ||
                         match['round'] == highestRound;

    final isChampionMatch = isFinalMatch && hasScores && match['winner'] != null && match['winner'] != 'tie';

    return InkWell(
      onTap: () {
        if (hasScores) {
          _showMatchOptionsDialog(match);
        } else {
          _selectMatch(match);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isChampionMatch 
              ? Colors.amber.withOpacity(0.1)
              : (isFinalMatch 
                  ? Colors.amber.withOpacity(0.05)
                  : (isSelected ? Colors.deepOrange.withOpacity(0.05) : Colors.white)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isChampionMatch
                ? Colors.amber.shade500
                : (isFinalMatch
                    ? Colors.amber.shade300
                    : (isSelected
                        ? Colors.deepOrange
                        : (hasScores ? Colors.green.shade200 : Colors.grey.shade200))),
            width: isChampionMatch ? 3 : (isFinalMatch ? 2 : (isSelected ? 2 : 1)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isChampionMatch
                    ? Colors.amber
                    : (isFinalMatch
                        ? Colors.amber
                        : (hasScores 
                            ? Colors.green 
                            : (isDoubleElim ? Colors.purple.shade300 : Colors.deepOrange.shade200))),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),

            _buildTeamLogo(team1Id, team1Name, size: 30),
            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isChampionMatch)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.emoji_events, size: 10, color: Colors.amber.shade700),
                              const SizedBox(width: 2),
                              Text(
                                'CHAMPION',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: Colors.amber.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          isFinalMatch ? 'CHAMPIONSHIP' : 'Match $matchNumber',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isFinalMatch ? FontWeight.bold : FontWeight.w600,
                            color: isFinalMatch ? Colors.amber.shade800 : Colors.grey.shade700,
                          ),
                        ),
                      const SizedBox(width: 6),
                      if (matchTime.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 10, color: Colors.grey.shade600),
                              const SizedBox(width: 2),
                              Text(
                                matchTime,
                                style: TextStyle(fontSize: 9, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      if (hasScores && !isChampionMatch)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 10, color: Colors.green.shade600),
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isChampionMatch && match['winner'] == team1Id ? FontWeight.bold : FontWeight.w500,
                            color: isChampionMatch && match['winner'] == team1Id ? Colors.amber.shade800 : null,
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
                            color: isChampionMatch ? Colors.amber.shade600 : Colors.grey.shade500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          team2Name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isChampionMatch && match['winner'] == team2Id ? FontWeight.bold : FontWeight.w500,
                            color: isChampionMatch && match['winner'] == team2Id ? Colors.amber.shade800 : null,
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

            const SizedBox(width: 8),
            _buildTeamLogo(team2Id, team2Name, size: 30),
            
            if (isChampionMatch) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 16),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopFutureMatchesSection(List<Map<String, dynamic>> placeholderMatches) {
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
                  child: const Icon(Icons.schedule, color: Colors.white, size: 14),
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
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          ...placeholderMatches.map((match) => _buildDesktopFutureMatchItem(match)).toList(),
        ],
      ),
    );
  }

  Widget _buildDesktopFutureMatchItem(Map<String, dynamic> match) {
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
    final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();
    final matchNumber = match['matchNumber'] ?? '#';

    final isTeam1Ready = _isTeamReady(team1, match);
    final isTeam2Ready = _isTeamReady(team2, match);
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
              color: isFullyResolved ? Colors.green.shade400 : Colors.blue.shade200,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

          _buildTeamLogo(isTeam1Ready ? team1Id : null, team1Name, size: 30, useGradient: !isTeam1Ready),
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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 10, color: Colors.green.shade600),
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
                          fontWeight: isTeam1Ready ? FontWeight.w500 : FontWeight.normal,
                          color: isTeam1Ready ? Colors.grey.shade800 : Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('vs', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ),
                    Expanded(
                      child: Text(
                        team2Name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isTeam2Ready ? FontWeight.w500 : FontWeight.normal,
                          color: isTeam2Ready ? Colors.grey.shade800 : Colors.grey.shade500,
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

          const SizedBox(width: 8),
          _buildTeamLogo(isTeam2Ready ? team2Id : null, team2Name, size: 30, useGradient: !isTeam2Ready),

          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isFullyResolved ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isFullyResolved ? 'Ready' : 'Waiting',
              style: TextStyle(
                fontSize: 9,
                color: isFullyResolved ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop Score Entry Panel
  Widget _buildDesktopScoreEntryPanel() {
    if (_selectedMatch == null || _currentEditingMatchId == null) return const SizedBox();

    final match = _selectedMatch!;
    final matchId = _currentEditingMatchId!;
    final state = _matchScoreStates[matchId];
    
    if (state == null) return const SizedBox();

    final team1Obj = match['team1'] as Map<String, dynamic>?;
    final team2Obj = match['team2'] as Map<String, dynamic>?;
    
    String team1Id = '';
    String team2Id = '';
    String team1Name = '';
    String team2Name = '';

    if (team1Obj != null) {
      team1Id = team1Obj['id']?.toString() ?? '';
      team1Name = team1Obj['displayName']?.toString() ?? team1Obj['name']?.toString() ?? '';
    } else {
      team1Id = match['team1Id']?.toString() ?? '';
      team1Name = match['team1DisplayName']?.toString() ?? match['team1Name']?.toString() ?? '';
    }

    if (team2Obj != null) {
      team2Id = team2Obj['id']?.toString() ?? '';
      team2Name = team2Obj['displayName']?.toString() ?? team2Obj['name']?.toString() ?? '';
    } else {
      team2Id = match['team2Id']?.toString() ?? '';
      team2Name = match['team2DisplayName']?.toString() ?? match['team2Name']?.toString() ?? '';
    }

    final matchNumber = match['matchNumber'] ?? '#';
    final bracket = match['bracket'] ?? 'Match';
    final matchTime = _formatMatchTime(match['dateTime'] ?? match['startTime']);
    final isPlaceholder = _isPlaceholderMatch(match);
    
    final tournamentMatches = _allMatches
        .where((m) => m['tournamentSetupId']?.toString() == match['tournamentSetupId']?.toString())
        .toList();
    final highestRound = _getHighestRound(tournamentMatches);
    
    final isFinalMatch = match['isGrandFinal'] == true || 
                         match['matchType']?.toString().toLowerCase() == 'grand_final' ||
                         match['matchType']?.toString().toLowerCase() == 'final' ||
                         match['bracket']?.toString().toLowerCase() == 'grand' ||
                         match['bracket']?.toString().toLowerCase() == 'final' ||
                         match['round'] == highestRound;

    final hasScores = state.score1 > 0 || state.score2 > 0;
    final isChampionMatch = isFinalMatch && hasScores && state.selectedWinner != null && state.selectedWinner != 'tie';

    return SingleChildScrollView(
      controller: _rightPanelScrollController,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isEditMode)
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
                          style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: Colors.blue.shade700,
                        onPressed: () => _exitEditMode(matchId),
                      ),
                    ],
                  ),
                ),

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
                          style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: isFinalMatch
                                ? LinearGradient(colors: [Colors.amber.shade400, Colors.amber.shade600])
                                : LinearGradient(colors: [Colors.deepOrange.shade400, Colors.deepOrange.shade600]),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            isFinalMatch ? '🏆 CHAMPIONSHIP 🏆' : bracket.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Match $matchNumber',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                        ),
                        const Spacer(),
                        if (matchTime.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.access_time, size: 18, color: Colors.grey.shade600),
                                const SizedBox(width: 8),
                                Text(matchTime, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    ListenableBuilder(
                      listenable: state,
                      builder: (context, _) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  _buildTeamLogo(team1Id, team1Name, size: 120),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name)
                                          ? Colors.amber.withOpacity(0.2)
                                          : Colors.deepOrange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch)
                                          Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 16),
                                        if (state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch)
                                          const SizedBox(width: 4),
                                        Text(
                                          team1Name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? FontWeight.bold : FontWeight.w600,
                                            color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? Colors.amber.shade800 : Color(0xFF2D3748),
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    width: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch
                                            ? Colors.amber.shade400
                                            : Colors.grey.shade300,
                                        width: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch ? 3 : 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: state.score1Controller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch
                                            ? Colors.amber.shade700
                                            : Color(0xFF2D3748),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(color: Colors.grey.shade400),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      enabled: !state.isSaving && (state.isEditMode || !hasScores) && !isPlaceholder,
                                      onChanged: (value) => _updateScore(matchId, 'team1', value),
                                    ),
                                  ),
                                ],
                              ),
                            ),

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
                                    child: Text(
                                      'VS',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: isChampionMatch ? Colors.amber.shade700 : Color(0xFF4A5568),
                                      ),
                                    ),
                                  ),
                                  if (isChampionMatch) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 24),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            Expanded(
                              child: Column(
                                children: [
                                  _buildTeamLogo(team2Id, team2Name, size: 120),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name)
                                          ? Colors.amber.withOpacity(0.2)
                                          : Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch)
                                          Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 16),
                                        if (state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch)
                                          const SizedBox(width: 4),
                                        Text(
                                          team2Name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) ? FontWeight.bold : FontWeight.w600,
                                            color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) ? Colors.amber.shade800 : Color(0xFF2D3748),
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    width: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch
                                            ? Colors.amber.shade400
                                            : Colors.grey.shade300,
                                        width: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch ? 3 : 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: state.score2Controller,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch
                                            ? Colors.amber.shade700
                                            : Color(0xFF2D3748),
                                      ),
                                      decoration: InputDecoration(
                                        hintText: '0',
                                        hintStyle: TextStyle(color: Colors.grey.shade400),
                                        border: InputBorder.none,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                      ),
                                      enabled: !state.isSaving && (state.isEditMode || !hasScores) && !isPlaceholder,
                                      onChanged: (value) => _updateScore(matchId, 'team2', value),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    ListenableBuilder(
                      listenable: state,
                      builder: (context, _) {
                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Select Winner',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                  ),
                                  if (isChampionMatch) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.emoji_events, size: 14, color: Colors.amber.shade700),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Champion',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDesktopWinnerButton(
                                      label: team1Name,
                                      teamId: team1Id,
                                      isSelected: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name),
                                      color: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch
                                          ? Colors.amber
                                          : Colors.deepOrange,
                                      showCrown: state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) && isChampionMatch,
                                      onTap: (state.isEditMode || !hasScores) && !isPlaceholder
                                          ? () => _updateWinner(matchId, team1Id.isNotEmpty ? team1Id : team1Name)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDesktopWinnerButton(
                                      label: team2Name,
                                      teamId: team2Id,
                                      isSelected: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name),
                                      color: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch
                                          ? Colors.amber
                                          : Colors.blue,
                                      showCrown: state.selectedWinner == (team2Id.isNotEmpty ? team2Id : team2Name) && isChampionMatch,
                                      onTap: (state.isEditMode || !hasScores) && !isPlaceholder
                                          ? () => _updateWinner(matchId, team2Id.isNotEmpty ? team2Id : team2Name)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDesktopWinnerButton(
                                      label: 'Tie',
                                      teamId: null,
                                      isSelected: state.selectedWinner == 'tie',
                                      color: Colors.purple,
                                      showCrown: false,
                                      onTap: (state.isEditMode || !hasScores) && !isPlaceholder
                                          ? () => _updateWinner(matchId, 'tie')
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (state.isSaving || isPlaceholder || (!state.isEditMode && hasScores))
                                ? null
                                : () => _resetScores(matchId),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Reset', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: (state.isSaving || isPlaceholder || (!state.isEditMode && hasScores))
                                ? null
                                : () => _saveScore(matchId, match),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isPlaceholder
                                  ? Colors.grey
                                  : (state.isEditMode
                                      ? Colors.blue
                                      : (hasScores
                                          ? (isChampionMatch ? Colors.amber : Colors.green)
                                          : Colors.deepOrange)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: state.isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isChampionMatch && !state.isEditMode && hasScores)
                                        Icon(Icons.emoji_events, size: 20, color: Colors.white),
                                      if (isChampionMatch && !state.isEditMode && hasScores)
                                        const SizedBox(width: 8),
                                      Text(
                                        isPlaceholder
                                            ? 'Cannot Score'
                                            : (state.isEditMode
                                                ? 'Update Score'
                                                : (hasScores
                                                    ? (isChampionMatch ? '🏆 CHAMPION 🏆' : 'Completed')
                                                    : 'Save Score')),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),

                    if (hasScores && !state.isEditMode) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isChampionMatch ? Colors.amber.shade50 : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isChampionMatch ? Colors.amber.shade200 : Colors.green.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isChampionMatch ? Icons.emoji_events : Icons.check_circle,
                              color: isChampionMatch ? Colors.amber.shade600 : Colors.green.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isChampionMatch ? '🎉 TOURNAMENT CHAMPION CROWNED! 🎉' : 'Match completed',
                                    style: TextStyle(
                                      color: isChampionMatch ? Colors.amber.shade700 : Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      if (state.selectedWinner != null && state.selectedWinner != 'tie')
                                        _buildTeamLogo(
                                          state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? team1Id : team2Id,
                                          state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? team1Name : team2Name,
                                          size: 24,
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isChampionMatch
                                              ? 'Winner: ${state.selectedWinner == 'tie' ? 'Tie' : (state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? team1Name : team2Name)} is the CHAMPION!'
                                              : 'Winner: ${state.selectedWinner == 'tie' ? 'Tie' : (state.selectedWinner == (team1Id.isNotEmpty ? team1Id : team1Name) ? team1Name : team2Name)}',
                                          style: TextStyle(
                                            color: isChampionMatch ? Colors.amber.shade600 : Colors.green.shade600,
                                            fontSize: 13,
                                            fontWeight: isChampionMatch ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (!isChampionMatch)
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
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 14),
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
    );
  }

  Widget _buildDesktopWinnerButton({
    required String label,
    required String? teamId,
    required bool isSelected,
    required Color color,
    required bool showCrown,
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
            if (showCrown && isSelected) ...[
              Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 16),
              const SizedBox(width: 4),
            ],
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

  void _showMatchOptionsDialog(Map<String, dynamic> match) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Match Options'),
          content: const Text('What would you like to do with this match?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _selectMatch(match);
              },
              child: const Text('View Scores'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _enterEditMode(match);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
              child: const Text('Edit Scores'),
            ),
          ],
        );
      },
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
            child: const Icon(Icons.touch_app, size: 64, color: Colors.deepOrange),
          ),
          const SizedBox(height: 24),
          const Text(
            'Select a match to encode scores',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF2D3748)),
          ),
          const SizedBox(height: 8),
          Text(
            _filterMode == 'all'
                ? 'Showing all matches from all tournaments'
                : 'Choose from the matches on the left panel',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading matches',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
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
            child: Icon(Icons.sports_score, size: 64, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            'No matches found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          if (_filterMode == 'date')
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                  _filteredMatches = _filterMatchesByMode(_allMatches);
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
                  _filteredMatches = _filterMatchesByMode(_allMatches);
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
          'champion': data['champion'],
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
        _currentEditingMatchId = null;
        _filteredMatches = _filterMatchesByMode(_allMatches);
      });
    }
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
}

class MatchScoreState extends ChangeNotifier {
  final String matchId;
  final TextEditingController score1Controller;
  final TextEditingController score2Controller;
  String? selectedWinner;
  bool isEditMode;
  bool isSaving;
  int _score1;
  int _score2;

  int get score1 => _score1;
  int get score2 => _score2;

  MatchScoreState({
    required this.matchId,
    required int initialScore1,
    required int initialScore2,
    String? initialWinner,
    this.isEditMode = false,
    this.isSaving = false,
  }) : _score1 = initialScore1,
       _score2 = initialScore2,
       score1Controller = TextEditingController(text: initialScore1.toString()),
       score2Controller = TextEditingController(text: initialScore2.toString()),
       selectedWinner = initialWinner {
    score1Controller.addListener(_onScore1Changed);
    score2Controller.addListener(_onScore2Changed);
  }

  factory MatchScoreState.fromMatch(Map<String, dynamic> match) {
    final team1Obj = match['team1'] as Map<String, dynamic>?;
    final team2Obj = match['team2'] as Map<String, dynamic>?;
    
    String team1Id = '';
    String team2Id = '';
    String team1Name = '';
    String team2Name = '';

    if (team1Obj != null) {
      team1Id = team1Obj['id']?.toString() ?? '';
      team1Name = team1Obj['displayName']?.toString() ?? team1Obj['name']?.toString() ?? '';
    } else {
      team1Id = match['team1Id']?.toString() ?? '';
      team1Name = match['team1DisplayName']?.toString() ?? match['team1Name']?.toString() ?? '';
    }

    if (team2Obj != null) {
      team2Id = team2Obj['id']?.toString() ?? '';
      team2Name = team2Obj['displayName']?.toString() ?? team2Obj['name']?.toString() ?? '';
    } else {
      team2Id = match['team2Id']?.toString() ?? '';
      team2Name = match['team2DisplayName']?.toString() ?? match['team2Name']?.toString() ?? '';
    }

    final existingScores = match['scores'] as Map<String, dynamic>? ?? {};
    
    int score1 = 0;
    int score2 = 0;
    
    if (existingScores.isNotEmpty) {
      if (team1Id.isNotEmpty && existingScores.containsKey(team1Id)) {
        score1 = existingScores[team1Id] as int? ?? 0;
      } else if (existingScores.containsKey(team1Name)) {
        score1 = existingScores[team1Name] as int? ?? 0;
      }
      
      if (team2Id.isNotEmpty && existingScores.containsKey(team2Id)) {
        score2 = existingScores[team2Id] as int? ?? 0;
      } else if (existingScores.containsKey(team2Name)) {
        score2 = existingScores[team2Name] as int? ?? 0;
      }
    }
    
    if (score1 == 0 && match.containsKey('team1Score')) {
      score1 = match['team1Score'] as int? ?? 0;
    }
    if (score2 == 0 && match.containsKey('team2Score')) {
      score2 = match['team2Score'] as int? ?? 0;
    }

    String? winner;
    if (match.containsKey('winner') && match['winner'] != null) {
      winner = match['winner'].toString();
    }

    return MatchScoreState(
      matchId: match['id'] ?? '',
      initialScore1: score1,
      initialScore2: score2,
      initialWinner: winner,
    );
  }

  void _onScore1Changed() {
    final newScore = int.tryParse(score1Controller.text) ?? 0;
    if (_score1 != newScore) {
      _score1 = newScore;
      notifyListeners();
    }
  }

  void _onScore2Changed() {
    final newScore = int.tryParse(score2Controller.text) ?? 0;
    if (_score2 != newScore) {
      _score2 = newScore;
      notifyListeners();
    }
  }

  void updateScore(String team, String value) {
    if (team == 'team1') {
      score1Controller.text = value;
      score1Controller.selection = TextSelection.fromPosition(
        TextPosition(offset: score1Controller.text.length),
      );
    } else {
      score2Controller.text = value;
      score2Controller.selection = TextSelection.fromPosition(
        TextPosition(offset: score2Controller.text.length),
      );
    }
  }

  void updateWinner(String winner) {
    selectedWinner = winner;
    notifyListeners();
  }

  void setEditMode(bool editMode) {
    isEditMode = editMode;
    notifyListeners();
  }

  void setSaving(bool saving) {
    isSaving = saving;
    notifyListeners();
  }

  void updateFromMatch(Map<String, dynamic> match) {
    final newScore1 = match['team1Score'] as int? ?? 0;
    final newScore2 = match['team2Score'] as int? ?? 0;
    
    if (_score1 != newScore1) {
      _score1 = newScore1;
      score1Controller.text = newScore1.toString();
    }
    if (_score2 != newScore2) {
      _score2 = newScore2;
      score2Controller.text = newScore2.toString();
    }
    
    if (match.containsKey('winner') && match['winner'] != null) {
      selectedWinner = match['winner'].toString();
    }
    
    notifyListeners();
  }

  void reset() {
    _score1 = 0;
    _score2 = 0;
    score1Controller.text = '0';
    score2Controller.text = '0';
    selectedWinner = null;
    notifyListeners();
  }

  @override
  void dispose() {
    score1Controller.removeListener(_onScore1Changed);
    score2Controller.removeListener(_onScore2Changed);
    score1Controller.dispose();
    score2Controller.dispose();
    super.dispose();
  }
}