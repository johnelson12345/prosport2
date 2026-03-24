import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

class ReportsAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Tournament Data
  List<Map<String, dynamic>> tournaments = [];
  
  // Analytics Metrics
  int totalTournaments = 0;
  int activeTournaments = 0;
  int completedTournaments = 0;
  int totalMatches = 0;
  int completedMatches = 0;
  int totalTeams = 0;
  int totalVenues = 0;
  
  // Distribution Maps
  Map<String, int> categoryDistribution = {};
  Map<String, int> sportDistribution = {};
  Map<String, int> genderDistribution = {};
  Map<String, int> bracketTypeDistribution = {};
  Map<String, int> eliminationTypeDistribution = {};
  Map<String, int> venueDistribution = {};
  Map<String, int> statusDistribution = {};
  
  // Match Statistics
  Map<String, int> matchesByBracket = {};
  Map<String, int> matchesByRound = {};
  Map<String, int> matchesByMatchType = {};
  List<Map<String, dynamic>> topScoringMatches = [];
  List<Map<String, dynamic>> closestMatches = [];
  List<Map<String, dynamic>> highestMarginMatches = [];
  
  // Tournament Timeline
  List<Map<String, dynamic>> tournamentTimeline = [];
  
  // Team Statistics
  Map<String, Map<String, dynamic>> teamStats = {};
  List<Map<String, dynamic>> topTeamsByWins = [];
  List<Map<String, dynamic>> topTeamsByScore = [];
  
  // Medal Standings
  Map<String, Map<String, dynamic>> medalStandings = {};
  
  // Date Range
  DateTime? startDate;
  DateTime? endDate;
  
  // Tournament Categories
  Set<String> uniqueCategories = {};
  Set<String> uniqueSports = {};
  Set<String> uniqueGenders = {};
  Set<String> uniqueBracketTypes = {};
  Set<String> uniqueEliminationTypes = {};
  
  // Loading state
  bool isLoading = false;
  String? errorMessage;

Future<void> loadAnalyticsData({
  DateTime? startDateFilter,
  DateTime? endDateFilter,
  String? sportFilter,
  String? categoryFilter,
}) async {
  isLoading = true;
  errorMessage = null;
  
  try {
    // Build query
    Query query = _firestore.collection('tournaments');
    
    // Apply date filters if provided
    if (startDateFilter != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDateFilter);
    }
    if (endDateFilter != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: endDateFilter);
    }
    
    final tournamentsSnapshot = await query.get();
    
    // Convert documents to maps with proper casting
    final List<Map<String, dynamic>> allTournaments = [];
    for (var doc in tournamentsSnapshot.docs) {
      // Cast data() to Map<String, dynamic>
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        final Map<String, dynamic> tournamentMap = Map<String, dynamic>.from(data);
        tournamentMap['id'] = doc.id;
        allTournaments.add(tournamentMap);
      }
    }
    
    // Apply sport filter with explicit type handling
    List<Map<String, dynamic>> filteredBySport = allTournaments;
    if (sportFilter != null && sportFilter.isNotEmpty) {
      filteredBySport = [];
      for (var tournament in allTournaments) {
        final sportValue = tournament['sport'];
        if (sportValue != null && sportValue.toString() == sportFilter) {
          filteredBySport.add(tournament);
        }
      }
    }
    
    // Apply category filter with explicit type handling
    List<Map<String, dynamic>> filteredByCategory = filteredBySport;
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      filteredByCategory = [];
      for (var tournament in filteredBySport) {
        final categoryValue = tournament['category'];
        if (categoryValue != null && categoryValue.toString() == categoryFilter) {
          filteredByCategory.add(tournament);
        }
      }
    }
    
    tournaments = filteredByCategory;
    
    await _processTournamentData();
    
  } catch (e) {
    errorMessage = 'Error loading analytics: $e';
    if (kDebugMode) {
      print(errorMessage);
    }
  } finally {
    isLoading = false;
  }
}
  Future<void> _processTournamentData() async {
    // Reset all metrics
    _resetMetrics();
    
    // Get all team IDs from tournaments
    Set<String> allTeamIds = {};
    Set<String> allVenues = {};
    
    for (var tournament in tournaments) {
      final matchupsRaw = tournament['matchups'];
      final List<dynamic> matchups = matchupsRaw is List ? matchupsRaw : [];
      final selectedTeamIdsRaw = tournament['selectedTeamIds'];
      final List<dynamic> selectedTeamIds = selectedTeamIdsRaw is List ? selectedTeamIdsRaw : [];
      
      // Add team IDs
      for (var teamId in selectedTeamIds) {
        if (teamId != null && teamId is String) {
          allTeamIds.add(teamId);
        } else if (teamId != null) {
          allTeamIds.add(teamId.toString());
        }
      }
      
      // Process matchups
      for (var match in matchups) {
        if (match == null) continue;
        
        final Map<String, dynamic> matchMap = match is Map ? Map<String, dynamic>.from(match) : {};
        
        totalMatches++;
        
        // Match status
        final status = matchMap['status'] as String? ?? 'pending';
        if (status == 'completed') {
          completedMatches++;
        }
        
        // Process scores for statistics
        final scoresRaw = matchMap['scores'];
        final Map<String, dynamic>? scores = scoresRaw is Map ? Map<String, dynamic>.from(scoresRaw) : null;
        if (scores != null && scores.isNotEmpty && status == 'completed') {
          _processMatchScores(matchMap, scores);
        }
        
        // Track bracket distribution
        final bracket = matchMap['bracket'] as String? ?? 'unknown';
        matchesByBracket[bracket] = (matchesByBracket[bracket] ?? 0) + 1;
        
        // Track round distribution
        final round = matchMap['round'] as int? ?? 0;
        final roundKey = 'Round $round';
        matchesByRound[roundKey] = (matchesByRound[roundKey] ?? 0) + 1;
        
        // Track match type distribution
        final matchType = matchMap['matchType'] as String? ?? 'regular';
        matchesByMatchType[matchType] = (matchesByMatchType[matchType] ?? 0) + 1;
        
        // Track venue
        final venue = matchMap['venue'] as String? ?? 'TBD';
        if (venue != 'TBD') {
          allVenues.add(venue);
          venueDistribution[venue] = (venueDistribution[venue] ?? 0) + 1;
        }
      }
      
      // Process tournament metadata
      final category = tournament['category'] as String? ?? 'Unknown';
      categoryDistribution[category] = (categoryDistribution[category] ?? 0) + 1;
      
      final sport = tournament['sport'] as String? ?? 'Unknown';
      sportDistribution[sport] = (sportDistribution[sport] ?? 0) + 1;
      
      final gender = tournament['gender'] as String? ?? 'Mixed';
      genderDistribution[gender] = (genderDistribution[gender] ?? 0) + 1;
      
      final bracketType = tournament['bracketType'] as String? ?? 'single';
      bracketTypeDistribution[bracketType] = (bracketTypeDistribution[bracketType] ?? 0) + 1;
      
      final eliminationType = tournament['eliminationType'] as String? ?? 'Single Elimination';
      eliminationTypeDistribution[eliminationType] = (eliminationTypeDistribution[eliminationType] ?? 0) + 1;
      
      final status = tournament['status'] as String? ?? 'active';
      statusDistribution[status] = (statusDistribution[status] ?? 0) + 1;
      
      // Tournament timeline
      final createdAtRaw = tournament['createdAt'];
      if (createdAtRaw is Timestamp) {
        tournamentTimeline.add({
          'date': createdAtRaw.toDate(),
          'tournamentName': tournament['name'] ?? tournament['tournamentName'] ?? 'Unknown',
          'sport': sport,
          'category': category,
        });
      }
      
      // Process medal standings
      final medalsRaw = tournament['medals'];
      if (medalsRaw is Map) {
        final medals = Map<String, dynamic>.from(medalsRaw);
        if (medals.isNotEmpty) {
          _processMedals(medals, tournament['name'] ?? tournament['tournamentName'] ?? 'Unknown');
        }
      }
    }
    
    // Get team details from participants collection
    await _loadTeamDetails(allTeamIds);
    
    // Calculate top teams
    _calculateTopTeams();
    
    // Sort top scoring matches
    topScoringMatches.sort((a, b) => (b['totalScore'] ?? 0).compareTo(a['totalScore'] ?? 0));
    topScoringMatches = topScoringMatches.take(10).toList();
    
    // Sort closest matches
    closestMatches.sort((a, b) => (a['scoreDifference'] ?? 0).compareTo(b['scoreDifference'] ?? 0));
    closestMatches = closestMatches.take(10).toList();
    
    // Sort highest margin matches
    highestMarginMatches.sort((a, b) => (b['scoreDifference'] ?? 0).compareTo(a['scoreDifference'] ?? 0));
    highestMarginMatches = highestMarginMatches.take(10).toList();
    
    // Sort tournament timeline
    tournamentTimeline.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    
    // Calculate totals
    totalTeams = allTeamIds.length;
    totalVenues = allVenues.length;
    
    // Update unique sets
    uniqueCategories = categoryDistribution.keys.toSet();
    uniqueSports = sportDistribution.keys.toSet();
    uniqueGenders = genderDistribution.keys.toSet();
    uniqueBracketTypes = bracketTypeDistribution.keys.toSet();
    uniqueEliminationTypes = eliminationTypeDistribution.keys.toSet();
  }
  
  void _resetMetrics() {
    totalTournaments = tournaments.length;
    activeTournaments = 0;
    completedTournaments = 0;
    totalMatches = 0;
    completedMatches = 0;
    totalTeams = 0;
    totalVenues = 0;
    
    categoryDistribution.clear();
    sportDistribution.clear();
    genderDistribution.clear();
    bracketTypeDistribution.clear();
    eliminationTypeDistribution.clear();
    venueDistribution.clear();
    statusDistribution.clear();
    
    matchesByBracket.clear();
    matchesByRound.clear();
    matchesByMatchType.clear();
    topScoringMatches.clear();
    closestMatches.clear();
    highestMarginMatches.clear();
    
    tournamentTimeline.clear();
    teamStats.clear();
    topTeamsByWins.clear();
    topTeamsByScore.clear();
    medalStandings.clear();
  }
  
  void _processMatchScores(Map<String, dynamic> match, Map<String, dynamic> scores) {
    final scoreValues = scores.values.whereType<num>().toList();
    if (scoreValues.length >= 2) {
      final maxScore = scoreValues.reduce((a, b) => a > b ? a : b).toDouble();
      final minScore = scoreValues.reduce((a, b) => a < b ? a : b).toDouble();
      final totalScore = scoreValues.reduce((a, b) => a + b).toDouble();
      final scoreDifference = maxScore - minScore;
      
      final matchData = <String, dynamic>{
        'matchId': match['id'],
        'matchNumber': match['matchNumber'],
        'tournamentName': match['tournamentName'],
        'sport': match['sport'],
        'category': match['category'],
        'bracket': match['bracket'],
        'round': match['round'],
        'winner': match['winner'],
        'scores': scores,
        'maxScore': maxScore,
        'minScore': minScore,
        'totalScore': totalScore,
        'scoreDifference': scoreDifference,
      };
      
      topScoringMatches.add(matchData);
      closestMatches.add(matchData);
      highestMarginMatches.add(matchData);
      
      // Track team scores for team statistics
      final team1Raw = match['team1'];
      final team2Raw = match['team2'];
      
      if (team1Raw is Map && team2Raw is Map) {
        final team1 = Map<String, dynamic>.from(team1Raw);
        final team2 = Map<String, dynamic>.from(team2Raw);
        
        final team1Id = (team1['id'] ?? match['team1Id']).toString();
        final team2Id = (team2['id'] ?? match['team2Id']).toString();
        final team1Score = (match['team1Score'] ?? team1['score'] ?? 0) as num;
        final team2Score = (match['team2Score'] ?? team2['score'] ?? 0) as num;
        final winnerId = match['winner']?.toString();
        
        _updateTeamStats(team1Id, team1Score, team2Score, winnerId == team1Id);
        _updateTeamStats(team2Id, team2Score, team1Score, winnerId == team2Id);
      }
    }
  }
  
  void _updateTeamStats(String teamId, num score, num opponentScore, bool isWinner) {
    if (!teamStats.containsKey(teamId)) {
      teamStats[teamId] = {
        'teamId': teamId,
        'teamName': '',
        'totalMatches': 0,
        'wins': 0,
        'losses': 0,
        'totalPoints': 0,
        'pointsAgainst': 0,
        'averageScore': 0.0,
      };
    }
    
    final stats = teamStats[teamId]!;
    stats['totalMatches'] = (stats['totalMatches'] as int) + 1;
    if (isWinner) {
      stats['wins'] = (stats['wins'] as int) + 1;
    } else {
      stats['losses'] = (stats['losses'] as int) + 1;
    }
    stats['totalPoints'] = (stats['totalPoints'] as num) + score;
    stats['pointsAgainst'] = (stats['pointsAgainst'] as num) + opponentScore;
    stats['averageScore'] = (stats['totalPoints'] as num) / (stats['totalMatches'] as int);
  }
  
  void _processMedals(Map<String, dynamic> medals, String tournamentName) {
    final goldId = medals['gold'] as String?;
    final silverId = medals['silver'] as String?;
    final bronzeId = medals['bronze'] as String?;
    
    if (goldId != null) {
      if (!medalStandings.containsKey(goldId)) {
        medalStandings[goldId] = {
          'teamId': goldId,
          'teamName': '',
          'gold': 0,
          'silver': 0,
          'bronze': 0,
          'total': 0
        };
      }
      medalStandings[goldId]!['gold'] = (medalStandings[goldId]!['gold'] as int) + 1;
      medalStandings[goldId]!['total'] = (medalStandings[goldId]!['total'] as int) + 1;
    }
    
    if (silverId != null) {
      if (!medalStandings.containsKey(silverId)) {
        medalStandings[silverId] = {
          'teamId': silverId,
          'teamName': '',
          'gold': 0,
          'silver': 0,
          'bronze': 0,
          'total': 0
        };
      }
      medalStandings[silverId]!['silver'] = (medalStandings[silverId]!['silver'] as int) + 1;
      medalStandings[silverId]!['total'] = (medalStandings[silverId]!['total'] as int) + 1;
    }
    
    if (bronzeId != null) {
      if (!medalStandings.containsKey(bronzeId)) {
        medalStandings[bronzeId] = {
          'teamId': bronzeId,
          'teamName': '',
          'gold': 0,
          'silver': 0,
          'bronze': 0,
          'total': 0
        };
      }
      medalStandings[bronzeId]!['bronze'] = (medalStandings[bronzeId]!['bronze'] as int) + 1;
      medalStandings[bronzeId]!['total'] = (medalStandings[bronzeId]!['total'] as int) + 1;
    }
  }
  
  Future<void> _loadTeamDetails(Set<String> teamIds) async {
    if (teamIds.isEmpty) return;
    
    try {
      final List<String> teamIdList = teamIds.toList();
      
      // Split into batches of 10 for Firestore's whereIn limit
      const batchSize = 10;
      List<Map<String, dynamic>> allParticipants = [];
      
      for (var i = 0; i < teamIdList.length; i += batchSize) {
        final end = (i + batchSize < teamIdList.length) ? i + batchSize : teamIdList.length;
        final batch = teamIdList.sublist(i, end);
        
        final participantsSnapshot = await _firestore
            .collection('participants')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        
        for (var doc in participantsSnapshot.docs) {
          final teamId = doc.id;
          final data = doc.data();
          final teamName = data['name'] ?? data['teamName'] ?? 'Unknown Team';
          
          // Update team stats with names
          if (teamStats.containsKey(teamId)) {
            teamStats[teamId]!['teamName'] = teamName;
          }
          
          // Update medal standings with names
          if (medalStandings.containsKey(teamId)) {
            medalStandings[teamId]!['teamName'] = teamName;
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading team details: $e');
      }
    }
  }
  
  void _calculateTopTeams() {
    // Top teams by wins
    final List<Map<String, dynamic>> winsList = teamStats.values.toList();
    winsList.sort((a, b) => (b['wins'] as int).compareTo(a['wins'] as int));
    topTeamsByWins = winsList.take(10).toList();
    
    // Top teams by average score
    final List<Map<String, dynamic>> scoreList = teamStats.values.toList();
    scoreList.sort((a, b) => (b['averageScore'] as double).compareTo(a['averageScore'] as double));
    topTeamsByScore = scoreList.take(10).toList();
  }
  
  // Helper methods for reports
  Map<String, dynamic> getTournamentByCategoryReport() {
    return {
      'categories': Map<String, int>.from(categoryDistribution),
      'totalCategories': categoryDistribution.length,
      'mostPopularCategory': categoryDistribution.entries.isEmpty 
          ? null 
          : categoryDistribution.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }
  
  Map<String, dynamic> getSportDistributionReport() {
    return {
      'sports': Map<String, int>.from(sportDistribution),
      'totalSports': sportDistribution.length,
      'mostPopularSport': sportDistribution.entries.isEmpty 
          ? null 
          : sportDistribution.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }
  
  Map<String, dynamic> getMatchCompletionReport() {
    final completionRate = totalMatches > 0 ? (completedMatches / totalMatches) * 100 : 0;
    return {
      'totalMatches': totalMatches,
      'completedMatches': completedMatches,
      'pendingMatches': totalMatches - completedMatches,
      'completionRate': completionRate,
      'matchesByBracket': Map<String, int>.from(matchesByBracket),
      'matchesByRound': Map<String, int>.from(matchesByRound),
      'matchesByType': Map<String, int>.from(matchesByMatchType),
    };
  }
  
  Map<String, dynamic> getVenueUtilizationReport() {
    return {
      'totalVenues': totalVenues,
      'venueDistribution': Map<String, int>.from(venueDistribution),
      'mostUsedVenue': venueDistribution.entries.isEmpty 
          ? null 
          : venueDistribution.entries.reduce((a, b) => a.value > b.value ? a : b).key,
    };
  }
  
  Map<String, dynamic> getTournamentStatusReport() {
    return {
      'totalTournaments': totalTournaments,
      'activeTournaments': activeTournaments,
      'completedTournaments': completedTournaments,
      'statusDistribution': Map<String, int>.from(statusDistribution),
    };
  }
  
  Map<String, dynamic> getGenderDistributionReport() {
    return {
      'distribution': Map<String, int>.from(genderDistribution),
      'menTournaments': genderDistribution['Men'] ?? 0,
      'womenTournaments': genderDistribution['Women'] ?? 0,
      'mixedTournaments': genderDistribution['Mixed'] ?? 0,
    };
  }
  
  Map<String, dynamic> getTopScoringMatchesReport() {
    return {
      'topScoringMatches': List<Map<String, dynamic>>.from(topScoringMatches),
      'highestTotalScore': topScoringMatches.isNotEmpty ? topScoringMatches.first['totalScore'] : 0,
    };
  }
  
  Map<String, dynamic> getClosestMatchesReport() {
    return {
      'closestMatches': List<Map<String, dynamic>>.from(closestMatches),
      'smallestMargin': closestMatches.isNotEmpty ? closestMatches.first['scoreDifference'] : 0,
    };
  }
  
  Map<String, dynamic> getBiggestWinsReport() {
    return {
      'biggestWins': List<Map<String, dynamic>>.from(highestMarginMatches),
      'largestMargin': highestMarginMatches.isNotEmpty ? highestMarginMatches.first['scoreDifference'] : 0,
    };
  }
  
  Map<String, dynamic> getTeamStandingsReport() {
    return {
      'topTeamsByWins': List<Map<String, dynamic>>.from(topTeamsByWins),
      'topTeamsByAverageScore': List<Map<String, dynamic>>.from(topTeamsByScore),
      'totalTeams': totalTeams,
    };
  }
  
  Map<String, dynamic> getMedalStandingsReport() {
    final List<Map<String, dynamic>> sortedMedals = medalStandings.values.toList();
    sortedMedals.sort((a, b) {
      if (b['gold'] != a['gold']) return (b['gold'] as int).compareTo(a['gold'] as int);
      if (b['silver'] != a['silver']) return (b['silver'] as int).compareTo(a['silver'] as int);
      return (b['bronze'] as int).compareTo(a['bronze'] as int);
    });
    
    return {
      'medalStandings': sortedMedals,
      'totalMedalWinners': medalStandings.length,
    };
  }
  
  Map<String, dynamic> getTournamentTimelineReport() {
    final monthlyData = <String, int>{};
    for (var timeline in tournamentTimeline) {
      final date = timeline['date'] as DateTime;
      final monthKey = DateFormat('MMM yyyy').format(date);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
    }
    
    return {
      'timeline': List<Map<String, dynamic>>.from(tournamentTimeline),
      'monthlyTournaments': monthlyData,
      'firstTournament': tournamentTimeline.isNotEmpty ? tournamentTimeline.first['date'] : null,
      'latestTournament': tournamentTimeline.isNotEmpty ? tournamentTimeline.last['date'] : null,
    };
  }
  
  Map<String, dynamic> getFullReport() {
    return {
      'summary': {
        'totalTournaments': totalTournaments,
        'activeTournaments': activeTournaments,
        'completedTournaments': completedTournaments,
        'totalMatches': totalMatches,
        'completedMatches': completedMatches,
        'completionRate': totalMatches > 0 ? (completedMatches / totalMatches) * 100 : 0,
        'totalTeams': totalTeams,
        'totalVenues': totalVenues,
      },
      'categoryDistribution': getTournamentByCategoryReport(),
      'sportDistribution': getSportDistributionReport(),
      'genderDistribution': getGenderDistributionReport(),
      'bracketTypes': Map<String, int>.from(bracketTypeDistribution),
      'eliminationTypes': Map<String, int>.from(eliminationTypeDistribution),
      'matchCompletion': getMatchCompletionReport(),
      'venueUtilization': getVenueUtilizationReport(),
      'topScoringMatches': getTopScoringMatchesReport(),
      'closestMatches': getClosestMatchesReport(),
      'biggestWins': getBiggestWinsReport(),
      'teamStandings': getTeamStandingsReport(),
      'medalStandings': getMedalStandingsReport(),
      'tournamentTimeline': getTournamentTimelineReport(),
    };
  }
  
  List<String> getFilterOptions(String type) {
    switch (type) {
      case 'sport':
        return uniqueSports.toList()..sort();
      case 'category':
        return uniqueCategories.toList()..sort();
      case 'gender':
        return uniqueGenders.toList()..sort();
      case 'bracketType':
        return uniqueBracketTypes.toList()..sort();
      case 'eliminationType':
        return uniqueEliminationTypes.toList()..sort();
      default:
        return [];
    }
  }
}