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
  const hasAnnexure = opts.showUploadedDocuments && uploadedDocEntries.length > 0;

  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Official Admission Form — ${studentId} (${studentName})</title>
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">
  <style>
    @page {
      size: A4 portrait;
      margin: 6mm 8mm;
    }
    * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, Arial, Helvetica, sans-serif;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
      text-rendering: optimizeLegibility;
      letter-spacing: normal;
    }
    body {
      background: #ffffff;
      color: #0f172a;
      font-size: 11px;
      line-height: 1.35;
      padding: 0;
      position: relative;
    }

    /* Outer Executive Certificate Border Frame */
    .page-frame {
      width: 100%;
      height: 278mm;
      min-height: 278mm;
      box-sizing: border-box;
      border: 2.5px solid #1e293b;
      outline: 1px solid #94a3b8;
      outline-offset: -5px;
      border-radius: 8px;
      padding: 10px 13px;
      position: relative;
      background: #ffffff;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      box-shadow: 0 2px 8px rgba(0,0,0,0.04);
    }

    .page-break {
      page-break-before: always;
      break-before: page;
      margin-top: 15px;
    }

    /* Auto-Fit Flex Container to eliminate blank bottom spaces */
    .page-content-flow {
      display: flex;
      flex-direction: column;
      justify-content: space-between;
      flex: 1;
      min-height: 0;
      gap: 7px;
      margin-bottom: 4px;
    }

    /* Watermark Stamp */
    .watermark-stamp {
      position: absolute;
      top: 250px;
      right: 40px;
      border: 3px dashed ${stampColor};
      color: ${stampColor};
      padding: 6px 14px;
      font-size: 0.82rem;
      font-weight: 800;
      letter-spacing: 2px;
      text-transform: uppercase;
      transform: rotate(-7deg);
      opacity: 0.16;
      border-radius: 8px;
      pointer-events: none;
      z-index: 1;
    }

    /* Template Header */
    .mg-header {
      background: ${isClassic ? '#1e293b' : isCompact ? '#0284c7' : 'linear-gradient(135deg, #3730a3, #047857)'};
      color: #ffffff;
      padding: 10px 14px;
      border-radius: 6px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
    }
    .mg-header h1 { font-size: 16.5px; font-weight: 700; margin: 0; line-height: 1.2; }
    .mg-header p { font-size: 10px; opacity: 0.95; margin: 0; }

    /* Section Cards with Dynamic Auto-Fit Expansion */
    .sec-card {
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      padding: 7px 11px;
      background: #f8fafc;
      position: relative;
      z-index: 2;
      display: flex;
      flex-direction: column;
      justify-content: space-around;
      flex: 1 0 auto;
    }
    .sec-title {
      font-weight: 700;
      font-size: 11px;
      color: ${isClassic ? '#1e293b' : '#3730a3'};
      border-bottom: 1.5px solid ${isClassic ? '#1e293b' : '#4338ca'};
      padding-bottom: 3px;
      margin-bottom: 5px;
      text-transform: uppercase;
      letter-spacing: 0.3px;
      display: flex;
      align-items: center;
      gap: 6px;
      flex-shrink: 0;
    }

    /* Grid Layouts */
    .grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 6px 12px; }
    .grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 6px 10px; }
    .grid-4 { display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 6px 8px; }

    .field-label { font-size: 8.5px; color: #475569; font-weight: 600; text-transform: uppercase; letter-spacing: 0.25px; }
    .field-value { font-size: 11px; font-weight: 600; color: #0f172a; margin-top: 1px; word-break: break-word; }

    /* Photo & QR Frame */
    .photo-frame {
      width: 110px;
      height: 118px;
      border: 1.5px solid #94a3b8;
      border-radius: 6px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: #ffffff;
      overflow: hidden;
      margin: 0 auto;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    }
    .photo-frame img { width: 100%; height: 100%; object-fit: cover; }

    .qr-frame {
      width: 110px;
      border: 1.5px solid #94a3b8;
      border-radius: 6px;
      background: #ffffff;
      padding: 4px;
      text-align: center;
      box-shadow: 0 1px 3px rgba(0,0,0,0.06);
    }

    .sig-box {
      width: 155px;
      height: 40px;
      border-bottom: 1.5px solid #334155;
      display: flex;
      align-items: flex-end;
      justify-content: center;
      margin-top: 2px;
    }
    .sig-box img { max-height: 36px; max-width: 100%; object-fit: contain; }

    /* Annexure Full Page Frame */
    .annexure-header {
      background: linear-gradient(135deg, #1e293b, #334155);
      color: #ffffff;
      padding: 10px 14px;
      border-radius: 6px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      flex-shrink: 0;
    }
    .doc-preview-card-full {
      border: 1px solid #cbd5e1;
      border-radius: 6px;
      background: #ffffff;
      padding: 10px;
      text-align: center;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      flex: 1;
      min-height: 228mm;
      margin: 6px 0;
    }
    .doc-preview-img-full {
      max-height: 205mm;
      width: 100%;
      object-fit: contain;
      border-radius: 4px;
      background: #f8fafc;
    }

    /* Rules Table */
    .rules-list { font-size: 9px; color: #334155; padding-left: 14px; margin-top: 2px; line-height: 1.35; }
    .rules-list li { margin-bottom: 1.5px; }

    /* Footer Bar */
    .doc-footer {
      border-top: 1px solid #cbd5e1;
      padding-top: 4px;
      display: flex;
      justify-content: space-between;
      font-size: 8.5px;
      color: #64748b;
      flex-shrink: 0;
    }

    @media print {
      body { padding: 0; background: #fff !important; }
      .page-frame { height: 278mm; min-height: 278mm; max-height: 278mm; border: 2.5px solid #1e293b; outline: 1px solid #94a3b8; }
      .sec-card { background: #fff !important; border-color: #94a3b8; }
      .mg-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .annexure-header { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .page-break { page-break-before: always; break-before: page; margin-top: 0; }
    }
  </style>
</head>
<body>

  <!-- ==================== PAGE 1: OFFICIAL ADMISSION CERTIFICATE & FORM ==================== -->
  <div class="page-frame">
    ${opts.showWatermarkStamp ? `<div class="watermark-stamp">${stampText}</div>` : ''}

    <div class="page-content-flow">
      <!-- 1. Header -->
      <div class="mg-header">
        <div style="display: flex; align-items: center; gap: 10px;">
          ${logoUrl ? `<img src="${logoUrl}" style="max-height: 42px; max-width: 65px; object-fit: contain; background: #fff; padding: 2px; border-radius: 4px;">` : ''}
          <div>
            <h1>${b.businessName}</h1>
            <p>${b.tagline || 'Silence, Focus and Success'}</p>
            <p style="margin-top: 2px; font-size: 9px;">📍 ${b.address || ''} • 📞 ${b.phone || ''} ${gstNumber ? `• GSTIN: ${gstNumber}` : ''}</p>
          </div>
        </div>
        <div style="text-align: right; background: rgba(255,255,255,0.22); padding: 4px 10px; border-radius: 5px; min-width: 140px; white-space: nowrap; flex-shrink: 0;">
          <div style="font-size: 8px; text-transform: uppercase; letter-spacing: 0.5px; font-weight: 700;">OFFICIAL ADMISSION FORM</div>
          <div style="font-size: 13px; font-weight: 700; font-family: monospace; margin: 1px 0;">${studentId}</div>
          <div style="font-size: 9px; font-weight: 600;">Date: ${joinedDate}</div>
        </div>
      </div>

      <!-- 2. Top 2-Column Grid: Left (Personal + Seat Info) | Right (Photo + QR Code) -->
      <div style="display: grid; grid-template-columns: 1fr 118px; gap: 8px; align-items: stretch;">
        
        <!-- Left Column: Personal Information & Seat Allotment -->
        <div style="display: flex; flex-direction: column; gap: 6px; justify-content: space-between;">
          
          <!-- Student Personal Information -->
          <div class="sec-card" style="margin-bottom: 0;">
            <div class="sec-title">👤 Student Personal Information</div>
            
            <div class="grid-3" style="margin-bottom: 4px;">
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

            <div class="grid-4" style="margin-bottom: 4px;">
              <div>
                <div class="field-label">Gender</div>
                <div class="field-value">${gender}</div>
              </div>
              <div>
                <div class="field-label">Date of Birth</div>
                <div class="field-value" style="color: #3730a3; font-weight: 700;">${dob}</div>
              </div>
              <div>
                <div class="field-label">Blood Group</div>
                <div class="field-value" style="color: #dc2626; font-weight: 700;">${bloodGroup}</div>
              </div>
              <div>
                <div class="field-label">City & State</div>
                <div class="field-value">${city}${state && state !== 'N/A' ? ', ' + state : ''}</div>
              </div>
            </div>

            ${fullAddress ? `
              <div style="border-top: 1px dashed #cbd5e1; padding-top: 3px;">
                <div class="field-label">Resident / Permanent Address</div>
                <div class="field-value" style="font-size: 10px;">${fullAddress}${pincode && pincode !== 'N/A' ? ' (PIN: ' + pincode + ')' : ''}</div>
              </div>
            ` : ''}
          </div>

          <!-- Study Centre, Shift & Seating Allocation -->
          <div class="sec-card" style="margin-bottom: 0;">
            <div class="sec-title">🏢 Study Centre & Seating Allocation</div>
            
            <div class="grid-3" style="margin-bottom: 4px;">
              <div>
                <div class="field-label">Campus / Branch</div>
                <div class="field-value" style="color: #3730a3;">${branchName}</div>
              </div>
              <div>
                <div class="field-label">Assigned Desk / Seat</div>
                <div class="field-value" style="color: #047857; font-size: 11.5px;">${seatNumber} (${seatZone}${seatFloor})</div>
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
                <div class="field-value" style="color: #047857;">${planPrice || 'Standard Rate'}</div>
              </div>
              <div>
                <div class="field-label">Admission Date</div>
                <div class="field-value">${joinedDate}</div>
              </div>
              <div>
                <div class="field-label">Validity Expiry Date</div>
                <div class="field-value" style="color: #dc2626; font-weight: 700;">${expiryDate}</div>
              </div>
            </div>
          </div>

        </div>

        <!-- Right Column: Passport Photo & Verification QR Code -->
        <div style="display: flex; flex-direction: column; align-items: center; justify-content: space-between; gap: 6px;">
          
          <!-- Passport Photo Frame -->
          <div style="width: 100%; text-align: center;">
            <div class="field-label" style="margin-bottom: 2px; font-size: 8px;">PASSPORT PHOTO</div>
            <div class="photo-frame">
              ${photoUrl ? `<img src="${photoUrl}" alt="Photo">` : `<span style="color:#94a3b8; font-size:8.5px; font-weight:600;">AFFIX PHOTO</span>`}
            </div>
          </div>

          <!-- Generated Student Verification QR Code -->
          <div style="width: 100%; text-align: center;">
            <div class="field-label" style="margin-bottom: 2px; font-size: 8px;">VERIFY ID QR</div>
            <div class="qr-frame" style="margin: 0 auto;">
              <div style="display: flex; align-items: center; justify-content: center;">
                ${qrCodeImg}
              </div>
              <div style="font-size: 7.5px; font-weight: 700; font-family: monospace; color: #475569; margin-top: 1px;">${studentId}</div>
            </div>
          </div>

        </div>

      </div>

      <!-- 3. Academic Focus, Locker & Guardian Emergency Contact -->
      <div class="sec-card">
        <div class="sec-title">🎯 Academic Goals, Facilities & Emergency Contact</div>
        
        <div class="grid-3" style="margin-bottom: 4px;">
          <div>
            <div class="field-label">Target Competitive Exams</div>
            <div class="field-value" style="color: #3730a3;">
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
          <div style="border-top: 1px dashed #cbd5e1; padding-top: 3px;" class="grid-3">
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
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; align-items: center;">
          
          <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 5px; padding: 5px 9px; display: flex; align-items: center; justify-content: space-between;">
            <div>
              <div style="font-weight: 700; font-size: 10.5px; color: #0f172a;">📑 ${idProofType}</div>
              <div style="font-size: 9.5px; color: #334155; font-family: monospace; font-weight: 600; margin-top: 1px;">
                ${idProofNumber ? `ID Number: ${idProofNumber}` : 'Document Attached on Record'}
              </div>
            </div>
            <span style="font-size: 8px; font-weight: 700; color: #047857; background: #d1fae5; padding: 2px 6px; border-radius: 3px; border: 1px solid #10b981;">
              KYC VERIFIED ✓
            </span>
          </div>

          <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 5px; padding: 5px 9px; display: flex; align-items: center; justify-content: space-between;">
            <div>
              <div style="font-weight: 700; font-size: 10.5px; color: #0f172a;">📋 Admission & Fee Status</div>
              <div style="font-size: 9.5px; color: #334155; font-family: monospace; font-weight: 600; margin-top: 1px;">
                Status: ${status} (${isPaid ? 'CONFIRMED' : 'PROVISIONAL'})
              </div>
            </div>
            <span style="font-size: 8px; font-weight: 700; color: ${isPaid ? '#047857' : '#d97706'}; background: ${isPaid ? '#d1fae5' : '#fef3c7'}; padding: 2px 6px; border-radius: 3px; border: 1px solid ${isPaid ? '#10b981' : '#f59e0b'};">
              ${isPaid ? 'ACTIVE ACCESS' : 'PENDING'}
            </span>
          </div>

        </div>
      </div>

      <!-- 5. Form Builder Custom Questions & Dynamic Answers (Auto-Fit Expansion) -->
      ${customEntries.length > 0 ? `
        <div class="sec-card">
          <div class="sec-title">📋 Additional Registration Information</div>
          <div class="grid-2">
            ${customEntries.map(e => `
              <div style="margin-bottom: 2px;">
                <div class="field-label">${escapeHTML(e.label)}</div>
                <div class="field-value" style="font-size: 10px;">${escapeHTML(e.value)}</div>
              </div>
            `).join('')}
          </div>
        </div>
      ` : ''}

      <!-- 6. Discipline Code, Terms of Admission & Declaration -->
      ${opts.showRules ? `
        <div class="sec-card">
          <div class="sec-title">📜 Discipline Code & Student Declaration</div>
          ${termsText ? `<div class="rules-list" style="margin-bottom: 3px;">${termsText}</div>` : `
          <ol class="rules-list">
            <li>Maintain complete silence in the study hall. Mobile phones must strictly be kept on Silent mode.</li>
            <li>Seats are reserved for the registered student and non-transferable without prior management approval.</li>
            <li>Eatables, tea, and open beverages are strictly prohibited inside reading rooms.</li>
            <li>I declare that the information provided is accurate and agree to adhere to all library rules and timings.</li>
          </ol>`}
          ${customNote ? `<p style="font-size: 8.5px; color: #3730a3; font-weight: 600; margin-top: 2px;">Notice: ${customNote}</p>` : ''}

          <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 4px; padding-top: 4px; border-top: 1px dashed #cbd5e1;">
            <div>
              <div class="field-label">Date & Place</div>
              <div class="field-value">${joinedDate} • ${city !== 'N/A' ? city : 'Campus'}</div>
            </div>

            ${opts.showSignature ? `
              <div style="text-align: center;">
                <div class="field-label">Student Digital Signature</div>
                <div class="sig-box">
                  ${sigUrl ? `<img src="${sigUrl}" alt="Signature">` : `<span style="font-family: Arial, sans-serif; font-size:10.5px; font-weight:600;">${studentName}</span>`}
                </div>
              </div>
            ` : ''}

            <div style="text-align: center;">
              <div class="field-label">${rcFooter.signatureLabel || 'Authorized Seal & Signatory'}</div>
              <div class="sig-box" style="border-bottom-style: dotted; display: flex; align-items: center; justify-content: center; gap: 6px;">
                ${stampImageUrl ? `<img src="${stampImageUrl}" style="max-height: 36px; opacity: 0.92;">` : ''}
                ${managerSigUrl ? `<img src="${managerSigUrl}" style="max-height: 32px;">` : ''}
                ${!stampImageUrl && !managerSigUrl ? `<span style="font-size:8px; color:#64748b; font-weight:700; border:1px solid #cbd5e1; padding:2px 6px; border-radius:3px;">OFFICIAL SEAL</span>` : ''}
              </div>
            </div>
          </div>
        </div>
      ` : ''}
    </div>

    <!-- Page 1 Footer -->
    <div class="doc-footer">
      <div>Generated via ${b.businessName || 'Study Library Management'} • ${hasAnnexure ? 'Page 1 of 2 (Official Admission Form)' : 'Official Admission & Registration Record'}</div>
      <div>Document Ref: ${studentId} • Verified Student Copy</div>
    </div>
  </div>

  <!-- ==================== PAGE 2: ANNEXURE — ATTACHED KYC DOCUMENT SCAN ==================== -->
  ${hasAnnexure ? `
    ${uploadedDocEntries.map((doc, idx) => `
      <div class="page-frame page-break">
        <!-- Annexure Header -->
        <div class="annexure-header">
          <div style="display: flex; align-items: center; gap: 10px;">
            ${logoUrl ? `<img src="${logoUrl}" style="max-height: 38px; max-width: 60px; object-fit: contain; background: #fff; padding: 2px; border-radius: 4px;">` : ''}
            <div>
              <h1 style="font-size: 14.5px; font-weight: 700; margin: 0;">${b.businessName}</h1>
              <p style="font-size: 9px; opacity: 0.9; margin: 0;">ANNEXURE ${uploadedDocEntries.length > 1 ? String.fromCharCode(65 + idx) : 'A'} — GOVERNMENT ID & KYC VERIFICATION PROOF</p>
            </div>
          </div>
          <div style="text-align: right; background: rgba(255,255,255,0.18); padding: 4px 10px; border-radius: 5px;">
            <div style="font-size: 7.5px; text-transform: uppercase; font-weight: 700;">STUDENT IDENTIFICATION</div>
            <div style="font-size: 12px; font-weight: 700; font-family: monospace;">${studentId}</div>
          </div>
        </div>

        <!-- Document Full-Page Display Frame (Auto-Fit to A4) -->
        <div class="doc-preview-card-full">
          <div style="width: 100%; display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; border-bottom: 1px dashed #cbd5e1; padding-bottom: 4px;">
            <span style="font-size: 10.5px; font-weight: 700; color: #1e293b; text-transform: uppercase;">
              📄 ${escapeHTML(doc.label)}
            </span>
            <span style="font-size: 8.5px; font-weight: 700; color: #047857; background: #d1fae5; padding: 2px 7px; border-radius: 3px; border: 1px solid #10b981;">
              OFFICIAL RECORD ATTACHMENT ✓
            </span>
          </div>
          
          <div style="flex: 1; width: 100%; display: flex; align-items: center; justify-content: center; background: #ffffff; padding: 4px;">
            <img src="${doc.url}" alt="${escapeHTML(doc.label)}" class="doc-preview-img-full">
          </div>

          <div style="width: 100%; font-size: 8.5px; color: #64748b; margin-top: 4px; border-top: 1px solid #e2e8f0; padding-top: 4px; font-family: monospace; display: flex; justify-content: space-between;">
            <span>Document Reference: ${studentId} • Verified KYC Record Proof</span>
            <span>Name: ${studentName} • Date: ${joinedDate}</span>
          </div>
        </div>

        <!-- Page 2 Footer -->
        <div class="doc-footer">
          <div>Generated via ${b.businessName || 'Study Library Management'} • Page ${2 + idx} of ${1 + uploadedDocEntries.length} (Verified KYC Document)</div>
          <div>Document Ref: ${studentId} • Official Verification Attachment</div>
        </div>
      </div>
    `).join('')}
  ` : ''}

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
