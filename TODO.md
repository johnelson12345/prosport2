# Task: Fix Dart syntax errors in assigned_games.dart

## Steps:
- [x] 1. Create TODO.md with plan breakdown
- [ ] 2. Fix line 1679: Add missing ! to startDateTime!
- [ ] 3. Fix _TournamentCompletionButton constructor: Remove malformed onRefresh:(){} and add proper VoidCallback? onRefresh param
- [ ] 4. Remove duplicate standalone _getDisplayName and _buildTeamRow functions at file end
- [ ] 5. Update _TournamentCompletionButton._toggleCompletion() to call widget.onRefresh?.call() if provided
- [ ] 6. Verify fixes with Dart analysis
- [ ] 7. Test tournament completion button
- [ ] 8. attempt_completion

