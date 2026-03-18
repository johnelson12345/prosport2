// ignore_for_file: library_private_types_in_public_api, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TournamentInfo extends StatefulWidget {
  final String tournamentId;

  const TournamentInfo({super.key, required this.tournamentId});

  @override
  _TournamentInfoState createState() => _TournamentInfoState();
}

class _TournamentInfoState extends State<TournamentInfo> {
  Map<String, dynamic>? _tournamentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTournamentInfo();
  }

  Future<void> _fetchTournamentInfo() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('tournaments')
          .doc(widget.tournamentId)
          .get();

      if (doc.exists) {
        setState(() {
          _tournamentData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tournament not found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading tournament info: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('Tournament Information'),
      //   flexibleSpace: Container(
      //     decoration: BoxDecoration(
      //       gradient: LinearGradient(
      //         colors: [
      //           Colors.blue.shade900,
      //           Colors.blue.shade700,
      //           Colors.orange.shade600,
      //           Colors.deepOrange.shade700,
      //         ],
      //         begin: Alignment.topLeft,
      //         end: Alignment.bottomRight,
      //         stops: const [0.0, 0.3, 0.7, 1.0],
      //       ),
      //     ),
      //   ),
      // ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tournamentData == null
              ? const Center(child: Text('No data available.'))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ListView(
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tournament Name: ${_tournamentData!['name'] ?? 'N/A'}',
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Category: ${_tournamentData!['category'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sport: ${_tournamentData!['sport'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Status: ${_tournamentData!['status'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 16),
                              ),
                              // Add more fields as needed
                              if (_tournamentData!['eliminationType'] !=
                                  null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Elimination Type: ${_tournamentData!['eliminationType']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                              if (_tournamentData!['description'] != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Description: ${_tournamentData!['description']}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                              // Add other fields from the collection
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
