// results_ranking.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:tabulation_systemv7/services/results_rankings_service.dart';

class ResultsAndRankingsPage extends StatefulWidget {
  const ResultsAndRankingsPage({Key? key}) : super(key: key);

  @override
  State<ResultsAndRankingsPage> createState() => _ResultsAndRankingsPageState();
}

class _ResultsAndRankingsPageState extends State<ResultsAndRankingsPage> {
  final TournamentResultsRankingsService _tournamentService = TournamentResultsRankingsService();
  List<Tournament> _tournaments = [];
  List<TeamRanking> _rankings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch all tournaments
      _tournaments = await _tournamentService.fetchAllTournaments();
      
      // Get all unique team IDs from tournaments
      Set<String> allTeamIds = {};
      for (var tournament in _tournaments) {
        allTeamIds.addAll(tournament.selectedTeamIds);
        if (tournament.medals.containsKey('gold') && tournament.medals['gold'] != null) {
          allTeamIds.add(tournament.medals['gold']);
        }
        if (tournament.medals.containsKey('silver') && tournament.medals['silver'] != null) {
          allTeamIds.add(tournament.medals['silver']);
        }
        if (tournament.medals.containsKey('bronze') && tournament.medals['bronze'] != null) {
          allTeamIds.add(tournament.medals['bronze']);
        }
      }
      
      // Fetch participants data
      Map<String, Participant> participants = await _tournamentService.fetchParticipants(allTeamIds.toList());
      
      // Calculate rankings with participant data
      Map<String, TeamRanking> rankingsMap = await _tournamentService.calculateRankings(_tournaments, participants);
      
      // Sort rankings
      _rankings = _tournamentService.sortRankings(rankingsMap);
      
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
   
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading tournaments and rankings...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tournaments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_esports,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No tournaments found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_rankings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'No teams found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          // Summary Cards - 1 row that maximizes screen width
          _buildSummaryCards(),
          const SizedBox(height: 16),
          // Rankings Table
          _buildRankingsTable(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    int totalTournaments = _tournaments.length;
    int totalTeams = _rankings.length;
    int totalGoldMedals = _rankings.fold(0, (sum, team) => sum + team.goldCount);
    int totalSilverMedals = _rankings.fold(0, (sum, team) => sum + team.silverCount);
    int totalBronzeMedals = _rankings.fold(0, (sum, team) => sum + team.bronzeCount);
    int teamsWithMedals = _rankings.where((team) => team.totalMedals > 0).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildExpandedCard(
              'Tournaments',
              totalTournaments.toString(),
              Icons.emoji_events,
              Colors.blue,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildExpandedCard(
              'Teams',
              totalTeams.toString(),
              Icons.people,
              Colors.green,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildExpandedCard(
              '🥇 Gold',
              totalGoldMedals.toString(),
              Icons.workspace_premium,
              Colors.amber,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildExpandedCard(
              '🥈 Silver',
              totalSilverMedals.toString(),
              Icons.workspace_premium,
              Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildExpandedCard(
              '🥉 Bronze',
              totalBronzeMedals.toString(),
              Icons.workspace_premium,
              Colors.brown,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildExpandedCard(
              'Medal Teams',
              '$teamsWithMedals',
              Icons.emoji_events,
              Colors.orange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRankingsTable() {
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            child: const Row(
              children: [
                SizedBox(width: 50, child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 40, child: Text('', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text('Team', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 50, child: Text('🥇', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 50, child: Text('🥈', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 50, child: Text('🥉', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                SizedBox(width: 50, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.65,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _rankings.length,
              itemBuilder: (context, index) {
                return _buildRankingRow(_rankings[index], index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankingRow(TeamRanking ranking, int rank) {
    bool hasMedals = ranking.totalMedals > 0;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: hasMedals ? null : Colors.grey[50],
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: _buildRankIcon(rank, hasMedals),
          ),
          SizedBox(
            width: 40,
            child: _buildTeamAvatar(ranking.imageBase64),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking.teamName ?? ranking.teamId,
                  style: TextStyle(
                    fontWeight: hasMedals ? FontWeight.w600 : FontWeight.normal,
                    color: hasMedals ? Colors.black87 : Colors.grey[600],
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (ranking.coachName != null && ranking.coachName!.isNotEmpty)
                  Text(
                    'Coach: ${ranking.coachName}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              ranking.goldCount.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ranking.goldCount > 0 ? Colors.amber : Colors.grey[400],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              ranking.silverCount.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ranking.silverCount > 0 ? Colors.grey[600] : Colors.grey[400],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              ranking.bronzeCount.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ranking.bronzeCount > 0 ? Colors.brown[300] : Colors.grey[400],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 50,
            child: Text(
              ranking.totalMedals.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: hasMedals ? Colors.black87 : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamAvatar(String? imageBase64) {
    if (imageBase64 != null && imageBase64.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(imageBase64),
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports, size: 16),
              );
            },
          ),
        );
      } catch (e) {
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.sports, size: 16),
        );
      }
    } else {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.sports, size: 16),
      );
    }
  }

  Widget _buildRankIcon(int rank, bool hasMedals) {
    if (!hasMedals) {
      return Text(
        rank.toString(),
        style: TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          color: Colors.grey[400],
        ),
        textAlign: TextAlign.center,
      );
    }
    
    if (rank == 1) {
      return const Icon(Icons.emoji_events, color: Colors.amber, size: 20);
    } else if (rank == 2) {
      return const Icon(Icons.emoji_events, color: Colors.grey, size: 20);
    } else if (rank == 3) {
      return const Icon(Icons.emoji_events, color: Colors.brown, size: 20);
    } else {
      return Text(
        rank.toString(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
      );
    }
  }
}