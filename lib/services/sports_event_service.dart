import 'package:cloud_firestore/cloud_firestore.dart';

class SportsEventService {
  final CollectionReference _sportsEventCollection =
      FirebaseFirestore.instance.collection('sports_events');

  Stream<QuerySnapshot> getSportsEventsStream() {
    return _sportsEventCollection.snapshots();
  }

  Future<void> addSportsEvent(Map<String, dynamic> eventData) async {
    try {
      String id = eventData['id'];
      await _sportsEventCollection.doc(id).set(eventData);
    } catch (e) {
      throw Exception('Error adding sports event: $e');
    }
  }

  Future<void> updateSportsEvent(
      String docId, Map<String, dynamic> updatedData) async {
    try {
      await _sportsEventCollection.doc(docId).update(updatedData);
    } catch (e) {
      throw Exception('Error updating sports event: $e');
    }
  }

  Future<void> deleteSportsEvent(String docId) async {
    try {
      // Delete linked team schedules
      final schedulesCollection =
          FirebaseFirestore.instance.collection('team_schedules');
      final schedulesSnapshot = await schedulesCollection
          .where('tournamentSetupId', isEqualTo: docId)
          .get();
      for (final doc in schedulesSnapshot.docs) {
        await schedulesCollection.doc(doc.id).delete();
      }
      // Delete the sports event document
      await _sportsEventCollection.doc(docId).delete();
    } catch (e) {
      throw Exception('Error deleting sports event and linked schedules: $e');
    }
  }

  Future<bool> sportsEventNameExists(String name) async {
    try {
      final querySnapshot = await _sportsEventCollection
          .where('name', isEqualTo: name.trim())
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error checking sports event name existence: $e');
    }
  }

  Future<bool> hasActiveSportsEvent() async {
    try {
      final querySnapshot = await _sportsEventCollection
          .where('status', isEqualTo: 'active')
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Error checking active sports event: $e');
    }
  }

  Future<String?> getActiveSportsEventId() async {
    try {
      final querySnapshot = await _sportsEventCollection
          .where('status', isEqualTo: 'active')
          .get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }
      return null;
    } catch (e) {
      throw Exception('Error getting active sports event ID: $e');
    }
  }
}
