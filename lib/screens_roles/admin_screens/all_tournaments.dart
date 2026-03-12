import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/services/team_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:async';
import 'dart:typed_data';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/tournament_info.dart';

class BracketsNewScreen extends StatefulWidget {
  const BracketsNewScreen({super.key});

  @override
  _BracketsNewScreenState createState() => _BracketsNewScreenState();
}

class _BracketsNewScreenState extends State<BracketsNewScreen> {
  final TeamParticipantsService _teamService = TeamParticipantsService();
  Map<String, Map<String, dynamic>> _tournaments =
      {}; // Maps tournament ID -> Tournament Data
  List<Map<String, dynamic>> _filteredTournaments = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoadingInitialData = true;
  bool _hasError = false;
  Map<String, String> _teamNamesById = {};

  // Pagination variables
  int _currentPage = 0;
  static const int _itemsPerPage = 12; // Show 12 tournaments per page
  int get _totalPages => (_filteredTournaments.length / _itemsPerPage).ceil();

  List<Map<String, dynamic>> get _paginatedTournaments {
    final startIndex = _currentPage * _itemsPerPage;
    final endIndex =
        (startIndex + _itemsPerPage).clamp(0, _filteredTournaments.length);
    if (startIndex >= _filteredTournaments.length) {
      return [];
    }
    return _filteredTournaments.sublist(startIndex, endIndex);
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      setState(() {
        _currentPage++;
      });
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    }
  }

  void _goToPage(int page) {
    if (page >= 0 && page < _totalPages) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoadingInitialData = true;
    });
    try {
      await Future.wait([
        _fetchTournaments(),
        _fetchTeams(),
      ]).timeout(const Duration(seconds: 10));
    } catch (e) {
      print('Error loading initial data: $e');
      // Optionally show a snackbar or dialog with error
    } finally {
      setState(() {
        _isLoadingInitialData = false;
      });
    }
  }

  Future<void> _fetchTournaments() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('tournaments').get();
    setState(() {
      _tournaments = {
        for (var doc in snapshot.docs)
          if (doc.data().containsKey('name') && doc['name'] != null)
            doc.id: doc.data()
      };
      _filteredTournaments = _tournaments.values.toList();
    });
  }

  Future<void> _fetchTeams() async {
    final teams = await _teamService.getTeams();
    setState(() {
      // Teams fetched but not stored since not needed in this screen anymore
    });
  }

  void _filterTournaments(String query) {
    setState(() {
      _filteredTournaments = _tournaments.values
          .where((tournament) => (tournament['name'] as String)
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    });
  }

  void _onTournamentSelected(Map<String, dynamic> tournament) {
    final tournamentId = _tournaments.entries
        .firstWhere((entry) => entry.value == tournament,
            orElse: () => const MapEntry('', {}))
        .key;

    if (tournamentId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BracketViewScreen(
            tournamentId: tournamentId,
            tournamentName: tournament['name'] ?? 'Unknown',
          ),
        ),
      );
      _searchController.clear();
      _filteredTournaments = _tournaments.values.toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: _isLoadingInitialData
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2))
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: "Search Tournament",
                        prefixIcon: const Icon(Icons.search,
                            color: Color.fromARGB(255, 0, 0, 0)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: _filterTournaments,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 5,
                              mainAxisSpacing: 5,
                              childAspectRatio:
                                  1.1, // Increased aspect ratio to prevent overflow
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            itemCount: _paginatedTournaments.length,
                            itemBuilder: (context, index) {
                              final tournament = _paginatedTournaments[index];
                              final tournamentName =
                                  tournament['name'] ?? 'Unknown';
                              final category = tournament['category'] ?? 'N/A';
                              final sport = tournament['sport'] ?? 'N/A';
                              final eliminationType =
                                  tournament['eliminationType'] ?? 'N/A';
                              final status = tournament['status'] ?? 'N/A';

                              // Modern color scheme based on status
                              Color cardColor1, cardColor2;
                              Color textColor = Colors.white;

                              switch (status.toLowerCase()) {
                                case 'active':
                                  cardColor1 =
                                      const Color.fromARGB(255, 21, 38, 112);
                                  cardColor2 =
                                      const Color.fromARGB(255, 139, 164, 175);

                                  break;

                                case 'inactive':
                                  cardColor1 =
                                      const Color.fromARGB(255, 21, 38, 112);
                                  cardColor2 =
                                      const Color.fromARGB(255, 139, 164, 175);
                                  break;
                                default:
                                  cardColor1 = const Color(0xFFFA709A);
                                  cardColor2 = const Color(0xFFFEE140);
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
                                          // Background pattern/dots for modern touch
                                          Positioned(
                                            top: -20,
                                            right: -20,
                                            child: Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white
                                                    .withOpacity(0.1),
                                              ),
                                            ),
                                          ),

                                          // Main content
                                          Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Header with icon and status badge
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              10),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .emoji_events_rounded,
                                                        size: 28,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                    Flexible(
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Flexible(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 8,
                                                                vertical: 4,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .white
                                                                    .withOpacity(
                                                                        0.2),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            20),
                                                                border:
                                                                    Border.all(
                                                                  color: Colors
                                                                      .white
                                                                      .withOpacity(
                                                                          0.3),
                                                                  width: 1,
                                                                ),
                                                              ),
                                                              child: Text(
                                                                status
                                                                    .toUpperCase(),
                                                                style:
                                                                    const TextStyle(
                                                                  fontSize: 8,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Colors
                                                                      .white,
                                                                  letterSpacing:
                                                                      0.5,
                                                                ),
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          GestureDetector(
                                                            onTap: () {
                                                              final tournamentId = _tournaments
                                                                  .entries
                                                                  .firstWhere(
                                                                      (entry) =>
                                                                          entry
                                                                              .value ==
                                                                          tournament,
                                                                      orElse: () =>
                                                                          const MapEntry(
                                                                              '',
                                                                              {}))
                                                                  .key;
                                                              if (tournamentId
                                                                  .isNotEmpty) {
                                                                showDialog(
                                                                  context:
                                                                      context,
                                                                  builder:
                                                                      (context) =>
                                                                          AlertDialog(
                                                                    title: const Text(
                                                                        'Tournament Information'),
                                                                    content:
                                                                        SizedBox(
                                                                      width:
                                                                          300,
                                                                      height:
                                                                          200,
                                                                      child: TournamentInfo(
                                                                          tournamentId:
                                                                              tournamentId),
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed:
                                                                            () =>
                                                                                Navigator.of(context).pop(),
                                                                        child: const Text(
                                                                            'Close'),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                              }
                                                            },
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(4),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Colors
                                                                    .white
                                                                    .withOpacity(
                                                                        0.2),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12),
                                                              ),
                                                              child: const Icon(
                                                                Icons
                                                                    .info_outline,
                                                                size: 16,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                const SizedBox(height: 16),

                                                // Tournament name with modern typography
                                                Text(
                                                  tournamentName,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),

                                                const SizedBox(height: 10),

                                                // Details with improved layout
                                                Expanded(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceEvenly,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Category with icon
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .category_rounded,
                                                            size: 16,
                                                            color: Colors.white
                                                                .withOpacity(
                                                                    0.8),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Category: $category',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white
                                                                    .withOpacity(
                                                                        0.95),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),

                                                      // Sport with icon
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .sports_rounded,
                                                            size: 16,
                                                            color: Colors.white
                                                                .withOpacity(
                                                                    0.8),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Sport: $sport',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white
                                                                    .withOpacity(
                                                                        0.95),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),

                                                      //Elimination type with icon
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .format_list_bulleted_rounded,
                                                            size: 16,
                                                            color: Colors.white
                                                                .withOpacity(
                                                                    0.8),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Type: $eliminationType',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white
                                                                    .withOpacity(
                                                                        0.95),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),

                                                      // Teams with icon
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.group_rounded,
                                                            size: 16,
                                                            color: Colors.white
                                                                .withOpacity(
                                                                    0.8),
                                                          ),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Teams: ${(tournament['teams'] as List<dynamic>?)?.map((teamId) => _teamNamesById[teamId] ?? teamId).join(', ') ?? 'N/A'}',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white
                                                                    .withOpacity(
                                                                        0.95),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                // Bottom indicator/divider
                                                Container(
                                                  height: 2,
                                                  margin: const EdgeInsets.only(
                                                      top: 12),
                                                  decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            2),
                                                    color: Colors.white
                                                        .withOpacity(0.3),
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
                        ),
                        // Pagination Controls - Always Visible
                        Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // First Page Button
                              IconButton(
                                onPressed: _currentPage > 0
                                    ? () => _goToPage(0)
                                    : null,
                                icon: const Icon(Icons.first_page),
                                tooltip: 'First Page',
                              ),
                              // Previous Page Button
                              IconButton(
                                onPressed:
                                    _currentPage > 0 ? _previousPage : null,
                                icon: const Icon(Icons.chevron_left),
                                tooltip: 'Previous Page',
                              ),
                              const SizedBox(width: 16),
                              // Page Info
                              Text(
                                'Page ${_currentPage + 1} of ${_totalPages > 0 ? _totalPages : 1}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Next Page Button
                              IconButton(
                                onPressed: _currentPage < _totalPages - 1
                                    ? _nextPage
                                    : null,
                                icon: const Icon(Icons.chevron_right),
                                tooltip: 'Next Page',
                              ),
                              // Last Page Button
                              IconButton(
                                onPressed: _currentPage < _totalPages - 1
                                    ? () => _goToPage(_totalPages - 1)
                                    : null,
                                icon: const Icon(Icons.last_page),
                                tooltip: 'Last Page',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class BracketViewScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;

  const BracketViewScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
  });

  @override
  _BracketViewScreenState createState() => _BracketViewScreenState();
}

class _BracketViewScreenState extends State<BracketViewScreen> {
  final TeamParticipantsService _teamService = TeamParticipantsService();
  List<Map<String, dynamic>> _matchups = [];
  Map<String, String> _teamNamesById = {};
  List<Map<String, dynamic>> _teamRankings = [];
  StreamSubscription<QuerySnapshot>? _matchupsSubscription;
  bool _isLoadingMatchups = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await _fetchTeams();
      _fetchMatchups();
    } catch (e) {
      print('Error loading data: $e');
      setState(() {
        _hasError = true;
        _isLoadingMatchups = false;
      });
    }
  }

  Future<void> _fetchTeams() async {
    final teams = await _teamService.getTeams();
    setState(() {
      _teamNamesById = {
        for (var team in teams) team['id'] as String: team['name'] as String
      };
    });
  }

  String _getTeamName(String teamId) {
    return _teamNamesById[teamId] ?? teamId;
  }

  String _formatDateTime(String dateTimeString) {
    try {
      // Handle different date formats from Firebase
      DateTime dateTime;

      // Check if it's a Firebase Timestamp object (converted to string)
      if (dateTimeString.contains('Timestamp') ||
          dateTimeString.contains('seconds')) {
        // Handle Firebase Timestamp format like "Timestamp(seconds=1704067200, nanoseconds=0)"
        final secondsMatch =
            RegExp(r'seconds=(\d+)').firstMatch(dateTimeString);
        if (secondsMatch != null) {
          final seconds = int.parse(secondsMatch.group(1)!);
          dateTime = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        } else {
          return dateTimeString; // fallback
        }
      }
      // Handle ISO format: 2024-01-15T14:30:00.000Z or 2024-01-15T14:30:00
      else if (dateTimeString.contains('T')) {
        dateTime = DateTime.parse(dateTimeString);
      }
      // Handle custom format: 15/1/2024 14:30
      else if (dateTimeString.contains('/')) {
        final parts = dateTimeString.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('/');
          final timeParts = parts[1].split(':');
          if (dateParts.length == 3 && timeParts.length == 2) {
            dateTime = DateTime(
              int.parse(dateParts[2]), // year
              int.parse(dateParts[1]), // month
              int.parse(dateParts[0]), // day
              int.parse(timeParts[0]), // hour
              int.parse(timeParts[1]), // minute
            );
          } else {
            return dateTimeString; // fallback
          }
        } else {
          return dateTimeString; // fallback
        }
      }
      // Handle dash-separated format: 2024-01-15 14:30:00
      else if (dateTimeString.contains('-') && dateTimeString.contains(':')) {
        final parts = dateTimeString.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('-');
          final timeParts = parts[1].split(':');
          if (dateParts.length == 3 && timeParts.length >= 2) {
            dateTime = DateTime(
              int.parse(dateParts[0]), // year
              int.parse(dateParts[1]), // month
              int.parse(dateParts[2]), // day
              int.parse(timeParts[0]), // hour
              int.parse(timeParts[1]), // minute
            );
          } else {
            return dateTimeString; // fallback
          }
        } else {
          return dateTimeString; // fallback
        }
      }
      // Handle numeric timestamp (milliseconds since epoch)
      else if (int.tryParse(dateTimeString) != null) {
        final timestamp = int.tryParse(dateTimeString);
        if (timestamp != null) {
          // Check if it's seconds or milliseconds
          if (timestamp > 1e10) {
            // Likely milliseconds
            dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else {
            // Likely seconds
            dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
          }
        } else {
          return dateTimeString; // fallback
        }
      } else {
        return dateTimeString; // fallback
      }

      // Format to readable format: Jan 15, 2024 2:30 PM
      return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
    } catch (e) {
      print('Error formatting date: $dateTimeString - $e');
      return dateTimeString; // fallback to original string if parsing fails
    }
  }

  void _fetchMatchups() {
    // Cancel previous subscription if exists
    _matchupsSubscription?.cancel();

    // Get the tournament document to read matchups directly
    FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .get()
        .then((tournamentDoc) {
      if (tournamentDoc.exists) {
        final tournamentData = tournamentDoc.data();
        if (tournamentData != null && tournamentData.containsKey('matchups')) {
          final matchupsData =
              tournamentData['matchups'] as List<dynamic>? ?? [];

          setState(() {
            _matchups = matchupsData.map((matchup) {
              final matchupMap = matchup as Map<String, dynamic>;
              return {
                'id': matchupMap['id'] ?? '',
                'teams': List<String>.from(matchupMap['teams'] ?? []),
                'scores': Map<String, dynamic>.from(matchupMap['scores'] ?? {}),
                'winner': matchupMap['winner']?.toString() ?? '',
                'dateTime': _formatDateTime(
                    matchupMap['dateTime']?.toString() ?? 'Upcoming'),
              };
            }).toList();
            _isLoadingMatchups = false;
            _calculateTeamRankings();
          });
        } else {
          // No matchups field, set empty
          setState(() {
            _matchups = [];
            _isLoadingMatchups = false;
            _calculateTeamRankings();
          });
        }
      } else {
        // Tournament not found, set loading to false
        setState(() {
          _isLoadingMatchups = false;
        });
      }
    }).catchError((error) {
      print('Error fetching tournament: $error');
      setState(() {
        _isLoadingMatchups = false;
      });
    });
  }

  // Organize matches into rounds for bracket display
  List<List<Map<String, dynamic>>> _organizeMatchesIntoRounds() {
    if (_matchups.isEmpty) return [];

    // Simple approach: organize by match index assuming tournament progression
    // Round 1: first half of matches, Round 2: second half, etc.
    int totalMatches = _matchups.length;
    int numRounds = 1;

    // Calculate number of rounds based on total matches
    if (totalMatches > 1) {
      numRounds = (totalMatches / 2).ceil() + 1;
    }

    List<List<Map<String, dynamic>>> bracketRounds = [];
    for (int r = 0; r < numRounds; r++) {
      bracketRounds.add([]);
    }

    // Distribute matches across rounds
    for (int i = 0; i < totalMatches; i++) {
      int roundIndex = i % numRounds;
      if (roundIndex < bracketRounds.length) {
        bracketRounds[roundIndex].add(_matchups[i]);
      }
    }

    // Remove empty rounds
    bracketRounds.removeWhere((round) => round.isEmpty);

    return bracketRounds;
  }

  // Build a proper bracket visualization with horizontal rounds
  Widget _buildBracketWidget() {
    if (_matchups.isEmpty) {
      return _buildEmptyBracket();
    }

    final rounds = _organizeMatchesIntoRounds();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: rounds.asMap().entries.map((entry) {
          final roundIndex = entry.key;
          final roundMatches = entry.value;

          return _buildRoundColumn(roundIndex, roundMatches, rounds.length);
        }).toList(),
      ),
    );
  }

  // Build a single column for a round
  Widget _buildRoundColumn(int roundIndex,
      List<Map<String, dynamic>> roundMatches, int totalRounds) {
    String roundName = _getRoundName(roundIndex, totalRounds);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Round header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _getRoundColor(roundIndex, totalRounds),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              roundName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Matches in this round
          ...roundMatches.asMap().entries.map((entry) {
            final matchIndex = entry.key;
            final match = entry.value;
            return _buildBracketMatch(
                match, roundIndex, matchIndex, roundMatches.length);
          }),
        ],
      ),
    );
  }

  String _getRoundName(int roundIndex, int totalRounds) {
    if (totalRounds <= 1) return 'Matches';

    int roundsFromEnd = totalRounds - 1 - roundIndex;

    switch (roundsFromEnd) {
      case 0:
        return 'Finals';
      case 1:
        return 'Semifinals';
      case 2:
        return 'Quarterfinals';
      default:
        return 'Round ${roundIndex + 1}';
    }
  }

  Color _getRoundColor(int roundIndex, int totalRounds) {
    int roundsFromEnd = totalRounds - 1 - roundIndex;

    switch (roundsFromEnd) {
      case 0:
        return Colors.amber.shade700; // Finals - gold
      case 1:
        return Colors.deepPurple; // Semifinals
      case 2:
        return Colors.blue.shade700; // Quarterfinals
      default:
        return Colors.blueGrey; // Earlier rounds
    }
  }

  // Build a single match in the bracket
  Widget _buildBracketMatch(Map<String, dynamic> match, int roundIndex,
      int matchIndex, int totalMatchesInRound) {
    final teams = match['teams'] as List<String>;
    final winner = match['winner']?.toString() ?? '';
    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    final isFinalMatch =
        roundIndex == _organizeMatchesIntoRounds().length - 1 &&
            winner.isNotEmpty;

    // Calculate spacing based on round
    double verticalSpacing = 20.0;
    if (roundIndex > 0) {
      verticalSpacing = 40.0 * (roundIndex);
    }

    return Column(
      children: [
        // Connection line from previous round (if not first round)
        if (roundIndex > 0)
          Container(
            width: 2,
            height: verticalSpacing,
            color: Colors.grey.shade400,
          ),

        // Match card
        Container(
          width: 180,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: winner.isNotEmpty ? Colors.green : Colors.grey.shade300,
                width: winner.isNotEmpty ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Match label
                  Text(
                    'Match ${matchIndex + 1}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Team 1
                  if (teams.isNotEmpty)
                    _buildBracketTeam(
                      teams.length > 0 ? teams[0] : '',
                      scores,
                      winner,
                    ),

                  // VS divider
                  if (teams.length >= 2) ...[
                    Container(
                      height: 1,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    _buildBracketTeam(
                      teams[1],
                      scores,
                      winner,
                    ),
                  ] else if (teams.length == 1) ...[
                    Container(
                      height: 1,
                      color: Colors.grey.shade300,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                    ),
                    _buildBracketTeam(
                      teams[0],
                      scores,
                      winner,
                      isBye: true,
                    ),
                  ],

                  // Winner indicator
                  if (winner.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isFinalMatch
                            ? Colors.amber.shade100
                            : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isFinalMatch
                                ? Icons.emoji_events
                                : Icons.check_circle,
                            size: 12,
                            color: isFinalMatch
                                ? Colors.amber.shade700
                                : Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isFinalMatch ? 'Champion' : 'Winner',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isFinalMatch
                                  ? Colors.amber.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Connection line to next round (if not last round)
        if (roundIndex < _organizeMatchesIntoRounds().length - 1)
          Container(
            width: 2,
            height: verticalSpacing,
            color: Colors.grey.shade400,
          ),
      ],
    );
  }

  // Build a team display in the bracket
  Widget _buildBracketTeam(
      String teamId, Map<String, dynamic> scores, String matchWinner,
      {bool isBye = false}) {
    final teamName = _getTeamName(teamId);
    final isWinner = teamId == matchWinner;
    final score = scores[teamId]?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isWinner ? Colors.amber.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isWinner ? Colors.amber : Colors.grey.shade300,
          width: isWinner ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              teamName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.w500,
                color: isWinner ? Colors.amber.shade800 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (score.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isWinner ? Colors.amber : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                score,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color:
                      isWinner ? Colors.amber.shade800 : Colors.grey.shade700,
                ),
              ),
            ),
          if (isWinner)
            const Icon(
              Icons.check_circle,
              size: 14,
              color: Colors.green,
            ),
        ],
      ),
    );
  }

  void _calculateTeamRankings() {
    Map<String, Map<String, dynamic>> teamStats = {};

    // Identify champion from final matchup using _resolveWinnerFromString
    String? championTeamId;
    if (_matchups.isNotEmpty) {
      var finalMatch = _matchups.last;
      String winnerStr = finalMatch['winner']?.toString() ?? '';
      championTeamId = _resolveWinnerFromString(winnerStr, _matchups);
    }

    for (int i = 0; i < _matchups.length; i++) {
      var matchup = _matchups[i];
      var teams = matchup['teams'] as List<String>;
      var winner = matchup['winner']?.toString() ?? '';

      for (var teamId in teams) {
        if (!teamStats.containsKey(teamId)) {
          String teamName = _getTeamName(teamId);
          // Filter out placeholder names starting with "Winner of"
          if (teamName.startsWith("Winner of")) {
            continue;
          }
          teamStats[teamId] = {
            'teamId': teamId,
            'teamName': teamName,
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
          int basePoints = teams.length == 1 ? 1 : 3; // Lower points for bye
          int bonusPoints = i >= _matchups.length * 0.75
              ? 1
              : 0; // Higher points near championship
          teamStats[teamId]!['points'] += basePoints + bonusPoints;
        } else if (winner.isNotEmpty) {
          teamStats[teamId]!['losses'] += 1;
        }
      }
    }

    _teamRankings = teamStats.values.toList();

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
  }

  Widget _buildRankings() {
    if (_teamRankings.isEmpty) {
      return const SizedBox.shrink();
    }
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
    await Printing.layoutPdf(
      onLayout: (format) async => await _generatePdf(),
      name: '${widget.tournamentName}_Summary.pdf',
    );
  }

  Future<Uint8List> _generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Tournament Summary: ${widget.tournamentName}',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Team Rankings:',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
        final teams = matchup['teams'] as List<String>;
        final scores = matchup['scores'] as Map<String, dynamic>;
        final winner = matchup['winner']?.toString() ?? '';
        final isFinalMatch =
            (index == _matchups.length - 1) && winner.isNotEmpty;

        String resolvedWinner = '';
        if (winner.isNotEmpty) {
          if (isFinalMatch) {
            resolvedWinner = _resolveWinnerFromString(winner, _matchups);
          } else {
            resolvedWinner = _getTeamName(winner);
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Round indicator
                Text(
                  'Round ${index + 1}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 12),
                // Teams with scores
                if (teams.length == 2) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTeamScoreTile(
                          _getTeamName(teams[0]),
                          scores[teams[0]]?.toString() ?? '0',
                          winner == teams[0],
                        ),
                      ),
                      Container(
                        width: 2,
                        height: 40,
                        color: Colors.grey,
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(
                        child: _buildTeamScoreTile(
                          _getTeamName(teams[1]),
                          scores[teams[1]]?.toString() ?? '0',
                          winner == teams[1],
                        ),
                      ),
                    ],
                  ),
                ] else if (teams.length == 1) ...[
                  _buildTeamScoreTile(
                    _getTeamName(teams[0]),
                    scores[teams[0]]?.toString() ?? '0',
                    winner == teams[0],
                    isBye: true,
                  ),
                ],
                const SizedBox(height: 12),
                // Winner announcement
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: winner.isNotEmpty
                        ? Colors.green.shade100
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    winner.isNotEmpty
                        ? (isFinalMatch
                            ? '🏆 Champion: $resolvedWinner'
                            : 'Winner: $resolvedWinner')
                        : 'Winner: TBD',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: winner.isNotEmpty
                          ? Colors.green[800]
                          : Colors.grey[700],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyBracket() {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'No Matchups Available',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 0, 0, 0),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This tournament has no scheduled matches yet.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamScoreTile(String teamName, String score, bool isWinner,
      {bool isBye = false}) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isWinner ? Colors.amber.shade100 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isWinner ? Colors.amber : Colors.grey.shade300,
          width: isWinner ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            teamName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.amber.shade800 : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Score: $score',
            style: TextStyle(
              fontSize: 14,
              color: isWinner ? Colors.amber.shade700 : Colors.grey.shade700,
            ),
          ),
          if (isBye)
            Text(
              '(Bye)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          widget.tournamentName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                const Color.fromARGB(255, 22, 38, 129),
                const Color.fromARGB(255, 62, 66, 80),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: Colors.white),
            onPressed: _printSummary,
            tooltip: 'Print Summary',
          ),
        ],
      ),
      body: _isLoadingMatchups
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Expanded(
                    child: _matchups.isEmpty
                        ? _buildEmptyBracket()
                        : _buildBracketWidget(),
                  ),
                  if (_teamRankings.isNotEmpty) _buildRankings(),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _matchupsSubscription?.cancel();
    super.dispose();
  }
}
