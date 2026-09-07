import"../app.js";import"../i18n.js";import{Modal as j,Toast as h,Loading as Y,escapeHTML as y}from"../ui.js";import{ChartEngine as _}from"../charts.js";import E from"../api.js";const k=i=>new Intl.NumberFormat("en-IN",{style:"currency",currency:"INR",maximumFractionDigits:0}).format(i||0),L=i=>i?new Date(i).toLocaleDateString("en-IN",{day:"2-digit",month:"short",year:"numeric"}):"-";async function it(i){i||(i=document.getElementById("page-content")||document.createElement("div"));let A="collections",R="all",J="this_month",P=G("this_month"),f="",O=null,B=null,q=null,I=null;function G(e){const o=new Date;o.setHours(23,59,59,999);const t=new Date(o);return e==="today"?t.setHours(0,0,0,0):e==="last_7_days"?(t.setDate(o.getDate()-6),t.setHours(0,0,0,0)):e==="this_month"?(t.setDate(1),t.setHours(0,0,0,0)):e==="last_30_days"&&(t.setDate(o.getDate()-29),t.setHours(0,0,0,0)),{type:e,startDate:t.toISOString().split("T")[0],endDate:o.toISOString().split("T")[0]}}return i.innerHTML=`
    <div class="reports-container" style="display: flex; flex-direction: column; gap: var(--space-5);">
      
      <!-- Standard Module Header -->
      <div class="module-header">
        <div class="module-title-area">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h2>\u{1F4CA} Reports & Analytics</h2>
            <span class="badge badge-primary" style="font-size: 0.75rem; text-transform: uppercase;">Real-time</span>
          </div>
          <p>Deep-dive financial collections, member occupancy, peak study hours, and expiry forecasting.</p>
        </div>

        <!-- Controls: Date Range Selector, Export Dropdown, Print -->
        <div class="module-actions">
          <!-- Date Range Selector -->
          <div class="date-range-wrapper d-flex align-items-center gap-1" style="background: var(--color-surface); padding: 4px; border: 1px solid var(--color-border); border-radius: var(--radius-md); box-shadow: var(--shadow-xs);">
            <select id="rangeSelect" class="form-select form-control" style="border: none; background: transparent; font-size: 0.85rem; font-weight: 600; padding: 6px 12px; cursor: pointer; color: var(--color-text-primary); outline: none;">
              <option value="today">Today</option>
              <option value="last_7_days">Last 7 Days</option>
              <option value="this_month" selected>This Month</option>
              <option value="last_30_days">Last 30 Days</option>
              <option value="custom">Custom Range</option>
            </select>
            
            <div id="customDateInputs" style="display: none; align-items: center; gap: 6px; padding-left: 6px; border-left: 1px solid var(--color-border);">
              <input type="date" id="customStartDate" class="form-control" style="padding: 4px 8px; font-size: 0.8rem; height: 32px; border: 1px solid var(--color-border); border-radius: var(--radius-sm);" />
              <span style="color: var(--color-text-muted); font-size: 0.8rem;">to</span>
              <input type="date" id="customEndDate" class="form-control" style="padding: 4px 8px; font-size: 0.8rem; height: 32px; border: 1px solid var(--color-border); border-radius: var(--radius-sm);" />
              <button id="btnApplyCustomDate" class="btn btn-sm btn-primary" style="padding: 4px 10px; font-size: 0.8rem; height: 32px;">Apply</button>
            </div>
          </div>

          <!-- Export Data Dropdown -->
          <div class="dropdown" id="exportDropdown">
            <button class="btn btn-secondary d-flex align-items-center gap-2" id="exportMenuBtn" style="font-size: 0.85rem; padding: 8px 14px; font-weight: 600;">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
              <span>Export Data</span>
              <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg>
            </button>
            <div class="dropdown-menu" id="exportMenu" style="right: 0; left: auto; min-width: 240px;">
              <a href="#" class="dropdown-item" id="exportPdfExecutiveSummary" style="font-weight: 700; color: var(--color-primary);">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
                <span>\u{1F4C4} Executive Summary (PDF Print)</span>
              </a>
              <div class="dropdown-divider" style="border-top: 1px solid var(--color-border); margin: 4px 0;"></div>
              <a href="#" class="dropdown-item" id="exportStudentsCsv">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>
                <span>Students List (.CSV)</span>
              </a>
              <a href="#" class="dropdown-item" id="exportPaymentsCsv">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>
                <span>Financial Ledger (.CSV)</span>
              </a>
              <a href="#" class="dropdown-item" id="exportAttendanceCsv">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>
                <span>Attendance Log (.CSV)</span>
              </a>
            </div>
          </div>

          <!-- Print Report -->
          <button class="btn btn-outline-secondary d-flex align-items-center gap-2" id="btnPrintReport" style="font-size: 0.85rem; padding: 8px 14px; font-weight: 600;">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg>
            <span>Print Report</span>
          </button>
        </div>
      </div>

      <!-- Contextual Guidance Tip Banner -->
      <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
        <span style="font-size: 1.1rem;">\u{1F4A1}</span>
        <span><strong>Tip:</strong> Reports update automatically in real-time. Export clean Excel spreadsheets or PDF statements with 1 click.</span>
      </div>

      <!-- Top Standard KPI Metrics Grid -->
      <div class="kpi-grid">
        
        <!-- Total Revenue Card -->
        <div class="kpi-card kpi-primary">
          <div class="kpi-label">Revenue in Period <span>\u{1F4B3}</span></div>
          <div class="kpi-value" id="metricPeriodRevenue" style="color: var(--color-primary);">\u20B90</div>
          <div class="kpi-subtext" id="metricRevenueTransactions">0 transactions</div>
        </div>

        <!-- Avg Daily Check-ins Card -->
        <div class="kpi-card kpi-success">
          <div class="kpi-label">Avg Daily Check-ins <span>\u23F1\uFE0F</span></div>
          <div class="kpi-value text-success" id="metricAvgDailyCheckins">0</div>
          <div class="kpi-subtext" id="metricPeakHour">Peak: --</div>
        </div>

        <!-- Renewal Rate % Card -->
        <div class="kpi-card kpi-info">
          <div class="kpi-label">Renewal Rate <span>\u{1F4C8}</span></div>
          <div class="kpi-value" id="metricRenewalRate" style="color: var(--color-info);">0%</div>
          <div class="kpi-subtext" id="metricActiveStudents">0 active members</div>
        </div>

        <!-- Pending Dues Card -->
        <div class="kpi-card kpi-danger">
          <div class="kpi-label">Pending Dues <span>\u26A0\uFE0F</span></div>
          <div class="kpi-value text-danger" id="metricPendingDues">\u20B90</div>
          <div class="kpi-subtext" id="metricPendingCount">0 overdue accounts</div>
        </div>

      </div>

      <!-- Multi-Branch Comparative Analytics -->
      <div class="card mb-2" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2" style="border-bottom: 1px solid var(--color-divider);">
          <h3 style="margin: 0; font-size: 1rem; font-weight: 700; display: flex; align-items: center; gap: 8px;">
            <span>\u{1F3E2}</span> Multi-Branch Comparative Analytics & Occupancy P&L
          </h3>
          <span class="badge badge-primary" id="branchAnalyticsCount">0 Branches</span>
        </div>
        <div class="card-body p-3">
          <div id="multiBranchGrid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 1rem;">
            <div class="text-muted small text-center p-3">Loading branch analytics...</div>
          </div>
        </div>
      </div>

      <!-- Tally & GST Accounting Exports Card -->
      <div class="card mb-2" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2" style="border-bottom: 1px solid var(--color-divider);">
          <h3 style="margin: 0; font-size: 1rem; font-weight: 700; display: flex; align-items: center; gap: 8px;">
            <span>\u{1F4D1}</span> Tally & GST Accounting Exports
          </h3>
          <span class="badge badge-success" style="font-size: 0.75rem;">GSTR-1 & Tally Prime Ready</span>
        </div>
        <div class="card-body p-3">
          <p class="small text-muted mb-3" style="margin-bottom: 12px;">Export fee collections and operational expense ledgers formatted for Tally Prime XML import or download GSTR-1 & GSTR-3B B2C tax compliance summaries.</p>
          <div class="d-flex align-items-center gap-3 flex-wrap">
            <button class="btn btn-primary d-flex align-items-center gap-2" id="btnDownloadTallyXml" style="font-weight: 600;">
              <span>\u{1F4E5}</span> Download Tally XML Import File
            </button>
            <button class="btn btn-secondary d-flex align-items-center gap-2" id="btnDownloadGstReport" style="font-weight: 600;">
              <span>\u{1F4CA}</span> Download GST Sales Summary Report (CSV)
            </button>
          </div>
        </div>
      </div>

      <!-- Charts Section -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
        
        <!-- Revenue Trend Chart -->
        <div class="card" style="background: var(--color-surface);">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h3 style="margin: 0; font-size: 1rem; font-weight: 600; display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4C8}</span> Revenue Trend (Collections)
            </h3>
            <span class="badge badge-primary" id="trendChartTotal">\u20B90</span>
          </div>
          <div class="card-body" style="padding: 16px; position: relative;">
            <canvas id="revenueTrendChart" style="width: 100%; height: 220px; max-height: 220px; display: block;"></canvas>
          </div>
        </div>

        <!-- Payment Method Distribution Chart -->
        <div class="card" style="background: var(--color-surface);">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h3 style="margin: 0; font-size: 1rem; font-weight: 600; display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4B3}</span> Payment Methods Breakdown
            </h3>
            <span class="badge badge-ghost" id="methodBreakdownTotal">Total \u20B90</span>
          </div>
          <div class="card-body" style="padding: 16px; display: flex; flex-direction: column; align-items: center;">
            <canvas id="paymentMethodChart" style="width: min(180px, 100%); height: min(180px, 50vw); max-height: 180px; margin-bottom: 12px;"></canvas>
            <div id="paymentMethodLegend" style="display: flex; flex-wrap: wrap; justify-content: center; gap: 10px; width: 100%; font-size: 0.8rem;"></div>
          </div>
        </div>

        <!-- Hourly Attendance Distribution Chart -->
        <div class="card" style="background: var(--color-surface);">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h3 style="margin: 0; font-size: 1rem; font-weight: 600; display: flex; align-items: center; gap: 8px;">
              <span>\u23F1\uFE0F</span> Peak Study & Occupancy Hours
            </h3>
            <span class="badge badge-success" id="hourlyChartPeak">06:00 - 23:00</span>
          </div>
          <div class="card-body" style="padding: 16px; position: relative;">
            <canvas id="hourlyAttendanceChart" style="width: 100%; height: 220px; max-height: 220px; display: block;"></canvas>
          </div>
        </div>

      </div>

      <!-- Tabbed Report Tables Card -->
      <div class="card" style="background: var(--color-surface);">
        <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-3" style="border-bottom: none; padding-bottom: 0;">
          
          <!-- Tab Navigation -->
          <div class="tabs mb-0" style="border-bottom: none; margin-bottom: 0;">
            <button class="tab-item active" data-tab="collections" style="font-size: 0.95rem; display: flex; align-items: center; gap: 6px;">
              <span>\u{1F4B0} Financial Collections</span>
              <span class="badge badge-ghost" id="tabCountCollections">0</span>
            </button>
            <button class="tab-item" data-tab="expiries" style="font-size: 0.95rem; display: flex; align-items: center; gap: 6px;">
              <span>\u26A0\uFE0F Upcoming Expiries</span>
              <span class="badge badge-warning" id="tabCountExpiries">0</span>
            </button>
            <button class="tab-item" data-tab="attendance" style="font-size: 0.95rem; display: flex; align-items: center; gap: 6px;">
              <span>\u{1F4CA} Attendance Analytics</span>
              <span class="badge badge-ghost" id="tabCountAttendance">0</span>
            </button>
          </div>

          <!-- Table Search & Filters -->
          <div class="d-flex align-items-center gap-2 flex-wrap">
            <div class="search-box" style="position: relative; min-width: 220px;">
              <input type="text" id="reportSearchInput" class="form-control" placeholder="Search in table..." style="padding: 6px 12px 6px 32px; font-size: 0.85rem; border-radius: var(--radius-md);" />
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" style="position: absolute; left: 10px; top: 50%; transform: translateY(-50%); color: var(--color-text-muted);"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
            </div>
          </div>

        </div>

        <div class="card-body p-0" style="border-top: 1px solid var(--color-divider); margin-top: 10px;">
          
          <!-- TAB 1: Financial Collections -->
          <div id="tabContentCollections" class="tab-content-panel">
            <div class="table-responsive">
              <table class="table data-table mb-0">
                <thead>
                  <tr>
                    <th>Receipt #</th>
                    <th>Date</th>
                    <th>Student Details</th>
                    <th>Membership Plan</th>
                    <th>Method</th>
                    <th style="text-align: right;">Amount Paid</th>
                    <th>Status</th>
                    <th style="text-align: center;">Action</th>
                  </tr>
                </thead>
                <tbody id="collectionsTableBody">
                  <tr><td colspan="8" class="text-center p-4 text-muted">Loading financial collections...</td></tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- TAB 2: Upcoming Expiries -->
          <div id="tabContentExpiries" class="tab-content-panel" style="display: none;">
            
            <!-- Expiry sub-filter pills -->
            <div class="d-flex align-items-center gap-2 p-3" style="background: var(--color-bg-secondary); border-bottom: 1px solid var(--color-divider); flex-wrap: wrap;">
              <span class="small text-muted" style="font-weight: 500;">Filter Expiry:</span>
              <button class="btn btn-sm btn-primary expiry-filter-btn" data-filter="all" style="padding: 3px 10px; font-size: 0.8rem;">All Active</button>
              <button class="btn btn-sm btn-outline-secondary expiry-filter-btn" data-filter="7" style="padding: 3px 10px; font-size: 0.8rem;">Next 7 Days (<span id="expCount7">0</span>)</button>
              <button class="btn btn-sm btn-outline-secondary expiry-filter-btn" data-filter="15" style="padding: 3px 10px; font-size: 0.8rem;">Next 15 Days (<span id="expCount15">0</span>)</button>
              <button class="btn btn-sm btn-outline-secondary expiry-filter-btn" data-filter="30" style="padding: 3px 10px; font-size: 0.8rem;">Next 30 Days (<span id="expCount30">0</span>)</button>
              <button class="btn btn-sm btn-outline-danger expiry-filter-btn" data-filter="expired" style="padding: 3px 10px; font-size: 0.8rem;">Already Expired (<span id="expCountExpired">0</span>)</button>
            </div>

            <div class="table-responsive">
              <table class="table data-table mb-0">
                <thead>
                  <tr>
                    <th>Student Name & ID</th>
                    <th>Phone / Contact</th>
                    <th>Current Plan</th>
                    <th>Assigned Seat</th>
                    <th>Expiry Date</th>
                    <th>Days Remaining</th>
                    <th style="text-align: center;">Action</th>
                  </tr>
                </thead>
                <tbody id="expiriesTableBody">
                  <tr><td colspan="7" class="text-center p-4 text-muted">Loading upcoming expiries...</td></tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- TAB 3: Attendance Analytics -->
          <div id="tabContentAttendance" class="tab-content-panel" style="display: none;">
            <div class="table-responsive">
              <table class="table data-table mb-0">
                <thead>
                  <tr>
                    <th>Rank</th>
                    <th>Student Name & ID</th>
                    <th>Phone</th>
                    <th style="text-align: center;">Days Present</th>
                    <th style="text-align: center;">Total Study Hours</th>
                    <th style="text-align: center;">Avg Hours / Day</th>
                    <th>Attendance Rate</th>
                  </tr>
                </thead>
                <tbody id="attendanceTableBody">
                  <tr><td colspan="7" class="text-center p-4 text-muted">Loading attendance analytics...</td></tr>
                </tbody>
              </table>
            </div>
          </div>

        </div>

        <!-- Card Footer with summary and export shortcut buttons -->
        <div class="card-footer d-flex justify-content-between align-items-center flex-wrap gap-3" style="padding: 12px 20px; background: var(--color-surface-hover);">
          <div class="small text-muted" id="tableSummaryFooter">
            Showing records for current period
          </div>
          <div class="d-flex align-items-center gap-2">
            <button class="btn btn-sm btn-outline-secondary" id="btnQuickStudentsCsv">
              \u{1F4E5} Students CSV
            </button>
            <button class="btn btn-sm btn-outline-secondary" id="btnQuickPaymentsCsv">
              \u{1F4B3} Payments CSV
            </button>
            <button class="btn btn-sm btn-outline-secondary" id="btnQuickAttendanceCsv">
              \u23F1\uFE0F Attendance CSV
            </button>
          </div>
        </div>

      </div>

    </div>
  `,K(),await M(),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1F4CA}",label:"Reports & Export Actions",color:"#6c5ce7",actions:[{icon:"\u{1F4E5}",label:"Tally XML Export",onClick:()=>{X()}},{icon:"\u{1F4D1}",label:"GST Sales Summary",onClick:()=>{Q()}},{icon:"\u{1F5A8}\uFE0F",label:"Print Analytics",onClick:()=>{window.print()}}]}),i;function K(){const e=i.querySelector("#rangeSelect"),o=i.querySelector("#customDateInputs"),t=i.querySelector("#customStartDate"),n=i.querySelector("#customEndDate"),a=i.querySelector("#btnApplyCustomDate");if(e){const m=new Date().toISOString().split("T")[0],g=new Date(new Date().getFullYear(),new Date().getMonth(),1).toISOString().split("T")[0];t&&(t.value=g),n&&(n.value=m),e.addEventListener("change",async ot=>{const U=ot.target.value;J=U,U==="custom"?o&&(o.style.display="inline-flex"):(o&&(o.style.display="none"),P=G(U),await M())})}a&&a.addEventListener("click",async()=>{if(!t?.value||!n?.value){h.error("Please select both Start Date and End Date");return}if(new Date(t.value)>new Date(n.value)){h.error("Start Date cannot be after End Date");return}P={type:"custom",startDate:t.value,endDate:n.value},await M()});const r=i.querySelector("#exportDropdown"),s=i.querySelector("#exportMenuBtn");s&&r&&(s.addEventListener("click",m=>{m.stopPropagation(),r.classList.toggle("active")}),window._repExportClickCleanup&&document.removeEventListener("click",window._repExportClickCleanup),window._repExportClickCleanup=m=>{r.contains(m.target)||r.classList.remove("active")},document.addEventListener("click",window._repExportClickCleanup));const l=i.querySelector("#exportPdfExecutiveSummary"),d=i.querySelector("#exportStudentsCsv"),c=i.querySelector("#exportPaymentsCsv"),u=i.querySelector("#exportAttendanceCsv"),p=i.querySelector("#exportJsonReport"),v=i.querySelector("#btnQuickStudentsCsv"),b=i.querySelector("#btnQuickPaymentsCsv"),C=i.querySelector("#btnQuickAttendanceCsv");l&&(l.onclick=m=>{m.preventDefault(),window.print()}),d&&(d.onclick=m=>{m.preventDefault(),T("students","csv")}),c&&(c.onclick=m=>{m.preventDefault(),T("payments","csv")}),u&&(u.onclick=m=>{m.preventDefault(),T("attendance","csv")}),p&&(p.onclick=m=>{m.preventDefault(),T("payments","json")}),v&&(v.onclick=()=>T("students","csv")),b&&(b.onclick=()=>T("payments","csv")),C&&(C.onclick=()=>T("attendance","csv"));const $=i.querySelector("#btnDownloadTallyXml"),x=i.querySelector("#btnDownloadGstReport");$&&($.onclick=()=>X()),x&&(x.onclick=()=>Q());const S=i.querySelector("#btnPrintReport")||i.querySelector("#btnPrintSummary");S&&S.addEventListener("click",()=>{window.print()});const w=i.querySelectorAll(".tabs .tab-item");w.forEach(m=>{m.addEventListener("click",()=>{if(w.forEach(g=>g.classList.remove("active")),m.classList.add("active"),A=m.dataset.tab,i.querySelectorAll(".tab-content-panel").forEach(g=>g.style.display="none"),A==="collections"){const g=i.querySelector("#tabContentCollections");g&&(g.style.display="block"),N()}else if(A==="expiries"){const g=i.querySelector("#tabContentExpiries");g&&(g.style.display="block"),z()}else if(A==="attendance"){const g=i.querySelector("#tabContentAttendance");g&&(g.style.display="block"),H()}})});const D=i.querySelectorAll(".expiry-filter-btn");D.forEach(m=>{m.addEventListener("click",()=>{D.forEach(g=>{g.className="btn btn-sm btn-outline-secondary expiry-filter-btn"}),m.dataset.filter==="expired"?m.className="btn btn-sm btn-danger expiry-filter-btn":m.className="btn btn-sm btn-primary expiry-filter-btn",R=m.dataset.filter,z()})});const F=i.querySelector("#reportSearchInput");F&&F.addEventListener("input",m=>{f=m.target.value.toLowerCase().trim(),A==="collections"?N():A==="expiries"?z():A==="attendance"&&H()})}async function M(){try{const{startDate:e,endDate:o}=P,t={startDate:e,endDate:o},[n,a,r,s,l]=await Promise.allSettled([E.get("/api/reports/overview",t),E.get("/api/reports/revenue",t),E.get("/api/reports/attendance",t),E.get("/api/reports/expiries",{days:30}),E.get("/api/branches")]);n.status==="fulfilled"&&n.value?.success&&(O=n.value.data,W(O)),l.status==="fulfilled"&&l.value?.success?V(l.value.data):V([]),a.status==="fulfilled"&&a.value?.success&&(B=a.value.data,tt(B),et(B),N()),r.status==="fulfilled"&&r.value?.success&&(q=r.value.data,at(q),H()),s.status==="fulfilled"&&s.value?.success&&(I=s.value.data,Z(I),z())}catch(e){console.error("Error loading reports analytics:",e),h.error("Failed to load reports data. Please check backend connection.")}}function V(e){const o=i.querySelector("#multiBranchGrid"),t=i.querySelector("#branchAnalyticsCount");if(o){if(!e||e.length===0){o.innerHTML='<div class="text-muted small text-center p-3">No active branch locations registered.</div>',t&&(t.textContent="0 Branches");return}t&&(t.textContent=`${e.length} ${e.length===1?"Branch":"Branches"}`),o.innerHTML=e.map(n=>{const a=n.occupancyPercent||0;let r="var(--color-success)";return a>85?r="var(--color-danger)":a>60&&(r="var(--color-primary)"),`
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 14px;">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
            <div>
              <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-text-primary);">${y(n.name)}</div>
              <div style="font-size: 0.78rem; color: var(--color-text-secondary);">${y(n.city||"")} ${n.isMainBranch?'\u2022 <span class="badge badge-primary" style="font-size: 0.65rem;">MAIN</span>':""}</div>
            </div>
            <span class="badge ${n.isActive?"badge-success":"badge-secondary"}" style="font-size: 0.7rem;">${n.isActive?"Active":"Inactive"}</span>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 8px; font-size: 0.82rem; margin-bottom: 10px;">
            <div><span class="text-muted d-block small">Occupancy</span><strong style="color: var(--color-primary);">${n.occupiedSeats||0} / ${n.effectiveCapacity||n.totalSeats||50}</strong></div>
            <div><span class="text-muted d-block small">Active Members</span><strong>${n.activeStudents||0}</strong></div>
          </div>

          <div style="margin-top: 6px;">
            <div style="display: flex; justify-content: space-between; font-size: 0.75rem; margin-bottom: 4px; color: var(--color-text-muted);">
              <span>Occupancy Rate</span>
              <strong>${a}%</strong>
            </div>
            <div class="progress" style="height: 6px;">
              <div class="progress-bar" style="width: ${a}%; background: ${r};"></div>
            </div>
          </div>
        </div>
      `}).join("")}}function W(e){if(!e)return;const o=i.querySelector("#metricPeriodRevenue"),t=i.querySelector("#metricRevenueTransactions"),n=i.querySelector("#metricAvgDailyCheckins"),a=i.querySelector("#metricPeakHour"),r=i.querySelector("#metricRenewalRate"),s=i.querySelector("#metricActiveStudents"),l=i.querySelector("#metricPendingDues"),d=i.querySelector("#metricPendingCount");o&&(o.textContent=k(e.periodRevenue)),t&&(t.textContent=`${e.periodTransactions||0} collections (${L(e.period?.startDate)} - ${L(e.period?.endDate)})`),r&&(r.textContent=`${e.renewalRate||0}%`),s&&(s.textContent=`${e.totalActiveStudents||0} of ${e.totalStudents||0} active members`),l&&(l.textContent=k(e.pendingPaymentsAmount)),d&&(d.textContent=`${e.pendingDuesCount||0} overdue memberships`)}function Z(e){if(!e)return;const{counts:o}=e,t=i.querySelector("#expCount7"),n=i.querySelector("#expCount15"),a=i.querySelector("#expCount30"),r=i.querySelector("#expCountExpired"),s=i.querySelector("#tabCountExpiries");t&&(t.textContent=o.count7||0),n&&(n.textContent=o.count15||0),a&&(a.textContent=o.count30||0),r&&(r.textContent=o.countExpired||0),s&&(s.textContent=o.total||0)}function tt(e){if(!e||!e.trend)return;const o=e.summary?.totalRevenue||0,t=i.querySelector("#trendChartTotal");t&&(t.textContent=`Total: ${k(o)}`);const n=e.trend.map(r=>{const s=r.date.split("-");return s.length===3?`${s[2]}/${s[1]}`:r.date}),a=e.trend.map(r=>r.amount);a.length===0&&(n.push("No Data"),a.push(0));try{_.areaChart("revenueTrendChart",{labels:n.length>15?n.filter((r,s)=>s%Math.ceil(n.length/10)===0):n,data:a,color:"#6c5ce7",title:"Daily Collections"})}catch(r){console.warn("Revenue chart render issue:",r)}}function et(e){if(!e||!e.byMethod)return;const{cash:o=0,upi:t=0,bank_transfer:n=0,card:a=0,other:r=0}=e.byMethod,s=o+t+n+a+r,l=i.querySelector("#methodBreakdownTotal");l&&(l.textContent=`Total ${k(s)}`);const d=["UPI","Cash","Bank Transfer","Card","Other"],c=[t,o,n,a,r],u=["#6c5ce7","#00b894","#0984e3","#fdcb6e","#a29bfe"];try{_.doughnutChart("paymentMethodChart",{labels:d,data:s>0?c:[1],colors:s>0?u:["#333"],title:"Payment Methods"})}catch(v){console.warn("Payment method chart issue:",v)}const p=i.querySelector("#paymentMethodLegend");p&&(p.innerHTML=d.map((v,b)=>{const C=c[b],$=s>0?Math.round(C/s*100):0;return`
          <div style="display: flex; align-items: center; gap: 6px;">
            <span style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; background: ${u[b]};"></span>
            <span style="color: var(--color-text-secondary);">${v}:</span>
            <strong style="color: var(--color-text-primary);">${k(C)} (${$}%)</strong>
          </div>
        `}).join(""))}function at(e){if(!e||!e.hourlyDistribution)return;const o=e.hourlyDistribution,t=e.stats,n=i.querySelector("#metricAvgDailyCheckins"),a=i.querySelector("#metricPeakHour"),r=i.querySelector("#hourlyChartPeak");n&&(n.textContent=`${t?.avgDailyCheckIns||0} / day`),a&&(a.textContent=`Peak: ${t?.peakHour||"N/A"}`),r&&(r.textContent=`Peak: ${t?.peakHourData?.displayLabel||"N/A"}`);const s=o.filter(c=>c.hour>=6&&c.hour<=23),l=s.map(c=>c.displayLabel),d=s.map(c=>c.count);try{_.barChart("hourlyAttendanceChart",{labels:l,data:d,color:"#00b894",title:"Occupancy Distribution"})}catch(c){console.warn("Attendance chart issue:",c)}}function N(){const e=i.querySelector("#collectionsTableBody"),o=i.querySelector("#tabCountCollections");if(!e)return;const t=B?.collections||[];let n=t;if(f&&(n=n.filter(a=>{const r=a.student?.name||"",s=a.student?.phone||"",l=a.student?.studentId||"",d=a.receiptNumber||"",c=a.paymentMethod||"";return r.toLowerCase().includes(f)||s.toLowerCase().includes(f)||l.toLowerCase().includes(f)||d.toLowerCase().includes(f)||c.toLowerCase().includes(f)})),o&&(o.textContent=t.length),n.length===0){e.innerHTML=`
        <tr>
          <td colspan="8" class="text-center p-4 text-muted">
            <div style="font-size: 1.2rem; margin-bottom: 4px;">\u{1F4B8}</div>
            No financial collection records found in this range.
          </td>
        </tr>
      `;return}e.innerHTML=n.map(a=>{const r=a.receiptNumber||"N/A",s=a.student?.name||"Unknown Student",l=a.student?.studentId||"",d=a.student?.phone||"",c=a.plan?.name||"Custom / Direct Plan",u=k(a.finalAmount||a.amount),p=(a.paymentMethod||"cash").toUpperCase(),v=a.status||"paid",b=L(a.paymentDate);let C="badge-primary";return p==="UPI"?C="badge-primary":p==="CASH"?C="badge-success":p==="CARD"?C="badge-warning":p==="BANK_TRANSFER"&&(C="badge-info"),`
        <tr>
          <td>
            <a href="#" class="view-receipt-btn" data-id="${a._id}" style="font-family: monospace; font-weight: 700; color: var(--color-primary); text-decoration: none;">
              ${y(r)}
            </a>
          </td>
          <td style="white-space: nowrap; color: var(--color-text-secondary); font-size: 0.85rem;">
            ${b}
          </td>
          <td>
            <div style="font-weight: 600; color: var(--color-text-primary);">${y(s)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${y(l)} ${d?`\u2022 ${y(d)}`:""}</div>
          </td>
          <td>
            <span class="badge badge-ghost" style="font-weight: 500;">${y(c)}</span>
          </td>
          <td>
            <span class="badge ${C}" style="font-size: 0.75rem;">${y(p)}</span>
          </td>
          <td style="text-align: right;">
            <strong style="font-size: 1rem; color: var(--color-text-primary);">${u}</strong>
          </td>
          <td>
            <span class="badge ${v==="paid"?"badge-success":"badge-danger"}" style="text-transform: capitalize;">
              ${y(v)}
            </span>
          </td>
          <td style="text-align: center;">
            <button class="btn btn-sm btn-outline-secondary view-receipt-btn" data-id="${a._id}" style="padding: 4px 8px; font-size: 0.8rem;" title="View Receipt">
              \u{1F9FE} Receipt
            </button>
          </td>
        </tr>
      `}).join(""),e.querySelectorAll(".view-receipt-btn").forEach(a=>{a.addEventListener("click",r=>{r.preventDefault(),nt(a.dataset.id)})})}function z(){const e=i.querySelector("#expiriesTableBody");if(!e)return;let o=I?.students||[];if(R==="7"?o=o.filter(t=>t.expiryCategory==="next7Days"):R==="15"?o=o.filter(t=>t.expiryCategory==="next15Days"):R==="30"?o=o.filter(t=>t.expiryCategory==="next30Days"):R==="expired"&&(o=o.filter(t=>t.expiryCategory==="expired")),f&&(o=o.filter(t=>{const n=t.name||"",a=t.studentId||"",r=t.phone||"",s=t.plan?.name||"";return n.toLowerCase().includes(f)||a.toLowerCase().includes(f)||r.toLowerCase().includes(f)||s.toLowerCase().includes(f)})),o.length===0){e.innerHTML=`
        <tr>
          <td colspan="7" class="text-center p-4 text-muted">
            <div style="font-size: 1.2rem; margin-bottom: 4px;">\u{1F389}</div>
            No students matching the selected expiry criteria.
          </td>
        </tr>
      `;return}e.innerHTML=o.map(t=>{const n=t.daysRemaining;let a="",r="badge-info";n<0?(a=`Expired ${Math.abs(n)}d ago`,r="badge-danger"):n===0?(a="Expires Today",r="badge-danger"):n===1?(a="1 day remaining",r="badge-danger"):n<=7?(a=`${n} days remaining`,r="badge-danger"):n<=15?(a=`${n} days remaining`,r="badge-warning"):(a=`${n} days remaining`,r="badge-info");const s=t.plan?.name||"Standard Plan",l=t.plan?.price?`\u20B9${t.plan.price}`:"-",d=t.seat?.seatNumber?`Seat #${t.seat.seatNumber}`:"Unassigned";return`
        <tr>
          <td>
            <div style="font-weight: 600; color: var(--color-text-primary);">${y(t.name)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${y(t.studentId||"")}</div>
          </td>
          <td>
            <div style="color: var(--color-text-primary); font-size: 0.88rem;">${y(t.phone||"-")}</div>
            ${t.email?`<div class="small text-muted" style="font-size: 0.75rem;">${y(t.email)}</div>`:""}
          </td>
          <td>
            <div style="font-weight: 500;">${y(s)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${l}</div>
          </td>
          <td>
            <span class="badge badge-ghost">${y(d)}</span>
          </td>
          <td style="font-weight: 500; color: var(--color-text-primary);">
            ${L(t.expiryDate)}
          </td>
          <td>
            <span class="badge ${r}" style="font-weight: 600;">
              ${y(a)}
            </span>
          </td>
          <td style="text-align: center;">
            <button class="btn btn-sm btn-success btn-collect-fee-action" data-studentid="${t._id}" data-name="${y(t.name)}" data-plan="${t.plan?._id||""}" style="padding: 4px 10px; font-size: 0.8rem; display: inline-flex; align-items: center; gap: 4px;">
              <span>\u{1F4B0}</span> Collect Fee
            </button>
          </td>
        </tr>
      `}).join(""),e.querySelectorAll(".btn-collect-fee-action").forEach(t=>{t.addEventListener("click",()=>{rt(t.dataset.studentid,t.dataset.name,t.dataset.plan)})})}function H(){const e=i.querySelector("#attendanceTableBody"),o=i.querySelector("#tabCountAttendance");if(!e)return;const t=q?.studentAnalytics||[];let n=t;if(f&&(n=n.filter(a=>{const r=a.student?.name||"",s=a.student?.studentId||"",l=a.student?.phone||"";return r.toLowerCase().includes(f)||s.toLowerCase().includes(f)||l.toLowerCase().includes(f)})),o&&(o.textContent=t.length),n.length===0){e.innerHTML=`
        <tr>
          <td colspan="7" class="text-center p-4 text-muted">
            <div style="font-size: 1.2rem; margin-bottom: 4px;">\u23F1\uFE0F</div>
            No student attendance logs found in this date range.
          </td>
        </tr>
      `;return}e.innerHTML=n.map((a,r)=>{const s=a.student?.name||"Unknown Student",l=a.student?.studentId||"",d=a.student?.phone||"-",c=a.daysPresent||0,u=a.totalHours||0,p=a.avgHours||0,v=a.attendanceRate||0;let b="var(--color-success)";return v<50?b="var(--color-danger)":v<75&&(b="var(--color-warning)"),`
        <tr>
          <td style="font-weight: 700; color: var(--color-text-muted); width: 50px;">
            #${r+1}
          </td>
          <td>
            <div style="font-weight: 600; color: var(--color-text-primary);">${y(s)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${y(l)}</div>
          </td>
          <td>
            <div style="color: var(--color-text-secondary); font-size: 0.85rem;">${y(d)}</div>
          </td>
          <td style="text-align: center;">
            <strong style="color: var(--color-primary); font-size: 1rem;">${c}</strong>
            <span class="text-muted small"> days</span>
          </td>
          <td style="text-align: center;">
            <strong style="color: var(--color-text-primary);">${u}</strong>
            <span class="text-muted small"> hrs</span>
          </td>
          <td style="text-align: center;">
            <span class="badge badge-ghost" style="font-size: 0.85rem;">${p} hrs/day</span>
          </td>
          <td style="min-width: 140px;">
            <div class="d-flex align-items-center gap-2">
              <div class="progress" style="height: 6px; flex: 1;">
                <div class="progress-bar" style="width: ${v}%; background: ${b};"></div>
              </div>
              <span style="font-weight: 600; font-size: 0.8rem; color: ${b}; min-width: 35px; text-align: right;">${v}%</span>
            </div>
          </td>
        </tr>
      `}).join("")}async function T(e,o="csv"){try{h.info(`Generating ${e.toUpperCase()} ${o.toUpperCase()} export...`);const t=localStorage.getItem("sl_token"),{startDate:n,endDate:a}=P,r=new URLSearchParams;r.set("format",o),n&&r.set("startDate",n),a&&r.set("endDate",a);const s=`/api/reports/export/${e}?${r.toString()}`,l=await fetch(s,{headers:{...t?{Authorization:`Bearer ${t}`}:{}}});if(!l.ok)throw new Error(`Failed to download report (${l.status})`);if(o==="json"){const d=await l.json(),c=new Blob([JSON.stringify(d,null,2)],{type:"application/json"}),u=URL.createObjectURL(c),p=document.createElement("a");p.href=u,p.download=`${e}-report-${new Date().toISOString().split("T")[0]}.json`,document.body.appendChild(p),p.click(),p.remove(),URL.revokeObjectURL(u)}else{const d=await l.blob(),c=URL.createObjectURL(d),u=document.createElement("a");u.href=c;const p=l.headers.get("Content-Disposition");let v=`${e}-report-${new Date().toISOString().split("T")[0]}.csv`;if(p&&p.includes("filename=")){const b=p.match(/filename="?([^"]+)"?/);b&&b[1]&&(v=b[1])}u.download=v,document.body.appendChild(u),u.click(),u.remove(),URL.revokeObjectURL(c)}h.success(`${e.toUpperCase()} report exported successfully!`)}catch(t){console.error("Download error:",t),h.error(`Export failed: ${t.message||"Error occurred"}`)}}async function X(){try{h.info("Generating Tally Prime XML import file...");const e=localStorage.getItem("sl_token"),{startDate:o,endDate:t}=P,n=new URLSearchParams;o&&n.set("startDate",o),t&&n.set("endDate",t);const a=`/api/reports/tally-xml?${n.toString()}`,r=await fetch(a,{headers:{...e?{Authorization:`Bearer ${e}`}:{}}});if(!r.ok)throw new Error(`Failed to download Tally XML (${r.status})`);const s=await r.blob(),l=URL.createObjectURL(s),d=document.createElement("a");d.href=l;const c=r.headers.get("Content-Disposition");let u=`tally-import-${new Date().toISOString().split("T")[0]}.xml`;if(c&&c.includes("filename=")){const p=c.match(/filename="?([^"]+)"?/);p&&p[1]&&(u=p[1])}d.download=u,document.body.appendChild(d),d.click(),d.remove(),URL.revokeObjectURL(l),h.success("Tally Prime XML import file downloaded successfully!")}catch(e){console.error("Tally XML download error:",e),h.error(`Tally export failed: ${e.message||"Error occurred"}`)}}async function Q(){try{h.info("Generating GST Sales Summary Report (CSV)...");const e=localStorage.getItem("sl_token"),{startDate:o,endDate:t}=P,n=new URLSearchParams;n.set("format","csv"),o&&n.set("startDate",o),t&&n.set("endDate",t);const a=`/api/reports/gst-report?${n.toString()}`,r=await fetch(a,{headers:{...e?{Authorization:`Bearer ${e}`}:{}}});if(!r.ok)throw new Error(`Failed to download GST Report (${r.status})`);const s=await r.blob(),l=URL.createObjectURL(s),d=document.createElement("a");d.href=l;const c=r.headers.get("Content-Disposition");let u=`gst-b2c-sales-summary-${new Date().toISOString().split("T")[0]}.csv`;if(c&&c.includes("filename=")){const p=c.match(/filename="?([^"]+)"?/);p&&p[1]&&(u=p[1])}d.download=u,document.body.appendChild(d),d.click(),d.remove(),URL.revokeObjectURL(l),h.success("GST Sales Summary Report downloaded successfully!")}catch(e){console.error("GST Report download error:",e),h.error(`GST export failed: ${e.message||"Error occurred"}`)}}async function nt(e){try{const o=await E.get(`/api/payments/${e}/receipt`);if(!o.success||!o.data){h.error("Receipt not found");return}const t=o.data,n=`
        <div id="printableReceiptArea" style="padding: 10px; font-family: var(--font-family);">
          <div style="border: 2px dashed var(--color-border); border-radius: var(--radius-md); padding: 20px; background: var(--color-surface);">
            
            <!-- Receipt Header -->
            <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 1px solid var(--color-divider); padding-bottom: 16px; margin-bottom: 16px;">
              <div>
                <h3 style="margin: 0; font-size: 1.3rem; font-weight: 700; color: var(--color-primary);">${y(t.businessName||"Reading Room & Study Library")}</h3>
                <div class="text-muted small" style="margin-top: 4px;">Official Payment Receipt</div>
              </div>
              <div style="text-align: right;">
                <div style="font-family: monospace; font-weight: 700; font-size: 1rem; color: var(--color-text-primary);">${y(t.receiptNumber||"N/A")}</div>
                <div class="text-muted small">${L(t.date)}</div>
              </div>
            </div>

            <!-- Student Info -->
            <div style="background: var(--color-bg-secondary); border-radius: var(--radius-sm); padding: 12px; margin-bottom: 16px;">
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 8px;">
                <div>
                  <span class="text-muted small">Student Name:</span>
                  <div style="font-weight: 600; color: var(--color-text-primary);">${y(t.student?.name||"Unknown")}</div>
                </div>
                <div>
                  <span class="text-muted small">Student ID:</span>
                  <div style="font-weight: 600; color: var(--color-text-primary);">${y(t.student?.studentId||"-")}</div>
                </div>
                <div>
                  <span class="text-muted small">Phone:</span>
                  <div style="color: var(--color-text-primary);">${y(t.student?.phone||"-")}</div>
                </div>
                <div>
                  <span class="text-muted small">Plan Enrolled:</span>
                  <div style="color: var(--color-text-primary); font-weight: 500;">${y(t.plan?.name||"Custom Plan")}</div>
                </div>
              </div>
            </div>

            <!-- Financial Breakdown Table -->
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px; font-size: 0.9rem;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-secondary); text-align: left;">
                  <th style="padding: 8px 0;">Description</th>
                  <th style="padding: 8px 0; text-align: right;">Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td style="padding: 8px 0;">Base Membership Fee</td>
                  <td style="padding: 8px 0; text-align: right;">${k(t.paymentDetails?.amount)}</td>
                </tr>
                ${t.paymentDetails?.discount>0?`
                <tr style="color: var(--color-success);">
                  <td style="padding: 4px 0;">Discount Applied</td>
                  <td style="padding: 4px 0; text-align: right;">- ${k(t.paymentDetails.discount)}</td>
                </tr>`:""}
                ${t.paymentDetails?.lateFee>0?`
                <tr style="color: var(--color-danger);">
                  <td style="padding: 4px 0;">Late Fee</td>
                  <td style="padding: 4px 0; text-align: right;">+ ${k(t.paymentDetails.lateFee)}</td>
                </tr>`:""}
                <tr style="border-top: 2px solid var(--color-divider); font-weight: 700; font-size: 1.1rem; color: var(--color-text-primary);">
                  <td style="padding: 12px 0;">Total Paid</td>
                  <td style="padding: 12px 0; text-align: right; color: var(--color-success);">${k(t.paymentDetails?.finalAmount)}</td>
                </tr>
              </tbody>
            </table>

            <!-- Payment Metadata -->
            <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.8rem; color: var(--color-text-secondary); border-top: 1px solid var(--color-divider); padding-top: 12px;">
              <div>
                <span>Payment Method: </span>
                <strong style="color: var(--color-text-primary); text-transform: uppercase;">${y(t.paymentDetails?.method||"CASH")}</strong>
                ${t.paymentDetails?.transactionId?`<span style="margin-left: 8px;">(Txn: ${y(t.paymentDetails.transactionId)})</span>`:""}
              </div>
              <div>
                <span>Collected By: </span>
                <strong style="color: var(--color-text-primary);">${y(t.collectedBy||"Admin")}</strong>
              </div>
            </div>

          </div>
        </div>
      `;j.show({title:"Fee Payment Receipt",content:n,size:"md",actions:`
          <button class="btn btn-secondary" onclick="window.Modal&&window.Modal.closeAll?window.Modal.closeAll():document.querySelector('dialog[open]')?.close()">Close</button>
          <button class="btn btn-primary d-flex align-items-center gap-2" id="btnPrintReceiptModal">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg>
            Print Receipt
          </button>
        `});const a=document.getElementById("btnPrintReceiptModal");a&&(a.onclick=()=>{const r=window.open("","_blank","width=750,height=800");if(!r){window.print();return}r.document.open(),r.document.write(`
            <!DOCTYPE html>
            <html lang="en">
            <head>
              <meta charset="UTF-8">
              <title>Receipt \u2014 ${t.receiptNumber||"Fee Receipt"}</title>
              <link rel="preconnect" href="https://fonts.googleapis.com">
              <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
              <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
              <style>
                @page { size: A4 portrait; margin: 8mm; }
                * { box-sizing: border-box; margin: 0; padding: 0; }
                body {
                  background: #ffffff !important;
                  color: #000000 !important;
                  font-family: 'Inter', Arial, Helvetica, sans-serif;
                  padding: 10px;
                  width: 100%;
                  max-width: 720px;
                  margin: 0 auto;
                  -webkit-font-smoothing: antialiased;
                }
                table { width: 100%; border-collapse: collapse; }
                @media print {
                  body { width: 100%; max-width: 720px; margin: 0 auto; padding: 0; }
                  * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
                }
              </style>
            </head>
            <body>
              ${n}
              <script>
                window.onload = function() {
                  setTimeout(function() {
                    window.print();
                  }, 300);
                };
              <\/script>
            </body>
            </html>
          `),r.document.close()})}catch(o){console.error("Error fetching receipt:",o),h.error("Failed to load receipt details")}}async function rt(e,o,t){try{let n=function(){const x=parseFloat(v.value)||0,S=parseFloat(b.value)||0,w=Math.max(0,x-S);C&&(C.textContent=k(w))};const a=await E.get("/api/plans"),r=a.success&&a.data?a.data:[];let s='<option value="">-- Select Subscription Plan --</option>',l=0,d=0;r.forEach(x=>{const S=x._id===t,w=Number(x.price)||0,D=Number(x.discount)||0,F=Math.round(w*(D/100)),m=Math.round(x.effectivePrice!==void 0?x.effectivePrice:w-F);S&&(l=w,d=F);const g=D>0?` [${D}% OFF, was \u20B9${w.toLocaleString("en-IN")}]`:"";s+=`<option value="${x._id}" data-price="${w}" data-discount="${F}" ${S?"selected":""}>${y(x.name)} - \u20B9${m.toLocaleString("en-IN")} (${x.duration} ${x.durationType})${g}</option>`});const c=`
        <form id="collectFeeForm" style="display: flex; flex-direction: column; gap: var(--space-4);">
          
          <div class="form-group mb-0">
            <label class="form-label">Student</label>
            <input type="text" class="form-control" value="${y(o)}" disabled style="background: var(--color-bg-secondary); font-weight: 600;" />
          </div>

          <div class="form-group mb-0">
            <label class="form-label">Membership Plan *</label>
            <select id="modalPlanSelect" class="form-select form-control" required>
              ${s}
            </select>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: var(--space-3);">
            <div class="form-group mb-0">
              <label class="form-label">Amount (\u20B9) *</label>
              <input type="number" id="modalAmount" class="form-control" value="${l}" required min="0" />
            </div>

            <div class="form-group mb-0">
              <label class="form-label">Discount (\u20B9)</label>
              <input type="number" id="modalDiscount" class="form-control" value="${d}" min="0" />
            </div>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: var(--space-3);">
            <div class="form-group mb-0">
              <label class="form-label">Payment Method</label>
              <select id="modalMethod" class="form-select form-control">
                <option value="cash">\u{1F4B5} Cash</option>
                <option value="upi" selected>\u26A1 UPI (Instant)</option>
                <option value="bank_transfer">\u{1F3DB}\uFE0F Bank Transfer / NEFT</option>
                <option value="card">\u{1F4B3} Debit / Credit Card</option>
                <option value="desk">\u{1F4B5} Pay Later at Front Desk</option>
                <option value="netbanking">\u{1F3E6} NetBanking / Online Transfer</option>
              </select>
            </div>

            <div class="form-group mb-0">
              <label class="form-label">Transaction Reference #</label>
              <input type="text" id="modalTxnId" class="form-control" placeholder="UPI Ref / Txn ID" />
            </div>
          </div>

          <div class="form-group mb-0">
            <label class="form-label">Notes (Optional)</label>
            <textarea id="modalNotes" class="form-control" rows="2" placeholder="e.g. Paid in full for next month renewal"></textarea>
          </div>

          <div style="background: var(--color-primary-bg); padding: 12px; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
            <span style="font-weight: 500; color: var(--color-primary);">Final Payable Amount:</span>
            <strong id="modalFinalDisplay" style="font-size: 1.2rem; color: var(--color-primary);">${k(Math.max(0,l-d))}</strong>
          </div>

        </form>
      `,u=j.show({title:`Collect Fee: ${o}`,content:c,size:"md",actions:`
          <button class="btn btn-secondary" onclick="window.Modal&&window.Modal.closeAll?window.Modal.closeAll():document.querySelector('dialog[open]')?.close()">Cancel</button>
          <button class="btn btn-primary d-flex align-items-center gap-2" id="btnSubmitCollectFee">
            <span>\u{1F4BE} Record Payment</span>
          </button>
        `}),p=u.querySelector("#modalPlanSelect"),v=u.querySelector("#modalAmount"),b=u.querySelector("#modalDiscount"),C=u.querySelector("#modalFinalDisplay");p&&p.addEventListener("change",x=>{const S=x.target.options[x.target.selectedIndex],w=S.dataset.price,D=S.dataset.discount||0;w&&v&&(v.value=w,b&&(b.value=D),n())}),v&&v.addEventListener("input",n),b&&b.addEventListener("input",n);const $=u.querySelector("#btnSubmitCollectFee");$&&($.onclick=async()=>{const x=p?.value,S=parseFloat(v?.value),w=parseFloat(b?.value)||0,D=u.querySelector("#modalMethod")?.value||"upi",F=u.querySelector("#modalTxnId")?.value||"",m=u.querySelector("#modalNotes")?.value||"";if(!x){h.error("Please select a membership plan");return}if(isNaN(S)||S<=0){h.error("Please enter a valid amount");return}Y.button($,!0);try{const g=await E.post("/api/payments",{student:e,plan:x,amount:S,discount:w,lateFee:0,paymentMethod:D,transactionId:F,notes:m,status:"paid"});g.success?(j.close(),h.success("Fee collected and subscription renewed successfully!"),await M()):h.error(g.message||"Payment submission failed")}catch(g){console.error("Payment error:",g),h.error(g.message||"Error processing payment")}finally{Y.button($,!1)}})}catch(n){console.error("Error opening collect fee modal:",n),h.error("Failed to open fee collection")}}}export{it as render};
