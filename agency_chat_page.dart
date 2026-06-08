import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AgencyChatPage extends StatefulWidget {
  final String chatRoomId;
  final String agencyId;
  final String userId;
  final String userName;

  const AgencyChatPage({
    super.key,
    required this.chatRoomId,
    required this.agencyId,
    required this.userId,
    required this.userName,
  });

  @override
  State<AgencyChatPage> createState() => _AgencyChatPageState();
}

class _AgencyChatPageState extends State<AgencyChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Stream<QuerySnapshot<Map<String, dynamic>>> get _messagesStream =>
      FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(widget.chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .set({
          'participants': [widget.userId, widget.agencyId],
        }, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .add({
          'text': text,
          'isLocation': false,
          'timestamp': FieldValue.serverTimestamp(),
          'senderId': widget.agencyId,
          'senderType': 'agency',
        });
    _messageController.clear();
    _focusNode.requestFocus();
  }

  Future<void> _deleteAllMessagesForAgency() async {
    final messages = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(widget.chatRoomId)
        .collection('messages')
        .get();
    for (final doc in messages.docs) {
      await doc.reference.update({'deletedForAgency': true});
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All messages deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.chat_bubble_outline, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                ': ${widget.userName}',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.teal,
        elevation: 2,
       
       
        actions: [
          
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            tooltip: 'Delete All Messages',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete All Messages'),
                  content: const Text(
                    'Are you sure you want to delete all messages in this chat? This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _deleteAllMessagesForAgency();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE0F7FA), Color(0xFFFFFFFF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Filter out messages deleted for agency
                  final docs = snapshot.data!.docs
                      .where((doc) => doc.data()['deletedForAgency'] != true)
                      .toList();
                  return ListView.separated(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: docs.length,
                    separatorBuilder:
                        (context, idx) => const SizedBox(height: 2),
                    itemBuilder: (context, idx) {
                      final msg = docs[idx].data();
                      final isMe = msg['senderId'] == widget.agencyId;
                      final timestamp =
                          msg['timestamp'] != null
                              ? (msg['timestamp'] as Timestamp).toDate()
                              : null;

                      return FutureBuilder<
                        DocumentSnapshot<Map<String, dynamic>>
                      >(
                        future:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(msg['senderId'])
                                .get(),
                        builder: (context, userSnapshot) {
                          String userName = 'User';
                          String? profileImageUrl;

                          if (userSnapshot.hasData &&
                              userSnapshot.data!.exists) {
                            final userData = userSnapshot.data!.data();
                            userName = userData?['name'] ?? 'User';
                            profileImageUrl = userData?['profileImageUrl'];
                          }

                          return Align(
                            alignment:
                                isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment:
                                  isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (!isMe)
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            profileImageUrl != null
                                                ? NetworkImage(profileImageUrl)
                                                : null,
                                        child:
                                            profileImageUrl == null
                                                ? const Icon(
                                                  Icons.person,
                                                  size: 18,
                                                )
                                                : null,
                                      ),
                                    if (!isMe) const SizedBox(width: 6),
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isMe) const SizedBox(width: 6),
                                    if (isMe)
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            profileImageUrl != null
                                                ? NetworkImage(profileImageUrl)
                                                : null,
                                        child:
                                            profileImageUrl == null
                                                ? const Icon(
                                                  Icons.person,
                                                  size: 18,
                                                )
                                                : null,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 12,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe ? Colors.teal[100] : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft:
                                          isMe
                                              ? const Radius.circular(18)
                                              : const Radius.circular(4),
                                      bottomRight:
                                          isMe
                                              ? const Radius.circular(4)
                                              : const Radius.circular(18),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    msg['text'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (timestamp != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 18,
                                      right: 18,
                                      bottom: 2,
                                    ),
                                    child: Text(
                                      DateFormat('hh:mm a').format(timestamp),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Location button removed
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(context).requestFocus(_focusNode);
                        },
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[600]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 10,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.teal,
                      shape: const CircleBorder(),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _sendMessage,
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.send,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
       );
  }
}