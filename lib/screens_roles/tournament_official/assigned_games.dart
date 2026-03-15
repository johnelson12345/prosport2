import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/bracket.dart';
import 'package:tabulation_systemv7/services/scores.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';
import 'package:tabulation_systemv7/services/team_service.dart';
import 'dart:async';

class TournamentDetailsNotifier
    extends ValueNotifier<Map<String, Map<String, dynamic>>> {
  TournamentDetailsNotifier(super.value);
}

class TournamentTeamScheduleManagementScreen extends StatefulWidget {
  const TournamentTeamScheduleManagementScreen({super.key});

  @override
  _TeamScheduleManagementScreenState createState() =>
      _TeamScheduleManagementScreenState();
}

class _TeamScheduleManagementScreenState
    extends State<TournamentTeamScheduleManagementScreen> {
  final TeamScheduleService _service = TeamScheduleService();
  final TournamentService _tournamentService = TournamentService();
  final TeamParticipantsService _teamParticipantsService =
      TeamParticipantsService();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy hh:mm a');

  late TournamentDetailsNotifier _tournamentDetailsNotifier;
  Map<String, String> _tournamentNames = {};
  Map<String, String> _teamDetails = {};
  Map<String, String> _userEmails = {};
  Map<String, String> _userNames = {};

  String _searchQuery = "";
  String? _currentUserId;
  DateTime? _selectedDate;
  int _currentPage = 0;
  int _itemsPerPage = 20;
  bool _isAddingMatch = false;
  final bool _isEditingMatch = false;

  @override
  void initState() {
    super.initState();
    _tournamentDetailsNotifier = TournamentDetailsNotifier({});
    _loadTournamentData();
    _loadTeamsData();
    _loadUserEmails();
    _getCurrentUser();
  }

  void _getCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() {
          _currentUserId = user.uid;
        });
      }
    } catch (e) {
    }
  }

  void _loadTournamentData() async {
    _tournamentService.getTournamentStream().listen((snapshot) {
      final Map<String, String> names = {};
      final Map<String, Map<String, dynamic>> details = {};
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        names[data['id']] = data['name'] ?? 'Unnamed Tournament';
        details[data['id']] = {
          'docId': doc.id,
          'name': data['name'] ?? 'Unnamed Tournament',
          'sportId': data['sportId'] ?? '',
          'categoryId': data['categoryId'] ?? '',
          'gender': data['gender'] ?? 'Unknown',
          'venue': data['venue'] ?? 'Not specified',
          'eliminationType': data['eliminationType'] ?? 'Single Elimination',
          'assignedUsers': data['assignedUsers'] ?? [],
          'status': data['status'] is String ? data['status'] : 'Active',
          'selectedTeamIds': data['selectedTeamIds'] ?? [],
          'isCompleted': data['isCompleted'] ?? false,
          'completedAt': data['completedAt'],
          'completedBy': data['completedBy'],
          'lastUpdated': data['lastUpdated'],
          'matchups': data['matchups'] ?? [],
        };
      }
      setState(() {
        _tournamentNames = names;
        _tournamentDetailsNotifier.value = details;
      });
    });
  }

  // New method to get tournaments with matches directly from Firestore
  Stream<List<Map<String, dynamic>>> _getTournamentsWithMatches() {
    return FirebaseFirestore.instance
        .collection('tournaments')
        .snapshots()
        .map((snapshot) {
      List<Map<String, dynamic>> tournaments = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        
        // Only include tournaments the user is assigned to
        if (_currentUserId != null) {
          final assignedUsers = data['assignedUsers'] as List<dynamic>? ?? [];
          if (!assignedUsers.contains(_currentUserId)) {
            continue;
          }
        }
        
        // Get matches from the matchups array
        final matches = (data['matchups'] as List<dynamic>? ?? [])
            .map((match) => match as Map<String, dynamic>)
            .toList();
        
        // Add tournament info to each match
        for (var match in matches) {
          match['tournamentSetupId'] = data['id'];
          match['tournamentName'] = data['name'] ?? 'Unnamed Tournament';
          match['sport'] = data['sport'] ?? 'Unknown';
          match['category'] = data['category'] ?? 'Unknown';
          match['gender'] = data['gender'] ?? 'Unknown';
          match['venue'] = data['venue'] ?? 'Not specified';
        }
        
        tournaments.add({
          'id': data['id'],
          'name': data['name'] ?? 'Unnamed Tournament',
          'sport': data['sport'] ?? 'Unknown',
          'category': data['category'] ?? 'Unknown',
          'gender': data['gender'] ?? 'Unknown',
          'venue': data['venue'] ?? 'Not specified',
          'status': data['status'] ?? 'active',
          'assignedUsers': data['assignedUsers'] ?? [],
          'selectedTeamIds': data['selectedTeamIds'] ?? [],
          'matchups': matches,
          'totalMatches': data['totalMatches'] ?? matches.length,
          'isCompleted': data['isCompleted'] ?? false,
        });
      }
      
      return tournaments;
    });
  }

  Future<void> _refreshTournamentData() async {
    setState(() {});
    
    try {
      final snapshot = await _tournamentService.getTournamentStream().first;
      final Map<String, String> names = {};
      final Map<String, Map<String, dynamic>> details = {};
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        names[data['id']] = data['name'] ?? 'Unnamed Tournament';
        details[data['id']] = {
          'docId': doc.id,
          'name': data['name'] ?? 'Unnamed Tournament',
          'sportId': data['sportId'] ?? '',
          'categoryId': data['categoryId'] ?? '',
          'gender': data['gender'] ?? 'Unknown',
          'venue': data['venue'] ?? 'Not specified',
          'eliminationType': data['eliminationType'] ?? 'Single Elimination',
          'assignedUsers': data['assignedUsers'] ?? [],
          'status': data['status'] is String ? data['status'] : 'Active',
          'selectedTeamIds': data['selectedTeamIds'] ?? [],
          'isCompleted': data['isCompleted'] ?? false,
          'completedAt': data['completedAt'],
          'completedBy': data['completedBy'],
          'lastUpdated': data['lastUpdated'],
          'matchups': data['matchups'] ?? [],
        };
      }
      
      setState(() {
        _tournamentNames = names;
        _tournamentDetailsNotifier.value = details;
      });
    } catch (e) {
    }
  }

  Future<void> _showEditMatchDialog(
      String tournamentId, Map<String, dynamic> match) async {
    if (_isEditingMatch) return;

    final tournamentTeams = await _getTournamentTeams(tournamentId);

    String? selectedTeam1 = match['team1Id'];
    String? selectedTeam2 = match['team2Id'];
    DateTime? selectedDateTime;
    try {
      selectedDateTime =
          DateTime.parse(match['dateTime'] ?? match['startTime'] ?? '');
    } catch (e) {
      selectedDateTime = DateTime.now();
    }

    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Edit Match',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Container(
                width: 400,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: isProcessing ? 0.5 : 1.0,
                      child: AbsorbPointer(
                        absorbing: isProcessing,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Team 1',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: selectedTeam1,
                                  hint: const Text('Select Team'),
                                  items: tournamentTeams
                                      .map<DropdownMenuItem<String>>((team) {
                                    return DropdownMenuItem<String>(
                                      value: team['id'] as String,
                                      child: Text(team['name'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTeam1 = value;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              const Text('Team 2',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: selectedTeam2,
                                  hint: const Text('Select Team'),
                                  items: tournamentTeams
                                      .map<DropdownMenuItem<String>>((team) {
                                    return DropdownMenuItem<String>(
                                      value: team['id'] as String,
                                      child: Text(team['name'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      selectedTeam2 = value;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),

                              const Text('Schedule',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              const SizedBox(height: 8),

                              InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        selectedDateTime ?? DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                          selectedDateTime ?? DateTime.now()),
                                    );
                                    if (time != null) {
                                      setState(() {
                                        selectedDateTime = DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                          time.hour,
                                          time.minute,
                                        );
                                      });
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today,
                                          size: 18,
                                          color: Colors.grey.shade600),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          selectedDateTime == null
                                              ? 'Select Date & Time'
                                              : _displayDateFormat
                                                  .format(selectedDateTime!),
                                          style: TextStyle(
                                            color: selectedDateTime == null
                                                ? Colors.grey.shade500
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                      Icon(Icons.arrow_drop_down,
                                          color: Colors.grey.shade600),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    if (isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(top: 20, bottom: 8),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text(
                                'Updating match...',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (selectedTeam1 == null ||
                              selectedTeam2 == null ||
                              selectedDateTime == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Please select teams and schedule')),
                            );
                            return;
                          }

                          if (selectedTeam1 == selectedTeam2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Please select different teams')),
                            );
                            return;
                          }

                          setState(() {
                            isProcessing = true;
                          });

                          try {
                            final team1 = tournamentTeams
                                .firstWhere((t) => t['id'] == selectedTeam1);
                            final team2 = tournamentTeams
                                .firstWhere((t) => t['id'] == selectedTeam2);

                            // Update the match in the tournament's matchups array
                            final tournamentQuery = await FirebaseFirestore.instance
                                .collection('tournaments')
                                .where('id', isEqualTo: tournamentId)
                                .limit(1)
                                .get();

                            if (tournamentQuery.docs.isNotEmpty) {
                              final tournamentDoc = tournamentQuery.docs.first;
                              final tournamentData = tournamentDoc.data();
                              final matchups = List<Map<String, dynamic>>.from(tournamentData['matchups'] ?? []);
                              
                              final matchIndex = matchups.indexWhere((m) => m['id'] == match['id']);
                              if (matchIndex != -1) {
                                matchups[matchIndex] = {
                                  ...matchups[matchIndex],
                                  'team1': team1,
                                  'team2': team2,
                                  'team1Id': team1['id'],
                                  'team2Id': team2['id'],
                                  'team1Name': team1['name'],
                                  'team2Name': team2['name'],
                                  'dateTime': _dateFormat.format(selectedDateTime!),
                                  'startTime': _dateFormat.format(selectedDateTime!),
                                };
                                
                                await tournamentDoc.reference.update({
                                  'matchups': matchups,
                                  'updatedAt': FieldValue.serverTimestamp(),
                                });
                              }
                            }

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Match updated successfully'),
                                    backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setState(() {
                                isProcessing = false;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error updating match: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProcessing ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: isProcessing
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Updating...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Update Match',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showAddMatchDialog(String tournamentId) async {
    if (_isAddingMatch) return;

    final tournamentTeams = await _getTournamentTeams(tournamentId);
    if (tournamentTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teams available for this tournament')),
      );
      return;
    }

    // Get current tournament data
    final tournamentQuery = await FirebaseFirestore.instance
        .collection('tournaments')
        .where('id', isEqualTo: tournamentId)
        .limit(1)
        .get();
    
    if (tournamentQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament not found')),
      );
      return;
    }
    
    final tournamentDoc = tournamentQuery.docs.first;
    final tournamentData = tournamentDoc.data();
    final currentVenue = tournamentData['venue'] ?? 'Court 1';
    final currentMatchups = List<Map<String, dynamic>>.from(tournamentData['matchups'] ?? []);
    
    String? selectedTeam1;
    String? selectedTeam2;
    DateTime? startDateTime;
    DateTime? endDateTime;

    bool isProcessing = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Add Match',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              content: Container(
                width: 450,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AbsorbPointer(
                      absorbing: isProcessing,
                      child: Opacity(
                        opacity: isProcessing ? 0.5 : 1.0,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Team 1',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: selectedTeam1,
                                  hint: const Text('Select Team'),
                                  items: tournamentTeams
                                      .map<DropdownMenuItem<String>>((team) {
                                    return DropdownMenuItem<String>(
                                      value: team['id'] as String,
                                      child: Text(team['name'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedTeam1 = value;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              const Text('Team 2',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonFormField<String>(
                                  value: selectedTeam2,
                                  hint: const Text('Select Team'),
                                  items: tournamentTeams
                                      .map<DropdownMenuItem<String>>((team) {
                                    return DropdownMenuItem<String>(
                                      value: team['id'] as String,
                                      child: Text(team['name'] as String),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedTeam2 = value;
                                    });
                                  },
                                  decoration: const InputDecoration(
                                    contentPadding:
                                        EdgeInsets.symmetric(horizontal: 12),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),

                              const Text('Schedule',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              const SizedBox(height: 12),

                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Start Time',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate:
                                              startDateTime ?? DateTime.now(),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 365)),
                                        );
                                        if (date != null) {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.fromDateTime(
                                                startDateTime ??
                                                    DateTime.now()),
                                          );
                                          if (time != null) {
                                            setDialogState(() {
                                              startDateTime = DateTime(
                                                date.year,
                                                date.month,
                                                date.day,
                                                time.hour,
                                                time.minute,
                                              );
                                            });
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 18,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                startDateTime == null
                                                    ? 'Select Start Date & Time'
                                                    : _displayDateFormat
                                                        .format(startDateTime!),
                                                style: TextStyle(
                                                  color: startDateTime == null
                                                      ? Colors.grey.shade500
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.arrow_drop_down,
                                                color: Colors.grey.shade600),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('End Time',
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: endDateTime ??
                                              (startDateTime ?? DateTime.now()),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 365)),
                                        );
                                        if (date != null) {
                                          final time = await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay.fromDateTime(
                                                endDateTime ??
                                                    (startDateTime ??
                                                        DateTime.now())),
                                          );
                                          if (time != null) {
                                            setDialogState(() {
                                              endDateTime = DateTime(
                                                date.year,
                                                date.month,
                                                date.day,
                                                time.hour,
                                                time.minute,
                                              );
                                            });
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 12),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 18,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                endDateTime == null
                                                    ? 'Select End Date & Time'
                                                    : _displayDateFormat
                                                        .format(endDateTime!),
                                                style: TextStyle(
                                                  color: endDateTime == null
                                                      ? Colors.grey.shade500
                                                      : Colors.black,
                                                ),
                                              ),
                                            ),
                                            Icon(Icons.arrow_drop_down,
                                                color: Colors.grey.shade600),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (startDateTime != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: _DurationButton(
                                          label: '+30 min',
                                          onPressed: () {
                                            setDialogState(() {
                                              endDateTime = startDateTime!.add(
                                                  const Duration(minutes: 30));
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _DurationButton(
                                          label: '+1 hour',
                                          onPressed: () {
                                            setDialogState(() {
                                              endDateTime = startDateTime!.add(
                                                  const Duration(hours: 1));
                                            });
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _DurationButton(
                                          label: '+1.5 hour',
                                          onPressed: () {
                                            setDialogState(() {
                                              endDateTime = startDateTime!.add(
                                                  const Duration(minutes: 90));
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.location_on,
                                        size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Venue: $currentVenue',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
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

                    if (isProcessing)
                      const Padding(
                        padding: EdgeInsets.only(top: 20, bottom: 8),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text(
                                'Adding match...',
                                style:
                                    TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isProcessing
                      ? null
                      : () async {
                          if (selectedTeam1 == null ||
                              selectedTeam2 == null ||
                              startDateTime == null ||
                              endDateTime == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please select teams, start time, and end time')),
                            );
                            return;
                          }

                          if (selectedTeam1 == selectedTeam2) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Please select different teams')),
                            );
                            return;
                          }

                          if (endDateTime!.isBefore(startDateTime!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'End time must be after start time')),
                            );
                            return;
                          }

                          setDialogState(() {
                            isProcessing = true;
                          });

                          try {
                            final team1 = tournamentTeams
                                .firstWhere((t) => t['id'] == selectedTeam1);
                            final team2 = tournamentTeams
                                .firstWhere((t) => t['id'] == selectedTeam2);

                            final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

                            final newMatch = {
                              'id': 'match_${DateTime.now().millisecondsSinceEpoch}',
                              'matchNumber': currentMatchups.length + 1,
                              'round': 1,
                              'bracket': 'single',
                              'matchType': 'regular',
                              'status': 'scheduled',
                              'team1': team1,
                              'team2': team2,
                              'team1Id': team1['id'],
                              'team2Id': team2['id'],
                              'team1Name': team1['name'],
                              'team2Name': team2['name'],
                              'dateTime': dateFormat.format(startDateTime!),
                              'startTime': dateFormat.format(startDateTime!),
                              'endTime': dateFormat.format(endDateTime!),
                              'sport': tournamentData['sport'] ?? 'Unknown',
                              'category': tournamentData['category'] ?? 'Unknown',
                              'gender': tournamentData['gender'] ?? 'Unknown',
                              'venue': currentVenue,
                              'scores': {},
                              'winner': null,
                              'loser': null,
                            };

                            currentMatchups.add(newMatch);
                            
                            await tournamentDoc.reference.update({
                              'matchups': currentMatchups,
                              'totalMatches': currentMatchups.length,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });

                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Match added successfully'),
                                    backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() {
                                isProcessing = false;
                              });

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding match: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProcessing ? Colors.grey : Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(120, 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                  child: isProcessing
                      ? const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Adding...',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Add Match',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _loadTeamsData() async {
    final allTeams = await _teamParticipantsService.getTeams();
    final Map<String, String> teamDetails = {};
    for (var team in allTeams) {
      teamDetails[team['name'] ?? ''] = team['name'] ?? 'Unknown Team';
    }
    setState(() {
    });
  }

  void _loadUserEmails() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> userEmails = {};
      final Map<String, String> userNames = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final userId = doc.id;
        final email = data['email'] ?? 'Unknown Email';
        final name = data['name'] ?? email.split('@')[0];
        userEmails[userId] = email;
        userNames[userId] = name;
      }
      setState(() {
        _userEmails = userEmails;
        _userNames = userNames;
      });
    } catch (e) {}
  }

  Future<List<Map<String, dynamic>>> _getTournamentTeams(String tournamentId) async {
    try {
      final tournamentQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: tournamentId)
          .get();

      if (tournamentQuery.docs.isNotEmpty) {
        final tournamentData = tournamentQuery.docs.first.data();
        final teamIds = List<String>.from(tournamentData['selectedTeamIds'] ?? []);
        
        if (teamIds.isNotEmpty) {
          final teams = <Map<String, dynamic>>[];
          for (var teamId in teamIds) {
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('participants')
                  .doc(teamId)
                  .get();
              if (doc.exists) {
                teams.add({
                  'id': doc.id,
                  'name': doc['name'] ?? 'Unknown Team',
                });
              }
            // ignore: empty_catches
            } catch (e) {
            }
          }
          return teams;
        }
      }
    // ignore: empty_catches
    } catch (e) {
    }
    
    return [];
  }

 

 

  
  String _getUserNamesString(List<dynamic>? userIds) {
    if (userIds == null || userIds.isEmpty) {
      return 'Not assigned';
    }
    final names =
        userIds.map((id) => _userNames[id] ?? _userEmails[id] ?? id).toList();
    if (names.length > 2) {
      return '${names.take(2).join(', ')} +${names.length - 2}';
    }
    return names.join(', ');
  }

  void _deleteTeamSchedule(String id) async {
    // Delete match from tournament's matchups array
    try {
      // Find which tournament contains this match
      final tournamentsQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('matchups', arrayContains: {'id': id})
          .get();
      
      for (var doc in tournamentsQuery.docs) {
        final data = doc.data();
        final matchups = List<Map<String, dynamic>>.from(data['matchups'] ?? []);
        matchups.removeWhere((match) => match['id'] == id);
        
        await doc.reference.update({
          'matchups': matchups,
          'totalMatches': matchups.length,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    // ignore: empty_catches
    } catch (e) {
    }
    }

  List<Map<String, dynamic>> _organizeMatchesInBracketFormat(
      List<Map<String, dynamic>> matches) {
    if (matches.isEmpty) return [];

    matches.sort((a, b) {
      final aNum = a['matchNumber'] ?? 999;
      final bNum = b['matchNumber'] ?? 999;
      return aNum.compareTo(bNum);
    });

    final sampleMatch = matches.first;
    if (sampleMatch.containsKey('team1') && sampleMatch.containsKey('team2')) {
      return matches.map((match) {
        final round = match['round'] ??
            _calculateRound(match['matchNumber'], matches.length);
        return {
          ...match,
          'round': round,
          'bracket': match['bracket'] ?? _getBracketType(match),
        };
      }).toList();
    }

    return matches.map((match) {
      final teams = List<String>.from(match['teams'] ?? []);
      final isWinnerMatch = teams.any((t) =>
          t.toString().toLowerCase().contains('winner of') ||
          t.toString().toLowerCase().contains('loser of'));
      return {
        ...match,
        'displayType': isWinnerMatch ? 'winner_match' : 'team_match',
        'isLegacy': true,
      };
    }).toList();
  }

  int _calculateRound(int? matchNumber, int totalMatches) {
    if (matchNumber == null) return 1;

    if (totalMatches <= 3) {
      return matchNumber <= 2 ? 1 : 2;
    } else if (totalMatches <= 5) {
      if (matchNumber <= 2) return 1;
      if (matchNumber <= 4) return 2;
      return 3;
    } else if (totalMatches <= 7) {
      if (matchNumber <= 4) return 1;
      if (matchNumber <= 6) return 2;
      return 3;
    } else {
      int matchesInRound1 = totalMatches - (1 << (totalMatches.bitLength - 2));
      if (matchNumber <= matchesInRound1) return 1;
      return 2 +
          ((matchNumber - matchesInRound1 - 1) ~/ (matchesInRound1 ~/ 2));
    }
  }

  String _getBracketType(Map<String, dynamic> match) {
    if (match.containsKey('bracket')) return match['bracket'];
    if (match.containsKey('isGrandFinals')) return 'finals';
    if (match.containsKey('isIfNecessary')) return 'finals';

    final team1Name = match['team1Name'] ?? '';
    final team2Name = match['team2Name'] ?? '';

    if (team1Name.contains('Winner') && team2Name.contains('Winner')) {
      return 'finals';
    }
    if (team1Name.contains('Loser') || team2Name.contains('Loser')) {
      return 'losers';
    }
    return 'winners';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black),
        titleSpacing: 0,
        toolbarHeight: 70,
        title: Row(
          children: [
            const SizedBox(width: 8),
            const Text(
              'Scheduling List',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 42,
                margin: const EdgeInsets.symmetric(vertical: 12),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: "Search by team or tournament...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                      _currentPage = 0;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _selectedDate != null
                    ? Colors.blue.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: Icon(Icons.calendar_today,
                    size: 20,
                    color: _selectedDate != null ? Colors.blue : Colors.grey),
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() {
                      _selectedDate = pickedDate;
                      _currentPage = 0;
                    });
                  }
                },
              ),
            ),
            if (_selectedDate != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.clear, size: 20, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _selectedDate = null;
                      _currentPage = 0;
                    });
                  },
                ),
              ),
            const SizedBox(width: 12),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _itemsPerPage,
                  items: [5, 10, 15, 20, 25, 50].map((value) {
                    return DropdownMenuItem<int>(
                      value: value,
                      child: Text('$value per page'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _itemsPerPage = value;
                        _currentPage = 0;
                      });
                    }
                  },
                  icon: const Icon(Icons.arrow_drop_down),
                  style: const TextStyle(fontSize: 14, color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = constraints.maxWidth > 1400
              ? 5
              : constraints.maxWidth > 1200
                  ? 4
                  : constraints.maxWidth > 900
                      ? 3
                      : constraints.maxWidth > 600
                          ? 2
                          : 1;

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getTournamentsWithMatches(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style:
                            const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final tournaments = snapshot.data!;
              if (tournaments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_score,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'No tournaments found.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }

              // Apply search filter
              var filteredTournaments = tournaments.where((tournament) {
                final tournamentName = tournament['name']?.toLowerCase() ?? '';
                
                String teamList = '';
                final matchups = tournament['matchups'] as List<dynamic>? ?? [];
                for (var match in matchups) {
                  final matchMap = match as Map<String, dynamic>;
                  final team1 = matchMap['team1Name'] ?? '';
                  final team2 = matchMap['team2Name'] ?? '';
                  teamList += '$team1 $team2 ';
                }

                return tournamentName.contains(_searchQuery) ||
                    teamList.toLowerCase().contains(_searchQuery);
              }).toList();

              // Apply date filter
              if (_selectedDate != null) {
                filteredTournaments = filteredTournaments.where((tournament) {
                  final matchups = tournament['matchups'] as List<dynamic>? ?? [];
                  for (var match in matchups) {
                    final matchMap = match as Map<String, dynamic>;
                    try {
                      final dateTimeStr = matchMap['dateTime'] ?? matchMap['startTime'];
                      if (dateTimeStr != null) {
                        final date = _parseDateTime(dateTimeStr.toString());
                        if (date.year == _selectedDate!.year &&
                            date.month == _selectedDate!.month &&
                            date.day == _selectedDate!.day) {
                          return true;
                        }
                      }
                    } catch (e) {}
                  }
                  return false;
                }).toList();
              }

              final totalPages = (filteredTournaments.length / _itemsPerPage).ceil();

              if (_currentPage >= totalPages && totalPages > 0) {
                _currentPage = totalPages - 1;
              }

              final startIndex = _currentPage * _itemsPerPage;
              final endIndex = (startIndex + _itemsPerPage) > filteredTournaments.length
                  ? filteredTournaments.length
                  : startIndex + _itemsPerPage;

              final paginatedTournaments = filteredTournaments.isEmpty
                  ? []
                  : filteredTournaments.sublist(
                      startIndex > filteredTournaments.length ? 0 : startIndex,
                      endIndex);

              return Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade200),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Showing ${filteredTournaments.isEmpty ? 0 : startIndex + 1}-${filteredTournaments.isEmpty ? 0 : endIndex} of ${filteredTournaments.length} tournaments',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),

                        Row(
                          children: [
                            _buildPaginationButton(
                              icon: Icons.chevron_left,
                              onPressed: _currentPage > 0
                                  ? () {
                                      setState(() {
                                        _currentPage--;
                                      });
                                    }
                                  : null,
                              label: 'Previous',
                            ),

                            const SizedBox(width: 8),

                            if (totalPages > 1) ...[
                              _buildPageNumbers(totalPages, _currentPage),
                            ],

                            const SizedBox(width: 8),

                            _buildPaginationButton(
                              icon: Icons.chevron_right,
                              onPressed: _currentPage < totalPages - 1
                                  ? () {
                                      setState(() {
                                        _currentPage++;
                                      });
                                    }
                                  : null,
                              label: 'Next',
                              isNext: true,
                            ),
                          ],
                        ),

                        Text(
                          '${_itemsPerPage} items per page',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: paginatedTournaments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No tournaments match your filters',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty ||
                                    _selectedDate != null)
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = "";
                                        _selectedDate = null;
                                        _currentPage = 0;
                                      });
                                    },
                                    child: const Text('Clear filters'),
                                  ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _refreshTournamentData,
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                childAspectRatio: 0.75,
                              ),
                              itemCount: paginatedTournaments.length,
                              itemBuilder: (context, index) {
                                final tournament = paginatedTournaments[index];
                                final tournamentId = tournament['id'];
                                final tournamentName = tournament['name'] ?? 'Unnamed Tournament';
                                final matchups = tournament['matchups'] as List<dynamic>? ?? [];
                                final schedules = matchups.map((m) => m as Map<String, dynamic>).toList();

                                final organizedMatches = _organizeMatchesInBracketFormat(schedules);

                                final sportName = tournament['sport'] ?? 'Unknown Sport';
                                final categoryName = tournament['category'] ?? 'Unknown Category';

                                final sportIcon = _getSportIcon(sportName);
                                final categoryColor = _getCategoryColor(categoryName);

                                final teamCount = tournament['selectedTeamIds']?.length ?? 0;
                                final bracketInfo = _getBracketInfo(teamCount, schedules.length);

                                return _BracketStyleTournamentCard(
                                  tournamentId: tournamentId,
                                  tournamentName: tournamentName,
                                  sportIcon: sportIcon,
                                  sportName: sportName,
                                  categoryName: categoryName,
                                  categoryColor: categoryColor,
                                  schedules: organizedMatches,
                                  originalSchedules: schedules,
                                  tournamentDetails: tournament,
                                  teamCount: teamCount,
                                  bracketInfo: bracketInfo,
                                  onEditVenue: () => _editVenue(tournamentId),
                                  onEditStatus: () => _editStatus(tournamentId),
                                  onDeleteAll: () => _deleteAllTournamentData(tournamentId),
                                  onAddMatch: () async {
                                    await _showAddMatchDialog(tournamentId);
                                  },
                                  onEditMatch: (item) => _showEditMatchDialog(tournamentId, item),
                                  onDeleteMatch: (item) async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Confirm Delete'),
                                        content: const Text(
                                            'Are you sure you want to delete this schedule?'),
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
                                    if (confirmed == true) {
                                      _deleteTeamSchedule(item['id']);
                                    }
                                  },
                                  onShowBracket: () {
                                    TournamentOfficialBracketDialog.show(
                                      context: context,
                                      tournamentId: tournamentId,
                                      tournamentName: tournamentName,
                                    );
                                  },
                                  formatDateTime: _formatDateTime,
                                  formatEndDateTime: _formatEndDateTime,
                                  getUserNamesString: _getUserNamesString,
                                  onRefresh: _refreshTournamentData,
                                );
                              },
                            ),
                          ),
                  ),

                  if (totalPages > 1)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: _currentPage > 0
                                ? () {
                                    setState(() {
                                      _currentPage--;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            style: IconButton.styleFrom(
                              backgroundColor: _currentPage > 0
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            'Page ${_currentPage + 1} of $totalPages',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: _currentPage < totalPages - 1
                                ? () {
                                    setState(() {
                                      _currentPage++;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            style: IconButton.styleFrom(
                              backgroundColor: _currentPage < totalPages - 1
                                  ? Colors.blue.shade50
                                  : Colors.grey.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  DateTime _parseDateTime(String dateTimeString) {
    try {
      if (dateTimeString.contains('T')) {
        return DateTime.parse(dateTimeString);
      } else if (dateTimeString.contains('/')) {
        final parts = dateTimeString.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('/');
          final timeParts = parts[1].split(':');
          return DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        }
      }
    } catch (e) {}
    return DateTime.now();
  }

  Widget _buildPaginationButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String label,
    bool isNext = false,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: onPressed != null ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                onPressed != null ? Colors.blue.shade200 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            if (!isNext)
              Icon(icon,
                  size: 16,
                  color: onPressed != null ? Colors.blue : Colors.grey),
            if (!isNext) const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: onPressed != null ? Colors.blue : Colors.grey,
              ),
            ),
            if (isNext) const SizedBox(width: 4),
            if (isNext)
              Icon(icon,
                  size: 16,
                  color: onPressed != null ? Colors.blue : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildPageNumbers(int totalPages, int currentPage) {
    List<Widget> pageButtons = [];

    pageButtons.add(_buildPageNumberButton(1, currentPage == 0));

    if (totalPages > 7) {
      if (currentPage > 3) {
        pageButtons.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: const Text('...',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
        );
      }

      int start = currentPage > 3 ? currentPage - 1 : 2;
      int end = currentPage < totalPages - 4 ? currentPage + 1 : totalPages - 2;

      for (int i = start; i <= end; i++) {
        if (i > 1 && i < totalPages) {
          pageButtons.add(_buildPageNumberButton(i + 1, currentPage == i));
        }
      }

      if (currentPage < totalPages - 4) {
        pageButtons.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: const Text('...',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
        );
      }
    } else {
      for (int i = 2; i <= totalPages - 1; i++) {
        pageButtons.add(_buildPageNumberButton(i, currentPage == i - 1));
      }
    }

    if (totalPages > 1) {
      pageButtons.add(
          _buildPageNumberButton(totalPages, currentPage == totalPages - 1));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: pageButtons,
    );
  }

  Widget _buildPageNumberButton(int pageNumber, bool isSelected) {
    return InkWell(
      onTap: isSelected
          ? null
          : () {
              setState(() {
                _currentPage = pageNumber - 1;
              });
            },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
          ),
        ),
        child: Text(
          pageNumber.toString(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  


  String _getBracketInfo(int teamCount, int matchCount) {
    if (teamCount <= 0) return '';

    int rounds = (teamCount - 1).bitLength;

    if (teamCount <= 8) {
      if (teamCount == 2) return 'Final (1 match)';
      if (teamCount == 3) return '2 Rounds • 2 matches';
      if (teamCount == 4) return 'Semifinals + Final';
      if (teamCount == 5) return 'Quarterfinals → Final';
      if (teamCount == 6) return 'Quarterfinals → Final';
      if (teamCount == 7) return 'Quarterfinals → Final';
      if (teamCount == 8) return 'Quarterfinals + Semifinals + Final';
    }

    return '$teamCount teams • $matchCount matches • $rounds rounds';
  }

  String _getSportIcon(String sportName) {
    switch (sportName.toLowerCase()) {
      case 'basketball':
        return '🏀';
      case 'volleyball':
        return '🏐';
      case 'football':
      case 'soccer':
        return '⚽';
      case 'badminton':
        return '🏸';
      case 'table tennis':
        return '🏓';
      case 'tennis':
        return '🎾';
      case 'swimming':
        return '🏊';
      case 'athletics':
        return '🏃';
      case 'baseball':
        return '⚾';
      default:
        return '🏆';
    }
  }

  Color _getCategoryColor(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case "men's":
      case "men":
        return Colors.blue;
      case "women's":
      case "women":
        return Colors.pink;
      case "mixed":
        return Colors.purple;
      case "boys":
        return Colors.lightBlue;
      case "girls":
        return Colors.pinkAccent;
      case "innings":
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return 'Not set';
    }
    try {
      DateTime dateTime;
      if (dateTimeString.contains('T')) {
        dateTime = DateTime.parse(dateTimeString);
      } else if (dateTimeString.contains('/')) {
        final parts = dateTimeString.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('/');
          final timeParts = parts[1].split(':');
          dateTime = DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        } else {
          return dateTimeString;
        }
      } else if (dateTimeString.contains('-') && dateTimeString.contains(':')) {
        final cleanString = dateTimeString.replaceAll('T', ' ');
        dateTime = DateTime.parse(cleanString);
      } else {
        return dateTimeString;
      }
      return _displayDateFormat.format(dateTime);
    } catch (e) {
      return dateTimeString;
    }
  }

  String _formatEndDateTime(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) {
      return '';
    }
    try {
      DateTime dateTime;
      if (dateTimeString.contains('T')) {
        dateTime = DateTime.parse(dateTimeString);
      } else if (dateTimeString.contains('/')) {
        final parts = dateTimeString.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('/');
          final timeParts = parts[1].split(':');
          dateTime = DateTime(
            int.parse(dateParts[2]),
            int.parse(dateParts[1]),
            int.parse(dateParts[0]),
            int.parse(timeParts[0]),
            int.parse(timeParts[1]),
          );
        } else {
          return ' - ${_formatDateTime(dateTimeString)}';
        }
      } else if (dateTimeString.contains('-') && dateTimeString.contains(':')) {
        final cleanString = dateTimeString.replaceAll('T', ' ');
        dateTime = DateTime.parse(cleanString);
      } else {
        return ' - $dateTimeString';
      }
      return ' - ${_displayDateFormat.format(dateTime)}';
    } catch (e) {
      return ' - $dateTimeString';
    }
  }

  void _editVenue(String tournamentId) {
    final currentVenue =
        _tournamentDetailsNotifier.value[tournamentId]?['venue'] ?? '';
    showDialog(
      context: context,
      builder: (context) {
        String newVenue = currentVenue;
        return AlertDialog(
          title: const Text('Edit Venue'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: TextField(
            controller: TextEditingController(text: currentVenue),
            onChanged: (value) => newVenue = value,
            decoration: InputDecoration(
              labelText: 'Venue',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.location_on),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final docId =
                    _tournamentDetailsNotifier.value[tournamentId]?['docId'];
                if (docId != null) {
                  try {
                    await _tournamentService
                        .updateTournament(docId, {'venue': newVenue});
                    if (mounted) {
                      setState(() {
                        if (_tournamentDetailsNotifier.value
                            .containsKey(tournamentId)) {
                          _tournamentDetailsNotifier
                              .value[tournamentId]!['venue'] = newVenue;
                        }
                      });
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Venue updated successfully'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating venue: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _editStatus(String tournamentId) {
    final statusValue =
        _tournamentDetailsNotifier.value[tournamentId]?['status'];
    final currentStatus = statusValue is String
        ? (statusValue.toLowerCase() == 'active' ? 'Active' : 'Inactive')
        : 'Active';
    showDialog(
      context: context,
      builder: (context) {
        String newStatus = currentStatus;
        return AlertDialog(
          title: const Text('Edit Status'),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: DropdownButtonFormField<String>(
            value: newStatus,
            items: const [
              DropdownMenuItem(value: 'Active', child: Text('Active')),
              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
            ],
            onChanged: (value) => newStatus = value ?? 'Active',
            decoration: InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.circle),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final docId =
                    _tournamentDetailsNotifier.value[tournamentId]?['docId'];
                if (docId != null) {
                  try {
                    await _tournamentService
                        .updateTournament(docId, {'status': newStatus});
                    if (mounted) {
                      setState(() {
                        if (_tournamentDetailsNotifier.value
                            .containsKey(tournamentId)) {
                          _tournamentDetailsNotifier
                              .value[tournamentId]!['status'] = newStatus;
                        }
                      });
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Status updated successfully'),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error updating status: $e'),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAllTournamentData(String tournamentId) async {
    try {
      final tournamentQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: tournamentId)
          .get();
      
      if (tournamentQuery.docs.isEmpty) return;
      
      final tournamentDoc = tournamentQuery.docs.first;
      final tournamentData = tournamentDoc.data();
      final matchups = tournamentData['matchups'] as List<dynamic>? ?? [];
      final matchesCount = matchups.length;

      final scoresSnapshot = await FirebaseFirestore.instance
          .collection('scores')
          .where('tournamentSetupId', isEqualTo: tournamentId)
          .get();
      final scoresCount = scoresSnapshot.docs.length;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Delete All Tournament Data',
            style: TextStyle(color: Colors.red),
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone. The following data will be permanently deleted:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    children: [
                      _buildDeleteStat(
                        icon: Icons.sports,
                        label: 'Matches',
                        count: matchesCount,
                        color: Colors.red,
                      ),
                      const Divider(height: 16),
                      _buildDeleteStat(
                        icon: Icons.scoreboard,
                        label: 'Scores',
                        count: scoresCount,
                        color: Colors.orange,
                      ),
                      const Divider(height: 16),
                      _buildDeleteStat(
                        icon: Icons.emoji_events,
                        label: 'Tournament',
                        count: 1,
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Tournament: ${_tournamentNames[tournamentId] ?? tournamentId}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Delete Everything'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        try {
          int deletedScores = 0;

          // Delete all scores
          for (var doc in scoresSnapshot.docs) {
            try {
              await doc.reference.delete();
              deletedScores++;
            } catch (e) {}
          }

          // Clear matchups in tournament
          await tournamentDoc.reference.update({
            'matchups': [],
            'totalMatches': 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deletion completed successfully!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text('• $matchesCount matches cleared'),
                    Text('• $deletedScores scores deleted'),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error deleting data: $e'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildDeleteStat({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _BracketStyleTournamentCard extends StatelessWidget {
  final String tournamentId;
  final String tournamentName;
  final String sportIcon;
  final String sportName;
  final String categoryName;
  final Color categoryColor;
  final List<Map<String, dynamic>> schedules;
  final List<Map<String, dynamic>> originalSchedules;
  final Map<String, dynamic>? tournamentDetails;
  final int teamCount;
  final String bracketInfo;
  final VoidCallback onEditVenue;
  final VoidCallback onEditStatus;
  final VoidCallback onDeleteAll;
  final Future<void> Function() onAddMatch;
  final Function(Map<String, dynamic>) onEditMatch;
  final Function(Map<String, dynamic>) onDeleteMatch;
  final VoidCallback onShowBracket;
  final String Function(String) formatDateTime;
  final String Function(String?) formatEndDateTime;
  final String Function(List<dynamic>?) getUserNamesString;
  final VoidCallback onRefresh;

  const _BracketStyleTournamentCard({
    required this.tournamentId,
    required this.tournamentName,
    required this.sportIcon,
    required this.sportName,
    required this.categoryName,
    required this.categoryColor,
    required this.schedules,
    required this.originalSchedules,
    required this.tournamentDetails,
    required this.teamCount,
    required this.bracketInfo,
    required this.onEditVenue,
    required this.onEditStatus,
    required this.onDeleteAll,
    required this.onAddMatch,
    required this.onEditMatch,
    required this.onDeleteMatch,
    required this.onShowBracket,
    required this.formatDateTime,
    required this.formatEndDateTime,
    required this.getUserNamesString,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tournamentDetails?['status'] == 'Active' || 
                     tournamentDetails?['status'] == 'active';
    final isCompleted = tournamentDetails?['isCompleted'] == true;
    final venue = tournamentDetails?['venue'] ?? 'Not specified';
    final assignedUsers = tournamentDetails?['assignedUsers'] as List<dynamic>?;
    
    // Calculate completion stats
    final totalMatches = originalSchedules.length;
    
    int matchesWithScores = 0;
    for (var match in originalSchedules) {
      final scores = match['scores'] as Map<String, dynamic>?;
      if (scores != null && scores.isNotEmpty) {
        matchesWithScores++;
      } else if (match['winner'] != null) {
        matchesWithScores++;
      } else if (match['status'] == 'completed') {
        matchesWithScores++;
      }
    }
    
    final completionPercentage = totalMatches > 0 
        ? (matchesWithScores / totalMatches * 100).toInt() 
        : 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted 
                ? Colors.green.shade300 
                : (isActive ? Colors.green.shade200 : Colors.grey.shade200),
            width: isCompleted ? 2 : 1,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isCompleted
                        ? [Colors.green.shade100, Colors.green.shade50]
                        : (isActive
                            ? [Colors.green.shade50, Colors.green.shade100]
                            : [Colors.grey.shade100, Colors.grey.shade50]),
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCompleted 
                                  ? Colors.green.shade300 
                                  : Colors.grey.shade200,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            sportIcon, 
                            style: const TextStyle(fontSize: 24)
                          ),
                        ),
                        if (isCompleted)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    const SizedBox(width: 12),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  tournamentName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    decoration: isCompleted 
                                        ? TextDecoration.lineThrough 
                                        : null,
                                    decorationColor: Colors.green.shade400,
                                    color: isCompleted 
                                        ? Colors.green.shade700 
                                        : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCompleted)
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6, 
                                    vertical: 2
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        size: 10,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 2),
                                      Text(
                                        'COMPLETED',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          
                          const SizedBox(height: 4),
                          
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  sportName,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: categoryColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  categoryName,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive ? Colors.green : Colors.red,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                tournamentDetails?['status'] ?? 'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isActive
                                      ? Colors.green.shade700
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 4),
                        
                        _TournamentCompletionButton(
                          tournamentId: tournamentId,
                          tournamentDetails: tournamentDetails,
                          matches: originalSchedules,
                          onStatusChanged: () {
                            onRefresh();
                                                    },
                          onRefresh: onRefresh,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (totalMatches > 0) ...[
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: Colors.grey.shade200,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: completionPercentage / 100,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: isCompleted
                                    ? [Colors.green, Colors.green.shade300]
                                    : [Colors.blue, Colors.lightBlue.shade300],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Icon(
                            isCompleted 
                                ? Icons.check_circle 
                                : Icons.pending,
                            size: 12,
                            color: isCompleted 
                                ? Colors.green 
                                : Colors.blue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isCompleted
                                ? 'All matches completed'
                                : '$matchesWithScores/$totalMatches matches have scores ($completionPercentage%)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isCompleted 
                                  ? Colors.green.shade700 
                                  : Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    
                    Row(
                      children: [
                        Expanded(
                          child: _InfoChip(
                            icon: Icons.location_on,
                            label: venue,
                            color: Colors.blue,
                            onTap: onEditVenue,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.sports_soccer,
                          label: '$totalMatches matches',
                          color: Colors.orange,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Colors.green.shade50
                            : Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isCompleted
                              ? Colors.green.shade200
                              : Colors.deepOrange.shade200,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_tree,
                            size: 14,
                            color: isCompleted
                                ? Colors.green.shade700
                                : Colors.deepOrange.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              isCompleted ? 'Tournament Completed' : bracketInfo,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isCompleted
                                    ? Colors.green.shade700
                                    : Colors.deepOrange.shade700,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$teamCount teams',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted
                                    ? Colors.green.shade700
                                    : Colors.deepOrange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (assignedUsers != null && assignedUsers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.people,
                                size: 14, color: Colors.purple.shade400),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                getUserNamesString(assignedUsers),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.purple.shade700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        const SizedBox(width: 4),
                        Expanded(
                          child: _ActionButton(
                            onPressed: onShowBracket,
                            icon: Icons.account_tree,
                            label: 'Bracket',
                            color: isCompleted ? Colors.green : Colors.green,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'MATCHES',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                        if (isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '✓ All completed',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    originalSchedules.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.sports_score,
                                  size: 32,
                                  color: Colors.grey.shade300,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No matches yet',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Opacity(
                            opacity: isCompleted ? 0.7 : 1.0,
                            child: _buildCompactMatchesGrid(),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactMatchesGrid() {
    final allMatches = List<Map<String, dynamic>>.from(schedules);
    allMatches.sort((a, b) {
      final aNum = a['matchNumber'] ?? 999;
      final bNum = b['matchNumber'] ?? 999;
      return aNum.compareTo(bNum);
    });

    final matchCount = allMatches.length;
    final crossAxisCount = 2;
    final rowCount = (matchCount / crossAxisCount).ceil();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: List.generate(rowCount, (rowIndex) {
          final startIndex = rowIndex * crossAxisCount;
          final endIndex = (startIndex + crossAxisCount) > matchCount
              ? matchCount
              : startIndex + crossAxisCount;

          return Padding(
            padding: EdgeInsets.only(
              bottom: rowIndex < rowCount - 1 ? 8 : 0,
            ),
            child: Row(
              children: List.generate(endIndex - startIndex, (colIndex) {
                final matchIndex = startIndex + colIndex;
                final match = allMatches[matchIndex];

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: colIndex == 0 ? 0 : 4,
                      right: colIndex < (endIndex - startIndex - 1) ? 4 : 0,
                    ),
                    child: _CompactMatchCard(
                      match: match,
                      matchNumber: match['matchNumber'] ?? matchIndex + 1,
                      onEdit: () => onEditMatch(match),
                      onDelete: () => onDeleteMatch(match),
                      formatDateTime: formatDateTime,
                      formatEndDateTime: (dateTimeString) =>
                          formatEndDateTime(dateTimeString),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}

class _CompactMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final int matchNumber;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String Function(String) formatDateTime;
  final String Function(String?) formatEndDateTime;

  const _CompactMatchCard({
    required this.match,
    required this.matchNumber,
    required this.onEdit,
    required this.onDelete,
    required this.formatDateTime,
    required this.formatEndDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final team1 =
        match['team1'] as Map<String, dynamic>? ?? {'name': 'TBD', 'id': 'tbd'};
    final team2 =
        match['team2'] as Map<String, dynamic>? ?? {'name': 'TBD', 'id': 'tbd'};

    String team1Name = _getDisplayName(team1, match['team1Name']);
    String team2Name = _getDisplayName(team2, match['team2Name']);

    // Get the actual team IDs - for team2, it might be in team2Id field
    final String? team1Id = match['team1Id'] ?? team1['id'];
    final String? team2Id = match['team2Id'] ?? team2['id'];
    
    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    final winner = match['winner'];
    
    // FIX: Get scores using multiple possible keys
    String? getTeamScore(String? teamId, String teamName) {
      if (teamId == null) return null;
      
      // Try direct ID match first
      if (scores.containsKey(teamId)) {
        return scores[teamId].toString();
      }
      
      // Try name match
      if (scores.containsKey(teamName)) {
        return scores[teamName].toString();
      }
      
      // For placeholder teams, the actual winning team ID might be stored
      // in the winner field or in team2Id
      if (match['team2Id'] != null && scores.containsKey(match['team2Id'])) {
        return scores[match['team2Id']].toString();
      }
      
      return null;
    }

    String? team1Score = getTeamScore(team1Id, team1Name);
    String? team2Score = getTeamScore(team2Id, team2Name);

    final matchType = match['matchType'] ?? 'regular';
    final bracket = match['bracket'] as String?;
    final round = match['round'] as int? ?? 1;
    final nextMatchRef = match['nextMatchReference'];
    final isBye = matchType == 'bye';
    final isFixedMatch = match['isFixedMatch'] == true;

    String roundName = 'Round $round';
    if (bracket == 'winners') {
      roundName = 'Winners R$round';
    } else if (bracket == 'losers') {
      roundName = 'Losers R$round';
    } else if (bracket == 'finals') {
      roundName = match['isIfNecessary'] == true ? 'If Necessary' : 'Final';
    } else if (isFixedMatch) {
      roundName = 'FIXED';
    }

    Color borderColor = Colors.grey.shade300;
    if (isFixedMatch) {
      borderColor = Colors.blue.shade300;
    } else if (winner != null) {
      borderColor = Colors.green.shade300;
    } else if (bracket == 'winners') {
      borderColor = Colors.green.shade200;
    } else if (bracket == 'losers') {
      borderColor = Colors.orange.shade200;
    } else if (bracket == 'finals') {
      borderColor = Colors.purple.shade300;
    }

    Color headerColor = Colors.grey.shade50;
    if (isFixedMatch) {
      headerColor = Colors.blue.shade50;
    } else if (bracket == 'winners') {
      headerColor = Colors.green.shade50;
    } else if (bracket == 'losers') {
      headerColor = Colors.orange.shade50;
    } else if (bracket == 'finals') {
      headerColor = Colors.purple.shade50;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: isFixedMatch ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Text(
                    'M$matchNumber',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      color: isFixedMatch
                          ? Colors.blue.shade700
                          : (bracket == 'winners'
                              ? Colors.green.shade700
                              : (bracket == 'losers'
                                  ? Colors.orange.shade700
                                  : (bracket == 'finals'
                                      ? Colors.purple.shade700
                                      : Colors.grey.shade700))),
                    ),
                  ),
                ),
                Icon(
                  isFixedMatch
                      ? Icons.push_pin
                      : (bracket == 'winners'
                          ? Icons.emoji_events
                          : (bracket == 'losers'
                              ? Icons.restore
                              : (bracket == 'finals'
                                  ? Icons.star
                                  : (isBye ? Icons.skip_next : Icons.sports)))),
                  size: 10,
                  color: isFixedMatch
                      ? Colors.blue.shade700
                      : (bracket == 'winners'
                          ? Colors.green.shade700
                          : (bracket == 'losers'
                              ? Colors.orange.shade700
                              : (bracket == 'finals'
                                  ? Colors.purple.shade700
                                  : (isBye
                                      ? Colors.blue.shade700
                                      : Colors.grey.shade600)))),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    roundName,
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                      color: isFixedMatch
                          ? Colors.blue.shade700
                          : (bracket == 'winners'
                              ? Colors.green.shade700
                              : (bracket == 'losers'
                                  ? Colors.orange.shade700
                                  : (bracket == 'finals'
                                      ? Colors.purple.shade700
                                      : Colors.grey.shade700))),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isFixedMatch)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'FIXED',
                      style: TextStyle(
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                if (match['startTime'] != null || match['dateTime'] != null)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatDateTime(
                              match['startTime'] ?? match['dateTime']),
                          style: TextStyle(
                            fontSize: 6,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.right,
                        ),
                        if (match['endTime'] != null &&
                            match['endTime'].toString().isNotEmpty)
                          Text(
                            formatEndDateTime(match['endTime']),
                            style: TextStyle(
                              fontSize: 6,
                              color: Colors.grey.shade500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                if (isBye) ...[
                  _buildTeamRow(
                    name: team1Name,
                    score: team1Score,
                    isWinner: true,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text('BYE',
                        style: TextStyle(fontSize: 7, color: Colors.blue)),
                  ),
                ] else ...[
                  _buildTeamRow(
                    name: team1Name,
                    score: team1Score,
                    isWinner: winner == team1Id || winner == team1Name,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text('VS',
                        style: TextStyle(fontSize: 7, color: Colors.grey)),
                  ),
                  _buildTeamRow(
                    name: team2Name,
                    score: team2Score,
                    isWinner: winner == team2Id || winner == team2Name,
                  ),
                ],
                if (nextMatchRef != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '→ Winner to Match $nextMatchRef',
                      style: TextStyle(
                        fontSize: 7,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
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

  String _getDisplayName(Map<String, dynamic> team, String? teamName) {
    if (teamName != null && teamName.isNotEmpty) {
      if (teamName.contains('Winner Match')) {
        final matchNumber = teamName.replaceAll(RegExp(r'[^0-9]'), '');
        return 'M$matchNumber';
      }
      if (teamName.contains('Loser Match')) {
        final matchNumber = teamName.replaceAll(RegExp(r'[^0-9]'), '');
        return 'L$matchNumber';
      }
      return teamName;
    }

    if (team['type'] == 'placeholder') {
      final name = team['name'] ?? '';
      if (name.contains('Winner Match')) {
        final matchNumber = name.replaceAll(RegExp(r'[^0-9]'), '');
        return 'M$matchNumber';
      }
      if (name.contains('Loser Match')) {
        final matchNumber = name.replaceAll(RegExp(r'[^0-9]'), '');
        return 'L$matchNumber';
      }
      return name;
    }

    return team['name'] ?? 'TBD';
  }

  Widget _buildTeamRow({
    required String name,
    String? score,
    required bool isWinner,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 8,
              fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
              color: isWinner ? Colors.green.shade700 : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          decoration: BoxDecoration(
            color: isWinner ? Colors.green.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(
            score ?? '-',
            style: TextStyle(
              fontSize: 7,
              fontWeight: FontWeight.bold,
              color: isWinner ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
        ),
      ],
    );
  }
}



class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _DurationButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _DurationButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TournamentCompletionButton extends StatefulWidget {
  final String tournamentId;
  final Map<String, dynamic>? tournamentDetails;
  final List<Map<String, dynamic>> matches;
  final VoidCallback onStatusChanged;
  final VoidCallback? onRefresh;

  const _TournamentCompletionButton({
    required this.tournamentId,
    required this.tournamentDetails,
    required this.matches,
    required this.onStatusChanged,
    this.onRefresh,
  });

  @override
  __TournamentCompletionButtonState createState() => __TournamentCompletionButtonState();
}

class __TournamentCompletionButtonState extends State<_TournamentCompletionButton> {
  final TournamentService _tournamentService = TournamentService();
  bool _isLoading = false;
  bool _isCompleted = false;
  int _matchesWithScores = 0;
  bool _checkingScores = true;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.tournamentDetails?['isCompleted'] == true;
    _checkScoresProgress();
  }

  @override
  void didUpdateWidget(_TournamentCompletionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tournamentDetails != oldWidget.tournamentDetails) {
      setState(() {
        _isCompleted = widget.tournamentDetails?['isCompleted'] == true;
      });
    }
    
    if (widget.matches.length != oldWidget.matches.length) {
      _checkScoresProgress();
    }
  }

  Future<void> _checkScoresProgress() async {
    setState(() => _checkingScores = true);
    
    try {
      // Get the tournament document directly to ensure latest scores
      final tournamentDoc = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: widget.tournamentId)
          .limit(1)
          .get();
      
      if (tournamentDoc.docs.isNotEmpty) {
        final tournamentData = tournamentDoc.docs.first.data();
        final matchups = tournamentData['matchups'] as List<dynamic>? ?? [];
        
        int count = 0;
        for (var matchup in matchups) {
          final match = matchup as Map<String, dynamic>;
          final scores = match['scores'] as Map<String, dynamic>?;
          
          if (scores != null && scores.isNotEmpty) {
            count++;
          } else if (match['winner'] != null) {
            count++;
          } else if (match['status'] == 'completed') {
            count++;
          }
        }
        
        if (mounted) {
          setState(() {
            _matchesWithScores = count;
            _checkingScores = false;
          });
        }
      } else {
        // Fallback to checking passed matches
        int count = 0;
        for (var match in widget.matches) {
          final scores = match['scores'] as Map<String, dynamic>?;
          if (scores != null && scores.isNotEmpty) {
            count++;
          } else if (match['winner'] != null) {
            count++;
          } else if (match['status'] == 'completed') {
            count++;
          }
        }
        
        if (mounted) {
          setState(() {
            _matchesWithScores = count;
            _checkingScores = false;
          });
        }
      }
    } catch (e) {
      // Fallback to checking passed matches
      try {
        int count = 0;
        for (var match in widget.matches) {
          final scores = match['scores'] as Map<String, dynamic>?;
          if (scores != null && scores.isNotEmpty) {
            count++;
          } else if (match['winner'] != null) {
            count++;
          } else if (match['status'] == 'completed') {
            count++;
          }
        }
        
        if (mounted) {
          setState(() {
            _matchesWithScores = count;
            _checkingScores = false;
          });
        }
      } catch (e2) {
        if (mounted) setState(() => _checkingScores = false);
      }
    }
  }

  Future<void> _toggleCompletion() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final allHaveScores = await _tournamentService.doAllMatchesHaveScores(
        widget.tournamentId
      );
      
      if (!allHaveScores && !_isCompleted) {
        await _checkScoresProgress();
        
        _showStatusMessage(
          '⚠️ ${_matchesWithScores}/${widget.matches.length} matches have scores',
          Colors.orange,
        );
        setState(() => _isLoading = false);
        return;
      }

      final newStatus = !_isCompleted;
      await _tournamentService.markTournamentAsCompleted(
        widget.tournamentId, newStatus
      );

      setState(() {
        _isCompleted = newStatus;
        _isLoading = false;
      });
      
      widget.onStatusChanged();
      if (widget.onRefresh != null) {
        widget.onRefresh!();
      }
      
      _showStatusMessage(
        newStatus ? '✅ Tournament completed!' : '📋 Tournament marked incomplete',
        newStatus ? Colors.green : Colors.orange,
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showStatusMessage('❌ Error: $e', Colors.red);
    }
  }

  void _showStatusMessage(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMatches = widget.matches.length;
    final progress = totalMatches > 0 ? _matchesWithScores / totalMatches : 0.0;
    final canComplete = _matchesWithScores == totalMatches && totalMatches > 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: _isCompleted 
              ? [Colors.green.shade100, Colors.green.shade50]
              : (canComplete 
                  ? [Colors.blue.shade100, Colors.blue.shade50]
                  : [Colors.grey.shade200, Colors.grey.shade100]),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _toggleCompletion,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isCompleted 
                                ? Colors.green.shade200
                                : (canComplete 
                                    ? Colors.blue.shade200 
                                    : Colors.grey.shade300),
                            width: 2,
                          ),
                        ),
                      ),
                      if (_isCompleted)
                        const Center(
                          child: Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.green,
                          ),
                        )
                      else if (!_checkingScores && totalMatches > 0)
                        Center(
                          child: Text(
                            '${(progress * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: canComplete ? Colors.blue : Colors.grey,
                            ),
                          ),
                        ),
                      if (_isLoading || _checkingScores)
                        const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isCompleted 
                          ? 'Completed' 
                          : (canComplete ? 'Ready to Complete' : 'In Progress'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _isCompleted 
                            ? Colors.green.shade700
                            : (canComplete 
                                ? Colors.blue.shade700 
                                : Colors.grey.shade600),
                      ),
                    ),
                    if (!_isCompleted && totalMatches > 0)
                      Text(
                        '$_matchesWithScores/$totalMatches matches',
                        style: TextStyle(
                          fontSize: 9,
                          color: canComplete 
                              ? Colors.blue.shade400 
                              : Colors.grey.shade500,
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
}