import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class ParticipantsService {
  final CollectionReference _participantsCollection =
      FirebaseFirestore.instance.collection('participants');
  final SportsEventService _sportsEventService = SportsEventService();

  // Fetch Participants (Stream for Real-Time Updates)
  Stream<QuerySnapshot> getParticipantsStream() async* {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      yield* const Stream.empty();
    } else {
      yield* _participantsCollection
          .where('sportsEventId', isEqualTo: activeEventId)
          .snapshots();
    }
  }

  // Add Participant
  Future<void> addParticipant(Map<String, dynamic> participantData) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception(
            'No active sports event found. Cannot add participant.');
      }
      // Create a new map with FieldValue for dateCreated and initialize rewards
      Map<String, Object> dataWithTimestamp =
          Map<String, Object>.from(participantData);
      dataWithTimestamp['dateCreated'] = FieldValue.serverTimestamp();
      dataWithTimestamp['participationGold'] =
          participantData['participationGold'] ?? 0;
      dataWithTimestamp['medals'] = participantData['medals'] ?? [];
      dataWithTimestamp['sportsEventId'] = activeEventId;
      await _participantsCollection.add(dataWithTimestamp);
    } catch (e) {
      throw Exception('Error adding participant: $e');
    }
  }

  // Update Participant
  Future<void> updateParticipant(
      String docId, Map<String, dynamic> updatedData) async {
    try {
      // Ensure dateCreated is not overwritten during updates
      await _participantsCollection.doc(docId).update(updatedData);
    } catch (e) {
      throw Exception('Error updating participant: $e');
    }
  }

  // Delete Participant
  Future<void> deleteParticipant(String docId) async {
    try {
      await _participantsCollection.doc(docId).delete();
    } catch (e) {
      throw Exception('Error deleting participant: $e');
    }
  }

  // Update Participant Rewards
  Future<void> updateParticipantRewards(
      String docId, int participationGold, List<String> medals) async {
    try {
      await _participantsCollection.doc(docId).update({
        'participationGold': participationGold,
        'medals': medals,
      });
    } catch (e) {
      throw Exception('Error updating participant rewards: $e');
    }
  }

  // Award Participation Gold to Tournament Participants
  Future<void> awardParticipationGoldToTournament(String tournamentId) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception('No active sports event found.');
      }
      // Get all teams that participated in the tournament
      final teamsSnapshot = await FirebaseFirestore.instance
          .collection('teams')
          .where('tournamentId', isEqualTo: tournamentId)
          .where('sportsEventId', isEqualTo: activeEventId)
          .get();

      for (var teamDoc in teamsSnapshot.docs) {
        final teamData = teamDoc.data();
        final participants = teamData['participants'] as List<dynamic>? ?? [];

        // Award gold to each participant in the team
        for (var participantName in participants) {
          final participantSnapshot = await _participantsCollection
              .where('name', isEqualTo: participantName)
              .get();
          if (participantSnapshot.docs.isNotEmpty) {
            final participantDoc = participantSnapshot.docs.first;
            final participantId = participantDoc.id;
            Map<String, dynamic> data =
                participantDoc.data() as Map<String, dynamic>;
            final currentGold = data['participationGold'] ?? 0;
            final currentMedals = List<String>.from(data['medals'] ?? []);
            await updateParticipantRewards(
                participantId, currentGold + 1, currentMedals);
          }
        }
      }
    } catch (e) {
      throw Exception('Error awarding participation gold: $e');
    }
  }

  // Award Medals to Team Participants
  Future<void> awardMedalsToTeamParticipants(
      List<String> participantIds, String medal) async {
    try {
      for (String participantId in participantIds) {
        DocumentSnapshot doc =
            await _participantsCollection.doc(participantId).get();
        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          List<String> currentMedals = List<String>.from(data['medals'] ?? []);
          currentMedals.add(medal);
          await _participantsCollection.doc(participantId).update({
            'medals': currentMedals,
          });
        }
      }
    } catch (e) {
      throw Exception('Error awarding medals: $e');
    }
  }

  // Get Active Sports Event ID
  Future<String?> getActiveSportsEventId() async {
    return await _sportsEventService.getActiveSportsEventId();
  }
}
