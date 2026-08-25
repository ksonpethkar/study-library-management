import { App } from '../app.js';
import { t } from '../i18n.js';
import { Modal, Confirm, Toast, Loading, escapeHTML } from '../ui.js';
import { ChartEngine } from '../charts.js';
import api from '../api.js';

/**
 * Currency formatter (INR)
 */
const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
  }).format(amount || 0);
};

/**
 * Date formatter
 */
const formatDate = (dateString) => {
  if (!dateString) return '-';
  return new Date(dateString).toLocaleDateString('en-IN', {
    day: '2-digit',
    month: 'short',
    year: 'numeric'
  });
};

/**
 * Main Reports & Analytics Page Renderer
 */
export async function render(container) {
  if (!container) {
    container = document.getElementById('page-content') || document.createElement('div');
  }

  // Active state for reports page
  let activeTab = 'collections';
  let activeExpiryFilter = 'all';
  let currentRangeType = 'this_month';
  let currentRange = computeDateRange('this_month');
  let currentSearchQuery = '';

  let cachedOverview = null;
  let cachedRevenue = null;
  let cachedAttendance = null;
  let cachedExpiries = null;

  function computeDateRange(type) {
    const today = new Date();
    today.setHours(23, 59, 59, 999);
    const start = new Date(today);

    if (type === 'today') {
      start.setHours(0, 0, 0, 0);
    } else if (type === 'last_7_days') {
      start.setDate(today.getDate() - 6);
      start.setHours(0, 0, 0, 0);
    } else if (type === 'this_month') {
      start.setDate(1);
      start.setHours(0, 0, 0, 0);
    } else if (type === 'last_30_days') {
      start.setDate(today.getDate() - 29);
      start.setHours(0, 0, 0, 0);
    }
    return {
      type,
      startDate: start.toISOString().split('T')[0],
      endDate: today.toISOString().split('T')[0]
    };
  }

  container.innerHTML = `
    <div class="reports-container" style="display: flex; flex-direction: column; gap: var(--space-5);">
      
      <!-- Standard Module Header -->
      <div class="module-header">
        <div class="module-title-area">
          <div style="display: flex; align-items: center; gap: 8px;">
            <h2>📊 Reports & Analytics</h2>
            <span class="badge badge-primary" style="font-size: 0.75rem; text-transform: uppercase;">Real-time</span>
          </div>
          <p>Deep-dive financial collections, member occupancy, peak study hours, and expiry forecasting.</p>
        </div>

        <!-- Controls: Date Range Selector, Export Dropdown, Print -->
        <div class="module-actions">
          <!-- Date Range Selector -->
          <div class="date-range-wrapper d-flex align-items-center gap-1" style="background: var(--color-surface); padding: 4px; border: 1px solid var(--color-border); border-radius: var(--radius-md); box-shadow: var(--shadow-xs);">
            <select id="rangeSelect" class="form-select form-control" style="border: none; background: transparent; font-size: 0.85rem; font-weight: 600; padding: 6px 12px; cursor: pointer; color: var(--color-text-primary); outline: none;">
              <option value="today">Today</option>
              <option value="last_7_days">Last 7 Days</option>
              <option value="this_month" selected>This Month</option>
              <option value="last_30_days">Last 30 Days</option>
              <option value="custom">Custom Range</option>
            </select>
            
            <div id="customDateInputs" style="display: none; align-items: center; gap: 6px; padding-left: 6px; border-left: 1px solid var(--color-border);">
              <input type="date" id="customStartDate" class="form-control" style="padding: 4px 8px; font-size: 0.8rem; height: 32px; border: 1px solid var(--color-border); border-radius: var(--radius-sm);" />
              <span style="color: var(--color-text-muted); font-size: 0.8rem;">to</span>
              <input type="date" id="customEndDate" class="form-control" style="padding: 4px 8px; font-size: 0.8rem; height: 32px; border: 1px solid var(--color-border); border-radius: var(--radius-sm);" />
              <button id="btnApplyCustomDate" class="btn btn-sm btn-primary" style="padding: 4px 10px; font-size: 0.8rem; height: 32px;">Apply</button>
            </div>
          </div>

          <!-- Export Data Dropdown -->
          <div class="dropdown" id="exportDropdown">
            <button class="btn btn-secondary d-flex align-items-center gap-2" id="exportMenuBtn" style="font-size: 0.85rem; padding: 8px 14px; font-weight: 600;">
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></svg>
              <span>Export Data</span>
              <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 12 15 18 9"></polyline></svg>
            </button>
            <div class="dropdown-menu" id="exportMenu" style="right: 0; left: auto; min-width: 240px;">
              <a href="#" class="dropdown-item" id="exportPdfExecutiveSummary" style="font-weight: 700; color: var(--color-primary);">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="14 2 14 8 20 8"></polyline><line x1="16" y1="13" x2="8" y2="13"></line><line x1="16" y1="17" x2="8" y2="17"></line><polyline points="10 9 9 9 8 9"></polyline></svg>
                <span>📄 Executive Summary (PDF Print)</span>
              </a>
              <div class="dropdown-divider" style="border-top: 1px solid var(--color-border); margin: 4px 0;"></div>
              <a href="#" class="dropdown-item" id="exportStudentsCsv">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>
                <span>Students List (.CSV)</span>
              </a>
              <a href="#" class="dropdown-item" id="exportPaymentsCsv">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>
                <span>Financial Ledger (.CSV)</span>
              </a>
              <a href="#" class="dropdown-item" id="exportAttendanceCsv">
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>
                <span>Attendance Log (.CSV)</span>
              </a>
            </div>
          </div>

          <!-- Print Report -->
          <button class="btn btn-outline-secondary d-flex align-items-center gap-2" id="btnPrintReport" style="font-size: 0.85rem; padding: 8px 14px; font-weight: 600;">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg>
            <span>Print Report</span>
          </button>
        </div>
      </div>

      <!-- Contextual Guidance Tip Banner -->
      <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
        <span style="font-size: 1.1rem;">💡</span>
        <span><strong>Tip:</strong> Reports update automatically in real-time. Export clean Excel spreadsheets or PDF statements with 1 click.</span>
      </div>

      <!-- Top Standard KPI Metrics Grid -->
      <div class="kpi-grid">
        
        <!-- Total Revenue Card -->
        <div class="kpi-card kpi-primary">
          <div class="kpi-label">Revenue in Period <span>💳</span></div>
          <div class="kpi-value" id="metricPeriodRevenue" style="color: var(--color-primary);">₹0</div>
          <div class="kpi-subtext" id="metricRevenueTransactions">0 transactions</div>
        </div>

        <!-- Avg Daily Check-ins Card -->
        <div class="kpi-card kpi-success">
          <div class="kpi-label">Avg Daily Check-ins <span>⏱️</span></div>
          <div class="kpi-value text-success" id="metricAvgDailyCheckins">0</div>
          <div class="kpi-subtext" id="metricPeakHour">Peak: --</div>
        </div>

        <!-- Renewal Rate % Card -->
        <div class="kpi-card kpi-info">
          <div class="kpi-label">Renewal Rate <span>📈</span></div>
          <div class="kpi-value" id="metricRenewalRate" style="color: var(--color-info);">0%</div>
          <div class="kpi-subtext" id="metricActiveStudents">0 active members</div>
        </div>

        <!-- Pending Dues Card -->
        <div class="kpi-card kpi-danger">
          <div class="kpi-label">Pending Dues <span>⚠️</span></div>
          <div class="kpi-value text-danger" id="metricPendingDues">₹0</div>
          <div class="kpi-subtext" id="metricPendingCount">0 overdue accounts</div>
        </div>

      </div>

      <!-- Multi-Branch Comparative Analytics -->
      <div class="card mb-2" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2" style="border-bottom: 1px solid var(--color-divider);">
          <h3 style="margin: 0; font-size: 1rem; font-weight: 700; display: flex; align-items: center; gap: 8px;">
            <span>🏢</span> Multi-Branch Comparative Analytics & Occupancy P&L
          </h3>
          <span class="badge badge-primary" id="branchAnalyticsCount">0 Branches</span>
        </div>
        <div class="card-body p-3">
          <div id="multiBranchGrid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 240px), 1fr)); gap: 1rem;">
            <div class="text-muted small text-center p-3">Loading branch analytics...</div>
          </div>
        </div>
      </div>

      <!-- Tally & GST Accounting Exports Card -->
      <div class="card mb-2" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2" style="border-bottom: 1px solid var(--color-divider);">
          <h3 style="margin: 0; font-size: 1rem; font-weight: 700; display: flex; align-items: center; gap: 8px;">
            <span>📑</span> Tally & GST Accounting Exports
          </h3>
          <span class="badge badge-success" style="font-size: 0.75rem;">GSTR-1 & Tally Prime Ready</span>
        </div>
        <div class="card-body p-3">
          <p class="small text-muted mb-3" style="margin-bottom: 12px;">Export fee collections and operational expense ledgers formatted for Tally Prime XML import or download GSTR-1 & GSTR-3B B2C tax compliance summaries.</p>
          <div class="d-flex align-items-center gap-3 flex-wrap">
            <button class="btn btn-primary d-flex align-items-center gap-2" id="btnDownloadTallyXml" style="font-weight: 600;">
              <span>📥</span> Download Tally XML Import File
            </button>
            <button class="btn btn-secondary d-flex align-items-center gap-2" id="btnDownloadGstReport" style="font-weight: 600;">
              <span>📊</span> Download GST Sales Summary Report (CSV)
            </button>
          </div>
        </div>
      </div>

      <!-- Charts Section -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 320px), 1fr)); gap: 1.25rem;">
        
        <!-- Revenue Trend Chart -->
        <div class="card" style="background: var(--color-surface);">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h3 style="margin: 0; font-size: 1rem; font-weight: 600; display: flex; align-items: center; gap: 8px;">
              <span>📈</span> Revenue Trend (Collections)
            </h3>
            <span class="badge badge-primary" id="trendChartTotal">₹0</span>
          </div>
          <div class="card-body" style="padding: 16px; position: relative;">
            <canvas id="revenueTrendChart" style="width: 100%; height: 220px; max-height: 220px; display: block;"></canvas>
          </div>
        </div>

        <!-- Payment Method Distribution Chart -->
        <div class="card" style="background: var(--color-surface);">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h3 style="margin: 0; font-size: 1rem; font-weight: 600; display: flex; align-items: center; gap: 8px;">
              <span>💳</span> Payment Methods Breakdown
            </h3>
            <span class="badge badge-ghost" id="methodBreakdownTotal">Total ₹0</span>
          </div>
          <div class="card-body" style="padding: 16px; display: flex; flex-direction: column; align-items: center;">
            <canvas id="paymentMethodChart" style="width: min(180px, 100%); height: min(180px, 50vw); max-height: 180px; margin-bottom: 12px;"></canvas>
            <div id="paymentMethodLegend" style="display: flex; flex-wrap: wrap; justify-content: center; gap: 10px; width: 100%; font-size: 0.8rem;"></div>
          </div>
        </div>

        <!-- Hourly Attendance Distribution Chart -->
        <div class="card" style="background: var(--color-surface);">
          <div class="card-header d-flex justify-content-between align-items-center">
            <h3 style="margin: 0; font-size: 1rem; font-weight: 600; display: flex; align-items: center; gap: 8px;">
              <span>⏱️</span> Peak Study & Occupancy Hours
            </h3>
            <span class="badge badge-success" id="hourlyChartPeak">06:00 - 23:00</span>
          </div>
          <div class="card-body" style="padding: 16px; position: relative;">
            <canvas id="hourlyAttendanceChart" style="width: 100%; height: 220px; max-height: 220px; display: block;"></canvas>
          </div>
        </div>

      </div>

      <!-- Tabbed Report Tables Card -->
      <div class="card" style="background: var(--color-surface);">
        <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-3" style="border-bottom: none; padding-bottom: 0;">
          
          <!-- Tab Navigation -->
          <div class="tabs mb-0" style="border-bottom: none; margin-bottom: 0;">
            <button class="tab-item active" data-tab="collections" style="font-size: 0.95rem; display: flex; align-items: center; gap: 6px;">
              <span>💰 Financial Collections</span>
              <span class="badge badge-ghost" id="tabCountCollections">0</span>
            </button>
            <button class="tab-item" data-tab="expiries" style="font-size: 0.95rem; display: flex; align-items: center; gap: 6px;">
              <span>⚠️ Upcoming Expiries</span>
              <span class="badge badge-warning" id="tabCountExpiries">0</span>
            </button>
            <button class="tab-item" data-tab="attendance" style="font-size: 0.95rem; display: flex; align-items: center; gap: 6px;">
              <span>📊 Attendance Analytics</span>
              <span class="badge badge-ghost" id="tabCountAttendance">0</span>
            </button>
          </div>

          <!-- Table Search & Filters -->
          <div class="d-flex align-items-center gap-2 flex-wrap">
            <div class="search-box" style="position: relative; min-width: 220px;">
              <input type="text" id="reportSearchInput" class="form-control" placeholder="Search in table..." style="padding: 6px 12px 6px 32px; font-size: 0.85rem; border-radius: var(--radius-md);" />
              <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2" style="position: absolute; left: 10px; top: 50%; transform: translateY(-50%); color: var(--color-text-muted);"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
            </div>
          </div>

        </div>

        <div class="card-body p-0" style="border-top: 1px solid var(--color-divider); margin-top: 10px;">
          
          <!-- TAB 1: Financial Collections -->
          <div id="tabContentCollections" class="tab-content-panel">
            <div class="table-responsive">
              <table class="table data-table mb-0">
                <thead>
                  <tr>
                    <th>Receipt #</th>
                    <th>Date</th>
                    <th>Student Details</th>
                    <th>Membership Plan</th>
                    <th>Method</th>
                    <th style="text-align: right;">Amount Paid</th>
                    <th>Status</th>
                    <th style="text-align: center;">Action</th>
                  </tr>
                </thead>
                <tbody id="collectionsTableBody">
                  <tr><td colspan="8" class="text-center p-4 text-muted">Loading financial collections...</td></tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- TAB 2: Upcoming Expiries -->
          <div id="tabContentExpiries" class="tab-content-panel" style="display: none;">
            
            <!-- Expiry sub-filter pills -->
            <div class="d-flex align-items-center gap-2 p-3" style="background: var(--color-bg-secondary); border-bottom: 1px solid var(--color-divider); flex-wrap: wrap;">
              <span class="small text-muted" style="font-weight: 500;">Filter Expiry:</span>
              <button class="btn btn-sm btn-primary expiry-filter-btn" data-filter="all" style="padding: 3px 10px; font-size: 0.8rem;">All Active</button>
              <button class="btn btn-sm btn-outline-secondary expiry-filter-btn" data-filter="7" style="padding: 3px 10px; font-size: 0.8rem;">Next 7 Days (<span id="expCount7">0</span>)</button>
              <button class="btn btn-sm btn-outline-secondary expiry-filter-btn" data-filter="15" style="padding: 3px 10px; font-size: 0.8rem;">Next 15 Days (<span id="expCount15">0</span>)</button>
              <button class="btn btn-sm btn-outline-secondary expiry-filter-btn" data-filter="30" style="padding: 3px 10px; font-size: 0.8rem;">Next 30 Days (<span id="expCount30">0</span>)</button>
              <button class="btn btn-sm btn-outline-danger expiry-filter-btn" data-filter="expired" style="padding: 3px 10px; font-size: 0.8rem;">Already Expired (<span id="expCountExpired">0</span>)</button>
            </div>

            <div class="table-responsive">
              <table class="table data-table mb-0">
                <thead>
                  <tr>
                    <th>Student Name & ID</th>
                    <th>Phone / Contact</th>
                    <th>Current Plan</th>
                    <th>Assigned Seat</th>
                    <th>Expiry Date</th>
                    <th>Days Remaining</th>
                    <th style="text-align: center;">Action</th>
                  </tr>
                </thead>
                <tbody id="expiriesTableBody">
                  <tr><td colspan="7" class="text-center p-4 text-muted">Loading upcoming expiries...</td></tr>
                </tbody>
              </table>
            </div>
          </div>

          <!-- TAB 3: Attendance Analytics -->
          <div id="tabContentAttendance" class="tab-content-panel" style="display: none;">
            <div class="table-responsive">
              <table class="table data-table mb-0">
                <thead>
                  <tr>
                    <th>Rank</th>
                    <th>Student Name & ID</th>
                    <th>Phone</th>
                    <th style="text-align: center;">Days Present</th>
                    <th style="text-align: center;">Total Study Hours</th>
                    <th style="text-align: center;">Avg Hours / Day</th>
                    <th>Attendance Rate</th>
                  </tr>
                </thead>
                <tbody id="attendanceTableBody">
                  <tr><td colspan="7" class="text-center p-4 text-muted">Loading attendance analytics...</td></tr>
                </tbody>
              </table>
            </div>
          </div>

        </div>

        <!-- Card Footer with summary and export shortcut buttons -->
        <div class="card-footer d-flex justify-content-between align-items-center flex-wrap gap-3" style="padding: 12px 20px; background: var(--color-surface-hover);">
          <div class="small text-muted" id="tableSummaryFooter">
            Showing records for current period
          </div>
          <div class="d-flex align-items-center gap-2">
            <button class="btn btn-sm btn-outline-secondary" id="btnQuickStudentsCsv">
              📥 Students CSV
            </button>
            <button class="btn btn-sm btn-outline-secondary" id="btnQuickPaymentsCsv">
              💳 Payments CSV
            </button>
            <button class="btn btn-sm btn-outline-secondary" id="btnQuickAttendanceCsv">
              ⏱️ Attendance CSV
            </button>
          </div>
        </div>

      </div>

    </div>
  `;

  // Attach event handlers and load data
  initEventHandlers();
  await loadAllData();

  // Mount context-aware FAB for Reports page
  if (typeof window !== 'undefined' && window.FAB) {
    window.FAB.mount({
      icon: '📊',
      label: 'Reports & Export Actions',
      color: '#6c5ce7',
      actions: [
        {
          icon: '📥',
          label: 'Tally XML Export',
          onClick: () => {
            downloadTallyXml();
          }
        },
        {
          icon: '📑',
          label: 'GST Sales Summary',
          onClick: () => {
            downloadGstReport();
          }
        },
        {
          icon: '🖨️',
          label: 'Print Analytics',
          onClick: () => {
            window.print();
          }
        }
      ]
    });
  }

  return container;

  /**
   * Bind DOM Events
   */
  function initEventHandlers() {
    // Range select change
    const rangeSelect = container.querySelector('#rangeSelect');
    const customDateInputs = container.querySelector('#customDateInputs');
    const customStart = container.querySelector('#customStartDate');
    const customEnd = container.querySelector('#customEndDate');
    const btnApplyCustom = container.querySelector('#btnApplyCustomDate');

    if (rangeSelect) {
      // Set defaults for custom inputs
      const todayStr = new Date().toISOString().split('T')[0];
      const monthStartStr = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0];
      if (customStart) customStart.value = monthStartStr;
      if (customEnd) customEnd.value = todayStr;

      rangeSelect.addEventListener('change', async (e) => {
        const val = e.target.value;
        currentRangeType = val;
        if (val === 'custom') {
          if (customDateInputs) customDateInputs.style.display = 'inline-flex';
        } else {
          if (customDateInputs) customDateInputs.style.display = 'none';
          currentRange = computeDateRange(val);
          await loadAllData();
        }
      });
    }

    if (btnApplyCustom) {
      btnApplyCustom.addEventListener('click', async () => {
        if (!customStart?.value || !customEnd?.value) {
          Toast.error('Please select both Start Date and End Date');
          return;
        }
        if (new Date(customStart.value) > new Date(customEnd.value)) {
          Toast.error('Start Date cannot be after End Date');
          return;
        }
        currentRange = {
          type: 'custom',
          startDate: customStart.value,
          endDate: customEnd.value
        };
        await loadAllData();
      });
    }

    // Export Dropdown toggling
    const exportDropdown = container.querySelector('#exportDropdown');
    const exportMenuBtn = container.querySelector('#exportMenuBtn');
    if (exportMenuBtn && exportDropdown) {
      exportMenuBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        exportDropdown.classList.toggle('active');
      });

      if (window._repExportClickCleanup) {
        document.removeEventListener('click', window._repExportClickCleanup);
      }
      window._repExportClickCleanup = (e) => {
        if (!exportDropdown.contains(e.target)) {
          exportDropdown.classList.remove('active');
        }
      };
      document.addEventListener('click', window._repExportClickCleanup);
    }

    // Export Actions
    const exportPdfExecutiveSummary = container.querySelector('#exportPdfExecutiveSummary');
    const exportStudentsCsv = container.querySelector('#exportStudentsCsv');
    const exportPaymentsCsv = container.querySelector('#exportPaymentsCsv');
    const exportAttendanceCsv = container.querySelector('#exportAttendanceCsv');
    const exportJsonReport = container.querySelector('#exportJsonReport');

    const btnQuickStudentsCsv = container.querySelector('#btnQuickStudentsCsv');
    const btnQuickPaymentsCsv = container.querySelector('#btnQuickPaymentsCsv');
    const btnQuickAttendanceCsv = container.querySelector('#btnQuickAttendanceCsv');

    if (exportPdfExecutiveSummary) exportPdfExecutiveSummary.onclick = (e) => { e.preventDefault(); window.print(); };
    if (exportStudentsCsv) exportStudentsCsv.onclick = (e) => { e.preventDefault(); downloadReport('students', 'csv'); };
    if (exportPaymentsCsv) exportPaymentsCsv.onclick = (e) => { e.preventDefault(); downloadReport('payments', 'csv'); };
    if (exportAttendanceCsv) exportAttendanceCsv.onclick = (e) => { e.preventDefault(); downloadReport('attendance', 'csv'); };
    if (exportJsonReport) exportJsonReport.onclick = (e) => { e.preventDefault(); downloadReport('payments', 'json'); };

    if (btnQuickStudentsCsv) btnQuickStudentsCsv.onclick = () => downloadReport('students', 'csv');
    if (btnQuickPaymentsCsv) btnQuickPaymentsCsv.onclick = () => downloadReport('payments', 'csv');
    if (btnQuickAttendanceCsv) btnQuickAttendanceCsv.onclick = () => downloadReport('attendance', 'csv');

    // Tally & GST Export card action buttons
    const btnDownloadTallyXml = container.querySelector('#btnDownloadTallyXml');
    const btnDownloadGstReport = container.querySelector('#btnDownloadGstReport');

    if (btnDownloadTallyXml) btnDownloadTallyXml.onclick = () => downloadTallyXml();
    if (btnDownloadGstReport) btnDownloadGstReport.onclick = () => downloadGstReport();

    // Print summary
    const btnPrintSummary = container.querySelector('#btnPrintReport') || container.querySelector('#btnPrintSummary');
    if (btnPrintSummary) {
      btnPrintSummary.addEventListener('click', () => {
        window.print();
      });
    }

    // Tab Navigation
    const tabButtons = container.querySelectorAll('.tabs .tab-item');
    tabButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        tabButtons.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        activeTab = btn.dataset.tab;

        const panels = container.querySelectorAll('.tab-content-panel');
        panels.forEach(p => p.style.display = 'none');

        if (activeTab === 'collections') {
          const p = container.querySelector('#tabContentCollections');
          if (p) p.style.display = 'block';
          renderCollectionsTable();
        } else if (activeTab === 'expiries') {
          const p = container.querySelector('#tabContentExpiries');
          if (p) p.style.display = 'block';
          renderExpiriesTable();
        } else if (activeTab === 'attendance') {
          const p = container.querySelector('#tabContentAttendance');
          if (p) p.style.display = 'block';
          renderAttendanceTable();
        }
      });
    });

    // Expiry sub-filter buttons
    const expFilterButtons = container.querySelectorAll('.expiry-filter-btn');
    expFilterButtons.forEach(btn => {
      btn.addEventListener('click', () => {
        expFilterButtons.forEach(b => {
          b.className = 'btn btn-sm btn-outline-secondary expiry-filter-btn';
        });
        if (btn.dataset.filter === 'expired') {
          btn.className = 'btn btn-sm btn-danger expiry-filter-btn';
        } else {
          btn.className = 'btn btn-sm btn-primary expiry-filter-btn';
        }
        activeExpiryFilter = btn.dataset.filter;
        renderExpiriesTable();
      });
    });

    // Search input filtering
    const searchInput = container.querySelector('#reportSearchInput');
    if (searchInput) {
      searchInput.addEventListener('input', (e) => {
        currentSearchQuery = e.target.value.toLowerCase().trim();
        if (activeTab === 'collections') renderCollectionsTable();
        else if (activeTab === 'expiries') renderExpiriesTable();
        else if (activeTab === 'attendance') renderAttendanceTable();
      });
    }
  }

  /**
   * Load all reports data from backend
   */
  async function loadAllData() {
    try {
      const { startDate, endDate } = currentRange;
      const params = { startDate, endDate };

      // Fetch all reports in parallel
      const [overviewRes, revenueRes, attendanceRes, expiriesRes, branchesRes] = await Promise.allSettled([
        api.get('/api/reports/overview', params),
        api.get('/api/reports/revenue', params),
        api.get('/api/reports/attendance', params),
        api.get('/api/reports/expiries', { days: 30 }),
        api.get('/api/branches')
      ]);

      if (overviewRes.status === 'fulfilled' && overviewRes.value?.success) {
        cachedOverview = overviewRes.value.data;
        updateOverviewCards(cachedOverview);
      }

      if (branchesRes.status === 'fulfilled' && branchesRes.value?.success) {
        renderMultiBranchAnalytics(branchesRes.value.data);
      } else {
        renderMultiBranchAnalytics([]);
      }

      if (revenueRes.status === 'fulfilled' && revenueRes.value?.success) {
        cachedRevenue = revenueRes.value.data;
        renderRevenueTrendChart(cachedRevenue);
        renderPaymentMethodChart(cachedRevenue);
        renderCollectionsTable();
      }

      if (attendanceRes.status === 'fulfilled' && attendanceRes.value?.success) {
        cachedAttendance = attendanceRes.value.data;
        renderHourlyAttendanceChart(cachedAttendance);
        renderAttendanceTable();
      }

      if (expiriesRes.status === 'fulfilled' && expiriesRes.value?.success) {
        cachedExpiries = expiriesRes.value.data;
        updateExpiryBadges(cachedExpiries);
        renderExpiriesTable();
      }

    } catch (err) {
      console.error('Error loading reports analytics:', err);
      Toast.error('Failed to load reports data. Please check backend connection.');
    }
  }

  /**
   * Render Multi-Branch Comparative Analytics Cards
   */
  function renderMultiBranchAnalytics(branches) {
    const grid = container.querySelector('#multiBranchGrid');
    const badge = container.querySelector('#branchAnalyticsCount');
    if (!grid) return;

    if (!branches || branches.length === 0) {
      grid.innerHTML = `<div class="text-muted small text-center p-3">No active branch locations registered.</div>`;
      if (badge) badge.textContent = '0 Branches';
      return;
    }

    if (badge) badge.textContent = `${branches.length} ${branches.length === 1 ? 'Branch' : 'Branches'}`;

    grid.innerHTML = branches.map(b => {
      const occPct = b.occupancyPercent || 0;
      let barColor = 'var(--color-success)';
      if (occPct > 85) barColor = 'var(--color-danger)';
      else if (occPct > 60) barColor = 'var(--color-primary)';

      return `
        <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 14px;">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 8px;">
            <div>
              <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-text-primary);">${escapeHTML(b.name)}</div>
              <div style="font-size: 0.78rem; color: var(--color-text-secondary);">${escapeHTML(b.city || '')} ${b.isMainBranch ? '• <span class="badge badge-primary" style="font-size: 0.65rem;">MAIN</span>' : ''}</div>
            </div>
            <span class="badge ${b.isActive ? 'badge-success' : 'badge-secondary'}" style="font-size: 0.7rem;">${b.isActive ? 'Active' : 'Inactive'}</span>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 8px; font-size: 0.82rem; margin-bottom: 10px;">
            <div><span class="text-muted d-block small">Occupancy</span><strong style="color: var(--color-primary);">${b.occupiedSeats || 0} / ${b.effectiveCapacity || b.totalSeats || 50}</strong></div>
            <div><span class="text-muted d-block small">Active Members</span><strong>${b.activeStudents || 0}</strong></div>
          </div>

          <div style="margin-top: 6px;">
            <div style="display: flex; justify-content: space-between; font-size: 0.75rem; margin-bottom: 4px; color: var(--color-text-muted);">
              <span>Occupancy Rate</span>
              <strong>${occPct}%</strong>
            </div>
            <div class="progress" style="height: 6px;">
              <div class="progress-bar" style="width: ${occPct}%; background: ${barColor};"></div>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  /**
   * Update top metric cards
   */
  function updateOverviewCards(data) {
    if (!data) return;

    const elRev = container.querySelector('#metricPeriodRevenue');
    const elRevTx = container.querySelector('#metricRevenueTransactions');
    const elCheck = container.querySelector('#metricAvgDailyCheckins');
    const elPeak = container.querySelector('#metricPeakHour');
    const elRenew = container.querySelector('#metricRenewalRate');
    const elActive = container.querySelector('#metricActiveStudents');
    const elDues = container.querySelector('#metricPendingDues');
    const elDuesCount = container.querySelector('#metricPendingCount');

    if (elRev) elRev.textContent = formatCurrency(data.periodRevenue);
    if (elRevTx) elRevTx.textContent = `${data.periodTransactions || 0} collections (${formatDate(data.period?.startDate)} - ${formatDate(data.period?.endDate)})`;
    if (elRenew) elRenew.textContent = `${data.renewalRate || 0}%`;
    if (elActive) elActive.textContent = `${data.totalActiveStudents || 0} of ${data.totalStudents || 0} active members`;
    if (elDues) elDues.textContent = formatCurrency(data.pendingPaymentsAmount);
    if (elDuesCount) elDuesCount.textContent = `${data.pendingDuesCount || 0} overdue memberships`;
  }

  /**
   * Update expiry counts on tabs and sub-filter pills
   */
  function updateExpiryBadges(data) {
    if (!data) return;
    const { counts } = data;
    const elCount7 = container.querySelector('#expCount7');
    const elCount15 = container.querySelector('#expCount15');
    const elCount30 = container.querySelector('#expCount30');
    const elCountExp = container.querySelector('#expCountExpired');
    const elTabExp = container.querySelector('#tabCountExpiries');

    if (elCount7) elCount7.textContent = counts.count7 || 0;
    if (elCount15) elCount15.textContent = counts.count15 || 0;
    if (elCount30) elCount30.textContent = counts.count30 || 0;
    if (elCountExp) elCountExp.textContent = counts.countExpired || 0;
    if (elTabExp) elTabExp.textContent = counts.total || 0;
  }

  /**
   * Render Revenue Trend Chart (Area / Line Chart)
   */
  function renderRevenueTrendChart(data) {
    if (!data || !data.trend) return;

    const totalRev = data.summary?.totalRevenue || 0;
    const badge = container.querySelector('#trendChartTotal');
    if (badge) badge.textContent = `Total: ${formatCurrency(totalRev)}`;

    const labels = data.trend.map(t => {
      const parts = t.date.split('-');
      return parts.length === 3 ? `${parts[2]}/${parts[1]}` : t.date;
    });
    const values = data.trend.map(t => t.amount);

    // If all values are 0, provide placeholder
    if (values.length === 0) {
      labels.push('No Data');
      values.push(0);
    }

    try {
      ChartEngine.areaChart('revenueTrendChart', {
        labels: labels.length > 15 ? labels.filter((_, i) => i % Math.ceil(labels.length / 10) === 0) : labels,
        data: values,
        color: '#6c5ce7',
        title: 'Daily Collections'
      });
    } catch (e) {
      console.warn('Revenue chart render issue:', e);
    }
  }

  /**
   * Render Payment Method Doughnut Chart
   */
  function renderPaymentMethodChart(data) {
    if (!data || !data.byMethod) return;

    const { cash = 0, upi = 0, bank_transfer = 0, card = 0, other = 0 } = data.byMethod;
    const total = cash + upi + bank_transfer + card + other;

    const badge = container.querySelector('#methodBreakdownTotal');
    if (badge) badge.textContent = `Total ${formatCurrency(total)}`;

    const chartLabels = ['UPI', 'Cash', 'Bank Transfer', 'Card', 'Other'];
    const chartData = [upi, cash, bank_transfer, card, other];
    const chartColors = ['#6c5ce7', '#00b894', '#0984e3', '#fdcb6e', '#a29bfe'];

    try {
      ChartEngine.doughnutChart('paymentMethodChart', {
        labels: chartLabels,
        data: total > 0 ? chartData : [1],
        colors: total > 0 ? chartColors : ['#333'],
        title: 'Payment Methods'
      });
    } catch (e) {
      console.warn('Payment method chart issue:', e);
    }

    // Render custom legend
    const legendContainer = container.querySelector('#paymentMethodLegend');
    if (legendContainer) {
      legendContainer.innerHTML = chartLabels.map((label, i) => {
        const amt = chartData[i];
        const pct = total > 0 ? Math.round((amt / total) * 100) : 0;
        return `
          <div style="display: flex; align-items: center; gap: 6px;">
            <span style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; background: ${chartColors[i]};"></span>
            <span style="color: var(--color-text-secondary);">${label}:</span>
            <strong style="color: var(--color-text-primary);">${formatCurrency(amt)} (${pct}%)</strong>
          </div>
        `;
      }).join('');
    }
  }

  /**
   * Render Hourly Attendance Distribution Chart (Bar Chart)
   */
  function renderHourlyAttendanceChart(data) {
    if (!data || !data.hourlyDistribution) return;

    const hourly = data.hourlyDistribution;
    const stats = data.stats;

    const elCheck = container.querySelector('#metricAvgDailyCheckins');
    const elPeak = container.querySelector('#metricPeakHour');
    const elPeakBadge = container.querySelector('#hourlyChartPeak');

    if (elCheck) elCheck.textContent = `${stats?.avgDailyCheckIns || 0} / day`;
    if (elPeak) elPeak.textContent = `Peak: ${stats?.peakHour || 'N/A'}`;
    if (elPeakBadge) elPeakBadge.textContent = `Peak: ${stats?.peakHourData?.displayLabel || 'N/A'}`;

    // Filter library active hours from 06:00 to 23:00 for clearer graph
    const filteredHours = hourly.filter(h => h.hour >= 6 && h.hour <= 23);
    const labels = filteredHours.map(h => h.displayLabel);
    const counts = filteredHours.map(h => h.count);

    try {
      ChartEngine.barChart('hourlyAttendanceChart', {
        labels,
        data: counts,
        color: '#00b894',
        title: 'Occupancy Distribution'
      });
    } catch (e) {
      console.warn('Attendance chart issue:', e);
    }
  }

  /**
   * Render Tab 1: Financial Collections Table
   */
  function renderCollectionsTable() {
    const tbody = container.querySelector('#collectionsTableBody');
    const tabCount = container.querySelector('#tabCountCollections');
    if (!tbody) return;

    const collections = cachedRevenue?.collections || [];
    let filtered = collections;

    if (currentSearchQuery) {
      filtered = filtered.filter(p => {
        const sName = p.student?.name || '';
        const sPhone = p.student?.phone || '';
        const sId = p.student?.studentId || '';
        const rec = p.receiptNumber || '';
        const method = p.paymentMethod || '';
        return sName.toLowerCase().includes(currentSearchQuery) ||
          sPhone.toLowerCase().includes(currentSearchQuery) ||
          sId.toLowerCase().includes(currentSearchQuery) ||
          rec.toLowerCase().includes(currentSearchQuery) ||
          method.toLowerCase().includes(currentSearchQuery);
      });
    }

    if (tabCount) tabCount.textContent = collections.length;

    if (filtered.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="8" class="text-center p-4 text-muted">
            <div style="font-size: 1.2rem; margin-bottom: 4px;">💸</div>
            No financial collection records found in this range.
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = filtered.map(p => {
      const receiptNo = p.receiptNumber || 'N/A';
      const studentName = p.student?.name || 'Unknown Student';
      const studentId = p.student?.studentId || '';
      const studentPhone = p.student?.phone || '';
      const planName = p.plan?.name || 'Custom / Direct Plan';
      const amount = formatCurrency(p.finalAmount || p.amount);
      const method = (p.paymentMethod || 'cash').toUpperCase();
      const status = p.status || 'paid';
      const date = formatDate(p.paymentDate);

      let methodBadgeClass = 'badge-primary';
      if (method === 'UPI') methodBadgeClass = 'badge-primary';
      else if (method === 'CASH') methodBadgeClass = 'badge-success';
      else if (method === 'CARD') methodBadgeClass = 'badge-warning';
      else if (method === 'BANK_TRANSFER') methodBadgeClass = 'badge-info';

      return `
        <tr>
          <td>
            <a href="#" class="view-receipt-btn" data-id="${p._id}" style="font-family: monospace; font-weight: 700; color: var(--color-primary); text-decoration: none;">
              ${escapeHTML(receiptNo)}
            </a>
          </td>
          <td style="white-space: nowrap; color: var(--color-text-secondary); font-size: 0.85rem;">
            ${date}
          </td>
          <td>
            <div style="font-weight: 600; color: var(--color-text-primary);">${escapeHTML(studentName)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${escapeHTML(studentId)} ${studentPhone ? `• ${escapeHTML(studentPhone)}` : ''}</div>
          </td>
          <td>
            <span class="badge badge-ghost" style="font-weight: 500;">${escapeHTML(planName)}</span>
          </td>
          <td>
            <span class="badge ${methodBadgeClass}" style="font-size: 0.75rem;">${escapeHTML(method)}</span>
          </td>
          <td style="text-align: right;">
            <strong style="font-size: 1rem; color: var(--color-text-primary);">${amount}</strong>
          </td>
          <td>
            <span class="badge ${status === 'paid' ? 'badge-success' : 'badge-danger'}" style="text-transform: capitalize;">
              ${escapeHTML(status)}
            </span>
          </td>
          <td style="text-align: center;">
            <button class="btn btn-sm btn-outline-secondary view-receipt-btn" data-id="${p._id}" style="padding: 4px 8px; font-size: 0.8rem;" title="View Receipt">
              🧾 Receipt
            </button>
          </td>
        </tr>
      `;
    }).join('');

    // Attach receipt viewer clicks
    tbody.querySelectorAll('.view-receipt-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        e.preventDefault();
        showReceiptModal(btn.dataset.id);
      });
    });
  }

  /**
   * Render Tab 2: Upcoming Expiries Table
   */
  function renderExpiriesTable() {
    const tbody = container.querySelector('#expiriesTableBody');
    if (!tbody) return;

    const allStudents = cachedExpiries?.students || [];
    let filtered = allStudents;

    // Apply expiry category sub-filter
    if (activeExpiryFilter === '7') {
      filtered = filtered.filter(s => s.expiryCategory === 'next7Days');
    } else if (activeExpiryFilter === '15') {
      filtered = filtered.filter(s => s.expiryCategory === 'next15Days');
    } else if (activeExpiryFilter === '30') {
      filtered = filtered.filter(s => s.expiryCategory === 'next30Days');
    } else if (activeExpiryFilter === 'expired') {
      filtered = filtered.filter(s => s.expiryCategory === 'expired');
    }

    // Apply search filter
    if (currentSearchQuery) {
      filtered = filtered.filter(s => {
        const name = s.name || '';
        const id = s.studentId || '';
        const phone = s.phone || '';
        const plan = s.plan?.name || '';
        return name.toLowerCase().includes(currentSearchQuery) ||
          id.toLowerCase().includes(currentSearchQuery) ||
          phone.toLowerCase().includes(currentSearchQuery) ||
          plan.toLowerCase().includes(currentSearchQuery);
      });
    }

    if (filtered.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" class="text-center p-4 text-muted">
            <div style="font-size: 1.2rem; margin-bottom: 4px;">🎉</div>
            No students matching the selected expiry criteria.
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = filtered.map(s => {
      const days = s.daysRemaining;
      let badgeLabel = '';
      let badgeClass = 'badge-info';

      if (days < 0) {
        badgeLabel = `Expired ${Math.abs(days)}d ago`;
        badgeClass = 'badge-danger';
      } else if (days === 0) {
        badgeLabel = 'Expires Today';
        badgeClass = 'badge-danger';
      } else if (days === 1) {
        badgeLabel = '1 day remaining';
        badgeClass = 'badge-danger';
      } else if (days <= 7) {
        badgeLabel = `${days} days remaining`;
        badgeClass = 'badge-danger';
      } else if (days <= 15) {
        badgeLabel = `${days} days remaining`;
        badgeClass = 'badge-warning';
      } else {
        badgeLabel = `${days} days remaining`;
        badgeClass = 'badge-info';
      }

      const planName = s.plan?.name || 'Standard Plan';
      const planPrice = s.plan?.price ? `₹${s.plan.price}` : '-';
      const seatNum = s.seat?.seatNumber ? `Seat #${s.seat.seatNumber}` : 'Unassigned';

      return `
        <tr>
          <td>
            <div style="font-weight: 600; color: var(--color-text-primary);">${escapeHTML(s.name)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${escapeHTML(s.studentId || '')}</div>
          </td>
          <td>
            <div style="color: var(--color-text-primary); font-size: 0.88rem;">${escapeHTML(s.phone || '-')}</div>
            ${s.email ? `<div class="small text-muted" style="font-size: 0.75rem;">${escapeHTML(s.email)}</div>` : ''}
          </td>
          <td>
            <div style="font-weight: 500;">${escapeHTML(planName)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${planPrice}</div>
          </td>
          <td>
            <span class="badge badge-ghost">${escapeHTML(seatNum)}</span>
          </td>
          <td style="font-weight: 500; color: var(--color-text-primary);">
            ${formatDate(s.expiryDate)}
          </td>
          <td>
            <span class="badge ${badgeClass}" style="font-weight: 600;">
              ${escapeHTML(badgeLabel)}
            </span>
          </td>
          <td style="text-align: center;">
            <button class="btn btn-sm btn-success btn-collect-fee-action" data-studentid="${s._id}" data-name="${escapeHTML(s.name)}" data-plan="${s.plan?._id || ''}" style="padding: 4px 10px; font-size: 0.8rem; display: inline-flex; align-items: center; gap: 4px;">
              <span>💰</span> Collect Fee
            </button>
          </td>
        </tr>
      `;
    }).join('');

    // Attach Collect Fee buttons
    tbody.querySelectorAll('.btn-collect-fee-action').forEach(btn => {
      btn.addEventListener('click', () => {
        openCollectFeeModal(btn.dataset.studentid, btn.dataset.name, btn.dataset.plan);
      });
    });
  }

  /**
   * Render Tab 3: Attendance Analytics Table
   */
  function renderAttendanceTable() {
    const tbody = container.querySelector('#attendanceTableBody');
    const tabCount = container.querySelector('#tabCountAttendance');
    if (!tbody) return;

    const studentStats = cachedAttendance?.studentAnalytics || [];
    let filtered = studentStats;

    if (currentSearchQuery) {
      filtered = filtered.filter(item => {
        const name = item.student?.name || '';
        const id = item.student?.studentId || '';
        const phone = item.student?.phone || '';
        return name.toLowerCase().includes(currentSearchQuery) ||
          id.toLowerCase().includes(currentSearchQuery) ||
          phone.toLowerCase().includes(currentSearchQuery);
      });
    }

    if (tabCount) tabCount.textContent = studentStats.length;

    if (filtered.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" class="text-center p-4 text-muted">
            <div style="font-size: 1.2rem; margin-bottom: 4px;">⏱️</div>
            No student attendance logs found in this date range.
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = filtered.map((item, index) => {
      const studentName = item.student?.name || 'Unknown Student';
      const studentId = item.student?.studentId || '';
      const studentPhone = item.student?.phone || '-';
      const daysPresent = item.daysPresent || 0;
      const totalHours = item.totalHours || 0;
      const avgHours = item.avgHours || 0;
      const rate = item.attendanceRate || 0;

      let rateColor = 'var(--color-success)';
      if (rate < 50) rateColor = 'var(--color-danger)';
      else if (rate < 75) rateColor = 'var(--color-warning)';

      return `
        <tr>
          <td style="font-weight: 700; color: var(--color-text-muted); width: 50px;">
            #${index + 1}
          </td>
          <td>
            <div style="font-weight: 600; color: var(--color-text-primary);">${escapeHTML(studentName)}</div>
            <div class="small text-muted" style="font-size: 0.78rem;">${escapeHTML(studentId)}</div>
          </td>
          <td>
            <div style="color: var(--color-text-secondary); font-size: 0.85rem;">${escapeHTML(studentPhone)}</div>
          </td>
          <td style="text-align: center;">
            <strong style="color: var(--color-primary); font-size: 1rem;">${daysPresent}</strong>
            <span class="text-muted small"> days</span>
          </td>
          <td style="text-align: center;">
            <strong style="color: var(--color-text-primary);">${totalHours}</strong>
            <span class="text-muted small"> hrs</span>
          </td>
          <td style="text-align: center;">
            <span class="badge badge-ghost" style="font-size: 0.85rem;">${avgHours} hrs/day</span>
          </td>
          <td style="min-width: 140px;">
            <div class="d-flex align-items-center gap-2">
              <div class="progress" style="height: 6px; flex: 1;">
                <div class="progress-bar" style="width: ${rate}%; background: ${rateColor};"></div>
              </div>
              <span style="font-weight: 600; font-size: 0.8rem; color: ${rateColor}; min-width: 35px; text-align: right;">${rate}%</span>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  /**
   * Helper to download CSV or JSON directly
   */
  async function downloadReport(type, format = 'csv') {
    try {
      Toast.info(`Generating ${type.toUpperCase()} ${format.toUpperCase()} export...`);
      const token = localStorage.getItem('sl_token');
      const { startDate, endDate } = currentRange;

      const params = new URLSearchParams();
      params.set('format', format);
      if (startDate) params.set('startDate', startDate);
      if (endDate) params.set('endDate', endDate);

      const url = `/api/reports/export/${type}?${params.toString()}`;
      const response = await fetch(url, {
        headers: {
          ...(token ? { 'Authorization': `Bearer ${token}` } : {})
        }
      });

      if (!response.ok) {
        throw new Error(`Failed to download report (${response.status})`);
      }

      if (format === 'json') {
        const json = await response.json();
        const blob = new Blob([JSON.stringify(json, null, 2)], { type: 'application/json' });
        const downloadUrl = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = downloadUrl;
        a.download = `${type}-report-${new Date().toISOString().split('T')[0]}.json`;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(downloadUrl);
      } else {
        const blob = await response.blob();
        const downloadUrl = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = downloadUrl;
        const disposition = response.headers.get('Content-Disposition');
        let filename = `${type}-report-${new Date().toISOString().split('T')[0]}.csv`;
        if (disposition && disposition.includes('filename=')) {
          const match = disposition.match(/filename="?([^"]+)"?/);
          if (match && match[1]) filename = match[1];
        }
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        a.remove();
        URL.revokeObjectURL(downloadUrl);
      }

      Toast.success(`${type.toUpperCase()} report exported successfully!`);
    } catch (err) {
      console.error('Download error:', err);
      Toast.error(`Export failed: ${err.message || 'Error occurred'}`);
    }
  }

  /**
   * Helper to download Tally Prime XML import file directly
   */
  async function downloadTallyXml() {
    try {
      Toast.info('Generating Tally Prime XML import file...');
      const token = localStorage.getItem('sl_token');
      const { startDate, endDate } = currentRange;

      const params = new URLSearchParams();
      if (startDate) params.set('startDate', startDate);
      if (endDate) params.set('endDate', endDate);

      const url = `/api/reports/tally-xml?${params.toString()}`;
      const response = await fetch(url, {
        headers: {
          ...(token ? { 'Authorization': `Bearer ${token}` } : {})
        }
      });

      if (!response.ok) {
        throw new Error(`Failed to download Tally XML (${response.status})`);
      }

      const blob = await response.blob();
      const downloadUrl = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = downloadUrl;
      const disposition = response.headers.get('Content-Disposition');
      let filename = `tally-import-${new Date().toISOString().split('T')[0]}.xml`;
      if (disposition && disposition.includes('filename=')) {
        const match = disposition.match(/filename="?([^"]+)"?/);
        if (match && match[1]) filename = match[1];
      }
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(downloadUrl);

      Toast.success('Tally Prime XML import file downloaded successfully!');
    } catch (err) {
      console.error('Tally XML download error:', err);
      Toast.error(`Tally export failed: ${err.message || 'Error occurred'}`);
    }
  }

  /**
   * Helper to download GST Sales Summary CSV directly
   */
  async function downloadGstReport() {
    try {
      Toast.info('Generating GST Sales Summary Report (CSV)...');
      const token = localStorage.getItem('sl_token');
      const { startDate, endDate } = currentRange;

      const params = new URLSearchParams();
      params.set('format', 'csv');
      if (startDate) params.set('startDate', startDate);
      if (endDate) params.set('endDate', endDate);

      const url = `/api/reports/gst-report?${params.toString()}`;
      const response = await fetch(url, {
        headers: {
          ...(token ? { 'Authorization': `Bearer ${token}` } : {})
        }
      });

      if (!response.ok) {
        throw new Error(`Failed to download GST Report (${response.status})`);
      }

      const blob = await response.blob();
      const downloadUrl = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = downloadUrl;
      const disposition = response.headers.get('Content-Disposition');
      let filename = `gst-b2c-sales-summary-${new Date().toISOString().split('T')[0]}.csv`;
      if (disposition && disposition.includes('filename=')) {
        const match = disposition.match(/filename="?([^"]+)"?/);
        if (match && match[1]) filename = match[1];
      }
      a.download = filename;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(downloadUrl);

      Toast.success('GST Sales Summary Report downloaded successfully!');
    } catch (err) {
      console.error('GST Report download error:', err);
      Toast.error(`GST export failed: ${err.message || 'Error occurred'}`);
    }
  }

  /**
   * Show Printable Receipt Modal
   */
  async function showReceiptModal(paymentId) {
    try {
      const res = await api.get(`/api/payments/${paymentId}/receipt`);
      if (!res.success || !res.data) {
        Toast.error('Receipt not found');
        return;
      }

      const r = res.data;
      const receiptContent = `
        <div id="printableReceiptArea" style="padding: 10px; font-family: var(--font-family);">
          <div style="border: 2px dashed var(--color-border); border-radius: var(--radius-md); padding: 20px; background: var(--color-surface);">
            
            <!-- Receipt Header -->
            <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 1px solid var(--color-divider); padding-bottom: 16px; margin-bottom: 16px;">
              <div>
                <h3 style="margin: 0; font-size: 1.3rem; font-weight: 700; color: var(--color-primary);">${escapeHTML(r.businessName || 'Reading Room & Study Library')}</h3>
                <div class="text-muted small" style="margin-top: 4px;">Official Payment Receipt</div>
              </div>
              <div style="text-align: right;">
                <div style="font-family: monospace; font-weight: 700; font-size: 1rem; color: var(--color-text-primary);">${escapeHTML(r.receiptNumber || 'N/A')}</div>
                <div class="text-muted small">${formatDate(r.date)}</div>
              </div>
            </div>

            <!-- Student Info -->
            <div style="background: var(--color-bg-secondary); border-radius: var(--radius-sm); padding: 12px; margin-bottom: 16px;">
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 8px;">
                <div>
                  <span class="text-muted small">Student Name:</span>
                  <div style="font-weight: 600; color: var(--color-text-primary);">${escapeHTML(r.student?.name || 'Unknown')}</div>
                </div>
                <div>
                  <span class="text-muted small">Student ID:</span>
                  <div style="font-weight: 600; color: var(--color-text-primary);">${escapeHTML(r.student?.studentId || '-')}</div>
                </div>
                <div>
                  <span class="text-muted small">Phone:</span>
                  <div style="color: var(--color-text-primary);">${escapeHTML(r.student?.phone || '-')}</div>
                </div>
                <div>
                  <span class="text-muted small">Plan Enrolled:</span>
                  <div style="color: var(--color-text-primary); font-weight: 500;">${escapeHTML(r.plan?.name || 'Custom Plan')}</div>
                </div>
              </div>
            </div>

            <!-- Financial Breakdown Table -->
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 16px; font-size: 0.9rem;">
              <thead>
                <tr style="border-bottom: 1px solid var(--color-divider); color: var(--color-text-secondary); text-align: left;">
                  <th style="padding: 8px 0;">Description</th>
                  <th style="padding: 8px 0; text-align: right;">Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td style="padding: 8px 0;">Base Membership Fee</td>
                  <td style="padding: 8px 0; text-align: right;">${formatCurrency(r.paymentDetails?.amount)}</td>
                </tr>
                ${r.paymentDetails?.discount > 0 ? `
                <tr style="color: var(--color-success);">
                  <td style="padding: 4px 0;">Discount Applied</td>
                  <td style="padding: 4px 0; text-align: right;">- ${formatCurrency(r.paymentDetails.discount)}</td>
                </tr>` : ''}
                ${r.paymentDetails?.lateFee > 0 ? `
                <tr style="color: var(--color-danger);">
                  <td style="padding: 4px 0;">Late Fee</td>
                  <td style="padding: 4px 0; text-align: right;">+ ${formatCurrency(r.paymentDetails.lateFee)}</td>
                </tr>` : ''}
                <tr style="border-top: 2px solid var(--color-divider); font-weight: 700; font-size: 1.1rem; color: var(--color-text-primary);">
                  <td style="padding: 12px 0;">Total Paid</td>
                  <td style="padding: 12px 0; text-align: right; color: var(--color-success);">${formatCurrency(r.paymentDetails?.finalAmount)}</td>
                </tr>
              </tbody>
            </table>

            <!-- Payment Metadata -->
            <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.8rem; color: var(--color-text-secondary); border-top: 1px solid var(--color-divider); padding-top: 12px;">
              <div>
                <span>Payment Method: </span>
                <strong style="color: var(--color-text-primary); text-transform: uppercase;">${escapeHTML(r.paymentDetails?.method || 'CASH')}</strong>
                ${r.paymentDetails?.transactionId ? `<span style="margin-left: 8px;">(Txn: ${escapeHTML(r.paymentDetails.transactionId)})</span>` : ''}
              </div>
              <div>
                <span>Collected By: </span>
                <strong style="color: var(--color-text-primary);">${escapeHTML(r.collectedBy || 'Admin')}</strong>
              </div>
            </div>

          </div>
        </div>
      `;

      Modal.show({
        title: 'Fee Payment Receipt',
        content: receiptContent,
        size: 'md',
        actions: `
          <button class="btn btn-secondary" onclick="document.getElementById('modal-container').close()">Close</button>
          <button class="btn btn-primary d-flex align-items-center gap-2" id="btnPrintReceiptModal">
            <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2"><polyline points="6 9 6 2 18 2 18 9"></polyline><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"></path><rect x="6" y="14" width="12" height="8"></rect></svg>
            Print Receipt
          </button>
        `
      });

      const btnPrint = document.getElementById('btnPrintReceiptModal');
      if (btnPrint) {
        btnPrint.onclick = () => {
          window.print();
        };
      }

    } catch (err) {
      console.error('Error fetching receipt:', err);
      Toast.error('Failed to load receipt details');
    }
  }

  /**
   * Modal to collect fee payment for expiring / expired student
   */
  async function openCollectFeeModal(studentId, studentName, currentPlanId) {
    try {
      // Fetch available plans
      const plansRes = await api.get('/api/plans');
      const plans = (plansRes.success && plansRes.data) ? plansRes.data : [];

      let planOptions = '<option value="">-- Select Subscription Plan --</option>';
      let defaultPrice = 0;

      plans.forEach(p => {
        const isSelected = p._id === currentPlanId;
        if (isSelected) defaultPrice = p.price;
        planOptions += `<option value="${p._id}" data-price="${p.price}" ${isSelected ? 'selected' : ''}>${escapeHTML(p.name)} - ₹${p.price} (${p.duration} ${p.durationType})</option>`;
      });

      const formContent = `
        <form id="collectFeeForm" style="display: flex; flex-direction: column; gap: var(--space-4);">
          
          <div class="form-group mb-0">
            <label class="form-label">Student</label>
            <input type="text" class="form-control" value="${escapeHTML(studentName)}" disabled style="background: var(--color-bg-secondary); font-weight: 600;" />
          </div>

          <div class="form-group mb-0">
            <label class="form-label">Membership Plan *</label>
            <select id="modalPlanSelect" class="form-select form-control" required>
              ${planOptions}
            </select>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: var(--space-3);">
            <div class="form-group mb-0">
              <label class="form-label">Amount (₹) *</label>
              <input type="number" id="modalAmount" class="form-control" value="${defaultPrice}" required min="0" />
            </div>

            <div class="form-group mb-0">
              <label class="form-label">Discount (₹)</label>
              <input type="number" id="modalDiscount" class="form-control" value="0" min="0" />
            </div>
          </div>

          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: var(--space-3);">
            <div class="form-group mb-0">
              <label class="form-label">Payment Method</label>
              <select id="modalMethod" class="form-select form-control">
                <option value="upi" selected>UPI (GPay / PhonePe / Paytm)</option>
                <option value="cash">Cash</option>
                <option value="bank_transfer">Bank Transfer / IMPS</option>
                <option value="card">Debit / Credit Card</option>
                <option value="other">Other</option>
              </select>
            </div>

            <div class="form-group mb-0">
              <label class="form-label">Transaction Reference #</label>
              <input type="text" id="modalTxnId" class="form-control" placeholder="UPI Ref / Txn ID" />
            </div>
          </div>

          <div class="form-group mb-0">
            <label class="form-label">Notes (Optional)</label>
            <textarea id="modalNotes" class="form-control" rows="2" placeholder="e.g. Paid in full for next month renewal"></textarea>
          </div>

          <div style="background: var(--color-primary-bg); padding: 12px; border-radius: var(--radius-md); display: flex; justify-content: space-between; align-items: center;">
            <span style="font-weight: 500; color: var(--color-primary);">Final Payable Amount:</span>
            <strong id="modalFinalDisplay" style="font-size: 1.2rem; color: var(--color-primary);">${formatCurrency(defaultPrice)}</strong>
          </div>

        </form>
      `;

      const modal = Modal.show({
        title: `Collect Fee: ${studentName}`,
        content: formContent,
        size: 'md',
        actions: `
          <button class="btn btn-secondary" onclick="document.getElementById('modal-container').close()">Cancel</button>
          <button class="btn btn-primary d-flex align-items-center gap-2" id="btnSubmitCollectFee">
            <span>💰</span> Confirm Payment & Renew
          </button>
        `
      });

      // Price auto-calculation
      const planSelect = modal.querySelector('#modalPlanSelect');
      const amountInput = modal.querySelector('#modalAmount');
      const discountInput = modal.querySelector('#modalDiscount');
      const finalDisplay = modal.querySelector('#modalFinalDisplay');

      function updatePayable() {
        const amt = parseFloat(amountInput.value) || 0;
        const disc = parseFloat(discountInput.value) || 0;
        const finalVal = Math.max(0, amt - disc);
        if (finalDisplay) finalDisplay.textContent = formatCurrency(finalVal);
      }

      if (planSelect) {
        planSelect.addEventListener('change', (e) => {
          const selectedOption = e.target.options[e.target.selectedIndex];
          const price = selectedOption.dataset.price;
          if (price && amountInput) {
            amountInput.value = price;
            updatePayable();
          }
        });
      }

      if (amountInput) amountInput.addEventListener('input', updatePayable);
      if (discountInput) discountInput.addEventListener('input', updatePayable);

      // Submit payment
      const submitBtn = modal.querySelector('#btnSubmitCollectFee');
      if (submitBtn) {
        submitBtn.onclick = async () => {
          const planId = planSelect?.value;
          const amount = parseFloat(amountInput?.value);
          const discount = parseFloat(discountInput?.value) || 0;
          const method = modal.querySelector('#modalMethod')?.value || 'upi';
          const txnId = modal.querySelector('#modalTxnId')?.value || '';
          const notes = modal.querySelector('#modalNotes')?.value || '';

          if (!planId) {
            Toast.error('Please select a membership plan');
            return;
          }
          if (isNaN(amount) || amount <= 0) {
            Toast.error('Please enter a valid amount');
            return;
          }

          Loading.button(submitBtn, true);

          try {
            const payRes = await api.post('/api/payments', {
              student: studentId,
              plan: planId,
              amount,
              discount,
              lateFee: 0,
              paymentMethod: method,
              transactionId: txnId,
              notes,
              status: 'paid'
            });

            if (payRes.success) {
              Modal.close();
              Toast.success('Fee collected and subscription renewed successfully!');
              await loadAllData();
            } else {
              Toast.error(payRes.message || 'Payment submission failed');
            }
          } catch (err) {
            console.error('Payment error:', err);
            Toast.error(err.message || 'Error processing payment');
          } finally {
            Loading.button(submitBtn, false);
          }
        };
      }

    } catch (err) {
      console.error('Error opening collect fee modal:', err);
      Toast.error('Failed to open fee collection');
    }
  }
}
