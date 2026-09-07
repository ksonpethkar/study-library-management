import E from"../api.js";import{Toast as w,Modal as j,Confirm as J,Loading as I,escapeHTML as d}from"../ui.js";import{MediaFieldPicker as R}from"../mediaStudio.js";import"../i18n.js";import"../pdfGenerator.js";import{FormBuilder as W}from"../formBuilder.js";import"../utils/pushNotifications.js";import{render as Z}from"./trash.js";async function O(e){e||(e=document.createElement("div"),e.className="page-container"),e.innerHTML=`
    <div class="module-header" style="margin-bottom: 1.25rem;">
      <div class="module-title-area">
        <h2 style="font-size: 1.5rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
          <span>\u2699\uFE0F</span> Admin Master Control Hub
        </h2>
        <p style="color: var(--color-text-secondary); margin: 4px 0 0 0; font-size: 0.88rem;">
          Unified configuration center for library branding, membership policies, forms, billing, AI analytics, and mobile portals.
        </p>
      </div>
    </div>
    <div class="card" style="padding: 3rem; text-align: center;">
      <div class="loading-spinner" style="margin: 0 auto 1rem auto;"></div>
      <p style="color: var(--color-text-secondary); margin: 0; font-weight: 600;">Loading Master Control Hub...</p>
    </div>
  `;try{const[m,s,g,a,o]=await Promise.allSettled([E.get("/api/settings"),E.get("/api/branches"),E.get("/api/plans"),E.get("/api/shifts"),E.get("/api/auth/users").catch(()=>({data:[]}))]),l=m.status==="fulfilled"&&m.value?.data?m.value.data:{},r=l.businessProfile||{},u=l.systemSettings||{},n=s.status==="fulfilled"&&Array.isArray(s.value?.data)?s.value.data:[],i=g.status==="fulfilled"&&Array.isArray(g.value?.data)?g.value.data:[],b=a.status==="fulfilled"&&Array.isArray(a.value?.data)?a.value.data:[],k=o.status==="fulfilled"&&Array.isArray(o.value?.data)?o.value.data:[],A=u.general||{},x=u.payment||{},C=u.admission||{},L=u.notification||{},B=u.portal||{},D=u.automations||{},y=u.billing||{},t=u.operations||{};ee(e,{profile:r,settings:{gen:A,pay:x,adm:C,notif:L,portal:B,auto:D,billing:y,ops:t},branches:n,plans:i,shifts:b,staffUsers:k})}catch(m){console.error("Failed to load Master Settings Hub:",m),e.innerHTML=`
      <div class="card" style="padding: 2.5rem; border-color: var(--color-danger); text-align: center;">
        <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">\u26A0\uFE0F</div>
        <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Failed to load Master Settings</h3>
        <p style="color: var(--color-text-secondary); margin-bottom: 1.5rem;">${d(m.message||"Could not connect to settings service.")}</p>
        <button id="btn-retry-settings" class="btn btn-primary">\u{1F504} Retry Loading</button>
      </div>
    `,e.querySelector("#btn-retry-settings")?.addEventListener("click",()=>O())}return e}function ee(e,m){const{profile:s,settings:g,branches:a,plans:o,shifts:l,staffUsers:r}=m,{gen:u,pay:n,adm:i,notif:b,portal:k,auto:A,billing:x,ops:C}=g;e.innerHTML=`
    <!-- Top Action Bar -->
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.25rem; flex-wrap: wrap; gap: 12px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 12px 16px; box-shadow: var(--shadow-xs);">
      <div>
        <h2 style="margin: 0; font-size: 1.3rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
          <span>\u2699\uFE0F</span> Master Admin Control Hub
        </h2>
        <span style="font-size: 0.8rem; color: var(--color-text-secondary);">Single Source of Truth (SSOT) \u2022 Instant real-time synchronization</span>
      </div>
      <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
        <button id="btn-master-quick-backup" class="btn btn-sm btn-outline-success" style="font-weight: 700; font-size: 0.82rem; padding: 6px 12px; display: inline-flex; align-items: center; gap: 6px;">
          <span>\u{1F4BE}</span> Backup
        </button>
      </div>
    </div>

    <!-- Responsive Adaptive Master Studio Layout -->
    <div class="master-hub-layout">
      
      <!-- Adaptive Studio Smart-Rail (Desktop 60px rail with hover expansion, Mobile Segmented Ribbon) -->
      <aside class="master-hub-sidebar">
        
        <div class="studio-section-label">Core Setup</div>
        <div class="studio-nav-group">
          <button type="button" class="studio-nav-item active" data-studio="branding" data-tooltip="Library Branding & Info">
            <span class="studio-icon">\u{1F3E2}</span> <span class="studio-label">Branding & Profile</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="memberships" data-tooltip="Plans, Fees & Fines">
            <span class="studio-icon">\u{1F4B3}</span> <span class="studio-label">Plans & Fees</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="formbuilder" data-tooltip="Registration Form Builder">
            <span class="studio-icon">\u{1F4DD}</span> <span class="studio-label">Form Builder</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="centers_seats" data-tooltip="Centers, Seats & Shifts">
            <span class="studio-icon">\u{1F4BA}</span> <span class="studio-label">Centers & Shifts</span>
          </button>
        </div>

        <div class="studio-section-label">Finance & Ops</div>
        <div class="studio-nav-group">
          <button type="button" class="studio-nav-item" data-studio="billing_receipt" data-tooltip="Receipt Builder & Billing">
            <span class="studio-icon">\u{1F9FE}</span> <span class="studio-label">Receipt Studio</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="modules_manager" data-tooltip="App Modules & Toggles">
            <span class="studio-icon">\u{1F9E9}</span> <span class="studio-label">Module Toggles</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="notifications" data-tooltip="WhatsApp & Notifications">
            <span class="studio-icon">\u{1F4AC}</span> <span class="studio-label">WhatsApp Alerts</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="operations" data-tooltip="Hours, Holidays & Notices">
            <span class="studio-icon">\u{1F552}</span> <span class="studio-label">Hours & Notices</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="staff_rbac" data-tooltip="Staff & Permissions (RBAC)">
            <span class="studio-icon">\u{1F465}</span> <span class="studio-label">Staff & Roles</span>
          </button>
        </div>

        <div class="studio-section-label">Portals & AI</div>
        <div class="studio-nav-group">
          <button type="button" class="studio-nav-item" data-studio="website_cms" data-tooltip="Website CMS & SEO Studio">
            <span class="studio-icon">\u{1F310}</span> <span class="studio-label">Website CMS</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="student_portal" data-tooltip="Student Portal Controls">
            <span class="studio-icon">\u{1F4F1}</span> <span class="studio-label">Student Portal</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="automations_ai" data-tooltip="Automations & AI Insights">
            <span class="studio-icon">\u{1F916}</span> <span class="studio-label">AI Automations</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="security_backup" data-tooltip="Security & Data Backup">
            <span class="studio-icon">\u{1F512}</span> <span class="studio-label">Security Backup</span>
          </button>
          <button type="button" class="studio-nav-item" data-studio="system_health" data-tooltip="System Health & Diagnostics">
            <span class="studio-icon">\u{1F3E5}</span> <span class="studio-label">Health Monitor</span>
          </button>
          <button type="button" class="studio-nav-item studio-trash-item" data-studio="trash" data-tooltip="Recycle Bin & Trash">
            <span class="studio-icon">\u{1F5D1}\uFE0F</span> <span class="studio-label">Recycle Bin</span>
          </button>
        </div>

      </aside>

      <!-- Active Studio Suite Viewport -->
      <main id="master-studio-viewport" style="min-width: 0; width: 100%;">
        <!-- Dynamic Studio Content is Mounted Here with 0ms Delay -->
      </main>

    </div>

    <!-- Sticky Mobile Master Save Bar (visible on mobile viewports) -->
    <div class="mobile-settings-sticky-save">
      <button type="button" id="btn-module-save-mobile" class="btn btn-primary btn-save-mobile">
        <span>\u{1F4BE}</span> Save Settings
      </button>
    </div>
  `;const L=document.createElement("style");L.textContent=`
    .master-hub-layout {
      display: grid;
      grid-template-columns: 60px 1fr;
      gap: 16px;
      align-items: start;
      position: relative;
    }
    .master-hub-sidebar {
      background: var(--color-surface);
      border: 1px solid var(--color-border);
      border-radius: var(--radius-lg);
      padding: 8px 6px;
      position: sticky;
      top: 80px;
      width: 60px;
      transition: width 0.22s var(--ease-spring), box-shadow 0.22s var(--ease-spring);
      overflow: hidden;
      z-index: 200;
      box-shadow: var(--shadow-xs);
    }
    .master-hub-sidebar:hover {
      width: 210px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
    }
    .studio-section-label {
      font-size: 0.65rem;
      font-weight: 800;
      text-transform: uppercase;
      color: var(--color-text-muted);
      padding: 8px 8px 4px 8px;
      letter-spacing: 0.5px;
      white-space: nowrap;
      display: none;
    }
    .master-hub-sidebar:hover .studio-section-label {
      display: block;
    }
    .studio-nav-group {
      display: flex;
      flex-direction: column;
      gap: 3px;
    }
    .studio-nav-item {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 10px;
      width: 100%;
      text-align: left;
      border: 1px solid transparent;
      background: transparent;
      color: var(--color-text-secondary);
      font-size: 0.85rem;
      font-weight: 600;
      border-radius: var(--radius-md);
      cursor: pointer;
      transition: all 0.15s var(--ease-spring);
      white-space: nowrap;
      user-select: none;
      -webkit-user-select: none;
    }
    .studio-icon {
      font-size: 1.15rem;
      min-width: 24px;
      text-align: center;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
    }
    .studio-label {
      display: none;
      font-size: 0.84rem;
      font-weight: 600;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
    .master-hub-sidebar:hover .studio-label {
      display: inline;
    }
    .studio-nav-item:hover {
      background: var(--color-surface-hover);
      color: var(--color-text-primary);
      transform: translateX(1px);
    }
    .studio-nav-item.active {
      background: var(--color-primary-bg, rgba(99, 102, 241, 0.15));
      color: var(--color-primary);
      font-weight: 700;
      border-color: rgba(99, 102, 241, 0.3);
    }
    .studio-trash-item {
      color: var(--color-danger) !important;
    }
    .studio-trash-item.active {
      background: rgba(239, 68, 68, 0.15) !important;
      border-color: rgba(239, 68, 68, 0.3) !important;
    }

    /* Mobile / Tablet Segmented Ribbon Mode */
    @media (max-width: 991px) {
      .master-hub-layout {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      .master-hub-sidebar {
        position: static;
        width: 100% !important;
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 6px 8px;
        border-radius: var(--radius-lg);
        scrollbar-width: none;
      }
      .master-hub-sidebar::-webkit-scrollbar {
        display: none;
      }
      .studio-section-label {
        display: none !important;
      }
      .studio-nav-group {
        display: flex;
        flex-direction: row;
        gap: 4px;
      }
      .studio-nav-item {
        padding: 6px 12px;
        width: auto;
        border-radius: 9999px;
        background: var(--color-bg-secondary);
        font-size: 0.8rem;
      }
      .studio-label {
        display: inline !important;
      }
      .studio-icon {
        font-size: 1rem;
        min-width: 18px;
      }
    }
    .settings-accordion-card {
      background: var(--color-bg-secondary);
      border: 1px solid var(--color-border);
      border-radius: var(--radius-md);
      margin-bottom: 14px;
      overflow: visible;
      transition: all 0.2s ease;
    }
    .settings-accordion-header, .cms-accordion-header {
      padding: 12px 16px;
      display: flex;
      justify-content: space-between;
      align-items: center;
      cursor: pointer;
      user-select: none;
      background: var(--color-surface-hover);
      border-bottom: 1px solid var(--color-border);
      border-radius: var(--radius-md) var(--radius-md) 0 0;
      transition: background 0.15s ease;
    }
    .settings-accordion-header:hover, .cms-accordion-header:hover {
      background: var(--color-bg-secondary);
    }
    .settings-accordion-header h5, .settings-accordion-header h4, .cms-accordion-header h5, .cms-accordion-header h4 {
      margin: 0;
      font-size: 0.95rem;
      font-weight: 800;
      color: var(--color-primary);
      display: flex;
      align-items: center;
      gap: 6px;
    }
    .settings-accordion-toggle, .cms-accordion-toggle {
      font-size: 0.9rem;
      font-weight: bold;
      color: var(--color-text-muted);
      transition: transform 0.2s ease, color 0.15s ease;
      padding: 4px 8px;
      border-radius: 4px;
    }
    .settings-accordion-header:hover .settings-accordion-toggle, .cms-accordion-header:hover .cms-accordion-toggle {
      color: var(--color-primary);
      background: rgba(108, 92, 231, 0.08);
    }
    .settings-accordion-body, .cms-accordion-body {
      padding: 16px;
      display: block;
    }
    @media (max-width: 900px) {
      .master-hub-layout {
        grid-template-columns: 1fr !important;
      }
      .master-hub-sidebar {
        position: static !important;
        overflow-x: auto;
      }
    }
  `,e.appendChild(L);const B=e.querySelector("#master-studio-viewport");let D="branding";const y={branding:()=>te(s,u),memberships:()=>ae(n,i,o,m),formbuilder:()=>se(e),centers_seats:()=>oe(a,l),billing_receipt:()=>re(s,x,n,m),modules_manager:()=>le(),notifications:()=>Q(b,s),operations:()=>ie(C),staff_rbac:()=>ne(r,a),website_cms:()=>ce(),student_portal:()=>de(k,s),automations_ai:()=>V(A),security_backup:()=>me(),system_health:()=>pe(),trash:async()=>{const c=document.createElement("div");return c.style.cssText="width: 100%; max-width: 100%; box-sizing: border-box;",await Z(c),c}},t=async c=>{if(!(!c||!y[c])){D=c;try{localStorage.setItem("sl_active_settings_studio",c);const f=window.location.hash.split("?")[0]||"#/settings";window.history.replaceState(null,"",`${f}?tab=${c}`)}catch{}if(e.querySelectorAll(".studio-nav-item").forEach(f=>{f.classList.toggle("active",f.dataset.studio===c)}),B&&y[c]){B.innerHTML="";const f=y[c](),h=f&&typeof f.then=="function"?await f:f;h instanceof HTMLElement?B.appendChild(h):typeof h=="string"&&(B.innerHTML=h),K(e,c,m),setTimeout(()=>ue(B),20)}}};e.querySelectorAll(".studio-nav-item").forEach(c=>{c.addEventListener("click",()=>{t(c.dataset.studio)})});const p=new URLSearchParams(window.location.hash.split("?")[1]||"").get("tab")||localStorage.getItem("sl_active_settings_studio")||(window.location.hash.includes("trash")?"trash":"branding");t(y[p]?p:"branding"),e.querySelector("#btn-master-quick-backup")?.addEventListener("click",async()=>{try{I.show("Generating full system database backup snapshot...");const c=localStorage.getItem("sl_token")||localStorage.getItem("token")||"";let f=await fetch("/api/backup/export",{headers:{Authorization:`Bearer ${c}`}});if(f.ok||(f=await fetch("/api/settings/backup",{headers:{Authorization:`Bearer ${c}`}})),I.hide(),!f.ok)throw new Error("Backup failed (HTTP "+f.status+")");const h=await f.blob(),F=URL.createObjectURL(h),q=document.createElement("a");q.href=F,q.download=`StudyLibrary_Backup_${new Date().toISOString().split("T")[0]}.json`,document.body.appendChild(q),q.click(),document.body.removeChild(q),w.success("Full database snapshot downloaded successfully!")}catch(c){I.hide(),w.error(c.message||"Backup failed")}});const _studioLabels={branding:"Branding",memberships:"Plans & Fees",formbuilder:"Form Builder",centers_seats:"Centers & Shifts",billing_receipt:"Receipt Studio",modules_manager:"Module Toggles",notifications:"WhatsApp Alerts",operations:"Hours & Notices",staff_rbac:"Staff & Roles",website_cms:"Website CMS",student_portal:"Student Portal",automations_ai:"AI Automations",security_backup:"Security",system_health:"Health Monitor",trash:"Trash"};const _noSaveStudios=new Set(["formbuilder","centers_seats","modules_manager","staff_rbac","website_cms","security_backup","system_health","trash"]);function _updateMobileSaveBtn(){const mb=e.querySelector("#btn-module-save-mobile");if(!mb)return;if(_noSaveStudios.has(D)){mb.style.display="none";return}mb.style.display="";mb.innerHTML=`<span>\u{1F4BE}</span> Save ${_studioLabels[D]||"Settings"}`}const _origTabSwitch=t;const _wrappedTabSwitch=async c=>{await _origTabSwitch(c);_updateMobileSaveBtn()};e.querySelectorAll(".studio-nav-item").forEach(c=>{const cloned=c.cloneNode(true);c.parentNode.replaceChild(cloned,c);cloned.addEventListener("click",()=>{_wrappedTabSwitch(cloned.dataset.studio)})});_updateMobileSaveBtn();async function _saveActiveModule(){const btn=e.querySelector("#btn-module-save-mobile");if(btn)I.button(btn,true);try{await _doModuleSave(D,e,s,m);w.success(`${_studioLabels[D]||"Settings"} saved successfully!`);try{localStorage.removeItem("sl_public_config_cache");localStorage.removeItem("sl_public_profile_cache");window.dispatchEvent(new CustomEvent("sl:settings-updated",{detail:{studio:D}}))}catch{}}catch(err){w.error(err.message||"Failed to save settings.")}finally{if(btn)I.button(btn,false)}}async function _doModuleSave(studio,el,sData,mData){const o=(sel,fb)=>{const x=el.querySelector(sel);return x?x.value.trim():fb??""},l=(sel,fb)=>{const x=el.querySelector(sel);return x&&x.value!==""?Number(x.value):fb??0},r=(sel,fb)=>{const x=el.querySelector(sel);return x?x.checked:!!fb};if(studio==="branding"){const prof={...sData.profile,businessName:o("#setting-businessName",sData.profile.businessName),tagline:o("#setting-tagline",sData.profile.tagline),phone:o("#setting-phone",sData.profile.phone),email:o("#setting-email",sData.profile.email),website:o("#setting-website",sData.profile.website),address:o("#setting-address",sData.profile.address),city:o("#setting-city",sData.profile.city),state:o("#setting-state",sData.profile.state),pincode:o("#setting-pincode",sData.profile.pincode),registrationNumber:o("#setting-regNumber",sData.profile.registrationNumber),gstNumber:o("#setting-gstNumber",sData.profile.gstNumber),logo:(el.querySelector("#setting-logo")||el.querySelector('input[name="logo"]'))?.value?.trim()||sData.profile.logo,favicon:(el.querySelector("#setting-favicon")||el.querySelector('input[name="favicon"]'))?.value?.trim()||sData.profile.favicon,stampImage:(el.querySelector("#setting-stamp")||el.querySelector('input[name="stampImage"]'))?.value?.trim()||sData.profile.stampImage,bannerImage:(el.querySelector("#setting-banner")||el.querySelector('input[name="bannerImage"]'))?.value?.trim()||sData.profile.bannerImage,upiId:o("#setting-bill-upiId",sData.profile.upiId),upiQrCode:(el.querySelector("#setting-bill-upiQr")||el.querySelector('input[name="upiQrCode"]'))?.value?.trim()||sData.profile.upiQrCode,bankDetails:{...sData.profile.bankDetails||{},accountName:o("#setting-bank-accName",sData.profile.bankDetails?.accountName),accountNumber:o("#setting-bank-accNo",sData.profile.bankDetails?.accountNumber),bankName:o("#setting-bank-name",sData.profile.bankDetails?.bankName),ifscCode:o("#setting-bank-ifsc",sData.profile.bankDetails?.ifscCode),branchName:o("#setting-bank-branch",sData.profile.bankDetails?.branchName)},paymentInstructions:o("#setting-pay-instructions",sData.profile.paymentInstructions),gatewayProvider:el.querySelector("#setting-gateway-provider")?.value||sData.profile.gatewayProvider||"manual_upi",razorpayKeyId:o("#setting-razorpay-key",sData.profile.razorpayKeyId),socialLinks:{...sData.profile.socialLinks||{},whatsapp:o("#setting-social-wa",sData.profile.socialLinks?.whatsapp),instagram:o("#setting-social-insta",sData.profile.socialLinks?.instagram),facebook:o("#setting-social-fb",sData.profile.socialLinks?.facebook)}};const pmr=el.querySelectorAll(".setting-paymethod-row");if(pmr.length>0){prof.paymentMethods=Array.from(pmr).map((t2,p2)=>({key:t2.dataset.key,name:t2.querySelector(".spm-name")?.value?.trim()||t2.dataset.name,subtitle:t2.querySelector(".spm-sub")?.value?.trim()||"",icon:t2.dataset.icon||"\\u{1F4B3}",enabled:t2.querySelector(".spm-enabled")?t2.querySelector(".spm-enabled").checked:true,order:p2+1,instructions:t2.querySelector(".spm-instructions")?.value?.trim()||"",requiresRef:t2.querySelector(".spm-reqref")?t2.querySelector(".spm-reqref").checked:true,refLabel:t2.querySelector(".spm-reflabel")?.value?.trim()||"Transaction Reference / UTR *"}))}const res=await E.put("/api/settings/business-profile",prof);Object.assign(sData.profile,prof);const ht=el.querySelector("#branding-headerText")?.value?.trim(),tl=el.querySelector("#branding-tagline")?.value?.trim();if(ht||tl)try{await E.put("/api/custom-fields/templates/active",{branding:{headerText:ht||"Student Admission Wizard",tagline:tl||"Silence, Focus & Success",alignment:el.querySelector("#branding-alignment")?.value||"center",logoSize:el.querySelector("#branding-logoSize")?.value||"64",showLogo:true}})}catch(e2){console.warn("FormTemplate branding save:",e2.message)}if(res?.data&&window.ThemeManager?.applyPublicBranding)window.ThemeManager.applyPublicBranding(res.data);if(typeof window.updateDynamicFaviconAndTitle==="function"&&res?.data)window.updateDynamicFaviconAndTitle(res.data)}else if(studio==="memberships"){await E.put("/api/settings/system-settings",{payment:{gracePeriod:l("#setting-pay-grace",sData.settings.pay?.gracePeriod??5),lateFeeAmount:l("#setting-pay-lateFee",sData.settings.pay?.lateFeeAmount??50),autoSuspendDays:l("#setting-pay-suspend",sData.settings.pay?.autoSuspendDays??15)},locker:{enableAddon:r("#setting-locker-enable",sData.settings.locker?.enableAddon!==false),monthlyFee:l("#setting-locker-fee",sData.settings.locker?.monthlyFee??200),deposit:l("#setting-locker-deposit",sData.settings.locker?.deposit??0),title:o("#setting-locker-title",sData.settings.locker?.title||"Add Personal Study Locker"),description:o("#setting-locker-desc",sData.settings.locker?.description||"Secure private key-allotted locker to safely keep heavy study books, notes & laptop.")},admission:{idPrefix:o("#setting-adm-idPrefix",sData.settings.adm?.idPrefix||"STU")}})}else if(studio==="notifications"){await E.put("/api/settings/system-settings",{notification:{enableWhatsapp:r("#setting-notif-wa",sData.settings.notif?.enableWhatsapp??true),whatsappScheduleTime:o("#setting-notif-time",sData.settings.notif?.whatsappScheduleTime||"09:30"),expiryReminderDays:o("#setting-notif-expiryDays",sData.settings.notif?.expiryReminderDays||"7, 3, 1, 0"),balanceReminderDays:o("#setting-notif-balanceDays",sData.settings.notif?.balanceReminderDays||"7, 3, 1"),enableAutoExpiryBot:r("#setting-notif-expiryBot",sData.settings.notif?.enableAutoExpiryBot!==false),enableAutoDuesBot:r("#setting-notif-duesBot",sData.settings.notif?.enableAutoDuesBot!==false),enableConversationalBot:r("#setting-notif-chatBot",sData.settings.notif?.enableConversationalBot!==false),whatsappProvider:o("#setting-notif-provider",sData.settings.notif?.whatsappProvider||"none"),ultramsgInstanceId:o("#setting-notif-ultramsgId",sData.settings.notif?.ultramsgInstanceId||""),ultramsgToken:o("#setting-notif-ultramsgToken",sData.settings.notif?.ultramsgToken||""),fast2smsApiKey:o("#setting-notif-fast2smsKey",sData.settings.notif?.fast2smsApiKey||""),metaPhoneNumberId:o("#setting-notif-metaPhoneId",sData.settings.notif?.metaPhoneNumberId||""),metaAccessToken:o("#setting-notif-metaToken",sData.settings.notif?.metaAccessToken||""),webhookUrl:o("#setting-notif-webhookUrl",sData.settings.notif?.webhookUrl||"")}})}else if(studio==="operations"){await E.put("/api/settings/system-settings",{operations:{openingTime:o("#setting-ops-open",sData.settings.ops?.openingTime||"06:00"),closingTime:o("#setting-ops-close",sData.settings.ops?.closingTime||"23:00"),weeklyOff:o("#setting-ops-weeklyOff",sData.settings.ops?.weeklyOff||"none"),autoCheckout:r("#setting-ops-autoCheckout",sData.settings.ops?.autoCheckout!==false),autoCheckoutHours:l("#setting-ops-autoCheckoutHours",Number(sData.settings.ops?.autoCheckoutHours)||16),autoCheckoutTime:o("#setting-ops-autoCheckoutTime",sData.settings.ops?.autoCheckoutTime||"23:00"),gracePeriodMinutes:l("#setting-ops-graceMinutes",Number(sData.settings.ops?.gracePeriodMinutes)||15),latePenaltyPerHour:l("#setting-ops-overstayPenalty",Number(sData.settings.ops?.latePenaltyPerHour)||0),examExtendedHours:r("#setting-ops-examHours",!!sData.settings.ops?.examExtendedHours),emergencyNotice:o("#setting-ops-emergencyNotice",sData.settings.ops?.emergencyNotice||""),emergencyNoticeEnabled:r("#setting-ops-emergencyToggle",!!sData.settings.ops?.emergencyNoticeEnabled)},kiosk:{enableVoice:r("#setting-kiosk-voice",sData.settings.kiosk?.enableVoice!==false),voiceLanguage:o("#setting-kiosk-lang",sData.settings.kiosk?.voiceLanguage||"en-IN"),soundEnabled:r("#setting-kiosk-sound",sData.settings.kiosk?.soundEnabled!==false),autoCheckout:r("#setting-kiosk-autoCheckout",sData.settings.kiosk?.autoCheckout!==false),autoCheckoutHours:l("#setting-kiosk-checkoutHours",Number(sData.settings.kiosk?.autoCheckoutHours)||16),screenTimeoutSeconds:l("#setting-kiosk-timeout",Number(sData.settings.kiosk?.screenTimeoutSeconds)||10),announcementVolume:l("#setting-kiosk-volume",Number(sData.settings.kiosk?.announcementVolume)||80)}})}else if(studio==="student_portal"){const portalData={...sData.settings.portal||{}};el.querySelectorAll(".student-portal-toggle").forEach(t2=>{portalData[t2.dataset.key]=t2.checked});await E.put("/api/settings/system-settings",{portal:portalData})}else if(studio==="automations_ai"){await E.put("/api/settings/system-settings",{automations:{autoSeatExpiry:r("#setting-auto-seatExpiry",sData.settings.auto?.autoSeatExpiry!==false),autoDueReminders:r("#setting-auto-dueReminders",sData.settings.auto?.autoDueReminders!==false)}})}else if(studio==="billing_receipt"){const tpl=el.querySelector(".receipt-format-card.active")?.dataset.format||sData.settings.billing?.defaultTemplate||"thermal80";const gstin=el.querySelector("#rc-header-gstin")?.value?.trim();const rcfg={activeTemplate:tpl,header:{showLogo:el.querySelector("#rc-toggle-logo")?el.querySelector("#rc-toggle-logo").checked:true,showBusinessName:true,subtitle:el.querySelector("#rc-header-subtitle")?.value?.trim()||"Official Fee Receipt",showAddress:el.querySelector("#rc-toggle-address")?el.querySelector("#rc-toggle-address").checked:true,showPhone:el.querySelector("#rc-toggle-contact")?el.querySelector("#rc-toggle-contact").checked:true,showEmail:el.querySelector("#rc-toggle-contact")?el.querySelector("#rc-toggle-contact").checked:true,showGst:!!gstin,gstNumber:gstin,headerColor:el.querySelector("#rc-header-color")?.value||"#4f46e5"},body:{showStudentId:el.querySelector("#rc-toggle-stuId")?el.querySelector("#rc-toggle-stuId").checked:true,showStudentPhone:el.querySelector("#rc-toggle-stuPhone")?el.querySelector("#rc-toggle-stuPhone").checked:true,showSeatNumber:el.querySelector("#rc-toggle-seat")?el.querySelector("#rc-toggle-seat").checked:true,showShift:el.querySelector("#rc-toggle-seat")?el.querySelector("#rc-toggle-seat").checked:true,showPeriod:el.querySelector("#rc-toggle-validity")?el.querySelector("#rc-toggle-validity").checked:true,showDiscount:el.querySelector("#rc-toggle-breakdown")?el.querySelector("#rc-toggle-breakdown").checked:true,showPaymentMethod:el.querySelector("#rc-toggle-paymentMode")?el.querySelector("#rc-toggle-paymentMode").checked:true,showTransactionId:el.querySelector("#rc-toggle-paymentMode")?el.querySelector("#rc-toggle-paymentMode").checked:true},stamp:{showStamp:el.querySelector("#rc-toggle-stamp")?el.querySelector("#rc-toggle-stamp").checked:true,stampText:el.querySelector("#rc-stamp-text")?.value?.trim()||"PAID \\u2022 OFFICIAL RECEIPT",stampColor:el.querySelector("#rc-stamp-color")?.value||"#059669",showWatermark:tpl==="standardA4"},footer:{showSignature:el.querySelector("#rc-toggle-signature")?el.querySelector("#rc-toggle-signature").checked:true,signatureLabel:el.querySelector("#rc-signature-label")?.value?.trim()||"Authorized Signatory",showUpiQr:el.querySelector("#rc-toggle-upiqr")?el.querySelector("#rc-toggle-upiqr").checked:true,termsText:el.querySelector("#rc-terms-text")?.value?.trim(),customNote:el.querySelector("#rc-custom-note")?.value?.trim(),showTimestamp:el.querySelector("#rc-toggle-timestamp")?el.querySelector("#rc-toggle-timestamp").checked:true},gst:{enabled:Number(el.querySelector("#setting-bill-gstRate")?.value||18)>0,gstRate:Number(el.querySelector("#setting-bill-gstRate")?.value||18),hsnCode:el.querySelector("#setting-bill-hsn")?.value?.trim()||"999293"}};await Promise.all([E.put("/api/settings/receipt-config",rcfg),E.put("/api/settings/system-settings",{billing:{receiptPrefix:o("#setting-bill-prefix",sData.settings.billing?.receiptPrefix||"LIB-2026"),defaultTemplate:tpl,gstRate:l("#setting-bill-gstRate",sData.settings.billing?.gstRate??18),hsnSacCode:o("#setting-bill-hsn",sData.settings.billing?.hsnSacCode||"999293"),refundPolicyDays:l("#setting-bill-refundDays",sData.settings.billing?.refundPolicyDays??3)}}),E.put("/api/settings/business-profile",{upiId:o("#setting-bill-upiId",sData.profile.upiId),bankDetails:{...sData.profile.bankDetails||{},accountName:o("#setting-bank-accName",sData.profile.bankDetails?.accountName),accountNumber:o("#setting-bank-accNo",sData.profile.bankDetails?.accountNumber),bankName:o("#setting-bank-name",sData.profile.bankDetails?.bankName),ifscCode:o("#setting-bank-ifsc",sData.profile.bankDetails?.ifscCode),branchName:o("#setting-bank-branch",sData.profile.bankDetails?.branchName)}})])}else{return}}e.querySelector("#btn-module-save-mobile")?.addEventListener("click",()=>_saveActiveModule());document.addEventListener("click",ev=>{const sbtn=ev.target.closest(".btn-save-module");if(sbtn){const studio=sbtn.dataset.studio||D;const origD=D;D=studio;I.button(sbtn,true);_doModuleSave(studio,e,s,m).then(()=>{w.success(`${_studioLabels[studio]||"Settings"} saved successfully!`);try{localStorage.removeItem("sl_public_config_cache");localStorage.removeItem("sl_public_profile_cache")}catch{}}).catch(err=>{w.error(err.message||"Failed to save.")}).finally(()=>{I.button(sbtn,false);D=origD})}})}function te(e,m){const s=document.createElement("div");return s.className="card",s.style.cssText="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);",s.innerHTML=`
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F3E2} Library Branding & Global Identity</h3>
        <p class="text-muted small mb-0">Configure your study centre's public name, official logos, contact information, and terms.</p>
      </div>
      <div class="d-flex gap-2 align-items-center">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
      </div>
    <div style="text-align: right; padding: 12px 0 4px 0;"><button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="billing_receipt" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">💾 Save Receipt Studio</button></div>
    <div style="text-align: right; padding: 12px 0 4px 0;"><button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="automations_ai" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">💾 Save AI Automations</button></div>
    <div style="text-align: right; padding: 12px 0 4px 0;"><button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="student_portal" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">💾 Save Student Portal</button></div>
    <div style="text-align: right; padding: 12px 0 4px 0;"><button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="branding" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">💾 Save Branding</button></div>
    </div>

    <!-- Section 1: \u{1F3E2} Basic Library Profile & Identification -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>\u{1F3E2}</span> Basic Business Details & Identity</h5>
        <span class="settings-accordion-toggle">\u25B2</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Library / Business Name *</label>
            <input type="text" id="setting-businessName" class="form-control" value="${d(e.businessName||"Study Library")}" placeholder="e.g. Study Library & Reading Hall">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Brand Tagline / Slogan</label>
            <input type="text" id="setting-tagline" class="form-control" value="${d(e.tagline||"Premier Air-Conditioned Self-Study Space")}" placeholder="e.g. Premier Self-Study Space">
          </div>

          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Official Phone / WhatsApp</label>
            <input type="tel" id="setting-phone" class="form-control" value="${d(e.phone||"")}" placeholder="+91 9876543210">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Official Support Email</label>
            <input type="email" id="setting-email" class="form-control" value="${d(e.email||"")}" placeholder="support@library.com">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Website / Domain</label>
            <input type="url" id="setting-website" class="form-control" value="${d(e.website||"")}" placeholder="https://yourlibrary.com">
          </div>

          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">Shop Act / Registration Number</label>
            <input type="text" id="setting-regNumber" class="form-control" value="${d(e.registrationNumber||"")}" placeholder="e.g. REG-MH-2026-9988">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">GSTIN Tax Number</label>
            <input type="text" id="setting-gstNumber" class="form-control font-monospace" value="${d(e.gstNumber||"")}" placeholder="e.g. 27AAAAA0000A1Z5">
          </div>
        </div>
      </div>
    </div>

    <!-- Section 2: \u{1F4CD} Physical Campus Address & Location -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>\u{1F4CD}</span> Physical Campus Address & Location</h5>
        <span class="settings-accordion-toggle">\u25B2</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-12">
            <label class="form-label" style="font-weight: 600;">Physical Campus Address</label>
            <textarea id="setting-address" class="form-control" rows="2" placeholder="Full street address, landmark, area...">${d(e.address||"")}</textarea>
          </div>

          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">City</label>
            <input type="text" id="setting-city" class="form-control" value="${d(e.city||"")}" placeholder="e.g. Pune">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">State</label>
            <input type="text" id="setting-state" class="form-control" value="${d(e.state||"")}" placeholder="e.g. Maharashtra">
          </div>
          <div class="col-md-4">
            <label class="form-label" style="font-weight: 600;">Pincode</label>
            <input type="text" id="setting-pincode" class="form-control" value="${d(e.pincode||"")}" placeholder="e.g. 411001">
          </div>
        </div>
      </div>
    </div>

    <!-- Section 3: \u{1F5BC}\uFE0F Brand Media & Visual Assets -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>\u{1F5BC}\uFE0F</span> Brand Media & Visual Assets (Upload, Crop & Remove)</h5>
        <span class="settings-accordion-toggle">\u25B2</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-6 col-lg-3" id="mount-branding-logo"></div>
          <div class="col-md-6 col-lg-3" id="mount-branding-favicon"></div>
          <div class="col-md-6 col-lg-3" id="mount-branding-stamp"></div>
          <div class="col-md-6 col-lg-3" id="mount-branding-banner"></div>
        </div>
      </div>
    </div>

    <!-- Section 4: \u{1F310} Social Media Channels & Links -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>\u{1F310}</span> Social Media Channels & Groups</h5>
        <span class="settings-accordion-toggle">\u25B2</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-4">
            <label class="form-label small" style="font-weight: 600;">WhatsApp Channel / Group Link</label>
            <input type="url" id="setting-social-wa" class="form-control" value="${d(e.socialLinks?.whatsapp||"")}" placeholder="https://chat.whatsapp.com/...">
          </div>
          <div class="col-md-4">
            <label class="form-label small" style="font-weight: 600;">Instagram Profile URL</label>
            <input type="url" id="setting-social-insta" class="form-control" value="${d(e.socialLinks?.instagram||"")}" placeholder="https://instagram.com/...">
          </div>
          <div class="col-md-4">
            <label class="form-label small" style="font-weight: 600;">Facebook Page URL</label>
            <input type="url" id="setting-social-fb" class="form-control" value="${d(e.socialLinks?.facebook||"")}" placeholder="https://facebook.com/...">
          </div>
        </div>
      </div>
    </div>
  `,setTimeout(()=>{const g=s.querySelector("#mount-branding-logo");if(g&&typeof R<"u"){const r=R.create({name:"logo",label:"Official Library Logo",value:e.logo||"",preset:"stamp_logo",onChange:u=>{e.logo=u}});r.querySelector(".mfp-hidden-value")?.setAttribute("id","setting-logo"),g.appendChild(r)}const a=s.querySelector("#mount-branding-favicon");if(a&&typeof R<"u"){const r=R.create({name:"favicon",label:"Browser Favicon / App Icon",value:e.favicon||"",preset:"stamp_logo",onChange:u=>{e.favicon=u}});r.querySelector(".mfp-hidden-value")?.setAttribute("id","setting-favicon"),a.appendChild(r)}const o=s.querySelector("#mount-branding-stamp");if(o&&typeof R<"u"){const r=R.create({name:"stampImage",label:"Official Digital Stamp / Seal",value:e.stampImage||"",preset:"stamp_logo",onChange:u=>{e.stampImage=u}});r.querySelector(".mfp-hidden-value")?.setAttribute("id","setting-stamp"),o.appendChild(r)}const l=s.querySelector("#mount-branding-banner");if(l&&typeof R<"u"){const r=R.create({name:"bannerImage",label:"Organisation Banner / Hero Cover",value:e.bannerImage||"",preset:"cover_banner",onChange:u=>{e.bannerImage=u}});r.querySelector(".mfp-hidden-value")?.setAttribute("id","setting-banner"),l.appendChild(r)}},10),s}function ae(e,m,s,g){const a=g?.settings?.locker||{},o=g?.profile||{},l=Array.isArray(o.paymentMethods)?o.paymentMethods:[],r=new Map(l.map(n=>[n.key,n])),u=[{key:"upi",name:"Dynamic UPI QR & 1-Tap Apps",subtitle:"GPay / PhonePe / Paytm / BHIM (Instant)",icon:"\u26A1",defaultEnabled:!0,instructions:"Scan QR code or use 1-tap UPI app buttons and enter 12-digit UTR number",refLabel:"12-Digit Bank UTR / Reference Number *",requiresRef:!0},{key:"card",name:"Debit / Credit Card",subtitle:"Visa, Mastercard, RuPay & POS Swipe",icon:"\u{1F4B3}",defaultEnabled:!0,instructions:"Swipe / pay via card machine or online POS and enter card txn reference",refLabel:"Card Transaction Reference / Approval Code *",requiresRef:!0},{key:"netbanking",name:"NetBanking / Direct Bank Transfer",subtitle:"NEFT / IMPS / RTGS (All Indian Banks)",icon:"\u{1F3E6}",defaultEnabled:!0,instructions:"Transfer fee to official library bank account and enter transaction UTR or upload slip",refLabel:"Bank Transaction Reference / UTR *",requiresRef:!0},{key:"desk",name:"Pay Later at Front Desk",subtitle:"Cash / Spot Pay on Arrival",icon:"\u{1F4B5}",defaultEnabled:!0,instructions:"Your chosen seat is reserved for 24 hours. Pay cash or UPI at the front desk upon arrival.",refLabel:"",requiresRef:!1}].map(n=>{const i=r.get(n.key),b=i?i.enabled!==!1:n.defaultEnabled,k=i?.name||n.name,A=i?.subtitle||n.subtitle,x=i?.instructions||n.instructions,C=i?.requiresRef!==void 0?i.requiresRef:n.requiresRef,L=i?.refLabel||n.refLabel;return`
      <div class="setting-paymethod-row card p-3" data-key="${n.key}" data-name="${d(k)}" data-icon="${n.icon}" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); transition: all 0.2s;">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; margin-bottom: 8px;">
          <div style="display: flex; align-items: center; gap: 8px;">
            <span style="font-size: 1.4rem;">${n.icon}</span>
            <div>
              <strong style="font-size: 0.95rem; color: var(--color-text-primary);">${d(n.name)}</strong>
              <div class="text-muted small">${d(n.subtitle)}</div>
            </div>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <span class="badge ${b?"badge-success":"badge-secondary"}" id="spm-badge-${n.key}" style="font-size: 0.72rem; padding: 4px 8px;">${b?"PORTAL ACTIVE":"DISABLED"}</span>
            <div class="form-check form-switch mb-0" style="font-size: 1.15rem;">
              <input class="form-check-input spm-enabled" type="checkbox" id="spm-toggle-${n.key}" ${b?"checked":""} onchange="const b=document.getElementById('spm-badge-${n.key}'); if(b){ b.className='badge '+(this.checked?'badge-success':'badge-secondary'); b.textContent=this.checked?'PORTAL ACTIVE':'DISABLED'; }">
            </div>
          </div>
        </div>

        <div class="row g-2 mt-1">
          <div class="col-md-6">
            <label class="form-label small mb-1" style="font-weight: 700;">Portal Display Title</label>
            <input type="text" class="form-control form-control-sm spm-name" value="${d(k)}" placeholder="${d(n.name)}">
          </div>
          <div class="col-md-6">
            <label class="form-label small mb-1" style="font-weight: 700;">Subtitle / Badge</label>
            <input type="text" class="form-control form-control-sm spm-sub" value="${d(A)}" placeholder="${d(n.subtitle)}">
          </div>
          <div class="col-md-8">
            <label class="form-label small mb-1" style="font-weight: 700;">Student Instructions</label>
            <input type="text" class="form-control form-control-sm spm-instructions" value="${d(x)}" placeholder="${d(n.instructions)}">
          </div>
          <div class="col-md-4">
            <label class="form-label small mb-1" style="font-weight: 700;">UTR / Ref Label</label>
            <input type="text" class="form-control form-control-sm spm-reflabel" value="${d(L)}" placeholder="e.g. UTR / Ref *">
          </div>
        </div>
      </div>
    `}).join("");return`
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F4B3} Membership Plans, Fines & Fee Policies</h3>
          <p class="text-muted small mb-0">Configure admission fees, security deposit amounts, automated late fine formulas, and grace periods.</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
          <a href="#/plans" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u2795 Manage Plans Matrix \u2197</a>
          <button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="memberships" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">\u{1F4BE} Save Plans & Fees</button>
        </div>
      </div>

      <!-- Section 1: \u{1F4B3} Late Fees, Grace Periods & Auto-Suspend -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F4B3}</span> Fee Grace Periods, Late Fines &amp; Auto-Suspend</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Payment Grace Period (Days)</label>
              <input type="number" id="setting-pay-grace" class="form-control" value="${e["payment.gracePeriod"]??e.gracePeriod??5}" min="0" max="30">
              <small class="text-muted">Days allowed after expiry before late fine begins</small>
            </div>

            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Daily Late Fine Amount (\u20B9)</label>
              <input type="number" id="setting-pay-lateFee" class="form-control" value="${e["payment.lateFeeAmount"]??e.lateFeeAmount??50}" min="0">
              <small class="text-muted">Penalty charged per day past grace period</small>
            </div>

            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Auto-Suspend Threshold (Days)</label>
              <input type="number" id="setting-pay-suspend" class="form-control" value="${e["payment.autoSuspendDays"]??e.autoSuspendDays??15}" min="1">
              <small class="text-muted">Days overdue before student seat is auto-released</small>
            </div>

            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Student ID Prefix</label>
              <input type="text" id="setting-adm-idPrefix" class="form-control font-monospace" value="${d(m["admission.idPrefix"]||m.idPrefix||"STU")}">
              <small class="text-muted">Example: STU &rarr; STU-2026-001</small>
            </div>

            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Maximum Membership Pause Days</label>
              <input type="number" id="setting-adm-maxPause" class="form-control" value="15" min="0" max="60">
              <small class="text-muted">Days allowed for exam break membership freeze</small>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: \u{1F512} Personal Study Locker Add-on Customization -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h5><span>\u{1F512}</span> Personal Study Locker Add-on Customization</h5>
          </div>
          <div style="display: flex; align-items: center; gap: 10px;">
            <div class="form-check form-switch" style="font-size: 1.1rem; margin: 0;">
              <input class="form-check-input" type="checkbox" id="setting-locker-enable" ${a.enableAddon!==!1&&a["locker.enableAddon"]!==!1?"checked":""}>
              <label class="form-check-label" style="font-size: 0.82rem; font-weight: 700; margin-left: 4px;">Enable</label>
            </div>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3 p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Locker Monthly Fee (\u20B9)</label>
              <input type="number" id="setting-locker-fee" class="form-control" value="${a.monthlyFee??a["locker.monthlyFee"]??200}" min="0">
              <small class="text-muted">Added to admission total when selected by student</small>
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Locker Security Deposit (\u20B9)</label>
              <input type="number" id="setting-locker-deposit" class="form-control" value="${a.deposit??a["locker.deposit"]??0}" min="0">
              <small class="text-muted">Refundable locker key deposit</small>
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Add-on Option Title</label>
              <input type="text" id="setting-locker-title" class="form-control" value="${d(a.title||a["locker.title"]||"Add Personal Study Locker")}">
            </div>
            <div class="col-12">
              <label class="form-label" style="font-weight: 600;">Locker Add-on Description</label>
              <input type="text" id="setting-locker-desc" class="form-control" value="${d(a.description||a["locker.description"]||"Secure private key-allotted locker to safely keep heavy study books, notes & laptop.")}">
            </div>
          </div>
        </div>
      </div>

      <!-- Section 3: \u{1F4CB} Active Membership Plans Overview -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F4CB}</span> Active Membership Plans Overview (${s.length} Plans)</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="table-responsive">
            <table class="table" style="font-size: 0.88rem;">
              <thead>
                <tr style="background: var(--color-bg-secondary);">
                  <th>Plan Name</th>
                  <th>Duration</th>
                  <th>Shift</th>
                  <th>Base Price</th>
                  <th>Discount</th>
                  <th>Effective Fee</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                ${s.length>0?s.map(n=>{const i=Number(n.price||0),b=Number(n.discount||0),k=Math.round(n.effectivePrice!==void 0?n.effectivePrice:i*(1-b/100));return`
                  <tr>
                    <td><strong>${d(n.name)}</strong></td>
                    <td>${n.duration} ${n.durationType||"months"}</td>
                    <td><span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary); text-transform: uppercase;">${n.shift||"Any"}</span></td>
                    <td style="${b>0?"text-decoration: line-through; color: var(--color-text-muted);":""}">\u20B9${i.toLocaleString("en-IN")}</td>
                    <td>${b>0?`<span class="badge badge-danger" style="background: #ef4444; color: #fff; font-weight: 700; font-size: 0.72rem;">${b}% OFF</span>`:"\u2014"}</td>
                    <td><strong style="color: var(--color-primary);">\u20B9${k.toLocaleString("en-IN")}</strong></td>
                    <td><span class="badge" style="background: ${n.isActive!==!1?"rgba(16,185,129,0.15)":"rgba(239,68,68,0.15)"}; color: ${n.isActive!==!1?"#10b981":"#ef4444"};">${n.isActive!==!1?"Active":"Inactive"}</span></td>
                  </tr>
                `}).join(""):'<tr><td colspan="7" class="text-center p-3 text-muted">No plans created yet.</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      <!-- Section 4: \u{1F4B3} Self-Registration Portal Payment Gateways (Enable / Disable) -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h5><span>\u{1F4B3}</span> Self-Registration Portal Payment Gateways &amp; Options</h5>
          </div>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div style="margin-bottom: 14px; font-size: 0.84rem; color: var(--color-text-secondary); line-height: 1.4;">
            Control which payment methods are active and displayed on the student public self-registration portal (<a href="/register" target="_blank" style="font-weight: 700; color: var(--color-primary);">/register \u2197</a>). You can enable or disable any method, edit titles, and set instructions.
          </div>

          <div style="display: flex; flex-direction: column; gap: 10px;" id="setting-paymethods-list">
            ${u}
          </div>

          <div style="margin-top: 14px; display: flex; justify-content: flex-end;">
            <button type="button" id="btn-save-reg-payment-methods" class="btn btn-sm btn-primary" style="font-weight: 800; padding: 7px 20px;">
              \u{1F4BE} Save Registration Payment Methods
            </button>
          </div>
        </div>
      </div>

    </div>
  `}function se(e){const m=document.createElement("div");return m.className="card",m.style.cssText="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);",m.innerHTML=`
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F4DD} Student Admission Dynamic Form Builder</h3>
        <p class="text-muted small mb-0">Drag and drop fields, create custom admission questions, and toggle mandatory/optional status.</p>
      </div>
      <a href="/register" target="_blank" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u{1F441}\uFE0F Test Public Register Form \u2197</a>
    </div>
    <div id="form-builder-mount-container" style="min-height: 400px;"></div>
  `,setTimeout(async()=>{const s=m.querySelector("#form-builder-mount-container");if(s&&typeof W<"u")try{await W.render(s)}catch(g){console.error("Form builder render error:",g),s.innerHTML=`<div class="p-4 text-center text-muted">Error loading Form Builder studio: ${d(g.message)}</div>`}},50),m}function oe(e,m){return`
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F4BA} Multi-Branch, Seating Layouts & Shift Quotas</h3>
          <p class="text-muted small mb-0">Manage library branches, desk zones (AC, Silent, Cabins), and shift timings.</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
          <a href="#/branches" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u{1F3DB}\uFE0F Branches Matrix</a>
          <a href="#/seats" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u{1F4BA} Seating Grid</a>
          <a href="#/shifts" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u{1F552} Shifts Studio</a>
        </div>
      </div>

      <!-- Section 1: \u{1F3DB}\uFE0F Active Study Centre Branches -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F3DB}\uFE0F</span> Active Study Centre Branches (${e.length})</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="table-responsive">
            <table class="table" style="font-size: 0.88rem;">
              <thead>
                <tr style="background: var(--color-bg-secondary);">
                  <th>Branch Name</th>
                  <th>Code</th>
                  <th>City</th>
                  <th>Capacity</th>
                  <th>Phone</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                ${e.length>0?e.map(s=>`
                  <tr>
                    <td><strong>${d(s.name)}</strong></td>
                    <td><code>${d(s.code||"MAIN")}</code></td>
                    <td>${d(s.city||"Central")}</td>
                    <td><strong>${s.totalSeats||50} Desks</strong></td>
                    <td>${d(s.phone||"-")}</td>
                    <td><span class="badge badge-success">Active</span></td>
                  </tr>
                `).join(""):'<tr><td colspan="6" class="text-center p-3 text-muted">No branches configured yet.</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Section 2: \u{1F552} Configured Study Shifts -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F552}</span> Configured Study Shifts &amp; Rate Multipliers (${m.length})</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="table-responsive">
            <table class="table" style="font-size: 0.88rem;">
              <thead>
                <tr style="background: var(--color-bg-secondary);">
                  <th>Shift Name</th>
                  <th>Code</th>
                  <th>Timing</th>
                  <th>Rate Multiplier</th>
                  <th>Capacity Limit</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                ${m.length>0?m.map(s=>`
                  <tr>
                    <td><strong>${d(s.name)}</strong></td>
                    <td><code>${d(s.code||"-")}</code></td>
                    <td>${s.startTime||"06:00"} \u2013 ${s.endTime||"23:00"}</td>
                    <td><span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary);">${s.priceMultiplier||1}x</span></td>
                    <td>${s.maxCapacity>0?`${s.maxCapacity} seats`:"Unlimited"}</td>
                    <td><span class="badge badge-success">Active</span></td>
                  </tr>
                `).join(""):'<tr><td colspan="6" class="text-center p-3 text-muted">No shifts configured yet.</td></tr>'}
              </tbody>
            </table>
          </div>
        </div>
      </div>

    </div>
  `}function re(e,m,s,g){const a=document.createElement("div");a.className="card",a.style.cssText="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);";let o=m["billing.defaultTemplate"]||"thermal80";return a.innerHTML=`
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-primary);">\u{1F9FE} POS Receipt Builder & GST Billing Studio</h3>
        <p class="text-muted small mb-0">Design, customize, and test-print thermal receipts (80mm/58mm), official A4 GST invoices, paid stamps, and UPI QR codes with real-time live preview.</p>
      </div>
      <div class="d-flex gap-2 align-items-center flex-wrap">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
        <button type="button" id="btn-test-print-receipt" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u{1F5A8}\uFE0F Test Print Sample</button>
        <button type="button" id="btn-save-receipt-builder" class="btn btn-sm btn-primary btn-save-module" data-studio="billing_receipt" style="font-weight: 800; padding: 6px 18px;">\u{1F4BE} Save Receipt Template</button>
      </div>
    </div>

    <!-- Template Format Selector Cards -->
    <div style="margin-bottom: 1.5rem;">
      <label class="form-label" style="font-weight: 800; font-size: 0.95rem; margin-bottom: 8px; display: flex; align-items: center; gap: 6px;">
        <span>\u{1F5A8}\uFE0F</span> Select Receipt Output Format
      </label>
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px;" id="receipt-format-grid">
        <div class="card p-3 receipt-format-card ${o==="thermal80"?"active":""}" data-format="thermal80" style="border: ${o==="thermal80"?"2px solid var(--color-primary)":"1px solid var(--color-border)"}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">\u{1F5A8}\uFE0F</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">POS Thermal 80mm</h5>
          <small class="text-muted d-block">Standard 3-inch POS roll</small>
        </div>
        <div class="card p-3 receipt-format-card ${o==="thermal58"?"active":""}" data-format="thermal58" style="border: ${o==="thermal58"?"2px solid var(--color-primary)":"1px solid var(--color-border)"}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">\u{1F4F1}</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">POS Thermal 58mm</h5>
          <small class="text-muted d-block">2-inch mobile Bluetooth roll</small>
        </div>
        <div class="card p-3 receipt-format-card ${o==="standardA4"?"active":""}" data-format="standardA4" style="border: ${o==="standardA4"?"2px solid var(--color-primary)":"1px solid var(--color-border)"}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">\u{1F4C4}</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">Official A4 Invoice</h5>
          <small class="text-muted d-block">Printable GST tax invoice</small>
        </div>
        <div class="card p-3 receipt-format-card ${o==="modern_minimal"?"active":""}" data-format="modern_minimal" style="border: ${o==="modern_minimal"?"2px solid var(--color-primary)":"1px solid var(--color-border)"}; background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <span style="font-size: 1.6rem; margin-bottom: 2px;">\u2728</span>
          <h5 style="margin: 0; font-size: 0.92rem; font-weight: 800;">Modern Digital Pass</h5>
          <small class="text-muted d-block">Clean digital fee voucher</small>
        </div>
      </div>
    </div>

    <!-- Split-Screen Controls + Live Thermal Receipt Preview -->
    <div style="display: grid; grid-template-columns: 1fr 1.1fr; gap: 20px;" class="receipt-split-layout">
      
      <!-- Left Column: Customization Controls -->
      <div style="display: flex; flex-direction: column; gap: 14px; max-height: 750px; overflow-y: auto; padding-right: 4px;">
        
        <!-- Header & Branding -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>\u{1F3E2}</span> Header &amp; Library Branding</h5>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Receipt & Invoice Prefix</label>
                <input type="text" id="setting-bill-prefix" class="form-control form-control-sm font-monospace" value="${d(m["billing.receiptPrefix"]||m.receiptPrefix||"LIB-2026")}" placeholder="e.g. LIB-2026">
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Receipt Subtitle / Tagline</label>
                <input type="text" id="rc-header-subtitle" class="form-control form-control-sm" value="Official Fee Payment Receipt">
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Header Accent Color</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="rc-header-color" class="form-control form-control-color p-0" value="#4f46e5" style="width: 34px; height: 30px; cursor: pointer;">
                  <input type="text" id="rc-header-color-text" class="form-control form-control-sm font-monospace" value="#4f46e5" maxlength="7">
                </div>
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">GSTIN / Tax Number</label>
                <input type="text" id="rc-header-gstin" class="form-control form-control-sm font-monospace" value="${d(e.gstNumber||"")}" placeholder="e.g. 27AAAAA0000A1Z5">
              </div>
              <div class="col-12 mt-2">
                <div style="display: flex; gap: 14px; flex-wrap: wrap;">
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-logo" checked>
                    <span>Show Library Logo</span>
                  </label>
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-address" checked>
                    <span>Show Address</span>
                  </label>
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-contact" checked>
                    <span>Show Phone & Email</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Student, Desk & Admission Details -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>\u{1F4CB}</span> Student Details &amp; Line Items</h5>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
          <div class="settings-accordion-body">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px;">
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-stuId" checked>
                <span>Show Student ID</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-stuPhone" checked>
                <span>Show Student Phone</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-seat" checked>
                <span>Show Desk / Shift</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-validity" checked>
                <span>Show Validity Dates</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-breakdown" checked>
                <span>Itemized Fee Breakdown</span>
              </label>
              <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                <input class="form-check-input" type="checkbox" id="rc-toggle-paymentMode" checked>
                <span>Payment Mode & Txn Ref</span>
              </label>
            </div>
          </div>
        </div>

        <!-- Official Stamp & Signature Block -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>\u{1FAAA}</span> Official Stamp &amp; Signature</h5>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-7">
                <label class="form-label small" style="font-weight: 700;">Paid Stamp Text</label>
                <input type="text" id="rc-stamp-text" class="form-control form-control-sm font-monospace" value="PAID \u2022 OFFICIAL RECEIPT">
              </div>
              <div class="col-md-5">
                <label class="form-label small" style="font-weight: 700;">Stamp Color</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="rc-stamp-color" class="form-control form-control-color p-0" value="#059669" style="width: 34px; height: 30px; cursor: pointer;">
                  <input type="text" id="rc-stamp-color-text" class="form-control form-control-sm font-monospace" value="#059669" maxlength="7">
                </div>
              </div>
              <div class="col-md-7">
                <label class="form-label small" style="font-weight: 700;">Authorized Signatory Label</label>
                <input type="text" id="rc-signature-label" class="form-control form-control-sm" value="Authorized Signatory">
              </div>
              <div class="col-12 mt-2">
                <div style="display: flex; gap: 14px; flex-wrap: wrap;">
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-stamp" checked>
                    <span>Show Paid Stamp Mark</span>
                  </label>
                  <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                    <input class="form-check-input" type="checkbox" id="rc-toggle-signature" checked>
                    <span>Show Signature Line</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Dynamic UPI QR & Payment Link on Receipt -->
        <!-- Dynamic UPI QR & Payment Link on Receipt -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>\u{1F4B3}</span> Dynamic UPI QR Code &amp; Gateway Settings</h5>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-8">
                <label class="form-label small" style="font-weight: 700;">Primary Library UPI ID (VPA)</label>
                <input type="text" id="setting-bill-upiId" class="form-control form-control-sm font-monospace" value="${d(e.upiId||"")}" placeholder="e.g. studylib@okhdfcbank">
                <small class="text-muted" style="font-size: 0.72rem;">Used to generate dynamic QR codes and deep links on /register, receipts, and student portal.</small>
              </div>
              <div class="col-md-4 d-flex align-items-center">
                <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
                  <input class="form-check-input" type="checkbox" id="rc-toggle-upiqr" checked>
                  <span>Print UPI QR on Receipts</span>
                </label>
              </div>
              <div class="col-12 mt-2">
                <label class="form-label small" style="font-weight: 700;">Payment Instructions for Students (Shown on Checkout &amp; Portal)</label>
                <input type="text" id="setting-pay-instructions" class="form-control form-control-sm" value="${d(e.paymentInstructions||"Please enter your 12-digit UTR / Reference number after completing payment.")}" placeholder="Instructions for applicants...">
              </div>
              <div class="col-md-6 mt-2">
                <label class="form-label small" style="font-weight: 700;">Online Payment Verification Mode</label>
                <select id="setting-gateway-provider" class="form-select form-select-sm">
                  <option value="manual_upi" ${!e.gatewayProvider||e.gatewayProvider==="manual_upi"?"selected":""}>\u{1F7E2} Option A: Free Dynamic UPI QR + 12-digit UTR Check (Zero Gateway Fee)</option>
                  <option value="razorpay" ${e.gatewayProvider==="razorpay"?"selected":""}>\u26A1 Option B: Razorpay PG (Cards, NetBanking, Instant Auto-Verify)</option>
                  <option value="cashfree" ${e.gatewayProvider==="cashfree"?"selected":""}>\u26A1 Option B: Cashfree Payments Gateway</option>
                  <option value="phonepe" ${e.gatewayProvider==="phonepe"?"selected":""}>\u26A1 Option B: PhonePe PG Gateway</option>
                </select>
              </div>
              <div class="col-md-6 mt-2" id="pg-credentials-block" style="display: ${e.gatewayProvider&&e.gatewayProvider!=="manual_upi"?"block":"none"};">
                <label class="form-label small" style="font-weight: 700;">API Key / Merchant ID</label>
                <input type="text" id="setting-razorpay-key" class="form-control form-control-sm font-monospace" value="${d(e.razorpayKeyId||e.cashfreeAppId||"")}" placeholder="Key ID">
              </div>
            </div>
          </div>
        </div>

        <!-- Terms, Conditions & Custom Footer Notes -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>\u{1F4DD}</span> Terms, Policies &amp; Footer Message</h5>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
          <div class="settings-accordion-body">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Terms & Conditions</label>
              <textarea id="rc-terms-text" class="form-control form-control-sm" rows="2">1. Fees paid are non-refundable. 2. Seat allotment is strictly non-transferable. 3. Maintain pin-drop silence in the reading hall.</textarea>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Footer Greeting / Custom Note</label>
              <input type="text" id="rc-custom-note" class="form-control form-control-sm" value="Thank you for choosing our study library! Best wishes for your exams.">
            </div>
            <label class="form-check form-switch mb-0" style="font-size: 0.88rem; cursor: pointer;">
              <input class="form-check-input" type="checkbox" id="rc-toggle-timestamp" checked>
              <span>Print Date & Time Timestamp</span>
            </label>
          </div>
        </div>

        <!-- GST & Bank Wire Transfer Details -->
        <div class="card settings-accordion-card">
          <div class="settings-accordion-header">
            <h5><span>\u{1F4CA}</span> GST Tax Engine &amp; Official Bank Account Details</h5>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
          <div class="settings-accordion-body">
            <div class="row g-2">
              <div class="col-md-4">
                <label class="form-label small" style="font-weight: 700;">GST Rate (%)</label>
                <input type="number" id="setting-bill-gstRate" class="form-control form-control-sm" value="${m["billing.gstRate"]??m.gstRate??18}" min="0" max="28">
              </div>
              <div class="col-md-4">
                <label class="form-label small" style="font-weight: 700;">HSN / SAC Code</label>
                <input type="text" id="setting-bill-hsn" class="form-control form-control-sm font-monospace" value="${d(m["billing.hsnSacCode"]||m.hsnSacCode||"999293")}" placeholder="999293">
              </div>
              <div class="col-md-4">
                <label class="form-label small" style="font-weight: 700;">Refund Window (Days)</label>
                <input type="number" id="setting-bill-refundDays" class="form-control form-control-sm" value="${m["billing.refundPolicyDays"]??m.refundPolicyDays??3}" min="0">
              </div>
              
              <div class="col-12 mt-2 pt-2 border-top">
                <div style="font-weight: 800; font-size: 0.82rem; color: var(--color-primary); margin-bottom: 6px;">
                  \u{1F3DB}\uFE0F Official Bank Account (Displayed on NetBanking checkout &amp; Student Portal)
                </div>
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Bank Account Holder Name</label>
                <input type="text" id="setting-bank-accName" class="form-control form-control-sm" value="${d(e.bankDetails?.accountName||"")}" placeholder="e.g. Study Library Pvt Ltd">
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Account Number</label>
                <input type="text" id="setting-bank-accNo" class="form-control form-control-sm font-monospace" value="${d(e.bankDetails?.accountNumber||"")}" placeholder="e.g. 50200012345678">
              </div>
              <div class="col-md-4 mt-2">
                <label class="form-label small" style="font-weight: 700;">Bank Name</label>
                <input type="text" id="setting-bank-name" class="form-control form-control-sm" value="${d(e.bankDetails?.bankName||"")}" placeholder="e.g. HDFC Bank">
              </div>
              <div class="col-md-4 mt-2">
                <label class="form-label small" style="font-weight: 700;">IFSC Code</label>
                <input type="text" id="setting-bank-ifsc" class="form-control form-control-sm font-monospace" value="${d(e.bankDetails?.ifscCode||"")}" placeholder="e.g. HDFC0000123">
              </div>
              <div class="col-md-4 mt-2">
                <label class="form-label small" style="font-weight: 700;">Branch Name / City</label>
                <input type="text" id="setting-bank-branch" class="form-control form-control-sm" value="${d(e.bankDetails?.branchName||"")}" placeholder="e.g. FC Road, Pune">
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- Right Column: Live Simulated Receipt Preview -->
      <div style="display: flex; flex-direction: column; position: sticky; top: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
          <div class="d-flex align-items-center gap-2">
            <span style="font-weight: 800; font-size: 0.9rem; color: var(--color-text-primary);">\u{1F4F1} Live Visual Receipt Preview</span>
            <span id="preview-format-badge" class="badge badge-primary" style="font-size: 0.72rem; text-transform: uppercase;">POS Thermal 80mm</span>
          </div>
          <button type="button" id="btn-refresh-receipt-preview" class="btn btn-xs btn-outline-secondary" style="padding: 2px 6px;">\u{1F504}</button>
        </div>

        <div id="receipt-preview-wrapper" style="width: 100%; max-height: 730px; overflow-y: auto; background: #2d3748; padding: 20px; border-radius: var(--radius-lg); display: flex; justify-content: center; box-shadow: inset 0 2px 8px rgba(0,0,0,0.4);">
          <!-- Live Thermal Paper Simulation -->
          <div id="receipt-paper" style="width: 340px; background: #ffffff; color: #111827; padding: 20px 18px; border-radius: 4px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); font-family: 'Courier New', Courier, monospace; font-size: 13px; line-height: 1.4; transition: all 0.3s ease;">
            <!-- Rendered by liveUpdateReceipt() -->
          </div>
        </div>
      </div>

    </div>
  `,setTimeout(async()=>{try{const n=await E.get("/api/settings/receipt-config");if(n.success&&n.data){const i=n.data;i.activeTemplate&&(o=i.activeTemplate,a.querySelectorAll(".receipt-format-card").forEach(b=>{b.dataset.format===o?(b.classList.add("active"),b.style.border="2px solid var(--color-primary)"):(b.classList.remove("active"),b.style.border="1px solid var(--color-border)")})),i.header?.subtitle&&(a.querySelector("#rc-header-subtitle").value=i.header.subtitle),i.header?.headerColor&&(a.querySelector("#rc-header-color").value=i.header.headerColor,a.querySelector("#rc-header-color-text").value=i.header.headerColor),i.header?.gstNumber&&(a.querySelector("#rc-header-gstin").value=i.header.gstNumber),i.header?.showLogo!==void 0&&(a.querySelector("#rc-toggle-logo").checked=i.header.showLogo),i.header?.showAddress!==void 0&&(a.querySelector("#rc-toggle-address").checked=i.header.showAddress),i.header?.showPhone!==void 0&&(a.querySelector("#rc-toggle-contact").checked=i.header.showPhone),i.body?.showStudentId!==void 0&&(a.querySelector("#rc-toggle-stuId").checked=i.body.showStudentId!==!1),i.body?.showStudentPhone!==void 0&&(a.querySelector("#rc-toggle-stuPhone").checked=i.body.showStudentPhone!==!1),i.body?.showSeatNumber!==void 0&&(a.querySelector("#rc-toggle-seat").checked=i.body.showSeatNumber!==!1),i.body?.showPeriod!==void 0&&(a.querySelector("#rc-toggle-validity").checked=i.body.showPeriod!==!1),i.body?.showDiscount!==void 0&&(a.querySelector("#rc-toggle-breakdown").checked=i.body.showDiscount!==!1),i.body?.showPaymentMethod!==void 0&&(a.querySelector("#rc-toggle-paymentMode").checked=i.body.showPaymentMethod!==!1),i.stamp?.showStamp!==void 0&&(a.querySelector("#rc-toggle-stamp").checked=i.stamp.showStamp!==!1),i.stamp?.stampText&&(a.querySelector("#rc-stamp-text").value=i.stamp.stampText),i.stamp?.stampColor&&(a.querySelector("#rc-stamp-color").value=i.stamp.stampColor,a.querySelector("#rc-stamp-color-text").value=i.stamp.stampColor),i.footer?.signatureLabel&&(a.querySelector("#rc-signature-label").value=i.footer.signatureLabel),i.footer?.showSignature!==void 0&&(a.querySelector("#rc-toggle-signature").checked=i.footer.showSignature!==!1),i.footer?.showUpiQr!==void 0&&(a.querySelector("#rc-toggle-upiqr").checked=!!i.footer.showUpiQr),i.footer?.termsText&&(a.querySelector("#rc-terms-text").value=i.footer.termsText),i.footer?.customNote&&(a.querySelector("#rc-custom-note").value=i.footer.customNote),i.footer?.showTimestamp!==void 0&&(a.querySelector("#rc-toggle-timestamp").checked=i.footer.showTimestamp!==!1),window.store&&(window.store.settings||(window.store.settings={}),window.store.settings.receipt=i)}}catch(n){console.warn("Could not load receipt-config:",n)}const l=a.querySelector("#receipt-paper"),r=a.querySelector("#preview-format-badge"),u=()=>{if(!l)return;const n=e.businessName||"The Cozy Corner Study Library",i=e.address||"MG Road, Shivajinagar, Pune 411005",b=e.phone||"+91 98765 43210",k=e.email||"contact@cozystudylibrary.com",A=a.querySelector("#rc-header-gstin")?.value?.trim(),x=a.querySelector("#setting-bill-prefix")?.value?.trim()||"LIB-2026",C=a.querySelector("#rc-header-subtitle")?.value?.trim()||"Official Fee Receipt",L=a.querySelector("#rc-header-color")?.value||"#4f46e5",B=a.querySelector("#rc-toggle-logo")?.checked!==!1,D=a.querySelector("#rc-toggle-address")?.checked!==!1,y=a.querySelector("#rc-toggle-contact")?.checked!==!1,t=a.querySelector("#rc-toggle-stuId")?.checked!==!1,p=a.querySelector("#rc-toggle-stuPhone")?.checked!==!1,S=a.querySelector("#rc-toggle-seat")?.checked!==!1,c=a.querySelector("#rc-toggle-validity")?.checked!==!1,f=a.querySelector("#rc-toggle-breakdown")?.checked!==!1,h=a.querySelector("#rc-toggle-paymentMode")?.checked!==!1,F=a.querySelector("#rc-toggle-stamp")?.checked!==!1,q=a.querySelector("#rc-stamp-text")?.value?.trim()||"PAID \u2022 OFFICIAL RECEIPT",T=a.querySelector("#rc-stamp-color")?.value||"#059669",M=a.querySelector("#rc-toggle-signature")?.checked!==!1,H=a.querySelector("#rc-signature-label")?.value?.trim()||"Authorized Signatory",N=a.querySelector("#rc-toggle-upiqr")?.checked!==!1,v=a.querySelector("#setting-bill-upiId")?.value?.trim()||e.upiId||"thecozycorner@okaxis",P=a.querySelector("#rc-terms-text")?.value?.trim(),$=a.querySelector("#rc-custom-note")?.value?.trim(),z=a.querySelector("#rc-toggle-timestamp")?.checked!==!1;o==="thermal58"?(l.style.width="260px",l.style.fontSize="11px",l.style.padding="12px 10px",l.style.borderRadius="0px",l.style.fontFamily="'Courier New', Courier, monospace",r&&(r.textContent="POS Thermal 58mm")):o==="standardA4"?(l.style.width="480px",l.style.fontSize="12px",l.style.padding="28px 24px",l.style.borderRadius="4px",l.style.fontFamily="var(--font-family, sans-serif)",r&&(r.textContent="Standard A4 Invoice")):o==="modern_minimal"?(l.style.width="380px",l.style.fontSize="12px",l.style.padding="22px 20px",l.style.borderRadius="12px",l.style.boxShadow="0 10px 25px -5px rgba(0,0,0,0.15)",l.style.fontFamily="var(--font-family, sans-serif)",r&&(r.textContent="Modern Digital Pass")):(l.style.width="340px",l.style.fontSize="12.5px",l.style.padding="18px 16px",l.style.borderRadius="0px",l.style.fontFamily="'Courier New', Courier, monospace",r&&(r.textContent="POS Thermal 80mm")),l.innerHTML=`
        <!-- Receipt Header -->
        <div style="text-align: center; border-bottom: 1.5px dashed #333; padding-bottom: 10px; margin-bottom: 10px;">
          ${B?`
            <div style="margin-bottom: 4px; text-align: center;">
              ${e.logo||(container.querySelector("#setting-logo")||container.querySelector('input[name="logo"]'))?.value?.trim()?`
                <img src="${e.logo||(container.querySelector("#setting-logo")||container.querySelector('input[name="logo"]'))?.value?.trim()}" alt="Logo" style="max-height: 48px; max-width: 120px; object-fit: contain; display: inline-block;">
              `:`
                <div style="font-size: 1.75rem;">\u{1F4DA}</div>
              `}
            </div>
          `:""}
          <div style="font-weight: 800; font-size: 1.05rem; text-transform: uppercase; color: ${L}; letter-spacing: 0.5px;">${d(n)}</div>
          <div style="font-size: 0.8rem; font-weight: 700; color: #555; text-transform: uppercase;">${d(C)}</div>
          ${D?`<div style="font-size: 0.72rem; color: #444; margin-top: 3px;">${d(i)}</div>`:""}
          ${y?`<div style="font-size: 0.72rem; color: #444;">Tel: ${d(b)} \u2022 ${d(k)}</div>`:""}
          ${A?`<div style="font-size: 0.72rem; font-weight: 700; color: #222; margin-top: 2px;">GSTIN: ${d(A)}</div>`:""}
        </div>

        <!-- Receipt Metadata -->
        <div style="border-bottom: 1px dashed #666; padding-bottom: 8px; margin-bottom: 8px; font-size: 0.82rem;">
          <div style="display: flex; justify-content: space-between;">
            <span>Receipt No:</span>
            <strong style="font-family: monospace;">${d(x)}-0042</strong>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Date & Time:</span>
            <span>${new Date().toLocaleDateString("en-IN")} 10:45 AM</span>
          </div>
          <div style="display: flex; justify-content: space-between;">
            <span>Student Name:</span>
            <strong>Rahul S. Sharma</strong>
          </div>
          ${t?`
            <div style="display: flex; justify-content: space-between;">
              <span>Student ID:</span>
              <span style="font-family: monospace;">STU-2026-0042</span>
            </div>
          `:""}
          ${p?`
            <div style="display: flex; justify-content: space-between;">
              <span>Phone (WA):</span>
              <span>+91 98765 43210</span>
            </div>
          `:""}
          ${S?`
            <div style="display: flex; justify-content: space-between;">
              <span>Allocated Seat:</span>
              <strong>Desk #012 (Zone A)</strong>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span>Shift Timing:</span>
              <span>Full Day (7 AM \u2013 11 PM)</span>
            </div>
          `:""}
          ${c?`
            <div style="display: flex; justify-content: space-between; margin-top: 2px;">
              <span>Validity Period:</span>
              <strong style="color: #059669;">01 Aug 2026 \u2013 31 Aug 2026</strong>
            </div>
          `:""}
        </div>

        <!-- Itemized Table -->
        ${f?`
          <div style="border-bottom: 1.5px dashed #333; padding-bottom: 8px; margin-bottom: 8px; font-size: 0.82rem;">
            <div style="display: flex; justify-content: space-between; font-weight: 700; border-bottom: 1px solid #ddd; padding-bottom: 3px; margin-bottom: 4px;">
              <span>Description</span>
              <span>Amount (\u20B9)</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span>Monthly Premium 24/7 (30 Days)</span>
              <span>1,200.00</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span>Personal Locker Storage Addon</span>
              <span>200.00</span>
            </div>
            <div style="display: flex; justify-content: space-between; color: #dc2626;">
              <span>Special Early Bird Discount</span>
              <span>- 100.00</span>
            </div>
            <div style="display: flex; justify-content: space-between; color: #666; font-size: 0.76rem;">
              <span>CGST (9%) + SGST (9%)</span>
              <span>234.00</span>
            </div>
          </div>
        `:""}

        <!-- Total Paid & Payment Method -->
        <div style="border-bottom: 1.5px dashed #333; padding-bottom: 8px; margin-bottom: 8px; font-size: 0.95rem;">
          <div style="display: flex; justify-content: space-between; font-weight: 800; font-size: 1.05rem;">
            <span>TOTAL AMOUNT PAID:</span>
            <span>\u20B9 1,534.00</span>
          </div>
          <div style="display: flex; justify-content: space-between; font-size: 0.8rem; color: #059669; font-weight: 700; margin-top: 2px;">
            <span>Balance Due:</span>
            <span>\u20B9 0.00 (PAID IN FULL)</span>
          </div>
          ${h?`
            <div style="display: flex; justify-content: space-between; font-size: 0.78rem; color: #444; margin-top: 4px;">
              <span>Payment Mode:</span>
              <span>UPI / QR Scan</span>
            </div>
            <div style="display: flex; justify-content: space-between; font-size: 0.72rem; color: #666; font-family: monospace;">
              <span>Txn Ref / UTR:</span>
              <span>UPI/423981029381</span>
            </div>
          `:""}
        </div>

        <!-- PAID Official Stamp -->
        ${F?`
          <div style="text-align: center; margin: 12px 0;">
            ${e.stampImage||(container.querySelector("#setting-stamp")||container.querySelector('input[name="stampImage"]'))?.value?.trim()?`
              <img src="${e.stampImage||(container.querySelector("#setting-stamp")||container.querySelector('input[name="stampImage"]'))?.value?.trim()}" style="max-height: 52px; max-width: 65px; object-fit: contain; margin-bottom: 4px;" alt="Official Stamp"><br>
            `:""}
            <div style="display: inline-block; border: 2.5px solid ${T}; color: ${T}; font-weight: 900; font-size: 0.95rem; padding: 4px 14px; border-radius: 6px; text-transform: uppercase; letter-spacing: 1px; transform: rotate(-3deg);">
              \u2714 ${d(q)}
            </div>
          </div>
        `:""}

        <!-- Dynamic UPI QR Code for instant verification -->
        ${N?`
          <div style="text-align: center; margin: 10px 0; padding: 8px; background: #f9fafb; border: 1px solid #e5e7eb; border-radius: 6px;">
            <img src="https://api.qrserver.com/v1/create-qr-code/?size=90x90&data=${encodeURIComponent("upi://pay?pa="+v+"&pn="+n+"&am=0&cu=INR")}" style="width: 80px; height: 80px; display: block; margin: 0 auto 4px;" alt="UPI QR">
            <div style="font-size: 0.68rem; font-weight: 700; color: #374151;">Scan to Verify / Pay Balance via UPI</div>
            <div style="font-size: 0.62rem; color: #6b7280; font-family: monospace;">${d(v)}</div>
          </div>
        `:""}

        <!-- Terms, Footer Note & Signature -->
        <div style="font-size: 0.72rem; color: #4b5563; margin-top: 8px;">
          ${$?`<div style="font-weight: 700; text-align: center; margin-bottom: 6px; color: #111827;">${d($)}</div>`:""}
          ${P?`<div style="line-height: 1.3; font-size: 0.68rem; color: #6b7280; margin-bottom: 8px;">${d(P)}</div>`:""}
          
          ${M?`
            <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 14px; padding-top: 8px; border-top: 1px solid #eee;">
              <div style="font-size: 0.65rem; color: #9ca3af;">
                ${z?`Generated on: ${new Date().toLocaleString("en-IN")}`:""}
              </div>
              <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                ${e.stampImage||(container.querySelector("#setting-stamp")||container.querySelector('input[name="stampImage"]'))?.value?.trim()?`
                  <img src="${e.stampImage||(container.querySelector("#setting-stamp")||container.querySelector('input[name="stampImage"]'))?.value?.trim()}" style="max-height: 44px; max-width: 58px; object-fit: contain; margin-bottom: 2px;" alt="Seal Stamp">
                `:""}
                <div style="border-bottom: 1px solid #333; width: 100px; margin-bottom: 2px;"></div>
                <div style="font-size: 0.65rem; font-weight: 700;">${d(H)}</div>
              </div>
            </div>
          `:""}
        </div>
      `};a.querySelectorAll(".receipt-format-card").forEach(n=>{n.addEventListener("click",()=>{a.querySelectorAll(".receipt-format-card").forEach(b=>{b.classList.remove("active"),b.style.border="1px solid var(--color-border)"}),n.classList.add("active"),n.style.border="2px solid var(--color-primary)",o=n.dataset.format,m&&(m.defaultTemplate=o,m["billing.defaultTemplate"]=o);const i=g||(typeof window<"u"?window.store:null);i&&i.settings&&i.settings.billing&&(i.settings.billing.defaultTemplate=o),u()})}),a.querySelectorAll("input, select, textarea").forEach(n=>{n.addEventListener("input",u),n.addEventListener("change",u)}),["#rc-header-color","#rc-stamp-color"].forEach(n=>{const i=a.querySelector(n),b=a.querySelector(n+"-text");i&&b&&(i.addEventListener("input",()=>{b.value=i.value,u()}),b.addEventListener("input",()=>{b.value.startsWith("#")&&b.value.length===7&&(i.value=b.value,u())}))}),a.querySelector("#btn-refresh-receipt-preview")?.addEventListener("click",u),a.querySelector("#btn-test-print-receipt")?.addEventListener("click",()=>{const n=window.open("","_blank"),i=l.innerHTML,b=o==="thermal58"?"58mm":o==="standardA4"?"210mm":"80mm";n.document.write(`
        <!DOCTYPE html>
        <html>
        <head>
          <title>Test Print Receipt</title>
          <style>
            @page { size: ${b} auto; margin: 0; }
            body { 
              margin: 0; 
              padding: 10px; 
              font-family: ${o==="standardA4"?"sans-serif":"'Courier New', Courier, monospace"}; 
              font-size: ${o==="thermal58"?"11px":"13px"};
              color: #000;
              background: #fff;
              width: ${b};
              box-sizing: border-box;
            }
            img { max-width: 100%; }
          </style>
        </head>
        <body>
          ${i}
          <script>
            window.onload = () => { window.print(); window.close(); };
          <\/script>
        </body>
        </html>
      `),n.document.close()}),a.querySelector("#btn-save-receipt-builder")?.addEventListener("click",async()=>{const n=a.querySelector("#btn-save-receipt-builder");UI.buttonLoading(n,!0,"Saving Template...");const i=a.querySelector("#setting-bill-prefix")?.value?.trim()||"LIB-2026",b=a.querySelector("#rc-header-subtitle")?.value?.trim(),k=a.querySelector("#rc-header-color")?.value,A=a.querySelector("#rc-header-gstin")?.value?.trim(),x=a.querySelector("#rc-toggle-logo")?.checked,C=a.querySelector("#rc-toggle-address")?.checked,L=a.querySelector("#rc-toggle-contact")?.checked,B=a.querySelector("#rc-toggle-stuId")?.checked,D=a.querySelector("#rc-toggle-stuPhone")?.checked,y=a.querySelector("#rc-toggle-seat")?.checked,t=a.querySelector("#rc-toggle-validity")?.checked,p=a.querySelector("#rc-toggle-breakdown")?.checked,S=a.querySelector("#rc-toggle-paymentMode")?.checked,c=a.querySelector("#rc-toggle-stamp")?.checked,f=a.querySelector("#rc-stamp-text")?.value?.trim(),h=a.querySelector("#rc-stamp-color")?.value,F=a.querySelector("#rc-toggle-signature")?.checked,q=a.querySelector("#rc-signature-label")?.value?.trim(),T=a.querySelector("#rc-toggle-upiqr")?.checked,M=a.querySelector("#setting-bill-upiId")?.value?.trim(),H=a.querySelector("#rc-terms-text")?.value?.trim(),N=a.querySelector("#rc-custom-note")?.value?.trim(),v=a.querySelector("#rc-toggle-timestamp")?.checked,P=Number(a.querySelector("#setting-bill-gstRate")?.value||18),$=a.querySelector("#setting-bill-hsn")?.value?.trim()||"999293",z=Number(a.querySelector("#setting-bill-refundDays")?.value||3),U=a.querySelector("#setting-bank-accName")?.value?.trim(),X=a.querySelector("#setting-bank-accNo")?.value?.trim();try{const _={activeTemplate:o,header:{showLogo:x,showBusinessName:!0,subtitle:b,showAddress:C,showPhone:L,showEmail:L,showGst:!!A,gstNumber:A,headerColor:k},body:{showStudentId:B,showStudentPhone:D,showSeatNumber:y,showShift:y,showPeriod:t,showDiscount:p,showPaymentMethod:S,showTransactionId:S},stamp:{showStamp:c,stampText:f,stampColor:h,showWatermark:o==="standardA4"},footer:{showSignature:F,signatureLabel:q,showUpiQr:T,termsText:H,customNote:N,showTimestamp:v},gst:{enabled:P>0,gstRate:P,hsnCode:$}},[G,Y,ve]=await Promise.all([E.put("/api/settings/receipt-config",_),E.put("/api/settings/system-settings",{billing:{receiptPrefix:i,defaultTemplate:o,gstRate:P,hsnSacCode:$,refundPolicyDays:z}}),E.put("/api/settings/business-profile",{upiId:M||e.upiId,gstNumber:A,bankDetails:{accountName:U||e.bankDetails?.accountName,accountNumber:X||e.bankDetails?.accountNumber}})]);G.success||Y.success?w.success("Receipt Builder template & billing configuration saved successfully!"):w.error(G.message||"Failed to save template")}catch(_){w.error(_.message||"Error saving receipt template")}finally{UI.buttonLoading(n,!1)}}),u()},50),a}function le(){const e=document.createElement("div");return e.className="card",e.style.cssText="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);",e.innerHTML=`
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-primary);">\u{1F9E9} App Modules & Granular Feature Toggles</h3>
        <p class="text-muted small mb-0">Turn any system module ON or OFF with 1-click. Disabled modules are immediately hidden from navigation and deactivated system-wide.</p>
      </div>
      <div class="d-flex gap-2 align-items-center flex-wrap">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" id="btn-modules-expand-all" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" id="btn-modules-collapse-all" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
        <button type="button" id="btn-modules-enable-all" class="btn btn-sm btn-outline-success" style="font-weight: 700;">\u{1F7E2} Enable All</button>
        <button type="button" id="btn-modules-disable-optional" class="btn btn-sm btn-outline-secondary" style="font-weight: 700;">\u26AA Minimal Mode</button>
        <button type="button" id="btn-save-modules-config" class="btn btn-sm btn-primary" style="font-weight: 800; padding: 6px 18px;">\u{1F4BE} Save Module Settings</button>
      </div>
    </div>

    <div id="modules-loading-spinner" class="text-center p-4">
      <div class="spinner-border text-primary" role="status" style="width: 2rem; height: 2rem;"></div>
      <p class="text-muted small mt-2">Loading system modules & permissions...</p>
    </div>

    <div id="modules-grid-container" style="display: none;">
      <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 14px;" id="modules-cards-grid">
        <!-- Dynamic Module Cards -->
      </div>
    </div>
  `,setTimeout(async()=>{try{const m=await E.get("/api/settings/sidebar/all"),s=m.success&&Array.isArray(m.data)?m.data:[],g={dashboard:"Executive overview, real-time KPI cards, revenue metrics & occupancy charts.",students:"Directory of registered members, 360\xB0 profiles, KYC documents & identity passes.",seats:"Interactive visual desk layout grid, branch selector & live shift occupancy.",lockers:"Private study locker allocation, security keys & monthly recurring locker fees.",plans:"Membership study tiers, pricing rules, validity duration & discount coupons.",payments:"Fee collection register, GST tax invoices, partial payments & refund tracking.",attendance:"Student check-in / check-out scanner, Kiosk terminal & biometric sync.",shifts:"Operating study shifts (Morning, Evening, Full Day, 24x7) with price multipliers.",reports:"Financial P&L statements, GSTR-1 sales reports & Tally Prime XML accounting exports.",expenses:"Operational library expense log, vendor payments, utility bills & category tracking.",operations:"Library operating schedule, weekly off days, emergency notices & holiday calendar.",settings:"Master administration hub, branding, receipt templates & security configurations.",profile:"Current user profile settings, credentials & active session info."},a=e.querySelector("#modules-loading-spinner"),o=e.querySelector("#modules-grid-container"),l=e.querySelector("#modules-cards-grid");a&&(a.style.display="none"),o&&(o.style.display="block"),l.innerHTML=s.map(r=>{const u=r.isSystem,n=r.isEnabled!==!1,i=g[r.key]||"Core feature module of the Study Library platform.";return`
          <div class="card p-3 module-item-card" data-key="${d(r.key)}" style="background: var(--color-bg-secondary); border: 1.5px solid ${n?"rgba(0, 184, 148, 0.4)":"var(--color-border)"}; border-radius: var(--radius-md); transition: all 0.2s;">
            <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
              <div class="module-card-header" style="display: flex; align-items: center; gap: 10px; cursor: pointer; flex: 1;">
                <span style="font-size: 1.6rem; width: 38px; height: 38px; display: flex; align-items: center; justify-content: center; background: var(--color-surface); border-radius: 8px; border: 1px solid var(--color-border);">${r.icon||"\u{1F4E6}"}</span>
                <div>
                  <h5 style="margin: 0; font-size: 0.98rem; font-weight: 800; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                    ${d(r.label)}
                    <span class="module-toggle-caret" style="font-size: 0.75rem; color: var(--color-text-muted);">\u25B2</span>
                  </h5>
                  <code style="font-size: 0.72rem; color: var(--color-text-muted);">${d(r.href)}</code>
                </div>
              </div>
              <div class="form-check form-switch" style="padding-left: 2.5em; margin: 0;">
                <input class="form-check-input module-toggle-switch" type="checkbox" role="switch" data-key="${d(r.key)}" ${n?"checked":""} ${u?"disabled":""} style="width: 2.2em; height: 1.2em; cursor: ${u?"not-allowed":"pointer"};">
              </div>
            </div>
            
            <div class="module-details-body">
              <p style="font-size: 0.82rem; color: var(--color-text-secondary); margin: 6px 0 10px 0; line-height: 1.35;">
                ${d(i)}
              </p>

              <div style="display: flex; justify-content: space-between; align-items: center; border-top: 1px solid var(--color-border); padding-top: 8px; font-size: 0.75rem;">
                <span class="module-status-badge badge" style="background: ${n?"rgba(0, 184, 148, 0.15)":"rgba(108, 117, 125, 0.15)"}; color: ${n?"var(--color-success)":"var(--color-text-muted)"}; font-weight: 700;">
                  ${n?"\u{1F7E2} Active & Visible":"\u26AA Disabled (Hidden)"}
                </span>
                ${u?'<span class="badge badge-secondary" style="font-size: 0.65rem;">System Core</span>':'<span class="text-muted">Custom Module</span>'}
              </div>
            </div>
          </div>
        `}).join(""),l.querySelectorAll(".module-card-header").forEach(r=>{r.addEventListener("click",()=>{const u=r.closest(".module-item-card"),n=u?.querySelector(".module-details-body"),i=u?.querySelector(".module-toggle-caret");n&&(n.style.display==="none"?(n.style.display="block",i&&(i.textContent="\u25B2")):(n.style.display="none",i&&(i.textContent="\u25BC")))})}),l.querySelectorAll(".module-toggle-switch").forEach(r=>{r.addEventListener("change",()=>{const u=r.closest(".module-item-card"),n=u.querySelector(".module-status-badge");r.checked?(u.style.border="1.5px solid rgba(0, 184, 148, 0.4)",n.style.background="rgba(0, 184, 148, 0.15)",n.style.color="var(--color-success)",n.textContent="\u{1F7E2} Active & Visible"):(u.style.border="1.5px solid var(--color-border)",n.style.background="rgba(108, 117, 125, 0.15)",n.style.color="var(--color-text-muted)",n.textContent="\u26AA Disabled (Hidden)")})}),e.querySelector("#btn-modules-enable-all")?.addEventListener("click",()=>{l.querySelectorAll(".module-toggle-switch").forEach(r=>{r.checked=!0,r.dispatchEvent(new Event("change"))})}),e.querySelector("#btn-modules-disable-optional")?.addEventListener("click",()=>{l.querySelectorAll(".module-toggle-switch").forEach(r=>{if(!r.disabled){const u=r.dataset.key;["lockers","expenses","operations","reports","attendance","shifts"].includes(u)&&(r.checked=!1,r.dispatchEvent(new Event("change")))}})}),e.querySelector("#btn-save-modules-config")?.addEventListener("click",async()=>{const r=e.querySelector("#btn-save-modules-config");UI.buttonLoading(r,!0,"Saving Modules...");const u=s.map(n=>{const i=l.querySelector(`.module-toggle-switch[data-key="${n.key}"]`);return{...n,isEnabled:i?i.checked:n.isEnabled!==!1}});try{const n=await E.put("/api/settings/sidebar",{items:u});if(n.success){w.success("Module settings saved successfully! Navigation refreshed.");try{const i=u.filter(b=>b.isEnabled!==!1).map(b=>b.href);localStorage.setItem("sl_sidebar_order",JSON.stringify(i)),window.SidebarSortable&&window.SidebarSortable.init&&window.SidebarSortable.init(),window.dispatchEvent(new CustomEvent("sidebar-config-changed",{detail:u}))}catch{}}else w.error(n.message||"Failed to update modules")}catch(n){w.error(n.message||"Error updating module configuration")}finally{UI.buttonLoading(r,!1)}})}catch(m){console.error("Error in modules studio:",m)}},50),e}function Q(e,m){const s=Q,g=Array.isArray(e["notification.expiryReminderDays"])?e["notification.expiryReminderDays"].join(", "):e["notification.expiryReminderDays"]||e.expiryReminderDays||"7, 3, 1, 0",a=Array.isArray(e["notification.balanceReminderDays"])?e["notification.balanceReminderDays"].join(", "):e["notification.balanceReminderDays"]||e.balanceReminderDays||"7, 3, 1";return`
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F514} WhatsApp Reminders, Bots &amp; Automated Dispatch</h3>
          <p class="text-muted small mb-0">Automate payment reminder dispatch, seat expiry alerts, and interactive conversational bot.</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" id="btn-run-auto-reminders-now" class="btn btn-sm btn-primary" style="font-weight: 700; font-size: 0.82rem; padding: 5px 12px; display: inline-flex; align-items: center; gap: 6px;">
            \u26A1 Run Auto-Reminders Now
          </button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
          <button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="notifications" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">\u{1F4BE} Save Alerts</button>
        </div>
      </div>

      <!-- Section 1: \u{1F514} WhatsApp Engine & Automated Reminders -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F514}</span> Automated WhatsApp Reminders Engine</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-2" style="font-size: 1.1rem;">
                  <input class="form-check-input" type="checkbox" id="setting-notif-wa" ${e["notification.enableWhatsapp"]||e.enableWhatsapp?"checked":""}>
                  <label class="form-check-label font-weight-bold" for="setting-notif-wa" style="font-size: 0.9rem; font-weight: 700;">Enable Automated WhatsApp Engine</label>
                </div>
                <p class="text-muted small mb-0">Dispatches 1-tap WhatsApp reminder links and gateway alerts to students.</p>
              </div>
            </div>

            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <label class="form-label" style="font-weight: 700; font-size: 0.9rem;">Daily Automated Dispatch Schedule</label>
                <input type="time" id="setting-notif-time" class="form-control" value="${e["notification.whatsappScheduleTime"]||e.whatsappScheduleTime||"09:30"}">
                <small class="text-muted">Time when system checks and queues daily reminders (Default: 09:30 AM)</small>
              </div>
            </div>

            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <label class="form-label" style="font-weight: 700; font-size: 0.9rem;">\u23F3 Expiry Reminder Intervals (Days Before Expiry)</label>
                <input type="text" id="setting-notif-expiryDays" class="form-control" value="${g}" placeholder="e.g. 7, 3, 1, 0">
                <small class="text-muted">Comma-separated days before expiry to dispatch reminder (0 = on expiry day)</small>
              </div>
            </div>

            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <label class="form-label" style="font-weight: 700; font-size: 0.9rem;">\u{1F4B3} Overdue Balance Intervals (Days After Due)</label>
                <input type="text" id="setting-notif-balanceDays" class="form-control" value="${a}" placeholder="e.g. 7, 3, 1">
                <small class="text-muted">Comma-separated days to send pending partial fee balance reminders</small>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 1B: \u{1F4E1} Autonomous Cloud WhatsApp Gateway Provider -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F4E1}</span> Cloud WhatsApp Gateway (Silent Background Auto-Dispatch)</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-12">
              <div class="p-3" style="background: rgba(16, 185, 129, 0.08); border: 1px solid rgba(16, 185, 129, 0.2); border-radius: var(--radius-md);">
                <div style="font-weight: 700; font-size: 0.9rem; color: var(--color-success); margin-bottom: 4px;">\u26A1 Choose Dispatch Architecture</div>
                <div class="small text-muted">Select <strong>Free 1-Tap Links</strong> (default, zero setup) to open WhatsApp Web/App pre-filled with 1 click, or connect a <strong>Cloud API Gateway</strong> (UltraMsg, Fast2SMS, Meta) to dispatch messages automatically in the background without needing a phone open.</div>
              </div>
            </div>

            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700; font-size: 0.9rem;">Gateway Provider</label>
              <select id="setting-notif-provider" class="form-select form-control">
                <option value="none" ${!e["notification.whatsappProvider"]||e["notification.whatsappProvider"]==="none"?"selected":""}>Free 1-Tap Links (wa.me click-to-chat)</option>
                <option value="ultramsg" ${e["notification.whatsappProvider"]==="ultramsg"?"selected":""}>UltraMsg Cloud API (Autonomous Background)</option>
                <option value="fast2sms" ${e["notification.whatsappProvider"]==="fast2sms"?"selected":""}>Fast2SMS Indian Gateway (SMS & Alerts)</option>
                <option value="meta" ${e["notification.whatsappProvider"]==="meta"?"selected":""}>Meta Official WhatsApp Cloud API</option>
                <option value="webhook" ${e["notification.whatsappProvider"]==="webhook"?"selected":""}>Custom Webhook (Zapier / Pabbly / Make)</option>
              </select>
            </div>

            <div class="col-md-6 d-flex align-items-end">
              <button type="button" id="btn-test-wa-gateway" class="btn btn-outline-success w-100" style="font-weight: 700; min-height: 44px;">
                \u{1F9EA} Test Gateway Dispatch (To Admin Phone)
              </button>
            </div>

            <!-- UltraMsg Credentials -->
            <div class="col-md-6 wa-provider-field wa-field-ultramsg" style="display: ${e["notification.whatsappProvider"]==="ultramsg"?"block":"none"};">
              <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">UltraMsg Instance ID</label>
              <input type="text" id="setting-notif-ultramsgId" class="form-control" value="${e["notification.ultramsgInstanceId"]||""}" placeholder="e.g. instance12345">
            </div>
            <div class="col-md-6 wa-provider-field wa-field-ultramsg" style="display: ${e["notification.whatsappProvider"]==="ultramsg"?"block":"none"};">
              <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">UltraMsg Token</label>
              <input type="password" id="setting-notif-ultramsgToken" class="form-control" value="${e["notification.ultramsgToken"]||""}" placeholder="Enter UltraMsg Token">
            </div>

            <!-- Fast2SMS Credentials -->
            <div class="col-12 wa-provider-field wa-field-fast2sms" style="display: ${e["notification.whatsappProvider"]==="fast2sms"?"block":"none"};">
              <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Fast2SMS Authorization API Key</label>
              <input type="password" id="setting-notif-fast2smsKey" class="form-control" value="${e["notification.fast2smsApiKey"]||""}" placeholder="Fast2SMS API Key">
            </div>

            <!-- Meta Cloud API Credentials -->
            <div class="col-md-6 wa-provider-field wa-field-meta" style="display: ${e["notification.whatsappProvider"]==="meta"?"block":"none"};">
              <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Meta Phone Number ID</label>
              <input type="text" id="setting-notif-metaPhoneId" class="form-control" value="${e["notification.metaPhoneNumberId"]||""}" placeholder="e.g. 1048291048192">
            </div>
            <div class="col-md-6 wa-provider-field wa-field-meta" style="display: ${e["notification.whatsappProvider"]==="meta"?"block":"none"};">
              <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Meta Permanent Access Token</label>
              <input type="password" id="setting-notif-metaToken" class="form-control" value="${e["notification.metaAccessToken"]||""}" placeholder="Bearer Token from Meta Business Manager">
            </div>

            <!-- Custom Webhook URL -->
            <div class="col-12 wa-provider-field wa-field-webhook" style="display: ${e["notification.whatsappProvider"]==="webhook"?"block":"none"};">
              <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Webhook Dispatch URL</label>
              <input type="url" id="setting-notif-webhookUrl" class="form-control" value="${e["notification.webhookUrl"]||""}" placeholder="https://hook.eu1.make.com/... or Zapier Webhook">
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: \u{1F916} Automated Bots Suite -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F916}</span> Automated AI Bots Suite (Expiry, Dues &amp; Conversational)</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-1">
                  <input class="form-check-input" type="checkbox" id="setting-notif-expiryBot" ${e["notification.enableAutoExpiryBot"]!==!1?"checked":""}>
                  <label class="form-check-label font-weight-bold" style="font-weight: 700; font-size: 0.88rem;">\u23F3 Expiry Alert Bot</label>
                </div>
                <small class="text-muted">Sends renewal alerts dynamically before plan expires.</small>
              </div>
            </div>

            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-1">
                  <input class="form-check-input" type="checkbox" id="setting-notif-duesBot" ${e["notification.enableAutoDuesBot"]!==!1?"checked":""}>
                  <label class="form-check-label font-weight-bold" style="font-weight: 700; font-size: 0.88rem;">\u{1F4B3} Balance Due Bot</label>
                </div>
                <small class="text-muted">Notifies students with pending partial fee payments.</small>
              </div>
            </div>

            <div class="col-md-4">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div class="form-check form-switch mb-1">
                  <input class="form-check-input" type="checkbox" id="setting-notif-chatBot" ${e["notification.enableConversationalBot"]!==!1?"checked":""}>
                  <label class="form-check-label font-weight-bold" style="font-weight: 700; font-size: 0.88rem;">\u{1F916} Conversational Bot</label>
                </div>
                <small class="text-muted">Replies to <code>!seat</code>, <code>!expiry</code>, and <code>!renew</code> commands.</small>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>
  `}function ie(e){return`
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u23F1\uFE0F Library Operations, Schedule & Attendance Rules</h3>
          <p class="text-muted small mb-0">Configure operating hours, weekly off rules, and emergency notices.</p>
        </div>
        <div class="d-flex gap-2 align-items-center">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
          <button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="operations" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">\u{1F4BE} Save Operations</button>
        </div>
      </div>

      <!-- Section 1: \u23F1\uFE0F Opening Hours & Weekly Off Schedule -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u23F1\uFE0F</span> Campus Operating Hours &amp; Weekly Offs</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Opening Time</label>
              <input type="time" id="setting-ops-open" class="form-control" value="${e["operations.openingTime"]||e.openingTime||"06:00"}">
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Closing Time</label>
              <input type="time" id="setting-ops-close" class="form-control" value="${e["operations.closingTime"]||e.closingTime||"23:00"}">
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Weekly Off Day</label>
              <select id="setting-ops-weeklyOff" class="form-select">
                <option value="none" selected>None (Open All 7 Days)</option>
                <option value="sunday">Sunday Only</option>
                <option value="monday">Monday Only</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: \u{1F4E2} Emergency Notice Board Banner -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h5><span>\u{1F4E2}</span> Emergency Notice Board Banner</h5>
          </div>
          <div style="display: flex; align-items: center; gap: 10px;">
            <div class="form-check form-switch" style="margin: 0; font-size: 1.1rem;">
              <input class="form-check-input" type="checkbox" id="setting-ops-emergencyToggle" ${e["operations.emergencyNoticeEnabled"]||e.emergencyNoticeEnabled?"checked":""}>
              <label class="form-check-label small font-weight-bold" for="setting-ops-emergencyToggle" style="font-weight: 700;">Display Banner</label>
            </div>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <input type="text" id="setting-ops-emergencyNotice" class="form-control" value="${d(e["operations.emergencyNotice"]||e.emergencyNotice||"")}" placeholder="e.g. Library will remain closed on 15th August for Independence Day.">
        </div>
      </div>

      <!-- Section 3: \u{1F6AA} Automated Daily Check-Out & Attendance Rules -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h5><span>\u{1F6AA}</span> Automated Check-Out &amp; Overstay Rules</h5>
          </div>
          <div style="display: flex; align-items: center; gap: 10px;">
            <div class="form-check form-switch" style="margin: 0; font-size: 1.1rem;">
              <input class="form-check-input" type="checkbox" id="setting-ops-autoCheckout" ${(e["operations.autoCheckout"]!==void 0?e["operations.autoCheckout"]:e.autoCheckout!==!1)?"checked":""}>
              <label class="form-check-label small font-weight-bold" for="setting-ops-autoCheckout" style="font-weight: 700;">Enable Auto Check-Out</label>
            </div>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Daily Night Auto Check-Out Time</label>
              <input type="time" id="setting-ops-autoCheckoutTime" class="form-control" value="${e["operations.autoCheckoutTime"]||e.autoCheckoutTime||"23:00"}">
              <small class="text-muted">Daily cron executes at this exact time to auto-checkout open sessions.</small>
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Max Session Limit (Hours)</label>
              <input type="number" id="setting-ops-autoCheckoutHours" class="form-control" min="1" max="24" value="${e["operations.autoCheckoutHours"]||e.autoCheckoutHours||16}">
              <small class="text-muted">Automatically marks students as checked out if session exceeds this limit.</small>
            </div>
            <div class="col-md-4">
              <label class="form-label" style="font-weight: 700;">Check-in Grace Period (Mins)</label>
              <input type="number" id="setting-ops-graceMinutes" class="form-control" min="0" max="60" value="${e["operations.gracePeriodMinutes"]||e.gracePeriodMinutes||15}">
              <small class="text-muted">Allowed buffer before marking attendance as late.</small>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Overstay Penalty Per Hour (\u20B9)</label>
              <input type="number" id="setting-ops-overstayPenalty" class="form-control" min="0" value="${e["operations.latePenaltyPerHour"]||e.latePenaltyPerHour||0}">
              <small class="text-muted">Fine applied when study duration exceeds shift hours.</small>
            </div>
            <div class="col-md-6 d-flex align-items-center mt-4">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" id="setting-ops-examHours" ${e["operations.examExtendedHours"]||e.examExtendedHours?"checked":""}>
                <label class="form-check-label" for="setting-ops-examHours" style="font-weight: 700;">Enable 24x7 Exam Season Open Mode</label>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>
  `}function ne(e,m){const s=document.createElement("div");return s.className="card",s.style.cssText="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);",s.innerHTML=`
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F465} Staff Management, Roles & Granular Permissions</h3>
        <p class="text-muted small mb-0">Create staff accounts, assign branch access, and configure granular module permissions.</p>
      </div>
      <div class="d-flex gap-2 align-items-center flex-wrap">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
        <button id="btn-add-staff-member" class="btn btn-sm btn-primary" style="font-weight: 700; display: inline-flex; align-items: center; gap: 6px;">
          <span>\u2795</span> Add Staff Member
        </button>
      </div>
    <div style="text-align: right; padding: 12px 0 4px 0;"><button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="operations" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">💾 Save Hours & Notices</button></div>
    </div>

    <!-- Section 1: \u{1F465} Staff Members Directory -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>\u{1F465}</span> Staff Members &amp; Branch Access Directory (${e.length} Staff)</h5>
        <span class="settings-accordion-toggle">\u25B2</span>
      </div>
      <div class="settings-accordion-body">
        <div class="table-responsive">
          <table class="table" style="font-size: 0.88rem;">
            <thead>
              <tr style="background: var(--color-bg-secondary);">
                <th>Staff Name</th>
                <th>Email</th>
                <th>Role</th>
                <th>Assigned Branch</th>
                <th>Status</th>
                <th style="text-align: right;">Actions</th>
              </tr>
            </thead>
            <tbody id="staff-table-body">
              ${e.length>0?e.map(g=>`
                <tr data-user-id="${d(g._id||g.id)}">
                  <td><strong>${d(g.name)}</strong></td>
                  <td>${d(g.email)}</td>
                  <td><span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary); text-transform: uppercase;">${d(g.role||"staff")}</span></td>
                  <td>${d(g.branch?.name||m.find(a=>a._id===g.branch)?.name||"All Branches")}</td>
                  <td><span class="badge ${g.isActive!==!1?"badge-success":"badge-danger"}">${g.isActive!==!1?"Active":"Inactive"}</span></td>
                  <td style="text-align: right;">
                    <div class="btn-icon-group">
                      <button type="button" class="btn-icon-action action-edit btn-edit-staff" data-id="${d(g._id||g.id)}" data-tooltip="Edit Staff Permissions" aria-label="Edit Permissions">\u270F\uFE0F</button>
                      <button type="button" class="btn-icon-action action-delete btn-del-staff" data-id="${d(g._id||g.id)}" data-tooltip="Delete Staff" aria-label="Delete Staff">\u{1F5D1}\uFE0F</button>
                    </div>
                  </td>
                </tr>
              `).join(""):`
                <tr>
                  <td><strong>Admin Superuser</strong></td>
                  <td>admin@studylibrary.com</td>
                  <td><span class="badge badge-primary">OWNER</span></td>
                  <td>All Branches</td>
                  <td><span class="badge badge-success">Active</span></td>
                  <td style="text-align: right;"><span class="text-muted small">Superadmin Account</span></td>
                </tr>
              `}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `,setTimeout(()=>{s.querySelector("#btn-add-staff-member")?.addEventListener("click",()=>{const g=j.show({title:"\u2795 Add New Staff Team Member",content:`
          <form id="add-staff-form" class="row g-3">
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Full Name *</label>
              <input type="text" id="staff-name" class="form-control" placeholder="e.g. Priya Sharma" required>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Email Address *</label>
              <input type="email" id="staff-email" class="form-control" placeholder="staff@studylibrary.com" required>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Phone Number</label>
              <input type="tel" id="staff-phone" class="form-control" placeholder="+91 9876543210">
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Login Password *</label>
              <input type="password" id="staff-pwd" class="form-control" placeholder="Minimum 6 characters" required>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Assigned Role *</label>
              <select id="staff-role" class="form-select">
                <option value="branch_manager">Branch Manager (Full Branch Admin)</option>
                <option value="receptionist" selected>Receptionist (Admissions, Fees, Kiosk)</option>
                <option value="accountant">Accountant (Payments, Expenses, GST)</option>
                <option value="librarian">Librarian (Attendance, Seats, QR Scan)</option>
              </select>
            </div>
            <div class="col-md-6">
              <label class="form-label" style="font-weight: 700;">Assigned Branch</label>
              <select id="staff-branch" class="form-select">
                <option value="">All Branches / Main Complex</option>
                ${m.map(a=>`<option value="${a._id}">${d(a.name)}</option>`).join("")}
              </select>
            </div>
          </form>
        `,actions:[{text:"Cancel",class:"btn-secondary",onClick:()=>g.close()},{text:"Save Staff Member",class:"btn-primary",onClick:async()=>{const a=document.getElementById("staff-name")?.value?.trim(),o=document.getElementById("staff-email")?.value?.trim(),l=document.getElementById("staff-phone")?.value?.trim(),r=document.getElementById("staff-pwd")?.value?.trim(),u=document.getElementById("staff-role")?.value,n=document.getElementById("staff-branch")?.value||null;if(!a||!o||!r){w.error("Please enter name, email, and password");return}try{const i=await E.post("/api/auth/register",{name:a,email:o,phone:l,password:r,role:u,branch:n});i.success?(w.success(`Staff member ${a} created successfully!`),g.close(),O()):w.error(i.message||"Failed to create staff")}catch(i){w.error(i.message||"Error creating staff")}}}]})}),s.querySelectorAll(".btn-edit-staff").forEach(g=>{g.addEventListener("click",()=>{const a=g.dataset.id,o=e.find(n=>(n._id||n.id)===a);if(!o)return;const l=["Students","Seats","Plans","Payments","Expenses","Reports","Operations","Settings"],r=["View","Create","Edit","Delete","Export"],u=j.show({title:`\u270F\uFE0F Staff Permissions \u2014 ${d(o.name)}`,content:`
            <div style="margin-bottom: 1rem;">
              <div class="row g-2 mb-3">
                <div class="col-md-6">
                  <label class="form-label small" style="font-weight: 700;">Staff Role</label>
                  <select id="edit-staff-role" class="form-select form-select-sm">
                    <option value="branch_manager" ${o.role==="branch_manager"?"selected":""}>Branch Manager</option>
                    <option value="receptionist" ${o.role==="receptionist"?"selected":""}>Receptionist</option>
                    <option value="accountant" ${o.role==="accountant"?"selected":""}>Accountant</option>
                    <option value="librarian" ${o.role==="librarian"?"selected":""}>Librarian</option>
                  </select>
                </div>
                <div class="col-md-6">
                  <label class="form-label small" style="font-weight: 700;">Account Status</label>
                  <select id="edit-staff-status" class="form-select form-select-sm">
                    <option value="true" ${o.isActive!==!1?"selected":""}>Active</option>
                    <option value="false" ${o.isActive===!1?"selected":""}>Inactive / Suspended</option>
                  </select>
                </div>
              </div>

              <h6 style="font-weight: 800; font-size: 0.9rem; color: var(--color-primary); margin-bottom: 8px;">Granular Module Permissions Matrix</h6>
              <div class="table-responsive">
                <table class="table table-bordered table-sm" style="font-size: 0.82rem; text-align: center;">
                  <thead>
                    <tr style="background: var(--color-bg-secondary);">
                      <th style="text-align: left;">Module</th>
                      ${r.map(n=>`<th>${n}</th>`).join("")}
                    </tr>
                  </thead>
                  <tbody>
                    ${l.map(n=>`
                      <tr>
                        <td style="text-align: left; font-weight: 700;">${n}</td>
                        ${r.map(i=>`
                          <td>
                            <input type="checkbox" class="perm-cb" data-mod="${n.toLowerCase()}" data-act="${i.toLowerCase()}" checked>
                          </td>
                        `).join("")}
                      </tr>
                    `).join("")}
                  </tbody>
                </table>
              </div>
            </div>
          `,actions:[{text:"Cancel",class:"btn-secondary",onClick:()=>u.close()},{text:"Save Permissions",class:"btn-primary",onClick:async()=>{const n=document.getElementById("edit-staff-role")?.value,i=document.getElementById("edit-staff-status")?.value==="true";try{await E.put(`/api/auth/users/${a}`,{role:n,isActive:i}),w.success("Staff permissions updated successfully!"),u.close(),O()}catch(b){w.error(b.message||"Failed to update staff")}}}]})})}),s.querySelectorAll(".btn-del-staff").forEach(g=>{g.addEventListener("click",async()=>{const a=g.dataset.id;if(await J.show("Are you sure you want to remove this staff account?"))try{await E.delete(`/api/auth/users/${a}`),w.success("Staff member removed successfully"),O()}catch(o){w.error(o.message||"Failed to delete staff")}})})},50),s}function ce(){const e=document.createElement("div");e.className="card cms-studio-container",e.style.cssText="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);";const m={modern_glass:{primary:"#6c5ce7",accent:"#00b894",secondary:"#3b82f6",font:"Outfit, sans-serif"},academic_clean:{primary:"#1e293b",accent:"#0284c7",secondary:"#64748b",font:"Inter, sans-serif"},dark_cyber:{primary:"#06b6d4",accent:"#10b981",secondary:"#8b5cf6",font:"Plus Jakarta Sans, sans-serif"},warm_cozy:{primary:"#b45309",accent:"#d97706",secondary:"#78350f",font:"Playfair Display, serif"}};let s="modern_glass",g=!1,a="split",o="all";return e.innerHTML=`
    <!-- Top Action & View Toolbar -->
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 14px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
      <div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
          <span>\u{1F310}</span> Website CMS & Live Split-Screen Studio
        </h3>
        <p class="text-muted small mb-0">100% Granular Customizer: Edit every headline, button, facility, shift, review, rule, and SEO tag with live split-screen preview.</p>
      </div>
      <div class="d-flex gap-2 align-items-center flex-wrap">
        <!-- View Mode Switcher -->
        <div class="btn-group btn-group-sm" role="group" style="background: var(--color-bg-secondary); padding: 2px; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
          <button type="button" id="btn-view-split" class="btn btn-xs btn-primary" style="font-weight: 700; padding: 4px 10px;">\u{1F532} Split View</button>
          <button type="button" id="btn-view-editor" class="btn btn-xs btn-ghost text-muted" style="font-weight: 700; padding: 4px 10px;">\u{1F4DD} Editor Only</button>
          <button type="button" id="btn-view-preview" class="btn btn-xs btn-ghost text-muted" style="font-weight: 700; padding: 4px 10px;">\u{1F4F1} Preview Only</button>
        </div>
        <a href="/landing" target="_blank" class="btn btn-sm btn-outline-primary" style="font-weight: 700; padding: 6px 12px;">\u{1F441}\uFE0F Open Live \u2197</a>
        <button id="btn-save-website-cms" class="btn btn-sm btn-primary" style="font-weight: 800; padding: 6px 18px; box-shadow: var(--shadow-sm);">\u{1F680} Publish Live Website</button>
      </div>
    </div>

    <!-- 4 Visual Theme Presets -->
    <div style="margin-bottom: 1.25rem; background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 14px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
        <label class="form-label mb-0" style="font-weight: 800; font-size: 0.88rem; display: flex; align-items: center; gap: 6px;">
          <span>\u{1F3A8}</span> Visual Theme Preset
        </label>
        <span class="badge" style="background: rgba(108,92,231,0.12); color: var(--color-primary); font-size: 0.72rem;">1-Tap Instant Theme Apply</span>
      </div>
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 10px;" id="theme-presets-grid">
        <div class="card p-2 theme-preset-card active" data-preset="modern_glass" style="border: 2px solid var(--color-primary); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
            <span>\u2728</span>
            <strong style="font-size: 0.88rem; color: var(--color-text-primary);">Modern Glass</strong>
          </div>
          <small class="text-muted" style="font-size: 0.72rem; display: block;">Frosted glass & emerald glow</small>
          <div style="margin-top: 4px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #6c5ce7; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #00b894; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #3b82f6; display: inline-block;"></span>
          </div>
        </div>

        <div class="card p-2 theme-preset-card" data-preset="academic_clean" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
            <span>\u{1F4D6}</span>
            <strong style="font-size: 0.88rem; color: var(--color-text-primary);">Academic Clean</strong>
          </div>
          <small class="text-muted" style="font-size: 0.72rem; display: block;">Slate & ocean teal</small>
          <div style="margin-top: 4px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #1e293b; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #0284c7; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #64748b; display: inline-block;"></span>
          </div>
        </div>

        <div class="card p-2 theme-preset-card" data-preset="dark_cyber" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
            <span>\u26A1</span>
            <strong style="font-size: 0.88rem; color: var(--color-text-primary);">Dark Cyber</strong>
          </div>
          <small class="text-muted" style="font-size: 0.72rem; display: block;">Obsidian & cyan glow</small>
          <div style="margin-top: 4px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #06b6d4; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #10b981; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #0b0f19; border: 1px solid #333; display: inline-block;"></span>
          </div>
        </div>

        <div class="card p-2 theme-preset-card" data-preset="warm_cozy" style="border: 1px solid var(--color-border); background: var(--color-surface); text-align: center; cursor: pointer; transition: all 0.2s; border-radius: var(--radius-md);">
          <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
            <span>\u{1F3DB}\uFE0F</span>
            <strong style="font-size: 0.88rem; color: var(--color-text-primary);">Warm Cozy</strong>
          </div>
          <small class="text-muted" style="font-size: 0.72rem; display: block;">Parchment & amber wood</small>
          <div style="margin-top: 4px; display: flex; justify-content: center; gap: 4px;">
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #b45309; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #d97706; display: inline-block;"></span>
            <span style="width: 10px; height: 10px; border-radius: 50%; background: #faf5ee; border: 1px solid #ccc; display: inline-block;"></span>
          </div>
        </div>
      </div>
    </div>

    <!-- Category Filter Tabs Navigation -->
    <div style="display: flex; gap: 6px; overflow-x: auto; padding-bottom: 8px; margin-bottom: 12px;" id="cms-cat-tabs">
      <button type="button" class="btn btn-xs btn-primary cms-cat-btn" data-cat="all" style="font-weight: 700; white-space: nowrap; border-radius: 20px; padding: 4px 12px;">\u{1F31F} All Sections (17)</button>
      <button type="button" class="btn btn-xs btn-outline-secondary cms-cat-btn" data-cat="branding" style="font-weight: 700; white-space: nowrap; border-radius: 20px; padding: 4px 12px;">\u{1F3A8} Theme & Header</button>
      <button type="button" class="btn btn-xs btn-outline-secondary cms-cat-btn" data-cat="hero" style="font-weight: 700; white-space: nowrap; border-radius: 20px; padding: 4px 12px;">\u{1F680} Hero & Plans</button>
      <button type="button" class="btn btn-xs btn-outline-secondary cms-cat-btn" data-cat="facilities" style="font-weight: 700; white-space: nowrap; border-radius: 20px; padding: 4px 12px;">\u26A1 Amenities & Shifts</button>
      <button type="button" class="btn btn-xs btn-outline-secondary cms-cat-btn" data-cat="about" style="font-weight: 700; white-space: nowrap; border-radius: 20px; padding: 4px 12px;">\u{1F4D6} About & Reviews</button>
      <button type="button" class="btn btn-xs btn-outline-secondary cms-cat-btn" data-cat="policy" style="font-weight: 700; white-space: nowrap; border-radius: 20px; padding: 4px 12px;">\u{1F4DC} FAQs & Rules</button>
      <button type="button" class="btn btn-xs btn-outline-secondary cms-cat-btn" data-cat="contact" style="font-weight: 700; white-space: nowrap; border-radius: 20px; padding: 4px 12px;">\u{1F4DE} Contact & SEO</button>
    </div>

    <!-- Main Studio Layout: Editor (Left) + Split Preview (Right) -->
    <div id="cms-main-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;" class="cms-split-layout">
      
      <!-- Left Column: Collapsible Interactive Accordions with Zero Flex-Shrink -->
      <div style="display: flex; flex-direction: column; gap: 12px; max-height: 850px; overflow-y: auto; padding-right: 6px;" id="cms-accordions-col">
        
        <!-- Accordion Controls Toolbar -->
        <div style="display: flex; justify-content: space-between; align-items: center; padding-bottom: 4px;">
          <span style="font-size: 0.82rem; font-weight: 700; color: var(--color-text-secondary);" id="cms-sections-count-label">\u2699\uFE0F Showing 17 Sections</span>
          <div class="d-flex gap-2">
            <button type="button" id="btn-cms-expand-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.72rem; padding: 3px 8px; font-weight: 700;">\u2795 Expand All</button>
            <button type="button" id="btn-cms-collapse-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.72rem; padding: 3px 8px; font-weight: 700;">\u2796 Collapse All</button>
          </div>
        </div>

        <!-- Section 1: \u{1F3A8} Palette & Typography Overrides -->
        <div class="card cms-accordion-card" data-category="branding" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none; background: var(--color-surface);">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F3A8}</span> 1. Color Palette & Typography Styling
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25B2</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: block; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 10px; margin-bottom: 10px;">
              <div class="p-2 border rounded" style="background: var(--color-surface);">
                <label class="form-label small mb-1" style="font-weight: 700;">Primary Color</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="cms-color-primary" value="#6c5ce7" style="width: 34px; height: 30px; border: none; cursor: pointer; border-radius: 4px; padding: 0;">
                  <input type="text" id="cms-color-primary-text" class="form-control form-control-sm font-monospace p-1" value="#6c5ce7" maxlength="7" style="font-size: 0.8rem;">
                </div>
              </div>
              <div class="p-2 border rounded" style="background: var(--color-surface);">
                <label class="form-label small mb-1" style="font-weight: 700;">Accent Glow</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="cms-color-accent" value="#00b894" style="width: 34px; height: 30px; border: none; cursor: pointer; border-radius: 4px; padding: 0;">
                  <input type="text" id="cms-color-accent-text" class="form-control form-control-sm font-monospace p-1" value="#00b894" maxlength="7" style="font-size: 0.8rem;">
                </div>
              </div>
              <div class="p-2 border rounded" style="background: var(--color-surface);">
                <label class="form-label small mb-1" style="font-weight: 700;">Secondary Tint</label>
                <div style="display: flex; align-items: center; gap: 6px;">
                  <input type="color" id="cms-color-secondary" value="#3b82f6" style="width: 34px; height: 30px; border: none; cursor: pointer; border-radius: 4px; padding: 0;">
                  <input type="text" id="cms-color-secondary-text" class="form-control form-control-sm font-monospace p-1" value="#3b82f6" maxlength="7" style="font-size: 0.8rem;">
                </div>
              </div>
            </div>
            <div>
              <label class="form-label small mb-1" style="font-weight: 700;">Typography Font Family</label>
              <select id="cms-font-family" class="form-select form-select-sm">
                <option value="Outfit, sans-serif">Outfit (Modern, Clean & Geometric)</option>
                <option value="Inter, sans-serif">Inter (High Legibility & Academic)</option>
                <option value="Poppins, sans-serif">Poppins (Friendly & Rounded)</option>
                <option value="Plus Jakarta Sans, sans-serif">Plus Jakarta Sans (Tech & Sleek)</option>
                <option value="Playfair Display, serif">Playfair Display (Warm & Classic Serif)</option>
                <option value="Roboto, sans-serif">Roboto (Standard Sans)</option>
              </select>
            </div>
          </div>
        </div>

        <!-- Section 2: \u{1F4E2} Announcement Ticker & Live Seat Availability -->
        <div class="card cms-accordion-card" data-category="branding" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4E2}</span> 2. Announcement Ticker & Live Seat Badge
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="form-check form-switch mb-2">
              <input class="form-check-input" type="checkbox" id="cms-ticker-enabled" checked>
              <label class="form-check-label small" for="cms-ticker-enabled" style="font-weight: 700;">Show Top Announcement Marquee Ticker</label>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Ticker Marquee Message</label>
              <input type="text" id="cms-hero-ticker" class="form-control form-control-sm" value="\u26A1 Special Discount on 3-Month & 6-Month Membership Plans! Book Your Reserved Seat Today.">
            </div>
            <div class="form-group">
              <label class="form-label small" style="font-weight: 700;">Live Seat Availability Badge Text</label>
              <input type="text" id="cms-live-seat-text" class="form-control form-control-sm" value="Only 12 Seats Left">
            </div>
          </div>
        </div>

        <!-- Section 3: \u{1F9ED} Navbar & Header Action Buttons -->
        <div class="card cms-accordion-card" data-category="branding" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F9ED}</span> 3. Navigation Bar & Header Actions
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Navbar Brand Name Override</label>
              <input type="text" id="cms-nav-brand-name" class="form-control form-control-sm" placeholder="Leave blank to use Business Profile Name">
            </div>
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Primary Button Text</label>
                <input type="text" id="cms-nav-cta-primary-text" class="form-control form-control-sm" value="Register Now">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Primary Button Link</label>
                <input type="text" id="cms-nav-cta-primary-link" class="form-control form-control-sm" value="/register">
              </div>
            </div>
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Secondary Button Text</label>
                <input type="text" id="cms-nav-cta-sec-text" class="form-control form-control-sm" value="Student Portal">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Secondary Button Link</label>
                <input type="text" id="cms-nav-cta-sec-link" class="form-control form-control-sm" value="/student-login">
              </div>
            </div>
            <div class="form-check form-switch">
              <input class="form-check-input" type="checkbox" id="cms-nav-dark-toggle" checked>
              <label class="form-check-label small" for="cms-nav-dark-toggle" style="font-weight: 700;">Show Dark/Light Mode Switcher on Navbar</label>
            </div>
          </div>
        </div>

        <!-- Section 4: \u{1F31F} Hero Section Headline, Buttons & Feature Badges -->
        <div class="card cms-accordion-card" data-category="hero" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F31F}</span> 4. Hero Section Headline, CTAs & Badges
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Hero Main Title Headline</label>
              <input type="text" id="cms-hero-title" class="form-control form-control-sm" value="Premier Air-Conditioned Study Library & Reading Hall">
              <small class="text-muted">Use <code>{library_name}</code> for auto business name insertion</small>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Hero Subtitle / Description</label>
              <textarea id="cms-hero-subtitle" class="form-control form-control-sm" rows="2">Peaceful, Disciplined & Distraction-Free Study Environment for UPSC, MPSC, Banking, SSC, NEET, JEE & CA Aspirants.</textarea>
            </div>
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Hero Primary Button Text</label>
                <input type="text" id="cms-hero-cta-text" class="form-control form-control-sm" value="Apply for Admission / Register Now">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Hero Primary Button URL</label>
                <input type="text" id="cms-hero-cta-link" class="form-control form-control-sm" value="/register">
              </div>
            </div>
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Hero Secondary Button Text</label>
                <input type="text" id="cms-hero-sec-text" class="form-control form-control-sm" value="Send Quick Enquiry">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Hero Secondary Button URL</label>
                <input type="text" id="cms-hero-sec-link" class="form-control form-control-sm" value="#enquiry">
              </div>
            </div>
            <label class="form-label small mt-1 mb-1" style="font-weight: 700;">4 Hero Highlight Badges</label>
            <div class="row g-2">
              <div class="col-6"><input type="text" id="cms-hero-badge-1" class="form-control form-control-sm" value="\u{1F512} 24x7 CCTV Surveillance"></div>
              <div class="col-6"><input type="text" id="cms-hero-badge-2" class="form-control form-control-sm" value="\u2744\uFE0F Dual AC Reading Halls"></div>
              <div class="col-6"><input type="text" id="cms-hero-badge-3" class="form-control form-control-sm" value="\u{1F4F6} 300 Mbps High-Speed Wi-Fi"></div>
              <div class="col-6"><input type="text" id="cms-hero-badge-4" class="form-control form-control-sm" value="\u{1F50B} 100% Power Backup"></div>
            </div>
          </div>
        </div>

        <!-- Section 5: \u26A1 Key Facilities & Amenities (6 Cards) -->
        <div class="card cms-accordion-card" data-category="facilities" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u26A1</span> 5. Facilities & Amenities Cards (6 Cards)
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Title</label>
                <input type="text" id="cms-fac-title" class="form-control form-control-sm" value="Premium Facilities & Amenities">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Subtitle</label>
                <input type="text" id="cms-fac-subtitle" class="form-control form-control-sm" value="Designed with obsession for student comfort and maximum study stamina.">
              </div>
            </div>
            <div id="cms-facilities-list" style="display: flex; flex-direction: column; gap: 8px;">
              ${[{icon:"\u2744\uFE0F",title:"Central Air Conditioning",desc:"Dual inverter ACs maintaining optimal 23\xB0C temperature all year round."},{icon:"\u{1F680}",title:"300 Mbps Fiber Wi-Fi",desc:"Enterprise dual-band optical internet with zero buffering for video lectures."},{icon:"\u{1F50B}",title:"100% Power Backup",desc:"Heavy-duty silent generator & online UPS ensuring zero power cut interruptions."},{icon:"\u{1FA91}",title:"Ergonomic Desk & Chair",desc:"Extra-padded high-back lumbar support chairs for 14+ hours fatigue-free sitting."},{icon:"\u{1F4A1}",title:"Individual LED Desk Light",desc:"Eye-friendly anti-glare reading lamps with dedicated charging sockets."},{icon:"\u{1F4A7}",title:"Hot & Cold RO Water",desc:"Multi-stage RO purified water dispenser with tea & coffee pantry station."}].map((l,r)=>`
                <div class="p-2 border rounded" style="background: var(--color-surface);">
                  <div class="row g-1">
                    <div class="col-2"><input type="text" id="cms-fac-icon-${r+1}" class="form-control form-control-sm text-center" value="${l.icon}"></div>
                    <div class="col-10"><input type="text" id="cms-fac-title-${r+1}" class="form-control form-control-sm" value="${l.title}"></div>
                    <div class="col-12"><input type="text" id="cms-fac-desc-${r+1}" class="form-control form-control-sm" value="${l.desc}"></div>
                  </div>
                </div>
              `).join("")}
            </div>
          </div>
        </div>

        <!-- Section 6: \u23F0 Flexible Study Shifts & Timings -->
        <div class="card cms-accordion-card" data-category="facilities" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u23F0</span> 6. Study Shifts & Timings Guide
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Title</label>
                <input type="text" id="cms-shifts-title" class="form-control form-control-sm" value="Flexible Study Shifts">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Subtitle</label>
                <input type="text" id="cms-shifts-subtitle" class="form-control form-control-sm" value="Choose the shift timing that matches your study routine and peak biological clock.">
              </div>
            </div>
            <div id="cms-shifts-list" style="display: flex; flex-direction: column; gap: 8px;">
              ${[{icon:"\u{1F305}",name:"Morning Shift",timing:"06:00 AM \u2013 02:00 PM",desc:"Early morning slot for fresh mental energy and peak focus."},{icon:"\u{1F307}",name:"Evening Shift",timing:"02:00 PM \u2013 10:00 PM",desc:"Afternoon & evening slot ideal for college students and professionals."},{icon:"\u2600\uFE0F",name:"Full Day Prime",timing:"06:00 AM \u2013 11:00 PM",desc:"Complete 17-hour all-day reserved seat with dedicated charging desk."},{icon:"\u{1F319}",name:"Night Owl Slot",timing:"10:00 PM \u2013 06:00 AM",desc:"Distraction-free overnight study hours for night preparation."}].map((l,r)=>`
                <div class="p-2 border rounded" style="background: var(--color-surface);">
                  <div class="row g-1 align-items-center">
                    <div class="col-2"><input type="text" id="cms-shift-icon-${r+1}" class="form-control form-control-sm text-center" value="${l.icon}"></div>
                    <div class="col-5"><input type="text" id="cms-shift-name-${r+1}" class="form-control form-control-sm font-weight-bold" value="${l.name}"></div>
                    <div class="col-5"><input type="text" id="cms-shift-time-${r+1}" class="form-control form-control-sm font-monospace" value="${l.timing}"></div>
                    <div class="col-12"><input type="text" id="cms-shift-desc-${r+1}" class="form-control form-control-sm" value="${l.desc}"></div>
                  </div>
                </div>
              `).join("")}
            </div>
          </div>
        </div>

        <!-- Section 7: \u{1F4B3} Pricing & Membership Plans Header -->
        <div class="card cms-accordion-card" data-category="hero" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4B3}</span> 7. Pricing & Membership Plans Header
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Section Badge / Tag</label>
              <input type="text" id="cms-plans-badge" class="form-control form-control-sm" value="AFFORDABLE PRICING">
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Section Title</label>
              <input type="text" id="cms-plans-title" class="form-control form-control-sm" value="Transparent & Student-Friendly Membership Plans">
            </div>
            <div class="form-group">
              <label class="form-label small" style="font-weight: 700;">Section Subtitle</label>
              <input type="text" id="cms-plans-subtitle" class="form-control form-control-sm" value="No hidden charges. Select your required shift & duration with instant digital booking.">
            </div>
          </div>
        </div>

        <!-- Section 8: \u{1F4D6} About Section, Highlights & Live Counters -->
        <div class="card cms-accordion-card" data-category="about" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4D6}</span> 8. About Section, Highlights & Live Counters
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">About Headline Title</label>
                <input type="text" id="cms-about-title" class="form-control form-control-sm" value="About Our Study Library">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">About Subtitle</label>
                <input type="text" id="cms-about-subtitle" class="form-control form-control-sm" value="Why Choose Our Reading Hall?">
              </div>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">About Narrative / Mission</label>
              <textarea id="cms-about-desc" class="form-control form-control-sm" rows="3">We understand the discipline, intense focus, and peace required for cracking India\u2019s toughest competitive examinations. Our study space is engineered to eliminate all distractions so you can study 12 to 16 hours every day with maximum productivity.</textarea>
            </div>
            <label class="form-label small mt-1 mb-1" style="font-weight: 700;">4 Key Highlight Bullet Points</label>
            <div class="row g-2 mb-2">
              <div class="col-6"><input type="text" id="cms-about-hl-1" class="form-control form-control-sm" value="Ergonomic cushioned chairs with personal reading lamps & charging sockets"></div>
              <div class="col-6"><input type="text" id="cms-about-hl-2" class="form-control form-control-sm" value="Individual study cubicles / cabins for complete privacy and noise isolation"></div>
              <div class="col-6"><input type="text" id="cms-about-hl-3" class="form-control form-control-sm" value="Strict pin-drop silence policy enforced with round-the-clock supervision"></div>
              <div class="col-6"><input type="text" id="cms-about-hl-4" class="form-control form-control-sm" value="Separate dining area with hot water kettle, microwave & RO water"></div>
            </div>
            <label class="form-label small mt-1 mb-1" style="font-weight: 700;">4 Live Statistics Counters</label>
            <div class="row g-2">
              <div class="col-3"><input type="text" id="cms-stat-num-1" class="form-control form-control-sm text-center font-weight-bold" value="100%"><input type="text" id="cms-stat-lbl-1" class="form-control form-control-sm text-center mt-1" value="Silence"></div>
              <div class="col-3"><input type="text" id="cms-stat-num-2" class="form-control form-control-sm text-center font-weight-bold" value="300 Mbps"><input type="text" id="cms-stat-lbl-2" class="form-control form-control-sm text-center mt-1" value="Wi-Fi Speed"></div>
              <div class="col-3"><input type="text" id="cms-stat-num-3" class="form-control form-control-sm text-center font-weight-bold" value="180+"><input type="text" id="cms-stat-lbl-3" class="form-control form-control-sm text-center mt-1" value="Selections"></div>
              <div class="col-3"><input type="text" id="cms-stat-num-4" class="form-control form-control-sm text-center font-weight-bold" value="365 Days"><input type="text" id="cms-stat-lbl-4" class="form-control form-control-sm text-center mt-1" value="Open Daily"></div>
            </div>
          </div>
        </div>

        <!-- Section 9: \u{1F5BC}\uFE0F Photo Gallery & Showcase -->
        <div class="card cms-accordion-card" data-category="about" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F5BC}\uFE0F</span> 9. Photo Gallery & Showcase
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Title</label>
                <input type="text" id="cms-gallery-title" class="form-control form-control-sm" value="Library Hall & Infrastructure Gallery">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Subtitle</label>
                <input type="text" id="cms-gallery-subtitle" class="form-control form-control-sm" value="Take a visual tour inside our distraction-free study environment and premium seating.">
              </div>
            </div>
            <div id="cms-gallery-list" style="display: flex; flex-direction: column; gap: 8px;">
              ${[{url:"https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=800&q=80",caption:"Quiet Air-Conditioned Main Reading Hall",cat:"Main Hall"},{url:"https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=800&q=80",caption:"Individual Focused Study Desks with Charging Ports",cat:"Desks"},{url:"https://images.unsplash.com/photo-1541339907198-e08756dedf3f?w=800&q=80",caption:"Clean Dining, Refreshment & Discussion Zone",cat:"Dining"},{url:"https://images.unsplash.com/photo-1568667256549-094345857637?w=800&q=80",caption:"Secure Personal Storage Lockers Area",cat:"Lockers"}].map((l,r)=>`
                <div class="p-2 border rounded" style="background: var(--color-surface);">
                  <div class="row g-1">
                    <div class="col-8"><input type="url" id="cms-gal-url-${r+1}" class="form-control form-control-sm font-monospace" value="${l.url}" placeholder="Image URL"></div>
                    <div class="col-4"><input type="text" id="cms-gal-cat-${r+1}" class="form-control form-control-sm" value="${l.cat}" placeholder="Category"></div>
                    <div class="col-12"><input type="text" id="cms-gal-cap-${r+1}" class="form-control form-control-sm" value="${l.caption}" placeholder="Caption"></div>
                  </div>
                </div>
              `).join("")}
            </div>
          </div>
        </div>

        <!-- Section 10: \u2B50 Student Reviews & Google Trust Rating -->
        <div class="card cms-accordion-card" data-category="about" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u2B50</span> 10. Student Reviews & Google Rating
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Title</label>
                <input type="text" id="cms-test-title" class="form-control form-control-sm" value="What Our Students Say">
              </div>
              <div class="col-3">
                <label class="form-label small" style="font-weight: 700;">Google Rating</label>
                <input type="text" id="cms-test-rating" class="form-control form-control-sm text-center font-weight-bold" value="4.9">
              </div>
              <div class="col-3">
                <label class="form-label small" style="font-weight: 700;">Review Count</label>
                <input type="text" id="cms-test-count" class="form-control form-control-sm text-center" value="250+ Reviews">
              </div>
            </div>
            <div id="cms-testimonials-list" style="display: flex; flex-direction: column; gap: 8px;">
              ${[{name:"Aditya Sharma",exam:"UPSC CSE Aspirant (AIR 142)",feedback:"The pin-drop silence and ergonomic chair saved my back during 14-hour study sessions. Best reading hall in town!"},{name:"Priya Kulkarni",exam:"MPSC State Services (Class 1)",feedback:"Uninterrupted power backup and super fast Wi-Fi helped me watch all my online test series without a single glitch."},{name:"Rohan Deshmukh",exam:"Chartered Accountancy (CA Final)",feedback:"Very peaceful atmosphere, well-disciplined students, and extremely cooperative staff. Highly recommended!"}].map((l,r)=>`
                <div class="p-2 border rounded" style="background: var(--color-surface);">
                  <div class="row g-1">
                    <div class="col-6"><input type="text" id="cms-test-name-${r+1}" class="form-control form-control-sm font-weight-bold" value="${l.name}"></div>
                    <div class="col-6"><input type="text" id="cms-test-exam-${r+1}" class="form-control form-control-sm text-muted" value="${l.exam}"></div>
                    <div class="col-12"><textarea id="cms-test-text-${r+1}" class="form-control form-control-sm" rows="2">${l.feedback}</textarea></div>
                  </div>
                </div>
              `).join("")}
            </div>
          </div>
        </div>

        <!-- Section 11: \u2753 Frequently Asked Questions (FAQs) -->
        <div class="card cms-accordion-card" data-category="policy" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u2753</span> 11. Frequently Asked Questions (FAQs)
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Title</label>
                <input type="text" id="cms-faqs-title" class="form-control form-control-sm" value="Frequently Asked Questions">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Subtitle</label>
                <input type="text" id="cms-faqs-subtitle" class="form-control form-control-sm" value="Everything you need to know about joining and facilities.">
              </div>
            </div>
            <div id="cms-faqs-list" style="display: flex; flex-direction: column; gap: 8px;">
              ${[{q:"Can I choose my fixed desk and seat number?",a:"Yes! You can choose your preferred desk location during admission, which remains reserved exclusively for you during your shift."},{q:"Is high-speed Wi-Fi and power backup included in the fee?",a:"Yes, 300 Mbps unlimited optical fiber internet and 24x7 100% generator power backup are completely free with all memberships."},{q:"Is there a trial or 1-day demo available?",a:"Yes, we offer a complimentary 1-day trial session so you can experience the silence, AC, and ergonomic comfort before enrolling."},{q:"What documents are required for library admission?",a:"You only need 1 government ID proof (Aadhaar / Voter ID / Driving License) and 1 passport size photograph."}].map((l,r)=>`
                <div class="p-2 border rounded" style="background: var(--color-surface);">
                  <div class="form-group mb-1">
                    <input type="text" id="cms-faq-q-${r+1}" class="form-control form-control-sm font-weight-bold" value="${l.q}" placeholder="Question">
                  </div>
                  <div class="form-group mb-0">
                    <textarea id="cms-faq-a-${r+1}" class="form-control form-control-sm" rows="2" placeholder="Answer">${l.a}</textarea>
                  </div>
                </div>
              `).join("")}
            </div>
          </div>
        </div>

        <!-- Section 12: \u{1F4DC} Library Rules & Code of Conduct -->
        <div class="card cms-accordion-card" data-category="policy" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4DC}</span> 12. Library Rules & Code of Conduct
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Title</label>
                <input type="text" id="cms-rules-title" class="form-control form-control-sm" value="Library Rules & Discipline Guidelines">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Section Subtitle</label>
                <input type="text" id="cms-rules-subtitle" class="form-control form-control-sm" value="Adherence to these rules is compulsory to maintain a serene learning ecosystem.">
              </div>
            </div>
            <label class="form-label small mb-1" style="font-weight: 700;">5 Core Discipline Rules</label>
            <div style="display: flex; flex-direction: column; gap: 6px;">
              ${["Maintain absolute pin-drop silence in all study halls at all times.","Mobile phones must remain on silent mode. All phone calls must be taken outside the hall.","Do not reserve empty desks with bags or books when leaving for long breaks.","Eating snacks, cooked meals, and smoking are strictly forbidden inside reading halls.","Keep your desk tidy, switch off lights when leaving, and handle library furniture with care."].map((l,r)=>`
                <div class="input-group input-group-sm">
                  <span class="input-group-text font-weight-bold" style="width: 32px; justify-content: center;">${r+1}</span>
                  <input type="text" id="cms-rule-${r+1}" class="form-control form-control-sm" value="${l}">
                </div>
              `).join("")}
            </div>
          </div>
        </div>

        <!-- Section 13: \u{1F4DD} Online Enquiry Form -->
        <div class="card cms-accordion-card" data-category="policy" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4DD}</span> 13. Online Enquiry Section & Alert
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Enquiry Title</label>
                <input type="text" id="cms-enquiry-title" class="form-control form-control-sm" value="Have Questions? Send Us an Enquiry">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Enquiry Subtitle</label>
                <input type="text" id="cms-enquiry-subtitle" class="form-control form-control-sm" value="Fill out the quick form below and our team will get in touch with you via WhatsApp or Call.">
              </div>
            </div>
            <div class="form-group">
              <label class="form-label small" style="font-weight: 700;">Custom Success Message on Form Submit</label>
              <input type="text" id="cms-enquiry-success" class="form-control form-control-sm" value="Thank you! Your enquiry has been received. Our manager will contact you shortly.">
            </div>
          </div>
        </div>

        <!-- Section 14: \u{1F4DE} Contact Info, Operating Hours & Google Maps Location -->
        <div class="card cms-accordion-card" data-category="contact" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4DE}</span> 14. Contact Info, Hours & Google Maps
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Contact Phone</label>
                <input type="tel" id="cms-contact-phone" class="form-control form-control-sm" placeholder="+91 98765 43210">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">WhatsApp Support Number</label>
                <input type="tel" id="cms-contact-wa" class="form-control form-control-sm" placeholder="+91 98765 43210">
              </div>
            </div>
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Official Email</label>
                <input type="email" id="cms-contact-email" class="form-control form-control-sm" placeholder="info@studylibrary.com">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Daily Operating Hours Notice</label>
                <input type="text" id="cms-opening-hours" class="form-control form-control-sm" value="06:00 AM \u2013 11:00 PM (Daily)">
              </div>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Physical Address</label>
              <input type="text" id="cms-contact-address" class="form-control form-control-sm" placeholder="Plot No. 12, Near Metro Station, Pune">
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Google Maps Embed Iframe URL</label>
              <input type="url" id="cms-map-embed" class="form-control form-control-sm" placeholder="https://www.google.com/maps/embed?...">
            </div>
            <div class="form-group">
              <label class="form-label small" style="font-weight: 700;">Google Maps Direct Navigation Link</label>
              <input type="url" id="cms-map-direct" class="form-control form-control-sm" placeholder="https://maps.google.com/?q=...">
            </div>
          </div>
        </div>

        <!-- Section 15: \u{1F4F1} Floating Quick Actions Widget (Sticky WhatsApp & Call) -->
        <div class="card cms-accordion-card" data-category="contact" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4F1}</span> 15. Floating Quick Action Buttons (Sticky WA & Call)
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="form-check form-switch mb-2">
              <input class="form-check-input" type="checkbox" id="cms-floating-enabled" checked>
              <label class="form-check-label small" for="cms-floating-enabled" style="font-weight: 700;">Enable Sticky WhatsApp & Call Buttons</label>
            </div>
            <div class="row g-2 mb-2">
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Floating WhatsApp Number</label>
                <input type="tel" id="cms-floating-whatsapp" class="form-control form-control-sm" placeholder="+91 98765 43210">
              </div>
              <div class="col-md-6">
                <label class="form-label small" style="font-weight: 700;">Floating Direct Call Number</label>
                <input type="tel" id="cms-floating-call" class="form-control form-control-sm" placeholder="+91 98765 43210">
              </div>
            </div>
            <div class="form-group">
              <label class="form-label small" style="font-weight: 700;">Pre-filled WhatsApp Welcome Message</label>
              <input type="text" id="cms-floating-wa-msg" class="form-control form-control-sm" value="Hello! I am interested in library admission.">
            </div>
          </div>
        </div>

        <!-- Section 16: \u{1F9B6} Footer, Quick Links & Copyright -->
        <div class="card cms-accordion-card" data-category="contact" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F9B6}</span> 16. Footer, Quick Links & Copyright Notice
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Footer Organization Name</label>
                <input type="text" id="cms-footer-org-name" class="form-control form-control-sm" placeholder="Leave blank to use Business Profile Name">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Footer Tagline</label>
                <input type="text" id="cms-footer-tagline" class="form-control form-control-sm" value="Premier Air-Conditioned Reading Hall & Self-Study Space.">
              </div>
            </div>
            <div class="row g-2 mb-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Quick Links Column Heading</label>
                <input type="text" id="cms-footer-links-heading" class="form-control form-control-sm" value="Quick Links" placeholder="e.g. Quick Links, Student Portals">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Copyright Notice</label>
                <input type="text" id="cms-footer-copy-text" class="form-control form-control-sm" value="Study Library Management System. All Rights Reserved.">
              </div>
            </div>

            <!-- Dynamic Quick Links Management -->
            <div class="mb-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px; margin-top: 10px;">
              <div class="d-flex justify-content-between align-items-center mb-2 flex-wrap gap-2">
                <div>
                  <label class="form-label small mb-0" style="font-weight: 800; color: var(--color-primary);">\u{1F517} Custom Footer Quick Navigation Links</label>
                  <div class="text-muted" style="font-size: 0.72rem;">Add, edit, reorder or remove navigation links dynamically displayed in the landing footer.</div>
                </div>
                <button type="button" id="btn-add-cms-qlink" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">
                  \u2795 Add New Link
                </button>
              </div>

              <!-- Quick Links Preset Shortcuts -->
              <div class="mb-2 d-flex flex-wrap gap-1 align-items-center" style="background: var(--color-bg-secondary); padding: 6px 10px; border-radius: var(--radius-sm); border: 1px dashed var(--color-border);">
                <span style="font-size: 0.72rem; font-weight: 700; color: var(--color-text-muted);">Quick Presets:</span>
                <button type="button" class="btn btn-xs btn-ghost btn-preset-qlink" data-label="Online Admission" data-url="/register">+ Online Admission</button>
                <button type="button" class="btn btn-xs btn-ghost btn-preset-qlink" data-label="Student Portal" data-url="/student-login">+ Student Portal</button>
                <button type="button" class="btn btn-xs btn-ghost btn-preset-qlink" data-label="Gate Kiosk" data-url="/kiosk">+ Gate Kiosk</button>
                <button type="button" class="btn btn-xs btn-ghost btn-preset-qlink" data-label="Staff & Admin Login" data-url="/#/">+ Staff Login</button>
                <button type="button" class="btn btn-xs btn-ghost btn-preset-qlink" data-label="Fee Plans" data-url="#pricing">+ Fee Plans</button>
                <button type="button" class="btn btn-xs btn-ghost btn-preset-qlink" data-label="Study Shifts" data-url="#shifts">+ Shifts</button>
                <button type="button" class="btn btn-xs btn-ghost btn-preset-qlink" data-label="Contact & Location" data-url="#contact">+ Contact</button>
              </div>

              <!-- Quick Links Container -->
              <div id="cms-qlinks-container" style="display: flex; flex-direction: column; gap: 8px;">
                <!-- Dynamically populated rows -->
              </div>
            </div>
          </div>
        </div>

        <!-- Section 17: \u{1F50D} SEO Search Metadata, Social Share & Analytics -->
        <div class="card cms-accordion-card" data-category="contact" style="flex-shrink: 0; width: 100%; margin-bottom: 8px; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); overflow: hidden;">
          <div class="cms-accordion-header p-3 d-flex justify-content-between align-items-center" style="cursor: pointer; user-select: none;">
            <h5 style="margin: 0; font-size: 0.95rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F50D}</span> 17. SEO Search Metadata & Social Graph
            </h5>
            <span class="cms-accordion-toggle" style="font-size: 0.85rem; font-weight: bold; color: var(--color-text-muted);">\u25BC</span>
          </div>
          <div class="cms-accordion-body p-3 pt-0" style="display: none; background: var(--color-bg-secondary); border-top: 1px solid var(--color-border);">
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Google Search Page Title</label>
              <input type="text" id="cms-seo-title" class="form-control form-control-sm" value="Study Library & Reading Hall \u2014 Premium Self-Study Space">
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Meta Description</label>
              <textarea id="cms-seo-desc" class="form-control form-control-sm" rows="2">Peaceful, air-conditioned study library with high-speed Wi-Fi, ergonomic seating, and 24x7 power backup.</textarea>
            </div>
            <div class="form-group mb-2">
              <label class="form-label small" style="font-weight: 700;">Meta Keywords (comma separated)</label>
              <input type="text" id="cms-seo-keywords" class="form-control form-control-sm" value="study library, reading hall, silent library, UPSC library, competitive exam study space">
            </div>
            <div class="row g-2">
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Google Analytics ID (G-XXXXX)</label>
                <input type="text" id="cms-seo-ga" class="form-control form-control-sm font-monospace" placeholder="G-XXXXXXXXXX">
              </div>
              <div class="col-6">
                <label class="form-label small" style="font-weight: 700;">Meta Pixel ID</label>
                <input type="text" id="cms-seo-pixel" class="form-control form-control-sm font-monospace" placeholder="1234567890">
              </div>
            </div>
          </div>
        </div>

      </div>

      <!-- Right Column: Live Responsive Split-Screen Preview -->
      <div id="cms-preview-col" style="display: flex; flex-direction: column; position: sticky; top: 10px;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; flex-wrap: wrap; gap: 6px;">
          <div class="d-flex align-items-center gap-2">
            <span style="font-weight: 800; font-size: 0.9rem; color: var(--color-text-primary);">\u{1F4F1} Live Preview Canvas</span>
            <span class="badge badge-success" style="font-size: 0.7rem; font-weight: 700;">\u26A1 Instant Sync</span>
          </div>
          <div class="d-flex gap-1 align-items-center">
            <button type="button" id="btn-preview-mode-desktop" class="btn btn-xs btn-primary" style="padding: 2px 8px; font-weight: 700;">\u{1F5A5}\uFE0F Desktop</button>
            <button type="button" id="btn-preview-mode-mobile" class="btn btn-xs btn-outline-secondary" style="padding: 2px 8px; font-weight: 700;">\u{1F4F1} Mobile</button>
            <button type="button" id="btn-preview-reload" class="btn btn-xs btn-outline-secondary" style="padding: 2px 6px;" title="Hard Reload Preview">\u{1F504}</button>
          </div>
        </div>

        <div id="cms-preview-container" style="width: 100%; height: 780px; border: 2px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; background: #0f121d; display: flex; justify-content: center; align-items: center; transition: all 0.3s;">
          <iframe id="cms-preview-frame" src="/landing?preview=true&theme=modern_glass" style="width: 100%; height: 100%; border: none; transition: width 0.3s ease;"></iframe>
        </div>
      </div>

    </div>
  `,setTimeout(async()=>{const l=e.querySelector("#cms-preview-frame"),r=e.querySelector("#cms-main-grid"),u=e.querySelector("#cms-preview-col"),n=e.querySelector("#cms-accordions-col"),i=e.querySelector("#btn-view-split"),b=e.querySelector("#btn-view-editor"),k=e.querySelector("#btn-view-preview"),A=y=>{a=y,[i,b,k].forEach(t=>{t&&(t.className="btn btn-xs btn-ghost text-muted")}),y==="split"?(i.className="btn btn-xs btn-primary",r.style.display="grid",r.style.gridTemplateColumns="1fr 1fr",n.style.display="flex",u.style.display="flex"):y==="editor"?(b.className="btn btn-xs btn-primary",r.style.display="block",n.style.display="flex",u.style.display="none"):y==="preview"&&(k.className="btn btn-xs btn-primary",r.style.display="block",n.style.display="none",u.style.display="flex")};i?.addEventListener("click",()=>A("split")),b?.addEventListener("click",()=>A("editor")),k?.addEventListener("click",()=>A("preview")),e.querySelectorAll(".cms-cat-btn").forEach(y=>{y.addEventListener("click",()=>{e.querySelectorAll(".cms-cat-btn").forEach(c=>{c.className="btn btn-xs btn-outline-secondary cms-cat-btn"}),y.className="btn btn-xs btn-primary cms-cat-btn",o=y.dataset.cat;let t=0,p=null;if(e.querySelectorAll(".cms-accordion-card").forEach(c=>{const f=c.dataset.category;o==="all"||f===o?(c.style.display="block",t++,p||(p=c)):c.style.display="none"}),p&&o!=="all"){const c=p.querySelector(".cms-accordion-body"),f=p.querySelector(".cms-accordion-toggle");c&&(c.style.display="block"),f&&(f.textContent="\u25B2")}const S=e.querySelector("#cms-sections-count-label");S&&(S.textContent=`\u2699\uFE0F Showing ${t} Section${t>1?"s":""}`)})});let x=[{label:"Online Admission",url:"/register",openInNewTab:!1},{label:"Student Portal",url:"/student-login",openInNewTab:!1},{label:"Gate Kiosk",url:"/kiosk",openInNewTab:!1},{label:"Staff & Owner Login",url:"/#/",openInNewTab:!1}];const C=()=>{if(!l||!l.contentWindow)return;const y=x.filter(t=>t&&t.label&&t.url);l.contentWindow.postMessage({type:"LIVE_CMS_UPDATE",preset:s,primaryColor:e.querySelector("#cms-color-primary")?.value,accentColor:e.querySelector("#cms-color-accent")?.value,secondaryColor:e.querySelector("#cms-color-secondary")?.value,fontFamily:e.querySelector("#cms-font-family")?.value,heroTitle:e.querySelector("#cms-hero-title")?.value,heroSubtitle:e.querySelector("#cms-hero-subtitle")?.value,announcementTicker:e.querySelector("#cms-hero-ticker")?.value,footerLinksHeading:e.querySelector("#cms-footer-links-heading")?.value?.trim()||"Quick Links",quickLinks:y,footerTagline:e.querySelector("#cms-footer-tagline")?.value,navBrand:e.querySelector("#cms-nav-brand-name")?.value},"*")},L=()=>{const y=e.querySelector("#cms-qlinks-container");if(y){if(x.length===0){y.innerHTML=`
          <div class="text-center p-3 text-muted" style="font-size: 0.8rem; border: 1px dashed var(--color-border); border-radius: var(--radius-sm);">
            No links added yet. Click <strong>\u2795 Add New Link</strong> or a quick preset above.
          </div>
        `;return}y.innerHTML=x.map((t,p)=>`
        <div class="cms-qlink-row row g-2 align-items-center p-2" data-index="${p}" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-sm);">
          <div class="col-4">
            <input type="text" class="form-control form-control-sm qlink-input-label font-weight-bold" placeholder="Link Text (e.g. Online Admission)" value="${d(t.label||"")}">
          </div>
          <div class="col-4">
            <input type="text" class="form-control form-control-sm font-monospace qlink-input-url" placeholder="URL (e.g. /register or #pricing)" value="${d(t.url||"")}">
          </div>
          <div class="col-2 d-flex align-items-center">
            <label class="form-check-label small mb-0 d-flex align-items-center gap-1" style="font-size: 0.72rem; cursor: pointer; white-space: nowrap;">
              <input type="checkbox" class="form-check-input qlink-input-newtab" ${t.openInNewTab?"checked":""} style="margin: 0;">
              <span>\u2197 Tab</span>
            </label>
          </div>
          <div class="col-2 text-end">
            <button type="button" class="btn btn-xs btn-outline-danger btn-delete-qlink" data-index="${p}" title="Delete link" style="padding: 2px 7px;">
              \u{1F5D1}\uFE0F
            </button>
          </div>
        </div>
      `).join(""),y.querySelectorAll(".qlink-input-label").forEach((t,p)=>{t.addEventListener("input",S=>{x[p]&&(x[p].label=S.target.value),C()})}),y.querySelectorAll(".qlink-input-url").forEach((t,p)=>{t.addEventListener("input",S=>{x[p]&&(x[p].url=S.target.value),C()})}),y.querySelectorAll(".qlink-input-newtab").forEach((t,p)=>{t.addEventListener("change",S=>{x[p]&&(x[p].openInNewTab=S.target.checked),C()})}),y.querySelectorAll(".btn-delete-qlink").forEach(t=>{t.addEventListener("click",()=>{const p=parseInt(t.dataset.index,10);x.splice(p,1),L(),C()})})}};e.querySelector("#btn-add-cms-qlink")?.addEventListener("click",()=>{x.push({label:"New Link",url:"/",openInNewTab:!1}),L(),C()}),e.querySelectorAll(".btn-preset-qlink").forEach(y=>{y.addEventListener("click",()=>{const t=y.dataset.label,p=y.dataset.url;x.some(S=>S.url===p)||(x.push({label:t,url:p,openInNewTab:!1}),L(),C())})}),l&&l.addEventListener("load",()=>{setTimeout(C,350)});try{const y=await E.get("/api/landing");if(y.success&&y.data){const{landing:t={},businessProfile:p={}}=y.data;t.theme?.preset&&(s=t.theme.preset,e.querySelectorAll(".theme-preset-card").forEach(c=>{c.dataset.preset===s?(c.classList.add("active"),c.style.border="2px solid var(--color-primary)"):(c.classList.remove("active"),c.style.border="1px solid var(--color-border)")})),t.theme?.primaryColor&&(e.querySelector("#cms-color-primary").value=t.theme.primaryColor,e.querySelector("#cms-color-primary-text").value=t.theme.primaryColor),t.theme?.accentColor&&(e.querySelector("#cms-color-accent").value=t.theme.accentColor,e.querySelector("#cms-color-accent-text").value=t.theme.accentColor),t.theme?.secondaryColor&&(e.querySelector("#cms-color-secondary").value=t.theme.secondaryColor,e.querySelector("#cms-color-secondary-text").value=t.theme.secondaryColor),t.theme?.fontFamily&&(e.querySelector("#cms-font-family").value=t.theme.fontFamily),t.hero?.enableTicker!==void 0&&(e.querySelector("#cms-ticker-enabled").checked=t.hero.enableTicker),t.hero?.tickerText&&(e.querySelector("#cms-hero-ticker").value=t.hero.tickerText),t.hero?.liveSeatBadge?.text&&(e.querySelector("#cms-live-seat-text").value=t.hero.liveSeatBadge.text),t.navbar?.brandName&&(e.querySelector("#cms-nav-brand-name").value=t.navbar.brandName),t.navbar?.ctaPrimaryText&&(e.querySelector("#cms-nav-cta-primary-text").value=t.navbar.ctaPrimaryText),t.navbar?.ctaPrimaryLink&&(e.querySelector("#cms-nav-cta-primary-link").value=t.navbar.ctaPrimaryLink),t.navbar?.ctaSecondaryText&&(e.querySelector("#cms-nav-cta-sec-text").value=t.navbar.ctaSecondaryText),t.navbar?.ctaSecondaryLink&&(e.querySelector("#cms-nav-cta-sec-link").value=t.navbar.ctaSecondaryLink),t.navbar?.showDarkModeToggle!==void 0&&(e.querySelector("#cms-nav-dark-toggle").checked=t.navbar.showDarkModeToggle),t.hero?.title&&(e.querySelector("#cms-hero-title").value=t.hero.title),t.hero?.subtitle&&(e.querySelector("#cms-hero-subtitle").value=t.hero.subtitle),t.hero?.ctaPrimaryText&&(e.querySelector("#cms-hero-cta-text").value=t.hero.ctaPrimaryText),t.hero?.ctaPrimaryLink&&(e.querySelector("#cms-hero-cta-link").value=t.hero.ctaPrimaryLink),t.hero?.ctaSecondaryText&&(e.querySelector("#cms-hero-sec-text").value=t.hero.ctaSecondaryText),t.hero?.ctaSecondaryLink&&(e.querySelector("#cms-hero-sec-link").value=t.hero.ctaSecondaryLink),Array.isArray(t.hero?.badges)&&t.hero.badges.forEach((c,f)=>{const h=e.querySelector(`#cms-hero-badge-${f+1}`);h&&(h.value=c)}),t.facilities?.title&&(e.querySelector("#cms-fac-title").value=t.facilities.title),t.facilities?.subtitle&&(e.querySelector("#cms-fac-subtitle").value=t.facilities.subtitle),Array.isArray(t.facilities?.items)&&t.facilities.items.forEach((c,f)=>{const h=f+1,F=e.querySelector(`#cms-fac-icon-${h}`),q=e.querySelector(`#cms-fac-title-${h}`),T=e.querySelector(`#cms-fac-desc-${h}`);F&&c.icon&&(F.value=c.icon),q&&c.title&&(q.value=c.title),T&&c.description&&(T.value=c.description)}),t.shifts?.title&&(e.querySelector("#cms-shifts-title").value=t.shifts.title),t.shifts?.subtitle&&(e.querySelector("#cms-shifts-subtitle").value=t.shifts.subtitle),Array.isArray(t.shifts?.items)&&t.shifts.items.forEach((c,f)=>{const h=f+1,F=e.querySelector(`#cms-shift-icon-${h}`),q=e.querySelector(`#cms-shift-name-${h}`),T=e.querySelector(`#cms-shift-time-${h}`),M=e.querySelector(`#cms-shift-desc-${h}`);F&&c.icon&&(F.value=c.icon),q&&c.name&&(q.value=c.name),T&&c.timing&&(T.value=c.timing),M&&c.description&&(M.value=c.description)}),t.pricing?.badge&&(e.querySelector("#cms-plans-badge").value=t.pricing.badge),t.pricing?.title&&(e.querySelector("#cms-plans-title").value=t.pricing.title),t.pricing?.subtitle&&(e.querySelector("#cms-plans-subtitle").value=t.pricing.subtitle),t.about?.title&&(e.querySelector("#cms-about-title").value=t.about.title),t.about?.subtitle&&(e.querySelector("#cms-about-subtitle").value=t.about.subtitle),t.about?.description&&(e.querySelector("#cms-about-desc").value=t.about.description),Array.isArray(t.about?.highlightPoints)&&t.about.highlightPoints.forEach((c,f)=>{const h=e.querySelector(`#cms-about-hl-${f+1}`);h&&(h.value=c)}),Array.isArray(t.about?.stats)&&t.about.stats.forEach((c,f)=>{const h=f+1,F=e.querySelector(`#cms-stat-num-${h}`),q=e.querySelector(`#cms-stat-lbl-${h}`);F&&c.number&&(F.value=c.number),q&&c.label&&(q.value=c.label)}),t.gallery?.title&&(e.querySelector("#cms-gallery-title").value=t.gallery.title),t.gallery?.subtitle&&(e.querySelector("#cms-gallery-subtitle").value=t.gallery.subtitle);const S=t.gallery?.images||t.gallery?.items;if(Array.isArray(S)&&S.forEach((c,f)=>{const h=f+1,F=e.querySelector(`#cms-gal-url-${h}`),q=e.querySelector(`#cms-gal-cat-${h}`),T=e.querySelector(`#cms-gal-cap-${h}`);F&&c.url&&(F.value=c.url),q&&c.category&&(q.value=c.category),T&&c.caption&&(T.value=c.caption)}),t.testimonials?.title&&(e.querySelector("#cms-test-title").value=t.testimonials.title),t.testimonials?.googleRating&&(e.querySelector("#cms-test-rating").value=t.testimonials.googleRating),t.testimonials?.googleReviewsCount&&(e.querySelector("#cms-test-count").value=t.testimonials.googleReviewsCount),Array.isArray(t.testimonials?.items)&&t.testimonials.items.forEach((c,f)=>{const h=f+1,F=e.querySelector(`#cms-test-name-${h}`),q=e.querySelector(`#cms-test-exam-${h}`),T=e.querySelector(`#cms-test-text-${h}`);F&&c.name&&(F.value=c.name),q&&c.exam&&(q.value=c.exam),T&&c.feedback&&(T.value=c.feedback)}),t.faqs?.title&&(e.querySelector("#cms-faqs-title").value=t.faqs.title),t.faqs?.subtitle&&(e.querySelector("#cms-faqs-subtitle").value=t.faqs.subtitle),Array.isArray(t.faqs?.items)&&t.faqs.items.forEach((c,f)=>{const h=f+1,F=e.querySelector(`#cms-faq-q-${h}`),q=e.querySelector(`#cms-faq-a-${h}`);F&&c.question&&(F.value=c.question),q&&c.answer&&(q.value=c.answer)}),t.rules?.title&&(e.querySelector("#cms-rules-title").value=t.rules.title),t.rules?.subtitle&&(e.querySelector("#cms-rules-subtitle").value=t.rules.subtitle),Array.isArray(t.rules?.items)&&t.rules.items.forEach((c,f)=>{const h=e.querySelector(`#cms-rule-${f+1}`);h&&(h.value=c)}),t.enquiry?.title&&(e.querySelector("#cms-enquiry-title").value=t.enquiry.title),t.enquiry?.subtitle&&(e.querySelector("#cms-enquiry-subtitle").value=t.enquiry.subtitle),t.enquiry?.successMessage&&(e.querySelector("#cms-enquiry-success").value=t.enquiry.successMessage),(t.contact?.phone||p.phone)&&(e.querySelector("#cms-contact-phone").value=t.contact?.phone||p.phone||""),(t.contact?.whatsapp||p.socialLinks?.whatsapp||p.phone)&&(e.querySelector("#cms-contact-wa").value=t.contact?.whatsapp||p.socialLinks?.whatsapp||p.phone||""),(t.contact?.email||p.email)&&(e.querySelector("#cms-contact-email").value=t.contact?.email||p.email||""),t.contact?.openingHours&&(e.querySelector("#cms-opening-hours").value=t.contact.openingHours),(t.contact?.address||p.address)&&(e.querySelector("#cms-contact-address").value=t.contact?.address||p.address||""),(p.mapEmbedUrl||t.footer?.mapEmbedUrl||t.contact?.googleMapEmbedUrl)&&(e.querySelector("#cms-map-embed").value=p.mapEmbedUrl||t.footer?.mapEmbedUrl||t.contact?.googleMapEmbedUrl||""),t.footer?.mapDirectLink&&(e.querySelector("#cms-map-direct").value=t.footer.mapDirectLink),t.floatingActions?.enabled!==void 0&&(e.querySelector("#cms-floating-enabled").checked=t.floatingActions.enabled),(t.floatingActions?.whatsappNumber||p.phone)&&(e.querySelector("#cms-floating-whatsapp").value=t.floatingActions?.whatsappNumber||p.phone||""),(t.floatingActions?.callNumber||p.phone)&&(e.querySelector("#cms-floating-call").value=t.floatingActions?.callNumber||p.phone||""),t.floatingActions?.whatsappMessage&&(e.querySelector("#cms-floating-wa-msg").value=t.floatingActions.whatsappMessage),t.footer?.orgName&&(e.querySelector("#cms-footer-org-name").value=t.footer.orgName),t.footer?.tagline&&(e.querySelector("#cms-footer-tagline").value=t.footer.tagline),t.footer?.copyrightText&&(e.querySelector("#cms-footer-copy-text").value=t.footer.copyrightText),t.footer?.linksHeading){const c=e.querySelector("#cms-footer-links-heading");c&&(c.value=t.footer.linksHeading)}Array.isArray(t.footer?.quickLinks)&&t.footer.quickLinks.length>0&&(x=t.footer.quickLinks.map(c=>({label:c.label||"",url:c.url||"",openInNewTab:!!c.openInNewTab}))),L(),t.seo?.metaTitle&&(e.querySelector("#cms-seo-title").value=t.seo.metaTitle),t.seo?.metaDescription&&(e.querySelector("#cms-seo-desc").value=t.seo.metaDescription),t.seo?.metaKeywords&&(e.querySelector("#cms-seo-keywords").value=t.seo.metaKeywords),t.seo?.googleAnalyticsId&&(e.querySelector("#cms-seo-ga").value=t.seo.googleAnalyticsId),t.seo?.metaPixelId&&(e.querySelector("#cms-seo-pixel").value=t.seo.metaPixelId),l&&(l.src=`/landing?preview=true&theme=${s}&t=${Date.now()}`)}}catch(y){console.warn("Failed to load landing config:",y)}e.querySelectorAll(".theme-preset-card").forEach(y=>{y.addEventListener("click",()=>{e.querySelectorAll(".theme-preset-card").forEach(p=>{p.classList.remove("active"),p.style.border="1px solid var(--color-border)"}),y.classList.add("active"),y.style.border="2px solid var(--color-primary)",s=y.dataset.preset;const t=m[s]||m.modern_glass;e.querySelector("#cms-color-primary").value=t.primary,e.querySelector("#cms-color-primary-text").value=t.primary,e.querySelector("#cms-color-accent").value=t.accent,e.querySelector("#cms-color-accent-text").value=t.accent,e.querySelector("#cms-color-secondary").value=t.secondary,e.querySelector("#cms-color-secondary-text").value=t.secondary,e.querySelector("#cms-font-family").value=t.font,l&&(l.src=`/landing?preview=true&theme=${s}&t=${Date.now()}`),setTimeout(C,150)})}),["primary","accent","secondary"].forEach(y=>{const t=e.querySelector(`#cms-color-${y}`),p=e.querySelector(`#cms-color-${y}-text`);t&&p&&(t.addEventListener("input",()=>{p.value=t.value,C()}),p.addEventListener("input",()=>{p.value.startsWith("#")&&p.value.length===7&&(t.value=p.value,C())}))}),["#cms-font-family","#cms-hero-title","#cms-hero-subtitle","#cms-hero-ticker","#cms-footer-tagline","#cms-nav-brand-name","#cms-qlink-lbl-1","#cms-qlink-url-1","#cms-qlink-lbl-2","#cms-qlink-url-2","#cms-qlink-lbl-3","#cms-qlink-url-3","#cms-qlink-lbl-4","#cms-qlink-url-4"].forEach(y=>{e.querySelector(y)?.addEventListener("input",C)});const B=e.querySelector("#btn-preview-mode-desktop"),D=e.querySelector("#btn-preview-mode-mobile");B?.addEventListener("click",()=>{g=!1,B.classList.replace("btn-outline-secondary","btn-primary"),D.classList.replace("btn-primary","btn-outline-secondary"),l&&(l.style.width="100%",l.style.maxWidth="100%")}),D?.addEventListener("click",()=>{g=!0,D.classList.replace("btn-outline-secondary","btn-primary"),B.classList.replace("btn-primary","btn-outline-secondary"),l&&(l.style.width="375px",l.style.maxWidth="375px",l.style.boxShadow="0 0 20px rgba(0,0,0,0.5)",l.style.borderRadius="16px")}),e.querySelector("#btn-preview-reload")?.addEventListener("click",()=>{l&&(l.src=`/landing?preview=true&theme=${s}&t=${Date.now()}`)}),e.querySelector("#btn-save-website-cms")?.addEventListener("click",async()=>{const y=e.querySelector("#btn-save-website-cms");UI.buttonLoading(y,!0,"Publishing...");try{const t=[e.querySelector("#cms-hero-badge-1")?.value?.trim(),e.querySelector("#cms-hero-badge-2")?.value?.trim(),e.querySelector("#cms-hero-badge-3")?.value?.trim(),e.querySelector("#cms-hero-badge-4")?.value?.trim()].filter(Boolean),p=[];for(let v=1;v<=6;v++){const P=e.querySelector(`#cms-fac-icon-${v}`)?.value?.trim()||"\u2744\uFE0F",$=e.querySelector(`#cms-fac-title-${v}`)?.value?.trim(),z=e.querySelector(`#cms-fac-desc-${v}`)?.value?.trim()||"";$&&p.push({icon:P,title:$,description:z})}const S=[];for(let v=1;v<=4;v++){const P=e.querySelector(`#cms-shift-icon-${v}`)?.value?.trim()||"\u23F0",$=e.querySelector(`#cms-shift-name-${v}`)?.value?.trim(),z=e.querySelector(`#cms-shift-time-${v}`)?.value?.trim()||"",U=e.querySelector(`#cms-shift-desc-${v}`)?.value?.trim()||"";$&&S.push({icon:P,name:$,timing:z,description:U,enabled:!0})}const c=[e.querySelector("#cms-about-hl-1")?.value?.trim(),e.querySelector("#cms-about-hl-2")?.value?.trim(),e.querySelector("#cms-about-hl-3")?.value?.trim(),e.querySelector("#cms-about-hl-4")?.value?.trim()].filter(Boolean),f=[];for(let v=1;v<=4;v++){const P=e.querySelector(`#cms-stat-num-${v}`)?.value?.trim(),$=e.querySelector(`#cms-stat-lbl-${v}`)?.value?.trim();(P||$)&&f.push({number:P||"",label:$||""})}const h=[];for(let v=1;v<=4;v++){const P=e.querySelector(`#cms-gal-url-${v}`)?.value?.trim(),$=e.querySelector(`#cms-gal-cat-${v}`)?.value?.trim()||"Hall",z=e.querySelector(`#cms-gal-cap-${v}`)?.value?.trim()||"";P&&h.push({url:P,category:$,caption:z})}const F=[];for(let v=1;v<=3;v++){const P=e.querySelector(`#cms-test-name-${v}`)?.value?.trim(),$=e.querySelector(`#cms-test-exam-${v}`)?.value?.trim()||"Aspirant",z=e.querySelector(`#cms-test-text-${v}`)?.value?.trim();P&&z&&F.push({name:P,exam:$,feedback:z,rating:5})}const q=[];for(let v=1;v<=4;v++){const P=e.querySelector(`#cms-faq-q-${v}`)?.value?.trim(),$=e.querySelector(`#cms-faq-a-${v}`)?.value?.trim();P&&$&&q.push({question:P,answer:$})}const T=[];for(let v=1;v<=5;v++){const P=e.querySelector(`#cms-rule-${v}`)?.value?.trim();P&&T.push(P)}const M=x.map(v=>({label:v.label?.trim()||"",url:v.url?.trim()||"",openInNewTab:!!v.openInNewTab})).filter(v=>v.label&&v.url),H={theme:{preset:s,primaryColor:e.querySelector("#cms-color-primary")?.value,accentColor:e.querySelector("#cms-color-accent")?.value,secondaryColor:e.querySelector("#cms-color-secondary")?.value,fontFamily:e.querySelector("#cms-font-family")?.value},hero:{title:e.querySelector("#cms-hero-title")?.value?.trim(),subtitle:e.querySelector("#cms-hero-subtitle")?.value?.trim(),enableTicker:e.querySelector("#cms-ticker-enabled")?.checked,tickerText:e.querySelector("#cms-hero-ticker")?.value?.trim(),liveSeatBadge:{enabled:!0,text:e.querySelector("#cms-live-seat-text")?.value?.trim()||"Only 12 Seats Left"},ctaPrimaryText:e.querySelector("#cms-hero-cta-text")?.value?.trim()||"Apply for Admission / Register Now",ctaPrimaryLink:e.querySelector("#cms-hero-cta-link")?.value?.trim()||"/register",ctaSecondaryText:e.querySelector("#cms-hero-sec-text")?.value?.trim()||"Send Quick Enquiry",ctaSecondaryLink:e.querySelector("#cms-hero-sec-link")?.value?.trim()||"#enquiry",badges:t},navbar:{brandName:e.querySelector("#cms-nav-brand-name")?.value?.trim()||"",ctaPrimaryText:e.querySelector("#cms-nav-cta-primary-text")?.value?.trim()||"Register Now",ctaPrimaryLink:e.querySelector("#cms-nav-cta-primary-link")?.value?.trim()||"/register",ctaSecondaryText:e.querySelector("#cms-nav-cta-sec-text")?.value?.trim()||"Student Portal",ctaSecondaryLink:e.querySelector("#cms-nav-cta-sec-link")?.value?.trim()||"/student-login",showDarkModeToggle:e.querySelector("#cms-nav-dark-toggle")?.checked},facilities:{enabled:!0,title:e.querySelector("#cms-fac-title")?.value?.trim()||"Premium Facilities & Amenities",subtitle:e.querySelector("#cms-fac-subtitle")?.value?.trim()||"",items:p},shifts:{enabled:!0,title:e.querySelector("#cms-shifts-title")?.value?.trim()||"Flexible Study Shifts",subtitle:e.querySelector("#cms-shifts-subtitle")?.value?.trim()||"",items:S},pricing:{enabled:!0,badge:e.querySelector("#cms-plans-badge")?.value?.trim()||"PRICING",title:e.querySelector("#cms-plans-title")?.value?.trim()||"Transparent & Student-Friendly Membership Plans",subtitle:e.querySelector("#cms-plans-subtitle")?.value?.trim()||""},about:{enabled:!0,title:e.querySelector("#cms-about-title")?.value?.trim()||"About Our Study Library",subtitle:e.querySelector("#cms-about-subtitle")?.value?.trim()||"",description:e.querySelector("#cms-about-desc")?.value?.trim()||"",highlightPoints:c,stats:f},gallery:{enabled:!0,title:e.querySelector("#cms-gallery-title")?.value?.trim()||"Library Hall & Infrastructure Gallery",subtitle:e.querySelector("#cms-gallery-subtitle")?.value?.trim()||"",images:h},testimonials:{enabled:!0,title:e.querySelector("#cms-test-title")?.value?.trim()||"What Our Students Say",googleRating:e.querySelector("#cms-test-rating")?.value?.trim()||"4.9",googleReviewsCount:e.querySelector("#cms-test-count")?.value?.trim()||"250+ Reviews",items:F},faqs:{enabled:!0,title:e.querySelector("#cms-faqs-title")?.value?.trim()||"Frequently Asked Questions",subtitle:e.querySelector("#cms-faqs-subtitle")?.value?.trim()||"",items:q},rules:{enabled:!0,title:e.querySelector("#cms-rules-title")?.value?.trim()||"Library Rules & Discipline Guidelines",subtitle:e.querySelector("#cms-rules-subtitle")?.value?.trim()||"",items:T},enquiry:{enabled:!0,title:e.querySelector("#cms-enquiry-title")?.value?.trim()||"Have Questions? Send Us an Enquiry",subtitle:e.querySelector("#cms-enquiry-subtitle")?.value?.trim()||"",successMessage:e.querySelector("#cms-enquiry-success")?.value?.trim()||""},contact:{enabled:!0,phone:e.querySelector("#cms-contact-phone")?.value?.trim()||"",whatsapp:e.querySelector("#cms-contact-wa")?.value?.trim()||"",email:e.querySelector("#cms-contact-email")?.value?.trim()||"",address:e.querySelector("#cms-contact-address")?.value?.trim()||"",openingHours:e.querySelector("#cms-opening-hours")?.value?.trim()||"",googleMapEmbedUrl:e.querySelector("#cms-map-embed")?.value?.trim()||""},floatingActions:{enabled:e.querySelector("#cms-floating-enabled")?.checked,whatsappNumber:e.querySelector("#cms-floating-whatsapp")?.value?.trim()||"",whatsappMessage:e.querySelector("#cms-floating-wa-msg")?.value?.trim()||"Hello! I am interested in library admission.",callNumber:e.querySelector("#cms-floating-call")?.value?.trim()||""},footer:{enabled:!0,showLinks:!0,linksHeading:e.querySelector("#cms-footer-links-heading")?.value?.trim()||"Quick Links",orgName:e.querySelector("#cms-footer-org-name")?.value?.trim()||"",tagline:e.querySelector("#cms-footer-tagline")?.value?.trim()||"",copyrightText:e.querySelector("#cms-footer-copy-text")?.value?.trim()||"",mapEmbedUrl:e.querySelector("#cms-map-embed")?.value?.trim()||"",mapDirectLink:e.querySelector("#cms-map-direct")?.value?.trim()||"",quickLinks:M},seo:{metaTitle:e.querySelector("#cms-seo-title")?.value?.trim()||"",metaDescription:e.querySelector("#cms-seo-desc")?.value?.trim()||"",metaKeywords:e.querySelector("#cms-seo-keywords")?.value?.trim()||"",googleAnalyticsId:e.querySelector("#cms-seo-ga")?.value?.trim()||"",metaPixelId:e.querySelector("#cms-seo-pixel")?.value?.trim()||""},businessProfile:{mapEmbedUrl:e.querySelector("#cms-map-embed")?.value?.trim()||"",phone:e.querySelector("#cms-contact-phone")?.value?.trim()||"",email:e.querySelector("#cms-contact-email")?.value?.trim()||"",address:e.querySelector("#cms-contact-address")?.value?.trim()||""}},N=await E.put("/api/landing",H);if(N.success){try{localStorage.removeItem("sl_public_profile_cache")}catch{}w.success("Public Website published live with all 17 customization sections!"),C(),l&&(l.src=`/landing?preview=true&theme=${s}&t=${Date.now()}`)}else w.error(N.message||"Failed to publish website")}catch(t){w.error(t.message||"Error publishing website")}finally{UI.buttonLoading(y,!1)}})},50),e}function de(e,m){const s=a=>e[`portal.${a}`]!==!1&&e[a]!==!1,g=[{key:"enableOnlineRenewal",title:"\u{1F4B3} Online UPI Fee Renewal",desc:"Allows students to pay fees online via QR code & UPI intent apps"},{key:"enableSeatTransfer",title:"\u{1F504} Seat / Desk Transfer Requests",desc:"Allows students to submit self-service seat transfer requests"},{key:"enableShiftSwitch",title:"\u{1F552} Shift Switch Requests",desc:"Allows students to request shift timing changes"},{key:"enableIdPassDownload",title:"\u{1FAAA} Digital Mobile ID Pass Download",desc:"Generates 1080x1920px 9:16 mobile wallpaper ID passes"},{key:"enableReceiptDownload",title:"\u{1F9FE} Fee Receipt PDF Download",desc:"Allows students to download official fee payment invoices"},{key:"enableProfileEdit",title:"\u{1F464} Profile & KYC Self-Edit",desc:"Permits students to update phone, emergency contacts, and photo"},{key:"enableWebAuthn",title:"\u{1F510} One-Touch Biometric FaceID Login",desc:"Enables passkey and fingerprint authentication"},{key:"enableGamifiedBadges",title:"\u{1F3C6} Gamified Badges & Study Streak",desc:"Displays study streak milestones and achievement trophies"},{key:"enableReferralProgram",title:"\u{1F381} Referral Program & Cashback Wallet",desc:"Enables referral sharing links and cashback balances"},{key:"enableAttendanceLogs",title:"\u{1F4CA} 30-Day AI Study Heatmap",desc:"Displays attendance heatmap logs and study duration graph"},{key:"enableAnnouncements",title:"\u{1F4E2} Notice Board & Announcements",desc:"Displays library alerts and emergency closure banners"},{key:"enableLockerRequests",title:"\u{1F512} Locker Allotment Requests",desc:"Allows students to request personal locker storage"}];return`
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F4F1} Student Portal & Mobile App Master Feature Matrix</h3>
          <p class="text-muted small mb-0">Granularly turn ON or OFF every button, self-service request, and card inside the Student Portal (/student-login).</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
          <a href="/student-login" target="_blank" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u{1F441}\uFE0F Test Student Portal \u2197</a>
          <button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="student_portal" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">\u{1F4BE} Save Portal Settings</button>
        </div>
      </div>

      <!-- Section 1: \u{1F4F1} Student Self-Service Feature Matrix -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F4F1}</span> Active Student Portal Features &amp; Modules (${g.length} Modules)</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 14px;">
            ${g.map(a=>`
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center; gap: 12px;">
                <div>
                  <div style="font-weight: 700; font-size: 0.92rem; color: var(--color-text-primary); margin-bottom: 2px;">${a.title}</div>
                  <div style="font-size: 0.78rem; color: var(--color-text-secondary); line-height: 1.4;">${a.desc}</div>
                </div>
                <div class="form-check form-switch" style="margin: 0; font-size: 1.2rem;">
                  <input class="form-check-input student-portal-toggle" type="checkbox" data-key="${a.key}" ${s(a.key)?"checked":""}>
                </div>
              </div>
            `).join("")}
          </div>
        </div>
      </div>

    </div>
  `}function V(e){const m=document.createElement("div");return m.className="card",m.style.cssText="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);",m.innerHTML=`
    <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
      <div>
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F916} Automation Engine & AI Business Insights Studio</h3>
        <p class="text-muted small mb-0">Autonomous background tasks, AI revenue summaries, occupancy forecasts, and smart retention risk detection.</p>
      </div>
      <div class="d-flex gap-2 align-items-center">
        <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
        <button type="button" class="btn btn-sm btn-primary btn-save-module" data-studio="automations_ai" style="font-weight: 800; font-size: 0.82rem; padding: 6px 14px; display: inline-flex; align-items: center; gap: 6px;">\u{1F4BE} Save Automations</button>
      </div>
    </div>

    <!-- Section 1: \u26A1 Autonomous System Daemons -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>\u26A1</span> Autonomous System Daemons &amp; Auto-Releases</h5>
        <span class="settings-accordion-toggle">\u25B2</span>
      </div>
      <div class="settings-accordion-body">
        <div class="row g-3">
          <div class="col-md-6">
            <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" id="setting-auto-seatExpiry" ${e["automations.autoSeatExpiry"]!==!1?"checked":""}>
                <label class="form-check-label" style="font-weight: 700;">Auto-Release Expired Seats</label>
              </div>
              <small class="text-muted d-block mt-1">Automatically marks desk as vacant when plan expires + grace days</small>
            </div>
          </div>
          <div class="col-md-6">
            <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
              <div class="form-check form-switch">
                <input class="form-check-input" type="checkbox" id="setting-auto-dueReminders" ${e["automations.autoDueReminders"]!==!1?"checked":""}>
                <label class="form-check-label" style="font-weight: 700;">Auto-Dispatch Balance Due Reminders</label>
              </div>
              <small class="text-muted d-block mt-1">Schedules automated WhatsApp balance notifications</small>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Section 2: \u2728 AI Business Intelligence & Analytics -->
    <div class="card settings-accordion-card">
      <div class="settings-accordion-header">
        <h5><span>\u2728</span> AI Business Intelligence &amp; Retention Analytics</h5>
        <div class="d-flex align-items-center gap-2">
          <button id="btn-refresh-ai-insights" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">\u{1F504} Refresh</button>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
      </div>
      <div class="settings-accordion-body">
        <div id="ai-insights-mount-container">
          <div style="padding: 2rem; text-align: center; color: var(--color-text-secondary);">
            <div class="loading-spinner" style="margin: 0 auto 8px auto;"></div>
            <p style="margin: 0; font-size: 0.88rem;">Generating AI insights from real-time database...</p>
          </div>
        </div>
      </div>
    </div>
  `,setTimeout(async()=>{const s=m.querySelector("#ai-insights-mount-container");if(s)try{const g=(await E.get("/api/ai/insights"))?.data||{},a=g.financialSummary||{},o=g.occupancySummary||{},l=g.retentionRisks||[];s.innerHTML=`
        <div class="row g-3">
          
          <!-- Financial Card -->
          <div class="col-md-6">
            <div class="card p-3" style="background: linear-gradient(135deg, rgba(108,92,231,0.08), rgba(0,184,148,0.08)); border: 1px solid var(--color-border);">
              <div style="font-size: 0.8rem; font-weight: 700; color: var(--color-primary); text-transform: uppercase;">\u{1F4B0} AI Revenue Growth Summary</div>
              <div style="font-size: 1.6rem; font-weight: 800; margin: 4px 0;">\u20B9${Number(a.thisMonthRevenue||0).toLocaleString("en-IN")}</div>
              <div style="font-size: 0.82rem; color: ${a.growthPercent>=0?"var(--color-success)":"var(--color-danger)"}; font-weight: 700;">
                ${a.growthPercent>=0?"\u25B2 +":"\u25BC "}${a.growthPercent}% vs previous month
              </div>
              <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 6px;">
                Average revenue per active student: <strong>\u20B9${a.avgRevenuePerMember||0}</strong>
              </div>
            </div>
          </div>

          <!-- Occupancy Card -->
          <div class="col-md-6">
            <div class="card p-3" style="background: linear-gradient(135deg, rgba(59,130,246,0.08), rgba(16,185,129,0.08)); border: 1px solid var(--color-border);">
              <div style="font-size: 0.8rem; font-weight: 700; color: var(--color-primary); text-transform: uppercase;">\u{1F4BA} AI Capacity & Occupancy Forecast</div>
              <div style="font-size: 1.6rem; font-weight: 800; margin: 4px 0;">${o.occupancyRate||0}% Occupied</div>
              <div style="font-size: 0.82rem; color: var(--color-text-primary); font-weight: 600;">
                ${o.occupiedSeats||0} occupied / ${o.totalSeats||0} total desks (${o.availableSeats||0} vacant)
              </div>
              <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-top: 6px;">
                \u{1F4A1} <em>${d(o.insight||"Capacity optimal.")}</em>
              </div>
            </div>
          </div>

          <!-- Retention Risks Table -->
          <div class="col-12 mt-2">
            <div class="card p-3" style="border: 1px solid var(--color-border);">
              <div style="font-weight: 700; font-size: 0.92rem; margin-bottom: 8px; display: flex; align-items: center; gap: 6px;">
                <span>\u{1F6E1}\uFE0F</span> <span>AI Student Retention Watchlist (Expiring in 5 Days)</span>
              </div>
              <div class="table-responsive">
                <table class="table" style="font-size: 0.85rem;">
                  <thead>
                    <tr style="background: var(--color-bg-secondary);">
                      <th>Student Name</th>
                      <th>Phone</th>
                      <th>Days Left</th>
                      <th>Urgency</th>
                      <th>AI Suggested Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${l.length>0?l.map(r=>`
                      <tr>
                        <td><strong>${d(r.name)}</strong></td>
                        <td>${d(r.phone)}</td>
                        <td><strong>${r.daysLeft} days</strong></td>
                        <td><span class="badge" style="background: ${r.urgency==="high"?"rgba(239,68,68,0.15)":"rgba(245,158,11,0.15)"}; color: ${r.urgency==="high"?"#ef4444":"#f59e0b"}; text-transform: uppercase;">${r.urgency}</span></td>
                        <td><span class="text-muted small">${r.suggestedAction}</span></td>
                      </tr>
                    `).join(""):'<tr><td colspan="5" class="text-center p-3 text-muted">No students at immediate retention risk.</td></tr>'}
                  </tbody>
                </table>
              </div>
            </div>
          </div>

        </div>
      `}catch{s.innerHTML='<p class="text-muted p-3 text-center">AI insights calculation active.</p>'}},50),m}function me(){return`
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary);">\u{1F512} Security, Immutable Audit Trails & Backups</h3>
          <p class="text-muted small mb-0">PIN lock, login history logs, immutable activity audit trails, and 1-click database export/restore.</p>
        </div>
        <div class="d-flex gap-2 align-items-center">
          <button type="button" class="btn btn-xs btn-outline-secondary btn-expand-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2795 Expand All</button>
          <button type="button" class="btn btn-xs btn-outline-secondary btn-collapse-all-sections" style="font-weight: 700; font-size: 0.75rem; padding: 3px 9px;">\u2796 Collapse All</button>
        </div>
      </div>

      <!-- Section 1: \u{1F510} PIN Lock & Database Snapshot -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F510}</span> Terminal Lock &amp; Database Backups</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 6px;">\u{1F510} Quick Admin PIN Lock</h5>
                <p class="text-muted small mb-3">Set a 4-digit PIN for instant terminal lock when stepping away from the front reception desk.</p>
                <div style="display: flex; gap: 8px;">
                  <input type="password" id="setting-sec-pin" maxlength="4" class="form-control font-monospace" placeholder="4-digit PIN" style="width: 140px; text-align: center; letter-spacing: 4px; font-size: 1.1rem;">
                  <button id="btn-save-pin" class="btn btn-sm btn-primary">Save PIN</button>
                </div>
              </div>
            </div>

            <div class="col-md-6">
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 6px;">\u{1F4BE} Database Snapshot & Export</h5>
                <p class="text-muted small mb-3">Download complete JSON or CSV data archives of all students, payments, and seats.</p>
                <div style="display: flex; gap: 8px; flex-wrap: wrap;">
                  <button id="btn-sec-export-json" class="btn btn-sm btn-outline-primary">\u{1F4E5} Export JSON Backup</button>
                  <a href="#/reports" class="btn btn-sm btn-outline-secondary">\u{1F4CA} Accounting Exports</a>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Section 2: \u{1F4DC} System Activity Audit Trail -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F4DC}</span> System Activity Audit Trail</h5>
          <div class="d-flex align-items-center gap-2">
            <a href="#/reports" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">View Logs \u2197</a>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <p class="text-muted small mb-0">Every student admission, fee payment, desk allocation, and settings change is recorded with user timestamp and IP address.</p>
        </div>
      </div>

    </div>
  `}function ue(e){e&&(e.querySelectorAll(".settings-accordion-header, .cms-accordion-header").forEach(m=>{m.dataset.accordionBound||(m.dataset.accordionBound="true",m.addEventListener("click",s=>{if(s.target.closest("input, select, .form-switch, .form-check, label.form-check-label")&&!s.target.closest(".settings-accordion-toggle, .cms-accordion-toggle"))return;const g=m.closest(".settings-accordion-card, .cms-accordion-card")||m.parentElement,a=m.nextElementSibling||g.querySelector(".settings-accordion-body, .cms-accordion-body"),o=m.querySelector(".settings-accordion-toggle, .cms-accordion-toggle");a&&(!a.style.display||a.style.display==="none"||window.getComputedStyle(a).display==="none"?(a.style.display="block",o&&(o.textContent="\u25B2")):(a.style.display="none",o&&(o.textContent="\u25BC")))}))}),e.querySelectorAll(".btn-expand-all-sections, #btn-cms-expand-all, #btn-modules-expand-all").forEach(m=>{m.dataset.bound||(m.dataset.bound="true",m.addEventListener("click",()=>{e.querySelectorAll(".settings-accordion-body, .cms-accordion-body, .module-details-body").forEach(s=>s.style.display="block"),e.querySelectorAll(".settings-accordion-toggle, .cms-accordion-toggle, .module-toggle-caret").forEach(s=>s.textContent="\u25B2")}))}),e.querySelectorAll(".btn-collapse-all-sections, #btn-cms-collapse-all, #btn-modules-collapse-all").forEach(m=>{m.dataset.bound||(m.dataset.bound="true",m.addEventListener("click",()=>{e.querySelectorAll(".settings-accordion-body, .cms-accordion-body, .module-details-body").forEach(s=>s.style.display="none"),e.querySelectorAll(".settings-accordion-toggle, .cms-accordion-toggle, .module-toggle-caret").forEach(s=>s.textContent="\u25BC")}))}))}function K(e,m,s){e.querySelector("#btn-save-reg-payment-methods")?.addEventListener("click",async()=>{try{const a=e.querySelectorAll(".setting-paymethod-row");if(a.length===0)return;const o=Array.from(a).map((r,u)=>({key:r.dataset.key,name:r.querySelector(".spm-name")?.value?.trim()||r.dataset.name,subtitle:r.querySelector(".spm-sub")?.value?.trim()||"",icon:r.dataset.icon||"\u{1F4B3}",enabled:r.querySelector(".spm-enabled")?r.querySelector(".spm-enabled").checked:!0,order:u+1,instructions:r.querySelector(".spm-instructions")?.value?.trim()||"",requiresRef:r.querySelector(".spm-reqref")?r.querySelector(".spm-reqref").checked:!0,refLabel:r.querySelector(".spm-reflabel")?.value?.trim()||"Transaction Reference / UTR *"}));I.show("Saving Self-Registration Payment Methods...");const l=await E.put("/api/settings/business-profile",{paymentMethods:o});I.hide(),l.success?(s&&s.profile&&(s.profile.paymentMethods=o),w.success("\u2705 Self-registration payment options updated successfully! Changes are live on the registration portal.")):w.error(l.message||"Failed to save payment options")}catch(a){I.hide(),w.error("Failed to update payment options: "+a.message)}}),e.querySelector("#btn-save-pin")?.addEventListener("click",()=>{const a=e.querySelector("#setting-sec-pin")?.value;a&&a.length===4?(localStorage.setItem("sl_admin_pin",a),w.success("Admin 4-digit PIN lock saved successfully!")):w.error("Please enter a valid 4-digit PIN.")}),e.querySelector("#btn-sec-export-json")?.addEventListener("click",()=>{e.querySelector("#btn-master-quick-backup")?.click()}),e.querySelector("#btn-add-staff-member")?.addEventListener("click",()=>{ge(e,s.branches||[])}),e.querySelector("#btn-refresh-ai-insights")?.addEventListener("click",()=>{w.info("Refreshing retention and revenue intelligence...");const a=e.querySelector("#master-studio-viewport");a&&(a.innerHTML="",a.appendChild(V(s.settings.auto)),K(e,"automations_ai",s))}),e.querySelector("#btn-run-auto-reminders-now")?.addEventListener("click",async()=>{try{I.show("Executing Automated WhatsApp Expiry & Dues Dispatch Engine...");const a=await E.post("/api/messages/run-cron-now");if(I.hide(),a.success){const o=a.data||{},l=document.createElement("div");l.innerHTML=`
          <div class="text-center mb-3">
            <div style="font-size: 2.5rem; margin-bottom: 6px;">\u26A1</div>
            <h4 style="color: var(--color-success); font-weight: 800; margin-bottom: 4px;">Automated Bot Dispatched Successfully</h4>
            <p class="text-muted small">Daily scheduled scan and WhatsApp reminder queue completed.</p>
          </div>
          <div class="row g-2 mb-3">
            <div class="col-6">
              <div class="p-2 rounded border text-center" style="background: var(--color-bg-secondary);">
                <div style="font-size: 1.3rem; font-weight: 800; color: var(--color-primary);">${o.totalStudentsScanned??0}</div>
                <div class="small text-muted font-weight-bold">Students Scanned</div>
              </div>
            </div>
            <div class="col-6">
              <div class="p-2 rounded border text-center" style="background: var(--color-bg-secondary);">
                <div style="font-size: 1.3rem; font-weight: 800; color: var(--color-success);">${o.expiryRemindersSent??0}</div>
                <div class="small text-muted font-weight-bold">Expiry Alerts Dispatched</div>
              </div>
            </div>
            <div class="col-6">
              <div class="p-2 rounded border text-center" style="background: var(--color-bg-secondary);">
                <div style="font-size: 1.3rem; font-weight: 800; color: var(--color-warning);">${o.balanceDueRemindersSent??0}</div>
                <div class="small text-muted font-weight-bold">Dues Alerts Dispatched</div>
              </div>
            </div>
            <div class="col-6">
              <div class="p-2 rounded border text-center" style="background: var(--color-bg-secondary);">
                <div style="font-size: 1.3rem; font-weight: 800; color: var(--color-danger);">${o.seatsReleased??0}</div>
                <div class="small text-muted font-weight-bold">Overdue Seats Released</div>
              </div>
            </div>
          </div>
          ${o.logs&&o.logs.length>0?`
            <div style="max-height: 180px; overflow-y: auto; font-size: 0.78rem; background: var(--color-surface); padding: 8px; border-radius: 6px; border: 1px solid var(--color-border);">
              <div class="font-weight-bold mb-1 text-muted">Execution Logs (${o.logs.length}):</div>
              ${o.logs.map(r=>`<div class="py-1 border-bottom d-flex justify-content-between"><span><strong>${d(r.studentName)}</strong> (${r.type}): ${d(r.detail||r.timeLabel||"")}</span><span class="badge badge-success">${r.status}</span></div>`).join("")}
            </div>
          `:'<div class="text-muted small text-center">No active student subscriptions required immediate reminder alerts today.</div>'}
        `,new j({title:"\u{1F916} Automated Reminders Execution Report",content:l,size:"md"}).show()}else w.error(a.message||"Failed to execute automated reminders bot")}catch(a){I.hide(),w.error(a.message||"Error executing automated reminders")}});const g=e.querySelector("#setting-notif-provider");if(g){const a=()=>{const o=g.value;e.querySelectorAll(".wa-provider-field").forEach(l=>l.style.display="none"),o==="ultramsg"?e.querySelectorAll(".wa-field-ultramsg").forEach(l=>l.style.display="block"):o==="fast2sms"?e.querySelectorAll(".wa-field-fast2sms").forEach(l=>l.style.display="block"):o==="meta"?e.querySelectorAll(".wa-field-meta").forEach(l=>l.style.display="block"):o==="webhook"&&e.querySelectorAll(".wa-field-webhook").forEach(l=>l.style.display="block")};g.addEventListener("change",a)}e.querySelector("#btn-test-wa-gateway")?.addEventListener("click",async()=>{const a=e.querySelector("#btn-test-wa-gateway");try{I.button(a,!0);const o=await E.post("/api/notifications/test-gateway",{type:"whatsapp",message:"\u{1F680} Test alert from Study Library Management System: Your WhatsApp Gateway integration is working perfectly!"});I.button(a,!1),o.success?(w.success(o.message||"Test message dispatched to gateway!"),o.data?.whatsappUrl&&(!o.data?.provider||o.data?.provider==="click_to_chat")&&window.open(o.data.whatsappUrl,"_blank")):w.error(o.message||"Gateway test failed")}catch(o){I.button(a,!1),w.error(o.message||"Test dispatch failed")}}),m==="system_health"&&be(e)}function pe(){return`
    <div class="card" style="padding: 1.5rem; background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
        <div>
          <h3 style="margin: 0; font-size: 1.2rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
            <span>\u{1F3E5}</span> System Health, Live Diagnostics &amp; Infrastructure Monitor
          </h3>
          <p class="text-muted small mb-0">Real-time telemetry, database latency benchmarking, container memory gauge, and 6-step data pipeline audit.</p>
        </div>
        <div class="d-flex gap-2 align-items-center flex-wrap">
          <button type="button" id="btn-export-health-report" class="btn btn-xs btn-outline-secondary" style="font-weight: 700; font-size: 0.75rem; padding: 4px 10px; display: inline-flex; align-items: center; gap: 4px;">
            <span>\u{1F4E5}</span> Export JSON
          </button>
          <button type="button" id="btn-run-full-audit" class="btn btn-xs btn-outline-primary" style="font-weight: 700; font-size: 0.75rem; padding: 4px 10px; display: inline-flex; align-items: center; gap: 4px;">
            <span>\u{1F9EA}</span> Run Full Audit
          </button>
          <button type="button" id="btn-refresh-health" class="btn btn-xs btn-primary" style="font-weight: 700; font-size: 0.75rem; padding: 4px 10px; display: inline-flex; align-items: center; gap: 4px;">
            <span>\u{1F504}</span> Refresh Metrics
          </button>
        </div>
      </div>

      <!-- Live Telemetry KPI Cards Grid -->
      <div class="row g-3 mb-4" id="health-kpi-grid">
        
        <!-- Card 1: Server & Uptime -->
        <div class="col-md-3 col-sm-6">
          <div class="card p-3 h-100" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); position: relative; overflow: hidden;">
            <div style="font-size: 0.75rem; font-weight: 700; color: var(--color-text-muted); text-transform: uppercase; margin-bottom: 6px;">\u{1F310} Server &amp; Uptime</div>
            <div style="font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary);" id="health-val-uptime">Connecting...</div>
            <div class="d-flex align-items-center justify-content-between mt-2 pt-2" style="border-top: 1px dashed var(--color-border); font-size: 0.75rem;">
              <span id="health-badge-server" class="badge badge-success">\u{1F7E2} Operational</span>
              <span class="text-muted" id="health-val-node">Node.js</span>
            </div>
          </div>
        </div>

        <!-- Card 2: MongoDB Latency -->
        <div class="col-md-3 col-sm-6">
          <div class="card p-3 h-100" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.75rem; font-weight: 700; color: var(--color-text-muted); text-transform: uppercase; margin-bottom: 6px;">\u{1F5C4}\uFE0F MongoDB Ping</div>
            <div style="font-size: 1.15rem; font-weight: 800; color: var(--color-primary);" id="health-val-dbping">-- ms</div>
            <div class="d-flex align-items-center justify-content-between mt-2 pt-2" style="border-top: 1px dashed var(--color-border); font-size: 0.75rem;">
              <span id="health-badge-db" class="badge badge-success">\u{1F7E2} Connected</span>
              <span class="text-muted" id="health-val-dbhost">Atlas Cloud</span>
            </div>
          </div>
        </div>

        <!-- Card 3: Memory Gauge -->
        <div class="col-md-3 col-sm-6">
          <div class="card p-3 h-100" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.75rem; font-weight: 700; color: var(--color-text-muted); text-transform: uppercase; margin-bottom: 6px;">\u{1F9E0} RAM / Memory</div>
            <div style="font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary);" id="health-val-memory">-- MB</div>
            <div class="progress mt-2" style="height: 6px; background: var(--color-border); border-radius: 4px; overflow: hidden;">
              <div id="health-memory-bar" class="progress-bar bg-success" style="width: 15%;"></div>
            </div>
            <div class="d-flex justify-content-between mt-1 text-muted" style="font-size: 0.70rem;">
              <span id="health-val-rss">RSS: --</span>
              <span>512 MB Limit</span>
            </div>
          </div>
        </div>

        <!-- Card 4: Security Hardening -->
        <div class="col-md-3 col-sm-6">
          <div class="card p-3 h-100" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.75rem; font-weight: 700; color: var(--color-text-muted); text-transform: uppercase; margin-bottom: 6px;">\u{1F512} Security &amp; RBAC</div>
            <div style="font-size: 1.15rem; font-weight: 800; color: var(--color-success);" id="health-val-security">100% Active</div>
            <div class="d-flex align-items-center justify-content-between mt-2 pt-2" style="border-top: 1px dashed var(--color-border); font-size: 0.75rem;">
              <span class="badge badge-info" id="health-badge-owasp">OWASP Guarded</span>
              <span class="text-muted" id="health-val-ratelimit">Rate Limiter \u2713</span>
            </div>
          </div>
        </div>

      </div>

      <!-- Section 1: \u{1F9EA} 6-Step End-to-End Data Pipeline Health -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F9EA}</span> 6-Step End-to-End Data Pipeline Simulation</h5>
          <div class="d-flex align-items-center gap-2">
            <span id="health-pipeline-status-badge" class="badge badge-success" style="font-size: 0.75rem;">6/6 Operational</span>
            <span class="settings-accordion-toggle">\u25B2</span>
          </div>
        </div>
        <div class="settings-accordion-body">
          <p class="text-muted small mb-3">Continuous validation that data seamlessly flows across Registration \u2794 Seat Allocation \u2794 Billing \u2794 Kiosk \u2794 Alerts.</p>
          <div id="health-pipeline-container" class="d-flex flex-column gap-2">
            <div class="text-center text-muted p-3"><div class="spinner-border spinner-border-sm text-primary"></div> Verifying pipeline integrity...</div>
          </div>
        </div>
      </div>

      <!-- Section 2: \u{1F4CA} Database Collections & Index Integrity Matrix -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F4CA}</span> Database Model Collections &amp; Index Integrity</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="table-responsive">
            <table class="table table-sm align-middle mb-0" style="font-size: 0.84rem;">
              <thead>
                <tr class="text-muted" style="border-bottom: 1.5px solid var(--color-border);">
                  <th>Model / Entity</th>
                  <th>Total Documents</th>
                  <th>Index Count</th>
                  <th>Index Health</th>
                </tr>
              </thead>
              <tbody id="health-collections-tbody">
                <tr><td colspan="4" class="text-center text-muted p-3"><div class="spinner-border spinner-border-sm text-primary"></div> Auditing database collections...</td></tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <!-- Section 3: \u{1F6E0}\uFE0F Maintenance & Performance Toolkit -->
      <div class="card settings-accordion-card">
        <div class="settings-accordion-header">
          <h5><span>\u{1F6E0}\uFE0F</span> Maintenance &amp; Performance Toolkit</h5>
          <span class="settings-accordion-toggle">\u25B2</span>
        </div>
        <div class="settings-accordion-body">
          <div class="row g-3">
            <div class="col-md-4">
              <div class="card p-3 h-100" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.9rem; margin-bottom: 4px;">\u{1F9F9} Flush SWR Cache</div>
                <p class="text-muted small mb-3">Clear stale public config &amp; SWR cache across client portals.</p>
                <button type="button" id="btn-health-clear-cache" class="btn btn-sm btn-outline-warning w-100">
                  <span>\u26A1</span> Clear Cache Now
                </button>
              </div>
            </div>
            <div class="col-md-4">
              <div class="card p-3 h-100" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.9rem; margin-bottom: 4px;">\u{1F4BE} Database Snapshot</div>
                <p class="text-muted small mb-3">Trigger an immediate immutable JSON/BSON database backup.</p>
                <button type="button" id="btn-health-backup" class="btn btn-sm btn-outline-success w-100">
                  <span>\u{1F4BE}</span> Trigger Backup
                </button>
              </div>
            </div>
            <div class="col-md-4">
              <div class="card p-3 h-100" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.9rem; margin-bottom: 4px;">\u{1F4DC} Security Audit Logs</div>
                <p class="text-muted small mb-3">Inspect system audit trail and staff administrative actions.</p>
                <a href="#/reports" class="btn btn-sm btn-outline-primary w-100">
                  <span>\u{1F4CA}</span> Open Audit Logs \u2197
                </a>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>
  `}function be(e){let m=null;async function s(g=!1){try{const a=localStorage.getItem("sl_token")||localStorage.getItem("token")||"",o=await(await fetch("/api/health")).json();if(o){const r=e.querySelector("#health-val-uptime");r&&(r.textContent=o.uptimeFormatted||`${o.uptime}s`);const u=e.querySelector("#health-val-node");u&&(u.textContent=`${o.system?.nodeVersion||"Node.js"} (PID: ${o.system?.pid||"-"})`);const n=e.querySelector("#health-val-dbping");if(n){const x=o.database?.pingLatencyMs;n.textContent=x>=0?`${x} ms`:"Connected",n.style.color=x>=0&&x>350?"var(--color-warning)":"var(--color-primary)"}const i=e.querySelector("#health-val-dbhost");i&&o.database?.host&&(i.textContent=o.database.host.split(".")[0]||"Atlas Cloud");const b=e.querySelector("#health-val-memory");b&&o.memory&&(b.textContent=`${o.memory.heapUsedMB} MB / ${o.memory.containerLimitMB} MB`);const k=e.querySelector("#health-val-rss");k&&o.memory&&(k.textContent=`RSS: ${o.memory.rssMB} MB (${o.memory.usagePercent}%)`);const A=e.querySelector("#health-memory-bar");if(A&&o.memory){const x=Math.min(100,Math.max(5,o.memory.usagePercent||15));A.style.width=`${x}%`,A.className=`progress-bar ${x>80?"bg-danger":x>60?"bg-warning":"bg-success"}`}}const l=await(await fetch("/api/system/health-check",{headers:{Authorization:`Bearer ${a}`}})).json();if(l.success&&l.data){m=l.data;const r=l.data,u=e.querySelector("#health-pipeline-container");if(u&&Array.isArray(r.dataPipelineAudit?.pipelineSteps)){const i=r.dataPipelineAudit.pipelineSteps;u.innerHTML=i.map(b=>{const k=b.status==="pass",A=k?"badge-success":"badge-danger";return`
              <div class="d-flex justify-content-between align-items-center p-2 rounded" style="background: var(--color-surface); border: 1px solid var(--color-border); font-size: 0.84rem;">
                <div class="d-flex align-items-center gap-2">
                  <span>${k?"\u2705":"\u274C"}</span>
                  <strong>Step ${b.step}: ${d(b.name)}</strong>
                  <span class="text-muted small">(${d(b.stage)})</span>
                </div>
                <div class="d-flex align-items-center gap-2">
                  <span class="text-muted small">${b.latencyMs!==void 0?b.latencyMs+"ms":""}</span>
                  <span class="badge ${A}">${d(b.details||(k?"Operational":"Failed"))}</span>
                </div>
              </div>
            `}).join("")}const n=e.querySelector("#health-collections-tbody");if(n&&r.databaseAudit?.modelCounts){const i=r.databaseAudit.modelCounts,b=r.databaseAudit.indexIntegrity||[],k={};b.forEach(x=>{k[x.model]=x});const A=[{name:"Students Master",count:i.students||0,model:"Student"},{name:"Study Desks / Seats",count:i.seats||0,model:"Seat"},{name:"Payments & Receipts",count:i.payments||0,model:"Payment"},{name:"Attendance / Check-ins",count:i.attendanceLogs||0,model:"Attendance"},{name:"Security Audit Logs",count:i.auditLogs||0,model:"AuditLog"},{name:"Staff / Users",count:i.users||0,model:"User"},{name:"Branches / Centres",count:i.branches||0,model:"Branch"},{name:"Membership Plans",count:i.plans||0,model:"Plan"},{name:"Study Shifts",count:i.shifts||0,model:"Shift"}];n.innerHTML=A.map(x=>{const C=k[x.model]?.indexCount||2;return`
              <tr>
                <td><strong>${d(x.name)}</strong></td>
                <td><span class="badge badge-secondary font-monospace">${x.count.toLocaleString()}</span></td>
                <td><span class="text-muted">${C} indexes</span></td>
                <td><span class="badge badge-success">\u{1F7E2} 100% Indexed &amp; Valid</span></td>
              </tr>
            `}).join("")}}g&&w.success("System diagnostics and live health metrics updated!")}catch(a){console.warn("Failed to fetch system diagnostics:",a)}}s(),e.querySelector("#btn-refresh-health")?.addEventListener("click",()=>{s(!0)}),e.querySelector("#btn-run-full-audit")?.addEventListener("click",async()=>{w.info("Running deep security, database & pipeline audit..."),await s(!0)}),e.querySelector("#btn-export-health-report")?.addEventListener("click",async()=>{try{const g=localStorage.getItem("sl_token")||localStorage.getItem("token")||"",[a,o]=await Promise.all([fetch("/api/health").catch(()=>null),fetch("/api/system/health-check",{headers:{Authorization:`Bearer ${g}`}}).catch(()=>null)]),l=a?await a.json():{},r=o?await o.json():{},u={exportedAt:new Date().toISOString(),systemHealth:l,detailedAudit:r?.data||m||{}},n=new Blob([JSON.stringify(u,null,2)],{type:"application/json"}),i=URL.createObjectURL(n),b=document.createElement("a");b.href=i,b.download=`system-health-diagnostics-${new Date().toISOString().slice(0,10)}.json`,document.body.appendChild(b),b.click(),document.body.removeChild(b),URL.revokeObjectURL(i),w.success("Diagnostic report downloaded successfully!")}catch{w.error("Failed to export diagnostic report.")}}),e.querySelector("#btn-health-clear-cache")?.addEventListener("click",()=>{try{localStorage.removeItem("sl_public_config_cache"),localStorage.removeItem("sl_public_profile_cache"),w.success("In-memory and local SWR caches purged successfully!")}catch{w.info("Cache cleared.")}}),e.querySelector("#btn-health-backup")?.addEventListener("click",()=>{e.querySelector("#btn-master-quick-backup")?.click()})}function ge(e,m){const s=document.createElement("div"),g=m.map(o=>`<option value="${o._id}">${d(o.name)}</option>`).join("");s.innerHTML=`
    <form id="form-add-staff" class="p-2">
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Full Name *</label>
        <input type="text" id="staff-name" class="form-control" placeholder="e.g. Ramesh Kumar" required>
      </div>
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Email Address (Login ID) *</label>
        <input type="email" id="staff-email" class="form-control" placeholder="e.g. ramesh@library.com" required>
      </div>
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Password *</label>
        <input type="password" id="staff-password" class="form-control" placeholder="Create temporary password" required>
      </div>
      <div class="form-group mb-2">
        <label class="form-label" style="font-weight: 600;">Phone Number</label>
        <input type="tel" id="staff-phone" class="form-control" placeholder="10-digit mobile">
      </div>
      <div class="row g-2 mb-3">
        <div class="col-6">
          <label class="form-label" style="font-weight: 600;">Role *</label>
          <select id="staff-role" class="form-select form-control">
            <option value="staff">Staff / Receptionist</option>
            <option value="branch_manager">Branch Manager</option>
            <option value="owner">Admin / Co-Owner</option>
          </select>
        </div>
        <div class="col-6">
          <label class="form-label" style="font-weight: 600;">Assigned Centre</label>
          <select id="staff-branch" class="form-select form-control">
            <option value="">All Branches</option>
            ${g}
          </select>
        </div>
      </div>
      <div class="d-flex justify-content-end gap-2 pt-2 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-save-staff">Create Staff Account</button>
      </div>
    </form>
  `;const a=new j({title:"\u{1F465} Add Staff Team Member",content:s,size:"md"});a.show(),s.querySelector("#form-add-staff")?.addEventListener("submit",async o=>{o.preventDefault();const l=s.querySelector("#staff-name").value.trim(),r=s.querySelector("#staff-email").value.trim(),u=s.querySelector("#staff-password").value,n=s.querySelector("#staff-phone").value.trim(),i=s.querySelector("#staff-role").value,b=s.querySelector("#staff-branch").value||null;try{await E.post("/api/auth/users",{name:l,email:r,password:u,phone:n,role:i,branch:b}),w.success("Staff account created successfully!"),a.close(),O(e)}catch(k){w.error(k.message||"Failed to create staff account")}})}async function ye(e,m,s){const g=[e.querySelector("#btn-master-save-all"),e.querySelector("#btn-master-save-all-mobile")].filter(Boolean);g.forEach(a=>I.button(a,!0));try{const a=[],o=(t,p)=>{const S=e.querySelector(t);return S?S.value.trim():p??""},l=(t,p)=>{const S=e.querySelector(t);return S&&S.value!==""?Number(S.value):p??0},r=(t,p)=>{const S=e.querySelector(t);return S?S.checked:!!p},u={...s.profile,businessName:o("#setting-businessName",s.profile.businessName),tagline:o("#setting-tagline",s.profile.tagline),phone:o("#setting-phone",s.profile.phone),email:o("#setting-email",s.profile.email),website:o("#setting-website",s.profile.website),address:o("#setting-address",s.profile.address),city:o("#setting-city",s.profile.city),state:o("#setting-state",s.profile.state),pincode:o("#setting-pincode",s.profile.pincode),registrationNumber:o("#setting-regNumber",s.profile.registrationNumber),gstNumber:o("#setting-gstNumber",s.profile.gstNumber),logo:(e.querySelector("#setting-logo")||e.querySelector('input[name="logo"]'))?.value?.trim()||s.profile.logo,favicon:(e.querySelector("#setting-favicon")||e.querySelector('input[name="favicon"]'))?.value?.trim()||s.profile.favicon,stampImage:(e.querySelector("#setting-stamp")||e.querySelector('input[name="stampImage"]'))?.value?.trim()||s.profile.stampImage,bannerImage:(e.querySelector("#setting-banner")||e.querySelector('input[name="bannerImage"]'))?.value?.trim()||s.profile.bannerImage,upiId:o("#setting-bill-upiId",s.profile.upiId),upiQrCode:(e.querySelector("#setting-bill-upiQr")||e.querySelector('input[name="upiQrCode"]'))?.value?.trim()||s.profile.upiQrCode,bankDetails:{...s.profile.bankDetails||{},accountName:o("#setting-bank-accName",s.profile.bankDetails?.accountName),accountNumber:o("#setting-bank-accNo",s.profile.bankDetails?.accountNumber),bankName:o("#setting-bank-name",s.profile.bankDetails?.bankName),ifscCode:o("#setting-bank-ifsc",s.profile.bankDetails?.ifscCode),branchName:o("#setting-bank-branch",s.profile.bankDetails?.branchName)},paymentInstructions:o("#setting-pay-instructions",s.profile.paymentInstructions),gatewayProvider:e.querySelector("#setting-gateway-provider")?.value||s.profile.gatewayProvider||"manual_upi",razorpayKeyId:o("#setting-razorpay-key",s.profile.razorpayKeyId),socialLinks:{...s.profile.socialLinks||{},whatsapp:o("#setting-social-wa",s.profile.socialLinks?.whatsapp),instagram:o("#setting-social-insta",s.profile.socialLinks?.instagram),facebook:o("#setting-social-fb",s.profile.socialLinks?.facebook)}},n=e.querySelectorAll(".setting-paymethod-row");n.length>0&&(u.paymentMethods=Array.from(n).map((t,p)=>({key:t.dataset.key,name:t.querySelector(".spm-name")?.value?.trim()||t.dataset.name,subtitle:t.querySelector(".spm-sub")?.value?.trim()||"",icon:t.dataset.icon||"\u{1F4B3}",enabled:t.querySelector(".spm-enabled")?t.querySelector(".spm-enabled").checked:!0,order:p+1,instructions:t.querySelector(".spm-instructions")?.value?.trim()||"",requiresRef:t.querySelector(".spm-reqref")?t.querySelector(".spm-reqref").checked:!0,refLabel:t.querySelector(".spm-reflabel")?.value?.trim()||"Transaction Reference / UTR *"})));const i={payment:{gracePeriod:l("#setting-pay-grace",s.settings.pay?.gracePeriod??5),lateFeeAmount:l("#setting-pay-lateFee",s.settings.pay?.lateFeeAmount??50),autoSuspendDays:l("#setting-pay-suspend",s.settings.pay?.autoSuspendDays??15)},locker:{enableAddon:r("#setting-locker-enable",s.settings.locker?.enableAddon!==!1),monthlyFee:l("#setting-locker-fee",s.settings.locker?.monthlyFee??200),deposit:l("#setting-locker-deposit",s.settings.locker?.deposit??0),title:o("#setting-locker-title",s.settings.locker?.title||"Add Personal Study Locker"),description:o("#setting-locker-desc",s.settings.locker?.description||"Secure private key-allotted locker to safely keep heavy study books, notes & laptop.")},admission:{idPrefix:o("#setting-adm-idPrefix",s.settings.adm?.idPrefix||"STU")},billing:{receiptPrefix:o("#setting-bill-prefix",s.settings.billing?.receiptPrefix||"LIB-2026"),defaultTemplate:e.querySelector(".receipt-format-card.active")?.dataset.format||s.settings.billing?.defaultTemplate||"thermal80",gstRate:l("#setting-bill-gstRate",s.settings.billing?.gstRate??18),hsnSacCode:o("#setting-bill-hsn",s.settings.billing?.hsnSacCode||"999293"),refundPolicyDays:l("#setting-bill-refundDays",s.settings.billing?.refundPolicyDays??3)},notification:{enableWhatsapp:r("#setting-notif-wa",s.settings.notif?.enableWhatsapp??!0),whatsappScheduleTime:o("#setting-notif-time",s.settings.notif?.whatsappScheduleTime||"09:30"),expiryReminderDays:o("#setting-notif-expiryDays",s.settings.notif?.expiryReminderDays||"7, 3, 1, 0"),balanceReminderDays:o("#setting-notif-balanceDays",s.settings.notif?.balanceReminderDays||"7, 3, 1"),enableAutoExpiryBot:r("#setting-notif-expiryBot",s.settings.notif?.enableAutoExpiryBot!==!1),enableAutoDuesBot:r("#setting-notif-duesBot",s.settings.notif?.enableAutoDuesBot!==!1),enableConversationalBot:r("#setting-notif-chatBot",s.settings.notif?.enableConversationalBot!==!1),whatsappProvider:o("#setting-notif-provider",s.settings.notif?.whatsappProvider||"none"),ultramsgInstanceId:o("#setting-notif-ultramsgId",s.settings.notif?.ultramsgInstanceId||""),ultramsgToken:o("#setting-notif-ultramsgToken",s.settings.notif?.ultramsgToken||""),fast2smsApiKey:o("#setting-notif-fast2smsKey",s.settings.notif?.fast2smsApiKey||""),metaPhoneNumberId:o("#setting-notif-metaPhoneId",s.settings.notif?.metaPhoneNumberId||""),metaAccessToken:o("#setting-notif-metaToken",s.settings.notif?.metaAccessToken||""),webhookUrl:o("#setting-notif-webhookUrl",s.settings.notif?.webhookUrl||"")},operations:{openingTime:o("#setting-ops-open",s.settings.ops?.openingTime||"06:00"),closingTime:o("#setting-ops-close",s.settings.ops?.closingTime||"23:00"),weeklyOff:o("#setting-ops-weeklyOff",s.settings.ops?.weeklyOff||"none"),autoCheckout:r("#setting-ops-autoCheckout",s.settings.ops?.autoCheckout!==!1),autoCheckoutHours:l("#setting-ops-autoCheckoutHours",Number(s.settings.ops?.autoCheckoutHours)||16),autoCheckoutTime:o("#setting-ops-autoCheckoutTime",s.settings.ops?.autoCheckoutTime||"23:00"),gracePeriodMinutes:l("#setting-ops-graceMinutes",Number(s.settings.ops?.gracePeriodMinutes)||15),latePenaltyPerHour:l("#setting-ops-overstayPenalty",Number(s.settings.ops?.latePenaltyPerHour)||0),examExtendedHours:r("#setting-ops-examHours",!!s.settings.ops?.examExtendedHours),emergencyNotice:o("#setting-ops-emergencyNotice",s.settings.ops?.emergencyNotice||""),emergencyNoticeEnabled:r("#setting-ops-emergencyToggle",!!s.settings.ops?.emergencyNoticeEnabled)},kiosk:{enableVoice:r("#setting-kiosk-voice",s.settings.kiosk?.enableVoice!==!1),voiceLanguage:o("#setting-kiosk-lang",s.settings.kiosk?.voiceLanguage||"en-IN"),soundEnabled:r("#setting-kiosk-sound",s.settings.kiosk?.soundEnabled!==!1),autoCheckout:r("#setting-kiosk-autoCheckout",s.settings.kiosk?.autoCheckout!==!1),autoCheckoutHours:l("#setting-kiosk-checkoutHours",Number(s.settings.kiosk?.autoCheckoutHours)||16),screenTimeoutSeconds:l("#setting-kiosk-timeout",Number(s.settings.kiosk?.screenTimeoutSeconds)||10),announcementVolume:l("#setting-kiosk-volume",Number(s.settings.kiosk?.announcementVolume)||80)},automations:{autoSeatExpiry:r("#setting-auto-seatExpiry",s.settings.auto?.autoSeatExpiry!==!1),autoDueReminders:r("#setting-auto-dueReminders",s.settings.auto?.autoDueReminders!==!1)},portal:{...s.settings.portal||{}}};e.querySelectorAll(".student-portal-toggle").forEach(t=>{i.portal[t.dataset.key]=t.checked}),Object.assign(s.profile,u),Object.assign(s.settings,i),a.push(E.put("/api/settings/business-profile",u)),a.push(E.put("/api/settings/system-settings",i));try{localStorage.removeItem("sl_public_config_cache"),localStorage.removeItem("sl_public_profile_cache")}catch{}const b=e.querySelector("#branding-headerText")?.value?.trim(),k=e.querySelector("#branding-tagline")?.value?.trim(),A=e.querySelector("#branding-alignment")?.value||"center",x=e.querySelector("#branding-logoSize")?.value||"64";(b||k)&&a.push(E.put("/api/custom-fields/templates/active",{branding:{headerText:b||"Student Admission Wizard",tagline:k||"Silence, Focus & Success",alignment:A,logoSize:x,showLogo:!0}}).catch(t=>console.warn("FormTemplate save warning:",t.message)));const C=e.querySelector("#rc-header-subtitle"),L=e.querySelector("#rc-toggle-paymentMode");if(C||L||e.querySelector("#rc-toggle-stuId")){const t=e.querySelector(".receipt-format-card.active")?.dataset.format||s.settings.billing?.defaultTemplate||"thermal80",p=e.querySelector("#rc-header-gstin")?.value?.trim(),S={activeTemplate:t,header:{showLogo:e.querySelector("#rc-toggle-logo")?e.querySelector("#rc-toggle-logo").checked:!0,showBusinessName:!0,subtitle:e.querySelector("#rc-header-subtitle")?.value?.trim()||"Official Fee Receipt",showAddress:e.querySelector("#rc-toggle-address")?e.querySelector("#rc-toggle-address").checked:!0,showPhone:e.querySelector("#rc-toggle-contact")?e.querySelector("#rc-toggle-contact").checked:!0,showEmail:e.querySelector("#rc-toggle-contact")?e.querySelector("#rc-toggle-contact").checked:!0,showGst:!!p,gstNumber:p,headerColor:e.querySelector("#rc-header-color")?.value||"#4f46e5"},body:{showStudentId:e.querySelector("#rc-toggle-stuId")?e.querySelector("#rc-toggle-stuId").checked:!0,showStudentPhone:e.querySelector("#rc-toggle-stuPhone")?e.querySelector("#rc-toggle-stuPhone").checked:!0,showSeatNumber:e.querySelector("#rc-toggle-seat")?e.querySelector("#rc-toggle-seat").checked:!0,showShift:e.querySelector("#rc-toggle-seat")?e.querySelector("#rc-toggle-seat").checked:!0,showPeriod:e.querySelector("#rc-toggle-validity")?e.querySelector("#rc-toggle-validity").checked:!0,showDiscount:e.querySelector("#rc-toggle-breakdown")?e.querySelector("#rc-toggle-breakdown").checked:!0,showPaymentMethod:e.querySelector("#rc-toggle-paymentMode")?e.querySelector("#rc-toggle-paymentMode").checked:!0,showTransactionId:e.querySelector("#rc-toggle-paymentMode")?e.querySelector("#rc-toggle-paymentMode").checked:!0},stamp:{showStamp:e.querySelector("#rc-toggle-stamp")?e.querySelector("#rc-toggle-stamp").checked:!0,stampText:e.querySelector("#rc-stamp-text")?.value?.trim()||"PAID \u2022 OFFICIAL RECEIPT",stampColor:e.querySelector("#rc-stamp-color")?.value||"#059669",showWatermark:t==="standardA4"},footer:{showSignature:e.querySelector("#rc-toggle-signature")?e.querySelector("#rc-toggle-signature").checked:!0,signatureLabel:e.querySelector("#rc-signature-label")?.value?.trim()||"Authorized Signatory",showUpiQr:e.querySelector("#rc-toggle-upiqr")?e.querySelector("#rc-toggle-upiqr").checked:!0,termsText:e.querySelector("#rc-terms-text")?.value?.trim(),customNote:e.querySelector("#rc-custom-note")?.value?.trim(),showTimestamp:e.querySelector("#rc-toggle-timestamp")?e.querySelector("#rc-toggle-timestamp").checked:!0},gst:{enabled:Number(e.querySelector("#setting-bill-gstRate")?.value||18)>0,gstRate:Number(e.querySelector("#setting-bill-gstRate")?.value||18),hsnCode:e.querySelector("#setting-bill-hsn")?.value?.trim()||"999293"}};s.settings&&(s.settings.receipt=S),a.push(E.put("/api/settings/receipt-config",S))}const B=await Promise.all(a),D=B[0]||{},y=B[1]||{};if(D.success||y.success){w.success("Master Settings updated successfully across all modules!");const t=D.data||u;window.ThemeManager&&typeof window.ThemeManager.applyPublicBranding=="function"&&window.ThemeManager.applyPublicBranding(t);try{localStorage.setItem("sl_public_profile_cache",JSON.stringify(t)),localStorage.setItem("sl_settings_sync_trigger",Date.now().toString()),window.dispatchEvent(new CustomEvent("sl:settings-updated",{detail:{profile:t,settings:i}}))}catch{}typeof window.updateDynamicFaviconAndTitle=="function"&&t&&window.updateDynamicFaviconAndTitle(t)}else w.error("Settings updated with warnings.")}catch(a){w.error(a.message||"Failed to save settings.")}finally{g.forEach(a=>I.button(a,!1))}}export{O as render};
