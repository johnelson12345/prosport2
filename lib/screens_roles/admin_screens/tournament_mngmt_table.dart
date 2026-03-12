import 'package:flutter/material.dart';

class TournamentSetupTable extends StatelessWidget {
  final Map<String, dynamic> setupData;

  const TournamentSetupTable({super.key, required this.setupData});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Step')),
            DataColumn(label: Text('Selection')),
          ],
          rows: [
            DataRow(cells: [
              const DataCell(Text('Sports Event')),
              DataCell(Text(setupData['name'] ?? 'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Category')),
              DataCell(Text(setupData['category'] ?? 'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Sport')),
              DataCell(Text(setupData['sport'] ?? 'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Teams')),
              DataCell(Text(
                  (setupData['selectedTeamIds'] as List<String>?)?.join(', ') ??
                      'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Gender')),
              DataCell(Text(setupData['gender'] ?? 'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Venue')),
              DataCell(Text(setupData['venue'] ?? 'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Elimination Type')),
              DataCell(Text(setupData['eliminationType'] ?? 'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Randomize')),
              DataCell(Text(setupData['randomize']?.toString() ?? 'Not set')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Schedules')),
              DataCell(Text((setupData['selectedScheduleIds'] as List<String>?)
                      ?.length
                      .toString() ??
                  '0')),
            ]),
            DataRow(cells: [
              const DataCell(Text('Assigned Users')),
              DataCell(Text(
                  (setupData['selectedUserIds'] as List<String>?)?.join(', ') ??
                      'Not set')),
            ]),
          ],
        ),
      ),
    );
  }
}
