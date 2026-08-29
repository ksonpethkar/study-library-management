/**
 * Study Library Management System — Universal Payment Studio
 * Centralized, standard payment engine for Self-Registration, Student Portal, Admin Payment Studio, and Student Master.
 */

import { escapeHTML, Toast } from './ui.js';

export const PaymentStudio = {
  /**
   * Get active business UPI & Banking profile
   */
  getProfile() {
    let bp = {};
    try {
      bp = window.store?.settings?.businessProfile ||
           window.store?.profile ||
           JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}') || {};
    } catch (e) {}

    return {
      businessName: bp.businessName || 'Study Library',
      upiId: bp.upiId || 'thecozycorner@okaxis',
      customQrImage: bp.upiQrCode || bp.upiQrImage || '',
      bankDetails: bp.bankDetails || {
        bankName: 'State Bank of India',
        accountNumber: '41238902145',
        ifscCode: 'SBIN0001234',
        accountHolder: bp.businessName || 'The Cozy Corner Centre',
        accountType: 'Current'
      },
      paymentInstructions: bp.paymentInstructions || ''
    };
  },

  /**
   * Generate RFC-compliant UPI Payment URI
   */
  generateUpiUri({ upiId, businessName, amount, note = 'Library Fee Payment', txnRef = '' } = {}) {
    const p = this.getProfile();
    const targetUpiId = upiId || p.upiId;
    const targetBizName = businessName || p.businessName;
    const cleanAmount = parseFloat(amount) || 0;
    const cleanNote = (note || 'Library Fee Payment').substring(0, 50);
    const cleanRef = txnRef || `SL${Date.now().toString().slice(-8)}`;

    const params = [
      `pa=${encodeURIComponent(targetUpiId)}`,
      `pn=${encodeURIComponent(targetBizName)}`,
      `am=${cleanAmount}`,
      `cu=INR`,
      `tn=${encodeURIComponent(cleanNote)}`,
      `tr=${encodeURIComponent(cleanRef)}`
    ];

    return `upi://pay?${params.join('&')}`;
  },

  /**
   * Generate QR Code Image URL for a given UPI URI
   */
  getQrCodeImageUrl(upiUri, customQrImage = '') {
    if (customQrImage) {
      return customQrImage.startsWith('data:image') || customQrImage.startsWith('/')
        ? customQrImage
        : '/' + customQrImage;
    }
    return `https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(upiUri)}&margin=2&bgcolor=ffffff`;
  },

  /**
   * Render Standardized UPI Payment Card HTML
   */
  renderUPIWidget({
    amount = 0,
    note = 'Library Fee Payment',
    txnRef = '',
    upiId = '',
    businessName = '',
    customQrImage = '',
    showUtrInput = true,
    utrInputId = 'pay-utr-number',
    mountId = 'ps-upi-qr-mount'
  } = {}) {
    const profile = this.getProfile();
    const targetUpiId = upiId || profile.upiId;
    const targetBizName = businessName || profile.businessName;
    const targetQrImg = customQrImage || profile.customQrImage;
    const cleanAmount = parseFloat(amount) || 0;
    const upiUri = this.generateUpiUri({ upiId: targetUpiId, businessName: targetBizName, amount: cleanAmount, note, txnRef });
    const qrUrl = this.getQrCodeImageUrl(upiUri, targetQrImg);

    return `
      <div class="payment-studio-upi-card" style="background: var(--color-surface); border: 1.5px solid var(--color-border); border-radius: 16px; padding: 16px; text-align: center; box-shadow: var(--shadow-sm); margin-bottom: 1rem;">
        
        <!-- Header Banner -->
        <div style="font-weight: 800; font-size: 1rem; color: var(--color-text-primary); margin-bottom: 4px; display: flex; align-items: center; justify-content: center; gap: 8px;">
          <span>⚡</span> <span>1-Tap Instant UPI Payment</span>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-bottom: 12px;">
          Scan QR code or use installed UPI apps below to complete payment.
        </div>

        <!-- QR Code Display Frame -->
        <div style="margin-bottom: 12px;">
          <div id="${mountId}" style="background: #ffffff; padding: 10px; border-radius: 14px; display: inline-block; margin: 0 auto 6px auto; border: 1.5px solid var(--color-border); box-shadow: var(--shadow-sm);">
            <img src="${qrUrl}" alt="Scan UPI QR" style="width: 170px; height: 170px; border-radius: 8px; object-fit: contain; display: block; margin: 0 auto;" onerror="this.onerror=null; this.src='https://chart.googleapis.com/chart?chs=200x200&cht=qr&chl=${encodeURIComponent(upiUri)}';">
            <div style="margin-top: 6px;">
              <span class="badge" style="background: var(--color-primary); color: #fff; font-size: 0.8rem; font-weight: 700; padding: 4px 10px; border-radius: 20px;">
                Pay ₹${cleanAmount.toLocaleString('en-IN')}
              </span>
            </div>
          </div>

          <!-- Official UPI ID & Copy Bar -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 10px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 8px; flex-wrap: wrap; margin-top: 8px; max-width: 420px; margin-left: auto; margin-right: auto;">
            <div style="text-align: left;">
              <div style="font-size: 0.7rem; color: var(--color-text-muted); font-weight: 600;">Official UPI ID</div>
              <span style="font-family: monospace; font-size: 0.92rem; font-weight: 700; color: var(--color-primary);" class="ps-display-upi-id">${escapeHTML(targetUpiId)}</span>
            </div>
            <button type="button" class="btn btn-sm btn-outline-primary btn-ps-copy-upi" data-upi="${escapeHTML(targetUpiId)}" style="padding: 4px 12px; font-size: 0.8rem; font-weight: 700; border-radius: 8px;">
              📋 Copy UPI ID
            </button>
          </div>
        </div>

        <!-- 1-Tap UPI Intent Mobile Shortcuts -->
        <div style="margin-top: 12px; border-top: 1px dashed var(--color-border); padding-top: 10px; max-width: 420px; margin-left: auto; margin-right: auto;">
          <div style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-secondary); margin-bottom: 8px;">
            Or Open Directly in Your UPI App:
          </div>
          <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px;">
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="gpay" data-uri="${escapeHTML(upiUri)}" style="background: #4285F4; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">🔵</span>
              <span>GPay</span>
            </button>
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="phonepe" data-uri="${escapeHTML(upiUri)}" style="background: #5f259f; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">🟣</span>
              <span>PhonePe</span>
            </button>
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="paytm" data-uri="${escapeHTML(upiUri)}" style="background: #00baf2; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">💙</span>
              <span>Paytm</span>
            </button>
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="generic" data-uri="${escapeHTML(upiUri)}" style="background: #00b894; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">📲</span>
              <span>BHIM / App</span>
            </button>
          </div>
        </div>

        <!-- NPCI Anti-Failure Guidance Alert -->
        <div style="margin-top: 10px; background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: 10px; padding: 8px 10px; text-align: left; font-size: 0.75rem; color: var(--color-text-secondary); line-height: 1.35; max-width: 420px; margin-left: auto; margin-right: auto;">
          <strong style="color: #d97706;">💡 Payment Tip:</strong> If your UPI app shows a security notice on intent links, simply <strong>Scan the QR Code</strong> or tap <strong>📋 Copy UPI ID</strong> and pay directly in your app.
        </div>

        ${showUtrInput ? `
          <!-- 12-Digit Bank UTR / Reference No Input Field -->
          <div style="margin-top: 12px; text-align: left; max-width: 420px; margin-left: auto; margin-right: auto;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
              <label class="form-label mb-0" style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">
                <span>💳</span> 12-Digit Bank UTR / Ref No.
              </label>
              <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); font-size: 0.7rem; font-weight: 700;">Required</span>
            </div>
            <div style="display: flex; gap: 6px;">
              <input type="text" id="${utrInputId}" class="form-control ps-utr-input" placeholder="e.g. 423819203912 (12 digits)" maxlength="25" style="font-family: monospace; font-size: 0.92rem; font-weight: 600; letter-spacing: 0.5px;">
              <button type="button" class="btn btn-outline-primary btn-ps-paste-utr" data-target="${utrInputId}" style="font-size: 0.8rem; padding: 6px 12px; white-space: nowrap; border-radius: 8px; font-weight: 700;">📋 Paste</button>
            </div>
            <small class="text-muted" style="font-size: 0.72rem; display: block; margin-top: 4px;">
              💡 Find your 12-digit UTR in Google Pay / PhonePe / Paytm payment receipt and paste above.
            </small>
          </div>
        ` : ''}
      </div>
    `;
  },

  /**
   * Render Standardized Beneficiary Bank Details Card HTML
   */
  renderBankDetailsWidget() {
    const p = this.getProfile();
    const b = p.bankDetails || {};
    const bankName = b.bankName || 'State Bank of India';
    const accNo = b.accountNumber || '41238902145';
    const ifsc = b.ifscCode || 'SBIN0001234';
    const holder = b.accountHolder || p.businessName || 'The Cozy Corner Centre';
    const type = b.accountType || 'Current Account';

    const fullDetailsText = `Bank: ${bankName}\nAccount Name: ${holder}\nAccount No: ${accNo}\nIFSC: ${ifsc}\nType: ${type}`;

    return `
      <div class="payment-studio-bank-card" style="background: var(--color-surface); border: 1.5px solid var(--color-border); border-radius: 14px; padding: 1rem; margin-bottom: 1rem; box-shadow: var(--shadow-sm);">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; border-bottom: 1px dashed var(--color-border); padding-bottom: 6px;">
          <span style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">🏛️ Official Beneficiary Account</span>
          <button type="button" class="btn btn-xs btn-outline-primary btn-ps-copy-bank" data-details="${escapeHTML(fullDetailsText)}" style="padding: 2px 8px; font-size: 0.75rem; border-radius: 6px; font-weight: 700;">
            📋 Copy All
          </button>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 0.82rem;">
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">Account Holder</span>
            <strong style="color: var(--color-text-primary);">${escapeHTML(holder)}</strong>
          </div>
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">Bank Name</span>
            <strong style="color: var(--color-text-primary);">${escapeHTML(bankName)}</strong>
          </div>
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">Account Number</span>
            <strong style="font-family: monospace; color: var(--color-primary); font-size: 0.9rem;">${escapeHTML(accNo)}</strong>
          </div>
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">IFSC Code</span>
            <strong style="font-family: monospace; color: var(--color-primary); font-size: 0.9rem;">${escapeHTML(ifsc)}</strong>
          </div>
        </div>
      </div>
    `;
  },

  /**
   * Attach Interactive Event Listeners (Copy UPI, Copy Bank, Paste UTR, Intent Buttons)
   */
  attachEventListeners(container) {
    if (!container) return;

    // 1. Copy UPI ID Button
    container.querySelectorAll('.btn-ps-copy-upi').forEach(btn => {
      btn.addEventListener('click', async () => {
        const upi = btn.dataset.upi;
        if (!upi) return;
        try {
          await navigator.clipboard.writeText(upi);
          const originalText = btn.innerHTML;
          btn.innerHTML = '✓ Copied!';
          btn.classList.replace('btn-outline-primary', 'btn-success');
          Toast?.success ? Toast.success(`UPI ID "${upi}" copied to clipboard!`) : null;
          setTimeout(() => {
            btn.innerHTML = originalText;
            btn.classList.replace('btn-success', 'btn-outline-primary');
          }, 2000);
        } catch (e) {
          Toast?.error ? Toast.error('Could not copy automatically. Please copy manually.') : null;
        }
      });
    });

    // 2. Copy Bank Details Button
    container.querySelectorAll('.btn-ps-copy-bank').forEach(btn => {
      btn.addEventListener('click', async () => {
        const details = btn.dataset.details;
        if (!details) return;
        try {
          await navigator.clipboard.writeText(details);
          const originalText = btn.innerHTML;
          btn.innerHTML = '✓ Copied!';
          Toast?.success ? Toast.success('Bank details copied to clipboard!') : null;
          setTimeout(() => { btn.innerHTML = originalText; }, 2000);
        } catch (e) {
          Toast?.error ? Toast.error('Could not copy bank details.') : null;
        }
      });
    });

    // 3. Paste UTR Button
    container.querySelectorAll('.btn-ps-paste-utr').forEach(btn => {
      btn.addEventListener('click', async () => {
        const targetId = btn.dataset.target;
        const input = targetId ? container.querySelector(`#${targetId}`) : container.querySelector('.ps-utr-input');
        if (!input) return;
        try {
          const text = await navigator.clipboard.readText();
          const clean = text.replace(/[^a-zA-Z0-9]/g, '').trim();
          if (clean) {
            input.value = clean;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            Toast?.success ? Toast.success('Pasted from clipboard!') : null;
          } else {
            Toast?.warning ? Toast.warning('Clipboard is empty or contains invalid characters.') : null;
          }
        } catch (e) {
          Toast?.info ? Toast.info('Please paste your UTR manually into the input box.') : null;
        }
      });
    });

    // 4. UPI App Intent Buttons
    container.querySelectorAll('.btn-ps-intent').forEach(btn => {
      btn.addEventListener('click', () => {
        const app = btn.dataset.app;
        const uri = btn.dataset.uri;
        if (!uri) return;

        let targetUrl = uri;
        if (app === 'gpay') {
          targetUrl = uri.replace('upi://pay?', 'gpay://upi/pay?');
        } else if (app === 'phonepe') {
          targetUrl = uri.replace('upi://pay?', 'phonepe://pay?');
        } else if (app === 'paytm') {
          targetUrl = uri.replace('upi://pay?', 'paytmmp://pay?');
        }

        window.location.href = targetUrl;
      });
    });
  },

  /**
   * Generate 1-Tap WhatsApp Payment Link with dynamic UPI details
   */
  generateWhatsAppPaymentLink({ phone = '', studentName = '', amount = 0, dueDate = '', planName = '', paymentType = 'Fee Renewal' } = {}) {
    const p = this.getProfile();
    const cleanPhone = String(phone || '').replace(/[^0-9]/g, '');
    const cleanAmount = parseFloat(amount) || 0;
    const upiUri = this.generateUpiUri({ amount: cleanAmount, note: `${paymentType} - ${studentName}` });

    const message = `Hello *${studentName || 'Student'}*,\n\nThis is a gentle payment reminder from *${p.businessName}*.\n\n` +
      `📋 *Payment Details:*\n` +
      `• *Type:* ${paymentType} ${planName ? `(${planName})` : ''}\n` +
      `• *Payable Amount:* ₹${cleanAmount.toLocaleString('en-IN')}\n` +
      (dueDate ? `• *Due Date:* ${dueDate}\n` : '') +
      `• *Official UPI ID:* \`${p.upiId}\`\n\n` +
      `⚡ *1-Tap Pay via UPI Link:*\n${upiUri}\n\n` +
      `After payment, please reply with your 12-digit UTR number or screenshot to confirm.\n\nThank you! 🙏`;

    return `https://wa.me/${cleanPhone ? (cleanPhone.startsWith('91') ? cleanPhone : '91' + cleanPhone) : ''}?text=${encodeURIComponent(message)}`;
  }
};

export default PaymentStudio;
