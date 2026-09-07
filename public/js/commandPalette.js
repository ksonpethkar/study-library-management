import{escapeHTML as r}from"./ui.js";const a={isOpen:!1,commands:[{id:"new_student",title:"Add New Student Admission",category:"Actions",icon:"\u{1F464}",shortcut:"Alt+N",href:"#/students?action=new"},{id:"collect_fee",title:"Collect Fee / New Payment",category:"Actions",icon:"\u{1F4B5}",shortcut:"Alt+P",href:"#/payments?action=new"},{id:"attendance_kiosk",title:"Open Attendance Kiosk",category:"Actions",icon:"\u{1F552}",href:"/kiosk",external:!0},{id:"view_seats",title:"Study Desks & Live Seat Map",category:"Navigation",icon:"\u{1F4BA}",href:"#/seats"},{id:"open_trash",title:"Recycle Bin & Trash Management",category:"System",icon:"\u{1F5D1}\uFE0F",href:"#/trash"},{id:"view_reports",title:"Financial Reports & GST Summary",category:"Navigation",icon:"\u{1F4CA}",href:"#/reports"},{id:"form_builder",title:"Dynamic Form Builder & Custom Fields",category:"System",icon:"\u{1F4DD}",href:"#/settings?tab=form-builder"},{id:"system_settings",title:"Business Profile & Branding Settings",category:"System",icon:"\u2699\uFE0F",href:"#/settings"},{id:"expenses",title:"Expense Tracker & P&L",category:"Navigation",icon:"\u{1F4B8}",href:"#/expenses"},{id:"lockers",title:"Locker Allocation Studio",category:"Navigation",icon:"\u{1F512}",href:"#/lockers"},{id:"operations",title:"Notice Board & Daily Visitors",category:"Navigation",icon:"\u{1F4E2}",href:"#/operations"}],init(){this._createDOM(),this._attachListeners()},_createDOM(){if(document.getElementById("sl-command-palette-overlay"))return;const e=document.createElement("div");e.id="sl-command-palette-overlay",e.style.cssText=`
      position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
      background: rgba(15, 23, 42, 0.7); backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px);
      z-index: 10000; display: none; align-items: flex-start; justify-content: center;
      padding-top: 10vh; opacity: 0; transition: opacity 0.15s ease-out;
    `,e.innerHTML=`
      <div id="sl-command-palette" style="
        width: 100%; max-width: 600px; background: var(--color-surface, #ffffff);
        border: 1px solid var(--color-border, #e2e8f0); border-radius: 14px;
        box-shadow: 0 20px 40px -10px rgba(0, 0, 0, 0.35); overflow: hidden;
        display: flex; flex-direction: column; transform: translateY(-10px); transition: transform 0.15s ease-out;
      ">
        <div style="display: flex; align-items: center; padding: 14px 18px; border-bottom: 1px solid var(--color-border, #e2e8f0); gap: 12px;">
          <span style="font-size: 1.25rem;">\u26A1</span>
          <input type="text" id="sl-cmd-input" placeholder="Type a command or search students..." autocomplete="off" style="
            flex: 1; border: none; outline: none; background: transparent;
            font-size: 1.05rem; font-weight: 500; color: var(--color-text-primary, #1e293b);
          ">
          <span style="font-size: 0.75rem; background: var(--color-bg-secondary, #f1f5f9); color: var(--color-text-secondary, #64748b); padding: 3px 8px; border-radius: 6px; font-weight: 600;">ESC</span>
        </div>
        <div id="sl-cmd-results" style="max-height: 380px; overflow-y: auto; padding: 8px 0;"></div>
        <div style="padding: 10px 18px; background: var(--color-bg-secondary, #f8fafc); border-top: 1px solid var(--color-border, #e2e8f0); display: flex; justify-content: space-between; align-items: center; font-size: 0.75rem; color: var(--color-text-secondary, #64748b);">
          <span>Navigate: <strong>\u2191</strong> <strong>\u2193</strong> \u2022 Select: <strong>\u21B5 Enter</strong></span>
          <span>Quick Actions & Search</span>
        </div>
      </div>
    `,document.body.appendChild(e),e.addEventListener("click",t=>{t.target===e&&this.close()});const o=document.getElementById("sl-cmd-input");o.addEventListener("input",()=>this._onInput(o.value)),o.addEventListener("keydown",t=>this._onKeyDown(t))},_attachListeners(){window.addEventListener("keydown",e=>{(e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==="k"?(e.preventDefault(),this.toggle()):e.key==="Escape"&&this.isOpen&&this.close()}),document.addEventListener("click",e=>{(e.target.closest("#header-search-btn")||e.target.closest(".global-search-trigger"))&&this.open()})},open(){const e=document.getElementById("sl-command-palette-overlay"),o=document.getElementById("sl-cmd-input");!e||!o||(this.isOpen=!0,e.style.display="flex",requestAnimationFrame(()=>{e.style.opacity="1";const t=document.getElementById("sl-command-palette");t&&(t.style.transform="translateY(0)")}),o.value="",this._renderItems(this.commands),setTimeout(()=>o.focus(),50))},close(){const e=document.getElementById("sl-command-palette-overlay");if(!e)return;this.isOpen=!1,e.style.opacity="0";const o=document.getElementById("sl-command-palette");o&&(o.style.transform="translateY(-10px)"),setTimeout(()=>{e.style.display="none"},150)},toggle(){this.isOpen?this.close():this.open()},_onInput(e){const o=(e||"").trim().toLowerCase();if(!o){this._renderItems(this.commands);return}const t=this.commands.filter(n=>n.title.toLowerCase().includes(o)||n.category.toLowerCase().includes(o));this._renderItems(t),o.length>=2&&this._searchStudentsAsync(o)},async _searchStudentsAsync(e){try{const o=localStorage.getItem("sl_token");if(!o)return;const t=await(await fetch(`/api/students?search=${encodeURIComponent(e)}&limit=5`,{headers:{Authorization:`Bearer ${o}`}})).json();if(t.success&&Array.isArray(t.data?.students)&&t.data.students.length>0){const n=t.data.students.map(s=>({id:`student_${s._id}`,title:`${s.name} (${s.studentId||"ID"})`,category:"Students",icon:"\u{1F393}",subtitle:`\u{1F4F1} ${s.phone||"No Phone"} \u2022 Status: ${(s.status||"active").toUpperCase()}`,href:`#/students?search=${encodeURIComponent(s.studentId||s.phone||s.name)}`}));if(document.getElementById("sl-cmd-input")?.value?.trim().toLowerCase()===e){const s=this.commands.filter(i=>i.title.toLowerCase().includes(e));this._renderItems([...s,...n])}}}catch{}},_renderItems(e){const o=document.getElementById("sl-cmd-results");if(o){if(!e||e.length===0){o.innerHTML=`
        <div style="padding: 2rem 1rem; text-align: center; color: var(--color-text-secondary, #64748b);">
          <div style="font-size: 1.75rem; margin-bottom: 6px;">\u{1F50D}</div>
          <div>No matching actions or records found</div>
        </div>
      `;return}o.innerHTML=e.map((t,n)=>`
      <div class="sl-cmd-item ${n===0?"selected":""}" data-idx="${n}" data-href="${t.href||""}" data-ext="${t.external?"1":"0"}" style="
        display: flex; align-items: center; padding: 10px 18px; cursor: pointer;
        border-left: 3px solid ${n===0?"var(--color-primary, #6c5ce7)":"transparent"};
        background: ${n===0?"var(--color-bg-secondary, #f8fafc)":"transparent"};
        transition: background 0.1s, border-color 0.1s; gap: 12px;
      ">
        <span style="font-size: 1.25rem;">${t.icon||"\u{1F4CC}"}</span>
        <div style="flex: 1; min-width: 0;">
          <div style="font-size: 0.92rem; font-weight: 600; color: var(--color-text-primary, #1e293b); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
            ${r(t.title)}
          </div>
          ${t.subtitle?`<div style="font-size: 0.75rem; color: var(--color-text-secondary, #64748b);">${r(t.subtitle)}</div>`:""}
        </div>
        <span style="font-size: 0.72rem; color: var(--color-text-secondary, #94a3b8); background: var(--color-surface, #fff); border: 1px solid var(--color-border, #e2e8f0); padding: 2px 6px; border-radius: 4px;">
          ${t.category||"Action"}
        </span>
      </div>
    `).join(""),o.querySelectorAll(".sl-cmd-item").forEach(t=>{t.addEventListener("mouseenter",()=>{o.querySelectorAll(".sl-cmd-item").forEach(n=>{n.classList.remove("selected"),n.style.background="transparent",n.style.borderLeftColor="transparent"}),t.classList.add("selected"),t.style.background="var(--color-bg-secondary, #f8fafc)",t.style.borderLeftColor="var(--color-primary, #6c5ce7)"}),t.addEventListener("click",()=>{this._executeItem(t)})})}},_onKeyDown(e){const o=document.getElementById("sl-cmd-results");if(!o)return;const t=Array.from(o.querySelectorAll(".sl-cmd-item"));if(t.length===0)return;const n=t.findIndex(s=>s.classList.contains("selected"));if(e.key==="ArrowDown"){e.preventDefault();const s=(n+1)%t.length;this._selectIndex(t,s)}else if(e.key==="ArrowUp"){e.preventDefault();const s=(n-1+t.length)%t.length;this._selectIndex(t,s)}else e.key==="Enter"&&(e.preventDefault(),n>=0&&t[n]&&this._executeItem(t[n]))},_selectIndex(e,o){e.forEach((t,n)=>{const s=n===o;t.classList.toggle("selected",s),t.style.background=s?"var(--color-bg-secondary, #f8fafc)":"transparent",t.style.borderLeftColor=s?"var(--color-primary, #6c5ce7)":"transparent",s&&t.scrollIntoView({block:"nearest"})})},_executeItem(e){const o=e.getAttribute("data-href"),t=e.getAttribute("data-ext")==="1";this.close(),o&&(t?window.open(o,"_blank"):window.location.hash=o)}};window.CommandPalette=a;export{a as CommandPalette};
