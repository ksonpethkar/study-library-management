import{AudioFeedback as M}from"./utils/audioFeedback.js";import{triggerHaptic as P}from"./utils/mobileGestures.js";function h(t){return t==null?"":String(t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;").replace(/'/g,"&#039;")}typeof window<"u"&&(window.escapeHTML=h);const x={show(t,e="info",o=4e3){let n=document.getElementById("toast-container");n||(n=document.createElement("div"),n.id="toast-container",n.className="toast-container",document.body.appendChild(n)),e==="success"?(M.play("success"),P("success")):e==="warning"||e==="error"?(M.play("warning"),P("warning")):P("light");const i=document.createElement("div");i.className=`toast toast-${e}`;let a="";e==="success"?a='<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>':e==="error"?a='<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>':e==="warning"?a='<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>':a='<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>',i.innerHTML=`
      <div class="toast-content" style="display: flex; align-items: center; gap: 10px;">
        <span class="toast-icon">${a}</span>
        <span class="toast-msg">${h(t)}</span>
      </div>
      <button class="toast-close" style="background:none; border:none; color:inherit; cursor:pointer; font-size:16px; margin-left:12px;">&times;</button>
    `,n.appendChild(i);const r=i.querySelector(".toast-close"),p=()=>{i.style.opacity="0",i.style.transform="translateX(20px)",setTimeout(()=>i.remove(),250)};r.onclick=p,o>0&&setTimeout(p,o)},success(t){this.show(t,"success")},error(t){this.show(t,"error")},warning(t){this.show(t,"warning")},info(t){this.show(t,"info")},undo(t,e){let o=document.getElementById("toast-container");o||(o=document.createElement("div"),o.id="toast-container",o.className="toast-container",document.body.appendChild(o)),M.play("info");const n=document.createElement("div");n.className="toast toast-info toast-undo";const i='<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>';n.innerHTML=`
      <div class="toast-content" style="display: flex; align-items: center; gap: 10px; flex: 1;">
        <span class="toast-icon">${i}</span>
        <span class="toast-msg">${h(t)}</span>
      </div>
      <button class="toast-undo-btn" style="background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); color: inherit; cursor: pointer; font-weight: 700; font-size: 0.85rem; padding: 4px 10px; border-radius: 6px; margin-left: 10px; display: inline-flex; align-items: center; gap: 4px;">\u21A9\uFE0F Undo</button>
      <button class="toast-close" style="background:none; border:none; color:inherit; cursor:pointer; font-size:16px; margin-left:8px;">&times;</button>
    `,o.appendChild(n);let a=!1,r=null;const p=()=>{a||(a=!0,r&&clearTimeout(r),n.style.opacity="0",n.style.transform="translateX(20px)",setTimeout(()=>n.remove(),250))},u=n.querySelector(".toast-undo-btn");u&&(u.onclick=()=>{a||(p(),typeof e=="function"&&e())});const s=n.querySelector(".toast-close");s&&(s.onclick=p),r=setTimeout(p,5e3)}};class H{constructor(e,o,n="md"){typeof e=="object"&&e!==null?this.options=e:this.options={title:e,content:o,size:n},this.element=null}show(){return this.element=d.show(this.options),this.element}open(){return this.show()}hide(){d.close(this.element)}close(){d.close(this.element)}}const d=function(t,e,o){return new.target||this instanceof d?(typeof t=="object"&&t!==null?this.options=t:this.options={title:t,content:e,size:o},this.element=null,this):new H(t,e,o)};d._stack=[],d.show=function(t){let e="",o="",n="md",i="",a=null,r=null;typeof t=="string"?e=t:typeof t=="object"&&t!==null&&(e=t.title||"",o=t.content||"",n=t.size||"md",i=t.actions||"",a=t.buttons||null,r=t.onClose||null);const p=d._stack.length,u=1e3+p*10;if(p>0){const y=d._stack[p-1];y&&y.element&&(y.element.setAttribute("aria-hidden","true"),y.element.style.pointerEvents="none")}const s=document.createElement("dialog");s.className="modal-container-dialog app-modal modal",s.id=p===0?"modal-container":`modal-container-${Date.now()}-${p}`,s.setAttribute("data-stack-level",String(p));const l={sm:"420px",md:"640px",lg:"850px",xl:"1050px"},c=l[n]||l.md;s.style.cssText=`
    padding: 0;
    border: 1px solid var(--color-border, rgba(255,255,255,0.12));
    border-radius: var(--radius-lg, 14px);
    background: var(--color-surface, #1e2230);
    color: var(--color-text-primary, #fff);
    box-shadow: var(--shadow-xl, 0 16px 48px rgba(0,0,0,0.5));
    width: min(${c}, 95vw);
    max-width: 95vw;
    height: fit-content !important;
    min-height: 0 !important;
    max-height: 85vh;
    margin: auto;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
    z-index: ${u};
  `,s.innerHTML=`
    <div class="modal-header" style="padding: 14px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center; flex-shrink: 0;">
      <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary, #fff);">${h(e)}</h3>
      <button class="modal-close modal-close-btn" style="background: none; border: none; font-size: 1.4rem; color: var(--color-text-muted, #aaa); cursor: pointer; line-height: 1; padding: 4px;">&times;</button>
    </div>
    <div class="modal-body-container" style="padding: 18px 20px; max-height: calc(85vh - 120px); overflow-y: auto; flex: 1 1 auto;">
    </div>
    <div class="modal-footer-container" style="padding: 12px 20px; border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: none; justify-content: flex-end; gap: 10px; flex-shrink: 0; background: var(--color-bg-secondary, rgba(255,255,255,0.02));"></div>
  `;const m=s.querySelector(".modal-body-container");o instanceof HTMLElement?m.appendChild(o):typeof o=="string"&&(m.innerHTML=o);const g=s.querySelector(".modal-footer-container"),v={element:s,close:()=>{d.close(s)},hide:()=>{d.close(s)}};if(a&&Array.isArray(a)&&a.length>0)g.style.display="flex",a.forEach(y=>{const b=document.createElement("button");b.type="button",b.className=`btn ${y.className||"btn-secondary"}`,b.textContent=y.text||"Button",b.onclick=L=>{L.preventDefault(),L.stopPropagation(),typeof y.onClick=="function"?y.onClick(v):d.close(s)},g.appendChild(b)});else if(t&&(t.onConfirm||t.confirmText)){g.style.display="flex";const y=document.createElement("button");y.type="button",y.className="btn btn-secondary modal-cancel-btn",y.textContent=t.cancelText||"Cancel",y.onclick=L=>{L.preventDefault(),L.stopPropagation(),d.close(s)};const b=document.createElement("button");b.type="button",b.className=`btn ${t.confirmClass||"btn-primary"} modal-confirm-btn`,b.textContent=t.confirmText||"Save & Confirm",b.onclick=async L=>{if(L.preventDefault(),L.stopPropagation(),typeof t.onConfirm=="function"){b.disabled=!0,b.textContent="Processing...";try{await t.onConfirm(v)!==!1?d.close(s):(b.disabled=!1,b.textContent=t.confirmText||"Save & Confirm")}catch(G){console.error(G),d.close(s)}}else d.close(s)},g.appendChild(y),g.appendChild(b)}else i&&(g.style.display="flex",g.innerHTML=i);const f=s.querySelector(".modal-close"),_=y=>{y&&(y.preventDefault(),y.stopPropagation()),d.close(s)};if(f&&(f.onclick=_),s.oncancel=y=>{y.preventDefault(),y.stopPropagation()},s.addEventListener("cancel",y=>{y.preventDefault(),y.stopPropagation()}),t&&t.backdropClose===!0){let y=!1;s.addEventListener("mousedown",b=>{y=b.target===s}),s.addEventListener("mouseup",b=>{y&&b.target===s&&d.close(s),y=!1})}if(d._stack.push({element:s,onClose:r,options:t,wrapper:v}),document.body.appendChild(s),typeof document<"u"&&document.body&&(document.body.classList.add("modal-open"),document.body.style.overflow="hidden"),typeof s.showModal=="function"){if(!s.open)try{s.showModal()}catch{s.setAttribute("open",""),s.style.display="flex"}}else s.setAttribute("open",""),s.style.display="flex";return s},d.close=function(t){if(!d._stack||d._stack.length===0){document.querySelectorAll("dialog, #modal-container, .modal-container, .modal, .modal-backdrop").forEach(o=>{try{typeof o.close=="function"&&o.open&&o.close(),o.removeAttribute("open"),o.style.display="none",o.remove()}catch{}}),typeof document<"u"&&document.body&&(document.body.classList.remove("modal-open"),document.body.style.overflow="");return}let e=null;if(t){const o=t instanceof HTMLElement?t:t&&t.element?t.element:null,n=d._stack.findIndex(i=>i.element===o||o&&i.element&&i.element.contains(o));n!==-1&&(e=d._stack.splice(n,1)[0])}if(e||(e=d._stack.pop()),e&&e.element){try{typeof e.element.close=="function"&&e.element.open&&e.element.close()}catch{}try{e.element.removeAttribute("open"),e.element.style.display="none",e.element.remove()}catch{}if(typeof e.onClose=="function")try{e.onClose()}catch(o){console.error("Error in Modal onClose handler:",o)}}if(d._stack.length>0){const o=d._stack[d._stack.length-1];if(o&&o.element){o.element.removeAttribute("aria-hidden"),o.element.style.pointerEvents="";try{const n=o.element.querySelector('input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [tabindex]:not([tabindex="-1"])');n?n.focus():o.element.focus()}catch{}}}else typeof document<"u"&&document.body&&(document.body.classList.remove("modal-open"),document.body.style.overflow=""),document.querySelectorAll(".modal-backdrop").forEach(o=>{try{o.remove()}catch{}})},d.closeAll=function(){if(d._stack&&d._stack.length>0)for(;d._stack.length>0;)d.close();document.querySelectorAll("dialog, #modal-container, .modal-container, .modal, .modal-backdrop").forEach(t=>{try{typeof t.close=="function"&&t.open&&t.close(),t.removeAttribute("open"),t.style.display="none",t.remove()}catch{}}),typeof document<"u"&&document.body&&(document.body.classList.remove("modal-open"),document.body.style.overflow="")},d.hide=function(t){d.close(t)},typeof document<"u"&&document.addEventListener("click",t=>{const e=t.target.closest("[data-modal-close], [data-close-modal], .modal-close, .modal-close-btn, .modal-cancel, .btn-modal-close, .fb-cancel-modal-btn");if(e){t.preventDefault(),t.stopPropagation();const n=e.closest("dialog, .modal-container, .modal");if(n){d.close(n);return}d.close();return}const o=t.target.closest(".modal-cancel-btn");if(o){t.preventDefault(),t.stopPropagation();const n=o.closest("dialog, .modal-container, .modal");if(n){d.close(n);return}d.close()}},!0);const q={printElement(t,e="Document"){const o=document.getElementById(t);if(!o){x.error("Element not found for export");return}const n=window.open("","_blank","width=800,height=900");if(!n){window.print();return}n.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>${h(e)}</title>
        <link rel="stylesheet" href="/css/variables.css">
        <link rel="stylesheet" href="/css/base.css">
        <link rel="stylesheet" href="/css/components.css">
        <link rel="stylesheet" href="/css/print.css">
        <style>
          body { background: #fff !important; color: #000 !important; padding: 20px; font-family: 'Outfit', sans-serif; }
          .no-print, button, .modal-close { display: none !important; }
        </style>
      </head>
      <body>
        ${o.outerHTML}
        <script>
          setTimeout(() => {
            window.print();
            window.close();
          }, 300);
        <\/script>
      </body>
      </html>
    `),n.document.close()}};d.prototype.show=function(){return this.element=d.show(this.options),this.element},d.prototype.open=function(){return this.show()},d.prototype.hide=function(){d.close(this.element)},d.prototype.close=function(){d.close(this.element)},d.confirm=async function(t,e,o){return typeof t=="string"&&typeof e=="string"?await E.show({title:t,message:e,confirmText:o?.confirmLabel||o?.confirmText||"Confirm",danger:o?.confirmClass?.includes("danger")||o?.danger||!1}):typeof t=="string"?await E.show({message:t,confirmText:e?.confirmLabel||e?.confirmText||"Confirm",danger:e?.confirmClass?.includes("danger")||e?.danger||!1}):await E.show(t)};const E=function(t,e){return typeof t=="string"?E.show({title:"Confirmation",message:t,onConfirm:e}):E.show(t)};E.show=async function(t){let e="Confirm Action",o="Are you sure?",n="Confirm",i="Cancel",a=!1,r=null;typeof t=="string"?o=t:typeof t=="object"&&t!==null&&(e=t.title||e,o=t.message||o,n=t.confirmText||n,i=t.cancelText||i,a=t.danger||!1,r=t.onConfirm||null);const p=a?"\u26A0\uFE0F":"\u2753";return new Promise(u=>{let s=!1;const l=g=>{s||(s=!0,d.close(),u(g))},c=a?"btn-danger":"btn-primary",m=`
      <div style="display: flex; gap: 14px; align-items: flex-start; padding: 4px 0;">
        <div style="font-size: 1.6rem; line-height: 1; flex-shrink: 0; padding-top: 2px;">${p}</div>
        <div style="flex: 1; color: var(--color-text-secondary, rgba(255,255,255,0.75)); font-size: 0.95rem; line-height: 1.55; font-weight: 500;">
          ${h(o)}
        </div>
      </div>
    `;d.show({title:e,content:m,size:"sm",buttons:[{text:i,className:"btn-secondary modal-cancel-btn",onClick:()=>{l(!1)}},{text:n,className:`${c} modal-confirm-btn`,onClick:async()=>{if(l(!0),typeof r=="function")try{await r()}catch(g){console.error("onConfirm error:",g)}}}],onClose:()=>l(!1)})})};const B={_progressInterval:null,_progressValue:0,startProgress(){let t=document.getElementById("global-top-progress");t||(t=document.createElement("div"),t.id="global-top-progress",t.className="global-top-progress-bar",document.body.appendChild(t)),clearInterval(this._progressInterval),this._progressValue=15,t.style.width="15%",t.style.opacity="1",t.style.display="block",this._progressInterval=setInterval(()=>{this._progressValue<85&&(this._progressValue+=Math.random()*12,this._progressValue>85&&(this._progressValue=85),t.style.width=`${this._progressValue}%`)},100)},doneProgress(){clearInterval(this._progressInterval);const t=document.getElementById("global-top-progress");t&&(t.style.width="100%",setTimeout(()=>{t.style.opacity="0",setTimeout(()=>{t.style.display="none",t.style.width="0%"},250)},150))},showPage(t="Loading...",e="Preparing your workspace...",o="\u26A1"){this.startProgress();const n=document.getElementById("system-preloader");if(n&&n.style.display!=="none"){const a=document.getElementById("sys-preloader-icon"),r=document.getElementById("sys-preloader-name"),p=document.getElementById("sys-preloader-sub");a&&(a.textContent=o),r&&(r.textContent=t),p&&(p.textContent=e);return}let i=document.getElementById("global-page-loader");i||(i=document.createElement("div"),i.id="global-page-loader",i.className="global-page-loader-overlay",document.body.appendChild(i)),i.innerHTML=`
      <div class="page-loader-card">
        <div class="page-loader-ring">
          <span class="page-loader-icon">${o}</span>
        </div>
        <h3 class="page-loader-title">${h(t)}</h3>
        <p class="page-loader-subtitle">${h(e)}</p>
        <div class="page-loader-bar">
          <div class="page-loader-progress"></div>
        </div>
      </div>
    `,i.style.opacity="1",i.style.visibility="visible",i.style.display="flex"},hidePage(){this.doneProgress();const t=document.getElementById("system-preloader");t&&(t.style.opacity="0",t.style.pointerEvents="none",setTimeout(()=>{t.style.display="none";try{t.remove()}catch{}},250));const e=document.getElementById("global-page-loader");e&&(e.style.opacity="0",e.style.pointerEvents="none",setTimeout(()=>{e.style.display="none";try{e.remove()}catch{}},250))},renderSkeleton(t,e="table"){t&&(typeof t=="string"&&(t=document.querySelector(t)),t&&(e==="dashboard"?t.innerHTML=`
        <div class="skeleton-shimmer-container">
          <div class="skeleton-stats-grid">
            <div class="skeleton-card skeleton-stat-box"></div>
            <div class="skeleton-card skeleton-stat-box"></div>
            <div class="skeleton-card skeleton-stat-box"></div>
            <div class="skeleton-card skeleton-stat-box"></div>
          </div>
          <div class="skeleton-main-grid">
            <div class="skeleton-card skeleton-chart-box"></div>
            <div class="skeleton-card skeleton-side-box"></div>
          </div>
        </div>
      `:e==="seats"?t.innerHTML=`
        <div class="skeleton-shimmer-container">
          <div class="skeleton-card skeleton-toolbar"></div>
          <div class="skeleton-seat-grid">
            ${Array.from({length:48}).map(()=>'<div class="skeleton-seat-circle"></div>').join("")}
          </div>
        </div>
      `:t.innerHTML=`
        <div class="skeleton-shimmer-container">
          <div class="skeleton-card skeleton-toolbar"></div>
          <div class="skeleton-card skeleton-table-box">
            <div class="skeleton-row skeleton-header-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
          </div>
        </div>
      `))},show(t){if(!t){this.showPage("Processing Request...","Please wait a moment...","\u26A1");return}if(t instanceof HTMLElement){if(t.tagName==="BUTTON"||t.classList.contains("btn")){t.classList.add("btn-loading"),t.disabled=!0;return}t.classList.add("loading-skeleton"),t.setAttribute("aria-busy","true");return}typeof t=="string"&&this.showPage("Processing...",t,"\u26A1")},hide(t){if(this.hidePage(),t instanceof HTMLElement){if(t.tagName==="BUTTON"||t.classList.contains("btn")){t.classList.remove("btn-loading"),t.disabled=!1;return}t.classList.remove("loading-skeleton"),t.removeAttribute("aria-busy")}if(typeof t=="string")try{const o=document.querySelector(t);o&&(o.classList.remove("loading-skeleton"),o.removeAttribute("aria-busy"))}catch{}const e=document.getElementById("global-loading-overlay");e&&e.remove()},button(t,e){typeof t=="string"&&(t=document.querySelector(t)),t&&(e?(t.dataset.originalText=t.innerHTML,t.classList.add("btn-loading"),t.disabled=!0):(t.classList.remove("btn-loading"),t.dataset.originalText&&(t.innerHTML=t.dataset.originalText),t.disabled=!1))},skeleton(t,e="table"){let o=t;if(typeof t=="string"&&(o=document.querySelector(t)),!o)return;let n="";e==="table"?n=`
        <div class="skeleton-table p-3">
          ${Array(5).fill(0).map(()=>`
            <div class="skeleton-row">
              <div class="skeleton skeleton-avatar" style="width: 28px; height: 28px;"></div>
              <div class="skeleton skeleton-text" style="flex: 1; margin-bottom: 0;"></div>
              <div class="skeleton skeleton-text" style="flex: 2; margin-bottom: 0;"></div>
              <div class="skeleton skeleton-text" style="flex: 1; margin-bottom: 0;"></div>
              <div class="skeleton skeleton-button" style="width: 60px; height: 28px;"></div>
            </div>
          `).join("")}
        </div>
      `:e==="cards"?n=`
        <div class="grid-auto-fit gap-3 p-3">
          ${Array(4).fill(0).map(()=>`
            <div class="skeleton-card">
              <div class="d-flex align-items-center gap-3">
                <div class="skeleton skeleton-avatar"></div>
                <div style="flex: 1;">
                  <div class="skeleton skeleton-title" style="width: 60%; margin-bottom: 4px;"></div>
                  <div class="skeleton skeleton-text short" style="margin-bottom: 0;"></div>
                </div>
              </div>
              <div class="skeleton skeleton-text" style="margin-top: 8px;"></div>
              <div class="skeleton skeleton-text short"></div>
            </div>
          `).join("")}
        </div>
      `:e==="kpi"?n=`
        <div class="kpi-grid">
          ${Array(4).fill(0).map(()=>`
            <div class="kpi-card skeleton-card" style="min-height: 96px; justify-content: center;">
              <div class="skeleton skeleton-text short" style="width: 50%; margin-bottom: 8px;"></div>
              <div class="skeleton skeleton-title" style="width: 40%; height: 1.8rem; margin-bottom: 4px;"></div>
              <div class="skeleton skeleton-text short" style="width: 70%; margin-bottom: 0;"></div>
            </div>
          `).join("")}
        </div>
      `:e==="profile"?n=`
        <div class="skeleton-card p-4">
          <div class="d-flex align-items-center gap-4 mb-4">
            <div class="skeleton skeleton-avatar" style="width: 72px; height: 72px;"></div>
            <div style="flex: 1;">
              <div class="skeleton skeleton-title" style="width: 40%;"></div>
              <div class="skeleton skeleton-text short mb-2"></div>
              <div class="skeleton skeleton-text" style="width: 60%;"></div>
            </div>
          </div>
          <div class="skeleton skeleton-text mb-3"></div>
          <div class="skeleton skeleton-text mb-3"></div>
          <div class="skeleton skeleton-text short"></div>
        </div>
      `:n=`
        <div class="p-3">
          <div class="skeleton skeleton-title"></div>
          <div class="skeleton skeleton-text"></div>
          <div class="skeleton skeleton-text short"></div>
        </div>
      `,o.innerHTML=n}};function N(t,e={}){let o=typeof t=="string"?document.querySelector(t):t;if(!o)return null;const{icon:n='<svg viewBox="0 0 24 24" width="40" height="40" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="color: var(--color-text-muted, #888);"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>',title:i="No Data Available",description:a="There are no items to display at this time.",actionText:r=null,onAction:p=null}=e,u=document.createElement("div");u.className="empty-state-card",u.style.cssText=`
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 24px;
    text-align: center;
    background: var(--color-surface, #1e2230);
    border: 1px dashed var(--color-border, rgba(255,255,255,0.12));
    border-radius: var(--radius-lg, 12px);
    margin: 16px 0;
    width: 100%;
    box-sizing: border-box;
  `;let s="";typeof n=="string"&&!n.includes("<")?s=`<div style="font-size: 2.8rem; margin-bottom: 12px; line-height: 1;">${n}</div>`:typeof n=="string"&&(s=`<div style="margin-bottom: 14px; opacity: 0.85; display: inline-flex; align-items: center; justify-content: center;">${n}</div>`);let l="";if(r&&(l=`<button type="button" class="btn btn-primary empty-state-action-btn" style="margin-top: 16px; font-weight: 600;">${h(r)}</button>`),u.innerHTML=`
    ${s}
    <h4 style="margin: 0 0 8px 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary, #fff);">${h(i)}</h4>
    <p style="margin: 0; font-size: 0.875rem; color: var(--color-text-muted, #a0aec0); max-width: 420px; line-height: 1.5;">${h(a)}</p>
    ${l}
  `,r&&typeof p=="function"){const c=u.querySelector(".empty-state-action-btn");c&&(c.onclick=m=>p(m))}if(o.tagName==="TBODY"){o.innerHTML="";const c=document.createElement("tr"),m=document.createElement("td");return m.colSpan=100,m.style.padding="12px",m.appendChild(u),c.appendChild(m),o.appendChild(c),u}return o.innerHTML="",o.appendChild(u),u}function D(t,e,o){let n=typeof t=="string"?document.querySelector(t):t;if(n)if(e){if(n.dataset.isLoading==="true")return;n.dataset.isLoading="true",n.dataset.originalHtml=n.innerHTML,n.disabled=!0;const i='<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true" style="display: inline-block; width: 0.9em; height: 0.9em; border: 2px solid currentColor; border-right-color: transparent; border-radius: 50%; animation: spin 0.75s linear infinite; vertical-align: text-bottom;"></span>',a=o?`<span class="btn-loading-text" style="margin-left: 6px;">${h(o)}</span>`:n.innerText?`<span class="btn-loading-text" style="margin-left: 6px;">${h(n.innerText.trim())}</span>`:"";n.innerHTML=`${i}${a}`}else n.dataset.originalHtml!==void 0&&(n.innerHTML=n.dataset.originalHtml,delete n.dataset.originalHtml),n.dataset.isLoading="false",n.disabled=!1}const F={emptyState:N,buttonLoading:D};typeof window<"u"&&(window.UI=F);function j(t,e=250){let o=null;return function(...n){const i=this;o&&clearTimeout(o),o=setTimeout(()=>{t.apply(i,n)},e)}}typeof window<"u"&&(window.debounce=j);const V={async share(t={}){let e,o,n;typeof t=="string"?n=t:{title:e,text:o,url:n}=t||{};const i={};if(e&&(i.title=e),o&&(i.text=o),n&&(i.url=n),navigator.share)try{if(!(navigator.canShare&&!navigator.canShare(i)))return await navigator.share(i),!0}catch(r){if(r.name==="AbortError")return!1}const a=n||o||e||(typeof window<"u"?window.location.href:"");try{if(navigator.clipboard&&navigator.clipboard.writeText)await navigator.clipboard.writeText(a);else if(typeof document<"u"){const r=document.createElement("textarea");r.value=a,r.style.position="fixed",r.style.opacity="0",document.body.appendChild(r),r.select(),document.execCommand("copy"),r.remove()}return x.success("Link copied to clipboard!"),!0}catch{return x.error("Failed to copy link"),!1}}};typeof window<"u"&&(window.NativeShare=V);async function Y(t,e){if(!t)return!1;try{if(navigator.clipboard&&navigator.clipboard.writeText)await navigator.clipboard.writeText(t);else if(typeof document<"u"){const o=document.createElement("textarea");o.value=t,o.style.position="fixed",o.style.opacity="0",document.body.appendChild(o),o.select(),document.execCommand("copy"),o.remove()}if(e){const o=e.innerHTML,n=e.style.backgroundColor,i=e.style.color,a=e.style.borderColor;e.innerHTML="\u2713 Copied!",e.classList.add("badge","bg-success","text-white"),e.style.backgroundColor="var(--color-success, #2ed573)",e.style.color="#ffffff",e.style.borderColor="var(--color-success, #2ed573)",e._copyTimeout&&clearTimeout(e._copyTimeout),e._copyTimeout=setTimeout(()=>{e.innerHTML=o,e.classList.remove("badge","bg-success","text-white"),e.style.backgroundColor=n,e.style.color=i,e.style.borderColor=a,delete e._copyTimeout},2e3)}return x.success("Copied to clipboard!"),!0}catch(o){return console.error("Failed to copy to clipboard:",o),x.error("Failed to copy to clipboard"),!1}}typeof window<"u"&&(window.copyToClipboard=Y);class k{constructor(e={}){typeof e=="string"&&(e={title:e}),this.options=e,this.sheet=null,this.overlay=null,this.onClose=e.onClose||null}static show(e){return typeof window<"u"&&window.innerWidth<=768?new k(e).open():d.show(e)}static close(){if(typeof document>"u")return;const e=document.querySelectorAll(".bottom-sheet");e.forEach(n=>{n.classList.remove("open"),n.style.transform="translateY(100%)"});const o=document.querySelectorAll(".bottom-sheet-overlay");o.forEach(n=>{n.classList.remove("open"),n.style.opacity="0"}),setTimeout(()=>{e.forEach(n=>n.remove()),o.forEach(n=>n.remove())},300)}open(){if(!(typeof window<"u"&&window.innerWidth<=768))return d.show(this.options);const e=typeof this.options=="string"?{title:this.options}:this.options||{},o=e.title||"",n=e.content||"";let i=document.querySelector(".bottom-sheet-overlay");i||(i=document.createElement("div"),i.className="bottom-sheet-overlay",document.body.appendChild(i)),this.overlay=i;const a=document.createElement("div");a.className="bottom-sheet",this.sheet=a;let r="";o&&(r=`
        <div class="bottom-sheet-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08));">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">${h(o)}</h3>
          <button class="bottom-sheet-close" style="background: none; border: none; font-size: 1.4rem; color: var(--color-text-muted); cursor: pointer; padding: 4px; line-height: 1;">&times;</button>
        </div>
      `);let p="";e.buttons&&Array.isArray(e.buttons)&&e.buttons.length>0?p='<div class="bottom-sheet-footer" style="margin-top: 16px; display: flex; gap: 8px; justify-content: flex-end;"></div>':e.actions&&(p=`<div class="bottom-sheet-footer" style="margin-top: 16px; display: flex; gap: 8px; justify-content: flex-end;">${e.actions}</div>`),a.innerHTML=`
      <div class="bottom-sheet-handle"></div>
      ${r}
      <div class="bottom-sheet-body"></div>
      ${p}
    `;const u=a.querySelector(".bottom-sheet-body");if(n instanceof HTMLElement?u.appendChild(n):typeof n=="string"&&(u.innerHTML=n),e.buttons&&Array.isArray(e.buttons)&&e.buttons.length>0){const l=a.querySelector(".bottom-sheet-footer");e.buttons.forEach(c=>{const m=document.createElement("button");m.className=`btn ${c.className||"btn-secondary"}`,m.textContent=c.text||"Button",m.onclick=()=>{typeof c.onClick=="function"?c.onClick(this):this.close()},l.appendChild(m)})}document.body.appendChild(a);const s=a.querySelector(".bottom-sheet-close");return s&&(s.onclick=()=>this.close()),i.onclick=()=>this.close(),this._initSwipeGesture(),requestAnimationFrame(()=>{i.classList.add("open"),a.classList.add("open")}),a}close(){this.sheet&&(this.sheet.classList.remove("open"),this.sheet.style.transform="translateY(100%)"),this.overlay&&this.overlay.classList.remove("open"),setTimeout(()=>{this.sheet&&this.sheet.remove(),this.overlay&&this.overlay.remove(),typeof this.onClose=="function"&&this.onClose()},300)}_initSwipeGesture(){if(!this.sheet)return;const e=this.sheet.querySelector(".bottom-sheet-handle")||this.sheet;let o=0,n=0,i=!1;const a=u=>{this.sheet.scrollTop>0&&u.target!==e||(o=u.touches[0].clientY,i=!0,this.sheet.style.transition="none")},r=u=>{if(!i)return;n=u.touches[0].clientY;const s=n-o;s>0&&(this.sheet.style.transform=`translateY(${s}px)`)},p=()=>{i&&(i=!1,this.sheet.style.transition="transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)",n-o>80?this.close():(this.sheet.style.transform="",this.sheet.classList.add("open")))};e.addEventListener("touchstart",a,{passive:!0}),this.sheet.addEventListener("touchstart",a,{passive:!0}),window.addEventListener("touchmove",r,{passive:!0}),window.addEventListener("touchend",p,{passive:!0})}}function C(){if(typeof window>"u")return;let t=document.getElementById("pull-to-refresh-spinner");t||(t=document.createElement("div"),t.id="pull-to-refresh-spinner",t.className="pull-to-refresh-spinner",t.innerHTML=`
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color: var(--color-primary, #6366f1); animation: spin 0.8s linear infinite;">
        <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/>
      </svg>
    `,document.body.appendChild(t));let e=0,o=0,n=!1,i=!1;window.addEventListener("touchstart",a=>{window.scrollY===0&&a.touches&&a.touches.length===1&&(e=a.touches[0].clientY,n=!0,o=0)},{passive:!0}),window.addEventListener("touchmove",a=>{if(!n||i)return;if(window.scrollY>0){n=!1;return}if(!a.touches||a.touches.length===0)return;const r=a.touches[0].clientY-e;r>0&&window.scrollY===0&&(o=r,o>=70?t.classList.add("visible"):t.classList.remove("visible"))},{passive:!0}),window.addEventListener("touchend",()=>{n&&(n=!1,o>=70&&!i?(i=!0,t.classList.add("visible"),window.dispatchEvent(new HashChangeEvent("hashchange")),setTimeout(()=>{t.classList.remove("visible"),i=!1,o=0},600)):(t.classList.remove("visible"),o=0))},{passive:!0})}typeof window<"u"&&(window.BottomSheet=k,window.initPullToRefresh=C,document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>C()):C());function I(t="admin"){const e=document.getElementById("mobile-nav");if(!e)return;e.classList.contains("mobile-bottom-nav")||e.classList.add("mobile-bottom-nav");const o=document.getElementById("mobile-more-btn"),n=document.getElementById("mobile-more-overlay"),i=document.getElementById("mobile-more-sheet"),a=document.getElementById("mobile-logout-btn"),r=()=>{n&&(n.style.display="flex",requestAnimationFrame(()=>{n.classList.add("open"),i?.classList.add("open")}),document.body.style.overflow="hidden")},p=()=>{n&&(n.classList.remove("open"),i?.classList.remove("open"),document.body.style.overflow="",setTimeout(()=>{n.classList.contains("open")||(n.style.display="none")},300))};o?.addEventListener("click",c=>{if(c.preventDefault(),c.stopPropagation(),navigator.vibrate)try{navigator.vibrate(25)}catch{}n?.classList.contains("open")?p():r()}),n?.addEventListener("click",c=>{c.target===n&&p()}),document.addEventListener("keydown",c=>{c.key==="Escape"&&n?.classList.contains("open")&&p()}),n?.querySelectorAll(".mobile-more-item").forEach(c=>{c.addEventListener("click",m=>{if(navigator.vibrate)try{navigator.vibrate(25)}catch{}p()})}),a?.addEventListener("click",()=>{p(),document.getElementById("sidebar-logout-btn")?.click()||document.getElementById("logout-btn")?.click()});let u=0,s=0,l=!1;i?.addEventListener("touchstart",c=>{(c.target.closest(".mobile-more-handle, .mobile-more-title")||c.target===i)&&(u=c.touches[0].clientY,l=!0)},{passive:!0}),i?.addEventListener("touchmove",c=>{if(!l)return;s=c.touches[0].clientY;const m=s-u;m>0&&(i.style.transform=`translateY(${m}px)`)},{passive:!0}),i?.addEventListener("touchend",()=>{l&&(l=!1,s-u>80&&p(),i.style.transform="",u=0,s=0)},{passive:!0}),e.querySelectorAll(".mobile-nav-item:not(.mobile-nav-more-btn)").forEach(c=>{c.addEventListener("click",()=>{if(navigator.vibrate)try{navigator.vibrate(25)}catch{}})})}typeof window<"u"&&(window.renderMobileBottomNav=I);const z={recognition:null,isListening:!1,indicator:null,showIndicator(){if(this.hideIndicator(),!document.getElementById("voice-search-style")){const e=document.createElement("style");e.id="voice-search-style",e.textContent=`
        @keyframes voice-pulse-ring {
          0% { box-shadow: 0 0 0 0 rgba(108, 92, 231, 0.7); }
          70% { box-shadow: 0 0 0 16px rgba(108, 92, 231, 0); }
          100% { box-shadow: 0 0 0 0 rgba(108, 92, 231, 0); }
        }
        @keyframes voice-mic-bounce {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.25); }
        }
      `,document.head.appendChild(e)}this.indicator=document.createElement("div"),this.indicator.id="voice-search-indicator",this.indicator.style.cssText=`
      position: fixed;
      bottom: 36px;
      left: 50%;
      transform: translateX(-50%);
      background: linear-gradient(135deg, #6c5ce7, #a29bfe);
      color: #ffffff;
      padding: 12px 24px;
      border-radius: 50px;
      box-shadow: 0 8px 24px rgba(108, 92, 231, 0.4);
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 600;
      font-size: 0.95rem;
      font-family: 'Outfit', sans-serif;
      z-index: 999999;
      animation: voice-pulse-ring 1.5s infinite;
      cursor: pointer;
    `,this.indicator.innerHTML=`
      <span style="font-size: 1.3rem; display: inline-block; animation: voice-mic-bounce 1s infinite;">\u{1F399}\uFE0F</span>
      <span>Listening... Speak now</span>
      <button style="background: rgba(255,255,255,0.2); border: none; color: #fff; border-radius: 50%; width: 22px; height: 22px; font-size: 12px; cursor: pointer; display: flex; align-items: center; justify-content: justify; margin-left: 6px;" title="Cancel">&times;</button>
    `;const t=this.indicator.querySelector("button");t&&t.addEventListener("click",e=>{e.stopPropagation(),this.stop()}),document.body.appendChild(this.indicator)},hideIndicator(){this.indicator&&(this.indicator.remove(),this.indicator=null)},start(t,e){const o=window.SpeechRecognition||window.webkitSpeechRecognition;if(!o){x.error("Voice search is not supported in this browser."),e&&e("Speech recognition not supported");return}try{this.isListening&&this.recognition&&this.recognition.abort();const n=new o;this.recognition=n,n.continuous=!1,n.interimResults=!1,n.lang="en-US",n.onstart=()=>{this.isListening=!0,this.showIndicator()},n.onresult=i=>{if(this.isListening=!1,this.hideIndicator(),i.results&&i.results[0]&&i.results[0][0]){const a=i.results[0][0].transcript;t&&t(a)}},n.onerror=i=>{this.isListening=!1,this.hideIndicator(),console.error("Voice recognition error:",i.error),i.error!=="aborted"&&x.error(`Voice search error: ${i.error}`),e&&e(i.error)},n.onend=()=>{this.isListening=!1,this.hideIndicator()},n.start()}catch(n){this.isListening=!1,this.hideIndicator(),console.error("Failed to start voice search:",n),x.error("Failed to start voice search"),e&&e(n)}},stop(){if(this.recognition&&this.isListening){try{this.recognition.stop()}catch{}this.isListening=!1,this.hideIndicator()}}};typeof window<"u"&&(window.VoiceSearch=z);const O={_el:null,_scrollHandler:null,_outsideClickHandler:null,_lastScrollY:0,_isOpen:!1,mount(t={}){this.unmount();const{icon:e="+",label:o="Quick Actions",color:n="var(--color-primary, #6c5ce7)",actions:i=[]}=t,a=document.createElement("div");a.id="global-fab",a.className="fab-container",a.setAttribute("aria-label",o);const r=document.createElement("div");r.className="fab-speed-dial",r.setAttribute("aria-hidden","true"),i.forEach((s,l)=>{const c=document.createElement("button");c.className="fab-speed-item",c.type="button",c.setAttribute("aria-label",s.label||""),c.style.transitionDelay=`${l*45}ms`,c.innerHTML=`
        <span class="fab-speed-label">${h(s.label||"")}</span>
        <span class="fab-speed-icon">${s.icon||"\u26A1"}</span>
      `;const m=g=>{g&&(g.preventDefault(),g.stopPropagation()),this._closeSpeedDial(),typeof s.onClick=="function"&&setTimeout(()=>{try{s.onClick()}catch(v){console.error("Error executing FAB action:",v)}},50),typeof navigator<"u"&&navigator.vibrate&&navigator.vibrate(12)};c.addEventListener("click",m),r.appendChild(c)});const p=document.createElement("button");p.type="button",p.className="fab-main-btn",p.setAttribute("aria-expanded","false"),p.setAttribute("aria-label",o),p.style.background=n,p.innerHTML=`<span class="fab-main-icon">${e}</span>`,p.onclick=s=>{s.stopPropagation(),this._isOpen?this._closeSpeedDial():this._openSpeedDial(),typeof navigator<"u"&&navigator.vibrate&&navigator.vibrate(10)},a.appendChild(r),a.appendChild(p),document.body.appendChild(a),this._el=a,this._lastScrollY=window.scrollY;let u=!1;this._scrollHandler=()=>{u||(requestAnimationFrame(()=>{const s=window.scrollY,l=s-this._lastScrollY;l>60&&s>150?(a.classList.add("fab-hidden"),this._closeSpeedDial()):l<-20&&a.classList.remove("fab-hidden"),this._lastScrollY=s,u=!1}),u=!0)},window.addEventListener("scroll",this._scrollHandler,{passive:!0}),this._outsideClickHandler=s=>{this._isOpen&&this._el&&!this._el.contains(s.target)&&this._closeSpeedDial()},document.addEventListener("click",this._outsideClickHandler)},_openSpeedDial(){if(!this._el)return;this._isOpen=!0,this._el.classList.add("fab-open");const t=this._el.querySelector(".fab-main-btn");t&&t.setAttribute("aria-expanded","true");const e=this._el.querySelector(".fab-speed-dial");e&&e.removeAttribute("aria-hidden"),this._el.querySelectorAll(".fab-speed-item").forEach((o,n)=>{setTimeout(()=>o.classList.add("visible"),n*35)})},_closeSpeedDial(){if(!this._el)return;this._isOpen=!1,this._el.classList.remove("fab-open");const t=this._el.querySelector(".fab-main-btn");t&&t.setAttribute("aria-expanded","false");const e=this._el.querySelector(".fab-speed-dial");e&&e.setAttribute("aria-hidden","true"),this._el.querySelectorAll(".fab-speed-item").forEach(o=>o.classList.remove("visible"))},unmount(){this._el&&this._el.parentNode&&this._el.remove(),document.querySelectorAll("#global-fab, .fab-container, .speed-dial-fab").forEach(t=>t.remove()),this._el=null,this._isOpen=!1,this._scrollHandler&&(window.removeEventListener("scroll",this._scrollHandler),this._scrollHandler=null),this._outsideClickHandler&&(document.removeEventListener("click",this._outsideClickHandler),this._outsideClickHandler=null)},update(t){this.unmount(),this.mount(t)},hide(){this._el&&this._el.classList.add("fab-hidden")},show(){this._el&&this._el.classList.remove("fab-hidden")}},w={_activeFloatingMenu:null,_activeTrigger:null,closeAll(){this._activeFloatingMenu&&(this._activeFloatingMenu.remove(),this._activeFloatingMenu=null),this._activeTrigger=null,document.querySelectorAll(".dropdown.active, .dropdown.open, .dropdown-menu.show").forEach(t=>{t.classList.remove("active","open","show")})},renderHtml(t=[],e=""){const o=encodeURIComponent(JSON.stringify(t));return`
      <div class="dropdown action-menu-wrapper d-inline-block" data-entity-id="${h(e)}">
        <button type="button" class="btn-icon-action btn-action-menu-trigger dropdown-toggle" data-actions="${o}" data-entity-id="${h(e)}" aria-expanded="false" data-tooltip="More Actions" aria-label="More Actions" style="font-size: 1.15rem; font-weight: 800;">
          \u22EE
        </button>
        <ul class="dropdown-menu dropdown-menu-end shadow" style="display: none; min-width: 210px; font-size: 0.84rem; padding: 6px 0; border-radius: 8px; z-index: 1050; background: var(--color-surface); border: 1px solid var(--color-border);">
          ${t.map(n=>{if(n.divider)return'<li><hr class="dropdown-divider" style="margin: 4px 0; border-color: var(--color-border);"></li>';if(n.header)return`<li class="dropdown-header text-muted text-uppercase" style="font-size: 0.68rem; font-weight: 800; padding: 4px 14px; letter-spacing: 0.5px; color: var(--color-text-secondary);">${h(n.header)}</li>`;const i=n.icon||"\u26A1",a=n.label||"",r=n.action||n.id||"";return`
              <li>
                <a class="dropdown-item d-flex align-items-center gap-2 ${n.danger?"text-danger":""} action-menu-item" href="#" data-action="${h(r)}" data-id="${h(e)}" style="padding: 6px 14px; cursor: pointer; color: var(--color-text-primary);">
                  <span style="font-size: 1rem; width: 20px; text-align: center;">${i}</span>
                  <span style="flex-grow: 1; font-weight: ${n.bold?"700":"500"};">${h(a)}</span>
                  ${n.badge?`<span class="badge badge-sm" style="font-size: 0.65rem; background: rgba(108,92,231,0.15); color: var(--color-primary);">${h(n.badge)}</span>`:""}
                </a>
              </li>
            `}).join("")}
        </ul>
      </div>
    `},showFloatingMenu(t,e,o){if(this.closeAll(),!e||!e.length)return;const n=(s,l)=>{const c=[t.parentElement?.querySelector(`.action-menu-item[data-action="${s}"]`),t.closest(".dropdown, .action-menu-wrapper, tr, td")?.querySelector(`.action-menu-item[data-action="${s}"]`),document.querySelector(`.dropdown[data-entity-id="${l}"] .action-menu-item[data-action="${s}"]`),document.querySelector(`.action-menu-item[data-id="${l}"][data-action="${s}"]`)];for(const f of c)if(f)try{f.click();return}catch{}const m={action:s,id:l,entityId:l,trigger:t},g=new CustomEvent("action-menu-select",{bubbles:!0,cancelable:!0,detail:m});t.dispatchEvent(g),document.dispatchEvent(new CustomEvent("action-menu-select",{bubbles:!0,cancelable:!0,detail:m}));const v=t.closest("tr, .card, .portal-card, #page-content");if(v){const f=document.createElement("span");f.className="action-menu-item",f.dataset.action=s,f.dataset.id=l,f.style.display="none",v.appendChild(f);try{f.click()}finally{setTimeout(()=>f.remove(),100)}}};if(window.innerWidth<=768&&typeof k<"u"&&k.show){const s=`
        <div style="padding: 0.5rem 0;">
          <div style="font-weight: 800; font-size: 0.95rem; margin-bottom: 10px; padding: 0 16px; color: var(--color-primary); display: flex; align-items: center; justify-content: space-between;">
            <span>\u26A1 Quick Actions</span>
            ${o?`<span class="badge badge-secondary" style="font-size: 0.7rem; font-family: monospace;">${h(o.slice(-6))}</span>`:""}
          </div>
          <div style="display: flex; flex-direction: column;">
            ${e.map(m=>{if(m.divider)return'<hr style="margin: 4px 0; border-color: var(--color-border);">';if(m.header)return`<div style="font-size: 0.7rem; font-weight: 800; text-transform: uppercase; color: var(--color-text-muted); padding: 8px 16px 2px;">${h(m.header)}</div>`;const g=m.icon||"\u26A1",v=m.label||"",f=m.action||m.id||"",_=m.danger?"color: var(--color-danger, #ef4444);":"color: var(--color-text-primary);";return`
                <button type="button" class="btn-mobile-sheet-action action-menu-item" data-action="${h(f)}" data-id="${h(o)}" style="display: flex; align-items: center; gap: 12px; width: 100%; text-align: left; padding: 14px 18px; border: none; background: transparent; ${_} font-size: 0.96rem; font-weight: 600; cursor: pointer; touch-action: manipulation; -webkit-tap-highlight-color: transparent; border-bottom: 1px solid var(--color-divider, #f1f5f9);">
                  <span style="font-size: 1.25rem; width: 26px; text-align: center; flex-shrink: 0;">${g}</span>
                  <span style="flex-grow: 1; font-weight: ${m.bold?"700":"600"};">${h(v)}</span>
                  ${m.badge?`<span class="badge badge-sm" style="font-size: 0.7rem; background: rgba(108,92,231,0.15); color: var(--color-primary);">${h(m.badge)}</span>`:""}
                </button>
              `}).join("")}
          </div>
        </div>
      `,l=k.show({title:"Select Action",content:s,height:"auto"}),c=l instanceof HTMLElement?l:document.querySelector(".bottom-sheet");if(c){const m=g=>{const v=g.target.closest(".action-menu-item, .btn-mobile-sheet-action");if(!v)return;g.preventDefault(),g.stopPropagation();const f=v.dataset.action,_=v.dataset.id||o;k.close(),setTimeout(()=>n(f,_),80)};c.addEventListener("click",m),c.addEventListener("touchend",m,{passive:!1})}return}const i=document.createElement("div");i.id="floating-action-menu-portal",i.className="floating-action-menu-portal shadow-lg",i.style.cssText=`
      position: fixed;
      z-index: 999999;
      background: var(--color-surface, #ffffff);
      border: 1px solid var(--color-border, #e2e8f0);
      border-radius: 8px;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.35), 0 8px 10px -6px rgba(0, 0, 0, 0.2);
      min-width: 210px;
      max-width: 280px;
      padding: 6px 0;
      font-size: 0.84rem;
      user-select: none;
      animation: fadeIn 0.12s ease-out;
    `,i.innerHTML=`
      <ul style="list-style: none; margin: 0; padding: 0;">
        ${e.map(s=>{if(s.divider)return'<li style="margin: 4px 0; border-top: 1px solid var(--color-border, #e2e8f0);"></li>';if(s.header)return`<li style="font-size: 0.66rem; font-weight: 800; padding: 4px 14px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--color-text-secondary, #64748b);">${h(s.header)}</li>`;const l=s.icon||"\u26A1",c=s.label||"",m=s.action||s.id||"",g=s.danger?"color: var(--color-danger, #ef4444);":"color: var(--color-text-primary, #1e293b);";return`
            <li>
              <a href="#" class="floating-action-item action-menu-item" data-action="${h(m)}" data-id="${h(o)}" style="display: flex; align-items: center; gap: 8px; padding: 8px 14px; text-decoration: none; ${g} transition: background 0.12s; cursor: pointer;">
                <span style="font-size: 0.95rem; width: 18px; text-align: center;">${l}</span>
                <span style="flex-grow: 1; font-weight: ${s.bold?"700":"500"}; white-space: nowrap;">${h(c)}</span>
                ${s.badge?`<span class="badge badge-sm" style="font-size: 0.65rem; background: rgba(108,92,231,0.15); color: var(--color-primary);">${h(s.badge)}</span>`:""}
              </a>
            </li>
          `}).join("")}
      </ul>
    `,document.body.appendChild(i),this._activeFloatingMenu=i,this._activeTrigger=t,i.querySelectorAll(".floating-action-item").forEach(s=>{s.addEventListener("mouseenter",()=>{s.style.backgroundColor="var(--color-bg-secondary, rgba(108,92,231,0.08))"}),s.addEventListener("mouseleave",()=>{s.style.backgroundColor="transparent"})});const a=t.getBoundingClientRect(),r=i.getBoundingClientRect();let p=a.right-r.width;p<10&&(p=10),p+r.width>window.innerWidth-10&&(p=window.innerWidth-r.width-10);let u=a.bottom+4;u+r.height>window.innerHeight-10&&(u=a.top-r.height-4),i.style.left=`${Math.max(0,p)}px`,i.style.top=`${Math.max(0,u)}px`,i.addEventListener("click",s=>{const l=s.target.closest(".action-menu-item");if(!l)return;s.preventDefault(),s.stopPropagation();const c=l.dataset.action,m=l.dataset.id||o;w.closeAll(),n(c,m)})},bind(t,e){!t||typeof e!="function"||(t.addEventListener("click",o=>{const n=o.target.closest(".action-menu-item");if(!n)return;o.preventDefault(),o.stopPropagation();const i=n.dataset.action,a=n.dataset.id;e(i,a,n)}),t.addEventListener("action-menu-select",o=>{o.detail&&o.detail.action&&e(o.detail.action,o.detail.id,o.detail.trigger)}))}};typeof document<"u"&&(document.addEventListener("click",t=>{const e=t.target.closest('.btn-action-menu-trigger, [data-bs-toggle="dropdown"]');if(e){if(t.preventDefault(),t.stopPropagation(),w._activeTrigger===e){w.closeAll();return}let o=[];const n=e.getAttribute("data-actions");if(n)try{o=JSON.parse(decodeURIComponent(n))}catch{}if(!o||!o.length){const a=e.parentElement?.querySelector(".dropdown-menu");a&&a.querySelectorAll(".action-menu-item").forEach(r=>{o.push({action:r.dataset.action,id:r.dataset.id,label:r.textContent.trim(),danger:r.classList.contains("text-danger")})})}const i=e.getAttribute("data-entity-id")||e.closest("[data-entity-id]")?.dataset.entityId||"";w.showFloatingMenu(e,o,i);return}t.target.closest("#floating-action-menu-portal, #bottom-sheet, .bottom-sheet-overlay")||w.closeAll()}),window.addEventListener("resize",()=>{w._activeFloatingMenu&&!document.getElementById("bottom-sheet")&&w.closeAll()}),window.addEventListener("scroll",()=>{w._activeFloatingMenu&&w.closeAll()},{passive:!0}),document.addEventListener("keydown",t=>{t.key==="Escape"&&w.closeAll()}));function T(){if(typeof window>"u")return;const t=()=>{window.visualViewport&&(window.visualViewport.height<window.innerHeight*.75?document.body.classList.add("virtual-keyboard-open"):document.body.classList.remove("virtual-keyboard-open"))};window.visualViewport&&(window.visualViewport.addEventListener("resize",t),window.visualViewport.addEventListener("scroll",t)),window.addEventListener("focusin",e=>{e.target&&(e.target.tagName==="INPUT"||e.target.tagName==="TEXTAREA"||e.target.tagName==="SELECT")&&window.innerWidth<=768&&setTimeout(t,150)}),window.addEventListener("focusout",()=>{window.innerWidth<=768&&setTimeout(t,150)}),t()}const R={create({container:t,options:e=[],onChange:o,activeId:n=""}){if(!t)return;const i=n||e[0]?.id||"";t.innerHTML=`
      <div class="segmented-control" role="tablist">
        <div class="segmented-control-indicator"></div>
        ${e.map(l=>`
          <button type="button" class="segmented-control-item ${l.id===i?"active":""}" data-id="${l.id}" role="tab" aria-selected="${l.id===i}">
            ${l.icon?`<span>${l.icon}</span>`:""}
            <span>${l.label}</span>
            ${l.badge!==void 0?`<span class="badge badge-sm" style="margin-left: 4px; padding: 2px 6px; font-size: 0.7rem; border-radius: 9999px;">${l.badge}</span>`:""}
          </button>
        `).join("")}
      </div>
    `;const a=t.querySelector(".segmented-control"),r=a.querySelector(".segmented-control-indicator"),p=a.querySelectorAll(".segmented-control-item"),u=l=>{!r||!l||(r.style.left=`${l.offsetLeft}px`,r.style.width=`${l.offsetWidth}px`)},s=a.querySelector(".segmented-control-item.active")||p[0];return s&&setTimeout(()=>u(s),30),p.forEach(l=>{l.addEventListener("click",c=>{if(c.preventDefault(),p.forEach(m=>{m.classList.remove("active"),m.setAttribute("aria-selected","false")}),l.classList.add("active"),l.setAttribute("aria-selected","true"),u(l),navigator.vibrate)try{navigator.vibrate(10)}catch{}typeof o=="function"&&o(l.dataset.id)})}),window.addEventListener("resize",()=>{const l=a.querySelector(".segmented-control-item.active");l&&u(l)}),{setActive(l){const c=a.querySelector(`.segmented-control-item[data-id="${l}"]`);c&&c.click()}}}},$={_el:null,_timer:null,init(){typeof window>"u"||document.getElementById("network-banner")||(this._el=document.createElement("div"),this._el.id="network-banner",this._el.className="online",document.body.appendChild(this._el),window.addEventListener("online",()=>this.show("online")),window.addEventListener("offline",()=>this.show("offline")),navigator.onLine||this.show("offline"))},show(t){this._el||this.init(),this._timer&&clearTimeout(this._timer),t==="online"?(this._el.className="online visible",this._el.innerHTML="<span>\u{1F7E2}</span><span>Back Online \u2022 System Synced</span>",this._timer=setTimeout(()=>{this._el.classList.remove("visible")},3e3)):(this._el.className="offline visible",this._el.innerHTML="<span>\u{1F7E1}</span><span>Offline Mode \u2022 Changes Saved Locally</span>")},hide(){this._el&&this._el.classList.remove("visible")}},S={init(){window.GlobalSearch&&window.GlobalSearch.buildUI?.()},toggle(){window.GlobalSearch&&window.GlobalSearch.toggle()},open(){window.GlobalSearch&&window.GlobalSearch.open()},close(){window.GlobalSearch&&window.GlobalSearch.close()}},A={_overlay:null,_enteredPin:"",_defaultPin:"1234",init(){if(typeof window>"u")return;const t=window.location.pathname||"";if(t.includes("/register")||t.includes("/landing")||t.includes("/student-login")||t.includes("/kiosk")||!document.getElementById("app")&&!document.getElementById("sidebar"))return;if(document.getElementById("pin-lock-overlay"))this._overlay=document.getElementById("pin-lock-overlay"),this._overlay.style.setProperty("display","none","important");else{this._overlay=document.createElement("div"),this._overlay.id="pin-lock-overlay",this._overlay.style.cssText="display: none !important; position: fixed !important; inset: 0 !important; top: 0 !important; left: 0 !important; right: 0 !important; bottom: 0 !important; width: 100vw !important; height: 100vh !important; background: rgba(10, 15, 30, 0.96) !important; backdrop-filter: blur(28px) !important; -webkit-backdrop-filter: blur(28px) !important; z-index: 99999999 !important; align-items: center !important; justify-content: center !important; padding: 24px !important; margin: 0 !important; box-sizing: border-box !important;";const o="width: 72px !important; height: 72px !important; min-width: 72px !important; max-width: 72px !important; min-height: 72px !important; max-height: 72px !important; border-radius: 50% !important; border: 1.5px solid rgba(255, 255, 255, 0.18) !important; background: rgba(255, 255, 255, 0.08) !important; background-color: rgba(255, 255, 255, 0.08) !important; color: #ffffff !important; font-size: 1.55rem !important; font-weight: 700 !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; margin: 0 auto !important; cursor: pointer !important; box-shadow: 0 4px 14px rgba(0, 0, 0, 0.3) !important; padding: 0 !important; outline: none !important; user-select: none !important; -webkit-user-select: none !important; touch-action: manipulation !important; box-sizing: border-box !important; transition: all 0.15s ease !important;",n="width: 72px !important; height: 72px !important; min-width: 72px !important; max-width: 72px !important; min-height: 72px !important; max-height: 72px !important; border-radius: 50% !important; border: 1.5px solid transparent !important; background: transparent !important; background-color: transparent !important; color: #94a3b8 !important; font-size: 1.25rem !important; font-weight: 700 !important; display: inline-flex !important; align-items: center !important; justify-content: center !important; margin: 0 auto !important; cursor: pointer !important; box-shadow: none !important; padding: 0 !important; outline: none !important; user-select: none !important; -webkit-user-select: none !important; touch-action: manipulation !important; box-sizing: border-box !important; transition: all 0.15s ease !important;";this._overlay.innerHTML=`
        <div class="pin-lock-card" style="width: 100% !important; max-width: 360px !important; text-align: center !important; color: #ffffff !important; background: rgba(30, 41, 59, 0.85) !important; border: 1.5px solid rgba(255, 255, 255, 0.16) !important; border-radius: 28px !important; padding: 36px 24px !important; box-shadow: 0 25px 60px rgba(0,0,0,0.8), 0 0 50px rgba(99,102,241,0.25) !important; backdrop-filter: blur(24px) !important; -webkit-backdrop-filter: blur(24px) !important; box-sizing: border-box !important; margin: auto !important;">
          <div style="font-size: 3rem; margin-bottom: 10px; line-height: 1;">\u{1F512}</div>
          <h3 style="font-weight: 800; margin: 0 0 6px 0; font-size: 1.45rem; color: #ffffff; letter-spacing: -0.3px;">Front-Desk Locked</h3>
          <p style="color: #94a3b8; font-size: 0.86rem; margin: 0;">Enter 4-digit PIN to unlock reception terminal</p>
          
          <div class="pin-dot-container" id="pin-dots" style="display: flex !important; justify-content: center !important; align-items: center !important; gap: 16px !important; margin: 24px 0 28px !important;">
            <div class="pin-dot" style="width: 16px !important; height: 16px !important; border-radius: 50% !important; border: 2px solid rgba(255,255,255,0.4) !important; background: transparent !important; transition: all 0.2s cubic-bezier(0.16,1,0.3,1) !important; box-sizing: border-box !important;"></div>
            <div class="pin-dot" style="width: 16px !important; height: 16px !important; border-radius: 50% !important; border: 2px solid rgba(255,255,255,0.4) !important; background: transparent !important; transition: all 0.2s cubic-bezier(0.16,1,0.3,1) !important; box-sizing: border-box !important;"></div>
            <div class="pin-dot" style="width: 16px !important; height: 16px !important; border-radius: 50% !important; border: 2px solid rgba(255,255,255,0.4) !important; background: transparent !important; transition: all 0.2s cubic-bezier(0.16,1,0.3,1) !important; box-sizing: border-box !important;"></div>
            <div class="pin-dot" style="width: 16px !important; height: 16px !important; border-radius: 50% !important; border: 2px solid rgba(255,255,255,0.4) !important; background: transparent !important; transition: all 0.2s cubic-bezier(0.16,1,0.3,1) !important; box-sizing: border-box !important;"></div>
          </div>

          <div class="pin-keypad" style="display: grid !important; grid-template-columns: repeat(3, 72px) !important; grid-template-rows: repeat(4, 72px) !important; gap: 16px !important; justify-content: center !important; align-items: center !important; max-width: 280px !important; margin: 0 auto !important; padding: 0 !important;">
            <button type="button" class="pin-key" data-num="1" style="${o}">1</button>
            <button type="button" class="pin-key" data-num="2" style="${o}">2</button>
            <button type="button" class="pin-key" data-num="3" style="${o}">3</button>
            <button type="button" class="pin-key" data-num="4" style="${o}">4</button>
            <button type="button" class="pin-key" data-num="5" style="${o}">5</button>
            <button type="button" class="pin-key" data-num="6" style="${o}">6</button>
            <button type="button" class="pin-key" data-num="7" style="${o}">7</button>
            <button type="button" class="pin-key" data-num="8" style="${o}">8</button>
            <button type="button" class="pin-key" data-num="9" style="${o}">9</button>
            <button type="button" class="pin-key key-action" id="btn-pin-clear" title="Clear PIN" style="${n}">\u2715</button>
            <button type="button" class="pin-key" data-num="0" style="${o}">0</button>
            <button type="button" class="pin-key key-action" id="btn-pin-backspace" title="Backspace" style="${n}">\u232B</button>
          </div>
          <div style="margin-top: 20px; font-size: 0.76rem; color: #64748b;">
            Default PIN: <strong style="color: #94a3b8;">1234</strong>
          </div>
        </div>
      `,document.body.appendChild(this._overlay),this._overlay.querySelectorAll(".pin-key[data-num]").forEach(i=>{i.addEventListener("click",a=>{a.preventDefault(),a.stopPropagation(),this.handleDigit(i.dataset.num)})}),this._overlay.querySelector("#btn-pin-clear")?.addEventListener("click",i=>{i.preventDefault(),i.stopPropagation(),this.clear()}),this._overlay.querySelector("#btn-pin-backspace")?.addEventListener("click",i=>{i.preventDefault(),i.stopPropagation(),this.backspace()}),document.addEventListener("keydown",i=>{!this._overlay||this._overlay.style.display==="none"||!this._overlay.classList.contains("active")||(/^[0-9]$/.test(i.key)?this.handleDigit(i.key):i.key==="Backspace"?this.backspace():i.key==="Escape"&&this.clear())})}const e=document.getElementById("btn-header-lock");e&&(e.onclick=o=>{o.preventDefault(),this.lock()}),sessionStorage.getItem("sl_desk_locked")==="true"&&this.lock()},lock(){(!this._overlay||!document.getElementById("pin-lock-overlay"))&&this.init(),this._overlay&&(this._enteredPin="",this.updateDots(),this._overlay.style.setProperty("display","flex","important"),this._overlay.classList.add("active"),sessionStorage.setItem("sl_desk_locked","true"))},unlock(){this._overlay&&(this._overlay.style.setProperty("display","none","important"),this._overlay.classList.remove("active"),this._enteredPin="",this.updateDots(),sessionStorage.removeItem("sl_desk_locked"),x.success("Front-Desk terminal unlocked"))},handleDigit(t){if(!(this._enteredPin.length>=4)){if(this._enteredPin+=t,this.updateDots(),navigator.vibrate)try{navigator.vibrate(15)}catch{}this._enteredPin.length===4&&setTimeout(()=>this.verify(),100)}},backspace(){this._enteredPin.length>0&&(this._enteredPin=this._enteredPin.slice(0,-1),this.updateDots())},clear(){this._enteredPin="",this.updateDots()},updateDots(){const t=this._overlay?.querySelectorAll(".pin-dot");t&&t.forEach((e,o)=>{o<this._enteredPin.length?(e.classList.add("filled"),e.style.setProperty("background","#6366f1","important"),e.style.setProperty("border-color","#818cf8","important"),e.style.setProperty("box-shadow","0 0 16px rgba(99, 102, 241, 0.9)","important"),e.style.setProperty("transform","scale(1.25)","important")):(e.classList.remove("filled"),e.style.setProperty("background","transparent","important"),e.style.setProperty("border-color","rgba(255, 255, 255, 0.4)","important"),e.style.setProperty("box-shadow","none","important"),e.style.setProperty("transform","scale(1)","important"))})},verify(){const t=localStorage.getItem("sl_desk_pin")||this._defaultPin;if(this._enteredPin===t)this.unlock();else{const e=this._overlay?.querySelector(".pin-lock-card");if(e&&(e.classList.add("pin-shake"),setTimeout(()=>e.classList.remove("pin-shake"),400)),navigator.vibrate)try{navigator.vibrate([50,50,50])}catch{}x.error("Incorrect PIN. Default PIN: 1234"),this.clear()}}};typeof window<"u"&&(window.Toast=x,window.Modal=d,window.Modal.closeAll=d.closeAll,window.Modal.close=d.close,window.Modal.hide=d.hide,window.Modal.confirm=d.confirm,window.Confirm=E,window.Loading=B,window.BottomSheet=k,window.FAB=O,window.ActionMenu=w,window.SegmentedControl=R,window.NetworkBanner=$,window.CommandPalette=S,window.PinLock=A,window.initPullToRefresh=C,window.initVisualViewportKeyboardListener=T,window.PDFExport=q,window.VoiceSearch=z,window.renderMobileBottomNav=I,document.readyState==="loading"?document.addEventListener("DOMContentLoaded",()=>{T(),$.init(),S.init(),A.init()}):(T(),$.init(),S.init(),A.init()));export{w as ActionMenu,k as BottomSheet,S as CommandPalette,E as Confirm,O as FAB,B as Loading,d as Modal,H as ModalClass,V as NativeShare,$ as NetworkBanner,q as PDFExport,A as PinLock,R as SegmentedControl,x as Toast,F as UI,z as VoiceSearch,D as buttonLoading,Y as copyToClipboard,j as debounce,N as emptyState,h as escapeHTML,C as initPullToRefresh,T as initVisualViewportKeyboardListener,I as renderMobileBottomNav};
