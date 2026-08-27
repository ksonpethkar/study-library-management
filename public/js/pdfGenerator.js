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
  const emergencyName = s.emergencyContact?.name || s.emergencyContactName || s.customFields?.['parent___guardian_name'] || s.customFields?.['parentguardianname'] || s.customFields?.['Parent / Guardian Name'] || s.customFields?.['Emergency Contact Name'] || s.customFields?.['Father / Guardian Name'] || s.customFields?.parentName || s.customFields?.guardianName || s.customFields?.fatherName || s.customFields?.emergencyContactName || '';
  const emergencyPhone = s.emergencyContact?.phone || s.emergencyContactPhone || s.customFields?.emergencycontact || s.customFields?.emergencyContact || s.customFields?.['Emergency Contact Phone'] || s.customFields?.['Parent Phone'] || s.customFields?.parentPhone || '';
  const emergencyRelation = s.emergencyContact?.relation || s.emergencyContactRelation || s.customFields?.relationship || s.customFields?.relation || s.customFields?.['Relationship'] || s.customFields?.['Relation'] || s.customFields?.parentRelation || 'Parent';

  // Government ID Proof & KYC Details
  const idProofType = s.idProof?.type || s.idProofType || s.customFields?.idProofType || s.customFields?.id_proof_type || s.customFields?.idprooftype || 'Aadhaar Card';
  const idProofNumber = s.idProof?.number || s.idProofNumber || s.customFields?.idProofNumber || s.customFields?.id_proof_number || s.customFields?.idproofnumber || s.customFields?.aadhaar || s.customFields?.pan || '';
  const idProofImage = s.idProof?.image || s.idProofImage || s.customFields?.idProofImage || s.customFields?.id_proof_image || s.customFields?.idproofimage || s.customFields?.idProof || s.customFields?.id_proof || '';

  // 1. Resolve active Custom Field definitions and Form Template sections
  let allCustomFieldDefs = [];
  if (Array.isArray(opts.customFields) && opts.customFields.length > 0) {
    allCustomFieldDefs = opts.customFields;
  } else if (typeof window !== 'undefined') {
    allCustomFieldDefs = window.store?.customFields || window.store?.settings?.customFields || window.FormBuilder?.allFields || [];
    if (!allCustomFieldDefs || allCustomFieldDefs.length === 0) {
      try {
        const cached = JSON.parse(localStorage.getItem('sl_custom_fields_cache') || '[]');
        if (Array.isArray(cached) && cached.length > 0) allCustomFieldDefs = cached;
      } catch (e) {}
    }
  }

  let allTemplateSections = [];
  if (opts.templateConfig && Array.isArray(opts.templateConfig.sections)) {
    allTemplateSections = opts.templateConfig.sections;
  } else if (typeof window !== 'undefined') {
    allTemplateSections = window.store?.formTemplate?.sections || window.store?.settings?.formTemplate?.sections || window.FormBuilder?.sections || [];
    if (!allTemplateSections || allTemplateSections.length === 0) {
      try {
        const cachedTpl = JSON.parse(localStorage.getItem('sl_form_template_cache') || '{}');
        if (Array.isArray(cachedTpl?.sections)) allTemplateSections = cachedTpl.sections;
      } catch (e) {}
    }
  }

  // Format human-friendly label fallback from camelCase or snake_case or SCREAMING_SNAKE_CASE
  function formatHumanLabel(rawKey) {
    if (!rawKey) return '';
    let str = String(rawKey).trim();
    if (str.includes('___')) {
      str = str.replace(/___/g, ' / ');
    }
    str = str.replace(/_/g, ' ');
    str = str.replace(/([a-z])([A-Z])/g, '$1 $2');
    return str
      .split(' ')
      .filter(Boolean)
      .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
      .join(' ')
      .replace(/\s*\/\s*/g, ' / ');
  }

  // Form Builder Custom Fields & Uploaded Document Attachments Extraction
  const customFieldEntries = [];
  const uploadedDocEntries = [];

  const coreExcluded = new Set([
    'name', 'fullname', 'phone', 'mobile', 'email', 'gender', 'dob', 'dateofbirth', 'birthdate',
    'photo', 'signature', 'seat', 'plan', 'status', 'branch', 'shift', 'feeamount',
    'idproofimage', 'idproof', 'idprooftype', 'idproofnumber', 'targetexams', 'target_exams', 'competitive_exams',
    'address', 'city', 'state', 'pincode', 'bloodgroup', 'blood_group', 'emergencycontact', 'emergencycontactname',
    'emergencycontactphone', 'emergencycontactrelation', 'parentphone', 'fathername', 'rfidcardnumber', 'biometricid',
    'parentguardianname', 'parent___guardian_name', 'parentname', 'guardianname', 'relationship', 'relation',
    'whatsapp', 'alternatephone', 'altphone', 'lockernumber', 'occupation', 'collegeorcompany', 'college', 'company'
  ]);

  function processCustomField(key, val) {
    if (val === undefined || val === null || val === '') return;
    const cleanKey = key.toLowerCase().replace(/[^a-z0-9]/g, '');
    if (coreExcluded.has(cleanKey)) return;

    // Match against configured custom field definition
    const def = allCustomFieldDefs.find(f => {
      const fn = (f.fieldName || f.name || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      const fl = (f.label || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      return fn === cleanKey || fl === cleanKey;
    });

    const label = def?.label || formatHumanLabel(key);
    const section = def?.section || 'additional';
    const order = def?.order !== undefined ? def.order : 999;
    const strVal = String(val).trim();

    // Check if value is an uploaded image / document
    if (strVal.startsWith('data:image/') || strVal.startsWith('http://') || strVal.startsWith('https://') || strVal.startsWith('/uploads/') || strVal.includes('res.cloudinary.com')) {
      uploadedDocEntries.push({ label: label, url: strVal });
    } else {
      let formattedVal = strVal;
      if (typeof val === 'boolean' || strVal === 'true' || strVal === 'false') {
        formattedVal = (val === true || strVal === 'true') ? 'Yes' : 'No';
      }
      customFieldEntries.push({
        key,
        label,
        value: formattedVal,
        section,
        order,
        type: def?.type || 'text'
      });
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
    if (!uploadedDocEntries.some(d => d.url === idProofImage)) {
      uploadedDocEntries.unshift({ label: `${idProofType} KYC Document Scan`, url: idProofImage });
    }
  }

  // Group custom fields by sections as configured in Form Builder
  const sectionGroups = [];
  const secIcons = {
    personal: '👤',
    academic: '🎯',
    plan: '⏰',
    payment: '💳',
    seat: '🪑',
    contact: '📍',
    kyc: '🪪',
    parent: '👨‍👩‍👧',
    vehicle: '🚗',
    transport: '🚲',
    custom: '📋',
    additional: '📋',
    other: '📝'
  };

  if (allTemplateSections.length > 0) {
    allTemplateSections.forEach(sec => {
      const matchingFields = customFieldEntries
        .filter(f => f.section === sec.name)
        .sort((a, b) => a.order - b.order);
      
      if (matchingFields.length > 0) {
        sectionGroups.push({
          name: sec.name,
          label: sec.label || formatHumanLabel(sec.name),
          icon: sec.icon && sec.icon.length <= 4 ? sec.icon : (secIcons[sec.name] || '📋'),
          fields: matchingFields
        });
      }
    });

    const handledKeys = new Set(sectionGroups.flatMap(g => g.fields.map(f => f.key)));
    const unhandled = customFieldEntries.filter(f => !handledKeys.has(f.key));
    if (unhandled.length > 0) {
      sectionGroups.push({
        name: 'additional',
        label: 'Additional Registration Information',
        icon: '📋',
        fields: unhandled.sort((a, b) => a.order - b.order)
      });
    }
  } else {
    const secMap = new Map();
    customFieldEntries.forEach(f => {
      const sName = f.section || 'additional';
      if (!secMap.has(sName)) {
        secMap.set(sName, {
          name: sName,
          label: formatHumanLabel(sName),
          icon: secIcons[sName] || '📋',
          fields: []
        });
      }
      secMap.get(sName).fields.push(f);
    });
    secMap.forEach(g => {
      g.fields.sort((a, b) => a.order - b.order);
      sectionGroups.push(g);
    });
  }

  // Photo & Signature & Stamp URLs
  const winStore = typeof window !== 'undefined' ? window.store : null;
  const photoUrl = s.photo || s.photoUrl || s.customFields?.photo || s.customFields?.passport_photo || s.avatar || winStore?.user?.photo || winStore?.user?.avatar || '';
  const sigUrl = s.signature || s.signatureUrl || s.customFields?.signature || '';
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

      <!-- 5. Form Builder Custom Questions & Sections (Organized matching Admin Form Builder) -->
      ${sectionGroups.map(grp => `
        <div class="sec-card">
          <div class="sec-title">${grp.icon} ${escapeHTML(grp.label)}</div>
          <div class="grid-2">
            ${grp.fields.map(e => `
              <div style="margin-bottom: 2px;">
                <div class="field-label">${escapeHTML(e.label)}</div>
                <div class="field-value" style="font-size: 10px;">${escapeHTML(e.value)}</div>
              </div>
            `).join('')}
          </div>
        </div>
      `).join('')}

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
  const opts = { ...options };
  try {
    const token = (typeof localStorage !== 'undefined') ? (localStorage.getItem('sl_token') || localStorage.getItem('token')) : null;
    const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
    
    const [stuRes, cfRes, tplRes] = await Promise.all([
      (student && student._id && (!student.plan?.name || !student.shift?.name || !student.branch?.name || !student.idProof?.image))
        ? fetch(`/api/students/${student._id}`, { headers }).then(r => r.json()).catch(() => null)
        : null,
      (!opts.customFields)
        ? fetch('/api/custom-fields/all', { headers }).then(r => r.json()).catch(() => null)
        : null,
      (!opts.templateConfig)
        ? fetch('/api/custom-fields/templates/active', { headers }).then(r => r.json()).catch(() => null)
        : null
    ]);

    if (stuRes?.success && stuRes?.data) fullStudent = stuRes.data;
    if (cfRes?.success && Array.isArray(cfRes.data)) opts.customFields = cfRes.data;
    if (tplRes?.success && tplRes.data) opts.templateConfig = tplRes.data;
  } catch (e) {}

  const htmlContent = buildAdmissionFormHTML(fullStudent, opts);
  
  // Try popup window first on desktop
  let printWindow = null;
  try {
    printWindow = window.open('', '_blank', 'width=900,height=1100');
  } catch (_) {}

  if (printWindow) {
    printWindow.document.open();
    printWindow.document.write(htmlContent + `
      <script>
        window.onload = function() {
          setTimeout(() => { window.print(); }, 400);
        };
      </script>
    `);
    printWindow.document.close();
  } else {
    // Mobile / Popup-blocked Fallback: Sandboxed hidden iframe
    let printFrame = document.getElementById('pdf-print-sandbox-frame');
    if (!printFrame) {
      printFrame = document.createElement('iframe');
      printFrame.id = 'pdf-print-sandbox-frame';
      printFrame.style.position = 'fixed';
      printFrame.style.right = '0';
      printFrame.style.bottom = '0';
      printFrame.style.width = '0';
      printFrame.style.height = '0';
      printFrame.style.border = '0';
      document.body.appendChild(printFrame);
    }
    const doc = printFrame.contentWindow.document;
    doc.open();
    doc.write(htmlContent);
    doc.close();
    setTimeout(() => {
      try {
        printFrame.contentWindow.focus();
        printFrame.contentWindow.print();
      } catch (err) {
        window.print();
      }
    }, 500);
  }
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
    z-index: 2147483647; display: flex; flex-direction: column;
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

  // Asynchronously fetch fresh full student record, custom fields & template to guarantee exact labels & section ordering
  (async () => {
    try {
      const token = (typeof localStorage !== 'undefined') ? (localStorage.getItem('sl_token') || localStorage.getItem('token')) : null;
      const headers = token ? { 'Authorization': `Bearer ${token}` } : {};

      const [stuRes, cfRes, tplRes, bizRes] = await Promise.all([
        student?._id ? fetch(`/api/students/${student._id}`, { headers }).then(r => r.json()).catch(() => null) : null,
        fetch('/api/custom-fields/all', { headers }).then(r => r.json()).catch(() => null),
        fetch('/api/custom-fields/templates/active', { headers }).then(r => r.json()).catch(() => null),
        (!currentOpts.business || !currentOpts.business.businessName || currentOpts.business.businessName === 'Study Library Management')
          ? fetch('/api/settings', { headers }).then(r => r.json()).catch(() => null)
          : null
      ]);

      if (stuRes?.success && stuRes?.data) activeStudent = stuRes.data;
      if (cfRes?.success && Array.isArray(cfRes.data)) {
        currentOpts.customFields = cfRes.data;
        try { localStorage.setItem('sl_custom_fields_cache', JSON.stringify(cfRes.data)); } catch (e) {}
      }
      if (tplRes?.success && tplRes.data) {
        currentOpts.templateConfig = tplRes.data;
        try { localStorage.setItem('sl_form_template_cache', JSON.stringify(tplRes.data)); } catch (e) {}
      }
      if (bizRes?.success && bizRes?.data?.businessProfile) {
        currentOpts.business = bizRes.data.businessProfile;
        if (bizRes.data.receipt) currentOpts.receiptConfig = bizRes.data.receipt;
      }

      updateIframePreview();
    } catch (e) {}
  })();

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

/**
 * 🧾 Universal Receipt Generator for POS Thermal (80mm/58mm), Standard A4 & Modern Digital Pass
 * Strictly obeys Admin's ReceiptConfig visibility flags across all formats.
 */
export function buildReceiptHTML(payment = {}, options = {}) {
  const rc = options.receiptConfig || (typeof window !== 'undefined' ? window.store?.settings?.receipt : {}) || {};
  const bp = options.businessProfile || options.business || (typeof window !== 'undefined' ? window.store?.profile : {}) || {};
  
  // Format normalization: 'thermal80', 'thermal58', 'standardA4', 'modern_minimal'
  let rawTemplate = options.template || rc.activeTemplate || 'thermal80';
  let format = 'thermal80';
  if (rawTemplate === 'thermal_58' || rawTemplate === 'thermal58') format = 'thermal58';
  else if (rawTemplate === 'standard_a4' || rawTemplate === 'standardA4' || rawTemplate === 'gst_invoice') format = 'standardA4';
  else if (rawTemplate === 'modern_minimal' || rawTemplate === 'digital') format = 'modern_minimal';
  else format = 'thermal80';

  const head = rc.header || {};
  const bdy = rc.body || {};
  const stp = rc.stamp || {};
  const ftr = rc.footer || {};
  const dt = rc.dateTime || {};
  const gst = rc.gst || {};

  const bizName = bp.businessName || 'Study Library';
  const address = bp.address || '';
  const phone = bp.phone || '';
  const email = bp.email || '';
  const gstin = head.gstNumber || bp.gstNumber || '';
  const taxNumber = head.taxNumber || bp.registrationNumber || '';
  const logoUrl = head.logoUrl || bp.logo || bp.logoUrl || '';
  const upiId = bp.upiId || 'library@upi';

  const subtitle = head.subtitle || 'Official Fee Payment Receipt';
  const headerColor = head.headerColor || '#4f46e5';

  const showLogo = head.showLogo !== false && Boolean(logoUrl);
  const showBusinessName = head.showBusinessName !== false;
  const showAddress = head.showAddress !== false && Boolean(address);
  const showPhone = head.showPhone !== false && Boolean(phone);
  const showEmail = head.showEmail !== false && Boolean(email);
  const showGst = head.showGst !== false && Boolean(gstin);

  const showStuId = bdy.showStudentId !== false;
  const showStuPhone = bdy.showStudentPhone !== false;
  const showSeat = bdy.showSeatNumber !== false;
  const showShift = bdy.showShift !== false;
  const showPeriod = bdy.showPeriod !== false;
  const showBreakdown = bdy.showDiscount !== false && bdy.showPlanDetails !== false;
  const showPaymentMode = bdy.showPaymentMethod !== false;
  const showTxnId = bdy.showTransactionId !== false && showPaymentMode;

  const showStamp = stp.showStamp !== false;
  const stampText = stp.stampText || 'PAID • OFFICIAL RECEIPT';
  const stampColor = stp.stampColor || '#059669';
  const stampImg = stp.stampImage || ftr.stampImage || bp.stampImage || '';

  const showSignature = ftr.showSignature !== false;
  const signatureLabel = ftr.signatureLabel || 'Authorized Signatory';
  const sigImg = ftr.signatureImage || '';

  const showUpiQr = Boolean(ftr.showUpiQr);
  const showTimestamp = dt.showTimestamp !== false && ftr.showTimestamp !== false;
  const termsText = ftr.termsText || 'This is an authorized computer-generated fee receipt.';
  const customNote = ftr.customNote || 'Thank you for choosing our study library!';

  // Payment data extraction
  const p = payment || {};
  const receiptNo = p.receiptNumber || (p._id ? `REC-${String(p._id).slice(-6).toUpperCase()}` : 'REC-001');
  const pDate = p.paymentDate || p.createdAt || p.date || new Date();
  const dateObj = new Date(pDate);
  const formattedDate = dateObj.toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const timeStr = dateObj.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
  const fullDateTime = showTimestamp ? `${formattedDate} ${timeStr}` : formattedDate;

  const studentObj = (p.student && typeof p.student === 'object') ? p.student : {};
  const studentName = studentObj.name || p.studentName || 'Student Member';
  const studentId = studentObj.studentId || p.studentId || 'N/A';
  const studentPhone = studentObj.phone || p.phone || '';
  const seatName = (studentObj.seat && typeof studentObj.seat === 'object') ? studentObj.seat.seatNumber : (studentObj.seat || p.seatNumber || '');
  const shiftName = (studentObj.shift && typeof studentObj.shift === 'object') ? studentObj.shift.name : (studentObj.shift || p.shiftName || '');

  const planObj = (p.plan && typeof p.plan === 'object') ? p.plan : {};
  const planName = planObj.name || p.planName || 'Study Space Membership';

  const paidAmount = Number(p.finalAmount !== undefined ? p.finalAmount : (p.amount || 0));
  const baseAmount = Number(p.amount !== undefined ? p.amount : paidAmount);
  const discountAmount = Number(p.discount || (baseAmount > paidAmount ? baseAmount - paidAmount : 0));
  const paymentMethod = (p.paymentMethod || p.method || 'UPI').toUpperCase();
  const txnId = p.transactionId || p.utrNumber || p.utr || '';

  const validFrom = p.periodStart ? new Date(p.periodStart).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '';
  const validUntil = p.periodEnd ? new Date(p.periodEnd).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '';
  const validityText = (validFrom && validUntil) ? `${validFrom} – ${validUntil}` : '';

  // 1. STANDARD A4 INVOICE FORMAT
  if (format === 'standardA4') {
    return `
      <div class="receipt-document format-standard-a4" style="width: 100%; max-width: 680px; margin: 0 auto; background: #fff; color: #111827; padding: 28px; font-family: 'Inter', Arial, sans-serif; box-sizing: border-box; position: relative; overflow: hidden; border: 1px solid #e5e7eb; border-radius: 8px;">
        
        <!-- Header -->
        <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2.5px solid ${headerColor}; padding-bottom: 16px; margin-bottom: 18px; gap: 16px;">
          <div>
            ${showLogo ? `<img src="${logoUrl}" style="max-height: 54px; max-width: 120px; object-fit: contain; margin-bottom: 8px;" alt="Logo"><br>` : ''}
            ${showBusinessName ? `<h2 style="margin: 0; font-size: 1.35rem; font-weight: 800; color: ${headerColor}; text-transform: uppercase;">${escapeHTML(bizName)}</h2>` : ''}
            <div style="font-size: 0.85rem; font-weight: 700; color: #4b5563; margin-top: 2px;">${escapeHTML(subtitle)}</div>
            ${showAddress ? `<div style="font-size: 0.78rem; color: #6b7280; margin-top: 3px;">${escapeHTML(address)}</div>` : ''}
            <div style="font-size: 0.78rem; color: #6b7280;">
              ${showPhone ? `<span>📞 ${escapeHTML(phone)}</span>` : ''}
              ${showEmail ? `<span style="margin-left: 8px;">✉️ ${escapeHTML(email)}</span>` : ''}
            </div>
            ${showGst ? `<div style="font-size: 0.78rem; font-weight: 700; color: #1f2937; margin-top: 2px;">GSTIN: ${escapeHTML(gstin)}</div>` : ''}
          </div>
          <div style="text-align: right;">
            <div style="font-size: 0.75rem; font-weight: 700; color: #6b7280; text-transform: uppercase;">RECEIPT NUMBER</div>
            <div style="font-size: 1.15rem; font-weight: 900; font-family: monospace; color: #111827;">${escapeHTML(receiptNo)}</div>
            <div style="font-size: 0.75rem; color: #6b7280; margin-top: 6px;">Date: <strong>${fullDateTime}</strong></div>
            ${showStamp ? `
              <div style="display: inline-block; margin-top: 10px; border: 2px dashed ${stampColor}; color: ${stampColor}; font-weight: 800; font-size: 0.8rem; padding: 4px 10px; border-radius: 4px; text-transform: uppercase; transform: rotate(-5deg); background: rgba(255,255,255,0.9);">
                ✔ ${escapeHTML(stampText)}
              </div>
            ` : ''}
          </div>
        </div>

        <!-- Student & Allotment Information Box -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 12px 16px; margin-bottom: 18px; font-size: 0.82rem;">
          <div>
            <div style="font-size: 0.7rem; font-weight: 700; color: #6b7280; text-transform: uppercase;">STUDENT DETAILS</div>
            <div style="font-weight: 800; font-size: 0.95rem; color: #111827; margin-top: 2px;">${escapeHTML(studentName)}</div>
            ${showStuId ? `<div style="font-family: monospace; color: #4b5563;">ID: ${escapeHTML(studentId)}</div>` : ''}
            ${showStuPhone && studentPhone ? `<div>Phone: ${escapeHTML(studentPhone)}</div>` : ''}
          </div>
          <div>
            <div style="font-size: 0.7rem; font-weight: 700; color: #6b7280; text-transform: uppercase;">ADMISSION &amp; DESK</div>
            ${showSeat && seatName ? `<div>Allocated Seat: <strong>Desk #${escapeHTML(seatName)}</strong></div>` : ''}
            ${showShift && shiftName ? `<div>Shift Timing: <strong>${escapeHTML(shiftName)}</strong></div>` : ''}
            ${showPeriod && validityText ? `<div style="color: #059669; font-weight: 700; margin-top: 2px;">Validity: ${escapeHTML(validityText)}</div>` : ''}
          </div>
        </div>

        <!-- Line Items Table -->
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 18px; font-size: 0.84rem;">
          <thead>
            <tr style="background: #f3f4f6; border-bottom: 2px solid #e5e7eb; color: #374151; font-weight: 700; text-transform: uppercase; font-size: 0.74rem;">
              <th style="padding: 8px 10px; text-align: left;">Description</th>
              <th style="padding: 8px 10px; text-align: right;">Amount (₹)</th>
            </tr>
          </thead>
          <tbody>
            <tr style="border-bottom: 1px solid #e5e7eb;">
              <td style="padding: 10px 10px;">
                <strong>${escapeHTML(planName)}</strong>
                ${validityText ? `<div style="font-size: 0.75rem; color: #6b7280;">Duration: ${escapeHTML(validityText)}</div>` : ''}
              </td>
              <td style="padding: 10px 10px; text-align: right; font-weight: 600;">₹${baseAmount.toFixed(2)}</td>
            </tr>
            ${(showBreakdown && discountAmount > 0) ? `
              <tr style="border-bottom: 1px solid #e5e7eb; color: #dc2626;">
                <td style="padding: 6px 10px;">Discount Applied</td>
                <td style="padding: 6px 10px; text-align: right; font-weight: 600;">-₹${discountAmount.toFixed(2)}</td>
              </tr>
            ` : ''}
          </tbody>
          <tfoot>
            <tr style="border-top: 2px solid #111827; font-weight: 800; font-size: 1rem;">
              <td style="padding: 10px 10px;">TOTAL AMOUNT PAID:</td>
              <td style="padding: 10px 10px; text-align: right; color: #059669;">₹${paidAmount.toFixed(2)}</td>
            </tr>
          </tfoot>
        </table>

        <!-- Payment Mode & Reference Block (Strictly Hidden if Admin unchecks Payment Mode) -->
        ${showPaymentMode ? `
          <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 10px 14px; margin-bottom: 16px; font-size: 0.8rem; display: flex; justify-content: space-between; align-items: center;">
            <div>
              <span>Payment Mode: <strong>${escapeHTML(paymentMethod)}</strong></span>
              ${showTxnId && txnId ? `<span style="margin-left: 10px; font-family: monospace; color: #475569;">(Ref / Txn ID: ${escapeHTML(txnId)})</span>` : ''}
            </div>
            <span style="font-size: 0.75rem; font-weight: 800; color: #047857; background: #d1fae5; padding: 2px 8px; border-radius: 4px;">
              PAID &amp; SETTLED ✓
            </span>
          </div>
        ` : ''}

        <!-- Terms, Footer & Signature Block -->
        <div style="display: flex; justify-content: space-between; align-items: flex-end; border-top: 1px solid #e5e7eb; padding-top: 14px; margin-top: 12px; gap: 16px;">
          <div style="font-size: 0.72rem; color: #6b7280; max-width: 65%;">
            ${customNote ? `<div style="font-weight: 700; color: #1f2937; margin-bottom: 4px;">${escapeHTML(customNote)}</div>` : ''}
            ${termsText ? `<div>${escapeHTML(termsText)}</div>` : ''}
          </div>
          ${showSignature ? `
            <div style="text-align: center; min-width: 140px;">
              ${sigImg ? `<img src="${sigImg}" style="max-height: 40px; margin-bottom: 4px;" alt="Signature"><br>` : '<div style="height: 34px;"></div>'}
              <div style="border-top: 1.5px solid #111827; padding-top: 4px; font-size: 0.72rem; font-weight: 700; color: #111827;">${escapeHTML(signatureLabel)}</div>
            </div>
          ` : ''}
        </div>

      </div>
    `;
  }

  // 2. MODERN DIGITAL PASS FORMAT
  if (format === 'modern_minimal') {
    return `
      <div class="receipt-document format-modern-digital" style="width: 100%; max-width: 420px; margin: 0 auto; background: #ffffff; color: #0f172a; padding: 22px; font-family: 'Inter', Arial, sans-serif; box-sizing: border-box; border-radius: 12px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; position: relative;">
        
        <!-- Header -->
        <div style="text-align: center; border-bottom: 2px solid ${headerColor}; padding-bottom: 12px; margin-bottom: 14px;">
          ${showLogo ? `<img src="${logoUrl}" style="max-height: 44px; max-width: 90px; object-fit: contain; margin-bottom: 6px;" alt="Logo"><br>` : ''}
          ${showBusinessName ? `<h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: ${headerColor}; text-transform: uppercase;">${escapeHTML(bizName)}</h3>` : ''}
          <div style="font-size: 0.78rem; font-weight: 700; color: #64748b; margin-top: 2px;">${escapeHTML(subtitle)}</div>
          ${showAddress ? `<div style="font-size: 0.72rem; color: #64748b; margin-top: 2px;">${escapeHTML(address)}</div>` : ''}
          ${(showPhone || showEmail) ? `<div style="font-size: 0.72rem; color: #64748b;">${showPhone ? `📞 ${escapeHTML(phone)} ` : ''}${showEmail ? `✉️ ${escapeHTML(email)}` : ''}</div>` : ''}
          ${showGst ? `<div style="font-size: 0.72rem; font-weight: 700; color: #334155; margin-top: 2px;">GSTIN: ${escapeHTML(gstin)}</div>` : ''}
        </div>

        <!-- Receipt Metadata Grid -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px 12px; font-size: 0.78rem; margin-bottom: 14px; background: #f8fafc; padding: 10px 12px; border-radius: 8px; border: 1px solid #e2e8f0;">
          <div>
            <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">RECEIPT NO.</div>
            <div style="font-weight: 800; font-family: monospace; color: #0f172a;">${escapeHTML(receiptNo)}</div>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">DATE &amp; TIME</div>
            <div style="font-weight: 600; color: #0f172a;">${fullDateTime}</div>
          </div>
          <div>
            <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">STUDENT NAME</div>
            <div style="font-weight: 800; color: #0f172a;">${escapeHTML(studentName)}</div>
            ${showStuId ? `<div style="font-size: 0.68rem; color: #64748b; font-family: monospace;">ID: ${escapeHTML(studentId)}</div>` : ''}
          </div>
          <div style="text-align: right;">
            ${showSeat && seatName ? `
              <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">ALLOCATED DESK</div>
              <div style="font-weight: 700; color: #047857;">Desk #${escapeHTML(seatName)}</div>
            ` : ''}
            ${showShift && shiftName ? `<div style="font-size: 0.68rem; color: #64748b;">${escapeHTML(shiftName)}</div>` : ''}
          </div>
          ${showPeriod && validityText ? `
            <div style="grid-column: span 2; border-top: 1px dashed #cbd5e1; padding-top: 4px; margin-top: 2px;">
              <span style="font-size: 0.68rem; color: #64748b;">Validity:</span>
              <strong style="color: #059669; margin-left: 4px;">${escapeHTML(validityText)}</strong>
            </div>
          ` : ''}
        </div>

        <!-- Plan Description & Total -->
        <div style="border-bottom: 1.5px dashed #cbd5e1; padding-bottom: 10px; margin-bottom: 12px; font-size: 0.82rem;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span>${escapeHTML(planName)}</span>
            <span style="font-weight: 600;">₹${baseAmount.toFixed(2)}</span>
          </div>
          ${(showBreakdown && discountAmount > 0) ? `
            <div style="display: flex; justify-content: space-between; color: #dc2626; font-size: 0.76rem;">
              <span>Special Discount</span>
              <span>-₹${discountAmount.toFixed(2)}</span>
            </div>
          ` : ''}
          <div style="display: flex; justify-content: space-between; font-weight: 800; font-size: 1.05rem; margin-top: 8px; border-top: 1.5px solid #0f172a; padding-top: 6px;">
            <span>TOTAL PAID:</span>
            <span style="color: #059669;">₹${paidAmount.toFixed(2)}</span>
          </div>
        </div>

        <!-- Payment Mode & Reference (Strictly Hidden if Admin unchecks Payment Mode) -->
        ${showPaymentMode ? `
          <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.74rem; color: #475569; border-bottom: 1px solid #e2e8f0; padding-bottom: 8px; margin-bottom: 10px;">
            <div>
              <span>Mode: <strong style="color: #0f172a;">${escapeHTML(paymentMethod)}</strong></span>
              ${showTxnId && txnId ? `<div style="font-family: monospace; font-size: 0.68rem; color: #64748b;">Txn: ${escapeHTML(txnId)}</div>` : ''}
            </div>
            <span style="font-size: 0.68rem; font-weight: 700; color: #047857; background: #d1fae5; padding: 2px 7px; border-radius: 4px; border: 1px solid #10b981;">
              PAID &amp; VERIFIED ✓
            </span>
          </div>
        ` : ''}

        <!-- Official Stamp -->
        ${showStamp ? `
          <div style="text-align: center; margin: 10px 0;">
            <div style="display: inline-block; border: 2px solid ${stampColor}; color: ${stampColor}; font-weight: 800; font-size: 0.85rem; padding: 3px 12px; border-radius: 6px; text-transform: uppercase; transform: rotate(-2deg);">
              ✔ ${escapeHTML(stampText)}
            </div>
          </div>
        ` : ''}

        <!-- Dynamic UPI QR -->
        ${showUpiQr ? `
          <div style="text-align: center; margin: 8px 0; padding: 6px; background: #f8fafc; border-radius: 6px; border: 1px solid #e2e8f0;">
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=${encodeURIComponent('upi://pay?pa=' + upiId + '&pn=' + bizName + '&am=0&cu=INR')}" style="width: 70px; height: 70px; display: block; margin: 0 auto 3px;" alt="QR">
            <div style="font-size: 0.62rem; font-weight: 700; color: #475569;">Scan to Verify via UPI</div>
          </div>
        ` : ''}

        <!-- Footer -->
        <div style="text-align: center; font-size: 0.68rem; color: #94a3b8; margin-top: 8px;">
          ${customNote ? `<div style="font-weight: 700; color: #475569; margin-bottom: 2px;">${escapeHTML(customNote)}</div>` : ''}
          ${termsText ? `<div>${escapeHTML(termsText)}</div>` : ''}
        </div>

      </div>
    `;
  }

  // 3. POS THERMAL 80mm & 58mm FORMATS
  const is58 = format === 'thermal58';
  const paperWidth = is58 ? '260px' : '340px';
  const fontSize = is58 ? '11px' : '12.5px';

  return `
    <div class="receipt-document format-thermal" style="width: ${paperWidth}; max-width: 100%; margin: 0 auto; background: #ffffff; color: #111827; padding: ${is58 ? '12px 10px' : '18px 16px'}; font-family: 'Courier New', Courier, monospace; font-size: ${fontSize}; line-height: 1.4; box-sizing: border-box;">
      
      <!-- Receipt Header -->
      <div style="text-align: center; border-bottom: 1.5px dashed #333; padding-bottom: 8px; margin-bottom: 8px;">
        ${showLogo ? `<img src="${logoUrl}" style="max-height: ${is58 ? '36px' : '44px'}; max-width: 100px; object-fit: contain; margin-bottom: 4px;" alt="Logo"><br>` : ''}
        ${showBusinessName ? `<div style="font-weight: 800; font-size: ${is58 ? '0.95rem' : '1.05rem'}; text-transform: uppercase; color: ${headerColor}; letter-spacing: 0.5px;">${escapeHTML(bizName)}</div>` : ''}
        <div style="font-size: 0.78rem; font-weight: 700; color: #555; text-transform: uppercase;">${escapeHTML(subtitle)}</div>
        ${showAddress ? `<div style="font-size: 0.72rem; color: #444; margin-top: 2px;">${escapeHTML(address)}</div>` : ''}
        ${(showPhone || showEmail) ? `<div style="font-size: 0.72rem; color: #444;">${showPhone ? `Tel: ${escapeHTML(phone)} ` : ''}${showEmail ? `• ${escapeHTML(email)}` : ''}</div>` : ''}
        ${showGst ? `<div style="font-size: 0.72rem; font-weight: 700; color: #222; margin-top: 2px;">GSTIN: ${escapeHTML(gstin)}</div>` : ''}
      </div>

      <!-- Receipt Metadata -->
      <div style="border-bottom: 1px dashed #666; padding-bottom: 6px; margin-bottom: 6px; font-size: 0.8rem;">
        <div style="display: flex; justify-content: space-between;">
          <span>Receipt No:</span>
          <strong style="font-family: monospace;">${escapeHTML(receiptNo)}</strong>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span>Date &amp; Time:</span>
          <span>${fullDateTime}</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span>Student Name:</span>
          <strong>${escapeHTML(studentName)}</strong>
        </div>
        ${showStuId ? `
          <div style="display: flex; justify-content: space-between;">
            <span>Student ID:</span>
            <span style="font-family: monospace;">${escapeHTML(studentId)}</span>
          </div>
        ` : ''}
        ${showStuPhone && studentPhone ? `
          <div style="display: flex; justify-content: space-between;">
            <span>Phone:</span>
            <span>${escapeHTML(studentPhone)}</span>
          </div>
        ` : ''}
        ${showSeat && seatName ? `
          <div style="display: flex; justify-content: space-between;">
            <span>Allocated Seat:</span>
            <strong>Desk #${escapeHTML(seatName)}</strong>
          </div>
        ` : ''}
        ${showShift && shiftName ? `
          <div style="display: flex; justify-content: space-between;">
            <span>Shift Timing:</span>
            <span>${escapeHTML(shiftName)}</span>
          </div>
        ` : ''}
        ${showPeriod && validityText ? `
          <div style="display: flex; justify-content: space-between; margin-top: 2px;">
            <span>Validity:</span>
            <strong style="color: #059669;">${escapeHTML(validityText)}</strong>
          </div>
        ` : ''}
      </div>

      <!-- Line Items / Fee Breakdown -->
      ${showBreakdown ? `
        <div style="border-bottom: 1.5px dashed #333; padding-bottom: 6px; margin-bottom: 6px; font-size: 0.8rem;">
          <div style="display: flex; justify-content: space-between; font-weight: 700; border-bottom: 1px solid #ddd; padding-bottom: 2px; margin-bottom: 3px;">
            <span>Description</span>
            <span>Amount (₹)</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>${escapeHTML(planName)}</span>
            <span>${baseAmount.toFixed(2)}</span>
          </div>
          ${discountAmount > 0 ? `
            <div style="display: flex; justify-content: space-between; color: #dc2626;">
              <span>Special Discount</span>
              <span>-${discountAmount.toFixed(2)}</span>
            </div>
          ` : ''}
        </div>
      ` : ''}

      <!-- Total Paid & Payment Method -->
      <div style="border-bottom: 1.5px dashed #333; padding-bottom: 6px; margin-bottom: 6px;">
        <div style="display: flex; justify-content: space-between; font-weight: 800; font-size: 0.95rem;">
          <span>TOTAL PAID:</span>
          <span>₹${paidAmount.toFixed(2)}</span>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 0.76rem; color: #059669; font-weight: 700; margin-top: 2px;">
          <span>Balance Due:</span>
          <span>₹0.00 (PAID IN FULL)</span>
        </div>
        ${showPaymentMode ? `
          <div style="display: flex; justify-content: space-between; font-size: 0.76rem; color: #444; margin-top: 3px;">
            <span>Payment Mode:</span>
            <span>${escapeHTML(paymentMethod)}</span>
          </div>
          ${showTxnId && txnId ? `
            <div style="display: flex; justify-content: space-between; font-size: 0.72rem; color: #666; font-family: monospace;">
              <span>Txn Ref / UTR:</span>
              <span>${escapeHTML(txnId)}</span>
            </div>
          ` : ''}
        ` : ''}
      </div>

      <!-- Paid Official Stamp -->
      ${showStamp ? `
        <div style="text-align: center; margin: 8px 0;">
          ${stampImg ? `<img src="${stampImg}" style="max-height: 40px; margin-bottom: 2px;" alt="Stamp"><br>` : ''}
          <div style="display: inline-block; border: 2px solid ${stampColor}; color: ${stampColor}; font-weight: 900; font-size: 0.85rem; padding: 3px 10px; border-radius: 4px; text-transform: uppercase; transform: rotate(-3deg);">
            ✔ ${escapeHTML(stampText)}
          </div>
        </div>
      ` : ''}

      <!-- Dynamic UPI QR -->
      ${showUpiQr ? `
        <div style="text-align: center; margin: 8px 0; padding: 6px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 4px;">
          <img src="https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=${encodeURIComponent('upi://pay?pa=' + upiId + '&pn=' + bizName + '&am=0&cu=INR')}" style="width: 70px; height: 70px; display: block; margin: 0 auto 3px;" alt="UPI QR">
          <div style="font-size: 0.62rem; font-weight: 700; color: #374151;">Scan to Verify via UPI</div>
        </div>
      ` : ''}

      <!-- Terms & Signature -->
      <div style="font-size: 0.7rem; color: #4b5563; margin-top: 6px;">
        ${customNote ? `<div style="font-weight: 700; text-align: center; margin-bottom: 4px; color: #111827;">${escapeHTML(customNote)}</div>` : ''}
        ${termsText ? `<div style="line-height: 1.25; font-size: 0.65rem; color: #6b7280; text-align: center; margin-bottom: 6px;">${escapeHTML(termsText)}</div>` : ''}
        
        ${showSignature ? `
          <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 10px; padding-top: 6px; border-top: 1px solid #eee;">
            <div style="font-size: 0.62rem; color: #9ca3af;">
              ${showTimestamp ? `Generated: ${formattedDate}` : ''}
            </div>
            <div style="text-align: center;">
              <div style="font-size: 0.68rem; font-weight: 700; color: #111827; border-top: 1px solid #111827; padding-top: 2px;">${escapeHTML(signatureLabel)}</div>
            </div>
          </div>
        ` : ''}
      </div>

    </div>
  `;
}

/**
 * 🖨️ Isolated Printer for Receipt Documents
 */
export function printReceiptDocument(payment, options = {}) {
  const rc = options.receiptConfig || (typeof window !== 'undefined' ? window.store?.settings?.receipt : {}) || {};
  let rawTemplate = options.template || rc.activeTemplate || 'thermal80';
  let widthCss = '80mm';
  if (rawTemplate === 'thermal_58' || rawTemplate === 'thermal58') widthCss = '58mm';
  else if (rawTemplate === 'standard_a4' || rawTemplate === 'standardA4' || rawTemplate === 'gst_invoice') widthCss = '210mm';
  else widthCss = '80mm';

  const receiptHtml = buildReceiptHTML(payment, options);
  const printWin = window.open('', '_blank', 'width=750,height=800');
  if (!printWin) {
    window.print();
    return;
  }

  printWin.document.open();
  printWin.document.write(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Receipt — ${payment?.receiptNumber || 'Receipt'}</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=Courier+Prime:wght@400;700&display=swap" rel="stylesheet">
      <style>
        @page { size: ${widthCss === '210mm' ? 'A4 portrait' : `${widthCss} auto`}; margin: 0; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          background: #ffffff !important;
          color: #000000 !important;
          width: ${widthCss};
          max-width: 100%;
          margin: 0 auto;
          padding: 8px;
          -webkit-font-smoothing: antialiased;
        }
        img { max-width: 100%; }
        @media print {
          body { width: ${widthCss}; margin: 0 auto; padding: 4px; }
          * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        }
      </style>
    </head>
    <body>
      ${receiptHtml}
      <script>
        window.onload = function() {
          setTimeout(function() {
            window.print();
            window.close();
          }, 350);
        };
      </script>
    </body>
    </html>
  `);
  printWin.document.close();
}

