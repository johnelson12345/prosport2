# Bracket.dart Team Resolution Fix TODO

## Task: Fix bracket.dart to display actual teams instead of "Winner Match X" when source matches have scores

### Steps:
1. [x] **Analyze current bug**: Enhanced _getMatchDisplayNames to directly resolve using _getActualTeamName + debug logs + improved _getTeamScore.
2. [ ] **Improve regex patterns**: Add patterns for all placeholder formats in _getActualTeamName (_WINNER_MATCH_REGEX, _LOSER_MATCH_REGEX, ID_REGEX).
3. [x] **Fix score resolution**: Prioritize team1Score/team2Score, then team IDs for scores lookup.
4. [x] **Add debug logging**: Added print statements in _getMatchDisplayNames and _resolvePlaceholder.
5. [ ] **Test with JSON data**: Verify Match 3 shows 'UNIT 4' vs 'UNIT 3'.
6. [ ] **Edge cases**: Handle incomplete source matches (show placeholder), no sourceMatch (extract from name).
7. [ ] **Clean up**: Remove debug logs after confirmation.
8. [ ] **Complete**: attempt_completion

**Current Progress: 3/8**
**Priority: High**

Next: Test the changes - run the app, open bracket dialog for tournament_double4, check console logs and if Match 3 shows actual teams.
`flutter run` or hot reload, then test.

