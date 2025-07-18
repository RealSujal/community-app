// routes/help.js
const express = require('express');
const router = express.Router();
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');

// GET /api/faqs - Get all FAQs
router.get('/faqs', authMiddleware, async (req, res) => {
    try {
        const [rows] = await db.promise().query('SELECT id, question, answer FROM faqs');
        res.json(rows);
    } catch (err) {
        console.error('Error fetching FAQs:', err);
        res.status(500).json({ message: 'Failed to load FAQs' });
    }
});


// POST /api/feedback - Submit feedback
router.post('/feedback', authMiddleware, (req, res) => {
    const { rating, message, want_reply } = req.body;
    const user_id = req.user.id;

    if (!rating || rating < 1 || rating > 5) {
        return res.status(400).json({ message: 'Rating must be between 1 and 5.' });
    }

    const sql = 'INSERT INTO feedback (user_id, rating, message, want_reply) VALUES (?, ?, ?, ?)';
    db.query(sql, [user_id, rating, message || '', want_reply || false], (err, result) => {
        if (err) {
            console.error('Error saving feedback:', err);
            return res.status(500).json({ message: 'Failed to save feedback' });
        }
        return res.status(201).json({ message: 'Feedback submitted successfully' });
    });
});

router.post('/ai-chat', authMiddleware, async (req, res) => {
    const { message } = req.body;

    if (!message) {
        return res.status(400).json({ error: 'Message is required.' });
    }

    // Simulated AI response (replace with OpenAI or other API later)
    const reply = getAIResponse(message);

    return res.status(200).json({ reply });
});

// Basic rule-based bot for now
function getAIResponse(msg) {
    const lower = msg.toLowerCase();

    if (lower.includes('change phone') || lower.includes('update number')) {
        return 'You can update your phone number in the Edit Profile screen.';
    }

    if (lower.includes('join community')) {
        return 'To join a community, go to Join Community and enter the code.';
    }

    if (lower.includes('forgot password')) {
        return 'Use Forgot Password on login screen to reset.';
    }

    return "I'm still learning! Please check the FAQ or reach out for support.";
}


module.exports = router;
