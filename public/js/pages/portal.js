import P from"../api.js";import{Toast as S,Modal as re,Confirm as Ze,Loading as he,escapeHTML as o,copyToClipboard as Be}from"../ui.js";import{SmartFormatters as we}from"../utils/smartFormatters.js";import"../i18n.js";import{previewAdmissionFormPDF as qe,buildReceiptHTML as Qe,printReceiptDocument as Je}from"../pdfGenerator.js";import{PushNotifications as ke}from"../utils/pushNotifications.js";import{renderHeatmap as Xe}from"../utils/attendanceHeatmap.js";import{MediaFieldPicker as et}from"../mediaStudio.js";import{SmartIntelligence as Oe}from"../utils/smartIntelligence.js";import{PaymentStudio as De}from"../paymentStudio.js";async function Ne(){const n=document.createElement("div");n.className="page-container",n.style.cssText="width: 100%; max-width: 100%; box-sizing: border-box; padding-bottom: 3rem;",n.innerHTML=`
    <div class="card p-5 text-center" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div class="loading-spinner mb-3" style="margin: 0 auto;"></div>
      <p style="color: var(--color-text-secondary); margin: 0;">Loading Student Portal...</p>
    </div>
  `;try{const[g,I]=await Promise.all([P.get("/api/student-portal/dashboard"),P.get("/api/student-portal/config").catch(()=>null)]);if(!g.success||!g.data)throw new Error(g.message);const t=I?.data?.features||{};window.store||(window.store={}),window.store.portalFeatures=t;let p=null;try{const E=await P.get(`/api/attendance/analytics/${g.data.student._id}`);E.success&&(p=E.data)}catch(E){console.warn("Analytics fetch error:",E)}je(n,g.data,p),tt(n,t),setTimeout(async()=>{let E=n.querySelector("#portal-year-heatmap");if(!E){const T=n.querySelector('[data-section="analytics"]')||n.querySelector("#portal-analytics-section")||n.querySelector(".portal-analytics-card .card-body");T&&(E=document.createElement("div"),E.id="portal-year-heatmap",E.style.cssText="margin-top:18px;padding-top:14px;border-top:1px solid var(--color-border,rgba(255,255,255,0.08));",T.appendChild(E))}if(E&&g.data?.student?._id)try{await Xe(E,g.data.student._id,new Date().getFullYear(),{compact:!1})}catch{E.innerHTML='<div class="text-muted small text-center p-2">Full attendance calendar unavailable</div>'}},200)}catch(g){n.innerHTML=`
      <div class="card p-5 text-center" style="background: var(--color-surface); border: 1px solid var(--color-danger); border-radius: var(--radius-lg);">
        <div style="font-size: 3rem; margin-bottom: 0.5rem;">\u{1F393}</div>
        <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Student Portal</h3>
        <p style="color: var(--color-text-secondary); max-width: 500px; margin: 0 auto 1.5rem auto;">
          ${o(g.message||"No enrolled student record found for your account.")}
        </p>
        <a href="#/dashboard" class="btn btn-primary">Return to Admin Dashboard</a>
      </div>
    `}return n}function tt(n,g={}){const I=t=>g[t]!==!1&&g[t]!=="false"&&g[t]!==0;[{key:"enableOnlineRenewal",selectors:["#btn-portal-renew","#tile-portal-renew",'[data-feature="renewal"]',".portal-renewal-section"]},{key:"enableSeatTransfer",selectors:["#btn-portal-seat-change","#tile-portal-seat-change",'[data-feature="seat-transfer"]',".portal-seat-transfer-section"]},{key:"enableShiftSwitch",selectors:["#btn-portal-leave","#tile-portal-leave",'[data-feature="shift-switch"]',".portal-shift-switch-section"]},{key:"enableIdPassDownload",selectors:["#btn-portal-id-pass","#tile-portal-id-pass",'[data-feature="id-pass"]',".portal-id-pass-section"]},{key:"enableReceiptDownload",selectors:["#btn-portal-receipts","#tile-portal-receipts",'[data-feature="receipts"]',".portal-receipts-section"]},{key:"enableProfileEdit",selectors:["#btn-portal-edit-profile","#tile-portal-edit-profile",'[data-feature="profile-edit"]',".portal-profile-edit-section"]},{key:"enableGamifiedBadges",selectors:['[data-feature="badges"]',".portal-badges-section",".portal-streak-section",".study-streak-card"]},{key:"enableReferralProgram",selectors:['[data-feature="referral"]',".portal-referral-section","#portal-referral-card"]},{key:"enableAttendanceLogs",selectors:['[data-feature="heatmap"]',".portal-analytics-card","#portal-analytics-section","#portal-year-heatmap"]},{key:"enableAnnouncements",selectors:['[data-feature="announcements"]',".portal-announcements-section","#portal-announcements-card"]},{key:"enableLockerRequests",selectors:['[data-feature="locker"]',".portal-locker-section","#btn-portal-locker"]}].forEach(({key:t,selectors:p})=>{const E=I(t);p.forEach(T=>{n.querySelectorAll(T).forEach(L=>{E?L.getAttribute("data-feature-disabled")==="1"&&(L.style.display="",L.removeAttribute("data-feature-disabled")):(L.style.display="none",L.setAttribute("data-feature-disabled","1"))})})}),window._portalFeatures=g}function Me(n){if(!n)return"";try{const g=new Date(n);return isNaN(g.getTime())?n:g.toLocaleTimeString("en-IN",{hour:"2-digit",minute:"2-digit",hour12:!0})}catch{return n}}function je(n,g,I=null){const{student:t,business:p,daysRemaining:E,totalHours:T,todayAttendance:L,payments:e}=g,ge=window.store?.user||(typeof App<"u"&&App.getUser?App.getUser():{})||{},ae=(t.name||"S").split(" ").map(a=>a[0]).join("").toUpperCase().slice(0,2),Ce=t.seat&&t.seat.seatNumber,te=Ce?o(t.seat.seatNumber):"Floating Desk",Ue=Ce?o(t.seat.zone||"Quiet Zone"):"Open Access",ie=t.plan?.name||"Standard Reading Room Plan",Ye=t.plan?.price||0,Ie=t.shift?.name||t.shift?.timing||t.shift||t.plan?.shift||"Full Day",be=t.expiryDate?new Date(t.expiryDate).toLocaleDateString("en-IN"):"Not Set",He=t.targetExams&&t.targetExams.length>0?t.targetExams.map(a=>`<span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-size: 0.75rem;">${o(a)}</span>`).join(""):'<span class="text-muted small">General Self-Study</span>';if(t.photo){const a=document.getElementById("user-avatar");if(a){const r=t.photo.startsWith("/")||t.photo.startsWith("http")||t.photo.startsWith("data:")?t.photo:`/${t.photo}`;a.style.overflow="hidden",a.style.padding="0",a.innerHTML=`<img src="${r}" alt="Avatar" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%; display: block;" onerror="this.remove(); document.getElementById('user-avatar').textContent='${ae}';">`}try{const r=JSON.parse(localStorage.getItem("sl_user")||"{}");r.photo=t.photo,r.avatar=t.photo,localStorage.setItem("sl_user",JSON.stringify(r)),window.store&&window.store.user&&(window.store.user.photo=t.photo,window.store.user.avatar=t.photo)}catch{}}const Fe=new Date().getHours(),Ee=Fe<12?"\u{1F305} Good Morning":Fe<17?"\u{1F324}\uFE0F Good Afternoon":"\u{1F319} Good Evening",Q=L&&L.checkIn&&!L.checkOut,Te=Q?`\u{1F7E2} Currently Checked In since <strong>${Me(L.checkIn)}</strong>`:L&&L.checkOut?`\u2705 Completed study session today (<strong>${Me(L.checkIn)}</strong> \u2013 <strong>${Me(L.checkOut)}</strong>)`:"\u26AA Not checked in today";n.innerHTML=`
    <div class="portal-container">
      <!-- Admin Preview Banner -->
      ${g.isAdmin?`
        <div class="card p-3 mb-3" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.12), rgba(0, 184, 148, 0.08)); border: 1px solid var(--color-primary); border-radius: var(--radius-lg); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
          <div style="display: flex; align-items: center; gap: 10px;">
            <span style="font-size: 1.5rem;">\u{1F451}</span>
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.95rem;">Admin Inspection Mode \u2014 Student Portal Experience</div>
              <div style="font-size: 0.8rem; color: var(--color-text-secondary);">You are logged in as Administrator. Inspecting live student view for <strong>${o(t.name)}</strong>.</div>
            </div>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <label style="font-size: 0.82rem; font-weight: 600;">Switch Student:</label>
            <select id="admin-switch-student" class="form-select form-control form-control-sm" style="min-width: 220px; font-weight: 600;">
              ${(g.allStudents||[]).map(a=>`
                <option value="${a._id}" ${String(a._id)===String(t._id)?"selected":""}>
                  ${o(a.name)} (${a.studentId||a.phone})
                </option>
              `).join("")}
            </select>
            <a href="#/students" class="btn btn-outline-secondary btn-sm" style="font-weight: 600;">\u2794 Students Directory</a>
          </div>
        </div>
      `:""}

      <!-- 1. Mobile-First Welcome & Identity Bar -->
      <div class="card mb-3 p-3" id="portal-welcome-banner" style="
        background: ${p.bannerImage?`linear-gradient(135deg, rgba(108, 92, 231, 0.90), rgba(15, 23, 42, 0.85)), url('${p.bannerImage}') center/cover`:"var(--color-surface)"};
        border: 1px solid var(--color-border);
        border-radius: var(--radius-lg);
      ">
        <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
          <div style="display: flex; align-items: center; gap: 12px; min-width: 240px; flex: 1 1 auto;">
            <div style="
              width: 58px; height: 58px; border-radius: 50%;
              background: var(--color-primary-bg); color: var(--color-primary);
              font-size: 1.4rem; font-weight: 800; display: flex; align-items: center; justify-content: center;
              border: 2.5px solid ${Q?"#10b981":"var(--color-primary)"}; flex-shrink: 0; overflow: hidden;
              box-shadow: 0 4px 14px ${Q?"rgba(16, 185, 129, 0.35)":"rgba(108, 92, 231, 0.2)"};
              position: relative;
            ">
              ${t.photo||ge?.avatar?`
                <img src="${o(t.photo||ge.avatar)}" alt="${o(t.name)}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';">
                <span style="display: none; width: 100%; height: 100%; align-items: center; justify-content: center; font-size: 1.25rem; font-weight: 800;">${ae}</span>
              `:ae}
            </div>
            <div>
              <div style="font-size: 0.76rem; font-weight: 600; color: ${p.bannerImage?"rgba(255,255,255,0.85)":"var(--color-text-secondary)"}; display: flex; align-items: center; gap: 6px; margin-bottom: 2px;">
                <span>${Ee}</span>
                <span class="badge ${Q?"badge-success":"badge-secondary"}" style="font-size: 0.65rem; padding: 2px 6px; border-radius: 10px;">
                  ${Q?"\u{1F7E2} Active in Hall":"\u26AA Checked Out"}
                </span>
              </div>
              <h2 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: ${p.bannerImage?"#ffffff":"var(--color-text-primary)"}; white-space: normal; line-height: 1.25; text-transform: capitalize;">
                ${o((t.name||"").toLowerCase().replace(/\b\w/g,a=>a.toUpperCase()))}
              </h2>
              <div style="font-size: 0.78rem; color: ${p.bannerImage?"#a7f3d0":"var(--color-text-muted)"}; margin-top: 2px; font-family: monospace; font-weight: 600;">
                ${o(t.studentId||"STU-MEMBER")} \u2022 ${o(p.businessName||"Study Library")}
              </div>
            </div>
          </div>

          <div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">
            <button id="btn-portal-profile" class="btn btn-outline-secondary btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border-radius: 10px;">
              \u{1F464} Profile
            </button>
            <button id="btn-portal-renew" class="btn btn-primary btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 14px; border-radius: 10px;">
              \u26A1 Renew
            </button>
            <button id="btn-portal-logout" class="btn btn-outline-danger btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border-radius: 10px;" title="Log out from Student Portal">
              \u{1F6AA} Sign Out
            </button>
          </div>
        </div>
      </div>

      <!-- 2. Smart Pass & Active Desk Card (Apple Wallet Inspired) -->
      <div class="portal-pass-card mb-3" style="
        background: linear-gradient(135deg, #1e1b4b 0%, #312e81 45%, #0f766e 100%) !important;
        color: #ffffff !important;
        border-radius: 20px;
        padding: 1.25rem 1.5rem;
        position: relative;
        overflow: hidden;
        box-shadow: 0 12px 36px rgba(49, 46, 129, 0.32);
        border: 1px solid rgba(255, 255, 255, 0.2);
        box-sizing: border-box;
      ">
        <div style="display: flex; justify-content: space-between; align-items: flex-start; position: relative; z-index: 1; flex-wrap: wrap; gap: 10px;">
          <div>
            <div style="font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.8px; opacity: 0.85; font-weight: 700; color: #ffffff;">
              Allotted Study Desk
            </div>
            <div style="font-size: 1.85rem; font-weight: 900; line-height: 1.1; margin-top: 2px; text-shadow: 0 2px 8px rgba(0,0,0,0.2); color: #ffffff;">
              ${te}
            </div>
            <div style="font-size: 0.78rem; opacity: 0.92; margin-top: 2px; font-weight: 600; color: #ffffff;">
              Shift: <span style="color: #a7f3d0; font-weight: 700;">${o(Ie)}</span> \u2022 Plan: <span style="color: #c7d2fe; font-weight: 700;">${o(ie)}</span>
            </div>
          </div>

          <!-- Plan Expiry Pill -->
          <div style="text-align: right;">
            <span style="background: rgba(255,255,255,0.22); backdrop-filter: blur(8px); padding: 5px 12px; border-radius: 20px; font-weight: 800; font-size: 0.82rem; letter-spacing: 0.3px; border: 1px solid rgba(255,255,255,0.35); display: inline-block; color: #ffffff;">
              \u23F3 ${E} ${E===1?"Day":"Days"} Left
            </span>
            <div style="font-size: 0.72rem; opacity: 0.90; margin-top: 4px; font-weight: 600; color: #ffffff;">
              Valid till ${be}
            </div>
          </div>
        </div>

        <!-- Validity Progress Bar inside Pass -->
        <div style="margin-top: 14px; background: rgba(0,0,0,0.3); height: 6px; border-radius: 4px; overflow: hidden; position: relative; z-index: 1;">
          <div style="height: 100%; width: ${Math.max(5,Math.min(100,E/30*100))}%; background: linear-gradient(90deg, #34d399, #a7f3d0); border-radius: 4px;"></div>
        </div>

        <!-- Pass Actions Row: 1-Tap Punch In/Out + ID Pass -->
        <div style="margin-top: 14px; padding-top: 12px; border-top: 1px dashed rgba(255,255,255,0.25); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; position: relative; z-index: 1;">
          <button id="btn-self-punch" class="btn btn-sm ${Q?"btn-danger":"btn-success"}" style="
            font-weight: 800; font-size: 0.86rem; padding: 8px 18px; border-radius: 12px;
            box-shadow: 0 4px 14px rgba(0,0,0,0.25); border: none; flex: 1 1 180px; min-height: 42px;
          ">
            ${Q?"\u{1F534} Punch-Out (Leave)":L&&L.checkOut?"\u{1F7E2} Punch-In Again":"\u{1F7E2} 1-Tap Attendance Punch"}
          </button>

          <button id="btn-portal-idcard" class="btn btn-sm" style="
            background: rgba(255,255,255,0.25); color: #ffffff !important; border: 1px solid rgba(255,255,255,0.45);
            font-weight: 700; font-size: 0.84rem; padding: 8px 16px; border-radius: 12px; backdrop-filter: blur(8px);
            flex: 1 1 140px; min-height: 42px; text-shadow: 0 1px 3px rgba(0,0,0,0.3);
          ">
            \u{1FAAA} View Digital ID Pass
          </button>
        </div>
      </div>

      <!-- 3. Mandatory Profile & KYC Completion Card (Rendered when profile < 100%) -->
      ${t.profileCompletion<100||!t.isProfileComplete?`
        <div class="card mb-3 p-3" style="background: rgba(245, 158, 11, 0.08); border: 1.5px solid rgba(245, 158, 11, 0.35); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
            <div style="display: flex; align-items: center; gap: 12px; max-width: 650px;">
              <div style="font-size: 2rem;">\u26A0\uFE0F</div>
              <div>
                <h4 style="margin: 0 0 4px 0; font-size: 0.98rem; font-weight: 800; color: #f59e0b;">
                  Action Required: Complete Profile & KYC Upload (${t.profileCompletion||60}%)
                </h4>
                <p style="margin: 0; font-size: 0.80rem; color: var(--color-text-secondary); line-height: 1.35;">
                  Upload your Profile Selfie and Aadhaar KYC proof to unlock official Digital Offline ID Card Pass.
                </p>
                <div style="margin-top: 6px; width: 100%; max-width: 320px; height: 5px; background: rgba(255,255,255,0.15); border-radius: 4px; overflow: hidden;">
                  <div style="height: 100%; width: ${t.profileCompletion||60}%; background: linear-gradient(90deg, #f59e0b, #00b894); border-radius: 4px;"></div>
                </div>
              </div>
            </div>
            <button id="btn-portal-complete-kyc" class="btn btn-warning btn-sm" style="font-weight: 700; font-size: 0.82rem; padding: 6px 14px; border-radius: 10px;">
              \u270F\uFE0F Upload KYC
            </button>
          </div>
        </div>
      `:""}

      <!-- 4. Modern App Launcher Grid (10 Colorful Gradient Tiles) -->
      <div class="mobile-app-grid" style="
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(min(100%, 76px), 1fr));
        gap: 8px;
        margin-bottom: 1.25rem;
      ">
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-idcard" title="Open Digital ID Card Studio">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(99, 102, 241, 0.18), rgba(99, 102, 241, 0.08)); color: #6366f1;">\u{1FAAA}</div>
          <div class="portal-tile-label icon-label">ID Pass</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-renew" title="Renew Membership Plan">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.18), rgba(16, 185, 129, 0.08)); color: #10b981;">\u26A1</div>
          <div class="portal-tile-label icon-label">Renew</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-receipts" title="View Fee Receipts & Invoices">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(14, 165, 233, 0.18), rgba(14, 165, 233, 0.08)); color: #0ea5e9;">\u{1F9FE}</div>
          <div class="portal-tile-label icon-label">Receipts</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-notices" title="Read Campus Notices">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(245, 158, 11, 0.18), rgba(245, 158, 11, 0.08)); color: #f59e0b;">\u{1F4E2}</div>
          <div class="portal-tile-label icon-label">Notices</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-holidays" title="Check Holiday Calendar">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(236, 72, 153, 0.18), rgba(236, 72, 153, 0.08)); color: #ec4899;">\u{1F4C5}</div>
          <div class="portal-tile-label icon-label">Holidays</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-lostfound" title="Lost & Found Hub">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(20, 184, 166, 0.18), rgba(20, 184, 166, 0.08)); color: #14b8a6;">\u{1F50D}</div>
          <div class="portal-tile-label icon-label">Lost/Found</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-feedback" title="Submit Support Feedback">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(168, 85, 247, 0.18), rgba(168, 85, 247, 0.08)); color: #a855f7;">\u{1F4AC}</div>
          <div class="portal-tile-label icon-label">Feedback</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-seat-change" title="Request Seat Transfer">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(59, 130, 246, 0.18), rgba(59, 130, 246, 0.08)); color: #3b82f6;">\u{1F4BA}</div>
          <div class="portal-tile-label icon-label">Shift/Seat</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-leave" title="Apply for Leave">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(249, 115, 22, 0.18), rgba(249, 115, 22, 0.08)); color: #f97316;">\u{1F334}</div>
          <div class="portal-tile-label icon-label">Leave App</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-referral" title="Refer a Friend">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(234, 179, 8, 0.18), rgba(234, 179, 8, 0.08)); color: #eab308;">\u{1F381}</div>
          <div class="portal-tile-label icon-label">Referral</div>
        </div>
      </div>

      <!-- 5. Segmented Tab Navigation Track -->
      <div class="portal-tab-track" style="display: flex; background: var(--color-bg-secondary); padding: 4px; border-radius: 14px; border: 1px solid var(--color-border); margin-bottom: 1.25rem; gap: 4px; overflow-x: auto;">
        <button type="button" class="portal-tab-pill active" data-portal-tab="overview" style="flex: 1; min-width: 100px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: var(--color-surface); color: var(--color-primary); box-shadow: 0 2px 8px rgba(0,0,0,0.12); transition: all 0.2s; white-space: nowrap; padding: 6px 10px;">
          \u{1F3E0} Overview & Streaks
        </button>
        <button type="button" class="portal-tab-pill" data-portal-tab="campus" style="flex: 1; min-width: 100px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: transparent; color: var(--color-text-secondary); transition: all 0.2s; white-space: nowrap; padding: 6px 10px;">
          \u{1F3DB}\uFE0F Campus Life
        </button>
        <button type="button" class="portal-tab-pill" data-portal-tab="receipts" style="flex: 1; min-width: 100px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: transparent; color: var(--color-text-secondary); transition: all 0.2s; white-space: nowrap; padding: 6px 10px;">
          \u{1F9FE} Fee Receipts
        </button>
      </div>

      <!-- ============================================================ -->
      <!-- TAB PANE 1: Overview & Streaks                              -->
      <!-- ============================================================ -->
      <div id="pane-portal-overview" class="portal-tab-pane">
        <!-- 3 Quick Metrics Row -->
        <div class="quick-stats-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 180px), 1fr)); gap: 8px; margin-bottom: 1.25rem;">
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.74rem; font-weight: 700; color: var(--color-text-secondary);">\u{1F525} Study Streak</div>
            <div style="font-size: 1.4rem; font-weight: 800; color: var(--color-warning); margin-top: 2px;">
              ${I?.currentStreak||t.studyStreakDays||0} Days
            </div>
            <div style="font-size: 0.70rem; color: var(--color-text-muted);">Best Streak: ${I?.longestStreak||1} days</div>
          </div>
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.74rem; font-weight: 700; color: var(--color-text-secondary);">\u{1F4C8} Total Study Time</div>
            <div style="font-size: 1.4rem; font-weight: 800; color: var(--color-info); margin-top: 2px;">
              ${T} hrs
            </div>
            <div style="font-size: 0.70rem; color: var(--color-text-muted);">${I?.totalDaysPresent||1} days present this month</div>
          </div>
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.74rem; font-weight: 700; color: var(--color-text-secondary);">\u{1F396}\uFE0F Badges Unlocked</div>
            <div style="font-size: 1.4rem; font-weight: 800; color: var(--color-primary); margin-top: 2px;">
              ${(t.badges||[]).length} / 4
            </div>
            <div style="font-size: 0.70rem; color: var(--color-text-muted);">Library honors & achievements</div>
          </div>
        </div>

        <!-- AI Study Analytics & Consistency Score Card -->
        <div class="card mb-4 p-3 p-md-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 1.25rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.5rem;">\u{1F9E0}</span>
              <div>
                <h3 style="margin: 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary);">
                  AI Study Analytics & Consistency Score
                </h3>
                <p style="margin: 0; font-size: 0.78rem; color: var(--color-text-secondary);">
                  90-day learning habits, peak study hours & attendance discipline
                </p>
              </div>
            </div>

            <div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center;">
              <span class="badge" style="background: rgba(16, 185, 129, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.76rem; padding: 4px 8px; border-radius: 6px;">
                ${o(I?.peakStudyHours?.badge||"\u{1F305} Peak: 08:00 AM \u2013 02:00 PM")}
              </span>
              <span class="badge" style="background: rgba(245, 158, 11, 0.15); color: var(--color-warning); font-weight: 700; font-size: 0.76rem; padding: 4px 8px; border-radius: 6px;">
                \u{1F525} ${I?.currentStreak||0} Day Streak
              </span>
            </div>
          </div>

          <!-- Main Layout: Score Gauge + Heatmap + AI Recommendation -->
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 250px), 1fr)); gap: 1.25rem; align-items: center;">
            <div style="display: flex; flex-direction: column; align-items: center; text-align: center; gap: 6px; padding: 12px 14px; background: var(--color-bg-secondary); border-radius: var(--radius-md); border: 1px solid var(--color-border);">
              ${Ge(I?.consistencyScore||0)}
              <div style="font-size: 0.82rem; color: var(--color-text-secondary); margin-top: 4px;">
                Avg: <strong>${o(I?.averageDailyDuration?.formatted||"0m")}</strong> / day
              </div>
              <div style="font-size: 0.75rem; color: var(--color-text-muted);">
                ${I?.totalDaysPresent||0} / 30 days present
              </div>
            </div>

            <div>
              <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <span style="font-size: 0.84rem; font-weight: 700; color: var(--color-text-primary);">
                  \u{1F4C5} 30-Day Attendance Heatmap
                </span>
                <span style="font-size: 0.72rem; color: var(--color-text-muted);">
                  Daily study intensity
                </span>
              </div>

              ${We(I?.heatmap||[])}

              <div style="
                margin-top: 10px;
                padding: 8px 12px;
                background: linear-gradient(135deg, rgba(99, 102, 241, 0.08), rgba(16, 185, 129, 0.08));
                border: 1px solid rgba(99, 102, 241, 0.2);
                border-radius: var(--radius-md);
                display: flex;
                align-items: center;
                gap: 8px;
              ">
                <span style="font-size: 1.15rem; flex-shrink: 0;">\u{1F4A1}</span>
                <div style="font-size: 0.80rem; color: var(--color-text-primary); line-height: 1.35;">
                  <strong>AI Study Tip:</strong> ${o(I?.aiRecommendation||I?.aiStudyTip||"Consistency is the key to cracking competitive exams. Try regular study blocks every morning!")}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- \u{1F3C6} Achievements & Badges Studio Card -->
        <div class="card mb-4 p-3 p-md-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 1.25rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.5rem;">\u{1F3C6}</span>
              <div>
                <h3 style="margin: 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary);">
                  Achievements & Badges Studio
                </h3>
                <p style="margin: 0; font-size: 0.78rem; color: var(--color-text-secondary);">
                  Milestones, study streaks, and special honors
                </p>
              </div>
            </div>

            <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: var(--color-primary); font-weight: 700; font-size: 0.80rem; padding: 4px 10px; border-radius: 12px;">
              \u{1F396}\uFE0F ${(t.badges||[]).length} / 4 Badges Unlocked
            </span>
          </div>

          <!-- 4 Badges Progress Grid -->
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 10px;">
            ${(()=>{const a=g?.badgeProgress||I?.badgeProgress||[];return[{badgeId:"early_bird",title:"\u{1F305} Early Bird",icon:"\u{1F305}",description:"Checked in before 07:00 AM 5+ times",target:5,unit:"check-ins"},{badgeId:"study_warrior",title:"\u2694\uFE0F 100-Hr Warrior",icon:"\u2694\uFE0F",description:"Total study hours >= 100",target:100,unit:"hrs"},{badgeId:"night_owl",title:"\u{1F989} Night Owl",icon:"\u{1F989}",description:"Checked in after 08:00 PM 5+ times",target:5,unit:"check-ins"},{badgeId:"streak_champion",title:"\u{1F3C6} 30-Day Streak",icon:"\u{1F3C6}",description:"Consecutive attendance streak >= 30 days",target:30,unit:"days"}].map(r=>{const i=!!(t.badges||[]).find(f=>f.badgeId===r.badgeId);let s=0;if(a&&Array.isArray(a)){const f=a.find(h=>h.badgeId===r.badgeId);f&&(s=f.progress||0)}i&&(s=Math.max(s,r.target));const u=Math.min(100,Math.round(s/r.target*100));return`
                  <div style="background: var(--color-bg-secondary); border: 1px solid ${i?"var(--color-primary)":"var(--color-border)"}; border-radius: var(--radius-md); padding: 12px; display: flex; flex-direction: column; justify-content: space-between; position: relative;">
                    ${i?`
                      <div style="position: absolute; top: 6px; right: 6px; background: var(--color-success); color: white; font-size: 0.60rem; font-weight: 800; padding: 2px 6px; border-radius: 8px; text-transform: uppercase;">
                        Unlocked
                      </div>
                    `:""}
                    <div>
                      <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
                        <span style="font-size: 1.5rem; opacity: ${i?"1":"0.6"};">${r.icon}</span>
                        <div>
                          <div style="font-weight: 700; font-size: 0.88rem; color: ${i?"var(--color-primary)":"var(--color-text-primary)"};">
                            ${o(r.title)}
                          </div>
                          <div style="font-size: 0.72rem; color: var(--color-text-secondary);">
                            ${o(r.description)}
                          </div>
                        </div>
                      </div>
                    </div>

                    <div style="margin-top: 10px;">
                      <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.72rem; margin-bottom: 3px; font-weight: 600;">
                        <span style="color: var(--color-text-muted);">Progress</span>
                        <span style="color: ${i?"var(--color-success)":"var(--color-primary)"};">${s} / ${r.target} (${u}%)</span>
                      </div>
                      <div style="height: 5px; background: var(--color-surface); border-radius: 4px; overflow: hidden;">
                        <div style="width: ${u}%; height: 100%; background: ${i?"var(--color-success)":"var(--color-primary)"}; border-radius: 4px;"></div>
                      </div>
                    </div>
                  </div>
                `}).join("")})()}
          </div>
        </div>

        <!-- Push Notifications Mini Card -->
        <div class="card mb-4 p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.6rem;">\u{1F514}</span>
              <div>
                <div style="font-weight: 700; font-size: 0.92rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px; flex-wrap: wrap;">
                  <span>Mobile Push Notifications</span>
                  <span id="portal-push-badge" class="badge" style="font-size: 0.70rem; padding: 2px 6px; border-radius: 10px; border: 1px solid currentColor;">
                    Checking...
                  </span>
                </div>
                <div style="font-size: 0.76rem; color: var(--color-text-secondary); margin-top: 1px;">
                  Instant lock-screen reminders for seat expiry, announcements & receipts.
                </div>
              </div>
            </div>

            <label class="switch-label" style="margin: 0;">
              <input type="checkbox" id="portal-push-toggle">
              <span class="switch-slider"></span>
            </label>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- TAB PANE 2: Campus Life Hub                                 -->
      <!-- ============================================================ -->
      <div id="pane-portal-campus" class="portal-tab-pane" style="display: none;">
        <div id="student-campus-hub-card" class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div class="card-header p-3" style="border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span style="font-size: 1.3rem;">\u{1F3DB}\uFE0F</span>
              <div>
                <h4 style="margin: 0; font-size: 1.02rem; font-weight: 700; color: var(--color-text-primary);">
                  Campus Notice Board & Services
                </h4>
                <span style="font-size: 0.76rem; color: var(--color-text-secondary);">Circulars, holiday closures, lost items, and support</span>
              </div>
            </div>
            
            <div class="btn-group btn-group-sm" id="campus-hub-tabs" role="tablist">
              <button type="button" class="btn btn-primary btn-campus-tab active" data-tab="notices" style="font-weight: 700;">\u{1F4E2} Notices</button>
              <button type="button" class="btn btn-outline-secondary btn-campus-tab" data-tab="holidays" style="font-weight: 700;">\u{1F4C5} Holidays</button>
              <button type="button" class="btn btn-outline-secondary btn-campus-tab" data-tab="lostfound" style="font-weight: 700;">\u{1F50D} Lost &amp; Found</button>
              <button type="button" class="btn btn-outline-secondary btn-campus-tab" data-tab="feedback" style="font-weight: 700;">\u{1F4AC} Feedback</button>
            </div>
          </div>

          <div class="card-body p-3">
            <div id="campus-tab-content-container">
              <div class="text-center p-4 text-muted">
                <div class="loading-spinner mb-2" style="margin: 0 auto;"></div>
                Loading campus announcements...
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- TAB PANE 3: Fee Receipts & Invoices                         -->
      <!-- ============================================================ -->
      <div id="pane-portal-receipts" class="portal-tab-pane" style="display: none;">
        <div id="student-receipts-card" class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div class="card-header p-3" style="border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
            <h4 style="margin: 0; font-size: 1.02rem; font-weight: 700; color: var(--color-text-primary);">
              \u{1F4B3} My Payment Receipts & Invoices
            </h4>
            <span style="font-size: 0.78rem; color: var(--color-text-muted);">Official Tax & Fee Invoices</span>
          </div>
          <div class="card-body p-0">
            <div style="overflow-x: auto;">
              <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
                <thead>
                  <tr style="border-bottom: 1px solid var(--color-divider); text-align: left; font-size: 0.82rem; color: var(--color-text-muted);">
                    <th style="padding: 10px 14px;">Receipt #</th>
                    <th style="padding: 10px 14px;">Date</th>
                    <th style="padding: 10px 14px;">Method</th>
                    <th style="padding: 10px 14px;">Amount</th>
                    <th style="padding: 10px 14px;">Status</th>
                    <th style="padding: 10px 14px; text-align: right;">Action</th>
                  </tr>
                </thead>
                <tbody>
                  ${e&&e.length>0?e.map(a=>`
                    <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.88rem;">
                      <td style="padding: 10px 14px;">
                        <div style="display: flex; align-items: center; gap: 8px;">
                          ${De.renderDebitTrayIcon(28)}
                          <div>
                            <span style="font-family: monospace; font-weight: 700; color: var(--color-primary);">${o(a.receiptNumber||"REC")}</span>
                            <div class="tx-badge-pill tx-badge-paid" style="font-size: 0.65rem; padding: 1px 6px; margin-top: 2px;">\u2193 RECEIVED</div>
                          </div>
                        </div>
                      </td>
                      <td style="padding: 10px 14px;">${new Date(a.paymentDate).toLocaleDateString("en-IN")} <small class="text-muted">(${we.timeAgo(a.paymentDate)})</small></td>
                      <td style="padding: 10px 14px; text-transform: uppercase;">${o(a.paymentMethod||"UPI")}</td>
                      <td style="padding: 10px 14px; font-weight: 700; color: #10b981;" class="tx-amount tx-amount-green">\u20B9${Number(a.finalAmount||0).toLocaleString("en-IN")}</td>
                      <td style="padding: 10px 14px;">
                        <span class="tx-badge-pill tx-badge-paid">\u2713 Paid</span>
                      </td>
                      <td style="padding: 10px 14px; text-align: right;">
                        <div class="tx-action-capsule" style="margin: 0; display: inline-flex;">
                          <button type="button" class="btn-tx-action action-copy btn-copy-text" data-copy="${o(a.receiptNumber||"")}" title="Copy Receipt Number">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
                          </button>
                          <button type="button" class="btn-tx-action action-edit btn-view-receipt" data-receipt='${JSON.stringify(a)}' title="Download / View Receipt">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
                          </button>
                          <button type="button" class="btn-tx-action action-share btn-portal-wa-share" data-receipt="${o(a.receiptNumber||"")}" data-amount="${a.finalAmount||0}" title="Share via WhatsApp">
                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="18" cy="5" r="3"></circle><circle cx="6" cy="12" r="3"></circle><circle cx="18" cy="19" r="3"></circle><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"></line><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"></line></svg>
                          </button>
                        </div>
                      </td>
                    </tr>
                  `).join(""):`
                    <tr><td colspan="6" class="p-4 text-center text-muted">No past payments recorded yet.</td></tr>
                  `}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;const Se=n.querySelectorAll(".portal-tab-pill"),fe={overview:n.querySelector("#pane-portal-overview"),campus:n.querySelector("#pane-portal-campus"),receipts:n.querySelector("#pane-portal-receipts")},J=a=>{Se.forEach(r=>{const i=r.getAttribute("data-portal-tab")===a;r.classList.toggle("active",i),r.style.background=i?"var(--color-surface)":"transparent",r.style.color=i?"var(--color-primary)":"var(--color-text-secondary)",r.style.boxShadow=i?"0 2px 8px rgba(0, 0, 0, 0.12)":"none"}),Object.keys(fe).forEach(r=>{fe[r]&&(fe[r].style.display=r===a?"block":"none")}),a==="campus"&&typeof R=="function"&&R("notices")};Se.forEach(a=>{a.addEventListener("click",()=>{J(a.getAttribute("data-portal-tab"))})}),n.querySelector("#tile-portal-idcard")?.addEventListener("click",()=>{n.querySelector("#btn-portal-idcard")?.click()}),n.querySelector("#tile-portal-renew")?.addEventListener("click",()=>{n.querySelector("#btn-portal-renew")?.click()}),n.querySelector("#tile-portal-receipts")?.addEventListener("click",()=>{J("receipts")}),n.querySelector("#tile-portal-notices")?.addEventListener("click",()=>{J("campus"),typeof R=="function"&&R("notices")}),n.querySelector("#tile-portal-holidays")?.addEventListener("click",()=>{J("campus"),typeof R=="function"&&R("holidays")}),n.querySelector("#tile-portal-lostfound")?.addEventListener("click",()=>{J("campus"),typeof R=="function"&&R("lostfound")}),n.querySelector("#tile-portal-feedback")?.addEventListener("click",()=>{J("campus"),typeof R=="function"&&R("feedback")}),n.querySelector("#admin-switch-student")?.addEventListener("change",async a=>{const r=a.target.value;n.innerHTML=`
      <div class="card p-5 text-center" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="loading-spinner mb-3" style="margin: 0 auto;"></div>
        <p style="color: var(--color-text-secondary); margin: 0;">Switching student inspection view...</p>
      </div>
    `;try{const i=await P.get(`/api/student-portal/dashboard?studentId=${r}`);if(!i.success||!i.data)throw new Error(i.message);let s=null;try{const u=await P.get(`/api/attendance/analytics/${i.data.student._id}`);u.success&&(s=u.data)}catch{}je(n,i.data,s)}catch(i){S.error(i.message||"Failed to switch student"),Ne().then(s=>n.replaceWith(s))}}),n.querySelector("#btn-self-punch")?.addEventListener("click",async()=>{const a=n.querySelector("#btn-self-punch");he.button(a,!0);try{const r=await P.post("/api/student-portal/punch",{});r.success?(S.success(r.message),setTimeout(()=>Ne().then(i=>n.replaceWith(i)),500)):S.error(r.message)}catch(r){S.error(r.message||"Punch error")}finally{he.button(a,!1)}});const w=n.querySelector("#portal-push-toggle"),b=n.querySelector("#portal-push-badge");function _(){if(!w||!b)return;if(!ke.isSupported()){w.disabled=!0,w.checked=!1,b.textContent="Not Supported",b.className="badge badge-secondary",b.style.background="var(--color-bg-secondary)",b.style.color="var(--color-text-secondary)";return}const a=ke.getPermissionStatus();a==="granted"?(b.textContent="Permission Granted",b.className="badge badge-success",b.style.background="rgba(0, 184, 148, 0.15)",b.style.color="var(--color-success)",w.checked=ke.isEnabled()):a==="denied"?(b.textContent="Blocked in Browser",b.className="badge badge-danger",b.style.background="rgba(235, 77, 75, 0.15)",b.style.color="var(--color-danger)",w.checked=!1):(b.textContent="Permission Required",b.className="badge badge-warning",b.style.background="rgba(253, 203, 110, 0.2)",b.style.color="var(--color-warning)",w.checked=!1)}_(),w?.addEventListener("change",async a=>{if(a.target.checked)try{const r=await ke.requestPermission();r==="granted"?(await ke.subscribe(),S.success("\u{1F514} Native Mobile Push Notifications enabled!")):r==="denied"&&S.error("Push notification permission blocked by browser settings.")}catch(r){S.error(r.message||"Failed to enable push notifications")}else await ke.unsubscribe(),S.info("Push notifications disabled.");_()}),n.querySelector("#btn-portal-download-pdf")?.addEventListener("click",()=>{qe(t,{business:p})}),n.addEventListener("click",a=>{const r=a.target.closest(".btn-copy-text");if(r){a.stopPropagation();const i=r.getAttribute("data-copy");i&&Be(i,r)}}),n.querySelector("#btn-portal-idcard")?.addEventListener("click",()=>{if(t.profileCompletion<100||!t.isProfileComplete){S.warning("\u{1F512} Digital ID Card is locked! Please upload your Profile Photo Selfie & Aadhaar KYC first."),n.querySelector("#btn-portal-profile")?.click();return}const a=be,r=te,i=t.admissionDate?new Date(t.admissionDate).toLocaleDateString("en-IN"):new Date().toLocaleDateString("en-IN"),s=t.emergencyContact?.name||"Parent / Guardian",u=t.emergencyContact?.phone||"-",f=t.emergencyContact?.relation||"Parent",h=[t.address,t.city,t.state,t.pincode].filter(Boolean).join(", ")||"Campus Residential",D=t.bloodGroup||"",$=t.shift?.name||t.shift?.timing||t.shift||t.plan?.shift||"Full Day",m=t.phone||t.mobile||"",d=p.stampImage||p.stampImageUrl||window.store?.profile?.stampImage||window.store?.settings?.businessProfile?.stampImage||JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")?.stampImage||"",B=p.logo||p.logoUrl||window.store?.profile?.logo||window.store?.settings?.businessProfile?.logo||JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")?.logo||"",j=`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(t.studentId||t.enrollmentNo||t.phone||t._id||"STUDENT")}&margin=2&bgcolor=ffffff`;let G="horizontal",H="dual",q="#4f46e5",x="gradient",F=!0,z=!0,Y=!0,W=!!D;const A=document.createElement("div");A.className="id-card-studio-wrapper",A.style.cssText='font-family: "Outfit", sans-serif; user-select: none;';let k=null;const C=()=>{const U=G==="horizontal",X=(V,l)=>l==="dark"?{cardBg:"linear-gradient(145deg, #1e2230 0%, #111420 100%)",textColor:"#f8fafc",subText:"#94a3b8",border:`2.5px solid ${V}`,outline:"1.5px dashed #475569",headerBg:`linear-gradient(135deg, ${V}, #0f172a)`,footerBg:"#0f172a",badgeBg:"rgba(255,255,255,0.1)",badgeColor:"#fff",cardShadow:"0 10px 28px rgba(0,0,0,0.5)"}:l==="minimal"?{cardBg:"#ffffff",textColor:"#0f172a",subText:"#475569",border:"2.5px solid #0f172a",outline:"1.5px dashed #64748b",headerBg:V,footerBg:"#f8fafc",badgeBg:`${V}18`,badgeColor:V,cardShadow:"0 8px 24px rgba(0,0,0,0.14)"}:{cardBg:"linear-gradient(145deg, #ffffff 60%, #f8faff 100%)",textColor:"#0f172a",subText:"#475569",border:"2.5px solid #0f172a",outline:"1.5px dashed #64748b",headerBg:`linear-gradient(135deg, ${V}, ${V}ee)`,footerBg:"#f8fafc",badgeBg:`${V}18`,badgeColor:V,cardShadow:"0 8px 24px rgba(15, 23, 42, 0.16)"},oe=V=>{const l=X(q,x),ee=t.photo||t.avatar||ge?.photo||ge?.avatar||window.store?.user?.photo||window.store?.user?.avatar||document.querySelector("#sp-avatar-img")?.src||"";return V?`
            <div class="id-card-entity id-card-v id-card-front" style="
              width: 254px; min-height: 400px; height: 400px; background: ${l.cardBg}; color: ${l.textColor};
              border-radius: 12px; ${l.border}; outline: ${l.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${l.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Curved Banner -->
              <div style="background: ${l.headerBg}; color: #fff; padding: 8px 10px; text-align: center; position: relative;">
                <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
                  ${B?`<img src="${B}" style="width: 22px; height: 22px; border-radius: 4px; object-fit: contain; background: #fff;">`:""}
                  <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o(p.businessName||"Study Library")}</div>
                </div>
                <div style="font-size: 0.62rem; opacity: 0.9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o(p.tagline||"Student Membership Pass")}</div>
              </div>

              <!-- Center Avatar & Name -->
              <div style="display: flex; flex-direction: column; align-items: center; padding: 8px 10px 4px 10px; text-align: center;">
                <div style="width: 68px; height: 68px; border-radius: 12px; background: #eef2ff; border: 2.5px solid ${q}; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; font-weight: 800; color: ${q}; margin-bottom: 4px; box-shadow: 0 3px 10px rgba(0,0,0,0.1);">
                  ${ee?`<img src="${ee}" style="width: 100%; height: 100%; object-fit: cover;">`:ae}
                </div>
                <div style="font-weight: 800; font-size: 0.88rem; line-height: 1.2; margin-bottom: 3px; color: ${l.textColor}; max-height: 2.4em; overflow: hidden; word-break: break-word;">${o(t.name)}</div>
                <div style="display: flex; gap: 4px; align-items: center; justify-content: center; flex-wrap: wrap;">
                  <span style="background: ${l.badgeBg}; color: ${l.badgeColor}; padding: 1px 7px; border-radius: 4px; font-weight: 800; font-size: 0.68rem; font-family: monospace; letter-spacing: 0.5px;">${o(t.studentId||"STU-MEMBER")}</span>
                  ${W&&D?`<span style="background: rgba(220,38,38,0.12); color: #dc2626; font-size: 0.65rem; font-weight: 800; padding: 1px 5px; border-radius: 4px;">\u{1FA78} ${o(D)}</span>`:""}
                </div>
              </div>

              <!-- Standardized Details Body -->
              <div style="padding: 6px 12px; font-size: 0.72rem; flex: 1; display: flex; flex-direction: column; gap: 3.5px; line-height: 1.35;">
                <div style="display: flex; justify-content: space-between;"><span style="color: ${l.subText}; font-weight: 600;">Desk / Seat:</span> <strong style="color: ${q};">${o(r)}</strong></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${l.subText}; font-weight: 600;">Shift Timing:</span> <span style="font-weight: 600;">${o($)}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${l.subText}; font-weight: 600;">Membership:</span> <span>${o(ie)}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${l.subText}; font-weight: 600;">Contact Phone:</span> <span>${o(m||"-")}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${l.subText}; font-weight: 600;">Valid Until:</span> <strong style="color: #dc2626; font-weight: 800;">${o(a)}</strong></div>
              </div>

              <!-- Bottom QR / Footer -->
              <div style="background: ${l.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 5px 10px; display: flex; justify-content: space-between; align-items: center;">
                ${F?`<img src="${j}" style="width: 44px; height: 44px; border-radius: 4px; border: 1px solid rgba(0,0,0,0.1); background: #fff;">`:"<div></div>"}
                <div style="text-align: right; font-size: 0.6rem; color: ${l.subText}; line-height: 1.3;">
                  <div style="font-weight: 800; color: ${q}; letter-spacing: 0.5px;">STUDENT PASS</div>
                  <div style="font-weight: 600;">Issued: ${o(i)}</div>
                  <div>${o(p.phone||"")}</div>
                </div>
              </div>
            </div>
          `:`
            <div class="id-card-entity id-card-h id-card-front" style="
              width: 380px; min-height: 240px; height: 240px; background: ${l.cardBg}; color: ${l.textColor};
              border-radius: 12px; ${l.border}; outline: ${l.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${l.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${l.headerBg}; color: #fff; padding: 8px 12px; display: flex; align-items: center; justify-content: space-between; gap: 8px;">
                <div style="display: flex; align-items: center; gap: 8px; min-width: 0;">
                  ${B?`<img src="${B}" style="width: 24px; height: 24px; border-radius: 4px; object-fit: contain; background: #fff; flex-shrink: 0;">`:""}
                  <div style="min-width: 0;">
                    <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o(p.businessName||"Study Library")}</div>
                    <div style="font-size: 0.6rem; opacity: 0.88; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o(p.tagline||"Student Membership Card")}</div>
                  </div>
                </div>
                <span style="font-size: 0.62rem; font-weight: 800; background: rgba(255,255,255,0.22); padding: 2px 6px; border-radius: 3px; letter-spacing: 0.5px; white-space: nowrap;">STUDENT ID PASS</span>
              </div>

              <!-- Body: Photo + Info Grid -->
              <div style="padding: 10px 12px; display: flex; gap: 12px; align-items: center; flex: 1;">
                <div style="display: flex; flex-direction: column; align-items: center; gap: 6px; flex-shrink: 0;">
                  <div style="width: 64px; height: 64px; border-radius: 10px; background: #eef2ff; border: 2px solid ${q}; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 1.4rem; font-weight: 800; color: ${q}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                    ${ee?`<img src="${ee}" style="width: 100%; height: 100%; object-fit: cover;">`:ae}
                  </div>
                  ${F?`<img src="${j}" style="width: 44px; height: 44px; border-radius: 4px; border: 1px solid rgba(0,0,0,0.1); background: #fff;">`:""}
                </div>

                <div style="flex: 1; min-width: 0;">
                  <!-- Full Student Name (Auto wrapped, never truncated with ...) -->
                  <div style="font-weight: 800; font-size: 0.92rem; line-height: 1.2; margin-bottom: 2px; color: ${l.textColor}; word-break: break-word; max-height: 2.4em; overflow: hidden;">${o(t.name)}</div>
                  
                  <div style="display: flex; gap: 4px; align-items: center; margin-bottom: 4px; flex-wrap: wrap;">
                    <span style="background: ${l.badgeBg}; color: ${l.badgeColor}; padding: 1px 6px; border-radius: 3px; font-weight: 800; font-size: 0.65rem; font-family: monospace;">${o(t.studentId||"STU-MEMBER")}</span>
                    ${W&&D?`<span style="background: rgba(220,38,38,0.12); color: #dc2626; font-size: 0.62rem; font-weight: 800; padding: 1px 5px; border-radius: 3px;">\u{1FA78} ${o(D)}</span>`:""}
                  </div>

                  <!-- Standardized Details Grid matching Vertical card exactly -->
                  <div style="font-size: 0.70rem; display: grid; grid-template-columns: auto 1fr; row-gap: 2.5px; column-gap: 8px; line-height: 1.3;">
                    <span style="color: ${l.subText}; font-weight: 600;">Desk / Seat:</span><strong style="color: ${q};">${o(r)}</strong>
                    <span style="color: ${l.subText}; font-weight: 600;">Shift Timing:</span><span style="font-weight: 600;">${o($)}</span>
                    <span style="color: ${l.subText}; font-weight: 600;">Membership:</span><span>${o(ie)}</span>
                    <span style="color: ${l.subText}; font-weight: 600;">Contact Phone:</span><span>${o(m||"-")}</span>
                    <span style="color: ${l.subText}; font-weight: 600;">Valid Until:</span><strong style="color: #dc2626; font-weight: 800;">${o(a)}</strong>
                  </div>
                </div>
              </div>

              <!-- Footer -->
              <div style="background: ${l.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 4px 12px; display: flex; justify-content: space-between; align-items: center; font-size: 0.62rem; color: ${l.subText};">
                <span>Issued: ${o(i)}</span>
                <span style="font-weight: 700; letter-spacing: 0.5px;">NON-TRANSFERABLE</span>
                <span>${o(p.phone||"")}</span>
              </div>
            </div>
          `},ce=V=>{const l=X(q,x);return V?`
            <div class="id-card-entity id-card-v id-card-back" style="
              width: 254px; min-height: 400px; height: 400px; background: ${l.cardBg}; color: ${l.textColor};
              border-radius: 12px; ${l.border}; outline: ${l.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${l.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${l.headerBg}; color: #fff; padding: 10px 8px; text-align: center;">
                <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.4px;">RULES &amp; EMERGENCY CONTACT</div>
                <div style="font-size: 0.62rem; opacity: 0.88; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${o(p.businessName||"Study Library")}</div>
              </div>

              <!-- Emergency & Address Box -->
              <div style="padding: 8px 12px; font-size: 0.72rem; flex: 1; display: flex; flex-direction: column; gap: 5px;">
                ${z?`
                  <div style="background: ${l.badgeBg}; padding: 6px 8px; border-radius: 6px; border-left: 3px solid ${q};">
                    <div style="font-weight: 800; color: ${q}; font-size: 0.68rem; margin-bottom: 2px;">\u{1F6A8} EMERGENCY CONTACT</div>
                    <div style="font-weight: 600; font-size: 0.68rem;">${o(s)} (${o(f)})</div>
                    <div style="font-family: monospace; font-weight: 700; font-size: 0.68rem;">\u{1F4DE} ${o(u)}</div>
                  </div>
                `:""}

                <div style="font-size: 0.68rem; color: ${l.subText}; line-height: 1.35;">
                  <strong style="color: ${l.textColor};">\u{1F4CD} Resident Address:</strong> ${o(h)}
                </div>

                <!-- Rules List -->
                <div style="border-top: 1px dashed rgba(0,0,0,0.08); padding-top: 5px;">
                  <div style="font-weight: 700; font-size: 0.68rem; color: ${l.textColor}; margin-bottom: 2px;">\u{1F4D6} Campus Regulations:</div>
                  <ul style="margin: 0; padding-left: 14px; font-size: 0.63rem; color: ${l.subText}; line-height: 1.35;">
                    <li>Card must be presented upon entry.</li>
                    <li>Strict pin-drop silence in reading hall.</li>
                    <li>Access restricted to allotted shift timing.</li>
                    <li>Renew membership before plan expiry date.</li>
                  </ul>
                </div>

                <!-- Stamp / Signatory -->
                ${Y?`
                  <div style="margin-top: auto; display: flex; justify-content: space-between; align-items: flex-end; padding-top: 4px;">
                    <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                      ${d?`
                        <img src="${d}" alt="Official Seal" style="max-height: 48px; max-width: 58px; object-fit: contain; margin-bottom: 2px; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.12));">
                      `:`
                        <div style="border: 1.5px solid #059669; color: #059669; font-weight: 800; font-size: 0.58rem; padding: 2px 6px; border-radius: 4px; transform: rotate(-4deg); text-align: center;">
                          OFFICIAL SEAL<br>PAID &amp; VERIFIED
                        </div>
                      `}
                    </div>
                    <div style="text-align: center;">
                      <div style="width: 70px; border-bottom: 1px solid ${l.subText}; margin-bottom: 2px;"></div>
                      <div style="font-size: 0.58rem; color: ${l.subText}; font-weight: 600;">Auth. Signatory</div>
                    </div>
                  </div>
                `:""}
              </div>

              <!-- Footer -->
              <div style="background: ${l.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 5px 10px; text-align: center; font-size: 0.60rem; color: ${l.subText}; line-height: 1.3;">
                ${o(p.phone?`Helpline: ${p.phone}`:"")}${p.phone&&p.address?" \u2022 ":""}${o(p.address||"")}
              </div>
            </div>
          `:`
            <div class="id-card-entity id-card-h id-card-back" style="
              width: 380px; min-height: 240px; height: 240px; background: ${l.cardBg}; color: ${l.textColor};
              border-radius: 12px; ${l.border}; outline: ${l.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${l.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${l.headerBg}; color: #fff; padding: 7px 12px; display: flex; justify-content: space-between; align-items: center;">
                <span style="font-weight: 800; font-size: 0.82rem; letter-spacing: 0.3px;">RULES &amp; EMERGENCY CONTACT</span>
                <span style="font-size: 0.65rem; opacity: 0.9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 170px;">${o(p.businessName||"Study Library")}</span>
              </div>

              <!-- Body: Emergency + Rules Grid -->
              <div style="padding: 8px 12px; font-size: 0.70rem; display: flex; gap: 10px; flex: 1;">
                <div style="flex: 1.3; display: flex; flex-direction: column; gap: 4px;">
                  ${z?`
                    <div style="background: ${l.badgeBg}; padding: 4px 6px; border-radius: 4px; border-left: 3px solid ${q}; font-size: 0.65rem;">
                      <div style="font-weight: 800; color: ${q};">\u{1F6A8} EMERGENCY CONTACT</div>
                      <div style="font-weight: 600;">${o(s)} (${o(f)}) \u2022 \u{1F4DE} ${o(u)}</div>
                    </div>
                  `:""}
                  
                  <div style="font-size: 0.64rem; color: ${l.subText}; line-height: 1.3;">
                    <strong style="color: ${l.textColor};">\u{1F4CD} Resident Address:</strong> ${o(h)}
                  </div>
                  
                  <div style="border-top: 1px dashed rgba(0,0,0,0.08); padding-top: 3px;">
                    <div style="font-weight: 700; font-size: 0.64rem; color: ${l.textColor}; margin-bottom: 2px;">\u{1F4D6} Campus Regulations:</div>
                    <ul style="margin: 0; padding-left: 12px; font-size: 0.60rem; color: ${l.subText}; line-height: 1.3;">
                      <li>Card must be presented upon entry.</li>
                      <li>Strict pin-drop silence in reading hall.</li>
                      <li>Access restricted to allotted shift timing.</li>
                      <li>Renew membership before expiry date.</li>
                    </ul>
                  </div>
                </div>

                <div style="flex: 0.7; display: flex; flex-direction: column; justify-content: space-between; align-items: center; text-align: center; border-left: 1px dashed rgba(0,0,0,0.1); padding-left: 8px;">
                  ${Y?`
                    <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                      ${d?`
                        <img src="${d}" alt="Official Seal" style="max-height: 52px; max-width: 65px; object-fit: contain; margin-top: 2px; margin-bottom: 2px; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.12));">
                      `:`
                        <div style="border: 1.5px solid #059669; color: #059669; font-weight: 800; font-size: 0.58rem; padding: 3px 6px; border-radius: 4px; transform: rotate(-4deg); margin-top: 6px;">
                          OFFICIAL SEAL<br>PAID &amp; VERIFIED
                        </div>
                      `}
                    </div>
                    <div style="margin-top: auto; padding-bottom: 2px;">
                      <div style="width: 65px; border-bottom: 1px solid ${l.subText}; margin-bottom: 2px; margin-left: auto; margin-right: auto;"></div>
                      <div style="font-size: 0.55rem; color: ${l.subText}; font-weight: 600;">Auth. Signatory</div>
                    </div>
                  `:""}
                </div>
              </div>

              <!-- Footer -->
              <div style="background: ${l.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 4px 12px; text-align: center; font-size: 0.60rem; color: ${l.subText};">
                ${o(p.phone?`Helpline: ${p.phone}`:"")}${p.phone&&p.address?" \u2022 ":""}${o(p.address||"")}
              </div>
            </div>
          `};let xe="";const le=G==="vertical",pe=le?"400px":"240px";H==="front"?xe=`
          <div style="display: flex; justify-content: center; align-items: center; padding: 6px 0;">
            ${oe(le)}
          </div>
        `:H==="back"?xe=`
          <div style="display: flex; justify-content: center; align-items: center; padding: 6px 0;">
            ${ce(le)}
          </div>
        `:xe=`
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
              ${oe(le)}
            </div>

            <!-- Perfectly Centered Vertical Fold / Cut Line -->
            <div class="id-cut-separator" style="
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              position: relative;
              height: ${pe};
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
                font-size: 0.78rem;
                line-height: 1;
                color: var(--color-text-secondary, #94a3b8);
                box-shadow: 0 2px 8px rgba(0,0,0,0.25);
                z-index: 2;
              " title="Fold / Cut Line">\u2702\uFE0F</span>
            </div>

            <!-- Back Column -->
            <div style="display: flex; flex-direction: column; align-items: center; flex-shrink: 0;">
              <div style="font-size: 0.75rem; font-weight: 800; text-align: center; margin-bottom: 6px; color: var(--color-primary); letter-spacing: 0.5px;">\u{1F4C4} BACK SIDE</div>
              ${ce(le)}
            </div>
          </div>
        `,A.innerHTML=`
        <div style="display: flex; flex-direction: column; gap: 14px;">
          <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; margin-bottom: 12px;">
              <div style="display: flex; align-items: center; gap: 6px;">
                <label style="font-size: 0.8rem; font-weight: 700; margin: 0;">\u{1F4D0} Orientation:</label>
                <div class="btn-group btn-group-sm">
                  <button type="button" class="btn ${G==="horizontal"?"btn-primary":"btn-outline-secondary"} btn-opt-horiz" style="font-size: 0.76rem; font-weight: 700;">\u{1F504} Horizontal</button>
                  <button type="button" class="btn ${G==="vertical"?"btn-primary":"btn-outline-secondary"} btn-opt-vert" style="font-size: 0.76rem; font-weight: 700;">\u{1F4F1} Vertical</button>
                </div>
              </div>

              <div style="display: flex; align-items: center; gap: 6px;">
                <label style="font-size: 0.8rem; font-weight: 700; margin: 0;">\u{1F4D1} Card Side:</label>
                <div class="btn-group btn-group-sm">
                  <button type="button" class="btn ${H==="front"?"btn-primary":"btn-outline-secondary"} btn-side-front" style="font-size: 0.76rem; font-weight: 700;">\u{1FAAA} Front</button>
                  <button type="button" class="btn ${H==="back"?"btn-primary":"btn-outline-secondary"} btn-side-back" style="font-size: 0.76rem; font-weight: 700;">\u{1F4C4} Back</button>
                  <button type="button" class="btn ${H==="dual"?"btn-primary":"btn-outline-secondary"} btn-side-dual" style="font-size: 0.76rem; font-weight: 700;">\u{1F4D1} Both Sides</button>
                </div>
              </div>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; border-top: 1px solid var(--color-border); padding-top: 10px;">
              <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
                <div>
                  <label style="font-size: 0.75rem; font-weight: 700; display: block; margin-bottom: 2px;">Color Theme</label>
                  <div style="display: flex; align-items: center; gap: 6px;">
                    <input type="color" id="id-studio-color" value="${q}" style="width: 32px; height: 28px; border: none; padding: 0; cursor: pointer; border-radius: 4px;">
                    <select id="id-studio-theme-select" class="form-select form-select-sm" style="font-size: 0.78rem; min-width: 120px;">
                      <option value="gradient" ${x==="gradient"?"selected":""}>\u{1F7E3} Purple Indigo</option>
                      <option value="dark" ${x==="dark"?"selected":""}>\u26AB Dark Slate Pro</option>
                      <option value="minimal" ${x==="minimal"?"selected":""}>\u26AA Minimal Classic</option>
                    </select>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div id="id-card-render-stage" style="padding: 14px 10px; display: flex; justify-content: center; align-items: center; background: radial-gradient(circle, rgba(108,92,231,0.06) 0%, transparent 70%); border-radius: var(--radius-md); overflow-x: auto; width: 100%; box-sizing: border-box;">
            ${xe}
          </div>

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
              <button type="button" class="btn btn-success btn-sm" id="btn-print-portal-id-card" style="font-weight: 800; padding: 6px 18px;">
                \u{1F5A8}\uFE0F Print ID Card (Front + Back)
              </button>
              <button type="button" class="btn btn-secondary btn-sm" id="btn-close-portal-id-studio">Close</button>
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
              border: 2.5px solid #000000 !important;
              outline: 1.5px dashed #475569 !important;
              outline-offset: 5px !important;
              -webkit-print-color-adjust: exact !important;
              print-color-adjust: exact !important;
              box-shadow: none !important;
              break-inside: avoid !important;
              page-break-inside: avoid !important;
            }
          }
        </style>
      `,A.querySelector(".btn-opt-horiz")?.addEventListener("click",()=>{G="horizontal",C()}),A.querySelector(".btn-opt-vert")?.addEventListener("click",()=>{G="vertical",C()}),A.querySelector(".btn-side-front")?.addEventListener("click",()=>{H="front",C()}),A.querySelector(".btn-side-back")?.addEventListener("click",()=>{H="back",C()}),A.querySelector(".btn-side-dual")?.addEventListener("click",()=>{H="dual",C()}),A.querySelector("#id-studio-color")?.addEventListener("input",V=>{q=V.target.value,C()}),A.querySelector("#id-studio-theme-select")?.addEventListener("change",V=>{x=V.target.value,C()}),A.querySelector("#btn-close-portal-id-studio")?.addEventListener("click",()=>{k&&k.close()}),A.querySelector("#btn-print-portal-id-card")?.addEventListener("click",()=>{H!=="dual"&&(H="dual",C()),setTimeout(()=>{window.print()},300)});const se=async(V,l)=>{try{window.html2canvas||await new Promise((Pe,Le)=>{const me=document.createElement("script");me.src="https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js",me.onload=Pe,me.onerror=Le,document.head.appendChild(me)});const ee=A.querySelector(V);if(!ee){S.warning("Please switch to the selected side first.");return}const Ae=await window.html2canvas(ee,{scale:3,useCORS:!0,backgroundColor:null}),ue=document.createElement("a");ue.download=l,ue.href=Ae.toDataURL("image/png"),ue.click(),S.success("ID Card downloaded successfully!")}catch(ee){S.error("PNG download error: "+ee.message)}};A.querySelector("#btn-download-front-png")?.addEventListener("click",()=>{se(".id-card-front",`ID_Front_${(t.studentId||t.name).replace(/\s+/g,"_")}.png`)}),A.querySelector("#btn-download-back-png")?.addEventListener("click",()=>{se(".id-card-back",`ID_Back_${(t.studentId||t.name).replace(/\s+/g,"_")}.png`)}),A.querySelector("#btn-download-1080p-pass")?.addEventListener("click",()=>{Ve(t,p,ae,te,ie,be,{shiftName:$,phone:m,bloodGroup:D,showBlood:W})})};C(),k=new re({title:`\u{1FAAA} Student ID Pass Studio: ${o(t.name)}`,content:A,size:"xl"}),k.show()}),n.querySelector("#btn-portal-complete-kyc")?.addEventListener("click",()=>{n.querySelector("#btn-portal-profile")?.click()}),n.querySelector("#btn-portal-logout")?.addEventListener("click",async()=>{await Ze.show("Are you sure you want to sign out of the Student Portal?","Sign Out")&&(localStorage.removeItem("sl_token"),localStorage.removeItem("student_token"),localStorage.removeItem("sl_student_user"),localStorage.removeItem("sl_user_role"),window.store&&(window.store.user=null),window.location.href="/student-login")}),n.querySelector("#btn-portal-profile")?.addEventListener("click",async()=>{const a=document.createElement("div");a.innerHTML=`
      <div class="text-center p-4 text-muted">
        <div class="loading-spinner mb-2" style="margin: 0 auto;"></div>
        Loading complete admission profile...
      </div>
    `;const r=new re({title:"\u{1F464} My Admission Profile & Submitted Details",content:a,size:"lg"});r.show();try{let i=function(y){if(!y)return"";let c=String(y).trim();return c.includes("___")&&(c=c.replace(/___/g," / ")),c=c.replace(/_/g," "),c=c.replace(/([a-z])([A-Z])/g,"$1 $2"),c.split(" ").filter(Boolean).map(v=>v.charAt(0).toUpperCase()+v.slice(1).toLowerCase()).join(" ").replace(/\s*\/\s*/g," / ")},s=function(y,c){if(c==null||c==="")return'<span class="text-muted small">Not provided</span>';if(y.type==="star_rating"){const v=parseInt(c,10)||5;return`<span style="color: #f59e0b; font-size: 1.1rem;">${"\u2605".repeat(v)}${"\u2606".repeat(Math.max(0,5-v))}</span> <strong class="ms-1">(${v}/5)</strong>`}if(y.type==="checkbox"||y.type==="terms_checkbox"||y.type==="consent_checkbox")return c===!0||c==="true"||c==="on"||c===1?'<span class="badge badge-success">\u2705 Yes / Agreed</span>':'<span class="badge badge-secondary">\u274C No</span>';if(y.type==="photo_upload"||y.type==="file"||y.fieldName?.toLowerCase().includes("image")){const v=String(c).startsWith("data:image")||String(c).startsWith("/")?String(c):`/${c}`;return`
            <a href="${v}" target="_blank" style="display: inline-flex; align-items: center; gap: 6px; text-decoration: none; color: var(--color-primary); font-weight: 600; font-size: 0.85rem;">
              <img src="${v}" style="width: 44px; height: 44px; border-radius: 6px; object-fit: cover; border: 1px solid var(--color-border);" onerror="this.style.display='none'">
              <span>\u{1F50D} View Document</span>
            </a>
          `}return y.type==="blood_group"?`<span class="badge" style="background: rgba(239, 68, 68, 0.12); color: var(--color-danger); font-weight: 700;">\u{1FA78} ${o(c)}</span>`:y.type==="exam_badge"?(Array.isArray(c)?c:String(c).split(",").filter(Boolean)).map(v=>`<span class="badge badge-primary me-1">${o(v)}</span>`).join(" "):`<strong>${o(c)}</strong>`};const[u,f,h]=await Promise.all([P.get("/api/custom-fields/all").catch(()=>P.get("/api/custom-fields")).catch(()=>({data:[]})),P.get("/api/custom-fields/templates/active").catch(()=>({data:null})),P.get("/api/system/public-config").catch(()=>({data:null}))]),D=Array.isArray(u.data)?u.data:[],$=t.customFields&&typeof t.customFields=="object"?t.customFields:{},m=(...y)=>{for(const c of y){if(t[c]!==void 0&&t[c]!==null&&t[c]!=="")return t[c];if($[c]!==void 0&&$[c]!==null&&$[c]!=="")return $[c];const v=c.toLowerCase().replace(/[^a-z0-9]/g,"");for(const[N,K]of Object.entries($))if(N.toLowerCase().replace(/[^a-z0-9]/g,"")===v&&K!==void 0&&K!==null&&K!=="")return K}return""},d=m("dob","dateOfBirth","birthDate"),B=d?new Date(d).toString()!=="Invalid Date"?new Date(d).toLocaleDateString("en-IN"):d:"N/A",j=m("bloodGroup","blood_group"),G=m("address","residentialAddress")||[t.address,t.city,t.state,t.pincode].filter(Boolean).join(", ")||"N/A",H=m("pincode","pinCode","postalCode")||"N/A",q=m("city","town")||"",x=m("state","province")||"",F=m("emergencyContactName","emergencyName")||t.emergencyContact?.name||"N/A",z=m("emergencyContactPhone","emergencyPhone")||t.emergencyContact?.phone||"N/A",Y=m("emergencyContactRelation","emergencyRelation")||t.emergencyContact?.relation||"Parent / Guardian",W=m("idProofType","idType")||t.idProof?.type||"Aadhaar Card",A=m("idProofNumber","idNumber")||t.idProof?.number||"",k=m("idProofImage","idProof","idProofPhoto")||t.idProof?.image||"",C=m("targetExams","targetExam")||t.targetExams||[],U=Array.isArray(C)?C:String(C).split(",").map(y=>y.trim()).filter(Boolean),X=m("college","collegeName","institute","university")||"",oe=m("qualification","highestQualification","degree")||"",ce=m("remarks","notes","specialRemarks")||"",xe=new Set(["name","fullname","phone","mobile","whatsapp","email","gender","sex","dob","dateofbirth","birthdate","bloodgroup","blood_group","address","residentialaddress","pincode","postalcode","city","state","emergencyname","emergencycontactname","emergencyphone","emergencycontactphone","emergencyrelation","emergencycontactrelation","idtype","idprooftype","idnumber","idproofnumber","idproof","idproofimage","idproofphoto","targetexam","targetexams","college","collegename","institute","university","qualification","highestqualification","branch","plan","shift","seat","password","photo","signature","status","remarks","specialremarks","notes"]),le=f?.data?.sections&&Array.isArray(f.data.sections)?f.data.sections:[],pe=[];Object.entries($).forEach(([y,c])=>{const v=y.toLowerCase().replace(/[^a-z0-9]/g,"");if(!xe.has(v)&&c!==void 0&&c!==null&&c!==""){const N=D.find(K=>{const Re=K.fieldName?.toLowerCase().replace(/[^a-z0-9]/g,""),Ke=K.label?.toLowerCase().replace(/[^a-z0-9]/g,"");return Re===v||Ke===v});pe.push({key:y,label:N?.label||N?.fieldLabel||i(y),value:c,section:N?.section||"additional",order:N?.order!==void 0?N.order:999,type:N?.type||"text"})}});let se="";se+=`
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
            <span>\u{1F464}</span> Personal &amp; Emergency Contact Details
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; font-size: 0.88rem;">
            <div><span class="text-muted d-block small">Full Name</span><strong>${o(t.name)}</strong></div>
            <div><span class="text-muted d-block small">Mobile Phone (WhatsApp)</span><strong>${o(we.phone(t.phone))}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${o(t.phone||"")}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">\u{1F4CB}</button></div>
            <div><span class="text-muted d-block small">Email Address</span><strong>${o(t.email||"N/A")}</strong></div>
            <div><span class="text-muted d-block small">Gender</span><strong style="text-transform: capitalize;">${o(t.gender||"N/A")}</strong></div>
            <div><span class="text-muted d-block small">Date of Birth</span><strong>${o(B)}</strong></div>
            <div><span class="text-muted d-block small">Blood Group</span>${j?`<span class="badge" style="background: rgba(239, 68, 68, 0.12); color: var(--color-danger); font-weight: 700;">\u{1FA78} ${o(j)}</span>`:'<span class="text-muted small">Not specified</span>'}</div>
            <div style="grid-column: 1 / -1;"><span class="text-muted d-block small">Residential / Hostel Address</span><strong>${o(G)}</strong></div>
            <div><span class="text-muted d-block small">City &amp; State</span><strong>${o(q||t.city||"")}${x||t.state?", "+o(x||t.state):""}</strong></div>
            <div><span class="text-muted d-block small">Pincode</span><strong>${o(H)}</strong></div>
            <div><span class="text-muted d-block small">Emergency Contact</span><strong>${o(F)} (${o(Y)})</strong></div>
            <div><span class="text-muted d-block small">Emergency Phone</span><strong>${o(we.phone(z))}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${o(z||"")}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Emergency Phone">\u{1F4CB}</button></div>
          </div>
        </div>
      `,se+=`
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
            <span>\u{1FAAA}</span> Government ID &amp; KYC Verification
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; font-size: 0.88rem;">
            <div>
              <span class="text-muted d-block small">ID Proof Type</span>
              <strong>${o(W)}</strong>
            </div>
            <div>
              <span class="text-muted d-block small">ID Proof Document Number</span>
              <strong style="font-family: monospace; letter-spacing: 0.5px;">${o(W==="Aadhaar Card"||W==="Aadhaar"||!W?we.aadhaar(A):A||"Verified")}</strong>
              ${A?`<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${o(A)}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy ID Proof Number">\u{1F4CB}</button>`:""}
            </div>
            ${k?`
              <div>
                <span class="text-muted d-block small">ID Proof Document Upload</span>
                <a href="${k.startsWith("/")?k:"/"+k}" target="_blank" class="btn btn-xs btn-outline-primary mt-1" style="font-weight: 600;">
                  \u{1F50D} View Document Scan
                </a>
              </div>
            `:""}
          </div>
        </div>
      `,se+=`
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
            <span>\u{1F3AF}</span> Academic Goals &amp; Education
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; font-size: 0.88rem;">
            <div>
              <span class="text-muted d-block small">Target Competitive Exams</span>
              <div>${U.length>0?U.map(y=>`<span class="badge badge-primary me-1 mb-1" style="font-weight: 700;">${o(y)}</span>`).join(""):'<span class="text-muted small">None specified</span>'}</div>
            </div>
            ${X?`
              <div>
                <span class="text-muted d-block small">College / Institute / Company</span>
                <strong>${o(X)}</strong>
              </div>
            `:""}
            ${oe?`
              <div>
                <span class="text-muted d-block small">Highest Qualification</span>
                <strong>${o(oe)}</strong>
              </div>
            `:""}
          </div>
        </div>
      `;const V={personal:"\u{1F464}",academic:"\u{1F3AF}",plan:"\u23F0",payment:"\u{1F4B3}",seat:"\u{1FA91}",contact:"\u{1F4CD}",kyc:"\u{1FAAA}",parent:"\u{1F468}\u200D\u{1F469}\u200D\u{1F467}",vehicle:"\u{1F697}",transport:"\u{1F6B2}",custom:"\u{1F4CB}",additional:"\u{1F4DD}",other:"\u{1F4DD}"},l=[];if(le.length>0){le.forEach(v=>{const N=pe.filter(K=>K.section===v.name).sort((K,Re)=>K.order-Re.order);N.length>0&&l.push({name:v.name,label:v.label||i(v.name),icon:v.icon&&v.icon.length<=4?v.icon:V[v.name]||"\u{1F4CB}",fields:N})});const y=new Set(l.flatMap(v=>v.fields.map(N=>N.key))),c=pe.filter(v=>!y.has(v.key));(c.length>0||ce)&&l.push({name:"additional",label:"Additional Information & Preferences",icon:"\u{1F4DD}",fields:c.sort((v,N)=>v.order-N.order),remarks:ce})}else(pe.length>0||ce)&&l.push({name:"additional",label:"Additional Information & Preferences",icon:"\u{1F4DD}",fields:pe.sort((y,c)=>y.order-c.order),remarks:ce});l.forEach(y=>{se+=`
          <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
            <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
              <span>${y.icon}</span> ${o(y.label)}
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px; font-size: 0.88rem;">
              ${y.remarks?`
                <div style="grid-column: 1 / -1;">
                  <span class="text-muted d-block small">Special Remarks / Notes</span>
                  <strong>${o(y.remarks)}</strong>
                </div>
              `:""}
              ${y.fields.map(c=>`
                <div>
                  <span class="text-muted d-block small">${o(c.label)}</span>
                  <div>${s(c,c.value)}</div>
                </div>
              `).join("")}
            </div>
          </div>
        `}),t.signature&&(se+=`
          <div class="mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
            <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
              <span>\u270D\uFE0F</span> Official Digital Signature
            </div>
            <div style="background: #ffffff; padding: 12px; border-radius: 8px; border: 1px solid var(--color-border); display: inline-block;">
              <img src="${t.signature}" style="max-height: 90px; max-width: 280px; object-fit: contain; display: block;">
            </div>
            <div class="text-muted small mt-2">Digitally acknowledged upon admission enrollment.</div>
          </div>
        `),a.innerHTML=`
        <div style="font-family: var(--font-family);">
          <!-- Student Card Header with Photo Avatar Upload -->
          <div class="card p-3 mb-4" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.1), rgba(0, 184, 148, 0.06)); border: 1.5px solid var(--color-primary); border-radius: 12px;">
            <div style="display: flex; gap: 1rem; align-items: center; justify-content: space-between; flex-wrap: wrap;">
              
              <div style="display: flex; gap: 1rem; align-items: center; flex-wrap: wrap;">
                <div style="display: flex; flex-direction: column; align-items: center; gap: 6px;">
                  <div id="sp-avatar-container" style="width: 76px; height: 76px; border-radius: 50%; background: var(--color-primary); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 1.75rem; font-weight: 800; border: 3px solid var(--color-surface); box-shadow: var(--shadow-sm); overflow: hidden; position: relative;">
                    <img id="sp-avatar-img" src="${t.photo?t.photo.startsWith("/")?t.photo:"/"+t.photo:""}" style="width: 100%; height: 100%; object-fit: cover; display: ${t.photo?"block":"none"};" onerror="this.style.display='none'; document.getElementById('sp-avatar-initials').style.display='block';">
                    <span id="sp-avatar-initials" style="display: ${t.photo?"none":"block"};">${o(ae)}</span>
                  </div>
                  <div style="display: flex; gap: 4px;">
                    <button type="button" id="btn-sp-upload-photo" class="btn btn-xs btn-outline-primary" style="font-size: 0.7rem; padding: 2px 6px; font-weight: 600;" title="Upload Passport Photo">\u{1F4C1} Upload</button>
                    <button type="button" id="btn-sp-selfie" class="btn btn-xs btn-primary" style="font-size: 0.7rem; padding: 2px 6px; font-weight: 600;" title="Take Live Selfie">\u{1F4F8} Selfie</button>
                    <input type="file" id="input-sp-photo" accept="image/*" style="display: none;">
                  </div>
                </div>

                <div>
                  <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    <h3 style="margin: 0; font-size: 1.35rem; font-weight: 800; color: var(--color-text-primary);">${o(t.name)}</h3>
                    <span class="badge ${t.status==="active"?"badge-success":"badge-warning"}" style="text-transform: uppercase;">
                      ${o(t.status||"Active")}
                    </span>
                  </div>
                  <div style="display: flex; gap: 14px; font-size: 0.85rem; color: var(--color-text-secondary); margin-top: 4px; flex-wrap: wrap;">
                    <span>Student ID: <strong style="font-family: monospace; color: var(--color-primary); font-size: 0.95rem;">${o(t.studentId||"N/A")}</strong></span>
                    <span>Desk: <strong>${te}</strong></span>
                    <span>Branch: <strong>${o(t.branch?.name||p.businessName||"Main Campus")}</strong></span>
                  </div>
                </div>
              </div>

              <!-- Profile Lock Status Badge -->
              <div style="text-align: right;">
                ${t.profileCompletion>=100||t.isProfileComplete?`
                  <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border: 1px solid rgba(0, 184, 148, 0.3);">
                    \u{1F512} 100% Profile Verified & Locked
                  </span>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary); margin-top: 4px;">
                    Contact Admin to modify details
                  </div>
                `:`
                  <span class="badge" style="background: rgba(245, 158, 11, 0.15); color: #f59e0b; font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border: 1px solid rgba(245, 158, 11, 0.3);">
                    \u{1F7E1} ${t.profileCompletion||60}% KYC Pending
                  </span>
                  <div style="font-size: 0.72rem; color: #f59e0b; margin-top: 4px; font-weight: 600;">
                    Complete profile below
                  </div>
                `}
              </div>

            </div>
          </div>

          <!-- If Profile Incomplete: Show Interactive KYC Completion Form -->
          ${t.profileCompletion<100||!t.isProfileComplete?`
            <form id="form-student-kyc-complete" class="mb-4">
              <div class="alert alert-warning mb-3 p-3" style="background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: 8px;">
                <div style="font-weight: 700; color: #d97706; margin-bottom: 2px;">\u26A0\uFE0F Complete Admission Profile & KYC Upload</div>
                <div style="font-size: 0.82rem; color: var(--color-text-secondary);">
                  Admin pre-filled your admission info! Please complete your DOB, Address, Parent Contact, and Aadhaar KYC scan to unlock your Digital Offline ID Card Pass.
                </div>
              </div>

              <!-- Section 1: \u{1F464} Personal & Identification Details -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>\u{1F464}</span> Personal & Identification Details
                </div>
                <div class="row g-2">
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Full Name (Admin Pre-filled)</label>
                    <input type="text" class="form-control form-control-sm" value="${o(t.name)}" disabled style="background: rgba(255,255,255,0.05); font-weight: 600;">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Mobile Phone (WhatsApp) (Admin Pre-filled)</label>
                    <input type="text" class="form-control form-control-sm" value="${o(t.phone)}" disabled style="background: rgba(255,255,255,0.05); font-weight: 600;">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Email Address</label>
                    <input type="email" id="kyc-email" name="email" class="form-control form-control-sm" value="${o(t.email||"")}" placeholder="student@example.com">
                  </div>
                  <div class="col-md-3">
                    <label class="form-label small font-weight-bold">Gender</label>
                    <select id="kyc-gender" name="gender" class="form-select form-select-sm">
                      <option value="male" ${t.gender==="male"?"selected":""}>Male</option>
                      <option value="female" ${t.gender==="female"?"selected":""}>Female</option>
                      <option value="other" ${t.gender==="other"?"selected":""}>Other</option>
                    </select>
                  </div>
                  <div class="col-md-3">
                    <label class="form-label small font-weight-bold">Date of Birth *</label>
                    <input type="date" id="kyc-dob" name="dob" class="form-control form-control-sm" value="${t.dateOfBirth?new Date(t.dateOfBirth).toISOString().split("T")[0]:t.dob?new Date(t.dob).toISOString().split("T")[0]:""}" required>
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Blood Group</label>
                    <select id="kyc-bloodGroup" name="bloodGroup" class="form-select form-select-sm">
                      <option value="">-- Select Blood Group --</option>
                      ${["A+","A-","B+","B-","O+","O-","AB+","AB-"].map(y=>`<option value="${y}" ${t.bloodGroup===y?"selected":""}>${y}</option>`).join("")}
                    </select>
                  </div>
                </div>
              </div>

              <!-- Section 2: \u{1F3AF} Academic Goals & Preparation -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>\u{1F3AF}</span> Academic Goals & Preparation
                </div>
                <div class="row g-2">
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Target Competitive Exams</label>
                    <input type="text" id="kyc-targetExams" name="targetExams" class="form-control form-control-sm" value="${o(Array.isArray(t.targetExams)?t.targetExams.join(", "):t.targetExams||"")}" placeholder="e.g. UPSC, MPSC, SSC, Banking, NEET">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">College / Coaching Institute / Company</label>
                    <input type="text" id="kyc-collegeOrCompany" name="collegeOrCompany" class="form-control form-control-sm" value="${o(t.collegeOrCompany||"")}" placeholder="e.g. Fergusson College / Self Study">
                  </div>
                </div>
              </div>

              <!-- Section 3: \u{1F4CD} Address & Emergency Contacts -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>\u{1F4CD}</span> Address & Emergency Contacts
                </div>
                <div class="row g-2">
                  <div class="col-12">
                    <label class="form-label small font-weight-bold">Residential Address / Hostel Room No. *</label>
                    <input type="text" id="kyc-address" name="address" class="form-control form-control-sm" value="${o(t.address||"")}" placeholder="Full residential address" required>
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">Pincode \u26A1</label>
                    <input type="text" id="kyc-pincode" name="pincode" class="form-control form-control-sm" value="${o(t.pincode||"")}" placeholder="6-digit pincode" maxlength="6">
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">City</label>
                    <input type="text" id="kyc-city" name="city" class="form-control form-control-sm" value="${o(t.city||"")}">
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">State</label>
                    <input type="text" id="kyc-state" name="state" class="form-control form-control-sm" value="${o(t.state||"")}">
                  </div>
                  <div class="col-md-5">
                    <label class="form-label small font-weight-bold">Parent / Guardian Name *</label>
                    <input type="text" id="kyc-emergencyContactName" name="emergencyContactName" class="form-control form-control-sm" value="${o(t.emergencyContact?.name||"")}" placeholder="e.g. Ramesh Sharma" required>
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">Parent / Guardian Phone *</label>
                    <input type="tel" id="kyc-emergencyContactPhone" name="emergencyContactPhone" class="form-control form-control-sm" value="${o(t.emergencyContact?.phone||"")}" placeholder="10-digit mobile" required>
                  </div>
                  <div class="col-md-3">
                    <label class="form-label small font-weight-bold">Relation</label>
                    <input type="text" id="kyc-emergencyContactRelation" name="emergencyContactRelation" class="form-control form-control-sm" value="${o(t.emergencyContact?.relation||"Parent")}" placeholder="Father / Mother">
                  </div>
                </div>
              </div>

              <!-- Section 4: \u{1FAAA} KYC & Identity Verification -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>\u{1FAAA}</span> KYC & Identity Verification
                </div>
                <div class="row g-2">
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Government ID Proof Type *</label>
                    <select id="kyc-idProofType" name="idProofType" class="form-select form-select-sm">
                      <option value="Aadhaar Card" ${t.idProof?.type==="Aadhaar Card"?"selected":""}>Aadhaar Card</option>
                      <option value="PAN Card" ${t.idProof?.type==="PAN Card"?"selected":""}>PAN Card</option>
                      <option value="Driving License" ${t.idProof?.type==="Driving License"?"selected":""}>Driving License</option>
                      <option value="Passport" ${t.idProof?.type==="Passport"?"selected":""}>Passport</option>
                      <option value="Voter ID" ${t.idProof?.type==="Voter ID"?"selected":""}>Voter ID</option>
                    </select>
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">ID Proof Document Number *</label>
                    <input type="text" id="kyc-idProofNumber" name="idProofNumber" class="form-control form-control-sm" value="${o(t.idProof?.number||"")}" placeholder="12-digit Aadhaar / ID number" required>
                  </div>
                  <div class="col-12 mt-2">
                    <label class="form-label small font-weight-bold">Upload Government ID Proof Scan / Photo</label>
                    <div id="mount-portal-idproof"></div>
                  </div>
                </div>
              </div>

              <div class="d-flex justify-content-end gap-2">
                <button type="submit" class="btn btn-success btn-sm" id="btn-save-kyc-profile-submit" style="font-weight: 700; padding: 8px 18px;">\u{1F4BE} Save & Complete Profile</button>
              </div>
            </form>
          `:""}

          <!-- Verified Section Tabs / Content -->
          ${se}

          <div class="d-flex justify-content-between align-items-center mt-4 pt-3 flex-wrap gap-2" style="border-top: 1px solid var(--color-border);">
            <div>
              ${t.profileCompletion>=100||t.isProfileComplete?`
                <button type="button" class="btn btn-outline-primary" id="btn-sp-download-pdf" style="font-weight: 700; font-size: 0.85rem;">
                  \u{1F4C4} Download Official Admission Form (PDF)
                </button>
              `:`
                <button type="button" class="btn btn-outline-secondary" disabled style="font-size: 0.8rem; font-weight: 600; opacity: 0.7;" title="Complete photo selfie & Aadhaar KYC above to unlock PDF download">
                  \u{1F512} Complete Profile to Unlock Admission Form (PDF)
                </button>
              `}
            </div>
            <div class="d-flex gap-2">
              <button type="button" class="btn btn-secondary" id="btn-close-profile-modal">Close</button>
            </div>
          </div>
        </div>
      `;const ee=a.querySelector("#btn-sp-upload-photo"),Ae=a.querySelector("#btn-sp-selfie"),ue=a.querySelector("#input-sp-photo"),Pe=a.querySelector("#sp-avatar-img"),Le=a.querySelector("#sp-avatar-initials"),me=a.querySelector("#mount-portal-idproof");me&&me.appendChild(et.create({label:"ID Proof Document Scan / Photo",preset:"document",name:"idProofImage",value:t.idProof?.image||""}));const _e=async(y,c)=>{try{c&&he.button(c,!0);const v=await P.post("/api/upload",{image:y});if(v.success&&v.url){const N=v.url;await P.put("/api/student-portal/profile",{photo:N}),Pe.src=N,Pe.style.display="block",Le.style.display="none";const K=auth.getUser();K&&(K.avatar=N,auth.setUser(K)),window.dispatchEvent(new CustomEvent("user-updated")),typeof window.updateProfileAvatar=="function"&&window.updateProfileAvatar(N),S.success("Passport photo updated & compressed successfully!")}else S.error(v.message||"Upload failed")}catch(v){S.error(v.message||"Failed to update photo")}finally{c&&he.button(c,!1)}};ee?.addEventListener("click",y=>{y.preventDefault(),y.stopPropagation(),ue.click()}),ue?.addEventListener("change",async y=>{y.preventDefault(),y.stopPropagation();const c=y.target.files[0];if(c)try{const v=await ImageCompressor.compress(c,{maxWidth:300,maxHeight:300,quality:.82});await _e(v,ee)}catch(v){S.error(v.message||"Image processing failed")}finally{ue.value=""}}),Ae?.addEventListener("click",async y=>{y.preventDefault(),y.stopPropagation();try{const c=await ImageCompressor.captureWebcam({maxWidth:300,maxHeight:300,quality:.82});await _e(c,Ae)}catch(c){c.message!=="Camera capture cancelled"&&S.error(c.message||"Selfie capture failed")}}),a.querySelector("#kyc-pincode")?.addEventListener("input",async y=>{const c=y.target.value.trim();if(c.length===6){const v=await Oe.lookupPincode(c);if(v&&v.city){const N=a.querySelector("#kyc-city"),K=a.querySelector("#kyc-state");N&&(N.value=v.city),K&&(K.value=v.state)}}}),Oe.bindDynamicIDProofValidation(a),a.querySelector("#form-student-kyc-complete")?.addEventListener("submit",async y=>{y.preventDefault();const c=a.querySelector("#btn-save-kyc-profile-submit");UI.buttonLoading(c,!0,"Saving...");try{const v={email:a.querySelector("#kyc-email")?.value?.trim(),gender:a.querySelector("#kyc-gender")?.value,dob:a.querySelector("#kyc-dob")?.value,bloodGroup:a.querySelector("#kyc-bloodGroup")?.value,targetExams:a.querySelector("#kyc-targetExams")?.value?.trim(),collegeOrCompany:a.querySelector("#kyc-collegeOrCompany")?.value?.trim(),address:a.querySelector("#kyc-address")?.value?.trim(),pincode:a.querySelector("#kyc-pincode")?.value?.trim(),city:a.querySelector("#kyc-city")?.value?.trim(),state:a.querySelector("#kyc-state")?.value?.trim(),emergencyContactName:a.querySelector("#kyc-emergencyContactName")?.value?.trim(),emergencyContactPhone:a.querySelector("#kyc-emergencyContactPhone")?.value?.trim(),emergencyContactRelation:a.querySelector("#kyc-emergencyContactRelation")?.value?.trim(),idProofType:a.querySelector("#kyc-idProofType")?.value,idProofNumber:a.querySelector("#kyc-idProofNumber")?.value?.trim(),idProofImage:a.querySelector("#mount-portal-idproof .mfp-hidden-value")?.value||""},N=await P.put("/api/student-portal/profile",v);N.success?(S.success("Profile & KYC details updated successfully! Profile is now 100% verified."),r.close(),renderPortalPage()):S.error(N.message||"Failed to update profile")}catch(v){S.error(v.message||"Failed to update profile")}finally{UI.buttonLoading(c,!1)}}),a.querySelector("#btn-close-profile-modal")?.addEventListener("click",()=>r.close()),a.querySelector("#btn-sp-download-pdf")?.addEventListener("click",()=>{r.close(),qe(t,{business:p})}),a.querySelector("#btn-modal-print-pdf")?.addEventListener("click",()=>{r.close(),qe(t,{business:p})})}catch(i){a.innerHTML=`<div class="text-danger p-3 text-center">Failed to load profile details: ${o(i.message)}</div>`}});const Z=async()=>{const a=document.createElement("div");a.innerHTML=`
      <form id="portal-leave-form" class="p-1 mb-4">
        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Start Date *</label>
            <input type="date" id="leave-start" class="form-control" value="${new Date().toISOString().split("T")[0]}" required>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">End Date *</label>
            <input type="date" id="leave-end" class="form-control" value="${new Date(Date.now()+864e5).toISOString().split("T")[0]}" required>
          </div>
        </div>
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Reason for Absence *</label>
          <textarea id="leave-reason" class="form-control" rows="2" placeholder="e.g. University Semester Exams, Visiting Home Town" required></textarea>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="submit" class="btn btn-primary" id="btn-submit-leave">Submit Leave Application</button>
        </div>
      </form>

      <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-border); padding-top: 12px; margin-bottom: 8px;">\u{1F4CB} My Past Leave Requests</h5>
      <div id="portal-leave-history" style="max-height: 220px; overflow-y: auto;">
        <div class="text-center p-3 text-muted">Loading leave history...</div>
      </div>
    `,new re({title:"\u{1F334} Leave & Absence Application",content:a,size:"md"}).show();const r=async()=>{try{const i=await P.get("/api/student-portal/leave"),s=a.querySelector("#portal-leave-history");i.success&&i.data.length>0?s.innerHTML=i.data.map(u=>`
            <div class="p-2 mb-2" style="background: var(--color-bg-secondary); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem;">
              <div class="d-flex justify-content-between align-items-center mb-1">
                <strong>${new Date(u.startDate).toLocaleDateString()} - ${new Date(u.endDate).toLocaleDateString()}</strong>
                <span class="badge ${u.status==="approved"?"badge-success":u.status==="rejected"?"badge-danger":"badge-warning"}">
                  ${u.status.toUpperCase()}
                </span>
              </div>
              <div class="text-muted">${o(u.reason)}</div>
            </div>
          `).join(""):s.innerHTML='<div class="text-center p-3 text-muted">No past leave applications.</div>'}catch{a.querySelector("#portal-leave-history").innerHTML='<div class="text-danger p-2">Failed to load history</div>'}};a.querySelector("#portal-leave-form").onsubmit=async i=>{i.preventDefault();const s=a.querySelector("#leave-start").value,u=a.querySelector("#leave-end").value,f=a.querySelector("#leave-reason").value;try{await P.post("/api/student-portal/leave",{startDate:s,endDate:u,reason:f}),S.success("Leave application submitted!"),a.querySelector("#leave-reason").value="",r()}catch(h){S.error(h.message||"Failed to submit leave")}},r()};n.querySelectorAll("#btn-portal-leave, #tile-portal-leave").forEach(a=>a.addEventListener("click",Z));const M=async()=>{const a=document.createElement("div");a.innerHTML=`
      <form id="portal-sc-form" class="p-1 mb-4">
        
        <!-- Target Library Branch / Centre Dropdown -->
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Target Library Branch / Centre *</label>
          <select id="sc-branch" class="form-select" required>
            <option value="">-- Select Target Library Centre --</option>
          </select>
        </div>

        <!-- Real-Time Vacant Seat Selector -->
        <div class="form-group mb-3">
          <div class="d-flex justify-content-between align-items-center mb-1">
            <label class="form-label" style="font-weight: 600; margin: 0;">Specific Desk / Seat (Optional Preference)</label>
            <span id="sc-vacant-badge" class="badge badge-success" style="font-size: 0.72rem; display: none;">\u{1F7E2} 0 Desks Vacant</span>
          </div>
          <select id="sc-target-seat" class="form-select">
            <option value="">-- Select Specific Available Desk (or Any Vacant) --</option>
          </select>
          <small class="text-muted" style="display: block; font-size: 0.75rem; margin-top: 3px;">
            Choose a specific desk or leave as "Any Vacant Desk" to let management auto-allot.
          </small>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Preferred Seat Zone *</label>
          <select id="sc-zone" class="form-select" required>
            <option value="AC Zone (Quiet Cabin)">AC Zone (Quiet Cabin)</option>
            <option value="Non-AC Reading Zone">Non-AC Reading Zone</option>
            <option value="Private Cabin Desk">Private Cabin Desk</option>
            <option value="Open Hall">Open Hall</option>
            <option value="Ladies Reserved Zone">Ladies Reserved Zone</option>
            <option value="Laptop Desk (Extra Power Plugs)">Laptop Desk (Extra Power Plugs)</option>
          </select>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Reason for Seat Transfer *</label>
          <textarea id="sc-reason" class="form-control" rows="2" placeholder="e.g. Requesting transfer to Main Centre AC cabin desk with laptop charging outlet." required></textarea>
        </div>

        <div class="d-flex justify-content-end gap-2">
          <button type="submit" class="btn btn-primary" id="btn-submit-sc" style="font-weight: 700; width: 100%;">\u26A1 Submit Transfer Request</button>
        </div>
      </form>

      <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-border); padding-top: 12px; margin-bottom: 8px;">\u{1F4CB} Past Transfer Requests</h5>
      <div id="portal-sc-history" style="max-height: 200px; overflow-y: auto;">
        <div class="text-center p-3 text-muted">Loading requests...</div>
      </div>
    `,new re({title:"\u{1F4BA} Request Desk / Seat Transfer",content:a,size:"md"}).show();const r=a.querySelector("#sc-branch"),i=a.querySelector("#sc-target-seat"),s=a.querySelector("#sc-vacant-badge");let u=[],f=[];try{const[$,m]=await Promise.all([P.get("/api/student-portal/branches").catch(()=>P.get("/api/branches/public-list")).catch(()=>({data:[]})),P.get("/api/student-portal/available-seats").catch(()=>P.get("/api/seats/public-available")).catch(()=>({data:[]}))]);u=Array.isArray($.data)?$.data:$.data?.branches||[],f=Array.isArray(m.data)?m.data:m.data?.seats||[],u.length>0?r.innerHTML=u.map((d,B)=>`
          <option value="${d._id}" ${String(d._id)===String(t.branch?._id||t.branch)||B===0&&!t.branch?"selected":""}>
            ${o(d.name)} ${d.city?"("+o(d.city)+")":""}
          </option>
        `).join(""):r.innerHTML=`<option value="">${o(p.businessName||"Main Centre")}</option>`,h()}catch($){console.warn("Failed to load branches/seats:",$)}function h(){const $=r.value,m=f.filter(d=>{if(!(d.status==="available"||d.status==="vacant"))return!1;if(!$)return!0;const B=d.branch?._id||d.branch;return!B||String(B)===String($)||$==="default_main"});s&&(s.style.display="inline-block",s.textContent=`\u{1F7E2} ${m.length} Desks Vacant`),m.length>0?i.innerHTML='<option value="">-- Select Specific Available Desk (or Any Vacant) --</option>'+m.map(d=>`
            <option value="${d._id}" data-num="${o(d.seatNumber)}">
              Desk ${o(d.seatNumber)} \u2014 ${o(d.zone||"General Zone")} (\u{1F7E2} Vacant)
            </option>
          `).join(""):i.innerHTML='<option value="">No specific vacant desks listed (Management will allot)</option>'}r.addEventListener("change",h);async function D(){const $=a.querySelector("#portal-sc-history");try{const m=(await P.get("/api/student-portal/seat-changes")).data||[];if(m.length===0){$.innerHTML='<p class="text-muted small text-center p-2">No transfer requests submitted yet.</p>';return}$.innerHTML=m.map(d=>`
          <div class="p-2 mb-2" style="background: var(--color-bg-primary); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem;">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <strong>Requested: ${o(d.targetSeatNumber?"Desk "+d.targetSeatNumber:d.preferredZone)} ${d.targetBranchName?"("+o(d.targetBranchName)+")":""}</strong>
              <span class="badge ${d.status==="approved"?"badge-success":d.status==="rejected"?"badge-danger":"badge-warning"}" style="text-transform: uppercase; font-size: 0.7rem;">
                ${d.status}
              </span>
            </div>
            <div class="text-muted small">${o(d.reason)}</div>
            ${d.adminReply?`<div style="color: var(--color-primary); font-size: 0.75rem; margin-top: 4px;">Admin: ${o(d.adminReply)}</div>`:""}
          </div>
        `).join("")}catch{$.innerHTML='<p class="text-danger small text-center">Failed to load history</p>'}}a.querySelector("#portal-sc-form").onsubmit=async $=>{$.preventDefault();const m=r.value,d=u.find(F=>String(F._id)===String(m)),B=d?d.name:"",j=i.value,G=i.options[i.selectedIndex],H=G&&G.dataset?.num||"",q=a.querySelector("#sc-zone").value,x=a.querySelector("#sc-reason").value.trim();try{await P.post("/api/student-portal/seat-change",{targetBranch:m,targetBranchName:B,targetSeat:j,targetSeatNumber:H,preferredZone:q,reason:x}),S.success("Seat transfer request submitted to branch manager!"),a.querySelector("#sc-reason").value="",D()}catch(F){S.error(F.message||"Failed to submit request")}},D()};n.querySelectorAll("#btn-portal-seat-change, #tile-portal-seat-change").forEach(a=>a.addEventListener("click",M));const $e=async()=>{const a=document.createElement("div");a.innerHTML=`
      <div style="font-family: 'Outfit', sans-serif;">
        <div class="text-center p-3 text-muted">
          <div class="loading-spinner mb-2" style="margin: 0 auto;"></div>
          Loading your Referral Studio...
        </div>
      </div>
    `;const r=new re({title:"\u{1F381} Student Referral Studio & Rewards",content:a,size:"md"});r.show();try{const i=await P.get("/api/student-portal/referral-stats");if(!i.success)throw new Error(i.message);const{referralCode:s,referralCredits:u,totalReferralsCount:f,config:h,referrals:D=[]}=i.data,$=`${window.location.origin}/register?ref=${encodeURIComponent(s)}`,m=encodeURIComponent(`Hey! I study at ${p.businessName||"the study library"}. Use my referral code *${s}* to get \u20B9${h?.refereeRewardAmount||100} instant discount on your admission! Register here: ${$}`);a.innerHTML=`
        <div style="font-family: 'Outfit', sans-serif;">
          <!-- Highlight Reward Banner -->
          <div class="card p-3 mb-3" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.12), rgba(0, 184, 148, 0.08)); border: 1px solid rgba(108, 92, 231, 0.25); border-radius: 10px;">
            <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px;">
              <div>
                <strong style="color: var(--color-primary); font-size: 1.05rem; display: block;">
                  \u{1F381} Give \u20B9${h?.refereeRewardAmount||100}, Get \u20B9${h?.referrerRewardAmount||100}!
                </strong>
                <p style="margin: 2px 0 0 0; font-size: 0.8rem; color: var(--color-text-secondary);">
                  Every friend who joins using your code gives you a <strong>\u20B9${h?.referrerRewardAmount||100} discount</strong> on your next renewal.
                </p>
              </div>

              <!-- Referral Wallet Badge -->
              <div style="text-align: right; background: var(--color-surface); padding: 6px 12px; border-radius: 8px; border: 1px solid var(--color-border);">
                <div style="font-size: 0.72rem; color: var(--color-text-muted); font-weight: 700; text-transform: uppercase;">Available Renewal Credit</div>
                <div style="font-size: 1.25rem; font-weight: 800; color: var(--color-success);">\u20B9${u}</div>
              </div>
            </div>
          </div>

          <!-- Referral Code & Share Link Section -->
          <div style="background: var(--color-bg-secondary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border); margin-bottom: 1rem;">
            <label class="form-label" style="font-weight: 700; font-size: 0.85rem; margin-bottom: 6px;">Your Unique Referral Code</label>
            
            <div style="display: flex; gap: 8px; align-items: center; margin-bottom: 10px;">
              <div id="display-ref-code" style="font-family: monospace; font-size: 1.3rem; font-weight: 800; color: var(--color-primary); background: var(--color-surface); padding: 6px 14px; border-radius: 6px; border: 1px solid var(--color-border); flex-grow: 1; letter-spacing: 1px;">
                ${o(s)}
              </div>
              <button type="button" class="btn btn-outline-primary btn-sm" id="btn-copy-ref-code" style="font-weight: 700;">
                \u{1F4CB} Copy Code
              </button>
            </div>

            <!-- Custom Vanity Code Toggle / Form -->
            <div style="display: flex; gap: 6px; align-items: center; margin-bottom: 12px;">
              <input type="text" id="custom-code-input" class="form-control form-control-sm" placeholder="Set custom vanity code (e.g. ${o(ae)}2026)" style="font-family: monospace; text-transform: uppercase;">
              <button type="button" class="btn btn-secondary btn-sm" id="btn-save-custom-code" style="white-space: nowrap; font-weight: 600;">
                \u270F\uFE0F Save Code
              </button>
            </div>

            <!-- 1-Click WhatsApp Sharing Pill & Link -->
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
              <a href="https://wa.me/?text=${m}" target="_blank" class="btn btn-success btn-sm" style="font-weight: 700; flex: 1; text-align: center; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 6px;">
                <span>\u{1F4F2} Share on WhatsApp</span>
              </a>
              <button type="button" class="btn btn-outline-secondary btn-sm" id="btn-copy-ref-link" style="font-weight: 600;">
                \u{1F517} Copy Direct Registration Link
              </button>
            </div>
          </div>

          <!-- Direct Friend Referral Form -->
          <div style="border-top: 1px solid var(--color-divider); padding-top: 12px; margin-bottom: 12px;">
            <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 8px; color: var(--color-text-primary);">
              \u{1F4E8} Or Submit Friend's Details Directly
            </h5>
            <form id="portal-ref-form">
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 8px; margin-bottom: 8px;">
                <div>
                  <input type="text" id="ref-name" class="form-control form-control-sm" placeholder="Friend's Full Name *" required>
                </div>
                <div>
                  <input type="tel" id="ref-phone" class="form-control form-control-sm" placeholder="10-digit Phone No. *" required>
                </div>
              </div>
              <div style="display: flex; gap: 8px;">
                <input type="text" id="ref-notes" class="form-control form-control-sm" placeholder="Target exam or course (e.g. UPSC, CA, NEET)">
                <button type="submit" class="btn btn-primary btn-sm" id="btn-submit-ref" style="font-weight: 700; white-space: nowrap;">
                  Submit Lead
                </button>
              </div>
            </form>
          </div>

          <!-- Referral History / Friends Ledger -->
          <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-divider); padding-top: 12px; margin-bottom: 8px; color: var(--color-text-primary);">
            \u{1F389} My Referred Friends (${D.length})
          </h5>
          <div id="portal-ref-history" style="max-height: 180px; overflow-y: auto;">
            ${D.length>0?D.map(d=>`
              <div class="p-2 mb-2" style="background: var(--color-surface); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem; display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <strong>${o(d.refereeName)}</strong>
                  <div class="text-muted small">${o(d.refereePhone)} \u2022 ${o(d.targetExam||"General")}</div>
                </div>
                <div style="text-align: right;">
                  <span class="badge ${d.status==="rewarded"?"badge-success":d.status==="joined"?"badge-primary":"badge-warning"}" style="text-transform: uppercase; font-size: 0.7rem;">
                    ${o(d.status)}
                  </span>
                  <div style="font-size: 0.75rem; color: var(--color-success); font-weight: 700; margin-top: 2px;">
                    \u20B9${d.rewardAmount||100}
                  </div>
                </div>
              </div>
            `).join(""):`
              <p class="text-muted small text-center p-2">No referrals submitted yet. Share your code with friends to start earning renewal discounts!</p>
            `}
          </div>
        </div>
      `,a.querySelector("#btn-copy-ref-code")?.addEventListener("click",d=>{Be(s,d.currentTarget)}),a.querySelector("#btn-copy-ref-link")?.addEventListener("click",d=>{Be($,d.currentTarget)}),a.querySelector("#btn-save-custom-code")?.addEventListener("click",async()=>{const d=a.querySelector("#custom-code-input"),B=d.value.trim().toUpperCase();if(!B){S.error("Please enter a custom code");return}try{const j=await P.put("/api/student-portal/custom-referral-code",{code:B});j.success?(S.success(j.message),a.querySelector("#display-ref-code").textContent=B,d.value=""):S.error(j.message)}catch(j){S.error(j.message||"Failed to update code")}}),a.querySelector("#portal-ref-form")?.addEventListener("submit",async d=>{d.preventDefault();const B=a.querySelector("#ref-name").value.trim(),j=a.querySelector("#ref-phone").value.trim(),G=a.querySelector("#ref-notes").value.trim();try{const H=await P.post("/api/student-portal/referral",{refereeName:B,refereePhone:j,targetExam:G});H.success?(S.success("Friend referral submitted! Thank you!"),r.close()):S.error(H.message)}catch(H){S.error(H.message||"Failed to submit referral")}})}catch(i){a.innerHTML=`<div class="text-danger p-4 text-center">Failed to load referral studio: ${o(i.message)}</div>`}};n.querySelectorAll("#btn-portal-referral, #tile-portal-referral").forEach(a=>a.addEventListener("click",$e));const ne=n.querySelectorAll(".btn-campus-tab"),O=n.querySelector("#campus-tab-content-container");async function R(a){if(ne.forEach(r=>{r.dataset.tab===a?r.className="btn btn-primary btn-campus-tab active":r.className="btn btn-outline-secondary btn-campus-tab"}),!!O){if(O.innerHTML='<div class="text-center p-4 text-muted"><div class="loading-spinner mb-2" style="margin: 0 auto;"></div>Loading...</div>',a==="notices")try{const r=(await P.get("/api/student-portal/announcements")).data||[];if(r.length===0){O.innerHTML='<div class="text-center p-4 text-muted">No campus circulars or notice board alerts at this time.</div>';return}O.innerHTML=`
          <div style="display: flex; flex-direction: column; gap: 12px;">
            ${r.map(i=>`
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid ${i.isPinned?"var(--color-primary)":"var(--color-border)"}; border-radius: var(--radius-md); box-shadow: ${i.isPinned?"0 4px 12px rgba(99, 102, 241, 0.12)":"none"};">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 10px; margin-bottom: 6px; flex-wrap: wrap;">
                  <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    ${i.isPinned?'<span class="badge" style="background: #f59e0b; color: #fff; font-weight: 800; font-size: 0.72rem;">\u{1F4CC} PINNED</span>':""}
                    <h5 style="margin: 0; font-size: 0.98rem; font-weight: 700; color: var(--color-text-primary);">${o(i.title)}</h5>
                    <span class="badge" style="background: rgba(99, 102, 241, 0.12); color: var(--color-primary); font-size: 0.72rem; text-transform: uppercase;">${o(i.category||"general")}</span>
                  </div>
                  <span style="font-size: 0.75rem; color: var(--color-text-muted); white-space: nowrap;">${new Date(i.createdAt).toLocaleDateString("en-IN")} (${we.timeAgo(i.createdAt)})</span>
                </div>
                <div style="font-size: 0.85rem; color: var(--color-text-primary); line-height: 1.5; white-space: pre-wrap;">${o(i.message)}</div>
              </div>
            `).join("")}
          </div>
        `}catch(r){O.innerHTML=`<div class="text-danger p-3 text-center">Failed to load notices: ${o(r.message)}</div>`}else if(a==="holidays")try{const r=(await P.get("/api/student-portal/holidays")).data||[];if(r.length===0){O.innerHTML='<div class="text-center p-4 text-muted">No scheduled holidays or library closures found. Reading rooms open on standard hours!</div>';return}O.innerHTML=`
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px;">
            ${r.map(i=>{const s=new Date(i.date||i.startDate||Date.now()),u=Math.ceil((s-new Date)/(1e3*60*60*24));return`
                <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; margin-bottom: 4px;">
                    <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-text-primary);">${o(i.title)}</div>
                    <span class="badge ${i.isLibraryClosed?"badge-danger":"badge-warning"}" style="font-size: 0.7rem;">
                      ${i.isLibraryClosed?"\u{1F534} Closed":"\u{1F7E1} Timings Revised"}
                    </span>
                  </div>
                  <div style="font-size: 0.82rem; color: var(--color-primary); font-weight: 700; margin-bottom: 4px;">
                    \u{1F4C5} ${s.toLocaleDateString("en-IN",{weekday:"short",day:"2-digit",month:"short",year:"numeric"})}
                    ${u>0?`<small class="text-muted">(${u} days away)</small>`:u===0?'<small class="text-danger">(Today)</small>':""}
                  </div>
                  ${i.timingOverride?`<div style="font-size: 0.78rem; color: var(--color-text-secondary);">\u23F0 Shift Timing: <strong>${o(i.timingOverride)}</strong></div>`:""}
                  ${i.description?`<div style="font-size: 0.78rem; color: var(--color-text-muted); margin-top: 4px;">${o(i.description)}</div>`:""}
                </div>
              `}).join("")}
          </div>
        `}catch(r){O.innerHTML=`<div class="text-danger p-3 text-center">Failed to load holiday calendar: ${o(r.message)}</div>`}else if(a==="lostfound")try{const r=(await P.get("/api/student-portal/lost-found")).data||[];O.innerHTML=`
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div style="font-size: 0.85rem; color: var(--color-text-secondary);">
              Items found inside study rooms, silent cabins &amp; washrooms. Check with manager desk to claim.
            </div>
            <button type="button" class="btn btn-sm btn-primary" id="btn-report-lost-item" style="font-weight: 700;">
              \u2795 Report Lost/Found Item
            </button>
          </div>
          ${r.length===0?`
            <div class="text-center p-4 text-muted">No lost or unclaimed items recorded currently.</div>
          `:`
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px;">
              ${r.map(i=>`
                <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; margin-bottom: 4px;">
                    <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-text-primary);">${o(i.itemName)}</div>
                    <span class="badge ${i.status==="claimed"?"badge-success":"badge-warning"}" style="font-size: 0.7rem; text-transform: uppercase;">
                      ${i.status==="claimed"?"\u2705 Claimed":"\u{1F7E2} Found / Available"}
                    </span>
                  </div>
                  <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-bottom: 4px;">
                    \u{1F4CD} Found Location: <strong>${o(i.foundLocation||"Library")}</strong>
                  </div>
                  ${i.description?`<div style="font-size: 0.78rem; color: var(--color-text-muted);">${o(i.description)}</div>`:""}
                  <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 6px;">
                    Reported on: ${new Date(i.foundDate||i.createdAt).toLocaleDateString("en-IN")}
                  </div>
                </div>
              `).join("")}
            </div>
          `}
        `,O.querySelector("#btn-report-lost-item")?.addEventListener("click",()=>{de()})}catch(r){O.innerHTML=`<div class="text-danger p-3 text-center">Failed to load lost & found items: ${o(r.message)}</div>`}else if(a==="feedback")try{const r=(await P.get("/api/student-portal/feedback")).data||[];O.innerHTML=`
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div style="font-size: 0.85rem; color: var(--color-text-secondary);">
              Your suggestions &amp; queries help us maintain 5-star study conditions.
            </div>
            <button type="button" class="btn btn-sm btn-primary" id="btn-submit-new-feedback" style="font-weight: 700;">
              \u270D\uFE0F Submit Feedback / Query
            </button>
          </div>
          ${r.length===0?`
            <div class="text-center p-4 text-muted">You haven't submitted any feedback yet. Have a request or issue? Click the button above to contact management!</div>
          `:`
            <div style="display: flex; flex-direction: column; gap: 10px;">
              ${r.map(i=>`
                <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; margin-bottom: 4px;">
                    <div style="display: flex; align-items: center; gap: 8px;">
                      <span style="font-weight: 700; font-size: 0.9rem; text-transform: uppercase; color: var(--color-primary);">${o(i.category||"General")}</span>
                      <span>${"\u2B50".repeat(Math.max(1,Math.min(5,i.rating||5)))}</span>
                    </div>
                    <span class="badge ${i.status==="resolved"?"badge-success":"badge-warning"}" style="font-size: 0.7rem; text-transform: uppercase;">
                      ${o(i.status||"Pending")}
                    </span>
                  </div>
                  <div style="font-size: 0.85rem; color: var(--color-text-primary); line-height: 1.4; margin: 4px 0;">${o(i.message)}</div>
                  ${i.adminReply?`
                    <div style="background: rgba(108, 92, 231, 0.08); border-left: 3px solid var(--color-primary); padding: 6px 10px; border-radius: 4px; font-size: 0.8rem; margin-top: 6px;">
                      <strong style="color: var(--color-primary);">Management Reply:</strong> ${o(i.adminReply)}
                    </div>
                  `:""}
                  <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 6px;">
                    Submitted: ${new Date(i.createdAt).toLocaleDateString("en-IN")} (${we.timeAgo(i.createdAt)})
                  </div>
                </div>
              `).join("")}
            </div>
          `}
        `,O.querySelector("#btn-submit-new-feedback")?.addEventListener("click",()=>{ye()})}catch(r){O.innerHTML=`<div class="text-danger p-3 text-center">Failed to load feedback: ${o(r.message)}</div>`}}}function de(){const a=document.createElement("div");a.innerHTML=`
      <form id="form-report-lost" style="font-family: 'Outfit', sans-serif;">
        <div class="mb-3">
          <label class="form-label" style="font-weight: 700;">Item Name *</label>
          <input type="text" id="lost-itemName" class="form-control" placeholder="e.g. Boat Earbuds, Casio Calculator, Blue Water Bottle" required>
        </div>
        <div class="row g-2 mb-3">
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">Category</label>
            <select id="lost-category" class="form-select">
              <option value="electronics">\u{1F4F1} Electronics / Charger</option>
              <option value="books">\u{1F4DA} Books / Notes</option>
              <option value="stationery">\u270F\uFE0F Stationery / Calculator</option>
              <option value="clothing">\u{1F455} Clothing / Bag / Bottle</option>
              <option value="other">\u{1F4E6} Other</option>
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">Location Found / Lost</label>
            <input type="text" id="lost-location" class="form-control" placeholder="e.g. Cabin 02, Discussion Hall">
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label" style="font-weight: 600;">Item Description / Markings</label>
          <textarea id="lost-desc" class="form-control" rows="2" placeholder="Color, brand, identifying details"></textarea>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">Submit Report</button>
        </div>
      </form>
    `;const r=new re({title:"\u{1F50D} Report Lost / Found Item",content:a,size:"md"});r.show(),a.querySelector("#form-report-lost").onsubmit=async i=>{i.preventDefault();const s=a.querySelector("#lost-itemName").value.trim(),u=a.querySelector("#lost-category").value,f=a.querySelector("#lost-location").value.trim(),h=a.querySelector("#lost-desc").value.trim();try{const D=await P.post("/api/student-portal/lost-found",{itemName:s,category:u,foundLocation:f,description:h});D.success?(S.success("Lost & Found item reported!"),r.close(),R("lostfound")):S.error(D.message)}catch(D){S.error(D.message||"Failed to submit report")}}}function ye(){const a=document.createElement("div");a.innerHTML=`
      <form id="form-submit-feedback" style="font-family: 'Outfit', sans-serif;">
        <div class="row g-2 mb-3">
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Category *</label>
            <select id="fb-category" class="form-select">
              <option value="cleanliness">\u{1F9F9} Cleanliness & Washrooms</option>
              <option value="ac_wifi">\u2744\uFE0F AC & High-Speed Wi-Fi</option>
              <option value="noise">\u{1F92B} Noise / Silence Maintenance</option>
              <option value="seats">\u{1F4BA} Desk / Ergonomic Seating</option>
              <option value="management">\u{1F465} Management & Staff Support</option>
              <option value="other">\u{1F4AC} General Suggestion</option>
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Overall Satisfaction Rating</label>
            <select id="fb-rating" class="form-select">
              <option value="5">\u2B50\u2B50\u2B50\u2B50\u2B50 Excellent (5/5)</option>
              <option value="4">\u2B50\u2B50\u2B50\u2B50 Good (4/5)</option>
              <option value="3">\u2B50\u2B50\u2B50 Average (3/5)</option>
              <option value="2">\u2B50\u2B50 Needs Improvement (2/5)</option>
              <option value="1">\u2B50 Poor (1/5)</option>
            </select>
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label" style="font-weight: 700;">Your Message / Query *</label>
          <textarea id="fb-message" class="form-control" rows="3" placeholder="Tell us how we can make your study experience better..." required></textarea>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">Send to Management</button>
        </div>
      </form>
    `;const r=new re({title:"\u{1F4AC} Student Feedback & Helpdesk",content:a,size:"md"});r.show(),a.querySelector("#form-submit-feedback").onsubmit=async i=>{i.preventDefault();const s=a.querySelector("#fb-category").value,u=a.querySelector("#fb-rating").value,f=a.querySelector("#fb-message").value.trim();try{const h=await P.post("/api/student-portal/feedback",{category:s,rating:u,message:f});h.success?(S.success("Feedback submitted! Thank you!"),r.close(),R("feedback")):S.error(h.message)}catch(h){S.error(h.message||"Failed to submit feedback")}}}ne.forEach(a=>{a.addEventListener("click",()=>{R(a.dataset.tab)})});function ve(a){const r=document.getElementById("student-campus-hub-card");r&&(r.scrollIntoView({behavior:"smooth",block:"center"}),r.style.boxShadow="0 0 0 3px rgba(99, 102, 241, 0.4)",setTimeout(()=>{r.style.boxShadow=""},1500),R(a))}n.querySelector("#btn-portal-notices")?.addEventListener("click",()=>ve("notices")),n.querySelector("#btn-portal-holidays")?.addEventListener("click",()=>ve("holidays")),n.querySelector("#btn-portal-lostfound")?.addEventListener("click",()=>ve("lostfound")),n.querySelector("#btn-portal-feedback")?.addEventListener("click",()=>ve("feedback")),R("notices"),n.querySelector("#btn-portal-receipts-jump")?.addEventListener("click",()=>{const a=document.getElementById("student-receipts-card");a&&(a.scrollIntoView({behavior:"smooth",block:"center"}),a.style.boxShadow="0 0 0 3px rgba(99, 102, 241, 0.4)",setTimeout(()=>{a.style.boxShadow=""},1500))}),n.querySelectorAll(".btn-view-receipt").forEach(a=>{a.addEventListener("click",async()=>{try{const r=JSON.parse(a.dataset.receipt),i=r.receiptNumber||"REC";let s=window.store?.settings?.receipt;if(!s||!s.activeTemplate)try{const f=await P.get("/api/settings/receipt-config").catch(()=>null);f?.success&&f?.data&&(s=f.data)}catch{}const u=`
          <div style="padding: 6px; font-family: inherit;">
            <div id="student-receipt-rendered-container">
              ${Qe(r,{receiptConfig:s,businessProfile:p,isStudent:!0})}
            </div>
            <div style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 16px; border-top: 1px solid var(--color-border, #e2e8f0); padding-top: 12px;">
              <button class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Close</button>
              <button class="btn btn-primary btn-sm" id="btn-print-student-receipt-modal" style="font-weight: 700; display: inline-flex; align-items: center; gap: 6px;">
                <span>\u{1F4E5}</span> Download PDF / Print Receipt
              </button>
            </div>
          </div>
        `;re.show({title:`Payment Receipt \u2014 ${i}`,content:u,size:"md"}),setTimeout(()=>{document.getElementById("btn-print-student-receipt-modal")?.addEventListener("click",()=>{Je(r,{receiptConfig:s,businessProfile:p})})},50)}catch(r){console.error("Receipt click error:",r),S.error("Could not load receipt")}})}),n.querySelector("#btn-portal-renew")?.addEventListener("click",async()=>{try{let a=function(){f.innerHTML=`
          <div style="font-family: 'Outfit', sans-serif;">
            
            <!-- Dynamic Admin Selected Verification Engine Header -->
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 10px; padding: 8px 12px; margin-bottom: 1rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
              <div style="display: flex; align-items: center; gap: 8px;">
                <span class="badge" style="background: ${s.gatewayProvider==="manual_upi"||!s.gatewayProvider?"rgba(0, 184, 148, 0.15)":"rgba(108, 92, 231, 0.15)"}; color: ${s.gatewayProvider==="manual_upi"||!s.gatewayProvider?"var(--color-success)":"var(--color-primary)"}; font-weight: 800; font-size: 0.82rem; padding: 4px 10px;">
                  ${s.gatewayProvider==="manual_upi"||!s.gatewayProvider?"\u{1F7E2} Option A: Free Standard UPI QR & UTR Check":"\u26A1 Option B: "+(s.gatewayProvider||"gateway").toUpperCase()+" 0-Sec Auto-Verify"}
                </span>
              </div>
              <span style="font-size: 0.78rem; color: var(--color-text-secondary); font-weight: 600;">
                Active Admin Mode
              </span>
            </div>

            <!-- Plan & Shift Selection Engine -->
            <div class="row g-2 mb-3">
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Select Membership Plan *</label>
                <select id="renewal-plan-select" class="form-select" style="font-weight: 600;">
                  ${(s.allPlans||[]).map(h=>{const D=h.durationType||"days",$=h.duration||30,m=D==="months"?`${$} Month${$>1?"s":""}`:D==="years"?`${$} Year${$>1?"s":""}`:`${$} Day${$!==1?"s":""}`;return`
                    <option value="${h._id}" ${String(h._id)===String(s.selectedPlanId)?"selected":""}>
                      ${o(h.name)} \u2014 \u20B9${Number(h.price||0).toLocaleString("en-IN")} (${m})
                    </option>`}).join("")}

                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Select Preferred Study Shift *</label>
                <select id="renewal-shift-select" class="form-select" style="font-weight: 600;">
                  ${(s.allShifts||[]).map(h=>`
                    <option value="${h._id}" ${String(h._id)===String(s.selectedShiftId)?"selected":""}>
                      ${o(h.name)} (${o(h.startTime||"")} - ${o(h.endTime||"")})
                    </option>
                  `).join("")}
                </select>
              </div>
            </div>

            <!-- Dynamic Renewal Summary Card -->
            <div style="text-align: center; margin-bottom: 1rem; background: rgba(108, 92, 231, 0.06); padding: 10px; border-radius: 10px; border: 1px solid rgba(108, 92, 231, 0.2);">
              <span class="badge" style="background: rgba(108, 92, 231, 0.2); color: var(--color-primary); font-weight: 700; font-size: 0.8rem; padding: 4px 10px;">
                \u26A1 Instant Self-Renewal
              </span>
              <h4 style="margin: 6px 0 2px 0; font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary);">
                ${o(s.planName)}
              </h4>
              <p class="text-muted small" style="margin: 0; font-size: 0.8rem;">Extends membership by ${s.durationDays>=365?Math.round(s.durationDays/365)+" Year(s)":s.durationDays>=28?Math.round(s.durationDays/30)+" Month(s)":s.durationDays+" Day(s)"} from expiry.</p>
            </div>

            <!-- Fee Calculation Table -->
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 16px; margin-bottom: 1rem;">
              <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 6px;">
                <span class="text-muted">Plan Base Fee:</span>
                <span style="font-weight: 600;">\u20B9${s.basePrice.toLocaleString("en-IN")}</span>
              </div>
              ${s.discount>0?`
                <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 6px; color: var(--color-success);">
                  <span>Special Discount:</span>
                  <span style="font-weight: 600;">- \u20B9${s.discount.toLocaleString("en-IN")}</span>
                </div>
              `:""}
              ${s.pendingFine>0?`
                <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 6px; color: var(--color-danger);">
                  <span>Late Fee / Grace Due:</span>
                  <span style="font-weight: 600;">+ \u20B9${s.pendingFine.toLocaleString("en-IN")}</span>
                </div>
              `:""}
              <div style="display: flex; justify-content: space-between; font-size: 1.1rem; font-weight: 800; border-top: 1px dashed var(--color-border); padding-top: 8px; margin-top: 4px; color: var(--color-primary);">
                <span>Total Amount Payable:</span>
                <span>\u20B9${s.totalPayable.toLocaleString("en-IN")}</span>
              </div>
            </div>

            ${s.allMethodsDisabled||(s.paymentMethods||[]).length===0?`
              <!-- Disabled Payment Banner when Admin turns off all online payment methods -->
              <div style="background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.25); border-radius: 12px; padding: 1.25rem; text-align: center; margin-bottom: 1rem;">
                <div style="font-size: 2.2rem; margin-bottom: 6px;">\u{1F6AB}</div>
                <h4 style="margin: 0 0 6px 0; font-size: 1.05rem; font-weight: 800; color: var(--color-danger);">
                  Online Self-Renewal Currently Disabled
                </h4>
                <p style="margin: 0 0 1rem 0; font-size: 0.85rem; color: var(--color-text-secondary); line-height: 1.5;">
                  Online self-renewal payments have been turned OFF by the administration. Please contact the library manager or visit the front reception desk to renew your membership.
                </p>
                <div>
                  <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Close Window</button>
                </div>
              </div>
            `:`
              <!-- Payment Method Selection Tabs -->
              <div class="mb-3">
                <label class="form-label" style="font-weight: 700;">Choose Payment Method *</label>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 8px;">
                  <button type="button" class="btn btn-sm ${u==="upi"?"btn-primary":"btn-outline-secondary"} btn-portal-pm" data-mode="upi" style="font-weight: 700; padding: 7px 10px;">
                    \u26A1 Instant UPI / QR
                  </button>
                  <button type="button" class="btn btn-sm ${u==="bank_transfer"?"btn-primary":"btn-outline-secondary"} btn-portal-pm" data-mode="bank_transfer" style="font-weight: 700; padding: 7px 10px;">
                    \u{1F3DB}\uFE0F Bank Transfer
                  </button>
                  <button type="button" class="btn btn-sm ${u==="desk"?"btn-primary":"btn-outline-secondary"} btn-portal-pm" data-mode="desk" style="font-weight: 700; padding: 7px 10px;">
                    \u{1F4B5} Pay at Desk
                  </button>
                </div>
              </div>

              <!-- Dynamic Subpanes Container -->
              <div id="portal-payment-subpane" class="mb-3">
                ${u==="upi"?`
                  ${De.renderUPIWidget({amount:s.totalPayable,upiId:s.upiId,note:`Renewal_${t.studentId||""}`,showUtrInput:!0,utrInputId:"renewal-utr-input",mountId:"renewal-upi-qr-mount"})}
                `:u==="bank_transfer"?`
                  ${De.renderBankDetailsWidget()}

                  <!-- \u{1F4F8} 1-Tap Slip Upload Trigger -->
                  <div style="background: var(--color-bg-secondary); border: 1.5px dashed var(--color-primary); border-radius: 10px; padding: 10px; text-align: center; margin-bottom: 10px;">
                    <input type="file" id="renewal-slip-file-input" accept="image/*,application/pdf" style="display: none;">
                    <button type="button" id="btn-renewal-slip-trigger" class="btn btn-sm btn-outline-primary" style="font-weight: 700; font-size: 0.80rem; border-radius: 6px; padding: 5px 14px;">
                      \u{1F4F8} Attach Payment Screenshot / Slip
                    </button>
                    <div id="renewal-slip-preview" style="display: none; margin-top: 6px; font-size: 0.76rem; color: var(--color-success); font-weight: 700;"></div>
                  </div>

                  <!-- 12-Digit Bank Ref / UTR Input -->
                  <div style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: 10px; padding: 10px 14px; margin-bottom: 8px;">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
                      <label class="form-label mb-0" style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">
                        \u{1F3DB}\uFE0F Bank NEFT / IMPS Reference / UTR *
                      </label>
                      <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); font-size: 0.7rem; font-weight: 700;">Required</span>
                    </div>
                    <div style="display: flex; gap: 6px;">
                      <input type="text" id="renewal-utr-input" class="form-control" placeholder="e.g. 423819203912 or Bank Ref # (12 digits)" maxlength="35" style="font-family: monospace; font-size: 0.92rem; font-weight: 600;">
                      <button type="button" class="btn btn-outline-primary btn-ps-paste-utr" data-target="renewal-utr-input" style="font-size: 0.8rem; padding: 6px 12px; white-space: nowrap; border-radius: 8px; font-weight: 700;">\u{1F4CB} Paste</button>
                    </div>
                  </div>
                `:`
                  <!-- Pay at Desk Notice -->
                  <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 12px; padding: 14px; font-size: 0.85rem; color: var(--color-text-primary);">
                    <div style="font-weight: 800; color: var(--color-success); margin-bottom: 4px;">\u{1F4B5} Pay Cash at Reception Desk</div>
                    <p style="margin: 0; line-height: 1.45;">Your renewal application will be recorded as <strong>Pending Cash Payment</strong>. Please visit the front reception desk to complete payment and receive your printed receipt.</p>
                  </div>
                `}
              </div>

              <!-- Submit Form -->
              <form id="portal-renewal-submit-form">
                <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 1rem;">
                  <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
                  <button type="submit" class="btn btn-primary" id="btn-submit-renewal-utr" style="font-weight: 700; min-height: 40px;">
                    ${u==="desk"?"\u{1F4DD} Submit Desk Renewal Request":"\u2705 Confirm & Extend Membership"}
                  </button>
                </div>
              </form>
            `}
          </div>
        `,r()},r=function(){De.attachEventListeners(f),f.querySelectorAll(".btn-portal-pm").forEach(x=>{x.addEventListener("click",()=>{const F=x.dataset.mode;F&&F!==u&&(u=F,a())})});const h=f.querySelector("#renewal-plan-select"),D=f.querySelector("#renewal-shift-select");async function $(){const x=h?h.value:"",F=D?D.value:"";try{const z=await P.get(`/api/student-portal/renewal-quote?planId=${x}&shiftId=${F}&applyWallet=false`);z.success&&z.data&&(s=z.data,a())}catch(z){console.warn("Failed to calculate renewal quote:",z)}}h&&h.addEventListener("change",$),D&&D.addEventListener("change",$);let m=null;f.querySelectorAll(".btn-renewal-intent").forEach(x=>{x.onclick=F=>{F.preventDefault();const z=x.dataset.app,Y=s.upiId||"7276969070@upi",W=s.businessName||"Study Library";m=`UPI_REN_${(t.phone||"STU").slice(-4)}_${Date.now().toString().slice(-6)}`;const A=f.querySelector("#renewal-utr-input");A&&(A.value=m);const k=f.querySelector("#renewal-auto-status");k&&(k.style.display="block",k.innerHTML=`
                <div style="font-weight: 700; color: var(--color-primary); display: flex; align-items: center; justify-content: center; gap: 8px;">
                  <span class="spinner-border spinner-border-sm" role="status" style="width: 14px; height: 14px; border-width: 2px;"></span>
                  <span>Opening ${z==="gpay"?"Google Pay":z==="phonepe"?"PhonePe":z==="paytm"?"Paytm":"UPI App"}...</span>
                </div>
                <small class="text-muted" style="display: block; margin-top: 3px;">Ref <code>${m}</code> attached. Return here to auto-renew.</small>
              `);const C=`pa=${encodeURIComponent(Y)}&pn=${encodeURIComponent(W)}&am=${s.totalPayable}&cu=INR&tn=${encodeURIComponent("Library Membership Renewal")}&tr=${encodeURIComponent(m)}`;let U=`upi://pay?${C}`;z==="gpay"?U=`gpay://upi/pay?${C}`:z==="phonepe"?U=`phonepe://pay?${C}`:z==="paytm"&&(U=`paytmmp://pay?${C}`),window.location.href=U}}),f.querySelectorAll(".btn-portal-copy-bank").forEach(x=>{x.onclick=F=>{F.preventDefault();const z=x.dataset.copy;z&&navigator.clipboard.writeText(z).then(()=>{const Y=x.textContent;x.textContent="\u2705",setTimeout(()=>{x.textContent=Y},1500)}).catch(()=>{})}});const d=f.querySelector("#btn-portal-copy-all-bank");d&&(d.onclick=x=>{x.preventDefault();const F=`Bank: ${s.bankDetails?.bankName||"HDFC Bank"}
A/C No: ${s.bankDetails?.accountNumber||"50200012345678"}
IFSC: ${s.bankDetails?.ifscCode||"HDFC0000123"}
Beneficiary: ${s.bankDetails?.accountHolderName||s.businessName||"Study Library"}`;navigator.clipboard.writeText(F).then(()=>{d.textContent="\u2705 Copied All!",setTimeout(()=>{d.textContent="\u{1F4CB} Copy All"},1500)}).catch(()=>{})}),f.querySelectorAll(".btn-renewal-bank-intent").forEach(x=>{x.onclick=F=>{F.preventDefault();const z=x.dataset.bank;m=`BNK_REN_${(t.phone||"STU").slice(-4)}_${Date.now().toString().slice(-6)}`;const Y=`${s.bankDetails?.accountNumber||"50200012345678"}`;navigator.clipboard.writeText(Y).catch(()=>{});const W=f.querySelector("#renewal-utr-input");W&&(W.value=m);const A=f.querySelector("#renewal-nb-auto-status");A&&(A.style.display="block",A.innerHTML=`
                <div style="font-weight: 700; color: var(--color-primary); display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>\u23F3</span> <span>Opening ${z.toUpperCase()} (A/C No Copied)...</span>
                </div>
                <small class="text-muted" style="display: block; margin-top: 2px;">Ref <code>${m}</code> auto-assigned. Complete transfer and return here.</small>
              `);const k={sbi:"https://www.onlinesbi.sbi/",hdfc:"https://netbanking.hdfcbank.com/netbanking/",icici:"https://infinity.icicibank.com/",other:"https://www.google.com/search?q=net+banking+login"};window.open(k[z]||k.other,"_blank")}});const B=f.querySelector("#btn-renewal-slip-trigger"),j=f.querySelector("#renewal-slip-file-input"),G=f.querySelector("#renewal-slip-preview");B&&j&&(B.onclick=x=>{x.preventDefault(),j.click()},j.onchange=()=>{const x=j.files?.[0];if(x){m=`SLIP_REN_${(t.phone||"STU").slice(-4)}_${Date.now().toString().slice(-6)}`;const F=f.querySelector("#renewal-utr-input");F&&(F.value=m),G&&(G.style.display="block",G.innerHTML=`\u2705 Slip Attached: <strong>${o(x.name)}</strong> (Ref: <code>${m}</code>)`)}});const H=()=>{if(m){const x=f.querySelector("#renewal-auto-status");x&&u==="upi"&&(x.style.display="block",x.style.borderColor="var(--color-success)",x.style.background="rgba(0, 184, 148, 0.08)",x.innerHTML=`
                <div style="font-weight: 800; color: var(--color-success); display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>\u2705</span> <span>UPI App Payment Captured!</span>
                </div>
                <small style="display: block; margin-top: 3px; color: var(--color-text-secondary);">
                  Ref <code>${m}</code> verified. Tap <strong>Confirm & Extend Membership</strong> below.
                </small>
              `);const F=f.querySelector("#renewal-nb-auto-status");F&&u==="bank_transfer"&&(F.style.display="block",F.style.borderColor="var(--color-success)",F.style.background="rgba(0, 184, 148, 0.08)",F.innerHTML=`
                <div style="font-weight: 800; color: var(--color-success); display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>\u2705</span> <span>Bank Transfer Handshake Recorded!</span>
                </div>
                <small style="display: block; margin-top: 3px; color: var(--color-text-secondary);">
                  Ref <code>${m}</code> auto-attached. Tap <strong>Confirm & Extend Membership</strong> below.
                </small>
              `)}};window.addEventListener("focus",H);const q=f.querySelector("#portal-renewal-submit-form");q&&(q.onsubmit=async x=>{x.preventDefault();const F=f.querySelector("#renewal-utr-input");if(u!=="desk"){const C=F?.value?.trim()||"";if(!C||C.length<6){S.error("Please enter your 12-digit Bank UTR / Transaction Reference number from Google Pay / PhonePe / Paytm."),F?.focus();return}}const z=u==="desk"?"DESK_CASH":F?.value?.trim(),Y=h?h.value:s.selectedPlanId,W=D?D.value:s.selectedShiftId,A=!1,k=f.querySelector("#btn-submit-renewal-utr");he.button(k,!0);try{const C=await P.post("/api/student-portal/renewal-request",{utrNumber:z,planId:Y,shiftId:W,amountPaid:s.totalPayable,applyWallet:A,paymentMode:u==="desk"?"cash":u});if(!C.success)throw new Error(C.message);S.success("\u{1F389} Membership renewal submitted successfully!"),re.closeAll();const U=await P.get("/api/student-portal/dashboard");if(U.success&&U.data){let X=null;try{const oe=await P.get(`/api/attendance/analytics/${U.data.student._id}`);oe.success&&(X=oe.data)}catch{}je(n,U.data,X)}}catch(C){S.error(C.message||"Renewal failed. Please check UTR.")}finally{he.button(k,!1)}})};const i=await P.get("/api/student-portal/renewal-quote?applyWallet=false");if(!i.success)throw new Error(i.message);let s=i.data,u="upi";const f=document.createElement("div");a(),(s.allMethodsDisabled||(s.paymentMethods||[]).length===0)&&S.info("Online payment is currently disabled by library management. Please contact reception to renew."),new re({title:"\u{1F4B3} Membership Self-Renewal",content:f,size:"md"}).show()}catch(a){S.error(a.message||"Could not load renewal quote")}})}function Ge(n){const g=Math.max(0,Math.min(100,Math.round(n||0)));return`
    <div style="position: relative; width: 100px; height: 100px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
      <svg viewBox="0 0 36 36" style="width: 100px; height: 100px; transform: rotate(-90deg);">
        <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
              fill="none"
              stroke="rgba(148, 163, 184, 0.2)"
              stroke-width="3.2" />
        <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
              fill="none"
              stroke="url(#portalScoreGaugeGrad)"
              stroke-width="3.2"
              stroke-dasharray="${g}, 100"
              stroke-linecap="round" />
        <defs>
          <linearGradient id="portalScoreGaugeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#10b981"/>
            <stop offset="100%" stop-color="#6366f1"/>
          </linearGradient>
        </defs>
      </svg>
      <div style="position: absolute; text-align: center;">
        <div style="font-size: 1.25rem; font-weight: 800; color: var(--color-text-primary); line-height: 1;">${g}%</div>
        <div style="font-size: 0.6rem; color: var(--color-text-secondary); text-transform: uppercase; font-weight: 700; margin-top: 2px;">Consistency</div>
      </div>
    </div>
  `}function We(n){return!n||n.length===0?'<div class="text-muted small text-center p-3">No attendance records found for the past 30 days.</div>':`
    <div>
      <div style="display: flex; flex-wrap: wrap; gap: 6px; align-items: center; justify-content: flex-start; padding: 4px 0;">
        ${n.map(g=>{const I=g.minutes||0,t=(I/60).toFixed(1),p=new Date(g.date),E=isNaN(p.getTime())?g.date:p.toLocaleDateString("en-IN",{month:"short",day:"numeric",weekday:"short"});let T="rgba(148, 163, 184, 0.15)",L="rgba(148, 163, 184, 0.25)",e="Absent";return g.status==="absent"||I===0?(T="rgba(148, 163, 184, 0.15)",L="rgba(148, 163, 184, 0.25)",e="Absent"):I<120?(T="#0e4429",L="#006d32",e=`${I} mins (${g.status})`):I<240?(T="#006d32",L="#26a641",e=`${t} hrs (${g.status})`):I<360?(T="#26a641",L="#39d353",e=`${t} hrs (${g.status})`):(T="#39d353",L="#2ea043",e=`${t} hrs (${g.status})`),`
      <div
        title="${`${E}: ${e}${g.checkIn?` [${g.checkIn} - ${g.checkOut||"Active"}]`:""}`}"
        style="
          width: 22px;
          height: 22px;
          border-radius: 4px;
          background: ${T};
          border: 1px solid ${L};
          cursor: pointer;
          transition: transform 0.15s ease, box-shadow 0.15s ease;
          flex-shrink: 0;
        "
        onmouseover="this.style.transform='scale(1.35)'; this.style.zIndex='5'; this.style.boxShadow='0 0 8px rgba(57,211,83,0.6)';"
        onmouseout="this.style.transform='scale(1)'; this.style.zIndex='1'; this.style.boxShadow='none';"
      ></div>
    `}).join("")}
      </div>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 8px; font-size: 0.72rem; color: var(--color-text-muted);">
        <span>30 Days Ago</span>
        <div style="display: flex; align-items: center; gap: 4px;">
          <span>Less</span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: rgba(148, 163, 184, 0.15); display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #0e4429; display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #006d32; display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #26a641; display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #39d353; display: inline-block;"></span>
          <span>More</span>
        </div>
        <span>Today</span>
      </div>
    </div>
  `}function ze(n){return new Promise(g=>{if(!n||typeof n!="string")return g(null);const I=n.trim();if(!I)return g(null);const t=Array.from(document.querySelectorAll("img")).find(T=>T.complete&&T.naturalWidth>0&&(T.src===I||T.getAttribute("src")===I||T.src.endsWith(I)));if(t)return g(t);let p=I;!p.startsWith("http")&&!p.startsWith("data:")&&!p.startsWith("blob:")&&!p.startsWith("/")&&(p="/"+p);const E=new Image;!p.startsWith("data:")&&!p.startsWith("blob:")&&(E.crossOrigin="anonymous"),E.onload=()=>g(E),E.onerror=()=>{if(E.crossOrigin){const T=new Image;T.onload=()=>g(T),T.onerror=()=>g(null),T.src=p}else g(null)},E.src=p})}async function Ve(n,g={},I="S",t="02",p="Study Plan",E="Not Set",T={}){S.info("\u{1F3A8} Generating 1080p Ultra-HD Mobile Pass Wallpaper...");const L=document.createElement("canvas");L.width=1080,L.height=1920;const e=L.getContext("2d"),ge=n.photo||n.avatar||n.profilePhoto||n.selfie||window.store?.user?.photo||window.store?.user?.avatar||document.querySelector("#sp-avatar-img")?.src||document.querySelector(".portal-profile-avatar img")?.src||"",ae=g.logo||g.logoUrl||window.store?.profile?.logo||window.store?.settings?.businessProfile?.logo||document.querySelector(".brand-logo img")?.src||"",Ce=g.stampImage||g.stampImageUrl||window.store?.profile?.stampImage||window.store?.settings?.businessProfile?.stampImage||"";let te=T.shiftName||n.shift?.name||n.shift?.timing||n.shift||n.plan?.shift||"Full Day";typeof te=="string"&&(te.toLowerCase()==="fullday"?te="Full Day":te=te.replace(/\b\w/g,k=>k.toUpperCase()));const Ue=te;let ie=p||n.plan?.name||"Study Plan";typeof ie=="string"&&(ie=ie.replace(/\b\w/g,k=>k.toUpperCase()));const Ye=ie,Ie=T.phone||n.phone||n.mobile||"-",be=T.bloodGroup||n.bloodGroup||"",He=n.studentId||n.enrollmentNo||"STU-MEMBER",Fe=n.admissionDate?new Date(n.admissionDate).toLocaleDateString("en-IN"):new Date().toLocaleDateString("en-IN"),Ee=`https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(n.studentId||n.phone||n._id||"STUDENT")}&margin=2&bgcolor=ffffff`,[Q,Te,Se,fe]=await Promise.all([ze(ge),ze(ae),ze(Ce),ze(Ee)]),J=e.createLinearGradient(0,0,1080,1920);J.addColorStop(0,"#0a0d18"),J.addColorStop(.3,"#13182e"),J.addColorStop(.7,"#181534"),J.addColorStop(1,"#090b14"),e.fillStyle=J,e.fillRect(0,0,1080,1920),e.save(),e.beginPath(),e.arc(180,240,450,0,Math.PI*2),e.fillStyle="rgba(79, 70, 229, 0.12)",e.fill(),e.beginPath(),e.arc(900,1680,400,0,Math.PI*2),e.fillStyle="rgba(16, 185, 129, 0.08)",e.fill(),e.restore(),e.textAlign="center",e.fillStyle="rgba(255, 255, 255, 0.7)",e.font='600 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText(`\u{1F4F1} OFFLINE DIGITAL PASS \u2022 ${(g.businessName||"STUDY LIBRARY").toUpperCase()}`,540,75);const w=80,b=120,_=920,Z=1660,M=36;e.save(),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(w,b,_,Z,M):(e.moveTo(w+M,b),e.arcTo(w+_,b,w+_,b+Z,M),e.arcTo(w+_,b+Z,w,b+Z,M),e.arcTo(w,b+Z,w,b,M),e.arcTo(w,b,w+_,b,M)),e.closePath(),e.fillStyle="#ffffff",e.shadowColor="rgba(0, 0, 0, 0.45)",e.shadowBlur=50,e.shadowOffsetY=24,e.fill(),e.strokeStyle="#0f172a",e.lineWidth=4,e.stroke(),e.restore(),e.save(),e.setLineDash([16,10]),e.beginPath(),typeof e.roundRect=="function"&&e.roundRect(w-14,b-14,_+28,Z+28,M+10),e.strokeStyle="rgba(255, 255, 255, 0.45)",e.lineWidth=2.5,e.stroke(),e.restore(),e.save(),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(w,b,_,240,[M,M,0,0]):(e.moveTo(w,b+M),e.arcTo(w,b,w+M,b,M),e.lineTo(w+_-M,b),e.arcTo(w+_,b,w+_,b+M,M),e.lineTo(w+_,b+240),e.lineTo(w,b+240)),e.closePath(),e.clip();const $e=e.createLinearGradient(w,b,w+_,b+240);if($e.addColorStop(0,"#4f46e5"),$e.addColorStop(1,"#6366f1"),e.fillStyle=$e,e.fillRect(w,b,_,240),Te){const k=w+36,C=b+36;e.save(),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(k,C,64,64,12):e.rect(k,C,64,64),e.fillStyle="#ffffff",e.fill(),e.clip(),e.drawImage(Te,k,C,64,64),e.restore(),e.textAlign="left",e.fillStyle="#ffffff",e.font='800 36px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText(g.businessName||"Study Library",w+115,b+68),e.fillStyle="rgba(255, 255, 255, 0.88)",e.font='500 22px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText(g.tagline||"Silence, Focus and Success",w+115,b+102)}else e.textAlign="center",e.fillStyle="#ffffff",e.font='800 38px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText(g.businessName||"STUDY LIBRARY",540,b+70),e.fillStyle="rgba(255, 255, 255, 0.88)",e.font='500 22px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText(g.tagline||"Silence, Focus and Success",540,b+106);e.restore();const ne=540,O=b+240,R=100;if(e.save(),e.beginPath(),e.arc(ne,O,R+10,0,Math.PI*2),e.fillStyle="#ffffff",e.shadowColor="rgba(0, 0, 0, 0.15)",e.shadowBlur=20,e.shadowOffsetY=6,e.fill(),e.beginPath(),e.arc(ne,O,R+4,0,Math.PI*2),e.fillStyle="#4f46e5",e.fill(),e.beginPath(),e.arc(ne,O,R,0,Math.PI*2),e.closePath(),e.clip(),Q){const k=Q.naturalWidth||Q.width||200,C=Q.naturalHeight||Q.height||200,U=Math.min(k,C),X=(k-U)/2,oe=(C-U)/2;e.drawImage(Q,X,oe,U,U,ne-R,O-R,R*2,R*2)}else e.fillStyle="#eef2ff",e.fillRect(ne-R,O-R,R*2,R*2),e.fillStyle="#4f46e5",e.font='800 76px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.textAlign="center",e.textBaseline="middle",e.fillText(I,ne,O);e.restore(),e.textBaseline="alphabetic";const de=(n.name||"Student Member").trim();e.textAlign="center",e.fillStyle="#0f172a";let ye=44;e.font=`800 ${ye}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;let ve=e.measureText(de).width,a=[];if(ve>760){const k=de.split(" ");if(k.length>=2){const C=Math.ceil(k.length/2),U=k.slice(0,C).join(" "),X=k.slice(C).join(" ");a=[U,X],ye=38}else a=[de],ye=34}else a=[de];e.font=`800 ${ye}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;let r=b+390;a.length>1?(a.forEach((k,C)=>{e.fillText(k,540,r+C*46)}),r+=(a.length-1)*46):e.fillText(a[0],540,r);const i=r+22,s=He;e.font="800 26px monospace";const u=e.measureText(s).width+36,f=46;let h=0;const D=!!be,$=`\u{1FA78} ${be}`;D&&(e.font='800 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',h=e.measureText($).width+28);let m=540-(u+(D?12+h:0))/2;if(e.save(),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(m,i,u,f,10):e.rect(m,i,u,f),e.fillStyle="#eef2ff",e.fill(),e.strokeStyle="#c7d2fe",e.lineWidth=1.5,e.stroke(),e.fillStyle="#4338ca",e.font="800 26px monospace",e.textAlign="center",e.fillText(s,m+u/2,i+32),e.restore(),D){const k=m+u+12;e.save(),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(k,i,h,f,10):e.rect(k,i,h,f),e.fillStyle="rgba(220, 38, 38, 0.1)",e.fill(),e.strokeStyle="rgba(220, 38, 38, 0.25)",e.lineWidth=1.5,e.stroke(),e.fillStyle="#dc2626",e.font='800 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.textAlign="center",e.fillText($,k+h/2,i+32),e.restore()}const d=w+44,B=i+68,j=_-88,G=490;e.save(),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(d,B,j,G,20):e.rect(d,B,j,G),e.fillStyle="#f8fafc",e.fill(),e.strokeStyle="#e2e8f0",e.lineWidth=2,e.stroke(),e.restore();const H=[{label:"Assigned Desk / Seat:",val:t,color:"#4f46e5",bold:!0},{label:"Shift Timing:",val:Ue,color:"#0f172a",bold:!0},{label:"Study Plan:",val:p,color:"#334155",bold:!1},{label:"Contact Phone:",val:Ie,color:"#334155",bold:!1},{label:"Valid Until:",val:E,color:"#dc2626",bold:!0}];H.forEach((k,C)=>{const U=B+64+C*92;e.textAlign="left",e.fillStyle="#64748b",e.font='600 28px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText(k.label,d+32,U),e.textAlign="right",e.fillStyle=k.color,e.font=`${k.bold?"800":"600"} 30px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`,e.fillText(k.val,d+j-32,U),C<H.length-1&&(e.beginPath(),e.moveTo(d+24,U+30),e.lineTo(d+j-24,U+30),e.strokeStyle="#e2e8f0",e.lineWidth=1.5,e.stroke())});const q=B+G+36,x=240,F=w+70;fe&&(e.save(),e.beginPath(),typeof e.roundRect=="function"&&e.roundRect(F-8,q-8,x+16,x+16,12),e.fillStyle="#ffffff",e.fill(),e.strokeStyle="#cbd5e1",e.lineWidth=2,e.stroke(),e.drawImage(fe,F,q,x,x),e.restore(),e.textAlign="center",e.fillStyle="#4f46e5",e.font="800 20px monospace",e.fillText("SCAN TO VERIFY PASS",F+x/2,q+x+30));const z=w+_-340,Y=q+10;Se?(e.save(),e.drawImage(Se,z+40,Y,180,180),e.restore()):(e.save(),e.translate(z+130,Y+80),e.rotate(-.06),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(-100,-45,200,90,8):e.rect(-100,-45,200,90),e.strokeStyle="#059669",e.lineWidth=3,e.stroke(),e.fillStyle="#059669",e.textAlign="center",e.font='800 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText("OFFICIAL SEAL",0,-10),e.font='700 20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText("PAID & VERIFIED",0,20),e.restore()),e.beginPath(),e.moveTo(z+10,Y+210),e.lineTo(z+250,Y+210),e.strokeStyle="#94a3b8",e.lineWidth=2,e.stroke(),e.textAlign="center",e.fillStyle="#64748b",e.font='600 20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText("Authorized Signatory",z+130,Y+238);const W=b+Z-68;e.save(),e.beginPath(),typeof e.roundRect=="function"?e.roundRect(w,W,_,68,[0,0,M,M]):(e.moveTo(w,W),e.lineTo(w+_,W),e.lineTo(w+_,b+Z-M),e.arcTo(w+_,b+Z,w+_-M,b+Z,M),e.lineTo(w+M,b+Z),e.arcTo(w,b+Z,w,b+Z-M,M),e.lineTo(w,W)),e.closePath(),e.fillStyle="#f8fafc",e.fill(),e.strokeStyle="#e2e8f0",e.lineWidth=1,e.stroke(),e.restore(),e.textAlign="center",e.fillStyle="#64748b",e.font='600 22px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText(`Issued: ${Fe} \u2022 Helpline: ${g.phone||"+91 98765 43210"} \u2022 Non-Transferable`,540,W+42),e.textAlign="center",e.fillStyle="rgba(255, 255, 255, 0.45)",e.font='500 20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',e.fillText("Carry on phone lockscreen for instant entry \u2022 Anti-Tamper Digital Token",540,1870);const A=document.createElement("a");A.download=`${de.replace(/\s+/g,"_")}_Mobile_ID_Pass_1080x1920.png`,A.href=L.toDataURL("image/png"),document.body.appendChild(A),A.click(),A.remove(),S.success("\u{1F4F1} 1080x1920px Mobile ID Pass Wallpaper downloaded successfully!")}export{Ve as download1080pMobileIDPass,Ne as render,Ge as renderGaugeScoreSvg,We as renderHeatmapGridHtml};
