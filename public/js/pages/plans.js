import"../app.js";import{t as o}from"../i18n.js";import{Toast as i,Confirm as T,escapeHTML as x}from"../ui.js";import b from"../api.js";let B=[],h=[];async function q(){const t=document.createElement("div");return t.className="page-container",t.innerHTML=`
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>\u{1F4B3} ${o("Plans & Pricing")}</h2>
        <p>Define study room membership tiers, durations, fee discounts, and pricing structures.</p>
      </div>
      <div class="module-actions">
        <button id="btn-create-plan" class="btn btn-primary d-flex align-items-center gap-2" style="font-weight: 700;">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
          ${o("+ Create Plan")}
        </button>
      </div>
    </div>
    
    <!-- Toolbar Card -->
    <div class="toolbar-card d-flex justify-content-between align-items-center flex-wrap gap-2">
      <div class="d-flex align-items-center gap-2">
        <input type="checkbox" id="show-inactive-plans" style="cursor: pointer; width: 16px; height: 16px;">
        <label for="show-inactive-plans" style="cursor: pointer; margin: 0; font-size: 0.88rem; font-weight: 600; color: var(--color-text-secondary);">${o("Show Inactive / Archived Plans")}</label>
      </div>
      <span class="text-muted text-xs">Manage seat access permissions per plan</span>
    </div>
    
    <div id="plans-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
      <!-- Plans will be rendered here -->
    </div>
    
    
    <hr style="margin: 3rem 0; border-color: var(--color-divider);">
    <div class="module-header mt-4">
      <div class="module-title-area">
        <h2>\u{1F39F}\uFE0F Promo Coupons & Discount Manager</h2>
        <p>Create and manage discount codes for student admissions.</p>
      </div>
      <div class="module-actions">
        <button id="btn-create-coupon" class="btn btn-primary d-flex align-items-center gap-2" style="font-weight: 700;">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
          ${o("Add Coupon")}
        </button>
      </div>
    <!-- Interactive Coupon Test Sandbox -->
    <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
      <div style="font-weight: 700; font-size: 0.9rem; color: var(--color-primary); margin-bottom: 8px;">
        \u{1F9EA} Interactive Coupon Calculator Sandbox
      </div>
      <div class="d-flex gap-2 flex-wrap align-items-center">
        <input type="text" id="sandbox-coupon-code" class="form-control form-control-sm" placeholder="Enter coupon code (e.g. SUMMER50)..." style="max-width: 220px; text-transform: uppercase;">
        <input type="number" id="sandbox-amount" class="form-control form-control-sm" placeholder="Plan Fee \u20B9 (e.g. 1000)" value="1000" style="max-width: 150px;">
        <button type="button" id="btn-test-coupon-sandbox" class="btn btn-sm btn-outline-primary" style="font-weight: 700;">\u26A1 Test Coupon Math</button>
        <div id="sandbox-result-display" style="font-weight: 700; font-size: 0.9rem; margin-left: 8px;"></div>
      </div>
    </div>
    
    <div class="card p-0 mb-5" style="overflow-x: auto;">
      <div class="table-responsive"><table class="table" style="width: 100%; border-collapse: collapse;">
        <thead style="background: var(--color-surface); border-bottom: 2px solid var(--color-border);">
          <tr>
            <th style="padding: 12px 16px; text-align: left;">Code</th>
            <th style="padding: 12px 16px; text-align: left;">Discount</th>
            <th style="padding: 12px 16px; text-align: left;">Min Amount</th>
            <th style="padding: 12px 16px; text-align: left;">Usage</th>
            <th style="padding: 12px 16px; text-align: left;">Status</th>
            <th style="padding: 12px 16px; text-align: left;">Actions</th>
          </tr>
        </thead>
        <tbody id="coupons-tbody">
          <tr><td colspan="6" class="text-center text-muted p-4">Loading coupons...</td></tr>
        </tbody>
      </table></div>
    </div>

    <!-- Coupon Modal -->
    <div id="couponModal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.6); z-index:10000; justify-content:center; align-items:center; padding:1.5rem;">
      <div style="background:var(--color-surface, #1e2230); color: var(--color-text-primary, #fff); border: 1px solid var(--color-border, #333); border-radius:var(--radius-lg, 12px); width:100%; max-width:500px; box-shadow:var(--shadow-xl);">
        <div style="padding: 16px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center;">
          <h4 id="couponModalTitle" style="margin: 0; font-size: 1.2rem; font-weight: 600;">${o("Add Coupon")}</h4>
          <button type="button" id="couponModalClose" style="background:none; border:none; color:var(--color-text-muted, #aaa); font-size: 1.5rem; cursor:pointer; line-height: 1;">&times;</button>
        </div>
        <div style="padding: 20px;">
          <form id="coupon-form">
            <input type="hidden" id="coupon-id">
            
            <div class="mb-3">
              <label class="form-label">Code *</label>
              <input type="text" class="form-control" id="coupon-code" required placeholder="e.g. SUMMER50" style="text-transform: uppercase;">
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Type</label>
                <select class="form-control form-select" id="coupon-discountType">
                  <option value="percentage">Percentage (%)</option>
                  <option value="flat">Flat Amount (\u20B9)</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Value *</label>
                <input type="number" class="form-control" id="coupon-discountValue" required min="0" placeholder="e.g. 10">
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Min Plan Amount</label>
                <input type="number" class="form-control" id="coupon-minPlanAmount" min="0" value="0">
              </div>
              <div class="col-md-6">
                <label class="form-label">Max Discount (\u20B9)</label>
                <input type="number" class="form-control" id="coupon-maxDiscount" min="0" placeholder="Optional">
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Valid Until</label>
                <input type="date" class="form-control" id="coupon-validUntil">
              </div>
              <div class="col-md-6">
                <label class="form-label">Usage Limit</label>
                <input type="number" class="form-control" id="coupon-usageLimit" min="1" value="100">
              </div>
            </div>
            
            <div class="d-flex align-items-center gap-2 mb-3">
              <input type="checkbox" id="coupon-isActive" checked style="cursor: pointer; width: 18px; height: 18px;">
              <label for="coupon-isActive" style="cursor: pointer; margin: 0;">Active</label>
            </div>

            <div style="padding-top: 14px; border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: flex-end; gap: 10px;">
              <button type="button" class="btn btn-secondary" id="couponModalCancel">${o("Cancel")}</button>
              <button type="button" class="btn btn-primary" id="btn-save-coupon">${o("Save Coupon")}</button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Plan Modal -->
    <div id="planModal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.6); z-index:10000; justify-content:center; align-items:center; padding:1.5rem;">
      <div style="background:var(--color-surface, #1e2230); color: var(--color-text-primary, #fff); border: 1px solid var(--color-border, #333); border-radius:var(--radius-lg, 12px); width:100%; max-width:600px; max-height:90vh; overflow-y:auto; box-shadow:var(--shadow-xl);">
        <div style="padding: 16px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center;">
          <h4 id="planModalTitle" style="margin: 0; font-size: 1.2rem; font-weight: 600;">${o("Create Plan")}</h4>
          <button type="button" id="planModalClose" style="background:none; border:none; color:var(--color-text-muted, #aaa); font-size: 1.5rem; cursor:pointer; line-height: 1;">&times;</button>
        </div>
        <div style="padding: 20px;">
          <form id="plan-form">
            <input type="hidden" id="plan-id">
            
            <div class="mb-3">
              <label for="plan-name" class="form-label" style="font-weight: 500;">${o("Plan Name")} *</label>
              <input type="text" class="form-control" id="plan-name" required placeholder="e.g. Monthly Standard, Quarterly Full Day">
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label for="plan-price" class="form-label" style="font-weight: 500;">${o("Price")} (\u20B9) *</label>
                <input type="number" class="form-control" id="plan-price" required min="0" placeholder="e.g. 1500">
              </div>
              <div class="col-md-6">
                <label for="plan-discount" class="form-label" style="font-weight: 500;">${o("Discount")} (%)</label>
                <input type="number" class="form-control" id="plan-discount" min="0" max="100" value="0">
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label for="plan-duration" class="form-label" style="font-weight: 500;">${o("Duration")} *</label>
                <input type="number" class="form-control" id="plan-duration" required min="1" value="30">
              </div>
              <div class="col-md-6">
                <label for="plan-durationType" class="form-label" style="font-weight: 500;">${o("Duration Type")}</label>
                <select class="form-select form-control" id="plan-durationType">
                  <option value="days">${o("Days")}</option>
                  <option value="months">${o("Months")}</option>
                  <option value="years">${o("Years")}</option>
                </select>
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label for="plan-seatType" class="form-label" style="font-weight: 500;">${o("Seat Type")}</label>
                <select class="form-select form-control" id="plan-seatType">
                  <option value="any">${o("Any / All Seats")}</option>
                  <option value="regular">${o("Regular")}</option>
                  <option value="premium">${o("Premium / AC")}</option>
                  <option value="cabin">${o("Private Cabin")}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label for="plan-shift" class="form-label" style="font-weight: 500;">${o("Shift / Timing")}</label>
                <select class="form-select form-control" id="plan-shift">
                  <option value="any">${o("Any Shift (Full Access)")}</option>
                  <option value="morning">${o("Morning Shift")}</option>
                  <option value="evening">${o("Evening Shift")}</option>
                  <option value="fullday">${o("Full Day")}</option>
                  <option value="night">${o("Night Shift")}</option>
                </select>
              </div>
            </div>
            
            <div class="mb-3">
              <label for="plan-description" class="form-label" style="font-weight: 500;">${o("Description")}</label>
              <textarea class="form-control" id="plan-description" rows="2" placeholder="Brief info about this membership..."></textarea>
            </div>
            
            <div class="mb-3">
              <label for="plan-features" class="form-label" style="font-weight: 500;">${o("Features")} (Comma separated)</label>
              <textarea class="form-control" id="plan-features" rows="2" placeholder="High Speed WiFi, RO Water, Dedicated Locker, Power Socket"></textarea>
            </div>
            
            <div class="d-flex align-items-center gap-2 mb-3">
              <input type="checkbox" id="plan-isActive" checked style="cursor: pointer; width: 18px; height: 18px;">
              <label for="plan-isActive" style="cursor: pointer; margin: 0;">${o("Plan is Active (Available for selection)")}</label>
            </div>

            <div style="padding-top: 14px; border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: flex-end; gap: 10px;">
              <button type="button" class="btn btn-secondary" id="planModalCancel">${o("Cancel")}</button>
              <button type="button" class="btn btn-primary" id="btn-save-plan">${o("Save Plan")}</button>
            </div>
          </form>
        </div>
      </div>
    </div>
  `,setTimeout(()=>{E(),I();const e=t.querySelector("#btn-create-coupon");e&&e.addEventListener("click",()=>{const l=t.querySelector("#coupon-form");l&&l.reset(),t.querySelector("#coupon-id").value="",t.querySelector("#coupon-isActive").checked=!0,t.querySelector("#couponModalTitle").textContent=o("Add Coupon"),document.getElementById("couponModal").style.display="flex"});const n=t.querySelector("#btn-save-coupon");n&&n.addEventListener("click",_);const s=t.querySelector("#coupons-tbody");s&&(s.addEventListener("click",l=>{const d=l.target.closest(".btn-edit-coupon");if(d){const r=d.dataset.id;V(r)}const c=l.target.closest(".btn-delete-coupon");if(c){const r=c.dataset.id;j(r)}}),s.addEventListener("change",l=>{if(l.target.classList.contains("coupon-active-toggle")){const d=l.target.dataset.id,c=l.target.checked;N(d,c)}}));const a=t.querySelector("#couponModalClose");a&&a.addEventListener("click",()=>document.getElementById("couponModal").style.display="none");const u=t.querySelector("#couponModalCancel");u&&u.addEventListener("click",()=>document.getElementById("couponModal").style.display="none");const p=t.querySelector("#show-inactive-plans");p&&p.addEventListener("change",E);const y=t.querySelector("#btn-create-plan");y&&y.addEventListener("click",()=>{const l=t.querySelector("#plan-form");l&&l.reset(),t.querySelector("#plan-id").value="",t.querySelector("#plan-isActive").checked=!0,t.querySelector("#planModalTitle").textContent=o("Create New Plan"),C()});const v=t.querySelector("#btn-save-plan");v&&v.addEventListener("click",U),t.querySelector("#btn-test-coupon-sandbox")?.addEventListener("click",()=>{const l=t.querySelector("#sandbox-coupon-code")?.value?.trim()?.toUpperCase(),d=parseFloat(t.querySelector("#sandbox-amount")?.value)||0,c=t.querySelector("#sandbox-result-display");if(!l){c.innerHTML='<span style="color: var(--color-danger);">Please enter a coupon code</span>';return}const r=h.find(g=>g.code.toUpperCase()===l&&g.isActive);if(!r){c.innerHTML='<span style="color: var(--color-danger);">\u274C Invalid or Inactive Coupon Code</span>';return}if(r.minAmount&&d<r.minAmount){c.innerHTML=`<span style="color: #f59e0b;">\u26A0\uFE0F Min order value of \u20B9${r.minAmount} required</span>`;return}let f=0;r.discountType==="percentage"?f=d*r.discountValue/100:f=r.discountValue;const m=Math.max(0,d-f);c.innerHTML=`<span style="color: var(--color-success);">\u{1F7E2} Valid Coupon! Discount: \u20B9${f.toFixed(0)} \u2022 Final Payable: \u20B9${m.toFixed(0)}</span>`});const w=t.querySelector("#plans-grid");w&&(w.addEventListener("click",l=>{const d=l.target.closest(".action-menu-item");if(d){l.preventDefault(),l.stopPropagation();const m=d.dataset.action,g=d.dataset.id;if(m==="edit")S(g);else if(m==="clone")k(g);else if(m==="delete")L(g);else if(m==="toggle-active"){const M=B.find(D=>D._id===g);M&&P(g,!M.isActive)}return}const c=l.target.closest(".btn-clone");if(c){const m=c.dataset.id;k(m)}const r=l.target.closest(".btn-edit");if(r){const m=r.dataset.id;S(m)}const f=l.target.closest(".btn-delete");if(f){const m=f.dataset.id;L(m)}}),w.addEventListener("change",l=>{if(l.target.classList.contains("plan-active-toggle")){const d=l.target.dataset.id,c=l.target.checked;P(d,c)}}));const $=t.querySelector("#planModalClose");$&&$.addEventListener("click",F);const A=t.querySelector("#planModalCancel");A&&A.addEventListener("click",F)},0),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1F4B3}",label:"Plan Actions",color:"var(--color-primary, #6c5ce7)",actions:[{icon:"\u2795",label:"Create Plan",onClick:()=>{C()}},{icon:"\u{1F39F}\uFE0F",label:"Add Coupon",onClick:()=>{showCouponModal()}}]}),t}function C(){const t=document.getElementById("planModal");t&&(t.style.display="flex")}function F(){const t=document.getElementById("planModal");t&&(t.style.display="none")}async function E(){const t=document.getElementById("plans-grid");if(!t)return;t.innerHTML='<div class="text-center p-5 text-muted" style="grid-column: 1 / -1;">Loading plans...</div>';const e=document.getElementById("show-inactive-plans")?.checked?"/api/plans/all":"/api/plans";try{const n=await b.get(e);n.success&&n.data?(B=n.data,H(B)):i.error(n.message)}catch{i.error("Failed to load plans")}}function H(t){const e=document.getElementById("plans-grid");if(!e)return;if(!t||t.length===0){e.innerHTML='<div class="empty-state p-5 text-center text-muted" style="grid-column: 1 / -1;">No plans found. Click "Create Plan" to add your first membership package.</div>';return}const n=new Intl.NumberFormat("en-IN",{style:"currency",currency:"INR",maximumFractionDigits:0});let s="";t.forEach(a=>{const u=a.effectivePrice||a.price*(1-(a.discount||0)/100);let p="";a.features&&a.features.length>0&&(p='<ul style="list-style: none; padding: 0; margin: 16px 0; display: flex; flex-direction: column; gap: 6px;">',a.features.forEach($=>{p+=`<li style="font-size: 0.88rem; display: flex; align-items: center; gap: 8px;"><span style="color: var(--color-success, #00b894);">\u2713</span> ${x($)}</li>`}),p+="</ul>");const y=`${a.duration} ${a.durationType||"days"}`,v=a.discount>0?`<span class="badge" style="position: absolute; top: 12px; right: 12px; background: var(--color-danger, #d63031); color: white; font-weight: 700;">${a.discount}% OFF</span>`:"",w=a.isActive?"":"opacity: 0.6;";s+=`
      <div class="card p-4 position-relative d-flex flex-column" style="${w} border: 1px solid var(--color-border); border-radius: var(--radius-lg, 12px); box-shadow: var(--shadow-sm); min-height: 320px; justify-content: space-between;">
        ${v}
        <div>
          <div class="mb-2">
            <h3 style="margin: 0; font-size: 1.3rem; font-weight: 700; color: var(--color-text-primary);">${x(a.name)}</h3>
            <div class="d-flex gap-1 flex-wrap mt-1">
              <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: var(--color-primary); font-size: 0.75rem; font-weight: 700;">${x(a.seatType||"any")} &bull; ${x(a.shift||"any")}</span>
              <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-size: 0.75rem; font-weight: 700;">\u{1F465} ${a.activeMembersCount||0} Active Members</span>
            </div>
          </div>

          <div class="mb-3">
            <h2 style="margin: 0; font-size: 2rem; font-weight: 800; color: var(--color-primary);">
              ${n.format(u)}
              <small style="font-size: 0.9rem; font-weight: 600; color: var(--color-text-secondary);">/ ${y}</small>
            </h2>
            ${a.discount>0?`<div style="text-decoration: line-through; color: var(--color-text-muted); font-size: 0.85rem; font-weight: 600;">${n.format(a.price)}</div>`:""}
          </div>

          ${a.description?`<p class="text-muted small mb-2">${x(a.description)}</p>`:""}
        </div>
        
        <div style="flex-grow: 1; margin: 12px 0;">
          ${p||'<p class="text-muted small mb-0">Standard study room amenities included.</p>'}
        </div>

        <div style="border-top: 1px solid var(--color-divider); padding-top: 14px; margin-top: 8px;" class="d-flex justify-content-between align-items-center">
          <div class="d-flex align-items-center gap-2">
            <input type="checkbox" class="plan-active-toggle" data-id="${a._id}" ${a.isActive?"checked":""} style="cursor: pointer;">
            <label class="small text-muted" style="margin: 0; font-weight: 600;">Active</label>
          </div>
          <div class="btn-icon-group">
            <button type="button" class="btn-icon-action action-view btn-clone" data-id="${a._id}" data-tooltip="Clone Plan" aria-label="Clone">\u{1F4CB}</button>
            <button type="button" class="btn-icon-action action-edit btn-edit" data-id="${a._id}" data-tooltip="Edit Plan" aria-label="Edit">\u270F\uFE0F</button>
            ${typeof ActionMenu<"u"?ActionMenu.renderHtml([{header:"Level 1: Plan Operations"},{id:"edit",icon:"\u270F\uFE0F",label:"Edit Plan Configuration",bold:!0},{id:"clone",icon:"\u{1F4D1}",label:"Clone / Duplicate Plan"},{divider:!0},{header:"Level 2: Status & Lifecycle"},{id:"toggle-active",icon:a.isActive?"\u23F8\uFE0F":"\u{1F7E2}",label:a.isActive?"Deactivate / Archive":"Activate Plan"},{divider:!0},{header:"Level 3: Danger Zone"},{id:"delete",icon:"\u{1F5D1}\uFE0F",label:"Delete Plan",danger:!0}],a._id):""}
          </div>
        </div>
      </div>
    `}),e.innerHTML=s}function k(t){const e=B.find(n=>n._id===t);e&&(document.getElementById("plan-id").value="",document.getElementById("plan-name").value=`${e.name} (Copy)`,document.getElementById("plan-price").value=e.price,document.getElementById("plan-discount").value=e.discount||0,document.getElementById("plan-duration").value=e.duration,document.getElementById("plan-durationType").value=e.durationType||"days",document.getElementById("plan-seatType").value=e.seatType||"any",document.getElementById("plan-shift").value=e.shift||"any",document.getElementById("plan-description").value=e.description||"",document.getElementById("plan-features").value=e.features?e.features.join(", "):"",document.getElementById("plan-isActive").checked=!0,document.getElementById("planModalTitle").textContent=o("Clone & Create Plan"),C())}function S(t){const e=B.find(n=>n._id===t);e&&(document.getElementById("plan-id").value=e._id,document.getElementById("plan-name").value=e.name,document.getElementById("plan-price").value=e.price,document.getElementById("plan-discount").value=e.discount||0,document.getElementById("plan-duration").value=e.duration,document.getElementById("plan-durationType").value=e.durationType||"days",document.getElementById("plan-seatType").value=e.seatType||"any",document.getElementById("plan-shift").value=e.shift||"any",document.getElementById("plan-description").value=e.description||"",document.getElementById("plan-features").value=e.features?e.features.join(", "):"",document.getElementById("plan-isActive").checked=e.isActive,document.getElementById("planModalTitle").textContent=o("Edit Plan"),C())}async function U(){const t=document.getElementById("plan-form");if(!t.checkValidity()){t.reportValidity();return}const e=document.getElementById("plan-id").value,n=document.getElementById("plan-features").value,s=n?n.split(",").map(y=>y.trim()).filter(Boolean):[],a={name:document.getElementById("plan-name").value,price:parseFloat(document.getElementById("plan-price").value)||0,discount:parseFloat(document.getElementById("plan-discount").value)||0,duration:parseInt(document.getElementById("plan-duration").value,10)||30,durationType:document.getElementById("plan-durationType").value,seatType:document.getElementById("plan-seatType").value,shift:document.getElementById("plan-shift").value,description:document.getElementById("plan-description").value,features:s,isActive:document.getElementById("plan-isActive").checked},u=document.getElementById("btn-save-plan"),p=u.innerHTML;u.innerHTML="Saving...",u.disabled=!0;try{const y=e?`/api/plans/${e}`:"/api/plans",v=await b[e?"put":"post"](y,a);v.success?(i.success(v.message),F(),E()):i.error(v.message)}catch(y){i.error(y.message||"Failed to save plan")}finally{u.innerHTML=p,u.disabled=!1}}async function L(t){T.show({title:"Delete Plan",message:"Are you sure you want to deactivate this membership plan?",danger:!0,onConfirm:async()=>{try{const e=await b.delete(`/api/plans/${t}`);e.success?(i.success(e.message),E()):i.error(e.message)}catch(e){i.error(e.message||"Failed to delete plan")}}})}async function P(t,e){try{const n=await b.put(`/api/plans/${t}`,{isActive:e});n.success?i.success("Plan status updated"):(i.error(n.message),E())}catch{i.error("Failed to update plan status"),E()}}async function I(){if(document.getElementById("coupons-tbody"))try{const t=await b.get("/api/coupons");t.success&&(h=t.coupons,z())}catch(t){console.error(t)}}function z(){const t=document.getElementById("coupons-tbody");if(!t)return;if(!h||h.length===0){t.innerHTML='<tr><td colspan="6" class="text-center text-muted p-4">No coupons found.</td></tr>';return}let e="";h.forEach(n=>{const s=n.discountType==="percentage"?`${n.discountValue}%`:`\u20B9${n.discountValue}`,a=n.validUntil?new Date(n.validUntil).toLocaleDateString():"Never";e+=`
      <tr style="border-bottom: 1px solid var(--color-border);">
        <td style="padding: 12px 16px; font-weight: 700; color: var(--color-primary);">${x(n.code)}</td>
        <td style="padding: 12px 16px;">${s}</td>
        <td style="padding: 12px 16px;">\u20B9${n.minPlanAmount}</td>
        <td style="padding: 12px 16px;">${n.usedCount} / ${n.usageLimit}</td>
        <td style="padding: 12px 16px;">
          <input type="checkbox" class="coupon-active-toggle" data-id="${n._id}" ${n.isActive?"checked":""} style="cursor: pointer;">
        </td>
        <td style="padding: 12px 16px;">
          <div class="btn-icon-group">
            <button type="button" class="btn-icon-action action-edit btn-edit-coupon" data-id="${n._id}" data-tooltip="Edit Coupon" aria-label="Edit">\u270F\uFE0F</button>
            <button type="button" class="btn-icon-action action-delete btn-delete-coupon" data-id="${n._id}" data-tooltip="Delete Coupon" aria-label="Delete">\u{1F5D1}\uFE0F</button>
          </div>
        </td>
      </tr>
    `}),t.innerHTML=e}function V(t){const e=h.find(n=>n._id===t);e&&(document.getElementById("coupon-id").value=e._id,document.getElementById("coupon-code").value=e.code,document.getElementById("coupon-discountType").value=e.discountType,document.getElementById("coupon-discountValue").value=e.discountValue,document.getElementById("coupon-minPlanAmount").value=e.minPlanAmount||0,document.getElementById("coupon-maxDiscount").value=e.maxDiscount||"",e.validUntil?document.getElementById("coupon-validUntil").value=new Date(e.validUntil).toISOString().split("T")[0]:document.getElementById("coupon-validUntil").value="",document.getElementById("coupon-usageLimit").value=e.usageLimit||100,document.getElementById("coupon-isActive").checked=e.isActive,document.getElementById("couponModalTitle").textContent=o("Edit Coupon"),document.getElementById("couponModal").style.display="flex")}async function _(){const t=document.getElementById("coupon-form");if(!t.checkValidity()){t.reportValidity();return}const e=document.getElementById("coupon-id").value,n={code:document.getElementById("coupon-code").value.toUpperCase(),discountType:document.getElementById("coupon-discountType").value,discountValue:parseFloat(document.getElementById("coupon-discountValue").value),minPlanAmount:parseFloat(document.getElementById("coupon-minPlanAmount").value)||0,maxDiscount:document.getElementById("coupon-maxDiscount").value?parseFloat(document.getElementById("coupon-maxDiscount").value):null,validUntil:document.getElementById("coupon-validUntil").value||null,usageLimit:parseInt(document.getElementById("coupon-usageLimit").value)||100,isActive:document.getElementById("coupon-isActive").checked},s=document.getElementById("btn-save-coupon"),a=s.innerHTML;s.innerHTML="Saving...",s.disabled=!0;try{const u=e?`/api/coupons/${e}`:"/api/coupons",p=await b[e?"put":"post"](u,n);p.success?(i.success("Coupon saved successfully"),document.getElementById("couponModal").style.display="none",I()):i.error(p.message)}catch{i.error("Failed to save coupon")}finally{s.innerHTML=a,s.disabled=!1}}async function j(t){T.show({title:"Delete Coupon",message:"Are you sure you want to delete this coupon?",danger:!0,onConfirm:async()=>{try{const e=await b.delete(`/api/coupons/${t}`);e.success?(i.success("Coupon deleted"),I()):i.error(e.message)}catch{i.error("Failed to delete coupon")}}})}async function N(t,e){try{const n=await b.put(`/api/coupons/${t}`,{isActive:e});n.success||(i.error(n.message),I())}catch{i.error("Failed to update status"),I()}}export{q as render};
