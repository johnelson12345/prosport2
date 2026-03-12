import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class MatchupService {
  static final MatchupService _instance = MatchupService._internal();

  factory MatchupService() {
    return _instance;
  }

  MatchupService._internal();

  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('matchups');
  final SportsEventService _sportsEventService = SportsEventService();

  Future<void> createMatchup(
      Map<String, dynamic> matchup, List<String> teamIds) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception('No active sports event found. Cannot create matchup.');
    }
    matchup['teamIds'] = teamIds; // Add team IDs to the matchup data
    matchup['sportsEventId'] = activeEventId;
    await _collection.doc(matchup['id']).set(matchup);
  }

  Stream<List<Map<String, dynamic>>> getAllMatchups() async* {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      yield [];
    } else {
      yield* _collection
          .where('sportsEventId', isEqualTo: activeEventId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList());
    }
  }

  Stream<List<Map<String, dynamic>>> getMatchupsByTournament(
      String tournamentId) async* {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      yield [];
    } else {
      yield* _collection
          .where('sportsEventId', isEqualTo: activeEventId)
          .where('tournamentSetupId', isEqualTo: tournamentId)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList());
    }
  }

  Future<void> updateMatchupScores(
      String id, int scoreTeam1, int scoreTeam2, String winner) async {
    await _collection.doc(id).update({
      'scoreTeam1': scoreTeam1,
      'scoreTeam2': scoreTeam2,
      'winner': winner,
    });
  }

  Future<void> updateMatchup(String id, Map<String, dynamic> updatedMatchup,
      List<String>? teamIds) async {
    if (teamIds != null) {
      updatedMatchup['teamIds'] = teamIds; // Update team IDs if provided
    }
    await _collection.doc(id).update(updatedMatchup);
  }

  Future<void> deleteMatchup(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> updateWinner(String id, String winner) async {
    await _collection.doc(id).update({'winner': winner});
  }
}
