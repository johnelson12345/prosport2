// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/services/match_schedule_service.dart';

/// =====================================================
/// HELPER FUNCTION: Generate Unique ID
/// =====================================================
String _generateUniqueId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final random = Random().nextInt(99999).toString().padLeft(5, '0');
  return '${timestamp}_$random';
}

String _formatTimeSlot(String? dateTimeStr) {
  if (dateTimeStr == null || dateTimeStr.isEmpty) return '';

  try {
    final dateTime = DateTime.parse(dateTimeStr);
    return DateFormat('hh:mm a').format(dateTime);
  } catch (e) {
    return '';
  }
}

/// =====================================================
/// SCHEDULES DATA SOURCE
/// =====================================================

class SchedulesDataSource extends DataTableSource {
  final List<Map<String, dynamic>> schedules;
  final void Function(Map<String, dynamic> schedule) onEdit;
  final void Function(String scheduleId) onDelete;

  SchedulesDataSource(this.schedules, this.onEdit, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= schedules.length) return null;

    final schedule = schedules[index];
    final startTimeStr = schedule['startTime'] as String? ??
        schedule['dateTime'] as String? ??
        '';
    final endTimeStr = schedule['endTime'] as String? ??
        startTimeStr; // Default end to start if not set
    final isOccupied = schedule['isOccupied'] as bool? ?? false;

    final formattedStartTime = _formatDateTime(startTimeStr);
    final formattedEndTime = _formatDateTime(endTimeStr);
    final occupiedText = isOccupied ? 'Yes' : 'No';

    return DataRow(
      cells: [
        DataCell(Text(formattedStartTime)),
        DataCell(Text(formattedEndTime)),
        DataCell(Text(occupiedText)),
        DataCell(
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit(schedule);
              } else if (value == 'delete') {
                onDelete(schedule['id']);
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

  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.tryParse(dateTimeStr);
      if (dateTime != null) {
        return DateFormat('MMM dd, yyyy hh:mm a').format(dateTime);
      }
      return dateTimeStr;
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  int get rowCount => schedules.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

/// =====================================================
/// MATRIX TABLE DATA SOURCE
/// =====================================================

class ScheduleMatrixDataSource extends DataTableSource {
  final Map<String, List<Map<String, dynamic>>> schedulesByDate;
  final List<String> timeSlots;
  final void Function(Map<String, dynamic> schedule) onEdit;
  final void Function(String scheduleId) onDelete;

  ScheduleMatrixDataSource(
    this.schedulesByDate,
    this.timeSlots,
    this.onEdit,
    this.onDelete,
  );

  @override
  DataRow? getRow(int index) {
    if (index >= timeSlots.length) return null;

    final timeSlot = timeSlots[index];
    return DataRow(
      cells: [
        DataCell(Text(timeSlot)),
        ...schedulesByDate.keys.map((date) {
          final daySchedules = schedulesByDate[date] ?? [];
          final schedule = daySchedules.firstWhere(
            (s) => _formatTime(s['startTime'] as String?) == timeSlot,
            orElse: () => <String, dynamic>{},
          );

          if (schedule.isEmpty) {
            return const DataCell(Text('-'));
          }

          final isOccupied = schedule['isOccupied'] as bool? ?? false;
          return DataCell(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOccupied ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isOccupied ? 'Occupied' : 'Available',
                style: TextStyle(
                  color:
                      isOccupied ? Colors.red.shade700 : Colors.green.shade700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('hh:mm a').format(dateTime);
    } catch (e) {
      return '';
    }
  }

  @override
  int get rowCount => timeSlots.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

class SchedulesManagementScreen extends StatefulWidget {
  final bool embedded;

  const SchedulesManagementScreen({super.key, this.embedded = false});

  @override
  _SchedulesManagementScreenState createState() =>
      _SchedulesManagementScreenState();
}

class _SchedulesManagementScreenState extends State<SchedulesManagementScreen>
    with SingleTickerProviderStateMixin {
  final MatchScheduleService _matchScheduleService = MatchScheduleService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _schedules = [];
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _subscribeToSchedules();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _subscribeToSchedules() {
    _subscription =
        _matchScheduleService.getAllMatchSchedules().listen((schedules) {
      setState(() {
        _schedules = schedules;
      });
    });
  }

  List<Map<String, dynamic>> get _filteredSchedules {
    if (_searchQuery.isEmpty) {
      return _schedules;
    }
    return _schedules.where((schedule) {
      final startTimeStr = schedule['startTime'] as String? ??
          schedule['dateTime'] as String? ??
          '';
      final endTimeStr = schedule['endTime'] as String? ?? '';
      final occupiedStr =
          (schedule['isOccupied'] as bool? ?? false) ? 'yes' : 'no';
      return startTimeStr.toLowerCase().contains(_searchQuery) ||
          endTimeStr.toLowerCase().contains(_searchQuery) ||
          occupiedStr.contains(_searchQuery);
    }).toList();
  }

  /// Get schedules grouped by date for matrix view
  Map<String, List<Map<String, dynamic>>> get _schedulesByDate {
    final Map<String, List<Map<String, dynamic>>> result = {};
    for (var schedule in _filteredSchedules) {
      final startTimeStr = schedule['startTime'] as String? ?? '';
      if (startTimeStr.isEmpty) continue;

      try {
        final dateTime = DateTime.parse(startTimeStr);
        final dateKey = DateFormat('MMM dd, yyyy').format(dateTime);
        result.putIfAbsent(dateKey, () => []);
        result[dateKey]!.add(schedule);
      } catch (e) {
        // Skip invalid dates
      }
    }
    return result;
  }

  /// Get unique time slots from schedules
  List<String> get _timeSlots {
    final Set<String> times = {};
    for (var schedule in _filteredSchedules) {
      final startTimeStr = schedule['startTime'] as String? ?? '';
      if (startTimeStr.isEmpty) continue;

      try {
        final dateTime = DateTime.parse(startTimeStr);
        times.add(DateFormat('hh:mm a').format(dateTime));
      } catch (e) {
        // Skip invalid dates
      }
    }
    return times.toList()..sort();
  }

  /// Validate schedule before saving
  Future<String?> _validateSchedule({
    required DateTime startTime,
    required DateTime endTime,
    String? excludeId,
  }) async {
    // Validate endTime > startTime
    if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
      return 'End time must be after start time';
    }

    // Check for duplicates
    final isDuplicate = await _matchScheduleService.isDuplicateSchedule(
      startTime: startTime.toIso8601String(),
      endTime: endTime.toIso8601String(),
      excludeId: excludeId,
    );

    if (isDuplicate) {
      return 'A schedule with the same start and end time already exists';
    }

    // Check for overlaps (with 5-minute buffer)
    final hasOverlap = await _matchScheduleService.hasOverlappingSchedule(
      startTime: startTime.toIso8601String(),
      endTime: endTime.toIso8601String(),
      excludeId: excludeId,
      bufferMinutes: 5,
    );

    if (hasOverlap) {
      return 'This schedule overlaps with an existing schedule';
    }

    return null;
  }

  Future<void> _showScheduleDialog({Map<String, dynamic>? schedule}) async {
    DateTime? selectedStartTime;
    DateTime? selectedEndTime;
    bool isOccupied = false;
    String? localValidationError;

    if (schedule != null) {
      final dateTimeStr = schedule['dateTime'] ?? schedule['startTime'] ?? '';
      selectedStartTime = DateTime.tryParse(dateTimeStr);
      selectedEndTime = DateTime.tryParse(schedule['endTime'] ?? dateTimeStr);
      isOccupied = schedule['isOccupied'] as bool? ?? false;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:
                  Text(schedule == null ? 'Add New Schedule' : 'Edit Schedule'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Validation error message
                    if (localValidationError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localValidationError!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Start Time Picker
                    ElevatedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedStartTime ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                                selectedStartTime ?? DateTime.now()),
                          );
                          if (time != null) {
                            setState(() {
                              selectedStartTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                              // Clear validation error when time changes
                              localValidationError = null;
                            });
                          }
                        }
                      },
                      child: const Text('Select Start Date & Time'),
                    ),
                    if (selectedStartTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            'Start: ${DateFormat('MMM dd, yyyy hh:mm a').format(selectedStartTime!)}'),
                      ),
                    const SizedBox(height: 16),

                    // End Time Picker
                    ElevatedButton(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedEndTime ??
                              selectedStartTime ??
                              DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                                selectedEndTime ??
                                    selectedStartTime ??
                                    DateTime.now()),
                          );
                          if (time != null) {
                            setState(() {
                              selectedEndTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                              // Clear validation error when time changes
                              localValidationError = null;
                            });
                          }
                        }
                      },
                      child: const Text('Select End Date & Time'),
                    ),
                    if (selectedEndTime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            'End: ${DateFormat('MMM dd, yyyy hh:mm a').format(selectedEndTime!)}'),
                      ),
                    const SizedBox(height: 16),

                    // Occupied Checkbox
                    CheckboxListTile(
                      title: const Text('Occupied'),
                      value: isOccupied,
                      onChanged: (value) {
                        setState(() {
                          isOccupied = value ?? false;
                        });
                      },
                    ),

                    // Info text
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        'Note: Duplicate schedules and overlapping times will be prevented.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (selectedStartTime != null && selectedEndTime != null) {
                      // Validate the schedule
                      final validationError = await _validateSchedule(
                        startTime: selectedStartTime!,
                        endTime: selectedEndTime!,
                        excludeId: schedule?['id'] as String?,
                      );

                      if (validationError != null) {
                        setState(() {
                          localValidationError = validationError;
                        });
                        return;
                      }

                      try {
                        final scheduleData = {
                          'startTime': selectedStartTime!.toIso8601String(),
                          'endTime': selectedEndTime!.toIso8601String(),
                          'isOccupied': isOccupied,
                        };

                        if (schedule == null) {
                          // Add new schedule with unique ID
                          scheduleData['id'] = _generateUniqueId();
                          await _matchScheduleService
                              .createMatchSchedule(scheduleData);
                        } else {
                          // Update existing schedule
                          await _matchScheduleService.updateMatchSchedule(
                            schedule['id'],
                            scheduleData,
                          );
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(schedule == null
                                ? 'Schedule added successfully'
                                : 'Schedule updated successfully'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Please select both start and end times'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  child: Text(schedule == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _editSchedule(Map<String, dynamic> schedule) =>
      _showScheduleDialog(schedule: schedule);

  void _deleteSchedule(String scheduleId) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    ).then((confirm) {
      if (confirm == true) {
        _matchScheduleService.deleteMatchSchedule(scheduleId).then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }).catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting schedule: $e'),
              backgroundColor: Colors.red,
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
        title: const Text('Schedule Management'),
        backgroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'List View', icon: Icon(Icons.list)),
            Tab(text: 'Matrix View', icon: Icon(Icons.grid_view)),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Schedule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: () => _showScheduleDialog(),
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // List View
          _buildListView(),
          // Matrix View
          _buildMatrixView(),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Schedules',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _schedules.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No schedules available.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: PaginatedDataTable(
                      header: const Text('Schedules List'),
                      rowsPerPage: 10,
                      showCheckboxColumn: false,
                      columnSpacing: 200,
                      columns: const [
                        DataColumn(label: Text('Start Time')),
                        DataColumn(label: Text('End Time')),
                        DataColumn(label: Text('Occupied')),
                        DataColumn(label: Text('Actions')),
                      ],
                      source: SchedulesDataSource(
                          _filteredSchedules, _editSchedule, _deleteSchedule),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixView() {
    final schedulesByDate = _schedulesByDate;
    final timeSlots = _timeSlots;
    final dates = schedulesByDate.keys.toList()..sort();

    if (schedulesByDate.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.grid_view, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No schedules to display in matrix view.',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
            columns: [
              const DataColumn(label: Text('Time')),
              ...dates.map(
                (date) => DataColumn(
                  label: Text(
                    date,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            rows: timeSlots.map((timeSlot) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      timeSlot,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  ...dates.map((date) {
                    final daySchedules = schedulesByDate[date] ?? [];

                    final schedule = daySchedules.firstWhere(
                      (s) =>
                          _formatTimeSlot(s['startTime'] as String?) ==
                          timeSlot,
                      orElse: () => <String, dynamic>{},
                    );

                    if (schedule.isEmpty) {
                      return const DataCell(Text('-'));
                    }

                    final isOccupied = schedule['isOccupied'] as bool? ?? false;

                    return DataCell(
                      InkWell(
                        onTap: () => _editSchedule(schedule),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isOccupied
                                ? Colors.red.shade100
                                : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isOccupied
                                  ? Colors.red.shade300
                                  : Colors.green.shade300,
                            ),
                          ),
                          child: Text(
                            isOccupied ? 'Occupied' : 'Available',
                            style: TextStyle(
                              color: isOccupied
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
