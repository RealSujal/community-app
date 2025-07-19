// routes/communityRoutes.js
const express = require('express');
const router = express.Router();
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');
const dotenv = require('dotenv');
dotenv.config();

const generateInviteCode = () => Math.random().toString(36).substring(2, 8).toUpperCase();

// Create community
router.post('/create-community', authMiddleware, (req, res) => {
    const { name, location, description } = req.body;
    const created_by = req.user.userId;

    if (!name) return res.status(400).json({ message: 'Community name is required' });

    const invite_code = generateInviteCode();
    const sql = `INSERT INTO communities (name, location, description, invite_code, created_by) VALUES (?, ?, ?, ?, ?)`;

    db.query(sql, [name, location, description, invite_code, created_by], (err, result) => {
        if (err) return res.status(500).json({ message: 'Community creation failed', error: err });

        const communityId = result.insertId;
        const insertHead = `INSERT INTO community_user (user_id, community_id, role) VALUES (?, ?, 'head')`;

        db.query(insertHead, [created_by, communityId], (err2) => {
            if (err2) return res.status(500).json({ message: 'Failed to assign head', error: err2 });

            res.status(201).json({
                message: 'Community created successfully',
                community: { id: communityId, name, location, invite_code }
            });
        });
    });
});

// Join community
router.post('/join-community', authMiddleware, (req, res) => {
    const { invite_code } = req.body;
    const user_id = req.user.userId;

    if (!invite_code) return res.status(400).json({ message: 'Invite code is required' });

    const findCommunity = `SELECT id FROM communities WHERE invite_code = ?`;
    db.query(findCommunity, [invite_code], (err, results) => {
        if (err || results.length === 0) return res.status(404).json({ message: 'Invalid invite code' });

        const community_id = results[0].id;
        const checkMember = `SELECT * FROM community_user WHERE user_id = ? AND community_id = ?`;

        db.query(checkMember, [user_id, community_id], (err2, exists) => {
            if (exists.length > 0) return res.status(400).json({ message: 'Already a member' });

            const insertMember = `INSERT INTO community_user (user_id, community_id, role) VALUES (?, ?, 'member')`;
            db.query(insertMember, [user_id, community_id], (err3) => {
                if (err3) return res.status(500).json({ message: 'Failed to join', error: err3 });
                res.status(201).json({ message: 'Joined community successfully' });
            });
        });
    });
});

// Get members of current user's community
router.get('/members', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const { location, name, role } = req.query;

    const findCommunity = `SELECT community_id FROM community_user WHERE user_id = ?`;

    db.query(findCommunity, [userId], (err, results) => {
        if (err || results.length === 0) {
            return res.status(400).json({ message: 'Not part of a community' });
        }

        const communityId = results[0].community_id;
        let membersSql = `
            SELECT 
                u.id, u.name, u.email, u.phone, u.location, u.profile_picture, cu.role
            FROM users u
            JOIN community_user cu ON u.id = cu.user_id
            WHERE cu.community_id = ?
        `;
        const values = [communityId];

        // Add filters corresponding to query parameters
        if (location && location.trim() !== '') {
            membersSql += ' AND u.location = ?';
            values.push(location.trim());
        }

        if (name && name.trim() !== '') {
            membersSql += ' AND u.name LIKE ?';
            values.push(`%${name.trim()}%`);
        }

        if (role && role.trim() !== '') {
            membersSql += ' AND cu.role = ?';
            values.push(role.trim());
        }

        membersSql += ' ORDER BY FIELD(cu.role, \'head\', \'admin\', \'member\'), u.name';

        db.query(membersSql, values, (err2, members) => {
            if (err2) {
                console.error("Error fetching members:", err2);
                return res.status(500).json({ message: "DB error" });
            }

            console.log("🔍 Raw members from DB:", members);

            // Attach full URL for profile picture
            const baseUrl = process.env.BASE_URL || 'http://192.168.1.7:3000';
            const formattedMembers = members.map(member => ({
                ...member,
                profile_picture: member.profile_picture
                    ? `${baseUrl}/${member.profile_picture.replace(/\\/g, '/')}`
                    : null
            }));

            console.log("📋 Formatted members:", formattedMembers);

            return res.status(200).json({
                message: "Members fetched successfully",
                count: formattedMembers.length,
                members: formattedMembers
            });
        });
    });
});


// Leave community
router.delete('/leave-community', authMiddleware, (req, res) => {
    const userId = req.user.userId;
    const roleSql = `SELECT role, community_id FROM community_user WHERE user_id = ?`;

    db.query(roleSql, [userId], (err, result) => {
        if (err || result.length === 0) return res.status(400).json({ message: 'Not in community' });

        const { role, community_id } = result[0];
        if (role === 'head') return res.status(403).json({ message: 'Head must transfer role first' });

        const deleteSql = `DELETE FROM community_user WHERE user_id = ? AND community_id = ?`;
        db.query(deleteSql, [userId, community_id], (err2) => {
            if (err2) return res.status(500).json({ message: 'Error leaving community' });
            res.status(200).json({ message: 'Left community successfully' });
        });
    });
});

// Transfer head role
router.put('/transfer-head', authMiddleware, (req, res) => {
    const { new_head_user_id } = req.body;
    const currentUserId = req.user.userId;

    const headCheck = `SELECT community_id FROM community_user WHERE user_id = ? AND role = 'head'`;
    db.query(headCheck, [currentUserId], (err, result) => {
        if (err || result.length === 0) return res.status(403).json({ message: 'Only head can transfer role' });

        const community_id = result[0].community_id;
        const updateNew = `UPDATE community_user SET role = 'head' WHERE user_id = ? AND community_id = ?`;
        const updateOld = `UPDATE community_user SET role = 'admin' WHERE user_id = ? AND community_id = ?`;

        db.query(updateNew, [new_head_user_id, community_id], (err2) => {
            if (err2) return res.status(500).json({ message: 'Promote failed', error: err2 });

            const { createNotification } = require('./notificationRoutes');
            createNotification(
                new_head_user_id,
                'You are now the Community head!',
                `Congratulations! You've been promoted to Head of the Community.`
            );
            db.query(updateOld, [currentUserId, community_id], (err3) => {
                if (err3) return res.status(500).json({ message: 'Demote failed', error: err3 });
                res.status(200).json({ message: 'Head role transferred' });
            });
        });
    });
});

// Remove member (only head or admin)
router.delete('/remove-member/:userId', authMiddleware, (req, res) => {
    const actingUser = req.user.userId;
    const targetUser = req.params.userId;

    const roleCheck = `SELECT community_id, role FROM community_user WHERE user_id = ?`;

    db.query(roleCheck, [actingUser], (err, result) => {
        if (err || result.length === 0 || !['admin', 'head'].includes(result[0].role)) {
            return res.status(403).json({ message: 'Unauthorized' });
        }

        const communityId = result[0].community_id;
        const actorRole = result[0].role;
        const deleteSql = `DELETE FROM community_user WHERE user_id = ? AND community_id = ?`;

        db.query(deleteSql, [targetUser, communityId], (err2) => {
            if (err2) return res.status(500).json({ message: 'Failed to remove user', error: err2 });
            res.status(200).json({ message: 'Member removed' });

            const { createNotification } = require('./notificationRoutes');
            createNotification(
                targetUser,
                'Removed from community',
                `You have been removed from the community by ${actorRole}.`
            );

            res.status(200).json({ message: 'Member removed' });
        });
    });
});

// View logged-in user's community info
router.get('/my-community', authMiddleware, (req, res) => {
    const userId = req.user.userId;

    const getCommunitySql = `
        SELECT c.id, c.name, c.description, c.location, c.invite_code, cu.role
        FROM communities c
        JOIN community_user cu ON c.id = cu.community_id
        WHERE cu.user_id = ?
    `;

    db.query(getCommunitySql, [userId], (err, results) => {
        if (err) {
            console.error("Error fetching community:", err);
            return res.status(500).json({ message: "DB error" });
        }

        if (results.length === 0) {
            return res.status(404).json({ message: "User is not part of any community" });
        }

        const community = results[0];

        res.status(200).json({
            message: "Community fetched",
            community: {
                id: community.id,
                name: community.name,
                description: community.description,
                location: community.location,
                invite_code: community.invite_code,
                role: community.role
            }
        });
    });
});

// Community Dashboard Stats
router.get('/dashboard', authMiddleware, (req, res) => {
    const userId = req.user.userId;

    const getCommunityId = `SELECT community_id FROM community_user WHERE user_id = ?`;

    db.query(getCommunityId, [userId], (err, result) => {
        if (err || result.length === 0) {
            return res.status(400).json({ message: 'User not in any community' });
        }

        const communityId = result[0].community_id;

        // Query all stats using nested queries
        const sql = `
            SELECT
                (SELECT COUNT(*) FROM community_user WHERE community_id = ?) AS members,
                (SELECT COUNT(*) FROM posts WHERE community_id = ?) AS posts,
                (SELECT COUNT(*) FROM comments c
                    JOIN posts p ON c.post_id = p.id
                    WHERE p.community_id = ?) AS comments,
                (SELECT COUNT(*) FROM likes l
                    JOIN posts p ON l.post_id = p.id
                    WHERE p.community_id = ?) AS likes
        `;

        db.query(sql, [communityId, communityId, communityId, communityId], (err2, stats) => {
            if (err2) {
                console.error("Dashboard error:", err2);
                return res.status(500).json({ message: 'Failed to fetch dashboard stats' });
            }

            const { members, posts, comments, likes } = stats[0];

            return res.status(200).json({
                message: "Dashboard data fetched",
                data: { members, posts, comments, likes }
            });
        });
    });
});


module.exports = router;
