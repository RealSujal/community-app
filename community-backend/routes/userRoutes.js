const express = require('express');
const router = express.Router();
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');
const bcrypt = require('bcrypt');
const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/profile_pictures/');
    },
    filename: (req, file, cb) => {
        const ext = path.extname(file.originalname);
        cb(null, `user_${req.user.userId}${ext}`);
    }
});
const upload = multer({ storage });

// PATCH /api/users/edit-profile
router.patch('/edit-profile', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const { name, phone, email, gender, dob, location, socialLinks } = req.body;

    const fields = [];
    const values = [];

    if (name) { fields.push('name = ?'); values.push(name); }
    if (phone) { fields.push('phone = ?'); values.push(phone); }
    if (email) { fields.push('email = ?'); values.push(email); }
    if (gender) { fields.push('gender = ?'); values.push(gender); }
    if (dob) { fields.push('dob = ?'); values.push(dob); }
    if (location) { fields.push('location = ?'); values.push(location); }
    if (socialLinks) {
        fields.push('social_links = ?');
        values.push(JSON.stringify(socialLinks));
    }

    if (fields.length === 0) {
        return res.status(400).json({ message: 'No valid fields to update' });
    }

    const sql = `UPDATE users SET ${fields.join(', ')} WHERE id = ?`;
    values.push(userId);

    db.query(sql, values, (err) => {
        if (err) {
            console.error('Edit profile error:', err);
            return res.status(500).json({ message: 'Profile update failed' });
        }
        res.status(200).json({ message: 'Profile updated successfully' });
    });
});

// PATCH /api/users/change-password
router.patch('/change-password', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const { currentPassword, newPassword, confirmPassword } = req.body;

    if (!currentPassword || !newPassword || !confirmPassword) {
        return res.status(400).json({ message: 'All fields are required' });
    }

    if (newPassword !== confirmPassword) {
        return res.status(400).json({ message: 'New passwords do not match' });
    }

    const findUserSql = `SELECT password_hash FROM users WHERE id = ?`;

    db.query(findUserSql, [userId], async (err, results) => {
        if (err || results.length === 0) {
            return res.status(400).json({ message: 'User not found' });
        }

        const hashedPassword = results[0].password_hash;
        const match = await bcrypt.compare(currentPassword, hashedPassword);

        if (!match) {
            return res.status(401).json({ message: 'Current password is incorrect' });
        }

        const newHashedPassword = await bcrypt.hash(newPassword, 10);
        const updateSql = `UPDATE users SET password_hash = ? WHERE id = ?`;

        db.query(updateSql, [newHashedPassword, userId], (err2) => {
            if (err2) {
                return res.status(500).json({ message: 'Failed to update password' });
            }
            res.status(200).json({ message: 'Password changed successfully' });
        });
    });
});

// POST /api/users/upload-profile-picture
router.post('/upload-profile-picture', authMiddleware, upload.single('profile'), (req, res) => {
    const userId = req.user.userId;
    const filePath = req.file.path.replace(/\\/g, '/');
    const relativePath = filePath.split('uploads')[1];
    const finalPath = `uploads${relativePath}`;

    const sql = `UPDATE users SET profile_picture = ? WHERE id = ?`;
    db.query(sql, [finalPath, userId], (err) => {
        if (err) return res.status(500).json({ message: 'Upload failed' });
        res.status(200).json({ message: 'Profile picture uploaded', profile_picture: finalPath });
    });
});

// GET /api/users/me
router.get('/me', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const sql = `
    SELECT u.id, u.name, u.email, u.phone, u.gender, u.dob, u.location,
           u.profile_picture, u.social_links, cu.role
    FROM users u
    LEFT JOIN community_user cu ON u.id = cu.user_id
    WHERE u.id = ?`;

    db.query(sql, [userId], (err, results) => {
        if (err || results.length === 0) {
            return res.status(500).json({ message: 'Error fetching user info' });
        }

        const user = results[0];
        const baseUrl = process.env.API_URL || 'http://192.168.1.7:3000';
        const profilePictureUrl = user.profile_picture
            ? `${baseUrl}/${user.profile_picture.replace(/\\/g, '/')}`
            : null;

        let socialLinks = {};
        try { if (user.social_links) socialLinks = JSON.parse(user.social_links); } catch (e) { }

        res.status(200).json({
            message: 'User info fetched',
            user: { ...user, profile_picture: profilePictureUrl, socialLinks }
        });
    });
});

// GET /api/users/user/:userId
router.get('/user/:userId', authMiddleware, (req, res) => {
    const currentUser = req.user.userId;
    const targetUser = req.params.userId;

    const sql = `
    SELECT cu.role, u.id, u.name, u.email, u.phone, u.profile_picture
    FROM community_user cu
    JOIN users u ON cu.user_id = u.id
    WHERE cu.community_id = (SELECT community_id FROM community_user WHERE user_id = ?)
      AND u.id = ?`;

    db.query(sql, [currentUser, targetUser], (err, results) => {
        if (err || results.length === 0) {
            return res.status(404).json({ message: 'User not found in your community' });
        }

        const user = results[0];
        const baseUrl = process.env.BASE_URL || 'http://localhost:3000';

        res.status(200).json({
            message: 'User fetched successfully',
            user: {
                ...user,
                profile_picture: user.profile_picture
                    ? `${baseUrl}/${user.profile_picture.replace(/^\/+/g, '')}`
                    : null
            }
        });
    });
});

// PUT /api/users/promote/:userId
router.put('/promote/:userId', authMiddleware, (req, res) => {
    const actor = req.user.userId;
    const target = req.params.userId;

    if (actor == target) {
        return res.status(400).json({ message: "You cannot promote yourself" });
    }

    const sql = `SELECT community_id, role FROM community_user WHERE user_id = ?`;

    db.query(sql, [actor], (err, results) => {
        if (err || results.length === 0 || !['admin', 'head'].includes(results[0].role)) {
            return res.status(403).json({ message: 'Unauthorized' });
        }

        const communityId = results[0].community_id;
        const actorRole = results[0].role;

        const promoteSql = `UPDATE community_user SET role = 'admin' WHERE user_id = ? AND community_id = ?`;

        db.query(promoteSql, [target, communityId], (err2) => {
            if (err2) return res.status(500).json({ message: 'Promotion failed' });

            const { createNotification } = require('./notificationRoutes');
            createNotification(
                target,
                'Promoted to Admin',
                `You have been promoted to Admin by a community ${actorRole}.`,
            )

            res.status(200).json({ message: 'User promoted to admin' });
        });
    });
});

// PUT /api/users/demote/:userId
router.put('/demote/:userId', authMiddleware, (req, res) => {
    const actor = req.user.userId;
    const target = req.params.userId;

    if (actor == target) {
        return res.status(400).json({ message: "You cannot demote yourself" });
    }

    const sql = `SELECT community_id, role FROM community_user WHERE user_id = ?`;

    db.query(sql, [actor], (err, results) => {
        if (err || results.length === 0 || !['admin', 'head'].includes(results[0].role)) {
            return res.status(403).json({ message: 'Unauthorized' });
        }

        const communityId = results[0].community_id;
        const actorRole = results[0].role;

        const demoteSql = `UPDATE community_user SET role = 'member' WHERE user_id = ? AND community_id = ?`;

        db.query(demoteSql, [target, communityId], (err2) => {
            if (err2) return res.status(500).json({ message: 'Demotion failed' });

            const { createNotification } = require('./notificationRoutes');
            createNotification(
                target,
                'Demoted to Member',
                `You have been demoted to Member by a community ${actorRole}.`,
            )
            res.status(200).json({ message: 'User demoted to member' });
        });
    });
});

// GET /api/users/:userId — Public profile with privacy & family
router.get('/:userId', authMiddleware, (req, res) => {
    const { userId } = req.params;
    if (!userId || isNaN(userId) || userId == 0) {
        return res.status(400).json({ message: 'Invalid user ID' });
    }

    const sql = `
    SELECT id, name, email, phone, dob, gender, location, profile_picture, social_links,
           (SELECT role FROM community_user WHERE user_id = ? LIMIT 1) AS role
    FROM users
    WHERE id = ?`;

    db.query(sql, [userId, userId], (err, results) => {
        if (err || results.length === 0) {
            return res.status(404).json({ message: 'User not found' });
        }

        const user = results[0];
        if (user.profile_picture) {
            const baseUrl = process.env.API_URL;
            user.profile_picture = `${baseUrl}/${user.profile_picture.replace(/^\/+/g, '')}`;
        }

        const privacyQuery = 'SELECT * FROM privacy_settings WHERE user_id = ?';
        const familySql = 'SELECT name, relation FROM person WHERE user_id = ?';

        db.query(privacyQuery, [userId], (err2, privacyResults) => {
            if (err2) return res.status(500).json({ message: 'Privacy fetch failed' });

            const row = privacyResults[0] || {};
            const privacy = {
                phone: !!row.show_phone,
                email: !!row.show_email,
                dob: !!row.show_dob,
                gender: !!row.show_gender,
                location: !!row.show_address,
                social_links: !!row.show_social_links
            };

            db.query(familySql, [userId], (err3, familyRes) => {
                if (err3) return res.status(500).json({ message: 'Family fetch failed' });

                res.status(200).json({ user, privacy, family: familyRes || [] });
            });
        });
    });
});

module.exports = router;
