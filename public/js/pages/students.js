import { App } from '../app.js';
import { t } from '../i18n.js';
import { Toast, Modal, Loading, Confirm, escapeHTML, debounce, copyToClipboard, UI } from '../ui.js';
import { SmartFormatters } from '../utils/smartFormatters.js';
import { SignatureStudio } from '../signatureStudio.js';
import { MediaStudio, MediaFieldPicker } from '../mediaStudio.js';
import api from '../api.js';
import { generateAdmissionFormPDF, previewAdmissionFormPDF } from '../pdfGenerator.js';
import { renderHeatmapGridHtml } from './portal.js';
import { IDBStorage } from '../utils/idbStorage.js';
import { OptimisticUI } from '../utils/optimisticUI.js';
import { SmartIntelligence } from '../utils/smartIntelligence.js';
import { renderHeatmap, renderBehaviorBadge, calculateBehaviorScore } from '../utils/attendanceHeatmap.js';

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';
  
  // Standard Module Header
  const header = document.createElement('div');
  header.className = 'module-header';
  header.innerHTML = `
    <div class="module-title-area">
      <h2>👥 ${t('Students Directory')}</h2>
      <p>Manage student admissions, memberships, identity proofs, and academic records.</p>
    </div>
    <div class="module-actions">
      <button id="addStudentBtn" class="btn btn-primary d-flex align-items-center gap-2" style="font-weight: 700;">
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
        ${t('+ Add Student')}
      </button>
    </div>
  `;
  container.appendChild(header);

  // Contextual Guidance Tip Banner
  const tipBanner = document.createElement('div');
  tipBanner.style.cssText = 'background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;';
  tipBanner.innerHTML = `<span style="font-size: 1.1rem;">💡</span> <span><strong>Tip:</strong> Click any student row to view study habit consistency, attendance history, and payment ledger.</span>`;
  container.appendChild(tipBanner);

  // Standard KPI Stats Grid
  const statsContainer = document.createElement('div');
  statsContainer.className = 'kpi-grid';
  statsContainer.id = 'students-stats';
  container.appendChild(statsContainer);
  
  // Filters and Data Table Card
  const contentCard = document.createElement('div');
  contentCard.className = 'card';
  
  const filterRow = document.createElement('div');
  filterRow.className = 'card-header d-flex justify-content-between align-items-center flex-wrap gap-3';
  filterRow.innerHTML = `
    <div class="search-box w-100 w-md-auto" style="flex: 1; max-width: 360px;">
      <input type="text" id="studentSearch" class="form-control form-control-sm w-100" placeholder="${t('Search by name, phone, student ID...')}" />
    </div>
    <div class="filter-box d-flex gap-2 align-items-center w-100 w-md-auto">
      <label class="form-label mb-0 text-xs" style="font-weight: 700; color: var(--color-text-secondary);">STATUS:</label>
      <select id="studentStatusFilter" class="form-select form-control form-control-sm w-100" style="max-width: 160px; font-weight: 600;">
        <option value="all">${t('All Status')}</option>
        <option value="active">🟢 ${t('Active')}</option>
        <option value="inactive">⚪ ${t('Inactive')}</option>
        <option value="pending_payment">⏳ Pending Fee</option>
        <option value="suspended">🟡 ${t('Suspended')}</option>
        <option value="expired">🔴 ${t('Expired')}</option>
      </select>
    </div>
  `;
  contentCard.appendChild(filterRow);
  
  const tableContainer = document.createElement('div');
  tableContainer.className = 'card-body p-0';
  tableContainer.id = 'students-table-container';
  contentCard.appendChild(tableContainer);
  
  container.appendChild(contentCard);
  
  const state = {
    students: [],
    pagination: { page: 1, limit: 10, total: 0, pages: 1 }
  };

  function renderStats(stats) {
    statsContainer.innerHTML = `
      <div class="kpi-card kpi-primary">
        <div class="kpi-label">${t('Total Students')} <span>👥</span></div>
        <div class="kpi-value">${stats.total || 0}</div>
        <div class="kpi-subtext">All registered members</div>
      </div>
      <div class="kpi-card kpi-success">
        <div class="kpi-label">${t('Active Members')} <span>🟢</span></div>
        <div class="kpi-value text-success">${stats.active || 0}</div>
        <div class="kpi-subtext">Currently studying</div>
      </div>
      <div class="kpi-card kpi-danger">
        <div class="kpi-label">${t('Expired / Due')} <span>🔴</span></div>
        <div class="kpi-value text-danger">${stats.expired || 0}</div>
        <div class="kpi-subtext">Needs membership renewal</div>
      </div>
      <div class="kpi-card kpi-info">
        <div class="kpi-label">${t('New This Month')} <span>✨</span></div>
        <div class="kpi-value" style="color: var(--color-info);">${stats.newThisMonth || 0}</div>
        <div class="kpi-subtext">Recent admissions</div>
      </div>
    `;
  }

  async function loadStats() {
    let hasRenderedCache = false;
    try {
      const cachedStats = await IDBStorage.get('students', 'stats');
      if (cachedStats) {
        renderStats(cachedStats);
        hasRenderedCache = true;
      }
    } catch (e) {
      console.warn('IDB read stats warning:', e);
    }

    if (!hasRenderedCache) {
      Loading.skeleton(statsContainer, 'kpi');
    }

    try {
      const res = await api.get('/api/students/stats');
      if (res.success && res.data) {
        const stats = res.data;
        await IDBStorage.set('students', 'stats', stats);
        renderStats(stats);
      }
    } catch (err) {
      console.error(err);
    }
  }

  async function loadStudents(page = 1) {
    const search = container.querySelector('#studentSearch')?.value || '';
    const status = container.querySelector('#studentStatusFilter')?.value || 'all';
    const cacheKey = `list_${page}_${search}_${status}`;

    let hasRenderedCache = false;
    try {
      const cachedData = await IDBStorage.get('students', cacheKey);
      if (cachedData && cachedData.students) {
        state.students = cachedData.students || [];
        state.pagination = cachedData.pagination || { page: 1, limit: 10, total: 0, pages: 1 };
        renderTable();
        hasRenderedCache = true;
      }
    } catch (e) {
      console.warn('IDB read students list warning:', e);
    }
    
    if (!hasRenderedCache) {
      Loading.skeleton(tableContainer, 'table');
    }

    try {
      const res = await api.get('/api/students', { page, limit: 10, search, status });
      if (res.success && res.data) {
        state.students = res.data.students || [];
        state.pagination = res.data.pagination || { page: 1, limit: 10, total: 0, pages: 1 };
        await IDBStorage.set('students', cacheKey, res.data);
        renderTable();
      }
    } catch (err) {
      if (!hasRenderedCache) {
        Toast.error(err.message || 'Failed to load students');
        tableContainer.innerHTML = '<div class="text-center p-5 text-muted">Error loading students list.</div>';
      }
    }
  }

  function renderTable() {
    if (state.students.length === 0) {
      UI.emptyState(tableContainer, {
        icon: '🎓',
        title: 'No Students Found',
        description: 'No student records match your search or status filter. Click below to enroll a new member.',
        actionText: '+ Add Student',
        onAction: () => {
          const addBtn = container.querySelector('#addStudentBtn');
          if (addBtn) addBtn.click();
        }
      });
      return;
    }

    let rowsHtml = state.students.map(s => {
      let statusStyle = 'background: rgba(255,255,255,0.08); color: #ccc;';
      if (s.status === 'active') statusStyle = 'background: rgba(0, 184, 148, 0.2); color: var(--color-success, #00b894);';
      else if (s.status === 'pending_payment' || s.status === 'pending') statusStyle = 'background: rgba(245, 158, 11, 0.2); color: var(--color-warning, #f59e0b);';
      else if (s.status === 'expired') statusStyle = 'background: rgba(214, 48, 49, 0.2); color: var(--color-danger, #d63031);';
      else if (s.status === 'suspended') statusStyle = 'background: rgba(253, 203, 110, 0.2); color: var(--color-warning, #fdcb6e);';

      const planName = s.plan?.name || '-';
      const seatNum = s.seat?.seatNumber || '-';
      const expiry = s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : '-';

      return `
        <tr class="student-row" data-id="${escapeHTML(s._id)}" data-student-id="${escapeHTML(s.studentId || '')}">
          <td style="width: 44px; text-align: center; vertical-align: middle; padding: 0.5rem 0.25rem;">
            <label class="student-select-label" style="position: relative; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; width: 22px; height: 22px; margin: 0;">
              <input type="checkbox" class="student-select-cb" data-id="${escapeHTML(s._id)}" style="position: absolute; opacity: 0; width: 0; height: 0; margin: 0; pointer-events: none;">
              <span class="custom-select-circle" style="width: 20px; height: 20px; border-radius: 50%; border: 2px solid var(--color-border, #cbd5e1); display: inline-flex; align-items: center; justify-content: center; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); opacity: 0; font-size: 11px; color: #fff; background: transparent;">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" style="display: none;"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </span>
            </label>
          </td>
          <td class="col-student-id" style="white-space: nowrap;"><span style="font-family: monospace; font-weight: 700; display: inline-block;">${escapeHTML(s.studentId || '-')}</span> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(s.studentId || '')}" style="padding: 2px 5px; font-size: 0.7rem; display: inline-flex; align-items: center; vertical-align: middle;" title="Copy Student ID">📋</button></td>
          <td class="col-name" style="white-space: nowrap;"><strong>${escapeHTML(s.name || '-')}</strong></td>
          <td class="col-phone" style="white-space: nowrap;"><span style="display: inline-block;">${escapeHTML(SmartFormatters.phone(s.phone) || '-')}</span> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(s.phone || '')}" style="padding: 2px 5px; font-size: 0.7rem; display: inline-flex; align-items: center; vertical-align: middle;" title="Copy Phone">📋</button></td>
          <td style="white-space: nowrap;"><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary, #6c5ce7); font-weight: 600;">${escapeHTML(planName)}</span></td>
          <td style="white-space: nowrap;"><span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success, #00b894); font-weight: 600;">${escapeHTML(seatNum)}</span></td>
          <td style="white-space: nowrap;">${expiry} ${s.expiryDate ? `<small class="text-muted">(${SmartFormatters.timeAgo(s.expiryDate)})</small>` : ''}</td>
          <td class="col-status" style="white-space: nowrap;"><span class="badge btn-toggle-student-status" data-id="${escapeHTML(s._id)}" style="${statusStyle} padding: 4px 8px; border-radius: 4px; font-weight: 600; text-transform: uppercase; font-size: 0.75rem; cursor: pointer;" title="Click to toggle status">${escapeHTML(s.status || 'active')}</span></td>
          <td style="white-space: nowrap;">
            <div style="width: 85px;" title="KYC Profile Completion: ${s.profileCompletion || 60}%">
              <div style="display: flex; align-items: center; justify-content: space-between; font-size: 0.72rem; font-weight: 800; color: ${s.profileCompletion >= 100 ? 'var(--color-success)' : '#f59e0b'}; margin-bottom: 2px;">
                <span>${s.profileCompletion >= 100 ? '🟢 100%' : `🟡 ${s.profileCompletion || 60}%`}</span>
              </div>
              <div style="width: 100%; height: 5px; background: rgba(255,255,255,0.12); border-radius: 4px; overflow: hidden;">
                <div style="height: 100%; width: ${s.profileCompletion || 60}%; background: ${s.profileCompletion >= 100 ? '#00b894' : 'linear-gradient(90deg, #f59e0b, #00b894)'}; border-radius: 4px;"></div>
              </div>
            </div>
          </td>
          <td style="white-space: nowrap;">
            <div class="d-inline-flex gap-1 align-items-center">
              <button class="btn btn-sm btn-outline-secondary btn-view" data-id="${escapeHTML(s._id)}" title="View 360° Profile" style="padding: 4px 8px; font-size: 0.75rem; white-space: nowrap;">👁️ View</button>
              <button class="btn btn-sm btn-outline-success btn-wa-remind" data-id="${escapeHTML(s._id)}" title="Send WhatsApp Reminder" style="padding: 4px 8px; font-size: 0.75rem; white-space: nowrap;">📲 WhatsApp</button>
              <button class="btn btn-sm btn-outline-warning btn-pwdreset" data-id="${escapeHTML(s._id)}" title="Reset Password / PIN" style="padding: 4px 6px; font-size: 0.75rem;">🔑</button>
              <button class="btn btn-sm btn-outline-info btn-idcard" data-id="${escapeHTML(s._id)}" title="Print ID Card" style="padding: 4px 6px; font-size: 0.75rem;">🪪</button>
              <button class="btn btn-sm btn-outline-success btn-pdfform" data-id="${escapeHTML(s._id)}" title="Download PDF Form" style="padding: 4px 6px; font-size: 0.75rem;">📄</button>
              <button class="btn btn-sm btn-outline-primary btn-edit" data-id="${escapeHTML(s._id)}" title="Edit Student" style="padding: 4px 6px; font-size: 0.75rem;">✏️</button>
              <button class="btn btn-sm btn-outline-danger btn-delete" data-id="${escapeHTML(s._id)}" title="Delete Student" style="padding: 4px 6px; font-size: 0.75rem;">🗑️</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');

    tableContainer.innerHTML = `
      <style>
        .students-table-container tr .custom-select-circle {
          opacity: 0;
          transform: scale(0.85);
          transition: opacity 0.2s ease, transform 0.2s ease, background-color 0.2s ease, border-color 0.2s ease;
        }
        .students-table-container tr:hover .custom-select-circle {
          opacity: 0.65;
          transform: scale(1);
          border-color: var(--color-primary, #6c5ce7);
        }
        .students-table-container.has-selections thead .master-select-circle,
        .students-table-container thead:hover .master-select-circle {
          opacity: 0.65 !important;
          transform: scale(1) !important;
        }
        .students-table-container .student-select-cb:checked + .custom-select-circle,
        .students-table-container #selectAllStudents:checked + .custom-select-circle {
          opacity: 1 !important;
          transform: scale(1) !important;
          background-color: var(--color-primary, #6c5ce7) !important;
          border-color: var(--color-primary, #6c5ce7) !important;
        }
        .students-table-container .student-select-cb:checked + .custom-select-circle svg,
        .students-table-container #selectAllStudents:checked + .custom-select-circle svg {
          display: block !important;
        }
        .students-table-container tr.row-selected {
          background-color: rgba(108, 92, 231, 0.08) !important;
        }
      </style>

      <!-- Floating Bulk Action Bar -->
      <div id="bulk-actions-bar" style="display: none; padding: 0.75rem 1.25rem; background: var(--color-surface); border-bottom: 2px solid var(--color-primary); justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
        <div class="d-flex align-items-center gap-2">
          <span class="badge badge-primary" id="selected-count-badge">0 selected</span>
          <span class="text-muted small">Bulk Actions:</span>
        </div>
        <div class="d-flex gap-2 flex-wrap">
          <button class="btn btn-sm btn-outline-success" id="btn-bulk-whatsapp" style="font-size: 0.8rem; font-weight: 600;">
            📲 WhatsApp Reminders
          </button>
          <button class="btn btn-sm btn-outline-primary" id="btn-bulk-renew" style="font-size: 0.8rem; font-weight: 600;">
            🔄 Bulk Renew (+30d)
          </button>
          <button class="btn btn-sm btn-outline-secondary" id="btn-bulk-export" style="font-size: 0.8rem; font-weight: 600;">
            📄 Export Selected
          </button>
          <button class="btn btn-sm btn-outline-danger" id="btn-bulk-deactivate" style="font-size: 0.8rem; font-weight: 600;">
            🗑️ Deactivate Selected
          </button>
        </div>
      </div>

      <div class="table-responsive students-table-container">
        <table class="table data-table mb-0">
          <thead>
            <tr>
              <th style="width: 44px; text-align: center; vertical-align: middle; padding: 0.5rem 0.25rem;">
                <label class="select-all-label" style="position: relative; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; width: 22px; height: 22px; margin: 0;" title="Select All Students">
                  <input type="checkbox" id="selectAllStudents" style="position: absolute; opacity: 0; width: 0; height: 0; margin: 0; pointer-events: none;">
                  <span class="custom-select-circle master-select-circle" style="width: 20px; height: 20px; border-radius: 50%; border: 2px solid var(--color-border, #cbd5e1); display: inline-flex; align-items: center; justify-content: center; transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1); opacity: 0; font-size: 11px; color: #fff; background: transparent;">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" style="display: none;"><polyline points="20 6 9 17 4 12"></polyline></svg>
                  </span>
                </label>
              </th>
              <th class="col-student-id">Student ID</th>
              <th class="col-name">Name</th>
              <th class="col-phone">Phone</th>
              <th>Plan</th>
              <th>Seat</th>
              <th>Expiry Date</th>
              <th class="col-status">Status</th>
              <th>Profile KYC</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rowsHtml}
          </tbody>
        </table>
      </div>
    `;

    // Bulk action bar logic
    const selectAll = tableContainer.querySelector('#selectAllStudents');
    const cbs = tableContainer.querySelectorAll('.student-select-cb');
    const bulkBar = tableContainer.querySelector('#bulk-actions-bar');
    const countBadge = tableContainer.querySelector('#selected-count-badge');
    const tableResp = tableContainer.querySelector('.students-table-container');

    function updateBulkBar() {
      const selectedCbs = Array.from(cbs).filter(cb => cb.checked);
      const selectedCount = selectedCbs.length;

      // Highlight selected rows
      cbs.forEach(cb => {
        const tr = cb.closest('tr');
        if (tr) tr.classList.toggle('row-selected', cb.checked);
      });

      if (selectedCount > 0) {
        bulkBar.style.display = 'flex';
        countBadge.textContent = `${selectedCount} student(s) selected`;
        tableResp?.classList.add('has-selections');
        if (selectAll) selectAll.checked = selectedCount === cbs.length;
      } else {
        bulkBar.style.display = 'none';
        tableResp?.classList.remove('has-selections');
        if (selectAll) selectAll.checked = false;
      }
    }

    if (selectAll) {
      selectAll.addEventListener('change', () => {
        cbs.forEach(cb => cb.checked = selectAll.checked);
        updateBulkBar();
      });
    }

    cbs.forEach(cb => {
      cb.addEventListener('change', () => {
        if (!cb.checked && selectAll) selectAll.checked = false;
        updateBulkBar();
      });
    });

    // Bulk WhatsApp Blast — opens wa.me/ links with filter options
    tableContainer.querySelector('#btn-bulk-whatsapp')?.addEventListener('click', async () => {
      const selectedIds = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      const selectedStudents = state.students.filter(s => selectedIds.includes(s._id));
      await openWABlastModal(selectedStudents, loadStudents, state, api, Toast, Modal, Confirm, escapeHTML);
    });

    // Bulk Renew
    tableContainer.querySelector('#btn-bulk-renew')?.addEventListener('click', async (e) => {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length === 0) return;
      const ok = await Confirm.show({
        title: 'Bulk Renew Memberships',
        message: `Are you sure you want to extend validity by 30 days for ${selected.length} selected student(s)?`
      });
      if (ok) {
        const btn = e.currentTarget;
        UI.buttonLoading(btn, true, 'Renewing...');
        try {
          const res = await api.post('/api/students/bulk-renew', { studentIds: selected, days: 30 });
          Toast.success(res.message);
          await IDBStorage.clear('students');
          loadStudents(state.pagination.page);
          loadStats();
        } catch (err) {
          Toast.error(err.message || 'Bulk renew failed');
        } finally {
          UI.buttonLoading(btn, false);
        }
      }
    });

    // Bulk Deactivate
    tableContainer.querySelector('#btn-bulk-deactivate')?.addEventListener('click', async (e) => {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length === 0) return;
      const ok = await Confirm.show({
        title: 'Bulk Deactivate',
        message: `Are you sure you want to mark ${selected.length} student(s) as inactive?`,
        danger: true
      });
      if (ok) {
        const btn = e.currentTarget;
        UI.buttonLoading(btn, true, 'Deactivating...');
        try {
          const res = await api.post('/api/students/bulk-deactivate', { studentIds: selected });
          Toast.success(res.message);
          await IDBStorage.clear('students');
          loadStudents(state.pagination.page);
          loadStats();
        } catch (err) {
          Toast.error(err.message || 'Bulk deactivation failed');
        } finally {
          UI.buttonLoading(btn, false);
        }
      }
    });

    // Bulk Export
    tableContainer.querySelector('#btn-bulk-export')?.addEventListener('click', () => {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length === 0) return;
      const selectedStudents = state.students.filter(s => selected.includes(s._id));
      const headers = ['ID', 'Name', 'Phone', 'Email', 'Plan', 'Seat', 'Expiry', 'Status'];
      const rows = selectedStudents.map(s => [
        s.studentId,
        `"${s.name}"`,
        s.phone,
        s.email || '',
        s.plan?.name || '',
        s.seat?.seatNumber || '',
        s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : '',
        s.status
      ]);
      const csv = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
      const a = document.createElement('a');
      a.href = encodeURI(csv);
      a.download = `selected_students_${Date.now()}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      Toast.success(`Exported ${selected.length} students to CSV`);
    });

    // Pagination
    if (state.pagination.pages > 1) {
      const paginationDiv = document.createElement('div');
      paginationDiv.className = 'd-flex justify-content-between align-items-center p-3 border-top';
      
      const prevBtn = document.createElement('button');
      prevBtn.className = 'btn btn-sm btn-outline-secondary';
      prevBtn.textContent = 'Previous';
      prevBtn.disabled = state.pagination.page <= 1;
      prevBtn.onclick = () => loadStudents(state.pagination.page - 1);

      const nextBtn = document.createElement('button');
      nextBtn.className = 'btn btn-sm btn-outline-secondary';
      nextBtn.textContent = 'Next';
      nextBtn.disabled = state.pagination.page >= state.pagination.pages;
      nextBtn.onclick = () => loadStudents(state.pagination.page + 1);
      
      const pageInfo = document.createElement('span');
      pageInfo.className = 'text-muted small';
      pageInfo.textContent = `Page ${state.pagination.page} of ${state.pagination.pages} (${state.pagination.total} total)`;
      
      paginationDiv.appendChild(prevBtn);
      paginationDiv.appendChild(pageInfo);
      paginationDiv.appendChild(nextBtn);
      
      tableContainer.appendChild(paginationDiv);
    }
  }

  async function showStudentForm(student = null) {
    const isEdit = !!student;
    // Fetch available plans, seats, custom fields, and active form template
    let plansOptions = '<option value="">-- Select Plan (Optional) --</option>';
    let seatsOptions = '<option value="">-- Select Seat (Optional) --</option>';
    let rawAvailableSeats = [];
    let customFields = [];
    let template = {};
    
    try {
      const [plansRes, seatsRes, cfRes, tplRes] = await Promise.all([
        api.get('/api/plans'),
        api.get('/api/seats?status=available'),
        api.get('/api/custom-fields/all'),
        api.get('/api/custom-fields/templates/active')
      ]);
      
      if (plansRes?.success && plansRes.data) {
        plansRes.data.forEach(p => {
          const selected = (student && student.plan && (student.plan._id === p._id || student.plan === p._id)) ? 'selected' : '';
          plansOptions += `<option value="${p._id}" ${selected}>${escapeHTML(p.name)} - ₹${p.price} (${p.duration} ${p.durationType})</option>`;
        });
      }
      
      if (seatsRes?.success && seatsRes.data) {
        rawAvailableSeats = seatsRes.data;
        seatsRes.data.forEach(s => {
          const selected = (student && student.seat && (student.seat._id === s._id || student.seat === s._id)) ? 'selected' : '';
          seatsOptions += `<option value="${s._id}" ${selected}>${escapeHTML(s.seatNumber)} (${escapeHTML(s.zone)} - ${escapeHTML(s.type)})</option>`;
        });
      }
      if (student && student.seat && typeof student.seat === 'object') {
        if (!seatsOptions.includes(student.seat._id)) {
          seatsOptions += `<option value="${student.seat._id}" selected>${escapeHTML(student.seat.seatNumber)} (Current)</option>`;
        }
      }

      if (cfRes?.success && cfRes?.data) {
        customFields = cfRes.data;
      }
      if (tplRes?.success && tplRes?.data) {
        template = tplRes.data;
      }
    } catch (err) {
      console.error('Error fetching student modal dependencies:', err);
    }

    // Helper to extract student field values
    function getVal(fieldName) {
      if (!student) return '';
      if (student[fieldName] !== undefined && student[fieldName] !== null) return student[fieldName];
      if (fieldName === 'idProofType') return student.idProof?.type || 'Aadhaar Card';
      if (fieldName === 'idProofNumber') return student.idProof?.number || '';
      if (fieldName === 'idProofImage') return student.idProof?.image || '';
      if (fieldName === 'emergencyContactName') return student.emergencyContact?.name || '';
      if (fieldName === 'emergencyContactPhone') return student.emergencyContact?.phone || '';
      if (fieldName === 'emergencyContactRelation') return student.emergencyContact?.relation || '';
      if (fieldName === 'dateOfBirth' && student.dateOfBirth) {
        const d = new Date(student.dateOfBirth);
        return isNaN(d.getTime()) ? '' : d.toISOString().split('T')[0];
      }
      if (student.customFields) {
        if (student.customFields instanceof Map) return student.customFields.get(fieldName) || '';
        if (typeof student.customFields === 'object') return student.customFields[fieldName] || '';
      }
      return '';
    }

    // 1. Group active fields by Form Builder configured sections (Strict Deduplication)
    const configuredSections = (template.sections && template.sections.length > 0)
      ? template.sections.filter(s => !s.isHidden).sort((a, b) => (a.order || 0) - (b.order || 0))
      : [
          { name: 'personal', label: 'Personal & Contact Details', icon: 'personal' },
          { name: 'academic', label: 'Academic Goals & KYC Verification', icon: 'academic' },
          { name: 'seat', label: 'Declaration & Signature', icon: 'seat' }
        ];

    const seenFieldNames = new Set();
    const adminFieldKeys = new Set(['plan', 'seat', 'status', 'notes', 'rfidCardNumber', 'biometricId']);
    const activeFields = [];

    (customFields || []).forEach(f => {
      if (f.isActive === false) return;
      const key = (f.fieldName || '').trim().toLowerCase();
      if (!key) return;
      // Skip if handled by admin allotment card or if already rendered once (no duplicates!)
      if (adminFieldKeys.has(f.fieldName) || seenFieldNames.has(key)) return;
      seenFieldNames.add(key);
      activeFields.push(f);
    });

    activeFields.sort((a, b) => (a.order || 0) - (b.order || 0));

    const sectionsMap = new Map();
    configuredSections.forEach(s => {
      sectionsMap.set(s.name, {
        key: s.name,
        label: s.label,
        icon: s.icon,
        fields: []
      });
    });

    // Distribute unique fields to sections
    activeFields.forEach(f => {
      const secKey = f.section || 'personal';
      if (sectionsMap.has(secKey)) {
        sectionsMap.get(secKey).fields.push(f);
      } else {
        const firstSec = sectionsMap.values().next().value;
        if (firstSec) firstSec.fields.push(f);
      }
    });

    // 2. Render each field dynamically
    function renderFieldInput(f) {
      const val = getVal(f.fieldName);
      const reqMark = f.required ? ' <span class="text-danger">*</span>' : '';
      const colClass = f.type === 'textarea' || f.type === 'address_autocomplete' || f.type === 'aadhaar_pan' || f.type === 'exam_badge' || f.type === 'signature_pad' ? 'col-12' : (f.colSpan === 12 || f.colSpan === 2 ? 'col-12' : 'col-md-6');
      // Support both new showIf API and legacy conditional.enabled API
      const showIfConfig = f.showIf || (f.conditional?.enabled ? { field: f.conditional.dependsOn, operator: f.conditional.operator || 'equals', value: f.conditional.showWhen } : null);
      const depAttr = showIfConfig ? `data-depends-on="${escapeHTML(showIfConfig.field)}" data-show-when="${escapeHTML(showIfConfig.value || '')}" data-operator="${escapeHTML(showIfConfig.operator || 'equals')}" style="display:none;"` : '';
      const helpText = f.helpText ? `<small class="text-muted d-block" style="font-size: 0.72rem; margin-top: 3px;">${escapeHTML(f.helpText)}</small>` : '';

      if (f.type === 'photo_upload') {
        return `
          <div class="col-12 mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">📷 ${escapeHTML(f.label)}${reqMark}</label>
            <div id="mount-student-photo" class="custom-media-mount" data-field="${escapeHTML(f.fieldName)}" data-preset="passport" data-label="${escapeHTML(f.label)}"></div>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'signature_pad') {
        return `
          <div class="col-12 mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">✍️ ${escapeHTML(f.label)}${reqMark}</label>
            <div id="admission-signature-studio-mount"></div>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'aadhaar_pan') {
        return `
          <div class="col-12 mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">📑 ${escapeHTML(f.label)}${reqMark}</label>
            <div class="row g-2 mb-2" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
              <div>
                <label class="form-label text-xs">ID Proof Type</label>
                <select class="form-select form-control" name="idProof.type">
                  <option value="Aadhaar Card" ${getVal('idProofType') === 'Aadhaar Card' ? 'selected' : ''}>Aadhaar Card</option>
                  <option value="PAN Card" ${getVal('idProofType') === 'PAN Card' ? 'selected' : ''}>PAN Card</option>
                  <option value="Driving License" ${getVal('idProofType') === 'Driving License' ? 'selected' : ''}>Driving License</option>
                  <option value="Voter ID" ${getVal('idProofType') === 'Voter ID' ? 'selected' : ''}>Voter ID Card</option>
                  <option value="College ID" ${getVal('idProofType') === 'College ID' ? 'selected' : ''}>College Student ID</option>
                  <option value="Passport" ${getVal('idProofType') === 'Passport' ? 'selected' : ''}>Passport</option>
                </select>
              </div>
              <div>
                <label class="form-label text-xs">ID Proof Number</label>
                <input type="text" class="form-control" name="idProof.number" value="${escapeHTML(getVal('idProofNumber'))}" placeholder="e.g. 1234 5678 9012">
              </div>
            </div>
            <div id="mount-student-idproof" class="custom-media-mount" data-field="idProofImage" data-preset="document" data-label="ID Proof Document Upload"></div>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'exam_badge') {
        const examsList = ['UPSC', 'MPSC', 'SSC CGL', 'Banking / IBPS', 'JEE', 'NEET', 'CA / CS', 'GATE', 'CAT / MBA', 'Law / CLAT', 'UGC NET', 'State PSC', 'Other'];
        const selectedArr = Array.isArray(val) ? val : (typeof val === 'string' && val ? val.split(',') : []);
        return `
          <div class="col-12 mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">🎯 ${escapeHTML(f.label)}${reqMark}</label>
            <div id="exam-chips-container" style="display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px;">
              ${examsList.map(ex => {
                const isSel = selectedArr.includes(ex);
                return `
                  <button type="button" class="btn btn-sm exam-chip-btn ${isSel ? 'btn-primary' : 'btn-outline-secondary'}" data-exam="${ex}" style="border-radius: 16px; font-size: 0.8rem; padding: 3px 10px;">
                    ${ex}
                  </button>
                `;
              }).join('')}
            </div>
            <input type="hidden" name="targetExams" id="selectedTargetExams" value="${escapeHTML(selectedArr.join(','))}">
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'blood_group') {
        const bgOptions = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];
        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">🩸 ${escapeHTML(f.label)}${reqMark}</label>
            <select class="form-select form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" ${f.required ? 'required' : ''}>
              <option value="">-- Select Blood Group --</option>
              ${bgOptions.map(bg => `<option value="${bg}" ${val === bg ? 'selected' : ''}>${bg}</option>`).join('')}
            </select>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'star_rating') {
        const curRating = parseInt(val, 10) || 5;
        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">⭐ ${escapeHTML(f.label)}${reqMark}</label>
            <div class="star-rating-wrap modal-star-rating" data-field="${escapeHTML(f.fieldName)}" style="display: inline-flex; gap: 6px; font-size: 1.4rem; cursor: pointer;">
              ${[1, 2, 3, 4, 5].map(v => `<span class="star-rating-item ${v <= curRating ? 'active' : ''}" data-val="${v}" style="color: ${v <= curRating ? '#f59e0b' : '#d1d5db'};">★</span>`).join('')}
            </div>
            <input type="hidden" class="custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" value="${curRating}">
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'file') {
        return `
          <div class="${colClass} mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">📎 ${escapeHTML(f.label)}${reqMark}</label>
            <div class="custom-field-media-mount" data-field="${escapeHTML(f.fieldName)}" data-label="${escapeHTML(f.label)}" data-preset="document"></div>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'select') {
        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
            <select class="form-select form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" ${f.required ? 'required' : ''}>
              <option value="">-- Select --</option>
              ${(f.options || []).map(opt => `<option value="${escapeHTML(opt)}" ${val === opt ? 'selected' : ''}>${escapeHTML(opt)}</option>`).join('')}
            </select>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'radio') {
        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
            <div style="display: flex; gap: 12px; flex-wrap: wrap; margin-top: 4px;">
              ${(f.options || []).map(opt => `
                <label style="display: inline-flex; align-items: center; gap: 4px; font-size: 0.88rem; cursor: pointer;">
                  <input type="radio" class="custom-dyn-radio" name="${escapeHTML(f.fieldName)}" data-field="${escapeHTML(f.fieldName)}" value="${escapeHTML(opt)}" ${val === opt ? 'checked' : ''}>
                  ${escapeHTML(opt)}
                </label>
              `).join('')}
            </div>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'checkbox' || f.type === 'terms_checkbox' || f.type === 'consent_checkbox') {
        const isChecked = val === true || val === 'true' || val === 'on' || val === 1;
        return `
          <div class="col-12 mt-1 dynamic-field-wrapper" ${depAttr}>
            <div style="background: var(--color-bg-secondary); padding: 10px 14px; border-radius: var(--radius-md); border: 1px solid var(--color-border);">
              <label style="display: flex; align-items: center; gap: 8px; cursor: pointer; font-size: 0.9rem; font-weight: 500; margin: 0;">
                <input type="checkbox" class="custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" ${isChecked ? 'checked' : ''} ${f.required ? 'required' : ''} style="width: 17px; height: 17px; accent-color: var(--color-primary);">
                <span>${escapeHTML(f.label)}${reqMark}</span>
              </label>
              ${helpText}
            </div>
          </div>
        `;
      }

      if (f.type === 'textarea') {
        return `
          <div class="col-12 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
            <textarea class="form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" rows="2" placeholder="${escapeHTML(f.placeholder || '')}" ${f.required ? 'required' : ''}>${escapeHTML(val)}</textarea>
            ${helpText}
          </div>
        `;
      }

      const inputType = f.type === 'number' ? 'number' : (f.type === 'date' ? 'date' : (f.type === 'time' ? 'time' : (f.type === 'email' ? 'email' : (f.type === 'phone' ? 'tel' : 'text'))));

      return `
        <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
          <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
          <input type="${inputType}" class="form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" value="${escapeHTML(val)}" placeholder="${escapeHTML(f.placeholder || '')}" ${f.required ? 'required' : ''}>
          ${helpText}
        </div>
      `;
    }

    // 3. Build Form Sections HTML dynamically
    let dynamicSectionsHtml = '';
    sectionsMap.forEach(sec => {
      if (sec.fields.length === 0) return;
      dynamicSectionsHtml += `
        <div class="col-12 mt-3 mb-1" style="border-top: 1px solid var(--color-border); padding-top: 10px;">
          <h5 style="font-size: 1rem; font-weight: 700; color: var(--color-primary); margin-bottom: 8px; display: flex; align-items: center; gap: 8px;">
            <span>📝</span>
            <span>${escapeHTML(sec.label)}</span>
          </h5>
        </div>
        ${sec.fields.map(f => renderFieldInput(f)).join('')}
      `;
    });

    const formHtml = !isEdit ? `
      <form id="studentForm">
        <div class="row" style="row-gap: 12px;">
          
          <!-- 🚀 10-Second Express Walk-in Card (Placed Right at Top for Instant Admission) -->
          <div class="col-12" style="background: rgba(108, 92, 231, 0.08); border: 1.5px solid var(--color-primary); border-radius: var(--radius-lg); padding: 1.25rem; box-shadow: var(--shadow-xs);">
            <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 1rem; flex-wrap: wrap; gap: 8px;">
              <h5 style="margin: 0; font-size: 1.05rem; font-weight: 800; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                <span>🚀</span> 10-Second Express Walk-in Admission
              </h5>
              <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.75rem;">Fast Entry Mode</span>
            </div>

            <div class="row" style="row-gap: 12px;">
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Full Student Name *</label>
                <input type="text" class="form-control custom-dyn-input" name="name" data-field="name" value="${escapeHTML(getVal('name'))}" placeholder="e.g. Rahul Sharma" required style="font-weight: 600;">
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Mobile Number (WhatsApp) *</label>
                <input type="tel" class="form-control custom-dyn-input" name="phone" data-field="phone" value="${escapeHTML(getVal('phone'))}" placeholder="10-digit mobile (e.g. 9876543210)" required style="font-weight: 600;">
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Select Membership Plan *</label>
                <select class="form-select form-control" name="plan" style="font-weight: 600;">
                  ${plansOptions}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Select Reserved Study Desk / Seat</label>
                <select class="form-select form-control" name="seat" style="font-weight: 600;">
                  ${seatsOptions}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Membership Status</label>
                <select class="form-select form-control" name="status" style="font-weight: 600;">
                  <option value="active" selected>🟢 Active (Instant Access)</option>
                  <option value="pending_payment">🟡 Pending Cash Payment</option>
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Payment Mode Collected</label>
                <select class="form-select form-control" name="paymentMode" style="font-weight: 600;">
                  <option value="cash" selected>💵 Cash at Reception Desk</option>
                  <option value="upi">⚡ Direct UPI / GPay / PhonePe</option>
                  <option value="card">💳 Debit / Credit Card</option>
                </select>
              </div>
            </div>
          </div>

          <!-- Collapsible Accordion: Optional Extended Details (KYC Photo, Guardian Contact, Address & RFID) -->
          <div class="col-12 mt-2">
            <details style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 12px 16px;">
              <summary style="cursor: pointer; font-weight: 700; font-size: 0.9rem; color: var(--color-primary); display: flex; align-items: center; gap: 8px;">
                <span>➕ Optional Extended Details (KYC Photo, Guardian Contact, Address & RFID)</span>
              </summary>
              <div class="row mt-3" style="row-gap: 12px;">
                ${dynamicSectionsHtml}

                <div class="col-md-6">
                  <label class="form-label" style="font-weight: 600;">🏷️ RFID Smart Card UID</label>
                  <input type="text" class="form-control" name="rfidCardNumber" value="${student && student.rfidCardNumber ? escapeHTML(student.rfidCardNumber) : ''}" placeholder="Scan card or enter Hex/DEC UID">
                </div>

                <div class="col-md-6">
                  <label class="form-label" style="font-weight: 600;">👤 Biometric / Machine ID</label>
                  <input type="text" class="form-control" name="biometricId" value="${student && student.biometricId ? escapeHTML(student.biometricId) : ''}" placeholder="e.g. BIO-101 / Finger ID">
                </div>

                <div class="col-12">
                  <label class="form-label" style="font-weight: 600;">Special Remarks / Admin Notes</label>
                  <textarea class="form-control" name="notes" rows="2" placeholder="Any health conditions, locker preference, discount notes, etc.">${student && student.notes ? escapeHTML(student.notes) : ''}</textarea>
                </div>
              </div>
            </details>
          </div>

        </div>
      </form>
    ` : `
      <form id="studentForm">
        <div class="row" style="row-gap: 12px;">
          <!-- Dynamically Grouped Form Sections -->
          ${dynamicSectionsHtml}

          <!-- Administrative & Membership Allotment Section Card -->
          <div class="col-12 mt-3" style="border-top: 2px dashed var(--color-primary); padding-top: 12px; background: rgba(108, 92, 231, 0.04); border-radius: var(--radius-md); padding: 14px;">
            <h5 style="font-size: 1rem; font-weight: 700; color: var(--color-primary); margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
              <span>🏛️</span>
              <span>Administrative & Membership Allotment</span>
            </h5>
            
            <div class="row" style="row-gap: 12px;">
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">Membership Plan</label>
                <select class="form-select form-control" name="plan">
                  ${plansOptions}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">Assigned Study Desk / Seat</label>
                <select class="form-select form-control" name="seat">
                  ${seatsOptions}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">Membership Status</label>
                <select class="form-select form-control" name="status">
                  <option value="active" ${!student || student.status === 'active' ? 'selected' : ''}>🟢 Active</option>
                  <option value="inactive" ${student && student.status === 'inactive' ? 'selected' : ''}>🔴 Inactive</option>
                  <option value="suspended" ${student && student.status === 'suspended' ? 'selected' : ''}>🟡 Suspended</option>
                  <option value="expired" ${student && student.status === 'expired' ? 'selected' : ''}>⚪ Expired</option>
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">🏷️ RFID Smart Card UID</label>
                <input type="text" class="form-control" name="rfidCardNumber" value="${student && student.rfidCardNumber ? escapeHTML(student.rfidCardNumber) : ''}" placeholder="Scan card or enter Hex/DEC UID">
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">👤 Biometric / Machine ID</label>
                <input type="text" class="form-control" name="biometricId" value="${student && student.biometricId ? escapeHTML(student.biometricId) : ''}" placeholder="e.g. BIO-101 / Finger ID">
              </div>

              <div class="col-12">
                <label class="form-label" style="font-weight: 600;">Special Remarks / Admin Notes</label>
                <textarea class="form-control" name="notes" rows="2" placeholder="Any health conditions, locker preference, discount notes, etc.">${student && student.notes ? escapeHTML(student.notes) : ''}</textarea>
              </div>
            </div>
          </div>
        </div>
      </form>
    `;

    let sigStudio = null;

    const modal = new Modal({
      title: isEdit ? 'Edit Student Details' : 'Add New Student Admission',
      content: formHtml,
      size: 'lg',
      buttons: [
        {
          text: 'Cancel',
          className: 'btn-secondary',
          onClick: (m) => m.close()
        },
        {
          text: isEdit ? 'Update Student' : 'Save Admission',
          className: 'btn-primary',
          onClick: async (m) => {
            const form = m.element.querySelector('#studentForm');
            if (!form.checkValidity()) {
              form.reportValidity();
              return;
            }
            
            const formData = new FormData(form);
            const data = Object.fromEntries(formData.entries());
            
            // Handle target exams array
            const examsStr = data.targetExams || '';
            data.targetExams = examsStr ? examsStr.split(',').filter(Boolean) : [];

            // Capture all custom dynamic fields
            data.customFields = {};
            m.element.querySelectorAll('.custom-dyn-input').forEach(input => {
              const fName = input.dataset.field;
              if (fName) {
                if (input.type === 'checkbox') {
                  data.customFields[fName] = input.checked;
                } else {
                  data.customFields[fName] = input.value;
                }
              }
            });

            // Capture radio buttons
            m.element.querySelectorAll('.custom-dyn-radio:checked').forEach(radio => {
              const fName = radio.dataset.field;
              if (fName) data.customFields[fName] = radio.value;
            });

            // Capture custom media fields
            m.element.querySelectorAll('.custom-field-media-mount').forEach(mount => {
              const fName = mount.dataset.field;
              const val = mount.querySelector('.mfp-hidden-value')?.value || '';
              if (val) data.customFields[fName] = val;
            });

            // Capture Passport Photo
            const photoVal = m.element.querySelector('#mount-student-photo .mfp-hidden-value')?.value;
            if (photoVal !== undefined) data.photo = photoVal;

            // Capture KYC ID Proof image
            const kycVal = m.element.querySelector('#mount-student-idproof .mfp-hidden-value')?.value;
            if (kycVal !== undefined) data.idProofImage = kycVal;

            // Capture Signature from SignatureStudio
            if (sigStudio) {
              const sigVal = sigStudio.getValue();
              if (sigVal) data.signature = sigVal;
            }

            // Handle optional references
            if (!data.plan) delete data.plan;
            if (!data.seat) delete data.seat;
            if (!data.dateOfBirth) delete data.dateOfBirth;

            // Reconstruct KYC idProof object
            data.idProof = {
              type: data['idProof.type'] || 'Aadhaar Card',
              number: data['idProof.number'] || '',
              image: data.idProofImage || student?.idProof?.image || ''
            };
            delete data['idProof.type'];
            delete data['idProof.number'];
            delete data.idProofImage;

            // Reconstruct emergency contact if present
            data.emergencyContact = {
              name: data['emergencyContactName'] || data['emergencyContact.name'] || student?.emergencyContact?.name || '',
              phone: data['emergencyContactPhone'] || data['emergencyContact.phone'] || student?.emergencyContact?.phone || '',
              relation: data['emergencyContactRelation'] || data['emergencyContact.relation'] || student?.emergencyContact?.relation || ''
            };

            const prevStatus = student?.status;
            const prevSeat = student?.seat;

            try {
              await OptimisticUI.execute({
                applyState: () => {
                  if (isEdit && student) {
                    if (data.status) student.status = data.status;
                    if ('seat' in data) {
                      student.seat = data.seat ? { _id: data.seat } : null;
                    }
                    renderTable();
                  }
                },
                rollbackState: () => {
                  if (isEdit && student) {
                    student.status = prevStatus;
                    student.seat = prevSeat;
                    renderTable();
                  }
                },
                apiCall: () => isEdit ? api.put(`/api/students/${student._id}`, data) : api.post('/api/students', data),
                onSuccess: async (res) => {
                  Toast.success(res.message || 'Student saved successfully');
                  // 🎉 Phase 7: Confetti celebration on new admission
                  if (!isEdit && typeof window.confettiCelebrate === 'function') {
                    window.confettiCelebrate({ duration: 2500 });
                  }
                  // Refresh notification bell badge
                  if (typeof window.refreshNotifications === 'function') window.refreshNotifications();
                  m.close();
                  await IDBStorage.clear('students');
                  loadStats();
                  loadStudents(state.pagination.page);
                }
              });
            } catch (err) {
              // Handled by OptimisticUI
            }
          }
        }
      ]
    });
    
    modal.open();

    // Initialize Smart Photo Picker
    const photoMount = modal.element.querySelector('#mount-student-photo');
    if (photoMount) {
      photoMount.appendChild(MediaFieldPicker.create({
        label: 'Student Passport Photo',
        preset: 'passport',
        name: 'photo',
        value: student?.photo || ''
      }));
    }

    // Initialize Smart KYC Document Picker
    const kycMount = modal.element.querySelector('#mount-student-idproof');
    if (kycMount) {
      kycMount.appendChild(MediaFieldPicker.create({
        label: 'ID Proof Document Scan / Photo',
        preset: 'document',
        name: 'idProofImage',
        value: student?.idProof?.image || ''
      }));
    }

    // Initialize Custom Dynamic Field Media Pickers
    modal.element.querySelectorAll('.custom-field-media-mount').forEach(mount => {
      const fName = mount.dataset.field;
      const fLabel = mount.dataset.label;
      const fPreset = mount.dataset.preset;
      const val = student?.customFields?.[fName] || '';
      mount.appendChild(MediaFieldPicker.create({
        label: fLabel,
        preset: fPreset,
        name: fName,
        value: val
      }));
    });

    // Bind Dynamic ID Proof Type & Number Validation
    if (window.SmartIntelligence && typeof window.SmartIntelligence.bindDynamicIDProofValidation === 'function') {
      window.SmartIntelligence.bindDynamicIDProofValidation(modal.element);
    }

    // Initialize Smart Signature Studio
    const sigMount = modal.element.querySelector('#admission-signature-studio-mount');
    if (sigMount) {
      sigStudio = new SignatureStudio(sigMount, {
        value: student?.signature,
        studentName: student?.name,
        width: 500,
        height: 140
      });
    }

    // Setup Exam Chips Toggling
    const chipsContainer = modal.element.querySelector('#exam-chips-container');
    const selectedExamsInput = modal.element.querySelector('#selectedTargetExams');
    if (chipsContainer && selectedExamsInput) {
      let selectedSet = new Set(selectedExamsInput.value ? selectedExamsInput.value.split(',') : []);
      chipsContainer.querySelectorAll('.exam-chip-btn').forEach(chip => {
        chip.addEventListener('click', () => {
          const ex = chip.dataset.exam;
          if (selectedSet.has(ex)) {
            selectedSet.delete(ex);
            chip.classList.remove('btn-primary');
            chip.classList.add('btn-outline-secondary');
          } else {
            selectedSet.add(ex);
            chip.classList.remove('btn-outline-secondary');
            chip.classList.add('btn-primary');
          }
          selectedExamsInput.value = Array.from(selectedSet).join(',');
        });
      });
    }

    // Setup Star Rating Interactivity in Student Modal
    modal.element.querySelectorAll('.modal-star-rating').forEach(wrap => {
      const stars = wrap.querySelectorAll('.star-rating-item');
      const hiddenInp = wrap.nextElementSibling;
      stars.forEach(star => {
        star.addEventListener('click', () => {
          const val = parseInt(star.dataset.val, 10);
          if (hiddenInp) hiddenInp.value = val;
          stars.forEach((s, idx) => {
            if (idx < val) {
              s.classList.add('active');
              s.style.color = '#f59e0b';
            } else {
              s.classList.remove('active');
              s.style.color = '#d1d5db';
            }
          });
        });
      });
    });

    // Evaluate conditional display rules in modal
    function evaluateModalLogic() {
      const formEl = modal.element.querySelector('#studentForm');
      if (!formEl) return;
      const formData = new FormData(formEl);
      const data = Object.fromEntries(formData.entries());

      modal.element.querySelectorAll('.custom-dyn-input, .custom-dyn-radio').forEach(el => {
        const name = el.dataset.field || el.name;
        if (name) {
          if (el.type === 'checkbox') data[name] = el.checked;
          else if (el.type === 'radio') {
            if (el.checked) data[name] = el.value;
          } else if (el.value) data[name] = el.value;
        }
      });

      modal.element.querySelectorAll('.dynamic-field-wrapper').forEach(wrapper => {
        const dependsOn = wrapper.dataset.dependsOn;
        const showWhen = wrapper.dataset.showWhen;
        const operator = wrapper.dataset.operator || 'equals';

        if (dependsOn && showWhen) {
          const rawVal = data[dependsOn];
          const val = rawVal !== undefined ? String(rawVal).trim() : '';
          const target = String(showWhen).trim();

          let isMatch = false;
          const boolVal = rawVal === true || rawVal === 'true' || rawVal === 'on';
          if (operator === 'equals') {
            isMatch = val.toLowerCase() === target.toLowerCase() || (boolVal && target.toLowerCase() === 'true');
          } else if (operator === 'not_equals') {
            isMatch = val.toLowerCase() !== target.toLowerCase();
          } else if (operator === 'contains') {
            isMatch = val.toLowerCase().includes(target.toLowerCase());
          } else if (operator === 'is_checked') {
            isMatch = boolVal;
          } else if (operator === 'is_not_checked') {
            isMatch = !boolVal;
          } else if (operator === 'is_not_empty' || operator === 'not_empty') {
            isMatch = val.length > 0;
          } else if (operator === 'is_empty') {
            isMatch = val.length === 0;
          }

          if (isMatch) {
            wrapper.style.display = '';
            wrapper.querySelectorAll('input, select, textarea').forEach(inp => {
              if (inp.dataset.originallyRequired === 'true') inp.required = true;
            });
          } else {
            wrapper.style.display = 'none';
            wrapper.querySelectorAll('input, select, textarea').forEach(inp => {
              if (inp.required) inp.dataset.originallyRequired = 'true';
              inp.required = false;
            });
          }
        }
      });
    }

    modal.element.addEventListener('input', evaluateModalLogic);
    modal.element.addEventListener('change', evaluateModalLogic);
    evaluateModalLogic();

    // Setup Pincode Auto-Fill in Admin Student Modal using SmartIntelligence
    const pincodeInput = modal.element.querySelector('input[name="pincode"]');
    const cityInput = modal.element.querySelector('input[name="city"]');
    const stateInput = modal.element.querySelector('input[name="state"]');

    if (pincodeInput) {
      const handleAdminPincode = async () => {
        const pin = pincodeInput.value.trim();
        if (pin.length === 6 && /^\d+$/.test(pin)) {
          if (cityInput && !cityInput.value) cityInput.placeholder = '⚡ Auto-filling...';
          if (stateInput && !stateInput.value) stateInput.placeholder = '⚡ Auto-filling...';

          try {
            const res = await SmartIntelligence.lookupPincode(pin);
            if (res.success) {
              if (cityInput && res.city) cityInput.value = res.city;
              if (stateInput && res.state) stateInput.value = res.state;
            }
          } catch (err) {
          } finally {
            if (cityInput) cityInput.placeholder = 'City';
            if (stateInput) stateInput.placeholder = 'State';
          }
        }
      };

      ['input', 'blur', 'change', 'paste', 'keyup'].forEach(evt => {
        pincodeInput.addEventListener(evt, handleAdminPincode);
      });
      if (pincodeInput.value.trim().length === 6) handleAdminPincode();
    }

    // Real-Time Duplicate Student (Phone & Email) Validator in Admin Modal
    const phoneInput = modal.element.querySelector('input[name="phone"]');
    const emailInput = modal.element.querySelector('input[name="email"]');
    const formElement = modal.element.querySelector('#studentForm');

    let dupAlert = modal.element.querySelector('#admin-student-dup-alert');
    if (!dupAlert && formElement) {
      dupAlert = document.createElement('div');
      dupAlert.id = 'admin-student-dup-alert';
      dupAlert.className = 'alert alert-warning mb-3';
      dupAlert.style.display = 'none';
      dupAlert.style.fontSize = '0.85rem';
      dupAlert.style.fontWeight = '600';
      formElement.insertBefore(dupAlert, formElement.firstChild);
    }

    const checkDuplicateAdmin = () => {
      const phoneVal = phoneInput?.value?.trim() || '';
      const emailVal = emailInput?.value?.trim() || '';

      const otherStudents = (state.students || []).filter(s => !isEdit || (student && s._id !== student._id));
      const dupResult = SmartIntelligence.checkDuplicateStudent(phoneVal, emailVal, otherStudents);

      if (dupResult.isDuplicate && dupAlert) {
        dupAlert.textContent = dupResult.message;
        dupAlert.style.display = 'block';
      } else if (dupAlert) {
        dupAlert.style.display = 'none';
      }
    };

    if (phoneInput) {
      ['input', 'blur', 'change', 'keyup'].forEach(evt => phoneInput.addEventListener(evt, checkDuplicateAdmin));
    }
    if (emailInput) {
      ['input', 'blur', 'change', 'keyup'].forEach(evt => emailInput.addEventListener(evt, checkDuplicateAdmin));
    }

    // Smart Seat Suggestion Match Action
    const suggestBtn = modal.element.querySelector('#btn-auto-suggest-seat');
    const seatSelect = modal.element.querySelector('select[name="seat"]');
    if (suggestBtn && seatSelect) {
      suggestBtn.addEventListener('click', () => {
        const shiftVal = modal.element.querySelector('select[name="shift"]')?.value || null;
        const zoneVal = modal.element.querySelector('select[name="zone"]')?.value || null;
        const suggested = SmartIntelligence.suggestSeat(shiftVal, zoneVal, rawAvailableSeats || []);
        if (suggested && suggested.seatId) {
          seatSelect.value = suggested.seatId;
          Toast.show(`⚡ Recommended Seat ${suggested.seatNumber} (${suggested.matchReason})`, 'info');
        } else {
          Toast.show('No matching vacant seats available', 'warning');
        }
      });
    }
  }

  function initSignatureCanvas(canvas, existingDataUrl) {
    const ctx = canvas.getContext('2d');
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    if (existingDataUrl) {
      const img = new Image();
      img.onload = () => ctx.drawImage(img, 0, 0);
      img.src = existingDataUrl;
    }

    let isDrawing = false;
    let lastX = 0, lastY = 0;

    function getPos(e) {
      const rect = canvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      const scaleX = canvas.width / rect.width;
      const scaleY = canvas.height / rect.height;
      return {
        x: (clientX - rect.left) * scaleX,
        y: (clientY - rect.top) * scaleY
      };
    }

    function startDraw(e) {
      e.preventDefault();
      isDrawing = true;
      const pos = getPos(e);
      lastX = pos.x;
      lastY = pos.y;
    }

    function draw(e) {
      if (!isDrawing) return;
      e.preventDefault();
      const pos = getPos(e);
      ctx.beginPath();
      ctx.moveTo(lastX, lastY);
      ctx.lineTo(pos.x, pos.y);
      ctx.stroke();
      lastX = pos.x;
      lastY = pos.y;
    }

    function stopDraw() {
      isDrawing = false;
    }

    canvas.addEventListener('mousedown', startDraw);
    canvas.addEventListener('mousemove', draw);
    canvas.addEventListener('mouseup', stopDraw);
    canvas.addEventListener('mouseleave', stopDraw);

    canvas.addEventListener('touchstart', startDraw, { passive: false });
    canvas.addEventListener('touchmove', draw, { passive: false });
    canvas.addEventListener('touchend', stopDraw);
  }

  function isCanvasBlank(canvas) {
    const ctx = canvas.getContext('2d');
    const pixelBuffer = new Uint32Array(
      ctx.getImageData(0, 0, canvas.width, canvas.height).data.buffer
    );
    return !pixelBuffer.some(color => color !== 0);
  }

  async function handleDelete(id) {
    Confirm.show({
      title: 'Delete Student Record',
      message: 'Are you sure you want to permanently delete this student record? This action will remove the student, release their assigned seat & locker, and remove them completely from the directory.',
      danger: true,
      onConfirm: async () => {
        try {
          const res = await api.delete(`/api/students/${id}`);
          if (res.success) {
            Toast.success(res.message);
            await IDBStorage.clear('students');
            loadStats();
            loadStudents(state.pagination.page);
          } else {
            Toast.error(res.message);
          }
        } catch (err) {
          Toast.error(err.message || 'Error deleting student');
        }
      }
    });
  }

  // Event Listeners
  container.addEventListener('click', (e) => {
    const addBtn = e.target.closest('#addStudentBtn');
    if (addBtn) {
      showStudentForm();
      return;
    }

    const statusToggleBtn = e.target.closest('.btn-toggle-student-status');
    if (statusToggleBtn) {
      const id = statusToggleBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) {
        const oldStatus = student.status || 'active';
        const newStatus = oldStatus === 'active' ? 'inactive' : 'active';
        OptimisticUI.execute({
          applyState: () => {
            student.status = newStatus;
            renderTable();
          },
          rollbackState: () => {
            student.status = oldStatus;
            renderTable();
          },
          apiCall: () => api.put(`/api/students/${id}`, { status: newStatus }),
          onSuccess: async (res) => {
            Toast.success(res.message || `Status updated to ${newStatus}`);
            await IDBStorage.clear('students');
            loadStats();
          }
        });
      }
      return;
    }
    
    const copyBtn = e.target.closest('.btn-copy-text');
    if (copyBtn) {
      e.stopPropagation();
      const textToCopy = copyBtn.getAttribute('data-copy');
      if (textToCopy) copyToClipboard(textToCopy, copyBtn);
      return;
    }

    const viewBtn = e.target.closest('.btn-view');
    if (viewBtn) {
      const id = viewBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showStudentProfile(student);
      return;
    }

    const remindBtn = e.target.closest('.btn-wa-remind');
    if (remindBtn) {
      const id = remindBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) sendWhatsAppReminder(student);
      return;
    }

    const editBtn = e.target.closest('.btn-edit');
    if (editBtn) {
      const id = editBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showStudentForm(student);
      return;
    }

    const idCardBtn = e.target.closest('.btn-idcard');
    if (idCardBtn) {
      const id = idCardBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showStudentIdCard(student);
      return;
    }

    const pdfBtn = e.target.closest('.btn-pdfform');
    if (pdfBtn) {
      const id = pdfBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) previewAdmissionFormPDF(student);
      return;
    }
    
    const pwdBtn = e.target.closest('.btn-pwdreset');
    if (pwdBtn) {
      const id = pwdBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showPasswordResetModal(student);
      return;
    }

    const deleteBtn = e.target.closest('.btn-delete');
    if (deleteBtn) {
      const id = deleteBtn.getAttribute('data-id');
      handleDelete(id);
      return;
    }

    const rowEl = e.target.closest('tr.student-row');
    if (rowEl && !e.target.closest('button, input, select, .badge, .btn, label, a')) {
      const id = rowEl.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showStudentProfile(student);
      return;
    }
  });

  function showStudentProfile(student) {
    const planName = student.plan?.name || 'Standard Plan';
    const seatNumber = student.seat?.seatNumber || 'Floating / Not Assigned';
    const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : '-';
    const expiryDate = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : '-';
    const daysLeft = student.expiryDate ? Math.ceil((new Date(student.expiryDate) - new Date()) / (1000 * 60 * 60 * 24)) : null;

    let phone = (student.phone || '').replace(/[^0-9]/g, '');
    if (phone.length === 10) phone = '91' + phone;
    const waUrl = phone ? `https://api.whatsapp.com/send?phone=${phone}` : null;

    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <div style="font-family: 'Outfit', sans-serif;">
        <!-- Student Header Card -->
        <div style="display: flex; align-items: center; gap: 16px; padding: 16px; background: var(--color-surface-hover); border-radius: 12px; margin-bottom: 20px; border: 1px solid var(--color-border);">
          <div style="width: 64px; height: 64px; border-radius: 50%; background: linear-gradient(135deg, #6366f1, #8b5cf6); display: flex; align-items: center; justify-content: center; font-size: 24px; color: #fff; font-weight: 700; overflow: hidden;">
            ${student.photo ? `<img src="${student.photo}" style="width: 100%; height: 100%; object-fit: cover;">` : (student.name || 'S').charAt(0)}
          </div>
          <div style="flex: 1;">
            <div class="d-flex align-items-center gap-2">
              <h3 style="margin: 0; font-size: 1.25rem; font-weight: 700;">${escapeHTML(student.name)}</h3>
              <span class="badge ${student.status === 'active' ? 'badge-success' : 'badge-danger'}" style="text-transform: uppercase;">${escapeHTML(student.status)}</span>
            </div>
            <div class="text-muted small mt-1">
              Student ID: <strong style="color: var(--color-primary); font-family: monospace;">${escapeHTML(student.studentId || '-')}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(student.studentId || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Student ID">📋</button> • Phone: <strong>${escapeHTML(SmartFormatters.phone(student.phone) || '-')}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(student.phone || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">📋</button>
            </div>
          </div>
        </div>

        <!-- 360 Degree Info Grid -->
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 16px; margin-bottom: 20px;">
          <!-- Membership Info -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-primary);">💺 Membership & Seat</h5>
            <div class="small text-muted mb-1">Plan: <strong class="text-primary">${escapeHTML(planName)}</strong></div>
            <div class="small text-muted mb-1">Desk / Seat: <strong class="text-success">${escapeHTML(seatNumber)}</strong></div>
            <div class="small text-muted mb-1">Enrolled: <strong>${admissionDate}</strong></div>
            <div class="small text-muted">Valid Until: <strong class="text-danger">${expiryDate}</strong> (${daysLeft !== null ? (daysLeft <= 0 ? 'Expired' : `${daysLeft} days left • ${SmartFormatters.timeAgo(student.expiryDate)}`) : '-'})</div>
          </div>

          <!-- Academic & Exams -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-info);">🎯 Academic & Target Exams</h5>
            <div class="small text-muted mb-1">College/Coaching: <strong>${escapeHTML(student.occupation || 'N/A')}</strong></div>
            <div class="small text-muted mb-2">Blood Group: <strong>${escapeHTML(student.bloodGroup || 'N/A')}</strong></div>
            <div class="d-flex flex-wrap gap-1">
              ${(student.targetExams && student.targetExams.length > 0) ? student.targetExams.map(ex => `<span class="badge badge-primary" style="font-size: 0.7rem;">${escapeHTML(ex)}</span>`).join('') : '<span class="text-muted small">No target exams specified</span>'}
            </div>
          </div>

          <!-- Contact & Address -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-warning);">📍 Address & Emergency</h5>
            <div class="small text-muted mb-1">Email: <strong>${escapeHTML(student.email || 'N/A')}</strong></div>
            <div class="small text-muted mb-1">Address: <strong>${escapeHTML(student.address || 'N/A')}, ${escapeHTML(student.city || '')} ${escapeHTML(student.pincode || '')}</strong></div>
            <div class="small text-muted">Emergency Contact: <strong>${escapeHTML(student.emergencyContact?.name || 'N/A')} (${escapeHTML(student.emergencyContact?.relation || 'Parent')}) - ${escapeHTML(SmartFormatters.phone(student.emergencyContact?.phone) || '')}</strong> ${student.emergencyContact?.phone ? `<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(student.emergencyContact.phone)}" style="padding: 1px 4px; font-size: 0.7rem;">📋</button>` : ''}</div>
          </div>

          <!-- Smart Access & KYC -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-success);">🔐 Access & KYC</h5>
            <div class="small text-muted mb-1">RFID Smart Card: <strong>${escapeHTML(student.rfidCardNumber || 'Not Linked')}</strong></div>
            <div class="small text-muted mb-1">Biometric ID: <strong>${escapeHTML(student.biometricId || 'Not Linked')}</strong></div>
            <div class="small text-muted mb-1">ID Proof: <strong>${escapeHTML(student.idProof?.type || 'Aadhaar')} (${escapeHTML(student.idProof?.type === 'Aadhaar' || !student.idProof?.type ? SmartFormatters.aadhaar(student.idProof?.number) : (student.idProof?.number || 'N/A'))})</strong> ${student.idProof?.number ? `<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(student.idProof.number)}" style="padding: 1px 4px; font-size: 0.7rem;">📋</button>` : ''}</div>
            ${student.signature ? `
              <div class="mt-2">
                <div class="text-xs text-muted">Digital Signature:</div>
                <img src="${student.signature}" style="max-height: 40px; border: 1px solid var(--color-border); border-radius: 4px; background: #fff; padding: 2px;">
              </div>
            ` : ''}
          </div>
        </div>

        <!-- 🧠 Study Consistency & Heatmap Analytics Widget -->
        <div id="student-analytics-widget" style="background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: 12px; padding: 16px; margin-bottom: 20px;">
          <div class="d-flex justify-content-between align-items-center mb-3">
            <div class="d-flex align-items-center gap-2">
              <span style="font-size: 1.3rem;">🧠</span>
              <h5 style="margin: 0; font-size: 0.95rem; font-weight: 700; color: var(--color-text-primary);">
                Study Consistency & Attendance Heatmap
              </h5>
            </div>
            <div id="student-analytics-badges" class="d-flex gap-2 align-items-center"></div>
          </div>
          <div id="student-analytics-content">
            <div class="text-center p-3 text-muted">
              <div class="loading-spinner mb-2" style="margin: 0 auto; width: 22px; height: 22px;"></div>
              <small>Analyzing student attendance discipline & study patterns...</small>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="d-flex justify-content-end gap-2 pt-3 border-top flex-wrap">
          <button type="button" class="btn btn-outline-success btn-sm btn-profile-remind" style="font-weight: 700;">
            📲 WhatsApp Reminder
          </button>
          ${waUrl ? `
            <a href="${waUrl}" target="_blank" class="btn btn-outline-success btn-sm" style="font-weight: 600;">
              💬 Chat
            </a>
          ` : ''}
          <button type="button" class="btn btn-outline-info btn-sm btn-profile-idcard">
            🪪 Print ID Card
          </button>
          <button type="button" class="btn btn-outline-success btn-sm btn-profile-pdfform">
            📄 Download PDF Form
          </button>
          <button type="button" class="btn btn-primary btn-sm btn-profile-edit">
            ✏️ Edit Student
          </button>
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">
            Close
          </button>
        </div>
      </div>
    `;

    const pModal = new Modal({
      title: `👤 Student Profile: ${student.name}`,
      content: modalContent,
      size: 'lg'
    });
    pModal.show();

    loadStudentAnalyticsWidget(student._id, modalContent);

    modalContent.querySelectorAll('.btn-copy-text').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.stopPropagation();
        const textToCopy = btn.getAttribute('data-copy');
        if (textToCopy) copyToClipboard(textToCopy, btn);
      });
    });

    modalContent.querySelector('.btn-profile-remind')?.addEventListener('click', () => {
      sendWhatsAppReminder(student, student.balanceDue > 0 ? 'balance_due' : 'renewal_reminder');
    });

    modalContent.querySelector('.btn-profile-idcard')?.addEventListener('click', () => {
      pModal.close();
      showStudentIdCard(student);
    });

    modalContent.querySelector('.btn-profile-pdfform')?.addEventListener('click', () => {
      previewAdmissionFormPDF(student);
    });

    modalContent.querySelector('.btn-profile-edit')?.addEventListener('click', () => {
      pModal.close();
      showStudentForm(student);
    });
  }

  /**
   * Smart WhatsApp Blast Modal
   * Supports: selected students | all active | by shift | by plan
   * Uses wa.me/ links (free, no API cost)
   */
  async function openWABlastModal(preSelectedStudents = [], reloadFn) {
    let allStudents = preSelectedStudents;
    let shifts = [];
    let plans = [];

    // Fetch shifts and plans for filter options
    try {
      const [shiftRes, planRes] = await Promise.all([
        api.get('/api/shifts?limit=50'),
        api.get('/api/plans?limit=50')
      ]);
      shifts = shiftRes?.data?.shifts || shiftRes?.data || [];
      plans = planRes?.data?.plans || planRes?.data || [];
    } catch (e) {}

    const shiftOptions = shifts.map(s => `<option value="${escapeHTML(s._id)}">${escapeHTML(s.name)}</option>`).join('');
    const planOptions = plans.map(p => `<option value="${escapeHTML(p._id)}">${escapeHTML(p.name)}</option>`).join('');

    const msgTemplate = `Hi {name}! 👋\nYour library membership expires on *{expiry}*.\nPlease renew to continue your studies. 📚\nRenew now: {link}\n\n— {library}`;

    const content = `
      <div id="wa-blast-modal" style="font-family:'Outfit',sans-serif;">
        <div class="mb-3">
          <label class="form-label fw-700">📋 Recipient Filter</label>
          <div class="d-flex flex-wrap gap-2 mb-2">
            <button type="button" class="btn btn-sm btn-primary wa-filter-btn active" data-filter="selected">
              ✅ Selected (${preSelectedStudents.length})
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary wa-filter-btn" data-filter="all_active">
              🟢 All Active Students
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary wa-filter-btn" data-filter="by_shift">
              🕒 By Shift
            </button>
            <button type="button" class="btn btn-sm btn-outline-secondary wa-filter-btn" data-filter="by_plan">
              🏷️ By Plan
            </button>
          </div>
          <div id="wa-filter-sub" style="display:none;margin-top:8px;">
            <div id="wa-shift-select" style="display:none;">
              <select id="wa-shift-id" class="form-select form-control form-control-sm">
                <option value="">— Select Shift —</option>
                ${shiftOptions}
              </select>
            </div>
            <div id="wa-plan-select" style="display:none;">
              <select id="wa-plan-id" class="form-select form-control form-control-sm">
                <option value="">— Select Plan —</option>
                ${planOptions}
              </select>
            </div>
          </div>
        </div>

        <div class="mb-3">
          <label class="form-label fw-700">💬 Message Template</label>
          <div class="mb-1 text-xs text-muted">Variables: <code>{name}</code> <code>{expiry}</code> <code>{plan}</code> <code>{seat}</code> <code>{link}</code> <code>{library}</code></div>
          <textarea id="wa-blast-message" class="form-control" rows="5" style="font-size:0.85rem;font-family:monospace;">${msgTemplate}</textarea>
        </div>

        <div id="wa-recipient-count" class="mb-3 text-sm" style="color:var(--color-text-secondary);">
          Recipients loaded: <strong id="wa-count-num">${preSelectedStudents.length}</strong>
        </div>

        <div class="mb-2 text-xs text-muted" style="background:rgba(108,92,231,0.08);border-radius:8px;padding:8px 12px;border:1px solid rgba(108,92,231,0.2);">
          ℹ️ This opens WhatsApp <code>wa.me/</code> links one by one (free, no API cost). Your browser may block popups — please allow for this site.
        </div>
      </div>`;

    const modal = Modal.show({
      title: '📲 WhatsApp Blast Sender',
      content,
      size: 'md',
      actions: `
        <button id="wa-blast-load-btn" type="button" class="btn btn-outline-secondary btn-sm">🔄 Load Recipients</button>
        <button id="wa-blast-send-btn" type="button" class="btn btn-success">📲 Open WA Links (${preSelectedStudents.length})</button>
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
      `
    });
    if (!modal) return;

    let currentFilter = 'selected';
    let recipientList = [...preSelectedStudents];

    const countEl = modal.querySelector('#wa-count-num');
    const sendBtn = modal.querySelector('#wa-blast-send-btn');

    function updateCount() {
      if (countEl) countEl.textContent = recipientList.length;
      if (sendBtn) sendBtn.textContent = `📲 Open WA Links (${recipientList.length})`;
    }

    // Filter button switching
    modal.querySelectorAll('.wa-filter-btn').forEach(btn => {
      btn.onclick = () => {
        modal.querySelectorAll('.wa-filter-btn').forEach(b => b.classList.replace('btn-primary', 'btn-outline-secondary'));
        btn.classList.replace('btn-outline-secondary', 'btn-primary');
        currentFilter = btn.dataset.filter;
        const subEl = modal.querySelector('#wa-filter-sub');
        const shiftSel = modal.querySelector('#wa-shift-select');
        const planSel = modal.querySelector('#wa-plan-select');
        if (currentFilter === 'by_shift') {
          if (subEl) subEl.style.display = 'block';
          if (shiftSel) shiftSel.style.display = 'block';
          if (planSel) planSel.style.display = 'none';
        } else if (currentFilter === 'by_plan') {
          if (subEl) subEl.style.display = 'block';
          if (shiftSel) shiftSel.style.display = 'none';
          if (planSel) planSel.style.display = 'block';
        } else {
          if (subEl) subEl.style.display = 'none';
        }
        if (currentFilter === 'selected') {
          recipientList = [...preSelectedStudents];
          updateCount();
        }
      };
    });

    // Load recipients button
    modal.querySelector('#wa-blast-load-btn')?.addEventListener('click', async () => {
      try {
        let params = { status: 'active', limit: 500 };
        if (currentFilter === 'by_shift') {
          const shiftId = modal.querySelector('#wa-shift-id')?.value;
          if (!shiftId) { Toast.error('Please select a shift'); return; }
          params.shift = shiftId;
        } else if (currentFilter === 'by_plan') {
          const planId = modal.querySelector('#wa-plan-id')?.value;
          if (!planId) { Toast.error('Please select a plan'); return; }
          params.plan = planId;
        } else if (currentFilter === 'selected') {
          recipientList = [...preSelectedStudents];
          updateCount();
          return;
        }
        const res = await api.get('/api/students', params);
        recipientList = res?.data?.students || res?.data || [];
        updateCount();
        Toast.success(`${recipientList.length} recipients loaded`);
      } catch (e) {
        Toast.error('Failed to load recipients');
      }
    });

    // Send WA links
    modal.querySelector('#wa-blast-send-btn')?.addEventListener('click', async () => {
      if (recipientList.length === 0) { Toast.error('No recipients'); return; }

      const msgTpl = modal.querySelector('#wa-blast-message')?.value || msgTemplate;
      let bizName = 'Study Library';
      try {
        const bRes = await api.get('/api/settings');
        bizName = bRes?.data?.businessProfile?.businessName || bizName;
      } catch (e) {}

      Modal.closeAll();

      let sent = 0;
      for (const student of recipientList) {
        const phone = (student.phone || '').replace(/[^0-9]/g, '');
        if (!phone || phone.length < 10) continue;
        const intlPhone = phone.length === 10 ? '91' + phone : phone;

        const expiry = student.expiryDate
          ? new Date(student.expiryDate).toLocaleDateString('en-IN')
          : 'N/A';
        const renewLink = `https://wa.me/${intlPhone}`;

        const msg = msgTpl
          .replace(/{name}/g, student.name || 'Student')
          .replace(/{expiry}/g, expiry)
          .replace(/{plan}/g, student.plan?.name || 'your plan')
          .replace(/{seat}/g, student.seat?.seatNumber || 'N/A')
          .replace(/{link}/g, renewLink)
          .replace(/{library}/g, bizName);

        const waUrl = `https://wa.me/${intlPhone}?text=${encodeURIComponent(msg)}`;
        window.open(waUrl, '_blank');
        sent++;

        // Delay between opens to avoid browser blocking
        if (sent < recipientList.length) {
          await new Promise(r => setTimeout(r, 700));
        }
      }
      Toast.success(`📲 Opened ${sent} WhatsApp link(s). Check your browser tabs!`);
    });
  }

  async function sendWhatsAppReminder(student, reminderType = 'renewal_reminder') {
    try {
      Loading.show('Preparing WhatsApp reminder & UPI payment link...');
      const res = await api.post('/api/messages/send-reminder', {
        studentId: student._id,
        reminderType
      });
      Loading.hide();
      if (res.success && res.data) {
        if (res.data.whatsappUrl) {
          window.open(res.data.whatsappUrl, '_blank');
        }
        Toast.success(`WhatsApp reminder generated & opened for ${res.data.studentName}!`);
      } else {
        Toast.error(res.message || 'Failed to dispatch reminder');
      }
    } catch (err) {
      Loading.hide();
      Toast.error(err.message || 'Failed to trigger reminder');
    }
  }

  async function loadStudentAnalyticsWidget(studentId, container) {
    const contentEl = container.querySelector('#student-analytics-content');
    const badgesEl = container.querySelector('#student-analytics-badges');
    if (!contentEl) return;

    try {
      const res = await api.get(`/api/attendance/analytics/${studentId}`);
      if (!res.success || !res.data) throw new Error(res.message || 'No data');
      const a = res.data;

      if (badgesEl) {
        // Calculate behavior score from analytics data
        const attPct = a.consistencyScore || 0;
        const streakD = a.currentStreak || 0;
        const behaviorBadgeHtml = renderBehaviorBadge(attPct, 100, streakD);
        badgesEl.innerHTML = `
          ${behaviorBadgeHtml}
          <span class="badge" style="background: rgba(16, 185, 129, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.75rem;">
            ${escapeHTML(a.peakStudyHours?.badge || '🌅 Peak Time')}
          </span>
          <span class="badge" style="background: rgba(245, 158, 11, 0.15); color: var(--color-warning); font-weight: 700; font-size: 0.75rem;">
            🔥 ${a.currentStreak || 0}d Streak
          </span>
        `;
      }

      const safeScore = Math.max(0, Math.min(100, Math.round(a.consistencyScore || 0)));

      contentEl.innerHTML = `
        <div style="display: grid; grid-template-columns: minmax(130px, auto) 1fr; gap: 16px; align-items: center;">
          <!-- Consistency Gauge & Metrics -->
          <div style="display: flex; flex-direction: column; align-items: center; text-align: center; padding: 10px; background: var(--color-surface); border-radius: 8px; border: 1px solid var(--color-border);">
            <div style="position: relative; width: 84px; height: 84px; display: flex; align-items: center; justify-content: center;">
              <svg viewBox="0 0 36 36" style="width: 84px; height: 84px; transform: rotate(-90deg);">
                <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                      fill="none" stroke="rgba(148, 163, 184, 0.2)" stroke-width="3.2" />
                <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
                      fill="none" stroke="url(#adminScoreGaugeGrad)" stroke-width="3.2"
                      stroke-dasharray="${safeScore}, 100" stroke-linecap="round" />
                <defs>
                  <linearGradient id="adminScoreGaugeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" stop-color="#10b981"/>
                    <stop offset="100%" stop-color="#6366f1"/>
                  </linearGradient>
                </defs>
              </svg>
              <div style="position: absolute; text-align: center;">
                <div style="font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary); line-height: 1;">${safeScore}%</div>
                <div style="font-size: 0.55rem; color: var(--color-text-secondary); text-transform: uppercase; font-weight: 700; margin-top: 2px;">Consistency</div>
              </div>
            </div>
            <div class="small mt-1" style="font-size: 0.75rem; color: var(--color-text-secondary);">
              Avg: <strong>${escapeHTML(a.averageDailyDuration?.formatted || '0m')}</strong>/day
            </div>
            <div class="text-muted" style="font-size: 0.7rem;">
              ${a.totalDaysPresent || 0}/30d present (Best: ${a.longestStreak || 0}d)
            </div>
          </div>

          <!-- 30-Day Heatmap Grid -->
          <div>
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; font-size: 0.8rem;">
              <strong style="color: var(--color-text-primary);">30-Day Attendance Grid</strong>
              <span class="text-muted" style="font-size: 0.72rem;">${a.peakStudyHours?.slot || 'Peak Hours'}</span>
            </div>

            ${renderHeatmapGridHtml(a.heatmap || [])}

            <div style="margin-top: 10px; padding: 8px 12px; background: var(--color-surface); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.8rem; line-height: 1.4; color: var(--color-text-secondary);">
              <strong>🤖 AI Insight:</strong> ${escapeHTML(a.aiRecommendation || a.aiStudyTip || 'Regular attendance observed.')}
            </div>
          </div>
        </div>
      `;
    } catch (err) {
      contentEl.innerHTML = `<div class="text-muted small text-center p-2">Unable to load attendance analytics (${escapeHTML(err.message || 'No records')})</div>`;
    }

    // ── Full-year Heatmap (Phase 2) ──────────────────────────────────────────
    // Add a full GitHub-style year heatmap below the existing 30-day grid
    let yearHeatmapEl = container.querySelector('#student-year-heatmap');
    if (!yearHeatmapEl) {
      yearHeatmapEl = document.createElement('div');
      yearHeatmapEl.id = 'student-year-heatmap';
      yearHeatmapEl.style.cssText = 'margin-top:14px;padding-top:14px;border-top:1px solid var(--color-border,rgba(255,255,255,0.08));';
      const analyticsWidget = container.querySelector('#student-analytics-widget');
      if (analyticsWidget) analyticsWidget.appendChild(yearHeatmapEl);
    }
    try {
      await renderHeatmap(yearHeatmapEl, studentId, new Date().getFullYear(), { compact: false });
    } catch (e) {
      yearHeatmapEl.innerHTML = '<div class="text-muted small text-center">Heatmap unavailable</div>';
    }
  }

  async function showStudentIdCard(student) {
    let business = { businessName: 'Study Library', tagline: 'Self Study & Reading Room', phone: '', address: '', logo: '' };
    try {
      const bRes = await api.get('/api/settings');
      if (bRes.success && bRes.data?.businessProfile) business = { ...business, ...bRes.data.businessProfile };
    } catch (e) {}

    const planName = student.plan?.name || 'Standard Access';
    const seatNumber = student.seat?.seatNumber || 'Floating';
    const shiftName = student.shift?.name || '';
    const expiryDate = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : '-';
    const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : '-';
    const phone = student.phone || '-';
    const initials = (student.name||'S').split(' ').map(n=>n[0]).join('').toUpperCase().slice(0,2);

    // QR Code — encodes student ID + name + phone
    const qrPayload = encodeURIComponent(JSON.stringify({ id: student.studentId, name: student.name, phone: student.phone, seat: seatNumber }));
    const qrCodeURL = `https://api.qrserver.com/v1/create-qr-code/?size=120x120&data=${qrPayload}&margin=4&bgcolor=ffffff`;

    const cardContent = document.createElement('div');
    cardContent.innerHTML = `
      <div class="id-card-studio" style="font-family:'Outfit',sans-serif;">

        <!-- Live Card Preview -->
        <div style="display:flex;justify-content:center;margin-bottom:18px;" id="id-card-preview-wrap">
          <div id="printable-id-card" style="
            width:340px;min-height:210px;background:linear-gradient(145deg,#ffffff 60%,#f0eeff 100%);
            color:#1a1a2e;border-radius:14px;border:2.5px solid #6c5ce7;overflow:hidden;
            box-shadow:0 12px 32px rgba(108,92,231,0.22);font-family:'Outfit',sans-serif;
            position:relative;user-select:none;
          ">
            <!-- Header Bar -->
            <div style="background:linear-gradient(135deg,#6c5ce7,#a29bfe);color:#fff;padding:12px 16px;display:flex;align-items:center;gap:10px;">
              ${business.logo ? `<img src="${business.logo}" style="height:34px;width:34px;border-radius:6px;object-fit:cover;background:#fff;flex-shrink:0;">` : `<div style="width:34px;height:34px;border-radius:6px;background:rgba(255,255,255,0.2);display:flex;align-items:center;justify-content:center;font-size:1.1rem;flex-shrink:0;">📚</div>`}
              <div style="flex:1;min-width:0;">
                <div style="font-weight:800;font-size:0.95rem;letter-spacing:0.3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHTML(business.businessName)}</div>
                <div style="font-size:0.68rem;opacity:0.88;margin-top:1px;">${escapeHTML(business.tagline || 'Student Membership Card')}</div>
              </div>
              <div style="font-size:0.62rem;opacity:0.8;text-align:right;flex-shrink:0;">STUDENT ID</div>
            </div>

            <!-- Card Body -->
            <div style="padding:12px 14px;display:flex;gap:12px;align-items:flex-start;">
              <!-- Photo -->
              <div style="flex-shrink:0;display:flex;flex-direction:column;align-items:center;gap:6px;">
                <div style="width:68px;height:68px;border-radius:8px;background:#eef2ff;color:#6c5ce7;display:flex;align-items:center;justify-content:center;font-size:1.5rem;font-weight:800;border:2px solid #6c5ce7;overflow:hidden;" id="id-card-photo">
                  ${student.photo ? `<img src="${student.photo}" style="width:100%;height:100%;object-fit:cover;">` : initials}
                </div>
                <img src="${qrCodeURL}" alt="QR" style="width:60px;height:60px;border-radius:4px;border:1px solid #e2e8f0;">
              </div>

              <!-- Fields -->
              <div style="flex:1;min-width:0;">
                <!-- Name -->
                <div style="font-weight:800;font-size:1.05rem;color:#2d3436;margin-bottom:4px;line-height:1.2;">${escapeHTML(student.name)}</div>
                <!-- Roll No / Student ID -->
                <div style="background:#eef2ff;color:#4338ca;padding:2px 8px;border-radius:4px;display:inline-block;font-weight:700;font-size:0.72rem;font-family:monospace;margin-bottom:8px;">${escapeHTML(student.studentId || 'STU-MEMBER')}</div>

                <!-- Info Grid -->
                <div style="font-size:0.75rem;color:#4a5568;display:grid;grid-template-columns:auto 1fr;row-gap:2px;column-gap:6px;">
                  <span style="font-weight:700;color:#718096;">Seat</span><span style="font-weight:700;color:#6c5ce7;">${escapeHTML(seatNumber)}</span>
                  <span style="font-weight:700;color:#718096;">Plan</span><span>${escapeHTML(planName)}</span>
                  <span style="font-weight:700;color:#718096;">Phone</span><span>${escapeHTML(phone)}</span>
                  <span style="font-weight:700;color:#718096;">Valid Till</span><span style="font-weight:700;color:#e53e3e;">${escapeHTML(expiryDate)}</span>
                  ${shiftName ? `<span style="font-weight:700;color:#718096;">Shift</span><span>${escapeHTML(shiftName)}</span>` : ''}
                </div>
              </div>
            </div>

            <!-- Footer -->
            <div style="background:#f7fafc;border-top:1px dashed #e2e8f0;padding:5px 14px;display:flex;justify-content:space-between;align-items:center;font-size:0.62rem;color:#718096;">
              <span>Issued: ${escapeHTML(admissionDate)}</span>
              <span style="font-weight:700;letter-spacing:0.5px;">NON-TRANSFERABLE</span>
              <span>${escapeHTML(business.phone || '')}</span>
            </div>
          </div>
        </div>

        <!-- Card Style Controls -->
        <div style="background:var(--color-bg-secondary,rgba(0,0,0,0.04));border-radius:10px;padding:12px 14px;margin-bottom:14px;border:1px solid var(--color-border);">
          <div style="font-weight:700;font-size:0.82rem;margin-bottom:10px;color:var(--color-text-primary);">🎨 Card Theme & Style</div>
          <div style="display:flex;flex-wrap:wrap;gap:10px;align-items:center;">
            <div>
              <label style="font-size:0.75rem;font-weight:600;display:block;margin-bottom:3px;">Primary Color</label>
              <input type="color" id="id-card-color" value="#6c5ce7" style="width:40px;height:32px;border:none;padding:0;cursor:pointer;border-radius:6px;">
            </div>
            <div>
              <label style="font-size:0.75rem;font-weight:600;display:block;margin-bottom:3px;">Card Style</label>
              <select id="id-card-style" class="form-select form-control-sm" style="font-size:0.78rem;min-width:120px;">
                <option value="gradient">Gradient Purple</option>
                <option value="dark">Dark Pro</option>
                <option value="minimal">Minimal White</option>
                <option value="colorful">Colorful Bright</option>
              </select>
            </div>
            <div style="margin-left:auto;display:flex;gap:8px;">
              <button class="btn btn-sm btn-outline-secondary" id="btn-id-flip" title="Show Back Side">🔄 Flip</button>
            </div>
          </div>
        </div>

        <!-- Action Controls -->
        <div class="d-flex justify-content-center gap-2 flex-wrap">
          <button class="btn btn-primary" id="btn-download-id-png">
            📥 Download PNG
          </button>
          <button class="btn btn-outline-secondary" id="btn-print-id-card">
            🖨️ Print
          </button>
          <button class="btn btn-secondary" onclick="Modal.closeAll()">Close</button>
        </div>

        <style>
          @media print {
            body * { visibility: hidden; }
            #printable-id-card, #printable-id-card * { visibility: visible; }
            #printable-id-card { position: absolute; left: 50%; top: 20px; transform: translateX(-50%); box-shadow: none !important; }
          }
        </style>
      </div>`;

    const idModal = new Modal({ title: `🪪 Student ID Card: ${escapeHTML(student.name)}`, content: cardContent, size: 'md' });
    idModal.show();

    // Print button
    cardContent.querySelector('#btn-print-id-card')?.addEventListener('click', () => window.print());

    // Download PNG via html2canvas CDN (lazy-loaded)
    cardContent.querySelector('#btn-download-id-png')?.addEventListener('click', async (e) => {
      const btn = e.currentTarget;
      btn.textContent = '⏳ Generating...';
      btn.disabled = true;
      try {
        // Dynamically load html2canvas
        if (!window.html2canvas) {
          await new Promise((res, rej) => {
            const s = document.createElement('script');
            s.src = 'https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js';
            s.onload = res; s.onerror = rej;
            document.head.appendChild(s);
          });
        }
        const cardEl = cardContent.querySelector('#printable-id-card');
        const canvas = await window.html2canvas(cardEl, { scale: 3, useCORS: true, backgroundColor: null });
        const link = document.createElement('a');
        link.download = `ID_${(student.studentId||student.name||'student').replace(/\s+/g,'_')}.png`;
        link.href = canvas.toDataURL('image/png');
        link.click();
        Toast.success('ID Card downloaded as PNG!');
      } catch (err) {
        Toast.error('PNG download requires internet (html2canvas CDN). Try Print instead.');
      } finally {
        btn.textContent = '📥 Download PNG';
        btn.disabled = false;
      }
    });

    // Theme color picker
    cardContent.querySelector('#id-card-color')?.addEventListener('input', (e) => {
      const color = e.target.value;
      const card = cardContent.querySelector('#printable-id-card');
      if (!card) return;
      card.style.borderColor = color;
      const header = card.querySelector('div[style*="linear-gradient"]');
      if (header) header.style.background = `linear-gradient(135deg, ${color}, ${color}bb)`;
      const rollBadge = card.querySelector('div[style*="eef2ff"]');
      if (rollBadge) { rollBadge.style.background = color + '22'; rollBadge.style.color = color; }
      const seatVal = card.querySelector('span[style*="#6c5ce7"]');
      if (seatVal) seatVal.style.color = color;
      card.style.boxShadow = `0 12px 32px ${color}44`;
    });

    // Style presets
    cardContent.querySelector('#id-card-style')?.addEventListener('change', (e) => {
      const card = cardContent.querySelector('#printable-id-card');
      if (!card) return;
      const styles = {
        gradient: 'linear-gradient(145deg,#ffffff 60%,#f0eeff 100%)',
        dark: 'linear-gradient(145deg,#1a1a2e,#16213e)',
        minimal: '#ffffff',
        colorful: 'linear-gradient(145deg,#fff9f0,#f0fff4)'
      };
      card.style.background = styles[e.target.value] || styles.gradient;
      if (e.target.value === 'dark') {
        card.style.color = '#f0f0f0';
      } else {
        card.style.color = '#1a1a2e';
      }
    });

    // Flip to show back side
    let showingBack = false;
    cardContent.querySelector('#btn-id-flip')?.addEventListener('click', () => {
      const card = cardContent.querySelector('#printable-id-card');
      if (!card) return;
      showingBack = !showingBack;
      if (showingBack) {
        card.style.transform = 'rotateY(180deg)';
        card.style.transition = 'transform 0.5s ease';
        setTimeout(() => {
          card.innerHTML = `
            <div style="background:linear-gradient(135deg,#6c5ce7,#a29bfe);color:#fff;padding:12px 16px;text-align:center;">
              <div style="font-weight:800;font-size:1rem;">${escapeHTML(business.businessName)}</div>
              <div style="font-size:0.7rem;opacity:0.85;">Student Terms & Conditions</div>
            </div>
            <div style="padding:14px;font-size:0.75rem;color:#4a5568;line-height:1.7;">
              <ul style="margin:0;padding-left:16px;">
                <li>This card is non-transferable and must be carried daily.</li>
                <li>Lost card must be reported immediately to the admin.</li>
                <li>Membership is valid only till the date shown on front.</li>
                <li>Entry after expiry is not permitted without renewal.</li>
                <li>Damage to library property will attract fines.</li>
              </ul>
            </div>
            <div style="text-align:center;padding:8px;border-top:1px dashed #e2e8f0;font-size:0.65rem;color:#718096;">
              ${escapeHTML(business.phone || '')} • ${escapeHTML(business.address || '')}
            </div>`;
          card.style.transform = 'rotateY(0)';
        }, 250);
      } else {
        // Re-render front side by re-calling
        idModal.close();
        setTimeout(() => showStudentIdCard(student), 100);
      }
    });
  }

  // Password Reset Modal Function
  function showPasswordResetModal(student) {
    const cleanPhone = (student.phone || '').replace(/[^0-9]/g, '').slice(-10);
    const formattedDob = student.dateOfBirth ? new Date(student.dateOfBirth).toISOString().slice(0,10).replace(/-/g, '') : '';
    const initialPin = Math.floor(100000 + Math.random() * 900000).toString();

    const contentHtml = `
      <div style="display: flex; flex-direction: column; gap: 14px; user-select: none;">
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 8px;">
          <div>
            <div style="font-weight: 800; font-size: 1.05rem; color: var(--color-primary);">${escapeHTML(student.name)}</div>
            <div class="text-muted small">ID: ${escapeHTML(student.studentId || '-')} | Phone: ${escapeHTML(student.phone || 'N/A')}</div>
          </div>
          <span class="badge badge-success" style="font-weight: 700;">Student Portal</span>
        </div>

        <div class="form-group" style="margin: 0;">
          <label class="form-label" style="font-weight: 700; font-size: 0.88rem;">New Password / 6-Digit PIN *</label>
          <div style="position: relative;">
            <input type="text" id="reset-pwd-input" class="form-control form-control-lg" value="${initialPin}" style="padding-right: 48px; font-family: monospace; font-size: 1.2rem; font-weight: 800; letter-spacing: 2px;" required>
            <button type="button" id="btn-toggle-reset-eye" class="btn btn-icon btn-ghost" style="position: absolute; right: 8px; top: 8px; color: var(--color-text-muted);" title="Toggle Visibility">👁️</button>
          </div>
        </div>

        <!-- Preset Quick Buttons -->
        <div>
          <label class="form-label text-xs" style="font-weight: 700; text-transform: uppercase; color: var(--color-text-secondary); margin-bottom: 6px; display: block;">⚡ 1-Click Password Presets</label>
          <div style="display: flex; gap: 8px; flex-wrap: wrap;">
            <button type="button" class="btn btn-sm btn-secondary" id="preset-random-pin" style="font-weight: 600;">🎲 Random 6-Digit PIN</button>
            ${cleanPhone ? `<button type="button" class="btn btn-sm btn-secondary" id="preset-phone-pin" style="font-weight: 600;">📱 Phone (${cleanPhone})</button>` : ''}
            ${formattedDob ? `<button type="button" class="btn btn-sm btn-secondary" id="preset-dob-pin" style="font-weight: 600;">🎂 DOB (${formattedDob})</button>` : ''}
          </div>
        </div>

        <!-- Dispatch Options Toggles -->
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 14px; display: flex; flex-direction: column; gap: 10px; margin-bottom: 1rem;">
          <label style="font-weight: 700; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
            <input type="checkbox" id="reset-toggle-wa" class="form-toggle" checked> 📲 Open Pre-filled WhatsApp Credential Link
          </label>
          <label style="font-weight: 700; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
            <input type="checkbox" id="reset-toggle-email" class="form-toggle" ${student.email ? 'checked' : ''}> 📧 Send Credentials Notification via Email
          </label>
        </div>

        <!-- Prominent In-Modal Primary Save Button -->
        <div>
          <button type="button" id="btn-save-reset-password" class="btn btn-primary btn-lg" style="width: 100%; font-weight: 800; font-size: 1rem; padding: 12px; justify-content: center; display: flex; align-items: center; gap: 8px; border-radius: 10px;">
            💾 Save & Update Password
          </button>
        </div>
      </div>
    `;

    const executeSavePassword = async (modalInstance) => {
      const pwdInput = document.getElementById('reset-pwd-input');
      const newPassword = pwdInput?.value?.trim();
      const sendEmail = document.getElementById('reset-toggle-email')?.checked;
      const sendWa = document.getElementById('reset-toggle-wa')?.checked;

      if (!newPassword || newPassword.length < 4) {
        Toast.error('Password must be at least 4 characters long');
        return false;
      }

      const saveBtn = document.getElementById('btn-save-reset-password');
      if (saveBtn) {
        saveBtn.disabled = true;
        saveBtn.textContent = 'Saving & Updating Password...';
      }

      try {
        const res = await api.post(`/api/students/${student._id}/reset-password`, {
          newPassword,
          sendEmail
        });

        if (res.success) {
          Toast.success(`Password updated for ${student.name}!`);
          if (sendWa && res.data?.whatsappUrl) {
            window.open(res.data.whatsappUrl, '_blank');
          }
          if (modalInstance && typeof modalInstance.close === 'function') {
            modalInstance.close();
          }
          return true;
        } else {
          Toast.error(res.message || 'Failed to update password');
          if (saveBtn) {
            saveBtn.disabled = false;
            saveBtn.textContent = '💾 Save & Update Password';
          }
          return false;
        }
      } catch (err) {
        Toast.error(err.message || 'Password update failed');
        if (saveBtn) {
          saveBtn.disabled = false;
          saveBtn.textContent = '💾 Save & Update Password';
        }
        return false;
      }
    };

    const modal = Modal.show({
      title: '🔑 Reset Student Portal Password',
      content: contentHtml,
      confirmText: '💾 Save & Update Password',
      confirmClass: 'btn-primary',
      onConfirm: async (m) => {
        return await executeSavePassword(m);
      }
    });

    // Attach Preset Event Listeners inside Modal
    setTimeout(() => {
      const input = document.getElementById('reset-pwd-input');
      document.getElementById('preset-random-pin')?.addEventListener('click', () => {
        if (input) input.value = Math.floor(100000 + Math.random() * 900000).toString();
      });
      document.getElementById('preset-phone-pin')?.addEventListener('click', () => {
        if (input && cleanPhone) input.value = cleanPhone;
      });
      document.getElementById('preset-dob-pin')?.addEventListener('click', () => {
        if (input && formattedDob) input.value = formattedDob;
      });
      document.getElementById('btn-toggle-reset-eye')?.addEventListener('click', () => {
        if (input) input.type = input.type === 'password' ? 'text' : 'password';
      });
      document.getElementById('btn-save-reset-password')?.addEventListener('click', () => {
        executeSavePassword(modal);
      });
    }, 100);
  }

  const searchInput = container.querySelector('#studentSearch');
  if (searchInput) {
    searchInput.addEventListener('input', debounce(() => loadStudents(1), 250));
  }

  const statusFilter = container.querySelector('#studentStatusFilter');
  if (statusFilter) {
    statusFilter.addEventListener('change', () => loadStudents(1));
  }

  // Initial load
  setTimeout(() => {
    loadStats();
    loadStudents(1);
  }, 0);

  // Mount context-aware FAB for Students page
  if (typeof window !== 'undefined' && window.FAB) {
    window.FAB.mount({
      icon: '🎓',
      label: 'Student Actions',
      color: 'var(--color-primary, #6c5ce7)',
      actions: [
        {
          icon: '➕',
          label: 'Add Student',
          onClick: () => { const btn = container.querySelector('#addStudentBtn'); if (btn) btn.click(); }
        },
        {
          icon: '⏳',
          label: 'Waiting List',
          onClick: () => { const tab = container.querySelector('[data-tab="waiting"]'); if (tab) tab.click(); }
        },
        {
          icon: '📤',
          label: 'Export Students',
          onClick: () => { const btn = container.querySelector('#exportStudentsBtn, [id*="export"]'); if (btn) btn.click(); }
        }
      ]
    });
  }

  return container;
}
