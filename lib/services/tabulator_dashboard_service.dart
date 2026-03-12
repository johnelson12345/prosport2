import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class TabulatorDashboardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get real-time dashboard statistics
  Stream<Map<String, dynamic>> getDashboardStatisticsStream() {
    return Stream.periodic(const Duration(seconds: 5), (_) {})
        .asyncMap((_) async {
      return await getDashboardStatistics();
    });
  }

  // Get all dashboard statistics at once
  Future<Map<String, dynamic>> getDashboardStatistics() async {
    try {
      final results = await Future.wait([
        getTotalTournaments(),
        getActiveTournaments(),
        getTotalMatches(),
        getCompletedMatches(),
        getPendingScores(),
        getTotalTeams(),
        getTotalParticipants(),
        getTournamentCategories(),
        getRecentMatches(),
        getUpcomingMatches(),
      ]);

      return {
        'totalTournaments': results[0],
        'activeTournaments': results[1],
        'totalMatches': results[2],
        'completedMatches': results[3],
        'pendingScores': results[4],
        'totalTeams': results[5],
        'totalParticipants': results[6],
        'tournamentCategories': results[7],
        'recentMatches': results[8],
        'upcomingMatches': results[9],
        'lastUpdated': DateTime.now().toString(),
      };
    } catch (e) {
      print('Error fetching dashboard statistics: $e');
      return _getDefaultStatistics();
    }
  }

  // Get total tournaments count (only those without verification status)
  Future<int> getTotalTournaments() async {
    try {
      final snapshot = await _firestore.collection('tournaments').get();
      int count = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        // Only count tournaments that don't have verification status fields
        if (!_hasVerificationStatus(data)) {
          count++;
        }
      }

      return count;
    } catch (e) {
      print('Error fetching total tournaments: $e');
      return 0;
    }
  }

  // Get active tournaments count (total number of tournaments)
  Future<int> getActiveTournaments() async {
    try {
      final snapshot = await _firestore.collection('tournaments').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching active tournaments: $e');
      return 0;
    }
  }

  // Helper function to check if tournament has verification status fields
  bool _hasVerificationStatus(Map<String, dynamic> data) {
    return data.containsKey('isVerified') ||
        data.containsKey('verificationStatus') ||
        data.containsKey('verifiedAt') ||
        data.containsKey('verifiedBy');
  }

  // Get total matches count based on team schedules
  Future<int> getTotalMatches() async {
    try {
      final snapshot = await _firestore.collection('team_schedules').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching total matches: $e');
      return 0;
    }
  }

  // Get completed matches count
  Future<int> getCompletedMatches() async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .where('status', isEqualTo: 'completed')
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching completed matches: $e');
      return 0;
    }
  }

  // Get pending scores count - tournaments that have matches with no scores
  Future<int> getPendingScores() async {
    try {
      // Get all matches that don't have scores (score1 and score2 are null or 0)
      final snapshot = await _firestore.collection('matches').get();

      int pendingScoreCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final score1 = data['score1'];
        final score2 = data['score2'];

        // Check if either score is missing or null (indicating no scores entered)
        if (score1 == null || score2 == null || (score1 == 0 && score2 == 0)) {
          pendingScoreCount++;
        }
      }

      return pendingScoreCount;
    } catch (e) {
      print('Error fetching pending scores: $e');
      return 0;
    }
  }

  // Get total teams count
  Future<int> getTotalTeams() async {
    try {
      final snapshot = await _firestore.collection('teams').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching total teams: $e');
      return 0;
    }
  }

  // Get total participants count
  Future<int> getTotalParticipants() async {
    try {
      final snapshot = await _firestore.collection('participants').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching total participants: $e');
      return 0;
    }
  }

  // Get tournament categories count
  Future<int> getTournamentCategories() async {
    try {
      final snapshot = await _firestore.collection('sports_categories').get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error fetching tournament categories: $e');
      return 0;
    }
  }

  // Get recent matches (last 5)
  Future<List<Map<String, dynamic>>> getRecentMatches() async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'team1': data['team1'] ?? 'TBD',
          'team2': data['team2'] ?? 'TBD',
          'score1': data['score1'] ?? 0,
          'score2': data['score2'] ?? 0,
          'status': data['status'] ?? 'pending',
          'scheduledTime': data['scheduledTime']?.toDate() ?? DateTime.now(),
        };
      }).toList();
    } catch (e) {
      print('Error fetching recent matches: $e');
      return [];
    }
  }

  // Get upcoming matches (next 5)
  Future<List<Map<String, dynamic>>> getUpcomingMatches() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('matches')
          .where('scheduledTime', isGreaterThan: now)
          .orderBy('scheduledTime')
          .limit(5)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'team1': data['team1'] ?? 'TBD',
          'team2': data['team2'] ?? 'TBD',
          'scheduledTime': data['scheduledTime']?.toDate() ?? DateTime.now(),
          'venue': data['venue'] ?? 'TBD',
        };
      }).toList();
    } catch (e) {
      print('Error fetching upcoming matches: $e');
      return [];
    }
  }

  // Get tournament summary by status
  Future<Map<String, int>> getTournamentStatusSummary() async {
    try {
      final snapshot = await _firestore.collection('tournaments').get();
      final statusCounts = <String, int>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      print('Error fetching tournament status summary: $e');
      return {};
    }
  }

  // Get match summary by status
  Future<Map<String, int>> getMatchStatusSummary() async {
    try {
      final snapshot = await _firestore.collection('matches').get();
      final statusCounts = <String, int>{};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final status = data['status'] ?? 'pending';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }

      return statusCounts;
    } catch (e) {
      print('Error fetching match status summary: $e');
      return {};
    }
  }

  // Get team performance summary
  Future<List<Map<String, dynamic>>> getTeamPerformanceSummary() async {
    try {
      final snapshot = await _firestore.collection('teams').get();
      final teams = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final teamId = doc.id;

        // Get team matches
        final matchesSnapshot = await _firestore
            .collection('matches')
            .where('team1', isEqualTo: teamId)
            .get();

        final matchesSnapshot2 = await _firestore
            .collection('matches')
            .where('team2', isEqualTo: teamId)
            .get();

        final allMatches = [...matchesSnapshot.docs, ...matchesSnapshot2.docs];

        int wins = 0;
        int losses = 0;
        int draws = 0;

        for (var matchDoc in allMatches) {
          final match = matchDoc.data();
          final score1 = match['score1'] ?? 0;
          final score2 = match['score2'] ?? 0;

          if (match['team1'] == teamId) {
            if (score1 > score2) {
              wins++;
            } else if (score1 < score2)
              losses++;
            else
              draws++;
          } else {
            if (score2 > score1) {
              wins++;
            } else if (score2 < score1)
              losses++;
            else
              draws++;
          }
        }

        teams.add({
          'teamId': teamId,
          'teamName': data['teamName'] ?? 'Unknown',
          'wins': wins,
          'losses': losses,
          'draws': draws,
          'totalMatches': allMatches.length,
        });
      }

      return teams;
    } catch (e) {
      print('Error fetching team performance summary: $e');
      return [];
    }
  }

  // Default statistics when error occurs
  Map<String, dynamic> _getDefaultStatistics() {
    return {
      'totalTournaments': 0,
      'activeTournaments': 0,
      'totalMatches': 0,
      'completedMatches': 0,
      'pendingScores': 0,
      'totalTeams': 0,
      'totalParticipants': 0,
      'tournamentCategories': 0,
      'recentMatches': [],
      'upcomingMatches': [],
      'lastUpdated': DateTime.now().toString(),
    };
  }
}
