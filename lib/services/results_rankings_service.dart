// services/tournament_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Tournament {
  final String id;
  final String name;
  final String sport;
  final String category;
  final String gender;
  final String venue;
  final String bracketType;
  final String eliminationType;
  final String status;
  final int totalMatches;
  final Map<String, dynamic> medals;
  final List<String> selectedTeamIds;
  final List<String> assignedUsers;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool randomize;

  Tournament({
    required this.id,
    required this.name,
    required this.sport,
    required this.category,
    required this.gender,
    required this.venue,
    required this.bracketType,
    required this.eliminationType,
    required this.status,
    required this.totalMatches,
    required this.medals,
    required this.selectedTeamIds,
    required this.assignedUsers,
    required this.createdAt,
    required this.updatedAt,
    required this.randomize,
  });

  factory Tournament.fromFirestore(Map<String, dynamic> data, String id) {
    return Tournament(
      id: id,
      name: data['name'] ?? '',
      sport: data['sport'] ?? '',
      category: data['category'] ?? '',
      gender: data['gender'] ?? '',
      venue: data['venue'] ?? '',
      bracketType: data['bracketType'] ?? '',
      eliminationType: data['eliminationType'] ?? '',
      status: data['status'] ?? '',
      totalMatches: data['totalMatches'] ?? 0,
      medals: Map<String, dynamic>.from(data['medals'] ?? {}),
      selectedTeamIds: List<String>.from(data['selectedTeamIds'] ?? []),
      assignedUsers: List<String>.from(data['assignedUsers'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      randomize: data['randomize'] ?? false,
    );
  }
}

class Participant {
  final String id;
  final String name;
  final String coachName;
  final String contactInfo;
  final String imageBase64;
  final List<dynamic> medals;
  final int participationGold;
  final String sportsEventId;
  final DateTime dateCreated;

  Participant({
    required this.id,
    required this.name,
    required this.coachName,
    required this.contactInfo,
    required this.imageBase64,
    required this.medals,
    required this.participationGold,
    required this.sportsEventId,
    required this.dateCreated,
  });

  factory Participant.fromFirestore(Map<String, dynamic> data, String id) {
    return Participant(
      id: id,
      name: data['name'] ?? '',
      coachName: data['coachName'] ?? '',
      contactInfo: data['contactInfo'] ?? '',
      imageBase64: data['imageBase64'] ?? '',
      medals: data['medals'] ?? [],
      participationGold: data['participationGold'] ?? 0,
      sportsEventId: data['sportsEventId'] ?? '',
      dateCreated: (data['dateCreated'] as Timestamp).toDate(),
    );
  }
}

class TeamRanking {
  final String teamId;
  int goldCount;
  int silverCount;
  int bronzeCount;
  int totalMedals;
  String? teamName;
  String? coachName;
  String? imageBase64;

  TeamRanking({
    required this.teamId,
    this.goldCount = 0,
    this.silverCount = 0,
    this.bronzeCount = 0,
    this.totalMedals = 0,
    this.teamName,
    this.coachName,
    this.imageBase64,
  });

  void calculateTotalMedals() {
    totalMedals = goldCount + silverCount + bronzeCount;
  }

  int get medalPoints => (goldCount * 3) + (silverCount * 2) + (bronzeCount * 1);
}

class TournamentResultsRankingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Tournament>> fetchAllTournaments() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('tournaments')
          .where('status', isEqualTo: 'active')
          .get();

      return querySnapshot.docs
          .map((doc) => Tournament.fromFirestore(
                doc.data() as Map<String, dynamic>,
                doc.id,
              ))
          .toList();
    } catch (e) {
      print('Error fetching tournaments: $e');
      return [];
    }
  }

  Future<Map<String, Participant>> fetchParticipants(List<String> teamIds) async {
    Map<String, Participant> participants = {};
    
    if (teamIds.isEmpty) return participants;
    
    try {
      // Fetch all participants
      for (var teamId in teamIds) {
        if (teamId.isNotEmpty) {
          DocumentSnapshot doc = await _firestore.collection('participants').doc(teamId).get();
          if (doc.exists) {
            participants[teamId] = Participant.fromFirestore(
              doc.data() as Map<String, dynamic>,
              doc.id,
            );
          }
        }
      }
      return participants;
    } catch (e) {
      print('Error fetching participants: $e');
      return participants;
    }
  }

  Future<Map<String, TeamRanking>> calculateRankings(
    List<Tournament> tournaments,
    Map<String, Participant> participants,
  ) async {
    Map<String, TeamRanking> rankings = {};

    for (var tournament in tournaments) {
      // Process gold medal
      if (tournament.medals.containsKey('gold') && tournament.medals['gold'] != null) {
        String goldTeamId = tournament.medals['gold'];
        rankings.putIfAbsent(goldTeamId, () => TeamRanking(teamId: goldTeamId));
        rankings[goldTeamId]!.goldCount++;
      }

      // Process silver medal
      if (tournament.medals.containsKey('silver') && tournament.medals['silver'] != null) {
        String silverTeamId = tournament.medals['silver'];
        rankings.putIfAbsent(silverTeamId, () => TeamRanking(teamId: silverTeamId));
        rankings[silverTeamId]!.silverCount++;
      }

      // Process bronze medal
      if (tournament.medals.containsKey('bronze') && tournament.medals['bronze'] != null) {
        String bronzeTeamId = tournament.medals['bronze'];
        rankings.putIfAbsent(bronzeTeamId, () => TeamRanking(teamId: bronzeTeamId));
        rankings[bronzeTeamId]!.bronzeCount++;
      }

      // Also count team participation from selectedTeamIds
      for (var teamId in tournament.selectedTeamIds) {
        rankings.putIfAbsent(teamId, () => TeamRanking(teamId: teamId));
      }
    }

    // Add participant details to rankings
    for (var ranking in rankings.values) {
      if (participants.containsKey(ranking.teamId)) {
        ranking.teamName = participants[ranking.teamId]!.name;
        ranking.coachName = participants[ranking.teamId]!.coachName;
        ranking.imageBase64 = participants[ranking.teamId]!.imageBase64;
      }
      ranking.calculateTotalMedals();
    }

    return rankings;
  }

  List<TeamRanking> sortRankings(Map<String, TeamRanking> rankings) {
    return rankings.values.toList()
      ..sort((a, b) {
        if (a.goldCount != b.goldCount) {
          return b.goldCount.compareTo(a.goldCount);
        }
        if (a.silverCount != b.silverCount) {
          return b.silverCount.compareTo(a.silverCount);
        }
        if (a.bronzeCount != b.bronzeCount) {
          return b.bronzeCount.compareTo(a.bronzeCount);
        }
        return b.totalMedals.compareTo(a.totalMedals);
      });
  }
}