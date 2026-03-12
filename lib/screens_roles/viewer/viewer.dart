import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/team_service.dart';
import 'package:tabulation_systemv7/screens_roles/viewer/viewer_bracket.dart';

class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key});

  @override
  _BracketsNewScreenState createState() => _BracketsNewScreenState();
}

class _BracketsNewScreenState extends State<ViewerScreen> {
  final TeamParticipantsService _teamService = TeamParticipantsService();
  Map<String, String> _tournaments = {};
  List<String> _filteredTournaments = [];
  String? _selectedTournamentId;
  List<Map<String, dynamic>> _matchups = [];
  final TextEditingController _searchController = TextEditingController();
  bool _showDropdown = false;
  bool _ignoreFilter = false;

  bool _showPartialBrackets = true;
  Map<String, String> _teamNamesById = {};

  int _selectedIndex = 0;
  Timer? _refreshTimer;
  StreamSubscription? _matchupsSubscription;

  @override
  void initState() {
    super.initState();
    _fetchTournaments();
    _fetchTeams();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _matchupsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchTournaments() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('tournaments').get();
    setState(() {
      _tournaments = {
        for (var doc in snapshot.docs)
          doc['id'] as String: doc['name'] as String
      };
      _filteredTournaments = _tournaments.values.toList();
    });
  }

  Future<void> _fetchTeams() async {
    final teams = await _teamService.getTeams();
    setState(() {
      _teamNamesById = {
        for (var team in teams) team['id'] as String: team['name'] as String
      };
    });
  }

  void _fetchMatchups(String tournamentId) {
    _matchupsSubscription?.cancel();
    setState(() {
      _matchups = []; // Clear matchups immediately when switching tournaments
    });
    _matchupsSubscription = FirebaseFirestore.instance
        .collection('team_schedules')
        .where('tournamentSetupId', isEqualTo: tournamentId)
        .snapshots()
        .listen((snapshot) {
      // Ignore updates if the tournament has changed
      if (_selectedTournamentId != tournamentId) return;

      setState(() {
        var allMatchups = snapshot.docs
            .map((doc) => {
                  'id': doc['id'],
                  'teams': List<String>.from(doc['teams']),
                  'scores': doc['scores'] != null
                      ? Map<String, dynamic>.from(doc['scores'])
                      : {},
                  'winner': doc['winner']?.toString() ?? '',
                  'dateTime': doc['dateTime']?.toString() ?? 'Upcoming',
                })
            .toList();

        // Debug print to check fetched data
        for (var matchup in allMatchups) {
          print(
              'Fetched matchup for tournament $tournamentId: id=${matchup['id']}, teams=${matchup['teams']}, scores=${matchup['scores']}, winner=${matchup['winner']}');
        }

        _matchups = allMatchups;
      });
    });
  }

  void _filterTournaments(String query) {
    if (_ignoreFilter) {
      _ignoreFilter = false;
      return;
    }
    setState(() {
      _filteredTournaments = _tournaments.values
          .where((name) => name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _showDropdown = query.isNotEmpty && _filteredTournaments.isNotEmpty;
      if (query.isEmpty) {
        _matchupsSubscription?.cancel();
        _matchupsSubscription = null;
        _matchups = [];
        _selectedTournamentId = null;
      } else {
        // Clear previous tournament data when starting a new search
        _selectedTournamentId = null;
        _matchups = [];
        _matchupsSubscription?.cancel();
        _matchupsSubscription = null;
      }
    });
  }

  void _onTournamentSelected(String tournamentName) {
    final tournamentId = _tournaments.entries
        .firstWhere((entry) => entry.value == tournamentName,
            orElse: () => const MapEntry('', ''))
        .key;

    if (tournamentId.isNotEmpty) {
      _matchupsSubscription?.cancel();
      _matchupsSubscription = null;
      setState(() {
        _matchups = [];
        _selectedTournamentId = tournamentId;
        _ignoreFilter = true;
      });
      _fetchMatchups(tournamentId);
      _searchController.clear();
      _filteredTournaments.clear();
      _showDropdown = false;
    }
  }

  void _handleMatchupTap(Map<String, dynamic> matchup) {
    // Handle the tap event on a matchup card here
    print('Tapped matchup: \$matchup');
    // You can add navigation or dialog display logic here
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_selectedTournamentId != null) {
        _fetchMatchups(_selectedTournamentId!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Tournament Brackets',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_selectedTournamentId != null) {
                _fetchMatchups(_selectedTournamentId!);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search and tournament selection
            Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search tournaments...",
                  prefixIcon:
                      const Icon(Icons.search, color: Colors.deepPurple),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _filterTournaments('');
                            setState(() {
                              _selectedTournamentId = null;
                              _matchups = [];
                            });
                          },
                        )
                      : null,
                ),
                onChanged: _filterTournaments,
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Show On-going Tournaments'),
                Switch(
                  value: _showPartialBrackets,
                  onChanged: (value) {
                    setState(() {
                      _showPartialBrackets = value;
                      if (_selectedTournamentId != null) {
                        _fetchMatchups(_selectedTournamentId!);
                      }
                    });
                  },
                ),
              ],
            ),

            if (_showDropdown)
              Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _filteredTournaments.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(
                          _filteredTournaments[index],
                          style: const TextStyle(fontSize: 16),
                        ),
                        onTap: () =>
                            _onTournamentSelected(_filteredTournaments[index]),
                      );
                    },
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Tournament info section
            if (_selectedTournamentId != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.emoji_events, color: Colors.amber[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _tournaments[_selectedTournamentId]!,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_matchups.length} matchups',
                            style: TextStyle(
                              color: Colors.grey[600],
                            ),
                          ),
                          Chip(
                            label: Text(
                              _matchups.any((m) =>
                                      m['winner'].isNotEmpty &&
                                      m['teams'].isNotEmpty)
                                  ? 'Match Ended'
                                  : 'In Progress',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                            backgroundColor: _matchups.any((m) =>
                                    m['winner'].isNotEmpty &&
                                    m['teams'].isNotEmpty)
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Matchups section
            if (_matchups.isEmpty)
              Column(
                children: [
                  Image.asset(
                    'assets/logo1.jpg', // Replace with your own asset
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No matchups found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select a tournament to view its brackets',
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              )
            else
              ViewerBracketWidget(
                key: ValueKey(_selectedTournamentId),
                matchups: _matchups,
                teamNamesById: _teamNamesById,
                tournamentName:
                    _tournaments[_selectedTournamentId] ?? 'Tournament',
                onMatchupTap: _handleMatchupTap,
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (int index) {
          setState(() {
            _selectedIndex = index;
          });
          if (index == 1) {}
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.view_list),
            label: 'Teams',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Accounts',
          ),
        ],
      ),
    );
  }
}
