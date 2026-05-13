import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_theme.dart';
import '../../models/comment_model.dart';
import '../../providers/collaboration_provider.dart';

class CommentsScreen extends StatefulWidget {
  final String noteId;
  final String noteTitle;

  const CommentsScreen({
    super.key,
    required this.noteId,
    required this.noteTitle,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CollaborationProvider>().loadComments(widget.noteId);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() {
    if (_commentController.text.isEmpty) return;

    context.read<CollaborationProvider>().addComment(
      widget.noteId,
      _commentController.text,
    );

    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments - ${widget.noteTitle}'),
        backgroundColor: AppColors.bgDark,
        elevation: 0,
      ),
      backgroundColor: AppColors.bgDark,
      body: Consumer<CollaborationProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Comments list
              Expanded(
                child: provider.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      )
                    : provider.comments.isEmpty
                    ? Center(
                        child: Text(
                          'No comments yet. Start the conversation!',
                          style: TextStyle(color: Colors.grey[400]),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: provider.comments.length,
                        itemBuilder: (context, index) {
                          final comment = provider.comments[index];
                          return _CommentTile(
                            comment: comment,
                            noteId: widget.noteId,
                            onDelete: () => context
                                .read<CollaborationProvider>()
                                .deleteComment(widget.noteId, comment.id),
                            onLike: () => context
                                .read<CollaborationProvider>()
                                .toggleCommentLike(widget.noteId, comment.id),
                          );
                        },
                      ),
              ),

              // Error message
              if (provider.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    provider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // Comment input
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  border: Border(top: BorderSide(color: Colors.grey[700]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[700]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        maxLines: null,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _submitComment,
                      icon: const Icon(Icons.send, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommentModel comment;
  final String noteId;
  final VoidCallback onDelete;
  final VoidCallback onLike;

  const _CommentTile({
    required this.comment,
    required this.noteId,
    required this.onDelete,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == comment.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment.userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                _formatTime(comment.createdAt),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Comment content
          Text(comment.content),
          const SizedBox(height: 8),

          // Actions
          Row(
            children: [
              GestureDetector(
                onTap: onLike,
                child: Row(
                  children: [
                    Icon(
                      comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 16,
                      color: comment.likedBy.contains(FirebaseAuth.instance.currentUser?.uid)
                          ? Colors.red
                          : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${comment.likes}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (isOwner)
                GestureDetector(
                  onTap: onDelete,
                  child: Text(
                    'Delete',
                    style: TextStyle(fontSize: 12, color: Colors.red[400]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
