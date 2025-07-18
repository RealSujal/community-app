const express = require('express');
const router = express.Router();
const db = require('../models/db');
const authMiddleware = require('../middleware/authMiddleware');
const { getRelation } = require('../utils/relationMapper');

// ADD MEMBER (used by both head & inner add screens)
router.post('/person', authMiddleware, async (req, res) => {
    const { name, gender, dob, age, relation, address, phone, family_id, email } = req.body;
    const addedByUserId = req.user.userId;
    let familyIdFromBody = family_id;

    try {
        let familyId = familyIdFromBody;
        if (!familyId) {
            const [familyRows] = await db.promise().query(
                'SELECT id FROM family WHERE user_id = ?',
                [addedByUserId]
            );
            if (familyRows.length === 0) {
                return res.status(400).json({ message: "Family not found for current user" });
            }
            familyId = familyRows[0].id;
        }

        // Prevent duplicate person with same email in the same family
        // But allow the user who is creating the family to use their own email for the head
        if (email) {
            const [existingPerson] = await db.promise().query(
                'SELECT id, user_id FROM person WHERE email = ? AND family_id = ?',
                [email, familyId]
            );
            if (existingPerson.length > 0) {
                // Check if this is the same user trying to add themselves as head
                const existingPersonData = existingPerson[0];
                // If it's the same user and they already have a person record, dont allow duplicate
                if (existingPersonData.user_id === addedByUserId) {
                    return res.status(409).json({ message: 'Member already exists in family, duplicate: true' });
                }
                // If it's a different user, dont allow duplicate email
                return res.status(409).json({ message: 'A member with this email already exists in the family., duplicate: true' });
            }
        }

        let userId = null;
        if (email) {
            const [userRows] = await db.promise().query(
                'SELECT id FROM users WHERE email = ?',
                [email]
            );
            if (userRows.length > 0) {
                userId = userRows[0].id;
                // Link this user to the family
                await db.promise().query(
                    'UPDATE users SET family_id = ? WHERE id = ?',
                    [familyId, userId]
                );
            }
        }

        let finalAddress = address;
        if (!finalAddress || finalAddress.trim() === '') {
            const [familyResult] = await db.promise().query(
                'SELECT address FROM family WHERE id = ?', [familyId]
            );
            finalAddress = familyResult?.[0]?.address || '';
        }

        // Insert person
        await db.promise().query(
            `INSERT INTO person 
            (name, gender, dob, age, relation, address, phone, family_id, user_id, added_by_user_id, email)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                name,
                gender,
                dob,
                age,
                relation,
                finalAddress,
                phone,
                familyId,
                userId,
                addedByUserId,
                email || null
            ]
        );

        // Check if this is the first member (head) and update family table
        const [memberCount] = await db.promise().query(
            'SELECT COUNT(*) as count FROM person WHERE family_id = ?',
            [familyId]
        );

        if (memberCount[0].count === 1) {
            // This is the first member (head), update family table
            await db.promise().query(
                'UPDATE family SET head_name = ?, contact_number = ? WHERE id = ?',
                [name, phone, familyId]
            );
            console.log('👑 Updated family with head details:', { name, phone, familyId });
        }

        res.status(201).json({ message: 'Member added successfully' });
    } catch (err) {
        console.error('Add Person Error:', err);
        res.status(500).json({ message: 'Failed to add member' });
    }
});

// DELETE /person/:id - Remove a member from the family
router.delete('/person/:id', authMiddleware, async (req, res) => {
    const personId = req.params.id;
    try {
        // Get the person and their user_id (if any)
        const [personRows] = await db.promise().query(
            'SELECT user_id, family_id FROM person WHERE id = ?',
            [personId]
        );
        if (!personRows || personRows.length === 0) {
            return res.status(404).json({ message: 'Person not found' });
        }
        const { user_id, family_id } = personRows[0];
        // Delete the person
        await db.promise().query('DELETE FROM person WHERE id = ?', [personId]);
        // If linked to a user, set their family_id to NULL
        if (user_id) {
            await db.promise().query('UPDATE users SET family_id = NULL WHERE id = ?', [user_id]);
        }
        res.json({ message: 'Member removed successfully' });
    } catch (err) {
        console.error('Remove Person Error:', err);
        res.status(500).json({ message: 'Failed to remove member' });
    }
});

//  GET person details by ID
router.get('/person/:id', async (req, res) => {
    const { id } = req.params;
    try {
        const [result] = await db.promise().query(
            'SELECT * FROM person WHERE id = ?', [id]
        );
        if (result.length === 0)
            return res.status(404).json({ message: 'Not found' });

        res.json({ person: result[0] });
    } catch (err) {
        console.error('Fetch person failed:', err);
        res.status(500).json({ message: 'Server error' });
    }
});

//  UPDATE person
router.put('/person/:id', authMiddleware, async (req, res) => {
    const personId = req.params.id;
    const {
        name, gender, dob, age, relation,
        address, phone, email
    } = req.body;

    try {
        await db.promise().query(`
            UPDATE person SET 
                name = ?, gender = ?, dob = ?, age = ?, 
                relation = ?, address = ?, phone = ?, email = ?
            WHERE id = ?
        `, [name, gender, dob, age, relation, address, phone, email, personId]);

        res.json({ message: 'Person updated successfully' });
    } catch (err) {
        console.error('Update failed:', err);
        res.status(500).json({ message: 'Failed to update person' });
    }
});

//  GET people list by family or address
router.get('/people', (req, res) => {
    const { family_id, address, name } = req.query;

    let sql = 'SELECT * FROM person WHERE 1=1';
    const params = [];

    if (family_id) {
        sql += ' AND family_id = ?';
        params.push(family_id);
    }

    if (address) {
        sql += ' AND address LIKE ?';
        params.push(`%${address}%`);
    }

    if (name) {
        sql += ' AND name LIKE ?';
        params.push(`%${name}%`);
    }

    db.query(sql, params, (err, results) => {
        if (err) {
            console.error("Fetch people error:", err);
            return res.status(500).json({ message: "DB error" });
        }

        res.json({
            message: "People fetched successfully",
            people: results
        });
    });
});

//  Add Relation
router.post('/add-relation', (req, res) => {
    const { person_id, related_to_id, relation_type } = req.body;

    if (!person_id || !related_to_id || !relation_type) {
        return res.status(400).json({ message: 'All relation fields are required' });
    }

    const sql = `
        INSERT INTO relation (person_id, related_to_id, relation_type)
        VALUES (?, ?, ?)
    `;

    db.query(sql, [person_id, related_to_id, relation_type], (err, result) => {
        if (err) {
            console.error("Relation insert error:", err);
            return res.status(500).json({ message: "Database error" });
        }

        res.status(201).json({
            message: "Relation added",
            relationId: result.insertId
        });
    });
});

//  GET relations for a person
router.get('/relations/:person_id', (req, res) => {
    const { person_id } = req.params;

    const sql = `
        SELECT 
            r.relation_type,
            p2.relation AS self_relation,
            p2.id AS related_person_id,
            p2.name AS related_person_name,
            p2.age,
            p2.gender,
            p2.phone,
            p2.address
        FROM relation r
        JOIN person p2 ON r.related_to_id = p2.id
        WHERE r.person_id = ?
            AND p2.id != ?
    `;

    db.query(sql, [person_id, person_id], (err, results) => {
        if (err) {
            console.error("Fetch relation error:", err);
            return res.status(500).json({ message: "Database error" });
        }

        res.json({
            message: "Relations fetched successfully",
            relations: results
        });
    });
});

// GET /api/profile/:personId/family-relations
router.get('/profile/:personId/family-relations', async (req, res) => {
    const personId = req.params.personId;

    try {
        // Get the person and their family_id and relation
        const [personRows] = await db.promise().query(
            'SELECT id, family_id, relation, name FROM person WHERE id = ?',
            [personId]
        );
        if (!personRows.length) return res.status(404).json({ message: "Person not found" });

        const person = personRows[0];

        // Get all family members
        const [familyMembers] = await db.promise().query(
            'SELECT id, name, relation, user_id FROM person WHERE family_id = ?',
            [person.family_id]
        );

        // Map relations from this person's perspective
        const relations = familyMembers
            .filter(member => member.id !== person.id)
            .map(member => ({
                id: member.user_id,
                name: member.name,
                relation: getRelation(member.relation, person.relation), // relation from viewed person's perspective
                member_relation_to_head: member.relation // for reference/debugging
            }));

        res.json({
            self: {
                id: person.id,
                name: person.name,
                relation_to_head: person.relation
            },
            relations
        });
    } catch (err) {
        console.error("Family Relations Error:", err);
        res.status(500).json({ message: "Database error" });
    }
});

module.exports = router;
