import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'agency_dashboard.dart';
import 'agency_login_screen.dart';
import 'admin_screen.dart'; // <-- Import AdminScreen

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool passwordVisible = false;
  String errorText = '';

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  Future<void> handleAuth() async {
    setState(() => errorText = '');
    final mail = emailController.text.trim();
    final pass = passwordController.text.trim();

    if (mail.isEmpty || pass.isEmpty) {
      setState(() => errorText = 'Please fill all required fields.');
      return;
    }

    try {
      // Login with Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: mail, password: pass);

      // Check for admin email (replace with your actual admin email)
      if (mail == 'sigs@gmail.com') {
        if (!mounted) return; // <-- Add this line
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminScreen()),
        );
        if (!mounted) return; // <-- Add this line
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin Login Successful!')),
        );
        return;
      }

      // Fetch user role from Firestore (assuming you store a 'role' field)
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();
      String role = userDoc.data()?['role'] ?? 'user';

      if (role == 'agency') {
        // Fetch agency details from Firestore
        final agencyDoc =
            await FirebaseFirestore.instance
                .collection('agencies')
                .doc(userCredential.user!.uid)
                .get();

        final data = agencyDoc.data() ?? {};

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => AgencyDashboardScreen(
                  agencyName: data['agencyName'] ?? '',
                  ownerName: data['ownerName'] ?? '',
                  email: data['email'] ?? '',
                  phone: data['phone'] ?? '',
                  address: data['address'] ?? '',
                  regNumber: data['regNumber'] ?? '',
                  pickedFiles: Map<String, String>.from(
                    data['pickedFiles'] ?? {},
                  ),
                  userId: userCredential.user!.uid,
                  agencyId: userCredential.user!.uid,
                ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (context) => HomeScreen(
                  userName: userDoc.data()?['name'] ?? mail.split('@')[0],
                  userEmail: mail,
                  userPhone: userDoc.data()?['phone'] ?? '',
                ),
          ),
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${role[0].toUpperCase()}${role.substring(1)} Login Successful!',
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => errorText = e.message ?? 'Invalid email or password.');
    } catch (e) {
      if (!mounted) return;
      setState(() => errorText = 'An error occurred');
    }
  }

  void handleForgotPassword() async {
    final TextEditingController resetEmailController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Password'),
            content: TextField(
              controller: resetEmailController,
              decoration: const InputDecoration(
                labelText: 'Enter your email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  try {
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                      email: resetEmailController.text.trim(),
                    );
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Password reset link sent to ${resetEmailController.text}',
                        ),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to send reset link'),
                      ),
                    );
                  }
                },
                child: const Text('Send Link'),
              ),
            ],
          ),
    );
  }

  Widget _buildTextField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    bool showEye = false,
    bool eyeVisible = false,
    VoidCallback? onEyeTap,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure && !eyeVisible,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        suffixIcon:
            showEye
                ? IconButton(
                  icon: Icon(
                    eyeVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey[600],
                  ),
                  onPressed: onEyeTap,
                )
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6A1B9A), Color(0xFF00BFAE)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Image.asset(
                    'assets/logon.png',
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.1,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: Container(
                  margin: const EdgeInsets.only(
                    top: 220,
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 36,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.13),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (errorText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            errorText,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      _buildTextField(
                        hint: 'Email',
                        icon: Icons.email,
                        controller: emailController,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        hint: 'Password',
                        icon: Icons.lock,
                        controller: passwordController,
                        obscure: true,
                        showEye: true,
                        eyeVisible: passwordVisible,
                        onEyeTap: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: handleForgotPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Color(0xFF6A1B9A)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: handleAuth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 3,
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 19, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Colors.black26)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'or',
                              style: TextStyle(
                                color: Color.fromARGB(255, 90, 83, 83),
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Colors.black26)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.business,
                            size: 28,
                          ), // Bigger icon
                          label: const Text(
                            'Agency Login',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16, // Bigger font
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6A1B9A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 10,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AgencyLoginScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/agency-registration');
                        },
                        child: RichText(
                          text: const TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              color: Colors.black87,
                              fontSize: 15,
                            ),
                            children: [
                              TextSpan(
                                text: 'Register here',
                                style: TextStyle(
                                  color: Color(0xFF00BFAE),
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
