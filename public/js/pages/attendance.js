import { App } from '../app.js';
import { t } from '../i18n.js';
import { Toast, Modal, Loading, Confirm, escapeHTML, debounce } from '../ui.js';
import api from '../api.js';

let refreshInterval;

export function render() {
  const container = document.createElement('div');
  container.className = 'page-container attendance-page';
  
  container.innerHTML = `
    <div class="page-header d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3">
      <div>
        <h2 style="margin: 0; font-size: 1.5rem; font-weight: 700;">📋 Attendance Tracking</h2>
        <p class="text-muted small mb-0" style="margin-top: 4px;">Daily check-in / check-out logs and occupancy tracking.</p>
      </div>
      <div class="actions d-flex align-items-center gap-2 flex-wrap">
        <button id="btn-biometric-simulator" class="btn btn-outline-primary btn-sm" style="font-weight: 600;">
          🏷️ Biometric / RFID Turnstile
        </button>
        <label for="attendance-date" class="text-muted small" style="margin: 0;">Date:</label>
        <input type="date" id="attendance-date" class="form-control" style="width: auto;" value="${new Date().toISOString().split('T')[0]}">
      </div>
    </div>

    <!-- Stats Grid -->
    <div class="stats-grid mb-4" id="attendance-stats" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem;">
      <div class="stat-card card p-3" style="border-left: 4px solid var(--color-success, #00b894);">
        <div class="text-muted small">Present Today</div>
        <h3 id="stat-present" style="margin: 4px 0 0 0; font-size: 1.6rem; font-weight: 700; color: var(--color-success, #00b894);">-</h3>
      </div>
      <div class="stat-card card p-3" style="border-left: 4px solid var(--color-primary, #6c5ce7);">
        <div class="text-muted small">Currently Checked In</div>
        <h3 id="stat-current" style="margin: 4px 0 0 0; font-size: 1.6rem; font-weight: 700; color: var(--color-primary, #6c5ce7);">-</h3>
      </div>
      <div class="stat-card card p-3" style="border-left: 4px solid var(--color-info, #0984e3);">
        <div class="text-muted small">Total Logs Today</div>
        <h3 id="stat-total" style="margin: 4px 0 0 0; font-size: 1.6rem; font-weight: 700; color: var(--color-info, #0984e3);">-</h3>
      </div>
    </div>

    <!-- Quick Check-in -->
    <div class="card mb-4">
      <div class="card-header">
        <h5 style="margin: 0; font-size: 1.1rem; font-weight: 600;">⚡ Quick Student Check-In</h5>
      </div>
      <div class="card-body">
        <div class="search-container" style="position: relative;">
          <input type="text" id="student-search" class="form-control form-control-lg" placeholder="Type student name or phone number to check in..." autocomplete="off">
          <div id="search-results" class="search-results dropdown-menu" style="display: none; position: absolute; width: 100%; z-index: 1000; background: var(--color-surface, #1e2230); border: 1px solid var(--color-border, #333); border-radius: 8px; max-height: 240px; overflow-y: auto; box-shadow: var(--shadow-lg);"></div>
        </div>
      </div>
    </div>

    <!-- Today's Log -->
    <div class="card">
      <div class="card-header d-flex justify-content-between align-items-center">
        <h5 style="margin: 0; font-size: 1.1rem; font-weight: 600;">📋 Attendance Log</h5>
        <button id="refreshAttendanceBtn" class="btn btn-sm btn-outline-secondary">Refresh</button>
      </div>
      <div class="card-body p-0">
        <div class="table-responsive">
          <table class="table data-table mb-0">
            <thead>
              <tr>
                <th>Student ID</th>
                <th>Name</th>
                <th>Check In</th>
                <th>Check Out</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody id="attendance-list">
              <tr><td colspan="7" class="text-center p-4">Loading attendance...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  setTimeout(() => init(container), 0);
  
  return container;
}

async function init(container) {
  const dateInput = container.querySelector('#attendance-date');
  const searchInput = container.querySelector('#student-search');
  const searchResults = container.querySelector('#search-results');
  const refreshBtn = container.querySelector('#refreshAttendanceBtn');
  
  if (dateInput) {
    dateInput.addEventListener('change', () => loadData(dateInput.value));
  }
  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => loadData(dateInput.value));
  }
  
  if (searchInput) {
    searchInput.addEventListener('input', debounce((e) => {
      const query = e.target.value.trim();
      if (query.length < 2) {
        searchResults.style.display = 'none';
        return;
      }
      searchStudents(query, searchResults);
    }, 250));
  }

  // Hide search results when clicking outside
  document.addEventListener('click', (e) => {
    if (searchInput && searchResults && !searchInput.contains(e.target) && !searchResults.contains(e.target)) {
      searchResults.style.display = 'none';
    }
  });

  // Hardware Biometric / RFID Scanner Modal
  container.querySelector('#btn-biometric-simulator')?.addEventListener('click', () => {
    const modalDiv = document.createElement('div');
    modalDiv.innerHTML = `
      <div class="p-2 text-center">
        <div style="font-size: 2.8rem; margin-bottom: 8px;">🚪</div>
        <h4 style="margin: 0 0 4px 0; font-weight: 700;">Smart Turnstile & Biometric Scanner</h4>
        <p class="text-muted small" style="margin-bottom: 1.25rem;">
          Swipe an RFID Smart Card, scan fingerprint ID, or enter Student ID.
        </p>

        <form id="biometricSyncForm">
          <div class="form-group mb-3">
            <input type="text" id="bioCardInput" class="form-control form-control-lg text-center" 
              placeholder="Swipe Card or Enter UID (e.g. STU-2026-001)" 
              style="font-size: 1.1rem; font-family: monospace; letter-spacing: 1px;" autofocus required>
          </div>
          <button type="submit" class="btn btn-primary w-full" style="font-weight: 700; padding: 0.65rem;">
            ⚡ Trigger Gate Relay / Attendance Punch
          </button>
        </form>

        <div id="gateRelayStatus" class="mt-3 p-3 text-center" style="display: none; border-radius: 8px;"></div>
      </div>
    `;

    const bioModal = new Modal({
      title: '🏷️ Turnstile & Biometric Sync',
      content: modalDiv,
      size: 'sm'
    });
    bioModal.show();

    setTimeout(() => modalDiv.querySelector('#bioCardInput')?.focus(), 200);

    const bForm = modalDiv.querySelector('#biometricSyncForm');
    const bInput = modalDiv.querySelector('#bioCardInput');
    const statusDiv = modalDiv.querySelector('#gateRelayStatus');

    bForm?.addEventListener('submit', async (e) => {
      e.preventDefault();
      const val = bInput.value.trim();
      if (!val) return;

      statusDiv.style.display = 'block';
      statusDiv.className = 'mt-3 p-3 text-center';
      statusDiv.style.background = 'var(--color-surface-hover)';
      statusDiv.innerHTML = '<div class="loading-spinner mb-1"></div> Communicating with Gate Controller...';

      try {
        const res = await api.post('/api/attendance/biometric', {
          studentId: val,
          rfidCardNumber: val,
          biometricId: val
        });

        if (res.success && res.accessGranted) {
          statusDiv.style.background = 'rgba(0, 184, 148, 0.15)';
          statusDiv.style.border = '1px solid var(--color-success)';
          statusDiv.innerHTML = `
            <div style="font-size: 1.6rem; color: var(--color-success); margin-bottom: 4px;">🟢 ACCESS GRANTED</div>
            <strong style="font-size: 1rem; color: var(--color-text-primary);">${escapeHTML(res.studentName)}</strong>
            <div style="font-size: 0.85rem; color: var(--color-text-secondary); margin-top: 2px;">
              Desk: <strong>${escapeHTML(res.seatNumber)}</strong> • Action: <strong>${res.action === 'check_in' ? 'Check-In' : 'Check-Out'}</strong> at ${res.time}
            </div>
            <div style="font-size: 0.75rem; color: var(--color-success); margin-top: 4px;">⚡ Turnstile Relay: UNLOCKED (3s)</div>
          `;
          bInput.value = '';
          bInput.focus();
          if (dateInput) loadData(dateInput.value, false);
        } else {
          statusDiv.style.background = 'rgba(214, 48, 49, 0.15)';
          statusDiv.style.border = '1px solid var(--color-danger)';
          statusDiv.innerHTML = `
            <div style="font-size: 1.6rem; color: var(--color-danger); margin-bottom: 4px;">🔴 ACCESS DENIED</div>
            <div style="font-size: 0.85rem; color: var(--color-danger);">${escapeHTML(res.message || 'Card invalid or expired')}</div>
          `;
        }
      } catch (err) {
        statusDiv.style.background = 'rgba(214, 48, 49, 0.15)';
        statusDiv.style.border = '1px solid var(--color-danger)';
        statusDiv.innerHTML = `<div style="color: var(--color-danger); font-size: 0.85rem;">🔴 ${escapeHTML(err.message || 'Hardware sync error')}</div>`;
      }
    });
  });

  if (dateInput) {
    await loadData(dateInput.value);
  }
  
  // Auto-refresh every 60 seconds
  if (refreshInterval) clearInterval(refreshInterval);
  refreshInterval = setInterval(() => {
    const curDateInput = document.querySelector('#attendance-date');
    if (curDateInput) {
      loadData(curDateInput.value, false);
    } else {
      clearInterval(refreshInterval);
    }
  }, 60000);
}

async function loadData(dateStr, showLoading = true) {
  const tbody = document.querySelector('#attendance-list');
  if (showLoading && tbody) Loading.skeleton(tbody, 'table');

  try {
    const isToday = dateStr === new Date().toISOString().split('T')[0];
    let res;
    
    if (isToday) {
      res = await api.get('/api/attendance/today');
    } else {
      res = await api.get(`/api/attendance?date=${dateStr}`);
    }

    if (!res.success) throw new Error(res.message);

    const records = res.data.records || [];
    const stats = isToday ? res.data.stats : null;

    updateStats(stats, records.length);
    renderTable(records, isToday);

  } catch (err) {
    Toast.error('Failed to load attendance: ' + (err.message || 'Error'));
    if (tbody) tbody.innerHTML = '<tr><td colspan="7" class="text-center empty-state p-4 text-muted">Error loading attendance data</td></tr>';
  }
}

function updateStats(stats, totalRecords) {
  const statPresent = document.querySelector('#stat-present');
  const statCurrent = document.querySelector('#stat-current');
  const statTotal = document.querySelector('#stat-total');

  if (statPresent) statPresent.textContent = stats ? (stats.totalPresent || 0) : '-';
  if (statCurrent) statCurrent.textContent = stats ? (stats.currentlyCheckedIn || 0) : '-';
  if (statTotal) statTotal.textContent = totalRecords;
}

function renderTable(records, isToday) {
  const tbody = document.querySelector('#attendance-list');
  if (!tbody) return;
  
  if (!records || records.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="text-center empty-state p-4 text-muted">No attendance records found for this date.</td></tr>';
    return;
  }

  tbody.innerHTML = records.map(record => {
    const student = record.student || {};
    const checkInTime = record.checkIn ? new Date(record.checkIn).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : '-';
    const checkOutTime = record.checkOut ? new Date(record.checkOut).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) : '-';
    
    let statusBadge = '';
    if (record.status === 'present') statusBadge = '<span class="badge" style="background: rgba(0, 184, 148, 0.2); color: var(--color-success, #00b894); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Present</span>';
    else if (record.status === 'absent') statusBadge = '<span class="badge" style="background: rgba(214, 48, 49, 0.2); color: var(--color-danger, #d63031); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Absent</span>';
    else if (record.status === 'late') statusBadge = '<span class="badge" style="background: rgba(253, 203, 110, 0.2); color: var(--color-warning, #fdcb6e); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Late</span>';
    else if (record.status === 'half_day') statusBadge = '<span class="badge" style="background: rgba(9, 132, 227, 0.2); color: var(--color-info, #0984e3); padding: 4px 8px; border-radius: 4px; font-weight: 600;">Half Day</span>';

    let actionBtn = '-';
    if (isToday && record.checkIn && !record.checkOut) {
      actionBtn = `<button class="btn btn-sm btn-outline-primary btn-checkout" data-id="${student._id || ''}" style="cursor: pointer; padding: 3px 8px; font-size: 0.75rem;">Check Out</button>`;
    }

    return `
      <tr>
        <td><span style="font-family: monospace; font-weight: 600;">${escapeHTML(student.studentId || '-')}</span></td>
        <td><strong>${escapeHTML(student.name || 'Unknown')}</strong></td>
        <td>${checkInTime}</td>
        <td>${checkOutTime}</td>
        <td>${record.duration !== undefined && record.duration !== null ? record.duration + ' min' : '-'}</td>
        <td>${statusBadge}</td>
        <td>${actionBtn}</td>
      </tr>
    `;
  }).join('');

  tbody.querySelectorAll('.btn-checkout').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      if (id) window.checkoutStudent(id);
    });
  });
}

async function searchStudents(query, resultsContainer) {
  try {
    const res = await api.get(`/api/students?search=${encodeURIComponent(query)}&limit=8`);
    if (res.success && res.data.students && res.data.students.length > 0) {
      resultsContainer.innerHTML = res.data.students.map(s => `
        <div class="search-result-item" style="padding: 10px 14px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.05)); cursor: pointer; display: flex; justify-content: space-between; align-items: center;" data-id="${s._id}" data-name="${escapeHTML(s.name)}">
          <div>
            <strong>${escapeHTML(s.name)}</strong>
            <span class="text-muted small" style="margin-left: 8px;">(${escapeHTML(s.studentId || s.phone || '')})</span>
          </div>
          <span class="badge" style="background: var(--color-primary, #6c5ce7); color: white; padding: 2px 6px; font-size: 0.7rem;">Check In</span>
        </div>
      `).join('');
      resultsContainer.style.display = 'block';

      resultsContainer.querySelectorAll('.search-result-item').forEach(item => {
        item.addEventListener('click', () => {
          const id = item.getAttribute('data-id');
          const name = item.getAttribute('data-name');
          window.checkinStudent(id, name);
        });
      });
    } else {
      resultsContainer.innerHTML = '<div style="padding: 12px; text-align: center;" class="text-muted">No students found</div>';
      resultsContainer.style.display = 'block';
    }
  } catch (err) {
    console.error('Search error', err);
  }
}

// Global functions for inline event handlers
window.checkinStudent = async (studentId, name) => {
  const searchInput = document.querySelector('#student-search');
  const searchResults = document.querySelector('#search-results');
  if (searchInput) searchInput.value = '';
  if (searchResults) searchResults.style.display = 'none';
  
  try {
    const res = await api.post('/api/attendance/check-in', { studentId });
    if (res.success) {
      Toast.success(`Checked in ${name || 'student'}`);
      const dateInput = document.querySelector('#attendance-date');
      if (dateInput) loadData(dateInput.value, false);
    } else {
      Toast.error(res.message);
    }
  } catch (err) {
    Toast.error(err.message || 'Check-in failed');
  }
};

window.checkoutStudent = async (studentId) => {
  try {
    const res = await api.post('/api/attendance/check-out', { studentId });
    if (res.success) {
      Toast.success('Successfully checked out');
      const dateInput = document.querySelector('#attendance-date');
      if (dateInput) loadData(dateInput.value, false);
    } else {
      Toast.error(res.message);
    }
  } catch (err) {
    Toast.error(err.message || 'Check-out failed');
  }
};
