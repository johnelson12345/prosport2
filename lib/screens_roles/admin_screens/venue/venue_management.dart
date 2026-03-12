import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/venue_service.dart';
import 'package:tabulation_systemv7/services/sports_list.dart';

/// =====================================================
/// VENUE DATA SOURCE
/// =====================================================

class VenueDataSource extends DataTableSource {
  final List<DocumentSnapshot> venues;
  final void Function(DocumentSnapshot venue) onEdit;
  final void Function(String venueId) onDelete;

  VenueDataSource(this.venues, this.onEdit, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= venues.length) return null;

    final doc = venues[index];
    final data = doc.data() as Map<String, dynamic>;

    final name = data['name'] ?? '';
    final sportName = data['sportName'] ?? '';

    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(name)),
        DataCell(Text(sportName)),
        DataCell(
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit(doc);
              } else if (value == 'delete') {
                onDelete(doc.id);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Edit')
                  ])),
              const PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red))
                  ])),
            ],
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => venues.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

/// =====================================================
/// MAIN SCREEN
/// =====================================================

class VenueManagementScreen extends StatefulWidget {
  const VenueManagementScreen({super.key});

  @override
  State<VenueManagementScreen> createState() => _VenueManagementScreenState();
}

class _VenueManagementScreenState extends State<VenueManagementScreen> {
  final VenueService _venueService = VenueService();
  final SportsService _sportsService = SportsService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _entriesPerPage = 10;
  List<DocumentSnapshot> _venues = [];
  List<DocumentSnapshot?> _lastDocumentsPerPage = [];
  bool _isLastPage = false;
  bool _isLoading = false;
  int _totalEntries = 0;

  // Debounce timer for search
  DateTime? _lastSearchTime;
  static const _searchDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _fetchVenues(reset: true);
    _fetchTotalEntries();

    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final now = DateTime.now();
    final newQuery = _searchController.text.trim();

    // Update search query immediately for UI
    setState(() {
      _searchQuery = newQuery;
    });

    // Debounce the actual fetch
    if (_lastSearchTime != null &&
        now.difference(_lastSearchTime!) < _searchDelay) {
      return;
    }

    _lastSearchTime = now;

    Future.delayed(_searchDelay, () {
      if (mounted) {
        setState(() {
          _lastDocumentsPerPage = [];
          _currentPage = 1;
          _venues.clear();
          _isLastPage = false;
        });
        _fetchTotalEntries().then((_) {
          _fetchVenues(reset: true);
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _lastDocumentsPerPage = [];
      _currentPage = 1;
      _venues.clear();
      _isLastPage = false;
    });
    _fetchTotalEntries().then((_) {
      _fetchVenues(reset: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTotalEntries() async {
    Query query = FirebaseFirestore.instance.collection('venues');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }
    try {
      final aggregateQuery = query.count();
      final aggregateSnapshot = await aggregateQuery.get();
      setState(() {
        _totalEntries = aggregateSnapshot.count!;
      });
    } catch (e) {
      final snapshot = await query.get();
      setState(() {
        _totalEntries = snapshot.docs.length;
      });
    }
  }

  Future<void> _fetchVenues({bool reset = false, int? page}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    int fetchLimit = _entriesPerPage + 1;

    Query query = FirebaseFirestore.instance
        .collection('venues')
        .orderBy('name')
        .orderBy(FieldPath.documentId)
        .limit(fetchLimit);

    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }

    if (reset) {
      _lastDocumentsPerPage = [];
      _currentPage = 1;
    }

    int targetPage = page ?? _currentPage;

    if (targetPage > 1) {
      for (int i = _lastDocumentsPerPage.length; i < targetPage - 1; i++) {
        Query tempQuery = FirebaseFirestore.instance
            .collection('venues')
            .orderBy('name')
            .orderBy(FieldPath.documentId)
            .limit(fetchLimit);
        if (_searchQuery.isNotEmpty) {
          tempQuery = tempQuery
              .where('name', isGreaterThanOrEqualTo: _searchQuery)
              .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
        }
        if (i > 0) {
          DocumentSnapshot? lastDoc = _lastDocumentsPerPage.isNotEmpty
              ? _lastDocumentsPerPage.last
              : null;
          if (lastDoc != null) {
            tempQuery = tempQuery.startAfter([
              lastDoc.get('name'),
              lastDoc.id,
            ]);
          }
        }
        final tempSnapshot = await tempQuery.get();
        if (tempSnapshot.docs.isNotEmpty) {
          if (_lastDocumentsPerPage.length < i + 1) {
            _lastDocumentsPerPage.add(tempSnapshot.docs.last);
          } else {
            _lastDocumentsPerPage[i] = tempSnapshot.docs.last;
          }
        }
      }
      DocumentSnapshot? lastDoc = _lastDocumentsPerPage.isNotEmpty
          ? _lastDocumentsPerPage[targetPage - 2]
          : null;
      if (lastDoc != null) {
        query = query.startAfter([
          lastDoc.get('name'),
          lastDoc.id,
        ]);
      }
    }

    final snapshot = await query.get();

    setState(() {
      if (snapshot.docs.length > _entriesPerPage) {
        _venues = snapshot.docs.sublist(0, _entriesPerPage);
        _isLastPage = false;
      } else {
        _venues = snapshot.docs;
        _isLastPage = true;
      }

      _currentPage = targetPage;

      if (_lastDocumentsPerPage.length < _currentPage) {
        _lastDocumentsPerPage
            .add(snapshot.docs.isNotEmpty ? snapshot.docs.last : null);
      } else {
        _lastDocumentsPerPage[_currentPage - 1] =
            snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      }

      _isLoading = false;
    });
  }

  void _nextPage() {
    if (!_isLastPage) {
      _fetchVenues(page: _currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      _fetchVenues(reset: true).then((_) {
        if (_currentPage > 2) {
          _fetchVenues(page: _currentPage - 1);
        }
      });
    }
  }

  Widget _buildDataTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _venueService.getVenuesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No venues available.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Click "Add Venue" to create one.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final allVenues = snapshot.data!.docs;
        final query = _searchController.text.toLowerCase();
        final venues = query.isEmpty
            ? allVenues
            : allVenues.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name']?.toLowerCase() ?? '';
                final sportName = data['sportName']?.toLowerCase() ?? '';
                return name.contains(query) || sportName.contains(query);
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
                      const Text('Venue List'),
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search Venues',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                    tooltip: 'Clear search',
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  rowsPerPage: 10,
                  showCheckboxColumn: false,
                  columnSpacing: 40,
                  columns: const [
                    DataColumn(label: Text('No.')),
                    DataColumn(label: Text('Venue Name')),
                    DataColumn(label: Text('Sport')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: VenueDataSource(venues, _editVenue, _deleteVenue),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showVenueDialog({DocumentSnapshot? snapshot}) async {
    final formKey = GlobalKey<FormState>();
    String venueName = snapshot?['name'] ?? '';
    String? selectedSportId = snapshot?['sportId'];
    String? selectedSportName = snapshot?['sportName'];
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                  maxWidth: 500,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              snapshot == null ? 'Add Venue' : 'Edit Venue',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Venue Name'),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: venueName,
                                onSaved: (value) => venueName = value ?? '',
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Venue name is required'
                                        : null,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter venue name',
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Sport'),
                              const SizedBox(height: 8),
                              StreamBuilder<QuerySnapshot>(
                                stream: _sportsService.getSportsStream(),
                                builder: (context, sportsSnapshot) {
                                  if (sportsSnapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const CircularProgressIndicator();
                                  }

                                  if (!sportsSnapshot.hasData ||
                                      sportsSnapshot.data!.docs.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.orange[50],
                                        borderRadius: BorderRadius.circular(8),
                                        border:
                                            Border.all(color: Colors.orange),
                                      ),
                                      child: const Row(
                                        children: [
                                          Icon(Icons.warning,
                                              color: Colors.orange),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'No sports available. Please add sports first.',
                                              style: TextStyle(
                                                  color: Colors.orange),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final sports = sportsSnapshot.data!.docs;

                                  // Set default values if editing
                                  if (selectedSportId == null &&
                                      sports.isNotEmpty) {
                                    selectedSportId = sports.first.id;
                                    selectedSportName = sports.first['name'];
                                  }

                                  return DropdownButtonFormField<String>(
                                    value: selectedSportId,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      hintText: 'Select a sport',
                                    ),
                                    items: sports.map<DropdownMenuItem<String>>(
                                      (sport) {
                                        return DropdownMenuItem<String>(
                                          value: sport.id,
                                          child: Text(sport['name'] ?? ''),
                                        );
                                      },
                                    ).toList(),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        selectedSportId = value;
                                        final selectedSport = sports.firstWhere(
                                          (s) => s.id == value,
                                          orElse: () => sports.first,
                                        );
                                        selectedSportName =
                                            selectedSport['name'];
                                      });
                                    },
                                    validator: (value) => value == null
                                        ? 'Please select a sport'
                                        : null,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (formKey.currentState!.validate()) {
                                      setDialogState(() => isLoading = true);

                                      try {
                                        formKey.currentState!.save();

                                        if (snapshot == null) {
                                          await _venueService.addVenue(
                                            venueName,
                                            selectedSportId!,
                                            selectedSportName!,
                                          );
                                          await _fetchTotalEntries();
                                          int lastPage = ((_totalEntries - 1) ~/
                                                  _entriesPerPage) +
                                              1;
                                          await _fetchVenues(page: lastPage);
                                        } else {
                                          await _venueService.updateVenue(
                                            snapshot.id,
                                            venueName,
                                            selectedSportId!,
                                            selectedSportName!,
                                          );
                                          await _fetchVenues(
                                              page: _currentPage);
                                        }

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.check_circle,
                                                    color: Colors.white),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    snapshot == null
                                                        ? 'Venue Added Successfully'
                                                        : 'Venue Updated Successfully',
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor:
                                                Colors.green.shade600,
                                            behavior: SnackBarBehavior.floating,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );

                                        Navigator.pop(context);
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Row(
                                              children: [
                                                const Icon(Icons.error,
                                                    color: Colors.white),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    'Error: ${e.toString()}',
                                                    style: const TextStyle(
                                                        color: Colors.white),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            backgroundColor:
                                                Colors.red.shade600,
                                            behavior: SnackBarBehavior.floating,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            duration:
                                                const Duration(seconds: 3),
                                          ),
                                        );
                                      } finally {
                                        setDialogState(() => isLoading = false);
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isLoading ? Colors.grey : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 16, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : Text(snapshot == null ? 'Add' : 'Update'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaginationControls() {
    int totalPages = (_totalEntries / _entriesPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton(
          onPressed: _currentPage > 1 ? _previousPage : null,
          child: const Text('Previous'),
        ),
        const SizedBox(width: 20),
        Text('Page $_currentPage of $totalPages ($_totalEntries entries)'),
        const SizedBox(width: 20),
        ElevatedButton(
          onPressed: !_isLastPage ? _nextPage : null,
          child: const Text('Next'),
        ),
      ],
    );
  }

  void _editVenue(DocumentSnapshot venue) => _showVenueDialog(snapshot: venue);

  void _deleteVenue(String venueId) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this venue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true) {
        _venueService.deleteVenue(venueId).then((_) async {
          await _fetchTotalEntries();
          await _fetchVenues(reset: true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Venue Deleted Successfully',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Venue Management'),
        backgroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Venue'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => _showVenueDialog(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Expanded(
              child: _buildDataTable(),
            ),
          ],
        ),
      ),
    );
  }
}
