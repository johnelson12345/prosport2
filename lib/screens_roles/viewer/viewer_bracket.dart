import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ViewerBracketWidget extends StatefulWidget {
  final List<Map<String, dynamic>> matchups;
  final Map<String, String> teamNamesById;
  final void Function(Map<String, dynamic> matchup)? onMatchupTap;
  final String tournamentName;

  const ViewerBracketWidget({
    super.key,
    required this.matchups,
    required this.teamNamesById,
    this.onMatchupTap,
    required this.tournamentName,
  });

  @override
  _ViewerBracketWidgetState createState() => _ViewerBracketWidgetState();
}

class _ViewerBracketWidgetState extends State<ViewerBracketWidget> {
  String _getTeamName(String teamId) {
    return widget.teamNamesById[teamId] ?? teamId;
  }

  String _resolveWinnerFromString(
      String winnerStr, List<Map<String, dynamic>> matchups) {
    if (widget.teamNamesById.containsKey(winnerStr)) {
      return widget.teamNamesById[winnerStr]!;
    }
    if (winnerStr.startsWith("Winner of ")) {
      String teamsStr = winnerStr.substring("Winner of ".length);
      List<String> parts = teamsStr.split(" vs ");
      if (parts.length == 2) {
        String teamA = parts[0].trim();
        String teamB = parts[1].trim();
        for (var matchup in matchups) {
          if (matchup['teams'].length == 2) {
            String mTeamA = _getTeamName(matchup['teams'][0]);
            String mTeamB = _getTeamName(matchup['teams'][1]);
            if ((mTeamA == teamA && mTeamB == teamB) ||
                (mTeamA == teamB && mTeamB == teamA)) {
              String nestedWinner = matchup['winner'];
              if (nestedWinner.isNotEmpty && nestedWinner != winnerStr) {
                return _resolveWinnerFromString(nestedWinner, matchups);
              } else {
                return winnerStr;
              }
            }
          }
        }
      }
    }
    return winnerStr;
  }

  Widget _buildMatchupCard(Map<String, dynamic> matchup, bool isFinalMatch) {
    final teams = matchup['teams'];
    final winner = matchup['winner'];
    final scores = matchup['scores'] as Map<String, dynamic>?;

    String displayText = '';
    if (teams.length == 2) {
      String teamAName = _getTeamName(teams[0]);
      String teamBName = _getTeamName(teams[1]);
      String teamAScore = '';
      String teamBScore = '';
      if (scores != null && scores.isNotEmpty && winner.isNotEmpty) {
        // Try team ID keys first, then team name keys
        var scoreA = scores[teams[0]] ?? scores[teamAName];
        var scoreB = scores[teams[1]] ?? scores[teamBName];
        teamAScore = (scoreA != null && scoreA.toString() != '0')
            ? scoreA.toString()
            : '';
        teamBScore = (scoreB != null && scoreB.toString() != '0')
            ? scoreB.toString()
            : '';
      }
      displayText =
          "$teamAName${teamAScore.isNotEmpty ? ' ($teamAScore)' : ''} vs $teamBName${teamBScore.isNotEmpty ? ' ($teamBScore)' : ''}";
    } else if (teams.length == 1) {
      String teamName = _getTeamName(teams[0]);
      String teamScore = '';
      if (scores != null && scores.isNotEmpty && winner.isNotEmpty) {
        var score = scores[teams[0]] ?? scores[teamName];
        teamScore =
            (score != null && score.toString() != '0') ? score.toString() : '';
      }
      displayText = "$teamName${teamScore.isNotEmpty ? ' ($teamScore)' : ''}";
    } else {
      displayText = "Matchup";
    }

    String resolvedWinner = '';
    if (winner.isNotEmpty) {
      resolvedWinner = isFinalMatch
          ? _resolveWinnerFromString(winner, widget.matchups)
          : _getTeamName(winner);
    }

    // Determine the status indicator text and color
    String statusText = '';
    Color statusColor = Colors.grey;
    bool isMatchupEnded = false;

    if (winner.isNotEmpty && teams.contains(winner)) {
      statusText = 'Matchup Ended';
      statusColor = Colors.green;
      isMatchupEnded = true;
    } else if (teams.isNotEmpty && winner.isEmpty) {
      statusText = 'In Progress';
      statusColor = Colors.orange;
    }

    return Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onMatchupTap != null
            ? () {
                widget.onMatchupTap!(matchup);
              }
            : null,
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        displayText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.deepPurple,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  height: 1,
                  width: double.infinity,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 8),
                if (winner.isNotEmpty)
                  Column(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: isFinalMatch ? Colors.amber : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFinalMatch
                            ? 'Champion: $resolvedWinner'
                            : 'Winner: $resolvedWinner',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isFinalMatch
                              ? Colors.amber[800]
                              : Colors.green[800],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                if (!isMatchupEnded && statusText.isNotEmpty)
                  Column(
                    children: [
                      Icon(
                        Icons.timelapse,
                        color: statusColor,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Match Schedule: ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      matchup['dateTime'] ?? 'Upcoming',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBracket() {
    if (widget.matchups.isEmpty) {
      return Column(
        children: [
          _buildPlaceholderMatchupCard(),
        ],
      );
    }
    return Column(
      children: widget.matchups.asMap().entries.map((entry) {
        final index = entry.key;
        final matchup = entry.value;
        final isFinalMatch = (index == widget.matchups.length - 1) &&
            matchup['winner'].isNotEmpty;

        return _buildMatchupCard(matchup, isFinalMatch);
      }).toList(),
    );
  }

  Widget _buildPlaceholderMatchupCard() {
    return Material(
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Flexible(
                    child: Text(
                      "No matchups scheduled yet for this tournament.",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.deepPurple,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 1,
                width: double.infinity,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              const Icon(
                Icons.timelapse,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(height: 4),
              const Text(
                'Tournament Setup In Progress',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Match Schedule: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'TBD',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildBracket();
  }
}
