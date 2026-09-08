import c from"../api.js";import{Toast as i,Modal as h,Confirm as F,Loading as k,escapeHTML as a}from"../ui.js";import"../mediaStudio.js";import"../i18n.js";async function M(){const w=document.createElement("div");w.className="page-container",w.innerHTML=`
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>\u{1F4E2} Library Operations & Community Suite</h2>
        <p>Manage walk-in visitors, digital notice board, holiday calendars, lost & found, and student feedback.</p>
      </div>
    </div>

    <!-- Contextual Guidance Tip Banner -->
    <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
      <span style="font-size: 1.1rem;">\u{1F4A1}</span>
      <span><strong>Tip:</strong> When a shift reaches max capacity, walk-in candidates are automatically queued here. Convert them to active admissions in 1 click when a seat clears.</span>
    </div>

    <!-- Tabs Navigation -->
    <div style="border-bottom: 1px solid var(--color-border); margin-bottom: 1.5rem; overflow-x: auto;">
      <div style="display: flex; gap: 0.5rem; min-width: max-content;">
        <button class="ops-tab-btn active" data-tab="visitors" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 600; background: none; border: none; border-bottom: 3px solid var(--color-primary); color: var(--color-primary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F4CB}</span> Visitor & Inquiry Leads
        </button>
        <button class="ops-tab-btn" data-tab="notices" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F4E2}</span> Notice Board
        </button>
        <button class="ops-tab-btn" data-tab="holidays" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F4C5}</span> Holiday Calendar
        </button>
        <button class="ops-tab-btn" data-tab="lostfound" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F50D}</span> Lost & Found
        </button>
        <button class="ops-tab-btn" data-tab="feedback" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F4AC}</span> Student Feedback
        </button>
        <button class="ops-tab-btn" data-tab="leaves" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F334}</span> Leave Requests
        </button>
        <button class="ops-tab-btn" data-tab="waitinglist" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u23F3</span> Waiting List Queue
        </button>
        <button class="ops-tab-btn" data-tab="seatchanges" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F4BA}</span> Seat Changes
        </button>
        <button class="ops-tab-btn" data-tab="referrals" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>\u{1F381}</span> Student Referrals
        </button>
      </div>
    </div>

    <!-- Tab Panels Container -->
    <div id="ops-panel-content">
      <div class="text-center p-5 text-muted">Loading operations...</div>
    </div>
  `;const A=w.querySelectorAll(".ops-tab-btn");let v="visitors";A.forEach(t=>{t.addEventListener("click",()=>{v=t.dataset.tab,A.forEach(d=>{const e=d===t;d.style.borderBottomColor=e?"var(--color-primary)":"transparent",d.style.color=e?"var(--color-primary)":"var(--color-text-secondary)",d.style.fontWeight=e?"600":"500"}),u()})});async function u(){const t=w.querySelector("#ops-panel-content");t.innerHTML='<div class="text-center p-5 text-muted"><div class="loading-spinner mb-2"></div>Loading data...</div>',v==="visitors"?await q(t):v==="waitinglist"?await T(t):v==="notices"?await N(t):v==="holidays"?await C(t):v==="lostfound"?await L(t):v==="feedback"?await D(t):v==="leaves"?await z(t):v==="seatchanges"?await R(t):v==="referrals"&&await j(t)}async function q(t){try{const d=(await c.get("/api/operations/visitors")).data||[];t.innerHTML=`
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">\u{1F4CB} Walk-in Visitors & Inquiry Leads (${d.length})</h3>
          <button id="btn-add-visitor" class="btn btn-primary btn-sm">+ Log New Visitor</button>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Visitor Name</th>
                  <th style="padding: 12px 16px;">Phone</th>
                  <th style="padding: 12px 16px;">Target Exam</th>
                  <th style="padding: 12px 16px;">Preferred Shift</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Date</th>
                  <th style="padding: 12px 16px;">Action</th>
                </tr>
              </thead>
              <tbody>
                ${d.length>0?d.map(e=>`
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;"><strong>${a(e.name)}</strong></td>
                    <td style="padding: 12px 16px;">${a(e.phone)}</td>
                    <td style="padding: 12px 16px;"><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary);">${a(e.targetExam||"General")}</span></td>
                    <td style="padding: 12px 16px;">${a(e.preferredSlot||"Full Day")}</td>
                    <td style="padding: 12px 16px;"><span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); text-transform: uppercase;">${a(e.status)}</span></td>
                    <td style="padding: 12px 16px;">${new Date(e.createdAt).toLocaleDateString("en-IN")}</td>
                    <td style="padding: 12px 16px;">
                      <div class="btn-icon-group">
                        <button type="button" class="btn-icon-action action-verify btn-convert-visitor" data-name="${a(e.name)}" data-phone="${a(e.phone)}" data-exam="${a(e.targetExam||"")}" data-slot="${a(e.preferredSlot||"")}" data-tooltip="Convert Lead to Admission" aria-label="Convert Lead">
                          \u{1F393}
                        </button>
                        <a href="https://wa.me/91${a(e.phone)}?text=${encodeURIComponent(`Hello ${e.name}! Greetings from ${window.store?.settings?.businessName||"our Study Library"}. Desks are available for your ${e.targetExam||"study"} preparation. Visit us to reserve your seat today!`)}" target="_blank" class="btn-icon-action action-whatsapp" data-tooltip="Send WhatsApp Invitation" aria-label="WhatsApp">
                          \u{1F4AC}
                        </a>
                        <button type="button" class="btn-icon-action action-delete btn-delete-visitor" data-id="${e._id}" data-tooltip="Delete Visitor Lead" aria-label="Delete">\u{1F5D1}\uFE0F</button>
                      </div>
                    </td>
                  </tr>
                `).join(""):`
                  <tr><td colspan="7" class="p-4 text-center text-muted">No visitors logged yet. Click "+ Log New Visitor" to record walk-in leads.</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `,t.querySelectorAll(".btn-convert-visitor").forEach(e=>{e.addEventListener("click",()=>{const n=e.dataset.name;window.location.hash="#/students",i.info(`Converting lead ${n} into active student admission.`)})}),t.querySelector("#btn-add-visitor")?.addEventListener("click",()=>{const e=`
          <form id="visitorForm">
            <div class="row" style="row-gap: 12px;">
              <div class="col-md-6">
                <label class="form-label">Full Name *</label>
                <input type="text" class="form-control" name="name" required placeholder="e.g. Vikas Patil">
              </div>
              <div class="col-md-6">
                <label class="form-label">Phone Number *</label>
                <input type="tel" class="form-control" name="phone" required placeholder="10 digit mobile">
              </div>
              <div class="col-md-6">
                <label class="form-label">Target Exam</label>
                <input type="text" class="form-control" name="targetExam" placeholder="e.g. UPSC / MPSC">
              </div>
              <div class="col-md-6">
                <label class="form-label">Preferred Shift Slot</label>
                <select class="form-select form-control" name="preferredSlot">
                  <option value="Morning">Morning (06:00 - 14:00)</option>
                  <option value="Evening">Evening (14:00 - 22:00)</option>
                  <option value="Full Day" selected>Full Day (06:00 - 22:00)</option>
                  <option value="Night">Night (22:00 - 06:00)</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Inquiry Notes</label>
                <textarea class="form-control" name="notes" rows="2" placeholder="Notes on seat preference, demo trial..."></textarea>
              </div>
            </div>
          </form>
        `;new h({title:"Log New Walk-In Visitor",content:e,size:"md",buttons:[{text:"Cancel",className:"btn-secondary",onClick:n=>n.close()},{text:"Save Visitor",className:"btn-primary",onClick:async n=>{const o=n.element.querySelector("#visitorForm");if(!o.checkValidity()){o.reportValidity();return}const r=Object.fromEntries(new FormData(o).entries());try{const s=await c.post("/api/operations/visitors",r);s.success&&(i.success(s.message),n.close(),u())}catch(s){i.error(s.message)}}}]}).show()}),t.querySelectorAll(".btn-delete-visitor").forEach(e=>{e.addEventListener("click",async()=>{if(await F.show({title:"Delete Visitor Record",message:"Are you sure you want to remove this inquiry?",danger:!0}))try{await c.delete(`/api/operations/visitors/${e.dataset.id}`),i.success("Visitor removed"),u()}catch(n){i.error(n.message||"Failed to remove visitor")}})})}catch{t.innerHTML='<div class="text-danger p-4">Failed to load visitors</div>'}}async function N(t){try{const d=(await c.get("/api/operations/announcements")).data||[];t.innerHTML=`
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">\u{1F4E2} Digital Notice Board (${d.length})</h3>
          <button id="btn-add-notice" class="btn btn-primary btn-sm">+ Post New Notice</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
          ${d.length>0?d.map(e=>`
            <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); position: relative;">
              <div class="d-flex justify-content-between align-items-start mb-2">
                <span class="badge" style="background: ${e.priority==="urgent"?"rgba(214,48,49,0.2)":"rgba(108,92,231,0.15)"}; color: ${e.priority==="urgent"?"var(--color-danger)":"var(--color-primary)"}; font-weight: 700; text-transform: uppercase; font-size: 0.7rem;">
                  ${a(e.category)} \u2022 ${a(e.priority)}
                </span>
                <button type="button" class="btn-icon-action action-delete btn-delete-notice" data-id="${e._id}" data-tooltip="Delete Notice Broadcast" aria-label="Delete">\u{1F5D1}\uFE0F</button>
              </div>
              <h4 style="margin: 0 0 8px 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary);">${a(e.title)}</h4>
              <p style="margin: 0 0 12px 0; font-size: 0.88rem; color: var(--color-text-secondary); line-height: 1.5;">${a(e.message)}</p>
              <div class="text-muted small" style="font-size: 0.75rem;">Posted on ${new Date(e.createdAt).toLocaleDateString("en-IN")}</div>
            </div>
          `).join(""):`
            <div class="col-12 p-5 text-center text-muted card" style="grid-column: 1/-1;">No notices published. Click "+ Post New Notice" to broadcast to members.</div>
          `}
        </div>
      `,t.querySelector("#btn-add-notice")?.addEventListener("click",()=>{const e=`
          <form id="noticeForm">
            <div class="form-group mb-3">
              <label class="form-label">Notice Title *</label>
              <input type="text" class="form-control" name="title" required placeholder="e.g. WiFi Maintenance on Sunday 6 AM">
            </div>
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Category</label>
                <select class="form-select form-control" name="category">
                  <option value="general">General Announcement</option>
                  <option value="holiday">Holiday Notice</option>
                  <option value="rules">Library Rules</option>
                  <option value="exam_alert">Exam Schedule</option>
                  <option value="maintenance">Facility Maintenance</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Priority</label>
                <select class="form-select form-control" name="priority">
                  <option value="normal">Normal</option>
                  <option value="high">Important (High)</option>
                  <option value="urgent">Urgent / Alert</option>
                </select>
              </div>
            </div>
            <div class="form-group mb-2">
              <label class="form-label">Notice Message *</label>
              <textarea class="form-control" name="message" rows="3" required placeholder="Detailed message for students..."></textarea>
            </div>
          </form>
        `;new h({title:"Post New Notice",content:e,size:"md",buttons:[{text:"Cancel",className:"btn-secondary",onClick:n=>n.close()},{text:"Publish Notice",className:"btn-primary",onClick:async n=>{const o=n.element.querySelector("#noticeForm");if(!o.checkValidity()){o.reportValidity();return}const r=Object.fromEntries(new FormData(o).entries());try{const s=await c.post("/api/operations/announcements",r);s.success&&(i.success(s.message),n.close(),u())}catch(s){i.error(s.message)}}}]}).show()}),t.querySelectorAll(".btn-delete-notice").forEach(e=>{e.addEventListener("click",()=>{F.show({title:"Delete Notice",message:"Remove this notice from the board?",danger:!0,onConfirm:async()=>{await c.delete(`/api/operations/announcements/${e.dataset.id}`),i.success("Notice removed"),u()}})})})}catch{t.innerHTML='<div class="text-danger p-4">Failed to load notices</div>'}}async function C(t){try{const d=(await c.get("/api/operations/holidays")).data||[];t.innerHTML=`
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">\u{1F4C5} Library Holiday & Event Schedule (${d.length})</h3>
          <button id="btn-add-holiday" class="btn btn-primary btn-sm">+ Schedule Holiday</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 280px), 1fr)); gap: 1rem;">
          ${d.length>0?d.map(e=>`
            <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
              <div class="d-flex justify-content-between align-items-start mb-2">
                <strong style="font-size: 1rem;">${a(e.title)}</strong>
                <button class="btn btn-sm text-danger btn-delete-holiday" data-id="${e._id}" style="padding: 0 4px; font-size: 0.9rem;" title="Delete Holiday">\u{1F5D1}\uFE0F</button>
              </div>
              <div style="font-size: 0.85rem; color: var(--color-primary); font-weight: 600; margin-bottom: 6px;">
                \u{1F4C5} ${new Date(e.date).toLocaleDateString("en-IN",{weekday:"long",year:"numeric",month:"short",day:"numeric"})}
              </div>
              <p style="font-size: 0.85rem; color: var(--color-text-secondary); margin: 0;">${a(e.description||"Library study rooms will remain closed.")}</p>
            </div>
          `).join(""):`
            <div class="p-4 text-center text-muted" style="grid-column: 1 / -1;">No upcoming holidays scheduled.</div>
          `}
        </div>
      `,t.querySelector("#btn-add-holiday")?.addEventListener("click",()=>{const e=`
          <form id="holidayForm">
            <div class="mb-3">
              <label class="form-label">Holiday / Occasion Title *</label>
              <input type="text" class="form-control" name="title" required placeholder="e.g. Republic Day, Diwali Break">
            </div>
            <div class="mb-3">
              <label class="form-label">Date *</label>
              <input type="date" class="form-control" name="date" required value="${new Date().toISOString().split("T")[0]}">
            </div>
            <div class="mb-3">
              <label class="form-label">Description / Instructions</label>
              <textarea class="form-control" name="description" rows="2" placeholder="e.g. Library opens back at 6:00 AM the next day."></textarea>
            </div>
          </form>
        `,n=new h({title:"Schedule Library Holiday",content:e,buttons:[{text:"Cancel",className:"btn-secondary",onClick:()=>n.close()},{text:"Save Holiday",className:"btn-primary",onClick:async()=>{const o=document.getElementById("holidayForm"),r=new FormData(o),s=Object.fromEntries(r.entries());if(!s.title||!s.date){i.error("Title and Date are required");return}try{await c.post("/api/operations/holidays",s),i.success("Holiday scheduled successfully"),n.close(),u()}catch(l){i.error(l.message||"Failed to save holiday")}}}]});n.show()}),t.querySelectorAll(".btn-delete-holiday").forEach(e=>{e.addEventListener("click",async()=>{if(await F.show({title:"Delete Holiday",message:"Remove this date from the holiday list?",danger:!0}))try{await c.delete(`/api/operations/holidays/${e.dataset.id}`),i.success("Holiday removed"),u()}catch(n){i.error(n.message||"Failed to remove holiday")}})})}catch{t.innerHTML='<div class="text-danger p-4">Failed to load holidays</div>'}}async function L(t){try{const d=(await c.get("/api/operations/lostfound")).data||[];t.innerHTML=`
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">\u{1F50D} Lost & Found Registry (${d.length})</h3>
          <button id="btn-add-item" class="btn btn-primary btn-sm">+ Log Found Item</button>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Item Name</th>
                  <th style="padding: 12px 16px;">Found Location</th>
                  <th style="padding: 12px 16px;">Date Found</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Claimed By</th>
                  <th style="padding: 12px 16px;">Action</th>
                </tr>
              </thead>
              <tbody>
                ${d.length>0?d.map(e=>`
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;"><strong>${a(e.itemName)}</strong></td>
                    <td style="padding: 12px 16px;">${a(e.locationFound||"Study Hall")}</td>
                    <td style="padding: 12px 16px;">${new Date(e.dateFound).toLocaleDateString("en-IN")}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge" style="background: ${e.status==="claimed"?"rgba(0, 184, 148, 0.15)":"rgba(253, 203, 110, 0.2)"}; color: ${e.status==="claimed"?"var(--color-success)":"var(--color-warning)"}; text-transform: uppercase;">
                        ${a(e.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px;">${a(e.claimedBy||"-")}</td>
                    <td style="padding: 12px 16px;">
                      <div class="btn-icon-group">
                        ${e.status==="found"?`
                          <button type="button" class="btn-icon-action action-verify btn-claim-item" data-id="${e._id}" data-tooltip="Mark Item Claimed" aria-label="Mark Claimed">\u2705</button>
                        `:""}
                        <button type="button" class="btn-icon-action action-delete btn-delete-item" data-id="${e._id}" data-tooltip="Delete Item Record" aria-label="Delete">\u{1F5D1}\uFE0F</button>
                      </div>
                    </td>
                  </tr>
                `).join(""):`
                  <tr><td colspan="6" class="p-4 text-center text-muted">No lost & found records. Click "+ Log Found Item" to record misplaced belongings.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `,t.querySelector("#btn-add-item")?.addEventListener("click",()=>{const e=`
          <form id="lostFoundForm">
            <div class="mb-3">
              <label class="form-label">Item Name / Description *</label>
              <input type="text" class="form-control" name="itemName" required placeholder="e.g. Blue Boat Earphones, Calculator, Water Bottle">
            </div>
            <div class="mb-3">
              <label class="form-label">Found Location *</label>
              <input type="text" class="form-control" name="locationFound" required placeholder="e.g. Desk D-14, Discussion Room 2">
            </div>
            <div class="mb-3">
              <label class="form-label">Date Found</label>
              <input type="date" class="form-control" name="dateFound" required value="${new Date().toISOString().split("T")[0]}">
            </div>
          </form>
        `,n=new h({title:"Log Found Item",content:e,buttons:[{text:"Cancel",className:"btn-secondary",onClick:()=>n.close()},{text:"Save Item",className:"btn-primary",onClick:async()=>{const o=document.getElementById("lostFoundForm"),r=new FormData(o),s=Object.fromEntries(r.entries());if(!s.itemName||!s.locationFound){i.error("Item name and location are required");return}try{await c.post("/api/operations/lostfound",s),i.success("Lost & found item logged"),n.close(),u()}catch(l){i.error(l.message||"Failed to save item")}}}]});n.show()}),t.querySelectorAll(".btn-claim-item").forEach(e=>{e.addEventListener("click",async()=>{const n=prompt("Enter student name or roll number claiming this item:");n&&(await c.put(`/api/operations/lostfound/${e.dataset.id}`,{status:"claimed",claimedBy:n}),i.success("Item marked as claimed"),u())})}),t.querySelectorAll(".btn-delete-item").forEach(e=>{e.addEventListener("click",async()=>{if(await F.show({title:"Delete Item",message:"Remove item from register?",danger:!0}))try{await c.delete(`/api/operations/lostfound/${e.dataset.id}`),i.success("Record deleted"),u()}catch(n){i.error(n.message||"Failed to delete item")}})})}catch{t.innerHTML='<div class="text-danger p-4">Failed to load lost & found</div>'}}async function D(t){try{const d=(await c.get("/api/operations/feedback")).data||[];t.innerHTML=`
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">\u{1F4AC} Student Feedback & Complaints (${d.length})</h3>
          <button id="btn-add-feedback" class="btn btn-primary btn-sm">+ Submit Feedback</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
          ${d.length>0?d.map(e=>`
            <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
              <div class="d-flex justify-content-between align-items-start mb-2">
                <span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary); text-transform: capitalize;">
                  ${a(e.category)}
                </span>
                <span style="color: #f39c12; font-size: 0.9rem;">${"\u2605".repeat(e.rating||5)}${"\u2606".repeat(5-(e.rating||5))}</span>
              </div>
              <h4 style="margin: 0 0 6px 0; font-size: 1rem; font-weight: 700;">${a(e.studentName)}</h4>
              <p style="margin: 0 0 10px 0; font-size: 0.88rem; color: var(--color-text-secondary);">${a(e.message)}</p>
              ${e.adminReply?`
                <div style="background: var(--color-bg-primary); padding: 8px 12px; border-radius: 6px; font-size: 0.8rem; border-left: 3px solid var(--color-success); margin-bottom: 8px;">
                  <strong>Admin Reply:</strong> ${a(e.adminReply)}
                </div>
              `:""}
              <div class="d-flex justify-content-between align-items-center mt-2 pt-2" style="border-top: 1px solid var(--color-divider);">
                <span class="badge" style="background: ${e.status==="resolved"?"rgba(0,184,148,0.2)":"rgba(253,203,110,0.2)"}; color: ${e.status==="resolved"?"var(--color-success)":"var(--color-warning)"};">
                  ${a(e.status)}
                </span>
                <button type="button" class="btn-icon-action action-edit btn-reply-feedback" data-id="${e._id}" data-tooltip="Reply to Feedback" aria-label="Reply">\u{1F4AC}</button>
              </div>
            </div>
          `).join(""):`
            <div class="col-12 p-5 text-center text-muted card" style="grid-column: 1/-1;">No complaints or feedback submitted.</div>
          `}
        </div>
      `,t.querySelector("#btn-add-feedback")?.addEventListener("click",()=>{const e=`
          <form id="feedbackForm">
            <div class="form-group mb-3">
              <label class="form-label">Student Name *</label>
              <input type="text" class="form-control" name="studentName" required placeholder="e.g. Anjali Deshmukh">
            </div>
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Category</label>
                <select class="form-select form-control" name="category">
                  <option value="cleanliness">Cleanliness & Hygiene</option>
                  <option value="ac_wifi">AC / WiFi Speed</option>
                  <option value="noise">Noise / Silence</option>
                  <option value="seats">Chair / Desk Comfort</option>
                  <option value="management">Management / Staff</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Rating (1 to 5 Stars)</label>
                <select class="form-select form-control" name="rating">
                  <option value="5" selected>\u2605\u2605\u2605\u2605\u2605 (5 Stars - Excellent)</option>
                  <option value="4">\u2605\u2605\u2605\u2605\u2606 (4 Stars - Good)</option>
                  <option value="3">\u2605\u2605\u2605\u2606\u2606 (3 Stars - Average)</option>
                  <option value="2">\u2605\u2605\u2606\u2606\u2606 (2 Stars - Needs Improvement)</option>
                  <option value="1">\u2605\u2606\u2606\u2606\u2606 (1 Star - Urgent Issue)</option>
                </select>
              </div>
            </div>
            <div class="form-group mb-2">
              <label class="form-label">Feedback / Suggestion *</label>
              <textarea class="form-control" name="message" rows="3" required placeholder="Describe your experience or complaint..."></textarea>
            </div>
          </form>
        `;new h({title:"Submit Student Feedback",content:e,size:"md",buttons:[{text:"Cancel",className:"btn-secondary",onClick:n=>n.close()},{text:"Submit Feedback",className:"btn-primary",onClick:async n=>{const o=n.element.querySelector("#feedbackForm");if(!o.checkValidity()){o.reportValidity();return}const r=Object.fromEntries(new FormData(o).entries());r.rating=parseInt(r.rating,10);try{const s=await c.post("/api/operations/feedback",r);s.success&&(i.success(s.message),n.close(),u())}catch(s){i.error(s.message)}}}]}).show()}),t.querySelectorAll(".btn-reply-feedback").forEach(e=>{e.addEventListener("click",async()=>{const n=prompt("Enter administrative reply / resolution message:");n&&(await c.put(`/api/operations/feedback/${e.dataset.id}/reply`,{adminReply:n,status:"resolved"}),i.success("Reply saved & status resolved"),u())})})}catch{t.innerHTML='<div class="text-danger p-4">Failed to load feedback</div>'}}async function z(t){try{const d=(await c.get("/api/operations/leave-requests")).data||[];t.innerHTML=`
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">\u{1F334} Student Absence & Leave Requests (${d.length})</h3>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Student</th>
                  <th style="padding: 12px 16px;">Dates</th>
                  <th style="padding: 12px 16px;">Reason</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Reply</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${d.length>0?d.map(e=>`
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;">
                      <strong>${a(e.studentName)}</strong>
                      <div class="text-muted small">${a(e.studentPhone||"-")}</div>
                    </td>
                    <td style="padding: 12px 16px; font-weight: 500;">
                      ${new Date(e.startDate).toLocaleDateString("en-IN")} - ${new Date(e.endDate).toLocaleDateString("en-IN")}
                    </td>
                    <td style="padding: 12px 16px;">${a(e.reason)}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge ${e.status==="approved"?"badge-success":e.status==="rejected"?"badge-danger":"badge-warning"}" style="text-transform: uppercase; font-size: 0.75rem;">
                        ${a(e.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px; font-size: 0.8rem; color: var(--color-text-secondary);">${a(e.adminReply||"-")}</td>
                    <td style="padding: 12px 16px; text-align: center;">
                      ${e.status==="pending"?`
                        <div class="btn-icon-group justify-content-center">
                          <button type="button" class="btn-icon-action action-verify btn-approve-leave" data-id="${e._id}" data-tooltip="Approve Leave" aria-label="Approve">\u2705</button>
                          <button type="button" class="btn-icon-action action-delete btn-reject-leave" data-id="${e._id}" data-tooltip="Reject Leave" aria-label="Reject">\u274C</button>
                        </div>
                      `:'<span class="text-muted small">-</span>'}
                    </td>
                  </tr>
                `).join(""):`
                  <tr><td colspan="6" class="p-4 text-center text-muted">No leave applications submitted yet.</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `,t.querySelectorAll(".btn-approve-leave").forEach(e=>{e.addEventListener("click",async()=>{const n=prompt("Optional approval message / note for student:");await c.put(`/api/operations/leave-requests/${e.dataset.id}`,{status:"approved",adminReply:n||"Approved. Safe travels!"}),i.success("Leave approved"),u()})}),t.querySelectorAll(".btn-reject-leave").forEach(e=>{e.addEventListener("click",async()=>{const n=prompt("Reason for rejection:");await c.put(`/api/operations/leave-requests/${e.dataset.id}`,{status:"rejected",adminReply:n||"Leave request declined."}),i.warning("Leave rejected"),u()})})}catch{t.innerHTML='<div class="text-danger p-4">Failed to load leave requests</div>'}}async function R(t){try{const d=(await c.get("/api/operations/seat-changes")).data||[];t.innerHTML=`
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">\u{1F4BA} Student Desk Transfer Requests (${d.length})</h3>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Student</th>
                  <th style="padding: 12px 16px;">Current Seat</th>
                  <th style="padding: 12px 16px;">Requested Zone</th>
                  <th style="padding: 12px 16px;">Reason</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${d.length>0?d.map(e=>`
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;">
                      <strong>${a(e.studentName)}</strong>
                      <div class="text-muted small">${a(e.studentPhone||"-")}</div>
                    </td>
                    <td style="padding: 12px 16px; font-weight: 700; color: var(--color-primary);">
                      ${a(e.currentSeat?.seatNumber||e.currentSeatNumber||"-")}
                    </td>
                    <td style="padding: 12px 16px;"><span class="badge badge-primary">${a(e.preferredZone)}</span></td>
                    <td style="padding: 12px 16px;">${a(e.reason)}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge ${e.status==="approved"?"badge-success":e.status==="rejected"?"badge-danger":"badge-warning"}" style="text-transform: uppercase; font-size: 0.75rem;">
                        ${a(e.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px; text-align: center;">
                      ${e.status==="pending"?`
                        <div class="btn-icon-group justify-content-center">
                          <button type="button" class="btn-icon-action action-verify btn-transfer-seat" data-id="${e._id}" data-name="${a(e.studentName)}" data-tooltip="Allocate & Approve" aria-label="Allocate">\u2705</button>
                          <button type="button" class="btn-icon-action action-delete btn-reject-sc" data-id="${e._id}" data-tooltip="Reject Request" aria-label="Reject">\u274C</button>
                        </div>
                      `:'<span class="text-muted small">-</span>'}
                    </td>
                  </tr>
                `).join(""):`
                  <tr><td colspan="6" class="p-4 text-center text-muted">No seat transfer requests submitted.</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `,t.querySelectorAll(".btn-transfer-seat").forEach(e=>{e.addEventListener("click",async()=>{const n=await c.get("/api/seats?status=available"),o=Array.isArray(n.data)?n.data:n.data?.seats||n.seats||[];if(o.length===0){i.warning("No available seats to allocate.");return}const r=document.createElement("div");r.innerHTML=`
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Choose New Seat for ${a(e.dataset.name)}</label>
              <select id="transfer-seat-select" class="form-select">
                ${o.map(l=>`<option value="${l._id}">${a(l.seatNumber)} (${a(l.zone)} - ${a(l.type)})</option>`).join("")}
              </select>
            </div>
            <div class="d-flex justify-content-end gap-2">
              <button class="btn btn-primary" id="btn-confirm-transfer">Transfer Seat & Approve</button>
            </div>
          `;const s=new h({title:"\u{1F4BA} Transfer Student Seat",content:r,size:"sm"});s.show(),r.querySelector("#btn-confirm-transfer").onclick=async()=>{const l=r.querySelector("#transfer-seat-select").value;try{await c.put(`/api/operations/seat-changes/${e.dataset.id}`,{status:"approved",allocatedSeatId:l,adminReply:"Seat transfer approved and allocated."}),i.success("Seat transferred successfully!"),s.close(),u()}catch(m){i.error(m.message||"Transfer failed")}}})}),t.querySelectorAll(".btn-reject-sc").forEach(e=>{e.addEventListener("click",async()=>{const n=prompt("Reason for rejecting seat transfer:");await c.put(`/api/operations/seat-changes/${e.dataset.id}`,{status:"rejected",adminReply:n||"Seats in that zone are currently full."}),i.warning("Request rejected"),u()})})}catch{t.innerHTML='<div class="text-danger p-4">Failed to load seat change requests</div>'}}async function j(t){try{const[d,e]=await Promise.all([c.get("/api/operations/referrals"),c.get("/api/operations/referrals/config")]),n=d.data||[],o=e.data||{isEnabled:!0,referrerRewardType:"flat",referrerRewardAmount:100,refereeRewardType:"flat",refereeRewardAmount:100,minPlanAmount:500,autoApplyToNextRenewal:!0};t.innerHTML=`
        <!-- Top Program Configuration Card -->
        <div class="card p-4 mb-4" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.08), rgba(0, 184, 148, 0.05)), var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; margin-bottom: 1.25rem;">
            <div>
              <div style="display: flex; align-items: center; gap: 8px;">
                <span style="font-size: 1.4rem;">\u{1F381}</span>
                <h3 style="margin: 0; font-size: 1.2rem; font-weight: 700; color: var(--color-text-primary);">
                  Student Referral Program & Reward Settings
                </h3>
                <span class="badge ${o.isEnabled?"badge-success":"badge-danger"}" style="font-size: 0.75rem;">
                  ${o.isEnabled?"\u{1F7E2} Active & Enabled":"\u{1F534} Disabled"}
                </span>
              </div>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
                Customize reward discounts, automated next-renewal wallet credits, and referral validation rules.
              </p>
            </div>

            <div style="display: flex; gap: 8px; align-items: center;">
              <button id="btn-add-manual-referral" class="btn btn-primary btn-sm" style="font-weight: 700;">
                \u2795 Record Manual Referral
              </button>
            </div>
          </div>

          <!-- Configuration Controls Form -->
          <form id="referral-config-form" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; align-items: flex-end; background: var(--color-surface); padding: 14px; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Program Master Status</label>
              <select id="cfg-enabled" class="form-select form-control" style="font-weight: 600;">
                <option value="true" ${o.isEnabled?"selected":""}>\u{1F7E2} Enabled (Accepting Referrals)</option>
                <option value="false" ${o.isEnabled?"":"selected"}>\u{1F534} Disabled (Paused)</option>
              </select>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Referrer Reward (Next Renewal)</label>
              <div style="display: flex; gap: 4px;">
                <span class="input-group-text" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 6px 10px; font-weight: 700; border-radius: 6px 0 0 6px;">\u20B9</span>
                <input type="number" id="cfg-referrer-amount" class="form-control" value="${o.referrerRewardAmount||100}" min="0" required style="border-radius: 0 6px 6px 0;">
              </div>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Friend Discount (On Joining)</label>
              <div style="display: flex; gap: 4px;">
                <span class="input-group-text" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 6px 10px; font-weight: 700; border-radius: 6px 0 0 6px;">\u20B9</span>
                <input type="number" id="cfg-referee-amount" class="form-control" value="${o.refereeRewardAmount||100}" min="0" required style="border-radius: 0 6px 6px 0;">
              </div>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Min Plan Price</label>
              <div style="display: flex; gap: 4px;">
                <span class="input-group-text" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 6px 10px; font-weight: 700; border-radius: 6px 0 0 6px;">\u20B9</span>
                <input type="number" id="cfg-min-plan" class="form-control" value="${o.minPlanAmount||500}" min="0" required style="border-radius: 0 6px 6px 0;">
              </div>
            </div>

            <div style="grid-column: 1 / -1; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; border-top: 1px solid var(--color-divider); padding-top: 10px; margin-top: 4px;">
              <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; font-weight: 600; cursor: pointer; color: var(--color-text-primary);">
                <input type="checkbox" id="cfg-auto-apply" ${o.autoApplyToNextRenewal?"checked":""} style="width: 16px; height: 16px;">
                \u26A1 Automatically apply approved referral credits as discount on student's next renewal invoice
              </label>

              <button type="submit" class="btn btn-success btn-sm" id="btn-save-referral-config" style="font-weight: 700; padding: 6px 16px;">
                \u{1F4BE} Save Program Settings
              </button>
            </div>
          </form>
        </div>

        <!-- Referral Leads & Transactions Table -->
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div class="p-3" style="border-bottom: 1px solid var(--color-divider); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; background: var(--color-surface-hover);">
            <div style="font-weight: 700; font-size: 1rem; color: var(--color-text-primary);">
              \u{1F4CB} Referral Leads & Reward Ledger (${n.length})
            </div>
            <div class="text-muted small">
              Earned discounts automatically deduct from student renewal quotes.
            </div>
          </div>

          <div style="overflow-x: auto;">
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Referrer Student</th>
                  <th style="padding: 12px 16px;">Prospect Friend</th>
                  <th style="padding: 12px 16px;">Phone</th>
                  <th style="padding: 12px 16px;">Referral Code</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Reward</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${n.length>0?n.map(r=>{const s=r.referrerStudent?.name||r.referrerName,l=r.referrerStudent?.studentId||"",m=r.referralCode||r.referrerStudent?.referralCode||"-";let f="badge-secondary";return r.status==="rewarded"?f="badge-success":r.status==="joined"||r.status==="approved"?f="badge-primary":r.status==="pending"?f="badge-warning":r.status==="rejected"&&(f="badge-danger"),`
                    <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                      <td style="padding: 12px 16px;">
                        <div style="font-weight: 700; color: var(--color-text-primary);">${a(s)}</div>
                        <div class="text-muted small" style="font-family: monospace;">${a(l||r.referrerPhone||"")}</div>
                      </td>
                      <td style="padding: 12px 16px;">
                        <div style="font-weight: 600;">${a(r.refereeName)}</div>
                        <div class="text-muted small">${a(r.targetExam||r.notes||"-")}</div>
                      </td>
                      <td style="padding: 12px 16px; font-family: monospace;">${a(r.refereePhone)}</td>
                      <td style="padding: 12px 16px;">
                        <span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-family: monospace; font-weight: 700;">
                          ${a(m)}
                        </span>
                      </td>
                      <td style="padding: 12px 16px;">
                        <span class="badge ${f}" style="text-transform: uppercase; font-size: 0.75rem;">
                          ${a(r.status)}
                        </span>
                      </td>
                      <td style="padding: 12px 16px; font-weight: 700; color: var(--color-success);">
                        \u20B9${r.rewardAmount||100}
                        ${r.discountApplied?'<span style="font-size: 0.72rem; color: var(--color-text-muted); display: block;">\u2713 Credited</span>':""}
                      </td>
                      <td style="padding: 12px 16px; text-align: center;">
                        <div class="btn-icon-group justify-content-center">
                          ${!r.discountApplied&&r.status!=="rejected"?`
                            <button type="button" class="btn-icon-action action-verify btn-approve-ref-reward" data-id="${r._id}" data-amt="${r.rewardAmount||100}" data-tooltip="Credit \u20B9${r.rewardAmount||100} Discount" aria-label="Credit Discount">\u26A1</button>
                          `:""}
                          <button type="button" class="btn-icon-action action-edit btn-edit-ref" data-ref='${JSON.stringify(r)}' data-tooltip="Edit Referral" aria-label="Edit">\u270F\uFE0F</button>
                          <button type="button" class="btn-icon-action action-delete btn-delete-ref" data-id="${r._id}" data-tooltip="Delete Referral Record" aria-label="Delete">\u{1F5D1}\uFE0F</button>
                        </div>
                      </td>
                    </tr>
                  `}).join(""):`
                  <tr><td colspan="7" class="p-5 text-center text-muted">No student referrals recorded yet. Friends who use student referral codes on registration will appear here automatically!</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `,t.querySelector("#referral-config-form")?.addEventListener("submit",async r=>{r.preventDefault();const s=t.querySelector("#btn-save-referral-config");k.button(s,!0);try{const l={isEnabled:t.querySelector("#cfg-enabled").value==="true",referrerRewardAmount:Number(t.querySelector("#cfg-referrer-amount").value),refereeRewardAmount:Number(t.querySelector("#cfg-referee-amount").value),minPlanAmount:Number(t.querySelector("#cfg-min-plan").value),autoApplyToNextRenewal:t.querySelector("#cfg-auto-apply").checked},m=await c.put("/api/operations/referrals/config",l);m.success?(i.success("Referral Program settings saved successfully!"),u()):i.error(m.message)}catch(l){i.error(l.message||"Failed to save settings")}finally{k.button(s,!1)}}),t.querySelectorAll(".btn-approve-ref-reward").forEach(r=>{r.addEventListener("click",async()=>{try{k.button(r,!0);const s=await c.post(`/api/operations/referrals/${r.dataset.id}/approve-reward`,{rewardAmount:Number(r.dataset.amt)});s.success?(i.success(s.message),u()):i.error(s.message)}catch(s){i.error(s.message||"Failed to credit reward")}finally{k.button(r,!1)}})}),t.querySelector("#btn-add-manual-referral")?.addEventListener("click",async()=>{let r=[];try{const p=await c.get("/api/students?limit=500"),g=p?.data?.students||p?.students||p?.data||p;r=Array.isArray(g)?g:[]}catch(p){console.error("Error loading students list for referral modal:",p)}const s=document.createElement("div");s.innerHTML=`
          <form id="form-manual-referral" style="display: flex; flex-direction: column; gap: 16px;">
            
            <div class="form-group">
              <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin: 0;">
                  Referring Student (Existing Member) *
                </label>
                <span class="badge badge-secondary" style="font-size: 0.72rem;">${r.length} Members Loaded</span>
              </div>

              <input type="text" id="man-student-search" class="form-control mb-2" placeholder="\u{1F50D} Type to filter student by name, phone, or ID..." style="font-size: 0.85rem; padding: 6px 10px; border-radius: 6px;">

              <select id="man-student-id" class="form-select form-control" required size="5" style="font-weight: 600; padding: 6px; border-radius: var(--radius-md); background: var(--color-surface); color: var(--color-text-primary); border: 1.5px solid var(--color-border); max-height: 140px; overflow-y: auto;">
                <option value="" style="background: var(--color-surface); color: var(--color-text-secondary); font-style: italic;" disabled selected>-- Select Referring Student Below --</option>
                ${r.length>0?r.map(p=>`
                  <option value="${p._id}" data-search="${a((p.name+" "+(p.studentId||"")+" "+(p.phone||"")+" "+(p.referralCode||"")).toLowerCase())}" style="background: var(--color-surface); color: var(--color-text-primary); padding: 8px 10px; border-bottom: 1px solid var(--color-divider); cursor: pointer;">
                    \u{1F464} ${a(p.name)} \u2022 \u{1F4F1} ${a(p.phone||p.studentId||"N/A")} ${p.referralCode?" \u2022 [Code: "+a(p.referralCode)+"]":""}
                  </option>
                `).join(""):`
                  <option value="" disabled style="padding: 10px; color: var(--color-text-secondary);">No registered students found in database</option>
                `}
              </select>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Friend / Referee Name *</label>
                <input type="text" id="man-referee-name" class="form-control" placeholder="e.g. Rahul Sharma" required style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);">
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Friend Phone *</label>
                <input type="tel" id="man-referee-phone" class="form-control" placeholder="10-digit mobile" required style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);">
              </div>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Course / Target Exam</label>
                <input type="text" id="man-target-exam" class="form-control" placeholder="e.g. UPSC, CA, NEET" style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);">
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Reward Credit Amount (\u20B9)</label>
                <input type="number" id="man-reward-amt" class="form-control" value="100" min="0" style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md); font-weight: 700; color: var(--color-success);">
              </div>
            </div>

            <div class="form-group">
              <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Notes / Follow-up Details</label>
              <textarea id="man-notes" class="form-control" rows="2" placeholder="Friend visited library for trial..." style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);"></textarea>
            </div>

            <div style="display: flex; gap: 10px; justify-content: flex-end; margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--color-divider);">
              <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()" style="font-weight: 600; padding: 0.6rem 1.25rem;">Cancel</button>
              <button type="submit" class="btn btn-primary" style="font-weight: 700; padding: 0.6rem 1.5rem;">Record Referral</button>
            </div>
          </form>
        `;const l=new h({title:"\u{1F381} Record Manual Referral Lead",content:s,size:"md"});l.show();const m=s.querySelector("#man-student-search"),f=s.querySelector("#man-student-id");m&&f&&(m.focus(),m.addEventListener("input",p=>{const g=p.target.value.toLowerCase().trim();Array.from(f.options).forEach(y=>{y.dataset.search&&(y.style.display=y.dataset.search.includes(g)?"block":"none")})})),s.querySelector("#form-manual-referral").onsubmit=async p=>{p.preventDefault();try{const g={referrerStudentId:s.querySelector("#man-student-id").value,refereeName:s.querySelector("#man-referee-name").value.trim(),refereePhone:s.querySelector("#man-referee-phone").value.trim(),targetExam:s.querySelector("#man-target-exam").value.trim(),rewardAmount:Number(s.querySelector("#man-reward-amt").value),notes:s.querySelector("#man-notes").value.trim()},y=await c.post("/api/operations/referrals",g);y.success?(i.success("Referral lead recorded successfully!"),l.close(),u()):i.error(y.message)}catch(g){i.error(g.message||"Failed to record referral")}}}),t.querySelectorAll(".btn-edit-ref").forEach(r=>{r.addEventListener("click",()=>{const s=JSON.parse(r.dataset.ref),l=document.createElement("div");l.innerHTML=`
            <form id="form-edit-referral" style="display: flex; flex-direction: column; gap: 12px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Referral Status</label>
                <select id="edit-ref-status" class="form-select form-control">
                  <option value="pending" ${s.status==="pending"?"selected":""}>\u{1F7E1} Pending Lead</option>
                  <option value="joined" ${s.status==="joined"?"selected":""}>\u{1F535} Friend Joined</option>
                  <option value="approved" ${s.status==="approved"?"selected":""}>\u{1F7E3} Approved</option>
                  <option value="rewarded" ${s.status==="rewarded"?"selected":""}>\u{1F7E2} Rewarded & Discount Credited</option>
                  <option value="rejected" ${s.status==="rejected"?"selected":""}>\u{1F534} Rejected / Invalid</option>
                </select>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Reward Discount Amount (\u20B9)</label>
                <input type="number" id="edit-ref-reward-amt" class="form-control" value="${s.rewardAmount||100}">
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Notes</label>
                <textarea id="edit-ref-notes" class="form-control" rows="2">${a(s.notes||"")}</textarea>
              </div>

              <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 8px;">
                <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
                <button type="submit" class="btn btn-primary" style="font-weight: 700;">\u{1F4BE} Save Changes</button>
              </div>
            </form>
          `;const m=new h({title:"\u270F\uFE0F Edit Referral Record",content:l,size:"md"});m.show(),l.querySelector("#form-edit-referral").onsubmit=async f=>{f.preventDefault();try{const p={status:l.querySelector("#edit-ref-status").value,rewardAmount:Number(l.querySelector("#edit-ref-reward-amt").value),notes:l.querySelector("#edit-ref-notes").value.trim()},g=await c.put(`/api/operations/referrals/${s._id}`,p);g.success?(i.success("Referral updated successfully!"),m.close(),u()):i.error(g.message)}catch(p){i.error(p.message||"Failed to update referral")}}})}),t.querySelectorAll(".btn-delete-ref").forEach(r=>{r.addEventListener("click",async()=>{if(await F.show({title:"Delete Referral Entry",message:"Are you sure you want to delete this referral lead?",danger:!0}))try{await c.delete(`/api/operations/referrals/${r.dataset.id}`),i.success("Referral deleted"),u()}catch(s){i.error(s.message||"Failed to delete")}})})}catch(d){t.innerHTML=`<div class="text-danger p-4">Failed to load referrals: ${a(d.message)}</div>`}}async function T(t){try{const d=await c.get("/api/waiting-list"),e=d.data?.items||[],n=d.data?.counts||{waiting:0,offered:0,assigned:0,total:e.length};t.innerHTML=`
        <!-- Top Metrics Cards -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px; margin-bottom: 1.5rem;">
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; align-items: center; gap: 14px;">
            <div style="width: 48px; height: 48px; border-radius: 12px; background: rgba(245, 158, 11, 0.15); color: var(--color-warning); display: flex; align-items: center; justify-content: center; font-size: 1.5rem;">
              \u23F3
            </div>
            <div>
              <div class="text-muted small" style="font-weight: 600; text-transform: uppercase;">Active in Queue</div>
              <div style="font-size: 1.6rem; font-weight: 800; color: var(--color-warning);">${n.waiting}</div>
            </div>
          </div>

          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; align-items: center; gap: 14px;">
            <div style="width: 48px; height: 48px; border-radius: 12px; background: rgba(99, 102, 241, 0.15); color: var(--color-primary); display: flex; align-items: center; justify-content: center; font-size: 1.5rem;">
              \u{1F4BA}
            </div>
            <div>
              <div class="text-muted small" style="font-weight: 600; text-transform: uppercase;">Offered / 24h Hold</div>
              <div style="font-size: 1.6rem; font-weight: 800; color: var(--color-primary);">${n.offered}</div>
            </div>
          </div>

          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; align-items: center; gap: 14px;">
            <div style="width: 48px; height: 48px; border-radius: 12px; background: rgba(34, 197, 94, 0.15); color: var(--color-success); display: flex; align-items: center; justify-content: center; font-size: 1.5rem;">
              \u2705
            </div>
            <div>
              <div class="text-muted small" style="font-weight: 600; text-transform: uppercase;">Converted to Admission</div>
              <div style="font-size: 1.6rem; font-weight: 800; color: var(--color-success);">${n.assigned}</div>
            </div>
          </div>
        </div>

        <!-- Header Actions -->
        <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
          <div>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700;">\u23F3 Shift Capacity & Seat Waiting List (${e.length})</h3>
            <p style="margin: 2px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
              Students queued for full shifts or reserved seats. Allocate vacant seats in 1 click!
            </p>
          </div>
          <div class="d-flex gap-2 align-items-center">
            <button id="btn-add-waiting-item" class="btn btn-primary btn-sm" style="font-weight: 700;">
              \u2795 Add Walk-in to Queue
            </button>
          </div>
        </div>

        <!-- Waiting Queue Table -->
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Priority</th>
                  <th style="padding: 12px 16px;">Student Name</th>
                  <th style="padding: 12px 16px;">Contact</th>
                  <th style="padding: 12px 16px;">Preferred Shift & Zone</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Offered Seat / Note</th>
                  <th style="padding: 12px 16px;">Date Added</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${e.length>0?e.map((o,r)=>{let s="badge-warning";o.status==="assigned"?s="badge-success":o.status==="offered"?s="badge-primary":o.status==="cancelled"&&(s="badge-danger");const l=o.createdAt?new Date(o.createdAt).toLocaleDateString("en-IN"):"-",m=o.offeredSeat?.seatNumber||(typeof o.offeredSeat=="string"?o.offeredSeat:null);return`
                    <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                      <td style="padding: 12px 16px;">
                        <span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-weight: 800; font-size: 0.85rem;">
                          #${o.priority||r+1}
                        </span>
                      </td>
                      <td style="padding: 12px 16px;">
                        <strong style="color: var(--color-text-primary);">${a(o.studentName)}</strong>
                        ${o.student?.studentId?`<div class="text-muted small">${a(o.student.studentId)}</div>`:""}
                      </td>
                      <td style="padding: 12px 16px; font-family: monospace;">
                        <div>${a(o.studentPhone)}</div>
                        ${o.studentEmail?`<div class="text-muted small" style="font-size: 0.75rem;">${a(o.studentEmail)}</div>`:""}
                      </td>
                      <td style="padding: 12px 16px;">
                        <span class="badge badge-primary">${a(o.preferredShift||"Any Shift")}</span>
                        <span class="badge badge-secondary" style="margin-left: 4px;">${a(o.preferredZone||"Any Zone")}</span>
                      </td>
                      <td style="padding: 12px 16px;">
                        <span class="badge ${s}" style="text-transform: uppercase; font-size: 0.75rem;">
                          ${a(o.status)}
                        </span>
                      </td>
                      <td style="padding: 12px 16px;">
                        ${m?`
                          <div style="font-weight: 700; color: var(--color-primary);">\u{1F4BA} Seat ${a(m)}</div>
                          ${o.offerExpiresAt?`<div class="text-muted small" style="font-size: 0.75rem;">Hold: ${new Date(o.offerExpiresAt).toLocaleTimeString([],{hour:"2-digit",minute:"2-digit"})}</div>`:""}
                        `:`<span class="text-muted small">${a(o.notes||"Awaiting vacant seat")}</span>`}
                      </td>
                      <td style="padding: 12px 16px; font-size: 0.85rem; color: var(--color-text-secondary);">
                        ${l}
                      </td>
                      <td style="padding: 12px 16px; text-align: center;">
                        <div class="btn-icon-group justify-content-center">
                          ${o.status!=="assigned"&&o.status!=="cancelled"?`
                            <button type="button" class="btn-icon-action action-verify btn-convert-admission" data-id="${o._id}" data-name="${a(o.studentName)}" data-phone="${a(o.studentPhone)}" data-shift="${a(o.preferredShift||"")}" data-seat="${m||""}" data-tooltip="Convert to Admission" aria-label="Convert">\u26A1</button>
                            <button type="button" class="btn-icon-action action-receipt btn-offer-seat" data-id="${o._id}" data-name="${a(o.studentName)}" data-tooltip="Offer Vacant Desk (24h Hold)" aria-label="Offer Desk">\u{1F4BA}</button>
                            <button type="button" class="btn-icon-action action-delete btn-cancel-waiting" data-id="${o._id}" data-tooltip="Cancel Waiting Entry" aria-label="Cancel">\u{1F5D1}\uFE0F</button>
                          `:`<span class="badge badge-success" style="font-size: 0.75rem;">${o.status==="assigned"?"\u2713 Enrolled":"Cancelled"}</span>`}
                        </div>
                      </td>
                    </tr>
                  `}).join(""):`
                  <tr><td colspan="8" class="p-5 text-center text-muted">No students currently in waiting queue. When a shift reaches maximum capacity, applicants will appear here automatically!</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `,t.querySelectorAll(".btn-convert-admission").forEach(o=>{o.addEventListener("click",async()=>{const r=o.dataset.id,s=o.dataset.name,l=o.dataset.phone,m=o.dataset.shift;let f=[],p=[],g=[];try{const[b,$,x]=await Promise.all([c.get("/api/seats?status=available"),c.get("/api/shifts"),c.get("/api/plans")]);f=Array.isArray(b.data)?b.data:b.data?.seats||b.seats||[],p=Array.isArray($.data)?$.data:$.data?.shifts||[],g=Array.isArray(x.data)?x.data:x.data?.plans||[]}catch{}if(f.length===0){i.warning("No vacant seats currently available. Please check seat availability or wait for a desk to clear.");return}const y=document.createElement("div");y.innerHTML=`
            <form id="form-convert-admission" style="display: flex; flex-direction: column; gap: 14px;">
              <div style="background: rgba(34, 197, 94, 0.08); border: 1px solid rgba(34, 197, 94, 0.25); border-radius: var(--radius-md); padding: 12px;">
                <div style="font-weight: 700; color: var(--color-success);">\u26A1 1-Click Admission & Desk Allocation</div>
                <div style="font-size: 0.85rem; color: var(--color-text-secondary);">
                  Converting <strong>${a(s)}</strong> (${a(l)}) to an active student membership.
                </div>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Select Available Vacant Seat *</label>
                <select id="conv-seat-id" class="form-select form-control" required style="font-weight: 700; font-size: 0.95rem;">
                  ${f.map(b=>`<option value="${b._id}">\u{1F4BA} ${a(b.seatNumber)} (${a(b.zone||"General")} - ${a(b.type||"Standard")})</option>`).join("")}
                </select>
              </div>

              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
                <div class="form-group">
                  <label class="form-label" style="font-weight: 700;">Study Shift</label>
                  <select id="conv-shift-id" class="form-select form-control">
                    <option value="">-- Select Shift --</option>
                    ${p.map(b=>`<option value="${b._id}">${a(b.name)} (${b.startTime} - ${b.endTime})</option>`).join("")}
                  </select>
                </div>

                <div class="form-group">
                  <label class="form-label" style="font-weight: 700;">Membership Plan</label>
                  <select id="conv-plan-id" class="form-select form-control">
                    ${g.map(b=>{const $=Number(b.price)||0,x=Number(b.discount)||0,S=Math.round(b.effectivePrice!==void 0?b.effectivePrice:$*(1-x/100)),P=x>0?` [${x}% OFF, \u20B9${S.toLocaleString("en-IN")}]`:` (\u20B9${S.toLocaleString("en-IN")})`;return`<option value="${b._id}">${a(b.name)}${P}</option>`}).join("")}
                  </select>
                </div>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Payment Method</label>
                <select id="conv-pay-method" class="form-select form-control">
                  <option value="cash" selected>\u{1F4B5} Cash at Reception Desk</option>
                  <option value="upi">\u26A1 Direct UPI (GPay / PhonePe / Paytm / BHIM)</option>
                  <option value="bank_transfer">\u{1F3DB}\uFE0F Bank Transfer / NEFT</option>
                  <option value="card">\u{1F4B3} Debit / Credit Card</option>
                  <option value="desk">\u{1F4B5} Pay Later at Front Desk</option>
                  <option value="netbanking">\u{1F3E6} NetBanking / Online Transfer</option>
                </select>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Admission Notes / Reference</label>
                <input type="text" id="conv-notes" class="form-control" placeholder="Allocated upon seat vacancy...">
              </div>

              <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 10px;">
                <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
                <button type="submit" class="btn btn-success" id="btn-submit-convert" style="font-weight: 700;">
                  \u{1F680} Convert to Admission & Assign Seat
                </button>
              </div>
            </form>
          `;const E=new h({title:`\u26A1 Convert ${s} to Admission`,content:y,size:"md"});E.show(),y.querySelector("#form-convert-admission").onsubmit=async b=>{b.preventDefault();const $=y.querySelector("#btn-submit-convert");k.button($,!0);try{const x={seatId:y.querySelector("#conv-seat-id").value,shiftId:y.querySelector("#conv-shift-id").value||null,planId:y.querySelector("#conv-plan-id").value||null,paymentMethod:y.querySelector("#conv-pay-method")?.value||"cash",notes:y.querySelector("#conv-notes").value.trim()},S=await c.post(`/api/waiting-list/${r}/convert-admission`,x);S.success?(i.success(S.message||"Successfully converted to active student admission!"),E.close(),u()):i.error(S.message)}catch(x){i.error(x.message||"Failed to convert admission")}finally{k.button($,!1)}}})}),t.querySelectorAll(".btn-offer-seat").forEach(o=>{o.addEventListener("click",async()=>{const r=o.dataset.id,s=o.dataset.name;let l=[];try{const p=await c.get("/api/seats?status=available");l=Array.isArray(p.data)?p.data:p.data?.seats||p.seats||[]}catch{}if(l.length===0){i.warning("No available vacant seats to offer.");return}const m=document.createElement("div");m.innerHTML=`
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Choose Vacant Seat to Offer ${a(s)} (24-hour Hold)</label>
              <select id="offer-seat-select" class="form-select form-control">
                ${l.map(p=>`<option value="${p._id}">${a(p.seatNumber)} (${a(p.zone||"Hall")} - ${a(p.type||"Standard")})</option>`).join("")}
              </select>
            </div>
            <div class="d-flex justify-content-end gap-2">
              <button class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
              <button class="btn btn-primary" id="btn-confirm-offer" style="font-weight: 700;">\u{1F4BA} Offer Seat Hold</button>
            </div>
          `;const f=new h({title:`\u{1F4BA} Offer Seat to ${s}`,content:m,size:"sm"});f.show(),m.querySelector("#btn-confirm-offer").onclick=async()=>{const p=m.querySelector("#offer-seat-select").value;try{const g=await c.put(`/api/waiting-list/${r}/offer`,{seatId:p});g.success?(i.success(g.message),f.close(),u()):i.error(g.message)}catch(g){i.error(g.message||"Failed to offer seat")}}})}),t.querySelectorAll(".btn-cancel-waiting").forEach(o=>{o.addEventListener("click",async()=>{if(await F.show({title:"Cancel Waiting Queue Entry",message:"Are you sure you want to remove this candidate from the waiting list?",danger:!0}))try{await c.put(`/api/waiting-list/${o.dataset.id}/cancel`,{}),i.success("Waiting entry cancelled"),u()}catch(r){i.error(r.message||"Failed to cancel")}})}),t.querySelector("#btn-add-waiting-item")?.addEventListener("click",async()=>{let o=[];try{const l=await c.get("/api/shifts");o=Array.isArray(l.data)?l.data:l.data?.shifts||[]}catch{}const r=document.createElement("div");r.innerHTML=`
          <form id="form-add-waiting" style="display: flex; flex-direction: column; gap: 12px;">
            <div class="form-group">
              <label class="form-label" style="font-weight: 700;">Student / Candidate Name *</label>
              <input type="text" id="wl-name" class="form-control" placeholder="Full name" required>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Mobile Phone *</label>
                <input type="tel" id="wl-phone" class="form-control" placeholder="10-digit mobile" required>
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Email Address</label>
                <input type="email" id="wl-email" class="form-control" placeholder="student@example.com">
              </div>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Preferred Study Shift</label>
                <select id="wl-shift" class="form-select form-control">
                  <option value="Any">Any Shift</option>
                  ${o.map(l=>`<option value="${a(l.name)}">${a(l.name)} (${l.startTime} - ${l.endTime})</option>`).join("")}
                </select>
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Preferred Zone / Desk Type</label>
                <select id="wl-zone" class="form-select form-control">
                  <option value="General">General Reading Zone</option>
                  <option value="Silent AC">Silent AC Zone</option>
                  <option value="Private Cabin">Private Cabin</option>
                  <option value="Discussion">Discussion Zone</option>
                </select>
              </div>
            </div>

            <div class="form-group">
              <label class="form-label" style="font-weight: 700;">Notes / Target Exam</label>
              <textarea id="wl-notes" class="form-control" rows="2" placeholder="Preparing for UPSC, requires morning slot..."></textarea>
            </div>

            <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 8px;">
              <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
              <button type="submit" class="btn btn-primary" style="font-weight: 700;">\u2795 Add to Waiting Queue</button>
            </div>
          </form>
        `;const s=new h({title:"\u23F3 Add Candidate to Waiting List",content:r,size:"md"});s.show(),r.querySelector("#form-add-waiting").onsubmit=async l=>{l.preventDefault();try{const m={studentName:r.querySelector("#wl-name").value.trim(),studentPhone:r.querySelector("#wl-phone").value.trim(),studentEmail:r.querySelector("#wl-email").value.trim(),preferredShift:r.querySelector("#wl-shift").value,preferredZone:r.querySelector("#wl-zone").value,notes:r.querySelector("#wl-notes").value.trim()},f=await c.post("/api/waiting-list",m);f.success?(i.success(f.message||"Added to waiting queue!"),s.close(),u()):i.error(f.message)}catch(m){i.error(m.message||"Failed to add to waiting list")}}})}catch(d){t.innerHTML=`<div class="text-danger p-4">Failed to load waiting list: ${a(d.message)}</div>`}}return u(),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u26A1",label:"Operations Actions",color:"#6c5ce7",actions:[{icon:"\u23F3",label:"Waiting List",onClick:()=>{v="waiting",w.querySelectorAll(".tab-btn").forEach(t=>t.classList.toggle("active",t.dataset.tab==="waiting")),u()}},{icon:"\u{1F4E2}",label:"Broadcast Notice",onClick:()=>{v="announcements",w.querySelectorAll(".tab-btn").forEach(t=>t.classList.toggle("active",t.dataset.tab==="announcements")),u()}},{icon:"\u{1F381}",label:"Referrals Lead",onClick:()=>{v="referrals",w.querySelectorAll(".tab-btn").forEach(t=>t.classList.toggle("active",t.dataset.tab==="referrals")),u()}}]}),w}export{M as render};
