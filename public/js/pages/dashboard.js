import{App as Ie}from"../app.js";import{t as R}from"../i18n.js";import{escapeHTML as A,Toast as B,Modal as U}from"../ui.js";import f from"../api.js";import{ChartEngine as H,loadChartJS}from"../charts.js";loadChartJS().catch(()=>{});const V=[{id:"kpi_active_students",label:"Active Students",isEnabled:!0,order:1,category:"kpi",icon:"\u{1F465}"},{id:"kpi_available_seats",label:"Available Seats & Live Occupancy",isEnabled:!0,order:2,category:"kpi",icon:"\u{1F4BA}"},{id:"kpi_today_revenue",label:"Today's Fee Collection",isEnabled:!0,order:3,category:"kpi",icon:"\u{1F4B0}"},{id:"kpi_expiring_soon",label:"Expiring in 48 Hours",isEnabled:!0,order:4,category:"kpi",icon:"\u23F0"},{id:"kpi_defaulter_dues",label:"Overdue Fee Balances",isEnabled:!0,order:5,category:"kpi",icon:"\u26A0\uFE0F"},{id:"kpi_total_seats",label:"Total Seat Capacity",isEnabled:!0,order:6,category:"kpi",icon:"\u{1F3E2}"},{id:"kpi_renewals_week",label:"Renewals Due This Week",isEnabled:!0,order:7,category:"kpi",icon:"\u{1F4C5}"},{id:"kpi_occupancy_gauge",label:"Live Seat Occupancy Gauge",isEnabled:!0,order:8,category:"kpi",icon:"\u{1F3AF}"},{id:"kpi_behavior_alerts",label:"At-Risk Student Alerts",isEnabled:!0,order:9,category:"kpi",icon:"\u{1F534}"},{id:"chart_revenue_trend",label:"Monthly Revenue Trend Chart",isEnabled:!0,order:10,category:"chart",icon:"\u{1F4C8}"},{id:"chart_shift_occupancy",label:"Shift Occupancy Distribution Chart",isEnabled:!0,order:11,category:"chart",icon:"\u{1F552}"},{id:"chart_exam_stats",label:"Student Exam Preparation Breakdown",isEnabled:!0,order:12,category:"chart",icon:"\u{1F3AF}"},{id:"quick_actions",label:"Quick 1-Tap Action Toolbar",isEnabled:!0,order:13,category:"action",icon:"\u26A1"},{id:"system_health",label:"System Health Monitor",isEnabled:!0,order:14,category:"kpi",icon:"\u26A1"}],L=c=>new Intl.NumberFormat("en-IN",{style:"currency",currency:"INR",maximumFractionDigits:0}).format(c||0);let q=[];async function Te(){try{const c=await f.get("/api/settings/dashboard-widgets");if(c&&c.success&&Array.isArray(c.data)&&c.data.length>0)return c.data.map((i,l)=>{const p=V.find(x=>x.id===i.id)||{};return{id:i.id,label:i.label||p.label||i.id,isEnabled:i.isEnabled!==void 0?!!i.isEnabled:!0,order:i.order!==void 0?Number(i.order):l+1,category:i.category||p.category||"kpi",icon:p.icon||"\u{1F4CA}"}}).sort((i,l)=>i.order-l.order)}catch(c){console.warn("Could not load custom dashboard widgets, using defaults:",c)}return JSON.parse(JSON.stringify(V))}function De(c){switch(c.id){case"kpi_active_students":return`
        <div class="stat-card card" data-widget-id="kpi_active_students" style="border-left: 4px solid var(--color-primary, #6c5ce7);">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">${R("dashboard.totalStudents","Active Students")}</div>
              <div class="stat-card-value" id="dash-kpi-active-students" style="color: var(--color-primary, #6c5ce7);">0</div>
              <div class="text-xs text-muted" id="dash-kpi-total-students-sub" style="margin-top: 4px;">Total registered: 0</div>
            </div>
            <div class="stat-card-icon" style="background: var(--color-primary-bg, rgba(108, 92, 231, 0.15)); color: var(--color-primary, #6c5ce7);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
            </div>
          </div>
        </div>
      `;case"kpi_available_seats":return`
        <div class="stat-card card" data-widget-id="kpi_available_seats" style="border-left: 4px solid var(--color-success, #00b894);">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">${R("dashboard.occupiedSeats","Available Seats & Occupancy")}</div>
              <div class="stat-card-value" id="dash-kpi-available-seats" style="color: var(--color-success, #00b894);">0 Available</div>
              <div class="text-xs text-muted" id="dash-kpi-seats-sub" style="margin-top: 4px;">0 / 0 Occupied</div>
            </div>
            <div class="stat-card-icon" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success, #00b894);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M5 16V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v12"></path><path d="M3 16h18"></path><path d="M5 16v4"></path><path d="M19 16v4"></path></svg>
            </div>
          </div>
        </div>
      `;case"kpi_today_revenue":return`
        <div class="stat-card card" data-widget-id="kpi_today_revenue" style="border-left: 4px solid var(--color-info, #0984e3);">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">Today's Fee Collection</div>
              <div class="stat-card-value" id="dash-kpi-today-revenue" style="color: var(--color-info, #0984e3);">\u20B90</div>
              <div class="text-xs text-muted" id="dash-kpi-month-rev-sub" style="margin-top: 4px;">Month: \u20B90</div>
            </div>
            <div class="stat-card-icon" style="background: rgba(9, 132, 227, 0.15); color: var(--color-info, #0984e3);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>
            </div>
          </div>
        </div>
      `;case"kpi_expiring_soon":return`
        <div class="stat-card card" data-widget-id="kpi_expiring_soon" style="border-left: 4px solid #fdcb6e;">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">Expiring in 48 Hours</div>
              <div class="stat-card-value" id="dash-kpi-expiring-soon" style="color: #fdcb6e;">0</div>
              <div class="text-xs text-muted" id="dash-kpi-expiring-sub" style="margin-top: 4px;">Next 7 days: 0</div>
            </div>
            <div class="stat-card-icon" style="background: rgba(253, 203, 110, 0.15); color: #fdcb6e;">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
            </div>
          </div>
        </div>
      `;case"kpi_defaulter_dues":return`
        <div class="stat-card card" data-widget-id="kpi_defaulter_dues" style="border-left: 4px solid var(--color-danger, #d63031);">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">${R("dashboard.pendingDues","Overdue Fee Balances")}</div>
              <div class="stat-card-value" id="dash-kpi-defaulter-dues" style="color: var(--color-danger, #d63031);">\u20B90</div>
              <div class="text-xs text-muted" id="dash-kpi-dues-sub" style="margin-top: 4px;">Pending payments</div>
            </div>
            <div class="stat-card-icon" style="background: rgba(214, 48, 49, 0.15); color: var(--color-danger, #d63031);">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>
            </div>
          </div>
        </div>
      `;case"kpi_total_seats":return`
        <div class="stat-card card" data-widget-id="kpi_total_seats" style="border-left: 4px solid #a29bfe;">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">Total Seat Capacity</div>
              <div class="stat-card-value" id="dash-kpi-total-seats" style="color: #a29bfe;">0 Desks</div>
              <div class="text-xs text-muted" id="dash-kpi-total-seats-sub" style="margin-top: 4px;">Full branch capacity</div>
            </div>
            <div class="stat-card-icon" style="background: rgba(162, 155, 254, 0.15); color: #a29bfe;">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>
            </div>
          </div>
        </div>
      `;case"quick_actions":return`
        <div class="card mb-4" data-widget-id="quick_actions">
          <div class="card-header flex-between">
            <h5 style="margin: 0; font-size: 1.05rem; font-weight: 600;">\u26A1 Quick 1-Tap Action Toolbar</h5>
            <span class="badge badge-primary" style="font-size: 11px;">Fast Shortcuts</span>
          </div>
          <div class="card-body" style="display: flex; gap: var(--space-3); flex-wrap: wrap;">
            <a href="#/students" class="btn btn-primary d-flex align-items-center gap-2">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
              + Add New Student
            </a>
            <a href="#/payments" class="btn btn-success d-flex align-items-center gap-2">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>
              \u{1F4B0} Collect Fee Payment
            </a>
            <a href="#/seats" class="btn btn-outline-secondary d-flex align-items-center gap-2">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M5 16V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v12"></path><path d="M3 16h18"></path></svg>
              \u{1F4BA} View Seat Matrix
            </a>
            <a href="#/lockers" class="btn btn-outline-secondary d-flex align-items-center gap-2">
              \u{1F510} Manage Lockers
            </a>
            <a href="#/attendance" class="btn btn-outline-secondary d-flex align-items-center gap-2">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>
              \u23F1\uFE0F Daily Attendance Log
            </a>
            <a href="/kiosk" target="_blank" class="btn btn-outline-secondary d-flex align-items-center gap-2">
              \u{1F4F2} Launch Gate Kiosk
            </a>
            <a href="#/reports" class="btn btn-outline-secondary d-flex align-items-center gap-2">
              \u{1F4CA} Analytics & EOD
            </a>
          </div>
        </div>
      `;case"chart_revenue_trend":return`
        <div class="card" data-widget-id="chart_revenue_trend">
          <div class="card-header flex-between">
            <h5 style="margin: 0; font-size: 1.05rem; font-weight: 600;">\u{1F4C8} Monthly Revenue Trend</h5>
            <span class="badge badge-info" id="dash-trend-total">\u20B90 Total</span>
          </div>
          <div class="card-body">
            <div style="position: relative; height: 220px; width: 100%;">
              <canvas id="chart-revenue-trend-canvas" style="width: 100%; height: 220px;"></canvas>
            </div>
          </div>
        </div>
      `;case"chart_shift_occupancy":return`
        <div class="card" data-widget-id="chart_shift_occupancy">
          <div class="card-header flex-between">
            <h5 style="margin: 0; font-size: 1.05rem; font-weight: 600;">\u{1F552} Shift Occupancy Distribution</h5>
            <span class="badge badge-success" id="dash-shift-total">0 Enrolled</span>
          </div>
          <div class="card-body">
            <div style="position: relative; height: 220px; width: 100%;">
              <canvas id="chart-shift-occupancy-canvas" style="width: 100%; height: 220px;"></canvas>
            </div>
            <div id="chart-shift-legend" class="d-flex justify-content-center flex-wrap gap-2 mt-3" style="font-size: 12px;"></div>
          </div>
        </div>
      `;case"chart_exam_stats":return`
        <div class="card" data-widget-id="chart_exam_stats">
          <div class="card-header flex-between">
            <h5 style="margin: 0; font-size: 1.05rem; font-weight: 600;">\u{1F3AF} Student Exam Preparation Breakdown</h5>
            <span class="badge badge-primary" id="dash-exam-total">Target Exams</span>
          </div>
          <div class="card-body">
            <div style="position: relative; height: 220px; width: 100%;">
              <canvas id="chart-exam-stats-canvas" style="width: 100%; height: 220px;"></canvas>
            </div>
            <div id="chart-exam-legend" class="d-flex justify-content-center flex-wrap gap-2 mt-3" style="font-size: 12px;"></div>
          </div>
        </div>
      `;case"kpi_renewals_week":return`
        <div class="stat-card card" data-widget-id="kpi_renewals_week" style="border-left: 4px solid #6c5ce7; cursor:pointer;" onclick="window.location.hash='#/students'">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">\u{1F4C5} Renewals Due This Week</div>
              <div class="stat-card-value" id="dash-kpi-renewals-week" style="color:#6c5ce7;">0 students</div>
              <div class="text-xs text-muted" id="dash-kpi-renewals-sub" style="margin-top:4px;">Expiring in next 7 days</div>
            </div>
            <div class="stat-card-icon" style="background:rgba(108,92,231,0.15);color:#6c5ce7;">\u{1F4C5}</div>
          </div>
          <div style="padding:0 16px 12px;display:flex;gap:8px;flex-wrap:wrap;" id="dash-renewal-wa-actions">
            <button class="btn btn-xs btn-outline-success dash-wa-blast-btn" style="font-size:0.72rem;padding:3px 10px;" onclick="event.stopPropagation();window._dashWABlast && window._dashWABlast()">
              \u{1F4F2} WA Blast Renewals
            </button>
          </div>
        </div>`;case"kpi_occupancy_gauge":return`
        <div class="stat-card card" data-widget-id="kpi_occupancy_gauge" style="border-left: 4px solid #00cec9;">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">\u{1F3AF} Seat Occupancy</div>
              <div style="display:flex;align-items:center;gap:12px;margin-top:6px;">
                <div style="position:relative;width:56px;height:56px;flex-shrink:0;">
                  <svg viewBox="0 0 36 36" style="width:56px;height:56px;transform:rotate(-90deg);">
                    <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                          fill="none" stroke="rgba(148,163,184,0.2)" stroke-width="4"/>
                    <path id="dash-gauge-arc" d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                          fill="none" stroke="#00cec9" stroke-width="4" stroke-dasharray="0, 100" stroke-linecap="round"/>
                  </svg>
                  <div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:0.75rem;font-weight:800;color:#00cec9;" id="dash-gauge-pct">0%</div>
                </div>
                <div>
                  <div class="stat-card-value" id="dash-kpi-occ-value" style="color:#00cec9;font-size:1.3rem;">0/0</div>
                  <div class="text-xs text-muted" id="dash-kpi-occ-sub">Occupied / Total Seats</div>
                </div>
              </div>
            </div>
          </div>
        </div>`;case"kpi_behavior_alerts":return`
        <div class="stat-card card" data-widget-id="kpi_behavior_alerts" style="border-left: 4px solid #d63031; cursor:pointer;" onclick="window.location.hash='#/students'">
          <div class="stat-card-body">
            <div class="stat-card-info">
              <div class="stat-card-title">\u{1F534} At-Risk Students</div>
              <div class="stat-card-value" id="dash-kpi-behavior-alerts" style="color:#d63031;">0</div>
              <div class="text-xs text-muted" id="dash-kpi-alerts-sub" style="margin-top:4px;">Low attendance (&lt;50%) or expired</div>
            </div>
            <div class="stat-card-icon" style="background:rgba(214,48,49,0.15);color:#d63031;">\u26A0\uFE0F</div>
          </div>
        </div>`;case"system_health":return`
        <div data-widget-id="system_health" id="dash-system-health-widget">
          ${window.PerformanceMonitor?window.PerformanceMonitor.renderHealthWidget():'<div class="card p-3 text-center text-muted">\u26A1 System Health loading...</div>'}
        </div>
      `;default:return""}}function Le(c){const i=c.filter(b=>b.isEnabled).sort((b,m)=>b.order-m.order);if(i.length===0)return`
      <div class="card text-center p-5 mb-4">
        <div style="font-size: 3rem; margin-bottom: 12px;">\u{1F39B}\uFE0F</div>
        <h4 style="margin: 0 0 8px 0;">All Dashboard Widgets are Hidden</h4>
        <p class="text-muted mb-3">Click customize above to re-enable KPI cards, charts, and quick actions.</p>
        <div>
          <button id="btn-empty-customize" class="btn btn-primary">\u2699\uFE0F Customize Dashboard Widgets</button>
        </div>
      </div>
    `;let l='<div class="dashboard-dynamic-container">',p=null,x=[];const y=()=>{x.length!==0&&(p==="kpi"?l+=`<div class="stats-grid mb-4" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 230px), 1fr)); gap: 1rem;">${x.join("")}</div>`:p==="chart"?l+=`<div class="charts-grid mb-4" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 340px), 1fr)); gap: 1.5rem;">${x.join("")}</div>`:l+=x.join(""),x=[],p=null)};return i.forEach(b=>{const m=De(b);m&&(b.category==="kpi"?(p!=="kpi"&&y(),p="kpi",x.push(m)):b.category==="chart"?(p!=="chart"&&y(),p="chart",x.push(m)):(y(),x.push(m),y()))}),y(),l+="</div>",l}function Se(c){let i=JSON.parse(JSON.stringify(q));const l=document.createElement("div");l.className="dashboard-customize-container";const p=()=>{l.innerHTML=`
      <div style="margin-bottom: 16px;">
        <p class="text-muted small mb-3">
          Toggle switch to show/hide widgets. Drag the handle <span style="font-weight: bold;">\u22EE\u22EE</span> or use \u2B06\uFE0F / \u2B07\uFE0F buttons to reorder your dashboard layout.
        </p>
      </div>
      
      <div id="customize-widget-list" class="d-flex flex-column gap-2" style="max-height: 440px; overflow-y: auto; padding-right: 4px;">
        ${i.map((e,a)=>{let o="badge-primary",h="KPI";return e.category==="chart"?(o="badge-info",h="Chart"):e.category==="action"&&(o="badge-warning",h="Action"),`
            <div class="customize-item card p-3" 
                 draggable="true" 
                 data-id="${A(e.id)}" 
                 data-index="${a}"
                 style="display: flex; flex-direction: row; align-items: center; justify-content: space-between; gap: 12px; background: var(--color-bg-secondary, rgba(255,255,255,0.03)); border: 1px solid var(--color-border, rgba(255,255,255,0.08)); border-radius: 8px; cursor: grab; user-select: none; transition: background 0.15s ease;">
              
              <div class="d-flex align-items-center gap-3" style="flex: 1; min-width: 0;">
                <span class="drag-handle text-muted" style="cursor: grab; font-size: 1.2rem; line-height: 1;" title="Drag to reorder">\u22EE\u22EE</span>
                <span style="font-size: 1.3rem;">${A(e.icon||"\u{1F4CA}")}</span>
                <div style="min-width: 0;">
                  <div style="font-weight: 600; font-size: 14px; display: flex; align-items: center; gap: 8px;">
                    <span>${A(e.label)}</span>
                    <span class="badge ${o}" style="font-size: 10px; padding: 2px 6px;">${h}</span>
                  </div>
                  <div class="text-xs text-muted">Position #${a+1}</div>
                </div>
              </div>

              <div class="d-flex align-items-center gap-2">
                <button type="button" class="btn btn-sm btn-icon btn-move-up" data-index="${a}" ${a===0?'disabled style="opacity: 0.3;"':""} title="Move Up" style="padding: 4px 8px; font-size: 13px;">
                  \u2B06\uFE0F
                </button>
                <button type="button" class="btn btn-sm btn-icon btn-move-down" data-index="${a}" ${a===i.length-1?'disabled style="opacity: 0.3;"':""} title="Move Down" style="padding: 4px 8px; font-size: 13px;">
                  \u2B07\uFE0F
                </button>

                <label class="switch-label" style="margin-left: 8px;">
                  <input type="checkbox" class="widget-toggle-input" data-index="${a}" ${e.isEnabled?"checked":""}>
                  <span class="switch-slider"></span>
                  <span class="small ms-1" style="font-size: 12px; min-width: 32px; font-weight: 700; color: ${e.isEnabled?"var(--color-success)":"var(--color-text-muted, #888)"};">
                    ${e.isEnabled?"ON":"OFF"}
                  </span>
                </label>
              </div>
            </div>
          `}).join("")}
      </div>

      <div class="d-flex justify-content-between align-items-center mt-4 pt-3" style="border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08));">
        <button type="button" id="btn-reset-widgets" class="btn btn-outline text-muted btn-sm">
          \u{1F504} Reset Defaults
        </button>
        <div class="d-flex gap-2">
          <button type="button" id="btn-cancel-widgets" class="btn btn-outline-secondary">
            Cancel
          </button>
          <button type="button" id="btn-save-widgets" class="btn btn-primary d-flex align-items-center gap-2">
            \u{1F4BE} Save Layout
          </button>
        </div>
      </div>
    `;const x=l.querySelector("#customize-widget-list");let y=null;x.querySelectorAll(".customize-item").forEach(e=>{e.addEventListener("dragstart",a=>{y=Number(e.getAttribute("data-index")),a.dataTransfer.effectAllowed="move",e.style.opacity="0.4"}),e.addEventListener("dragover",a=>{a.preventDefault(),a.dataTransfer.dropEffect="move",e.style.borderTop="2px solid var(--color-primary, #6c5ce7)"}),e.addEventListener("dragleave",()=>{e.style.borderTop="1px solid var(--color-border, rgba(255,255,255,0.08))"}),e.addEventListener("drop",a=>{a.preventDefault(),e.style.borderTop="1px solid var(--color-border, rgba(255,255,255,0.08))";const o=Number(e.getAttribute("data-index"));if(y!==null&&y!==o){const h=i.splice(y,1)[0];i.splice(o,0,h),i.forEach((k,$)=>{k.order=$+1}),p()}}),e.addEventListener("dragend",()=>{e.style.opacity="1"})}),l.querySelectorAll(".btn-move-up").forEach(e=>{e.onclick=()=>{const a=Number(e.getAttribute("data-index"));if(a>0){const o=i[a];i[a]=i[a-1],i[a-1]=o,i.forEach((h,k)=>{h.order=k+1}),p()}}}),l.querySelectorAll(".btn-move-down").forEach(e=>{e.onclick=()=>{const a=Number(e.getAttribute("data-index"));if(a<i.length-1){const o=i[a];i[a]=i[a+1],i[a+1]=o,i.forEach((h,k)=>{h.order=k+1}),p()}}}),l.querySelectorAll(".widget-toggle-input").forEach(e=>{e.onchange=()=>{const a=Number(e.getAttribute("data-index"));i[a].isEnabled=e.checked,p()}});const b=l.querySelector("#btn-reset-widgets");b&&(b.onclick=()=>{i=JSON.parse(JSON.stringify(V)),p(),B.info("Layout reset to default order")});const m=l.querySelector("#btn-cancel-widgets");m&&(m.onclick=()=>{U.close()});const w=l.querySelector("#btn-save-widgets");w&&(w.onclick=async()=>{w.disabled=!0,w.innerHTML="Saving...";try{i.forEach((a,o)=>{a.order=o+1});const e=await f.put("/api/settings/dashboard-widgets",{widgets:i});e&&e.success?(B.success("Dashboard layout saved successfully!"),q=i,U.close(),c&&c(i)):(B.error(e?.message||"Failed to save widget layout"),w.disabled=!1,w.innerHTML="\u{1F4BE} Save Layout")}catch(e){console.error(e),B.error(e.message||"Error saving dashboard widgets"),w.disabled=!1,w.innerHTML="\u{1F4BE} Save Layout"}})};p(),U.show({title:"\u2699\uFE0F Customize Dashboard Layout & KPI Studio",content:l,size:"lg"})}async function W(c){const i=c||document.getElementById("page-content");if(!i)return;const l=Ie.getUser()||{name:"Admin"},p=["owner","branch_manager","admin"].includes(l.role);q=await Te();const x=new Date().getHours(),y=x<12?"\u{1F305} Good Morning":x<17?"\u{1F324}\uFE0F Good Afternoon":"\u{1F319} Good Evening";i.innerHTML=`
    <div class="portal-container">
      
      <!-- Top Welcome & Master Action Header -->
      <div class="card mb-3 p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
          <div style="display: flex; align-items: center; gap: 12px; min-width: 220px;">
            <div style="
              width: 52px; height: 52px; border-radius: 50%;
              background: var(--color-primary-bg); color: var(--color-primary);
              font-size: 1.3rem; font-weight: 800; display: flex; align-items: center; justify-content: center;
              border: 2px solid var(--color-primary); flex-shrink: 0;
              box-shadow: 0 4px 12px rgba(108, 92, 231, 0.2);
            ">
              \u{1F451}
            </div>
            <div>
              <div style="font-size: 0.76rem; font-weight: 600; color: var(--color-text-secondary); margin-bottom: 2px;">
                ${y}, ${A(l.name)}!
              </div>
              <h1 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-text-primary); line-height: 1.2;">
                ${R("nav.dashboard","Admin Console")}
              </h1>
              <div style="font-size: 0.78rem; color: var(--color-text-muted); margin-top: 2px; font-weight: 600;">
                Live Study Library Command Centre
              </div>
            </div>
          </div>

          <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
            <button id="btn-refresh-dashboard" class="btn btn-outline-secondary btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border-radius: 10px;">
              \u{1F504} Refresh
            </button>
            ${p?`
              <button id="btn-customize-dashboard" class="btn btn-outline-primary btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border-radius: 10px;">
                \u2699\uFE0F Widgets
              </button>
            `:""}
            <a href="/kiosk" target="_blank" class="btn btn-primary btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 14px; border-radius: 10px;">
              \u{1F4F2} Kiosk
            </a>
          </div>
        </div>
      </div>

      <!-- 1. Executive Summary Hero Pass Card -->
      <div class="admin-hero-card mb-3" style="
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
        <div style="display: flex; justify-content: space-between; align-items: flex-start; position: relative; z-index: 1; flex-wrap: wrap; gap: 12px;">
          <div>
            <div style="font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.8px; opacity: 0.85; font-weight: 700; color: #ffffff;">
              Live Library Occupancy
            </div>
            <div style="font-size: 1.85rem; font-weight: 900; line-height: 1.1; margin-top: 2px; text-shadow: 0 2px 8px rgba(0,0,0,0.2); color: #ffffff;" id="dash-hero-occ">
              0 / 0 Seats
            </div>
            <div style="font-size: 0.78rem; opacity: 0.92; margin-top: 2px; font-weight: 600; color: #ffffff;" id="dash-hero-checkin">
              \u{1F7E2} 0 students checked in right now
            </div>
          </div>

          <!-- Today's Revenue Pill -->
          <div style="text-align: right;">
            <span style="background: rgba(255,255,255,0.22); backdrop-filter: blur(8px); padding: 5px 12px; border-radius: 20px; font-weight: 800; font-size: 0.84rem; letter-spacing: 0.3px; border: 1px solid rgba(255,255,255,0.3); display: inline-block; color: #ffffff;" id="dash-hero-revenue">
              \u20B90 Today
            </span>
            <div style="font-size: 0.72rem; opacity: 0.88; margin-top: 4px; font-weight: 600; color: #ffffff;" id="dash-hero-students">
              0 Active Members
            </div>
          </div>
        </div>

        <!-- Occupancy Gauge Progress Line -->
        <div style="margin-top: 14px; background: rgba(0,0,0,0.25); height: 6px; border-radius: 4px; overflow: hidden; position: relative; z-index: 1;">
          <div id="dash-hero-progress-bar" style="height: 100%; width: 0%; background: linear-gradient(90deg, #34d399, #a7f3d0); border-radius: 4px; transition: width 0.6s ease;"></div>
        </div>

        <!-- Quick 1-Tap Admin Action Triggers -->
        <div style="margin-top: 14px; padding-top: 12px; border-top: 1px dashed rgba(255,255,255,0.25); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; position: relative; z-index: 1;">
          <a href="#/students" class="btn btn-sm btn-success" style="font-weight: 800; font-size: 0.84rem; padding: 7px 16px; border-radius: 10px; text-decoration: none; flex: 1 1 140px; text-align: center;">
            \u2795 New Admission
          </a>
          <a href="#/payments" class="btn btn-sm" style="background: rgba(255,255,255,0.22); color: #ffffff; border: 1px solid rgba(255,255,255,0.4); font-weight: 700; font-size: 0.82rem; padding: 7px 14px; border-radius: 10px; backdrop-filter: blur(8px); text-decoration: none; flex: 1 1 120px; text-align: center;">
            \u{1F4B3} Collect Fee
          </a>
          <a href="#/notifications" class="btn btn-sm" style="background: rgba(255,255,255,0.22); color: #ffffff; border: 1px solid rgba(255,255,255,0.4); font-weight: 700; font-size: 0.82rem; padding: 7px 14px; border-radius: 10px; backdrop-filter: blur(8px); text-decoration: none; flex: 1 1 120px; text-align: center;">
            \u{1F4E2} Broadcast
          </a>
        </div>
      </div>

      <!-- 2. Admin Quick Launchpad Grid (8 Responsive Micro-Tiles) -->
      <div style="
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(min(100%, 82px), 1fr));
        gap: 8px;
        margin-bottom: 1.25rem;
      ">
        <a href="#/students" class="admin-app-tile" title="Manage Students & Admissions" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(99, 102, 241, 0.18), rgba(99, 102, 241, 0.08)); color: var(--color-primary);">\u{1F393}</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Students</div>
        </a>
        <a href="#/seats" class="admin-app-tile" title="Seat Matrix & Floor Plan" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(16, 185, 129, 0.18), rgba(16, 185, 129, 0.08)); color: var(--color-success);">\u{1F4BA}</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Seats</div>
        </a>
        <a href="#/payments" class="admin-app-tile" title="Fee Collections & Invoices" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(14, 165, 233, 0.18), rgba(14, 165, 233, 0.08)); color: #0ea5e9;">\u{1F4B3}</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Payments</div>
        </a>
        <a href="#/attendance" class="admin-app-tile" title="Live Attendance & RFID Log" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(20, 184, 166, 0.18), rgba(20, 184, 166, 0.08)); color: #14b8a6;">\u{1F465}</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Attendance</div>
        </a>
        <a href="#/expenses" class="admin-app-tile" title="Expenses & Daily P&L" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(236, 72, 153, 0.18), rgba(236, 72, 153, 0.08)); color: #ec4899;">\u{1F4CA}</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Expenses</div>
        </a>
        <a href="#/notifications" class="admin-app-tile" title="Send WhatsApp & Push Alerts" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(245, 158, 11, 0.18), rgba(245, 158, 11, 0.08)); color: var(--color-warning);">\u{1F4E2}</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Broadcast</div>
        </a>
        <a href="#/reports" class="admin-app-tile" title="Business Analytics & Tax Reports" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(168, 85, 247, 0.18), rgba(168, 85, 247, 0.08)); color: #a855f7;">\u{1F4C8}</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Reports</div>
        </a>
        <a href="#/settings" class="admin-app-tile" title="System & POS Configuration" style="display: flex; flex-direction: column; align-items: center; justify-content: center; text-align: center; gap: 6px; padding: 12px 6px; border-radius: 16px; background: var(--color-surface); border: 1px solid var(--color-border); cursor: pointer; min-height: 88px; box-sizing: border-box; text-decoration: none; box-shadow: var(--shadow-sm);">
          <div class="admin-tile-icon" style="width: 44px; height: 44px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 1.35rem; margin: 0 auto; box-shadow: 0 4px 10px rgba(0,0,0,0.08); background: linear-gradient(135deg, rgba(100, 116, 139, 0.18), rgba(100, 116, 139, 0.08)); color: var(--color-text-muted);">\u2699\uFE0F</div>
          <div class="admin-tile-label" style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-primary); line-height: 1.2; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 100%;">Settings</div>
        </a>
      </div>

      <!-- 3. Segmented Tab Navigation Track -->
      <div class="portal-tab-track" style="display: flex; background: var(--color-bg-secondary); padding: 4px; border-radius: 14px; border: 1px solid var(--color-border); margin-bottom: 1.25rem; gap: 4px; overflow-x: auto;">
        <button type="button" class="portal-tab-pill active" data-admin-tab="live-ops" style="flex: 1; min-width: 110px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: var(--color-surface); color: var(--color-primary); box-shadow: 0 2px 8px rgba(0,0,0,0.12); transition: all 0.2s; white-space: nowrap; padding: 6px 12px;">
          \u{1F4CA} Operations & KPI
        </button>
        <button type="button" class="portal-tab-pill" data-admin-tab="expiring" style="flex: 1; min-width: 110px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: transparent; color: var(--color-text-secondary); transition: all 0.2s; white-space: nowrap; padding: 6px 12px;">
          \u23F3 Expiring Soon
        </button>
        <button type="button" class="portal-tab-pill" data-admin-tab="pulse" style="flex: 1; min-width: 110px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: transparent; color: var(--color-text-secondary); transition: all 0.2s; white-space: nowrap; padding: 6px 12px;">
          \u{1F4C8} Analytics & Trends
        </button>
      </div>

      <!-- TAB PANE 1: Operations & Dynamic KPI -->
      <div id="pane-admin-live-ops" class="admin-tab-pane">
        <div id="dashboard-layout-root">
          ${Le(q)}
        </div>
      </div>

      <!-- TAB PANE 2: Expiring Soon List -->
      <div id="pane-admin-expiring" class="admin-tab-pane" style="display: none;">
        <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div class="card-header p-3" style="border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
            <h5 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary);">\u23F0 Memberships Expiring in 7 Days</h5>
            <a href="#/students" class="btn btn-sm btn-outline-primary" style="font-size: 0.78rem; padding: 4px 10px; font-weight: 600; text-decoration: none;">View All Students</a>
          </div>
          <div class="card-body p-0" id="dash-expiring-container" style="max-height: 480px; overflow-y: auto;">
            <div class="p-4 text-center text-muted">Checking upcoming expiries...</div>
          </div>
        </div>
      </div>

      <!-- TAB PANE 3: Analytics & Real-Time Pulse -->
      <div id="pane-admin-pulse" class="admin-tab-pane" style="display: none;">
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
          <!-- Live Overview & Hourly Activity -->
          <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
            <div class="card-header p-3 flex-between" style="border-bottom: 1px solid var(--color-divider);">
              <h5 style="margin: 0; font-size: 1.02rem; font-weight: 700;">\u{1F514} Real-Time Attendance Pulse</h5>
              <span class="badge badge-success" style="font-weight: 700; font-size: 0.72rem;">\u25CF Live</span>
            </div>
            <div class="card-body p-3">
              <div class="d-flex flex-column gap-2 mb-3">
                <div class="p-2 px-3" style="background: var(--color-bg-secondary); border-radius: 8px; display: flex; justify-content: space-between; align-items: center; font-size: 0.88rem;">
                  <span>Currently Studying Inside:</span>
                  <strong id="dash-present-today" style="font-size: 1.1rem; color: var(--color-primary);">0 Students</strong>
                </div>
                <div class="p-2 px-3" style="background: var(--color-bg-secondary); border-radius: 8px; display: flex; justify-content: space-between; align-items: center; font-size: 0.88rem;">
                  <span>Available Desks:</span>
                  <strong id="dash-available-seats" class="text-success" style="font-size: 1.1rem;">0 Available</strong>
                </div>
                <div class="p-2 px-3" style="background: var(--color-bg-secondary); border-radius: 8px; display: flex; justify-content: space-between; align-items: center; font-size: 0.88rem;">
                  <span>Active Subscriptions:</span>
                  <strong id="dash-active-subs" class="text-info" style="font-size: 1.1rem;">0</strong>
                </div>
              </div>
              <canvas id="dashboard-chart" style="width: 100%; height: 180px;"></canvas>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;const b=i.querySelectorAll(".portal-tab-pill[data-admin-tab]"),m={"live-ops":i.querySelector("#pane-admin-live-ops"),expiring:i.querySelector("#pane-admin-expiring"),pulse:i.querySelector("#pane-admin-pulse")},w=e=>{b.forEach(a=>{const o=a.getAttribute("data-admin-tab")===e;a.classList.toggle("active",o),a.style.background=o?"var(--color-surface)":"transparent",a.style.color=o?"var(--color-primary)":"var(--color-text-secondary)",a.style.boxShadow=o?"0 2px 8px rgba(0, 0, 0, 0.12)":"none"}),Object.keys(m).forEach(a=>{m[a]&&(m[a].style.display=a===e?"block":"none")})};b.forEach(e=>{e.addEventListener("click",()=>{w(e.getAttribute("data-admin-tab"))})}),(()=>{const e=document.getElementById("btn-refresh-dashboard");e&&(e.onclick=()=>{B.info("Refreshing live dashboard telemetry..."),W(c)});const a=document.getElementById("btn-customize-dashboard");a&&(a.onclick=()=>Se(h=>{W(c)}));const o=document.getElementById("btn-empty-customize");o&&(o.onclick=()=>Se(h=>{W(c)}))})();try{const[e,a,o,h,k,$,G,I]=await Promise.allSettled([f.get("/api/students/stats"),f.get("/api/seats/stats"),f.get("/api/payments/stats"),f.get("/api/attendance/today"),f.get("/api/reports/expiries?days=7"),f.get("/api/shifts/stats"),f.get("/api/reports/revenue"),f.get("/api/students?limit=200")]),F=e.status==="fulfilled"&&e.value?.success?e.value.data:{},M=a.status==="fulfilled"&&a.value?.success?a.value.data:{},T=o.status==="fulfilled"&&o.value?.success?o.value.data:{},N=h.status==="fulfilled"&&h.value?.success?h.value.data:{},j=k.status==="fulfilled"&&k.value?.data?k.value.data:{},D=Array.isArray(j?.students)?j.students:Array.isArray(j)?j:[],P=$.status==="fulfilled"&&$.value?.data?$.value.data:{},S=G.status==="fulfilled"&&G.value?.data?G.value.data:{},J=I.status==="fulfilled"&&I.value?.data?.students?I.value.data.students:Array.isArray(I.value?.data)?I.value.data:[],Y=document.getElementById("dash-hero-occ"),X=document.getElementById("dash-hero-checkin"),Z=document.getElementById("dash-hero-revenue"),ee=document.getElementById("dash-hero-students"),te=document.getElementById("dash-hero-progress-bar"),z=M.occupied??0,C=M.total??0,ae=M.available??Math.max(0,C-z),_=C>0?Math.round(z/C*100):0,ze=N.stats?.totalPresent||N.stats?.totalCheckedIn||0;Y&&(Y.textContent=`${z} / ${C} Seats (${_}%)`),X&&(X.textContent=`\u{1F7E2} ${ze} students currently studying inside`),Z&&(Z.textContent=`${L(T.todayRevenue)} Today`),ee&&(ee.textContent=`${F.active||0} Active Members`),te&&(te.style.width=`${Math.min(100,Math.max(0,_))}%`);const ie=document.getElementById("dash-kpi-active-students"),se=document.getElementById("dash-kpi-total-students-sub");ie&&(ie.textContent=F.active??0),se&&(se.textContent=`Total registered: ${F.total??0}`);const re=document.getElementById("dash-kpi-available-seats"),ne=document.getElementById("dash-kpi-seats-sub");re&&(re.textContent=`${ae} Available`),ne&&(ne.textContent=`${z} / ${C} Occupied (${_}%)`);const de=document.getElementById("dash-kpi-today-revenue"),oe=document.getElementById("dash-kpi-month-rev-sub");de&&(de.textContent=L(T.todayRevenue)),oe&&(oe.textContent=`Month: ${L(T.monthRevenue)}`);const le=document.getElementById("dash-kpi-expiring-soon"),ce=document.getElementById("dash-kpi-expiring-sub"),pe=D.filter(t=>t.daysRemaining!==void 0?t.daysRemaining<=2:t.expiryDate?(new Date(t.expiryDate)-new Date)/864e5<=2:!1).length;le&&(le.textContent=`${pe} Students`),ce&&(ce.textContent=`Next 7 days: ${D.length} total`);const ue=document.getElementById("dash-kpi-defaulter-dues"),ge=document.getElementById("dash-kpi-dues-sub"),_e=T.totalPending||S.summary?.pendingDues||0;ue&&(ue.textContent=L(_e)),ge&&(ge.textContent=S.summary?.pendingStudentsCount?`${S.summary.pendingStudentsCount} students with dues`:"Pending recovery");const ve=document.getElementById("dash-kpi-total-seats"),xe=document.getElementById("dash-kpi-total-seats-sub");ve&&(ve.textContent=`${C} Desks`),xe&&(xe.textContent=`${z} Occupied, ${M.maintenance||0} Maintenance`);const he=document.getElementById("dash-kpi-renewals-week"),be=document.getElementById("dash-kpi-renewals-sub"),O=D.filter(t=>{if(t.daysRemaining!==void 0)return t.daysRemaining>=0&&t.daysRemaining<=7;if(t.expiryDate){const n=(new Date(t.expiryDate)-new Date)/864e5;return n>=0&&n<=7}return!1});he&&(he.textContent=`${O.length} students`),be&&(be.textContent=`${pe} expiring today / tomorrow`),window._dashWABlast=async()=>{if(!O.length){window.Toast&&B.info("No renewals due this week");return}let t="Study Library";try{t=(await f.get("/api/settings"))?.data?.businessProfile?.businessName||t}catch{}for(const n of O){const r=(n.phone||"").replace(/[^0-9]/g,"");if(!r||r.length<10)continue;const v=r.length===10?"91"+r:r,u=n.expiryDate?new Date(n.expiryDate).toLocaleDateString("en-IN"):"soon",s=`Hi ${n.name}! \u{1F44B}
Your library membership expires on *${u}*.
Please renew to continue your studies. \u{1F4DA}

\u2014 ${t}`;window.open(`https://wa.me/${v}?text=${encodeURIComponent(s)}`,"_blank"),await new Promise(d=>setTimeout(d,700))}window.Toast&&B.success(`\u{1F4F2} Opened ${O.length} WA links`)};const me=document.getElementById("dash-gauge-arc"),ye=document.getElementById("dash-gauge-pct"),fe=document.getElementById("dash-kpi-occ-value"),we=document.getElementById("dash-kpi-occ-sub");me&&me.setAttribute("stroke-dasharray",`${_}, 100`),ye&&(ye.textContent=`${_}%`),fe&&(fe.textContent=`${z}/${C}`),we&&(we.textContent=`Occupied / Total \u2022 ${_}% full`);const ke=document.getElementById("dash-kpi-behavior-alerts"),Ee=document.getElementById("dash-kpi-alerts-sub"),$e=(F.expired||0)+(F.inactive||0);ke&&(ke.textContent=$e),Ee&&(Ee.textContent=`${F.expired||0} expired + ${F.inactive||0} inactive`),document.querySelectorAll(".stat-card-value").forEach(t=>{const n=t.textContent?.replace(/[₹,\s]/g,"").replace(/[^0-9.]/g,""),r=parseFloat(n);if(!isNaN(r)&&r>0&&!t.dataset.animated){t.dataset.animated="1";const v=t.textContent.startsWith("\u20B9")?"\u20B9":"",u=t.textContent.replace(/[₹0-9,.\s]/g,"").trim();let s=0;const d=r/30,g=setInterval(()=>{s=Math.min(s+d,r),t.textContent=v+Math.round(s).toLocaleString("en-IN")+(u?" "+u:""),s>=r&&clearInterval(g)},20)}});const Fe=document.getElementById("dash-present-today"),Ae=document.getElementById("dash-available-seats"),Ce=document.getElementById("dash-active-subs");Fe&&(Fe.textContent=`${N.stats?.totalPresent||N.stats?.totalCheckedIn||0} Students`),Ae&&(Ae.textContent=`${ae} Available`),Ce&&(Ce.textContent=`${F.active??0}`);const K=document.getElementById("dash-expiring-container");if(K&&(D.length===0?K.innerHTML=`
          <div class="p-4 text-center text-muted">
            <div style="font-size: 28px; margin-bottom: 4px;">\u{1F389}</div>
            <p class="small mb-0">No memberships expiring in the next 7 days!</p>
          </div>
        `:K.innerHTML=`
          <div class="d-flex flex-column divide-y">
            ${D.slice(0,6).map(t=>{const n=t.expiryDate?new Date(t.expiryDate):null,r=n&&!isNaN(n.getTime()),v=t.daysRemaining??(r?Math.ceil((n-new Date)/(1e3*60*60*24)):0),u=r?n.toLocaleDateString("en-IN"):"N/A",s=(t.phone||"").replace(/[^0-9]/g,""),d=encodeURIComponent(`Hi ${t.name}, friendly reminder from Study Library: Your desk membership expires on ${u}. Please renew to retain your seat!`),g=s?`https://api.whatsapp.com/send?phone=${s.length===10?"91"+s:s}&text=${d}`:"#";return`
                <div class="p-3 d-flex justify-content-between align-items-center" style="border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.06));">
                  <div>
                    <div style="font-weight: 600; font-size: 14px;">${A(t.name)}</div>
                    <div class="text-xs text-muted">Seat: ${A(t.seat?.seatNumber||t.seatNumber||"N/A")} | Exp: ${u}</div>
                  </div>
                  <div class="d-flex align-items-center gap-2">
                    <span class="badge ${v<=2?"badge-danger":"badge-warning"}" style="font-size: 11px;">
                      ${v<=0?"Expires Today":`${v}d left`}
                    </span>
                    ${s?`
                      <a href="${g}" target="_blank" class="btn btn-sm btn-success" style="padding: 4px 8px; font-size: 12px; background: #25D366; border-color: #25D366;" title="Send WhatsApp Reminder">
                        \u{1F4F2}
                      </a>
                    `:""}
                  </div>
                </div>
              `}).join("")}
          </div>
        `),document.getElementById("chart-revenue-trend-canvas")){const t=Array.isArray(S.trend)&&S.trend.length>0?S.trend.slice(-14):[{date:"Day 1",amount:3200},{date:"Day 3",amount:4800},{date:"Day 6",amount:2900},{date:"Day 9",amount:6200},{date:"Day 12",amount:5100},{date:"Day 15",amount:7400},{date:"Today",amount:T.todayRevenue||4500}],n=t.map(s=>{if(!s.date)return"";if(s.date.includes("-")){const d=s.date.split("-");return`${d[2]}/${d[1]}`}return s.date}),r=t.map(s=>s.amount||0),v=r.reduce((s,d)=>s+d,0),u=document.getElementById("dash-trend-total");u&&(u.textContent=L(v)),H.lineChart("chart-revenue-trend-canvas",{labels:n,data:r,color:"#0984e3",fill:!0,title:"Daily Collection (\u20B9)"})}if(document.getElementById("chart-shift-occupancy-canvas")){const t=Array.isArray(P.shiftStats)?P.shiftStats:Array.isArray(P)?P:[];let n=[],r=[];const v=["#6c5ce7","#00b894","#0984e3","#fdcb6e","#e17055","#a29bfe"];t.length>0?(n=t.map(g=>g.name||g.code),r=t.map(g=>g.enrolledStudents??g.enrolled??0)):(n=["Morning","Evening","Full Day","Night"],r=[8,12,16,4]);const u=r.reduce((g,E)=>g+E,0),s=document.getElementById("dash-shift-total");s&&(s.textContent=`${u} Students`),H.doughnutChart("chart-shift-occupancy-canvas",{labels:u>0?n:["No Students Enrolled"],data:u>0?r:[1],colors:u>0?v:["rgba(148, 163, 184, 0.2)"],title:"Shift Distribution"});const d=document.getElementById("chart-shift-legend");d&&(u>0?d.innerHTML=n.map((g,E)=>`
            <span style="display: inline-flex; align-items: center; gap: 4px;">
              <span style="width: 10px; height: 10px; border-radius: 50%; background: ${v[E%v.length]}; display: inline-block;"></span>
              ${A(g)}: <strong>${r[E]}</strong>
            </span>
          `).join(""):d.innerHTML='<span class="text-muted small">No students assigned to shifts yet</span>')}if(document.getElementById("chart-exam-stats-canvas")){const t={"UPSC / IAS":0,"SSC / CGL":0,"Banking / IBPS":0,"State PSC":0,"NEET / JEE":0,"Defence / NDA":0,Other:0};Array.isArray(J)&&J.length>0&&J.forEach(d=>{Array.isArray(d.targetExams)&&d.targetExams.length>0&&d.targetExams.forEach(g=>{const E=String(g).trim();if(t[E]!==void 0)t[E]++;else{let Be=!1;for(const Q of Object.keys(t))if(E.toLowerCase().includes(Q.toLowerCase())||Q.toLowerCase().includes(E.toLowerCase())){t[Q]++,Be=!0;break}Be||t.Other++}})});const n=Object.values(t).reduce((d,g)=>d+g,0),r=Object.keys(t).filter(d=>t[d]>0),v=r.map(d=>t[d]),u=["#6c5ce7","#00cec9","#fdcb6e","#e84393","#0984e3","#00b894","#636e72"];H.doughnutChart("chart-exam-stats-canvas",{labels:n>0?r:["No Exam Records"],data:n>0?v:[1],colors:n>0?u:["rgba(148, 163, 184, 0.2)"],title:"Exam Preparation"});const s=document.getElementById("chart-exam-legend");s&&(n>0?s.innerHTML=r.map((d,g)=>`
            <span style="display: inline-flex; align-items: center; gap: 4px;">
              <span style="width: 10px; height: 10px; border-radius: 50%; background: ${u[g%u.length]}; display: inline-block;"></span>
              ${A(d)}: <strong>${v[g]}</strong>
            </span>
          `).join(""):s.innerHTML='<span class="text-muted small">No student exam targets registered yet</span>')}if(document.getElementById("dashboard-chart")){const t=[0,0,0,0,0,0,0];H.barChart("dashboard-chart",{labels:["Mon","Tue","Wed","Thu","Fri","Sat","Sun"],data:t,title:"Weekly Attendance Pulse",color:"#6c5ce7"})}typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1F680}",label:"Dashboard Quick Actions",color:"var(--color-primary, #6c5ce7)",actions:[{icon:"\u{1F393}",label:"New Admission",onClick:()=>{window.location.hash="#/students"}},{icon:"\u{1F4B3}",label:"Collect Fee",onClick:()=>{window.location.hash="#/payments"}},{icon:"\u23F1\uFE0F",label:"Live Attendance",onClick:()=>{window.location.hash="#/attendance"}},{icon:"\u{1FA91}",label:"Seating Hub",onClick:()=>{window.location.hash="#/seats"}}]})}catch(e){console.error("Error fetching dashboard statistics:",e)}}export{W as render};
