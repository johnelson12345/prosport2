import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/participants_service.dart';
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
  final ParticipantsService _participantsService = ParticipantsService();
  List<Map<String, dynamic>> _matchups = [];
  bool _isLoading = true;

  // Cache for team/participant information
  late Map<String, Map<String, dynamic>> _participantCache;
  // Cache for winner information to propagate to subsequent matches
  late Map<int, Map<String, dynamic>> _winnerCache;
  // Cache for match results to help with score lookups
  late Map<int, Map<String, dynamic>> _matchResultsCache;
  // Map to store resolved team names for placeholder IDs
  late Map<String, String> _resolvedTeamNames;

  // Bracket structure
  late Map<int, List<Map<String, dynamic>>> _rounds;
  late Map<String, List<int>> _matchConnections;

  @override
  void initState() {
    super.initState();
    _participantCache = {};
    _winnerCache = {};
    _matchResultsCache = {};
    _resolvedTeamNames = {};
    _loadBracketData();
  }

  Future<void> _loadBracketData() async {
    try {
      // Load all participants first
      await _loadAllParticipants();

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
        _buildMatchResultsCache();
        _organizeBracket();
        _propagateWinners();
        _resolveAllPlaceholderNames();
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

  Future<void> _loadAllParticipants() async {
    try {
      final participantsStream = _participantsService.getParticipantsStream();
      final snapshot = await participantsStream.first;

      if (snapshot.docs.isNotEmpty) {
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String participantId = doc.id;

          // Get the best available name
          String participantName = data['name'] ?? '';
          if (participantName.isEmpty) {
            participantName = data['teamName'] ?? '';
          }
          if (participantName.isEmpty) {
            participantName = data['coachName'] ?? '';
          }
          if (participantName.isEmpty) {
            participantName = 'Team ${participantId.substring(0, 4)}';
          }

          // Store by ID
          _participantCache[participantId] = {
            'id': participantId,
            'name': participantName,
            'coachName': data['coachName'] ?? '',
            'contactInfo': data['contactInfo'] ?? '',
          };

          // Store by name for lookups
          if (participantName.isNotEmpty) {
            _participantCache[participantName] = {
              'id': participantId,
              'name': participantName,
              'coachName': data['coachName'] ?? '',
              'contactInfo': data['contactInfo'] ?? '',
            };
          }
        }
      }
    } catch (e) {
      print('Error loading participants: $e');
    }
  }

  void _buildMatchResultsCache() {
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'];
      if (matchNumber == null) continue;

      Map<String, dynamic> scores = {};
      if (match['scores'] != null && match['scores'] is Map) {
        scores.addAll(Map<String, dynamic>.from(match['scores']));
      }

      String team1Id = _getTeamId(match['team1']);
      String team2Id = _getTeamId(match['team2']);
      String team1Name = _getTeamName(match['team1']);
      String team2Name = _getTeamName(match['team2']);

      _matchResultsCache[matchNumber] = {
        'winner': match['winner'],
        'winnerId': _getTeamId(match['winner']),
        'winnerName': _getTeamName(match['winner']),
        'scores': scores,
        'team1': match['team1'],
        'team2': match['team2'],
        'team1Id': team1Id,
        'team2Id': team2Id,
        'team1Name': team1Name,
        'team2Name': team2Name,
        'team1Score': match['team1Score'],
        'team2Score': match['team2Score'],
      };
    }
  }

  void _resolveAllPlaceholderNames() {
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'];
      if (matchNumber == null) continue;

      if (match.containsKey('team1') && match['team1'] is Map) {
        final team1 = match['team1'] as Map;
        if (team1['type'] == 'placeholder' && team1['sourceMatch'] != null) {
          final sourceMatch = team1['sourceMatch'];
          if (_winnerCache.containsKey(sourceMatch)) {
            _resolvedTeamNames[team1['id']] = _winnerCache[sourceMatch]!['name'];
          }
        }
      }

      if (match.containsKey('team2') && match['team2'] is Map) {
        final team2 = match['team2'] as Map;
        if (team2['type'] == 'placeholder' && team2['sourceMatch'] != null) {
          final sourceMatch = team2['sourceMatch'];
          if (_winnerCache.containsKey(sourceMatch)) {
            _resolvedTeamNames[team2['id']] = _winnerCache[sourceMatch]!['name'];
          }
        }
      }
    }
  }

  void _propagateWinners() {
    // First, cache all winners from matches that have them
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'];
      final winner = match['winner'];

      if (matchNumber != null && winner != null) {
        String winnerName = _resolveParticipantName(winner);
        String winnerId = _resolveParticipantId(winner);

        // Try to get better winner name from match data
        if (winnerName == winnerId || winnerName == 'Unknown Team' || winnerName == 'TBD') {
          // Check if winner matches team1
          if (match['team1'] != null) {
            String team1Id = _getTeamId(match['team1']);
            if (team1Id == winnerId) {
              String team1Name = _getTeamName(match['team1']);
              if (team1Name != 'TBD' && !team1Name.contains('Unknown')) {
                winnerName = team1Name;
              }
            }
          }

          // Check if winner matches team2
          if (match['team2'] != null && winnerName == winnerId) {
            String team2Id = _getTeamId(match['team2']);
            if (team2Id == winnerId) {
              String team2Name = _getTeamName(match['team2']);
              if (team2Name != 'TBD' && !team2Name.contains('Unknown')) {
                winnerName = team2Name;
              }
            }
          }
        }

        _winnerCache[matchNumber] = {
          'id': winnerId,
          'name': winnerName,
          'originalMatch': matchNumber,
        };
      }
    }

    // Update matchups with winner references
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'];
      if (matchNumber == null) continue;

      if (match.containsKey('team1') && match.containsKey('team2')) {
        dynamic team1 = match['team1'];
        dynamic team2 = match['team2'];

        // Handle team1
        if (_isWinnerReference(team1)) {
          final referencedMatch = _extractMatchNumberFromReference(team1);
          if (referencedMatch != null && _winnerCache.containsKey(referencedMatch)) {
            match['team1'] = _winnerCache[referencedMatch]!;
          }
        } else if (team1 is Map && team1['type'] == 'placeholder' && team1['sourceMatch'] != null) {
          final sourceMatch = team1['sourceMatch'];
          if (_winnerCache.containsKey(sourceMatch)) {
            team1['resolvedName'] = _winnerCache[sourceMatch]!['name'];
            team1['resolvedId'] = _winnerCache[sourceMatch]!['id'];
          }
        }

        // Handle team2
        if (_isWinnerReference(team2)) {
          final referencedMatch = _extractMatchNumberFromReference(team2);
          if (referencedMatch != null && _winnerCache.containsKey(referencedMatch)) {
            match['team2'] = _winnerCache[referencedMatch]!;
          }
        } else if (team2 is Map && team2['type'] == 'placeholder' && team2['sourceMatch'] != null) {
          final sourceMatch = team2['sourceMatch'];
          if (_winnerCache.containsKey(sourceMatch)) {
            team2['resolvedName'] = _winnerCache[sourceMatch]!['name'];
            team2['resolvedId'] = _winnerCache[sourceMatch]!['id'];
          }
        }
      }

      // Update winner field
      if (match.containsKey('winner') && match['winner'] != null) {
        String resolvedWinnerName = _resolveParticipantName(match['winner']);
        if (resolvedWinnerName != match['winner'].toString()) {
          match['winnerName'] = resolvedWinnerName;
        }
      }
    }
  }

  String _resolveParticipantName(dynamic participantData) {
    if (participantData == null) return 'TBD';

    if (participantData is Map<String, dynamic>) {
      if (participantData.containsKey('name') && participantData['name'] != null) {
        return participantData['name'].toString();
      }
      if (participantData.containsKey('resolvedName') && participantData['resolvedName'] != null) {
        return participantData['resolvedName'].toString();
      }
      if (participantData.containsKey('coachName') && participantData['coachName'] != null) {
        return participantData['coachName'].toString();
      }

      if (participantData.containsKey('id')) {
        final String id = participantData['id'].toString();
        if (_participantCache.containsKey(id)) {
          return _participantCache[id]!['name'];
        }
        if (_resolvedTeamNames.containsKey(id)) {
          return _resolvedTeamNames[id]!;
        }
      }

      return 'Unknown Participant';
    }

    if (participantData is String) {
      if (participantData.contains('Winner of') || participantData.contains('Loser of')) {
        return participantData;
      }

      if (participantData.contains('match_') && participantData.contains('winner')) {
        final matchRegex = RegExp(r'match_(\d+)_winner');
        final match = matchRegex.firstMatch(participantData);
        if (match != null) {
          final matchNum = int.parse(match.group(1)!);
          if (_winnerCache.containsKey(matchNum)) {
            return _winnerCache[matchNum]!['name'];
          }
        }
        return 'TBD (Waiting)';
      }

      if (_participantCache.containsKey(participantData)) {
        return _participantCache[participantData]!['name'];
      }

      return participantData;
    }

    if (participantData is int || participantData is double) {
      final String idStr = participantData.toString();
      if (_participantCache.containsKey(idStr)) {
        return _participantCache[idStr]!['name'];
      }
    }

    return 'TBD';
  }

  String _resolveParticipantId(dynamic participantData) {
    if (participantData == null) return '';

    if (participantData is Map<String, dynamic>) {
      if (participantData.containsKey('id')) {
        return participantData['id'].toString();
      }
      if (participantData.containsKey('resolvedId')) {
        return participantData['resolvedId'].toString();
      }
    }

    if (participantData is String) {
      return participantData;
    }

    return participantData.toString();
  }

  bool _isWinnerReference(dynamic team) {
    if (team == null) return false;

    String teamStr;
    if (team is Map<String, dynamic>) {
      teamStr = team['name'] ?? '';
    } else if (team is String) {
      teamStr = team;
    } else {
      return false;
    }

    return teamStr.contains('Winner of') ||
        teamStr.contains('Winner Match') ||
        teamStr.contains('Winners of');
  }

  int? _extractMatchNumberFromReference(dynamic team) {
    if (team == null) return null;

    String teamStr;
    if (team is Map<String, dynamic>) {
      teamStr = team['name'] ?? '';
    } else if (team is String) {
      teamStr = team;
    } else {
      return null;
    }

    final regex = RegExp(r'Winner of Match (\d+) vs Match (\d+)');
    final match = regex.firstMatch(teamStr);
    if (match != null) {
      return int.parse(match.group(1)!);
    }

    final simpleRegex = RegExp(r'Match (\d+)');
    final simpleMatch = simpleRegex.firstMatch(teamStr);
    if (simpleMatch != null) {
      return int.parse(simpleMatch.group(1)!);
    }

    final placeholderRegex = RegExp(r'match_(\d+)_winner');
    final placeholderMatch = placeholderRegex.firstMatch(teamStr);
    if (placeholderMatch != null) {
      return int.parse(placeholderMatch.group(1)!);
    }

    return null;
  }

  void _organizeBracket() {
    _rounds = {};
    _matchConnections = {};

    if (_matchups.isEmpty) return;

    final sampleMatch = _matchups.first;
    final bool isNewFormat =
        sampleMatch.containsKey('team1') && sampleMatch.containsKey('team2');

    if (isNewFormat) {
      _organizeNewFormatBracket();
    } else {
      _organizeLegacyFormatBracket();
    }
  }

  void _organizeNewFormatBracket() {
    for (var match in _matchups) {
      final round = match['round'] ?? 1;
      _rounds.putIfAbsent(round, () => []).add(match);

      final nextMatchRef = match['nextMatchReference'];
      final matchNumber = match['matchNumber'];
      if (nextMatchRef != null && matchNumber != null) {
        _matchConnections
            .putIfAbsent(nextMatchRef.toString(), () => [])
            .add(matchNumber);
      }
    }

    _rounds.forEach((round, matches) {
      matches.sort((a, b) {
        final aNum = a['matchNumber'] ?? 0;
        final bNum = b['matchNumber'] ?? 0;
        return aNum.compareTo(bNum);
      });
    });
  }

  void _organizeLegacyFormatBracket() {
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'] ?? 0;
      final teams = List<String>.from(match['teams'] ?? []);

      bool isWinnerMatch = false;
      List<int> previousMatches = [];

      for (var team in teams) {
        final regex = RegExp(r'Winner of Match (\d+) vs Match (\d+)');
        final match2 = regex.firstMatch(team);
        if (match2 != null) {
          isWinnerMatch = true;
          previousMatches.add(int.parse(match2.group(1)!));
          previousMatches.add(int.parse(match2.group(2)!));
        }
      }

      if (isWinnerMatch && previousMatches.length == 2) {
        _matchConnections[matchNumber.toString()] = previousMatches;
      }
    }

    Map<int, bool> isWinnerMatch = {};
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'] ?? 0;
      isWinnerMatch[matchNumber] =
          _matchConnections.containsKey(matchNumber.toString());
    }

    for (var match in _matchups) {
      final matchNumber = match['matchNumber'] ?? 0;

      int round = 1;
      if (isWinnerMatch[matchNumber] == true) {
        final prevMatches = _matchConnections[matchNumber.toString()];
        if (prevMatches != null && prevMatches.isNotEmpty) {
          bool prevAreWinnerMatches =
              prevMatches.every((pm) => isWinnerMatch[pm] == true);
          if (prevAreWinnerMatches) {
            round = 3;
          } else {
            round = 2;
          }
        }
      }

      _rounds.putIfAbsent(round, () => []).add(match);
    }

    _rounds.forEach((round, matches) {
      matches.sort((a, b) {
        final aNum = a['matchNumber'] ?? 0;
        final bNum = b['matchNumber'] ?? 0;
        return aNum.compareTo(bNum);
      });
    });
  }

  String _getTeamName(dynamic team) {
    if (team == null) return 'TBD';

    if (team is Map<String, dynamic>) {
      if (team.containsKey('name') && team['name'] != null) {
        if (team['name'].toString().contains('Winner') && team.containsKey('sourceMatch')) {
          final sourceMatch = team['sourceMatch'];
          if (_winnerCache.containsKey(sourceMatch)) {
            return _winnerCache[sourceMatch]!['name'];
          }
        }
        return team['name'].toString();
      }
      if (team.containsKey('resolvedName') && team['resolvedName'] != null) {
        return team['resolvedName'].toString();
      }
      if (team.containsKey('coachName') && team['coachName'] != null) {
        return team['coachName'].toString();
      }
      if (team.containsKey('id')) {
        final String id = team['id'].toString();
        if (_participantCache.containsKey(id)) {
          return _participantCache[id]!['name'];
        }
        if (_resolvedTeamNames.containsKey(id)) {
          return _resolvedTeamNames[id]!;
        }
      }
      return 'Unknown Team';
    }

    if (team is String) {
      if (team.contains('Winner of') || team.contains('Loser of')) {
        return 'TBD (Waiting)';
      }
      return _resolveParticipantName(team);
    }

    return 'TBD';
  }

  String _getTeamId(dynamic team) {
    return _resolveParticipantId(team);
  }

  String? _getTeamScore(dynamic team, Map<String, dynamic> match, int matchNumber) {
    if (team == null) return null;

    // First check match results cache
    if (_matchResultsCache.containsKey(matchNumber)) {
      final cachedMatch = _matchResultsCache[matchNumber]!;
      final teamId = _getTeamId(team);
      final teamName = _getTeamName(team);

      if (cachedMatch['team1Id'] == teamId || cachedMatch['team1Name'] == teamName) {
        if (cachedMatch['team1Score'] != null) {
          return cachedMatch['team1Score'].toString();
        }
      }
      if (cachedMatch['team2Id'] == teamId || cachedMatch['team2Name'] == teamName) {
        if (cachedMatch['team2Score'] != null) {
          return cachedMatch['team2Score'].toString();
        }
      }
    }

    // Check scores map
    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    final teamId = _getTeamId(team);
    final teamName = _getTeamName(team);

    // Try various score lookup methods
    if (teamId.isNotEmpty && scores.containsKey(teamId)) {
      return scores[teamId].toString();
    }

    if (teamName != 'TBD' && scores.containsKey(teamName)) {
      return scores[teamName].toString();
    }

    // Check direct score fields
    if (match.containsKey('team1Score') && 
        (teamId == _getTeamId(match['team1']) || teamName == _getTeamName(match['team1']))) {
      return match['team1Score'].toString();
    }

    if (match.containsKey('team2Score') && 
        (teamId == _getTeamId(match['team2']) || teamName == _getTeamName(match['team2']))) {
      return match['team2Score'].toString();
    }

    // Check for placeholder keys
    if (team is Map && team['id'] != null) {
      final placeholderId = team['id'].toString();
      if (scores.containsKey(placeholderId)) {
        return scores[placeholderId].toString();
      }
    }

    // Check for winner reference in scores
    if (teamName.contains('Winner') && teamName.contains('Match')) {
      final matchRegex = RegExp(r'Match (\d+)');
      final matchMatch = matchRegex.firstMatch(teamName);
      if (matchMatch != null) {
        final sourceMatch = int.parse(matchMatch.group(1)!);
        final possibleKeys = [
          'match_${sourceMatch}_winner',
          'winner_$sourceMatch',
          'match${sourceMatch}Winner',
        ];

        for (var key in possibleKeys) {
          if (scores.containsKey(key)) {
            return scores[key].toString();
          }
        }
      }
    }

    return null;
  }

  bool _isByeMatch(Map<String, dynamic> match) {
    if (match['matchType'] == 'bye') return true;
    final teams = match['teams'] as List? ?? [];
    return teams.contains('BYE');
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

      // Try parsing common formats
      
      // Format: "15/2/2026 12:00" (dd/M/yyyy HH:mm)
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
                // Has time component
                final timeParts = parts[1].split(':');
                if (timeParts.length >= 2) {
                  final hour = int.tryParse(timeParts[0]) ?? 0;
                  final minute = int.tryParse(timeParts[1]) ?? 0;
                  parsedDate = DateTime(year, month, day, hour, minute);
                }
              } else {
                // Date only
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
          // Continue to next format
        }
      }
      
      // Try format: "2026-03-11T12:22:24.708"
      if (parsedDate == null && dateStr.contains('T')) {
        try {
          parsedDate = DateTime.parse(dateStr);
        } catch (e) {
          // Continue
        }
      }
      
      // Try timestamp string
      if (parsedDate == null) {
        final timestamp = int.tryParse(dateStr);
        if (timestamp != null) {
          parsedDate = timestamp > 1000000000000
              ? DateTime.fromMillisecondsSinceEpoch(timestamp)
              : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        }
      }
    } 
    else if (dateTime is int) {
      // Handle timestamp
      parsedDate = dateTime > 1000000000000
          ? DateTime.fromMillisecondsSinceEpoch(dateTime)
          : DateTime.fromMillisecondsSinceEpoch(dateTime * 1000);
    }

    if (parsedDate == null) {
      print('Could not parse date: $dateTime');
      return 'TBD';
    }

    // Format the date for display
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
      // Format as "MMM dd, yyyy" (e.g., "Feb 15, 2026")
      dateStr = DateFormat('MMM dd, yyyy').format(parsedDate);
    }

    // Check if time is set (not midnight)
    if (parsedDate.hour == 0 && parsedDate.minute == 0) {
      return dateStr;
    }

    // Format time as "h:mm a" (e.g., "12:00 PM")
    final timeStr = DateFormat('h:mm a').format(parsedDate);
    return '$dateStr at $timeStr';
    
  } catch (e) {
    print('Date parsing error: $e for value: $dateTime');
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
    if (isLastRound) {
      roundName = 'CHAMPIONSHIP';
    } else if (roundIndex == totalRounds - 2) {
      roundName = 'SEMIFINALS';
    } else if (roundIndex == totalRounds - 3) {
      roundName = 'QUARTERFINALS';
    } else {
      roundName = 'ROUND $round';
    }

    return Container(
      width: 280,
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
                colors: isLastRound
                    ? [Colors.amber.shade700, Colors.orange.shade700]
                    : roundName == 'SEMIFINALS'
                        ? [Colors.blue.shade700, Colors.purple.shade700]
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
                      _buildBracketMatchCard(
                        match: match,
                        roundIndex: roundIndex,
                        matchIndex: index,
                        totalMatches: matches.length,
                        isLastRound: isLastRound,
                        prevMatches: prevMatches,
                      ),
                      if (index < matches.length - 1)
                        _buildConnectorLine(
                          height: 40,
                          isLastRound: isLastRound,
                        ),
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

  Widget _buildBracketMatchCard({
    required Map<String, dynamic> match,
    required int roundIndex,
    required int matchIndex,
    required int totalMatches,
    required bool isLastRound,
    List<int>? prevMatches,
  }) {
    dynamic team1Data;
    dynamic team2Data;
    List<String> legacyTeams = [];

    if (match.containsKey('team1') && match.containsKey('team2')) {
      team1Data = match['team1'];
      team2Data = match['team2'];
    } else {
      legacyTeams = List<String>.from(match['teams'] ?? []);
    }

    final winner = match['winner'];
    final winnerName = match['winnerName'];
    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    final hasWinner = winner != null;
    final matchNumber = match['matchNumber'] ?? matchIndex + 1;
    final matchType = match['matchType'] ?? 'regular';
    final bracket = match['bracket'] as String?;
    final isBye = matchType == 'bye';

    dynamic dateValue = match['dateTime'] ??
        match['startTime'] ??
        match['startDate'] ??
        match['date'];
    dynamic endDateValue = match['endTime'] ?? match['endDate'];

    bool isWinnerMatch = prevMatches != null && prevMatches.length == 2;

    String team1Name = 'TBD';
    String team2Name = 'TBD';
    String team1Id = '';
    String team2Id = '';
    String? team1Score;
    String? team2Score;

    if (team1Data != null) {
      team1Name = _getTeamName(team1Data);
      team1Id = _getTeamId(team1Data);
      team1Score = _getTeamScore(team1Data, match, matchNumber);

      if (isLastRound && hasWinner) {
        bool isTeam1Winner = false;
        if (winner is Map) {
          isTeam1Winner = _getTeamId(winner) == team1Id;
        } else {
          isTeam1Winner = winner == team1Id || winner == team1Name;
        }

        if (isTeam1Winner) {
          team1Name = '🏆 $team1Name';
        }
      }
    } else if (legacyTeams.isNotEmpty) {
      team1Name = _resolveParticipantName(legacyTeams[0]);
      if (isLastRound && hasWinner && winner == legacyTeams[0]) {
        team1Name = '🏆 $team1Name';
      }
    }

    if (team2Data != null) {
      team2Name = _getTeamName(team2Data);
      team2Id = _getTeamId(team2Data);
      team2Score = _getTeamScore(team2Data, match, matchNumber);

      if (isLastRound && hasWinner) {
        bool isTeam2Winner = false;
        if (winner is Map) {
          isTeam2Winner = _getTeamId(winner) == team2Id;
        } else {
          isTeam2Winner = winner == team2Id || winner == team2Name;
        }

        if (isTeam2Winner) {
          team2Name = '🏆 $team2Name';
        }
      }
    } else if (legacyTeams.length > 1) {
      team2Name = _resolveParticipantName(legacyTeams[1]);
      if (isLastRound && hasWinner && winner == legacyTeams[1]) {
        team2Name = '🏆 $team2Name';
      }
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: matchIndex < totalMatches - 1 ? 24 : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isWinnerMatch && prevMatches != null)
            Positioned(
              left: -25,
              top: 30,
              child: _buildWinnerMatchConnector(
                matchNumber: matchNumber,
                prevMatch1: prevMatches[0],
                prevMatch2: prevMatches[1],
                isWinner: hasWinner,
              ),
            ),

          Container(
            width: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasWinner
                    ? (isLastRound
                        ? Colors.amber.shade400
                        : Colors.green.shade400)
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
                    color: (isLastRound ? Colors.amber : Colors.green)
                        .withOpacity(0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: bracket == 'winners'
                        ? Colors.green.shade50
                        : (bracket == 'losers'
                            ? Colors.orange.shade50
                            : (isWinnerMatch
                                ? Colors.amber.shade50
                                : Colors.blue.shade50)),
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
                                : (isWinnerMatch
                                    ? Icons.emoji_events
                                    : Icons.sports)),
                        size: 12,
                        color: bracket == 'winners'
                            ? Colors.green.shade700
                            : (bracket == 'losers'
                                ? Colors.orange.shade700
                                : (isWinnerMatch
                                    ? Colors.amber.shade700
                                    : Colors.blue.shade700)),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Match $matchNumber',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            color: bracket == 'winners'
                                ? Colors.green.shade700
                                : (bracket == 'losers'
                                    ? Colors.orange.shade700
                                    : (isWinnerMatch
                                        ? Colors.amber.shade700
                                        : Colors.blue.shade700)),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (bracket != null || isWinnerMatch)
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
                            bracket != null
                                ? bracket.substring(0, 1).toUpperCase()
                                : (isWinnerMatch ? 'W' : ''),
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                              color: bracket == 'winners'
                                  ? Colors.green.shade700
                                  : (bracket == 'losers'
                                      ? Colors.orange.shade700
                                      : (isWinnerMatch
                                          ? Colors.amber.shade700
                                          : Colors.blue.shade700)),
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
                          hasWinner ? 'Done' : 'Pending',
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

                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      if (isBye) ...[
                        _buildTeamRow(
                          label: team1Name,
                          score: team1Score,
                          isWinner: true,
                          isLastRound: isLastRound,
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
                          isWinner: winner == team1Id || winner == team1Name ||
                              (winner is Map && _getTeamId(winner) == team1Id),
                          isLastRound: isLastRound,
                        ),

                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: const Text(
                            'VS',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        _buildTeamRow(
                          label: team2Name,
                          score: team2Score,
                          isWinner: winner == team2Id || winner == team2Name ||
                              (winner is Map && _getTeamId(winner) == team2Id),
                          isLastRound: isLastRound,
                        ),
                      ],

                      if (dateValue != null) ...[
                        const SizedBox(height: 10),
                        Container(
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
                                  _formatDateTime(dateValue),
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (endDateValue != null) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 1,
                                  height: 8,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'End: ${_formatDateTime(endDateValue)}',
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
                            ],
                          ),
                        ),
                      ],

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

                if (hasWinner)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isLastRound
                          ? Colors.amber.shade100
                          : Colors.green.shade100,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(11),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isLastRound ? Icons.emoji_events : Icons.star,
                          size: 10,
                          color: isLastRound
                              ? Colors.amber.shade700
                              : Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Winner: ${winnerName ?? _formatTeamName(winner)}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isLastRound
                                  ? Colors.amber.shade700
                                  : Colors.green.shade700,
                            ),
                            overflow: TextOverflow.ellipsis,
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

  Widget _buildTeamRow({
    required String label,
    String? score,
    required bool isWinner,
    required bool isLastRound,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isWinner
            ? (isLastRound ? Colors.amber.shade50 : Colors.green.shade50)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWinner
              ? (isLastRound ? Colors.amber.shade200 : Colors.green.shade200)
              : Colors.grey.shade200,
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                color: isWinner
                    ? (isLastRound
                        ? Colors.amber.shade700
                        : Colors.green.shade700)
                    : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (score != null && score.isNotEmpty) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isWinner
                    ? (isLastRound
                        ? Colors.amber.shade100
                        : Colors.green.shade100)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                score,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isWinner
                      ? (isLastRound
                          ? Colors.amber.shade700
                          : Colors.green.shade700)
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectorLine({
    required double height,
    required bool isLastRound,
  }) {
    return SizedBox(
      height: height,
      child: Center(
        child: CustomPaint(
          painter: ConnectorLinePainter(
            color: isLastRound ? Colors.amber.shade300 : Colors.blue.shade300,
          ),
          size: const Size(20, 20),
        ),
      ),
    );
  }

  Widget _buildWinnerMatchConnector({
    required int matchNumber,
    required int prevMatch1,
    required int prevMatch2,
    required bool isWinner,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isWinner ? Colors.green.shade400 : Colors.grey.shade400,
                width: 1.5,
              ),
              bottom: BorderSide(
                color: isWinner ? Colors.green.shade400 : Colors.grey.shade400,
                width: 1.5,
              ),
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: isWinner ? Colors.green.shade400 : Colors.grey.shade400,
                width: 1.5,
              ),
              top: BorderSide(
                color: isWinner ? Colors.green.shade400 : Colors.grey.shade400,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _extractTeamName(String teamString) {
    if (teamString.contains('Winner of') || teamString.contains('Loser of')) {
      final regex = RegExp(r'Winner of Match (\d+) vs Match (\d+)');
      final match = regex.firstMatch(teamString);
      if (match != null) {
        return 'W${match.group(1)}/W${match.group(2)}';
      }
      return 'Winner Match';
    }

    String resolved = _resolveParticipantName(teamString);
    return resolved.length > 15 ? '${resolved.substring(0, 15)}...' : resolved;
  }

  String _formatTeamName(dynamic name) {
    return _resolveParticipantName(name);
  }
}

class ConnectorLinePainter extends CustomPainter {
  final Color color;

  ConnectorLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width / 2, size.height / 2);
    path.lineTo(size.width, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}