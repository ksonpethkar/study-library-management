import api from './api.js';
import { Toast, Modal, BottomSheet } from './ui.js';

const DEFAULT_MODULES = [
  { key: 'dashboard', href: '#/dashboard', label: 'Dashboard', icon: '📊', isEnabled: true },
  { key: 'students', href: '#/students', label: 'Students', icon: '🎓', isEnabled: true },
  { key: 'seats', href: '#/seats', label: 'Seats', icon: '🪑', isEnabled: true },
  { key: 'plans', href: '#/plans', label: 'Plans', icon: '📦', isEnabled: true },
  { key: 'lockers', href: '#/lockers', label: 'Lockers', icon: '🔐', isEnabled: true },
  { key: 'payments', href: '#/payments', label: 'Payments', icon: '💳', isEnabled: true },
  { key: 'attendance', href: '#/attendance', label: 'Attendance', icon: '📅', isEnabled: true },
  { key: 'shifts', href: '#/shifts', label: 'Shifts', icon: '⏰', isEnabled: true },
  { key: 'branches', href: '#/branches', label: 'Branches', icon: '🏢', isEnabled: false },
  { key: 'reports', href: '#/reports', label: 'Reports', icon: '📈', isEnabled: true },
  { key: 'expenses', href: '#/expenses', label: 'Expenses (P&L)', icon: '💸', isEnabled: true },
  { key: 'operations', href: '#/operations', label: 'Operations', icon: '⚙️', isEnabled: true },
  { key: 'trash', href: '#/trash', label: 'Recycle Bin', icon: '🗑️', isEnabled: true },
  { key: 'settings', href: '#/settings', label: 'Settings', icon: '🛠️', isEnabled: true },
  { key: 'profile', href: '#/profile', label: 'My Profile', icon: '👤', isEnabled: true }
];

const PRESETS = {
  default: {
    name: 'Standard Default',
    keys: ['dashboard', 'students', 'seats', 'plans', 'lockers', 'payments', 'attendance', 'shifts', 'reports', 'expenses', 'operations', 'trash', 'settings', 'profile']
  },
  frontdesk: {
    name: 'Front Desk Essential',
    keys: ['dashboard', 'students', 'seats', 'payments', 'attendance', 'settings', 'profile']
  },
  all: {
    name: 'All Modules Active',
    keys: ['dashboard', 'students', 'seats', 'plans', 'lockers', 'payments', 'attendance', 'shifts', 'branches', 'reports', 'expenses', 'operations', 'trash', 'settings', 'profile']
  }
};

const POPULAR_ICONS = ['📊', '🎓', '🪑', '📦', '🔐', '💳', '📅', '⏰', '🏢', '📈', '💸', '⚙️', '🗑️', '🛠️', '👤', '📚', '⚡', '💼', '📌', '🔔', '🏷️', '🎯'];

class SidebarCustomizer {
  constructor() {
    this.items = [];
    this.modalInstance = null;
    this.userRole = 'staff';
    this.saveScope = 'global'; // 'global' or 'personal'
  }

  async open() {
    try {
      const userRaw = localStorage.getItem('sl_user');
      if (userRaw) {
        const u = JSON.parse(userRaw);
        this.userRole = u.role || 'staff';
      }
    } catch (e) {}

    // Dynamic lazy-load Sortable if not already present
    if (typeof window !== 'undefined' && !window.Sortable) {
      try {
        const { loadSortable } = await import('./dragDrop.js');
        if (typeof loadSortable === 'function') await loadSortable();
      } catch (e) {}
    }

    await this.loadConfig();
    this.render();
  }

  async loadConfig() {
    try {
      // Try fetching all modules (including disabled) from backend
      const res = await api.get('/api/settings/sidebar/all');
      if (res && res.success && Array.isArray(res.data) && res.data.length > 0) {
        this.items = res.data.map((item, idx) => ({
          key: item.key,
          label: item.label || item.key,
          href: item.href || `#/${item.key}`,
          icon: this.formatIcon(item.icon, item.key),
          isEnabled: item.isEnabled !== false,
          order: item.order !== undefined ? item.order : idx + 1
        }));
      } else {
        // Fallback to active items
        const activeRes = await api.get('/api/settings/sidebar');
        if (activeRes && activeRes.success && Array.isArray(activeRes.data) && activeRes.data.length > 0) {
          const activeKeys = new Set(activeRes.data.map(i => i.key));
          const orderMap = new Map(activeRes.data.map((i, idx) => [i.key, idx + 1]));
          this.items = DEFAULT_MODULES.map(def => ({
            ...def,
            isEnabled: activeKeys.has(def.key),
            order: orderMap.get(def.key) || 99
          })).sort((a, b) => a.order - b.order);
        } else {
          this.items = JSON.parse(JSON.stringify(DEFAULT_MODULES));
        }
      }
    } catch (err) {
      console.warn('Could not fetch server sidebar, using defaults:', err.message);
      this.items = JSON.parse(JSON.stringify(DEFAULT_MODULES));
    }

    // Apply personal local overrides if present
    try {
      const personalOrder = localStorage.getItem('sl_sidebar_order_personal') || localStorage.getItem('sl_sidebar_order');
      if (personalOrder) {
        const orderArr = JSON.parse(personalOrder);
        if (Array.isArray(orderArr) && orderArr.length > 0) {
          const orderMap = new Map(orderArr.map((href, idx) => [href.replace('#/', ''), idx + 1]));
          this.items.forEach(item => {
            if (orderMap.has(item.key)) item.order = orderMap.get(item.key);
          });
          this.items.sort((a, b) => a.order - b.order);
        }
      }
    } catch (e) {}
  }

  formatIcon(icon, key) {
    if (!icon || icon.startsWith('<svg')) {
      const def = DEFAULT_MODULES.find(d => d.key === key);
      return def ? def.icon : '📌';
    }
    return icon.trim();
  }

  render() {
    const isOwnerOrManager = ['owner', 'branch_manager', 'admin'].includes(this.userRole);
    const content = document.createElement('div');
    content.className = 'sidebar-customizer-wrap';
    content.style.cssText = 'display: flex; flex-direction: column; gap: 14px; max-height: 75vh; overflow-y: auto; padding-right: 4px;';

    content.innerHTML = `
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
          ⚡ <strong>Customize Your Navigation</strong>: Toggle modules on/off, rename titles, change icons, and reorder with buttons or drag handles.
        </div>
        <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
          <span style="font-size: 0.75rem; font-weight: 700; color: var(--color-text-muted, #64748b);">Quick Presets:</span>
          <button type="button" class="sc-preset-chip" data-preset="default">🏛️ Standard Default</button>
          <button type="button" class="sc-preset-chip" data-preset="frontdesk">🛎️ Front Desk Essential</button>
          <button type="button" class="sc-preset-chip" data-preset="all">✨ Enable All</button>
        </div>
      </div>

      <!-- Scope Selector for Owners / Managers -->
      ${isOwnerOrManager ? `
      <div style="display: flex; align-items: center; justify-content: space-between; background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 8px 12px;">
        <div>
          <strong style="font-size: 0.85rem; color: var(--color-text-primary);">Save Scope</strong>
          <div class="text-muted small" style="font-size: 0.72rem;">Choose who sees this custom navigation layout</div>
        </div>
        <div class="btn-group" role="group" style="display: inline-flex;">
          <button type="button" class="btn btn-xs ${this.saveScope === 'global' ? 'btn-primary' : 'btn-outline-secondary'} sc-scope-btn" data-scope="global" style="font-weight: 700; font-size: 0.75rem; padding: 4px 10px;">
            🌐 Everyone (Global)
          </button>
          <button type="button" class="btn btn-xs ${this.saveScope === 'personal' ? 'btn-primary' : 'btn-outline-secondary'} sc-scope-btn" data-scope="personal" style="font-weight: 700; font-size: 0.75rem; padding: 4px 10px;">
            👤 Personal (Only Me)
          </button>
        </div>
      </div>
      ` : ''}

      <!-- Interactive Module List -->
      <div id="sc-items-container" style="display: flex; flex-direction: column; gap: 8px;">
        ${this.renderItemsHtml()}
      </div>

      <!-- Footer Buttons -->
      <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 10px; border-top: 1px solid var(--color-border); padding-top: 12px; flex-wrap: wrap; gap: 8px;">
        <button type="button" id="sc-btn-reset" class="btn btn-sm btn-outline-danger" style="font-weight: 700; font-size: 0.82rem; display: inline-flex; align-items: center; gap: 4px;">
          ↺ Reset Defaults
        </button>
        <div style="display: flex; gap: 8px; align-items: center;">
          <button type="button" id="sc-btn-cancel" class="btn btn-sm btn-secondary" style="font-weight: 700; font-size: 0.82rem;">
            Cancel
          </button>
          <button type="button" id="sc-btn-save" class="btn btn-sm btn-primary" style="font-weight: 800; font-size: 0.85rem; padding: 6px 18px; display: inline-flex; align-items: center; gap: 6px;">
            💾 Save & Apply
          </button>
        </div>
      </div>
    `;

    this.bindEvents(content);

    // Open in BottomSheet if mobile (<= 768px), otherwise in Modal
    if (window.innerWidth <= 768 && typeof BottomSheet !== 'undefined' && BottomSheet.show) {
      this.modalInstance = BottomSheet.show({
        title: '🎨 Customize Sidebar Navigation',
        content: content,
        height: '85vh'
      });
    } else if (typeof Modal !== 'undefined' && Modal.show) {
      this.modalInstance = Modal.show({
        title: '🎨 Customize Sidebar Navigation',
        content: content,
        size: 'lg'
      });
    }
  }

  renderItemsHtml() {
    return this.items.map((item, index) => {
      const isFirst = index === 0;
      const isLast = index === this.items.length - 1;
      return `
        <div class="sc-module-row ${item.isEnabled ? '' : 'sc-disabled'}" data-key="${item.key}" data-index="${index}">
          <!-- Drag Handle -->
          <span class="sc-drag-handle" title="Drag to reorder">☰</span>

          <!-- Up/Down Buttons for Mobile -->
          <div style="display: flex; flex-direction: column; gap: 2px;">
            <button type="button" class="sc-reorder-btn sc-btn-up" data-index="${index}" ${isFirst ? 'disabled' : ''} title="Move Up">▲</button>
            <button type="button" class="sc-reorder-btn sc-btn-down" data-index="${index}" ${isLast ? 'disabled' : ''} title="Move Down">▼</button>
          </div>

          <!-- Icon / Emoji -->
          <button type="button" class="sc-icon-btn" data-key="${item.key}" title="Tap to change icon">
            ${item.icon || '📌'}
          </button>

          <!-- Label Rename Input -->
          <input type="text" class="sc-rename-input" data-key="${item.key}" value="${item.label || item.key}" placeholder="${item.key}">

          <!-- Visibility Toggle -->
          <div class="form-check form-switch mb-0" style="font-size: 1.15rem; margin-left: auto;">
            <input class="form-check-input sc-toggle-switch" type="checkbox" data-key="${item.key}" ${item.isEnabled ? 'checked' : ''} title="Turn on/off in navigation">
          </div>
        </div>
      `;
    }).join('');
  }

  refreshList(container) {
    container.innerHTML = this.renderItemsHtml();
    this.bindRowEvents(container);
  }

  bindEvents(content) {
    const listContainer = content.querySelector('#sc-items-container');

    // Preset Buttons
    content.querySelectorAll('.sc-preset-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const presetKey = chip.dataset.preset;
        this.applyPreset(presetKey);
        this.refreshList(listContainer);
      });
    });

    // Scope Switch
    content.querySelectorAll('.sc-scope-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        this.saveScope = btn.dataset.scope;
        content.querySelectorAll('.sc-scope-btn').forEach(b => {
          b.className = `btn btn-xs ${b.dataset.scope === this.saveScope ? 'btn-primary' : 'btn-outline-secondary'} sc-scope-btn`;
        });
      });
    });

    // Reset Button
    content.querySelector('#sc-btn-reset')?.addEventListener('click', async () => {
      if (confirm('Reset navigation layout to default factory order?')) {
        this.items = JSON.parse(JSON.stringify(DEFAULT_MODULES));
        this.refreshList(listContainer);
      }
    });

    // Cancel Button
    content.querySelector('#sc-btn-cancel')?.addEventListener('click', () => {
      this.closeModal();
    });

    // Save Button
    content.querySelector('#sc-btn-save')?.addEventListener('click', async () => {
      const saveBtn = content.querySelector('#sc-btn-save');
      if (saveBtn) saveBtn.disabled = true;
      try {
        await this.saveChanges();
        this.closeModal();
      } catch (err) {
        Toast.error(err.message || 'Failed to save navigation changes.');
      } finally {
        if (saveBtn) saveBtn.disabled = false;
      }
    });

    this.bindRowEvents(listContainer);
  }

  bindRowEvents(listContainer) {
    if (typeof window !== 'undefined' && window.Sortable && listContainer) {
      try {
        if (this._sortableInst) this._sortableInst.destroy();
        this._sortableInst = window.Sortable.create(listContainer, {
          handle: '.sc-drag-handle',
          animation: 180,
          ghostClass: 'sortable-ghost',
          chosenClass: 'sortable-chosen',
          onEnd: () => {
            const rows = Array.from(listContainer.querySelectorAll('.sc-module-row'));
            const newOrderMap = new Map(rows.map((r, idx) => [r.dataset.key, idx]));
            this.items.sort((a, b) => {
              const ordA = newOrderMap.has(a.key) ? newOrderMap.get(a.key) : 999;
              const ordB = newOrderMap.has(b.key) ? newOrderMap.get(b.key) : 999;
              return ordA - ordB;
            });
            this.refreshList(listContainer);
          }
        });
      } catch (e) {}
    }

    // Up buttons
    listContainer.querySelectorAll('.sc-btn-up').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.dataset.index, 10);
        if (idx > 0) {
          const temp = this.items[idx];
          this.items[idx] = this.items[idx - 1];
          this.items[idx - 1] = temp;
          this.refreshList(listContainer);
        }
      });
    });

    // Down buttons
    listContainer.querySelectorAll('.sc-btn-down').forEach(btn => {
      btn.addEventListener('click', () => {
        const idx = parseInt(btn.dataset.index, 10);
        if (idx < this.items.length - 1) {
          const temp = this.items[idx];
          this.items[idx] = this.items[idx + 1];
          this.items[idx + 1] = temp;
          this.refreshList(listContainer);
        }
      });
    });

    // Rename Inputs
    listContainer.querySelectorAll('.sc-rename-input').forEach(inp => {
      inp.addEventListener('input', () => {
        const key = inp.dataset.key;
        const item = this.items.find(i => i.key === key);
        if (item) item.label = inp.value.trim();
      });
    });

    // Toggle Switches
    listContainer.querySelectorAll('.sc-toggle-switch').forEach(sw => {
      sw.addEventListener('change', () => {
        const key = sw.dataset.key;
        const item = this.items.find(i => i.key === key);
        if (item) {
          item.isEnabled = sw.checked;
          const row = sw.closest('.sc-module-row');
          if (row) row.classList.toggle('sc-disabled', !sw.checked);
        }
      });
    });

    // Icon Selector Popups
    listContainer.querySelectorAll('.sc-icon-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.openEmojiPicker(btn);
      });
    });
  }

  openEmojiPicker(targetBtn) {
    const existing = document.getElementById('sc-emoji-picker-dropdown');
    if (existing) existing.remove();

    const picker = document.createElement('div');
    picker.id = 'sc-emoji-picker-dropdown';
    picker.style.cssText = `
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
    `;

    POPULAR_ICONS.forEach(emoji => {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = emoji;
      b.style.cssText = 'font-size: 1.25rem; border: none; background: transparent; cursor: pointer; border-radius: 6px; padding: 4px; transition: background 0.1s;';
      b.onmouseenter = () => { b.style.background = 'rgba(108, 92, 231, 0.15)'; };
      b.onmouseleave = () => { b.style.background = 'transparent'; };
      b.onclick = (ev) => {
        ev.stopPropagation();
        targetBtn.textContent = emoji;
        const key = targetBtn.dataset.key;
        const item = this.items.find(i => i.key === key);
        if (item) item.icon = emoji;
        picker.remove();
      };
      picker.appendChild(b);
    });

    document.body.appendChild(picker);

    const rect = targetBtn.getBoundingClientRect();
    picker.style.left = `${Math.min(window.innerWidth - 260, Math.max(10, rect.left))}px`;
    picker.style.top = `${rect.bottom + 6}px`;

    const closeHandler = (ev) => {
      if (!picker.contains(ev.target) && ev.target !== targetBtn) {
        picker.remove();
        document.removeEventListener('click', closeHandler);
      }
    };
    setTimeout(() => document.addEventListener('click', closeHandler), 10);
  }

  applyPreset(presetKey) {
    const preset = PRESETS[presetKey];
    if (!preset) return;

    if (presetKey === 'all') {
      this.items.forEach(item => { item.isEnabled = true; });
    } else {
      const activeSet = new Set(preset.keys);
      this.items.forEach(item => {
        item.isEnabled = activeSet.has(item.key);
      });
      // Re-order according to preset
      const orderMap = new Map(preset.keys.map((k, idx) => [k, idx]));
      this.items.sort((a, b) => {
        const orderA = orderMap.has(a.key) ? orderMap.get(a.key) : 999;
        const orderB = orderMap.has(b.key) ? orderMap.get(b.key) : 999;
        return orderA - orderB;
      });
    }
  }

  async saveChanges() {
    const payload = this.items.map((item, idx) => ({
      key: item.key,
      label: item.label,
      href: item.href,
      icon: item.icon,
      isEnabled: item.isEnabled,
      order: idx + 1
    }));

    // Personal Save: Always save to LocalStorage for instant recall
    try {
      const activeHrefs = payload.filter(i => i.isEnabled).map(i => i.href);
      localStorage.setItem('sl_sidebar_order', JSON.stringify(activeHrefs));
      localStorage.setItem('sl_sidebar_order_personal', JSON.stringify(activeHrefs));
      localStorage.setItem('sl_sidebar_custom_items', JSON.stringify(payload));
    } catch (e) {}

    // Global Save: If owner/manager and global scope selected, save to backend
    if (this.saveScope === 'global' && ['owner', 'branch_manager', 'admin'].includes(this.userRole)) {
      try {
        const res = await api.put('/api/settings/sidebar', { items: payload });
        if (!res || !res.success) {
          throw new Error(res?.message || 'Failed to update global sidebar');
        }
      } catch (err) {
        console.warn('Could not save globally, saved locally:', err.message);
      }
    }

    Toast.success('Navigation layout updated successfully!');

    // Trigger sidebar re-render in app
    if (typeof window.reloadSidebar === 'function') {
      window.reloadSidebar();
    } else if (window.App && typeof window.App.updateSidebarForRole === 'function') {
      window.App.updateSidebarForRole();
    }
  }

  closeModal() {
    if (this.modalInstance) {
      if (typeof this.modalInstance.close === 'function') {
        this.modalInstance.close();
      } else if (typeof BottomSheet !== 'undefined' && BottomSheet.close) {
        BottomSheet.close();
      } else if (typeof Modal !== 'undefined' && Modal.closeAll) {
        Modal.closeAll();
      }
      this.modalInstance = null;
    }
  }
}

const instance = new SidebarCustomizer();
window.SidebarCustomizer = instance;
export default instance;
