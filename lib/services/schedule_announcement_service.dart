import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class ScheduleAnnouncementService {
  static final ScheduleAnnouncementService _instance =
      ScheduleAnnouncementService._internal();

  factory ScheduleAnnouncementService() {
    return _instance;
  }

  ScheduleAnnouncementService._internal();

  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('announcements');
  final SportsEventService _sportsEventService = SportsEventService();

  Future<void> createAnnouncement(Map<String, dynamic> announcement) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception(
          'No active sports event found. Cannot create announcement.');
    }
    announcement['sportsEventId'] = activeEventId;
    await _collection.doc(announcement['id']).set(announcement);
  }

Stream<List<Map<String, dynamic>>> getLatestAnnouncements(
      {int limit = 20}) async* {
    String? activeEventId;
    try {
      activeEventId = await _sportsEventService.getActiveSportsEventId();
    } catch (e) {
      activeEventId = null;
    }
    
    if (activeEventId == null) {
      yield [];
      return;
    }
    
    try {
      yield* _collection
          .where('sportsEventId', isEqualTo: activeEventId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
            try {
              return snapshot.docs
                  .map((doc) => doc.data() as Map<String, dynamic>)
                  .toList();
            } catch (castError) {
              return <Map<String, dynamic>>[];
            }
          });
    } catch (queryError) {
      yield [];
    }
  }

  Future<void> deleteAnnouncement(String id) async {
    await _collection.doc(id).delete();
  }

  Future<void> updateAnnouncement(String id, Map<String, dynamic> data) async {
    await _collection.doc(id).update(data);
  }
}
