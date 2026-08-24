/**
 * 🗑️ Universal Recycle Bin & Trash Management Module
 * Allows viewing, restoring, or permanently destroying soft-deleted records
 * across all system modules with explicit safety confirmation dialogs.
 */

import { api } from '../api.js';
import { Toast, Modal, escapeHTML } from '../ui.js';
import { store } from '../store.js';

let currentTab = 'all';
let currentSearch = '';
let currentPage = 1;
let selectedItemIds = new Set();

const TYPE_CONFIG = {
  all: { label: 'All Items', icon: '📋', color: '#6c5ce7' },
  student: { label: 'Students', icon: '🎓', color: '#3b82f6' },
  payment: { label: 'Payments & Receipts', icon: '💳', color: '#10b981' },
  expense: { label: 'Expenses', icon: '💸', color: '#ef4444' },
  seat: { label: 'Desks / Seats', icon: '💺', color: '#8b5cf6' },
  plan: { label: 'Membership Plans', icon: '💎', color: '#f59e0b' },
  shift: { label: 'Study Shifts', icon: '⏰', color: '#06b6d4' },
  branch: { label: 'Branches', icon: '🏢', color: '#ec4899' },
  locker: { label: 'Lockers', icon: '🔒', color: '#64748b' },
  custom_field: { label: 'Custom Questions', icon: '📝', color: '#14b8a6' },
  coupon: { label: 'Coupons / Promos', icon: '🎟️', color: '#f97316' },
  waiting_list: { label: 'Waitlist', icon: '⏳', color: '#a855f7' },
  announcement: { label: 'Notices', icon: '📢', color: '#eab308' },
  holiday: { label: 'Holidays', icon: '🏖️', color: '#06b6d4' },
  visitor: { label: 'Visitors', icon: '👥', color: '#64748b' },
  lost_found: { label: 'Lost & Found', icon: '🔍', color: '#f43f5e' },
  feedback: { label: 'Feedback', icon: '💬', color: '#8b5cf6' }
};

export async function render(container) {
  if (!container) return;
  selectedItemIds.clear();
  currentPage = 1;

  container.innerHTML = `
    <div class="page-content-wrapper" style="padding: 1.5rem 2rem; max-width: 1400px; margin: 0 auto;">
      <!-- Header Banner -->
      <div class="card mb-4" style="background: linear-gradient(135deg, rgba(239, 68, 68, 0.08), rgba(108, 92, 231, 0.08)); border-left: 4px solid var(--color-danger, #ef4444);">
        <div class="card-body" style="padding: 1.5rem;">
          <div class="d-flex justify-content-between align-items-center flex-wrap gap-3">
            <div>
              <h2 style="font-size: 1.5rem; font-weight: 700; color: var(--color-text-primary); margin: 0 0 4px 0;">
                🗑️ Recycle Bin & Trash Management
              </h2>
              <p class="text-muted" style="margin: 0; font-size: 0.88rem;">
                Safely inspect, restore, or permanently remove deleted student records, desks, receipts, plans, and settings.
              </p>
            </div>
            <div class="d-flex gap-2 flex-wrap">
              <button class="btn btn-outline-primary btn-sm" id="trash-bulk-restore-btn" style="display: none;">
                ♻️ Restore Selected (<span id="trash-selected-count">0</span>)
              </button>
              <button class="btn btn-outline-danger btn-sm" id="trash-empty-btn">
                🧹 Empty Recycle Bin
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Category Filter Tabs -->
      <div class="card mb-4">
        <div class="card-body" style="padding: 1rem 1.25rem;">
          <div class="d-flex gap-2 flex-wrap" id="trash-category-tabs">
            <button class="btn btn-sm ${currentTab === 'all' ? 'btn-primary' : 'btn-ghost'}" data-tab="all">
              📋 All Items <span class="badge badge-secondary" id="count-all">...</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'student' ? 'btn-primary' : 'btn-ghost'}" data-tab="student">
              🎓 Students <span class="badge badge-secondary" id="count-student">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'payment' ? 'btn-primary' : 'btn-ghost'}" data-tab="payment">
              💳 Payments <span class="badge badge-secondary" id="count-payment">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'expense' ? 'btn-primary' : 'btn-ghost'}" data-tab="expense">
              💸 Expenses <span class="badge badge-secondary" id="count-expense">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'seat' ? 'btn-primary' : 'btn-ghost'}" data-tab="seat">
              💺 Desks <span class="badge badge-secondary" id="count-seat">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'plan' ? 'btn-primary' : 'btn-ghost'}" data-tab="plan">
              💎 Plans <span class="badge badge-secondary" id="count-plan">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'shift' ? 'btn-primary' : 'btn-ghost'}" data-tab="shift">
              ⏰ Shifts <span class="badge badge-secondary" id="count-shift">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'branch' ? 'btn-primary' : 'btn-ghost'}" data-tab="branch">
              🏢 Branches <span class="badge badge-secondary" id="count-branch">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'locker' ? 'btn-primary' : 'btn-ghost'}" data-tab="locker">
              🔒 Lockers <span class="badge badge-secondary" id="count-locker">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'custom_field' ? 'btn-primary' : 'btn-ghost'}" data-tab="custom_field">
              📝 Custom Fields <span class="badge badge-secondary" id="count-custom_field">0</span>
            </button>
            <button class="btn btn-sm ${currentTab === 'coupon' ? 'btn-primary' : 'btn-ghost'}" data-tab="coupon">
              🎟️ Coupons <span class="badge badge-secondary" id="count-coupon">0</span>
            </button>
          </div>
        </div>
      </div>

      <!-- Search & Data Table -->
      <div class="card">
        <div class="card-body" style="padding: 1.25rem;">
          <!-- Toolbar -->
          <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
            <div style="flex: 1; max-width: 400px; position: relative;">
              <input type="text" id="trash-search-input" class="form-control form-control-sm" placeholder="🔍 Search deleted records by title, phone, user..." value="${escapeHTML(currentSearch)}" style="padding-left: 2rem;">
              <span style="position: absolute; left: 10px; top: 50%; transform: translateY(-50%); opacity: 0.5;">🔍</span>
            </div>
            <div class="text-muted" style="font-size: 0.85rem;" id="trash-meta-info">
              Loading records...
            </div>
          </div>

          <!-- Items Table Container -->
          <div id="trash-table-container">
            <div style="padding: 3rem 1rem; text-align: center; color: var(--color-text-secondary);">
              <div class="spinner-border spinner-border-sm text-primary mb-2"></div>
              <div>Fetching deleted records...</div>
            </div>
          </div>

          <!-- Pagination Container -->
          <div id="trash-pagination-container" class="d-flex justify-content-between align-items-center mt-3 pt-3" style="border-top: 1px solid var(--color-border, #e2e8f0); display: none;"></div>
        </div>
      </div>
    </div>
  `;

  _attachEvents(container);
  _loadCounts();
  _loadTrashList();
}

function _attachEvents(container) {
  // Category tabs
  const tabButtons = container.querySelectorAll('#trash-category-tabs button');
  tabButtons.forEach(btn => {
    btn.addEventListener('click', () => {
      tabButtons.forEach(b => {
        b.classList.remove('btn-primary');
        b.classList.add('btn-ghost');
      });
      btn.classList.add('btn-primary');
      btn.classList.remove('btn-ghost');

      currentTab = btn.getAttribute('data-tab') || 'all';
      currentPage = 1;
      selectedItemIds.clear();
      _updateBulkButton();
      _loadTrashList();
    });
  });

  // Search input with debounce
  const searchInput = container.getElementById('trash-search-input');
  if (searchInput) {
    let debounceTimer;
    searchInput.addEventListener('input', () => {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(() => {
        currentSearch = searchInput.value.trim();
        currentPage = 1;
        _loadTrashList();
      }, 250);
    });
  }

  // Bulk Restore button
  const bulkBtn = container.querySelector('#trash-bulk-restore-btn');
  if (bulkBtn) {
    bulkBtn.addEventListener('click', _handleBulkRestore);
  }

  // Empty Trash button
  const emptyBtn = container.querySelector('#trash-empty-btn');
  if (emptyBtn) {
    emptyBtn.addEventListener('click', _handleEmptyTrash);
  }
}

async function _loadCounts() {
  try {
    const res = await api.get('/api/trash/counts');
    if (res.success && res.data) {
      Object.keys(res.data).forEach(k => {
        const el = document.getElementById(`count-${k}`);
        if (el) el.textContent = res.data[k] || 0;
      });
      const allEl = document.getElementById('count-all');
      if (allEl) allEl.textContent = res.data.all || 0;
    }
  } catch (e) {}
}

async function _loadTrashList() {
  const mount = document.getElementById('trash-table-container');
  const metaEl = document.getElementById('trash-meta-info');
  const pagMount = document.getElementById('trash-pagination-container');
  if (!mount) return;

  try {
    const query = new URLSearchParams({
      type: currentTab,
      search: currentSearch,
      page: currentPage,
      limit: 20
    });

    const res = await api.get(`/api/trash?${query.toString()}`);
    if (!res.success || !res.data) {
      throw new Error(res.message || 'Failed to fetch items');
    }

    const { items, total, totalPages } = res.data;

    if (metaEl) {
      metaEl.textContent = total === 1 ? '1 deleted item' : `${total} deleted items`;
    }

    if (items.length === 0) {
      mount.innerHTML = `
        <div style="padding: 4rem 1rem; text-align: center; color: var(--color-text-secondary);">
          <div style="font-size: 3rem; margin-bottom: 0.75rem;">✨</div>
          <h4 style="font-weight: 600; color: var(--color-text-primary); margin-bottom: 4px;">Recycle Bin is Clean</h4>
          <p style="font-size: 0.88rem; max-width: 450px; margin: 0 auto;">
            ${currentSearch ? 'No deleted records match your search criteria.' : 'There are no deleted items in this category. Any deleted items will appear here for safe recovery.'}
          </p>
        </div>
      `;
      if (pagMount) pagMount.style.display = 'none';
      return;
    }

    // Render Table
    mount.innerHTML = `
      <div class="table-responsive">
        <table class="table data-table" style="width: 100%; border-collapse: collapse;">
          <thead>
            <tr style="border-bottom: 2px solid var(--color-border, #e2e8f0); text-align: left; font-size: 0.8rem; color: var(--color-text-secondary); text-transform: uppercase;">
              <th style="width: 40px; text-align: center;">
                <input type="checkbox" id="trash-select-all" title="Select All">
              </th>
              <th>Item / Record</th>
              <th>Category</th>
              <th>Deleted By</th>
              <th>Deleted Timestamp</th>
              <th style="text-align: right; min-width: 160px;">Actions</th>
            </tr>
          </thead>
          <tbody>
            ${items.map(item => {
              const cfg = TYPE_CONFIG[item.itemType] || { label: item.itemType, icon: '📦', color: '#64748b' };
              const timeStr = _formatRelativeDate(item.deletedAt);
              const isSelected = selectedItemIds.has(item._id);

              return `
                <tr data-id="${item._id}" style="border-bottom: 1px solid var(--color-border, #f1f5f9); vertical-align: middle;">
                  <td style="text-align: center;">
                    <input type="checkbox" class="trash-item-checkbox" data-id="${item._id}" ${isSelected ? 'checked' : ''}>
                  </td>
                  <td style="padding: 10px 8px;">
                    <div class="d-flex align-items-center gap-2">
                      <span style="font-size: 1.25rem;">${cfg.icon}</span>
                      <div>
                        <div style="font-weight: 600; color: var(--color-text-primary); font-size: 0.92rem;">
                          ${escapeHTML(item.itemTitle || 'Untitled Record')}
                        </div>
                        ${item.itemSubtitle ? `<div style="font-size: 0.78rem; color: var(--color-text-secondary);">${escapeHTML(item.itemSubtitle)}</div>` : ''}
                      </div>
                    </div>
                  </td>
                  <td>
                    <span class="badge" style="background: ${cfg.color}15; color: ${cfg.color}; font-weight: 600; font-size: 0.75rem;">
                      ${cfg.icon} ${cfg.label}
                    </span>
                  </td>
                  <td style="font-size: 0.85rem; color: var(--color-text-primary);">
                    👤 ${escapeHTML(item.deletedByName || 'Admin')}
                  </td>
                  <td style="font-size: 0.82rem; color: var(--color-text-secondary);" title="${new Date(item.deletedAt).toLocaleString()}">
                    🕒 ${timeStr}
                  </td>
                  <td style="text-align: right; padding-right: 8px;">
                    <div class="d-flex gap-2 justify-content-end">
                      <button class="btn btn-sm btn-outline-success restore-item-btn" data-id="${item._id}" data-title="${escapeHTML(item.itemTitle)}" title="Restore Record">
                        ♻️ Restore
                      </button>
                      <button class="btn btn-sm btn-outline-danger hard-delete-btn" data-id="${item._id}" data-title="${escapeHTML(item.itemTitle)}" title="Permanently Destroy Record">
                        💥 Hard Delete
                      </button>
                    </div>
                  </td>
                </tr>
              `;
            }).join('')}
          </tbody>
        </table>
      </div>
    `;

    // Attach Row Level Listeners
    _attachTableListeners(mount, items, totalPages);

  } catch (err) {
    mount.innerHTML = `
      <div style="padding: 2rem; text-align: center; color: var(--color-danger);">
        ⚠️ Failed to load trash items: ${escapeHTML(err.message)}
      </div>
    `;
  }
}

function _attachTableListeners(mount, items, totalPages) {
  // Select All Checkbox
  const selectAll = mount.querySelector('#trash-select-all');
  if (selectAll) {
    selectAll.addEventListener('change', () => {
      const checkboxes = mount.querySelectorAll('.trash-item-checkbox');
      checkboxes.forEach(cb => {
        cb.checked = selectAll.checked;
        const id = cb.getAttribute('data-id');
        if (selectAll.checked) selectedItemIds.add(id);
        else selectedItemIds.delete(id);
      });
      _updateBulkButton();
    });
  }

  // Row Checkboxes
  mount.querySelectorAll('.trash-item-checkbox').forEach(cb => {
    cb.addEventListener('change', () => {
      const id = cb.getAttribute('data-id');
      if (cb.checked) selectedItemIds.add(id);
      else selectedItemIds.delete(id);
      _updateBulkButton();
    });
  });

  // Restore Single Item
  mount.querySelectorAll('.restore-item-btn').forEach(btn => {
    btn.addEventListener('click', async () => {
      const id = btn.getAttribute('data-id');
      const title = btn.getAttribute('data-title');
      await _handleRestoreSingle(id, title);
    });
  });

  // Permanent Hard Delete Single Item
  mount.querySelectorAll('.hard-delete-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const id = btn.getAttribute('data-id');
      const title = btn.getAttribute('data-title');
      _openHardDeleteConfirmationModal(id, title);
    });
  });
}

function _updateBulkButton() {
  const bulkBtn = document.getElementById('trash-bulk-restore-btn');
  const countSpan = document.getElementById('trash-selected-count');
  if (bulkBtn && countSpan) {
    const size = selectedItemIds.size;
    countSpan.textContent = size;
    bulkBtn.style.display = size > 0 ? 'inline-flex' : 'none';
  }
}

async function _handleRestoreSingle(id, title) {
  try {
    const res = await api.post(`/api/trash/restore/${id}`);
    if (res.success) {
      Toast.success(res.message || `"${title}" restored successfully!`);
      selectedItemIds.delete(id);
      _updateBulkButton();
      _loadCounts();
      _loadTrashList();
    } else {
      Toast.error(res.message || 'Failed to restore item');
    }
  } catch (err) {
    Toast.error(err.message || 'Restore error');
  }
}

async function _handleBulkRestore() {
  const ids = Array.from(selectedItemIds);
  if (ids.length === 0) return;

  try {
    const res = await api.post('/api/trash/restore-bulk', { ids });
    if (res.success) {
      Toast.success(res.message || `Restored ${ids.length} items successfully!`);
      selectedItemIds.clear();
      _updateBulkButton();
      _loadCounts();
      _loadTrashList();
    } else {
      Toast.error(res.message || 'Failed to restore selected items');
    }
  } catch (err) {
    Toast.error(err.message || 'Bulk restore error');
  }
}

function _openHardDeleteConfirmationModal(id, title) {
  Modal.show({
    title: '⚠️ Permanent Deletion Warning',
    content: `
      <div style="padding: 0.5rem 0;">
        <div class="alert alert-danger" style="background: rgba(239, 68, 68, 0.1); border: 1px solid var(--color-danger, #ef4444); color: #b91c1c; border-radius: 8px; padding: 12px 16px; margin-bottom: 1rem; font-size: 0.88rem;">
          <strong>CAUTION:</strong> This action CANNOT be undone! The record will be permanently purged from MongoDB and cannot be recovered.
        </div>
        <p style="font-size: 0.95rem; color: var(--color-text-primary); margin-bottom: 0.5rem;">
          Are you sure you want to permanently erase:
        </p>
        <div style="background: var(--color-bg-secondary, #f8fafc); padding: 10px 14px; border-radius: 6px; font-weight: 700; color: var(--color-danger); margin-bottom: 1rem;">
          🗑️ ${escapeHTML(title)}
        </div>
      </div>
    `,
    actions: `
      <button type="button" class="btn btn-ghost" onclick="window.Modal.close()">Cancel</button>
      <button type="button" class="btn btn-danger" id="confirm-hard-delete-action">💥 Yes, Permanently Delete</button>
    `
  });

  setTimeout(() => {
    const confirmBtn = document.getElementById('confirm-hard-delete-action');
    if (confirmBtn) {
      confirmBtn.onclick = async () => {
        confirmBtn.disabled = true;
        confirmBtn.textContent = 'Deleting...';
        try {
          const res = await api.delete(`/api/trash/permanent/${id}`);
          Modal.close();
          if (res.success) {
            Toast.info(`"${title}" permanently deleted.`);
            selectedItemIds.delete(id);
            _updateBulkButton();
            _loadCounts();
            _loadTrashList();
          } else {
            Toast.error(res.message || 'Failed to permanently delete');
          }
        } catch (e) {
          Modal.close();
          Toast.error(e.message || 'Deletion failed');
        }
      };
    }
  }, 100);
}

function _handleEmptyTrash() {
  const tabName = TYPE_CONFIG[currentTab]?.label || 'All Items';
  Modal.show({
    title: '🧹 Empty Recycle Bin Confirmation',
    content: `
      <div style="padding: 0.5rem 0;">
        <div class="alert alert-danger" style="background: rgba(239, 68, 68, 0.1); border: 1px solid var(--color-danger, #ef4444); color: #b91c1c; border-radius: 8px; padding: 12px 16px; margin-bottom: 1rem; font-size: 0.88rem;">
          <strong>CRITICAL WARNING:</strong> You are about to permanently destroy all items in <strong>${escapeHTML(tabName)}</strong>! Once emptied, these records are permanently gone forever.
        </div>
        <p style="font-size: 0.95rem; color: var(--color-text-primary);">
          Are you completely certain you want to proceed?
        </p>
      </div>
    `,
    actions: `
      <button type="button" class="btn btn-ghost" onclick="window.Modal.close()">Cancel</button>
      <button type="button" class="btn btn-danger" id="confirm-empty-trash-action">💥 Yes, Empty Trash</button>
    `
  });

  setTimeout(() => {
    const confirmBtn = document.getElementById('confirm-empty-trash-action');
    if (confirmBtn) {
      confirmBtn.onclick = async () => {
        confirmBtn.disabled = true;
        confirmBtn.textContent = 'Emptying...';
        try {
          const res = await api.delete(`/api/trash/empty?type=${currentTab}`);
          Modal.close();
          if (res.success) {
            Toast.info(res.message || 'Recycle Bin emptied successfully');
            selectedItemIds.clear();
            _updateBulkButton();
            _loadCounts();
            _loadTrashList();
          } else {
            Toast.error(res.message || 'Failed to empty recycle bin');
          }
        } catch (e) {
          Modal.close();
          Toast.error(e.message || 'Empty trash failed');
        }
      };
    }
  }, 100);
}

function _formatRelativeDate(dateStr) {
  if (!dateStr) return 'Recently';
  const d = new Date(dateStr);
  const diffMs = Date.now() - d.getTime();
  const diffSec = Math.floor(diffMs / 1000);
  const diffMin = Math.floor(diffSec / 60);
  const diffHour = Math.floor(diffMin / 60);
  const diffDay = Math.floor(diffHour / 24);

  if (diffSec < 60) return 'Just now';
  if (diffMin < 60) return `${diffMin}m ago`;
  if (diffHour < 24) return `${diffHour}h ago`;
  if (diffDay < 30) return `${diffDay}d ago`;
  return d.toLocaleDateString();
}
