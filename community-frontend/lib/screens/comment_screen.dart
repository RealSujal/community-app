import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';

class CommentScreen extends StatefulWidget {
  final int? postId;
  final int? currentUserId;
  final String? currentUserRole;
  const CommentScreen({
    Key? key,
    required this.postId,
    this.currentUserId,
    this.currentUserRole,
  }) : super(key: key);

  @override
  State<CommentScreen> createState() => _CommentScreenState();
}

class _CommentScreenState extends State<CommentScreen> {
  List comments = [];
  bool isLoading = true;
  String newComment = '';
  TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchComments();
  }

  Future<void> fetchComments() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/posts/${widget.postId}/comments'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          comments = data['comments'];
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> addComment() async {
    if (newComment.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/${widget.postId}/comment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'comment': newComment,
        }),
      );
      if (response.statusCode == 201) {
        commentController.clear();
        newComment = '';
        fetchComments(); // Refresh comments
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to post comment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteComment(int commentId, String userName) async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Delete Comment', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: Colors.grey[300]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.delete(
        Uri.parse('$baseUrl/api/posts/comments/$commentId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        fetchComments(); // Refresh comments
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete comment'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildComment(Map comment) {
    // Check if current user can delete this comment
    final canDelete = widget.currentUserId == comment['user_id'] ||
        ['admin', 'head'].contains(widget.currentUserRole);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.1),
            width: 0.5,
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.grey[700],
            child: Text(
              (comment['user_name'] ?? '?')[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Comment Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User info row
                Row(
                  children: [
                    Text(
                      comment['user_name'] ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment['created_at']),
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),

                    // Delete button (if user can delete)
                    if (canDelete)
                      GestureDetector(
                        onTap: () => deleteComment(
                            comment['comment_id'], comment['user_name']),
                        child: Icon(
                          Icons.more_horiz,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Comment text
                Text(
                  comment['comment'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),

                // Action buttons (simplified for now)
                Row(
                  children: [
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      onTap: () {
                        // For now, just focus the comment input
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      icon: Icons.favorite_outline,
                      onTap: () {
                        // TODO: Implement comment liking if needed
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      icon: Icons.share_outlined,
                      onTap: () {
                        // TODO: Implement sharing if needed
                      },
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

  Widget _buildActionButton({
    required IconData icon,
    int count = 0,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: color ?? Colors.grey[500],
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  color: color ?? Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(String? rawDate) {
    if (rawDate == null) return '';
    try {
      final dateTime = DateTime.parse(rawDate).toLocal();
      final diff = DateTime.now().difference(dateTime);
      if (diff.inSeconds < 60) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';
      return '${dateTime.day}/${dateTime.month}/${dateTime.year.toString().substring(2)}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Comments', style: TextStyle(color: Colors.white)),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Comments list
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 64,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (_, index) =>
                            _buildComment(comments[index]),
                      ),
          ),

          // Comment input
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border(
                top: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // User Avatar
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),

                // Input field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 100),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[700]!),
                    ),
                    child: TextField(
                      controller: commentController,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 16,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => setState(() => newComment = val),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Post button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: TextButton(
                    onPressed: newComment.trim().isEmpty ? null : addComment,
                    style: TextButton.styleFrom(
                      backgroundColor: newComment.trim().isEmpty
                          ? Colors.blue.withOpacity(0.3)
                          : Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text(
                      'Post',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
