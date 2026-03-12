import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_event_service.dart';

class LogoService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SportsEventService _sportsEventService = SportsEventService();

  Future<void> uploadLogo(String logoName, String logoUrl) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        throw Exception('No active sports event found. Cannot upload logo.');
      }
      await _firestore.collection('logos').doc(logoName).set({
        'name': logoName,
        'url': logoUrl,
        'sportsEventId': activeEventId,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error uploading logo: $e');
    }
  }

  Future<String?> getLogoUrl(String logoName) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        return null;
      }
      final doc = await _firestore.collection('logos').doc(logoName).get();
      if (doc.exists && doc.data()?['sportsEventId'] == activeEventId) {
        return doc.data()?['url'] as String?;
      }
      return null;
    } catch (e) {
      throw Exception('Error getting logo URL: $e');
    }
  }

  Future<bool> logoExists(String logoName) async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        return false;
      }
      final doc = await _firestore.collection('logos').doc(logoName).get();
      return doc.exists && doc.data()?['sportsEventId'] == activeEventId;
    } catch (e) {
      throw Exception('Error checking logo existence: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllLogos() async {
    try {
      String? activeEventId =
          await _sportsEventService.getActiveSportsEventId();
      if (activeEventId == null) {
        return [];
      }
      final snapshot = await _firestore
          .collection('logos')
          .where('sportsEventId', isEqualTo: activeEventId)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      throw Exception('Error getting all logos: $e');
    }
  }

  Future<void> deleteLogo(String logoName) async {
    try {
      await _firestore.collection('logos').doc(logoName).delete();
    } catch (e) {
      throw Exception('Error deleting logo: $e');
    }
  }
}
