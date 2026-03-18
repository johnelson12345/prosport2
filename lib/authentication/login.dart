import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tabulation_systemv7/screens_roles/tabulation_comittee/tabulator.dart';
import 'package:tabulation_systemv7/screens_roles/tournament_official/tournament_main.dart';
import 'package:tabulation_systemv7/screens_roles/admin_screens/admin.dart';
import 'package:tabulation_systemv7/screens_roles/viewer/main_viewer.dart';
import 'package:tabulation_systemv7/services/auth.dart';
import 'signup.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool isLoading = false;
  bool _obscurePassword = true; // Controls password visibility

  void _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showError("Email and password cannot be empty.");
      return;
    }

    setState(() => isLoading = true);

    final user = await _authService.signInWithEmailPassword(email, password);

    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final role = userDoc['role'];
        Widget nextScreen;

        // Normalize role to lowercase for consistent comparison
        final normalizedRole = (role ?? 'Viewer').trim().toLowerCase();

        switch (normalizedRole) {
          case 'admin':
            nextScreen = AdminScreen();
            break;
          case 'tournament official':
            nextScreen = const TournamentMain();
            break;
          case 'viewer':
            nextScreen = const ViewerMain();
            break;
          case 'tabulator':
            nextScreen = const TabulatorMain();
            break;
          default:
            _showError("Unrecognized user role: $role");
            setState(() => isLoading = false);
            return;
        }

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => nextScreen),
        );
      } else {
        _showError("User role not found.");
      }
    } else {
      _showError("Invalid email or password.");
    }

    if (!mounted) return;
    setState(() => isLoading = false);
  }

  void _showError(String message) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.redAccent.shade200,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 3),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo and Title in a Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/icon2.png',
                            height:
                                80, // Slightly reduced for better row alignment
                            width: 80,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'UA SPORTS DEVELOPMENT UNIT',
                              style: TextStyle(
                                fontSize: 22, // Slightly reduced to fit better
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Rest of your form fields remain exactly the same
                      TextField(
                        controller: emailController,
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.email, color: Colors.deepOrange),
                          labelText: 'Email',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.deepOrange),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ... [keep all your other existing form fields and buttons] ...

                      TextField(
                        controller: passwordController,
                        obscureText:
                            _obscurePassword, // Use the state variable here
                        decoration: InputDecoration(
                          prefixIcon:
                              const Icon(Icons.lock, color: Colors.deepOrange),
                          labelText: 'Password',
                          labelStyle: TextStyle(color: Colors.grey.shade600),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Colors.deepOrange),
                          ),
                          suffixIcon: IconButton(
                            // Add this icon button
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.deepOrange,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword; // Toggle visibility
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Google Sign-In Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Image.asset(
                            'assets/Google-Logo.png',
                            height: 24,
                            width: 24,
                          ),
                          label: const Text(
                            'Sign In with Google',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  setState(() => isLoading = true);
                                  try {
                                    final user =
                                        await _authService.signInWithGoogle();
                                    if (user != null) {
                                      // Get user role from Firestore
                                      final role = await _authService
                                          .getUserRole(user.uid);

                                      if (!mounted) return;

                                      Widget nextScreen;
                                      final normalizedRole = (role ?? 'Viewer')
                                          .trim()
                                          .toLowerCase();
                                      switch (normalizedRole) {
                                        case 'admin':
                                          nextScreen = const AdminScreen();
                                          break;
                                        case 'tournament official':
                                          nextScreen = const TournamentMain();
                                          break;
                                        case 'tabulator':
                                          nextScreen = const TabulatorMain();
                                          break;
                                        case 'viewer':
                                        default:
                                          nextScreen = const ViewerMain();
                                          break;
                                      }

                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                            builder: (context) => nextScreen),
                                      );
                                    }
                                  } catch (e) {
                                    _showError(
                                        "An error occurred during Google sign-in: $e");
                                    print("Google sign-in error: $e");
                                  }
                                  if (!mounted) return;
                                  setState(() => isLoading = false);
                                },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Sign Up Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const SignUpPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
