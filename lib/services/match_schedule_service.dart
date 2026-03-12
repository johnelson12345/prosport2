import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class MatchScheduleService {
  static final MatchScheduleService _instance =
      MatchScheduleService._internal();

  factory MatchScheduleService() {
    return _instance;
  }

  MatchScheduleService._internal();

  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('match_schedule');
  final SportsEventService _sportsEventService = SportsEventService();

  Future<void> createMatchSchedule(Map<String, dynamic> matchSchedule) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception(
          'No active sports event found. Cannot create match schedule.');
    }
    matchSchedule['sportsEventId'] = activeEventId;
    await _collection.doc(matchSchedule['id']).set(matchSchedule);
  }

  Future<void> createMultipleMatchSchedules(
      List<Map<String, dynamic>> matchSchedules) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      throw Exception(
          'No active sports event found. Cannot create match schedules.');
    }
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var matchSchedule in matchSchedules) {
      matchSchedule['sportsEventId'] = activeEventId;
      var docRef = _collection.doc(matchSchedule['id']);
      batch.set(docRef, matchSchedule);
    }
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> getAllMatchSchedules(
      {String? tournamentId}) async* {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      yield [];
    } else {
      Query query =
          _collection.where('sportsEventId', isEqualTo: activeEventId);
      if (tournamentId != null) {
        query = query.where('tournamentSetupId', isEqualTo: tournamentId);
      }
      yield* query.snapshots().map((snapshot) => snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList());
    }
  }

  Future<void> updateMatchSchedule(
      String id, Map<String, dynamic> updatedMatchSchedule) async {
    await _collection.doc(id).update(updatedMatchSchedule);
  }

  /// Update the isOccupied field for a specific schedule
  Future<void> updateScheduleOccupiedStatus(
      String scheduleId, bool isOccupied) async {
    await _collection.doc(scheduleId).update({'isOccupied': isOccupied});
  }

  /// Update the isOccupied field for multiple schedules
  Future<void> updateMultipleSchedulesOccupiedStatus(
      List<String> scheduleIds, bool isOccupied) async {
    if (scheduleIds.isEmpty) return;

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var scheduleId in scheduleIds) {
      var docRef = _collection.doc(scheduleId);
      batch.update(docRef, {'isOccupied': isOccupied});
    }
    await batch.commit();
  }

  Future<void> deleteMatchSchedule(String id) async {
    await _collection.doc(id).delete();
  }

  /// Check if a schedule with the exact same start and end time already exists
  Future<bool> isDuplicateSchedule({
    required String startTime,
    required String endTime,
    String? excludeId,
  }) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) return false;

    Query query = _collection
        .where('sportsEventId', isEqualTo: activeEventId)
        .where('startTime', isEqualTo: startTime)
        .where('endTime', isEqualTo: endTime);

    final snapshot = await query.get();

    // If we need to exclude a specific ID (for updates), filter it out
    if (excludeId != null && snapshot.docs.isNotEmpty) {
      return snapshot.docs.any((doc) => doc.id != excludeId);
    }

    return snapshot.docs.isNotEmpty;
  }

  /// Check if a schedule overlaps with any existing schedule
  Future<bool> hasOverlappingSchedule({
    required String startTime,
    required String endTime,
    String? excludeId,
    int bufferMinutes = 0,
  }) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) return false;

    final newStart = DateTime.parse(startTime);
    final newEnd = DateTime.parse(endTime);

    // Add buffer to the new schedule times
    final bufferedStart = newStart.subtract(Duration(minutes: bufferMinutes));
    final bufferedEnd = newEnd.add(Duration(minutes: bufferMinutes));

    // Get all schedules for the active event
    Query query = _collection.where('sportsEventId', isEqualTo: activeEventId);
    final snapshot = await query.get();

    for (var doc in snapshot.docs) {
      // Skip if this is the schedule we're updating
      if (excludeId != null && doc.id == excludeId) continue;

      final data = doc.data() as Map<String, dynamic>;
      final existingStart = DateTime.parse(data['startTime'] as String);
      final existingEnd = DateTime.parse(data['endTime'] as String);

      // Check for overlap: new start is before existing end AND new end is after existing start
      if (bufferedStart.isBefore(existingEnd) &&
          bufferedEnd.isAfter(existingStart)) {
        return true;
      }
    }

    return false;
  }

  /// Get all schedules sorted by start time
  Future<List<Map<String, dynamic>>> getSchedulesSortedByTime() async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) return [];

    final snapshot = await _collection
        .where('sportsEventId', isEqualTo: activeEventId)
        .orderBy('startTime')
        .get();

    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  /// Get schedules for a specific date
  Future<List<Map<String, dynamic>>> getSchedulesForDate(DateTime date) async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) return [];

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _collection
        .where('sportsEventId', isEqualTo: activeEventId)
        .where('startTime',
            isGreaterThanOrEqualTo: startOfDay.toIso8601String())
        .where('startTime', isLessThan: endOfDay.toIso8601String())
        .orderBy('startTime')
        .get();

    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  /// Get all unique dates that have schedules
  Future<List<DateTime>> getScheduledDates() async {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) return [];

    final snapshot = await _collection
        .where('sportsEventId', isEqualTo: activeEventId)
        .orderBy('startTime')
        .get();

    final Set<DateTime> dates = {};
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final startTime = DateTime.parse(data['startTime'] as String);
      dates.add(DateTime(startTime.year, startTime.month, startTime.day));
    }

    return dates.toList()..sort();
  }
}
