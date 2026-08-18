/**
 * Study Library Management System
 * Premium PDF Registration & Admission Form Generator
 * Supports multiple templates: Modern Glass, Classic Formal, Compact Pass
 */

export function generateAdmissionFormPDF(student, options = {}) {
  const defaults = {
    template: 'modern_glass', // 'modern_glass' | 'classic_formal' | 'compact_card'
    showPhoto: true,
    showSignature: true,
    showQrCode: true,
    showPaymentDetails: true,
    showRules: true,
    showWatermarkStamp: true,
    business: {
      businessName: 'Study Library & Reading Hall',
      tagline: 'Silent Study Environment & Digital Library',
      address: 'Central Campus Complex, Pune, Maharashtra',
      phone: '+91 9876543210',
      email: 'contact@studylib.com'
    }
  };

  const opts = { ...defaults, ...options };
  const s = student || {};
  const b = opts.business || defaults.business;

  const studentId = s.studentId || 'STU-2026-0001';
  const studentName = s.name || 'Student Name';
  const phone = s.phone || 'N/A';
  const email = s.email || 'N/A';
  const gender = (s.gender || 'Other').toUpperCase();
  const dob = s.dateOfBirth || s.dob ? new Date(s.dateOfBirth || s.dob).toLocaleDateString('en-IN') : 'N/A';
  const pincode = s.pincode || 'N/A';
  const city = s.city || 'N/A';
  const state = s.state || 'N/A';

  const branchName = s.branch?.name || s.branchName || 'Main Centre';
  const planName = s.plan?.name || s.planName || 'Standard Membership Plan';
  const shiftName = (s.plan?.shift || s.shift || 'ALL DAY').toUpperCase();
  const seatNumber = s.seat?.seatNumber || s.seatNumber || 'Floating Desk';
  const seatZone = s.seat?.zone || s.seatZone || 'General Reading Zone';

  const joinedDate = s.joinedDate ? new Date(s.joinedDate).toLocaleDateString('en-IN') : new Date().toLocaleDateString('en-IN');
  const expiryDate = s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : 'N/A';
  const status = (s.status || 'active').toUpperCase();

  const isPaid = status === 'ACTIVE' || status === 'PAID';
  const stampText = isPaid ? 'PAID • ACTIVE' : 'PRE-RESERVED • PENDING DESK FEE';
  const stampColor = isPaid ? '#00b894' : '#fdcb6e';

  // Target Exams tags
  const exams = Array.isArray(s.targetExams) && s.targetExams.length > 0 
    ? s.targetExams.join(', ') 
    : 'General Competitive Exams & Self Study';

  // Photo & Signature URLs
  const photoUrl = s.photo || s.photoUrl || '';
  const sigUrl = s.signature || s.signatureUrl || '';

  // Generate QR Code SVG / Image URL
  let qrCodeImg = '';
  if (opts.showQrCode && typeof qrcode !== 'undefined') {
    try {
      const qr = qrcode(0, 'M');
      qr.addData(studentId);
      qr.make();
      qrCodeImg = qr.createImgTag(4, 0);
    } catch (e) {}
  }

  // Create printable iframe or container
  const printWindow = window.open('', '_blank', 'width=900,height=1100');
  if (!printWindow) {
    alert('Please allow popups to download/print the PDF Admission Form.');
    return;
  }

  const isModern = opts.template === 'modern_glass';
  const isClassic = opts.template === 'classic_formal';
  const isCompact = opts.template === 'compact_card';

  const htmlContent = `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Admission Form — ${studentId} (${studentName})</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 12mm;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: #fff; color: #2d3436; font-size: 13px; line-height: 1.4; padding: 10px; }

    /* Watermark Stamp */
    .watermark-stamp {
      position: absolute;
      top: 240px;
      right: 40px;
      border: 3px dashed ${stampColor};
      color: ${stampColor};
      padding: 8px 18px;
      font-size: 1rem;
      font-weight: 900;
      letter-spacing: 2px;
      text-transform: uppercase;
      transform: rotate(-12deg);
      opacity: 0.85;
      border-radius: 8px;
      pointer-events: none;
    }

    /* Template 1: Modern Glass */
    .mg-header {
      background: linear-gradient(135deg, #6c5ce7, #00b894);
      color: #ffffff;
      padding: 24px;
      border-radius: 12px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 20px;
    }
    .mg-header h1 { font-size: 22px; font-weight: 800; letter-spacing: -0.5px; }
    .mg-header p { font-size: 12px; opacity: 0.9; }

    /* Section Cards */
    .sec-card {
      border: 1px solid #dfe6e9;
      border-radius: 10px;
      padding: 16px;
      margin-bottom: 16px;
      background: #fcfcfc;
    }
    .sec-title {
      font-weight: 800;
      font-size: 14px;
      color: #6c5ce7;
      border-bottom: 2px solid #6c5ce7;
      padding-bottom: 6px;
      margin-bottom: 12px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    /* Grid Layouts */
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; }
    .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; }
    .grid-4 { display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 12px; }

    .field-label { font-size: 10.5px; color: #636e72; font-weight: 600; text-transform: uppercase; }
    .field-value { font-size: 13px; font-weight: 700; color: #2d3436; margin-top: 2px; }

    /* Photo & Signature Frame */
    .photo-box {
      width: 110px;
      height: 130px;
      border: 2px dashed #b2bec3;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #f1f2f6;
      overflow: hidden;
      margin: 0 auto;
    }
    .photo-box img { width: 100%; height: 100%; object-fit: cover; }

    .sig-box {
      width: 180px;
      height: 60px;
      border-bottom: 1.5px solid #2d3436;
      display: flex;
      align-items: flex-end;
      justify-content: center;
      margin-top: 10px;
    }
    .sig-box img { max-height: 55px; max-width: 100%; object-fit: contain; }

    /* Rules Table */
    .rules-list { font-size: 11px; color: #636e72; padding-left: 18px; margin-top: 6px; }
    .rules-list li { margin-bottom: 4px; }

    /* Footer Bar */
    .doc-footer {
      margin-top: 25px;
      border-top: 1px solid #dfe6e9;
      padding-top: 12px;
      display: flex;
      justify-content: space-between;
      font-size: 10.5px;
      color: #b2bec3;
    }
  </style>
</head>
<body>

  ${opts.showWatermarkStamp ? `<div class="watermark-stamp">${stampText}</div>` : ''}

  <!-- Header -->
  <div class="mg-header">
    <div>
      <h1>${b.businessName}</h1>
      <p>${b.tagline}</p>
      <p style="margin-top: 4px; font-size: 11px;">📍 ${b.address} • 📞 ${b.phone}</p>
    </div>
    <div style="text-align: right; background: rgba(255,255,255,0.2); padding: 8px 14px; border-radius: 8px;">
      <div style="font-size: 10px; text-transform: uppercase;">Official Form Serial</div>
      <div style="font-size: 16px; font-weight: 900; font-family: monospace;">${studentId}</div>
      <div style="font-size: 11px; font-weight: 700;">Date: ${joinedDate}</div>
    </div>
  </div>

  <!-- Main Content Layout -->
  <div style="display: grid; grid-template-columns: 1fr 140px; gap: 20px; margin-bottom: 16px;">
    
    <!-- Left Column: Personal & Academic Details -->
    <div>
      <!-- Personal Details -->
      <div class="sec-card">
        <div class="sec-title">👤 Student Personal Information</div>
        <div class="grid-3 mb-3" style="margin-bottom: 10px;">
          <div>
            <div class="field-label">Full Name</div>
            <div class="field-value">${studentName}</div>
          </div>
          <div>
            <div class="field-label">Mobile Phone</div>
            <div class="field-value">${phone}</div>
          </div>
          <div>
            <div class="field-label">Email Address</div>
            <div class="field-value">${email}</div>
          </div>
        </div>

        <div class="grid-4">
          <div>
            <div class="field-label">Gender</div>
            <div class="field-value">${gender}</div>
          </div>
          <div>
            <div class="field-label">Date of Birth</div>
            <div class="field-value">${dob}</div>
          </div>
          <div>
            <div class="field-label">City & Pincode</div>
            <div class="field-value">${city} (${pincode})</div>
          </div>
          <div>
            <div class="field-label">State</div>
            <div class="field-value">${state}</div>
          </div>
        </div>
      </div>

      <!-- Membership & Seat Allocation -->
      <div class="sec-card">
        <div class="sec-title">🏢 Study Centre & Seat Allocation</div>
        <div class="grid-3" style="margin-bottom: 10px;">
          <div>
            <div class="field-label">Study Centre / Branch</div>
            <div class="field-value" style="color: #6c5ce7;">${branchName}</div>
          </div>
          <div>
            <div class="field-label">Assigned Seat Number</div>
            <div class="field-value" style="color: #00b894; font-size: 15px;">${seatNumber} (${seatZone})</div>
          </div>
          <div>
            <div class="field-label">Study Shift Timing</div>
            <div class="field-value">${shiftName}</div>
          </div>
        </div>

        <div class="grid-3">
          <div>
            <div class="field-label">Membership Plan</div>
            <div class="field-value">${planName}</div>
          </div>
          <div>
            <div class="field-label">Admission Date</div>
            <div class="field-value">${joinedDate}</div>
          </div>
          <div>
            <div class="field-label">Validity Expiry Date</div>
            <div class="field-value" style="color: #d63031;">${expiryDate}</div>
          </div>
        </div>
      </div>

    </div>

    <!-- Right Column: Passport Photo & QR Code -->
    <div style="text-align: center;">
      ${opts.showPhoto ? `
        <div style="margin-bottom: 14px;">
          <div class="field-label mb-1">Passport Photo</div>
          <div class="photo-box">
            ${photoUrl ? `<img src="${photoUrl}" alt="Photo">` : `<span style="color:#b2bec3; font-size:10px;">SELFIE PHOTO</span>`}
          </div>
        </div>
      ` : ''}

      ${opts.showQrCode && qrCodeImg ? `
        <div>
          <div class="field-label mb-1">Gate Entry Barcode</div>
          <div style="background: #fff; padding: 6px; border: 1px solid #dfe6e9; border-radius: 8px; display: inline-block;">
            ${qrCodeImg}
          </div>
        </div>
      ` : ''}
    </div>

  </div>

  <!-- Academic Goals & Fee Summary -->
  <div class="sec-card">
    <div class="sec-title">🎯 Target Exams & Fee Settlement Summary</div>
    <div class="grid-3">
      <div>
        <div class="field-label">Target Competitive Exams</div>
        <div class="field-value">${exams}</div>
      </div>
      <div>
        <div class="field-label">Payment Mode & Ref</div>
        <div class="field-value">${(s.paymentMethod || 'UPI / Cash').toUpperCase()} ${s.transactionId ? '(' + s.transactionId + ')' : ''}</div>
      </div>
      <div>
        <div class="field-label">Membership Status</div>
        <div class="field-value" style="color: ${isPaid ? '#00b894' : '#fdcb6e'};">${status}</div>
      </div>
    </div>
  </div>

  <!-- Terms & Signature Section -->
  ${opts.showRules ? `
    <div class="sec-card">
      <div class="sec-title">📜 Discipline Code & Student Declaration</div>
      <ol class="rules-list">
        <li>Maintain complete silence in the study hall. Mobile phones must strictly be kept on Silent mode.</li>
        <li>Seats are non-transferable without prior desk manager approval.</li>
        <li>Eatables, tea, and open beverages are strictly prohibited inside the main reading room.</li>
        <li>I agree to adhere to all library rules and timings set by the management.</li>
      </ol>

      <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 25px; padding-top: 10px; border-top: 1px dashed #dfe6e9;">
        <div>
          <div class="field-label">Date & Place</div>
          <div class="field-value">${joinedDate} • ${city}</div>
        </div>

        ${opts.showSignature ? `
          <div style="text-align: center;">
            <div class="field-label">Student Digital Signature</div>
            <div class="sig-box">
              ${sigUrl ? `<img src="${sigUrl}" alt="Signature">` : `<span style="font-family:'Courier New', monospace; font-size:12px;">${studentName}</span>`}
            </div>
          </div>
        ` : ''}

        <div style="text-align: center;">
          <div class="field-label">Authorized Stamp & Manager</div>
          <div class="sig-box" style="border-bottom-style: dotted;">
            <span style="font-size:11px; color:#b2bec3; font-weight:700;">LIBRARY SEAL</span>
          </div>
        </div>
      </div>
    </div>
  ` : ''}

  <!-- Footer -->
  <div class="doc-footer">
    <div>Generated via StudyLib Management System • Official Student Copy</div>
    <div>Document Ref: ${studentId} • Page 1 of 1</div>
  </div>

  <script>
    window.onload = function() {
      setTimeout(() => {
        window.print();
      }, 500);
    };
  </script>
</body>
</html>
  `;

  printWindow.document.open();
  printWindow.document.write(htmlContent);
  printWindow.document.close();
}
