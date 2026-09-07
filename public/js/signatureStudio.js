import{Toast as x}from"./ui.js";class f{constructor(e,s={}){this.container=typeof e=="string"?document.querySelector(e):e,this.options={value:s.value||"",onChange:s.onChange||null,width:s.width||440,height:s.height||160,penColor:s.penColor||"#1e40af",penWidth:s.penWidth||2.5,...s},this.activeTab="draw",this.history=[],this.historyIndex=-1,this.rotation=0,this.threshold=210,this.originalUploadedImage=null,this.render()}render(){this.container&&(this.container.innerHTML=`
      <div class="signature-studio-wrapper" style="border: 1px solid var(--color-border); border-radius: var(--radius-lg, 12px); background: var(--color-surface); overflow: hidden; box-shadow: var(--shadow-sm);">
        <!-- Mode Tabs -->
        <div class="sig-tabs" style="display: flex; border-bottom: 1px solid var(--color-divider); background: var(--color-bg-secondary);">
          <button type="button" class="sig-tab-btn active" data-tab="draw" style="flex: 1; padding: 10px 14px; border: none; background: transparent; font-weight: 600; font-size: 0.85rem; cursor: pointer; color: var(--color-text-primary); border-bottom: 2px solid var(--color-primary); transition: all 0.2s;">
            \u270D\uFE0F Draw Signature
          </button>
          <button type="button" class="sig-tab-btn" data-tab="upload" style="flex: 1; padding: 10px 14px; border: none; background: transparent; font-weight: 600; font-size: 0.85rem; cursor: pointer; color: var(--color-text-muted); border-bottom: 2px solid transparent; transition: all 0.2s;">
            \u{1F4F7} Upload & Auto-Enhance
          </button>
          <button type="button" class="sig-tab-btn" data-tab="type" style="flex: 1; padding: 10px 14px; border: none; background: transparent; font-weight: 600; font-size: 0.85rem; cursor: pointer; color: var(--color-text-muted); border-bottom: 2px solid transparent; transition: all 0.2s;">
            \u2328\uFE0F Type to Sign
          </button>
        </div>

        <!-- 1. DRAW TAB PANEL -->
        <div class="sig-panel sig-panel-draw p-3" style="display: block;">
          <!-- Toolbar -->
          <div class="d-flex justify-content-between align-items-center mb-2 flex-wrap gap-2">
            <!-- Ink Colors -->
            <div class="d-flex align-items-center gap-1">
              <span class="text-xs text-muted me-1">Ink:</span>
              <button type="button" class="sig-color-btn active" data-color="#1e40af" style="width: 22px; height: 22px; border-radius: 50%; background: #1e40af; border: 2px solid #fff; box-shadow: 0 0 0 2px #1e40af; cursor: pointer;" title="Royal Blue"></button>
              <button type="button" class="sig-color-btn" data-color="#0f172a" style="width: 22px; height: 22px; border-radius: 50%; background: #0f172a; border: 2px solid transparent; cursor: pointer;" title="Deep Black"></button>
              <button type="button" class="sig-color-btn" data-color="#0369a1" style="width: 22px; height: 22px; border-radius: 50%; background: #0369a1; border: 2px solid transparent; cursor: pointer;" title="Navy Blue"></button>
            </div>

            <!-- Pen Width -->
            <div class="d-flex align-items-center gap-1">
              <span class="text-xs text-muted me-1">Pen:</span>
              <button type="button" class="btn btn-sm btn-ghost sig-width-btn" data-width="1.5" style="padding: 2px 6px; font-size: 0.75rem;">Fine</button>
              <button type="button" class="btn btn-sm btn-primary sig-width-btn" data-width="2.5" style="padding: 2px 6px; font-size: 0.75rem;">Medium</button>
              <button type="button" class="btn btn-sm btn-ghost sig-width-btn" data-width="4.0" style="padding: 2px 6px; font-size: 0.75rem;">Bold</button>
            </div>

            <!-- History Actions -->
            <div class="d-flex align-items-center gap-1">
              <button type="button" class="btn btn-sm btn-ghost sig-undo-btn" title="Undo" style="padding: 2px 6px; font-size: 0.8rem;">\u21A9\uFE0F Undo</button>
              <button type="button" class="btn btn-sm btn-ghost sig-clear-btn text-danger" title="Clear Pad" style="padding: 2px 6px; font-size: 0.8rem;">\u{1F9F9} Clear</button>
            </div>
          </div>

          <!-- Canvas Pad -->
          <div class="sig-canvas-container" style="position: relative; width: 100%; height: ${this.options.height}px; background: #ffffff; border: 1.5px dashed #cbd5e1; border-radius: 8px; overflow: hidden; touch-action: none; cursor: crosshair;">
            <canvas class="sig-draw-canvas" width="${this.options.width}" height="${this.options.height}" style="width: 100%; height: 100%; display: block;"></canvas>
            <div class="sig-watermark" style="position: absolute; bottom: 8px; right: 12px; font-size: 11px; color: #94a3b8; pointer-events: none; user-select: none;">
              Sign here with finger / stylus
            </div>
          </div>
        </div>

        <!-- 2. UPLOAD & AUTO-ENHANCE TAB PANEL -->
        <div class="sig-panel sig-panel-upload p-3" style="display: none;">
          <!-- Drop Zone -->
          <div class="sig-dropzone p-4 text-center" style="border: 2px dashed #6366f1; border-radius: 8px; background: rgba(99, 102, 241, 0.04); cursor: pointer; transition: all 0.2s;">
            <div style="font-size: 32px; margin-bottom: 4px;">\u{1F4F8}</div>
            <div style="font-weight: 600; font-size: 0.9rem; color: var(--color-primary);">Select or Drop Signature Photo</div>
            <p class="text-xs text-muted mb-2">Take a photo of signature on white paper (Phone / Camera / Scan)</p>
            <input type="file" class="sig-file-input" accept="image/*" style="display: none;">
            <button type="button" class="btn btn-sm btn-primary sig-browse-btn" style="font-size: 0.8rem;">Browse Image</button>
          </div>

          <!-- Upload Processing Controls (Shown after image select) -->
          <div class="sig-upload-controls mt-3" style="display: none;">
            <!-- Sliders -->
            <div class="row g-2 mb-2" style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
              <div>
                <label class="text-xs text-muted d-flex justify-content-between">
                  <span>Paper Background Removal:</span>
                  <span class="sig-threshold-val font-monospace">210</span>
                </label>
                <input type="range" class="form-range sig-threshold-slider w-100" min="120" max="250" value="210">
              </div>
              <div class="d-flex align-items-end gap-1">
                <button type="button" class="btn btn-sm btn-outline-secondary sig-autotrim-btn flex-1" style="font-size: 0.75rem;">
                  \u2702\uFE0F Smart Auto-Crop
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary sig-rotate-btn" title="Rotate 90\xB0" style="font-size: 0.75rem;">
                  \u{1F504} Rotate
                </button>
              </div>
            </div>

            <!-- Preview Canvas with Checkerboard Background -->
            <div style="position: relative; width: 100%; height: ${this.options.height}px; border-radius: 8px; border: 1px solid var(--color-border); overflow: hidden; background-image: linear-gradient(45deg, #e2e8f0 25%, transparent 25%), linear-gradient(-45deg, #e2e8f0 25%, transparent 25%), linear-gradient(45deg, transparent 75%, #e2e8f0 75%), linear-gradient(-45deg, transparent 75%, #e2e8f0 75%); background-size: 16px 16px; background-position: 0 0, 0 8px, 8px -8px, -8px 0px;">
              <canvas class="sig-enhance-canvas" width="${this.options.width}" height="${this.options.height}" style="width: 100%; height: 100%; display: block;"></canvas>
            </div>
          </div>
        </div>

        <!-- 3. TYPE TO SIGN TAB PANEL -->
        <div class="sig-panel sig-panel-type p-3" style="display: none;">
          <div class="mb-3">
            <label class="form-label text-xs text-muted">Enter Full Name:</label>
            <input type="text" class="form-control sig-type-input" placeholder="e.g. Rahul Sharma" value="${this.options.studentName||""}">
          </div>

          <div class="sig-type-preview-grid" style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px;">
            <div class="sig-font-card p-2 text-center selected" data-font="Great Vibes" style="border: 2px solid var(--color-primary); border-radius: 8px; cursor: pointer; background: var(--color-surface);">
              <div class="sig-font-text" style="font-family: 'Great Vibes', cursive; font-size: 26px; color: #1e40af;">Rahul Sharma</div>
              <div class="text-xs text-muted">Classic Script</div>
            </div>
            <div class="sig-font-card p-2 text-center" data-font="Pacifico" style="border: 2px solid var(--color-border); border-radius: 8px; cursor: pointer; background: var(--color-surface);">
              <div class="sig-font-text" style="font-family: 'Pacifico', cursive; font-size: 20px; color: #1e40af;">Rahul Sharma</div>
              <div class="text-xs text-muted">Casual Brush</div>
            </div>
            <div class="sig-font-card p-2 text-center" data-font="Dancing Script" style="border: 2px solid var(--color-border); border-radius: 8px; cursor: pointer; background: var(--color-surface);">
              <div class="sig-font-text" style="font-family: 'Dancing Script', cursive; font-size: 24px; color: #1e40af;">Rahul Sharma</div>
              <div class="text-xs text-muted">Flowing Handwriting</div>
            </div>
            <div class="sig-font-card p-2 text-center" data-font="Caveat" style="border: 2px solid var(--color-border); border-radius: 8px; cursor: pointer; background: var(--color-surface);">
              <div class="sig-font-text" style="font-family: 'Caveat', cursive; font-size: 26px; color: #1e40af;">Rahul Sharma</div>
              <div class="text-xs text-muted">Modern Cursive</div>
            </div>
          </div>
        </div>

        <!-- Footer Output Status -->
        <div class="sig-footer p-2 px-3 d-flex justify-content-between align-items-center" style="background: var(--color-bg-secondary); border-top: 1px solid var(--color-divider); font-size: 0.75rem;">
          <div class="d-flex align-items-center gap-1">
            <span class="badge badge-success" style="font-size: 0.65rem;">\u2713 Transparent PNG</span>
            <span class="text-muted sig-status-text">Signature captured cleanly</span>
          </div>
          <button type="button" class="btn btn-sm btn-ghost sig-preview-modal-btn text-primary" style="padding: 2px 8px; font-size: 0.75rem;">
            \u{1F50D} Live Preview
          </button>
        </div>
      </div>
    `,this.initEvents(),this.options.value&&this.loadExistingValue(this.options.value))}initEvents(){const e=this.container;e.querySelectorAll(".sig-tab-btn").forEach(t=>{t.addEventListener("click",()=>{e.querySelectorAll(".sig-tab-btn").forEach(n=>{n.classList.remove("active"),n.style.color="var(--color-text-muted)",n.style.borderBottomColor="transparent"}),t.classList.add("active"),t.style.color="var(--color-text-primary)",t.style.borderBottomColor="var(--color-primary)";const a=t.dataset.tab;this.activeTab=a,e.querySelectorAll(".sig-panel").forEach(n=>n.style.display="none"),e.querySelector(`.sig-panel-${a}`).style.display="block",a==="type"&&this.updateTypeCanvas()})}),this.canvas=e.querySelector(".sig-draw-canvas"),this.ctx=this.canvas.getContext("2d"),this.ctx.lineCap="round",this.ctx.lineJoin="round",this.ctx.strokeStyle=this.options.penColor,this.ctx.lineWidth=this.options.penWidth;let s=!1,i=[];const o=t=>{const a=this.canvas.getBoundingClientRect(),n=t.touches?t.touches[0].clientX:t.clientX,b=t.touches?t.touches[0].clientY:t.clientY,v=this.canvas.width/a.width,u=this.canvas.height/a.height;return{x:(n-a.left)*v,y:(b-a.top)*u}},d=t=>{t.preventDefault(),s=!0;const a=o(t);i=[a],this.ctx.beginPath(),this.ctx.moveTo(a.x,a.y)},h=t=>{if(!s)return;t.preventDefault();const a=o(t);if(i.push(a),i.length>2){const n=i.slice(-2),b=(n[0].x+n[1].x)/2,v=(n[0].y+n[1].y)/2;this.ctx.quadraticCurveTo(n[0].x,n[0].y,b,v),this.ctx.stroke()}else this.ctx.lineTo(a.x,a.y),this.ctx.stroke()},p=()=>{s&&(s=!1,this.saveHistory(),this.emitChange())};this.canvas.addEventListener("mousedown",d),this.canvas.addEventListener("mousemove",h),window.addEventListener("mouseup",p),this.canvas.addEventListener("touchstart",d,{passive:!1}),this.canvas.addEventListener("touchmove",h,{passive:!1}),window.addEventListener("touchend",p),window.addEventListener("touchcancel",p),e.querySelectorAll(".sig-color-btn").forEach(t=>{t.addEventListener("click",()=>{e.querySelectorAll(".sig-color-btn").forEach(a=>{a.style.boxShadow="none",a.style.borderColor="transparent"}),t.style.boxShadow=`0 0 0 2px ${t.dataset.color}`,t.style.borderColor="#fff",this.options.penColor=t.dataset.color,this.ctx.strokeStyle=this.options.penColor})}),e.querySelectorAll(".sig-width-btn").forEach(t=>{t.addEventListener("click",()=>{e.querySelectorAll(".sig-width-btn").forEach(a=>{a.classList.remove("btn-primary"),a.classList.add("btn-ghost")}),t.classList.add("btn-primary"),t.classList.remove("btn-ghost"),this.options.penWidth=parseFloat(t.dataset.width),this.ctx.lineWidth=this.options.penWidth})}),e.querySelector(".sig-undo-btn")?.addEventListener("click",()=>this.undo()),e.querySelector(".sig-clear-btn")?.addEventListener("click",()=>this.clear());const r=e.querySelector(".sig-dropzone"),c=e.querySelector(".sig-file-input"),g=e.querySelector(".sig-browse-btn");g?.addEventListener("click",()=>c.click()),r?.addEventListener("click",t=>{t.target!==g&&c.click()}),c?.addEventListener("change",t=>{t.target.files&&t.target.files[0]&&this.handleFileUpload(t.target.files[0])}),r?.addEventListener("dragover",t=>{t.preventDefault(),r.style.borderColor="#22c55e",r.style.background="rgba(34, 197, 94, 0.08)"}),r?.addEventListener("dragleave",()=>{r.style.borderColor="#6366f1",r.style.background="rgba(99, 102, 241, 0.04)"}),r?.addEventListener("drop",t=>{t.preventDefault(),r.style.borderColor="#6366f1",r.style.background="rgba(99, 102, 241, 0.04)",t.dataTransfer.files&&t.dataTransfer.files[0]&&this.handleFileUpload(t.dataTransfer.files[0])}),e.querySelector(".sig-threshold-slider")?.addEventListener("input",t=>{this.threshold=parseInt(t.target.value,10),e.querySelector(".sig-threshold-val").textContent=this.threshold,this.processUploadedImage()}),e.querySelector(".sig-rotate-btn")?.addEventListener("click",()=>{this.rotation=(this.rotation+90)%360,this.processUploadedImage()}),e.querySelector(".sig-autotrim-btn")?.addEventListener("click",()=>{this.autoCropEnhanceCanvas(),x.success("Signature auto-cropped tightly")});const l=e.querySelector(".sig-type-input");l?.addEventListener("input",()=>{const t=l.value.trim()||"Your Name";e.querySelectorAll(".sig-font-text").forEach(a=>a.textContent=t),this.updateTypeCanvas()}),e.querySelectorAll(".sig-font-card").forEach(t=>{t.addEventListener("click",()=>{e.querySelectorAll(".sig-font-card").forEach(a=>{a.classList.remove("selected"),a.style.borderColor="var(--color-border)"}),t.classList.add("selected"),t.style.borderColor="var(--color-primary)",this.selectedFont=t.dataset.font,this.updateTypeCanvas()})}),this.saveHistory()}saveHistory(){this.canvas&&(this.history=this.history.slice(0,this.historyIndex+1),this.history.push(this.canvas.toDataURL()),this.historyIndex++)}undo(){if(this.historyIndex>0){this.historyIndex--;const e=new Image;e.onload=()=>{this.ctx.clearRect(0,0,this.canvas.width,this.canvas.height),this.ctx.drawImage(e,0,0),this.emitChange()},e.src=this.history[this.historyIndex]}else this.historyIndex===0&&this.clear()}clear(){this.canvas&&(this.ctx.clearRect(0,0,this.canvas.width,this.canvas.height),this.history=[],this.historyIndex=-1,this.saveHistory(),this.emitChange())}handleFileUpload(e){const s=new FileReader;s.onload=i=>{const o=new Image;o.onload=()=>{this.originalUploadedImage=o,this.container.querySelector(".sig-upload-controls").style.display="block",this.processUploadedImage()},o.src=i.target.result},s.readAsDataURL(e)}processUploadedImage(){if(!this.originalUploadedImage)return;const e=this.container.querySelector(".sig-enhance-canvas");if(!e)return;const s=e.getContext("2d"),i=e.width,o=e.height;s.clearRect(0,0,i,o),s.save(),s.translate(i/2,o/2),s.rotate(this.rotation*Math.PI/180);const d=this.originalUploadedImage,h=this.rotation===90||this.rotation===270,p=h?d.height:d.width,r=h?d.width:d.height,c=Math.min(i*.9/p,o*.9/r);s.drawImage(d,-d.width*c/2,-d.height*c/2,d.width*c,d.height*c),s.restore();const g=s.getImageData(0,0,i,o),l=g.data;for(let t=0;t<l.length;t+=4){const a=l[t],n=l[t+1],b=l[t+2],v=.299*a+.587*n+.114*b;if(v>this.threshold)l[t+3]=0;else{const u=1-v/this.threshold;l[t]=30,l[t+1]=64,l[t+2]=175,l[t+3]=Math.min(255,Math.floor(u*255*1.5))}}s.putImageData(g,0,0),this.emitChange()}autoCropEnhanceCanvas(){const e=this.activeTab==="upload"?this.container.querySelector(".sig-enhance-canvas"):this.canvas;if(!e)return;const s=e.getContext("2d"),i=e.width,o=e.height,d=s.getImageData(0,0,i,o).data;let h=i,p=o,r=0,c=0,g=!1;for(let u=0;u<o;u++)for(let y=0;y<i;y++)d[(u*i+y)*4+3]>20&&(g=!0,y<h&&(h=y),y>r&&(r=y),u<p&&(p=u),u>c&&(c=u));if(!g)return;const l=10;h=Math.max(0,h-l),p=Math.max(0,p-l),r=Math.min(i,r+l),c=Math.min(o,c+l);const t=r-h,a=c-p,n=s.getImageData(h,p,t,a);s.clearRect(0,0,i,o);const b=(i-t)/2,v=(o-a)/2;s.putImageData(n,b,v),this.emitChange()}updateTypeCanvas(){const e=this.container.querySelector(".sig-type-input")?.value.trim()||"Rahul Sharma",s=this.selectedFont||"Great Vibes",i=document.createElement("canvas");i.width=this.options.width,i.height=this.options.height;const o=i.getContext("2d");o.font=`36px "${s}", cursive`,o.fillStyle="#1e40af",o.textAlign="center",o.textBaseline="middle",o.fillText(e,i.width/2,i.height/2),this.typedDataUrl=i.toDataURL(),this.emitChange()}getValue(){if(this.activeTab==="upload"){const e=this.container.querySelector(".sig-enhance-canvas");return e?e.toDataURL():""}else return this.activeTab==="type"?this.typedDataUrl||"":!this.canvas||this.isCanvasBlank(this.canvas)?"":this.canvas.toDataURL()}loadExistingValue(e){if(!e||!this.canvas)return;const s=new Image;s.onload=()=>{this.ctx.clearRect(0,0,this.canvas.width,this.canvas.height),this.ctx.drawImage(s,0,0),this.saveHistory()},s.src=e}isCanvasBlank(e){const s=e.getContext("2d");return!new Uint32Array(s.getImageData(0,0,e.width,e.height).data.buffer).some(i=>i!==0)}emitChange(){const e=this.getValue();typeof this.options.onChange=="function"&&this.options.onChange(e)}}export{f as SignatureStudio};
