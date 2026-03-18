// lib/screens/tabulator/tabulator_medal_tally.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/bracket.dart';

class TabulatorMedalTally extends StatefulWidget {
  const TabulatorMedalTally({super.key});

  @override
  State<TabulatorMedalTally> createState() => _TabulatorMedalTallyState();
}

class _TabulatorMedalTallyState extends State<TabulatorMedalTally> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _tournaments = [];
  List<Map<String, dynamic>> _filteredTournaments = [];
  bool _isLoading = true;
  
  // Search controller
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination variables
  static const int _defaultItemsPerPage = 9; // 3x3 grid
  int _itemsPerPage = 9;
  final List<int> _itemsPerPageOptions = [6, 9, 12, 15, 18]; // Options for grid layout
  int _currentPage = 1;
  List<Map<String, dynamic>> _paginatedTournaments = [];
  bool _hasMoreItems = true;
  
  final ScrollController _scrollController = ScrollController();

  // Primary color for buttons
  static const Color buttonColor = Color.fromARGB(255, 5, 18, 37);
  // Accent color for text and icons
  static const Color accentColor = Color(0xFF5E35B1);

  @override
  void initState() {
    super.initState();
    _loadTournaments();
    _searchController.addListener(_filterTournaments);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTournaments();
    }
  }

  void _loadMoreTournaments() {
    if (!_hasMoreItems) return;

    setState(() {
      final startIndex = _currentPage * _itemsPerPage;
      final endIndex = startIndex + _itemsPerPage;
      
      if (startIndex < _filteredTournaments.length) {
        final newItems = _filteredTournaments.sublist(
          startIndex, 
          endIndex > _filteredTournaments.length ? _filteredTournaments.length : endIndex
        );
        _paginatedTournaments.addAll(newItems);
        _currentPage++;
        _hasMoreItems = endIndex < _filteredTournaments.length;
      } else {
        _hasMoreItems = false;
      }
    });
  }

  void _resetPagination() {
    setState(() {
      _currentPage = 1;
      _hasMoreItems = true;
      _updatePaginatedTournaments();
      // Scroll to top
      _scrollController.jumpTo(0);
    });
  }

  void _updatePaginatedTournaments() {
    final endIndex = _itemsPerPage > _filteredTournaments.length 
        ? _filteredTournaments.length 
        : _itemsPerPage;
    
    _paginatedTournaments = _filteredTournaments.sublist(0, endIndex);
    _hasMoreItems = _filteredTournaments.length > _itemsPerPage;
    _currentPage = 1;
  }

  void _changeItemsPerPage(int? newValue) {
    if (newValue != null) {
      setState(() {
        _itemsPerPage = newValue;
        _resetPagination();
      });
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 1) {
      setState(() {
        _currentPage--;
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = startIndex + _itemsPerPage;
        _paginatedTournaments = _filteredTournaments.sublist(
          startIndex,
          endIndex > _filteredTournaments.length ? _filteredTournaments.length : endIndex
        );
        // Scroll to top
        _scrollController.jumpTo(0);
      });
    }
  }

  void _goToNextPage() {
    if (_hasMoreItems) {
      setState(() {
        _currentPage++;
        final startIndex = (_currentPage - 1) * _itemsPerPage;
        final endIndex = startIndex + _itemsPerPage;
        _paginatedTournaments = _filteredTournaments.sublist(
          startIndex,
          endIndex > _filteredTournaments.length ? _filteredTournaments.length : endIndex
        );
        _hasMoreItems = endIndex < _filteredTournaments.length;
        // Scroll to top
        _scrollController.jumpTo(0);
      });
    }
  }

  void _filterTournaments() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredTournaments = List.from(_tournaments);
      } else {
        _filteredTournaments = _tournaments.where((tournament) {
          final name = tournament['name']?.toString().toLowerCase() ?? '';
          final sport = tournament['sportName']?.toString().toLowerCase() ?? '';
          final category = tournament['categoryName']?.toString().toLowerCase() ?? '';
          final venue = tournament['venue']?.toString().toLowerCase() ?? '';
          final official = tournament['officialNames']?.toString().toLowerCase() ?? '';
          
          return name.contains(_searchQuery) ||
                 sport.contains(_searchQuery) ||
                 category.contains(_searchQuery) ||
                 venue.contains(_searchQuery) ||
                 official.contains(_searchQuery);
        }).toList();
      }
      _resetPagination();
    });
  }

  Future<void> _loadTournaments() async {
    setState(() => _isLoading = true);

    try {
      QuerySnapshot snapshot = await _firestore
          .collection('tournaments')
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> tournaments = [];
      
      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        
        await _fetchCategoryName(data);
        await _fetchSportName(data);
        await _fetchOfficialNames(data);
        await _fetchMedalTeams(data);
        
        bool isVerified = data['isVerified'] == true || data['status'] == 'Verified';
        data['verificationStatus'] = isVerified ? 'Verified' : 'Pending';
        
        tournaments.add(data);
      }

      setState(() {
        _tournaments = tournaments;
        _filteredTournaments = List.from(tournaments);
        _updatePaginatedTournaments();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: buttonColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _fetchCategoryName(Map<String, dynamic> data) async {
    if (data['categoryId'] != null) {
      try {
        DocumentSnapshot categoryDoc = await _firestore
            .collection('categories')
            .doc(data['categoryId'])
            .get();
        if (categoryDoc.exists) {
          data['categoryName'] = (categoryDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
        }
      } catch (e) {
        data['categoryName'] = 'Unknown';
      }
    } else {
      data['categoryName'] = data['category'] ?? 'N/A';
    }
  }

  Future<void> _fetchSportName(Map<String, dynamic> data) async {
    if (data['sportsEventId'] != null) {
      try {
        DocumentSnapshot sportDoc = await _firestore
            .collection('sportsEvents')
            .doc(data['sportsEventId'])
            .get();
        if (sportDoc.exists) {
          data['sportName'] = (sportDoc.data() as Map<String, dynamic>)['name'] ?? 'Unknown';
        }
      } catch (e) {
        data['sportName'] = 'Unknown';
      }
    } else {
      data['sportName'] = data['sport'] ?? 'N/A';
    }
  }

  Future<void> _fetchOfficialNames(Map<String, dynamic> data) async {
    if (data['assignedUsers'] != null && (data['assignedUsers'] as List).isNotEmpty) {
      List<String> officialNames = [];
      for (String userId in (data['assignedUsers'] as List)) {
        try {
          DocumentSnapshot userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
            String name = userData['name'] ?? 
                         userData['displayName'] ?? 
                         userData['fullName'] ?? 
                         userData['email'] ?? 
                         'Unknown';
            officialNames.add(name);
          }
        } catch (e) {
          officialNames.add('Unknown');
        }
      }
      data['officialNames'] = officialNames.join(', ');
    } else {
      data['officialNames'] = 'Not Assigned';
    }
  }

  Future<void> _fetchMedalTeams(Map<String, dynamic> data) async {
    try {
      if (data['medals'] != null) {
        Map<String, dynamic> medals = data['medals'] as Map<String, dynamic>;
        
        if (medals['gold'] != null) {
          data['goldTeam'] = await _getTeamName(medals['gold']);
          data['goldTeamId'] = medals['gold'];
        }
        if (medals['silver'] != null) {
          data['silverTeam'] = await _getTeamName(medals['silver']);
          data['silverTeamId'] = medals['silver'];
        }
        if (medals['bronze'] != null) {
          data['bronzeTeam'] = await _getTeamName(medals['bronze']);
          data['bronzeTeamId'] = medals['bronze'];
        }
        data['hasMedals'] = true;
      } else {
        data['hasMedals'] = false;
      }
    } catch (e) {
      data['hasMedals'] = false;
    }
  }

  Future<String> _getTeamName(String? teamId) async {
    if (teamId == null || teamId.isEmpty) return 'Not Assigned';
    try {
      DocumentSnapshot doc = await _firestore
          .collection('participants')
          .doc(teamId)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return data['name'] ?? data['teamName'] ?? data['coachName'] ?? 'Unknown';
      }
    } catch (e) {}
    return teamId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search tournaments...',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade500,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          size: 22,
                          color: accentColor,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, color: Colors.grey.shade600, size: 22),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
              ],
            ),
          ),
          
          // Pagination Controls and Results count
          if (!_isLoading && _filteredTournaments.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Items per page selector
                  Row(
                    children: [
                      const Text(
                        'Show:',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: PopupMenuButton<int>(
                          tooltip: 'Items per page',
                          onSelected: _changeItemsPerPage,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Text(
                                  '$_itemsPerPage',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                          itemBuilder: (BuildContext context) {
                            return _itemsPerPageOptions.map((int value) {
                              return PopupMenuItem<int>(
                                value: value,
                                child: Text(
                                  '$value items',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ],
                  ),
                  
                  // Results count
                  Text(
                    '${_filteredTournaments.length} tournament${_filteredTournaments.length != 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  
                  // Page navigation
                  Row(
                    children: [
                      IconButton(
                        onPressed: _currentPage > 1 ? _goToPreviousPage : null,
                        icon: Icon(
                          Icons.chevron_left,
                          size: 20,
                          color: _currentPage > 1 ? buttonColor : Colors.grey.shade300,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: buttonColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$_currentPage',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: buttonColor,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _hasMoreItems ? _goToNextPage : null,
                        icon: Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: _hasMoreItems ? buttonColor : Colors.grey.shade300,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                    ),
                  )
                : _filteredTournaments.isEmpty
                    ? _buildEmptyState()
                    : _buildTournamentGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: buttonColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events_outlined,
              size: 60,
              color: buttonColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isEmpty ? 'No Tournaments Found' : 'No Matching Tournaments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: buttonColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty 
                ? 'Tournaments will appear here'
                : 'Try adjusting your search',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTournamentGrid() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: GridView.builder(
              controller: _scrollController,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: _paginatedTournaments.length,
              itemBuilder: (context, index) {
                return _TournamentCard(
                  tournament: _paginatedTournaments[index],
                  onTap: () => _showTournamentDetails(_paginatedTournaments[index]),
                  onMedalTap: () => _showAssignMedalDialog(_paginatedTournaments[index]),
                );
              },
            ),
          ),
          
          // Loading indicator for scroll pagination
          if (_hasMoreItems && _paginatedTournaments.length < _filteredTournaments.length)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  void _showTournamentDetails(Map<String, dynamic> tournament) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TournamentDetailsSheet(
        tournament: tournament,
        onMedalAssigned: _loadTournaments,
      ),
    );
  }

  Future<void> _showAssignMedalDialog(Map<String, dynamic> tournament) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AssignMedalDialog(
        tournamentId: tournament['id'],
        tournamentName: tournament['name'] ?? 'Tournament',
        currentGoldId: tournament['goldTeamId'],
        currentSilverId: tournament['silverTeamId'],
        currentBronzeId: tournament['bronzeTeamId'],
      ),
    );

    if (result == true) {
      _loadTournaments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Medals saved successfully'),
            backgroundColor: buttonColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _TournamentCard extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final VoidCallback onTap;
  final VoidCallback onMedalTap;

  static const Color buttonColor = Color.fromARGB(255, 9, 34, 72);
  static const Color accentColor = Color.fromARGB(255, 9, 34, 72);

  const _TournamentCard({
    required this.tournament,
    required this.onTap,
    required this.onMedalTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasMedals = tournament['hasMedals'] == true;
    final status = tournament['status'] ?? 'unknown';
    final statusColor = status == 'active' ? Colors.green : Colors.orange;
    
    final int teamsCount = tournament['selectedTeamIds']?.length ?? 0;
    final int matchesCount = tournament['totalMatches'] ?? 0;
    final String bracketType = tournament['eliminationType'] ?? 'Single Elimination';
    final String gender = tournament['gender'] ?? 'Mixed';
    final String official = tournament['officialNames'] ?? 'Not Assigned';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: buttonColor.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tournament['name'] ?? 'Unnamed',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: accentColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tournament['sportName'] ?? 'Sport',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Bracket Type and Gender Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_tree, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              bracketType,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            gender == 'Men' ? Icons.male : 
                            gender == 'Women' ? Icons.female : 
                            Icons.people,
                            size: 14, 
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              gender,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Teams and Matches Count Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.groups, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$teamsCount Teams',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sports_score, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$matchesCount Matches',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Tournament Official
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        official,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Medal button
              if (hasMedals) ...[
                Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: buttonColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildMedalIndicator('G', Colors.amber, tournament['goldTeam']),
                      Container(width: 1, height: 20, color: Colors.grey.shade300),
                      _buildMedalIndicator('S', Colors.grey, tournament['silverTeam']),
                      Container(width: 1, height: 20, color: Colors.grey.shade300),
                      _buildMedalIndicator('B', Colors.brown, tournament['bronzeTeam']),
                    ],
                  ),
                ),
              ] else ...[
                SizedBox(
                  height: 36,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onMedalTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Assign Medals',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedalIndicator(String label, Color color, String? teamName) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              teamName != null ? (teamName.length > 5 ? '${teamName.substring(0, 4)}.' : teamName) : '-',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> tournament;
  final VoidCallback onMedalAssigned;

  static const Color buttonColor = Color.fromARGB(255, 5, 18, 37);
  static const Color accentColor = Color(0xFF5E35B1);

  const _TournamentDetailsSheet({
    required this.tournament,
    required this.onMedalAssigned,
  });

  @override
  Widget build(BuildContext context) {
    final int teamsCount = tournament['selectedTeamIds']?.length ?? 0;
    final int matchesCount = tournament['totalMatches'] ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: buttonColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.info_outline, color: accentColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tournament['name'] ?? 'Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Medal preview
          if (tournament['hasMedals'] == true) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: buttonColor.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: buttonColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    _buildMedalChip('GOLD', tournament['goldTeam'] ?? '-', Colors.amber),
                    Container(width: 1, height: 30, color: Colors.grey.shade300),
                    _buildMedalChip('SILVER', tournament['silverTeam'] ?? '-', Colors.grey),
                    Container(width: 1, height: 30, color: Colors.grey.shade300),
                    _buildMedalChip('BRONZE', tournament['bronzeTeam'] ?? '-', Colors.brown),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(Icons.sports, 'Sport', tournament['sportName'] ?? 'N/A'),
                  _buildInfoRow(Icons.category, 'Category', tournament['categoryName'] ?? 'N/A'),
                  _buildInfoRow(Icons.account_tree, 'Bracket Type', tournament['eliminationType'] ?? 'N/A'),
                  _buildInfoRow(Icons.people, 'Gender', tournament['gender'] ?? 'Mixed'),
                  _buildInfoRow(Icons.groups, 'Teams', '$teamsCount Teams'),
                  _buildInfoRow(Icons.sports_score, 'Matches', '$matchesCount Matches'),
                  _buildInfoRow(Icons.location_on, 'Venue', tournament['venue'] ?? 'N/A'),
                  _buildInfoRow(Icons.person, 'Official', tournament['officialNames'] ?? 'Not Assigned'),
                  _buildInfoRow(Icons.verified, 'Verification', tournament['verificationStatus'] ?? 'Pending'),
                  _buildInfoRow(Icons.calendar_today, 'Created', tournament['createdAt'] != null 
                      ? DateFormat('MMM dd, yyyy').format((tournament['createdAt'] as Timestamp).toDate())
                      : 'N/A'),
                ],
              ),
            ),
          ),
          
          // Action button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AssignMedalDialog(
                      tournamentId: tournament['id'],
                      tournamentName: tournament['name'] ?? 'Tournament',
                      currentGoldId: tournament['goldTeamId'],
                      currentSilverId: tournament['silverTeamId'],
                      currentBronzeId: tournament['bronzeTeamId'],
                    ),
                  ).then((result) {
                    if (result == true) onMedalAssigned();
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  tournament['hasMedals'] == true ? 'Edit Medals' : 'Assign Medals',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedalChip(String label, String team, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            team.length > 12 ? '${team.substring(0, 10)}...' : team,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class AssignMedalDialog extends StatefulWidget {
  final String tournamentId;
  final String tournamentName;
  final String? currentGoldId;
  final String? currentSilverId;
  final String? currentBronzeId;

  const AssignMedalDialog({
    super.key,
    required this.tournamentId,
    required this.tournamentName,
    this.currentGoldId,
    this.currentSilverId,
    this.currentBronzeId,
  });

  @override
  State<AssignMedalDialog> createState() => _AssignMedalDialogState();
}

class _AssignMedalDialogState extends State<AssignMedalDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Color buttonColor = Color.fromARGB(255, 5, 18, 37);
  static const Color accentColor = Color(0xFF5E35B1);
  
  List<Map<String, dynamic>> _participants = [];
  bool _isLoading = true;
  bool _showBracket = true;
  
  String? _selectedGoldId;
  String? _selectedSilverId;
  String? _selectedBronzeId;
  
  final Map<String, String> _teamNameCache = {};
  
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredParticipants = [];
  
  String? _activeMedal;

  @override
  void initState() {
    super.initState();
    _selectedGoldId = widget.currentGoldId;
    _selectedSilverId = widget.currentSilverId;
    _selectedBronzeId = widget.currentBronzeId;
    _loadParticipants();
    _searchController.addListener(_filterParticipants);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadParticipants() async {
    setState(() => _isLoading = true);

    try {
      DocumentSnapshot tournamentDoc = await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();

      List<String> teamIds = [];
      if (tournamentDoc.exists) {
        Map<String, dynamic> data = tournamentDoc.data() as Map<String, dynamic>;
        if (data['selectedTeamIds'] != null) {
          teamIds = List<String>.from(data['selectedTeamIds']);
        }
      }

      List<Map<String, dynamic>> participants = [];
      for (String teamId in teamIds) {
        try {
          DocumentSnapshot doc = await _firestore
              .collection('participants')
              .doc(teamId)
              .get();
          
          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            data['displayName'] = data['name'] ?? data['teamName'] ?? data['coachName'] ?? 'Unknown';
            participants.add(data);
            _teamNameCache[doc.id] = data['displayName'];
          }
        } catch (e) {}
      }

      participants.sort((a, b) => (a['displayName'] ?? '').compareTo(b['displayName'] ?? ''));

      setState(() {
        _participants = participants;
        _filteredParticipants = List.from(participants);
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterParticipants() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredParticipants = List.from(_participants);
      } else {
        _filteredParticipants = _participants.where((p) {
          final name = p['displayName']?.toString().toLowerCase() ?? '';
          return name.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _saveMedals() async {
    try {
      Map<String, dynamic> medals = {};
      if (_selectedGoldId != null) medals['gold'] = _selectedGoldId;
      if (_selectedSilverId != null) medals['silver'] = _selectedSilverId;
      if (_selectedBronzeId != null) medals['bronze'] = _selectedBronzeId;

      await _firestore
          .collection('tournaments')
          .doc(widget.tournamentId)
          .update({'medals': medals});

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _selectTeam(String teamId) {
    setState(() {
      if (_activeMedal == 'gold') {
        _selectedGoldId = teamId;
        _activeMedal = null;
      } else if (_activeMedal == 'silver') {
        _selectedSilverId = teamId;
        _activeMedal = null;
      } else if (_activeMedal == 'bronze') {
        _selectedBronzeId = teamId;
        _activeMedal = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: buttonColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.tournamentName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Toggle
            Container(
              padding: const EdgeInsets.all(14),
              color: Colors.grey.shade50,
              child: Row(
                children: [
                  Expanded(
                    child: _buildToggleButton('Bracket', Icons.account_tree, _showBracket),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToggleButton('Select Medals', Icons.emoji_events, !_showBracket),
                  ),
                ],
              ),
            ),

            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_showBracket)
              Expanded(
                child: TournamentOfficialBracketDialog(
                  tournamentId: widget.tournamentId,
                  tournamentName: widget.tournamentName,
                ),
              )
            else
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Medal selection tabs
                      Row(
                        children: [
                          _buildMedalTab('Gold', Colors.amber, 'gold'),
                          const SizedBox(width: 8),
                          _buildMedalTab('Silver', Colors.grey, 'silver'),
                          const SizedBox(width: 8),
                          _buildMedalTab('Bronze', Colors.brown, 'bronze'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Current selections
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: buttonColor.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            _buildSelectionBadge('GOLD', _selectedGoldId, Colors.amber),
                            Container(width: 1, height: 30, color: Colors.grey.shade300),
                            _buildSelectionBadge('SILVER', _selectedSilverId, Colors.grey),
                            Container(width: 1, height: 30, color: Colors.grey.shade300),
                            _buildSelectionBadge('BRONZE', _selectedBronzeId, Colors.brown),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Search
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search teams...',
                          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                          prefixIcon: Icon(Icons.search, size: 20, color: accentColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Teams list with pagination
                      Expanded(
                        child: _buildTeamsList(),
                      ),
                    ],
                  ),
                ),
              ),

            // Save button
            if (!_showBracket)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_selectedGoldId != null || 
                               _selectedSilverId != null || 
                               _selectedBronzeId != null) ? _saveMedals : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Save Medals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamsList() {
    // Add pagination for teams list
    const int teamsPerPage = 20;
    return ListView.builder(
      itemCount: _filteredParticipants.length,
      itemBuilder: (context, index) {
        final team = _filteredParticipants[index];
        return _buildTeamTile(team);
      },
    );
  }

  Widget _buildToggleButton(String label, IconData icon, bool isActive) {
    return InkWell(
      onTap: () => setState(() => _showBracket = !_showBracket),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? buttonColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isActive ? Colors.white : Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: isActive ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedalTab(String label, Color color, String medalType) {
    final isActive = _activeMedal == medalType;
    final isSelected = medalType == 'gold' ? _selectedGoldId != null :
                      medalType == 'silver' ? _selectedSilverId != null :
                      _selectedBronzeId != null;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeMedal = _activeMedal == medalType ? null : medalType;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? color.withOpacity(0.1) : Colors.transparent,
            border: Border.all(
              color: isActive ? color : Colors.grey.shade300,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected)
                Icon(Icons.check_circle, color: color, size: 16),
              if (isSelected) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: isActive ? color : Colors.grey.shade700,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBadge(String label, String? teamId, Color color) {
    final teamName = teamId != null ? _teamNameCache[teamId] ?? 'Selected' : 'Not set';
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            teamName.length > 12 ? '${teamName.substring(0, 10)}...' : teamName,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamTile(Map<String, dynamic> team) {
    final isGold = team['id'] == _selectedGoldId;
    final isSilver = team['id'] == _selectedSilverId;
    final isBronze = team['id'] == _selectedBronzeId;
    final isSelected = isGold || isSilver || isBronze;
    final isSelectable = _activeMedal != null && !isSelected;
    
    Color? medalColor;
    if (isGold) medalColor = Colors.amber;
    else if (isSilver) medalColor = Colors.grey;
    else if (isBronze) medalColor = Colors.brown;

    return InkWell(
      onTap: isSelectable ? () => _selectTeam(team['id']) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? medalColor!.withOpacity(0.05) : null,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: medalColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              )
            else if (_activeMedal != null)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400, width: 1.5),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team['displayName'] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (team['school'] != null)
                    Text(
                      team['school'],
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),
            if (isSelectable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _activeMedal == 'gold' ? Colors.amber.withOpacity(0.1) :
                          _activeMedal == 'silver' ? Colors.grey.withOpacity(0.1) :
                          Colors.brown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Select',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _activeMedal == 'gold' ? Colors.amber :
                           _activeMedal == 'silver' ? Colors.grey :
                           Colors.brown,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}