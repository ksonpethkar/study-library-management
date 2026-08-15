import api from '../api.js';
import { Toast, Modal, Confirm, escapeHTML } from '../ui.js';
import { ChartEngine } from '../charts.js';
import { MediaStudio, MediaFieldPicker } from '../mediaStudio.js';

function formatCurrency(num) {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
  }).format(num || 0);
}

function formatDate(d) {
  if (!d) return '-';
  return new Date(d).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  });
}

const CATEGORIES = [
  'Rent',
  'Electricity',
  'Salaries & Staff',
  'High-Speed Wi-Fi & Tech',
  'RO Water & Dispenser',
  'Cleaning & Housekeeping',
  'Maintenance & Repairs',
  'Stationery & Printing',
  'Security & CCTV',
  'Taxes & Legal',
  'Marketing & Ads',
  'Other'
];

export async function render(container) {
  const currentYear = new Date().getFullYear();
  const currentMonth = new Date().getMonth() + 1;

  let state = {
    selectedYear: currentYear,
    selectedMonth: currentMonth,
    selectedCategory: 'all',
    search: '',
    page: 1,
    limit: 15,
    summary: null,
    expenses: [],
    pagination: { page: 1, limit: 15, total: 0, pages: 1 }
  };

  const page = document.createElement('div');
  page.className = 'page-container';

  page.innerHTML = `
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>🏢 Expense Tracking & Profit-Loss (P&L)</h2>
        <p>Track operating costs, rent, electricity, salaries, vendor bills, and auto-calculate net business profit.</p>
      </div>
      <div class="module-actions">
        <button class="btn btn-outline-secondary" id="btn-export-expenses" style="font-weight: 600;">
          📥 Export CSV
        </button>
        <button class="btn btn-primary" id="btn-add-expense" style="font-weight: 700;">
          + Record Expense
        </button>
      </div>
    </div>

    <!-- Date & Category Filters Toolbar -->
    <div class="toolbar-card">
      <div class="d-flex flex-wrap align-items-center justify-content-between gap-3">
        <div class="d-flex align-items-center gap-2 flex-wrap">
          <label class="form-label mb-0 text-xs" style="font-weight: 700; color: var(--color-text-secondary);">📅 PERIOD:</label>
          <select id="expense-month-filter" class="form-select form-control form-control-sm" style="width: 150px; font-weight: 600;">
            <option value="all">Full Year (${currentYear})</option>
            <option value="1" ${currentMonth === 1 ? 'selected' : ''}>January</option>
            <option value="2" ${currentMonth === 2 ? 'selected' : ''}>February</option>
            <option value="3" ${currentMonth === 3 ? 'selected' : ''}>March</option>
            <option value="4" ${currentMonth === 4 ? 'selected' : ''}>April</option>
            <option value="5" ${currentMonth === 5 ? 'selected' : ''}>May</option>
            <option value="6" ${currentMonth === 6 ? 'selected' : ''}>June</option>
            <option value="7" ${currentMonth === 7 ? 'selected' : ''}>July</option>
            <option value="8" ${currentMonth === 8 ? 'selected' : ''}>August</option>
            <option value="9" ${currentMonth === 9 ? 'selected' : ''}>September</option>
            <option value="10" ${currentMonth === 10 ? 'selected' : ''}>October</option>
            <option value="11" ${currentMonth === 11 ? 'selected' : ''}>November</option>
            <option value="12" ${currentMonth === 12 ? 'selected' : ''}>December</option>
          </select>

          <select id="expense-year-filter" class="form-select form-control form-control-sm" style="width: 110px; font-weight: 600;">
            <option value="${currentYear}">${currentYear}</option>
            <option value="${currentYear - 1}">${currentYear - 1}</option>
            <option value="${currentYear - 2}">${currentYear - 2}</option>
          </select>
        </div>

        <div class="d-flex align-items-center gap-2 flex-wrap">
          <label class="form-label mb-0 text-xs" style="font-weight: 700; color: var(--color-text-secondary);">CATEGORY:</label>
          <select id="expense-category-filter" class="form-select form-control form-control-sm" style="width: 160px; font-weight: 600;">
            <option value="all">All Categories</option>
            ${CATEGORIES.map(c => `<option value="${escapeHTML(c)}">${escapeHTML(c)}</option>`).join('')}
          </select>
          <input type="text" id="expense-search-input" class="form-control form-control-sm" placeholder="Search title, vendor..." style="width: 220px;">
        </div>
      </div>
    </div>

    <!-- Standard P&L KPI Cards Grid -->
    <div class="kpi-grid" id="pnl-kpi-cards">
      <div class="kpi-card kpi-success">
        <div class="kpi-label">Total Fee Revenue <span>📈</span></div>
        <div class="kpi-value text-success" id="kpi-revenue">₹0</div>
        <div class="kpi-subtext">Gross revenue</div>
      </div>
      <div class="kpi-card kpi-danger">
        <div class="kpi-label">Total Expenses <span>📉</span></div>
        <div class="kpi-value text-danger" id="kpi-expense">₹0</div>
        <div class="kpi-subtext">Operating costs</div>
      </div>
      <div class="kpi-card kpi-primary">
        <div class="kpi-label">Net Profit / Margin <span>💰</span></div>
        <div class="kpi-value" id="kpi-net-profit" style="color: var(--color-primary);">₹0</div>
        <div class="kpi-subtext" id="kpi-margin-percent">Margin: 0%</div>
      </div>
      <div class="kpi-card kpi-warning">
        <div class="kpi-label">Top Expense Category <span>🏷️</span></div>
        <div class="kpi-value text-warning" id="kpi-top-category" style="font-size: 1.3rem;">-</div>
        <div class="kpi-subtext" id="kpi-top-category-amount">₹0</div>
      </div>
    </div>

    <!-- Charts Row -->
    <div class="row mb-4 g-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1.25rem;">
      <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <h6 style="font-weight: 700; margin-bottom: 1rem;">📊 Expense Breakdown by Category</h6>
        <div style="position: relative; height: 220px; width: 100%;">
          <canvas id="expense-category-chart"></canvas>
        </div>
      </div>

      <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <h6 style="font-weight: 700; margin-bottom: 1rem;">📈 6-Month Revenue vs Expense Trend</h6>
        <div style="position: relative; height: 220px; width: 100%;">
          <canvas id="expense-trend-chart"></canvas>
        </div>
      </div>
    </div>

    <!-- Expenses Table Card -->
    <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div class="card-header p-3 d-flex justify-content-between align-items-center" style="border-bottom: 1px solid var(--color-border);">
        <h5 style="font-weight: 700; margin: 0; font-size: 1rem;">📋 Expense Transactions Log</h5>
        <span class="badge badge-primary" id="expense-total-badge">0 items</span>
      </div>

      <div class="table-responsive">
        <table class="table data-table mb-0" style="width: 100%;">
          <thead>
            <tr>
              <th>Date</th>
              <th>Title & Description</th>
              <th>Category</th>
              <th>Vendor</th>
              <th>Payment Mode</th>
              <th class="text-right">Amount</th>
              <th class="text-center">Actions</th>
            </tr>
          </thead>
          <tbody id="expenses-table-body">
            <tr>
              <td colspan="7" class="text-center p-4 text-muted">Loading expenses...</td>
            </tr>
          </tbody>
        </table>
      </div>

      <!-- Pagination Footer -->
      <div class="p-3 d-flex justify-content-between align-items-center flex-wrap gap-2" style="border-top: 1px solid var(--color-border);">
        <span class="text-muted small" id="expense-page-info">Showing 0 of 0</span>
        <div class="d-flex gap-2">
          <button class="btn btn-sm btn-outline-secondary" id="expense-prev-btn" disabled>Previous</button>
          <button class="btn btn-sm btn-outline-secondary" id="expense-next-btn" disabled>Next</button>
        </div>
      </div>
    </div>
  `;

  container.innerHTML = '';
  container.appendChild(page);

  // Load initial data
  async function loadData() {
    try {
      const monthParam = state.selectedMonth === 'all' ? '' : `&month=${state.selectedMonth}`;
      const [summaryRes, listRes] = await Promise.all([
        api.get(`/api/expenses/summary?year=${state.selectedYear}${monthParam}`),
        api.get(`/api/expenses?page=${state.page}&limit=${state.limit}&year=${state.selectedYear}${monthParam}&category=${state.selectedCategory}&search=${encodeURIComponent(state.search)}`)
      ]);

      if (summaryRes.success && summaryRes.data) {
        state.summary = summaryRes.data;
        renderSummaryCards(state.summary);
        renderCharts(state.summary);
      }

      if (listRes.success && listRes.data) {
        state.expenses = listRes.data.expenses;
        state.pagination = listRes.data.pagination;
        renderTable(state.expenses, state.pagination);
      }
    } catch (err) {
      console.error('Failed to load expenses:', err);
      Toast.error('Failed to load financial records');
    }
  }

  function renderSummaryCards(data) {
    const revEl = page.querySelector('#kpi-revenue');
    const expEl = page.querySelector('#kpi-expense') || page.querySelector('#kpi-expenses');
    const profitEl = page.querySelector('#kpi-net-profit') || page.querySelector('#kpi-profit');
    const marginEl = page.querySelector('#kpi-margin-percent') || page.querySelector('#kpi-margin-sub');
    const expSubEl = page.querySelector('#kpi-expenses-sub');

    if (revEl) revEl.textContent = formatCurrency(data.totalRevenue);
    if (expEl) expEl.textContent = formatCurrency(data.totalExpenses);
    if (expSubEl) expSubEl.textContent = `Across ${data.totalExpenseCount || 0} expense records`;

    if (profitEl) {
      profitEl.textContent = formatCurrency(data.netProfit);
      profitEl.style.color = data.netProfit >= 0 ? 'var(--color-success)' : 'var(--color-danger)';
    }

    if (marginEl) {
      marginEl.textContent = `Profit Margin: ${data.profitMargin}% | Revenue: ${data.totalPaymentCount || 0} payments`;
    }
  }

  function renderCharts(data) {
    // 1. Category Chart
    const catCanvas = page.querySelector('#expense-category-chart');
    if (catCanvas && data.categoryBreakdown) {
      const labels = data.categoryBreakdown.map(c => c._id);
      const values = data.categoryBreakdown.map(c => c.total);

      if (labels.length === 0) {
        const ctx = catCanvas.getContext('2d');
        ctx.clearRect(0, 0, catCanvas.width, catCanvas.height);
        ctx.font = '14px sans-serif';
        ctx.fillStyle = '#888';
        ctx.textAlign = 'center';
        ctx.fillText('No expenses recorded for this period', catCanvas.width / 2 || 150, 100);
      } else {
        ChartEngine.barChart('expense-category-chart', {
          labels,
          data: values,
          color: '#ff7675',
          title: 'Expenses by Category (₹)'
        });
      }
    }

    // 2. Trend Chart
    const trendCanvas = page.querySelector('#expense-trend-chart');
    if (trendCanvas && data.sixMonthsTrend) {
      const labels = data.sixMonthsTrend.map(t => t.label);
      const netProfits = data.sixMonthsTrend.map(t => t.netProfit);

      ChartEngine.lineChart('expense-trend-chart', {
        labels,
        data: netProfits,
        color: '#6c5ce7',
        fill: true,
        title: 'Net Profit Trend (₹)'
      });
    }
  }

  function renderTable(expenses, pagination) {
    const tbody = page.querySelector('#expenses-table-body');
    const badge = page.querySelector('#expense-total-badge');
    const pageInfo = page.querySelector('#expense-page-info');
    const prevBtn = page.querySelector('#expense-prev-btn');
    const nextBtn = page.querySelector('#expense-next-btn');

    if (badge) badge.textContent = `${pagination.total} items`;
    if (pageInfo) pageInfo.textContent = `Page ${pagination.page} of ${pagination.pages || 1} (${pagination.total} total)`;

    if (prevBtn) prevBtn.disabled = pagination.page <= 1;
    if (nextBtn) nextBtn.disabled = pagination.page >= pagination.pages;

    if (!expenses || expenses.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" class="text-center p-4 text-muted">
            <div style="font-size: 2rem; margin-bottom: 0.5rem;">💸</div>
            <p style="margin: 0; font-weight: 500;">No expenses found matching the current filters.</p>
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = expenses.map(exp => {
      return `
        <tr>
          <td style="font-weight: 500; font-size: 0.85rem;">${formatDate(exp.date)}</td>
          <td>
            <div style="font-weight: 600; font-size: 0.9rem;">${escapeHTML(exp.title)}</div>
            ${exp.description ? `<div class="text-muted small" style="font-size: 0.75rem;">${escapeHTML(exp.description)}</div>` : ''}
          </td>
          <td>
            <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); font-size: 0.75rem;">
              ${escapeHTML(exp.category)}
            </span>
          </td>
          <td class="text-muted small">${escapeHTML(exp.vendor || '-')}</td>
          <td>
            <span class="badge" style="background: var(--color-bg-secondary); color: var(--color-text-secondary); text-transform: uppercase; font-size: 0.7rem;">
              ${escapeHTML(exp.paymentMethod)}
            </span>
          </td>
          <td class="text-right" style="font-weight: 700; color: var(--color-danger); font-size: 0.95rem;">
            ${formatCurrency(exp.amount)}
          </td>
          <td class="text-center">
            <div class="d-flex justify-content-center gap-1">
              <button class="btn btn-sm btn-ghost btn-edit-exp" data-id="${exp._id}" title="Edit Expense" style="padding: 2px 6px;">✏️</button>
              <button class="btn btn-sm btn-ghost text-danger btn-delete-exp" data-id="${exp._id}" title="Delete" style="padding: 2px 6px;">🗑️</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');

    // Wire edit & delete
    tbody.querySelectorAll('.btn-edit-exp').forEach(btn => {
      btn.addEventListener('click', () => {
        const item = state.expenses.find(e => e._id === btn.dataset.id);
        if (item) showExpenseModal(item);
      });
    });

    tbody.querySelectorAll('.btn-delete-exp').forEach(btn => {
      btn.addEventListener('click', async () => {
        const ok = await Confirm.show({
          title: 'Delete Expense Record',
          message: 'Are you sure you want to delete this expense? This will adjust the profit-loss figures.',
          danger: true
        });
        if (ok) {
          try {
            await api.delete(`/api/expenses/${btn.dataset.id}`);
            Toast.success('Expense deleted successfully');
            loadData();
          } catch (err) {
            Toast.error('Failed to delete expense');
          }
        }
      });
    });
  }

  function showExpenseModal(exp = null) {
    const isEdit = !!exp;
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="expense-form" class="p-1">
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Expense Title *</label>
          <input type="text" id="exp-title" class="form-control" placeholder="e.g., Office Rent, Power Bill, Wi-Fi 300Mbps" value="${escapeHTML(exp?.title || '')}" required>
        </div>

        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Category *</label>
            <select id="exp-category" class="form-select" required>
              ${CATEGORIES.map(c => `<option value="${escapeHTML(c)}" ${exp?.category === c ? 'selected' : ''}>${escapeHTML(c)}</option>`).join('')}
            </select>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">Amount (₹) *</label>
            <input type="number" id="exp-amount" class="form-control" placeholder="0" min="1" step="any" value="${exp?.amount || ''}" required>
          </div>
        </div>

        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Expense Date *</label>
            <input type="date" id="exp-date" class="form-control" value="${exp?.date ? new Date(exp.date).toISOString().split('T')[0] : new Date().toISOString().split('T')[0]}" required>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">Payment Mode</label>
            <select id="exp-payment-method" class="form-select">
              <option value="upi" ${exp?.paymentMethod === 'upi' ? 'selected' : ''}>UPI / QR</option>
              <option value="cash" ${exp?.paymentMethod === 'cash' ? 'selected' : ''}>Cash</option>
              <option value="bank_transfer" ${exp?.paymentMethod === 'bank_transfer' ? 'selected' : ''}>Bank Transfer / NEFT</option>
              <option value="card" ${exp?.paymentMethod === 'card' ? 'selected' : ''}>Debit/Credit Card</option>
              <option value="cheque" ${exp?.paymentMethod === 'cheque' ? 'selected' : ''}>Cheque</option>
            </select>
          </div>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Vendor / Payee</label>
          <input type="text" id="exp-vendor" class="form-control" placeholder="e.g. Landlord Name, Airtel, MSEB" value="${escapeHTML(exp?.vendor || '')}">
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Bill / Payment Receipt Scan</label>
          <div id="mount-expense-receipt"></div>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Notes / Description</label>
          <textarea id="exp-desc" class="form-control" rows="2" placeholder="Optional details or receipt reference">${escapeHTML(exp?.description || '')}</textarea>
        </div>

        <div class="d-flex justify-content-end gap-2 mt-4">
          <button type="button" class="btn btn-secondary" id="btn-cancel-exp">Cancel</button>
          <button type="submit" class="btn btn-primary" id="btn-save-exp">${isEdit ? 'Update Expense' : 'Save Expense'}</button>
        </div>
      </form>
    `;

    // Mount Smart Receipt Scanner
    const receiptMount = modalContent.querySelector('#mount-expense-receipt');
    if (receiptMount) {
      receiptMount.appendChild(MediaFieldPicker.create({
        label: 'Receipt / Invoice Proof (Camera / File)',
        preset: 'document',
        name: 'receiptImage',
        value: exp?.receiptImage || ''
      }));
    }

    const modal = new Modal({
      title: isEdit ? '✏️ Edit Operating Expense' : '➕ Record Operating Expense',
      content: modalContent,
      size: 'md'
    });
    modal.show();

    modalContent.querySelector('#btn-cancel-exp').onclick = () => modal.close();

    modalContent.querySelector('#expense-form').onsubmit = async (e) => {
      e.preventDefault();
      const title = modalContent.querySelector('#exp-title').value.trim();
      const category = modalContent.querySelector('#exp-category').value;
      const amount = parseFloat(modalContent.querySelector('#exp-amount').value);
      const date = modalContent.querySelector('#exp-date').value;
      const paymentMethod = modalContent.querySelector('#exp-payment-method').value;
      const vendor = modalContent.querySelector('#exp-vendor').value.trim();
      const receiptImage = modalContent.querySelector('input[name="receiptImage"]')?.value || '';
      const description = modalContent.querySelector('#exp-desc').value.trim();

      if (!title || !amount) {
        Toast.error('Please fill required fields');
        return;
      }

      const saveBtn = modalContent.querySelector('#btn-save-exp');
      saveBtn.disabled = true;
      saveBtn.textContent = 'Saving...';

      try {
        if (isEdit) {
          await api.put(`/api/expenses/${exp._id}`, {
            title, category, amount, date, paymentMethod, vendor, receiptImage, description
          });
          Toast.success('Expense updated');
        } else {
          await api.post('/api/expenses', {
            title, category, amount, date, paymentMethod, vendor, receiptImage, description
          });
          Toast.success('Expense recorded successfully');
        }
        modal.close();
        loadData();
      } catch (err) {
        Toast.error(err.message || 'Failed to save expense');
        saveBtn.disabled = false;
        saveBtn.textContent = isEdit ? 'Update Expense' : 'Save Expense';
      }
    };
  }

  // Filter event listeners
  page.querySelector('#expense-month-filter').addEventListener('change', (e) => {
    state.selectedMonth = e.target.value;
    state.page = 1;
    loadData();
  });

  page.querySelector('#expense-year-filter').addEventListener('change', (e) => {
    state.selectedYear = parseInt(e.target.value);
    state.page = 1;
    loadData();
  });

  page.querySelector('#expense-category-filter').addEventListener('change', (e) => {
    state.selectedCategory = e.target.value;
    state.page = 1;
    loadData();
  });

  page.querySelector('#expense-search-input').addEventListener('input', (e) => {
    state.search = e.target.value;
    state.page = 1;
    loadData();
  });

  page.querySelector('#btn-add-expense').addEventListener('click', () => {
    showExpenseModal();
  });

  page.querySelector('#expense-prev-btn').addEventListener('click', () => {
    if (state.page > 1) {
      state.page--;
      loadData();
    }
  });

  page.querySelector('#expense-next-btn').addEventListener('click', () => {
    if (state.page < state.pagination.pages) {
      state.page++;
      loadData();
    }
  });

  page.querySelector('#btn-export-expenses').addEventListener('click', () => {
    if (!state.expenses || state.expenses.length === 0) {
      Toast.warning('No expenses to export');
      return;
    }
    const headers = ['Date', 'Title', 'Category', 'Vendor', 'Payment Mode', 'Amount (INR)', 'Description'];
    const rows = state.expenses.map(e => [
      formatDate(e.date),
      `"${(e.title || '').replace(/"/g, '""')}"`,
      `"${(e.category || '').replace(/"/g, '""')}"`,
      `"${(e.vendor || '').replace(/"/g, '""')}"`,
      e.paymentMethod,
      e.amount,
      `"${(e.description || '').replace(/"/g, '""')}"`
    ]);

    const csvContent = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `study_library_expenses_${state.selectedYear}_${state.selectedMonth}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  });

  await loadData();
}
