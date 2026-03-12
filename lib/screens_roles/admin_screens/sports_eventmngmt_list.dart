import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/tournament_mngmt_dialog.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';
import 'package:tabulation_systemv7/authentication/login.dart';
import 'package:uuid/uuid.dart';

class SportsEventManagementList extends StatefulWidget {
  const SportsEventManagementList({super.key});

  @override
  _SportsEventManagementListState createState() =>
      _SportsEventManagementListState();
}

class _SportsEventManagementListState extends State<SportsEventManagementList> {
  final SportsEventService _sportsEventService = SportsEventService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'active';
  DateTime? _startDate;
  DateTime? _endDate;

  // Debounce timer for search
  DateTime? _lastSearchTime;
  static const _searchDelay = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final now = DateTime.now();
    final newQuery = _searchController.text.trim();
    
    // Update search query immediately for UI
    setState(() {
      _searchQuery = newQuery;
    });
    
    // Debounce the actual filter
    if (_lastSearchTime != null &&
        now.difference(_lastSearchTime!) < _searchDelay) {
      return;
    }
    
    _lastSearchTime = now;
    
    Future.delayed(_searchDelay, () {
      if (mounted) {
        setState(() {});
      }
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
        title: const Text('Sports Event Management'),
        backgroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Sports Event'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => _showAddOrEditSportsEventDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _sportsEventService.getSportsEventsStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading sports events.'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allEvents = snapshot.data!.docs.toList();
            final query = _searchController.text.toLowerCase();
            final events = query.isEmpty
                ? allEvents
                : allEvents.where((doc) {
                    final name = (doc.data() as Map<String, dynamic>)['name']
                            ?.toLowerCase() ??
                        '';
                    return name.contains(query);
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
                          const Text('Sports Events'),
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
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Start')),
                        DataColumn(label: Text('End')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: _SportsEventDataSource(events, context,
                          _sportsEventService, _showAddOrEditSportsEventDialog),
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

  void _showAddOrEditSportsEventDialog(BuildContext context,
      {String? eventId,
      String? currentName,
      String? currentStatus,
      String? currentDescription,
      DateTime? currentStartDate,
      DateTime? currentEndDate,
      String? currentLocation}) {
    _nameController.text = currentName ?? '';
    _descriptionController.text = currentDescription ?? '';
    _locationController.text = currentLocation ?? '';
    _startDateController.text = currentStartDate != null
        ? currentStartDate.toLocal().toString().split(' ')[0]
        : '';
    _endDateController.text = currentEndDate != null
        ? currentEndDate.toLocal().toString().split(' ')[0]
        : '';
    _selectedStatus = currentStatus ?? 'active';
    _startDate = currentStartDate;
    _endDate = currentEndDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              Text(eventId == null ? 'Add Sports Event' : 'Edit Sports Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Sports Event Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  controller: _startDateController,
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                            _startDateController.text =
                                picked.toLocal().toString().split(' ')[0];
                          });
                        }
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  controller: _endDateController,
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() {
                            _endDate = picked;
                            _endDateController.text =
                                picked.toLocal().toString().split(' ')[0];
                          });
                        }
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final name = _nameController.text.trim();
                final description = _descriptionController.text.trim();
                final location = _locationController.text.trim();

                // Validation: Name is required
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sports Event Name is required.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                // Validation: Check for duplicate name
                bool nameExists =
                    await _sportsEventService.sportsEventNameExists(name);
                if (nameExists && (eventId == null || currentName != name)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'A sports event with this name already exists.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                // Validation: Start and End dates
                if (_startDate == null || _endDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Both start and end dates are required.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                if (!_startDate!.isBefore(_endDate!)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Start date must be before end date.',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.red.shade600,
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                  return;
                }

                // Validation: Only one active event
                if (_selectedStatus == 'active') {
                  bool hasActive =
                      await _sportsEventService.hasActiveSportsEvent();
                  if (hasActive &&
                      (eventId == null || currentStatus != 'active')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Only one active sports event is allowed at a time.',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red.shade600,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                    return;
                  }
                }
                if (eventId == null) {
                  // Add new event - force status to active as only active events are allowed
                  final eventData = {
                    'id': const Uuid().v4(),
                    'name': name,
                    'description': description,
                    'startDate': _startDate,
                    'endDate': _endDate,
                    'location': location,
                    'status': 'active',
                    'createdAt': DateTime.now(),
                    'updatedAt': DateTime.now(),
                  };
                  try {
                    await _sportsEventService.addSportsEvent(eventData);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sports Event Added Successfully',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                } else {
                  // Update existing event
                  try {
                    await _sportsEventService.updateSportsEvent(eventId, {
                      'name': name,
                      'description': description,
                      'startDate': _startDate,
                      'endDate': _endDate,
                      'location': location,
                      'status': _selectedStatus,
                      'updatedAt': DateTime.now(),
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sports Event Updated Successfully',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green.shade600,
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              child: Text(eventId == null ? 'Add Event' : 'Update Event'),
            ),
          ],
        );
      },
    );
  }
}

class _SportsEventDataSource extends DataTableSource {
  final List<DocumentSnapshot> _events;
  final BuildContext _context;
  final SportsEventService _sportsEventService;
  final Function(BuildContext,
      {String? eventId,
      String? currentName,
      String? currentStatus,
      String? currentDescription,
      DateTime? currentStartDate,
      DateTime? currentEndDate,
      String? currentLocation}) _showDialog;

  _SportsEventDataSource(
      this._events, this._context, this._sportsEventService, this._showDialog);

  @override
  DataRow? getRow(int index) {
    if (index >= _events.length) return null;
    final event = _events[index];
    final eventId = event.id;
    final name = event['name'] ?? '';
    final description = event['description'] ?? '';
    final startDate = event['startDate'] != null
        ? (event['startDate'] as Timestamp).toDate()
        : null;
    final endDate = event['endDate'] != null
        ? (event['endDate'] as Timestamp).toDate()
        : null;
    final location = event['location'] ?? '';
    final status = event['status'] ?? 'active';

    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(name)),
        DataCell(Text(description)),
        DataCell(Text(startDate != null
            ? startDate.toLocal().toString().split(' ')[0]
            : 'N/A')),
        DataCell(Text(endDate != null
            ? endDate.toLocal().toString().split(' ')[0]
            : 'N/A')),
        DataCell(Text(location)),
        DataCell(
          GestureDetector(
            onTap: () => _showStatusChangeDialog(_context, eventId, status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: status == 'active'
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: status == 'active' ? Colors.green : Colors.red,
                  width: 1,
                ),
              ),
              child: Text(
                status == 'active' ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: status == 'active' ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 80,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () {
                    _showDialog(_context,
                        eventId: eventId,
                        currentName: name,
                        currentStatus: status,
                        currentDescription: description,
                        currentStartDate: startDate,
                        currentEndDate: endDate,
                        currentLocation: location);
                  },
                ),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    bool? confirm = await showDialog<bool>(
                      context: _context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirm Delete'),
                        content: const Text(
                            'Are you sure you want to delete this sports event?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      try {
                        await _sportsEventService.deleteSportsEvent(eventId);
                        ScaffoldMessenger.of(_context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Sports Event Deleted Successfully',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(_context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _events.length;

  @override
  int get selectedRowCount => 0;

  void _showStatusChangeDialog(
      BuildContext context, String eventId, String currentStatus) async {
    final newStatus = currentStatus == 'active' ? 'inactive' : 'active';

    // If trying to activate, check if there's already an active event
    if (newStatus == 'active') {
      bool hasActive = await _sportsEventService.hasActiveSportsEvent();
      if (hasActive) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Only one active sports event is allowed at a time.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Status'),
        content: Text(
            'Are you sure you want to change the status to ${newStatus == 'active' ? 'Active' : 'Inactive'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor:
                  newStatus == 'active' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Change'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _sportsEventService.updateSportsEvent(eventId, {
          'status': newStatus,
          'updatedAt': DateTime.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Status Updated Successfully',
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

        // Log out the user if status was changed
        await FirebaseAuth.instance.signOut();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
