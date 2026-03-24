import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../services/reports_analytics_service.dart';

class ReportsAnalytics extends StatefulWidget {
  const ReportsAnalytics({super.key});

  @override
  ReportsAnalyticsState createState() => ReportsAnalyticsState();
}

class ReportsAnalyticsState extends State<ReportsAnalytics> {
  final ReportsAnalyticsService _analyticsService = ReportsAnalyticsService();
  
  // Filter states
  DateTimeRange? _selectedDateRange;
  String? _selectedSport;
  String? _selectedCategory;
  bool _showFilters = false;
  
  // UI State
  int _selectedTab = 0;
  final List<String> _tabs = [
    'Overview',
    'Tournaments',
    'Matches',
    'Teams',
    'Medals',
    'Timeline',
  ];
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    await _analyticsService.loadAnalyticsData(
      startDateFilter: _selectedDateRange?.start,
      endDateFilter: _selectedDateRange?.end,
      sportFilter: _selectedSport,
      categoryFilter: _selectedCategory,
    );
    if (mounted) setState(() {});
  }
  
  Future<void> _applyFilters() async {
    await _loadData();
    if (mounted) setState(() {});
  }
  
  void _resetFilters() {
    setState(() {
      _selectedDateRange = null;
      _selectedSport = null;
      _selectedCategory = null;
    });
    _loadData();
  }
  
  Widget _buildFilterBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      initialDateRange: _selectedDateRange,
                    );
                    if (picked != null) {
                      setState(() => _selectedDateRange = picked);
                      await _applyFilters();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedDateRange == null
                                ? 'Select Date Range'
                                : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd, yyyy').format(_selectedDateRange!.end)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_analyticsService.uniqueSports.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: _selectedSport,
                      hint: const Text('Sport'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Sports')),
                        ..._analyticsService.uniqueSports.map((sport) => DropdownMenuItem(
                          value: sport,
                          child: Text(sport),
                        )).toList(),
                      ],
                      onChanged: (value) async {
                        setState(() => _selectedSport = value);
                        await _applyFilters();
                      },
                    ),
                  ),
                ),
              if (_selectedSport != null || _selectedCategory != null || _selectedDateRange != null)
                TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Clear'),
                ),
            ],
          ),
          if (_showFilters && _analyticsService.uniqueCategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _selectedCategory,
                          hint: const Text('Category'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Categories')),
                            ..._analyticsService.uniqueCategories.map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            )).toList(),
                          ],
                          onChanged: (value) async {
                            setState(() => _selectedCategory = value);
                            await _applyFilters();
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          GestureDetector(
            onTap: () => setState(() => _showFilters = !_showFilters),
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showFilters ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _showFilters ? 'Less Filters' : 'More Filters',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatCard(String title, dynamic value, Color color, IconData icon, {String? suffix}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: color),
            const SizedBox(height: 6),
            Text(
              value is double ? value.toStringAsFixed(1) : value.toString(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (suffix != null)
              Text(
                suffix,
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            const SizedBox(height: 2),
            Text(
              title,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPieChart(Map<String, int> data, String title, List<Color> colors) {
    if (data.isEmpty) return const SizedBox.shrink();
    
    final total = data.values.reduce((a, b) => a + b);
    final sections = data.entries.map((entry) {
      final index = data.keys.toList().indexOf(entry.key);
      final color = colors[index % colors.length];
      final percentage = total > 0 ? (entry.value / total * 100).toStringAsFixed(1) : '0';
      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${entry.key}\n$percentage%',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(height: 180, child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: data.entries.map((entry) {
                final index = data.keys.toList().indexOf(entry.key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 10, height: 10, color: colors[index % colors.length]),
                    const SizedBox(width: 4),
                    Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 11)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBarChart(Map<String, int> data, String title, Color color) {
    if (data.isEmpty) return const SizedBox.shrink();
    
    final List<MapEntry<String, int>> sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(8).toList();
    final maxValue = topEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxValue + 1,
                  barGroups: List.generate(topEntries.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: topEntries[index].value.toDouble(),
                          color: color,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < topEntries.length) {
                            return Transform.rotate(
                              angle: -0.5,
                              child: Text(
                                topEntries[index].key.length > 10 ? '${topEntries[index].key.substring(0, 8)}...' : topEntries[index].key,
                                style: const TextStyle(fontSize: 9),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildOverviewTab() {
    final summary = _analyticsService.getFullReport()['summary'];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Analytics Dashboard', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Stats Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard('Tournaments', summary['totalTournaments'], Colors.blue, Icons.emoji_events),
              _buildStatCard('Active', summary['activeTournaments'], Colors.green, Icons.play_circle),
              _buildStatCard('Matches', summary['totalMatches'], Colors.orange, Icons.sports),
              _buildStatCard('Completion', summary['completionRate'], Colors.purple, Icons.check_circle, suffix: '%'),
              _buildStatCard('Teams', summary['totalTeams'], Colors.teal, Icons.people),
              _buildStatCard('Venues', summary['totalVenues'], Colors.brown, Icons.location_on),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Distribution Charts
          _buildPieChart(
            _analyticsService.categoryDistribution,
            'Tournaments by Category',
            [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink],
          ),
          
          const SizedBox(height: 16),
          
          _buildPieChart(
            _analyticsService.sportDistribution,
            'Tournaments by Sport',
            [Colors.red, Colors.blue, Colors.green, Colors.orange, Colors.purple],
          ),
          
          const SizedBox(height: 16),
          
          _buildPieChart(
            _analyticsService.genderDistribution,
            'Gender Distribution',
            [Colors.blue, Colors.pink, Colors.purple],
          ),
          
          const SizedBox(height: 16),
          
          _buildBarChart(
            _analyticsService.statusDistribution,
            'Tournament Status',
            Colors.teal,
          ),
        ],
      ),
    );
  }
  
  Widget _buildTournamentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBarChart(
            _analyticsService.categoryDistribution,
            'Tournaments by Category',
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildBarChart(
            _analyticsService.sportDistribution,
            'Tournaments by Sport',
            Colors.green,
          ),
          const SizedBox(height: 16),
          _buildPieChart(
            _analyticsService.bracketTypeDistribution,
            'Bracket Types',
            [Colors.blue, Colors.orange],
          ),
          const SizedBox(height: 16),
          _buildPieChart(
            _analyticsService.eliminationTypeDistribution,
            'Elimination Types',
            [Colors.purple, Colors.teal, Colors.orange],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMatchesTab() {
    final matchReport = _analyticsService.getMatchCompletionReport();
    final topScoring = _analyticsService.getTopScoringMatchesReport();
    final closestMatches = _analyticsService.getClosestMatchesReport();
    final biggestWins = _analyticsService.getBiggestWinsReport();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Match Completion Stats
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Match Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total', matchReport['totalMatches'], Colors.blue, Icons.sports)),
                      Expanded(child: _buildStatCard('Completed', matchReport['completedMatches'], Colors.green, Icons.check_circle)),
                      Expanded(child: _buildStatCard('Pending', matchReport['pendingMatches'], Colors.orange, Icons.pending)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: matchReport['completionRate'] / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text('Completion Rate: ${matchReport['completionRate'].toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Matches by Bracket
          _buildBarChart(
            _analyticsService.matchesByBracket,
            'Matches by Bracket',
            Colors.purple,
          ),
          
          const SizedBox(height: 16),
          
          // Matches by Round
          _buildBarChart(
            _analyticsService.matchesByRound,
            'Matches by Round',
            Colors.orange,
          ),
          
          const SizedBox(height: 16),
          
          // Top Scoring Matches
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Highest Scoring Matches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Highest Total: ${topScoring['highestTotalScore']} points', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ...(topScoring['topScoringMatches'] as List).take(5).map((match) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 4, height: 30, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(match['tournamentName'] ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              Text('Match ${match['matchNumber']} - ${match['bracket']} bracket', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('${match['totalScore']} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Closest Matches
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Closest Matches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Smallest Margin: ${closestMatches['smallestMargin']} points', style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ...(closestMatches['closestMatches'] as List).take(5).map((match) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 4, height: 30, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(match['tournamentName'] ?? 'Unknown', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              Text('Margin: ${match['scoreDifference']} pts', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text('${match['totalScore']} pts', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTeamsTab() {
    final teamStandings = _analyticsService.getTeamStandingsReport();
    final topTeamsByWins = teamStandings['topTeamsByWins'] as List;
    final topTeamsByScore = teamStandings['topTeamsByAverageScore'] as List;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Team Statistics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildStatCard('Total Teams', teamStandings['totalTeams'], Colors.blue, Icons.people)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Top Teams by Wins
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top Teams by Wins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...List.generate(topTeamsByWins.take(10).length, (index) {
                    final team = topTeamsByWins[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              team['teamName'] ?? 'Unknown Team',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${team['wins']}W - ${team['losses']}L', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Avg: ${team['averageScore'].toStringAsFixed(1)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Top Teams by Average Score
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Top Teams by Average Score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...List.generate(topTeamsByScore.take(10).length, (index) {
                    final team = topTeamsByScore[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              team['teamName'] ?? 'Unknown Team',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${team['averageScore'].toStringAsFixed(1)} pts', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${team['wins']}W - ${team['losses']}L', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMedalsTab() {
    final medalReport = _analyticsService.getMedalStandingsReport();
    final medalStandings = medalReport['medalStandings'] as List;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Overall Medal Standings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text('Total Medal Winners: ${medalReport['totalMedalWinners']}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ...List.generate(medalStandings.take(20).length, (index) {
                    final team = medalStandings[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: index == 0 ? Colors.amber.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: index == 0 ? Colors.amber : index == 1 ? Colors.grey : index == 2 ? Colors.brown : Colors.grey[300],
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: index < 3 ? Colors.white : Colors.grey[600],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              team['teamName'] ?? 'Unknown Team',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Row(
                            children: [
                              _buildMedalBadge('🥇', team['gold'] ?? 0, Colors.amber),
                              const SizedBox(width: 8),
                              _buildMedalBadge('🥈', team['silver'] ?? 0, Colors.grey),
                              const SizedBox(width: 8),
                              _buildMedalBadge('🥉', team['bronze'] ?? 0, Colors.brown),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMedalBadge(String emoji, int count, Color color) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          Text(count.toString(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
  
  Widget _buildTimelineTab() {
    final timelineReport = _analyticsService.getTournamentTimelineReport();
    final timeline = timelineReport['timeline'] as List;
    final monthlyData = timelineReport['monthlyTournaments'] as Map<String, int>;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Tournament Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildBarChart(monthlyData, 'Tournaments by Month', Colors.blue),
                  const SizedBox(height: 16),
                  const Text('Recent Tournaments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  ...List.generate(timeline.reversed.take(20).length, (index) {
                    final item = timeline.reversed.toList()[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: Icon(Icons.emoji_events, size: 16, color: Colors.blue),
                      ),
                      title: Text(item['tournamentName'] ?? 'Unknown'),
                      subtitle: Text('${item['sport']} - ${item['category']}'),
                      trailing: Text(DateFormat('MMM dd, yyyy').format(item['date'])),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (_analyticsService.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_analyticsService.errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_analyticsService.errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = _selectedTab == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedTab = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isSelected ? Colors.blue : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                      child: Text(
                        _tabs[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.grey[600],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildOverviewTab(),
                _buildTournamentsTab(),
                _buildMatchesTab(),
                _buildTeamsTab(),
                _buildMedalsTab(),
                _buildTimelineTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}