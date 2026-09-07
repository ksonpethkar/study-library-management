import"../app.js";import{t as Z}from"../i18n.js";import{Toast as k,Modal as ge,Loading as Ae,Confirm as Ne,escapeHTML as a,debounce as ft,copyToClipboard as nt,UI as De}from"../ui.js";import{SmartFormatters as pe}from"../utils/smartFormatters.js";import{SignatureStudio as yt}from"../signatureStudio.js";import{MediaFieldPicker as je}from"../mediaStudio.js";import z from"../api.js";import{previewAdmissionFormPDF as Re}from"../pdfGenerator.js";import{renderHeatmapGridHtml as ht}from"./portal.js";import{IDBStorage as ae}from"../utils/idbStorage.js";import{OptimisticUI as ot}from"../utils/optimisticUI.js";import{SmartIntelligence as be}from"../utils/smartIntelligence.js";import{renderHeatmap as vt,renderBehaviorBadge as xt}from"../utils/attendanceHeatmap.js";import{Validators as ue}from"../utils/validators.js";import{PaymentStudio as wt}from"../paymentStudio.js";import{initSwipeCards as $t}from"../utils/mobileGestures.js";async function Ft(){const K=document.createElement("div");K.className="page-container";const Be=document.createElement("div");Be.className="module-header",Be.innerHTML=`
    <div class="module-title-area">
      <h2>\u{1F465} ${Z("Students Directory")}</h2>
      <p>Manage student admissions, memberships, identity proofs, and academic records.</p>
    </div>
    <div class="module-actions">
      <button id="addStudentBtn" class="btn btn-primary d-flex align-items-center gap-2" style="font-weight: 700;">
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
        ${Z("+ Add Student")}
      </button>
    </div>
  `,K.appendChild(Be);const Te=document.createElement("div");Te.style.cssText="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;",Te.innerHTML='<span style="font-size: 1.1rem;">\u{1F4A1}</span> <span><strong>Tip:</strong> Click any student row to view study habit consistency, attendance history, and payment ledger.</span>',K.appendChild(Te);const xe=document.createElement("div");xe.className="kpi-grid",xe.id="students-stats",K.appendChild(xe);const Pe=document.createElement("div");Pe.className="card";const ze=document.createElement("div");ze.className="card-header d-flex justify-content-between align-items-center flex-wrap gap-3",ze.innerHTML=`
    <div class="search-box w-100 w-md-auto" style="flex: 1; max-width: 360px;">
      <input type="text" id="studentSearch" class="form-control form-control-sm w-100" placeholder="${Z("Search by name, phone, student ID...")}" />
    </div>
    <div class="filter-box d-flex gap-2 align-items-center w-100 w-md-auto">
      <label class="form-label mb-0 text-xs" style="font-weight: 700; color: var(--color-text-secondary);">STATUS:</label>
      <select id="studentStatusFilter" class="form-select form-control form-control-sm w-100" style="max-width: 160px; font-weight: 600;">
        <option value="all">${Z("All Status")}</option>
        <option value="active">\u{1F7E2} ${Z("Active")}</option>
        <option value="inactive">\u26AA ${Z("Inactive")}</option>
        <option value="pending_payment">\u23F3 Pending Fee</option>
        <option value="suspended">\u{1F7E1} ${Z("Suspended")}</option>
        <option value="expired">\u{1F534} ${Z("Expired")}</option>
      </select>
    </div>
  `,Pe.appendChild(ze);const U=document.createElement("div");U.className="card-body p-0",U.id="students-table-container",Pe.appendChild(U),K.appendChild(Pe);const N={students:[],pagination:{page:1,limit:10,total:0,pages:1}};function Oe(e){xe.innerHTML=`
      <div class="kpi-card kpi-primary">
        <div class="kpi-label">${Z("Total Students")} <span>\u{1F465}</span></div>
        <div class="kpi-value">${e.total||0}</div>
        <div class="kpi-subtext">All registered members</div>
      </div>
      <div class="kpi-card kpi-success">
        <div class="kpi-label">${Z("Active Members")} <span>\u{1F7E2}</span></div>
        <div class="kpi-value text-success">${e.active||0}</div>
        <div class="kpi-subtext">Currently studying</div>
      </div>
      <div class="kpi-card kpi-danger">
        <div class="kpi-label">${Z("Expired / Due")} <span>\u{1F534}</span></div>
        <div class="kpi-value text-danger">${e.expired||0}</div>
        <div class="kpi-subtext">Needs membership renewal</div>
      </div>
      <div class="kpi-card kpi-info">
        <div class="kpi-label">${Z("New This Month")} <span>\u2728</span></div>
        <div class="kpi-value" style="color: var(--color-info);">${e.newThisMonth||0}</div>
        <div class="kpi-subtext">Recent admissions</div>
      </div>
    `}async function fe(){let e=!1;try{const s=await ae.get("students","stats");s&&(Oe(s),e=!0)}catch(s){console.warn("IDB read stats warning:",s)}e||Ae.skeleton(xe,"kpi");try{const s=await z.get("/api/students/stats");if(s.success&&s.data){const r=s.data;await ae.set("students","stats",r),Oe(r)}}catch(s){console.error(s)}}async function ee(e=1){const s=K.querySelector("#studentSearch")?.value||"",r=K.querySelector("#studentStatusFilter")?.value||"all",w=`list_${e}_${s}_${r}`;let P=!1;try{const F=await ae.get("students",w);F&&F.students&&(N.students=F.students||[],N.pagination=F.pagination||{page:1,limit:10,total:0,pages:1},ye(),P=!0)}catch(F){console.warn("IDB read students list warning:",F)}P||Ae.skeleton(U,"table");try{const F=await z.get("/api/students",{page:e,limit:10,search:s,status:r});F.success&&F.data&&(N.students=F.data.students||[],N.pagination=F.data.pagination||{page:1,limit:10,total:0,pages:1},await ae.set("students",w,F.data),ye())}catch(F){P||(k.error(F.message||"Failed to load students"),U.innerHTML='<div class="text-center p-5 text-muted">Error loading students list.</div>')}}function ye(){if(N.students.length===0){De.emptyState(U,{icon:"\u{1F393}",title:"No Students Found",description:"No student records match your search or status filter. Click below to enroll a new member.",actionText:"+ Add Student",onAction:()=>{const i=K.querySelector("#addStudentBtn");i&&i.click()}});return}let e=N.students.map(i=>{let d="background: rgba(255,255,255,0.08); color: #ccc;";i.status==="active"?d="background: rgba(0, 184, 148, 0.2); color: var(--color-success, #00b894);":i.status==="pending_payment"||i.status==="pending"?d="background: rgba(245, 158, 11, 0.2); color: var(--color-warning, var(--color-warning));":i.status==="expired"?d="background: rgba(214, 48, 49, 0.2); color: var(--color-danger, #d63031);":i.status==="suspended"&&(d="background: rgba(253, 203, 110, 0.2); color: var(--color-warning, #fdcb6e);");const l=i.plan?.name||"-",p=i.seat?.seatNumber||"-",S=i.expiryDate?new Date(i.expiryDate).toLocaleDateString("en-IN"):"-";return`
        <tr class="student-row" data-id="${a(i._id)}" data-student-id="${a(i.studentId||"")}">
          <td style="width: 44px; text-align: center; vertical-align: middle; padding: 0.5rem 0.25rem;">
            <label class="student-select-label" style="position: relative; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; width: 22px; height: 22px; margin: 0;">
              <input type="checkbox" class="student-select-cb" data-id="${a(i._id)}" style="position: absolute; opacity: 0; width: 0; height: 0; margin: 0; pointer-events: none;">
              <span class="custom-select-circle" style="width: 20px; height: 20px; border-radius: 50%; border: 2px solid var(--color-border, #cbd5e1); display: inline-flex; align-items: center; justify-content: center; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); opacity: 0; font-size: 11px; color: #fff; background: transparent;">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" style="display: none;"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </span>
            </label>
          </td>
          <td class="col-student-id" style="white-space: nowrap;"><span style="font-family: monospace; font-weight: 700; display: inline-block;">${a(i.studentId||"-")}</span> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(i.studentId||"")}" style="padding: 2px 5px; font-size: 0.7rem; display: inline-flex; align-items: center; vertical-align: middle;" title="Copy Student ID">\u{1F4CB}</button></td>
          <td class="col-name" style="white-space: nowrap;"><strong>${a(i.name||"-")}</strong></td>
          <td class="col-phone" style="white-space: nowrap;"><span style="display: inline-block;">${a(pe.phone(i.phone)||"-")}</span> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(i.phone||"")}" style="padding: 2px 5px; font-size: 0.7rem; display: inline-flex; align-items: center; vertical-align: middle;" title="Copy Phone">\u{1F4CB}</button></td>
          <td style="white-space: nowrap;"><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary, #6c5ce7); font-weight: 600;">${a(l)}</span></td>
          <td style="white-space: nowrap;"><span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success, #00b894); font-weight: 600;">${a(p)}</span></td>
          <td style="white-space: nowrap;">${S} ${i.expiryDate?`<small class="text-muted">(${pe.timeAgo(i.expiryDate)})</small>`:""}</td>
          <td class="col-status" style="white-space: nowrap;"><span class="badge btn-toggle-student-status" data-id="${a(i._id)}" style="${d} padding: 4px 8px; border-radius: 4px; font-weight: 600; text-transform: uppercase; font-size: 0.75rem; cursor: pointer;" title="Click to toggle status">${a(i.status||"active")}</span></td>
          <td style="white-space: nowrap;">
            <div style="width: 85px;" title="KYC Profile Completion: ${i.profileCompletion||60}%">
              <div style="display: flex; align-items: center; justify-content: space-between; font-size: 0.72rem; font-weight: 800; color: ${i.profileCompletion>=100?"var(--color-success)":"var(--color-warning)"}; margin-bottom: 2px;">
                <span>${i.profileCompletion>=100?"\u{1F7E2} 100%":`\u{1F7E1} ${i.profileCompletion||60}%`}</span>
              </div>
              <div style="width: 100%; height: 5px; background: rgba(255,255,255,0.12); border-radius: 4px; overflow: hidden;">
                <div style="height: 100%; width: ${i.profileCompletion||60}%; background: ${i.profileCompletion>=100?"#00b894":"linear-gradient(90deg, var(--color-warning), #00b894)"}; border-radius: 4px;"></div>
              </div>
            </div>
          </td>
          <td style="white-space: nowrap;">
            <div class="btn-icon-group">
              <button type="button" class="btn-icon-action action-edit btn-view" data-id="${a(i._id)}" data-tooltip="View Profile" aria-label="View Profile">\u{1F441}\uFE0F</button>
              <button type="button" class="btn-icon-action action-whatsapp btn-wa-remind" data-id="${a(i._id)}" data-tooltip="WhatsApp" aria-label="WhatsApp">\u{1F4AC}</button>
              <button type="button" class="btn-icon-action action-receipt btn-id-pass" data-id="${a(i._id)}" data-tooltip="ID Card" aria-label="ID Card">\u{1FAAA}</button>
              <button type="button" class="btn-icon-action action-edit btn-edit" data-id="${a(i._id)}" data-tooltip="Edit" aria-label="Edit">\u270F\uFE0F</button>
              ${typeof ActionMenu<"u"?ActionMenu.renderHtml([{header:"Level 1: Core Operations"},{id:"view",icon:"\u{1F441}\uFE0F",label:"View 360\xB0 Profile",bold:!0},{id:"edit",icon:"\u270F\uFE0F",label:"Edit Member Details"},{divider:!0},{header:"Level 2: Status & Lifecycle"},{id:"toggle-status",icon:i.status==="active"?"\u23F8\uFE0F":"\u{1F7E2}",label:i.status==="active"?"Suspend / Deactivate":"Activate Membership"},{divider:!0},{header:"Level 3: Documents & Data"},{id:"idcard",icon:"\u{1FAAA}",label:"Print Digital ID Pass"},{id:"pdfform",icon:"\u{1F4C4}",label:"Download Admission PDF"},{id:"pwdreset",icon:"\u{1F511}",label:"Reset Password / PIN"},{divider:!0},{header:"Level 4: Critical & Danger"},{id:"delete",icon:"\u{1F5D1}\uFE0F",label:"Delete Student Record",danger:!0}],i._id):""}
            </div>
          </td>
        </tr>
      `}).join(""),s=N.students.map(i=>{let d="badge-active";i.status==="active"?d="badge-active":i.status==="pending_payment"||i.status==="pending"?d="badge-pending":i.status==="expired"?d="badge-expired":i.status==="suspended"&&(d="badge-inactive");const l=i.plan?.name||"-",p=i.seat?.seatNumber||"-",S=i.expiryDate?new Date(i.expiryDate).toLocaleDateString("en-IN"):"-",h=i.expiryDate?pe.timeAgo(i.expiryDate):"";return`
        <div class="swipe-item-container">
          <div class="swipe-actions-revealed">
            <a href="https://wa.me/91${a(String(i.phone||"").replace(/[^0-9]/g,"").slice(-10))}" target="_blank" class="swipe-btn swipe-btn-whatsapp" title="WhatsApp" onclick="event.stopPropagation()">
              <span style="font-size: 1.25rem;">\u{1F4AC}</span>
              <span>Chat</span>
            </a>
            <a href="tel:${a(i.phone||"")}" class="swipe-btn swipe-btn-call" title="Call" onclick="event.stopPropagation()">
              <span style="font-size: 1.25rem;">\u{1F4DE}</span>
              <span>Call</span>
            </a>
          </div>
          <div class="swipe-card-content mobile-data-card" data-id="${a(i._id)}" data-student-id="${a(i.studentId||"")}">
            <div class="mobile-card-header">
              <div style="min-width: 0; flex: 1;">
                <div class="mobile-card-title">${a(i.name||"-")}</div>
                <div class="mobile-card-subtitle" style="display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-top: 4px;">
                  <span style="font-family: monospace; font-weight: 700; color: var(--color-primary);">${a(i.studentId||"-")}</span>
                  <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(i.studentId||"")}" style="padding: 2px 6px; min-height: 28px; min-width: 28px;" title="Copy Student ID">\u{1F4CB}</button>
                  <span>\u2022</span>
                  <span>${a(pe.phone(i.phone)||"-")}</span>
                  <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(i.phone||"")}" style="padding: 2px 6px; min-height: 28px; min-width: 28px;" title="Copy Phone">\u{1F4CB}</button>
                </div>
              </div>
              <span class="mobile-card-badge ${d} btn-toggle-student-status" data-id="${a(i._id)}" style="cursor: pointer;" title="Tap to toggle status">
                ${a(i.status||"active")}
              </span>
            </div>

            <div class="mobile-card-details">
              <div class="mobile-card-detail">
                <div class="mobile-card-detail-label">Plan</div>
                <div class="mobile-card-detail-value" style="color: var(--color-primary);">${a(l)}</div>
              </div>
              <div class="mobile-card-detail">
                <div class="mobile-card-detail-label">Seat</div>
                <div class="mobile-card-detail-value" style="color: var(--color-success); font-weight: 700;">${a(p)}</div>
              </div>
              <div class="mobile-card-detail">
                <div class="mobile-card-detail-label">Expiry</div>
                <div class="mobile-card-detail-value">${S} ${h?`<small class="text-muted">(${h})</small>`:""}</div>
              </div>
              <div class="mobile-card-detail">
                <div class="mobile-card-detail-label">KYC Profile</div>
                <div class="mobile-card-detail-value" style="font-size: 0.8rem; font-weight: 700; color: ${i.profileCompletion>=100?"var(--color-success)":"var(--color-warning)"};">
                  ${i.profileCompletion>=100?"\u{1F7E2} 100%":`\u{1F7E1} ${i.profileCompletion||60}%`}
                </div>
              </div>
            </div>

            <div class="mobile-card-actions" style="display: flex; gap: 6px; align-items: center;">
              <button type="button" class="btn btn-sm btn-outline-primary btn-view" data-id="${a(i._id)}" style="min-height: 42px; flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: 4px; font-weight: 700;">
                \u{1F441}\uFE0F Profile
              </button>
              <button type="button" class="btn btn-sm btn-outline-success btn-wa-remind" data-id="${a(i._id)}" style="min-height: 42px; flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: 4px; font-weight: 700;">
                \u{1F4AC} WhatsApp
              </button>
              <button type="button" class="btn btn-sm btn-outline-secondary btn-edit" data-id="${a(i._id)}" style="min-height: 42px; flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: 4px; font-weight: 700;">
                \u270F\uFE0F Edit
              </button>
              ${typeof ActionMenu<"u"?ActionMenu.renderHtml([{header:"Level 1: Core Operations"},{id:"view",icon:"\u{1F441}\uFE0F",label:"View 360\xB0 Profile",bold:!0},{id:"edit",icon:"\u270F\uFE0F",label:"Edit Member Details"},{divider:!0},{header:"Level 2: Status & Lifecycle"},{id:"toggle-status",icon:i.status==="active"?"\u23F8\uFE0F":"\u{1F7E2}",label:i.status==="active"?"Suspend / Deactivate":"Activate Membership"},{divider:!0},{header:"Level 3: Documents & Data"},{id:"idcard",icon:"\u{1FAAA}",label:"Print Digital ID Pass"},{id:"pdfform",icon:"\u{1F4C4}",label:"Download Admission PDF"},{id:"pwdreset",icon:"\u{1F511}",label:"Reset Password / PIN"},{divider:!0},{header:"Level 4: Critical & Danger"},{id:"delete",icon:"\u{1F5D1}\uFE0F",label:"Delete Student Record",danger:!0}],i._id):""}
            </div>
          </div>
        </div>
      `}).join("");U.innerHTML=`
      <style>
        .students-table-container tr .custom-select-circle {
          opacity: 0;
          transform: scale(0.85);
          transition: opacity 0.2s ease, transform 0.2s ease, background-color 0.2s ease, border-color 0.2s ease;
        }
        .students-table-container tr:hover .custom-select-circle {
          opacity: 0.65;
          transform: scale(1);
          border-color: var(--color-primary, #6c5ce7);
        }
        .students-table-container.has-selections thead .master-select-circle,
        .students-table-container thead:hover .master-select-circle {
          opacity: 0.65 !important;
          transform: scale(1) !important;
        }
        .students-table-container .student-select-cb:checked + .custom-select-circle,
        .students-table-container #selectAllStudents:checked + .custom-select-circle {
          opacity: 1 !important;
          transform: scale(1) !important;
          background-color: var(--color-primary, #6c5ce7) !important;
          border-color: var(--color-primary, #6c5ce7) !important;
        }
        .students-table-container .student-select-cb:checked + .custom-select-circle svg,
        .students-table-container #selectAllStudents:checked + .custom-select-circle svg {
          display: block !important;
        }
        .students-table-container tr.row-selected {
          background-color: rgba(108, 92, 231, 0.08) !important;
        }
      </style>

      <!-- Floating Bulk Action Bar -->
      <div id="bulk-actions-bar" style="display: none; padding: 0.75rem 1.25rem; background: var(--color-surface); border-bottom: 2px solid var(--color-primary); justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
        <div class="d-flex align-items-center gap-2">
          <span class="badge badge-primary" id="selected-count-badge">0 selected</span>
          <span class="text-muted small">Bulk Actions:</span>
        </div>
        <div class="d-flex gap-2 flex-wrap">
          <button class="btn btn-sm btn-outline-success" id="btn-bulk-whatsapp" style="font-size: 0.8rem; font-weight: 600;">
            \u{1F4F2} WhatsApp Reminders
          </button>
          <button class="btn btn-sm btn-outline-primary" id="btn-bulk-renew" style="font-size: 0.8rem; font-weight: 600;">
            \u{1F504} Bulk Renew (+30d)
          </button>
          <button class="btn btn-sm btn-outline-secondary" id="btn-bulk-export" style="font-size: 0.8rem; font-weight: 600;">
            \u{1F4C4} Export Selected
          </button>
          <button class="btn btn-sm btn-outline-danger" id="btn-bulk-deactivate" style="font-size: 0.8rem; font-weight: 600;">
            \u{1F5D1}\uFE0F Deactivate Selected
          </button>
        </div>
      </div>

      <!-- Desktop Table View (hidden on mobile <= 768px via mobile-cards.css) -->
      <div class="table-responsive students-table-container desktop-table-view">
        <table class="table data-table mb-0">
          <thead>
            <tr>
              <th style="width: 44px; text-align: center; vertical-align: middle; padding: 0.5rem 0.25rem;">
                <label class="select-all-label" style="position: relative; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; width: 22px; height: 22px; margin: 0;" title="Select All Students">
                  <input type="checkbox" id="selectAllStudents" style="position: absolute; opacity: 0; width: 0; height: 0; margin: 0; pointer-events: none;">
                  <span class="custom-select-circle master-select-circle" style="width: 20px; height: 20px; border-radius: 50%; border: 2px solid var(--color-border, #cbd5e1); display: inline-flex; align-items: center; justify-content: center; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); opacity: 0; font-size: 11px; color: #fff; background: transparent;">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" style="display: none;"><polyline points="20 6 9 17 4 12"></polyline></svg>
                  </span>
                </label>
              </th>
              <th class="col-student-id">Student ID</th>
              <th class="col-name">Name</th>
              <th class="col-phone">Phone</th>
              <th>Plan</th>
              <th>Seat</th>
              <th>Expiry Date</th>
              <th class="col-status">Status</th>
              <th>Profile KYC</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${e}
          </tbody>
        </table>
      </div>

      <!-- Mobile Touch-Friendly Card List (visible only on <= 768px via mobile-cards.css) -->
      <div class="mobile-card-list students-mobile-cards">
        ${s}
      </div>
    `,$t(U);const r=U.querySelector("#selectAllStudents"),w=U.querySelectorAll(".student-select-cb"),P=U.querySelector("#bulk-actions-bar"),F=U.querySelector("#selected-count-badge"),y=U.querySelector(".students-table-container");function f(){const i=Array.from(w).filter(d=>d.checked).length;w.forEach(d=>{const l=d.closest("tr");l&&l.classList.toggle("row-selected",d.checked)}),i>0?(P.style.display="flex",F.textContent=`${i} student(s) selected`,y?.classList.add("has-selections"),r&&(r.checked=i===w.length)):(P.style.display="none",y?.classList.remove("has-selections"),r&&(r.checked=!1))}if(r&&r.addEventListener("change",()=>{w.forEach(i=>i.checked=r.checked),f()}),w.forEach(i=>{i.addEventListener("change",()=>{!i.checked&&r&&(r.checked=!1),f()})}),U.querySelector("#btn-bulk-whatsapp")?.addEventListener("click",async()=>{const i=Array.from(w).filter(l=>l.checked).map(l=>l.dataset.id),d=N.students.filter(l=>i.includes(l._id));await st(d,ee,N,z,k,ge,Ne,a)}),U.querySelector("#btn-bulk-renew")?.addEventListener("click",async i=>{const d=Array.from(w).filter(l=>l.checked).map(l=>l.dataset.id);if(d.length!==0&&await Ne.show({title:"Bulk Renew Memberships",message:`Are you sure you want to extend validity by 30 days for ${d.length} selected student(s)?`})){const l=i.currentTarget;De.buttonLoading(l,!0,"Renewing...");try{const p=await z.post("/api/students/bulk-renew",{studentIds:d,days:30});k.success(p.message),await ae.clear("students"),ee(N.pagination.page),fe()}catch(p){k.error(p.message||"Bulk renew failed")}finally{De.buttonLoading(l,!1)}}}),U.querySelector("#btn-bulk-deactivate")?.addEventListener("click",async i=>{const d=Array.from(w).filter(l=>l.checked).map(l=>l.dataset.id);if(d.length!==0&&await Ne.show({title:"Bulk Deactivate",message:`Are you sure you want to mark ${d.length} student(s) as inactive?`,danger:!0})){const l=i.currentTarget;De.buttonLoading(l,!0,"Deactivating...");try{const p=await z.post("/api/students/bulk-deactivate",{studentIds:d});k.success(p.message),await ae.clear("students"),ee(N.pagination.page),fe()}catch(p){k.error(p.message||"Bulk deactivation failed")}finally{De.buttonLoading(l,!1)}}}),U.querySelector("#btn-bulk-export")?.addEventListener("click",()=>{const i=Array.from(w).filter(m=>m.checked).map(m=>m.dataset.id);if(i.length===0)return;const d=N.students.filter(m=>i.includes(m._id)),l=["ID","Name","Phone","Email","Plan","Seat","Expiry","Status"],p=d.map(m=>[m.studentId,`"${m.name}"`,m.phone,m.email||"",m.plan?.name||"",m.seat?.seatNumber||"",m.expiryDate?new Date(m.expiryDate).toLocaleDateString("en-IN"):"",m.status]),S="data:text/csv;charset=utf-8,"+[l.join(","),...p.map(m=>m.join(","))].join(`
`),h=document.createElement("a");h.href=encodeURI(S),h.download=`selected_students_${Date.now()}.csv`,document.body.appendChild(h),h.click(),document.body.removeChild(h),k.success(`Exported ${i.length} students to CSV`)}),N.pagination.pages>1){const i=document.createElement("div");i.className="d-flex justify-content-between align-items-center p-3 border-top";const d=document.createElement("button");d.className="btn btn-sm btn-outline-secondary",d.textContent="Previous",d.disabled=N.pagination.page<=1,d.onclick=()=>ee(N.pagination.page-1);const l=document.createElement("button");l.className="btn btn-sm btn-outline-secondary",l.textContent="Next",l.disabled=N.pagination.page>=N.pagination.pages,l.onclick=()=>ee(N.pagination.page+1);const p=document.createElement("span");p.className="text-muted small",p.textContent=`Page ${N.pagination.page} of ${N.pagination.pages} (${N.pagination.total} total)`,i.appendChild(d),i.appendChild(p),i.appendChild(l),U.appendChild(i)}}let H=null;async function it(){if(H&&Array.isArray(H.branches)&&H.branches.length>0)return Promise.all([z.get("/api/plans").catch(()=>null),z.get("/api/seats?status=available").catch(()=>null),z.get("/api/custom-fields/all").catch(()=>null),z.get("/api/custom-fields/templates/active").catch(()=>null),z.get("/api/branches/public-list").catch(()=>null)]).then(([e,s,r,w,P])=>{e?.data&&(H.plans=e.data),s?.data&&(H.seats=s.data),r?.data&&(H.customFields=r.data),w?.data&&(H.template=w.data),P?.data&&(H.branches=P.data)}).catch(()=>{}),H;try{const[e,s,r,w,P]=await Promise.all([z.get("/api/plans").catch(()=>({data:[]})),z.get("/api/seats?status=available").catch(()=>({data:[]})),z.get("/api/custom-fields/all").catch(()=>({data:[]})),z.get("/api/custom-fields/templates/active").catch(()=>({data:{}})),z.get("/api/branches/public-list").catch(()=>({data:[]}))]);return H={plans:e?.data||[],seats:s?.data||[],customFields:r?.data||[],template:w?.data||{},branches:P?.data||[]},H}catch(e){return console.error("Error fetching student modal dependencies:",e),{plans:[],seats:[],customFields:[],template:{},branches:[]}}}async function we(e=null){let s=!!e;if(e&&e._id)try{const t=await z.get(`/api/students/${e._id}`);t?.data&&(e=t.data)}catch{}const r=await it(),w=Array.isArray(r.plans)?r.plans:[],P=Array.isArray(r.seats)?r.seats:[],F=Array.isArray(r.customFields)?r.customFields:[],y=r.template||{};let f=Array.isArray(r.branches)&&r.branches.length>0?r.branches:window.store?.branches&&window.store.branches.length>0?window.store.branches:[];if(f.length===0)try{const t=await z.get("/api/branches/public-list");t?.data&&Array.isArray(t.data)&&t.data.length>0&&(f=t.data,H&&(H.branches=f))}catch{}let i='<option value="">-- Select Plan (Optional) --</option>',d='<option value="">-- Select Seat (Optional) --</option>',l=P;w.forEach(t=>{const o=e&&e.plan&&(e.plan._id===t._id||e.plan===t._id)?"selected":"",g=Number(t.price)||0,x=Number(t.discount)||0,L=Math.round(t.effectivePrice!==void 0?t.effectivePrice:g*(1-x/100)),I=x>0?` [${x}% OFF, was \u20B9${g.toLocaleString("en-IN")}]`:"";i+=`<option value="${t._id}" data-price="${g}" data-discount="${x}" data-effective="${L}" ${o}>${a(t.name)} - \u20B9${L.toLocaleString("en-IN")} (${t.duration||1} ${t.durationType||"months"})${I}</option>`}),P.forEach(t=>{const o=e&&e.seat&&(e.seat._id===t._id||e.seat===t._id)?"selected":"";d+=`<option value="${t._id}" ${o}>${a(t.seatNumber)} (${a(t.zone)} - ${a(t.type)})</option>`}),e&&e.seat&&typeof e.seat=="object"&&(d.includes(e.seat._id)||(d+=`<option value="${e.seat._id}" selected>${a(e.seat.seatNumber)} (Current)</option>`));function p(t){if(!e)return"";const o=(t||"").toLowerCase().replace(/[^a-z0-9]/g,"");if(o==="branch"||o==="studycentre"||o==="center"||o==="centre")return e.branch?typeof e.branch=="object"&&e.branch._id?String(e.branch._id):String(e.branch):e.customFields&&(e.customFields.branch||e.customFields.studycentre||e.customFields.center)||"";if(e[t]!==void 0&&e[t]!==null&&e[t]!=="")return e[t];if(o==="targetexams"||o==="target_exams"||o==="competitiveexams"||o==="exams")return e.targetExams||e.customFields?.targetExams||e.customFields?.target_exams||"";if(o==="gender")return e.gender||e.customFields?.gender||e.customFields?.Gender||"";if(o==="bloodgroup"||o==="blood"||o==="blood_group")return e.bloodGroup||e.customFields?.bloodGroup||e.customFields?.blood_group||e.customFields?.bloodgroup||e.customFields?.BloodGroup||"";if(o==="occupation"||o==="collegeorcompany"||o==="college_or_company")return e.occupation||e.collegeOrCompany||e.customFields?.occupation||e.customFields?.collegeOrCompany||e.customFields?.college_or_company||"";if(o==="idprooftype"||o==="id_proof_type"||o==="idtype")return e.idProof?.type||e.customFields?.idProofType||e.customFields?.id_proof_type||e.customFields?.idprooftype||"Aadhaar Card";if(o==="idproofnumber"||o==="id_proof_number"||o==="idnumber"||o==="aadhaar"||o==="pan")return e.idProof?.number||e.customFields?.idProofNumber||e.customFields?.id_proof_number||e.customFields?.idproofnumber||e.customFields?.aadhaar||e.customFields?.pan||"";if(o==="idproofimage"||o==="idproof"||o==="id_proof_image")return e.idProof?.image||e.customFields?.idProofImage||e.customFields?.id_proof_image||e.customFields?.idproofimage||"";if(o==="emergencycontactname"||o==="emergency_contact_name"||o==="parentname"||o==="fathername"||o==="parentguardianname"||o==="guardianname"||o==="parentcontactname")return e.emergencyContact?.name||e.customFields?.parent___guardian_name||e.customFields?.parentguardianname||e.customFields?.emergencyContactName||e.customFields?.parentName||e.customFields?.fatherName||e.customFields?.emergency_contact_name||e.customFields?.emergencycontactname||"";if(o==="emergencycontactphone"||o==="emergencycontact"||o==="parentphone"||o==="emergency_contact_phone"||o==="emergencyphone")return e.emergencyContact?.phone||e.customFields?.emergencyContactPhone||e.customFields?.emergencyContact||e.customFields?.emergencycontact||e.customFields?.parentPhone||e.customFields?.emergency_contact_phone||e.customFields?.emergencycontactphone||"";if(o==="emergencycontactrelation"||o==="emergency_contact_relation"||o==="parentrelation"||o==="relation"||o==="relationship")return e.emergencyContact?.relation||e.customFields?.relationship||e.customFields?.relation||e.customFields?.emergencyContactRelation||e.customFields?.parentRelation||e.customFields?.emergency_contact_relation||e.customFields?.emergencycontactrelation||"Parent";if(o==="dateofbirth"||o==="dob"||o==="date_of_birth"||o==="birthdate"){const g=e.dateOfBirth||e.dob||e.customFields&&(e.customFields.dateOfBirth||e.customFields.dob||e.customFields.dateofbirth||(e.customFields instanceof Map?e.customFields.get("dateOfBirth")||e.customFields.get("dob")||e.customFields.get("dateofbirth"):null));if(g){const x=new Date(g);return isNaN(x.getTime())?"":x.toISOString().split("T")[0]}return""}if(o==="address")return e.address||e.customFields?.address||"";if(o==="city")return e.city||e.customFields?.city||"";if(o==="state")return e.state||e.customFields?.state||"";if(o==="pincode")return e.pincode||e.customFields?.pincode||"";if(e.customFields){if(e.customFields instanceof Map){if(e.customFields.has(t))return e.customFields.get(t)||"";for(const[g,x]of e.customFields.entries())if(g.toLowerCase().replace(/[^a-z0-9]/g,"")===o)return x||""}else if(typeof e.customFields=="object"){if(e.customFields[t]!==void 0&&e.customFields[t]!==null)return e.customFields[t];for(const[g,x]of Object.entries(e.customFields))if(g.toLowerCase().replace(/[^a-z0-9]/g,"")===o)return x||""}}return""}const S=y.sections&&y.sections.length>0?y.sections.filter(t=>!t.isHidden).sort((t,o)=>(t.order||0)-(o.order||0)):[{name:"personal",label:"Personal & Contact Details",icon:"personal"},{name:"academic",label:"Academic Goals & KYC Verification",icon:"academic"},{name:"seat",label:"Declaration & Signature",icon:"seat"}],h=new Set(s?[]:["name","phone","plan","seat","status","paymentmode","payment_mode"]),m=new Set(["plan","seat","status","notes","rfidCardNumber","biometricId","paymentMode","payment_mode"]),D=[];(F||[]).forEach(t=>{if(t.isActive===!1)return;const o=(t.fieldName||"").trim().toLowerCase();o&&(m.has(t.fieldName)||h.has(o)||(h.add(o),D.push(t)))}),D.sort((t,o)=>(t.order||0)-(o.order||0));const T=D.some(t=>{const o=(t.fieldName||"").toLowerCase().replace(/[^a-z0-9]/g,"");return o==="branch"||o==="studycentre"||o==="center"||o==="centre"||t.type==="branch"}),_=new Map,M={personal:"\u{1F464}",academic:"\u{1F3AF}",plan:"\u23F0",payment:"\u{1F4B3}",seat:"\u{1FA91}",contact:"\u{1F4CD}",kyc:"\u{1FAAA}",address:"\u{1F4CD}"};S.forEach(t=>{_.set(t.name,{key:t.name,label:t.label,icon:M[t.icon]||(t.icon&&t.icon.length<=4?t.icon:"")||"\u{1F4DD}",fields:[]})}),D.forEach(t=>{const o=t.section||"personal";if(_.has(o))_.get(o).fields.push(t);else{const g=_.values().next().value;g&&g.fields.push(t)}});function b(t){const o=p(t.fieldName),g=t.required?' <span class="text-danger">*</span>':"",x=t.type==="textarea"||t.type==="address_autocomplete"||t.type==="aadhaar_pan"||t.type==="exam_badge"||t.type==="signature_pad"||t.colSpan===12||t.colSpan===2?"col-12":"col-md-6",L=t.showIf||(t.conditional?.enabled?{field:t.conditional.dependsOn,operator:t.conditional.operator||"equals",value:t.conditional.showWhen}:null),I=L?`data-depends-on="${a(L.field)}" data-show-when="${a(L.value||"")}" data-operator="${a(L.operator||"equals")}" style="display:none;"`:"",j=t.helpText?`<small class="text-muted d-block" style="font-size: 0.72rem; margin-top: 3px;">${a(t.helpText)}</small>`:"";if(t.type==="photo_upload")return`
          <div class="col-12 mt-2 dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 600;">\u{1F4F7} ${a(t.label)}${g}</label>
            <div id="mount-student-photo" class="custom-media-mount" data-field="${a(t.fieldName)}" data-preset="passport" data-label="${a(t.label)}"></div>
            ${j}
          </div>
        `;if(t.type==="signature_pad")return`
          <div class="col-12 mt-2 dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 600;">\u270D\uFE0F ${a(t.label)}${g}</label>
            <div id="admission-signature-studio-mount"></div>
            ${j}
          </div>
        `;if(t.type==="aadhaar_pan"){const E=String(p("idProofType")||"").toLowerCase();return`
          <div class="col-12 mt-2 dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 600;">\u{1F4D1} ${a(t.label)}${g}</label>
            <div class="row g-2 mb-2" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 10px;">
              <div>
                <label class="form-label text-xs">ID Proof Type</label>
                <select class="form-select form-control" name="idProof.type">
                  <option value="Aadhaar Card" ${E.includes("aadhaar")||E===""?"selected":""}>Aadhaar Card</option>
                  <option value="PAN Card" ${E.includes("pan")?"selected":""}>PAN Card</option>
                  <option value="Driving License" ${E.includes("driving")?"selected":""}>Driving License</option>
                  <option value="Voter ID" ${E.includes("voter")?"selected":""}>Voter ID</option>
                  <option value="Passport" ${E.includes("passport")?"selected":""}>Passport</option>
                  <option value="Student / College ID" ${E.includes("student")||E.includes("college")?"selected":""}>Student / College ID</option>
                  <option value="Other Govt ID" ${E.includes("other")||E.includes("govt")?"selected":""}>Other Govt ID</option>
                </select>
              </div>
              <div>
                <label class="form-label text-xs">ID Document Number</label>
                <input type="text" class="form-control" name="idProof.number" value="${a(p("idProofNumber"))}" placeholder="Enter card / document number">
              </div>
            </div>
            <div id="mount-student-idproof" class="custom-media-mount" data-field="idProofImage" data-preset="document" data-label="ID Proof Document Upload"></div>
            ${j}
          </div>
        `}if(t.type==="address_autocomplete")return`
          <div class="col-12 mt-2 dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 600;">\u{1F4CD} ${a(t.label)}${g}</label>
            <textarea class="form-control custom-dyn-input mb-2" name="address" data-field="address" rows="2" placeholder="Full residential street address">${a(p("address"))}</textarea>
            <div class="row g-2" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 95px), 1fr)); gap: 8px;">
              <div>
                <input type="text" class="form-control custom-dyn-input" name="pincode" data-field="pincode" value="${a(p("pincode"))}" placeholder="Pincode" maxlength="6">
              </div>
              <div>
                <input type="text" class="form-control custom-dyn-input" name="city" data-field="city" value="${a(p("city"))}" placeholder="City">
              </div>
              <div>
                <input type="text" class="form-control custom-dyn-input" name="state" data-field="state" value="${a(p("state"))}" placeholder="State">
              </div>
            </div>
            ${j}
          </div>
        `;if(t.type==="exam_badge"){const E=t.options&&t.options.length>0?t.options:["UPSC","MPSC","Banking / IBPS","SSC CGL","JEE / NEET","CA / CS","GATE","UGC NET","State PSC","Law / CLAT","Defence / NDA","Other"],B=p(t.fieldName),u=Array.isArray(B)?B:typeof B=="string"?B.split(",").map(G=>G.trim()).filter(Boolean):[];return`
          <div class="col-12 mt-2 dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 600;">\u{1F3AF} ${a(t.label)}${g}</label>
            <div id="exam-chips-container" style="display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px;">
              ${E.map(G=>`
                  <button type="button" class="btn btn-sm exam-chip-btn ${u.some(me=>String(me).toLowerCase().trim()===String(G).toLowerCase().trim())?"btn-primary":"btn-outline-secondary"}" data-exam="${G}" style="border-radius: 16px; font-size: 0.8rem; padding: 3px 10px;">
                    ${G}
                  </button>
                `).join("")}
            </div>
            <input type="hidden" name="targetExams" id="selectedTargetExams" value="${a(u.join(","))}">
            ${j}
          </div>
        `}if(t.type==="blood_group"){const E=["A+","A-","B+","B-","O+","O-","AB+","AB-"],B=String(o||"").toUpperCase().trim();return`
          <div class="${x} dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 500;">\u{1FA78} ${a(t.label)}${g}</label>
            <select class="form-select form-control custom-dyn-input" data-field="${a(t.fieldName)}" name="${a(t.fieldName)}" ${t.required?"required":""}>
              <option value="">-- Select Blood Group --</option>
              ${E.map(u=>`<option value="${u}" ${B===u?"selected":""}>${u}</option>`).join("")}
            </select>
            ${j}
          </div>
        `}if(t.type==="star_rating"){const E=parseInt(o,10)||5;return`
          <div class="${x} dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 500;">\u2B50 ${a(t.label)}${g}</label>
            <div class="star-rating-wrap modal-star-rating" data-field="${a(t.fieldName)}" style="display: inline-flex; gap: 6px; font-size: 1.4rem; cursor: pointer;">
              ${[1,2,3,4,5].map(B=>`<span class="star-rating-item ${B<=E?"active":""}" data-val="${B}" style="color: ${B<=E?"var(--color-warning)":"#d1d5db"};">\u2605</span>`).join("")}
            </div>
            <input type="hidden" class="custom-dyn-input" data-field="${a(t.fieldName)}" name="${a(t.fieldName)}" value="${E}">
            ${j}
          </div>
        `}if(t.type==="file")return`
          <div class="${x} mt-2 dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 500;">\u{1F4CE} ${a(t.label)}${g}</label>
            <div class="custom-field-media-mount" data-field="${a(t.fieldName)}" data-label="${a(t.label)}" data-preset="document"></div>
            ${j}
          </div>
        `;const Q=(t.fieldName||"").toLowerCase().replace(/[^a-z0-9]/g,"");if(Q==="branch"||Q==="studycentre"||Q==="centre"||Q==="center"||t.type==="branch"){const E=String(o||"").trim().toLowerCase();let B='<option value="">-- Select Study Centre / Branch --</option>';return(f||[]).forEach(u=>{const G=String(u._id||u.id||""),me=u.name||"Main Campus",Le=u.city?` (${u.city})`:"",Ie=E&&E===G.toLowerCase()||E&&E===me.toLowerCase();B+=`<option value="${a(G)}" ${Ie?"selected":""}>${a(me+Le)}</option>`}),`
          <div class="${x} dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 600;">\u{1F3DB}\uFE0F ${a(t.label||"Preferred Study Centre / Branch")}${g}</label>
            <select class="form-select form-control custom-dyn-input" data-field="branch" name="branch" ${t.required?"required":""}>
              ${B}
            </select>
            ${j}
          </div>
        `}if(t.type==="select"){const E=String(o||"").toLowerCase().trim();return`
          <div class="${x} dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 500;">${a(t.label)}${g}</label>
            <select class="form-select form-control custom-dyn-input" data-field="${a(t.fieldName)}" name="${a(t.fieldName)}" ${t.required?"required":""}>
              <option value="">-- Select --</option>
              ${(t.options||[]).map(B=>`<option value="${a(B)}" ${E===String(B).toLowerCase().trim()?"selected":""}>${a(B)}</option>`).join("")}
            </select>
            ${j}
          </div>
        `}if(t.type==="radio"){const E=String(o||"").toLowerCase().trim();return`
          <div class="${x} dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 500;">${a(t.label)}${g}</label>
            <div style="display: flex; gap: 12px; flex-wrap: wrap; margin-top: 4px;">
              ${(t.options||[]).map(B=>`
                <label style="display: inline-flex; align-items: center; gap: 4px; font-size: 0.88rem; cursor: pointer;">
                  <input type="radio" class="custom-dyn-radio" name="${a(t.fieldName)}" data-field="${a(t.fieldName)}" value="${a(B)}" ${E===String(B).toLowerCase().trim()?"checked":""}>
                  ${a(B)}
                </label>
              `).join("")}
            </div>
            ${j}
          </div>
        `}if(t.type==="checkbox"||t.type==="terms_checkbox"||t.type==="consent_checkbox"){const E=o===!0||o==="true"||o==="on"||o===1;return`
          <div class="col-12 mt-1 dynamic-field-wrapper" ${I}>
            <label class="form-check" style="display: inline-flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
              <input type="checkbox" class="form-checkbox custom-dyn-checkbox" name="${a(t.fieldName)}" data-field="${a(t.fieldName)}" ${E?"checked":""} ${t.required?"required":""}>
              <span class="form-label mb-0" style="font-size: 0.88rem; font-weight: 500;">${a(t.label)}${g}</span>
            </label>
            ${j}
          </div>
        `}if(t.type==="textarea")return`
          <div class="col-12 dynamic-field-wrapper" ${I}>
            <label class="form-label" style="font-weight: 500;">${a(t.label)}${g}</label>
            <textarea class="form-control custom-dyn-input" data-field="${a(t.fieldName)}" name="${a(t.fieldName)}" placeholder="${a(t.placeholder||"")}" rows="2" ${t.required?"required":""}>${a(o)}</textarea>
            ${j}
          </div>
        `;const n=t.type==="phone"?"tel":t.type==="date"?"date":t.type==="time"?"time":t.type==="number"?"number":t.type==="email"?"email":"text";return`
        <div class="${x} dynamic-field-wrapper" ${I}>
          <label class="form-label" style="font-weight: 500;">${a(t.label)}${g}</label>
          <input type="${n}" class="form-control custom-dyn-input" data-field="${a(t.fieldName)}" name="${a(t.fieldName)}" value="${a(o)}" placeholder="${a(t.placeholder||"")}" ${t.required?"required":""}>
          ${j}
        </div>
      `}let v="";_.forEach(t=>{t.fields.length!==0&&(v+=`
        <div class="col-12 mt-3 mb-1" style="border-top: 1px solid var(--color-border); padding-top: 10px;">
          <h5 style="font-size: 1rem; font-weight: 700; color: var(--color-primary); margin-bottom: 8px; display: flex; align-items: center; gap: 8px;">
            <span>${t.icon||"\u{1F4DD}"}</span>
            <span>${a(t.label)}</span>
          </h5>
        </div>
        ${t.fields.map(o=>b(o)).join("")}
      `)});const C=s?`
      <form id="studentForm">
        <div class="row" style="row-gap: 12px;">
          <!-- Dynamically Grouped Form Sections -->
          ${v}

          <!-- Administrative & Membership Allotment Section Card -->
          <div class="col-12 mt-3" style="border-top: 2px dashed var(--color-primary); padding-top: 12px; background: rgba(108, 92, 231, 0.04); border-radius: var(--radius-md); padding: 14px;">
            <h5 style="font-size: 1rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
              <span>\u{1F3DB}\uFE0F</span>
              <span>Administrative & Membership Allotment</span>
            </h5>
            
            <div class="row" style="row-gap: 12px;">
              ${T?"":`
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">\u{1F3DB}\uFE0F Preferred Study Centre / Branch</label>
                <select class="form-select form-control custom-dyn-input" data-field="branch" name="branch">
                  <option value="">-- Select Study Centre / Branch --</option>
                  ${f.map(t=>{const o=String(t._id||t.id||""),g=t.name||"Main Campus",x=t.city?` (${t.city})`:"",L=String(p("branch")||"").trim().toLowerCase(),I=L&&L===o.toLowerCase()||L&&L===g.toLowerCase();return`<option value="${a(o)}" ${I?"selected":""}>${a(g+x)}</option>`}).join("")}
                </select>
              </div>
              `}

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">Membership Plan</label>
                <select class="form-select form-control" name="plan">
                  ${i}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">Assigned Study Desk / Seat</label>
                <select class="form-select form-control" name="seat">
                  ${d}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">Membership Status</label>
                <select class="form-select form-control" name="status">
                  <option value="active" ${!e||e.status==="active"?"selected":""}>\u{1F7E2} Active</option>
                  <option value="inactive" ${e&&e.status==="inactive"?"selected":""}>\u{1F534} Inactive</option>
                  <option value="suspended" ${e&&e.status==="suspended"?"selected":""}>\u{1F7E1} Suspended</option>
                  <option value="expired" ${e&&e.status==="expired"?"selected":""}>\u26AA Expired</option>
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">\u{1F3F7}\uFE0F RFID Smart Card UID</label>
                <input type="text" class="form-control" name="rfidCardNumber" value="${e&&e.rfidCardNumber?a(e.rfidCardNumber):""}" placeholder="Scan card or enter Hex/DEC UID">
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">\u{1F464} Biometric / Machine ID</label>
                <input type="text" class="form-control" name="biometricId" value="${e&&e.biometricId?a(e.biometricId):""}" placeholder="e.g. BIO-101 / Finger ID">
              </div>

              <div class="col-12">
                <label class="form-label" style="font-weight: 600;">Special Remarks / Admin Notes</label>
                <textarea class="form-control" name="notes" rows="2" placeholder="Any health conditions, locker preference, discount notes, etc.">${e&&e.notes?a(e.notes):""}</textarea>
              </div>
            </div>
          </div>
        </div>
      </form>
    `:`
      <form id="studentForm">
        <div class="row" style="row-gap: 12px;">
          
          <!-- \u{1F680} 10-Second Express Walk-in Card (Placed Right at Top for Instant Admission) -->
          <div class="col-12" style="background: rgba(108, 92, 231, 0.08); border: 1.5px solid var(--color-primary); border-radius: var(--radius-lg); padding: 1.25rem; box-shadow: var(--shadow-xs);">
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; flex-wrap: wrap; gap: 8px;">
              <h5 style="margin: 0; font-size: 1.05rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                <span>\u{1F680}</span> 10-Second Express Walk-in Admission
              </h5>
              <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.75rem;">Fast Entry Mode</span>
            </div>

            <div class="row" style="row-gap: 12px;">
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Full Student Name *</label>
                <input type="text" class="form-control custom-dyn-input" name="name" data-field="name" value="${a(p("name"))}" placeholder="e.g. Rahul Sharma" required style="font-weight: 600;">
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Mobile Number (WhatsApp) *</label>
                <input type="tel" class="form-control custom-dyn-input" name="phone" data-field="phone" value="${a(p("phone"))}" placeholder="10-digit mobile (e.g. 9876543210)" required style="font-weight: 600;">
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Select Membership Plan *</label>
                <select class="form-select form-control" name="plan" style="font-weight: 600;">
                  ${i}
                </select>
              </div>

              ${T?"":`
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Select Study Centre / Branch</label>
                <select class="form-select form-control custom-dyn-input" data-field="branch" name="branch" style="font-weight: 600;">
                  <option value="">-- Select Study Centre / Branch --</option>
                  ${f.map(t=>{const o=String(t._id||t.id||""),g=t.name||"Main Campus",x=t.city?` (${t.city})`:"",L=String(p("branch")||"").trim().toLowerCase(),I=L&&L===o.toLowerCase()||L&&L===g.toLowerCase();return`<option value="${a(o)}" ${I?"selected":""}>${a(g+x)}</option>`}).join("")}
                </select>
              </div>
              `}

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Select Reserved Study Desk / Seat</label>
                <select class="form-select form-control" name="seat" style="font-weight: 600;">
                  ${d}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Membership Status</label>
                <select class="form-select form-control" name="status" style="font-weight: 600;">
                  <option value="active" selected>\u{1F7E2} Active (Instant Access)</option>
                  <option value="pending_payment">\u{1F7E1} Pending Cash Payment</option>
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Payment Mode Collected</label>
                <select class="form-select form-control" name="paymentMode" id="adminStudentPaymentMode" style="font-weight: 600;">
                  <option value="cash" selected>\u{1F4B5} Cash at Reception Desk</option>
                  <option value="upi">\u26A1 Direct UPI (GPay / PhonePe / Paytm / BHIM)</option>
                  <option value="bank_transfer">\u{1F3DB}\uFE0F Bank Transfer (NEFT / IMPS / RTGS)</option>
                  <option value="card">\u{1F4B3} Debit / Credit Card (POS Terminal)</option>
                  <option value="desk">\u{1F4B5} Pay Later at Front Desk</option>
                  <option value="netbanking">\u{1F3E6} NetBanking / Online Transfer</option>
                </select>
              </div>

              <div class="col-12" id="adminStudentPaymentContext"></div>

              <div class="col-md-6" id="adminStudentTxnWrapper">
                <label class="form-label" id="adminStudentTxnLabel" style="font-weight: 600;">\u{1F4B5} Cash Collector Note (Optional)</label>
                <input type="text" class="form-control" name="transactionId" id="adminStudentTxnInput" placeholder="e.g. Cash received at reception desk" value="${e&&e.transactionId?a(e.transactionId):""}">
                <small id="adminStudentUtrWarn" class="text-danger" style="display: none; font-size: 0.75rem; margin-top: 3px; font-weight: 600;"></small>
              </div>
            </div>
          </div>

          <!-- Collapsible Accordion: Optional Extended Details (KYC Photo, Guardian Contact, Address & RFID) -->
          <div class="col-12 mt-2">
            <details style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 12px 16px;">
              <summary style="cursor: pointer; font-weight: 700; font-size: 0.9rem; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                <span>\u2795 Optional Extended Details (KYC Photo, Guardian Contact, Address & RFID)</span>
              </summary>
              <div class="row mt-3" style="row-gap: 12px;">
                ${v}

                <div class="col-md-6">
                  <label class="form-label" style="font-weight: 600;">\u{1F3F7}\uFE0F RFID Smart Card UID</label>
                  <input type="text" class="form-control" name="rfidCardNumber" value="${e&&e.rfidCardNumber?a(e.rfidCardNumber):""}" placeholder="Scan card or enter Hex/DEC UID">
                </div>

                <div class="col-md-6">
                  <label class="form-label" style="font-weight: 600;">\u{1F464} Biometric / Machine ID</label>
                  <input type="text" class="form-control" name="biometricId" value="${e&&e.biometricId?a(e.biometricId):""}" placeholder="e.g. BIO-101 / Finger ID">
                </div>

                <div class="col-12">
                  <label class="form-label" style="font-weight: 600;">Special Remarks / Admin Notes</label>
                  <textarea class="form-control" name="notes" rows="2" placeholder="Any health conditions, locker preference, discount notes, etc.">${e&&e.notes?a(e.notes):""}</textarea>
                </div>
              </div>
            </details>
          </div>

        </div>
      </form>
    `;let R=null;const $=new ge({title:s?"Edit Student Details":"Add New Student Admission",content:C,size:"lg",buttons:[{text:"Cancel",className:"btn-secondary",onClick:t=>t.close()},{text:s?"Update Student":"Save Admission",className:"btn-primary",onClick:async t=>{const o=t.element.querySelector("#studentForm");if(!o)return;const g=o.querySelector('[name="name"]'),x=o.querySelector('[name="phone"]'),L=g?.value?.trim();if(!L||L.length<2){k.warning("Please enter a valid Student Full Name (minimum 2 characters)"),g?.focus();return}let I=x?.value?.trim().replace(/[^0-9+]/g,"")||"";if(!I){k.warning("Please enter the Mobile Number (WhatsApp)"),x?.focus();return}I.startsWith("0")&&I.length===11&&(I=I.slice(1));const j=I.replace(/[^0-9]/g,"");if(j.length<10||!/^[6-9]\d{9}$/.test(j.slice(-10))){k.warning("Please enter a valid 10-digit Indian mobile number (starting with 6, 7, 8, or 9)"),x?.focus();return}const Q=new FormData(o),n=Object.fromEntries(Q.entries());n.name=L,n.phone=I;const E=t.element.querySelector("#selectedTargetExams"),B=E?E.value:n.targetExams||"";n.targetExams=B?Array.isArray(B)?B:String(B).split(",").map(O=>O.trim()).filter(Boolean):[],n.customFields={},t.element.querySelectorAll(".custom-dyn-input").forEach(O=>{const ce=O.dataset.field||O.name;ce&&(O.type==="checkbox"?n.customFields[ce]=O.checked:n.customFields[ce]=O.value)}),t.element.querySelectorAll(".custom-dyn-radio:checked").forEach(O=>{const ce=O.dataset.field||O.name;ce&&(n.customFields[ce]=O.value)}),t.element.querySelectorAll(".custom-field-media-mount").forEach(O=>{const ce=O.dataset.field,at=O.querySelector(".mfp-hidden-value")?.value||"";at&&(n.customFields[ce]=at)});const u=n.customFields||{},G=(o.querySelector('[name="branch"]')||t.element.querySelector('[name="branch"]')||t.element.querySelector('[data-field="branch"]'))?.value||n.branch||u.branch||e&&(e.branch?._id||e.branch)||"";G&&String(G).trim()?(n.branch=String(G).trim(),n.customFields.branch=n.branch):delete n.branch;const me=n.bloodGroup||n.blood_group||n.bloodgroup||u.bloodGroup||u.blood_group||u.bloodgroup||u.BloodGroup||e?.bloodGroup||"";me&&(n.bloodGroup=String(me).trim(),n.customFields.bloodGroup=n.bloodGroup,n.customFields.bloodgroup=n.bloodGroup);const Le=n.gender||u.gender||u.Gender||e?.gender||"";Le&&(n.gender=String(Le).toLowerCase().trim());const Ie=n.occupation||n.collegeOrCompany||n.college_or_company||u.occupation||u.collegeOrCompany||u.college_or_company||e?.occupation||e?.collegeOrCompany||"";Ie&&(n.occupation=String(Ie).trim(),n.collegeOrCompany=n.occupation,n.customFields.occupation=n.occupation);const Je=n.address||u.address||e?.address||"";Je&&(n.address=String(Je).trim());const Xe=n.city||u.city||e?.city||"";Xe&&(n.city=String(Xe).trim());const Qe=n.state||u.state||e?.state||"";Qe&&(n.state=String(Qe).trim());const Ze=n.pincode||u.pincode||e?.pincode||"";Ze&&(n.pincode=String(Ze).trim());const et=t.element.querySelector("#mount-student-photo .mfp-hidden-value")?.value;et!==void 0&&(n.photo=et);const tt=t.element.querySelector("#mount-student-idproof .mfp-hidden-value")?.value;tt!==void 0&&(n.idProofImage=tt);const lt=n.idProofType||n["idProof.type"]||n["idProof[type]"]||n.id_proof_type||n.idprooftype||n.idType||u.idProofType||u.idprooftype||u.id_proof_type||e?.idProof?.type||"Aadhaar Card",dt=n.idProofNumber||n["idProof.number"]||n["idProof[number]"]||n.id_proof_number||n.idproofnumber||n.idNumber||n.aadhaar||n.pan||u.idProofNumber||u.idproofnumber||u.id_proof_number||u.aadhaar||u.pan||e?.idProof?.number||"",ct=n.idProofImage||n["idProof.image"]||n["idProof[image]"]||n.id_proof_image||n.idproofimage||u.idProofImage||u.idproofimage||e?.idProof?.image||"";n.idProof={type:String(lt).trim(),number:String(dt).trim(),image:String(ct).trim()},n.customFields.idProofType=n.idProof.type,n.customFields.idprooftype=n.idProof.type,n.customFields.idProofNumber=n.idProof.number,n.customFields.idproofnumber=n.idProof.number,n.customFields.idProofImage=n.idProof.image,n.customFields.idproofimage=n.idProof.image,delete n["idProof.type"],delete n["idProof.number"],delete n["idProof.image"],delete n.idProofType,delete n.idProofNumber,delete n.idProofImage;const pt=n.emergencyContactName||n["emergencyContact.name"]||n["emergencyContact[name]"]||n.parentName||n.parent___guardian_name||n.parent_name||n.parentguardianname||n.guardianName||n.fatherName||u.parent___guardian_name||u.parentguardianname||u.guardianName||u.emergencyContactName||u.parentName||u.fatherName||u.emergency_contact_name||u.emergencycontactname||e?.emergencyContact?.name||"",ut=n.emergencyContactPhone||n["emergencyContact.phone"]||n["emergencyContact[phone]"]||n.emergencyContact||n.emergencycontact||n.parentPhone||n.parent_phone||u.emergencyContactPhone||u.emergencyContact||u.emergencycontact||u.parentPhone||u.emergency_contact_phone||u.emergencycontactphone||e?.emergencyContact?.phone||"",mt=n.emergencyContactRelation||n["emergencyContact.relation"]||n["emergencyContact[relation]"]||n.relationship||n.relation||n.parentRelation||n.parent_relation||u.relationship||u.relation||u.emergencyContactRelation||u.parentRelation||u.emergency_contact_relation||u.emergencycontactrelation||e?.emergencyContact?.relation||"Parent";if(n.emergencyContact={name:String(pt).trim(),phone:String(ut).trim().replace(/[^0-9+]/g,""),relation:String(mt).trim()},n.customFields.emergencyContact=n.emergencyContact.phone,n.customFields.emergencycontact=n.emergencyContact.phone,n.customFields.emergencyContactPhone=n.emergencyContact.phone,n.customFields.emergencycontactphone=n.emergencyContact.phone,n.customFields.parent___guardian_name=n.emergencyContact.name,n.customFields.parentguardianname=n.emergencyContact.name,n.customFields.emergencyContactName=n.emergencyContact.name,n.customFields.emergencycontactname=n.emergencyContact.name,n.customFields.relationship=n.emergencyContact.relation,n.customFields.relation=n.emergencyContact.relation,n.customFields.emergencyContactRelation=n.emergencyContact.relation,n.customFields.emergencycontactrelation=n.emergencyContact.relation,delete n["emergencyContact.name"],delete n["emergencyContact.phone"],delete n["emergencyContact.relation"],delete n.emergencyContactName,delete n.emergencyContactPhone,delete n.emergencyContactRelation,R){const O=R.getValue();O&&(n.signature=O)}n.plan||delete n.plan,n.seat||delete n.seat;const ke=n.dateOfBirth||n.dob||n.dateofbirth||n.date_of_birth||n.birthDate||n.birthdate||u.dateOfBirth||u.dob||u.dateofbirth||u.date_of_birth||u.birthDate||u.birthdate||e?.dateOfBirth;if(ke?(n.dateOfBirth=ke,n.customFields.dateOfBirth=ke,n.customFields.dob=ke,n.customFields.dateofbirth=ke):delete n.dateOfBirth,delete n.dob,delete n.dateofbirth,delete n.date_of_birth,delete n.birthDate,delete n.birthdate,n.email&&n.email.trim()&&!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(n.email.trim())){k.warning("Please enter a valid email address (e.g. name@example.com)");return}if(n.pincode&&n.pincode.trim()&&!/^[1-9][0-9]{5}$/.test(n.pincode.trim())){k.warning("Please enter a valid 6-digit Indian Postal PIN code (e.g. 411001)");return}if(n.idProof.number&&n.idProof.number.trim()){const O=be.validateGovernmentID(n.idProof.type,n.idProof.number.trim());if(!O.isValid){k.warning(O.message);return}}if(n.emergencyContact.phone&&n.emergencyContact.phone.trim()){const O=n.emergencyContact.phone.trim().replace(/[^0-9]/g,"");if(O.length<10||!/^[6-9]\d{9}$/.test(O.slice(-10))){k.warning("Please enter a valid 10-digit mobile number for Emergency Contact");return}if(O.slice(-10)===j.slice(-10)){k.warning("Emergency Contact number cannot be identical to the student\u2019s own mobile number. Please provide a Parent / Guardian contact number.");return}}const gt=e?.status,bt=e?.seat;try{await ot.execute({applyState:()=>{s&&e&&(n.status&&(e.status=n.status),"seat"in n&&(e.seat=n.seat?{_id:n.seat}:null),ye())},rollbackState:()=>{s&&e&&(e.status=gt,e.seat=bt,ye())},apiCall:()=>s?z.put(`/api/students/${e._id}`,n):z.post("/api/students",n),onSuccess:async O=>{k.success(O.message||"Student saved successfully"),!s&&typeof window.confettiCelebrate=="function"&&window.confettiCelebrate({duration:2500}),typeof window.refreshNotifications=="function"&&window.refreshNotifications(),t.close(),await ae.clear("students"),fe(),ee(N.pagination.page)}})}catch{}}}]});$.open();const W=$.element.querySelector('input[name="name"]');W&&ue.attachLiveValidation(W,t=>ue.text(t,2,100,"Student Name",!0));const q=$.element.querySelector('input[name="phone"]');q&&ue.attachLiveValidation(q,t=>ue.phone(t,!0));const V=$.element.querySelector('input[name="email"]');V&&ue.attachLiveValidation(V,t=>ue.email(t,!1));const $e=$.element.querySelector('input[name="emergencyContact.phone"], input[name="emergencyContactPhone"]');$e&&ue.attachLiveValidation($e,t=>ue.phone(t,!1));const ne=$.element.querySelector("#mount-student-photo");ne&&ne.appendChild(je.create({label:"Student Passport Photo",preset:"passport",name:"photo",value:e?.photo||""}));const Fe=$.element.querySelector("#mount-student-idproof");Fe&&Fe.appendChild(je.create({label:"ID Proof Document Scan / Photo",preset:"document",name:"idProofImage",value:e?.idProof?.image||""})),$.element.querySelectorAll(".custom-field-media-mount").forEach(t=>{const o=t.dataset.field,g=t.dataset.label,x=t.dataset.preset,L=e?.customFields?.[o]||"";t.appendChild(je.create({label:g,preset:x,name:o,value:L}))}),be&&typeof be.bindDynamicIDProofValidation=="function"&&be.bindDynamicIDProofValidation($.element);const he=$.element.querySelector("#adminStudentPaymentMode"),te=$.element.querySelector("#adminStudentPaymentContext"),J=$.element.querySelector("#adminStudentTxnLabel"),Y=$.element.querySelector("#adminStudentTxnInput"),le=$.element.querySelector("#adminStudentUtrWarn"),ve=()=>{const t=he?.value||"cash",o=window.store?.settings?.businessProfile?.upiId||window.store?.profile?.upiId||"";t==="cash"||t==="desk"?(J&&(J.innerHTML="\u{1F4B5} Cash / Front Desk Note (Optional)"),Y&&(Y.placeholder="e.g. Received at reception desk"),te&&(te.innerHTML=`
            <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4B5}</span>
              <span><strong>Cash / Desk Admission:</strong> Instant membership activation. No online transaction reference required.</span>
            </div>
          `),le&&(le.style.display="none")):t==="bank_transfer"||t==="netbanking"?(J&&(J.innerHTML="\u{1F3DB}\uFE0F Bank NEFT / IMPS / RTGS Reference Number"),Y&&(Y.placeholder="e.g. Bank Reference / UTR Number"),te&&(te.innerHTML=`
            <div style="background: rgba(9, 132, 227, 0.1); border: 1px solid #0984e3; border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F3DB}\uFE0F</span>
              <span><strong>Bank Transfer:</strong> Direct deposit / IMPS into library account.</span>
            </div>
          `),le&&(le.style.display="none")):t==="card"?(J&&(J.innerHTML="\u{1F4B3} POS Slip Code / Card Last 4 Digits"),Y&&(Y.placeholder="e.g. POS Auth Code #8492 or Card Ending 4321"),te&&(te.innerHTML=`
            <div style="background: rgba(225, 112, 85, 0.1); border: 1px solid #e17055; border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4B3}</span>
              <span><strong>Card Payment:</strong> Processed on POS terminal.</span>
            </div>
          `),le&&(le.style.display="none")):(J&&(J.innerHTML="\u26A1 UPI / 12-Digit UTR Transaction ID"),Y&&(Y.placeholder="e.g. 12-digit UTR (e.g. 423456789012)"),te&&(te.innerHTML=`
            <div style="background: rgba(108, 92, 231, 0.1); border: 1px solid var(--color-primary, #6c5ce7); border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 6px;">
              <span>\u{1F4F1} <strong>UPI Payment:</strong> GPay, PhonePe, Paytm, BHIM.</span>
              ${o?`<span class="badge" style="background: var(--color-primary); color: #fff; font-family: monospace; font-size: 0.75rem;">UPI: ${a(o)}</span>`:""}
            </div>
          `))};he&&(he.addEventListener("change",ve),ve());const A=$.element.querySelector("#admission-signature-studio-mount");A&&(R=new yt(A,{value:e?.signature,studentName:e?.name,width:500,height:140}));const c=$.element.querySelector("#exam-chips-container"),oe=$.element.querySelector("#selectedTargetExams");if(c&&oe){let t=new Set(oe.value?oe.value.split(","):[]);c.querySelectorAll(".exam-chip-btn").forEach(o=>{o.addEventListener("click",()=>{const g=o.dataset.exam;t.has(g)?(t.delete(g),o.classList.remove("btn-primary"),o.classList.add("btn-outline-secondary")):(t.add(g),o.classList.remove("btn-outline-secondary"),o.classList.add("btn-primary")),oe.value=Array.from(t).join(",")})})}$.element.querySelectorAll(".modal-star-rating").forEach(t=>{const o=t.querySelectorAll(".star-rating-item"),g=t.nextElementSibling;o.forEach(x=>{x.addEventListener("click",()=>{const L=parseInt(x.dataset.val,10);g&&(g.value=L),o.forEach((I,j)=>{j<L?(I.classList.add("active"),I.style.color="var(--color-warning)"):(I.classList.remove("active"),I.style.color="#d1d5db")})})})});function Se(){const t=$.element.querySelector("#studentForm");if(!t)return;const o=new FormData(t),g=Object.fromEntries(o.entries());$.element.querySelectorAll(".custom-dyn-input, .custom-dyn-radio").forEach(x=>{const L=x.dataset.field||x.name;L&&(x.type==="checkbox"?g[L]=x.checked:x.type==="radio"?x.checked&&(g[L]=x.value):x.value&&(g[L]=x.value))}),$.element.querySelectorAll(".dynamic-field-wrapper").forEach(x=>{const L=x.dataset.dependsOn,I=x.dataset.showWhen,j=x.dataset.operator||"equals";if(L&&I){const Q=g[L],n=Q!==void 0?String(Q).trim():"",E=String(I).trim();let B=!1;const u=Q===!0||Q==="true"||Q==="on";j==="equals"?B=n.toLowerCase()===E.toLowerCase()||u&&E.toLowerCase()==="true":j==="not_equals"?B=n.toLowerCase()!==E.toLowerCase():j==="contains"?B=n.toLowerCase().includes(E.toLowerCase()):j==="is_checked"?B=u:j==="is_not_checked"?B=!u:j==="is_not_empty"||j==="not_empty"?B=n.length>0:j==="is_empty"&&(B=n.length===0),B?(x.style.display="",x.querySelectorAll("input, select, textarea").forEach(G=>{G.dataset.originallyRequired==="true"&&(G.required=!0)})):(x.style.display="none",x.querySelectorAll("input, select, textarea").forEach(G=>{G.required&&(G.dataset.originallyRequired="true"),G.required=!1}))}})}$.element.addEventListener("input",Se),$.element.addEventListener("change",Se),Se();const de=$.element.querySelector('input[name="pincode"]'),ie=$.element.querySelector('input[name="city"]'),se=$.element.querySelector('input[name="state"]');if(de){const t=async()=>{const o=de.value.trim();if(o.length===6&&/^\d+$/.test(o)){ie&&!ie.value&&(ie.placeholder="\u26A1 Auto-filling..."),se&&!se.value&&(se.placeholder="\u26A1 Auto-filling...");try{const g=await be.lookupPincode(o);g.success&&(ie&&g.city&&(ie.value=g.city),se&&g.state&&(se.value=g.state))}catch{}finally{ie&&(ie.placeholder="City"),se&&(se.placeholder="State")}}};["input","blur","change","paste","keyup"].forEach(o=>{de.addEventListener(o,t)}),de.value.trim().length===6&&t()}const re=$.element.querySelector('input[name="phone"]'),Ee=$.element.querySelector('input[name="email"]'),Ce=$.element.querySelector("#studentForm");Ce&&Ce.addEventListener("submit",t=>{t.preventDefault(),t.stopPropagation()});let X=$.element.querySelector("#admin-student-dup-alert");!X&&Ce&&(X=document.createElement("div"),X.id="admin-student-dup-alert",X.className="alert alert-warning mb-3",X.style.display="none",X.style.fontSize="0.85rem",X.style.fontWeight="600",Ce.insertBefore(X,Ce.firstChild));const _e=()=>{const t=re?.value?.trim()||"",o=Ee?.value?.trim()||"",g=(N.students||[]).filter(L=>!s||e&&L._id!==e._id),x=be.checkDuplicateStudent(t,o,g);x.isDuplicate&&X?(X.textContent=x.message,X.style.display="block"):X&&(X.style.display="none")};re&&(re.addEventListener("input",_e),re.addEventListener("blur",_e)),Ee&&(Ee.addEventListener("input",_e),Ee.addEventListener("blur",_e));const Ye=$.element.querySelector("#btn-auto-suggest-seat"),Ke=$.element.querySelector('select[name="seat"]');Ye&&Ke&&Ye.addEventListener("click",()=>{const t=$.element.querySelector('select[name="shift"]')?.value||null,o=$.element.querySelector('select[name="zone"]')?.value||null,g=be.suggestSeat(t,o,l||[]);g&&g.seatId?(Ke.value=g.seatId,k.show(`\u26A1 Recommended Seat ${g.seatNumber} (${g.matchReason})`,"info")):k.show("No matching vacant seats available","warning")})}function St(e,s){const r=e.getContext("2d");if(r.strokeStyle="#1e293b",r.lineWidth=2.5,r.lineCap="round",r.lineJoin="round",s){const l=new Image;l.onload=()=>r.drawImage(l,0,0),l.src=s}let w=!1,P=0,F=0;function y(l){const p=e.getBoundingClientRect(),S=l.touches?l.touches[0].clientX:l.clientX,h=l.touches?l.touches[0].clientY:l.clientY,m=e.width/p.width,D=e.height/p.height;return{x:(S-p.left)*m,y:(h-p.top)*D}}function f(l){l.preventDefault(),w=!0;const p=y(l);P=p.x,F=p.y}function i(l){if(!w)return;l.preventDefault();const p=y(l);r.beginPath(),r.moveTo(P,F),r.lineTo(p.x,p.y),r.stroke(),P=p.x,F=p.y}function d(){w=!1}e.addEventListener("mousedown",f),e.addEventListener("mousemove",i),e.addEventListener("mouseup",d),e.addEventListener("mouseleave",d),e.addEventListener("touchstart",f,{passive:!1}),e.addEventListener("touchmove",i,{passive:!1}),e.addEventListener("touchend",d)}function Ct(e){const s=e.getContext("2d");return!new Uint32Array(s.getImageData(0,0,e.width,e.height).data.buffer).some(r=>r!==0)}async function Ge(e){Ne.show({title:"Delete Student Record",message:"Are you sure you want to permanently delete this student record? This action will remove the student, release their assigned seat & locker, and remove them completely from the directory.",danger:!0,onConfirm:async()=>{try{const s=await z.delete(`/api/students/${e}`);s.success?(k.success(s.message),await ae.clear("students"),fe(),ee(N.pagination.page)):k.error(s.message)}catch(s){k.error(s.message||"Error deleting student")}}})}K.addEventListener("click",e=>{if(e.target.closest("#addStudentBtn")){we();return}const s=e.target.closest(".btn-toggle-student-status");if(s){const S=s.getAttribute("data-id"),h=N.students.find(m=>m._id===S);if(h){const m=h.status||"active",D=m==="active"?"inactive":"active";ot.execute({applyState:()=>{h.status=D,ye()},rollbackState:()=>{h.status=m,ye()},apiCall:()=>z.put(`/api/students/${S}`,{status:D}),onSuccess:async T=>{k.success(T.message||`Status updated to ${D}`),await ae.clear("students"),fe()}})}return}const r=e.target.closest(".btn-copy-text");if(r){e.stopPropagation();const S=r.getAttribute("data-copy");S&&nt(S,r);return}const w=e.target.closest(".btn-view");if(w){const S=w.getAttribute("data-id"),h=N.students.find(m=>m._id===S);h&&qe(h);return}const P=e.target.closest(".btn-wa-remind");if(P){const S=P.getAttribute("data-id"),h=N.students.find(m=>m._id===S);h&&Ue(h);return}const F=e.target.closest(".btn-edit");if(F){const S=F.getAttribute("data-id"),h=N.students.find(m=>m._id===S);h&&we(h);return}const y=e.target.closest(".btn-idcard");if(y){const S=y.getAttribute("data-id"),h=N.students.find(m=>m._id===S);h&&Me(h);return}const f=e.target.closest(".btn-pdfform");if(f){const S=f.getAttribute("data-id"),h=N.students.find(m=>m._id===S);h&&Re(h,{business:window.store?.settings?.businessProfile,receiptConfig:window.store?.settings?.receipt});return}const i=e.target.closest(".btn-pwdreset");if(i){const S=i.getAttribute("data-id"),h=N.students.find(m=>m._id===S);h&&He(h);return}const d=e.target.closest(".action-menu-item");if(d){e.stopPropagation(),e.preventDefault();const S=d.dataset.action,h=d.dataset.id,m=N.students.find(D=>D._id===h);if(!m)return;if(S==="view")qe(m);else if(S==="edit")we(m);else if(S==="idcard")Me(m);else if(S==="pdfform")Re(m,{business:window.store?.settings?.businessProfile,receiptConfig:window.store?.settings?.receipt});else if(S==="pwdreset")He(m);else if(S==="delete")Ge(h);else if(S==="toggle-status"){const D=m.status==="active"?"suspended":"active";z.put(`/api/students/${h}`,{status:D}).then(T=>{k.success(`Student status updated to ${D}`),ee(N.pagination.page)}).catch(T=>k.error(T.message||"Failed to update status"))}return}const l=e.target.closest(".btn-delete");if(l){const S=l.getAttribute("data-id");Ge(S);return}const p=e.target.closest("tr.student-row");if(p&&!e.target.closest("button, input, select, .badge, .btn, label, a")){const S=p.getAttribute("data-id"),h=N.students.find(m=>m._id===S);h&&qe(h);return}});async function qe(e){if(e&&e._id)try{const b=await z.get(`/api/students/${e._id}`);b?.data&&(e=b.data)}catch{}let s=e.branch?.name||"";if(!s&&e.branch&&typeof e.branch=="string"){const b=(H?.branches||window.store?.branches||[]).find(v=>String(v._id||v.id)===String(e.branch));b&&(s=b.name+(b.city?` (${b.city})`:""))}s||(s=e.customFields?.branch||"Main Campus");const r=e.plan?.name||"Standard Plan",w=e.seat?.seatNumber||"Floating / Not Assigned",P=e.admissionDate?new Date(e.admissionDate).toLocaleDateString("en-IN"):"-",F=e.expiryDate?new Date(e.expiryDate).toLocaleDateString("en-IN"):"-",y=e.expiryDate?Math.ceil((new Date(e.expiryDate)-new Date)/(1e3*60*60*24)):null;let f=(e.phone||"").replace(/[^0-9]/g,"");f.length===10&&(f="91"+f);const i=f?`https://api.whatsapp.com/send?phone=${f}`:null;function d(b){if(!b)return"";let v=String(b).trim();return v.includes("___")&&(v=v.replace(/___/g," / ")),v=v.replace(/_/g," "),v=v.replace(/([a-z])([A-Z])/g,"$1 $2"),v.split(" ").filter(Boolean).map(C=>C.charAt(0).toUpperCase()+C.slice(1).toLowerCase()).join(" ").replace(/\s*\/\s*/g," / ")}const l=new Set(["name","fullname","phone","mobile","whatsapp","email","gender","sex","dob","dateofbirth","birthdate","bloodgroup","blood_group","address","residentialaddress","pincode","postalcode","city","state","emergencyname","emergencycontactname","emergencyphone","emergencycontactphone","emergencyrelation","emergencycontactrelation","parentguardianname","parent___guardian_name","parentname","guardianname","fathername","mothername","relationship","relation","emergencycontact","parentphone","idtype","idprooftype","idnumber","idproofnumber","idproof","idproofimage","idproofphoto","targetexam","targetexams","college","collegename","institute","university","qualification","highestqualification","branch","plan","shift","seat","password","photo","signature","status","remarks","specialremarks","notes","rfidcardnumber","biometricid","occupation","collegeorcompany"]),p=H?.customFields||[],S=H?.template?.sections||[],h=e.customFields&&typeof e.customFields=="object"?e.customFields:{},m=[];if(h instanceof Map)for(const[b,v]of h.entries()){const C=b.toLowerCase().replace(/[^a-z0-9]/g,"");if(!l.has(C)&&v!==void 0&&v!==null&&v!==""){const R=p.find($=>{const W=$.fieldName?.toLowerCase().replace(/[^a-z0-9]/g,""),q=$.label?.toLowerCase().replace(/[^a-z0-9]/g,"");return W===C||q===C});m.push({key:b,label:R?.label||d(b),value:v,section:R?.section||"additional",order:R?.order!==void 0?R.order:999,type:R?.type||"text"})}}else Object.entries(h).forEach(([b,v])=>{const C=b.toLowerCase().replace(/[^a-z0-9]/g,"");if(!l.has(C)&&v!==void 0&&v!==null&&v!==""){const R=p.find($=>{const W=$.fieldName?.toLowerCase().replace(/[^a-z0-9]/g,""),q=$.label?.toLowerCase().replace(/[^a-z0-9]/g,"");return W===C||q===C});m.push({key:b,label:R?.label||d(b),value:v,section:R?.section||"additional",order:R?.order!==void 0?R.order:999,type:R?.type||"text"})}});const D={personal:"\u{1F464}",academic:"\u{1F3AF}",plan:"\u23F0",payment:"\u{1F4B3}",seat:"\u{1FA91}",contact:"\u{1F4CD}",kyc:"\u{1FAAA}",parent:"\u{1F468}\u200D\u{1F469}\u200D\u{1F467}",vehicle:"\u{1F697}",transport:"\u{1F6B2}",custom:"\u{1F4CB}",additional:"\u{1F4DD}",other:"\u{1F4DD}"},T=[];if(S.length>0){S.forEach(C=>{const R=m.filter($=>$.section===C.name).sort(($,W)=>$.order-W.order);R.length>0&&T.push({name:C.name,label:C.label||d(C.name),icon:C.icon&&C.icon.length<=4?C.icon:D[C.name]||"\u{1F4CB}",fields:R})});const b=new Set(T.flatMap(C=>C.fields.map(R=>R.key))),v=m.filter(C=>!b.has(C.key));v.length>0&&T.push({name:"additional",label:"Additional Registration Information",icon:"\u{1F4DD}",fields:v.sort((C,R)=>C.order-R.order)})}else m.length>0&&T.push({name:"additional",label:"Additional Registration Information",icon:"\u{1F4DD}",fields:m.sort((b,v)=>b.order-v.order)});const _=document.createElement("div");_.innerHTML=`
      <div style="font-family: 'Outfit', sans-serif;">
        <!-- Student Header Card -->
        <div style="display: flex; align-items: center; gap: 16px; padding: 16px; background: var(--color-surface-hover); border-radius: 12px; margin-bottom: 20px; border: 1px solid var(--color-border);">
          <div style="width: 64px; height: 64px; border-radius: 50%; background: linear-gradient(135deg, var(--color-primary), #8b5cf6); display: flex; align-items: center; justify-content: center; font-size: 24px; color: #fff; font-weight: 700; overflow: hidden;">
            ${e.photo?`<img src="${e.photo}" style="width: 100%; height: 100%; object-fit: cover;">`:(e.name||"S").charAt(0)}
          </div>
          <div style="flex: 1;">
            <div class="d-flex align-items-center gap-2">
              <h3 style="margin: 0; font-size: 1.25rem; font-weight: 700;">${a(e.name)}</h3>
              <span class="badge ${e.status==="active"?"badge-success":"badge-danger"}" style="text-transform: uppercase;">${a(e.status)}</span>
            </div>
            <div class="text-muted small mt-1">
              Student ID: <strong style="color: var(--color-primary); font-family: monospace;">${a(e.studentId||"-")}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(e.studentId||"")}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Student ID">\u{1F4CB}</button> \u2022 Phone: <strong>${a(pe.phone(e.phone)||"-")}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(e.phone||"")}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">\u{1F4CB}</button>
            </div>
          </div>
        </div>

        <!-- 360 Degree Info Grid -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 16px; margin-bottom: 20px;">
          <!-- Membership Info -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-primary);">\u{1F4BA} Membership & Seat</h5>
            <div class="small text-muted mb-1">\u{1F3DB}\uFE0F Centre / Branch: <strong class="text-primary">${a(s)}</strong></div>
            <div class="small text-muted mb-1">Plan: <strong class="text-primary">${a(r)}</strong></div>
            <div class="small text-muted mb-1">Desk / Seat: <strong class="text-success">${a(w)}</strong></div>
            <div class="small text-muted mb-1">Enrolled: <strong>${P}</strong></div>
            <div class="small text-muted">Valid Until: <strong class="text-danger">${F}</strong> (${y!==null?y<=0?"Expired":`${y} days left \u2022 ${pe.timeAgo(e.expiryDate)}`:"-"})</div>
          </div>

          <!-- Academic & Exams -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-info);">\u{1F3AF} Academic & Target Exams</h5>
            <div class="small text-muted mb-1">College/Coaching: <strong>${a(e.occupation||"N/A")}</strong></div>
            <div class="small text-muted mb-2">Blood Group: <strong>${a(e.bloodGroup||"N/A")}</strong></div>
            <div class="d-flex flex-wrap gap-1">
              ${e.targetExams&&e.targetExams.length>0?e.targetExams.map(b=>`<span class="badge badge-primary" style="font-size: 0.7rem;">${a(b)}</span>`).join(""):'<span class="text-muted small">No target exams specified</span>'}
            </div>
          </div>

          <!-- Contact & Address -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-warning);">\u{1F4CD} Address & Emergency</h5>
            <div class="small text-muted mb-1">Email: <strong>${a(e.email||"N/A")}</strong></div>
            <div class="small text-muted mb-1">Address: <strong>${a(e.address||"N/A")}, ${a(e.city||"")} ${a(e.pincode||"")}</strong></div>
            ${(()=>{const b=e.emergencyContact?.name||e.customFields?.parent___guardian_name||e.customFields?.parentguardianname||e.customFields?.parentName||e.customFields?.emergencyContactName||e.customFields?.guardianName||e.customFields?.fatherName||"",v=e.emergencyContact?.relation||e.customFields?.relationship||e.customFields?.relation||e.customFields?.emergencyContactRelation||e.customFields?.parentRelation||"Parent",C=e.emergencyContact?.phone||e.customFields?.emergencyContactPhone||e.customFields?.emergencyContact||e.customFields?.emergencycontact||e.customFields?.parentPhone||"";return`
                <div class="small text-muted">Emergency Contact: <strong>${a(b||"N/A")} (${a(v)}) - ${a(pe.phone(C)||"")}</strong> ${C?`<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(C)}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">\u{1F4CB}</button>`:""}</div>
              `})()}
          </div>

          <!-- Smart Access & KYC -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-success);">\u{1F510} Access & KYC</h5>
            <div class="small text-muted mb-1">RFID Smart Card: <strong>${a(e.rfidCardNumber||"Not Linked")}</strong></div>
            <div class="small text-muted mb-1">Biometric ID: <strong>${a(e.biometricId||"Not Linked")}</strong></div>
            <div class="small text-muted mb-1">ID Proof: <strong>${a(e.idProof?.type||"Aadhaar")} (${a(e.idProof?.type==="Aadhaar"||!e.idProof?.type?pe.aadhaar(e.idProof?.number):e.idProof?.number||"N/A")})</strong> ${e.idProof?.number?`<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${a(e.idProof.number)}" style="padding: 1px 4px; font-size: 0.7rem;">\u{1F4CB}</button>`:""}</div>
            ${e.signature?`
              <div class="mt-2">
                <div class="text-xs text-muted">Digital Signature:</div>
                <img src="${e.signature}" style="max-height: 40px; border: 1px solid var(--color-border); border-radius: 4px; background: #fff; padding: 2px;">
              </div>
            `:""}
          </div>
        </div>

        <!-- Custom Sections & Questions as configured by Admin in Form Builder -->
        ${T.map(b=>`
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border); margin-bottom: 20px;">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>${b.icon}</span> ${a(b.label)}
            </h5>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 10px; font-size: 0.85rem;">
              ${b.fields.map(v=>{let C=a(String(v.value));return(typeof v.value=="boolean"||v.value==="true"||v.value==="false")&&(C=v.value===!0||v.value==="true"?'<span class="badge badge-success">Yes</span>':'<span class="badge badge-secondary">No</span>'),`
                  <div>
                    <span class="text-muted d-block small" style="font-weight: 600;">${a(v.label)}</span>
                    <strong style="color: var(--color-text-primary);">${C}</strong>
                  </div>
                `}).join("")}
            </div>
          </div>
        `).join("")}

        <!-- \u{1F9E0} Study Consistency & Heatmap Analytics Widget -->
        <div id="student-analytics-widget" style="background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: 12px; padding: 16px; margin-bottom: 20px;">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <div class="d-flex align-items-center gap-2">
              <span style="font-size: 1.3rem;">\u{1F9E0}</span>
              <h5 style="margin: 0; font-size: 0.95rem; font-weight: 700; color: var(--color-text-primary);">
                Study Consistency & Attendance Heatmap
              </h5>
            </div>
            <div id="student-analytics-badges" class="d-flex gap-2 align-items-center"></div>
          </div>
          <div id="student-analytics-content">
            <div class="text-center p-3 text-muted">
              <div class="loading-spinner mb-2" style="margin: 0 auto; width: 22px; height: 22px;"></div>
              <small>Analyzing student attendance discipline & study patterns...</small>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="d-flex justify-content-end gap-2 pt-3 border-top flex-wrap">
          <button type="button" class="btn btn-outline-success btn-sm btn-profile-remind" style="font-weight: 700;">
            \u{1F4F2} WhatsApp Reminder
          </button>
          ${i?`
            <a href="${i}" target="_blank" class="btn btn-outline-success btn-sm" style="font-weight: 600;">
              \u{1F4AC} Chat
            </a>
          `:""}
          <button type="button" class="btn btn-outline-info btn-sm btn-profile-idcard">
            \u{1FAAA} Print ID Card
          </button>
          <button type="button" class="btn btn-outline-success btn-sm btn-profile-pdfform">
            \u{1F4C4} Download PDF Form
          </button>
          <button type="button" class="btn btn-primary btn-sm btn-profile-edit">
            \u270F\uFE0F Edit Student
          </button>
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">
            Close
          </button>
        </div>
      </div>
    `;const M=new ge({title:`\u{1F464} Student Profile: ${e.name}`,content:_,size:"lg"});M.show(),rt(e._id,_),_.querySelectorAll(".btn-copy-text").forEach(b=>{b.addEventListener("click",v=>{v.stopPropagation();const C=b.getAttribute("data-copy");C&&nt(C,b)})}),_.querySelector(".btn-profile-remind")?.addEventListener("click",()=>{Ue(e,e.balanceDue>0?"balance_due":"renewal_reminder")}),_.querySelector(".btn-profile-idcard")?.addEventListener("click",()=>{M.close(),Me(e)}),_.querySelector(".btn-profile-pdfform")?.addEventListener("click",()=>{M.close(),Re(e,{business:window.store?.settings?.businessProfile,receiptConfig:window.store?.settings?.receipt})}),_.querySelector(".btn-profile-edit")?.addEventListener("click",()=>{M.close(),we(e)})}async function st(e=[],s){let r=e,w=[],P=[];try{const[D,T]=await Promise.all([z.get("/api/shifts?limit=50"),z.get("/api/plans?limit=50")]);w=D?.data?.shifts||D?.data||[],P=T?.data?.plans||T?.data||[]}catch{}const F=w.map(D=>`<option value="${a(D._id)}">${a(D.name)}</option>`).join(""),y=P.map(D=>`<option value="${a(D._id)}">${a(D.name)}</option>`).join(""),f=`Hi {name}! \u{1F44B}
Your library membership expires on *{expiry}*.
Please renew to continue your studies. \u{1F4DA}
Renew now: {link}

\u2014 {library}`,i=`
      <div id="wa-blast-modal" style="font-family:'Outfit',sans-serif;">
        <div class="mb-3">
          <label class="form-label fw-700">\u{1F4CB} Recipient Filter</label>
          <div class="d-flex flex-wrap gap-2 mb-2">
            <button type="button" class="btn btn-sm btn-primary wa-filter-btn active" data-filter="selected">
              \u2705 Selected (${e.length})
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary wa-filter-btn" data-filter="all_active">
              \u{1F7E2} All Active Students
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary wa-filter-btn" data-filter="by_shift">
              \u{1F552} By Shift
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary wa-filter-btn" data-filter="by_plan">
              \u{1F3F7}\uFE0F By Plan
            </button>
          </div>
          <div id="wa-filter-sub" style="display:none;margin-top:8px;">
            <div id="wa-shift-select" style="display:none;">
              <select id="wa-shift-id" class="form-select form-control form-control-sm">
                <option value="">\u2014 Select Shift \u2014</option>
                ${F}
              </select>
            </div>
            <div id="wa-plan-select" style="display:none;">
              <select id="wa-plan-id" class="form-select form-control form-control-sm">
                <option value="">\u2014 Select Plan \u2014</option>
                ${y}
              </select>
            </div>
          </div>
        </div>

        <div class="mb-3">
          <label class="form-label fw-700">\u{1F4AC} Message Template</label>
          <div class="mb-1 text-xs text-muted">Variables: <code>{name}</code> <code>{expiry}</code> <code>{plan}</code> <code>{seat}</code> <code>{link}</code> <code>{library}</code></div>
          <textarea id="wa-blast-message" class="form-control" rows="5" style="font-size:0.85rem;font-family:monospace;">${f}</textarea>
        </div>

        <div id="wa-recipient-count" class="mb-3 text-sm" style="color:var(--color-text-secondary);">
          Recipients loaded: <strong id="wa-count-num">${e.length}</strong>
        </div>

        <div class="mb-2 text-xs text-muted" style="background:rgba(108,92,231,0.08);border-radius:8px;padding:8px 12px;border:1px solid rgba(108,92,231,0.2);">
          \u2139\uFE0F This opens WhatsApp <code>wa.me/</code> links one by one (free, no API cost). Your browser may block popups \u2014 please allow for this site.
        </div>
      </div>`,d=ge.show({title:"\u{1F4F2} WhatsApp Blast Sender",content:i,size:"md",actions:`
        <button id="wa-blast-load-btn" type="button" class="btn btn-outline-secondary btn-sm">\u{1F504} Load Recipients</button>
        <button id="wa-blast-send-btn" type="button" class="btn btn-success">\u{1F4F2} Open WA Links (${e.length})</button>
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
      `});if(!d)return;let l="selected",p=[...e];const S=d.querySelector("#wa-count-num"),h=d.querySelector("#wa-blast-send-btn");function m(){S&&(S.textContent=p.length),h&&(h.textContent=`\u{1F4F2} Open WA Links (${p.length})`)}d.querySelectorAll(".wa-filter-btn").forEach(D=>{D.onclick=()=>{d.querySelectorAll(".wa-filter-btn").forEach(b=>b.classList.replace("btn-primary","btn-outline-secondary")),D.classList.replace("btn-outline-secondary","btn-primary"),l=D.dataset.filter;const T=d.querySelector("#wa-filter-sub"),_=d.querySelector("#wa-shift-select"),M=d.querySelector("#wa-plan-select");l==="by_shift"?(T&&(T.style.display="block"),_&&(_.style.display="block"),M&&(M.style.display="none")):l==="by_plan"?(T&&(T.style.display="block"),_&&(_.style.display="none"),M&&(M.style.display="block")):T&&(T.style.display="none"),l==="selected"&&(p=[...e],m())}}),d.querySelector("#wa-blast-load-btn")?.addEventListener("click",async()=>{try{let D={status:"active",limit:500};if(l==="by_shift"){const _=d.querySelector("#wa-shift-id")?.value;if(!_){k.error("Please select a shift");return}D.shift=_}else if(l==="by_plan"){const _=d.querySelector("#wa-plan-id")?.value;if(!_){k.error("Please select a plan");return}D.plan=_}else if(l==="selected"){p=[...e],m();return}const T=await z.get("/api/students",D);p=T?.data?.students||T?.data||[],m(),k.success(`${p.length} recipients loaded`)}catch{k.error("Failed to load recipients")}}),d.querySelector("#wa-blast-send-btn")?.addEventListener("click",async()=>{if(p.length===0){k.error("No recipients");return}const D=d.querySelector("#wa-blast-message")?.value||f;let T="Study Library";try{T=(await z.get("/api/settings"))?.data?.businessProfile?.businessName||T}catch{}ge.closeAll();let _=0;for(const M of p){const b=(M.phone||"").replace(/[^0-9]/g,"");if(!b||b.length<10)continue;const v=b.length===10?"91"+b:b,C=M.expiryDate?new Date(M.expiryDate).toLocaleDateString("en-IN"):"N/A",R=`https://wa.me/${v}`,$=D.replace(/{name}/g,M.name||"Student").replace(/{expiry}/g,C).replace(/{plan}/g,M.plan?.name||"your plan").replace(/{seat}/g,M.seat?.seatNumber||"N/A").replace(/{link}/g,R).replace(/{library}/g,T),W=`https://wa.me/${v}?text=${encodeURIComponent($)}`;window.open(W,"_blank"),_++,_<p.length&&await new Promise(q=>setTimeout(q,700))}k.success(`\u{1F4F2} Opened ${_} WhatsApp link(s). Check your browser tabs!`)})}async function Ue(e,s="renewal_reminder"){try{Ae.show("Preparing WhatsApp reminder & UPI payment link...");let r="";try{const w=await z.post("/api/messages/send-reminder",{studentId:e._id,reminderType:s});w.success&&w.data&&(r=w.data.whatsappUrl||w.data.waUrl)}catch(w){console.warn("Backend send-reminder error, generating direct WhatsApp payment link:",w)}if(!r){const w=e.balanceDue||e.pendingFine||e.plan?.price||0,P=s==="balance_due"?"Balance Due":"Membership Renewal",F=e.expiryDate?new Date(e.expiryDate).toLocaleDateString("en-IN"):"";r=wt.generateWhatsAppPaymentLink({phone:e.phone,studentName:e.name,amount:w,dueDate:F,planName:e.plan?.name||"",paymentType:P})}Ae.hide(),r?(/Android|iPhone|iPad|iPod/i.test(navigator.userAgent)?window.location.href=r:window.open(r,"_blank")||(window.location.href=r),k.success(`WhatsApp reminder opened for ${a(e.name||"Student")}!`)):k.error("Could not construct WhatsApp link")}catch(r){Ae.hide(),k.error(r.message||"Failed to trigger reminder")}}async function rt(e,s){const r=s.querySelector("#student-analytics-content"),w=s.querySelector("#student-analytics-badges");if(!r)return;function P(y){if(!y)return;if(w){const i=y.consistencyScore||0,d=y.currentStreak||0,l=xt(i,100,d);w.innerHTML=`
          ${l}
          <span class="badge" style="background: rgba(16, 185, 129, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.75rem;">
            ${a(y.peakStudyHours?.badge||"\u{1F305} Peak Time")}
          </span>
          <span class="badge" style="background: rgba(245, 158, 11, 0.15); color: var(--color-warning); font-weight: 700; font-size: 0.75rem;">
            \u{1F525} ${y.currentStreak||0}d Streak
          </span>
        `}const f=Math.max(0,Math.min(100,Math.round(y.consistencyScore||0)));r.innerHTML=`
        <div style="display: grid; grid-template-columns: minmax(130px, auto) 1fr; gap: 16px; align-items: center;">
          <!-- Consistency Gauge & Metrics -->
          <div style="display: flex; flex-direction: column; align-items: center; text-align: center; padding: 10px; background: var(--color-surface); border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="position: relative; width: 84px; height: 84px; display: flex; align-items: center; justify-content: center;">
              <svg viewBox="0 0 36 36" style="width: 84px; height: 84px; transform: rotate(-90deg);">
                <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                      fill="none" stroke="rgba(148, 163, 184, 0.2)" stroke-width="3.2" />
                <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                      fill="none" stroke="url(#adminScoreGaugeGrad)" stroke-width="3.2"
                      stroke-dasharray="${f}, 100" stroke-linecap="round" />
                <defs>
                  <linearGradient id="adminScoreGaugeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stop-color="#10b981"/>
                    <stop offset="100%" stop-color="#6366f1"/>
                  </linearGradient>
                </defs>
              </svg>
              <div style="position: absolute; text-align: center;">
                <div style="font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary); line-height: 1;">${f}%</div>
                <div style="font-size: 0.55rem; color: var(--color-text-secondary); text-transform: uppercase; font-weight: 700; margin-top: 2px;">Consistency</div>
              </div>
            </div>
            <div class="small mt-1" style="font-size: 0.75rem; color: var(--color-text-secondary);">
              Avg: <strong>${a(y.averageDailyDuration?.formatted||"0m")}</strong>/day
            </div>
            <div class="text-muted" style="font-size: 0.7rem;">
              ${y.totalDaysPresent||0}/90 days present
            </div>
          </div>

          <!-- 90-Day Interactive Calendar Heatmap -->
          <div>
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
              <span class="text-xs font-weight-bold" style="color: var(--color-text-primary);">90-Day Attendance Heatmap</span>
              <span class="text-muted" style="font-size: 0.7rem;">Hover cell for daily duration</span>
            </div>
            ${ht(y.heatmap||[])}

            <div style="margin-top: 10px; padding: 8px 12px; background: var(--color-surface); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.8rem; line-height: 1.4; color: var(--color-text-secondary);">
              <strong>\u{1F916} AI Insight:</strong> ${a(y.aiRecommendation||y.aiStudyTip||"Regular attendance observed.")}
            </div>
          </div>
        </div>
      `}try{const y=await ae.get("attendance","analytics_"+e);y&&P(y)}catch{}try{const y=await z.get(`/api/attendance/analytics/${e}`);y.success&&y.data&&(await ae.set("attendance","analytics_"+e,y.data),P(y.data))}catch(y){r.querySelector("svg")||(r.innerHTML=`<div class="text-muted small text-center p-2">Unable to load attendance analytics (${a(y.message||"No records")})</div>`)}let F=s.querySelector("#student-year-heatmap");if(!F){F=document.createElement("div"),F.id="student-year-heatmap",F.style.cssText="margin-top:14px;padding-top:14px;border-top:1px solid var(--color-border,rgba(255,255,255,0.08));";const y=s.querySelector("#student-analytics-widget");y&&y.appendChild(F)}try{await vt(F,e,new Date().getFullYear(),{compact:!1})}catch{F.innerHTML='<div class="text-muted small text-center">Heatmap unavailable</div>'}}async function Me(e){let s=window.store?.settings?.businessProfile||window.store?.profile||JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")||{businessName:"Study Library",tagline:"Self Study & Reading Room",phone:"",address:"",logo:"",upiId:""};(!s.businessName||s.businessName==="Study Library")&&z.get("/api/settings").then(ne=>{ne?.success&&ne.data?.businessProfile&&(s={...s,...ne.data.businessProfile})}).catch(()=>{});const r=s.stampImage||s.stampImageUrl||window.store?.profile?.stampImage||window.store?.settings?.businessProfile?.stampImage||JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")?.stampImage||"",w=s.logo||s.logoUrl||window.store?.profile?.logo||window.store?.settings?.businessProfile?.logo||JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")?.logo||"",P=e.plan?.name||"Standard Access",F=e.seat?.seatNumber||"Floating / Open Desk",y=e.shift?.name||"Full Day",f=e.expiryDate?new Date(e.expiryDate).toLocaleDateString("en-IN"):"Active",i=e.admissionDate?new Date(e.admissionDate).toLocaleDateString("en-IN"):new Date().toLocaleDateString("en-IN"),d=e.phone||"-",l=e.emergencyContact?.name||"Parent / Guardian",p=e.emergencyContact?.phone||"-",S=e.emergencyContact?.relation||"Parent",h=[e.address,e.city,e.state,e.pincode].filter(Boolean).join(", ")||"Campus Residential",m=e.bloodGroup||"",D=(e.name||"S").split(" ").map(ne=>ne[0]).join("").toUpperCase().slice(0,2),T=`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(JSON.stringify({id:e.studentId||"STU-MEMBER",name:e.name,phone:e.phone,seat:F,validTill:f}))}&margin=2&bgcolor=ffffff`;let _="horizontal",M="dual",b="#4f46e5",v="gradient",C=!0,R=!!m,$=!0,W=!0;const q=document.createElement("div");q.className="id-card-studio-wrapper",q.style.cssText='font-family: "Outfit", sans-serif; user-select: none;';const V=()=>{const ne=_==="horizontal",Fe=(A,c)=>c==="dark"?{cardBg:"linear-gradient(145deg, #1e2230 0%, #111420 100%)",textColor:"#f8fafc",subText:"#94a3b8",border:`2.5px solid ${A}`,outline:"1.5px dashed #475569",headerBg:`linear-gradient(135deg, ${A}, #0f172a)`,footerBg:"#0f172a",badgeBg:"rgba(255,255,255,0.1)",badgeColor:"#fff",cardShadow:"0 10px 28px rgba(0,0,0,0.5)"}:c==="minimal"?{cardBg:"#ffffff",textColor:"#0f172a",subText:"#64748b",border:"2.5px solid #0f172a",outline:"1.5px dashed #64748b",headerBg:A,footerBg:"#f8fafc",badgeBg:`${A}18`,badgeColor:A,cardShadow:"0 8px 24px rgba(0,0,0,0.14)"}:c==="glass"?{cardBg:"linear-gradient(135deg, rgba(255,255,255,0.95), rgba(240,244,255,0.98))",textColor:"#0f172a",subText:"#475569",border:"2.5px solid #0f172a",outline:"1.5px dashed #64748b",headerBg:`linear-gradient(135deg, ${A}, ${A}cc)`,footerBg:"#f1f5f9",badgeBg:`${A}20`,badgeColor:A,cardShadow:"0 8px 24px rgba(15, 23, 42, 0.16)"}:{cardBg:"linear-gradient(145deg, #ffffff 60%, #f8faff 100%)",textColor:"#0f172a",subText:"#475569",border:"2.5px solid #0f172a",outline:"1.5px dashed #64748b",headerBg:`linear-gradient(135deg, ${A}, ${A}ee)`,footerBg:"#f8fafc",badgeBg:`${A}18`,badgeColor:A,cardShadow:"0 8px 24px rgba(15, 23, 42, 0.16)"},he=A=>{const c=Fe(b,v);return A?`
            <div class="id-card-entity id-card-v id-card-front" style="
              width: 254px; min-height: 400px; height: 400px; background: ${c.cardBg}; color: ${c.textColor};
              border-radius: 12px; ${c.border}; outline: ${c.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${c.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Curved Banner -->
              <div style="background: ${c.headerBg}; color: #fff; padding: 10px 8px; text-align: center; position: relative;">
                <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
                  ${w?`<img src="${w}" style="width: 22px; height: 22px; border-radius: 4px; object-fit: contain; background: #fff;">`:'<span style="font-size: 1.1rem;">\u{1F4DA}</span>'}
                  <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 190px;">${a(s.businessName||"Study Library")}</div>
                </div>
                <div style="font-size: 0.62rem; opacity: 0.9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${a(s.tagline||"Student Membership Pass")}</div>
              </div>

              <!-- Center Avatar & Name -->
              <div style="display: flex; flex-direction: column; align-items: center; padding: 8px 10px 4px 10px; text-align: center;">
                <div style="width: 68px; height: 68px; border-radius: 12px; background: #eef2ff; border: 2.5px solid ${b}; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; font-weight: 800; color: ${b}; margin-bottom: 4px; box-shadow: 0 3px 10px rgba(0,0,0,0.1);">
                  ${e.photo?`<img src="${e.photo}" style="width: 100%; height: 100%; object-fit: cover;">`:D}
                </div>
                <div style="font-weight: 800; font-size: 0.88rem; line-height: 1.2; margin-bottom: 3px; color: ${c.textColor}; max-height: 2.4em; overflow: hidden; word-break: break-word;">${a(e.name)}</div>
                <div style="display: flex; gap: 4px; align-items: center; justify-content: center; flex-wrap: wrap;">
                  <span style="background: ${c.badgeBg}; color: ${c.badgeColor}; padding: 1px 7px; border-radius: 4px; font-weight: 800; font-size: 0.68rem; font-family: monospace; letter-spacing: 0.5px;">${a(e.studentId||"STU-MEMBER")}</span>
                  ${R&&m?`<span style="background: rgba(220,38,38,0.12); color: #dc2626; font-size: 0.65rem; font-weight: 800; padding: 1px 5px; border-radius: 4px;">\u{1FA78} ${a(m)}</span>`:""}
                </div>
              </div>

              <!-- Standardized Details Body -->
              <div style="padding: 6px 12px; font-size: 0.72rem; flex: 1; display: flex; flex-direction: column; gap: 3.5px; line-height: 1.35;">
                <div style="display: flex; justify-content: space-between;"><span style="color: ${c.subText}; font-weight: 600;">Desk / Seat:</span> <strong style="color: ${b};">${a(F)}</strong></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${c.subText}; font-weight: 600;">Shift Timing:</span> <span style="font-weight: 600;">${a(y)}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${c.subText}; font-weight: 600;">Membership:</span> <span>${a(P)}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${c.subText}; font-weight: 600;">Contact Phone:</span> <span>${a(d||"-")}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${c.subText}; font-weight: 600;">Valid Until:</span> <strong style="color: #dc2626; font-weight: 800;">${a(f)}</strong></div>
              </div>

              <!-- Bottom QR / Footer -->
              <div style="background: ${c.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 5px 10px; display: flex; justify-content: space-between; align-items: center;">
                ${C?`<img src="${T}" style="width: 44px; height: 44px; border-radius: 4px; border: 1px solid rgba(0,0,0,0.1); background: #fff;">`:"<div></div>"}
                <div style="text-align: right; font-size: 0.6rem; color: ${c.subText}; line-height: 1.3;">
                  <div style="font-weight: 800; color: ${b}; letter-spacing: 0.5px;">STUDENT PASS</div>
                  <div style="font-weight: 600;">Issued: ${a(i)}</div>
                  <div>${a(s.phone||"")}</div>
                </div>
              </div>
            </div>
          `:`
            <div class="id-card-entity id-card-h id-card-front" style="
              width: 380px; min-height: 240px; height: 240px; background: ${c.cardBg}; color: ${c.textColor};
              border-radius: 12px; ${c.border}; outline: ${c.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${c.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${c.headerBg}; color: #fff; padding: 8px 12px; display: flex; align-items: center; justify-content: space-between; gap: 8px;">
                <div style="display: flex; align-items: center; gap: 8px; min-width: 0;">
                  ${w?`<img src="${w}" style="width: 24px; height: 24px; border-radius: 4px; object-fit: contain; background: #fff; flex-shrink: 0;">`:'<span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4DA}</span>'}
                  <div style="min-width: 0;">
                    <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${a(s.businessName||"Study Library")}</div>
                    <div style="font-size: 0.6rem; opacity: 0.88; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${a(s.tagline||"Student Membership Card")}</div>
                  </div>
                </div>
                <span style="font-size: 0.62rem; font-weight: 800; background: rgba(255,255,255,0.22); padding: 2px 6px; border-radius: 3px; letter-spacing: 0.5px; white-space: nowrap;">STUDENT ID PASS</span>
              </div>

              <!-- Body: Photo + Info Grid -->
              <div style="padding: 10px 12px; display: flex; gap: 12px; align-items: center; flex: 1;">
                <div style="display: flex; flex-direction: column; align-items: center; gap: 6px; flex-shrink: 0;">
                  <div style="width: 64px; height: 64px; border-radius: 10px; background: #eef2ff; border: 2px solid ${b}; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 1.4rem; font-weight: 800; color: ${b}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                    ${e.photo?`<img src="${e.photo}" style="width: 100%; height: 100%; object-fit: cover;">`:D}
                  </div>
                  ${C?`<img src="${T}" style="width: 44px; height: 44px; border-radius: 4px; border: 1px solid rgba(0,0,0,0.1); background: #fff;">`:""}
                </div>

                <div style="flex: 1; min-width: 0;">
                  <!-- Full Student Name (Auto wrapped, never truncated with ...) -->
                  <div style="font-weight: 800; font-size: 0.92rem; line-height: 1.2; margin-bottom: 2px; color: ${c.textColor}; word-break: break-word; max-height: 2.4em; overflow: hidden;">${a(e.name)}</div>
                  
                  <div style="display: flex; gap: 4px; align-items: center; margin-bottom: 4px; flex-wrap: wrap;">
                    <span style="background: ${c.badgeBg}; color: ${c.badgeColor}; padding: 1px 6px; border-radius: 3px; font-weight: 800; font-size: 0.65rem; font-family: monospace;">${a(e.studentId||"STU-MEMBER")}</span>
                    ${R&&m?`<span style="background: rgba(220,38,38,0.12); color: #dc2626; font-size: 0.62rem; font-weight: 800; padding: 1px 5px; border-radius: 3px;">\u{1FA78} ${a(m)}</span>`:""}
                  </div>

                  <!-- Standardized Details Grid matching Vertical card exactly -->
                  <div style="font-size: 0.70rem; display: grid; grid-template-columns: auto 1fr; row-gap: 2.5px; column-gap: 8px; line-height: 1.3;">
                    <span style="color: ${c.subText}; font-weight: 600;">Desk / Seat:</span><strong style="color: ${b};">${a(F)}</strong>
                    <span style="color: ${c.subText}; font-weight: 600;">Shift Timing:</span><span style="font-weight: 600;">${a(y)}</span>
                    <span style="color: ${c.subText}; font-weight: 600;">Membership:</span><span>${a(P)}</span>
                    <span style="color: ${c.subText}; font-weight: 600;">Contact Phone:</span><span>${a(d||"-")}</span>
                    <span style="color: ${c.subText}; font-weight: 600;">Valid Until:</span><strong style="color: #dc2626; font-weight: 800;">${a(f)}</strong>
                  </div>
                </div>
              </div>

              <!-- Footer -->
              <div style="background: ${c.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 4px 12px; display: flex; justify-content: space-between; align-items: center; font-size: 0.62rem; color: ${c.subText};">
                <span>Issued: ${a(i)}</span>
                <span style="font-weight: 700; letter-spacing: 0.5px;">NON-TRANSFERABLE</span>
                <span>${a(s.phone||"")}</span>
              </div>
            </div>
          `},te=A=>{const c=Fe(b,v);return A?`
            <div class="id-card-entity id-card-v id-card-back" style="
              width: 254px; min-height: 400px; height: 400px; background: ${c.cardBg}; color: ${c.textColor};
              border-radius: 12px; ${c.border}; outline: ${c.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${c.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${c.headerBg}; color: #fff; padding: 10px 8px; text-align: center;">
                <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.4px;">RULES &amp; EMERGENCY CONTACT</div>
                <div style="font-size: 0.62rem; opacity: 0.88; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${a(s.businessName||"Study Library")}</div>
              </div>

              <!-- Emergency & Address Box -->
              <div style="padding: 8px 12px; font-size: 0.72rem; flex: 1; display: flex; flex-direction: column; gap: 5px;">
                ${$?`
                  <div style="background: ${c.badgeBg}; padding: 6px 8px; border-radius: 6px; border-left: 3px solid ${b};">
                    <div style="font-weight: 800; color: ${b}; font-size: 0.68rem; margin-bottom: 2px;">\u{1F6A8} EMERGENCY CONTACT</div>
                    <div style="font-weight: 600; font-size: 0.68rem;">${a(l)} (${a(S)})</div>
                    <div style="font-family: monospace; font-weight: 700; font-size: 0.68rem;">\u{1F4DE} ${a(p)}</div>
                  </div>
                `:""}

                <div style="font-size: 0.68rem; color: ${c.subText}; line-height: 1.35;">
                  <strong style="color: ${c.textColor};">\u{1F4CD} Resident Address:</strong> ${a(h)}
                </div>

                <!-- Rules List -->
                <div style="border-top: 1px dashed rgba(0,0,0,0.08); padding-top: 5px;">
                  <div style="font-weight: 700; font-size: 0.68rem; color: ${c.textColor}; margin-bottom: 2px;">\u{1F4D6} Campus Regulations:</div>
                  <ul style="margin: 0; padding-left: 14px; font-size: 0.63rem; color: ${c.subText}; line-height: 1.35;">
                    <li>Card must be presented upon entry.</li>
                    <li>Strict pin-drop silence in reading hall.</li>
                    <li>Access restricted to allotted shift timing.</li>
                    <li>Renew membership before plan expiry date.</li>
                  </ul>
                </div>

                <!-- Stamp / Signatory -->
                ${W?`
                  <div style="margin-top: auto; display: flex; justify-content: space-between; align-items: flex-end; padding-top: 4px;">
                    <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                      ${r?`
                        <img src="${r}" alt="Official Seal" style="max-height: 48px; max-width: 58px; object-fit: contain; margin-bottom: 2px; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.12));">
                      `:`
                        <div style="border: 1.5px solid #059669; color: #059669; font-weight: 800; font-size: 0.58rem; padding: 2px 6px; border-radius: 4px; transform: rotate(-4deg); text-align: center;">
                          OFFICIAL SEAL<br>PAID &amp; VERIFIED
                        </div>
                      `}
                    </div>
                    <div style="text-align: center;">
                      <div style="width: 70px; border-bottom: 1px solid ${c.subText}; margin-bottom: 2px;"></div>
                      <div style="font-size: 0.58rem; color: ${c.subText}; font-weight: 600;">Auth. Signatory</div>
                    </div>
                  </div>
                `:""}
              </div>

              <!-- Footer -->
              <div style="background: ${c.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 5px 10px; text-align: center; font-size: 0.60rem; color: ${c.subText}; line-height: 1.3;">
                ${a(s.phone?`Helpline: ${s.phone}`:"")}${s.phone&&s.address?" \u2022 ":""}${a(s.address||"")}
              </div>
            </div>
          `:`
            <div class="id-card-entity id-card-h id-card-back" style="
              width: 380px; min-height: 240px; height: 240px; background: ${c.cardBg}; color: ${c.textColor};
              border-radius: 12px; ${c.border}; outline: ${c.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${c.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${c.headerBg}; color: #fff; padding: 7px 12px; display: flex; justify-content: space-between; align-items: center;">
                <span style="font-weight: 800; font-size: 0.82rem; letter-spacing: 0.3px;">RULES &amp; EMERGENCY CONTACT</span>
                <span style="font-size: 0.65rem; opacity: 0.9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 170px;">${a(s.businessName||"Study Library")}</span>
              </div>

              <!-- Body: Emergency + Rules Grid -->
              <div style="padding: 8px 12px; font-size: 0.70rem; display: flex; gap: 10px; flex: 1;">
                <div style="flex: 1.3; display: flex; flex-direction: column; gap: 4px;">
                  ${$?`
                    <div style="background: ${c.badgeBg}; padding: 4px 6px; border-radius: 4px; border-left: 3px solid ${b}; font-size: 0.65rem;">
                      <div style="font-weight: 800; color: ${b};">\u{1F6A8} EMERGENCY CONTACT</div>
                      <div style="font-weight: 600;">${a(l)} (${a(S)}) \u2022 \u{1F4DE} ${a(p)}</div>
                    </div>
                  `:""}
                  
                  <div style="font-size: 0.64rem; color: ${c.subText}; line-height: 1.3;">
                    <strong style="color: ${c.textColor};">\u{1F4CD} Resident Address:</strong> ${a(h)}
                  </div>
                  
                  <div style="border-top: 1px dashed rgba(0,0,0,0.08); padding-top: 3px;">
                    <div style="font-weight: 700; font-size: 0.64rem; color: ${c.textColor}; margin-bottom: 2px;">\u{1F4D6} Campus Regulations:</div>
                    <ul style="margin: 0; padding-left: 12px; font-size: 0.60rem; color: ${c.subText}; line-height: 1.3;">
                      <li>Card must be presented upon entry.</li>
                      <li>Strict pin-drop silence in reading hall.</li>
                      <li>Access restricted to allotted shift timing.</li>
                      <li>Renew membership before expiry date.</li>
                    </ul>
                  </div>
                </div>

                <div style="flex: 0.7; display: flex; flex-direction: column; justify-content: space-between; align-items: center; text-align: center; border-left: 1px dashed rgba(0,0,0,0.1); padding-left: 8px;">
                  ${W?`
                    <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                      ${r?`
                        <img src="${r}" alt="Official Seal" style="max-height: 52px; max-width: 65px; object-fit: contain; margin-top: 2px; margin-bottom: 2px; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.12));">
                      `:`
                        <div style="border: 1.5px solid #059669; color: #059669; font-weight: 800; font-size: 0.58rem; padding: 3px 6px; border-radius: 4px; transform: rotate(-4deg); margin-top: 6px;">
                          OFFICIAL SEAL<br>PAID &amp; VERIFIED
                        </div>
                      `}
                    </div>
                    <div style="margin-top: auto; padding-bottom: 2px;">
                      <div style="width: 70px; border-bottom: 1px solid ${c.subText}; margin-bottom: 2px; margin-left: auto; margin-right: auto;"></div>
                      <div style="font-size: 0.56rem; color: ${c.subText}; font-weight: 600;">Auth. Signatory</div>
                    </div>
                  `:""}
                </div>
              </div>

              <!-- Footer with No Text Overlap -->
              <div style="background: ${c.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 4px 12px; text-align: center; font-size: 0.60rem; color: ${c.subText}; line-height: 1.3;">
                ${a(s.phone?`Helpline: ${s.phone}`:"")}${s.phone&&s.address?" \u2022 ":""}${a(s.address||"")}
              </div>
            </div>
          `};let J="";const Y=_==="vertical",le=Y?"400px":"240px";M==="front"?J=`
          <div style="display: flex; justify-content: center; align-items: center; padding: 6px 0;">
            ${he(Y)}
          </div>
        `:M==="back"?J=`
          <div style="display: flex; justify-content: center; align-items: center; padding: 6px 0;">
            ${te(Y)}
          </div>
        `:J=`
          <div id="dual-print-container" style="
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 20px;
            padding: 8px 4px;
            box-sizing: border-box;
            min-width: min-content;
            margin: 0 auto;
          ">
            <!-- Front Column -->
            <div style="display: flex; flex-direction: column; align-items: center; flex-shrink: 0;">
              <div style="font-size: 0.75rem; font-weight: 800; text-align: center; margin-bottom: 6px; color: var(--color-primary); letter-spacing: 0.5px;">\u{1FAAA} FRONT SIDE</div>
              ${he(Y)}
            </div>

            <!-- Perfectly Centered Vertical Fold / Cut Line -->
            <div class="id-cut-separator" style="
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              position: relative;
              height: ${le};
              width: 36px;
              flex-shrink: 0;
            ">
              <div style="position: absolute; top: 0; bottom: 0; left: 50%; border-left: 2px dashed rgba(99, 102, 241, 0.45); transform: translateX(-50%);"></div>
              <span style="
                position: relative;
                background: var(--color-surface, #1e2230);
                border: 1.5px solid var(--color-border, #374151);
                border-radius: 20px;
                padding: 4px 8px;
                font-size: 0.85rem;
                box-shadow: 0 2px 8px rgba(0,0,0,0.25);
                display: flex;
                align-items: center;
                justify-content: center;
                z-index: 2;
              ">
                \u2702\uFE0F
              </span>
            </div>

            <!-- Back Column -->
            <div style="display: flex; flex-direction: column; align-items: center; flex-shrink: 0;">
              <div style="font-size: 0.75rem; font-weight: 800; text-align: center; margin-bottom: 6px; color: var(--color-primary); letter-spacing: 0.5px;">\u{1F4C4} BACK SIDE</div>
              ${te(Y)}
            </div>
          </div>
        `,q.innerHTML=`
        <div style="display: flex; flex-direction: column; gap: 16px;">
          <!-- Top Studio Toolbar -->
          <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
              <!-- Orientation Toggle -->
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary);">Orientation:</span>
                <div class="btn-group btn-group-sm" role="group">
                  <button type="button" class="btn ${_==="horizontal"?"btn-primary":"btn-outline-secondary"} btn-opt-horiz" style="font-weight: 700;">
                    \u{1F4B3} Landscape (CR80)
                  </button>
                  <button type="button" class="btn ${_==="vertical"?"btn-primary":"btn-outline-secondary"} btn-opt-vert" style="font-weight: 700;">
                    \u{1FAAA} Portrait (CR80)
                  </button>
                </div>
              </div>

              <!-- Side Toggle -->
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary);">View:</span>
                <div class="btn-group btn-group-sm" role="group">
                  <button type="button" class="btn ${M==="front"?"btn-primary":"btn-outline-secondary"} btn-side-front" style="font-weight: 700;">Front</button>
                  <button type="button" class="btn ${M==="back"?"btn-primary":"btn-outline-secondary"} btn-side-back" style="font-weight: 700;">Back</button>
                  <button type="button" class="btn ${M==="dual"?"btn-primary":"btn-outline-secondary"} btn-side-dual" style="font-weight: 700;">Both Sides</button>
                </div>
              </div>

              <!-- Color & Theme Picker -->
              <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
                <div style="display: flex; align-items: center; gap: 6px;">
                  <label for="id-studio-color" style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary); margin: 0;">Accent:</label>
                  <input type="color" id="id-studio-color" value="${b}" style="width: 32px; height: 32px; border-radius: 6px; border: 1px solid var(--color-border); cursor: pointer; padding: 2px;">
                </div>

                <div style="display: flex; align-items: center; gap: 6px;">
                  <label for="id-studio-theme" style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary); margin: 0;">Theme:</label>
                  <select id="id-studio-theme" class="form-select form-select-sm" style="font-weight: 600; width: auto;">
                    <option value="gradient" ${v==="gradient"?"selected":""}>\u2728 Executive Vibrant</option>
                    <option value="dark" ${v==="dark"?"selected":""}>\u26AB Dark Slate Pro</option>
                    <option value="minimal" ${v==="minimal"?"selected":""}>\u26AA Minimal Classic</option>
                    <option value="glass" ${v==="glass"?"selected":""}>\u{1F48E} Frosted Glass</option>
                  </select>
                </div>
              </div>
            </div>
          </div>

          <!-- Studio Render Canvas Area -->
          <div id="id-card-render-stage" style="padding: 14px 10px; display: flex; justify-content: center; align-items: center; background: radial-gradient(circle, rgba(108,92,231,0.06) 0%, transparent 70%); border-radius: var(--radius-md); overflow-x: auto; width: 100%; box-sizing: border-box;">
            ${J}
          </div>

          <!-- Bottom Action Buttons Grid -->
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; border-top: 1px solid var(--color-border); padding-top: 12px;">
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
              <button type="button" class="btn btn-primary btn-sm" id="btn-download-front-png" style="font-weight: 700;">
                \u{1F4E5} Download Front
              </button>
              <button type="button" class="btn btn-outline-primary btn-sm" id="btn-download-back-png" style="font-weight: 700;">
                \u{1F4E5} Download Back
              </button>
              <button type="button" class="btn btn-outline-info btn-sm" id="btn-download-1080p-pass" style="font-weight: 700;">
                \u{1F4F1} 1080p Wallpaper Pass
              </button>
            </div>

            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-success btn-sm" id="btn-print-admin-id-card" style="font-weight: 800; padding: 6px 18px;">
                \u{1F5A8}\uFE0F Print ID Card (Front + Back)
              </button>
              <button type="button" class="btn btn-secondary btn-sm" id="btn-close-admin-id-studio">Close</button>
            </div>
          </div>
        </div>

        <style>
          .id-card-entity {
            box-sizing: border-box !important;
            transition: all 0.2s ease;
          }
          @media print {
            body * { visibility: hidden !important; }
            #id-card-render-stage, #id-card-render-stage * { visibility: visible !important; }
            #id-card-render-stage {
              position: fixed !important;
              left: 50% !important;
              top: 40px !important;
              transform: translateX(-50%) !important;
              width: 100% !important;
              box-shadow: none !important;
              background: none !important;
              padding: 0 !important;
              margin: 0 !important;
              overflow: visible !important;
            }
            #dual-print-container {
              display: flex !important;
              flex-direction: row !important;
              align-items: center !important;
              justify-content: center !important;
              gap: 36px !important;
              flex-wrap: nowrap !important;
            }
            .id-cut-separator {
              display: flex !important;
            }
            .id-card-entity {
              box-shadow: none !important;
              break-inside: avoid !important;
              page-break-inside: avoid !important;
            }
          }
        </style>
      `,q.querySelector(".btn-opt-horiz")?.addEventListener("click",()=>{_="horizontal",V()}),q.querySelector(".btn-opt-vert")?.addEventListener("click",()=>{_="vertical",V()}),q.querySelector(".btn-side-front")?.addEventListener("click",()=>{M="front",V()}),q.querySelector(".btn-side-back")?.addEventListener("click",()=>{M="back",V()}),q.querySelector(".btn-side-dual")?.addEventListener("click",()=>{M="dual",V()}),q.querySelector("#id-studio-color")?.addEventListener("input",A=>{b=A.target.value,V()}),q.querySelector("#id-studio-theme-select")?.addEventListener("change",A=>{v=A.target.value,V()}),q.querySelector("#toggle-id-qr")?.addEventListener("change",A=>{C=A.target.checked,V()}),q.querySelector("#toggle-id-blood")?.addEventListener("change",A=>{R=A.target.checked,V()}),q.querySelector("#toggle-id-emergency")?.addEventListener("change",A=>{$=A.target.checked,V()}),q.querySelector("#toggle-id-stamp")?.addEventListener("change",A=>{W=A.target.checked,V()}),q.querySelector("#btn-close-id-studio")?.addEventListener("click",()=>{$e.close()}),q.querySelector("#btn-print-id-card")?.addEventListener("click",()=>{M!=="dual"&&(M="dual",V()),setTimeout(()=>{window.print()},300)});const ve=async(A,c)=>{try{window.html2canvas||await new Promise((ie,se)=>{const re=document.createElement("script");re.src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js",re.onload=ie,re.onerror=se,document.head.appendChild(re)});const oe=q.querySelector(A);if(!oe){k.warning("Please switch to the selected side first.");return}const Se=await window.html2canvas(oe,{scale:3,useCORS:!0,backgroundColor:null}),de=document.createElement("a");de.download=c,de.href=Se.toDataURL("image/png"),de.click(),k.success("ID Card downloaded successfully!")}catch(oe){k.error("PNG download error: "+oe.message)}};q.querySelector("#btn-download-front-png")?.addEventListener("click",()=>{const A=(e.studentId||e.name||"student").replace(/\s+/g,"_");ve(".id-card-front",`ID_Front_${A}.png`)}),q.querySelector("#btn-download-back-png")?.addEventListener("click",()=>{const A=(e.studentId||e.name||"student").replace(/\s+/g,"_");ve(".id-card-back",`ID_Back_${A}.png`)}),q.querySelector("#btn-download-dual-png")?.addEventListener("click",()=>{const A=(e.studentId||e.name||"student").replace(/\s+/g,"_");ve("#id-card-render-stage",`ID_Dual_${A}.png`)})};V();const $e=new ge({title:`\u{1FAAA} Student ID Card Studio: ${a(e.name)}`,content:q,size:"xl"});$e.show()}function He(e){const s=(e.phone||"").replace(/[^0-9]/g,"").slice(-10),r=e.dateOfBirth?new Date(e.dateOfBirth).toISOString().slice(0,10).replace(/-/g,""):"",w=Math.floor(1e5+Math.random()*9e5).toString(),P=`
      <div style="display: flex; flex-direction: column; gap: 14px; user-select: none;">
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
          <div>
            <div style="font-weight: 800; font-size: 1.05rem; color: var(--color-primary);">${a(e.name)}</div>
            <div class="text-muted small">ID: ${a(e.studentId||"-")} | Phone: ${a(e.phone||"N/A")}</div>
          </div>
          <span class="badge badge-success" style="font-weight: 700;">Student Portal</span>
        </div>

        <div class="form-group" style="margin: 0;">
          <label class="form-label" style="font-weight: 700; font-size: 0.88rem;">New Password / 6-Digit PIN *</label>
          <div style="position: relative;">
            <input type="text" id="reset-pwd-input" class="form-control form-control-lg" value="${w}" style="padding-right: 48px; font-family: monospace; font-size: 1.2rem; font-weight: 800; letter-spacing: 2px;" required>
            <button type="button" id="btn-toggle-reset-eye" class="btn btn-icon btn-ghost" style="position: absolute; right: 8px; top: 8px; color: var(--color-text-muted);" title="Toggle Visibility">\u{1F441}\uFE0F</button>
          </div>
        </div>

        <!-- Preset Quick Buttons -->
        <div>
          <label class="form-label text-xs" style="font-weight: 700; text-transform: uppercase; color: var(--color-text-secondary); margin-bottom: 6px; display: block;">\u26A1 1-Click Password Presets</label>
          <div style="display: flex; gap: 8px; flex-wrap: wrap;">
            <button type="button" class="btn btn-sm btn-secondary" id="preset-random-pin" style="font-weight: 600;">\u{1F3B2} Random 6-Digit PIN</button>
            ${s?`<button type="button" class="btn btn-sm btn-secondary" id="preset-phone-pin" style="font-weight: 600;">\u{1F4F1} Phone (${s})</button>`:""}
            ${r?`<button type="button" class="btn btn-sm btn-secondary" id="preset-dob-pin" style="font-weight: 600;">\u{1F382} DOB (${r})</button>`:""}
          </div>
        </div>

        <!-- Dispatch Options Toggles -->
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 14px; display: flex; flex-direction: column; gap: 10px;">
          <label style="font-weight: 700; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
            <input type="checkbox" id="reset-toggle-wa" class="form-toggle" checked> \u{1F4F2} Open Pre-filled WhatsApp Credential Link
          </label>
          <label style="font-weight: 700; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
            <input type="checkbox" id="reset-toggle-email" class="form-toggle" ${e.email?"checked":""}> \u{1F4E7} Send Credentials Notification via Email
          </label>
        </div>
      </div>
    `,F=async f=>{const i=document.getElementById("reset-pwd-input")?.value?.trim(),d=document.getElementById("reset-toggle-email")?.checked,l=document.getElementById("reset-toggle-wa")?.checked;if(!i||i.length<4)return k.error("Password must be at least 4 characters long"),!1;try{const p=await z.post(`/api/students/${e._id}/reset-password`,{newPassword:i,sendEmail:d});return p.success?(k.success(`Password updated for ${e.name}!`),l&&p.data?.whatsappUrl&&window.open(p.data.whatsappUrl,"_blank"),!0):(k.error(p.message||"Failed to update password"),!1)}catch(p){return k.error(p.message||"Password update failed"),!1}},y=ge.show({title:"\u{1F511} Reset Student Portal Password",content:P,confirmText:"\u{1F4BE} Save & Update Password",confirmClass:"btn-primary",onConfirm:async f=>await F(f)});setTimeout(()=>{const f=document.getElementById("reset-pwd-input");document.getElementById("preset-random-pin")?.addEventListener("click",()=>{f&&(f.value=Math.floor(1e5+Math.random()*9e5).toString())}),document.getElementById("preset-phone-pin")?.addEventListener("click",()=>{f&&s&&(f.value=s)}),document.getElementById("preset-dob-pin")?.addEventListener("click",()=>{f&&r&&(f.value=r)}),document.getElementById("btn-toggle-reset-eye")?.addEventListener("click",()=>{f&&(f.type=f.type==="password"?"text":"password")})},100)}const Ve=K.querySelector("#studentSearch");Ve&&Ve.addEventListener("input",ft(()=>ee(1),250));const We=K.querySelector("#studentStatusFilter");return We&&We.addEventListener("change",()=>ee(1)),setTimeout(()=>{fe(),ee(1)},0),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1F393}",label:"Student Actions",color:"var(--color-primary, #6c5ce7)",actions:[{icon:"\u2795",label:"Add Student",onClick:()=>{we()}},{icon:"\u23F3",label:"Waiting List",onClick:()=>{window.location.hash="#/operations"}},{icon:"\u{1F4E4}",label:"Export Students",onClick:()=>{const e=N.students||[];if(e.length===0){k.info("No students loaded to export");return}const s=["Student ID","Full Name","Phone","Email","Plan","Seat","Blood Group","Gender","Status","Expiry Date"],r=e.map(f=>[`"${f.studentId||""}"`,`"${(f.name||"").replace(/"/g,'""')}"`,`"${f.phone||""}"`,`"${f.email||""}"`,`"${f.plan?.name||""}"`,`"${f.seat?.seatNumber||""}"`,`"${f.bloodGroup||""}"`,`"${f.gender||""}"`,`"${f.status||""}"`,`"${f.expiryDate?new Date(f.expiryDate).toLocaleDateString("en-IN"):""}"`]),w="\uFEFF"+[s.join(","),...r.map(f=>f.join(","))].join(`\r
`),P=new Blob([w],{type:"text/csv;charset=utf-8;"}),F=URL.createObjectURL(P),y=document.createElement("a");y.href=F,y.download=`students_export_${new Date().toISOString().split("T")[0]}.csv`,document.body.appendChild(y),y.click(),document.body.removeChild(y),URL.revokeObjectURL(F),k.success(`Exported ${e.length} student(s) to CSV`)}},{icon:"\u{1F50D}",label:"Search Student",onClick:()=>{const e=K.querySelector("#studentSearch")||document.querySelector("#studentSearch");e&&(e.focus(),e.scrollIntoView({behavior:"smooth"}))}}]}),K}export{Ft as render};
