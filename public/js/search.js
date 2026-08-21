import api from './api.js';

// ── Natural Language Query Engine ────────────────────────────────────────────
const NL_PATTERNS = [
  { test: /expir(ed|ing)|due.*renew|renew.*due/i,                             icon: '🔴', label: 'Expiring / Expired Students',     summary: 'Memberships expired or expiring soon',         link: '#/students',   badge: 'Renewals', color: '#e17055' },
  { test: /active.*student|student.*active|current.*member/i,                  icon: '✅', label: 'Active Students',                 summary: 'All currently active enrolled students',       link: '#/students',   badge: 'Active',   color: '#00b894' },
  { test: /unpaid|pending.*payment|due.*fee|fee.*due|payment.*pending/i,       icon: '💸', label: 'Pending Fee Students',            summary: 'Students with unpaid / pending fees',          link: '#/payments',  badge: 'Pending',  color: '#fdcb6e' },
  { test: /availabl.*seat|free.*seat|seat.*free|empty.*seat|vacant/i,          icon: '💺', label: 'Available Seats',                 summary: 'All free / available desks right now',         link: '#/seats',     badge: 'Free',     color: '#0984e3' },
  { test: /occupied.*seat|seat.*occupied|taken.*seat/i,                        icon: '🔒', label: 'Occupied Seats',                  summary: 'All currently occupied desks',                 link: '#/seats',     badge: 'Occupied', color: '#e17055' },
  { test: /present.*today|who.*here|check.*in.*today|attendance.*today/i,      icon: '📅', label: "Today's Attendance",              summary: "Today's full attendance log",                  link: '#/attendance', badge: 'Today',   color: '#6c5ce7' },
  { test: /paid.*today|today.*paid|revenue.*today|today.*collection/i,         icon: '💰', label: "Today's Collections",             summary: "Fee payments received today",                  link: '#/payments',  badge: 'Today',    color: '#00b894' },
  { test: /revenue.*month|monthly.*revenue|this.*month.*pay/i,                 icon: '📊', label: 'Monthly Revenue Report',          summary: 'This month fee collection & revenue',          link: '#/reports',   badge: 'Monthly',  color: '#a29bfe' },
  { test: /add.*student|new.*admission|new.*student|enroll/i,                  icon: '➕', label: 'Add New Student',                 summary: 'Open the new student admission form',          link: '#/students',  badge: 'Action',   color: '#6c5ce7' },
  { test: /collect.*fee|record.*payment|new.*payment|receive.*fee/i,           icon: '💳', label: 'Collect Fee / Payment',           summary: 'Open payment collection form',                 link: '#/payments',  badge: 'Action',   color: '#00b894' },
  { test: /dashboard|home.*page|overview|summary/i,                             icon: '🏠', label: 'Dashboard Overview',              summary: 'Go to the main admin dashboard',               link: '#/dashboard', badge: 'Page',     color: '#6c5ce7' },
  { test: /report|analytics|statistic|insight/i,                               icon: '📈', label: 'Reports & Analytics',             summary: 'Detailed reports and revenue analytics',       link: '#/reports',   badge: 'Page',     color: '#fdcb6e' },
  { test: /setting|configuration|preference/i,                                  icon: '⚙️', label: 'Settings',                       summary: 'Open system settings & configuration',         link: '#/settings',  badge: 'Page',     color: '#a29bfe' },
  { test: /who.*library|in.*library.*now|currently.*here|present.*now/i,        icon: '👥', label: 'Students In Library Now',         summary: 'See who is currently checked in',              link: '#/attendance', badge: 'Live',    color: '#00b894' },
  { test: /low.*attendance|at.*risk|irregular.*student|absent.*often/i,         icon: '⚠️', label: 'At-Risk Students',               summary: 'Students with low attendance',                 link: '#/students',  badge: 'At Risk',  color: '#e17055' },
  { test: /morning.*shift|morning.*student|day.*shift/i,                        icon: '🌅', label: 'Morning Shift Students',          summary: 'Students enrolled in morning shift',            link: '#/students',  badge: 'Shift',    color: '#fdcb6e' },
  { test: /evening.*shift|evening.*student|night.*shift/i,                      icon: '🌙', label: 'Evening Shift Students',          summary: 'Students enrolled in evening / night shift',   link: '#/students',  badge: 'Shift',    color: '#6c5ce7' },
  { test: /kiosk|punch.*in|self.*service.*attend/i,                             icon: '📲', label: 'Open Attendance Kiosk',           summary: 'Launch the self-service attendance kiosk',     link: '/kiosk',      badge: 'Kiosk',    color: '#0984e3' }
];

const NL_EXAMPLES = ['show expired students','available seats','today payments','who is here now','add new student','low attendance'];

function parseNLQuery(q) {
  if (!q || q.trim().length < 3) return { handled: false };
  const matches = NL_PATTERNS.filter(p => p.test.test(q.trim()));
  if (!matches.length) return { handled: false };

  let html = `<div style="padding:6px 12px 4px;font-weight:700;font-size:0.72rem;text-transform:uppercase;color:var(--color-text-muted);letter-spacing:0.5px;display:flex;align-items:center;gap:6px;"><span>🧠</span> Smart Results <span style="font-size:0.65rem;font-weight:400;opacity:0.7;">— understood your intent</span></div>`;
  const items = [];
  matches.forEach(m => {
    items.push({ link: m.link, title: m.label });
    const idx = items.length - 1;
    html += `<div class="search-result-row" data-idx="${idx}" data-link="${m.link}" style="padding:11px 14px;border-radius:8px;cursor:pointer;margin-bottom:3px;display:flex;align-items:center;justify-content:space-between;border-left:3px solid ${m.color};background:linear-gradient(90deg,${m.color}11,transparent);">
      <div style="display:flex;align-items:center;gap:11px;">
        <span style="font-size:1.2rem;flex-shrink:0;">${m.icon}</span>
        <div>
          <div style="font-weight:700;font-size:0.92rem;color:var(--color-text-primary);">${m.label}</div>
          <div style="font-size:0.74rem;color:var(--color-text-secondary);margin-top:1px;">${m.summary}</div>
        </div>
      </div>
      <span style="background:${m.color}22;color:${m.color};font-size:0.65rem;font-weight:700;padding:3px 8px;border-radius:10px;white-space:nowrap;flex-shrink:0;margin-left:8px;border:1px solid ${m.color}44;">${m.badge}</span>
    </div>`;
  });
  return { handled: true, html, items };
}

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
    this.overlay.style.cssText = 'position:fixed;top:0;left:0;width:100vw;height:100vh;background:rgba(0,0,0,0.72);backdrop-filter:blur(6px);display:none;justify-content:center;align-items:flex-start;padding-top:10vh;z-index:10000;';

    this.container = document.createElement('div');
    this.container.style.cssText = 'width:660px;max-width:95vw;background:var(--color-surface,#1e2230);color:var(--color-text-primary,#fff);border:1px solid var(--color-border,#444);border-radius:16px;box-shadow:0 24px 64px rgba(0,0,0,0.55);display:flex;flex-direction:column;overflow:hidden;';

    const header = document.createElement('div');
    header.style.cssText = 'display:flex;align-items:center;padding:14px 18px;gap:12px;border-bottom:1px solid var(--color-divider,rgba(255,255,255,0.07));';

    const searchIcon = document.createElement('div');
    searchIcon.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" style="color:var(--color-primary,#6c5ce7);flex-shrink:0;"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>';

    this.input = document.createElement('input');
    this.input.type = 'text';
    this.input.placeholder = 'Search or ask anything… "show expired students", "free seats"';
    this.input.style.cssText = 'flex:1;border:none;background:transparent;font-size:15px;color:var(--color-text-primary,#fff);outline:none;font-family:Outfit,sans-serif;';

    this._nlBadge = document.createElement('span');
    this._nlBadge.textContent = '🧠 Smart';
    this._nlBadge.style.cssText = 'display:none;background:rgba(108,92,231,0.18);color:var(--color-primary,#6c5ce7);font-size:0.68rem;font-weight:700;padding:3px 8px;border-radius:10px;border:1px solid rgba(108,92,231,0.3);white-space:nowrap;flex-shrink:0;';

    const voiceBtn = document.createElement('button');
    voiceBtn.type = 'button'; voiceBtn.title = 'Voice Search'; voiceBtn.textContent = '🎙️';
    voiceBtn.style.cssText = 'background:none;border:none;cursor:pointer;font-size:1.1rem;padding:4px;line-height:1;border-radius:4px;opacity:0.8;';
    voiceBtn.addEventListener('click', () => {
      if (window.VoiceSearch) window.VoiceSearch.start(t => { this.input.value = t; this.search(t); });
    });

    const escBtn = document.createElement('span');
    escBtn.textContent = 'ESC'; escBtn.title = 'Close (Escape)';
    escBtn.style.cssText = 'background:rgba(255,255,255,0.08);color:#888;font-size:0.7rem;padding:3px 8px;border-radius:4px;cursor:pointer;flex-shrink:0;';
    escBtn.addEventListener('click', () => this.close());

    header.append(searchIcon, this.input, this._nlBadge, voiceBtn, escBtn);

    this.results = document.createElement('div');
    this.results.style.cssText = 'max-height:460px;overflow-y:auto;padding:8px;';

    const footer = document.createElement('div');
    footer.style.cssText = 'padding:7px 14px;border-top:1px solid var(--color-divider,rgba(255,255,255,0.06));display:flex;align-items:center;gap:10px;font-size:0.68rem;color:var(--color-text-muted);flex-wrap:wrap;';
    footer.innerHTML = '<span><kbd style="padding:1px 5px;border-radius:3px;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.12);">↑↓</kbd> navigate</span><span><kbd style="padding:1px 5px;border-radius:3px;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.12);">↵</kbd> open</span><span><kbd style="padding:1px 5px;border-radius:3px;background:rgba(255,255,255,0.08);border:1px solid rgba(255,255,255,0.12);">Ctrl+K</kbd> toggle</span><span style="margin-left:auto;opacity:0.6;">🧠 Understands natural language</span>';

    this.container.append(header, this.results, footer);
    this.overlay.appendChild(this.container);
    document.body.appendChild(this.overlay);

    this.input.addEventListener('input', e => {
      clearTimeout(this.searchTimeout);
      this.searchTimeout = setTimeout(() => this.search(e.target.value), 180);
    });
    this.input.addEventListener('keydown', e => this.handleKeyboard(e));
    this.overlay.addEventListener('click', e => { if (e.target === this.overlay) this.close(); });
    document.addEventListener('keydown', e => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { e.preventDefault(); this.toggle(); }
    });
    document.getElementById('global-search-btn')?.addEventListener('click', () => this.open());
  }

  toggle() { this.isOpen ? this.close() : this.open(); }

  open() {
    this.isOpen = true;
    this.overlay.style.display = 'flex';
    this.input.value = '';
    this._nlBadge.style.display = 'none';
    this.search('');
    setTimeout(() => this.input.focus(), 50);
  }

  close() { this.isOpen = false; this.overlay.style.display = 'none'; }

  async search(query) {
    const q = (query || '').trim();
    this.selectedIndex = -1;
    this.items = [];

    const nl = parseNLQuery(q);
    if (nl.handled) {
      this._nlBadge.style.display = 'inline-block';
      this.items = nl.items;
      this.results.innerHTML = nl.html;
      this._bindRows();
      return;
    }
    this._nlBadge.style.display = 'none';

    try {
      const res = await api.get(`/api/search?q=${encodeURIComponent(q)}`);
      if (!res.success || !res.data) throw new Error();
      const { students, seats, plans, payments, actions } = res.data;
      let html = '';

      const sec = (icon, lbl) => `<div style="padding:6px 12px 4px;font-weight:700;font-size:0.72rem;text-transform:uppercase;color:var(--color-text-muted);letter-spacing:0.5px;">${icon} ${lbl}</div>`;
      const rowHtml = (idx, link, left, right) => `<div class="search-result-row" data-idx="${idx}" data-link="${link}" style="padding:10px 14px;border-radius:6px;cursor:pointer;display:flex;align-items:center;justify-content:space-between;margin-bottom:2px;">${left}${right}</div>`;

      if (actions?.length) {
        html += sec('⚡','Quick Actions');
        actions.forEach(a => {
          this.items.push({ link: a.link, title: a.label });
          html += rowHtml(this.items.length-1, a.link,
            `<div style="display:flex;align-items:center;gap:10px;"><span style="font-size:1.1rem;">${a.icon||'⚡'}</span><strong style="font-size:0.92rem;">${this.escapeHTML(a.label)}</strong></div>`,
            `<span class="badge" style="background:rgba(108,92,231,0.15);color:var(--color-primary);font-size:0.7rem;">Action</span>`);
        });
      }
      if (students?.length) {
        html += sec('🧑‍🎓','Students');
        students.forEach(s => {
          this.items.push({ link: '#/students', title: s.name });
          html += rowHtml(this.items.length-1, '#/students',
            `<div><strong>${this.escapeHTML(s.name)}</strong><span class="text-muted small" style="margin-left:8px;">(${this.escapeHTML(s.studentId||s.phone||'')})</span></div>`,
            `<span class="badge" style="background:rgba(0,184,148,0.15);color:var(--color-success);font-size:0.7rem;">${this.escapeHTML(s.status||'Active')}</span>`);
        });
      }
      if (seats?.length) {
        html += sec('💺','Seats');
        seats.forEach(st => {
          this.items.push({ link: '#/seats', title: st.seatNumber });
          html += rowHtml(this.items.length-1, '#/seats',
            `<div><strong>Seat ${this.escapeHTML(st.seatNumber)}</strong><span class="text-muted small" style="margin-left:8px;">(${this.escapeHTML(st.zone||'')})</span></div>`,
            `<span class="badge" style="background:rgba(9,132,227,0.15);color:var(--color-info);font-size:0.7rem;">${this.escapeHTML(st.status)}</span>`);
        });
      }
      if (plans?.length) {
        html += sec('📋','Plans');
        plans.forEach(p => {
          this.items.push({ link: '#/plans', title: p.name });
          html += rowHtml(this.items.length-1, '#/plans',
            `<div><strong>${this.escapeHTML(p.name)}</strong><span class="text-muted small" style="margin-left:8px;">Rs.${p.price} (${p.duration} ${p.durationType})</span></div>`,
            `<span class="badge" style="background:rgba(108,92,231,0.15);color:var(--color-primary);font-size:0.7rem;">Plan</span>`);
        });
      }
      if (payments?.length) {
        html += sec('💰','Payments');
        payments.forEach(py => {
          this.items.push({ link: '#/payments', title: py.receiptNumber });
          html += rowHtml(this.items.length-1, '#/payments',
            `<div><strong style="font-family:monospace;">${this.escapeHTML(py.receiptNumber||'REC')}</strong><span class="text-muted small" style="margin-left:8px;">${this.escapeHTML(py.student?.name||'')}</span></div>`,
            `<span style="font-weight:700;color:var(--color-success);">Rs.${py.finalAmount}</span>`);
        });
      }

      if (!html) {
        html = `<div style="padding:24px 20px;text-align:center;color:var(--color-text-muted);">
          <div style="font-size:2rem;margin-bottom:8px;">🔍</div>
          <div style="font-weight:600;margin-bottom:4px;">No results for "${this.escapeHTML(q)}"</div>
          <div style="font-size:0.78rem;margin-bottom:14px;opacity:0.7;">Try natural language — the search understands plain English</div>
          <div style="display:flex;flex-wrap:wrap;gap:6px;justify-content:center;">
            ${NL_EXAMPLES.map(s => `<span class="nl-suggestion" data-q="${s}" style="padding:4px 10px;border-radius:12px;font-size:0.75rem;cursor:pointer;background:rgba(108,92,231,0.12);color:var(--color-primary);border:1px solid rgba(108,92,231,0.25);">${s}</span>`).join('')}
          </div></div>`;
      }

      this.results.innerHTML = html;
      this.results.querySelectorAll('.nl-suggestion').forEach(c => {
        c.addEventListener('click', () => { this.input.value = c.dataset.q; this.search(c.dataset.q); });
      });
      this._bindRows();
    } catch (e) {
      this.results.innerHTML = '<div style="padding:20px;text-align:center;color:var(--color-text-muted);">Search unavailable</div>';
    }
  }

  _bindRows() {
    this.results.querySelectorAll('.search-result-row').forEach(row => {
      row.addEventListener('click', () => {
        const link = row.dataset.link;
        this.close();
        if (!link) return;
        if (link.startsWith('/') && !link.startsWith('/#')) window.location.href = link;
        else window.location.hash = link.replace(/^#/, '');
      });
      row.addEventListener('mouseenter', () => {
        this.results.querySelectorAll('.search-result-row').forEach(r => r.style.background = 'transparent');
        row.style.background = 'var(--color-bg-secondary,rgba(255,255,255,0.06))';
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
      const item = this.items[this.selectedIndex];
      if (!item?.link) return;
      this.close();
      if (item.link.startsWith('/') && !item.link.startsWith('/#')) window.location.href = item.link;
      else window.location.hash = item.link.replace(/^#/, '');
    }
  }

  highlightSelected(rows) {
    rows.forEach((r, i) => {
      r.style.background = i === this.selectedIndex ? 'var(--color-primary-bg,rgba(108,92,231,0.2))' : 'transparent';
      if (i === this.selectedIndex) r.scrollIntoView({ block: 'nearest' });
    });
  }

  escapeHTML(str) {
    if (str == null) return '';
    return String(str).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
  }
}
