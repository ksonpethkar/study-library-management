import api from './api.js';

export class SearchPalette {
  constructor() {
    this.isOpen = false;
    this.selectedIndex = -1;
    this.items = [];
    this.searchTimeout = null;
    this.buildUI();
  }

  buildUI() {
    this.overlay = document.createElement('div');
    this.overlay.className = 'search-palette-overlay';
    this.overlay.style.cssText = `
      position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
      background: rgba(0, 0, 0, 0.7); backdrop-filter: blur(4px);
      display: none; justify-content: center; align-items: flex-start;
      padding-top: 12vh; z-index: 10000;
    `;
    
    this.container = document.createElement('div');
    this.container.style.cssText = `
      width: 620px; max-width: 92vw;
      background: var(--color-surface, #1e2230);
      color: var(--color-text-primary, #fff);
      border: 1px solid var(--color-border, #444);
      border-radius: var(--radius-lg, 12px);
      box-shadow: var(--shadow-xl, 0 16px 48px rgba(0,0,0,0.5));
      display: flex; flex-direction: column; overflow: hidden;
    `;
    
    // Header with search input & shortcut hint
    const searchHeader = document.createElement('div');
    searchHeader.style.cssText = `
      display: flex; align-items: center; padding: 14px 18px;
      border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08));
      gap: 12px;
    `;
    
    const searchIcon = document.createElement('div');
    searchIcon.innerHTML = `<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" style="color: var(--color-primary, #6c5ce7);"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>`;

    this.input = document.createElement('input');
    this.input.type = 'text';
    this.input.placeholder = 'Search students, seats, plans, receipts, actions...';
    this.input.style.cssText = `
      flex: 1; border: none; background: transparent; font-size: 16px;
      color: var(--color-text-primary, #fff); outline: none; font-family: 'Outfit', sans-serif;
    `;

    const paletteVoiceBtn = document.createElement('button');
    paletteVoiceBtn.type = 'button';
    paletteVoiceBtn.title = 'Voice Search';
    paletteVoiceBtn.textContent = '🎙️';
    paletteVoiceBtn.style.cssText = `
      background: none; border: none; cursor: pointer; font-size: 1.1rem;
      padding: 4px; line-height: 1; border-radius: 4px; opacity: 0.85;
      transition: opacity 0.2s;
    `;
    paletteVoiceBtn.addEventListener('click', () => {
      if (window.VoiceSearch) {
        window.VoiceSearch.start((transcript) => {
          this.input.value = transcript;
          this.search(transcript);
        });
      }
    });

    const escBadge = document.createElement('span');
    escBadge.className = 'badge';
    escBadge.textContent = 'ESC to close';
    escBadge.style.cssText = `
      background: var(--color-bg-secondary, rgba(255,255,255,0.08));
      color: var(--color-text-muted, #888); font-size: 0.7rem; padding: 3px 8px; border-radius: 4px;
    `;

    searchHeader.appendChild(searchIcon);
    searchHeader.appendChild(this.input);
    searchHeader.appendChild(paletteVoiceBtn);
    searchHeader.appendChild(escBadge);

    this.results = document.createElement('div');
    this.results.style.cssText = 'max-height: 420px; overflow-y: auto; padding: 8px;';
    
    this.container.appendChild(searchHeader);
    this.container.appendChild(this.results);
    this.overlay.appendChild(this.container);
    document.body.appendChild(this.overlay);

    this.input.addEventListener('input', (e) => {
      clearTimeout(this.searchTimeout);
      this.searchTimeout = setTimeout(() => this.search(e.target.value), 200);
    });

    this.input.addEventListener('keydown', (e) => this.handleKeyboard(e));
    this.overlay.addEventListener('click', (e) => {
      if (e.target === this.overlay) this.close();
    });

    // Global shortcut Ctrl+K and /
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        this.toggle();
      }
    });

    // Also connect header search button
    const globalSearchBtn = document.getElementById('global-search-btn');
    if (globalSearchBtn) {
      globalSearchBtn.addEventListener('click', () => this.open());
    }
  }

  toggle() {
    if (this.isOpen) this.close();
    else this.open();
  }

  open() {
    this.isOpen = true;
    this.overlay.style.display = 'flex';
    this.input.value = '';
    this.search('');
    setTimeout(() => this.input.focus(), 50);
  }

  close() {
    this.isOpen = false;
    this.overlay.style.display = 'none';
  }

  async search(query) {
    const q = (query || '').trim();
    this.selectedIndex = -1;
    this.items = [];

    try {
      const res = await api.get(`/api/search?q=${encodeURIComponent(q)}`);
      if (!res.success || !res.data) throw new Error();

      const { students, seats, plans, payments, actions } = res.data;
      let html = '';

      // Quick Actions
      if (actions && actions.length > 0) {
        html += `<div style="padding: 6px 12px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px;">⚡ Quick Actions</div>`;
        actions.forEach(a => {
          this.items.push({ link: a.link, title: a.label });
          const idx = this.items.length - 1;
          html += `
            <div class="search-result-row" data-idx="${idx}" data-link="${a.link}" style="
              padding: 10px 14px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px;
            ">
              <div style="display: flex; align-items: center; gap: 10px;">
                <span style="font-size: 1.1rem;">${a.icon || '⚡'}</span>
                <strong style="font-size: 0.92rem;">${this.escapeHTML(a.label)}</strong>
              </div>
              <span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-size: 0.7rem;">Action</span>
            </div>
          `;
        });
      }

      // Students
      if (students && students.length > 0) {
        html += `<div style="padding: 8px 12px 4px 12px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px;">🧑‍🎓 Students</div>`;
        students.forEach(s => {
          const link = '#/students';
          this.items.push({ link, title: s.name });
          const idx = this.items.length - 1;
          html += `
            <div class="search-result-row" data-idx="${idx}" data-link="${link}" style="
              padding: 10px 14px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px;
            ">
              <div>
                <strong>${this.escapeHTML(s.name)}</strong>
                <span class="text-muted small" style="margin-left: 8px;">(${this.escapeHTML(s.studentId || s.phone || '')})</span>
              </div>
              <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-size: 0.7rem; text-transform: uppercase;">${this.escapeHTML(s.status || 'Active')}</span>
            </div>
          `;
        });
      }

      // Seats
      if (seats && seats.length > 0) {
        html += `<div style="padding: 8px 12px 4px 12px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px;">💺 Seats & Desks</div>`;
        seats.forEach(st => {
          const link = '#/seats';
          this.items.push({ link, title: st.seatNumber });
          const idx = this.items.length - 1;
          html += `
            <div class="search-result-row" data-idx="${idx}" data-link="${link}" style="
              padding: 10px 14px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px;
            ">
              <div>
                <strong>Seat ${this.escapeHTML(st.seatNumber)}</strong>
                <span class="text-muted small" style="margin-left: 8px;">(${this.escapeHTML(st.zone || '')} - ${this.escapeHTML(st.type || '')})</span>
              </div>
              <span class="badge" style="background: rgba(9, 132, 227, 0.15); color: var(--color-info); font-size: 0.7rem; text-transform: uppercase;">${this.escapeHTML(st.status)}</span>
            </div>
          `;
        });
      }

      // Plans
      if (plans && plans.length > 0) {
        html += `<div style="padding: 8px 12px 4px 12px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px;">📋 Plans</div>`;
        plans.forEach(p => {
          const link = '#/plans';
          this.items.push({ link, title: p.name });
          const idx = this.items.length - 1;
          html += `
            <div class="search-result-row" data-idx="${idx}" data-link="${link}" style="
              padding: 10px 14px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px;
            ">
              <div>
                <strong>${this.escapeHTML(p.name)}</strong>
                <span class="text-muted small" style="margin-left: 8px;">₹${p.price} (${p.duration} ${p.durationType})</span>
              </div>
              <span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-size: 0.7rem;">Plan</span>
            </div>
          `;
        });
      }

      // Payments
      if (payments && payments.length > 0) {
        html += `<div style="padding: 8px 12px 4px 12px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px;">💰 Payments</div>`;
        payments.forEach(py => {
          const link = '#/payments';
          this.items.push({ link, title: py.receiptNumber });
          const idx = this.items.length - 1;
          html += `
            <div class="search-result-row" data-idx="${idx}" data-link="${link}" style="
              padding: 10px 14px; border-radius: 6px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px;
            ">
              <div>
                <strong style="font-family: monospace;">${this.escapeHTML(py.receiptNumber || 'REC')}</strong>
                <span class="text-muted small" style="margin-left: 8px;">${this.escapeHTML(py.student?.name || '')}</span>
              </div>
              <span style="font-weight: 700; color: var(--color-success);">₹${py.finalAmount}</span>
            </div>
          `;
        });
      }

      if (!html) {
        html = `<div style="padding: 30px; text-align: center; color: var(--color-text-muted);">No results matching "${this.escapeHTML(q)}"</div>`;
      }

      this.results.innerHTML = html;

      this.results.querySelectorAll('.search-result-row').forEach(row => {
        row.addEventListener('click', () => {
          const link = row.dataset.link;
          this.close();
          if (link) window.location.hash = link;
        });

        row.addEventListener('mouseenter', () => {
          this.results.querySelectorAll('.search-result-row').forEach(r => r.style.background = 'transparent');
          row.style.background = 'var(--color-bg-secondary, rgba(255,255,255,0.06))';
          this.selectedIndex = parseInt(row.dataset.idx, 10);
        });
      });

    } catch (e) {
      this.results.innerHTML = `<div style="padding: 20px; text-align: center; color: var(--color-text-muted);">Search error</div>`;
    }
  }

  handleKeyboard(e) {
    const rows = this.results.querySelectorAll('.search-result-row');
    if (e.key === 'Escape') {
      this.close();
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (rows.length === 0) return;
      this.selectedIndex = (this.selectedIndex + 1) % rows.length;
      this.highlightSelected(rows);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (rows.length === 0) return;
      this.selectedIndex = (this.selectedIndex - 1 + rows.length) % rows.length;
      this.highlightSelected(rows);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (this.selectedIndex >= 0 && this.selectedIndex < this.items.length) {
        const item = this.items[this.selectedIndex];
        this.close();
        if (item && item.link) window.location.hash = item.link;
      }
    }
  }

  highlightSelected(rows) {
    rows.forEach((r, i) => {
      if (i === this.selectedIndex) {
        r.style.background = 'var(--color-primary-bg, rgba(108, 92, 231, 0.2))';
        r.scrollIntoView({ block: 'nearest' });
      } else {
        r.style.background = 'transparent';
      }
    });
  }

  escapeHTML(str) {
    if (str === null || str === undefined) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
}
