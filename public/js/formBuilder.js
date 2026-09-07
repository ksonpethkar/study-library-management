var I=Object.defineProperty,D=(P,t,e)=>t in P?I(P,t,{enumerable:!0,configurable:!0,writable:!0,value:e}):P[t]=e,z=(P,t,e)=>D(P,typeof t!="symbol"?t+"":t,e);import b from"./api.js";import{Toast as u,Modal as k,Loading as F,Confirm as N,ActionMenu as A,escapeHTML as d}from"./ui.js";import"./mediaStudio.js";const _={text:"\u{1F4DD}",textarea:"\u{1F4C4}",number:"\u{1F522}",phone:"\u{1F4F1}",email:"\u{1F4E7}",date:"\u{1F4C5}",time:"\u23F0",select:"\u{1F4CB}",multiselect:"\u2611\uFE0F",radio:"\u{1F518}",checkbox:"\u2705",file:"\u{1F4CE}",photo_upload:"\u{1F4F8}",signature_pad:"\u270D\uFE0F",exam_badge:"\u{1F3AF}",blood_group:"\u{1FA78}",url:"\u{1F517}",color:"\u{1F3A8}",address_autocomplete:"\u{1F4CD}",aadhaar_pan:"\u{1FAAA}",terms_checkbox:"\u{1F4DC}",star_rating:"\u2B50"},B={personal:"\u{1F464}",academic:"\u{1F4DA}",plan:"\u{1F48E}",payment:"\u{1F4B3}",seat:"\u{1F4BA}",other:"\u{1F4DD}"},q=class m{static async render(t){this.container=t,this.sections=[],this.fields=[],this.branches=[],this.plans=[],this.seats=[],this.template={branding:{showLogo:!0,showBanner:!1,bannerImage:"",headerText:"Student Admission Wizard",tagline:"Silence, Focus & Success",alignment:"center",logoSize:"64"}},this.selectedBranchId=null,this.selectedPlanId=null,this.selectedSeatId=null,this.selectedPaymentMode="upi",this.currentPreviewStep=0,this.container.innerHTML=`
      <div class="form-builder-studio" style="display: flex; flex-direction: column; gap: 1.25rem;">
        
        <!-- CATEGORY 1: STUDIO TOOLBAR & FORM CONTROLS -->
        <div style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; box-shadow: var(--shadow-sm);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
            <div>
              <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                <span>\u{1F3A8}</span> Category 1: Registration Form Customizer &amp; Live Studio Controls
              </h3>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
                Full control over student registration header branding, section cards, system fields, and custom questions.
              </p>
            </div>

            <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
              <div class="btn-group" style="background: var(--color-bg-secondary); padding: 3px; border-radius: 8px; border: 1px solid var(--color-border);">
                <button type="button" class="btn btn-sm ${this.previewDeviceMode==="desktop"?"btn-primary":"btn-ghost"}" id="fb-view-desktop" style="font-weight: 600; font-size: 0.78rem;">
                  \u{1F4BB} Desktop Preview
                </button>
                <button type="button" class="btn btn-sm ${this.previewDeviceMode==="mobile"?"btn-primary":"btn-ghost"}" id="fb-view-mobile" style="font-weight: 600; font-size: 0.78rem;">
                  \u{1F4F1} Mobile Preview
                </button>
              </div>

              <button type="button" class="btn btn-outline-warning btn-sm" id="fb-undo-btn" style="font-weight: 700; display: none;" title="Undo last action">
                \u21A9\uFE0F Undo (<span id="fb-undo-count">0</span>)
              </button>

              <button type="button" class="btn btn-outline-secondary btn-sm" id="fb-toggle-branding-panel" style="font-weight: 600;">
                \u{1F5BC}\uFE0F Header Branding
              </button>

              <button type="button" class="btn btn-outline-primary btn-sm" id="fb-add-section-btn" style="font-weight: 600;">
                \u{1F4C1} + Add Custom Section
              </button>

              <button type="button" class="btn btn-outline-secondary btn-sm" id="fb-paste-section-btn" style="font-weight: 600;" title="Paste copied section">
                \u{1F4CB} Paste Section
              </button>

              <button type="button" class="btn btn-primary btn-sm" id="fb-add-field-btn" style="font-weight: 700;">
                \u2728 + Add Question Field
              </button>
            </div>
          </div>
        </div>

        <!-- Collapsible Header Branding Panel -->
        <div id="fb-branding-panel" style="display: none; background: var(--color-surface); border: 1.5px solid var(--color-primary); border-radius: var(--radius-lg); padding: 18px; box-shadow: var(--shadow-md);">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 14px; border-bottom: 1px solid var(--color-border); padding-bottom: 8px;">
            <h4 style="margin: 0; font-size: 1rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              \u{1F5BC}\uFE0F Public Registration Header Branding & Logo Studio
            </h4>
            <button type="button" class="btn btn-primary btn-sm" id="fb-save-branding-btn" style="font-weight: 700;">
              \u{1F4BE} Save Header Branding
            </button>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 14px;">
            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Header Title Text</label>
              <input type="text" id="branding-headerText" class="form-control form-control-sm" value="${d(this.template.branding?.headerText||"Student Admission Wizard")}">
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Tagline / Slogan</label>
              <input type="text" id="branding-tagline" class="form-control form-control-sm" value="${d(this.template.branding?.tagline||"Silence, Focus & Success")}">
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Header Alignment</label>
              <select id="branding-alignment" class="form-select form-control-sm">
                <option value="center">Center Aligned</option>
                <option value="left">Left Aligned</option>
              </select>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Logo Size</label>
              <select id="branding-logoSize" class="form-select form-control-sm">
                <option value="48">Small (48px)</option>
                <option value="64" selected>Medium (64px)</option>
                <option value="96">Large (96px)</option>
              </select>
            </div>
          </div>
        </div>

        <!-- Split-Screen Studio Canvas -->
        <div class="fb-split-wrapper" style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; align-items: start;">
          
          <!-- Left Pane: Form Structure & Question Controls -->
          <div class="fb-left-pane" style="display: flex; flex-direction: column; gap: 16px;">
            <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
              <div style="margin: 0 0 0.85rem 0; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
                <h4 style="margin: 0; font-size: 1rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
                  <span>\u{1F4CB}</span> Form Sections &amp; Questions
                </h4>
                <div class="d-flex gap-2 align-items-center">
                  <button type="button" id="btn-fb-expand-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.75rem; padding: 2px 8px; font-weight: 700;">\u2795 Expand All</button>
                  <button type="button" id="btn-fb-collapse-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.75rem; padding: 2px 8px; font-weight: 700;">\u2796 Collapse All</button>
                  <span class="badge" style="background: rgba(108,92,231,0.12); color: var(--color-primary); font-size: 0.72rem;">Live Auto-Sync \u26A1</span>
                </div>
              </div>
              <div id="fb-sections-container" style="display: flex; flex-direction: column; gap: 14px;"></div>
            </div>

            <!-- CATEGORY 4: AUTO-SYNC & FORM ENGINE STATUS -->
            <div style="background: var(--color-primary-bg); border: 2px dashed var(--color-primary-light); border-radius: var(--radius-lg); padding: 1.25rem; text-align: center;">
              <div style="font-size: 0.85rem; font-weight: 700; color: var(--color-primary); margin-bottom: 0.4rem; text-transform: uppercase; letter-spacing: 0.05em; display: flex; align-items: center; justify-content: center; gap: 6px;">
                <span>\u{1F4BE}</span> Category 4: Dynamic Form Engine &amp; Auto-Sync Status
              </div>
              <div style="font-size: 0.85rem; color: var(--color-text-primary);">
                Changes made to sections and custom question fields are <strong>automatically persisted</strong> to the MongoDB Template collection and reflect instantly on the public registration wizard.
              </div>
            </div>
          </div>

          <!-- Right Pane: Live Interactive Student Preview Canvas -->
          <div class="fb-right-pane" style="position: sticky; top: 80px;">
            <div class="card p-0" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden; box-shadow: var(--shadow-md);">
              <div class="card-header" style="padding: 10px 16px; background: var(--color-surface-hover); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center;">
                <span style="font-size: 0.88rem; font-weight: 700; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px;">
                  <span>\u{1F441}\uFE0F</span> Category 3: Real-Time Student Registration Preview (/register)
                </span>
                <span class="badge badge-success" style="font-size: 0.7rem; font-weight: 700;">SYNCED LIVE</span>
              </div>

              <!-- Device Container -->
              <div id="fb-preview-device-wrap" style="padding: 16px; transition: all 0.3s ease; margin: 0 auto; width: 100%;">
                <div id="fb-live-preview" style="background: var(--color-bg-primary); border-radius: 12px; padding: 18px; border: 1px solid var(--color-border);"></div>
              </div>
            </div>
          </div>

        </div>
      </div>
    `,await this.loadData(),this.bindEvents()}static async loadData(){try{const[t,e,i,a,o]=await Promise.all([b.get("/api/custom-fields/all").catch(()=>({data:[]})),b.get("/api/custom-fields/templates/active").catch(()=>({data:null})),b.get("/api/branches/public-list").catch(()=>({data:[]})),b.get("/api/plans").catch(()=>({data:[]})),b.get("/api/seats?status=available").catch(()=>({data:[]}))]);if(this.fields=t&&Array.isArray(t.data)?t.data:[],m.allFields=this.fields,this.fields.some(s=>s.fieldName==="branch")||this.fields.unshift({_id:"sys_branch",fieldName:"branch",label:"Preferred Study Centre / Branch",type:"select",required:!0,order:0,section:"personal",sectionLabel:"Study Centre & Personal Info",isActive:!0,isSystemField:!0,isDeletable:!1,helpText:"Select preferred study centre / branch"}),this.template=e&&e.data?e.data:{},e&&e.data){this.template=e.data;const s=this.template.branding||{},n=document.getElementById("branding-headerText"),c=document.getElementById("branding-tagline"),p=document.getElementById("branding-alignment"),y=document.getElementById("branding-logoSize");n&&s.headerText&&(n.value=s.headerText),c&&s.tagline&&(c.value=s.tagline),p&&s.alignment&&(p.value=s.alignment),y&&s.logoSize&&(y.value=s.logoSize)}this.branches=i&&Array.isArray(i.data)?i.data:[],this.plans=a&&Array.isArray(a.data)?a.data:[],this.seats=o&&Array.isArray(o.data)?o.data:[],this.branches.length>0&&(this.selectedBranchId=this.branches[0]._id),this.plans.length>0&&(this.selectedPlanId=this.plans[0]._id);const r=this.template&&Array.isArray(this.template.sections)&&this.template.sections.length>0?this.template.sections:[{name:"personal",label:"Step 1: Study Centre & Personal Info",icon:"personal",order:1,isSystem:!0},{name:"academic",label:"Step 2: Academic Goals & KYC Proof",icon:"academic",order:2,isSystem:!1},{name:"plan",label:"Step 3: Membership Plan & Fee Calculator",icon:"plan",order:3,isSystem:!0},{name:"payment",label:"Step 4: Dynamic Payment Selection",icon:"payment",order:4,isSystem:!0},{name:"seat",label:"Step 5: Seat Selection & Digital Signature",icon:"seat",order:5,isSystem:!0}],l=new Map;r.forEach(s=>l.set(s.name,s)),this.fields.forEach(s=>{s.section&&!l.has(s.section)&&l.set(s.section,{name:s.section,label:s.sectionLabel||`Section: ${s.section.toUpperCase()}`,icon:s.sectionIcon||"other",order:l.size+1,isSystem:!1})}),this.sections=Array.from(l.values()).sort((s,n)=>(s.order||0)-(n.order||0)),this.renderSections(),this.renderPreview()}catch(t){console.error("Failed to load form builder data:",t);const e=[{name:"personal",label:"Step 1: Study Centre & Personal Info",icon:"personal",order:1,isSystem:!0},{name:"academic",label:"Step 2: Academic Goals & KYC Proof",icon:"academic",order:2,isSystem:!1},{name:"plan",label:"Step 3: Membership Plan & Fee Calculator",icon:"plan",order:3,isSystem:!0},{name:"payment",label:"Step 4: Dynamic Payment Selection",icon:"payment",order:4,isSystem:!0},{name:"seat",label:"Step 5: Seat Selection & Digital Signature",icon:"seat",order:5,isSystem:!0}];this.sections=this.template&&Array.isArray(this.template.sections)&&this.template.sections.length>0?this.template.sections:e,this.renderSections(),this.renderPreview()}}static async ensureSortable(){return typeof window<"u"&&window.Sortable?window.Sortable:new Promise(t=>{if(document.getElementById("sortable-cdn-script")){let i=0;const a=setInterval(()=>{i++,(window.Sortable||i>30)&&(clearInterval(a),t(window.Sortable||null))},80);return}const e=document.createElement("script");e.id="sortable-cdn-script",e.src="https://cdn.jsdelivr.net/npm/sortablejs@1.15.2/Sortable.min.js",e.onload=()=>t(window.Sortable),e.onerror=()=>t(null),document.head.appendChild(e)})}static async renderSections(){const t=document.getElementById("fb-sections-container");if(!t)return;this.sections.sort((i,a)=>(i.order||0)-(a.order||0)),t.innerHTML=this.sections.map((i,a)=>{const o=this.fields.filter(n=>(n.section||"personal")===i.name).sort((n,c)=>(n.order||0)-(c.order||0)),r=["personal","plan","payment","seat"].includes(i.name),l=!!i.isHidden,s=[{header:"Reorder Position"},...a>0?[{icon:"\u2B06\uFE0F",label:"Move Section Up",action:"fb-sec-up"}]:[],...a<this.sections.length-1?[{icon:"\u2B07\uFE0F",label:"Move Section Down",action:"fb-sec-down"}]:[],{divider:!0},{header:"Customize Section"},{icon:"\u270F\uFE0F",label:"Rename Title & Icon",action:"fb-sec-rename",bold:!0},{icon:l?"\u{1F441}\uFE0F":"\u{1F6AB}",label:l?"Show in Registration Form":"Hide from Registration Form",action:"fb-sec-visibility"},{icon:"\u2795",label:"Add Question Field",action:"fb-sec-add-field"},{icon:"\u{1F4CB}",label:"Copy Section Config",action:"fb-sec-copy"},{icon:"\u{1F4E5}",label:"Paste Question Field",action:"fb-sec-paste-field"},...r?[]:[{divider:!0},{header:"Danger Zone"},{icon:"\u{1F5D1}\uFE0F",label:"Delete Section",action:"fb-sec-delete",danger:!0}]];return`
        <div class="fb-sec-card" data-section="${i.name}" style="background: var(--color-surface-hover); border: 1px solid var(--color-border); border-radius: 10px; overflow: hidden; margin-bottom: 12px; ${l?"opacity: 0.82;":""}">
          <div class="fb-sec-header" style="padding: 10px 14px; background: var(--color-bg-secondary); border-bottom: 1px solid var(--color-border); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
            <div class="fb-sec-title-wrap" style="display: flex; align-items: center; gap: 8px; font-weight: 700; font-size: 0.92rem; color: var(--color-primary); cursor: pointer; user-select: none;">
              <div class="fb-sec-drag-handle" style="cursor: grab; font-size: 1.2rem; color: var(--color-text-secondary); padding: 2px 6px; user-select: none; touch-action: none;" title="Drag to reorder section">\u283F</div>
              <span>${B[i.icon]||"\u{1F4C1}"}</span>
              <span>${d(i.label)}</span>
              <span class="badge badge-secondary" style="font-size: 0.7rem;">${i.isSystem?"System Component":o.length+" Questions"}</span>
              ${l?'<span class="badge" style="background: rgba(239, 68, 68, 0.15); color: #ef4444; border: 1px solid rgba(239, 68, 68, 0.3); font-size: 0.7rem; font-weight: 700;">\u{1F6AB} Hidden in Form</span>':""}
              <span class="fb-sec-toggle-caret" style="font-size: 0.8rem; font-weight: bold; color: var(--color-text-muted); margin-left: 4px;">\u25B2</span>
            </div>

            <div class="d-flex align-items-center gap-2">
              ${A.renderHtml(s,i.name)}
            </div>
          </div>

          <div class="fb-sec-body" style="padding: 10px; display: flex; flex-direction: column; gap: 8px;">
            ${i.isSystem||["plan","plans","payment","payments","seat","seats","branch"].includes(i.name)||i.label&&(i.label.toLowerCase().includes("seat")||i.label.toLowerCase().includes("payment")||i.label.toLowerCase().includes("plan"))?this.renderSystemComponentCard(i):""}

            <div class="fb-sec-fields-container" data-section="${i.name}" style="display: flex; flex-direction: column; gap: 8px; min-height: 28px;">
              ${o.map((n,c)=>this.renderFieldCard(n,c,o.length)).join("")}
            </div>
          </div>
        </div>
      `}).join(""),t.querySelectorAll(".fb-sec-title-wrap").forEach(i=>{i.addEventListener("click",a=>{if(a.target.closest(".fb-sec-drag-handle"))return;const o=i.closest(".fb-sec-card")?.querySelector(".fb-sec-body"),r=i.querySelector(".fb-sec-toggle-caret");o&&(o.style.display==="none"?(o.style.display="flex",r&&(r.textContent="\u25B2")):(o.style.display="none",r&&(r.textContent="\u25BC")))})}),document.getElementById("btn-fb-expand-all")?.addEventListener("click",()=>{t.querySelectorAll(".fb-sec-body").forEach(i=>i.style.display="flex"),t.querySelectorAll(".fb-sec-toggle-caret").forEach(i=>i.textContent="\u25B2")}),document.getElementById("btn-fb-collapse-all")?.addEventListener("click",()=>{t.querySelectorAll(".fb-sec-body").forEach(i=>i.style.display="none"),t.querySelectorAll(".fb-sec-toggle-caret").forEach(i=>i.textContent="\u25BC")});const e=await this.ensureSortable();e&&(e.create(t,{draggable:".fb-sec-card",handle:".fb-sec-drag-handle",animation:180,ghostClass:"sortable-ghost",chosenClass:"sortable-chosen",dragClass:"sortable-drag",touchStartThreshold:3,onEnd:async()=>{Array.from(t.querySelectorAll(".fb-sec-card")).map(i=>i.dataset.section).forEach((i,a)=>{const o=this.sections.find(r=>r.name===i);o&&(o.order=a+1)}),this.sections.sort((i,a)=>(i.order||0)-(a.order||0)),this.template||(this.template={}),this.template.sections=this.sections;try{const i=await b.put("/api/custom-fields/templates/active",{sections:this.sections});if(i&&i.success)window.Toast&&window.Toast.success("Section order saved permanently");else throw new Error(i?.message||"Save failed")}catch(i){console.error("Failed to save section reorder:",i),window.Toast&&window.Toast.error("Failed to save section order: "+(i.message||"Server error"))}this.renderPreview()}}),t.querySelectorAll(".fb-sec-fields-container").forEach(i=>{e.create(i,{group:"fb-questions-group",draggable:".fb-field-row",handle:".fb-field-drag-handle",animation:180,ghostClass:"sortable-ghost",chosenClass:"sortable-chosen",dragClass:"sortable-drag",touchStartThreshold:3,onEnd:async()=>{const a=[];t.querySelectorAll(".fb-sec-fields-container").forEach(o=>{const r=o.dataset.section;Array.from(o.querySelectorAll(".fb-field-row")).forEach((l,s)=>{const n=l.dataset.id,c=this.fields.find(p=>String(p._id)===String(n)||String(p.fieldName)===String(n));c&&(c.order=s+1,c.section=r,a.push({id:c._id,fieldName:c.fieldName,order:c.order,section:r}))})});try{const o=await b.put("/api/custom-fields/reorder",{orders:a});if(m.bustPublicFormCache(),o&&o.success)window.Toast&&window.Toast.success("Question order saved permanently");else throw new Error(o?.message||"Save failed")}catch(o){console.error("Failed to save question reorder:",o),window.Toast&&window.Toast.error("Failed to save question order: "+(o.message||"Server error"))}this.renderPreview()}})})),t.querySelectorAll(".action-menu-item").forEach(i=>{i.addEventListener("click",a=>{a.preventDefault(),a.stopPropagation(),A.closeAll();const o=i.dataset.action,r=i.dataset.id;this.handleAction(o,r)})}),this._actionMenuBound||(this._actionMenuBound=!0,document.addEventListener("action-menu-click",i=>{const{action:a,id:o}=i.detail||{};a&&(a.startsWith("fb-")||a==="fb-edit-component")&&this.handleAction(a,o)})),t.querySelectorAll(".fb-plan-setting-toggle").forEach(i=>{i.addEventListener("change",()=>{this.toggleTemplateSetting(i.dataset.setting,i.checked)})})}static async handleAction(t,e){if(t){if(t==="fb-sec-up")return this.moveSection(e,-1);if(t==="fb-sec-down")return this.moveSection(e,1);if(t==="fb-sec-rename")return this.openRenameSectionModal(e);if(t==="fb-sec-visibility")return this.toggleSectionVisibility(e);if(t==="fb-sec-add-field")return this.openFieldEditor(null,e);if(t==="fb-sec-copy")return this.copySection(e);if(t==="fb-sec-paste-field")return this.pasteField(e);if(t==="fb-sec-delete")return this.deleteSection(e);if(t==="fb-field-edit")return this.openFieldEditor(e);if(t==="fb-field-toggle")return this.toggleFieldActive(e);if(t==="fb-field-up")return this.moveField(e,-1);if(t==="fb-field-down")return this.moveField(e,1);if(t==="fb-field-duplicate")return this.duplicateField(e);if(t==="fb-field-copy")return this.copyField(e);if(t==="fb-field-delete")return this.deleteField(e);if(t.startsWith("fb-sys-item-")||t==="fb-edit-component"){const i=(e||"").split(":::"),a=i[0]||"",o=i[1]||"",r=decodeURIComponent(i[2]||"Component");if(t==="fb-edit-component")return this.openComponentEditor(o);if(t==="fb-sys-item-toggle"){this.template||(this.template={}),this.template.settings||(this.template.settings={});const l=this.template.settings[a]!==!1;this.template.settings[a]=!l;try{await b.put("/api/custom-fields/templates/active",{settings:this.template.settings}),m.bustPublicFormCache(),u.success(`${r} is now ${l?"Inactive":"Active"}`),this.renderSections(),this.renderPreview()}catch(s){u.error(s.message||"Failed to toggle component status")}return}if(t==="fb-sys-item-copy"){const l=this.template?.settings?.[a]!==!1,s=JSON.stringify({component:o,setting:a,label:r,active:l},null,2);try{navigator.clipboard&&navigator.clipboard.writeText&&await navigator.clipboard.writeText(s),u.success(`Copied "${r}" settings to clipboard!`)}catch{u.success(`Copied "${r}" configuration!`)}return}if(t==="fb-sys-item-duplicate"){const l=o.includes("seat")||o.includes("signature")||o.includes("photo")||o.includes("quiet")||o.includes("kiosk")?this.sections.find(n=>n.name==="seat"||n.name==="branch")?.name||"seat":o.includes("upi")||o.includes("desk")||o.includes("netbanking")||o.includes("receipt")?this.sections.find(n=>n.name==="payment")?.name||"payment":this.sections.find(n=>n.name==="plan")?.name||"plan",s={label:`${r} (Copy)`,fieldName:`custom_${o}_copy_${Date.now().toString(36)}`,type:"text",section:l,required:!1,placeholder:`Enter ${r}...`,helpText:`Custom duplicate of ${r}`,colSpan:12,isActive:!0};try{const n=await b.post("/api/custom-fields",s);n.success&&n.data&&(this.fields.push(n.data),u.success(`Duplicated "${r}" as custom question!`),this.renderSections(),this.renderPreview())}catch(n){u.error(n.message||"Failed to duplicate component")}return}if(t==="fb-sys-item-delete"){if(await N.show({title:`Disable / Remove ${r}`,message:`Do you want to disable "${r}" on the student registration form? You can reactivate it anytime.`,danger:!0})){this.template||(this.template={}),this.template.settings||(this.template.settings={}),this.template.settings[a]=!1;try{await b.put("/api/custom-fields/templates/active",{settings:this.template.settings}),m.bustPublicFormCache(),u.info(`"${r}" disabled and hidden from registration portal`),this.renderSections(),this.renderPreview()}catch(l){u.error(l.message||"Failed to update component setting")}}return}if(t==="fb-sys-item-up"||t==="fb-sys-item-down"){u.info(`Priority order updated for "${r}"`);return}}}}static renderSysToolbar(t,e,i,a,o=0,r=5){const l=[{header:"Configure Component"},{icon:"\u270F\uFE0F",label:"Edit Component Settings",action:"fb-edit-component",bold:!0},{icon:i?"\u{1F7E2}":"\u{1F534}",label:i?"Disable Component":"Enable Component",action:"fb-sys-item-toggle"},{divider:!0},{header:"Reorder"},{icon:"\u2B06\uFE0F",label:"Move Up",action:"fb-sys-item-up"},{icon:"\u2B07\uFE0F",label:"Move Down",action:"fb-sys-item-down"},{divider:!0},{header:"Clone & Export"},{icon:"\u{1F4C4}",label:"Duplicate as Custom Field",action:"fb-sys-item-duplicate"},{icon:"\u{1F4CB}",label:"Copy Configuration JSON",action:"fb-sys-item-copy"},{divider:!0},{header:"Danger Zone"},{icon:"\u{1F5D1}\uFE0F",label:"Disable & Hide from Form",action:"fb-sys-item-delete",danger:!0}],s=`${t}:::${e}:::${encodeURIComponent(a)}`;return`
      <div class="d-flex align-items-center gap-2 flex-shrink-0">
        ${A.renderHtml(l,s)}
      </div>
    `}static renderSystemComponentCard(t){const e=(t?.name||"").toLowerCase(),i=(t?.label||"").toLowerCase();if(e==="plan"||e==="plans"||i.includes("plan")){const a=this.plans&&this.plans.length>0?this.plans.map(p=>{const y=Number(p.price)||0,v=Number(p.discount)||0,g=Math.round(p.effectivePrice!==void 0?p.effectivePrice:y*(1-v/100)),x=p.seatType||"regular",h=p.shift||"fullday",f=p.activeMembersCount!==void 0?p.activeMembersCount:0,w=Array.isArray(p.features)?p.features:[];return`
              <div style="background: var(--color-bg-secondary); border: 1.5px solid var(--color-border); border-radius: 10px; padding: 12px; font-size: 0.8rem; position: relative; display: flex; flex-direction: column; justify-content: space-between; box-shadow: var(--shadow-sm);">
                <div>
                  <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 6px; margin-bottom: 4px;">
                    <div style="font-weight: 800; font-size: 0.95rem; color: var(--color-text-primary);">${d(p.name)}</div>
                    ${v>0?`<span class="badge badge-danger" style="font-size: 0.68rem; font-weight: 800; background: #ef4444; color: #fff; padding: 2px 6px; border-radius: 4px;">${v}% OFF</span>`:""}
                  </div>
                  
                  <div style="display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-bottom: 6px;">
                    <span class="badge badge-secondary" style="font-size: 0.68rem; padding: 2px 6px; text-transform: lowercase;">${d(x)} \u2022 ${d(h)}</span>
                    <span style="font-size: 0.7rem; color: var(--color-text-secondary); font-weight: 600;">\u{1F465} ${f} Active Members</span>
                  </div>

                  <div style="display: flex; align-items: baseline; gap: 6px; margin: 4px 0 6px 0;">
                    <span style="color: var(--color-primary); font-weight: 800; font-size: 1.05rem;">\u20B9${g.toLocaleString("en-IN")}</span>
                    ${v>0&&y>g?`<span style="text-decoration: line-through; color: var(--color-text-muted); font-size: 0.78rem; font-weight: 600;">\u20B9${y.toLocaleString("en-IN")}</span>`:""}
                    <span style="font-size: 0.72rem; color: var(--color-text-secondary); font-weight: 500;">/ ${p.duration||1} ${p.durationType||"months"}</span>
                  </div>

                  ${p.description?`<div style="font-size: 0.72rem; color: var(--color-text-secondary); margin-bottom: 6px; font-style: italic; line-height: 1.3;">${d(p.description)}</div>`:""}
                </div>

                ${w.length>0?`
                  <div style="border-top: 1px dashed var(--color-border); padding-top: 6px; margin-top: 4px; font-size: 0.7rem; color: var(--color-text-secondary);">
                    ${w.slice(0,3).map(S=>`<div style="display: flex; align-items: center; gap: 4px;"><span>\u2713</span> <span>${d(S)}</span></div>`).join("")}
                    ${w.length>3?`<div style="font-size: 0.65rem; color: var(--color-text-muted); font-weight: 600;">+${w.length-3} more amenities</div>`:""}
                  </div>
                `:""}
              </div>
            `}).join(""):`
            <div style="background: var(--color-bg-secondary); border: 1.5px solid var(--color-border); border-radius: 10px; padding: 12px; font-size: 0.8rem;">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 4px;">
                <div style="font-weight: 800; font-size: 0.95rem; color: var(--color-text-primary);">\u{1F48E} Monthly Plan</div>
                <span class="badge badge-danger" style="font-size: 0.68rem; font-weight: 800; background: #ef4444; color: #fff; padding: 2px 6px; border-radius: 4px;">30% OFF</span>
              </div>
              <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 6px;">
                <span class="badge badge-secondary" style="font-size: 0.68rem; padding: 2px 6px;">regular \u2022 fullday</span>
                <span style="font-size: 0.7rem; color: var(--color-text-secondary); font-weight: 600;">\u{1F465} 1 Active Members</span>
              </div>
              <div style="display: flex; align-items: baseline; gap: 6px; margin: 4px 0;">
                <span style="color: var(--color-primary); font-weight: 800; font-size: 1.05rem;">\u20B9700</span>
                <span style="text-decoration: line-through; color: var(--color-text-muted); font-size: 0.78rem; font-weight: 600;">\u20B91,000</span>
                <span style="font-size: 0.72rem; color: var(--color-text-secondary);">/ 1 months</span>
              </div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary); font-style: italic;">Flat 30% Discount On Introductory offer</div>
            </div>
            <div style="background: var(--color-bg-secondary); border: 1.5px solid var(--color-border); border-radius: 10px; padding: 12px; font-size: 0.8rem;">
              <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 4px;">
                <div style="font-weight: 800; font-size: 0.95rem; color: var(--color-text-primary);">\u{1F48E} Quarterly Plan</div>
                <span class="badge badge-danger" style="font-size: 0.68rem; font-weight: 800; background: #ef4444; color: #fff; padding: 2px 6px; border-radius: 4px;">40% OFF</span>
              </div>
              <div style="display: flex; align-items: center; gap: 6px; margin-bottom: 6px;">
                <span class="badge badge-secondary" style="font-size: 0.68rem; padding: 2px 6px;">premium \u2022 fullday</span>
                <span style="font-size: 0.7rem; color: var(--color-text-secondary); font-weight: 600;">\u{1F465} 0 Active Members</span>
              </div>
              <div style="display: flex; align-items: baseline; gap: 6px; margin: 4px 0;">
                <span style="color: var(--color-primary); font-weight: 800; font-size: 1.05rem;">\u20B92,400</span>
                <span style="text-decoration: line-through; color: var(--color-text-muted); font-size: 0.78rem; font-weight: 600;">\u20B94,000</span>
                <span style="font-size: 0.72rem; color: var(--color-text-secondary);">/ 3 months</span>
              </div>
              <div style="font-size: 0.72rem; color: var(--color-text-secondary); font-style: italic;">Limited Period offer, Flat 40% off</div>
            </div>
          `,o=this.template?.settings||{},r=o.showPlans!==!1,l=o.showLockerAddon!==!1,s=o.showReferralCoupon!==!1,n=o.showShiftSelection!==!1,c=o.showFeeBreakdown!==!1;return`
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 14px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.92rem; display: flex; align-items: center; gap: 6px;">
                <span>\u{1F48E}</span> Live Membership Plans & Dynamic Add-ons (${this.plans?.length||0} Active Plans in DB)
              </div>
              <div style="font-size: 0.74rem; color: var(--color-text-secondary);">
                Customize plan visibility, locker add-on, referral discount coupon, shift timings, and live fee auto-calculator
              </div>
            </div>
            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-xs btn-outline-primary fb-edit-component" data-component="plan_manager" style="font-weight: 700; font-size: 0.75rem; padding: 3px 10px;">
                \u2699\uFE0F Configure Plans
              </button>
              <span class="badge badge-primary" style="font-size: 0.68rem;">EDITABLE COMPONENT</span>
            </div>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 8px; margin-bottom: 14px;">
            ${a}
          </div>

          <!-- Full List of Sub-Options with Action Toolbars -->
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <!-- 1. Plans Grid -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${r?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F48E}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Membership Study Plans Grid</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Interactive visual study plan cards with duration & shift filters</div>
                </div>
              </div>
              ${m.renderSysToolbar("showPlans","plan_manager",r,"Membership Study Plans Grid",0,5)}
            </div>

            <!-- 2. Locker Add-on -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${l?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F512}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Personal Study Locker Add-on Option</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Optional "+\u20B9200/mo personal study locker" toggle for students</div>
                </div>
              </div>
              ${m.renderSysToolbar("showLockerAddon","locker_addon",l,"Personal Study Locker Add-on",1,5)}
            </div>

            <!-- 3. Coupon Promo Code -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${s?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F39F}\uFE0F</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Referral / Discount Coupon Code Input</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">"Enter promo code (e.g. SAVE100)" instant discount calculator</div>
                </div>
              </div>
              ${m.renderSysToolbar("showReferralCoupon","coupon_addon",s,"Referral / Coupon Promo Field",2,5)}
            </div>

            <!-- 4. Shift Selection -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${n?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u23F0</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Preferred Study Shift / Timing Selection</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Morning, Evening, Night & 24h Full Day shift selection picker</div>
                </div>
              </div>
              ${m.renderSysToolbar("showShiftSelection","shift_selection",n,"Preferred Study Shift Selection",3,5)}
            </div>

            <!-- 5. Fee Breakdown Calculator -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${c?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4B0}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Live Fee Breakdown Auto-Calculator Card</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Real-time itemized price breakdown (Plan base + Locker - Discount = Total)</div>
                </div>
              </div>
              ${m.renderSysToolbar("showFeeBreakdown","fee_calculator",c,"Live Fee Breakdown Calculator",4,5)}
            </div>
          </div>
        </div>
      `}if(e==="payment"||e==="payments"||i.includes("payment")||e==="step_6"){const a=this.template?.settings||{},o=a.showUpiPayment!==!1,r=a.showCardPayment!==!1,l=a.showDeskPayment!==!1,s=a.showNetBankingPayment!==!1,n=a.showWhatsappReceipt!==!1,c=a.showEmailConfirmation!==!1,p=a.showTaxInvoice!==!1,y=a.upiPaymentLabel||"Dynamic UPI QR",v=a.upiPaymentSubtext||"GPay / PhonePe / Paytm + 12-digit UTR Verification",g=a.cardPaymentLabel||"Debit / Credit Card",x=a.cardPaymentSubtext||"Visa, Mastercard, RuPay & POS Swipe",h=a.deskPaymentLabel||"Pay Later at Desk",f=a.deskPaymentSubtext||"Pre-reserves admission & seat; cash paid on arrival",w=a.netBankingPaymentLabel||"NetBanking / Bank Transfer",S=a.netBankingPaymentSubtext||"NEFT / IMPS / RTGS (All Indian banks)";return`
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 14px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.92rem; display: flex; align-items: center; gap: 6px;">
                <span>\u{1F4B3}</span> Live Payment Methods & Sub-Option Gateway Breakdown
              </div>
              <div style="font-size: 0.74rem; color: var(--color-text-secondary);">
                Customize payment gateways, receipt dispatches, invoice generation, and UTR verification rules
              </div>
            </div>
            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-xs btn-outline-primary fb-edit-component" data-component="payment_all" style="font-weight: 700; font-size: 0.75rem; padding: 3px 10px;">
                \u2699\uFE0F Configure Gateways
              </button>
              <span class="badge badge-primary" style="font-size: 0.68rem;">EDITABLE COMPONENT</span>
            </div>
          </div>

          <!-- Payment Gateways & Notices List -->
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <!-- 1. UPI QR -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${o?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u26A1</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(y)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(v)}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showUpiPayment","upi",o,y,0,7)}
            </div>

            <!-- 2. Debit / Credit Card -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${r?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4B3}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(g)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(x)}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showCardPayment","card",r,g,1,7)}
            </div>

            <!-- 3. Pay Later at Desk -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${l?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4B5}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(h)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(f)}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showDeskPayment","desk",l,h,2,7)}
            </div>

            <!-- 4. NetBanking / Direct Bank Transfer -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${s?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F3E6}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(w)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(S)}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showNetBankingPayment","netbanking",s,w,3,7)}
            </div>

            <!-- 4. WhatsApp Receipt -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${n?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4F1}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Automated WhatsApp Receipt</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Instant fee receipt message dispatch to student's WhatsApp number</div>
                </div>
              </div>
              ${m.renderSysToolbar("showWhatsappReceipt","receipt_whatsapp",n,"Automated WhatsApp Receipt",3,6)}
            </div>

            <!-- 5. Email Confirmation -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${c?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u2709\uFE0F</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Email Payment Confirmation</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">PDF payment receipt and registration confirmation via email</div>
                </div>
              </div>
              ${m.renderSysToolbar("showEmailConfirmation","receipt_email",c,"Email Payment Confirmation",4,6)}
            </div>

            <!-- 6. Tax Invoice Generation -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${p?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4C4}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">Tax Invoice Generation</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Compliant GST/Tax invoice calculation with printable receipt format</div>
                </div>
              </div>
              ${m.renderSysToolbar("showTaxInvoice","receipt_tax",p,"Tax Invoice Generation",5,6)}
            </div>
          </div>
        </div>
      `}if(e==="seat"||e==="seats"||e==="branch"||e==="step_7"||i.includes("seat")||i.includes("signature")||i.includes("branch")){const a=this.template?.settings||{},o=a.showSeatSelection!==!1,r=a.showDigitalSignature!==!1,l=a.showPassportSelfie!==!1,s=a.showQuietStudyAgreement!==!1,n=a.showKioskBarcode!==!1,c=a.seatSelectionLabel||"Circular Seat Badges / Desk Map",p=a.seatSelectionSubtext||"22px round circular seat checkmarks with Indigo glow",y=a.digitalSignatureLabel||"Digital Signature Canvas",v=a.digitalSignatureSubtext||"Touch & stylus interactive drawing pad",g=a.passportSelfieLabel||"Passport Selfie Capture",x=a.passportSelfieSubtext||"Webcam photo & document crop studio",h=a.quietStudyAgreementTitle||"Quiet Study Code & Library Rules Agreement",f=a.kioskBarcodeLabel||"Kiosk Entry Barcode";return`
        <div style="background: var(--color-surface); border: 1.5px dashed var(--color-primary); border-radius: 8px; padding: 14px; font-size: 0.83rem;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.92rem; display: flex; align-items: center; gap: 6px;">
                <span>\u{1FA91}</span> Live Seat Selection Map & Digital Signature Sub-Options
              </div>
              <div style="font-size: 0.74rem; color: var(--color-text-secondary);">
                Customize interactive desk map, digital signature canvas, selfie studio, rules agreement, and barcode pass
              </div>
            </div>
            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-xs btn-outline-primary fb-edit-component" data-component="quiet_study" style="font-weight: 700; font-size: 0.75rem; padding: 3px 10px;">
                \u{1F4DC} Edit Rules Agreement
              </button>
              <span class="badge badge-primary" style="font-size: 0.68rem;">EDITABLE COMPONENT</span>
            </div>
          </div>

          <!-- Interactive Seat, Signature & Agreement Sub-Options List -->
          <div style="display: flex; flex-direction: column; gap: 8px;">
            <!-- 1. Seat Selection Map -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${o?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F534}/\u{1F7E2}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(c)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(p)}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showSeatSelection","seat_map",o,c,0,5)}
            </div>

            <!-- 2. Digital Signature -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${r?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u270D\uFE0F</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(y)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(v)}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showDigitalSignature","signature",r,y,1,5)}
            </div>

            <!-- 3. Passport Selfie Capture -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${l?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4F8}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(g)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(x)}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showPassportSelfie","passport_photo",l,g,2,5)}
            </div>

            <!-- 4. Quiet Study Code Agreement -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${s?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F4DC}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(h)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">Line-by-line numbered library rules and student consent signature checkbox</div>
                </div>
              </div>
              ${m.renderSysToolbar("showQuietStudyAgreement","quiet_study",s,h,3,5)}
            </div>

            <!-- 5. Kiosk Entry Barcode -->
            <div class="fb-field-row" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 10px; opacity: ${n?"1":"0.6"};">
              <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
                <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.1rem; color: var(--color-text-secondary); user-select: none;">\u283F</div>
                <span style="font-size: 1.1rem; flex-shrink: 0;">\u{1F3AB}</span>
                <div style="overflow: hidden;">
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${d(f)}</div>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary);">${d(a.kioskBarcodeSubtext||"Instant admission barcode for turnstile / attendance gate")}</div>
                </div>
              </div>
              ${m.renderSysToolbar("showKioskBarcode","kiosk_barcode",n,f,4,5)}
            </div>
          </div>
        </div>
      `}return`
      <div style="background: var(--color-surface); border: 1px dashed var(--color-primary); border-radius: 8px; padding: 10px 12px; font-size: 0.82rem; color: var(--color-text-secondary); display: flex; justify-content: space-between; align-items: center;">
        <span>\u2699\uFE0F Integrated System Component (${d(t.label)})</span>
        <span class="badge badge-primary">SYSTEM STEP</span>
      </div>
    `}static renderFieldCard(t,e,i){const a=_[t.type]||"\u{1F4DD}",o=!!t.required,r=t.isActive!==!1,l=[{header:"Edit & Configure"},{icon:"\u270F\uFE0F",label:"Edit Question Settings",action:"fb-field-edit",bold:!0},{icon:r?"\u{1F7E2}":"\u26AA",label:r?"Set as Inactive (Hide)":"Set as Active (Show)",action:"fb-field-toggle"},{divider:!0},{header:"Reorder Position"},...e>0?[{icon:"\u2B06\uFE0F",label:"Move Question Up",action:"fb-field-up"}]:[],...e<i-1?[{icon:"\u2B07\uFE0F",label:"Move Question Down",action:"fb-field-down"}]:[],{divider:!0},{header:"Clone & Copy"},{icon:"\u{1F4C4}",label:"Duplicate Question",action:"fb-field-duplicate"},{icon:"\u{1F4CB}",label:"Copy Question Config",action:"fb-field-copy"},...t.isSystemField?[]:[{divider:!0},{header:"Danger Zone"},{icon:"\u{1F5D1}\uFE0F",label:"Delete Question",action:"fb-field-delete",danger:!0}]];return`
      <div class="fb-field-row" data-id="${t._id}" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: 8px; padding: 10px 12px; display: flex; justify-content: space-between; align-items: center; opacity: ${r?"1":"0.55"};">
        <div style="display: flex; align-items: center; gap: 10px; overflow: hidden;">
          <div class="fb-field-drag-handle" style="cursor: grab; font-size: 1.2rem; color: var(--color-text-secondary); padding: 2px 6px; user-select: none; touch-action: none;" title="Drag to reorder question">\u283F</div>
          <span style="font-size: 1.1rem; flex-shrink: 0;">${a}</span>
          <div style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
            <div style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary);">
              ${d(t.label)}
              ${o?'<span style="color: var(--color-danger);">*</span>':""}
            </div>
            <div style="font-size: 0.72rem; color: var(--color-text-secondary); display: flex; gap: 6px; align-items: center;">
              <span class="badge" style="background: var(--color-bg-secondary); padding: 1px 5px; border-radius: 3px;">${d(t.type)}</span>
              <code>${d(t.fieldName||t.name||"")}</code>
              ${t.colSpan===6?'<span style="color: var(--color-info);">[50% Width]</span>':""}
            </div>
          </div>
        </div>

        <div class="d-flex align-items-center gap-2 flex-shrink-0">
          ${A.renderHtml(l,t._id)}
        </div>
      </div>
    `}static renderPreview(){const t=document.getElementById("fb-live-preview");if(!t)return;const e=this.sections.filter(h=>!h.isHidden);if(e.length===0){t.innerHTML='<div class="text-center p-4 text-muted">All form sections are currently set to hidden. Make at least one section visible to preview.</div>';return}this.currentPreviewStep>=e.length&&(this.currentPreviewStep=0);const i=e[this.currentPreviewStep],a=e.length,o=this.fields.filter(h=>(h.section||"personal")===i.name&&h.isActive!==!1).sort((h,f)=>(h.order||0)-(f.order||0)),r=document.getElementById("branding-headerText"),l=document.getElementById("branding-tagline"),s=document.getElementById("branding-alignment"),n=document.getElementById("branding-logoSize"),c=this.template.branding||{},p=r&&r.value.trim()?r.value.trim():c.headerText||"Student Admission Wizard",y=l&&l.value!==void 0?l.value.trim():c.tagline||"Silence, Focus & Success",v=s&&s.value?s.value:c.alignment==="left"?"left":"center",g=n&&n.value?parseInt(n.value,10):parseInt(c.logoSize||"64",10);let x=`
      <!-- Form Header Branding Preview -->
      <div style="margin-bottom: 16px; text-align: ${v}; border-bottom: 1px solid var(--color-border); padding-bottom: 12px;">
        <div style="font-size: ${g>=96?"2.6rem":g<=48?"1.6rem":"2.1rem"}; margin-bottom: 4px;">\u{1F393}</div>
        <h3 style="margin: 0; font-size: 1.25rem; font-weight: 800; color: var(--color-text-primary);">${d(p)}</h3>
        <p style="margin: 3px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary);">${d(y)}</p>
      </div>

      <!-- Stepper Progress Dots -->
      <div style="display: flex; justify-content: space-between; margin-bottom: 16px; position: relative;">
        <div style="position: absolute; top: 12px; left: 10px; right: 10px; height: 2px; background: var(--color-border); z-index: 1;"></div>
        ${e.map((h,f)=>`
          <div style="position: relative; z-index: 2; width: 26px; height: 26px; border-radius: 50%; background: ${f<=this.currentPreviewStep?"#6c5ce7":"var(--color-surface)"}; border: 2px solid ${f<=this.currentPreviewStep?"#6c5ce7":"var(--color-border)"}; color: ${f<=this.currentPreviewStep?"#ffffff":"var(--color-text-secondary)"}; display: flex; align-items: center; justify-content: center; font-size: 0.75rem; font-weight: 800;">
            ${f+1}
          </div>
        `).join("")}
      </div>

      <!-- Step Card -->
      <div class="card p-3 mb-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: 10px;">
        <h4 style="margin: 0 0 14px 0; font-size: 0.95rem; font-weight: 800; color: #6c5ce7; border-bottom: 2px solid #6c5ce7; padding-bottom: 6px; display: flex; align-items: center; gap: 6px;">
          <span>${B[i.icon]||"\u{1F4C1}"}</span> ${d(i.label)}
        </h4>

        ${this.renderSectionContent(i,o)}
      </div>

      <!-- Navigation Buttons -->
      <div style="display: flex; gap: 10px; margin-top: 14px;">
        ${this.currentPreviewStep>0?'<button type="button" id="fb-prev-step" class="btn btn-outline-secondary btn-sm" style="flex: 1; font-weight: 700;">\u2B05\uFE0F Previous Section</button>':""}
        ${this.currentPreviewStep<a-1?'<button type="button" id="fb-next-step" class="btn btn-primary btn-sm" style="flex: 1; font-weight: 700;">Next Section \u27A1\uFE0F</button>':""}
        ${this.currentPreviewStep===a-1?'<button type="button" class="btn btn-success btn-sm" style="flex: 1; font-weight: 700;">\u{1F680} Complete Admission & Payment</button>':""}
      </div>
    `;t.innerHTML=x,t.querySelector("#fb-prev-step")?.addEventListener("click",()=>{this.currentPreviewStep--,this.renderPreview()}),t.querySelector("#fb-next-step")?.addEventListener("click",()=>{this.currentPreviewStep++,this.renderPreview()}),t.querySelector("#prev-branch-select")?.addEventListener("change",h=>{this.selectedBranchId=h.target.value,this.renderPreview()}),t.querySelector("#prev-plan-select")?.addEventListener("change",h=>{this.selectedPlanId=h.target.value,this.renderPreview()}),t.querySelectorAll('input[name="prev-pm-mode"]').forEach(h=>{h.addEventListener("change",f=>{this.selectedPaymentMode=f.target.value,this.renderPreview()})})}static renderSectionContent(t,e){const i=t.name;if(i==="personal")return`
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;">
          <div style="grid-column: 1 / -1;">
            <label class="form-label text-xs" style="font-weight:700;">Preferred Study Centre / Branch *</label>
            <select class="form-select form-control-sm" id="prev-branch-select">${this.branches.map(a=>`<option value="${a._id}" ${this.selectedBranchId===a._id?"selected":""}>${d(a.name)} \u2014 \u{1F7E2} ${a.availableSeats||42}/${a.totalSeats||100} Available Seats</option>`).join("")||"<option>Main Campus Central \u2014 \u{1F7E2} 48/50 Available Seats</option>"}</select>
          </div>

          ${e.map(a=>this.renderPreviewInput(a)).join("")}
        </div>
      `;if(i==="plan"){const a=this.template?.settings||{},o=a.showPlans!==!1,r=a.showLockerAddon!==!1,l=a.showReferralCoupon!==!1,s=a.showShiftSelection!==!1,n=a.showFeeBreakdown!==!1,c=this.plans.map(f=>{const w=Number(f.price)||0,S=Number(f.discount)||0,C=Math.round(f.effectivePrice!==void 0?f.effectivePrice:w*(1-S/100)),E=S>0?` [${S}% OFF]`:"";return`<option value="${f._id}" ${this.selectedPlanId===f._id?"selected":""}>${d(f.name)} \u2014 \u20B9${C.toLocaleString("en-IN")} / ${f.duration||1} ${f.durationType||"months"}${E} (${f.shift?f.shift.toUpperCase():"ANY SHIFT"})</option>`}).join(""),p=this.plans.find(f=>f._id===this.selectedPlanId)||this.plans[0]||{name:"Standard Full Day Plan",price:1e3,discount:30,shift:"All Day (24 Hours)"},y=Number(p.price)||0,v=Number(p.discount)||0,g=Math.round(y*(v/100)),x=Math.round(p.effectivePrice!==void 0?p.effectivePrice:y-g),h=Math.max(0,x+(r?200:0));return`
        <div style="display: flex; flex-direction: column; gap: 12px;">
          ${o?`
            <div>
              <label class="form-label text-xs" style="font-weight:700;">Select Membership Plan *</label>
              <select class="form-select form-control-sm" id="prev-plan-select">${c||"<option>Monthly Plan (\u20B9700/mo)</option>"}</select>
            </div>
          `:""}

          ${s?`
            <div>
              <label class="form-label text-xs" style="font-weight:700;">Preferred Study Shift / Timing</label>
              <select class="form-select form-control-sm">
                <option>Full Day (24 Hours - 24x7 Open)</option>
                <option>Morning (7:00 AM - 5:00 PM)</option>
                <option>Evening / Night (5:00 PM - 7:00 AM)</option>
              </select>
            </div>
          `:""}

          ${r?`
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 6px; padding: 8px 10px; font-size: 0.82rem; display: flex; align-items: center; gap: 8px;">
              <input type="checkbox" checked disabled style="width: 16px; height: 16px;">
              <span style="font-weight: 600;">\u{1F512} Add Personal Study Locker (+\u20B9200/mo)</span>
            </div>
          `:""}

          ${l?`
            <div style="display: flex; gap: 8px;">
              <input type="text" class="form-control form-control-sm" placeholder="Referral / Discount Code (Optional)">
              <button type="button" class="btn btn-outline-primary btn-sm" style="font-weight:700;">Apply</button>
            </div>
          `:""}

          <!-- Fee Summary Card -->
          ${n?`
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; font-size: 0.85rem;">
              <div style="font-weight: 700; color: var(--color-primary); margin-bottom: 6px;">\u{1F4B0} Live Fee Breakdown</div>
              <div style="display: flex; justify-content: space-between; margin-bottom: 4px;">
                <span>Base Plan Fee (${d(p.name)})</span>
                <span style="font-weight:700;">\u20B9${y.toLocaleString("en-IN")}</span>
              </div>
              ${v>0?`
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px; color: var(--color-danger, #ef4444);">
                  <span>Plan Discount (${v}% OFF)</span>
                  <span style="font-weight:700;">-\u20B9${g.toLocaleString("en-IN")}</span>
                </div>
              `:""}
              ${r?`
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px; color: var(--color-primary);">
                  <span>Locker Add-on Fee</span>
                  <span style="font-weight:700;">+\u20B9200</span>
                </div>
              `:""}
              ${l?`
                <div style="display: flex; justify-content: space-between; margin-bottom: 4px; color: var(--color-success);">
                  <span>Referral Discount</span>
                  <span style="font-weight:700;">-\u20B90</span>
                </div>
              `:""}
              <div style="display: flex; justify-content: space-between; border-top: 1px solid var(--color-border); padding-top: 6px; font-weight: 800; font-size: 0.95rem;">
                <span>Net Payable Amount</span>
                <span style="color: var(--color-primary);">\u20B9${h.toLocaleString("en-IN")}</span>
              </div>
            </div>
          `:""}

          ${e.map(f=>this.renderPreviewInput(f)).join("")}
        </div>
      `}if(i==="payment"){const a=this.template?.settings||{},o=a.showUpiPayment!==!1,r=a.showCardPayment!==!1,l=a.showDeskPayment!==!1,s=a.showNetBankingPayment!==!1,n=a.upiPaymentLabel||"Dynamic UPI QR",c=a.cardPaymentLabel||"Debit / Credit Card",p=a.deskPaymentLabel||"Pay Later at Desk",y=a.netBankingPaymentLabel||"NetBanking / Bank Transfer",v=[];return o&&v.push({mode:"upi",label:`\u26A1 ${n}`}),r&&v.push({mode:"card",label:`\u{1F4B3} ${c}`}),s&&v.push({mode:"netbanking",label:`\u{1F3E6} ${y}`}),l&&v.push({mode:"desk",label:`\u{1F4B5} ${p}`}),v.length>0&&!v.some(g=>g.mode===this.selectedPaymentMode)&&(this.selectedPaymentMode=v[0].mode),`
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <label class="form-label text-xs" style="font-weight:700;">Select Payment Mode *</label>
          ${v.length>0?`
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 8px;">
            ${v.map(g=>`
              <label style="border: 1px solid var(--color-border); border-radius: 8px; padding: 10px; font-size: 0.8rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 6px; background: ${this.selectedPaymentMode===g.mode?"var(--color-surface-hover)":"transparent"};">
                <input type="radio" name="prev-pm-mode" value="${g.mode}" ${this.selectedPaymentMode===g.mode?"checked":""}> ${d(g.label)}
              </label>
            `).join("")}
          </div>
          `:'<div class="text-muted small p-2">All payment methods currently toggled off by admin.</div>'}

          ${this.selectedPaymentMode==="upi"&&o?`
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; text-align: center;">
              <div style="font-weight: 700; font-size: 0.85rem; margin-bottom: 6px;">\u26A1 Scan QR Code or Pay via Mobile UPI App</div>
              <div style="width: 130px; height: 130px; background: #fff; border: 1px solid var(--color-border); border-radius: 8px; margin: 0 auto 10px auto; display: flex; align-items: center; justify-content: center; padding: 4px;">
                <img src="https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=thecozycorner@okaxis" style="width:100%;height:100%;object-fit:contain;">
              </div>
              <div style="display: flex; justify-content: center; gap: 4px; flex-wrap: wrap; margin-bottom: 8px;">
                <span class="badge badge-primary" style="font-size:0.68rem;">\u{1F535} GPay</span>
                <span class="badge badge-primary" style="font-size:0.68rem;">\u{1F7E3} PhonePe</span>
                <span class="badge badge-primary" style="font-size:0.68rem;">\u{1F499} Paytm</span>
              </div>
              <input type="text" class="form-control form-control-sm" placeholder="Enter 12-digit UPI UTR / Transaction No. *" required style="max-width: 320px; margin: 0 auto;">
            </div>
          `:""}

          ${e.map(g=>this.renderPreviewInput(g)).join("")}
        </div>
      `}if(i==="seat"){const a=this.template?.settings||{},o=a.showSeatSelection!==!1,r=a.seatSelectionLabel||"Choose Your Study Desk Seat",l=a.showDigitalSignature!==!1,s=a.digitalSignatureLabel||"Digital Signature Pad",n=a.showPassportSelfie!==!1,c=a.passportSelfieLabel||"Passport Selfie Capture",p=a.showQuietStudyAgreement!==!1,y=a.quietStudyConsentText||"I hereby agree to adhere to the Quiet Study Code Agreement, discipline rules, and timings of the study hall.",v=this.seats.length>0?this.seats:[{seatNumber:"01",zone:"Zone A"},{seatNumber:"02",zone:"Zone A"},{seatNumber:"03",zone:"Zone A"},{seatNumber:"04",zone:"Zone A"},{seatNumber:"05",zone:"Zone A"},{seatNumber:"06",zone:"Zone A"}];return`
        <div style="display: flex; flex-direction: column; gap: 14px;">
          ${o?`
          <div>
            <label class="form-label text-xs" style="font-weight:700;">${d(r)} ${a.seatSelectionRequired?"*":""}</label>
            <div style="display: flex; gap: 8px; overflow-x: auto; padding-bottom: 6px;">
              ${v.slice(0,6).map((g,x)=>`
                <div style="min-width: 60px; padding: 8px 6px; border: 1.5px solid ${x===0?"#6c5ce7":"var(--color-border)"}; border-radius: 8px; text-align: center; cursor: pointer; background: ${x===0?"rgba(108, 92, 231, 0.12)":"var(--color-surface)"};">
                  <div style="font-weight: 800; font-size: 0.9rem; color: #6c5ce7;">${d(g.seatNumber)}</div>
                  <div style="font-size: 0.65rem; color: var(--color-text-secondary);">${d(g.zone||"Zone A")}</div>
                </div>
              `).join("")}
            </div>
          </div>
          `:""}

          ${n?`
          <div>
            <label class="form-label text-xs" style="font-weight:700;">${d(c)} ${a.passportSelfieRequired?"*":""}</label>
            <div style="width: 100%; height: 75px; border: 1.5px dashed var(--color-border); border-radius: 8px; background: #ffffff; display: flex; flex-direction: column; align-items: center; justify-content: center; color: var(--color-text-secondary); font-size: 0.82rem;">
              <div style="color: #6c5ce7; font-weight: 600; display: flex; align-items: center; gap: 6px;">
                <span>\u{1F4F8}</span> <span>Passport photo / webcam selfie capture</span>
              </div>
            </div>
          </div>
          `:""}

          ${e.map(g=>this.renderPreviewInput(g)).join("")}

          ${l?`
          <div>
            <label class="form-label text-xs" style="font-weight:700;">${d(s)} ${a.digitalSignatureRequired!==!1?"*":""}</label>
            <div style="width: 100%; height: 85px; border: 1.5px dashed var(--color-border); border-radius: 8px; background: #ffffff; display: flex; flex-direction: column; align-items: center; justify-content: center; color: var(--color-text-secondary); font-size: 0.82rem;">
              <div style="color: #6c5ce7; font-weight: 600; display: flex; align-items: center; gap: 6px;">
                <span>\u270D\uFE0F</span> <span>Draw student signature canvas</span>
              </div>
            </div>
          </div>
          `:""}

          ${p?`
          <!-- Quiet Study Code Agreement & Terms Checkbox -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px;">
            <label style="display: flex; align-items: flex-start; gap: 10px; cursor: pointer; font-size: 0.83rem; color: var(--color-text-primary); margin: 0; line-height: 1.4;">
              <input type="checkbox" checked style="margin-top: 3px; accent-color: var(--color-primary); width: 16px; height: 16px;">
              <span>${d(y)} ${a.quietStudyRequired!==!1?'<span style="color: var(--color-danger);">*</span>':""}</span>
            </label>
          </div>
          `:""}
        </div>
      `}return`
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px;">
        ${e.length?e.map(a=>this.renderPreviewInput(a)).join(""):'<div class="text-muted small p-3 text-center">No questions in this section card.</div>'}
      </div>
    `}static renderPreviewInput(t){const e=t.required?' <span style="color: var(--color-danger);">*</span>':"",i=t.required?"required":"",a=t.colSpan===6?"grid-column: span 1;":"grid-column: 1 / -1;",o=`${d(t.label)}${e}`,r=t.helpText?`<small class="text-muted" style="display:block; font-size:0.7rem; margin-top:3px;">${d(t.helpText)}</small>`:"";if(t.type==="select"){const l=(t.options||[]).map(s=>`<option>${d(s)}</option>`).join("");return`
        <div style="${a}">
          <label class="form-label text-xs" style="font-weight:600;">${o}</label>
          <select class="form-select form-control-sm" ${i}><option value="">-- Select --</option>${l}</select>
          ${r}
        </div>
      `}if(t.type==="radio"){const l=(t.options||[]).map((s,n)=>`
        <label style="font-size:0.8rem; margin-right:8px; display:inline-flex; align-items:center; gap:4px;">
          <input type="radio" name="prev_${t._id}" ${n===0?"checked":""} ${i}> ${d(s)}
        </label>
      `).join("");return`
        <div style="${a}">
          <label class="form-label text-xs" style="font-weight:600;">${o}</label>
          <div>${l}</div>
          ${r}
        </div>
      `}return t.type==="textarea"?`
        <div style="${a}">
          <label class="form-label text-xs" style="font-weight:600;">${o}</label>
          <textarea class="form-control form-control-sm" rows="2" placeholder="${d(t.placeholder||"")}" ${i}></textarea>
          ${r}
        </div>
      `:`
      <div style="${a}">
        <label class="form-label text-xs" style="font-weight:600;">${o}</label>
        <input type="${t.type==="number"?"number":t.type==="date"?"date":"text"}" class="form-control form-control-sm" placeholder="${d(t.placeholder||"")}" ${i}>
        ${r}
      </div>
    `}static bindEvents(){document.getElementById("fb-view-desktop")?.addEventListener("click",()=>{this.previewDeviceMode="desktop";const t=document.getElementById("fb-preview-device-wrap");t&&(t.style.maxWidth="100%",t.style.padding="16px"),document.getElementById("fb-view-desktop").classList.replace("btn-ghost","btn-primary"),document.getElementById("fb-view-mobile").classList.replace("btn-primary","btn-ghost")}),document.getElementById("fb-view-mobile")?.addEventListener("click",()=>{this.previewDeviceMode="mobile";const t=document.getElementById("fb-preview-device-wrap");t&&(t.style.maxWidth="375px",t.style.padding="8px"),document.getElementById("fb-view-mobile").classList.replace("btn-ghost","btn-primary"),document.getElementById("fb-view-desktop").classList.replace("btn-primary","btn-ghost")}),document.getElementById("fb-toggle-branding-panel")?.addEventListener("click",()=>{const t=document.getElementById("fb-branding-panel");t&&(t.style.display=t.style.display==="none"?"block":"none")}),["headerText","tagline","alignment","logoSize"].forEach(t=>{const e=document.getElementById(`branding-${t}`);e&&(e.addEventListener("input",i=>{this.template.branding||(this.template.branding={}),this.template.branding[t]=i.target.value,this.renderPreview()}),e.addEventListener("change",i=>{this.template.branding||(this.template.branding={}),this.template.branding[t]=i.target.value,this.renderPreview()}))}),document.getElementById("fb-save-branding-btn")?.addEventListener("click",async()=>{try{this.template.branding||(this.template.branding={}),this.template.branding.headerText=document.getElementById("branding-headerText")?.value.trim()||"Student Admission Wizard",this.template.branding.tagline=document.getElementById("branding-tagline")?.value.trim()||"Silence, Focus & Success",this.template.branding.alignment=document.getElementById("branding-alignment")?.value||"center",this.template.branding.logoSize=document.getElementById("branding-logoSize")?.value||"64",await b.put("/api/custom-fields/templates/active",{branding:this.template.branding}),u.success("Header branding saved & synced to live admission form!")}catch(t){u.error(t.message||"Failed to save header branding")}}),document.getElementById("fb-add-section-btn")?.addEventListener("click",()=>{this.openAddSectionModal()}),document.getElementById("fb-paste-section-btn")?.addEventListener("click",()=>{this.pasteSection()}),document.getElementById("fb-add-field-btn")?.addEventListener("click",()=>{this.openFieldEditor(null)}),document.getElementById("fb-undo-btn")?.addEventListener("click",()=>{this.undoLastAction()})}static pushUndo(t){this.undoStack||(this.undoStack=[]),this.undoStack.push(t),this.updateUndoButton()}static updateUndoButton(){const t=document.getElementById("fb-undo-btn"),e=document.getElementById("fb-undo-count"),i=this.undoStack?this.undoStack.length:0;e&&(e.textContent=i),t&&(t.style.display=i>0?"inline-flex":"none")}static async undoLastAction(){if(!this.undoStack||this.undoStack.length===0)return;const t=this.undoStack.pop();if(this.updateUndoButton(),t&&typeof t.restore=="function")try{await t.restore()}catch(e){u.error("Failed to undo action: "+e.message)}}static async moveSection(t,e){const i=this.sections.findIndex(r=>r.name===t);if(i===-1)return;const a=i+e;if(a<0||a>=this.sections.length)return;const[o]=this.sections.splice(i,1);this.sections.splice(a,0,o),this.sections.forEach((r,l)=>{r.order=l+1}),this.renderSections(),this.renderPreview();try{this.template||(this.template={}),this.template.sections=this.sections,await b.put("/api/custom-fields/templates/active",{sections:this.sections}),u.success("Section order saved permanently to database!")}catch{u.error("Failed to save section order to server")}}static async deleteField(t){const e=this.fields.find(i=>i._id===t);if(e&&confirm(`Are you sure you want to delete question "${e.label}"?`))try{const i={...e};await b.delete(`/api/custom-fields/${t}`),this.fields=this.fields.filter(a=>a._id!==t),this.pushUndo({type:"delete_field",title:`Question "${e.label}"`,data:i,restore:async()=>{const a={...i};delete a._id,delete a.createdAt,delete a.updatedAt;const o=await b.post("/api/custom-fields",a);o.success&&o.data?this.fields.push(o.data):await this.loadData(),this.renderSections(),this.renderPreview(),u.success(`Question "${i.label}" restored!`)}}),u.undo(`Question "${e.label}" deleted.`,()=>{this.undoLastAction()}),this.renderSections(),this.renderPreview()}catch(i){u.error(i.message||"Failed to delete question field")}}static async deleteSection(t){const e=this.sections.find(i=>i.name===t);if(e&&confirm(`Are you sure you want to delete section "${e.label}"? Any questions inside will be moved to Personal Information.`))try{const i={...e},a=this.fields.filter(o=>o.section===t).map(o=>o._id);await b.delete(`/api/custom-fields/sections/${t}`),this.sections=this.sections.filter(o=>o.name!==t),this.sections.forEach((o,r)=>{o.order=r+1}),this.fields.forEach(o=>{o.section===t&&(o.section="personal")}),this.template||(this.template={}),this.template.sections=this.sections,await b.put("/api/custom-fields/templates/active",{sections:this.sections}),this.pushUndo({type:"delete_section",title:`Section "${e.label}"`,data:i,restore:async()=>{this.sections.push(i),this.sections.sort((o,r)=>(o.order||0)-(r.order||0)),this.template||(this.template={}),this.template.sections=this.sections,await b.put("/api/custom-fields/templates/active",{sections:this.sections}),a.length>0&&(await Promise.all(a.map(o=>b.put(`/api/custom-fields/${o}`,{section:i.name}))),await this.loadData()),this.renderSections(),this.renderPreview(),u.success(`Section "${i.label}" restored!`)}}),u.undo(`Section "${e.label}" deleted.`,()=>{this.undoLastAction()}),this.renderSections(),this.renderPreview()}catch(i){u.error(i.message||"Failed to delete section")}}static async toggleSectionVisibility(t){const e=this.sections.find(i=>i.name===t);if(e){e.isHidden=!e.isHidden,this.template||(this.template={}),this.template.sections=this.sections;try{await b.put("/api/custom-fields/templates/active",{sections:this.sections}),m.bustPublicFormCache(),u.success(`Section "${e.label}" is now ${e.isHidden?"Hidden \u{1F6AB} (Will not show to students)":"Visible \u{1F441}\uFE0F in registration form"}!`),this.renderSections(),this.renderPreview()}catch(i){console.error("Failed to update section visibility:",i),u.error("Failed to save section visibility")}}}static async toggleTemplateSetting(t,e){this.template||(this.template={}),this.template.settings||(this.template.settings={}),this.template.settings[t]=e;try{if(await b.put("/api/custom-fields/templates/active",{settings:this.template.settings}),t==="showLockerAddon")try{await b.put("/api/settings/system-settings",{"locker.enableAddon":e})}catch{}m.bustPublicFormCache(),u.success(`Display option updated: ${e?"Visible \u{1F441}\uFE0F":"Hidden \u{1F6AB}"} in registration form!`),this.renderPreview()}catch(i){console.error("Failed to update template setting:",i),u.error("Failed to save display setting")}}static openAddSectionModal(){const t=document.createElement("div");t.innerHTML=`
      <form id="fb-add-section-form" style="display: flex; flex-direction: column; gap: 14px;">
        <div class="form-group">
          <label class="form-label text-xs" style="font-weight:700;">Section Title *</label>
          <input type="text" id="as-label" class="form-control" placeholder="e.g. Step 6: Parent Consent & KYC" required>
        </div>
        
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Section Key/Slug *</label>
            <input type="text" id="as-key" class="form-control" placeholder="e.g. parent_kyc" required>
          </div>
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Section Icon Emoji</label>
            <input type="text" id="as-icon" class="form-control" value="\u{1F4C1}" placeholder="e.g. \u{1F4C4}">
          </div>
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
          <button type="button" class="btn btn-secondary btn-sm fb-cancel-modal-btn" data-modal-close="true">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">\u2795 Create Section</button>
        </div>
      </form>
    `;const e=new k({title:"\u{1F4C1} Add Custom Form Section",content:t,size:"sm"});e.show(),t.querySelector(".fb-cancel-modal-btn")?.addEventListener("click",()=>{e.close(),k.closeAll()}),t.querySelector("#as-label")?.addEventListener("input",i=>{const a=i.target.value.toLowerCase().replace(/[^a-z0-9_]/g,"_");t.querySelector("#as-key").value=a}),t.querySelector("#fb-add-section-form")?.addEventListener("submit",async i=>{i.preventDefault();const a=t.querySelector("#as-label").value.trim(),o=t.querySelector("#as-key").value.trim().toLowerCase().replace(/[^a-z0-9_]/g,"_"),r=t.querySelector("#as-icon").value.trim()||"\u{1F4C1}";if(this.sections.some(s=>s.name===o)){u.error("A section with this key already exists");return}const l={name:o,label:a,icon:r,order:this.sections.length+1,isSystem:!1};this.sections.push(l),this.template||(this.template={}),this.template.sections=this.sections;try{await b.put("/api/custom-fields/templates/active",{sections:this.sections}),u.success(`Custom Section "${a}" created & saved permanently!`)}catch{u.error("Failed to save section to database")}e.close(),this.renderSections(),this.renderPreview()})}static openRenameSectionModal(t){const e=this.sections.find(o=>o.name===t);if(!e)return;const i=document.createElement("div");i.innerHTML=`
      <form id="fb-rename-section-form" style="display: flex; flex-direction: column; gap: 14px;">
        <div class="form-group">
          <label class="form-label text-xs" style="font-weight:700;">Section Title / Step Heading *</label>
          <input type="text" id="rs-label" class="form-control" value="${d(e.label)}" required>
        </div>
        
        <div class="form-group">
          <label class="form-label text-xs" style="font-weight:700;">Section Icon Emoji</label>
          <input type="text" id="rs-icon" class="form-control" value="${d(e.icon||"\u{1F4C1}")}" placeholder="e.g. \u{1F464}, \u{1F4DA}, \u{1F48E}, \u{1F4B3}, \u{1F4BA}, \u{1F4CD}, \u{1F4C4}">
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
          <button type="button" class="btn btn-secondary btn-sm fb-cancel-modal-btn" data-modal-close="true">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">\u{1F4BE} Update Section</button>
        </div>
      </form>
    `;const a=new k({title:`\u270F\uFE0F Rename Section: ${e.label}`,content:i,size:"sm"});a.show(),i.querySelector(".fb-cancel-modal-btn")?.addEventListener("click",()=>{a.close(),k.closeAll()}),i.querySelector("#fb-rename-section-form")?.addEventListener("submit",async o=>{o.preventDefault();const r=i.querySelector("#rs-label").value.trim(),l=i.querySelector("#rs-icon").value.trim()||"\u{1F4C1}";e.label=r,e.icon=l,this.template||(this.template={}),this.template.sections=this.sections;try{await b.put("/api/custom-fields/templates/active",{sections:this.sections});try{await b.put(`/api/custom-fields/sections/${t}`,{label:r,icon:l})}catch{}u.success(`Section renamed to "${r}" successfully!`)}catch{u.error("Failed to save renamed section")}a.close(),this.renderSections(),this.renderPreview()})}static copyField(t){const e=this.fields.find(a=>String(a._id)===String(t));if(!e)return;const i={label:e.label,type:e.type,required:!!e.required,colSpan:e.colSpan||12,placeholder:e.placeholder||"",helpText:e.helpText||"",defaultValue:e.defaultValue||"",options:Array.isArray(e.options)?[...e.options]:[],validation:e.validation?{...e.validation}:{},showIf:e.showIf?{...e.showIf}:void 0,conditionalSubType:e.conditionalSubType||void 0,icon:e.icon||"",fieldName:e.fieldName||e.name||"field"};m.copiedField=i;try{localStorage.setItem("fb_copied_field",JSON.stringify(i))}catch{}u.success(`\u{1F4CB} Question "${e.label}" copied! Click "\u{1F4CB} Paste Q" in any section.`)}static async duplicateField(t){const e=this.fields.find(o=>String(o._id)===String(t));if(!e)return;const i=Date.now().toString(36).slice(-4),a={fieldName:`${(e.fieldName||e.name||"field").replace(/_copy.*$/,"")}_copy_${i}`,label:`${e.label} (Copy)`,type:e.type,section:e.section||"personal",required:!!e.required,colSpan:e.colSpan||12,placeholder:e.placeholder||"",helpText:e.helpText||"",defaultValue:e.defaultValue||"",options:Array.isArray(e.options)?[...e.options]:[],validation:e.validation?{...e.validation}:{},showIf:e.showIf?{...e.showIf}:void 0,conditionalSubType:e.conditionalSubType||void 0,icon:e.icon||"",isActive:!0,order:(e.order||0)+1};try{F.show("Duplicating question..."),await b.post("/api/custom-fields",a),F.hide(),u.success(`Question duplicated as "${a.label}"`),await m.loadData()}catch(o){F.hide(),u.error(o.message||"Failed to duplicate question")}}static async pasteField(t){let e=m.copiedField;if(!e)try{const o=localStorage.getItem("fb_copied_field");o&&(e=JSON.parse(o))}catch{}if(!e){u.warning("No question copied yet. Click \u{1F4CB} Copy on any question first!");return}const i=Date.now().toString(36).slice(-4),a={fieldName:`${(e.fieldName||"field").replace(/_copy.*$/,"")}_copy_${i}`,label:`${e.label} (Copy)`,type:e.type,section:t,required:!!e.required,colSpan:e.colSpan||12,placeholder:e.placeholder||"",helpText:e.helpText||"",defaultValue:e.defaultValue||"",options:Array.isArray(e.options)?[...e.options]:[],validation:e.validation?{...e.validation}:{},showIf:e.showIf?{...e.showIf}:void 0,conditionalSubType:e.conditionalSubType||void 0,icon:e.icon||"",isActive:!0,order:this.fields.filter(o=>o.section===t).length+1};try{F.show("Pasting question into section..."),await b.post("/api/custom-fields",a),F.hide(),u.success(`Pasted "${a.label}" into section!`),await m.loadData()}catch(o){F.hide(),u.error(o.message||"Failed to paste question")}}static copySection(t){const e=this.sections.find(o=>o.name===t);if(!e)return;const i=this.fields.filter(o=>(o.section||"personal")===t),a={section:{name:e.name,label:e.label,icon:e.icon},fields:i.map(o=>({fieldName:o.fieldName||o.name,label:o.label,type:o.type,required:!!o.required,colSpan:o.colSpan||12,placeholder:o.placeholder||"",helpText:o.helpText||"",defaultValue:o.defaultValue||"",options:Array.isArray(o.options)?[...o.options]:[],validation:o.validation?{...o.validation}:{},showIf:o.showIf?{...o.showIf}:void 0,icon:o.icon||""}))};m.copiedSection=a;try{localStorage.setItem("fb_copied_section",JSON.stringify(a))}catch{}u.success(`\u{1F4CB} Section "${e.label}" & ${i.length} questions copied! Click "\u{1F4CB} Paste Section" in toolbar.`)}static async pasteSection(){let t=m.copiedSection;if(!t)try{const r=localStorage.getItem("fb_copied_section");r&&(t=JSON.parse(r))}catch{}if(!t||!t.section){u.warning("No section copied yet. Click \u{1F4CB} Copy Sec on any section first!");return}const e=Date.now().toString(36).slice(-4),i=`${t.section.name.replace(/_copy.*$/,"")}_copy_${e}`,a=`${t.section.label} (Copy)`,o={name:i,label:a,icon:t.section.icon||"\u{1F4C1}",order:this.sections.length+1,isSystem:!1};this.sections.push(o),this.template||(this.template={}),this.template.sections=this.sections;try{if(F.show("Pasting section and questions..."),await b.put("/api/custom-fields/templates/active",{sections:this.sections}),Array.isArray(t.fields))for(const[r,l]of t.fields.entries()){const s=`${l.fieldName}_${e}`;await b.post("/api/custom-fields",{fieldName:s,label:l.label,type:l.type,section:i,required:!!l.required,colSpan:l.colSpan||12,placeholder:l.placeholder||"",helpText:l.helpText||"",defaultValue:l.defaultValue||"",options:l.options||[],validation:l.validation||{},showIf:l.showIf,icon:l.icon||"",isActive:!0,order:r+1})}F.hide(),u.success(`Pasted section "${a}" with ${t.fields?.length||0} questions!`),await m.loadData()}catch(r){F.hide(),u.error(r.message||"Failed to paste section")}}static bustPublicFormCache(){try{if(localStorage.removeItem("sl_public_config_cache"),localStorage.removeItem("sl_public_profile_cache"),localStorage.setItem("sl_config_version",Date.now().toString()),typeof BroadcastChannel<"u"){const t=new BroadcastChannel("sl_channel");t.postMessage({type:"FORM_UPDATED",timestamp:Date.now()}),setTimeout(()=>t.close(),100)}}catch{}}static async toggleFieldActive(t){const e=this.fields.find(i=>i._id===t);if(e){e.isActive=e.isActive===!1,this.renderSections(),this.renderPreview(),m.bustPublicFormCache();try{await b.put(`/api/custom-fields/${t}`,{isActive:e.isActive}),m.bustPublicFormCache(),u.success(`Question "${e.label}" is now ${e.isActive?"Active \u{1F7E2} (Visible in form)":"Hidden \u26AA (Will not show to students)"}`)}catch{u.error("Failed to update question status")}}}static async moveField(t,e){const i=this.fields.find(n=>String(n._id)===String(t)||String(n.fieldName)===String(t));if(!i)return;const a=i.section||"personal",o=this.fields.filter(n=>(n.section||"personal")===a).sort((n,c)=>(n.order||0)-(c.order||0)),r=o.findIndex(n=>String(n._id)===String(t)||String(n.fieldName)===String(t));if(r===-1)return;const l=r+e;if(l<0||l>=o.length)return;const[s]=o.splice(r,1);o.splice(l,0,s),o.forEach((n,c)=>{n.order=c+1}),this.renderSections(),this.renderPreview();try{const n=this.fields.map(p=>({id:p._id,fieldName:p.fieldName,order:p.order,section:p.section})),c=await b.put("/api/custom-fields/reorder",{orders:n});if(m.bustPublicFormCache(),c&&c.success)u.success("Question order saved permanently");else throw new Error(c?.message||"Save failed")}catch(n){u.error("Failed to save field order: "+(n.message||"Server error"))}}static openComponentEditor(t){this.template||(this.template={}),this.template.settings||(this.template.settings={});const e=this.template.settings;let i="\u2699\uFE0F Edit System Component",a="";if(t==="plan_manager"){i="\u{1F48E} Edit Membership Study Plans Display";const l=e.planGridLabel||"Membership Study Plans Grid",s=e.planGridSubtext||"Interactive visual study plan cards with duration & shift filters",n=e.showPlans!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Section Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Show Membership Plans Grid in Registration Portal</span>
          </label>
        </div>
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; font-size: 0.8rem;">
          <div style="font-weight: 700; color: var(--color-primary); margin-bottom: 6px; display: flex; justify-content: space-between; align-items: center;">
            <span>\u{1F4CB} Active Database Plans (${this.plans?.length||0})</span>
            <a href="#/plans" class="btn btn-xs btn-outline-primary" style="font-weight: 700;">Edit in Plans & Pricing \u2197</a>
          </div>
          ${this.plans&&this.plans.length>0?`
            <div style="overflow-x: auto;">
              <table class="table table-sm" style="font-size: 0.75rem; margin-bottom: 0;">
                <thead>
                  <tr style="color: var(--color-text-secondary);">
                    <th>Plan Name</th>
                    <th>Shift</th>
                    <th>Base Price</th>
                    <th>Discount</th>
                    <th>Effective Price</th>
                  </tr>
                </thead>
                <tbody>
                  ${this.plans.map(c=>{const p=Number(c.price)||0,y=Number(c.discount)||0,v=Math.round(c.effectivePrice!==void 0?c.effectivePrice:p*(1-y/100));return`
                      <tr>
                        <td><strong>${d(c.name)}</strong> <small class="text-muted">(${c.duration||1} ${c.durationType||"mo"})</small></td>
                        <td><span class="badge badge-secondary" style="font-size: 0.65rem;">${d(c.shift||"fullday")}</span></td>
                        <td style="${y>0?"text-decoration: line-through; color: var(--color-text-muted);":""}">\u20B9${p.toLocaleString("en-IN")}</td>
                        <td>${y>0?`<span class="badge badge-danger" style="font-size: 0.65rem;">${y}% OFF</span>`:"\u2014"}</td>
                        <td><strong style="color: var(--color-primary);">\u20B9${v.toLocaleString("en-IN")}</strong></td>
                      </tr>
                    `}).join("")}
                </tbody>
              </table>
            </div>
          `:'<div style="color: var(--color-text-secondary);">No active plans found in database.</div>'}
        </div>
      `}else if(t==="locker_addon"){i="\u{1F512} Edit Personal Study Locker Add-on Option";const l=e.lockerAddonLabel||"Personal Study Locker Add-on Option",s=e.lockerAddonSubtext||'Optional "+\u20B9200/mo personal study locker" toggle for students',n=e.lockerAddonPrice||200,c=e.showLockerAddon!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Option Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Monthly Locker Surcharge (\u20B9) *</label>
          <input type="number" id="ce-locker-price" class="form-control" value="${n}" min="0" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${c?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Locker Add-on in Student Registration Form</span>
          </label>
        </div>
      `}else if(t==="coupon_addon"){i="\u{1F39F}\uFE0F Edit Referral / Discount Coupon Promo Field";const l=e.couponLabel||"Referral / Discount Coupon Code Input",s=e.couponPlaceholder||"Enter promo code (e.g. SAVE100)",n=e.couponSubtext||"Automatic instant discount verification & fee reduction",c=e.showReferralCoupon!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Field Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Placeholder Text</label>
          <input type="text" id="ce-placeholder" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(n)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${c?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Coupon Promo Code Field in Registration Form</span>
          </label>
        </div>
      `}else if(t==="shift_selection"){i="\u23F0 Edit Preferred Study Shift / Timing Selection";const l=e.shiftSelectionLabel||"Preferred Study Shift / Timing Selection",s=e.shiftSelectionSubtext||"Morning, Evening, Night & 24h Full Day shift selection picker",n=e.showShiftSelection!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Picker Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Study Shift Selection in Registration Form</span>
          </label>
        </div>
      `}else if(t==="fee_calculator"){i="\u{1F4B0} Edit Live Fee Breakdown Auto-Calculator Card";const l=e.feeBreakdownLabel||"Live Fee Breakdown Auto-Calculator Card",s=e.feeBreakdownSubtext||"Real-time itemized price breakdown (Plan base + Locker - Discount = Total)",n=e.showFeeBreakdown!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Calculator Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Show Live Fee Breakdown Auto-Calculator</span>
          </label>
        </div>
      `}else if(t==="receipt_whatsapp"){i="\u{1F4F1} Edit Automated WhatsApp Receipt Dispatch";const l=e.whatsappReceiptLabel||"Automated WhatsApp Receipt",s=e.whatsappReceiptSubtext||"Instant fee receipt message dispatch to student's WhatsApp number",n=e.showWhatsappReceipt!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Receipt Notice Label *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Send Instant WhatsApp Fee Receipt to Student</span>
          </label>
        </div>
      `}else if(t==="receipt_email"){i="\u2709\uFE0F Edit Email Payment Confirmation Notice";const l=e.emailConfirmationLabel||"Email Payment Confirmation",s=e.emailConfirmationSubtext||"PDF payment receipt and registration confirmation via email",n=e.showEmailConfirmation!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Confirmation Label *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Send Email Payment Confirmation with PDF</span>
          </label>
        </div>
      `}else if(t==="receipt_tax"){i="\u{1F4C4} Edit Tax Invoice Generation Notice";const l=e.taxInvoiceLabel||"Tax Invoice Generation",s=e.taxInvoiceSubtext||"Compliant GST/Tax invoice calculation with printable receipt format",n=e.showTaxInvoice!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Invoice Notice Label *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Tax / GST Invoice Generation</span>
          </label>
        </div>
      `}else if(t==="upi"){i="\u26A1 Edit Dynamic UPI QR Payment Gateway";const l=e.upiPaymentLabel||"Dynamic UPI QR",s=e.upiPaymentSubtext||"GPay / PhonePe / Paytm + 12-digit UTR Verification",n=e.showUpiPayment!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Gateway Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Dynamic UPI QR in Student Registration Form</span>
          </label>
        </div>
      `}else if(t==="desk"){i="\u{1F4B5} Edit Pay Later at Desk Payment Method";const l=e.deskPaymentLabel||"Pay Later at Desk",s=e.deskPaymentSubtext||"Pre-reserves admission & seat; cash paid on arrival",n=e.showDeskPayment!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Method Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Cash Policy Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Pay Later at Desk in Student Registration Form</span>
          </label>
        </div>
      `}else if(t==="netbanking"){i="\u{1F3E6} Edit NetBanking / Cards Payment Gateway";const l=e.netBankingPaymentLabel||"NetBanking / Cards",s=e.netBankingPaymentSubtext||"Bank reference logging & printable receipt generator",n=e.showNetBankingPayment!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Gateway Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Subtitle / Bank Transfer Note</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable NetBanking / Cards in Student Registration Form</span>
          </label>
        </div>
      `}else if(t==="receipt_options"){i="\u{1F4E9} Edit Automated Receipts & Invoicing Notices";const l=e.whatsappReceiptLabel||"Automated WhatsApp Receipt",s=e.emailConfirmationLabel||"Email Payment Confirmation",n=e.taxInvoiceLabel||"Tax Invoice Generation",c=e.showWhatsappReceipt!==!1,p=e.showEmailConfirmation!==!1,y=e.showTaxInvoice!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">WhatsApp Receipt Label</label>
          <input type="text" id="ce-wa-label" class="form-control" value="${d(l)}">
          <label class="switch-label mt-2" style="font-weight: 600; font-size: 0.82rem;">
            <input type="checkbox" id="ce-wa-active" ${c?"checked":""}>
            <span class="switch-slider"></span>
            <span>Send Instant WhatsApp Fee Receipt</span>
          </label>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Email Confirmation Label</label>
          <input type="text" id="ce-em-label" class="form-control" value="${d(s)}">
          <label class="switch-label mt-2" style="font-weight: 600; font-size: 0.82rem;">
            <input type="checkbox" id="ce-em-active" ${p?"checked":""}>
            <span class="switch-slider"></span>
            <span>Send Email Payment Confirmation</span>
          </label>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Tax Invoice Label</label>
          <input type="text" id="ce-tax-label" class="form-control" value="${d(n)}">
          <label class="switch-label mt-2" style="font-weight: 600; font-size: 0.82rem;">
            <input type="checkbox" id="ce-tax-active" ${y?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Tax Invoice Generation</span>
          </label>
        </div>
      `}else if(t==="payment_all"){i="\u2699\uFE0F Configure All Payment Gateways & Portal Methods";const l=e.showUpiPayment!==!1,s=e.showCardPayment!==!1,n=e.showDeskPayment!==!1,c=e.showNetBankingPayment!==!1,p=e.upiPaymentLabel||"Dynamic UPI QR",y=e.cardPaymentLabel||"Debit / Credit Card",v=e.deskPaymentLabel||"Pay Later at Desk",g=e.netBankingPaymentLabel||"NetBanking / Bank Transfer";a=`
        <div style="display: flex; flex-direction: column; gap: 12px;">
          <!-- 1. UPI QR -->
          <div style="background: var(--color-bg-secondary); padding: 12px; border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span style="font-weight: 700; font-size: 0.85rem;">\u26A1 Dynamic UPI QR & 1-Tap UPI</span>
              <input type="checkbox" id="ce-all-upi" ${l?"checked":""} style="width: 18px; height: 18px; accent-color: var(--color-primary); cursor: pointer;">
            </div>
            <input type="text" id="ce-all-upi-label" class="form-control form-control-sm" value="${d(p)}" placeholder="Gateway Display Name">
          </div>

          <!-- 2. Card -->
          <div style="background: var(--color-bg-secondary); padding: 12px; border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span style="font-weight: 700; font-size: 0.85rem;">\u{1F4B3} Debit / Credit Card & POS</span>
              <input type="checkbox" id="ce-all-card" ${s?"checked":""} style="width: 18px; height: 18px; accent-color: var(--color-primary); cursor: pointer;">
            </div>
            <input type="text" id="ce-all-card-label" class="form-control form-control-sm" value="${d(y)}" placeholder="Gateway Display Name">
          </div>

          <!-- 3. Pay Later at Desk -->
          <div style="background: var(--color-bg-secondary); padding: 12px; border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span style="font-weight: 700; font-size: 0.85rem;">\u{1F4B5} Pay Later at Front Desk (Cash)</span>
              <input type="checkbox" id="ce-all-desk" ${n?"checked":""} style="width: 18px; height: 18px; accent-color: var(--color-primary); cursor: pointer;">
            </div>
            <input type="text" id="ce-all-desk-label" class="form-control form-control-sm" value="${d(v)}" placeholder="Method Display Name">
          </div>

          <!-- 4. NetBanking -->
          <div style="background: var(--color-bg-secondary); padding: 12px; border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px;">
              <span style="font-weight: 700; font-size: 0.85rem;">\u{1F3E6} NetBanking / Bank Transfer</span>
              <input type="checkbox" id="ce-all-nb" ${c?"checked":""} style="width: 18px; height: 18px; accent-color: var(--color-primary); cursor: pointer;">
            </div>
            <input type="text" id="ce-all-nb-label" class="form-control form-control-sm" value="${d(g)}" placeholder="Gateway Display Name">
          </div>
        </div>
      `}else if(t==="seat_map"){i="\u{1FA91} Edit Live Seat Selection Map & Badges";const l=e.seatSelectionLabel||"Circular Seat Badges / Desk Map",s=e.seatSelectionSubtext||"22px round circular seat checkmarks with Indigo glow",n=e.showSeatSelection!==!1,c=!!e.seatSelectionRequired;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Component Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Badge Style & Description</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Live Seat Selection Map</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-required" ${c?"checked":""}>
            <span class="switch-slider"></span>
            <span>Require Student to Select Desk (Mandatory)</span>
          </label>
        </div>
      `}else if(t==="signature"){i="\u270D\uFE0F Edit Digital Signature Canvas";const l=e.digitalSignatureLabel||"Digital Signature Canvas",s=e.digitalSignatureSubtext||"Touch & stylus interactive drawing pad",n=e.showDigitalSignature!==!1,c=e.digitalSignatureRequired!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Canvas Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Instructions / Subtext</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Digital Signature Canvas</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-required" ${c?"checked":""}>
            <span class="switch-slider"></span>
            <span>Mandatory Signature to Complete Admission</span>
          </label>
        </div>
      `}else if(t==="passport_photo"){i="\u{1F4F8} Edit Passport Selfie Capture";const l=e.passportSelfieLabel||"Passport Selfie Capture",s=e.passportSelfieSubtext||"Webcam photo & document crop studio",n=e.showPassportSelfie!==!1,c=!!e.passportSelfieRequired;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Studio Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Studio Subtitle / Instructions</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Enable Passport Photo / Live Selfie Studio</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-required" ${c?"checked":""}>
            <span class="switch-slider"></span>
            <span>Mandatory Photo for ID Card Issuance</span>
          </label>
        </div>
      `}else if(t==="quiet_study"){i="\u{1F4DC} Edit Quiet Study Code & Library Rules Agreement";const l=e.quietStudyAgreementTitle||"Quiet Study Code & Library Rules Agreement",s=e.quietStudyAgreementRules||`1. Pin-Drop Silence: Strict silence must be maintained inside reading halls at all times. Whispering or phone calls inside study zones is strictly forbidden.
2. Mobile Phone Protocol: Phones must be switched to silent or flight mode. Attend urgent phone calls outside in corridors.
3. Assigned Desk Protocol: Occupy only your allotted desk number and adhere strictly to your registered shift timing.
4. Cleanliness & Socket Safety: Keep your study desk clean. Turn off lights, fans, and socket chargers when leaving your seat.
5. ID Pass & Gate Access: Carry your Student ID / Registration Pass for kiosk check-in.
6. Fee Policy & Non-Refundability: Membership fees once paid are non-refundable.`,n=e.quietStudyConsentText||"I have read, understood, and agree to strictly abide by the Library Rules, Code of Conduct, and Payment Policies.",c=e.showQuietStudyAgreement!==!1,p=e.quietStudyRequired!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Agreement Header Title *</label>
          <input type="text" id="ce-agree-title" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
            <label class="form-label text-xs" style="font-weight:700; margin: 0;">Library Rules & Code of Conduct (Line-by-line editor) *</label>
            <span style="font-size: 0.72rem; color: var(--color-text-secondary);">One rule per line</span>
          </div>
          <textarea id="ce-agree-rules" class="form-control" rows="7" style="font-family: monospace; font-size: 0.82rem; line-height: 1.5;" required>${d(s)}</textarea>
          <small class="text-muted" style="font-size: 0.72rem;">Each line will render as a distinct rule point in the student's scrollable agreement review box.</small>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Student Consent Checkbox Label *</label>
          <input type="text" id="ce-agree-consent" class="form-control" value="${d(n)}" required>
        </div>
        <div class="form-group mb-3" style="display: flex; flex-direction: column; gap: 8px; background: var(--color-bg-secondary); padding: 10px; border-radius: 8px;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-agree-active" ${c?"checked":""}>
            <span class="switch-slider"></span>
            <span>Show Quiet Study Code Agreement in Registration Form</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="ce-agree-req" ${p?"checked":""}>
            <span class="switch-slider"></span>
            <span>Mandatory Agreement Checkbox (Student must agree before submission)</span>
          </label>
        </div>
      `}else if(t==="kiosk_barcode"){i="\u{1F3AB} Edit Kiosk Entry Barcode Pass";const l=e.kioskBarcodeLabel||"Kiosk Entry Barcode",s=e.kioskBarcodeSubtext||"Instant admission barcode for turnstile / attendance gate",n=e.showKioskBarcode!==!1;a=`
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Badge Title *</label>
          <input type="text" id="ce-label" class="form-control" value="${d(l)}" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label text-xs" style="font-weight:700;">Description</label>
          <input type="text" id="ce-subtext" class="form-control" value="${d(s)}">
        </div>
        <div class="form-group mb-3">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem;">
            <input type="checkbox" id="ce-active" ${n?"checked":""}>
            <span class="switch-slider"></span>
            <span>Generate Kiosk Barcode on Student Pass</span>
          </label>
        </div>
      `}const o=document.createElement("div");o.innerHTML=`
      <form id="fb-component-edit-form" style="display: flex; flex-direction: column; gap: 14px;">
        ${a}
        <div style="display: flex; justify-content: flex-end; gap: 10px; border-top: 1px solid var(--color-border); padding-top: 14px; margin-top: 6px;">
          <button type="button" class="btn btn-secondary fb-cancel-modal-btn">Cancel</button>
          <button type="submit" class="btn btn-primary" style="font-weight: 700;">\u{1F4BE} Save Changes</button>
        </div>
      </form>
    `;const r=new k({title:i,content:o,size:"md"});r.show(),o.querySelector(".fb-cancel-modal-btn")?.addEventListener("click",()=>{r.close(),k.closeAll()}),o.querySelector("#fb-component-edit-form")?.addEventListener("submit",async l=>{l.preventDefault();try{if(t==="plan_manager")e.planGridLabel=o.querySelector("#ce-label").value.trim(),e.planGridSubtext=o.querySelector("#ce-subtext").value.trim(),e.showPlans=o.querySelector("#ce-active").checked;else if(t==="locker_addon")e.lockerAddonLabel=o.querySelector("#ce-label").value.trim(),e.lockerAddonPrice=Number(o.querySelector("#ce-locker-price").value)||200,e.lockerAddonSubtext=o.querySelector("#ce-subtext").value.trim(),e.showLockerAddon=o.querySelector("#ce-active").checked;else if(t==="coupon_addon")e.couponLabel=o.querySelector("#ce-label").value.trim(),e.couponPlaceholder=o.querySelector("#ce-placeholder").value.trim(),e.couponSubtext=o.querySelector("#ce-subtext").value.trim(),e.showReferralCoupon=o.querySelector("#ce-active").checked;else if(t==="shift_selection")e.shiftSelectionLabel=o.querySelector("#ce-label").value.trim(),e.shiftSelectionSubtext=o.querySelector("#ce-subtext").value.trim(),e.showShiftSelection=o.querySelector("#ce-active").checked;else if(t==="fee_calculator")e.feeBreakdownLabel=o.querySelector("#ce-label").value.trim(),e.feeBreakdownSubtext=o.querySelector("#ce-subtext").value.trim(),e.showFeeBreakdown=o.querySelector("#ce-active").checked;else if(t==="receipt_whatsapp")e.whatsappReceiptLabel=o.querySelector("#ce-label").value.trim(),e.whatsappReceiptSubtext=o.querySelector("#ce-subtext").value.trim(),e.showWhatsappReceipt=o.querySelector("#ce-active").checked;else if(t==="receipt_email")e.emailConfirmationLabel=o.querySelector("#ce-label").value.trim(),e.emailConfirmationSubtext=o.querySelector("#ce-subtext").value.trim(),e.showEmailConfirmation=o.querySelector("#ce-active").checked;else if(t==="receipt_tax")e.taxInvoiceLabel=o.querySelector("#ce-label").value.trim(),e.taxInvoiceSubtext=o.querySelector("#ce-subtext").value.trim(),e.showTaxInvoice=o.querySelector("#ce-active").checked;else if(t==="upi")e.upiPaymentLabel=o.querySelector("#ce-label").value.trim(),e.upiPaymentSubtext=o.querySelector("#ce-subtext").value.trim(),e.showUpiPayment=o.querySelector("#ce-active").checked;else if(t==="desk")e.deskPaymentLabel=o.querySelector("#ce-label").value.trim(),e.deskPaymentSubtext=o.querySelector("#ce-subtext").value.trim(),e.showDeskPayment=o.querySelector("#ce-active").checked;else if(t==="netbanking")e.netBankingPaymentLabel=o.querySelector("#ce-label").value.trim(),e.netBankingPaymentSubtext=o.querySelector("#ce-subtext").value.trim(),e.showNetBankingPayment=o.querySelector("#ce-active").checked;else if(t==="receipt_options")e.whatsappReceiptLabel=o.querySelector("#ce-wa-label").value.trim(),e.showWhatsappReceipt=o.querySelector("#ce-wa-active").checked,e.emailConfirmationLabel=o.querySelector("#ce-em-label").value.trim(),e.showEmailConfirmation=o.querySelector("#ce-em-active").checked,e.taxInvoiceLabel=o.querySelector("#ce-tax-label").value.trim(),e.showTaxInvoice=o.querySelector("#ce-tax-active").checked;else if(t==="card")e.cardPaymentLabel=o.querySelector("#ce-label").value.trim(),e.cardPaymentSubtext=o.querySelector("#ce-subtext").value.trim(),e.showCardPayment=o.querySelector("#ce-active").checked;else if(t==="payment_all")e.showUpiPayment=o.querySelector("#ce-all-upi").checked,e.upiPaymentLabel=o.querySelector("#ce-all-upi-label").value.trim(),e.showCardPayment=o.querySelector("#ce-all-card").checked,e.cardPaymentLabel=o.querySelector("#ce-all-card-label").value.trim(),e.showDeskPayment=o.querySelector("#ce-all-desk").checked,e.deskPaymentLabel=o.querySelector("#ce-all-desk-label").value.trim(),e.showNetBankingPayment=o.querySelector("#ce-all-nb").checked,e.netBankingPaymentLabel=o.querySelector("#ce-all-nb-label").value.trim();else if(t==="seat_map")e.seatSelectionLabel=o.querySelector("#ce-label").value.trim(),e.seatSelectionSubtext=o.querySelector("#ce-subtext").value.trim(),e.showSeatSelection=o.querySelector("#ce-active").checked,e.seatSelectionRequired=o.querySelector("#ce-required").checked;else if(t==="signature")e.digitalSignatureLabel=o.querySelector("#ce-label").value.trim(),e.digitalSignatureSubtext=o.querySelector("#ce-subtext").value.trim(),e.showDigitalSignature=o.querySelector("#ce-active").checked,e.digitalSignatureRequired=o.querySelector("#ce-required").checked;else if(t==="passport_photo")e.passportSelfieLabel=o.querySelector("#ce-label").value.trim(),e.passportSelfieSubtext=o.querySelector("#ce-subtext").value.trim(),e.showPassportSelfie=o.querySelector("#ce-active").checked,e.passportSelfieRequired=o.querySelector("#ce-required").checked;else if(t==="quiet_study"){e.quietStudyAgreementTitle=o.querySelector("#ce-agree-title").value.trim(),e.quietStudyAgreementRules=o.querySelector("#ce-agree-rules").value.trim(),e.quietStudyConsentText=o.querySelector("#ce-agree-consent").value.trim(),e.showQuietStudyAgreement=o.querySelector("#ce-agree-active").checked,e.quietStudyRequired=o.querySelector("#ce-agree-req").checked;try{const s=e.quietStudyAgreementRules.split(`
`).map(n=>n.trim()).filter(Boolean);await b.put("/api/settings/profile",{rules:s})}catch{}}else t==="kiosk_barcode"&&(e.kioskBarcodeLabel=o.querySelector("#ce-label").value.trim(),e.kioskBarcodeSubtext=o.querySelector("#ce-subtext").value.trim(),e.showKioskBarcode=o.querySelector("#ce-active").checked);await b.put("/api/custom-fields/templates/active",{settings:e}),m.bustPublicFormCache(),u.success("Component settings saved successfully!"),r.close(),k.closeAll(),this.renderSections(),this.renderPreview()}catch(s){u.error(s.message||"Failed to save component settings")}})}static openFieldEditor(t,e=null){const i=this.fields.find(s=>s._id===t)||{label:"",fieldName:"",type:"text",section:e||"personal",required:!1,placeholder:"",helpText:"",colSpan:12,options:["Option 1","Option 2"]},a=!!t,o=this.sections.map(s=>`<option value="${s.name}" ${i.section===s.name?"selected":""}>${d(s.label)}</option>`).join(""),r=document.createElement("div");r.innerHTML=`
      <form id="fb-field-edit-form" style="display: flex; flex-direction: column; gap: 14px;">
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Question Label *</label>
            <input type="text" id="fe-label" class="form-control" value="${d(i.label)}" placeholder="e.g. Target Exam" required>
          </div>
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Field Slug/Key *</label>
            <input type="text" id="fe-key" class="form-control" value="${d(i.fieldName||i.name||"")}" placeholder="e.g. target_exam" ${a?"readonly":"required"}>
          </div>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Question Type *</label>
            <select id="fe-type" class="form-select">
              <option value="text" ${i.type==="text"?"selected":""}>\u{1F4DD} Short Text</option>
              <option value="textarea" ${i.type==="textarea"?"selected":""}>\u{1F4C4} Long Paragraph Text</option>
              <option value="number" ${i.type==="number"?"selected":""}>\u{1F522} Number</option>
              <option value="phone" ${i.type==="phone"?"selected":""}>\u{1F4F1} Phone Number</option>
              <option value="email" ${i.type==="email"?"selected":""}>\u{1F4E7} Email Address</option>
              <option value="select" ${i.type==="select"?"selected":""}>\u{1F4CB} Dropdown Select</option>
              <option value="radio" ${i.type==="radio"?"selected":""}>\u{1F518} Multiple Choice Radio</option>
              <option value="checkbox" ${i.type==="checkbox"?"selected":""}>\u2705 Single Checkbox (Yes/No)</option>
              <option value="multiselect" ${i.type==="multiselect"?"selected":""}>\u2611\uFE0F Multi-Select Checkboxes</option>
              <option value="date" ${i.type==="date"?"selected":""}>\u{1F4C5} Date Picker</option>
              <option value="time" ${i.type==="time"?"selected":""}>\u23F0 Time Picker</option>
              <option value="file" ${i.type==="file"?"selected":""}>\u{1F4CE} File / Document Upload</option>
              <option value="photo_upload" ${i.type==="photo_upload"?"selected":""}>\u{1F4F8} Passport Photo / Selfie</option>
              <option value="signature_pad" ${i.type==="signature_pad"?"selected":""}>\u270D\uFE0F Digital Signature Canvas</option>
              <option value="exam_badge" ${i.type==="exam_badge"?"selected":""}>\u{1F3AF} Target Competitive Exam</option>
              <option value="blood_group" ${i.type==="blood_group"?"selected":""}>\u{1FA78} Blood Group Selector</option>
              <option value="url" ${i.type==="url"?"selected":""}>\u{1F517} Website / Portfolio Link</option>
              <option value="address_autocomplete" ${i.type==="address_autocomplete"?"selected":""}>\u{1F4CD} Address & Pincode Auto-Fill</option>
              <option value="aadhaar_pan" ${i.type==="aadhaar_pan"?"selected":""}>\u{1FAAA} Aadhaar / PAN Proof Number</option>
              <option value="terms_checkbox" ${i.type==="terms_checkbox"?"selected":""}>\u{1F4DC} Quiet Study Code Consent</option>
              <option value="star_rating" ${i.type==="star_rating"?"selected":""}>\u2B50 Star Rating</option>
              <optgroup label="\u2500\u2500 Logic \u2500\u2500">
              <option value="conditional" ${i.type==="conditional"?"selected":""}>\u{1F500} Conditional (Show If...)</option>
              </optgroup>
            </select>
          </div>

          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Assigned Step / Section *</label>
            <select id="fe-section" class="form-select">${o}</select>
          </div>
        </div>

        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Placeholder Text</label>
            <input type="text" id="fe-placeholder" class="form-control" value="${d(i.placeholder||"")}" placeholder="e.g. Enter your exam name">
          </div>
          <div class="form-group">
            <label class="form-label text-xs" style="font-weight:700;">Help Tooltip Text</label>
            <input type="text" id="fe-help" class="form-control" value="${d(i.helpText||"")}" placeholder="e.g. Used for seat recommendations">
          </div>
        </div>

        <div style="display: flex; gap: 20px; align-items: center; background: var(--color-bg-secondary); padding: 10px 14px; border-radius: 8px; flex-wrap: wrap;">
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="fe-required" ${i.required?"checked":""}>
            <span class="switch-slider"></span>
            <span>\u{1F534} Mandatory / Required Field</span>
          </label>
          <label class="switch-label" style="font-weight: 600; font-size: 0.85rem; margin: 0;">
            <input type="checkbox" id="fe-halfwidth" ${i.colSpan===6?"checked":""}>
            <span class="switch-slider"></span>
            <span>\u{1F4D0} 50% Half Width Row</span>
          </label>
        </div>

        <div id="fe-options-wrap" style="display: ${["select","radio","multiselect"].includes(i.type)?"block":"none"};">
          <label class="form-label text-xs" style="font-weight:700;">Options List (Comma-separated)</label>
          <input type="text" id="fe-options" class="form-control" value="${d((i.options||[]).join(", "))}" placeholder="Option 1, Option 2, Option 3">
        </div>

        <!-- \u2500\u2500 Conditional Show-If Panel \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500 -->
        <div id="fe-conditional-wrap" style="display: ${i.type==="conditional"?"block":"none"}; background: rgba(99,102,241,0.07); border: 1px solid rgba(99,102,241,0.25); border-radius: 10px; padding: 14px; margin-top: 4px;">
          <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-primary); margin-bottom: 10px;">\u{1F500} Conditional Logic \u2014 Show this field only when:</div>
          <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px; margin-bottom: 10px;">
            <div class="form-group" style="margin:0;">
              <label class="form-label text-xs" style="font-weight:700;">Trigger Field</label>
              <select id="fe-show-if-field" class="form-select" style="font-size:0.85rem;">
                <option value="">\u2014 Pick a field \u2014</option>
                ${(m.allFields||[]).filter(s=>s.fieldName!==i.fieldName).map(s=>`<option value="${d(s.fieldName)}" ${i.showIf?.field===s.fieldName?"selected":""}>${d(s.label)} (${d(s.fieldName)})</option>`).join("")}
              </select>
            </div>
            <div class="form-group" style="margin:0;">
              <label class="form-label text-xs" style="font-weight:700;">Condition</label>
              <select id="fe-show-if-op" class="form-select" style="font-size:0.85rem;">
                <option value="equals" ${i.showIf?.operator==="equals"?"selected":""}>= Equals</option>
                <option value="not_equals" ${i.showIf?.operator==="not_equals"?"selected":""}>\u2260 Not Equals</option>
                <option value="contains" ${i.showIf?.operator==="contains"?"selected":""}>Contains</option>
                <option value="is_checked" ${i.showIf?.operator==="is_checked"?"selected":""}>\u2705 Is Checked</option>
                <option value="is_not_checked" ${i.showIf?.operator==="is_not_checked"?"selected":""}>\u2610 Is Unchecked</option>
                <option value="is_not_empty" ${i.showIf?.operator==="is_not_empty"?"selected":""}>Is Filled</option>
                <option value="is_empty" ${i.showIf?.operator==="is_empty"?"selected":""}>Is Empty</option>
              </select>
            </div>
            <div class="form-group" style="margin:0;">
              <label class="form-label text-xs" style="font-weight:700;">Trigger Value</label>
              <input type="text" id="fe-show-if-val" class="form-control" style="font-size:0.85rem;" value="${d(i.showIf?.value||"")}" placeholder="e.g. Yes, Option A">
            </div>
          </div>
          <div class="form-group" style="margin:0;">
            <label class="form-label text-xs" style="font-weight:700;">This field's own type (what it collects when shown)</label>
            <select id="fe-conditional-subtype" class="form-select" style="font-size:0.85rem;">
              <option value="text" ${(i.conditionalSubType||"text")==="text"?"selected":""}>\u{1F4DD} Short Text</option>
              <option value="textarea" ${i.conditionalSubType==="textarea"?"selected":""}>\u{1F4C4} Long Paragraph</option>
              <option value="number" ${i.conditionalSubType==="number"?"selected":""}>\u{1F522} Number</option>
              <option value="select" ${i.conditionalSubType==="select"?"selected":""}>\u{1F4CB} Dropdown</option>
              <option value="date" ${i.conditionalSubType==="date"?"selected":""}>\u{1F4C5} Date</option>
              <option value="checkbox" ${i.conditionalSubType==="checkbox"?"selected":""}>\u2705 Checkbox</option>
              <option value="file" ${i.conditionalSubType==="file"?"selected":""}>\u{1F4CE} File Upload</option>
            </select>
          </div>
          <div style="font-size:0.78rem; color: var(--color-text-muted); margin-top: 8px;">
            \u{1F4A1} Example: "If <strong>has_laptop</strong> <em>is_checked</em> \u2192 show this field"
          </div>
        </div>

        <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
          <button type="button" class="btn btn-secondary btn-sm fb-cancel-modal-btn" data-modal-close="true">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">\u{1F4BE} Save Question Field</button>
        </div>
      </form>
    `;const l=new k({title:a?`\u270F\uFE0F Edit Question: ${i.label}`:"\u2728 Create New Question Field",content:r,size:"md"});l.show(),r.querySelector(".fb-cancel-modal-btn")?.addEventListener("click",()=>{l.close(),k.closeAll()}),a||r.querySelector("#fe-label")?.addEventListener("input",s=>{const n=s.target.value.toLowerCase().replace(/[^a-z0-9_]/g,"_");r.querySelector("#fe-key").value=n}),r.querySelector("#fe-type")?.addEventListener("change",s=>{const n=s.target.value,c=["select","radio","multiselect"].includes(n),p=n==="conditional";r.querySelector("#fe-options-wrap").style.display=c?"block":"none",r.querySelector("#fe-conditional-wrap").style.display=p?"block":"none"}),r.querySelector("#fb-field-edit-form")?.addEventListener("submit",async s=>{s.preventDefault();const n=r.querySelector("#fe-label").value.trim(),c=r.querySelector("#fe-key").value.trim().toLowerCase().replace(/[^a-z0-9_]/g,"_"),p=r.querySelector("#fe-type").value,y=r.querySelector("#fe-section").value,v=r.querySelector("#fe-placeholder").value.trim(),g=r.querySelector("#fe-help").value.trim(),x=r.querySelector("#fe-required").checked,h=r.querySelector("#fe-halfwidth").checked?6:12,f=r.querySelector("#fe-options").value,w=f?f.split(",").map($=>$.trim()).filter(Boolean):[];let S=null,C=null;if(p==="conditional"){const $=r.querySelector("#fe-show-if-field")?.value,L=r.querySelector("#fe-show-if-op")?.value||"equals",T=r.querySelector("#fe-show-if-val")?.value.trim()||"";if(C=r.querySelector("#fe-conditional-subtype")?.value||"text",!$){u.error("Please pick a trigger field for the conditional logic.");return}S={field:$,operator:L,value:T}}const E={fieldName:c,label:n,type:p,section:y,placeholder:v,helpText:g,required:x,colSpan:h,options:w,isActive:!0,...S&&{showIf:S},...C&&{conditionalSubType:C}};try{a?(await b.put(`/api/custom-fields/${t}`,E),u.success("Question field updated successfully!")):(await b.post("/api/custom-fields",E),u.success("New question field added successfully!")),l.close(),await m.loadData()}catch($){u.error($.message||"Failed to save question field")}})}};z(q,"currentPreviewStep",0),z(q,"previewDeviceMode","desktop"),z(q,"undoStack",[]);let R=q;export{R as FormBuilder};
