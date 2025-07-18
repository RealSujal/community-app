const express = require('express');
const router = express.Router();
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const db = require('../models/db');
const { sendOTPEmail } = require('../utils/mailer');
const authMiddleware = require('../middleware/authMiddleware');

const JWT_SECRET = process.env.JWT_SECRET || 'sQT8PcbHYUvPrci';
const OTP_EXPIRY_MINUTES = parseInt(process.env.OTP_EXPIRY_MINUTES || 5);

// Utility: Generate 4-digit OTP
const generateOTP = () => Math.floor(1000 + Math.random() * 9000).toString();


// 1. Send OTP
router.post('/send-otp', async (req, res) => {
    const { email } = req.body;

    if (!email) return res.status(400).json({ message: 'Email is required' });

    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + OTP_EXPIRY_MINUTES * 60000);

    const sql = `
        INSERT INTO otp_verification (email, otp, expires_at)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE otp = VALUES(otp), expires_at = VALUES(expires_at)
    `;

    db.query(sql, [email, otp, expiresAt], async (err) => {
        if (err) {
            console.error("OTP DB error:", err);
            return res.status(500).json({ message: 'Failed to store OTP' });
        }

        try {
            await sendOTPEmail(email, otp, 'register');
            return res.status(200).json({ message: 'OTP sent to your email' });
        } catch (emailErr) {
            console.error('OTP email error:', emailErr);
            return res.status(500).json({ message: 'Failed to send OTP' });
        }
    });
});


// 2. Register with OTP
router.post('/register', async (req, res) => {
    const { name, email, phone, password, otp } = req.body;

    if (!name || !email || !password || !otp) {
        return res.status(400).json({ message: 'Name, email, password, and OTP are required.' });
    }

    const checkOtpSql = `SELECT * FROM otp_verification WHERE email = ?`;
    db.query(checkOtpSql, [email], async (err, results) => {
        if (err || results.length === 0) {
            return res.status(400).json({ message: 'OTP not found. Please request again.' });
        }

        const record = results[0];
        if (record.otp !== otp) {
            return res.status(400).json({ message: 'Invalid OTP' });
        }

        if (new Date() > record.expires_at) {
            return res.status(400).json({ message: 'OTP expired' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);

        const insertUserSql = `INSERT INTO users (name, email, phone, password_hash, is_verified) VALUES (?, ?, ?, ?, TRUE)`;

        db.query(insertUserSql, [name, email, phone, hashedPassword], async (err2, result) => {
            if (err2) {
                console.error("Register error:", err2);
                return res.status(500).json({ message: 'Email already exists or DB error' });
            }

            const newUserId = result.insertId;

            // Insert default privacy settings for the new user
            try {
                await db.promise().query(
                    `INSERT INTO privacy_settings (user_id) VALUES (?)`,
                    [newUserId]
                );
            } catch (privacyErr) {
                console.error('Failed to insert privacy settings:', privacyErr);
            }

            db.query(`DELETE FROM otp_verification WHERE email = ?`, [email]);

            return res.status(201).json({ message: 'Registered successfully with OTP verification' });
        });
    });
});



// 3. Login Route
router.post('/login', (req, res) => {
    const { email, password } = req.body;

    if (!email || !password) {
        return res.status(400).json({ message: 'Email and password are required.' });
    }

    const sql = `SELECT * FROM users WHERE email = ?`;
    db.query(sql, [email], async (err, results) => {
        if (err || results.length === 0) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        const user = results[0];
        const match = await bcrypt.compare(password, user.password_hash);

        if (!match) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        if (!user.is_verified) {
            return res.status(403).json({ message: 'Please verify your email first.' });
        }

        const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '1h' });

        return res.status(200).json({
            message: 'Login successful',
            token,
            user: {
                id: user.id,
                name: user.name,
                email: user.email
            }
        });
    });
});

// 4. Request OTP for password reset
router.post('/request-reset', (req, res) => {
    const { email } = req.body;

    if (!email) return res.status(400).json({ message: 'Email is required' });

    const otp = generateOTP();
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 mins

    const sql = `
        INSERT INTO otp_verification (email, otp, expires_at)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE otp = VALUES(otp), expires_at = VALUES(expires_at)
    `;

    db.query(sql, [email, otp, expiresAt], (err) => {
        if (err) {
            console.error("OTP Save Error:", err);
            return res.status(500).json({ message: 'Failed to save OTP' });
        }

        sendOTPEmail(email, otp, 'reset')
            .then(() => res.status(200).json({ message: 'OTP sent to your email' }))
            .catch((emailErr) => {
                console.error("Email Error:", emailErr);
                res.status(500).json({ message: 'Failed to send OTP' });
            });
    });
});


// 5. Reset Password
router.post('/reset-password', async (req, res) => {
    const { email, otp, newPassword, confirmPassword } = req.body;

    if (!email || !otp || !newPassword || !confirmPassword) {
        return res.status(400).json({ message: 'All fields are required' });
    }

    if (newPassword !== confirmPassword) {
        return res.status(400).json({ message: 'Passwords do not match' });
    }

    const sql = `SELECT * FROM otp_verification WHERE email = ?`;
    db.query(sql, [email], async (err, results) => {
        if (err || results.length === 0) {
            return res.status(400).json({ message: 'OTP not found' });
        }

        const record = results[0];
        if (record.otp !== otp) {
            return res.status(401).json({ message: 'Invalid OTP' });
        }

        if (new Date() > record.expires_at) {
            return res.status(400).json({ message: 'OTP expired' });
        }

        const hashed = await bcrypt.hash(newPassword, 10);
        const updateSql = `UPDATE users SET password_hash = ? WHERE email = ?`;

        db.query(updateSql, [hashed, email], (err2) => {
            if (err2) return res.status(500).json({ message: 'Password update failed' });

            // Cleanup OTP
            db.query(`DELETE FROM otp_verification WHERE email = ?`, [email]);

            res.status(200).json({ message: 'Password reset successful' });
        });
    });
});

router.get('/privacy-settings', authMiddleware, async (req, res) => {
    const userId = req.user.userId;

    try {
        const [rows] = await db.promise().query(
            'SELECT show_phone, show_email, show_dob, show_address, show_gender, show_social_links FROM privacy_settings WHERE user_id = ?',
            [userId]
        );

        if (rows.length === 0) {
            return res.status(404).json({ message: 'Privacy settings not found' });
        }

        res.json({ privacy: rows[0] });
    } catch (err) {
        console.error("Privacy fetch error:", err);
        res.status(500).json({ message: 'Server error' });
    }
});


router.put('/privacy-settings', authMiddleware, async (req, res) => {
    const userId = req.user.userId;
    const {
        show_phone,
        show_email,
        show_dob,
        show_address,
        show_gender,
        show_social_links
    } = req.body;

    try {
        await db.promise().query(
            `UPDATE privacy_settings
         SET show_phone = ?, show_email = ?, show_dob = ?, show_address = ?, show_gender = ?, show_social_links = ?
         WHERE user_id = ?`,
            [
                show_phone ?? true,
                show_email ?? true,
                show_dob ?? true,
                show_address ?? true,
                show_gender ?? true,
                show_social_links ?? true,
                userId
            ]
        );

        res.json({ message: 'Privacy settings updated successfully' });
    } catch (err) {
        console.error("Privacy update error:", err);
        res.status(500).json({ message: 'Failed to update privacy settings' });
    }
});


// router.put('/change-password', authMiddleware, async (req, res) => {
//     const userId = req.user.userId;
//     const { currentPassword, newPassword } = req.body;

//     if (!currentPassword || !newPassword) {
//         return res.status(400).json({ message: 'Both current and new password are required' });
//     }

//     try {
//         const [users] = await db.promise().query(
//             'SELECT password FROM users WHERE id = ?',
//             [userId]
//         );

//         if (users.length === 0) {
//             return res.status(404).json({ message: 'User not found' });
//         }

//         const isMatch = await bcrypt.compare(currentPassword, users[0].password);
//         if (!isMatch) {
//             return res.status(401).json({ message: 'Current password is incorrect' });
//         }

//         const hashed = await bcrypt.hash(newPassword, 10);
//         await db.promise().query(
//             'UPDATE users SET password = ? WHERE id = ?',
//             [hashed, userId]
//         );

//         res.json({ message: 'Password changed successfully' });
//     } catch (err) {
//         console.error('Password change error:', err);
//         res.status(500).json({ message: 'Failed to change password' });
//     }
// });



module.exports = router;
