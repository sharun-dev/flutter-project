import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'login_screen.dart';


class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final List<String> _tabs = [
    'Admin Panel',
    'Users',
    'Agencies',
    'Bookings',
    'Reports',
  ];
  int _selectedIndex = 0;
  final Color _mainColor = const Color(0xFF6A1B9A);

  void _onTabTapped(int idx) {
    setState(() => _selectedIndex = idx);
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }

  // --- ADDED: Helper dialog for reject/delete ---
  Future<void> _showRejectDialog({
    required String type, // 'user' or 'agency'
    required String docId,
    required VoidCallback onReject,
    required VoidCallback onDelete,
  }) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Reject or Delete $type?'),
            content: Text(
              'Would you like to reject (mark as rejected) or permanently delete this $type?',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onReject();
                },
                child: const Text(
                  'Reject',
                  style: TextStyle(color: Colors.orange),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onDelete();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  // --- ADDED: Delete functions ---
  Future<void> _deleteUser(String userId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('User deleted')));
  }

  Future<void> _deleteAgency(String agencyId) async {
    await FirebaseFirestore.instance
        .collection('agencies')
        .doc(agencyId)
        .delete();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Agency deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildAnalyticsTab(),
      _buildUsersTab(),
      _buildAgenciesTab(),
      _buildBookingsTab(),
      _buildReportsTab(),
    ];

    PreferredSizeWidget? getAppBar() {
      return AppBar(
        backgroundColor: _mainColor,
        elevation: 0,
        title: Text(
          _tabs[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log Out',
            onPressed: _logout,
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: getAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: pages[_selectedIndex],
      ),
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 54,
        backgroundColor: Colors.transparent,
        color: _mainColor,
        buttonBackgroundColor: const Color(0xFF00BFAE),
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 300),
        items: const [
          Icon(Icons.analytics, size: 26, color: Colors.white),
          Icon(Icons.people, size: 26, color: Colors.white),
          Icon(Icons.business, size: 26, color: Colors.white),
          Icon(Icons.book_online, size: 26, color: Colors.white),
          Icon(Icons.report, size: 26, color: Colors.white),
        ],
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _buildUsersTab() {
    return Container(
      color: const Color(0xFFF3E5F5),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.deepPurple.shade100,
                    child: const Icon(Icons.person, color: Colors.deepPurple),
                  ),
                  title: Text(
                    data['name'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Email: ${data['email'] ?? ''}\n'
                    'Phone: ${data['phone'] ?? ''}\n'
                    'Status: ${data['status'] ?? ''}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.verified, color: Colors.green),
                        onPressed:
                            () => _updateUserStatus(docs[i].id, 'verified'),
                        tooltip: 'Verify',
                      ),
                      IconButton(
                        icon: const Icon(Icons.block, color: Colors.red),
                        onPressed:
                            () => _showRejectDialog(
                              type: 'user',
                              docId: docs[i].id,
                              onReject:
                                  () =>
                                      _updateUserStatus(docs[i].id, 'rejected'),
                              onDelete: () => _deleteUser(docs[i].id),
                            ),
                        tooltip: 'Reject/Delete',
                      ),
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

  Future<void> _updateUserStatus(String userId, String status) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'status': status,
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('User $status')));
  }

  Widget _buildAgenciesTab() {
    return Container(
      color: const Color(0xFFE3F2FD),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('agencies').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
            
              final status = data['status'] ?? 'pending';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.business, color: Colors.blue),
                  ),
                  title: Text(
                    data['agencyName'] ?? 'No Name',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Email: ${data['email'] ?? ''}\n'
                    'Phone: ${data['phone'] ?? ''}\n'
                    'Owner: ${data['ownerName'] ?? ''}\n'
                    'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Business Address: ${data['address'] ?? ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          Text(
                            'Registration Number: ${data['regNumber'] ?? ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 8),
  const Text(
    'Documents:',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),
  if (data['ownerIdProofUrl'] != null && data['ownerIdProofUrl'].toString().isNotEmpty)
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Text('Owner ID Proof: ', style: TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                data['ownerIdProofUrl'],
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 80,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
Row(
  mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (status == 'pending') ...[
                                IconButton(
                                  icon: const Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                  ),
                                  onPressed:
                                      () => _updateAgencyStatus(
                                        docs[i].id,
                                        'verified',
                                      ),
                                  tooltip: 'Verify',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.block,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => _showRejectDialog(
                                        type: 'agency',
                                        docId: docs[i].id,
                                        onReject:
                                            () => _updateAgencyStatus(
                                              docs[i].id,
                                              'rejected',
                                            ),
                                        onDelete:
                                            () => _deleteAgency(docs[i].id),
                                      ),
                                  tooltip: 'Reject/Delete',
                                ),
                              ] else ...[
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0),
                                  child: Text(
                                    status == 'verified'
                                        ? 'Verified'
                                        : 'Rejected',
                                    style: TextStyle(
                                      color:
                                          status == 'verified'
                                              ? Colors.green
                                              : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateAgencyStatus(String agencyId, String status) async {
    await FirebaseFirestore.instance
        .collection('agencies')
        .doc(agencyId)
        .update({'status': status});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Agency $status')));
  }

  Widget _buildBookingsTab() {
    return Container(
      color: const Color(0xFFFFFDE7),
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance.collectionGroup('bookings').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final busName = data['busName'] ?? '';
              final userId = data['userId'] ?? '';
              final status = data['status'] ?? '';
              final bookingDate =
                  data['bookingDate'] is Timestamp
                      ? (data['bookingDate'] as Timestamp).toDate()
                      : null;
              final location = data['location'] ?? '';
              final payment =
                  'Payment: ₹${data['totalPrice'] ?? ''} (${data['paymentMethod'] ?? ''})';

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.cyan.shade100,
                    child: const Icon(Icons.directions_bus, color: Colors.cyan),
                  ),
                  title: Text(
                    'Bus: $busName',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle:
                      (userId == null || userId.isEmpty)
                          ? Text(
                            'User: (unknown)\n'
                            'Status: $status\n'
                            'Date: $bookingDate\n'
                            'Payment: $payment\n'
                            'Location: $location',
                            style: const TextStyle(fontSize: 13),
                          )
                          : FutureBuilder<DocumentSnapshot>(
                            future:
                                FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .get(),
                            builder: (context, userSnap) {
                              String userName = '';
                              if (userSnap.hasData && userSnap.data!.exists) {
                                final userData =
                                    userSnap.data!.data()
                                        as Map<String, dynamic>;
                                userName = userData['name'] ?? '';
                              }
                              return Text(
                                'User: $userName ($userId)\n'
                                'Status: $status\n'
                                'Date: $bookingDate\n'
                                'Payment: $payment\n'
                                'Location: $location',
                                style: const TextStyle(fontSize: 13),
                              );
                            },
                          ),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed:
                            () => _updateBookingStatus(
                              docs[i].reference,
                              'accepted',
                            ),
                        tooltip: 'Accept',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed:
                            () => _updateBookingStatus(
                              docs[i].reference,
                              'rejected',
                            ),
                        tooltip: 'Reject',
                      ),
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

  Future<void> _updateBookingStatus(
    DocumentReference bookingRef,
    String status,
  ) async {
    await bookingRef.update({'status': status});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Booking $status')));
  }

  Widget _buildAnalyticsTab() {
    return Container(
      color: const Color(0xFFE3F2FD),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.deepPurple.shade700,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: FutureBuilder<int>(
                  future: _getTotalCount('users'),
                  builder: (context, snapshot) {
                    final totalUsers = snapshot.data ?? 0;
                    return Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 26),
                        const SizedBox(width: 12),
                        Text(
                          'Total Users: $totalUsers',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.blue.shade700,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: FutureBuilder<int>(
                  future: _getTotalCount('agencies'),
                  builder: (context, snapshot) {
                    final totalAgencies = snapshot.data ?? 0;
                    return Row(
                      children: [
                        const Icon(
                          Icons.business,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Total Agencies: $totalAgencies',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 22),
            // App Usage Per Week graph removed as requested
          ],
        ),
      ),
    );
  }

  Future<int> _getTotalCount(String collection) async {
    final snap = await FirebaseFirestore.instance.collection(collection).get();
    return snap.size;
  }

  Widget _buildReportsTab() {
    return Container(
      color: const Color(0xFFFFF3E0),
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('reports')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No reports found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final isUserReport =
                  data['type'] == 'agency' && data['userEmail'] != null;
              final isAgencyReport =
                  data['from'] == 'agency' && data['agencyEmail'] != null;
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isUserReport
                            ? Colors.deepPurple.shade100
                            : Colors.blue.shade100,
                    child: Icon(
                      isUserReport ? Icons.person : Icons.business,
                      color: isUserReport ? Colors.deepPurple : Colors.blue,
                    ),
                  ),
                  title: Text(
                    isUserReport
                        ? 'User: ${data['userEmail'] ?? ''}'
                        : 'Agency: ${data['agencyEmail'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUserReport)
                        Text(
                          'User ID: ${data['userId'] ?? ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (isAgencyReport)
                        Text(
                          'Agency ID: ${data['agencyId'] ?? ''}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      Text(
                        'Type: ${data['type'] ?? data['from'] ?? ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data['text'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      if (data['timestamp'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            (data['timestamp'] is Timestamp)
                                ? (data['timestamp'] as Timestamp)
                                    .toDate()
                                    .toString()
                                : data['timestamp'].toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
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
