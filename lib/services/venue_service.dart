import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class VenueService {
  final CollectionReference _venuesCollection =
      FirebaseFirestore.instance.collection('venues');
  final SportsEventService _sportsEventService = SportsEventService();

  Stream<QuerySnapshot> getVenuesStream() {
    return _venuesCollection.snapshots();
  }

  Future<void> addVenue(String name, String sportId, String sportName) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception('No active sports event found. Cannot add venue.');
    }
    await _venuesCollection.add({
      'name': name,
      'sportId': sportId,
      'sportName': sportName,
      'sportsEventId': activeEventId,
    });
  }

  Future<void> updateVenue(String docId, String name, String sportId, String sportName) async {
    await _venuesCollection.doc(docId).update({
      'name': name,
      'sportId': sportId,
      'sportName': sportName,
    });
  }

  Future<void> deleteVenue(String docId) async {
    await _venuesCollection.doc(docId).delete();
  }
}
