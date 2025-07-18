const express = require('express');
const router = express.Router();
const db = require('../models/db');
const multer = require('multer');
const path = require('path');
const authMiddleware = require('../middleware/authMiddleware');


const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, 'uploads/posts/'),
    filename: (req, file, cb) => {
        const ext = path.extname(file.originalname);
        cb(null, `${Date.now()}-${Math.random().toString(36).substring(2)}${ext}`);
    },
});

const allowedTypes = ['.jpeg', '.jpg', '.png', '.gif', '.mp4', '.webm'];

const fileFilter = (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
        cb(null, true);
    } else {
        cb(new Error('Invalid file type'));
    }
};

const upload = multer({ storage, fileFilter });


//  Create a post
router.post('/create', authMiddleware, upload.single('media'), (req, res) => {
    const userId = req.user.userId;
    const content = req.body?.content || null;

    if (!content && !req.file)
        return res.status(400).json({ message: 'Content or media is required' });

    const getCommunity = `SELECT community_id FROM community_user WHERE user_id = ?`;
    db.query(getCommunity, [userId], (err, results) => {
        if (err || results.length === 0)
            return res.status(400).json({ message: 'User not part of any community' });

        const communityId = results[0].community_id;
        const mediaUrl = req.file ? `/uploads/posts/${req.file.filename}` : null;

        const insertPost = `
        INSERT INTO posts (community_id, user_id, content, media_url)
        VALUES (?, ?, ?, ?)
      `;
        db.query(insertPost, [communityId, userId, content, mediaUrl], (err2) => {
            if (err2)
                return res.status(500).json({ message: 'Post creation failed', error: err2 });

            res.status(201).json({ message: 'Post created' });
        });
    });
});


//  Get all posts for the user's community
router.get('/community-posts', authMiddleware, (req, res) => {
    const userId = req.user.userId;

    const sql = `
        SELECT p.id, p.content, p.media_url, p.media_type, p.created_at, u.name AS author
        FROM posts p
        JOIN community_user cu ON cu.community_id = p.community_id
        JOIN users u ON u.id = p.user_id
        WHERE cu.user_id = ?
        ORDER BY p.created_at DESC
    `;

    db.query(sql, [userId], (err, results) => {
        if (err) return res.status(500).json({ message: 'DB error', error: err });

        res.status(200).json({
            message: "Posts fetched",
            posts: results
        });
    });
});

//  Add a comment to a post
router.post('/:postId/comment', authMiddleware, (req, res) => {
    const postId = req.params.postId;
    const userId = req.user.userId;
    const { comment } = req.body;

    if (!comment || content.trim() === '') return res.status(400).json({ message: 'Comment is required' });

    const sql = `INSERT INTO comments (post_id, user_id, comment) VALUES (?, ?, ?)`;
    db.query(sql, [postId, userId, comment], (err, result) => {
        if (err) {
            console.error("DB error:", err);
            return res.status(500).json({ message: 'Failed to add comment' });
        }

        res.status(201).json({ message: 'Comment added successfully' });
    });

    // After inserting comment successfully...
    const getPostOwnerSql = `SELECT user_id FROM posts WHERE id = ?`;
    db.query(getPostOwnerSql, [post_id], (err, result) => {
        if (!err && result.length > 0) {
            const postOwnerId = result[0].user_id;

            const { createNotification } = require('./notificationRoutes');
            createNotification(
                postOwnerId,
                '💬 New comment on your post',
                'Someone commented on your post. Check it out!'
            );
        }
    });

});

//  Toggle like/unlike
router.post('/:postId/like', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const postId = req.params.postId;

    // Check if already liked
    const checkSql = `SELECT * FROM likes WHERE post_id = ? AND user_id = ?`;
    db.query(checkSql, [postId, userId], (err, results) => {
        if (err) return res.status(500).json({ message: 'DB error', error: err });

        if (results.length > 0) {
            // Already liked → remove it (unlike)
            const deleteSql = `DELETE FROM likes WHERE post_id = ? AND user_id = ?`;
            db.query(deleteSql, [postId, userId], (err2) => {
                if (err2) return res.status(500).json({ message: 'Failed to unlike', error: err2 });

                return res.status(200).json({ message: 'Post unliked' });
            });
        } else {
            // Not liked yet → add like
            const insertSql = `INSERT INTO likes (post_id, user_id) VALUES (?, ?)`;
            db.query(insertSql, [postId, userId], (err3) => {
                if (err3) return res.status(500).json({ message: 'Failed to like', error: err3 });

                return res.status(201).json({ message: 'Post liked' });
            });
        }
    });
});

//  Get all posts from user's community (with like & comment count)
router.get('/feed', authMiddleware, (req, res) => {
    const userId = req.user.userId;

    // Step 1: Get user's community
    const communitySql = `SELECT community_id FROM community_user WHERE user_id = ?`;
    db.query(communitySql, [userId], (err, result) => {
        if (err || result.length === 0) {
            return res.status(400).json({ message: "User not part of any community" });
        }

        const communityId = result[0].community_id;

        // Step 2: Fetch posts with extra info
        const postsSql = `
        SELECT 
            p.id AS post_id,
            p.content,
            p.media_url,
            p.media_type,
            p.created_at,
            u.id AS user_id,
            u.name AS user_name,
            u.email AS user_email,
            u.profile_picture,
            (SELECT COUNT(*) FROM likes l WHERE l.post_id = p.id) AS like_count,
            (SELECT COUNT(*) FROM comments c WHERE c.post_id = p.id) AS comment_count,
            EXISTS (SELECT 1 FROM likes l WHERE l.post_id = p.id AND l.user_id = ?) AS is_liked
        FROM posts p
        JOIN users u ON p.user_id = u.id
        WHERE p.community_id = ?
        ORDER BY p.created_at DESC
        `;

        const baseUrl = process.env.API_URL || 'http://192.168.1.12:3000';

        db.query(postsSql, [userId, communityId], (err2, posts) => {
            if (err2) {
                console.error('Feed fetch error:', err2);
                return res.status(500).json({ message: 'Failed to fetch feed', error: err2 });
            }

            const formattedPosts = posts.map(post => ({
                ...post,
                user_id: post.user_id,
                profile_picture: post.profile_picture
                    ? `${baseUrl}/${post.profile_picture.replace(/^\/+/, '')}`
                    : null
            }));

            return res.status(200).json({
                message: "Feed fetched successfully",
                count: formattedPosts.length,
                posts: formattedPosts
            });
        });
    });
});

//  Get all comments on a post
router.get('/:postId/comments', authMiddleware, (req, res) => {
    const { postId } = req.params;

    const sql = `
        SELECT 
            c.id AS comment_id,
            c.comment,
            c.created_at,
            u.name AS user_name,
            u.email AS user_email
        FROM comments c
        JOIN users u ON c.user_id = u.id
        WHERE c.post_id = ?
        ORDER BY c.created_at ASC
    `;

    db.query(sql, [postId], (err, comments) => {
        if (err) {
            console.error('Fetch comments error:', err);
            return res.status(500).json({ message: 'Failed to fetch comments' });
        }

        return res.status(200).json({
            message: "Comments fetched successfully",
            count: comments.length,
            comments
        });
    });
});

router.delete('/posts/:postId', authMiddleware, (req, res) => {
    const postId = req.params.postId;
    const userId = req.user.userId;

    const checkSql = `
        SELECT p.user_id, cu.role 
        FROM posts p 
        JOIN community_user cu ON p.community_id = cu.community_id AND cu.user_id = ?
        WHERE p.id = ?
    `;

    db.query(checkSql, [userId, postId], (err, results) => {
        if (err || results.length === 0) return res.status(403).json({ message: 'Not authorized' });

        const { user_id, role } = results[0];
        if (userId !== user_id && !['admin', 'head'].includes(role)) {
            return res.status(403).json({ message: 'No permission to delete this post' });
        }

        const deleteSql = `DELETE FROM posts WHERE id = ?`;
        db.query(deleteSql, [postId], (err2) => {
            if (err2) return res.status(500).json({ message: 'Delete failed' });
            res.status(200).json({ message: 'Post deleted' });
        });
    });
});


router.delete('/comments/:commentId', authMiddleware, (req, res) => {
    const commentId = req.params.commentId;
    const userId = req.user.userId;

    const checkSql = `
        SELECT c.user_id, cu.role 
        FROM comments c 
        JOIN posts p ON c.post_id = p.id
        JOIN community_user cu ON cu.community_id = p.community_id AND cu.user_id = ?
        WHERE c.id = ?
    `;

    db.query(checkSql, [userId, commentId], (err, results) => {
        if (err || results.length === 0) return res.status(403).json({ message: 'Not authorized' });

        const { user_id, role } = results[0];
        if (userId !== user_id && !['admin', 'head'].includes(role)) {
            return res.status(403).json({ message: 'No permission to delete this comment' });
        }

        const deleteSql = `DELETE FROM comments WHERE id = ?`;
        db.query(deleteSql, [commentId], (err2) => {
            if (err2) return res.status(500).json({ message: 'Delete failed' });
            res.status(200).json({ message: 'Comment deleted' });
        });
    });
});


router.get('/posts/user/:userId', authMiddleware, (req, res) => {
    const userId = req.params.userId;

    const sql = `
        SELECT p.id, p.content, p.created_at, u.name AS author
        FROM posts p
        JOIN users u ON p.user_id = u.id
        WHERE u.id = ?
        ORDER BY p.created_at DESC
    `;

    db.query(sql, [userId], (err, posts) => {
        if (err) return res.status(500).json({ message: 'DB error' });
        res.status(200).json({ message: 'Posts fetched', posts });
    });
});

module.exports = router;
