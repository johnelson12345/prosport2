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

  void _organizeBracket() {
    _rounds = {};
    _matchConnections = {};

    if (_matchups.isEmpty) return;

    // Check if using new structured format or legacy format
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
    // Group matches by round from the structured data
    for (var match in _matchups) {
      final round = match['round'] ?? 1;
      _rounds.putIfAbsent(round, () => []).add(match);

      // Store connections from nextMatchReference
      final nextMatchRef = match['nextMatchReference'];
      final matchNumber = match['matchNumber'];
      if (nextMatchRef != null && matchNumber != null) {
        _matchConnections
            .putIfAbsent(nextMatchRef.toString(), () => [])
            .add(matchNumber);
      }
    }

    // Sort matches within each round
    _rounds.forEach((round, matches) {
      matches.sort((a, b) {
        final aNum = a['matchNumber'] ?? 0;
        final bNum = b['matchNumber'] ?? 0;
        return aNum.compareTo(bNum);
      });
    });
  }

  void _organizeLegacyFormatBracket() {
    // First, identify all matches and their relationships
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'] ?? 0;
      final teams = List<String>.from(match['teams'] ?? []);

      // Check if this is a winner match
      bool isWinnerMatch = false;
      List<int> previousMatches = [];

      for (var team in teams) {
        // Parse "Winner of Match X vs Match Y" format
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

    // Group matches by round
    Map<int, bool> isWinnerMatch = {};
    for (var match in _matchups) {
      final matchNumber = match['matchNumber'] ?? 0;
      isWinnerMatch[matchNumber] =
          _matchConnections.containsKey(matchNumber.toString());
    }

    for (var match in _matchups) {
      final matchNumber = match['matchNumber'] ?? 0;

      // Determine round
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

    // Sort matches within each round
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

    // If team is a Map (new format)
    if (team is Map<String, dynamic>) {
      return team['name'] ?? 'TBD';
    }

    // If team is a String (old format)
    if (team is String) {
      return team;
    }

    return 'TBD';
  }

  String _getTeamId(dynamic team) {
    if (team == null) return '';
    if (team is Map<String, dynamic>) {
      return team['id'] ?? '';
    }
    if (team is String) {
      return team;
    }
    return '';
  }

  bool _isByeMatch(Map<String, dynamic> match) {
    // Check new format
    if (match['matchType'] == 'bye') return true;

    // Check old format
    final teams = match['teams'] as List? ?? [];
    return teams.contains('BYE');
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null || dateTime == '') return 'TBD';

    try {
      DateTime? parsedDate;

      if (dateTime is DateTime) {
        parsedDate = dateTime;
      } else if (dateTime is String) {
        final String dateStr = dateTime.trim();

        if (dateStr.isEmpty) return 'TBD';

        // Try parsing as day/month/year format first
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
                  var hour = int.tryParse(timeParts[0]) ?? 0;
                  var minute = int.tryParse(timeParts[1]) ?? 0;

                  if (parts.length > 2 && parts[2].toUpperCase() == 'PM') {
                    if (hour != 12) hour += 12;
                  } else if (parts.length > 2 &&
                      parts[2].toUpperCase() == 'AM') {
                    if (hour == 12) hour = 0;
                  }

                  parsedDate = DateTime(year, month, day, hour, minute);
                } else {
                  parsedDate = DateTime(year, month, day);
                }
              } else {
                parsedDate = DateTime(year, month, day);
              }
            }
          }
        } catch (e) {
          // If day/month/year parsing fails, try other formats
        }

        if (parsedDate == null) {
          try {
            parsedDate = DateTime.parse(dateStr);
          } catch (e) {
            try {
              if (int.tryParse(dateStr) != null) {
                final timestamp = int.parse(dateStr);
                parsedDate = timestamp > 1000000000000
                    ? DateTime.fromMillisecondsSinceEpoch(timestamp)
                    : DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
              } else {
                final formats = [
                  'dd/MM/yyyy HH:mm',
                  'dd/MM/yyyy',
                  'dd/MM/yyyy hh:mm a',
                  'd/M/yyyy HH:mm',
                  'd/M/yyyy',
                  'yyyy-MM-dd HH:mm:ss',
                  'yyyy-MM-ddTHH:mm:ss',
                  'MM/dd/yyyy HH:mm',
                  'dd-MM-yyyy HH:mm',
                  'dd-MM-yyyy',
                ];

                for (final format in formats) {
                  try {
                    parsedDate = DateFormat(format).parse(dateStr);
                    break;
                  } catch (_) {
                    continue;
                  }
                }
              }
            } catch (e2) {
              return 'Invalid Date';
            }
          }
        }
      } else if (dateTime is int) {
        parsedDate = dateTime > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(dateTime)
            : DateTime.fromMillisecondsSinceEpoch(dateTime * 1000);
      } else {
        return 'TBD';
      }

      if (parsedDate == null) {
        return 'TBD';
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final matchDate =
          DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

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
      print('Date parsing error: $e');
      return 'TBD';
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
            // Dialog Header
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

            // Content
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
    // Round names
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
          // Round Header
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

          // Scrollable matches area
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
    // Get team data (handles both formats)
    dynamic team1Data;
    dynamic team2Data;
    List<String> legacyTeams = [];

    if (match.containsKey('team1') && match.containsKey('team2')) {
      // New format
      team1Data = match['team1'];
      team2Data = match['team2'];
    } else {
      // Legacy format
      legacyTeams = List<String>.from(match['teams'] ?? []);
    }

    final winner = match['winner'];
    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    final hasWinner = winner != null;
    final matchNumber = match['matchNumber'] ?? matchIndex + 1;
    final matchType = match['matchType'] ?? 'regular';
    final bracket = match['bracket'] as String?;
    final isBye = matchType == 'bye';

    // Check for date fields
    dynamic dateValue = match['dateTime'] ??
        match['startTime'] ??
        match['startDate'] ??
        match['date'];
    dynamic endDateValue = match['endTime'] ?? match['endDate'];

    // Determine if this is a winner match
    bool isWinnerMatch = prevMatches != null && prevMatches.length == 2;

    // Get team names
    String team1Name = 'TBD';
    String team2Name = 'TBD';
    String team1Id = '';
    String team2Id = '';

    if (team1Data != null) {
      team1Name = _getTeamName(team1Data);
      team1Id = _getTeamId(team1Data);
    } else if (legacyTeams.isNotEmpty) {
      team1Name = legacyTeams[0];
    }

    if (team2Data != null) {
      team2Name = _getTeamName(team2Data);
      team2Id = _getTeamId(team2Data);
    } else if (legacyTeams.length > 1) {
      team2Name = legacyTeams[1];
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: matchIndex < totalMatches - 1 ? 24 : 0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Connecting lines from previous matches
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

          // Main match card
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
                // Match header - ALWAYS SHOW MATCH NUMBER
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
                      // ALWAYS SHOW MATCH NUMBER HERE
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
                      // Optional bracket type indicator (can be removed or kept)
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

                // Match content
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      if (isBye) ...[
                        _buildTeamRow(
                          label: team1Name,
                          score: scores[team1Name]?.toString() ??
                              scores[team1Id]?.toString(),
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
                        // Team 1
                        _buildTeamRow(
                          label: team1Name,
                          score: scores[team1Name]?.toString() ??
                              scores[team1Id]?.toString(),
                          isWinner: winner == team1Id || winner == team1Name,
                          isLastRound: isLastRound,
                        ),

                        // VS
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

                        // Team 2
                        _buildTeamRow(
                          label: team2Name,
                          score: scores[team2Name]?.toString() ??
                              scores[team2Id]?.toString(),
                          isWinner: winner == team2Id || winner == team2Name,
                          isLastRound: isLastRound,
                        ),
                      ],

                      // Date/Time
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

                // Winner ribbon
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
                            'Winner: ${_formatTeamName(winner)}',
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
              label.length > 15 ? '${label.substring(0, 12)}...' : label,
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
    return teamString.length > 15
        ? '${teamString.substring(0, 15)}...'
        : teamString;
  }

  String _formatTeamName(dynamic name) {
    if (name == null) return 'TBD';

    if (name is Map<String, dynamic>) {
      return name['name'] ?? 'TBD';
    }

    if (name is String) {
      if (name.contains('Winner of') || name.contains('Loser of')) {
        final regex = RegExp(r'Winner of Match (\d+) vs Match (\d+)');
        final match = regex.firstMatch(name);
        if (match != null) {
          return 'Winner M${match.group(1)}/M${match.group(2)}';
        }
        return 'Winner Match';
      }
      return name.length > 15 ? '${name.substring(0, 15)}...' : name;
    }

    return 'TBD';
  }
}

// Custom painter for drawing connecting lines
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
