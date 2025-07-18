const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');

// Change Password
router.post('/change-password', authMiddleware, async (req, res) => {
    const userId = req.user.userId;
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
        return res.status(400).json({ message: "All fields are required." });
    }

    try {
        // Fetch existing password hash
        const [userRows] = await db.promise().query(
            'SELECT password_hash FROM users WHERE id = ?',
            [userId]
        );

        if (!userRows.length) {
            return res.status(404).json({ message: "User not found." });
        }

        const user = userRows[0];

        // Check if current password matches
        const isMatch = await bcrypt.compare(currentPassword, user.password_hash);
        if (!isMatch) {
            return res.status(401).json({ message: "Current password is incorrect." });
        }

        // Hash and update new password
        const hashed = await bcrypt.hash(newPassword, 10);
        await db.promise().query(
            'UPDATE users SET password_hash = ? WHERE id = ?',
            [hashed, userId]
        );

        return res.json({ message: "Password changed successfully." });

    } catch (err) {
        console.error("Change password error:", err);
        return res.status(500).json({ message: "Server error." });
    }
});

module.exports = router;
