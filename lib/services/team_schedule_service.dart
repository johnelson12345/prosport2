import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class TeamScheduleService {
  static final TeamScheduleService _instance = TeamScheduleService._internal();

  factory TeamScheduleService() {
    return _instance;
  }

  TeamScheduleService._internal();

  final CollectionReference _collection =
      FirebaseFirestore.instance.collection('team_schedules');

  Future<void> createTeamSchedule(Map<String, dynamic> teamSchedule) async {
    await _collection.doc(teamSchedule['id']).set(teamSchedule);
  }

  Future<void> createMultipleTeamSchedules(
      List<Map<String, dynamic>> teamSchedules) async {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var teamSchedule in teamSchedules) {
      var docRef = _collection.doc(teamSchedule['id']);
      batch.set(docRef, teamSchedule);
    }
    await batch.commit();
  }

  Stream<List<Map<String, dynamic>>> getAllTeamSchedules(
      {int limit = 50, DocumentSnapshot? startAfter}) async* {
    // Removed the sports event ID filter to display all team schedules
    // Previously filtered by active sports event which caused "no team schedules found" issue

    Query query =
        _collection.orderBy('dateTime', descending: true).limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    yield* query.snapshots().asyncMap((snapshot) async {
      final schedules = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // Enhance each schedule with category and sport information
      final enhancedSchedules = <Map<String, dynamic>>[];

      for (var schedule in schedules) {
        final enhancedSchedule = Map<String, dynamic>.from(schedule);

        // First, check if sport and category are already available in the schedule
        if (schedule['sport'] != null) {
          enhancedSchedule['sportName'] = schedule['sport'];
        }

        if (schedule['category'] != null) {
          enhancedSchedule['categoryName'] = schedule['category'];
        }

        // If sport or category is still missing, try to fetch from tournament
        if ((enhancedSchedule['sportName'] == null ||
                enhancedSchedule['categoryName'] == null ||
                enhancedSchedule['tournamentName'] == null) &&
            schedule['tournamentSetupId'] != null) {
          try {
            // First try to get by document ID
            var tournamentDoc = await FirebaseFirestore.instance
                .collection('tournaments')
                .doc(schedule['tournamentSetupId'])
                .get();

            // If not found, try to find by 'id' field
            if (!tournamentDoc.exists) {
              final querySnapshot = await FirebaseFirestore.instance
                  .collection('tournaments')
                  .where('id', isEqualTo: schedule['tournamentSetupId'])
                  .limit(1)
                  .get();

              if (querySnapshot.docs.isNotEmpty) {
                tournamentDoc = querySnapshot.docs.first;
              }
            }

            if (tournamentDoc.exists) {
              final tournamentData =
                  tournamentDoc.data() as Map<String, dynamic>;

              // Add category information if still missing
              // First check for categoryId field, then fall back to category field
              if (enhancedSchedule['categoryName'] == null) {
                if (tournamentData['categoryId'] != null) {
                  enhancedSchedule['categoryId'] = tournamentData['categoryId'];

                  // Fetch category name
                  final categoryDoc = await FirebaseFirestore.instance
                      .collection('sportsCategories')
                      .doc(tournamentData['categoryId'])
                      .get();

                  if (categoryDoc.exists) {
                    final categoryData =
                        categoryDoc.data() as Map<String, dynamic>;
                    enhancedSchedule['categoryName'] =
                        categoryData['name'] ?? 'Unknown Category';
                  } else {
                    enhancedSchedule['categoryName'] = 'Unknown Category';
                  }
                } else if (tournamentData['category'] != null) {
                  // Use category directly if categoryId is not available
                  enhancedSchedule['categoryName'] = tournamentData['category'];
                }
              }

              // Add sport information if still missing
              // First check for sportId field, then fall back to sport field
              if (enhancedSchedule['sportName'] == null) {
                if (tournamentData['sportId'] != null) {
                  enhancedSchedule['sportId'] = tournamentData['sportId'];

                  // Fetch sport name
                  final sportDoc = await FirebaseFirestore.instance
                      .collection('sports')
                      .doc(tournamentData['sportId'])
                      .get();

                  if (sportDoc.exists) {
                    final sportData = sportDoc.data() as Map<String, dynamic>;
                    enhancedSchedule['sportName'] =
                        sportData['name'] ?? 'Unknown Sport';
                  } else {
                    enhancedSchedule['sportName'] = 'Unknown Sport';
                  }
                } else if (tournamentData['sport'] != null) {
                  // Use sport directly if sportId is not available
                  enhancedSchedule['sportName'] = tournamentData['sport'];
                }
              }

              // Add assignedUsers from tournament if available
              if (tournamentData['assignedUsers'] != null) {
                enhancedSchedule['assignedUsers'] =
                    tournamentData['assignedUsers'];
              }

              // Add tournament name
              if (tournamentData['name'] != null) {
                enhancedSchedule['tournamentName'] = tournamentData['name'];
              }
            }
          } catch (e) {
            print('Error enhancing schedule data: $e');
            // Only set to unknown if not already set
            if (enhancedSchedule['categoryName'] == null) {
              enhancedSchedule['categoryName'] = 'Unknown Category';
            }
            if (enhancedSchedule['sportName'] == null) {
              enhancedSchedule['sportName'] = 'Unknown Sport';
            }
          }
        }

        // Set defaults if still missing
        if (enhancedSchedule['categoryName'] == null) {
          enhancedSchedule['categoryName'] = 'Unknown Category';
        }
        if (enhancedSchedule['sportName'] == null) {
          enhancedSchedule['sportName'] = 'Unknown Sport';
        }

        enhancedSchedules.add(enhancedSchedule);
      }

      return enhancedSchedules;
    });
  }

  Stream<List<Map<String, dynamic>>> getTeamSchedulesByTournament(
      String tournamentId,
      {int limit = 500,
      DocumentSnapshot? startAfter}) {
    Query query = _collection
        .where('tournamentSetupId', isEqualTo: tournamentId)
        .orderBy('dateTime', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList());
  }

  Future<void> updateTeamSchedule(
      String id, Map<String, dynamic> updatedTeamSchedule) async {
    await _collection.doc(id).update(updatedTeamSchedule);
  }

  Future<void> deleteTeamSchedule(String id) async {
    await _collection.doc(id).delete();
  }

  Future<bool> doesMatchupExist(List<String> teams,
      {String? tournamentId, String? excludeId}) async {
    if (teams.length != 2) return false;
    final teamA = teams[0];
    final teamB = teams[1];

    Query query = _collection.where('teams', arrayContainsAny: [teamA, teamB]);

    if (tournamentId != null) {
      query = query.where('tournamentSetupId', isEqualTo: tournamentId);
    }

    final snapshot = await query.get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docTeams = data['teams'] as List<dynamic>? ?? [];
      if (doc.id == excludeId) continue;
      if (docTeams.length == 2) {
        final containsBoth =
            (docTeams.contains(teamA) && docTeams.contains(teamB));
        if (containsBoth) {
          return true;
        }
      }
    }
    return false;
  }
}
