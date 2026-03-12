import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class SportsService {
  final CollectionReference _sportsCollection =
      FirebaseFirestore.instance.collection('sports');
  final SportsEventService _sportsEventService = SportsEventService();

  Stream<QuerySnapshot> getSportsStream() {
    return _sportsCollection.snapshots();
  }

  Future<void> addSport(String name, String category) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception('No active sports event found. Cannot add sport.');
    }
    await _sportsCollection.add({
      'name': name,
      'category': category,
      'sportsEventId': activeEventId,
    });
  }

  Future<void> updateSport(String docId, String name, String category) async {
    await _sportsCollection.doc(docId).update({
      'name': name,
      'category': category,
    });
  }

  Future<void> deleteSport(String docId) async {
    await _sportsCollection.doc(docId).delete();
  }
}
