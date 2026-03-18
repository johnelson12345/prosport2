// ignore_for_file: empty_catches

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class TournamentService {
  final CollectionReference _tournamentCollection =
      FirebaseFirestore.instance.collection('tournaments');
  final SportsEventService _sportsEventService = SportsEventService();

  // Create Tournament
  Future<void> addTournament(Map<String, dynamic> tournamentData) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception('No active sports event found. Cannot add tournament.');
      }
      tournamentData['sportsEventId'] = activeEventId;
      String id = tournamentData['id'];
      await _tournamentCollection.doc(id).set(tournamentData);
    } catch (e) {
      throw Exception('Error adding tournament: $e');
    }
  }
  
  Future<void> updateTournamentStatus(String docId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(docId)
          .update({'status': status});
    } catch (e) {
      rethrow;
    }
  }
  
 // In tournament_service.dart, update the getTournamentStream method:

// Read Tournaments (Stream for Real-Time Updates)
Stream<QuerySnapshot> getTournamentStream() async* {
  String? activeEventId = await _sportsEventService.getActiveSportsEventId();
  if (activeEventId == null) {
    yield* Stream.empty();
  } else {
    yield* _tournamentCollection
        .where('sportsEventId', isEqualTo: activeEventId)
        .snapshots();
  }
}

  // Update Tournament
  Future<void> updateTournament(
      String docId, Map<String, dynamic> updatedData) async {
    try {
      await _tournamentCollection.doc(docId).update(updatedData);
    } catch (e) {
      throw Exception('Error updating tournament: $e');
    }
  }

  // Delete Tournament and linked team schedules
  Future<void> deleteTournament(String docId) async {
    try {
      // Delete linked team schedules
      final schedulesCollection =
          FirebaseFirestore.instance.collection('team_schedules');
      final schedulesSnapshot = await schedulesCollection
          .where('tournamentId', isEqualTo: docId)
          .get();
      for (final doc in schedulesSnapshot.docs) {
        await schedulesCollection.doc(doc.id).delete();
      }
      // Delete the tournament document
      await _tournamentCollection.doc(docId).delete();
    } catch (e) {
      throw Exception('Error deleting tournament and linked schedules: $e');
    }
  }

  // Check if tournament name already exists
  Future<bool> tournamentNameExists(String name) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        return false;
      }
      final querySnapshot = await _tournamentCollection
          .where('name', isEqualTo: name.trim())
          .where('sportsEventId', isEqualTo: activeEventId)
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error checking tournament name existence: $e');
    }
  }
  
  // Mark entire tournament as completed
  Future<void> markTournamentAsCompleted(String tournamentId, bool isCompleted) async {
    try {
      // First, get the tournament document ID
      final tournamentQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: tournamentId)
          .limit(1)
          .get();

      if (tournamentQuery.docs.isEmpty) {
        throw Exception('Tournament not found');
      }

      final tournamentDocId = tournamentQuery.docs.first.id;
      
      // Update the tournament document
      await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentDocId)
          .update({
        'isCompleted': isCompleted,
        'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
        'completedBy': isCompleted ? FirebaseAuth.instance.currentUser?.uid : null,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
    } catch (e) {
      rethrow;
    }
  }

  // IMPROVED: Check if all matches in tournament have scores
  Future<bool> doAllMatchesHaveScores(String tournamentId) async {
    try {
      
      // Get tournament document ID
      final tournamentQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: tournamentId)
          .limit(1)
          .get();

      if (tournamentQuery.docs.isEmpty) {
        return false;
      }

      final tournamentDocId = tournamentQuery.docs.first.id;
      
      // Get all matches from team_schedules collection first (since your data shows matches there)
      final teamSchedulesSnapshot = await FirebaseFirestore.instance
          .collection('team_schedules')
          .where('tournamentSetupId', isEqualTo: tournamentId)
          .get();
      
      
      if (teamSchedulesSnapshot.docs.isEmpty) {
        return false;
      }
      
      // Check each match for scores in various locations
      int matchesWithScores = 0;
      
      for (var matchDoc in teamSchedulesSnapshot.docs) {
        final matchData = matchDoc.data();
        final matchId = matchDoc.id;
        
        print('\n--- Checking match: $matchId ---');
        
        bool hasScores = false;
        
        // LOCATION 1: Check if match has scores field directly
        if (matchData.containsKey('scores')) {
          final scores = matchData['scores'];
          if (scores != null) {
            if (scores is Map && scores.isNotEmpty) {
              hasScores = true;
            } else if (scores is List && scores.isNotEmpty) {
              hasScores = true;
            }
          }
        }
        
        // LOCATION 2: Check if match has winner/loser (indicates scores were entered)
        if (!hasScores && matchData.containsKey('winner') && matchData['winner'] != null) {
          hasScores = true;
        }
        
        // LOCATION 3: Check tournament's scores subcollection
        if (!hasScores) {
          final tournamentScores = await FirebaseFirestore.instance
              .collection('tournaments')
              .doc(tournamentDocId)
              .collection('scores')
              .where('matchId', isEqualTo: matchId)
              .get();
          
          if (tournamentScores.docs.isNotEmpty) {
            hasScores = true;
          }
        }
        
        // LOCATION 4: Check main scores collection
        if (!hasScores) {
          final mainScores = await FirebaseFirestore.instance
              .collection('scores')
              .where('matchId', isEqualTo: matchId)
              .get();
          
          if (mainScores.docs.isNotEmpty) {
            hasScores = true;
          }
        }
        
        // LOCATION 5: Check for any field that might contain score data
        if (!hasScores) {
          // Look for common score field names
          final possibleScoreFields = ['score', 'team1Score', 'team2Score', 'scores', 'result'];
          for (var field in possibleScoreFields) {
            if (matchData.containsKey(field) && matchData[field] != null) {
              final value = matchData[field];
              if (value is num || (value is String && value.isNotEmpty)) {
                hasScores = true;
                break;
              }
            }
          }
        }
        
        if (hasScores) {
          matchesWithScores++;
        } else {
        }
      }
      
      return matchesWithScores == teamSchedulesSnapshot.docs.length;
      
    } catch (e) {
      return false;
    }
  }

  // DEBUG METHOD: Check exactly where scores are stored
  Future<void> debugScoreLocations(String tournamentId) async {
    try {
      
      // Get tournament document
      final tournamentQuery = await FirebaseFirestore.instance
          .collection('tournaments')
          .where('id', isEqualTo: tournamentId)
          .limit(1)
          .get();

      if (tournamentQuery.docs.isEmpty) {
        return;
      }

      final tournamentDoc = tournamentQuery.docs.first;
      final tournamentDocId = tournamentDoc.id;
      
      // 1. Check team_schedules collection
      final teamSchedules = await FirebaseFirestore.instance
          .collection('team_schedules')
          .where('tournamentSetupId', isEqualTo: tournamentId)
          .get();
      
      for (var doc in teamSchedules.docs) {
        final data = doc.data();
        if (data.containsKey('scores')) {
        }
      }
      
      // 2. Check tournament matches subcollection
      final tournamentMatches = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentDocId)
          .collection('matches')
          .get();
      
      for (var doc in tournamentMatches.docs) {
        final data = doc.data();
        if (data.containsKey('scores')) {
        }
      }
      
      // 3. Check tournament scores subcollection
      final tournamentScores = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(tournamentDocId)
          .collection('scores')
          .get();
      
      for (var doc in tournamentScores.docs) {
      }
      
      // 4. Check main scores collection
      final mainScores = await FirebaseFirestore.instance
          .collection('scores')
          .where('tournamentSetupId', isEqualTo: tournamentId)
          .get();
      
      for (var doc in mainScores.docs) {
      }
      
    } catch (e) {
    }
  }
}