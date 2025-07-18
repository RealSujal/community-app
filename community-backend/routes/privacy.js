const express = require('express');
const router = express.Router();
const auth = require('../middleware/authMiddleware');
const db = require('../models/db');

// Get current settings
router.get('/privacy', auth, async (req, res) => {
    const userId = req.user.userId;
    const [rows] = await db.promise().query(
        'SELECT show_phone, show_email, show_dob, show_address, show_social_links FROM privacy_settings WHERE user_id = ?',
        [userId]
    );

    if (rows.length === 0) {
        return res.json({
            phone: true,
            email: true,
            dob: true,
            address: true,
            social_links: true,
        });
    }

    const row = rows[0];
    res.json({
        phone: row.show_phone,
        email: row.show_email,
        dob: row.show_dob,
        address: row.show_address,
        social_links: row.show_social_links,
    });
});

// Update one setting
router.put('/privacy', auth, async (req, res) => {
    const userId = req.user.userId;
    const key = Object.keys(req.body)[0];
    const value = req.body[key];

    const fieldMap = {
        phone: 'show_phone',
        email: 'show_email',
        dob: 'show_dob',
        address: 'show_address',
        social_links: 'show_social_links',
    };

    const field = fieldMap[key];
    if (!field) {
        return res.status(400).json({ message: 'Invalid field name' });
    }

    const [exists] = await db.promise().query(
        'SELECT id FROM privacy_settings WHERE user_id = ?',
        [userId]
    );

    if (exists.length === 0) {
        await db.promise().query(
            `INSERT INTO privacy_settings (user_id, ${field}) VALUES (?, ?)`,
            [userId, value]
        );
    } else {
        await db.promise().query(
            `UPDATE privacy_settings SET ${field} = ? WHERE user_id = ?`,
            [value, userId]
        );
    }

    res.json({ message: 'Updated' });
});


module.exports = router;
