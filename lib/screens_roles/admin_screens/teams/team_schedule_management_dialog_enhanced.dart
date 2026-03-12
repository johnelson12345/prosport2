import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/scores.dart';
import 'package:tabulation_systemv7/services/team_service.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/participants_service.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';
import 'package:flutter/services.dart';

// Enhanced Team Schedule Management Dialog with modern UI/UX
class TeamScheduleManagementDialog extends StatefulWidget {
  final DateFormat dateFormat;
  final Map<String, dynamic>? existing;
  final String? tournamentId;
  final Map<String, dynamic>? tournamentDetails;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const TeamScheduleManagementDialog({
    super.key,
    required this.dateFormat,
    this.existing,
    this.tournamentId,
    this.tournamentDetails,
    required this.onSave,
  });

  @override
  _TeamScheduleManagementDialogState createState() =>
      _TeamScheduleManagementDialogState();
}

class _TeamScheduleManagementDialogState
    extends State<TeamScheduleManagementDialog> {
  late TextEditingController _dateController;
  late TextEditingController _endDateController;
  late TextEditingController _notesController;
  DateTime? _selectedDateTime;
  DateTime? _selectedEndDateTime;
  List<String> _selectedTeams = [];
  String? _selectedVenue;
  String _matchType = 'Elimination Round';
  bool _isLosersMatch = false;
  bool _isKnockout = false;
  String _matchStatus = 'Scheduled';
  String _priority = 'Normal';
  TimeOfDay? _matchDuration;
  bool _isLoadingTeams = true;
  String? _teamsError;

  final SportsEventService _sportsEventService = SportsEventService();
  List<Map<String, dynamic>> _availableTeams = [];
  final List<String> _venues = [
    'Court 1',
    'Court 2',
    'RFC',
    'Field',
  ];
  final List<String> _matchTypes = [
    'Elimination Round',
    'Quarter Final',
    'Cross Over',
    'Semi Final',
    'Finals'
  ];
  final List<String> _statusOptions = [
    'Scheduled',
    'In Progress',
    'Completed',
    'Postponed',
    'Cancelled'
  ];
  final List<String> _priorityOptions = ['Low', 'Normal', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadTeams();
  }

  void _initializeControllers() {
    _dateController = TextEditingController(
      text: widget.existing?['dateTime'] ?? '',
    );
    _endDateController = TextEditingController(
      text: widget.existing?['endDateTime'] ?? '',
    );
    _notesController = TextEditingController(
      text: widget.existing?['notes'] ?? '',
    );

    if (widget.existing != null) {
      _selectedTeams = List<String>.from(widget.existing!['teams'] ?? []);
      _isLosersMatch = widget.existing!['isLosersMatch'] ?? false;
      _isKnockout = widget.existing!['isKnockout'] ?? false;
      _matchType = widget.existing!['matchType'] ?? 'Elimination Round';
      _matchStatus = widget.existing!['status'] ?? 'Scheduled';
      _priority = widget.existing!['priority'] ?? 'Normal';
      _selectedVenue = widget.existing!['venue'] ?? _venues.first;
      _selectedDateTime = DateTime.tryParse(widget.existing!['dateTime'] ?? '');
      _selectedEndDateTime = widget.existing!['endDateTime'] != null
          ? DateTime.tryParse(widget.existing!['endDateTime'] ?? '')
          : null;
    } else {
      _selectedVenue = _venues.first;
    }
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoadingTeams = true;
      _teamsError = null;
    });
    try {
      // Load teams from 'participants' collection for the current sports event
      final activeEventId = await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        setState(() {
          _availableTeams = [];
          _isLoadingTeams = false;
        });
        return;
      }
      
      final snapshot = await FirebaseFirestore.instance
          .collection('participants')
          .where('sportsEventId', isEqualTo: activeEventId)
          .get();
      
      setState(() {
        _availableTeams = snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
            .toList();
        _isLoadingTeams = false;
      });
    } catch (e) {
      setState(() {
        _teamsError = 'Failed to load teams: $e';
        _isLoadingTeams = false;
      });
      debugPrint('Error loading teams: $e');
    }
  }

  Future<void> _selectDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedDateTime != null
            ? TimeOfDay.fromDateTime(_selectedDateTime!)
            : TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).primaryColor,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _dateController.text = widget.dateFormat.format(_selectedDateTime!);
        });
      }
    }
  }

  Future<void> _selectEndDateTime() async {
    // Default to 1 hour after start time if available
    final initialDate = _selectedEndDateTime ??
        (_selectedDateTime != null
            ? _selectedDateTime!.add(const Duration(hours: 1))
            : DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedEndDateTime != null
            ? TimeOfDay.fromDateTime(_selectedEndDateTime!)
            : TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Theme.of(context).primaryColor,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        setState(() {
          _selectedEndDateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          _endDateController.text =
              widget.dateFormat.format(_selectedEndDateTime!);
        });
      }
    }
  }

  Widget _buildTeamSelection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Teams',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_isLoadingTeams)
              const Center(child: CircularProgressIndicator())
            else if (_teamsError != null)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      _teamsError!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadTeams,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
            else if (_availableTeams.isEmpty)
              const Center(
                child: Text(
                  'No teams available',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            else
              ..._availableTeams.map((team) {
                final teamName = team['name'] ?? 'Unnamed Team';
                return CheckboxListTile(
                  title: Text(teamName),
                  subtitle: Text(team['category'] ?? 'No category'),
                  value: _selectedTeams.contains(teamName),
                  onChanged: (selected) {
                    setState(() {
                      if (selected == true) {
                        if (_selectedTeams.length < 2) {
                          _selectedTeams.add(teamName);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Maximum 2 teams per match'),
                            ),
                          );
                        }
                      } else {
                        _selectedTeams.remove(teamName);
                      }
                    });
                  },
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchDetails() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Match Details',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _matchType,
              decoration: const InputDecoration(
                labelText: 'Match Type',
                border: OutlineInputBorder(),
              ),
              items: _matchTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _matchType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _matchStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: _statusOptions.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _matchStatus = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: _priorityOptions.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(priority),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _priority = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Advanced Options',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Losers Match'),
              subtitle: const Text('Mark as elimination match'),
              value: _isLosersMatch,
              onChanged: (value) {
                setState(() {
                  _isLosersMatch = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Knockout Stage'),
              subtitle: const Text('This is a knockout match'),
              value: _isKnockout,
              onChanged: (value) {
                setState(() {
                  _isKnockout = value;
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedVenue,
              decoration: const InputDecoration(
                labelText: 'Venue',
                border: OutlineInputBorder(),
              ),
              items: _venues.map((venue) {
                return DropdownMenuItem(
                  value: venue,
                  child: Text(venue),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVenue = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                hintText: 'Additional match notes...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    if (_selectedTeams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one team')),
      );
      return;
    }

    if (_selectedTeams.length != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select exactly 2 teams')),
      );
      return;
    }

    if (_selectedVenue == null || _selectedVenue!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a venue')),
      );
      return;
    }

    try {
      final id = widget.existing != null
          ? widget.existing!['id']
          : DateTime.now().millisecondsSinceEpoch.toString();

      final newEntry = {
        'id': id,
        'dateTime': _selectedDateTime!.toIso8601String(),
        'endDateTime': _selectedEndDateTime?.toIso8601String(),
        'teams': _selectedTeams,
        'venue': _selectedVenue,
        'matchType': _matchType,
        'isLosersMatch': _isLosersMatch,
        'isKnockout': _isKnockout,
        'status': _matchStatus,
        'priority': _priority,
        'notes': _notesController.text,
        'isFixed': true, // Mark as Fixed match (manually created from team schedule dialog)
        'createdAt': widget.existing != null
            ? widget.existing!['createdAt']
            : DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (widget.tournamentId != null) {
        newEntry['tournamentSetupId'] = widget.tournamentId;
      }

      // Add tournament details if available
      if (widget.tournamentDetails != null) {
        newEntry['tournamentName'] = widget.tournamentDetails!['name'] ?? '';
        newEntry['sportName'] = widget.tournamentDetails!['sportId'] ?? '';
        newEntry['categoryName'] = widget.tournamentDetails!['categoryId'] ?? '';
        newEntry['gender'] = widget.tournamentDetails!['gender'] ?? '';
        newEntry['venue'] = widget.tournamentDetails!['venue'] ?? newEntry['venue'];
      }

      await widget.onSave(newEntry);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule saved successfully')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving schedule: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    Icon(
                      widget.existing == null ? Icons.add : Icons.edit,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.existing == null
                            ? 'Add Team Schedule'
                            : 'Edit Team Schedule',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _dateController,
                            decoration: InputDecoration(
                              labelText: 'Start Date & Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _selectDateTime,
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _endDateController,
                            decoration: InputDecoration(
                              labelText: 'End Date & Time',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.calendar_today),
                                onPressed: _selectEndDateTime,
                              ),
                            ),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTeamSelection(),
                    const SizedBox(height: 16),
                    _buildMatchDetails(),
                    const SizedBox(height: 16),
                    _buildAdvancedOptions(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveSchedule,
                      icon: const Icon(Icons.save),
                      label: Text(
                        widget.existing == null ? 'Create' : 'Update',
                      ),
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

  @override
  void dispose() {
    _dateController.dispose();
    _endDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// Enhanced Score Input Dialog
class ScoreInputDialog extends StatefulWidget {
  final Map<String, dynamic> schedule;
  final ScoresService scoresService;

  const ScoreInputDialog({
    super.key,
    required this.schedule,
    required this.scoresService,
  });

  @override
  _ScoreInputDialogState createState() => _ScoreInputDialogState();
}

class _ScoreInputDialogState extends State<ScoreInputDialog> {
  late Map<String, TextEditingController> _scoreControllers;
  late String _winner;
  late String _matchNotes;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final teams = List<String>.from(widget.schedule['teams'] ?? []);
    _scoreControllers = {};

    for (final team in teams) {
      final existingScore = widget.schedule['scores'] != null &&
              widget.schedule['scores'][team] != null
          ? widget.schedule['scores'][team].toString()
          : '';
      _scoreControllers[team] = TextEditingController(text: existingScore);
    }

    _winner = widget.schedule['winner'] ?? '';
    _matchNotes = widget.schedule['matchNotes'] ?? '';
  }

  Future<void> _saveScores() async {
    final scores = <String, int>{};
    for (final entry in _scoreControllers.entries) {
      final score = int.tryParse(entry.value.text.trim());
      if (score == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter valid score for ${entry.key}')),
        );
        return;
      }
      scores[entry.key] = score;
    }

    try {
      await widget.scoresService.updateScoresAndWinner(
        widget.schedule['id'],
        scores,
      );

      // Update additional match notes if provided
      if (_matchNotes.isNotEmpty) {
        final teamScheduleService = TeamScheduleService();
        await teamScheduleService.updateTeamSchedule(
          widget.schedule['id'],
          {'matchNotes': _matchNotes},
        );
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving scores: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final teams = List<String>.from(widget.schedule['teams'] ?? []);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.5,
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
                    const Icon(Icons.score, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Match Scores: ${teams.join(' vs ')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ...teams.map((team) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextField(
                          controller: _scoreControllers[team],
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: InputDecoration(
                            labelText: '$team Score',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.sports_score),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Match Notes',
                        border: OutlineInputBorder(),
                        hintText: 'Additional match details...',
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        _matchNotes = value;
                      },
                      controller: TextEditingController(text: _matchNotes),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _saveScores,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Scores'),
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

  @override
  void dispose() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

// Helper functions for backward compatibility
Future<void> showAddEditDialog({
  required BuildContext context,
  required DateFormat dateFormat,
  Map<String, dynamic>? existing,
  String? tournamentId,
  Map<String, dynamic>? tournamentDetails,
  required Future<void> Function(Map<String, dynamic>) onSave,
}) async {
  return showDialog(
    context: context,
    builder: (context) => TeamScheduleManagementDialog(
      dateFormat: dateFormat,
      existing: existing,
      tournamentId: tournamentId,
      tournamentDetails: tournamentDetails,
      onSave: onSave,
    ),
  );
}

Future<void> showScoreInputDialog({
  required BuildContext context,
  required Map<String, dynamic> schedule,
  required ScoresService scoresService,
}) async {
  return showDialog(
    context: context,
    builder: (context) => ScoreInputDialog(
      schedule: schedule,
      scoresService: scoresService,
    ),
  );
}
