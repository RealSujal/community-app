// app.js
const express = require("express");
const dotenv = require("dotenv");
const path = require("path");

// Load environment variables
dotenv.config();

const app = express();

// Database connection
const db = require("./models/db");
db.query("SELECT 1 + 1 AS result", (err, results) => {
    if (err) {
        console.error("DB Connection Failed:", err);
    } else {
        console.log("DB Connected. Test Result:", results[0].result);
    }
});

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// Test route
app.get("/", (req, res) => {
    res.send("Community API is running");
});

// Auth
app.use("/auth", require("./routes/authRoutes"));
app.use("/auth", require("./routes/otpRoutes"));

// User
app.use("/api/users", require("./routes/userRoutes"));

// Person & Family
app.use("/api", require("./routes/personRoutes"));
app.use("/api", require("./routes/familyRoutes"));

// Community & Posts
app.use("/api/communities", require("./routes/communityRoutes"));
app.use("/api/posts", require("./routes/postRoutes"));

// Notifications
const { router: notificationRoutes } = require("./routes/notificationRoutes");
app.use("/api/notifications", notificationRoutes);

// Privacy & Password
app.use("/api", require("./routes/privacy"));
app.use("/api", require("./routes/changePassword"));

// Help & Feedback
app.use("/api", require("./routes/help"));

// Start server
const PORT = process.env.PORT || 3000;
const HOST = "0.0.0.0";

app.listen(PORT, HOST, () => {
    console.log(`Server running on http://${HOST}:${PORT}`);
    console.log(`Also accessible at http://192.168.1.7:${PORT}`);
});
