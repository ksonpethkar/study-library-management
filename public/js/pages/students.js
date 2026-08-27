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
import { Validators } from '../utils/validators.js';

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
              <button class="btn btn-sm btn-outline-success btn-wa-remind" data-id="${escapeHTML(s._id)}" title="Send WhatsApp Reminder" style="padding: 4px 8px; font-size: 0.75rem; white-space: nowrap;">📲 WA</button>
              <button class="btn btn-sm btn-outline-primary btn-edit" data-id="${escapeHTML(s._id)}" title="Edit Student" style="padding: 4px 6px; font-size: 0.75rem;">✏️</button>
              ${typeof ActionMenu !== 'undefined' ? ActionMenu.renderHtml([
                { header: 'Level 1: Core Operations' },
                { id: 'view', icon: '👁️', label: 'View 360° Profile', bold: true },
                { id: 'edit', icon: '✏️', label: 'Edit Member Details' },
                { divider: true },
                { header: 'Level 2: Status & Lifecycle' },
                { id: 'toggle-status', icon: s.status === 'active' ? '⏸️' : '🟢', label: s.status === 'active' ? 'Suspend / Deactivate' : 'Activate Membership' },
                { divider: true },
                { header: 'Level 3: Documents & Data' },
                { id: 'idcard', icon: '🪪', label: 'Print Digital ID Pass' },
                { id: 'pdfform', icon: '📄', label: 'Download Admission PDF' },
                { id: 'pwdreset', icon: '🔑', label: 'Reset Password / PIN' },
                { divider: true },
                { header: 'Level 4: Critical & Danger' },
                { id: 'delete', icon: '🗑️', label: 'Delete Student Record', danger: true }
              ], s._id) : ''}
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

  let _cachedFormDeps = null;
  async function fetchFormDeps() {
    if (_cachedFormDeps && Array.isArray(_cachedFormDeps.branches) && _cachedFormDeps.branches.length > 0) {
      // Background revalidate
      Promise.all([
        api.get('/api/plans').catch(() => null),
        api.get('/api/seats?status=available').catch(() => null),
        api.get('/api/custom-fields/all').catch(() => null),
        api.get('/api/custom-fields/templates/active').catch(() => null),
        api.get('/api/branches/public-list').catch(() => null)
      ]).then(([pRes, sRes, cRes, tRes, bRes]) => {
        if (pRes?.data) _cachedFormDeps.plans = pRes.data;
        if (sRes?.data) _cachedFormDeps.seats = sRes.data;
        if (cRes?.data) _cachedFormDeps.customFields = cRes.data;
        if (tRes?.data) _cachedFormDeps.template = tRes.data;
        if (bRes?.data) _cachedFormDeps.branches = bRes.data;
      }).catch(() => {});
      return _cachedFormDeps;
    }

    try {
      const [plansRes, seatsRes, cfRes, tplRes, branchRes] = await Promise.all([
        api.get('/api/plans').catch(() => ({ data: [] })),
        api.get('/api/seats?status=available').catch(() => ({ data: [] })),
        api.get('/api/custom-fields/all').catch(() => ({ data: [] })),
        api.get('/api/custom-fields/templates/active').catch(() => ({ data: {} })),
        api.get('/api/branches/public-list').catch(() => ({ data: [] }))
      ]);
      _cachedFormDeps = {
        plans: plansRes?.data || [],
        seats: seatsRes?.data || [],
        customFields: cfRes?.data || [],
        template: tplRes?.data || {},
        branches: branchRes?.data || []
      };
      return _cachedFormDeps;
    } catch (err) {
      console.error('Error fetching student modal dependencies:', err);
      return { plans: [], seats: [], customFields: [], template: {}, branches: [] };
    }
  }

  async function showStudentForm(student = null) {
    let isEdit = !!student;

    // If editing a student, fetch fresh full document with all customFields and populated branch
    if (student && student._id) {
      try {
        const fullRes = await api.get(`/api/students/${student._id}`);
        if (fullRes?.data) student = fullRes.data;
      } catch (e) {}
    }

    const deps = await fetchFormDeps();
    const plansList = Array.isArray(deps.plans) ? deps.plans : [];
    const seatsList = Array.isArray(deps.seats) ? deps.seats : [];
    const customFields = Array.isArray(deps.customFields) ? deps.customFields : [];
    const template = deps.template || {};

    let branchesList = Array.isArray(deps.branches) && deps.branches.length > 0
      ? deps.branches
      : (window.store?.branches && window.store.branches.length > 0 ? window.store.branches : []);

    if (branchesList.length === 0) {
      try {
        const bRes = await api.get('/api/branches/public-list');
        if (bRes?.data && Array.isArray(bRes.data) && bRes.data.length > 0) {
          branchesList = bRes.data;
          if (_cachedFormDeps) _cachedFormDeps.branches = branchesList;
        }
      } catch (e) {}
    }

    // Fetch available plans, seats, custom fields, and active form template
    let plansOptions = '<option value="">-- Select Plan (Optional) --</option>';
    let seatsOptions = '<option value="">-- Select Seat (Optional) --</option>';
    let rawAvailableSeats = seatsList;

    plansList.forEach(p => {
      const selected = (student && student.plan && (student.plan._id === p._id || student.plan === p._id)) ? 'selected' : '';
      plansOptions += `<option value="${p._id}" ${selected}>${escapeHTML(p.name)} - ₹${p.price} (${p.duration} ${p.durationType})</option>`;
    });

    seatsList.forEach(s => {
      const selected = (student && student.seat && (student.seat._id === s._id || student.seat === s._id)) ? 'selected' : '';
      seatsOptions += `<option value="${s._id}" ${selected}>${escapeHTML(s.seatNumber)} (${escapeHTML(s.zone)} - ${escapeHTML(s.type)})</option>`;
    });

    if (student && student.seat && typeof student.seat === 'object') {
      if (!seatsOptions.includes(student.seat._id)) {
        seatsOptions += `<option value="${student.seat._id}" selected>${escapeHTML(student.seat.seatNumber)} (Current)</option>`;
      }
    }

    // Helper to extract student field values
    function getVal(fieldName) {
      if (!student) return '';

      const fn = (fieldName || '').toLowerCase().replace(/[^a-z0-9]/g, '');

      // Special branch extraction (handles populated branch object, ID string, or customFields)
      if (fn === 'branch' || fn === 'studycentre' || fn === 'center' || fn === 'centre') {
        if (student.branch) {
          if (typeof student.branch === 'object' && student.branch._id) return String(student.branch._id);
          return String(student.branch);
        }
        return (student.customFields && (student.customFields.branch || student.customFields.studycentre || student.customFields.center)) || '';
      }

      if (student[fieldName] !== undefined && student[fieldName] !== null && student[fieldName] !== '') return student[fieldName];
      
      if (fn === 'targetexams' || fn === 'target_exams' || fn === 'competitiveexams' || fn === 'exams') {
        return student.targetExams || student.customFields?.targetExams || student.customFields?.target_exams || '';
      }
      if (fn === 'gender') {
        return student.gender || student.customFields?.gender || student.customFields?.Gender || '';
      }
      if (fn === 'bloodgroup' || fn === 'blood' || fn === 'blood_group') {
        return student.bloodGroup || student.customFields?.bloodGroup || student.customFields?.blood_group || student.customFields?.bloodgroup || student.customFields?.BloodGroup || '';
      }
      if (fn === 'occupation' || fn === 'collegeorcompany' || fn === 'college_or_company') {
        return student.occupation || student.collegeOrCompany || student.customFields?.occupation || student.customFields?.collegeOrCompany || student.customFields?.college_or_company || '';
      }
      if (fn === 'idprooftype' || fn === 'id_proof_type' || fn === 'idtype') {
        return student.idProof?.type || student.customFields?.idProofType || student.customFields?.id_proof_type || student.customFields?.idprooftype || 'Aadhaar Card';
      }
      if (fn === 'idproofnumber' || fn === 'id_proof_number' || fn === 'idnumber' || fn === 'aadhaar' || fn === 'pan') {
        return student.idProof?.number || student.customFields?.idProofNumber || student.customFields?.id_proof_number || student.customFields?.idproofnumber || student.customFields?.aadhaar || student.customFields?.pan || '';
      }
      if (fn === 'idproofimage' || fn === 'idproof' || fn === 'id_proof_image') {
        return student.idProof?.image || student.customFields?.idProofImage || student.customFields?.id_proof_image || student.customFields?.idproofimage || '';
      }
      if (fn === 'emergencycontactname' || fn === 'emergency_contact_name' || fn === 'parentname' || fn === 'fathername' || fn === 'parentguardianname' || fn === 'guardianname' || fn === 'parentcontactname') {
        return student.emergencyContact?.name || student.customFields?.parent___guardian_name || student.customFields?.parentguardianname || student.customFields?.emergencyContactName || student.customFields?.parentName || student.customFields?.fatherName || student.customFields?.emergency_contact_name || student.customFields?.emergencycontactname || '';
      }
      if (fn === 'emergencycontactphone' || fn === 'emergencycontact' || fn === 'parentphone' || fn === 'emergency_contact_phone' || fn === 'emergencyphone') {
        return student.emergencyContact?.phone || student.customFields?.emergencyContactPhone || student.customFields?.emergencyContact || student.customFields?.emergencycontact || student.customFields?.parentPhone || student.customFields?.emergency_contact_phone || student.customFields?.emergencycontactphone || '';
      }
      if (fn === 'emergencycontactrelation' || fn === 'emergency_contact_relation' || fn === 'parentrelation' || fn === 'relation' || fn === 'relationship') {
        return student.emergencyContact?.relation || student.customFields?.relationship || student.customFields?.relation || student.customFields?.emergencyContactRelation || student.customFields?.parentRelation || student.customFields?.emergency_contact_relation || student.customFields?.emergencycontactrelation || 'Parent';
      }
      if (fn === 'dateofbirth' || fn === 'dob' || fn === 'date_of_birth' || fn === 'birthdate') {
        const raw = student.dateOfBirth || student.dob || (student.customFields && (student.customFields.dateOfBirth || student.customFields.dob || student.customFields.dateofbirth || (student.customFields instanceof Map ? (student.customFields.get('dateOfBirth') || student.customFields.get('dob') || student.customFields.get('dateofbirth')) : null)));
        if (raw) {
          const d = new Date(raw);
          return isNaN(d.getTime()) ? '' : d.toISOString().split('T')[0];
        }
        return '';
      }
      if (fn === 'address') return student.address || student.customFields?.address || '';
      if (fn === 'city') return student.city || student.customFields?.city || '';
      if (fn === 'state') return student.state || student.customFields?.state || '';
      if (fn === 'pincode') return student.pincode || student.customFields?.pincode || '';

      if (student.customFields) {
        if (student.customFields instanceof Map) {
          if (student.customFields.has(fieldName)) return student.customFields.get(fieldName) || '';
          // Also try case-insensitive check
          for (const [k, v] of student.customFields.entries()) {
            if (k.toLowerCase().replace(/[^a-z0-9]/g, '') === fn) return v || '';
          }
        } else if (typeof student.customFields === 'object') {
          if (student.customFields[fieldName] !== undefined && student.customFields[fieldName] !== null) return student.customFields[fieldName];
          for (const [k, v] of Object.entries(student.customFields)) {
            if (k.toLowerCase().replace(/[^a-z0-9]/g, '') === fn) return v || '';
          }
        }
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

    const seenFieldNames = new Set(!isEdit ? ['name', 'phone', 'plan', 'seat', 'status', 'paymentmode', 'payment_mode'] : []);
    const adminFieldKeys = new Set(['plan', 'seat', 'status', 'notes', 'rfidCardNumber', 'biometricId', 'paymentMode', 'payment_mode']);
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

    const hasBranchInActive = activeFields.some(f => {
      const k = (f.fieldName || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      return k === 'branch' || k === 'studycentre' || k === 'center' || k === 'centre' || f.type === 'branch';
    });

    const sectionsMap = new Map();
    const iconMap = { personal: '👤', academic: '🎯', plan: '⏰', payment: '💳', seat: '🪑', contact: '📍', kyc: '🪪', address: '📍' };
    configuredSections.forEach(s => {
      sectionsMap.set(s.name, {
        key: s.name,
        label: s.label,
        icon: iconMap[s.icon] || (s.icon && s.icon.length <= 4 ? s.icon : '') || '📝',
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
        const idTypeVal = String(getVal('idProofType') || '').toLowerCase();
        return `
          <div class="col-12 mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">📑 ${escapeHTML(f.label)}${reqMark}</label>
            <div class="row g-2 mb-2" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
              <div>
                <label class="form-label text-xs">ID Proof Type</label>
                <select class="form-select form-control" name="idProof.type">
                  <option value="Aadhaar Card" ${idTypeVal.includes('aadhaar') || idTypeVal === '' ? 'selected' : ''}>Aadhaar Card</option>
                  <option value="PAN Card" ${idTypeVal.includes('pan') ? 'selected' : ''}>PAN Card</option>
                  <option value="Driving License" ${idTypeVal.includes('driving') ? 'selected' : ''}>Driving License</option>
                  <option value="Voter ID" ${idTypeVal.includes('voter') ? 'selected' : ''}>Voter ID</option>
                  <option value="Passport" ${idTypeVal.includes('passport') ? 'selected' : ''}>Passport</option>
                  <option value="Student / College ID" ${idTypeVal.includes('student') || idTypeVal.includes('college') ? 'selected' : ''}>Student / College ID</option>
                  <option value="Other Govt ID" ${idTypeVal.includes('other') || idTypeVal.includes('govt') ? 'selected' : ''}>Other Govt ID</option>
                </select>
              </div>
              <div>
                <label class="form-label text-xs">ID Document Number</label>
                <input type="text" class="form-control" name="idProof.number" value="${escapeHTML(getVal('idProofNumber'))}" placeholder="Enter card / document number">
              </div>
            </div>
            <div id="mount-student-idproof" class="custom-media-mount" data-field="idProofImage" data-preset="document" data-label="ID Proof Document Upload"></div>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'address_autocomplete') {
        return `
          <div class="col-12 mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">📍 ${escapeHTML(f.label)}${reqMark}</label>
            <textarea class="form-control custom-dyn-input mb-2" name="address" data-field="address" rows="2" placeholder="Full residential street address">${escapeHTML(getVal('address'))}</textarea>
            <div class="row g-2" style="display: grid; grid-template-columns: 140px 1fr 1fr; gap: 8px;">
              <div>
                <input type="text" class="form-control custom-dyn-input" name="pincode" data-field="pincode" value="${escapeHTML(getVal('pincode'))}" placeholder="Pincode (6 digits)" maxlength="6">
              </div>
              <div>
                <input type="text" class="form-control custom-dyn-input" name="city" data-field="city" value="${escapeHTML(getVal('city'))}" placeholder="City">
              </div>
              <div>
                <input type="text" class="form-control custom-dyn-input" name="state" data-field="state" value="${escapeHTML(getVal('state'))}" placeholder="State">
              </div>
            </div>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'exam_badge') {
        const examsList = f.options && f.options.length > 0 ? f.options : ['UPSC', 'MPSC', 'Banking / IBPS', 'SSC CGL', 'JEE / NEET', 'CA / CS', 'GATE', 'UGC NET', 'State PSC', 'Law / CLAT', 'Defence / NDA', 'Other'];
        const currentVal = getVal(f.fieldName);
        const selectedArr = Array.isArray(currentVal) ? currentVal : (typeof currentVal === 'string' ? currentVal.split(',').map(s => s.trim()).filter(Boolean) : []);
        return `
          <div class="col-12 mt-2 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">🎯 ${escapeHTML(f.label)}${reqMark}</label>
            <div id="exam-chips-container" style="display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px;">
              ${examsList.map(ex => {
                const isSel = selectedArr.some(s => String(s).toLowerCase().trim() === String(ex).toLowerCase().trim());
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
        const currentBg = String(val || '').toUpperCase().trim();
        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">🩸 ${escapeHTML(f.label)}${reqMark}</label>
            <select class="form-select form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" ${f.required ? 'required' : ''}>
              <option value="">-- Select Blood Group --</option>
              ${bgOptions.map(bg => `<option value="${bg}" ${currentBg === bg ? 'selected' : ''}>${bg}</option>`).join('')}
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

      const lowerFld = (f.fieldName || '').toLowerCase().replace(/[^a-z0-9]/g, '');
      const isBranchField = lowerFld === 'branch' || lowerFld === 'studycentre' || lowerFld === 'centre' || lowerFld === 'center' || f.type === 'branch';
      if (isBranchField) {
        const curBranchVal = String(val || '').trim().toLowerCase();
        let branchOptionsHtml = '<option value="">-- Select Study Centre / Branch --</option>';
        (branchesList || []).forEach(b => {
          const bId = String(b._id || b.id || '');
          const bName = b.name || 'Main Campus';
          const bCity = b.city ? ` (${b.city})` : '';
          const isSelected = (curBranchVal && curBranchVal === bId.toLowerCase()) || (curBranchVal && curBranchVal === bName.toLowerCase());
          branchOptionsHtml += `<option value="${escapeHTML(bId)}" ${isSelected ? 'selected' : ''}>${escapeHTML(bName + bCity)}</option>`;
        });

        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 600;">🏛️ ${escapeHTML(f.label || 'Preferred Study Centre / Branch')}${reqMark}</label>
            <select class="form-select form-control custom-dyn-input" data-field="branch" name="branch" ${f.required ? 'required' : ''}>
              ${branchOptionsHtml}
            </select>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'select') {
        const curVal = String(val || '').toLowerCase().trim();
        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
            <select class="form-select form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" ${f.required ? 'required' : ''}>
              <option value="">-- Select --</option>
              ${(f.options || []).map(opt => `<option value="${escapeHTML(opt)}" ${curVal === String(opt).toLowerCase().trim() ? 'selected' : ''}>${escapeHTML(opt)}</option>`).join('')}
            </select>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'radio') {
        const curVal = String(val || '').toLowerCase().trim();
        return `
          <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
            <div style="display: flex; gap: 12px; flex-wrap: wrap; margin-top: 4px;">
              ${(f.options || []).map(opt => `
                <label style="display: inline-flex; align-items: center; gap: 4px; font-size: 0.88rem; cursor: pointer;">
                  <input type="radio" class="custom-dyn-radio" name="${escapeHTML(f.fieldName)}" data-field="${escapeHTML(f.fieldName)}" value="${escapeHTML(opt)}" ${curVal === String(opt).toLowerCase().trim() ? 'checked' : ''}>
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
            <label class="form-check" style="display: inline-flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
              <input type="checkbox" class="form-checkbox custom-dyn-checkbox" name="${escapeHTML(f.fieldName)}" data-field="${escapeHTML(f.fieldName)}" ${isChecked ? 'checked' : ''} ${f.required ? 'required' : ''}>
              <span class="form-label mb-0" style="font-size: 0.88rem; font-weight: 500;">${escapeHTML(f.label)}${reqMark}</span>
            </label>
            ${helpText}
          </div>
        `;
      }

      if (f.type === 'textarea') {
        return `
          <div class="col-12 dynamic-field-wrapper" ${depAttr}>
            <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
            <textarea class="form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" placeholder="${escapeHTML(f.placeholder || '')}" rows="2" ${f.required ? 'required' : ''}>${escapeHTML(val)}</textarea>
            ${helpText}
          </div>
        `;
      }

      const inputType = (f.type === 'phone') ? 'tel' : (f.type === 'date' ? 'date' : (f.type === 'time' ? 'time' : (f.type === 'number' ? 'number' : (f.type === 'email' ? 'email' : 'text'))));
      return `
        <div class="${colClass} dynamic-field-wrapper" ${depAttr}>
          <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)}${reqMark}</label>
          <input type="${inputType}" class="form-control custom-dyn-input" data-field="${escapeHTML(f.fieldName)}" name="${escapeHTML(f.fieldName)}" value="${escapeHTML(val)}" placeholder="${escapeHTML(f.placeholder || '')}" ${f.required ? 'required' : ''}>
          ${helpText}
        </div>
      `;
    }

    let dynamicSectionsHtml = '';
    sectionsMap.forEach(sec => {
      if (sec.fields.length === 0) return;
      dynamicSectionsHtml += `
        <div class="col-12 mt-3 mb-1" style="border-top: 1px solid var(--color-border); padding-top: 10px;">
          <h5 style="font-size: 1rem; font-weight: 700; color: var(--color-primary); margin-bottom: 8px; display: flex; align-items: center; gap: 8px;">
            <span>${sec.icon || '📝'}</span>
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

              ${!hasBranchInActive ? `
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700;">Select Study Centre / Branch</label>
                <select class="form-select form-control custom-dyn-input" data-field="branch" name="branch" style="font-weight: 600;">
                  <option value="">-- Select Study Centre / Branch --</option>
                  ${branchesList.map(b => {
                    const bId = String(b._id || b.id || '');
                    const bName = b.name || 'Main Campus';
                    const bCity = b.city ? ` (${b.city})` : '';
                    const curBranchVal = String(getVal('branch') || '').trim().toLowerCase();
                    const isSelected = (curBranchVal && curBranchVal === bId.toLowerCase()) || (curBranchVal && curBranchVal === bName.toLowerCase());
                    return `<option value="${escapeHTML(bId)}" ${isSelected ? 'selected' : ''}>${escapeHTML(bName + bCity)}</option>`;
                  }).join('')}
                </select>
              </div>
              ` : ''}

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
                <select class="form-select form-control" name="paymentMode" id="adminStudentPaymentMode" style="font-weight: 600;">
                  <option value="cash" selected>💵 Cash at Reception Desk</option>
                  <option value="upi">⚡ Direct UPI (GPay / PhonePe / Paytm / BHIM)</option>
                  <option value="bank_transfer">🏛️ Bank Transfer (NEFT / IMPS / RTGS)</option>
                  <option value="card">💳 Debit / Credit Card (POS Terminal)</option>
                </select>
              </div>

              <div class="col-12" id="adminStudentPaymentContext"></div>

              <div class="col-md-6" id="adminStudentTxnWrapper">
                <label class="form-label" id="adminStudentTxnLabel" style="font-weight: 600;">💵 Cash Collector Note (Optional)</label>
                <input type="text" class="form-control" name="transactionId" id="adminStudentTxnInput" placeholder="e.g. Cash received at reception desk" value="${student && student.transactionId ? escapeHTML(student.transactionId) : ''}">
                <small id="adminStudentUtrWarn" class="text-danger" style="display: none; font-size: 0.75rem; margin-top: 3px; font-weight: 600;"></small>
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
              ${!hasBranchInActive ? `
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 600;">🏛️ Preferred Study Centre / Branch</label>
                <select class="form-select form-control custom-dyn-input" data-field="branch" name="branch">
                  <option value="">-- Select Study Centre / Branch --</option>
                  ${branchesList.map(b => {
                    const bId = String(b._id || b.id || '');
                    const bName = b.name || 'Main Campus';
                    const bCity = b.city ? ` (${b.city})` : '';
                    const curBranchVal = String(getVal('branch') || '').trim().toLowerCase();
                    const isSelected = (curBranchVal && curBranchVal === bId.toLowerCase()) || (curBranchVal && curBranchVal === bName.toLowerCase());
                    return `<option value="${escapeHTML(bId)}" ${isSelected ? 'selected' : ''}>${escapeHTML(bName + bCity)}</option>`;
                  }).join('')}
                </select>
              </div>
              ` : ''}

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
            if (!form) return;

            const nameInput = form.querySelector('[name="name"]');
            const phoneInput = form.querySelector('[name="phone"]');

            const nameVal = nameInput?.value?.trim();
            if (!nameVal || nameVal.length < 2) {
              Toast.warning('Please enter a valid Student Full Name (minimum 2 characters)');
              nameInput?.focus();
              return;
            }

            let phoneVal = phoneInput?.value?.trim().replace(/[^0-9+]/g, '') || '';
            if (!phoneVal) {
              Toast.warning('Please enter the Mobile Number (WhatsApp)');
              phoneInput?.focus();
              return;
            }
            if (phoneVal.startsWith('0') && phoneVal.length === 11) {
              phoneVal = phoneVal.slice(1);
            }
            const cleanPhoneDigits = phoneVal.replace(/[^0-9]/g, '');
            if (cleanPhoneDigits.length < 10 || !/^[6-9]\d{9}$/.test(cleanPhoneDigits.slice(-10))) {
              Toast.warning('Please enter a valid 10-digit Indian mobile number (starting with 6, 7, 8, or 9)');
              phoneInput?.focus();
              return;
            }

            const formData = new FormData(form);
            const data = Object.fromEntries(formData.entries());
            data.name = nameVal;
            data.phone = phoneVal;
            
            // Handle target exams array
            const selectedExamsInput = m.element.querySelector('#selectedTargetExams');
            const examsStr = selectedExamsInput ? selectedExamsInput.value : (data.targetExams || '');
            data.targetExams = examsStr ? (Array.isArray(examsStr) ? examsStr : String(examsStr).split(',').map(s => s.trim()).filter(Boolean)) : [];

            // Capture all custom dynamic fields
            data.customFields = {};
            m.element.querySelectorAll('.custom-dyn-input').forEach(input => {
              const fName = input.dataset.field || input.name;
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
              const fName = radio.dataset.field || radio.name;
              if (fName) data.customFields[fName] = radio.value;
            });

            // Capture custom media fields
            m.element.querySelectorAll('.custom-field-media-mount').forEach(mount => {
              const fName = mount.dataset.field;
              const val = mount.querySelector('.mfp-hidden-value')?.value || '';
              if (val) data.customFields[fName] = val;
            });

            const customF = data.customFields || {};

            // 0. Preferred Study Centre / Branch
            const branchInput = form.querySelector('[name="branch"]') || m.element.querySelector('[name="branch"]') || m.element.querySelector('[data-field="branch"]');
            const extractedBranch = branchInput?.value || data.branch || customF.branch || (student && (student.branch?._id || student.branch)) || '';
            if (extractedBranch && String(extractedBranch).trim()) {
              data.branch = String(extractedBranch).trim();
              data.customFields.branch = data.branch;
            } else {
              delete data.branch;
            }

            // 1. Blood Group
            const extractedBloodGroup = data.bloodGroup || data.blood_group || data.bloodgroup || customF.bloodGroup || customF.blood_group || customF.bloodgroup || customF.BloodGroup || student?.bloodGroup || '';
            if (extractedBloodGroup) {
              data.bloodGroup = String(extractedBloodGroup).trim();
              data.customFields.bloodGroup = data.bloodGroup;
              data.customFields.bloodgroup = data.bloodGroup;
            }

            // 2. Gender
            const extractedGender = data.gender || customF.gender || customF.Gender || student?.gender || '';
            if (extractedGender) {
              data.gender = String(extractedGender).toLowerCase().trim();
            }

            // 3. Occupation / College
            const extractedOccupation = data.occupation || data.collegeOrCompany || data.college_or_company || customF.occupation || customF.collegeOrCompany || customF.college_or_company || student?.occupation || student?.collegeOrCompany || '';
            if (extractedOccupation) {
              data.occupation = String(extractedOccupation).trim();
              data.collegeOrCompany = data.occupation;
              data.customFields.occupation = data.occupation;
            }

            // 4. Address, City, State, Pincode
            const extractedAddress = data.address || customF.address || student?.address || '';
            if (extractedAddress) data.address = String(extractedAddress).trim();
            const extractedCity = data.city || customF.city || student?.city || '';
            if (extractedCity) data.city = String(extractedCity).trim();
            const extractedState = data.state || customF.state || student?.state || '';
            if (extractedState) data.state = String(extractedState).trim();
            const extractedPincode = data.pincode || customF.pincode || student?.pincode || '';
            if (extractedPincode) data.pincode = String(extractedPincode).trim();

            // 5. Passport Photo & KYC ID Proof
            const photoVal = m.element.querySelector('#mount-student-photo .mfp-hidden-value')?.value;
            if (photoVal !== undefined) data.photo = photoVal;

            const kycVal = m.element.querySelector('#mount-student-idproof .mfp-hidden-value')?.value;
            if (kycVal !== undefined) data.idProofImage = kycVal;

            const idType = data.idProofType || data['idProof.type'] || data['idProof[type]'] || data.id_proof_type || data.idprooftype || data.idType || customF.idProofType || customF.idprooftype || customF.id_proof_type || student?.idProof?.type || 'Aadhaar Card';
            const idNum = data.idProofNumber || data['idProof.number'] || data['idProof[number]'] || data.id_proof_number || data.idproofnumber || data.idNumber || data.aadhaar || data.pan || customF.idProofNumber || customF.idproofnumber || customF.id_proof_number || customF.aadhaar || customF.pan || student?.idProof?.number || '';
            const idImg = data.idProofImage || data['idProof.image'] || data['idProof[image]'] || data.id_proof_image || data.idproofimage || customF.idProofImage || customF.idproofimage || student?.idProof?.image || '';

            data.idProof = {
              type: String(idType).trim(),
              number: String(idNum).trim(),
              image: String(idImg).trim()
            };
            data.customFields.idProofType = data.idProof.type;
            data.customFields.idprooftype = data.idProof.type;
            data.customFields.idProofNumber = data.idProof.number;
            data.customFields.idproofnumber = data.idProof.number;
            data.customFields.idProofImage = data.idProof.image;
            data.customFields.idproofimage = data.idProof.image;

            delete data['idProof.type'];
            delete data['idProof.number'];
            delete data['idProof.image'];
            delete data.idProofType;
            delete data.idProofNumber;
            delete data.idProofImage;

            // 6. Emergency Contact
            const emName = data.emergencyContactName || data['emergencyContact.name'] || data['emergencyContact[name]'] || data.parentName || data.parent___guardian_name || data.parent_name || data.parentguardianname || data.guardianName || data.fatherName || customF.parent___guardian_name || customF.parentguardianname || customF.guardianName || customF.emergencyContactName || customF.parentName || customF.fatherName || customF.emergency_contact_name || customF.emergencycontactname || student?.emergencyContact?.name || '';
            const emPhone = data.emergencyContactPhone || data['emergencyContact.phone'] || data['emergencyContact[phone]'] || data.emergencyContact || data.emergencycontact || data.parentPhone || data.parent_phone || customF.emergencyContactPhone || customF.emergencyContact || customF.emergencycontact || customF.parentPhone || customF.emergency_contact_phone || customF.emergencycontactphone || student?.emergencyContact?.phone || '';
            const emRel = data.emergencyContactRelation || data['emergencyContact.relation'] || data['emergencyContact[relation]'] || data.relationship || data.relation || data.parentRelation || data.parent_relation || customF.relationship || customF.relation || customF.emergencyContactRelation || customF.parentRelation || customF.emergency_contact_relation || customF.emergencycontactrelation || student?.emergencyContact?.relation || 'Parent';

            data.emergencyContact = {
              name: String(emName).trim(),
              phone: String(emPhone).trim().replace(/[^0-9+]/g, ''),
              relation: String(emRel).trim()
            };
            data.customFields.emergencyContact = data.emergencyContact.phone;
            data.customFields.emergencycontact = data.emergencyContact.phone;
            data.customFields.emergencyContactPhone = data.emergencyContact.phone;
            data.customFields.emergencycontactphone = data.emergencyContact.phone;
            data.customFields.parent___guardian_name = data.emergencyContact.name;
            data.customFields.parentguardianname = data.emergencyContact.name;
            data.customFields.emergencyContactName = data.emergencyContact.name;
            data.customFields.emergencycontactname = data.emergencyContact.name;
            data.customFields.relationship = data.emergencyContact.relation;
            data.customFields.relation = data.emergencyContact.relation;
            data.customFields.emergencyContactRelation = data.emergencyContact.relation;
            data.customFields.emergencycontactrelation = data.emergencyContact.relation;

            delete data['emergencyContact.name'];
            delete data['emergencyContact.phone'];
            delete data['emergencyContact.relation'];
            delete data.emergencyContactName;
            delete data.emergencyContactPhone;
            delete data.emergencyContactRelation;

            // Capture Signature from SignatureStudio
            if (sigStudio) {
              const sigVal = sigStudio.getValue();
              if (sigVal) data.signature = sigVal;
            }

            // Handle optional references
            if (!data.plan) delete data.plan;
            if (!data.seat) delete data.seat;

            // 7. Date of Birth Mapping
            const rawDob = data.dateOfBirth || data.dob || data.dateofbirth || data.date_of_birth || data.birthDate || data.birthdate || customF.dateOfBirth || customF.dob || customF.dateofbirth || customF.date_of_birth || customF.birthDate || customF.birthdate || student?.dateOfBirth;
            if (rawDob) {
              data.dateOfBirth = rawDob;
              data.customFields.dateOfBirth = rawDob;
              data.customFields.dob = rawDob;
              data.customFields.dateofbirth = rawDob;
            } else {
              delete data.dateOfBirth;
            }
            delete data.dob;
            delete data.dateofbirth;
            delete data.date_of_birth;
            delete data.birthDate;
            delete data.birthdate;

            // Strict Validation Checks:
            // Email Validation
            if (data.email && data.email.trim() && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(data.email.trim())) {
              Toast.warning('Please enter a valid email address (e.g. name@example.com)');
              return;
            }

            // Pincode Validation
            if (data.pincode && data.pincode.trim() && !/^[1-9][0-9]{5}$/.test(data.pincode.trim())) {
              Toast.warning('Please enter a valid 6-digit Indian Postal PIN code (e.g. 411001)');
              return;
            }

            // Government ID Validation
            if (data.idProof.number && data.idProof.number.trim()) {
              const idValidation = SmartIntelligence.validateGovernmentID(data.idProof.type, data.idProof.number.trim());
              if (!idValidation.isValid) {
                Toast.warning(idValidation.message);
                return;
              }
            }

            // Emergency Contact Phone Validation
            if (data.emergencyContact.phone && data.emergencyContact.phone.trim()) {
              const cleanEmPhone = data.emergencyContact.phone.trim().replace(/[^0-9]/g, '');
              if (cleanEmPhone.length < 10 || !/^[6-9]\d{9}$/.test(cleanEmPhone.slice(-10))) {
                Toast.warning('Please enter a valid 10-digit mobile number for Emergency Contact');
                return;
              }
              if (cleanEmPhone.slice(-10) === cleanPhoneDigits.slice(-10)) {
                Toast.warning('Emergency Contact number cannot be identical to the student’s own mobile number. Please provide a Parent / Guardian contact number.');
                return;
              }
            }

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

    // Attach Live Real-Time Validation Feedback to form inputs
    const nameInput = modal.element.querySelector('input[name="name"]');
    if (nameInput) {
      Validators.attachLiveValidation(nameInput, val => Validators.text(val, 2, 100, 'Student Name', true));
    }
    const phoneInput = modal.element.querySelector('input[name="phone"]');
    if (phoneInput) {
      Validators.attachLiveValidation(phoneInput, val => Validators.phone(val, true));
    }
    const emailInput = modal.element.querySelector('input[name="email"]');
    if (emailInput) {
      Validators.attachLiveValidation(emailInput, val => Validators.email(val, false));
    }
    const emPhoneInput = modal.element.querySelector('input[name="emergencyContact.phone"], input[name="emergencyContactPhone"]');
    if (emPhoneInput) {
      Validators.attachLiveValidation(emPhoneInput, val => Validators.phone(val, false));
    }

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
    if (SmartIntelligence && typeof SmartIntelligence.bindDynamicIDProofValidation === 'function') {
      SmartIntelligence.bindDynamicIDProofValidation(modal.element);
    }

    // Setup Dynamic Payment Mode Adapter in Student Admission Modal
    const admPaySelect = modal.element.querySelector('#adminStudentPaymentMode');
    const admPayContext = modal.element.querySelector('#adminStudentPaymentContext');
    const admPayTxnLabel = modal.element.querySelector('#adminStudentTxnLabel');
    const admPayTxnInput = modal.element.querySelector('#adminStudentTxnInput');
    const admPayUtrWarn = modal.element.querySelector('#adminStudentUtrWarn');

    const updateAdminPaymentUI = () => {
      const mode = admPaySelect?.value || 'cash';
      const upiId = window.store?.settings?.businessProfile?.upiId || window.store?.profile?.upiId || '';

      if (mode === 'cash') {
        if (admPayTxnLabel) admPayTxnLabel.innerHTML = '💵 Cash Collector Note (Optional)';
        if (admPayTxnInput) admPayTxnInput.placeholder = 'e.g. Cash received at reception desk';
        if (admPayContext) {
          admPayContext.innerHTML = `
            <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>💵</span>
              <span><strong>Cash Admission:</strong> Instant membership activation. No transaction reference required.</span>
            </div>
          `;
        }
        if (admPayUtrWarn) admPayUtrWarn.style.display = 'none';
      } else if (mode === 'bank_transfer') {
        if (admPayTxnLabel) admPayTxnLabel.innerHTML = '🏛️ Bank NEFT / IMPS / RTGS Reference Number';
        if (admPayTxnInput) admPayTxnInput.placeholder = 'e.g. Bank Reference / UTR Number';
        if (admPayContext) {
          admPayContext.innerHTML = `
            <div style="background: rgba(9, 132, 227, 0.1); border: 1px solid #0984e3; border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>🏛️</span>
              <span><strong>Bank Transfer:</strong> Direct deposit / IMPS into library account.</span>
            </div>
          `;
        }
        if (admPayUtrWarn) admPayUtrWarn.style.display = 'none';
      } else if (mode === 'card') {
        if (admPayTxnLabel) admPayTxnLabel.innerHTML = '💳 POS Slip Code / Card Last 4 Digits';
        if (admPayTxnInput) admPayTxnInput.placeholder = 'e.g. POS Auth Code #8492 or Card Ending 4321';
        if (admPayContext) {
          admPayContext.innerHTML = `
            <div style="background: rgba(225, 112, 85, 0.1); border: 1px solid #e17055; border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
              <span>💳</span>
              <span><strong>Card Payment:</strong> Processed on POS terminal.</span>
            </div>
          `;
        }
        if (admPayUtrWarn) admPayUtrWarn.style.display = 'none';
      } else {
        // Default: UPI
        if (admPayTxnLabel) admPayTxnLabel.innerHTML = '⚡ UPI / 12-Digit UTR Transaction ID';
        if (admPayTxnInput) admPayTxnInput.placeholder = 'e.g. 12-digit UTR (e.g. 423456789012)';
        if (admPayContext) {
          admPayContext.innerHTML = `
            <div style="background: rgba(108, 92, 231, 0.1); border: 1px solid var(--color-primary, #6c5ce7); border-radius: 8px; padding: 8px 12px; font-size: 0.8rem; color: var(--color-text-primary); display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 6px;">
              <span>📱 <strong>UPI Payment:</strong> GPay, PhonePe, Paytm, BHIM.</span>
              ${upiId ? `<span class="badge" style="background: var(--color-primary); color: #fff; font-family: monospace; font-size: 0.75rem;">UPI: ${escapeHTML(upiId)}</span>` : ''}
            </div>
          `;
        }
      }
    };

    if (admPaySelect) {
      admPaySelect.addEventListener('change', updateAdminPaymentUI);
      updateAdminPaymentUI();
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
    const dupPhoneInput = modal.element.querySelector('input[name="phone"]');
    const dupEmailInput = modal.element.querySelector('input[name="email"]');
    const formElement = modal.element.querySelector('#studentForm');
    if (formElement) {
      formElement.addEventListener('submit', (e) => {
        e.preventDefault();
        e.stopPropagation();
      });
    }

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
      const phoneVal = dupPhoneInput?.value?.trim() || '';
      const emailVal = dupEmailInput?.value?.trim() || '';

      const otherStudents = (state.students || []).filter(s => !isEdit || (student && s._id !== student._id));
      const dupResult = SmartIntelligence.checkDuplicateStudent(phoneVal, emailVal, otherStudents);

      if (dupResult.isDuplicate && dupAlert) {
        dupAlert.textContent = dupResult.message;
        dupAlert.style.display = 'block';
      } else if (dupAlert) {
        dupAlert.style.display = 'none';
      }
    };

    if (dupPhoneInput) {
      dupPhoneInput.addEventListener('input', checkDuplicateAdmin);
      dupPhoneInput.addEventListener('blur', checkDuplicateAdmin);
    }
    if (dupEmailInput) {
      dupEmailInput.addEventListener('input', checkDuplicateAdmin);
      dupEmailInput.addEventListener('blur', checkDuplicateAdmin);
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
      if (student) previewAdmissionFormPDF(student, { business: window.store?.settings?.businessProfile, receiptConfig: window.store?.settings?.receipt });
      return;
    }
    
    const pwdBtn = e.target.closest('.btn-pwdreset');
    if (pwdBtn) {
      const id = pwdBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showPasswordResetModal(student);
      return;
    }

    const actionMenuItem = e.target.closest('.action-menu-item');
    if (actionMenuItem) {
      e.stopPropagation();
      e.preventDefault();
      const action = actionMenuItem.dataset.action;
      const id = actionMenuItem.dataset.id;
      const student = state.students.find(s => s._id === id);
      if (!student) return;

      if (action === 'view') showStudentProfile(student);
      else if (action === 'edit') showStudentForm(student);
      else if (action === 'idcard') showStudentIdCard(student);
      else if (action === 'pdfform') previewAdmissionFormPDF(student, { business: window.store?.settings?.businessProfile, receiptConfig: window.store?.settings?.receipt });
      else if (action === 'pwdreset') showPasswordResetModal(student);
      else if (action === 'delete') handleDelete(id);
      else if (action === 'toggle-status') {
        const newStatus = student.status === 'active' ? 'suspended' : 'active';
        api.put(`/api/students/${id}`, { status: newStatus }).then(res => {
          Toast.success(`Student status updated to ${newStatus}`);
          loadStudents(state.pagination.page);
        }).catch(err => Toast.error(err.message || 'Failed to update status'));
      }
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

  async function showStudentProfile(student) {
    if (student && student._id) {
      try {
        const fresh = await api.get(`/api/students/${student._id}`);
        if (fresh?.data) student = fresh.data;
      } catch (e) {}
    }

    let branchName = student.branch?.name || '';
    if (!branchName && student.branch && typeof student.branch === 'string') {
      const bFound = (_cachedFormDeps?.branches || window.store?.branches || []).find(b => String(b._id || b.id) === String(student.branch));
      if (bFound) branchName = bFound.name + (bFound.city ? ` (${bFound.city})` : '');
    }
    if (!branchName) branchName = student.customFields?.branch || 'Main Campus';

    const planName = student.plan?.name || 'Standard Plan';
    const seatNumber = student.seat?.seatNumber || 'Floating / Not Assigned';
    const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : '-';
    const expiryDate = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : '-';
    const daysLeft = student.expiryDate ? Math.ceil((new Date(student.expiryDate) - new Date()) / (1000 * 60 * 60 * 24)) : null;

    let phone = (student.phone || '').replace(/[^0-9]/g, '');
    if (phone.length === 10) phone = '91' + phone;
    const waUrl = phone ? `https://api.whatsapp.com/send?phone=${phone}` : null;

    function formatHumanLabel(rawKey) {
      if (!rawKey) return '';
      let str = String(rawKey).trim();
      if (str.includes('___')) str = str.replace(/___/g, ' / ');
      str = str.replace(/_/g, ' ');
      str = str.replace(/([a-z])([A-Z])/g, '$1 $2');
      return str
        .split(' ')
        .filter(Boolean)
        .map(w => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
        .join(' ')
        .replace(/\s*\/\s*/g, ' / ');
    }

    const standardKeys = new Set([
      'name', 'fullname', 'phone', 'mobile', 'whatsapp', 'email', 'gender', 'sex',
      'dob', 'dateofbirth', 'birthdate', 'bloodgroup', 'blood_group',
      'address', 'residentialaddress', 'pincode', 'postalcode', 'city', 'state',
      'emergencyname', 'emergencycontactname', 'emergencyphone', 'emergencycontactphone', 'emergencyrelation', 'emergencycontactrelation',
      'parentguardianname', 'parent___guardian_name', 'parentname', 'guardianname', 'fathername', 'mothername', 'relationship', 'relation', 'emergencycontact', 'parentphone',
      'idtype', 'idprooftype', 'idnumber', 'idproofnumber', 'idproof', 'idproofimage', 'idproofphoto',
      'targetexam', 'targetexams', 'college', 'collegename', 'institute', 'university', 'qualification', 'highestqualification',
      'branch', 'plan', 'shift', 'seat', 'password', 'photo', 'signature', 'status', 'remarks', 'specialremarks', 'notes',
      'rfidcardnumber', 'biometricid', 'occupation', 'collegeorcompany'
    ]);

    const customFieldsList = _cachedFormDeps?.customFields || [];
    const templateSections = _cachedFormDeps?.template?.sections || [];
    const cfMap = (student.customFields && typeof student.customFields === 'object') ? student.customFields : {};
    
    const extraCustomFields = [];
    if (cfMap instanceof Map) {
      for (const [k, v] of cfMap.entries()) {
        const normKey = k.toLowerCase().replace(/[^a-z0-9]/g, '');
        if (!standardKeys.has(normKey) && v !== undefined && v !== null && v !== '') {
          const def = customFieldsList.find(f => {
            const fn = f.fieldName?.toLowerCase().replace(/[^a-z0-9]/g, '');
            const fl = f.label?.toLowerCase().replace(/[^a-z0-9]/g, '');
            return fn === normKey || fl === normKey;
          });
          extraCustomFields.push({
            key: k,
            label: def?.label || formatHumanLabel(k),
            value: v,
            section: def?.section || 'additional',
            order: def?.order !== undefined ? def.order : 999,
            type: def?.type || 'text'
          });
        }
      }
    } else {
      Object.entries(cfMap).forEach(([k, v]) => {
        const normKey = k.toLowerCase().replace(/[^a-z0-9]/g, '');
        if (!standardKeys.has(normKey) && v !== undefined && v !== null && v !== '') {
          const def = customFieldsList.find(f => {
            const fn = f.fieldName?.toLowerCase().replace(/[^a-z0-9]/g, '');
            const fl = f.label?.toLowerCase().replace(/[^a-z0-9]/g, '');
            return fn === normKey || fl === normKey;
          });
          extraCustomFields.push({
            key: k,
            label: def?.label || formatHumanLabel(k),
            value: v,
            section: def?.section || 'additional',
            order: def?.order !== undefined ? def.order : 999,
            type: def?.type || 'text'
          });
        }
      });
    }

    const secIconMap = {
      personal: '👤', academic: '🎯', plan: '⏰', payment: '💳', seat: '🪑',
      contact: '📍', kyc: '🪪', parent: '👨‍👩‍👧', vehicle: '🚗', transport: '🚲',
      custom: '📋', additional: '📝', other: '📝'
    };

    const customSectionGroups = [];
    if (templateSections.length > 0) {
      templateSections.forEach(sec => {
        const mFields = extraCustomFields.filter(f => f.section === sec.name).sort((a, b) => a.order - b.order);
        if (mFields.length > 0) {
          customSectionGroups.push({
            name: sec.name,
            label: sec.label || formatHumanLabel(sec.name),
            icon: sec.icon && sec.icon.length <= 4 ? sec.icon : (secIconMap[sec.name] || '📋'),
            fields: mFields
          });
        }
      });
      const handledK = new Set(customSectionGroups.flatMap(g => g.fields.map(f => f.key)));
      const unhandledF = extraCustomFields.filter(f => !handledK.has(f.key));
      if (unhandledF.length > 0) {
        customSectionGroups.push({
          name: 'additional',
          label: 'Additional Registration Information',
          icon: '📝',
          fields: unhandledF.sort((a, b) => a.order - b.order)
        });
      }
    } else if (extraCustomFields.length > 0) {
      customSectionGroups.push({
        name: 'additional',
        label: 'Additional Registration Information',
        icon: '📝',
        fields: extraCustomFields.sort((a, b) => a.order - b.order)
      });
    }

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
            <div class="small text-muted mb-1">🏛️ Centre / Branch: <strong class="text-primary">${escapeHTML(branchName)}</strong></div>
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
            ${(() => {
              const emName = student.emergencyContact?.name || student.customFields?.parent___guardian_name || student.customFields?.parentguardianname || student.customFields?.parentName || student.customFields?.emergencyContactName || student.customFields?.guardianName || student.customFields?.fatherName || '';
              const emRel = student.emergencyContact?.relation || student.customFields?.relationship || student.customFields?.relation || student.customFields?.emergencyContactRelation || student.customFields?.parentRelation || 'Parent';
              const emPhone = student.emergencyContact?.phone || student.customFields?.emergencyContactPhone || student.customFields?.emergencyContact || student.customFields?.emergencycontact || student.customFields?.parentPhone || '';
              return `
                <div class="small text-muted">Emergency Contact: <strong>${escapeHTML(emName || 'N/A')} (${escapeHTML(emRel)}) - ${escapeHTML(SmartFormatters.phone(emPhone) || '')}</strong> ${emPhone ? `<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(emPhone)}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">📋</button>` : ''}</div>
              `;
            })()}
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

        <!-- Custom Sections & Questions as configured by Admin in Form Builder -->
        ${customSectionGroups.map(grp => `
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border); margin-bottom: 20px;">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-primary); display: flex; align-items: center; gap: 6px;">
              <span>${grp.icon}</span> ${escapeHTML(grp.label)}
            </h5>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 10px; font-size: 0.85rem;">
              ${grp.fields.map(f => {
                let dispVal = escapeHTML(String(f.value));
                if (typeof f.value === 'boolean' || f.value === 'true' || f.value === 'false') {
                  dispVal = (f.value === true || f.value === 'true') ? '<span class="badge badge-success">Yes</span>' : '<span class="badge badge-secondary">No</span>';
                }
                return `
                  <div>
                    <span class="text-muted d-block small" style="font-weight: 600;">${escapeHTML(f.label)}</span>
                    <strong style="color: var(--color-text-primary);">${dispVal}</strong>
                  </div>
                `;
              }).join('')}
            </div>
          </div>
        `).join('')}

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
      pModal.close();
      previewAdmissionFormPDF(student, { business: window.store?.settings?.businessProfile, receiptConfig: window.store?.settings?.receipt });
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
        const targetUrl = res.data.whatsappUrl || res.data.waUrl;
        if (targetUrl) {
          const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
          if (isMobile) {
            window.location.href = targetUrl;
          } else {
            const w = window.open(targetUrl, '_blank');
            if (!w) window.location.href = targetUrl;
          }
        }
        Toast.success(`WhatsApp reminder opened for ${res.data.studentName}!`);
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

    function renderAnalyticsUI(a) {
      if (!a) return;
      if (badgesEl) {
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
              ${a.totalDaysPresent || 0}/90 days present
            </div>
          </div>

          <!-- 90-Day Interactive Calendar Heatmap -->
          <div>
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
              <span class="text-xs font-weight-bold" style="color: var(--color-text-primary);">90-Day Attendance Heatmap</span>
              <span class="text-muted" style="font-size: 0.7rem;">Hover cell for daily duration</span>
            </div>
            ${renderHeatmapGridHtml(a.heatmap || [])}

            <div style="margin-top: 10px; padding: 8px 12px; background: var(--color-surface); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.8rem; line-height: 1.4; color: var(--color-text-secondary);">
              <strong>🤖 AI Insight:</strong> ${escapeHTML(a.aiRecommendation || a.aiStudyTip || 'Regular attendance observed.')}
            </div>
          </div>
        </div>
      `;
    }

    try {
      const cached = await IDBStorage.get('attendance', 'analytics_' + studentId);
      if (cached) renderAnalyticsUI(cached);
    } catch (e) {}

    try {
      const res = await api.get(`/api/attendance/analytics/${studentId}`);
      if (res.success && res.data) {
        await IDBStorage.set('attendance', 'analytics_' + studentId, res.data);
        renderAnalyticsUI(res.data);
      }
    } catch (err) {
      if (!contentEl.querySelector('svg')) {
        contentEl.innerHTML = `<div class="text-muted small text-center p-2">Unable to load attendance analytics (${escapeHTML(err.message || 'No records')})</div>`;
      }
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
    let business = window.store?.settings?.businessProfile || 
                   window.store?.profile || 
                   JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}') || 
                   { businessName: 'Study Library', tagline: 'Self Study & Reading Room', phone: '', address: '', logo: '', upiId: '' };
    
    // Background refresh if needed
    if (!business.businessName || business.businessName === 'Study Library') {
      api.get('/api/settings').then(bRes => {
        if (bRes?.success && bRes.data?.businessProfile) {
          business = { ...business, ...bRes.data.businessProfile };
        }
      }).catch(() => {});
    }

    const stampImgUrl = business.stampImage || business.stampImageUrl || window.store?.profile?.stampImage || window.store?.settings?.businessProfile?.stampImage || JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}')?.stampImage || '';
    const logoImgUrl = business.logo || business.logoUrl || window.store?.profile?.logo || window.store?.settings?.businessProfile?.logo || JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}')?.logo || '';
    const planName = student.plan?.name || 'Standard Access';
    const seatNumber = student.seat?.seatNumber || 'Floating / Open Desk';
    const shiftName = student.shift?.name || 'Full Day';
    const expiryDate = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : 'Active';
    const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : new Date().toLocaleDateString('en-IN');
    const phone = student.phone || '-';
    const emergencyName = student.emergencyContact?.name || 'Parent / Guardian';
    const emergencyPhone = student.emergencyContact?.phone || '-';
    const emergencyRelation = student.emergencyContact?.relation || 'Parent';
    const address = [student.address, student.city, student.state, student.pincode].filter(Boolean).join(', ') || 'Campus Residential';
    const bloodGroup = student.bloodGroup || '';
    const initials = (student.name || 'S').split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);

    // QR Code — encodes student verification
    const qrPayload = encodeURIComponent(JSON.stringify({
      id: student.studentId || 'STU-MEMBER',
      name: student.name,
      phone: student.phone,
      seat: seatNumber,
      validTill: expiryDate
    }));
    const qrCodeURL = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${qrPayload}&margin=2&bgcolor=ffffff`;

    // State for studio
    let currentOrientation = 'horizontal'; // 'horizontal' | 'vertical'
    let currentSide = 'dual'; // 'front' | 'back' | 'dual'
    let currentColor = '#4f46e5';
    let currentTheme = 'gradient';
    let showQr = true;
    let showBlood = Boolean(bloodGroup);
    let showEmergency = true;
    let showStamp = true;

    const modalContent = document.createElement('div');
    modalContent.className = 'id-card-studio-wrapper';
    modalContent.style.cssText = 'font-family: "Outfit", sans-serif; user-select: none;';

    const renderStudioUI = () => {
      const isHoriz = currentOrientation === 'horizontal';

      // Card Themes CSS map
      const getThemeStyles = (color, theme) => {
        if (theme === 'dark') {
          return {
            cardBg: 'linear-gradient(145deg, #1e2230 0%, #111420 100%)',
            textColor: '#f8fafc',
            subText: '#94a3b8',
            border: `2.5px solid ${color}`,
            outline: `1.5px dashed #475569`,
            headerBg: `linear-gradient(135deg, ${color}, #0f172a)`,
            footerBg: '#0f172a',
            badgeBg: 'rgba(255,255,255,0.1)',
            badgeColor: '#fff',
            cardShadow: `0 10px 28px rgba(0,0,0,0.5)`
          };
        }
        if (theme === 'minimal') {
          return {
            cardBg: '#ffffff',
            textColor: '#0f172a',
            subText: '#64748b',
            border: `2.5px solid #0f172a`,
            outline: `1.5px dashed #64748b`,
            headerBg: color,
            footerBg: '#f8fafc',
            badgeBg: `${color}18`,
            badgeColor: color,
            cardShadow: `0 8px 24px rgba(0,0,0,0.14)`
          };
        }
        if (theme === 'glass') {
          return {
            cardBg: 'linear-gradient(135deg, rgba(255,255,255,0.95), rgba(240,244,255,0.98))',
            textColor: '#0f172a',
            subText: '#475569',
            border: `2.5px solid #0f172a`,
            outline: `1.5px dashed #64748b`,
            headerBg: `linear-gradient(135deg, ${color}, ${color}cc)`,
            footerBg: '#f1f5f9',
            badgeBg: `${color}20`,
            badgeColor: color,
            cardShadow: `0 8px 24px rgba(15, 23, 42, 0.16)`
          };
        }
        // Default gradient
        return {
          cardBg: 'linear-gradient(145deg, #ffffff 60%, #f8faff 100%)',
          textColor: '#0f172a',
          subText: '#475569',
          border: `2.5px solid #0f172a`,
          outline: `1.5px dashed #64748b`,
          headerBg: `linear-gradient(135deg, ${color}, ${color}ee)`,
          footerBg: '#f8fafc',
          badgeBg: `${color}18`,
          badgeColor: color,
          cardShadow: `0 8px 24px rgba(15, 23, 42, 0.16)`
        };
      };

      // Generate Front Card HTML
      const renderFrontCard = (isV) => {
        const st = getThemeStyles(currentColor, currentTheme);
        if (isV) {
          // Vertical Front (CR80 Portrait: 254px x 400px)
          return `
            <div class="id-card-entity id-card-v id-card-front" style="
              width: 254px; min-height: 400px; height: 400px; background: ${st.cardBg}; color: ${st.textColor};
              border-radius: 12px; ${st.border}; outline: ${st.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${st.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Curved Banner -->
              <div style="background: ${st.headerBg}; color: #fff; padding: 10px 8px; text-align: center; position: relative;">
                <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
                  ${logoImgUrl ? `<img src="${logoImgUrl}" style="width: 22px; height: 22px; border-radius: 4px; object-fit: contain; background: #fff;">` : `<span style="font-size: 1.1rem;">📚</span>`}
                  <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 190px;">${escapeHTML(business.businessName || 'Study Library')}</div>
                </div>
                <div style="font-size: 0.62rem; opacity: 0.9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHTML(business.tagline || 'Student Membership Pass')}</div>
              </div>

              <!-- Center Avatar & Name -->
              <div style="display: flex; flex-direction: column; align-items: center; padding: 8px 10px 4px 10px; text-align: center;">
                <div style="width: 68px; height: 68px; border-radius: 12px; background: #eef2ff; border: 2.5px solid ${currentColor}; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; font-weight: 800; color: ${currentColor}; margin-bottom: 4px; box-shadow: 0 3px 10px rgba(0,0,0,0.1);">
                  ${student.photo ? `<img src="${student.photo}" style="width: 100%; height: 100%; object-fit: cover;">` : initials}
                </div>
                <div style="font-weight: 800; font-size: 0.88rem; line-height: 1.2; margin-bottom: 3px; color: ${st.textColor}; max-height: 2.4em; overflow: hidden; word-break: break-word;">${escapeHTML(student.name)}</div>
                <div style="display: flex; gap: 4px; align-items: center; justify-content: center; flex-wrap: wrap;">
                  <span style="background: ${st.badgeBg}; color: ${st.badgeColor}; padding: 1px 7px; border-radius: 4px; font-weight: 800; font-size: 0.68rem; font-family: monospace; letter-spacing: 0.5px;">${escapeHTML(student.studentId || 'STU-MEMBER')}</span>
                  ${showBlood && bloodGroup ? `<span style="background: rgba(220,38,38,0.12); color: #dc2626; font-size: 0.65rem; font-weight: 800; padding: 1px 5px; border-radius: 4px;">🩸 ${escapeHTML(bloodGroup)}</span>` : ''}
                </div>
              </div>

              <!-- Standardized Details Body -->
              <div style="padding: 6px 12px; font-size: 0.72rem; flex: 1; display: flex; flex-direction: column; gap: 3.5px; line-height: 1.35;">
                <div style="display: flex; justify-content: space-between;"><span style="color: ${st.subText}; font-weight: 600;">Desk / Seat:</span> <strong style="color: ${currentColor};">${escapeHTML(seatNumber)}</strong></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${st.subText}; font-weight: 600;">Shift Timing:</span> <span style="font-weight: 600;">${escapeHTML(shiftName)}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${st.subText}; font-weight: 600;">Membership:</span> <span>${escapeHTML(planName)}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${st.subText}; font-weight: 600;">Contact Phone:</span> <span>${escapeHTML(phone || '-')}</span></div>
                <div style="display: flex; justify-content: space-between;"><span style="color: ${st.subText}; font-weight: 600;">Valid Until:</span> <strong style="color: #dc2626; font-weight: 800;">${escapeHTML(expiryDate)}</strong></div>
              </div>

              <!-- Bottom QR / Footer -->
              <div style="background: ${st.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 5px 10px; display: flex; justify-content: space-between; align-items: center;">
                ${showQr ? `<img src="${qrCodeURL}" style="width: 44px; height: 44px; border-radius: 4px; border: 1px solid rgba(0,0,0,0.1); background: #fff;">` : '<div></div>'}
                <div style="text-align: right; font-size: 0.6rem; color: ${st.subText}; line-height: 1.3;">
                  <div style="font-weight: 800; color: ${currentColor}; letter-spacing: 0.5px;">STUDENT PASS</div>
                  <div style="font-weight: 600;">Issued: ${escapeHTML(admissionDate)}</div>
                  <div>${escapeHTML(business.phone || '')}</div>
                </div>
              </div>
            </div>
          `;
        } else {
          // Horizontal Front (CR80 Landscape: 380px x 240px)
          return `
            <div class="id-card-entity id-card-h id-card-front" style="
              width: 380px; min-height: 240px; height: 240px; background: ${st.cardBg}; color: ${st.textColor};
              border-radius: 12px; ${st.border}; outline: ${st.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${st.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${st.headerBg}; color: #fff; padding: 8px 12px; display: flex; align-items: center; justify-content: space-between; gap: 8px;">
                <div style="display: flex; align-items: center; gap: 8px; min-width: 0;">
                  ${logoImgUrl ? `<img src="${logoImgUrl}" style="width: 24px; height: 24px; border-radius: 4px; object-fit: contain; background: #fff; flex-shrink: 0;">` : `<span style="font-size: 1.1rem; flex-shrink: 0;">📚</span>`}
                  <div style="min-width: 0;">
                    <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.3px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHTML(business.businessName || 'Study Library')}</div>
                    <div style="font-size: 0.6rem; opacity: 0.88; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHTML(business.tagline || 'Student Membership Card')}</div>
                  </div>
                </div>
                <span style="font-size: 0.62rem; font-weight: 800; background: rgba(255,255,255,0.22); padding: 2px 6px; border-radius: 3px; letter-spacing: 0.5px; white-space: nowrap;">STUDENT ID PASS</span>
              </div>

              <!-- Body: Photo + Info Grid -->
              <div style="padding: 10px 12px; display: flex; gap: 12px; align-items: center; flex: 1;">
                <div style="display: flex; flex-direction: column; align-items: center; gap: 6px; flex-shrink: 0;">
                  <div style="width: 64px; height: 64px; border-radius: 10px; background: #eef2ff; border: 2px solid ${currentColor}; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 1.4rem; font-weight: 800; color: ${currentColor}; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
                    ${student.photo ? `<img src="${student.photo}" style="width: 100%; height: 100%; object-fit: cover;">` : initials}
                  </div>
                  ${showQr ? `<img src="${qrCodeURL}" style="width: 44px; height: 44px; border-radius: 4px; border: 1px solid rgba(0,0,0,0.1); background: #fff;">` : ''}
                </div>

                <div style="flex: 1; min-width: 0;">
                  <!-- Full Student Name (Auto wrapped, never truncated with ...) -->
                  <div style="font-weight: 800; font-size: 0.92rem; line-height: 1.2; margin-bottom: 2px; color: ${st.textColor}; word-break: break-word; max-height: 2.4em; overflow: hidden;">${escapeHTML(student.name)}</div>
                  
                  <div style="display: flex; gap: 4px; align-items: center; margin-bottom: 4px; flex-wrap: wrap;">
                    <span style="background: ${st.badgeBg}; color: ${st.badgeColor}; padding: 1px 6px; border-radius: 3px; font-weight: 800; font-size: 0.65rem; font-family: monospace;">${escapeHTML(student.studentId || 'STU-MEMBER')}</span>
                    ${showBlood && bloodGroup ? `<span style="background: rgba(220,38,38,0.12); color: #dc2626; font-size: 0.62rem; font-weight: 800; padding: 1px 5px; border-radius: 3px;">🩸 ${escapeHTML(bloodGroup)}</span>` : ''}
                  </div>

                  <!-- Standardized Details Grid matching Vertical card exactly -->
                  <div style="font-size: 0.70rem; display: grid; grid-template-columns: auto 1fr; row-gap: 2.5px; column-gap: 8px; line-height: 1.3;">
                    <span style="color: ${st.subText}; font-weight: 600;">Desk / Seat:</span><strong style="color: ${currentColor};">${escapeHTML(seatNumber)}</strong>
                    <span style="color: ${st.subText}; font-weight: 600;">Shift Timing:</span><span style="font-weight: 600;">${escapeHTML(shiftName)}</span>
                    <span style="color: ${st.subText}; font-weight: 600;">Membership:</span><span>${escapeHTML(planName)}</span>
                    <span style="color: ${st.subText}; font-weight: 600;">Contact Phone:</span><span>${escapeHTML(phone || '-')}</span>
                    <span style="color: ${st.subText}; font-weight: 600;">Valid Until:</span><strong style="color: #dc2626; font-weight: 800;">${escapeHTML(expiryDate)}</strong>
                  </div>
                </div>
              </div>

              <!-- Footer -->
              <div style="background: ${st.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 4px 12px; display: flex; justify-content: space-between; align-items: center; font-size: 0.62rem; color: ${st.subText};">
                <span>Issued: ${escapeHTML(admissionDate)}</span>
                <span style="font-weight: 700; letter-spacing: 0.5px;">NON-TRANSFERABLE</span>
                <span>${escapeHTML(business.phone || '')}</span>
              </div>
            </div>
          `;
        }
      };

      // Generate Back Card HTML
      const renderBackCard = (isV) => {
        const st = getThemeStyles(currentColor, currentTheme);
        if (isV) {
          // Vertical Back (CR80 Portrait: 254px x 400px)
          return `
            <div class="id-card-entity id-card-v id-card-back" style="
              width: 254px; min-height: 400px; height: 400px; background: ${st.cardBg}; color: ${st.textColor};
              border-radius: 12px; ${st.border}; outline: ${st.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${st.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${st.headerBg}; color: #fff; padding: 10px 8px; text-align: center;">
                <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.4px;">RULES &amp; EMERGENCY CONTACT</div>
                <div style="font-size: 0.62rem; opacity: 0.88; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHTML(business.businessName || 'Study Library')}</div>
              </div>

              <!-- Emergency & Address Box -->
              <div style="padding: 8px 12px; font-size: 0.72rem; flex: 1; display: flex; flex-direction: column; gap: 5px;">
                ${showEmergency ? `
                  <div style="background: ${st.badgeBg}; padding: 6px 8px; border-radius: 6px; border-left: 3px solid ${currentColor};">
                    <div style="font-weight: 800; color: ${currentColor}; font-size: 0.68rem; margin-bottom: 2px;">🚨 EMERGENCY CONTACT</div>
                    <div style="font-weight: 600; font-size: 0.68rem;">${escapeHTML(emergencyName)} (${escapeHTML(emergencyRelation)})</div>
                    <div style="font-family: monospace; font-weight: 700; font-size: 0.68rem;">📞 ${escapeHTML(emergencyPhone)}</div>
                  </div>
                ` : ''}

                <div style="font-size: 0.68rem; color: ${st.subText}; line-height: 1.35;">
                  <strong style="color: ${st.textColor};">📍 Resident Address:</strong> ${escapeHTML(address)}
                </div>

                <!-- Rules List -->
                <div style="border-top: 1px dashed rgba(0,0,0,0.08); padding-top: 5px;">
                  <div style="font-weight: 700; font-size: 0.68rem; color: ${st.textColor}; margin-bottom: 2px;">📖 Campus Regulations:</div>
                  <ul style="margin: 0; padding-left: 14px; font-size: 0.63rem; color: ${st.subText}; line-height: 1.35;">
                    <li>Card must be presented upon entry.</li>
                    <li>Strict pin-drop silence in reading hall.</li>
                    <li>Access restricted to allotted shift timing.</li>
                    <li>Renew membership before plan expiry date.</li>
                  </ul>
                </div>

                <!-- Stamp / Signatory -->
                ${showStamp ? `
                  <div style="margin-top: auto; display: flex; justify-content: space-between; align-items: flex-end; padding-top: 4px;">
                    <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                      ${stampImgUrl ? `
                        <img src="${stampImgUrl}" alt="Official Seal" style="max-height: 48px; max-width: 58px; object-fit: contain; margin-bottom: 2px; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.12));">
                      ` : `
                        <div style="border: 1.5px solid #059669; color: #059669; font-weight: 800; font-size: 0.58rem; padding: 2px 6px; border-radius: 4px; transform: rotate(-4deg); text-align: center;">
                          OFFICIAL SEAL<br>PAID &amp; VERIFIED
                        </div>
                      `}
                    </div>
                    <div style="text-align: center;">
                      <div style="width: 70px; border-bottom: 1px solid ${st.subText}; margin-bottom: 2px;"></div>
                      <div style="font-size: 0.58rem; color: ${st.subText}; font-weight: 600;">Auth. Signatory</div>
                    </div>
                  </div>
                ` : ''}
              </div>

              <!-- Footer -->
              <div style="background: ${st.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 5px 10px; text-align: center; font-size: 0.60rem; color: ${st.subText}; line-height: 1.3;">
                ${escapeHTML(business.phone ? `Helpline: ${business.phone}` : '')}${business.phone && business.address ? ' • ' : ''}${escapeHTML(business.address || '')}
              </div>
            </div>
          `;
        } else {
          // Horizontal Back (CR80 Landscape: 380px x 240px)
          return `
            <div class="id-card-entity id-card-h id-card-back" style="
              width: 380px; min-height: 240px; height: 240px; background: ${st.cardBg}; color: ${st.textColor};
              border-radius: 12px; ${st.border}; outline: ${st.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${st.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Banner -->
              <div style="background: ${st.headerBg}; color: #fff; padding: 7px 12px; display: flex; justify-content: space-between; align-items: center;">
                <span style="font-weight: 800; font-size: 0.82rem; letter-spacing: 0.3px;">RULES &amp; EMERGENCY CONTACT</span>
                <span style="font-size: 0.65rem; opacity: 0.9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; max-width: 170px;">${escapeHTML(business.businessName || 'Study Library')}</span>
              </div>

              <!-- Body: Emergency + Rules Grid -->
              <div style="padding: 8px 12px; font-size: 0.70rem; display: flex; gap: 10px; flex: 1;">
                <div style="flex: 1.3; display: flex; flex-direction: column; gap: 4px;">
                  ${showEmergency ? `
                    <div style="background: ${st.badgeBg}; padding: 4px 6px; border-radius: 4px; border-left: 3px solid ${currentColor}; font-size: 0.65rem;">
                      <div style="font-weight: 800; color: ${currentColor};">🚨 EMERGENCY CONTACT</div>
                      <div style="font-weight: 600;">${escapeHTML(emergencyName)} (${escapeHTML(emergencyRelation)}) • 📞 ${escapeHTML(emergencyPhone)}</div>
                    </div>
                  ` : ''}
                  
                  <div style="font-size: 0.64rem; color: ${st.subText}; line-height: 1.3;">
                    <strong style="color: ${st.textColor};">📍 Resident Address:</strong> ${escapeHTML(address)}
                  </div>
                  
                  <div style="border-top: 1px dashed rgba(0,0,0,0.08); padding-top: 3px;">
                    <div style="font-weight: 700; font-size: 0.64rem; color: ${st.textColor}; margin-bottom: 2px;">📖 Campus Regulations:</div>
                    <ul style="margin: 0; padding-left: 12px; font-size: 0.60rem; color: ${st.subText}; line-height: 1.3;">
                      <li>Card must be presented upon entry.</li>
                      <li>Strict pin-drop silence in reading hall.</li>
                      <li>Access restricted to allotted shift timing.</li>
                      <li>Renew membership before expiry date.</li>
                    </ul>
                  </div>
                </div>

                <div style="flex: 0.7; display: flex; flex-direction: column; justify-content: space-between; align-items: center; text-align: center; border-left: 1px dashed rgba(0,0,0,0.1); padding-left: 8px;">
                  ${showStamp ? `
                    <div style="text-align: center; display: flex; flex-direction: column; align-items: center;">
                      ${stampImgUrl ? `
                        <img src="${stampImgUrl}" alt="Official Seal" style="max-height: 52px; max-width: 65px; object-fit: contain; margin-top: 2px; margin-bottom: 2px; filter: drop-shadow(0 1px 2px rgba(0,0,0,0.12));">
                      ` : `
                        <div style="border: 1.5px solid #059669; color: #059669; font-weight: 800; font-size: 0.58rem; padding: 3px 6px; border-radius: 4px; transform: rotate(-4deg); margin-top: 6px;">
                          OFFICIAL SEAL<br>PAID &amp; VERIFIED
                        </div>
                      `}
                    </div>
                    <div style="margin-top: auto; padding-bottom: 2px;">
                      <div style="width: 70px; border-bottom: 1px solid ${st.subText}; margin-bottom: 2px; margin-left: auto; margin-right: auto;"></div>
                      <div style="font-size: 0.56rem; color: ${st.subText}; font-weight: 600;">Auth. Signatory</div>
                    </div>
                  ` : ''}
                </div>
              </div>

              <!-- Footer with No Text Overlap -->
              <div style="background: ${st.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 4px 12px; text-align: center; font-size: 0.60rem; color: ${st.subText}; line-height: 1.3;">
                ${escapeHTML(business.phone ? `Helpline: ${business.phone}` : '')}${business.phone && business.address ? ' • ' : ''}${escapeHTML(business.address || '')}
              </div>
            </div>
          `;
        }
      };

      // Preview Grid Container based on currentSide & orientation
      let previewHtml = '';
      const isVertical = currentOrientation === 'vertical';
      const cardHeight = isVertical ? '400px' : '240px';

      if (currentSide === 'front') {
        previewHtml = `
          <div style="display: flex; justify-content: center; align-items: center; padding: 6px 0;">
            ${renderFrontCard(isVertical)}
          </div>
        `;
      } else if (currentSide === 'back') {
        previewHtml = `
          <div style="display: flex; justify-content: center; align-items: center; padding: 6px 0;">
            ${renderBackCard(isVertical)}
          </div>
        `;
      } else {
        // Dual side side-by-side
        previewHtml = `
          <div id="dual-print-container" style="
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 20px;
            padding: 8px 4px;
            box-sizing: border-box;
            min-width: min-content;
            margin: 0 auto;
          ">
            <!-- Front Column -->
            <div style="display: flex; flex-direction: column; align-items: center; flex-shrink: 0;">
              <div style="font-size: 0.75rem; font-weight: 800; text-align: center; margin-bottom: 6px; color: var(--color-primary); letter-spacing: 0.5px;">🪪 FRONT SIDE</div>
              ${renderFrontCard(isVertical)}
            </div>

            <!-- Perfectly Centered Vertical Fold / Cut Line -->
            <div class="id-cut-separator" style="
              display: flex;
              flex-direction: column;
              align-items: center;
              justify-content: center;
              position: relative;
              height: ${cardHeight};
              width: 36px;
              flex-shrink: 0;
            ">
              <div style="position: absolute; top: 0; bottom: 0; left: 50%; border-left: 2px dashed rgba(99, 102, 241, 0.45); transform: translateX(-50%);"></div>
              <span style="
                position: relative;
                background: var(--color-surface, #1e2230);
                border: 1.5px solid var(--color-border, #374151);
                border-radius: 20px;
                padding: 4px 8px;
                font-size: 0.85rem;
                box-shadow: 0 2px 8px rgba(0,0,0,0.25);
                display: flex;
                align-items: center;
                justify-content: center;
                z-index: 2;
              ">
                ✂️
              </span>
            </div>

            <!-- Back Column -->
            <div style="display: flex; flex-direction: column; align-items: center; flex-shrink: 0;">
              <div style="font-size: 0.75rem; font-weight: 800; text-align: center; margin-bottom: 6px; color: var(--color-primary); letter-spacing: 0.5px;">📄 BACK SIDE</div>
              ${renderBackCard(isVertical)}
            </div>
          </div>
        `;
      }

      modalContent.innerHTML = `
        <div style="display: flex; flex-direction: column; gap: 16px;">
          <!-- Top Studio Toolbar -->
          <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
              <!-- Orientation Toggle -->
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary);">Orientation:</span>
                <div class="btn-group btn-group-sm" role="group">
                  <button type="button" class="btn ${currentOrientation === 'horizontal' ? 'btn-primary' : 'btn-outline-secondary'} btn-opt-horiz" style="font-weight: 700;">
                    💳 Landscape (CR80)
                  </button>
                  <button type="button" class="btn ${currentOrientation === 'vertical' ? 'btn-primary' : 'btn-outline-secondary'} btn-opt-vert" style="font-weight: 700;">
                    🪪 Portrait (CR80)
                  </button>
                </div>
              </div>

              <!-- Side Toggle -->
              <div style="display: flex; align-items: center; gap: 6px;">
                <span style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary);">View:</span>
                <div class="btn-group btn-group-sm" role="group">
                  <button type="button" class="btn ${currentSide === 'front' ? 'btn-primary' : 'btn-outline-secondary'} btn-side-front" style="font-weight: 700;">Front</button>
                  <button type="button" class="btn ${currentSide === 'back' ? 'btn-primary' : 'btn-outline-secondary'} btn-side-back" style="font-weight: 700;">Back</button>
                  <button type="button" class="btn ${currentSide === 'dual' ? 'btn-primary' : 'btn-outline-secondary'} btn-side-dual" style="font-weight: 700;">Both Sides</button>
                </div>
              </div>

              <!-- Color & Theme Picker -->
              <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
                <div style="display: flex; align-items: center; gap: 6px;">
                  <label for="id-studio-color" style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary); margin: 0;">Accent:</label>
                  <input type="color" id="id-studio-color" value="${currentColor}" style="width: 32px; height: 32px; border-radius: 6px; border: 1px solid var(--color-border); cursor: pointer; padding: 2px;">
                </div>

                <div style="display: flex; align-items: center; gap: 6px;">
                  <label for="id-studio-theme" style="font-weight: 700; font-size: 0.82rem; color: var(--color-text-secondary); margin: 0;">Theme:</label>
                  <select id="id-studio-theme" class="form-select form-select-sm" style="font-weight: 600; width: auto;">
                    <option value="gradient" ${currentTheme === 'gradient' ? 'selected' : ''}>✨ Executive Vibrant</option>
                    <option value="dark" ${currentTheme === 'dark' ? 'selected' : ''}>⚫ Dark Slate Pro</option>
                    <option value="minimal" ${currentTheme === 'minimal' ? 'selected' : ''}>⚪ Minimal Classic</option>
                    <option value="glass" ${currentTheme === 'glass' ? 'selected' : ''}>💎 Frosted Glass</option>
                  </select>
                </div>
              </div>
            </div>
          </div>

          <!-- Studio Render Canvas Area -->
          <div id="id-card-render-stage" style="padding: 14px 10px; display: flex; justify-content: center; align-items: center; background: radial-gradient(circle, rgba(108,92,231,0.06) 0%, transparent 70%); border-radius: var(--radius-md); overflow-x: auto; width: 100%; box-sizing: border-box;">
            ${previewHtml}
          </div>

          <!-- Bottom Action Buttons Grid -->
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; border-top: 1px solid var(--color-border); padding-top: 12px;">
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
              <button type="button" class="btn btn-primary btn-sm" id="btn-download-front-png" style="font-weight: 700;">
                📥 Download Front
              </button>
              <button type="button" class="btn btn-outline-primary btn-sm" id="btn-download-back-png" style="font-weight: 700;">
                📥 Download Back
              </button>
              <button type="button" class="btn btn-outline-info btn-sm" id="btn-download-1080p-pass" style="font-weight: 700;">
                📱 1080p Wallpaper Pass
              </button>
            </div>

            <div style="display: flex; gap: 8px; align-items: center;">
              <button type="button" class="btn btn-success btn-sm" id="btn-print-admin-id-card" style="font-weight: 800; padding: 6px 18px;">
                🖨️ Print ID Card (Front + Back)
              </button>
              <button type="button" class="btn btn-secondary btn-sm" id="btn-close-admin-id-studio">Close</button>
            </div>
          </div>
        </div>

        <style>
          .id-card-entity {
            box-sizing: border-box !important;
            transition: all 0.2s ease;
          }
          @media print {
            body * { visibility: hidden !important; }
            #id-card-render-stage, #id-card-render-stage * { visibility: visible !important; }
            #id-card-render-stage {
              position: fixed !important;
              left: 50% !important;
              top: 40px !important;
              transform: translateX(-50%) !important;
              width: 100% !important;
              box-shadow: none !important;
              background: none !important;
              padding: 0 !important;
              margin: 0 !important;
              overflow: visible !important;
            }
            #dual-print-container {
              display: flex !important;
              flex-direction: row !important;
              align-items: center !important;
              justify-content: center !important;
              gap: 36px !important;
              flex-wrap: nowrap !important;
            }
            .id-cut-separator {
              display: flex !important;
            }
            .id-card-entity {
              box-shadow: none !important;
              break-inside: avoid !important;
              page-break-inside: avoid !important;
            }
          }
        </style>
      `;

      // Wire up orientation buttons
      modalContent.querySelector('.btn-opt-horiz')?.addEventListener('click', () => {
        currentOrientation = 'horizontal';
        renderStudioUI();
      });
      modalContent.querySelector('.btn-opt-vert')?.addEventListener('click', () => {
        currentOrientation = 'vertical';
        renderStudioUI();
      });

      // Wire up side buttons
      modalContent.querySelector('.btn-side-front')?.addEventListener('click', () => {
        currentSide = 'front';
        renderStudioUI();
      });
      modalContent.querySelector('.btn-side-back')?.addEventListener('click', () => {
        currentSide = 'back';
        renderStudioUI();
      });
      modalContent.querySelector('.btn-side-dual')?.addEventListener('click', () => {
        currentSide = 'dual';
        renderStudioUI();
      });

      // Wire up Color Theme Pickers
      modalContent.querySelector('#id-studio-color')?.addEventListener('input', (e) => {
        currentColor = e.target.value;
        renderStudioUI();
      });
      modalContent.querySelector('#id-studio-theme-select')?.addEventListener('change', (e) => {
        currentTheme = e.target.value;
        renderStudioUI();
      });

      // Wire up Feature Toggles
      modalContent.querySelector('#toggle-id-qr')?.addEventListener('change', (e) => {
        showQr = e.target.checked;
        renderStudioUI();
      });
      modalContent.querySelector('#toggle-id-blood')?.addEventListener('change', (e) => {
        showBlood = e.target.checked;
        renderStudioUI();
      });
      modalContent.querySelector('#toggle-id-emergency')?.addEventListener('change', (e) => {
        showEmergency = e.target.checked;
        renderStudioUI();
      });
      modalContent.querySelector('#toggle-id-stamp')?.addEventListener('change', (e) => {
        showStamp = e.target.checked;
        renderStudioUI();
      });

      // Wire up Close Button
      modalContent.querySelector('#btn-close-id-studio')?.addEventListener('click', () => {
        idModal.close();
      });

      // Wire up Native Print Action
      modalContent.querySelector('#btn-print-id-card')?.addEventListener('click', () => {
        if (currentSide !== 'dual') {
          currentSide = 'dual';
          renderStudioUI();
        }
        setTimeout(() => {
          window.print();
        }, 300);
      });

      // Wire up Single-Side PNG Downloads
      const downloadElementAsPng = async (targetSelector, filename) => {
        try {
          if (!window.html2canvas) {
            await new Promise((res, rej) => {
              const s = document.createElement('script');
              s.src = 'https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js';
              s.onload = res;
              s.onerror = rej;
              document.head.appendChild(s);
            });
          }
          const el = modalContent.querySelector(targetSelector);
          if (!el) {
            Toast.warning('Please switch to the selected side first.');
            return;
          }
          const canvas = await window.html2canvas(el, { scale: 3, useCORS: true, backgroundColor: null });
          const link = document.createElement('a');
          link.download = filename;
          link.href = canvas.toDataURL('image/png');
          link.click();
          Toast.success('ID Card downloaded successfully!');
        } catch (err) {
          Toast.error('PNG download error: ' + err.message);
        }
      };

      // Download Buttons
      modalContent.querySelector('#btn-download-front-png')?.addEventListener('click', () => {
        const studentClean = (student.studentId || student.name || 'student').replace(/\s+/g, '_');
        downloadElementAsPng('.id-card-front', `ID_Front_${studentClean}.png`);
      });

      modalContent.querySelector('#btn-download-back-png')?.addEventListener('click', () => {
        const studentClean = (student.studentId || student.name || 'student').replace(/\s+/g, '_');
        downloadElementAsPng('.id-card-back', `ID_Back_${studentClean}.png`);
      });

      modalContent.querySelector('#btn-download-dual-png')?.addEventListener('click', () => {
        const studentClean = (student.studentId || student.name || 'student').replace(/\s+/g, '_');
        downloadElementAsPng('#id-card-render-stage', `ID_Dual_${studentClean}.png`);
      });
    };

    renderStudioUI();

    const idModal = new Modal({
      title: `🪪 Student ID Card Studio: ${escapeHTML(student.name)}`,
      content: modalContent,
      size: 'xl'
    });
    idModal.show();
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
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 14px; display: flex; flex-direction: column; gap: 10px;">
          <label style="font-weight: 700; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
            <input type="checkbox" id="reset-toggle-wa" class="form-toggle" checked> 📲 Open Pre-filled WhatsApp Credential Link
          </label>
          <label style="font-weight: 700; font-size: 0.85rem; display: flex; align-items: center; gap: 8px; cursor: pointer; margin: 0;">
            <input type="checkbox" id="reset-toggle-email" class="form-toggle" ${student.email ? 'checked' : ''}> 📧 Send Credentials Notification via Email
          </label>
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
          return true;
        } else {
          Toast.error(res.message || 'Failed to update password');
          return false;
        }
      } catch (err) {
        Toast.error(err.message || 'Password update failed');
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
          onClick: () => {
            showStudentForm();
          }
        },
        {
          icon: '⏳',
          label: 'Waiting List',
          onClick: () => {
            window.location.hash = '#/operations';
          }
        },
        {
          icon: '📤',
          label: 'Export Students',
          onClick: () => {
            const list = state.students || [];
            if (list.length === 0) {
              Toast.info('No students loaded to export');
              return;
            }
            const headers = ['Student ID', 'Full Name', 'Phone', 'Email', 'Plan', 'Seat', 'Blood Group', 'Gender', 'Status', 'Expiry Date'];
            const rows = list.map(s => [
              `"${s.studentId || ''}"`,
              `"${(s.name || '').replace(/"/g, '""')}"`,
              `"${s.phone || ''}"`,
              `"${s.email || ''}"`,
              `"${s.plan?.name || ''}"`,
              `"${s.seat?.seatNumber || ''}"`,
              `"${s.bloodGroup || ''}"`,
              `"${s.gender || ''}"`,
              `"${s.status || ''}"`,
              `"${s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : ''}"`
            ]);
            const csv = '\uFEFF' + [headers.join(','), ...rows.map(r => r.join(','))].join('\r\n');
            const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `students_export_${new Date().toISOString().split('T')[0]}.csv`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            Toast.success(`Exported ${list.length} student(s) to CSV`);
          }
        },
        {
          icon: '🔍',
          label: 'Search Student',
          onClick: () => {
            const searchInput = container.querySelector('#studentSearch') || document.querySelector('#studentSearch');
            if (searchInput) {
              searchInput.focus();
              searchInput.scrollIntoView({ behavior: 'smooth' });
            }
          }
        }
      ]
    });
  }

  return container;
}
