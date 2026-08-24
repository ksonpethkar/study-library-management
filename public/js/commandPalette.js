/**
 * Global Command Palette & Quick Operations (`Ctrl+K` / `Cmd+K`)
 * Provides lightning-fast keyboard-driven navigation, instant student lookup,
 * and 1-tap administrative shortcuts.
 */

import { escapeHTML } from './ui.js';

export const CommandPalette = {
  isOpen: false,
  commands: [
    { id: 'new_student', title: 'Add New Student Admission', category: 'Actions', icon: '👤', shortcut: 'Alt+N', href: '#/students?action=new' },
    { id: 'collect_fee', title: 'Collect Fee / New Payment', category: 'Actions', icon: '💵', shortcut: 'Alt+P', href: '#/payments?action=new' },
    { id: 'attendance_kiosk', title: 'Open Attendance Kiosk', category: 'Actions', icon: '🕒', href: '/kiosk', external: true },
    { id: 'view_seats', title: 'Study Desks & Live Seat Map', category: 'Navigation', icon: '💺', href: '#/seats' },
    { id: 'open_trash', title: 'Recycle Bin & Trash Management', category: 'System', icon: '🗑️', href: '#/trash' },
    { id: 'view_reports', title: 'Financial Reports & GST Summary', category: 'Navigation', icon: '📊', href: '#/reports' },
    { id: 'form_builder', title: 'Dynamic Form Builder & Custom Fields', category: 'System', icon: '📝', href: '#/settings?tab=form-builder' },
    { id: 'system_settings', title: 'Business Profile & Branding Settings', category: 'System', icon: '⚙️', href: '#/settings' },
    { id: 'expenses', title: 'Expense Tracker & P&L', category: 'Navigation', icon: '💸', href: '#/expenses' },
    { id: 'lockers', title: 'Locker Allocation Studio', category: 'Navigation', icon: '🔒', href: '#/lockers' },
    { id: 'operations', title: 'Notice Board & Daily Visitors', category: 'Navigation', icon: '📢', href: '#/operations' }
  ],

  init() {
    this._createDOM();
    this._attachListeners();
  },

  _createDOM() {
    if (document.getElementById('sl-command-palette-overlay')) return;

    const overlay = document.createElement('div');
    overlay.id = 'sl-command-palette-overlay';
    overlay.style.cssText = `
      position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
      background: rgba(15, 23, 42, 0.7); backdrop-filter: blur(6px); -webkit-backdrop-filter: blur(6px);
      z-index: 10000; display: none; align-items: flex-start; justify-content: center;
      padding-top: 10vh; opacity: 0; transition: opacity 0.15s ease-out;
    `;

    overlay.innerHTML = `
      <div id="sl-command-palette" style="
        width: 100%; max-width: 600px; background: var(--color-surface, #ffffff);
        border: 1px solid var(--color-border, #e2e8f0); border-radius: 14px;
        box-shadow: 0 20px 40px -10px rgba(0, 0, 0, 0.35); overflow: hidden;
        display: flex; flex-direction: column; transform: translateY(-10px); transition: transform 0.15s ease-out;
      ">
        <div style="display: flex; align-items: center; padding: 14px 18px; border-bottom: 1px solid var(--color-border, #e2e8f0); gap: 12px;">
          <span style="font-size: 1.25rem;">⚡</span>
          <input type="text" id="sl-cmd-input" placeholder="Type a command or search students..." autocomplete="off" style="
            flex: 1; border: none; outline: none; background: transparent;
            font-size: 1.05rem; font-weight: 500; color: var(--color-text-primary, #1e293b);
          ">
          <span style="font-size: 0.75rem; background: var(--color-bg-secondary, #f1f5f9); color: var(--color-text-secondary, #64748b); padding: 3px 8px; border-radius: 6px; font-weight: 600;">ESC</span>
        </div>
        <div id="sl-cmd-results" style="max-height: 380px; overflow-y: auto; padding: 8px 0;"></div>
        <div style="padding: 10px 18px; background: var(--color-bg-secondary, #f8fafc); border-top: 1px solid var(--color-border, #e2e8f0); display: flex; justify-content: space-between; align-items: center; font-size: 0.75rem; color: var(--color-text-secondary, #64748b);">
          <span>Navigate: <strong>↑</strong> <strong>↓</strong> • Select: <strong>↵ Enter</strong></span>
          <span>Quick Actions & Search</span>
        </div>
      </div>
    `;

    document.body.appendChild(overlay);

    overlay.addEventListener('click', (e) => {
      if (e.target === overlay) this.close();
    });

    const input = document.getElementById('sl-cmd-input');
    input.addEventListener('input', () => this._onInput(input.value));
    input.addEventListener('keydown', (e) => this._onKeyDown(e));
  },

  _attachListeners() {
    window.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        this.toggle();
      } else if (e.key === 'Escape' && this.isOpen) {
        this.close();
      }
    });

    // Global Search trigger button in header
    document.addEventListener('click', (e) => {
      if (e.target.closest('#header-search-btn') || e.target.closest('.global-search-trigger')) {
        this.open();
      }
    });
  },

  open() {
    const overlay = document.getElementById('sl-command-palette-overlay');
    const input = document.getElementById('sl-cmd-input');
    if (!overlay || !input) return;

    this.isOpen = true;
    overlay.style.display = 'flex';
    requestAnimationFrame(() => {
      overlay.style.opacity = '1';
      const box = document.getElementById('sl-command-palette');
      if (box) box.style.transform = 'translateY(0)';
    });

    input.value = '';
    this._renderItems(this.commands);
    setTimeout(() => input.focus(), 50);
  },

  close() {
    const overlay = document.getElementById('sl-command-palette-overlay');
    if (!overlay) return;

    this.isOpen = false;
    overlay.style.opacity = '0';
    const box = document.getElementById('sl-command-palette');
    if (box) box.style.transform = 'translateY(-10px)';
    setTimeout(() => {
      overlay.style.display = 'none';
    }, 150);
  },

  toggle() {
    if (this.isOpen) this.close();
    else this.open();
  },

  _onInput(query) {
    const q = (query || '').trim().toLowerCase();
    if (!q) {
      this._renderItems(this.commands);
      return;
    }

    const filtered = this.commands.filter(c => 
      c.title.toLowerCase().includes(q) || 
      c.category.toLowerCase().includes(q)
    );

    this._renderItems(filtered);

    // Optional background student search if length >= 2
    if (q.length >= 2) {
      this._searchStudentsAsync(q);
    }
  },

  async _searchStudentsAsync(q) {
    try {
      const token = localStorage.getItem('sl_token');
      if (!token) return;
      const res = await fetch(`/api/students?search=${encodeURIComponent(q)}&limit=5`, {
        headers: { 'Authorization': `Bearer ${token}` }
      });
      const data = await res.json();
      if (data.success && Array.isArray(data.data?.students) && data.data.students.length > 0) {
        const studentItems = data.data.students.map(s => ({
          id: `student_${s._id}`,
          title: `${s.name} (${s.studentId || 'ID'})`,
          category: 'Students',
          icon: '🎓',
          subtitle: `📱 ${s.phone || 'No Phone'} • Status: ${(s.status || 'active').toUpperCase()}`,
          href: `#/students?search=${encodeURIComponent(s.studentId || s.phone || s.name)}`
        }));
        
        const currentQ = document.getElementById('sl-cmd-input')?.value?.trim().toLowerCase();
        if (currentQ === q) {
          const staticMatches = this.commands.filter(c => c.title.toLowerCase().includes(q));
          this._renderItems([...staticMatches, ...studentItems]);
        }
      }
    } catch (e) {}
  },

  _renderItems(items) {
    const mount = document.getElementById('sl-cmd-results');
    if (!mount) return;

    if (!items || items.length === 0) {
      mount.innerHTML = `
        <div style="padding: 2rem 1rem; text-align: center; color: var(--color-text-secondary, #64748b);">
          <div style="font-size: 1.75rem; margin-bottom: 6px;">🔍</div>
          <div>No matching actions or records found</div>
        </div>
      `;
      return;
    }

    mount.innerHTML = items.map((item, idx) => `
      <div class="sl-cmd-item ${idx === 0 ? 'selected' : ''}" data-idx="${idx}" data-href="${item.href || ''}" data-ext="${item.external ? '1' : '0'}" style="
        display: flex; align-items: center; padding: 10px 18px; cursor: pointer;
        border-left: 3px solid ${idx === 0 ? 'var(--color-primary, #6c5ce7)' : 'transparent'};
        background: ${idx === 0 ? 'var(--color-bg-secondary, #f8fafc)' : 'transparent'};
        transition: background 0.1s, border-color 0.1s; gap: 12px;
      ">
        <span style="font-size: 1.25rem;">${item.icon || '📌'}</span>
        <div style="flex: 1; min-width: 0;">
          <div style="font-size: 0.92rem; font-weight: 600; color: var(--color-text-primary, #1e293b); white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">
            ${escapeHTML(item.title)}
          </div>
          ${item.subtitle ? `<div style="font-size: 0.75rem; color: var(--color-text-secondary, #64748b);">${escapeHTML(item.subtitle)}</div>` : ''}
        </div>
        <span style="font-size: 0.72rem; color: var(--color-text-secondary, #94a3b8); background: var(--color-surface, #fff); border: 1px solid var(--color-border, #e2e8f0); padding: 2px 6px; border-radius: 4px;">
          ${item.category || 'Action'}
        </span>
      </div>
    `).join('');

    mount.querySelectorAll('.sl-cmd-item').forEach(el => {
      el.addEventListener('mouseenter', () => {
        mount.querySelectorAll('.sl-cmd-item').forEach(x => {
          x.classList.remove('selected');
          x.style.background = 'transparent';
          x.style.borderLeftColor = 'transparent';
        });
        el.classList.add('selected');
        el.style.background = 'var(--color-bg-secondary, #f8fafc)';
        el.style.borderLeftColor = 'var(--color-primary, #6c5ce7)';
      });
      el.addEventListener('click', () => {
        this._executeItem(el);
      });
    });
  },

  _onKeyDown(e) {
    const mount = document.getElementById('sl-cmd-results');
    if (!mount) return;

    const items = Array.from(mount.querySelectorAll('.sl-cmd-item'));
    if (items.length === 0) return;

    const currentIdx = items.findIndex(el => el.classList.contains('selected'));

    if (e.key === 'ArrowDown') {
      e.preventDefault();
      const nextIdx = (currentIdx + 1) % items.length;
      this._selectIndex(items, nextIdx);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      const prevIdx = (currentIdx - 1 + items.length) % items.length;
      this._selectIndex(items, prevIdx);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (currentIdx >= 0 && items[currentIdx]) {
        this._executeItem(items[currentIdx]);
      }
    }
  },

  _selectIndex(items, idx) {
    items.forEach((x, i) => {
      const isSel = i === idx;
      x.classList.toggle('selected', isSel);
      x.style.background = isSel ? 'var(--color-bg-secondary, #f8fafc)' : 'transparent';
      x.style.borderLeftColor = isSel ? 'var(--color-primary, #6c5ce7)' : 'transparent';
      if (isSel) x.scrollIntoView({ block: 'nearest' });
    });
  },

  _executeItem(el) {
    const href = el.getAttribute('data-href');
    const isExt = el.getAttribute('data-ext') === '1';
    this.close();

    if (href) {
      if (isExt) {
        window.open(href, '_blank');
      } else {
        window.location.hash = href;
      }
    }
  }
};

window.CommandPalette = CommandPalette;
