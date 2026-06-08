import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:trailer/agency_info.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trailer/login_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AgencyRegistrationScreen extends StatefulWidget {
  const AgencyRegistrationScreen({super.key});

  @override
  State<AgencyRegistrationScreen> createState() =>
      _AgencyRegistrationScreenState();
}

class _AgencyRegistrationScreenState extends State<AgencyRegistrationScreen> {
  String _selectedRole = 'agency'; // Default to agency

  // User fields
  final _userNameController = TextEditingController();
  final _userEmailController = TextEditingController();
  final _userPhoneController = TextEditingController();
  final _userPasswordController = TextEditingController();
  final _userConfirmPasswordController = TextEditingController();

  // Agency fields
  final _agencyNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Store file paths for upload
  final Map<String, String> _pickedFiles = {};

  String errorText = '';
  bool _loading = false;

  @override
  void dispose() {
    _userNameController.dispose();
    _userEmailController.dispose();
    _userPhoneController.dispose();
    _userPasswordController.dispose();
    _userConfirmPasswordController.dispose();
    _agencyNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _regNumberController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // Helper function to validate phone number
  bool _isValidPhoneNumber(String phone) {
    final digitsOnly = RegExp(r'^\d{10,}$');
    return digitsOnly.hasMatch(phone);
  }

  // Cloudinary upload helper
  Future<String?> uploadToCloudinary(File file) async {
    const cloudName = 'YOUR_CLOUD_NAME';
    const uploadPreset = 'YOUR_UPLOAD_PRESET';
    final url = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );
    final request =
        http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = uploadPreset
          ..files.add(await http.MultipartFile.fromPath('file', file.path));
    final response = await request.send();
    if (response.statusCode == 200) {
      final resStr = await response.stream.bytesToString();
      final resJson = json.decode(resStr);
      return resJson['secure_url'];
    }
    return null;
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 18.0),
          child: Center(
            child: Text(
              "Select your role",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF6A1B9A),
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => setState(() => _selectedRole = 'user'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color:
                      _selectedRole == 'user'
                          ? const Color(0xFF6A1B9A)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6A1B9A),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (_selectedRole == 'user')
                      BoxShadow(
                        color: const Color(0xFF6A1B9A).withOpacity(0.13),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person,
                      color:
                          _selectedRole == 'user'
                              ? Colors.white
                              : const Color(0xFF6A1B9A),
                      size: 22,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'User',
                      style: TextStyle(
                        color:
                            _selectedRole == 'user'
                                ? Colors.white
                                : const Color(0xFF6A1B9A),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _selectedRole = 'agency'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color:
                      _selectedRole == 'agency'
                          ? const Color(0xFF00BFAE)
                          : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF00BFAE),
                    width: 1.5,
                  ),
                  boxShadow: [
                    if (_selectedRole == 'agency')
                      BoxShadow(
                        color: const Color(0xFF00BFAE).withOpacity(0.13),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_bus,
                      color:
                          _selectedRole == 'agency'
                              ? Colors.white
                              : const Color(0xFF00BFAE),
                      size: 22,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Agency',
                      style: TextStyle(
                        color:
                            _selectedRole == 'agency'
                                ? Colors.white
                                : const Color(0xFF00BFAE),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserForm() {
    return Column(
      children: [
        _buildTextField('Full Name', Icons.person, _userNameController),
        const SizedBox(height: 16),
        _buildTextField('Email', Icons.email, _userEmailController),
        const SizedBox(height: 16),
        _buildTextField('Phone Number', Icons.phone, _userPhoneController),
        const SizedBox(height: 16),
        _buildTextField(
          'Password',
          Icons.lock,
          _userPasswordController,
          obscure: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Confirm Password',
          Icons.lock_outline,
          _userConfirmPasswordController,
          obscure: true,
        ),
        const SizedBox(height: 28),
        if (_loading) const CircularProgressIndicator(),
        if (!_loading)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _registerUser,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Register',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _registerUser() async {
    setState(() {
      errorText = '';
      _loading = true;
    });

    final email = _userEmailController.text.trim();
    final password = _userPasswordController.text.trim();
    final confirmPassword = _userConfirmPasswordController.text.trim();
    final phone = _userPhoneController.text.trim();

    // Phone validation
    if (!_isValidPhoneNumber(phone)) {
      setState(() {
        errorText =
            'Invalid phone number. Must be at least 10 digits and contain only numbers.';
        _loading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        errorText = 'Passwords do not match.';
        _loading = false;
      });
      return;
    }

    try {
      // Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // Save user details in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
            'name': _userNameController.text.trim(),
            'email': email,
            'phone': phone,
            'createdAt': FieldValue.serverTimestamp(),
          });

      setState(() => _loading = false);

      // Navigate to HomeScreen after registration
      Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      setState(() {
        errorText = e.message ?? 'Registration failed';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        errorText = 'An error occurred';
        _loading = false;
      });
    }
  }

  Future<void> _registerAgency() async {
    setState(() {
      errorText = '';
      _loading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final phone = _phoneController.text.trim();

    // Phone validation
    if (!_isValidPhoneNumber(phone)) {
      setState(() {
        errorText =
            'Invalid phone number. Must be at least 10 digits and contain only numbers.';
        _loading = false;
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        errorText = 'Passwords do not match.';
        _loading = false;
      });
      return;
    }
  try {
    // Upload files to Cloudinary
    Map<String, String> fileUrls = {};
    for (final entry in _pickedFiles.entries) {
      final filePath = entry.value;
      if (filePath.isNotEmpty) {
        final file = File(filePath);
        final url = await uploadToCloudinary(file);
        if (url != null) {
          fileUrls[entry.key] = url;
        }
      }
    }

      // Create user in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

    await FirebaseFirestore.instance
        .collection('agencies')
        .doc(userCredential.user!.uid)
        .set({
          'agencyName': _agencyNameController.text.trim(),
          'ownerName': _ownerNameController.text.trim(),
          'email': email,
          'phone': phone,
          'address': _addressController.text.trim(),
          'regNumber': _regNumberController.text.trim(),
          'documents': fileUrls, // <-- Save the document URLs here
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'pending', // Default status for admin verification
        });

    setState(() => _loading = false);

     Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AgencyInfoScreen(
          agencyName: _agencyNameController.text,
          ownerName: _ownerNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          regNumber: _regNumberController.text,
          pickedFiles: fileUrls,
          userId: userCredential.user!.uid,
        ),
      ),
    );
  } on FirebaseAuthException catch (e) {
    setState(() {
      errorText = e.message ?? 'Registration failed';
      _loading = false;
    });
  } catch (e) {
    setState(() {
      errorText = 'An error occurred';
      _loading = false;
    });
  }
}   



  Widget _buildAgencyForm() {
    return Column(
      children: [
        _buildTextField('Agency Name', Icons.business, _agencyNameController),
        const SizedBox(height: 16),
        _buildTextField(
          'Owner/Manager Name',
          Icons.person,
          _ownerNameController,
        ),
        const SizedBox(height: 16),
        _buildTextField('Email', Icons.email, _emailController),
        const SizedBox(height: 16),
        _buildTextField('Phone Number', Icons.phone, _phoneController),
        const SizedBox(height: 16),
        _buildTextField(
          'Business Address',
          Icons.location_on,
          _addressController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Business Registration Number',
          Icons.confirmation_number,
          _regNumberController,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Password',
          Icons.lock,
          _passwordController,
          obscure: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          'Confirm Password',
          Icons.lock_outline,
          _confirmPasswordController,
          obscure: true,
        ),
        const SizedBox(height: 16),
        _buildFileUpload('Business Registration Certificate'),
        const SizedBox(height: 16),
        _buildFileUpload('Bus Permit/Transport License'),
        const SizedBox(height: 16),
        _buildFileUpload('Owner ID Proof'),
        const SizedBox(height: 28),
        if (_loading) const CircularProgressIndicator(),
        if (!_loading)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _registerAgency,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
              child: const Text(
                'Submit Registration',
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController controller, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildFileUpload(String label) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _pickedFiles[label] != null
                ? '$label: ${_pickedFiles[label]}'
                : label,
            style: const TextStyle(fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            final XTypeGroup typeGroup = XTypeGroup(
              label: 'documents',
              extensions: ['pdf', 'jpg', 'jpeg', 'png'],
            );
            final XFile? file = await openFile(acceptedTypeGroups: [typeGroup]);
            if (file != null) {
              setState(() {
                _pickedFiles[label] = file.path;
              });
            }
          },
          icon: const Icon(Icons.upload_file),
          label: const Text('Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00BFAE),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  void _navigateToAgencyInfo({
    required String agencyName,
    required String ownerName,
    required String email,
    required String phone,
    required String address,
    required String regNumber,
    required Map<String, String> pickedFiles,
    required String userId,
  }) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder:
            (context) => AgencyInfoScreen(
              agencyName: agencyName,
              ownerName: ownerName,
              email: email,
              phone: phone,
              address: address,
              regNumber: regNumber,
              pickedFiles: pickedFiles,
              userId: userId,
            ),
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
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
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
                  _buildRoleSelector(),
                  const SizedBox(height: 32),
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
                  if (_selectedRole == 'user') _buildUserForm(),
                  if (_selectedRole == 'agency') _buildAgencyForm(),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Already have an account?",
                        style: TextStyle(
                          color: Color(0xFF6A1B9A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginScreen(),
                            ),
                          );
                          if (result != null &&
                              result is Map<String, dynamic>) {
                            _navigateToAgencyInfo(
                              agencyName: result['agencyName'] ?? '',
                              ownerName: result['ownerName'] ?? '',
                              email: result['email'] ?? '',
                              phone: result['phone'] ?? '',
                              address: result['address'] ?? '',
                              regNumber: result['regNumber'] ?? '',
                              pickedFiles: Map<String, String>.from(
                                result['pickedFiles'] ?? {},
                              ),
                              userId: result['userId'] ?? '',
                            );
                          }
                        },
                        child: const Text(
                          "Login",
                          style: TextStyle(
                            color: Color(0xFF00BFAE),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
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
    );
  }
}
