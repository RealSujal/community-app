// routes/notificationRoutes.js
const express = require('express');
const router = express.Router();
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');

// ➕ Create notification
const createNotification = (userId, title, message, type = 'info') => {
    const sql = `INSERT INTO notifications (user_id, title, message, type) VALUES (?, ?, ?, ?)`;
    db.query(sql, [userId, title, message, type], (err) => {
        if (err) console.error("Notification error:", err);
    });
};

// 📥 Get all notifications for user
router.get('/', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const sql = `SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC`;
    db.query(sql, [userId], (err, results) => {
        if (err) return res.status(500).json({ message: 'Error fetching notifications' });
        res.status(200).json({ message: 'Notifications fetched', notifications: results });
    });
});

// Mark a notification as seen
router.patch('/:id/seen', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const notificationId = req.params.id;

    const sql = `UPDATE notifications SET seen = 1 WHERE id = ? AND user_id = ?`;

    db.query(sql, [notificationId, userId], (err, result) => {
        if (err) {
            console.error('Mark as seen error:', err);
            return res.status(500).json({ message: 'Failed to mark notification as seen' });
        }

        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Notification not found or unauthorized' });
        }

        return res.status(200).json({ message: 'Notification marked as seen' });
    });
});


// Mark all notifications as seen
router.patch('/mark-all-seen', authMiddleware, (req, res) => {
    const userId = req.user.userId;

    const sql = `UPDATE notifications SET seen = 1 WHERE user_id = ?`;

    db.query(sql, [userId], (err, result) => {
        if (err) {
            console.error('Mark all as seen error:', err);
            return res.status(500).json({ message: 'Failed to mark notifications' });
        }

        return res.status(200).json({ message: `${result.affectedRows} notifications marked as seen` });
    });
});


module.exports = { router, createNotification };
