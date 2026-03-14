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
  bool _isLoading = true;

  
  // Grid configuration
  final int _crossAxisCount = 2;
  final double _cardAspectRatio = 1.2;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
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
        
        // Fetch related data
        await _fetchCategoryName(data);
        await _fetchSportName(data);
        await _fetchOfficialNames(data);
        
        // Determine verification status
        bool isVerified = data['isVerified'] == true || data['status'] == 'Verified';
        data['verificationStatus'] = isVerified ? 'Verified' : 'Pending';
        
        tournaments.add(data);
      }

      setState(() {
        _tournaments = tournaments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tournaments: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            String name = userData['name'] ?? userData['displayName'] ?? userData['email'] ?? 'Unknown';
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

  List<Map<String, dynamic>> get _tournamentsToDisplay => _tournaments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // // Modern App Bar
          // SliverAppBar(
          //   expandedHeight: 120,
          //   floating: true,
          //   pinned: true,
          //   backgroundColor: Colors.deepPurple,
          //   foregroundColor: Colors.white,
          //   flexibleSpace: FlexibleSpaceBar(
          //     titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
          //     title: Row(
          //       children: [
          //         Container(
          //           padding: const EdgeInsets.all(8),
          //           decoration: BoxDecoration(
          //             color: Colors.white.withOpacity(0.2),
          //             borderRadius: BorderRadius.circular(12),
          //           ),
          //           child: const Icon(Icons.emoji_events, size: 24),
          //         ),
          //         const SizedBox(width: 12),
          //         const Text(
          //           'Medal Tally',
          //           style: TextStyle(
          //             fontSize: 24,
          //             fontWeight: FontWeight.w600,
          //             letterSpacing: 0.5,
          //           ),
          //         ),
          //       ],
          //     ),
          //     background: Container(
          //       decoration: BoxDecoration(
          //         gradient: LinearGradient(
          //           begin: Alignment.topLeft,
          //           end: Alignment.bottomRight,
          //           colors: [
          //             Colors.deepPurple,
          //             Colors.deepPurple.shade700,
          //           ],
          //         ),
          //       ),
          //     ),
          //   ),
          //   actions: [
          //     IconButton(
          //       icon: const Icon(Icons.refresh),
          //       onPressed: _loadTournaments,
          //       tooltip: 'Refresh',
          //     ),
          //     const SizedBox(width: 8),
          //   ],
          // ),
          
          // Search and Filter Section
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: const Text(
                'All Tournaments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.deepPurple,
                ),
              ),
            ),
          ),
          

          
          // Two-Column Grid of Tournament Cards
          _isLoading
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade400),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading tournaments...',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                )
                : _tournaments.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.sports_esports,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No tournaments found',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No tournaments found. Add a tournament to get started',
                              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: _crossAxisCount,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: _cardAspectRatio,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tournament = _tournamentsToDisplay[index];
                            return _buildModernTournamentCard(tournament);
                          },
                          childCount: _tournamentsToDisplay.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildModernTournamentCard(Map<String, dynamic> tournament) {
    final status = tournament['status'] ?? 'Unknown';
    final verificationStatus = tournament['verificationStatus'] ?? 'Pending';
    final isVerified = verificationStatus == 'Verified';
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => _showTournamentDetails(tournament),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with status indicator
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            _getStatusColor(status),
                            _getStatusColor(status).withOpacity(0.5),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tournament['name'] ?? 'Unnamed Tournament',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Verification badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isVerified ? Colors.green.shade200 : Colors.orange.shade200,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isVerified ? Icons.verified : Icons.pending_outlined,
                                  size: 12,
                                  color: isVerified ? Colors.green.shade600 : Colors.orange.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  verificationStatus,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isVerified ? Colors.green.shade700 : Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Two-column info grid
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      _buildInfoChip(
                        icon: Icons.category,
                        label: tournament['categoryName'] ?? 'N/A',
                        color: Colors.blue,
                      ),
                      _buildInfoChip(
                        icon: Icons.sports,
                        label: tournament['sportName'] ?? 'N/A',
                        color: Colors.green,
                      ),
                      _buildInfoChip(
                        icon: Icons.person,
                        label: tournament['officialNames'] ?? 'Not Assigned',
                        color: Colors.orange,
                      ),
                      _buildInfoChip(
                        icon: Icons.location_on,
                        label: tournament['venue'] ?? 'N/A',
                        color: Colors.red,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showTournamentDetails(tournament),
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: const Text('Details', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showBracket(tournament),
                        icon: const Icon(Icons.account_tree, size: 18),
                        label: const Text('Bracket', style: TextStyle(fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
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

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
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

  void _showTournamentDetails(Map<String, dynamic> tournament) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _TournamentDetailsSheet(tournament: tournament),
    );
  }

  void _showBracket(Map<String, dynamic> tournament) {
    TournamentOfficialBracketDialog.show(
      context: context,
      tournamentId: tournament['id'],
      tournamentName: tournament['name'] ?? 'Tournament',
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Completed':
        return Colors.blue;
      case 'Draft':
        return Colors.grey;
      case 'Verified':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }
}

// Modern Bottom Sheet for Tournament Details
class _TournamentDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> tournament;

  const _TournamentDetailsSheet({required this.tournament});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.info_outline, color: Colors.deepPurple, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tournament['name'] ?? 'Tournament Details',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tournament Information',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          
          // Details grid
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDetailSection('Basic Information', [
                    _buildDetailRow(Icons.category, 'Category', tournament['categoryName'] ?? 'N/A'),
                    _buildDetailRow(Icons.sports, 'Sport', tournament['sportName'] ?? 'N/A'),
                    _buildDetailRow(Icons.emoji_events, 'Type', tournament['eliminationType'] ?? 'N/A'),
                    _buildDetailRow(Icons.people, 'Gender', tournament['gender'] ?? 'Mixed'),
                  ]),
                  
                  const SizedBox(height: 20),
                  
                  _buildDetailSection('Location & Schedule', [
                    _buildDetailRow(Icons.location_on, 'Venue', tournament['venue'] ?? 'N/A'),
                    _buildDetailRow(Icons.calendar_today, 'Created', 
                        tournament['createdAt'] != null 
                            ? DateFormat('MMM dd, yyyy').format((tournament['createdAt'] as Timestamp).toDate())
                            : 'N/A'),
                  ]),
                  
                  const SizedBox(height: 20),
                  
                  _buildDetailSection('Officials & Status', [
                    _buildDetailRow(Icons.person, 'Official', tournament['officialNames'] ?? 'Not Assigned'),
                    _buildDetailRow(Icons.verified, 'Verification', tournament['verificationStatus'] ?? 'Pending',
                        valueColor: tournament['verificationStatus'] == 'Verified' ? Colors.green : Colors.orange),
                    _buildDetailRow(Icons.format_list_numbered, 'Matches', 
                        tournament['totalMatches']?.toString() ?? '0'),
                    _buildDetailRow(Icons.check_circle, 'Status', tournament['status'] ?? 'Unknown',
                        valueColor: _getStatusColor(tournament['status'])),
                  ]),
                ],
              ),
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      TournamentOfficialBracketDialog.show(
                        context: context,
                        tournamentId: tournament['id'],
                        tournamentName: tournament['name'] ?? 'Tournament',
                      );
                    },
                    icon: const Icon(Icons.account_tree),
                    label: const Text('View Bracket'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.deepPurple.shade700,
              ),
            ),
          ),
          const Divider(height: 0),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Completed':
        return Colors.blue;
      case 'Draft':
        return Colors.grey;
      case 'Verified':
        return Colors.purple;
      default:
        return Colors.orange;
    }
  }
}