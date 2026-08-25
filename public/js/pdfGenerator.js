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
    showWatermarkStamp: true
  };

  const opts = { ...defaults, ...options };
  const s = student || {};

  // Dynamically resolve organization / business profile with zero hardcoding
  let cachedProfile = {};
  if (typeof localStorage !== 'undefined') {
    try {
      cachedProfile = JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}');
    } catch (e) {}
  }

  const sysBiz = (typeof window !== 'undefined' ? (window.store?.settings?.businessProfile || window.store?.profile) : null) || cachedProfile || {};
  const passedBiz = (options.business && (options.business.businessName || options.business.name)) ? options.business : null;
  const activeBiz = passedBiz || sysBiz;

  const b = {
    businessName: activeBiz.businessName || activeBiz.name || 'The Cozy Corner Centre',
    tagline: activeBiz.tagline || 'Silence, Focus and Success',
    address: activeBiz.address || '',
    phone: activeBiz.phone || '',
    email: activeBiz.email || '',
    logo: activeBiz.logo || activeBiz.logoUrl || '',
    stampImage: activeBiz.stampImage || activeBiz.stamp || ''
  };

  const rc = opts.receiptConfig || (typeof window !== 'undefined' ? window.store?.settings?.receipt : null) || {};
  const rcHeader = rc.header || {};
  const rcFooter = rc.footer || {};

  const studentId = s.studentId || 'STU-2026-0001';
  const studentName = s.name || 'Student Name';
  const phone = s.phone || 'N/A';
  const alternatePhone = s.whatsappPhone || s.alternatePhone || s.customFields?.whatsapp || s.customFields?.alternate_phone || s.customFields?.alt_phone || '';
  const email = s.email || 'N/A';

  // 1. Date of Birth Resolution (Inspect root, customFields, Map, and aliases)
  const rawDob = s.dateOfBirth || s.dob || s.birthDate || (s.customFields && (s.customFields.dateOfBirth || s.customFields.dob || s.customFields.dateofbirth || s.customFields.date_of_birth || s.customFields.birthDate || (s.customFields instanceof Map ? (s.customFields.get('dateOfBirth') || s.customFields.get('dob') || s.customFields.get('dateofbirth')) : null)));
  const parsedDob = rawDob ? new Date(rawDob) : null;
  const dob = parsedDob && !isNaN(parsedDob.getTime()) ? parsedDob.toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' }) : 'N/A';

  const gender = (s.gender || 'Other').toUpperCase();
  const bloodGroup = s.bloodGroup || s.customFields?.bloodGroup || s.customFields?.blood_group || s.customFields?.bloodgroup || 'N/A';
  const pincode = s.pincode || s.customFields?.pincode || 'N/A';
  const city = s.city || s.customFields?.city || 'N/A';
  const state = s.state || s.customFields?.state || 'N/A';
  const fullAddress = s.address || s.customFields?.address || '';
  const occupation = s.occupation || s.collegeOrCompany || s.customFields?.occupation || s.customFields?.college || s.customFields?.company || 'Student / Aspirant';

  // Branch & Campus Details
  const branchName = s.branch?.name || s.branchName || 'Main Branch';
  const branchAddress = s.branch?.address || '';

  // Seating, Shift & Membership Details
  const planName = s.plan?.name || s.planName || 'Standard Study Membership';
  const planPrice = s.plan?.price !== undefined ? `₹ ${s.plan.price}` : (s.feeAmount ? `₹ ${s.feeAmount}` : '');
  const planDuration = s.plan?.duration ? `${s.plan.duration} ${s.plan.durationType || 'month(s)'}` : '';
  
  let shiftTimingStr = '';
  if (s.shift && (s.shift.startTime || s.shift.endTime)) {
    shiftTimingStr = `${s.shift.name || 'Shift'} (${s.shift.startTime || ''} - ${s.shift.endTime || ''})`;
  } else if (s.plan?.shift) {
    shiftTimingStr = String(s.plan.shift).toUpperCase();
  } else if (s.shift) {
    shiftTimingStr = typeof s.shift === 'string' ? s.shift.toUpperCase() : (s.shift.name || 'FULL DAY').toUpperCase();
  } else {
    shiftTimingStr = 'FULL DAY SHIFT';
  }

  const seatNumber = s.seat?.seatNumber || s.seatNumber || 'Floating Desk';
  const seatZone = s.seat?.zone || s.seatZone || 'General Zone';
  const seatFloor = s.seat?.floor ? ` • Floor: ${s.seat.floor}` : '';
  const lockerNumber = s.locker?.lockerNumber || s.lockerNumber || s.customFields?.lockerNumber || s.customFields?.locker || '';

  const joinedDate = s.admissionDate || s.joinedDate || s.createdAt 
    ? new Date(s.admissionDate || s.joinedDate || s.createdAt).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' }) 
    : new Date().toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const expiryDate = s.expiryDate 
    ? new Date(s.expiryDate).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' }) 
    : 'N/A';
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
  const emergencyName = s.emergencyContact?.name || s.emergencyContactName || s.customFields?.['Emergency Contact Name'] || s.customFields?.['Father / Guardian Name'] || s.customFields?.fatherName || s.customFields?.parentName || '';
  const emergencyPhone = s.emergencyContact?.phone || s.emergencyContactPhone || s.customFields?.['Emergency Contact Phone'] || s.customFields?.['Parent Phone'] || s.customFields?.parentPhone || '';
  const emergencyRelation = s.emergencyContact?.relation || s.emergencyContactRelation || s.customFields?.['Relation'] || s.customFields?.parentRelation || 'Parent / Guardian';

  // Government ID Proof & KYC Details
  const idProofType = s.idProof?.type || s.idProofType || s.customFields?.idProofType || s.customFields?.id_proof_type || s.customFields?.idprooftype || 'Aadhaar Card';
  const idProofNumber = s.idProof?.number || s.idProofNumber || s.customFields?.idProofNumber || s.customFields?.id_proof_number || s.customFields?.idproofnumber || s.customFields?.aadhaar || s.customFields?.pan || '';
  const idProofImage = s.idProof?.image || s.idProofImage || s.customFields?.idProofImage || s.customFields?.id_proof_image || s.customFields?.idproofimage || s.customFields?.idProof || s.customFields?.id_proof || '';

  // Form Builder Custom Fields & Uploaded Document Attachments Extraction
  const customEntries = [];
  const uploadedDocEntries = [];

  const coreExcluded = new Set([
    'name', 'phone', 'email', 'gender', 'dob', 'dateofbirth', 'photo', 'signature', 'seat', 'plan', 'status',
    'idproofimage', 'idproof', 'idprooftype', 'idproofnumber', 'targetexams', 'target_exams', 'competitive_exams',
    'address', 'city', 'state', 'pincode', 'bloodgroup', 'blood_group', 'emergencycontact', 'emergencycontactname',
    'emergencycontactphone', 'emergencycontactrelation', 'parentphone', 'fathername', 'rfidcardnumber', 'biometricid',
    'whatsapp', 'alternatephone', 'altphone', 'lockernumber', 'occupation', 'collegeorcompany', 'college', 'company'
  ]);

  function processCustomField(key, val) {
    if (val === undefined || val === null || val === '') return;
    const cleanKey = key.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (coreExcluded.has(cleanKey)) return;

    const strVal = String(val).trim();
    // Check if value is an uploaded image / document
    if (strVal.startsWith('data:image/') || strVal.startsWith('http://') || strVal.startsWith('https://') || strVal.startsWith('/uploads/') || strVal.includes('res.cloudinary.com')) {
      uploadedDocEntries.push({ label: key, url: strVal });
    } else {
      customEntries.push({ label: key, value: typeof val === 'boolean' ? (val ? 'Yes' : 'No') : strVal });
    }
  }

  if (s.customFields) {
    if (s.customFields instanceof Map) {
      for (const [k, v] of s.customFields.entries()) {
        processCustomField(k, v);
      }
    } else if (typeof s.customFields === 'object') {
      for (const [k, v] of Object.entries(s.customFields)) {
        processCustomField(k, v);
      }
    }
  }

  // Include idProofImage in uploaded docs if available
  if (idProofImage && (idProofImage.startsWith('data:image/') || idProofImage.startsWith('http://') || idProofImage.startsWith('https://') || idProofImage.startsWith('/uploads/') || idProofImage.includes('res.cloudinary.com'))) {
    // Check if not already in list
    if (!uploadedDocEntries.some(d => d.url === idProofImage)) {
      uploadedDocEntries.unshift({ label: `${idProofType} KYC Document Scan`, url: idProofImage });
    }
  }

  // Photo & Signature & Stamp URLs
  const photoUrl = s.photo || s.photoUrl || s.customFields?.photo || s.customFields?.passport_photo || s.avatar || '';
  const sigUrl = s.signature || s.signatureUrl || s.customFields?.signature || '';
  const winStore = typeof window !== 'undefined' ? window.store : null;
  const logoUrl = rcHeader.logoUrl || b.logo || b.logoUrl || winStore?.profile?.logo || winStore?.settings?.businessProfile?.logo || cachedProfile?.logo || '';
  const stampImageUrl = rcFooter.stampImage || b.stampImage || b.stamp || winStore?.profile?.stampImage || winStore?.settings?.businessProfile?.stampImage || cachedProfile?.stampImage || '';
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
  <title>Official Admission Form — ${studentId} (${studentName})</title>
  <style>
    @page {
      size: A4 portrait;
      margin: 8mm 10mm;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', Roboto, -apple-system, BlinkMacSystemFont, Arial, sans-serif; }
    body { background: #ffffff; color: #0f172a; font-size: 11.5px; line-height: 1.35; padding: 8px; position: relative; }

    /* Watermark Stamp */
    .watermark-stamp {
      position: absolute;
      top: 260px;
      right: 35px;
      border: 3px dashed ${stampColor};
      color: ${stampColor};
      padding: 6px 14px;
      font-size: 0.88rem;
      font-weight: 900;
      letter-spacing: 2px;
      text-transform: uppercase;
      transform: rotate(-7deg);
      opacity: 0.22;
      border-radius: 8px;
      pointer-events: none;
      z-index: 1;
    }

    /* Template Header */
    .mg-header {
      background: ${isClassic ? '#1e293b' : isCompact ? '#0284c7' : 'linear-gradient(135deg, #4338ca, #059669)'};
      color: #ffffff;
      padding: 12px 18px;
      border-radius: ${isClassic ? '0' : '10px'};
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 10px;
    }
    .mg-header h1 { font-size: 18px; font-weight: 800; letter-spacing: -0.3px; margin: 0; line-height: 1.2; }
    .mg-header p { font-size: 10.5px; opacity: 0.95; margin: 0; }

    /* Section Cards */
    .sec-card {
      border: 1px solid #cbd5e1;
      border-radius: 8px;
      padding: 9px 12px;
      margin-bottom: 9px;
      background: #f8fafc;
      position: relative;
      z-index: 2;
      page-break-inside: avoid;
    }
    .sec-title {
      font-weight: 800;
      font-size: 12px;
      color: ${isClassic ? '#1e293b' : '#4338ca'};
      border-bottom: 2px solid ${isClassic ? '#1e293b' : '#4338ca'};
      padding-bottom: 3px;
      margin-bottom: 7px;
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

    .field-label { font-size: 9.5px; color: #475569; font-weight: 700; text-transform: uppercase; letter-spacing: 0.3px; }
    .field-value { font-size: 11.5px; font-weight: 700; color: #0f172a; margin-top: 1px; word-break: break-word; }

    /* Photo & Signature Frame */
    .photo-frame {
      width: 125px;
      height: 135px;
      border: 1.5px solid #94a3b8;
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
      border: 1.5px solid #94a3b8;
      border-radius: 8px;
      background: #ffffff;
      padding: 5px;
      text-align: center;
      box-shadow: 0 1px 3px rgba(0,0,0,0.08);
    }

    .sig-box {
      width: 160px;
      height: 48px;
      border-bottom: 1.5px solid #334155;
      display: flex;
      align-items: flex-end;
      justify-content: center;
      margin-top: 3px;
    }
    .sig-box img { max-height: 42px; max-width: 100%; object-fit: contain; }

    /* Uploaded Document Frame */
    .doc-preview-card {
      border: 1.5px solid #cbd5e1;
      border-radius: 8px;
      background: #ffffff;
      padding: 8px;
      text-align: center;
      page-break-inside: avoid;
    }
    .doc-preview-img {
      max-height: 220px;
      width: 100%;
      object-fit: contain;
      border-radius: 6px;
      border: 1px solid #e2e8f0;
      background: #f8fafc;
    }

    /* Rules Table */
    .rules-list { font-size: 9.5px; color: #334155; padding-left: 15px; margin-top: 3px; line-height: 1.4; }
    .rules-list li { margin-bottom: 2px; }

    /* Footer Bar */
    .doc-footer {
      margin-top: 10px;
      border-top: 1px solid #cbd5e1;
      padding-top: 6px;
      display: flex;
      justify-content: space-between;
      font-size: 9px;
      color: #64748b;
    }

    @media print {
      body { padding: 0; background: #fff !important; }
      .sec-card { background: #fff !important; border-color: #94a3b8; break-inside: avoid; page-break-inside: avoid; }
      .mg-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .doc-preview-card { break-inside: avoid; page-break-inside: avoid; }
    }
  </style>
</head>
<body>

  ${opts.showWatermarkStamp ? `<div class="watermark-stamp">${stampText}</div>` : ''}

  <!-- Header -->
  <div class="mg-header">
    <div style="display: flex; align-items: center; gap: 12px;">
      ${logoUrl ? `<img src="${logoUrl}" style="max-height: 48px; max-width: 75px; object-fit: contain; background: #fff; padding: 2px; border-radius: 6px;">` : ''}
      <div>
        <h1>${b.businessName}</h1>
        <p>${b.tagline || 'Self Study & Reading Room'}</p>
        <p style="margin-top: 2px; font-size: 9.5px;">📍 ${b.address || ''} • 📞 ${b.phone || ''} ${gstNumber ? `• GSTIN: ${gstNumber}` : ''}</p>
      </div>
    </div>
    <div style="text-align: right; background: rgba(255,255,255,0.22); padding: 5px 12px; border-radius: 6px; min-width: 145px; white-space: nowrap; flex-shrink: 0;">
      <div style="font-size: 9px; text-transform: uppercase; letter-spacing: 0.5px; font-weight: 700;">OFFICIAL ADMISSION FORM</div>
      <div style="font-size: 14px; font-weight: 900; font-family: monospace; margin: 1px 0;">${studentId}</div>
      <div style="font-size: 10px; font-weight: 700;">Date: ${joinedDate}</div>
    </div>
  </div>

  <!-- Top 2-Column Grid: Left: Personal + Seat Info | Right: Photo + QR Code -->
  <div style="display: grid; grid-template-columns: 1fr 135px; gap: 10px; margin-bottom: 8px; align-items: start;">
    
    <!-- Left Column: Personal Information & Seat Allotment -->
    <div style="display: flex; flex-direction: column; gap: 8px;">
      
      <!-- 1. Student Personal Information -->
      <div class="sec-card" style="margin-bottom: 0;">
        <div class="sec-title">👤 Student Personal Information</div>
        
        <div class="grid-3" style="margin-bottom: 6px;">
          <div>
            <div class="field-label">Full Student Name</div>
            <div class="field-value">${studentName}</div>
          </div>
          <div>
            <div class="field-label">Mobile Number</div>
            <div class="field-value">📞 ${phone}</div>
          </div>
          <div>
            <div class="field-label">Email Address</div>
            <div class="field-value">${email}</div>
          </div>
        </div>

        <div class="grid-4" style="margin-bottom: 6px;">
          <div>
            <div class="field-label">Gender</div>
            <div class="field-value">${gender}</div>
          </div>
          <div>
            <div class="field-label">Date of Birth</div>
            <div class="field-value" style="color: #4338ca; font-weight: 800;">${dob}</div>
          </div>
          <div>
            <div class="field-label">Blood Group</div>
            <div class="field-value" style="color: #dc2626; font-weight: 800;">${bloodGroup}</div>
          </div>
          <div>
            <div class="field-label">City & State</div>
            <div class="field-value">${city}${state && state !== 'N/A' ? ', ' + state : ''}</div>
          </div>
        </div>

        ${fullAddress ? `
          <div style="border-top: 1px dashed #cbd5e1; padding-top: 5px;">
            <div class="field-label">Resident / Permanent Address</div>
            <div class="field-value" style="font-size: 11px;">${fullAddress}${pincode && pincode !== 'N/A' ? ' (PIN: ' + pincode + ')' : ''}</div>
          </div>
        ` : ''}
      </div>

      <!-- 2. Study Centre, Shift & Seating Allocation -->
      <div class="sec-card" style="margin-bottom: 0;">
        <div class="sec-title">🏢 Study Centre & Seating Allocation</div>
        
        <div class="grid-3" style="margin-bottom: 6px;">
          <div>
            <div class="field-label">Campus / Branch</div>
            <div class="field-value" style="color: #4338ca;">${branchName}</div>
          </div>
          <div>
            <div class="field-label">Assigned Desk / Seat</div>
            <div class="field-value" style="color: #059669; font-size: 12.5px;">${seatNumber} (${seatZone}${seatFloor})</div>
          </div>
          <div>
            <div class="field-label">Study Shift & Timings</div>
            <div class="field-value">${shiftTimingStr}</div>
          </div>
        </div>

        <div class="grid-4">
          <div>
            <div class="field-label">Membership Plan</div>
            <div class="field-value">${planName} ${planDuration ? '(' + planDuration + ')' : ''}</div>
          </div>
          <div>
            <div class="field-label">Plan Fee Amount</div>
            <div class="field-value" style="color: #059669;">${planPrice || 'Standard Rate'}</div>
          </div>
          <div>
            <div class="field-label">Admission Date</div>
            <div class="field-value">${joinedDate}</div>
          </div>
          <div>
            <div class="field-label">Validity Expiry Date</div>
            <div class="field-value" style="color: #dc2626; font-weight: 800;">${expiryDate}</div>
          </div>
        </div>
      </div>

    </div>

    <!-- Right Column: Passport Photo & Verification QR Code -->
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

  <!-- 3. Academic Focus, Locker & Guardian Emergency Contact -->
  <div class="sec-card">
    <div class="sec-title">🎯 Academic Goals, Facilities & Emergency Contact</div>
    
    <div class="grid-3" style="margin-bottom: 6px;">
      <div>
        <div class="field-label">Target Competitive Exams</div>
        <div class="field-value" style="color: #4338ca;">
          ${targetExamsList.length > 0 ? targetExamsList.join(', ') : 'General Competitive Exams / Self Study'}
        </div>
      </div>
      <div>
        <div class="field-label">College / Company / Occupation</div>
        <div class="field-value">${occupation}</div>
      </div>
      <div>
        <div class="field-label">Locker & Access Card</div>
        <div class="field-value">${lockerNumber ? `Locker #${lockerNumber}` : 'No Locker Assigned'} • Bio/RFID: ${s.rfidCardNumber || s.biometricCardNumber || s.biometricId || 'N/A'}</div>
      </div>
    </div>

    ${emergencyName || emergencyPhone ? `
      <div style="border-top: 1px dashed #cbd5e1; padding-top: 5px;" class="grid-3">
        <div>
          <div class="field-label">Guardian / Parent Name</div>
          <div class="field-value">${emergencyName || 'N/A'}</div>
        </div>
        <div>
          <div class="field-label">Guardian Contact Phone</div>
          <div class="field-value">📞 ${emergencyPhone || 'N/A'}</div>
        </div>
        <div>
          <div class="field-label">Relationship</div>
          <div class="field-value">${emergencyRelation}</div>
        </div>
      </div>
    ` : ''}
  </div>

  <!-- 4. Government KYC & Identity Proof Verification -->
  <div class="sec-card">
    <div class="sec-title">🪪 Government ID Proof & KYC Verification</div>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 10px; align-items: center;">
      
      <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 8px 12px; display: flex; align-items: center; justify-content: space-between;">
        <div>
          <div style="font-weight: 800; font-size: 11.5px; color: #0f172a;">📑 ${idProofType}</div>
          <div style="font-size: 10.5px; color: #334155; font-family: monospace; font-weight: 700; margin-top: 2px;">
            ${idProofNumber ? `ID Number: ${idProofNumber}` : 'Document Attached on Record'}
          </div>
        </div>
        <span style="font-size: 9px; font-weight: 800; color: #059669; background: #d1fae5; padding: 3px 8px; border-radius: 4px; border: 1px solid #10b981;">
          KYC VERIFIED ✓
        </span>
      </div>

      <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 6px; padding: 8px 12px; display: flex; align-items: center; justify-content: space-between;">
        <div>
          <div style="font-weight: 800; font-size: 11.5px; color: #0f172a;">📋 Admission & Fee Status</div>
          <div style="font-size: 10.5px; color: #334155; font-family: monospace; font-weight: 700; margin-top: 2px;">
            Status: ${status} (${isPaid ? 'CONFIRMED' : 'PROVISIONAL'})
          </div>
        </div>
        <span style="font-size: 9px; font-weight: 800; color: ${isPaid ? '#059669' : '#d97706'}; background: ${isPaid ? '#d1fae5' : '#fef3c7'}; padding: 3px 8px; border-radius: 4px; border: 1px solid ${isPaid ? '#10b981' : '#f59e0b'};">
          ${isPaid ? 'ACTIVE ACCESS' : 'PENDING'}
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
          <div style="margin-bottom: 3px;">
            <div class="field-label">${escapeHTML(e.label)}</div>
            <div class="field-value" style="font-size: 11px;">${escapeHTML(e.value)}</div>
          </div>
        `).join('')}
      </div>
    </div>
  ` : ''}

  <!-- 6. ATTACHED & UPLOADED DOCUMENTS GALLERY SECTION -->
  ${opts.showUploadedDocuments && uploadedDocEntries.length > 0 ? `
    <div class="sec-card doc-gallery-section" style="page-break-inside: avoid;">
      <div class="sec-title">📑 Attached KYC Documents & Uploaded Verification Proofs</div>
      <div style="display: grid; grid-template-columns: ${uploadedDocEntries.length === 1 ? '1fr' : 'repeat(auto-fit, minmax(280px, 1fr))'}; gap: 10px;">
        ${uploadedDocEntries.map(doc => `
          <div class="doc-preview-card">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; border-bottom: 1px dashed #cbd5e1; padding-bottom: 4px;">
              <span style="font-size: 10px; font-weight: 800; color: #1e293b; text-transform: uppercase;">
                📄 ${escapeHTML(doc.label)}
              </span>
              <span style="font-size: 8.5px; font-weight: 700; color: #059669; background: #d1fae5; padding: 2px 6px; border-radius: 3px;">
                VERIFIED ATTACHMENT
              </span>
            </div>
            <div style="text-align: center; max-height: 230px; overflow: hidden; display: flex; align-items: center; justify-content: center; background: #f8fafc; border-radius: 6px;">
              <img src="${doc.url}" alt="${escapeHTML(doc.label)}" class="doc-preview-img" style="max-height: 220px; width: 100%; object-fit: contain;">
            </div>
            <div style="font-size: 8.5px; color: #64748b; margin-top: 4px; font-family: monospace;">
              Document Reference: ${studentId} • Record ID Proof Scan
            </div>
          </div>
        `).join('')}
      </div>
    </div>
  ` : ''}

  <!-- 7. Discipline Code, Terms of Admission & Declaration -->
  ${opts.showRules ? `
    <div class="sec-card" style="page-break-inside: avoid;">
      <div class="sec-title">📜 Discipline Code & Student Declaration</div>
      ${termsText ? `<div class="rules-list" style="margin-bottom: 5px;">${termsText}</div>` : `
      <ol class="rules-list">
        <li>Maintain complete silence in the study hall. Mobile phones must strictly be kept on Silent mode.</li>
        <li>Seats are reserved for the registered student and non-transferable without prior management approval.</li>
        <li>Eatables, tea, and open beverages are strictly prohibited inside reading rooms.</li>
        <li>I declare that the information provided is accurate and agree to adhere to all library rules and timings.</li>
      </ol>`}
      ${customNote ? `<p style="font-size: 9.5px; color: #4338ca; font-weight: 700; margin-top: 3px;">Notice: ${customNote}</p>` : ''}

      <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 8px; padding-top: 6px; border-top: 1px dashed #cbd5e1;">
        <div>
          <div class="field-label">Date & Place</div>
          <div class="field-value">${joinedDate} • ${city !== 'N/A' ? city : 'Campus'}</div>
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
            ${stampImageUrl ? `<img src="${stampImageUrl}" style="max-height: 40px; opacity: 0.90;">` : ''}
            ${managerSigUrl ? `<img src="${managerSigUrl}" style="max-height: 36px;">` : ''}
            ${!stampImageUrl && !managerSigUrl ? `<span style="font-size:9px; color:#64748b; font-weight:800; border:1px solid #cbd5e1; padding:2px 8px; border-radius:4px;">OFFICIAL SEAL</span>` : ''}
          </div>
        </div>
      </div>
    </div>
  ` : ''}

  <!-- Footer -->
  <div class="doc-footer">
    <div>Generated via ${b.businessName || 'Study Library Management'} • Official Admission & Registration Record</div>
    <div>Document Ref: ${studentId} • Verified Student Copy</div>
  </div>

</body>
</html>
  `;
}

/**
 * Direct Print PDF Trigger
 */
export async function generateAdmissionFormPDF(student, options = {}) {
  let fullStudent = student;
  if (student && student._id && (!student.plan?.name || !student.shift?.name || !student.branch?.name || !student.idProof?.image)) {
    try {
      const token = localStorage.getItem('sl_token') || localStorage.getItem('token');
      const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
      const res = await fetch(`/api/students/${student._id}`, { headers }).then(r => r.json());
      if (res?.success && res?.data) fullStudent = res.data;
    } catch (e) {}
  }

  const htmlContent = buildAdmissionFormHTML(fullStudent, options);
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
    showUploadedDocuments: true,
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
    width: 100%; max-width: 950px; height: 92vh; background: var(--color-surface, #ffffff);
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
            Includes all personal data, seating allotment, custom questions & uploaded documents
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
        width: 100%; max-width: 840px; height: 100%; min-height: 750px;
        background: #ffffff; border: none; border-radius: 4px; box-shadow: 0 10px 30px rgba(0,0,0,0.5);
      "></iframe>
    </div>
  `;

  overlay.appendChild(modal);
  document.body.appendChild(overlay);

  const iframe = modal.querySelector('#pdf-preview-iframe');
  let activeStudent = student;
  
  function updateIframePreview() {
    const html = buildAdmissionFormHTML(activeStudent, currentOpts);
    const doc = iframe.contentWindow.document;
    doc.open();
    doc.write(html);
    doc.close();
  }

  updateIframePreview();

  // Asynchronously fetch fresh full student record from database if _id exists to guarantee all populated references and uploaded document images are loaded
  if (student && student._id) {
    (async () => {
      try {
        const token = localStorage.getItem('sl_token') || localStorage.getItem('token');
        const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
        const res = await fetch(`/api/students/${student._id}`, { headers }).then(r => r.json());
        if (res?.success && res?.data) {
          activeStudent = res.data;
          updateIframePreview();
        }
      } catch (e) {}
    })();
  }

  // Async dynamic settings revalidation to ensure 100% fresh organisation branding
  if (!currentOpts.business || !currentOpts.business.businessName || currentOpts.business.businessName === 'Study Library Management') {
    (async () => {
      try {
        const res = await (window.api ? window.api.get('/api/settings') : fetch('/api/settings').then(r => r.json()));
        if (res?.success && res?.data?.businessProfile) {
          currentOpts.business = res.data.businessProfile;
          if (res.data.receipt) currentOpts.receiptConfig = res.data.receipt;
          updateIframePreview();
        }
      } catch (e) {}
    })();
  }

  // Template switch handler
  modal.querySelector('#pdf-prev-preset')?.addEventListener('change', (e) => {
    currentOpts.template = e.target.value;
    updateIframePreview();
  });

  // Print button handler
  modal.querySelector('#btn-pdf-modal-print')?.addEventListener('click', () => {
    generateAdmissionFormPDF(activeStudent, currentOpts);
  });

  // Close handler
  modal.querySelector('#btn-pdf-modal-close')?.addEventListener('click', () => {
    overlay.remove();
  });

  overlay.addEventListener('click', (e) => {
    if (e.target === overlay) overlay.remove();
  });
}
