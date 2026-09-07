import u from"../api.js";import{Toast as s,Modal as c,escapeHTML as n}from"../ui.js";import{t as p}from"../i18n.js";async function E(){const t=document.getElementById("page-content");t&&(t.innerHTML=`
    <div class="page-header flex-between mb-4">
      <div>
        <h1 class="page-title">\u{1F510} ${p("nav.lockers","Locker Management")}</h1>
        <p class="text-muted text-sm">Manage physical lockers, student allocations, and security deposits</p>
      </div>
      <div class="header-actions d-flex gap-2">
        <button id="btn-block-manager" class="btn btn-outline">
          \u{1F9F1} Block Manager
        </button>
        <button id="btn-bulk-lockers" class="btn btn-outline">
          \u26A1 ${p("lockers.bulkGenerate","Bulk Generate")}
        </button>
        <button id="btn-add-locker" class="btn btn-primary">
          + ${p("lockers.addLocker","Add Locker")}
        </button>
      </div>
    </div>

    <!-- Stat KPI Cards -->
    <div class="kpi-grid mb-4">
      <div class="kpi-card kpi-primary">
        <div class="stat-label">${p("lockers.total","Total Lockers")}</div>
        <div class="stat-value" id="stat-total" style="font-size: 1.75rem; font-weight: 700;">0</div>
        <div class="stat-meta text-muted">All physical units</div>
      </div>
      <div class="kpi-card kpi-success">
        <div class="stat-label">${p("lockers.available","Available")}</div>
        <div class="stat-value text-success" id="stat-available" style="font-size: 1.75rem; font-weight: 700; color: var(--color-success);">0</div>
        <div class="stat-meta text-muted">Ready for allocation</div>
      </div>
      <div class="kpi-card kpi-primary">
        <div class="stat-label">${p("lockers.occupied","Occupied")}</div>
        <div class="stat-value text-primary" id="stat-occupied" style="font-size: 1.75rem; font-weight: 700; color: var(--color-primary);">0</div>
        <div class="stat-meta text-muted">Currently in use</div>
      </div>
      <div class="kpi-card kpi-warning">
        <div class="stat-label">${p("lockers.depositHeld","Deposit Held")}</div>
        <div class="stat-value text-warning" id="stat-deposit" style="font-size: 1.75rem; font-weight: 700; color: var(--color-warning);">\u20B90</div>
        <div class="stat-meta text-muted">Refundable security</div>
      </div>
    </div>

    <!-- Filter Bar -->
    <div class="card mb-4">
      <div class="card-body p-3 d-flex flex-wrap gap-3 align-center">
        <div id="block-filters" class="d-flex gap-2 flex-wrap w-100 mb-2">
          <!-- Block filters injected here -->
        </div>
        <div style="flex: 1; min-width: 200px;">
          <input type="text" id="locker-search" class="form-control" placeholder="\u{1F50D} Search locker number...">
        </div>
        <div style="min-width: 150px;">
          <select id="locker-status-filter" class="form-control">
            <option value="all">All Statuses</option>
            <option value="available">\u{1F7E2} Available</option>
            <option value="occupied">\u{1F535} Occupied</option>
            <option value="maintenance">\u{1F7E0} Maintenance</option>
          </select>
        </div>
        <div style="min-width: 130px;">
          <select id="locker-size-filter" class="form-control">
            <option value="all">All Sizes</option>
            <option value="small">Small</option>
            <option value="medium">Medium</option>
            <option value="large">Large</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Locker Grid -->
    <div id="lockers-grid" class="d-grid" style="grid-template-columns: repeat(auto-fill, minmax(min(100%, 220px), 1fr)); gap: 16px;">
      <div class="text-center p-4 text-muted" style="grid-column: 1 / -1;">Loading lockers...</div>
    </div>
  `,t.querySelector("#btn-add-locker")?.addEventListener("click",x),t.querySelector("#btn-bulk-lockers")?.addEventListener("click",$),t.querySelector("#btn-block-manager")?.addEventListener("click",A),t.querySelector("#locker-search")?.addEventListener("input",w(d,300)),t.querySelector("#locker-status-filter")?.addEventListener("change",d),t.querySelector("#locker-size-filter")?.addEventListener("change",d),await d())}let y=[],b="all",g=[];async function d(){try{const t=document.getElementById("locker-search")?.value||"",l=document.getElementById("locker-status-filter")?.value||"all",e=document.getElementById("locker-size-filter")?.value||"all",a=await u.get(`/api/lockers?search=${encodeURIComponent(t)}&status=${l}&size=${e}`),r=await u.get("/api/lockers/blocks");if(!a||!a.success){s.error("Failed to load lockers");return}y=a.lockers||[],g=r?.blocks||[];const o=a.stats||{};let i=y;if(b!=="all"&&(i=y.filter(m=>(m.block||"Block A")===b)),b!=="all"){const m=g.find(k=>k.block===b)||{total:0,available:0,assigned:0,totalRevenue:0};document.getElementById("stat-total").textContent=m.total,document.getElementById("stat-available").textContent=m.available,document.getElementById("stat-occupied").textContent=m.assigned;const v=i.reduce((k,f)=>k+(f.isDepositPaid&&!f.isDepositRefunded&&f.depositAmount||0),0);document.getElementById("stat-deposit").textContent=`\u20B9${v.toLocaleString("en-IN")}`}else document.getElementById("stat-total").textContent=o.total||0,document.getElementById("stat-available").textContent=o.available||0,document.getElementById("stat-occupied").textContent=o.occupied||0,document.getElementById("stat-deposit").textContent=`\u20B9${(o.totalDeposit||0).toLocaleString("en-IN")}`;h(),B(i)}catch(t){console.error(t),s.error("Error loading lockers")}}function h(){const t=document.getElementById("block-filters");if(!t)return;let l=`<button class="btn btn-sm ${b==="all"?"btn-primary":"btn-outline"} block-filter-btn" data-block="all">All Blocks</button>`;g.forEach(e=>{const a=b===e.block;l+=`<button class="btn btn-sm ${a?"btn-primary":"btn-outline"} block-filter-btn" data-block="${n(e.block)}">${n(e.block)} (${e.total})</button>`}),t.innerHTML=l,t.querySelectorAll(".block-filter-btn").forEach(e=>{e.addEventListener("click",a=>{b=a.target.dataset.block,d()})})}function B(t){const l=document.getElementById("lockers-grid");if(l){if(t.length===0){UI.emptyState(l,{icon:"\u{1F510}",title:"No Lockers Configured",description:"Add physical lockers individually or bulk generate locker series (e.g. L-01 to L-50).",actionText:"+ Add First Locker",onAction:x});return}l.innerHTML=t.map(e=>{const a=e.status==="occupied",r=e.status==="maintenance",o=a?"var(--color-primary)":r?"var(--color-warning)":"var(--color-success)",i=a?"badge-primary":r?"badge-warning":"badge-success";return`
      <div class="card" style="border-top: 4px solid ${o}; transition: transform 0.15s ease;">
        <div class="card-body p-3">
          <div class="flex-between mb-2">
            <span style="font-size: 18px; font-weight: 700;">${n(e.lockerNumber)}</span>
            <span class="badge ${i}" style="text-transform: capitalize;">${n(e.status)}</span>
          </div>
          
          <div class="text-xs text-muted mb-2">
            Size: <strong>${n(e.size)}</strong> | Key #: <strong>${n(e.keyNumber||"N/A")}</strong>
          </div>

          ${a?`
            <div style="background: rgba(99, 102, 241, 0.08); padding: 8px 10px; border-radius: 8px; margin-bottom: 12px;">
              <div class="text-xs text-muted">Assigned To:</div>
              <div style="font-weight: 600; font-size: 14px;">${n(e.assignedStudent?.name||"Student")}</div>
              <div class="text-xs text-muted">ID: ${n(e.assignedStudent?.studentId||"")} | Dep: \u20B9${e.depositAmount}</div>
            </div>
            <button class="btn btn-sm btn-outline w-100 btn-release-locker" data-id="${e._id}" data-num="${n(e.lockerNumber)}" data-dep="${e.depositAmount}">
              \u{1F513} Release & Refund
            </button>
          `:r?`
            <div style="background: rgba(245, 158, 11, 0.08); padding: 8px 10px; border-radius: 8px; margin-bottom: 12px;">
              <div class="text-xs text-warning">Under Maintenance</div>
              <div class="text-xs text-muted">${n(e.notes||"Repairs in progress")}</div>
            </div>
            <button class="btn btn-sm btn-primary w-100 btn-edit-locker" data-id="${e._id}">
              \u2699\uFE0F Make Available
            </button>
          `:`
            <div style="padding: 8px 0; margin-bottom: 12px;">
              <div class="text-xs text-muted">Deposit: \u20B9${e.depositAmount||0}</div>
              <div class="text-xs text-success">\u2713 Ready for student</div>
            </div>
            <button class="btn btn-sm btn-primary w-100 btn-assign-locker" data-id="${e._id}" data-num="${n(e.lockerNumber)}" data-dep="${e.depositAmount}">
              \u{1F511} Assign to Student
            </button>
          `}
        </div>
      </div>
    `}).join(""),l.querySelectorAll(".btn-assign-locker").forEach(e=>{e.addEventListener("click",()=>I(e.dataset.id,e.dataset.num,e.dataset.dep))}),l.querySelectorAll(".btn-release-locker").forEach(e=>{e.addEventListener("click",()=>L(e.dataset.id,e.dataset.num,e.dataset.dep))}),l.querySelectorAll(".btn-edit-locker").forEach(e=>{e.addEventListener("click",()=>showEditLockerModal(e.dataset.id))})}}function x(){new c({title:"Add New Locker",content:`
      <form id="add-locker-form">
        <div class="form-group mb-3">
          <label class="form-label">Locker Number / ID *</label>
          <input type="text" id="add-locker-number" class="form-control" placeholder="e.g. L-01" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Size</label>
          <select id="add-locker-size" class="form-control">
            <option value="small">Small (Books & Bags)</option>
            <option value="medium" selected>Medium (Standard)</option>
            <option value="large">Large (Cabin Size)</option>
          </select>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Key Number / Duplicate Key ID</label>
          <input type="text" id="add-locker-key" class="form-control" placeholder="e.g. K-101">
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Caution Deposit (\u20B9)</label>
          <input type="number" id="add-locker-deposit" class="form-control" value="200" min="0">
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Create Locker</button>
        </div>
      </form>
    `}).show(),document.getElementById("add-locker-form")?.addEventListener("submit",async t=>{t.preventDefault();try{const l={lockerNumber:document.getElementById("add-locker-number").value.trim(),size:document.getElementById("add-locker-size").value,keyNumber:document.getElementById("add-locker-key").value.trim(),depositAmount:parseFloat(document.getElementById("add-locker-deposit").value)||0},e=await u.post("/api/lockers",l);e&&e.success?(s.success("Locker created successfully"),c.closeAll(),d()):s.error(e?.message||"Error creating locker")}catch(l){s.error(l.message||"Error creating locker")}})}function $(){new c({title:"\u26A1 Bulk Generate Lockers",content:`
      <form id="bulk-locker-form">
        <p class="text-sm text-muted mb-3">Quickly generate a sequence of locker boxes in one click.</p>
        <div class="d-grid grid-2 gap-3 mb-3">
          <div class="form-group">
            <label class="form-label">Prefix</label>
            <input type="text" id="bulk-prefix" class="form-control" value="L-" required>
          </div>
          <div class="form-group">
            <label class="form-label">Start Number</label>
            <input type="number" id="bulk-start" class="form-control" value="1" min="1" required>
          </div>
        </div>
        <div class="d-grid grid-2 gap-3 mb-3">
          <div class="form-group">
            <label class="form-label">Total Count</label>
            <input type="number" id="bulk-count" class="form-control" value="20" min="1" max="100" required>
          </div>
          <div class="form-group">
            <label class="form-label">Size</label>
            <select id="bulk-size" class="form-control">
              <option value="small">Small</option>
              <option value="medium" selected>Medium</option>
              <option value="large">Large</option>
            </select>
          </div>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Default Caution Deposit (\u20B9)</label>
          <input type="number" id="bulk-deposit" class="form-control" value="200" min="0">
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Generate Lockers</button>
        </div>
      </form>
    `}).show(),document.getElementById("bulk-locker-form")?.addEventListener("submit",async t=>{t.preventDefault();try{const l={isBulk:!0,prefix:document.getElementById("bulk-prefix").value.trim(),startNumber:parseInt(document.getElementById("bulk-start").value,10),count:parseInt(document.getElementById("bulk-count").value,10),size:document.getElementById("bulk-size").value,depositAmount:parseFloat(document.getElementById("bulk-deposit").value)||0},e=await u.post("/api/lockers",l);e&&e.success?(s.success(e.message||"Lockers generated"),c.closeAll(),d()):s.error(e?.message||"Error generating lockers")}catch(l){s.error(l.message||"Error generating lockers")}})}async function I(t,l,e){let a=[];try{const o=await u.get("/api/students?limit=100&status=active");a=o?.data?.students||o?.data||o?.students||[]}catch{}const r=a.map(o=>`
    <option value="${o._id}">${n(o.name)} (${o.studentId} - ${o.phone})</option>
  `).join("");new c({title:`\u{1F511} Assign Locker ${n(l)}`,content:`
      <form id="assign-locker-form">
        <div class="form-group mb-3">
          <label class="form-label">Select Student *</label>
          <select id="assign-student-id" class="form-control" required>
            <option value="">-- Choose active student --</option>
            ${r}
          </select>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Locker Caution Deposit (\u20B9)</label>
          <input type="number" id="assign-deposit" class="form-control" value="${e||200}" min="0">
        </div>
        <div class="form-group mb-3">
          <label class="d-flex align-center gap-2">
            <input type="checkbox" id="assign-deposit-paid" checked>
            <span>Deposit received in Cash / UPI</span>
          </label>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Key Number Handed Over</label>
          <input type="text" id="assign-key" class="form-control" placeholder="e.g. Key #04">
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Confirm Assignment</button>
        </div>
      </form>
    `}).show(),document.getElementById("assign-locker-form")?.addEventListener("submit",async o=>{o.preventDefault();try{const i=document.getElementById("assign-student-id").value;if(!i){s.error("Please select a student");return}const m={studentId:i,depositAmount:parseFloat(document.getElementById("assign-deposit").value)||0,isDepositPaid:document.getElementById("assign-deposit-paid").checked,keyNumber:document.getElementById("assign-key").value.trim()},v=await u.put(`/api/lockers/${t}/assign`,m);v&&v.success?(s.success(`Locker ${l} assigned to student!`),c.closeAll(),d()):s.error(v?.message||"Error assigning locker")}catch(i){s.error(i.message||"Error assigning locker")}})}function L(t,l,e){new c({title:`\u{1F513} Release Locker ${n(l)}`,content:`
      <div>
        <p class="mb-3">Are you sure you want to release <strong>${n(l)}</strong>? The student will be de-allocated and the locker marked available.</p>
        
        <div style="background: rgba(245, 158, 11, 0.1); padding: 12px; border-radius: 8px; margin-bottom: 16px;">
          <label class="d-flex align-center gap-2">
            <input type="checkbox" id="refund-deposit-cb" checked>
            <span><strong>Refund Caution Deposit (\u20B9${e||0})</strong> to student</span>
          </label>
        </div>

        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="button" id="confirm-release-btn" class="btn btn-warning">Confirm Release</button>
        </div>
      </div>
    `}).show(),document.getElementById("confirm-release-btn")?.addEventListener("click",async()=>{try{const a=document.getElementById("refund-deposit-cb").checked,r=await u.put(`/api/lockers/${t}/release`,{refundDeposit:a});r&&r.success?(s.success(`Locker ${l} released`),c.closeAll(),d()):s.error(r?.message||"Error releasing locker")}catch(a){s.error(a.message||"Error releasing locker")}})}function w(t,l){let e;return function(...a){clearTimeout(e),e=setTimeout(()=>t.apply(this,a),l)}}function A(){let t=g.map(l=>`<option value="${n(l.block)}">${n(l.block)}</option>`).join("");t||(t='<option value="Block A">Block A</option>'),new c({title:"\u{1F9F1} Locker Block & Pricing Manager",content:`
      <form id="block-manager-form">
        <p class="text-sm text-muted mb-3">Update pricing and size for all lockers in a selected block.</p>
        <div class="form-group mb-3">
          <label class="form-label">Select Block *</label>
          <select id="manage-block-name" class="form-control" required>
            ${t}
          </select>
        </div>
        <div class="d-grid grid-2 gap-3 mb-3">
          <div class="form-group">
            <label class="form-label">Monthly Rental Fee (\u20B9)</label>
            <input type="number" id="manage-monthly-fee" class="form-control" placeholder="e.g. 500" min="0">
          </div>
          <div class="form-group">
            <label class="form-label">Caution Deposit (\u20B9)</label>
            <input type="number" id="manage-deposit-fee" class="form-control" placeholder="e.g. 200" min="0">
          </div>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Change Size (Optional)</label>
          <select id="manage-block-size" class="form-control">
            <option value="">-- No Change --</option>
            <option value="small">Small</option>
            <option value="medium">Medium</option>
            <option value="large">Large</option>
          </select>
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Apply Changes</button>
        </div>
      </form>
    `}).show(),document.getElementById("block-manager-form")?.addEventListener("submit",async l=>{l.preventDefault();try{const e={block:document.getElementById("manage-block-name").value},a=document.getElementById("manage-monthly-fee").value;a&&(e.monthlyFee=a);const r=document.getElementById("manage-deposit-fee").value;r&&(e.depositFee=r);const o=document.getElementById("manage-block-size").value;o&&(e.size=o);const i=await u.put("/api/lockers/blocks/pricing",e);i&&i.success?(s.success(i.message||"Block pricing updated"),c.closeAll(),d()):s.error(i?.message||"Error updating block pricing")}catch(e){s.error(e.message||"Error updating block pricing")}})}export{E as render};
