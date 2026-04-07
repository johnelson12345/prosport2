// results_ranking.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tabulation_systemv7/services/results_rankings_service.dart';

class ResultsAndRankingsAdminPage extends StatefulWidget {
  const ResultsAndRankingsAdminPage({Key? key}) : super(key: key);

  @override
  State<ResultsAndRankingsAdminPage> createState() => _ResultsAndRankingsAdminPageState();
}

class _ResultsAndRankingsAdminPageState extends State<ResultsAndRankingsAdminPage> {
  final TournamentResultsRankingsService _tournamentService = TournamentResultsRankingsService();
  List<Tournament> _tournaments = [];
  List<TeamRanking> _rankings = [];
  bool _isLoading = true;
  String? _error;
  final GlobalKey _printKey = GlobalKey();

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

  Future<void> _printRankings() async {
    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => _generatePdf(format),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    
    // Calculate summary statistics for PDF
    int totalTournaments = _tournaments.length;
    int totalTeams = _rankings.length;
    int totalGoldMedals = _rankings.fold(0, (sum, team) => sum + team.goldCount);
    int totalSilverMedals = _rankings.fold(0, (sum, team) => sum + team.silverCount);
    int totalBronzeMedals = _rankings.fold(0, (sum, team) => sum + team.bronzeCount);
    int teamsWithMedals = _rankings.where((team) => team.totalMedals > 0).length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        orientation: pw.PageOrientation.landscape,
        build: (pw.Context context) {
          return [
            // Header
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Tournament Results and Rankings',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Generated on: ${DateTime.now().toString().split('.')[0]}',
                    style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
                  ),
                  pw.SizedBox(height: 20),
                  // Summary information as text (no cards)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 20),
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Summary Statistics',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 10),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            _buildPdfSummaryItem('Tournaments:', totalTournaments.toString()),
                            _buildPdfSummaryItem('Teams:', totalTeams.toString()),
                            _buildPdfSummaryItem('Gold Medals:', totalGoldMedals.toString()),
                            _buildPdfSummaryItem('Silver Medals:', totalSilverMedals.toString()),
                            _buildPdfSummaryItem('Bronze Medals:', totalBronzeMedals.toString()),
                            _buildPdfSummaryItem('Teams with Medals:', teamsWithMedals.toString()),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Rankings Table
            pw.Container(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Team Rankings',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _buildPdfRankingsTable(),
                ],
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildPdfSummaryItem(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8),
      child: pw.Text(
        '$label $value',
        style: pw.TextStyle(fontSize: 11),
      ),
    );
  }

  pw.Widget _buildPdfRankingsTable() {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300),
      columnWidths: {
        0: const pw.FixedColumnWidth(50),  // Rank
        1: const pw.FixedColumnWidth(40),  // Avatar (simplified)
        2: const pw.FlexColumnWidth(),     // Team Name
        3: const pw.FixedColumnWidth(50),  // Gold
        4: const pw.FixedColumnWidth(50),  // Silver
        5: const pw.FixedColumnWidth(50),  // Bronze
        6: const pw.FixedColumnWidth(50),  // Total
      },
      children: [
        // Header Row
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: PdfColors.grey200,
          ),
          children: [
            _buildPdfHeaderCell('Rank'),
            _buildPdfHeaderCell(''),
            _buildPdfHeaderCell('Team'),
            _buildPdfHeaderCell('🥇'),
            _buildPdfHeaderCell('🥈'),
            _buildPdfHeaderCell('🥉'),
            _buildPdfHeaderCell('Total'),
          ],
        ),
        // Data Rows
        ...List.generate(_rankings.length, (index) {
          final ranking = _rankings[index];
          final rank = index + 1;
          final hasMedals = ranking.totalMedals > 0;
          
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: index % 2 == 0 ? PdfColors.white : PdfColors.grey50,
            ),
            children: [
              _buildPdfCell(
                rank.toString(),
                alignment: pw.Alignment.center,
                fontWeight: hasMedals && rank <= 3 ? pw.FontWeight.bold : null,
                color: hasMedals && rank == 1 ? PdfColors.amber : 
                       hasMedals && rank == 2 ? PdfColors.grey600 :
                       hasMedals && rank == 3 ? PdfColors.brown : null,
              ),
              _buildPdfCell('🏅', alignment: pw.Alignment.center),
              _buildPdfCell(
                ranking.teamName ?? ranking.teamId,
                fontWeight: hasMedals ? pw.FontWeight.bold : pw.FontWeight.normal,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      ranking.teamName ?? ranking.teamId,
                      style: pw.TextStyle(
                        fontWeight: hasMedals ? pw.FontWeight.bold : pw.FontWeight.normal,
                        fontSize: 11,
                      ),
                    ),
                    if (ranking.coachName != null && ranking.coachName!.isNotEmpty)
                      pw.Text(
                        'Coach: ${ranking.coachName}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                      ),
                  ],
                ),
              ),
              _buildPdfCell(
                ranking.goldCount.toString(),
                alignment: pw.Alignment.center,
                fontWeight: pw.FontWeight.bold,
                color: ranking.goldCount > 0 ? PdfColors.amber : PdfColors.grey400,
              ),
              _buildPdfCell(
                ranking.silverCount.toString(),
                alignment: pw.Alignment.center,
                fontWeight: pw.FontWeight.bold,
                color: ranking.silverCount > 0 ? PdfColors.grey600 : PdfColors.grey400,
              ),
              _buildPdfCell(
                ranking.bronzeCount.toString(),
                alignment: pw.Alignment.center,
                fontWeight: pw.FontWeight.bold,
                color: ranking.bronzeCount > 0 ? PdfColors.brown : PdfColors.grey400,
              ),
              _buildPdfCell(
                ranking.totalMedals.toString(),
                alignment: pw.Alignment.center,
                fontWeight: pw.FontWeight.bold,
                fontSize: 14,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildPdfHeaderCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 12,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfCell(
    String text, {
    pw.Alignment alignment = pw.Alignment.centerLeft,
    pw.FontWeight? fontWeight,
    PdfColor? color,
    double fontSize = 11,
    pw.Widget? child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: child ??
          pw.Text(
            text,
            style: pw.TextStyle(
              fontWeight: fontWeight,
              color: color,
              fontSize: fontSize,
            ),
            textAlign: alignment == pw.Alignment.center 
                ? pw.TextAlign.center 
                : pw.TextAlign.left,
          ),
    );
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
          // Summary Cards - kept in UI
          _buildSummaryCards(),
          const SizedBox(height: 16),
          
          // Print Button above the table
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _printRankings,
                icon: const Icon(Icons.print),
                label: const Text('Print / Export PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
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