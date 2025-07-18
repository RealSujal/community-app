// routes/otpRoutes.js
const express = require('express');
const router = express.Router();
const db = require('../models/db');
const nodemailer = require('nodemailer');
const crypto = require('crypto');

// ➕ Generate 4-digit OTP
function generateOTP() {
    return Math.floor(1000 + Math.random() * 9000).toString();
}

// 📧 Mailer
const transporter = nodemailer.createTransport({
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_FROM,
        pass: process.env.EMAIL_PASSWORD
    }
});

// Route 1: Send OTP
router.post('/send-otp', (req, res) => {
    const { email } = req.body;
    if (!email) return res.status(400).json({ message: 'Email is required' });

    const checkSql = `SELECT otp, expires_at FROM otp_verification WHERE email = ?`;

    db.query(checkSql, [email], (err, results) => {
        if (err) {
            console.error("DB Error:", err);
            return res.status(500).json({ message: 'Database error' });
        }

        const now = new Date();
        if (results.length > 0 && new Date(results[0].expires_at) > now) {
            const otp = results[0].otp;

            const mailOptions = {
                from: process.env.EMAIL_FROM,
                to: email,
                subject: 'Your OTP for Community App',
                text: `Your OTP is: ${otp}`
            };

            transporter.sendMail(mailOptions, (emailErr) => {
                if (emailErr) {
                    console.error('Email Error:', emailErr);
                    return res.status(500).json({ message: 'Error sending OTP' });
                }

                return res.status(200).json({ message: 'OTP resent (still valid)' });
            });

        } else {
            // Generate new OTP and update/insert
            const otp = generateOTP();
            const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 mins

            const upsertSql = `
                INSERT INTO otp_verification (email, otp, expires_at)
                VALUES (?, ?, ?)
                ON DUPLICATE KEY UPDATE otp = VALUES(otp), expires_at = VALUES(expires_at)
            `;

            db.query(upsertSql, [email, otp, expiresAt], (err2) => {
                if (err2) {
                    console.error('DB Error (Insert/Update):', err2);
                    return res.status(500).json({ message: 'Failed to store OTP' });
                }

                const mailOptions = {
                    from: process.env.EMAIL_FROM,
                    to: email,
                    subject: 'Your OTP for Community App',
                    text: `Your OTP is: ${otp}`
                };

                transporter.sendMail(mailOptions, (emailErr) => {
                    if (emailErr) {
                        console.error('Email Error:', emailErr);
                        return res.status(500).json({ message: 'Error sending OTP' });
                    }

                    return res.status(200).json({ message: 'New OTP sent successfully' });
                });
            });
        }
    });
});


// Route 2: Verify OTP & Register User
router.post('/verify-otp-register', async (req, res) => {
    const { name, email, phone, password, otp } = req.body;
    if (!email || !password || !otp || !name) {
        return res.status(400).json({ message: 'All fields are required' });
    }

    const checkSQL = `
        SELECT * FROM otp_verification 
        WHERE email = ? AND otp = ? AND expires_at > NOW()
    `;

    db.query(checkSQL, [email, otp], async (err, results) => {
        if (err) return res.status(500).json({ message: 'DB error' });
        if (results.length === 0) return res.status(400).json({ message: 'Invalid or expired OTP' });

        const bcrypt = require('bcrypt');
        const hashedPassword = await bcrypt.hash(password, 10);

        const insertUserSQL = `
            INSERT INTO users (name, email, phone, password_hash, is_verified)
            VALUES (?, ?, ?, ?, true)
        `;

        db.query(insertUserSQL, [name, email, phone, hashedPassword], (err2) => {
            if (err2) {
                console.error('User registration error:', err2);
                return res.status(500).json({ message: 'User already exists or DB error' });
            }

            // Cleanup OTP
            db.query(`DELETE FROM otp_verification WHERE email = ?`, [email]);

            return res.status(201).json({ message: 'Registered and verified successfully' });
        });
    });
});

module.exports = router;
