import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tabulation_systemv7/services/schedule_announcement_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> with AutomaticKeepAliveClientMixin {
  final ScheduleAnnouncementService _announcementService = ScheduleAnnouncementService();
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy HH:mm');
  final DateFormat _timeFormat = DateFormat('HH:mm');
  final DateFormat _dayFormat = DateFormat('EEE, MMM dd');
  
  // Custom colors
  static const Color buttonColor = Color.fromARGB(255, 5, 18, 37);
  static const Color accentColor = Color.fromARGB(255, 255, 255, 255);
  
  // Filter options
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'High Priority', 'Unread', 'Events', 'Today'];
  
  // State variables
  bool _isRefreshing = false;
  final Map<String, bool> _readStatus = {};
  final Map<String, bool> _imageLoadErrors = {};
  
  // Responsive variables
  late double _screenWidth;
  late double _screenHeight;
  late bool _isTablet;
  late bool _isMobile;
  late bool _isLargeTablet;
  
  // Pagination
  final int _itemsPerPage = 20;
  DocumentSnapshot? _lastDocument;
  List<Map<String, dynamic>> _allAnnouncements = [];
  bool _hasMoreData = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitialAnnouncements();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreAnnouncements();
    }
  }

  Future<void> _loadInitialAnnouncements() async {
    setState(() {
      _allAnnouncements = [];
      _lastDocument = null;
      _hasMoreData = true;
    });
    await _loadMoreAnnouncements();
  }

  Future<void> _loadMoreAnnouncements() async {
    if (!_hasMoreData || _isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _announcementService.getPaginatedAnnouncements(
        lastDocument: _lastDocument,
        limit: _itemsPerPage,
      );

      setState(() {
        if (result.items.isEmpty) {
          _hasMoreData = false;
        } else {
          _allAnnouncements.addAll(result.items);
          _lastDocument = result.lastDoc;
          _hasMoreData = result.hasMore;
          
          // Initialize read status for new items
          for (var item in result.items) {
            final id = item['id'] ?? item['announcementId'] ?? DateTime.now().toString();
            _readStatus[id] = item['isRead'] ?? false;
          }
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
      _showErrorSnackBar('Failed to load more announcements');
    }
  }

  Future<void> _refreshAnnouncements() async {
    setState(() {
      _isRefreshing = true;
      _allAnnouncements = [];
      _lastDocument = null;
      _hasMoreData = true;
    });

    await _loadMoreAnnouncements();

    setState(() {
      _isRefreshing = false;
    });
  }

  Future<void> _markAsRead(String announcementId) async {
    try {
      await _announcementService.markAnnouncementAsRead(announcementId);
      setState(() {
        _readStatus[announcementId] = true;
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final unreadIds = _allAnnouncements
          .where((a) => !(_readStatus[a['id'] ?? a['announcementId']] ?? false))
          .map((a) => a['id'] ?? a['announcementId'])
          .where((id) => id != null)
          .cast<String>()
          .toList();

      if (unreadIds.isNotEmpty) {
        await _announcementService.markMultipleAsRead(unreadIds);
        setState(() {
          for (var id in unreadIds) {
            _readStatus[id] = true;
          }
        });
        _showSuccessSnackBar('All announcements marked as read');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to mark all as read');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // Get screen dimensions
    _screenWidth = MediaQuery.of(context).size.width;
    _screenHeight = MediaQuery.of(context).size.height;
    _isTablet = _screenWidth >= 600;
    _isLargeTablet = _screenWidth >= 900;
    _isMobile = _screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: Column(
            children: [
              _buildFilterChips(),
              _buildStatsBar(),
              Expanded(
                child: _buildAnnouncementsList(),
              ),
              if (_isLoadingMore)
                _buildLoadingIndicator(),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Announcements',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: buttonColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: _refreshAnnouncements,
          tooltip: 'Refresh',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onSelected: (value) {
            if (value == 'mark_all_read') {
              _markAllAsRead();
            } else if (value == 'filter') {
              _showFilterDialog();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_all_read',
              child: Row(
                children: [
                  Icon(Icons.done_all, size: 20),
                  SizedBox(width: 8),
                  Text('Mark all as read'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'filter',
              child: Row(
                children: [
                  Icon(Icons.filter_list, size: 20),
                  SizedBox(width: 8),
                  Text('Advanced filter'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildStatsBar() {
    final totalCount = _allAnnouncements.length;
    final unreadCount = _allAnnouncements
        .where((a) => !(_readStatus[a['id'] ?? a['announcementId']] ?? false))
        .length;
    final highPriorityCount = _allAnnouncements
        .where((a) => a['priority'] == 'high')
        .length;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getResponsivePadding(16),
        vertical: _getResponsivePadding(8),
      ),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.announcement,
            label: 'Total',
            value: '$totalCount',
            color: buttonColor,
          ),
          _buildStatItem(
            icon: Icons.mark_chat_unread,
            label: 'Unread',
            value: '$unreadCount',
            color: Colors.orange,
          ),
          _buildStatItem(
            icon: Icons.priority_high,
            label: 'High Priority',
            value: '$highPriorityCount',
            color: Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _getResponsivePadding(16),
        vertical: _getResponsivePadding(8),
      ),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterOptions.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: EdgeInsets.only(right: _getResponsivePadding(8)),
              child: FilterChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(12),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
                backgroundColor: Colors.grey.shade100,
                selectedColor: buttonColor,
                checkmarkColor: accentColor,
                labelStyle: TextStyle(
                  color: isSelected ? accentColor : buttonColor,
                ),
                elevation: isSelected ? 2 : 0,
                padding: EdgeInsets.symmetric(
                  horizontal: _getResponsivePadding(10),
                  vertical: _getResponsivePadding(6),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Advanced Filter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Date Range'),
              trailing: const Icon(Icons.date_range),
              onTap: () {
                Navigator.pop(context);
                _showDateRangePicker();
              },
            ),
            ListTile(
              title: const Text('Priority Level'),
              trailing: const Icon(Icons.flag),
              onTap: () {
                Navigator.pop(context);
                _showPriorityFilter();
              },
            ),
            ListTile(
              title: const Text('Announcement Type'),
              trailing: const Icon(Icons.category),
              onTap: () {
                Navigator.pop(context);
                _showTypeFilter();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDateRangePicker() {
    // Implement date range picker
    showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((date) {
      if (date != null) {
        // Handle date selection
      }
    });
  }

  void _showPriorityFilter() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Priority'),
        children: ['All', 'High', 'Medium', 'Normal'].map((priority) {
          return SimpleDialogOption(
            onPressed: () {
              setState(() {
                _selectedFilter = priority == 'All' ? 'All' : '$priority Priority';
              });
              Navigator.pop(context);
            },
            child: Text(priority),
          );
        }).toList(),
      ),
    );
  }

  void _showTypeFilter() {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Type'),
        children: ['All', 'Event', 'Alert', 'Update', 'Announcement'].map((type) {
          return SimpleDialogOption(
            onPressed: () {
              if (type == 'All') {
                setState(() => _selectedFilter = 'All');
              } else {
                setState(() => _selectedFilter = type);
              }
              Navigator.pop(context);
            },
            child: Text(type),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnnouncementsList() {
    if (_isRefreshing && _allAnnouncements.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredAnnouncements = _applyAdvancedFilter(_allAnnouncements);

    if (filteredAnnouncements.isEmpty) {
      return _buildEmptyState();
    }

    if (_isLargeTablet) {
      return _buildLargeTabletGrid(filteredAnnouncements);
    } else if (_isTablet) {
      return _buildTabletGrid(filteredAnnouncements);
    } else {
      return _buildMobileList(filteredAnnouncements);
    }
  }

  List<Map<String, dynamic>> _applyAdvancedFilter(List<Map<String, dynamic>> announcements) {
    return announcements.where((a) {
      final priority = a['priority'] ?? 'normal';
      final type = a['type'] ?? 'Announcement';
      final isRead = _readStatus[a['id'] ?? a['announcementId']] ?? false;
      final timestamp = a['timestamp'] as Timestamp?;
      final date = timestamp?.toDate();

      switch (_selectedFilter) {
        case 'High Priority':
          return priority == 'high';
        case 'Unread':
          return !isRead;
        case 'Events':
          return type == 'Event';
        case 'Today':
          if (date == null) return false;
          final now = DateTime.now();
          return date.year == now.year && 
                 date.month == now.month && 
                 date.day == now.day;
        default:
          return true;
      }
    }).toList();
  }

  Widget _buildLargeTabletGrid(List<Map<String, dynamic>> announcements) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        return _buildEnhancedCard(announcements[index], isLargeTablet: true);
      },
    );
  }

  Widget _buildTabletGrid(List<Map<String, dynamic>> announcements) {
    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.95,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        return _buildEnhancedCard(announcements[index], isLargeTablet: false);
      },
    );
  }

  Widget _buildMobileList(List<Map<String, dynamic>> announcements) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        return _buildEnhancedCard(announcements[index], isMobile: true);
      },
    );
  }

  Widget _buildEnhancedCard(
    Map<String, dynamic> announcement, {
    bool isLargeTablet = false,
    bool isMobile = false,
  }) {
    final timestamp = announcement['timestamp'] as Timestamp?;
    final date = timestamp?.toDate() ?? DateTime.now();
    final announcementId = announcement['id'] ?? 
                          announcement['announcementId'] ?? 
                          date.toString();
    final priority = announcement['priority'] ?? 'normal';
    final isRead = _readStatus[announcementId] ?? false;
    final type = announcement['type'] ?? 'Announcement';
    final message = announcement['message'] ?? 'No message';
    final title = announcement['title'] ?? type;
    
    // Dynamic sizing
    final cardPadding = isMobile ? 12.0 : (isLargeTablet ? 16.0 : 14.0);
    final iconSize = isMobile ? 18.0 : (isLargeTablet ? 22.0 : 20.0);
    final titleSize = isMobile ? 15.0 : (isLargeTablet ? 17.0 : 16.0);
    final messageSize = isMobile ? 13.0 : (isLargeTablet ? 14.0 : 13.5);
    
    // Truncate message based on layout
    final maxMessageLength = isMobile ? 80 : (isLargeTablet ? 150 : 100);
    final displayMessage = message.length > maxMessageLength 
        ? '${message.substring(0, maxMessageLength)}...' 
        : message;

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          _markAsRead(announcementId);
        }
        _showEnhancedDetails(announcement, date);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: isMobile ? 8 : 0),
        child: Card(
          elevation: isRead ? 1 : 3,
          shadowColor: !isRead ? buttonColor.withOpacity(0.2) : null,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: !isRead ? buttonColor.withOpacity(0.3) : Colors.grey.shade200,
              width: !isRead ? 1.5 : 1,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: !isRead ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  buttonColor.withOpacity(0.02),
                ],
              ) : null,
            ),
            child: Stack(
              children: [
                // Priority indicator
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: 0,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: _getPriorityColor(priority),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                ),
                
                // Content
                Padding(
                  padding: EdgeInsets.fromLTRB(16, cardPadding, cardPadding, cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header with type and time
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isMobile ? 6 : 8),
                            decoration: BoxDecoration(
                              color: _getTypeColor(type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getTypeIcon(type),
                              size: iconSize * 0.8,
                              color: _getTypeColor(type),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    color: buttonColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getSmartDateDisplay(date),
                                  style: TextStyle(
                                    fontSize: isMobile ? 10 : 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Unread indicator
                          if (!isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Message preview
                      Text(
                        displayMessage,
                        style: TextStyle(
                          fontSize: messageSize,
                          height: 1.3,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: isMobile ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Tags and metadata
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildEnhancedTag(
                            icon: _getPriorityIcon(priority),
                            label: priority.toUpperCase(),
                            color: _getPriorityColor(priority),
                            isMobile: isMobile,
                          ),
                          if (announcement['location'] != null)
                            _buildEnhancedTag(
                              icon: Icons.location_on,
                              label: announcement['location'],
                              color: Colors.teal,
                              isMobile: isMobile,
                            ),
                          if (announcement['sportName'] != null)
                            _buildEnhancedTag(
                              icon: Icons.sports,
                              label: announcement['sportName'],
                              color: Colors.purple,
                              isMobile: isMobile,
                            ),
                          _buildEnhancedTag(
                            icon: Icons.remove_red_eye,
                            label: isRead ? 'Read' : 'New',
                            color: isRead ? Colors.green : Colors.orange,
                            isMobile: isMobile,
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

  String _getSmartDateDisplay(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today at ${_timeFormat.format(date)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${_timeFormat.format(date)}';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return _dayFormat.format(date);
    }
  }

  Widget _buildEnhancedTag({
    required IconData icon,
    required String label,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 10,
        vertical: isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isMobile ? 12 : 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label.length > 8 && isMobile ? '${label.substring(0, 6)}...' : label,
            style: TextStyle(
              fontSize: isMobile ? 10 : 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showEnhancedDetails(Map<String, dynamic> announcement, DateTime date) {
    final isRead = _readStatus[announcement['id'] ?? announcement['announcementId']] ?? false;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: _screenHeight * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _getTypeColor(announcement['type'] ?? 'Announcement').withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getTypeIcon(announcement['type'] ?? 'Announcement'),
                          color: _getTypeColor(announcement['type'] ?? 'Announcement'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            announcement['title'] ?? announcement['type'] ?? 'Announcement',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getSmartDateDisplay(date),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 20),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full message
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        announcement['message'] ?? 'No content available',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Details section
                    const Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Details grid
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      childAspectRatio: 2.5,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      children: [
                        _buildDetailChip(
                          Icons.priority_high,
                          'Priority',
                          announcement['priority'] ?? 'Normal',
                          _getPriorityColor(announcement['priority'] ?? 'normal'),
                        ),
                        _buildDetailChip(
                          Icons.access_time,
                          'Time',
                          announcement['time'] ?? 'Not specified',
                          buttonColor,
                        ),
                        if (announcement['location'] != null)
                          _buildDetailChip(
                            Icons.location_on,
                            'Location',
                            announcement['location'],
                            Colors.teal,
                          ),
                        if (announcement['sportName'] != null)
                          _buildDetailChip(
                            Icons.sports,
                            'Sport',
                            announcement['sportName'],
                            Colors.purple,
                          ),
                        if (announcement['tournamentName'] != null)
                          _buildDetailChip(
                            Icons.emoji_events,
                            'Tournament',
                            announcement['tournamentName'],
                            Colors.amber.shade800,
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              // Share functionality
                            },
                            icon: const Icon(Icons.share),
                            label: const Text('Share'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (!isRead) {
                                _markAsRead(announcement['id'] ?? announcement['announcementId']);
                              }
                              Navigator.pop(context);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Got it'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_rounded,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No announcements found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pull down to refresh',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.shade200,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load announcements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _refreshAnnouncements,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildFloatingActionButton() {
    if (_isMobile) {
      return FloatingActionButton(
        onPressed: _showCreateOptions,
        backgroundColor: buttonColor,
        child: const Icon(Icons.add, color: Colors.white),
      );
    }
    return const SizedBox.shrink();
  }

  void _showCreateOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.announcement),
              title: const Text('New Announcement'),
              onTap: () {
                Navigator.pop(context);
                _showCreateAnnouncementDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.event),
              title: const Text('New Event'),
              onTap: () {
                Navigator.pop(context);
                // Handle new event
              },
            ),
            ListTile(
              leading: const Icon(Icons.warning),
              title: const Text('New Alert'),
              onTap: () {
                Navigator.pop(context);
                // Handle new alert
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Announcement'),
        content: const Text('This feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper methods
  double _getResponsivePadding(double basePadding) {
    if (_isLargeTablet) return basePadding * 1.5;
    if (_isTablet) return basePadding * 1.2;
    if (_screenWidth < 360) return basePadding * 0.8;
    return basePadding;
  }

  double _getResponsiveFontSize(double baseSize) {
    if (_isLargeTablet) return baseSize * 1.2;
    if (_isTablet) return baseSize * 1.1;
    if (_screenWidth < 360) return baseSize * 0.9;
    return baseSize;
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return buttonColor;
    }
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.remove;
      default:
        return Icons.low_priority;
    }
  }

  String _getPriorityLabel(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return 'High';
      case 'medium':
        return 'Med';
      default:
        return 'Norm';
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Event':
        return Colors.purple;
      case 'Alert':
        return Colors.red;
      case 'Update':
        return Colors.blue;
      default:
        return buttonColor;
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

  String _formatTime(String? time) {
    if (time == null) return '';
    if (time.length > 5) return time.substring(0, 5);
    return time;
  }
}

// Extension for pagination result
extension on ScheduleAnnouncementService {
  Future<PaginatedAnnouncements> getPaginatedAnnouncements({
    DocumentSnapshot? lastDocument,
    required int limit,
  }) async {
    // Implement pagination logic here
    // This is a placeholder - implement based on your actual service
    final items = await getLatestAnnouncements().first;
    return PaginatedAnnouncements(
      items: items,
      lastDoc: null,
      hasMore: false,
    );
  }

  Future<void> markAnnouncementAsRead(String id) async {
    // Implement mark as read logic
  }

  Future<void> markMultipleAsRead(List<String> ids) async {
    // Implement bulk mark as read
  }
}

class PaginatedAnnouncements {
  final List<Map<String, dynamic>> items;
  final DocumentSnapshot? lastDoc;
  final bool hasMore;

  PaginatedAnnouncements({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}