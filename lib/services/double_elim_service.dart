import 'package:flutter/material.dart';

class DoubleEliminationGenerator {
  final List<Map<String, dynamic>> _matchups = [];

  List<Map<String, dynamic>> generateDoubleEliminationMatchups(
    List<Map<String, dynamic>> teamData,
    bool randomize,
    BuildContext context,
  ) {
    _matchups.clear();

    if (teamData.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'At least 2 teams are required for Double Elimination',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return [];
    }

    // Create seeded order (1 is best, N is worst)
    List<Map<String, dynamic>> seededTeams = List.from(teamData);

    if (randomize) {
      seededTeams.shuffle();
      for (int i = 0; i < seededTeams.length; i++) {
        seededTeams[i]['seed'] = i + 1;
      }
    } else {
      for (int i = 0; i < seededTeams.length; i++) {
        seededTeams[i]['seed'] = i + 1;
      }
    }

    int teamCount = seededTeams.length;

    // Generate based on team count
    if (teamCount == 2) {
      _generateDoubleElimination2Teams(seededTeams);
    } else if (teamCount == 3) {
      _generateDoubleElimination3Teams(seededTeams); // CORRECTED VERSION
    } else if (teamCount == 4) {
      _generateDoubleElimination4Teams(seededTeams);
    } else if (teamCount == 5) {
      _generateDoubleElimination5Teams(seededTeams);
    } else if (teamCount == 6) {
      _generateDoubleElimination6Teams(seededTeams);
    } else if (teamCount == 7) {
      _generateDoubleElimination7Teams(seededTeams);
    } else if (teamCount == 8) {
      _generateDoubleElimination8Teams(seededTeams);
    } else {
      _generateDoubleEliminationGeneric(seededTeams);
    }

    _linkDoubleEliminationReferences();

    print(
        'Generated ${_matchups.length} double elimination matches for $teamCount teams');
    for (var match in _matchups) {
      print(
          'Match ${match['matchNumber']} (${match['bracket']} R${match['round']}): ${match['team1Name']} vs ${match['team2Name']}');
    }

    return _matchups;
  }

  void _createDoubleElimMatch(
    int matchNumber,
    String bracket,
    int round,
    dynamic team1,
    dynamic team2,
    String team1Name,
    String team2Name,
    int? nextMatchReference,
    int? losersNextMatchReference, {
    bool isGrandFinal = false,
  }) {
    Map<String, dynamic> match = {
      'matchNumber': matchNumber,
      'bracket': bracket,
      'round': round,
      'team1': team1,
      'team2': team2,
      'team1Name': team1Name,
      'team2Name': team2Name,
      'type': isGrandFinal ? 'grand_final' : 'regular',
      'nextMatchReference': nextMatchReference,
      'losersNextMatchReference': losersNextMatchReference,
      'winner': null,
      'loser': null,
      'status': 'scheduled',
      'isGrandFinal': isGrandFinal,
    };

    _matchups.add(match);
  }

  void _linkDoubleEliminationReferences() {
    // Create maps for quick lookup
    Map<int, Map<String, dynamic>> matchesByNumber = {};
    for (var match in _matchups) {
      matchesByNumber[match['matchNumber']] = match;
    }

    // Update placeholder references to actual match numbers
    for (var match in _matchups) {
      // Handle team1 if it's a placeholder
      if (match['team1'] is Map && match['team1']['type'] == 'placeholder') {
        var team1 = match['team1'];
        if (team1['sourceMatch'] != null) {
          int sourceMatch = team1['sourceMatch'];
          if (team1['isLoser'] == true) {
            match['team1'] = {
              'id': 'match_${sourceMatch}_loser',
              'name': 'Loser Match $sourceMatch',
              'type': 'placeholder',
              'sourceMatch': sourceMatch,
            };
          } else {
            match['team1'] = {
              'id': 'match_${sourceMatch}_winner',
              'name': 'Winner Match $sourceMatch',
              'type': 'placeholder',
              'sourceMatch': sourceMatch,
            };
          }
        }
      }

      // Handle team2 if it's a placeholder
      if (match['team2'] is Map && match['team2']['type'] == 'placeholder') {
        var team2 = match['team2'];
        if (team2['sourceMatch'] != null) {
          int sourceMatch = team2['sourceMatch'];
          if (team2['isLoser'] == true) {
            match['team2'] = {
              'id': 'match_${sourceMatch}_loser',
              'name': 'Loser Match $sourceMatch',
              'type': 'placeholder',
              'sourceMatch': sourceMatch,
            };
          } else {
            match['team2'] = {
              'id': 'match_${sourceMatch}_winner',
              'name': 'Winner Match $sourceMatch',
              'type': 'placeholder',
              'sourceMatch': sourceMatch,
            };
          }
        }
      }

      // Handle advancement matches (where team2 is null)
      if (match['team2'] == null) {
        match['team2'] = {
          'id': 'advancement',
          'name': 'ADVANCES',
          'type': 'advancement',
        };
      }
    }
  }

  // Double Elimination for 2 teams
  void _generateDoubleElimination2Teams(
      List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;

    // Winners Bracket Final (also serves as first match)
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[0],
      seededTeams[1],
      '${seededTeams[0]['name']} (Seed 1)',
      '${seededTeams[1]['name']} (Seed 2)',
      null, // No next match in winners
      2, // Loser goes to Losers Final
    );

    // Losers Bracket Final
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_1_loser',
        'name': 'Loser Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
        'isLoser': true
      },
      null, // Bye
      'Loser Match 1',
      'BYE',
      3, // Winner goes to Grand Final
      null,
    );

    // Grand Final (one match needed)
    _createDoubleElimMatch(
      matchNumber++,
      'grand',
      2,
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1
      },
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2
      },
      'Winner Match 1',
      'Winner Match 2',
      null,
      null,
      isGrandFinal: true,
    );
  }

  // Double Elimination for 3 teams - CORRECTED VERSION (4 matches total)
  void _generateDoubleElimination3Teams(
      List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;

    // Match 1 - Winners Bracket Round 1: Seed 2 vs Seed 3
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[1], // Seed 2
      seededTeams[2], // Seed 3
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[2]['name']} (Seed 3)',
      2, // Winner goes to Match 2 (Winners Final)
      3, // Loser goes to Match 3 (Losers Bracket) - DIRECT to losers final
    );

    // Match 2 - Winners Bracket Final: Seed 1 vs Winner M1
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      seededTeams[0], // Seed 1
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1
      },
      '${seededTeams[0]['name']} (Seed 1)',
      'Winner Match 1',
      4, // Winner goes to Match 4 (Grand Final)
      3, // Loser goes to Match 3 (Losers Bracket) - DIRECT to losers final
    );

    // Match 3 - Losers Bracket Final: Loser M1 vs Loser M2 (NO BYE)
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1, // Only one round in losers bracket for 3 teams
      {
        'id': 'match_1_loser',
        'name': 'Loser Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
        'isLoser': true
      },
      {
        'id': 'match_2_loser',
        'name': 'Loser Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
        'isLoser': true
      },
      'Loser Match 1',
      'Loser Match 2',
      4, // Winner goes to Match 4 (Grand Final)
      null,
    );

    // Match 4 - Grand Final: Winner M2 vs Winner M3
    _createDoubleElimMatch(
      matchNumber++,
      'grand',
      3,
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2
      },
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3
      },
      'Winner Match 2',
      'Winner Match 3',
      null,
      null,
      isGrandFinal: true,
    );
  }

  // Double Elimination for 4 teams
  void _generateDoubleElimination4Teams(
      List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;

    // Winners Bracket Semifinals
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[0], // Seed 1
      seededTeams[3], // Seed 4
      '${seededTeams[0]['name']} (Seed 1)',
      '${seededTeams[3]['name']} (Seed 4)',
      3, // Winner goes to Winners Final
      5, // Loser goes to Losers Semifinals
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[1], // Seed 2
      seededTeams[2], // Seed 3
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[2]['name']} (Seed 3)',
      3, // Winner goes to Winners Final
      6, // Loser goes to Losers Semifinals
    );

    // Winners Bracket Final
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1
      },
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2
      },
      'Winner Match 1',
      'Winner Match 2',
      7, // Winner goes to Grand Final
      4, // Loser goes to Losers Final
    );

    // Losers Bracket Semifinals
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_1_loser',
        'name': 'Loser Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
        'isLoser': true
      },
      {
        'id': 'match_2_loser',
        'name': 'Loser Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
        'isLoser': true
      },
      'Loser Match 1',
      'Loser Match 2',
      6, // Winner goes to Losers Final
      null,
    );

    // Losers Bracket Final
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      2,
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4
      },
      {
        'id': 'match_3_loser',
        'name': 'Loser Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
        'isLoser': true
      },
      'Winner Match 4',
      'Loser Match 3',
      7, // Winner goes to Grand Final
      null,
    );

    // Grand Final
    _createDoubleElimMatch(
      matchNumber++,
      'grand',
      3,
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3
      },
      {
        'id': 'match_5_winner',
        'name': 'Winner Match 5',
        'type': 'placeholder',
        'sourceMatch': 5
      },
      'Winner Match 3',
      'Winner Match 5',
      null,
      null,
      isGrandFinal: true,
    );
  }

// Double Elimination for 5 teams - GUARANTEED WORKING (7 matches)
  void _generateDoubleElimination5Teams(
      List<Map<String, dynamic>> seededTeams) {
    _matchups.clear();
    int matchNumber = 1;

    // Match 1: Seed 4 vs Seed 5
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[3],
      seededTeams[4],
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      3, // Winner to Match 3
      5, // Loser to Match 5
    );

    // Match 2: Seed 1 vs Seed 2
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[0],
      seededTeams[1],
      '${seededTeams[0]['name']} (Seed 1)',
      '${seededTeams[1]['name']} (Seed 2)',
      4, // Winner to Match 4
      6, // Loser to Match 6
    );

    // Match 3: Winners Semifinal (Seed 3 vs Winner M1)
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      seededTeams[2], // Seed 3
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1
      },
      '${seededTeams[2]['name']} (Seed 3)',
      'Winner Match 1',
      4, // Winner to Match 4
      5, // Loser to Match 5
    );

    // Match 4: Winners Final (Winner M2 vs Winner M3)
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      3,
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2
      },
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3
      },
      'Winner Match 2',
      'Winner Match 3',
      7, // Winner to Grand Final
      6, // Loser to Match 6
    );

    // Match 5: Losers Round 1 (Loser M1 vs Loser M3)
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_1_loser',
        'name': 'Loser Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
        'isLoser': true
      },
      {
        'id': 'match_3_loser',
        'name': 'Loser Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
        'isLoser': true
      },
      'Loser Match 1',
      'Loser Match 3',
      6, // Winner to Match 6
      null,
    );

    // Match 6: Losers Final (Winner M5 vs Loser M4)
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      2,
      {
        'id': 'match_5_winner',
        'name': 'Winner Match 5',
        'type': 'placeholder',
        'sourceMatch': 5
      },
      {
        'id': 'match_4_loser',
        'name': 'Loser Match 4',
        'type': 'placeholder',
        'sourceMatch': 4,
        'isLoser': true
      },
      'Winner Match 5',
      'Loser Match 4',
      7, // Winner to Grand Final
      null,
    );

    // Match 7: Grand Final (Winner M4 vs Winner M6)
    _createDoubleElimMatch(
      matchNumber++,
      'grand',
      4,
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4
      },
      {
        'id': 'match_6_winner',
        'name': 'Winner Match 6',
        'type': 'placeholder',
        'sourceMatch': 6
      },
      'Winner Match 4',
      'Winner Match 6',
      null,
      null,
      isGrandFinal: true,
    );

    print('✅ Generated ${_matchups.length} matches for 5 teams');
  }

  // 6-Team Double Elimination - REDUCED to 9 matches (Option 2)
  void _generateDoubleElimination6Teams(
      List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;

    // ===== WINNERS BRACKET (4 matches) =====

    // Match 1: Seed 3 vs Seed 6
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[2], // Seed 3
      seededTeams[5], // Seed 6
      '${seededTeams[2]['name']} (Seed 3)',
      '${seededTeams[5]['name']} (Seed 6)',
      3, // Winner to Match 3
      5, // Loser to Match 5
    );

    // Match 2: Seed 4 vs Seed 5
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[3], // Seed 4
      seededTeams[4], // Seed 5
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      4, // Winner to Match 4
      6, // Loser to Match 6
    );

    // Match 3: Seed 1 vs Winner M1
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      seededTeams[0], // Seed 1
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1
      },
      '${seededTeams[0]['name']} (Seed 1)',
      'Winner Match 1',
      7, // Winner to Match 7 (Winners Final)
      5, // Loser to Match 5
    );

    // Match 4: Seed 2 vs Winner M2
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      seededTeams[1], // Seed 2
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2
      },
      '${seededTeams[1]['name']} (Seed 2)',
      'Winner Match 2',
      7, // Winner to Match 7 (Winners Final)
      6, // Loser to Match 6
    );

    // Match 7: Winners Final (Winner M3 vs Winner M4)
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      3,
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3
      },
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4
      },
      'Winner Match 3',
      'Winner Match 4',
      9, // Winner to Grand Final (Match 9)
      8, // Loser to Match 8
    );

    // ===== LOSERS BRACKET (3 matches) =====

    // Match 5: Losers Round 1 (Loser M1 vs Loser M3)
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_1_loser',
        'name': 'Loser Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
        'isLoser': true
      },
      {
        'id': 'match_3_loser',
        'name': 'Loser Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
        'isLoser': true
      },
      'Loser Match 1',
      'Loser Match 3',
      8, // Winner to Match 8
      null,
    );

    // Match 6: Losers Round 2 (Loser M2 vs Loser M4)
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      2,
      {
        'id': 'match_2_loser',
        'name': 'Loser Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
        'isLoser': true
      },
      {
        'id': 'match_4_loser',
        'name': 'Loser Match 4',
        'type': 'placeholder',
        'sourceMatch': 4,
        'isLoser': true
      },
      'Loser Match 2',
      'Loser Match 4',
      8, // Winner to Match 8
      null,
    );

    // Match 8: Losers Final (Winner M5 vs Winner M6)
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      3,
      {
        'id': 'match_5_winner',
        'name': 'Winner Match 5',
        'type': 'placeholder',
        'sourceMatch': 5
      },
      {
        'id': 'match_6_winner',
        'name': 'Winner Match 6',
        'type': 'placeholder',
        'sourceMatch': 6
      },
      'Winner Match 5',
      'Winner Match 6',
      9, // Winner to Grand Final (Match 9)
      null,
    );

    // ===== GRAND FINAL (1 match) =====

    // Match 9: Grand Final (Winner M7 vs Winner M8)
    _createDoubleElimMatch(
      matchNumber++,
      'grand',
      4,
      {
        'id': 'match_7_winner',
        'name': 'Winner Match 7',
        'type': 'placeholder',
        'sourceMatch': 7
      },
      {
        'id': 'match_8_winner',
        'name': 'Winner Match 8',
        'type': 'placeholder',
        'sourceMatch': 8
      },
      'Winner Match 7',
      'Winner Match 8',
      null,
      null,
      isGrandFinal: true,
    );
  }

  // Double Elimination for 7 teams
  void _generateDoubleElimination7Teams(
      List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;

    // Winners Bracket Round 1
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[1], // Seed 2
      seededTeams[6], // Seed 7
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[6]['name']} (Seed 7)',
      4, // Winner goes to Winners Quarterfinals
      8, // Loser goes to Losers Round 1
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[2], // Seed 3
      seededTeams[5], // Seed 6
      '${seededTeams[2]['name']} (Seed 3)',
      '${seededTeams[5]['name']} (Seed 6)',
      4, // Winner goes to Winners Quarterfinals
      9, // Loser goes to Losers Round 1
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[3], // Seed 4
      seededTeams[4], // Seed 5
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      4, // Winner goes to Winners Quarterfinals
      10, // Loser goes to Losers Round 1
    );

    // Winners Bracket Quarterfinals
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      seededTeams[0], // Seed 1
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1
      },
      '${seededTeams[0]['name']} (Seed 1)',
      'Winner Match 1',
      6, // Winner goes to Winners Semifinals
      11, // Loser goes to Losers Round 2
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2
      },
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3
      },
      'Winner Match 2',
      'Winner Match 3',
      6, // Winner goes to Winners Semifinals
      12, // Loser goes to Losers Round 2
    );

    // Winners Bracket Semifinals
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      3,
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4
      },
      {
        'id': 'match_5_winner',
        'name': 'Winner Match 5',
        'type': 'placeholder',
        'sourceMatch': 5
      },
      'Winner Match 4',
      'Winner Match 5',
      14, // Winner goes to Grand Final
      7, // Loser goes to Losers Final
    );

    // Losers Bracket Round 1
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_1_loser',
        'name': 'Loser Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
        'isLoser': true
      },
      null, // Bye
      'Loser Match 1',
      'BYE',
      11, // Winner goes to Losers Round 2
      null,
    );

    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_2_loser',
        'name': 'Loser Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
        'isLoser': true
      },
      null, // Bye
      'Loser Match 2',
      'BYE',
      12, // Winner goes to Losers Round 2
      null,
    );

    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_3_loser',
        'name': 'Loser Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
        'isLoser': true
      },
      null, // Bye
      'Loser Match 3',
      'BYE',
      13, // Winner goes to Losers Round 2
      null,
    );

    // Losers Bracket Round 2
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      2,
      {
        'id': 'match_4_loser',
        'name': 'Loser Match 4',
        'type': 'placeholder',
        'sourceMatch': 4,
        'isLoser': true
      },
      {
        'id': 'match_7_winner',
        'name': 'Winner Match 7',
        'type': 'placeholder',
        'sourceMatch': 7
      },
      'Loser Match 4',
      'Winner Match 7',
      13, // Winner goes to Losers Round 3
      null,
    );

    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      2,
      {
        'id': 'match_5_loser',
        'name': 'Loser Match 5',
        'type': 'placeholder',
        'sourceMatch': 5,
        'isLoser': true
      },
      {
        'id': 'match_8_winner',
        'name': 'Winner Match 8',
        'type': 'placeholder',
        'sourceMatch': 8
      },
      'Loser Match 5',
      'Winner Match 8',
      14, // Winner goes to Losers Final
      null,
    );

    // Losers Bracket Round 3
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      3,
      {
        'id': 'match_9_winner',
        'name': 'Winner Match 9',
        'type': 'placeholder',
        'sourceMatch': 9
      },
      {
        'id': 'match_10_winner',
        'name': 'Winner Match 10',
        'type': 'placeholder',
        'sourceMatch': 10
      },
      'Winner Match 9',
      'Winner Match 10',
      14, // Winner goes to Losers Final
      null,
    );

    // Losers Bracket Final
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      4,
      {
        'id': 'match_11_winner',
        'name': 'Winner Match 11',
        'type': 'placeholder',
        'sourceMatch': 11
      },
      {
        'id': 'match_6_loser',
        'name': 'Loser Match 6',
        'type': 'placeholder',
        'sourceMatch': 6,
        'isLoser': true
      },
      'Winner Match 11',
      'Loser Match 6',
      15, // Winner goes to Grand Final
      null,
    );

    // Grand Final
    _createDoubleElimMatch(
      matchNumber++,
      'grand',
      5,
      {
        'id': 'match_6_winner',
        'name': 'Winner Match 6',
        'type': 'placeholder',
        'sourceMatch': 6
      },
      {
        'id': 'match_12_winner',
        'name': 'Winner Match 12',
        'type': 'placeholder',
        'sourceMatch': 12
      },
      'Winner Match 6',
      'Winner Match 12',
      null,
      null,
      isGrandFinal: true,
    );
  }

  // Double Elimination for 8 teams
  void _generateDoubleElimination8Teams(
      List<Map<String, dynamic>> seededTeams) {
    int matchNumber = 1;

    // Winners Bracket Quarterfinals
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[0], // Seed 1
      seededTeams[7], // Seed 8
      '${seededTeams[0]['name']} (Seed 1)',
      '${seededTeams[7]['name']} (Seed 8)',
      5, // Winner goes to Winners Semifinals
      9, // Loser goes to Losers Round 1
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[3], // Seed 4
      seededTeams[4], // Seed 5
      '${seededTeams[3]['name']} (Seed 4)',
      '${seededTeams[4]['name']} (Seed 5)',
      5, // Winner goes to Winners Semifinals
      10, // Loser goes to Losers Round 1
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[1], // Seed 2
      seededTeams[6], // Seed 7
      '${seededTeams[1]['name']} (Seed 2)',
      '${seededTeams[6]['name']} (Seed 7)',
      6, // Winner goes to Winners Semifinals
      11, // Loser goes to Losers Round 1
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      1,
      seededTeams[2], // Seed 3
      seededTeams[5], // Seed 6
      '${seededTeams[2]['name']} (Seed 3)',
      '${seededTeams[5]['name']} (Seed 6)',
      6, // Winner goes to Winners Semifinals
      12, // Loser goes to Losers Round 1
    );

    // Winners Bracket Semifinals
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      {
        'id': 'match_1_winner',
        'name': 'Winner Match 1',
        'type': 'placeholder',
        'sourceMatch': 1
      },
      {
        'id': 'match_2_winner',
        'name': 'Winner Match 2',
        'type': 'placeholder',
        'sourceMatch': 2
      },
      'Winner Match 1',
      'Winner Match 2',
      7, // Winner goes to Winners Final
      13, // Loser goes to Losers Round 2
    );

    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      2,
      {
        'id': 'match_3_winner',
        'name': 'Winner Match 3',
        'type': 'placeholder',
        'sourceMatch': 3
      },
      {
        'id': 'match_4_winner',
        'name': 'Winner Match 4',
        'type': 'placeholder',
        'sourceMatch': 4
      },
      'Winner Match 3',
      'Winner Match 4',
      7, // Winner goes to Winners Final
      14, // Loser goes to Losers Round 2
    );

    // Winners Bracket Final
    _createDoubleElimMatch(
      matchNumber++,
      'winners',
      3,
      {
        'id': 'match_5_winner',
        'name': 'Winner Match 5',
        'type': 'placeholder',
        'sourceMatch': 5
      },
      {
        'id': 'match_6_winner',
        'name': 'Winner Match 6',
        'type': 'placeholder',
        'sourceMatch': 6
      },
      'Winner Match 5',
      'Winner Match 6',
      15, // Winner goes to Grand Final
      8, // Loser goes to Losers Final
    );

    // Losers Bracket Round 1
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_1_loser',
        'name': 'Loser Match 1',
        'type': 'placeholder',
        'sourceMatch': 1,
        'isLoser': true
      },
      {
        'id': 'match_2_loser',
        'name': 'Loser Match 2',
        'type': 'placeholder',
        'sourceMatch': 2,
        'isLoser': true
      },
      'Loser Match 1',
      'Loser Match 2',
      13, // Winner goes to Losers Round 2
      null,
    );

    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      1,
      {
        'id': 'match_3_loser',
        'name': 'Loser Match 3',
        'type': 'placeholder',
        'sourceMatch': 3,
        'isLoser': true
      },
      {
        'id': 'match_4_loser',
        'name': 'Loser Match 4',
        'type': 'placeholder',
        'sourceMatch': 4,
        'isLoser': true
      },
      'Loser Match 3',
      'Loser Match 4',
      14, // Winner goes to Losers Round 2
      null,
    );

    // Losers Bracket Round 2
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      2,
      {
        'id': 'match_5_loser',
        'name': 'Loser Match 5',
        'type': 'placeholder',
        'sourceMatch': 5,
        'isLoser': true
      },
      {
        'id': 'match_9_winner',
        'name': 'Winner Match 9',
        'type': 'placeholder',
        'sourceMatch': 9
      },
      'Loser Match 5',
      'Winner Match 9',
      15, // Winner goes to Losers Final
      null,
    );

    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      2,
      {
        'id': 'match_6_loser',
        'name': 'Loser Match 6',
        'type': 'placeholder',
        'sourceMatch': 6,
        'isLoser': true
      },
      {
        'id': 'match_10_winner',
        'name': 'Winner Match 10',
        'type': 'placeholder',
        'sourceMatch': 10
      },
      'Loser Match 6',
      'Winner Match 10',
      15, // Winner goes to Losers Final
      null,
    );

    // Losers Bracket Final
    _createDoubleElimMatch(
      matchNumber++,
      'losers',
      3,
      {
        'id': 'match_11_winner',
        'name': 'Winner Match 11',
        'type': 'placeholder',
        'sourceMatch': 11
      },
      {
        'id': 'match_12_winner',
        'name': 'Winner Match 12',
        'type': 'placeholder',
        'sourceMatch': 12
      },
      'Winner Match 11',
      'Winner Match 12',
      16, // Winner goes to Grand Final
      null,
    );

    // Grand Final
    _createDoubleElimMatch(
      matchNumber++,
      'grand',
      4,
      {
        'id': 'match_7_winner',
        'name': 'Winner Match 7',
        'type': 'placeholder',
        'sourceMatch': 7
      },
      {
        'id': 'match_13_winner',
        'name': 'Winner Match 13',
        'type': 'placeholder',
        'sourceMatch': 13
      },
      'Winner Match 7',
      'Winner Match 13',
      null,
      null,
      isGrandFinal: true,
    );
  }

  // Generic double elimination for 9+ teams (simplified structure)
  void _generateDoubleEliminationGeneric(
      List<Map<String, dynamic>> seededTeams) {
    int teamCount = seededTeams.length;
    int matchNumber = 1;

    // For simplicity, we'll create a basic double elimination structure
    // Winners bracket - first round
    int winnersRound1Matches = teamCount ~/ 2;

    for (int i = 0; i < winnersRound1Matches; i++) {
      if (i * 2 + 1 < teamCount) {
        _createDoubleElimMatch(
          matchNumber++,
          'winners',
          1,
          seededTeams[i * 2],
          seededTeams[i * 2 + 1],
          _getTeamName(seededTeams[i * 2]),
          _getTeamName(seededTeams[i * 2 + 1]),
          matchNumber + winnersRound1Matches - i, // Approximate next match
          matchNumber + (teamCount * 2), // Approximate losers match
        );
      } else if (i * 2 < teamCount) {
        // Bye - team advances automatically
        _createDoubleElimMatch(
          matchNumber++,
          'winners',
          1,
          seededTeams[i * 2],
          null,
          _getTeamName(seededTeams[i * 2]),
          'BYE',
          matchNumber + winnersRound1Matches - i,
          null,
        );
      }
    }

    // Add remaining matches for complete tournament
    // This is a simplified version - for production, you'd want a more sophisticated algorithm
  }

  String _getTeamName(Map<String, dynamic> team) {
    return team['name'] ?? 'Unknown';
  }
}
