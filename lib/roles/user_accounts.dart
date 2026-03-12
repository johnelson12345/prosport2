import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserManagement extends StatefulWidget {
  const UserManagement({super.key});

  @override
  State<UserManagement> createState() => _UserManagementState();
}

class _UserManagementState extends State<UserManagement> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedRole;
  int _currentPage = 1;
  int _itemsPerPage = 10;

  @override
  Widget build(BuildContext context) {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    Future<void> assignRole(String userId, String role) async {
      setState(() {
        _isLoading = true;
      });
      try {
        await firestore.collection('users').doc(userId).update({'role': role});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Role updated to $role',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update role: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }

    Future<void> deleteUser(String userId) async {
      bool confirm = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Delete'),
          content:
              const Text('Are you sure you want to delete this user account?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.red, // Red background
                foregroundColor: Colors.white, // White text
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            )
          ],
        ),
      );

      if (confirm == true) {
        setState(() {
          _isLoading = true;
        });
        try {
          await firestore.collection('users').doc(userId).delete();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'User account deleted',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green.shade600,
                behavior: SnackBarBehavior.floating,
                margin:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to delete user: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }

    Future<void> editUser(BuildContext context, DocumentSnapshot user) async {
      final formKey = GlobalKey<FormState>();
      final emailController = TextEditingController(text: user['email']);
      String selectedRole = user['role'];

      bool saved = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit User'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email cannot be empty';
                    }
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(value)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: ['Admin', 'Tournament Official', 'Tabulator', 'Viewer']
                      .map((role) =>
                          DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (newRole) {
                    if (newRole != null) {
                      setState(() {
                        selectedRole = newRole;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a role';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.green, // Green background
                foregroundColor: Colors.white, // White text
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8), // Rounded corners
                ),
              ),
              child: const Text('Save'),
            )
          ],
        ),
      );

      if (saved == true) {
        setState(() {
          _isLoading = true;
        });
        try {
          await firestore.collection('users').doc(user.id).update({
            'email': emailController.text,
            'role': selectedRole,
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('User updated')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update user: $e')),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search by Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
                _currentPage = 1;
              });
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Filter by Role',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('All Roles'),
              ),
              ...['Admin', 'Tournament Official', 'Tabulator', 'Viewer']
                  .map((role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedRole = value;
                _currentPage = 1;
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: StreamBuilder(
            stream: firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var users = snapshot.data!.docs.where((user) {
                String email = user['email'] ?? '';
                String role = user['role'] ?? '';
                bool matchesSearch = email.toLowerCase().contains(_searchQuery);
                bool matchesRole =
                    _selectedRole == null || role == _selectedRole;
                return matchesSearch && matchesRole;
              }).toList();
              int totalUsers = users.length;
              int totalPages = (totalUsers / _itemsPerPage).ceil();
              int startIndex = (_currentPage - 1) * _itemsPerPage;
              int endIndex = startIndex + _itemsPerPage;
              if (endIndex > totalUsers) endIndex = totalUsers;
              List<DocumentSnapshot> pagedUsers =
                  users.sublist(startIndex, endIndex);

              return Column(
                children: [
                  Expanded(
                      child: ListView.builder(
                    itemCount: pagedUsers.length,
                    itemBuilder: (context, index) {
                      var user = pagedUsers[index];

                      String email = user['email'] ?? '';
                      String role = user['role'] ?? '';
                      String initials = '';
                      if (email.isNotEmpty) {
                        var parts = email.split('@');
                        if (parts.isNotEmpty && parts[0].isNotEmpty) {
                          initials = parts[0][0].toUpperCase();
                        }
                      }

                      Color avatarColor = Colors.blue.shade700;
                      switch (role) {
                        case 'Admin':
                          avatarColor = Colors.orange.shade700;
                          break;
                        case 'Tournament Official':
                          avatarColor = Colors.blue.shade700;
                          break;
                        case 'Tabulator':
                          avatarColor = const Color.fromARGB(255, 211, 93, 47);
                          break;
                        case 'Viewer':
                          avatarColor = Colors.red.shade700;
                          break;
                      }

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: avatarColor,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(email,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text("Role: $role"),
                          trailing: PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) async {
                              if (_isLoading) return;
                              if (value == 'edit') {
                                await editUser(context, user);
                              } else if (value == 'delete') {
                                await deleteUser(user.id);
                              } else if (value.startsWith('role_')) {
                                String role = value.substring(5);
                                await assignRole(user.id, role);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit,
                                        color: Colors.blue, size: 20),
                                    SizedBox(width: 8),
                                    Text('Edit User'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete,
                                        color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Delete'),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                enabled: false,
                                child: Text('Change Role',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              const PopupMenuItem(
                                value: 'role_Admin',
                                child: Row(
                                  children: [
                                    Icon(Icons.admin_panel_settings, size: 20),
                                    SizedBox(width: 8),
                                    Text('Admin'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'role_Tournament Official',
                                child: Row(
                                  children: [
                                    Icon(Icons.sports, size: 20),
                                    SizedBox(width: 8),
                                    Text('Tournament Official'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'role_Tabulator',
                                child: Row(
                                  children: [
                                    Icon(Icons.calculate, size: 20),
                                    SizedBox(width: 8),
                                    Text('Tabulator'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'role_Viewer',
                                child: Row(
                                  children: [
                                    Icon(Icons.visibility, size: 20),
                                    SizedBox(width: 8),
                                    Text('Viewer'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        DropdownButton<int>(
                          value: _itemsPerPage,
                          items: [10, 50, 100].map((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value per page'),
                            );
                          }).toList(),
                          onChanged: (int? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _itemsPerPage = newValue;
                                _currentPage = 1;
                              });
                            }
                          },
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 1
                                    ? () {
                                        setState(() {
                                          _currentPage--;
                                        });
                                      }
                                    : null,
                              ),
                              Flexible(
                                child: Text(
                                  'Showing ${startIndex + 1}-$endIndex of $totalUsers users',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage < totalPages
                                    ? () {
                                        setState(() {
                                          _currentPage++;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
