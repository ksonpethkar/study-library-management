import w from"../api.js";import{t as l}from"../i18n.js";import{Modal as H,Confirm as M,Toast as u,ActionMenu as D,escapeHTML as v}from"../ui.js";let m=[],E={total:0,active:0,inactive:0,fullDay:0,totalEnrolled:0,studentEnrollment:{},shiftStats:[]},x="all",k="";const L=[{key:"mon",label:"Mon",full:"Monday"},{key:"tue",label:"Tue",full:"Tuesday"},{key:"wed",label:"Wed",full:"Wednesday"},{key:"thu",label:"Thu",full:"Thursday"},{key:"fri",label:"Fri",full:"Friday"},{key:"sat",label:"Sat",full:"Saturday"},{key:"sun",label:"Sun",full:"Sunday"}];function q(t){if(!t)return"";const r=t.split(":"),a=parseInt(r[0],10),e=parseInt(r[1]||"0",10);if(isNaN(a))return t;const o=a>=12?"PM":"AM";return`${(a%12||12).toString().padStart(2,"0")}:${e.toString().padStart(2,"0")} ${o}`}function U(t,r){if(!t||!r)return"";const[a,e]=t.split(":").map(Number),[o,i]=r.split(":").map(Number);let d=a*60+e,f=o*60+i;f<=d&&(f+=1440);const y=f-d,s=Math.floor(y/60),n=y%60;return n===0?`${s} hrs`:`${s}h ${n}m`}async function R(){const t=document.createElement("div");return t.className="page-container",t.innerHTML=`
    <!-- Header -->
    <div class="page-header d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;">
      <div>
        <h2 style="margin: 0; font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary);">${l("Shift Management")}</h2>
        <p class="text-muted small mb-0" style="margin-top: 4px; color: var(--color-text-secondary); font-size: 0.9rem;">
          Configure study library operating shifts, daily schedules, capacities, and rates.
        </p>
      </div>
      <div style="display: flex; gap: 10px; align-items: center;">
        <button id="btn-add-shift" class="btn btn-primary" style="display: flex; align-items: center; gap: 8px;">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="12" y1="5" x2="12" y2="19"></line>
            <line x1="5" y1="12" x2="19" y2="12"></line>
          </svg>
          <span>${l("Add New Shift")}</span>
        </button>
      </div>
    </div>

    <!-- Stats Summary Cards -->
    <div id="shifts-stats-container" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 1.25rem; margin-bottom: 1.75rem;">
      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-primary-bg); color: var(--color-primary); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"></circle>
            <polyline points="12 6 12 12 16 14"></polyline>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${l("Total Shifts")}</div>
          <div class="stat-value" id="stat-total-shifts" style="font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary);">-</div>
        </div>
      </div>

      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-success-bg); color: var(--color-success); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
            <polyline points="22 4 12 14.01 9 11.01"></polyline>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${l("Active Shifts")}</div>
          <div class="stat-value" id="stat-active-shifts" style="font-size: 1.6rem; font-weight: 700; color: var(--color-success);">-</div>
        </div>
      </div>

      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-info-bg); color: var(--color-info); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="5"></circle>
            <line x1="12" y1="1" x2="12" y2="3"></line>
            <line x1="12" y1="21" x2="12" y2="23"></line>
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
            <line x1="1" y1="12" x2="3" y2="12"></line>
            <line x1="21" y1="12" x2="23" y2="12"></line>
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${l("Full-Day Shifts")}</div>
          <div class="stat-value" id="stat-fullday-shifts" style="font-size: 1.6rem; font-weight: 700; color: var(--color-info);">-</div>
        </div>
      </div>

      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-warning-bg); color: var(--color-warning-dark); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
            <circle cx="9" cy="7" r="4"></circle>
            <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
            <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${l("Enrolled Students")}</div>
          <div class="stat-value" id="stat-enrolled-students" style="font-size: 1.6rem; font-weight: 700; color: var(--color-warning-dark);">-</div>
        </div>
      </div>
    </div>

    <!-- Filters & Search Toolbar -->
    <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1rem 1.25rem; margin-bottom: 1.5rem;">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
        <!-- Search -->
        <div style="position: relative; min-width: 260px; flex: 1; max-width: 400px;">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--color-text-muted);">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input type="text" id="shifts-search-input" class="form-control" placeholder="Search by shift name, code..." style="padding-left: 36px; height: 38px; font-size: 0.9rem;">
        </div>

        <!-- Filter tabs -->
        <div style="display: flex; gap: 8px; align-items: center;">
          <span style="font-size: 0.85rem; color: var(--color-text-secondary); font-weight: 500;">${l("Filter")}:</span>
          <button type="button" class="btn btn-sm btn-filter ${x==="all"?"btn-primary":"btn-outline"}" data-filter="all">All</button>
          <button type="button" class="btn btn-sm btn-filter ${x==="active"?"btn-primary":"btn-outline"}" data-filter="active">Active</button>
          <button type="button" class="btn btn-sm btn-filter ${x==="inactive"?"btn-primary":"btn-outline"}" data-filter="inactive">Inactive</button>
        </div>
      </div>
    </div>

    <!-- Shifts Cards Grid -->
    <div id="shifts-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 340px), 1fr)); gap: 1.5rem;">
      <!-- Shift cards rendered dynamically -->
    </div>
  `,setTimeout(()=>{O(t)},0),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1F552}",label:"Shift Actions",color:"var(--color-primary, #6c5ce7)",actions:[{icon:"\u2795",label:"Add Shift",onClick:()=>{C()}},{icon:"\u{1FA91}",label:"Seating Hub",onClick:()=>{window.location.hash="#/seats"}}]}),t}async function O(t){const r=t.querySelector("#btn-add-shift");r&&r.addEventListener("click",()=>C());const a=t.querySelector("#shifts-search-input");a&&a.addEventListener("input",i=>{k=i.target.value.toLowerCase().trim(),S()});const e=t.querySelectorAll(".btn-filter");e.forEach(i=>{i.addEventListener("click",()=>{e.forEach(d=>{d.classList.remove("btn-primary"),d.classList.add("btn-outline")}),i.classList.add("btn-primary"),i.classList.remove("btn-outline"),x=i.dataset.filter,S()})});const o=t.querySelector("#shifts-grid");o&&(o.addEventListener("click",i=>{const d=i.target.closest(".action-menu-item");if(d){i.preventDefault(),i.stopPropagation();const n=d.dataset.action,c=d.dataset.id,p=m.find(h=>String(h._id||h.id)===String(c));n==="edit"?p&&C(p):n==="clone"?p&&B(p):n==="delete"?N(c):n==="delete-permanent"?W(c):n==="toggle-active"?p&&j(c,!p.isActive):n==="seats"&&(window.location.hash="#/seats");return}const f=i.target.closest(".btn-clone-shift");if(f){i.preventDefault(),i.stopPropagation();const n=f.dataset.id,c=m.find(p=>String(p._id||p.id)===String(n));c&&B(c);return}const y=i.target.closest(".btn-edit-shift");if(y){i.preventDefault(),i.stopPropagation();const n=y.dataset.id,c=m.find(p=>String(p._id||p.id)===String(n));c&&C(c);return}const s=i.target.closest(".btn-delete-shift");if(s){i.preventDefault(),i.stopPropagation();const n=s.dataset.id;N(n);return}}),o.addEventListener("change",i=>{if(i.target.classList.contains("shift-active-toggle")){const d=i.target.dataset.id,f=i.target.checked;j(d,f)}})),await A()}async function A(){const t=document.getElementById("shifts-grid");t&&(!m||m.length===0)&&(t.innerHTML=`
      <div style="grid-column: 1 / -1; padding: 3rem; text-align: center; color: var(--color-text-secondary);">
        <div class="loading-spinner" style="margin: 0 auto 1rem auto;"></div>
        <div>Loading shifts &amp; schedules...</div>
      </div>
    `);try{const[r,a]=await Promise.all([w.get("/api/shifts?all=true"),w.get("/api/shifts/stats")]);r?.success&&r.data&&(m=r.data),a?.success&&a.data&&(E=a.data,V(E)),S()}catch(r){console.error("Failed to load shifts:",r),u.error(r.message||"Failed to load shifts data"),t&&(t.innerHTML=`
        <div style="grid-column: 1 / -1; padding: 3rem; text-align: center; color: var(--color-danger);">
          <p style="font-size: 1.1rem; font-weight: 600;">Unable to load shifts</p>
          <button class="btn btn-outline btn-sm mt-2" onclick="location.reload()">Retry</button>
        </div>
      `)}}function V(t){const r=document.getElementById("stat-total-shifts"),a=document.getElementById("stat-active-shifts"),e=document.getElementById("stat-fullday-shifts"),o=document.getElementById("stat-enrolled-students");r&&(r.textContent=t.total??m.length),a&&(a.textContent=t.active??m.filter(i=>i.isActive).length),e&&(e.textContent=t.fullDay??m.filter(i=>i.code==="FULL").length),o&&(o.textContent=t.totalEnrolled??0)}function S(){const t=document.getElementById("shifts-grid");if(!t)return;let r=m.filter(e=>{if(x==="active"&&!e.isActive||x==="inactive"&&e.isActive)return!1;if(k){const o=e.name?.toLowerCase().includes(k),i=e.code?.toLowerCase().includes(k),d=e.description?.toLowerCase().includes(k);if(!o&&!i&&!d)return!1}return!0});if(r.length===0){t.innerHTML=`
      <div style="grid-column: 1 / -1; padding: 3.5rem 1.5rem; text-align: center; background: var(--color-surface); border: 1px dashed var(--color-border); border-radius: var(--radius-lg);">
        <div style="font-size: 2.5rem; margin-bottom: 0.75rem;">\u{1F552}</div>
        <h3 style="margin: 0 0 0.5rem 0; font-size: 1.2rem; color: var(--color-text-primary); font-weight: 600;">No shifts found</h3>
        <p style="color: var(--color-text-secondary); max-width: 400px; margin: 0 auto 1.25rem auto; font-size: 0.9rem;">
          ${k||x!=="all"?"No shifts match your search and filter criteria.":"Create your first shift schedule to manage library timings."}
        </p>
        ${!k&&x==="all"?`
          <button class="btn btn-primary" onclick="document.getElementById('btn-add-shift').click()">
            Add New Shift
          </button>
        `:""}
      </div>
    `;return}let a="";r.forEach(e=>{const o=q(e.startTime),i=q(e.endTime),d=U(e.startTime,e.endTime),f=E.studentEnrollment?.[e.code]||0,y=e.maxCapacity||0;let s="";if(y>0){const g=Math.min(100,Math.round(f/y*100));let $="var(--color-success)";g>=90?$="var(--color-danger)":g>=70&&($="var(--color-warning-dark)"),s=`
        <div style="margin-top: 12px; background: var(--color-bg-primary); padding: 10px 12px; border-radius: var(--radius-md); border: 1px solid var(--color-border-light);">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; font-size: 0.82rem;">
            <span style="color: var(--color-text-secondary); font-weight: 500;">Capacity Occupancy</span>
            <span style="font-weight: 600; color: var(--color-text-primary);">${f} / ${y} seats (${g}%)</span>
          </div>
          <div style="width: 100%; height: 6px; background: var(--color-border); border-radius: 3px; overflow: hidden;">
            <div style="width: ${g}%; height: 100%; background: ${$}; border-radius: 3px; transition: width 0.4s ease;"></div>
          </div>
        </div>
      `}else s=`
        <div style="margin-top: 12px; background: var(--color-bg-primary); padding: 8px 12px; border-radius: var(--radius-md); border: 1px solid var(--color-border-light); display: flex; justify-content: space-between; align-items: center; font-size: 0.82rem;">
          <span style="color: var(--color-text-secondary); font-weight: 500;">Capacity Limit</span>
          <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 600;">Unlimited / Seat-based</span>
        </div>
      `;const n=Array.isArray(e.daysActive)?e.daysActive.map(g=>g.toLowerCase()):["mon","tue","wed","thu","fri","sat","sun"];let c='<div style="display: flex; gap: 4px; flex-wrap: wrap; margin-top: 10px;">';L.forEach(g=>{n.includes(g.key)?c+=`<span style="padding: 2px 7px; font-size: 0.72rem; font-weight: 600; border-radius: var(--radius-sm); background: var(--color-primary-bg); color: var(--color-primary); border: 1px solid rgba(108, 92, 231, 0.2);">${g.label}</span>`:c+=`<span style="padding: 2px 7px; font-size: 0.72rem; font-weight: 400; border-radius: var(--radius-sm); background: var(--color-bg-secondary); color: var(--color-text-muted); opacity: 0.6;">${g.label}</span>`}),c+="</div>";const p=e.priceMultiplier||1;let h="";p>1?h=`<span class="badge" style="background: rgba(253, 203, 110, 0.2); color: var(--color-warning-dark); font-weight: 600; font-size: 0.75rem;">${p}x Rate</span>`:h='<span class="badge" style="background: var(--color-bg-secondary); color: var(--color-text-secondary); font-weight: 500; font-size: 0.75rem;">1.0x Standard</span>';const F=e.isActive?"":"opacity: 0.65;";a+=`
      <div class="card shift-card hoverable" style="${F} background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; flex-direction: column; justify-content: space-between; box-shadow: var(--shadow-sm); transition: all var(--transition-fast);">
        <div>
          <!-- Header: Name & Code Badge -->
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.85rem; gap: 8px;">
            <div>
              <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary);">${v(e.name)}</h3>
                <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 700; font-size: 0.75rem; letter-spacing: 0.5px;">${v(e.code)}</span>
              </div>
              ${e.description?`<p style="margin: 4px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary); line-height: 1.35;">${v(e.description)}</p>`:""}
            </div>
            ${h}
          </div>

          <!-- Timing Box -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border-light); border-radius: var(--radius-md); padding: 10px 14px; margin-bottom: 0.85rem; display: flex; align-items: center; justify-content: space-between;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <div style="color: var(--color-primary); display: flex; align-items: center;">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="10"></circle>
                  <polyline points="12 6 12 12 16 14"></polyline>
                </svg>
              </div>
              <div>
                <div style="font-size: 0.98rem; font-weight: 700; color: var(--color-text-primary); letter-spacing: -0.2px;">
                  ${o} &mdash; ${i}
                </div>
                <div style="font-size: 0.76rem; color: var(--color-text-secondary); margin-top: 1px;">
                  24h: ${v(e.startTime)} to ${v(e.endTime)}
                </div>
              </div>
            </div>
            <span class="badge" style="background: var(--color-surface); color: var(--color-text-primary); border: 1px solid var(--color-border); font-weight: 600; font-size: 0.78rem;">
              ${d}
            </span>
          </div>

          <!-- Active Days -->
          <div>
            <div style="font-size: 0.78rem; font-weight: 500; color: var(--color-text-secondary); margin-bottom: 2px;">Active Days:</div>
            ${c}
          </div>

          <!-- Capacity Indicator -->
          ${s}
        </div>

        <!-- Footer Actions -->
        <div style="margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid var(--color-divider); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
          <!-- Active Toggle -->
          <div style="display: flex; align-items: center; gap: 8px;">
            <input type="checkbox" class="form-toggle shift-active-toggle" id="toggle-${e._id}" data-id="${e._id}" ${e.isActive?"checked":""} style="cursor: pointer;">
            <label for="toggle-${e._id}" style="font-size: 0.82rem; font-weight: 500; color: var(--color-text-secondary); margin: 0; cursor: pointer;">
              ${e.isActive?"Active":"Disabled"}
            </label>
          </div>

          <!-- Action Buttons -->
          <div class="btn-icon-group">
            <a href="#/seats" class="btn-icon-action action-receipt" data-tooltip="View Shift Desks Matrix" aria-label="Seats">
              \u{1F4BA}
            </a>
            <button type="button" class="btn-icon-action action-view btn-clone-shift" data-id="${e._id}" data-tooltip="Clone Shift Configuration" aria-label="Clone">
              \u{1F4D1}
            </button>
            <button type="button" class="btn-icon-action action-edit btn-edit-shift" data-id="${e._id}" data-tooltip="Edit Shift Details" aria-label="Edit">
              \u270F\uFE0F
            </button>
            <button type="button" class="btn-icon-action action-delete btn-delete-shift" data-id="${e._id}" data-tooltip="Delete Shift" aria-label="Delete">
              \u{1F5D1}\uFE0F
            </button>
            ${typeof D<"u"?D.renderHtml([{header:"Shift Options"},{icon:"\u270F\uFE0F",label:"Edit Shift Details",action:"edit",bold:!0},{icon:"\u{1F4D1}",label:"Clone Shift Configuration",action:"clone"},{icon:"\u{1F4BA}",label:"View Shift Seats Grid",action:"seats"},{icon:e.isActive?"\u23F8\uFE0F":"\u25B6\uFE0F",label:e.isActive?"Deactivate Shift":"Activate Shift",action:"toggle-active"},{divider:!0},{icon:"\u{1F5D1}\uFE0F",label:"Delete Shift (Move to Trash)",action:"delete",danger:!0},{icon:"\u{1F4A5}",label:"Permanently Erase Shift",action:"delete-permanent",danger:!0}],e._id):""}
          </div>
        </div>
      </div>
    `}),t.innerHTML=a}function B(t){const r={...t,_id:null,name:`${t.name} (Copy)`,code:`${t.code}_CPY`.slice(0,10)};C(r)}function C(t=null){const r=!!(t&&t._id),a=r?l("Edit Shift"):l("Add New Shift"),e=r&&Array.isArray(t.daysActive)?t.daysActive:["mon","tue","wed","thu","fri","sat","sun"];let o='<div style="display: flex; gap: 8px; flex-wrap: wrap;">';L.forEach(s=>{const n=e.includes(s.key)?"checked":"";o+=`
      <label class="day-checkbox-label" style="cursor: pointer; display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md); font-size: 0.85rem; font-weight: 500; user-select: none;">
        <input type="checkbox" name="daysActive" value="${s.key}" ${n} style="cursor: pointer; width: 15px; height: 15px;">
        <span>${s.label}</span>
      </label>
    `}),o+="</div>";const i=document.createElement("div");i.innerHTML=`
    <form id="shift-form" style="display: flex; flex-direction: column; gap: 1rem;">
      <input type="hidden" id="shift-modal-id" value="${r?v(t._id):""}">
      
      <!-- Name & Code -->
      <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 1rem;">
        <div>
          <label for="shift-modal-name" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${l("Shift Name")} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="text" id="shift-modal-name" class="form-control" required placeholder="e.g. Morning Shift, Full Day" value="${r?v(t.name):""}">
        </div>
        <div>
          <label for="shift-modal-code" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${l("Code")} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="text" id="shift-modal-code" class="form-control" required maxlength="10" placeholder="e.g. MORN" value="${r?v(t.code):""}" style="text-transform: uppercase; font-weight: 600; letter-spacing: 0.5px;">
        </div>
      </div>

      <!-- Start Time & End Time -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 1rem;">
        <div>
          <label for="shift-modal-start" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${l("Start Time")} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="time" id="shift-modal-start" class="form-control" required value="${r?v(t.startTime):"06:00"}">
        </div>
        <div>
          <label for="shift-modal-end" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${l("End Time")} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="time" id="shift-modal-end" class="form-control" required value="${r?v(t.endTime):"14:00"}">
        </div>
      </div>

      <!-- Capacity & Price Multiplier -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 1rem;">
        <div>
          <label for="shift-modal-capacity" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${l("Max Capacity")}
          </label>
          <input type="number" id="shift-modal-capacity" class="form-control" min="0" placeholder="0 = Unlimited" value="${r&&t.maxCapacity||0}">
          <small style="font-size: 0.75rem; color: var(--color-text-muted); display: block; margin-top: 2px;">Set 0 for unlimited / seat-based</small>
        </div>
        <div>
          <label for="shift-modal-multiplier" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${l("Price Multiplier")}
          </label>
          <input type="number" id="shift-modal-multiplier" class="form-control" step="0.1" min="0.1" max="5.0" value="${r?t.priceMultiplier??1:1}">
          <small style="font-size: 0.75rem; color: var(--color-text-muted); display: block; margin-top: 2px;">e.g. 1.0 = base rate, 1.5 = +50%</small>
        </div>
      </div>

      <!-- Days Active -->
      <div>
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
          <label class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin: 0;">
            ${l("Active Days")}
          </label>
          <div style="display: flex; gap: 6px;">
            <button type="button" id="btn-select-all-days" class="btn btn-ghost btn-sm" style="font-size: 0.72rem; padding: 2px 6px;">All Days</button>
            <button type="button" id="btn-select-weekdays" class="btn btn-ghost btn-sm" style="font-size: 0.72rem; padding: 2px 6px;">Weekdays</button>
          </div>
        </div>
        ${o}
      </div>

      <!-- Description -->
      <div>
        <label for="shift-modal-description" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
          ${l("Description")}
        </label>
        <textarea id="shift-modal-description" class="form-control" rows="2" placeholder="Brief notes or timing highlights...">${r?v(t.description||""):""}</textarea>
      </div>

      <!-- Active Checkbox -->
      <div style="display: flex; align-items: center; gap: 8px; margin-top: 4px;">
        <input type="checkbox" id="shift-modal-active" ${!r||t.isActive?"checked":""} style="cursor: pointer; width: 16px; height: 16px;">
        <label for="shift-modal-active" style="cursor: pointer; margin: 0; font-size: 0.88rem; font-weight: 500; color: var(--color-text-primary);">
          ${l("Shift is active and available for student allocation")}
        </label>
      </div>
    </form>
  `;const d=i.querySelector("#btn-select-all-days");d&&(d.onclick=()=>{i.querySelectorAll('input[name="daysActive"]').forEach(s=>s.checked=!0)});const f=i.querySelector("#btn-select-weekdays");f&&(f.onclick=()=>{i.querySelectorAll('input[name="daysActive"]').forEach(s=>{s.checked=["mon","tue","wed","thu","fri"].includes(s.value)})});const y=i.querySelector("#shift-modal-code");y&&y.addEventListener("input",s=>{s.target.value=s.target.value.toUpperCase()}),H.show({title:a,content:i,size:"md",buttons:[{text:l("Cancel"),className:"btn-secondary",onClick:s=>s.close()},{text:r?l("Update Shift"):l("Create Shift"),className:"btn-primary",onClick:async s=>{const n=i.querySelector("#shift-form");if(!n.checkValidity()){n.reportValidity();return}const c=i.querySelector("#shift-modal-name").value.trim(),p=i.querySelector("#shift-modal-code").value.trim().toUpperCase(),h=i.querySelector("#shift-modal-start").value.trim(),F=i.querySelector("#shift-modal-end").value.trim(),g=parseInt(i.querySelector("#shift-modal-capacity").value,10)||0,$=parseFloat(i.querySelector("#shift-modal-multiplier").value)||1,_=i.querySelector("#shift-modal-description").value.trim(),P=i.querySelector("#shift-modal-active").checked,z=Array.from(i.querySelectorAll('input[name="daysActive"]:checked')).map(b=>b.value),I=z.length>0?z:["mon","tue","wed","thu","fri","sat","sun"];if(!c||!p||!h||!F){u.error("Please fill in all required fields (Name, Code, Start Time, End Time)");return}const T={name:c,code:p,startTime:h,endTime:F,maxCapacity:g,priceMultiplier:$,daysActive:I,description:_,isActive:P};try{let b;r?b=await w.put(`/api/shifts/${t._id}`,T):b=await w.post("/api/shifts",T),b.success?(u.success(b.message||(r?"Shift updated successfully":"Shift created successfully")),s.close(),await A()):u.error(b.message||"Failed to save shift")}catch(b){u.error(b.message||"Failed to save shift")}}}]})}async function j(t,r){try{const a=await w.put(`/api/shifts/${t}`,{isActive:r});if(a.success){u.success(r?"Shift activated":"Shift deactivated");const e=m.find(o=>o._id===t);e&&(e.isActive=r),await A()}else u.error(a.message||"Failed to update shift status"),S()}catch(a){u.error(a.message||"Failed to update shift status"),S()}}async function N(t){const r=m.find(e=>String(e._id||e.id)===String(t)),a=r?r.name:"this shift";M.show({title:l("Delete Shift"),message:`Are you sure you want to delete "${v(a)}"? It will be moved to the Recycle Bin (Trash) and removed from shift selection.`,confirmText:"Delete Shift",cancelText:"Cancel",danger:!0,onConfirm:async()=>{try{const e=await w.delete(`/api/shifts/${t}`);e&&e.success!==!1?(u.success(e.message||`Shift "${a}" deleted successfully`),m=m.filter(o=>String(o._id||o.id)!==String(t)),S(),await A()):u.error(e?.message||"Failed to delete shift")}catch(e){u.error(e.message||"Failed to delete shift")}}})}async function W(t){const r=m.find(e=>String(e._id||e.id)===String(t)),a=r?r.name:"this shift";M.show({title:l("Permanently Erase Shift"),message:`\u26A0\uFE0F Warning: This will PERMANENTLY DESTROY "${v(a)}" from the database. This action CANNOT be undone! Are you sure?`,confirmText:"Permanently Erase",cancelText:"Cancel",danger:!0,onConfirm:async()=>{try{const e=await w.delete(`/api/shifts/${t}?permanent=true`);e&&e.success!==!1?(u.success(e.message||`Shift "${a}" permanently erased`),m=m.filter(o=>String(o._id||o.id)!==String(t)),S(),await A()):u.error(e?.message||"Failed to permanently delete shift")}catch(e){u.error(e.message||"Failed to permanently delete shift")}}})}export{R as render};
