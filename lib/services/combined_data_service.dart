import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_list.dart';
import 'package:tabulation_systemv7/services/sports_category.dart';
import 'package:tabulation_systemv7/services/tournament_service.dart';
import 'package:tabulation_systemv7/services/match_schedule_service.dart';

class CombinedDataService {
  final SportsService _sportsService = SportsService();
  final SportCategoryService _categoryService = SportCategoryService();
  final TournamentService _tournamentService = TournamentService();
  final MatchScheduleService _scheduleService = MatchScheduleService();

  Stream<QuerySnapshot> getSportsStream() {
    return _sportsService.getSportsStream();
  }

  Stream<QuerySnapshot> getCategoriesStream() {
    return _categoryService.getCategories();
  }

  Stream<QuerySnapshot> getTournamentsStream() {
    return _tournamentService.getTournamentStream();
  }

  Stream<List<Map<String, dynamic>>> getMatchSchedulesStream({String? tournamentId}) {
    return _scheduleService.getAllMatchSchedules(tournamentId: tournamentId);
  }

  /// Example method to fetch combined data if needed
  Future<Map<String, dynamic>> fetchCombinedData() async {
    final sportsSnapshot = await _sportsService.getSportsStream().first;
    final categoriesSnapshot = await _categoryService.getCategories().first;
    final tournamentsSnapshot = await _tournamentService.getTournamentStream().first;
    final schedules = await _scheduleService.getAllMatchSchedules().first;

    return {
      'sports': sportsSnapshot.docs.map((doc) => doc.data()).toList(),
      'categories': categoriesSnapshot.docs.map((doc) => doc.data()).toList(),
      'tournaments': tournamentsSnapshot.docs.map((doc) => doc.data()).toList(),
      'schedules': schedules,
    };
  }
}
