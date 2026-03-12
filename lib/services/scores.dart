import 'package:tabulation_systemv7/services/team_schedule_service.dart';

class ScoresService {
  final TeamScheduleService _teamScheduleService = TeamScheduleService();

  /// Updates the scores for the given team schedule and determines the winner.
  /// [teamScheduleId] is the ID of the team schedule document.
  /// [scores] is a map with team names as keys and their scores as values.
  Future<void> updateScoresAndWinner(String teamScheduleId, Map<String, int> scores) async {
    if (scores.length != 2) {
      throw ArgumentError('Scores must be provided for exactly two teams.');
    }

    final teams = scores.keys.toList();
    final score1 = scores[teams[0]]!;
    final score2 = scores[teams[1]]!;

    String? winner;
    if (score1 > score2) {
      winner = teams[0];
    } else if (score2 > score1) {
      winner = teams[1];
    } else {
      winner = null; // Tie or no winner yet
    }

    final updateData = {
      'scores': scores,
      'winner': winner,
    };

    await _teamScheduleService.updateTeamSchedule(teamScheduleId, updateData);
  }
}
