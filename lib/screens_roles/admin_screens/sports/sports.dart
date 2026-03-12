import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_category.dart';
import 'package:tabulation_systemv7/services/sports_list.dart';

class SportsScreen extends StatefulWidget {
  const SportsScreen({super.key});

  @override
  _SportsScreenState createState() => _SportsScreenState();
}

class _SportsScreenState extends State<SportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<DocumentSnapshot> categories;
  bool isCategoriesFetched = false; // Flag to track if categories are fetched

  late SportCategoryService _categoryService;
  late SportsService _sportsService;

  @override
  void initState() {
    super.initState();
    _categoryService = SportCategoryService();
    _sportsService = SportsService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Categories'),
        backgroundColor: Colors.white,
        actions: [
          // ElevatedButton.icon(
          //   onPressed: () {
          //     // TODO: Implement add category functionality
          //   },
          //   icon: const Icon(Icons.add),
          //   // label: const Text('Add Category'),
          //   style: ElevatedButton.styleFrom(
          //     backgroundColor: Colors.white,
          //     foregroundColor: Colors.black,
          //     elevation: 0,
          //     shape: RoundedRectangleBorder(
          //       borderRadius: BorderRadius.circular(8),
          //     ),
          //   ),
          // ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _categoryService.getCategories(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No categories available.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          categories = snapshot.data!.docs;

          // Initialize TabController only after categories are fetched
          if (!isCategoriesFetched) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _tabController = TabController(
                length: categories.length,
                vsync: this,
              );
              setState(() {
                isCategoriesFetched = true;
              });
            });
          }

          // Ensure that TabController is initialized before displaying TabBar
          if (!isCategoriesFetched) {
            return const Center(child: CircularProgressIndicator());
          }

          return DefaultTabController(
            length: categories.length,
            child: Column(
              children: [
                // TabBar at the top
                TabBar(
                  controller: _tabController,
                  tabs: categories.map((category) {
                    return Tab(text: category['name']);
                  }).toList(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: categories.map((category) {
                      return SportsTab(
                          categoryName: category['name'],
                          sportsService: _sportsService);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class SportsTab extends StatelessWidget {
  final String categoryName;
  final SportsService sportsService;

  const SportsTab(
      {super.key, required this.categoryName, required this.sportsService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: sportsService.getSportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final sports = snapshot.data?.docs ?? [];
        if (sports.isEmpty) {
          return const Center(child: Text('No sports available'));
        }

        // Filter sports by category
        final filteredSports =
            sports.where((sport) => sport['category'] == categoryName).toList();

        if (filteredSports.isEmpty) {
          return const Center(child: Text('No sports found for this category'));
        }

        return SingleChildScrollView(
          // Use SingleChildScrollView to avoid overflow
          child: Column(
            children: filteredSports.map((sport) {
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(sport['name']),
                  subtitle: Text('Category: ${sport['category']}'),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
