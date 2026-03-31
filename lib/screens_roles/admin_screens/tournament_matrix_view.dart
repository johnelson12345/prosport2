import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/sports_list.dart';
import 'package:tabulation_systemv7/services/schedule_announcement_service.dart';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/tournament_calendar_printing.dart';

class _MatchDetailPopup extends StatelessWidget {
  final Map<String, dynamic> event;
  final Color sportColor;
  final String matchText;
  final String timeDisplay;
  final String venue;
  final int matchNumber;
  final int? round;
  final String tournamentName;
  final String categoryName;
  final String gender;
  final VoidCallback onEdit;
  final Offset position;
  final VoidCallback onClose;

  const _MatchDetailPopup({
    required this.event,
    required this.sportColor,
    required this.matchText,
    required this.timeDisplay,
    required this.venue,
    required this.matchNumber,
    required this.round,
    required this.tournamentName,
    required this.categoryName,
    required this.gender,
    required this.onEdit,
    required this.position,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen size to ensure popup stays within bounds
    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 320.0;
    const popupHeight = 380.0; // Approximate height of the popup
    
    // Calculate centered position
    double left = position.dx - (popupWidth / 2);
    double top = position.dy - (popupHeight / 2);
    
    // Adjust if popup would go off screen
    if (left < 10) {
      left = 10;
    } else if (left + popupWidth > screenSize.width - 10) {
      left = screenSize.width - popupWidth - 10;
    }
    
    if (top < 10) {
      top = 10;
    } else if (top + popupHeight > screenSize.height - 10) {
      top = screenSize.height - popupHeight - 10;
    }
    
    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: onClose,
          child: TweenAnimationBuilder(
            duration: const Duration(milliseconds: 200),
            tween: Tween<double>(begin: 0, end: 1),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.8 + (value * 0.2),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    width: popupWidth,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          sportColor,
                          sportColor.withOpacity(0.9),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: sportColor.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    tournamentName.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: onClose,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Content
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Match title
                                Text(
                                  matchText,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Time
                                _buildDetailRow(
                                  Icons.access_time,
                                  timeDisplay,
                                ),
                                const SizedBox(height: 12),
                                // Venue
                                _buildDetailRow(
                                  Icons.location_on,
                                  venue == 'TBD' ? 'Venue: To be determined' : venue,
                                ),
                                const SizedBox(height: 12),
                                // Round/Match number
                                _buildDetailRow(
                                  round != null && round! > 1 ? Icons.flag : Icons.sports,
                                  round != null && round! > 1 ? 'Round $round' : 'Match #$matchNumber',
                                ),
                                if (gender.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildDetailRow(Icons.people, gender),
                                ],
                                if (categoryName.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _buildDetailRow(Icons.category, categoryName),
                                ],
                                const SizedBox(height: 20),
                                // Edit Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      onClose();
                                      onEdit();
                                    },
                                    icon: const Icon(Icons.edit, size: 18),
                                    label: const Text(
                                      'Reschedule Match',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: sportColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
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
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white70),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}

class SchedulesAdmin extends StatefulWidget {
  final String? tournamentId;
  final bool isEditable;

  const SchedulesAdmin({
    super.key,
    this.tournamentId,
    this.isEditable = true,
  });

  @override
  _TournamentCalendarScreenState createState() =>
      _TournamentCalendarScreenState();
}

class _TournamentCalendarScreenState extends State<SchedulesAdmin>
    with SingleTickerProviderStateMixin {
  final TeamScheduleService _service = TeamScheduleService();
  final SportsService _sportsService = SportsService();
  final ScheduleAnnouncementService _announcementService =
      ScheduleAnnouncementService();
  final DateFormat _timeFormat = DateFormat('hh:mm a');
  final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy');

  DateTime _selectedDate = DateTime.now();
  final Set<String> _editingEvents = {};
  final Map<String, DateTime?> _dateCache = {};
  bool _isPrinting = false;
  String _searchQuery = '';
  String _selectedVenue = 'All Venues';
  Set<String> _selectedSports = {};
  Set<String> _selectedSportsFilter = {};
  Set<String> _selectedSportsColumns = {};
  List<String> _availableSports = [];
  bool _showAllDates = false;
  String _selectedView = 'grid';

  // Cache for team names
  final Map<String, String> _teamNameCache = {};
  Set<String> _availableVenues = {};
  List<Map<String, dynamic>>? _cachedSchedules;
  List<String>? _cachedSports;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Cache for precomputed data to avoid recalculation
  final Map<String, Color> _sportColorsCache = {};
  final Map<String, String> _matchTextCache = {};
  final Map<String, String> _formattedTimeCache = {};
  final Map<String, String> _durationTextCache = {};
  final Map<String, bool> _hasActualTeamsCache = {};
  final Map<String, Map<String, dynamic>> _eventMetadataCache = {};

  // Hover states for enhanced UI
  int _hoveredColumn = -1;
  int _hoveredRow = -1;
  
  // Track active popup
  OverlayEntry? _activePopup;
  String? _activePopupEventId;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    _clearCaches();
    _hidePopup();
    super.dispose();
  }

  void _hidePopup() {
    _activePopup?.remove();
    _activePopup = null;
    _activePopupEventId = null;
  }

  void _clearCaches() {
    _sportColorsCache.clear();
    _matchTextCache.clear();
    _formattedTimeCache.clear();
    _durationTextCache.clear();
    _hasActualTeamsCache.clear();
    _eventMetadataCache.clear();
  }

  DateTime? _parseDateTime(String dateTimeStr) {
    if (_dateCache.containsKey(dateTimeStr)) {
      return _dateCache[dateTimeStr]!;
    }

    DateTime? dateTime = DateTime.tryParse(dateTimeStr);
    if (dateTime == null) {
      try {
        final parts = dateTimeStr.split(' ');
        if (parts.length == 2) {
          final dateParts = parts[0].split('/');
          final timeParts = parts[1].split(':');
          if (dateParts.length == 3 && timeParts.length == 2) {
            dateTime = DateTime(
              int.parse(dateParts[2]),
              int.parse(dateParts[1]),
              int.parse(dateParts[0]),
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
            );
          }
        }
      } catch (e) {}
    }

    _dateCache[dateTimeStr] = dateTime;
    return dateTime;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _navigateDate(int days) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: days));
    });
  }

  Color _getSportColor(String sport) {
    if (_sportColorsCache.containsKey(sport)) {
      return _sportColorsCache[sport]!;
    }
    
    final colors = {
      'sipak': Colors.blue,
      'volleyball': Colors.green,
      'basketball': Colors.orange,
      'badminton': Colors.purple,
      'tennis': Colors.teal,
      'table tennis': Colors.pink,
      'swimming': Colors.cyan,
      'athletics': Colors.amber,
      'sepak takraw': Colors.blue,
      'innings': Colors.indigo,
    };
    final color = colors[sport.toLowerCase()] ?? Colors.blue;
    _sportColorsCache[sport] = color;
    return color;
  }

  String _cleanTeamName(String name) {
    if (name.isEmpty) return '';
    name = name.replaceAll(RegExp(r'\s*\(Seed \d+\)\s*'), '');
    name = name.replaceAll(RegExp(r'\s*Seed \d+\s*'), '');
    name = name.replaceAll(RegExp(r'\(Seed \d+\)'), '');
    name = name.replaceAll(RegExp(r'Seed \d+'), '');
    name = name.trim();
    return name;
  }

  String _getPlaceholderText(Map<String, dynamic> team) {
    int? sourceMatchNum;
    if (team['sourceMatch'] != null) {
      sourceMatchNum = team['sourceMatch'] is int 
          ? team['sourceMatch'] 
          : int.tryParse(team['sourceMatch'].toString());
    } else if (team['sourceMatchNumber'] != null) {
      sourceMatchNum = team['sourceMatchNumber'] is int
          ? team['sourceMatchNumber']
          : int.tryParse(team['sourceMatchNumber'].toString());
    }
    
    bool isWinner = team['name']?.toString().contains('Winner') ?? 
                    team['displayName']?.toString().contains('Winner') ?? 
                    team['type'] == 'winner' ?? true;
    
    if (sourceMatchNum != null) {
      if (isWinner) {
        return 'Winner of Match $sourceMatchNum';
      } else {
        return 'Loser of Match $sourceMatchNum';
      }
    }
    
    String displayName = team['displayName'] ?? team['name'] ?? '';
    if (displayName.isNotEmpty) {
      return _cleanTeamName(displayName);
    }
    
    return 'TBD';
  }

  String _buildMatchVersusText(Map<String, dynamic> event) {
    final eventId = event['id'] as String? ?? '';
    
    if (_matchTextCache.containsKey(eventId)) {
      return _matchTextCache[eventId]!;
    }
    
    final matchNumber = event['matchNumber'] as int? ?? 1;
    
    Map<String, dynamic>? team1Obj;
    Map<String, dynamic>? team2Obj;
    
    if (event['team1'] is Map<String, dynamic>) {
      team1Obj = event['team1'] as Map<String, dynamic>;
    }
    if (event['team2'] is Map<String, dynamic>) {
      team2Obj = event['team2'] as Map<String, dynamic>;
    }
    
    String team1Display = '';
    String team2Display = '';
    
    // Extract team1 display text
    if (team1Obj != null) {
      if (team1Obj['isPlaceholder'] == true || team1Obj['type'] == 'placeholder') {
        team1Display = _getPlaceholderText(team1Obj);
      } else {
        if (team1Obj['displayName'] != null && team1Obj['displayName'].toString().isNotEmpty) {
          team1Display = _cleanTeamName(team1Obj['displayName'].toString());
        } else if (team1Obj['name'] != null && team1Obj['name'].toString().isNotEmpty) {
          team1Display = _cleanTeamName(team1Obj['name'].toString());
        } else if (event['team1Name'] != null && event['team1Name'].toString().isNotEmpty) {
          team1Display = _cleanTeamName(event['team1Name'].toString());
        } else if (event['team1DisplayName'] != null && event['team1DisplayName'].toString().isNotEmpty) {
          team1Display = _cleanTeamName(event['team1DisplayName'].toString());
        }
      }
    } else {
      if (event['team1Name'] != null && event['team1Name'].toString().isNotEmpty) {
        team1Display = _cleanTeamName(event['team1Name'].toString());
      } else if (event['team1DisplayName'] != null && event['team1DisplayName'].toString().isNotEmpty) {
        team1Display = _cleanTeamName(event['team1DisplayName'].toString());
      }
    }
    
    // Extract team2 display text
    if (team2Obj != null) {
      if (team2Obj['isPlaceholder'] == true || team2Obj['type'] == 'placeholder') {
        team2Display = _getPlaceholderText(team2Obj);
      } else {
        if (team2Obj['displayName'] != null && team2Obj['displayName'].toString().isNotEmpty) {
          team2Display = _cleanTeamName(team2Obj['displayName'].toString());
        } else if (team2Obj['name'] != null && team2Obj['name'].toString().isNotEmpty) {
          team2Display = _cleanTeamName(team2Obj['name'].toString());
        } else if (event['team2Name'] != null && event['team2Name'].toString().isNotEmpty) {
          team2Display = _cleanTeamName(event['team2Name'].toString());
        } else if (event['team2DisplayName'] != null && event['team2DisplayName'].toString().isNotEmpty) {
          team2Display = _cleanTeamName(event['team2DisplayName'].toString());
        }
      }
    } else {
      if (event['team2Name'] != null && event['team2Name'].toString().isNotEmpty) {
        team2Display = _cleanTeamName(event['team2Name'].toString());
      } else if (event['team2DisplayName'] != null && event['team2DisplayName'].toString().isNotEmpty) {
        team2Display = _cleanTeamName(event['team2DisplayName'].toString());
      }
    }
    
    String result;
    
    // If we have actual team names (not placeholders), show them
    if (!team1Display.contains('Winner') && !team1Display.contains('Loser') &&
        !team2Display.contains('Winner') && !team2Display.contains('Loser') &&
        team1Display.isNotEmpty && team2Display.isNotEmpty) {
      result = 'Match $matchNumber: $team1Display vs $team2Display';
    } else {
      // Try to get actual team names from scores
      final scores = event['scores'] as Map<String, dynamic>?;
      if (scores != null && scores.isNotEmpty) {
        final scoreKeys = scores.keys.toList();
        if (scoreKeys.length >= 2) {
          String scoreTeam1 = _cleanTeamName(scoreKeys[0].toString());
          String scoreTeam2 = _cleanTeamName(scoreKeys[1].toString());
          
          if (!scoreTeam1.contains('Winner') && !scoreTeam1.contains('Loser') &&
              !scoreTeam2.contains('Winner') && !scoreTeam2.contains('Loser') &&
              scoreTeam1.isNotEmpty && scoreTeam2.isNotEmpty) {
            result = 'Match $matchNumber: $scoreTeam1 vs $scoreTeam2';
          } else if (team1Display.isNotEmpty && team2Display.isNotEmpty) {
            result = 'Match $matchNumber: $team1Display vs $team2Display';
          } else if (team1Display.isNotEmpty) {
            result = 'Match $matchNumber: $team1Display vs TBD';
          } else if (team2Display.isNotEmpty) {
            result = 'Match $matchNumber: TBD vs $team2Display';
          } else {
            result = 'Match $matchNumber';
          }
        } else {
          result = 'Match $matchNumber';
        }
      } else if (event['team1Name'] != null && event['team2Name'] != null) {
        String directTeam1 = _cleanTeamName(event['team1Name'].toString());
        String directTeam2 = _cleanTeamName(event['team2Name'].toString());
        
        if (!directTeam1.contains('Winner') && !directTeam1.contains('Loser') &&
            !directTeam2.contains('Winner') && !directTeam2.contains('Loser') &&
            directTeam1.isNotEmpty && directTeam2.isNotEmpty) {
          result = 'Match $matchNumber: $directTeam1 vs $directTeam2';
        } else if (team1Display.isNotEmpty && team2Display.isNotEmpty) {
          result = 'Match $matchNumber: $team1Display vs $team2Display';
        } else if (team1Display.isNotEmpty) {
          result = 'Match $matchNumber: $team1Display vs TBD';
        } else if (team2Display.isNotEmpty) {
          result = 'Match $matchNumber: TBD vs $team2Display';
        } else {
          result = 'Match $matchNumber';
        }
      } else if (team1Display.isNotEmpty && team2Display.isNotEmpty) {
        result = 'Match $matchNumber: $team1Display vs $team2Display';
      } else if (team1Display.isNotEmpty) {
        result = 'Match $matchNumber: $team1Display vs TBD';
      } else if (team2Display.isNotEmpty) {
        result = 'Match $matchNumber: TBD vs $team2Display';
      } else {
        result = 'Match $matchNumber';
      }
    }
    
    _matchTextCache[eventId] = result;
    return result;
  }

  String _formatDuration(Duration duration) {
    final key = duration.toString();
    if (_durationTextCache.containsKey(key)) {
      return _durationTextCache[key]!;
    }
    
    String result;
    if (duration.inHours > 0) {
      result = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      result = '${duration.inMinutes}m';
    }
    
    _durationTextCache[key] = result;
    return result;
  }

  String _formatTime(DateTime time) {
    final key = time.millisecondsSinceEpoch.toString();
    if (_formattedTimeCache.containsKey(key)) {
      return _formattedTimeCache[key]!;
    }
    final formatted = _timeFormat.format(time);
    _formattedTimeCache[key] = formatted;
    return formatted;
  }

  Map<String, dynamic> _getEventMetadata(Map<String, dynamic> event) {
    final eventId = event['id'] as String? ?? '';
    
    if (_eventMetadataCache.containsKey(eventId)) {
      return _eventMetadataCache[eventId]!;
    }
    
    final startTimeStr = event['dateTime'] as String? ?? '';
    final endTimeStr = event['endTime'] as String? ?? '';
    final startTime = _parseDateTime(startTimeStr);
    final endTime = _parseDateTime(endTimeStr);
    
    Duration? duration;
    String durationText = '';
    if (startTime != null && endTime != null) {
      duration = endTime.difference(startTime);
      durationText = _formatDuration(duration);
    }
    
    final matchText = _buildMatchVersusText(event);
    final hasActualTeams = !matchText.contains('Winner') && 
                           !matchText.contains('Loser') && 
                           !matchText.contains('TBD');
    
    final metadata = {
      'startTime': startTime,
      'endTime': endTime,
      'duration': duration,
      'durationText': durationText,
      'matchText': matchText,
      'hasActualTeams': hasActualTeams,
    };
    
    _eventMetadataCache[eventId] = metadata;
    return metadata;
  }

 Widget _buildOptimizedGridEventCard(
  Map<String, dynamic> event,
  Color sportColor,
  List<Map<String, dynamic>> allSchedules,
) {
  final metadata = _getEventMetadata(event);
  final matchText = metadata['matchText'];
  final startTime = metadata['startTime'];
  final endTime = metadata['endTime'];
  final venue = event['venue'] as String? ?? 'TBD';
  final matchNumber = event['matchNumber'] as int? ?? 1;
  final round = event['round'] as int?;
  final tournamentName = event['tournamentName'] as String? ?? 'Tournament';
  final categoryName = event['categoryName'] as String? ?? 'Category';
  final gender = event['gender'] as String? ?? '';
  final durationText = metadata['durationText'];
  final sportName = event['sportName'] as String? ?? event['sport'] as String? ?? 'Sport';
  final timeDisplay = startTime != null && endTime != null
      ? '${_formatTime(startTime)} - ${_formatTime(endTime)}'
      : 'Time TBD';
  final eventId = event['id'] as String? ?? '';

  Timer? _hoverTimer;

  // Declare functions first
  void _hidePopup() {
    _activePopup?.remove();
    _activePopup = null;
    _activePopupEventId = null;
  }

  void _showPopup(BuildContext context, Offset position) {
    if (_activePopupEventId == eventId) return;
    
    _hidePopup();
    
    _activePopup = OverlayEntry(
      builder: (context) => _MatchDetailPopup(
        event: event,
        sportColor: sportColor,
        matchText: matchText,
        timeDisplay: timeDisplay,
        venue: venue,
        matchNumber: matchNumber,
        round: round,
        tournamentName: tournamentName,
        categoryName: categoryName,
        gender: gender,
        onEdit: () {
          _hidePopup();
          _editMatchDateTime(context, event, allSchedules);
        },
        onClose: _hidePopup,
        position: position,
      ),
    );
    
    _activePopupEventId = eventId;
    Overlay.of(context).insert(_activePopup!);
  }

  void _startHoverTimer(BuildContext context, Offset position) {
    _hoverTimer?.cancel();
    _hoverTimer = Timer(const Duration(milliseconds: 300), () {
      _showPopup(context, position);
    });
  }

  void _cancelHoverTimer() {
    _hoverTimer?.cancel();
    _hidePopup();
  }

  return MouseRegion(
    onEnter: (PointerEvent details) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final Offset position = renderBox.localToGlobal(Offset.zero);
      _startHoverTimer(context, position);
    },
    onExit: (_) {
      _cancelHoverTimer();
      _hidePopup();
    },
    child: RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: _activePopupEventId == eventId
            ? Matrix4.diagonal3Values(1.02, 1.02, 1)
            : Matrix4.identity(),
        child: Material(
          elevation: _activePopupEventId == eventId ? 8 : 2,
          shadowColor: sportColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.isEditable 
                ? () => _editMatchDateTime(context, event, allSchedules)
                : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 85, maxHeight: 95),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    sportColor.withOpacity(0.05),
                    Colors.white,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: sportColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with tournament name and edit button
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 28,
                            decoration: BoxDecoration(
                              color: sportColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  tournamentName,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: sportColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Flexible(
                                  child: Row(
                                    children: [
                                      if (round != null && matchNumber != null)
                                        Expanded(
                                          child: Text(
                                            'R$round • M$matchNumber',
                                            style: TextStyle(
                                              fontSize: 7,
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      const SizedBox(width: 4),
                                      if (startTime != null && endTime != null)
                                        Flexible(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sportColor.withValues(alpha:0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _formatTime(startTime),
                                              style: TextStyle(
                                                fontSize: 7,
                                                color: sportColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Edit button - Always visible
                          if (widget.isEditable)
                            Container(
                              decoration: BoxDecoration(
                                color: sportColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.edit_calendar,
                                  size: 14,
                                  color: sportColor,
                                ),
                                onPressed: () =>
                                    _editMatchDateTime(context, event, allSchedules),
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Match text with proper truncation
                      Flexible(
                        child: Text(
                          matchText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Meta chips row
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: [
                          _buildCompactMetaChip(
                            Icons.sports,
                            sportName,
                            sportColor,
                          ),
                          if (durationText.isNotEmpty)
                            _buildCompactMetaChip(
                              Icons.timer,
                              durationText,
                              Colors.orange,
                            ),
                          if (venue.isNotEmpty && venue != 'TBD')
                            _buildCompactMetaChip(
                              Icons.location_on,
                              venue.length > 10 ? '${venue.substring(0, 8)}...' : venue,
                              Colors.grey,
                            ),
                          if (gender.isNotEmpty)
                            _buildCompactMetaChip(
                              gender == 'Men' ? Icons.male : Icons.female,
                              gender,
                              gender == 'Men' ? Colors.blue : Colors.pink,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildCompactMetaChip(IconData icon, String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    constraints: const BoxConstraints(maxWidth: 100, maxHeight: 14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 6, color: color),
        const SizedBox(width: 2),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 6.5,
                fontWeight: FontWeight.w500,
                color: color,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ),
  );
}

 
  Widget _buildOptimizedInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 6, color: color),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 6,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewOption(Icons.grid_view, 'grid', 'Grid View'),
          _buildViewOption(Icons.view_list, 'list', 'List View'),
          _buildViewOption(Icons.timeline, 'timeline', 'Timeline View'),
        ],
      ),
    );
  }

  Widget _buildViewOption(IconData icon, String view, String tooltip) {
    final isSelected = _selectedView == view;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedView = view;
            });
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(List<String> sports) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search teams, venues...',
                  border: InputBorder.none,
                  prefixIcon:
                      Icon(Icons.search, size: 18, color: Colors.grey[600]),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.view_column, size: 18),
              onPressed: () => _showColumnSelectorDialog(sports),
              tooltip: 'Select Columns',
              color: Colors.blue,
              padding: const EdgeInsets.all(8),
            ),
          ),
          if (_selectedSports.isNotEmpty ||
              _selectedVenue != 'All Venues' ||
              _searchQuery.isNotEmpty ||
              _selectedSportsFilter.isNotEmpty)
            Container(
              height: 40,
              margin: const EdgeInsets.only(left: 4),
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _selectedSports.clear();
                    _selectedVenue = 'All Venues';
                    _searchQuery = '';
                    _selectedSportsFilter.clear();
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  backgroundColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Clear'),
              ),
            ),
        ],
      ),
    );
  }

  void _showColumnSelectorDialog(List<String> sports) async {
    final localSelectedColumns = Set<String>.from(
      _selectedSportsColumns.isEmpty ? sports.toSet() : _selectedSportsColumns,
    );

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade400],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.view_column,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Columns',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              localSelectedColumns.clear();
                              localSelectedColumns.addAll(sports);
                            });
                          },
                          icon: const Icon(Icons.select_all),
                          label: const Text('Select All'),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setDialogState(() {
                              localSelectedColumns.clear();
                            });
                          },
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const Divider(),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: sports.length,
                        itemBuilder: (context, index) {
                          final sport = sports[index];
                          final isSelected = localSelectedColumns.contains(sport);
                          final sportColor = _getSportColor(sport);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: CheckboxListTile(
                              title: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          sportColor,
                                          sportColor.withValues(alpha: 0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.sports,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    sport,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              value: isSelected,
                              onChanged: (value) {
                                setDialogState(() {
                                  if (value == true) {
                                    localSelectedColumns.add(sport);
                                  } else {
                                    localSelectedColumns.remove(sport);
                                  }
                                });
                              },
                              activeColor: Colors.blue,
                              checkboxShape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          );
                        },
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
                  onPressed: () {
                    Navigator.pop(context, localSelectedColumns);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _selectedSportsColumns = result;
      });
    }
  }

  Widget _buildEnhancedGridView(List<Map<String, dynamic>> schedules, List<String> sports) {
    final sportsWithMatches = <String>{};
    
    final calendarMap = <String, Map<String, List<Map<String, dynamic>>>>{};
    final eventSpanMap = <String, Map<String, Map<String, dynamic>>>{};

    // Precompute calendar data
    for (final schedule in schedules) {
      final dateTimeStr = schedule['dateTime'] as String? ?? '';
      final endTimeStr = schedule['endTime'] as String? ?? '';
      final startTime = _parseDateTime(dateTimeStr);
      final endTime = _parseDateTime(endTimeStr);

      if (startTime != null) {
        final sportKey = schedule['sport'] as String? ??
            schedule['sportName'] as String? ??
            'Unknown Sport';

        sportsWithMatches.add(sportKey);

        final hour = startTime.hour;
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        final timeKey = '$hour12:00 $period';

        calendarMap.putIfAbsent(timeKey, () => {});
        calendarMap[timeKey]!.putIfAbsent(sportKey, () => []);
        calendarMap[timeKey]![sportKey]!.add(schedule);

        if (endTime != null) {
          int spanHours = endTime.difference(startTime).inHours;
          if (spanHours < 1) spanHours = 1;
          if (spanHours > 5) spanHours = 5;

          eventSpanMap.putIfAbsent(timeKey, () => {});
          eventSpanMap[timeKey]!.putIfAbsent(sportKey, () => {});
          eventSpanMap[timeKey]![sportKey]![schedule['id']] = {
            'span': spanHours,
            'event': schedule,
            'startHour': hour,
            'endHour': endTime.hour,
          };
        }
      }
    }

    final visibleSports = _selectedSportsColumns.isEmpty
        ? sports.where((sport) => sportsWithMatches.contains(sport)).toList()
        : sports
            .where((sport) =>
                _selectedSportsColumns.contains(sport) &&
                sportsWithMatches.contains(sport))
            .toList();

    visibleSports.sort();

    if (visibleSports.isEmpty) {
      return _buildEmptyGridViewState(sports);
    }

    final timeSlots = List.generate(17, (index) {
      final hour = 6 + index;
      return DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        hour,
      );
    }).map((dt) {
      final hour = dt.hour;
      final period = hour >= 12 ? 'PM' : 'AM';
      final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$hour12:00 $period';
    }).toList();

    const double rowHeight = 95;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            _buildOptimizedHeaderSection(visibleSports, sportsWithMatches),
            Expanded(
              child: _buildOptimizedTimeGrid(
                timeSlots,
                rowHeight,
                visibleSports,
                calendarMap,
                eventSpanMap,
                schedules,
              ),
            ),
            _buildOptimizedFooterSection(visibleSports),
          ],
        ),
      ),
    );
  }

  Widget _buildOptimizedHeaderSection(List<String> visibleSports, Set<String> sportsWithMatches) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromARGB(255, 0, 20, 47),
            Color(0xFF0B5EC9),
          ],
        ),
      ),
      child: Row(
        children: [
          _buildOptimizedTimeHeader(),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              itemCount: visibleSports.length,
              itemBuilder: (context, index) {
                final sport = visibleSports[index];
                final matchCount = _cachedSchedules?.where((s) {
                  final sportName = s['sport'] as String? ??
                      s['sportName'] as String? ??
                      '';
                  return sportName == sport;
                }).length ?? 0;

                return RepaintBoundary(
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          sport.toUpperCase(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$matchCount',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildOptimizedColumnSelectorButton(),
        ],
      ),
    );
  }

  Widget _buildOptimizedTimeHeader() {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'TIME',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _displayDateFormat.format(_selectedDate),
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedTimeGrid(
    List<String> timeSlots,
    double rowHeight,
    List<String> visibleSports,
    Map<String, Map<String, List<Map<String, dynamic>>>> calendarMap,
    Map<String, Map<String, Map<String, dynamic>>> eventSpanMap,
    List<Map<String, dynamic>> schedules,
  ) {
    return ListView.builder(
      controller: _verticalScrollController,
      itemCount: timeSlots.length,
      itemBuilder: (context, rowIndex) {
        final timeSlot = timeSlots[rowIndex];
        final isEvenRow = rowIndex % 2 == 0;

        return RepaintBoundary(
          child: Container(
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              color: isEvenRow
                  ? Colors.grey.withValues(alpha: 0.02)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                _buildOptimizedTimeSlotCell(timeSlot, isEvenRow),
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    controller: _horizontalScrollController,
                    itemCount: visibleSports.length,
                    itemBuilder: (context, colIndex) {
                      final sport = visibleSports[colIndex];
                      final sportColor = _getSportColor(sport);
                      final startingEvents = calendarMap[timeSlot]?[sport] ?? [];
                      final isCovered = _isCellCoveredBySpanningEvent(
                        rowIndex,
                        timeSlots,
                        sport,
                        calendarMap,
                        eventSpanMap,
                      );

                      return RepaintBoundary(
                        child: Container(
                          width: 240,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.grey.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            color: isCovered
                                ? sportColor.withValues(alpha:0.01)
                                : null,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (startingEvents.isEmpty && !isCovered)
                                _buildOptimizedEmptyCell(sportColor),
                              ...startingEvents.asMap().entries.map((entry) {
                                final eventIndex = entry.key;
                                final event = entry.value;
                                final spanInfo = eventSpanMap[timeSlot]?[sport]?[event['id']];
                                final span = spanInfo?['span'] ?? 1;

                                final double topOffset = eventIndex * 10.0;
                                final double leftOffset = eventIndex * 6.0;
                                final double rightOffset = eventIndex * 6.0;

                                return Positioned(
                                  top: topOffset + 4,
                                  left: leftOffset + 4,
                                  right: rightOffset + 4,
                                  height: (rowHeight * span) - 16 - topOffset,
                                  child: _buildOptimizedGridEventCard(
                                    event,
                                    sportColor,
                                    schedules,
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptimizedTimeSlotCell(String timeSlot, bool isEvenRow) {
    return Container(
      width: 80,
      alignment: Alignment.center,
      child: Text(
        timeSlot,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildOptimizedEmptyCell(Color sportColor) {
    return Center(
      child: Text(
        '—',
        style: TextStyle(
          color: sportColor.withOpacity(0.3),
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildOptimizedFooterSection(List<String> visibleSports) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            alignment: Alignment.center,
            child: Text(
              '${visibleSports.length} sports',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: Row(
                children: visibleSports.map((sport) {
                  final sportColor = _getSportColor(sport);
                  final matchCount = _cachedSchedules?.where((s) {
                    final sportName = s['sport'] as String? ??
                        s['sportName'] as String? ??
                        '';
                    return sportName == sport;
                  }).length ?? 0;

                  return Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: sportColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          sport,
                          style: TextStyle(
                            fontSize: 10,
                            color: sportColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Text(
                          '$matchCount',
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          _buildOptimizedScrollControls(),
        ],
      ),
    );
  }

  Widget _buildOptimizedScrollControls() {
    return Container(
      width: 50,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 16),
            onPressed: () {
              _horizontalScrollController.animateTo(
                _horizontalScrollController.offset - 240,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 16),
            onPressed: () {
              _horizontalScrollController.animateTo(
                _horizontalScrollController.offset + 240,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildOptimizedColumnSelectorButton() {
    return Container(
      width: 40,
      child: IconButton(
        icon: const Icon(Icons.view_column, size: 18),
        onPressed: () => _showColumnSelectorDialog(_availableSports),
        color: Colors.white,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  bool _isCellCoveredBySpanningEvent(
    int currentRowIndex,
    List<String> timeSlots,
    String sport,
    Map<String, Map<String, List<Map<String, dynamic>>>> calendarMap,
    Map<String, Map<String, Map<String, dynamic>>> eventSpanMap,
  ) {
    for (int i = 0; i < currentRowIndex; i++) {
      final prevTimeSlot = timeSlots[i];
      final eventsAtPrevSlot = calendarMap[prevTimeSlot]?[sport] ?? [];

      for (final event in eventsAtPrevSlot) {
        final eventId = event['id'];
        final spanInfo = eventSpanMap[prevTimeSlot]?[sport]?[eventId];
        if (spanInfo != null) {
          final span = spanInfo['span'] as int;
          if (i + span > currentRowIndex) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Widget _buildEmptyGridViewState(List<String> sports) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.sports,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _selectedSportsColumns.isEmpty
                ? 'No matches scheduled for this date'
                : 'No matches for selected sports on this date',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedSportsColumns.isNotEmpty)
            ElevatedButton(
              onPressed: () => _showColumnSelectorDialog(sports),
              child: const Text('Select Different Sports'),
            ),
        ],
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> schedules) {
    final groupedSchedules = <String, List<Map<String, dynamic>>>{};
    for (final schedule in schedules) {
      final dateTimeStr = schedule['dateTime'] as String? ?? '';
      final dateTime = _parseDateTime(dateTimeStr);
      if (dateTime != null) {
        final timeKey = _timeFormat.format(dateTime);
        groupedSchedules.putIfAbsent(timeKey, () => []);
        groupedSchedules[timeKey]!.add(schedule);
      }
    }

    final sortedTimes = groupedSchedules.keys.toList()..sort();

    return ListView.builder(
      itemCount: sortedTimes.length,
      itemBuilder: (context, index) {
        final time = sortedTimes[index];
        final timeSchedules = groupedSchedules[time]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            title: Text(
              '$time • ${timeSchedules.length} match${timeSchedules.length > 1 ? 'es' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            children: timeSchedules.map((schedule) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: _buildModernEventCard(schedule, schedules),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildModernEventCard(
    Map<String, dynamic> event,
    List<Map<String, dynamic>> allSchedules, {
    bool isCompact = false,
  }) {
    final metadata = _getEventMetadata(event);
    final matchText = metadata['matchText'];
    final startTime = metadata['startTime'];
    final endTime = metadata['endTime'];
    final durationText = metadata['durationText'];
    final venue = event['venue'] as String? ?? 'TBD';
    final gender = event['gender'] as String? ?? '';
    final tournamentName = event['tournamentName'] as String? ?? 'Tournament';
    final sportName =
        event['sportName'] as String? ?? event['sport'] as String? ?? 'Sport';
    final categoryName = event['categoryName'] as String? ?? 'Category';
    final matchNumber = event['matchNumber'] as int?;
    final round = event['round'] as int?;
    final sportColor = _getSportColor(sportName);
    final eventId = event['id'] as String? ?? '';

    bool _isExpanded = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) {
            setState(() {
              _isExpanded = true;
            });
          },
          onExit: (_) {
            setState(() {
              _isExpanded = false;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            height: _isExpanded ? 280 : 140,
            margin: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: sportColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.isEditable
                      ? () => _editMatchDateTime(context, event, allSchedules)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          sportColor.withOpacity(0.05),
                          Colors.white,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: sportColor.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: sportColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tournamentName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: sportColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (round != null && matchNumber != null)
                                          Text(
                                            'Round $round • Match #$matchNumber',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        if (startTime != null && endTime != null)
                                          Container(
                                            margin: const EdgeInsets.only(top: 2),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sportColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '${_formatTime(startTime)} - ${_formatTime(endTime)} • $durationText',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: sportColor,
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
                            if (widget.isEditable && _isExpanded)
                              Container(
                                decoration: BoxDecoration(
                                  color: sportColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.edit_calendar,
                                    size: 18,
                                    color: sportColor,
                                  ),
                                  onPressed: () =>
                                      _editMatchDateTime(context, event, allSchedules),
                                  padding: const EdgeInsets.all(6),
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          matchText,
                          style: TextStyle(
                            fontSize: _isExpanded ? 18 : 16,
                            fontWeight: _isExpanded ? FontWeight.w800 : FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildMetaChip(
                              Icons.sports,
                              sportName,
                              sportColor,
                            ),
                            _buildMetaChip(
                              Icons.category,
                              categoryName,
                              Colors.purple,
                            ),
                            if (durationText.isNotEmpty)
                              _buildMetaChip(
                                Icons.timer,
                                durationText,
                                Colors.orange,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      venue,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (gender.isNotEmpty)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: gender == 'Men'
                                        ? Colors.blue.withValues(alpha: 0.1)
                                        : gender == 'Women'
                                            ? Colors.pink.withValues(alpha: 0.1)
                                            : Colors.green.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  gender,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: gender == 'Men'
                                        ? Colors.blue
                                        : gender == 'Women'
                                            ? Colors.pink
                                            : Colors.green,
                                  ),
                                ),
                              ),
                              ),
                          ],
                        ),
                        if (_isExpanded && widget.isEditable)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _editMatchDateTime(context, event, allSchedules),
                                icon: Icon(Icons.edit_calendar, size: 16, color: sportColor),
                                label: const Text(
                                  'Reschedule Match',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: sportColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(List<Map<String, dynamic>> schedules) {
    final sortedSchedules = List<Map<String, dynamic>>.from(schedules);
    sortedSchedules.sort((a, b) {
      final aTime = _parseDateTime(a['dateTime'] as String? ?? '');
      final bTime = _parseDateTime(b['dateTime'] as String? ?? '');
      if (aTime == null || bTime == null) return 0;
      return aTime.compareTo(bTime);
    });

    return ListView.builder(
      itemCount: sortedSchedules.length,
      itemBuilder: (context, index) {
        final schedule = sortedSchedules[index];
        final dateTime = _parseDateTime(schedule['dateTime'] as String? ?? '');

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 80,
                child: Column(
                  children: [
                    if (dateTime != null)
                      Text(
                        _formatTime(dateTime),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    Container(
                      width: 2,
                      height: 50,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildModernEventCard(schedule, schedules),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editMatchDateTime(
    BuildContext context,
    Map<String, dynamic> event,
    List<Map<String, dynamic>> allSchedules,
  ) async {
    final eventId = event['id'] as String;
    setState(() {
      _editingEvents.add(eventId);
    });

    try {
      final sport = event['sport'] as String? ??
          event['sportName'] as String? ??
          'Unknown Sport';

      final currentDateTimeStr = event['dateTime'] as String? ?? '';
      final currentEndTimeStr = event['endTime'] as String? ?? '';
      final currentDateTime = _parseDateTime(currentDateTimeStr);
      final currentEndTime = _parseDateTime(currentEndTimeStr);

      DateTime selectedDate = currentDateTime ?? _selectedDate;
      TimeOfDay selectedStartTime = currentDateTime != null
          ? TimeOfDay(
              hour: currentDateTime.hour, minute: currentDateTime.minute)
          : const TimeOfDay(hour: 8, minute: 0);
      TimeOfDay selectedEndTime = currentEndTime != null
          ? TimeOfDay(hour: currentEndTime.hour, minute: currentEndTime.minute)
          : const TimeOfDay(hour: 9, minute: 0);

      List<String> _getAvailableSlots(DateTime date) {
        final daySchedules = allSchedules.where((s) {
          final dateTimeStr = s['dateTime'] as String? ?? '';
          final dateTime = _parseDateTime(dateTimeStr);
          return dateTime != null &&
              dateTime.year == date.year &&
              dateTime.month == date.month &&
              dateTime.day == date.day;
        }).toList();

        final occupiedSlots = <String>{};
        for (final schedule in daySchedules) {
          if (schedule['id'] != event['id']) {
            final scheduleSport = schedule['sport'] as String? ??
                schedule['sportName'] as String? ??
                'Unknown Sport';
            if (scheduleSport == sport) {
              final dateTimeStr = schedule['dateTime'] as String? ?? '';
              final dateTime = _parseDateTime(dateTimeStr);
              if (dateTime != null) {
                occupiedSlots.add('${dateTime.hour}:00');
              }
            }
          }
        }

        return List.generate(24, (index) => index)
            .where((hour) => !occupiedSlots.contains('$hour:00'))
            .map((hour) => '$hour:00')
            .toList();
      }

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final availableHours = _getAvailableSlots(selectedDate);
              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reschedule Match',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Current Schedule: ${_displayDateFormat.format(currentDateTime ?? _selectedDate)} ${currentDateTime != null ? _timeFormat.format(currentDateTime) : ''}${currentEndTime != null ? ' - ${_timeFormat.format(currentEndTime)}' : ''}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(
                            _displayDateFormat.format(selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedDate = picked;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text(
                            'Start: ${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedStartTime,
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedStartTime = picked;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.access_time_filled),
                          title: Text(
                            'End: ${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              final TimeOfDay? picked = await showTimePicker(
                                context: context,
                                initialTime: selectedEndTime,
                              );
                              if (picked != null) {
                                setState(() {
                                  selectedEndTime = picked;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Change'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (availableHours.isNotEmpty) ...[
                        const Text(
                          'Available Time Slots:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: availableHours.length,
                            itemBuilder: (context, index) {
                              final hour = availableHours[index];
                              return Padding(
                                padding: const EdgeInsets.all(8),
                                child: FilterChip(
                                  label: Text(hour),
                                  selected: selectedStartTime.hour.toString() ==
                                      hour.replaceAll(':00', ''),
                                  onSelected: (selected) {
                                    if (selected) {
                                      final hourInt =
                                          int.parse(hour.replaceAll(':00', ''));
                                      setState(() {
                                        selectedStartTime =
                                            TimeOfDay(hour: hourInt, minute: 0);
                                      });
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No available time slots for $sport on ${_displayDateFormat.format(selectedDate)}',
                                  style: TextStyle(color: Colors.orange[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: availableHours.isNotEmpty
                                ? () {
                                    Navigator.pop(context, {
                                      'date': selectedDate,
                                      'startTime': selectedStartTime,
                                      'endTime': selectedEndTime,
                                    });
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Reschedule'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

      if (result != null) {
        final selectedDate = result['date'] as DateTime;
        final selectedStartTime = result['startTime'] as TimeOfDay;
        final selectedEndTime = result['endTime'] as TimeOfDay;

        final newDateTimeStr =
            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} ${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}';
        final newEndTimeStr =
            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year} ${selectedEndTime.hour.toString().padLeft(2, '0')}:${selectedEndTime.minute.toString().padLeft(2, '0')}';

        await _service.updateTeamSchedule(event['id'], {
          'dateTime': newDateTimeStr,
          'endTime': newEndTimeStr,
        });

        final announcement = {
          'id': '${event['id']}_${DateTime.now().millisecondsSinceEpoch}',
          'tournamentName': event['tournamentName'] ?? 'Unknown Tournament',
          'sportName': event['sportName'] ?? 'Unknown Sport',
          'categoryName': event['categoryName'] ?? 'Unknown Category',
          'teams': event['teams'] ?? [],
          'oldDateTime': currentDateTimeStr,
          'newDateTime': newDateTimeStr,
          'timestamp': FieldValue.serverTimestamp(),
        };

        await _announcementService.createAnnouncement(announcement);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Match rescheduled successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _editingEvents.remove(eventId);
        });
      }
    }
  }

  Future<void> _printCalendar() async {
    setState(() {
      _isPrinting = true;
    });

    try {
      final data = await StreamZip([
        widget.tournamentId != null
            ? _service.getTeamSchedulesByTournament(widget.tournamentId!)
            : _service.getAllTeamSchedules(),
        _sportsService.getSportsStream(),
      ]).first;

      final schedules = data[0] as List<Map<String, dynamic>>;
      final sportsSnapshot = data[1] as QuerySnapshot;

      final scheduleSports = schedules
          .map((s) =>
              s['sport'] as String? ??
              s['sportName'] as String? ??
              'Unknown Sport')
          .toSet();

      final allSports = sportsSnapshot.docs
          .map((doc) => doc['name'] as String? ?? 'Unknown Sport')
          .toSet();

      final sports = (scheduleSports.union(allSports)).toList()..sort();

      final daySchedules = schedules.where((s) {
        final dateTimeStr = s['dateTime'] as String? ?? '';
        final dateTime = _parseDateTime(dateTimeStr);
        return dateTime != null &&
            dateTime.year == _selectedDate.year &&
            dateTime.month == _selectedDate.month &&
            dateTime.day == _selectedDate.day;
      }).toList();

      final timeSlots = List.generate(17, (index) {
        final hour = 6 + index;
        return DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          hour,
        );
      }).map((dt) {
        final hour = dt.hour;
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$hour12:00 $period';
      }).toList();

      final calendarMap = <String, Map<String, List<Map<String, dynamic>>>>{};
      for (final schedule in daySchedules) {
        final dateTimeStr = schedule['dateTime'] as String? ?? '';
        final dateTime = _parseDateTime(dateTimeStr);

        if (dateTime != null) {
          final hour = dateTime.hour;
          final period = hour >= 12 ? 'PM' : 'AM';
          final hour12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
          final timeKey = '$hour12:00 $period';

          final sportKey = schedule['sport'] as String? ??
              schedule['sportName'] as String? ??
              'Unknown Sport';

          calendarMap.putIfAbsent(timeKey, () => {});
          calendarMap[timeKey]!.putIfAbsent(sportKey, () => []);
          calendarMap[timeKey]![sportKey]!.add(schedule);
        }
      }

      await TournamentCalendarPrinting.printCalendar(
        timeSlots,
        sports,
        calendarMap,
        _selectedDate,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Calendar exported successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting calendar: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPrinting = false;
        });
      }
    }
  }

  Future<void> _showCreateAnnouncementDialog() async {
    final TextEditingController _announcementController =
        TextEditingController();
    String selectedType = 'General Update';
    final List<String> announcementTypes = [
      'General Update',
      'Schedule Change',
      'Venue Change',
      'Weather Advisory',
      'Important Notice',
      'Emergency',
    ];

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Announcement'),
              content: Container(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Announcement Type',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: selectedType,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: announcementTypes.map((String type) {
                          return DropdownMenuItem<String>(
                            value: type,
                            child: Row(
                              children: [
                                Icon(
                                  _getAnnouncementIcon(type),
                                  size: 18,
                                  color: _getAnnouncementColor(type),
                                ),
                                const SizedBox(width: 8),
                                Text(type),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setDialogState(() {
                              selectedType = newValue;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Title',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _announcementController,
                      maxLines: 2,
                      maxLength: 200,
                      decoration: InputDecoration(
                        hintText: 'Enter your announcement here...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
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
                  onPressed: () async {
                    if (_announcementController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter an announcement'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final announcement = {
                      'id':
                          'announcement_${DateTime.now().millisecondsSinceEpoch}',
                      'type': selectedType,
                      'message': _announcementController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                      'date': _displayDateFormat.format(DateTime.now()),
                      'time': _timeFormat.format(DateTime.now()),
                      'isRead': false,
                      'priority':
                          selectedType == 'Emergency' ? 'high' : 'normal',
                    };

                    try {
                      await _announcementService
                          .createAnnouncement(announcement);

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                const Text('Announcement created successfully'),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating announcement: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Post Announcement'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getAnnouncementIcon(String type) {
    switch (type) {
      case 'Schedule Change':
        return Icons.update;
      case 'Venue Change':
        return Icons.location_on;
      case 'Weather Advisory':
        return Icons.wb_sunny;
      case 'Important Notice':
        return Icons.priority_high;
      case 'Emergency':
        return Icons.warning;
      default:
        return Icons.campaign;
    }
  }

  Color _getAnnouncementColor(String type) {
    switch (type) {
      case 'Schedule Change':
        return Colors.blue;
      case 'Venue Change':
        return Colors.orange;
      case 'Weather Advisory':
        return Colors.amber;
      case 'Important Notice':
        return Colors.purple;
      case 'Emergency':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  void _showManageAnnouncementsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.campaign, color: Colors.blue[700], size: 28),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Manage Announcements',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'View, edit, and delete announcements',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _announcementService.getLatestAnnouncements(limit: 50),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          children: [
                            Icon(Icons.error, color: Colors.red[400], size: 48),
                            const SizedBox(height: 8),
                            Text('Error loading announcements: ${snapshot.error}'),
                            TextButton(
                              onPressed: () => setState(() {}),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.campaign_outlined, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No announcements yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create your first announcement using the Announce button',
                              style: TextStyle(color: Colors.grey[500]),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    final announcements = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: announcements.length,
                      itemBuilder: (context, index) {
                        final announcement = announcements[index];
                        final timestamp = announcement['timestamp'] as Timestamp?;
                        final timeAgo = timestamp != null 
                            ? _formatTimeAgo(timestamp.toDate()) 
                            : 'Unknown';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: _getAnnouncementColor(announcement['type'] ?? 'General Update'),
                              child: Icon(
                                _getAnnouncementIcon(announcement['type'] ?? 'General Update'),
                                color: Colors.white,
                              ),
                            ),
                            title: Text(
                              announcement['message'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(announcement['type'] ?? 'General Update'),
                                Text(timeAgo, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditAnnouncementDialog(context, announcement);
                                } else if (value == 'delete') {
                                  _showDeleteConfirmationDialog(context, announcement['id']);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text('Edit')])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showEditAnnouncementDialog(BuildContext context, Map<String, dynamic> announcement) {
    final controller = TextEditingController(text: announcement['message'] ?? '');
    final type = announcement['type'] ?? 'General Update';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Announcement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: ['General Update', 'Schedule Change', 'Venue Change', 'Weather Advisory', 'Important Notice', 'Emergency']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: null,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await _announcementService.updateAnnouncement(
                  announcement['id'],
                  {'message': controller.text.trim(), 'type': type},
                );
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement updated')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await _announcementService.deleteAnnouncement(id);
                if (context.mounted) Navigator.pop(context);
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Announcement deleted')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      onPressed: () => _navigateDate(-1),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _displayDateFormat.format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      onPressed: () => _navigateDate(1),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                _buildViewToggle(),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildFilterSection(_availableSports),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Tooltip(
                    message: 'Create Announcement',
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _showCreateAnnouncementDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.campaign,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Announce',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.list_alt, color: Color.fromARGB(255, 5, 33, 57)),
                  onPressed: () => _showManageAnnouncementsBottomSheet(context),
                  tooltip: 'Manage Announcements',
                ),
                if (_isPrinting)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.grey),
                    onPressed: _printCalendar,
                    tooltip: 'Export as PDF',
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: StreamZip([
                widget.tournamentId != null
                    ? _service
                        .getTeamSchedulesByTournament(widget.tournamentId!)
                    : _service.getAllTeamSchedules(),
                _sportsService.getSportsStream(),
              ]),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 48, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!;
                final schedules =
                    (data[0] as List<Map<String, dynamic>>?) ?? [];
                final sportsSnapshot = data[1] as QuerySnapshot;

                _cachedSchedules = schedules;
                
                _availableVenues = schedules
                    .where((s) => s != null)
                    .map((s) => s['venue'] as String? ?? 'TBD')
                    .where((v) => v.isNotEmpty)
                    .toSet();

                final scheduleSports = schedules
                    .where((s) => s != null)
                    .map((s) =>
                        s['sport'] as String? ??
                        s['sportName'] as String? ??
                        'Unknown Sport')
                    .where((sport) => sport != null && sport.isNotEmpty)
                    .toSet();

                final allSports = sportsSnapshot.docs
                    .map((doc) => doc['name'] as String? ?? 'Unknown Sport')
                    .where((sport) => sport != null && sport.isNotEmpty)
                    .toSet();

                final sports = (scheduleSports.union(allSports)).toList()
                  ..sort();

                _availableSports = sports;

                if (_selectedSportsColumns.isEmpty &&
                    sports.isNotEmpty &&
                    mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedSportsColumns = sports.toSet();
                    });
                  });
                }

                final daySchedules = _showAllDates
                    ? schedules.where((s) => s != null).toList()
                    : schedules.where((s) => s != null).where((s) {
                        final dateTimeStr = s['dateTime'] as String? ?? '';
                        final dateTime = _parseDateTime(dateTimeStr);
                        return dateTime != null &&
                            dateTime.year == _selectedDate.year &&
                            dateTime.month == _selectedDate.month &&
                            dateTime.day == _selectedDate.day;
                      }).toList();

                final filteredSchedules = daySchedules.where((schedule) {
                  if (schedule == null) return false;

                  if (_searchQuery.isNotEmpty) {
                    final teams = schedule['teams'] as List<dynamic>? ?? [];
                    final teamMatch = teams.any((team) =>
                        team?.toString().toLowerCase().contains(_searchQuery) ??
                        false);
                    final venueMatch = (schedule['venue'] as String? ?? '')
                        .toLowerCase()
                        .contains(_searchQuery);
                    final sportMatch = (schedule['sportName'] as String? ??
                            schedule['sport'] as String? ??
                            '')
                        .toLowerCase()
                        .contains(_searchQuery);

                    if (!teamMatch && !venueMatch && !sportMatch) {
                      return false;
                    }
                  }

                  if (_selectedVenue != 'All Venues' &&
                      (schedule['venue'] ?? 'TBD') != _selectedVenue) {
                    return false;
                  }

                  if (_selectedSports.isNotEmpty) {
                    final sportName = schedule['sportName'] as String? ??
                        schedule['sport'] as String? ??
                        '';
                    if (!_selectedSports.contains(sportName)) {
                      return false;
                    }
                  }

                  return true;
                }).toList();

                if (sports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sports,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No sports found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredSchedules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_busy,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showAllDates
                              ? 'No matches found with current filters'
                              : 'No matches scheduled for ${_displayDateFormat.format(_selectedDate)}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!_showAllDates)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _showAllDates = true;
                              });
                            },
                            child: const Text('Show all dates'),
                          ),
                      ],
                    ),
                  );
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _selectedView == 'grid'
                        ? _buildEnhancedGridView(filteredSchedules, sports)
                        : _selectedView == 'list'
                            ? _buildListView(filteredSchedules)
                            : _buildTimelineView(filteredSchedules),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MatrixPatternPainter extends CustomPainter {
  final Color baseColor;

  MatrixPatternPainter(this.baseColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    final cellSize = 20.0;
    final rows = (size.height / cellSize).ceil();
    final cols = (size.width / cellSize).ceil();

    for (int i = 0; i <= rows; i++) {
      for (int j = 0; j <= cols; j++) {
        if ((i + j) % 2 == 0) {
          canvas.drawCircle(
            Offset(j * cellSize, i * cellSize),
            1.5,
            paint..style = PaintingStyle.fill,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}