import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/constants.dart';
import '../widgets/post_card.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/api/posts/feed'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        setState(() {
          posts = json['posts'];
          isLoading = false;
        });
      } else {
        debugPrint('Failed to load posts: ${response.body}');
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching posts: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> toggleLike(int postId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      await http.post(
        Uri.parse('$baseUrl/api/posts/$postId/like'),
        headers: {'Authorization': 'Bearer $token'},
      );

      await fetchPosts(); // Refresh UI
    } catch (e) {
      debugPrint('Like failed: $e');
    }
  }

  String _formatTime(String rawDate) {
    try {
      final dateTime = DateTime.parse(rawDate).toLocal();
      final diff = DateTime.now().difference(dateTime);

      if (diff.inSeconds < 60) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours} hr ago';
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : posts.isEmpty
              ? const Center(
                  child: Text(
                    "No posts yet!",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchPosts,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 80),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return PostCard(
                        userId: post['user_id'] is int
                            ? post['user_id']
                            : int.tryParse('${post['user_id']}') ?? 0,
                        authorName: post['user_name'] ?? 'Unknown',
                        authorImageUrl: post['profile_picture'],
                        timeAgo: _formatTime(post['created_at']),
                        content: post['content'] ?? '',
                        mediaUrl: post['media_url'],
                        isLiked: (post['is_liked'] ?? 0) == 1,
                        likeCount: post['like_count'] ?? 0,
                        commentCount: post['comment_count'] ?? 0,
                        onLike: () => toggleLike(post['post_id']),
                        onComment: () {
                          // Will be implemented next
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Comment feature coming soon")),
                          );
                        },
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create-post');
        },
        backgroundColor: Colors.deepPurpleAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
