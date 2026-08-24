import { App } from '../app.js';
import { t } from '../i18n.js';
import { Toast, Modal, Loading, Confirm, escapeHTML, debounce, UI } from '../ui.js';
import api from '../api.js';
import { IDBStorage } from '../utils/idbStorage.js';
import { OptimisticUI } from '../utils/optimisticUI.js';

let activeHubTab = 'seats'; // 'seats' | 'centers' | 'analytics'
let currentBranch = 'all';  // 'all' | branchId | 'unassigned'
let currentZone = '';
let currentStatus = '';
let currentSearch = '';
let seatsData = [];
let branchesList = [];
let managersList = [];
let selectedSeatIds = new Set();

const ALL_AMENITIES = [
  { id: 'AC', label: 'AC', icon: '❄️' },
  { id: 'WiFi', label: 'High Speed WiFi', icon: '📶' },
  { id: 'CCTV', label: 'CCTV Surveillance', icon: '📹' },
  { id: 'Power Backup', label: 'Power Backup', icon: '⚡' },
  { id: 'RO Water', label: 'RO Drinking Water', icon: '💧' },
  { id: 'Locker', label: 'Personal Lockers', icon: '🔒' },
  { id: 'Cafeteria', label: 'Cafeteria / Pantry', icon: '☕' },
  { id: 'Discussion Room', label: 'Discussion Room', icon: '🗣️' },
  { id: 'Parking', label: 'Two Wheeler Parking', icon: '🚗' },
  { id: 'Biometric Access', label: 'Biometric Access', icon: '👆' }
];

export async function render() {
  const container = document.createElement('div');
  container.className = 'centers-seats-hub-page page-container';

  // Read URL query parameters: #/seats?tab=centers or #/seats?branch=XYZ
  const hash = window.location.hash;
  if (hash.includes('?')) {
    const urlParams = new URLSearchParams(hash.split('?')[1]);
    if (urlParams.get('tab')) {
      activeHubTab = urlParams.get('tab');
    }
    if (urlParams.get('branch')) {
      currentBranch = urlParams.get('branch');
    }
  }

  container.innerHTML = `
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>🏢 Centers & Seating Hub</h2>
        <p>Unified management for study library branches, seating matrices, floor plans, and cross-branch transfers.</p>
      </div>

      <!-- Top Primary Action Controls -->
      <div class="module-actions">
        <button id="btn-zone-customizer" class="btn btn-outline-info d-flex align-items-center gap-1" style="font-weight: 600;">
          🎨 Zone Customizer
        </button>
        <button id="btn-cross-transfer" class="btn btn-outline-secondary d-flex align-items-center gap-1" style="font-weight: 600;">
          🔄 Transfer Student
        </button>
        <button id="waitingListBtn" class="btn btn-outline-secondary d-flex align-items-center gap-1" style="font-weight: 600;">
          ⏳ Waiting List <span class="badge badge-primary" id="waiting-badge" style="display:none; margin-left: 4px;">0</span>
        </button>
        <button id="btn-hub-add-seat" class="btn btn-outline-primary" style="font-weight: 600;">
          + Add Single Seat
        </button>
        <button id="btn-hub-bulk-seats" class="btn btn-primary" style="font-weight: 600;">
          ⚡ Bulk Add Seats
        </button>
        <button id="btn-hub-add-branch" class="btn btn-success" style="font-weight: 600;">
          🏢 + New Branch
        </button>
      </div>
    </div>

    <!-- Contextual Guidance Tip Banner -->
    <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
      <span style="font-size: 1.1rem;">💡</span>
      <span><strong>Tip:</strong> Green = Vacant, Red = Occupied, Yellow = Reserved Hold. Click any desk to reassign or view student assignment.</span>
    </div>

    <!-- Hub View Switcher Tabs -->
    <div class="card p-2 mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
      <div class="d-flex gap-2 flex-wrap">
        <button type="button" class="btn btn-sm ${activeHubTab === 'seats' ? 'btn-primary' : 'btn-ghost text-muted'} hub-tab-btn" data-tab="seats" style="font-weight: 700; font-size: 0.9rem; padding: 6px 16px;">
          💺 Seats Matrix & Floor Plan
        </button>
        <button type="button" class="btn btn-sm ${activeHubTab === 'centers' ? 'btn-primary' : 'btn-ghost text-muted'} hub-tab-btn" data-tab="centers" style="font-weight: 700; font-size: 0.9rem; padding: 6px 16px;">
          🏢 Study Centers & Branches (<span id="tab-branches-count">0</span>)
        </button>
        <button type="button" class="btn btn-sm ${activeHubTab === 'analytics' ? 'btn-primary' : 'btn-ghost text-muted'} hub-tab-btn" data-tab="analytics" style="font-weight: 700; font-size: 0.9rem; padding: 6px 16px;">
          📊 Multi-Branch Occupancy & Comparison
        </button>
      </div>
    </div>

    <!-- ========================================================= -->
    <!-- VIEW 1: SEATS MATRIX & FLOOR PLAN -->
    <!-- ========================================================= -->
    <div class="hub-view" id="view-seats" style="${activeHubTab === 'seats' ? '' : 'display: none;'}">
      
      <!-- Standardized KPI Stats Grid -->
      <div class="kpi-grid" id="seatsStatsContainer">
        <div class="kpi-card kpi-primary">
          <div class="kpi-label">TOTAL SEATS <span>💺</span></div>
          <div class="kpi-value" id="stat-total">-</div>
          <div class="kpi-subtext">Capacity</div>
        </div>
        <div class="kpi-card kpi-success">
          <div class="kpi-label">AVAILABLE <span>🟢</span></div>
          <div class="kpi-value text-success" id="stat-available">-</div>
          <div class="kpi-subtext">Vacant & ready</div>
        </div>
        <div class="kpi-card kpi-danger">
          <div class="kpi-label">OCCUPIED <span>🔴</span></div>
          <div class="kpi-value text-danger" id="stat-occupied">-</div>
          <div class="kpi-subtext">Active students</div>
        </div>
        <div class="kpi-card kpi-warning">
          <div class="kpi-label">RESERVED <span>🟡</span></div>
          <div class="kpi-value text-warning" id="stat-reserved">-</div>
          <div class="kpi-subtext">Booked desks</div>
        </div>
        <div class="kpi-card kpi-slate">
          <div class="kpi-label">MAINTENANCE <span>⚪</span></div>
          <div class="kpi-value" id="stat-maintenance" style="color: #64748b;">-</div>
          <div class="kpi-subtext">Under repair</div>
        </div>
      </div>

      <!-- Filter & Search Toolbar -->
      <div class="toolbar-card">
        <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
          
          <!-- Left: Branch Selector & Search -->
          <div class="d-flex align-items-center gap-2 flex-wrap flex-1 w-100">
            <div class="w-100 w-md-auto">
              <label class="form-label text-xs mb-1" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px;">🏢 SELECT BRANCH</label>
              <select id="seat-branch-selector" class="form-select form-control form-control-sm w-100" style="font-weight: 600;">
                <option value="all">🌐 All Branches</option>
              </select>
            </div>

            <div class="w-100 flex-1">
              <label class="form-label text-xs mb-1" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px;">🔍 SEARCH SEAT</label>
              <input type="text" id="seat-search-input" class="form-control form-control-sm w-100" placeholder="Search seat number (e.g. A-01, 14)...">
            </div>

            <div class="w-100 w-md-auto">
              <label class="form-label text-xs mb-1" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px;">📌 STATUS FILTER</label>
              <select id="seat-status-filter" class="form-select form-control form-control-sm w-100">
                <option value="">All Statuses</option>
                <option value="available">🟢 Available</option>
                <option value="occupied">🔴 Occupied</option>
                <option value="reserved">🟡 Reserved</option>
                <option value="maintenance">⚪ Maintenance</option>
              </select>
            </div>
          </div>

          <!-- Right: Multi-select Toggle -->
          <div class="d-flex align-items-center gap-2">
            <button type="button" id="btn-toggle-select-all" class="btn btn-sm btn-outline-secondary" style="font-size: 0.8rem; font-weight: 600;">
              ☑️ Select All
            </button>
          </div>
        </div>

        <!-- Horizontal Scrollable Zone Pills -->
        <div class="mt-3 pt-3 border-top">
          <label class="form-label text-xs mb-2" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px; display: block;">🏷️ FILTER BY STUDY ZONE</label>
          <div id="zone-pills-container" style="display: flex; gap: 8px; overflow-x: auto; padding-bottom: 4px; scrollbar-width: thin;">
            <!-- Dynamically loaded zone badge buttons -->
          </div>
        </div>

        <!-- Horizontal Scrollable Shift Filter Pills -->
        <div class="mt-2 pt-2 border-top">
          <label class="form-label text-xs mb-2" style="font-weight: 800; color: var(--color-text-secondary); letter-spacing: 0.5px; display: block;">⏰ FILTER BY STUDY SHIFT</label>
          <div id="shift-pills-container" style="display: flex; gap: 8px; overflow-x: auto; padding-bottom: 4px; scrollbar-width: thin;">
            <button type="button" class="btn btn-xs btn-primary shift-pill-btn active" data-shift="" style="font-weight: 700; border-radius: 20px; padding: 4px 12px;">🌐 All Shifts</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="morning" style="font-weight: 600; border-radius: 20px; padding: 4px 12px;">🌅 Morning Shift</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="evening" style="font-weight: 600; border-radius: 20px; padding: 4px 12px;">🌆 Evening Shift</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="night" style="font-weight: 600; border-radius: 20px; padding: 4px 12px;">🌃 Night Shift</button>
            <button type="button" class="btn btn-xs btn-outline-secondary shift-pill-btn" data-shift="fullday" style="font-weight: 600; border-radius: 20px; padding: 4px 12px;">☀️ Full Day Shift</button>
          </div>
        </div>
      </div>

      <!-- Floating Bulk Actions Bar -->
      <div id="bulk-action-bar" style="display: none; position: sticky; top: 70px; z-index: 99; margin-bottom: 1rem; background: #1e293b; color: #fff; padding: 10px 18px; border-radius: var(--radius-md); box-shadow: var(--shadow-lg); align-items: center; justify-content: space-between; flex-wrap: gap-2;">
        <div class="d-flex align-items-center gap-2">
          <span class="badge badge-primary" id="bulk-selected-count" style="font-size: 0.85rem; padding: 4px 8px;">0 Selected</span>
          <span class="text-sm">Action on selected seats:</span>
        </div>
        <div class="d-flex gap-2 flex-wrap">
          <button type="button" class="btn btn-sm btn-outline-light" id="btn-bulk-rezone">🏷️ Change Zone</button>
          <button type="button" class="btn btn-sm btn-outline-light" id="btn-bulk-rebranch">🏢 Move Branch</button>
          <button type="button" class="btn btn-sm btn-outline-light" id="btn-bulk-status">🔄 Change Status</button>
          <button type="button" class="btn btn-sm btn-danger" id="btn-bulk-delete">🗑️ Delete Selected</button>
          <button type="button" class="btn btn-sm btn-ghost text-light" id="btn-bulk-cancel">❌ Cancel</button>
        </div>
      </div>

      <!-- Seats Grid -->
      <div class="seats-grid" id="seatsGrid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 135px), 1fr)); gap: 1rem;">
        <!-- Seats loaded here -->
      </div>
    </div>

    <!-- ========================================================= -->
    <!-- VIEW 2: STUDY CENTERS & BRANCHES OVERVIEW -->
    <!-- ========================================================= -->
    <div class="hub-view" id="view-centers" style="${activeHubTab === 'centers' ? '' : 'display: none;'}">
      <div class="d-flex justify-content-between align-items-center mb-3">
        <h3 style="margin: 0; font-size: 1.2rem; font-weight: 700;">🏢 Study Library Branches & Centers</h3>
        <button class="btn btn-success btn-sm btn-trigger-add-branch">+ Add New Branch Center</button>
      </div>

      <!-- Branch Cards Grid -->
      <div id="branches-cards-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 360px), 1fr)); gap: 1.5rem;">
        <div class="text-center p-4 text-muted col-span-full">Loading branches...</div>
      </div>
    </div>

    <!-- ========================================================= -->
    <!-- VIEW 3: MULTI-BRANCH ANALYTICS & COMPARISON -->
    <!-- ========================================================= -->
    <div class="hub-view" id="view-analytics" style="${activeHubTab === 'analytics' ? '' : 'display: none;'}">
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <h3 style="margin: 0 0 1rem 0; font-size: 1.2rem; font-weight: 700;">📊 Cross-Branch Performance & Occupancy Matrix</h3>
        
        <div class="table-responsive">
          <table class="table data-table mb-0" style="width: 100%; font-size: 0.9rem;">
            <thead>
              <tr>
                <th>Branch Center</th>
                <th>Code</th>
                <th>Manager</th>
                <th>Total Seats</th>
                <th>Occupied</th>
                <th>Available</th>
                <th>Occupancy Rate</th>
                <th class="text-right">Est. Monthly Revenue</th>
              </tr>
            </thead>
            <tbody id="analytics-table-body">
              <tr><td colspan="8" class="text-center p-4 text-muted">Calculating cross-branch metrics...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  bindHubEvents(container);

  setTimeout(async () => {
    await loadInitialHubData(container);
  }, 0);

  // Mount context-aware FAB for Seats page
  if (typeof window !== 'undefined' && window.FAB) {
    window.FAB.mount({
      icon: '🪑',
      label: 'Seat Actions',
      color: '#fd79a8',
      actions: [
        {
          icon: '➕',
          label: 'Add Seat',
          onClick: () => { const btn = container.querySelector('#addSeatBtn, [id*="addSeat"]'); if (btn) btn.click(); }
        },
        {
          icon: '🗺️',
          label: 'Seat Map',
          onClick: () => { const btn = container.querySelector('[data-tab="seats"], .hub-tab-btn'); if (btn) btn.click(); }
        },
        {
          icon: '📊',
          label: 'Occupancy Report',
          onClick: () => { window.location.hash = '#/reports'; }
        }
      ]
    });
  }

  return container;
}

function bindHubEvents(container) {
  // Tab switching
  container.querySelectorAll('.hub-tab-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const tab = btn.dataset.tab;
      activeHubTab = tab;

      container.querySelectorAll('.hub-tab-btn').forEach(b => {
        b.classList.remove('btn-primary');
        b.classList.add('btn-ghost', 'text-muted');
      });
      btn.classList.add('btn-primary');
      btn.classList.remove('btn-ghost', 'text-muted');

      container.querySelectorAll('.hub-view').forEach(v => v.style.display = 'none');
      container.querySelector(`#view-${tab}`).style.display = 'block';

      if (tab === 'centers') renderCentersTab(container);
      if (tab === 'analytics') renderAnalyticsTab(container);
      if (tab === 'seats') loadSeats(container);
    });
  });

  // Top header button triggers
  container.querySelector('#btn-hub-add-seat')?.addEventListener('click', () => showAddSingleSeatModal(container));
  container.querySelector('#btn-hub-bulk-seats')?.addEventListener('click', () => showAddSeatsModal(container));
  container.querySelector('#btn-hub-add-branch')?.addEventListener('click', () => showBranchModal(null, container));
  container.querySelector('.btn-trigger-add-branch')?.addEventListener('click', () => showBranchModal(null, container));
  container.querySelector('#waitingListBtn')?.addEventListener('click', showWaitingListModal);
  container.querySelector('#btn-cross-transfer')?.addEventListener('click', () => showCrossTransferModal(container));
  container.querySelector('#btn-zone-customizer')?.addEventListener('click', () => showZoneCustomizerModal(container));

  // Branch filter change
  container.querySelector('#seat-branch-selector')?.addEventListener('change', (e) => {
    currentBranch = e.target.value;
    selectedSeatIds.clear();
    updateBulkActionBar(container);
    loadStats(container);
    loadZones(container);
    loadSeats(container);
  });

  // Status filter change
  container.querySelector('#seat-status-filter')?.addEventListener('change', (e) => {
    currentStatus = e.target.value;
    loadSeats(container);
  });

  // Shift filter pills click
  container.querySelectorAll('.shift-pill-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      container.querySelectorAll('.shift-pill-btn').forEach(b => {
        b.classList.remove('btn-primary', 'active');
        b.classList.add('btn-outline-secondary');
      });
      btn.classList.add('btn-primary', 'active');
      btn.classList.remove('btn-outline-secondary');
      loadSeats(container);
    });
  });

  // Search input with debounce
  container.querySelector('#seat-search-input')?.addEventListener('input', debounce((e) => {
    currentSearch = e.target.value.trim();
    loadSeats(container);
  }, 250));

  // Select all toggle
  container.querySelector('#btn-toggle-select-all')?.addEventListener('click', () => {
    if (selectedSeatIds.size === seatsData.length) {
      selectedSeatIds.clear();
    } else {
      seatsData.forEach(s => selectedSeatIds.add(s._id));
    }
    updateBulkActionBar(container);
    renderSeatsGrid(seatsData, container);
  });

  // Bulk action handlers
  container.querySelector('#btn-bulk-cancel')?.addEventListener('click', () => {
    selectedSeatIds.clear();
    updateBulkActionBar(container);
    renderSeatsGrid(seatsData, container);
  });

  container.querySelector('#btn-bulk-delete')?.addEventListener('click', () => handleBulkDelete(container));
  container.querySelector('#btn-bulk-rezone')?.addEventListener('click', () => handleBulkRezone(container));
  container.querySelector('#btn-bulk-rebranch')?.addEventListener('click', () => handleBulkRebranch(container));
  container.querySelector('#btn-bulk-status')?.addEventListener('click', () => handleBulkStatus(container));
}

async function loadInitialHubData(container) {
  try {
    const [bRes, mRes] = await Promise.all([
      api.get('/api/branches'),
      api.get('/api/branches/managers').catch(() => ({ data: [] }))
    ]);

    if (bRes.success && bRes.data) {
      branchesList = bRes.data;
      container.querySelector('#tab-branches-count').textContent = branchesList.length;

      const select = container.querySelector('#seat-branch-selector');
      if (select) {
        let opts = `<option value="all" ${currentBranch === 'all' ? 'selected' : ''}>🌐 All Branches</option>`;
        branchesList.forEach(b => {
          opts += `<option value="${b._id}" ${currentBranch === b._id ? 'selected' : ''}>🏢 ${escapeHTML(b.name)} (${escapeHTML(b.code || '')})</option>`;
        });
        opts += `<option value="unassigned" ${currentBranch === 'unassigned' ? 'selected' : ''}>Unassigned Branch</option>`;
        select.innerHTML = opts;
      }
    }

    if (mRes.success && mRes.data) {
      managersList = mRes.data;
    }

    await Promise.all([
      loadStats(container),
      loadZones(container),
      loadSeats(container)
    ]);

    if (activeHubTab === 'centers') renderCentersTab(container);
    if (activeHubTab === 'analytics') renderAnalyticsTab(container);

  } catch (err) {
    console.error('Failed initial hub data load:', err);
  }
}

async function loadStats(container) {
  const branchParam = currentBranch !== 'all' ? `?branch=${currentBranch}` : '';
  const cacheKey = `stats_${currentBranch}`;

  try {
    const cachedStats = await IDBStorage.get('seats', cacheKey);
    if (cachedStats) {
      if (container.querySelector('#stat-total')) container.querySelector('#stat-total').textContent = cachedStats.total || 0;
      if (container.querySelector('#stat-available')) container.querySelector('#stat-available').textContent = cachedStats.available || 0;
      if (container.querySelector('#stat-occupied')) container.querySelector('#stat-occupied').textContent = cachedStats.occupied || 0;
      if (container.querySelector('#stat-reserved')) container.querySelector('#stat-reserved').textContent = cachedStats.reserved || 0;
      if (container.querySelector('#stat-maintenance')) container.querySelector('#stat-maintenance').textContent = cachedStats.maintenance || 0;
    }
  } catch (e) {
    console.warn('IDB read seats stats warning:', e);
  }

  try {
    const [res, wlRes] = await Promise.all([
      api.get(`/api/seats/stats${branchParam}`),
      api.get('/api/waiting-list')
    ]);

    if (res.success && res.data) {
      const stats = res.data;
      await IDBStorage.set('seats', cacheKey, stats);
      container.querySelector('#stat-total').textContent = stats.total || 0;
      container.querySelector('#stat-available').textContent = stats.available || 0;
      container.querySelector('#stat-occupied').textContent = stats.occupied || 0;
      container.querySelector('#stat-reserved').textContent = stats.reserved || 0;
      container.querySelector('#stat-maintenance').textContent = stats.maintenance || 0;
    }

    if (wlRes?.success && wlRes?.data?.counts) {
      const badge = container.querySelector('#waiting-badge');
      if (badge) {
        const count = wlRes.data.counts.waiting || 0;
        badge.textContent = count;
        badge.style.display = count > 0 ? 'inline-block' : 'none';
      }
    }
  } catch (error) {
    console.error('Error loading stats:', error);
  }
}

async function loadZones(container) {
  const pillsContainer = container.querySelector('#zone-pills-container');
  if (!pillsContainer) return;
  const branchParam = currentBranch !== 'all' ? `?branch=${currentBranch}` : '';
  const cacheKey = `zones_${currentBranch}`;

  const renderZonesUI = (zones) => {
    let totalCount = zones.reduce((acc, z) => acc + (z.count || 0), 0);
    let html = `
      <button type="button" class="btn btn-sm ${currentZone === '' ? 'btn-primary' : 'btn-outline-secondary'} zone-pill-btn" data-zone="" style="border-radius: 20px; font-weight: 600; white-space: nowrap;">
        🌟 All Zones (${totalCount})
      </button>
    `;
    zones.forEach(z => {
      const isAct = currentZone === z._id;
      html += `
        <button type="button" class="btn btn-sm ${isAct ? 'btn-primary' : 'btn-outline-secondary'} zone-pill-btn" data-zone="${escapeHTML(z._id)}" style="border-radius: 20px; font-weight: 600; white-space: nowrap;">
          📍 ${escapeHTML(z._id)} <span class="badge ${isAct ? 'bg-light text-dark' : 'badge-primary'}" style="font-size: 0.7rem; margin-left: 4px;">${z.count}</span>
        </button>
      `;
    });
    pillsContainer.innerHTML = html;
    pillsContainer.querySelectorAll('.zone-pill-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        currentZone = btn.getAttribute('data-zone') || '';
        pillsContainer.querySelectorAll('.zone-pill-btn').forEach(b => {
          b.classList.remove('btn-primary');
          b.classList.add('btn-outline-secondary');
        });
        btn.classList.add('btn-primary');
        btn.classList.remove('btn-outline-secondary');
        loadSeats(container);
      });
    });
  };

  try {
    const cachedZones = await IDBStorage.get('seats', cacheKey);
    if (cachedZones && Array.isArray(cachedZones)) {
      renderZonesUI(cachedZones);
    }
  } catch (e) {
    console.warn('IDB read zones warning:', e);
  }
  
  try {
    const res = await api.get(`/api/seats/zones${branchParam}`);
    if (res.success && res.data) {
      const zones = res.data;
      await IDBStorage.set('seats', cacheKey, zones);
      renderZonesUI(zones);
    }
  } catch (error) {
    console.error('Error loading zones:', error);
  }
}

async function loadSeats(container) {
  const grid = container.querySelector('#seatsGrid');
  if (!grid) return;

  const params = new URLSearchParams();
  if (currentBranch && currentBranch !== 'all') params.append('branch', currentBranch);
  if (currentZone) params.append('zone', currentZone);
  if (currentStatus) params.append('status', currentStatus);
  if (currentSearch) params.append('search', currentSearch);
  const cacheKey = `list_${params.toString()}`;

  let hasRenderedCache = false;
  try {
    const cachedSeats = await IDBStorage.get('seats', cacheKey);
    if (cachedSeats && Array.isArray(cachedSeats)) {
      seatsData = cachedSeats;
      renderSeatsGrid(seatsData, container);
      hasRenderedCache = true;
    }
  } catch (e) {
    console.warn('IDB read seats list warning:', e);
  }
  
  if (!hasRenderedCache) {
    Loading.skeleton(grid, 'cards');
  }
  
  try {
    const url = `/api/seats?${params.toString()}`;
    const res = await api.get(url);
    
    if (res.success) {
      seatsData = res.data || [];
      await IDBStorage.set('seats', cacheKey, seatsData);
      renderSeatsGrid(seatsData, container);
    } else {
      if (!hasRenderedCache) {
        Toast.error(res.message);
        grid.innerHTML = `<div class="empty-state">Error loading seats</div>`;
      }
    }
  } catch (error) {
    console.error('Error loading seats:', error);
    if (!hasRenderedCache) {
      Toast.error('Failed to load seats');
      grid.innerHTML = `<div class="empty-state">Failed to load seats</div>`;
    }
  }
}

function getStatusColor(status) {
  switch(status) {
    case 'available': return '#22c55e'; // green
    case 'occupied': return '#ef4444'; // red
    case 'reserved': return '#f59e0b'; // amber
    case 'maintenance': return '#64748b'; // slate
    default: return '#94a3b8';
  }
}

function open360DeskDetailsModal(seat, container) {
  const statusColor = getStatusColor(seat.status);
  const student = seat.currentStudent;
  const branchName = seat.branch ? (typeof seat.branch === 'object' ? seat.branch.name : seat.branch) : 'Main Branch';

  const modalContent = document.createElement('div');
  modalContent.innerHTML = `
    <div style="font-family: 'Outfit', sans-serif;">
      <!-- Header Banner -->
      <div style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.12), rgba(0, 184, 148, 0.08)); border: 1.5px solid var(--color-primary); border-radius: var(--radius-lg); padding: 1.25rem; margin-bottom: 1.25rem; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
        <div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <h3 style="margin: 0; font-size: 1.4rem; font-weight: 800; color: var(--color-text-primary);">
              💺 Desk ${escapeHTML(seat.seatNumber)}
            </h3>
            <span class="badge" style="background-color: ${statusColor}; color: #fff; font-weight: 800; font-size: 0.8rem; text-transform: uppercase; padding: 4px 10px;">
              ${escapeHTML(seat.status)}
            </span>
          </div>
          <div style="font-size: 0.85rem; color: var(--color-text-secondary); margin-top: 4px;">
            Zone: <strong>${escapeHTML(seat.zone)}</strong> • Type: <strong style="text-transform: capitalize;">${escapeHTML(seat.type || 'Regular')}</strong> • Branch: <strong>${escapeHTML(branchName)}</strong>
          </div>
        </div>
        <div style="font-size: 1.3rem; font-weight: 800; color: var(--color-primary);">
          ₹${seat.monthlyRate || 1000} <span style="font-size: 0.75rem; color: var(--color-text-secondary); font-weight: 500;">/ mo</span>
        </div>
      </div>

      <!-- Occupant / Assignment Card -->
      ${(seat.status === 'occupied' || seat.currentStudent) && student ? `
        <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
          <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 8px; display: flex; align-items: center; justify-content: space-between;">
            <span>👤 Active Desk Occupant</span>
            <button type="button" class="btn btn-xs btn-outline-success btn-wa-direct" data-phone="${escapeHTML(student.phone || '')}" style="font-size: 0.72rem; padding: 2px 8px; font-weight: 700;">
              📲 WhatsApp Occupant
            </button>
          </div>
          <div style="display: flex; gap: 12px; align-items: center;">
            <div style="width: 50px; height: 50px; border-radius: 50%; background: var(--color-primary); color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 1.2rem; flex-shrink: 0; overflow: hidden;">
              ${student.photo ? `<img src="${student.photo.startsWith('/') ? student.photo : '/' + student.photo}" style="width:100%; height:100%; object-fit:cover;">` : (student.name ? student.name.charAt(0).toUpperCase() : 'S')}
            </div>
            <div>
              <div style="font-weight: 800; font-size: 1.05rem; color: var(--color-text-primary);">${escapeHTML(student.name)}</div>
              <div style="font-size: 0.82rem; color: var(--color-text-secondary);">
                ID: <strong style="font-family: monospace; color: var(--color-primary);">${escapeHTML(student.studentId || 'N/A')}</strong> • Phone: <strong>${escapeHTML(student.phone || 'N/A')}</strong>
              </div>
            </div>
          </div>
        </div>
      ` : `
        <div class="card p-3 mb-3 text-center" style="background: rgba(0, 184, 148, 0.05); border: 1px dashed var(--color-success); border-radius: var(--radius-md);">
          <div style="font-weight: 700; color: var(--color-success); margin-bottom: 4px;">🟢 Desk Available for Immediate Allotment</div>
          <div style="font-size: 0.82rem; color: var(--color-text-secondary);">Assign this desk to a new or walk-in student member.</div>
        </div>
      `}

      <!-- Universal 5-Level Action Buttons Grid -->
      <div class="d-flex gap-2 flex-wrap justify-content-between align-items-center mt-4 pt-3" style="border-top: 1px solid var(--color-border);">
        <div class="d-flex gap-2 flex-wrap">
          ${(seat.status === 'occupied' || seat.currentStudent) ? `
            <button type="button" class="btn btn-outline-danger btn-sm btn-action-vacate" style="font-weight: 700;">
              🔓 Vacate / Release Desk
            </button>
          ` : `
            <button type="button" class="btn btn-outline-success btn-sm btn-action-assign" style="font-weight: 700;">
              👤 Assign Student
            </button>
          `}
          <button type="button" class="btn btn-outline-secondary btn-sm btn-action-clone" style="font-weight: 600;" title="Duplicate this desk with new number">
            📑 Clone Desk
          </button>
        </div>

        <div class="d-flex gap-2 flex-wrap">
          <button type="button" class="btn btn-outline-warning btn-sm btn-action-maint" style="font-weight: 600;">
            ${seat.status === 'maintenance' ? '🟢 Mark Available' : '🛠️ Maintenance'}
          </button>
          <button type="button" class="btn btn-outline-primary btn-sm btn-action-edit" style="font-weight: 600;">
            ✏️ Edit
          </button>
          <button type="button" class="btn btn-outline-danger btn-sm btn-action-delete" style="font-weight: 600;">
            🗑️ Delete
          </button>
        </div>
      </div>
    </div>
  `;

  const m = new Modal({
    title: `Desk ${seat.seatNumber} Details & Actions`,
    content: modalContent,
    size: 'md'
  });
  m.show();

  // Direct WhatsApp Occupant
  modalContent.querySelector('.btn-wa-direct')?.addEventListener('click', (e) => {
    const ph = e.currentTarget.dataset.phone;
    if (ph) {
      const cleanPhone = ph.replace(/\D/g, '');
      const url = `https://wa.me/${cleanPhone.length === 10 ? '91' + cleanPhone : cleanPhone}?text=${encodeURIComponent(`Hello! Library Admin checking in regarding Desk ${seat.seatNumber}.`)}`;
      window.open(url, '_blank');
    }
  });

  // Vacate / Release Desk Handler
  modalContent.querySelector('.btn-action-vacate')?.addEventListener('click', async () => {
    const ok = await Confirm.show({
      title: `Release Desk ${seat.seatNumber}?`,
      message: 'Are you sure you want to unassign this desk from the current student occupant?',
      danger: true
    });
    if (ok) {
      try {
        await api.put(`/api/seats/${seat._id}`, { status: 'available', currentStudent: null });
        Toast.success(`Desk ${seat.seatNumber} has been released and is now available!`);
        m.close();
        await IDBStorage.clear('seats');
        loadSeats(container);
        loadStats(container);
      } catch (err) {
        Toast.error(err.message || 'Failed to release desk');
      }
    }
  });

  // Assign Student Modal
  modalContent.querySelector('.btn-action-assign')?.addEventListener('click', async () => {
    m.close();
    showAssignStudentModal(seat, container);
  });

  // Clone / Duplicate Desk Handler
  modalContent.querySelector('.btn-action-clone')?.addEventListener('click', async () => {
    const currentNum = parseInt(seat.seatNumber.replace(/\D/g, '')) || 1;
    const prefix = seat.seatNumber.replace(/[0-9]/g, '') || 'D-';
    const newNumber = `${prefix}${currentNum + 1}`;

    try {
      const payload = {
        seatNumber: newNumber,
        type: seat.type || 'Regular',
        zone: seat.zone || 'General',
        zoneColor: seat.zoneColor || '#6c5ce7',
        floor: seat.floor || 'Ground Floor',
        monthlyRate: seat.monthlyRate || 1000,
        branch: seat.branch?._id || seat.branch || null,
        status: 'available'
      };
      const res = await api.post('/api/seats', payload);
      if (res.success) {
        Toast.success(`Desk ${newNumber} cloned and created successfully!`);
        m.close();
        await IDBStorage.clear('seats');
        loadSeats(container);
        loadStats(container);
      } else {
        Toast.error(res.message || 'Failed to clone desk');
      }
    } catch (err) {
      Toast.error(err.message || 'Error cloning desk');
    }
  });

  // Maintenance Toggle
  modalContent.querySelector('.btn-action-maint')?.addEventListener('click', async () => {
    const nextStatus = seat.status === 'maintenance' ? 'available' : 'maintenance';
    try {
      await api.put(`/api/seats/${seat._id}`, { status: nextStatus });
      Toast.success(`Desk ${seat.seatNumber} status updated to ${nextStatus}!`);
      m.close();
      await IDBStorage.clear('seats');
      loadSeats(container);
      loadStats(container);
    } catch (err) {
      Toast.error(err.message || 'Failed to update status');
    }
  });

  // Edit Config
  modalContent.querySelector('.btn-action-edit')?.addEventListener('click', () => {
    m.close();
    showSingleSeatModal(seat, container);
  });

  // Delete
  modalContent.querySelector('.btn-action-delete')?.addEventListener('click', async () => {
    const ok = await Confirm.show({
      title: `Delete Desk ${seat.seatNumber}?`,
      message: 'Are you sure you want to permanently remove this desk?',
      danger: true
    });
    if (ok) {
      try {
        await api.delete(`/api/seats/${seat._id}`);
        Toast.success(`Desk ${seat.seatNumber} deleted!`);
        m.close();
        await IDBStorage.clear('seats');
        loadSeats(container);
        loadStats(container);
      } catch (err) {
        Toast.error(err.message || 'Delete failed');
      }
    }
  });
}



function renderSeatsGrid(seats, container) {
  const c = container || document.querySelector('.centers-seats-hub-page') || document;
  const grid = c.querySelector('#seatsGrid');
  if (!grid) return;
  
  if (seats.length === 0) {
    UI.emptyState(grid, {
      icon: '💺',
      title: 'No Seats Match Current Filter',
      description: 'No seats found in this branch/zone combination. Click below to bulk add seats.',
      actionText: '⚡ Bulk Add Seats',
      onAction: () => showAddSeatsModal(c)
    });
    return;
  }
  
  let html = '';
  seats.forEach(seat => {
    const color = getStatusColor(seat.status);
    const studentName = seat.currentStudent ? seat.currentStudent.name : '';
    const isSelected = selectedSeatIds.has(seat._id);
    const branchName = seat.branch ? (typeof seat.branch === 'object' ? seat.branch.name : seat.branch) : '';
    
    html += `
      <div class="seat-card-wrapper" style="position: relative;">
        <div class="card seat-card p-2 text-center" data-id="${seat._id}" style="border-top: 4px solid ${color}; border-radius: 8px; background: var(--color-surface); border-left: 1px solid var(--color-border); border-right: 1px solid var(--color-border); border-bottom: 1px solid var(--color-border); transition: all 0.2s ease; cursor: pointer; position: relative; min-height: 142px; height: 142px; display: flex; flex-direction: column; justify-content: space-between; padding: 10px 8px; ${isSelected ? 'box-shadow: 0 0 0 2.5px var(--color-primary); background: var(--color-primary-bg);' : ''}">
          
          <!-- Select Checkbox (Top Left) -->
          <div style="position: absolute; top: 6px; left: 6px; z-index: 2;" onclick="event.stopPropagation();">
            <label style="position: relative; display: inline-flex; align-items: center; justify-content: center; cursor: pointer; width: 22px; height: 22px; margin: 0;" title="Select Seat">
              <input type="checkbox" class="seat-select-cb" data-id="${seat._id}" ${isSelected ? 'checked' : ''} style="position: absolute; opacity: 0; width: 0; height: 0; margin: 0; pointer-events: none;">
              <span class="custom-select-circle" style="width: 20px; height: 20px; border-radius: 50%; border: 2px solid ${seat.zoneColor || 'var(--color-primary, #6c5ce7)'}; display: inline-flex; align-items: center; justify-content: center; transition: all 0.2s ease; background-color: ${isSelected ? (seat.zoneColor || 'var(--color-primary, #6c5ce7)') : 'transparent'}; color: #fff;">
                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" style="${isSelected ? 'display: block;' : 'display: none;'}"><polyline points="20 6 9 17 4 12"></polyline></svg>
              </span>
            </label>
          </div>

          <!-- Quick Action Dot Menu (Top Right) -->
          <div style="position: absolute; top: 4px; right: 6px; z-index: 2;" onclick="event.stopPropagation();">
            <button type="button" class="btn btn-ghost btn-sm btn-seat-quick-edit" data-id="${seat._id}" title="Desk Details & Actions" style="padding: 2px 4px; font-size: 0.75rem; opacity: 0.7;">
              👁️
            </button>
          </div>

          <!-- Seat Number & Type -->
          <div class="mt-1">
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary); letter-spacing: 0.5px;">
              ${escapeHTML(seat.seatNumber)}
            </h3>
            <div style="font-size: 0.7rem; color: var(--color-text-secondary); text-transform: uppercase; font-weight: 600; margin-top: 1px;">
              ${escapeHTML(seat.type || 'Regular')} ${seat.floor ? '• ' + escapeHTML(seat.floor) : ''}
            </div>
          </div>

          <!-- Status Badge -->
          <div class="my-1">
            <span class="badge" style="background-color: ${color}; color: #fff; font-size: 0.65rem; padding: 2px 6px; text-transform: uppercase; font-weight: 700; border-radius: 4px;">
              ${escapeHTML(seat.status)}
            </span>
          </div>

          <!-- Branch Tag if viewing all branches -->
          ${currentBranch === 'all' && branchName ? `
            <div class="text-truncate-single" style="font-size: 0.65rem; color: var(--color-primary); font-weight: 600; margin-top: 1px;" title="${escapeHTML(branchName)}">
              🏢 ${escapeHTML(branchName)}
            </div>
          ` : ''}

          <!-- Assigned Student Avatar / Name -->
          ${studentName ? `
            <div class="pt-1 border-top text-truncate-single" style="font-size: 0.72rem; font-weight: 700; color: var(--color-danger); max-width: 100%;" title="${escapeHTML(studentName)}">
              👤 ${escapeHTML(studentName)}
            </div>
          ` : `
            <div class="pt-1 border-top text-muted text-truncate-single" style="font-size: 0.7rem; font-weight: 500;">
              Vacant
            </div>
          `}
        </div>
      </div>
    `;
  });
  
  grid.innerHTML = html;
  
  // Bind Card Click & Quick Actions
  grid.querySelectorAll('.seat-card').forEach(card => {
    card.addEventListener('mouseenter', () => {
      card.style.transform = 'translateY(-3px)';
      if (!selectedSeatIds.has(card.getAttribute('data-id'))) {
        card.style.boxShadow = 'var(--shadow-md)';
      }
    });
    card.addEventListener('mouseleave', () => {
      card.style.transform = 'translateY(0)';
      if (!selectedSeatIds.has(card.getAttribute('data-id'))) {
        card.style.boxShadow = '';
      }
    });

    // Quick Edit Eye Button click -> Open 360° Modal
    card.querySelector('.btn-seat-quick-edit')?.addEventListener('click', (e) => {
      e.stopPropagation();
      const seatId = card.getAttribute('data-id');
      const seat = seatsData.find(s => s._id === seatId);
      if (seat) open360DeskDetailsModal(seat, container);
    });
    
    // Card Click -> Open 360° Desk Details Modal
    card.addEventListener('click', (e) => {
      if (e.target.closest('.seat-select-cb') || e.target.closest('.btn-seat-quick-edit') || e.target.closest('label') || e.target.closest('.custom-select-circle')) return;
      const seatId = card.getAttribute('data-id');
      const seat = seatsData.find(s => s._id === seatId);
      if (seat) open360DeskDetailsModal(seat, container);
    });
  });

  // Checkbox toggling (without full re-render)
  grid.querySelectorAll('.seat-select-cb').forEach(cb => {
    cb.addEventListener('change', (e) => {
      const sId = e.target.dataset.id;
      const card = e.target.closest('.seat-card');
      const label = e.target.closest('label');
      const circle = label?.querySelector('.custom-select-circle');
      const svg = circle?.querySelector('svg');
      const seat = seatsData.find(s => s._id === sId);
      const zoneColor = seat?.zoneColor || 'var(--color-primary, #6c5ce7)';

      if (e.target.checked) {
        selectedSeatIds.add(sId);
        if (card) {
          card.style.boxShadow = '0 0 0 2.5px var(--color-primary)';
          card.style.background = 'var(--color-primary-bg)';
        }
        if (circle) {
          circle.style.backgroundColor = zoneColor;
          circle.style.borderColor = zoneColor;
        }
        if (svg) {
          svg.style.display = 'block';
        }
      } else {
        selectedSeatIds.delete(sId);
        if (card) {
          card.style.boxShadow = '';
          card.style.background = 'var(--color-surface)';
        }
        if (circle) {
          circle.style.backgroundColor = 'transparent';
          circle.style.borderColor = zoneColor;
        }
        if (svg) {
          svg.style.display = 'none';
        }
      }
      updateBulkActionBar(container);
    });
  });

  // Quick edit button click
  grid.querySelectorAll('.btn-seat-quick-edit').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const sId = btn.dataset.id;
      const seat = seatsData.find(s => s._id === sId);
      if (seat) showEditSeatModal(seat, container);
    });
  });
}

function updateBulkActionBar(container) {
  const bar = container.querySelector('#bulk-action-bar');
  const countEl = container.querySelector('#bulk-selected-count');
  if (!bar || !countEl) return;

  if (selectedSeatIds.size > 0) {
    bar.style.display = 'flex';
    countEl.textContent = `${selectedSeatIds.size} Selected`;
  } else {
    bar.style.display = 'none';
  }
}

// ----------------------------------------------------
// TAB 2: STUDY CENTERS & BRANCHES OVERVIEW
// ----------------------------------------------------
function renderCentersTab(container) {
  const grid = container.querySelector('#branches-cards-grid');
  if (!grid) return;

  if (branchesList.length === 0) {
    UI.emptyState(grid, {
      icon: '🏢',
      title: 'No Study Branches Configured',
      description: 'Add your first study room or branch location to begin seating allocation.',
      actionText: '+ Add New Branch',
      onAction: () => showBranchModal(null, container)
    });
    return;
  }

  let html = '';
  branchesList.forEach(branch => {
    const isMain = branch.isMainBranch;
    const capacity = branch.totalSeats || branch.effectiveCapacity || 50;
    const occupied = branch.occupiedSeats || branch.activeStudents || 0;
    const occupancyPercent = capacity > 0 ? Math.min(100, Math.round((occupied / capacity) * 100)) : 0;

    let barColor = 'var(--color-success)';
    if (occupancyPercent >= 90) barColor = 'var(--color-danger)';
    else if (occupancyPercent >= 70) barColor = 'var(--color-warning)';

    const managerName = branch.manager?.name || 'Unassigned';

    let amenitiesHtml = '';
    if (branch.amenities && branch.amenities.length > 0) {
      amenitiesHtml = branch.amenities.map(a => {
        const found = ALL_AMENITIES.find(item => item.id.toLowerCase() === a.toLowerCase() || item.label.toLowerCase() === a.toLowerCase());
        const icon = found ? found.icon : '✨';
        const label = found ? found.label : a;
        return `
          <span style="display: inline-flex; align-items: center; gap: 4px; padding: 2px 8px; font-size: 0.75rem; border-radius: 4px; background: var(--color-bg-secondary); color: var(--color-text-secondary); border: 1px solid var(--color-border);">
            <span>${icon}</span> ${escapeHTML(label)}
          </span>
        `;
      }).join('');
    } else {
      amenitiesHtml = `<span style="font-size: 0.75rem; color: var(--color-text-muted);">Standard Facilities</span>`;
    }

    html += `
      <div class="card branch-hub-card" style="background: var(--color-surface); border-radius: var(--radius-lg); border: 1px solid var(--color-border); ${isMain ? 'box-shadow: 0 4px 16px rgba(108, 92, 231, 0.15); border-color: var(--color-primary);' : ''} display: flex; flex-direction: column; overflow: hidden;">
        
        <!-- Header -->
        <div style="padding: 1.25rem; border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover);">
          <div class="d-flex justify-content-between align-items-start gap-2">
            <div>
              <h3 style="margin: 0; font-size: 1.25rem; font-weight: 700; color: var(--color-text-primary);">
                ${escapeHTML(branch.name)}
              </h3>
              <div class="text-xs text-muted mt-1">
                📍 ${escapeHTML(branch.city || '')} ${branch.state ? ', ' + escapeHTML(branch.state) : ''}
              </div>
            </div>
            <span class="badge badge-primary font-monospace" style="font-size: 0.8rem;">
              ${escapeHTML(branch.code || 'BR')}
            </span>
          </div>

          ${isMain ? `
            <div class="mt-2">
              <span class="badge" style="background: rgba(253, 203, 110, 0.2); color: #d48806; border: 1px solid rgba(253, 203, 110, 0.4); font-size: 0.75rem;">
                ⭐ Primary Main Campus
              </span>
            </div>
          ` : ''}
        </div>

        <!-- Body -->
        <div style="padding: 1.25rem; flex: 1; display: flex; flex-direction: column; gap: 12px;">
          
          <!-- Occupancy Progress Gauge -->
          <div>
            <div class="d-flex justify-content-between text-xs mb-1">
              <span style="font-weight: 600;">Seating Occupancy</span>
              <span style="font-weight: 700; color: ${barColor};">${occupancyPercent}% (${occupied}/${capacity} seats)</span>
            </div>
            <div style="width: 100%; height: 8px; background: var(--color-bg-secondary); border-radius: 4px; overflow: hidden;">
              <div style="width: ${occupancyPercent}%; height: 100%; background: ${barColor}; transition: width 0.3s ease;"></div>
            </div>
          </div>

          <!-- Contact & Manager -->
          <div class="text-xs text-muted" style="line-height: 1.6;">
            <div>👤 Manager: <strong>${escapeHTML(managerName)}</strong></div>
            <div>📞 Support: <strong>${escapeHTML(branch.phone || '-')}</strong></div>
            <div>✉️ Email: <strong>${escapeHTML(branch.email || '-')}</strong></div>
          </div>

          <!-- Amenities -->
          <div>
            <div class="text-xs text-muted mb-1" style="font-weight: 600;">Amenities:</div>
            <div class="d-flex flex-wrap gap-1">
              ${amenitiesHtml}
            </div>
          </div>

        </div>

        <!-- Footer Actions -->
        <div style="padding: 10px 1.25rem; background: var(--color-surface-hover); border-top: 1px solid var(--color-divider); display: flex; justify-content: space-between; align-items: center; gap: 6px;">
          <button type="button" class="btn btn-sm btn-primary btn-branch-view-seats" data-id="${branch._id}" style="font-weight: 600; font-size: 0.8rem;">
            💺 View Seats Matrix
          </button>
          <div class="d-flex gap-1">
            <button type="button" class="btn btn-sm btn-outline-secondary btn-branch-edit" data-id="${branch._id}" style="font-size: 0.8rem;">
              ✏️ Edit
            </button>
            <button type="button" class="btn btn-sm btn-outline-danger btn-branch-delete" data-id="${branch._id}" style="font-size: 0.8rem;" title="Delete Branch">
              🗑️
            </button>
          </div>
        </div>

      </div>
    `;
  });

  grid.innerHTML = html;

  // View seats matrix button (switches to Tab 1 filtered directly to this branch)
  grid.querySelectorAll('.btn-branch-view-seats').forEach(btn => {
    btn.addEventListener('click', () => {
      const bId = btn.dataset.id;
      currentBranch = bId;
      container.querySelector('.hub-tab-btn[data-tab="seats"]').click();
      const select = container.querySelector('#seat-branch-selector');
      if (select) select.value = bId;
      loadStats(container);
      loadZones(container);
      loadSeats(container);
    });
  });

  // Edit branch
  grid.querySelectorAll('.btn-branch-edit').forEach(btn => {
    btn.addEventListener('click', () => {
      const bId = btn.dataset.id;
      const b = branchesList.find(item => item._id === bId);
      if (b) showBranchModal(b, container);
    });
  });

  // Delete branch
  grid.querySelectorAll('.btn-branch-delete').forEach(btn => {
    btn.addEventListener('click', () => {
      const bId = btn.dataset.id;
      const b = branchesList.find(item => item._id === bId);
      if (b) handleDeleteBranch(b, container);
    });
  });
}

// ----------------------------------------------------
// TAB 3: MULTI-BRANCH ANALYTICS & COMPARISON
// ----------------------------------------------------
function renderAnalyticsTab(container) {
  const tbody = container.querySelector('#analytics-table-body');
  if (!tbody) return;

  if (branchesList.length === 0) {
    tbody.innerHTML = `<tr><td colspan="8" class="text-center p-4 text-muted">No branch data available</td></tr>`;
    return;
  }

  tbody.innerHTML = branchesList.map((b, idx) => {
    const capacity = b.totalSeats || b.effectiveCapacity || 50;
    const occupied = b.occupiedSeats || b.activeStudents || 0;
    const available = Math.max(0, capacity - occupied);
    const rate = capacity > 0 ? Math.round((occupied / capacity) * 100) : 0;
    const estRev = occupied * 1200; // Estimated monthly fee

    return `
      <tr>
        <td>
          <div style="font-weight: 700; color: var(--color-text-primary);">${escapeHTML(b.name)}</div>
          <div class="text-xs text-muted">${escapeHTML(b.city || '')} ${b.isMainBranch ? '• ⭐ Main Campus' : ''}</div>
        </td>
        <td><span class="badge badge-primary font-monospace">${escapeHTML(b.code || '')}</span></td>
        <td>${escapeHTML(b.manager?.name || 'Unassigned')}</td>
        <td><strong>${capacity}</strong></td>
        <td><span class="text-danger font-weight-bold">${occupied}</span></td>
        <td><span class="text-success font-weight-bold">${available}</span></td>
        <td>
          <div class="d-flex align-items-center gap-2">
            <div style="width: 60px; height: 6px; background: var(--color-bg-secondary); border-radius: 3px; overflow: hidden;">
              <div style="width: ${rate}%; height: 100%; background: ${rate > 80 ? 'var(--color-danger)' : 'var(--color-success)'};"></div>
            </div>
            <strong>${rate}%</strong>
          </div>
        </td>
        <td class="text-right font-weight-bold" style="color: var(--color-primary);">
          ₹${estRev.toLocaleString('en-IN')}
        </td>
      </tr>
    `;
  }).join('');
}

// ----------------------------------------------------
// Cross-Branch Student Transfer Modal
// ----------------------------------------------------
function showCrossTransferModal(container) {
  const content = document.createElement('div');
  const branchOptions = branchesList.map(b => `
    <option value="${b._id}">${escapeHTML(b.name)} (${escapeHTML(b.code || '')})</option>
  `).join('');

  content.innerHTML = `
    <div style="font-family: 'Outfit', sans-serif;">
      <p class="small text-muted mb-3">
        Move a student from their current seat/branch to a new study branch and seat instantly.
      </p>

      <!-- Step 1: Select Student -->
      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">1. Search Student to Transfer *</label>
        <input type="text" id="transfer-student-search" class="form-control" placeholder="Type student name or ID...">
        <div id="transfer-student-results" style="max-height: 140px; overflow-y: auto; border: 1px solid var(--color-border); border-radius: 6px; margin-top: 4px; padding: 6px; display: none;"></div>
        <input type="hidden" id="selected-transfer-student-id">
        <div id="selected-transfer-student-info" class="p-2 mt-2" style="display: none; background: rgba(99, 102, 241, 0.1); border-radius: 6px; font-size: 0.85rem;"></div>
      </div>

      <!-- Step 2: Target Branch & Seat -->
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">2. Destination Branch *</label>
          <select id="transfer-target-branch" class="form-select form-control">
            <option value="">-- Choose Target Center --</option>
            ${branchOptions}
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">3. Target Vacant Seat *</label>
          <select id="transfer-target-seat" class="form-select form-control" disabled>
            <option value="">Select branch first</option>
          </select>
        </div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="button" class="btn btn-primary" id="btn-execute-transfer" disabled style="font-weight: 700;">
          🔄 Confirm & Complete Transfer
        </button>
      </div>
    </div>
  `;

  const tModal = new Modal({
    title: '🔄 Cross-Branch Student Transfer',
    content,
    size: 'md'
  });
  tModal.show();

  const searchInput = content.querySelector('#transfer-student-search');
  const resultsBox = content.querySelector('#transfer-student-results');
  const hiddenStudentId = content.querySelector('#selected-transfer-student-id');
  const studentInfoBox = content.querySelector('#selected-transfer-student-info');
  const targetBranchSelect = content.querySelector('#transfer-target-branch');
  const targetSeatSelect = content.querySelector('#transfer-target-seat');
  const execBtn = content.querySelector('#btn-execute-transfer');

  // Search student
  let sTimer;
  searchInput.addEventListener('input', () => {
    clearTimeout(sTimer);
    sTimer = setTimeout(async () => {
      const q = searchInput.value.trim();
      if (!q) { resultsBox.style.display = 'none'; return; }
      try {
        const res = await api.get(`/api/students?search=${encodeURIComponent(q)}&limit=8`);
        const students = res.data?.students || [];
        if (students.length === 0) {
          resultsBox.innerHTML = `<div class="p-2 text-muted small">No students found</div>`;
          resultsBox.style.display = 'block';
          return;
        }

        resultsBox.innerHTML = students.map(s => `
          <div class="p-2 border-bottom d-flex justify-content-between align-items-center btn-pick-transfer-student" data-id="${s._id}" data-name="${escapeHTML(s.name)}" data-idnum="${escapeHTML(s.studentId || '')}" data-seat="${escapeHTML(s.seat?.seatNumber || 'No Seat')}" style="cursor: pointer;">
            <div>
              <strong>${escapeHTML(s.name)}</strong> (${escapeHTML(s.studentId || '')})
              <div class="text-xs text-muted">Current Seat: ${escapeHTML(s.seat?.seatNumber || 'None')}</div>
            </div>
            <button type="button" class="btn btn-xs btn-primary">Select</button>
          </div>
        `).join('');
        resultsBox.style.display = 'block';

        resultsBox.querySelectorAll('.btn-pick-transfer-student').forEach(el => {
          el.addEventListener('click', () => {
            hiddenStudentId.value = el.dataset.id;
            studentInfoBox.innerHTML = `👤 Selected: <strong>${el.dataset.name}</strong> (ID: ${el.dataset.idnum}) • Current Seat: <strong>${el.dataset.seat}</strong>`;
            studentInfoBox.style.display = 'block';
            resultsBox.style.display = 'none';
            checkReady();
          });
        });
      } catch (e) {}
    }, 250);
  });

  // Load vacant seats when target branch changes
  targetBranchSelect.addEventListener('change', async () => {
    const bId = targetBranchSelect.value;
    if (!bId) {
      targetSeatSelect.innerHTML = `<option value="">Select branch first</option>`;
      targetSeatSelect.disabled = true;
      checkReady();
      return;
    }

    targetSeatSelect.innerHTML = `<option value="">Loading available seats...</option>`;
    targetSeatSelect.disabled = true;

    try {
      const res = await api.get(`/api/seats?branch=${bId}&status=available`);
      const seats = res.data || [];
      if (seats.length === 0) {
        targetSeatSelect.innerHTML = `<option value="">No vacant seats at this branch</option>`;
        targetSeatSelect.disabled = true;
      } else {
        targetSeatSelect.innerHTML = `<option value="">-- Choose Vacant Seat (${seats.length} available) --</option>` +
          seats.map(s => `<option value="${s._id}">Seat ${escapeHTML(s.seatNumber)} (${escapeHTML(s.zone)})</option>`).join('');
        targetSeatSelect.disabled = false;
      }
    } catch (e) {
      targetSeatSelect.innerHTML = `<option value="">Failed to load seats</option>`;
    }
    checkReady();
  });

  targetSeatSelect.addEventListener('change', checkReady);

  function checkReady() {
    execBtn.disabled = !(hiddenStudentId.value && targetSeatSelect.value);
  }

  execBtn.addEventListener('click', async () => {
    Loading.button(execBtn, true);
    try {
      const studentId = hiddenStudentId.value;
      const seatId = targetSeatSelect.value;
      const res = await api.post(`/api/seats/${seatId}/assign`, { studentId });
      if (res.success) {
        Toast.success('Student transferred to target branch & seat successfully!');
        tModal.close();
        loadStats(container);
        loadSeats(container);
      } else {
        Toast.error(res.message);
      }
    } catch (err) {
      Toast.error(err.message || 'Transfer failed');
    } finally {
      Loading.button(execBtn, false);
    }
  });
}

// ----------------------------------------------------
// Branch Create / Edit Modal
// ----------------------------------------------------
function showBranchModal(branch = null, container) {
  const isEdit = Boolean(branch && branch._id);
  const selectedAmenities = new Set(branch?.amenities || ['AC', 'WiFi', 'CCTV', 'Power Backup', 'RO Water', 'Locker']);
  const content = document.createElement('div');

  let managerOptions = `<option value="">-- Select Manager (Optional) --</option>`;
  managersList.forEach(m => {
    const sel = (branch?.manager?._id === m._id || branch?.manager === m._id) ? 'selected' : '';
    managerOptions += `<option value="${m._id}" ${sel}>${escapeHTML(m.name)} - ${escapeHTML(m.phone || m.email)}</option>`;
  });

  let amenitiesCheckboxes = ALL_AMENITIES.map(amenity => {
    const checked = selectedAmenities.has(amenity.id) || selectedAmenities.has(amenity.label) ? 'checked' : '';
    return `
      <label style="display: flex; align-items: center; gap: 8px; font-size: 0.8rem; background: var(--color-bg-primary); padding: 6px 10px; border-radius: 6px; border: 1px solid var(--color-border); cursor: pointer;">
        <input type="checkbox" name="amenities" value="${amenity.id}" ${checked}>
        <span>${amenity.icon}</span>
        <span>${escapeHTML(amenity.label)}</span>
      </label>
    `;
  }).join('');

  content.innerHTML = `
    <form id="branchModalForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Branch / Center Name *</label>
          <input type="text" class="form-control" name="name" required value="${escapeHTML(branch?.name || '')}" placeholder="e.g. South Extension Campus">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Branch Code *</label>
          <input type="text" class="form-control" name="code" required value="${escapeHTML(branch?.code || '')}" placeholder="e.g. BR-SOUTH" style="text-transform: uppercase;">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Assigned Center Manager</label>
        <select class="form-select form-control" name="manager">
          ${managerOptions}
        </select>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Contact Mobile</label>
          <input type="tel" class="form-control" name="phone" value="${escapeHTML(branch?.phone || '')}" placeholder="+91 98765 43210">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Email</label>
          <input type="email" class="form-control" name="email" value="${escapeHTML(branch?.email || '')}" placeholder="branch@studylib.com">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Street Address</label>
        <input type="text" class="form-control" name="address" value="${escapeHTML(branch?.address || '')}" placeholder="Building name, street, metro pillar...">
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">City</label>
          <input type="text" class="form-control" name="city" value="${escapeHTML(branch?.city || '')}" placeholder="City">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Total Seating Capacity</label>
          <input type="number" class="form-control" name="effectiveCapacity" value="${branch?.effectiveCapacity || branch?.totalSeats || 50}" min="1">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Amenities & Infrastructure</label>
        <div style="display: flex; flex-wrap: wrap; gap: 6px;">
          ${amenitiesCheckboxes}
        </div>
      </div>

      <div class="mb-3 p-2" style="background: rgba(253, 203, 110, 0.1); border-radius: 6px; border: 1px solid rgba(253, 203, 110, 0.25);">
        <label class="form-check-label" style="font-size: 0.85rem; font-weight: 600; cursor: pointer; display: flex; align-items: center; gap: 8px;">
          <input type="checkbox" class="form-check-input" name="isMainBranch" value="true" ${branch?.isMainBranch ? 'checked' : ''} style="cursor: pointer;">
          <span>⭐ Designate as Primary Main Campus Branch</span>
        </label>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-submit-branch-form" style="font-weight: 600;">
          ${isEdit ? '💾 Update Branch' : '+ Create Branch Center'}
        </button>
      </div>
    </form>
  `;

  const bModal = new Modal({
    title: isEdit ? `✏️ Edit Branch: ${branch.name}` : '🏢 Create New Study Center Branch',
    content,
    size: 'md'
  });
  bModal.show();

  content.querySelector('#branchModalForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = content.querySelector('#btn-submit-branch-form');
    Loading.button(btn, true);

    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData.entries());
    data.amenities = Array.from(content.querySelectorAll('input[name="amenities"]:checked')).map(cb => cb.value);
    data.isMainBranch = Boolean(content.querySelector('input[name="isMainBranch"]:checked'));

    try {
      let res;
      if (isEdit) res = await api.put(`/api/branches/${branch._id}`, data);
      else res = await api.post('/api/branches', data);

      if (res.success) {
        Toast.success(res.message);
        bModal.close();
        await loadInitialHubData(container);
      } else {
        Toast.error(res.message);
      }
    } catch (err) {
      Toast.error(err.message || 'Failed to save branch');
    } finally {
      Loading.button(btn, false);
    }
  });
}

async function handleDeleteBranch(branch, container) {
  const isMain = branch.isMainBranch;
  const ok = await Confirm.show({
    title: `Delete Branch: ${branch.name}`,
    message: isMain
      ? `Are you sure you want to delete "${branch.name}" (${branch.code})? Since this is currently the primary main campus, another active branch will automatically become the primary campus.`
      : `Are you sure you want to delete branch "${branch.name}" (${branch.code})? Existing seat configurations will be archived.`,
    danger: true
  });
  if (ok) {
    try {
      const res = await api.delete(`/api/branches/${branch._id}`);
      if (res.success) {
        Toast.success(res.message || 'Branch deleted successfully');
        await loadInitialHubData(container);
      } else {
        Toast.error(res.message || 'Failed to delete branch');
      }
    } catch (e) {
      Toast.error(e.message || 'Failed to delete branch');
    }
  }
}

// ----------------------------------------------------
// Modals for Seat CRUD (Details, Edit, Add, Bulk, Assign)
// ----------------------------------------------------
function showSeatDetailModal(seat, container) {
  const content = document.createElement('div');
  const color = getStatusColor(seat.status);
  const student = seat.currentStudent;
  const branchName = seat.branch ? (typeof seat.branch === 'object' ? seat.branch.name : 'Branch ID: ' + seat.branch) : 'Unassigned';

  content.innerHTML = `
    <div style="font-family: 'Outfit', sans-serif;">
      
      <!-- Top Card Header -->
      <div class="d-flex justify-content-between align-items-start mb-3 pb-3 border-bottom">
        <div>
          <div class="d-flex align-items-center gap-2">
            <h3 style="margin: 0; font-size: 1.4rem; font-weight: 800;">Seat ${escapeHTML(seat.seatNumber)}</h3>
            <span class="badge" style="background-color: ${color}; color: #fff; font-size: 0.75rem; text-transform: uppercase; padding: 3px 8px; border-radius: 4px;">
              ${escapeHTML(seat.status)}
            </span>
          </div>
          <div class="text-muted small mt-1">
            Zone: <strong>${escapeHTML(seat.zone)}</strong> • Floor: <strong>${escapeHTML(seat.floor || 'Ground')}</strong> • Type: <strong>${escapeHTML(seat.type)}</strong>
          </div>
        </div>
        <div class="text-end">
          <div class="text-xs text-muted">Branch:</div>
          <span class="badge badge-primary">${escapeHTML(branchName)}</span>
        </div>
      </div>

      <!-- Current Student Card (If occupied) -->
      ${student ? `
        <div class="p-3 mb-3" style="background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.2); border-radius: var(--radius-md);">
          <div class="d-flex align-items-center justify-content-between">
            <div class="d-flex align-items-center gap-3">
              <div style="width: 46px; height: 46px; border-radius: 50%; background: #ef4444; color: #fff; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 1.2rem;">
                ${escapeHTML(student.name.charAt(0).toUpperCase())}
              </div>
              <div>
                <h4 style="margin: 0; font-size: 1.05rem; font-weight: 700; color: var(--color-text-primary);">
                  ${escapeHTML(student.name)}
                </h4>
                <div class="text-xs text-muted">
                  ID: <span class="font-monospace fw-bold">${escapeHTML(student.studentId || '-')}</span> ${student.phone ? '• Phone: ' + escapeHTML(student.phone) : ''}
                </div>
              </div>
            </div>
            <button type="button" class="btn btn-sm btn-outline-danger btn-detail-release" style="font-weight: 600;">
              🔓 Release / Vacate
            </button>
          </div>
        </div>
      ` : `
        <div class="p-3 mb-3 text-center" style="background: rgba(34, 197, 94, 0.08); border: 1px dashed rgba(34, 197, 94, 0.3); border-radius: var(--radius-md);">
          <div class="text-success font-weight-bold mb-1">🟢 Seat is Currently Vacant & Available</div>
          <p class="text-muted text-xs mb-2">You can assign this seat to any registered active student.</p>
          <button type="button" class="btn btn-sm btn-success btn-detail-assign" style="font-weight: 600;">
            👤 Assign Student to This Seat
          </button>
        </div>
      `}

      <!-- Seat Specifications -->
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 10px;">
        <div style="background: var(--color-bg-primary); padding: 10px; border-radius: 6px; border: 1px solid var(--color-border);">
          <div class="text-xs text-muted">Monthly Rate</div>
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-text-primary);">
            ₹${seat.monthlyRate || 0}/mo
          </div>
        </div>
        <div style="background: var(--color-bg-primary); padding: 10px; border-radius: 6px; border: 1px solid var(--color-border);">
          <div class="text-xs text-muted">Amenities</div>
          <div style="font-size: 0.8rem; font-weight: 600; color: var(--color-text-primary);">
            ${seat.amenities && seat.amenities.length > 0 ? seat.amenities.join(', ') : 'Standard Power & Light'}
          </div>
        </div>
      </div>

      <!-- Action Buttons Footer -->
      <div class="d-flex justify-content-between align-items-center pt-3 border-top">
        <button type="button" class="btn btn-outline-danger btn-sm btn-detail-delete" style="font-weight: 600;">
          🗑️ Delete Seat
        </button>
        <div class="d-flex gap-2">
          <button type="button" class="btn btn-outline-primary btn-sm btn-detail-edit" style="font-weight: 600;">
            ✏️ Edit / Modify Seat
          </button>
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">
            Close
          </button>
        </div>
      </div>
    </div>
  `;

  const sModal = new Modal({
    title: `Seat Overview: ${seat.seatNumber}`,
    content,
    size: 'md'
  });
  sModal.show();

  // Release button
  content.querySelector('.btn-detail-release')?.addEventListener('click', async () => {
    sModal.close();
    Confirm.show({
      title: 'Release Seat',
      message: `Unassign student from Seat ${seat.seatNumber} and mark seat as available?`,
      danger: false,
      onConfirm: async () => {
        try {
          const res = await api.post(`/api/seats/${seat._id}/release`);
          if (res.success) {
            Toast.success(res.message);
            loadStats(container);
            loadSeats(container);
          }
        } catch (e) { Toast.error(e.message); }
      }
    });
  });

  // Assign button
  content.querySelector('.btn-detail-assign')?.addEventListener('click', () => {
    sModal.close();
    showAssignStudentModal(seat, container);
  });

  // Edit button
  content.querySelector('.btn-detail-edit')?.addEventListener('click', () => {
    sModal.close();
    showEditSeatModal(seat, container);
  });

  // Delete button
  content.querySelector('.btn-detail-delete')?.addEventListener('click', () => {
    sModal.close();
    Confirm.show({
      title: 'Delete Seat',
      message: `Are you sure you want to permanently delete Seat ${seat.seatNumber}?`,
      danger: true,
      onConfirm: async () => {
        try {
          const res = await api.delete(`/api/seats/${seat._id}`);
          if (res.success) {
            Toast.success(res.message);
            loadStats(container);
            loadZones(container);
            loadSeats(container);
          }
        } catch (e) { Toast.error(e.message); }
      }
    });
  });
}

function showEditSeatModal(seat, container) {
  const content = document.createElement('div');
  const branchOptions = branchesList.map(b => `
    <option value="${b._id}" ${seat.branch && (seat.branch === b._id || seat.branch._id === b._id) ? 'selected' : ''}>
      ${escapeHTML(b.name)} (${escapeHTML(b.code || '')})
    </option>
  `).join('');

  content.innerHTML = `
    <form id="editSeatForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Number *</label>
          <input type="text" class="form-control" name="seatNumber" value="${escapeHTML(seat.seatNumber)}" required placeholder="e.g. A-01">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Branch Location</label>
          <select class="form-select form-control" name="branch">
            <option value="">-- No Specific Branch --</option>
            ${branchOptions}
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Study Zone *</label>
          <input type="text" class="form-control" name="zone" value="${escapeHTML(seat.zone)}" required placeholder="e.g. Zone A (AC), Boys Hall">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Floor / Section</label>
          <input type="text" class="form-control" name="floor" value="${escapeHTML(seat.floor || '')}" placeholder="e.g. Ground Floor, 1st Floor">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Type</label>
          <select class="form-select form-control" name="type">
            <option value="regular" ${seat.type === 'regular' ? 'selected' : ''}>Regular Desk</option>
            <option value="premium" ${seat.type === 'premium' ? 'selected' : ''}>Premium Cabin</option>
            <option value="cabin" ${seat.type === 'cabin' ? 'selected' : ''}>Private Cube / Cabin</option>
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Status</label>
          <select class="form-select form-control" name="status">
            <option value="available" ${seat.status === 'available' ? 'selected' : ''}>🟢 Available</option>
            <option value="occupied" ${seat.status === 'occupied' ? 'selected' : ''}>🔴 Occupied</option>
            <option value="reserved" ${seat.status === 'reserved' ? 'selected' : ''}>🟡 Reserved</option>
            <option value="maintenance" ${seat.status === 'maintenance' ? 'selected' : ''}>⚪ Under Maintenance</option>
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Monthly Fee (₹)</label>
          <input type="number" class="form-control" name="monthlyRate" value="${seat.monthlyRate || ''}" placeholder="e.g. 1200">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Amenities (Comma separated)</label>
          <input type="text" class="form-control" name="amenities" value="${seat.amenities ? escapeHTML(seat.amenities.join(', ')) : ''}" placeholder="Power Socket, Reading Light">
        </div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-submit-seat-edit" style="font-weight: 600;">
          💾 Save Seat Modifications
        </button>
      </div>
    </form>
  `;

  const eModal = new Modal({
    title: `✏️ Edit Seat: ${seat.seatNumber}`,
    content,
    size: 'md'
  });
  eModal.show();

  content.querySelector('#editSeatForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = content.querySelector('#btn-submit-seat-edit');
    Loading.button(btn, true);

    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData.entries());

    const oldStatus = seat.status;
    const targetStatus = data.status || oldStatus;

    try {
      await OptimisticUI.execute({
        applyState: () => {
          seat.status = targetStatus;
          const sObj = seatsData.find(s => s._id === seat._id);
          if (sObj) sObj.status = targetStatus;
          renderSeatsGrid(seatsData, container);
        },
        rollbackState: () => {
          seat.status = oldStatus;
          const sObj = seatsData.find(s => s._id === seat._id);
          if (sObj) sObj.status = oldStatus;
          renderSeatsGrid(seatsData, container);
        },
        apiCall: () => api.put(`/api/seats/${seat._id}`, data),
        onSuccess: (res) => {
          Toast.success(res.message || 'Seat updated successfully');
          eModal.close();
          loadStats(container);
          loadZones(container);
          loadSeats(container);
        }
      });
    } catch (err) {
      // Handled by OptimisticUI
    } finally {
      Loading.button(btn, false);
    }
  });
}

function showAddSingleSeatModal(container) {
  const c = container || document.querySelector('.centers-seats-hub-page') || document;
  const content = document.createElement('div');
  const branchOptions = branchesList.map(b => `
    <option value="${b._id}" ${currentBranch === b._id ? 'selected' : ''}>
      ${escapeHTML(b.name)} (${escapeHTML(b.code || '')})
    </option>
  `).join('');

  content.innerHTML = `
    <form id="addSingleSeatForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Number *</label>
          <input type="text" class="form-control" name="seatNumber" required placeholder="e.g. A-01 or 105">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Branch Location</label>
          <select class="form-select form-control" name="branch">
            <option value="">-- Main / Default Branch --</option>
            ${branchOptions}
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Study Zone *</label>
          <input type="text" class="form-control" name="zone" value="${escapeHTML(currentZone || 'Zone A')}" required placeholder="e.g. Zone A (AC)">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Floor / Section</label>
          <input type="text" class="form-control" name="floor" placeholder="e.g. Ground Floor">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Type</label>
          <select class="form-select form-control" name="type">
            <option value="regular">Regular Desk</option>
            <option value="premium">Premium Desk</option>
            <option value="cabin">Private Cabin</option>
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Monthly Rate (₹)</label>
          <input type="number" class="form-control" name="monthlyRate" placeholder="e.g. 1200">
        </div>
      </div>

      <div class="form-group mb-3">
        <label class="form-label" style="font-weight: 600;">Amenities (Comma separated)</label>
        <input type="text" class="form-control" name="amenities" placeholder="Power Socket, Reading Light, Ergonomic Chair">
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-create-single-seat" style="font-weight: 600;">
          + Create Seat
        </button>
      </div>
    </form>
  `;

  const aModal = new Modal({
    title: '➕ Add Single Custom Seat',
    content,
    size: 'md'
  });
  aModal.show();

  content.querySelector('#addSingleSeatForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = content.querySelector('#btn-create-single-seat');
    Loading.button(btn, true);

    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData.entries());

    try {
      const res = await api.post('/api/seats', data);
      if (res.success) {
        Toast.success(res.message);
        aModal.close();
        loadStats(c);
        loadZones(c);
        loadSeats(c);
      } else {
        Toast.error(res.message);
      }
    } catch (err) {
      Toast.error(err.message || 'Failed to create seat');
    } finally {
      Loading.button(btn, false);
    }
  });
}

function showAddSeatsModal(container) {
  const c = container || document.querySelector('.centers-seats-hub-page') || document;
  const content = document.createElement('div');
  const branchOptions = branchesList.map(b => `
    <option value="${b._id}" ${currentBranch === b._id ? 'selected' : ''}>
      ${escapeHTML(b.name)} (${escapeHTML(b.code || '')})
    </option>
  `).join('');

  content.innerHTML = `
    <form id="bulkAddSeatsForm" class="p-1">
      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Target Branch Location</label>
          <select class="form-select form-control" name="branch">
            <option value="">-- Main / Default Branch --</option>
            ${branchOptions}
          </select>
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Study Zone *</label>
          <input type="text" name="zone" class="form-control" required placeholder="e.g. Zone A (AC), Boys Section" value="${escapeHTML(currentZone || '')}">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Floor / Wing</label>
          <input type="text" name="floor" class="form-control" placeholder="e.g. Ground Floor">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Seat Type</label>
          <select name="type" class="form-select form-control">
            <option value="regular">Regular Desk</option>
            <option value="premium">Premium Desk</option>
            <option value="cabin">Private Cabin</option>
          </select>
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 10px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Prefix (Optional)</label>
          <input type="text" name="prefix" class="form-control" placeholder="e.g. A- or B-">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Start Number *</label>
          <input type="number" name="startNumber" class="form-control" required min="1" value="1">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Total Quantity *</label>
          <input type="number" name="count" class="form-control" required min="1" max="250" value="20">
        </div>
      </div>

      <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 12px;">
        <div>
          <label class="form-label" style="font-weight: 600;">Monthly Fee (₹)</label>
          <input type="number" name="monthlyRate" class="form-control" placeholder="e.g. 1200">
        </div>
        <div>
          <label class="form-label" style="font-weight: 600;">Amenities</label>
          <input type="text" name="amenities" class="form-control" placeholder="Power Socket, Reading Light">
        </div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="submit" class="btn btn-primary" id="btn-submit-bulk-seats" style="font-weight: 600;">
          ⚡ Generate & Save Seats
        </button>
      </div>
    </form>
  `;
  
  const modal = new Modal({
    title: '⚡ Bulk Add Seats Generation',
    content,
    size: 'md'
  });
  modal.show();
  
  content.querySelector('#bulkAddSeatsForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = content.querySelector('#btn-submit-bulk-seats');
    Loading.button(btn, true);

    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData.entries());
    data.startNumber = parseInt(data.startNumber, 10);
    data.count = parseInt(data.count, 10);
    
    try {
      const res = await api.post('/api/seats/bulk', data);
      if (res.success) {
        Toast.success(res.message);
        modal.close();
        loadStats(c);
        loadZones(c);
        loadSeats(c);
      } else {
        Toast.error(res.message);
      }
    } catch (error) {
      Toast.error(error.message || 'Failed to create seats');
    } finally {
      Loading.button(btn, false);
    }
  });
}

async function showAssignStudentModal(seat, container) {
  const content = document.createElement('div');
  content.innerHTML = `
    <div style="font-family: 'Outfit', sans-serif;">
      <div class="mb-3">
        <label class="form-label" style="font-weight: 600;">Search Active Student</label>
        <input type="text" id="assign-student-search" class="form-control" placeholder="Search student by name, phone, or ID...">
      </div>

      <div id="assign-student-results" style="max-height: 250px; overflow-y: auto; border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 8px;">
        <div class="text-center p-3 text-muted small">Type student name or mobile number above...</div>
      </div>

      <div class="d-flex justify-content-end gap-2 mt-4 pt-3 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
      </div>
    </div>
  `;

  const aModal = new Modal({
    title: `👤 Assign Student to Seat ${seat.seatNumber}`,
    content,
    size: 'md'
  });
  aModal.show();

  const searchInput = content.querySelector('#assign-student-search');
  const resultsContainer = content.querySelector('#assign-student-results');

  searchInput?.addEventListener('input', debounce(async () => {
    const q = searchInput.value.trim();
    if (!q) {
      resultsContainer.innerHTML = `<div class="text-center p-3 text-muted small">Type student name or mobile number above...</div>`;
      return;
    }

    Loading.skeleton(resultsContainer, 'table');
      try {
        const res = await api.get(`/api/students?search=${encodeURIComponent(q)}&limit=10`);
        const students = res.data?.students || [];

        if (students.length === 0) {
          resultsContainer.innerHTML = `<div class="text-center p-3 text-muted small">No active students found matching "${escapeHTML(q)}"</div>`;
          return;
        }

        resultsContainer.innerHTML = students.map(st => `
          <div class="p-2 d-flex justify-content-between align-items-center mb-1 border-bottom" style="border-radius: 4px;">
            <div>
              <div style="font-weight: 700; color: var(--color-text-primary); font-size: 0.95rem;">${escapeHTML(st.name)}</div>
              <div class="text-xs text-muted">ID: <strong>${escapeHTML(st.studentId || '-')}</strong> • 📞 ${escapeHTML(st.phone || '-')}</div>
            </div>
            <button type="button" class="btn btn-sm btn-primary btn-select-student" data-id="${st._id}" style="font-size: 0.75rem; font-weight: 600;">
              Assign
            </button>
          </div>
        `).join('');

        resultsContainer.querySelectorAll('.btn-select-student').forEach(btn => {
          btn.addEventListener('click', async () => {
            const studentId = btn.dataset.id;
            try {
              const assignRes = await api.post(`/api/seats/${seat._id}/assign`, { studentId });
              if (assignRes.success) {
                Toast.success(assignRes.message);
                aModal.close();
                loadStats(container);
                loadSeats(container);
              } else {
                Toast.error(assignRes.message);
              }
            } catch (err) {
              Toast.error(err.message || 'Failed to assign student');
            }
          });
        });
      } catch (err) {
        resultsContainer.innerHTML = `<div class="text-danger p-2">Search failed</div>`;
      }
    }, 250));
}

// ----------------------------------------------------
// Bulk Actions Handlers
// ----------------------------------------------------
async function handleBulkDelete(container) {
  const ids = Array.from(selectedSeatIds);
  Confirm.show({
    title: 'Bulk Delete Seats',
    message: `Are you sure you want to permanently delete ${ids.length} selected seat(s)? Occupied seats cannot be deleted.`,
    danger: true,
    onConfirm: async () => {
      try {
        const res = await api.post('/api/seats/bulk-delete', { seatIds: ids });
        if (res.success) {
          Toast.success(res.message);
          selectedSeatIds.clear();
          updateBulkActionBar(container);
          loadStats(container);
          loadZones(container);
          loadSeats(container);
        } else {
          Toast.error(res.message);
        }
      } catch (err) {
        Toast.error(err.message || 'Bulk delete failed');
      }
    }
  });
}

function handleBulkRezone(container) {
  const ids = Array.from(selectedSeatIds);
  const newZone = prompt(`Enter new Zone name for ${ids.length} selected seats:`);
  if (!newZone || !newZone.trim()) return;

  api.post('/api/seats/bulk-update', {
    seatIds: ids,
    updates: { zone: newZone.trim() }
  }).then(res => {
    Toast.success(res.message || 'Zones updated');
    selectedSeatIds.clear();
    updateBulkActionBar(container);
    loadZones(container);
    loadSeats(container);
  }).catch(err => Toast.error(err.message));
}

function handleBulkRebranch(container) {
  const ids = Array.from(selectedSeatIds);
  const content = document.createElement('div');
  const branchOptions = branchesList.map(b => `
    <option value="${b._id}">${escapeHTML(b.name)} (${escapeHTML(b.code || '')})</option>
  `).join('');

  content.innerHTML = `
    <div class="p-2">
      <p class="small text-muted mb-3">Select target branch center for the <strong>${ids.length}</strong> selected seats:</p>
      <div class="form-group mb-3">
        <select id="bulk-target-branch" class="form-select form-control">
          <option value="">-- No Specific Branch --</option>
          ${branchOptions}
        </select>
      </div>
      <div class="d-flex justify-content-end gap-2 mt-4 pt-2 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="button" class="btn btn-primary" id="btn-apply-bulk-branch">Move Seats</button>
      </div>
    </div>
  `;

  const m = new Modal({
    title: '🏢 Move Selected Seats to Branch',
    content,
    size: 'sm'
  });
  m.show();

  content.querySelector('#btn-apply-bulk-branch')?.addEventListener('click', async () => {
    const targetBranch = content.querySelector('#bulk-target-branch').value;
    try {
      const res = await api.post('/api/seats/bulk-update', {
        seatIds: ids,
        updates: { branch: targetBranch || null }
      });
      Toast.success(res.message || 'Seats moved successfully');
      m.close();
      selectedSeatIds.clear();
      updateBulkActionBar(container);
      loadStats(container);
      loadSeats(container);
    } catch (err) { Toast.error(err.message); }
  });
}

function handleBulkStatus(container) {
  const ids = Array.from(selectedSeatIds);
  const content = document.createElement('div');
  content.innerHTML = `
    <div class="p-2">
      <p class="small text-muted mb-3">Set status for <strong>${ids.length}</strong> selected seats:</p>
      <div class="form-group mb-3">
        <select id="bulk-target-status" class="form-select form-control">
          <option value="available">🟢 Available</option>
          <option value="reserved">🟡 Reserved</option>
          <option value="maintenance">⚪ Under Maintenance</option>
        </select>
      </div>
      <div class="d-flex justify-content-end gap-2 mt-4 pt-2 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
        <button type="button" class="btn btn-primary" id="btn-apply-bulk-status">Update Status</button>
      </div>
    </div>
  `;

  const m = new Modal({
    title: '🔄 Change Status for Selected Seats',
    content,
    size: 'sm'
  });
  m.show();

  content.querySelector('#btn-apply-bulk-status')?.addEventListener('click', async () => {
    const targetStatus = content.querySelector('#bulk-target-status').value;
    const previousStatuses = new Map();
    ids.forEach(id => {
      const s = seatsData.find(st => st._id === id);
      if (s) previousStatuses.set(id, s.status);
    });

    try {
      await OptimisticUI.execute({
        applyState: () => {
          ids.forEach(id => {
            const s = seatsData.find(st => st._id === id);
            if (s) s.status = targetStatus;
          });
          renderSeatsGrid(seatsData, container);
        },
        rollbackState: () => {
          ids.forEach(id => {
            const s = seatsData.find(st => st._id === id);
            if (s && previousStatuses.has(id)) s.status = previousStatuses.get(id);
          });
          renderSeatsGrid(seatsData, container);
        },
        apiCall: () => api.post('/api/seats/bulk-update', {
          seatIds: ids,
          updates: { status: targetStatus }
        }),
        onSuccess: (res) => {
          Toast.success(res.message || 'Status updated');
          m.close();
          selectedSeatIds.clear();
          updateBulkActionBar(container);
          loadStats(container);
          loadSeats(container);
        }
      });
    } catch (err) {
      // Handled by OptimisticUI
    }
  });
}

async function showWaitingListModal() {
  const content = document.createElement('div');
  content.innerHTML = `<div class="text-center p-4 text-muted">Loading waiting list entries...</div>`;

  const wlModal = new Modal({
    title: '⏳ Active Seat Waiting List',
    content,
    size: 'lg'
  });
  wlModal.show();

  try {
    const res = await api.get('/api/waiting-list');
    const entries = res.data?.entries || [];

    if (entries.length === 0) {
      content.innerHTML = `
        <div class="text-center p-5 text-muted">
          <div style="font-size: 2.5rem; margin-bottom: 0.5rem;">🎉</div>
          <h4 style="font-weight: 700; margin: 0;">Waiting List is Clear!</h4>
          <p class="small text-muted mt-1">All student requests currently have assigned seats.</p>
        </div>
      `;
      return;
    }

    content.innerHTML = `
      <div class="table-responsive">
        <table class="table data-table mb-0" style="width: 100%; font-size: 0.88rem;">
          <thead>
            <tr>
              <th>#</th>
              <th>Student</th>
              <th>Phone</th>
              <th>Preferred Zone/Shift</th>
              <th>Requested On</th>
              <th class="text-center">Action</th>
            </tr>
          </thead>
          <tbody>
            ${entries.map((w, idx) => `
              <tr>
                <td><strong>#${idx + 1}</strong></td>
                <td><strong>${escapeHTML(w.student?.name || w.name || 'Unknown')}</strong></td>
                <td>${escapeHTML(w.student?.phone || w.phone || '-')}</td>
                <td>${escapeHTML(w.preferredZone || 'Any Zone')} (${escapeHTML(w.preferredShift || 'All Day')})</td>
                <td>${new Date(w.createdAt).toLocaleDateString()}</td>
                <td class="text-center">
                  <button type="button" class="btn btn-xs btn-primary btn-wl-allocate" data-id="${w._id}" style="font-size: 0.75rem;">
                    Allocate Seat
                  </button>
                </td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
    `;

    content.querySelectorAll('.btn-wl-allocate').forEach(btn => {
      btn.addEventListener('click', () => {
        wlModal.close();
        Toast.info('Select a vacant seat card in the matrix to assign this student');
      });
    });

  } catch (err) {
    content.innerHTML = `<div class="text-danger p-3">Failed to load waiting list</div>`;
  }
}

export function showZoneCustomizerModal(container) {
  const content = document.createElement('div');
  const existingZones = Array.from(new Set(seatsData.map(s => s.zone || 'General').filter(Boolean)));
  
  content.innerHTML = `
    <div class="p-2">
      <p class="small text-muted mb-3">
        Manage study zones (e.g. <em>Silent Zone, Discussion Hall, AC Deluxe, First Floor</em>) and reassign desk blocks:
      </p>

      <div class="mb-4">
        <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 8px;">Active Zones in Library</h5>
        <div class="d-flex flex-wrap gap-2 mb-3" id="active-zones-pills">
          ${existingZones.map(z => `
            <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); border: 1px solid rgba(108, 92, 231, 0.3); padding: 6px 12px; font-size: 0.85rem; border-radius: 8px; display: inline-flex; align-items: center; gap: 6px;">
              📍 ${escapeHTML(z)}
            </span>
          `).join('') || '<span class="text-muted small">No custom zones configured yet</span>'}
        </div>
      </div>

      <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 14px; margin-bottom: 1rem;">
        <h5 style="font-size: 0.9rem; font-weight: 700; margin-bottom: 8px;">⚡ Quick Create / Rename Zone</h5>
        <div class="form-group mb-2">
          <label class="form-label small" style="font-weight: 600;">Zone Name *</label>
          <input type="text" id="custom-zone-name" class="form-control" placeholder="e.g. Quiet Reading Hall - Floor 2">
        </div>
        <p class="text-muted text-xs mb-0">You can assign seats to this new zone using Bulk Select in the Seating Matrix.</p>
      </div>

      <div class="d-flex justify-content-end gap-2 pt-2 border-top">
        <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Close</button>
        <button type="button" class="btn btn-primary" id="btn-save-custom-zone">Save Zone</button>
      </div>
    </div>
  `;

  const m = new Modal({
    title: '🎨 Library Study Zone Customizer',
    content,
    size: 'md'
  });
  m.show();

  content.querySelector('#btn-save-custom-zone')?.addEventListener('click', () => {
    const name = content.querySelector('#custom-zone-name')?.value?.trim();
    if (!name) {
      Toast.warning('Please enter a zone name');
      return;
    }
    Toast.success(`Zone "${name}" ready! You can now select desks and apply this zone.`);
    m.close();
    loadZones(container);
  });
}

