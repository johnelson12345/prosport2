import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/participants_service.dart';
import 'package:flutter/services.dart';

class ViewRewardsScreen extends StatefulWidget {
  const ViewRewardsScreen({super.key});

  @override
  State<ViewRewardsScreen> createState() => _ViewRewardsScreenState();
}

class _ViewRewardsScreenState extends State<ViewRewardsScreen> {
  final ParticipantsService _participantsService = ParticipantsService();
  Map<String, String> _tournamentNames = {};

  @override
  void initState() {
    super.initState();
    _fetchTournamentNames();
  }

  Future<void> _fetchTournamentNames() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('tournaments').get();
    setState(() {
      _tournamentNames = {
        for (var doc in snapshot.docs) doc.id: doc['name'] as String
      };
    });
  }

  Color _getMedalColor(String medal) {
    switch (medal.toLowerCase()) {
      case 'gold':
        return Colors.amber;
      case 'silver':
        return Colors.grey;
      case 'bronze':
        return Colors.brown;
      default:
        return Colors.blue;
    }
  }

  Widget _buildMedalCount(String medalType, List<String> medals, Color color) {
    int count = medals
        .where((medal) => medal.toLowerCase() == medalType.toLowerCase())
        .length;
    return Column(
      children: [
        Icon(Icons.emoji_events, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          medalType,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _showEditRewardsDialog(String participantId, String name,
      int currentGold, List<String> currentMedals) async {
    final formKey = GlobalKey<FormState>();
    int participationGold = currentGold;
    List<String> medals = List.from(currentMedals);
    String newMedal = '';

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Rewards for $name'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Participation Gold'),
                      TextFormField(
                        initialValue: participationGold.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        onSaved: (value) =>
                            participationGold = int.tryParse(value ?? '0') ?? 0,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final num = int.tryParse(value);
                          if (num == null || num < 0) {
                            return 'Must be a non-negative number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text('Current Medals:'),
                      if (medals.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          children: medals.map((medal) {
                            Color medalColor;
                            switch (medal.toLowerCase()) {
                              case 'gold':
                                medalColor = Colors.amber;
                                break;
                              case 'silver':
                                medalColor = Colors.grey;
                                break;
                              case 'bronze':
                                medalColor = Colors.brown;
                                break;
                              default:
                                medalColor = Colors.blue;
                            }
                            return Chip(
                              label: Text(medal),
                              backgroundColor: medalColor.withOpacity(0.2),
                              labelStyle: TextStyle(color: medalColor),
                              deleteIcon: const Icon(Icons.close, size: 16),
                              onDeleted: () {
                                setDialogState(() {
                                  medals.remove(medal);
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ] else ...[
                        const Text(
                          'No medals',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text('Add New Medal'),
                      DropdownButtonFormField<String>(
                        value: newMedal.isEmpty ? null : newMedal,
                        hint: const Text('Select medal type'),
                        items: ['Gold', 'Silver', 'Bronze']
                            .map((medal) => DropdownMenuItem(
                                  value: medal,
                                  child: Text(medal),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            newMedal = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed:
                            newMedal.isNotEmpty && !medals.contains(newMedal)
                                ? () {
                                    setDialogState(() {
                                      medals.add(newMedal);
                                      newMedal = '';
                                    });
                                  }
                                : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Medal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!.save();

                      try {
                        await _participantsService.updateParticipantRewards(
                            participantId, participationGold, medals);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Rewards updated successfully',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green.shade600,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );

                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.error, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Error updating rewards: $e',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.red.shade600,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Participant Rewards',
            style: TextStyle(color: Colors.white)),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade900,
                Colors.blue.shade700,
                Colors.orange.shade600,
                Colors.deepOrange.shade700,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
        elevation: 4,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _participantsService.getParticipantsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final participants = snapshot.data!.docs;

          if (participants.isEmpty) {
            return const Center(child: Text('No participants found.'));
          }

          return ListView.builder(
            itemCount: participants.length,
            itemBuilder: (context, index) {
              final participant =
                  participants[index].data() as Map<String, dynamic>;
              final participantId = participants[index].id;
              final name = participant['name'] ?? 'Unknown';
              final participationGold = participant['participationGold'] ?? 0;
              final medals = List<String>.from(participant['medals'] ?? []);
              final tournamentId = participant['tournamentId'];
              final tournamentName =
                  _tournamentNames[tournamentId] ?? 'Unknown Tournament';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (medals.isNotEmpty) ...[
                        const Text(
                          'Medals:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: medals.map((medal) {
                            Color medalColor;
                            switch (medal.toLowerCase()) {
                              case 'gold':
                                medalColor = Colors.amber;
                                break;
                              case 'silver':
                                medalColor = Colors.grey;
                                break;
                              case 'bronze':
                                medalColor = Colors.brown;
                                break;
                              default:
                                medalColor = Colors.blue;
                            }
                            return Chip(
                              label: Text(medal),
                              backgroundColor: medalColor.withOpacity(0.2),
                              labelStyle: TextStyle(color: medalColor),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildMedalCount('Gold', medals, Colors.amber),
                              _buildMedalCount('Silver', medals, Colors.grey),
                              _buildMedalCount('Bronze', medals, Colors.brown),
                            ],
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'No medals awarded',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'Reward History:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 0, 0, 0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (participant['rewardHistory'] != null &&
                          (participant['rewardHistory'] as List)
                              .isNotEmpty) ...[
                        ...List<Map<String, dynamic>>.from(
                                participant['rewardHistory'])
                            .where((history) =>
                                history['type'] != 'participationGold' &&
                                history['type'] != 'participationGoldRemoval')
                            .map((history) {
                          final type = history['type'] ?? 'Unknown';
                          final tournament = history['tournament'] ?? 'Unknown';
                          final category = history['category'] ?? 'Unknown';
                          final sport = history['sport'] ?? 'Unknown';
                          final date = history['date'] != null
                              ? (history['date'] as Timestamp)
                                  .toDate()
                                  .toString()
                                  .substring(0, 16)
                              : 'Unknown';
                          final amount = history['amount']?.toString() ?? '';
                          final medal = history['medal']?.toString() ?? '';

                          Color typeColor;
                          IconData typeIcon;
                          switch (type) {
                            case 'participationGold':
                              typeColor = Colors.amber;
                              typeIcon = Icons.monetization_on;
                              break;
                            case 'medal':
                              typeColor = Colors.blue;
                              typeIcon = Icons.emoji_events;
                              break;
                            case 'medalChange':
                              typeColor = Colors.orange;
                              typeIcon = Icons.swap_horiz;
                              break;
                            case 'medalRemoval':
                              typeColor = Colors.red;
                              typeIcon = Icons.remove_circle;
                              break;
                            case 'participationGoldRemoval':
                              typeColor = Colors.red;
                              typeIcon = Icons.remove_circle_outline;
                              break;
                            default:
                              typeColor = Colors.grey;
                              typeIcon = Icons.info;
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(typeIcon,
                                          color: typeColor, size: 24),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          type
                                              .replaceAllMapped(
                                                  RegExp(r'([A-Z])'),
                                                  (match) =>
                                                      ' ${match.group(0)}')
                                              .trim()
                                              .split(' ')
                                              .map((word) => word.isNotEmpty
                                                  ? word[0].toUpperCase() +
                                                      word
                                                          .substring(1)
                                                          .toLowerCase()
                                                  : word)
                                              .join(' '),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: typeColor,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        date,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.emoji_events,
                                                size: 16,
                                                color: Colors.deepPurple),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '$tournament ($category - $sport)',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (medal.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.military_tech,
                                                size: 16,
                                                color: _getMedalColor(medal),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Medal: $medal',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: _getMedalColor(medal),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history, color: Colors.grey),
                              SizedBox(width: 8),
                              Text(
                                'No reward history available',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
