import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class TournamentVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SportsEventService _sportsEventService = SportsEventService();

  Future<void> verifyTournament(String tournamentId) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception(
            'No active sports event found. Cannot verify tournament.');
      }
      // Check if tournament document exists
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        // Create missing tournament document with basic info
        await _firestore.collection('tournaments').doc(tournamentId).set({
          'id': tournamentId,
          'name': 'Unknown Tournament',
          'status': 'pending',
          'sportsEventId': activeEventId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update tournament document with verification info
      await _firestore.collection('tournaments').doc(tournamentId).set({
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Create or update verification record
      await _firestore
          .collection('tournament_verifications')
          .doc(tournamentId)
          .set({
        'tournamentId': tournamentId,
        'sportsEventId': activeEventId,
        'isVerified': true,
        'verifiedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error verifying tournament: $e');
    }
  }

  Future<void> unverifyTournament(String tournamentId) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception(
            'No active sports event found. Cannot unverify tournament.');
      }
      // Check if tournament document exists
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();

      if (!tournamentDoc.exists) {
        // Create missing tournament document with basic info
        await _firestore.collection('tournaments').doc(tournamentId).set({
          'id': tournamentId,
          'name': 'Unknown Tournament',
          'status': 'pending',
          'sportsEventId': activeEventId,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Update tournament document with unverification info
      await _firestore.collection('tournaments').doc(tournamentId).set({
        'isVerified': false,
        'unverifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update verification record
      await _firestore
          .collection('tournament_verifications')
          .doc(tournamentId)
          .set({
        'tournamentId': tournamentId,
        'sportsEventId': activeEventId,
        'isVerified': false,
        'unverifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Error unverifying tournament: $e');
    }
  }

  Future<bool> isTournamentVerified(String tournamentId) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        return false;
      }
      final tournamentDoc =
          await _firestore.collection('tournaments').doc(tournamentId).get();
      if (tournamentDoc.exists &&
          tournamentDoc.data()?['sportsEventId'] == activeEventId) {
        return tournamentDoc.data()?['isVerified'] == true;
      }
      return false;
    } catch (e) {
      throw Exception('Error checking tournament verification: $e');
    }
  }

  Stream<QuerySnapshot> getVerifiedTournaments() async* {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      yield* const Stream.empty();
    } else {
      yield* _firestore
          .collection('tournaments')
          .where('sportsEventId', isEqualTo: activeEventId)
          .where('isVerified', isEqualTo: true)
          .snapshots();
    }
  }

  Future<List<Map<String, dynamic>>> getVerifiedTournamentsList() async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        return [];
      }
      final snapshot = await _firestore
          .collection('tournaments')
          .where('sportsEventId', isEqualTo: activeEventId)
          .where('isVerified', isEqualTo: true)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      throw Exception('Error getting verified tournaments list: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUnverifiedTournamentsList() async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        return [];
      }
      final snapshot = await _firestore
          .collection('tournaments')
          .where('sportsEventId', isEqualTo: activeEventId)
          .where('isVerified', isEqualTo: false)
          .get();
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    } catch (e) {
      throw Exception('Error getting unverified tournaments list: $e');
    }
  }

  Stream<QuerySnapshot> streamVerificationStatus(String tournamentId) async* {
    String? activeEventId = await _sportsEventService.getActiveSportsEventId();
    if (activeEventId == null) {
      yield* const Stream.empty();
    } else {
      yield* _firestore
          .collection('tournament_verifications')
          .where('sportsEventId', isEqualTo: activeEventId)
          .where('tournamentId', isEqualTo: tournamentId)
          .snapshots();
    }
  }

  Future<void> verifyTournamentResults(String tournamentId) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception(
            'No active sports event found. Cannot verify tournament results.');
      }
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'resultsVerified': true,
        'resultsVerifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error verifying tournament results: $e');
    }
  }

  Future<void> unverifyTournamentResults(String tournamentId) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception(
            'No active sports event found. Cannot unverify tournament results.');
      }
      await _firestore.collection('tournaments').doc(tournamentId).update({
        'resultsVerified': false,
        'resultsUnverifiedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error unverifying tournament results: $e');
    }
  }
}
