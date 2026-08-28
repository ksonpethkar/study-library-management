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

    <!-- Contextual Guidance Tip Banner -->
    <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
      <span style="font-size: 1.1rem;">💡</span>
      <span><strong>Tip:</strong> When a shift reaches max capacity, walk-in candidates are automatically queued here. Convert them to active admissions in 1 click when a seat clears.</span>
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
        <button class="ops-tab-btn" data-tab="waitinglist" style="padding: 0.75rem 1.25rem; font-size: 0.95rem; font-weight: 500; background: none; border: none; border-bottom: 3px solid transparent; color: var(--color-text-secondary); cursor: pointer; display: flex; align-items: center; gap: 0.5rem;">
          <span>⏳</span> Waiting List Queue
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
    else if (currentTab === 'waitinglist') await renderWaitingList(panel);
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
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
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
                      <div class="btn-icon-group">
                        <button type="button" class="btn-icon-action action-verify btn-convert-visitor" data-name="${escapeHTML(v.name)}" data-phone="${escapeHTML(v.phone)}" data-exam="${escapeHTML(v.targetExam || '')}" data-slot="${escapeHTML(v.preferredSlot || '')}" data-tooltip="Convert Lead to Admission" aria-label="Convert Lead">
                          🎓
                        </button>
                        <a href="https://wa.me/91${escapeHTML(v.phone)}?text=${encodeURIComponent(`Hello ${v.name}! Greetings from ${window.store?.settings?.businessName || 'our Study Library'}. Desks are available for your ${v.targetExam || 'study'} preparation. Visit us to reserve your seat today!`)}" target="_blank" class="btn-icon-action action-whatsapp" data-tooltip="Send WhatsApp Invitation" aria-label="WhatsApp">
                          💬
                        </a>
                        <button type="button" class="btn-icon-action action-delete btn-delete-visitor" data-id="${v._id}" data-tooltip="Delete Visitor Lead" aria-label="Delete">🗑️</button>
                      </div>
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="7" class="p-4 text-center text-muted">No visitors logged yet. Click "+ Log New Visitor" to record walk-in leads.</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `;

      panel.querySelectorAll('.btn-convert-visitor').forEach(btn => {
        btn.addEventListener('click', () => {
          const name = btn.dataset.name;
          window.location.hash = '#/students';
          Toast.info(`Converting lead ${name} into active student admission.`);
        });
      });

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
        btn.addEventListener('click', async () => {
          const ok = await Confirm.show({
            title: 'Delete Visitor Record',
            message: 'Are you sure you want to remove this inquiry?',
            danger: true
          });
          if (ok) {
            try {
              await api.delete(`/api/operations/visitors/${btn.dataset.id}`);
              Toast.success('Visitor removed');
              loadCurrentTab();
            } catch (err) {
              Toast.error(err.message || 'Failed to remove visitor');
            }
          }
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
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
          ${notices.length > 0 ? notices.map(n => `
            <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); position: relative;">
              <div class="d-flex justify-content-between align-items-start mb-2">
                <span class="badge" style="background: ${n.priority === 'urgent' ? 'rgba(214,48,49,0.2)' : 'rgba(108,92,231,0.15)'}; color: ${n.priority === 'urgent' ? 'var(--color-danger)' : 'var(--color-primary)'}; font-weight: 700; text-transform: uppercase; font-size: 0.7rem;">
                  ${escapeHTML(n.category)} • ${escapeHTML(n.priority)}
                </span>
                <button type="button" class="btn-icon-action action-delete btn-delete-notice" data-id="${n._id}" data-tooltip="Delete Notice Broadcast" aria-label="Delete">🗑️</button>
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
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 280px), 1fr)); gap: 1rem;">
          ${holidays.length > 0 ? holidays.map(h => `
            <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
              <div class="d-flex justify-content-between align-items-start mb-2">
                <strong style="font-size: 1rem;">${escapeHTML(h.title)}</strong>
                <button class="btn btn-sm text-danger btn-delete-holiday" data-id="${h._id}" style="padding: 0 4px; font-size: 0.9rem;" title="Delete Holiday">🗑️</button>
              </div>
              <div style="font-size: 0.85rem; color: var(--color-primary); font-weight: 600; margin-bottom: 6px;">
                📅 ${new Date(h.date).toLocaleDateString('en-IN', { weekday: 'long', year: 'numeric', month: 'short', day: 'numeric' })}
              </div>
              <p style="font-size: 0.85rem; color: var(--color-text-secondary); margin: 0;">${escapeHTML(h.description || 'Library study rooms will remain closed.')}</p>
            </div>
          `).join('') : `
            <div class="p-4 text-center text-muted" style="grid-column: 1 / -1;">No upcoming holidays scheduled.</div>
          `}
        </div>
      `;

      panel.querySelector('#btn-add-holiday')?.addEventListener('click', () => {
        const modalHtml = `
          <form id="holidayForm">
            <div class="mb-3">
              <label class="form-label">Holiday / Occasion Title *</label>
              <input type="text" class="form-control" name="title" required placeholder="e.g. Republic Day, Diwali Break">
            </div>
            <div class="mb-3">
              <label class="form-label">Date *</label>
              <input type="date" class="form-control" name="date" required value="${new Date().toISOString().split('T')[0]}">
            </div>
            <div class="mb-3">
              <label class="form-label">Description / Instructions</label>
              <textarea class="form-control" name="description" rows="2" placeholder="e.g. Library opens back at 6:00 AM the next day."></textarea>
            </div>
          </form>
        `;

        const hModal = new Modal({
          title: 'Schedule Library Holiday',
          content: modalHtml,
          buttons: [
            { text: 'Cancel', className: 'btn-secondary', onClick: () => hModal.close() },
            {
              text: 'Save Holiday',
              className: 'btn-primary',
              onClick: async () => {
                const form = document.getElementById('holidayForm');
                const formData = new FormData(form);
                const payload = Object.fromEntries(formData.entries());

                if (!payload.title || !payload.date) {
                  Toast.error('Title and Date are required');
                  return;
                }

                try {
                  await api.post('/api/operations/holidays', payload);
                  Toast.success('Holiday scheduled successfully');
                  hModal.close();
                  loadCurrentTab();
                } catch (err) {
                  Toast.error(err.message || 'Failed to save holiday');
                }
              }
            }
          ]
        });
        hModal.show();
      });

      panel.querySelectorAll('.btn-delete-holiday').forEach(btn => {
        btn.addEventListener('click', async () => {
          const ok = await Confirm.show({
            title: 'Delete Holiday',
            message: 'Remove this date from the holiday list?',
            danger: true
          });
          if (ok) {
            try {
              await api.delete(`/api/operations/holidays/${btn.dataset.id}`);
              Toast.success('Holiday removed');
              loadCurrentTab();
            } catch (err) {
              Toast.error(err.message || 'Failed to remove holiday');
            }
          }
        });
      });

    } catch (e) { panel.innerHTML = `<div class="text-danger p-4">Failed to load holidays</div>`; }
  }

  // ----------------------------------------------------
  // Tab 4: Lost & Found Items Registry
  // ----------------------------------------------------
  async function renderLostFound(panel) {
    try {
      const res = await api.get('/api/operations/lostfound');
      const items = res.data || [];

      panel.innerHTML = `
        <div class="d-flex justify-content-between align-items-center mb-3">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600;">🔍 Lost & Found Registry (${items.length})</h3>
          <button id="btn-add-item" class="btn btn-primary btn-sm">+ Log Found Item</button>
        </div>
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Item Name</th>
                  <th style="padding: 12px 16px;">Found Location</th>
                  <th style="padding: 12px 16px;">Date Found</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Claimed By</th>
                  <th style="padding: 12px 16px;">Action</th>
                </tr>
              </thead>
              <tbody>
                ${items.length > 0 ? items.map(item => `
                  <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                    <td style="padding: 12px 16px;"><strong>${escapeHTML(item.itemName)}</strong></td>
                    <td style="padding: 12px 16px;">${escapeHTML(item.locationFound || 'Study Hall')}</td>
                    <td style="padding: 12px 16px;">${new Date(item.dateFound).toLocaleDateString('en-IN')}</td>
                    <td style="padding: 12px 16px;">
                      <span class="badge" style="background: ${item.status === 'claimed' ? 'rgba(0, 184, 148, 0.15)' : 'rgba(253, 203, 110, 0.2)'}; color: ${item.status === 'claimed' ? 'var(--color-success)' : 'var(--color-warning)'}; text-transform: uppercase;">
                        ${escapeHTML(item.status)}
                      </span>
                    </td>
                    <td style="padding: 12px 16px;">${escapeHTML(item.claimedBy || '-')}</td>
                    <td style="padding: 12px 16px;">
                      <div class="btn-icon-group">
                        ${item.status === 'found' ? `
                          <button type="button" class="btn-icon-action action-verify btn-claim-item" data-id="${item._id}" data-tooltip="Mark Item Claimed" aria-label="Mark Claimed">✅</button>
                        ` : ''}
                        <button type="button" class="btn-icon-action action-delete btn-delete-item" data-id="${item._id}" data-tooltip="Delete Item Record" aria-label="Delete">🗑️</button>
                      </div>
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="6" class="p-4 text-center text-muted">No lost & found records. Click "+ Log Found Item" to record misplaced belongings.</td></tr>
                `}
              </tbody>
            </table>
          </div>
        </div>
      `;

      panel.querySelector('#btn-add-item')?.addEventListener('click', () => {
        const modalHtml = `
          <form id="lostFoundForm">
            <div class="mb-3">
              <label class="form-label">Item Name / Description *</label>
              <input type="text" class="form-control" name="itemName" required placeholder="e.g. Blue Boat Earphones, Calculator, Water Bottle">
            </div>
            <div class="mb-3">
              <label class="form-label">Found Location *</label>
              <input type="text" class="form-control" name="locationFound" required placeholder="e.g. Desk D-14, Discussion Room 2">
            </div>
            <div class="mb-3">
              <label class="form-label">Date Found</label>
              <input type="date" class="form-control" name="dateFound" required value="${new Date().toISOString().split('T')[0]}">
            </div>
          </form>
        `;

        const lfModal = new Modal({
          title: 'Log Found Item',
          content: modalHtml,
          buttons: [
            { text: 'Cancel', className: 'btn-secondary', onClick: () => lfModal.close() },
            {
              text: 'Save Item',
              className: 'btn-primary',
              onClick: async () => {
                const form = document.getElementById('lostFoundForm');
                const formData = new FormData(form);
                const payload = Object.fromEntries(formData.entries());

                if (!payload.itemName || !payload.locationFound) {
                  Toast.error('Item name and location are required');
                  return;
                }

                try {
                  await api.post('/api/operations/lostfound', payload);
                  Toast.success('Lost & found item logged');
                  lfModal.close();
                  loadCurrentTab();
                } catch (err) {
                  Toast.error(err.message || 'Failed to save item');
                }
              }
            }
          ]
        });
        lfModal.show();
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
        btn.addEventListener('click', async () => {
          const ok = await Confirm.show({
            title: 'Delete Item',
            message: 'Remove item from register?',
            danger: true
          });
          if (ok) {
            try {
              await api.delete(`/api/operations/lostfound/${btn.dataset.id}`);
              Toast.success('Record deleted');
              loadCurrentTab();
            } catch (err) {
              Toast.error(err.message || 'Failed to delete item');
            }
          }
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
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
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
                <button type="button" class="btn-icon-action action-edit btn-reply-feedback" data-id="${fb._id}" data-tooltip="Reply to Feedback" aria-label="Reply">💬</button>
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
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
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
                        <div class="btn-icon-group justify-content-center">
                          <button type="button" class="btn-icon-action action-verify btn-approve-leave" data-id="${l._id}" data-tooltip="Approve Leave" aria-label="Approve">✅</button>
                          <button type="button" class="btn-icon-action action-delete btn-reject-leave" data-id="${l._id}" data-tooltip="Reject Leave" aria-label="Reject">❌</button>
                        </div>
                      ` : `<span class="text-muted small">-</span>`}
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="6" class="p-4 text-center text-muted">No leave applications submitted yet.</td></tr>
                `}
              </tbody>
            </table></div>
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
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
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
                        <div class="btn-icon-group justify-content-center">
                          <button type="button" class="btn-icon-action action-verify btn-transfer-seat" data-id="${r._id}" data-name="${escapeHTML(r.studentName)}" data-tooltip="Allocate & Approve" aria-label="Allocate">✅</button>
                          <button type="button" class="btn-icon-action action-delete btn-reject-sc" data-id="${r._id}" data-tooltip="Reject Request" aria-label="Reject">❌</button>
                        </div>
                      ` : `<span class="text-muted small">-</span>`}
                    </td>
                  </tr>
                `).join('') : `
                  <tr><td colspan="6" class="p-4 text-center text-muted">No seat transfer requests submitted.</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `;

      panel.querySelectorAll('.btn-transfer-seat').forEach(btn => {
        btn.addEventListener('click', async () => {
          const sRes = await api.get('/api/seats?status=available');
          const availSeats = Array.isArray(sRes.data) ? sRes.data : (sRes.data?.seats || sRes.seats || []);
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
  // Tab 8: Student Referrals & Program Control Suite
  // ----------------------------------------------------
  async function renderReferrals(panel) {
    try {
      const [refRes, configRes] = await Promise.all([
        api.get('/api/operations/referrals'),
        api.get('/api/operations/referrals/config')
      ]);

      const referrals = refRes.data || [];
      const config = configRes.data || {
        isEnabled: true,
        referrerRewardType: 'flat',
        referrerRewardAmount: 100,
        refereeRewardType: 'flat',
        refereeRewardAmount: 100,
        minPlanAmount: 500,
        autoApplyToNextRenewal: true
      };

      panel.innerHTML = `
        <!-- Top Program Configuration Card -->
        <div class="card p-4 mb-4" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.08), rgba(0, 184, 148, 0.05)), var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem; margin-bottom: 1.25rem;">
            <div>
              <div style="display: flex; align-items: center; gap: 8px;">
                <span style="font-size: 1.4rem;">🎁</span>
                <h3 style="margin: 0; font-size: 1.2rem; font-weight: 700; color: var(--color-text-primary);">
                  Student Referral Program & Reward Settings
                </h3>
                <span class="badge ${config.isEnabled ? 'badge-success' : 'badge-danger'}" style="font-size: 0.75rem;">
                  ${config.isEnabled ? '🟢 Active & Enabled' : '🔴 Disabled'}
                </span>
              </div>
              <p style="margin: 4px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
                Customize reward discounts, automated next-renewal wallet credits, and referral validation rules.
              </p>
            </div>

            <div style="display: flex; gap: 8px; align-items: center;">
              <button id="btn-add-manual-referral" class="btn btn-primary btn-sm" style="font-weight: 700;">
                ➕ Record Manual Referral
              </button>
            </div>
          </div>

          <!-- Configuration Controls Form -->
          <form id="referral-config-form" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; align-items: flex-end; background: var(--color-surface); padding: 14px; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Program Master Status</label>
              <select id="cfg-enabled" class="form-select form-control" style="font-weight: 600;">
                <option value="true" ${config.isEnabled ? 'selected' : ''}>🟢 Enabled (Accepting Referrals)</option>
                <option value="false" ${!config.isEnabled ? 'selected' : ''}>🔴 Disabled (Paused)</option>
              </select>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Referrer Reward (Next Renewal)</label>
              <div style="display: flex; gap: 4px;">
                <span class="input-group-text" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 6px 10px; font-weight: 700; border-radius: 6px 0 0 6px;">₹</span>
                <input type="number" id="cfg-referrer-amount" class="form-control" value="${config.referrerRewardAmount || 100}" min="0" required style="border-radius: 0 6px 6px 0;">
              </div>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Friend Discount (On Joining)</label>
              <div style="display: flex; gap: 4px;">
                <span class="input-group-text" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 6px 10px; font-weight: 700; border-radius: 6px 0 0 6px;">₹</span>
                <input type="number" id="cfg-referee-amount" class="form-control" value="${config.refereeRewardAmount || 100}" min="0" required style="border-radius: 0 6px 6px 0;">
              </div>
            </div>

            <div>
              <label class="form-label text-xs" style="font-weight: 700;">Min Plan Price</label>
              <div style="display: flex; gap: 4px;">
                <span class="input-group-text" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); padding: 6px 10px; font-weight: 700; border-radius: 6px 0 0 6px;">₹</span>
                <input type="number" id="cfg-min-plan" class="form-control" value="${config.minPlanAmount || 500}" min="0" required style="border-radius: 0 6px 6px 0;">
              </div>
            </div>

            <div style="grid-column: 1 / -1; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; border-top: 1px solid var(--color-divider); padding-top: 10px; margin-top: 4px;">
              <label style="display: flex; align-items: center; gap: 8px; font-size: 0.85rem; font-weight: 600; cursor: pointer; color: var(--color-text-primary);">
                <input type="checkbox" id="cfg-auto-apply" ${config.autoApplyToNextRenewal ? 'checked' : ''} style="width: 16px; height: 16px;">
                ⚡ Automatically apply approved referral credits as discount on student's next renewal invoice
              </label>

              <button type="submit" class="btn btn-success btn-sm" id="btn-save-referral-config" style="font-weight: 700; padding: 6px 16px;">
                💾 Save Program Settings
              </button>
            </div>
          </form>
        </div>

        <!-- Referral Leads & Transactions Table -->
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div class="p-3" style="border-bottom: 1px solid var(--color-divider); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px; background: var(--color-surface-hover);">
            <div style="font-weight: 700; font-size: 1rem; color: var(--color-text-primary);">
              📋 Referral Leads & Reward Ledger (${referrals.length})
            </div>
            <div class="text-muted small">
              Earned discounts automatically deduct from student renewal quotes.
            </div>
          </div>

          <div style="overflow-x: auto;">
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Referrer Student</th>
                  <th style="padding: 12px 16px;">Prospect Friend</th>
                  <th style="padding: 12px 16px;">Phone</th>
                  <th style="padding: 12px 16px;">Referral Code</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Reward</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${referrals.length > 0 ? referrals.map(r => {
                  const studentName = r.referrerStudent?.name || r.referrerName;
                  const studentId = r.referrerStudent?.studentId || '';
                  const refCode = r.referralCode || r.referrerStudent?.referralCode || '-';
                  
                  let badgeClass = 'badge-secondary';
                  if (r.status === 'rewarded') badgeClass = 'badge-success';
                  else if (r.status === 'joined' || r.status === 'approved') badgeClass = 'badge-primary';
                  else if (r.status === 'pending') badgeClass = 'badge-warning';
                  else if (r.status === 'rejected') badgeClass = 'badge-danger';

                  return `
                    <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                      <td style="padding: 12px 16px;">
                        <div style="font-weight: 700; color: var(--color-text-primary);">${escapeHTML(studentName)}</div>
                        <div class="text-muted small" style="font-family: monospace;">${escapeHTML(studentId || r.referrerPhone || '')}</div>
                      </td>
                      <td style="padding: 12px 16px;">
                        <div style="font-weight: 600;">${escapeHTML(r.refereeName)}</div>
                        <div class="text-muted small">${escapeHTML(r.targetExam || r.notes || '-')}</div>
                      </td>
                      <td style="padding: 12px 16px; font-family: monospace;">${escapeHTML(r.refereePhone)}</td>
                      <td style="padding: 12px 16px;">
                        <span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-family: monospace; font-weight: 700;">
                          ${escapeHTML(refCode)}
                        </span>
                      </td>
                      <td style="padding: 12px 16px;">
                        <span class="badge ${badgeClass}" style="text-transform: uppercase; font-size: 0.75rem;">
                          ${escapeHTML(r.status)}
                        </span>
                      </td>
                      <td style="padding: 12px 16px; font-weight: 700; color: var(--color-success);">
                        ₹${r.rewardAmount || 100}
                        ${r.discountApplied ? `<span style="font-size: 0.72rem; color: var(--color-text-muted); display: block;">✓ Credited</span>` : ''}
                      </td>
                      <td style="padding: 12px 16px; text-align: center;">
                        <div class="btn-icon-group justify-content-center">
                          ${!r.discountApplied && r.status !== 'rejected' ? `
                            <button type="button" class="btn-icon-action action-verify btn-approve-ref-reward" data-id="${r._id}" data-amt="${r.rewardAmount || 100}" data-tooltip="Credit ₹${r.rewardAmount || 100} Discount" aria-label="Credit Discount">⚡</button>
                          ` : ''}
                          <button type="button" class="btn-icon-action action-edit btn-edit-ref" data-ref='${JSON.stringify(r)}' data-tooltip="Edit Referral" aria-label="Edit">✏️</button>
                          <button type="button" class="btn-icon-action action-delete btn-delete-ref" data-id="${r._id}" data-tooltip="Delete Referral Record" aria-label="Delete">🗑️</button>
                        </div>
                      </td>
                    </tr>
                  `;
                }).join('') : `
                  <tr><td colspan="7" class="p-5 text-center text-muted">No student referrals recorded yet. Friends who use student referral codes on registration will appear here automatically!</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `;

      // Save Program Settings
      panel.querySelector('#referral-config-form')?.addEventListener('submit', async (e) => {
        e.preventDefault();
        const btn = panel.querySelector('#btn-save-referral-config');
        Loading.button(btn, true);
        try {
          const payload = {
            isEnabled: panel.querySelector('#cfg-enabled').value === 'true',
            referrerRewardAmount: Number(panel.querySelector('#cfg-referrer-amount').value),
            refereeRewardAmount: Number(panel.querySelector('#cfg-referee-amount').value),
            minPlanAmount: Number(panel.querySelector('#cfg-min-plan').value),
            autoApplyToNextRenewal: panel.querySelector('#cfg-auto-apply').checked
          };
          const saveRes = await api.put('/api/operations/referrals/config', payload);
          if (saveRes.success) {
            Toast.success('Referral Program settings saved successfully!');
            loadCurrentTab();
          } else {
            Toast.error(saveRes.message);
          }
        } catch (err) {
          Toast.error(err.message || 'Failed to save settings');
        } finally {
          Loading.button(btn, false);
        }
      });

      // Approve & Credit Reward
      panel.querySelectorAll('.btn-approve-ref-reward').forEach(btn => {
        btn.addEventListener('click', async () => {
          try {
            Loading.button(btn, true);
            const res = await api.post(`/api/operations/referrals/${btn.dataset.id}/approve-reward`, {
              rewardAmount: Number(btn.dataset.amt)
            });
            if (res.success) {
              Toast.success(res.message);
              loadCurrentTab();
            } else {
              Toast.error(res.message);
            }
          } catch (err) {
            Toast.error(err.message || 'Failed to credit reward');
          } finally {
            Loading.button(btn, false);
          }
        });
      });

      // Record Manual Referral Modal
      panel.querySelector('#btn-add-manual-referral')?.addEventListener('click', async () => {
        let studentsList = [];
        try {
          const sRes = await api.get('/api/students?limit=500');
          const raw = sRes?.data?.students || sRes?.students || sRes?.data || sRes;
          studentsList = Array.isArray(raw) ? raw : [];
        } catch (e) {
          console.error('Error loading students list for referral modal:', e);
        }

        const modalContent = document.createElement('div');
        modalContent.innerHTML = `
          <form id="form-manual-referral" style="display: flex; flex-direction: column; gap: 16px;">
            
            <div class="form-group">
              <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin: 0;">
                  Referring Student (Existing Member) *
                </label>
                <span class="badge badge-secondary" style="font-size: 0.72rem;">${studentsList.length} Members Loaded</span>
              </div>

              <input type="text" id="man-student-search" class="form-control mb-2" placeholder="🔍 Type to filter student by name, phone, or ID..." style="font-size: 0.85rem; padding: 6px 10px; border-radius: 6px;">

              <select id="man-student-id" class="form-select form-control" required size="5" style="font-weight: 600; padding: 6px; border-radius: var(--radius-md); background: var(--color-surface); color: var(--color-text-primary); border: 1.5px solid var(--color-border); max-height: 140px; overflow-y: auto;">
                <option value="" style="background: var(--color-surface); color: var(--color-text-secondary); font-style: italic;" disabled selected>-- Select Referring Student Below --</option>
                ${studentsList.length > 0 ? studentsList.map(s => `
                  <option value="${s._id}" data-search="${escapeHTML((s.name + ' ' + (s.studentId||'') + ' ' + (s.phone||'') + ' ' + (s.referralCode||'')).toLowerCase())}" style="background: var(--color-surface); color: var(--color-text-primary); padding: 8px 10px; border-bottom: 1px solid var(--color-divider); cursor: pointer;">
                    👤 ${escapeHTML(s.name)} • 📱 ${escapeHTML(s.phone || s.studentId || 'N/A')} ${s.referralCode ? ' • [Code: ' + escapeHTML(s.referralCode) + ']' : ''}
                  </option>
                `).join('') : `
                  <option value="" disabled style="padding: 10px; color: var(--color-text-secondary);">No registered students found in database</option>
                `}
              </select>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Friend / Referee Name *</label>
                <input type="text" id="man-referee-name" class="form-control" placeholder="e.g. Rahul Sharma" required style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);">
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Friend Phone *</label>
                <input type="tel" id="man-referee-phone" class="form-control" placeholder="10-digit mobile" required style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);">
              </div>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Course / Target Exam</label>
                <input type="text" id="man-target-exam" class="form-control" placeholder="e.g. UPSC, CA, NEET" style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);">
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Reward Credit Amount (₹)</label>
                <input type="number" id="man-reward-amt" class="form-control" value="100" min="0" style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md); font-weight: 700; color: var(--color-success);">
              </div>
            </div>

            <div class="form-group">
              <label class="form-label" style="font-weight: 700; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 6px; display: block;">Notes / Follow-up Details</label>
              <textarea id="man-notes" class="form-control" rows="2" placeholder="Friend visited library for trial..." style="padding: 0.65rem 0.85rem; border-radius: var(--radius-md);"></textarea>
            </div>

            <div style="display: flex; gap: 10px; justify-content: flex-end; margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--color-divider);">
              <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()" style="font-weight: 600; padding: 0.6rem 1.25rem;">Cancel</button>
              <button type="submit" class="btn btn-primary" style="font-weight: 700; padding: 0.6rem 1.5rem;">Record Referral</button>
            </div>
          </form>
        `;

        const modal = new Modal({ title: '🎁 Record Manual Referral Lead', content: modalContent, size: 'md' });
        modal.show();

        // Live Student Search Filter Listener
        const searchInput = modalContent.querySelector('#man-student-search');
        const selectEl = modalContent.querySelector('#man-student-id');
        if (searchInput && selectEl) {
          searchInput.focus();
          searchInput.addEventListener('input', (e) => {
            const q = e.target.value.toLowerCase().trim();
            Array.from(selectEl.options).forEach(opt => {
              if (!opt.dataset.search) return;
              opt.style.display = opt.dataset.search.includes(q) ? 'block' : 'none';
            });
          });
        }

        modalContent.querySelector('#form-manual-referral').onsubmit = async (e) => {
          e.preventDefault();
          try {
            const payload = {
              referrerStudentId: modalContent.querySelector('#man-student-id').value,
              refereeName: modalContent.querySelector('#man-referee-name').value.trim(),
              refereePhone: modalContent.querySelector('#man-referee-phone').value.trim(),
              targetExam: modalContent.querySelector('#man-target-exam').value.trim(),
              rewardAmount: Number(modalContent.querySelector('#man-reward-amt').value),
              notes: modalContent.querySelector('#man-notes').value.trim()
            };
            const createRes = await api.post('/api/operations/referrals', payload);
            if (createRes.success) {
              Toast.success('Referral lead recorded successfully!');
              modal.close();
              loadCurrentTab();
            } else {
              Toast.error(createRes.message);
            }
          } catch (err) {
            Toast.error(err.message || 'Failed to record referral');
          }
        };
      });

      // Edit Referral Modal
      panel.querySelectorAll('.btn-edit-ref').forEach(btn => {
        btn.addEventListener('click', () => {
          const r = JSON.parse(btn.dataset.ref);
          const modalContent = document.createElement('div');
          modalContent.innerHTML = `
            <form id="form-edit-referral" style="display: flex; flex-direction: column; gap: 12px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Referral Status</label>
                <select id="edit-ref-status" class="form-select form-control">
                  <option value="pending" ${r.status === 'pending' ? 'selected' : ''}>🟡 Pending Lead</option>
                  <option value="joined" ${r.status === 'joined' ? 'selected' : ''}>🔵 Friend Joined</option>
                  <option value="approved" ${r.status === 'approved' ? 'selected' : ''}>🟣 Approved</option>
                  <option value="rewarded" ${r.status === 'rewarded' ? 'selected' : ''}>🟢 Rewarded & Discount Credited</option>
                  <option value="rejected" ${r.status === 'rejected' ? 'selected' : ''}>🔴 Rejected / Invalid</option>
                </select>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Reward Discount Amount (₹)</label>
                <input type="number" id="edit-ref-reward-amt" class="form-control" value="${r.rewardAmount || 100}">
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Notes</label>
                <textarea id="edit-ref-notes" class="form-control" rows="2">${escapeHTML(r.notes || '')}</textarea>
              </div>

              <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 8px;">
                <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
                <button type="submit" class="btn btn-primary" style="font-weight: 700;">💾 Save Changes</button>
              </div>
            </form>
          `;

          const modal = new Modal({ title: '✏️ Edit Referral Record', content: modalContent, size: 'md' });
          modal.show();

          modalContent.querySelector('#form-edit-referral').onsubmit = async (e) => {
            e.preventDefault();
            try {
              const payload = {
                status: modalContent.querySelector('#edit-ref-status').value,
                rewardAmount: Number(modalContent.querySelector('#edit-ref-reward-amt').value),
                notes: modalContent.querySelector('#edit-ref-notes').value.trim()
              };
              const updateRes = await api.put(`/api/operations/referrals/${r._id}`, payload);
              if (updateRes.success) {
                Toast.success('Referral updated successfully!');
                modal.close();
                loadCurrentTab();
              } else {
                Toast.error(updateRes.message);
              }
            } catch (err) {
              Toast.error(err.message || 'Failed to update referral');
            }
          };
        });
      });

      // Delete Referral
      panel.querySelectorAll('.btn-delete-ref').forEach(btn => {
        btn.addEventListener('click', async () => {
          const ok = await Confirm.show({
            title: 'Delete Referral Entry',
            message: 'Are you sure you want to delete this referral lead?',
            danger: true
          });
          if (ok) {
            try {
              await api.delete(`/api/operations/referrals/${btn.dataset.id}`);
              Toast.success('Referral deleted');
              loadCurrentTab();
            } catch (e) {
              Toast.error(e.message || 'Failed to delete');
            }
          }
        });
      });

    } catch (e) {
      panel.innerHTML = `<div class="text-danger p-4">Failed to load referrals: ${escapeHTML(e.message)}</div>`;
    }
  }

  // ----------------------------------------------------
  // Tab 9: Waiting List Queue & 1-Click Admission Converter
  // ----------------------------------------------------
  async function renderWaitingList(panel) {
    try {
      const res = await api.get('/api/waiting-list');
      const items = res.data?.items || [];
      const counts = res.data?.counts || { waiting: 0, offered: 0, assigned: 0, total: items.length };

      panel.innerHTML = `
        <!-- Top Metrics Cards -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px; margin-bottom: 1.5rem;">
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; align-items: center; gap: 14px;">
            <div style="width: 48px; height: 48px; border-radius: 12px; background: rgba(245, 158, 11, 0.15); color: #f59e0b; display: flex; align-items: center; justify-content: center; font-size: 1.5rem;">
              ⏳
            </div>
            <div>
              <div class="text-muted small" style="font-weight: 600; text-transform: uppercase;">Active in Queue</div>
              <div style="font-size: 1.6rem; font-weight: 800; color: #f59e0b;">${counts.waiting}</div>
            </div>
          </div>

          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; align-items: center; gap: 14px;">
            <div style="width: 48px; height: 48px; border-radius: 12px; background: rgba(99, 102, 241, 0.15); color: var(--color-primary); display: flex; align-items: center; justify-content: center; font-size: 1.5rem;">
              💺
            </div>
            <div>
              <div class="text-muted small" style="font-weight: 600; text-transform: uppercase;">Offered / 24h Hold</div>
              <div style="font-size: 1.6rem; font-weight: 800; color: var(--color-primary);">${counts.offered}</div>
            </div>
          </div>

          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; align-items: center; gap: 14px;">
            <div style="width: 48px; height: 48px; border-radius: 12px; background: rgba(34, 197, 94, 0.15); color: var(--color-success); display: flex; align-items: center; justify-content: center; font-size: 1.5rem;">
              ✅
            </div>
            <div>
              <div class="text-muted small" style="font-weight: 600; text-transform: uppercase;">Converted to Admission</div>
              <div style="font-size: 1.6rem; font-weight: 800; color: var(--color-success);">${counts.assigned}</div>
            </div>
          </div>
        </div>

        <!-- Header Actions -->
        <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
          <div>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700;">⏳ Shift Capacity & Seat Waiting List (${items.length})</h3>
            <p style="margin: 2px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
              Students queued for full shifts or reserved seats. Allocate vacant seats in 1 click!
            </p>
          </div>
          <div class="d-flex gap-2 align-items-center">
            <button id="btn-add-waiting-item" class="btn btn-primary btn-sm" style="font-weight: 700;">
              ➕ Add Walk-in to Queue
            </button>
          </div>
        </div>

        <!-- Waiting Queue Table -->
        <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div style="overflow-x: auto;">
            <div class="table-responsive"><table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-muted); font-size: 0.85rem; text-align: left;">
                  <th style="padding: 12px 16px;">Priority</th>
                  <th style="padding: 12px 16px;">Student Name</th>
                  <th style="padding: 12px 16px;">Contact</th>
                  <th style="padding: 12px 16px;">Preferred Shift & Zone</th>
                  <th style="padding: 12px 16px;">Status</th>
                  <th style="padding: 12px 16px;">Offered Seat / Note</th>
                  <th style="padding: 12px 16px;">Date Added</th>
                  <th style="padding: 12px 16px; text-align: center;">Actions</th>
                </tr>
              </thead>
              <tbody>
                ${items.length > 0 ? items.map((it, idx) => {
                  let statusBadge = 'badge-warning';
                  if (it.status === 'assigned') statusBadge = 'badge-success';
                  else if (it.status === 'offered') statusBadge = 'badge-primary';
                  else if (it.status === 'cancelled') statusBadge = 'badge-danger';

                  const dateStr = it.createdAt ? new Date(it.createdAt).toLocaleDateString('en-IN') : '-';
                  const offeredSeatNum = it.offeredSeat?.seatNumber || (typeof it.offeredSeat === 'string' ? it.offeredSeat : null);

                  return `
                    <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                      <td style="padding: 12px 16px;">
                        <span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-weight: 800; font-size: 0.85rem;">
                          #${it.priority || (idx + 1)}
                        </span>
                      </td>
                      <td style="padding: 12px 16px;">
                        <strong style="color: var(--color-text-primary);">${escapeHTML(it.studentName)}</strong>
                        ${it.student?.studentId ? `<div class="text-muted small">${escapeHTML(it.student.studentId)}</div>` : ''}
                      </td>
                      <td style="padding: 12px 16px; font-family: monospace;">
                        <div>${escapeHTML(it.studentPhone)}</div>
                        ${it.studentEmail ? `<div class="text-muted small" style="font-size: 0.75rem;">${escapeHTML(it.studentEmail)}</div>` : ''}
                      </td>
                      <td style="padding: 12px 16px;">
                        <span class="badge badge-primary">${escapeHTML(it.preferredShift || 'Any Shift')}</span>
                        <span class="badge badge-secondary" style="margin-left: 4px;">${escapeHTML(it.preferredZone || 'Any Zone')}</span>
                      </td>
                      <td style="padding: 12px 16px;">
                        <span class="badge ${statusBadge}" style="text-transform: uppercase; font-size: 0.75rem;">
                          ${escapeHTML(it.status)}
                        </span>
                      </td>
                      <td style="padding: 12px 16px;">
                        ${offeredSeatNum ? `
                          <div style="font-weight: 700; color: var(--color-primary);">💺 Seat ${escapeHTML(offeredSeatNum)}</div>
                          ${it.offerExpiresAt ? `<div class="text-muted small" style="font-size: 0.75rem;">Hold: ${new Date(it.offerExpiresAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</div>` : ''}
                        ` : `<span class="text-muted small">${escapeHTML(it.notes || 'Awaiting vacant seat')}</span>`}
                      </td>
                      <td style="padding: 12px 16px; font-size: 0.85rem; color: var(--color-text-secondary);">
                        ${dateStr}
                      </td>
                      <td style="padding: 12px 16px; text-align: center;">
                        <div class="btn-icon-group justify-content-center">
                          ${it.status !== 'assigned' && it.status !== 'cancelled' ? `
                            <button type="button" class="btn-icon-action action-verify btn-convert-admission" data-id="${it._id}" data-name="${escapeHTML(it.studentName)}" data-phone="${escapeHTML(it.studentPhone)}" data-shift="${escapeHTML(it.preferredShift || '')}" data-seat="${offeredSeatNum || ''}" data-tooltip="Convert to Admission" aria-label="Convert">⚡</button>
                            <button type="button" class="btn-icon-action action-receipt btn-offer-seat" data-id="${it._id}" data-name="${escapeHTML(it.studentName)}" data-tooltip="Offer Vacant Desk (24h Hold)" aria-label="Offer Desk">💺</button>
                            <button type="button" class="btn-icon-action action-delete btn-cancel-waiting" data-id="${it._id}" data-tooltip="Cancel Waiting Entry" aria-label="Cancel">✕</button>
                          ` : `<span class="badge badge-success" style="font-size: 0.75rem;">${it.status === 'assigned' ? '✓ Enrolled' : 'Cancelled'}</span>`}
                        </div>
                      </td>
                    </tr>
                  `;
                }).join('') : `
                  <tr><td colspan="8" class="p-5 text-center text-muted">No students currently in waiting queue. When a shift reaches maximum capacity, applicants will appear here automatically!</td></tr>
                `}
              </tbody>
            </table></div>
          </div>
        </div>
      `;

      // 1-Click Convert to Admission
      panel.querySelectorAll('.btn-convert-admission').forEach(btn => {
        btn.addEventListener('click', async () => {
          const waitingId = btn.dataset.id;
          const candidateName = btn.dataset.name;
          const candidatePhone = btn.dataset.phone;
          const preferredShiftName = btn.dataset.shift;

          let availableSeats = [];
          let shiftsList = [];
          let plansList = [];

          try {
            const [sRes, shiftsRes, pRes] = await Promise.all([
              api.get('/api/seats?status=available'),
              api.get('/api/shifts'),
              api.get('/api/plans')
            ]);
            availableSeats = Array.isArray(sRes.data) ? sRes.data : (sRes.data?.seats || sRes.seats || []);
            shiftsList = Array.isArray(shiftsRes.data) ? shiftsRes.data : (shiftsRes.data?.shifts || []);
            plansList = Array.isArray(pRes.data) ? pRes.data : (pRes.data?.plans || []);
          } catch (e) {}

          if (availableSeats.length === 0) {
            Toast.warning('No vacant seats currently available. Please check seat availability or wait for a desk to clear.');
            return;
          }

          const modalContent = document.createElement('div');
          modalContent.innerHTML = `
            <form id="form-convert-admission" style="display: flex; flex-direction: column; gap: 14px;">
              <div style="background: rgba(34, 197, 94, 0.08); border: 1px solid rgba(34, 197, 94, 0.25); border-radius: var(--radius-md); padding: 12px;">
                <div style="font-weight: 700; color: var(--color-success);">⚡ 1-Click Admission & Desk Allocation</div>
                <div style="font-size: 0.85rem; color: var(--color-text-secondary);">
                  Converting <strong>${escapeHTML(candidateName)}</strong> (${escapeHTML(candidatePhone)}) to an active student membership.
                </div>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Select Available Vacant Seat *</label>
                <select id="conv-seat-id" class="form-select form-control" required style="font-weight: 700; font-size: 0.95rem;">
                  ${availableSeats.map(s => `<option value="${s._id}">💺 ${escapeHTML(s.seatNumber)} (${escapeHTML(s.zone || 'General')} - ${escapeHTML(s.type || 'Standard')})</option>`).join('')}
                </select>
              </div>

              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
                <div class="form-group">
                  <label class="form-label" style="font-weight: 700;">Study Shift</label>
                  <select id="conv-shift-id" class="form-select form-control">
                    <option value="">-- Select Shift --</option>
                    ${shiftsList.map(s => `<option value="${s._id}">${escapeHTML(s.name)} (${s.startTime} - ${s.endTime})</option>`).join('')}
                  </select>
                </div>

                <div class="form-group">
                  <label class="form-label" style="font-weight: 700;">Membership Plan</label>
                  <select id="conv-plan-id" class="form-select form-control">
                    <option value="">-- Select Plan --</option>
                    ${plansList.map(p => `<option value="${p._id}">${escapeHTML(p.name)} (₹${p.price})</option>`).join('')}
                  </select>
                </div>
              </div>

              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Admission Notes / Reference</label>
                <input type="text" id="conv-notes" class="form-control" placeholder="Allocated upon seat vacancy...">
              </div>

              <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 10px;">
                <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
                <button type="submit" class="btn btn-success" id="btn-submit-convert" style="font-weight: 700;">
                  🚀 Convert to Admission & Assign Seat
                </button>
              </div>
            </form>
          `;

          const modal = new Modal({ title: `⚡ Convert ${candidateName} to Admission`, content: modalContent, size: 'md' });
          modal.show();

          modalContent.querySelector('#form-convert-admission').onsubmit = async (e) => {
            e.preventDefault();
            const submitBtn = modalContent.querySelector('#btn-submit-convert');
            Loading.button(submitBtn, true);

            try {
              const payload = {
                seatId: modalContent.querySelector('#conv-seat-id').value,
                shiftId: modalContent.querySelector('#conv-shift-id').value || null,
                planId: modalContent.querySelector('#conv-plan-id').value || null,
                notes: modalContent.querySelector('#conv-notes').value.trim()
              };

              const convertRes = await api.post(`/api/waiting-list/${waitingId}/convert-admission`, payload);
              if (convertRes.success) {
                Toast.success(convertRes.message || 'Successfully converted to active student admission!');
                modal.close();
                loadCurrentTab();
              } else {
                Toast.error(convertRes.message);
              }
            } catch (err) {
              Toast.error(err.message || 'Failed to convert admission');
            } finally {
              Loading.button(submitBtn, false);
            }
          };
        });
      });

      // Offer Vacant Seat
      panel.querySelectorAll('.btn-offer-seat').forEach(btn => {
        btn.addEventListener('click', async () => {
          const waitingId = btn.dataset.id;
          const candidateName = btn.dataset.name;

          let availableSeats = [];
          try {
            const sRes = await api.get('/api/seats?status=available');
            availableSeats = Array.isArray(sRes.data) ? sRes.data : (sRes.data?.seats || sRes.seats || []);
          } catch (e) {}

          if (availableSeats.length === 0) {
            Toast.warning('No available vacant seats to offer.');
            return;
          }

          const modalContent = document.createElement('div');
          modalContent.innerHTML = `
            <div class="form-group mb-3">
              <label class="form-label" style="font-weight: 600;">Choose Vacant Seat to Offer ${escapeHTML(candidateName)} (24-hour Hold)</label>
              <select id="offer-seat-select" class="form-select form-control">
                ${availableSeats.map(s => `<option value="${s._id}">${escapeHTML(s.seatNumber)} (${escapeHTML(s.zone || 'Hall')} - ${escapeHTML(s.type || 'Standard')})</option>`).join('')}
              </select>
            </div>
            <div class="d-flex justify-content-end gap-2">
              <button class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
              <button class="btn btn-primary" id="btn-confirm-offer" style="font-weight: 700;">💺 Offer Seat Hold</button>
            </div>
          `;

          const modal = new Modal({ title: `💺 Offer Seat to ${candidateName}`, content: modalContent, size: 'sm' });
          modal.show();

          modalContent.querySelector('#btn-confirm-offer').onclick = async () => {
            const seatId = modalContent.querySelector('#offer-seat-select').value;
            try {
              const res = await api.put(`/api/waiting-list/${waitingId}/offer`, { seatId });
              if (res.success) {
                Toast.success(res.message);
                modal.close();
                loadCurrentTab();
              } else {
                Toast.error(res.message);
              }
            } catch (err) {
              Toast.error(err.message || 'Failed to offer seat');
            }
          };
        });
      });

      // Cancel Waiting Entry
      panel.querySelectorAll('.btn-cancel-waiting').forEach(btn => {
        btn.addEventListener('click', async () => {
          const ok = await Confirm.show({
            title: 'Cancel Waiting Queue Entry',
            message: 'Are you sure you want to remove this candidate from the waiting list?',
            danger: true
          });
          if (ok) {
            try {
              await api.put(`/api/waiting-list/${btn.dataset.id}/cancel`, {});
              Toast.success('Waiting entry cancelled');
              loadCurrentTab();
            } catch (e) {
              Toast.error(e.message || 'Failed to cancel');
            }
          }
        });
      });

      // Add Walk-in to Waiting List Modal
      panel.querySelector('#btn-add-waiting-item')?.addEventListener('click', async () => {
        let shiftsList = [];
        try {
          const shiftsRes = await api.get('/api/shifts');
          shiftsList = Array.isArray(shiftsRes.data) ? shiftsRes.data : (shiftsRes.data?.shifts || []);
        } catch (e) {}

        const modalContent = document.createElement('div');
        modalContent.innerHTML = `
          <form id="form-add-waiting" style="display: flex; flex-direction: column; gap: 12px;">
            <div class="form-group">
              <label class="form-label" style="font-weight: 700;">Student / Candidate Name *</label>
              <input type="text" id="wl-name" class="form-control" placeholder="Full name" required>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Mobile Phone *</label>
                <input type="tel" id="wl-phone" class="form-control" placeholder="10-digit mobile" required>
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Email Address</label>
                <input type="email" id="wl-email" class="form-control" placeholder="student@example.com">
              </div>
            </div>

            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Preferred Study Shift</label>
                <select id="wl-shift" class="form-select form-control">
                  <option value="Any">Any Shift</option>
                  ${shiftsList.map(s => `<option value="${escapeHTML(s.name)}">${escapeHTML(s.name)} (${s.startTime} - ${s.endTime})</option>`).join('')}
                </select>
              </div>
              <div class="form-group">
                <label class="form-label" style="font-weight: 700;">Preferred Zone / Desk Type</label>
                <select id="wl-zone" class="form-select form-control">
                  <option value="General">General Reading Zone</option>
                  <option value="Silent AC">Silent AC Zone</option>
                  <option value="Private Cabin">Private Cabin</option>
                  <option value="Discussion">Discussion Zone</option>
                </select>
              </div>
            </div>

            <div class="form-group">
              <label class="form-label" style="font-weight: 700;">Notes / Target Exam</label>
              <textarea id="wl-notes" class="form-control" rows="2" placeholder="Preparing for UPSC, requires morning slot..."></textarea>
            </div>

            <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 8px;">
              <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
              <button type="submit" class="btn btn-primary" style="font-weight: 700;">➕ Add to Waiting Queue</button>
            </div>
          </form>
        `;

        const modal = new Modal({ title: '⏳ Add Candidate to Waiting List', content: modalContent, size: 'md' });
        modal.show();

        modalContent.querySelector('#form-add-waiting').onsubmit = async (e) => {
          e.preventDefault();
          try {
            const payload = {
              studentName: modalContent.querySelector('#wl-name').value.trim(),
              studentPhone: modalContent.querySelector('#wl-phone').value.trim(),
              studentEmail: modalContent.querySelector('#wl-email').value.trim(),
              preferredShift: modalContent.querySelector('#wl-shift').value,
              preferredZone: modalContent.querySelector('#wl-zone').value,
              notes: modalContent.querySelector('#wl-notes').value.trim()
            };

            const addRes = await api.post('/api/waiting-list', payload);
            if (addRes.success) {
              Toast.success(addRes.message || 'Added to waiting queue!');
              modal.close();
              loadCurrentTab();
            } else {
              Toast.error(addRes.message);
            }
          } catch (err) {
            Toast.error(err.message || 'Failed to add to waiting list');
          }
        };
      });

    } catch (e) {
      panel.innerHTML = `<div class="text-danger p-4">Failed to load waiting list: ${escapeHTML(e.message)}</div>`;
    }
  }

  // Initial load
  loadCurrentTab();

  // Mount context-aware FAB for Operations page
  if (typeof window !== 'undefined' && window.FAB) {
    window.FAB.mount({
      icon: '⚡',
      label: 'Operations Actions',
      color: '#6c5ce7',
      actions: [
        {
          icon: '⏳',
          label: 'Waiting List',
          onClick: () => {
            currentTab = 'waiting';
            container.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === 'waiting'));
            loadCurrentTab();
          }
        },
        {
          icon: '📢',
          label: 'Broadcast Notice',
          onClick: () => {
            currentTab = 'announcements';
            container.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === 'announcements'));
            loadCurrentTab();
          }
        },
        {
          icon: '🎁',
          label: 'Referrals Lead',
          onClick: () => {
            currentTab = 'referrals';
            container.querySelectorAll('.tab-btn').forEach(b => b.classList.toggle('active', b.dataset.tab === 'referrals'));
            loadCurrentTab();
          }
        }
      ]
    });
  }

  return container;
}
