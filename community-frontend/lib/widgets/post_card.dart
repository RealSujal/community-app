import 'package:community_frontend/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class PostCard extends StatelessWidget {
  final int userId;
  final String authorName;
  final String? authorImageUrl;
  final String timeAgo;
  final String content;
  final String? imageUrl;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onComment;

  const PostCard({
    super.key,
    required this.userId,
    required this.authorName,
    this.authorImageUrl,
    required this.timeAgo,
    required this.content,
    this.imageUrl,
    required this.likeCount,
    required this.commentCount,
    required this.isLiked,
    required this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.grey[900],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildContent(),
            if (imageUrl != null && imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPostImage(),
            ],
            const SizedBox(height: 12),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, '/user-profile', arguments: {
              'userId': userId,
              'userName': authorName,
              'avatarUrl': authorImageUrl,
            });
          },
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.white,
            backgroundImage:
                (authorImageUrl != null && authorImageUrl!.isNotEmpty)
                    ? NetworkImage(authorImageUrl!)
                    : null,
            child: (authorImageUrl == null || authorImageUrl!.isEmpty)
                ? Text(
                    authorName.isNotEmpty ? authorName[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.black),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/user-profile', arguments: {
                'userId': userId,
                'userName': authorName,
                'avatarUrl': authorImageUrl,
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  timeAgo,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Text(
      content,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
    );
  }

  Widget _buildPostImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox(
          height: 150,
          child: Center(
            child: Text("Image failed to load",
                style: TextStyle(color: Colors.grey)),
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _actionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          label: likeCount.toString(),
          onTap: onLike,
        ),
        _actionButton(
          icon: Icons.comment_outlined,
          label: commentCount.toString(),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Comment feature coming soon')),
            );
            onComment();
          },
        ),
        _actionButton(
          icon: Icons.share_outlined,
          label: 'Share',
          onTap: () {
            final text = content;
            if (imageUrl != null && imageUrl!.isNotEmpty) {
              Share.share('$text\n\nCheck this out: $baseUrl$imageUrl');
            } else {
              Share.share(text);
            }
          },
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
