import 'package:flutter/material.dart';
import 'package:tabulation_systemv7/services/auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  SignUpPageState createState() => SignUpPageState();
}

class SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Add listeners to update UI on input changes for real-time validation feedback
  @override
  void initState() {
    super.initState();
    emailController.addListener(() => setState(() {}));
    passwordController.addListener(() => setState(() {}));
    confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Email validation regex
  final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#\$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
  );

  // Password strength validation regex: min 8 chars, at least 1 uppercase, 1 lowercase, 1 digit, 1 special char
  final RegExp _passwordRegExp = RegExp(
    r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[!@#\$&*~]).{8,}$',
  );

  bool _isEmailValid(String email) {
    return _emailRegExp.hasMatch(email);
  }

  bool _isPasswordStrong(String password) {
    return _passwordRegExp.hasMatch(password);
  }

  bool _isFormValid() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    return email.isNotEmpty &&
        password.isNotEmpty &&
        confirmPassword.isNotEmpty &&
        _isEmailValid(email) &&
        _isPasswordStrong(password) &&
        password == confirmPassword;
  }

  void _signUp() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showError("Please fill in all fields.");
      return;
    }

    if (!_isEmailValid(email)) {
      _showError("Please enter a valid email address.");
      return;
    }

    if (!_isPasswordStrong(password)) {
      _showError(
          "Password must be at least 8 characters and include uppercase, lowercase, number, and special character.");
      return;
    }

    if (password != confirmPassword) {
      _showError("Passwords do not match.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = await _authService.signUpWithEmailPassword(email, password);

      if (user != null) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': email,
          'role': 'Viewer',
        });

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      } else {
        _showError("Sign up failed. Please try again.");
      }
    } catch (e) {
      _showError("An error occurred: $e");
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
                    // Logo and Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/icon2.png',
                          height: 80,
                          width: 80,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'UA SPORTS DEVELOPMENT UNIT',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Email Field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.email, color: Colors.deepOrange),
                        labelText: 'Email',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        errorText: emailController.text.isEmpty
                            ? null
                            : (!_isEmailValid(emailController.text.trim())
                                ? 'Enter a valid email'
                                : null),
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

                    // Password Field
                    TextField(
                      controller: passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.deepOrange),
                        labelText: 'Password',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        errorText: passwordController.text.isEmpty
                            ? null
                            : (!_isPasswordStrong(
                                    passwordController.text.trim())
                                ? 'Password must be at least 8 chars, include uppercase, lowercase, number & special char'
                                : null),
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
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.deepOrange,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Confirm Password Field
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        prefixIcon:
                            const Icon(Icons.lock, color: Colors.deepOrange),
                        labelText: 'Confirm Password',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        errorText: confirmPasswordController.text.isEmpty
                            ? null
                            : (confirmPasswordController.text.trim() !=
                                    passwordController.text.trim()
                                ? 'Passwords do not match'
                                : null),
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
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.deepOrange,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign Up Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            isLoading || !_isFormValid() ? null : _signUp,
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
                                'Sign Up',
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
                          backgroundColor: const Color.fromARGB(255, 249, 100, 0),
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

                                    final normalizedRole =
                                        (role ?? 'Viewer').trim().toLowerCase();
                                    switch (normalizedRole) {
                                      case 'admin':
                                        break;
                                      case 'tournament official':
                                        // nextScreen = TechScreen();
                                        break;
                                      case 'tabulator':
                                        break;
                                      case 'viewer':
                                      default:
                                        // nextScreen = ViewerMain();
                                        break;
                                    }

                                    // Navigator.pushReplacement(
                                    //   context,
                                    //   MaterialPageRoute(
                                    //       builder: (context) => nextScreen),
                                    // );
                                  }
                                } catch (e) {
                                  _showError(
                                      "An error occurred during Google sign-in: $e");
                                }
                                if (!mounted) return;
                                setState(() => isLoading = false);
                              },
                      ),
                    ),

                    // Login Link
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Already have an account? ",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          child: const Text(
                            'Login',
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
      )
    );
  }
}
