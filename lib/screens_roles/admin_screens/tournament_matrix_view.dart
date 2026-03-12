import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/sports_list.dart';
import 'package:tabulation_systemv7/services/schedule_announcement_service.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/announcement.dart';
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/tournament_calendar_printing.dart';

class TournamentCalendarScreen extends StatefulWidget {
  final String? tournamentId;
  final bool isEditable;

  const TournamentCalendarScreen({
    super.key,
    this.tournamentId,
    this.isEditable = true,
  });

  @override
  _TournamentCalendarScreenState createState() =>
      _TournamentCalendarScreenState();
}

class _TournamentCalendarScreenState extends State<TournamentCalendarScreen>
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
  String _selectedView = 'grid'; // Default to grid view

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
                      print('DEBUG [TournamentMatrix Announcement]: Error: ${snapshot.error}');
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
              onChanged: null, // Read-only for simplicity
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
                if (context.mounted) Navigator.pop(context); // Close bottom sheet
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

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Cached data
  List<Map<String, dynamic>>? _cachedSchedules;
  List<String>? _cachedSports;
  Set<String> _availableVenues = {};

  // Scroll controllers
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

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
    super.dispose();
  }

  DateTime? _parseDateTime(String dateTimeStr) {
    if (_dateCache.containsKey(dateTimeStr)) {
      return _dateCache[dateTimeStr];
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
      } catch (e) {
        // Ignore parsing errors
      }
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
      ' innings': Colors.indigo,
    };
    return colors[sport.toLowerCase()] ?? Colors.blue;
  }

  String _buildMatchVersusText(Map<String, dynamic> event) {
    final teams = event['teams'] as List<dynamic>? ?? [];
    final matchNumber = event['matchNumber'] as int? ?? 1;
    final round = event['round'] as int? ?? 1;

    bool isWinnerMatch = teams.any((team) =>
        team.toString().contains('Winner of') ||
        team.toString().contains('Loser of') ||
        team.toString().contains('winner of') ||
        team.toString().contains('loser of'));

    if (isWinnerMatch && teams.length >= 2) {
      if (round >= 2) {
        int prevRoundStartMatch;
        int prevRoundEndMatch;

        if (round == 2) {
          prevRoundStartMatch = matchNumber - 2;
          prevRoundEndMatch = matchNumber - 1;
        } else {
          prevRoundStartMatch = matchNumber - ((round - 1) * 2 - 1);
          prevRoundEndMatch = matchNumber - ((round - 1) * 2 - 2);
        }

        if (prevRoundStartMatch >= 1 && prevRoundEndMatch >= 1) {
          return 'Match $prevRoundStartMatch vs Match $prevRoundEndMatch';
        }
      }

      String team1 = teams[0]
          .toString()
          .replaceAll(
              RegExp(r'(Winner|Loser|winner|loser)\s+of\s+',
                  caseSensitive: false),
              '')
          .trim();
      String team2 = teams[1]
          .toString()
          .replaceAll(
              RegExp(r'(Winner|Loser|winner|loser)\s+of\s+',
                  caseSensitive: false),
              '')
          .trim();

      RegExp matchRegex = RegExp(r'Match\s*(\d+)', caseSensitive: false);
      Match? match1 = matchRegex.firstMatch(team1);
      Match? match2 = matchRegex.firstMatch(team2);

      if (match1 != null && match2 != null) {
        return 'Match $matchNumber: Match ${match1.group(1)} vs Match ${match2.group(1)}';
      }

      RegExp fullRegex =
          RegExp(r'Winner of Match (\d+) vs Match (\d+)', caseSensitive: false);
      String fullTeamString = teams[0].toString();
      Match? fullMatch = fullRegex.firstMatch(fullTeamString);
      if (fullMatch != null) {
        return 'Match $matchNumber: Match ${fullMatch.group(1)} vs Match ${fullMatch.group(2)}';
      }

      if (team1.isNotEmpty || team2.isNotEmpty) {
        return 'Match $matchNumber: ${team1.isNotEmpty ? team1 : "TBD"} vs ${team2.isNotEmpty ? team2 : "TBD"}';
      }
    }

    if (teams.length >= 2) {
      return 'Match $matchNumber: ${teams[0]} vs ${teams[1]}';
    } else if (teams.length == 1) {
      return 'Match $matchNumber: ${teams[0]} vs TBD';
    } else {
      return 'Match $matchNumber: TBD vs TBD';
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      return '${duration.inMinutes}m';
    }
  }

  Widget _buildModernEventCard(
    Map<String, dynamic> event,
    List<Map<String, dynamic>> allSchedules, {
    bool isCompact = false,
  }) {
    final teams = event['teams'] as List<dynamic>? ?? [];
    final venue = event['venue'] as String? ?? 'TBD';
    final gender = event['gender'] as String? ?? '';
    final tournamentName = event['tournamentName'] as String? ?? 'Tournament';
    final sportName =
        event['sportName'] as String? ?? event['sport'] as String? ?? 'Sport';
    final categoryName = event['categoryName'] as String? ?? 'Category';
    final matchNumber = event['matchNumber'] as int?;
    final round = event['round'] as int?;
    final sportColor = _getSportColor(sportName);

    // Parse times
    final startTimeStr = event['dateTime'] as String? ?? '';
    final endTimeStr = event['endTime'] as String? ?? '';
    final startTime = _parseDateTime(startTimeStr);
    final endTime = _parseDateTime(endTimeStr);

    // Calculate duration
    Duration? duration;
    String durationText = '';
    if (startTime != null && endTime != null) {
      duration = endTime.difference(startTime);
      durationText = _formatDuration(duration);
    }

    if (isCompact) {
      final matchText = _buildMatchVersusText(event);
      final isHovered = false;

      final teams = event['teams'] as List<dynamic>? ?? [];
      final hasTeams = teams.isNotEmpty;

      final displayText = hasTeams
          ? matchText
          : '${event['tournamentName'] ?? 'Tournament'}\n${event['sportName'] ?? ''}';

      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        transform: isHovered
            ? Matrix4.translationValues(0, -2, 0)
            : Matrix4.identity(),
        child: Tooltip(
          message:
              '$matchText\nDuration: $durationText\nVenue: $venue\nTournament: ${event['tournamentName'] ?? 'N/A'}',
          waitDuration: const Duration(milliseconds: 500),
          child: Material(
            color: Colors.transparent,
            elevation: isHovered ? 8 : 4,
            shadowColor: sportColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              onTap: widget.isEditable
                  ? () => _editMatchDateTime(context, event, allSchedules)
                  : null,
              borderRadius: BorderRadius.circular(6),
              splashColor: sportColor.withOpacity(0.2),
              highlightColor: sportColor.withOpacity(0.1),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      sportColor.withOpacity(0.85),
                      sportColor.withOpacity(0.65),
                      sportColor.withOpacity(0.45),
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: sportColor.withOpacity(0.9),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: sportColor.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.98),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black87, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasTeams ? matchText : 'No Teams Assigned',
                            style: TextStyle(
                              fontSize: hasTeams ? 11 : 10,
                              fontWeight: FontWeight.w900,
                              color: hasTeams ? Colors.black : Colors.red,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!hasTeams && event['tournamentName'] != null)
                            Text(
                              event['tournamentName'],
                              style: TextStyle(
                                fontSize: 7,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (startTime != null && endTime != null)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 2, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 6,
                                    color: sportColor.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 1),
                                  Expanded(
                                    child: Text(
                                      '${_timeFormat.format(startTime)}-${_timeFormat.format(endTime)}',
                                      style: TextStyle(
                                        fontSize: 6,
                                        color: sportColor.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                event['round'] != null
                                    ? Icons.flag
                                    : Icons.sports_soccer,
                                size: 6,
                                color: sportColor,
                              ),
                              const SizedBox(width: 1),
                              Text(
                                event['round'] != null
                                    ? 'R${event['round']}'
                                    : 'M${event['matchNumber'] ?? 1}',
                                style: TextStyle(
                                  fontSize: 6,
                                  color: sportColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                                      '${_timeFormat.format(startTime)} - ${_timeFormat.format(endTime)} • $durationText',
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
                    if (widget.isEditable)
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: sportColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _buildMatchVersusText(event),
                          style: TextStyle(
                            fontSize: isCompact ? 12 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
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
                    if (duration != null)
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gender == 'Men'
                              ? Colors.blue.withOpacity(0.1)
                              : gender == 'Women'
                                  ? Colors.pink.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
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
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  void _showMoreEventsDialog(
    BuildContext context,
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> allSchedules,
    String timeSlot,
    String sport,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.event,
                          color: _getSportColor(sport),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sport,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _getSportColor(sport),
                                ),
                              ),
                              Text(
                                '$timeSlot • ${events.length} matches',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        return _buildModernEventCard(
                          events[index],
                          allSchedules,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey[100],
      selectedColor: Colors.blue.withOpacity(0.2),
      checkmarkColor: Colors.blue,
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue : Colors.black87,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? Colors.blue : Colors.grey[300]!,
        ),
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
            color: Colors.grey.withOpacity(0.1),
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
                  Icon(Icons.view_column, color: Colors.blue[700]),
                  const SizedBox(width: 8),
                  const Text('Select Columns'),
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
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              localSelectedColumns.clear();
                              localSelectedColumns.addAll(sports);
                            });
                          },
                          child: const Text('Select All'),
                        ),
                        TextButton(
                          onPressed: () {
                            setDialogState(() {
                              localSelectedColumns.clear();
                            });
                          },
                          child: const Text('Clear All'),
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
                          final isSelected =
                              localSelectedColumns.contains(sport);
                          return CheckboxListTile(
                            title: Row(
                              children: [
                                Icon(
                                  Icons.sports,
                                  size: 20,
                                  color: _getSportColor(sport),
                                ),
                                const SizedBox(width: 8),
                                Text(sport),
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

  Widget _buildGridView(
      List<Map<String, dynamic>> schedules, List<String> sports) {
    final sportsWithMatches = <String>{};

    final calendarMap = <String, Map<String, List<Map<String, dynamic>>>>{};
    final eventSpanMap = <String, Map<String, Map<String, dynamic>>>{};

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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.sports,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedSportsColumns.isEmpty
                  ? 'No matches scheduled for this date'
                  : 'No matches for selected sports on this date',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedSportsColumns.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () => _showColumnSelectorDialog(sports),
                icon: const Icon(Icons.view_column),
                label: const Text('Select Different Sports'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _navigateDate(1),
                icon: const Icon(Icons.today),
                label: const Text('View Next Day'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
          ],
        ),
      );
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

    const double rowHeight = 90;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.blue.shade700,
                    Colors.blue.shade500,
                    Colors.blue.shade400,
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withOpacity(0.2), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 100,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'TIME',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _displayDateFormat.format(_selectedDate),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalScrollController,
                      itemCount: visibleSports.length,
                      itemBuilder: (context, index) {
                        final sport = visibleSports[index];
                        final sportColor = _getSportColor(sport);
                        final matchCount = schedules.where((s) {
                          final sportName = s['sport'] as String? ??
                              s['sportName'] as String? ??
                              '';
                          return sportName == sport;
                        }).length;

                        return Container(
                          width: 240,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: Colors.white.withOpacity(0.2),
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.sports,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                sport.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
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
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$matchCount match${matchCount != 1 ? 'es' : ''}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 50,
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.view_column,
                          color: Colors.white,
                          size: 22,
                        ),
                        onPressed: () => _showColumnSelectorDialog(sports),
                        tooltip: 'Select Columns',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.15),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _verticalScrollController,
                itemCount: timeSlots.length,
                itemBuilder: (context, rowIndex) {
                  final timeSlot = timeSlots[rowIndex];
                  final isEvenRow = rowIndex % 2 == 0;

                  return Container(
                    height: rowHeight,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 100,
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(
                                color: Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            color: isEvenRow
                                ? Colors.grey.withOpacity(0.02)
                                : Colors.transparent,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                timeSlot,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[800],
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                width: 30,
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            controller: _horizontalScrollController,
                            itemCount: visibleSports.length,
                            itemBuilder: (context, colIndex) {
                              final sport = visibleSports[colIndex];
                              final sportColor = _getSportColor(sport);

                              final startingEvents =
                                  calendarMap[timeSlot]?[sport] ?? [];

                              final isCovered = _isCellCoveredBySpanningEvent(
                                  rowIndex,
                                  timeSlots,
                                  sport,
                                  calendarMap,
                                  eventSpanMap);

                              return Container(
                                width: 240,
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                  ),
                                  color: isCovered
                                      ? sportColor.withOpacity(0.02)
                                      : (isEvenRow
                                          ? Colors.grey.withOpacity(0.02)
                                          : Colors.transparent),
                                ),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    if (startingEvents.isEmpty && !isCovered)
                                      Center(
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.grey.withOpacity(0.05),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '—',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 16,
                                                fontWeight: FontWeight.w300,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ...startingEvents
                                        .asMap()
                                        .entries
                                        .map((entry) {
                                      final eventIndex = entry.key;
                                      final event = entry.value;
                                      final eventId = event['id'];
                                      final spanInfo = eventSpanMap[timeSlot]
                                          ?[sport]?[eventId];
                                      final span = spanInfo?['span'] ?? 1;

                                      final double topOffset = eventIndex * 8.0;
                                      final double leftOffset =
                                          eventIndex * 4.0;
                                      final double rightOffset =
                                          eventIndex * 4.0;

                                      return Positioned(
                                        top: topOffset + 4,
                                        left: leftOffset + 4,
                                        right: rightOffset + 4,
                                        height:
                                            (rowHeight * span) - 16 - topOffset,
                                        child: AnimatedContainer(
                                          duration: Duration(
                                              milliseconds:
                                                  300 + (eventIndex * 100)),
                                          curve: Curves.easeOutCubic,
                                          child: Material(
                                            elevation: 6,
                                            shadowColor:
                                                sportColor.withOpacity(0.4),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: _buildModernMatrixEventCard(
                                              event,
                                              schedules,
                                              sportColor,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey.shade50,
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.withOpacity(0.2)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 100,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.sports,
                          size: 16,
                          color: Colors.blue[400],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${visibleSports.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _horizontalScrollController,
                      child: Row(
                        children: visibleSports.map((sport) {
                          final sportColor = _getSportColor(sport);
                          final matchCount = schedules.where((s) {
                            final sportName = s['sport'] as String? ??
                                s['sportName'] as String? ??
                                '';
                            return sportName == sport;
                          }).length;

                          return Container(
                            width: 220,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: sportColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: sportColor.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: sportColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      sport,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: sportColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '$matchCount',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: sportColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  Container(
                    width: 50,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 18),
                          onPressed: () {
                            _horizontalScrollController.animateTo(
                              _horizontalScrollController.offset - 200,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey[600],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 18),
                          onPressed: () {
                            _horizontalScrollController.animateTo(
                              _horizontalScrollController.offset + 200,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey[600],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernMatrixEventCard(
    Map<String, dynamic> event,
    List<Map<String, dynamic>> allSchedules,
    Color sportColor,
  ) {
    final teams = event['teams'] as List<dynamic>? ?? [];
    final venue = event['venue'] as String? ?? 'TBD';
    final tournamentName = event['tournamentName'] as String? ?? 'Tournament';
    final matchNumber = event['matchNumber'] as int? ?? 1;
    final round = event['round'] as int? ?? 1;
    final matchText = _buildMatchVersusText(event);
    final hasTeams = teams.isNotEmpty;

    final startTimeStr = event['dateTime'] as String? ?? '';
    final endTimeStr = event['endTime'] as String? ?? '';
    final startTime = _parseDateTime(startTimeStr);
    final endTime = _parseDateTime(endTimeStr);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            sportColor,
            sportColor.withOpacity(0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: sportColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isEditable
                ? () => _editMatchDateTime(context, event, allSchedules)
                : null,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: MatrixPatternPainter(sportColor),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tournamentName,
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: Center(
                          child: Text(
                            hasTeams ? matchText : 'TBD vs TBD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: const Offset(1, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (startTime != null && endTime != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 8,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    _timeFormat.format(startTime),
                                    style: const TextStyle(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  round > 1 ? Icons.flag : Icons.sports,
                                  size: 7,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  round > 1 ? 'R$round' : 'M$matchNumber',
                                  style: const TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (venue.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 6,
                                color: Colors.white.withOpacity(0.7),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  venue,
                                  style: TextStyle(
                                    fontSize: 6,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
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
                        _timeFormat.format(dateTime),
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
                  icon: const Icon(Icons.list_alt, color: Colors.blue),
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
                        ? _buildGridView(filteredSchedules, sports)
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
