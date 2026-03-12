import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/participants_service.dart';
import 'package:tabulation_systemv7/services/team_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:math';

import 'package:tabulation_systemv7/services/tournament_verification_service_fixed.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/tournament_info.dart';

class ResultsVerification extends StatefulWidget {
  const ResultsVerification({super.key});

  @override
  _BracketsNewScreenState createState() => _BracketsNewScreenState();
}

class _BracketsNewScreenState extends State<ResultsVerification> {
  final TeamParticipantsService _teamService = TeamParticipantsService();
  final TournamentVerificationService _verificationService =
      TournamentVerificationService();
  final ParticipantsService _participantsService = ParticipantsService();
  Map<String, Map<String, dynamic>> _tournaments =
      {}; // Maps tournament ID -> {name, category, sport}
  List<Map<String, dynamic>> _filteredTournaments = [];
  String? _selectedTournamentId;
  List<Map<String, dynamic>> _matchups = [];
  final TextEditingController _searchController = TextEditingController();
  bool _showDropdown = false;
  Map<String, String> _teamNamesById = {};
  Map<String, String> _teamIdsByName = {};
  List<Map<String, dynamic>> _teamRankings = [];
  Map<String, dynamic>? _verificationStatus;
  bool _isVerifying = false;
  bool _isAwarding = false;
  List<Map<String, dynamic>> _teams = [];
  bool _hasAwardsBeenSet = false;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
    _fetchTeams();
  }

  Future<void> _fetchTournaments() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('tournaments').get();

      if (snapshot.docs.isEmpty) {
        print('No tournaments found in database');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('No tournaments found. Please create a tournament first.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      setState(() {
        _tournaments = {
          for (var doc in snapshot.docs)
            doc.id: {
              'name': doc['name'] as String,
              'category': doc['category'] as String? ?? 'Unknown',
              'sport': doc['sport'] as String? ?? 'Unknown',
            }
        };
        _filteredTournaments = _tournaments.values.toList();
        print('Fetched tournaments: $_tournaments');
      });
    } catch (e) {
      print('Error fetching tournaments: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tournaments: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchTeams() async {
    final teams = await _teamService.getTeams();
    setState(() {
      _teams = teams;
      _teamNamesById = {
        for (var team in teams) team['id'] as String: team['name'] as String
      };
      _teamIdsByName = {
        for (var team in teams) team['name'] as String: team['id'] as String
      };
    });
  }

  String _getTeamName(String teamId) {
    return _teamNamesById[teamId] ?? teamId;
  }

  void _fetchMatchups(String tournamentDocId) async {
    print('Debug: Fetching matchups for tournamentDocId: $tournamentDocId');

    // First, get the tournament document to extract the tournamentSetupId
    try {
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentDocId)
          .get();

      if (!tournamentDoc.exists) {
        print('Debug: Tournament document not found');
        return;
      }

      final tournamentData = tournamentDoc.data()!;
      final tournamentSetupId = tournamentDocId;
      print('Debug: Tournament setup ID: $tournamentSetupId');

      if (tournamentSetupId == null) {
        print('Debug: No tournamentSetupId found in tournament document');
        return;
      }

      FirebaseFirestore.instance
          .collection('team_schedules')
          .where('tournamentSetupId', isEqualTo: tournamentSetupId)
          .snapshots()
          .listen((snapshot) {
        print('Debug: Found ${snapshot.docs.length} matchup documents');
        for (var doc in snapshot.docs) {
          print('Debug: Matchup doc ${doc.id}: ${doc.data()}');
        }
        setState(() {
          _matchups = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'teams': List<String>.from(doc['teams']),
                    'scores': Map<String, dynamic>.from(doc['scores']),
                    'winner': doc['winner']?.toString() ?? '',
                    'dateTime': doc['dateTime']?.toString() ?? 'Upcoming',
                  })
              .toList();
          print('Debug: Processed ${_matchups.length} matchups');
          _calculateTeamRankings();
        });
      });
    } catch (e) {
      print('Debug: Error fetching tournament or matchups: $e');
    }

    // Listen to verification status
    _verificationService
        .streamVerificationStatus(tournamentDocId)
        .listen((snapshot) {
      if (mounted) {
        Map<String, dynamic>? status;
        if (snapshot.docs.isNotEmpty) {
          status = snapshot.docs.first.data() as Map<String, dynamic>?;
        }
        setState(() {
          _verificationStatus = status;
        });
        // Check if awards have been set when verification status changes
        if (status != null && status['isVerified'] == true) {
          _checkIfAwardsHaveBeenSet();
        }
      }
    });
  }

  String _getEffectiveWinner(Map<String, dynamic> matchup) {
    String winner = matchup['winner']?.toString() ?? '';
    if (winner.isNotEmpty) {
      return winner;
    }

    // If no winner set, infer from scores
    var scores = matchup['scores'] as Map<String, dynamic>? ?? {};
    var teams = matchup['teams'] as List<String>;

    print('Debug: teams: $teams, scores: $scores');

    if (teams.length == 2 && scores.isNotEmpty) {
      String teamA = teams[0];
      String teamB = teams[1];
      int scoreA = (scores[teamA] as num?)?.toInt() ?? 0;
      int scoreB = (scores[teamB] as num?)?.toInt() ?? 0;

      print(
          'Debug: teamA: $teamA scoreA: $scoreA, teamB: $teamB scoreB: $scoreB');

      if (scoreA > scoreB) {
        return teamA;
      } else if (scoreB > scoreA) {
        return teamB;
      }
    }

    return ''; // No clear winner
  }

  void _calculateTeamRankings() {
    Map<String, Map<String, dynamic>> teamStats = {};
    print('Debug: Calculating rankings for ${_matchups.length} matchups');

    // Identify champion from final matchup using effective winner
    String? championTeamId;
    if (_matchups.isNotEmpty) {
      var finalMatch = _matchups.last;
      String effectiveWinner = _getEffectiveWinner(finalMatch);
      if (effectiveWinner.isNotEmpty) {
        // If effectiveWinner is a team name, convert to ID
        championTeamId = _teamIdsByName[effectiveWinner] ?? effectiveWinner;
        print('Debug: Champion identified: $championTeamId');
      }
    }

    for (var matchup in _matchups) {
      var teams = matchup['teams'] as List<String>;
      String effectiveWinner = _getEffectiveWinner(matchup);
      print('Debug: Matchup teams: $teams, effective winner: $effectiveWinner');

      for (var teamName in teams) {
        // Convert team name to ID if necessary
        String teamId = _teamIdsByName[teamName] ?? teamName;
        if (!teamStats.containsKey(teamId)) {
          String teamNameDisplay = _getTeamName(teamId);
          // Filter out placeholder names starting with "Winner of"
          if (teamNameDisplay.startsWith("Winner of")) {
            print('Debug: Skipping placeholder team: $teamNameDisplay');
            continue;
          }
          teamStats[teamId] = {
            'teamId': teamId,
            'teamName': teamNameDisplay,
            'wins': 0,
            'losses': 0,
            'matches': 0,
            'points': 0,
            'rank': 0,
          };
          print('Debug: Added team to stats: $teamNameDisplay (ID: $teamId)');
        }

        teamStats[teamId]!['matches'] += 1;

        // Convert effectiveWinner to ID for comparison
        String winnerId = _teamIdsByName[effectiveWinner] ?? effectiveWinner;
        if (teamId == winnerId) {
          teamStats[teamId]!['wins'] += 1;
          teamStats[teamId]!['points'] += 3;
          print('Debug: $teamId won a match');
        } else if (effectiveWinner.isNotEmpty) {
          teamStats[teamId]!['losses'] += 1;
          print('Debug: $teamId lost a match');
        }
      }
    }

    _teamRankings = teamStats.values.toList();
    print('Debug: Generated ${_teamRankings.length} team rankings');

    // Sort with champion first, then by points and wins
    _teamRankings.sort((a, b) {
      if (a['teamId'] == championTeamId) return -1;
      if (b['teamId'] == championTeamId) return 1;
      if (b['points'] != a['points']) {
        return b['points'].compareTo(a['points']);
      }
      return b['wins'].compareTo(a['wins']);
    });

    for (int i = 0; i < _teamRankings.length; i++) {
      _teamRankings[i]['rank'] = i + 1;
    }

    print('Debug: Final rankings:');
    for (var ranking in _teamRankings) {
      print(
          '  Rank ${ranking['rank']}: ${ranking['teamName']} - ${ranking['wins']}W ${ranking['losses']}L ${ranking['points']}pts');
    }
  }

  Widget _buildVerificationStatus() {
    if (_selectedTournamentId == null) return const SizedBox.shrink();

    final isVerified = _verificationStatus?['isVerified'] ?? false;
    final verifiedAt = _verificationStatus?['verifiedAt'];
    final verifiedByEmail = _verificationStatus?['verifiedByEmail'];

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.pending,
                  color: isVerified ? Colors.green : Colors.orange,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Text(
                  isVerified ? 'Tournament Verified' : 'Pending Verification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isVerified ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            if (verifiedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Verified on: ${verifiedAt.toDate().toString().substring(0, 16)}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (verifiedByEmail != null) ...[
              const SizedBox(height: 4),
              Text(
                'Verified by: $verifiedByEmail',
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isVerifying
                        ? null
                        : () => _handleVerification(!isVerified),
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(isVerified ? Icons.close : Icons.verified),
                    label: Text(
                      _isVerifying
                          ? 'Processing...'
                          : (isVerified
                              ? 'Unverify Results'
                              : 'Verify Tournament Results'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isVerified ? Colors.orange : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            if (isVerified) ...[
              const SizedBox(height: 16),
              if (!_hasAwardsBeenSet)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed:
                            _isAwarding ? null : () => _showSetRewardsDialog(),
                        icon: _isAwarding
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.emoji_events),
                        label: Text(
                          _isAwarding ? 'Awarding...' : 'Set Rewards',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_hasAwardsBeenSet)
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showEditPreviousAwardsDialog(),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Previous Awards'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRankings() {
    String getRankLabel(int rank) {
      switch (rank) {
        case 1:
          return 'Champion';
        case 2:
          return '1st Runner Up';
        case 3:
          return '2nd Runner Up';
        default:
          return 'Rank $rank';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          'Team Rankings',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurpleAccent),
        ),
        const SizedBox(height: 10),
        if (_teamRankings.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'No rankings available yet.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                shrinkWrap: true,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _teamRankings.length,
                itemBuilder: (context, index) {
                  final team = _teamRankings[index];
                  final rankLabel = getRankLabel(team['rank']);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getRankColor(team['rank']),
                        child: Text(
                          team['rank'].toString(),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        '${team['teamName']} ($rankLabel)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                          'Wins: ${team['wins']} | Losses: ${team['losses']} | Matches: ${team['matches']} | Points: ${team['points']}'),
                      trailing: Text(
                        '${team['points']} pts',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _handleVerification(bool verify) async {
    if (_selectedTournamentId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(verify ? 'Verify Tournament' : 'Unverify Tournament'),
        content: Text(
          verify
              ? 'Are you sure you want to verify these tournament results? This action cannot be undone easily.'
              : 'Are you sure you want to unverify these tournament results?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: verify ? Colors.green : Colors.orange,
            ),
            child: Text(verify ? 'Verify' : 'Unverify'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isVerifying = true);

    try {
      if (verify) {
        await _verificationService
            .verifyTournamentResults(_selectedTournamentId!);
      } else {
        await _verificationService
            .unverifyTournamentResults(_selectedTournamentId!);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verify
                ? 'Tournament verified successfully!'
                : 'Tournament unverified successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isVerifying = false);
    }
  }

  void _showSetRewardsDialog() async {
    // Fetch all participants for this tournament
    List<Map<String, dynamic>> tournamentParticipants = [];
    Map<String, String> participantNames = {};

    try {
      // Get the tournament document to extract the tournamentSetupId
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(_selectedTournamentId)
          .get();

      if (!tournamentDoc.exists) {
        print('Tournament document not found');
        return;
      }

      final tournamentData = tournamentDoc.data()!;
      final tournamentSetupId = _selectedTournamentId;

      print('Debug: tournamentSetupId: $tournamentSetupId');

      if (tournamentSetupId == null) {
        print('No tournamentSetupId found in tournament document');
        return;
      }

      // Get all participants (teams) in this tournament from the rankings
      final allParticipantsSnapshot =
          await FirebaseFirestore.instance.collection('participants').get();

      for (var ranking in _teamRankings) {
        final participantName =
            ranking['teamName'].toString().trim().toLowerCase();
        // Find participant by name (case insensitive)
        QueryDocumentSnapshot<Map<String, dynamic>>? participantDoc;
        for (var doc in allParticipantsSnapshot.docs) {
          if ((doc['name'] as String?)?.trim().toLowerCase() ==
              participantName) {
            participantDoc = doc;
            break;
          }
        }

        if (participantDoc != null) {
          final participantData = participantDoc.data()!;
          final participantId = participantDoc.id;
          tournamentParticipants.add({
            'id': participantId,
            'name': participantData['name'] ?? 'Unknown',
            'currentMedals': List<String>.from(participantData['medals'] ?? []),
            'participationGold': participantData['participationGold'] ?? 0,
            'teamName': ranking['teamName'],
          });
          participantNames[participantId] =
              participantData['name'] ?? 'Unknown';
        }
      }

      print(
          'Debug: Found ${tournamentParticipants.length} participants for tournament $tournamentSetupId');
    } catch (e) {
      print('Error fetching participants: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading participants: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Medal assignment state
    Map<String, List<String>> medalAssignments = {
      'Gold': [],
      'Silver': [],
      'Bronze': [],
    };

    // Pre-assign based on rankings
    for (int i = 0; i < _teamRankings.length && i < 3; i++) {
      final ranking = _teamRankings[i];
      final team = _teams.firstWhere((t) => t['id'] == ranking['teamId'],
          orElse: () => {});
      final participants = team['participants'] as List<dynamic>? ?? [];

      String medal = '';
      switch (ranking['rank']) {
        case 1:
          medal = 'Gold';
          break;
        case 2:
          medal = 'Silver';
          break;
        case 3:
          medal = 'Bronze';
          break;
      }

      for (var participantId in participants) {
        if (participantNames.containsKey(participantId)) {
          medalAssignments[medal]!.add(participantId);
        }
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Set Tournament Rewards'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Assign Medals to Participants:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (tournamentParticipants.isEmpty)
                      const Text('No participants found for this tournament.')
                    else
                      ...['Gold', 'Silver', 'Bronze'].map((medal) {
                        Color medalColor;
                        switch (medal.toLowerCase()) {
                          case 'gold':
                            medalColor = Colors.amber;
                            break;
                          case 'silver':
                            medalColor = Colors.grey;
                            break;
                          case 'bronze':
                            medalColor = Colors.brown;
                            break;
                          default:
                            medalColor = Colors.blue;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.emoji_events, color: medalColor),
                                const SizedBox(width: 8),
                                Text(
                                  '$medal Medal',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: medalColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 150),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  children:
                                      tournamentParticipants.map((participant) {
                                    final isAssigned = medalAssignments[medal]!
                                        .contains(participant['id']);
                                    final hasMedal =
                                        participant['currentMedals']
                                            .contains(medal);

                                    return CheckboxListTile(
                                      title: Text(
                                        '${participant['name']} (${participant['teamName']})',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: hasMedal
                                              ? Colors.green[700]
                                              : null,
                                          fontWeight:
                                              hasMedal ? FontWeight.bold : null,
                                        ),
                                      ),
                                      subtitle: hasMedal
                                          ? Text('Already has $medal medal')
                                          : null,
                                      value: isAssigned,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          if (value == true) {
                                            // Remove all participants from the same team from other medals
                                            final teamName =
                                                participant['teamName'];
                                            for (var otherMedal
                                                in medalAssignments.keys) {
                                              if (otherMedal != medal) {
                                                medalAssignments[otherMedal]!
                                                    .removeWhere((id) {
                                                  final p =
                                                      tournamentParticipants
                                                          .firstWhere(
                                                              (p) =>
                                                                  p['id'] == id,
                                                              orElse: () => {});
                                                  return p['teamName'] ==
                                                      teamName;
                                                });
                                              }
                                            }
                                            medalAssignments[medal]!
                                                .add(participant['id']);
                                          } else {
                                            medalAssignments[medal]!
                                                .remove(participant['id']);
                                          }
                                        });
                                      },
                                      dense: true,
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }),
                    const Divider(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.monetization_on, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Participation Gold: +1 to all participants in this tournament.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isAwarding
                      ? null
                      : () async {
                          setState(() => _isAwarding = true);
                          try {
                            await _awardCustomRewards(medalAssignments);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Rewards awarded successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error awarding rewards: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            setState(() => _isAwarding = false);
                          }
                        },
                  child: _isAwarding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Award Rewards'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditPreviousAwardsDialog() async {
    // Fetch all participants for this tournament with their current awards
    List<Map<String, dynamic>> tournamentParticipants = [];
    Map<String, String> participantNames = {};

    try {
      // Get the tournament document to extract the tournamentSetupId
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(_selectedTournamentId)
          .get();

      if (!tournamentDoc.exists) {
        print('Tournament document not found');
        return;
      }

      final tournamentData = tournamentDoc.data()!;
      final tournamentSetupId = _selectedTournamentId;

      print('Debug: tournamentSetupId: $tournamentSetupId');

      if (tournamentSetupId == null) {
        print('No tournamentSetupId found in tournament document');
        return;
      }

      // Get all participants (teams) in this tournament from the rankings
      final allParticipantsSnapshot =
          await FirebaseFirestore.instance.collection('participants').get();

      for (var ranking in _teamRankings) {
        final participantName =
            ranking['teamName'].toString().trim().toLowerCase();
        // Find participant by name (case insensitive)
        QueryDocumentSnapshot<Map<String, dynamic>>? participantDoc;
        for (var doc in allParticipantsSnapshot.docs) {
          if ((doc['name'] as String?)?.trim().toLowerCase() ==
              participantName) {
            participantDoc = doc;
            break;
          }
        }

        if (participantDoc != null) {
          final participantData = participantDoc.data()!;
          final participantId = participantDoc.id;
          tournamentParticipants.add({
            'id': participantId,
            'name': participantData['name'] ?? 'Unknown',
            'currentMedals': List<String>.from(participantData['medals'] ?? []),
            'participationGold': participantData['participationGold'] ?? 0,
            'teamName': ranking['teamName'],
            'rewardHistory': List<Map<String, dynamic>>.from(
                participantData['rewardHistory'] ?? []),
          });
          participantNames[participantId] =
              participantData['name'] ?? 'Unknown';
        }
      }

      print(
          'Debug: Found ${tournamentParticipants.length} participants for tournament $tournamentSetupId');
    } catch (e) {
      print('Error fetching participants: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading participants: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // State for editing awards
    Map<String, Map<String, String>> medalChanges =
        {}; // participantId -> {oldMedal: newMedal}
    Map<String, List<String>> medalRemovals = {
      'Gold': [],
      'Silver': [],
      'Bronze': [],
    };
    List<String> goldRemovals = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Previous Awards'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Edit Medals for Participants:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    if (tournamentParticipants.isEmpty)
                      const Text('No participants found for this tournament.')
                    else
                      ...tournamentParticipants.map((participant) {
                        final currentMedals =
                            participant['currentMedals'] as List<String>;
                        if (currentMedals.isEmpty)
                          return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${participant['name']} (${participant['teamName']})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            ...currentMedals.map((medal) {
                              Color medalColor;
                              switch (medal.toLowerCase()) {
                                case 'gold':
                                  medalColor = Colors.amber;
                                  break;
                                case 'silver':
                                  medalColor = Colors.grey;
                                  break;
                                case 'bronze':
                                  medalColor = Colors.brown;
                                  break;
                                default:
                                  medalColor = Colors.blue;
                              }

                              return Row(
                                children: [
                                  Icon(Icons.emoji_events,
                                      color: medalColor, size: 20),
                                  const SizedBox(width: 8),
                                  Text('Current: $medal',
                                      style: TextStyle(color: medalColor)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButton<String>(
                                      value: medalChanges[participant['id']]
                                                  ?.containsKey(medal) ==
                                              true
                                          ? medalChanges[participant['id']]![
                                              medal]
                                          : medal,
                                      items: [
                                        'Gold',
                                        'Silver',
                                        'Bronze',
                                        'Remove'
                                      ]
                                          .map((newMedal) => DropdownMenuItem(
                                                value: newMedal,
                                                child: Text(newMedal),
                                              ))
                                          .toList(),
                                      onChanged: (String? newValue) {
                                        setState(() {
                                          if (newValue == 'Remove') {
                                            medalRemovals[medal]!
                                                .add(participant['id']);
                                            medalChanges[participant['id']]
                                                ?.remove(medal);
                                          } else {
                                            medalRemovals[medal]!
                                                .remove(participant['id']);
                                            medalChanges[participant['id']] ??=
                                                {};
                                            medalChanges[participant['id']]![
                                                medal] = newValue!;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text(
                      'Remove Participation Gold:',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: tournamentParticipants.map((participant) {
                            final currentGold =
                                participant['participationGold'];
                            final isMarkedForRemoval =
                                goldRemovals.contains(participant['id']);

                            if (currentGold <= 0)
                              return const SizedBox.shrink();

                            return CheckboxListTile(
                              title: Text(
                                '${participant['name']} (${participant['teamName']}) - Current Gold: $currentGold',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: const Text('Remove 1 Gold'),
                              value: isMarkedForRemoval,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    goldRemovals.add(participant['id']);
                                  } else {
                                    goldRemovals.remove(participant['id']);
                                  }
                                });
                              },
                              dense: true,
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isAwarding
                      ? null
                      : () async {
                          setState(() => _isAwarding = true);
                          try {
                            await _editPreviousAwards(
                                medalChanges, medalRemovals, goldRemovals);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Awards edited successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error editing awards: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            setState(() => _isAwarding = false);
                          }
                        },
                  child: _isAwarding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Edit Awards'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editPreviousAwards(
      Map<String, Map<String, String>> medalChanges,
      Map<String, List<String>> medalRemovals,
      List<String> goldRemovals) async {
    final tournamentName =
        _tournaments[_selectedTournamentId]?['name'] ?? 'Unknown Tournament';
    final category =
        _tournaments[_selectedTournamentId]?['category'] ?? 'Unknown';
    final sport = _tournaments[_selectedTournamentId]?['sport'] ?? 'Unknown';

    // Handle medal changes
    for (var entry in medalChanges.entries) {
      final participantId = entry.key;
      final changes = entry.value;

      for (var changeEntry in changes.entries) {
        final oldMedal = changeEntry.key;
        final newMedal = changeEntry.value;

        final doc = await FirebaseFirestore.instance
            .collection('participants')
            .doc(participantId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final currentMedals = List<String>.from(data['medals'] ?? []);
          currentMedals.remove(oldMedal);
          currentMedals.add(newMedal);
          await doc.reference.update({
            'medals': currentMedals,
            'rewardHistory': FieldValue.arrayUnion([
              {
                'type': 'medalChange',
                'oldMedal': oldMedal,
                'newMedal': newMedal,
                'tournament': tournamentName,
                'category': category,
                'sport': sport,
                'date': DateTime.now(),
              }
            ]),
          });
        }
      }
    }

    // Remove medals
    for (var entry in medalRemovals.entries) {
      final medal = entry.key;
      final participantIds = entry.value;

      for (var participantId in participantIds) {
        final doc = await FirebaseFirestore.instance
            .collection('participants')
            .doc(participantId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final currentMedals = List<String>.from(data['medals'] ?? []);
          currentMedals.remove(medal);
          await doc.reference.update({
            'medals': currentMedals,
            'rewardHistory': FieldValue.arrayUnion([
              {
                'type': 'medalRemoval',
                'medal': medal,
                'tournament': tournamentName,
                'category': category,
                'sport': sport,
                'date': DateTime.now(),
              }
            ]),
          });
        }
      }
    }

    // Remove participation gold
    for (var participantId in goldRemovals) {
      final doc = await FirebaseFirestore.instance
          .collection('participants')
          .doc(participantId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final currentGold = data['participationGold'] ?? 0;
        if (currentGold > 0) {
          await doc.reference.update({
            'participationGold': currentGold - 1,
            'rewardHistory': FieldValue.arrayUnion([
              {
                'type': 'participationGoldRemoval',
                'amount': 1,
                'tournament': tournamentName,
                'category': category,
                'sport': sport,
                'date': DateTime.now(),
              }
            ]),
          });
        }
      }
    }
  }

  Future<void> _checkIfAwardsHaveBeenSet() async {
    if (_selectedTournamentId == null) return;

    try {
      final tournamentName = _tournaments[_selectedTournamentId]?['name'] ?? '';
      final participantsSnapshot =
          await FirebaseFirestore.instance.collection('participants').get();

      bool hasAwards = false;
      for (var doc in participantsSnapshot.docs) {
        final data = doc.data();
        final rewardHistory =
            List<Map<String, dynamic>>.from(data['rewardHistory'] ?? []);
        final hasTournamentAwards =
            rewardHistory.any((entry) => entry['tournament'] == tournamentName);

        if (hasTournamentAwards) {
          hasAwards = true;
          break;
        }
      }

      setState(() {
        _hasAwardsBeenSet = hasAwards;
      });
    } catch (e) {
      print('Error checking awards: $e');
    }
  }

  Future<void> _awardRewards() async {
    if (_selectedTournamentId == null) return;

    // Award participation gold to all participants in the tournament
    await _participantsService
        .awardParticipationGoldToTournament(_selectedTournamentId!);

    // Award medals to top 3 teams
    for (int i = 0; i < _teamRankings.length && i < 3; i++) {
      final ranking = _teamRankings[i];
      final teamId = ranking['teamId'];
      final team =
          _teams.firstWhere((t) => t['id'] == teamId, orElse: () => {});
      final participants = team['participants'] as List<dynamic>? ?? [];

      String medal = '';
      switch (ranking['rank']) {
        case 1:
          medal = 'Gold';
          break;
        case 2:
          medal = 'Silver';
          break;
        case 3:
          medal = 'Bronze';
          break;
      }

      if (participants.isNotEmpty) {
        await _participantsService.awardMedalsToTeamParticipants(
            participants.cast<String>(), medal);
      }
    }
  }

  Future<void> _awardCustomRewards(
      Map<String, List<String>> medalAssignments) async {
    if (_selectedTournamentId == null) return;

    final tournamentName =
        _tournaments[_selectedTournamentId]?['name'] ?? 'Unknown Tournament';
    final category =
        _tournaments[_selectedTournamentId]?['category'] ?? 'Unknown';
    final sport = _tournaments[_selectedTournamentId]?['sport'] ?? 'Unknown';

    // Award participation gold to all participants in the tournament with label
    final participantsSnapshot =
        await FirebaseFirestore.instance.collection('participants').get();
    for (var doc in participantsSnapshot.docs) {
      final data = doc.data();
      final currentGold = data['participationGold'] ?? 0;
      await doc.reference.update({
        'participationGold': currentGold + 1,
        'rewardHistory': FieldValue.arrayUnion([
          {
            'type': 'participationGold',
            'amount': 1,
            'tournament': tournamentName,
            'category': category,
            'sport': sport,
            'date': DateTime.now(),
          }
        ]),
      });
    }

    // Award medals based on custom assignments with label
    for (var entry in medalAssignments.entries) {
      final medal = entry.key;
      final participantIds = entry.value;

      for (var participantId in participantIds) {
        final doc = await FirebaseFirestore.instance
            .collection('participants')
            .doc(participantId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          final currentMedals = List<String>.from(data['medals'] ?? []);
          currentMedals.add(medal);
          await doc.reference.update({
            'medals': currentMedals,
            'rewardHistory': FieldValue.arrayUnion([
              {
                'type': 'medal',
                'medal': medal,
                'tournament': tournamentName,
                'category': category,
                'sport': sport,
                'date': DateTime.now(),
              }
            ]),
          });
        }
      }
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  void _printSummary() async {
    final pdf = await _generatePdf();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreview(
          build: (format) => pdf,
          pdfFileName:
              '${_tournaments[_selectedTournamentId ?? 'tournament']?['name'] ?? 'tournament'}_Summary.pdf',
        ),
      ),
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    // Load logo images
    final logo3Bytes = await rootBundle.load('assets/logo3.jpg');
    final logo2Bytes = await rootBundle.load('assets/logo2.jpg');
    final logo3Image = pw.MemoryImage(logo3Bytes.buffer.asUint8List());
    final logo2Image = pw.MemoryImage(logo2Bytes.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with logos and text
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Image(logo3Image, width: 80, height: 80),
                  pw.SizedBox(width: 16),
                  pw.Text(
                    'Tournament Results Verification',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(width: 16),
                  pw.Image(logo2Image, width: 80, height: 80),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                  'Tournament Name: ${_tournaments[_selectedTournamentId ?? 'tournament']?['name'] ?? 'Unknown'}',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center),
              pw.SizedBox(height: 20),
              pw.Text('Summary/Team Rankings:',
                  style: pw.TextStyle(
                      fontSize: 15, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.ListView.builder(
                itemCount: _teamRankings.length,
                itemBuilder: (context, index) {
                  final team = _teamRankings[index];
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('${team['rank']}. ${team['teamName']}'),
                      pw.Text(
                          '   Wins: ${team['wins']} | Losses: ${team['losses']}'),
                      pw.Text(
                          '   Matches: ${team['matches']} | Points: ${team['points']}'),
                      pw.SizedBox(height: 10),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  void _filterTournaments(String query) {
    setState(() {
      _filteredTournaments = _tournaments.values
          .where((tournament) => (tournament['name'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
      _showDropdown = query.isNotEmpty;
    });
  }

  void _onTournamentSelected(Map<String, dynamic> tournament) {
    final tournamentName = tournament['name'] as String;
    print('Tournament selected: $tournamentName');
    print('Available tournaments: $_tournaments');

    final tournamentId = _tournaments.entries
        .firstWhere((entry) => entry.value['name'] == tournamentName,
            orElse: () => const MapEntry('', {}))
        .key;

    print('Found tournament ID: $tournamentId');

    if (tournamentId.isNotEmpty) {
      setState(() {
        _selectedTournamentId = tournamentId;
        print('Set selected tournament ID: $_selectedTournamentId');
        print(
            'Tournament name should be: ${_tournaments[_selectedTournamentId]?['name']}');
        // Clear old data to ensure fresh state when searching/selecting tournament
        _matchups = [];
        _teamRankings = [];
        _verificationStatus = null;
        _fetchMatchups(tournamentId);
        _searchController.clear();
        _filteredTournaments.clear();
        _showDropdown = false;
      });
    } else {
      print('Tournament ID not found for name: $tournamentName');
    }
  }

  String _resolveWinnerFromString(
      String winnerStr, List<Map<String, dynamic>> matchups) {
    // If winnerStr is a direct team name, return it
    if (_teamNamesById.containsKey(winnerStr)) {
      return _teamNamesById[winnerStr]!;
    }
    // If winnerStr starts with "Winner of ", parse referenced teams
    if (winnerStr.startsWith("Winner of ")) {
      // Extract the substring after "Winner of "
      String teamsStr = winnerStr.substring("Winner of ".length);
      // Expected format: "Team A vs Team B"
      List<String> parts = teamsStr.split(" vs ");
      if (parts.length == 2) {
        String teamA = parts[0].trim();
        String teamB = parts[1].trim();
        // Find the matchup with these two teams (in any order)
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
    // Fallback: return winnerStr as is
    return winnerStr;
  }

  Widget _buildBracket() {
    return Column(
      children: _matchups.asMap().entries.map((entry) {
        final index = entry.key;
        final matchup = entry.value;
        final teams = matchup['teams'];
        String effectiveWinner = _getEffectiveWinner(matchup);
        final isFinalMatch =
            (index == _matchups.length - 1) && effectiveWinner.isNotEmpty;

        String displayText;
        if (teams.length == 2) {
          displayText =
              "${_getTeamName(teams[0])} vs ${_getTeamName(teams[1])}";
        } else if (teams.length == 1) {
          displayText = _getTeamName(teams[0]);
        } else {
          displayText = "Matchup";
        }

        String resolvedWinner = '';
        if (effectiveWinner.isNotEmpty) {
          if (isFinalMatch) {
            resolvedWinner =
                _resolveWinnerFromString(effectiveWinner, _matchups);
          } else {
            resolvedWinner = _getTeamName(effectiveWinner);
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      displayText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Container(height: 2, width: 100, color: Colors.black),
              const SizedBox(height: 5),
              if (effectiveWinner.isNotEmpty)
                Text(
                  isFinalMatch
                      ? 'Champion: $resolvedWinner'
                      : 'Winner: $resolvedWinner',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Tournament Results Verification',
            style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                Colors.orange.shade600,
                Colors.deepOrange.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        elevation: 4,
        actions: [
          if (_selectedTournamentId != null)
            IconButton(
              icon: const Icon(Icons.print, color: Colors.white),
              onPressed: _printSummary,
              tooltip: 'Print Summary',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_selectedTournamentId == null)
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 0.7,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: _filteredTournaments.length,
                  itemBuilder: (context, index) {
                    final tournament = _filteredTournaments[index];
                    final tournamentName = tournament['name'] ?? 'Unknown';
                    final category = tournament['category'] ?? 'N/A';
                    final sport = tournament['sport'] ?? 'N/A';
                    final eliminationType =
                        tournament['eliminationType'] ?? 'N/A';
                    final status = tournament['status'] ?? 'N/A';

                    Color cardColor1, cardColor2;
                    Color textColor = Colors.white;

                    switch (status.toLowerCase()) {
                      case 'active':
                        cardColor1 = const Color(0xFF667EEA);
                        cardColor2 = const Color.fromARGB(255, 241, 96, 13);
                        break;
                      case 'inactive':
                        cardColor1 = const Color(0xFF4FACFE);
                        cardColor2 = const Color(0xFFFEE140);
                        break;
                      default:
                        cardColor1 = const Color(0xFF4FACFE);
                        cardColor2 = const Color(0xFFFEE140);
                        break;
                    }

                    return GestureDetector(
                      onTap: () => _onTournamentSelected(tournament),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: cardColor1.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                              spreadRadius: -5,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [cardColor1, cardColor2],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                stops: const [0.1, 0.9],
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: -20,
                                  right: -20,
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color:
                                                  Colors.white.withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.emoji_events_rounded,
                                              size: 28,
                                              color: Colors.white,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              final tournamentId = _tournaments
                                                  .entries
                                                  .firstWhere(
                                                      (entry) =>
                                                          entry.value['name'] ==
                                                          tournamentName,
                                                      orElse: () =>
                                                          const MapEntry(
                                                              '', {}))
                                                  .key;
                                              if (tournamentId.isNotEmpty) {
                                                showDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      AlertDialog(
                                                    title: const Text(
                                                        'Tournament Information'),
                                                    content: SizedBox(
                                                      width: 300,
                                                      height: 200,
                                                      child: TournamentInfo(
                                                          tournamentId:
                                                              tournamentId),
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.of(
                                                                    context)
                                                                .pop(),
                                                        child:
                                                            const Text('Close'),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.2),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: const Icon(
                                                Icons.info_outline,
                                                size: 24,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        tournamentName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 10),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.category_rounded,
                                                  size: 16,
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    'Category: $category',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white
                                                          .withOpacity(0.95),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.sports_rounded,
                                                  size: 16,
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                ),
                                                Expanded(
                                                  child: Text(
                                                    'Sport: $sport',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white
                                                          .withOpacity(0.95),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // Row(
                                            //   children: [
                                            //     Icon(
                                            //       Icons
                                            //           .format_list_bulleted_rounded,
                                            //       size: 16,
                                            //       color: Colors.white
                                            //           .withOpacity(0.8),
                                            //     ),
                                            //     const SizedBox(width: 8),
                                            //   ],
                                            // ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        height: 2,
                                        margin: const EdgeInsets.only(top: 12),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(2),
                                          color: Colors.white.withOpacity(0.3),
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
                  },
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Tournament Name: ${_tournaments[_selectedTournamentId!]!['name']}",
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color.fromARGB(255, 3, 3, 3)),
                          ),
                          Text(
                            "Category: ${_tournaments[_selectedTournamentId!]!['category']} | Sport: ${_tournaments[_selectedTournamentId!]!['sport']}",
                            style: TextStyle(
                                fontSize: 14, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    _buildVerificationStatus(),
                    _matchups.isEmpty
                        ? const Text('Select a tournament to view matchups.',
                            style:
                                TextStyle(fontSize: 18, color: Colors.black54))
                        : _buildBracket(),
                    _buildRankings(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
