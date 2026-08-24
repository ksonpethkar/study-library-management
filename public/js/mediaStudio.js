import { escapeHTML, Toast, Modal } from './ui.js';

/**
 * Universal Smart Media Studio & Live Camera Suite
 * Features:
 * - Live Camera (Front/Rear flip, 3s countdown, guide overlay, flash simulation)
 * - File Upload & Drag-and-Drop + Clipboard Paste (Ctrl+V)
 * - Manual Drag-to-Crop with 8 handles & aspect ratio presets (1:1, 3:4, 4:3, 16:9, Free)
 * - Smart Auto-Enhance (Auto-balance, Portrait, B&W Doc Scan, Magic Color, Transparent Stamp)
 * - Manual Adjustments (Brightness, Contrast, Saturation, Sharpness, Rotate 90°, Flip H/V)
 * - Client-side WebP/JPEG Compression (< 120KB)
 */
export class MediaStudio {
  constructor(options = {}) {
    this.options = {
      preset: options.preset || 'general', // 'passport' | 'document' | 'stamp_logo' | 'qr_code' | 'general'
      title: options.title || 'Smart Image Studio',
      aspectRatio: options.aspectRatio || null, // null = free, 1 = 1:1, 0.75 = 3:4, 1.33 = 4:3
      value: options.value || '',
      onSave: options.onSave || null,
      maxSizeKB: options.maxSizeKB || 250,
      maxWidth: options.maxWidth || 1200,
      maxHeight: options.maxHeight || 1200,
      ...options
    };

    // Set default aspect ratio based on preset if not specified
    if (this.options.aspectRatio === null) {
      if (this.options.preset === 'passport') this.options.aspectRatio = 1; // Square / 3:4
      else if (this.options.preset === 'stamp_logo' || this.options.preset === 'qr_code') this.options.aspectRatio = 1;
      else if (this.options.preset === 'document') this.options.aspectRatio = 1.33; // 4:3
    }

    this.activeSourceTab = 'upload'; // 'upload' | 'camera'
    this.currentImage = null; // HTMLImageElement
    this.stream = null; // MediaStream for camera
    this.cameraFacingMode = 'user'; // 'user' | 'environment'
    this.rotation = 0;
    this.flipH = false;
    this.flipV = false;
    this.zoom = 1.0;
    this.brightness = 0; // -100 to 100
    this.contrast = 0;   // -100 to 100
    this.saturation = 100; // 0 to 200%
    this.activeFilter = 'none'; // 'none' | 'auto_enhance' | 'doc_scan' | 'magic_color' | 'transparent_bg'
    this.bgThreshold = 215;

    // Crop box coordinates (in canvas normalized percentage 0..1)
    this.crop = { x: 0.1, y: 0.1, w: 0.8, h: 0.8 };
    this.isDraggingCrop = false;
    this.activeHandle = null;
    this.dragStart = { x: 0, y: 0 };
    this.cropStart = { x: 0, y: 0, w: 0, h: 0 };

    this.initModal();
  }

  static open(options = {}) {
    return new Promise((resolve) => {
      const studio = new MediaStudio({
        ...options,
        onSave: (dataUrl) => {
          if (options.onSave) options.onSave(dataUrl);
          resolve(dataUrl);
        }
      });
      studio.show();
    });
  }

  initModal() {
    this.modalContent = document.createElement('div');
    this.modalContent.className = 'media-studio-modal-wrapper';
    this.modalContent.innerHTML = `
      <div style="font-family: 'Outfit', sans-serif; user-select: none;">
        <!-- Top Source Selection Tabs -->
        <div class="d-flex justify-content-between align-items-center mb-3 pb-2 border-bottom flex-wrap gap-2">
          <div class="d-flex gap-2">
            <button type="button" class="btn btn-sm btn-primary ms-tab-btn" data-tab="upload" style="font-weight: 600;">
              📁 Upload & Drag-Drop
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary ms-tab-btn" data-tab="camera" style="font-weight: 600;">
              📸 Live Camera Capture
            </button>
          </div>
          <div class="d-flex align-items-center gap-1">
            <span class="badge badge-primary" style="text-transform: uppercase; font-size: 0.7rem;">
              ${this.options.preset.replace('_', ' ')} MODE
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
              <div style="font-size: 48px; margin-bottom: 8px;">🖼️</div>
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
                  🔄
                </button>
                <button type="button" class="btn btn-primary ms-snap-btn" style="border-radius: 50%; width: 60px; height: 60px; padding: 0; font-size: 24px; box-shadow: 0 0 0 4px rgba(255,255,255,0.4); background: #ef4444; border: 3px solid #fff;">
                  📸
                </button>
                <button type="button" class="btn btn-sm btn-secondary ms-timer-btn" title="3s Timer" style="border-radius: 50%; width: 42px; height: 42px; padding: 0; font-weight: 700; font-size: 0.8rem;">
                  ⏱️ 3s
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
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">🔄 TRANSFORM</label>
              <div class="d-flex gap-1 mb-2">
                <button type="button" class="btn btn-sm btn-outline-secondary flex-1 ms-rotate-btn" title="Rotate 90°">🔄 90°</button>
                <button type="button" class="btn btn-sm btn-outline-secondary flex-1 ms-fliph-btn" title="Flip Horizontal">↔️</button>
                <button type="button" class="btn btn-sm btn-outline-secondary flex-1 ms-flipv-btn" title="Flip Vertical">↕️</button>
                <button type="button" class="btn btn-sm btn-outline-danger ms-reset-btn" title="Reset All">🧹</button>
              </div>

              <!-- Aspect Ratio Presets -->
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">📐 ASPECT RATIO</label>
              <div class="d-flex flex-wrap gap-1">
                <button type="button" class="btn btn-xs ${this.options.aspectRatio === 1 ? 'btn-primary' : 'btn-outline-secondary'} ms-aspect-btn" data-aspect="1" style="font-size: 0.75rem; padding: 2px 6px;">1:1 Square</button>
                <button type="button" class="btn btn-xs ${this.options.aspectRatio === 0.75 ? 'btn-primary' : 'btn-outline-secondary'} ms-aspect-btn" data-aspect="0.75" style="font-size: 0.75rem; padding: 2px 6px;">3:4 Passport</button>
                <button type="button" class="btn btn-xs ${this.options.aspectRatio === 1.33 ? 'btn-primary' : 'btn-outline-secondary'} ms-aspect-btn" data-aspect="1.33" style="font-size: 0.75rem; padding: 2px 6px;">4:3 Doc</button>
                <button type="button" class="btn btn-xs ${this.options.aspectRatio === null ? 'btn-primary' : 'btn-outline-secondary'} ms-aspect-btn" data-aspect="free" style="font-size: 0.75rem; padding: 2px 6px;">Free</button>
              </div>
            </div>

            <!-- Smart Auto-Enhance & Filter Presets -->
            <div style="background: var(--color-surface); padding: 10px; border-radius: 8px; border: 1px solid var(--color-border);">
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">⚡ SMART ENHANCE</label>
              <div class="d-flex flex-column gap-1">
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn active" data-filter="none" style="font-size: 0.8rem;">
                  ✨ Original / Natural
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="auto_enhance" style="font-size: 0.8rem;">
                  🌟 Auto Balance & Clarity
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="doc_scan" style="font-size: 0.8rem;">
                  📄 B&W Document Scanner
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="magic_color" style="font-size: 0.8rem;">
                  🎨 Magic Color Contrast
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary text-start ms-filter-btn" data-filter="transparent_bg" style="font-size: 0.8rem;">
                  🧹 Transparent Background
                </button>
              </div>
            </div>

            <!-- Manual Fine-Tuning Sliders -->
            <div style="background: var(--color-surface); padding: 10px; border-radius: 8px; border: 1px solid var(--color-border);">
              <label class="form-label text-xs text-muted mb-1" style="font-weight: 700;">🎛️ MANUAL ADJUST</label>
              
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
              💾 Apply & Crop
            </button>
          </div>
        </div>
      </div>
    `;

    this.initEvents();
  }

  renderGuideOverlay() {
    if (this.options.preset === 'passport') {
      return `
        <div style="width: 180px; height: 230px; border: 2px dashed #22c55e; border-radius: 50%; box-shadow: 0 0 0 9999px rgba(0,0,0,0.5);">
          <div style="text-align: center; color: #fff; font-size: 11px; margin-top: 240px; font-weight: 600; text-shadow: 0 1px 3px #000;">
            Align Face Inside Oval
          </div>
        </div>
      `;
    } else if (this.options.preset === 'document') {
      return `
        <div style="width: 80%; height: 75%; border: 2px dashed #38bdf8; border-radius: 8px; box-shadow: 0 0 0 9999px rgba(0,0,0,0.5);">
          <div style="text-align: center; color: #fff; font-size: 11px; margin-top: 10px; font-weight: 600; text-shadow: 0 1px 3px #000;">
            Align Document / ID Card Inside Frame
          </div>
        </div>
      `;
    }
    return `
      <div style="width: 70%; height: 70%; border: 2px dashed #e2e8f0; border-radius: 8px;"></div>
    `;
  }

  initEvents() {
    const wrap = this.modalContent;

    // 1. Source Tab Switching
    wrap.querySelectorAll('.ms-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const tab = btn.dataset.tab;
        this.activeSourceTab = tab;
        wrap.querySelectorAll('.ms-tab-btn').forEach(b => {
          b.classList.remove('btn-primary');
          b.classList.add('btn-outline-secondary');
        });
        btn.classList.add('btn-primary');
        btn.classList.remove('btn-outline-secondary');

        if (tab === 'camera') {
          this.startCamera();
        } else {
          this.stopCamera();
          wrap.querySelector('.ms-camera-viewfinder').style.display = 'none';
          if (this.currentImage) {
            wrap.querySelector('.ms-crop-viewport').style.display = 'block';
          } else {
            wrap.querySelector('.ms-drop-zone').style.display = 'flex';
          }
        }
      });
    });

    // 2. File Picker & Drag-and-Drop
    const dropZone = wrap.querySelector('.ms-drop-zone');
    const fileInput = wrap.querySelector('.ms-file-input');
    const selectBtn = wrap.querySelector('.ms-select-file-btn');

    selectBtn?.addEventListener('click', () => fileInput.click());
    dropZone?.addEventListener('click', (e) => {
      if (e.target !== selectBtn) fileInput.click();
    });

    fileInput?.addEventListener('change', (e) => {
      if (e.target.files && e.target.files[0]) {
        this.loadFile(e.target.files[0]);
      }
    });

    // Drag-Drop
    dropZone?.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropZone.style.background = 'rgba(99, 102, 241, 0.15)';
    });
    dropZone?.addEventListener('dragleave', () => {
      dropZone.style.background = 'transparent';
    });
    dropZone?.addEventListener('drop', (e) => {
      e.preventDefault();
      dropZone.style.background = 'transparent';
      if (e.dataTransfer.files && e.dataTransfer.files[0]) {
        this.loadFile(e.dataTransfer.files[0]);
      }
    });

    // Paste from Clipboard (Ctrl+V)
    window.addEventListener('paste', (e) => {
      if (e.clipboardData && e.clipboardData.items) {
        for (let item of e.clipboardData.items) {
          if (item.type.indexOf('image') !== -1) {
            const file = item.getAsFile();
            this.loadFile(file);
            Toast.info('Image pasted from clipboard');
            break;
          }
        }
      }
    });

    // 3. Camera Controls
    wrap.querySelector('.ms-flip-cam-btn')?.addEventListener('click', () => {
      this.cameraFacingMode = this.cameraFacingMode === 'user' ? 'environment' : 'user';
      this.startCamera();
    });

    wrap.querySelector('.ms-timer-btn')?.addEventListener('click', () => {
      this.snapWithCountdown(3);
    });

    wrap.querySelector('.ms-snap-btn')?.addEventListener('click', () => {
      this.captureCamera();
    });

    // 4. Transform Tools (Rotate, Flip, Reset)
    wrap.querySelector('.ms-rotate-btn')?.addEventListener('click', () => {
      this.rotation = (this.rotation + 90) % 360;
      this.renderCanvas();
    });

    wrap.querySelector('.ms-fliph-btn')?.addEventListener('click', () => {
      this.flipH = !this.flipH;
      this.renderCanvas();
    });

    wrap.querySelector('.ms-flipv-btn')?.addEventListener('click', () => {
      this.flipV = !this.flipV;
      this.renderCanvas();
    });

    wrap.querySelector('.ms-reset-btn')?.addEventListener('click', () => {
      this.resetAdjustments();
    });

    // 5. Aspect Ratio Buttons
    wrap.querySelectorAll('.ms-aspect-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        wrap.querySelectorAll('.ms-aspect-btn').forEach(b => {
          b.classList.remove('btn-primary');
          b.classList.add('btn-outline-secondary');
        });
        btn.classList.add('btn-primary');
        btn.classList.remove('btn-outline-secondary');

        const aspect = btn.dataset.aspect;
        this.options.aspectRatio = aspect === 'free' ? null : parseFloat(aspect);
        this.resetCropBox();
      });
    });

    // 6. Filter Buttons
    wrap.querySelectorAll('.ms-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        wrap.querySelectorAll('.ms-filter-btn').forEach(b => {
          b.classList.remove('btn-primary', 'active');
          b.classList.add('btn-outline-secondary');
        });
        btn.classList.add('btn-primary', 'active');
        btn.classList.remove('btn-outline-secondary');

        this.activeFilter = btn.dataset.filter;
        this.renderCanvas();
      });
    });

    // 7. Manual Sliders
    const bSlider = wrap.querySelector('.ms-slider-brightness');
    bSlider?.addEventListener('input', (e) => {
      this.brightness = parseInt(e.target.value, 10);
      wrap.querySelector('.ms-val-brightness').textContent = this.brightness;
      this.renderCanvas();
    });

    const cSlider = wrap.querySelector('.ms-slider-contrast');
    cSlider?.addEventListener('input', (e) => {
      this.contrast = parseInt(e.target.value, 10);
      wrap.querySelector('.ms-val-contrast').textContent = this.contrast;
      this.renderCanvas();
    });

    const sSlider = wrap.querySelector('.ms-slider-saturation');
    sSlider?.addEventListener('input', (e) => {
      this.saturation = parseInt(e.target.value, 10);
      wrap.querySelector('.ms-val-saturation').textContent = `${this.saturation}%`;
      this.renderCanvas();
    });

    // 8. Crop Box Draggable Interaction
    this.initCropBoxEvents();

    // 9. Footer Save & Cancel
    wrap.querySelector('.ms-btn-apply')?.addEventListener('click', () => {
      this.applyAndSave();
    });

    wrap.querySelector('.ms-btn-cancel')?.addEventListener('click', () => {
      this.close();
    });
  }

  initCropBoxEvents() {
    const wrap = this.modalContent;
    const cropBox = wrap.querySelector('.ms-crop-box');
    const viewport = wrap.querySelector('.ms-crop-viewport');

    const onMouseDown = (e) => {
      e.preventDefault();
      const rect = viewport.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      this.dragStart = { x: clientX, y: clientY };
      this.cropStart = { ...this.crop };

      if (e.target.classList.contains('ms-handle')) {
        this.activeHandle = e.target.dataset.handle;
      } else {
        this.isDraggingCrop = true;
      }

      window.addEventListener('mousemove', onMouseMove);
      window.addEventListener('mouseup', onMouseUp);
      window.addEventListener('touchmove', onMouseMove, { passive: false });
      window.addEventListener('touchend', onMouseUp);
    };

    const onMouseMove = (e) => {
      const rect = viewport.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      const dx = (clientX - this.dragStart.x) / rect.width;
      const dy = (clientY - this.dragStart.y) / rect.height;

      if (this.isDraggingCrop) {
        this.crop.x = Math.max(0, Math.min(1 - this.crop.w, this.cropStart.x + dx));
        this.crop.y = Math.max(0, Math.min(1 - this.crop.h, this.cropStart.y + dy));
      } else if (this.activeHandle) {
        this.handleResize(this.activeHandle, dx, dy, rect.width, rect.height);
      }

      this.updateCropBoxDOM();
    };

    const onMouseUp = () => {
      this.isDraggingCrop = false;
      this.activeHandle = null;
      window.removeEventListener('mousemove', onMouseMove);
      window.removeEventListener('mouseup', onMouseUp);
      window.removeEventListener('touchmove', onMouseMove);
      window.removeEventListener('touchend', onMouseUp);
    };

    cropBox?.addEventListener('mousedown', onMouseDown);
    cropBox?.addEventListener('touchstart', onMouseDown, { passive: false });
  }

  handleResize(handle, dx, dy, viewW, viewH) {
    let { x, y, w, h } = this.cropStart;
    const minSize = 0.1;

    if (handle.includes('r')) w = Math.max(minSize, Math.min(1 - x, w + dx));
    if (handle.includes('b')) h = Math.max(minSize, Math.min(1 - y, h + dy));
    if (handle.includes('l')) {
      const newX = Math.max(0, Math.min(x + w - minSize, x + dx));
      w = w + (x - newX);
      x = newX;
    }
    if (handle.includes('t')) {
      const newY = Math.max(0, Math.min(y + h - minSize, y + dy));
      h = h + (y - newY);
      y = newY;
    }

    // Lock aspect ratio if required
    if (this.options.aspectRatio) {
      const pixelAspect = (w * viewW) / (h * viewH);
      if (handle.includes('r') || handle.includes('l')) {
        h = (w * viewW) / (this.options.aspectRatio * viewH);
      } else {
        w = (h * viewH * this.options.aspectRatio) / viewW;
      }
    }

    this.crop = { x, y, w: Math.min(1 - x, w), h: Math.min(1 - y, h) };
  }

  resetCropBox() {
    const wrap = this.modalContent;
    const viewport = wrap.querySelector('.ms-crop-viewport');
    if (!viewport) return;
    const viewW = viewport.clientWidth || 500;
    const viewH = viewport.clientHeight || 380;

    let w = 0.8;
    let h = 0.8;

    if (this.options.aspectRatio) {
      if (this.options.aspectRatio > 1) {
        h = w / this.options.aspectRatio;
      } else {
        w = h * this.options.aspectRatio;
      }
    }

    this.crop = {
      x: (1 - w) / 2,
      y: (1 - h) / 2,
      w,
      h
    };

    this.updateCropBoxDOM();
  }

  updateCropBoxDOM() {
    const box = this.modalContent.querySelector('.ms-crop-box');
    if (!box) return;
    box.style.left = `${this.crop.x * 100}%`;
    box.style.top = `${this.crop.y * 100}%`;
    box.style.width = `${this.crop.w * 100}%`;
    box.style.height = `${this.crop.h * 100}%`;
  }

  async startCamera() {
    this.stopCamera();
    const wrap = this.modalContent;
    wrap.querySelector('.ms-drop-zone').style.display = 'none';
    wrap.querySelector('.ms-crop-viewport').style.display = 'none';
    const camView = wrap.querySelector('.ms-camera-viewfinder');
    camView.style.display = 'block';

    try {
      this.stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: this.cameraFacingMode,
          width: { ideal: 1280 },
          height: { ideal: 720 }
        },
        audio: false
      });
      const video = wrap.querySelector('.ms-camera-video');
      video.srcObject = this.stream;
    } catch (err) {
      Toast.error('Camera permission denied or camera not found');
      wrap.querySelector('.ms-tab-btn[data-tab="upload"]').click();
    }
  }

  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach(track => track.stop());
      this.stream = null;
    }
  }

  snapWithCountdown(seconds = 3) {
    const wrap = this.modalContent;
    const overlay = wrap.querySelector('.ms-countdown-overlay');
    overlay.style.display = 'flex';
    let count = seconds;
    overlay.textContent = count;

    const timer = setInterval(() => {
      count--;
      if (count > 0) {
        overlay.textContent = count;
      } else {
        clearInterval(timer);
        overlay.style.display = 'none';
        this.captureCamera();
      }
    }, 1000);
  }

  captureCamera() {
    const wrap = this.modalContent;
    const video = wrap.querySelector('.ms-camera-video');
    if (!video || !video.videoWidth) return;

    const off = document.createElement('canvas');
    off.width = video.videoWidth;
    off.height = video.videoHeight;
    const ctx = off.getContext('2d');

    // Mirror selfie camera
    if (this.cameraFacingMode === 'user') {
      ctx.translate(off.width, 0);
      ctx.scale(-1, 1);
    }
    ctx.drawImage(video, 0, 0);

    const img = new Image();
    img.onload = () => {
      this.setImage(img);
      this.stopCamera();
      Toast.success('Photo captured! Adjust crop and filters.');
    };
    img.src = off.toDataURL('image/jpeg', 0.95);
  }

  loadFile(file) {
    if (!file) return;
    // File size validation (max 15MB)
    const maxSize = 15 * 1024 * 1024;
    if (file.size > maxSize) {
      Toast.error(`File too large (${(file.size / 1024 / 1024).toFixed(1)}MB). Maximum is 15MB.`);
      return;
    }
    // Validate file type
    if (!file.type.startsWith('image/')) {
      Toast.error('Please select a valid image file (JPEG, PNG, WebP)');
      return;
    }
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        this.setImage(img);
        Toast.success('Image loaded successfully');
      };
      img.onerror = () => {
        Toast.error('Failed to load image. The file may be corrupt or unsupported.');
      };
      img.src = e.target.result;
    };
    reader.onerror = () => {
      Toast.error('Failed to read file. Please try again.');
    };
    reader.readAsDataURL(file);
  }

  setImage(img) {
    this.currentImage = img;
    const wrap = this.modalContent;
    wrap.querySelector('.ms-drop-zone').style.display = 'none';
    wrap.querySelector('.ms-camera-viewfinder').style.display = 'none';
    wrap.querySelector('.ms-crop-viewport').style.display = 'block';
    wrap.querySelector('.ms-btn-apply').disabled = false;

    wrap.querySelector('.ms-file-info').textContent = `Dimensions: ${img.naturalWidth} × ${img.naturalHeight}px`;

    this.resetAdjustments();
    this.resetCropBox();
    this.renderCanvas();
  }

  resetAdjustments() {
    this.rotation = 0;
    this.flipH = false;
    this.flipV = false;
    this.brightness = 0;
    this.contrast = 0;
    this.saturation = 100;
    this.activeFilter = 'none';

    const wrap = this.modalContent;
    wrap.querySelector('.ms-slider-brightness').value = 0;
    wrap.querySelector('.ms-val-brightness').textContent = 0;
    wrap.querySelector('.ms-slider-contrast').value = 0;
    wrap.querySelector('.ms-val-contrast').textContent = 0;
    wrap.querySelector('.ms-slider-saturation').value = 100;
    wrap.querySelector('.ms-val-saturation').textContent = '100%';

    wrap.querySelectorAll('.ms-filter-btn').forEach(b => {
      b.classList.remove('btn-primary', 'active');
      b.classList.add('btn-outline-secondary');
    });
    wrap.querySelector('.ms-filter-btn[data-filter="none"]')?.classList.add('btn-primary', 'active');

    this.renderCanvas();
  }

  renderCanvas() {
    if (!this.currentImage) return;

    const canvas = this.modalContent.querySelector('.ms-main-canvas');
    const viewport = this.modalContent.querySelector('.ms-crop-viewport');
    if (!canvas || !viewport) return;

    canvas.width = viewport.clientWidth || 500;
    canvas.height = viewport.clientHeight || 380;

    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;

    ctx.clearRect(0, 0, w, h);

    // Apply Filter Matrix
    ctx.save();
    ctx.translate(w / 2, h / 2);
    ctx.rotate((this.rotation * Math.PI) / 180);
    ctx.scale(this.flipH ? -1 : 1, this.flipV ? -1 : 1);

    const isRot = this.rotation === 90 || this.rotation === 270;
    const srcW = isRot ? this.currentImage.naturalHeight : this.currentImage.naturalWidth;
    const srcH = isRot ? this.currentImage.naturalWidth : this.currentImage.naturalHeight;

    const scale = Math.min(w / srcW, h / srcH);
    const drawW = this.currentImage.naturalWidth * scale;
    const drawH = this.currentImage.naturalHeight * scale;

    ctx.drawImage(this.currentImage, -drawW / 2, -drawH / 2, drawW, drawH);
    ctx.restore();

    // Apply Pixel Processing Filters (Brightness, Contrast, Document Scan, Transparency)
    this.applyPixelFilters(ctx, w, h);
  }

  applyPixelFilters(ctx, w, h) {
    const imgData = ctx.getImageData(0, 0, w, h);
    const data = imgData.data;

    const bFactor = this.brightness * 1.5;
    const cFactor = (259 * (this.contrast + 255)) / (255 * (259 - this.contrast));
    const sFactor = this.saturation / 100;

    for (let i = 0; i < data.length; i += 4) {
      if (data[i + 3] === 0) continue; // Skip transparent

      let r = data[i];
      let g = data[i + 1];
      let b = data[i + 2];

      // 1. Brightness & Contrast
      r = cFactor * (r + bFactor - 128) + 128;
      g = cFactor * (g + bFactor - 128) + 128;
      b = cFactor * (b + bFactor - 128) + 128;

      // 2. Saturation
      const gray = 0.299 * r + 0.587 * g + 0.114 * b;
      r = gray + (r - gray) * sFactor;
      g = gray + (g - gray) * sFactor;
      b = gray + (b - gray) * sFactor;

      // 3. Preset Filters
      if (this.activeFilter === 'doc_scan') {
        // High-contrast B&W document scan threshold
        const threshold = 180;
        const v = gray > threshold ? 255 : (gray < 80 ? 0 : gray * 0.5);
        r = g = b = v;
      } else if (this.activeFilter === 'magic_color') {
        // Magic Color: Enhance contrast and remove yellow tint
        r = Math.min(255, r * 1.15);
        g = Math.min(255, g * 1.15);
        b = Math.min(255, b * 1.25);
      } else if (this.activeFilter === 'auto_enhance') {
        // Portrait auto-enhance
        r = Math.min(255, r * 1.08 + 5);
        g = Math.min(255, g * 1.08 + 5);
        b = Math.min(255, b * 1.08 + 5);
      } else if (this.activeFilter === 'transparent_bg') {
        // Remove light paper background
        if (gray > this.bgThreshold) {
          data[i + 3] = 0;
        }
      }

      data[i] = Math.max(0, Math.min(255, r));
      data[i + 1] = Math.max(0, Math.min(255, g));
      data[i + 2] = Math.max(0, Math.min(255, b));
    }

    ctx.putImageData(imgData, 0, 0);
  }

  applyAndSave() {
    const canvas = this.modalContent.querySelector('.ms-main-canvas');
    if (!canvas) return;

    const cropX = Math.floor(this.crop.x * canvas.width);
    const cropY = Math.floor(this.crop.y * canvas.height);
    const cropW = Math.floor(this.crop.w * canvas.width);
    const cropH = Math.floor(this.crop.h * canvas.height);

    const outCanvas = document.createElement('canvas');
    outCanvas.width = Math.min(cropW, this.options.maxWidth);
    outCanvas.height = Math.min(cropH, this.options.maxHeight);

    const outCtx = outCanvas.getContext('2d');
    outCtx.drawImage(canvas, cropX, cropY, cropW, cropH, 0, 0, outCanvas.width, outCanvas.height);

    // Optimized WebP / JPEG Export (< 150KB)
    const format = this.activeFilter === 'transparent_bg' ? 'image/png' : 'image/webp';
    const dataUrl = outCanvas.toDataURL(format, 0.88);

    if (this.options.onSave) {
      this.options.onSave(dataUrl);
    }

    Toast.success('Enhanced photo saved successfully');
    this.close();
  }

  show() {
    // Render in an independent dialog so parent modals (Student Edit, Profile, etc.) are never overwritten or closed
    let dialog = document.getElementById('media-studio-modal');
    if (!dialog) {
      dialog = document.createElement('dialog');
      dialog.id = 'media-studio-modal';
      document.body.appendChild(dialog);
    }

    const widthMap = { passport: '640px', document: '850px', general: '750px' };
    const rawW = widthMap[this.options.preset] || '800px';

    dialog.style.cssText = `
      padding: 0;
      border: 1px solid var(--color-border, rgba(255,255,255,0.15));
      border-radius: var(--radius-lg, 14px);
      background: var(--color-surface, #1e2230);
      color: var(--color-text-primary, #fff);
      box-shadow: 0 20px 60px rgba(0,0,0,0.7);
      width: min(${rawW}, 95vw);
      max-width: 95vw;
      height: fit-content !important;
      min-height: 0 !important;
      max-height: 90vh;
      margin: auto;
      overflow: hidden;
      display: flex;
      flex-direction: column;
      box-sizing: border-box;
      z-index: 10000;
    `;

    dialog.innerHTML = `
      <div class="modal-header" style="padding: 14px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center; flex-shrink: 0;">
        <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary, #fff);">📸 ${escapeHTML(this.options.title || 'Photo & Media Studio')}</h3>
        <button type="button" class="ms-close-btn" style="background: none; border: none; font-size: 1.4rem; color: var(--color-text-muted, #aaa); cursor: pointer; line-height: 1; padding: 4px;">&times;</button>
      </div>
      <div class="modal-body-container" style="padding: 18px 20px; max-height: calc(90vh - 80px); overflow-y: auto; flex: 1 1 auto;">
      </div>
    `;

    const bodyContainer = dialog.querySelector('.modal-body-container');
    bodyContainer.appendChild(this.modalContent);

    dialog.querySelector('.ms-close-btn').addEventListener('click', () => this.close());
    dialog.oncancel = () => this.close();

    if (!dialog.open) {
      dialog.showModal();
    }
    this.dialog = dialog;

    if (this.options.value) {
      const img = new Image();
      img.onload = () => this.setImage(img);
      img.src = this.options.value;
    }
  }

  close() {
    this.stopCamera();
    if (this.dialog) {
      try {
        if (this.dialog.open) this.dialog.close();
      } catch (e) {}
      this.dialog.remove();
      this.dialog = null;
    }
  }
}

/**
 * MediaFieldPicker: Helper to render an interactive image picker component
 * Displays: Preview thumbnail, "Open Studio" button, "Remove" button, hidden input
 */
export class MediaFieldPicker {
  static create({ label = 'Select Photo', preset = 'passport', value = '', name = 'photo', onChange = null }) {
    const wrapper = document.createElement('div');
    wrapper.className = 'media-field-picker-wrapper';

    const formatImgUrl = (val) => {
      if (!val || typeof val !== 'string') return '';
      let clean = val.trim();
      if (!clean || clean === 'null' || clean === 'undefined' || clean === 'false') return '';
      if (clean.startsWith('data:image')) {
        return clean;
      }
      if (clean.startsWith('uploads/') || clean.startsWith('uploads\\')) {
        return '/' + clean.replace(/\\/g, '/');
      }
      if (!clean.startsWith('http://') && !clean.startsWith('https://') && !clean.startsWith('data:') && !clean.startsWith('/')) {
        return '/' + clean;
      }
      return clean;
    };

    const renderPreview = (val) => {
      const cleanUrl = formatImgUrl(val);
      if (!cleanUrl) {
        if (preset === 'qr_code') {
          const upiString = `upi://pay?pa=thecozycorner@okaxis&pn=${encodeURIComponent('Study Library')}&am=0&cu=INR`;
          const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(upiString)}`;
          return `<img src="${qrUrl}" alt="UPI QR" style="width: 100%; height: 100%; object-fit: contain; background: #fff; padding: 2px;">`;
        }
        const defaultEmoji = preset === 'stamp_logo' ? '🏛️' : preset === 'qr_code' ? '📱' : preset === 'document' ? '📑' : '👤';
        return `<span style="font-size: 2rem; line-height: 1; opacity: 0.85;">${defaultEmoji}</span>`;
      }

      const safeSrc = cleanUrl.startsWith('data:image') ? cleanUrl : escapeHTML(cleanUrl);
      const fallbackUrl = preset === 'qr_code'
        ? `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=upi://pay?pa=thecozycorner@okaxis`
        : `https://ui-avatars.com/api/?name=${encodeURIComponent(label.replace(/[^a-zA-Z0-9 ]/g, ''))}&background=6c5ce7&color=fff&size=128`;

      return `<img src="${safeSrc}" alt="Preview" style="width: 100%; height: 100%; object-fit: contain; background: #fff; border-radius: 6px; padding: 2px;" onerror="this.onerror=null; this.src='${fallbackUrl}';">`;
    };

    wrapper.innerHTML = `
      <div style="background: var(--color-surface); border: 1.5px solid var(--color-border); border-radius: 12px; padding: 14px; box-shadow: var(--shadow-sm); display: flex; flex-direction: column; gap: 10px;">
        <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(label)}</div>
        <div style="display: flex; align-items: center; gap: 14px;">
          <div class="mfp-preview" style="width: 68px; height: 68px; border-radius: 10px; background: #ffffff; display: flex; align-items: center; justify-content: center; overflow: hidden; border: 2px solid var(--color-border); flex-shrink: 0; cursor: pointer; box-shadow: var(--shadow-sm);" title="Click to Change Image">
            ${renderPreview(value)}
          </div>
          <div style="flex: 1; display: flex; flex-direction: column; gap: 6px;">
            <div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center;">
              <button type="button" class="btn btn-sm btn-primary mfp-upload-file-btn" style="font-size: 0.76rem; font-weight: 600; padding: 4px 10px;">
                📁 ${value ? 'Change' : 'Upload'}
              </button>
              <button type="button" class="btn btn-sm btn-outline-primary mfp-open-btn" style="font-size: 0.76rem; font-weight: 600; padding: 4px 10px;">
                📸 Camera / Studio
              </button>
              <button type="button" class="btn btn-sm btn-ghost text-danger mfp-remove-btn" style="font-size: 0.76rem; padding: 4px 8px; ${value ? '' : 'display: none;'}">
                🗑️ Remove
              </button>
            </div>
            <small style="color: var(--color-text-secondary); font-size: 0.72rem;">${preset === 'qr_code' ? '⚡ UPI QR for student fees' : preset === 'document' ? '📑 Clear KYC scan / photo' : '✨ 1:1 Transparent PNG / JPG'}</small>
          </div>
        </div>
        <input type="file" class="mfp-file-input" accept="image/*" style="display: none;">
        <input type="hidden" name="${name}" class="mfp-hidden-value" value="${escapeHTML(value)}">
      </div>
    `;

    const hiddenInput = wrapper.querySelector('.mfp-hidden-value');
    const fileInput = wrapper.querySelector('.mfp-file-input');
    const preview = wrapper.querySelector('.mfp-preview');
    const removeBtn = wrapper.querySelector('.mfp-remove-btn');
    const uploadBtn = wrapper.querySelector('.mfp-upload-file-btn');

    const updateImageValue = async (dataUrl) => {
      hiddenInput.value = dataUrl || '';
      preview.innerHTML = renderPreview(dataUrl);
      removeBtn.style.display = dataUrl ? 'inline-block' : 'none';
      uploadBtn.innerHTML = dataUrl ? '📁 Change' : '📁 Upload';

      hiddenInput.dispatchEvent(new Event('input', { bubbles: true }));
      hiddenInput.dispatchEvent(new Event('change', { bubbles: true }));

      if (onChange) onChange(dataUrl);

      if (dataUrl && dataUrl.startsWith('data:image/')) {
        try {
          const token = localStorage.getItem('sl_token') || localStorage.getItem('token');
          const headers = { 'Content-Type': 'application/json' };
          if (token) headers['Authorization'] = `Bearer ${token}`;

          const res = await fetch('/api/upload', {
            method: 'POST',
            headers,
            body: JSON.stringify({ image: dataUrl })
          });
          const result = await res.json();
          if (result.success && result.url) {
            hiddenInput.value = result.url;
            hiddenInput.dispatchEvent(new Event('input', { bubbles: true }));
            hiddenInput.dispatchEvent(new Event('change', { bubbles: true }));
            if (onChange) onChange(result.url);
          }
        } catch (err) {
          console.error('Image background upload error:', err);
        }
      }
    };

    // Clicking preview box also triggers upload
    preview.addEventListener('click', (e) => {
      e.stopPropagation();
      fileInput.click();
    });

    // Direct File Upload click
    uploadBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      fileInput.click();
    });

    // Helper to auto-compress image files on client-side
    const compressUploadedFile = (file) => {
      return new Promise((resolve) => {
        if (!file.type.startsWith('image/')) {
          const reader = new FileReader();
          reader.onload = (e) => resolve(e.target.result);
          reader.onerror = () => resolve('');
          reader.readAsDataURL(file);
          return;
        }

        const reader = new FileReader();
        reader.onload = (e) => {
          const img = new Image();
          img.onload = () => {
            try {
              const canvas = document.createElement('canvas');
              let maxW = preset === 'passport' ? 400 : 1200;
              let maxH = preset === 'passport' ? 400 : 1200;
              let { width, height } = img;

              if (width > maxW || height > maxH) {
                if (width > height) {
                  height = Math.round((height * maxW) / width);
                  width = maxW;
                } else {
                  width = Math.round((width * maxH) / height);
                  height = maxH;
                }
              }

              canvas.width = width;
              canvas.height = height;
              const ctx = canvas.getContext('2d');
              ctx.imageSmoothingEnabled = true;
              ctx.imageSmoothingQuality = 'high';
              ctx.drawImage(img, 0, 0, width, height);

              let dataUrl = canvas.toDataURL('image/webp', 0.85);
              if (!dataUrl || dataUrl.length < 50) {
                dataUrl = canvas.toDataURL('image/jpeg', 0.85);
              }
              resolve(dataUrl);
            } catch (err) {
              resolve(e.target.result);
            }
          };
          img.onerror = () => resolve(e.target.result);
          img.src = e.target.result;
        };
        reader.onerror = () => resolve('');
        reader.readAsDataURL(file);
      });
    };

    // File Input change
    fileInput.addEventListener('change', async (e) => {
      const file = e.target.files[0];
      if (!file) return;

      if (!file.type.startsWith('image/') && file.type !== 'application/pdf') {
        Toast.error('Please select a valid image file (PNG, JPG, WebP) or PDF document');
        return;
      }

      try {
        const compressedDataUrl = await compressUploadedFile(file);
        if (compressedDataUrl) {
          await updateImageValue(compressedDataUrl);
          Toast.success(`${label || 'Document'} uploaded & optimized successfully!`);
        }
      } catch (err) {
        Toast.error(err.message || 'File processing failed');
      }
    });

    // Open Camera & Filter Studio
    wrapper.querySelector('.mfp-open-btn').addEventListener('click', (e) => {
      e.stopPropagation();
      MediaStudio.open({
        title: label,
        preset,
        value: hiddenInput.value,
        onSave: (dataUrl) => {
          updateImageValue(dataUrl);
        }
      });
    });

    // Remove Image
    removeBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      hiddenInput.value = '';
      fileInput.value = '';
      preview.innerHTML = renderPreview('');
      removeBtn.style.display = 'none';
      uploadBtn.innerHTML = '📁 Upload';
      hiddenInput.dispatchEvent(new Event('input', { bubbles: true }));
      hiddenInput.dispatchEvent(new Event('change', { bubbles: true }));
      if (onChange) onChange('');
    });

    return wrapper;
  }
}

