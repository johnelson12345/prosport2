import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/services/schedule_announcement_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final ScheduleAnnouncementService _announcementService = ScheduleAnnouncementService();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  
  // Custom colors from previous conversation
  static const Color buttonColor = Color.fromARGB(255, 5, 18, 37);
  static const Color accentColor = Color.fromARGB(255, 255, 255, 255); // White for text/icons on dark bg
  
  // Filter options
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'High Priority', 'Unread', 'Events'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // appBar: AppBar(
      //   title: const Text(
      //     'Announcements',
      //     style: TextStyle(
      //       color: Colors.white,
      //       fontWeight: FontWeight.bold,
      //       fontSize: 24,
      //       letterSpacing: 1.2,
      //     ),
      //   ),
      //   centerTitle: true,
      //   elevation: 0,
      //   backgroundColor: buttonColor, // Using the custom button color
      //   actions: [
      //     IconButton(
      //       icon: const Icon(Icons.refresh, color: Colors.white),
      //       onPressed: () {
      //         setState(() {});
      //       },
      //     ),
      //     const SizedBox(width: 8),
      //   ],
      // ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Filter chips
            _buildFilterChips(),
            
            // Announcements list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _announcementService.getLatestAnnouncements(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: buttonColor.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(
                              fontSize: 16,
                              color: buttonColor,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              buttonColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading announcements...',
                            style: TextStyle(
                              fontSize: 16,
                              color: buttonColor.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  var announcements = snapshot.data!;
                  
                  // Apply filter
                  announcements = _applyFilter(announcements);
                  
                  if (announcements.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notifications_off_rounded,
                            size: 80,
                            color: buttonColor.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No announcements found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: buttonColor.withOpacity(0.7),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check back later for updates',
                            style: TextStyle(
                              fontSize: 14,
                              color: buttonColor.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: announcements.length,
                    itemBuilder: (context, index) {
                      final announcement = announcements[index];
                      final timestamp = announcement['timestamp'] as Timestamp?;
                      final formattedDate = timestamp != null
                          ? _dateFormat.format(timestamp.toDate())
                          : (announcement['date'] ?? 'Unknown Date');

                      return _buildAnnouncementCard(announcement, formattedDate);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      
   
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterOptions.map((filter) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter),
                selected: _selectedFilter == filter,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor: buttonColor, // Using custom button color
                checkmarkColor: accentColor, // White checkmark
                labelStyle: TextStyle(
                  color: _selectedFilter == filter ? accentColor : buttonColor,
                  fontWeight: _selectedFilter == filter ? FontWeight.bold : FontWeight.normal,
                ),
                elevation: _selectedFilter == filter ? 2 : 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> announcements) {
    switch (_selectedFilter) {
      case 'High Priority':
        return announcements.where((a) => a['priority'] == 'high').toList();
      case 'Unread':
        return announcements.where((a) => a['isRead'] == false).toList();
      case 'Events':
        return announcements.where((a) => a['type'] == 'Event').toList();
      default:
        return announcements;
    }
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement, String formattedDate) {
    final priority = announcement['priority'] ?? 'normal';
    final isRead = announcement['isRead'] ?? false;
    final type = announcement['type'] ?? 'Announcement';
    
    // Color based on priority
    Color priorityColor;
    IconData priorityIcon;
    
    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        priorityIcon = Icons.priority_high;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        priorityIcon = Icons.remove;
        break;
      default:
        priorityColor = buttonColor; // Using button color for normal priority
        priorityIcon = Icons.low_priority;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: buttonColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showAnnouncementDetails(announcement, formattedDate);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isRead ? Colors.grey.shade200 : buttonColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                // Priority indicator
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: priorityColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _getTypeColor(type).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    _getTypeIcon(type),
                                    size: 18,
                                    color: _getTypeColor(type),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: _getTypeColor(type),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: buttonColor.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: buttonColor.withOpacity(0.2)),
                            ),
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: buttonColor.withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      if (announcement['message'] != null) ...[
                        Text(
                          announcement['message'],
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                            color: buttonColor.withOpacity(0.9),
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Tags section
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildTag(
                            icon: priorityIcon,
                            label: 'Priority: $priority',
                            color: priorityColor,
                          ),
                          if (announcement['time'] != null)
                            _buildTag(
                              icon: Icons.access_time,
                              label: announcement['time'],
                              color: buttonColor,
                            ),
                          _buildTag(
                            icon: isRead ? Icons.done_all : Icons.mark_chat_unread,
                            label: isRead ? 'Read' : 'Unread',
                            color: isRead ? Colors.green : buttonColor,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // View details indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Tap for details',
                            style: TextStyle(
                              fontSize: 12,
                              color: buttonColor.withOpacity(0.4),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 12,
                            color: buttonColor.withOpacity(0.4),
                          ),
                        ],
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

  Widget _buildTag({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Event':
        return buttonColor; // Using button color instead of purple
      case 'Alert':
        return Colors.red;
      case 'Update':
        return Colors.blue;
      default:
        return buttonColor.withOpacity(0.8);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Event':
        return Icons.event;
      case 'Alert':
        return Icons.warning_amber_rounded;
      case 'Update':
        return Icons.update;
      default:
        return Icons.campaign;
    }
  }

  // FIXED: Changed from bottom sheet to centered dialog
  void _showAnnouncementDetails(Map<String, dynamic> announcement, String formattedDate) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 16,
          backgroundColor: Colors.white,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: buttonColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.announcement,
                              color: buttonColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            announcement['type'] ?? 'Announcement',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: buttonColor,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Date and time
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: buttonColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: buttonColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            fontSize: 14,
                            color: buttonColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Message
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: buttonColor.withOpacity(0.2)),
                    ),
                    child: Text(
                      announcement['message'] ?? 'No message content',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: buttonColor.withOpacity(0.9),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Additional Information
                  Text(
                    'Additional Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: buttonColor,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Info rows
                  _buildInfoRow('Priority', announcement['priority'] ?? 'normal'),
                   Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow('Time', announcement['time'] ?? 'Not specified'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  _buildInfoRow('Status', announcement['isRead'] ?? false ? 'Read' : 'Unread'),
                  Divider(height: 1, color: Colors.grey.shade200),
                  if (announcement['tournamentName'] != null)
                    _buildInfoRow('Tournament', announcement['tournamentName']),
                  if (announcement['sportName'] != null)
                    _buildInfoRow('Sport', announcement['sportName']),
                  
                  const SizedBox(height: 24),
                  
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buttonColor,
                        foregroundColor: accentColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: buttonColor.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: buttonColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          width: MediaQuery.of(context).size.width * 0.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Announcement',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: buttonColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This feature is coming soon!',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: buttonColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      // Save announcement
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: accentColor,
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}