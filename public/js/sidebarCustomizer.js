import p from"./api.js";import{Toast as f,Modal as i,BottomSheet as l}from"./ui.js";const c=[{key:"dashboard",href:"#/dashboard",label:"Dashboard",icon:"\u{1F4CA}",isEnabled:!0},{key:"students",href:"#/students",label:"Students",icon:"\u{1F393}",isEnabled:!0},{key:"seats",href:"#/seats",label:"Seats",icon:"\u{1FA91}",isEnabled:!0},{key:"plans",href:"#/plans",label:"Plans",icon:"\u{1F4E6}",isEnabled:!0},{key:"lockers",href:"#/lockers",label:"Lockers",icon:"\u{1F510}",isEnabled:!0},{key:"payments",href:"#/payments",label:"Payments",icon:"\u{1F4B3}",isEnabled:!0},{key:"attendance",href:"#/attendance",label:"Attendance",icon:"\u{1F4C5}",isEnabled:!0},{key:"shifts",href:"#/shifts",label:"Shifts",icon:"\u23F0",isEnabled:!0},{key:"branches",href:"#/branches",label:"Branches",icon:"\u{1F3E2}",isEnabled:!1},{key:"reports",href:"#/reports",label:"Reports",icon:"\u{1F4C8}",isEnabled:!0},{key:"expenses",href:"#/expenses",label:"Expenses (P&L)",icon:"\u{1F4B8}",isEnabled:!0},{key:"operations",href:"#/operations",label:"Operations",icon:"\u2699\uFE0F",isEnabled:!0},{key:"trash",href:"#/trash",label:"Recycle Bin",icon:"\u{1F5D1}\uFE0F",isEnabled:!0},{key:"settings",href:"#/settings",label:"Settings",icon:"\u{1F6E0}\uFE0F",isEnabled:!0},{key:"profile",href:"#/profile",label:"My Profile",icon:"\u{1F464}",isEnabled:!0}],m={default:{name:"Standard Default",keys:["dashboard","students","seats","plans","lockers","payments","attendance","shifts","reports","expenses","operations","trash","settings","profile"]},frontdesk:{name:"Front Desk Essential",keys:["dashboard","students","seats","payments","attendance","settings","profile"]},all:{name:"All Modules Active",keys:["dashboard","students","seats","plans","lockers","payments","attendance","shifts","branches","reports","expenses","operations","trash","settings","profile"]}},g=["\u{1F4CA}","\u{1F393}","\u{1FA91}","\u{1F4E6}","\u{1F510}","\u{1F4B3}","\u{1F4C5}","\u23F0","\u{1F3E2}","\u{1F4C8}","\u{1F4B8}","\u2699\uFE0F","\u{1F5D1}\uFE0F","\u{1F6E0}\uFE0F","\u{1F464}","\u{1F4DA}","\u26A1","\u{1F4BC}","\u{1F4CC}","\u{1F514}","\u{1F3F7}\uFE0F","\u{1F3AF}"];class v{constructor(){this.items=[],this.modalInstance=null,this.userRole="staff",this.saveScope="global"}async open(){try{const t=localStorage.getItem("sl_user");if(t){const e=JSON.parse(t);this.userRole=e.role||"staff"}}catch{}if(typeof window<"u"&&!window.Sortable)try{const{loadSortable:t}=await import("./dragDrop.js");typeof t=="function"&&await t()}catch{}await this.loadConfig(),this.render()}async loadConfig(){try{const t=await p.get("/api/settings/sidebar/all");if(t&&t.success&&Array.isArray(t.data)&&t.data.length>0)this.items=t.data.map((e,s)=>({key:e.key,label:e.label||e.key,href:e.href||`#/${e.key}`,icon:this.formatIcon(e.icon,e.key),isEnabled:e.isEnabled!==!1,order:e.order!==void 0?e.order:s+1}));else{const e=await p.get("/api/settings/sidebar");if(e&&e.success&&Array.isArray(e.data)&&e.data.length>0){const s=new Set(e.data.map(o=>o.key)),r=new Map(e.data.map((o,a)=>[o.key,a+1]));this.items=c.map(o=>({...o,isEnabled:s.has(o.key),order:r.get(o.key)||99})).sort((o,a)=>o.order-a.order)}else this.items=JSON.parse(JSON.stringify(c))}}catch(t){console.warn("Could not fetch server sidebar, using defaults:",t.message),this.items=JSON.parse(JSON.stringify(c))}try{const t=localStorage.getItem("sl_sidebar_order_personal")||localStorage.getItem("sl_sidebar_order");if(t){const e=JSON.parse(t);if(Array.isArray(e)&&e.length>0){const s=new Map(e.map((r,o)=>[r.replace("#/",""),o+1]));this.items.forEach(r=>{s.has(r.key)&&(r.order=s.get(r.key))}),this.items.sort((r,o)=>r.order-o.order)}}}catch{}}formatIcon(t,e){if(!t||t.startsWith("<svg")){const s=c.find(r=>r.key===e);return s?s.icon:"\u{1F4CC}"}return t.trim()}render(){const t=["owner","branch_manager","admin"].includes(this.userRole),e=document.createElement("div");e.className="sidebar-customizer-wrap",e.style.cssText="display: flex; flex-direction: column; gap: 14px; max-height: 75vh; overflow-y: auto; padding-right: 4px;",e.innerHTML=`
      <style>
        .sc-module-row {
          display: flex;
          align-items: center;
          gap: 10px;
          background: var(--color-bg-secondary, #f8fafc);
          border: 1px solid var(--color-border, #e2e8f0);
          border-radius: var(--radius-md, 8px);
          padding: 8px 12px;
          transition: all 0.18s ease;
        }
        .sc-module-row:hover {
          border-color: var(--color-primary, #6c5ce7);
          box-shadow: var(--shadow-xs, 0 1px 3px rgba(0,0,0,0.05));
        }
        .sc-module-row.sc-disabled {
          opacity: 0.55;
          background: rgba(0,0,0,0.02);
        }
        .sc-drag-handle {
          cursor: grab;
          font-size: 1.1rem;
          color: var(--color-text-muted, #94a3b8);
          user-select: none;
          touch-action: none;
          padding: 4px 6px;
        }
        .sc-reorder-btn {
          background: transparent;
          border: 1px solid var(--color-border, #cbd5e1);
          border-radius: 4px;
          width: 28px;
          height: 28px;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          font-size: 0.75rem;
          cursor: pointer;
          color: var(--color-text-secondary, #64748b);
          touch-action: manipulation;
          transition: background 0.12s;
        }
        .sc-reorder-btn:hover:not(:disabled) {
          background: var(--color-primary, #6c5ce7);
          color: #fff;
          border-color: var(--color-primary, #6c5ce7);
        }
        .sc-reorder-btn:disabled {
          opacity: 0.3;
          cursor: not-allowed;
        }
        .sc-icon-btn {
          font-size: 1.25rem;
          background: var(--color-surface, #fff);
          border: 1px solid var(--color-border, #cbd5e1);
          border-radius: 6px;
          width: 38px;
          height: 38px;
          display: inline-flex;
          align-items: center;
          justify-content: center;
          cursor: pointer;
          flex-shrink: 0;
          transition: transform 0.1s;
        }
        .sc-icon-btn:hover {
          transform: scale(1.08);
          border-color: var(--color-primary, #6c5ce7);
        }
        .sc-rename-input {
          flex: 1;
          font-size: 0.88rem;
          font-weight: 600;
          padding: 6px 10px;
          border-radius: 6px;
          border: 1px solid var(--color-border, #cbd5e1);
          background: var(--color-surface, #fff);
          color: var(--color-text-primary, #1e293b);
          min-width: 120px;
        }
        .sc-rename-input:focus {
          border-color: var(--color-primary, #6c5ce7);
          outline: none;
          box-shadow: 0 0 0 2px rgba(108, 92, 231, 0.2);
        }
        .sc-preset-chip {
          font-size: 0.76rem;
          font-weight: 700;
          padding: 4px 10px;
          border-radius: 20px;
          border: 1px solid var(--color-border, #cbd5e1);
          background: var(--color-surface, #fff);
          cursor: pointer;
          display: inline-flex;
          align-items: center;
          gap: 4px;
          transition: all 0.15s;
        }
        .sc-preset-chip:hover {
          background: rgba(108, 92, 231, 0.1);
          border-color: var(--color-primary, #6c5ce7);
          color: var(--color-primary, #6c5ce7);
        }
      </style>

      <!-- Description Header & Presets -->
      <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.18); border-radius: var(--radius-md, 8px); padding: 10px 14px;">
        <div style="font-size: 0.84rem; color: var(--color-text-primary, #1e293b); font-weight: 600; margin-bottom: 6px;">
          \u26A1 <strong>Customize Your Navigation</strong>: Toggle modules on/off, rename titles, change icons, and reorder with buttons or drag handles.
        </div>
        <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
          <span style="font-size: 0.75rem; font-weight: 700; color: var(--color-text-muted, #64748b);">Quick Presets:</span>
          <button type="button" class="sc-preset-chip" data-preset="default">\u{1F3DB}\uFE0F Standard Default</button>
          <button type="button" class="sc-preset-chip" data-preset="frontdesk">\u{1F6CE}\uFE0F Front Desk Essential</button>
          <button type="button" class="sc-preset-chip" data-preset="all">\u2728 Enable All</button>
        </div>
      </div>

      <!-- Scope Selector for Owners / Managers -->
      ${t?`
      <div style="display: flex; align-items: center; justify-content: space-between; background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px;">
        <div>
          <strong style="font-size: 0.85rem; color: var(--color-text-primary);">Save Scope</strong>
          <div class="text-muted small" style="font-size: 0.72rem;">Choose who sees this custom navigation layout</div>
        </div>
        <div class="btn-group" role="group" style="display: inline-flex;">
          <button type="button" class="btn btn-xs ${this.saveScope==="global"?"btn-primary":"btn-outline-secondary"} sc-scope-btn" data-scope="global" style="font-weight: 700; font-size: 0.75rem; padding: 4px 10px;">
            \u{1F310} Everyone (Global)
          </button>
          <button type="button" class="btn btn-xs ${this.saveScope==="personal"?"btn-primary":"btn-outline-secondary"} sc-scope-btn" data-scope="personal" style="font-weight: 700; font-size: 0.75rem; padding: 4px 10px;">
            \u{1F464} Personal (Only Me)
          </button>
        </div>
      </div>
      `:""}

      <!-- Interactive Module List -->
      <div id="sc-items-container" style="display: flex; flex-direction: column; gap: 8px;">
        ${this.renderItemsHtml()}
      </div>

      <!-- Footer Buttons -->
      <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 10px; border-top: 1px solid var(--color-border); padding-top: 12px; flex-wrap: wrap; gap: 8px;">
        <button type="button" id="sc-btn-reset" class="btn btn-sm btn-outline-danger" style="font-weight: 700; font-size: 0.82rem; display: inline-flex; align-items: center; gap: 4px;">
          \u21BA Reset Defaults
        </button>
        <div style="display: flex; gap: 8px; align-items: center;">
          <button type="button" id="sc-btn-cancel" class="btn btn-sm btn-secondary" style="font-weight: 700; font-size: 0.82rem;">
            Cancel
          </button>
          <button type="button" id="sc-btn-save" class="btn btn-sm btn-primary" style="font-weight: 800; font-size: 0.85rem; padding: 6px 18px; display: inline-flex; align-items: center; gap: 6px;">
            \u{1F4BE} Save & Apply
          </button>
        </div>
      </div>
    `,this.bindEvents(e),window.innerWidth<=768&&typeof l<"u"&&l.show?this.modalInstance=l.show({title:"\u{1F3A8} Customize Sidebar Navigation",content:e,height:"85vh"}):typeof i<"u"&&i.show&&(this.modalInstance=i.show({title:"\u{1F3A8} Customize Sidebar Navigation",content:e,size:"lg"}))}renderItemsHtml(){return this.items.map((t,e)=>{const s=e===0,r=e===this.items.length-1;return`
        <div class="sc-module-row ${t.isEnabled?"":"sc-disabled"}" data-key="${t.key}" data-index="${e}">
          <!-- Drag Handle -->
          <span class="sc-drag-handle" title="Drag to reorder">\u2630</span>

          <!-- Up/Down Buttons for Mobile -->
          <div style="display: flex; flex-direction: column; gap: 2px;">
            <button type="button" class="sc-reorder-btn sc-btn-up" data-index="${e}" ${s?"disabled":""} title="Move Up">\u25B2</button>
            <button type="button" class="sc-reorder-btn sc-btn-down" data-index="${e}" ${r?"disabled":""} title="Move Down">\u25BC</button>
          </div>

          <!-- Icon / Emoji -->
          <button type="button" class="sc-icon-btn" data-key="${t.key}" title="Tap to change icon">
            ${t.icon||"\u{1F4CC}"}
          </button>

          <!-- Label Rename Input -->
          <input type="text" class="sc-rename-input" data-key="${t.key}" value="${t.label||t.key}" placeholder="${t.key}">

          <!-- Visibility Toggle -->
          <div class="form-check form-switch mb-0" style="font-size: 1.15rem; margin-left: auto;">
            <input class="form-check-input sc-toggle-switch" type="checkbox" data-key="${t.key}" ${t.isEnabled?"checked":""} title="Turn on/off in navigation">
          </div>
        </div>
      `}).join("")}refreshList(t){t.innerHTML=this.renderItemsHtml(),this.bindRowEvents(t)}bindEvents(t){const e=t.querySelector("#sc-items-container");t.querySelectorAll(".sc-preset-chip").forEach(s=>{s.addEventListener("click",()=>{const r=s.dataset.preset;this.applyPreset(r),this.refreshList(e)})}),t.querySelectorAll(".sc-scope-btn").forEach(s=>{s.addEventListener("click",()=>{this.saveScope=s.dataset.scope,t.querySelectorAll(".sc-scope-btn").forEach(r=>{r.className=`btn btn-xs ${r.dataset.scope===this.saveScope?"btn-primary":"btn-outline-secondary"} sc-scope-btn`})})}),t.querySelector("#sc-btn-reset")?.addEventListener("click",async()=>{confirm("Reset navigation layout to default factory order?")&&(this.items=JSON.parse(JSON.stringify(c)),this.refreshList(e))}),t.querySelector("#sc-btn-cancel")?.addEventListener("click",()=>{this.closeModal()}),t.querySelector("#sc-btn-save")?.addEventListener("click",async()=>{const s=t.querySelector("#sc-btn-save");s&&(s.disabled=!0);try{await this.saveChanges(),this.closeModal()}catch(r){f.error(r.message||"Failed to save navigation changes.")}finally{s&&(s.disabled=!1)}}),this.bindRowEvents(e)}bindRowEvents(t){if(typeof window<"u"&&window.Sortable&&t)try{this._sortableInst&&this._sortableInst.destroy(),this._sortableInst=window.Sortable.create(t,{handle:".sc-drag-handle",animation:180,ghostClass:"sortable-ghost",chosenClass:"sortable-chosen",onEnd:()=>{const e=Array.from(t.querySelectorAll(".sc-module-row")),s=new Map(e.map((r,o)=>[r.dataset.key,o]));this.items.sort((r,o)=>{const a=s.has(r.key)?s.get(r.key):999,n=s.has(o.key)?s.get(o.key):999;return a-n}),this.refreshList(t)}})}catch{}t.querySelectorAll(".sc-btn-up").forEach(e=>{e.addEventListener("click",()=>{const s=parseInt(e.dataset.index,10);if(s>0){const r=this.items[s];this.items[s]=this.items[s-1],this.items[s-1]=r,this.refreshList(t)}})}),t.querySelectorAll(".sc-btn-down").forEach(e=>{e.addEventListener("click",()=>{const s=parseInt(e.dataset.index,10);if(s<this.items.length-1){const r=this.items[s];this.items[s]=this.items[s+1],this.items[s+1]=r,this.refreshList(t)}})}),t.querySelectorAll(".sc-rename-input").forEach(e=>{e.addEventListener("input",()=>{const s=e.dataset.key,r=this.items.find(o=>o.key===s);r&&(r.label=e.value.trim())})}),t.querySelectorAll(".sc-toggle-switch").forEach(e=>{e.addEventListener("change",()=>{const s=e.dataset.key,r=this.items.find(o=>o.key===s);if(r){r.isEnabled=e.checked;const o=e.closest(".sc-module-row");o&&o.classList.toggle("sc-disabled",!e.checked)}})}),t.querySelectorAll(".sc-icon-btn").forEach(e=>{e.addEventListener("click",s=>{s.stopPropagation(),this.openEmojiPicker(e)})})}openEmojiPicker(t){const e=document.getElementById("sc-emoji-picker-dropdown");e&&e.remove();const s=document.createElement("div");s.id="sc-emoji-picker-dropdown",s.style.cssText=`
      position: fixed;
      z-index: 9999999;
      background: var(--color-surface, #fff);
      border: 1px solid var(--color-border, #cbd5e1);
      border-radius: 12px;
      box-shadow: 0 10px 25px rgba(0,0,0,0.25);
      padding: 10px;
      display: grid;
      grid-template-columns: repeat(6, 1fr);
      gap: 6px;
      max-width: 250px;
    `,g.forEach(a=>{const n=document.createElement("button");n.type="button",n.textContent=a,n.style.cssText="font-size: 1.25rem; border: none; background: transparent; cursor: pointer; border-radius: 6px; padding: 4px; transition: background 0.1s;",n.onmouseenter=()=>{n.style.background="rgba(108, 92, 231, 0.15)"},n.onmouseleave=()=>{n.style.background="transparent"},n.onclick=d=>{d.stopPropagation(),t.textContent=a;const h=t.dataset.key,b=this.items.find(y=>y.key===h);b&&(b.icon=a),s.remove()},s.appendChild(n)}),document.body.appendChild(s);const r=t.getBoundingClientRect();s.style.left=`${Math.min(window.innerWidth-260,Math.max(10,r.left))}px`,s.style.top=`${r.bottom+6}px`;const o=a=>{!s.contains(a.target)&&a.target!==t&&(s.remove(),document.removeEventListener("click",o))};setTimeout(()=>document.addEventListener("click",o),10)}applyPreset(t){const e=m[t];if(e)if(t==="all")this.items.forEach(s=>{s.isEnabled=!0});else{const s=new Set(e.keys);this.items.forEach(o=>{o.isEnabled=s.has(o.key)});const r=new Map(e.keys.map((o,a)=>[o,a]));this.items.sort((o,a)=>{const n=r.has(o.key)?r.get(o.key):999,d=r.has(a.key)?r.get(a.key):999;return n-d})}}async saveChanges(){const t=this.items.map((e,s)=>({key:e.key,label:e.label,href:e.href,icon:e.icon,isEnabled:e.isEnabled,order:s+1}));try{const e=t.filter(s=>s.isEnabled).map(s=>s.href);localStorage.setItem("sl_sidebar_order",JSON.stringify(e)),localStorage.setItem("sl_sidebar_order_personal",JSON.stringify(e)),localStorage.setItem("sl_sidebar_custom_items",JSON.stringify(t))}catch{}if(this.saveScope==="global"&&["owner","branch_manager","admin"].includes(this.userRole))try{const e=await p.put("/api/settings/sidebar",{items:t});if(!e||!e.success)throw new Error(e?.message||"Failed to update global sidebar")}catch(e){console.warn("Could not save globally, saved locally:",e.message)}f.success("Navigation layout updated successfully!"),typeof window.reloadSidebar=="function"?window.reloadSidebar():window.App&&typeof window.App.updateSidebarForRole=="function"&&window.App.updateSidebarForRole()}closeModal(){this.modalInstance&&(typeof this.modalInstance.close=="function"?this.modalInstance.close():typeof l<"u"&&l.close?l.close():typeof i<"u"&&i.closeAll&&i.closeAll(),this.modalInstance=null)}}const u=new v;window.SidebarCustomizer=u;var E=u;export{E as default};
