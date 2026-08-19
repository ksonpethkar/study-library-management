import { App } from '../app.js';
import { t } from '../i18n.js';
import { escapeHTML, Toast } from '../ui.js';
import api from '../api.js';

const formatCurrency = (amount) => {
  return new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
  }).format(amount || 0);
};

export async function render() {
  const content = document.getElementById('page-content');
  if (!content) return;

  const user = App.getUser() || { name: 'Admin' };

  content.innerHTML = `
    <div class="page-header flex-between mb-4">
      <div>
        <h1 style="margin: 0; font-size: 1.6rem; font-weight: 700;">${t('nav.dashboard', 'Dashboard')}</h1>
        <p class="text-muted small mb-0" style="margin-top: 4px;">Welcome back, ${escapeHTML(user.name)}! Here is your study library live overview.</p>
      </div>
      <div class="d-flex gap-2">
        <a href="/kiosk" target="_blank" class="btn btn-outline" style="border-color: #6366f1; color: #818cf8; font-weight: 600;">
          📲 Launch Gate Kiosk
        </a>
      </div>
    </div>
    
    <!-- 4 Primary KPI Cards -->
    <!-- 4 Primary KPI Cards -->
    <div class="stats-grid mb-4" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 1rem;">
      <div class="stat-card card" style="border-left: 4px solid var(--color-primary, #6c5ce7);">
        <div class="stat-card-body">
          <div class="stat-card-info">
            <div class="stat-card-title">${t('dashboard.totalStudents', 'Total Students')}</div>
            <div class="stat-card-value" id="dash-students">0</div>
          </div>
          <div class="stat-card-icon" style="background: var(--color-primary-bg, rgba(108, 92, 231, 0.15)); color: var(--color-primary, #6c5ce7);">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>
          </div>
        </div>
      </div>

      <div class="stat-card card" style="border-left: 4px solid var(--color-success, #00b894);">
        <div class="stat-card-body">
          <div class="stat-card-info">
            <div class="stat-card-title">${t('dashboard.occupiedSeats', 'Seats Occupied')}</div>
            <div class="stat-card-value" id="dash-seats" style="color: var(--color-success, #00b894);">0 / 0</div>
          </div>
          <div class="stat-card-icon" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success, #00b894);">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M5 16V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v12"></path><path d="M3 16h18"></path><path d="M5 16v4"></path><path d="M19 16v4"></path></svg>
          </div>
        </div>
      </div>

      <div class="stat-card card" style="border-left: 4px solid var(--color-info, #0984e3);">
        <div class="stat-card-body">
          <div class="stat-card-info">
            <div class="stat-card-title">${t('dashboard.monthlyRevenue', 'Monthly Revenue')}</div>
            <div class="stat-card-value" id="dash-revenue" style="color: var(--color-info, #0984e3);">₹0</div>
          </div>
          <div class="stat-card-icon" style="background: rgba(9, 132, 227, 0.15); color: var(--color-info, #0984e3);">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>
          </div>
        </div>
      </div>

      <div class="stat-card card" style="border-left: 4px solid var(--color-danger, #d63031);">
        <div class="stat-card-body">
          <div class="stat-card-info">
            <div class="stat-card-title">${t('dashboard.pendingDues', 'Pending Dues')}</div>
            <div class="stat-card-value" id="dash-dues" style="color: var(--color-danger, #d63031);">₹0</div>
          </div>
          <div class="stat-card-icon" style="background: rgba(214, 48, 49, 0.15); color: var(--color-danger, #d63031);">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="22" height="22"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>
          </div>
        </div>
      </div>
    </div>

    <!-- Quick Actions Bar -->
    <div class="card mb-4">
      <div class="card-header">
        <h5 style="margin: 0; font-size: 1.05rem; font-weight: 600;">⚡ Quick Actions</h5>
      </div>
      <div class="card-body" style="display: flex; gap: var(--space-3); flex-wrap: wrap;">
        <a href="#/students" class="btn btn-primary d-flex align-items-center gap-2">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
          + Add New Student
        </a>
        <a href="#/payments" class="btn btn-success d-flex align-items-center gap-2">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>
          💰 Collect Fee Payment
        </a>
        <a href="#/seats" class="btn btn-outline-secondary d-flex align-items-center gap-2">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M5 16V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v12"></path><path d="M3 16h18"></path></svg>
          💺 View Seat Matrix
        </a>
        <a href="#/lockers" class="btn btn-outline-secondary d-flex align-items-center gap-2">
          🔐 Manage Lockers
        </a>
        <a href="#/attendance" class="btn btn-outline-secondary d-flex align-items-center gap-2">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="18" height="18"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle></svg>
          ⏱️ Daily Attendance Log
        </a>
      </div>
    </div>

    <!-- Live Attendance Overview & Expiring Soon Row -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(320px, 1fr)); gap: 1.5rem; margin-bottom: 1.5rem;">
      
      <!-- Live Overview & Hourly Activity -->
      <div class="card">
        <div class="card-header flex-between">
          <h5 style="margin: 0; font-size: 1.05rem; font-weight: 600;">🔔 Real-Time Attendance Pulse</h5>
          <span class="badge badge-success" style="animation: pulse 2s infinite;">● Live</span>
        </div>
        <div class="card-body">
          <div class="d-flex flex-column gap-3 mb-4">
            <div class="p-3" style="background: var(--color-bg-secondary, rgba(255,255,255,0.04)); border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
              <span>Currently Studying Inside:</span>
              <strong id="dash-present-today" style="font-size: 1.2rem; color: var(--color-primary);">0 Students</strong>
            </div>
            <div class="p-3" style="background: var(--color-bg-secondary, rgba(255,255,255,0.04)); border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
              <span>Available Desks:</span>
              <strong id="dash-available-seats" class="text-success">0 Available</strong>
            </div>
            <div class="p-3" style="background: var(--color-bg-secondary, rgba(255,255,255,0.04)); border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
              <span>Active Subscriptions:</span>
              <strong id="dash-active-subs" class="text-info">0</strong>
            </div>
          </div>
          <canvas id="dashboard-chart" style="width: 100%; height: 180px;"></canvas>
        </div>
      </div>

      <!-- Expiring Soon (Next 7 Days) Widget with WhatsApp Trigger -->
      <div class="card">
        <div class="card-header flex-between">
          <h5 style="margin: 0; font-size: 1.05rem; font-weight: 600;">⏰ Memberships Expiring in 7 Days</h5>
          <a href="#/students" class="text-xs text-primary" style="text-decoration: none;">View All</a>
        </div>
        <div class="card-body p-0" id="dash-expiring-container" style="max-height: 380px; overflow-y: auto;">
          <div class="p-4 text-center text-muted">Checking upcoming expiries...</div>
        </div>
      </div>
    </div>
  `;

  // Fetch live stats & expiring students from backend
  try {
    const [stuRes, seatRes, payRes, attRes, expiringRes] = await Promise.allSettled([
      api.get('/api/students/stats'),
      api.get('/api/seats/stats'),
      api.get('/api/payments/stats'),
      api.get('/api/attendance/today'),
      api.get('/api/reports/expiries?days=7')
    ]);

    if (stuRes.status === 'fulfilled' && stuRes.value?.success) {
      const s = stuRes.value.data;
      const el = document.getElementById('dash-students');
      const elActive = document.getElementById('dash-active-subs');
      if (el) el.textContent = s.total || 0;
      if (elActive) elActive.textContent = s.active || 0;
    }

    if (seatRes.status === 'fulfilled' && seatRes.value?.success) {
      const s = seatRes.value.data;
      const el = document.getElementById('dash-seats');
      const elAvail = document.getElementById('dash-available-seats');
      if (el) el.textContent = `${s.occupied || 0} / ${s.total || 0}`;
      if (elAvail) elAvail.textContent = `${s.available || 0} Available`;
    }

    if (payRes.status === 'fulfilled' && payRes.value?.success) {
      const p = payRes.value.data;
      const elRev = document.getElementById('dash-revenue');
      const elDues = document.getElementById('dash-dues');
      if (elRev) elRev.textContent = formatCurrency(p.monthRevenue);
      if (elDues) elDues.textContent = formatCurrency(p.totalPending);
    }

    if (attRes.status === 'fulfilled' && attRes.value?.success) {
      const a = attRes.value.data;
      const elPres = document.getElementById('dash-present-today');
      if (elPres) elPres.textContent = `${a.stats?.totalPresent || 0} Students`;
    }

    // Render Expiring Soon list
    const expiringContainer = document.getElementById('dash-expiring-container');
    if (expiringContainer) {
      const expiringList = (expiringRes.status === 'fulfilled' && expiringRes.value?.data) ? expiringRes.value.data : [];
      if (expiringList.length === 0) {
        expiringContainer.innerHTML = `
          <div class="p-4 text-center text-muted">
            <div style="font-size: 28px; margin-bottom: 4px;">🎉</div>
            <p class="small mb-0">No memberships expiring in the next 7 days!</p>
          </div>
        `;
      } else {
        expiringContainer.innerHTML = `
          <div class="d-flex flex-column divide-y">
            ${expiringList.slice(0, 5).map(s => {
              const expDateObj = s.expiryDate ? new Date(s.expiryDate) : null;
              const isValidExp = expDateObj && !isNaN(expDateObj.getTime());
              const daysLeft = s.daysUntilExpiry ?? (isValidExp ? Math.ceil((expDateObj - new Date()) / (1000 * 60 * 60 * 24)) : 0);
              const expDateStr = isValidExp ? expDateObj.toLocaleDateString('en-IN') : 'N/A';
              const phone = (s.phone || '').replace(/[^0-9]/g, '');
              const waText = encodeURIComponent(`Hi ${s.name}, friendly reminder from Study Library: Your desk membership expires on ${expDateStr}. Please renew to retain your seat!`);
              const waLink = phone ? `https://api.whatsapp.com/send?phone=${phone.length === 10 ? '91' + phone : phone}&text=${waText}` : '#';

              return `
                <div class="p-3 d-flex justify-content-between align-items-center" style="border-bottom: 1px solid var(--color-divider);">
                  <div>
                    <div style="font-weight: 600; font-size: 14px;">${escapeHTML(s.name)}</div>
                    <div class="text-xs text-muted">Seat: ${escapeHTML(s.seatNumber || 'N/A')} | Exp: ${expDateStr}</div>
                  </div>
                  <div class="d-flex align-items-center gap-2">
                    <span class="badge ${daysLeft <= 2 ? 'badge-danger' : 'badge-warning'}" style="font-size: 11px;">
                      ${daysLeft <= 0 ? 'Expires Today' : `${daysLeft}d left`}
                    </span>
                    ${phone ? `
                      <a href="${waLink}" target="_blank" class="btn btn-sm btn-success" style="padding: 4px 8px; font-size: 12px; background: #25D366; border-color: #25D366;" title="Send WhatsApp Reminder">
                        📲
                      </a>
                    ` : ''}
                  </div>
                </div>
              `;
            }).join('')}
          </div>
        `;
      }
    }
  } catch (err) {
    console.error('Error loading dashboard stats:', err);
  }

  // Draw attendance chart
  import('../charts.js').then(({ ChartEngine }) => {
    ChartEngine.barChart('dashboard-chart', {
      labels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      data: [18, 24, 21, 27, 25, 32, 29],
      title: 'Weekly Attendance',
      color: '#6c5ce7'
    });
  }).catch(() => {});
}
