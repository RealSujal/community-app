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

// Create a post
router.post('/create', authMiddleware, upload.array('media', 5), (req, res) => {
    const userId = req.user.userId;
    const content = req.body?.content || '';

    console.log('Create post request received:');
    console.log('- User ID:', userId);
    console.log('- Content:', content);
    console.log('- Files:', req.files ? req.files.length : 'none');

    if (!content && (!req.files || req.files.length === 0))
        return res.status(400).json({ message: 'Content or media is required' });

    const getCommunity = `SELECT community_id FROM community_user WHERE user_id = ?`;
    db.query(getCommunity, [userId], (err, results) => {
        if (err || results.length === 0) {
            console.error('Community query error:', err);
            console.log('Community results:', results);
            return res.status(400).json({ message: 'User not part of any community' });
        }

        const communityId = results[0].community_id;
        const mediaUrls = req.files.map(file => `/uploads/posts/${file.filename}`);
        const mediaUrlsJson = JSON.stringify(mediaUrls);

        const insertPost = `
            INSERT INTO posts (community_id, user_id, content, media_url)
            VALUES (?, ?, ?, ?)
        `;

        db.query(insertPost, [communityId, userId, content, mediaUrlsJson], (err2) => {
            if (err2) {
                console.error('Post creation error:', err2);
                return res.status(500).json({ message: 'Post creation failed', error: err2 });
            }

            console.log('Post created successfully');
            res.status(201).json({ message: 'Post created' });
        });
    });
});

// Get all posts for the user's community
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

// Add a comment to a post
router.post('/:postId/comment', authMiddleware, (req, res) => {
    const postId = req.params.postId;
    const userId = req.user.userId;
    const { comment, parent_id } = req.body;

    if (!comment || comment.trim() === '')
        return res.status(400).json({ message: 'Comment is required' });

    // Insert the comment
    const sql = `INSERT INTO comments (post_id, user_id, comment, parent_id) VALUES (?, ?, ?, ?)`;
    db.query(sql, [postId, userId, comment, parent_id || null], (err, result) => {
        if (err) {
            console.error("DB error:", err);
            return res.status(500).json({ message: 'Failed to add comment' });
        }

        // Get the inserted comment with user details
        const getCommentSql = `
            SELECT 
                c.id AS comment_id,
                c.comment,
                c.created_at,
                c.user_id,
                c.parent_id,
                u.name AS user_name,
                u.email AS user_email,
                u.profile_picture,
                0 AS like_count,
                0 AS is_liked
            FROM comments c
            JOIN users u ON c.user_id = u.id
            WHERE c.id = ?
        `;

        db.query(getCommentSql, [result.insertId], (err2, commentResult) => {
            if (err2) {
                console.error("Error fetching new comment:", err2);
                return res.status(500).json({ message: 'Comment added but failed to fetch details' });
            }

            res.status(201).json({
                message: 'Comment added successfully',
                comment: commentResult[0]
            });
        });

        // Send notifications (existing code)
        const getPostOwnerSql = `SELECT user_id FROM posts WHERE id = ?`;
        db.query(getPostOwnerSql, [postId], (err, result) => {
            if (!err && result.length > 0) {
                const postOwnerId = result[0].user_id;
                if (postOwnerId !== userId) {
                    const { createNotification } = require('./notificationRoutes');
                    createNotification(
                        postOwnerId,
                        '💬 New comment on your post',
                        'Someone commented on your post. Check it out!'
                    );
                }
            }
        });

        if (parent_id) {
            const getParentOwnerSql = `SELECT user_id FROM comments WHERE id = ?`;
            db.query(getParentOwnerSql, [parent_id], (err, result) => {
                if (!err && result.length > 0) {
                    const parentOwnerId = result[0].user_id;
                    if (parentOwnerId !== userId) {
                        const { createNotification } = require('./notificationRoutes');
                        createNotification(
                            parentOwnerId,
                            '💬 New reply on your comment',
                            'Someone replied to your comment. Check it out!'
                        );
                    }
                }
            });
        }
    });
});

// Toggle like/unlike for posts
router.post('/:postId/like', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const postId = req.params.postId;

    const checkSql = `SELECT * FROM likes WHERE post_id = ? AND user_id = ?`;
    db.query(checkSql, [postId, userId], (err, results) => {
        if (err) return res.status(500).json({ message: 'DB error', error: err });

        if (results.length > 0) {
            const deleteSql = `DELETE FROM likes WHERE post_id = ? AND user_id = ?`;
            db.query(deleteSql, [postId, userId], (err2) => {
                if (err2) return res.status(500).json({ message: 'Failed to unlike', error: err2 });
                return res.status(200).json({ message: 'Post unliked' });
            });
        } else {
            const insertSql = `INSERT INTO likes (post_id, user_id) VALUES (?, ?)`;
            db.query(insertSql, [postId, userId], (err3) => {
                if (err3) return res.status(500).json({ message: 'Failed to like', error: err3 });
                return res.status(201).json({ message: 'Post liked' });
            });
        }
    });
});

// Toggle like/unlike for comments
router.post('/comments/:commentId/like', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const commentId = req.params.commentId;

    // Ensure comment_likes table exists
    db.query("SHOW TABLES LIKE 'comment_likes'", (tableErr, tableResult) => {
        if (!tableResult || tableResult.length === 0) {
            const createTableSql = `
                CREATE TABLE IF NOT EXISTS comment_likes (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    comment_id INT NOT NULL,
                    user_id INT NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE KEY unique_comment_like (comment_id, user_id),
                    FOREIGN KEY (comment_id) REFERENCES comments(id) ON DELETE CASCADE,
                    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
                )
            `;

            db.query(createTableSql, (createErr) => {
                if (createErr) {
                    console.error('Error creating comment_likes table:', createErr);
                    return res.status(500).json({ message: 'Failed to setup comment likes feature', error: createErr });
                }
                handleCommentLike();
            });
        } else {
            handleCommentLike();
        }
    });

    function handleCommentLike() {
        const checkSql = `SELECT * FROM comment_likes WHERE comment_id = ? AND user_id = ?`;
        db.query(checkSql, [commentId, userId], (err, results) => {
            if (err) return res.status(500).json({ message: 'DB error', error: err });

            if (results.length > 0) {
                const deleteSql = `DELETE FROM comment_likes WHERE comment_id = ? AND user_id = ?`;
                db.query(deleteSql, [commentId, userId], (err2) => {
                    if (err2) return res.status(500).json({ message: 'Failed to unlike comment', error: err2 });
                    return res.status(200).json({ message: 'Comment unliked' });
                });
            } else {
                const insertSql = `INSERT INTO comment_likes (comment_id, user_id) VALUES (?, ?)`;
                db.query(insertSql, [commentId, userId], (err3) => {
                    if (err3) return res.status(500).json({ message: 'Failed to like comment', error: err3 });

                    // Notify comment owner
                    const getCommentOwnerSql = `SELECT user_id FROM comments WHERE id = ?`;
                    db.query(getCommentOwnerSql, [commentId], (err4, result) => {
                        if (!err4 && result.length > 0) {
                            const commentOwnerId = result[0].user_id;
                            if (commentOwnerId !== userId) {
                                const { createNotification } = require('./notificationRoutes');
                                createNotification(
                                    commentOwnerId,
                                    '❤️ New like on your comment',
                                    'Someone liked your comment!'
                                );
                            }
                        }
                    });

                    return res.status(201).json({ message: 'Comment liked' });
                });
            }
        });
    }
});

// Get feed with enhanced post data
router.get('/feed', authMiddleware, (req, res) => {
    const userId = req.user.userId;

    const communitySql = `SELECT community_id FROM community_user WHERE user_id = ?`;
    db.query(communitySql, [userId], (err, result) => {
        if (err || result.length === 0) {
            return res.status(400).json({ message: "User not part of any community" });
        }

        const communityId = result[0].community_id;
        const baseUrl = process.env.BASE_URL || process.env.API_URL;

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

        db.query(postsSql, [userId, communityId], (err2, posts) => {
            if (err2) {
                console.error('Feed fetch error:', err2);
                return res.status(500).json({ message: 'Failed to fetch feed', error: err2 });
            }

            const formattedPosts = posts.map(post => ({
                ...post,
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

// Enhanced comments endpoint with better threading and user data
router.get('/:postId/comments', authMiddleware, (req, res) => {
    const { postId } = req.params;
    const userId = req.user.userId;
    const baseUrl = process.env.BASE_URL || process.env.API_URL;

    // Check if comment_likes table exists
    db.query("SHOW TABLES LIKE 'comment_likes'", (tableErr, tableResult) => {
        let sql;

        if (tableResult && tableResult.length > 0) {
            sql = `
                SELECT 
                    c.id AS comment_id,
                    c.comment,
                    c.created_at,
                    c.user_id,
                    c.parent_id,
                    u.name AS user_name,
                    u.email AS user_email,
                    u.profile_picture,
                    COALESCE(cu.role, 'member') AS user_role,
                    post_author.name AS post_author_name,
                    (SELECT COUNT(*) FROM comment_likes cl WHERE cl.comment_id = c.id) AS like_count,
                    EXISTS (SELECT 1 FROM comment_likes cl WHERE cl.comment_id = c.id AND cl.user_id = ?) AS is_liked
                FROM comments c
                JOIN users u ON c.user_id = u.id
                JOIN posts p ON c.post_id = p.id
                JOIN users post_author ON p.user_id = post_author.id
                LEFT JOIN community_user cu ON cu.user_id = u.id AND cu.community_id = p.community_id
                WHERE c.post_id = ?
                ORDER BY c.created_at ASC
            `;
        } else {
            sql = `
                SELECT 
                    c.id AS comment_id,
                    c.comment,
                    c.created_at,
                    c.user_id,
                    c.parent_id,
                    u.name AS user_name,
                    u.email AS user_email,
                    u.profile_picture,
                    COALESCE(cu.role, 'member') AS user_role,
                    post_author.name AS post_author_name,
                    0 AS like_count,
                    0 AS is_liked
                FROM comments c
                JOIN users u ON c.user_id = u.id
                JOIN posts p ON c.post_id = p.id
                JOIN users post_author ON p.user_id = post_author.id
                LEFT JOIN community_user cu ON cu.user_id = u.id AND cu.community_id = p.community_id
                WHERE c.post_id = ?
                ORDER BY c.created_at ASC
            `;
        }

        const queryParams = tableResult && tableResult.length > 0 ? [userId, postId] : [postId];

        db.query(sql, queryParams, (err, comments) => {
            if (err) {
                console.error('Fetch comments error:', err);
                return res.status(500).json({ message: 'Failed to fetch comments' });
            }

            // Format profile pictures and organize into threads
            const formattedComments = comments.map(comment => ({
                ...comment,
                profile_picture: comment.profile_picture
                    ? `${baseUrl}/${comment.profile_picture.replace(/^\/+/, '')}`
                    : null,
                is_liked: comment.is_liked === 1 || comment.is_liked === true
            }));

            // Create thread structure
            const commentMap = {};
            const threads = [];

            // First pass: create map and initialize replies array
            formattedComments.forEach(comment => {
                comment.replies = [];
                commentMap[comment.comment_id] = comment;
            });

            // Second pass: organize into parent-child structure
            formattedComments.forEach(comment => {
                if (comment.parent_id && commentMap[comment.parent_id]) {
                    commentMap[comment.parent_id].replies.push(comment);
                } else if (!comment.parent_id) {
                    threads.push(comment);
                }
            });

            // Sort replies by creation time
            threads.forEach(thread => {
                thread.replies.sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
            });

            return res.status(200).json({
                message: "Comments fetched successfully",
                count: formattedComments.length,
                thread_count: threads.length,
                comments: threads
            });
        });
    });
});

// Get a single post with author info
router.get('/:postId', authMiddleware, (req, res) => {
    const { postId } = req.params;

    const sql = `
        SELECT 
            p.id,
            p.content,
            p.media_url,
            p.created_at,
            u.name AS author_name,
            u.profile_picture AS author_picture
        FROM posts p
        JOIN users u ON p.user_id = u.id
        WHERE p.id = ?
    `;

    db.query(sql, [postId], (err, results) => {
        if (err) {
            console.error('Fetch post error:', err);
            return res.status(500).json({ message: 'Failed to fetch post' });
        }

        if (results.length === 0) {
            return res.status(404).json({ message: 'Post not found' });
        }

        return res.status(200).json({
            message: "Post fetched successfully",
            post: results[0]
        });
    });
});

// Delete post
router.delete('/:postId', authMiddleware, (req, res) => {
    const postId = req.params.postId;
    const userId = req.user.userId;

    const checkSql = `
        SELECT p.user_id, cu.role 
        FROM posts p 
        JOIN community_user cu ON p.community_id = cu.community_id AND cu.user_id = ?
        WHERE p.id = ?
    `;

    db.query(checkSql, [userId, postId], (err, results) => {
        if (err || results.length === 0)
            return res.status(403).json({ message: 'Not authorized' });

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

// Delete comment
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
        if (err || results.length === 0)
            return res.status(403).json({ message: 'Not authorized' });

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

// Get posts by user
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