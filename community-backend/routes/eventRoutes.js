const express = require('express');
const router = express.Router();
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');
const multer = require('multer');
const path = require('path');

// Multer setup for event image uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, 'uploads/events/'),
    filename: (req, file, cb) => {
        const ext = path.extname(file.originalname);
        const filename = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}${ext}`;
        cb(null, filename);
    }
});
const upload = multer({ storage });

//  Check if user is admin or head of their community
function checkAdminOrHead(userId, callback) {
    const sql = `SELECT role FROM community_user WHERE user_id = ?`;
    db.query(sql, [userId], (err, result) => {
        if (err || result.length === 0) return callback(false);
        const role = result[0].role;
        callback(role === 'admin' || role === 'head');
    });
}

//  Create a new event (admin/head only)
router.post('/create', authMiddleware, upload.single('image'), (req, res) => {
    const userId = req.user.userId;
    const { name, description, event_date, event_time, location } = req.body;

    if (!name || !event_date || !event_time) {
        return res.status(400).json({ message: 'Name, date, and time are required' });
    }

    checkAdminOrHead(userId, (isAllowed) => {
        if (!isAllowed) {
            return res.status(403).json({ message: 'Only admins or heads can create events' });
        }

        const getCommunity = `SELECT community_id FROM community_user WHERE user_id = ?`;
        db.query(getCommunity, [userId], (err, results) => {
            if (err || results.length === 0) {
                return res.status(400).json({ message: 'Community not found for user' });
            }

            const communityId = results[0].community_id;
            const imageUrl = req.file ? `/uploads/events/${req.file.filename}` : null;

            const insertSql = `
                INSERT INTO events (community_id, created_by, name, description, event_date, event_time, location, image_url)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            `;
            db.query(insertSql, [communityId, userId, name, description, event_date, event_time, location, imageUrl], (err2) => {
                if (err2) {
                    return res.status(500).json({ message: 'Event creation failed', error: err2 });
                }
                res.status(201).json({ message: 'Event created successfully' });
            });
        });
    });
});

//  Get all events for the current user's community
router.get('/', authMiddleware, (req, res) => {
    const userId = req.user.userId;

    const getCommunity = `SELECT community_id FROM community_user WHERE user_id = ?`;
    db.query(getCommunity, [userId], (err, results) => {
        if (err || results.length === 0) {
            return res.status(400).json({ message: 'User not part of any community' });
        }

        const communityId = results[0].community_id;

        const fetchSql = `
            SELECT 
                e.id, e.name, e.description, e.event_date, e.event_time, e.location,
                e.image_url, e.created_at, u.name AS created_by_name
            FROM events e
            JOIN users u ON e.created_by = u.id
            WHERE e.community_id = ?
            ORDER BY e.event_date, e.event_time
        `;
        db.query(fetchSql, [communityId], (err2, events) => {
            if (err2) {
                return res.status(500).json({ message: 'Failed to fetch events', error: err2 });
            }
            res.status(200).json({ events });
        });
    });
});

//  Delete an event (by creator or admin/head)
router.delete('/:eventId', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const eventId = req.params.eventId;

    const checkSql = `
        SELECT e.created_by, cu.role
        FROM events e
        JOIN community_user cu ON cu.user_id = ? AND cu.community_id = e.community_id
        WHERE e.id = ?
    `;

    db.query(checkSql, [userId, eventId], (err, result) => {
        if (err || result.length === 0) {
            return res.status(403).json({ message: 'Not authorized to delete this event' });
        }

        const { created_by, role } = result[0];
        if (userId !== created_by && !['admin', 'head'].includes(role)) {
            return res.status(403).json({ message: 'You do not have permission to delete this event' });
        }

        const deleteSql = `DELETE FROM events WHERE id = ?`;
        db.query(deleteSql, [eventId], (err2) => {
            if (err2) {
                return res.status(500).json({ message: 'Failed to delete event' });
            }
            res.status(200).json({ message: 'Event deleted successfully' });
        });
    });
});

module.exports = router;
