import"../app.js";import"../i18n.js";import{Toast as l,Modal as A,Loading as g,Confirm as L,escapeHTML as m,debounce as $}from"../ui.js";import v from"../api.js";let y;function E(){const c=document.createElement("div");return c.className="page-container attendance-page",c.innerHTML=`
    <div class="page-header d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3">
      <div>
        <h2 style="margin: 0; font-size: 1.5rem; font-weight: 700;">\u{1F4CB} Attendance Tracking</h2>
        <p class="text-muted small mb-0" style="margin-top: 4px;">Daily check-in / check-out logs and occupancy tracking.</p>
      </div>
      <div class="actions d-flex align-items-center gap-2 flex-wrap">
        <a href="/kiosk.html" target="_blank" class="btn btn-outline-info btn-sm d-inline-flex align-items-center gap-1" style="font-weight: 600;">
          \u{1F5A5}\uFE0F Launch Kiosk Gate
        </a>
        <button id="btn-biometric-simulator" class="btn btn-outline-primary btn-sm" style="font-weight: 600;">
          \u{1F3F7}\uFE0F Biometric / RFID Turnstile
        </button>
        <label for="attendance-date" class="text-muted small" style="margin: 0;">Date:</label>
        <input type="date" id="attendance-date" class="form-control" style="width: auto;" value="${new Date().toISOString().split("T")[0]}">
      </div>
    </div>

    <!-- Stats Grid -->
    <div class="stats-grid mb-4" id="attendance-stats" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 1rem;">
      <div class="stat-card card p-3" style="border-left: 4px solid var(--color-success, #00b894);">
        <div class="text-muted small">Present Today</div>
        <h3 id="stat-present" style="margin: 4px 0 0 0; font-size: 1.6rem; font-weight: 700; color: var(--color-success, #00b894);">-</h3>
      </div>
      <div class="stat-card card p-3" style="border-left: 4px solid var(--color-primary, #6c5ce7);">
        <div class="text-muted small">Currently Checked In</div>
        <h3 id="stat-current" style="margin: 4px 0 0 0; font-size: 1.6rem; font-weight: 700; color: var(--color-primary, #6c5ce7);">-</h3>
      </div>
      <div class="stat-card card p-3" style="border-left: 4px solid var(--color-info, #0984e3);">
        <div class="text-muted small">Total Logs Today</div>
        <h3 id="stat-total" style="margin: 4px 0 0 0; font-size: 1.6rem; font-weight: 700; color: var(--color-info, #0984e3);">-</h3>
      </div>
    </div>

    <!-- Quick Check-in -->
    <div class="card mb-4">
      <div class="card-header">
        <h5 style="margin: 0; font-size: 1.1rem; font-weight: 600;">\u26A1 Quick Student Check-In</h5>
      </div>
      <div class="card-body">
        <div class="search-container" style="position: relative;">
          <input type="text" id="student-search" class="form-control form-control-lg" placeholder="Type student name or phone number to check in..." autocomplete="off">
          <div id="search-results" class="search-results dropdown-menu" style="display: none; position: absolute; width: 100%; z-index: 1000; background: var(--color-surface, #1e2230); border: 1px solid var(--color-border, #333); border-radius: 8px; max-height: 240px; overflow-y: auto; box-shadow: var(--shadow-lg);"></div>
        </div>
      </div>
    </div>

    <!-- Today's Log -->
    <div class="card">
      <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2">
        <h5 style="margin: 0; font-size: 1.1rem; font-weight: 600;">\u{1F4CB} Attendance Log</h5>
        <div class="d-flex gap-2 flex-wrap">
          <button id="btn-export-attendance-csv" class="btn btn-sm btn-outline-success" style="font-weight: 600;">\u{1F4E5} Export CSV</button>
          <button id="btn-checkout-all" class="btn btn-sm btn-outline-danger" style="font-weight: 600;">\u{1F6AA} Check Out All</button>
          <button id="refreshAttendanceBtn" class="btn btn-sm btn-outline-secondary">Refresh</button>
        </div>
      </div>
      <div class="card-body p-0">
        <div class="table-responsive desktop-table-view">
          <table class="table data-table mb-0">
            <thead>
              <tr>
                <th>Student ID</th>
                <th>Name</th>
                <th>Check In</th>
                <th>Check Out</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody id="attendance-list">
              <tr><td colspan="7" class="text-center p-4">Loading attendance...</td></tr>
            </tbody>
          </table>
        </div>

        <!-- Mobile Touch-Friendly Attendance Cards -->
        <div class="mobile-card-list p-2" id="attendance-mobile-cards">
          <div class="text-center p-4 text-muted">Loading attendance...</div>
        </div>
      </div>
    </div>
  `,setTimeout(()=>F(c),0),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u23F1\uFE0F",label:"Attendance Actions",color:"#0984e3",actions:[{icon:"\u2705",label:"Mark Present",onClick:()=>{const a=c.querySelector("#student-search")||document.querySelector("#student-search");a&&(a.focus(),a.scrollIntoView({behavior:"smooth"}))}},{icon:"\u{1F5A5}\uFE0F",label:"Open Kiosk",onClick:()=>{window.open("/kiosk.html","_blank")}},{icon:"\u{1F4E5}",label:"Export Logs",onClick:()=>{const a=c.querySelector("#btn-export-attendance-csv")||document.querySelector("#btn-export-attendance-csv");a&&a.click()}}]}),c}async function F(c){const a=c.querySelector("#attendance-date"),r=c.querySelector("#student-search"),n=c.querySelector("#search-results"),t=c.querySelector("#refreshAttendanceBtn");a&&a.addEventListener("change",()=>b(a.value)),t&&t.addEventListener("click",()=>b(a.value)),c.querySelector("#btn-export-attendance-csv")?.addEventListener("click",async()=>{try{const e=a?.value||new Date().toISOString().split("T")[0];g.show("Exporting attendance CSV...");const s=await v.get(`/api/attendance?date=${e}&limit=1000`);g.hide();const p=s.data?.records||[];if(p.length===0){l.error("No attendance records found for "+e);return}let o=`Student ID,Name,Phone,Check In,Check Out,Duration (Mins),Status,Date
`;p.forEach(d=>{const f=d.student?.studentId||"N/A",k=(d.student?.name||"Student").replace(/,/g,""),x=d.student?.phone||"",w=d.checkIn?new Date(d.checkIn).toLocaleTimeString("en-IN"):"-",S=d.checkOut?new Date(d.checkOut).toLocaleTimeString("en-IN"):"-",C=d.checkIn&&d.checkOut?Math.round((new Date(d.checkOut)-new Date(d.checkIn))/6e4):"-",I=d.status||(d.checkOut?"checked_out":"in_hall");o+=`"${f}","${k}","${x}","${w}","${S}","${C}","${I}","${e}"
`});const u=new Blob([o],{type:"text/csv;charset=utf-8;"}),h=URL.createObjectURL(u),i=document.createElement("a");i.href=h,i.setAttribute("download",`Attendance_Log_${e}.csv`),document.body.appendChild(i),i.click(),document.body.removeChild(i),l.success("Attendance CSV exported successfully!")}catch(e){g.hide(),l.error(e.message||"Export failed")}}),c.querySelector("#btn-checkout-all")?.addEventListener("click",async()=>{if(await L.show({title:"Check Out All Active Members?",message:"Are you sure you want to check out all students currently inside the reading hall?",danger:!0}))try{g.show("Checking out active members...");const e=await v.post("/api/attendance/check-out-all");g.hide(),l.success(e.message||"All members checked out successfully!"),b(a?.value)}catch(e){g.hide(),l.error(e.message||"Check-out failed")}}),r&&r.addEventListener("input",$(e=>{const s=e.target.value.trim();if(s.length<2){n.style.display="none";return}q(s,n)},250)),window._attSearchClickCleanup&&document.removeEventListener("click",window._attSearchClickCleanup),window._attSearchClickCleanup=e=>{r&&n&&!r.contains(e.target)&&!n.contains(e.target)&&(n.style.display="none")},document.addEventListener("click",window._attSearchClickCleanup),c.querySelector("#btn-biometric-simulator")?.addEventListener("click",()=>{const e=document.createElement("div");e.innerHTML=`
      <div class="p-2 text-center">
        <div style="font-size: 2.8rem; margin-bottom: 8px;">\u{1F6AA}</div>
        <h4 style="margin: 0 0 4px 0; font-weight: 700;">Smart Turnstile & Biometric Scanner</h4>
        <p class="text-muted small" style="margin-bottom: 1.25rem;">
          Swipe an RFID Smart Card, scan fingerprint ID, or enter Student ID.
        </p>

        <form id="biometricSyncForm">
          <div class="form-group mb-3">
            <input type="text" id="bioCardInput" class="form-control form-control-lg text-center" 
              placeholder="Swipe Card or Enter UID (e.g. STU-2026-001)" 
              style="font-size: 1.1rem; font-family: monospace; letter-spacing: 1px;" autofocus required>
          </div>
          <button type="submit" class="btn btn-primary w-full" style="font-weight: 700; padding: 0.65rem;">
            \u26A1 Trigger Gate Relay / Attendance Punch
          </button>
        </form>

        <div id="gateRelayStatus" class="mt-3 p-3 text-center" style="display: none; border-radius: 8px;"></div>
      </div>
    `,new A({title:"\u{1F3F7}\uFE0F Turnstile & Biometric Sync",content:e,size:"sm"}).show(),setTimeout(()=>e.querySelector("#bioCardInput")?.focus(),200);const s=e.querySelector("#biometricSyncForm"),p=e.querySelector("#bioCardInput"),o=e.querySelector("#gateRelayStatus");s?.addEventListener("submit",async u=>{u.preventDefault();const h=p.value.trim();if(h){o.style.display="block",o.className="mt-3 p-3 text-center",o.style.background="var(--color-surface-hover)",o.innerHTML='<div class="loading-spinner mb-1"></div> Communicating with Gate Controller...';try{const i=await v.post("/api/attendance/biometric",{studentId:h,rfidCardNumber:h,biometricId:h});i.success&&i.accessGranted?(o.style.background="rgba(0, 184, 148, 0.15)",o.style.border="1px solid var(--color-success)",o.innerHTML=`
            <div style="font-size: 1.6rem; color: var(--color-success); margin-bottom: 4px;">\u{1F7E2} ACCESS GRANTED</div>
            <strong style="font-size: 1rem; color: var(--color-text-primary);">${m(i.studentName)}</strong>
            <div style="font-size: 0.85rem; color: var(--color-text-secondary); margin-top: 2px;">
              Desk: <strong>${m(i.seatNumber)}</strong> \u2022 Action: <strong>${i.action==="check_in"?"Check-In":"Check-Out"}</strong> at ${i.time}
            </div>
            <div style="font-size: 0.75rem; color: var(--color-success); margin-top: 4px;">\u26A1 Turnstile Relay: UNLOCKED (3s)</div>
          `,p.value="",p.focus(),a&&b(a.value,!1)):(o.style.background="rgba(214, 48, 49, 0.15)",o.style.border="1px solid var(--color-danger)",o.innerHTML=`
            <div style="font-size: 1.6rem; color: var(--color-danger); margin-bottom: 4px;">\u{1F534} ACCESS DENIED</div>
            <div style="font-size: 0.85rem; color: var(--color-danger);">${m(i.message||"Card invalid or expired")}</div>
          `)}catch(i){o.style.background="rgba(214, 48, 49, 0.15)",o.style.border="1px solid var(--color-danger)",o.innerHTML=`<div style="color: var(--color-danger); font-size: 0.85rem;">\u{1F534} ${m(i.message||"Hardware sync error")}</div>`}}})}),a&&await b(a.value),y&&clearInterval(y),y=setInterval(()=>{const e=document.querySelector("#attendance-date");e?b(e.value,!1):clearInterval(y)},6e4)}async function b(c,a=!0){const r=document.querySelector("#attendance-list");a&&r&&g.skeleton(r,"table");try{const n=c===new Date().toISOString().split("T")[0];let t;if(n?t=await v.get("/api/attendance/today"):t=await v.get(`/api/attendance?date=${c}`),!t.success)throw new Error(t.message);const e=t.data.records||[],s=n?t.data.stats:null;T(s,e.length),D(e,n)}catch(n){l.error("Failed to load attendance: "+(n.message||"Error")),r&&(r.innerHTML='<tr><td colspan="7" class="text-center empty-state p-4 text-muted">Error loading attendance data</td></tr>')}}function T(c,a){const r=document.querySelector("#stat-present"),n=document.querySelector("#stat-current"),t=document.querySelector("#stat-total");r&&(r.textContent=c?c.totalPresent||0:"-"),n&&(n.textContent=c?c.currentlyCheckedIn||0:"-"),t&&(t.textContent=a)}function D(c,a){const r=document.querySelector("#attendance-list"),n=document.querySelector("#attendance-mobile-cards");if(!(!r&&!n)){if(!c||c.length===0){r&&(r.innerHTML='<tr><td colspan="7" class="text-center empty-state p-4 text-muted">No attendance records found for this date.</td></tr>'),n&&(n.innerHTML='<div class="text-center empty-state p-4 text-muted">No attendance records found for this date.</div>');return}r&&(r.innerHTML=c.map(t=>{const e=t.student||{},s=t.checkIn?new Date(t.checkIn).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"}):"-",p=t.checkOut?new Date(t.checkOut).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"}):"-";let o="";t.status==="present"?o='<span class="badge" style="background: rgba(0, 184, 148, 0.2); color: var(--color-success, #00b894); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Present</span>':t.status==="absent"?o='<span class="badge" style="background: rgba(214, 48, 49, 0.2); color: var(--color-danger, #d63031); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Absent</span>':t.status==="late"?o='<span class="badge" style="background: rgba(253, 203, 110, 0.2); color: var(--color-warning, #fdcb6e); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Late</span>':t.status==="half_day"&&(o='<span class="badge" style="background: rgba(9, 132, 227, 0.2); color: var(--color-info, #0984e3); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Half Day</span>');let u="-";return a&&t.checkIn&&!t.checkOut&&(u=`<button type="button" class="btn-icon-action action-verify btn-checkout" data-id="${e._id||""}" data-tooltip="Check Out Student" aria-label="Check Out">\u{1F6AA}</button>`),`
        <tr>
          <td><span style="font-family: monospace; font-weight: 600;">${m(e.studentId||"-")}</span></td>
          <td><strong>${m(e.name||"Unknown")}</strong></td>
          <td>${s}</td>
          <td>${p}</td>
          <td>${t.duration!==void 0&&t.duration!==null?t.duration+" min":"-"}</td>
          <td>${o}</td>
          <td>${u}</td>
        </tr>
      `}).join("")),n&&(n.innerHTML=c.map(t=>{const e=t.student||{},s=t.checkIn?new Date(t.checkIn).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"}):"-",p=t.checkOut?new Date(t.checkOut).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"}):"-";let o="badge-active",u="Present";t.status==="absent"?(o="badge-expired",u="Absent"):t.status==="late"?(o="badge-pending",u="Late"):t.status==="half_day"&&(o="badge-pending",u="Half Day");const h=a&&t.checkIn&&!t.checkOut;return`
        <div class="mobile-data-card" data-id="${e._id||""}">
          <div class="mobile-card-header">
            <div style="min-width: 0; flex: 1;">
              <div class="mobile-card-title">${m(e.name||"Student")}</div>
              <div class="mobile-card-subtitle" style="font-family: monospace; font-weight: 700; color: var(--color-primary); margin-top: 2px;">
                ${m(e.studentId||"-")}
              </div>
            </div>
            <span class="mobile-card-badge ${o}">${u}</span>
          </div>

          <div class="mobile-card-details">
            <div class="mobile-card-detail">
              <div class="mobile-card-detail-label">Check In</div>
              <div class="mobile-card-detail-value" style="color: var(--color-success); font-weight: 700;">${s}</div>
            </div>
            <div class="mobile-card-detail">
              <div class="mobile-card-detail-label">Check Out</div>
              <div class="mobile-card-detail-value">${p}</div>
            </div>
            <div class="mobile-card-detail">
              <div class="mobile-card-detail-label">Duration</div>
              <div class="mobile-card-detail-value">${t.duration!==void 0&&t.duration!==null?t.duration+" min":h?"\u23F1\uFE0F Active":"-"}</div>
            </div>
            <div class="mobile-card-detail">
              <div class="mobile-card-detail-label">Session</div>
              <div class="mobile-card-detail-value">${h?'<span style="color: #10b981; font-weight: 700;">\u{1F7E2} In Library</span>':"\u26AA Completed"}</div>
            </div>
          </div>

          ${h?`
          <div class="mobile-card-actions">
            <button type="button" class="btn btn-sm btn-outline-danger btn-checkout" data-id="${e._id||""}" style="min-height: 42px; flex: 1; font-weight: 700; display: inline-flex; align-items: center; justify-content: center; gap: 6px;">
              \u{1F6AA} Check Out Student
            </button>
          </div>
          `:""}
        </div>
      `}).join("")),[r,n].filter(Boolean).forEach(t=>{t.querySelectorAll(".btn-checkout").forEach(e=>{e.addEventListener("click",()=>{const s=e.getAttribute("data-id");s&&window.checkoutStudent&&window.checkoutStudent(s)})})})}}async function q(c,a){try{const r=await v.get(`/api/students?search=${encodeURIComponent(c)}&limit=8`);r.success&&r.data.students&&r.data.students.length>0?(a.innerHTML=r.data.students.map(n=>`
        <div class="search-result-item" style="padding: 10px 14px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.05)); cursor: pointer; display: flex; justify-content: space-between; align-items: center;" data-id="${n._id}" data-name="${m(n.name)}">
          <div>
            <strong>${m(n.name)}</strong>
            <span class="text-muted small" style="margin-left: 8px;">(${m(n.studentId||n.phone||"")})</span>
          </div>
          <span class="badge" style="background: var(--color-primary, #6c5ce7); color: white; padding: 2px 6px; font-size: 0.7rem;">Check In</span>
        </div>
      `).join(""),a.style.display="block",a.querySelectorAll(".search-result-item").forEach(n=>{n.addEventListener("click",()=>{const t=n.getAttribute("data-id"),e=n.getAttribute("data-name");window.checkinStudent(t,e)})})):(a.innerHTML='<div style="padding: 12px; text-align: center;" class="text-muted">No students found</div>',a.style.display="block")}catch(r){console.error("Search error",r)}}window.checkinStudent=async(c,a)=>{const r=document.querySelector("#student-search"),n=document.querySelector("#search-results");r&&(r.value=""),n&&(n.style.display="none");try{const t=await v.post("/api/attendance/check-in",{studentId:c});if(t.success){l.success(`Checked in ${a||"student"}`);const e=document.querySelector("#attendance-date");e&&b(e.value,!1)}else l.error(t.message)}catch(t){l.error(t.message||"Check-in failed")}},window.checkoutStudent=async c=>{try{const a=await v.post("/api/attendance/check-out",{studentId:c});if(a.success){l.success("Successfully checked out");const r=document.querySelector("#attendance-date");r&&b(r.value,!1)}else l.error(a.message)}catch(a){l.error(a.message||"Check-out failed")}};export{E as render};
