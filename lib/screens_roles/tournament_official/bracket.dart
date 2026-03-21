import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  State<TournamentOfficialBracketDialog> createState() =>
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
  List<Map<String, dynamic>> _matchups = [];
  bool _isLoading = true;
  String? _error;

  // Cache for participant names
  final Map<String, String> _participantNameCache = {};
  
  // Cache for resolved match results - key: matchNumber, value: {team1, team2, winner, loser}
  final Map<int, Map<String, String>> _matchResults = {};

  // Bracket structure
  late Map<int, List<Map<String, dynamic>>> _rounds;
  late Map<String, List<int>> _matchConnections;

  @override
  void initState() {
    super.initState();
    _loadBracketData();
  }

  Future<void> _loadBracketData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tournamentQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: widget.tournamentId)
          .limit(1)
          .get();

      if (tournamentQuery.docs.isEmpty) {
        setState(() {
          _error = 'Tournament not found';
          _isLoading = false;
        });
        return;
      }

      final tournamentDoc = tournamentQuery.docs.first;
      final tournamentData = tournamentDoc.data();
      final matchups = tournamentData['matchups'] as List<dynamic>? ?? [];

      List<Map<String, dynamic>> schedules = [];
      for (var matchup in matchups) {
        final match = Map<String, dynamic>.from(matchup as Map);
        match['tournamentSetupId'] = tournamentData['id'];
        match['tournamentName'] = tournamentData['name'] ?? 'Unnamed Tournament';
        schedules.add(match);
      }

      schedules.sort((a, b) {
        final aNum = a['matchNumber'] ?? 999;
        final bNum = b['matchNumber'] ?? 999;
        return aNum.compareTo(bNum);
      });

      // First, load all participant names from Firestore
      await _loadAllParticipantNames(schedules);
      
      // Then, process matches in order to build results cache
      for (var match in schedules) {
        await _processMatch(match);
      }

      setState(() {
        _matchups = schedules;
        _organizeBracket();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading bracket: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAllParticipantNames(List<Map<String, dynamic>> schedules) async {
    // Collect all participant IDs from all matches
    Set<String> participantIds = {};
    
    for (var match in schedules) {
      // Get from team1 and team2 objects
      if (match['team1'] is Map && match['team1']['id'] != null) {
        String id = match['team1']['id'].toString();
        if (!id.contains('match_') && !id.contains('winner') && !id.contains('loser')) {
          participantIds.add(id);
        }
      }
      if (match['team2'] is Map && match['team2']['id'] != null) {
        String id = match['team2']['id'].toString();
        if (!id.contains('match_') && !id.contains('winner') && !id.contains('loser')) {
          participantIds.add(id);
        }
      }
      
      // Get from team1Id and team2Id fields
      if (match['team1Id'] != null) {
        String id = match['team1Id'].toString();
        if (!id.contains('match_') && !id.contains('winner') && !id.contains('loser')) {
          participantIds.add(id);
        }
      }
      if (match['team2Id'] != null) {
        String id = match['team2Id'].toString();
        if (!id.contains('match_') && !id.contains('winner') && !id.contains('loser')) {
          participantIds.add(id);
        }
      }
      
      // Get from scores map keys (they might be team names or IDs)
      if (match['scores'] != null) {
        final scores = match['scores'] as Map<String, dynamic>;
        for (var key in scores.keys) {
          if (key.contains('-') || key.length > 10) {
            participantIds.add(key);
          }
        }
      }
    }
    
    // Fetch all participant names
    for (var id in participantIds) {
      await _getParticipantName(id);
    }
  }

  Future<String> _getParticipantName(String participantId) async {
    if (participantId.isEmpty || participantId == 'null') return 'TBD';
    
    if (_participantNameCache.containsKey(participantId)) {
      return _participantNameCache[participantId]!;
    }
    
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('participants')
          .doc(participantId)
          .get();
      
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String name = data['name'] ?? data['teamName'] ?? 'Unknown';
        // Remove "Seed X" suffix
        name = name.replaceAll(RegExp(r'\s*\(Seed \d+\)\s*'), '');
        _participantNameCache[participantId] = name;
        return name;
      }
    } catch (e) {}
    _participantNameCache[participantId] = participantId;
    return participantId;
  }

  // Get actual team name - this is the main resolver
  Future<String> _getActualTeamName(dynamic team, Map<String, dynamic> contextMatch) async {
    if (team == null) return 'TBD';
    
    // If it's a map
    if (team is Map<String, dynamic>) {
      // Check if it's a placeholder
      if (team['isPlaceholder'] == true || team['type'] == 'placeholder') {
        return await _resolvePlaceholderFromMap(team);
      }
      
      // If it has an ID
      if (team.containsKey('id') && team['id'] != null) {
        String id = team['id'].toString();
        return await _resolveById(id, contextMatch);
      }
      
      // Direct name
      if (team.containsKey('displayName') && team['displayName'] != null) {
        return _cleanTeamName(team['displayName'].toString());
      }
      if (team.containsKey('name') && team['name'] != null) {
        return _cleanTeamName(team['name'].toString());
      }
    }
    
    // If it's a string
    if (team is String) {
      return await _resolveByString(team, contextMatch);
    }
    
    return 'TBD';
  }

  Future<String> _resolvePlaceholderFromMap(Map<String, dynamic> placeholder) async {
    int? sourceMatchNum;
    bool needWinner = true;
    
    // Get source match number
    if (placeholder['sourceMatch'] != null) {
      sourceMatchNum = placeholder['sourceMatch'] is int 
          ? placeholder['sourceMatch'] 
          : int.tryParse(placeholder['sourceMatch'].toString());
    }
    
    // Determine if we need winner or loser
    needWinner = placeholder['name']?.toString().contains('Winner') ?? 
                 placeholder['displayName']?.toString().contains('Winner') ?? 
                 placeholder['type'] == 'winner' ?? true;
    
    if (sourceMatchNum != null && _matchResults.containsKey(sourceMatchNum)) {
      if (needWinner) {
        return _matchResults[sourceMatchNum]!['winner'] ?? 'TBD';
      } else {
        return _matchResults[sourceMatchNum]!['loser'] ?? 'TBD';
      }
    }
    
    return placeholder['displayName'] ?? placeholder['name'] ?? 'TBD';
  }

  Future<String> _resolveById(String id, Map<String, dynamic> contextMatch) async {
    // Check if it's a placeholder ID like match_1_winner
    final regex = RegExp(r'match_(\d+)_(winner|loser)');
    final match = regex.firstMatch(id);
    if (match != null) {
      int sourceMatchNum = int.parse(match.group(1)!);
      bool needWinner = match.group(2) == 'winner';
      if (_matchResults.containsKey(sourceMatchNum)) {
        return needWinner 
            ? _matchResults[sourceMatchNum]!['winner'] ?? 'TBD'
            : _matchResults[sourceMatchNum]!['loser'] ?? 'TBD';
      }
    }
    
    // Real participant ID
    return await _getParticipantName(id);
  }

  Future<String> _resolveByString(String teamStr, Map<String, dynamic> contextMatch) async {
    // Check for placeholder patterns
    final winnerRegex = RegExp(r'Winner Match (\d+)', caseSensitive: false);
    final loserRegex = RegExp(r'Loser Match (\d+)', caseSensitive: false);
    
    var match = winnerRegex.firstMatch(teamStr);
    if (match != null) {
      int sourceMatchNum = int.parse(match.group(1)!);
      if (_matchResults.containsKey(sourceMatchNum)) {
        return _matchResults[sourceMatchNum]!['winner'] ?? teamStr;
      }
      return teamStr;
    }
    
    match = loserRegex.firstMatch(teamStr);
    if (match != null) {
      int sourceMatchNum = int.parse(match.group(1)!);
      if (_matchResults.containsKey(sourceMatchNum)) {
        return _matchResults[sourceMatchNum]!['loser'] ?? teamStr;
      }
      return teamStr;
    }
    
    // Check if it's a participant ID
    if (teamStr.length > 10 || teamStr.contains('-')) {
      return await _getParticipantName(teamStr);
    }
    
    return _cleanTeamName(teamStr);
  }

  // Process a match and store its results in cache
  Future<void> _processMatch(Map<String, dynamic> match) async {
    int matchNum = match['matchNumber'] ?? 0;
    
    Map<String, String> results = {};
    
    // Get team1 name
    if (match['team1'] != null) {
      results['team1'] = await _getActualTeamName(match['team1'], match);
    } else if (match['team1Name'] != null) {
      results['team1'] = _cleanTeamName(match['team1Name'].toString());
    } else {
      results['team1'] = 'TBD';
    }
    
    // Get team2 name
    if (match['team2'] != null) {
      results['team2'] = await _getActualTeamName(match['team2'], match);
    } else if (match['team2Name'] != null) {
      results['team2'] = _cleanTeamName(match['team2Name'].toString());
    } else {
      results['team2'] = 'TBD';
    }
    
    // Determine winner
    String winnerName = 'TBD';
    
    // Try winner field first
    if (match['winner'] != null) {
      winnerName = await _getActualTeamName(match['winner'], match);
    }
    
    // If winner is still placeholder or TBD, try from scores
    if (winnerName == 'TBD' || winnerName.contains('Winner') || winnerName.contains('Loser')) {
      final scores = match['scores'] as Map<String, dynamic>?;
      if (scores != null && scores.isNotEmpty) {
        String? winnerKey;
        int? highestScore;
        for (var entry in scores.entries) {
          int score = int.tryParse(entry.value.toString()) ?? 0;
          if (highestScore == null || score > highestScore!) {
            highestScore = score;
            winnerKey = entry.key;
          }
        }
        if (winnerKey != null) {
          winnerName = await _getActualTeamName(winnerKey, match);
        }
      }
    }
    
    // If winner is still a placeholder, try to resolve from team names
    if (winnerName.contains('Winner') || winnerName.contains('Loser')) {
      if (results['team1'] != null && !results['team1']!.contains('Winner') && !results['team1']!.contains('Loser')) {
        winnerName = results['team1']!;
      } else if (results['team2'] != null && !results['team2']!.contains('Winner') && !results['team2']!.contains('Loser')) {
        winnerName = results['team2']!;
      }
    }
    
    results['winner'] = winnerName;
    
    // Determine loser
    String loserName = 'TBD';
    if (match['loser'] != null) {
      loserName = await _getActualTeamName(match['loser'], match);
    }
    
    if (loserName == 'TBD' || loserName.contains('Winner') || loserName.contains('Loser')) {
      // Loser is the other team
      if (winnerName == results['team1']) {
        loserName = results['team2']!;
      } else if (winnerName == results['team2']) {
        loserName = results['team1']!;
      } else {
        // Try from scores
        final scores = match['scores'] as Map<String, dynamic>?;
        if (scores != null && scores.isNotEmpty) {
          String? loserKey;
          int? lowestScore;
          for (var entry in scores.entries) {
            int score = int.tryParse(entry.value.toString()) ?? 0;
            if (lowestScore == null || score < lowestScore!) {
              lowestScore = score;
              loserKey = entry.key;
            }
          }
          if (loserKey != null) {
            loserName = await _getActualTeamName(loserKey, match);
          }
        }
      }
    }
    
    results['loser'] = loserName;
    
    _matchResults[matchNum] = results;
  }

  String _cleanTeamName(String name) {
    name = name.replaceAll(RegExp(r'\s*\(Seed \d+\)\s*'), '');
    name = name.replaceAll(RegExp(r'\s*Seed \d+\s*'), '');
    return name;
  }

  String? _getTeamScore(dynamic team, Map<String, dynamic> match) {
    if (team == null) return null;

    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    
    List<String> possibleKeys = [];
    
    if (team is Map<String, dynamic>) {
      if (team['displayName'] != null) possibleKeys.add(team['displayName'].toString());
      if (team['name'] != null) possibleKeys.add(team['name'].toString());
      if (team['id'] != null) possibleKeys.add(team['id'].toString());
    } else if (team is String) {
      possibleKeys.add(team);
    }
    
    if (match['team1Name'] != null) possibleKeys.add(match['team1Name'].toString());
    if (match['team2Name'] != null) possibleKeys.add(match['team2Name'].toString());
    
    if (team == match['team1'] && match['team1Score'] != null) {
      return match['team1Score'].toString();
    }
    if (team == match['team2'] && match['team2Score'] != null) {
      return match['team2Score'].toString();
    }
    
    for (var key in possibleKeys) {
      if (key.isNotEmpty && scores.containsKey(key)) {
        return scores[key].toString();
      }
    }
    
    if (scores.isNotEmpty) {
      return scores.values.first.toString();
    }
    
    return null;
  }

  bool _isByeMatch(Map<String, dynamic> match) {
    if (match['matchType'] == 'bye') return true;
    
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

    for (var match in _matchups) {
      final round = match['round'] ?? 1;
      _rounds.putIfAbsent(round, () => []).add(match);
    }

    _rounds.forEach((round, matches) {
      matches.sort((a, b) {
        final aNum = a['matchNumber'] ?? 0;
        final bNum = b['matchNumber'] ?? 0;
        return aNum.compareTo(bNum);
      });
    });

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

      if (dateTime is DateTime) {
        parsedDate = dateTime;
      } 
      else if (dateTime is Timestamp) {
        parsedDate = dateTime.toDate();
      }
      else if (dateTime is String) {
        final String dateStr = dateTime.trim();
        if (dateStr.isEmpty) return 'TBD';

        if (dateStr.contains('/')) {
          try {
            final parts = dateStr.split(' ');
            final dateParts = parts[0].split('/');
            
            if (dateParts.length == 3) {
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
          } catch (e) {}
        }
        
        if (parsedDate == null) {
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {}
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
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.red.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _error!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadBracketData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
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

                  return Column(
                    children: [
                      FutureBuilder<Map<String, String>>(
                        future: _getMatchDisplayNames(match),
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

  Future<Map<String, String>> _getMatchDisplayNames(Map<String, dynamic> match) async {
    int matchNum = match['matchNumber'] ?? 0;
    
    String team1Name = 'TBD';
    String team2Name = 'TBD';
    String winnerName = 'TBD';
    
    // Use cached results if available
    if (_matchResults.containsKey(matchNum)) {
      team1Name = _matchResults[matchNum]!['team1'] ?? 'TBD';
      team2Name = _matchResults[matchNum]!['team2'] ?? 'TBD';
      winnerName = _matchResults[matchNum]!['winner'] ?? 'TBD';
    } else {
      // Process the match now
      await _processMatch(match);
      if (_matchResults.containsKey(matchNum)) {
        team1Name = _matchResults[matchNum]!['team1'] ?? 'TBD';
        team2Name = _matchResults[matchNum]!['team2'] ?? 'TBD';
        winnerName = _matchResults[matchNum]!['winner'] ?? 'TBD';
      }
    }
    
    // Final cleanup - ensure no placeholder text remains
    team1Name = _finalCleanName(team1Name);
    team2Name = _finalCleanName(team2Name);
    winnerName = _finalCleanName(winnerName);
    
    return {
      'team1': team1Name,
      'team2': team2Name,
      'winner': winnerName,
    };
  }

  String _finalCleanName(String name) {
    if (name.contains('Winner Match') || name.contains('Loser Match')) {
      // Try to extract the match number and resolve again
      final regex = RegExp(r'(Winner|Loser) Match (\d+)');
      final match = regex.firstMatch(name);
      if (match != null) {
        int sourceMatchNum = int.parse(match.group(2)!);
        if (_matchResults.containsKey(sourceMatchNum)) {
          if (match.group(1) == 'Winner') {
            return _matchResults[sourceMatchNum]!['winner'] ?? name;
          } else {
            return _matchResults[sourceMatchNum]!['loser'] ?? name;
          }
        }
      }
    }
    return name;
  }

  Widget _buildBracketMatchCard({
    required Map<String, dynamic> match,
    required Map<String, String> resolvedNames,
  }) {
    final matchNumber = match['matchNumber'] ?? 0;
    final bracket = match['bracket'] as String?;
    final isGrandFinal = match['isGrandFinal'] == true;
    final isBye = _isByeMatch(match);

    String team1Name = resolvedNames['team1'] ?? 'TBD';
    String team2Name = resolvedNames['team2'] ?? 'TBD';
    String winnerName = resolvedNames['winner'] ?? 'TBD';
    
    String? team1Score = _getTeamScore(match['team1'], match);
    String? team2Score = _getTeamScore(match['team2'], match);

    final hasWinner = winnerName != 'TBD' && winnerName.isNotEmpty && 
                      !winnerName.contains('Winner') && !winnerName.contains('Loser') &&
                      winnerName != 'TBD';

    Color bracketColor = Colors.blue;
    if (bracket == 'winners') {
      bracketColor = Colors.green;
    } else if (bracket == 'losers') {
      bracketColor = Colors.orange;
    } else if (bracket == 'grand' || isGrandFinal) {
      bracketColor = Colors.amber;
    }

    bool isTeam1Winner = team1Name == winnerName;
    bool isTeam2Winner = team2Name == winnerName;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(bottom: 8),
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
              color: (isGrandFinal ? Colors.amber : Colors.green).withOpacity(0.2),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: bracketColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Icon(
                  bracket == 'winners'
                      ? Icons.emoji_events
                      : (bracket == 'losers'
                          ? Icons.restore
                          : (isGrandFinal ? Icons.stadium : Icons.sports)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      bracket == 'grand' ? 'GF' : bracket[0].toUpperCase(),
                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: bracketColor),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: hasWinner ? Colors.green.shade100 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    hasWinner ? 'Done' : 'Scheduled',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: hasWinner ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),

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
                    child: Text('BYE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blue)),
                  ),
                ] else ...[
                  _buildTeamRow(
                    label: team1Name,
                    score: team1Score,
                    isWinner: isTeam1Winner,
                    isGrandFinal: isGrandFinal,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: const Text('VS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ),
                  _buildTeamRow(
                    label: team2Name,
                    score: team2Score,
                    isWinner: isTeam2Winner,
                    isGrandFinal: isGrandFinal,
                  ),
                ],

                if (match['dateTime'] != null || match['startTime'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time, size: 10, color: Colors.grey.shade600),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDateTime(match['dateTime'] ?? match['startTime']),
                              style: TextStyle(fontSize: 8, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (match['nextMatchReference'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '→ Advances to Match ${match['nextMatchReference']}',
                      style: TextStyle(fontSize: 8, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),

          if (hasWinner)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: (isGrandFinal ? Colors.amber : Colors.green).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
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
          if (score != null && score.isNotEmpty && score != '0')
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
      ),
    );
  }
}