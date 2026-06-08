import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'bus_details_page.dart';
import 'user_profile.dart';
import 'dart:async';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'chat_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// --- Unwatched Bookings Stream ---
Stream<int> getUnwatchedUpcomingCount(String userId) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('bookings')
      .where('status', isEqualTo: 'accepted')
      .where('watched', isEqualTo: false)
      .snapshots()
      .map((snap) => snap.docs.length);
}

// --- Bus Search Delegate ---
class BusSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> buses;
  final Color mainColor;
  final BuildContext parentContext;

  BusSearchDelegate(this.buses, this.mainColor, this.parentContext);

  @override
  String get searchFieldLabel => 'Search buses...';

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final results =
        buses
            .where(
              (bus) => (bus['name'] ?? '').toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
            )
            .toList();

    if (results.isEmpty) {
      return Center(child: Text('No buses found.'));
    }

    return ListView(
      children:
          results
              .map(
                (bus) => ListTile(
                  leading:
                      (bus['images'] != null &&
                              bus['images'] is List &&
                              (bus['images'] as List).isNotEmpty &&
                              (bus['images'][0] is String) &&
                              (bus['images'][0] as String).isNotEmpty)
                          ? CircleAvatar(
                            backgroundImage: NetworkImage(bus['images'][0]),
                            backgroundColor: Colors.grey[200],
                          )
                          : CircleAvatar(
                            child: Icon(Icons.directions_bus),
                            backgroundColor: Colors.grey[200],
                          ),
                  title: Text(bus['name'] ?? ''),
                  subtitle: Text(bus['agencyName'] ?? ''),
                  onTap: () {
                    if (bus['agencyId'] != null && bus['docId'] != null) {
                      Navigator.push(
                        parentContext,
                        MaterialPageRoute(
                          builder:
                              (_) => BusDetailsPage(
                                agencyId: bus['agencyId'],
                                busDocId: bus['docId'],
                              ),
                        ),
                      );
                    }
                  },
                ),
              )
              .toList(),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return buildResults(context);
  }
}

// --- Terms and Conditions Page ---
class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Conditions'),
        backgroundColor: Color(0xFF6A1B9A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: SingleChildScrollView(
          child: Text(
            '''Terms and conditions,
1. The required information about users and agencies must be given at the registration time. 
2. The information will be accessed and verified by the admin. 
3. The requests without proper information may be rejected by the admin.
4. The users and agencies are connected through the app after the  admin verification. 
5. The agencies must give their proper details about their vehicle and their minimum charge for the trip according to per day. 
6. The compliant about the app like ( agencies dealings, additional payment,time delay, etc) can be directly reported to admin.''',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}

// --- Report Page ---
class ReportPage extends StatefulWidget {
  final String reportType; // "app" or "agency"
  const ReportPage({super.key, required this.reportType});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;

  Future<void> _submitReport() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    await FirebaseFirestore.instance.collection('reports').add({
      'type': widget.reportType,
      'text': text,
      'userId': user?.uid,
      'userEmail': user?.email,
      'timestamp': FieldValue.serverTimestamp(),
    });

    setState(() => _loading = false);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report submitted!')));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.reportType == 'app'
              ? 'Report about App'
              : 'Report about Agency',
        ),
        backgroundColor: Color(0xFF6A1B9A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Type your report here',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF00BFAE),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text(
                          'Register',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
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

// --- ChatTab Widget ---
class ChatTab extends StatelessWidget {
  const ChatTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('chatRooms')
              .where('participants', arrayContains: userId)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final chatRooms = snapshot.data!.docs;
        if (chatRooms.isEmpty) {
          return const Center(child: Text('No chats yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          itemCount: chatRooms.length,
          itemBuilder: (context, idx) {
            final data = chatRooms[idx].data() as Map<String, dynamic>;
            final participants = List<String>.from(data['participants']);
            final agencyId = participants.firstWhere((id) => id != userId);

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance
                      .collection('agencies')
                      .doc(agencyId)
                      .get(),
              builder: (context, agencySnapshot) {
                String agencyName = 'Agency';
                String? agencyImage;
                if (agencySnapshot.hasData && agencySnapshot.data!.exists) {
                  final agencyData =
                      agencySnapshot.data!.data() as Map<String, dynamic>;
                  agencyName = agencyData['agencyName'] ?? 'Agency';
                  agencyImage = agencyData['profileImage'] ?? null;
                }

                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 18,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.deepPurple[100],
                      backgroundImage:
                          (agencyImage != null && agencyImage.isNotEmpty)
                              ? NetworkImage(agencyImage)
                              : null,
                      child:
                          (agencyImage == null || agencyImage.isEmpty)
                              ? const Icon(
                                Icons.business,
                                size: 32,
                                color: Color(0xFF6A1B9A),
                              )
                              : null,
                    ),
                    title: Text(
                      agencyName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF6A1B9A),
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: Colors.teal,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Tap to chat',
                          style: TextStyle(
                            color: Colors.teal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.deepPurple,
                      size: 20,
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ChatPage(
                                busName: agencyName,
                                agencyId: agencyId,
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// --- Review Dialog Widget ---
Future<void> showReviewDialog(
  BuildContext context,
  String agencyId,
  String busDocId,
  String busName,
) async {
  final TextEditingController _reviewController = TextEditingController();
  double _rating = 5.0;
  return showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Review $busName'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _reviewController,
                  decoration: InputDecoration(labelText: 'Write your review'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Rating:'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _rating.toString(),
                        onChanged: (val) {
                          setState(() {
                            _rating = val;
                          });
                        },
                      ),
                    ),
                    Text(_rating.toStringAsFixed(1)),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final reviewText = _reviewController.text.trim();
                  if (reviewText.isNotEmpty && _rating > 0) {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final newReview = {
                      // Should be user's name
                      'userEmail': currentUser?.email ?? '',
                      'text': reviewText,
                      'review': reviewText,
                      'rating': _rating,
                      'timestamp': FieldValue.serverTimestamp(),
                    };
                    try {
                      // Add to bus reviews
                      final busReviewsRef = FirebaseFirestore.instance
                          .collection('agencies')
                          .doc(agencyId)
                          .collection('buses')
                          .doc(busDocId)
                          .collection('reviews');
                      await busReviewsRef.add(newReview);

                      // Add to agency reviews
                      final agencyReviewsRef = FirebaseFirestore.instance
                          .collection('agencies')
                          .doc(agencyId)
                          .collection('reviews');
                      await agencyReviewsRef.add(newReview);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Review submitted!')),
                      );
                      Navigator.pop(ctx);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to submit review.'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );
    },
  );
}

// --- UserBookingsTab with Notification Badge ---
class UserBookingsTab extends StatefulWidget {
  const UserBookingsTab({super.key});

  @override
  State<UserBookingsTab> createState() => _UserBookingsTabState();
}

class _UserBookingsTabState extends State<UserBookingsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Upcoming\nSchedules', 'Cancelled', 'Expired'];
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _deleteBooking(
    String userId,
    String agencyId,
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Delete from user's bookings
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('bookings')
          .doc(bookingId)
          .delete();

      // Delete from agency's bookings
      if (agencyId.isNotEmpty) {
        final agencyBookingQuery =
            await FirebaseFirestore.instance
                .collection('agencies')
                .doc(agencyId)
                .collection('bookings')
                .where('userId', isEqualTo: userId)
                .where('busName', isEqualTo: data['busName'])
                .where('bookingDate', isEqualTo: data['bookingDate'])
                .get();

        for (var doc in agencyBookingQuery.docs) {
          await doc.reference.delete();
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking deleted successfully.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete booking: $e')));
      }
    }
  }

  // Mark all unwatched bookings as watched
  Future<void> markUpcomingAsWatched(String userId) async {
    final snap =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('bookings')
            .where('status', isEqualTo: 'accepted')
            .where('watched', isEqualTo: false)
            .get();
    for (var doc in snap.docs) {
      await doc.reference.update({'watched': true});
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_tabs.length, (i) {
              final isSelected = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedTab = i;
                      _tabController.index = i;
                    });
                    if (i == 0) {
                      await markUpcomingAsWatched(userId);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 54,
                    padding: const EdgeInsets.symmetric(vertical: 0),
                    decoration: BoxDecoration(
                      color: isSelected ? Color(0xFF6A1B9A) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color:
                            isSelected ? Color(0xFF6A1B9A) : Colors.grey[300]!,
                        width: 1.5,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: Color(0xFF6A1B9A).withOpacity(0.10),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ]
                              : [],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _tabs[i],
                            style: TextStyle(
                              color:
                                  isSelected ? Colors.white : Color(0xFF6A1B9A),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (i == 0)
                            StreamBuilder<int>(
                              stream: getUnwatchedUpcomingCount(userId),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                if (count == 0) return SizedBox.shrink();
                                return Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildBookingsList(userId, status: 'accepted'),
              _buildBookingsList(userId, status: 'cancelled'),
              _buildBookingsList(userId, expired: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBookingsList(
    String userId, {
    String? status,
    bool expired = false,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('bookings')
              .orderBy('timestamp', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bookings =
            snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              DateTime? bookingDate;
              if (data['bookingDate'] is Timestamp) {
                bookingDate = (data['bookingDate'] as Timestamp).toDate();
              } else if (data['bookingDate'] is DateTime) {
                bookingDate = data['bookingDate'];
              }
              final isExpired =
                  bookingDate != null && bookingDate.isBefore(DateTime.now());
              if (expired) {
                return isExpired;
              }
              if (status != null) {
                return !isExpired &&
                    (data['status']?.toString().toLowerCase() == status);
              }
              return false;
            }).toList();

        if (bookings.isEmpty) {
          return const Center(child: Text('No bookings yet.'));
        }

        return ListView.builder(
          itemCount: bookings.length,
          itemBuilder: (context, idx) {
            final data = bookings[idx].data() as Map<String, dynamic>;
            final bookingId = bookings[idx].id;
            final agencyId = data['agencyId'];
            final busName = data['busName'] ?? '';
            DateTime? bookingDate;
            if (data['bookingDate'] is Timestamp) {
              bookingDate = (data['bookingDate'] as Timestamp).toDate();
            } else if (data['bookingDate'] is DateTime) {
              bookingDate = data['bookingDate'];
            }
            final isExpired =
                bookingDate != null && bookingDate.isBefore(DateTime.now());

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text('${data['busName']} (${data['agencyName'] ?? ''})'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${bookingDate != null ? bookingDate.toString().split(' ')[0] : ''}',
                    ),
                    Text('Location: ${data['location'] ?? ''}'),
                    Text('Duration: ${data['daysDuration'] ?? ''} days'),
                    Text(
                      'Status: ${isExpired ? 'Expired' : (data['status'] ?? '')}',
                      style: TextStyle(
                        color: isExpired ? Colors.red : null,
                        fontWeight: isExpired ? FontWeight.bold : null,
                      ),
                    ),
                    if (!isExpired &&
                        data['status'] != 'cancelled' &&
                        data['status'] != 'Cancelled')
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('Cancel Booking?'),
                                    content: const Text(
                                      'Are you sure you want to cancel this booking?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        child: const Text('Yes'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirm != true) return;

                            try {
                              // 1. Update status in agency's bookings collection
                              if (agencyId != null) {
                                final agencyBookingQuery =
                                    await FirebaseFirestore.instance
                                        .collection('agencies')
                                        .doc(agencyId)
                                        .collection('bookings')
                                        .where('userId', isEqualTo: userId)
                                        .where(
                                          'busName',
                                          isEqualTo: data['busName'],
                                        )
                                        .where(
                                          'bookingDate',
                                          isEqualTo: data['bookingDate'],
                                        )
                                        .get();

                                for (var doc in agencyBookingQuery.docs) {
                                  await doc.reference.update({
                                    'status': 'cancelled',
                                  });
                                }
                              }

                              // 2. Update status in user's bookings collection
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(userId)
                                  .collection('bookings')
                                  .doc(bookingId)
                                  .update({'status': 'cancelled'});

                              if (context.mounted) {
                                showDialog(
                                  context: context,
                                  builder:
                                      (ctx) => AlertDialog(
                                        title: const Text('Booking Cancelled'),
                                        content: const Text(
                                          'Your booking has been cancelled, and your refund will be processed shortly.',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to cancel booking: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text('Cancel Booking'),
                        ),
                      ),

                    // Add delete button for cancelled or expired bookings
                    if ((isExpired ||
                        (data['status']?.toString().toLowerCase() ==
                            'cancelled')))
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.delete),
                          label: const Text('Delete'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              200,
                              15,
                              15,
                            ),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder:
                                  (ctx) => AlertDialog(
                                    title: const Text('Delete Booking?'),
                                    content: const Text(
                                      'Are you sure you want to permanently delete this booking?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, false),
                                        child: const Text('No'),
                                      ),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.pop(ctx, true),
                                        child: const Text('Yes'),
                                      ),
                                    ],
                                  ),
                            );
                            if (confirm == true) {
                              await _deleteBooking(
                                userId,
                                agencyId,
                                bookingId,
                                data,
                              );
                            }
                          },
                        ),
                      ),

                    // Add review button for expired bookings
                    if (isExpired)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.rate_review),
                          label: const Text('Add Review'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            if (agencyId != null) {
                              showReviewDialog(
                                context,
                                agencyId,
                                bookingId,
                                busName,
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userEmail;
  final String? userAddress;

  const HomeScreen({
    super.key,
    required this.userName,
    required this.userPhone,
    required this.userEmail,
    this.userAddress,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Color _mainColor = Color(0xFF6A1B9A);

  int _selectedIndex = 0;
  String _searchQuery = '';
  String _selectedPlace = 'All';
  final List<String> _places = [
    'All',
    'Trivandrum',
    'Kollam',
    'Pathanamthitta',
    'Alappuzha',
    'Kottayam',
    'Idukki',
    'Ernakulam',
    'Thrissur',
    'Palakkad',
    'Malappuram',
    'Kozhikode',
    'Wayanad',
    'Kannur',
    'Kasaragod',
  ];

  late String _userName;
  late String _userEmail;

  final PageController _offerPageController = PageController(
    viewportFraction: 0.93,
  );
  Timer? _offerScrollTimer;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
    _userEmail = widget.userEmail;
    _initFCM();
  }

  @override
  void dispose() {
    _offerScrollTimer?.cancel();
    _offerPageController.dispose();
    super.dispose();
  }

  // --- Push Notification Setup ---
  void _initFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request permissions (iOS)
    await messaging.requestPermission();

    // Get the token (you can send this to your backend if needed)
    String? token = await messaging.getToken();
    print('FCM Token: $token');

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification!.title ?? 'New Notification'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    // Handle background & terminated messages (optional)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Handle notification tap
      print('Notification clicked!');
    });
  }

  Stream<List<Map<String, dynamic>>> getAllBusesStream() {
    return FirebaseFirestore.instance
        .collection('agencies')
        .snapshots()
        .asyncMap((agencySnap) async {
          List<Map<String, dynamic>> buses = [];
          for (var agencyDoc in agencySnap.docs) {
            final busesSnap =
                await agencyDoc.reference.collection('buses').get();
            for (var busDoc in busesSnap.docs) {
              buses.add({
                ...busDoc.data(),
                'docId': busDoc.id,
                'agencyId': agencyDoc.id,
                'agencyName': agencyDoc.data()['agencyName'] ?? '',
              });
            }
          }
          return buses;
        });
  }

  // --- Special Offers Stream ---
  Stream<List<Map<String, dynamic>>> getSpecialOffersStream() {
    return FirebaseFirestore.instance
        .collectionGroup('offers')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) {
                final data = doc.data();
                return {...data, 'docId': doc.id};
              }).toList(),
        );
  }

  // --- Special Offers Carousel Widget ---
  Widget _buildSpecialOffersCarousel() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: getSpecialOffersStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          _offerScrollTimer?.cancel(); // Stop timer if no offers
          return const SizedBox.shrink();
        }
        final offers = snapshot.data!;

        // Start auto-scroll timer when offers are loaded
        if (_offerScrollTimer == null || !_offerScrollTimer!.isActive) {
          _offerScrollTimer = Timer.periodic(const Duration(seconds: 2), (
            timer,
          ) {
            if (_offerPageController.hasClients && offers.isNotEmpty) {
              int nextPage = (_offerPageController.page?.round() ?? 0) + 1;
              if (nextPage >= offers.length) nextPage = 0;
              _offerPageController.animateToPage(
                nextPage,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
              );
            }
          });
        }

        return SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _offerPageController,
            itemCount: offers.length,
            itemBuilder: (context, idx) {
              final offer = offers[idx];
              return GestureDetector(
                onTap: () async {
                  final agency = offer['agency'];
                  final buses = await getAllBusesStream().first;
                  final bus = buses.firstWhere(
                    (b) => b['agencyName'] == agency,
                    orElse: () => buses.first,
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => BusDetailsPage(
                            agencyId: bus['agencyId'],
                            busDocId: bus['docId'],
                          ),
                    ),
                  );
                },

                child: Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                        child:
                            offer['imageUrl'] != null && offer['imageUrl'] != ''
                                ? Image.network(
                                  offer['imageUrl'],
                                  width: 140,
                                  height: 170,
                                  fit: BoxFit.cover,
                                )
                                : Container(
                                  width: 140,
                                  height: 170,
                                  color: Colors.grey[300],
                                  child: const Icon(
                                    Icons.local_offer,
                                    size: 40,
                                  ),
                                ),
                      ),
                      Expanded(
                        child: Container(
                          height: 170,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topRight: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer['description'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Colors.black,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                if (offer['agency'] != null)
                                  Text(
                                    'By: ${offer['agency']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.deepPurple,
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
            },
          ),
        );
      },
    );
  }

  Widget _buildHomePage() {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        // --- Special Offers Carousel at the Top ---
        _buildSpecialOffersCarousel(),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: Material(
                elevation: 6,
                shadowColor: _mainColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(22),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: getAllBusesStream().first,
                  builder: (context, snapshot) {
                    return TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Search buses...',
                        hintStyle: TextStyle(
                          color: _mainColor.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: _mainColor,
                          size: 28,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 0,
                          horizontal: 18,
                        ),
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _mainColor,
                      ),
                      onTap: () async {
                        final buses = snapshot.data ?? [];
                        showSearch(
                          context: context,
                          delegate: BusSearchDelegate(
                            buses,
                            _mainColor,
                            context,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _mainColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: _mainColor.withOpacity(0.08),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPlace,
                  icon: Icon(Icons.arrow_drop_down, color: _mainColor),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  style: TextStyle(
                    color: _mainColor,
                    fontWeight: FontWeight.bold,
                  ),
                  items:
                      _places
                          .map(
                            (place) => DropdownMenuItem(
                              value: place,
                              child: Text(place),
                            ),
                          )
                          .toList(),
                  onChanged: (val) => setState(() => _selectedPlace = val!),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.directions_bus_sharp,
              color: Colors.amber[700],
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Explore & Book All Kerala Tourist Buses in One Place',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _mainColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                softWrap: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const SizedBox(height: 18),
        const SizedBox(height: 12),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: getAllBusesStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('No buses uploaded yet.'));
            }




































            final buses =
                snapshot.data!.where((bus) {
                  final matchesPlace =
                      _selectedPlace == 'All' ||
                      (bus['place']?.toString().toLowerCase().trim().contains(
                            _selectedPlace.toLowerCase().trim(),
                          ) ??
                          false);

                  final matchesSearch =
                      _searchQuery.isEmpty ||
                      (bus['name'] ?? '').toString().toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      );
                  return matchesPlace && matchesSearch;
                }).toList();

            if (buses.isEmpty) {
              return const Center(
                child: Text('No buses found for your filter.'),
              );
            }
            return Column(
              children:
                  buses.map((bus) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final imageWidth =
                            constraints.maxWidth * 0.4; // 40% of card width
                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 5,
                          shadowColor: _mainColor.withOpacity(0.10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(18),
                                  bottomLeft: Radius.circular(18),
                                ),
                                child:
                                    (bus['images'] != null &&
                                            bus['images'] is List &&
                                            (bus['images'] as List).isNotEmpty)
                                        ? Image.network(
                                          (bus['images'][0] is String)
                                              ? bus['images'][0]
                                              : '',
                                          width: imageWidth,
                                          height: 185,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    width: imageWidth,
                                                    height: 185,
                                                    color: Colors.grey[300],
                                                    child: const Icon(
                                                      Icons.directions_bus,
                                                      size: 40,
                                                    ),
                                                  ),
                                        )
                                        : Container(
                                          width: imageWidth,
                                          height: 150,
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.directions_bus,
                                            size: 40,
                                          ),
                                        ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 185,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(18),
                                      bottomRight: Radius.circular(18),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          bus['name'] ?? '',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: _mainColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        const SizedBox(height: 6),
                                        // Rating & Price Row
                                        Row(
                                          children: [
                                            // Rating
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.amber[100],
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    (bus['rating'] ?? 5.0)
                                                        .toString(),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Price
                                            if (bus['price'] != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.teal[50],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  '₹${bus['price']}/km',
                                                  style: const TextStyle(
                                                    color: Colors.teal,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // Place
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              color: Colors.deepPurple,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              bus['place'] ?? '',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Colors.deepPurple,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),

                                        if (bus['agencyName'] != null &&
                                            bus['agencyName']
                                                .toString()
                                                .isNotEmpty)
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.business,
                                                color: Colors.indigo,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Agency: ${bus['agencyName']}',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.indigo,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        const Spacer(),

                                        Align(
                                          alignment: Alignment.bottomRight,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          BusDetailsPage(
                                                            agencyId:
                                                                bus['agencyId'],
                                                            busDocId:
                                                                bus['docId'],
                                                          ),
                                                ),
                                              );
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF00BFAE,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(22),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 18,
                                                    vertical: 10,
                                                  ),
                                              elevation: 2,
                                            ),
                                            child: const Text(
                                              'View',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 5,
                                                fontSize: 15,
                                              ),
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
                        );
                      },
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget bookingsTabIcon(String userId) {
    return StreamBuilder<int>(
      stream: getUnwatchedUpcomingCount(userId),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return Stack(
          children: [
            const Icon(Icons.book_online, size: 30, color: Colors.white),
            if (count > 0)
              Positioned(
                right: 0,
                top: 0,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: Colors.red,
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final pages = [
      _buildHomePage(),
      const UserBookingsTab(),
      const ChatTab(),
      UserProfileScreen(username: _userName, email: _userEmail),
    ];

    PreferredSizeWidget? getAppBar() {
      if (_selectedIndex == 0) {
        return AppBar(
          backgroundColor: _mainColor,
          elevation: 0,
          title: Text(
            'TravelMate',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 28,
              letterSpacing: 1.5,
              shadows: [
                Shadow(
                  color: Colors.black26,
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.more_vert, color: Colors.white, size: 34),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(18),
                    ),
                  ),
                  builder: (ctx) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.description),
                            title: const Text('Terms and conditions'),
                            onTap: () {
                              Navigator.pop(ctx);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => const TermsAndConditionsPage(),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.report),
                            title: const Text('Report'),
                            onTap: () {
                              Navigator.pop(ctx);
                              showModalBottomSheet(
                                context: context,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(18),
                                  ),
                                ),
                                builder: (ctx2) {
                                  return SafeArea(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: const Icon(Icons.bug_report),
                                          title: const Text('Report about app'),
                                          onTap: () {
                                            Navigator.pop(ctx2);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => const ReportPage(
                                                      reportType: 'app',
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.business),
                                          title: const Text(
                                            'Report about agency',
                                          ),
                                          onTap: () {
                                            Navigator.pop(ctx2);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder:
                                                    (_) => const ReportPage(
                                                      reportType: 'agency',
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              tooltip: 'More',
            ),
          ],
          iconTheme: IconThemeData(color: Colors.white, size: 28),
        );
      } else if (_selectedIndex == 1) {
        return AppBar(
          backgroundColor: _mainColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Bookings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 1.1,
            ),
          ),
          centerTitle: true,
        );
      } else if (_selectedIndex == 2) {
        return AppBar(
          backgroundColor: _mainColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Chats',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 22,
              letterSpacing: 1.1,
            ),
          ),
          centerTitle: true,
        );
      } else {
        return null;
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: getAppBar(),
      body: pages[_selectedIndex],
      bottomNavigationBar: CurvedNavigationBar(
        index: _selectedIndex,
        height: 60,
        backgroundColor: Colors.transparent,
        color: _mainColor,
        buttonBackgroundColor: const Color(0xFF00BFAE),
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 400),
        items: [
          const Icon(Icons.home, size: 30, color: Colors.white),
          bookingsTabIcon(userId),
          const Icon(Icons.chat, size: 30, color: Colors.white),
          const Icon(Icons.person, size: 30, color: Colors.white),
        ],
        onTap: (idx) {
          setState(() => _selectedIndex = idx);
        },
      ),
    );
  }
}
