/**
 * Free Email Notification Service
 * Uses standard Nodemailer with Gmail SMTP or custom SMTP credentials
 */

const BusinessProfile = require('../models/BusinessProfile');

class EmailService {
  /**
   * Get configured transporter or mock logger if credentials not yet configured
   */
  static getTransporter() {
    const user = process.env.EMAIL_USER;
    const pass = process.env.EMAIL_PASS;

    if (!user || !pass) {
      return null;
    }

    try {
      const nodemailer = require('nodemailer');
      return nodemailer.createTransport({
        service: 'gmail',
        auth: { user, pass }
      });
    } catch (err) {
      console.warn('Nodemailer not initialized:', err.message);
      return null;
    }
  }

  /**
   * Send Email with HTML template
   */
  static async sendMail({ to, subject, html, text }) {
    const transporter = this.getTransporter();
    const from = process.env.EMAIL_FROM || process.env.EMAIL_USER || 'noreply@studylibrary.com';

    if (!transporter) {
      console.log(`[Email Mock Log] To: ${to} | Subject: ${subject}`);
      return { success: true, mocked: true, message: 'Email logged (SMTP credentials not configured in .env)' };
    }

    try {
      const info = await transporter.sendMail({
        from: `"Study Library" <${from}>`,
        to,
        subject,
        text,
        html
      });
      return { success: true, messageId: info.messageId };
    } catch (error) {
      console.error('Failed to send email:', error.message);
      return { success: false, error: error.message };
    }
  }

  /**
   * Send Branded Payment Receipt Email
   */
  static async sendPaymentReceipt(student, payment, businessName = 'Study Library') {
    if (!student.email) return;

    const subject = `Receipt Confirmation: ₹${payment.amountPaid.toLocaleString('en-IN')} - ${businessName}`;
    const html = `
      <div style="font-family: 'Helvetica Neue', Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;">
        <div style="background: #6c5ce7; color: #ffffff; padding: 24px; text-align: center;">
          <h1 style="margin: 0; font-size: 24px; font-weight: 800;">${businessName}</h1>
          <p style="margin: 6px 0 0 0; opacity: 0.9; font-size: 14px;">Fee Payment Confirmation & Receipt</p>
        </div>
        <div style="padding: 24px; color: #1e293b;">
          <p style="font-size: 16px;">Dear <strong>${student.name}</strong>,</p>
          <p>We have successfully received your membership fee payment. Below are your transaction details:</p>
          
          <table style="width: 100%; border-collapse: collapse; margin: 20px 0; font-size: 14px;">
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 10px 0; color: #64748b;">Receipt Number:</td>
              <td style="padding: 10px 0; font-weight: 700; text-align: right;">${payment.receiptNumber || 'REC-' + Date.now()}</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 10px 0; color: #64748b;">Student ID:</td>
              <td style="padding: 10px 0; font-weight: 700; text-align: right;">${student.studentId}</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 10px 0; color: #64748b;">Amount Paid:</td>
              <td style="padding: 10px 0; font-weight: 800; font-size: 18px; color: #00b894; text-align: right;">₹${payment.amountPaid.toLocaleString('en-IN')}</td>
            </tr>
            <tr style="border-bottom: 1px solid #f1f5f9;">
              <td style="padding: 10px 0; color: #64748b;">Payment Mode:</td>
              <td style="padding: 10px 0; text-align: right;">${(payment.paymentMode || 'UPI').toUpperCase()}</td>
            </tr>
            <tr>
              <td style="padding: 10px 0; color: #64748b;">Membership Valid Until:</td>
              <td style="padding: 10px 0; font-weight: 700; text-align: right;">${new Date(payment.validUntil || Date.now() + 30*86400000).toLocaleDateString('en-IN')}</td>
            </tr>
          </table>

          <div style="text-align: center; margin-top: 30px;">
            <a href="http://localhost:5000/#/portal" style="background: #6c5ce7; color: #ffffff; padding: 12px 24px; text-decoration: none; border-radius: 8px; font-weight: 700; font-size: 14px; display: inline-block;">Open Student Portal</a>
          </div>
        </div>
        <div style="background: #f8fafc; padding: 16px; text-align: center; font-size: 12px; color: #94a3b8; border-top: 1px solid #e2e8f0;">
          © ${new Date().getFullYear()} ${businessName}. All rights reserved.
        </div>
      </div>
    `;

    return this.sendMail({ to: student.email, subject, html });
  }
}

module.exports = EmailService;
