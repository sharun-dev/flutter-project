import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;
  final String email;
  final String? phone;
  final String? address;

  const UserProfileScreen({
    super.key,
    required this.username,
    required this.email,
    this.phone,
    this.address,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _isEditing = false;

  String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.username);
    _emailController = TextEditingController(text: widget.email);
    _phoneController = TextEditingController(text: widget.phone ?? '');
    _addressController = TextEditingController(text: widget.address ?? '');
    _loadProfileFromFirestore();
  }

  Future<void> _loadProfileFromFirestore() async {
    if (_currentUserId == null) return;
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['name'] ?? widget.username;
          _emailController.text = data['email'] ?? widget.email;
          _phoneController.text = data['phone'] ?? (widget.phone ?? '');
          _addressController.text = data['address'] ?? (widget.address ?? '');
        });
      }
    } catch (e) {
      // Optionally handle error
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF6A1B9A),
        centerTitle: true,
        automaticallyImplyLeading: false, // Removes the back arrow
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
          child: Column(
            children: [
              // Simple Avatar and Name
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.deepPurple.shade100,
                child: Icon(Icons.person, color: Colors.deepPurple, size: 54),
              ),
              const SizedBox(height: 16),
              Text(
                _nameController.text,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6A1B9A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _emailController.text,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 18,
                    horizontal: 16,
                  ),
                  child: Column(
                    children: [
                      _profileField(
                        icon: Icons.person,
                        label: 'Name',
                        controller: _nameController,
                        isEditing: _isEditing,
                      ),
                      const Divider(height: 28),
                      _profileField(
                        icon: Icons.email,
                        label: 'Email',
                        controller: _emailController,
                        isEditing: _isEditing,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const Divider(height: 28),
                      _profileField(
                        icon: Icons.phone,
                        label: 'Phone',
                        controller: _phoneController,
                        isEditing: _isEditing,
                        keyboardType: TextInputType.phone,
                      ),
                      const Divider(height: 28),
                      _profileField(
                        icon: Icons.home,
                        label: 'Address',
                        controller: _addressController,
                        isEditing: _isEditing,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 36),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        'Logout',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      onPressed: () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text(
                              'Are you sure you want to log out?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(color: Color.fromARGB(255, 161, 14, 3)),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (shouldLogout == true) {
                          await FirebaseAuth.instance.signOut();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (route) => false,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      icon: Icon(
                        _isEditing ? Icons.save : Icons.edit,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isEditing ? 'Save' : 'Edit',
                        style: const TextStyle(fontSize: 16, color: Colors.white),
                      ),
                      onPressed: () async {
                        if (_isEditing) {
                          // Save changes to Firestore
                          if (_currentUserId != null) {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(_currentUserId)
                                .update({
                              'name': _nameController.text.trim(),
                              'email': _emailController.text.trim(),
                              'phone': _phoneController.text.trim(),
                              'address': _addressController.text.trim(),
                            });
                          }
                          setState(() {
                            _isEditing = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile updated')),
                          );
                        } else {
                          setState(() {
                            _isEditing = true;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileField({
    required IconData icon,
    required String label,
    required TextEditingController controller,
    required bool isEditing,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment:
          maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: const Color(0xFF6A1B9A)),
        const SizedBox(width: 12),
        Expanded(
          child:
              isEditing
                  ? TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      labelText: label,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  )
                  : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      controller.text.isEmpty ? 'Not set' : controller.text,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ),
        ),
      ],
    );
  }
}