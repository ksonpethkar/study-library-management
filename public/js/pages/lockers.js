import api from '../api.js';
import { Toast, Modal, escapeHTML } from '../ui.js';
import { t } from '../i18n.js';

export async function render() {
  const content = document.getElementById('page-content');
  
  content.innerHTML = `
    <div class="page-header flex-between mb-4">
      <div>
        <h1 class="page-title">🔐 ${t('nav.lockers', 'Locker Management')}</h1>
        <p class="text-muted text-sm">Manage physical lockers, student allocations, and security deposits</p>
      </div>
      <div class="header-actions d-flex gap-2">
        <button id="btn-block-manager" class="btn btn-outline">
          🧱 Block Manager
        </button>
        <button id="btn-bulk-lockers" class="btn btn-outline">
          ⚡ ${t('lockers.bulkGenerate', 'Bulk Generate')}
        </button>
        <button id="btn-add-locker" class="btn btn-primary">
          + ${t('lockers.addLocker', 'Add Locker')}
        </button>
      </div>
    </div>

    <!-- Stat KPI Cards -->
    <div class="stat-grid grid-4 mb-4">
      <div class="stat-card">
        <div class="stat-label">${t('lockers.total', 'Total Lockers')}</div>
        <div class="stat-value" id="stat-total">0</div>
        <div class="stat-meta text-muted">All physical units</div>
      </div>
      <div class="stat-card text-success">
        <div class="stat-label">${t('lockers.available', 'Available')}</div>
        <div class="stat-value" id="stat-available" style="color: var(--color-success);">0</div>
        <div class="stat-meta text-muted">Ready for allocation</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">${t('lockers.occupied', 'Occupied')}</div>
        <div class="stat-value" id="stat-occupied" style="color: var(--color-primary);">0</div>
        <div class="stat-meta text-muted">Currently in use</div>
      </div>
      <div class="stat-card">
        <div class="stat-label">${t('lockers.depositHeld', 'Deposit Held')}</div>
        <div class="stat-value" id="stat-deposit" style="color: var(--color-warning);">₹0</div>
        <div class="stat-meta text-muted">Refundable security</div>
      </div>
    </div>

    <!-- Filter Bar -->
    <div class="card mb-4">
      <div class="card-body p-3 d-flex flex-wrap gap-3 align-center">
        <div id="block-filters" class="d-flex gap-2 flex-wrap w-100 mb-2">
          <!-- Block filters injected here -->
        </div>
        <div style="flex: 1; min-width: 200px;">
          <input type="text" id="locker-search" class="form-control" placeholder="🔍 Search locker number...">
        </div>
        <div style="min-width: 150px;">
          <select id="locker-status-filter" class="form-control">
            <option value="all">All Statuses</option>
            <option value="available">🟢 Available</option>
            <option value="occupied">🔵 Occupied</option>
            <option value="maintenance">🟠 Maintenance</option>
          </select>
        </div>
        <div style="min-width: 130px;">
          <select id="locker-size-filter" class="form-control">
            <option value="all">All Sizes</option>
            <option value="small">Small</option>
            <option value="medium">Medium</option>
            <option value="large">Large</option>
          </select>
        </div>
      </div>
    </div>

    <!-- Locker Grid -->
    <div id="lockers-grid" class="d-grid" style="grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 16px;">
      <div class="text-center p-4 text-muted" style="grid-column: 1 / -1;">Loading lockers...</div>
    </div>
  `;

  // Attach event listeners safely
  container.querySelector('#btn-add-locker')?.addEventListener('click', showAddLockerModal);
  container.querySelector('#btn-bulk-lockers')?.addEventListener('click', showBulkGenerateModal);
  container.querySelector('#btn-block-manager')?.addEventListener('click', showBlockManagerModal);
  container.querySelector('#locker-search')?.addEventListener('input', debounce(loadLockers, 300));
  container.querySelector('#locker-status-filter')?.addEventListener('change', loadLockers);
  container.querySelector('#locker-size-filter')?.addEventListener('change', loadLockers);

  // Initial load
  await loadLockers();
}

let lockersData = [];
let currentBlockFilter = 'all';
let blocksList = [];

async function loadLockers() {
  try {
    const search = document.getElementById('locker-search')?.value || '';
    const status = document.getElementById('locker-status-filter')?.value || 'all';
    const size = document.getElementById('locker-size-filter')?.value || 'all';

    const res = await api.get(`/api/lockers?search=${encodeURIComponent(search)}&status=${status}&size=${size}`);
    const blockRes = await api.get('/api/lockers/blocks');
    
    if (!res || !res.success) {
      Toast.error('Failed to load lockers');
      return;
    }

    lockersData = res.lockers || [];
    blocksList = blockRes?.blocks || [];
    const stats = res.stats || {};

    // Apply client side block filter
    let filteredLockers = lockersData;
    if (currentBlockFilter !== 'all') {
      filteredLockers = lockersData.filter(l => (l.block || 'Block A') === currentBlockFilter);
    }

    // Update KPI stats based on filtered data if block is selected, or global if 'all'
    if (currentBlockFilter !== 'all') {
      const activeBlock = blocksList.find(b => b.block === currentBlockFilter) || { total: 0, available: 0, assigned: 0, totalRevenue: 0 };
      document.getElementById('stat-total').textContent = activeBlock.total;
      document.getElementById('stat-available').textContent = activeBlock.available;
      document.getElementById('stat-occupied').textContent = activeBlock.assigned;
      
      const filteredDeposit = filteredLockers.reduce((acc, l) => acc + (l.isDepositPaid && !l.isDepositRefunded ? (l.depositAmount || 0) : 0), 0);
      document.getElementById('stat-deposit').textContent = `₹${filteredDeposit.toLocaleString('en-IN')}`;
    } else {
      document.getElementById('stat-total').textContent = stats.total || 0;
      document.getElementById('stat-available').textContent = stats.available || 0;
      document.getElementById('stat-occupied').textContent = stats.occupied || 0;
      document.getElementById('stat-deposit').textContent = `₹${(stats.totalDeposit || 0).toLocaleString('en-IN')}`;
    }

    renderBlockFilters();
    renderLockerGrid(filteredLockers);
  } catch (err) {
    console.error(err);
    Toast.error('Error loading lockers');
  }
}

function renderBlockFilters() {
  const container = document.getElementById('block-filters');
  if (!container) return;
  
  let html = `<button class="btn btn-sm ${currentBlockFilter === 'all' ? 'btn-primary' : 'btn-outline'} block-filter-btn" data-block="all">All Blocks</button>`;
  blocksList.forEach(b => {
    const isActive = currentBlockFilter === b.block;
    html += `<button class="btn btn-sm ${isActive ? 'btn-primary' : 'btn-outline'} block-filter-btn" data-block="${escapeHTML(b.block)}">${escapeHTML(b.block)} (${b.total})</button>`;
  });
  
  container.innerHTML = html;
  container.querySelectorAll('.block-filter-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      currentBlockFilter = e.target.dataset.block;
      loadLockers();
    });
  });
}

function renderLockerGrid(lockers) {
  const container = document.getElementById('lockers-grid');
  if (!container) return;

  if (lockers.length === 0) {
    container.innerHTML = `
      <div class="empty-state p-5 text-center" style="grid-column: 1 / -1; background: var(--color-surface); border-radius: 12px; border: 1px dashed var(--color-border);">
        <div style="font-size: 40px; margin-bottom: 8px;">🔐</div>
        <h3>No Lockers Found</h3>
        <p class="text-muted text-sm">Add lockers individually or bulk generate numbers (L-01 to L-50)</p>
      </div>
    `;
    return;
  }

  container.innerHTML = lockers.map(l => {
    const isOccupied = l.status === 'occupied';
    const isMaint = l.status === 'maintenance';
    const borderColor = isOccupied ? 'var(--color-primary)' : isMaint ? 'var(--color-warning)' : 'var(--color-success)';
    const statusBadgeClass = isOccupied ? 'badge-primary' : isMaint ? 'badge-warning' : 'badge-success';

    return `
      <div class="card" style="border-top: 4px solid ${borderColor}; transition: transform 0.15s ease;">
        <div class="card-body p-3">
          <div class="flex-between mb-2">
            <span style="font-size: 18px; font-weight: 700;">${escapeHTML(l.lockerNumber)}</span>
            <span class="badge ${statusBadgeClass}" style="text-transform: capitalize;">${escapeHTML(l.status)}</span>
          </div>
          
          <div class="text-xs text-muted mb-2">
            Size: <strong>${escapeHTML(l.size)}</strong> | Key #: <strong>${escapeHTML(l.keyNumber || 'N/A')}</strong>
          </div>

          ${isOccupied ? `
            <div style="background: rgba(99, 102, 241, 0.08); padding: 8px 10px; border-radius: 8px; margin-bottom: 12px;">
              <div class="text-xs text-muted">Assigned To:</div>
              <div style="font-weight: 600; font-size: 14px;">${escapeHTML(l.assignedStudent?.name || 'Student')}</div>
              <div class="text-xs text-muted">ID: ${escapeHTML(l.assignedStudent?.studentId || '')} | Dep: ₹${l.depositAmount}</div>
            </div>
            <button class="btn btn-sm btn-outline w-100 btn-release-locker" data-id="${l._id}" data-num="${escapeHTML(l.lockerNumber)}" data-dep="${l.depositAmount}">
              🔓 Release & Refund
            </button>
          ` : isMaint ? `
            <div style="background: rgba(245, 158, 11, 0.08); padding: 8px 10px; border-radius: 8px; margin-bottom: 12px;">
              <div class="text-xs text-warning">Under Maintenance</div>
              <div class="text-xs text-muted">${escapeHTML(l.notes || 'Repairs in progress')}</div>
            </div>
            <button class="btn btn-sm btn-primary w-100 btn-edit-locker" data-id="${l._id}">
              ⚙️ Make Available
            </button>
          ` : `
            <div style="padding: 8px 0; margin-bottom: 12px;">
              <div class="text-xs text-muted">Deposit: ₹${l.depositAmount || 0}</div>
              <div class="text-xs text-success">✓ Ready for student</div>
            </div>
            <button class="btn btn-sm btn-primary w-100 btn-assign-locker" data-id="${l._id}" data-num="${escapeHTML(l.lockerNumber)}" data-dep="${l.depositAmount}">
              🔑 Assign to Student
            </button>
          `}
        </div>
      </div>
    `;
  }).join('');

  // Event handlers on buttons
  container.querySelectorAll('.btn-assign-locker').forEach(b => {
    b.addEventListener('click', () => showAssignModal(b.dataset.id, b.dataset.num, b.dataset.dep));
  });

  container.querySelectorAll('.btn-release-locker').forEach(b => {
    b.addEventListener('click', () => showReleaseModal(b.dataset.id, b.dataset.num, b.dataset.dep));
  });

  container.querySelectorAll('.btn-edit-locker').forEach(b => {
    b.addEventListener('click', () => showEditLockerModal(b.dataset.id));
  });
}

// Add Single Locker Modal
function showAddLockerModal() {
  const modal = new Modal({
    title: 'Add New Locker',
    content: `
      <form id="add-locker-form">
        <div class="form-group mb-3">
          <label class="form-label">Locker Number / ID *</label>
          <input type="text" id="add-locker-number" class="form-control" placeholder="e.g. L-01" required>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Size</label>
          <select id="add-locker-size" class="form-control">
            <option value="small">Small (Books & Bags)</option>
            <option value="medium" selected>Medium (Standard)</option>
            <option value="large">Large (Cabin Size)</option>
          </select>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Key Number / Duplicate Key ID</label>
          <input type="text" id="add-locker-key" class="form-control" placeholder="e.g. K-101">
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Caution Deposit (₹)</label>
          <input type="number" id="add-locker-deposit" class="form-control" value="200" min="0">
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Create Locker</button>
        </div>
      </form>
    `
  });
  modal.show();

  document.getElementById('add-locker-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    try {
      const payload = {
        lockerNumber: document.getElementById('add-locker-number').value.trim(),
        size: document.getElementById('add-locker-size').value,
        keyNumber: document.getElementById('add-locker-key').value.trim(),
        depositAmount: parseFloat(document.getElementById('add-locker-deposit').value) || 0
      };

      const res = await api.post('/api/lockers', payload);
      if (res && res.success) {
        Toast.success('Locker created successfully');
        Modal.closeAll();
        loadLockers();
      } else {
        Toast.error(res?.message || 'Error creating locker');
      }
    } catch (err) {
      Toast.error(err.message || 'Error creating locker');
    }
  });
}

// Bulk Generate Lockers Modal
function showBulkGenerateModal() {
  const modal = new Modal({
    title: '⚡ Bulk Generate Lockers',
    content: `
      <form id="bulk-locker-form">
        <p class="text-sm text-muted mb-3">Quickly generate a sequence of locker boxes in one click.</p>
        <div class="d-grid grid-2 gap-3 mb-3">
          <div class="form-group">
            <label class="form-label">Prefix</label>
            <input type="text" id="bulk-prefix" class="form-control" value="L-" required>
          </div>
          <div class="form-group">
            <label class="form-label">Start Number</label>
            <input type="number" id="bulk-start" class="form-control" value="1" min="1" required>
          </div>
        </div>
        <div class="d-grid grid-2 gap-3 mb-3">
          <div class="form-group">
            <label class="form-label">Total Count</label>
            <input type="number" id="bulk-count" class="form-control" value="20" min="1" max="100" required>
          </div>
          <div class="form-group">
            <label class="form-label">Size</label>
            <select id="bulk-size" class="form-control">
              <option value="small">Small</option>
              <option value="medium" selected>Medium</option>
              <option value="large">Large</option>
            </select>
          </div>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Default Caution Deposit (₹)</label>
          <input type="number" id="bulk-deposit" class="form-control" value="200" min="0">
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Generate Lockers</button>
        </div>
      </form>
    `
  });
  modal.show();

  document.getElementById('bulk-locker-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    try {
      const payload = {
        isBulk: true,
        prefix: document.getElementById('bulk-prefix').value.trim(),
        startNumber: parseInt(document.getElementById('bulk-start').value, 10),
        count: parseInt(document.getElementById('bulk-count').value, 10),
        size: document.getElementById('bulk-size').value,
        depositAmount: parseFloat(document.getElementById('bulk-deposit').value) || 0
      };

      const res = await api.post('/api/lockers', payload);
      if (res && res.success) {
        Toast.success(res.message || 'Lockers generated');
        Modal.closeAll();
        loadLockers();
      } else {
        Toast.error(res?.message || 'Error generating lockers');
      }
    } catch (err) {
      Toast.error(err.message || 'Error generating lockers');
    }
  });
}

// Assign Locker to Student
async function showAssignModal(lockerId, lockerNum, defaultDeposit) {
  // Fetch active students
  let students = [];
  try {
    const res = await api.get('/api/students?limit=100&status=active');
    students = res?.data?.students || res?.data || res?.students || [];
  } catch (e) {}

  const studentOptions = students.map(s => `
    <option value="${s._id}">${escapeHTML(s.name)} (${s.studentId} - ${s.phone})</option>
  `).join('');

  const modal = new Modal({
    title: `🔑 Assign Locker ${escapeHTML(lockerNum)}`,
    content: `
      <form id="assign-locker-form">
        <div class="form-group mb-3">
          <label class="form-label">Select Student *</label>
          <select id="assign-student-id" class="form-control" required>
            <option value="">-- Choose active student --</option>
            ${studentOptions}
          </select>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Locker Caution Deposit (₹)</label>
          <input type="number" id="assign-deposit" class="form-control" value="${defaultDeposit || 200}" min="0">
        </div>
        <div class="form-group mb-3">
          <label class="d-flex align-center gap-2">
            <input type="checkbox" id="assign-deposit-paid" checked>
            <span>Deposit received in Cash / UPI</span>
          </label>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Key Number Handed Over</label>
          <input type="text" id="assign-key" class="form-control" placeholder="e.g. Key #04">
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Confirm Assignment</button>
        </div>
      </form>
    `
  });
  modal.show();

  document.getElementById('assign-locker-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    try {
      const studentId = document.getElementById('assign-student-id').value;
      if (!studentId) {
        Toast.error('Please select a student');
        return;
      }

      const payload = {
        studentId,
        depositAmount: parseFloat(document.getElementById('assign-deposit').value) || 0,
        isDepositPaid: document.getElementById('assign-deposit-paid').checked,
        keyNumber: document.getElementById('assign-key').value.trim()
      };

      const res = await api.put(`/api/lockers/${lockerId}/assign`, payload);
      if (res && res.success) {
        Toast.success(`Locker ${lockerNum} assigned to student!`);
        Modal.closeAll();
        loadLockers();
      } else {
        Toast.error(res?.message || 'Error assigning locker');
      }
    } catch (err) {
      Toast.error(err.message || 'Error assigning locker');
    }
  });
}

// Release & Refund Modal
function showReleaseModal(lockerId, lockerNum, depositAmount) {
  const modal = new Modal({
    title: `🔓 Release Locker ${escapeHTML(lockerNum)}`,
    content: `
      <div>
        <p class="mb-3">Are you sure you want to release <strong>${escapeHTML(lockerNum)}</strong>? The student will be de-allocated and the locker marked available.</p>
        
        <div style="background: rgba(245, 158, 11, 0.1); padding: 12px; border-radius: 8px; margin-bottom: 16px;">
          <label class="d-flex align-center gap-2">
            <input type="checkbox" id="refund-deposit-cb" checked>
            <span><strong>Refund Caution Deposit (₹${depositAmount || 0})</strong> to student</span>
          </label>
        </div>

        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="button" id="confirm-release-btn" class="btn btn-warning">Confirm Release</button>
        </div>
      </div>
    `
  });
  modal.show();

  document.getElementById('confirm-release-btn')?.addEventListener('click', async () => {
    try {
      const refundDeposit = document.getElementById('refund-deposit-cb').checked;
      const res = await api.put(`/api/lockers/${lockerId}/release`, { refundDeposit });
      if (res && res.success) {
        Toast.success(`Locker ${lockerNum} released`);
        Modal.closeAll();
        loadLockers();
      } else {
        Toast.error(res?.message || 'Error releasing locker');
      }
    } catch (err) {
      Toast.error(err.message || 'Error releasing locker');
    }
  });
}

// Helper debounce
function debounce(fn, ms) {
  let timeout;
  return function(...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => fn.apply(this, args), ms);
  };
}

// Block Manager Modal
function showBlockManagerModal() {
  let blockOptions = blocksList.map(b => `<option value="${escapeHTML(b.block)}">${escapeHTML(b.block)}</option>`).join('');
  if (!blockOptions) {
    blockOptions = `<option value="Block A">Block A</option>`;
  }

  const modal = new Modal({
    title: '🧱 Locker Block & Pricing Manager',
    content: `
      <form id="block-manager-form">
        <p class="text-sm text-muted mb-3">Update pricing and size for all lockers in a selected block.</p>
        <div class="form-group mb-3">
          <label class="form-label">Select Block *</label>
          <select id="manage-block-name" class="form-control" required>
            ${blockOptions}
          </select>
        </div>
        <div class="d-grid grid-2 gap-3 mb-3">
          <div class="form-group">
            <label class="form-label">Monthly Rental Fee (₹)</label>
            <input type="number" id="manage-monthly-fee" class="form-control" placeholder="e.g. 500" min="0">
          </div>
          <div class="form-group">
            <label class="form-label">Caution Deposit (₹)</label>
            <input type="number" id="manage-deposit-fee" class="form-control" placeholder="e.g. 200" min="0">
          </div>
        </div>
        <div class="form-group mb-3">
          <label class="form-label">Change Size (Optional)</label>
          <select id="manage-block-size" class="form-control">
            <option value="">-- No Change --</option>
            <option value="small">Small</option>
            <option value="medium">Medium</option>
            <option value="large">Large</option>
          </select>
        </div>
        <div class="d-flex justify-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary">Apply Changes</button>
        </div>
      </form>
    `
  });
  modal.show();

  document.getElementById('block-manager-form')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    try {
      const payload = {
        block: document.getElementById('manage-block-name').value
      };
      
      const monthlyFee = document.getElementById('manage-monthly-fee').value;
      if (monthlyFee) payload.monthlyFee = monthlyFee;
      
      const depositFee = document.getElementById('manage-deposit-fee').value;
      if (depositFee) payload.depositFee = depositFee;
      
      const size = document.getElementById('manage-block-size').value;
      if (size) payload.size = size;

      const res = await api.put('/api/lockers/blocks/pricing', payload);
      if (res && res.success) {
        Toast.success(res.message || 'Block pricing updated');
        Modal.closeAll();
        loadLockers();
      } else {
        Toast.error(res?.message || 'Error updating block pricing');
      }
    } catch (err) {
      Toast.error(err.message || 'Error updating block pricing');
    }
  });
}
