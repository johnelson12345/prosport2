import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:intl/intl.dart';

class TournamentOfficialBracketDialog extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const TournamentOfficialBracketDialog({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  _TournamentOfficialBracketDialogState createState() =>
      _TournamentOfficialBracketDialogState();

  static Future<void> show({
    required BuildContext context,
    required String tournamentId,
    required String tournamentName,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => TournamentOfficialBracketDialog(
        tournamentId: tournamentId,
        tournamentName: tournamentName,
      ),
    );
  }
}

class _TournamentOfficialBracketDialogState
    extends State<TournamentOfficialBracketDialog> {
  final TeamScheduleService _service = TeamScheduleService();
  List<Map<String, dynamic>> _matchups = [];
  bool _isLoading = true;

  // Cache for resolved team names
  final Map<String, String> _teamNameCache = {};

  // Bracket structure
  late Map<int, List<Map<String, dynamic>>> _rounds;
  late Map<String, List<int>> _matchConnections;

  @override
  void initState() {
    super.initState();
    _loadBracketData();
  }

  Future<void> _loadBracketData() async {
    try {
      final allSchedules = await _service.getAllTeamSchedules().first;
      final schedules = allSchedules
          .where((s) => s['tournamentSetupId'] == widget.tournamentId)
          .toList();

      // Sort by match number
      schedules.sort((a, b) {
        final aNum = a['matchNumber'] ?? 999;
        final bNum = b['matchNumber'] ?? 999;
        return aNum.compareTo(bNum);
      });

      setState(() {
        _matchups = schedules;
        _organizeBracket();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading bracket: $e')),
        );
      }
    }
  }

  // Query Firestore directly to get participant name by ID
  Future<String> _getParticipantName(String participantId) async {
    if (participantId.isEmpty || participantId == 'null') return 'TBD';
    
    // Check cache first
    if (_teamNameCache.containsKey(participantId)) {
      return _teamNameCache[participantId]!;
    }
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('participants')
          .doc(participantId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String name = data['name'] ?? data['teamName'] ?? data['coachName'] ?? 'Unknown';
        _teamNameCache[participantId] = name;
        return name;
      }
    } catch (e) {
      // Silently handle missing participant
    }
    _teamNameCache[participantId] = participantId;
    return participantId; // Return ID if not found
  }
// Get team name - handles placeholders and actual teams
Future<String> _getTeamName(dynamic team) async {
  if (team == null) return 'TBD';
  
  // If team is a map
  if (team is Map<String, dynamic>) {
    // Check if it's a placeholder
    if (team['isPlaceholder'] == true) {
      // Get the source match number
      int? sourceMatchNumber;
      
      // Try different ways to get the source match
      if (team['sourceMatch'] != null) {
        sourceMatchNumber = team['sourceMatch'] is int 
            ? team['sourceMatch'] 
            : int.tryParse(team['sourceMatch'].toString());
      } else if (team['sourceMatchNumber'] != null) {
        sourceMatchNumber = team['sourceMatchNumber'] is int
            ? team['sourceMatchNumber']
            : int.tryParse(team['sourceMatchNumber'].toString());
      }
      
      if (sourceMatchNumber != null) {
        // Find the source match
        final sourceMatch = _matchups.firstWhere(
          (m) => m['matchNumber'] == sourceMatchNumber,
          orElse: () => {},
        );
        
        if (sourceMatch.isNotEmpty) {
          // Check if we need winner or loser
          bool needWinner = team['name']?.toString().contains('Winner') ?? 
                           team['displayName']?.toString().contains('Winner') ?? 
                           team['type'] == 'winner' ?? false;
          
          if (needWinner) {
            // If source match has a winner, return that team's name
            if (sourceMatch['winner'] != null) {
              return await _getTeamName(sourceMatch['winner']);
            }
            
            // No winner yet, show the teams that will play
            String team1Name = await _getTeamName(sourceMatch['team1']);
            String team2Name = await _getTeamName(sourceMatch['team2']);
            
            // Remove any "TBD" or placeholder text for cleaner display
            team1Name = _cleanTeamName(team1Name);
            team2Name = _cleanTeamName(team2Name);
            
            return 'Winner: $team1Name vs $team2Name';
          } else {
            // Need loser
            if (sourceMatch['loser'] != null) {
              return await _getTeamName(sourceMatch['loser']);
            }
            
            // No loser yet, show the teams
            String team1Name = await _getTeamName(sourceMatch['team1']);
            String team2Name = await _getTeamName(sourceMatch['team2']);
            
            team1Name = _cleanTeamName(team1Name);
            team2Name = _cleanTeamName(team2Name);
            
            return 'Loser: $team1Name vs $team2Name';
          }
        }
      }
      
      // If we can't resolve, return a cleaned version of the display name
      String displayName = team['displayName'] ?? team['name'] ?? 'TBD';
      return _cleanTeamName(displayName);
    }
    
    // Regular team with ID - get from Firestore
    if (team.containsKey('id') && team['id'] != null) {
      String id = team['id'].toString();
      
      // Check if it's a placeholder ID
      if (id.contains('match_') || id.contains('placeholder')) {
        // This might be a placeholder masquerading as a regular team
        // Try to extract match number from ID
        final matchRegex = RegExp(r'match_(\d+)_');
        final matchMatch = matchRegex.firstMatch(id);
        if (matchMatch != null) {
          int matchNum = int.parse(matchMatch.group(1)!);
          final sourceMatch = _matchups.firstWhere(
            (m) => m['matchNumber'] == matchNum,
            orElse: () => {},
          );
          if (sourceMatch.isNotEmpty) {
            if (id.contains('winner')) {
              if (sourceMatch['winner'] != null) {
                return await _getTeamName(sourceMatch['winner']);
              }
            } else if (id.contains('loser')) {
              if (sourceMatch['loser'] != null) {
                return await _getTeamName(sourceMatch['loser']);
              }
            }
          }
        }
      }
      
      // Regular participant ID
      return await _getParticipantName(id);
    }
    
    // Team with direct name
    if (team.containsKey('name') && team['name'] != null) {
      String name = team['name'].toString();
      if (!name.contains('Match') && !name.contains('Winner') && !name.contains('Loser')) {
        return name;
      }
    }
    
    if (team.containsKey('displayName') && team['displayName'] != null) {
      String displayName = team['displayName'].toString();
      return _cleanTeamName(displayName);
    }
  }
  
  // If team is a string
  if (team is String) {
    // Check if it's a placeholder string
    if (team.contains('Winner of') || team.contains('Loser of')) {
      // Try to extract match numbers
      final regex = RegExp(r'Winner of Match (\d+) vs Match (\d+)');
      final match = regex.firstMatch(team);
      if (match != null) {
        int match1 = int.parse(match.group(1)!);
        int match2 = int.parse(match.group(2)!);
        
        // Try to find winners of these matches
        for (var m in _matchups) {
          if (m['matchNumber'] == match1 && m['winner'] != null) {
            return await _getTeamName(m['winner']);
          }
          if (m['matchNumber'] == match2 && m['winner'] != null) {
            return await _getTeamName(m['winner']);
          }
        }
      }
    }
    
    // Check if it's a Firestore ID
    if (team.length > 15 || team.contains('-')) {
      return await _getParticipantName(team);
    }
    
    // Return as-is, but clean it
    return _cleanTeamName(team);
  }
  
  if (team is int) {
    return await _getParticipantName(team.toString());
  }
  
  return 'TBD';
}

// Helper method to clean up team names
String _cleanTeamName(String name) {
  if (name.contains('match_') || name.contains('_winner') || name.contains('_loser')) {
    // Try to extract a meaningful name from the ID
    if (name.contains('match_')) {
      final regex = RegExp(r'match_(\d+)_(winner|loser)');
      final match = regex.firstMatch(name);
      if (match != null) {
        String type = match.group(2) == 'winner' ? 'Winner' : 'Loser';
        return '$type Match ${match.group(1)}';
      }
    }
    return 'TBD';
  }
  return name;
}

  // Get winner name
Future<String> _getWinnerName(dynamic winner, Map<String, dynamic> match) async {
  if (winner == null) return 'TBD';
  
  // If winner is a map
  if (winner is Map<String, dynamic>) {
    return await _getTeamName(winner);
  }
  
  // If winner is a string (could be ID)
  if (winner is String) {
    // Check if it's a placeholder
    if (winner.contains('match_') || winner.contains('winner') || winner.contains('loser')) {
      // Try to find the actual team in the match
      if (match['team1'] != null) {
        String team1Id = _getTeamId(match['team1']);
        if (team1Id == winner) {
          return await _getTeamName(match['team1']);
        }
      }
      if (match['team2'] != null) {
        String team2Id = _getTeamId(match['team2']);
        if (team2Id == winner) {
          return await _getTeamName(match['team2']);
        }
      }
      
      // Try to find in previous matches
      for (var m in _matchups) {
        if (m['matchNumber'] == match['matchNumber'] - 1) {
          if (m['winner'] != null) {
            return await _getTeamName(m['winner']);
          }
        }
      }
    }
    
    // Try to find which team this winner ID belongs to
    if (match['team1'] != null && _getTeamId(match['team1']) == winner) {
      return await _getTeamName(match['team1']);
    }
    if (match['team2'] != null && _getTeamId(match['team2']) == winner) {
      return await _getTeamName(match['team2']);
    }
    
    // Search all matches
    for (var m in _matchups) {
      if (m['team1'] != null && _getTeamId(m['team1']) == winner) {
        return await _getTeamName(m['team1']);
      }
      if (m['team2'] != null && _getTeamId(m['team2']) == winner) {
        return await _getTeamName(m['team2']);
      }
    }
    
    // Otherwise treat as ID
    return await _getParticipantName(winner);
  }
  
  if (winner is int) {
    return await _getParticipantName(winner.toString());
  }
  
  return winner.toString();
}

  // Get loser name
  Future<String> _getLoserName(dynamic loser, Map<String, dynamic> match) async {
    if (loser == null) return 'TBD';
    return await _getTeamName(loser);
  }

  // Get team ID from various formats
  String _getTeamId(dynamic team) {
    if (team == null) return '';
    
    if (team is Map<String, dynamic>) {
      if (team.containsKey('id')) return team['id'].toString();
      if (team.containsKey('resolvedId')) return team['resolvedId'].toString();
    }
    
    if (team is String) return team;
    if (team is int) return team.toString();
    
    return '';
  }

  // Get team score
  String? _getTeamScore(dynamic team, Map<String, dynamic> match) {
    if (team == null) return null;

    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    final teamId = _getTeamId(team);

    // Try various score lookup methods
    if (teamId.isNotEmpty && scores.containsKey(teamId)) {
      return scores[teamId].toString();
    }

    return null;
  }

  bool _isByeMatch(Map<String, dynamic> match) {
    if (match['matchType'] == 'bye') return true;
    
    // Check for BYE in team names
    if (match['team1'] != null) {
      String team1Name = match['team1'] is Map 
          ? (match['team1']['name'] ?? '') 
          : match['team1'].toString();
      if (team1Name == 'BYE') return true;
    }
    
    if (match['team2'] != null) {
      String team2Name = match['team2'] is Map 
          ? (match['team2']['name'] ?? '') 
          : match['team2'].toString();
      if (team2Name == 'BYE') return true;
    }
    
    return false;
  }

  void _organizeBracket() {
    _rounds = {};
    _matchConnections = {};

    if (_matchups.isEmpty) return;

    // Group matches by round
    for (var match in _matchups) {
      final round = match['round'] ?? 1;
      _rounds.putIfAbsent(round, () => []).add(match);
    }

    // Sort matches within each round by match number
    _rounds.forEach((round, matches) {
      matches.sort((a, b) {
        final aNum = a['matchNumber'] ?? 0;
        final bNum = b['matchNumber'] ?? 0;
        return aNum.compareTo(bNum);
      });
    });

    // Build connections for visual lines
    for (var match in _matchups) {
      final nextMatchRef = match['nextMatchReference'];
      final matchNumber = match['matchNumber'];
      if (nextMatchRef != null && matchNumber != null) {
        _matchConnections
            .putIfAbsent(nextMatchRef.toString(), () => [])
            .add(matchNumber);
      }
    }
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null || dateTime == '') return 'TBD';

    try {
      DateTime? parsedDate;

      // Handle different input types
      if (dateTime is DateTime) {
        parsedDate = dateTime;
      } 
      else if (dateTime is Timestamp) {
        parsedDate = dateTime.toDate();
      }
      else if (dateTime is String) {
        final String dateStr = dateTime.trim();
        if (dateStr.isEmpty) return 'TBD';

        // Try parsing common formats (dd/MM/yyyy HH:mm)
        if (dateStr.contains('/')) {
          try {
            final parts = dateStr.split(' ');
            final dateParts = parts[0].split('/');
            
            if (dateParts.length == 3) {
              // Assuming format dd/MM/yyyy
              final day = int.tryParse(dateParts[0]);
              final month = int.tryParse(dateParts[1]);
              final year = int.tryParse(dateParts[2]);
              
              if (day != null && month != null && year != null) {
                if (parts.length > 1) {
                  final timeParts = parts[1].split(':');
                  if (timeParts.length >= 2) {
                    final hour = int.tryParse(timeParts[0]) ?? 0;
                    final minute = int.tryParse(timeParts[1]) ?? 0;
                    parsedDate = DateTime(year, month, day, hour, minute);
                  }
                } else {
                  parsedDate = DateTime(year, month, day);
                }
              }
            }
          } catch (e) {
            // Continue to next format
          }
        }
        
        // Try ISO format
        if (parsedDate == null) {
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            // Continue
          }
        }
      } 

      if (parsedDate == null) return 'TBD';

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final matchDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

      String dateStr;
      if (matchDate == today) {
        dateStr = 'Today';
      } else if (matchDate == today.add(const Duration(days: 1))) {
        dateStr = 'Tomorrow';
      } else if (matchDate == today.subtract(const Duration(days: 1))) {
        dateStr = 'Yesterday';
      } else {
        dateStr = DateFormat('MMM dd, yyyy').format(parsedDate);
      }

      if (parsedDate.hour == 0 && parsedDate.minute == 0) {
        return dateStr;
      }

      final timeStr = DateFormat('h:mm a').format(parsedDate);
      return '$dateStr at $timeStr';
      
    } catch (e) {
      return 'Invalid Date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple, Colors.purpleAccent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.tournamentName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          'Tournament Bracket',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_matchups.length} Matches',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _matchups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No matchups available',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add matches to see the bracket',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: _buildBracketView(),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBracketView() {
    final roundNumbers = _rounds.keys.toList()..sort();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: roundNumbers.asMap().entries.map((entry) {
        final index = entry.key;
        final round = entry.value;
        final matches = _rounds[round]!;
        final isLastRound = round == roundNumbers.last;

        return _buildRoundColumn(
          round: round,
          matches: matches,
          isLastRound: isLastRound,
          totalRounds: roundNumbers.length,
          roundIndex: index,
        );
      }).toList(),
    );
  }

  Widget _buildRoundColumn({
    required int round,
    required List<Map<String, dynamic>> matches,
    required bool isLastRound,
    required int totalRounds,
    required int roundIndex,
  }) {
    String roundName;
    
    // Determine round name based on bracket type and round number
    final firstMatch = matches.isNotEmpty ? matches.first : null;
    final bracketType = firstMatch?['bracket'];
    
    if (bracketType == 'grand') {
      roundName = 'GRAND FINAL';
    } else if (bracketType == 'winners') {
      if (isLastRound && bracketType == 'winners') {
        roundName = 'WINNERS FINAL';
      } else if (roundIndex == totalRounds - 2) {
        roundName = 'WINNERS SEMIFINAL';
      } else {
        roundName = 'WINNERS ROUND $round';
      }
    } else if (bracketType == 'losers') {
      if (round == 1) {
        roundName = 'LOSERS ROUND 1';
      } else if (round == 2) {
        roundName = 'LOSERS ROUND 2';
      } else if (round == 3) {
        roundName = 'LOSERS ROUND 3';
      } else {
        roundName = 'LOSERS ROUND $round';
      }
    } else {
      roundName = 'ROUND $round';
    }

    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: bracketType == 'grand'
                    ? [Colors.amber.shade700, Colors.orange.shade700]
                    : bracketType == 'winners'
                        ? [Colors.green.shade700, Colors.teal.shade700]
                        : bracketType == 'losers'
                            ? [Colors.red.shade700, Colors.orange.shade700]
                            : [Colors.indigo.shade700, Colors.blue.shade700],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  roundName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  '${matches.length} Match${matches.length > 1 ? 'es' : ''}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: List.generate(matches.length, (index) {
                  final match = matches[index];
                  final matchNumber = match['matchNumber'] ?? 0;

                  List<int>? prevMatches =
                      _matchConnections[matchNumber.toString()];

                  return Column(
                    children: [
                      FutureBuilder<Map<String, String>>(
                        future: _resolveMatchNames(match),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Container(
                              width: 280,
                              height: 160,
                              padding: const EdgeInsets.all(16),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          
                          return _buildBracketMatchCard(
                            match: match,
                            roundIndex: roundIndex,
                            matchIndex: index,
                            totalMatches: matches.length,
                            isLastRound: isLastRound,
                            prevMatches: prevMatches,
                            resolvedNames: snapshot.data!,
                          );
                        },
                      ),
                      if (index < matches.length - 1)
                        SizedBox(height: 24),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, String>> _resolveMatchNames(Map<String, dynamic> match) async {
    String team1Name = 'TBD';
    String team2Name = 'TBD';
    String winnerName = 'TBD';
    String loserName = 'TBD';
    
    // Resolve team1
    if (match['team1'] != null) {
      team1Name = await _getTeamName(match['team1']);
    }
    
    // Resolve team2
    if (match['team2'] != null) {
      team2Name = await _getTeamName(match['team2']);
    }
    
    // Resolve winner
    if (match['winner'] != null) {
      winnerName = await _getWinnerName(match['winner'], match);
    }
    
    // Resolve loser
    if (match['loser'] != null) {
      loserName = await _getLoserName(match['loser'], match);
    }
    
    return {
      'team1': team1Name,
      'team2': team2Name,
      'winner': winnerName,
      'loser': loserName,
    };
  }

  Widget _buildBracketMatchCard({
    required Map<String, dynamic> match,
    required int roundIndex,
    required int matchIndex,
    required int totalMatches,
    required bool isLastRound,
    List<int>? prevMatches,
    required Map<String, String> resolvedNames,
  }) {
    final matchNumber = match['matchNumber'] ?? matchIndex + 1;
    final matchType = match['matchType'] ?? 'regular';
    final bracket = match['bracket'] as String?;
    final isGrandFinal = match['isGrandFinal'] == true;
    final isBye = _isByeMatch(match);

    String team1Name = resolvedNames['team1'] ?? 'TBD';
    String team2Name = resolvedNames['team2'] ?? 'TBD';
    String winnerName = resolvedNames['winner'] ?? 'TBD';
    
    String? team1Score = _getTeamScore(match['team1'], match);
    String? team2Score = _getTeamScore(match['team2'], match);

    final hasWinner = match['winner'] != null;

    // Determine colors based on bracket type
    Color bracketColor = Colors.blue;
    if (bracket == 'winners') {
      bracketColor = Colors.green;
    } else if (bracket == 'losers') {
      bracketColor = Colors.orange;
    } else if (bracket == 'grand' || isGrandFinal) {
      bracketColor = Colors.amber;
    }

    return Container(
      width: 280,
      margin: EdgeInsets.only(
        bottom: matchIndex < totalMatches - 1 ? 8 : 0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasWinner
              ? (isGrandFinal ? Colors.amber.shade400 : Colors.green.shade400)
              : Colors.grey.shade300,
          width: hasWinner ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
          if (hasWinner)
            BoxShadow(
              color: (isGrandFinal ? Colors.amber : Colors.green)
                  .withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Match header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: bracketColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  bracket == 'winners'
                      ? Icons.emoji_events
                      : (bracket == 'losers'
                          ? Icons.restore
                          : (isGrandFinal
                              ? Icons.stadium
                              : Icons.sports)),
                  size: 12,
                  color: bracketColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Match $matchNumber',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      color: bracketColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (bracket != null)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      bracket == 'grand' ? 'GF' : bracket[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: bracketColor,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: hasWinner
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    hasWinner ? 'Done' : 'Scheduled',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: hasWinner
                          ? Colors.green.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Match content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                if (isBye) ...[
                  _buildTeamRow(
                    label: team1Name,
                    score: team1Score,
                    isWinner: true,
                    isGrandFinal: isGrandFinal,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'BYE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ] else ...[
                  _buildTeamRow(
                    label: team1Name,
                    score: team1Score,
                    isWinner: match['winner'] != null && 
                        (_getTeamId(match['team1']) == _getTeamId(match['winner']) ||
                         team1Name == winnerName),
                    isGrandFinal: isGrandFinal,
                  ),

                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: const Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),

                  _buildTeamRow(
                    label: team2Name,
                    score: team2Score,
                    isWinner: match['winner'] != null && 
                        (_getTeamId(match['team2']) == _getTeamId(match['winner']) ||
                         team2Name == winnerName),
                    isGrandFinal: isGrandFinal,
                  ),
                ],

                // Date/Time
                if (match['dateTime'] != null || match['startTime'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 10,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDateTime(match['dateTime'] ?? match['startTime']),
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Next match reference
                if (match['nextMatchReference'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '→ Advances to Match ${match['nextMatchReference']}',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Winner footer
          if (hasWinner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 8,
              ),
              decoration: BoxDecoration(
                color: (isGrandFinal ? Colors.amber : Colors.green).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(11),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isGrandFinal ? Icons.emoji_events : Icons.star,
                    size: 10,
                    color: isGrandFinal ? Colors.amber.shade700 : Colors.green.shade700,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Winner: $winnerName',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isGrandFinal ? Colors.amber.shade700 : Colors.green.shade700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTeamRow({
    required String label,
    String? score,
    required bool isWinner,
    required bool isGrandFinal,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isWinner
            ? (isGrandFinal ? Colors.amber.shade50 : Colors.green.shade50)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWinner
              ? (isGrandFinal ? Colors.amber.shade200 : Colors.green.shade200)
              : Colors.grey.shade200,
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          if (isWinner)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                isGrandFinal ? Icons.emoji_events : Icons.check_circle,
                size: 10,
                color: isGrandFinal ? Colors.amber.shade700 : Colors.green.shade700,
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                color: isWinner
                    ? (isGrandFinal ? Colors.amber.shade700 : Colors.green.shade700)
                    : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (score != null && score.isNotEmpty) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isWinner
                    ? (isGrandFinal ? Colors.amber.shade100 : Colors.green.shade100)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                score,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isWinner
                      ? (isGrandFinal ? Colors.amber.shade700 : Colors.green.shade700)
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}