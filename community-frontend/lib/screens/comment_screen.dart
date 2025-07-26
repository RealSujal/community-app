import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';
import 'package:flutter/services.dart';

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
  Map<int, bool> expandedReplies = {};
  Map<String, dynamic>? replyingTo;
  FocusNode commentFocusNode = FocusNode();
  ScrollController scrollController = ScrollController();
  String? postAuthorName;

  @override
  void initState() {
    super.initState();
    fetchComments();
    fetchPostAuthor();
  }

  @override
  void dispose() {
    commentController.dispose();
    commentFocusNode.dispose();
    scrollController.dispose();
    super.dispose();
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
          comments =
              data['comments'].where((c) => c['parent_id'] == null).toList();
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

      final Map<String, dynamic> payload = {
        'comment': newComment,
      };

      if (replyingTo != null) {
        payload['parent_id'] = replyingTo!['comment_id'];
      }

      final response = await http.post(
        Uri.parse('$baseUrl/api/posts/${widget.postId}/comment'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        commentController.clear();
        setState(() {
          newComment = '';
          replyingTo = null;
        });
        fetchComments();

        // Scroll to bottom to show new comment
        Future.delayed(Duration(milliseconds: 300), () {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error posting comment: $e');
    }
  }

  void startReply(dynamic comment) {
    setState(() {
      replyingTo = comment;
      final username = comment['user_name'];
      commentController.text = '@$username ';
      commentController.selection = TextSelection.fromPosition(
        TextPosition(offset: commentController.text.length),
      );
    });
    commentFocusNode.requestFocus();
  }

  void cancelReply() {
    setState(() {
      replyingTo = null;
      commentController.text = '';
      newComment = '';
    });
  }

  Future<void> fetchPostAuthor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/posts/${widget.postId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          postAuthorName = data['post']['author_name'] ?? 'Unknown';
        });
      }
    } catch (e) {
      debugPrint('Error fetching post author: $e');
      setState(() {
        postAuthorName = 'Unknown';
      });
    }
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

  Widget _buildUserAvatar(dynamic comment, {double radius = 20}) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundImage: comment['profile_picture'] != null
            ? NetworkImage(comment['profile_picture'])
            : null,
        backgroundColor: _getAvatarColor(comment['user_name']),
        child: comment['profile_picture'] == null
            ? Text(
                (comment['user_name'] ?? '?')[0].toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.7,
                  fontWeight: FontWeight.w600,
                ),
              )
            : null,
      ),
    );
  }

  Color _getAvatarColor(String? name) {
    if (name == null || name.isEmpty) return const Color(0xFF4A4A4A);

    final colors = [
      const Color(0xFF6B73FF), // Blue
      const Color(0xFF9B59B6), // Purple
      const Color(0xFFE74C3C), // Red
      const Color(0xFF3498DB), // Light Blue
      const Color(0xFF2ECC71), // Green
      const Color(0xFFF39C12), // Orange
      const Color(0xFF1ABC9C), // Teal
      const Color(0xFFE67E22), // Dark Orange
    ];

    return colors[name.hashCode % colors.length];
  }

  Widget _buildCommentBubble(dynamic comment, {bool isReply = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and time
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                    children: [
                      TextSpan(
                        text: comment['user_name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(
                        text: ' commented on ',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Colors.grey[400],
                        ),
                      ),
                      TextSpan(
                        text: '${postAuthorName ?? 'Unknown'}\'s post',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(comment['created_at']),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Comment text
          Text(
            comment['comment'] ?? '',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentActions(dynamic comment) {
    final commentId = comment['comment_id'];
    final hasReplies =
        comment['replies'] != null && comment['replies'].length > 0;
    final isExpanded = expandedReplies[commentId] ?? false;

    return Padding(
      padding: const EdgeInsets.only(left: 52, top: 8),
      child: Row(
        children: [
          // Reply button
          GestureDetector(
            onTap: () => startReply(comment),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                'Reply',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const Spacer(),
          // Show/Hide replies
          if (hasReplies)
            GestureDetector(
              onTap: () {
                setState(() {
                  expandedReplies[commentId] = !isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isExpanded
                          ? 'Hide replies'
                          : '${comment['replies'].length} ${comment['replies'].length == 1 ? 'reply' : 'replies'}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey[400],
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentThread(dynamic comment) {
    final commentId = comment['comment_id'];
    final hasReplies =
        comment['replies'] != null && comment['replies'].length > 0;
    final isExpanded = expandedReplies[commentId] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main comment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildUserAvatar(comment),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCommentBubble(comment),
              ),
            ],
          ),

          // Actions (like, reply, etc.)
          _buildCommentActions(comment),

          // Replies
          if (hasReplies && isExpanded) ...[
            const SizedBox(height: 16),
            ...List.generate(
              comment['replies'].length,
              (index) => _buildReplyThread(comment['replies'][index]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyThread(dynamic reply) {
    return Container(
      margin: const EdgeInsets.only(left: 52, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildUserAvatar(reply, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCommentBubble(reply, isReply: true),
                // Reply actions
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => startReply(reply),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyingToBar() {
    if (replyingTo == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply,
            size: 16,
            color: Colors.grey[500],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14),
                children: [
                  TextSpan(
                    text: 'Replying to ',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  TextSpan(
                    text: replyingTo!['user_name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: cancelReply,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                color: Colors.grey[500],
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        border: Border(
          top: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: commentController,
                focusNode: commentFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: replyingTo != null
                      ? 'Write a reply...'
                      : 'Write a comment...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) => setState(() => newComment = val),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Send button
          GestureDetector(
            onTap: newComment.trim().isEmpty ? null : addComment,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: newComment.trim().isEmpty
                    ? Colors.grey[800]
                    : const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: Text(
                  'Send',
                  style: TextStyle(
                    color: newComment.trim().isEmpty
                        ? Colors.grey[600]
                        : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        elevation: 0,
        title: const Text(
          'Comments',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.dark,
        ),
      ),
      body: Column(
        children: [
          _buildReplyingToBar(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF007AFF),
                      strokeWidth: 2,
                    ),
                  )
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
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 20),
                        itemCount: comments.length,
                        itemBuilder: (context, index) =>
                            _buildCommentThread(comments[index]),
                      ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }
}
