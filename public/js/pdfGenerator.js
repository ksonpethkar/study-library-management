/**
 * Study Library Management System
 * Premium PDF Registration & Admission Form Generator & Interactive Modal Preview
 */

function escapeHTML(str) {
  if (!str) return '';
  return String(str).replace(/[&<>"']/g, m => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }[m]));
}

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
  const b = opts.business || (window.store?.settings?.businessProfile) || defaults.business;
  const rc = opts.receiptConfig || (window.store?.settings?.receipt) || {};
  const rcHeader = rc.header || {};
  const rcFooter = rc.footer || {};

  const studentId = s.studentId || 'STU-2026-0001';
  const studentName = s.name || 'Student Name';
  const phone = s.phone || 'N/A';
  const email = s.email || 'N/A';
  const gender = (s.gender || 'Other').toUpperCase();
  const dob = s.dateOfBirth || s.dob ? new Date(s.dateOfBirth || s.dob).toLocaleDateString('en-IN') : 'N/A';
  const bloodGroup = s.bloodGroup || s.customFields?.bloodGroup || s.customFields?.blood_group || '';
  const pincode = s.pincode || 'N/A';
  const city = s.city || 'N/A';
  const state = s.state || 'N/A';
  const fullAddress = s.address || s.customFields?.address || '';
  const occupation = s.occupation || s.collegeOrCompany || s.customFields?.occupation || s.customFields?.college || '';

  const branchName = s.branch?.name || s.branchName || 'Main Branch';
  const planName = s.plan?.name || s.planName || 'Standard Study Membership';
  const shiftName = (s.shift?.name || s.plan?.shift || s.shift || 'FULL DAY').toUpperCase();
  const seatNumber = s.seat?.seatNumber || s.seatNumber || 'Floating Desk';
  const seatZone = s.seat?.zone || s.seatZone || 'General Zone';

  const joinedDate = s.admissionDate || s.joinedDate || s.createdAt 
    ? new Date(s.admissionDate || s.joinedDate || s.createdAt).toLocaleDateString('en-IN') 
    : new Date().toLocaleDateString('en-IN');
  const expiryDate = s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : 'N/A';
  const status = (s.status || 'active').toUpperCase();

  const isPaid = status === 'ACTIVE' || status === 'PAID';
  const stampText = options.stampText || (isPaid ? 'PAID & VERIFIED' : 'PROVISIONAL ADMISSION');
  const stampColor = isPaid ? '#059669' : '#d97706';

  // Target Competitive Exams
  let targetExamsList = [];
  if (Array.isArray(s.targetExams) && s.targetExams.length > 0) {
    targetExamsList = s.targetExams;
  } else if (typeof s.targetExams === 'string' && s.targetExams.trim()) {
    targetExamsList = s.targetExams.split(',').map(x => x.trim()).filter(Boolean);
  } else if (s.customFields?.targetExams || s.customFields?.target_exams || s.customFields?.competitive_exams) {
    const raw = s.customFields.targetExams || s.customFields.target_exams || s.customFields.competitive_exams;
    targetExamsList = Array.isArray(raw) ? raw : String(raw).split(',').map(x => x.trim()).filter(Boolean);
  }

  // Emergency / Guardian Contacts
  const emergencyName = s.emergencyContact?.name || s.emergencyContactName || s.customFields?.['Emergency Contact Name'] || s.customFields?.['Father / Guardian Name'] || s.customFields?.fatherName || '';
  const emergencyPhone = s.emergencyContact?.phone || s.emergencyContactPhone || s.customFields?.['Emergency Contact Phone'] || s.customFields?.['Parent Phone'] || '';
  const emergencyRelation = s.emergencyContact?.relation || s.emergencyContactRelation || s.customFields?.['Relation'] || 'Parent / Guardian';

  // Government ID Proof & KYC Details
  const idProofType = s.idProof?.type || s.idProofType || s.customFields?.idProofType || 'Aadhaar Card';
  const idProofNumber = s.idProof?.number || s.idProofNumber || s.customFields?.idProofNumber || '';
  const idProofImage = s.idProof?.image || s.idProofImage || s.customFields?.idProofImage || s.customFields?.idProof || '';

  // Form Builder Custom Fields Extraction (Exclude core fields)
  const customEntries = [];
  const coreExcluded = new Set([
    'name', 'phone', 'email', 'gender', 'dob', 'dateofbirth', 'photo', 'signature', 'seat', 'plan', 'status',
    'idproofimage', 'idproof', 'idprooftype', 'idproofnumber', 'targetexams', 'target_exams', 'competitive_exams',
    'address', 'city', 'state', 'pincode', 'bloodgroup', 'blood_group', 'emergencycontact', 'emergencycontactname',
    'emergencycontactphone', 'emergencycontactrelation', 'parentphone', 'fathername', 'rfidcardnumber', 'biometricid'
  ]);

  if (s.customFields) {
    if (s.customFields instanceof Map) {
      for (const [k, v] of s.customFields.entries()) {
        const cleanKey = k.toLowerCase().replace(/[^a-z0-9]/g, '');
        if (!coreExcluded.has(cleanKey) && v !== undefined && v !== null && v !== '') {
          customEntries.push({ label: k, value: typeof v === 'boolean' ? (v ? 'Yes' : 'No') : String(v) });
        }
      }
    } else if (typeof s.customFields === 'object') {
      for (const [k, v] of Object.entries(s.customFields)) {
        const cleanKey = k.toLowerCase().replace(/[^a-z0-9]/g, '');
        if (!coreExcluded.has(cleanKey) && v !== undefined && v !== null && v !== '') {
          customEntries.push({ label: k, value: typeof v === 'boolean' ? (v ? 'Yes' : 'No') : String(v) });
        }
      }
    }
  }

  // Photo & Signature & Stamp URLs
  const photoUrl = s.photo || s.photoUrl || s.customFields?.photo || s.customFields?.passport_photo || s.avatar || '';
  const sigUrl = s.signature || s.signatureUrl || s.customFields?.signature || '';
  const logoUrl = rcHeader.logoUrl || b.logo || b.logoUrl || '';
  const stampImageUrl = rcFooter.stampImage || b.stampImage || '';
  const managerSigUrl = rcFooter.signatureImage || '';
  const gstNumber = rcHeader.gstNumber || rcHeader.taxNumber || b.gstNumber || b.taxNumber || '';
  const termsText = rcFooter.termsText || rc.terms || b.rules || '';
  const customNote = rcFooter.customNote || '';

  // Generate QR Code SVG / Image URL
  let qrCodeImg = '';
  if (opts.showQrCode) {
    if (typeof qrcode !== 'undefined') {
      try {
        const qr = qrcode(0, 'M');
        qr.addData(studentId);
        qr.make();
        qrCodeImg = qr.createImgTag(3.2, 0);
      } catch (e) {}
    }
    if (!qrCodeImg) {
      const upiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=110x110&data=${encodeURIComponent(studentId)}`;
      qrCodeImg = `<img src="${upiUrl}" alt="QR Code" style="width: 90px; height: 90px; object-fit: contain;">`;
    }
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
      margin: 8mm 10mm;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; }
    body { background: #ffffff; color: #1e293b; font-size: 12px; line-height: 1.35; padding: 8px; position: relative; }

    /* Watermark Stamp */
    .watermark-stamp {
      position: absolute;
      top: 260px;
      right: 40px;
      border: 3px dashed ${stampColor};
      color: ${stampColor};
      padding: 6px 14px;
      font-size: 0.90rem;
      font-weight: 900;
      letter-spacing: 2px;
      text-transform: uppercase;
      transform: rotate(-7deg);
      opacity: 0.20;
      border-radius: 8px;
      pointer-events: none;
      z-index: 1;
    }

    /* Template Header */
    .mg-header {
      background: ${isClassic ? '#1e293b' : isCompact ? '#0284c7' : 'linear-gradient(135deg, #4f46e5, #059669)'};
      color: #ffffff;
      padding: 14px 18px;
      border-radius: ${isClassic ? '0' : '10px'};
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 12px;
    }
    .mg-header h1 { font-size: 18px; font-weight: 800; letter-spacing: -0.3px; margin: 0; }
    .mg-header p { font-size: 10.5px; opacity: 0.92; margin: 0; }

    /* Section Cards */
    .sec-card {
      border: 1px solid #e2e8f0;
      border-radius: 8px;
      padding: 10px 12px;
      margin-bottom: 10px;
      background: #f8fafc;
      position: relative;
      z-index: 2;
    }
    .sec-title {
      font-weight: 800;
      font-size: 12.5px;
      color: ${isClassic ? '#1e293b' : '#4f46e5'};
      border-bottom: 2px solid ${isClassic ? '#1e293b' : '#4f46e5'};
      padding-bottom: 4px;
      margin-bottom: 8px;
      text-transform: uppercase;
      letter-spacing: 0.4px;
      display: flex;
      align-items: center;
      gap: 6px;
    }

    /* Grid Layouts */
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
    .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; }
    .grid-4 { display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 8px; }

    .field-label { font-size: 9.5px; color: #64748b; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; }
    .field-value { font-size: 12px; font-weight: 700; color: #0f172a; margin-top: 1px; }

    /* Photo & Signature Frame */
    .photo-frame {
      width: 125px;
      height: 135px;
      border: 1.5px solid #cbd5e1;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #ffffff;
      overflow: hidden;
      margin: 0 auto;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
    }
    .photo-frame img { width: 100%; height: 100%; object-fit: cover; }

    .qr-frame {
      width: 125px;
      border: 1.5px solid #cbd5e1;
      border-radius: 8px;
      background: #ffffff;
      padding: 6px;
      text-align: center;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
    }

    .sig-box {
      width: 160px;
      height: 50px;
      border-bottom: 1.5px solid #334155;
      display: flex;
      align-items: flex-end;
      justify-content: center;
      margin-top: 4px;
    }
    .sig-box img { max-height: 44px; max-width: 100%; object-fit: contain; }

    /* Rules Table */
    .rules-list { font-size: 10px; color: #475569; padding-left: 16px; margin-top: 4px; line-height: 1.4; }
    .rules-list li { margin-bottom: 2px; }

    /* Footer Bar */
    .doc-footer {
      margin-top: 12px;
      border-top: 1px solid #e2e8f0;
      padding-top: 8px;
      display: flex;
      justify-content: space-between;
      font-size: 9.5px;
      color: #94a3b8;
    }

    @media print {
      body { padding: 0; background: #fff !important; }
      .sec-card { background: #fff !important; break-inside: avoid; }
      .mg-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    }
  </style>
</head>
<body>

  ${opts.showWatermarkStamp ? `<div class="watermark-stamp">${stampText}</div>` : ''}

  <!-- Header -->
  <div class="mg-header">
    <div style="display: flex; align-items: center; gap: 12px;">
      ${logoUrl ? `<img src="${logoUrl}" style="max-height: 50px; max-width: 80px; object-fit: contain; background: #fff; padding: 3px; border-radius: 6px;">` : ''}
      <div>
        <h1>${b.businessName}</h1>
        <p>${b.tagline || 'Silent Study Environment & Digital Library'}</p>
        <p style="margin-top: 3px; font-size: 10px;">📍 ${b.address || ''} • 📞 ${b.phone || ''} ${gstNumber ? `• GSTIN: ${gstNumber}` : ''}</p>
      </div>
    </div>
    <div style="text-align: right; background: rgba(255,255,255,0.22); padding: 6px 12px; border-radius: 6px; min-width: 145px; white-space: nowrap; flex-shrink: 0;">
      <div style="font-size: 9px; text-transform: uppercase; letter-spacing: 0.5px;">Official Admission Form</div>
      <div style="font-size: 14px; font-weight: 900; font-family: monospace; margin: 1px 0;">${studentId}</div>
      <div style="font-size: 10px; font-weight: 700;">Date: ${joinedDate}</div>
    </div>
  </div>

  <!-- Top 2-Column Grid: Left: Personal + Seat Info | Right: Photo + QR Code -->
  <div style="display: grid; grid-template-columns: 1fr 135px; gap: 12px; margin-bottom: 8px; align-items: start;">
    
    <!-- Left Column: Personal Information & Seat Allotment -->
    <div style="display: flex; flex-direction: column; gap: 8px;">
      
      <!-- 1. Student Personal Information -->
      <div class="sec-card" style="margin-bottom: 0;">
        <div class="sec-title">👤 Student Personal Information</div>
        
        <div class="grid-3" style="margin-bottom: 8px;">
          <div>
            <div class="field-label">Full Student Name</div>
            <div class="field-value">${studentName}</div>
          </div>
          <div>
            <div class="field-label">Mobile Number</div>
            <div class="field-value">${phone}</div>
          </div>
          <div>
            <div class="field-label">Email Address</div>
            <div class="field-value">${email}</div>
          </div>
        </div>

        <div class="grid-4" style="margin-bottom: 8px;">
          <div>
            <div class="field-label">Gender</div>
            <div class="field-value">${gender}</div>
          </div>
          <div>
            <div class="field-label">Date of Birth</div>
            <div class="field-value">${dob}</div>
          </div>
          <div>
            <div class="field-label">Blood Group</div>
            <div class="field-value">${bloodGroup || 'N/A'}</div>
          </div>
          <div>
            <div class="field-label">City & State</div>
            <div class="field-value">${city}${state && state !== 'N/A' ? ', ' + state : ''}</div>
          </div>
        </div>

        ${fullAddress ? `
          <div style="border-top: 1px dashed #e2e8f0; padding-top: 6px;">
            <div class="field-label">Resident Address</div>
            <div class="field-value" style="font-size: 11px;">${fullAddress}${pincode && pincode !== 'N/A' ? ' (PIN: ' + pincode + ')' : ''}</div>
          </div>
        ` : ''}
      </div>

      <!-- 2. Study Centre & Seat Allocation -->
      <div class="sec-card" style="margin-bottom: 0;">
        <div class="sec-title">🏢 Study Centre & Seat Allocation</div>
        
        <div class="grid-3" style="margin-bottom: 8px;">
          <div>
            <div class="field-label">Study Centre / Branch</div>
            <div class="field-value" style="color: #4f46e5;">${branchName}</div>
          </div>
          <div>
            <div class="field-label">Assigned Desk / Seat</div>
            <div class="field-value" style="color: #059669; font-size: 13px;">${seatNumber} (${seatZone})</div>
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
            <div class="field-value" style="color: #dc2626;">${expiryDate}</div>
          </div>
        </div>
      </div>

    </div>

    <!-- Right Column: Passport Photo & Verification QR Code directly beneath it -->
    <div style="display: flex; flex-direction: column; align-items: center; gap: 8px;">
      
      <!-- Passport Photo Frame -->
      <div style="width: 100%; text-align: center;">
        <div class="field-label" style="margin-bottom: 3px; font-size: 8.5px;">PASSPORT PHOTO</div>
        <div class="photo-frame">
          ${photoUrl ? `<img src="${photoUrl}" alt="Photo">` : `<span style="color:#94a3b8; font-size:9px; font-weight:700;">AFFIX PHOTO</span>`}
        </div>
      </div>

      <!-- Generated Student Verification QR Code -->
      <div style="width: 100%; text-align: center;">
        <div class="field-label" style="margin-bottom: 3px; font-size: 8.5px;">VERIFY ID QR</div>
        <div class="qr-frame" style="margin: 0 auto;">
          <div style="display: flex; align-items: center; justify-content: center;">
            ${qrCodeImg}
          </div>
          <div style="font-size: 8.5px; font-weight: 800; font-family: monospace; color: #475569; margin-top: 2px;">${studentId}</div>
        </div>
      </div>

    </div>

  </div>

  <!-- 3. Academic Goals, Target Competitive Exams & Guardian Contact -->
  <div class="sec-card">
    <div class="sec-title">🎯 Academic Goals, Target Exams & Emergency Contact</div>
    
    <div class="grid-3" style="margin-bottom: 8px;">
      <div>
        <div class="field-label">Target Competitive Exams</div>
        <div class="field-value" style="color: #4f46e5;">
          ${targetExamsList.length > 0 ? targetExamsList.join(', ') : 'General Competitive Exams / Self Study'}
        </div>
      </div>
      <div>
        <div class="field-label">College / Company / Occupation</div>
        <div class="field-value">${occupation || 'Student / Aspirant'}</div>
      </div>
      <div>
        <div class="field-label">Admission Status</div>
        <div class="field-value" style="color: ${isPaid ? '#059669' : '#d97706'}; font-weight: 800;">
          ${status} (${isPaid ? 'CONFIRMED' : 'PENDING'})
        </div>
      </div>
    </div>

    ${emergencyName || emergencyPhone ? `
      <div style="border-top: 1px dashed #e2e8f0; padding-top: 6px;" class="grid-3">
        <div>
          <div class="field-label">Guardian / Parent Name</div>
          <div class="field-value">${emergencyName || 'N/A'}</div>
        </div>
        <div>
          <div class="field-label">Emergency Phone</div>
          <div class="field-value">📞 ${emergencyPhone || 'N/A'}</div>
        </div>
        <div>
          <div class="field-label">Relationship</div>
          <div class="field-value">${emergencyRelation}</div>
        </div>
      </div>
    ` : ''}
  </div>

  <!-- 4. Government KYC & Document Proof Attachments -->
  <div class="sec-card">
    <div class="sec-title">🪪 KYC Verification & Government ID Attachments</div>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; align-items: center;">
      
      <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 8px 10px; display: flex; align-items: center; justify-content: space-between;">
        <div>
          <div style="font-weight: 800; font-size: 11.5px; color: #1e293b;">📑 ${idProofType}</div>
          <div style="font-size: 10px; color: #475569; font-family: monospace; font-weight: 700; margin-top: 2px;">
            ${idProofNumber ? `ID No: ${idProofNumber}` : 'Document Attached on Record'}
          </div>
        </div>
        <span style="font-size: 9px; font-weight: 800; color: #059669; background: #d1fae5; padding: 3px 8px; border-radius: 4px; border: 1px solid #10b981;">
          KYC VERIFIED ✓
        </span>
      </div>

      <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 8px 10px; display: flex; align-items: center; justify-content: space-between;">
        <div>
          <div style="font-weight: 800; font-size: 11.5px; color: #1e293b;">🏛️ Campus ID Allotment</div>
          <div style="font-size: 10px; color: #475569; font-family: monospace; font-weight: 700; margin-top: 2px;">
            RFID / Bio ID: ${s.rfidCardNumber || s.biometricId || studentId}
          </div>
        </div>
        <span style="font-size: 9px; font-weight: 800; color: #4f46e5; background: #e0e7ff; padding: 3px 8px; border-radius: 4px; border: 1px solid #6366f1;">
          ACTIVE ACCESS
        </span>
      </div>

    </div>
  </div>

  <!-- 5. Form Builder Custom Questions & Dynamic Answers (If Any) -->
  ${customEntries.length > 0 ? `
    <div class="sec-card">
      <div class="sec-title">📋 Additional Registration Information</div>
      <div class="grid-2">
        ${customEntries.map(e => `
          <div style="margin-bottom: 4px;">
            <div class="field-label">${escapeHTML(e.label)}</div>
            <div class="field-value" style="font-size: 11.5px;">${escapeHTML(e.value)}</div>
          </div>
        `).join('')}
      </div>
    </div>
  ` : ''}

  <!-- 6. Discipline Code, Terms of Admission & Declaration -->
  ${opts.showRules ? `
    <div class="sec-card">
      <div class="sec-title">📜 Discipline Code & Student Declaration</div>
      ${termsText ? `<div class="rules-list" style="margin-bottom: 6px;">${termsText}</div>` : `
      <ol class="rules-list">
        <li>Maintain complete silence in the study hall. Mobile phones must strictly be kept on Silent mode.</li>
        <li>Seats are reserved for the registered student and non-transferable without prior management approval.</li>
        <li>Eatables, tea, and open beverages are strictly prohibited inside reading rooms.</li>
        <li>I declare that the information provided is accurate and agree to adhere to all library rules and timings.</li>
      </ol>`}
      ${customNote ? `<p style="font-size: 10px; color: #4f46e5; font-weight: 700; margin-top: 4px;">Notice: ${customNote}</p>` : ''}

      <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 10px; padding-top: 8px; border-top: 1px dashed #cbd5e1;">
        <div>
          <div class="field-label">Date & Place</div>
          <div class="field-value">${joinedDate} • ${city !== 'N/A' ? city : 'Pune'}</div>
        </div>

        ${opts.showSignature ? `
          <div style="text-align: center;">
            <div class="field-label">Student Digital Signature</div>
            <div class="sig-box">
              ${sigUrl ? `<img src="${sigUrl}" alt="Signature">` : `<span style="font-family:'Courier New', monospace; font-size:11px; font-weight:700;">${studentName}</span>`}
            </div>
          </div>
        ` : ''}

        <div style="text-align: center;">
          <div class="field-label">${rcFooter.signatureLabel || 'Authorized Seal & Signatory'}</div>
          <div class="sig-box" style="border-bottom-style: dotted; display: flex; align-items: center; justify-content: center; gap: 6px;">
            ${stampImageUrl ? `<img src="${stampImageUrl}" style="max-height: 42px; opacity: 0.85;">` : ''}
            ${managerSigUrl ? `<img src="${managerSigUrl}" style="max-height: 38px;">` : ''}
            ${!stampImageUrl && !managerSigUrl ? `<span style="font-size:9.5px; color:#94a3b8; font-weight:800; border:1px solid #cbd5e1; padding:2px 8px; border-radius:4px;">OFFICIAL SEAL</span>` : ''}
          </div>
        </div>
      </div>
    </div>
  ` : ''}

  <!-- Footer -->
  <div class="doc-footer">
    <div>Generated via ${b.businessName || 'StudyLib Management System'} • Official Admission Copy</div>
    <div>Document Ref: ${studentId} • Verified Student Record</div>
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
