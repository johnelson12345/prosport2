// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class TournamentSummaryScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final List<Map<String, dynamic>> matchups;
  final Map<String, String> teamNamesById;

  const TournamentSummaryScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    required this.matchups,
    required this.teamNamesById,
  });

  @override
  // ignore: library_private_types_in_public_api
  _TournamentSummaryScreenState createState() =>
      _TournamentSummaryScreenState();
}

class _TournamentSummaryScreenState extends State<TournamentSummaryScreen> {
  List<Map<String, dynamic>> _teamRankings = [];

  @override
  void initState() {
    super.initState();
    _calculateTeamRankings();
  }

  String _getTeamName(String teamId) {
    return widget.teamNamesById[teamId] ?? teamId;
  }

  void _calculateTeamRankings() {
    Map<String, Map<String, dynamic>> teamStats = {};

    for (var matchup in widget.matchups) {
      var teams = matchup['teams'] as List<String>;
      var winner = matchup['winner']?.toString() ?? '';

      for (var teamId in teams) {
        if (!teamStats.containsKey(teamId)) {
          teamStats[teamId] = {
            'teamId': teamId,
            'teamName': _getTeamName(teamId),
            'wins': 0,
            'losses': 0,
            'matches': 0,
            'points': 0,
            'rank': 0,
          };
        }

        teamStats[teamId]!['matches'] += 1;

        if (teamId == winner) {
          teamStats[teamId]!['wins'] += 1;
          teamStats[teamId]!['points'] += 3;
        } else if (winner.isNotEmpty) {
          teamStats[teamId]!['losses'] += 1;
        }
      }
    }

    _teamRankings = teamStats.values.toList();
    _teamRankings.sort((a, b) {
      if (b['points'] != a['points']) {
        return b['points'].compareTo(a['points']);
      }
      return b['wins'].compareTo(a['wins']);
    });

    // Assign ranks
    for (int i = 0; i < _teamRankings.length; i++) {
      _teamRankings[i]['rank'] = i + 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLogo('assets/logo1.jpg'),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${widget.tournamentName} - Summary',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildLogo('assets/logo2.jpg'),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: () => _printSummary(),
          ),
        ],
        backgroundColor: Colors.deepPurple,
        elevation: 4,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Tournament Title
                  Text(
                    widget.tournamentName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tournament Summary',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Logo Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLogo('assets/logo1.jpg', size: 50),
                      const SizedBox(width: 20),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(width: 20),
                      _buildLogo('assets/logo2.jpg', size: 50),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats Summary Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildStatCard(
                      'Teams', _teamRankings.length.toString(), Icons.groups),
                  const SizedBox(width: 12),
                  _buildStatCard('Matches', widget.matchups.length.toString(),
                      Icons.sports),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Rankings Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.leaderboard, color: Colors.deepPurple),
                  const SizedBox(width: 8),
                  const Text(
                    'Team Rankings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_teamRankings.length} teams',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Rankings List
            Expanded(
              child: _teamRankings.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No tournament data available',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _teamRankings.length,
                      itemBuilder: (context, index) {
                        final team = _teamRankings[index];
                        return _buildTeamCard(team, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(String assetPath, {double size = 30}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: Icon(
                Icons.flag,
                color: Colors.grey[400],
                size: size * 0.6,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.deepPurple, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int index) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: team['rank'] == 1
              ? Border.all(color: Colors.amber, width: 2)
              : null,
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getRankColor(team['rank']),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: _getRankColor(team['rank']).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                team['rank'].toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            team['teamName'],
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: team['rank'] == 1 ? Colors.amber[700] : Colors.black87,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatIndicator('W', team['wins'], Colors.green),
                    const SizedBox(width: 8),
                    _buildStatIndicator('L', team['losses'], Colors.red),
                    const SizedBox(width: 8),
                    _buildStatIndicator('M', team['matches'], Colors.blue),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value:
                      team['matches'] > 0 ? team['wins'] / team['matches'] : 0,
                  backgroundColor: Colors.grey[200],
                  color: _getRankColor(team['rank']),
                  minHeight: 4,
                ),
              ],
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${team['points']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const Text(
                'points',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatIndicator(String label, int value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$label: $value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.blueGrey;
      case 3:
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  void _printSummary() async {
    try {
      final pdf = await _generatePdf();
      await Printing.layoutPdf(
        onLayout: (format) => pdf,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    // Create a simple PDF without logos first to test
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32.0),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        'TOURNAMENT SUMMARY',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.deepPurple,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        widget.tournamentName.isNotEmpty
                            ? widget.tournamentName
                            : 'Tournament',
                        style: pw.TextStyle(
                          fontSize: 18,
                          color: PdfColors.grey600,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 24),

                // Summary Information
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Total Teams: ${_teamRankings.length}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Total Matches: ${widget.matchups.length}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      'Generated on: ${DateTime.now().toString().split(' ')[0]}',
                      style: const pw.TextStyle(
                        color: PdfColors.grey600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),

                pw.SizedBox(height: 32),

                // Rankings Title
                pw.Text(
                  'TEAM RANKINGS',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.deepPurple,
                  ),
                ),

                pw.SizedBox(height: 16),

                // Rankings Table
                pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey400,
                    width: 1,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(0.8), // Rank
                    1: const pw.FlexColumnWidth(2.5), // Team Name
                    2: const pw.FlexColumnWidth(0.8), // Wins
                    3: const pw.FlexColumnWidth(0.8), // Losses
                    4: const pw.FlexColumnWidth(0.8), // Matches
                    5: const pw.FlexColumnWidth(1.0), // Points
                  },
                  children: [
                    // Table Header
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'Rank',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'Team Name',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'W',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'L',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'M',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(12),
                          child: pw.Text(
                            'Points',
                            style: pw.TextStyle(
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    // Table Rows
                    ..._teamRankings.map((team) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(10),
                              child: pw.Text(
                                team['rank'].toString(),
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: team['rank'] <= 3
                                      ? pw.FontWeight.bold
                                      : pw.FontWeight.normal,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(10),
                              child: pw.Text(
                                team['teamName'],
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: team['rank'] == 1
                                      ? pw.FontWeight.bold
                                      : pw.FontWeight.normal,
                                ),
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(10),
                              child: pw.Text(
                                team['wins'].toString(),
                                style: const pw.TextStyle(fontSize: 11),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(10),
                              child: pw.Text(
                                team['losses'].toString(),
                                style: const pw.TextStyle(fontSize: 11),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(10),
                              child: pw.Text(
                                team['matches'].toString(),
                                style: const pw.TextStyle(fontSize: 11),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(10),
                              child: pw.Text(
                                team['points'].toString(),
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                          ],
                        )),
                  ],
                ),

                pw.SizedBox(height: 24),

                // Footer
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Tournament completed successfully',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
