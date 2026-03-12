import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/services/sports_category.dart';
import 'package:tabulation_systemv7/services/sports_list.dart';

/// =====================================================
/// SPORTS TABLE SOURCE
/// =====================================================

class SportsDataSource extends DataTableSource {
  final List<DocumentSnapshot> sports;
  final void Function(String sportId, String name, String category) onEdit;
  final void Function(String sportId) onDelete;

  SportsDataSource(this.sports, this.onEdit, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= sports.length) return null;

    final doc = sports[index];
    final data = doc.data() as Map<String, dynamic>;

    final id = doc.id;
    final name = data['name'] ?? '';
    final category = data['category'] ?? '';

    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(category)),
        DataCell(Text(name)),
        DataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => onEdit(id, name, category),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => onDelete(id),
            ),
          ],
        )),
      ],
    );
  }

  @override
  int get rowCount => sports.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

/// =====================================================
/// CATEGORY TABLE SOURCE
/// =====================================================

class CategoriesDataSource extends DataTableSource {
  final List<DocumentSnapshot> categories;
  final void Function(String id, String name) onEdit;
  final void Function(String id) onDelete;

  CategoriesDataSource(this.categories, this.onEdit, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= categories.length) return null;

    final doc = categories[index];
    final name = (doc.data() as Map<String, dynamic>)['name'] ?? '';

    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(Text(name)),
        DataCell(Row(
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: () => onEdit(doc.id, name),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => onDelete(doc.id),
            ),
          ],
        )),
      ],
    );
  }

  @override
  int get rowCount => categories.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}

/// =====================================================
/// MAIN SCREEN
/// =====================================================

class SportsManagementScreen extends StatefulWidget {
  const SportsManagementScreen({super.key});

  @override
  State<SportsManagementScreen> createState() => _SportsManagementScreenState();
}

class _SportsManagementScreenState extends State<SportsManagementScreen> {
  int _selectedView = 0;

  final SportsService _sportsService = SportsService();
  final SportCategoryService _categoryService = SportCategoryService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<DocumentSnapshot> _filteredSports = [];
  List<DocumentSnapshot> _filteredCategories = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterSportsAndCategories);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSportsAndCategories() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  /// =====================================================
  /// BUILD
  /// =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports Management'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              _tabButton(0, 'Sports', Icons.sports_soccer, Colors.blue),
              _tabButton(1, 'Categories', Icons.category, Colors.green),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              icon: Icon(
                  _selectedView == 0 ? Icons.sports_soccer : Icons.category),
              label: Text(_selectedView == 0 ? 'Add Sport' : 'Add Category'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _selectedView == 0 ? Colors.blue : Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _selectedView == 0
                  ? _showAddOrEditSportDialog(context)
                  : _showAddOrEditCategoryDialog(context),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: _selectedView == 0 ? _buildSportsTab() : _buildCategoriesTab(),
      ),
    );
  }

  /// =====================================================
  /// TABS
  /// =====================================================

  Widget _tabButton(int index, String label, IconData icon, Color color) {
    final selected = _selectedView == index;

    return Expanded(
      child: TextButton.icon(
        onPressed: () => setState(() => _selectedView = index),
        icon: Icon(icon, color: selected ? color : Colors.grey),
        label: Text(label,
            style: TextStyle(
                color: selected ? color : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  /// =====================================================
  /// SPORTS TAB
  /// =====================================================

  Widget _buildSportsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _sportsService.getSportsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sports_soccer, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No sports for this sports event.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check sports event management.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final allSports = snapshot.data!.docs;
        final query = _searchController.text.toLowerCase();
        final sports = query.isEmpty
            ? allSports
            : allSports.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name']?.toLowerCase() ?? '';
                final category = data['category']?.toLowerCase() ?? '';
                return name.contains(query) || category.contains(query);
              }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: SizedBox(
                width: constraints.maxWidth,
                child: PaginatedDataTable(
                  header: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sports List'),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                    tooltip: 'Clear search',
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  rowsPerPage: 8,
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  horizontalMargin: 10,
                  columns: const [
                    DataColumn(label: Text('No.')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Sport Name')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: SportsDataSource(sports, _editSport, _deleteSport),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// =====================================================
  /// CATEGORY TAB
  /// =====================================================

  Widget _buildCategoriesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _categoryService.getCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.category, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No categories for this sports event.',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Please check sports event management.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final allCategories = snapshot.data!.docs;
        final query = _searchController.text.toLowerCase();
        final categories = query.isEmpty
            ? allCategories
            : allCategories.where((doc) {
                final name = (doc.data() as Map<String, dynamic>)['name']
                        ?.toLowerCase() ??
                    '';
                return name.contains(query);
              }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: SizedBox(
                width: constraints.maxWidth,
                child: PaginatedDataTable(
                  header: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Categories List'),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: _clearSearch,
                                    tooltip: 'Clear search',
                                  )
                                : null,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  rowsPerPage: 8,
                  showCheckboxColumn: false,
                  columnSpacing: 20,
                  horizontalMargin: 10,
                  columns: const [
                    DataColumn(label: Text('No.')),
                    DataColumn(label: Text('Category Name')),
                    DataColumn(label: Text('Actions')),
                  ],
                  source: CategoriesDataSource(
                      categories, _editCategory, _deleteCategory),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// =====================================================
  /// ACTIONS
  /// =====================================================

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, String itemType, VoidCallback onConfirm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete $itemType'),
        content: Text(
            'Are you sure you want to delete this $itemType? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    if (result == true) {
      onConfirm();
    }
  }

  void _editSport(String id, String name, String category) =>
      _showAddOrEditSportDialog(context,
          sportId: id, currentName: name, currentCategory: category);

  void _deleteSport(String id) {
    _showDeleteConfirmationDialog(
        context, 'sport', () => _sportsService.deleteSport(id));
  }

  void _editCategory(String id, String name) =>
      _showAddOrEditCategoryDialog(context, categoryId: id, currentName: name);

  void _deleteCategory(String id) {
    _showDeleteConfirmationDialog(
        context, 'category', () => _categoryService.deleteCategory(id));
  }

  /// =====================================================
  /// DIALOGS
  /// =====================================================

  void _showAddOrEditCategoryDialog(BuildContext context,
      {String? categoryId, String? currentName}) {
    final controller = TextEditingController(text: currentName ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(categoryId == null ? 'Add Category' : 'Edit Category'),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text;
              if (name.isEmpty) return;

              categoryId == null
                  ? _categoryService.addCategory(name)
                  : _categoryService.updateCategory(categoryId, name);

              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditSportDialog(BuildContext context,
      {String? sportId, String? currentName, String? currentCategory}) {
    final controller = TextEditingController(text: currentName ?? '');
    String? selected = currentCategory;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(sportId == null ? 'Add Sport' : 'Edit Sport'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller),
              const SizedBox(height: 10),
              StreamBuilder<QuerySnapshot>(
                stream: _categoryService.getCategories(),
                builder: (_, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();

                  return DropdownButton<String>(
                    isExpanded: true,
                    value: selected,
                    hint: const Text('Select Category'),
                    items: snapshot.data!.docs
                        .map<DropdownMenuItem<String>>(
                          (e) => DropdownMenuItem<String>(
                            value: e['name'] as String,
                            child: Text(e['name']),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selected = v),
                  );
                },
              )
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final name = controller.text;
                if (name.isEmpty || selected == null) return;

                sportId == null
                    ? _sportsService.addSport(name, selected!)
                    : _sportsService.updateSport(sportId, name, selected!);

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
