import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tabulation_systemv7/services/participants_service.dart';
import 'package:intl/intl.dart';

/// =====================================================
/// PARTICIPANTS DATA SOURCE
/// =====================================================

class ParticipantsDataSource extends DataTableSource {
  final List<DocumentSnapshot> participants;
  final void Function(DocumentSnapshot participant) onEdit;
  final void Function(String participantId) onDelete;

  ParticipantsDataSource(this.participants, this.onEdit, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= participants.length) return null;

    final participant = participants[index];
    final data = participant.data() as Map<String, dynamic>;

    final name = data['name'] ?? '';
    final coachName = data['coachName'] ?? '';
    final contactInfo = data['contactInfo'] ?? '';
    final dateCreated = _formatDateSafe(participant);
    final medals =
        (data['medals'] as List<dynamic>?)?.join(', ') ?? 'No medals';

    return DataRow(
      cells: [
        DataCell(Center(
          child: data.containsKey('imageBase64') &&
                  data['imageBase64'] != null &&
                  data['imageBase64'].isNotEmpty
              ? Image.memory(
                  base64Decode(data['imageBase64']),
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image),
                )
              : const Icon(Icons.image_not_supported),
        )),
        DataCell(Text(name)),
        DataCell(Text(coachName)),
        DataCell(Text(contactInfo)),
        DataCell(Text(dateCreated)),
        DataCell(Text(medals)),
        DataCell(
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit(participant);
              } else if (value == 'delete') {
                onDelete(participant.id);
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

  String _formatDateSafe(DocumentSnapshot participant) {
    try {
      final data = participant.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('dateCreated')) {
        return _formatDate(data['dateCreated']);
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  String _formatDate(dynamic dateCreated) {
    if (dateCreated == null) return 'N/A';

    DateTime date;
    if (dateCreated is Timestamp) {
      date = dateCreated.toDate();
    } else if (dateCreated is DateTime) {
      date = dateCreated;
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  @override
  int get rowCount => participants.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

class ParticipantsManagementScreen extends StatefulWidget {
  const ParticipantsManagementScreen({super.key});

  @override
  _ParticipantsManagementScreenState createState() =>
      _ParticipantsManagementScreenState();
}

class _ParticipantsManagementScreenState
    extends State<ParticipantsManagementScreen> {
  final ParticipantsService _participantsService = ParticipantsService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentPage = 1;
  final int _entriesPerPage = 10;
  List<DocumentSnapshot> _participants = [];
  List<DocumentSnapshot?> _lastDocumentsPerPage = [];
  bool _isLastPage = false;
  bool _isLoading = false;
  int _totalEntries = 0;
  String? _activeSportsEventName;

  @override
  void initState() {
    super.initState();
    _fetchParticipants(reset: true);
    _fetchTotalEntries();

    _searchController.addListener(() {
      final newQuery = _searchController.text.trim();
      if (newQuery != _searchQuery) {
        setState(() {
          _searchQuery = newQuery;
          _lastDocumentsPerPage = [];
          _currentPage = 1;
          _participants.clear();
          _isLastPage = false;
        });
        _fetchTotalEntries().then((_) {
          _fetchParticipants(reset: true);
        });
      }
    });
  }

  Future<void> _fetchTotalEntries() async {
    Query query = FirebaseFirestore.instance.collection('participants');
    if (_searchQuery.isNotEmpty) {
      query = query
          .where('name', isGreaterThanOrEqualTo: _searchQuery)
          .where('name', isLessThanOrEqualTo: '$_searchQuery\uf8ff');
    }
    // Use count aggregation query if supported, else fallback to get()
    try {
      final aggregateQuery = query.count();
      final aggregateSnapshot = await aggregateQuery.get();
      setState(() {
        _totalEntries = aggregateSnapshot.count!;
      });
    } catch (e) {
      // Fallback to get all documents and count
      final snapshot = await query.get();
      setState(() {
        _totalEntries = snapshot.docs.length;
      });
    }
  }

  Future<void> _fetchParticipants({bool reset = false, int? page}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    int fetchLimit =
        _entriesPerPage + 1; // Fetch one extra to check if next page exists

    Query query = FirebaseFirestore.instance
        .collection('participants')
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
      // Fetch pages sequentially only if needed to fill _lastDocumentsPerPage
      for (int i = _lastDocumentsPerPage.length; i < targetPage - 1; i++) {
        Query tempQuery = FirebaseFirestore.instance
            .collection('participants')
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
      // Show only _entriesPerPage documents, keep the extra to check next page
      if (snapshot.docs.length > _entriesPerPage) {
        _participants = snapshot.docs.sublist(0, _entriesPerPage);
        _isLastPage = false;
      } else {
        _participants = snapshot.docs;
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
      _fetchParticipants(page: _currentPage + 1);
    }
  }

  void _previousPage() {
    if (_currentPage > 1) {
      // For previous page, reset and fetch pages sequentially up to previous page
      _fetchParticipants(reset: true).then((_) {
        if (_currentPage > 2) {
          _fetchParticipants(page: _currentPage - 1);
        }
      });
    }
  }

  String _formatDate(dynamic dateCreated) {
    if (dateCreated == null) return 'N/A';

    DateTime date;
    if (dateCreated is Timestamp) {
      date = dateCreated.toDate();
    } else if (dateCreated is DateTime) {
      date = dateCreated;
    } else {
      return 'N/A';
    }

    return DateFormat('MMM dd, yyyy hh:mm a').format(date);
  }

  String _formatDateSafe(DocumentSnapshot participant) {
    try {
      final data = participant.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('dateCreated')) {
        return _formatDate(data['dateCreated']);
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  Widget _buildDataTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('participants').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.groups, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No teams/participants for this sports event.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check sports event management.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final allParticipants = snapshot.data!.docs;
        final query = _searchController.text.toLowerCase();
        final participants = query.isEmpty
            ? allParticipants
            : allParticipants.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name']?.toLowerCase() ?? '';
                final coach = data['coachName']?.toLowerCase() ?? '';
                return name.contains(query) || coach.contains(query);
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
                      const Text('Teams/Participants List'),
                      SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search Participants',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
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
                    DataColumn(label: Text('Logo')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Coach')),
                    DataColumn(label: Text('Contact')),
                    DataColumn(label: Text('Date Created')),
                    DataColumn(label: Text('Medals')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: ParticipantsDataSource(
                      participants, _editParticipant, _deleteParticipant),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showParticipantDialog({DocumentSnapshot? snapshot}) async {
    final formKey = GlobalKey<FormState>();
    String teamOrPlayerName = snapshot?['name'] ?? '';
    String coachName = snapshot?['coachName'] ?? '';
    String contactInfo = snapshot?['contactInfo'] ?? '';
    String? imageBase64 = snapshot?['imageBase64'];
    String? dateCreated = _getDateCreatedSafe(snapshot);
    XFile? selectedLogo;
    bool isLoading = false;

    Future<List<int>> compressImage(List<int> bytes) async {
      if (bytes.length > 500 * 1024) {
        debugPrint(
            'Warning: Image size ${bytes.length} bytes exceeds recommended limit');
        // TODO: Add actual compression logic here
      }

      return bytes;
    }

    Future<String> convertImageToBase64(XFile file) async {
      try {
        // Read file as bytes
        final bytes = await file.readAsBytes();
        debugPrint('Converting ${bytes.length} bytes to base64');

        // Compress image if too large (aim for under 500KB to stay safe with Firestore limits)
        final compressedBytes = await compressImage(bytes);

        // Convert to base64
        final base64String = base64Encode(compressedBytes);
        debugPrint('Base64 string length: ${base64String.length}');

        return base64String;
      } catch (e, stacktrace) {
        debugPrint('Error converting image to base64: $e');
        debugPrint('$stacktrace');
        throw Exception('Error converting image to base64: $e');
      }
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              selectedLogo =
                  await picker.pickImage(source: ImageSource.gallery);
              setDialogState(() {});
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                          const Icon(Icons.people, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              snapshot == null
                                  ? 'Add Unit/Department'
                                  : 'Edit Participant',
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
                    // Content with Flexible and SingleChildScrollView
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Unit/Department name'),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: teamOrPlayerName,
                                onSaved: (value) =>
                                    teamOrPlayerName = value ?? '',
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Required'
                                        : null,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter unit/department name',
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Coach Name'),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: coachName,
                                onSaved: (value) => coachName = value ?? '',
                                validator: (value) =>
                                    value == null || value.isEmpty
                                        ? 'Required'
                                        : null,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter coach name',
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text('Contact Info'),
                              const SizedBox(height: 8),
                              TextFormField(
                                initialValue: contactInfo,
                                onSaved: (value) => contactInfo = value ?? '',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  if (value.length != 11) {
                                    return 'Contact must be exactly 11 digits';
                                  }
                                  return null;
                                },
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  hintText: 'Enter 11-digit contact',
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (snapshot != null && dateCreated != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Date Created'),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.grey[300]!),
                                      ),
                                      child: Text(
                                        dateCreated,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              const Text('Upload Logo/Image'),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: pickImage,
                                icon: const Icon(Icons.image),
                                label: const Text('Choose File'),
                              ),
                              if (selectedLogo != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text('Selected: ${selectedLogo!.name}'),
                                    const SizedBox(height: 8),
                                    FutureBuilder<Uint8List>(
                                      future: selectedLogo!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error,
                                                    stackTrace) =>
                                                const Icon(Icons.broken_image),
                                          );
                                        } else {
                                          return const CircularProgressIndicator();
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              if (imageBase64 != null &&
                                  selectedLogo == null &&
                                  snapshot != null)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Current Image:'),
                                    const SizedBox(height: 8),
                                    Image.memory(
                                      base64Decode(imageBase64),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.broken_image),
                                    ),
                                  ],
                                ),
                              if (imageBase64 != null &&
                                  selectedLogo == null &&
                                  snapshot == null)
                                const Text('Image uploaded successfully'),
                              const SizedBox(height: 16),
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

                                        String? newImageBase64 = imageBase64;
                                        if (selectedLogo != null) {
                                          newImageBase64 =
                                              await convertImageToBase64(
                                                  selectedLogo!);
                                        }

                                        final participantData = {
                                          'name': teamOrPlayerName,
                                          'coachName': coachName,
                                          'contactInfo': contactInfo,
                                          'imageBase64': newImageBase64,
                                        };

                                        if (snapshot == null) {
                                          await _participantsService
                                              .addParticipant(participantData);
                                          await _fetchTotalEntries();
                                          int lastPage = ((_totalEntries - 1) ~/
                                                  _entriesPerPage) +
                                              1;
                                          await _fetchParticipants(
                                              page: lastPage);
                                        } else {
                                          await _participantsService
                                              .updateParticipant(
                                                  snapshot.id, participantData);
                                          await _fetchParticipants(
                                              page: _currentPage);
                                        }

                                        // Optional: show a success SnackBar
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
                                                        ? 'Participant Added Successfully'
                                                        : 'Participant Updated Successfully',
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
                                        // Show error message
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

  String? _getDateCreatedSafe(DocumentSnapshot? snapshot) {
    if (snapshot == null) return null;

    try {
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data != null && data.containsKey('dateCreated')) {
        return _formatDate(data['dateCreated']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildPaginationControls() {
    int totalPages = (_totalEntries / _entriesPerPage).ceil();

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

  void _editParticipant(DocumentSnapshot participant) =>
      _showParticipantDialog(snapshot: participant);

  void _deleteParticipant(String participantId) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content:
            const Text('Are you sure you want to delete this participant?'),
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
        _participantsService.deleteParticipant(participantId).then((_) async {
          // Fetch updated data
          await _fetchTotalEntries();
          await _fetchParticipants(reset: true);

          // Show success SnackBar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Participant Deleted Successfully',
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
        title: const Text('Team Management'),
        backgroundColor: Colors.white,
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Team/Participant'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => _showParticipantDialog(),
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
