import"../app.js";import"../i18n.js";import{Toast as p,Modal as A,Loading as x,Confirm as C,escapeHTML as r,debounce as P,UI as O}from"../ui.js";import y from"../api.js";import{IDBStorage as D}from"../utils/idbStorage.js";import{OptimisticUI as G}from"../utils/optimisticUI.js";let L="seats",w="all",q="",B="",N="",S=[],F=[],U=[],k=new Set;const V=[{id:"AC",label:"AC",icon:"\u2744\uFE0F"},{id:"WiFi",label:"High Speed WiFi",icon:"\u{1F4F6}"},{id:"CCTV",label:"CCTV Surveillance",icon:"\u{1F4F9}"},{id:"Power Backup",label:"Power Backup",icon:"\u26A1"},{id:"RO Water",label:"RO Drinking Water",icon:"\u{1F4A7}"},{id:"Locker",label:"Personal Lockers",icon:"\u{1F512}"},{id:"Cafeteria",label:"Cafeteria / Pantry",icon:"\u2615"},{id:"Discussion Room",label:"Discussion Room",icon:"\u{1F5E3}\uFE0F"},{id:"Parking",label:"Two Wheeler Parking",icon:"\u{1F697}"},{id:"Biometric Access",label:"Biometric Access",icon:"\u{1F446}"}];async function J(){const e=document.createElement("div");e.className="centers-seats-hub-page page-container";const t=window.location.hash;if(t.includes("?")){const o=new URLSearchParams(t.split("?")[1]);o.get("tab")&&(L=o.get("tab")),o.get("branch")&&(w=o.get("branch"))}return e.innerHTML=`
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>\u{1F3E2} Centers & Seating Hub</h2>
        <p>Unified management for study library branches, seating matrices, floor plans, and cross-branch transfers.</p>
      </div>

      <!-- Top Primary Action Controls -->
      <div class="module-actions">
        <button id="btn-zone-customizer" class="btn btn-outline-info d-flex align-items-center gap-1" style="font-weight: 600;">
          \u{1F3A8} Zone Customizer
        </button>
        <button id="btn-cross-transfer" class="btn btn-outline-secondary d-flex align-items-center gap-1" style="font-weight: 600;">
          \u{1F504} Transfer Student
        </button>
        <button id="waitingListBtn" class="btn btn-outline-secondary d-flex align-items-center gap-1" style="font-weight: 600;">
          \u23F3 Waiting List <span class="badge badge-primary" id="waiting-badge" style="display:none; margin-left: 4px;">0</span>
        </button>
        <button id="btn-hub-add-seat" class="btn btn-outline-primary" style="font-weight: 600;">
          + Add Single Seat
        </button>
        <button id="btn-hub-bulk-seats" class="btn btn-primary" style="font-weight: 600;">
          \u26A1 Bulk Add Seats
        </button>
        <button id="btn-hub-add-branch" class="btn btn-success" style="font-weight: 600;">
          \u{1F3E2} + New Branch
        </button>
      </div>
    </div>

    <!-- Contextual Guidance Tip Banner -->
    <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
      <span style="font-size: 1.1rem;">\u{1F4A1}</span>
      <span><strong>Tip:</strong> Green = Vacant, Red = Occupied, Yellow = Reserved Hold. Click any desk to reassign or view student assignment.</span>
    </div>

    <!-- Hub View Switcher Tabs -->
    <div class="card p-2 mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
      <div class="d-flex gap-2 flex-wrap">
        <button type="button" class="btn btn-sm ${L==="seats"?"btn-primary":"btn-ghost text-muted"} hub-tab-btn" data-tab="seats" style="font-weight: 700; font-size: 0.9rem; padding: 6px 16px;">
          \u{1F4BA} Seats Matrix & Floor Plan
        </button>
        <button type="button" class="btn btn-sm ${L==="centers"?"btn-primary":"btn-ghost text-muted"} hub-tab-btn" data-tab="centers" style="font-weight: 700; font-size: 0.9rem; padding: 6px 16px;">
          \u{1F3E2} Study Centers & Branches (<span id="tab-branches-count">0</span>)
        </button>
        <button type="button" class="btn btn-sm ${L==="analytics"?"btn-primary":"btn-ghost text-muted"} hub-tab-btn" data-tab="analytics" style="font-weight: 700; font-size: 0.9rem; padding: 6px 16px;">
          \u{1F4CA} Multi-Branch Occupancy & Comparison
        </button>
      </div>
    </div>

    <!-- ========================================================= -->
    <!-- VIEW 1: SEATS MATRIX & FLOOR PLAN -->
    <!-- ========================================================= -->
    <div class="hub-view" id="view-seats" style="${L==="seats"?"":"display: none;"}">
      
      <!-- Standardized KPI Stats Grid -->
      <div class="kpi-grid" id="seatsStatsContainer">
        <div class="kpi-card kpi-primary">
          <div class="kpi-label">TOTAL SEATS <span>\u{1F4BA}</span></div>
          <div class="kpi-value" id="stat-total">-</div>
          <div class="kpi-subtext">Capacity</div>
        </div>
        <div class="kpi-card kpi-success">
          <div class="kpi-label">AVAILABLE <span>\u{1F7E2}</span></div>
          <div class="kpi-value text-success" id="stat-available">-</div>
          <div class="kpi-subtext">Vacant & ready</div>
        </div>
        <div class="kpi-card kpi-danger">
          <div class="kpi-label">OCCUPIED <span>\u{1F534}</span></div>
          <div class="kpi-value text-danger" id="stat-occupied">-</div>
          <div class="kpi-subtext">Active students</div>
        </div>
        <div class="kpi-card kpi-warning">
          <div class="kpi-label">RESERVED <span>\u{1F7E1}</span></div>
          <div class="kpi-value text-warning" id="stat-reserved">-</div>
          <div class="kpi-subtext">Booked desks</div>
        </div>
        <div class="kpi-card kpi-slate">
          <div class="kpi-label">MAINTENANCE <span>\u26AA</span></div>
          <div class="kpi-value" id="stat-maintenance" style="color: var(--color-text-muted);">-</div>
          <div class="kpi-subtext">Under repair</div>
        </div>
      </div>

      <!-- Filter & Search Toolbar -->
      <div class="toolbar-card" style="padding: 1rem; margin-bottom: 1.25rem;">
        <div class="row g-2 align-items-end" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px; width: 100%;">
          
          <div>
            <label class="form-label text-xs mb-1" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px; display: block;">\u{1F3E2} SELECT BRANCH</label>
            <select id="seat-branch-selector" class="form-select form-control form-control-sm w-100" style="font-weight: 600; min-height: 38px; width: 100%;">
              <option value="all">\u{1F310} All Branches</option>
            </select>
          </div>

          <div>
            <label class="form-label text-xs mb-1" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px; display: block;">\u{1F50D} SEARCH SEAT</label>
            <input type="text" id="seat-search-input" class="form-control form-control-sm w-100" placeholder="Search seat number (e.g. A-01, 14)..." style="min-height: 38px; width: 100%;">
          </div>

          <div>
            <label class="form-label text-xs mb-1" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px; display: block;">\u{1F4CC} STATUS FILTER</label>
            <select id="seat-status-filter" class="form-select form-control form-control-sm w-100" style="min-height: 38px; width: 100%;">
              <option value="">All Statuses</option>
              <option value="available">\u{1F7E2} Available</option>
              <option value="occupied">\u{1F534} Occupied</option>
              <option value="reserved">\u{1F7E1} Reserved</option>
              <option value="maintenance">\u26AA Maintenance</option>
            </select>
          </div>

          <div style="display: flex; align-items: flex-end;">
            <button type="button" id="btn-toggle-select-all" class="btn btn-sm btn-outline-secondary w-100" style="font-size: 0.82rem; font-weight: 600; min-height: 38px; display: inline-flex; align-items: center; justify-content: center; gap: 6px;">
              \u2611\uFE0F Select All
            </button>
          </div>
        </div>

        <!-- Horizontal Scrollable Zone Pills -->
        <div class="mt-3 pt-3 border-top">
          <label class="form-label text-xs mb-2" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px; display: block;">\u{1F3F7}\uFE0F FILTER BY STUDY ZONE</label>
          <div id="zone-pills-container" class="pill-scroll-container" style="display: flex; flex-direction: row; flex-wrap: nowrap; gap: 8px; overflow-x: auto; -webkit-overflow-scrolling: touch; padding-bottom: 6px; scrollbar-width: thin; width: 100%;">
            <!-- Dynamically loaded zone badge buttons -->
          </div>
        </div>

        <!-- Horizontal Scrollable Shift Filter Pills -->
        <div class="mt-2 pt-2 border-top">
          <label class="form-label text-xs mb-2" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px; display: block;">\u23F0 FILTER BY STUDY SHIFT</label>
          <div id="shift-pills-container" class="pill-scroll-container" style="display: flex; flex-direction: row; flex-wrap: nowrap; gap: 8px; overflow-x: auto; -webkit-overflow-scrolling: touch; padding-bottom: 6px; scrollbar-width: thin; width: 100%;">
            <button type="button" class="btn btn-xs btn-primary shift-pill-btn active" data-shift="" style="font-weight: 700; border-radius: 20px; padding: 6px 14px; white-space: nowrap; flex-shrink: 0;">\u{1F310} All Shifts</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="morning" style="font-weight: 600; border-radius: 20px; padding: 6px 14px; white-space: nowrap; flex-shrink: 0;">\u{1F305} Morning Shift</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="evening" style="font-weight: 600; border-radius: 20px; padding: 6px 14px; white-space: nowrap; flex-shrink: 0;">\u{1F306} Evening Shift</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="night" style="font-weight: 600; border-radius: 20px; padding: 6px 14px; white-space: nowrap; flex-shrink: 0;">\u{1F303} Night Shift</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="fullday" style="font-weight: 600; border-radius: 20px; padding: 6px 14px; white-space: nowrap; flex-shrink: 0;">\u2600\uFE0F Full Day Shift</button>
          </div>
        </div>
      </div>

      <!-- Floating Bulk Actions Bar -->
      <div id="bulk-action-bar" style="display: none; position: sticky; top: var(--header-height, 64px); z-index: 99; margin-bottom: 1rem; background: #1e293b; color: #fff; padding: 10px 14px; border-radius: var(--radius-md); box-shadow: var(--shadow-lg); align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
        <div class="d-flex align-items-center gap-2">
          <span class="badge badge-primary" id="bulk-selected-count" style="font-size: 0.85rem; padding: 4px 8px;">0 Selected</span>
          <span class="text-sm">Action on selected seats:</span>
        </div>
        <div class="d-flex gap-2 flex-wrap">
          <button type="button" class="btn btn-sm btn-outline-light" id="btn-bulk-rezone">\u{1F3F7}\uFE0F Change Zone</button>
          <button type="button" class="btn btn-sm btn-outline-light" id="btn-bulk-rebranch">\u{1F3E2} Move Branch</button>
          <button type="button" class="btn btn-sm btn-outline-light" id="btn-bulk-status">\u{1F504} Change Status</button>
          <button type="button" class="btn btn-sm btn-danger" id="btn-bulk-delete">\u{1F5D1}\uFE0F Delete Selected</button>
          <button type="button" class="btn btn-sm btn-ghost text-light" id="btn-bulk-cancel">\u274C Cancel</button>
        </div>
      </div>

      <!-- Seats Grid -->
      <div class="seats-grid" id="seatsGrid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 115px), 1fr)); gap: 0.75rem;">
        <!-- Seats loaded here -->
      </div>
    </div>

    <!-- ========================================================= -->
    <!-- VIEW 2: STUDY CENTERS & BRANCHES OVERVIEW -->
    <!-- ========================================================= -->
    <div class="hub-view" id="view-centers" style="${L==="centers"?"":"display: none;"}">
      <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 700;">\u{1F3E2} Study Library Branches & Centers</h3>
        <button class="btn btn-success btn-sm btn-trigger-add-branch">+ Add New Branch Center</button>
      </div>

      <!-- Branch Cards Grid -->
      <div id="branches-cards-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 280px), 1fr)); gap: 1rem;">
        <div class="text-center p-4 text-muted col-span-full">Loading branches...</div>
      </div>
    </div>

    <!-- ========================================================= -->
    <!-- VIEW 3: MULTI-BRANCH ANALYTICS & COMPARISON -->
    <!-- ========================================================= -->
    <div class="hub-view" id="view-analytics" style="${L==="analytics"?"":"display: none;"}">
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <h3 style="margin: 0 0 1rem 0; font-size: 1.2rem; font-weight: 700;">\u{1F4CA} Cross-Branch Performance & Occupancy Matrix</h3>
        
        <div class="table-responsive">
          <table class="table data-table mb-0" style="width: 100%; font-size: 0.9rem;">
            <thead>
              <tr>
                <th>Branch Center</th>
                <th>Code</th>
                <th>Manager</th>
                <th>Total Seats</th>
                <th>Occupied</th>
                <th>Available</th>
                <th>Occupancy Rate</th>
                <th class="text-right">Est. Monthly Revenue</th>
              </tr>
            </thead>
            <tbody id="analytics-table-body">
              <tr><td colspan="8" class="text-center p-4 text-muted">Calculating cross-branch metrics...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `,ee(e),setTimeout(async()=>{await H(e)},0),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1FA91}",label:"Seat Actions",color:"#fd79a8",actions:[{icon:"\u2795",label:"Add Seats",onClick:()=>{Z(e)}},{icon:"\u{1F5FA}\uFE0F",label:"Seat Map Grid",onClick:()=>{switchHubTab(e,"seats")}},{icon:"\u{1F4CA}",label:"Occupancy Report",onClick:()=>{window.location.hash="#/reports"}}]}),e}function ee(e){e.querySelectorAll(".hub-tab-btn").forEach(t=>{t.addEventListener("click",()=>{const o=t.dataset.tab;L=o,e.querySelectorAll(".hub-tab-btn").forEach(n=>{n.classList.remove("btn-primary"),n.classList.add("btn-ghost","text-muted")}),t.classList.add("btn-primary"),t.classList.remove("btn-ghost","text-muted"),e.querySelectorAll(".hub-view").forEach(n=>n.style.display="none"),e.querySelector(`#view-${o}`).style.display="block",o==="centers"&&Y(e),o==="analytics"&&Q(e),o==="seats"&&h(e)})}),e.querySelector("#btn-hub-add-seat")?.addEventListener("click",()=>se(e)),e.querySelector("#btn-hub-bulk-seats")?.addEventListener("click",()=>Z(e)),e.querySelector("#btn-hub-add-branch")?.addEventListener("click",()=>_(null,e)),e.querySelector(".btn-trigger-add-branch")?.addEventListener("click",()=>_(null,e)),e.querySelector("#waitingListBtn")?.addEventListener("click",ie),e.querySelector("#btn-cross-transfer")?.addEventListener("click",()=>te(e)),e.querySelector("#btn-zone-customizer")?.addEventListener("click",()=>I(e)),e.querySelector("#seat-branch-selector")?.addEventListener("change",t=>{w=t.target.value,k.clear(),T(e),$(e),E(e),h(e)}),e.querySelector("#seat-status-filter")?.addEventListener("change",t=>{B=t.target.value,h(e)}),e.querySelectorAll(".shift-pill-btn").forEach(t=>{t.addEventListener("click",()=>{e.querySelectorAll(".shift-pill-btn").forEach(o=>{o.classList.remove("btn-primary","active"),o.classList.add("btn-outline-secondary")}),t.classList.add("btn-primary","active"),t.classList.remove("btn-outline-secondary"),h(e)})}),e.querySelector("#seat-search-input")?.addEventListener("input",P(t=>{N=t.target.value.trim(),h(e)},250)),e.querySelector("#btn-toggle-select-all")?.addEventListener("click",()=>{k.size===S.length?k.clear():S.forEach(t=>k.add(t._id)),T(e),M(S,e)}),e.querySelector("#btn-bulk-cancel")?.addEventListener("click",()=>{k.clear(),T(e),M(S,e)}),e.querySelector("#btn-bulk-delete")?.addEventListener("click",()=>ne(e)),e.querySelector("#btn-bulk-rezone")?.addEventListener("click",()=>oe(e)),e.querySelector("#btn-bulk-rebranch")?.addEventListener("click",()=>re(e)),e.querySelector("#btn-bulk-status")?.addEventListener("click",()=>le(e))}async function H(e){try{const[t,o]=await Promise.all([y.get("/api/branches"),y.get("/api/branches/managers").catch(()=>({data:[]}))]);if(t.success&&t.data){F=t.data,e.querySelector("#tab-branches-count").textContent=F.length;const n=e.querySelector("#seat-branch-selector");if(n){let d=`<option value="all" ${w==="all"?"selected":""}>\u{1F310} All Branches</option>`;F.forEach(a=>{d+=`<option value="${a._id}" ${w===a._id?"selected":""}>\u{1F3E2} ${r(a.name)} (${r(a.code||"")})</option>`}),d+=`<option value="unassigned" ${w==="unassigned"?"selected":""}>Unassigned Branch</option>`,n.innerHTML=d}}o.success&&o.data&&(U=o.data),await Promise.all([$(e),E(e),h(e)]),Y(e),Q(e)}catch(t){console.error("Failed initial hub data load:",t)}}async function $(e){const t=e||document.querySelector(".centers-seats-hub-page")||document,o=w!=="all"?`?branch=${w}`:"";try{const[n,d]=await Promise.all([y.get(`/api/seats/stats${o}`),y.get("/api/waiting-list").catch(()=>({data:{}}))]);if(n.success&&n.data){const a=n.data;t.querySelector("#stat-total")&&(t.querySelector("#stat-total").textContent=a.total??0),t.querySelector("#stat-available")&&(t.querySelector("#stat-available").textContent=a.available??0),t.querySelector("#stat-occupied")&&(t.querySelector("#stat-occupied").textContent=a.occupied??0),t.querySelector("#stat-reserved")&&(t.querySelector("#stat-reserved").textContent=a.reserved??0),t.querySelector("#stat-maintenance")&&(t.querySelector("#stat-maintenance").textContent=a.maintenance??0)}if(d?.success&&d?.data?.counts){const a=t.querySelector("#waiting-badge");if(a){const i=d.data.counts.waiting||0;a.textContent=i,a.style.display=i>0?"inline-block":"none"}}}catch(n){console.error("Error loading stats:",n)}}async function E(e){const t=e||document.querySelector(".centers-seats-hub-page")||document,o=t.querySelector("#zone-pills-container");if(!o)return;const n=w!=="all"?`?branch=${w}`:"",d=a=>{let i=a.reduce((l,s)=>l+(s.count||0),0),c=`
      <button type="button" class="btn btn-sm ${q===""?"btn-primary":"btn-outline-secondary"} zone-pill-btn" data-zone="" style="border-radius: 20px; font-weight: 600; white-space: nowrap; flex-shrink: 0; padding: 6px 14px;">
        \u{1F31F} All Zones (${i})
      </button>
    `;a.forEach(l=>{const s=q===l._id;c+=`
        <button type="button" class="btn btn-sm ${s?"btn-primary":"btn-outline-secondary"} zone-pill-btn" data-zone="${r(l._id)}" style="border-radius: 20px; font-weight: 600; white-space: nowrap; flex-shrink: 0; padding: 6px 14px;">
          \u{1F4CD} ${r(l._id)} <span class="badge ${s?"bg-light text-dark":"badge-primary"}" style="font-size: 0.7rem; margin-left: 4px;">${l.count}</span>
        </button>
      `}),c+=`
      <button type="button" class="btn btn-sm btn-ghost text-primary" id="btn-quick-manage-zones" title="Edit, Modify, Rename or Delete Study Zones" style="font-weight: 700; border-radius: 20px; font-size: 0.8rem; display: inline-flex; align-items: center; gap: 4px; border: 1px dashed var(--color-primary); white-space: nowrap; flex-shrink: 0; padding: 6px 14px;">
        \u2699\uFE0F Manage Zones
      </button>
    `,o.innerHTML=c,o.querySelector("#btn-quick-manage-zones")?.addEventListener("click",()=>{I(t)}),o.querySelectorAll(".zone-pill-btn").forEach(l=>{l.addEventListener("click",()=>{q=l.getAttribute("data-zone")||"",o.querySelectorAll(".zone-pill-btn").forEach(s=>{s.classList.remove("btn-primary"),s.classList.add("btn-outline-secondary")}),l.classList.add("btn-primary"),l.classList.remove("btn-outline-secondary"),h(t)})})};try{const a=await y.get(`/api/seats/zones${n}`);if(a.success&&a.data){const i=a.data;d(i)}}catch(a){console.error("Error loading zones:",a)}}async function h(e){const t=e||document.querySelector(".centers-seats-hub-page")||document,o=t.querySelector("#seatsGrid");if(!o)return;const n=new URLSearchParams;w&&w!=="all"&&n.append("branch",w),q&&n.append("zone",q),B&&n.append("status",B),N&&n.append("search",N),x.skeleton(o,"cards");try{const d=`/api/seats?${n.toString()}`,a=await y.get(d);a.success?(S=a.data||[],M(S,t)):(p.error(a.message),o.innerHTML='<div class="empty-state">Error loading seats</div>')}catch(d){console.error("Error loading seats:",d),p.error("Failed to load seats"),o.innerHTML='<div class="empty-state">Failed to load seats</div>'}}function j(e){switch(e){case"available":return"#22c55e";case"occupied":return"#ef4444";case"reserved":return"#f59e0b";case"maintenance":return"#64748b";default:return"#94a3b8"}}function W(e,t){const o=j(e.status),n=e.currentStudent,d=e.branch?typeof e.branch=="object"?e.branch.name:e.branch:"Main Branch",a=document.createElement("div");a.innerHTML=`
    <div style="font-family: 'Outfit', sans-serif;">
      <!-- Header Banner -->
      <div style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.12), rgba(0, 184, 148, 0.08)); border: 1.5px solid var(--color-primary); border-radius: var(--radius-lg); padding: 1.25rem; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
        <div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <h3 style="margin: 0; font-size: 1.4rem; font-weight: 800; color: var(--color-text-primary);">
              \u{1F4BA} Desk ${r(e.seatNumber)}
            </h3>
            <span class="badge" style="background-color: ${o}; color: #fff; font-weight: 800; font-size: 0.8rem; text-transform: uppercase; padding: 4px 10px;">
              ${r(e.status)}
            </span>
          </div>
          <div style="font-size: 0.85rem; color: var(--color-text-secondary); margin-top: 4px;">
            Zone: <strong>${r(e.zone)}</strong> \u2022 Type: <strong style="text-transform: capitalize;">${r(e.type||"Regular")}</strong> \u2022 Branch: <strong>${r(d)}</strong>
          </div>
        </div>
        <div style="font-size: 1.3rem; font-weight: 800; color: var(--color-primary);">
          \u20B9${e.monthlyRate||1e3} <span style="font-size: 0.75rem; color: var(--color-text-secondary); font-weight: 500;">/ mo</span>
        </div>
      </div>

      <!-- Occupant / Assignment Card -->
      ${(e.status==="occupied"||e.currentStudent)&&n?`
        <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
          <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 8px; display: flex; align-items: center; justify-content: space-between;">
            <span>\u{1F464} Active Desk Occupant</span>
            <button type="button" class="btn btn-xs btn-outline-success btn-wa-direct" data-phone="${r(n.phone||"")}" style="font-size: 0.72rem; padding: 2px 8px; font-weight: 700;">
              \u{1F4F2} WhatsApp Occupant
            </button>
          </div>
          <div style="display: flex; gap: 12px; align-items: center;">
            <div style="width: 50px; height: 50px; border-radius: 50%; background: var(--color-primary); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 1.2rem; flex-shrink: 0; overflow: hidden;">
              ${n.photo?`<img src="${n.photo.startsWith("/")?n.photo:"/"+n.photo}" style="width:100%; height:100%; object-fit:cover;">`:n.name?n.name.charAt(0).toUpperCase():"S"}
            </div>
            <div>
              <div style="font-weight: 800; font-size: 1.05rem; color: var(--color-text-primary);">${r(n.name)}</div>
              <div style="font-size: 0.82rem; color: var(--color-text-secondary);">
                ID: <strong style="font-family: monospace; color: var(--color-primary);">${r(n.studentId||"N/A")}</strong> \u2022 Phone: <strong>${r(n.phone||"N/A")}</strong>
              </div>
            </div>
          </div>
        </div>
      `:`
        <div class="card p-3 mb-3 text-center" style="background: rgba(0, 184, 148, 0.05); border: 1px dashed var(--color-success); border-radius: var(--radius-md);">
          <div style="font-weight: 700; color: var(--color-success); margin-bottom: 4px;">\u{1F7E2} Desk Available for Immediate Allotment</div>
          <div style="font-size: 0.82rem; color: var(--color-text-secondary);">Assign this desk to a new or walk-in student member.</div>
        </div>
      `}

      <!-- Universal 5-Level Action Buttons Grid -->
      <div class="d-flex gap-2 flex-wrap justify-content-between align-items-center mt-4 pt-3" style="border-top: 1px solid var(--color-border);">
        <div class="d-flex gap-2 flex-wrap">
          ${e.status==="occupied"||e.currentStudent?`
            <button type="button" class="btn btn-outline-danger btn-sm btn-action-vacate" style="font-weight: 700;">
              \u{1F513} Vacate / Release Desk
            </button>
          `:`
            <button type="button" class="btn btn-outline-success btn-sm btn-action-assign" style="font-weight: 700;">
              \u{1F464} Assign Student
            </button>
          `}
          <button type="button" class="btn btn-outline-secondary btn-sm btn-action-clone" style="font-weight: 600;" title="Duplicate this desk with new number">
            \u{1F4D1} Clone Desk
          </button>
        </div>

        <div class="d-flex gap-2 flex-wrap">
          <button type="button" class="btn btn-outline-warning btn-sm btn-action-maint" style="font-weight: 600;">
            ${e.status==="maintenance"?"\u{1F7E2} Mark Available":"\u{1F6E0}\uFE0F Maintenance"}
          </button>
          <button type="button" class="btn btn-outline-primary btn-sm btn-action-edit" style="font-weight: 600;">
            \u270F\uFE0F Edit
          </button>
          <button type="button" class="btn btn-outline-danger btn-sm btn-action-delete" style="font-weight: 600;">
            \u{1F5D1}\uFE0F Delete
          </button>
        </div>
      </div>
    </div>
  `;const i=new A({title:`Desk ${e.seatNumber} Details & Actions`,content:a,size:"md"});i.show(),a.querySelector(".btn-wa-direct")?.addEventListener("click",c=>{const l=c.currentTarget.dataset.phone;if(l){const s=l.replace(/\D/g,""),u=`https://wa.me/${s.length===10?"91"+s:s}?text=${encodeURIComponent(`Hello! Library Admin checking in regarding Desk ${e.seatNumber}.`)}`;window.open(u,"_blank")}}),a.querySelector(".btn-action-vacate")?.addEventListener("click",async()=>{if(await C.show({title:`Release Desk ${e.seatNumber}?`,message:"Are you sure you want to unassign this desk from the current student occupant?",danger:!0}))try{await y.put(`/api/seats/${e._id}`,{status:"available",currentStudent:null}),p.success(`Desk ${e.seatNumber} has been released and is now available!`),i.close(),await D.clear("seats"),h(t),$(t)}catch(c){p.error(c.message||"Failed to release desk")}}),a.querySelector(".btn-action-assign")?.addEventListener("click",async()=>{i.close(),X(e,t)}),a.querySelector(".btn-action-clone")?.addEventListener("click",async()=>{const c=parseInt(e.seatNumber.replace(/\D/g,""))||1,l=`${e.seatNumber.replace(/[0-9]/g,"")||"D-"}${c+1}`;try{const s={seatNumber:l,type:e.type||"Regular",zone:e.zone||"General",zoneColor:e.zoneColor||"#6c5ce7",floor:e.floor||"Ground Floor",monthlyRate:e.monthlyRate||1e3,branch:e.branch?._id||e.branch||null,status:"available"},u=await y.post("/api/seats",s);u.success?(p.success(`Desk ${l} cloned and created successfully!`),i.close(),await D.clear("seats"),h(t),$(t)):p.error(u.message||"Failed to clone desk")}catch(s){p.error(s.message||"Error cloning desk")}}),a.querySelector(".btn-action-maint")?.addEventListener("click",async()=>{const c=e.status==="maintenance"?"available":"maintenance";try{await y.put(`/api/seats/${e._id}`,{status:c}),p.success(`Desk ${e.seatNumber} status updated to ${c}!`),i.close(),await D.clear("seats"),h(t),$(t)}catch(l){p.error(l.message||"Failed to update status")}}),a.querySelector(".btn-action-edit")?.addEventListener("click",()=>{i.close(),showSingleSeatModal(e,t)}),a.querySelector(".btn-action-delete")?.addEventListener("click",async()=>{if(await C.show({title:`Delete Desk ${e.seatNumber}?`,message:"Are you sure you want to permanently remove this desk?",danger:!0}))try{await y.delete(`/api/seats/${e._id}`),p.success(`Desk ${e.seatNumber} deleted!`),i.close(),await D.clear("seats"),h(t),$(t)}catch(c){p.error(c.message||"Delete failed")}})}function M(e,t){const o=t||document.querySelector(".centers-seats-hub-page")||document,n=o.querySelector("#seatsGrid");if(!n)return;if(e.length===0){O.emptyState(n,{icon:"\u{1F4BA}",title:"No Seats Match Current Filter",description:"No seats found in this branch/zone combination. Click below to bulk add seats.",actionText:"\u26A1 Bulk Add Seats",onAction:()=>Z(o)});return}let d="";e.forEach(a=>{const i=j(a.status),c=a.currentStudent?a.currentStudent.name:"",l=k.has(a._id),s=a.branch?typeof a.branch=="object"?a.branch.name:a.branch:"";d+=`
      <div class="seat-card-wrapper" style="position: relative;">
        <div class="card seat-card p-2 text-center" data-id="${a._id}" style="border-top: 4px solid ${i}; border-radius: 8px; background: var(--color-surface); border-left: 1px solid var(--color-border); border-right: 1px solid var(--color-border); border-bottom: 1px solid var(--color-border); transition: all 0.2s ease; cursor: pointer; position: relative; min-height: 142px; height: 142px; display: flex; flex-direction: column; justify-content: space-between; padding: 10px 8px; ${l?"box-shadow: 0 0 0 2.5px var(--color-primary); background: var(--color-primary-bg);":""}">
          
          <!-- Select Checkbox (Top Left) -->
          <div style="position: absolute; top: 6px; left: 6px; z-index: 2;" onclick="event.stopPropagation();">
            <label style="position: relative; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; width: 22px; height: 22px; margin: 0;" title="Select Seat">
              <input type="checkbox" class="seat-select-cb" data-id="${a._id}" ${l?"checked":""} style="position: absolute; opacity: 0; width: 0; height: 0; margin: 0; pointer-events: none;">
              <span class="custom-select-circle" style="width: 20px; height: 20px; border-radius: 50%; border: 2px solid ${a.zoneColor||"var(--color-primary, #6c5ce7)"}; display: inline-flex; align-items: center; justify-content: center; transition: all 0.2s ease; background-color: ${l?a.zoneColor||"var(--color-primary, #6c5ce7)":"transparent"}; color: #fff;">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" style="${l?"display: block;":"display: none;"}"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </span>
            </label>
          </div>

          <!-- Quick Action Dot Menu (Top Right) -->
          <div style="position: absolute; top: 4px; right: 6px; z-index: 2;" onclick="event.stopPropagation();">
            <button type="button" class="btn btn-ghost btn-sm btn-seat-quick-edit" data-id="${a._id}" title="Desk Details & Actions" style="padding: 2px 4px; font-size: 0.75rem; opacity: 0.7;">
              \u{1F441}\uFE0F
            </button>
          </div>

          <!-- Seat Number & Type -->
          <div class="mt-1">
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary); letter-spacing: 0.5px;">
              ${r(a.seatNumber)}
            </h3>
            <div style="font-size: 0.7rem; color: var(--color-text-secondary); text-transform: uppercase; font-weight: 600; margin-top: 1px;">
              ${r(a.type||"Regular")} ${a.floor?"\u2022 "+r(a.floor):""}
            </div>
          </div>

          <!-- Status Badge -->
          <div class="my-1">
            <span class="badge" style="background-color: ${i}; color: #fff; font-size: 0.65rem; padding: 2px 6px; text-transform: uppercase; font-weight: 700; border-radius: 4px;">
              ${r(a.status)}
            </span>
          </div>

          <!-- Branch Tag if viewing all branches -->
          ${w==="all"&&s?`
            <div class="text-truncate-single" style="font-size: 0.65rem; color: var(--color-primary); font-weight: 600; margin-top: 1px;" title="${r(s)}">
              \u{1F3E2} ${r(s)}
            </div>
          `:""}

          <!-- Assigned Student Avatar / Name -->
          ${c?`
            <div class="pt-1 border-top text-truncate-single" style="font-size: 0.72rem; font-weight: 700; color: var(--color-danger); max-width: 100%;" title="${r(c)}">
              \u{1F464} ${r(c)}
            </div>
          `:`
            <div class="pt-1 border-top text-muted text-truncate-single" style="font-size: 0.7rem; font-weight: 500;">
              Vacant
            </div>
          `}
        </div>
      </div>
    `}),n.innerHTML=d,n.querySelectorAll(".seat-card").forEach(a=>{a.addEventListener("mouseenter",()=>{a.style.transform="translateY(-3px)",k.has(a.getAttribute("data-id"))||(a.style.boxShadow="var(--shadow-md)")}),a.addEventListener("mouseleave",()=>{a.style.transform="translateY(0)",k.has(a.getAttribute("data-id"))||(a.style.boxShadow="")}),a.querySelector(".btn-seat-quick-edit")?.addEventListener("click",i=>{i.stopPropagation();const c=a.getAttribute("data-id"),l=S.find(s=>s._id===c);l&&W(l,t)}),a.addEventListener("click",i=>{if(i.target.closest(".seat-select-cb")||i.target.closest(".btn-seat-quick-edit")||i.target.closest("label")||i.target.closest(".custom-select-circle"))return;const c=a.getAttribute("data-id"),l=S.find(s=>s._id===c);l&&W(l,t)})}),n.querySelectorAll(".seat-select-cb").forEach(a=>{a.addEventListener("change",i=>{const c=i.target.dataset.id,l=i.target.closest(".seat-card"),s=i.target.closest("label")?.querySelector(".custom-select-circle"),u=s?.querySelector("svg"),b=S.find(m=>m._id===c)?.zoneColor||"var(--color-primary, #6c5ce7)";i.target.checked?(k.add(c),l&&(l.style.boxShadow="0 0 0 2.5px var(--color-primary)",l.style.background="var(--color-primary-bg)"),s&&(s.style.backgroundColor=b,s.style.borderColor=b),u&&(u.style.display="block")):(k.delete(c),l&&(l.style.boxShadow="",l.style.background="var(--color-surface)"),s&&(s.style.backgroundColor="transparent",s.style.borderColor=b),u&&(u.style.display="none")),T(t)})}),n.querySelectorAll(".btn-seat-quick-edit").forEach(a=>{a.addEventListener("click",i=>{i.stopPropagation();const c=a.dataset.id,l=S.find(s=>s._id===c);l&&K(l,t)})})}function T(e){const t=e.querySelector("#bulk-action-bar"),o=e.querySelector("#bulk-selected-count");!t||!o||(k.size>0?(t.style.display="flex",o.textContent=`${k.size} Selected`):t.style.display="none")}function Y(e){const t=e.querySelector("#branches-cards-grid");if(!t)return;if(F.length===0){O.emptyState(t,{icon:"\u{1F3E2}",title:"No Study Branches Configured",description:"Add your first study room or branch location to begin seating allocation.",actionText:"+ Add New Branch",onAction:()=>_(null,e)});return}let o="";F.forEach(n=>{const d=n.isMainBranch,a=n.totalSeats||n.effectiveCapacity||50,i=n.occupiedSeats||n.activeStudents||0,c=a>0?Math.min(100,Math.round(i/a*100)):0;let l="var(--color-success)";c>=90?l="var(--color-danger)":c>=70&&(l="var(--color-warning)");const s=n.manager?.name||"Unassigned";let u="";n.amenities&&n.amenities.length>0?u=n.amenities.map(b=>{const m=V.find(g=>g.id.toLowerCase()===b.toLowerCase()||g.label.toLowerCase()===b.toLowerCase()),v=m?m.icon:"\u2728",f=m?m.label:b;return`
          <span style="display: inline-flex; align-items: center; gap: 4px; padding: 2px 8px; font-size: 0.75rem; border-radius: 4px; background: var(--color-bg-secondary); color: var(--color-text-secondary); border: 1px solid var(--color-border);">
            <span>${v}</span> ${r(f)}
          </span>
        `}).join(""):u='<span style="font-size: 0.75rem; color: var(--color-text-muted);">Standard Facilities</span>',o+=`
      <div class="card branch-hub-card" style="background: var(--color-surface); border-radius: var(--radius-lg); border: 1px solid var(--color-border); ${d?"box-shadow: 0 4px 16px rgba(108, 92, 231, 0.15); border-color: var(--color-primary);":""} display: flex; flex-direction: column; overflow: hidden;">
        
        <!-- Header -->
        <div style="padding: 1.25rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover);">
          <div class="d-flex justify-content-between align-items-start gap-2">
            <div>
              <h3 style="margin: 0; font-size: 1.25rem; font-weight: 700; color: var(--color-text-primary);">
                ${r(n.name)}
              </h3>
              <div class="text-xs text-muted mt-1">
                \u{1F4CD} ${r(n.city||"")} ${n.state?", "+r(n.state):""}
              </div>
            </div>
            <span class="badge badge-primary font-monospace" style="font-size: 0.8rem;">
              ${r(n.code||"BR")}
            </span>
          </div>

          ${d?`
            <div class="mt-2">
              <span class="badge" style="background: rgba(253, 203, 110, 0.2); color: #d48806; border: 1px solid rgba(253, 203, 110, 0.4); font-size: 0.75rem;">
                \u2B50 Primary Main Campus
              </span>
            </div>
          `:""}
        </div>

        <!-- Body -->
        <div style="padding: 1.25rem; flex: 1; display: flex; flex-direction: column; gap: 12px;">
          
          <!-- Occupancy Progress Gauge -->
          <div>
            <div class="d-flex justify-content-between text-xs mb-1">
              <span style="font-weight: 600;">Seating Occupancy</span>
              <span style="font-weight: 700; color: ${l};">${c}% (${i}/${a} seats)</span>
            </div>
            <div style="width: 100%; height: 8px; background: var(--color-bg-secondary); border-radius: 4px; overflow: hidden;">
              <div style="width: ${c}%; height: 100%; background: ${l}; transition: width 0.3s ease;"></div>
            </div>
          </div>

          <!-- Contact & Manager -->
          <div class="text-xs text-muted" style="line-height: 1.6;">
            <div>\u{1F464} Manager: <strong>${r(s)}</strong></div>
            <div>\u{1F4DE} Support: <strong>${r(n.phone||"-")}</strong></div>
            <div>\u2709\uFE0F Email: <strong>${r(n.email||"-")}</strong></div>
          </div>

          <!-- Amenities -->
          <div>
            <div class="text-xs text-muted mb-1" style="font-weight: 600;">Amenities:</div>
            <div class="d-flex flex-wrap gap-1">
              ${u}
            </div>
          </div>

        </div>

        <!-- Footer Actions -->
        <div style="padding: 10px 1.25rem; background: var(--color-surface-hover); border-top: 1px solid var(--color-divider); display: flex; justify-content: space-between; align-items: center; gap: 6px;">
          <button type="button" class="btn btn-sm btn-primary btn-branch-view-seats" data-id="${n._id}" style="font-weight: 600; font-size: 0.8rem;">
            \u{1F4BA} View Seats Matrix
          </button>
          <div class="d-flex gap-1">
            <button type="button" class="btn btn-sm btn-outline-secondary btn-branch-edit" data-id="${n._id}" style="font-size: 0.8rem;">
              \u270F\uFE0F Edit
            </button>
            <button type="button" class="btn btn-sm btn-outline-danger btn-branch-delete" data-id="${n._id}" style="font-size: 0.8rem;" title="Delete Branch">
              \u{1F5D1}\uFE0F
            </button>
          </div>
        </div>

      </div>
    `}),t.innerHTML=o,t.querySelectorAll(".btn-branch-view-seats").forEach(n=>{n.addEventListener("click",()=>{const d=n.dataset.id;w=d,e.querySelector('.hub-tab-btn[data-tab="seats"]').click();const a=e.querySelector("#seat-branch-selector");a&&(a.value=d),$(e),E(e),h(e)})}),t.querySelectorAll(".btn-branch-edit").forEach(n=>{n.addEventListener("click",()=>{const d=n.dataset.id,a=F.find(i=>i._id===d);a&&_(a,e)})}),t.querySelectorAll(".btn-branch-delete").forEach(n=>{n.addEventListener("click",()=>{const d=n.dataset.id,a=F.find(i=>i._id===d);a&&ae(a,e)})})}function Q(e){const t=e.querySelector("#analytics-table-body");if(t){if(F.length===0){t.innerHTML='<tr><td colspan="8" class="text-center p-4 text-muted">No branch data available</td></tr>';return}t.innerHTML=F.map((o,n)=>{const d=o.configuredSeats>0?o.configuredSeats:o.totalSeats||o.effectiveCapacity||59,a=o.occupiedSeats||o.activeStudents||0,i=Math.max(0,d-a),c=d>0?Math.round(a/d*100):0,l=a*1200;return`
      <tr>
        <td>
          <div style="font-weight: 700; color: var(--color-text-primary);">${r(o.name)}</div>
          <div class="text-xs text-muted">${r(o.city||"")} ${o.isMainBranch?"\u2022 \u2B50 Main Campus":""}</div>
        </td>
        <td><span class="badge badge-primary font-monospace">${r(o.code||"")}</span></td>
        <td>${r(o.manager?.name||"Unassigned")}</td>
        <td><strong>${d}</strong></td>
        <td><span class="text-danger font-weight-bold">${a}</span></td>
        <td><span class="text-success font-weight-bold">${i}</span></td>
        <td>
          <div class="d-flex align-items-center gap-2">
            <div style="width: 60px; height: 6px; background: var(--color-bg-secondary); border-radius: 3px; overflow: hidden;">
              <div style="width: ${c}%; height: 100%; background: ${c>80?"var(--color-danger)":"var(--color-success)"};"></div>
            </div>
            <strong>${c}%</strong>
          </div>
        </td>
        <td class="text-right font-weight-bold" style="color: var(--color-primary);">
          \u20B9${l.toLocaleString("en-IN")}
        </td>
      </tr>
    `}).join("")}}function te(e){const t=document.createElement("div"),o=F.map(v=>`
    <option value="${v._id}">${r(v.name)} (${r(v.code||"")})</option>
  `).join("");t.innerHTML=`
    <div style="font-family: 'Outfit', sans-serif;">
      <p class="small text-muted mb-3">
        Move a student from their current seat/branch to a new study branch and seat instantly.
      </p>

      <!-- Step 1: Select Student -->
      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">1. Search Student to Transfer *</label>
        <input type="text" id="transfer-student-search" class="form-control" placeholder="Type student name or ID...">
        <div id="transfer-student-results" style="max-height: 140px; overflow-y: auto; border: 1px solid var(--color-border); border-radius: 6px; margin-top: 4px; padding: 6px; display: none;"></div>
        <input type="hidden" id="selected-transfer-student-id">
        <div id="selected-transfer-student-info" class="p-2 mt-2" style="display: none; background: rgba(99, 102, 241, 0.1); border-radius: 6px; font-size: 0.85rem;"></div>
      </div>

      <!-- Step 2: Target Branch & Seat -->
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">2. Destination Branch *</label>
          <select id="transfer-target-branch" class="form-select form-control">
            <option value="">-- Choose Target Center --</option>
            ${o}
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">3. Target Vacant Seat *</label>
          <select id="transfer-target-seat" class="form-select form-control" disabled>
            <option value="">Select branch first</option>
          </select>
        </div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="button" class="btn btn-primary" id="btn-execute-transfer" disabled style="font-weight: 700;">
          \u{1F504} Confirm & Complete Transfer
        </button>
      </div>
    </div>
  `;const n=new A({title:"\u{1F504} Cross-Branch Student Transfer",content:t,size:"md"});n.show();const d=t.querySelector("#transfer-student-search"),a=t.querySelector("#transfer-student-results"),i=t.querySelector("#selected-transfer-student-id"),c=t.querySelector("#selected-transfer-student-info"),l=t.querySelector("#transfer-target-branch"),s=t.querySelector("#transfer-target-seat"),u=t.querySelector("#btn-execute-transfer");let b;d.addEventListener("input",()=>{clearTimeout(b),b=setTimeout(async()=>{const v=d.value.trim();if(!v){a.style.display="none";return}try{const f=(await y.get(`/api/students?search=${encodeURIComponent(v)}&limit=8`)).data?.students||[];if(f.length===0){a.innerHTML='<div class="p-2 text-muted small">No students found</div>',a.style.display="block";return}a.innerHTML=f.map(g=>`
          <div class="p-2 border-bottom d-flex justify-content-between align-items-center btn-pick-transfer-student" data-id="${g._id}" data-name="${r(g.name)}" data-idnum="${r(g.studentId||"")}" data-seat="${r(g.seat?.seatNumber||"No Seat")}" style="cursor: pointer;">
            <div>
              <strong>${r(g.name)}</strong> (${r(g.studentId||"")})
              <div class="text-xs text-muted">Current Seat: ${r(g.seat?.seatNumber||"None")}</div>
            </div>
            <button type="button" class="btn btn-xs btn-primary">Select</button>
          </div>
        `).join(""),a.style.display="block",a.querySelectorAll(".btn-pick-transfer-student").forEach(g=>{g.addEventListener("click",()=>{i.value=g.dataset.id,c.innerHTML=`\u{1F464} Selected: <strong>${g.dataset.name}</strong> (ID: ${g.dataset.idnum}) \u2022 Current Seat: <strong>${g.dataset.seat}</strong>`,c.style.display="block",a.style.display="none",m()})})}catch{}},250)}),l.addEventListener("change",async()=>{const v=l.value;if(!v){s.innerHTML='<option value="">Select branch first</option>',s.disabled=!0,m();return}s.innerHTML='<option value="">Loading available seats...</option>',s.disabled=!0;try{const f=(await y.get(`/api/seats?branch=${v}&status=available`)).data||[];f.length===0?(s.innerHTML='<option value="">No vacant seats at this branch</option>',s.disabled=!0):(s.innerHTML=`<option value="">-- Choose Vacant Seat (${f.length} available) --</option>`+f.map(g=>`<option value="${g._id}">Seat ${r(g.seatNumber)} (${r(g.zone)})</option>`).join(""),s.disabled=!1)}catch{s.innerHTML='<option value="">Failed to load seats</option>'}m()}),s.addEventListener("change",m);function m(){u.disabled=!(i.value&&s.value)}u.addEventListener("click",async()=>{x.button(u,!0);try{const v=i.value,f=s.value,g=await y.post(`/api/seats/${f}/assign`,{studentId:v});g.success?(p.success("Student transferred to target branch & seat successfully!"),n.close(),$(e),h(e)):p.error(g.message)}catch(v){p.error(v.message||"Transfer failed")}finally{x.button(u,!1)}})}function _(e=null,t){const o=!!(e&&e._id),n=new Set(e?.amenities||["AC","WiFi","CCTV","Power Backup","RO Water","Locker"]),d=document.createElement("div");let a='<option value="">-- Select Manager (Optional) --</option>';U.forEach(l=>{const s=e?.manager?._id===l._id||e?.manager===l._id?"selected":"";a+=`<option value="${l._id}" ${s}>${r(l.name)} - ${r(l.phone||l.email)}</option>`});let i=V.map(l=>{const s=n.has(l.id)||n.has(l.label)?"checked":"";return`
      <label style="display: flex; align-items: center; gap: 8px; font-size: 0.8rem; background: var(--color-bg-primary); padding: 6px 10px; border-radius: 6px; border: 1px solid var(--color-border); cursor: pointer;">
        <input type="checkbox" name="amenities" value="${l.id}" ${s}>
        <span>${l.icon}</span>
        <span>${r(l.label)}</span>
      </label>
    `}).join("");d.innerHTML=`
    <form id="branchModalForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Branch / Center Name *</label>
          <input type="text" class="form-control" name="name" required value="${r(e?.name||"")}" placeholder="e.g. South Extension Campus">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Branch Code *</label>
          <input type="text" class="form-control" name="code" required value="${r(e?.code||"")}" placeholder="e.g. BR-SOUTH" style="text-transform: uppercase;">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Assigned Center Manager</label>
        <select class="form-select form-control" name="manager">
          ${a}
        </select>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Contact Mobile</label>
          <input type="tel" class="form-control" name="phone" value="${r(e?.phone||"")}" placeholder="+91 98765 43210">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Email</label>
          <input type="email" class="form-control" name="email" value="${r(e?.email||"")}" placeholder="branch@studylib.com">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Street Address</label>
        <input type="text" class="form-control" name="address" value="${r(e?.address||"")}" placeholder="Building name, street, metro pillar...">
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">City</label>
          <input type="text" class="form-control" name="city" value="${r(e?.city||"")}" placeholder="City">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Total Seating Capacity</label>
          <input type="number" class="form-control" name="effectiveCapacity" value="${e?.effectiveCapacity||e?.totalSeats||50}" min="1">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Amenities & Infrastructure</label>
        <div style="display: flex; flex-wrap: wrap; gap: 6px;">
          ${i}
        </div>
      </div>

      <div class="mb-3 p-2" style="background: rgba(253, 203, 110, 0.1); border-radius: 6px; border: 1px solid rgba(253, 203, 110, 0.25);">
        <label class="form-check-label" style="font-size: 0.85rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 8px;">
          <input type="checkbox" class="form-check-input" name="isMainBranch" value="true" ${e?.isMainBranch?"checked":""} style="cursor: pointer;">
          <span>\u2B50 Designate as Primary Main Campus Branch</span>
        </label>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-submit-branch-form" style="font-weight: 600;">
          ${o?"\u{1F4BE} Update Branch":"+ Create Branch Center"}
        </button>
      </div>
    </form>
  `;const c=new A({title:o?`\u270F\uFE0F Edit Branch: ${e.name}`:"\u{1F3E2} Create New Study Center Branch",content:d,size:"md"});c.show(),d.querySelector("#branchModalForm").addEventListener("submit",async l=>{l.preventDefault();const s=d.querySelector("#btn-submit-branch-form");x.button(s,!0);const u=new FormData(l.target),b=Object.fromEntries(u.entries());b.amenities=Array.from(d.querySelectorAll('input[name="amenities"]:checked')).map(m=>m.value),b.isMainBranch=!!d.querySelector('input[name="isMainBranch"]:checked');try{let m;o?m=await y.put(`/api/branches/${e._id}`,b):m=await y.post("/api/branches",b),m.success?(p.success(m.message),c.close(),await H(t)):p.error(m.message)}catch(m){p.error(m.message||"Failed to save branch")}finally{x.button(s,!1)}})}async function ae(e,t){const o=e.isMainBranch;if(await C.show({title:`Delete Branch: ${e.name}`,message:o?`Are you sure you want to delete "${e.name}" (${e.code})? Since this is currently the primary main campus, another active branch will automatically become the primary campus.`:`Are you sure you want to delete branch "${e.name}" (${e.code})? Existing seat configurations will be archived.`,danger:!0}))try{const n=await y.delete(`/api/branches/${e._id}`);n.success?(p.success(n.message||"Branch deleted successfully"),await H(t)):p.error(n.message||"Failed to delete branch")}catch(n){p.error(n.message||"Failed to delete branch")}}function ge(e,t){const o=document.createElement("div"),n=j(e.status),d=e.currentStudent,a=e.branch?typeof e.branch=="object"?e.branch.name:"Branch ID: "+e.branch:"Unassigned";o.innerHTML=`
    <div style="font-family: 'Outfit', sans-serif;">
      
      <!-- Top Card Header -->
      <div class="d-flex justify-content-between align-items-start mb-3 pb-3 border-bottom">
        <div>
          <div class="d-flex align-items-center gap-2">
            <h3 style="margin: 0; font-size: 1.4rem; font-weight: 800;">Seat ${r(e.seatNumber)}</h3>
            <span class="badge" style="background-color: ${n}; color: #fff; font-size: 0.75rem; text-transform: uppercase; padding: 3px 8px; border-radius: 4px;">
              ${r(e.status)}
            </span>
          </div>
          <div class="text-muted small mt-1">
            Zone: <strong>${r(e.zone)}</strong> \u2022 Floor: <strong>${r(e.floor||"Ground")}</strong> \u2022 Type: <strong>${r(e.type)}</strong>
          </div>
        </div>
        <div class="text-end">
          <div class="text-xs text-muted">Branch:</div>
          <span class="badge badge-primary">${r(a)}</span>
        </div>
      </div>

      <!-- Current Student Card (If occupied) -->
      ${d?`
        <div class="p-3 mb-3" style="background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.2); border-radius: var(--radius-md);">
          <div class="d-flex align-items-center justify-content-between">
            <div class="d-flex align-items-center gap-3">
              <div style="width: 46px; height: 46px; border-radius: 50%; background: var(--color-danger); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 1.2rem;">
                ${r(d.name.charAt(0).toUpperCase())}
              </div>
              <div>
                <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary);">
                  ${r(d.name)}
                </h4>
                <div class="text-xs text-muted">
                  ID: <span class="font-monospace fw-bold">${r(d.studentId||"-")}</span> ${d.phone?"\u2022 Phone: "+r(d.phone):""}
                </div>
              </div>
            </div>
            <button type="button" class="btn btn-sm btn-outline-danger btn-detail-release" style="font-weight: 600;">
              \u{1F513} Release / Vacate
            </button>
          </div>
        </div>
      `:`
        <div class="p-3 mb-3 text-center" style="background: rgba(34, 197, 94, 0.08); border: 1px dashed rgba(34, 197, 94, 0.3); border-radius: var(--radius-md);">
          <div class="text-success font-weight-bold mb-1">\u{1F7E2} Seat is Currently Vacant & Available</div>
          <p class="text-muted text-xs mb-2">You can assign this seat to any registered active student.</p>
          <button type="button" class="btn btn-sm btn-success btn-detail-assign" style="font-weight: 600;">
            \u{1F464} Assign Student to This Seat
          </button>
        </div>
      `}

      <!-- Seat Specifications -->
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
        <div style="background: var(--color-bg-primary); padding: 10px; border-radius: 6px; border: 1px solid var(--color-border);">
          <div class="text-xs text-muted">Monthly Rate</div>
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-text-primary);">
            \u20B9${e.monthlyRate||0}/mo
          </div>
        </div>
        <div style="background: var(--color-bg-primary); padding: 10px; border-radius: 6px; border: 1px solid var(--color-border);">
          <div class="text-xs text-muted">Amenities</div>
          <div style="font-size: 0.8rem; font-weight: 600; color: var(--color-text-primary);">
            ${e.amenities&&e.amenities.length>0?e.amenities.join(", "):"Standard Power & Light"}
          </div>
        </div>
      </div>

      <!-- Action Buttons Footer -->
      <div class="d-flex justify-content-between align-items-center pt-3 border-top">
        <button type="button" class="btn btn-outline-danger btn-sm btn-detail-delete" style="font-weight: 600;">
          \u{1F5D1}\uFE0F Delete Seat
        </button>
        <div class="d-flex gap-2">
          <button type="button" class="btn btn-outline-primary btn-sm btn-detail-edit" style="font-weight: 600;">
            \u270F\uFE0F Edit / Modify Seat
          </button>
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">
            Close
          </button>
        </div>
      </div>
    </div>
  `;const i=new A({title:`Seat Overview: ${e.seatNumber}`,content:o,size:"md"});i.show(),o.querySelector(".btn-detail-release")?.addEventListener("click",async()=>{i.close(),C.show({title:"Release Seat",message:`Unassign student from Seat ${e.seatNumber} and mark seat as available?`,danger:!1,onConfirm:async()=>{try{const c=await y.post(`/api/seats/${e._id}/release`);c.success&&(p.success(c.message),$(t),h(t))}catch(c){p.error(c.message)}}})}),o.querySelector(".btn-detail-assign")?.addEventListener("click",()=>{i.close(),X(e,t)}),o.querySelector(".btn-detail-edit")?.addEventListener("click",()=>{i.close(),K(e,t)}),o.querySelector(".btn-detail-delete")?.addEventListener("click",()=>{i.close(),C.show({title:"Delete Seat",message:`Are you sure you want to permanently delete Seat ${e.seatNumber}?`,danger:!0,onConfirm:async()=>{try{const c=await y.delete(`/api/seats/${e._id}`);c.success&&(p.success(c.message),$(t),E(t),h(t))}catch(c){p.error(c.message)}}})})}function K(e,t){const o=document.createElement("div"),n=F.map(a=>`
    <option value="${a._id}" ${e.branch&&(e.branch===a._id||e.branch._id===a._id)?"selected":""}>
      ${r(a.name)} (${r(a.code||"")})
    </option>
  `).join("");o.innerHTML=`
    <form id="editSeatForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Number *</label>
          <input type="text" class="form-control" name="seatNumber" value="${r(e.seatNumber)}" required placeholder="e.g. A-01">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Branch Location</label>
          <select class="form-select form-control" name="branch">
            <option value="">-- No Specific Branch --</option>
            ${n}
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Study Zone *</label>
          <input type="text" class="form-control" name="zone" value="${r(e.zone)}" required placeholder="e.g. Zone A (AC), Boys Hall">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Floor / Section</label>
          <input type="text" class="form-control" name="floor" value="${r(e.floor||"")}" placeholder="e.g. Ground Floor, 1st Floor">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Type</label>
          <select class="form-select form-control" name="type">
            <option value="regular" ${e.type==="regular"?"selected":""}>Regular Desk</option>
            <option value="premium" ${e.type==="premium"?"selected":""}>Premium Cabin</option>
            <option value="cabin" ${e.type==="cabin"?"selected":""}>Private Cube / Cabin</option>
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Status</label>
          <select class="form-select form-control" name="status">
            <option value="available" ${e.status==="available"?"selected":""}>\u{1F7E2} Available</option>
            <option value="occupied" ${e.status==="occupied"?"selected":""}>\u{1F534} Occupied</option>
            <option value="reserved" ${e.status==="reserved"?"selected":""}>\u{1F7E1} Reserved</option>
            <option value="maintenance" ${e.status==="maintenance"?"selected":""}>\u26AA Under Maintenance</option>
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Monthly Fee (\u20B9)</label>
          <input type="number" class="form-control" name="monthlyRate" value="${e.monthlyRate||""}" placeholder="e.g. 1200">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Amenities (Comma separated)</label>
          <input type="text" class="form-control" name="amenities" value="${e.amenities?r(e.amenities.join(", ")):""}" placeholder="Power Socket, Reading Light">
        </div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-submit-seat-edit" style="font-weight: 600;">
          \u{1F4BE} Save Seat Modifications
        </button>
      </div>
    </form>
  `;const d=new A({title:`\u270F\uFE0F Edit Seat: ${e.seatNumber}`,content:o,size:"md"});d.show(),o.querySelector("#editSeatForm").addEventListener("submit",async a=>{a.preventDefault();const i=o.querySelector("#btn-submit-seat-edit");x.button(i,!0);const c=new FormData(a.target),l=Object.fromEntries(c.entries()),s=e.status,u=l.status||s;try{await G.execute({applyState:()=>{e.status=u;const b=S.find(m=>m._id===e._id);b&&(b.status=u),M(S,t)},rollbackState:()=>{e.status=s;const b=S.find(m=>m._id===e._id);b&&(b.status=s),M(S,t)},apiCall:()=>y.put(`/api/seats/${e._id}`,l),onSuccess:b=>{p.success(b.message||"Seat updated successfully"),d.close(),$(t),E(t),h(t)}})}catch{}finally{x.button(i,!1)}})}function se(e){const t=e||document.querySelector(".centers-seats-hub-page")||document,o=document.createElement("div"),n=F.map(a=>`
    <option value="${a._id}" ${w===a._id?"selected":""}>
      ${r(a.name)} (${r(a.code||"")})
    </option>
  `).join("");o.innerHTML=`
    <form id="addSingleSeatForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Number *</label>
          <input type="text" class="form-control" name="seatNumber" required placeholder="e.g. A-01 or 105">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Branch Location</label>
          <select class="form-select form-control" name="branch">
            <option value="">-- Main / Default Branch --</option>
            ${n}
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Study Zone *</label>
          <input type="text" class="form-control" name="zone" value="${r(q||"Zone A")}" required placeholder="e.g. Zone A (AC)">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Floor / Section</label>
          <input type="text" class="form-control" name="floor" placeholder="e.g. Ground Floor">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Type</label>
          <select class="form-select form-control" name="type">
            <option value="regular">Regular Desk</option>
            <option value="premium">Premium Desk</option>
            <option value="cabin">Private Cabin</option>
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Monthly Rate (\u20B9)</label>
          <input type="number" class="form-control" name="monthlyRate" placeholder="e.g. 1200">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Amenities (Comma separated)</label>
        <input type="text" class="form-control" name="amenities" placeholder="Power Socket, Reading Light, Ergonomic Chair">
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-create-single-seat" style="font-weight: 600;">
          + Create Seat
        </button>
      </div>
    </form>
  `;const d=new A({title:"\u2795 Add Single Custom Seat",content:o,size:"md"});d.show(),o.querySelector("#addSingleSeatForm").addEventListener("submit",async a=>{a.preventDefault();const i=o.querySelector("#btn-create-single-seat");x.button(i,!0);const c=new FormData(a.target),l=Object.fromEntries(c.entries());try{const s=await y.post("/api/seats",l);s.success?(p.success(s.message),d.close(),$(t),E(t),h(t)):p.error(s.message)}catch(s){p.error(s.message||"Failed to create seat")}finally{x.button(i,!1)}})}function Z(e){const t=e||document.querySelector(".centers-seats-hub-page")||document,o=document.createElement("div"),n=F.map(a=>`
    <option value="${a._id}" ${w===a._id?"selected":""}>
      ${r(a.name)} (${r(a.code||"")})
    </option>
  `).join("");o.innerHTML=`
    <form id="bulkAddSeatsForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Target Branch Location</label>
          <select class="form-select form-control" name="branch">
            <option value="">-- Main / Default Branch --</option>
            ${n}
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Study Zone *</label>
          <input type="text" name="zone" class="form-control" required placeholder="e.g. Zone A (AC), Boys Section" value="${r(q||"")}">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Floor / Wing</label>
          <input type="text" name="floor" class="form-control" placeholder="e.g. Ground Floor">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Type</label>
          <select name="type" class="form-select form-control">
            <option value="regular">Regular Desk</option>
            <option value="premium">Premium Desk</option>
            <option value="cabin">Private Cabin</option>
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Prefix (Optional)</label>
          <input type="text" name="prefix" class="form-control" placeholder="e.g. A- or B-">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Start Number *</label>
          <input type="number" name="startNumber" class="form-control" required min="1" value="1">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Total Quantity *</label>
          <input type="number" name="count" class="form-control" required min="1" max="250" value="20">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Monthly Fee (\u20B9)</label>
          <input type="number" name="monthlyRate" class="form-control" placeholder="e.g. 1200">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Amenities</label>
          <input type="text" name="amenities" class="form-control" placeholder="Power Socket, Reading Light">
        </div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-submit-bulk-seats" style="font-weight: 600;">
          \u26A1 Generate & Save Seats
        </button>
      </div>
    </form>
  `;const d=new A({title:"\u26A1 Bulk Add Seats Generation",content:o,size:"md"});d.show(),o.querySelector("#bulkAddSeatsForm").addEventListener("submit",async a=>{a.preventDefault();const i=o.querySelector("#btn-submit-bulk-seats");x.button(i,!0);const c=new FormData(a.target),l=Object.fromEntries(c.entries());l.startNumber=parseInt(l.startNumber,10),l.count=parseInt(l.count,10);try{const s=await y.post("/api/seats/bulk",l);if(s.success){if(p.success(s.message),d.close(),l.branch&&l.branch!=="none"){w=l.branch;const u=t.querySelector("#seat-branch-selector");u&&(u.value=w)}q="",N="",B="",await D.clear("seats").catch(()=>{}),await Promise.all([$(t),E(t),h(t)])}else p.error(s.message)}catch(s){p.error(s.message||"Failed to create seats")}finally{x.button(i,!1)}})}async function X(e,t){const o=document.createElement("div");o.innerHTML=`
    <div style="font-family: 'Outfit', sans-serif;">
      <div class="mb-3">
        <label class="form-label" style="font-weight: 600;">Search Active Student</label>
        <input type="text" id="assign-student-search" class="form-control" placeholder="Search student by name, phone, or ID...">
      </div>

      <div id="assign-student-results" style="max-height: 250px; overflow-y: auto; border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 8px;">
        <div class="text-center p-3 text-muted small">Type student name or mobile number above...</div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
      </div>
    </div>
  `;const n=new A({title:`\u{1F464} Assign Student to Seat ${e.seatNumber}`,content:o,size:"md"});n.show();const d=o.querySelector("#assign-student-search"),a=o.querySelector("#assign-student-results");d?.addEventListener("input",P(async()=>{const i=d.value.trim();if(!i){a.innerHTML='<div class="text-center p-3 text-muted small">Type student name or mobile number above...</div>';return}x.skeleton(a,"table");try{const c=(await y.get(`/api/students?search=${encodeURIComponent(i)}&limit=10`)).data?.students||[];if(c.length===0){a.innerHTML=`<div class="text-center p-3 text-muted small">No active students found matching "${r(i)}"</div>`;return}a.innerHTML=c.map(l=>`
          <div class="p-2 d-flex justify-content-between align-items-center mb-1 border-bottom" style="border-radius: 4px;">
            <div>
              <div style="font-weight: 700; color: var(--color-text-primary); font-size: 0.95rem;">${r(l.name)}</div>
              <div class="text-xs text-muted">ID: <strong>${r(l.studentId||"-")}</strong> \u2022 \u{1F4DE} ${r(l.phone||"-")}</div>
            </div>
            <button type="button" class="btn btn-sm btn-primary btn-select-student" data-id="${l._id}" style="font-size: 0.75rem; font-weight: 600;">
              Assign
            </button>
          </div>
        `).join(""),a.querySelectorAll(".btn-select-student").forEach(l=>{l.addEventListener("click",async()=>{const s=l.dataset.id;try{const u=await y.post(`/api/seats/${e._id}/assign`,{studentId:s});u.success?(p.success(u.message),n.close(),$(t),h(t)):p.error(u.message)}catch(u){p.error(u.message||"Failed to assign student")}})})}catch{a.innerHTML='<div class="text-danger p-2">Search failed</div>'}},250))}async function ne(e){const t=Array.from(k);C.show({title:"Bulk Delete Seats",message:`Are you sure you want to permanently delete ${t.length} selected seat(s)? Occupied seats cannot be deleted.`,danger:!0,onConfirm:async()=>{try{const o=await y.post("/api/seats/bulk-delete",{seatIds:t});o.success?(p.success(o.message),k.clear(),T(e),$(e),E(e),h(e)):p.error(o.message)}catch(o){p.error(o.message||"Bulk delete failed")}}})}function oe(e){const t=Array.from(k),o=prompt(`Enter new Zone name for ${t.length} selected seats:`);!o||!o.trim()||y.post("/api/seats/bulk-update",{seatIds:t,updates:{zone:o.trim()}}).then(n=>{p.success(n.message||"Zones updated"),k.clear(),T(e),E(e),h(e)}).catch(n=>p.error(n.message))}function re(e){const t=Array.from(k),o=document.createElement("div"),n=F.map(a=>`
    <option value="${a._id}">${r(a.name)} (${r(a.code||"")})</option>
  `).join("");o.innerHTML=`
    <div class="p-2">
      <p class="small text-muted mb-3">Select target branch center for the <strong>${t.length}</strong> selected seats:</p>
      <div class="form-group mb-3">
        <select id="bulk-target-branch" class="form-select form-control">
          <option value="">-- No Specific Branch --</option>
          ${n}
        </select>
      </div>
      <div class="d-flex justify-content-end gap-2 mt-4 pt-2 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="button" class="btn btn-primary" id="btn-apply-bulk-branch">Move Seats</button>
      </div>
    </div>
  `;const d=new A({title:"\u{1F3E2} Move Selected Seats to Branch",content:o,size:"sm"});d.show(),o.querySelector("#btn-apply-bulk-branch")?.addEventListener("click",async()=>{const a=o.querySelector("#bulk-target-branch").value;try{const i=await y.post("/api/seats/bulk-update",{seatIds:t,updates:{branch:a||null}});p.success(i.message||"Seats moved successfully"),d.close(),k.clear(),T(e),$(e),h(e)}catch(i){p.error(i.message)}})}function le(e){const t=Array.from(k),o=document.createElement("div");o.innerHTML=`
    <div class="p-2">
      <p class="small text-muted mb-3">Set status for <strong>${t.length}</strong> selected seats:</p>
      <div class="form-group mb-3">
        <select id="bulk-target-status" class="form-select form-control">
          <option value="available">\u{1F7E2} Available</option>
          <option value="reserved">\u{1F7E1} Reserved</option>
          <option value="maintenance">\u26AA Under Maintenance</option>
        </select>
      </div>
      <div class="d-flex justify-content-end gap-2 mt-4 pt-2 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="button" class="btn btn-primary" id="btn-apply-bulk-status">Update Status</button>
      </div>
    </div>
  `;const n=new A({title:"\u{1F504} Change Status for Selected Seats",content:o,size:"sm"});n.show(),o.querySelector("#btn-apply-bulk-status")?.addEventListener("click",async()=>{const d=o.querySelector("#bulk-target-status").value,a=new Map;t.forEach(i=>{const c=S.find(l=>l._id===i);c&&a.set(i,c.status)});try{await G.execute({applyState:()=>{t.forEach(i=>{const c=S.find(l=>l._id===i);c&&(c.status=d)}),M(S,e)},rollbackState:()=>{t.forEach(i=>{const c=S.find(l=>l._id===i);c&&a.has(i)&&(c.status=a.get(i))}),M(S,e)},apiCall:()=>y.post("/api/seats/bulk-update",{seatIds:t,updates:{status:d}}),onSuccess:i=>{p.success(i.message||"Status updated"),n.close(),k.clear(),T(e),$(e),h(e)}})}catch{}})}async function ie(){const e=document.createElement("div");e.innerHTML='<div class="text-center p-4 text-muted">Loading waiting list entries...</div>';const t=new A({title:"\u23F3 Active Seat Waiting List",content:e,size:"lg"});t.show();try{const o=(await y.get("/api/waiting-list")).data?.entries||[];if(o.length===0){e.innerHTML=`
        <div class="text-center p-5 text-muted">
          <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">\u{1F389}</div>
          <h4 style="font-weight: 700; margin: 0;">Waiting List is Clear!</h4>
          <p class="small text-muted mt-1">All student requests currently have assigned seats.</p>
        </div>
      `;return}e.innerHTML=`
      <div class="table-responsive">
        <table class="table data-table mb-0" style="width: 100%; font-size: 0.88rem;">
          <thead>
            <tr>
              <th>#</th>
              <th>Student</th>
              <th>Phone</th>
              <th>Preferred Zone/Shift</th>
              <th>Requested On</th>
              <th class="text-center">Action</th>
            </tr>
          </thead>
          <tbody>
            ${o.map((n,d)=>`
              <tr>
                <td><strong>#${d+1}</strong></td>
                <td><strong>${r(n.student?.name||n.name||"Unknown")}</strong></td>
                <td>${r(n.student?.phone||n.phone||"-")}</td>
                <td>${r(n.preferredZone||"Any Zone")} (${r(n.preferredShift||"All Day")})</td>
                <td>${new Date(n.createdAt).toLocaleDateString()}</td>
                <td class="text-center">
                  <button type="button" class="btn btn-xs btn-primary btn-wl-allocate" data-id="${n._id}" style="font-size: 0.75rem;">
                    Allocate Seat
                  </button>
                </td>
              </tr>
            `).join("")}
          </tbody>
        </table>
      </div>
    `,e.querySelectorAll(".btn-wl-allocate").forEach(n=>{n.addEventListener("click",()=>{t.close(),p.info("Select a vacant seat card in the matrix to assign this student")})})}catch{e.innerHTML='<div class="text-danger p-3">Failed to load waiting list</div>'}}function I(e){const t=document.createElement("div");t.className="zone-studio-container p-2";const o=new Map;S.forEach(s=>{const u=s.zone||"General";o.has(u)||o.set(u,{name:u,total:0,available:0,occupied:0,reserved:0,color:s.zoneColor||"#6c5ce7",seatType:s.seatType||"standard",floor:s.floor||"Ground Floor",seatIds:[]});const b=o.get(u);b.total+=1,b.seatIds.push(s._id),s.status==="available"?b.available+=1:s.status==="occupied"?b.occupied+=1:s.status==="reserved"&&(b.reserved+=1),s.zoneColor&&(b.color=s.zoneColor),s.floor&&(b.floor=s.floor),s.seatType&&(b.seatType=s.seatType)});const n=Array.from(o.values()),d=Array.from(e.querySelectorAll(".seat-checkbox:checked")).map(s=>s.value),a=[{name:"Indigo",hex:"#6c5ce7"},{name:"Emerald",hex:"#00b894"},{name:"Rose",hex:"#e84393"},{name:"Amber",hex:"#f59e0b"},{name:"Cyan",hex:"#0984e3"},{name:"Violet",hex:"#8e44ad"},{name:"Teal",hex:"#00cec9"},{name:"Slate",hex:"#64748b"}],i=()=>{t.innerHTML=`
      <div style="font-family: 'Outfit', sans-serif;">
        <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom flex-wrap gap-2">
          <div>
            <h4 style="margin: 0; font-size: 1.1rem; font-weight: 700; display: flex; align-items: center; gap: 8px;">
              \u{1F3A8} Library Study Zone Studio
            </h4>
            <p class="text-muted small mb-0">Create, customize colors, edit, rename, reassign, or delete library study zones.</p>
          </div>
          <span class="badge badge-primary" style="font-size: 0.8rem; padding: 6px 12px; border-radius: 20px;">
            ${n.length} Active Study Zones
          </span>
        </div>

        <!-- 1. ACTIVE ZONES MANAGEMENT LIST -->
        <div class="mb-4">
          <div class="d-flex justify-content-between align-items-center mb-2">
            <h5 style="font-size: 0.92rem; font-weight: 700; margin: 0; text-transform: uppercase; letter-spacing: 0.5px; color: var(--color-text-secondary);">
              \u{1F4CD} Configured Study Zones (${n.length})
            </h5>
          </div>

          <div class="zone-cards-list d-flex flex-column gap-2" id="zone-items-mount">
            ${n.map(s=>`
              <div class="zone-row-card card p-3" data-zone="${r(s.name)}" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md); transition: all 0.2s ease;">
                <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                  <div class="d-flex align-items-center gap-3">
                    <div style="width: 14px; height: 14px; border-radius: 50%; background: ${s.color}; box-shadow: 0 0 8px ${s.color}88; flex-shrink: 0;"></div>
                    <div>
                      <div class="d-flex align-items-center gap-2">
                        <strong style="font-size: 1rem; color: var(--color-text-primary);">${r(s.name)}</strong>
                        <span class="badge" style="background: ${s.color}22; color: ${s.color}; border: 1px solid ${s.color}44; font-size: 0.72rem; padding: 2px 8px; border-radius: 6px;">
                          ${r(s.floor||"All Floors")}
                        </span>
                      </div>
                      <div class="d-flex align-items-center gap-3 mt-1 text-muted" style="font-size: 0.8rem;">
                        <span>\u{1FA91} <strong>${s.total}</strong> Desks</span>
                        <span style="color: var(--color-success);">\u{1F7E2} ${s.available} Vacant</span>
                        <span style="color: var(--color-danger);">\u{1F534} ${s.occupied} Occupied</span>
                        ${s.reserved>0?`<span style="color: var(--color-warning);">\u{1F7E1} ${s.reserved} Hold</span>`:""}
                      </div>
                    </div>
                  </div>

                  <!-- Zone Action Buttons -->
                  <div class="d-flex align-items-center gap-1">
                    <button type="button" class="btn btn-sm btn-outline-primary btn-edit-zone" data-zone="${r(s.name)}" title="Edit & Rename Zone" style="font-weight: 600; display: inline-flex; align-items: center; gap: 4px;">
                      \u270F\uFE0F Edit / Rename
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-secondary btn-reassign-zone" data-zone="${r(s.name)}" title="Reassign Desks to Another Zone" style="font-weight: 600; display: inline-flex; align-items: center; gap: 4px;">
                      \u{1F504} Reassign
                    </button>
                    <button type="button" class="btn btn-sm btn-outline-danger btn-delete-zone" data-zone="${r(s.name)}" title="Delete Zone" style="font-weight: 600; display: inline-flex; align-items: center; gap: 4px;">
                      \u{1F5D1}\uFE0F Delete
                    </button>
                  </div>
                </div>

                <!-- Inline Edit Form (Hidden by default) -->
                <div class="zone-inline-edit-form mt-3 pt-3 border-top" id="inline-edit-${r(s.name).replace(/[^a-zA-Z0-9]/g,"_")}" style="display: none;">
                  <h6 style="font-size: 0.88rem; font-weight: 700; margin-bottom: 10px; color: var(--color-primary);">
                    \u270F\uFE0F Modify Zone Settings: "${r(s.name)}"
                  </h6>
                  <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 10px; margin-bottom: 10px;">
                    <div>
                      <label class="form-label small" style="font-weight: 600;">Zone Name *</label>
                      <input type="text" class="form-control form-control-sm edit-zone-name" value="${r(s.name)}">
                    </div>
                    <div>
                      <label class="form-label small" style="font-weight: 600;">Floor / Category</label>
                      <input type="text" class="form-control form-control-sm edit-zone-floor" value="${r(s.floor||"")}" placeholder="e.g. Ground Floor">
                    </div>
                    <div>
                      <label class="form-label small" style="font-weight: 600;">Default Desk Type</label>
                      <select class="form-select form-select-sm edit-zone-seattype">
                        <option value="standard" ${s.seatType==="standard"?"selected":""}>Standard Desk</option>
                        <option value="glass_cabin" ${s.seatType==="glass_cabin"?"selected":""}>Glass Cabin Desk</option>
                        <option value="corner_desk" ${s.seatType==="corner_desk"?"selected":""}>Corner Focus Desk</option>
                        <option value="girls_only" ${s.seatType==="girls_only"?"selected":""}>Girls Only Dedicated</option>
                        <option value="premium" ${s.seatType==="premium"?"selected":""}>Premium Recliner</option>
                      </select>
                    </div>
                    <div>
                      <label class="form-label small" style="font-weight: 600;">Zone Theme Color</label>
                      <div class="d-flex align-items-center gap-2">
                        <input type="color" class="form-control form-control-sm edit-zone-color p-0" value="${s.color||"#6c5ce7"}" style="width: 38px; height: 32px; cursor: pointer; border-radius: 6px;">
                        <span class="small text-muted">${s.color||"#6c5ce7"}</span>
                      </div>
                    </div>
                  </div>
                  <div class="d-flex justify-content-end gap-2">
                    <button type="button" class="btn btn-sm btn-ghost btn-cancel-inline-edit" data-zone="${r(s.name)}">Cancel</button>
                    <button type="button" class="btn btn-sm btn-primary btn-save-inline-edit" data-zone="${r(s.name)}">\u{1F4BE} Save Changes</button>
                  </div>
                </div>
              </div>
            `).join("")||`
              <div class="text-center p-4 text-muted card" style="background: var(--color-bg-secondary);">
                <div style="font-size: 2rem; margin-bottom: 6px;">\u{1F4CD}</div>
                <strong>No custom study zones found</strong>
                <p class="small mb-0">Use the form below to create your first study zone.</p>
              </div>
            `}
          </div>
        </div>

        <!-- 2. CREATE NEW STUDY ZONE PANEL -->
        <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1.5px dashed var(--color-border); border-radius: var(--radius-lg);">
          <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 12px; display: flex; align-items: center; gap: 6px;">
            \u2795 Create New Library Study Zone
          </h5>
          
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; margin-bottom: 12px;">
            <div class="form-group">
              <label class="form-label small" style="font-weight: 600;">New Zone Name *</label>
              <input type="text" id="new-zone-name" class="form-control form-control-sm" placeholder="e.g. Silent Zone - 2nd Floor">
            </div>

            <div class="form-group">
              <label class="form-label small" style="font-weight: 600;">Floor / Category</label>
              <input type="text" id="new-zone-floor" class="form-control form-control-sm" placeholder="e.g. Floor 2 / AC Wing">
            </div>

            <div class="form-group">
              <label class="form-label small" style="font-weight: 600;">Default Desk Type</label>
              <select id="new-zone-seattype" class="form-select form-select-sm">
                <option value="standard">Standard Desk</option>
                <option value="glass_cabin">Glass Cabin Desk</option>
                <option value="corner_desk">Corner Focus Desk</option>
                <option value="girls_only">Girls Only Dedicated</option>
                <option value="premium">Premium Recliner</option>
              </select>
            </div>

            <div class="form-group">
              <label class="form-label small" style="font-weight: 600;">Theme Color Tag</label>
              <div class="d-flex align-items-center gap-2">
                <input type="color" id="new-zone-color" class="form-control form-control-sm p-0" value="#6c5ce7" style="width: 42px; height: 32px; cursor: pointer; border-radius: 6px;">
                <div class="d-flex gap-1 flex-wrap">
                  ${a.slice(0,5).map(s=>`
                    <div class="preset-color-swatch" data-hex="${s.hex}" title="${s.name}" style="width: 20px; height: 20px; border-radius: 4px; background: ${s.hex}; cursor: pointer; border: 1px solid rgba(0,0,0,0.1);"></div>
                  `).join("")}
                </div>
              </div>
            </div>
          </div>

          <!-- Assignment Options -->
          <div class="p-2 mb-2 rounded" style="background: var(--color-surface); border: 1px solid var(--color-border);">
            <div class="form-check form-switch mb-0">
              <input class="form-check-input" type="checkbox" id="chk-assign-selected-seats" ${d.length>0?"checked":""}>
              <label class="form-check-label small" for="chk-assign-selected-seats" style="font-weight: 600;">
                Assign ${d.length>0?`the <strong>${d.length} currently selected desks</strong>`:"selected desks"} from Seating Matrix to this new zone
              </label>
            </div>
          </div>

          <div class="d-flex justify-content-end">
            <button type="button" class="btn btn-primary btn-sm d-flex align-items-center gap-2" id="btn-create-zone" style="font-weight: 700;">
              \u2728 Create &amp; Save Study Zone
            </button>
          </div>
        </div>

        <div class="d-flex justify-content-end gap-2 pt-2 border-top">
          <button type="button" class="btn btn-secondary" id="btn-close-zone-studio">Done / Close</button>
        </div>
      </div>
    `,l()},c=new A({title:"\u{1F3A8} Library Study Zone Studio",content:t,size:"lg"});c.show();const l=()=>{t.querySelectorAll(".preset-color-swatch").forEach(s=>{s.addEventListener("click",()=>{const u=s.dataset.hex,b=t.querySelector("#new-zone-color");b&&(b.value=u)})}),t.querySelectorAll(".btn-edit-zone").forEach(s=>{s.addEventListener("click",()=>{const u=s.dataset.zone.replace(/[^a-zA-Z0-9]/g,"_"),b=t.querySelector(`#inline-edit-${u}`);if(b){const m=b.style.display!=="none";t.querySelectorAll(".zone-inline-edit-form").forEach(v=>v.style.display="none"),b.style.display=m?"none":"block"}})}),t.querySelectorAll(".btn-cancel-inline-edit").forEach(s=>{s.addEventListener("click",()=>{const u=s.dataset.zone.replace(/[^a-zA-Z0-9]/g,"_"),b=t.querySelector(`#inline-edit-${u}`);b&&(b.style.display="none")})}),t.querySelectorAll(".btn-save-inline-edit").forEach(s=>{s.addEventListener("click",async()=>{const u=s.dataset.zone,b=u.replace(/[^a-zA-Z0-9]/g,"_"),m=t.querySelector(`#inline-edit-${b}`);if(!m)return;const v=m.querySelector(".edit-zone-name")?.value?.trim(),f=m.querySelector(".edit-zone-floor")?.value?.trim(),g=m.querySelector(".edit-zone-seattype")?.value,R=m.querySelector(".edit-zone-color")?.value;if(!v){p.warning("Zone name cannot be empty");return}try{x.show();const z=await y.put("/api/seats/zones/rename",{oldZone:u,newZone:v,floor:f,seatType:g,zoneColor:R,branch:w});x.hide(),z.success?(p.success(z.message||`Zone "${v}" updated successfully!`),c.close(),await h(e),await E(e)):p.error(z.message||"Failed to update zone")}catch(z){x.hide(),p.error(z.message||"Failed to update zone")}})}),t.querySelectorAll(".btn-reassign-zone").forEach(s=>{s.addEventListener("click",async()=>{const u=s.dataset.zone,b=n.map(f=>f.name).filter(f=>f!==u),m=(b.length>0?b:["General","Zone A","Zone B"]).map(f=>`<option value="${r(f)}">${r(f)}</option>`).join(""),v=await C.prompt({title:`\u{1F504} Reassign Desks in "${u}"`,message:`Select the target zone to move all desks currently in "${u}":`,inputHtml:`
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Target Study Zone *</label>
              <select id="swal-target-zone" class="form-select">
                ${m}
                <option value="__custom__">+ Enter Custom Zone Name...</option>
              </select>
            </div>
            <div class="form-group" id="custom-target-zone-group" style="display: none;">
              <label class="form-label" style="font-weight: 600;">Custom Zone Name</label>
              <input type="text" id="swal-custom-target-zone" class="form-control" placeholder="e.g. Quiet Hall 2">
            </div>
          `,confirmText:"Reassign Desks",cancelText:"Cancel"});if(v){let f=v;v==="__custom__"&&(f=document.getElementById("swal-custom-target-zone")?.value?.trim()||"General");try{x.show();const g=await y.post("/api/seats/zones/delete",{zone:u,action:"reassign",targetZone:f,branch:w});x.hide(),g.success?(p.success(g.message||`Desks reassigned to "${f}"!`),c.close(),await h(e),await E(e)):p.error(g.message||"Failed to reassign zone desks")}catch(g){x.hide(),p.error(g.message||"Failed to reassign zone desks")}}})}),t.querySelectorAll(".btn-delete-zone").forEach(s=>{s.addEventListener("click",async()=>{const u=s.dataset.zone,b=o.get(u),m=b?b.total:0,v=n.map(g=>g.name).filter(g=>g!==u),f=(v.length>0?v:["General"]).map(g=>`<option value="${r(g)}">${r(g)}</option>`).join("");if(await C.show({title:`\u{1F5D1}\uFE0F Delete Zone: "${u}"?`,message:`This zone contains ${m} desk(s). What would you like to do with the desks in this zone?`,customHtml:`
            <div class="text-left mt-3">
              <div class="form-check mb-2">
                <input class="form-check-input" type="radio" name="zoneDeleteAction" id="actReassign" value="reassign" checked>
                <label class="form-check-label" for="actReassign" style="font-weight: 600;">
                  \u{1F504} Safe Option: Reassign desks to another zone:
                </label>
                <select id="delete-fallback-zone" class="form-select form-select-sm mt-1">
                  ${f}
                </select>
              </div>
              <div class="form-check mt-3">
                <input class="form-check-input text-danger" type="radio" name="zoneDeleteAction" id="actTrash" value="trash">
                <label class="form-check-label text-danger" for="actTrash" style="font-weight: 600;">
                  \u{1F5D1}\uFE0F Danger: Move all ${m} desks to Recycle Bin (Trash)
                </label>
              </div>
            </div>
          `,confirmText:"Delete Zone",cancelText:"Cancel",danger:!0})){const g=document.getElementById("actTrash")?.checked,R=document.getElementById("delete-fallback-zone")?.value||"General";try{x.show();const z=await y.post("/api/seats/zones/delete",{zone:u,action:g?"trash":"reassign",targetZone:R,branch:w});x.hide(),z.success?(p.success(z.message||`Zone "${u}" deleted successfully!`),c.close(),await h(e),await E(e)):p.error(z.message||"Failed to delete zone")}catch(z){x.hide(),p.error(z.message||"Failed to delete zone")}}})}),t.querySelector("#btn-create-zone")?.addEventListener("click",async()=>{const s=t.querySelector("#new-zone-name")?.value?.trim(),u=t.querySelector("#new-zone-floor")?.value?.trim()||"Ground Floor",b=t.querySelector("#new-zone-seattype")?.value||"standard",m=t.querySelector("#new-zone-color")?.value||"#6c5ce7",v=t.querySelector("#chk-assign-selected-seats")?.checked;if(!s){p.warning("Please enter a name for the new zone");return}try{if(x.show(),v&&d.length>0){const f=await y.post("/api/seats/bulk-update",{seatIds:d,updates:{zone:s,floor:u,seatType:b,zoneColor:m}});x.hide(),f.success?(p.success(`Zone "${s}" created and assigned to ${d.length} desks!`),c.close(),await h(e),await E(e)):p.error(f.message||"Failed to assign seats to zone")}else x.hide(),p.success(`Zone "${s}" created! You can now select desks in the Seating Matrix and apply this zone.`),c.close(),await E(e)}catch(f){x.hide(),p.error(f.message||"Failed to create zone")}}),t.querySelector("#btn-close-zone-studio")?.addEventListener("click",()=>{c.close()})};i()}export{J as render,I as showZoneCustomizerModal};
