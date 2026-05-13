// lib/screens/collaboration/comments_view.dart
// Real-time comments view with threading support

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/comment_model.dart';
import '../../providers/collaboration_provider.dart';

class CommentsView extends StatefulWidget {
  final String noteId;
  final String noteTitle;

  const CommentsView({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  State<CommentsView> createState() => _CommentsViewState();
}

class _CommentsViewState extends State<CommentsView> {
  late TextEditingController _commentController;
  String? _replyingToCommentId;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) return;

    try {
      final provider = context.read<CollaborationProvider>();
      final content = _commentController.text;

      if (_replyingToCommentId != null) {
        // Reply to comment
        await provider.addComment(widget.noteId, content);
      } else {
        // Top-level comment
        await provider.addComment(widget.noteId, content);
      }

      _commentController.clear();
      setState(() => _replyingToCommentId = null);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Comment posted')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments • ${widget.noteTitle}'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Comments stream
          Expanded(
            child: StreamBuilder<List<CommentModel>>(
              stream: context.read<CollaborationProvider>().watchComments(
                widget.noteId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No comments yet.\nBe the first to comment!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                final comments = snapshot.data!
                    .where((c) => c.parentCommentId == null) // Top-level only
                    .toList();

                return ListView.builder(
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return CommentTile(
                      comment: comment,
                      noteId: widget.noteId,
                      onReply: () {
                        setState(() => _replyingToCommentId = comment.id);
                        FocusScope.of(context).requestFocus();
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Comment input
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            padding: EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_replyingToCommentId != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.reply, size: 18, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Replying to comment',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                        Spacer(),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _replyingToCommentId = null),
                          child: Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                      ),
                    ),
                    SizedBox(width: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: _submitComment,
                      child: Icon(Icons.send),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String noteId;
  final VoidCallback onReply;

  const CommentTile({
    super.key,
    required this.comment,
    required this.noteId,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : '?',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.userName,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        Text(
                          _formatTime(comment.createdAt),
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(comment.content),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            context.read<CollaborationProvider>().likeComment(
                              noteId,
                              comment.id,
                            );
                          },
                          child: Row(
                            children: [
                              Icon(Icons.favorite_border, size: 16),
                              SizedBox(width: 4),
                              Text(
                                comment.likes.toString(),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),
                        GestureDetector(
                          onTap: onReply,
                          child: Row(
                            children: [
                              Icon(Icons.reply, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Reply',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Replies
          if (comment.replyIds.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 50, top: 8),
              child: Text(
                '+${comment.replyIds.length} replies',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Colors.blue),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }
}
