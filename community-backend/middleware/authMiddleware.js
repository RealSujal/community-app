const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET;

const authMiddleware = (req, res, next) => {
    const authHeader = req.headers.authorization;

    console.log('🔐 Incoming Authorization Header:', authHeader);

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        console.log("⛔ Missing or malformed Authorization header");
        return res.status(401).json({ message: 'Token required' });
    }

    const token = authHeader.split(' ')[1];
    console.log("📥 Extracted Token:", token);

    if (!token) {
        console.log("⛔ Token not found after splitting");
        return res.status(401).json({ message: "Token required" });
    }

    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        console.log("✅ Token verified. Payload:", decoded);
        req.user = decoded;
        next();
    } catch (err) {
        console.error("❌ Token verification failed:", err.message);
        return res.status(401).json({ message: 'Invalid token' });
    }
};

module.exports = authMiddleware;
