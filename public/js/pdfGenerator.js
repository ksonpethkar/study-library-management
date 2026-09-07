function t(c){return c?String(c).replace(/[&<>"']/g,m=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[m]):""}function Se(c,m={}){const a={template:"modern_glass",showPhoto:!0,showSignature:!0,showQrCode:!0,showFormBuilderAnswers:!0,showUploadedDocuments:!0,showPaymentDetails:!0,showRules:!0,showWatermarkStamp:!0,...m},e=c||{};let r={};if(typeof localStorage<"u")try{r=JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")}catch{}const u=(typeof window<"u"?window.store?.settings?.businessProfile||window.store?.profile:null)||r||{},i=(m.business&&(m.business.businessName||m.business.name)?m.business:null)||u,d={businessName:i.businessName||i.name||"The Cozy Corner Centre",tagline:i.tagline||"Silence, Focus and Success",address:i.address||"",phone:i.phone||"",email:i.email||"",logo:i.logo||i.logoUrl||"",stampImage:i.stampImage||i.stamp||""},x=a.receiptConfig||(typeof window<"u"?window.store?.settings?.receipt:null)||{},f=x.header||{},g=x.footer||{},p=e.studentId||"STU-2026-0001",b=e.name||"Student Name",A=e.phone||"N/A",D=e.whatsappPhone||e.alternatePhone||e.customFields?.whatsapp||e.customFields?.alternate_phone||e.customFields?.alt_phone||"",$=e.email||"N/A",v=e.dateOfBirth||e.dob||e.birthDate||e.customFields&&(e.customFields.dateOfBirth||e.customFields.dob||e.customFields.dateofbirth||e.customFields.date_of_birth||e.customFields.birthDate||(e.customFields instanceof Map?e.customFields.get("dateOfBirth")||e.customFields.get("dob")||e.customFields.get("dateofbirth"):null)),he=v?new Date(v):null,Z=he&&!isNaN(he.getTime())?he.toLocaleDateString("en-IN",{day:"2-digit",month:"2-digit",year:"numeric"}):"N/A",ye=(e.gender||"Other").toUpperCase(),pe=e.bloodGroup||e.customFields?.bloodGroup||e.customFields?.blood_group||e.customFields?.bloodgroup||"N/A",T=e.pincode||e.customFields?.pincode||"N/A",q=e.city||e.customFields?.city||"N/A",W=e.state||e.customFields?.state||"N/A",ee=e.address||e.customFields?.address||"",Q=e.occupation||e.collegeOrCompany||e.customFields?.occupation||e.customFields?.college||e.customFields?.company||"Student / Aspirant",Y=e.branch?.name||e.branchName||"Main Branch",we=e.branch?.address||"",ce=e.plan?.name||e.planName||"Standard Study Membership",$e=e.plan?.price!==void 0?`\u20B9 ${e.plan.price}`:e.feeAmount?`\u20B9 ${e.feeAmount}`:"",te=e.plan?.duration?`${e.plan.duration} ${e.plan.durationType||"month(s)"}`:"";let E="";e.shift&&(e.shift.startTime||e.shift.endTime)?E=`${e.shift.name||"Shift"} (${e.shift.startTime||""} - ${e.shift.endTime||""})`:e.plan?.shift?E=String(e.plan.shift).toUpperCase():e.shift?E=typeof e.shift=="string"?e.shift.toUpperCase():(e.shift.name||"FULL DAY").toUpperCase():E="FULL DAY SHIFT";const me=e.seat?.seatNumber||e.seatNumber||"Floating Desk",fe=e.seat?.zone||e.seatZone||"General Zone",ie=e.seat?.floor?` \u2022 Floor: ${e.seat.floor}`:"",oe=e.locker?.lockerNumber||e.lockerNumber||e.customFields?.lockerNumber||e.customFields?.locker||"",U=e.admissionDate||e.joinedDate||e.createdAt?new Date(e.admissionDate||e.joinedDate||e.createdAt).toLocaleDateString("en-IN",{day:"2-digit",month:"2-digit",year:"numeric"}):new Date().toLocaleDateString("en-IN",{day:"2-digit",month:"2-digit",year:"numeric"}),ge=e.expiryDate?new Date(e.expiryDate).toLocaleDateString("en-IN",{day:"2-digit",month:"2-digit",year:"numeric"}):"N/A",C=(e.status||"active").toUpperCase(),N=C==="ACTIVE"||C==="PAID",Fe=m.stampText||(N?"PAID & VERIFIED":"PROVISIONAL ADMISSION"),ue=N?"#059669":"#d97706";let G=[];if(Array.isArray(e.targetExams)&&e.targetExams.length>0)G=e.targetExams;else if(typeof e.targetExams=="string"&&e.targetExams.trim())G=e.targetExams.split(",").map(o=>o.trim()).filter(Boolean);else if(e.customFields?.targetExams||e.customFields?.target_exams||e.customFields?.competitive_exams){const o=e.customFields.targetExams||e.customFields.target_exams||e.customFields.competitive_exams;G=Array.isArray(o)?o:String(o).split(",").map(n=>n.trim()).filter(Boolean)}const xe=e.emergencyContact?.name||e.emergencyContactName||e.customFields?.parent___guardian_name||e.customFields?.parentguardianname||e.customFields?.["Parent / Guardian Name"]||e.customFields?.["Emergency Contact Name"]||e.customFields?.["Father / Guardian Name"]||e.customFields?.parentName||e.customFields?.guardianName||e.customFields?.fatherName||e.customFields?.emergencyContactName||"",ve=e.emergencyContact?.phone||e.emergencyContactPhone||e.customFields?.emergencycontact||e.customFields?.emergencyContact||e.customFields?.["Emergency Contact Phone"]||e.customFields?.["Parent Phone"]||e.customFields?.parentPhone||"",V=e.emergencyContact?.relation||e.emergencyContactRelation||e.customFields?.relationship||e.customFields?.relation||e.customFields?.Relationship||e.customFields?.Relation||e.customFields?.parentRelation||"Parent",_=e.idProof?.type||e.idProofType||e.customFields?.idProofType||e.customFields?.id_proof_type||e.customFields?.idprooftype||"Aadhaar Card",s=e.idProof?.number||e.idProofNumber||e.customFields?.idProofNumber||e.customFields?.id_proof_number||e.customFields?.idproofnumber||e.customFields?.aadhaar||e.customFields?.pan||"",F=e.idProof?.image||e.idProofImage||e.customFields?.idProofImage||e.customFields?.id_proof_image||e.customFields?.idproofimage||e.customFields?.idProof||e.customFields?.id_proof||"";let H=[];if(Array.isArray(a.customFields)&&a.customFields.length>0)H=a.customFields;else if(typeof window<"u"&&(H=window.store?.customFields||window.store?.settings?.customFields||window.FormBuilder?.allFields||[],!H||H.length===0))try{const o=JSON.parse(localStorage.getItem("sl_custom_fields_cache")||"[]");Array.isArray(o)&&o.length>0&&(H=o)}catch{}let z=[];if(a.templateConfig&&Array.isArray(a.templateConfig.sections))z=a.templateConfig.sections;else if(typeof window<"u"&&(z=window.store?.formTemplate?.sections||window.store?.settings?.formTemplate?.sections||window.FormBuilder?.sections||[],!z||z.length===0))try{const o=JSON.parse(localStorage.getItem("sl_form_template_cache")||"{}");Array.isArray(o?.sections)&&(z=o.sections)}catch{}function K(o){if(!o)return"";let n=String(o).trim();return n.includes("___")&&(n=n.replace(/___/g," / ")),n=n.replace(/_/g," "),n=n.replace(/([a-z])([A-Z])/g,"$1 $2"),n.split(" ").filter(Boolean).map(l=>l.charAt(0).toUpperCase()+l.slice(1).toLowerCase()).join(" ").replace(/\s*\/\s*/g," / ")}const ae=[],S=[],y=new Set(["name","fullname","phone","mobile","email","gender","dob","dateofbirth","birthdate","photo","signature","seat","plan","status","branch","shift","feeamount","idproofimage","idproof","idprooftype","idproofnumber","targetexams","target_exams","competitive_exams","address","city","state","pincode","bloodgroup","blood_group","emergencycontact","emergencycontactname","emergencycontactphone","emergencycontactrelation","parentphone","fathername","rfidcardnumber","biometricid","parentguardianname","parent___guardian_name","parentname","guardianname","relationship","relation","whatsapp","alternatephone","altphone","lockernumber","occupation","collegeorcompany","college","company"]);function se(o,n){if(n==null||n==="")return;const l=o.toLowerCase().replace(/[^a-z0-9]/g,"");if(y.has(l))return;const h=H.find(le=>{const Pe=(le.fieldName||le.name||"").toLowerCase().replace(/[^a-z0-9]/g,""),ke=(le.label||"").toLowerCase().replace(/[^a-z0-9]/g,"");return Pe===l||ke===l}),re=h?.label||K(o),Ae=h?.section||"additional",ze=h?.order!==void 0?h.order:999,k=String(n).trim();if(k.startsWith("data:image/")||k.startsWith("http://")||k.startsWith("https://")||k.startsWith("/uploads/")||k.includes("res.cloudinary.com"))S.push({label:re,url:k});else{let le=k;(typeof n=="boolean"||k==="true"||k==="false")&&(le=n===!0||k==="true"?"Yes":"No"),ae.push({key:o,label:re,value:le,section:Ae,order:ze,type:h?.type||"text"})}}if(e.customFields){if(e.customFields instanceof Map)for(const[o,n]of e.customFields.entries())se(o,n);else if(typeof e.customFields=="object")for(const[o,n]of Object.entries(e.customFields))se(o,n)}F&&(F.startsWith("data:image/")||F.startsWith("http://")||F.startsWith("https://")||F.startsWith("/uploads/")||F.includes("res.cloudinary.com"))&&(S.some(o=>o.url===F)||S.unshift({label:`${_} KYC Document Scan`,url:F}));const j=[],J={personal:"\u{1F464}",academic:"\u{1F3AF}",plan:"\u23F0",payment:"\u{1F4B3}",seat:"\u{1FA91}",contact:"\u{1F4CD}",kyc:"\u{1FAAA}",parent:"\u{1F468}\u200D\u{1F469}\u200D\u{1F467}",vehicle:"\u{1F697}",transport:"\u{1F6B2}",custom:"\u{1F4CB}",additional:"\u{1F4CB}",other:"\u{1F4DD}"};if(z.length>0){z.forEach(l=>{const h=ae.filter(re=>re.section===l.name).sort((re,Ae)=>re.order-Ae.order);h.length>0&&j.push({name:l.name,label:l.label||K(l.name),icon:l.icon&&l.icon.length<=4?l.icon:J[l.name]||"\u{1F4CB}",fields:h})});const o=new Set(j.flatMap(l=>l.fields.map(h=>h.key))),n=ae.filter(l=>!o.has(l.key));n.length>0&&j.push({name:"additional",label:"Additional Registration Information",icon:"\u{1F4CB}",fields:n.sort((l,h)=>l.order-h.order)})}else{const o=new Map;ae.forEach(n=>{const l=n.section||"additional";o.has(l)||o.set(l,{name:l,label:K(l),icon:J[l]||"\u{1F4CB}",fields:[]}),o.get(l).fields.push(n)}),o.forEach(n=>{n.fields.sort((l,h)=>l.order-h.order),j.push(n)})}const w=typeof window<"u"?window.store:null,R=e.photo||e.photoUrl||e.customFields?.photo||e.customFields?.passport_photo||e.avatar||w?.user?.photo||w?.user?.avatar||"",ne=e.signature||e.signatureUrl||e.customFields?.signature||"",I=f.logoUrl||d.logo||d.logoUrl||w?.profile?.logo||w?.settings?.businessProfile?.logo||r?.logo||"",L=g.stampImage||d.stampImage||d.stamp||w?.profile?.stampImage||w?.settings?.businessProfile?.stampImage||r?.stampImage||"",P=g.signatureImage||"",de=f.gstNumber||f.taxNumber||d.gstNumber||d.taxNumber||"",O=g.termsText||x.terms||d.rules||"",be=g.customNote||"";let X="";if(a.showQrCode){if(typeof qrcode<"u")try{const o=qrcode(0,"M");o.addData(p),o.make(),X=o.createImgTag(3.2,0)}catch{}X||(X=`<img src="${`https://api.qrserver.com/v1/create-qr-code/?size=110x110&data=${encodeURIComponent(p)}`}" alt="QR Code" style="width: 90px; height: 90px; object-fit: contain;">`)}const B=a.template==="modern_glass",M=a.template==="classic_formal",Ne=a.template==="compact_card",Ie=a.showUploadedDocuments&&S.length>0;return`
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Official Admission Form \u2014 ${p} (${b})</title>
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
      border: 3px dashed ${ue};
      color: ${ue};
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
      background: ${M?"#1e293b":Ne?"#0284c7":"linear-gradient(135deg, #3730a3, #047857)"};
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
      color: ${M?"#1e293b":"#3730a3"};
      border-bottom: 1.5px solid ${M?"#1e293b":"#4338ca"};
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
    ${a.showWatermarkStamp?`<div class="watermark-stamp">${Fe}</div>`:""}

    <div class="page-content-flow">
      <!-- 1. Header -->
      <div class="mg-header">
        <div style="display: flex; align-items: center; gap: 10px;">
          ${I?`<img src="${I}" style="max-height: 42px; max-width: 65px; object-fit: contain; background: #fff; padding: 2px; border-radius: 4px;">`:""}
          <div>
            <h1>${d.businessName}</h1>
            <p>${d.tagline||"Silence, Focus and Success"}</p>
            <p style="margin-top: 2px; font-size: 9px;">\u{1F4CD} ${d.address||""} \u2022 \u{1F4DE} ${d.phone||""} ${de?`\u2022 GSTIN: ${de}`:""}</p>
          </div>
        </div>
        <div style="text-align: right; background: rgba(255,255,255,0.22); padding: 4px 10px; border-radius: 5px; min-width: 140px; white-space: nowrap; flex-shrink: 0;">
          <div style="font-size: 8px; text-transform: uppercase; letter-spacing: 0.5px; font-weight: 700;">OFFICIAL ADMISSION FORM</div>
          <div style="font-size: 13px; font-weight: 700; font-family: monospace; margin: 1px 0;">${p}</div>
          <div style="font-size: 9px; font-weight: 600;">Date: ${U}</div>
        </div>
      </div>

      <!-- 2. Top 2-Column Grid: Left (Personal + Seat Info) | Right (Photo + QR Code) -->
      <div style="display: grid; grid-template-columns: 1fr 118px; gap: 8px; align-items: stretch;">
        
        <!-- Left Column: Personal Information & Seat Allotment -->
        <div style="display: flex; flex-direction: column; gap: 6px; justify-content: space-between;">
          
          <!-- Student Personal Information -->
          <div class="sec-card" style="margin-bottom: 0;">
            <div class="sec-title">\u{1F464} Student Personal Information</div>
            
            <div class="grid-3" style="margin-bottom: 4px;">
              <div>
                <div class="field-label">Full Student Name</div>
                <div class="field-value">${b}</div>
              </div>
              <div>
                <div class="field-label">Mobile Number</div>
                <div class="field-value">\u{1F4DE} ${A}</div>
              </div>
              <div>
                <div class="field-label">Email Address</div>
                <div class="field-value">${$}</div>
              </div>
            </div>

            <div class="grid-4" style="margin-bottom: 4px;">
              <div>
                <div class="field-label">Gender</div>
                <div class="field-value">${ye}</div>
              </div>
              <div>
                <div class="field-label">Date of Birth</div>
                <div class="field-value" style="color: #3730a3; font-weight: 700;">${Z}</div>
              </div>
              <div>
                <div class="field-label">Blood Group</div>
                <div class="field-value" style="color: #dc2626; font-weight: 700;">${pe}</div>
              </div>
              <div>
                <div class="field-label">City & State</div>
                <div class="field-value">${q}${W&&W!=="N/A"?", "+W:""}</div>
              </div>
            </div>

            ${ee?`
              <div style="border-top: 1px dashed #cbd5e1; padding-top: 3px;">
                <div class="field-label">Resident / Permanent Address</div>
                <div class="field-value" style="font-size: 10px;">${ee}${T&&T!=="N/A"?" (PIN: "+T+")":""}</div>
              </div>
            `:""}
          </div>

          <!-- Study Centre, Shift & Seating Allocation -->
          <div class="sec-card" style="margin-bottom: 0;">
            <div class="sec-title">\u{1F3E2} Study Centre & Seating Allocation</div>
            
            <div class="grid-3" style="margin-bottom: 4px;">
              <div>
                <div class="field-label">Campus / Branch</div>
                <div class="field-value" style="color: #3730a3;">${Y}</div>
              </div>
              <div>
                <div class="field-label">Assigned Desk / Seat</div>
                <div class="field-value" style="color: #047857; font-size: 11.5px;">${me} (${fe}${ie})</div>
              </div>
              <div>
                <div class="field-label">Study Shift & Timings</div>
                <div class="field-value">${E}</div>
              </div>
            </div>

            <div class="grid-4">
              <div>
                <div class="field-label">Membership Plan</div>
                <div class="field-value">${ce} ${te?"("+te+")":""}</div>
              </div>
              <div>
                <div class="field-label">Plan Fee Amount</div>
                <div class="field-value" style="color: #047857;">${$e||"Standard Rate"}</div>
              </div>
              <div>
                <div class="field-label">Admission Date</div>
                <div class="field-value">${U}</div>
              </div>
              <div>
                <div class="field-label">Validity Expiry Date</div>
                <div class="field-value" style="color: #dc2626; font-weight: 700;">${ge}</div>
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
              ${R?`<img src="${R}" alt="Photo">`:'<span style="color:#94a3b8; font-size:8.5px; font-weight:600;">AFFIX PHOTO</span>'}
            </div>
          </div>

          <!-- Generated Student Verification QR Code -->
          <div style="width: 100%; text-align: center;">
            <div class="field-label" style="margin-bottom: 2px; font-size: 8px;">VERIFY ID QR</div>
            <div class="qr-frame" style="margin: 0 auto;">
              <div style="display: flex; align-items: center; justify-content: center;">
                ${X}
              </div>
              <div style="font-size: 7.5px; font-weight: 700; font-family: monospace; color: #475569; margin-top: 1px;">${p}</div>
            </div>
          </div>

        </div>

      </div>

      <!-- 3. Academic Focus, Locker & Guardian Emergency Contact -->
      <div class="sec-card">
        <div class="sec-title">\u{1F3AF} Academic Goals, Facilities & Emergency Contact</div>
        
        <div class="grid-3" style="margin-bottom: 4px;">
          <div>
            <div class="field-label">Target Competitive Exams</div>
            <div class="field-value" style="color: #3730a3;">
              ${G.length>0?G.join(", "):"General Competitive Exams / Self Study"}
            </div>
          </div>
          <div>
            <div class="field-label">College / Company / Occupation</div>
            <div class="field-value">${Q}</div>
          </div>
          <div>
            <div class="field-label">Locker & Access Card</div>
            <div class="field-value">${oe?`Locker #${oe}`:"No Locker Assigned"} \u2022 Bio/RFID: ${e.rfidCardNumber||e.biometricCardNumber||e.biometricId||"N/A"}</div>
          </div>
        </div>

        ${xe||ve?`
          <div style="border-top: 1px dashed #cbd5e1; padding-top: 3px;" class="grid-3">
            <div>
              <div class="field-label">Guardian / Parent Name</div>
              <div class="field-value">${xe||"N/A"}</div>
            </div>
            <div>
              <div class="field-label">Guardian Contact Phone</div>
              <div class="field-value">\u{1F4DE} ${ve||"N/A"}</div>
            </div>
            <div>
              <div class="field-label">Relationship</div>
              <div class="field-value">${V}</div>
            </div>
          </div>
        `:""}
      </div>

      <!-- 4. Government KYC & Identity Proof Verification -->
      <div class="sec-card">
        <div class="sec-title">\u{1FAAA} Government ID Proof & KYC Verification</div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; align-items: center;">
          
          <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 5px; padding: 5px 9px; display: flex; align-items: center; justify-content: space-between;">
            <div>
              <div style="font-weight: 700; font-size: 10.5px; color: #0f172a;">\u{1F4D1} ${_}</div>
              <div style="font-size: 9.5px; color: #334155; font-family: monospace; font-weight: 600; margin-top: 1px;">
                ${s?`ID Number: ${s}`:"Document Attached on Record"}
              </div>
            </div>
            <span style="font-size: 8px; font-weight: 700; color: #047857; background: #d1fae5; padding: 2px 6px; border-radius: 3px; border: 1px solid #10b981;">
              KYC VERIFIED \u2713
            </span>
          </div>

          <div style="background: #ffffff; border: 1px solid #cbd5e1; border-radius: 5px; padding: 5px 9px; display: flex; align-items: center; justify-content: space-between;">
            <div>
              <div style="font-weight: 700; font-size: 10.5px; color: #0f172a;">\u{1F4CB} Admission & Fee Status</div>
              <div style="font-size: 9.5px; color: #334155; font-family: monospace; font-weight: 600; margin-top: 1px;">
                Status: ${C} (${N?"CONFIRMED":"PROVISIONAL"})
              </div>
            </div>
            <span style="font-size: 8px; font-weight: 700; color: ${N?"#047857":"#d97706"}; background: ${N?"#d1fae5":"#fef3c7"}; padding: 2px 6px; border-radius: 3px; border: 1px solid ${N?"#10b981":"#f59e0b"};">
              ${N?"ACTIVE ACCESS":"PENDING"}
            </span>
          </div>

        </div>
      </div>

      <!-- 5. Form Builder Custom Questions & Sections (Organized matching Admin Form Builder) -->
      ${j.map(o=>`
        <div class="sec-card">
          <div class="sec-title">${o.icon} ${t(o.label)}</div>
          <div class="grid-2">
            ${o.fields.map(n=>`
              <div style="margin-bottom: 2px;">
                <div class="field-label">${t(n.label)}</div>
                <div class="field-value" style="font-size: 10px;">${t(n.value)}</div>
              </div>
            `).join("")}
          </div>
        </div>
      `).join("")}

      <!-- 6. Discipline Code, Terms of Admission & Declaration -->
      ${a.showRules?`
        <div class="sec-card">
          <div class="sec-title">\u{1F4DC} Discipline Code & Student Declaration</div>
          ${O?`<div class="rules-list" style="margin-bottom: 3px;">${O}</div>`:`
          <ol class="rules-list">
            <li>Maintain complete silence in the study hall. Mobile phones must strictly be kept on Silent mode.</li>
            <li>Seats are reserved for the registered student and non-transferable without prior management approval.</li>
            <li>Eatables, tea, and open beverages are strictly prohibited inside reading rooms.</li>
            <li>I declare that the information provided is accurate and agree to adhere to all library rules and timings.</li>
          </ol>`}
          ${be?`<p style="font-size: 8.5px; color: #3730a3; font-weight: 600; margin-top: 2px;">Notice: ${be}</p>`:""}

          <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 4px; padding-top: 4px; border-top: 1px dashed #cbd5e1;">
            <div>
              <div class="field-label">Date & Place</div>
              <div class="field-value">${U} \u2022 ${q!=="N/A"?q:"Campus"}</div>
            </div>

            ${a.showSignature?`
              <div style="text-align: center;">
                <div class="field-label">Student Digital Signature</div>
                <div class="sig-box">
                  ${ne?`<img src="${ne}" alt="Signature">`:`<span style="font-family: Arial, sans-serif; font-size:10.5px; font-weight:600;">${b}</span>`}
                </div>
              </div>
            `:""}

            <div style="text-align: center;">
              <div class="field-label">${g.signatureLabel||"Authorized Seal & Signatory"}</div>
              <div class="sig-box" style="border-bottom-style: dotted; display: flex; align-items: center; justify-content: center; gap: 6px;">
                ${L?`<img src="${L}" style="max-height: 36px; opacity: 0.92;">`:""}
                ${P?`<img src="${P}" style="max-height: 32px;">`:""}
                ${!L&&!P?'<span style="font-size:8px; color:#64748b; font-weight:700; border:1px solid #cbd5e1; padding:2px 6px; border-radius:3px;">OFFICIAL SEAL</span>':""}
              </div>
            </div>
          </div>
        </div>
      `:""}
    </div>

    <!-- Page 1 Footer -->
    <div class="doc-footer">
      <div>Generated via ${d.businessName||"Study Library Management"} \u2022 ${Ie?"Page 1 of 2 (Official Admission Form)":"Official Admission & Registration Record"}</div>
      <div>Document Ref: ${p} \u2022 Verified Student Copy</div>
    </div>
  </div>

  <!-- ==================== PAGE 2: ANNEXURE \u2014 ATTACHED KYC DOCUMENT SCAN ==================== -->
  ${Ie?`
    ${S.map((o,n)=>`
      <div class="page-frame page-break">
        <!-- Annexure Header -->
        <div class="annexure-header">
          <div style="display: flex; align-items: center; gap: 10px;">
            ${I?`<img src="${I}" style="max-height: 38px; max-width: 60px; object-fit: contain; background: #fff; padding: 2px; border-radius: 4px;">`:""}
            <div>
              <h1 style="font-size: 14.5px; font-weight: 700; margin: 0;">${d.businessName}</h1>
              <p style="font-size: 9px; opacity: 0.9; margin: 0;">ANNEXURE ${S.length>1?String.fromCharCode(65+n):"A"} \u2014 GOVERNMENT ID & KYC VERIFICATION PROOF</p>
            </div>
          </div>
          <div style="text-align: right; background: rgba(255,255,255,0.18); padding: 4px 10px; border-radius: 5px;">
            <div style="font-size: 7.5px; text-transform: uppercase; font-weight: 700;">STUDENT IDENTIFICATION</div>
            <div style="font-size: 12px; font-weight: 700; font-family: monospace;">${p}</div>
          </div>
        </div>

        <!-- Document Full-Page Display Frame (Auto-Fit to A4) -->
        <div class="doc-preview-card-full">
          <div style="width: 100%; display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; border-bottom: 1px dashed #cbd5e1; padding-bottom: 4px;">
            <span style="font-size: 10.5px; font-weight: 700; color: #1e293b; text-transform: uppercase;">
              \u{1F4C4} ${t(o.label)}
            </span>
            <span style="font-size: 8.5px; font-weight: 700; color: #047857; background: #d1fae5; padding: 2px 7px; border-radius: 3px; border: 1px solid #10b981;">
              OFFICIAL RECORD ATTACHMENT \u2713
            </span>
          </div>
          
          <div style="flex: 1; width: 100%; display: flex; align-items: center; justify-content: center; background: #ffffff; padding: 4px;">
            <img src="${o.url}" alt="${t(o.label)}" class="doc-preview-img-full">
          </div>

          <div style="width: 100%; font-size: 8.5px; color: #64748b; margin-top: 4px; border-top: 1px solid #e2e8f0; padding-top: 4px; font-family: monospace; display: flex; justify-content: space-between;">
            <span>Document Reference: ${p} \u2022 Verified KYC Record Proof</span>
            <span>Name: ${b} \u2022 Date: ${U}</span>
          </div>
        </div>

        <!-- Page 2 Footer -->
        <div class="doc-footer">
          <div>Generated via ${d.businessName||"Study Library Management"} \u2022 Page ${2+n} of ${1+S.length} (Verified KYC Document)</div>
          <div>Document Ref: ${p} \u2022 Official Verification Attachment</div>
        </div>
      </div>
    `).join("")}
  `:""}

</body>
</html>
  `}async function De(c,m={}){let a=c;const e={...m};try{const i=typeof localStorage<"u"?localStorage.getItem("sl_token")||localStorage.getItem("token"):null,d=i?{Authorization:`Bearer ${i}`}:{},[x,f,g]=await Promise.all([c&&c._id&&(!c.plan?.name||!c.shift?.name||!c.branch?.name||!c.idProof?.image)?fetch(`/api/students/${c._id}`,{headers:d}).then(p=>p.json()).catch(()=>null):null,e.customFields?null:fetch("/api/custom-fields/all",{headers:d}).then(p=>p.json()).catch(()=>null),e.templateConfig?null:fetch("/api/custom-fields/templates/active",{headers:d}).then(p=>p.json()).catch(()=>null)]);x?.success&&x?.data&&(a=x.data),f?.success&&Array.isArray(f.data)&&(e.customFields=f.data),g?.success&&g.data&&(e.templateConfig=g.data)}catch{}const r=Se(a,e);let u=null;try{u=window.open("","_blank","width=900,height=1100")}catch{}if(u)u.document.open(),u.document.write(r+`
      <script>
        window.onload = function() {
          setTimeout(() => { window.print(); }, 400);
        };
      <\/script>
    `),u.document.close();else{let i=document.getElementById("pdf-print-sandbox-frame");i||(i=document.createElement("iframe"),i.id="pdf-print-sandbox-frame",i.style.position="fixed",i.style.right="0",i.style.bottom="0",i.style.width="0",i.style.height="0",i.style.border="0",document.body.appendChild(i));const d=i.contentWindow.document;d.open(),d.write(r),d.close(),setTimeout(()=>{try{i.contentWindow.focus(),i.contentWindow.print()}catch{window.print()}},500)}}function Te(c,m={}){const a={template:"modern_glass",showPhoto:!0,showSignature:!0,showQrCode:!0,showPaymentDetails:!0,showRules:!0,showWatermarkStamp:!0,showUploadedDocuments:!0,...m},e=document.createElement("div");e.id="pdf-preview-modal-overlay",e.style.cssText=`
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(15, 23, 42, 0.75); backdrop-filter: blur(8px);
    z-index: 2147483647; display: flex; flex-direction: column;
    align-items: center; justify-content: center; padding: 1.25rem;
    animation: fadeIn 0.25s ease forwards;
  `;const r=document.createElement("div");r.style.cssText=`
    width: 100%; max-width: 950px; height: 92vh; background: var(--color-surface, #ffffff);
    border-radius: 16px; border: 1px solid var(--color-border, #e2e8f0);
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.35); display: flex;
    flex-direction: column; overflow: hidden;
  `;const u=c?.name||"Student",i=c?.studentId||"CONFIRMED";r.innerHTML=`
    <!-- Top Modal Toolbar Header -->
    <div style="padding: 1rem 1.5rem; background: var(--color-bg-secondary, #f8fafc); border-bottom: 1px solid var(--color-border, #e2e8f0); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
      <div style="display: flex; align-items: center; gap: 10px;">
        <div style="font-size: 1.5rem;">\u{1F4C4}</div>
        <div>
          <h3 style="margin: 0; font-size: 1.1rem; font-weight: 800; color: var(--color-text-primary, #1e293b);">
            Admission Form Preview \u2014 ${u} (${i})
          </h3>
          <span class="text-muted small" style="font-size: 0.8rem; color: #64748b;">
            Includes all personal data, seating allotment, custom questions & uploaded documents
          </span>
        </div>
      </div>

      <div style="display: flex; align-items: center; gap: 10px;">
        <select id="pdf-prev-preset" class="form-select" style="padding: 6px 12px; font-size: 0.85rem; font-weight: 700; border-radius: 8px;">
          <option value="modern_glass" ${a.template==="modern_glass"?"selected":""}>\u{1F48E} Modern Glass Slate</option>
          <option value="classic_formal" ${a.template==="classic_formal"?"selected":""}>\u{1F3DB}\uFE0F Classic Indian Format</option>
          <option value="compact_card" ${a.template==="compact_card"?"selected":""}>\u{1FAAA} 1-Page Pass Slip</option>
        </select>

        <button id="btn-pdf-modal-print" class="btn btn-primary" style="font-weight: 700; padding: 7px 16px; border-radius: 8px; background: #6c5ce7; border: none;">
          \u{1F5A8}\uFE0F Print / Download PDF
        </button>

        <button id="btn-pdf-modal-close" class="btn btn-secondary" style="padding: 7px 12px; border-radius: 8px; font-weight: 700;">
          \u2715 Close
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
  `,e.appendChild(r),document.body.appendChild(e);const d=r.querySelector("#pdf-preview-iframe");let x=c;function f(){const g=Se(x,a),p=d.contentWindow.document;p.open(),p.write(g),p.close()}f(),(async()=>{try{const g=typeof localStorage<"u"?localStorage.getItem("sl_token")||localStorage.getItem("token"):null,p=g?{Authorization:`Bearer ${g}`}:{},[b,A,D,$]=await Promise.all([c?._id?fetch(`/api/students/${c._id}`,{headers:p}).then(v=>v.json()).catch(()=>null):null,fetch("/api/custom-fields/all",{headers:p}).then(v=>v.json()).catch(()=>null),fetch("/api/custom-fields/templates/active",{headers:p}).then(v=>v.json()).catch(()=>null),!a.business||!a.business.businessName||a.business.businessName==="Study Library Management"?fetch("/api/settings",{headers:p}).then(v=>v.json()).catch(()=>null):null]);if(b?.success&&b?.data&&(x=b.data),A?.success&&Array.isArray(A.data)){a.customFields=A.data;try{localStorage.setItem("sl_custom_fields_cache",JSON.stringify(A.data))}catch{}}if(D?.success&&D.data){a.templateConfig=D.data;try{localStorage.setItem("sl_form_template_cache",JSON.stringify(D.data))}catch{}}$?.success&&$?.data?.businessProfile&&(a.business=$.data.businessProfile,$.data.receipt&&(a.receiptConfig=$.data.receipt)),f()}catch{}})(),r.querySelector("#pdf-prev-preset")?.addEventListener("change",g=>{a.template=g.target.value,f()}),r.querySelector("#btn-pdf-modal-print")?.addEventListener("click",()=>{De(x,a)}),r.querySelector("#btn-pdf-modal-close")?.addEventListener("click",()=>{e.remove()}),e.addEventListener("click",g=>{g.target===e&&e.remove()})}function Ce(c={},m={}){const a=m.receiptConfig||(typeof window<"u"?window.store?.settings?.receipt:{})||{},e=m.businessProfile||m.business||(typeof window<"u"?window.store?.profile:{})||{};let r=m.template||a.activeTemplate||"thermal80",u="thermal80";r==="thermal_58"||r==="thermal58"?u="thermal58":r==="standard_a4"||r==="standardA4"||r==="gst_invoice"?u="standardA4":r==="modern_minimal"||r==="digital"?u="modern_minimal":u="thermal80";const i=a.header||{},d=a.body||{},x=a.stamp||{},f=a.footer||{},g=a.dateTime||{},p=a.gst||{},b=e.businessName||"Study Library",A=e.address||"",D=e.phone||"",$=e.email||"",v=i.gstNumber||e.gstNumber||"",he=i.taxNumber||e.registrationNumber||"",Z=i.logoUrl||e.logo||e.logoUrl||"",ye=e.upiId||"library@upi",pe=i.subtitle||"Official Fee Payment Receipt",T=i.headerColor||"#4f46e5",q=i.showLogo!==!1&&!!Z,W=i.showBusinessName!==!1,ee=i.showAddress!==!1&&!!A,Q=i.showPhone!==!1&&!!D,Y=i.showEmail!==!1&&!!$,we=i.showGst!==!1&&!!v,ce=d.showStudentId!==!1,$e=d.showStudentPhone!==!1,te=d.showSeatNumber!==!1,E=d.showShift!==!1,me=d.showPeriod!==!1,fe=d.showDiscount!==!1&&d.showPlanDetails!==!1,ie=d.showPaymentMethod!==!1,oe=d.showTransactionId!==!1&&ie,U=x.showStamp!==!1,ge=x.stampText||"PAID \u2022 OFFICIAL RECEIPT",C=x.stampColor||"#059669",N=x.stampImage||f.stampImage||e.stampImage||"",Fe=f.showSignature!==!1,ue=f.signatureLabel||"Authorized Signatory",G=f.signatureImage||"",xe=!!f.showUpiQr,ve=g.showTimestamp!==!1&&f.showTimestamp!==!1,V=f.termsText||"This is an authorized computer-generated fee receipt.",_=f.customNote||"Thank you for choosing our study library!",s=c||{},F=s.receiptNumber||(s._id?`REC-${String(s._id).slice(-6).toUpperCase()}`:"REC-001"),H=s.paymentDate||s.createdAt||s.date||new Date,z=new Date(H),K=z.toLocaleDateString("en-IN",{day:"2-digit",month:"2-digit",year:"numeric"}),ae=z.toLocaleTimeString("en-IN",{hour:"2-digit",minute:"2-digit",hour12:!0}),S=ve?`${K} ${ae}`:K,y=s.student&&typeof s.student=="object"?s.student:{},se=y.name||s.studentName||"Student Member",j=y.studentId||s.studentId||"N/A",J=y.phone||s.phone||"",w=y.seat&&typeof y.seat=="object"?y.seat.seatNumber:y.seat||s.seatNumber||"",R=y.shift&&typeof y.shift=="object"?y.shift.name:y.shift||s.shiftName||"",ne=(s.plan&&typeof s.plan=="object"?s.plan:{}).name||s.planName||"Study Space Membership",I=Number(s.finalAmount!==void 0?s.finalAmount:s.amount||0),L=Number(s.amount!==void 0?s.amount:I),P=Number(s.discount||(L>I?L-I:0)),de=(s.paymentMethod||s.method||"UPI").toUpperCase(),O=s.transactionId||s.utrNumber||s.utr||"",be=s.periodStart?new Date(s.periodStart).toLocaleDateString("en-IN",{day:"2-digit",month:"short",year:"numeric"}):"",X=s.periodEnd?new Date(s.periodEnd).toLocaleDateString("en-IN",{day:"2-digit",month:"short",year:"numeric"}):"",B=be&&X?`${be} \u2013 ${X}`:"";if(u==="standardA4")return`
      <div class="receipt-document format-standard-a4" style="width: 100%; max-width: 680px; margin: 0 auto; background: #fff; color: #111827; padding: 28px; font-family: 'Inter', Arial, sans-serif; box-sizing: border-box; position: relative; overflow: hidden; border: 1px solid #e5e7eb; border-radius: 8px;">
        
        <!-- Header -->
        <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2.5px solid ${T}; padding-bottom: 16px; margin-bottom: 18px; gap: 16px;">
          <div>
            ${q?`<img src="${Z}" style="max-height: 54px; max-width: 120px; object-fit: contain; margin-bottom: 8px;" alt="Logo"><br>`:""}
            ${W?`<h2 style="margin: 0; font-size: 1.35rem; font-weight: 800; color: ${T}; text-transform: uppercase;">${t(b)}</h2>`:""}
            <div style="font-size: 0.85rem; font-weight: 700; color: #4b5563; margin-top: 2px;">${t(pe)}</div>
            ${ee?`<div style="font-size: 0.78rem; color: #6b7280; margin-top: 3px;">${t(A)}</div>`:""}
            <div style="font-size: 0.78rem; color: #6b7280;">
              ${Q?`<span>\u{1F4DE} ${t(D)}</span>`:""}
              ${Y?`<span style="margin-left: 8px;">\u2709\uFE0F ${t($)}</span>`:""}
            </div>
            ${we?`<div style="font-size: 0.78rem; font-weight: 700; color: #1f2937; margin-top: 2px;">GSTIN: ${t(v)}</div>`:""}
          </div>
          <div style="text-align: right;">
            <div style="font-size: 0.75rem; font-weight: 700; color: #6b7280; text-transform: uppercase;">RECEIPT NUMBER</div>
            <div style="font-size: 1.15rem; font-weight: 900; font-family: monospace; color: #111827;">${t(F)}</div>
            <div style="font-size: 0.75rem; color: #6b7280; margin-top: 6px;">Date: <strong>${S}</strong></div>
            ${U?`
              <div style="display: inline-block; margin-top: 10px; border: 2px dashed ${C}; color: ${C}; font-weight: 800; font-size: 0.8rem; padding: 4px 10px; border-radius: 4px; text-transform: uppercase; transform: rotate(-5deg); background: rgba(255,255,255,0.9);">
                \u2714 ${t(ge)}
              </div>
            `:""}
          </div>
        </div>

        <!-- Student & Allotment Information Box -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 14px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px; padding: 12px 16px; margin-bottom: 18px; font-size: 0.82rem;">
          <div>
            <div style="font-size: 0.7rem; font-weight: 700; color: #6b7280; text-transform: uppercase;">STUDENT DETAILS</div>
            <div style="font-weight: 800; font-size: 0.95rem; color: #111827; margin-top: 2px;">${t(se)}</div>
            ${ce?`<div style="font-family: monospace; color: #4b5563;">ID: ${t(j)}</div>`:""}
            ${$e&&J?`<div>Phone: ${t(J)}</div>`:""}
          </div>
          <div>
            <div style="font-size: 0.7rem; font-weight: 700; color: #6b7280; text-transform: uppercase;">ADMISSION &amp; DESK</div>
            ${te&&w?`<div>Allocated Seat: <strong>Desk #${t(w)}</strong></div>`:""}
            ${E&&R?`<div>Shift Timing: <strong>${t(R)}</strong></div>`:""}
            ${me&&B?`<div style="color: #059669; font-weight: 700; margin-top: 2px;">Validity: ${t(B)}</div>`:""}
          </div>
        </div>

        <!-- Line Items Table -->
        <table style="width: 100%; border-collapse: collapse; margin-bottom: 18px; font-size: 0.84rem;">
          <thead>
            <tr style="background: #f3f4f6; border-bottom: 2px solid #e5e7eb; color: #374151; font-weight: 700; text-transform: uppercase; font-size: 0.74rem;">
              <th style="padding: 8px 10px; text-align: left;">Description</th>
              <th style="padding: 8px 10px; text-align: right;">Amount (\u20B9)</th>
            </tr>
          </thead>
          <tbody>
            <tr style="border-bottom: 1px solid #e5e7eb;">
              <td style="padding: 10px 10px;">
                <strong>${t(ne)}</strong>
                ${B?`<div style="font-size: 0.75rem; color: #6b7280;">Duration: ${t(B)}</div>`:""}
              </td>
              <td style="padding: 10px 10px; text-align: right; font-weight: 600;">\u20B9${L.toFixed(2)}</td>
            </tr>
            ${fe&&P>0?`
              <tr style="border-bottom: 1px solid #e5e7eb; color: #dc2626;">
                <td style="padding: 6px 10px;">Discount Applied</td>
                <td style="padding: 6px 10px; text-align: right; font-weight: 600;">-\u20B9${P.toFixed(2)}</td>
              </tr>
            `:""}
          </tbody>
          <tfoot>
            <tr style="border-top: 2px solid #111827; font-weight: 800; font-size: 1rem;">
              <td style="padding: 10px 10px;">TOTAL AMOUNT PAID:</td>
              <td style="padding: 10px 10px; text-align: right; color: #059669;">\u20B9${I.toFixed(2)}</td>
            </tr>
          </tfoot>
        </table>

        <!-- Payment Mode & Reference Block (Strictly Hidden if Admin unchecks Payment Mode) -->
        ${ie?`
          <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 6px; padding: 10px 14px; margin-bottom: 16px; font-size: 0.8rem; display: flex; justify-content: space-between; align-items: center;">
            <div>
              <span>Payment Mode: <strong>${t(de)}</strong></span>
              ${oe&&O?`<span style="margin-left: 10px; font-family: monospace; color: #475569;">(Ref / Txn ID: ${t(O)})</span>`:""}
            </div>
            <span style="font-size: 0.75rem; font-weight: 800; color: #047857; background: #d1fae5; padding: 2px 8px; border-radius: 4px;">
              PAID &amp; SETTLED \u2713
            </span>
          </div>
        `:""}

        <!-- Terms, Footer & Signature Block -->
        <div style="display: flex; justify-content: space-between; align-items: flex-end; border-top: 1px solid #e5e7eb; padding-top: 14px; margin-top: 12px; gap: 16px;">
          <div style="font-size: 0.72rem; color: #6b7280; max-width: 65%;">
            ${_?`<div style="font-weight: 700; color: #1f2937; margin-bottom: 4px;">${t(_)}</div>`:""}
            ${V?`<div>${t(V)}</div>`:""}
          </div>
          ${Fe?`
            <div style="text-align: center; min-width: 140px;">
              ${G?`<img src="${G}" style="max-height: 40px; margin-bottom: 4px;" alt="Signature"><br>`:'<div style="height: 34px;"></div>'}
              <div style="border-top: 1.5px solid #111827; padding-top: 4px; font-size: 0.72rem; font-weight: 700; color: #111827;">${t(ue)}</div>
            </div>
          `:""}
        </div>

      </div>
    `;if(u==="modern_minimal")return`
      <div class="receipt-document format-modern-digital" style="width: 100%; max-width: 420px; margin: 0 auto; background: #ffffff; color: #0f172a; padding: 22px; font-family: 'Inter', Arial, sans-serif; box-sizing: border-box; border-radius: 12px; box-shadow: 0 10px 25px -5px rgba(0,0,0,0.1); border: 1px solid #e2e8f0; position: relative;">
        
        <!-- Header -->
        <div style="text-align: center; border-bottom: 2px solid ${T}; padding-bottom: 12px; margin-bottom: 14px;">
          ${q?`<img src="${Z}" style="max-height: 44px; max-width: 90px; object-fit: contain; margin-bottom: 6px;" alt="Logo"><br>`:""}
          ${W?`<h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: ${T}; text-transform: uppercase;">${t(b)}</h3>`:""}
          <div style="font-size: 0.78rem; font-weight: 700; color: #64748b; margin-top: 2px;">${t(pe)}</div>
          ${ee?`<div style="font-size: 0.72rem; color: #64748b; margin-top: 2px;">${t(A)}</div>`:""}
          ${Q||Y?`<div style="font-size: 0.72rem; color: #64748b;">${Q?`\u{1F4DE} ${t(D)} `:""}${Y?`\u2709\uFE0F ${t($)}`:""}</div>`:""}
          ${we?`<div style="font-size: 0.72rem; font-weight: 700; color: #334155; margin-top: 2px;">GSTIN: ${t(v)}</div>`:""}
        </div>

        <!-- Receipt Metadata Grid -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px 12px; font-size: 0.78rem; margin-bottom: 14px; background: #f8fafc; padding: 10px 12px; border-radius: 8px; border: 1px solid #e2e8f0;">
          <div>
            <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">RECEIPT NO.</div>
            <div style="font-weight: 800; font-family: monospace; color: #0f172a;">${t(F)}</div>
          </div>
          <div style="text-align: right;">
            <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">DATE &amp; TIME</div>
            <div style="font-weight: 600; color: #0f172a;">${S}</div>
          </div>
          <div>
            <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">STUDENT NAME</div>
            <div style="font-weight: 800; color: #0f172a;">${t(se)}</div>
            ${ce?`<div style="font-size: 0.68rem; color: #64748b; font-family: monospace;">ID: ${t(j)}</div>`:""}
          </div>
          <div style="text-align: right;">
            ${te&&w?`
              <div style="font-size: 0.65rem; color: #64748b; font-weight: 700; text-transform: uppercase;">ALLOCATED DESK</div>
              <div style="font-weight: 700; color: #047857;">Desk #${t(w)}</div>
            `:""}
            ${E&&R?`<div style="font-size: 0.68rem; color: #64748b;">${t(R)}</div>`:""}
          </div>
          ${me&&B?`
            <div style="grid-column: span 2; border-top: 1px dashed #cbd5e1; padding-top: 4px; margin-top: 2px;">
              <span style="font-size: 0.68rem; color: #64748b;">Validity:</span>
              <strong style="color: #059669; margin-left: 4px;">${t(B)}</strong>
            </div>
          `:""}
        </div>

        <!-- Plan Description & Total -->
        <div style="border-bottom: 1.5px dashed #cbd5e1; padding-bottom: 10px; margin-bottom: 12px; font-size: 0.82rem;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
            <span>${t(ne)}</span>
            <span style="font-weight: 600;">\u20B9${L.toFixed(2)}</span>
          </div>
          ${fe&&P>0?`
            <div style="display: flex; justify-content: space-between; color: #dc2626; font-size: 0.76rem;">
              <span>Special Discount</span>
              <span>-\u20B9${P.toFixed(2)}</span>
            </div>
          `:""}
          <div style="display: flex; justify-content: space-between; font-weight: 800; font-size: 1.05rem; margin-top: 8px; border-top: 1.5px solid #0f172a; padding-top: 6px;">
            <span>TOTAL PAID:</span>
            <span style="color: #059669;">\u20B9${I.toFixed(2)}</span>
          </div>
        </div>

        <!-- Payment Mode & Reference (Strictly Hidden if Admin unchecks Payment Mode) -->
        ${ie?`
          <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.74rem; color: #475569; border-bottom: 1px solid #e2e8f0; padding-bottom: 8px; margin-bottom: 10px;">
            <div>
              <span>Mode: <strong style="color: #0f172a;">${t(de)}</strong></span>
              ${oe&&O?`<div style="font-family: monospace; font-size: 0.68rem; color: #64748b;">Txn: ${t(O)}</div>`:""}
            </div>
            <span style="font-size: 0.68rem; font-weight: 700; color: #047857; background: #d1fae5; padding: 2px 7px; border-radius: 4px; border: 1px solid #10b981;">
              PAID &amp; VERIFIED \u2713
            </span>
          </div>
        `:""}

        <!-- Official Stamp -->
        ${U?`
          <div style="text-align: center; margin: 10px 0;">
            <div style="display: inline-block; border: 2px solid ${C}; color: ${C}; font-weight: 800; font-size: 0.85rem; padding: 3px 12px; border-radius: 6px; text-transform: uppercase; transform: rotate(-2deg);">
              \u2714 ${t(ge)}
            </div>
          </div>
        `:""}

        <!-- Dynamic UPI QR -->
        ${xe?`
          <div style="text-align: center; margin: 8px 0; padding: 6px; background: #f8fafc; border-radius: 6px; border: 1px solid #e2e8f0;">
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=${encodeURIComponent("upi://pay?pa="+ye+"&pn="+b+"&am=0&cu=INR")}" style="width: 70px; height: 70px; display: block; margin: 0 auto 3px;" alt="QR">
            <div style="font-size: 0.62rem; font-weight: 700; color: #475569;">Scan to Verify via UPI</div>
          </div>
        `:""}

        <!-- Footer -->
        <div style="text-align: center; font-size: 0.68rem; color: #94a3b8; margin-top: 8px;">
          ${_?`<div style="font-weight: 700; color: #475569; margin-bottom: 2px;">${t(_)}</div>`:""}
          ${V?`<div>${t(V)}</div>`:""}
        </div>

      </div>
    `;const M=u==="thermal58";return`
    <div class="receipt-document format-thermal" style="width: ${M?"260px":"340px"}; max-width: 100%; margin: 0 auto; background: #ffffff; color: #111827; padding: ${M?"12px 10px":"18px 16px"}; font-family: 'Courier New', Courier, monospace; font-size: ${M?"11px":"12.5px"}; line-height: 1.4; box-sizing: border-box;">
      
      <!-- Receipt Header -->
      <div style="text-align: center; border-bottom: 1.5px dashed #333; padding-bottom: 8px; margin-bottom: 8px;">
        ${q?`<img src="${Z}" style="max-height: ${M?"36px":"44px"}; max-width: 100px; object-fit: contain; margin-bottom: 4px;" alt="Logo"><br>`:""}
        ${W?`<div style="font-weight: 800; font-size: ${M?"0.95rem":"1.05rem"}; text-transform: uppercase; color: ${T}; letter-spacing: 0.5px;">${t(b)}</div>`:""}
        <div style="font-size: 0.78rem; font-weight: 700; color: #555; text-transform: uppercase;">${t(pe)}</div>
        ${ee?`<div style="font-size: 0.72rem; color: #444; margin-top: 2px;">${t(A)}</div>`:""}
        ${Q||Y?`<div style="font-size: 0.72rem; color: #444;">${Q?`Tel: ${t(D)} `:""}${Y?`\u2022 ${t($)}`:""}</div>`:""}
        ${we?`<div style="font-size: 0.72rem; font-weight: 700; color: #222; margin-top: 2px;">GSTIN: ${t(v)}</div>`:""}
      </div>

      <!-- Receipt Metadata -->
      <div style="border-bottom: 1px dashed #666; padding-bottom: 6px; margin-bottom: 6px; font-size: 0.8rem;">
        <div style="display: flex; justify-content: space-between;">
          <span>Receipt No:</span>
          <strong style="font-family: monospace;">${t(F)}</strong>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span>Date &amp; Time:</span>
          <span>${S}</span>
        </div>
        <div style="display: flex; justify-content: space-between;">
          <span>Student Name:</span>
          <strong>${t(se)}</strong>
        </div>
        ${ce?`
          <div style="display: flex; justify-content: space-between;">
            <span>Student ID:</span>
            <span style="font-family: monospace;">${t(j)}</span>
          </div>
        `:""}
        ${$e&&J?`
          <div style="display: flex; justify-content: space-between;">
            <span>Phone:</span>
            <span>${t(J)}</span>
          </div>
        `:""}
        ${te&&w?`
          <div style="display: flex; justify-content: space-between;">
            <span>Allocated Seat:</span>
            <strong>Desk #${t(w)}</strong>
          </div>
        `:""}
        ${E&&R?`
          <div style="display: flex; justify-content: space-between;">
            <span>Shift Timing:</span>
            <span>${t(R)}</span>
          </div>
        `:""}
        ${me&&B?`
          <div style="display: flex; justify-content: space-between; margin-top: 2px;">
            <span>Validity:</span>
            <strong style="color: #059669;">${t(B)}</strong>
          </div>
        `:""}
      </div>

      <!-- Line Items / Fee Breakdown -->
      ${fe?`
        <div style="border-bottom: 1.5px dashed #333; padding-bottom: 6px; margin-bottom: 6px; font-size: 0.8rem;">
          <div style="display: flex; justify-content: space-between; font-weight: 700; border-bottom: 1px solid #ddd; padding-bottom: 2px; margin-bottom: 3px;">
            <span>Description</span>
            <span>Amount (\u20B9)</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>${t(ne)}</span>
            <span>${L.toFixed(2)}</span>
          </div>
          ${P>0?`
            <div style="display: flex; justify-content: space-between; color: #dc2626;">
              <span>Special Discount</span>
              <span>-${P.toFixed(2)}</span>
            </div>
          `:""}
        </div>
      `:""}

      <!-- Total Paid & Payment Method -->
      <div style="border-bottom: 1.5px dashed #333; padding-bottom: 6px; margin-bottom: 6px;">
        <div style="display: flex; justify-content: space-between; font-weight: 800; font-size: 0.95rem;">
          <span>TOTAL PAID:</span>
          <span>\u20B9${I.toFixed(2)}</span>
        </div>
        <div style="display: flex; justify-content: space-between; font-size: 0.76rem; color: #059669; font-weight: 700; margin-top: 2px;">
          <span>Balance Due:</span>
          <span>\u20B90.00 (PAID IN FULL)</span>
        </div>
        ${ie?`
          <div style="display: flex; justify-content: space-between; font-size: 0.76rem; color: #444; margin-top: 3px;">
            <span>Payment Mode:</span>
            <span>${t(de)}</span>
          </div>
          ${oe&&O?`
            <div style="display: flex; justify-content: space-between; font-size: 0.72rem; color: #666; font-family: monospace;">
              <span>Txn Ref / UTR:</span>
              <span>${t(O)}</span>
            </div>
          `:""}
        `:""}
      </div>

      <!-- Paid Official Stamp -->
      ${U?`
        <div style="text-align: center; margin: 8px 0;">
          ${N?`<img src="${N}" style="max-height: 40px; margin-bottom: 2px;" alt="Stamp"><br>`:""}
          <div style="display: inline-block; border: 2px solid ${C}; color: ${C}; font-weight: 900; font-size: 0.85rem; padding: 3px 10px; border-radius: 4px; text-transform: uppercase; transform: rotate(-3deg);">
            \u2714 ${t(ge)}
          </div>
        </div>
      `:""}

      <!-- Dynamic UPI QR -->
      ${xe?`
        <div style="text-align: center; margin: 8px 0; padding: 6px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 4px;">
          <img src="https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=${encodeURIComponent("upi://pay?pa="+ye+"&pn="+b+"&am=0&cu=INR")}" style="width: 70px; height: 70px; display: block; margin: 0 auto 3px;" alt="UPI QR">
          <div style="font-size: 0.62rem; font-weight: 700; color: #374151;">Scan to Verify via UPI</div>
        </div>
      `:""}

      <!-- Terms & Signature -->
      <div style="font-size: 0.7rem; color: #4b5563; margin-top: 6px;">
        ${_?`<div style="font-weight: 700; text-align: center; margin-bottom: 4px; color: #111827;">${t(_)}</div>`:""}
        ${V?`<div style="line-height: 1.25; font-size: 0.65rem; color: #6b7280; text-align: center; margin-bottom: 6px;">${t(V)}</div>`:""}
        
        ${Fe?`
          <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 10px; padding-top: 6px; border-top: 1px solid #eee;">
            <div style="font-size: 0.62rem; color: #9ca3af;">
              ${ve?`Generated: ${K}`:""}
            </div>
            <div style="text-align: center;">
              <div style="font-size: 0.68rem; font-weight: 700; color: #111827; border-top: 1px solid #111827; padding-top: 2px;">${t(ue)}</div>
            </div>
          </div>
        `:""}
      </div>

    </div>
  `}function Ee(c,m={}){const a=m.receiptConfig||(typeof window<"u"?window.store?.settings?.receipt:{})||{};let e=m.template||a.activeTemplate||"thermal80",r="80mm";e==="thermal_58"||e==="thermal58"?r="58mm":e==="standard_a4"||e==="standardA4"||e==="gst_invoice"?r="210mm":r="80mm";const u=Ce(c,m),i=window.open("","_blank","width=750,height=800");if(!i){window.print();return}i.document.open(),i.document.write(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Receipt \u2014 ${c?.receiptNumber||"Receipt"}</title>
      <link rel="preconnect" href="https://fonts.googleapis.com">
      <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
      <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=Courier+Prime:wght@400;700&display=swap" rel="stylesheet">
      <style>
        @page { size: ${r==="210mm"?"A4 portrait":`${r} auto`}; margin: 0; }
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
          background: #ffffff !important;
          color: #000000 !important;
          width: ${r};
          max-width: 100%;
          margin: 0 auto;
          padding: 8px;
          -webkit-font-smoothing: antialiased;
        }
        img { max-width: 100%; }
        @media print {
          body { width: ${r}; margin: 0 auto; padding: 4px; }
          * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
        }
      </style>
    </head>
    <body>
      ${u}
      <script>
        window.onload = function() {
          setTimeout(function() {
            window.print();
            window.close();
          }, 350);
        };
      <\/script>
    </body>
    </html>
  `),i.document.close()}export{Se as buildAdmissionFormHTML,Ce as buildReceiptHTML,De as generateAdmissionFormPDF,Te as previewAdmissionFormPDF,Ee as printReceiptDocument};
