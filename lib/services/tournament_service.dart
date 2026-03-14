import 'package:cloud_firestore/cloud_firestore.dart';
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
      print('Error updating tournament status: $e');
      rethrow;
    }
  }
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
}
