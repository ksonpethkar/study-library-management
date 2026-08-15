import api from '../api.js';
import { Toast, Modal, Confirm, Loading, escapeHTML } from '../ui.js';
import { MediaStudio, MediaFieldPicker } from '../mediaStudio.js';
import { t } from '../i18n.js';

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';

  container.innerHTML = `
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>📢 Library Operations & Community Suite</h2>
        <p>Manage walk-in visitors, digital notice board, holiday calendars, lost & found, and student feedback.</p>
      </div>
    </div>

    <!-- Tabs Navigation -->
    <div style="border-bottom: 1px solid var(--color-border); margin-bottom: 1.5rem; overflow-x: auto;">
      <div style="display: flex; gap: 0.5rem; min-width: max-content;">
        <button class="ops-tab-btn active" data-tab="visitors" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 600; background: none; border: none; border-bottom: 3px solid var(--color-primary); color: var(--color-primary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>📋</span> Visitor & Inquiry Leads
        </button>
        <button class="ops-tab-btn" data-tab="notices" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>📢</span> Notice Board
        </button>
        <button class="ops-tab-btn" data-tab="holidays" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>📅</span> Holiday Calendar
        </button>
        <button class="ops-tab-btn" data-tab="lostfound" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>🔍</span> Lost & Found
        </button>
        <button class="ops-tab-btn" data-tab="feedback" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>💬</span> Student Feedback
        </button>
        <button class="ops-tab-btn" data-tab="leaves" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>🌴</span> Leave Requests
        </button>
        <button class="ops-tab-btn" data-tab="seatchanges" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>💺</span> Seat Changes
        </button>
        <button class="ops-tab-btn" data-tab="referrals" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>🎁</span> Student Referrals
        </button>
      </div>
    </div>

    <!-- Tab Panels Container -->
    <div id="ops-panel-content">
      <div class="text-center p-5 text-muted">Loading operations...</div>
    </div>
  `;

  // Tab Switching Logic
  const tabBtns = container.querySelectorAll('.ops-tab-btn');
  let currentTab = 'visitors';

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      currentTab = btn.dataset.tab;
      tabBtns.forEach(b => {
        const isCurrent = b === btn;
        b.style.borderBottomColor = isCurrent ? 'var(--color-primary)' : 'transparent';
        b.style.color = isCurrent ? 'var(--color-primary)' : 'var(--color-text-secondary)';
        b.style.fontWeight = isCurrent ? '600' : '500';
      });
      loadCurrentTab();
    });
  });

  async function loadCurrentTab() {
    const panel = container.querySelector('#ops-panel-content');
    panel.innerHTML = '<div class="text-center p-5 text-muted"><div class="loading-spinner mb-2"></div>Loading data...</div>';

    if (currentTab === 'visitors') await renderVisitors(panel);
    else if (currentTab === 'notices') await renderNotices(panel);
    else if (currentTab === 'holidays') await renderHolidays(panel);
    else if (currentTab === 'lostfound') await renderLostFound(panel);
    else if (currentTab === 'feedback') await renderFeedback(panel);
    else if (currentTab === 'leaves') await renderLeaves(panel);
    else if (currentTab === 'seatchanges') await renderSeatChanges(panel);
    else if (currentTab === 'referrals') await renderReferrals(panel);
  }

  // ----------------------------------------------------
  // Tab 1: Visitors & Leads
  // ----------------------------------------------------
  async function renderVisitors(panel) {
    try {
      const res = await api.get('/api/operations/visitors');
      const visitors = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">📋 Walk-in Visitors & Inquiry Leads (${visitors.length})</h3>
          <button id="btn-add-visitor" class="btn btn-primary btn-sm">+ Log New Visitor</button>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Visitor Name</th>
                  <th style="padding: 12px 16px;">Phone</th>
                  <th style="padding: 12px 16px;">Target Exam</th>
                  <th style="padding: 12px 16px;">Preferred Shift</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Date</th>
                  <th style="padding: 12px 16px;">Action</th>
                </tr>
              </thead>
              <tbody>
                ${visitors.length > 0 ? visitors.map(v => `
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;"><strong>${escapeHTML(v.name)}</strong></td>
                    <td style="padding: 12px 16px;">${escapeHTML(v.phone)}</td>
                    <td style="padding: 12px 16px;"><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary);">${escapeHTML(v.targetExam || 'General')}</span></td>
                    <td style="padding: 12px 16px;">${escapeHTML(v.preferredSlot || 'Full Day')}</td>
                    <td style="padding: 12px 16px;"><span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); text-transform: uppercase;">${escapeHTML(v.status)}</span></td>
                    <td style="padding: 12px 16px;">${new Date(v.createdAt).toLocaleDateString('en-IN')}</td>
                    <td style="padding: 12px 16px;">
                      <button class="btn btn-sm btn-outline-danger btn-delete-visitor" data-id="${v._id}" style="padding: 2px 8px; font-size: 0.75rem;">Delete</button>
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="7" class="p-4 text-center text-muted">No visitors logged yet. Click "+ Log New Visitor" to record walk-in leads.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `;

      panel.querySelector('#btn-add-visitor')?.addEventListener('click', () => {
        const modalHtml = `
          <form id="visitorForm">
            <div class="row" style="row-gap: 12px;">
              <div class="col-md-6">
                <label class="form-label">Full Name *</label>
                <input type="text" class="form-control" name="name" required placeholder="e.g. Vikas Patil">
              </div>
              <div class="col-md-6">
                <label class="form-label">Phone Number *</label>
                <input type="tel" class="form-control" name="phone" required placeholder="10 digit mobile">
              </div>
              <div class="col-md-6">
                <label class="form-label">Target Exam</label>
                <input type="text" class="form-control" name="targetExam" placeholder="e.g. UPSC / MPSC">
              </div>
              <div class="col-md-6">
                <label class="form-label">Preferred Shift Slot</label>
                <select class="form-select form-control" name="preferredSlot">
                  <option value="Morning">Morning (06:00 - 14:00)</option>
                  <option value="Evening">Evening (14:00 - 22:00)</option>
                  <option value="Full Day" selected>Full Day (06:00 - 22:00)</option>
                  <option value="Night">Night (22:00 - 06:00)</option>
                </select>
              </div>
              <div class="col-12">
                <label class="form-label">Inquiry Notes</label>
                <textarea class="form-control" name="notes" rows="2" placeholder="Notes on seat preference, demo trial..."></textarea>
              </div>
            </div>
          </form>
        `;

        const vModal = new Modal({
          title: 'Log New Walk-In Visitor',
          content: modalHtml,
          size: 'md',
          buttons: [
            { text: 'Cancel', className: 'btn-secondary', onClick: (m) => m.close() },
            {
              text: 'Save Visitor',
              className: 'btn-primary',
              onClick: async (m) => {
                const form = m.element.querySelector('#visitorForm');
                if (!form.checkValidity()) { form.reportValidity(); return; }
                const data = Object.fromEntries(new FormData(form).entries());
                try {
                  const sRes = await api.post('/api/operations/visitors', data);
                  if (sRes.success) {
                    Toast.success(sRes.message);
                    m.close();
                    loadCurrentTab();
                  }
                } catch (err) { Toast.error(err.message); }
              }
            }
          ]
        });
        vModal.show();
      });

      panel.querySelectorAll('.btn-delete-visitor').forEach(btn => {
        btn.addEventListener('click', () => {
          Confirm.show({
            title: 'Delete Visitor Record',
            message: 'Are you sure you want to remove this inquiry?',
            danger: true,
            onConfirm: async () => {
              await api.delete(`/api/operations/visitors/${btn.dataset.id}`);
              Toast.success('Visitor removed');
              loadCurrentTab();
            }
          });
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load visitors</div>`; }
  }

  // ----------------------------------------------------
  // Tab 2: Notice Board
  // ----------------------------------------------------
  async function renderNotices(panel) {
    try {
      const res = await api.get('/api/operations/announcements');
      const notices = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">📢 Digital Notice Board (${notices.length})</h3>
          <button id="btn-add-notice" class="btn btn-primary btn-sm">+ Post New Notice</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1.25rem;">
          ${notices.length > 0 ? notices.map(n => `
            <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); position: relative;">
              <div class="d-flex justify-content-between align-items-start mb-2">
                <span class="badge" style="background: ${n.priority === 'urgent' ? 'rgba(214,48,49,0.2)' : 'rgba(108,92,231,0.15)'}; color: ${n.priority === 'urgent' ? 'var(--color-danger)' : 'var(--color-primary)'}; font-weight: 700; text-transform: uppercase; font-size: 0.7rem;">
                  ${escapeHTML(n.category)} • ${escapeHTML(n.priority)}
                </span>
                <button class="btn btn-sm btn-outline-danger btn-delete-notice" data-id="${n._id}" style="padding: 1px 6px; font-size: 0.75rem;">✕</button>
              </div>
              <h4 style="margin: 0 0 8px 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary);">${escapeHTML(n.title)}</h4>
              <p style="margin: 0 0 12px 0; font-size: 0.88rem; color: var(--color-text-secondary); line-height: 1.5;">${escapeHTML(n.message)}</p>
              <div class="text-muted small" style="font-size: 0.75rem;">Posted on ${new Date(n.createdAt).toLocaleDateString('en-IN')}</div>
            </div>
          `).join('') : `
            <div class="col-12 p-5 text-center text-muted card" style="grid-column: 1/-1;">No notices published. Click "+ Post New Notice" to broadcast to members.</div>
          `}
        </div>
      `;

      panel.querySelector('#btn-add-notice')?.addEventListener('click', () => {
        const modalHtml = `
          <form id="noticeForm">
            <div class="form-group mb-3">
              <label class="form-label">Notice Title *</label>
              <input type="text" class="form-control" name="title" required placeholder="e.g. WiFi Maintenance on Sunday 6 AM">
            </div>
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Category</label>
                <select class="form-select form-control" name="category">
                  <option value="general">General Announcement</option>
                  <option value="holiday">Holiday Notice</option>
                  <option value="rules">Library Rules</option>
                  <option value="exam_alert">Exam Schedule</option>
                  <option value="maintenance">Facility Maintenance</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Priority</label>
                <select class="form-select form-control" name="priority">
                  <option value="normal">Normal</option>
                  <option value="high">Important (High)</option>
                  <option value="urgent">Urgent / Alert</option>
                </select>
              </div>
            </div>
            <div class="form-group mb-2">
              <label class="form-label">Notice Message *</label>
              <textarea class="form-control" name="message" rows="3" required placeholder="Detailed message for students..."></textarea>
            </div>
          </form>
        `;

        const nModal = new Modal({
          title: 'Post New Notice',
          content: modalHtml,
          size: 'md',
          buttons: [
            { text: 'Cancel', className: 'btn-secondary', onClick: (m) => m.close() },
            {
              text: 'Publish Notice',
              className: 'btn-primary',
              onClick: async (m) => {
                const form = m.element.querySelector('#noticeForm');
                if (!form.checkValidity()) { form.reportValidity(); return; }
                const data = Object.fromEntries(new FormData(form).entries());
                try {
                  const sRes = await api.post('/api/operations/announcements', data);
                  if (sRes.success) {
                    Toast.success(sRes.message);
                    m.close();
                    loadCurrentTab();
                  }
                } catch (err) { Toast.error(err.message); }
              }
            }
          ]
        });
        nModal.show();
      });

      panel.querySelectorAll('.btn-delete-notice').forEach(btn => {
        btn.addEventListener('click', () => {
          Confirm.show({
            title: 'Delete Notice',
            message: 'Remove this notice from the board?',
            danger: true,
            onConfirm: async () => {
              await api.delete(`/api/operations/announcements/${btn.dataset.id}`);
              Toast.success('Notice removed');
              loadCurrentTab();
            }
          });
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load notices</div>`; }
  }

  // ----------------------------------------------------
  // Tab 3: Holidays & Schedule
  // ----------------------------------------------------
  async function renderHolidays(panel) {
    try {
      const res = await api.get('/api/operations/holidays');
      const holidays = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">📅 Library Holiday & Event Schedule (${holidays.length})</h3>
          <button id="btn-add-holiday" class="btn btn-primary btn-sm">+ Schedule Holiday</button>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Holiday / Event</th>
                  <th style="padding: 12px 16px;">Date</th>
                  <th style="padding: 12px 16px;">Type</th>
                  <th style="padding: 12px 16px;">Library Status</th>
                  <th style="padding: 12px 16px;">Timing Override</th>
                  <th style="padding: 12px 16px;">Action</th>
                </tr>
              </thead>
              <tbody>
                ${holidays.length > 0 ? holidays.map(h => `
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;"><strong>${escapeHTML(h.title)}</strong></td>
                    <td style="padding: 12px 16px;">${new Date(h.date).toLocaleDateString('en-IN', { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric' })}</td>
                    <td style="padding: 12px 16px;"><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); text-transform: capitalize;">${escapeHTML(h.type)}</span></td>
                    <td style="padding: 12px 16px;">
                      <span class="badge" style="background: ${h.isLibraryClosed ? 'rgba(214,48,49,0.2)' : 'rgba(0,184,148,0.2)'}; color: ${h.isLibraryClosed ? 'var(--color-danger)' : 'var(--color-success)'};">
                        ${h.isLibraryClosed ? '🔴 Closed' : '🟢 Open (Special Timings)'}
                      </span>
                    </td>
                    <td style="padding: 12px 16px;">${escapeHTML(h.timingOverride || 'Standard 24x7')}</td>
                    <td style="padding: 12px 16px;">
                      <button class="btn btn-sm btn-outline-danger btn-delete-holiday" data-id="${h._id}" style="padding: 2px 8px; font-size: 0.75rem;">Delete</button>
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="6" class="p-4 text-center text-muted">No scheduled holidays.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `;

      panel.querySelector('#btn-add-holiday')?.addEventListener('click', () => {
        const modalHtml = `
          <form id="holidayForm">
            <div class="form-group mb-3">
              <label class="form-label">Holiday / Festival Name *</label>
              <input type="text" class="form-control" name="title" required placeholder="e.g. Diwali Festival / Independence Day">
            </div>
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Date *</label>
                <input type="date" class="form-control" name="date" required value="${new Date().toISOString().split('T')[0]}">
              </div>
              <div class="col-md-6">
                <label class="form-label">Holiday Category</label>
                <select class="form-select form-control" name="type">
                  <option value="national">National Holiday</option>
                  <option value="festival" selected>Festival</option>
                  <option value="maintenance">Maintenance Day</option>
                  <option value="special">Special Event</option>
                </select>
              </div>
            </div>
            <div class="form-group mb-3">
              <label class="form-label">Special Timing (if open)</label>
              <input type="text" class="form-control" name="timingOverride" placeholder="e.g. Open 08:00 AM - 06:00 PM only">
            </div>
            <div class="form-check mb-2">
              <label><input type="checkbox" name="isLibraryClosed" value="true"> Entire Library Closed on this date</label>
            </div>
          </form>
        `;

        const hModal = new Modal({
          title: 'Schedule Library Holiday',
          content: modalHtml,
          size: 'md',
          buttons: [
            { text: 'Cancel', className: 'btn-secondary', onClick: (m) => m.close() },
            {
              text: 'Save Holiday',
              className: 'btn-primary',
              onClick: async (m) => {
                const form = m.element.querySelector('#holidayForm');
                if (!form.checkValidity()) { form.reportValidity(); return; }
                const data = Object.fromEntries(new FormData(form).entries());
                data.isLibraryClosed = !!data.isLibraryClosed;
                try {
                  const sRes = await api.post('/api/operations/holidays', data);
                  if (sRes.success) {
                    Toast.success(sRes.message);
                    m.close();
                    loadCurrentTab();
                  }
                } catch (err) { Toast.error(err.message); }
              }
            }
          ]
        });
        hModal.show();
      });

      panel.querySelectorAll('.btn-delete-holiday').forEach(btn => {
        btn.addEventListener('click', () => {
          Confirm.show({
            title: 'Delete Holiday',
            message: 'Remove this date from the holiday list?',
            danger: true,
            onConfirm: async () => {
              await api.delete(`/api/operations/holidays/${btn.dataset.id}`);
              Toast.success('Holiday removed');
              loadCurrentTab();
            }
          });
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load holidays</div>`; }
  }

  // ----------------------------------------------------
  // Tab 4: Lost & Found
  // ----------------------------------------------------
  async function renderLostFound(panel) {
    try {
      const res = await api.get('/api/operations/lostfound');
      const items = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">🔍 Lost & Found Register (${items.length})</h3>
          <button id="btn-add-lost" class="btn btn-primary btn-sm">+ Log Found Item</button>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Item Name</th>
                  <th style="padding: 12px 16px;">Category</th>
                  <th style="padding: 12px 16px;">Found Location</th>
                  <th style="padding: 12px 16px;">Found Date</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Claimed By</th>
                  <th style="padding: 12px 16px;">Action</th>
                </tr>
              </thead>
              <tbody>
                ${items.length > 0 ? items.map(it => `
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;"><strong>${escapeHTML(it.itemName)}</strong></td>
                    <td style="padding: 12px 16px;"><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); text-transform: capitalize;">${escapeHTML(it.category)}</span></td>
                    <td style="padding: 12px 16px;">${escapeHTML(it.foundLocation || 'Desk / Cabin')}</td>
                    <td style="padding: 12px 16px;">${new Date(it.foundDate).toLocaleDateString('en-IN')}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge" style="background: ${it.status === 'claimed' ? 'rgba(0,184,148,0.2)' : 'rgba(253,203,110,0.2)'}; color: ${it.status === 'claimed' ? 'var(--color-success)' : 'var(--color-warning)'}; text-transform: uppercase;">
                        ${escapeHTML(it.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px;">${escapeHTML(it.claimedBy || '-')}</td>
                    <td style="padding: 12px 16px;">
                      ${it.status === 'found' ? `<button class="btn btn-sm btn-outline-success btn-claim-item" data-id="${it._id}" style="padding: 2px 8px; font-size: 0.75rem;">Mark Claimed</button>` : ''}
                      <button class="btn btn-sm btn-outline-danger btn-delete-item" data-id="${it._id}" style="padding: 2px 8px; font-size: 0.75rem;">Delete</button>
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="7" class="p-4 text-center text-muted">No items in the lost & found register.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `;

      panel.querySelector('#btn-add-lost')?.addEventListener('click', () => {
        const modalHtml = `
          <form id="lostForm">
            <div class="form-group mb-3">
              <label class="form-label">Item Description *</label>
              <input type="text" class="form-control" name="itemName" required placeholder="e.g. Boat Airdopes Black Case / Fastrack Watch">
            </div>
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Category</label>
                <select class="form-select form-control" name="category">
                  <option value="electronics">Electronics (Earphones/Charger)</option>
                  <option value="books">Books & Notebooks</option>
                  <option value="stationery">Stationery (Pouch/Calculators)</option>
                  <option value="clothing">Clothing / Bottles</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Found Location</label>
                <input type="text" class="form-control" name="foundLocation" placeholder="e.g. Cabin Seat B-05">
              </div>
            </div>
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Item Photo (Live Snap / Upload)</label>
              <div id="mount-lost-photo"></div>
            </div>
          </form>
        `;

        const lModal = new Modal({
          title: 'Log Found Item in Vault',
          content: modalHtml,
          size: 'md',
          buttons: [
            { text: 'Cancel', className: 'btn-secondary', onClick: (m) => m.close() },
            {
              text: 'Save Item',
              className: 'btn-primary',
              onClick: async (m) => {
                const form = m.element.querySelector('#lostForm');
                if (!form.checkValidity()) { form.reportValidity(); return; }
                const data = Object.fromEntries(new FormData(form).entries());
                try {
                  const sRes = await api.post('/api/operations/lostfound', data);
                  if (sRes.success) {
                    Toast.success(sRes.message);
                    m.close();
                    loadCurrentTab();
                  }
                } catch (err) { Toast.error(err.message); }
              }
            }
          ]
        });
        lModal.show();

        const lostMount = lModal.element.querySelector('#mount-lost-photo');
        if (lostMount) {
          lostMount.appendChild(MediaFieldPicker.create({
            label: 'Found Item Photo',
            preset: 'general',
            name: 'image'
          }));
        }
      });

      panel.querySelectorAll('.btn-claim-item').forEach(btn => {
        btn.addEventListener('click', async () => {
          const claimName = prompt('Enter student name or roll number claiming this item:');
          if (!claimName) return;
          await api.put(`/api/operations/lostfound/${btn.dataset.id}`, { status: 'claimed', claimedBy: claimName });
          Toast.success('Item marked as claimed');
          loadCurrentTab();
        });
      });

      panel.querySelectorAll('.btn-delete-item').forEach(btn => {
        btn.addEventListener('click', () => {
          Confirm.show({
            title: 'Delete Item',
            message: 'Remove item from register?',
            danger: true,
            onConfirm: async () => {
              await api.delete(`/api/operations/lostfound/${btn.dataset.id}`);
              Toast.success('Record deleted');
              loadCurrentTab();
            }
          });
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load lost & found</div>`; }
  }

  // ----------------------------------------------------
  // Tab 5: Student Feedback & Complaints
  // ----------------------------------------------------
  async function renderFeedback(panel) {
    try {
      const res = await api.get('/api/operations/feedback');
      const feedbacks = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">💬 Student Feedback & Complaints (${feedbacks.length})</h3>
          <button id="btn-add-feedback" class="btn btn-primary btn-sm">+ Submit Feedback</button>
        </div>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1.25rem;">
          ${feedbacks.length > 0 ? feedbacks.map(fb => `
            <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
              <div class="d-flex justify-content-between align-items-start mb-2">
                <span class="badge" style="background: rgba(108,92,231,0.15); color: var(--color-primary); text-transform: capitalize;">
                  ${escapeHTML(fb.category)}
                </span>
                <span style="color: #f39c12; font-size: 0.9rem;">${'★'.repeat(fb.rating || 5)}${'☆'.repeat(5 - (fb.rating || 5))}</span>
              </div>
              <h4 style="margin: 0 0 6px 0; font-size: 1rem; font-weight: 700;">${escapeHTML(fb.studentName)}</h4>
              <p style="margin: 0 0 10px 0; font-size: 0.88rem; color: var(--color-text-secondary);">${escapeHTML(fb.message)}</p>
              ${fb.adminReply ? `
                <div style="background: var(--color-bg-primary); padding: 8px 12px; border-radius: 6px; font-size: 0.8rem; border-left: 3px solid var(--color-success); margin-bottom: 8px;">
                  <strong>Admin Reply:</strong> ${escapeHTML(fb.adminReply)}
                </div>
              ` : ''}
              <div class="d-flex justify-content-between align-items-center mt-2 pt-2" style="border-top: 1px solid var(--color-divider);">
                <span class="badge" style="background: ${fb.status === 'resolved' ? 'rgba(0,184,148,0.2)' : 'rgba(253,203,110,0.2)'}; color: ${fb.status === 'resolved' ? 'var(--color-success)' : 'var(--color-warning)'};">
                  ${escapeHTML(fb.status)}
                </span>
                <button class="btn btn-sm btn-outline-primary btn-reply-feedback" data-id="${fb._id}" style="font-size: 0.75rem; padding: 2px 8px;">Reply</button>
              </div>
            </div>
          `).join('') : `
            <div class="col-12 p-5 text-center text-muted card" style="grid-column: 1/-1;">No complaints or feedback submitted.</div>
          `}
        </div>
      `;

      panel.querySelector('#btn-add-feedback')?.addEventListener('click', () => {
        const modalHtml = `
          <form id="feedbackForm">
            <div class="form-group mb-3">
              <label class="form-label">Student Name *</label>
              <input type="text" class="form-control" name="studentName" required placeholder="e.g. Anjali Deshmukh">
            </div>
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Category</label>
                <select class="form-select form-control" name="category">
                  <option value="cleanliness">Cleanliness & Hygiene</option>
                  <option value="ac_wifi">AC / WiFi Speed</option>
                  <option value="noise">Noise / Silence</option>
                  <option value="seats">Chair / Desk Comfort</option>
                  <option value="management">Management / Staff</option>
                  <option value="other">Other</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Rating (1 to 5 Stars)</label>
                <select class="form-select form-control" name="rating">
                  <option value="5" selected>★★★★★ (5 Stars - Excellent)</option>
                  <option value="4">★★★★☆ (4 Stars - Good)</option>
                  <option value="3">★★★☆☆ (3 Stars - Average)</option>
                  <option value="2">★★☆☆☆ (2 Stars - Needs Improvement)</option>
                  <option value="1">★☆☆☆☆ (1 Star - Urgent Issue)</option>
                </select>
              </div>
            </div>
            <div class="form-group mb-2">
              <label class="form-label">Feedback / Suggestion *</label>
              <textarea class="form-control" name="message" rows="3" required placeholder="Describe your experience or complaint..."></textarea>
            </div>
          </form>
        `;

        const fModal = new Modal({
          title: 'Submit Student Feedback',
          content: modalHtml,
          size: 'md',
          buttons: [
            { text: 'Cancel', className: 'btn-secondary', onClick: (m) => m.close() },
            {
              text: 'Submit Feedback',
              className: 'btn-primary',
              onClick: async (m) => {
                const form = m.element.querySelector('#feedbackForm');
                if (!form.checkValidity()) { form.reportValidity(); return; }
                const data = Object.fromEntries(new FormData(form).entries());
                data.rating = parseInt(data.rating, 10);
                try {
                  const sRes = await api.post('/api/operations/feedback', data);
                  if (sRes.success) {
                    Toast.success(sRes.message);
                    m.close();
                    loadCurrentTab();
                  }
                } catch (err) { Toast.error(err.message); }
              }
            }
          ]
        });
        fModal.show();
      });

      panel.querySelectorAll('.btn-reply-feedback').forEach(btn => {
        btn.addEventListener('click', async () => {
          const reply = prompt('Enter administrative reply / resolution message:');
          if (!reply) return;
          await api.put(`/api/operations/feedback/${btn.dataset.id}/reply`, { adminReply: reply, status: 'resolved' });
          Toast.success('Reply saved & status resolved');
          loadCurrentTab();
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load feedback</div>`; }
  }

  // ----------------------------------------------------
  // Tab 6: Leave Applications
  // ----------------------------------------------------
  async function renderLeaves(panel) {
    try {
      const res = await api.get('/api/operations/leave-requests');
      const leaves = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">🌴 Student Absence & Leave Requests (${leaves.length})</h3>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Student</th>
                  <th style="padding: 12px 16px;">Dates</th>
                  <th style="padding: 12px 16px;">Reason</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Reply</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${leaves.length > 0 ? leaves.map(l => `
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;">
                      <strong>${escapeHTML(l.studentName)}</strong>
                      <div class="text-muted small">${escapeHTML(l.studentPhone || '-')}</div>
                    </td>
                    <td style="padding: 12px 16px; font-weight: 500;">
                      ${new Date(l.startDate).toLocaleDateString('en-IN')} - ${new Date(l.endDate).toLocaleDateString('en-IN')}
                    </td>
                    <td style="padding: 12px 16px;">${escapeHTML(l.reason)}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge ${l.status === 'approved' ? 'badge-success' : l.status === 'rejected' ? 'badge-danger' : 'badge-warning'}" style="text-transform: uppercase; font-size: 0.75rem;">
                        ${escapeHTML(l.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px; font-size: 0.8rem; color: var(--color-text-secondary);">${escapeHTML(l.adminReply || '-')}</td>
                    <td style="padding: 12px 16px; text-align: center;">
                      ${l.status === 'pending' ? `
                        <div class="d-flex justify-content-center gap-1">
                          <button class="btn btn-sm btn-success btn-approve-leave" data-id="${l._id}" style="padding: 2px 8px; font-size: 0.75rem;">✓ Approve</button>
                          <button class="btn btn-sm btn-outline-danger btn-reject-leave" data-id="${l._id}" style="padding: 2px 8px; font-size: 0.75rem;">✕ Reject</button>
                        </div>
                      ` : `<span class="text-muted small">-</span>`}
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="6" class="p-4 text-center text-muted">No leave applications submitted yet.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `;

      panel.querySelectorAll('.btn-approve-leave').forEach(btn => {
        btn.addEventListener('click', async () => {
          const reply = prompt('Optional approval message / note for student:');
          await api.put(`/api/operations/leave-requests/${btn.dataset.id}`, { status: 'approved', adminReply: reply || 'Approved. Safe travels!' });
          Toast.success('Leave approved');
          loadCurrentTab();
        });
      });

      panel.querySelectorAll('.btn-reject-leave').forEach(btn => {
        btn.addEventListener('click', async () => {
          const reply = prompt('Reason for rejection:');
          await api.put(`/api/operations/leave-requests/${btn.dataset.id}`, { status: 'rejected', adminReply: reply || 'Leave request declined.' });
          Toast.warning('Leave rejected');
          loadCurrentTab();
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load leave requests</div>`; }
  }

  // ----------------------------------------------------
  // Tab 7: Seat Change Requests
  // ----------------------------------------------------
  async function renderSeatChanges(panel) {
    try {
      const res = await api.get('/api/operations/seat-changes');
      const reqs = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">💺 Student Desk Transfer Requests (${reqs.length})</h3>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Student</th>
                  <th style="padding: 12px 16px;">Current Seat</th>
                  <th style="padding: 12px 16px;">Requested Zone</th>
                  <th style="padding: 12px 16px;">Reason</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${reqs.length > 0 ? reqs.map(r => `
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;">
                      <strong>${escapeHTML(r.studentName)}</strong>
                      <div class="text-muted small">${escapeHTML(r.studentPhone || '-')}</div>
                    </td>
                    <td style="padding: 12px 16px; font-weight: 700; color: var(--color-primary);">
                      ${escapeHTML(r.currentSeat?.seatNumber || r.currentSeatNumber || '-')}
                    </td>
                    <td style="padding: 12px 16px;"><span class="badge badge-primary">${escapeHTML(r.preferredZone)}</span></td>
                    <td style="padding: 12px 16px;">${escapeHTML(r.reason)}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge ${r.status === 'approved' ? 'badge-success' : r.status === 'rejected' ? 'badge-danger' : 'badge-warning'}" style="text-transform: uppercase; font-size: 0.75rem;">
                        ${escapeHTML(r.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px; text-align: center;">
                      ${r.status === 'pending' ? `
                        <div class="d-flex justify-content-center gap-1">
                          <button class="btn btn-sm btn-success btn-transfer-seat" data-id="${r._id}" data-name="${escapeHTML(r.studentName)}" style="padding: 2px 8px; font-size: 0.75rem;">Allocate & Approve</button>
                          <button class="btn btn-sm btn-outline-danger btn-reject-sc" data-id="${r._id}" style="padding: 2px 8px; font-size: 0.75rem;">✕ Reject</button>
                        </div>
                      ` : `<span class="text-muted small">-</span>`}
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="6" class="p-4 text-center text-muted">No seat transfer requests submitted.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `;

      panel.querySelectorAll('.btn-transfer-seat').forEach(btn => {
        btn.addEventListener('click', async () => {
          const sRes = await api.get('/api/seats?status=available');
          const availSeats = sRes.data?.seats || [];
          if (availSeats.length === 0) {
            Toast.warning('No available seats to allocate.');
            return;
          }

          const selectModalContent = document.createElement('div');
          selectModalContent.innerHTML = `
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Choose New Seat for ${escapeHTML(btn.dataset.name)}</label>
              <select id="transfer-seat-select" class="form-select">
                ${availSeats.map(s => `<option value="${s._id}">${escapeHTML(s.seatNumber)} (${escapeHTML(s.zone)} - ${escapeHTML(s.type)})</option>`).join('')}
              </select>
            </div>
            <div class="d-flex justify-content-end gap-2">
              <button class="btn btn-primary" id="btn-confirm-transfer">Transfer Seat & Approve</button>
            </div>
          `;

          const m = new Modal({ title: '💺 Transfer Student Seat', content: selectModalContent, size: 'sm' });
          m.show();

          selectModalContent.querySelector('#btn-confirm-transfer').onclick = async () => {
            const allocatedSeatId = selectModalContent.querySelector('#transfer-seat-select').value;
            try {
              await api.put(`/api/operations/seat-changes/${btn.dataset.id}`, {
                status: 'approved',
                allocatedSeatId,
                adminReply: 'Seat transfer approved and allocated.'
              });
              Toast.success('Seat transferred successfully!');
              m.close();
              loadCurrentTab();
            } catch (err) {
              Toast.error(err.message || 'Transfer failed');
            }
          };
        });
      });

      panel.querySelectorAll('.btn-reject-sc').forEach(btn => {
        btn.addEventListener('click', async () => {
          const reply = prompt('Reason for rejecting seat transfer:');
          await api.put(`/api/operations/seat-changes/${btn.dataset.id}`, { status: 'rejected', adminReply: reply || 'Seats in that zone are currently full.' });
          Toast.warning('Request rejected');
          loadCurrentTab();
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load seat change requests</div>`; }
  }

  // ----------------------------------------------------
  // Tab 8: Student Referrals
  // ----------------------------------------------------
  async function renderReferrals(panel) {
    try {
      const res = await api.get('/api/operations/referrals');
      const referrals = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">🎁 Student Referrals & Inquiries (${referrals.length})</h3>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Referred By (Student)</th>
                  <th style="padding: 12px 16px;">Prospect Friend</th>
                  <th style="padding: 12px 16px;">Friend Phone</th>
                  <th style="padding: 12px 16px;">Course / Exam</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Reward</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${referrals.length > 0 ? referrals.map(r => `
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;">
                      <strong>${escapeHTML(r.referrerName)}</strong>
                      <div class="text-muted small">${escapeHTML(r.referrerPhone || '')}</div>
                    </td>
                    <td style="padding: 12px 16px; font-weight: 600;">${escapeHTML(r.refereeName)}</td>
                    <td style="padding: 12px 16px;">${escapeHTML(r.refereePhone)}</td>
                    <td style="padding: 12px 16px;">${escapeHTML(r.notes || '-')}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge ${r.status === 'converted' || r.status === 'rewarded' ? 'badge-success' : 'badge-warning'}" style="text-transform: uppercase; font-size: 0.75rem;">
                        ${escapeHTML(r.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px; font-size: 0.8rem; color: var(--color-primary); font-weight: 600;">${escapeHTML(r.reward || '₹100 Discount')}</td>
                    <td style="padding: 12px 16px; text-align: center;">
                      ${r.status === 'pending' ? `
                        <div class="d-flex justify-content-center gap-1">
                          <button class="btn btn-sm btn-success btn-convert-ref" data-id="${r._id}" style="padding: 2px 8px; font-size: 0.75rem;">Mark Converted</button>
                        </div>
                      ` : `<span class="text-muted small">✓ Done</span>`}
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="7" class="p-4 text-center text-muted">No student referrals recorded yet.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `;

      panel.querySelectorAll('.btn-convert-ref').forEach(btn => {
        btn.addEventListener('click', async () => {
          try {
            await api.put(`/api/operations/referrals/${btn.dataset.id}`, { status: 'converted' });
            Toast.success('Referral marked as converted! Reward assigned.');
            loadCurrentTab();
          } catch (err) {
            Toast.error('Failed to update referral');
          }
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load referrals</div>`; }
  }

  // Initial load
  loadCurrentTab();

  return container;
}
