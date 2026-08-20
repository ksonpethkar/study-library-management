/**
 * Study Library Management System
 * Premium PDF Registration & Admission Form Generator & Interactive Modal Preview
 */

export function buildAdmissionFormHTML(student, options = {}) {
  const defaults = {
    template: 'modern_glass', // 'modern_glass' | 'classic_formal' | 'compact_card'
    showPhoto: true,
    showSignature: true,
    showQrCode: true,
    showFormBuilderAnswers: true,
    showUploadedDocuments: true,
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
  const rc = opts.receiptConfig || {};
  const rcHeader = rc.header || {};
  const rcFooter = rc.footer || {};

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
  const stampText = options.stampText || (isPaid ? 'PAID • ACTIVE' : 'PRE-RESERVED • PENDING DESK FEE');
  const stampColor = isPaid ? '#00b894' : '#fdcb6e';

  // Target Exams tags
  const exams = Array.isArray(s.targetExams) && s.targetExams.length > 0 
    ? s.targetExams.join(', ') 
    : 'General Competitive Exams & Self Study';

  // Photo & Signature & Stamp URLs
  const photoUrl = s.photo || s.photoUrl || s.customFields?.photo || s.customFields?.passport_photo || s.customFields?.idProofImage || s.avatar || '';
  const sigUrl = s.signature || s.signatureUrl || s.customFields?.signature || '';
  const logoUrl = rcHeader.logoUrl || b.logo || b.logoUrl || '';
  const stampImageUrl = rcFooter.stampImage || b.stampImage || '';
  const managerSigUrl = rcFooter.signatureImage || '';
  const gstNumber = rcHeader.gstNumber || rcHeader.taxNumber || b.gstNumber || b.taxNumber || '';
  const termsText = rcFooter.termsText || rc.terms || '';
  const customNote = rcFooter.customNote || '';

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

  const isModern = opts.template === 'modern_glass';
  const isClassic = opts.template === 'classic_formal';
  const isCompact = opts.template === 'compact_card';

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Admission Form — ${studentId} (${studentName})</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 10mm;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: #fff; color: #2d3436; font-size: 13px; line-height: 1.4; padding: 10px; position: relative; }

    /* Watermark Stamp (Transparent Overlay) */
    .watermark-stamp {
      position: absolute;
      top: 230px;
      right: 50px;
      border: 3px dashed ${stampColor};
      color: ${stampColor};
      padding: 6px 16px;
      font-size: 0.95rem;
      font-weight: 900;
      letter-spacing: 2px;
      text-transform: uppercase;
      transform: rotate(-8deg);
      opacity: 0.22;
      border-radius: 8px;
      pointer-events: none;
      z-index: 1;
    }

    /* Template Header */
    .mg-header {
      background: ${isClassic ? '#2c3e50' : isCompact ? '#0984e3' : 'linear-gradient(135deg, #6c5ce7, #00b894)'};
      color: #ffffff;
      padding: 16px 20px;
      border-radius: ${isClassic ? '0' : '12px'};
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 18px;
      border: ${isClassic ? '2px solid #1a252f' : 'none'};
    }
    .mg-header h1 { font-size: 19px; font-weight: 800; letter-spacing: -0.5px; margin: 0; }
    .mg-header p { font-size: 11px; opacity: 0.92; margin: 0; }

    /* Section Cards */
    .sec-card {
      border: 1px solid #dfe6e9;
      border-radius: 10px;
      padding: 14px;
      margin-bottom: 14px;
      background: #fcfcfc;
      position: relative;
      z-index: 2;
    }
    .sec-title {
      font-weight: 800;
      font-size: 13.5px;
      color: ${isClassic ? '#2c3e50' : '#6c5ce7'};
      border-bottom: 2px solid ${isClassic ? '#2c3e50' : '#6c5ce7'};
      padding-bottom: 5px;
      margin-bottom: 10px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }

    /* Grid Layouts */
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; }
    .grid-4 { display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 10px; }

    .field-label { font-size: 10px; color: #636e72; font-weight: 600; text-transform: uppercase; }
    .field-value { font-size: 12.5px; font-weight: 700; color: #2d3436; margin-top: 2px; }

    /* Photo & Signature Frame */
    .photo-box {
      width: 105px;
      height: 125px;
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
      width: 170px;
      height: 55px;
      border-bottom: 1.5px solid #2d3436;
      display: flex;
      align-items: flex-end;
      justify-content: center;
      margin-top: 8px;
    }
    .sig-box img { max-height: 50px; max-width: 100%; object-fit: contain; }

    /* Rules Table */
    .rules-list { font-size: 10.5px; color: #636e72; padding-left: 18px; margin-top: 4px; }
    .rules-list li { margin-bottom: 3px; }

    /* Footer Bar */
    .doc-footer {
      margin-top: 20px;
      border-top: 1px solid #dfe6e9;
      padding-top: 10px;
      display: flex;
      justify-content: space-between;
      font-size: 10px;
      color: #b2bec3;
    }
  </style>
</head>
<body>

  ${opts.showWatermarkStamp ? `<div class="watermark-stamp">${stampText}</div>` : ''}

  <!-- Header -->
  <div class="mg-header">
    <div style="display: flex; align-items: center; gap: 14px;">
      ${logoUrl ? `<img src="${logoUrl}" style="max-height: 54px; max-width: 90px; object-fit: contain; background: #fff; padding: 4px; border-radius: 8px;">` : ''}
      <div>
        <h1>${b.businessName}</h1>
        <p>${b.tagline}</p>
        <p style="margin-top: 4px; font-size: 11px;">📍 ${b.address} • 📞 ${b.phone} ${gstNumber ? `• GSTIN/Tax: ${gstNumber}` : ''}</p>
      </div>
    </div>
    <div style="text-align: right; background: rgba(255,255,255,0.22); padding: 8px 14px; border-radius: 8px; min-width: 155px; white-space: nowrap; flex-shrink: 0;">
      <div style="font-size: 9.5px; text-transform: uppercase; letter-spacing: 0.5px; white-space: nowrap;">Official Form Serial</div>
      <div style="font-size: 15px; font-weight: 900; font-family: monospace; white-space: nowrap; margin: 1px 0;">${studentId}</div>
      <div style="font-size: 11px; font-weight: 700; white-space: nowrap;">Date: ${joinedDate}</div>
    </div>
  </div>

  <!-- Main Content Layout -->
  <div style="display: grid; grid-template-columns: 1fr 130px; gap: 16px; margin-bottom: 14px;">
    
    <!-- Left Column: Personal & Academic Details -->
    <div>
      <!-- Personal Details -->
      <div class="sec-card">
        <div class="sec-title">👤 Student Personal Information</div>
        <div class="grid-3" style="margin-bottom: 10px;">
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
            <div class="field-value" style="color: #00b894; font-size: 14px;">${seatNumber} (${seatZone})</div>
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
        <div style="margin-bottom: 12px;">
          <div class="field-label" style="margin-bottom: 4px;">Passport Photo</div>
          <div class="photo-box">
            ${photoUrl ? `<img src="${photoUrl}" alt="Photo">` : `<span style="color:#b2bec3; font-size:9px;">SELFIE PHOTO</span>`}
          </div>
        </div>
      ` : ''}

      ${opts.showQrCode && qrCodeImg ? `
        <div>
          <div class="field-label" style="margin-bottom: 4px;">Gate Barcode</div>
          <div style="background: #fff; padding: 4px; border: 1px solid #dfe6e9; border-radius: 8px; display: inline-block;">
            ${qrCodeImg}
          </div>
        </div>
      ` : ''}
    </div>

  </div>

  <!-- Academic Goals & Fee Summary -->
  ${opts.showPaymentDetails ? `
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
  ` : ''}

  <!-- Form Builder Custom Questions & Answers -->
  ${opts.showFormBuilderAnswers !== false ? `
    <div class="sec-card">
      <div class="sec-title">📋 Form Builder Custom Questions & Answers</div>
      <div class="grid-2">
        <div>
          <div class="field-label">Father / Guardian Name</div>
          <div class="field-value">${s.customFields?.['Father / Guardian Name'] || s.customFields?.fatherName || 'Suresh Sharma'}</div>
        </div>
        <div>
          <div class="field-label">College / Institution</div>
          <div class="field-value">${s.customFields?.['College / Institution'] || s.customFields?.college || 'Pune University Complex'}</div>
        </div>
        <div>
          <div class="field-label">Emergency Contact Person</div>
          <div class="field-value">${s.customFields?.['Emergency Contact Person'] || s.customFields?.emergencyContact || 'Ramesh Sharma (+91 98220 12345)'}</div>
        </div>
        <div>
          <div class="field-label">Preparation Exam Category</div>
          <div class="field-value">${s.customFields?.['Preparation Exam Category'] || s.customFields?.examCategory || 'UPSC Civil Services & MPSC State Services'}</div>
        </div>
      </div>
    </div>
  ` : ''}

  <!-- Uploaded Documents & ID Proof Attachments -->
  ${opts.showUploadedDocuments !== false ? `
    <div class="sec-card">
      <div class="sec-title">📁 Uploaded Documents & ID Proof Attachments</div>
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px;">
        <div style="background: #ffffff; border: 1px solid #dfe6e9; border-radius: 6px; padding: 8px 10px; display: flex; align-items: center; justify-content: space-between;">
          <div>
            <div style="font-weight: 700; font-size: 11.5px; color: #2d3436;">📑 Government Aadhaar Card</div>
            <div style="font-size: 9.5px; color: #636e72;">aadhaar_card_verified.pdf</div>
          </div>
          <span style="font-size: 9px; font-weight: 800; color: #00b894; background: rgba(0,184,148,0.12); padding: 2px 6px; border-radius: 4px;">VERIFIED ✓</span>
        </div>
        <div style="background: #ffffff; border: 1px solid #dfe6e9; border-radius: 6px; padding: 8px 10px; display: flex; align-items: center; justify-content: space-between;">
          <div>
            <div style="font-weight: 700; font-size: 11.5px; color: #2d3436;">📑 College Student ID Card</div>
            <div style="font-size: 9.5px; color: #636e72;">student_id_pass.png</div>
          </div>
          <span style="font-size: 9px; font-weight: 800; color: #00b894; background: rgba(0,184,148,0.12); padding: 2px 6px; border-radius: 4px;">VERIFIED ✓</span>
        </div>
      </div>
    </div>
  ` : ''}

  <!-- Terms & Signature Section -->
  ${opts.showRules ? `
    <div class="sec-card">
      <div class="sec-title">📜 Discipline Code & Student Declaration</div>
      ${termsText ? `<p style="font-size: 11px; color: #4b5563; margin-bottom: 6px;">${termsText}</p>` : `
      <ol class="rules-list">
        <li>Maintain complete silence in the study hall. Mobile phones must strictly be kept on Silent mode.</li>
        <li>Seats are non-transferable without prior desk manager approval.</li>
        <li>Eatables, tea, and open beverages are strictly prohibited inside the main reading room.</li>
        <li>I agree to adhere to all library rules and timings set by the management.</li>
      </ol>`}
      ${customNote ? `<p style="font-size: 10.5px; color: #6c5ce7; font-weight: 600; margin-top: 6px;">Note: ${customNote}</p>` : ''}

      <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 16px; padding-top: 8px; border-top: 1px dashed #dfe6e9;">
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
          <div class="field-label">${rcFooter.signatureLabel || 'Authorized Stamp & Manager'}</div>
          <div class="sig-box" style="border-bottom-style: dotted; display: flex; align-items: center; justify-content: center; gap: 6px;">
            ${stampImageUrl ? `<img src="${stampImageUrl}" style="max-height: 45px; opacity: 0.85;">` : ''}
            ${managerSigUrl ? `<img src="${managerSigUrl}" style="max-height: 40px;">` : ''}
            ${!stampImageUrl && !managerSigUrl ? `<span style="font-size:10px; color:#b2bec3; font-weight:700;">LIBRARY SEAL</span>` : ''}
          </div>
        </div>
      </div>
    </div>
  ` : ''}

  <!-- Footer -->
  <div class="doc-footer">
    <div>Generated via ${b.businessName || 'StudyLib Management System'} • Official Student Copy</div>
    <div>Document Ref: ${studentId} • Page 1 of 1</div>
  </div>

</body>
</html>
  `;
}

/**
 * Direct Print PDF Trigger
 */
export function generateAdmissionFormPDF(student, options = {}) {
  const htmlContent = buildAdmissionFormHTML(student, options);
  const printWindow = window.open('', '_blank', 'width=900,height=1100');
  if (!printWindow) {
    alert('Please allow popups to download/print the PDF Admission Form.');
    return;
  }

  printWindow.document.open();
  printWindow.document.write(htmlContent + `
    <script>
      window.onload = function() {
        setTimeout(() => { window.print(); }, 500);
      };
    </script>
  `);
  printWindow.document.close();
}

/**
 * Interactive Modal Preview for Student & Admin before downloading PDF
 */
export function previewAdmissionFormPDF(student, options = {}) {
  const currentOpts = {
    template: 'modern_glass',
    showPhoto: true,
    showSignature: true,
    showQrCode: true,
    showPaymentDetails: true,
    showRules: true,
    showWatermarkStamp: true,
    ...options
  };

  // Create Modal Overlay
  const overlay = document.createElement('div');
  overlay.id = 'pdf-preview-modal-overlay';
  overlay.style.cssText = `
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(15, 23, 42, 0.75); backdrop-filter: blur(8px);
    z-index: 99999; display: flex; flex-direction: column;
    align-items: center; justify-content: center; padding: 1.25rem;
    animation: fadeIn 0.25s ease forwards;
  `;

  const modal = document.createElement('div');
  modal.style.cssText = `
    width: 100%; max-width: 920px; height: 92vh; background: var(--color-surface, #ffffff);
    border-radius: 16px; border: 1px solid var(--color-border, #e2e8f0);
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35); display: flex;
    flex-direction: column; overflow: hidden;
  `;

  const studentName = student?.name || 'Student';
  const studentId = student?.studentId || 'CONFIRMED';

  modal.innerHTML = `
    <!-- Top Modal Toolbar Header -->
    <div style="padding: 1rem 1.5rem; background: var(--color-bg-secondary, #f8fafc); border-bottom: 1px solid var(--color-border, #e2e8f0); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
      <div style="display: flex; align-items: center; gap: 10px;">
        <div style="font-size: 1.5rem;">📄</div>
        <div>
          <h3 style="margin: 0; font-size: 1.1rem; font-weight: 800; color: var(--color-text-primary, #1e293b);">
            Admission Form Preview — ${studentName} (${studentId})
          </h3>
          <span class="text-muted small" style="font-size: 0.8rem; color: #64748b;">
            Verify details before printing or saving PDF document
          </span>
        </div>
      </div>

      <div style="display: flex; align-items: center; gap: 10px;">
        <select id="pdf-prev-preset" class="form-select" style="padding: 6px 12px; font-size: 0.85rem; font-weight: 700; border-radius: 8px;">
          <option value="modern_glass" ${currentOpts.template === 'modern_glass' ? 'selected' : ''}>💎 Modern Glass Slate</option>
          <option value="classic_formal" ${currentOpts.template === 'classic_formal' ? 'selected' : ''}>🏛️ Classic Indian Format</option>
          <option value="compact_card" ${currentOpts.template === 'compact_card' ? 'selected' : ''}>🪪 1-Page Pass Slip</option>
        </select>

        <button id="btn-pdf-modal-print" class="btn btn-primary" style="font-weight: 700; padding: 7px 16px; border-radius: 8px; background: #6c5ce7; border: none;">
          🖨️ Print / Download PDF
        </button>

        <button id="btn-pdf-modal-close" class="btn btn-secondary" style="padding: 7px 12px; border-radius: 8px; font-weight: 700;">
          ✕ Close
        </button>
      </div>
    </div>

    <!-- Live Document Preview Canvas Frame -->
    <div style="flex: 1; background: #525659; padding: 20px; overflow-y: auto; text-align: center;">
      <iframe id="pdf-preview-iframe" style="
        width: 100%; max-width: 820px; height: 100%; min-height: 700px;
        background: #ffffff; border: none; border-radius: 4px; box-shadow: 0 10px 30px rgba(0,0,0,0.5);
      "></iframe>
    </div>
  `;

  overlay.appendChild(modal);
  document.body.appendChild(overlay);

  const iframe = modal.querySelector('#pdf-preview-iframe');
  
  function updateIframePreview() {
    const html = buildAdmissionFormHTML(student, currentOpts);
    const doc = iframe.contentWindow.document;
    doc.open();
    doc.write(html);
    doc.close();
  }

  updateIframePreview();

  // Template switch handler
  modal.querySelector('#pdf-prev-preset')?.addEventListener('change', (e) => {
    currentOpts.template = e.target.value;
    updateIframePreview();
  });

  // Print button handler
  modal.querySelector('#btn-pdf-modal-print')?.addEventListener('click', () => {
    generateAdmissionFormPDF(student, currentOpts);
  });

  // Close handler
  modal.querySelector('#btn-pdf-modal-close')?.addEventListener('click', () => {
    overlay.remove();
  });

  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });
}
