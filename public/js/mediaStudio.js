import{escapeHTML as k,Toast as v,Modal as z}from"./ui.js";class F{constructor(t={}){this.options={preset:t.preset||"general",title:t.title||"Smart Image Studio",aspectRatio:t.aspectRatio||null,value:t.value||"",onSave:t.onSave||null,maxSizeKB:t.maxSizeKB||250,maxWidth:t.maxWidth||1200,maxHeight:t.maxHeight||1200,...t},this.options.aspectRatio===null&&(this.options.preset==="passport"?this.options.aspectRatio=1:this.options.preset==="stamp_logo"||this.options.preset==="qr_code"?this.options.aspectRatio=1:this.options.preset==="document"&&(this.options.aspectRatio=1.33)),this.activeSourceTab="upload",this.currentImage=null,this.stream=null,this.cameraFacingMode="user",this.rotation=0,this.flipH=!1,this.flipV=!1,this.zoom=1,this.brightness=0,this.contrast=0,this.saturation=100,this.activeFilter="none",this.bgThreshold=215,this.crop={x:.1,y:.1,w:.8,h:.8},this.isDraggingCrop=!1,this.activeHandle=null,this.dragStart={x:0,y:0},this.cropStart={x:0,y:0,w:0,h:0},this.initModal()}static open(t={}){return new Promise(s=>{new F({...t,onSave:n=>{t.onSave&&t.onSave(n),s(n)}}).show()})}initModal(){this.modalContent=document.createElement("div"),this.modalContent.className="media-studio-modal-wrapper",this.modalContent.innerHTML=`
      <div style="font-family: 'Outfit', sans-serif; user-select: none;">
        <!-- Top Source Selection Tabs -->
        <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom flex-wrap gap-2">
          <div class="d-flex gap-2">
            <button type="button" class="btn btn-sm btn-primary ms-tab-btn" data-tab="upload" style="font-weight: 600;">
              \u{1F4C1} Upload & Drag-Drop
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary ms-tab-btn" data-tab="camera" style="font-weight: 600;">
              \u{1F4F8} Live Camera Capture
            </button>
          </div>
          <div class="d-flex align-items-center gap-1">
            <span class="badge badge-primary" style="text-transform: uppercase; font-size: 0.7rem;">
              ${this.options.preset.replace("_"," ")} MODE
            </span>
          </div>
        </div>

        <!-- MAIN WORKSPACE -->
        <style>
          @media (max-width: 767px) {
            .ms-workspace-grid { grid-template-columns: 1fr !important; }
          }
        </style>
        <div class="ms-workspace-grid" style="display: grid; grid-template-columns: 1fr 280px; gap: 16px;">
          
          <!-- LEFT: Interactive Canvas Viewport -->
          <div class="ms-viewport-container" style="background: #0f172a; border-radius: 10px; position: relative; overflow: hidden; height: 380px; display: flex; align-items: center; justify-content: center; border: 1px solid var(--color-border);">
            
            <!-- Upload Drop Zone (Visible when no image) -->
            <div class="ms-drop-zone p-4 text-center" style="cursor: pointer; width: 100%; height: 100%; display: flex; flex-direction: column; align-items: center; justify-content: center;">
              <div style="font-size: 48px; margin-bottom: 8px;">\u{1F5BC}\uFE0F</div>
              <h4 style="margin: 0; color: #f8fafc; font-weight: 600; font-size: 1.1rem;">Choose image, drop file, or paste (Ctrl+V)</h4>
              <p style="color: #94a3b8; font-size: 0.8rem; margin: 4px 0 16px 0;">Supports JPG, PNG, WebP, HEIC (Max 15MB)</p>
              <input type="file" class="ms-file-input" accept="image/*" style="display: none;">
              <button type="button" class="btn btn-primary btn-sm ms-select-file-btn">Browse Local Files</button>
            </div>

            <!-- Live Camera Viewfinder (Hidden by default) -->
            <div class="ms-camera-viewfinder" style="display: none; width: 100%; height: 100%; position: relative; background: #000;">
              <video class="ms-camera-video" autoplay playsinline style="width: 100%; height: 100%; object-fit: cover;"></video>
              
              <!-- Camera Overlay Guide based on Preset -->
              <div class="ms-camera-guide" style="position: absolute; inset: 0; pointer-events: none; display: flex; align-items: center; justify-content: center;">
                ${this.renderGuideOverlay()}
              </div>

              <!-- Camera Controls Overlay -->
              <div style="position: absolute; bottom: 16px; left: 0; right: 0; display: flex; justify-content: center; align-items: center; gap: 16px; z-index: 10;">
                <button type="button" class="btn btn-sm btn-secondary ms-flip-cam-btn" title="Flip Camera" style="border-radius: 50%; width: 42px; height: 42px; padding: 0;">
                  \u{1F504}
                </button>
                <button type="button" class="btn btn-primary ms-snap-btn" style="border-radius: 50%; width: 60px; height: 60px; padding: 0; font-size: 24px; box-shadow: 0 0 0 4px rgba(255,255,255,0.4); background: #ef4444; border: 3px solid #fff;">
                  \u{1F4F8}
                </button>
                <button type="button" class="btn btn-sm btn-secondary ms-timer-btn" title="3s Timer" style="border-radius: 50%; width: 42px; height: 42px; padding: 0; font-weight: 700; font-size: 0.8rem;">
                  \u23F1\uFE0F 3s
                </button>
              </div>

              <!-- Countdown Overlay -->
              <div class="ms-countdown-overlay" style="display: none; position: absolute; inset: 0; background: rgba(0,0,0,0.6); align-items: center; justify-content: center; z-index: 20; color: #fff; font-size: 80px; font-weight: 800;">
                3
              </div>
            </div>

            <!-- Processing & Crop Canvas Viewport -->
            <div class="ms-crop-viewport" style="display: none; width: 100%; height: 100%; position: relative;">
              <canvas class="ms-main-canvas" style="width: 100%; height: 100%; display: block; object-fit: contain;"></canvas>
              
              <!-- Draggable Crop Box Overlay -->
              <div class="ms-crop-box" style="position: absolute; border: 2px solid #38bdf8; box-shadow: 0 0 0 9999px rgba(0, 0, 0, 0.65); cursor: move; touch-action: none;">
                <!-- 3x3 Grid Lines -->
                <div style="position: absolute; inset: 0; display: grid; grid-template-columns: 1fr 1fr 1fr; grid-template-rows: 1fr 1fr 1fr; pointer-events: none; opacity: 0.4;">
                  <div style="border-right: 1px dashed #fff; border-bottom: 1px dashed #fff;"></div>
                  <div style="border-right: 1px dashed #fff; border-bottom: 1px dashed #fff;"></div>
                  <div style="border-bottom: 1px dashed #fff;"></div>
                  <div style="border-right: 1px dashed #fff; border-bottom: 1px dashed #fff;"></div>
                  <div style="border-right: 1px dashed #fff; border-bottom: 1px dashed #fff;"></div>
                  <div style="border-bottom: 1px dashed #fff;"></div>
                  <div style="border-right: 1px dashed #fff;"></div>
                  <div style="border-right: 1px dashed #fff;"></div>
                  <div></div>
                </div>

                <!-- 8 Resize Handles -->
                <div class="ms-handle ms-handle-tl" data-handle="tl" style="position: absolute; top: -6px; left: -6px; width: 12px; height: 12px; background: #38bdf8; border: 2px solid #fff; border-radius: 2px; cursor: nwse-resize;"></div>
                <div class="ms-handle ms-handle-tr" data-handle="tr" style="position: absolute; top: -6px; right: -6px; width: 12px; height: 12px; background: #38bdf8; border: 2px solid #fff; border-radius: 2px; cursor: nesw-resize;"></div>
                <div class="ms-handle ms-handle-bl" data-handle="bl" style="position: absolute; bottom: -6px; left: -6px; width: 12px; height: 12px; background: #38bdf8; border: 2px solid #fff; border-radius: 2px; cursor: nesw-resize;"></div>
                <div class="ms-handle ms-handle-br" data-handle="br" style="position: absolute; bottom: -6px; right: -6px; width: 12px; height: 12px; background: #38bdf8; border: 2px solid #fff; border-radius: 2px; cursor: nwse-resize;"></div>
                
                <div class="ms-handle ms-handle-t" data-handle="t" style="position: absolute; top: -5px; left: 50%; transform: translateX(-50%); width: 18px; height: 8px; background: #38bdf8; border: 1px solid #fff; border-radius: 2px; cursor: ns-resize;"></div>
                <div class="ms-handle ms-handle-b" data-handle="b" style="position: absolute; bottom: -5px; left: 50%; transform: translateX(-50%); width: 18px; height: 8px; background: #38bdf8; border: 1px solid #fff; border-radius: 2px; cursor: ns-resize;"></div>
                <div class="ms-handle ms-handle-l" data-handle="l" style="position: absolute; left: -5px; top: 50%; transform: translateY(-50%); width: 8px; height: 18px; background: #38bdf8; border: 1px solid #fff; border-radius: 2px; cursor: ew-resize;"></div>
                <div class="ms-handle ms-handle-r" data-handle="r" style="position: absolute; right: -5px; top: 50%; transform: translateY(-50%); width: 8px; height: 18px; background: #38bdf8; border: 1px solid #fff; border-radius: 2px; cursor: ew-resize;"></div>
              </div>
            </div>
          </div>

          <!-- RIGHT: Control Toolbar & Filters -->
          <div class="ms-tools-sidebar" style="display: flex; flex-direction: column; gap: 12px; max-height: 380px; overflow-y: auto; padding-right: 4px;">
            
            <!-- Quick Actions Toolbar -->
            <div style="background: var(--color-surface); padding: 10px; border-radius: 8px; border: 1px solid var(--color-border);">
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">\u{1F504} TRANSFORM</label>
              <div class="d-flex gap-1 mb-2">
                <button type="button" class="btn btn-sm btn-outline-secondary flex-1 ms-rotate-btn" title="Rotate 90\xB0">\u{1F504} 90\xB0</button>
                <button type="button" class="btn btn-sm btn-outline-secondary flex-1 ms-fliph-btn" title="Flip Horizontal">\u2194\uFE0F</button>
                <button type="button" class="btn btn-sm btn-outline-secondary flex-1 ms-flipv-btn" title="Flip Vertical">\u2195\uFE0F</button>
                <button type="button" class="btn btn-sm btn-outline-danger ms-reset-btn" title="Reset All">\u{1F9F9}</button>
              </div>

              <!-- Aspect Ratio Presets -->
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">\u{1F4D0} ASPECT RATIO</label>
              <div class="d-flex flex-wrap gap-1">
                <button type="button" class="btn btn-xs ${this.options.aspectRatio===1?"btn-primary":"btn-outline-secondary"} ms-aspect-btn" data-aspect="1" style="font-size: 0.75rem; padding: 2px 6px;">1:1 Square</button>
                <button type="button" class="btn btn-xs ${this.options.aspectRatio===.75?"btn-primary":"btn-outline-secondary"} ms-aspect-btn" data-aspect="0.75" style="font-size: 0.75rem; padding: 2px 6px;">3:4 Passport</button>
                <button type="button" class="btn btn-xs ${this.options.aspectRatio===1.33?"btn-primary":"btn-outline-secondary"} ms-aspect-btn" data-aspect="1.33" style="font-size: 0.75rem; padding: 2px 6px;">4:3 Doc</button>
                <button type="button" class="btn btn-xs ${this.options.aspectRatio===null?"btn-primary":"btn-outline-secondary"} ms-aspect-btn" data-aspect="free" style="font-size: 0.75rem; padding: 2px 6px;">Free</button>
              </div>
            </div>

            <!-- Smart Auto-Enhance & Filter Presets -->
            <div style="background: var(--color-surface); padding: 10px; border-radius: 8px; border: 1px solid var(--color-border);">
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">\u26A1 SMART ENHANCE</label>
              <div class="d-flex flex-column gap-1">
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn active" data-filter="none" style="font-size: 0.8rem;">
                  \u2728 Original / Natural
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="auto_enhance" style="font-size: 0.8rem;">
                  \u{1F31F} Auto Balance & Clarity
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="doc_scan" style="font-size: 0.8rem;">
                  \u{1F4C4} B&W Document Scanner
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="magic_color" style="font-size: 0.8rem;">
                  \u{1F3A8} Magic Color Contrast
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="transparent_bg" style="font-size: 0.8rem;">
                  \u{1F9F9} Transparent Background
                </button>
              </div>
            </div>

            <!-- Manual Fine-Tuning Sliders -->
            <div style="background: var(--color-surface); padding: 10px; border-radius: 8px; border: 1px solid var(--color-border);">
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">\u{1F39B}\uFE0F MANUAL ADJUST</label>
              
              <div class="mb-2">
                <div class="d-flex justify-content-between text-xs text-muted">
                  <span>Brightness:</span>
                  <span class="ms-val-brightness font-monospace">0</span>
                </div>
                <input type="range" class="form-range ms-slider-brightness w-100" min="-80" max="80" value="0">
              </div>

              <div class="mb-2">
                <div class="d-flex justify-content-between text-xs text-muted">
                  <span>Contrast:</span>
                  <span class="ms-val-contrast font-monospace">0</span>
                </div>
                <input type="range" class="form-range ms-slider-contrast w-100" min="-80" max="80" value="0">
              </div>

              <div>
                <div class="d-flex justify-content-between text-xs text-muted">
                  <span>Saturation:</span>
                  <span class="ms-val-saturation font-monospace">100%</span>
                </div>
                <input type="range" class="form-range ms-slider-saturation w-100" min="0" max="200" value="100">
              </div>
            </div>

          </div>
        </div>

        <!-- FOOTER ACTIONS -->
        <div class="d-flex justify-content-between align-items-center mt-3 pt-2 border-top">
          <div class="text-xs text-muted ms-file-info">
            No image loaded
          </div>
          <div class="d-flex gap-2">
            <button type="button" class="btn btn-secondary btn-sm ms-btn-cancel">Cancel</button>
            <button type="button" class="btn btn-primary btn-sm ms-btn-apply" disabled style="font-weight: 700; padding: 6px 16px;">
              \u{1F4BE} Apply & Crop
            </button>
          </div>
        </div>
      </div>
    `,this.initEvents()}renderGuideOverlay(){return this.options.preset==="passport"?`
        <div style="width: 180px; height: 230px; border: 2px dashed #22c55e; border-radius: 50%; box-shadow: 0 0 0 9999px rgba(0,0,0,0.5);">
          <div style="text-align: center; color: #fff; font-size: 11px; margin-top: 240px; font-weight: 600; text-shadow: 0 1px 3px #000;">
            Align Face Inside Oval
          </div>
        </div>
      `:this.options.preset==="document"?`
        <div style="width: 80%; height: 75%; border: 2px dashed #38bdf8; border-radius: 8px; box-shadow: 0 0 0 9999px rgba(0,0,0,0.5);">
          <div style="text-align: center; color: #fff; font-size: 11px; margin-top: 10px; font-weight: 600; text-shadow: 0 1px 3px #000;">
            Align Document / ID Card Inside Frame
          </div>
        </div>
      `:`
      <div style="width: 70%; height: 70%; border: 2px dashed #e2e8f0; border-radius: 8px;"></div>
    `}initEvents(){const t=this.modalContent;t.querySelectorAll(".ms-tab-btn").forEach(e=>{e.addEventListener("click",()=>{const i=e.dataset.tab;this.activeSourceTab=i,t.querySelectorAll(".ms-tab-btn").forEach(r=>{r.classList.remove("btn-primary"),r.classList.add("btn-outline-secondary")}),e.classList.add("btn-primary"),e.classList.remove("btn-outline-secondary"),i==="camera"?this.startCamera():(this.stopCamera(),t.querySelector(".ms-camera-viewfinder").style.display="none",this.currentImage?t.querySelector(".ms-crop-viewport").style.display="block":t.querySelector(".ms-drop-zone").style.display="flex")})});const s=t.querySelector(".ms-drop-zone"),n=t.querySelector(".ms-file-input"),d=t.querySelector(".ms-select-file-btn");d?.addEventListener("click",()=>n.click()),s?.addEventListener("click",e=>{e.target!==d&&n.click()}),n?.addEventListener("change",e=>{e.target.files&&e.target.files[0]&&this.loadFile(e.target.files[0])}),s?.addEventListener("dragover",e=>{e.preventDefault(),s.style.background="rgba(99, 102, 241, 0.15)"}),s?.addEventListener("dragleave",()=>{s.style.background="transparent"}),s?.addEventListener("drop",e=>{e.preventDefault(),s.style.background="transparent",e.dataTransfer.files&&e.dataTransfer.files[0]&&this.loadFile(e.dataTransfer.files[0])}),window.addEventListener("paste",e=>{if(e.clipboardData&&e.clipboardData.items){for(let i of e.clipboardData.items)if(i.type.indexOf("image")!==-1){const r=i.getAsFile();this.loadFile(r),v.info("Image pasted from clipboard");break}}}),t.querySelector(".ms-flip-cam-btn")?.addEventListener("click",()=>{this.cameraFacingMode=this.cameraFacingMode==="user"?"environment":"user",this.startCamera()}),t.querySelector(".ms-timer-btn")?.addEventListener("click",()=>{this.snapWithCountdown(3)}),t.querySelector(".ms-snap-btn")?.addEventListener("click",()=>{this.captureCamera()}),t.querySelector(".ms-rotate-btn")?.addEventListener("click",()=>{this.rotation=(this.rotation+90)%360,this.renderCanvas()}),t.querySelector(".ms-fliph-btn")?.addEventListener("click",()=>{this.flipH=!this.flipH,this.renderCanvas()}),t.querySelector(".ms-flipv-btn")?.addEventListener("click",()=>{this.flipV=!this.flipV,this.renderCanvas()}),t.querySelector(".ms-reset-btn")?.addEventListener("click",()=>{this.resetAdjustments()}),t.querySelectorAll(".ms-aspect-btn").forEach(e=>{e.addEventListener("click",()=>{t.querySelectorAll(".ms-aspect-btn").forEach(r=>{r.classList.remove("btn-primary"),r.classList.add("btn-outline-secondary")}),e.classList.add("btn-primary"),e.classList.remove("btn-outline-secondary");const i=e.dataset.aspect;this.options.aspectRatio=i==="free"?null:parseFloat(i),this.resetCropBox()})}),t.querySelectorAll(".ms-filter-btn").forEach(e=>{e.addEventListener("click",()=>{t.querySelectorAll(".ms-filter-btn").forEach(i=>{i.classList.remove("btn-primary","active"),i.classList.add("btn-outline-secondary")}),e.classList.add("btn-primary","active"),e.classList.remove("btn-outline-secondary"),this.activeFilter=e.dataset.filter,this.renderCanvas()})}),t.querySelector(".ms-slider-brightness")?.addEventListener("input",e=>{this.brightness=parseInt(e.target.value,10),t.querySelector(".ms-val-brightness").textContent=this.brightness,this.renderCanvas()}),t.querySelector(".ms-slider-contrast")?.addEventListener("input",e=>{this.contrast=parseInt(e.target.value,10),t.querySelector(".ms-val-contrast").textContent=this.contrast,this.renderCanvas()}),t.querySelector(".ms-slider-saturation")?.addEventListener("input",e=>{this.saturation=parseInt(e.target.value,10),t.querySelector(".ms-val-saturation").textContent=`${this.saturation}%`,this.renderCanvas()}),this.initCropBoxEvents(),t.querySelector(".ms-btn-apply")?.addEventListener("click",()=>{this.applyAndSave()}),t.querySelector(".ms-btn-cancel")?.addEventListener("click",()=>{this.close()})}initCropBoxEvents(){const t=this.modalContent,s=t.querySelector(".ms-crop-box"),n=t.querySelector(".ms-crop-viewport"),d=r=>{r.preventDefault();const p=n.getBoundingClientRect(),o=r.touches?r.touches[0].clientX:r.clientX,h=r.touches?r.touches[0].clientY:r.clientY;this.dragStart={x:o,y:h},this.cropStart={...this.crop},r.target.classList.contains("ms-handle")?this.activeHandle=r.target.dataset.handle:this.isDraggingCrop=!0,window.addEventListener("mousemove",e),window.addEventListener("mouseup",i),window.addEventListener("touchmove",e,{passive:!1}),window.addEventListener("touchend",i)},e=r=>{const p=n.getBoundingClientRect(),o=r.touches?r.touches[0].clientX:r.clientX,h=r.touches?r.touches[0].clientY:r.clientY,c=(o-this.dragStart.x)/p.width,u=(h-this.dragStart.y)/p.height;this.isDraggingCrop?(this.crop.x=Math.max(0,Math.min(1-this.crop.w,this.cropStart.x+c)),this.crop.y=Math.max(0,Math.min(1-this.crop.h,this.cropStart.y+u))):this.activeHandle&&this.handleResize(this.activeHandle,c,u,p.width,p.height),this.updateCropBoxDOM()},i=()=>{this.isDraggingCrop=!1,this.activeHandle=null,window.removeEventListener("mousemove",e),window.removeEventListener("mouseup",i),window.removeEventListener("touchmove",e),window.removeEventListener("touchend",i)};s?.addEventListener("mousedown",d),s?.addEventListener("touchstart",d,{passive:!1})}handleResize(t,s,n,d,e){let{x:i,y:r,w:p,h:o}=this.cropStart;const h=.1;if(t.includes("r")&&(p=Math.max(h,Math.min(1-i,p+s))),t.includes("b")&&(o=Math.max(h,Math.min(1-r,o+n))),t.includes("l")){const c=Math.max(0,Math.min(i+p-h,i+s));p=p+(i-c),i=c}if(t.includes("t")){const c=Math.max(0,Math.min(r+o-h,r+n));o=o+(r-c),r=c}if(this.options.aspectRatio){const c=p*d/(o*e);t.includes("r")||t.includes("l")?o=p*d/(this.options.aspectRatio*e):p=o*e*this.options.aspectRatio/d}this.crop={x:i,y:r,w:Math.min(1-i,p),h:Math.min(1-r,o)}}resetCropBox(){const t=this.modalContent.querySelector(".ms-crop-viewport");if(!t)return;const s=t.clientWidth||500,n=t.clientHeight||380;let d=.8,e=.8;this.options.aspectRatio&&(this.options.aspectRatio>1?e=d/this.options.aspectRatio:d=e*this.options.aspectRatio),this.crop={x:(1-d)/2,y:(1-e)/2,w:d,h:e},this.updateCropBoxDOM()}updateCropBoxDOM(){const t=this.modalContent.querySelector(".ms-crop-box");t&&(t.style.left=`${this.crop.x*100}%`,t.style.top=`${this.crop.y*100}%`,t.style.width=`${this.crop.w*100}%`,t.style.height=`${this.crop.h*100}%`)}async startCamera(){this.stopCamera();const t=this.modalContent;t.querySelector(".ms-drop-zone").style.display="none",t.querySelector(".ms-crop-viewport").style.display="none";const s=t.querySelector(".ms-camera-viewfinder");s.style.display="block";try{this.stream=await navigator.mediaDevices.getUserMedia({video:{facingMode:this.cameraFacingMode,width:{ideal:1280},height:{ideal:720}},audio:!1});const n=t.querySelector(".ms-camera-video");n.srcObject=this.stream}catch{v.error("Camera permission denied or camera not found"),t.querySelector('.ms-tab-btn[data-tab="upload"]').click()}}stopCamera(){this.stream&&(this.stream.getTracks().forEach(t=>t.stop()),this.stream=null)}snapWithCountdown(t=3){const s=this.modalContent.querySelector(".ms-countdown-overlay");s.style.display="flex";let n=t;s.textContent=n;const d=setInterval(()=>{n--,n>0?s.textContent=n:(clearInterval(d),s.style.display="none",this.captureCamera())},1e3)}captureCamera(){const t=this.modalContent.querySelector(".ms-camera-video");if(!t||!t.videoWidth)return;const s=document.createElement("canvas");s.width=t.videoWidth,s.height=t.videoHeight;const n=s.getContext("2d");this.cameraFacingMode==="user"&&(n.translate(s.width,0),n.scale(-1,1)),n.drawImage(t,0,0);const d=new Image;d.onload=()=>{this.setImage(d),this.stopCamera(),v.success("Photo captured! Adjust crop and filters.")},d.src=s.toDataURL("image/jpeg",.95)}loadFile(t){if(!t)return;const s=15*1024*1024;if(t.size>s){v.error(`File too large (${(t.size/1024/1024).toFixed(1)}MB). Maximum is 15MB.`);return}if(!t.type.startsWith("image/")){v.error("Please select a valid image file (JPEG, PNG, WebP)");return}const n=new FileReader;n.onload=d=>{const e=new Image;e.onload=()=>{this.setImage(e),v.success("Image loaded successfully")},e.onerror=()=>{v.error("Failed to load image. The file may be corrupt or unsupported.")},e.src=d.target.result},n.onerror=()=>{v.error("Failed to read file. Please try again.")},n.readAsDataURL(t)}setImage(t){this.currentImage=t;const s=this.modalContent;s.querySelector(".ms-drop-zone").style.display="none",s.querySelector(".ms-camera-viewfinder").style.display="none",s.querySelector(".ms-crop-viewport").style.display="block",s.querySelector(".ms-btn-apply").disabled=!1,s.querySelector(".ms-file-info").textContent=`Dimensions: ${t.naturalWidth} \xD7 ${t.naturalHeight}px`,this.resetAdjustments(),this.resetCropBox(),this.renderCanvas()}resetAdjustments(){this.rotation=0,this.flipH=!1,this.flipV=!1,this.brightness=0,this.contrast=0,this.saturation=100,this.activeFilter="none";const t=this.modalContent;t.querySelector(".ms-slider-brightness").value=0,t.querySelector(".ms-val-brightness").textContent=0,t.querySelector(".ms-slider-contrast").value=0,t.querySelector(".ms-val-contrast").textContent=0,t.querySelector(".ms-slider-saturation").value=100,t.querySelector(".ms-val-saturation").textContent="100%",t.querySelectorAll(".ms-filter-btn").forEach(s=>{s.classList.remove("btn-primary","active"),s.classList.add("btn-outline-secondary")}),t.querySelector('.ms-filter-btn[data-filter="none"]')?.classList.add("btn-primary","active"),this.renderCanvas()}renderCanvas(){if(!this.currentImage)return;const t=this.modalContent.querySelector(".ms-main-canvas"),s=this.modalContent.querySelector(".ms-crop-viewport");if(!t||!s)return;t.width=s.clientWidth||500,t.height=s.clientHeight||380;const n=t.getContext("2d"),d=t.width,e=t.height;n.clearRect(0,0,d,e),n.save(),n.translate(d/2,e/2),n.rotate(this.rotation*Math.PI/180),n.scale(this.flipH?-1:1,this.flipV?-1:1);const i=this.rotation===90||this.rotation===270,r=i?this.currentImage.naturalHeight:this.currentImage.naturalWidth,p=i?this.currentImage.naturalWidth:this.currentImage.naturalHeight,o=Math.min(d/r,e/p),h=this.currentImage.naturalWidth*o,c=this.currentImage.naturalHeight*o;n.drawImage(this.currentImage,-h/2,-c/2,h,c),n.restore(),this.applyPixelFilters(n,d,e)}applyPixelFilters(t,s,n){const d=t.getImageData(0,0,s,n),e=d.data,i=this.brightness*1.5,r=259*(this.contrast+255)/(255*(259-this.contrast)),p=this.saturation/100;for(let o=0;o<e.length;o+=4){if(e[o+3]===0)continue;let h=e[o],c=e[o+1],u=e[o+2];h=r*(h+i-128)+128,c=r*(c+i-128)+128,u=r*(u+i-128)+128;const b=.299*h+.587*c+.114*u;h=b+(h-b)*p,c=b+(c-b)*p,u=b+(u-b)*p,this.activeFilter==="doc_scan"?h=c=u=b>180?255:b<80?0:b*.5:this.activeFilter==="magic_color"?(h=Math.min(255,h*1.15),c=Math.min(255,c*1.15),u=Math.min(255,u*1.25)):this.activeFilter==="auto_enhance"?(h=Math.min(255,h*1.08+5),c=Math.min(255,c*1.08+5),u=Math.min(255,u*1.08+5)):this.activeFilter==="transparent_bg"&&b>this.bgThreshold&&(e[o+3]=0),e[o]=Math.max(0,Math.min(255,h)),e[o+1]=Math.max(0,Math.min(255,c)),e[o+2]=Math.max(0,Math.min(255,u))}t.putImageData(d,0,0)}applyAndSave(){const t=this.modalContent.querySelector(".ms-main-canvas");if(!t)return;const s=Math.floor(this.crop.x*t.width),n=Math.floor(this.crop.y*t.height),d=Math.floor(this.crop.w*t.width),e=Math.floor(this.crop.h*t.height),i=document.createElement("canvas");i.width=Math.min(d,this.options.maxWidth),i.height=Math.min(e,this.options.maxHeight),i.getContext("2d").drawImage(t,s,n,d,e,0,0,i.width,i.height);const r=this.activeFilter==="transparent_bg"?"image/png":"image/webp",p=i.toDataURL(r,.88);this.options.onSave&&this.options.onSave(p),v.success("Enhanced photo saved successfully"),this.close()}show(){const t={passport:"md",document:"lg",general:"lg"}[this.options.preset]||"lg";if(this.dialog=z.show({title:`\u{1F4F8} ${this.options.title||"Photo & Media Studio"}`,content:this.modalContent,size:t,onClose:()=>{this.stopCamera()}}),this.options.value){const s=new Image;s.onload=()=>this.setImage(s),s.src=this.options.value}}close(){this.stopCamera(),this.dialog&&(z.close(this.dialog),this.dialog=null)}}class R{static create({label:t="Select Photo",preset:s="passport",value:n="",name:d="photo",onChange:e=null}){const i=document.createElement("div");i.className="media-field-picker-wrapper";const r=l=>{if(!l||typeof l!="string")return"";let a=l.trim();return!a||a==="null"||a==="undefined"||a==="false"?"":a.startsWith("data:image")||a.startsWith("data:application/pdf")||a.startsWith("data:")?a:a.startsWith("uploads/")||a.startsWith("uploads\\")?"/"+a.replace(/\\/g,"/"):!a.startsWith("http://")&&!a.startsWith("https://")&&!a.startsWith("data:")&&!a.startsWith("/")?"/"+a:a},p=l=>{const a=r(l);if(!a){if(s==="qr_code"){const g=`upi://pay?pa=thecozycorner@okaxis&pn=${encodeURIComponent("Study Library")}&am=0&cu=INR`;return`<img src="${`https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(g)}`}" alt="UPI QR" style="width: 100%; height: 100%; object-fit: contain; background: #fff; padding: 2px;">`}return`<span style="font-size: 2rem; line-height: 1; opacity: 0.85;">${s==="stamp_logo"?"\u{1F3DB}\uFE0F":s==="qr_code"?"\u{1F4F1}":s==="document"?"\u{1F4D1}":"\u{1F464}"}</span>`}if(a.startsWith("data:application/pdf")||a.toLowerCase().endsWith(".pdf"))return`
          <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; width: 100%; height: 100%; background: #fee2e2; border-radius: 6px;">
            <span style="font-size: 1.6rem; line-height: 1;">\u{1F4D1}</span>
            <span style="font-size: 0.60rem; font-weight: 800; color: #dc2626; margin-top: 2px;">PDF DOC</span>
          </div>
        `;const m=a.startsWith("data:")?a:k(a),f=s==="qr_code"?"https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=thecozycorner@okaxis":`https://ui-avatars.com/api/?name=${encodeURIComponent(t.replace(/[^a-zA-Z0-9 ]/g,""))}&background=6c5ce7&color=fff&size=128`;return`<img src="${m}" alt="Preview" style="width: 100%; height: 100%; object-fit: cover; background: #fff; border-radius: 6px;" onerror="this.onerror=null; this.src='${f}';">`};i.innerHTML=`
      <div style="background: var(--color-surface); border: 1.5px solid var(--color-border); border-radius: 12px; padding: 14px; box-shadow: var(--shadow-sm); display: flex; flex-direction: column; gap: 10px;">
        <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${k(t)}</div>
        <div style="display: flex; align-items: center; gap: 14px;">
          <div class="mfp-preview" style="width: 68px; height: 68px; border-radius: 10px; background: #ffffff; display: flex; align-items: center; justify-content: center; overflow: hidden; border: 2px solid var(--color-border); flex-shrink: 0; cursor: pointer; box-shadow: var(--shadow-sm);" title="Click to Change / View Image">
            ${p(n)}
          </div>
          <div style="flex: 1; display: flex; flex-direction: column; gap: 6px;">
            <div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center;">
              <button type="button" class="btn btn-sm btn-primary mfp-upload-file-btn" style="font-size: 0.76rem; font-weight: 600; padding: 4px 10px;">
                \u{1F4C1} ${n?"Change":"Upload"}
              </button>
              <button type="button" class="btn btn-sm btn-outline-primary mfp-open-btn" style="font-size: 0.76rem; font-weight: 600; padding: 4px 10px;">
                \u{1F4F8} Camera / Studio
              </button>
              <button type="button" class="btn btn-sm btn-ghost text-danger mfp-remove-btn" style="font-size: 0.76rem; padding: 4px 8px; ${n?"":"display: none;"}">
                \u{1F5D1}\uFE0F Remove
              </button>
            </div>
            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
              <small style="color: var(--color-text-secondary); font-size: 0.72rem;">${s==="qr_code"?"\u26A1 UPI QR for student fees":s==="document"?"\u{1F4D1} Clear KYC scan / photo":"\u2728 1:1 Transparent PNG / JPG"}</small>
              <span class="mfp-view-link" style="${n?"display: inline-flex;":"display: none;"} align-items: center; gap: 3px; font-size: 0.72rem; font-weight: 700; color: var(--color-primary); cursor: pointer;">
                \u{1F441}\uFE0F View File
              </span>
            </div>
          </div>
        </div>
        <input type="file" class="mfp-file-input" accept="image/*,.pdf,application/pdf" style="display: none;">
        <input type="hidden" name="${d}" class="mfp-hidden-value" value="${k(n)}">
      </div>
    `;const o=i.querySelector(".mfp-hidden-value"),h=i.querySelector(".mfp-file-input"),c=i.querySelector(".mfp-preview"),u=i.querySelector(".mfp-remove-btn"),b=i.querySelector(".mfp-upload-file-btn"),w=i.querySelector(".mfp-view-link"),q=async l=>{if(!l){o.value="",c.innerHTML=p(""),u.style.display="none",w&&(w.style.display="none"),b.innerHTML="\u{1F4C1} Upload",o.dispatchEvent(new Event("input",{bubbles:!0})),o.dispatchEvent(new Event("change",{bubbles:!0})),e&&e("");return}if(o.value=l,c.innerHTML=p(l),u.style.display="inline-block",w&&(w.style.display="inline-flex"),b.innerHTML="\u{1F4C1} Change",o.dispatchEvent(new Event("input",{bubbles:!0})),o.dispatchEvent(new Event("change",{bubbles:!0})),e&&e(l),l&&(l.startsWith("data:image/")||l.startsWith("data:application/pdf")))try{const a=localStorage.getItem("sl_token")||localStorage.getItem("token"),m={"Content-Type":"application/json"};a&&(m.Authorization=`Bearer ${a}`);const f=await(await fetch("/api/upload",{method:"POST",headers:m,body:JSON.stringify({image:l})})).json();f.success&&f.url&&(o.value=f.url,c.innerHTML=p(f.url),w&&(w.style.display="inline-flex"),o.dispatchEvent(new Event("input",{bubbles:!0})),o.dispatchEvent(new Event("change",{bubbles:!0})),e&&e(f.url))}catch(a){console.error("Image background upload error:",a)}};w?.addEventListener("click",l=>{l.stopPropagation();const a=o.value;if(a)if(a.startsWith("data:")){const m=window.open();m&&(a.startsWith("data:application/pdf")?m.document.write(`<iframe src="${a}" frameborder="0" style="border:0; top:0; left:0; bottom:0; right:0; width:100%; height:100%;" allowfullscreen></iframe>`):m.document.write(`<img src="${a}" style="max-width:100%; max-height:100%; margin:auto; display:block;">`))}else window.open(a,"_blank")}),c.addEventListener("click",l=>{l.preventDefault(),l.stopPropagation(),h.click()}),b.addEventListener("click",l=>{l.preventDefault(),l.stopPropagation(),h.click()});const I=l=>new Promise(a=>{if(!l.type.startsWith("image/")){const f=new FileReader;f.onload=g=>a(g.target.result),f.onerror=()=>a(""),f.readAsDataURL(l);return}const m=new FileReader;m.onload=f=>{const g=new Image;g.onload=()=>{try{const C=document.createElement("canvas");let E=s==="passport"?400:1200,L=s==="passport"?400:1200,{width:y,height:x}=g;(y>E||x>L)&&(y>x?(x=Math.round(x*E/y),y=E):(y=Math.round(y*L/x),x=L)),C.width=y,C.height=x;const M=C.getContext("2d");M.imageSmoothingEnabled=!0,M.imageSmoothingQuality="high",M.drawImage(g,0,0,y,x);let S=C.toDataURL("image/webp",.85);(!S||S.length<50)&&(S=C.toDataURL("image/jpeg",.85)),a(S)}catch{a(f.target.result)}},g.onerror=()=>a(f.target.result),g.src=f.target.result},m.onerror=()=>a(""),m.readAsDataURL(l)});return h.addEventListener("change",async l=>{l.preventDefault(),l.stopPropagation();const a=l.target.files[0];if(a){if(!a.type.startsWith("image/")&&a.type!=="application/pdf"){v.error("Please select a valid image file (PNG, JPG, WebP) or PDF document");return}try{const m=await I(a);m&&(await q(m),v.success(`${t||"Document"} uploaded & optimized successfully!`))}catch(m){v.error(m.message||"File processing failed")}}}),i.querySelector(".mfp-open-btn").addEventListener("click",l=>{l.preventDefault(),l.stopPropagation(),F.open({title:t,preset:s,value:o.value,onSave:a=>{q(a)}})}),u.addEventListener("click",l=>{l.preventDefault(),l.stopPropagation(),o.value="",h.value="",c.innerHTML=p(""),u.style.display="none",b.innerHTML="\u{1F4C1} Upload",o.dispatchEvent(new Event("input",{bubbles:!0})),o.dispatchEvent(new Event("change",{bubbles:!0})),e&&e("")}),i}}export{R as MediaFieldPicker,F as MediaStudio};
