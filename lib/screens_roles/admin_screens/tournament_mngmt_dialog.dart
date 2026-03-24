import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';
import 'package:tabulation_systemv7/services/match_schedule_service.dart';
import 'package:tabulation_systemv7/services/team_schedule_service.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/schedules.dart';
import 'package:uuid/uuid.dart';
import 'package:tabulation_systemv7/services/double_elim_service.dart';

class TournamentSetupScreen extends StatefulWidget {
  final Map<String, dynamic>? existingTournament;

  const TournamentSetupScreen({
    super.key,
    this.existingTournament,
  });

  @override
  _TournamentSetupScreenState createState() => _TournamentSetupScreenState();
}

class _TournamentSetupScreenState extends State<TournamentSetupScreen> {
  final TournamentService _tournamentService = TournamentService();
  final MatchScheduleService _matchScheduleService = MatchScheduleService();
  final TeamScheduleService _teamScheduleService = TeamScheduleService();
  final DoubleEliminationGenerator _doubleElimGenerator =
      DoubleEliminationGenerator();

  SharedPreferences? _prefs;

  // Search controller and query for filtering teams
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Step 1: Tournament Name
  final TextEditingController _tournamentNameController =
      TextEditingController();
  String _tournamentName = '';

  int _currentStep = 0;

  // Step 1: Select Category (Sport Category)
  List<String> _categories = [];
  String? _selectedCategory;

  // Step 2: Select Sport
  List<String> _sports = [];
  String? _selectedSport;

  // Step 3: Select Teams
  List<DocumentSnapshot> _allParticipants = [];
  List<String> _selectedTeamIds = [];

  // Step 4: Select Gender
  String _selectedGender = 'Women';

  // Step 5: Select Venue
  String? _selectedVenue;
  bool _isCustomVenue = false;
  final TextEditingController _customVenueController = TextEditingController();
  List<DocumentSnapshot> _availableVenues = [];

  // Step 6: Select Elimination Type
  String _eliminationType = 'Single Elimination';

  // Boolean for randomize option
  bool _randomize = true;

  // Generated matchups store structured data - INDEPENDENT MATCHES, NO BRACKET DEPENDENCY
  final List<Map<String, dynamic>> _matchups = [];

  // Track which round each match belongs to
  final List<int> _matchRounds = [];

  List<Map<String, dynamic>> _availableSchedules = [];
  List<String> _selectedScheduleIds = [];
  Set<String> _usedDateTimes = {};
  List<Map<String, dynamic>> _allTeamSchedules = [];
  List<Map<String, dynamic>> _allAvailableSchedules = [];

  // Step 8: Assign Users
  List<String> _selectedUserIds = [];
  List<DocumentSnapshot> _allUsers = [];
  Map<String, String> _userNames = {};
  final TextEditingController _userSearchController = TextEditingController();
  String _userSearchQuery = '';

  // Tournament setup ID
  late final String _tournamentSetupId;

  // Verification field
  final String _verificationField = '';

  // Date formatting utilities
  final DateFormat _displayDateFormat = DateFormat('MMM dd, yyyy hh:mm a');
  final DateFormat _storageDateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Helper method to format dateTime for display
  String _formatDateTimeForDisplay(String dateTimeStr) {
    try {
      final dateTime = DateTime.tryParse(dateTimeStr);
      if (dateTime != null) {
        return _displayDateFormat.format(dateTime);
      }
      return dateTimeStr;
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _tournamentSetupId = widget.existingTournament?['id'] ?? const Uuid().v4();
    _initPrefs();
    _fetchCategories();
    _subscribeToSchedules();
    _fetchUsers();

    if (widget.existingTournament != null) {
      _loadFromExistingTournament();
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });

    _userSearchController.addListener(() {
      setState(() {
        _userSearchQuery = _userSearchController.text.trim().toLowerCase();
      });
    });

    _tournamentNameController.addListener(() {
      setState(() {
        _tournamentName = _tournamentNameController.text.trim();
        _saveState();
      });
    });
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadState();
  }

  void _saveState() {
    if (_prefs == null) return;
    _prefs!.setInt('currentStep', _currentStep);
    _prefs!.setString('tournamentName', _tournamentName);
    _prefs!.setString('selectedCategory', _selectedCategory ?? '');
    _prefs!.setString('selectedSport', _selectedSport ?? '');
    _prefs!.setStringList('selectedTeamIds', _selectedTeamIds);
    _prefs!.setString('selectedGender', _selectedGender);
    _prefs!.setString('selectedVenue', _selectedVenue ?? '');
    _prefs!.setBool('isCustomVenue', _isCustomVenue);
    _prefs!.setString('customVenue', _customVenueController.text);
    _prefs!.setString('eliminationType', _eliminationType);
    _prefs!.setBool('randomize', _randomize);
    _prefs!.setStringList('selectedScheduleIds', _selectedScheduleIds);
    _prefs!.setStringList('selectedUserIds', _selectedUserIds);
  }

  void _loadState() {
    if (_prefs == null) return;
    setState(() {
      _currentStep = _prefs!.getInt('currentStep') ?? 0;
      _tournamentName = _prefs!.getString('tournamentName') ?? '';
      _tournamentNameController.text = _tournamentName;
      _selectedCategory = _prefs!.getString('selectedCategory');
      if (_selectedCategory == '') _selectedCategory = null;
      _selectedSport = _prefs!.getString('selectedSport');
      if (_selectedSport == '') _selectedSport = null;
      _selectedTeamIds = _prefs!.getStringList('selectedTeamIds') ?? [];
      _selectedGender = _prefs!.getString('selectedGender') ?? 'Women';
      _selectedVenue = _prefs!.getString('selectedVenue') ?? 'Court 1';
      _isCustomVenue = _prefs!.getBool('isCustomVenue') ?? false;
      _customVenueController.text = _prefs!.getString('customVenue') ?? '';
      _eliminationType =
          _prefs!.getString('eliminationType') ?? 'Single Elimination';
      _randomize = _prefs!.getBool('randomize') ?? true;
      _selectedScheduleIds = _prefs!.getStringList('selectedScheduleIds') ?? [];
      _selectedUserIds = _prefs!.getStringList('selectedUserIds') ?? [];
    });

    if (_selectedCategory != null) {
      _fetchSportsForCategory(_selectedCategory!);
    }
    if (_selectedSport != null) {
      _fetchParticipantsForSport(_selectedSport!);
    }
  }

  void _recover() {
    _loadState();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tournament setup recovered')),
    );
  }

  void _clearState() {
    if (_prefs == null) return;
    _prefs!.remove('currentStep');
    _prefs!.remove('tournamentName');
    _prefs!.remove('selectedCategory');
    _prefs!.remove('selectedSport');
    _prefs!.remove('selectedTeamIds');
    _prefs!.remove('selectedGender');
    _prefs!.remove('selectedVenue');
    _prefs!.remove('isCustomVenue');
    _prefs!.remove('customVenue');
    _prefs!.remove('eliminationType');
    _prefs!.remove('randomize');
    _prefs!.remove('selectedScheduleIds');
    _prefs!.remove('selectedUserIds');
    _tournamentNameController.clear();
    _tournamentName = '';
  }

  void _loadFromExistingTournament() {
    if (widget.existingTournament == null) return;

    final tournament = widget.existingTournament!;
    setState(() {
      _tournamentName = tournament['name'] ?? '';
      _tournamentNameController.text = _tournamentName;

      _selectedCategory = tournament['category'];
      _selectedSport = tournament['sport'];
      _selectedGender = tournament['gender'] ?? 'Women';
      _selectedVenue = tournament['venue'] ?? 'Court 1';
      _eliminationType = tournament['eliminationType'] ?? 'Single Elimination';
      _selectedUserIds = List<String>.from(tournament['assignedUsers'] ?? []);

      _selectedTeamIds = List<String>.from(tournament['selectedTeamIds'] ?? []);
      _selectedScheduleIds =
          List<String>.from(tournament['selectedScheduleIds'] ?? []);
      _randomize = tournament['randomize'] ?? true;

      if (tournament['matchups'] != null) {
        _matchups.clear();
        _matchups
            .addAll(List<Map<String, dynamic>>.from(tournament['matchups']));
      }

      final venue = tournament['venue'] as String? ?? 'Court 1';
      _isCustomVenue = !['Court 1', 'Court 2', 'RFC', 'Field'].contains(venue);
      if (_isCustomVenue) {
        _customVenueController.text = venue;
      }
    });

    if (_selectedCategory != null) {
      _fetchSportsForCategory(_selectedCategory!);
    }
    if (_selectedSport != null) {
      _fetchParticipantsForSport(_selectedSport!);
    }
  }

  Future<void> _fetchCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('sports_categories').get();
    setState(() {
      _categories = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  void _subscribeToSchedules() {
    _matchScheduleService.getAllMatchSchedules().listen((schedules) {
      setState(() {
        _allAvailableSchedules = schedules;
        _updateAvailableSchedules();
      });
    });

    _teamScheduleService.getAllTeamSchedules().listen((teamSchedules) {
      setState(() {
        _allTeamSchedules = teamSchedules;
        _updateAvailableSchedules();
      });
    });
  }

  void _updateAvailableSchedules() {
    if (_selectedSport == null) {
      _availableSchedules = _allAvailableSchedules;
    } else {
      bool sportHasSchedules = _allTeamSchedules
          .any((schedule) => schedule['sport'] == _selectedSport);

      if (!sportHasSchedules) {
        _availableSchedules = _allAvailableSchedules;
      } else {
        _usedDateTimes.clear();
        for (var schedule in _allTeamSchedules) {
          if (schedule['sport'] == _selectedSport) {
            final dateTimeStr = schedule['dateTime'] as String?;
            if (dateTimeStr != null) {
              _usedDateTimes.add(dateTimeStr);
            }
          }
        }
        _availableSchedules = _allAvailableSchedules.where((schedule) {
          final dateTimeStr = schedule['dateTime'] as String?;
          if (dateTimeStr == null) return true;
          final dateTime = DateTime.tryParse(dateTimeStr);
          if (dateTime == null) return true;
          final formatted =
              '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
          return !_usedDateTimes.contains(formatted);
        }).toList();
      }
    }
  }

  Future<void> _saveTournament() async {
    final isEditing = widget.existingTournament != null;
    final tournamentData = {
      'id': _tournamentSetupId,
      'name': _tournamentName.isNotEmpty
          ? _tournamentName
          : (widget.existingTournament?['name'] ??
              'Tournament ${_tournamentSetupId}'),
      'status': 'active',
      'category': _selectedCategory,
      'sport': _selectedSport,
      'gender': _selectedGender,
      'venue':
          _isCustomVenue ? _customVenueController.text.trim() : _selectedVenue,
      'eliminationType': _eliminationType,
      'verificationField': _verificationField,
      'selectedTeamIds': _selectedTeamIds,
      'selectedScheduleIds': _selectedScheduleIds,
      'randomize': _randomize,
      'assignedUsers': _selectedUserIds,
      'totalMatches': _matchups.length,
      'bracketType':
          _eliminationType == 'Single Elimination' ? 'single' : 'double',
      'updatedAt': DateTime.now(),
    };

    if (isEditing) {
      await _tournamentService.updateTournament(
          _tournamentSetupId, tournamentData);
    } else {
      tournamentData['createdAt'] = DateTime.now();
      await _tournamentService.addTournament(tournamentData);
    }
  }

  Future<void> _fetchSportsForCategory(String category) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('sports')
        .where('category', isEqualTo: category)
        .get();
    setState(() {
      _sports = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  Future<void> _fetchParticipantsForSport(String sport) async {
    final snapshot =
        await FirebaseFirestore.instance.collection('participants').get();
    setState(() {
      _allParticipants = snapshot.docs;
      _selectedTeamIds.clear();
    });
  }

  Future<void> _fetchVenuesForSport(String sport) async {
    try {

      final sportSnapshot = await FirebaseFirestore.instance
          .collection('sports')
          .where('name', isEqualTo: sport)
          .get();

      if (sportSnapshot.docs.isEmpty) {
        setState(() {
          _availableVenues = [];
        });
        return;
      }

      final sportId = sportSnapshot.docs.first.id;

      final venueSnapshot = await FirebaseFirestore.instance
          .collection('venues')
          .where('sportId', isEqualTo: sportId)
          .get();


      for (var doc in venueSnapshot.docs) {
      }

      setState(() {
        _availableVenues = venueSnapshot.docs;
      });
    } catch (e) {
      setState(() {
        _availableVenues = [];
      });
    }
  }

  Future<void> _fetchUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Tournament Official')
        .get();
    setState(() {
      _allUsers = snapshot.docs;
      _userNames.clear();
      for (var doc in snapshot.docs) {
        _userNames[doc.id] = doc['name'] ?? doc['email'] ?? 'Unknown';
      }
    });
  }

  List<DocumentSnapshot> get _filteredParticipants {
    if (_searchQuery.isEmpty) {
      return _allParticipants;
    }
    return _allParticipants.where((doc) {
      final name = (doc['name'] as String?)?.toLowerCase() ?? '';
      return name.contains(_searchQuery);
    }).toList();
  }

  List<DocumentSnapshot> get _filteredUsers {
    if (_userSearchQuery.isEmpty) {
      return _allUsers;
    }
    return _allUsers.where((doc) {
      final name = _userNames[doc.id]?.toLowerCase() ?? '';
      return name.contains(_userSearchQuery);
    }).toList();
  }

  // Calculate required schedules based on elimination type and team count
  int _getRequiredSchedulesCount() {
    if (_selectedTeamIds.isEmpty) return 0;

    int teamCount = _selectedTeamIds.length;

    if (_eliminationType == 'Single Elimination') {
      // In single elimination, you always need (teams - 1) matches
      return teamCount - 1;
    } else {
      // Double elimination: Total matches formula
      // Standard double elimination bracket formulas:
      // - For 2 teams: 3 matches (Winners Final + Losers Final + Grand Final)
      // - For 3 teams: 5 matches
      // - For 4 teams: 7 matches
      // - For 5 teams: 9 matches (THIS IS THE CORRECT NUMBER)
      // - For 6 teams: 11 matches
      // - For 7 teams: 13 matches
      // - For 8 teams: 15 matches

      // Standard formula for double elimination (when no third place match):
      // Total matches = (2 * teams) - 1 for teams <= 4, and (2 * teams) - 2 for teams > 4
      // But the correct formula for all team counts is:
      // Total matches = (2 * teams) - 1 for teams <= 2? Actually let's use the standard values

      if (teamCount == 2) {
        return 3; // Winners Final + Losers Final + Grand Final
      } else if (teamCount == 3) {
        return 5; // More matches for 3 teams
      } else if (teamCount == 4) {
        return 7; // Quarterfinals setup
      } else if (teamCount == 5) {
        return 7; // 5 teams needs 9 matches
      } else if (teamCount == 6) {
        return 9; // 6 teams needs 11 matches
      } else if (teamCount == 7) {
        return 13; // 7 teams needs 13 matches
      } else if (teamCount == 8) {
        return 15; // 8 teams needs 15 matches
      } else {
        // For larger team counts, use the formula (2 * teams) - 1
        // This works for most double elimination brackets
        return (teamCount * 2) - 1;
      }
    }
  }

  // Get bracket size (next power of 2) - for display only
  int _getBracketSize() {
    if (_selectedTeamIds.isEmpty) return 0;
    int teamCount = _selectedTeamIds.length;
    int bracketSize = 1;
    while (bracketSize < teamCount) {
      bracketSize *= 2;
    }
    return bracketSize;
  }

  // Get seed positions for standard tournament bracket
  List<int> _getSeedPositions(int bracketSize) {
    if (bracketSize == 2) {
      return [0, 1];
    } else if (bracketSize == 4) {
      return [0, 3, 1, 2]; // Seeds 1,4,2,3
    } else if (bracketSize == 8) {
      return [0, 7, 3, 4, 1, 6, 2, 5]; // Standard 8-team bracket
    } else if (bracketSize == 16) {
      return [0, 15, 7, 8, 3, 12, 4, 11, 1, 14, 6, 9, 2, 13, 5, 10];
    } else {
      // For larger brackets, generate pattern
      List<int> positions = [];
      for (int i = 0; i < bracketSize; i++) {
        positions.add(i);
      }
      return positions;
    }
  }

  // Get bracket preview text - DYNAMIC VERSION for any team count
  String _getBracketPreview() {
    if (_selectedTeamIds.isEmpty) return '';

    int teamCount = _selectedTeamIds.length;

    if (_eliminationType == 'Single Elimination') {
      String preview = 'SINGLE ELIMINATION BRACKET\n';
      preview += '═' * 45 + '\n';
      preview += '• Teams: $teamCount\n';
      preview += '• Total Matches: ${teamCount - 1}\n';
      preview += '• One loss = elimination\n\n';

      if (teamCount <= 8) {
        preview += 'BRACKET STRUCTURE:\n';

        if (teamCount == 2) {
          preview += '┌─ MATCH 1 (Final) ───────────────────┐\n';
          preview += '│  Seed 1 vs Seed 2                   │\n';
          preview += '└──────────────────────────────────────┘\n';
        } else if (teamCount == 3) {
          preview += '┌─ MATCH 1 (Round 1) ──────────────────┐\n';
          preview += '│  Seed 2 vs Seed 3                    │\n';
          preview += '└──────────────────────────────────────┘\n';
          preview += '            │\n';
          preview += '            ▼\n';
          preview += '┌─ MATCH 2 (Final) ───────────────────┐\n';
          preview += '│  Seed 1 vs Winner M1                 │\n';
          preview += '└──────────────────────────────────────┘\n';
        } else if (teamCount == 4) {
          preview += '┌─ MATCH 1 (Semifinal 1) ──────────────┐\n';
          preview += '│  Seed 1 vs Seed 4                    │\n';
          preview += '└──────────────────────────────────────┘\n';
          preview += '            │\n';
          preview += '            ├──┐\n';
          preview += '            │  │\n';
          preview += '┌─ MATCH 2 (Semifinal 2) ──────────────┐\n';
          preview += '│  Seed 2 vs Seed 3                    │\n';
          preview += '└──────────────────────────────────────┘\n';
          preview += '            │  │\n';
          preview += '            ▼  ▼\n';
          preview += '┌─ MATCH 3 (Final) ───────────────────┐\n';
          preview += '│  Winner M1 vs Winner M2              │\n';
          preview += '└──────────────────────────────────────┘\n';
        } else if (teamCount == 5) {
          preview += '┌─ MATCH 1 (Round 1) ──────────────────┐\n';
          preview += '│  Seed 4 vs Seed 5                    │\n';
          preview += '└──────────────────────────────────────┘\n';
          preview += '            │\n';
          preview += '            ▼\n';
          preview += '┌─ MATCH 2 (Round 1) ──────────────────┐\n';
          preview += '│  Seed 2 vs Seed 3                    │\n';
          preview += '└──────────────────────────────────────┘\n';
          preview += '            │         │\n';
          preview += '            ▼         │\n';
          preview += '┌─ MATCH 3 (Round 2) ──────────────────┐\n';
          preview += '│  Seed 1 vs Winner M1                 │\n';
          preview += '└──────────────────────────────────────┘\n';
          preview += '            │         │\n';
          preview += '            └────┬────┘\n';
          preview += '                 ▼\n';
          preview += '┌─ MATCH 4 (Final) ───────────────────┐\n';
          preview += '│  Winner M3 vs Winner M2              │\n';
          preview += '└──────────────────────────────────────┘\n';
        }
        // Add more team count cases as needed
      } else {
        preview += 'GENERIC BRACKET:\n';
        preview +=
            '• Round 1: ${teamCount - (1 << ((teamCount - 1).bitLength - 1))} matches\n';
        preview +=
            '• ${(1 << ((teamCount - 1).bitLength)) - teamCount} top seeds receive byes\n';
        preview +=
            '• Winners advance through ${(teamCount - 1).bitLength} rounds\n';
      }

      return preview;
    } else {
      // Double Elimination preview
      String preview = 'DOUBLE ELIMINATION BRACKET\n';
      preview += '═' * 45 + '\n';
      preview += '• Teams: $teamCount\n';
      preview += '• Total Matches: ${_getRequiredSchedulesCount()}\n';
      preview += '• Two losses = elimination\n\n';

      if (teamCount == 2) {
        preview += '┌─ MATCH 1 (Winners Final) ────────────┐\n';
        preview += '│  Seed 1 vs Seed 2                    │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '┌─ MATCH 2 (Losers Final) ─────────────┐\n';
        preview += '│  Loser M1 vs BYE                     │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │\n';
        preview += '            ▼\n';
        preview += '┌─ MATCH 3 (Grand Final) ──────────────┐\n';
        preview += '│  Winner M1 vs Winner M2              │\n';
        preview += '└──────────────────────────────────────┘\n';
      } else if (teamCount == 3) {
        preview += '┌─ MATCH 1 (Winners R1) ───────────────┐\n';
        preview += '│  Seed 2 vs Seed 3                    │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '┌─ MATCH 2 (Winners Final) ────────────┐\n';
        preview += '│  Seed 1 vs Winner M1                 │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '            │     ┌─ MATCH 3 (Losers Final) ─┐\n';
        preview += '            │     │  Loser M1 vs Loser M2    │\n';
        preview += '            │     └───────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            └───────┬──────┘\n';
        preview += '                    ▼\n';
        preview += '┌─ MATCH 4 (Grand Final) ──────────────┐\n';
        preview += '│  Winner M2 vs Winner M3              │\n';
        preview += '└──────────────────────────────────────┘\n';
      } else if (teamCount == 4) {
        preview += '┌─ MATCH 1 (Winners SF1) ──────────────┐\n';
        preview += '│  Seed 1 vs Seed 4                    │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '┌─ MATCH 2 (Winners SF2) ──────────────┐\n';
        preview += '│  Seed 2 vs Seed 3                    │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '┌─ MATCH 3 (Winners Final) ────────────┐\n';
        preview += '│  Winner M1 vs Winner M2              │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '            │     ┌─ MATCH 4 (Losers SF) ───┐\n';
        preview += '            │     │  Loser M1 vs Loser M2   │\n';
        preview += '            │     └──────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            │              ▼\n';
        preview += '            │     ┌─ MATCH 5 (Losers Final) ─┐\n';
        preview += '            │     │  Winner M4 vs Loser M3   │\n';
        preview += '            │     └───────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            └───────┬──────┘\n';
        preview += '                    ▼\n';
        preview += '┌─ MATCH 6 (Grand Final) ──────────────┐\n';
        preview += '│  Winner M3 vs Winner M5              │\n';
        preview += '└──────────────────────────────────────┘\n';
      } else if (teamCount == 5) {
        preview += '┌─ MATCH 1 (Winners R1) ───────────────┐\n';
        preview += '│  Seed 4 vs Seed 5                    │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │\n';
        preview += '            ▼\n';
        preview += '┌─ MATCH 2 (Winners R1) ───────────────┐\n';
        preview += '│  Seed 1 vs Seed 2                    │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '┌─ MATCH 3 (Winners SF) ───────────────┐\n';
        preview += '│  Winner M1 advances                  │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │\n';
        preview += '            ▼\n';
        preview += '┌─ MATCH 4 (Winners Final) ────────────┐\n';
        preview += '│  Winner M2 vs Winner M3              │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │              │\n';
        preview += '            ▼              ▼\n';
        preview += '┌─ MATCH 5 (Losers R1) ────────────────┐\n';
        preview += '│  Loser M1 advances                   │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │\n';
        preview += '            ▼\n';
        preview += '┌─ MATCH 6 (Losers Final) ─────────────┐\n';
        preview += '│  Winner M5 vs Loser M4               │\n';
        preview += '└──────────────────────────────────────┘\n';
        preview += '            │\n';
        preview += '            ▼\n';
        preview += '┌─ MATCH 7 (GRAND FINAL) ──────────────┐\n';
        preview += '│  TEAM 3 vs Winner M6                 │\n';
        preview += '└──────────────────────────────────────┘\n';
      } else {
        preview += 'COMPLEX BRACKET STRUCTURE:\n';
        preview += '• Winners Bracket: ${teamCount - 1} matches\n';
        preview += '• Losers Bracket: ${teamCount - 1} matches\n';
        preview += '• Grand Final: 1 match\n';
        preview += '• Match numbers will be assigned sequentially\n';
        preview += '• First round matches: ${teamCount ~/ 2} matches\n';
      }

      return preview;
    }
  }

  void _generateMatchups() {
    if (_eliminationType == 'Single Elimination') {
      _generateSingleEliminationMatchups();
    } else {
      _generateDoubleEliminationMatchups();
    }
  }

  // Method to get team data with IDs
  List<Map<String, dynamic>> _getSelectedTeamsData() {
    return _allParticipants
        .where((doc) => _selectedTeamIds.contains(doc.id))
        .map<Map<String, dynamic>>((doc) => {
              'id': doc.id,
              'name': doc['name'] as String? ?? 'Unnamed',
              'type': 'team',
            })
        .toList();
  }

  // Generate single elimination matchups for ANY number of teams
  void _generateSingleEliminationMatchups() {
    List<Map<String, dynamic>> teamData = _getSelectedTeamsData();

    _matchups.clear();
    _matchRounds.clear();

    if (teamData.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'At least 2 teams are required for Single Elimination',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Create seeded order (1 is best, N is worst)
    List<Map<String, dynamic>> seededTeams = List.from(teamData);

    if (_randomize) {
      seededTeams.shuffle();
      for (int i = 0; i < seededTeams.length; i++) {
        seededTeams[i]['seed'] = i + 1;
      }
    } else {
      for (int i = 0; i < seededTeams.length; i++) {
        seededTeams[i]['seed'] = i + 1;
      }
    }

    int teamCount = seededTeams.length;

    // Use specific bracket generators for different team counts
    if (teamCount == 2) {
      _generate2TeamBracket(seededTeams);
    } else if (teamCount == 3) {
      _generate3TeamBracket(seededTeams);
    } else if (teamCount == 4) {
      _generate4TeamBracket(seededTeams);
    } else if (teamCount == 5) {
      _generate5TeamBracket(seededTeams);
    } else if (teamCount == 6) {
      _generate6TeamBracket(seededTeams);
    } else if (teamCount == 7) {
      _generate7TeamBracket(seededTeams);
    } else if (teamCount == 8) {
      _generate8TeamBracket(seededTeams);
    } else {
      // For other team counts, use the generic bracket generator
      _generateGenericBracket(seededTeams);
    }

    _linkMatchReferences();

    for (var match in _matchups) {
    }
  }

  // Generate 2-team bracket (1 match)
  void _generate2TeamBracket(List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;
    int roundNumber = 1;

    // Final: Seed 1 vs Seed 2
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[0], // Seed 1
      seededTeams[1], // Seed 2
      '${seededTeams[0]['name']} (Seed 1)',
      '${seededTeams[1]['name']} (Seed 2)',
      null, // No next match
    );
  }

  // Generate 3-team bracket (2 matches)
  void _generate3TeamBracket(List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;
    int roundNumber = 1;

    // Round 1: Seed 2 vs Seed 3
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[1], // Seed 2
      seededTeams[2], // Seed 3
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[2]['name']} (Seed 3)',
      2, // Winner goes to Match 2
    );
    matchNumber++;

    roundNumber++;

    // Round 2 (Final): Seed 1 vs Winner M1
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[0], // Seed 1
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
      },
      '${seededTeams[0]['name']} (Seed 1)',
      'Winner Match 1',
      null, // Final match
    );
  }

  // Generate 4-team bracket (3 matches)
  void _generate4TeamBracket(List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;
    int roundNumber = 1;

    // Round 1: Match 1 (Seed 1 vs Seed 4)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[0], // Seed 1
      seededTeams[3], // Seed 4
      '${seededTeams[0]['name']} (Seed 1)',
      '${seededTeams[3]['name']} (Seed 4)',
      3, // Winner goes to Match 3
    );
    matchNumber++;

    // Round 1: Match 2 (Seed 2 vs Seed 3)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[1], // Seed 2
      seededTeams[2], // Seed 3
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[2]['name']} (Seed 3)',
      3, // Winner goes to Match 3
    );
    matchNumber++;

    roundNumber++;

    // Round 2 (Final): Match 3 (Winner M1 vs Winner M2)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
      },
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
      },
      'Winner Match 1',
      'Winner Match 2',
      null, // Final match
    );
  }

  // Generate 5-team bracket (4 matches total)
  void _generate5TeamBracket(List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;
    int roundNumber = 1;

    // Round 1: Match 1 (Seed 4 vs Seed 5)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[3], // Seed 4
      seededTeams[4], // Seed 5
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      3, // Winner goes to Match 3
    );
    matchNumber++;

    // Round 1: Match 2 (Seed 2 vs Seed 3)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[1], // Seed 2
      seededTeams[2], // Seed 3
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[2]['name']} (Seed 3)',
      4, // Winner goes to Match 4
    );
    matchNumber++;

    roundNumber++;

    // Round 2: Match 3 (Seed 1 vs Winner M1)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[0], // Seed 1
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
      },
      '${seededTeams[0]['name']} (Seed 1)',
      'Winner Match 1',
      4, // Winner goes to Match 4 (Final)
    );
    matchNumber++;

    roundNumber++;

    // Round 3 (FINAL): Match 4 (Winner M3 vs Winner M2)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
      },
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
      },
      'Winner Match 3',
      'Winner Match 2',
      null, // Final match
    );
  }

  // Generate 6-team bracket (5 matches total)
  void _generate6TeamBracket(List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;
    int roundNumber = 1;

    // Round 1: Match 1 (Seed 3 vs Seed 6)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[2], // Seed 3
      seededTeams[5], // Seed 6
      '${seededTeams[2]['name']} (Seed 3)',
      '${seededTeams[5]['name']} (Seed 6)',
      3, // Winner goes to Match 3
    );
    matchNumber++;

    // Round 1: Match 2 (Seed 4 vs Seed 5)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[3], // Seed 4
      seededTeams[4], // Seed 5
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      4, // Winner goes to Match 4
    );
    matchNumber++;

    roundNumber++;

    // Round 2: Match 3 (Seed 1 vs Winner M1)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[0], // Seed 1
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
      },
      '${seededTeams[0]['name']} (Seed 1)',
      'Winner Match 1',
      5, // Winner goes to Match 5 (Final)
    );
    matchNumber++;

    // Round 2: Match 4 (Seed 2 vs Winner M2)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[1], // Seed 2
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
      },
      '${seededTeams[1]['name']} (Seed 2)',
      'Winner Match 2',
      5, // Winner goes to Match 5 (Final)
    );
    matchNumber++;

    roundNumber++;

    // Round 3 (FINAL): Match 5 (Winner M3 vs Winner M4)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
      },
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4,
      },
      'Winner Match 3',
      'Winner Match 4',
      null, // Final match
    );
  }

  // Generate 7-team bracket (6 matches total)
  void _generate7TeamBracket(List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;
    int roundNumber = 1;

    // Round 1: Match 1 (Seed 2 vs Seed 7)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[1], // Seed 2
      seededTeams[6], // Seed 7
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[6]['name']} (Seed 7)',
      4, // Winner goes to Match 4
    );
    matchNumber++;

    // Round 1: Match 2 (Seed 3 vs Seed 6)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[2], // Seed 3
      seededTeams[5], // Seed 6
      '${seededTeams[2]['name']} (Seed 3)',
      '${seededTeams[5]['name']} (Seed 6)',
      5, // Winner goes to Match 5
    );
    matchNumber++;

    // Round 1: Match 3 (Seed 4 vs Seed 5)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[3], // Seed 4
      seededTeams[4], // Seed 5
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      5, // Winner goes to Match 5
    );
    matchNumber++;

    roundNumber++;

    // Round 2: Match 4 (Seed 1 vs Winner M1)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[0], // Seed 1
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
      },
      '${seededTeams[0]['name']} (Seed 1)',
      'Winner Match 1',
      6, // Winner goes to Match 6 (Final)
    );
    matchNumber++;

    // Round 2: Match 5 (Winner M2 vs Winner M3)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
      },
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
      },
      'Winner Match 2',
      'Winner Match 3',
      6, // Winner goes to Match 6 (Final)
    );
    matchNumber++;

    roundNumber++;

    // Round 3 (FINAL): Match 6 (Winner M4 vs Winner M5)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4,
      },
      {
        'id': 'match_5_winner',
        'name': 'Winner Match 5',
        'type': 'placeholder',
        'sourceMatch': 5,
      },
      'Winner Match 4',
      'Winner Match 5',
      null, // Final match
    );
  }

  // Generate 8-team bracket (7 matches total)
  void _generate8TeamBracket(List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;
    int roundNumber = 1;

    // Round 1 (Quarterfinals): Match 1 (Seed 1 vs Seed 8)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[0], // Seed 1
      seededTeams[7], // Seed 8
      '${seededTeams[0]['name']} (Seed 1)',
      '${seededTeams[7]['name']} (Seed 8)',
      5, // Winner goes to Match 5
    );
    matchNumber++;

    // Round 1 (Quarterfinals): Match 2 (Seed 4 vs Seed 5)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[3], // Seed 4
      seededTeams[4], // Seed 5
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      5, // Winner goes to Match 5
    );
    matchNumber++;

    // Round 1 (Quarterfinals): Match 3 (Seed 2 vs Seed 7)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[1], // Seed 2
      seededTeams[6], // Seed 7
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[6]['name']} (Seed 7)',
      6, // Winner goes to Match 6
    );
    matchNumber++;

    // Round 1 (Quarterfinals): Match 4 (Seed 3 vs Seed 6)
    _createMatch(
      matchNumber,
      roundNumber,
      seededTeams[2], // Seed 3
      seededTeams[5], // Seed 6
      '${seededTeams[2]['name']} (Seed 3)',
      '${seededTeams[5]['name']} (Seed 6)',
      6, // Winner goes to Match 6
    );
    matchNumber++;

    roundNumber++;

    // Round 2 (Semifinals): Match 5 (Winner M1 vs Winner M2)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
      },
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
      },
      'Winner Match 1',
      'Winner Match 2',
      7, // Winner goes to Match 7 (Final)
    );
    matchNumber++;

    // Round 2 (Semifinals): Match 6 (Winner M3 vs Winner M4)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
      },
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4,
      },
      'Winner Match 3',
      'Winner Match 4',
      7, // Winner goes to Match 7 (Final)
    );
    matchNumber++;

    roundNumber++;

    // Round 3 (FINAL): Match 7 (Winner M5 vs Winner M6)
    _createMatch(
      matchNumber,
      roundNumber,
      {
        'id': 'match_5_winner',
        'name': 'Winner Match 5',
        'type': 'placeholder',
        'sourceMatch': 5,
      },
      {
        'id': 'match_6_winner',
        'name': 'Winner Match 6',
        'type': 'placeholder',
        'sourceMatch': 6,
      },
      'Winner Match 5',
      'Winner Match 6',
      null, // Final match
    );
  }

  // Generic bracket generator for other team counts (9+ teams)
  void _generateGenericBracket(List<Map<String, dynamic>> seededTeams) {
    int teamCount = seededTeams.length;

    // Calculate bracket structure
    int rounds = (teamCount - 1).bitLength;
    int bracketSize = 1 << rounds;

    List<Map<String, dynamic>?> bracket = List.filled(bracketSize, null);
    _placeSeedsInBracket(bracket, seededTeams, 0, bracketSize - 1, 0);

    int matchNumber = 1;
    int roundNumber = 1;
    List<Map<String, dynamic>?> currentRound = bracket;

    // Track match numbers for each round to set nextMatchReference
    Map<int, int> firstMatchInRound = {};

    while (currentRound.length > 1) {
      List<Map<String, dynamic>?> nextRound = [];
      int matchesInRound = currentRound.length ~/ 2;

      // Store the first match number of this round
      firstMatchInRound[roundNumber] = matchNumber;

      for (int i = 0; i < matchesInRound; i++) {
        int team1Index = i * 2;
        int team2Index = i * 2 + 1;

        Map<String, dynamic>? team1 = currentRound[team1Index];
        Map<String, dynamic>? team2 = currentRound[team2Index];

        // Skip if both are null
        if (team1 == null && team2 == null) {
          nextRound.add(null);
          continue;
        }

        // Handle BYEs - team advances without a match
        if (team1 == null) {
          nextRound.add(team2);
          continue;
        }

        if (team2 == null) {
          nextRound.add(team1);
          continue;
        }

        // Both teams exist - create regular match
        String team1Name = _getTeamName(team1);
        String team2Name = _getTeamName(team2);

        // Calculate next match reference
        int? nextMatchRef;
        if (currentRound.length > 2) {
          // Winner goes to next round, position i ~/ 2
          int nextRoundMatchIndex = i ~/ 2;
          // Next match number will be firstMatchInNextRound + nextRoundMatchIndex
          int nextRoundFirstMatch =
              matchNumber + (matchesInRound - i ~/ 2) + (nextRoundMatchIndex);
          nextMatchRef = nextRoundFirstMatch;
        }

        _createMatch(
          matchNumber,
          roundNumber,
          team1,
          team2,
          team1Name,
          team2Name,
          nextMatchRef,
        );

        // Add placeholder for winner
        nextRound.add({
          'id': 'match_${matchNumber}_winner',
          'name': 'Winner Match $matchNumber',
          'type': 'placeholder',
          'sourceMatch': matchNumber,
        });

        matchNumber++;
      }

      // Remove null entries from next round
      currentRound = nextRound.where((m) => m != null).toList();
      roundNumber++;
    }
  }

  // Helper method to create a match
  void _createMatch(int matchNumber, int round, dynamic team1, dynamic team2,
      String team1Name, String team2Name, int? nextMatchReference) {
    Map<String, dynamic> match = {
      'matchNumber': matchNumber,
      'round': round,
      'team1': team1,
      'team2': team2,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'type': 'regular',
      'nextMatchReference': nextMatchReference,
      'winner': null,
      'loser': null,
      'status': 'scheduled',
    };

    _matchups.add(match);
    _matchRounds.add(round);
  }

  // Helper method to place seeds in bracket using standard algorithm
  void _placeSeedsInBracket(List<Map<String, dynamic>?> bracket,
      List<Map<String, dynamic>> seeds, int left, int right, int seedIndex) {
    if (left > right || seedIndex >= seeds.length) return;

    if (left == right) {
      bracket[left] = seeds[seedIndex];
      return;
    }

    int mid = (left + right) ~/ 2;

    // Place seed at current position
    bracket[left] = seeds[seedIndex];

    // Place next seed at the end
    if (seedIndex + 1 < seeds.length) {
      bracket[right] = seeds[seedIndex + 1];
    }

    // Recursively fill the rest
    _placeSeedsInBracket(bracket, seeds, left + 1, mid - 1, seedIndex + 2);
    _placeSeedsInBracket(bracket, seeds, mid + 1, right - 1, seedIndex + 2);
  }

  // Helper method to get team name with seed
  String _getTeamName(Map<String, dynamic> team) {
    if (team['type'] == 'placeholder') return team['name'] ?? 'TBD';
    return '${team['name']}${team['seed'] != null ? ' (Seed ${team['seed']})' : ''}';
  }

  // Link matches to their next round references
  void _linkMatchReferences() {
    Map<int, List<Map<String, dynamic>>> matchesByRound = {};
    for (var match in _matchups) {
      int round = match['round'] as int;
      if (!matchesByRound.containsKey(round)) {
        matchesByRound[round] = [];
      }
      matchesByRound[round]!.add(match);
    }

    for (int round = 1; round < matchesByRound.length; round++) {
      List<Map<String, dynamic>> currentRoundMatches =
          matchesByRound[round] ?? [];
      List<Map<String, dynamic>> nextRoundMatches =
          matchesByRound[round + 1] ?? [];

      for (int i = 0; i < currentRoundMatches.length; i++) {
        if (i < nextRoundMatches.length) {
          int targetMatchIndex = i ~/ 2;
          if (targetMatchIndex < nextRoundMatches.length) {
            currentRoundMatches[i]['nextMatchReference'] =
                nextRoundMatches[targetMatchIndex]['matchNumber'] as int;
          }
        }
      }
    }
  }

  void _generateDoubleEliminationMatchups() {
    List<Map<String, dynamic>> teamData = _getSelectedTeamsData();

    _matchups.clear();
    _matchRounds.clear();

    final generatedMatchups =
        _doubleElimGenerator.generateDoubleEliminationMatchups(
      teamData,
      _randomize,
      context,
    );

    if (generatedMatchups.isNotEmpty) {
      _matchups.addAll(generatedMatchups);
      for (var match in _matchups) {
        _matchRounds.add(match['round'] ?? 1);
      }
    }
  }

// Add this method to resolve team data properly
  Map<String, dynamic> _resolveTeamData(
      dynamic team, Map<String, dynamic> matchData) {
    // If it's a placeholder (from double elimination)
    if (team is Map && team['type'] == 'placeholder') {
      String teamName = team['name'] ?? 'TBD';
      String teamId = team['id'] ?? 'tbd';
      bool isLoser = team['isLoser'] == true;
      int? sourceMatch = team['sourceMatch'];

      // Create a readable representation
      return {
        'id': teamId,
        'name': teamName,
        'type': 'placeholder',
        'sourceMatch': sourceMatch,
        'isLoser': isLoser,
        'displayName': teamName,
        'isPlaceholder': true,
      };
    }

    // If it's a BYE case
    if (team == null) {
      return {
        'id': 'bye',
        'name': 'BYE',
        'type': 'bye',
        'displayName': 'BYE',
        'isBye': true,
      };
    }

    // If it's a real team with ID
    if (team is Map && team['id'] != null && team['id'] != 'tbd') {
      String seedText = team['seed'] != null ? ' (Seed ${team['seed']})' : '';
      return {
        'id': team['id'],
        'name': team['name'] ?? 'Unknown',
        'type': 'team',
        'seed': team['seed'],
        'displayName': '${team['name'] ?? 'Unknown'}$seedText',
      };
    }

    // If it's a map but might be from the generator
    if (team is Map) {
      return {
        'id': team['id'] ?? 'tbd',
        'name': team['name'] ?? 'TBD',
        'type': team['type'] ?? 'unknown',
        'seed': team['seed'],
        'displayName': team['name'] ?? 'TBD',
      };
    }

    // Default fallback
    return {
      'id': 'tbd',
      'name': 'TBD',
      'type': 'unknown',
      'displayName': 'TBD',
    };
  }

  Future<void> _assignSchedules() async {
    try {

      int schedulesNeeded = _matchups.length;

      if (_selectedScheduleIds.length < schedulesNeeded) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Select at least $schedulesNeeded schedules to cover all matches')));
        return;
      }

      final isEditing = widget.existingTournament != null;

      // Prepare tournament data
      final tournamentData = {
        'id': _tournamentSetupId,
        'name': _tournamentName.isNotEmpty
            ? _tournamentName
            : (widget.existingTournament?['name'] ??
                'Tournament ${_tournamentSetupId}'),
        'status': 'active',
        'category': _selectedCategory,
        'sport': _selectedSport,
        'gender': _selectedGender,
        'venue': _isCustomVenue
            ? _customVenueController.text.trim()
            : _selectedVenue,
        'eliminationType': _eliminationType,
        'verificationField': _verificationField,
        'selectedTeamIds': _selectedTeamIds,
        'selectedScheduleIds': _selectedScheduleIds,
        'randomize': _randomize,
        'assignedUsers': _selectedUserIds,
        'totalMatches': _matchups.length,
        'bracketType':
            _eliminationType == 'Single Elimination' ? 'single' : 'double',
        'updatedAt': DateTime.now(),
      };

      if (!isEditing) {
        tournamentData['createdAt'] = DateTime.now();
      }


      // Sort schedules by date/time
      List<String> sortedScheduleIds = List.from(_selectedScheduleIds);
      sortedScheduleIds.sort((a, b) {
        final scheduleA = _availableSchedules.firstWhere((s) => s['id'] == a,
            orElse: () => {});
        final scheduleB = _availableSchedules.firstWhere((s) => s['id'] == b,
            orElse: () => {});

        final dateTimeA = DateTime.tryParse(
            scheduleA['dateTime'] ?? scheduleA['startTime'] ?? '');
        final dateTimeB = DateTime.tryParse(
            scheduleB['dateTime'] ?? scheduleB['startTime'] ?? '');

        if (dateTimeA != null && dateTimeB != null) {
          return dateTimeA.compareTo(dateTimeB);
        } else if (dateTimeA != null) {
          return -1;
        } else if (dateTimeB != null) {
          return 1;
        }
        return 0;
      });

      List<Map<String, dynamic>> batchSchedules = [];

      // Create match schedules
      for (int i = 0; i < _matchups.length; i++) {
        // Make sure we don't go out of bounds
        if (i >= sortedScheduleIds.length) {
          break;
        }

        final scheduleId = sortedScheduleIds[i];
        final schedule = _availableSchedules
            .firstWhere((s) => s['id'] == scheduleId, orElse: () => {});
        final matchData = _matchups[i];
        final matchId = 'match_${DateTime.now().millisecondsSinceEpoch}_$i';

        String readableStartDateTime;
        final startTimeValue = schedule['startTime'] ?? schedule['dateTime'];
        if (startTimeValue != null) {
          final dateTime = DateTime.tryParse(startTimeValue.toString());
          if (dateTime != null) {
            readableStartDateTime =
                '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
          } else {
            readableStartDateTime = startTimeValue.toString();
          }
        } else {
          final now = DateTime.now();
          readableStartDateTime =
              '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        }

        String? readableEndDateTime;
        final endTimeValue = schedule['endTime'];
        if (endTimeValue != null) {
          final dateTime = DateTime.tryParse(endTimeValue.toString());
          if (dateTime != null) {
            readableEndDateTime =
                '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
          } else {
            readableEndDateTime = endTimeValue.toString();
          }
        }

        // RESOLVE TEAM DATA PROPERLY
        Map<String, dynamic> team1 = {};
        Map<String, dynamic> team2 = {};
        String team1Name = 'TBD';
        String team2Name = 'TBD';
        String team1Id = 'tbd';
        String team2Id = 'tbd';

        // Handle team1 - resolve placeholder if needed
        if (matchData['team1'] != null) {
          team1 = _resolveTeamData(matchData['team1'], matchData);
          team1Name = team1['displayName'] ?? team1['name'] ?? 'TBD';
          team1Id = team1['id'] ?? 'tbd';
        } else if (matchData['team1Name'] != null) {
          team1Name = matchData['team1Name'];
          team1 = {
            'id': 'tbd',
            'name': team1Name,
            'displayName': team1Name,
            'type': 'unknown'
          };
        }

        // Handle team2 - resolve placeholder if needed
        if (matchData['team2'] != null) {
          team2 = _resolveTeamData(matchData['team2'], matchData);
          team2Name = team2['displayName'] ?? team2['name'] ?? 'TBD';
          team2Id = team2['id'] ?? 'tbd';

          // Special handling for BYE
          if (team2['isBye'] == true) {
            team2Name = 'BYE';
            team2Id = 'bye';
          }
        } else if (matchData['team2Name'] != null) {
          team2Name = matchData['team2Name'];
          team2 = {
            'id': 'tbd',
            'name': team2Name,
            'displayName': team2Name,
            'type': 'unknown'
          };
        }

        // Ensure BYE is properly represented
        if (team2Name == 'BYE' ||
            (team2.isEmpty && matchData['team2'] == null)) {
          team2 = {
            'id': 'bye',
            'name': 'BYE',
            'type': 'bye',
            'displayName': 'BYE',
            'isBye': true,
          };
          team2Id = 'bye';
          team2Name = 'BYE';
        }

        // Create the match schedule with all resolved data
        final matchSchedule = {
          'id': matchId,
          'matchNumber': matchData['matchNumber'],
          'round': matchData['round'],
          'bracket': matchData['bracket'] ??
              (_eliminationType == 'Single Elimination' ? 'single' : 'double'),
          'dateTime': readableStartDateTime,
          'startTime': readableStartDateTime,
          if (readableEndDateTime != null) 'endTime': readableEndDateTime,
          'tournamentSetupId': _tournamentSetupId,
          'tournamentName': tournamentData['name'],
          'team1': team1,
          'team2': team2,
          'team1Id': team1Id,
          'team2Id': team2Id,
          'team1Name': team1Name,
          'team2Name': team2Name,
          'team1DisplayName': team1['displayName'] ?? team1Name,
          'team2DisplayName': team2['displayName'] ?? team2Name,
          'sport': _selectedSport,
          'category': _selectedCategory,
          'gender': _selectedGender,
          'venue': _isCustomVenue
              ? _customVenueController.text.trim()
              : _selectedVenue,
          'nextMatchReference': matchData['nextMatchReference'],
          'losersNextMatchReference': matchData['losersNextMatchReference'],
          'matchType': matchData['type'] ?? 'regular',
          'status': 'scheduled',
          'winner': null,
          'loser': null,
          'originalScheduleId': scheduleId,
          // Add metadata for better understanding
          'isPlaceholderMatch':
              team1['isPlaceholder'] == true || team2['isPlaceholder'] == true,
          'hasBye': team2['isBye'] == true,
          'isGrandFinal': matchData['isGrandFinal'] ?? false,
        };

        batchSchedules.add(matchSchedule);
      }

      // Add matchups to tournament data
      tournamentData['matchups'] = batchSchedules;

      // Save tournament to Firestore

      if (isEditing) {
        await _tournamentService.updateTournament(
            _tournamentSetupId, tournamentData);
      } else {
        tournamentData['createdAt'] = DateTime.now();
        await _tournamentService.addTournament(tournamentData);
      }

      // Save match schedules
      await _teamScheduleService.createMultipleTeamSchedules(batchSchedules);

      // Update schedule occupied status
      await _matchScheduleService.updateMultipleSchedulesOccupiedStatus(
          _selectedScheduleIds, true);

    } catch (e) {
      rethrow; // Rethrow so the calling method can handle it
    }
  }

  Future<void> _showAddScheduleDialog() async {
    DateTime? selectedDateTime;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add New Schedule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
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
                    child: const Text('Select Date & Time'),
                  ),
                  if (selectedDateTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                          'Selected: ${_displayDateFormat.format(selectedDateTime!)}'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedDateTime != null) {
                      final existingSchedules = await FirebaseFirestore.instance
                          .collection('match_schedule')
                          .where('dateTime',
                              isEqualTo: selectedDateTime!.toIso8601String())
                          .get();
                      if (existingSchedules.docs.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'A schedule with this date and time already exists.')),
                        );
                        return;
                      }

                      final formattedDateTime =
                          '${selectedDateTime!.day}/${selectedDateTime!.month}/${selectedDateTime!.year} ${selectedDateTime!.hour.toString().padLeft(2, '0')}:${selectedDateTime!.minute.toString().padLeft(2, '0')}';
                      if (_usedDateTimes.contains(formattedDateTime)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'A schedule with this date and time is already used by another sport.')),
                        );
                        return;
                      }

                      await _matchScheduleService.createMatchSchedule({
                        'dateTime': selectedDateTime!.toIso8601String(),
                        'id': DateTime.now().millisecondsSinceEpoch.toString(),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditScheduleDialog(Map<String, dynamic> schedule) async {
    DateTime? selectedDateTime = DateTime.tryParse(schedule['dateTime'] ?? '');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Schedule'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDateTime ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
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
                    child: const Text('Select Date & Time'),
                  ),
                  if (selectedDateTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                          'Selected: ${_displayDateFormat.format(selectedDateTime!)}'),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedDateTime != null) {
                      await _matchScheduleService
                          .updateMatchSchedule(schedule['id'], {
                        'dateTime': selectedDateTime!.toIso8601String(),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text(
            'Are you sure you want to delete this schedule? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _matchScheduleService.deleteMatchSchedule(scheduleId);
      setState(() {
        _selectedScheduleIds.remove(scheduleId);
        _saveState();
      });
    }
  }

  void _onStepContinue() async {
    void showValidationSnackBar(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.close, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    if (_currentStep == 0) {
      if (_tournamentName.isEmpty) {
        showValidationSnackBar('Please enter a tournament name');
        return;
      }
      setState(() {
        _currentStep++;
        _saveState();
      });
    } else if (_currentStep == 1) {
      if (_selectedCategory == null) {
        showValidationSnackBar('Please select a category');
        return;
      }
      await _fetchSportsForCategory(_selectedCategory!);
      setState(() {
        _currentStep++;
        _selectedSport = null;
        _saveState();
      });
    } else if (_currentStep == 2) {
      if (_selectedSport == null) {
        showValidationSnackBar('Please select a sport');
        return;
      }
      await _fetchParticipantsForSport(_selectedSport!);
      await _fetchVenuesForSport(_selectedSport!); // <-- Add 'await' here
      setState(() {
        _currentStep++;
        _selectedTeamIds.clear();
        _saveState();
      });
    } else if (_currentStep == 3) {
      if (_selectedTeamIds.isEmpty) {
        showValidationSnackBar('Please select at least one team');
        return;
      }
      setState(() {
        _currentStep++;
        _saveState();
      });
    } else if (_currentStep == 4) {
      setState(() {
        _currentStep++;
        _saveState();
      });
    } else if (_currentStep == 5) {
      if (_isCustomVenue && _customVenueController.text.trim().isEmpty) {
        showValidationSnackBar('Please enter a custom venue');
        return;
      }
      setState(() {
        _currentStep++;
        _saveState();
      });
    } else if (_currentStep == 6) {
      setState(() {
        _currentStep++;
        _saveState();
      });
    } else if (_currentStep == 7) {
      int schedulesNeeded = _matchups.isNotEmpty
          ? _matchups.length
          : _getRequiredSchedulesCount();
      if (_selectedScheduleIds.length < schedulesNeeded) {
        showValidationSnackBar(
            'Please select at least $schedulesNeeded schedule${schedulesNeeded == 1 ? '' : 's'}');
        return;
      }
      setState(() {
        _currentStep++;
        _saveState();
      });
    } else if (_currentStep == 8) {
      setState(() {
        _currentStep++;
        _saveState();
      });
    } else if (_currentStep == 9) {

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      try {
        _generateMatchups();


        if (_matchups.isEmpty) {
          // Close loading dialog
          Navigator.of(context).pop();
          showValidationSnackBar(
              'Failed to generate matchups. Please check your team selection.');
          return;
        }

        await _assignSchedules();

        // Close loading dialog
        Navigator.of(context).pop();


        // Reset the form but DON'T increment _currentStep
        setState(() {
          _currentStep = 0; // Reset to first step
          _selectedCategory = null;
          _selectedSport = null;
          _selectedTeamIds.clear();
          _selectedScheduleIds.clear();
          _selectedUserIds.clear();
          _matchups.clear();
          _saveState();
        });
        _clearState();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 12),
                Text('Tournament created successfully!'),
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
      } catch (e) {
        // Close loading dialog if error occurs
        Navigator.of(context).pop();
        showValidationSnackBar('Error creating tournament: $e');
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _saveState();
      });
    }
  }

  Widget _buildRequirementRow(String label, String value, Color color,
      {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.deepOrange.shade600,
          ),
        ),
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          onStepContinue: _onStepContinue,
          onStepCancel: _onStepCancel,
          onStepTapped: (step) {
            setState(() => _currentStep = step);
            if (step == 0) {
              _fetchCategories();
            }
          },
          steps: [
            Step(
              title: const Text('Tournament Name'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _tournamentNameController,
                    decoration: InputDecoration(
                      labelText: 'Enter Tournament Name',
                      hintText: 'e.g., Summer Championship',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _tournamentName = value.trim();
                        _saveState();
                      });
                    },
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('Select Category'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((cat) =>
                            DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selectedCategory = val;
                      _saveState();
                    }),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('Select Sport'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<String>(
                    value: _selectedSport,
                    items: _sports
                        .map((sport) =>
                            DropdownMenuItem(value: sport, child: Text(sport)))
                        .toList(),
                    onChanged: (val) => setState(() {
                      _selectedSport = val;
                      _saveState();
                      _updateAvailableSchedules();
                    }),
                    decoration: InputDecoration(
                      labelText: 'Sport',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('Select Teams'),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: _allParticipants.isEmpty
                  ? const Text('No teams available for this sport')
                  : Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: SizedBox(
                        height: 240,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  labelText: 'Search Teams',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: ListView(
                                  padding: const EdgeInsets.all(8),
                                  children: _filteredParticipants.map((doc) {
                                    final teamName = doc['name'] ?? 'Unnamed';
                                    final teamId = doc.id;
                                    final selected =
                                        _selectedTeamIds.contains(teamId);
                                    return CheckboxListTile(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      tileColor: selected
                                          ? Colors.deepOrange.shade50
                                          : Colors.grey.shade100,
                                      title: Text(teamName),
                                      value: selected,
                                      onChanged: (bool? val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedTeamIds.add(teamId);
                                          } else {
                                            _selectedTeamIds.remove(teamId);
                                          }
                                          _saveState();
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Step(
              title: const Text('Select Gender'),
              isActive: _currentStep >= 4,
              state: _currentStep > 4 ? StepState.complete : StepState.indexed,
              content: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        title: const Text('Women'),
                        value: 'Women',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                            _saveState();
                          });
                        },
                        activeColor: Colors.deepOrange,
                      ),
                      RadioListTile<String>(
                        title: const Text('Men'),
                        value: 'Men',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                            _saveState();
                          });
                        },
                        activeColor: Colors.deepOrange,
                      ),
                      RadioListTile<String>(
                        title: const Text('Girls'),
                        value: 'Girls',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                            _saveState();
                          });
                        },
                        activeColor: Colors.deepOrange,
                      ),
                      RadioListTile<String>(
                        title: const Text('Boys'),
                        value: 'Boys',
                        groupValue: _selectedGender,
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                            _saveState();
                          });
                        },
                        activeColor: Colors.deepOrange,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('Select Venue'),
              isActive: _currentStep >= 5,
              state: _currentStep > 5 ? StepState.complete : StepState.indexed,
              content: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_selectedSport == null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.orange.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Please select a sport first to see available venues.',
                                  style: TextStyle(color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (_availableVenues.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline,
                                  color: Colors.blue.shade700),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'No venues found. You can add venues in Venue Management or use custom venue option.',
                                  style: TextStyle(color: Colors.blue),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._availableVenues.map((venueDoc) {
                          final venueData =
                              venueDoc.data() as Map<String, dynamic>;
                          final venueName =
                              venueData['name'] as String? ?? 'Unnamed Venue';
                          return RadioListTile<String>(
                            title: Text(venueName),
                            value: venueName,
                            groupValue: _isCustomVenue ? null : _selectedVenue,
                            onChanged: (value) {
                              setState(() {
                                _selectedVenue = value!;
                                _isCustomVenue = false;
                                _saveState();
                              });
                            },
                            activeColor: Colors.deepOrange,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      const Divider(),
                      RadioListTile<String>(
                        title: const Text('Custom Venue'),
                        value: 'Custom',
                        groupValue: _isCustomVenue ? 'Custom' : null,
                        onChanged: (value) {
                          setState(() {
                            _isCustomVenue = true;
                            _saveState();
                          });
                        },
                        activeColor: Colors.deepOrange,
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (_isCustomVenue)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextField(
                            controller: _customVenueController,
                            decoration: InputDecoration(
                              labelText: 'Enter Custom Venue',
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              _saveState();
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('Elimination & Randomize'),
              isActive: _currentStep >= 6,
              state: _currentStep > 6 ? StepState.complete : StepState.indexed,
              content: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        value: _eliminationType,
                        items: ['Single Elimination', 'Double Elimination']
                            .map((type) => DropdownMenuItem(
                                value: type, child: Text(type)))
                            .toList(),
                        onChanged: (val) => setState(() {
                          _eliminationType = val ?? 'Single Elimination';
                          _saveState();
                        }),
                        decoration: InputDecoration(
                          labelText: 'Elimination Type',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Randomize Seeds'),
                          Switch(
                            value: _randomize,
                            onChanged: (val) {
                              setState(() {
                                _randomize = val;
                                _saveState();
                              });
                            },
                            activeColor: Colors.deepOrange,
                          ),
                        ],
                      ),
                      if (_randomize)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.shuffle,
                                    color: Colors.blue, size: 16),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Teams will be randomly seeded. Top seeds get byes.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Step(
              title: const Text('Select Schedules'),
              isActive: _currentStep >= 7,
              state: _currentStep > 7 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: Colors.deepOrange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline,
                                      color: Colors.deepOrange.shade700,
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Schedule Requirements',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.deepOrange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildRequirementRow(
                                'Teams Selected:',
                                '${_selectedTeamIds.length}',
                                Colors.deepOrange.shade700,
                              ),
                              const SizedBox(height: 8),
                              _buildRequirementRow(
                                'Elimination Type:',
                                _eliminationType,
                                Colors.deepOrange.shade700,
                              ),
                              const SizedBox(height: 8),
                              _buildRequirementRow(
                                'Bracket Size:',
                                '${_getBracketSize()}',
                                Colors.deepOrange.shade700,
                              ),
                              const SizedBox(height: 8),
                              _buildRequirementRow(
                                'Schedules Required:',
                                '${_getRequiredSchedulesCount()}',
                                Colors.deepOrange.shade700,
                                isBold: true,
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _selectedScheduleIds.length >=
                                          _getRequiredSchedulesCount()
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _selectedScheduleIds.length >=
                                            _getRequiredSchedulesCount()
                                        ? Colors.green.shade200
                                        : Colors.orange.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Selected:',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: _selectedScheduleIds
                                                        .length >=
                                                    _getRequiredSchedulesCount()
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                        Text(
                                          '${_selectedScheduleIds.length} / ${_getRequiredSchedulesCount()}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _selectedScheduleIds
                                                        .length >=
                                                    _getRequiredSchedulesCount()
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_selectedScheduleIds.length <
                                        _getRequiredSchedulesCount())
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: LinearProgressIndicator(
                                          value: _selectedScheduleIds.length /
                                              _getRequiredSchedulesCount(),
                                          backgroundColor:
                                              Colors.orange.shade100,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.orange.shade700),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_selectedTeamIds.isNotEmpty)
                          Card(
                            color: Colors.blue.shade50,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.blue.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.account_tree,
                                          color: Colors.blue.shade700,
                                          size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Bracket Preview',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _getBracketPreview(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade700,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Card(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    child: SizedBox(
                      height: 300,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton.icon(
                              onPressed: () => showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Container(
                                    width:
                                        MediaQuery.of(context).size.width * 0.9,
                                    height: MediaQuery.of(context).size.height *
                                        0.9,
                                    child: const SchedulesManagementScreen(),
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add New Schedule'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepOrange.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: _availableSchedules.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.event_busy,
                                            size: 48, color: Colors.grey),
                                        SizedBox(height: 8),
                                        Text(
                                          'No schedules available.',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : Scrollbar(
                                    thumbVisibility: true,
                                    child: ListView(
                                      padding: const EdgeInsets.all(8),
                                      children:
                                          _availableSchedules.map((schedule) {
                                        final scheduleId =
                                            schedule['id'] as String? ?? '';
                                        final startTimeStr =
                                            schedule['startTime'] as String? ??
                                                schedule['dateTime']
                                                    as String? ??
                                                '';
                                        final endTimeStr =
                                            schedule['endTime'] as String? ??
                                                '';
                                        final selected = _selectedScheduleIds
                                            .contains(scheduleId);
                                        return CheckboxListTile(
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8)),
                                          tileColor: selected
                                              ? Colors.deepOrange.shade50
                                              : Colors.grey.shade100,
                                          title: Text(
                                            '${_formatDateTimeForDisplay(startTimeStr)}${endTimeStr.isNotEmpty ? ' - ${_formatDateTimeForDisplay(endTimeStr)}' : ''}',
                                            style:
                                                const TextStyle(fontSize: 13),
                                          ),
                                          subtitle: Text(
                                            'ID: ${scheduleId.length > 8 ? scheduleId.substring(0, 8) : scheduleId}...',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          value: selected,
                                          onChanged: (bool? val) {
                                            setState(() {
                                              if (val == true) {
                                                if (!_selectedScheduleIds
                                                    .contains(scheduleId)) {
                                                  _selectedScheduleIds
                                                      .add(scheduleId);
                                                }
                                              } else {
                                                _selectedScheduleIds
                                                    .remove(scheduleId);
                                              }
                                              _saveState();
                                            });
                                          },
                                          secondary: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.edit,
                                                    size: 20),
                                                onPressed: () =>
                                                    _showEditScheduleDialog(
                                                        schedule),
                                                tooltip: 'Edit Schedule',
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete,
                                                    size: 20,
                                                    color: Colors.red),
                                                onPressed: () =>
                                                    _deleteSchedule(scheduleId),
                                                tooltip: 'Delete Schedule',
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Assign Users'),
              isActive: _currentStep >= 8,
              state: _currentStep > 8 ? StepState.complete : StepState.indexed,
              content: _allUsers.isEmpty
                  ? const Text('No users available to assign.')
                  : Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                      child: SizedBox(
                        height: 240,
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: TextField(
                                controller: _userSearchController,
                                decoration: InputDecoration(
                                  labelText: 'Search Users',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade100,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: ListView(
                                  padding: const EdgeInsets.all(8),
                                  children: _filteredUsers.map((doc) {
                                    final userName = _userNames[doc.id] ??
                                        doc['email'] ??
                                        'Unnamed';
                                    final userId = doc.id;
                                    final selected =
                                        _selectedUserIds.contains(userId);
                                    return CheckboxListTile(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      tileColor: selected
                                          ? Colors.deepOrange.shade50
                                          : Colors.grey.shade100,
                                      title: Text(userName),
                                      subtitle: Text(
                                        'Role: ${doc['role'] ?? 'Unknown'}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                      value: selected,
                                      onChanged: (bool? val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedUserIds.add(userId);
                                          } else {
                                            _selectedUserIds.remove(userId);
                                          }
                                          _saveState();
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            Step(
              title: const Text('Generate Matchups & Complete'),
              isActive: _currentStep >= 9,
              state: _currentStep > 9 ? StepState.complete : StepState.indexed,
              content: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Review your tournament setup:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Tournament Name', _tournamentName),
                      _buildSummaryRow(
                          'Category', _selectedCategory ?? 'Not selected'),
                      _buildSummaryRow(
                          'Sport', _selectedSport ?? 'Not selected'),
                      _buildSummaryRow(
                          'Teams', '${_selectedTeamIds.length} teams selected'),
                      _buildSummaryRow('Gender', _selectedGender),
                      _buildSummaryRow(
                          'Venue',
                          _isCustomVenue
                              ? _customVenueController.text
                              : _selectedVenue ?? 'Not selected'),
                      _buildSummaryRow('Format', _eliminationType),
                      _buildSummaryRow('Schedules',
                          '${_selectedScheduleIds.length} schedules'),
                      _buildSummaryRow(
                          'Users', '${_selectedUserIds.length} users assigned'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.deepOrange.shade200),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.deepOrange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Click Continue to generate seeded bracket and create the tournament.',
                                style: TextStyle(
                                  color: Colors.deepOrange,
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
          ],
        ),
      ),
    );
  }
}
