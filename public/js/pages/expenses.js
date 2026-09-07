import h from"../api.js";import{Toast as u,Modal as R,Confirm as C,escapeHTML as d}from"../ui.js";import{ChartEngine as I}from"../charts.js";import{MediaFieldPicker as j}from"../mediaStudio.js";import{PaymentStudio as O}from"../paymentStudio.js";function $(E){return new Intl.NumberFormat("en-IN",{style:"currency",currency:"INR",maximumFractionDigits:0}).format(E||0)}function k(E){return E?new Date(E).toLocaleDateString("en-IN",{day:"2-digit",month:"short",year:"numeric"}):"-"}let q=[];async function G(E){const w=new Date().getFullYear(),v=new Date().getMonth()+1;let o={selectedYear:w,selectedMonth:v,selectedCategory:"all",search:"",page:1,limit:15,summary:null,expenses:[],categories:[],pagination:{page:1,limit:15,total:0,pages:1}};const s=document.createElement("div");s.className="page-container",s.innerHTML=`
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>\u{1F3E2} Expense Tracking & Profit-Loss (P&L)</h2>
        <p>Track operating costs, rent, electricity, salaries, vendor bills, and auto-calculate net business profit.</p>
      </div>
      <div class="module-actions">
        <button class="btn btn-outline-info" id="btn-print-pnl" style="font-weight: 600;">
          \u{1F4C4} Print P&L Statement
        </button>
        <button class="btn btn-outline-secondary" id="btn-manage-categories" style="font-weight: 600;">
          \u{1F3F7}\uFE0F Manage Expense Categories
        </button>
        <button class="btn btn-outline-secondary" id="btn-export-expenses" style="font-weight: 600;">
          \u{1F4E5} Export CSV
        </button>
        <button class="btn btn-primary" id="btn-add-expense" style="font-weight: 700;">
          + Record Expense
        </button>
      </div>
    </div>

    <!-- Contextual Guidance Tip Banner -->
    <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
      <span style="font-size: 1.1rem;">\u{1F4A1}</span>
      <span><strong>Tip:</strong> Track library operational expenses, electricity bills, and rent to monitor net monthly profitability.</span>
    </div>

    <!-- Quick Recurring Presets Bar -->
    <div class="card p-2 mb-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
      <div class="d-flex align-items-center gap-2 flex-wrap">
        <span class="text-xs text-muted" style="font-weight: 800; letter-spacing: 0.5px; margin-right: 4px;">\u26A1 QUICK RECURRING PRESETS:</span>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-preset-expense" data-title="Monthly Property Rent" data-category="Rent & Infrastructure" data-mode="bank_transfer" style="font-weight: 600; border-radius: 20px;">\u{1F3E2} Property Rent</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-preset-expense" data-title="Electricity & AC Power Bill" data-category="Electricity & Utilities" data-mode="upi" style="font-weight: 600; border-radius: 20px;">\u26A1 Electricity Bill</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-preset-expense" data-title="High Speed Fiber WiFi Bill" data-category="Internet & Technology" data-mode="upi" style="font-weight: 600; border-radius: 20px;">\u{1F4F6} Fiber WiFi</button>
        <button type="button" class="btn btn-xs btn-outline-secondary btn-preset-expense" data-title="Staff & Cleaning Monthly Salary" data-category="Staff Salaries" data-mode="bank_transfer" style="font-weight: 600; border-radius: 20px;">\u{1F468}\u200D\u{1F4BC} Staff Salary</button>
      </div>
    </div>

    <!-- Date & Category Filters Toolbar -->
    <div class="toolbar-card">
      <div class="d-flex flex-wrap align-items-center justify-content-between gap-3">
        <div class="d-flex align-items-center gap-2 flex-wrap">
          <label class="form-label mb-0 text-xs" style="font-weight: 700; color: var(--color-text-secondary);">\u{1F4C5} PERIOD:</label>
          <select id="expense-month-filter" class="form-select form-control form-control-sm" style="width: 150px; font-weight: 600;">
            <option value="all">Full Year (${w})</option>
            <option value="1" ${v===1?"selected":""}>January</option>
            <option value="2" ${v===2?"selected":""}>February</option>
            <option value="3" ${v===3?"selected":""}>March</option>
            <option value="4" ${v===4?"selected":""}>April</option>
            <option value="5" ${v===5?"selected":""}>May</option>
            <option value="6" ${v===6?"selected":""}>June</option>
            <option value="7" ${v===7?"selected":""}>July</option>
            <option value="8" ${v===8?"selected":""}>August</option>
            <option value="9" ${v===9?"selected":""}>September</option>
            <option value="10" ${v===10?"selected":""}>October</option>
            <option value="11" ${v===11?"selected":""}>November</option>
            <option value="12" ${v===12?"selected":""}>December</option>
          </select>

          <select id="expense-year-filter" class="form-select form-control form-control-sm" style="width: 110px; font-weight: 600;">
            <option value="${w}">${w}</option>
            <option value="${w-1}">${w-1}</option>
            <option value="${w-2}">${w-2}</option>
          </select>
        </div>

        <div class="d-flex align-items-center gap-2 flex-wrap">
          <label class="form-label mb-0 text-xs" style="font-weight: 700; color: var(--color-text-secondary);">CATEGORY:</label>
          <select id="expense-category-filter" class="form-select form-control form-control-sm" style="width: 160px; font-weight: 600;">
            <option value="all">All Categories</option>
            <!-- Categories will be populated dynamically -->
          </select>
          <input type="text" id="expense-search-input" class="form-control form-control-sm" placeholder="Search title, vendor..." style="width: 220px;">
        </div>
      </div>
    </div>

    <!-- Standard P&L KPI Cards Grid -->
    <div class="kpi-grid" id="pnl-kpi-cards">
      <div class="kpi-card kpi-success">
        <div class="kpi-label">Total Fee Revenue <span>\u{1F4C8}</span></div>
        <div class="kpi-value text-success" id="kpi-revenue">\u20B90</div>
        <div class="kpi-subtext">Gross revenue</div>
      </div>
      <div class="kpi-card kpi-danger">
        <div class="kpi-label">Total Expenses <span>\u{1F4C9}</span></div>
        <div class="kpi-value text-danger" id="kpi-expense">\u20B90</div>
        <div class="kpi-subtext">Operating costs</div>
      </div>
      <div class="kpi-card kpi-primary">
        <div class="kpi-label">Net Profit / Margin <span>\u{1F4B0}</span></div>
        <div class="kpi-value" id="kpi-net-profit" style="color: var(--color-primary);">\u20B90</div>
        <div class="kpi-subtext" id="kpi-margin-percent">Margin: 0%</div>
      </div>
      <div class="kpi-card kpi-warning">
        <div class="kpi-label">Top Expense Category <span>\u{1F3F7}\uFE0F</span></div>
        <div class="kpi-value text-warning" id="kpi-top-category" style="font-size: 1.3rem;">-</div>
        <div class="kpi-subtext" id="kpi-top-category-amount">\u20B90</div>
      </div>
    </div>

    <!-- Charts Row -->
    <div class="row mb-4 g-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
      <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <h6 style="font-weight: 700; margin-bottom: 1rem;">\u{1F4CA} Expense Breakdown by Category</h6>
        <div style="position: relative; height: 220px; width: 100%;">
          <canvas id="expense-category-chart"></canvas>
        </div>
      </div>

      <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <h6 style="font-weight: 700; margin-bottom: 1rem;">\u{1F4C8} 6-Month Revenue vs Expense Trend</h6>
        <div style="position: relative; height: 220px; width: 100%;">
          <canvas id="expense-trend-chart"></canvas>
        </div>
      </div>
    </div>

    <!-- Expenses Table Card -->
    <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div class="card-header p-3 d-flex justify-content-between align-items-center" style="border-bottom: 1px solid var(--color-border);">
        <h5 style="font-weight: 700; margin: 0; font-size: 1rem;">\u{1F4CB} Expense Transactions Log</h5>
        <span class="badge badge-primary" id="expense-total-badge">0 items</span>
      </div>

      <div class="desktop-table-view">
        <div class="table-responsive">
          <table class="table data-table mb-0" style="width: 100%;">
            <thead>
              <tr>
                <th>Date</th>
                <th>Title & Description</th>
                <th>Category</th>
                <th>Vendor</th>
                <th>Payment Mode</th>
                <th class="text-right">Amount</th>
                <th class="text-center">Actions</th>
              </tr>
            </thead>
            <tbody id="expenses-table-body">
              <tr>
                <td colspan="7" class="text-center p-4 text-muted">Loading expenses...</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>

      <!-- Mobile Card List View -->
      <div class="mobile-card-list p-3" id="expenses-mobile-cards">
        <div class="mobile-card-empty">Loading expenses...</div>
      </div>

      <!-- Pagination Footer -->
      <div class="p-3 d-flex justify-content-between align-items-center flex-wrap gap-2" style="border-top: 1px solid var(--color-border);">
        <span class="text-muted small" id="expense-page-info">Showing 0 of 0</span>
        <div class="d-flex gap-2">
          <button class="btn btn-sm btn-outline-secondary" id="expense-prev-btn" disabled>Previous</button>
          <button class="btn btn-sm btn-outline-secondary" id="expense-next-btn" disabled>Next</button>
        </div>
      </div>
    </div>
  `,E.innerHTML="",E.appendChild(s);async function f(){try{const e=o.selectedMonth==="all"?"":`&month=${o.selectedMonth}`,[r,t,a]=await Promise.all([h.get("/api/expenses/categories"),h.get(`/api/expenses/summary?year=${o.selectedYear}${e}`),h.get(`/api/expenses?page=${o.page}&limit=${o.limit}&year=${o.selectedYear}${e}&category=${o.selectedCategory}&search=${encodeURIComponent(o.search)}`)]);r.success&&r.data&&(o.categories=r.data,q=r.data,N()),t.success&&t.data&&(o.summary=t.data,H(o.summary),_(o.summary)),a.success&&a.data&&(o.expenses=a.data.expenses,o.pagination=a.data.pagination,z(o.expenses,o.pagination))}catch(e){console.error("Failed to load expenses:",e),u.error("Failed to load financial records")}}function N(){const e=s.querySelector("#expense-category-filter");if(!e)return;const r=e.value;e.innerHTML='<option value="all">All Categories</option>'+o.categories.map(t=>`<option value="${d(t.name)}">${d(t.icon)} ${d(t.name)}</option>`).join(""),e.value=r||"all"}function H(e){const r=s.querySelector("#kpi-revenue"),t=s.querySelector("#kpi-expense")||s.querySelector("#kpi-expenses"),a=s.querySelector("#kpi-net-profit")||s.querySelector("#kpi-profit"),i=s.querySelector("#kpi-margin-percent")||s.querySelector("#kpi-margin-sub"),l=s.querySelector("#kpi-expenses-sub");r&&(r.textContent=$(e.totalRevenue)),t&&(t.textContent=$(e.totalExpenses)),l&&(l.textContent=`Across ${e.totalExpenseCount||0} expense records`),a&&(a.textContent=$(e.netProfit),a.style.color=e.netProfit>=0?"var(--color-success)":"var(--color-danger)"),i&&(i.textContent=`Profit Margin: ${e.profitMargin}% | Revenue: ${e.totalPaymentCount||0} payments`)}function _(e){const r=s.querySelector("#expense-category-chart");if(r&&e.categoryBreakdown){const t=e.categoryBreakdown.map(i=>i._id),a=e.categoryBreakdown.map(i=>i.total);if(t.length===0){const i=r.getContext("2d");i.clearRect(0,0,r.width,r.height),i.font="14px sans-serif",i.fillStyle="#888",i.textAlign="center",i.fillText("No expenses recorded for this period",r.width/2||150,100)}else I.barChart("expense-category-chart",{labels:t,data:a,color:"#ff7675",title:"Expenses by Category (\u20B9)"})}if(s.querySelector("#expense-trend-chart")&&e.sixMonthsTrend){const t=e.sixMonthsTrend.map(i=>i.label),a=e.sixMonthsTrend.map(i=>i.netProfit);I.lineChart("expense-trend-chart",{labels:t,data:a,color:"#6c5ce7",fill:!0,title:"Net Profit Trend (\u20B9)"})}}function z(e,r){const t=s.querySelector("#expenses-table-body"),a=s.querySelector("#expense-total-badge"),i=s.querySelector("#expense-page-info"),l=s.querySelector("#expense-prev-btn"),y=s.querySelector("#expense-next-btn");if(a&&(a.textContent=`${r.total} items`),i&&(i.textContent=`Page ${r.page} of ${r.pages||1} (${r.total} total)`),l&&(l.disabled=r.page<=1),y&&(y.disabled=r.page>=r.pages),!e||e.length===0){t.innerHTML=`
        <tr>
          <td colspan="7" class="text-center p-4 text-muted">
            <div style="font-size: 2rem; margin-bottom: 0.5rem;">\u{1F4B8}</div>
            <p style="margin: 0; font-weight: 500;">No expenses found matching the current filters.</p>
          </td>
        </tr>
      `;return}t.innerHTML=e.map(n=>`
        <tr>
          <td style="font-weight: 500; font-size: 0.85rem;">${k(n.date)}</td>
          <td>
            <div style="display: flex; align-items: center; gap: 10px;">
              ${O.renderCreditTrayIcon(32)}
              <div>
                <div style="font-weight: 600; font-size: 0.9rem;">${d(n.title)}</div>
                <div style="display: flex; align-items: center; gap: 6px; margin-top: 2px;">
                  <span class="tx-badge-pill tx-badge-debit" style="font-size: 0.65rem; padding: 1px 6px;">\u2191 EXPENSE</span>
                  ${n.description?`<span class="text-muted small" style="font-size: 0.75rem;">${d(n.description)}</span>`:""}
                </div>
              </div>
            </div>
          </td>
          <td>
            <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); font-size: 0.75rem;">
              ${d(n.category)}
            </span>
          </td>
          <td class="text-muted small">${d(n.vendor||"-")}</td>
          <td>
            <span class="badge" style="background: var(--color-bg-secondary); color: var(--color-text-secondary); text-transform: uppercase; font-size: 0.7rem;">
              ${d(n.paymentMethod)}
            </span>
          </td>
          <td class="text-right" style="font-weight: 700; color: #ef4444; font-size: 0.95rem;">
            -${$(n.amount)}
          </td>
          <td class="text-center" style="white-space: nowrap;">
            <div class="btn-icon-group" style="display: inline-flex; align-items: center; justify-content: center; gap: 4px;">
              <button type="button" class="btn-icon-action action-edit btn-edit-exp" data-id="${n._id}" data-tooltip="Edit Expense" aria-label="Edit Expense">\u270F\uFE0F</button>
              <button type="button" class="btn-icon-action action-whatsapp btn-share-exp" data-id="${n._id}" data-share="Expense: ${d(n.title)} - \u20B9${n.amount} (${d(n.category||"")})" data-tooltip="Share Expense" aria-label="Share">\u{1F4F2}</button>
              ${typeof ActionMenu<"u"?ActionMenu.renderHtml([{header:"Level 1: Expense Operations"},{id:"edit",icon:"\u270F\uFE0F",label:"Edit Expense Details",bold:!0},{id:"clone",icon:"\u{1F4D1}",label:"Duplicate / Re-record Expense"},{divider:!0},{header:"Level 2: Danger Zone"},{id:"delete",icon:"\u{1F5D1}\uFE0F",label:"Delete Expense Record",danger:!0}],n._id):""}
            </div>
          </td>
        </tr>
      `).join("");const b=s.querySelector("#expenses-mobile-cards");b&&(!e||e.length===0?b.innerHTML=`
          <div class="mobile-card-empty text-center p-4">
            <div style="font-size: 2rem; margin-bottom: 0.5rem;">\u{1F4B8}</div>
            <p style="margin: 0; font-weight: 500;" class="text-muted">No expenses found matching the current filters.</p>
          </div>
        `:b.innerHTML=e.map(n=>`
          <div class="mobile-data-card">
            <div class="mobile-card-header">
              <div>
                <div class="mobile-card-title">${d(n.title)}</div>
                <div class="mobile-card-subtitle">${k(n.date)} \u2022 ${d(n.vendor||"General")}</div>
              </div>
              <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); font-size: 0.75rem;">
                ${d(n.category)}
              </span>
            </div>
            <div class="mobile-card-details">
              <div class="mobile-card-detail">
                <div class="mobile-card-detail-label">Payment Mode</div>
                <div class="mobile-card-detail-value" style="text-transform: uppercase;">${d(n.paymentMethod||"Cash")}</div>
              </div>
              <div class="mobile-card-detail">
                <div class="mobile-card-detail-label">Amount</div>
                <div class="mobile-card-detail-value" style="color: #ef4444; font-weight: 800; font-size: 1.05rem;">
                  -${$(n.amount)}
                </div>
              </div>
              ${n.description?`
                <div class="mobile-card-detail detail-full-width">
                  <div class="mobile-card-detail-label">Description</div>
                  <div class="mobile-card-detail-value small text-muted">${d(n.description)}</div>
                </div>
              `:""}
            </div>
            <div class="mobile-card-actions">
              <button type="button" class="btn btn-sm btn-outline-primary btn-edit-tx" data-id="${n._id}" style="min-height: 42px; flex: 1; font-weight: 700;">\u270F\uFE0F Edit</button>
              <button type="button" class="btn btn-sm btn-outline-success btn-share-tx" data-id="${n._id}" data-share="Expense: ${d(n.title)} - \u20B9${n.amount} (${d(n.category||"")})" style="min-height: 42px; flex: 1; font-weight: 700;">\u{1F4F2} WhatsApp</button>
              <button type="button" class="btn btn-sm btn-outline-danger btn-delete-tx" data-id="${n._id}" style="min-height: 42px; flex: 1; font-weight: 700;">\u{1F5D1}\uFE0F Delete</button>
            </div>
          </div>
        `).join("")),[t,b].filter(Boolean).forEach(n=>{n.querySelectorAll(".btn-copy-tx").forEach(p=>{p.addEventListener("click",c=>{c.stopPropagation();const m=p.dataset.copy;m&&navigator.clipboard.writeText(m).then(()=>{u.success(`Copied: ${m}`)})})}),n.querySelectorAll(".btn-edit-tx, .btn-edit-exp").forEach(p=>{p.addEventListener("click",c=>{c.stopPropagation();const m=p.dataset.id,g=o.expenses.find(x=>x._id===m);g&&F(g)})}),n.querySelectorAll(".btn-delete-tx").forEach(p=>{p.addEventListener("click",async c=>{c.stopPropagation();const m=p.dataset.id,g=o.expenses.find(x=>x._id===m);if(g&&await C.show({title:"Delete Expense",message:`Are you sure you want to delete "${g.title}" (\u20B9${g.amount})?`,confirmText:"Delete",cancelText:"Cancel"}))try{await h.delete(`/api/expenses/${m}`),u.success("Expense deleted"),loadExpenses()}catch{u.error("Failed to delete expense")}})}),n.querySelectorAll(".btn-share-tx, .btn-share-exp").forEach(p=>{p.addEventListener("click",c=>{c.stopPropagation();const m=p.dataset.share;m&&window.open(`https://wa.me/?text=${encodeURIComponent(m)}`,"_blank")})})}),t.querySelectorAll(".action-menu-item").forEach(n=>{n.addEventListener("click",async p=>{p.preventDefault(),p.stopPropagation();const c=n.dataset.action,m=n.dataset.id,g=o.expenses.find(x=>x._id===m);if(g){if(c==="edit")F(g);else if(c==="clone"){const x={...g,title:`${g.title} (Repeat)`,date:new Date().toISOString().split("T")[0]};delete x._id,delete x.createdAt,F(x)}else if(c==="delete"&&await C.show({title:"Delete Expense Record",message:`Are you sure you want to delete "${g.title}"?`,danger:!0}))try{await h.delete(`/api/expenses/${m}`),u.success("Expense deleted successfully"),f()}catch{u.error("Failed to delete expense")}}})}),t.querySelectorAll(".btn-edit-exp").forEach(n=>{n.addEventListener("click",()=>{const p=o.expenses.find(c=>c._id===n.dataset.id);p&&F(p)})})}function F(e=null){const r=!!e,t=document.createElement("div");t.innerHTML=`
      <form id="expense-form" class="p-1">
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Expense Title *</label>
          <input type="text" id="exp-title" class="form-control" placeholder="e.g., Office Rent, Power Bill, Wi-Fi 300Mbps" value="${d(e?.title||"")}" required>
        </div>

        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Category *</label>
            <select id="exp-category" class="form-select" required>
              ${q.map(c=>`<option value="${d(c.name)}" ${e?.category===c.name?"selected":""}>${d(c.icon)} ${d(c.name)}</option>`).join("")}
            </select>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">Amount (\u20B9) *</label>
            <input type="number" id="exp-amount" class="form-control" placeholder="0" min="1" step="any" value="${e?.amount||""}" required>
          </div>
        </div>

        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Expense Date *</label>
            <input type="date" id="exp-date" class="form-control" value="${e?.date?new Date(e.date).toISOString().split("T")[0]:new Date().toISOString().split("T")[0]}" required>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">Payment Mode *</label>
            <select id="exp-payment-method" class="form-select" style="font-weight: 600;">
              <option value="upi" ${e?.paymentMethod==="upi"||!e?"selected":""}>\u26A1 UPI / QR Payment</option>
              <option value="cash" ${e?.paymentMethod==="cash"?"selected":""}>\u{1F4B5} Cash from Drawer</option>
              <option value="bank_transfer" ${e?.paymentMethod==="bank_transfer"?"selected":""}>\u{1F3DB}\uFE0F Bank Transfer / NEFT / IMPS</option>
              <option value="card" ${e?.paymentMethod==="card"?"selected":""}>\u{1F4B3} Debit / Credit Card</option>
              <option value="cheque" ${e?.paymentMethod==="cheque"?"selected":""}>\u{1F4DD} Cheque Issued</option>
            </select>
          </div>
        </div>

        <div id="exp-payment-context" class="mb-3"></div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Vendor / Payee</label>
          <input type="text" id="exp-vendor" class="form-control" placeholder="e.g. Landlord Name, Airtel, MSEB" value="${d(e?.vendor||"")}">
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Bill / Payment Receipt Scan</label>
          <div id="mount-expense-receipt"></div>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" id="exp-desc-label" style="font-weight: 600;">Notes / Reference ID</label>
          <textarea id="exp-desc" class="form-control" rows="2" placeholder="Optional details or transaction reference">${d(e?.description||"")}</textarea>
        </div>

        <div class="d-flex justify-content-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" id="btn-cancel-exp">Cancel</button>
          <button type="submit" class="btn btn-primary" id="btn-save-exp">${r?"Update Expense":"Save Expense"}</button>
        </div>
      </form>
    `;const a=t.querySelector("#mount-expense-receipt");a&&a.appendChild(j.create({label:"Receipt / Invoice Proof (Camera / File)",preset:"document",name:"receiptImage",value:e?.receiptImage||""}));const i=t.querySelector("#exp-payment-method"),l=t.querySelector("#exp-payment-context"),y=t.querySelector("#exp-desc-label"),b=t.querySelector("#exp-desc"),n=()=>{const c=i?.value||"upi";c==="cash"?(y&&(y.innerHTML="\u{1F4B5} Cash Voucher No. / Note (Optional)"),b&&(b.placeholder="e.g. Cash Voucher #102, Handed to caretaker"),l&&(l.innerHTML=`
            <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4B5}</span>
              <span><strong>Cash Expense:</strong> Disbursed directly from reception cash register.</span>
            </div>
          `)):c==="bank_transfer"?(y&&(y.innerHTML="\u{1F3DB}\uFE0F Bank Transaction Ref / UTR No."),b&&(b.placeholder="e.g. NEFT / IMPS Ref #89324021"),l&&(l.innerHTML=`
            <div style="background: rgba(9, 132, 227, 0.1); border: 1px solid #0984e3; border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F3DB}\uFE0F</span>
              <span><strong>Bank Transfer:</strong> Transferred directly from library bank account.</span>
            </div>
          `)):c==="card"?(y&&(y.innerHTML="\u{1F4B3} Card Machine Slip / Auth Code"),b&&(b.placeholder="e.g. Card ending 4321 / Auth #8492"),l&&(l.innerHTML=`
            <div style="background: rgba(225, 112, 85, 0.1); border: 1px solid #e17055; border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4B3}</span>
              <span><strong>Card Payment:</strong> Paid via Debit / Corporate Credit Card.</span>
            </div>
          `)):c==="cheque"?(y&&(y.innerHTML="\u{1F4DD} Cheque Number & Drawn Bank"),b&&(b.placeholder="e.g. Cheque #004521 - HDFC Bank"),l&&(l.innerHTML=`
            <div style="background: rgba(108, 92, 231, 0.1); border: 1px solid var(--color-primary, #6c5ce7); border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u{1F4DD}</span>
              <span><strong>Cheque Payment:</strong> Physical cheque issued to vendor.</span>
            </div>
          `)):(y&&(y.innerHTML="\u26A1 UPI Transaction Ref / 12-Digit UTR"),b&&(b.placeholder="e.g. 12-digit UTR No. from GPay/PhonePe"),l&&(l.innerHTML=`
            <div style="background: rgba(108, 92, 231, 0.1); border: 1px solid var(--color-primary, #6c5ce7); border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>\u26A1</span>
              <span><strong>UPI Payment:</strong> Paid via UPI QR / GPay / PhonePe / Paytm.</span>
            </div>
          `))};i&&(i.addEventListener("change",n),n());const p=new R({title:r?"\u270F\uFE0F Edit Operating Expense":"\u2795 Record Operating Expense",content:t,size:"md"});p.show(),t.querySelector("#btn-cancel-exp").onclick=()=>p.close(),t.querySelector("#expense-form").onsubmit=async c=>{c.preventDefault();const m=t.querySelector("#exp-title").value.trim(),g=t.querySelector("#exp-category").value,x=parseFloat(t.querySelector("#exp-amount").value),P=t.querySelector("#exp-date").value,L=t.querySelector("#exp-payment-method").value,D=t.querySelector("#exp-vendor").value.trim(),B=t.querySelector('input[name="receiptImage"]')?.value||"",A=t.querySelector("#exp-desc").value.trim();if(!m){u.error("Expense title is required");return}if(isNaN(x)||x<=0){u.error("Expense amount must be a valid positive number");return}const S=t.querySelector("#btn-save-exp");S.disabled=!0,S.textContent="Saving...";try{r?(await h.put(`/api/expenses/${e._id}`,{title:m,category:g,amount:x,date:P,paymentMethod:L,vendor:D,receiptImage:B,description:A}),u.success("Expense updated")):(await h.post("/api/expenses",{title:m,category:g,amount:x,date:P,paymentMethod:L,vendor:D,receiptImage:B,description:A}),u.success("Expense recorded successfully")),p.close(),f()}catch(U){u.error(U.message||"Failed to save expense"),S.disabled=!1,S.textContent=r?"Update Expense":"Save Expense"}}}function M(){const e=document.createElement("div");e.innerHTML=`
      <div class="mb-3 d-flex gap-2">
        <input type="text" id="new-cat-name" class="form-control" placeholder="Category Name" style="flex: 1;">
        <input type="text" id="new-cat-icon" class="form-control" placeholder="Icon (e.g. \u{1F354})" style="width: 100px;">
        <input type="color" id="new-cat-color" class="form-control" value="#e74c3c" style="width: 60px; padding: 2px;">
        <button class="btn btn-primary" id="btn-add-cat">Add</button>
      </div>
      <div class="table-responsive" style="max-height: 400px; overflow-y: auto;">
        <table class="table mb-0">
          <thead>
            <tr>
              <th>Icon</th>
              <th>Name</th>
              <th class="text-center">Action</th>
            </tr>
          </thead>
          <tbody id="cat-list-body">
            <tr><td colspan="3" class="text-center">Loading...</td></tr>
          </tbody>
        </table>
      </div>
    `;const r=()=>{const t=e.querySelector("#cat-list-body");t.innerHTML=q.map(a=>`
        <tr>
          <td style="font-size: 1.2rem;">${d(a.icon||"\u{1F4B8}")}</td>
          <td>
            <div style="font-weight: 600; color: ${d(a.color||"#333")}">${d(a.name)}</div>
            ${a.isSystem?'<span class="badge bg-secondary text-xs">System</span>':""}
          </td>
          <td class="text-center">
            ${a.isSystem?"-":`
              <div class="btn-icon-group justify-content-center">
                <button type="button" class="btn-icon-action action-edit btn-edit-cat" data-id="${a._id}" data-name="${d(a.name)}" data-icon="${d(a.icon||"")}" data-color="${d(a.color||"#333")}" data-tooltip="Edit Expense Category" aria-label="Edit">\u270F\uFE0F</button>
                <button type="button" class="btn-icon-action action-delete btn-delete-cat" data-id="${a._id}" data-tooltip="Delete Expense Category" aria-label="Delete">\u{1F5D1}\uFE0F</button>
              </div>
            `}
          </td>
        </tr>
      `).join(""),t.querySelectorAll(".btn-edit-cat").forEach(a=>{a.addEventListener("click",()=>{const i=prompt("Edit Category Name",a.dataset.name);if(i===null)return;const l=prompt("Edit Category Icon",a.dataset.icon)||"\u{1F4B8}",y=prompt("Edit Category Color",a.dataset.color)||"#e74c3c";if(!i.trim())return u.error("Name cannot be empty");h.put(`/api/expenses/categories/${a.dataset.id}`,{name:i.trim(),icon:l.trim(),color:y.trim()}).then(async()=>{u.success("Category updated"),await f(),r()}).catch(b=>{u.error(b.message||"Failed to update category")})})}),t.querySelectorAll(".btn-delete-cat").forEach(a=>{a.addEventListener("click",async()=>{if(await C.show({title:"Delete Category",message:"Delete this category?",danger:!0}))try{await h.delete(`/api/expenses/categories/${a.dataset.id}`),u.success("Category deleted"),await f(),r()}catch(i){u.error(i.message||"Failed to delete category")}})})};new R({title:"\u{1F3F7}\uFE0F Manage Expense Categories",content:e,size:"md"}).show(),r(),e.querySelector("#btn-add-cat").addEventListener("click",async()=>{const t=e.querySelector("#new-cat-name").value.trim(),a=e.querySelector("#new-cat-icon").value.trim()||"\u{1F4B8}",i=e.querySelector("#new-cat-color").value;if(!t)return u.error("Name is required");try{await h.post("/api/expenses/categories",{name:t,icon:a,color:i}),u.success("Category added"),e.querySelector("#new-cat-name").value="",e.querySelector("#new-cat-icon").value="",await f(),r()}catch(l){u.error(l.message||"Failed to add category")}})}s.querySelector("#expense-month-filter").addEventListener("change",e=>{o.selectedMonth=e.target.value,o.page=1,f()}),s.querySelector("#expense-year-filter").addEventListener("change",e=>{o.selectedYear=parseInt(e.target.value),o.page=1,f()}),s.querySelector("#expense-category-filter").addEventListener("change",e=>{o.selectedCategory=e.target.value,o.page=1,f()});let T;s.querySelector("#expense-search-input").addEventListener("input",e=>{clearTimeout(T),o.search=e.target.value,o.page=1,T=setTimeout(()=>{f()},300)}),s.querySelector("#btn-print-pnl")?.addEventListener("click",()=>{window.print()}),s.querySelectorAll(".btn-preset-expense").forEach(e=>{e.addEventListener("click",()=>{const r=e.dataset.title,t=e.dataset.category,a=e.dataset.mode||"cash";F({title:r,category:t,paymentMethod:a,amount:""})})}),s.querySelector("#btn-manage-categories").addEventListener("click",()=>{M()}),s.querySelector("#btn-add-expense").addEventListener("click",()=>{F()}),s.querySelector("#expense-prev-btn").addEventListener("click",()=>{o.page>1&&(o.page--,f())}),s.querySelector("#expense-next-btn").addEventListener("click",()=>{o.page<o.pagination.pages&&(o.page++,f())}),s.querySelector("#btn-export-expenses").addEventListener("click",()=>{if(!o.expenses||o.expenses.length===0){u.warning("No expenses to export");return}const e=["Date","Title","Category","Vendor","Payment Mode","Amount (INR)","Description"],r=o.expenses.map(l=>[k(l.date),`"${(l.title||"").replace(/"/g,'""')}"`,`"${(l.category||"").replace(/"/g,'""')}"`,`"${(l.vendor||"").replace(/"/g,'""')}"`,l.paymentMethod,l.amount,`"${(l.description||"").replace(/"/g,'""')}"`]),t="data:text/csv;charset=utf-8,"+[e.join(","),...r.map(l=>l.join(","))].join(`
`),a=encodeURI(t),i=document.createElement("a");i.setAttribute("href",a),i.setAttribute("download",`study_library_expenses_${o.selectedYear}_${o.selectedMonth}.csv`),document.body.appendChild(i),i.click(),document.body.removeChild(i)}),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1F4B8}",label:"Expense Actions",color:"#e17055",actions:[{icon:"\u2795",label:"Add Expense",onClick:()=>{F()}},{icon:"\u{1F3F7}\uFE0F",label:"Categories",onClick:()=>{M()}},{icon:"\u{1F4E5}",label:"Export CSV",onClick:()=>{const e=s.querySelector("#btn-export-expenses")||document.querySelector("#btn-export-expenses");e&&e.click()}}]}),await f()}export{G as render};
