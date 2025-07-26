const nodemailer = require('nodemailer');
const dotenv = require('dotenv');
dotenv.config();

//  Setup transporter using Gmail + environment variables
const transporter = nodemailer.createTransport({
    host: process.env.EMAIL_HOST,
    port: process.env.EMAIL_PORT,
    secure: false,
    service: 'gmail',
    auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS
    }
});

/**
 * Send OTP email with different purpose-based templates (register / reset)
 * @param {string} toEmail - Receiver's email
 * @param {string} otp - OTP code
 * @param {string} purpose - Either 'register' or 'reset'
 */
const sendOTPEmail = async (toEmail, otp, purpose = 'register') => {
    const from = `"${process.env.EMAIL_FROM_NAME}" <${process.env.EMAIL_FROM_ADDRESS}>`;

    //  Dynamic subject and message
    const subject =
        purpose === 'reset'
            ? 'Your OTP to Reset Password'
            : 'Your OTP for Registration';

    const introMessage =
        purpose === 'reset'
            ? 'You requested to reset your password. Use the following OTP:'
            : 'Thanks for registering. Use the following OTP to verify your email:';

    const html = `
        <p>Hi there 👋</p>
        <p>${introMessage}</p>
        <h2>${otp}</h2>
        <p>This OTP will expire in ${process.env.OTP_EXPIRY_MINUTES || 5} minutes.</p>
        <p>— The Community App Team</p>
    `;

    const mailOptions = {
        from,
        to: toEmail,
        subject,
        html,
    };

    await transporter.sendMail(mailOptions);
};

module.exports = { sendOTPEmail };
