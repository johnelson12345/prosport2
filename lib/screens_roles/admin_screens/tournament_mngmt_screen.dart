import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/tournament_mngmt_dialog.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/schedules.dart';

class TournamentManagementScreen extends StatefulWidget {
  const TournamentManagementScreen({super.key});

  @override
  State<TournamentManagementScreen> createState() =>
      _TournamentManagementScreenState();
}

class _TournamentManagementScreenState
    extends State<TournamentManagementScreen> {
  final TournamentService _tournamentService = TournamentService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterTournaments);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterTournaments() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Management'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Tournament'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.height * 0.8,
                    child: Column(
                      children: [
                        // Custom App Bar for Dialog
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 5, 18, 37),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16),
                              topRight: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Create New Tournament',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close,
                                    color: Colors.white),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                        ),
                        // Tournament Setup Content
                        const Expanded(
                          child: TournamentSetupScreen(),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.schedule),
            label: const Text('Schedules'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.9,
                  child: const SchedulesManagementScreen(),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _tournamentService.getTournamentStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No tournaments found.'));
            }

            final allTournaments = snapshot.data!.docs.toList();
            final query = _searchController.text.toLowerCase();
            final tournaments = query.isEmpty
                ? allTournaments
                : allTournaments.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name']?.toLowerCase() ?? '';
                    final category = data['category']?.toLowerCase() ?? '';
                    final sport = data['sport']?.toLowerCase() ?? '';
                    final gender = data['gender']?.toLowerCase() ?? '';
                    final venue = data['venue']?.toLowerCase() ?? '';
                    return name.contains(query) ||
                        category.contains(query) ||
                        sport.contains(query) ||
                        gender.contains(query) ||
                        venue.contains(query);
                  }).toList();

            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: SizedBox(
                    width: constraints.maxWidth,
                    child: PaginatedDataTable(
                      header: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Tournaments'),
                          SizedBox(
                            width: 200,
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Search',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: _clearSearch,
                                        tooltip: 'Clear search',
                                      )
                                    : null,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      rowsPerPage: 8,
                      showCheckboxColumn: false,
                      columnSpacing: 30,
                      horizontalMargin: 10,
                      columns: const [
                        DataColumn(label: Text('No.')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Sport')),
                        DataColumn(label: Text('Gender')),
                        DataColumn(label: Text('Venue')),
                        DataColumn(label: Text('Elimination Type')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _TournamentDataSource(
                          tournaments, context, _tournamentService),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _TournamentDataSource extends DataTableSource {
  final List<DocumentSnapshot> _tournaments;
  final BuildContext _context;
  final TournamentService _tournamentService;

  _TournamentDataSource(
      this._tournaments, this._context, this._tournamentService);

  @override
  DataRow? getRow(int index) {
    if (index >= _tournaments.length) return null;
    final doc = _tournaments[index];
    final data = doc.data() as Map<String, dynamic>;

    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(data['name'] ?? 'N/A')),
        DataCell(Text(data['category'] ?? 'N/A')),
        DataCell(Text(data['sport'] ?? 'N/A')),
        DataCell(Text(data['gender'] ?? 'N/A')),
        DataCell(Text(data['venue'] ?? 'N/A')),
        DataCell(Text(data['eliminationType'] ?? 'N/A')),
        DataCell(Text(data['status'] ?? 'N/A')),
        DataCell(
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: _context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Tournament'),
                  content: const Text(
                      'Are you sure you want to delete this tournament?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _tournamentService.deleteTournament(doc.id);
              }
            },
            tooltip: 'Delete',
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _tournaments.length;

  @override
  int get selectedRowCount => 0;
}
