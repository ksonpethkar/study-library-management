import { escapeHTML, Toast } from './ui.js';

/**
 * Smart Signature Studio Component
 * Supports:
 * 1. Interactive Drawing Pad (Touch / Stylus / Mouse with Bezier curve smoothing)
 * 2. Upload Photo of Handwritten Signature with Smart Auto-Crop & Paper Background Removal
 * 3. Type to Sign with authentic script handwriting fonts
 * 4. High-Res Transparent PNG Export
 */
export class SignatureStudio {
  constructor(container, options = {}) {
    this.container = typeof container === 'string' ? document.querySelector(container) : container;
    this.options = {
      value: options.value || '',
      onChange: options.onChange || null,
      width: options.width || 440,
      height: options.height || 160,
      penColor: options.penColor || '#1e40af', // Royal Blue default
      penWidth: options.penWidth || 2.5,
      ...options
    };

    this.activeTab = 'draw'; // 'draw' | 'upload' | 'type'
    this.history = [];
    this.historyIndex = -1;
    this.rotation = 0;
    this.threshold = 210; // Default paper removal threshold (0-255)
    this.originalUploadedImage = null;

    this.render();
  }

  render() {
    if (!this.container) return;

    this.container.innerHTML = `
      <div class="signature-studio-wrapper" style="border: 1px solid var(--color-border); border-radius: var(--radius-lg, 12px); background: var(--color-surface); overflow: hidden; box-shadow: var(--shadow-sm);">
        <!-- Mode Tabs -->
        <div class="sig-tabs" style="display: flex; border-bottom: 1px solid var(--color-divider); background: var(--color-bg-secondary);">
          <button type="button" class="sig-tab-btn active" data-tab="draw" style="flex: 1; padding: 10px 14px; border: none; background: transparent; font-weight: 600; font-size: 0.85rem; cursor: pointer; color: var(--color-text-primary); border-bottom: 2px solid var(--color-primary); transition: all 0.2s;">
            ✍️ Draw Signature
          </button>
          <button type="button" class="sig-tab-btn" data-tab="upload" style="flex: 1; padding: 10px 14px; border: none; background: transparent; font-weight: 600; font-size: 0.85rem; cursor: pointer; color: var(--color-text-muted); border-bottom: 2px solid transparent; transition: all 0.2s;">
            📷 Upload & Auto-Enhance
          </button>
          <button type="button" class="sig-tab-btn" data-tab="type" style="flex: 1; padding: 10px 14px; border: none; background: transparent; font-weight: 600; font-size: 0.85rem; cursor: pointer; color: var(--color-text-muted); border-bottom: 2px solid transparent; transition: all 0.2s;">
            ⌨️ Type to Sign
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
              <button type="button" class="btn btn-sm btn-ghost sig-undo-btn" title="Undo" style="padding: 2px 6px; font-size: 0.8rem;">↩️ Undo</button>
              <button type="button" class="btn btn-sm btn-ghost sig-clear-btn text-danger" title="Clear Pad" style="padding: 2px 6px; font-size: 0.8rem;">🧹 Clear</button>
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
            <div style="font-size: 32px; margin-bottom: 4px;">📸</div>
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
                  ✂️ Smart Auto-Crop
                </button>
                <button type="button" class="btn btn-sm btn-outline-secondary sig-rotate-btn" title="Rotate 90°" style="font-size: 0.75rem;">
                  🔄 Rotate
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
            <input type="text" class="form-control sig-type-input" placeholder="e.g. Rahul Sharma" value="${this.options.studentName || ''}">
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
            <span class="badge badge-success" style="font-size: 0.65rem;">✓ Transparent PNG</span>
            <span class="text-muted sig-status-text">Signature captured cleanly</span>
          </div>
          <button type="button" class="btn btn-sm btn-ghost sig-preview-modal-btn text-primary" style="padding: 2px 8px; font-size: 0.75rem;">
            🔍 Live Preview
          </button>
        </div>
      </div>
    `;

    this.initEvents();
    if (this.options.value) {
      this.loadExistingValue(this.options.value);
    }
  }

  initEvents() {
    const wrap = this.container;

    // 1. Tab Switching
    wrap.querySelectorAll('.sig-tab-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        wrap.querySelectorAll('.sig-tab-btn').forEach(b => {
          b.classList.remove('active');
          b.style.color = 'var(--color-text-muted)';
          b.style.borderBottomColor = 'transparent';
        });
        btn.classList.add('active');
        btn.style.color = 'var(--color-text-primary)';
        btn.style.borderBottomColor = 'var(--color-primary)';

        const tab = btn.dataset.tab;
        this.activeTab = tab;
        wrap.querySelectorAll('.sig-panel').forEach(p => p.style.display = 'none');
        wrap.querySelector(`.sig-panel-${tab}`).style.display = 'block';

        if (tab === 'type') {
          this.updateTypeCanvas();
        }
      });
    });

    // 2. Setup Drawing Canvas
    this.canvas = wrap.querySelector('.sig-draw-canvas');
    this.ctx = this.canvas.getContext('2d');
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    this.ctx.strokeStyle = this.options.penColor;
    this.ctx.lineWidth = this.options.penWidth;

    let isDrawing = false;
    let points = [];

    const getCanvasPos = (e) => {
      const rect = this.canvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      const scaleX = this.canvas.width / rect.width;
      const scaleY = this.canvas.height / rect.height;
      return {
        x: (clientX - rect.left) * scaleX,
        y: (clientY - rect.top) * scaleY
      };
    };

    const startDraw = (e) => {
      e.preventDefault();
      isDrawing = true;
      const pos = getCanvasPos(e);
      points = [pos];
      this.ctx.beginPath();
      this.ctx.moveTo(pos.x, pos.y);
    };

    const draw = (e) => {
      if (!isDrawing) return;
      e.preventDefault();
      const pos = getCanvasPos(e);
      points.push(pos);

      // Bezier curve smoothing for natural pen strokes
      if (points.length > 2) {
        const lastTwo = points.slice(-2);
        const xc = (lastTwo[0].x + lastTwo[1].x) / 2;
        const yc = (lastTwo[0].y + lastTwo[1].y) / 2;
        this.ctx.quadraticCurveTo(lastTwo[0].x, lastTwo[0].y, xc, yc);
        this.ctx.stroke();
      } else {
        this.ctx.lineTo(pos.x, pos.y);
        this.ctx.stroke();
      }
    };

    const stopDraw = () => {
      if (isDrawing) {
        isDrawing = false;
        this.saveHistory();
        this.emitChange();
      }
    };

    this.canvas.addEventListener('mousedown', startDraw);
    this.canvas.addEventListener('mousemove', draw);
    window.addEventListener('mouseup', stopDraw);

    this.canvas.addEventListener('touchstart', startDraw, { passive: false });
    this.canvas.addEventListener('touchmove', draw, { passive: false });
    window.addEventListener('touchend', stopDraw);

    // Ink Color buttons
    wrap.querySelectorAll('.sig-color-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        wrap.querySelectorAll('.sig-color-btn').forEach(b => {
          b.style.boxShadow = 'none';
          b.style.borderColor = 'transparent';
        });
        btn.style.boxShadow = `0 0 0 2px ${btn.dataset.color}`;
        btn.style.borderColor = '#fff';
        this.options.penColor = btn.dataset.color;
        this.ctx.strokeStyle = this.options.penColor;
      });
    });

    // Pen Width buttons
    wrap.querySelectorAll('.sig-width-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        wrap.querySelectorAll('.sig-width-btn').forEach(b => {
          b.classList.remove('btn-primary');
          b.classList.add('btn-ghost');
        });
        btn.classList.add('btn-primary');
        btn.classList.remove('btn-ghost');
        this.options.penWidth = parseFloat(btn.dataset.width);
        this.ctx.lineWidth = this.options.penWidth;
      });
    });

    // Undo & Clear
    wrap.querySelector('.sig-undo-btn')?.addEventListener('click', () => this.undo());
    wrap.querySelector('.sig-clear-btn')?.addEventListener('click', () => this.clear());

    // 3. Upload & Enhance Events
    const dropzone = wrap.querySelector('.sig-dropzone');
    const fileInput = wrap.querySelector('.sig-file-input');
    const browseBtn = wrap.querySelector('.sig-browse-btn');

    browseBtn?.addEventListener('click', () => fileInput.click());
    dropzone?.addEventListener('click', (e) => {
      if (e.target !== browseBtn) fileInput.click();
    });

    fileInput?.addEventListener('change', (e) => {
      if (e.target.files && e.target.files[0]) {
        this.handleFileUpload(e.target.files[0]);
      }
    });

    // Drag & Drop
    dropzone?.addEventListener('dragover', (e) => {
      e.preventDefault();
      dropzone.style.borderColor = '#22c55e';
      dropzone.style.background = 'rgba(34, 197, 94, 0.08)';
    });
    dropzone?.addEventListener('dragleave', () => {
      dropzone.style.borderColor = '#6366f1';
      dropzone.style.background = 'rgba(99, 102, 241, 0.04)';
    });
    dropzone?.addEventListener('drop', (e) => {
      e.preventDefault();
      dropzone.style.borderColor = '#6366f1';
      dropzone.style.background = 'rgba(99, 102, 241, 0.04)';
      if (e.dataTransfer.files && e.dataTransfer.files[0]) {
        this.handleFileUpload(e.dataTransfer.files[0]);
      }
    });

    // Threshold Slider
    const thresholdSlider = wrap.querySelector('.sig-threshold-slider');
    thresholdSlider?.addEventListener('input', (e) => {
      this.threshold = parseInt(e.target.value, 10);
      wrap.querySelector('.sig-threshold-val').textContent = this.threshold;
      this.processUploadedImage();
    });

    // Rotate Button
    wrap.querySelector('.sig-rotate-btn')?.addEventListener('click', () => {
      this.rotation = (this.rotation + 90) % 360;
      this.processUploadedImage();
    });

    // Auto-Trim Button
    wrap.querySelector('.sig-autotrim-btn')?.addEventListener('click', () => {
      this.autoCropEnhanceCanvas();
      Toast.success('Signature auto-cropped tightly');
    });

    // 4. Type to Sign Events
    const typeInput = wrap.querySelector('.sig-type-input');
    typeInput?.addEventListener('input', () => {
      const name = typeInput.value.trim() || 'Your Name';
      wrap.querySelectorAll('.sig-font-text').forEach(el => el.textContent = name);
      this.updateTypeCanvas();
    });

    wrap.querySelectorAll('.sig-font-card').forEach(card => {
      card.addEventListener('click', () => {
        wrap.querySelectorAll('.sig-font-card').forEach(c => {
          c.classList.remove('selected');
          c.style.borderColor = 'var(--color-border)';
        });
        card.classList.add('selected');
        card.style.borderColor = 'var(--color-primary)';
        this.selectedFont = card.dataset.font;
        this.updateTypeCanvas();
      });
    });

    // Save initial state
    this.saveHistory();
  }

  saveHistory() {
    if (!this.canvas) return;
    this.history = this.history.slice(0, this.historyIndex + 1);
    this.history.push(this.canvas.toDataURL());
    this.historyIndex++;
  }

  undo() {
    if (this.historyIndex > 0) {
      this.historyIndex--;
      const img = new Image();
      img.onload = () => {
        this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
        this.ctx.drawImage(img, 0, 0);
        this.emitChange();
      };
      img.src = this.history[this.historyIndex];
    } else if (this.historyIndex === 0) {
      this.clear();
    }
  }

  clear() {
    if (this.canvas) {
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      this.history = [];
      this.historyIndex = -1;
      this.saveHistory();
      this.emitChange();
    }
  }

  handleFileUpload(file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      const img = new Image();
      img.onload = () => {
        this.originalUploadedImage = img;
        this.container.querySelector('.sig-upload-controls').style.display = 'block';
        this.processUploadedImage();
      };
      img.src = e.target.result;
    };
    reader.readAsDataURL(file);
  }

  /**
   * Smart Paper Background Removal & Binarization Algorithm
   */
  processUploadedImage() {
    if (!this.originalUploadedImage) return;

    const enhanceCanvas = this.container.querySelector('.sig-enhance-canvas');
    if (!enhanceCanvas) return;
    const ctx = enhanceCanvas.getContext('2d');

    const w = enhanceCanvas.width;
    const h = enhanceCanvas.height;

    ctx.clearRect(0, 0, w, h);
    ctx.save();
    ctx.translate(w / 2, h / 2);
    ctx.rotate((this.rotation * Math.PI) / 180);

    // Scale to fit canvas
    const img = this.originalUploadedImage;
    const isRotated = this.rotation === 90 || this.rotation === 270;
    const srcW = isRotated ? img.height : img.width;
    const srcH = isRotated ? img.width : img.height;
    const scale = Math.min((w * 0.9) / srcW, (h * 0.9) / srcH);

    ctx.drawImage(img, (-img.width * scale) / 2, (-img.height * scale) / 2, img.width * scale, img.height * scale);
    ctx.restore();

    // Pixel manipulation for paper removal & ink darkening
    const imgData = ctx.getImageData(0, 0, w, h);
    const data = imgData.data;

    for (let i = 0; i < data.length; i += 4) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];
      const brightness = 0.299 * r + 0.587 * g + 0.114 * b; // Grayscale luminance

      if (brightness > this.threshold) {
        // Paper background -> Make 100% transparent
        data[i + 3] = 0;
      } else {
        // Signature Ink -> Convert to crisp Royal Blue or Deep Black
        const intensity = 1 - brightness / this.threshold;
        data[i] = 30;     // R
        data[i + 1] = 64;  // G
        data[i + 2] = 175; // B (Royal Blue)
        data[i + 3] = Math.min(255, Math.floor(intensity * 255 * 1.5)); // Alpha
      }
    }

    ctx.putImageData(imgData, 0, 0);
    this.emitChange();
  }

  /**
   * Auto-Crop: Detects bounding box of non-transparent signature pixels and crops tightly
   */
  autoCropEnhanceCanvas() {
    const canvas = this.activeTab === 'upload' ? this.container.querySelector('.sig-enhance-canvas') : this.canvas;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;

    const imgData = ctx.getImageData(0, 0, w, h);
    const data = imgData.data;

    let minX = w, minY = h, maxX = 0, maxY = 0;
    let found = false;

    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        const alpha = data[(y * w + x) * 4 + 3];
        if (alpha > 20) { // Non-transparent pixel
          found = true;
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (!found) return;

    // Add 10px margin
    const pad = 10;
    minX = Math.max(0, minX - pad);
    minY = Math.max(0, minY - pad);
    maxX = Math.min(w, maxX + pad);
    maxY = Math.min(h, maxY + pad);

    const cropW = maxX - minX;
    const cropH = maxY - minY;

    const croppedData = ctx.getImageData(minX, minY, cropW, cropH);

    ctx.clearRect(0, 0, w, h);
    // Center cropped signature onto canvas
    const targetX = (w - cropW) / 2;
    const targetY = (h - cropH) / 2;
    ctx.putImageData(croppedData, targetX, targetY);

    this.emitChange();
  }

  updateTypeCanvas() {
    const typeInput = this.container.querySelector('.sig-type-input');
    const name = typeInput?.value.trim() || 'Rahul Sharma';
    const font = this.selectedFont || 'Great Vibes';

    // Create offscreen canvas for type
    const off = document.createElement('canvas');
    off.width = this.options.width;
    off.height = this.options.height;
    const ctx = off.getContext('2d');

    ctx.font = `36px "${font}", cursive`;
    ctx.fillStyle = '#1e40af';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(name, off.width / 2, off.height / 2);

    this.typedDataUrl = off.toDataURL();
    this.emitChange();
  }

  getValue() {
    if (this.activeTab === 'upload') {
      const enhanceCanvas = this.container.querySelector('.sig-enhance-canvas');
      return enhanceCanvas ? enhanceCanvas.toDataURL() : '';
    } else if (this.activeTab === 'type') {
      return this.typedDataUrl || '';
    } else {
      if (!this.canvas || this.isCanvasBlank(this.canvas)) return '';
      return this.canvas.toDataURL();
    }
  }

  loadExistingValue(dataUrl) {
    if (!dataUrl || !this.canvas) return;
    const img = new Image();
    img.onload = () => {
      this.ctx.clearRect(0, 0, this.canvas.width, this.canvas.height);
      this.ctx.drawImage(img, 0, 0);
      this.saveHistory();
    };
    img.src = dataUrl;
  }

  isCanvasBlank(canvas) {
    const ctx = canvas.getContext('2d');
    const pixelBuffer = new Uint32Array(
      ctx.getImageData(0, 0, canvas.width, canvas.height).data.buffer
    );
    return !pixelBuffer.some(color => color !== 0);
  }

  emitChange() {
    const val = this.getValue();
    if (typeof this.options.onChange === 'function') {
      this.options.onChange(val);
    }
  }
}
