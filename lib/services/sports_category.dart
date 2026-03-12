import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class SportCategoryService {
  final CollectionReference _sportsCollection =
      FirebaseFirestore.instance.collection('sports_categories');
  final SportsEventService _sportsEventService = SportsEventService();

  // Create
  Future<void> addCategory(String name) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception('No active sports event found. Cannot add category.');
    }
    await _sportsCollection.add({'name': name, 'sportsEventId': activeEventId});
  }

  // Read (get all categories)
  Stream<QuerySnapshot> getCategories() {
    return _sportsCollection.snapshots();
  }

  // Update
  Future<void> updateCategory(String docId, String newName) async {
    await _sportsCollection.doc(docId).update({'name': newName});
  }

  // Delete
  Future<void> deleteCategory(String docId) async {
    await _sportsCollection.doc(docId).delete();
  }

  // Get Active Sports Event ID
  Future<String?> getActiveSportsEventId() async {
    return await _sportsEventService.getActiveSportsEventId();
  }
}
