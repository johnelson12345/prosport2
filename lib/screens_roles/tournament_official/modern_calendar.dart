// lib/widgets/modern_calendar_picker.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ModernCalendarPicker extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Function(DateTime) onDateSelected;

  const ModernCalendarPicker({
    Key? key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<ModernCalendarPicker> createState() => _ModernCalendarPickerState();
}

class _ModernCalendarPickerState extends State<ModernCalendarPicker> {
  late DateTime _selectedDate;
  late DateTime _focusedDate;
  late List<DateTime> _currentMonthDays;

  final List<String> _weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // Quick date options
  final List<Map<String, dynamic>> _quickDates = [
    {'label': 'Today', 'days': 0},
    {'label': 'Tomorrow', 'days': 1},
    {'label': 'Next Week', 'days': 7},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _focusedDate = widget.initialDate;
    _generateMonthDays();
  }

  void _generateMonthDays() {
    _currentMonthDays = [];
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth =
        DateTime(_focusedDate.year, _focusedDate.month + 1, 0);

    // Add previous month days to fill the first week
    int firstWeekday = firstDayOfMonth.weekday - 1; // 0 = Monday
    if (firstWeekday == -1) firstWeekday = 6; // Sunday

    for (int i = firstWeekday; i > 0; i--) {
      _currentMonthDays.add(firstDayOfMonth.subtract(Duration(days: i)));
    }

    // Add current month days
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      _currentMonthDays.add(DateTime(_focusedDate.year, _focusedDate.month, i));
    }

    // Add next month days to complete the grid (42 days total for 6 rows)
    int remainingDays = 42 - _currentMonthDays.length;
    for (int i = 1; i <= remainingDays; i++) {
      _currentMonthDays.add(lastDayOfMonth.add(Duration(days: i)));
    }
  }

  void _changeMonth(int increment) {
    setState(() {
      _focusedDate =
          DateTime(_focusedDate.year, _focusedDate.month + increment, 1);
      _generateMonthDays();
    });
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isInCurrentMonth(DateTime date) {
    return date.month == _focusedDate.month;
  }

  bool _isSelectable(DateTime date) {
    return !date.isBefore(widget.firstDate) && !date.isAfter(widget.lastDate);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header with month and year
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              DateFormat('MMMM yyyy').format(_focusedDate),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3748),
              ),
            ),
            Row(
              children: [
                _buildNavButton(
                  icon: Icons.chevron_left,
                  onTap: () => _changeMonth(-1),
                ),
                const SizedBox(width: 8),
                _buildNavButton(
                  icon: Icons.chevron_right,
                  onTap: () => _changeMonth(1),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Quick date selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:
              _quickDates.map((quick) => _buildQuickDateButton(quick)).toList(),
        ),

        const SizedBox(height: 24),

        // Week days header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _weekDays
              .map(
                (day) => Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              )
              .toList(),
        ),

        const SizedBox(height: 8),

        // Calendar grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: _currentMonthDays.length,
          itemBuilder: (context, index) {
            final date = _currentMonthDays[index];
            final isSelected = _isSameDay(date, _selectedDate);
            final isCurrentMonth = _isInCurrentMonth(date);
            final isToday = _isToday(date);
            final isSelectable = _isSelectable(date);

            return InkWell(
              onTap: isSelectable ? () => _selectDate(date) : null,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.deepOrange
                      : (isToday && isCurrentMonth
                          ? Colors.deepOrange.withOpacity(0.1)
                          : null),
                  border: isToday && !isSelected && isCurrentMonth
                      ? Border.all(color: Colors.deepOrange, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : (isCurrentMonth
                              ? (isSelectable
                                  ? const Color(0xFF2D3748)
                                  : Colors.grey.shade400)
                              : Colors.grey.shade300),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Footer with today button and confirm
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _focusedDate = DateTime.now();
                  _selectedDate = DateTime.now();
                  _generateMonthDays();
                });
              },
              icon: const Icon(Icons.today, size: 18),
              label: const Text('Today'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.deepOrange,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => widget.onDateSelected(_selectedDate),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text('Select'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNavButton(
      {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildQuickDateButton(Map<String, dynamic> quick) {
    final days = quick['days'] as int;
    final date = DateTime.now().add(Duration(days: days));
    final isSelected = _isSameDay(date, _selectedDate);

    return InkWell(
      onTap: () => _selectDate(date),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepOrange.withOpacity(0.1)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepOrange : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Text(
              quick['label'],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.deepOrange : Colors.grey.shade700,
              ),
            ),
            Text(
              DateFormat('d MMM').format(date),
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.deepOrange : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      if (date.month != _focusedDate.month) {
        _focusedDate = date;
        _generateMonthDays();
      }
    });
  }
}
