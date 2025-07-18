const express = require('express');
const router = express.Router();
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');

router.post('/register-family', authMiddleware, async (req, res) => {
    const { family_name, address } = req.body;
    const userId = req.user.userId;

    try {
        // Create family
        const [result] = await db.promise().query(
            `INSERT INTO family (family_name, address, contact_number, user_id)
         VALUES (?, ?, ?, ?)`,
            [family_name, address, null, userId]
        );

        const familyId = result.insertId;

        // Link family to user
        await db.promise().query(
            `UPDATE users SET family_id = ? WHERE id = ?`,
            [familyId, userId]
        );

        res.status(201).json({
            message: 'Family registered successfully',
            familyId
        });
    } catch (err) {
        console.error('Register Family Error:', err);
        res.status(500).json({ error: 'Failed to register family' });
    }
});


// GET /api/families - List of all families
router.get('/families', (req, res) => {
    db.query('SELECT id, family_name FROM family', (err, results) => {
        if (err) return res.status(500).json({ message: "Database error" });
        res.json({ families: results });
    });
});

// GET /my-family - get family details for the logged-in user
router.get('/my-family', authMiddleware, async (req, res) => {
    const userId = req.user.userId;

    try {
        // Get family_id from users table
        const [userRows] = await db.promise().query(
            `SELECT family_id FROM users WHERE id = ?`,
            [userId]
        );

        const familyId = userRows?.[0]?.family_id;
        if (!familyId) return res.json({ familyExists: false });

        // Fetch family info
        const [familyRows] = await db.promise().query(
            `SELECT id, family_name, address, contact_number, head_name
         FROM family WHERE id = ?`,
            [familyId]
        );

        if (!familyRows.length) return res.json({ familyExists: false });

        // Fetch members
        const [members] = await db.promise().query(
            `SELECT id, name, gender, dob, age, relation, phone, address, email
         FROM person WHERE family_id = ?
        ORDER BY id ASC`,
            [familyId]
        );

        const response = {
            familyExists: true,
            family: familyRows[0],
            members
        };
        res.json(response);
    } catch (err) {
        console.error("My Family Error:", err);
        res.status(500).json({ message: "Database error" });
    }
});

// GET /family-by-person/:personId
router.get('/family-by-person/:personId', async (req, res) => {
    const personId = req.params.personId;

    try {
        // Get person and their family_id
        const [personRows] = await db.promise().query(
            `SELECT family_id FROM person WHERE id = ?`,
            [personId]
        );

        const familyId = personRows?.[0]?.family_id;
        if (!familyId) return res.json({ familyExists: false });

        // Fetch family info
        const [familyRows] = await db.promise().query(
            `SELECT id, family_name, address, contact_number, head_name
         FROM family WHERE id = ?`,
            [familyId]
        );

        if (!familyRows.length) return res.json({ familyExists: false });

        // Fetch members
        const [members] = await db.promise().query(
            `SELECT id, name, gender, dob, age, relation, phone, address, email
         FROM person WHERE family_id = ?
        ORDER BY id ASC`,
            [familyId]
        );

        res.json({
            familyExists: true,
            family: familyRows[0],
            members
        });
    } catch (err) {
        console.error("Family by Person Error:", err);
        res.status(500).json({ message: "Database error" });
    }
});

module.exports = router;
