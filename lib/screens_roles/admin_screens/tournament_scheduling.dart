import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/teams/team_schedule_management_dialog_enhanced.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/tournament_mngmt_dialog.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/bracket.dart';
import 'package:tabulation_systemv7/services/scores.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';
import 'package:tabulation_systemv7/services/team_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';

class TournamentDetailsNotifier
    extends ValueNotifier<Map<String, Map<String, dynamic>>> {
  TournamentDetailsNotifier(super.value);
}

class AdminTeamScheduleManagementScreen extends StatefulWidget {
  const AdminTeamScheduleManagementScreen({super.key});

  @override
  _TeamScheduleManagementScreenState createState() =>
      _TeamScheduleManagementScreenState();
}

class _TeamScheduleManagementScreenState
    extends State<AdminTeamScheduleManagementScreen> {
  final TeamScheduleService _service = TeamScheduleService();
  final TournamentService _tournamentService = TournamentService();
  final ScoresService _scoresService = ScoresService();
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
  DateTime? _selectedDate;
  int _currentPage = 0;
  int _itemsPerPage = 20;
  bool _isAddingMatch = false;
  bool _isEditingMatch = false;
  bool _isDeletingMatch = false;
  bool _isEditingVenue = false;
  bool _isEditingStatus = false;
  bool _isDeletingAll = false;

  @override
  void initState() {
    super.initState();
    _tournamentDetailsNotifier = TournamentDetailsNotifier({});
    _loadTournamentData();
    _loadTeamsData();
    _loadUserEmails();
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
          'selectedTeamIds': data['selectedTeamIds'] ?? [], // ADD THIS LINE
        };
      }
      setState(() {
        _tournamentNames = names;
        _tournamentDetailsNotifier.value = details;
      });
    });
  }

  // SIMPLIFIED EDIT MATCH DIALOG with working loading indicator
  Future<void> _showEditMatchDialog(
      String tournamentId, Map<String, dynamic> match) async {
    if (_isEditingMatch) return; // Prevent multiple clicks

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
                    // Form fields (disabled when processing)
                    Opacity(
                      opacity: isProcessing ? 0.5 : 1.0,
                      child: AbsorbPointer(
                        absorbing: isProcessing,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Team 1 Selection
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

                              // Team 2 Selection
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

                              // Date & Time Selection
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

                    // Loading indicator
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

                            final updatedMatch = {
                              ...match,
                              'team1': team1,
                              'team2': team2,
                              'team1Id': team1['id'],
                              'team2Id': team2['id'],
                              'team1Name': team1['name'],
                              'team2Name': team2['name'],
                              'dateTime': selectedDateTime!.toIso8601String(),
                              'startTime': selectedDateTime!.toIso8601String(),
                              'isFixedMatch': true,
                            };

                            await _service.updateTeamSchedule(
                                match['id'], updatedMatch);

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

    final currentVenue =
        _tournamentDetailsNotifier.value[tournamentId]?['venue'] ?? 'Court 1';

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
                width: 450, // Wider to accommodate two time pickers
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wrap everything in AbsorbPointer and Opacity
                    AbsorbPointer(
                      absorbing: isProcessing,
                      child: Opacity(
                        opacity: isProcessing ? 0.5 : 1.0,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Team 1 Selection
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

                              // Team 2 Selection
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

                              // Schedule Section Header
                              const Text('Schedule',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13)),
                              const SizedBox(height: 12),

                              // START DATE & TIME
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

                              // END DATE & TIME
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

                              // Quick set duration buttons (optional helper)
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

                              // Show venue being used
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.blue.shade200),
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

                    // Loading indicator
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
                          // Validate inputs
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

// Add null checks with ! since we've already validated they're not null
                          if (endDateTime!.isBefore(startDateTime!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'End time must be after start time')),
                            );
                            return;
                          }

                          // Show loading state
                          setDialogState(() {
                            isProcessing = true;
                          });

                          try {
                            final team1 = tournamentTeams
                                .firstWhere((t) => t['id'] == selectedTeam1);
                            final team2 = tournamentTeams
                                .firstWhere((t) => t['id'] == selectedTeam2);

                            // Format dates as dd/MM/yyyy HH:mm (matching your data structure)
                            final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

                            final newMatch = {
                              'id': const Uuid().v4(),
                              'matchNumber': _getNextMatchNumber(tournamentId),
                              'round': 1,
                              'team1': team1,
                              'team2': team2,
                              'team1Id': team1['id'],
                              'team2Id': team2['id'],
                              'team1Name': team1['name'],
                              'team2Name': team2['name'],
                              'dateTime': dateFormat
                                  .format(startDateTime!), // Start time
                              'startTime': dateFormat.format(startDateTime!),
                              'endTime': dateFormat.format(endDateTime!),
                              'tournamentSetupId': tournamentId,
                              'tournamentName':
                                  _tournamentNames[tournamentId] ??
                                      'Tournament',
                              'sport': _getTournamentSport(tournamentId),
                              'category': _getTournamentCategory(tournamentId),
                              'gender': _getTournamentGender(tournamentId),
                              'venue': currentVenue,
                              'type': 'regular',
                              'status': 'scheduled',
                              'isFixedMatch': true,
                              'winner': null,
                              'loser': null,
                              'scores': {},
                            };

                            await _service.createTeamSchedule(newMatch);

                            if (context.mounted) {
                              Navigator.pop(context); // Close dialog
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
      _teamDetails = teamDetails;
    });
  }

  void _loadUserEmails() async {
    try {
      final usersSnapshot =
          await FirebaseFirestore.instance.collection('users').get();
      final Map<String, String> userEmails = {};
      final Map<String, String> userNames = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
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

  // Helper methods for tournament data
  Future<List<Map<String, dynamic>>> _getTournamentTeams(
      String tournamentId) async {
    // Try to get tournament data directly from Firestore
    try {
      final tournamentQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: tournamentId)
          .get();

      if (tournamentQuery.docs.isNotEmpty) {
        final tournamentData = tournamentQuery.docs.first.data();

        // Check for team IDs in various possible field names
        List<String> teamIds = [];

        if (tournamentData.containsKey('selectedTeamIds')) {
          teamIds = List<String>.from(tournamentData['selectedTeamIds'] ?? []);
        } else if (tournamentData.containsKey('teamIds')) {
          teamIds = List<String>.from(tournamentData['teamIds'] ?? []);
        } else if (tournamentData.containsKey('teams')) {
          teamIds = List<String>.from(tournamentData['teams'] ?? []);
        }

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
              } else {}
            } catch (e) {}
          }
          return teams;
        }
      }
    } catch (e) {}

    // Fallback to notifier data
    final tournamentInfo = _tournamentDetailsNotifier.value[tournamentId];
    if (tournamentInfo == null) {
      return [];
    }

    final teamIds = tournamentInfo['selectedTeamIds'] as List? ?? [];

    if (teamIds.isEmpty) {
      return [];
    }

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
        } else {}
      } catch (e) {}
    }

    return teams;
  }

  int _getNextMatchNumber(String tournamentId) {
    // This would need to be implemented to get the next match number
    // For now, return a temporary value
    return DateTime.now().millisecondsSinceEpoch % 1000;
  }

  String _getTournamentSport(String tournamentId) {
    return _tournamentDetailsNotifier.value[tournamentId]?['sport'] ??
        'Unknown';
  }

  String _getTournamentCategory(String tournamentId) {
    return _tournamentDetailsNotifier.value[tournamentId]?['category'] ??
        'Unknown';
  }

  String _getTournamentGender(String tournamentId) {
    return _tournamentDetailsNotifier.value[tournamentId]?['gender'] ??
        'Unknown';
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
    await _service.deleteTeamSchedule(id);
  }

  // Organize matches in proper bracket format based on team count
  List<Map<String, dynamic>> _organizeMatchesInBracketFormat(
      List<Map<String, dynamic>> matches) {
    if (matches.isEmpty) return [];

    // Sort by match number
    matches.sort((a, b) {
      final aNum = a['matchNumber'] ?? 999;
      final bNum = b['matchNumber'] ?? 999;
      return aNum.compareTo(bNum);
    });

    // Check if using new structured format
    final sampleMatch = matches.first;
    if (sampleMatch.containsKey('team1') && sampleMatch.containsKey('team2')) {
      // New format - add round information based on bracket structure
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

    // Legacy format
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

  // Calculate round based on match number and total matches
  int _calculateRound(int? matchNumber, int totalMatches) {
    if (matchNumber == null) return 1;

    if (totalMatches <= 3) {
      // 2-4 teams: Round 1 = matches 1-2, Round 2 = match 3
      return matchNumber <= 2 ? 1 : 2;
    } else if (totalMatches <= 5) {
      // 5-6 teams: Round 1 = matches 1-2, Round 2 = matches 3-4, Round 3 = match 5
      if (matchNumber <= 2) return 1;
      if (matchNumber <= 4) return 2;
      return 3;
    } else if (totalMatches <= 7) {
      // 7-8 teams: Round 1 = matches 1-4, Round 2 = matches 5-6, Round 3 = match 7
      if (matchNumber <= 4) return 1;
      if (matchNumber <= 6) return 2;
      return 3;
    } else {
      // 9-16 teams: More complex calculation
      int matchesInRound1 = totalMatches - (1 << (totalMatches.bitLength - 2));
      if (matchNumber <= matchesInRound1) return 1;
      return 2 +
          ((matchNumber - matchesInRound1 - 1) ~/ (matchesInRound1 ~/ 2));
    }
  }

  // Get bracket type based on match data
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
            // Add items per page selector
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
            stream: _service.getAllTeamSchedules(limit: 10000),
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

              final teamSchedules = snapshot.data!;
              if (teamSchedules.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sports_score,
                          size: 80, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'No team schedules found.',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }

              // Apply search filter
              var filteredSchedules = teamSchedules.where((schedule) {
                final tournamentName =
                    _tournamentNames[schedule['tournamentSetupId']]
                            ?.toLowerCase() ??
                        '';

                String teamList = '';
                if (schedule.containsKey('teams')) {
                  teamList =
                      (schedule['teams'] as List?)?.join(" ").toLowerCase() ??
                          '';
                } else if (schedule.containsKey('team1') &&
                    schedule.containsKey('team2')) {
                  final team1 = schedule['team1'] as Map<String, dynamic>?;
                  final team2 = schedule['team2'] as Map<String, dynamic>?;
                  teamList = '${team1?['name'] ?? ''} ${team2?['name'] ?? ''}'
                      .toLowerCase();
                }

                return tournamentName.contains(_searchQuery) ||
                    teamList.contains(_searchQuery);
              }).toList();

              // Apply date filter
              if (_selectedDate != null) {
                filteredSchedules = filteredSchedules.where((schedule) {
                  try {
                    final dateTimeStr =
                        schedule['dateTime'] ?? schedule['startTime'];
                    if (dateTimeStr == null) return false;
                    final date = DateTime.parse(dateTimeStr.toString());
                    return date.year == _selectedDate!.year &&
                        date.month == _selectedDate!.month &&
                        date.day == _selectedDate!.day;
                  } catch (e) {
                    return false;
                  }
                }).toList();
              }

              // Group schedules by tournament
              Map<String, List<Map<String, dynamic>>> groupedSchedules = {};
              for (var schedule in filteredSchedules) {
                final tournamentId =
                    schedule['tournamentSetupId'] ?? 'Unknown Tournament';
                groupedSchedules
                    .putIfAbsent(tournamentId, () => [])
                    .add(schedule);
              }

              final allEntries = groupedSchedules.entries.toList();
              final totalPages = (allEntries.length / _itemsPerPage).ceil();

              // Ensure current page is valid
              if (_currentPage >= totalPages && totalPages > 0) {
                _currentPage = totalPages - 1;
              }

              final startIndex = _currentPage * _itemsPerPage;
              final endIndex = (startIndex + _itemsPerPage) > allEntries.length
                  ? allEntries.length
                  : startIndex + _itemsPerPage;

              final paginatedEntries = allEntries.isEmpty
                  ? []
                  : allEntries.sublist(
                      startIndex > allEntries.length ? 0 : startIndex,
                      endIndex);

              return Column(
                children: [
                  // Pagination info and controls
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
                        // Showing X-Y of Z entries
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Showing ${allEntries.isEmpty ? 0 : startIndex + 1}-${allEntries.isEmpty ? 0 : endIndex} of ${allEntries.length} tournaments',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),

                        // Pagination controls
                        Row(
                          children: [
                            // Previous button
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

                            // Page numbers
                            if (totalPages > 1) ...[
                              _buildPageNumbers(totalPages, _currentPage),
                            ],

                            const SizedBox(width: 8),

                            // Next button
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

                        // Items per page indicator
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

                  // Grid content
                  Expanded(
                    child: paginatedEntries.isEmpty
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
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: paginatedEntries.length,
                            itemBuilder: (context, index) {
                              final entry = paginatedEntries[index];
                              final tournamentId = entry.key;
                              final schedules = entry.value;
                              final tournamentName =
                                  _tournamentNames[tournamentId] ??
                                      tournamentId;

                              final organizedMatches =
                                  _organizeMatchesInBracketFormat(schedules);

                              final sportName = schedules.isNotEmpty
                                  ? schedules.first['sport'] ??
                                      schedules.first['sportName'] ??
                                      'Unknown Sport'
                                  : 'Unknown Sport';
                              final categoryName = schedules.isNotEmpty
                                  ? schedules.first['category'] ??
                                      schedules.first['categoryName'] ??
                                      'Unknown Category'
                                  : 'Unknown Category';

                              final sportIcon = _getSportIcon(sportName);
                              final categoryColor =
                                  _getCategoryColor(categoryName);

                              // Calculate bracket info
                              final teamCount = _extractTeamCount(schedules);
                              final bracketInfo =
                                  _getBracketInfo(teamCount, schedules.length);

                              return _BracketStyleTournamentCard(
                                tournamentId: tournamentId,
                                tournamentName: tournamentName,
                                sportIcon: sportIcon,
                                sportName: sportName,
                                categoryName: categoryName,
                                categoryColor: categoryColor,
                                schedules: organizedMatches,
                                originalSchedules: schedules,
                                tournamentDetails: _tournamentDetailsNotifier
                                    .value[tournamentId],
                                teamCount: teamCount,
                                bracketInfo: bracketInfo,
                                onEditVenue: () => _editVenue(tournamentId),
                                onEditStatus: () => _editStatus(tournamentId),
                                onDeleteAll: () =>
                                    _deleteAllTournamentData(tournamentId),
                                onAddMatch: () async {
                                  await _showAddMatchDialog(tournamentId);
                                },
                                onEditMatch: (item) =>
                                    _showEditMatchDialog(tournamentId, item),
                                onDeleteMatch: (item) async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: const Text(
                                          'Are you sure you want to delete this schedule?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
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
                              );
                            },
                          ),
                  ),

                  // Bottom pagination (optional - you can remove if not needed)
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
                          // Simple bottom pagination
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

// Helper method to build pagination buttons
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

// Helper method to build page number buttons
  Widget _buildPageNumbers(int totalPages, int currentPage) {
    List<Widget> pageButtons = [];

    // Always show first page
    pageButtons.add(_buildPageNumberButton(1, currentPage == 0));

    if (totalPages > 7) {
      // Show ellipsis if needed
      if (currentPage > 3) {
        pageButtons.add(
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: const Text('...',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ),
        );
      }

      // Show pages around current page
      int start = currentPage > 3 ? currentPage - 1 : 2;
      int end = currentPage < totalPages - 4 ? currentPage + 1 : totalPages - 2;

      for (int i = start; i <= end; i++) {
        if (i > 1 && i < totalPages) {
          pageButtons.add(_buildPageNumberButton(i + 1, currentPage == i));
        }
      }

      // Show ellipsis before last page
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
      // Show all pages if total pages is 7 or less
      for (int i = 2; i <= totalPages - 1; i++) {
        pageButtons.add(_buildPageNumberButton(i, currentPage == i - 1));
      }
    }

    // Always show last page if there is more than one page
    if (totalPages > 1) {
      pageButtons.add(
          _buildPageNumberButton(totalPages, currentPage == totalPages - 1));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: pageButtons,
    );
  }

// Helper method to build individual page number button
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

  // Extract team count from schedules
  int _extractTeamCount(List<Map<String, dynamic>> schedules) {
    if (schedules.isEmpty) return 0;

    // Try to get from tournament details
    final tournamentId = schedules.first['tournamentSetupId'];
    final tournamentInfo = _tournamentDetailsNotifier.value[tournamentId];
    if (tournamentInfo != null &&
        tournamentInfo.containsKey('selectedTeamIds')) {
      final teamIds = tournamentInfo['selectedTeamIds'] as List?;
      if (teamIds != null) return teamIds.length;
    }

    // Estimate from number of matches (matches = teams - 1)
    return schedules.length + 1;
  }

  // Get bracket info string
  String _getBracketInfo(int teamCount, int matchCount) {
    if (teamCount <= 0) return '';

    int rounds = (teamCount - 1).bitLength;
    int bracketSize = 1 << rounds;

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
      final schedulesSnapshot = await FirebaseFirestore.instance
          .collection('team_schedules')
          .where('tournamentSetupId', isEqualTo: tournamentId)
          .get();
      final schedulesCount = schedulesSnapshot.docs.length;

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
                        count: schedulesCount,
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
          int deletedSchedules = 0;
          int deletedScores = 0;

          for (var doc in schedulesSnapshot.docs) {
            try {
              await doc.reference.delete();
              deletedSchedules++;
            } catch (e) {}
          }

          for (var doc in scoresSnapshot.docs) {
            try {
              await doc.reference.delete();
              deletedScores++;
            } catch (e) {}
          }

          try {
            final tournamentQuery = await FirebaseFirestore.instance
                .collection('tournaments')
                .where('id', isEqualTo: tournamentId)
                .get();

            if (tournamentQuery.docs.isNotEmpty) {
              final tournamentDoc = tournamentQuery.docs.first;
              await FirebaseFirestore.instance
                  .collection('tournaments')
                  .doc(tournamentDoc.id)
                  .delete();
            }
          } catch (e) {}

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
                    Text('• $deletedSchedules matches deleted'),
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
  final Future<void> Function() onAddMatch; // Change from VoidCallback to this
  final Function(Map<String, dynamic>) onEditMatch;
  final Function(Map<String, dynamic>) onDeleteMatch;
  final VoidCallback onShowBracket;
  final String Function(String) formatDateTime;
  final String Function(String?) formatEndDateTime;
  final String Function(List<dynamic>?) getUserNamesString;

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
  });

  @override
  Widget build(BuildContext context) {
    final isActive = tournamentDetails?['status'] == 'Active';
    final venue = tournamentDetails?['venue'] ?? 'Not specified';
    final assignedUsers = tournamentDetails?['assignedUsers'] as List<dynamic>?;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.green.shade200 : Colors.grey.shade200,
          ),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child:
                          Text(sportIcon, style: const TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            tournamentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info Row
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
                          label: '${originalSchedules.length} matches',
                          color: Colors.orange,
                        ),
                      ],
                    ),

                    // Bracket Info
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.deepOrange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.deepOrange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.account_tree,
                              size: 14, color: Colors.deepOrange.shade700),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              bracketInfo,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.deepOrange.shade700,
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
                                color: Colors.deepOrange.shade700,
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

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            onPressed: () async {
                              // Create a completer to track when dialog is ready
                              final dialogCompleter = Completer<void>();

                              // Show loading indicator with Future that will complete when dialog is ready
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) {
                                  return FutureBuilder<void>(
                                    future: dialogCompleter.future,
                                    builder: (context, snapshot) {
                                      return Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(24),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 16),
                                              Text(
                                                snapshot.connectionState ==
                                                        ConnectionState.waiting
                                                    ? 'Loading match dialog...'
                                                    : 'Ready!',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
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

                              // Small delay to ensure dialog is shown
                              await Future.delayed(
                                  const Duration(milliseconds: 100));

                              // Now actually load the add match dialog
                              // This will wait for the dialog to be fully ready
                              await onAddMatch();

                              // Complete the future to close the loading dialog
                              if (!dialogCompleter.isCompleted) {
                                dialogCompleter.complete();
                              }

                              // Small delay to show the "Ready!" message
                              await Future.delayed(
                                  const Duration(milliseconds: 300));

                              // Close loading dialog
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                            icon: Icons.add,
                            label: 'Match',
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _ActionButton(
                            onPressed: onShowBracket,
                            icon: Icons.account_tree,
                            label: 'Bracket',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _IconButton(
                          onPressed: onEditStatus,
                          icon: Icons.edit,
                          color: Colors.orange,
                          tooltip: 'Edit Status',
                        ),
                        _IconButton(
                          onPressed: onDeleteAll,
                          icon: Icons.delete,
                          color: Colors.red,
                          tooltip: 'Delete All',
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // MATCHES GRID
                    const Text(
                      'MATCHES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
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
                        : _buildCompactMatchesGrid(),
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

    // Get team names, replacing "Winner Match X" with just "M{X}"
    String team1Name = _getDisplayName(team1, match['team1Name']);
    String team2Name = _getDisplayName(team2, match['team2Name']);

    final scores = match['scores'] as Map<String, dynamic>? ?? {};
    final winner = match['winner'];
    final matchType = match['matchType'] ?? 'regular';
    final bracket = match['bracket'] as String?;
    final round = match['round'] as int? ?? 1;
    final nextMatchRef = match['nextMatchReference'];
    final isBye = matchType == 'bye';
    final isFixedMatch = match['isFixedMatch'] == true;

    // Get round name based on bracket structure
    String roundName = 'Round $round';
    if (bracket == 'winners') {
      roundName = 'Winners R$round';
    } else if (bracket == 'losers') {
      roundName = 'Losers R$round';
    } else if (bracket == 'finals') {
      roundName = match['isIfNecessary'] == true ? 'If Necessary' : 'Final';
    } else if (isFixedMatch) {
      roundName = 'FIXED'; // Show FIXED instead of round number
    }

    // Border color based on match type
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

    // Background color for header
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
          // Match header
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
                // Match number badge in header
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
                // Add FIXED label badge
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

          // Match content
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                if (isBye) ...[
                  _buildTeamRow(
                    name: team1Name,
                    score: scores[team1Name]?.toString(),
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
                    score: scores[team1Name]?.toString() ??
                        scores[team1['id']]?.toString(),
                    isWinner: winner == team1['id'] || winner == team1Name,
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: Text('VS',
                        style: TextStyle(fontSize: 7, color: Colors.grey)),
                  ),
                  _buildTeamRow(
                    name: team2Name,
                    score: scores[team2Name]?.toString() ??
                        scores[team2['id']]?.toString(),
                    isWinner: winner == team2['id'] || winner == team2Name,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _MiniButton(
                      onPressed: onEdit,
                      icon: Icons.edit,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 2),
                    _MiniButton(
                      onPressed: onDelete,
                      icon: Icons.delete,
                      color: Colors.red,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get display name - replaces "Winner Match X" with "M{X}"
  String _getDisplayName(Map<String, dynamic> team, String? teamName) {
    if (teamName != null && teamName.isNotEmpty) {
      // Check if it's a winner placeholder
      if (teamName.contains('Winner Match')) {
        final matchNumber = teamName.replaceAll(RegExp(r'[^0-9]'), '');
        return 'M$matchNumber';
      }
      // Check if it's a loser placeholder
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

// Helper method to get display name - replaces "Winner Match X" with "M{X}"
String _getDisplayName(Map<String, dynamic> team, String? teamName) {
  if (teamName != null && teamName.isNotEmpty) {
    // Check if it's a winner placeholder
    if (teamName.contains('Winner Match')) {
      final matchNumber = teamName.replaceAll(RegExp(r'[^0-9]'), '');
      return 'M$matchNumber';
    }
    // Check if it's a loser placeholder
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

class _MiniButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;

  const _MiniButton({
    required this.onPressed,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Icon(icon, size: 10, color: color),
      ),
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

class _IconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color color;
  final String tooltip;

  const _IconButton({
    required this.onPressed,
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 12, color: color),
        tooltip: tooltip,
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
      ),
    );
  }
}

// Add this helper widget at the bottom of your file
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
