import g from"../api.js";import{Toast as i,Modal as F,escapeHTML as b}from"../ui.js";let d="all",v="",f=1,c=new Set;const $={all:{label:"All Items",icon:"\u{1F4CB}",color:"#6c5ce7"},student:{label:"Students",icon:"\u{1F393}",color:"#3b82f6"},payment:{label:"Payments & Receipts",icon:"\u{1F4B3}",color:"#10b981"},expense:{label:"Expenses",icon:"\u{1F4B8}",color:"#ef4444"},seat:{label:"Desks / Seats",icon:"\u{1F4BA}",color:"#8b5cf6"},plan:{label:"Membership Plans",icon:"\u{1F48E}",color:"#f59e0b"},shift:{label:"Study Shifts",icon:"\u23F0",color:"#06b6d4"},branch:{label:"Branches",icon:"\u{1F3E2}",color:"#ec4899"},locker:{label:"Lockers",icon:"\u{1F512}",color:"var(--color-text-muted)"},custom_field:{label:"Custom Questions",icon:"\u{1F4DD}",color:"#14b8a6"},coupon:{label:"Coupons / Promos",icon:"\u{1F39F}\uFE0F",color:"#f97316"},waiting_list:{label:"Waitlist",icon:"\u23F3",color:"#a855f7"},announcement:{label:"Notices",icon:"\u{1F4E2}",color:"#eab308"},holiday:{label:"Holidays",icon:"\u{1F3D6}\uFE0F",color:"#06b6d4"},visitor:{label:"Visitors",icon:"\u{1F465}",color:"var(--color-text-muted)"},lost_found:{label:"Lost & Found",icon:"\u{1F50D}",color:"#f43f5e"},feedback:{label:"Feedback",icon:"\u{1F4AC}",color:"#8b5cf6"}};async function E(e){e&&(c.clear(),f=1,e.innerHTML=`
    <div class="trash-studio-container" style="width: 100%; max-width: 100%; box-sizing: border-box;">
      <!-- Header Banner -->
      <div class="card mb-4" style="background: linear-gradient(135deg, rgba(239, 68, 68, 0.08), rgba(108, 92, 231, 0.08)); border-left: 4px solid var(--color-danger, #ef4444); width: 100%; box-sizing: border-box;">
        <div class="card-body" style="padding: 1.25rem 1.5rem;">
          <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
            <div>
              <h2 style="font-size: 1.35rem; font-weight: 800; color: var(--color-text-primary); margin: 0 0 4px 0;">
                \u{1F5D1}\uFE0F Recycle Bin & Trash Management
              </h2>
              <p class="text-muted" style="margin: 0; font-size: 0.88rem;">
                Safely inspect, restore, or permanently remove deleted student records, desks, receipts, plans, and settings.
              </p>
            </div>
            <div class="d-flex gap-2 flex-wrap">
              <button class="btn btn-outline-primary btn-sm" id="trash-bulk-restore-btn" style="display: none;">
                \u267B\uFE0F Restore Selected (<span id="trash-selected-count">0</span>)
              </button>
              <button class="btn btn-outline-danger btn-sm" id="trash-bulk-delete-btn" style="display: none;">
                \u{1F4A5} Delete Selected (<span id="trash-selected-delete-count">0</span>)
              </button>
              <button class="btn btn-danger btn-sm" id="trash-empty-btn" style="font-weight: 700;">
                \u{1F9F9} Empty Recycle Bin
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Category Filter Tabs -->
      <div class="card mb-4" style="width: 100%; box-sizing: border-box;">
        <div class="card-body" style="padding: 0.85rem 1rem;">
          <div class="d-flex gap-2 flex-wrap" id="trash-category-tabs" style="width: 100%;">
            <button class="btn btn-sm ${d==="all"?"btn-primary":"btn-ghost"}" data-tab="all">
              \u{1F4CB} All Items <span class="badge badge-secondary" id="count-all">...</span>
            </button>
            <button class="btn btn-sm ${d==="student"?"btn-primary":"btn-ghost"}" data-tab="student">
              \u{1F393} Students <span class="badge badge-secondary" id="count-student">0</span>
            </button>
            <button class="btn btn-sm ${d==="payment"?"btn-primary":"btn-ghost"}" data-tab="payment">
              \u{1F4B3} Payments <span class="badge badge-secondary" id="count-payment">0</span>
            </button>
            <button class="btn btn-sm ${d==="expense"?"btn-primary":"btn-ghost"}" data-tab="expense">
              \u{1F4B8} Expenses <span class="badge badge-secondary" id="count-expense">0</span>
            </button>
            <button class="btn btn-sm ${d==="seat"?"btn-primary":"btn-ghost"}" data-tab="seat">
              \u{1F4BA} Desks <span class="badge badge-secondary" id="count-seat">0</span>
            </button>
            <button class="btn btn-sm ${d==="plan"?"btn-primary":"btn-ghost"}" data-tab="plan">
              \u{1F48E} Plans <span class="badge badge-secondary" id="count-plan">0</span>
            </button>
            <button class="btn btn-sm ${d==="shift"?"btn-primary":"btn-ghost"}" data-tab="shift">
              \u23F0 Shifts <span class="badge badge-secondary" id="count-shift">0</span>
            </button>
            <button class="btn btn-sm ${d==="branch"?"btn-primary":"btn-ghost"}" data-tab="branch">
              \u{1F3E2} Branches <span class="badge badge-secondary" id="count-branch">0</span>
            </button>
            <button class="btn btn-sm ${d==="locker"?"btn-primary":"btn-ghost"}" data-tab="locker">
              \u{1F512} Lockers <span class="badge badge-secondary" id="count-locker">0</span>
            </button>
            <button class="btn btn-sm ${d==="custom_field"?"btn-primary":"btn-ghost"}" data-tab="custom_field">
              \u{1F4DD} Custom Fields <span class="badge badge-secondary" id="count-custom_field">0</span>
            </button>
            <button class="btn btn-sm ${d==="coupon"?"btn-primary":"btn-ghost"}" data-tab="coupon">
              \u{1F39F}\uFE0F Coupons <span class="badge badge-secondary" id="count-coupon">0</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Search & Data Table -->
      <div class="card" style="width: 100%; box-sizing: border-box;">
        <div class="card-body" style="padding: 1.25rem;">
          <!-- Toolbar -->
          <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2" style="width: 100%;">
            <div style="flex: 1 1 300px; min-width: 240px; position: relative;">
              <input type="text" id="trash-search-input" class="form-control form-control-sm w-100" placeholder="\u{1F50D} Search deleted records by title, phone, user..." value="${b(v)}" style="padding-left: 2rem;">
              <span style="position: absolute; left: 10px; top: 50%; transform: translateY(-50%); opacity: 0.5;">\u{1F50D}</span>
            </div>
            <div class="text-muted" style="font-size: 0.85rem;" id="trash-meta-info">
              Loading records...
            </div>
          </div>

          <!-- Items Table Container -->
          <div id="trash-table-container" style="width: 100%; overflow-x: auto;">
            <div style="padding: 3rem 1rem; text-align: center; color: var(--color-text-secondary);">
              <div class="spinner-border spinner-border-sm text-primary mb-2"></div>
              <div>Fetching deleted records...</div>
            </div>
          </div>

          <!-- Pagination Container -->
          <div id="trash-pagination-container" class="d-flex justify-content-between align-items-center mt-3 pt-3" style="border-top: 1px solid var(--color-border, #e2e8f0); display: none; width: 100%;"></div>
        </div>
      </div>
    </div>
  `,A(e),h(),p())}function A(e){const a=e.querySelectorAll("#trash-category-tabs button");a.forEach(r=>{r.addEventListener("click",()=>{a.forEach(u=>{u.classList.remove("btn-primary"),u.classList.add("btn-ghost")}),r.classList.add("btn-primary"),r.classList.remove("btn-ghost"),d=r.getAttribute("data-tab")||"all",f=1,c.clear(),y(),p()})});const t=e.querySelector("#trash-search-input");if(t){let r;t.addEventListener("input",()=>{clearTimeout(r),r=setTimeout(()=>{v=t.value.trim(),f=1,p()},250)})}const n=e.querySelector("#trash-bulk-restore-btn");n&&n.addEventListener("click",C);const s=e.querySelector("#trash-bulk-delete-btn");s&&s.addEventListener("click",S);const l=e.querySelector("#trash-empty-btn");l&&l.addEventListener("click",L)}async function h(){try{const e=await g.get("/api/trash/counts");if(e.success&&e.data){Object.keys(e.data).forEach(t=>{const n=document.getElementById(`count-${t}`);n&&(n.textContent=e.data[t]||0)});const a=document.getElementById("count-all");a&&(a.textContent=e.data.all||0)}}catch{}}async function p(){const e=document.getElementById("trash-table-container"),a=document.getElementById("trash-meta-info"),t=document.getElementById("trash-pagination-container");if(e)try{const n=new URLSearchParams({type:d,search:v,page:f,limit:20}),s=await g.get(`/api/trash?${n.toString()}`);if(!s.success||!s.data)throw new Error(s.message||"Failed to fetch items");const{items:l,total:r,totalPages:u}=s.data;if(a&&(a.textContent=r===1?"1 deleted item":`${r} deleted items`),l.length===0){e.innerHTML=`
        <div style="padding: 4rem 1rem; text-align: center; color: var(--color-text-secondary);">
          <div style="font-size: 3rem; margin-bottom: 0.75rem;">\u2728</div>
          <h4 style="font-weight: 600; color: var(--color-text-primary); margin-bottom: 4px;">Recycle Bin is Clean</h4>
          <p style="font-size: 0.88rem; max-width: 450px; margin: 0 auto;">
            ${v?"No deleted records match your search criteria.":"There are no deleted items in this category. Any deleted items will appear here for safe recovery."}
          </p>
        </div>
      `,t&&(t.style.display="none");return}e.innerHTML=`
      <div class="desktop-table-view">
        <div class="table-responsive">
          <table class="table data-table" style="width: 100%; border-collapse: collapse;">
            <thead>
              <tr style="border-bottom: 2px solid var(--color-border, #e2e8f0); text-align: left; font-size: 0.8rem; color: var(--color-text-secondary); text-transform: uppercase;">
                <th style="width: 40px; text-align: center;">
                  <input type="checkbox" id="trash-select-all" title="Select All">
                </th>
                <th>Item / Record</th>
                <th>Category</th>
                <th>Deleted By</th>
                <th>Deleted Timestamp</th>
                <th style="text-align: right; min-width: 160px;">Actions</th>
              </tr>
            </thead>
            <tbody>
              ${l.map(o=>{const m=$[o.itemType]||{label:o.itemType,icon:"\u{1F4E6}",color:"var(--color-text-muted)"},x=w(o.deletedAt),k=c.has(o._id);return`
                  <tr data-id="${o._id}" style="border-bottom: 1px solid var(--color-border, #f1f5f9); vertical-align: middle;">
                    <td style="text-align: center;">
                      <input type="checkbox" class="trash-item-checkbox" data-id="${o._id}" ${k?"checked":""}>
                    </td>
                    <td style="padding: 10px 8px;">
                      <div class="d-flex align-items-center gap-2">
                        <span style="font-size: 1.25rem;">${m.icon}</span>
                        <div>
                          <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.92rem;">
                            ${b(o.itemTitle||"Untitled Record")}
                          </div>
                          ${o.itemSubtitle?`<div style="font-size: 0.78rem; color: var(--color-text-secondary);">${b(o.itemSubtitle)}</div>`:""}
                        </div>
                      </div>
                    </td>
                    <td>
                      <span class="badge" style="background: ${m.color}15; color: ${m.color}; font-weight: 600; font-size: 0.75rem;">
                        ${m.icon} ${m.label}
                      </span>
                    </td>
                    <td style="font-size: 0.85rem; color: var(--color-text-primary);">
                      \u{1F464} ${b(o.deletedByName||"Admin")}
                    </td>
                    <td style="font-size: 0.82rem; color: var(--color-text-secondary);" title="${new Date(o.deletedAt).toLocaleString()}">
                      \u{1F552} ${x}
                    </td>
                    <td style="text-align: right; padding-right: 8px;">
                      <div class="d-flex gap-2 justify-content-end">
                        <button class="btn btn-sm btn-outline-success restore-item-btn" data-id="${o._id}" data-title="${b(o.itemTitle)}" title="Restore Record">
                          \u267B\uFE0F Restore
                        </button>
                        <button class="btn btn-sm btn-outline-danger hard-delete-btn" data-id="${o._id}" data-title="${b(o.itemTitle)}" title="Permanently Destroy Record">
                          \u{1F4A5} Hard Delete
                        </button>
                      </div>
                    </td>
                  </tr>
                `}).join("")}
            </tbody>
          </table>
        </div>
      </div>

      <!-- Mobile Card List View -->
      <div class="mobile-card-list">
        ${l.map(o=>{const m=$[o.itemType]||{label:o.itemType,icon:"\u{1F4E6}",color:"var(--color-text-muted)"},x=w(o.deletedAt);return`
            <div class="mobile-data-card" data-id="${o._id}">
              <div class="mobile-card-header">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <span style="font-size: 1.3rem;">${m.icon}</span>
                  <div>
                    <div class="mobile-card-title">${b(o.itemTitle||"Untitled Record")}</div>
                    ${o.itemSubtitle?`<div class="mobile-card-subtitle">${b(o.itemSubtitle)}</div>`:""}
                  </div>
                </div>
                <span class="badge" style="background: ${m.color}15; color: ${m.color}; font-weight: 700; font-size: 0.72rem;">
                  ${m.label}
                </span>
              </div>
              <div class="mobile-card-details">
                <div class="mobile-card-detail">
                  <div class="mobile-card-detail-label">Deleted By</div>
                  <div class="mobile-card-detail-value">\u{1F464} ${b(o.deletedByName||"Admin")}</div>
                </div>
                <div class="mobile-card-detail">
                  <div class="mobile-card-detail-label">Deleted Time</div>
                  <div class="mobile-card-detail-value">\u{1F552} ${x}</div>
                </div>
              </div>
              <div class="mobile-card-actions">
                <button class="btn btn-sm btn-outline-success restore-item-btn" data-id="${o._id}" data-title="${b(o.itemTitle)}" style="min-height: 42px; flex: 1; font-weight: 700;">
                  \u267B\uFE0F Restore
                </button>
                <button class="btn btn-sm btn-outline-danger hard-delete-btn" data-id="${o._id}" data-title="${b(o.itemTitle)}" style="min-height: 42px; flex: 1; font-weight: 700;">
                  \u{1F4A5} Destroy
                </button>
              </div>
            </div>
          `}).join("")}
      </div>
    `,B(e,l,u)}catch(n){e.innerHTML=`
      <div style="padding: 2rem; text-align: center; color: var(--color-danger);">
        \u26A0\uFE0F Failed to load trash items: ${b(n.message)}
      </div>
    `}}function B(e,a,t){const n=e.querySelector("#trash-select-all");if(n){const s=e.querySelectorAll(".trash-item-checkbox"),l=s.length>0&&Array.from(s).every(r=>r.checked);n.checked=l,n.addEventListener("change",()=>{s.forEach(r=>{r.checked=n.checked;const u=r.getAttribute("data-id");n.checked?c.add(u):c.delete(u)}),y()})}e.querySelectorAll(".trash-item-checkbox").forEach(s=>{s.addEventListener("change",()=>{const l=s.getAttribute("data-id");s.checked?c.add(l):c.delete(l);const r=e.querySelectorAll(".trash-item-checkbox");n&&(n.checked=r.length>0&&Array.from(r).every(u=>u.checked)),y()})}),e.querySelectorAll(".restore-item-btn").forEach(s=>{s.addEventListener("click",async()=>{const l=s.getAttribute("data-id"),r=s.getAttribute("data-title");await T(l,r)})}),e.querySelectorAll(".hard-delete-btn").forEach(s=>{s.addEventListener("click",()=>{const l=s.getAttribute("data-id"),r=s.getAttribute("data-title");D(l,r)})})}function y(){const e=document.getElementById("trash-bulk-restore-btn"),a=document.getElementById("trash-selected-count"),t=document.getElementById("trash-bulk-delete-btn"),n=document.getElementById("trash-selected-delete-count"),s=c.size;a&&(a.textContent=s),n&&(n.textContent=s),e&&(e.style.display=s>0?"inline-flex":"none"),t&&(t.style.display=s>0?"inline-flex":"none")}async function T(e,a){try{const t=await g.post(`/api/trash/restore/${e}`);t.success?(i.success(t.message||`"${a}" restored successfully!`),c.delete(e),y(),h(),p()):i.error(t.message||"Failed to restore item")}catch(t){i.error(t.message||"Restore error")}}async function C(){const e=Array.from(c);if(e.length!==0)try{const a=await g.post("/api/trash/restore-bulk",{ids:e});a.success?(i.success(a.message||`Restored ${e.length} items successfully!`),c.clear(),y(),h(),p()):i.error(a.message||"Failed to restore selected items")}catch(a){i.error(a.message||"Bulk restore error")}}async function S(){const e=Array.from(c);e.length!==0&&F.show({title:"\u26A0\uFE0F Permanent Bulk Deletion Warning",content:`
      <div style="padding: 0.5rem 0;">
        <div class="alert alert-danger" style="background: rgba(239, 68, 68, 0.1); border: 1px solid var(--color-danger, #ef4444); color: #b91c1c; border-radius: 8px; padding: 12px 16px; margin-bottom: 1rem; font-size: 0.88rem;">
          <strong>CAUTION:</strong> You are about to permanently delete <strong>${e.length} selected items</strong>! These records will be completely removed from the database and cannot be recovered.
        </div>
        <p style="font-size: 0.95rem; color: var(--color-text-primary);">
          Are you sure you want to permanently delete these ${e.length} items?
        </p>
      </div>
    `,buttons:[{text:"Cancel",className:"btn-ghost",onClick:a=>a.close()},{text:`\u{1F4A5} Yes, Permanently Delete (${e.length})`,className:"btn-danger",onClick:async a=>{try{const t=await g.post("/api/trash/delete-bulk",{ids:e});a.close(),t.success?(i.success(t.message||`Permanently removed ${e.length} items.`),c.clear(),y(),h(),p()):i.error(t.message||"Failed to delete selected items")}catch(t){a.close(),i.error(t.message||"Bulk delete error")}}}]})}function D(e,a){F.show({title:"\u26A0\uFE0F Permanent Deletion Warning",content:`
      <div style="padding: 0.5rem 0;">
        <div class="alert alert-danger" style="background: rgba(239, 68, 68, 0.1); border: 1px solid var(--color-danger, #ef4444); color: #b91c1c; border-radius: 8px; padding: 12px 16px; margin-bottom: 1rem; font-size: 0.88rem;">
          <strong>CAUTION:</strong> This action CANNOT be undone! The record will be permanently purged from MongoDB and cannot be recovered.
        </div>
        <p style="font-size: 0.95rem; color: var(--color-text-primary); margin-bottom: 0.5rem;">
          Are you sure you want to permanently erase:
        </p>
        <div style="background: var(--color-bg-secondary, #f8fafc); padding: 10px 14px; border-radius: 6px; font-weight: 700; color: var(--color-danger); margin-bottom: 1rem;">
          \u{1F5D1}\uFE0F ${b(a)}
        </div>
      </div>
    `,buttons:[{text:"Cancel",className:"btn-ghost",onClick:t=>t.close()},{text:"\u{1F4A5} Yes, Permanently Delete",className:"btn-danger",onClick:async t=>{try{const n=await g.delete(`/api/trash/permanent/${e}`);t.close(),n.success?(i.info(`"${a}" permanently deleted.`),c.delete(e),y(),h(),p()):i.error(n.message||"Failed to permanently delete")}catch(n){t.close(),i.error(n.message||"Deletion failed")}}}]})}function L(){const e=$[d]?.label||"All Items";F.show({title:"\u{1F9F9} Empty Recycle Bin Confirmation",content:`
      <div style="padding: 0.5rem 0;">
        <div class="alert alert-danger" style="background: rgba(239, 68, 68, 0.1); border: 1px solid var(--color-danger, #ef4444); color: #b91c1c; border-radius: 8px; padding: 12px 16px; margin-bottom: 1rem; font-size: 0.88rem;">
          <strong>CRITICAL WARNING:</strong> You are about to permanently destroy all items in <strong>${b(e)}</strong>! Once emptied, these records are permanently gone forever.
        </div>
        <p style="font-size: 0.95rem; color: var(--color-text-primary);">
          Are you completely certain you want to proceed?
        </p>
      </div>
    `,buttons:[{text:"Cancel",className:"btn-ghost",onClick:a=>a.close()},{text:"\u{1F4A5} Yes, Empty Trash",className:"btn-danger",onClick:async a=>{try{const t=await g.delete(`/api/trash/empty?type=${d}`);a.close(),t.success?(i.success(t.message||"Recycle Bin emptied successfully"),c.clear(),y(),h(),p()):i.error(t.message||"Failed to empty recycle bin")}catch(t){a.close(),i.error(t.message||"Empty trash failed")}}}]})}function w(e){if(!e)return"Recently";const a=new Date(e),t=Date.now()-a.getTime(),n=Math.floor(t/1e3),s=Math.floor(n/60),l=Math.floor(s/60),r=Math.floor(l/24);return n<60?"Just now":s<60?`${s}m ago`:l<24?`${l}h ago`:r<30?`${r}d ago`:a.toLocaleDateString()}export{E as render};
