// ignore_for_file: dead_code

import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

String getChatRoomId(String userId, String agencyId) {
  // Ensures the same ID is generated regardless of order
  return userId.compareTo(agencyId) < 0
      ? '${userId}_$agencyId'
      : '${agencyId}_$userId';
}

class ChatPage extends StatefulWidget {
  final String busName;
  final String agencyId;
  final bool isOnline;

  const ChatPage({
    super.key,
    required this.busName,
    required this.agencyId,
    this.isOnline = true,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  late String _chatRoomId;
  late String _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser!.uid;
    _chatRoomId = getChatRoomId(_userId, widget.agencyId);
  }

  Future<void> _sendMessage({String? text}) async {
    if (text != null && text.trim().isNotEmpty) {
      // Ensure chat room exists with participants
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(_chatRoomId)
          .set({
            'participants': [_userId, widget.agencyId],
          }, SetOptions(merge: true));

      final messageData = {
        'text': text,
        'isLocation': false,
        'timestamp': FieldValue.serverTimestamp(),
        'senderId': _userId,
        'senderType': 'user',
      };
      await FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(_chatRoomId)
          .collection('messages')
          .add(messageData);
      _messageController.clear();
    }
  }

  // Add this function to mark all messages as deleted for the user
  Future<void> _deleteAllMessagesForUser() async {
    final messages = await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(_chatRoomId)
        .collection('messages')
        .get();
    for (final doc in messages.docs) {
      await doc.reference.update({'deletedForUser': true});
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All messages deleted.')),
      );
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> get _messagesStream =>
      FirebaseFirestore.instance
          .collection('chatRooms')
          .doc(_chatRoomId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isOnline ? Colors.green : Colors.red;
    final statusText = widget.isOnline ? '' : '';

    final myBubbleColor = const Color(0xFFDCF8C6); // WhatsApp-like green
    final otherBubbleColor = Colors.white;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.teal,
        title: Row(
          children: [
            CircleAvatar(backgroundColor: statusColor, radius: 5),
            const SizedBox(width: 8),
            Text(
              widget.busName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
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
                await _deleteAllMessagesForUser();
              }
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFE5DDD5), // WhatsApp chat background
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _messagesStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // Filter out messages deleted for user
                  final docs = snapshot.data!.docs
                      .where((doc) => doc.data()['deletedForUser'] != true)
                      .toList();
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: docs.length,
                    itemBuilder: (context, idx) {
                      final msg = docs[idx].data();
                      final isMe = msg['senderId'] == _userId;

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: (!isMe ? otherBubbleColor : myBubbleColor),
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
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  msg['text'],
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                  ),
                                  softWrap: true,
                                  overflow: TextOverflow.visible,
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
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          FocusScope.of(
                            context,
                          ).requestFocus(_messageFocusNode);
                        },
                        child: TextField(
                          controller: _messageController,
                          focusNode: _messageFocusNode,
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.teal,
                        size: 28,
                      ),
                      onPressed:
                          () => _sendMessage(text: _messageController.text),
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