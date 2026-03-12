import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class TeamParticipantsService {
  final CollectionReference _teamsCollection =
      FirebaseFirestore.instance.collection('teams');
  final SportsEventService _sportsEventService = SportsEventService();

  Future<List<Map<String, dynamic>>> getTeams() async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      return [];
    }
    final snapshot = await _teamsCollection
        .where('sportsEventId', isEqualTo: activeEventId)
        .get();
    return snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
        .toList();
  }

  Future<void> addTeam(Map<String, dynamic> data) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception('No active sports event found. Cannot add team.');
    }
    data['sportsEventId'] = activeEventId;
    await _teamsCollection.add(data);
  }

  Future<void> updateTeam(String id, Map<String, dynamic> data) async {
    await _teamsCollection.doc(id).update(data);
  }

  Future<void> deleteTeam(String id) async {
    await _teamsCollection.doc(id).delete();
  }
}
