import api from './api.js';

/**
 * ── Natural Language Query & Intent Parser ──────────────────────────────────
 */
const NL_PATTERNS = [
  { test: /expir(ed|ing)|due.*renew|renew.*due/i,                             icon: '🔴', label: 'Expiring / Expired Students',     summary: 'Memberships expired or expiring soon',         link: '#/students',   badge: 'Renewals', color: '#ef4444' },
  { test: /active.*student|student.*active|current.*member/i,                  icon: '✅', label: 'Active Students',                 summary: 'All currently active enrolled students',       link: '#/students',   badge: 'Active',   color: '#10b981' },
  { test: /unpaid|pending.*payment|due.*fee|fee.*due|payment.*pending/i,       icon: '💸', label: 'Pending Fee Students',            summary: 'Students with unpaid / pending fees',          link: '#/payments',  badge: 'Pending',  color: '#f59e0b' },
  { test: /availabl.*seat|free.*seat|seat.*free|empty.*seat|vacant/i,          icon: '💺', label: 'Available Desks',                 summary: 'All free / available study desks right now',   link: '#/seats',     badge: 'Free',     color: '#0284c7' },
  { test: /occupied.*seat|seat.*occupied|taken.*seat/i,                        icon: '🔒', label: 'Occupied Desks',                  summary: 'All currently occupied study desks',           link: '#/seats',     badge: 'Occupied', color: '#ef4444' },
  { test: /present.*today|who.*here|check.*in.*today|attendance.*today/i,      icon: '📅', label: "Today's Attendance",              summary: "Today's full attendance punch log",            link: '#/attendance', badge: 'Today',   color: '#6366f1' },
  { test: /paid.*today|today.*paid|revenue.*today|today.*collection/i,         icon: '💰', label: "Today's Collections",             summary: "Fee payments received today",                  link: '#/payments',  badge: 'Today',    color: '#10b981' },
  { test: /revenue.*month|monthly.*revenue|this.*month.*pay/i,                 icon: '📊', label: 'Monthly Revenue Report',          summary: 'This month fee collection & revenue P&L',      link: '#/reports',   badge: 'Monthly',  color: '#8b5cf6' },
  { test: /add.*student|new.*admission|new.*student|enroll/i,                  icon: '➕', label: 'Add New Student Admission',        summary: 'Open the new student registration form',       link: '#/students?action=new', badge: 'Action', color: '#6366f1' },
  { test: /collect.*fee|record.*payment|new.*payment|receive.*fee/i,           icon: '💳', label: 'Collect Fee / Payment',           summary: 'Open payment collection & receipt modal',      link: '#/payments?action=new', badge: 'Action', color: '#10b981' },
  { test: /lock.*desk|pin.*lock|lock.*terminal|screen.*lock/i,                 icon: '🔒', label: 'Lock Reception Terminal (PIN)',   summary: 'Lock the front-desk screen with 4-digit PIN',  action: 'pinlock',   badge: 'Security', color: '#ef4444' },
  { test: /kiosk|punch.*in|self.*service.*attend/i,                             icon: '📱', label: 'Open Attendance Punch Kiosk',     summary: 'Launch the full-screen barcode/RFID kiosk',    link: '/kiosk',      badge: 'Kiosk',    color: '#0284c7', external: true },
  { test: /form.*builder|custom.*field|registration.*question/i,               icon: '📝', label: 'Dynamic Form Builder',            summary: 'Customize registration fields & questions',    link: '#/settings?tab=form-builder', badge: 'Setup', color: '#8b5cf6' },
  { test: /recycle|trash|bin|deleted/i,                                        icon: '🗑️', label: 'Recycle Bin & Trash',              summary: 'Recover or purge soft-deleted records',        link: '#/trash',     badge: 'System',   color: '#f59e0b' },
  { test: /setting|configuration|preference|branding/i,                        icon: '⚙️', label: 'Library Master Settings',         summary: 'Branding, receipts, rules & security settings',link: '#/settings',  badge: 'Settings', color: '#6366f1' },
  { test: /expense|p&l|profit.*loss|spending/i,                                icon: '📉', label: 'Expenses & Overhead P&L',         summary: 'Log library rent, electricity & maintenance',  link: '#/expenses',  badge: 'Finances', color: '#ef4444' },
  { test: /locker|cupboard|locker.*allot/i,                                    icon: '🔐', label: 'Locker Allocation Studio',         summary: 'Manage student lockers and key deposits',      link: '#/lockers',   badge: 'Facilities', color: '#f59e0b' },
  { test: /notice|visitor|daily.*log/i,                                        icon: '📢', label: 'Notice Board & Operations',        summary: 'Send announcements & visitor desk log',        link: '#/operations', badge: 'Ops',     color: '#0284c7' }
];

const QUICK_COMMANDS = [
  { id: 'nav-dashboard', label: 'Dashboard Overview', summary: 'Main analytics, live occupancy & collections', icon: '🏠', shortcut: 'G D', link: '#/dashboard', badge: 'Page' },
  { id: 'nav-students', label: 'Students Directory', summary: 'Active members, renewals & profiles', icon: '🎓', shortcut: 'G S', link: '#/students', badge: 'Page' },
  { id: 'nav-seats', label: 'Interactive Seat Layout Map', summary: 'Live visual desk grid & quick switch', icon: '🪑', shortcut: 'G L', link: '#/seats', badge: 'Page' },
  { id: 'nav-payments', label: 'Fee Payments & Billing', summary: 'Receipts, UTR verification & balances', icon: '💳', shortcut: 'G P', link: '#/payments', badge: 'Page' },
  { id: 'nav-attendance', label: 'Daily Attendance & Logs', summary: 'Live punch logs, RFID & biometric stats', icon: '📊', shortcut: 'G A', link: '#/attendance', badge: 'Page' },
  { id: 'nav-operations', label: 'Operations & Waiting List', summary: 'Waiting queue, notices & daily visitors', icon: '⚡', shortcut: 'G O', link: '#/operations', badge: 'Page' },
  { id: 'nav-reports', label: 'Financial & Occupancy Reports', summary: 'P&L, GST invoices & collection charts', icon: '📈', shortcut: 'G R', link: '#/reports', badge: 'Page' },
  { id: 'nav-settings', label: 'Library Master Settings', summary: 'Business profile, receipts & admin rules', icon: '⚙️', shortcut: 'G ,', link: '#/settings', badge: 'Page' },
  { id: 'act-new-student', label: 'Add New Student Admission', summary: 'Register student & assign desk', icon: '👤', shortcut: 'Alt+N', link: '#/students?action=new', badge: 'Action' },
  { id: 'act-collect-fee', label: 'Collect Fee Payment', summary: 'Record cash, UPI or card fee', icon: '💵', shortcut: 'Alt+P', link: '#/payments?action=new', badge: 'Action' },
  { id: 'act-pinlock', label: 'Lock Front-Desk Terminal', summary: 'Lock reception counter with 4-digit PIN', icon: '🔒', shortcut: 'PIN', action: 'pinlock', badge: 'Security' },
  { id: 'act-kiosk', label: 'Open Attendance Kiosk', summary: 'Launch student self-punch kiosk', icon: '📱', shortcut: 'KIOSK', link: '/kiosk', external: true, badge: 'Terminal' }
];

const NL_EXAMPLES = ['show expired students', 'available seats', 'today payments', 'who is here now', 'add new student', 'lock desk'];

/**
 * ── Unified Spotlight Search & Command Engine ──────────────────────────────
 */
export class SearchPalette {
  constructor() {
    this.isOpen = false;
    this.selectedIndex = -1;
    this.items = [];
    this.searchTimeout = null;
    this.buildUI();
  }

  buildUI() {
    if (document.getElementById('unified-search-overlay')) return;

    this.overlay = document.createElement('div');
    this.overlay.id = 'unified-search-overlay';
    this.overlay.className = 'search-palette-overlay';
    this.overlay.style.cssText = `
      position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
      background: rgba(15, 23, 42, 0.72); backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px);
      display: none; justify-content: center; align-items: flex-start;
      padding-top: 8vh; z-index: 999990; opacity: 0; transition: opacity 0.18s var(--ease-spring);
    `;

    this.container = document.createElement('div');
    this.container.className = 'glass-card command-palette-modal';
    this.container.style.cssText = `
      width: 680px; max-width: 95vw; background: var(--color-surface, #ffffff);
      color: var(--color-text-primary, #0f172a); border: 1px solid var(--color-border-light, #e2e8f0);
      border-radius: 20px; box-shadow: 0 25px 60px -15px rgba(0, 0, 0, 0.35);
      display: flex; flex-direction: column; overflow: hidden; transform: translateY(-16px) scale(0.97);
      transition: transform 0.22s var(--ease-spring); max-height: 82vh;
    `;

    // ── Search Input Header ──
    const header = document.createElement('div');
    header.style.cssText = 'display: flex; align-items: center; padding: 16px 20px; gap: 12px; border-bottom: 1px solid var(--color-border-light, #e2e8f0);';

    const searchIcon = document.createElement('div');
    searchIcon.innerHTML = '<svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.2" style="color: var(--color-primary, #6366f1); flex-shrink: 0;"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>';

    this.input = document.createElement('input');
    this.input.type = 'text';
    this.input.placeholder = 'Search students, desks, receipts, or ask anything…';
    this.input.autocomplete = 'off';
    this.input.style.cssText = 'flex: 1; border: none; background: transparent; font-size: 1.05rem; font-weight: 500; color: var(--color-text-primary, #0f172a); outline: none; font-family: inherit;';

    this._nlBadge = document.createElement('span');
    this._nlBadge.textContent = '🧠 AI Intent';
    this._nlBadge.style.cssText = 'display: none; background: rgba(99, 102, 241, 0.14); color: var(--color-primary, #6366f1); font-size: 0.72rem; font-weight: 700; padding: 3px 8px; border-radius: 9999px; border: 1px solid rgba(99, 102, 241, 0.3); white-space: nowrap; flex-shrink: 0;';

    const voiceBtn = document.createElement('button');
    voiceBtn.type = 'button';
    voiceBtn.title = 'Voice Search';
    voiceBtn.textContent = '🎙️';
    voiceBtn.style.cssText = 'background: none; border: none; cursor: pointer; font-size: 1.15rem; padding: 4px; line-height: 1; border-radius: 6px; opacity: 0.85; transition: transform 0.15s;';
    voiceBtn.addEventListener('click', () => {
      if (window.VoiceSearch) {
        window.VoiceSearch.start(t => {
          this.input.value = t;
          this.search(t);
        });
      }
    });

    const escBtn = document.createElement('span');
    escBtn.textContent = 'ESC';
    escBtn.title = 'Close (Escape)';
    escBtn.style.cssText = 'background: var(--color-bg-secondary, #f1f5f9); color: var(--color-text-muted, #64748b); font-size: 0.72rem; font-weight: 700; font-family: "JetBrains Mono", monospace; padding: 3px 8px; border-radius: 6px; border: 1px solid var(--color-border-light, #e2e8f0); cursor: pointer; flex-shrink: 0;';
    escBtn.addEventListener('click', () => this.close());

    header.append(searchIcon, this.input, this._nlBadge, voiceBtn, escBtn);

    // ── Results Container ──
    this.results = document.createElement('div');
    this.results.style.cssText = 'max-height: 480px; overflow-y: auto; padding: 10px;';

    // ── Keyboard Helper Footer ──
    const footer = document.createElement('div');
    footer.style.cssText = 'padding: 10px 18px; border-top: 1px solid var(--color-border-light, #e2e8f0); display: flex; align-items: center; gap: 12px; font-size: 0.75rem; color: var(--color-text-muted, #64748b); flex-wrap: wrap; background: var(--color-bg-secondary, #f8fafc);';
    footer.innerHTML = `
      <span><kbd class="command-shortcut-badge">↑↓</kbd> navigate</span>
      <span><kbd class="command-shortcut-badge">↵</kbd> select</span>
      <span><kbd class="command-shortcut-badge">Ctrl+K</kbd> toggle</span>
      <span style="margin-left: auto; opacity: 0.7;">⚡ Unified Instant Search</span>
    `;

    this.container.append(header, this.results, footer);
    this.overlay.appendChild(this.container);
    document.body.appendChild(this.overlay);

    // Event Listeners
    this.input.addEventListener('input', e => {
      clearTimeout(this.searchTimeout);
      this.searchTimeout = setTimeout(() => this.search(e.target.value), 120);
    });
    this.input.addEventListener('keydown', e => this.handleKeyboard(e));
    this.overlay.addEventListener('click', e => { if (e.target === this.overlay) this.close(); });
    
    // Global Keyboard & Click Triggers
    document.addEventListener('keydown', e => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        this.toggle();
      }
    });

    document.getElementById('global-search-btn')?.addEventListener('click', () => this.open());
  }

  toggle() { this.isOpen ? this.close() : this.open(); }

  open() {
    this.isOpen = true;
    this.overlay.style.display = 'flex';
    requestAnimationFrame(() => {
      this.overlay.style.opacity = '1';
      this.container.style.transform = 'translateY(0) scale(1)';
    });
    this.input.value = '';
    this._nlBadge.style.display = 'none';
    this.search('');
    setTimeout(() => this.input.focus(), 60);
  }

  close() {
    this.isOpen = false;
    this.overlay.style.opacity = '0';
    this.container.style.transform = 'translateY(-16px) scale(0.97)';
    setTimeout(() => {
      this.overlay.style.display = 'none';
    }, 180);
  }

  async search(query) {
    const q = (query || '').trim();
    this.selectedIndex = -1;
    this.items = [];

    // 1. Natural Language Intent Recognition
    if (q.length >= 3) {
      const nlMatches = NL_PATTERNS.filter(p => p.test.test(q));
      if (nlMatches.length > 0) {
        this._nlBadge.style.display = 'inline-block';
        let html = `<div style="padding: 6px 12px 6px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px; display: flex; align-items: center; gap: 6px;"><span>🧠</span> Smart Intent Results</div>`;
        nlMatches.forEach(m => {
          this.items.push({ link: m.link, title: m.label, action: m.action, external: m.external });
          const idx = this.items.length - 1;
          html += `
            <div class="search-result-row hover-lift" data-idx="${idx}" style="padding: 12px 16px; border-radius: 12px; cursor: pointer; margin-bottom: 4px; display: flex; align-items: center; justify-content: space-between; border-left: 3px solid ${m.color}; background: linear-gradient(90deg, ${m.color}15, transparent);">
              <div style="display: flex; align-items: center; gap: 12px;">
                <span style="font-size: 1.25rem; flex-shrink: 0;">${m.icon}</span>
                <div>
                  <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-text-primary);">${this.escapeHTML(m.label)}</div>
                  <div style="font-size: 0.76rem; color: var(--color-text-secondary); margin-top: 2px;">${this.escapeHTML(m.summary)}</div>
                </div>
              </div>
              <span class="badge" style="background: ${m.color}22; color: ${m.color}; font-size: 0.7rem; font-weight: 700; padding: 4px 10px; border-radius: 9999px; border: 1px solid ${m.color}44;">${m.badge}</span>
            </div>
          `;
        });
        this.results.innerHTML = html;
        this._bindRows();
        return;
      }
    }
    this._nlBadge.style.display = 'none';

    // 2. Default Quick Navigation & Commands (when input is empty or broad)
    if (!q) {
      let html = `<div style="padding: 6px 12px 6px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px;">⚡ Quick Actions & Pages</div>`;
      QUICK_COMMANDS.forEach(cmd => {
        this.items.push({ link: cmd.link, title: cmd.label, action: cmd.action, external: cmd.external });
        const idx = this.items.length - 1;
        html += `
          <div class="search-result-row hover-lift" data-idx="${idx}" style="padding: 10px 14px; border-radius: 10px; cursor: pointer; margin-bottom: 2px; display: flex; align-items: center; justify-content: space-between;">
            <div style="display: flex; align-items: center; gap: 12px;">
              <span style="font-size: 1.15rem; flex-shrink: 0;">${cmd.icon}</span>
              <div>
                <div style="font-weight: 600; font-size: 0.9rem;">${this.escapeHTML(cmd.label)}</div>
                <div style="font-size: 0.75rem; color: var(--color-text-muted);">${this.escapeHTML(cmd.summary)}</div>
              </div>
            </div>
            <div style="display: flex; align-items: center; gap: 8px;">
              <span class="command-shortcut-badge">${cmd.shortcut}</span>
            </div>
          </div>
        `;
      });
      this.results.innerHTML = html;
      this._bindRows();
      return;
    }

    // 3. Live Server-Side Multi-Entity Query
    try {
      const res = await api.get(`/api/search?q=${encodeURIComponent(q)}`);
      if (!res.success || !res.data) throw new Error();
      const { students, seats, plans, payments, actions } = res.data;
      let html = '';

      const sec = (icon, lbl) => `<div style="padding: 8px 12px 4px; font-weight: 700; font-size: 0.72rem; text-transform: uppercase; color: var(--color-text-muted); letter-spacing: 0.5px;">${icon} ${lbl}</div>`;
      const rowHtml = (idx, left, right) => `<div class="search-result-row hover-lift" data-idx="${idx}" style="padding: 10px 14px; border-radius: 10px; cursor: pointer; display: flex; align-items: center; justify-content: space-between; margin-bottom: 2px;">${left}${right}</div>`;

      // Matching Quick Actions
      const matchedCmds = QUICK_COMMANDS.filter(c => c.label.toLowerCase().includes(q.toLowerCase()) || c.id.toLowerCase().includes(q.toLowerCase()));
      if (matchedCmds.length > 0) {
        html += sec('⚡', 'Quick Commands');
        matchedCmds.forEach(c => {
          this.items.push({ link: c.link, title: c.label, action: c.action, external: c.external });
          html += rowHtml(this.items.length - 1,
            `<div style="display: flex; align-items: center; gap: 10px;"><span style="font-size: 1.15rem;">${c.icon}</span><strong style="font-size: 0.9rem;">${this.escapeHTML(c.label)}</strong></div>`,
            `<span class="command-shortcut-badge">${c.shortcut}</span>`
          );
        });
      }

      // Matching Students
      if (students?.length) {
        html += sec('🧑‍🎓', 'Students');
        students.forEach(s => {
          this.items.push({ link: `#/students?id=${s._id}`, title: s.name });
          html += rowHtml(this.items.length - 1,
            `<div style="display: flex; align-items: center; gap: 10px;">
              <div class="avatar avatar-xs" style="background: rgba(99, 102, 241, 0.15); color: var(--color-primary); font-weight: 700; width: 30px; height: 30px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 0.75rem;">${(s.name || 'S').slice(0, 2).toUpperCase()}</div>
              <div>
                <strong style="font-size: 0.92rem;">${this.escapeHTML(s.name)}</strong>
                <span class="text-muted font-mono-num" style="margin-left: 8px; font-size: 0.78rem;">${this.escapeHTML(s.studentId || s.phone || '')}</span>
              </div>
            </div>`,
            `<span class="badge" style="background: ${s.status === 'active' ? 'rgba(16, 185, 129, 0.15); color: var(--color-success);' : 'rgba(239, 68, 68, 0.15); color: var(--color-danger);'} font-size: 0.7rem; font-weight: 700; border-radius: 9999px;">${this.escapeHTML(s.status || 'Active')}</span>`
          );
        });
      }

      // Matching Seats
      if (seats?.length) {
        html += sec('💺', 'Study Desks');
        seats.forEach(st => {
          this.items.push({ link: '#/seats', title: `Seat ${st.seatNumber}` });
          html += rowHtml(this.items.length - 1,
            `<div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.1rem;">🪑</span>
              <strong style="font-family: 'JetBrains Mono', monospace; font-size: 0.92rem;">Desk ${this.escapeHTML(st.seatNumber)}</strong>
              <span class="text-muted small" style="margin-left: 6px;">(${this.escapeHTML(st.zone || 'General')})</span>
            </div>`,
            `<span class="badge font-mono-num" style="background: rgba(2, 132, 199, 0.15); color: var(--color-info); font-size: 0.7rem; font-weight: 700; border-radius: 9999px;">${this.escapeHTML(st.status)}</span>`
          );
        });
      }

      // Matching Payments & Receipts
      if (payments?.length) {
        html += sec('💰', 'Payments & Invoices');
        payments.forEach(py => {
          this.items.push({ link: '#/payments', title: py.receiptNumber });
          html += rowHtml(this.items.length - 1,
            `<div>
              <strong class="font-mono-num" style="color: var(--color-primary); font-size: 0.9rem;">${this.escapeHTML(py.receiptNumber || 'REC')}</strong>
              <span class="text-muted small" style="margin-left: 8px;">${this.escapeHTML(py.student?.name || 'Student')}</span>
            </div>`,
            `<span class="font-mono-num" style="font-weight: 700; color: var(--color-success); font-size: 0.92rem;">₹${py.finalAmount || py.amount}</span>`
          );
        });
      }

      if (!html) {
        html = `
          <div style="padding: 28px 20px; text-align: center; color: var(--color-text-muted);">
            <div style="font-size: 2.2rem; margin-bottom: 8px;">🔍</div>
            <div style="font-weight: 700; font-size: 1rem; margin-bottom: 4px; color: var(--color-text-primary);">No direct results for "${this.escapeHTML(q)}"</div>
            <div style="font-size: 0.8rem; margin-bottom: 16px; opacity: 0.75;">Try natural language — this search understands plain questions</div>
            <div style="display: flex; flex-wrap: wrap; gap: 8px; justify-content: center;">
              ${NL_EXAMPLES.map(s => `<span class="nl-suggestion hover-lift" data-q="${s}" style="padding: 5px 12px; border-radius: 9999px; font-size: 0.78rem; font-weight: 600; cursor: pointer; background: rgba(99, 102, 241, 0.12); color: var(--color-primary); border: 1px solid rgba(99, 102, 241, 0.25);">${s}</span>`).join('')}
            </div>
          </div>
        `;
      }

      this.results.innerHTML = html;
      this.results.querySelectorAll('.nl-suggestion').forEach(c => {
        c.addEventListener('click', () => {
          this.input.value = c.dataset.q;
          this.search(c.dataset.q);
        });
      });
      this._bindRows();
    } catch (e) {
      this.results.innerHTML = '<div style="padding: 24px; text-align: center; color: var(--color-text-muted);">Search query failed</div>';
    }
  }

  _bindRows() {
    this.results.querySelectorAll('.search-result-row').forEach(row => {
      row.addEventListener('click', () => {
        const idx = parseInt(row.dataset.idx, 10);
        const item = this.items[idx];
        this.close();
        if (!item) return;

        if (item.action === 'pinlock') {
          if (window.PinLock) window.PinLock.lock();
          return;
        }

        if (item.link) {
          if (item.external) {
            window.open(item.link, '_blank');
          } else if (item.link.startsWith('/') && !item.link.startsWith('/#')) {
            window.location.href = item.link;
          } else {
            window.location.hash = item.link.replace(/^#/, '');
          }
        }
      });

      row.addEventListener('mouseenter', () => {
        this.results.querySelectorAll('.search-result-row').forEach(r => r.style.background = 'transparent');
        row.style.background = 'var(--color-bg-secondary, rgba(255, 255, 255, 0.08))';
        this.selectedIndex = parseInt(row.dataset.idx, 10);
      });
    });
  }

  handleKeyboard(e) {
    const rows = this.results.querySelectorAll('.search-result-row');
    if (e.key === 'Escape') { this.close(); return; }
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (!rows.length) return;
      this.selectedIndex = (this.selectedIndex + 1) % rows.length;
      this.highlightSelected(rows);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (!rows.length) return;
      this.selectedIndex = (this.selectedIndex - 1 + rows.length) % rows.length;
      this.highlightSelected(rows);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (this.selectedIndex >= 0 && rows[this.selectedIndex]) {
        rows[this.selectedIndex].click();
      }
    }
  }

  highlightSelected(rows) {
    rows.forEach((r, i) => {
      r.style.background = i === this.selectedIndex ? 'var(--color-primary-bg, rgba(99, 102, 241, 0.18))' : 'transparent';
      if (i === this.selectedIndex) r.scrollIntoView({ block: 'nearest' });
    });
  }

  escapeHTML(str) {
    if (str == null) return '';
    return String(str).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }
}

// Global Singleton Instance
export const GlobalSearch = new SearchPalette();
window.GlobalSearch = GlobalSearch;
window.SearchPalette = SearchPalette;
window.CommandPalette = GlobalSearch;
