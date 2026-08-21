import api from '../api.js';
import { t } from '../i18n.js';
import { Modal, Confirm, Toast, Loading, escapeHTML } from '../ui.js';

let shifts = [];
let stats = {
  total: 0,
  active: 0,
  inactive: 0,
  fullDay: 0,
  totalEnrolled: 0,
  studentEnrollment: {},
  shiftStats: []
};
let activeFilter = 'all';
let searchQuery = '';

const ALL_DAYS = [
  { key: 'mon', label: 'Mon', full: 'Monday' },
  { key: 'tue', label: 'Tue', full: 'Tuesday' },
  { key: 'wed', label: 'Wed', full: 'Wednesday' },
  { key: 'thu', label: 'Thu', full: 'Thursday' },
  { key: 'fri', label: 'Fri', full: 'Friday' },
  { key: 'sat', label: 'Sat', full: 'Saturday' },
  { key: 'sun', label: 'Sun', full: 'Sunday' }
];

/**
 * Format HH:mm string to 12-hour AM/PM format
 */
function formatTime12(time24) {
  if (!time24) return '';
  const parts = time24.split(':');
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1] || '0', 10);
  if (isNaN(h)) return time24;
  const period = h >= 12 ? 'PM' : 'AM';
  const hour12 = h % 12 || 12;
  return `${hour12.toString().padStart(2, '0')}:${m.toString().padStart(2, '0')} ${period}`;
}

/**
 * Calculate duration between start and end time (handles overnight)
 */
function calculateDuration(startTime, endTime) {
  if (!startTime || !endTime) return '';
  const [h1, m1] = startTime.split(':').map(Number);
  const [h2, m2] = endTime.split(':').map(Number);
  let startMinutes = h1 * 60 + m1;
  let endMinutes = h2 * 60 + m2;
  if (endMinutes <= startMinutes) {
    endMinutes += 24 * 60; // Overnight shift
  }
  const diff = endMinutes - startMinutes;
  const hours = Math.floor(diff / 60);
  const mins = diff % 60;
  if (mins === 0) return `${hours} hrs`;
  return `${hours}h ${mins}m`;
}

/**
 * Main render function for Shifts Management
 */
export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';

  container.innerHTML = `
    <!-- Header -->
    <div class="page-header d-flex justify-content-between align-items-center mb-4 flex-wrap gap-3" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem; flex-wrap: wrap; gap: 1rem;">
      <div>
        <h2 style="margin: 0; font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary);">${t('Shift Management')}</h2>
        <p class="text-muted small mb-0" style="margin-top: 4px; color: var(--color-text-secondary); font-size: 0.9rem;">
          Configure study library operating shifts, daily schedules, capacities, and rates.
        </p>
      </div>
      <div style="display: flex; gap: 10px; align-items: center;">
        <button id="btn-add-shift" class="btn btn-primary" style="display: flex; align-items: center; gap: 8px;">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <line x1="12" y1="5" x2="12" y2="19"></line>
            <line x1="5" y1="12" x2="19" y2="12"></line>
          </svg>
          <span>${t('Add New Shift')}</span>
        </button>
      </div>
    </div>

    <!-- Stats Summary Cards -->
    <div id="shifts-stats-container" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 1.25rem; margin-bottom: 1.75rem;">
      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-primary-bg); color: var(--color-primary); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"></circle>
            <polyline points="12 6 12 12 16 14"></polyline>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${t('Total Shifts')}</div>
          <div class="stat-value" id="stat-total-shifts" style="font-size: 1.6rem; font-weight: 700; color: var(--color-text-primary);">-</div>
        </div>
      </div>

      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-success-bg); color: var(--color-success); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
            <polyline points="22 4 12 14.01 9 11.01"></polyline>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${t('Active Shifts')}</div>
          <div class="stat-value" id="stat-active-shifts" style="font-size: 1.6rem; font-weight: 700; color: var(--color-success);">-</div>
        </div>
      </div>

      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-info-bg); color: var(--color-info); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="5"></circle>
            <line x1="12" y1="1" x2="12" y2="3"></line>
            <line x1="12" y1="21" x2="12" y2="23"></line>
            <line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line>
            <line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line>
            <line x1="1" y1="12" x2="3" y2="12"></line>
            <line x1="21" y1="12" x2="23" y2="12"></line>
            <line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line>
            <line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${t('Full-Day Shifts')}</div>
          <div class="stat-value" id="stat-fullday-shifts" style="font-size: 1.6rem; font-weight: 700; color: var(--color-info);">-</div>
        </div>
      </div>

      <div class="card stat-card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; align-items: center; gap: 1rem; box-shadow: var(--shadow-sm);">
        <div class="stat-icon" style="width: 48px; height: 48px; border-radius: var(--radius-md); background: var(--color-warning-bg); color: var(--color-warning-dark); display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
          <svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
            <circle cx="9" cy="7" r="4"></circle>
            <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
            <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
          </svg>
        </div>
        <div class="stat-content">
          <div class="stat-label" style="font-size: 0.82rem; color: var(--color-text-secondary); margin-bottom: 4px; font-weight: 500;">${t('Enrolled Students')}</div>
          <div class="stat-value" id="stat-enrolled-students" style="font-size: 1.6rem; font-weight: 700; color: var(--color-warning-dark);">-</div>
        </div>
      </div>
    </div>

    <!-- Filters & Search Toolbar -->
    <div class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1rem 1.25rem; margin-bottom: 1.5rem;">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
        <!-- Search -->
        <div style="position: relative; min-width: 260px; flex: 1; max-width: 400px;">
          <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--color-text-muted);">
            <circle cx="11" cy="11" r="8"></circle>
            <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
          </svg>
          <input type="text" id="shifts-search-input" class="form-control" placeholder="Search by shift name, code..." style="padding-left: 36px; height: 38px; font-size: 0.9rem;">
        </div>

        <!-- Filter tabs -->
        <div style="display: flex; gap: 8px; align-items: center;">
          <span style="font-size: 0.85rem; color: var(--color-text-secondary); font-weight: 500;">${t('Filter')}:</span>
          <button type="button" class="btn btn-sm btn-filter ${activeFilter === 'all' ? 'btn-primary' : 'btn-outline'}" data-filter="all">All</button>
          <button type="button" class="btn btn-sm btn-filter ${activeFilter === 'active' ? 'btn-primary' : 'btn-outline'}" data-filter="active">Active</button>
          <button type="button" class="btn btn-sm btn-filter ${activeFilter === 'inactive' ? 'btn-primary' : 'btn-outline'}" data-filter="inactive">Inactive</button>
        </div>
      </div>
    </div>

    <!-- Shifts Cards Grid -->
    <div id="shifts-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 340px), 1fr)); gap: 1.5rem;">
      <!-- Shift cards rendered dynamically -->
    </div>
  `;

  // Attach events after DOM attached
  setTimeout(() => {
    initShiftsPage(container);
  }, 0);

  return container;
}

/**
 * Initialize event listeners and fetch initial data
 */
async function initShiftsPage(container) {
  // Add shift button
  const addBtn = container.querySelector('#btn-add-shift');
  if (addBtn) {
    addBtn.addEventListener('click', () => openShiftModal());
  }

  // Search input
  const searchInput = container.querySelector('#shifts-search-input');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      searchQuery = e.target.value.toLowerCase().trim();
      renderShiftsGrid();
    });
  }

  // Filter buttons
  const filterBtns = container.querySelectorAll('.btn-filter');
  filterBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      filterBtns.forEach(b => {
        b.classList.remove('btn-primary');
        b.classList.add('btn-outline');
      });
      btn.classList.add('btn-primary');
      btn.classList.remove('btn-outline');
      activeFilter = btn.dataset.filter;
      renderShiftsGrid();
    });
  });

  // Delegate grid actions (edit, delete, toggle status)
  const grid = container.querySelector('#shifts-grid');
  if (grid) {
    grid.addEventListener('click', (e) => {
      const cloneBtn = e.target.closest('.btn-clone-shift');
      if (cloneBtn) {
        const id = cloneBtn.dataset.id;
        const shift = shifts.find(s => s._id === id);
        if (shift) cloneShift(shift);
        return;
      }

      const editBtn = e.target.closest('.btn-edit-shift');
      if (editBtn) {
        const id = editBtn.dataset.id;
        const shift = shifts.find(s => s._id === id);
        if (shift) openShiftModal(shift);
        return;
      }

      const deleteBtn = e.target.closest('.btn-delete-shift');
      if (deleteBtn) {
        const id = deleteBtn.dataset.id;
        deleteShift(id);
        return;
      }
    });

    grid.addEventListener('change', (e) => {
      if (e.target.classList.contains('shift-active-toggle')) {
        const id = e.target.dataset.id;
        const isActive = e.target.checked;
        toggleShiftStatus(id, isActive);
      }
    });
  }

  // Fetch initial data
  await loadShiftsAndStats();
}

/**
 * Fetch shifts and stats from the API
 */
async function loadShiftsAndStats() {
  const grid = document.getElementById('shifts-grid');
  if (grid) {
    grid.innerHTML = `
      <div style="grid-column: 1 / -1; padding: 3rem; text-align: center; color: var(--color-text-secondary);">
        <div class="loading-spinner" style="margin: 0 auto 1rem auto;"></div>
        <div>Loading shifts &amp; schedules...</div>
      </div>
    `;
  }

  try {
    const [shiftsRes, statsRes] = await Promise.all([
      api.get('/api/shifts?all=true'),
      api.get('/api/shifts/stats')
    ]);

    if (shiftsRes?.success && shiftsRes.data) {
      shifts = shiftsRes.data;
    }

    if (statsRes?.success && statsRes.data) {
      stats = statsRes.data;
      updateStatsUI(stats);
    }

    renderShiftsGrid();
  } catch (error) {
    console.error('Failed to load shifts:', error);
    Toast.error(error.message || 'Failed to load shifts data');
    if (grid) {
      grid.innerHTML = `
        <div style="grid-column: 1 / -1; padding: 3rem; text-align: center; color: var(--color-danger);">
          <p style="font-size: 1.1rem; font-weight: 600;">Unable to load shifts</p>
          <button class="btn btn-outline btn-sm mt-2" onclick="location.reload()">Retry</button>
        </div>
      `;
    }
  }
}

/**
 * Update the Top Stats Counter Cards
 */
function updateStatsUI(statsData) {
  const totalEl = document.getElementById('stat-total-shifts');
  const activeEl = document.getElementById('stat-active-shifts');
  const fullDayEl = document.getElementById('stat-fullday-shifts');
  const enrolledEl = document.getElementById('stat-enrolled-students');

  if (totalEl) totalEl.textContent = statsData.total ?? shifts.length;
  if (activeEl) activeEl.textContent = statsData.active ?? shifts.filter(s => s.isActive).length;
  if (fullDayEl) fullDayEl.textContent = statsData.fullDay ?? shifts.filter(s => s.code === 'FULL').length;
  if (enrolledEl) enrolledEl.textContent = statsData.totalEnrolled ?? 0;
}

/**
 * Render the Responsive Grid of Shift Cards
 */
function renderShiftsGrid() {
  const grid = document.getElementById('shifts-grid');
  if (!grid) return;

  // Filter based on search and status
  let filtered = shifts.filter(s => {
    if (activeFilter === 'active' && !s.isActive) return false;
    if (activeFilter === 'inactive' && s.isActive) return false;
    if (searchQuery) {
      const matchName = s.name?.toLowerCase().includes(searchQuery);
      const matchCode = s.code?.toLowerCase().includes(searchQuery);
      const matchDesc = s.description?.toLowerCase().includes(searchQuery);
      if (!matchName && !matchCode && !matchDesc) return false;
    }
    return true;
  });

  if (filtered.length === 0) {
    grid.innerHTML = `
      <div style="grid-column: 1 / -1; padding: 3.5rem 1.5rem; text-align: center; background: var(--color-surface); border: 1px dashed var(--color-border); border-radius: var(--radius-lg);">
        <div style="font-size: 2.5rem; margin-bottom: 0.75rem;">🕒</div>
        <h3 style="margin: 0 0 0.5rem 0; font-size: 1.2rem; color: var(--color-text-primary); font-weight: 600;">No shifts found</h3>
        <p style="color: var(--color-text-secondary); max-width: 400px; margin: 0 auto 1.25rem auto; font-size: 0.9rem;">
          ${searchQuery || activeFilter !== 'all' ? 'No shifts match your search and filter criteria.' : 'Create your first shift schedule to manage library timings.'}
        </p>
        ${!searchQuery && activeFilter === 'all' ? `
          <button class="btn btn-primary" onclick="document.getElementById('btn-add-shift').click()">
            Add New Shift
          </button>
        ` : ''}
      </div>
    `;
    return;
  }

  let html = '';

  filtered.forEach(shift => {
    const formattedStart = formatTime12(shift.startTime);
    const formattedEnd = formatTime12(shift.endTime);
    const duration = calculateDuration(shift.startTime, shift.endTime);
    const enrolledCount = stats.studentEnrollment?.[shift.code] || 0;
    const maxCap = shift.maxCapacity || 0;

    // Capacity progress & status
    let capacityHtml = '';
    if (maxCap > 0) {
      const percent = Math.min(100, Math.round((enrolledCount / maxCap) * 100));
      let progressColor = 'var(--color-success)';
      if (percent >= 90) progressColor = 'var(--color-danger)';
      else if (percent >= 70) progressColor = 'var(--color-warning-dark)';

      capacityHtml = `
        <div style="margin-top: 12px; background: var(--color-bg-primary); padding: 10px 12px; border-radius: var(--radius-md); border: 1px solid var(--color-border-light);">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px; font-size: 0.82rem;">
            <span style="color: var(--color-text-secondary); font-weight: 500;">Capacity Occupancy</span>
            <span style="font-weight: 600; color: var(--color-text-primary);">${enrolledCount} / ${maxCap} seats (${percent}%)</span>
          </div>
          <div style="width: 100%; height: 6px; background: var(--color-border); border-radius: 3px; overflow: hidden;">
            <div style="width: ${percent}%; height: 100%; background: ${progressColor}; border-radius: 3px; transition: width 0.4s ease;"></div>
          </div>
        </div>
      `;
    } else {
      capacityHtml = `
        <div style="margin-top: 12px; background: var(--color-bg-primary); padding: 8px 12px; border-radius: var(--radius-md); border: 1px solid var(--color-border-light); display: flex; justify-content: space-between; align-items: center; font-size: 0.82rem;">
          <span style="color: var(--color-text-secondary); font-weight: 500;">Capacity Limit</span>
          <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 600;">Unlimited / Seat-based</span>
        </div>
      `;
    }

    // Active days pills
    const activeDays = Array.isArray(shift.daysActive) ? shift.daysActive.map(d => d.toLowerCase()) : ['mon','tue','wed','thu','fri','sat','sun'];
    let daysHtml = '<div style="display: flex; gap: 4px; flex-wrap: wrap; margin-top: 10px;">';
    ALL_DAYS.forEach(day => {
      const isActiveDay = activeDays.includes(day.key);
      if (isActiveDay) {
        daysHtml += `<span style="padding: 2px 7px; font-size: 0.72rem; font-weight: 600; border-radius: var(--radius-sm); background: var(--color-primary-bg); color: var(--color-primary); border: 1px solid rgba(108, 92, 231, 0.2);">${day.label}</span>`;
      } else {
        daysHtml += `<span style="padding: 2px 7px; font-size: 0.72rem; font-weight: 400; border-radius: var(--radius-sm); background: var(--color-bg-secondary); color: var(--color-text-muted); opacity: 0.6;">${day.label}</span>`;
      }
    });
    daysHtml += '</div>';

    // Price Multiplier badge
    const multiplier = shift.priceMultiplier || 1.0;
    let multiplierBadge = '';
    if (multiplier > 1.0) {
      multiplierBadge = `<span class="badge" style="background: rgba(253, 203, 110, 0.2); color: var(--color-warning-dark); font-weight: 600; font-size: 0.75rem;">${multiplier}x Rate</span>`;
    } else {
      multiplierBadge = `<span class="badge" style="background: var(--color-bg-secondary); color: var(--color-text-secondary); font-weight: 500; font-size: 0.75rem;">1.0x Standard</span>`;
    }

    const cardOpacity = shift.isActive ? '' : 'opacity: 0.65;';

    html += `
      <div class="card shift-card hoverable" style="${cardOpacity} background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem; display: flex; flex-direction: column; justify-content: space-between; box-shadow: var(--shadow-sm); transition: all var(--transition-fast);">
        <div>
          <!-- Header: Name & Code Badge -->
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 0.85rem; gap: 8px;">
            <div>
              <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary);">${escapeHTML(shift.name)}</h3>
                <span class="badge" style="background: var(--color-primary-bg); color: var(--color-primary); font-weight: 700; font-size: 0.75rem; letter-spacing: 0.5px;">${escapeHTML(shift.code)}</span>
              </div>
              ${shift.description ? `<p style="margin: 4px 0 0 0; font-size: 0.83rem; color: var(--color-text-secondary); line-height: 1.35;">${escapeHTML(shift.description)}</p>` : ''}
            </div>
            ${multiplierBadge}
          </div>

          <!-- Timing Box -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border-light); border-radius: var(--radius-md); padding: 10px 14px; margin-bottom: 0.85rem; display: flex; align-items: center; justify-content: space-between;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <div style="color: var(--color-primary); display: flex; align-items: center;">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                  <circle cx="12" cy="12" r="10"></circle>
                  <polyline points="12 6 12 12 16 14"></polyline>
                </svg>
              </div>
              <div>
                <div style="font-size: 0.98rem; font-weight: 700; color: var(--color-text-primary); letter-spacing: -0.2px;">
                  ${formattedStart} &mdash; ${formattedEnd}
                </div>
                <div style="font-size: 0.76rem; color: var(--color-text-secondary); margin-top: 1px;">
                  24h: ${escapeHTML(shift.startTime)} to ${escapeHTML(shift.endTime)}
                </div>
              </div>
            </div>
            <span class="badge" style="background: var(--color-surface); color: var(--color-text-primary); border: 1px solid var(--color-border); font-weight: 600; font-size: 0.78rem;">
              ${duration}
            </span>
          </div>

          <!-- Active Days -->
          <div>
            <div style="font-size: 0.78rem; font-weight: 500; color: var(--color-text-secondary); margin-bottom: 2px;">Active Days:</div>
            ${daysHtml}
          </div>

          <!-- Capacity Indicator -->
          ${capacityHtml}
        </div>

        <!-- Footer Actions -->
        <div style="margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid var(--color-divider); display: flex; justify-content: space-between; align-items: center;">
          <!-- Active Toggle -->
          <div style="display: flex; align-items: center; gap: 8px;">
            <input type="checkbox" class="form-toggle shift-active-toggle" id="toggle-${shift._id}" data-id="${shift._id}" ${shift.isActive ? 'checked' : ''} style="cursor: pointer;">
            <label for="toggle-${shift._id}" style="font-size: 0.82rem; font-weight: 500; color: var(--color-text-secondary); margin: 0; cursor: pointer;">
              ${shift.isActive ? 'Active' : 'Disabled'}
            </label>
          </div>

          <!-- Action Buttons -->
          <div style="display: flex; gap: 4px; flex-wrap: wrap;">
            <a href="#/seats" class="btn btn-sm btn-outline-info" style="padding: 4px 8px; font-weight: 600; font-size: 0.78rem; text-decoration: none;" title="Filter Seats Matrix by this shift">
              💺 View Seats
            </a>
            <button type="button" class="btn btn-sm btn-outline btn-clone-shift" data-id="${shift._id}" title="Clone Shift Configuration" style="padding: 4px 8px; font-size: 0.78rem; font-weight: 600;">
              📋 Clone
            </button>
            <button type="button" class="btn btn-sm btn-outline btn-edit-shift" data-id="${shift._id}" title="Edit Shift" style="padding: 4px 8px; display: inline-flex; align-items: center; gap: 4px; font-size: 0.78rem; font-weight: 600;">
              <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
              </svg>
              <span>Edit</span>
            </button>
            <button type="button" class="btn btn-sm btn-outline btn-delete-shift" data-id="${shift._id}" title="Deactivate Shift" style="padding: 4px 6px; color: var(--color-danger); border-color: rgba(214, 48, 49, 0.3);">
              <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <polyline points="3 6 5 6 21 6"></polyline>
                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `;
  });

  grid.innerHTML = html;
}

function cloneShift(shift) {
  const cloned = {
    ...shift,
    _id: null,
    name: `${shift.name} (Copy)`,
    code: `${shift.code}_COPY`
  };
  openShiftModal(cloned);
}

/**
 * Open Modal to Add or Edit a Shift
 */
function openShiftModal(shift = null) {
  const isEdit = Boolean(shift && shift._id);
  const title = isEdit ? t('Edit Shift') : t('Add New Shift');
  const selectedDays = isEdit && Array.isArray(shift.daysActive) ? shift.daysActive : ['mon','tue','wed','thu','fri','sat','sun'];

  // Build days checkboxes HTML
  let daysCheckboxesHtml = '<div style="display: flex; gap: 8px; flex-wrap: wrap;">';
  ALL_DAYS.forEach(day => {
    const checked = selectedDays.includes(day.key) ? 'checked' : '';
    daysCheckboxesHtml += `
      <label class="day-checkbox-label" style="cursor: pointer; display: inline-flex; align-items: center; gap: 6px; padding: 6px 12px; background: var(--color-bg-primary); border: 1px solid var(--color-border); border-radius: var(--radius-md); font-size: 0.85rem; font-weight: 500; user-select: none;">
        <input type="checkbox" name="daysActive" value="${day.key}" ${checked} style="cursor: pointer; width: 15px; height: 15px;">
        <span>${day.label}</span>
      </label>
    `;
  });
  daysCheckboxesHtml += '</div>';

  const content = document.createElement('div');
  content.innerHTML = `
    <form id="shift-form" style="display: flex; flex-direction: column; gap: 1rem;">
      <input type="hidden" id="shift-modal-id" value="${isEdit ? escapeHTML(shift._id) : ''}">
      
      <!-- Name & Code -->
      <div style="display: grid; grid-template-columns: 2fr 1fr; gap: 1rem;">
        <div>
          <label for="shift-modal-name" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${t('Shift Name')} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="text" id="shift-modal-name" class="form-control" required placeholder="e.g. Morning Shift, Full Day" value="${isEdit ? escapeHTML(shift.name) : ''}">
        </div>
        <div>
          <label for="shift-modal-code" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${t('Code')} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="text" id="shift-modal-code" class="form-control" required maxlength="10" placeholder="e.g. MORN" value="${isEdit ? escapeHTML(shift.code) : ''}" style="text-transform: uppercase; font-weight: 600; letter-spacing: 0.5px;">
        </div>
      </div>

      <!-- Start Time & End Time -->
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
        <div>
          <label for="shift-modal-start" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${t('Start Time')} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="time" id="shift-modal-start" class="form-control" required value="${isEdit ? escapeHTML(shift.startTime) : '06:00'}">
        </div>
        <div>
          <label for="shift-modal-end" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${t('End Time')} <span style="color: var(--color-danger);">*</span>
          </label>
          <input type="time" id="shift-modal-end" class="form-control" required value="${isEdit ? escapeHTML(shift.endTime) : '14:00'}">
        </div>
      </div>

      <!-- Capacity & Price Multiplier -->
      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1rem;">
        <div>
          <label for="shift-modal-capacity" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${t('Max Capacity')}
          </label>
          <input type="number" id="shift-modal-capacity" class="form-control" min="0" placeholder="0 = Unlimited" value="${isEdit ? (shift.maxCapacity || 0) : 0}">
          <small style="font-size: 0.75rem; color: var(--color-text-muted); display: block; margin-top: 2px;">Set 0 for unlimited / seat-based</small>
        </div>
        <div>
          <label for="shift-modal-multiplier" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
            ${t('Price Multiplier')}
          </label>
          <input type="number" id="shift-modal-multiplier" class="form-control" step="0.1" min="0.1" max="5.0" value="${isEdit ? (shift.priceMultiplier ?? 1.0) : 1.0}">
          <small style="font-size: 0.75rem; color: var(--color-text-muted); display: block; margin-top: 2px;">e.g. 1.0 = base rate, 1.5 = +50%</small>
        </div>
      </div>

      <!-- Days Active -->
      <div>
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
          <label class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin: 0;">
            ${t('Active Days')}
          </label>
          <div style="display: flex; gap: 6px;">
            <button type="button" id="btn-select-all-days" class="btn btn-ghost btn-sm" style="font-size: 0.72rem; padding: 2px 6px;">All Days</button>
            <button type="button" id="btn-select-weekdays" class="btn btn-ghost btn-sm" style="font-size: 0.72rem; padding: 2px 6px;">Weekdays</button>
          </div>
        </div>
        ${daysCheckboxesHtml}
      </div>

      <!-- Description -->
      <div>
        <label for="shift-modal-description" class="form-label" style="font-weight: 600; font-size: 0.88rem; color: var(--color-text-primary); margin-bottom: 4px;">
          ${t('Description')}
        </label>
        <textarea id="shift-modal-description" class="form-control" rows="2" placeholder="Brief notes or timing highlights...">${isEdit ? escapeHTML(shift.description || '') : ''}</textarea>
      </div>

      <!-- Active Checkbox -->
      <div style="display: flex; align-items: center; gap: 8px; margin-top: 4px;">
        <input type="checkbox" id="shift-modal-active" ${!isEdit || shift.isActive ? 'checked' : ''} style="cursor: pointer; width: 16px; height: 16px;">
        <label for="shift-modal-active" style="cursor: pointer; margin: 0; font-size: 0.88rem; font-weight: 500; color: var(--color-text-primary);">
          ${t('Shift is active and available for student allocation')}
        </label>
      </div>
    </form>
  `;

  // Quick day selection button events
  const selectAllBtn = content.querySelector('#btn-select-all-days');
  if (selectAllBtn) {
    selectAllBtn.onclick = () => {
      content.querySelectorAll('input[name="daysActive"]').forEach(cb => cb.checked = true);
    };
  }

  const selectWeekdaysBtn = content.querySelector('#btn-select-weekdays');
  if (selectWeekdaysBtn) {
    selectWeekdaysBtn.onclick = () => {
      content.querySelectorAll('input[name="daysActive"]').forEach(cb => {
        cb.checked = ['mon', 'tue', 'wed', 'thu', 'fri'].includes(cb.value);
      });
    };
  }

  // Code input auto-uppercase
  const codeInput = content.querySelector('#shift-modal-code');
  if (codeInput) {
    codeInput.addEventListener('input', (e) => {
      e.target.value = e.target.value.toUpperCase();
    });
  }

  Modal.show({
    title,
    content,
    size: 'md',
    buttons: [
      {
        text: t('Cancel'),
        className: 'btn-secondary',
        onClick: (modal) => modal.close()
      },
      {
        text: isEdit ? t('Update Shift') : t('Create Shift'),
        className: 'btn-primary',
        onClick: async (modal) => {
          const form = content.querySelector('#shift-form');
          if (!form.checkValidity()) {
            form.reportValidity();
            return;
          }

          const name = content.querySelector('#shift-modal-name').value.trim();
          const code = content.querySelector('#shift-modal-code').value.trim().toUpperCase();
          const startTime = content.querySelector('#shift-modal-start').value.trim();
          const endTime = content.querySelector('#shift-modal-end').value.trim();
          const maxCapacity = parseInt(content.querySelector('#shift-modal-capacity').value, 10) || 0;
          const priceMultiplier = parseFloat(content.querySelector('#shift-modal-multiplier').value) || 1.0;
          const description = content.querySelector('#shift-modal-description').value.trim();
          const isActive = content.querySelector('#shift-modal-active').checked;

          const checkedDays = Array.from(content.querySelectorAll('input[name="daysActive"]:checked')).map(cb => cb.value);
          const daysActive = checkedDays.length > 0 ? checkedDays : ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

          if (!name || !code || !startTime || !endTime) {
            Toast.error('Please fill in all required fields (Name, Code, Start Time, End Time)');
            return;
          }

          const payload = {
            name,
            code,
            startTime,
            endTime,
            maxCapacity,
            priceMultiplier,
            daysActive,
            description,
            isActive
          };

          try {
            let res;
            if (isEdit) {
              res = await api.put(`/api/shifts/${shift._id}`, payload);
            } else {
              res = await api.post('/api/shifts', payload);
            }

            if (res.success) {
              Toast.success(res.message || (isEdit ? 'Shift updated successfully' : 'Shift created successfully'));
              modal.close();
              await loadShiftsAndStats();
            } else {
              Toast.error(res.message || 'Failed to save shift');
            }
          } catch (error) {
            Toast.error(error.message || 'Failed to save shift');
          }
        }
      }
    ]
  });
}

/**
 * Toggle Shift Active / Disabled Status
 */
async function toggleShiftStatus(id, isActive) {
  try {
    const res = await api.put(`/api/shifts/${id}`, { isActive });
    if (res.success) {
      Toast.success(isActive ? 'Shift activated' : 'Shift deactivated');
      // Update local memory and UI
      const found = shifts.find(s => s._id === id);
      if (found) found.isActive = isActive;
      await loadShiftsAndStats();
    } else {
      Toast.error(res.message || 'Failed to update shift status');
      renderShiftsGrid();
    }
  } catch (error) {
    Toast.error(error.message || 'Failed to update shift status');
    renderShiftsGrid();
  }
}

/**
 * Soft delete / Deactivate a shift with confirmation
 */
async function deleteShift(id) {
  const shift = shifts.find(s => s._id === id);
  const shiftName = shift ? shift.name : 'this shift';

  Confirm.show({
    title: t('Deactivate Shift'),
    message: `Are you sure you want to deactivate "${escapeHTML(shiftName)}"? Existing students on this shift will not be lost, but the shift will be disabled for new assignments.`,
    confirmText: 'Deactivate',
    cancelText: 'Cancel',
    danger: true,
    onConfirm: async () => {
      try {
        const res = await api.delete(`/api/shifts/${id}`);
        if (res.success) {
          Toast.success(res.message || 'Shift deactivated successfully');
          await loadShiftsAndStats();
        } else {
          Toast.error(res.message || 'Failed to deactivate shift');
        }
      } catch (error) {
        Toast.error(error.message || 'Failed to deactivate shift');
      }
    }
  });
}
