import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/modern_calendar.dart';
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
  
  // Animation controller for smooth transitions
  late AnimationController _animationController;
  
  // Separate scroll controllers for left and right panels
  final ScrollController _leftPanelScrollController = ScrollController();
  final ScrollController _rightPanelScrollController = ScrollController();

  DateTime _selectedDate = DateTime.now();
  String? _currentUserId;
  Map<String, String> _tournamentNames = {};
  Map<String, Map<String, dynamic>> _tournamentDetails = {};
  bool _isLoading = true;
  bool _isSaving = false;
  String? _savingMatchId;

  // Filter mode - 'date' or 'all'
  String _filterMode = 'date';

  // Edit mode flag
  bool _isEditMode = false;

  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _filteredMatches = [];

  // For better organization
  String? _selectedTournamentId;
  Map<String, dynamic>? _selectedMatch;

  // Score input controllers
  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, String?> _selectedWinners = {};

  // Track tournament champions
  final Map<String, Map<String, dynamic>> _tournamentChampions = {};

  // For manual champion selection
  bool _isSelectingChampion = false;
  String? _championSelectionTournamentId;

  // Track scroll position
  double _savedScrollPosition = 0;

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
    
    // Add listener to save scroll position
    _leftPanelScrollController.addListener(() {
      _savedScrollPosition = _leftPanelScrollController.position.pixels;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _leftPanelScrollController.dispose();
    _rightPanelScrollController.dispose();
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
    }
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

  // ============== IMPROVED MATCH SELECTION ==============
  
  void _selectMatch(Map<String, dynamic> match) {
    // Store current scroll position
    _savedScrollPosition = _leftPanelScrollController.position.pixels;
    
    setState(() {
      _selectedMatch = match;
      _isEditMode = false;
    });
    
    // Initialize controllers with existing scores if any
    _initializeScoreControllers(match);
    
    // Restore scroll position after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leftPanelScrollController.hasClients) {
        _leftPanelScrollController.jumpTo(_savedScrollPosition);
      }
    });
  }

  void _initializeScoreControllers(Map<String, dynamic> match) {
    final matchId = match['id'] ?? '';
    
    // Get team data with proper casting
    final team1Obj = match['team1'] as Map<String, dynamic>?;
    final team2Obj = match['team2'] as Map<String, dynamic>?;
    
    // Extract team information
    String team1Id = '';
    String team2Id = '';
    String team1Name = '';
    String team2Name = '';

    // Process Team 1
    if (team1Obj != null) {
      team1Id = team1Obj['id']?.toString() ?? '';
      team1Name = team1Obj['displayName']?.toString() ?? team1Obj['name']?.toString() ?? '';
    } else {
      team1Id = match['team1Id']?.toString() ?? '';
      team1Name = match['team1DisplayName']?.toString() ?? match['team1Name']?.toString() ?? '';
    }

    // Process Team 2
    if (team2Obj != null) {
      team2Id = team2Obj['id']?.toString() ?? '';
      team2Name = team2Obj['displayName']?.toString() ?? team2Obj['name']?.toString() ?? '';
    } else {
      team2Id = match['team2Id']?.toString() ?? '';
      team2Name = match['team2DisplayName']?.toString() ?? match['team2Name']?.toString() ?? '';
    }

    final existingScores = match['scores'] as Map<String, dynamic>? ?? {};
    
    // Try to get scores from various possible locations
    int score1 = 0;
    int score2 = 0;
    
    // Check scores map first using IDs
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
    
    // Fallback to direct score fields
    if (score1 == 0 && match.containsKey('team1Score')) {
      score1 = match['team1Score'] as int? ?? 0;
    }
    if (score2 == 0 && match.containsKey('team2Score')) {
      score2 = match['team2Score'] as int? ?? 0;
    }

    // Create or update controllers
    if (!_scoreControllers.containsKey('${matchId}_1')) {
      _scoreControllers['${matchId}_1'] = TextEditingController(text: score1.toString());
    } else {
      _scoreControllers['${matchId}_1']?.text = score1.toString();
    }

    if (!_scoreControllers.containsKey('${matchId}_2')) {
      _scoreControllers['${matchId}_2'] = TextEditingController(text: score2.toString());
    } else {
      _scoreControllers['${matchId}_2']?.text = score2.toString();
    }

    // Set winner if exists
    if (match.containsKey('winner') && match['winner'] != null) {
      _selectedWinners[matchId] = match['winner'].toString();
    }
  }

  // ============== MANUAL CHAMPION SELECTION METHODS ==============

  void _showManualChampionSelection(String tournamentId) {
    final tournamentMatches = _allMatches
        .where((match) => match['tournamentSetupId']?.toString() == tournamentId)
        .toList();

    final Map<String, String> teamMap = {}; // id -> name

    for (var match in tournamentMatches) {
      _extractTeamsFromMatch(match, teamMap);
    }

    if (teamMap.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid teams found in this tournament'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select Tournament Champion',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _tournamentNames[tournamentId] ?? 'Unknown Tournament',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Choose a team to crown as champion:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: teamMap.length,
                      itemBuilder: (context, index) {
                        final entry = teamMap.entries.elementAt(index);
                        final teamId = entry.key;
                        final teamName = entry.value;
                        final isCurrentChampion = _tournamentChampions[tournamentId]?['id'] == teamId;

                        return InkWell(
                          onTap: () {
                            _setManualChampion(tournamentId, teamId, teamName);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isCurrentChampion
                                  ? LinearGradient(
                                      colors: [
                                        Colors.amber.shade400,
                                        Colors.amber.shade600,
                                      ],
                                    )
                                  : null,
                              color: isCurrentChampion ? null : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentChampion
                                    ? Colors.amber.shade400
                                    : Colors.grey.shade300,
                                width: isCurrentChampion ? 2 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildTeamLogo(teamId, teamName, size: 60),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    teamName,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isCurrentChampion ? FontWeight.bold : FontWeight.normal,
                                      color: isCurrentChampion ? Colors.white : Colors.grey.shade800,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (isCurrentChampion) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.emoji_events, size: 14, color: Colors.white),
                                      const SizedBox(width: 2),
                                      const Text(
                                        'Champion',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _extractTeamsFromMatch(Map<String, dynamic> match, Map<String, String> teamMap) {
    final team1 = match['team1'] as Map<String, dynamic>?;
    final team2 = match['team2'] as Map<String, dynamic>?;
    
    if (team1 != null) {
      _addTeamToMap(team1, teamMap);
    }
    
    if (team2 != null) {
      _addTeamToMap(team2, teamMap);
    }
    
    if (match.containsKey('team1Id') && match.containsKey('team1Name')) {
      final teamId = match['team1Id']?.toString();
      final teamName = match['team1Name']?.toString() ?? match['team1DisplayName']?.toString();
      if (teamId != null && teamName != null && 
          !teamId.contains('match_') && !teamId.contains('winner') && !teamId.contains('loser')) {
        teamMap[teamId] = teamName;
      }
    }
    
    if (match.containsKey('team2Id') && match.containsKey('team2Name')) {
      final teamId = match['team2Id']?.toString();
      final teamName = match['team2Name']?.toString() ?? match['team2DisplayName']?.toString();
      if (teamId != null && teamName != null && 
          !teamId.contains('match_') && !teamId.contains('winner') && !teamId.contains('loser')) {
        teamMap[teamId] = teamName;
      }
    }
  }

  void _addTeamToMap(Map<String, dynamic> team, Map<String, String> teamMap) {
    final teamId = team['id']?.toString();
    final teamName = team['displayName']?.toString() ?? team['name']?.toString();
    
    if (teamId != null && teamName != null && 
        !teamId.contains('match_') && !teamId.contains('winner') && !teamId.contains('loser') &&
        !teamName.contains('Winner') && !teamName.contains('Loser')) {
      teamMap[teamId] = teamName;
    }
  }

  Future<void> _setManualChampion(String tournamentId, String teamId, String teamName) async {
    String actualTeamName = teamName;
    
    if (actualTeamName.contains('Winner') || actualTeamName.contains('Loser') || 
        actualTeamName.contains('Match') || actualTeamName.contains('match_')) {
      String? realName = _getTeamNameFromId(teamId);
      if (realName != null && !realName.contains('Winner') && !realName.contains('Loser')) {
        actualTeamName = realName;
      }
    }
    
    
    if (mounted) {
      setState(() {
        _tournamentChampions[tournamentId] = {
          'id': teamId,
          'name': actualTeamName,
          'displayName': actualTeamName,
          'isManual': true,
          'selectedAt': DateTime.now().toIso8601String(),
          'selectedBy': _currentUserId,
        };
      });
    }

    try {
      final tournamentInfo = _tournamentDetails[tournamentId];
      if (tournamentInfo != null) {
        final tournamentDocId = tournamentInfo['docId'];
        await FirebaseFirestore.instance
            .collection('tournaments')
            .doc(tournamentDocId)
            .update({
          'champion': {
            'id': teamId,
            'name': actualTeamName,
            'displayName': actualTeamName,
            'selectedAt': DateTime.now().toIso8601String(),
            'selectedBy': _currentUserId,
            'isManual': true,
          }
        });
      }
    } catch (e) {
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🏆 $actualTeamName crowned as tournament champion!'),
          backgroundColor: Colors.amber,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  // ============== HELPER METHODS ==============

  bool _isPlaceholderMatch(Map<String, dynamic> match) {
    final status = match['status'] as String? ?? 'scheduled';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    
    if (status == 'completed' || hasScores) {
      return false;
    }

    final team1 = match['team1'] as Map<String, dynamic>?;
    final team2 = match['team2'] as Map<String, dynamic>?;
    
    if (team1 == null || team2 == null) return true;

    final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString() ?? '';
    final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString() ?? '';

    bool isTeam1Real = _isRealParticipant(team1Id, team1);
    bool isTeam2Real = _isRealParticipant(team2Id, team2);

    if (isTeam1Real && isTeam2Real) {
      return false;
    }

    bool team1Ready = _isTeamReady(team1, match);
    bool team2Ready = _isTeamReady(team2, match);

    return !(team1Ready && team2Ready);
  }

  Map<String, dynamic>? _getTeamFromMatch(Map<String, dynamic> match, String teamKey) {
    if (match[teamKey] is Map<String, dynamic>) {
      return match[teamKey] as Map<String, dynamic>;
    }
    
    final idKey = '${teamKey}Id';
    final nameKey = '${teamKey}Name';
    final displayNameKey = '${teamKey}DisplayName';
    
    if (match.containsKey(idKey)) {
      return {
        'id': match[idKey]?.toString(),
        'name': match[nameKey]?.toString() ?? match[displayNameKey]?.toString() ?? 'Unknown',
        'displayName': match[displayNameKey]?.toString() ?? match[nameKey]?.toString() ?? 'Unknown',
      };
    }
    
    return null;
  }

  bool _isRealParticipant(String teamId, Map<String, dynamic>? team) {
    if (teamId.isEmpty) return false;
    
    if (teamId.contains('winner') || 
        teamId.contains('loser') || 
        teamId.contains('placeholder') ||
        teamId.contains('match_')) {
      return false;
    }
    
    if (team != null) {
      final teamType = team['type']?.toString() ?? '';
      if (teamType == 'placeholder' || team['isPlaceholder'] == true) {
        return false;
      }
      
      final teamName = team['name']?.toString() ?? '';
      final teamDisplayName = team['displayName']?.toString() ?? '';
      
      if (teamName.contains('Winner') || teamName.contains('Loser') || 
          teamName.contains('TBD') || teamName.contains('Match')) {
        return false;
      }
      
      if (teamDisplayName.contains('Winner') || teamDisplayName.contains('Loser') || 
          teamDisplayName.contains('TBD') || teamDisplayName.contains('Match')) {
        return false;
      }
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
    
    // Search through all matches for this team ID
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
      
      if (match['team1Id']?.toString() == teamId) {
        String? name = match['team1DisplayName']?.toString() ?? match['team1Name']?.toString();
        if (name != null && !name.contains('Winner') && !name.contains('Loser')) {
          return name;
        }
      }
      
      if (match['team2Id']?.toString() == teamId) {
        String? name = match['team2DisplayName']?.toString() ?? match['team2Name']?.toString();
        if (name != null && !name.contains('Winner') && !name.contains('Loser')) {
          return name;
        }
      }
    }
    
    return null;
  }

  String? _getRealTeamIdFromPlaceholder(String placeholder, Map<String, dynamic> match) {
    int? sourceMatchNumber = _extractSourceMatchNumber(placeholder, '');
    if (sourceMatchNumber == null) return null;
    
    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    
    final sourceMatch = _allMatches.firstWhere(
      (m) => m['tournamentSetupId']?.toString() == tournamentId && 
             m['matchNumber'] == sourceMatchNumber,
      orElse: () => <String, dynamic>{},
    );
    
    if (sourceMatch.isEmpty) return null;
    
    final sourceWinner = sourceMatch['winner'] as String?;
    if (sourceWinner == null || sourceWinner.isEmpty) return null;
    
    if (!sourceWinner.contains('match_') && !sourceWinner.contains('winner') && !sourceWinner.contains('loser')) {
      return sourceWinner;
    }
    
    return _getRealTeamIdFromPlaceholder(sourceWinner, sourceMatch);
  }

  String? _getTeamId(Map<String, dynamic>? team) {
    if (team == null) return null;
    return team['id']?.toString();
  }

  bool _isUserAssignedToTournament(String tournamentId) {
    final tournamentInfo = _tournamentDetails[tournamentId];
    if (tournamentInfo == null) return false;
    final assignedUsers = tournamentInfo['assignedUsers'] as List<String>? ?? [];
    if (assignedUsers.isEmpty) return true;
    return _currentUserId != null && assignedUsers.contains(_currentUserId);
  }

  // ============== TOURNAMENT COMPLETION AND CHAMPION METHODS ==============

  bool _isTournamentCompleted(String tournamentId) {
    final tournamentMatches = _allMatches
        .where((match) => match['tournamentSetupId']?.toString() == tournamentId)
        .toList();
    
    if (tournamentMatches.isEmpty) return false;
    
    for (var match in tournamentMatches) {
      final status = match['status'] as String? ?? 'scheduled';
      final hasScores = match['scores'] != null ||
          (match['team1Score'] != null && match['team2Score'] != null);
      
      if (status != 'completed' && !hasScores) {
        return false;
      }
    }
    
    return true;
  }

  int _getHighestRound(List<Map<String, dynamic>> matches) {
    int highestRound = 0;
    for (var match in matches) {
      final round = match['round'] as int? ?? 0;
      if (round > highestRound) {
        highestRound = round;
      }
    }
    return highestRound;
  }

  Map<String, dynamic>? _getFinalMatch(String tournamentId) {
    final tournamentMatches = _allMatches
        .where((match) => match['tournamentSetupId']?.toString() == tournamentId)
        .toList();
    
    if (tournamentMatches.isEmpty) return null;
    
    final tournamentInfo = _tournamentDetails[tournamentId];
    final bracketType = tournamentInfo?['bracketType'] ?? 'single';
    
    if (bracketType == 'double') {
      final grandFinal = tournamentMatches.firstWhere(
        (match) => 
            match['isGrandFinal'] == true || 
            match['matchType']?.toString().toLowerCase() == 'grand_final' ||
            match['bracket']?.toString().toLowerCase() == 'grand' ||
            match['matchNumber'] == 0 ||
            (match['round'] == _getHighestRound(tournamentMatches) && 
             match['matchType']!.toString().toLowerCase().contains('grand')),
        orElse: () => <String, dynamic>{},
      );
      
      if (grandFinal.isNotEmpty) return grandFinal;
    }
    
    final highestRound = _getHighestRound(tournamentMatches);
    final finalMatch = tournamentMatches.firstWhere(
      (m) => m['round'] == highestRound,
      orElse: () => <String, dynamic>{},
    );
    
    return finalMatch.isNotEmpty ? finalMatch : null;
  }

  Map<String, dynamic>? _extractChampionFromMatch(Map<String, dynamic> match) {
    final status = match['status'] as String? ?? 'scheduled';
    final hasScores = match['scores'] != null ||
        (match['team1Score'] != null && match['team2Score'] != null);
    
    if (status != 'completed' && !hasScores) return null;
    
    final winner = match['winner'] as String?;
    if (winner == null || winner == 'tie') return null;
    
    String? championName;
    String? championId;
    
    final team1 = match['team1'] as Map<String, dynamic>?;
    final team2 = match['team2'] as Map<String, dynamic>?;
    
    String? team1Id = team1?['id']?.toString() ?? match['team1Id']?.toString();
    String? team2Id = team2?['id']?.toString() ?? match['team2Id']?.toString();
    
    String team1ActualName = _getTeamDisplayName(team1, match, _allMatches);
    String team2ActualName = _getTeamDisplayName(team2, match, _allMatches);
    
    
    if (team1Id != null && (winner == team1Id || winner == team1ActualName)) {
      championId = team1Id;
      championName = team1ActualName;
    }
    else if (team2Id != null && (winner == team2Id || winner == team2ActualName)) {
      championId = team2Id;
      championName = team2ActualName;
    }
    else {
      final matchTeam1Id = match['team1Id']?.toString();
      final matchTeam2Id = match['team2Id']?.toString();
      final matchTeam1Name = match['team1Name']?.toString() ?? match['team1DisplayName']?.toString() ?? '';
      final matchTeam2Name = match['team2Name']?.toString() ?? match['team2DisplayName']?.toString() ?? '';
      
      if (matchTeam1Id != null && (winner == matchTeam1Id || winner == matchTeam1Name)) {
        championId = matchTeam1Id;
        championName = matchTeam1Name;
      } else if (matchTeam2Id != null && (winner == matchTeam2Id || winner == matchTeam2Name)) {
        championId = matchTeam2Id;
        championName = matchTeam2Name;
      }
    }
    
    if (championId == null && (winner.contains('match_') || winner.contains('winner') || winner.contains('loser'))) {
      String? resolvedId = _getRealTeamIdFromPlaceholder(winner, match);
      if (resolvedId != null) {
        championId = resolvedId;
        championName = _getTeamNameFromId(resolvedId) ?? 'Unknown Team';
      }
    }
    
    if (championName == null || championName.isEmpty || championName.contains('Winner') || championName.contains('Loser')) {
      String? nameFromId = _getTeamNameFromId(winner);
      if (nameFromId != null && !nameFromId.contains('Winner') && !nameFromId.contains('Loser')) {
        championName = nameFromId;
        championId = winner;
      } else {
        championName = winner;
      }
    }
    
    if (championName.contains('match_') || championName.contains('Winner') || championName.contains('Loser')) {
      if (championId != null && championId.isNotEmpty) {
        String? betterName = _getTeamNameFromId(championId);
        if (betterName != null && !betterName.contains('Winner') && !betterName.contains('Loser')) {
          championName = betterName;
        }
      }
    }
    
    if (championName == null || championName.isEmpty || championName == 'tie') {
      return null;
    }
    
    final Map<String, dynamic> champion = {
      'id': championId,
      'name': championName,
      'displayName': championName,
      'match': match,
      'matchNumber': match['matchNumber'],
      'isAutomatic': true,
    };
    
    return champion;
  }

  Map<String, dynamic>? _getTournamentChampion(String tournamentId) {
    if (_tournamentChampions.containsKey(tournamentId)) {
      return _tournamentChampions[tournamentId];
    }
    
    final finalMatch = _getFinalMatch(tournamentId);
    if (finalMatch == null) return null;
    
    final champion = _extractChampionFromMatch(finalMatch);
    if (champion != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _tournamentChampions[tournamentId] = champion;
          });
        }
      });
    }
    
    return champion;
  }

  // ============== FIXED SAVE SCORE METHOD - UPDATES TOURNAMENT DOCUMENT ONLY ==============

  Future<void> _saveScore(String matchId, Map<String, dynamic> match) async {
    if (_isSaving) return;

    if (_isPlaceholderMatch(match)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save scores for placeholder matches - waiting for previous matches to complete'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};

    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    
    String? team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
    String? team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();


    final score1Text = _scoreControllers['${matchId}_1']?.text ?? '';
    final score2Text = _scoreControllers['${matchId}_2']?.text ?? '';

    if (score1Text.isEmpty && score2Text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one score'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final score1 = int.tryParse(score1Text) ?? 0;
    final score2 = int.tryParse(score2Text) ?? 0;

    String? winner;
    if (_selectedWinners[matchId] != null && _selectedWinners[matchId] != 'tie') {
      winner = _selectedWinners[matchId];
    } else if (_selectedWinners[matchId] == 'tie') {
      winner = 'tie';
    } else if (score1 > score2) {
      winner = team1Id ?? team1Name;
    } else if (score2 > score1) {
      winner = team2Id ?? team2Name;
    }

    // Resolve winner to actual team ID if possible
    if (winner != null && winner != 'tie') {
      if (team1Id != null && winner == team1Id) {
      } else if (team2Id != null && winner == team2Id) {
      }
      else if (winner == team1Name && team1Id != null) {
        winner = team1Id;
      } else if (winner == team2Name && team2Id != null) {
        winner = team2Id;
      }
      else if (winner.contains('match_') || winner.contains('winner') || winner.contains('loser')) {
        String? resolvedWinner = _getRealTeamIdFromPlaceholder(winner, match);
        if (resolvedWinner != null) {
          winner = resolvedWinner;
        }
      }
    }

    // Save current scroll position before setState
    double currentScroll = _leftPanelScrollController.hasClients 
        ? _leftPanelScrollController.position.pixels 
        : _savedScrollPosition;

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
      final matchups = List<Map<String, dynamic>>.from(tournamentData['matchups'] ?? []);

      final matchIndex = matchups.indexWhere((m) => m['id'] == matchId);
      if (matchIndex == -1) throw Exception('Match not found');

      // Create scores map with actual team IDs
      final Map<String, dynamic> scoresMap = {};
      if (team1Id != null && !team1Id.contains('match_') && !team1Id.contains('winner') && !team1Id.contains('loser')) {
        scoresMap[team1Id] = score1;
      } else {
        scoresMap[team1Name] = score1;
      }
      
      if (team2Id != null && !team2Id.contains('match_') && !team2Id.contains('winner') && !team2Id.contains('loser')) {
        scoresMap[team2Id] = score2;
      } else {
        scoresMap[team2Name] = score2;
      }

      // Create updated match with proper typing - ONLY update essential fields
      final Map<String, dynamic> updatedMatch = Map<String, dynamic>.from(matchups[matchIndex]);
      
      // Update ONLY the essential fields
      updatedMatch['scores'] = scoresMap;
      updatedMatch['winner'] = winner;
      updatedMatch['status'] = 'completed';
      updatedMatch['team1Score'] = score1;
      updatedMatch['team2Score'] = score2;
      updatedMatch['team1Id'] = team1Id ?? matchups[matchIndex]['team1Id'];
      updatedMatch['team2Id'] = team2Id ?? matchups[matchIndex]['team2Id'];
      updatedMatch['team1Name'] = team1Name;
      updatedMatch['team2Name'] = team2Name;
      
      // Only update timestamp fields if they exist in the original document
      if (matchups[matchIndex].containsKey('completedAt')) {
        updatedMatch['completedAt'] = matchups[matchIndex]['completedAt'] ?? DateTime.now().toIso8601String();
      }
      
      // Remove any edit history if it exists (to prevent accumulation)
      if (updatedMatch.containsKey('editHistory')) {
        updatedMatch.remove('editHistory');
      }
      
      // Remove any previous scores fields
      if (updatedMatch.containsKey('previousScores')) {
        updatedMatch.remove('previousScores');
      }
      if (updatedMatch.containsKey('previousWinner')) {
        updatedMatch.remove('previousWinner');
      }
      if (updatedMatch.containsKey('previousTeam1Score')) {
        updatedMatch.remove('previousTeam1Score');
      }
      if (updatedMatch.containsKey('previousTeam2Score')) {
        updatedMatch.remove('previousTeam2Score');
      }

      matchups[matchIndex] = updatedMatch;

      // Update the tournament document with the clean matchups array
      await tournamentRef.update({'matchups': matchups});

      // Update local match data
      final Map<String, dynamic> updatedMatchData = Map<String, dynamic>.from(updatedMatch);
      
      // Update in _allMatches list
      final allMatchesIndex = _allMatches.indexWhere((m) => m['id'] == matchId);
      if (allMatchesIndex != -1) {
        _allMatches[allMatchesIndex] = {
          ..._allMatches[allMatchesIndex],
          ...updatedMatchData,
        };
      }

      // Update filtered matches
      final filteredIndex = _filteredMatches.indexWhere((m) => m['id'] == matchId);
      if (filteredIndex != -1) {
        _filteredMatches[filteredIndex] = {
          ..._filteredMatches[filteredIndex],
          ...updatedMatchData,
        };
      }

      // Check if this is the final match and extract champion
      if (mounted) {
        final finalMatch = _getFinalMatch(tournamentId);
        if (finalMatch != null && finalMatch['id'] == matchId) {
          final champion = _extractChampionFromMatch(finalMatch);
          if (champion != null) {
            setState(() {
              _tournamentChampions[tournamentId] = champion;
            });
            
            _showChampionAnnouncement(tournamentId, champion);
          }
        }
      }

      if (mounted) {
        String action = _isEditMode ? 'updated' : 'saved';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Score $action: $team1Name $score1 - $score2 $team2Name'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        setState(() {
          _isSaving = false;
          _savingMatchId = null;
          _isEditMode = false;
        });

        // Restore scroll position after rebuild
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_leftPanelScrollController.hasClients) {
            _leftPanelScrollController.jumpTo(currentScroll);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _savingMatchId = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showChampionAnnouncement(String tournamentId, Map<String, dynamic> champion) {
    final tournamentName = _tournamentNames[tournamentId] ?? 'Tournament';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text('🏆 CHAMPION CROWNED! 🏆'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade400,
                      Colors.amber.shade600,
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: champion['id'] != null
                    ? _buildTeamLogo(champion['id'], champion['displayName'], size: 80)
                    : const Icon(Icons.emoji_events, size: 80, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                tournamentName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                champion['displayName'],
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3748),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'is the',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              const Text(
                'TOURNAMENT CHAMPION!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepOrange,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
              ),
              child: const Text('View Bracket'),
            ),
          ],
        );
      },
    );
  }

  void _enterEditMode(Map<String, dynamic> match) {
    // Initialize controllers with existing scores
    _initializeScoreControllers(match);
    
    // Save current scroll position
    double currentScroll = _leftPanelScrollController.hasClients 
        ? _leftPanelScrollController.position.pixels 
        : _savedScrollPosition;

    setState(() {
      _selectedMatch = match;
      _isEditMode = true;
    });

    // Restore scroll position after rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_leftPanelScrollController.hasClients) {
        _leftPanelScrollController.jumpTo(currentScroll);
      }
    });
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

  // ============== UI BUILD METHODS ==============

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: _buildAppBar(),
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

                // Extract all matches from tournaments
                final List<Map<String, dynamic>> allSchedules = [];
                
                for (var doc in snapshot.data!.docs) {
                  final tournamentData = doc.data() as Map<String, dynamic>;
                  final tournamentId = tournamentData['id'] ?? doc.id;
                  final tournamentName = tournamentData['name'] ?? 'Unnamed Tournament';
                  
                  // Get matches from matchups array
                  final matchups = tournamentData['matchups'] as List<dynamic>? ?? [];
                  
                  for (var matchup in matchups) {
                    final match = Map<String, dynamic>.from(matchup as Map);
                    
                    // Add tournament info to each match
                    match['tournamentSetupId'] = tournamentId;
                    match['tournamentName'] = tournamentName;
                    match['sport'] = tournamentData['sport'] ?? 'Unknown';
                    match['category'] = tournamentData['category'] ?? 'Unknown';
                    match['gender'] = tournamentData['gender'] ?? 'Unknown';
                    match['venue'] = tournamentData['venue'] ?? 'Not specified';
                    
                    allSchedules.add(match);
                  }
                }

                // Update matches only if changed
                if (_allMatches.isEmpty || _allMatches.length != allSchedules.length) {
                  _allMatches = allSchedules;
                  _filteredMatches = _filterMatchesByMode(allSchedules);
                }

                if (_filteredMatches.isEmpty) {
                  return _buildEmptyState();
                }

                return Row(
                  children: [
                    _buildLeftPanel(),
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

  PreferredSizeWidget _buildAppBar() {
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
              _buildFilterChip('Date', 'date'),
              _buildFilterChip('All', 'all'),
            ],
          ),
        ),
        if (_filterMode == 'date') _buildDateSelector(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildFilterChip(String label, String mode) {
    final isSelected = _filterMode == mode;
    return GestureDetector(
      onTap: () {
        if (_filterMode != mode) {
          // Save scroll position before changing filter
          double currentScroll = _leftPanelScrollController.hasClients 
              ? _leftPanelScrollController.position.pixels 
              : 0;
          
          setState(() {
            _filterMode = mode;
            _filteredMatches = _filterMatchesByMode(_allMatches);
            _selectedMatch = null;
            _isEditMode = false;
          });
          
          // Restore scroll position (will be 0 for new filter)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_leftPanelScrollController.hasClients) {
              _leftPanelScrollController.jumpTo(0);
            }
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                mode == 'all'
                    ? 'Showing all matches'
                    : 'Showing matches for selected date',
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

  Widget _buildLeftPanel() {
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
          _buildMatchStats(realMatches.length, placeholderMatches.length),
          Expanded(
            child: _buildTournamentMatchList(
              tournamentMatches, 
              placeholderMatches,
            ),
          ),
        ],
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

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
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
    final items = <Widget>[];
    
    tournamentMatches.forEach((tournamentId, matches) {
      items.add(_buildTournamentSection(tournamentId, matches));
    });
    
    if (placeholderMatches.isNotEmpty) {
      items.add(_buildFutureMatchesSection(placeholderMatches));
    }
    
    return ListView.builder(
      controller: _leftPanelScrollController,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  Widget _buildTournamentSection(
    String tournamentId, List<Map<String, dynamic>> matches) {
    final tournamentName = _tournamentNames[tournamentId] ?? 'Unknown Tournament';
    final tournamentInfo = _tournamentDetails[tournamentId] ?? {};
    final sport = tournamentInfo['sport'] ?? 'Unknown';
    final bracketType = tournamentInfo['bracketType'] ?? 'single';
    final bracketIcon = bracketType == 'double' ? Icons.sports_esports : Icons.emoji_events;
    
    final isCompleted = _isTournamentCompleted(tournamentId);
    
    Map<String, dynamic>? champion;
    if (_tournamentChampions.containsKey(tournamentId)) {
      champion = _tournamentChampions[tournamentId];
    } else if (isCompleted) {
      champion = _getTournamentChampion(tournamentId);
    }

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
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.emoji_events,
                    color: champion != null ? Colors.amber : Colors.grey.shade400,
                    size: 20,
                  ),
                  onPressed: () => _showManualChampionSelection(tournamentId),
                  tooltip: champion != null ? 'Change Champion' : 'Select Champion',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          if (champion != null) _buildChampionBanner(champion),
          
          const SizedBox(height: 8),
          ...matches.map((match) => _buildMatchListItem(match)).toList(),
        ],
      ),
    );
  }

  Widget _buildChampionBanner(Map<String, dynamic>? champion) {
    if (champion == null) return const SizedBox();
    
    String displayName = champion['displayName'] ?? champion['name'] ?? 'Unknown Team';
    String? teamId = champion['id'];
    
    if (displayName.contains('Winner') || displayName.contains('Loser') || 
        displayName.contains('Match') || displayName.contains('match_')) {
      if (teamId != null && teamId.isNotEmpty) {
        String? betterName = _getTeamNameFromId(teamId);
        if (betterName != null && !betterName.contains('Winner') && !betterName.contains('Loser')) {
          displayName = betterName;
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16, top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400,
            Colors.amber.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.emoji_events,
              color: Colors.amber.shade700,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'TOURNAMENT CHAMPION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    if (champion['isManual'] == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'MANUAL',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (teamId != null && teamId.isNotEmpty)
                      _buildTeamLogo(teamId, displayName, size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                      onPressed: () {
                        final tournamentId = _getTournamentIdFromChampion(champion);
                        if (tournamentId != null) {
                          _showManualChampionSelection(tournamentId);
                        }
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getTournamentIdFromChampion(Map<String, dynamic> champion) {
    for (var entry in _tournamentChampions.entries) {
      if (entry.value == champion) {
        return entry.key;
      }
    }
    return null;
  }

  Widget _buildMatchListItem(Map<String, dynamic> match) {
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
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
                                Icon(Icons.emoji_events,
                                    size: 10, color: Colors.amber.shade700),
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
                        if (isDoubleElim && !isFinalMatch) ...[
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
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          team1Name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isChampionMatch && match['winner'] == team1Id ? FontWeight.bold : (isFinalMatch ? FontWeight.w600 : FontWeight.w500),
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
                            fontWeight: isChampionMatch ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          team2Name,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isChampionMatch && match['winner'] == team2Id ? FontWeight.bold : (isFinalMatch ? FontWeight.w600 : FontWeight.w500),
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
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.amber.shade700,
                  size: 16,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFutureMatchesSection(List<Map<String, dynamic>> placeholderMatches) {
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
          ...placeholderMatches.map((match) => _buildFutureMatchItem(match)).toList(),
        ],
      ),
    );
  }

  Widget _buildFutureMatchItem(Map<String, dynamic> match) {
    final team1 = match['team1'] as Map<String, dynamic>? ?? {};
    final team2 = match['team2'] as Map<String, dynamic>? ?? {};
    final team1Name = _getTeamDisplayName(team1, match, _allMatches);
    final team2Name = _getTeamDisplayName(team2, match, _allMatches);
    final team1Id = team1['id']?.toString() ?? match['team1Id']?.toString();
    final team2Id = team2['id']?.toString() ?? match['team2Id']?.toString();
    final matchNumber = match['matchNumber'] ?? '#';

    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    final tournamentInfo = _tournamentDetails[tournamentId];
    final isDoubleElim = tournamentInfo?['bracketType'] == 'double';
    
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
              color: isFullyResolved
                  ? Colors.green.shade400
                  : (isDoubleElim ? Colors.purple.shade300 : Colors.blue.shade200),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),

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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                          fontWeight: isTeam1Ready ? FontWeight.w500 : FontWeight.normal,
                          color: isTeam1Ready ? Colors.grey.shade800 : Colors.grey.shade500,
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
    
    // Get team data with proper casting
    final team1Obj = match['team1'] as Map<String, dynamic>?;
    final team2Obj = match['team2'] as Map<String, dynamic>?;
    
    // Extract team information
    String team1Id = '';
    String team2Id = '';
    String team1Name = '';
    String team2Name = '';
    String team1DisplayName = '';
    String team2DisplayName = '';

    // Process Team 1
    if (team1Obj != null) {
      team1Id = team1Obj['id']?.toString() ?? '';
      team1Name = team1Obj['name']?.toString() ?? '';
      team1DisplayName = team1Obj['displayName']?.toString() ?? team1Name;
    } else {
      team1Id = match['team1Id']?.toString() ?? '';
      team1Name = match['team1Name']?.toString() ?? '';
      team1DisplayName = match['team1DisplayName']?.toString() ?? team1Name;
    }

    // Process Team 2
    if (team2Obj != null) {
      team2Id = team2Obj['id']?.toString() ?? '';
      team2Name = team2Obj['name']?.toString() ?? '';
      team2DisplayName = team2Obj['displayName']?.toString() ?? team2Name;
    } else {
      team2Id = match['team2Id']?.toString() ?? '';
      team2Name = match['team2Name']?.toString() ?? '';
      team2DisplayName = match['team2DisplayName']?.toString() ?? team2Name;
    }

    // Use display names for UI
    final team1UiName = team1DisplayName.isNotEmpty ? team1DisplayName : team1Name;
    final team2UiName = team2DisplayName.isNotEmpty ? team2DisplayName : team2Name;

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

    // Get scores from the match
    final existingScores = match['scores'] as Map<String, dynamic>? ?? {};
    
    
    // Try to get scores using multiple methods
    int score1 = 0;
    int score2 = 0;

    // Method 1: Try using team IDs (most reliable)
    if (existingScores.isNotEmpty) {
      if (team1Id.isNotEmpty && existingScores.containsKey(team1Id)) {
        score1 = existingScores[team1Id] as int? ?? 0;
      } else if (existingScores.containsKey(team1UiName)) {
        score1 = existingScores[team1UiName] as int? ?? 0;
      }
      
      if (team2Id.isNotEmpty && existingScores.containsKey(team2Id)) {
        score2 = existingScores[team2Id] as int? ?? 0;
      } else if (existingScores.containsKey(team2UiName)) {
        score2 = existingScores[team2UiName] as int? ?? 0;
      }
    }

    // Method 2: Check direct score fields
    if (score1 == 0 && match.containsKey('team1Score')) {
      score1 = match['team1Score'] as int? ?? 0;
    }
    if (score2 == 0 && match.containsKey('team2Score')) {
      score2 = match['team2Score'] as int? ?? 0;
    }

    // Method 3: For placeholder matches, check if the actual team ID is in team2Id
    if (match['isPlaceholderMatch'] == true) {
      if (team2Id.isNotEmpty && existingScores.containsKey(team2Id)) {
        score2 = existingScores[team2Id] as int? ?? 0;
      }
    }

    
    final existingWinner = match['winner'];
    final hasScores = score1 > 0 || score2 > 0 || existingScores.isNotEmpty;
    final isSavingThis = _savingMatchId == matchId;

    final tournamentId = match['tournamentSetupId']?.toString() ?? '';
    final isChampionMatch = isFinalMatch && hasScores && existingWinner != null && existingWinner != 'tie';
    final champion = isChampionMatch ? _extractChampionFromMatch(match) : null;

    // Initialize controllers if needed
    if (!_scoreControllers.containsKey('${matchId}_1')) {
      _scoreControllers['${matchId}_1'] = TextEditingController(text: score1.toString());
    } else {
      _scoreControllers['${matchId}_1']?.text = score1.toString();
    }
    
    if (!_scoreControllers.containsKey('${matchId}_2')) {
      _scoreControllers['${matchId}_2'] = TextEditingController(text: score2.toString());
    } else {
      _scoreControllers['${matchId}_2']?.text = score2.toString();
    }
    
    if (!_selectedWinners.containsKey(matchId) && existingWinner != null) {
      _selectedWinners[matchId] = existingWinner.toString();
    }

    return SingleChildScrollView(
      controller: _rightPanelScrollController,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isEditMode)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
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
                            // Reset controllers to original values
                            _scoreControllers['${matchId}_1']?.text = score1.toString();
                            _scoreControllers['${matchId}_2']?.text = score2.toString();
                            if (existingWinner != null) {
                              _selectedWinners[matchId] = existingWinner.toString();
                            }
                          });
                        },
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
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w500,
                          ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team1Id, team1UiName, size: 120),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: existingWinner == team1Id
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.deepOrange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (existingWinner == team1Id && isChampionMatch)
                                      Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 16),
                                    if (existingWinner == team1Id && isChampionMatch)
                                      const SizedBox(width: 4),
                                    Text(
                                      team1UiName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: existingWinner == team1Id ? FontWeight.bold : FontWeight.w600,
                                        color: existingWinner == team1Id ? Colors.amber.shade800 : Color(0xFF2D3748),
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
                                    color: existingWinner == team1Id && isChampionMatch
                                        ? Colors.amber.shade400
                                        : Colors.grey.shade300,
                                    width: existingWinner == team1Id && isChampionMatch ? 3 : 2,
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
                                  controller: _scoreControllers['${matchId}_1'],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: existingWinner == team1Id && isChampionMatch
                                        ? Colors.amber.shade700
                                        : Color(0xFF2D3748),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(color: Colors.grey.shade400),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  enabled: !isSavingThis && 
                                          (_isEditMode || !hasScores) && 
                                          !isPlaceholder,
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
                                  child: Icon(
                                    Icons.emoji_events,
                                    color: Colors.amber.shade700,
                                    size: 24,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        Expanded(
                          child: Column(
                            children: [
                              _buildTeamLogo(team2Id, team2UiName, size: 120),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: existingWinner == team2Id
                                      ? Colors.amber.withOpacity(0.2)
                                      : Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (existingWinner == team2Id && isChampionMatch)
                                      Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 16),
                                    if (existingWinner == team2Id && isChampionMatch)
                                      const SizedBox(width: 4),
                                    Text(
                                      team2UiName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: existingWinner == team2Id ? FontWeight.bold : FontWeight.w600,
                                        color: existingWinner == team2Id ? Colors.amber.shade800 : Color(0xFF2D3748),
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
                                    color: existingWinner == team2Id && isChampionMatch
                                        ? Colors.amber.shade400
                                        : Colors.grey.shade300,
                                    width: existingWinner == team2Id && isChampionMatch ? 3 : 2,
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
                                  controller: _scoreControllers['${matchId}_2'],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: existingWinner == team2Id && isChampionMatch
                                        ? Colors.amber.shade700
                                        : Color(0xFF2D3748),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0',
                                    hintStyle: TextStyle(color: Colors.grey.shade400),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
                          Row(
                            children: [
                              const Text(
                                'Select Winner',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF4A5568),
                                ),
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
                                child: _buildWinnerButtonWithLogo(
                                  label: team1UiName,
                                  teamId: team1Id,
                                  isSelected: _selectedWinners[matchId] ==
                                      (team1Id.isNotEmpty ? team1Id : team1UiName),
                                  color: existingWinner == team1Id && isChampionMatch
                                      ? Colors.amber
                                      : Colors.deepOrange,
                                  showCrown: existingWinner == team1Id && isChampionMatch,
                                  onTap: (_isEditMode || !hasScores) && !isPlaceholder
                                      ? () {
                                          setState(() {
                                            _selectedWinners[matchId] =
                                                team1Id.isNotEmpty ? team1Id : team1UiName;
                                          });
                                        }
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildWinnerButtonWithLogo(
                                  label: team2UiName,
                                  teamId: team2Id,
                                  isSelected: _selectedWinners[matchId] ==
                                      (team2Id.isNotEmpty ? team2Id : team2UiName),
                                  color: existingWinner == team2Id && isChampionMatch
                                      ? Colors.amber
                                      : Colors.blue,
                                  showCrown: existingWinner == team2Id && isChampionMatch,
                                  onTap: (_isEditMode || !hasScores) && !isPlaceholder
                                      ? () {
                                          setState(() {
                                            _selectedWinners[matchId] =
                                                team2Id.isNotEmpty ? team2Id : team2UiName;
                                          });
                                        }
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildWinnerButton(
                                  label: 'Tie',
                                  isSelected: _selectedWinners[matchId] == 'tie',
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

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (isSavingThis || 
                                      isPlaceholder || 
                                      (!_isEditMode && hasScores))
                                ? null
                                : () {
                                    _scoreControllers['${matchId}_1']?.clear();
                                    _scoreControllers['${matchId}_2']?.clear();
                                    _selectedWinners.remove(matchId);
                                    setState(() {});
                                  },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: Colors.grey.shade400),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Reset', style: TextStyle(fontSize: 16)),
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
                                          ? (isChampionMatch ? Colors.amber : Colors.green)
                                          : Colors.deepOrange)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isChampionMatch && !_isEditMode && hasScores)
                                        Icon(Icons.emoji_events, size: 20, color: Colors.white),
                                      if (isChampionMatch && !_isEditMode && hasScores)
                                        const SizedBox(width: 8),
                                      Text(
                                        isPlaceholder
                                            ? 'Cannot Score'
                                            : (_isEditMode
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

                    if (hasScores && !_isEditMode) ...[
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
                                      if (existingWinner != null && existingWinner != 'tie')
                                        _buildTeamLogo(
                                          existingWinner == team1Id ? team1Id : team2Id,
                                          existingWinner == team1Id ? team1UiName : team2UiName,
                                          size: 24,
                                        ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          isChampionMatch
                                              ? 'Winner: ${existingWinner == 'tie' ? 'Tie' : (existingWinner == team1Id ? team1UiName : team2UiName)} is the CHAMPION!'
                                              : 'Winner: ${existingWinner == 'tie' ? 'Tie' : (existingWinner == team1Id ? team1UiName : team2UiName)}',
                                          style: TextStyle(
                                            color: isChampionMatch ? Colors.amber.shade600 : Colors.green.shade600,
                                            fontSize: 13,
                                            fontWeight: isChampionMatch ? FontWeight.bold : FontWeight.normal,
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
                                          color: isChampionMatch ? Colors.amber.shade400 : Colors.green.shade400,
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
                                backgroundColor: isChampionMatch ? Colors.amber : Colors.blue,
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
              
              if (isChampionMatch) ...[
                const SizedBox(height: 16),
                _buildChampionDisplay(match),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWinnerButtonWithLogo({
    required String label,
    required String? teamId,
    required bool isSelected,
    required Color color,
    required VoidCallback? onTap,
    bool showCrown = false,
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
            Stack(
              children: [
                _buildTeamLogo(teamId, label, size: 40),
                if (showCrown)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.emoji_events,
                        color: Colors.amber.shade700,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected) Icon(Icons.check_circle, color: color, size: 16),
                if (isSelected) const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
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

  Widget _buildChampionDisplay(Map<String, dynamic> match) {
    if (match['winner'] == null || match['winner'] == 'tie') return const SizedBox();
    
    final champion = _extractChampionFromMatch(match);
    if (champion == null) return const SizedBox();
    
    String championName = champion['displayName'] ?? 'Unknown Team';
    String? championId = champion['id'];
    
    if (championName.contains('Winner') || championName.contains('Loser') || 
        championName.contains('Match') || championName.contains('match_')) {
      if (championId != null && championId.isNotEmpty) {
        String? betterName = _getTeamNameFromId(championId);
        if (betterName != null && !betterName.contains('Winner') && !betterName.contains('Loser')) {
          championName = betterName;
        }
      }
    }
    
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade400,
            Colors.amber.shade600,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'TOURNAMENT CHAMPION',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (championId != null && championId.isNotEmpty)
                _buildTeamLogo(championId, championName, size: 60),
              const SizedBox(width: 16),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      championName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMatchOptionsDialog(Map<String, dynamic> match) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
        
        // Load champion if exists
        if (data.containsKey('champion') && data['champion'] != null) {
          _tournamentChampions[tournamentId] = Map<String, dynamic>.from(data['champion']);
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