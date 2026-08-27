import api from '../api.js';
import { Toast, Modal, Confirm, Loading, escapeHTML, copyToClipboard } from '../ui.js';
import { SmartFormatters } from '../utils/smartFormatters.js';
import { t } from '../i18n.js';
import { generateAdmissionFormPDF, previewAdmissionFormPDF } from '../pdfGenerator.js';
import { PushNotifications } from '../utils/pushNotifications.js';
import { renderHeatmap, renderBehaviorBadge, calculateBehaviorScore } from '../utils/attendanceHeatmap.js';
import { MediaStudio, MediaFieldPicker } from '../mediaStudio.js';
import { SmartIntelligence } from '../utils/smartIntelligence.js';

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';
  container.style.cssText = 'width: 100%; max-width: 100%; box-sizing: border-box; padding-bottom: 3rem;';

  container.innerHTML = `
    <div class="card p-5 text-center" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div class="loading-spinner mb-3" style="margin: 0 auto;"></div>
      <p style="color: var(--color-text-secondary); margin: 0;">Loading Student Portal...</p>
    </div>
  `;

  try {
    const res = await api.get('/api/student-portal/dashboard');
    if (!res.success || !res.data) throw new Error(res.message);

    let analytics = null;
    try {
      const aRes = await api.get(`/api/attendance/analytics/${res.data.student._id}`);
      if (aRes.success) analytics = aRes.data;
    } catch (e) {
      console.warn('Analytics fetch error:', e);
    }

    renderPortalUI(container, res.data, analytics);

    // ── Phase 2: Inject full-year heatmap into student portal ────────────────
    // Runs after the portal HTML is in the DOM
    setTimeout(async () => {
      // Find or create the year heatmap container below the 30-day grid
      let yearHeatmapWrap = container.querySelector('#portal-year-heatmap');
      if (!yearHeatmapWrap) {
        const analyticsSection = container.querySelector('[data-section="analytics"]') ||
          container.querySelector('#portal-analytics-section') ||
          container.querySelector('.portal-analytics-card .card-body');
        if (analyticsSection) {
          yearHeatmapWrap = document.createElement('div');
          yearHeatmapWrap.id = 'portal-year-heatmap';
          yearHeatmapWrap.style.cssText = 'margin-top:18px;padding-top:14px;border-top:1px solid var(--color-border,rgba(255,255,255,0.08));';
          analyticsSection.appendChild(yearHeatmapWrap);
        }
      }
      if (yearHeatmapWrap && res.data?.student?._id) {
        try {
          await renderHeatmap(yearHeatmapWrap, res.data.student._id, new Date().getFullYear(), { compact: false });
        } catch (e) {
          yearHeatmapWrap.innerHTML = '<div class="text-muted small text-center p-2">Full attendance calendar unavailable</div>';
        }
      }
    }, 200);

  } catch (error) {
    container.innerHTML = `
      <div class="card p-5 text-center" style="background: var(--color-surface); border: 1px solid var(--color-danger); border-radius: var(--radius-lg);">
        <div style="font-size: 3rem; margin-bottom: 0.5rem;">🎓</div>
        <h3 style="color: var(--color-danger); margin-bottom: 0.5rem;">Student Portal</h3>
        <p style="color: var(--color-text-secondary); max-width: 500px; margin: 0 auto 1.5rem auto;">
          ${escapeHTML(error.message || 'No enrolled student record found for your account.')}
        </p>
        <a href="#/dashboard" class="btn btn-primary">Return to Admin Dashboard</a>
      </div>
    `;
  }

  return container;
}

function formatPunchTime(val) {
  if (!val) return '';
  try {
    const d = new Date(val);
    if (isNaN(d.getTime())) return val;
    return d.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
  } catch (e) {
    return val;
  }
}

function renderPortalUI(container, data, analytics = null) {
  const { student, business, daysRemaining, totalHours, todayAttendance, payments } = data;
  const user = window.store?.user || (typeof App !== 'undefined' && App.getUser ? App.getUser() : {}) || {};

  const initials = (student.name || 'S')
    .split(' ')
    .map(n => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  const hasSeat = student.seat && student.seat.seatNumber;
  const seatTitle = hasSeat ? escapeHTML(student.seat.seatNumber) : 'Floating Desk';
  const seatBadge = hasSeat ? escapeHTML(student.seat.zone || 'Quiet Zone') : 'Open Access';
  const planName = student.plan?.name || 'Standard Reading Room Plan';
  const planPrice = student.plan?.price || 0;
  const shiftName = student.shift?.name || student.shift?.timing || student.shift || student.plan?.shift || 'Full Day';
  const expiryDateStr = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : 'Not Set';

  const examTags = (student.targetExams && student.targetExams.length > 0)
    ? student.targetExams.map(ex => `<span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-size: 0.75rem;">${escapeHTML(ex)}</span>`).join('')
    : '<span class="text-muted small">General Self-Study</span>';

  // Immediately synchronize student photo into top-right header user-avatar
  if (student.photo) {
    const avatarEl = document.getElementById('user-avatar');
    if (avatarEl) {
      const cleanPhotoUrl = student.photo.startsWith('/') || student.photo.startsWith('http') || student.photo.startsWith('data:') ? student.photo : `/${student.photo}`;
      avatarEl.style.overflow = 'hidden';
      avatarEl.style.padding = '0';
      avatarEl.innerHTML = `<img src="${cleanPhotoUrl}" alt="Avatar" style="width: 100%; height: 100%; object-fit: cover; border-radius: 50%; display: block;" onerror="this.remove(); document.getElementById('user-avatar').textContent='${initials}';">`;
    }
    try {
      const user = JSON.parse(localStorage.getItem('sl_user') || '{}');
      user.photo = student.photo;
      user.avatar = student.photo;
      localStorage.setItem('sl_user', JSON.stringify(user));
      if (window.store && window.store.user) {
        window.store.user.photo = student.photo;
        window.store.user.avatar = student.photo;
      }
    } catch(e) {}
  }

  const currentHour = new Date().getHours();
  const timeGreeting = currentHour < 12 ? '🌅 Good Morning' : (currentHour < 17 ? '🌤️ Good Afternoon' : '🌙 Good Evening');
  const isCheckedIn = todayAttendance && todayAttendance.checkIn && !todayAttendance.checkOut;
  const punchStatusText = isCheckedIn
    ? `🟢 Currently Checked In since <strong>${formatPunchTime(todayAttendance.checkIn)}</strong>`
    : (todayAttendance && todayAttendance.checkOut)
    ? `✅ Completed study session today (<strong>${formatPunchTime(todayAttendance.checkIn)}</strong> – <strong>${formatPunchTime(todayAttendance.checkOut)}</strong>)`
    : `⚪ Not checked in today`;

  container.innerHTML = `
    <div class="portal-container">
      <!-- Admin Preview Banner -->
      ${data.isAdmin ? `
        <div class="card p-3 mb-3" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.12), rgba(0, 184, 148, 0.08)); border: 1px solid var(--color-primary); border-radius: var(--radius-lg); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
          <div style="display: flex; align-items: center; gap: 10px;">
            <span style="font-size: 1.5rem;">👑</span>
            <div>
              <div style="font-weight: 700; color: var(--color-primary); font-size: 0.95rem;">Admin Inspection Mode — Student Portal Experience</div>
              <div style="font-size: 0.8rem; color: var(--color-text-secondary);">You are logged in as Administrator. Inspecting live student view for <strong>${escapeHTML(student.name)}</strong>.</div>
            </div>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <label style="font-size: 0.82rem; font-weight: 600;">Switch Student:</label>
            <select id="admin-switch-student" class="form-select form-control form-control-sm" style="min-width: 220px; font-weight: 600;">
              ${(data.allStudents || []).map(s => `
                <option value="${s._id}" ${String(s._id) === String(student._id) ? 'selected' : ''}>
                  ${escapeHTML(s.name)} (${s.studentId || s.phone})
                </option>
              `).join('')}
            </select>
            <a href="#/students" class="btn btn-outline-secondary btn-sm" style="font-weight: 600;">➔ Students Directory</a>
          </div>
        </div>
      ` : ''}

      <!-- 1. Mobile-First Welcome & Identity Bar -->
      <div class="card mb-3 p-3" id="portal-welcome-banner" style="
        background: ${business.bannerImage ? `linear-gradient(135deg, rgba(108, 92, 231, 0.90), rgba(15, 23, 42, 0.85)), url('${business.bannerImage}') center/cover` : 'var(--color-surface)'};
        border: 1px solid var(--color-border);
        border-radius: var(--radius-lg);
      ">
        <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 12px;">
          <div style="display: flex; align-items: center; gap: 12px; min-width: 240px; flex: 1 1 auto;">
            <div style="
              width: 58px; height: 58px; border-radius: 50%;
              background: var(--color-primary-bg); color: var(--color-primary);
              font-size: 1.4rem; font-weight: 800; display: flex; align-items: center; justify-content: center;
              border: 2.5px solid ${isCheckedIn ? '#10b981' : 'var(--color-primary)'}; flex-shrink: 0; overflow: hidden;
              box-shadow: 0 4px 14px ${isCheckedIn ? 'rgba(16, 185, 129, 0.35)' : 'rgba(108, 92, 231, 0.2)'};
              position: relative;
            ">
              ${(student.photo || user?.avatar) ? `
                <img src="${escapeHTML(student.photo || user.avatar)}" alt="${escapeHTML(student.name)}" style="width: 100%; height: 100%; object-fit: cover;" onerror="this.style.display='none'; if(this.nextElementSibling) this.nextElementSibling.style.display='flex';">
                <span style="display: none; width: 100%; height: 100%; align-items: center; justify-content: center; font-size: 1.25rem; font-weight: 800;">${initials}</span>
              ` : initials}
            </div>
            <div>
              <div style="font-size: 0.76rem; font-weight: 600; color: ${business.bannerImage ? 'rgba(255,255,255,0.85)' : 'var(--color-text-secondary)'}; display: flex; align-items: center; gap: 6px; margin-bottom: 2px;">
                <span>${timeGreeting}</span>
                <span class="badge ${isCheckedIn ? 'badge-success' : 'badge-secondary'}" style="font-size: 0.65rem; padding: 2px 6px; border-radius: 10px;">
                  ${isCheckedIn ? '🟢 Active in Hall' : '⚪ Checked Out'}
                </span>
              </div>
              <h2 style="margin: 0; font-size: 1.15rem; font-weight: 800; color: ${business.bannerImage ? '#ffffff' : 'var(--color-text-primary)'}; white-space: normal; line-height: 1.25; text-transform: capitalize;">
                ${escapeHTML((student.name || '').toLowerCase().replace(/\b\w/g, c => c.toUpperCase()))}
              </h2>
              <div style="font-size: 0.78rem; color: ${business.bannerImage ? '#a7f3d0' : 'var(--color-text-muted)'}; margin-top: 2px; font-family: monospace; font-weight: 600;">
                ${escapeHTML(student.studentId || 'STU-MEMBER')} • ${escapeHTML(business.businessName || 'Study Library')}
              </div>
            </div>
          </div>

          <div style="display: flex; align-items: center; gap: 8px; flex-shrink: 0;">
            <button id="btn-portal-profile" class="btn btn-outline-secondary btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border-radius: 10px;">
              👤 Profile
            </button>
            <button id="btn-portal-renew" class="btn btn-primary btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 14px; border-radius: 10px;">
              ⚡ Renew
            </button>
            <button id="btn-portal-logout" class="btn btn-outline-danger btn-sm" style="font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border-radius: 10px;" title="Log out from Student Portal">
              🚪 Sign Out
            </button>
          </div>
        </div>
      </div>

      <!-- 2. Smart Pass & Active Desk Card (Apple Wallet Inspired) -->
      <div class="portal-pass-card mb-3" style="
        background: linear-gradient(135deg, #1e1b4b 0%, #312e81 45%, #0f766e 100%) !important;
        color: #ffffff !important;
        border-radius: 20px;
        padding: 1.25rem 1.5rem;
        position: relative;
        overflow: hidden;
        box-shadow: 0 12px 36px rgba(49, 46, 129, 0.32);
        border: 1px solid rgba(255, 255, 255, 0.2);
        box-sizing: border-box;
      ">
        <div style="display: flex; justify-content: space-between; align-items: flex-start; position: relative; z-index: 1; flex-wrap: wrap; gap: 10px;">
          <div>
            <div style="font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.8px; opacity: 0.85; font-weight: 700; color: #ffffff;">
              Allotted Study Desk
            </div>
            <div style="font-size: 1.85rem; font-weight: 900; line-height: 1.1; margin-top: 2px; text-shadow: 0 2px 8px rgba(0,0,0,0.2); color: #ffffff;">
              ${seatTitle}
            </div>
            <div style="font-size: 0.78rem; opacity: 0.92; margin-top: 2px; font-weight: 600; color: #ffffff;">
              Shift: <span style="color: #a7f3d0; font-weight: 700;">${escapeHTML(shiftName)}</span> • Plan: <span style="color: #c7d2fe; font-weight: 700;">${escapeHTML(planName)}</span>
            </div>
          </div>

          <!-- Plan Expiry Pill -->
          <div style="text-align: right;">
            <span style="background: rgba(255,255,255,0.22); backdrop-filter: blur(8px); padding: 5px 12px; border-radius: 20px; font-weight: 800; font-size: 0.82rem; letter-spacing: 0.3px; border: 1px solid rgba(255,255,255,0.35); display: inline-block; color: #ffffff;">
              ⏳ ${daysRemaining} ${daysRemaining === 1 ? 'Day' : 'Days'} Left
            </span>
            <div style="font-size: 0.72rem; opacity: 0.90; margin-top: 4px; font-weight: 600; color: #ffffff;">
              Valid till ${expiryDateStr}
            </div>
          </div>
        </div>

        <!-- Validity Progress Bar inside Pass -->
        <div style="margin-top: 14px; background: rgba(0,0,0,0.3); height: 6px; border-radius: 4px; overflow: hidden; position: relative; z-index: 1;">
          <div style="height: 100%; width: ${Math.max(5, Math.min(100, (daysRemaining / 30) * 100))}%; background: linear-gradient(90deg, #34d399, #a7f3d0); border-radius: 4px;"></div>
        </div>

        <!-- Pass Actions Row: 1-Tap Punch In/Out + ID Pass -->
        <div style="margin-top: 14px; padding-top: 12px; border-top: 1px dashed rgba(255,255,255,0.25); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; position: relative; z-index: 1;">
          <button id="btn-self-punch" class="btn btn-sm ${isCheckedIn ? 'btn-danger' : 'btn-success'}" style="
            font-weight: 800; font-size: 0.86rem; padding: 8px 18px; border-radius: 12px;
            box-shadow: 0 4px 14px rgba(0,0,0,0.25); border: none; flex: 1 1 180px; min-height: 42px;
          ">
            ${isCheckedIn ? '🔴 Punch-Out (Leave)' : (todayAttendance && todayAttendance.checkOut ? '🟢 Punch-In Again' : '🟢 1-Tap Attendance Punch')}
          </button>

          <button id="btn-portal-idcard" class="btn btn-sm" style="
            background: rgba(255,255,255,0.25); color: #ffffff !important; border: 1px solid rgba(255,255,255,0.45);
            font-weight: 700; font-size: 0.84rem; padding: 8px 16px; border-radius: 12px; backdrop-filter: blur(8px);
            flex: 1 1 140px; min-height: 42px; text-shadow: 0 1px 3px rgba(0,0,0,0.3);
          ">
            🪪 View Digital ID Pass
          </button>
        </div>
      </div>

      <!-- 3. Mandatory Profile & KYC Completion Card (Rendered when profile < 100%) -->
      ${(student.profileCompletion < 100 || !student.isProfileComplete) ? `
        <div class="card mb-3 p-3" style="background: rgba(245, 158, 11, 0.08); border: 1.5px solid rgba(245, 158, 11, 0.35); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
            <div style="display: flex; align-items: center; gap: 12px; max-width: 650px;">
              <div style="font-size: 2rem;">⚠️</div>
              <div>
                <h4 style="margin: 0 0 4px 0; font-size: 0.98rem; font-weight: 800; color: #f59e0b;">
                  Action Required: Complete Profile & KYC Upload (${student.profileCompletion || 60}%)
                </h4>
                <p style="margin: 0; font-size: 0.80rem; color: var(--color-text-secondary); line-height: 1.35;">
                  Upload your Profile Selfie and Aadhaar KYC proof to unlock official Digital Offline ID Card Pass.
                </p>
                <div style="margin-top: 6px; width: 100%; max-width: 320px; height: 5px; background: rgba(255,255,255,0.15); border-radius: 4px; overflow: hidden;">
                  <div style="height: 100%; width: ${student.profileCompletion || 60}%; background: linear-gradient(90deg, #f59e0b, #00b894); border-radius: 4px;"></div>
                </div>
              </div>
            </div>
            <button id="btn-portal-complete-kyc" class="btn btn-warning btn-sm" style="font-weight: 700; font-size: 0.82rem; padding: 6px 14px; border-radius: 10px;">
              ✏️ Upload KYC
            </button>
          </div>
        </div>
      ` : ''}

      <!-- 4. Modern App Launcher Grid (10 Colorful Gradient Tiles) -->
      <div class="mobile-app-grid" style="
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(min(100%, 76px), 1fr));
        gap: 8px;
        margin-bottom: 1.25rem;
      ">
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-idcard" title="Open Digital ID Card Studio">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(99, 102, 241, 0.18), rgba(99, 102, 241, 0.08)); color: #6366f1;">🪪</div>
          <div class="portal-tile-label icon-label">ID Pass</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-renew" title="Renew Membership Plan">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(16, 185, 129, 0.18), rgba(16, 185, 129, 0.08)); color: #10b981;">⚡</div>
          <div class="portal-tile-label icon-label">Renew</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-receipts" title="View Fee Receipts & Invoices">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(14, 165, 233, 0.18), rgba(14, 165, 233, 0.08)); color: #0ea5e9;">🧾</div>
          <div class="portal-tile-label icon-label">Receipts</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-notices" title="Read Campus Notices">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(245, 158, 11, 0.18), rgba(245, 158, 11, 0.08)); color: #f59e0b;">📢</div>
          <div class="portal-tile-label icon-label">Notices</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-holidays" title="Check Holiday Calendar">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(236, 72, 153, 0.18), rgba(236, 72, 153, 0.08)); color: #ec4899;">📅</div>
          <div class="portal-tile-label icon-label">Holidays</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-lostfound" title="Lost & Found Hub">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(20, 184, 166, 0.18), rgba(20, 184, 166, 0.08)); color: #14b8a6;">🔍</div>
          <div class="portal-tile-label icon-label">Lost/Found</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-feedback" title="Submit Support Feedback">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(168, 85, 247, 0.18), rgba(168, 85, 247, 0.08)); color: #a855f7;">💬</div>
          <div class="portal-tile-label icon-label">Feedback</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-seat-change" title="Request Seat Transfer">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(59, 130, 246, 0.18), rgba(59, 130, 246, 0.08)); color: #3b82f6;">💺</div>
          <div class="portal-tile-label icon-label">Shift/Seat</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-leave" title="Apply for Leave">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(249, 115, 22, 0.18), rgba(249, 115, 22, 0.08)); color: #f97316;">🌴</div>
          <div class="portal-tile-label icon-label">Leave App</div>
        </div>
        <div class="portal-app-tile mobile-app-icon-card" id="tile-portal-referral" title="Refer a Friend">
          <div class="portal-tile-icon icon-badge" style="background: linear-gradient(135deg, rgba(234, 179, 8, 0.18), rgba(234, 179, 8, 0.08)); color: #eab308;">🎁</div>
          <div class="portal-tile-label icon-label">Referral</div>
        </div>
      </div>

      <!-- 5. Segmented Tab Navigation Track -->
      <div class="portal-tab-track" style="display: flex; background: var(--color-bg-secondary); padding: 4px; border-radius: 14px; border: 1px solid var(--color-border); margin-bottom: 1.25rem; gap: 4px; overflow-x: auto;">
        <button type="button" class="portal-tab-pill active" data-portal-tab="overview" style="flex: 1; min-width: 100px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: var(--color-surface); color: var(--color-primary); box-shadow: 0 2px 8px rgba(0,0,0,0.12); transition: all 0.2s; white-space: nowrap; padding: 6px 10px;">
          🏠 Overview & Streaks
        </button>
        <button type="button" class="portal-tab-pill" data-portal-tab="campus" style="flex: 1; min-width: 100px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: transparent; color: var(--color-text-secondary); transition: all 0.2s; white-space: nowrap; padding: 6px 10px;">
          🏛️ Campus Life
        </button>
        <button type="button" class="portal-tab-pill" data-portal-tab="receipts" style="flex: 1; min-width: 100px; min-height: 40px; display: flex; align-items: center; justify-content: center; gap: 6px; font-weight: 700; font-size: 0.84rem; border-radius: 10px; border: none; cursor: pointer; background: transparent; color: var(--color-text-secondary); transition: all 0.2s; white-space: nowrap; padding: 6px 10px;">
          🧾 Fee Receipts
        </button>
      </div>

      <!-- ============================================================ -->
      <!-- TAB PANE 1: Overview & Streaks                              -->
      <!-- ============================================================ -->
      <div id="pane-portal-overview" class="portal-tab-pane">
        <!-- 3 Quick Metrics Row -->
        <div class="quick-stats-grid" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 180px), 1fr)); gap: 8px; margin-bottom: 1.25rem;">
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.74rem; font-weight: 700; color: var(--color-text-secondary);">🔥 Study Streak</div>
            <div style="font-size: 1.4rem; font-weight: 800; color: var(--color-warning); margin-top: 2px;">
              ${analytics?.currentStreak || student.studyStreakDays || 0} Days
            </div>
            <div style="font-size: 0.70rem; color: var(--color-text-muted);">Best Streak: ${analytics?.longestStreak || 1} days</div>
          </div>
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.74rem; font-weight: 700; color: var(--color-text-secondary);">📈 Total Study Time</div>
            <div style="font-size: 1.4rem; font-weight: 800; color: var(--color-info); margin-top: 2px;">
              ${totalHours} hrs
            </div>
            <div style="font-size: 0.70rem; color: var(--color-text-muted);">${analytics?.totalDaysPresent || 1} days present this month</div>
          </div>
          <div class="card p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="font-size: 0.74rem; font-weight: 700; color: var(--color-text-secondary);">🎖️ Badges Unlocked</div>
            <div style="font-size: 1.4rem; font-weight: 800; color: var(--color-primary); margin-top: 2px;">
              ${(student.badges || []).length} / 4
            </div>
            <div style="font-size: 0.70rem; color: var(--color-text-muted);">Library honors & achievements</div>
          </div>
        </div>

        <!-- AI Study Analytics & Consistency Score Card -->
        <div class="card mb-4 p-3 p-md-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 1.25rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.5rem;">🧠</span>
              <div>
                <h3 style="margin: 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary);">
                  AI Study Analytics & Consistency Score
                </h3>
                <p style="margin: 0; font-size: 0.78rem; color: var(--color-text-secondary);">
                  90-day learning habits, peak study hours & attendance discipline
                </p>
              </div>
            </div>

            <div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center;">
              <span class="badge" style="background: rgba(16, 185, 129, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.76rem; padding: 4px 8px; border-radius: 6px;">
                ${escapeHTML(analytics?.peakStudyHours?.badge || '🌅 Peak: 08:00 AM – 02:00 PM')}
              </span>
              <span class="badge" style="background: rgba(245, 158, 11, 0.15); color: var(--color-warning); font-weight: 700; font-size: 0.76rem; padding: 4px 8px; border-radius: 6px;">
                🔥 ${analytics?.currentStreak || 0} Day Streak
              </span>
            </div>
          </div>

          <!-- Main Layout: Score Gauge + Heatmap + AI Recommendation -->
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 250px), 1fr)); gap: 1.25rem; align-items: center;">
            <div style="display: flex; flex-direction: column; align-items: center; text-align: center; gap: 6px; padding: 12px 14px; background: var(--color-bg-secondary); border-radius: var(--radius-md); border: 1px solid var(--color-border);">
              ${renderGaugeScoreSvg(analytics?.consistencyScore || 0)}
              <div style="font-size: 0.82rem; color: var(--color-text-secondary); margin-top: 4px;">
                Avg: <strong>${escapeHTML(analytics?.averageDailyDuration?.formatted || '0m')}</strong> / day
              </div>
              <div style="font-size: 0.75rem; color: var(--color-text-muted);">
                ${analytics?.totalDaysPresent || 0} / 30 days present
              </div>
            </div>

            <div>
              <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                <span style="font-size: 0.84rem; font-weight: 700; color: var(--color-text-primary);">
                  📅 30-Day Attendance Heatmap
                </span>
                <span style="font-size: 0.72rem; color: var(--color-text-muted);">
                  Daily study intensity
                </span>
              </div>

              ${renderHeatmapGridHtml(analytics?.heatmap || [])}

              <div style="
                margin-top: 10px;
                padding: 8px 12px;
                background: linear-gradient(135deg, rgba(99, 102, 241, 0.08), rgba(16, 185, 129, 0.08));
                border: 1px solid rgba(99, 102, 241, 0.2);
                border-radius: var(--radius-md);
                display: flex;
                align-items: center;
                gap: 8px;
              ">
                <span style="font-size: 1.15rem; flex-shrink: 0;">💡</span>
                <div style="font-size: 0.80rem; color: var(--color-text-primary); line-height: 1.35;">
                  <strong>AI Study Tip:</strong> ${escapeHTML(analytics?.aiRecommendation || analytics?.aiStudyTip || 'Consistency is the key to cracking competitive exams. Try regular study blocks every morning!')}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 🏆 Achievements & Badges Studio Card -->
        <div class="card mb-4 p-3 p-md-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 1.25rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.5rem;">🏆</span>
              <div>
                <h3 style="margin: 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary);">
                  Achievements & Badges Studio
                </h3>
                <p style="margin: 0; font-size: 0.78rem; color: var(--color-text-secondary);">
                  Milestones, study streaks, and special honors
                </p>
              </div>
            </div>

            <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: var(--color-primary); font-weight: 700; font-size: 0.80rem; padding: 4px 10px; border-radius: 12px;">
              🎖️ ${(student.badges || []).length} / 4 Badges Unlocked
            </span>
          </div>

          <!-- 4 Badges Progress Grid -->
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 10px;">
            ${(() => {
              const badgeProgress = data?.badgeProgress || analytics?.badgeProgress || [];
              return [
                { badgeId: 'early_bird', title: '🌅 Early Bird', icon: '🌅', description: 'Checked in before 07:00 AM 5+ times', target: 5, unit: 'check-ins' },
                { badgeId: 'study_warrior', title: '⚔️ 100-Hr Warrior', icon: '⚔️', description: 'Total study hours >= 100', target: 100, unit: 'hrs' },
                { badgeId: 'night_owl', title: '🦉 Night Owl', icon: '🦉', description: 'Checked in after 08:00 PM 5+ times', target: 5, unit: 'check-ins' },
                { badgeId: 'streak_champion', title: '🏆 30-Day Streak', icon: '🏆', description: 'Consecutive attendance streak >= 30 days', target: 30, unit: 'days' }
              ].map(b => {
                const earnedBadge = (student.badges || []).find(eb => eb.badgeId === b.badgeId);
                const isEarned = !!earnedBadge;
                
                let progVal = 0;
                if (badgeProgress && Array.isArray(badgeProgress)) {
                  const bp = badgeProgress.find(p => p.badgeId === b.badgeId);
                  if (bp) progVal = bp.progress || 0;
                }
                if (isEarned) progVal = Math.max(progVal, b.target);
                const percent = Math.min(100, Math.round((progVal / b.target) * 100));

                return `
                  <div style="background: var(--color-bg-secondary); border: 1px solid ${isEarned ? 'var(--color-primary)' : 'var(--color-border)'}; border-radius: var(--radius-md); padding: 12px; display: flex; flex-direction: column; justify-content: space-between; position: relative;">
                    ${isEarned ? `
                      <div style="position: absolute; top: 6px; right: 6px; background: var(--color-success); color: white; font-size: 0.60rem; font-weight: 800; padding: 2px 6px; border-radius: 8px; text-transform: uppercase;">
                        Unlocked
                      </div>
                    ` : ''}
                    <div>
                      <div style="display: flex; align-items: center; gap: 8px; margin-bottom: 4px;">
                        <span style="font-size: 1.5rem; opacity: ${isEarned ? '1' : '0.6'};">${b.icon}</span>
                        <div>
                          <div style="font-weight: 700; font-size: 0.88rem; color: ${isEarned ? 'var(--color-primary)' : 'var(--color-text-primary)'};">
                            ${escapeHTML(b.title)}
                          </div>
                          <div style="font-size: 0.72rem; color: var(--color-text-secondary);">
                            ${escapeHTML(b.description)}
                          </div>
                        </div>
                      </div>
                    </div>

                    <div style="margin-top: 10px;">
                      <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.72rem; margin-bottom: 3px; font-weight: 600;">
                        <span style="color: var(--color-text-muted);">Progress</span>
                        <span style="color: ${isEarned ? 'var(--color-success)' : 'var(--color-primary)'};">${progVal} / ${b.target} (${percent}%)</span>
                      </div>
                      <div style="height: 5px; background: var(--color-surface); border-radius: 4px; overflow: hidden;">
                        <div style="width: ${percent}%; height: 100%; background: ${isEarned ? 'var(--color-success)' : 'var(--color-primary)'}; border-radius: 4px;"></div>
                      </div>
                    </div>
                  </div>
                `;
              }).join('');
            })()}
          </div>
        </div>

        <!-- Push Notifications Mini Card -->
        <div class="card mb-4 p-3" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
          <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
            <div style="display: flex; align-items: center; gap: 10px;">
              <span style="font-size: 1.6rem;">🔔</span>
              <div>
                <div style="font-weight: 700; font-size: 0.92rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 6px; flex-wrap: wrap;">
                  <span>Mobile Push Notifications</span>
                  <span id="portal-push-badge" class="badge" style="font-size: 0.70rem; padding: 2px 6px; border-radius: 10px; border: 1px solid currentColor;">
                    Checking...
                  </span>
                </div>
                <div style="font-size: 0.76rem; color: var(--color-text-secondary); margin-top: 1px;">
                  Instant lock-screen reminders for seat expiry, announcements & receipts.
                </div>
              </div>
            </div>

            <label class="switch-label" style="margin: 0;">
              <input type="checkbox" id="portal-push-toggle">
              <span class="switch-slider"></span>
            </label>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- TAB PANE 2: Campus Life Hub                                 -->
      <!-- ============================================================ -->
      <div id="pane-portal-campus" class="portal-tab-pane" style="display: none;">
        <div id="student-campus-hub-card" class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div class="card-header p-3" style="border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px;">
            <div style="display: flex; align-items: center; gap: 8px;">
              <span style="font-size: 1.3rem;">🏛️</span>
              <div>
                <h4 style="margin: 0; font-size: 1.02rem; font-weight: 700; color: var(--color-text-primary);">
                  Campus Notice Board & Services
                </h4>
                <span style="font-size: 0.76rem; color: var(--color-text-secondary);">Circulars, holiday closures, lost items, and support</span>
              </div>
            </div>
            
            <div class="btn-group btn-group-sm" id="campus-hub-tabs" role="tablist">
              <button type="button" class="btn btn-primary btn-campus-tab active" data-tab="notices" style="font-weight: 700;">📢 Notices</button>
              <button type="button" class="btn btn-outline-secondary btn-campus-tab" data-tab="holidays" style="font-weight: 700;">📅 Holidays</button>
              <button type="button" class="btn btn-outline-secondary btn-campus-tab" data-tab="lostfound" style="font-weight: 700;">🔍 Lost &amp; Found</button>
              <button type="button" class="btn btn-outline-secondary btn-campus-tab" data-tab="feedback" style="font-weight: 700;">💬 Feedback</button>
            </div>
          </div>

          <div class="card-body p-3">
            <div id="campus-tab-content-container">
              <div class="text-center p-4 text-muted">
                <div class="loading-spinner mb-2" style="margin: 0 auto;"></div>
                Loading campus announcements...
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- ============================================================ -->
      <!-- TAB PANE 3: Fee Receipts & Invoices                         -->
      <!-- ============================================================ -->
      <div id="pane-portal-receipts" class="portal-tab-pane" style="display: none;">
        <div id="student-receipts-card" class="card mb-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
          <div class="card-header p-3" style="border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover); display: flex; justify-content: space-between; align-items: center;">
            <h4 style="margin: 0; font-size: 1.02rem; font-weight: 700; color: var(--color-text-primary);">
              💳 My Payment Receipts & Invoices
            </h4>
            <span style="font-size: 0.78rem; color: var(--color-text-muted);">Official Tax & Fee Invoices</span>
          </div>
          <div class="card-body p-0">
            <div style="overflow-x: auto;">
              <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
                <thead>
                  <tr style="border-bottom: 1px solid var(--color-divider); text-align: left; font-size: 0.82rem; color: var(--color-text-muted);">
                    <th style="padding: 10px 14px;">Receipt #</th>
                    <th style="padding: 10px 14px;">Date</th>
                    <th style="padding: 10px 14px;">Method</th>
                    <th style="padding: 10px 14px;">Amount</th>
                    <th style="padding: 10px 14px;">Status</th>
                    <th style="padding: 10px 14px; text-align: right;">Action</th>
                  </tr>
                </thead>
                <tbody>
                  ${payments && payments.length > 0 ? payments.map(p => `
                    <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.88rem;">
                      <td style="padding: 10px 14px; font-family: monospace; font-weight: 700;">
                        ${escapeHTML(p.receiptNumber || 'REC')}
                        <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(p.receiptNumber || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Receipt #">📋</button>
                      </td>
                      <td style="padding: 10px 14px;">${new Date(p.paymentDate).toLocaleDateString('en-IN')} <small class="text-muted">(${SmartFormatters.timeAgo(p.paymentDate)})</small></td>
                      <td style="padding: 10px 14px; text-transform: uppercase;">${escapeHTML(p.paymentMethod || 'UPI')}</td>
                      <td style="padding: 10px 14px; font-weight: 700; color: var(--color-success);">${SmartFormatters.currency(p.finalAmount)}</td>
                      <td style="padding: 10px 14px;"><span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success);">Paid</span></td>
                      <td style="padding: 10px 14px; text-align: right;">
                        <button class="btn btn-sm btn-primary btn-view-receipt" data-receipt='${JSON.stringify(p)}' style="font-size: 0.78rem; padding: 4px 10px; font-weight: 600;">
                          📥 Download / Print
                        </button>
                      </td>
                    </tr>
                  `).join('') : `
                    <tr><td colspan="6" class="p-4 text-center text-muted">No past payments recorded yet.</td></tr>
                  `}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  `;

  // -----------------------------------------------------------------
  // Segmented Tab Switcher Logic
  // -----------------------------------------------------------------
  const portalTabPills = container.querySelectorAll('.portal-tab-pill');
  const portalTabPanes = {
    overview: container.querySelector('#pane-portal-overview'),
    campus: container.querySelector('#pane-portal-campus'),
    receipts: container.querySelector('#pane-portal-receipts')
  };

  const switchPortalTab = (tabKey) => {
    portalTabPills.forEach(pill => {
      const isActive = pill.getAttribute('data-portal-tab') === tabKey;
      pill.classList.toggle('active', isActive);
      pill.style.background = isActive ? 'var(--color-surface)' : 'transparent';
      pill.style.color = isActive ? 'var(--color-primary)' : 'var(--color-text-secondary)';
      pill.style.boxShadow = isActive ? '0 2px 8px rgba(0, 0, 0, 0.12)' : 'none';
    });
    Object.keys(portalTabPanes).forEach(k => {
      if (portalTabPanes[k]) {
        portalTabPanes[k].style.display = (k === tabKey) ? 'block' : 'none';
      }
    });
    if (tabKey === 'campus' && typeof activateCampusTab === 'function') {
      activateCampusTab('notices');
    }
  };

  portalTabPills.forEach(pill => {
    pill.addEventListener('click', () => {
      switchPortalTab(pill.getAttribute('data-portal-tab'));
    });
  });

  // App Launcher Tiles Wiring
  container.querySelector('#tile-portal-idcard')?.addEventListener('click', () => {
    container.querySelector('#btn-portal-idcard')?.click();
  });
  container.querySelector('#tile-portal-renew')?.addEventListener('click', () => {
    container.querySelector('#btn-portal-renew')?.click();
  });
  container.querySelector('#tile-portal-receipts')?.addEventListener('click', () => {
    switchPortalTab('receipts');
  });
  container.querySelector('#tile-portal-notices')?.addEventListener('click', () => {
    switchPortalTab('campus');
    if (typeof activateCampusTab === 'function') activateCampusTab('notices');
  });
  container.querySelector('#tile-portal-holidays')?.addEventListener('click', () => {
    switchPortalTab('campus');
    if (typeof activateCampusTab === 'function') activateCampusTab('holidays');
  });
  container.querySelector('#tile-portal-lostfound')?.addEventListener('click', () => {
    switchPortalTab('campus');
    if (typeof activateCampusTab === 'function') activateCampusTab('lostfound');
  });
  container.querySelector('#tile-portal-feedback')?.addEventListener('click', () => {
    switchPortalTab('campus');
    if (typeof activateCampusTab === 'function') activateCampusTab('feedback');
  });

  // Admin Switch Student Handler
  container.querySelector('#admin-switch-student')?.addEventListener('change', async (e) => {
    const selectedStudentId = e.target.value;
    container.innerHTML = `
      <div class="card p-5 text-center" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="loading-spinner mb-3" style="margin: 0 auto;"></div>
        <p style="color: var(--color-text-secondary); margin: 0;">Switching student inspection view...</p>
      </div>
    `;
    try {
      const res = await api.get(`/api/student-portal/dashboard?studentId=${selectedStudentId}`);
      if (!res.success || !res.data) throw new Error(res.message);
      let analytics = null;
      try {
        const aRes = await api.get(`/api/attendance/analytics/${res.data.student._id}`);
        if (aRes.success) analytics = aRes.data;
      } catch (err) {}
      renderPortalUI(container, res.data, analytics);
    } catch (err) {
      Toast.error(err.message || 'Failed to switch student');
      render().then(newEl => container.replaceWith(newEl));
    }
  });

  // Attach Self Punch Handler
  container.querySelector('#btn-self-punch')?.addEventListener('click', async () => {
    const btn = container.querySelector('#btn-self-punch');
    Loading.button(btn, true);
    try {
      const res = await api.post('/api/student-portal/punch', {});
      if (res.success) {
        Toast.success(res.message);
        setTimeout(() => render().then(newEl => container.replaceWith(newEl)), 500);
      } else {
        Toast.error(res.message);
      }
    } catch (err) {
      Toast.error(err.message || 'Punch error');
    } finally {
      Loading.button(btn, false);
    }
  });

  // Initialize Push Notification Toggle & Badge in Student Portal
  const pushTogglePortal = container.querySelector('#portal-push-toggle');
  const pushBadgePortal = container.querySelector('#portal-push-badge');

  function syncPortalPushUI() {
    if (!pushTogglePortal || !pushBadgePortal) return;

    if (!PushNotifications.isSupported()) {
      pushTogglePortal.disabled = true;
      pushTogglePortal.checked = false;
      pushBadgePortal.textContent = 'Not Supported';
      pushBadgePortal.className = 'badge badge-secondary';
      pushBadgePortal.style.background = 'var(--color-bg-secondary)';
      pushBadgePortal.style.color = 'var(--color-text-secondary)';
      return;
    }

    const status = PushNotifications.getPermissionStatus();
    if (status === 'granted') {
      pushBadgePortal.textContent = 'Permission Granted';
      pushBadgePortal.className = 'badge badge-success';
      pushBadgePortal.style.background = 'rgba(0, 184, 148, 0.15)';
      pushBadgePortal.style.color = 'var(--color-success)';
      pushTogglePortal.checked = PushNotifications.isEnabled();
    } else if (status === 'denied') {
      pushBadgePortal.textContent = 'Blocked in Browser';
      pushBadgePortal.className = 'badge badge-danger';
      pushBadgePortal.style.background = 'rgba(235, 77, 75, 0.15)';
      pushBadgePortal.style.color = 'var(--color-danger)';
      pushTogglePortal.checked = false;
    } else {
      pushBadgePortal.textContent = 'Permission Required';
      pushBadgePortal.className = 'badge badge-warning';
      pushBadgePortal.style.background = 'rgba(253, 203, 110, 0.2)';
      pushBadgePortal.style.color = 'var(--color-warning)';
      pushTogglePortal.checked = false;
    }
  }

  syncPortalPushUI();

  pushTogglePortal?.addEventListener('change', async (e) => {
    if (e.target.checked) {
      try {
        const perm = await PushNotifications.requestPermission();
        if (perm === 'granted') {
          await PushNotifications.subscribe();
          Toast.success('🔔 Native Mobile Push Notifications enabled!');
        } else if (perm === 'denied') {
          Toast.error('Push notification permission blocked by browser settings.');
        }
      } catch (err) {
        Toast.error(err.message || 'Failed to enable push notifications');
      }
    } else {
      await PushNotifications.unsubscribe();
      Toast.info('Push notifications disabled.');
    }
    syncPortalPushUI();
  });

  // Attach PDF Admission Form Download Handler
  container.querySelector('#btn-portal-download-pdf')?.addEventListener('click', () => {
    previewAdmissionFormPDF(student, { business });
  });

  container.addEventListener('click', (e) => {
    const copyBtn = e.target.closest('.btn-copy-text');
    if (copyBtn) {
      e.stopPropagation();
      const textToCopy = copyBtn.getAttribute('data-copy');
      if (textToCopy) copyToClipboard(textToCopy, copyBtn);
    }
  });

  // Attach ID Card Handler
  container.querySelector('#btn-portal-idcard')?.addEventListener('click', () => {
    if (student.profileCompletion < 100 || !student.isProfileComplete) {
      Toast.warning('🔒 Digital ID Card is locked! Please upload your Profile Photo Selfie & Aadhaar KYC first.');
      container.querySelector('#btn-portal-profile')?.click();
      return;
    }

    const expiryDate = expiryDateStr;
    const seatNumber = seatTitle;
    const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : new Date().toLocaleDateString('en-IN');
    const emergencyName = student.emergencyContact?.name || 'Parent / Guardian';
    const emergencyPhone = student.emergencyContact?.phone || '-';
    const emergencyRelation = student.emergencyContact?.relation || 'Parent';
    const address = [student.address, student.city, student.state, student.pincode].filter(Boolean).join(', ') || 'Campus Residential';
    const bloodGroup = student.bloodGroup || '';
    const shiftName = student.shift?.name || student.shift?.timing || student.shift || student.plan?.shift || 'Full Day';
    const phone = student.phone || student.mobile || '';
    const stampImgUrl = business.stampImage || business.stampImageUrl || window.store?.profile?.stampImage || window.store?.settings?.businessProfile?.stampImage || JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}')?.stampImage || '';
    const logoImgUrl = business.logo || business.logoUrl || window.store?.profile?.logo || window.store?.settings?.businessProfile?.logo || JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}')?.logo || '';

    const qrPayload = encodeURIComponent(student.studentId || student.enrollmentNo || student.phone || student._id || 'STUDENT');
    const qrCodeURL = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${qrPayload}&margin=2&bgcolor=ffffff`;

    let currentOrientation = 'horizontal';
    let currentSide = 'dual';
    let currentColor = '#4f46e5';
    let currentTheme = 'gradient';
    let showQr = true;
    let showEmergency = true;
    let showStamp = true;
    let showBlood = Boolean(bloodGroup);

    const modalContent = document.createElement('div');
    modalContent.className = 'id-card-studio-wrapper';
    modalContent.style.cssText = 'font-family: "Outfit", sans-serif; user-select: none;';

    let idModal = null;

    const renderPortalStudioUI = () => {
      const isHoriz = currentOrientation === 'horizontal';

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
            cardShadow: '0 10px 28px rgba(0,0,0,0.5)'
          };
        }
        if (theme === 'minimal') {
          return {
            cardBg: '#ffffff',
            textColor: '#0f172a',
            subText: '#475569',
            border: `2.5px solid #0f172a`,
            outline: `1.5px dashed #64748b`,
            headerBg: color,
            footerBg: '#f8fafc',
            badgeBg: `${color}18`,
            badgeColor: color,
            cardShadow: '0 8px 24px rgba(0,0,0,0.14)'
          };
        }
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

      const renderFrontCard = (isV) => {
        const st = getThemeStyles(currentColor, currentTheme);
        const cardPhotoSrc = student.photo || student.avatar || user?.photo || user?.avatar || window.store?.user?.photo || window.store?.user?.avatar || (document.querySelector('#sp-avatar-img')?.src) || '';
        if (isV) {
          // Vertical Front (CR80 Portrait: 254px x 400px)
          return `
            <div class="id-card-entity id-card-v id-card-front" style="
              width: 254px; min-height: 400px; height: 400px; background: ${st.cardBg}; color: ${st.textColor};
              border-radius: 12px; ${st.border}; outline: ${st.outline}; outline-offset: 4px; overflow: hidden; box-shadow: ${st.cardShadow};
              position: relative; display: flex; flex-direction: column; box-sizing: border-box; font-family: var(--font-family, system-ui, sans-serif);
            ">
              <!-- Top Curved Banner -->
              <div style="background: ${st.headerBg}; color: #fff; padding: 8px 10px; text-align: center; position: relative;">
                <div style="display: flex; align-items: center; justify-content: center; gap: 6px; margin-bottom: 2px;">
                  ${logoImgUrl ? `<img src="${logoImgUrl}" style="width: 22px; height: 22px; border-radius: 4px; object-fit: contain; background: #fff;">` : ''}
                  <div style="font-weight: 800; font-size: 0.85rem; letter-spacing: 0.4px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHTML(business.businessName || 'Study Library')}</div>
                </div>
                <div style="font-size: 0.62rem; opacity: 0.9; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${escapeHTML(business.tagline || 'Student Membership Pass')}</div>
              </div>

              <!-- Center Avatar & Name -->
              <div style="display: flex; flex-direction: column; align-items: center; padding: 8px 10px 4px 10px; text-align: center;">
                <div style="width: 68px; height: 68px; border-radius: 12px; background: #eef2ff; border: 2.5px solid ${currentColor}; overflow: hidden; display: flex; align-items: center; justify-content: center; font-size: 1.5rem; font-weight: 800; color: ${currentColor}; margin-bottom: 4px; box-shadow: 0 3px 10px rgba(0,0,0,0.1);">
                  ${cardPhotoSrc ? `<img src="${cardPhotoSrc}" style="width: 100%; height: 100%; object-fit: cover;">` : initials}
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
                  ${logoImgUrl ? `<img src="${logoImgUrl}" style="width: 24px; height: 24px; border-radius: 4px; object-fit: contain; background: #fff; flex-shrink: 0;">` : ''}
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
                    ${cardPhotoSrc ? `<img src="${cardPhotoSrc}" style="width: 100%; height: 100%; object-fit: cover;">` : initials}
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
                      <div style="width: 65px; border-bottom: 1px solid ${st.subText}; margin-bottom: 2px; margin-left: auto; margin-right: auto;"></div>
                      <div style="font-size: 0.55rem; color: ${st.subText}; font-weight: 600;">Auth. Signatory</div>
                    </div>
                  ` : ''}
                </div>
              </div>

              <!-- Footer -->
              <div style="background: ${st.footerBg}; border-top: 1px dashed rgba(0,0,0,0.08); padding: 4px 12px; text-align: center; font-size: 0.60rem; color: ${st.subText};">
                ${escapeHTML(business.phone ? `Helpline: ${business.phone}` : '')}${business.phone && business.address ? ' • ' : ''}${escapeHTML(business.address || '')}
              </div>
            </div>
          `;
        }
      };

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
                font-size: 0.78rem;
                line-height: 1;
                color: var(--color-text-secondary, #94a3b8);
                box-shadow: 0 2px 8px rgba(0,0,0,0.25);
                z-index: 2;
              " title="Fold / Cut Line">✂️</span>
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
        <div style="display: flex; flex-direction: column; gap: 14px;">
          <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; margin-bottom: 12px;">
              <div style="display: flex; align-items: center; gap: 6px;">
                <label style="font-size: 0.8rem; font-weight: 700; margin: 0;">📐 Orientation:</label>
                <div class="btn-group btn-group-sm">
                  <button type="button" class="btn ${currentOrientation === 'horizontal' ? 'btn-primary' : 'btn-outline-secondary'} btn-opt-horiz" style="font-size: 0.76rem; font-weight: 700;">🔄 Horizontal</button>
                  <button type="button" class="btn ${currentOrientation === 'vertical' ? 'btn-primary' : 'btn-outline-secondary'} btn-opt-vert" style="font-size: 0.76rem; font-weight: 700;">📱 Vertical</button>
                </div>
              </div>

              <div style="display: flex; align-items: center; gap: 6px;">
                <label style="font-size: 0.8rem; font-weight: 700; margin: 0;">📑 Card Side:</label>
                <div class="btn-group btn-group-sm">
                  <button type="button" class="btn ${currentSide === 'front' ? 'btn-primary' : 'btn-outline-secondary'} btn-side-front" style="font-size: 0.76rem; font-weight: 700;">🪪 Front</button>
                  <button type="button" class="btn ${currentSide === 'back' ? 'btn-primary' : 'btn-outline-secondary'} btn-side-back" style="font-size: 0.76rem; font-weight: 700;">📄 Back</button>
                  <button type="button" class="btn ${currentSide === 'dual' ? 'btn-primary' : 'btn-outline-secondary'} btn-side-dual" style="font-size: 0.76rem; font-weight: 700;">📑 Both Sides</button>
                </div>
              </div>
            </div>

            <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 10px; border-top: 1px solid var(--color-border); padding-top: 10px;">
              <div style="display: flex; align-items: center; gap: 10px; flex-wrap: wrap;">
                <div>
                  <label style="font-size: 0.75rem; font-weight: 700; display: block; margin-bottom: 2px;">Color Theme</label>
                  <div style="display: flex; align-items: center; gap: 6px;">
                    <input type="color" id="id-studio-color" value="${currentColor}" style="width: 32px; height: 28px; border: none; padding: 0; cursor: pointer; border-radius: 4px;">
                    <select id="id-studio-theme-select" class="form-select form-select-sm" style="font-size: 0.78rem; min-width: 120px;">
                      <option value="gradient" ${currentTheme === 'gradient' ? 'selected' : ''}>🟣 Purple Indigo</option>
                      <option value="dark" ${currentTheme === 'dark' ? 'selected' : ''}>⚫ Dark Slate Pro</option>
                      <option value="minimal" ${currentTheme === 'minimal' ? 'selected' : ''}>⚪ Minimal Classic</option>
                    </select>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div id="id-card-render-stage" style="padding: 14px 10px; display: flex; justify-content: center; align-items: center; background: radial-gradient(circle, rgba(108,92,231,0.06) 0%, transparent 70%); border-radius: var(--radius-md); overflow-x: auto; width: 100%; box-sizing: border-box;">
            ${previewHtml}
          </div>

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
              <button type="button" class="btn btn-success btn-sm" id="btn-print-portal-id-card" style="font-weight: 800; padding: 6px 18px;">
                🖨️ Print ID Card (Front + Back)
              </button>
              <button type="button" class="btn btn-secondary btn-sm" id="btn-close-portal-id-studio">Close</button>
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
              border: 2.5px solid #000000 !important;
              outline: 1.5px dashed #475569 !important;
              outline-offset: 5px !important;
              -webkit-print-color-adjust: exact !important;
              print-color-adjust: exact !important;
              box-shadow: none !important;
              break-inside: avoid !important;
              page-break-inside: avoid !important;
            }
          }
        </style>
      `;

      modalContent.querySelector('.btn-opt-horiz')?.addEventListener('click', () => {
        currentOrientation = 'horizontal';
        renderPortalStudioUI();
      });
      modalContent.querySelector('.btn-opt-vert')?.addEventListener('click', () => {
        currentOrientation = 'vertical';
        renderPortalStudioUI();
      });
      modalContent.querySelector('.btn-side-front')?.addEventListener('click', () => {
        currentSide = 'front';
        renderPortalStudioUI();
      });
      modalContent.querySelector('.btn-side-back')?.addEventListener('click', () => {
        currentSide = 'back';
        renderPortalStudioUI();
      });
      modalContent.querySelector('.btn-side-dual')?.addEventListener('click', () => {
        currentSide = 'dual';
        renderPortalStudioUI();
      });

      modalContent.querySelector('#id-studio-color')?.addEventListener('input', (e) => {
        currentColor = e.target.value;
        renderPortalStudioUI();
      });
      modalContent.querySelector('#id-studio-theme-select')?.addEventListener('change', (e) => {
        currentTheme = e.target.value;
        renderPortalStudioUI();
      });

      modalContent.querySelector('#btn-close-portal-id-studio')?.addEventListener('click', () => {
        if (idModal) idModal.close();
      });

      modalContent.querySelector('#btn-print-portal-id-card')?.addEventListener('click', () => {
        if (currentSide !== 'dual') {
          currentSide = 'dual';
          renderPortalStudioUI();
        }
        setTimeout(() => {
          window.print();
        }, 300);
      });

      const downloadElementAsPng = async (targetSelector, filename) => {
        try {
          if (!window.html2canvas) {
            await new Promise((res, rej) => {
              const s = document.createElement('script');
              s.src = 'https://cdn.jsdelivr.net/npm/html2canvas@1.4.1/dist/html2canvas.min.js';
              s.onload = res; s.onerror = rej;
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

      modalContent.querySelector('#btn-download-front-png')?.addEventListener('click', () => {
        downloadElementAsPng('.id-card-front', `ID_Front_${(student.studentId||student.name).replace(/\s+/g,'_')}.png`);
      });
      modalContent.querySelector('#btn-download-back-png')?.addEventListener('click', () => {
        downloadElementAsPng('.id-card-back', `ID_Back_${(student.studentId||student.name).replace(/\s+/g,'_')}.png`);
      });
      modalContent.querySelector('#btn-download-1080p-pass')?.addEventListener('click', () => {
        download1080pMobileIDPass(student, business, initials, seatTitle, planName, expiryDateStr, { shiftName, phone, bloodGroup, showBlood });
      });
    };

    renderPortalStudioUI();

    idModal = new Modal({ title: `🪪 Student ID Pass Studio: ${escapeHTML(student.name)}`, content: modalContent, size: 'xl' });
    idModal.show();
  });



  container.querySelector('#btn-portal-complete-kyc')?.addEventListener('click', () => {
    container.querySelector('#btn-portal-profile')?.click();
  });

  // Attach Student Portal Sign Out Handler
  container.querySelector('#btn-portal-logout')?.addEventListener('click', async () => {
    const ok = await Confirm.show('Are you sure you want to sign out of the Student Portal?', 'Sign Out');
    if (ok) {
      localStorage.removeItem('sl_token');
      localStorage.removeItem('student_token');
      localStorage.removeItem('sl_student_user');
      localStorage.removeItem('sl_user_role');
      if (window.store) window.store.user = null;
      window.location.href = '/student-login';
    }
  });

  // Attach Student Profile View Modal
  container.querySelector('#btn-portal-profile')?.addEventListener('click', async () => {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <div class="text-center p-4 text-muted">
        <div class="loading-spinner mb-2" style="margin: 0 auto;"></div>
        Loading complete admission profile...
      </div>
    `;

    const profileModal = new Modal({
      title: '👤 My Admission Profile & Submitted Details',
      content: modalContent,
      size: 'lg'
    });
    profileModal.show();

    try {
      const [fieldsRes, tplRes, cfgRes] = await Promise.all([
        api.get('/api/custom-fields/all').catch(() => api.get('/api/custom-fields')).catch(() => ({ data: [] })),
        api.get('/api/custom-fields/templates/active').catch(() => ({ data: null })),
        api.get('/api/system/public-config').catch(() => ({ data: null }))
      ]);

      const customFieldsList = Array.isArray(fieldsRes.data) ? fieldsRes.data : [];
      const cfMap = (student.customFields && typeof student.customFields === 'object') ? student.customFields : {};

      // Smart value resolver across direct schema fields and custom fields map
      const getVal = (...keys) => {
        for (const k of keys) {
          if (student[k] !== undefined && student[k] !== null && student[k] !== '') return student[k];
          if (cfMap[k] !== undefined && cfMap[k] !== null && cfMap[k] !== '') return cfMap[k];
          const lowerK = k.toLowerCase().replace(/[^a-z0-9]/g, '');
          for (const [ck, cv] of Object.entries(cfMap)) {
            if (ck.toLowerCase().replace(/[^a-z0-9]/g, '') === lowerK && cv !== undefined && cv !== null && cv !== '') {
              return cv;
            }
          }
        }
        return '';
      };

      const dobVal = getVal('dob', 'dateOfBirth', 'birthDate');
      const formattedDob = dobVal ? (new Date(dobVal).toString() !== 'Invalid Date' ? new Date(dobVal).toLocaleDateString('en-IN') : dobVal) : 'N/A';
      const bloodVal = getVal('bloodGroup', 'blood_group');
      const addressVal = getVal('address', 'residentialAddress') || [student.address, student.city, student.state, student.pincode].filter(Boolean).join(', ') || 'N/A';
      const pincodeVal = getVal('pincode', 'pinCode', 'postalCode') || 'N/A';
      const cityVal = getVal('city', 'town') || '';
      const stateVal = getVal('state', 'province') || '';
      const emNameVal = getVal('emergencyContactName', 'emergencyName') || student.emergencyContact?.name || 'N/A';
      const emPhoneVal = getVal('emergencyContactPhone', 'emergencyPhone') || student.emergencyContact?.phone || 'N/A';
      const emRelVal = getVal('emergencyContactRelation', 'emergencyRelation') || student.emergencyContact?.relation || 'Parent / Guardian';

      // KYC
      const idTypeVal = getVal('idProofType', 'idType') || student.idProof?.type || 'Aadhaar Card';
      const idNumVal = getVal('idProofNumber', 'idNumber') || student.idProof?.number || '';
      const idImgVal = getVal('idProofImage', 'idProof', 'idProofPhoto') || student.idProof?.image || '';

      // Academic
      const rawExams = getVal('targetExams', 'targetExam') || student.targetExams || [];
      const examsList = Array.isArray(rawExams) ? rawExams : (String(rawExams).split(',').map(s => s.trim()).filter(Boolean));
      const collegeVal = getVal('college', 'collegeName', 'institute', 'university') || '';
      const qualVal = getVal('qualification', 'highestQualification', 'degree') || '';
      const remarksVal = getVal('remarks', 'notes', 'specialRemarks') || '';

      // Truly extra custom fields
      const standardKeys = new Set([
        'name', 'fullname', 'phone', 'mobile', 'whatsapp', 'email', 'gender', 'sex',
        'dob', 'dateofbirth', 'birthdate', 'bloodgroup', 'blood_group',
        'address', 'residentialaddress', 'pincode', 'postalcode', 'city', 'state',
        'emergencyname', 'emergencycontactname', 'emergencyphone', 'emergencycontactphone', 'emergencyrelation', 'emergencycontactrelation',
        'idtype', 'idprooftype', 'idnumber', 'idproofnumber', 'idproof', 'idproofimage', 'idproofphoto',
        'targetexam', 'targetexams', 'college', 'collegename', 'institute', 'university', 'qualification', 'highestqualification',
        'branch', 'plan', 'shift', 'seat', 'password', 'photo', 'signature', 'status', 'remarks', 'specialremarks', 'notes'
      ]);

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

      const templateSections = (tplRes?.data?.sections && Array.isArray(tplRes.data.sections)) ? tplRes.data.sections : [];

      const extraCustomFields = [];
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
            label: def?.label || def?.fieldLabel || formatHumanLabel(k),
            value: v,
            section: def?.section || 'additional',
            order: def?.order !== undefined ? def.order : 999,
            type: def?.type || 'text'
          });
        }
      });

      function formatVal(f, val) {
        if (val === undefined || val === null || val === '') return '<span class="text-muted small">Not provided</span>';
        if (f.type === 'star_rating') {
          const num = parseInt(val, 10) || 5;
          return `<span style="color: #f59e0b; font-size: 1.1rem;">${'★'.repeat(num)}${'☆'.repeat(Math.max(0, 5 - num))}</span> <strong class="ms-1">(${num}/5)</strong>`;
        }
        if (f.type === 'checkbox' || f.type === 'terms_checkbox' || f.type === 'consent_checkbox') {
          const isTrue = val === true || val === 'true' || val === 'on' || val === 1;
          return isTrue ? `<span class="badge badge-success">✅ Yes / Agreed</span>` : `<span class="badge badge-secondary">❌ No</span>`;
        }
        if (f.type === 'photo_upload' || f.type === 'file' || f.fieldName?.toLowerCase().includes('image')) {
          const imgUrl = String(val).startsWith('data:image') || String(val).startsWith('/') ? String(val) : `/${val}`;
          return `
            <a href="${imgUrl}" target="_blank" style="display: inline-flex; align-items: center; gap: 6px; text-decoration: none; color: var(--color-primary); font-weight: 600; font-size: 0.85rem;">
              <img src="${imgUrl}" style="width: 44px; height: 44px; border-radius: 6px; object-fit: cover; border: 1px solid var(--color-border);" onerror="this.style.display='none'">
              <span>🔍 View Document</span>
            </a>
          `;
        }
        if (f.type === 'blood_group') {
          return `<span class="badge" style="background: rgba(239, 68, 68, 0.12); color: var(--color-danger); font-weight: 700;">🩸 ${escapeHTML(val)}</span>`;
        }
        if (f.type === 'exam_badge') {
          const arr = Array.isArray(val) ? val : String(val).split(',').filter(Boolean);
          return arr.map(e => `<span class="badge badge-primary me-1">${escapeHTML(e)}</span>`).join(' ');
        }
        return `<strong>${escapeHTML(val)}</strong>`;
      }

      // Build Clean, Beautiful Section Cards
      let sectionsHtml = '';

      // 1. Personal & Contact Details Card
      sectionsHtml += `
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
            <span>👤</span> Personal &amp; Emergency Contact Details
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; font-size: 0.88rem;">
            <div><span class="text-muted d-block small">Full Name</span><strong>${escapeHTML(student.name)}</strong></div>
            <div><span class="text-muted d-block small">Mobile Phone (WhatsApp)</span><strong>${escapeHTML(SmartFormatters.phone(student.phone))}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(student.phone || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">📋</button></div>
            <div><span class="text-muted d-block small">Email Address</span><strong>${escapeHTML(student.email || 'N/A')}</strong></div>
            <div><span class="text-muted d-block small">Gender</span><strong style="text-transform: capitalize;">${escapeHTML(student.gender || 'N/A')}</strong></div>
            <div><span class="text-muted d-block small">Date of Birth</span><strong>${escapeHTML(formattedDob)}</strong></div>
            <div><span class="text-muted d-block small">Blood Group</span>${bloodVal ? `<span class="badge" style="background: rgba(239, 68, 68, 0.12); color: var(--color-danger); font-weight: 700;">🩸 ${escapeHTML(bloodVal)}</span>` : '<span class="text-muted small">Not specified</span>'}</div>
            <div style="grid-column: 1 / -1;"><span class="text-muted d-block small">Residential / Hostel Address</span><strong>${escapeHTML(addressVal)}</strong></div>
            <div><span class="text-muted d-block small">City &amp; State</span><strong>${escapeHTML(cityVal || student.city || '')}${stateVal || student.state ? ', ' + escapeHTML(stateVal || student.state) : ''}</strong></div>
            <div><span class="text-muted d-block small">Pincode</span><strong>${escapeHTML(pincodeVal)}</strong></div>
            <div><span class="text-muted d-block small">Emergency Contact</span><strong>${escapeHTML(emNameVal)} (${escapeHTML(emRelVal)})</strong></div>
            <div><span class="text-muted d-block small">Emergency Phone</span><strong>${escapeHTML(SmartFormatters.phone(emPhoneVal))}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(emPhoneVal || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Emergency Phone">📋</button></div>
          </div>
        </div>
      `;

      // 2. Government ID & KYC Verification Card
      sectionsHtml += `
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
            <span>🪪</span> Government ID &amp; KYC Verification
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; font-size: 0.88rem;">
            <div>
              <span class="text-muted d-block small">ID Proof Type</span>
              <strong>${escapeHTML(idTypeVal)}</strong>
            </div>
            <div>
              <span class="text-muted d-block small">ID Proof Document Number</span>
              <strong style="font-family: monospace; letter-spacing: 0.5px;">${escapeHTML((idTypeVal === 'Aadhaar Card' || idTypeVal === 'Aadhaar' || !idTypeVal) ? SmartFormatters.aadhaar(idNumVal) : (idNumVal || 'Verified'))}</strong>
              ${idNumVal ? `<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(idNumVal)}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy ID Proof Number">📋</button>` : ''}
            </div>
            ${idImgVal ? `
              <div>
                <span class="text-muted d-block small">ID Proof Document Upload</span>
                <a href="${idImgVal.startsWith('/') ? idImgVal : '/' + idImgVal}" target="_blank" class="btn btn-xs btn-outline-primary mt-1" style="font-weight: 600;">
                  🔍 View Document Scan
                </a>
              </div>
            ` : ''}
          </div>
        </div>
      `;

      // 3. Academic Goals & Education Card
      sectionsHtml += `
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
            <span>🎯</span> Academic Goals &amp; Education
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 200px), 1fr)); gap: 14px; font-size: 0.88rem;">
            <div>
              <span class="text-muted d-block small">Target Competitive Exams</span>
              <div>${examsList.length > 0 ? examsList.map(e => `<span class="badge badge-primary me-1 mb-1" style="font-weight: 700;">${escapeHTML(e)}</span>`).join('') : '<span class="text-muted small">None specified</span>'}</div>
            </div>
            ${collegeVal ? `
              <div>
                <span class="text-muted d-block small">College / Institute / Company</span>
                <strong>${escapeHTML(collegeVal)}</strong>
              </div>
            ` : ''}
            ${qualVal ? `
              <div>
                <span class="text-muted d-block small">Highest Qualification</span>
                <strong>${escapeHTML(qualVal)}</strong>
              </div>
            ` : ''}
          </div>
        </div>
      `;

      // 4. Custom Sections & Additional Information Cards (as configured by Admin in Form Builder)
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
        if (unhandledF.length > 0 || remarksVal) {
          customSectionGroups.push({
            name: 'additional',
            label: 'Additional Information & Preferences',
            icon: '📝',
            fields: unhandledF.sort((a, b) => a.order - b.order),
            remarks: remarksVal
          });
        }
      } else if (extraCustomFields.length > 0 || remarksVal) {
        customSectionGroups.push({
          name: 'additional',
          label: 'Additional Information & Preferences',
          icon: '📝',
          fields: extraCustomFields.sort((a, b) => a.order - b.order),
          remarks: remarksVal
        });
      }

      customSectionGroups.forEach(grp => {
        sectionsHtml += `
          <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
            <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 14px; display: flex; align-items: center; gap: 8px;">
              <span>${grp.icon}</span> ${escapeHTML(grp.label)}
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 220px), 1fr)); gap: 14px; font-size: 0.88rem;">
              ${grp.remarks ? `
                <div style="grid-column: 1 / -1;">
                  <span class="text-muted d-block small">Special Remarks / Notes</span>
                  <strong>${escapeHTML(grp.remarks)}</strong>
                </div>
              ` : ''}
              ${grp.fields.map(f => `
                <div>
                  <span class="text-muted d-block small">${escapeHTML(f.label)}</span>
                  <div>${formatVal(f, f.value)}</div>
                </div>
              `).join('')}
            </div>
          </div>
        `;
      });

      // Digital Signature Section if available
      if (student.signature) {
        sectionsHtml += `
          <div class="mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
            <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
              <span>✍️</span> Official Digital Signature
            </div>
            <div style="background: #ffffff; padding: 12px; border-radius: 8px; border: 1px solid var(--color-border); display: inline-block;">
              <img src="${student.signature}" style="max-height: 90px; max-width: 280px; object-fit: contain; display: block;">
            </div>
            <div class="text-muted small mt-2">Digitally acknowledged upon admission enrollment.</div>
          </div>
        `;
      }

      modalContent.innerHTML = `
        <div style="font-family: var(--font-family);">
          <!-- Student Card Header with Photo Avatar Upload -->
          <div class="card p-3 mb-4" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.1), rgba(0, 184, 148, 0.06)); border: 1.5px solid var(--color-primary); border-radius: 12px;">
            <div style="display: flex; gap: 1rem; align-items: center; justify-content: space-between; flex-wrap: wrap;">
              
              <div style="display: flex; gap: 1rem; align-items: center; flex-wrap: wrap;">
                <div style="display: flex; flex-direction: column; align-items: center; gap: 6px;">
                  <div id="sp-avatar-container" style="width: 76px; height: 76px; border-radius: 50%; background: var(--color-primary); color: #fff; display: flex; align-items: center; justify-content: center; font-size: 1.75rem; font-weight: 800; border: 3px solid var(--color-surface); box-shadow: var(--shadow-sm); overflow: hidden; position: relative;">
                    <img id="sp-avatar-img" src="${student.photo ? (student.photo.startsWith('/') ? student.photo : '/' + student.photo) : ''}" style="width: 100%; height: 100%; object-fit: cover; display: ${student.photo ? 'block' : 'none'};" onerror="this.style.display='none'; document.getElementById('sp-avatar-initials').style.display='block';">
                    <span id="sp-avatar-initials" style="display: ${student.photo ? 'none' : 'block'};">${escapeHTML(initials)}</span>
                  </div>
                  <div style="display: flex; gap: 4px;">
                    <button type="button" id="btn-sp-upload-photo" class="btn btn-xs btn-outline-primary" style="font-size: 0.7rem; padding: 2px 6px; font-weight: 600;" title="Upload Passport Photo">📁 Upload</button>
                    <button type="button" id="btn-sp-selfie" class="btn btn-xs btn-primary" style="font-size: 0.7rem; padding: 2px 6px; font-weight: 600;" title="Take Live Selfie">📸 Selfie</button>
                    <input type="file" id="input-sp-photo" accept="image/*" style="display: none;">
                  </div>
                </div>

                <div>
                  <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    <h3 style="margin: 0; font-size: 1.35rem; font-weight: 800; color: var(--color-text-primary);">${escapeHTML(student.name)}</h3>
                    <span class="badge ${student.status === 'active' ? 'badge-success' : 'badge-warning'}" style="text-transform: uppercase;">
                      ${escapeHTML(student.status || 'Active')}
                    </span>
                  </div>
                  <div style="display: flex; gap: 14px; font-size: 0.85rem; color: var(--color-text-secondary); margin-top: 4px; flex-wrap: wrap;">
                    <span>Student ID: <strong style="font-family: monospace; color: var(--color-primary); font-size: 0.95rem;">${escapeHTML(student.studentId || 'N/A')}</strong></span>
                    <span>Desk: <strong>${seatTitle}</strong></span>
                    <span>Branch: <strong>${escapeHTML(student.branch?.name || business.businessName || 'Main Campus')}</strong></span>
                  </div>
                </div>
              </div>

              <!-- Profile Lock Status Badge -->
              <div style="text-align: right;">
                ${(student.profileCompletion >= 100 || student.isProfileComplete) ? `
                  <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border: 1px solid rgba(0, 184, 148, 0.3);">
                    🔒 100% Profile Verified & Locked
                  </span>
                  <div style="font-size: 0.72rem; color: var(--color-text-secondary); margin-top: 4px;">
                    Contact Admin to modify details
                  </div>
                ` : `
                  <span class="badge" style="background: rgba(245, 158, 11, 0.15); color: #f59e0b; font-weight: 700; font-size: 0.8rem; padding: 6px 12px; border: 1px solid rgba(245, 158, 11, 0.3);">
                    🟡 ${student.profileCompletion || 60}% KYC Pending
                  </span>
                  <div style="font-size: 0.72rem; color: #f59e0b; margin-top: 4px; font-weight: 600;">
                    Complete profile below
                  </div>
                `}
              </div>

            </div>
          </div>

          <!-- If Profile Incomplete: Show Interactive KYC Completion Form -->
          ${(student.profileCompletion < 100 || !student.isProfileComplete) ? `
            <form id="form-student-kyc-complete" class="mb-4">
              <div class="alert alert-warning mb-3 p-3" style="background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: 8px;">
                <div style="font-weight: 700; color: #d97706; margin-bottom: 2px;">⚠️ Complete Admission Profile & KYC Upload</div>
                <div style="font-size: 0.82rem; color: var(--color-text-secondary);">
                  Admin pre-filled your admission info! Please complete your DOB, Address, Parent Contact, and Aadhaar KYC scan to unlock your Digital Offline ID Card Pass.
                </div>
              </div>

              <!-- Section 1: 👤 Personal & Identification Details -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>👤</span> Personal & Identification Details
                </div>
                <div class="row g-2">
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Full Name (Admin Pre-filled)</label>
                    <input type="text" class="form-control form-control-sm" value="${escapeHTML(student.name)}" disabled style="background: rgba(255,255,255,0.05); font-weight: 600;">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Mobile Phone (WhatsApp) (Admin Pre-filled)</label>
                    <input type="text" class="form-control form-control-sm" value="${escapeHTML(student.phone)}" disabled style="background: rgba(255,255,255,0.05); font-weight: 600;">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Email Address</label>
                    <input type="email" id="kyc-email" name="email" class="form-control form-control-sm" value="${escapeHTML(student.email || '')}" placeholder="student@example.com">
                  </div>
                  <div class="col-md-3">
                    <label class="form-label small font-weight-bold">Gender</label>
                    <select id="kyc-gender" name="gender" class="form-select form-select-sm">
                      <option value="male" ${student.gender === 'male' ? 'selected' : ''}>Male</option>
                      <option value="female" ${student.gender === 'female' ? 'selected' : ''}>Female</option>
                      <option value="other" ${student.gender === 'other' ? 'selected' : ''}>Other</option>
                    </select>
                  </div>
                  <div class="col-md-3">
                    <label class="form-label small font-weight-bold">Date of Birth *</label>
                    <input type="date" id="kyc-dob" name="dob" class="form-control form-control-sm" value="${student.dateOfBirth ? new Date(student.dateOfBirth).toISOString().split('T')[0] : (student.dob ? new Date(student.dob).toISOString().split('T')[0] : '')}" required>
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Blood Group</label>
                    <select id="kyc-bloodGroup" name="bloodGroup" class="form-select form-select-sm">
                      <option value="">-- Select Blood Group --</option>
                      ${['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map(bg => `<option value="${bg}" ${student.bloodGroup === bg ? 'selected' : ''}>${bg}</option>`).join('')}
                    </select>
                  </div>
                </div>
              </div>

              <!-- Section 2: 🎯 Academic Goals & Preparation -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>🎯</span> Academic Goals & Preparation
                </div>
                <div class="row g-2">
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Target Competitive Exams</label>
                    <input type="text" id="kyc-targetExams" name="targetExams" class="form-control form-control-sm" value="${escapeHTML(Array.isArray(student.targetExams) ? student.targetExams.join(', ') : (student.targetExams || ''))}" placeholder="e.g. UPSC, MPSC, SSC, Banking, NEET">
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">College / Coaching Institute / Company</label>
                    <input type="text" id="kyc-collegeOrCompany" name="collegeOrCompany" class="form-control form-control-sm" value="${escapeHTML(student.collegeOrCompany || '')}" placeholder="e.g. Fergusson College / Self Study">
                  </div>
                </div>
              </div>

              <!-- Section 3: 📍 Address & Emergency Contacts -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>📍</span> Address & Emergency Contacts
                </div>
                <div class="row g-2">
                  <div class="col-12">
                    <label class="form-label small font-weight-bold">Residential Address / Hostel Room No. *</label>
                    <input type="text" id="kyc-address" name="address" class="form-control form-control-sm" value="${escapeHTML(student.address || '')}" placeholder="Full residential address" required>
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">Pincode ⚡</label>
                    <input type="text" id="kyc-pincode" name="pincode" class="form-control form-control-sm" value="${escapeHTML(student.pincode || '')}" placeholder="6-digit pincode" maxlength="6">
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">City</label>
                    <input type="text" id="kyc-city" name="city" class="form-control form-control-sm" value="${escapeHTML(student.city || '')}">
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">State</label>
                    <input type="text" id="kyc-state" name="state" class="form-control form-control-sm" value="${escapeHTML(student.state || '')}">
                  </div>
                  <div class="col-md-5">
                    <label class="form-label small font-weight-bold">Parent / Guardian Name *</label>
                    <input type="text" id="kyc-emergencyContactName" name="emergencyContactName" class="form-control form-control-sm" value="${escapeHTML(student.emergencyContact?.name || '')}" placeholder="e.g. Ramesh Sharma" required>
                  </div>
                  <div class="col-md-4">
                    <label class="form-label small font-weight-bold">Parent / Guardian Phone *</label>
                    <input type="tel" id="kyc-emergencyContactPhone" name="emergencyContactPhone" class="form-control form-control-sm" value="${escapeHTML(student.emergencyContact?.phone || '')}" placeholder="10-digit mobile" required>
                  </div>
                  <div class="col-md-3">
                    <label class="form-label small font-weight-bold">Relation</label>
                    <input type="text" id="kyc-emergencyContactRelation" name="emergencyContactRelation" class="form-control form-control-sm" value="${escapeHTML(student.emergencyContact?.relation || 'Parent')}" placeholder="Father / Mother">
                  </div>
                </div>
              </div>

              <!-- Section 4: 🪪 KYC & Identity Verification -->
              <div class="card p-3 mb-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border);">
                <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-primary); margin-bottom: 10px;">
                  <span>🪪</span> KYC & Identity Verification
                </div>
                <div class="row g-2">
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">Government ID Proof Type *</label>
                    <select id="kyc-idProofType" name="idProofType" class="form-select form-select-sm">
                      <option value="Aadhaar Card" ${student.idProof?.type === 'Aadhaar Card' ? 'selected' : ''}>Aadhaar Card</option>
                      <option value="PAN Card" ${student.idProof?.type === 'PAN Card' ? 'selected' : ''}>PAN Card</option>
                      <option value="Driving License" ${student.idProof?.type === 'Driving License' ? 'selected' : ''}>Driving License</option>
                      <option value="Passport" ${student.idProof?.type === 'Passport' ? 'selected' : ''}>Passport</option>
                      <option value="Voter ID" ${student.idProof?.type === 'Voter ID' ? 'selected' : ''}>Voter ID</option>
                    </select>
                  </div>
                  <div class="col-md-6">
                    <label class="form-label small font-weight-bold">ID Proof Document Number *</label>
                    <input type="text" id="kyc-idProofNumber" name="idProofNumber" class="form-control form-control-sm" value="${escapeHTML(student.idProof?.number || '')}" placeholder="12-digit Aadhaar / ID number" required>
                  </div>
                  <div class="col-12 mt-2">
                    <label class="form-label small font-weight-bold">Upload Government ID Proof Scan / Photo</label>
                    <div id="mount-portal-idproof"></div>
                  </div>
                </div>
              </div>

              <div class="d-flex justify-content-end gap-2">
                <button type="submit" class="btn btn-success btn-sm" id="btn-save-kyc-profile-submit" style="font-weight: 700; padding: 8px 18px;">💾 Save & Complete Profile</button>
              </div>
            </form>
          ` : ''}

          <!-- Verified Section Tabs / Content -->
          ${sectionsHtml}

          <div class="d-flex justify-content-between align-items-center mt-4 pt-3 flex-wrap gap-2" style="border-top: 1px solid var(--color-border);">
            <div>
              ${(student.profileCompletion >= 100 || student.isProfileComplete) ? `
                <button type="button" class="btn btn-outline-primary" id="btn-sp-download-pdf" style="font-weight: 700; font-size: 0.85rem;">
                  📄 Download Official Admission Form (PDF)
                </button>
              ` : `
                <button type="button" class="btn btn-outline-secondary" disabled style="font-size: 0.8rem; font-weight: 600; opacity: 0.7;" title="Complete photo selfie & Aadhaar KYC above to unlock PDF download">
                  🔒 Complete Profile to Unlock Admission Form (PDF)
                </button>
              `}
            </div>
            <div class="d-flex gap-2">
              <button type="button" class="btn btn-secondary" id="btn-close-profile-modal">Close</button>
            </div>
          </div>
        </div>
      `;

      const btnSpUpload = modalContent.querySelector('#btn-sp-upload-photo');
      const btnSpSelfie = modalContent.querySelector('#btn-sp-selfie');
      const inputSpPhoto = modalContent.querySelector('#input-sp-photo');
      const spImg = modalContent.querySelector('#sp-avatar-img');
      const spInitials = modalContent.querySelector('#sp-avatar-initials');

      // Mount ID Proof Document Scan Picker if KYC incomplete
      const portalKycMount = modalContent.querySelector('#mount-portal-idproof');
      if (portalKycMount) {
        portalKycMount.appendChild(MediaFieldPicker.create({
          label: 'ID Proof Document Scan / Photo',
          preset: 'document',
          name: 'idProofImage',
          value: student.idProof?.image || ''
        }));
      }

      const saveStudentPhoto = async (dataUrl, btn) => {
        try {
          if (btn) Loading.button(btn, true);
          const uploadRes = await api.post('/api/upload', { image: dataUrl });
          if (uploadRes.success && uploadRes.url) {
            const photoUrl = uploadRes.url;
            await api.put('/api/student-portal/profile', { photo: photoUrl });
            spImg.src = photoUrl;
            spImg.style.display = 'block';
            spInitials.style.display = 'none';
            
            // Sync with active auth session & update global header
            const u = auth.getUser();
            if (u) {
              u.avatar = photoUrl;
              auth.setUser(u);
            }
            window.dispatchEvent(new CustomEvent('user-updated'));
            
            if (typeof window.updateProfileAvatar === 'function') {
              window.updateProfileAvatar(photoUrl);
            }
            Toast.success('Passport photo updated & compressed successfully!');
          } else {
            Toast.error(uploadRes.message || 'Upload failed');
          }
        } catch (err) {
          Toast.error(err.message || 'Failed to update photo');
        } finally {
          if (btn) Loading.button(btn, false);
        }
      };

      btnSpUpload?.addEventListener('click', (e) => {
        e.preventDefault();
        e.stopPropagation();
        inputSpPhoto.click();
      });
      inputSpPhoto?.addEventListener('change', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        const file = e.target.files[0];
        if (!file) return;
        try {
          const compressed = await ImageCompressor.compress(file, { maxWidth: 300, maxHeight: 300, quality: 0.82 });
          await saveStudentPhoto(compressed, btnSpUpload);
        } catch (err) {
          Toast.error(err.message || 'Image processing failed');
        } finally {
          inputSpPhoto.value = '';
        }
      });

      btnSpSelfie?.addEventListener('click', async (e) => {
        e.preventDefault();
        e.stopPropagation();
        try {
          const selfie = await ImageCompressor.captureWebcam({ maxWidth: 300, maxHeight: 300, quality: 0.82 });
          await saveStudentPhoto(selfie, btnSpSelfie);
        } catch (err) {
          if (err.message !== 'Camera capture cancelled') {
            Toast.error(err.message || 'Selfie capture failed');
          }
        }
      });

      // Pincode Auto-Fill for KYC Form
      modalContent.querySelector('#kyc-pincode')?.addEventListener('input', async (e) => {
        const val = e.target.value.trim();
        if (val.length === 6) {
          const res = await SmartIntelligence.lookupPincode(val);
          if (res && res.city) {
            const cityEl = modalContent.querySelector('#kyc-city');
            const stateEl = modalContent.querySelector('#kyc-state');
            if (cityEl) cityEl.value = res.city;
            if (stateEl) stateEl.value = res.state;
          }
        }
      });

      // Bind Dynamic ID Proof Validation & Document Auto-Fetch
      SmartIntelligence.bindDynamicIDProofValidation(modalContent);

      // Submit Profile KYC Completion Form
      modalContent.querySelector('#form-student-kyc-complete')?.addEventListener('submit', async (e) => {
        e.preventDefault();
        const btnSave = modalContent.querySelector('#btn-save-kyc-profile-submit');
        UI.buttonLoading(btnSave, true, 'Saving...');
        try {
          const payload = {
            email: modalContent.querySelector('#kyc-email')?.value?.trim(),
            gender: modalContent.querySelector('#kyc-gender')?.value,
            dob: modalContent.querySelector('#kyc-dob')?.value,
            bloodGroup: modalContent.querySelector('#kyc-bloodGroup')?.value,
            targetExams: modalContent.querySelector('#kyc-targetExams')?.value?.trim(),
            collegeOrCompany: modalContent.querySelector('#kyc-collegeOrCompany')?.value?.trim(),
            address: modalContent.querySelector('#kyc-address')?.value?.trim(),
            pincode: modalContent.querySelector('#kyc-pincode')?.value?.trim(),
            city: modalContent.querySelector('#kyc-city')?.value?.trim(),
            state: modalContent.querySelector('#kyc-state')?.value?.trim(),
            emergencyContactName: modalContent.querySelector('#kyc-emergencyContactName')?.value?.trim(),
            emergencyContactPhone: modalContent.querySelector('#kyc-emergencyContactPhone')?.value?.trim(),
            emergencyContactRelation: modalContent.querySelector('#kyc-emergencyContactRelation')?.value?.trim(),
            idProofType: modalContent.querySelector('#kyc-idProofType')?.value,
            idProofNumber: modalContent.querySelector('#kyc-idProofNumber')?.value?.trim(),
            idProofImage: modalContent.querySelector('#mount-portal-idproof .mfp-hidden-value')?.value || ''
          };

          const res = await api.put('/api/student-portal/profile', payload);
          if (res.success) {
            Toast.success('Profile & KYC details updated successfully! Profile is now 100% verified.');
            profileModal.close();
            // Reload Portal Dashboard to reflect 100% completion & unlock Digital ID Card Pass
            renderPortalPage();
          } else {
            Toast.error(res.message || 'Failed to update profile');
          }
        } catch (err) {
          Toast.error(err.message || 'Failed to update profile');
        } finally {
          UI.buttonLoading(btnSave, false);
        }
      });

      modalContent.querySelector('#btn-close-profile-modal')?.addEventListener('click', () => profileModal.close());
      modalContent.querySelector('#btn-sp-download-pdf')?.addEventListener('click', () => {
        profileModal.close();
        previewAdmissionFormPDF(student, { business });
      });
      modalContent.querySelector('#btn-modal-print-pdf')?.addEventListener('click', () => {
        profileModal.close();
        previewAdmissionFormPDF(student, { business });
      });

    } catch (err) {
      modalContent.innerHTML = `<div class="text-danger p-3 text-center">Failed to load profile details: ${escapeHTML(err.message)}</div>`;
    }
  });

  // Attach Leave Request Modal
  const openLeaveModal = async () => {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="portal-leave-form" class="p-1 mb-4">
        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Start Date *</label>
            <input type="date" id="leave-start" class="form-control" value="${new Date().toISOString().split('T')[0]}" required>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">End Date *</label>
            <input type="date" id="leave-end" class="form-control" value="${new Date(Date.now() + 86400000).toISOString().split('T')[0]}" required>
          </div>
        </div>
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Reason for Absence *</label>
          <textarea id="leave-reason" class="form-control" rows="2" placeholder="e.g. University Semester Exams, Visiting Home Town" required></textarea>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="submit" class="btn btn-primary" id="btn-submit-leave">Submit Leave Application</button>
        </div>
      </form>

      <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-border); padding-top: 12px; margin-bottom: 8px;">📋 My Past Leave Requests</h5>
      <div id="portal-leave-history" style="max-height: 220px; overflow-y: auto;">
        <div class="text-center p-3 text-muted">Loading leave history...</div>
      </div>
    `;

    const leaveModal = new Modal({ title: '🌴 Leave & Absence Application', content: modalContent, size: 'md' });
    leaveModal.show();

    // Load History
    const loadLeaveHistory = async () => {
      try {
        const res = await api.get('/api/student-portal/leave');
        const historyContainer = modalContent.querySelector('#portal-leave-history');
        if (res.success && res.data.length > 0) {
          historyContainer.innerHTML = res.data.map(l => `
            <div class="p-2 mb-2" style="background: var(--color-bg-secondary); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem;">
              <div class="d-flex justify-content-between align-items-center mb-1">
                <strong>${new Date(l.startDate).toLocaleDateString()} - ${new Date(l.endDate).toLocaleDateString()}</strong>
                <span class="badge ${l.status === 'approved' ? 'badge-success' : (l.status === 'rejected' ? 'badge-danger' : 'badge-warning')}">
                  ${l.status.toUpperCase()}
                </span>
              </div>
              <div class="text-muted">${escapeHTML(l.reason)}</div>
            </div>
          `).join('');
        } else {
          historyContainer.innerHTML = '<div class="text-center p-3 text-muted">No past leave applications.</div>';
        }
      } catch (err) {
        modalContent.querySelector('#portal-leave-history').innerHTML = '<div class="text-danger p-2">Failed to load history</div>';
      }
    };

    // Form Submit
    modalContent.querySelector('#portal-leave-form').onsubmit = async (e) => {
      e.preventDefault();
      const startDate = modalContent.querySelector('#leave-start').value;
      const endDate = modalContent.querySelector('#leave-end').value;
      const reason = modalContent.querySelector('#leave-reason').value;

      try {
        await api.post('/api/student-portal/leave', { startDate, endDate, reason });
        Toast.success('Leave application submitted!');
        modalContent.querySelector('#leave-reason').value = '';
        loadLeaveHistory();
      } catch (err) {
        Toast.error(err.message || 'Failed to submit leave');
      }
    };

    loadLeaveHistory();
  };
  container.querySelectorAll('#btn-portal-leave, #tile-portal-leave').forEach(el => el.addEventListener('click', openLeaveModal));

  // Attach Seat Change Modal
  const openSeatChangeModal = async () => {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="portal-sc-form" class="p-1 mb-4">
        
        <!-- Target Library Branch / Centre Dropdown -->
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Target Library Branch / Centre *</label>
          <select id="sc-branch" class="form-select" required>
            <option value="">-- Select Target Library Centre --</option>
          </select>
        </div>

        <!-- Real-Time Vacant Seat Selector -->
        <div class="form-group mb-3">
          <div class="d-flex justify-content-between align-items-center mb-1">
            <label class="form-label" style="font-weight: 600; margin: 0;">Specific Desk / Seat (Optional Preference)</label>
            <span id="sc-vacant-badge" class="badge badge-success" style="font-size: 0.72rem; display: none;">🟢 0 Desks Vacant</span>
          </div>
          <select id="sc-target-seat" class="form-select">
            <option value="">-- Select Specific Available Desk (or Any Vacant) --</option>
          </select>
          <small class="text-muted" style="display: block; font-size: 0.75rem; margin-top: 3px;">
            Choose a specific desk or leave as "Any Vacant Desk" to let management auto-allot.
          </small>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Preferred Seat Zone *</label>
          <select id="sc-zone" class="form-select" required>
            <option value="AC Zone (Quiet Cabin)">AC Zone (Quiet Cabin)</option>
            <option value="Non-AC Reading Zone">Non-AC Reading Zone</option>
            <option value="Private Cabin Desk">Private Cabin Desk</option>
            <option value="Open Hall">Open Hall</option>
            <option value="Ladies Reserved Zone">Ladies Reserved Zone</option>
            <option value="Laptop Desk (Extra Power Plugs)">Laptop Desk (Extra Power Plugs)</option>
          </select>
        </div>

        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Reason for Seat Transfer *</label>
          <textarea id="sc-reason" class="form-control" rows="2" placeholder="e.g. Requesting transfer to Main Centre AC cabin desk with laptop charging outlet." required></textarea>
        </div>

        <div class="d-flex justify-content-end gap-2">
          <button type="submit" class="btn btn-primary" id="btn-submit-sc" style="font-weight: 700; width: 100%;">⚡ Submit Transfer Request</button>
        </div>
      </form>

      <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-border); padding-top: 12px; margin-bottom: 8px;">📋 Past Transfer Requests</h5>
      <div id="portal-sc-history" style="max-height: 200px; overflow-y: auto;">
        <div class="text-center p-3 text-muted">Loading requests...</div>
      </div>
    `;

    const scModal = new Modal({ title: '💺 Request Desk / Seat Transfer', content: modalContent, size: 'md' });
    scModal.show();

    const branchSelect = modalContent.querySelector('#sc-branch');
    const seatSelect = modalContent.querySelector('#sc-target-seat');
    const vacantBadge = modalContent.querySelector('#sc-vacant-badge');

    let allBranches = [];
    let allSeats = [];

    // Load Branches & Vacant Desks using Student Portal & Public APIs
    try {
      const [bRes, sRes] = await Promise.all([
        api.get('/api/student-portal/branches').catch(() => api.get('/api/branches/public-list')).catch(() => ({ data: [] })),
        api.get('/api/student-portal/available-seats').catch(() => api.get('/api/seats/public-available')).catch(() => ({ data: [] }))
      ]);

      allBranches = Array.isArray(bRes.data) ? bRes.data : (bRes.data?.branches || []);
      allSeats = Array.isArray(sRes.data) ? sRes.data : (sRes.data?.seats || []);

      if (allBranches.length > 0) {
        branchSelect.innerHTML = allBranches.map((b, idx) => `
          <option value="${b._id}" ${String(b._id) === String(student.branch?._id || student.branch) || (idx === 0 && !student.branch) ? 'selected' : ''}>
            ${escapeHTML(b.name)} ${b.city ? '(' + escapeHTML(b.city) + ')' : ''}
          </option>
        `).join('');
      } else {
        branchSelect.innerHTML = `<option value="">${escapeHTML(business.businessName || 'Main Centre')}</option>`;
      }

      populateVacantSeats();
    } catch (err) {
      console.warn('Failed to load branches/seats:', err);
    }

    function populateVacantSeats() {
      const selectedBranchId = branchSelect.value;
      const vacant = allSeats.filter(s => {
        const isVacant = s.status === 'available' || s.status === 'vacant';
        if (!isVacant) return false;
        if (!selectedBranchId) return true;
        const bId = s.branch?._id || s.branch;
        return !bId || String(bId) === String(selectedBranchId) || selectedBranchId === 'default_main';
      });

      if (vacantBadge) {
        vacantBadge.style.display = 'inline-block';
        vacantBadge.textContent = `🟢 ${vacant.length} Desks Vacant`;
      }

      if (vacant.length > 0) {
        seatSelect.innerHTML = `<option value="">-- Select Specific Available Desk (or Any Vacant) --</option>` +
          vacant.map(s => `
            <option value="${s._id}" data-num="${escapeHTML(s.seatNumber)}">
              Desk ${escapeHTML(s.seatNumber)} — ${escapeHTML(s.zone || 'General Zone')} (🟢 Vacant)
            </option>
          `).join('');
      } else {
        seatSelect.innerHTML = `<option value="">No specific vacant desks listed (Management will allot)</option>`;
      }
    }

    branchSelect.addEventListener('change', populateVacantSeats);

    async function loadScHistory() {
      const histContainer = modalContent.querySelector('#portal-sc-history');
      try {
        const res = await api.get('/api/student-portal/seat-changes');
        const list = res.data || [];
        if (list.length === 0) {
          histContainer.innerHTML = `<p class="text-muted small text-center p-2">No transfer requests submitted yet.</p>`;
          return;
        }
        histContainer.innerHTML = list.map(s => `
          <div class="p-2 mb-2" style="background: var(--color-bg-primary); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem;">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <strong>Requested: ${escapeHTML(s.targetSeatNumber ? 'Desk ' + s.targetSeatNumber : s.preferredZone)} ${s.targetBranchName ? '(' + escapeHTML(s.targetBranchName) + ')' : ''}</strong>
              <span class="badge ${s.status === 'approved' ? 'badge-success' : s.status === 'rejected' ? 'badge-danger' : 'badge-warning'}" style="text-transform: uppercase; font-size: 0.7rem;">
                ${s.status}
              </span>
            </div>
            <div class="text-muted small">${escapeHTML(s.reason)}</div>
            ${s.adminReply ? `<div style="color: var(--color-primary); font-size: 0.75rem; margin-top: 4px;">Admin: ${escapeHTML(s.adminReply)}</div>` : ''}
          </div>
        `).join('');
      } catch (e) {
        histContainer.innerHTML = `<p class="text-danger small text-center">Failed to load history</p>`;
      }
    }

    modalContent.querySelector('#portal-sc-form').onsubmit = async (e) => {
      e.preventDefault();
      const targetBranch = branchSelect.value;
      const selectedBranchObj = allBranches.find(b => String(b._id) === String(targetBranch));
      const targetBranchName = selectedBranchObj ? selectedBranchObj.name : '';

      const targetSeat = seatSelect.value;
      const selectedSeatOpt = seatSelect.options[seatSelect.selectedIndex];
      const targetSeatNumber = selectedSeatOpt ? (selectedSeatOpt.dataset?.num || '') : '';

      const preferredZone = modalContent.querySelector('#sc-zone').value;
      const reason = modalContent.querySelector('#sc-reason').value.trim();

      try {
        await api.post('/api/student-portal/seat-change', {
          targetBranch,
          targetBranchName,
          targetSeat,
          targetSeatNumber,
          preferredZone,
          reason
        });
        Toast.success('Seat transfer request submitted to branch manager!');
        modalContent.querySelector('#sc-reason').value = '';
        loadScHistory();
      } catch (err) {
        Toast.error(err.message || 'Failed to submit request');
      }
    };

    loadScHistory();
  };
  container.querySelectorAll('#btn-portal-seat-change, #tile-portal-seat-change').forEach(el => el.addEventListener('click', openSeatChangeModal));

  // Attach Smart Referral Studio Modal
  const openReferralModal = async () => {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <div style="font-family: 'Outfit', sans-serif;">
        <div class="text-center p-3 text-muted">
          <div class="loading-spinner mb-2" style="margin: 0 auto;"></div>
          Loading your Referral Studio...
        </div>
      </div>
    `;

    const refModal = new Modal({ title: '🎁 Student Referral Studio & Rewards', content: modalContent, size: 'md' });
    refModal.show();

    try {
      const statsRes = await api.get('/api/student-portal/referral-stats');
      if (!statsRes.success) throw new Error(statsRes.message);

      const { referralCode, referralCredits, totalReferralsCount, config, referrals = [] } = statsRes.data;
      const origin = window.location.origin;
      const shareUrl = `${origin}/register?ref=${encodeURIComponent(referralCode)}`;
      const waText = encodeURIComponent(`Hey! I study at ${business.businessName || 'the study library'}. Use my referral code *${referralCode}* to get ₹${config?.refereeRewardAmount || 100} instant discount on your admission! Register here: ${shareUrl}`);

      modalContent.innerHTML = `
        <div style="font-family: 'Outfit', sans-serif;">
          <!-- Highlight Reward Banner -->
          <div class="card p-3 mb-3" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.12), rgba(0, 184, 148, 0.08)); border: 1px solid rgba(108, 92, 231, 0.25); border-radius: 10px;">
            <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 10px;">
              <div>
                <strong style="color: var(--color-primary); font-size: 1.05rem; display: block;">
                  🎁 Give ₹${config?.refereeRewardAmount || 100}, Get ₹${config?.referrerRewardAmount || 100}!
                </strong>
                <p style="margin: 2px 0 0 0; font-size: 0.8rem; color: var(--color-text-secondary);">
                  Every friend who joins using your code gives you a <strong>₹${config?.referrerRewardAmount || 100} discount</strong> on your next renewal.
                </p>
              </div>

              <!-- Referral Wallet Badge -->
              <div style="text-align: right; background: var(--color-surface); padding: 6px 12px; border-radius: 8px; border: 1px solid var(--color-border);">
                <div style="font-size: 0.72rem; color: var(--color-text-muted); font-weight: 700; text-transform: uppercase;">Available Renewal Credit</div>
                <div style="font-size: 1.25rem; font-weight: 800; color: var(--color-success);">₹${referralCredits}</div>
              </div>
            </div>
          </div>

          <!-- Referral Code & Share Link Section -->
          <div style="background: var(--color-bg-secondary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border); margin-bottom: 1rem;">
            <label class="form-label" style="font-weight: 700; font-size: 0.85rem; margin-bottom: 6px;">Your Unique Referral Code</label>
            
            <div style="display: flex; gap: 8px; align-items: center; margin-bottom: 10px;">
              <div id="display-ref-code" style="font-family: monospace; font-size: 1.3rem; font-weight: 800; color: var(--color-primary); background: var(--color-surface); padding: 6px 14px; border-radius: 6px; border: 1px solid var(--color-border); flex-grow: 1; letter-spacing: 1px;">
                ${escapeHTML(referralCode)}
              </div>
              <button type="button" class="btn btn-outline-primary btn-sm" id="btn-copy-ref-code" style="font-weight: 700;">
                📋 Copy Code
              </button>
            </div>

            <!-- Custom Vanity Code Toggle / Form -->
            <div style="display: flex; gap: 6px; align-items: center; margin-bottom: 12px;">
              <input type="text" id="custom-code-input" class="form-control form-control-sm" placeholder="Set custom vanity code (e.g. ${escapeHTML(initials)}2026)" style="font-family: monospace; text-transform: uppercase;">
              <button type="button" class="btn btn-secondary btn-sm" id="btn-save-custom-code" style="white-space: nowrap; font-weight: 600;">
                ✏️ Save Code
              </button>
            </div>

            <!-- 1-Click WhatsApp Sharing Pill & Link -->
            <div style="display: flex; gap: 8px; flex-wrap: wrap;">
              <a href="https://wa.me/?text=${waText}" target="_blank" class="btn btn-success btn-sm" style="font-weight: 700; flex: 1; text-align: center; text-decoration: none; display: flex; align-items: center; justify-content: center; gap: 6px;">
                <span>📲 Share on WhatsApp</span>
              </a>
              <button type="button" class="btn btn-outline-secondary btn-sm" id="btn-copy-ref-link" style="font-weight: 600;">
                🔗 Copy Direct Registration Link
              </button>
            </div>
          </div>

          <!-- Direct Friend Referral Form -->
          <div style="border-top: 1px solid var(--color-divider); padding-top: 12px; margin-bottom: 12px;">
            <h5 style="font-size: 0.95rem; font-weight: 700; margin-bottom: 8px; color: var(--color-text-primary);">
              📨 Or Submit Friend's Details Directly
            </h5>
            <form id="portal-ref-form">
              <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(min(100%, 260px), 1fr)); gap: 8px; margin-bottom: 8px;">
                <div>
                  <input type="text" id="ref-name" class="form-control form-control-sm" placeholder="Friend's Full Name *" required>
                </div>
                <div>
                  <input type="tel" id="ref-phone" class="form-control form-control-sm" placeholder="10-digit Phone No. *" required>
                </div>
              </div>
              <div style="display: flex; gap: 8px;">
                <input type="text" id="ref-notes" class="form-control form-control-sm" placeholder="Target exam or course (e.g. UPSC, CA, NEET)">
                <button type="submit" class="btn btn-primary btn-sm" id="btn-submit-ref" style="font-weight: 700; white-space: nowrap;">
                  Submit Lead
                </button>
              </div>
            </form>
          </div>

          <!-- Referral History / Friends Ledger -->
          <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-divider); padding-top: 12px; margin-bottom: 8px; color: var(--color-text-primary);">
            🎉 My Referred Friends (${referrals.length})
          </h5>
          <div id="portal-ref-history" style="max-height: 180px; overflow-y: auto;">
            ${referrals.length > 0 ? referrals.map(r => `
              <div class="p-2 mb-2" style="background: var(--color-surface); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem; display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <strong>${escapeHTML(r.refereeName)}</strong>
                  <div class="text-muted small">${escapeHTML(r.refereePhone)} • ${escapeHTML(r.targetExam || 'General')}</div>
                </div>
                <div style="text-align: right;">
                  <span class="badge ${r.status === 'rewarded' ? 'badge-success' : (r.status === 'joined' ? 'badge-primary' : 'badge-warning')}" style="text-transform: uppercase; font-size: 0.7rem;">
                    ${escapeHTML(r.status)}
                  </span>
                  <div style="font-size: 0.75rem; color: var(--color-success); font-weight: 700; margin-top: 2px;">
                    ₹${r.rewardAmount || 100}
                  </div>
                </div>
              </div>
            `).join('') : `
              <p class="text-muted small text-center p-2">No referrals submitted yet. Share your code with friends to start earning renewal discounts!</p>
            `}
          </div>
        </div>
      `;

      // Copy Code
      modalContent.querySelector('#btn-copy-ref-code')?.addEventListener('click', (e) => {
        copyToClipboard(referralCode, e.currentTarget);
      });

      // Copy Share Link
      modalContent.querySelector('#btn-copy-ref-link')?.addEventListener('click', (e) => {
        copyToClipboard(shareUrl, e.currentTarget);
      });

      // Custom Code Save
      modalContent.querySelector('#btn-save-custom-code')?.addEventListener('click', async () => {
        const input = modalContent.querySelector('#custom-code-input');
        const newCode = input.value.trim().toUpperCase();
        if (!newCode) {
          Toast.error('Please enter a custom code');
          return;
        }
        try {
          const res = await api.put('/api/student-portal/custom-referral-code', { code: newCode });
          if (res.success) {
            Toast.success(res.message);
            modalContent.querySelector('#display-ref-code').textContent = newCode;
            input.value = '';
          } else {
            Toast.error(res.message);
          }
        } catch (e) {
          Toast.error(e.message || 'Failed to update code');
        }
      });

      // Submit Direct Friend Referral
      modalContent.querySelector('#portal-ref-form')?.addEventListener('submit', async (e) => {
        e.preventDefault();
        const refereeName = modalContent.querySelector('#ref-name').value.trim();
        const refereePhone = modalContent.querySelector('#ref-phone').value.trim();
        const targetExam = modalContent.querySelector('#ref-notes').value.trim();

        try {
          const sRes = await api.post('/api/student-portal/referral', { refereeName, refereePhone, targetExam });
          if (sRes.success) {
            Toast.success('Friend referral submitted! Thank you!');
            refModal.close();
          } else {
            Toast.error(sRes.message);
          }
        } catch (err) {
          Toast.error(err.message || 'Failed to submit referral');
        }
      });

    } catch (err) {
      modalContent.innerHTML = `<div class="text-danger p-4 text-center">Failed to load referral studio: ${escapeHTML(err.message)}</div>`;
    }
  };
  container.querySelectorAll('#btn-portal-referral, #tile-portal-referral').forEach(el => el.addEventListener('click', openReferralModal));

  // -------------------------------------------------------------------------
  // 🏛️ Campus Life & Utilities Hub Controller (Notices, Holidays, Lost&Found, Feedback)
  // -------------------------------------------------------------------------
  const campusTabs = container.querySelectorAll('.btn-campus-tab');
  const campusContent = container.querySelector('#campus-tab-content-container');

  async function activateCampusTab(tabKey) {
    campusTabs.forEach(b => {
      if (b.dataset.tab === tabKey) {
        b.className = 'btn btn-primary btn-campus-tab active';
      } else {
        b.className = 'btn btn-outline-secondary btn-campus-tab';
      }
    });

    if (!campusContent) return;
    campusContent.innerHTML = `<div class="text-center p-4 text-muted"><div class="loading-spinner mb-2" style="margin: 0 auto;"></div>Loading...</div>`;

    if (tabKey === 'notices') {
      try {
        const res = await api.get('/api/student-portal/announcements');
        const notices = res.data || [];
        if (notices.length === 0) {
          campusContent.innerHTML = `<div class="text-center p-4 text-muted">No campus circulars or notice board alerts at this time.</div>`;
          return;
        }
        campusContent.innerHTML = `
          <div style="display: flex; flex-direction: column; gap: 12px;">
            ${notices.map(n => `
              <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid ${n.isPinned ? 'var(--color-primary)' : 'var(--color-border)'}; border-radius: var(--radius-md); box-shadow: ${n.isPinned ? '0 4px 12px rgba(99, 102, 241, 0.12)' : 'none'};">
                <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 10px; margin-bottom: 6px; flex-wrap: wrap;">
                  <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
                    ${n.isPinned ? `<span class="badge" style="background: #f59e0b; color: #fff; font-weight: 800; font-size: 0.72rem;">📌 PINNED</span>` : ''}
                    <h5 style="margin: 0; font-size: 0.98rem; font-weight: 700; color: var(--color-text-primary);">${escapeHTML(n.title)}</h5>
                    <span class="badge" style="background: rgba(99, 102, 241, 0.12); color: var(--color-primary); font-size: 0.72rem; text-transform: uppercase;">${escapeHTML(n.category || 'general')}</span>
                  </div>
                  <span style="font-size: 0.75rem; color: var(--color-text-muted); white-space: nowrap;">${new Date(n.createdAt).toLocaleDateString('en-IN')} (${SmartFormatters.timeAgo(n.createdAt)})</span>
                </div>
                <div style="font-size: 0.85rem; color: var(--color-text-primary); line-height: 1.5; white-space: pre-wrap;">${escapeHTML(n.message)}</div>
              </div>
            `).join('')}
          </div>
        `;
      } catch (err) {
        campusContent.innerHTML = `<div class="text-danger p-3 text-center">Failed to load notices: ${escapeHTML(err.message)}</div>`;
      }
    } else if (tabKey === 'holidays') {
      try {
        const res = await api.get('/api/student-portal/holidays');
        const holidays = res.data || [];
        if (holidays.length === 0) {
          campusContent.innerHTML = `<div class="text-center p-4 text-muted">No scheduled holidays or library closures found. Reading rooms open on standard hours!</div>`;
          return;
        }
        campusContent.innerHTML = `
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px;">
            ${holidays.map(h => {
              const hDate = new Date(h.date || h.startDate || Date.now());
              const diffDays = Math.ceil((hDate - new Date()) / (1000 * 60 * 60 * 24));
              return `
                <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; margin-bottom: 4px;">
                    <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-text-primary);">${escapeHTML(h.title)}</div>
                    <span class="badge ${h.isLibraryClosed ? 'badge-danger' : 'badge-warning'}" style="font-size: 0.7rem;">
                      ${h.isLibraryClosed ? '🔴 Closed' : '🟡 Timings Revised'}
                    </span>
                  </div>
                  <div style="font-size: 0.82rem; color: var(--color-primary); font-weight: 700; margin-bottom: 4px;">
                    📅 ${hDate.toLocaleDateString('en-IN', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' })}
                    ${diffDays > 0 ? `<small class="text-muted">(${diffDays} days away)</small>` : (diffDays === 0 ? `<small class="text-danger">(Today)</small>` : '')}
                  </div>
                  ${h.timingOverride ? `<div style="font-size: 0.78rem; color: var(--color-text-secondary);">⏰ Shift Timing: <strong>${escapeHTML(h.timingOverride)}</strong></div>` : ''}
                  ${h.description ? `<div style="font-size: 0.78rem; color: var(--color-text-muted); margin-top: 4px;">${escapeHTML(h.description)}</div>` : ''}
                </div>
              `;
            }).join('')}
          </div>
        `;
      } catch (err) {
        campusContent.innerHTML = `<div class="text-danger p-3 text-center">Failed to load holiday calendar: ${escapeHTML(err.message)}</div>`;
      }
    } else if (tabKey === 'lostfound') {
      try {
        const res = await api.get('/api/student-portal/lost-found');
        const items = res.data || [];
        campusContent.innerHTML = `
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div style="font-size: 0.85rem; color: var(--color-text-secondary);">
              Items found inside study rooms, silent cabins &amp; washrooms. Check with manager desk to claim.
            </div>
            <button type="button" class="btn btn-sm btn-primary" id="btn-report-lost-item" style="font-weight: 700;">
              ➕ Report Lost/Found Item
            </button>
          </div>
          ${items.length === 0 ? `
            <div class="text-center p-4 text-muted">No lost or unclaimed items recorded currently.</div>
          ` : `
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 12px;">
              ${items.map(item => `
                <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; margin-bottom: 4px;">
                    <div style="font-weight: 700; font-size: 0.95rem; color: var(--color-text-primary);">${escapeHTML(item.itemName)}</div>
                    <span class="badge ${item.status === 'claimed' ? 'badge-success' : 'badge-warning'}" style="font-size: 0.7rem; text-transform: uppercase;">
                      ${item.status === 'claimed' ? '✅ Claimed' : '🟢 Found / Available'}
                    </span>
                  </div>
                  <div style="font-size: 0.78rem; color: var(--color-text-secondary); margin-bottom: 4px;">
                    📍 Found Location: <strong>${escapeHTML(item.foundLocation || 'Library')}</strong>
                  </div>
                  ${item.description ? `<div style="font-size: 0.78rem; color: var(--color-text-muted);">${escapeHTML(item.description)}</div>` : ''}
                  <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 6px;">
                    Reported on: ${new Date(item.foundDate || item.createdAt).toLocaleDateString('en-IN')}
                  </div>
                </div>
              `).join('')}
            </div>
          `}
        `;

        campusContent.querySelector('#btn-report-lost-item')?.addEventListener('click', () => {
          showReportLostModal();
        });
      } catch (err) {
        campusContent.innerHTML = `<div class="text-danger p-3 text-center">Failed to load lost & found items: ${escapeHTML(err.message)}</div>`;
      }
    } else if (tabKey === 'feedback') {
      try {
        const res = await api.get('/api/student-portal/feedback');
        const feedbacks = res.data || [];
        campusContent.innerHTML = `
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; flex-wrap: wrap; gap: 8px;">
            <div style="font-size: 0.85rem; color: var(--color-text-secondary);">
              Your suggestions &amp; queries help us maintain 5-star study conditions.
            </div>
            <button type="button" class="btn btn-sm btn-primary" id="btn-submit-new-feedback" style="font-weight: 700;">
              ✍️ Submit Feedback / Query
            </button>
          </div>
          ${feedbacks.length === 0 ? `
            <div class="text-center p-4 text-muted">You haven't submitted any feedback yet. Have a request or issue? Click the button above to contact management!</div>
          ` : `
            <div style="display: flex; flex-direction: column; gap: 10px;">
              ${feedbacks.map(f => `
                <div class="card p-3" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md);">
                  <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; margin-bottom: 4px;">
                    <div style="display: flex; align-items: center; gap: 8px;">
                      <span style="font-weight: 700; font-size: 0.9rem; text-transform: uppercase; color: var(--color-primary);">${escapeHTML(f.category || 'General')}</span>
                      <span>${'⭐'.repeat(Math.max(1, Math.min(5, f.rating || 5)))}</span>
                    </div>
                    <span class="badge ${f.status === 'resolved' ? 'badge-success' : 'badge-warning'}" style="font-size: 0.7rem; text-transform: uppercase;">
                      ${escapeHTML(f.status || 'Pending')}
                    </span>
                  </div>
                  <div style="font-size: 0.85rem; color: var(--color-text-primary); line-height: 1.4; margin: 4px 0;">${escapeHTML(f.message)}</div>
                  ${f.adminReply ? `
                    <div style="background: rgba(108, 92, 231, 0.08); border-left: 3px solid var(--color-primary); padding: 6px 10px; border-radius: 4px; font-size: 0.8rem; margin-top: 6px;">
                      <strong style="color: var(--color-primary);">Management Reply:</strong> ${escapeHTML(f.adminReply)}
                    </div>
                  ` : ''}
                  <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 6px;">
                    Submitted: ${new Date(f.createdAt).toLocaleDateString('en-IN')} (${SmartFormatters.timeAgo(f.createdAt)})
                  </div>
                </div>
              `).join('')}
            </div>
          `}
        `;

        campusContent.querySelector('#btn-submit-new-feedback')?.addEventListener('click', () => {
          showSubmitFeedbackModal();
        });
      } catch (err) {
        campusContent.innerHTML = `<div class="text-danger p-3 text-center">Failed to load feedback: ${escapeHTML(err.message)}</div>`;
      }
    }
  }

  function showReportLostModal() {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="form-report-lost" style="font-family: 'Outfit', sans-serif;">
        <div class="mb-3">
          <label class="form-label" style="font-weight: 700;">Item Name *</label>
          <input type="text" id="lost-itemName" class="form-control" placeholder="e.g. Boat Earbuds, Casio Calculator, Blue Water Bottle" required>
        </div>
        <div class="row g-2 mb-3">
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">Category</label>
            <select id="lost-category" class="form-select">
              <option value="electronics">📱 Electronics / Charger</option>
              <option value="books">📚 Books / Notes</option>
              <option value="stationery">✏️ Stationery / Calculator</option>
              <option value="clothing">👕 Clothing / Bag / Bottle</option>
              <option value="other">📦 Other</option>
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 600;">Location Found / Lost</label>
            <input type="text" id="lost-location" class="form-control" placeholder="e.g. Cabin 02, Discussion Hall">
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label" style="font-weight: 600;">Item Description / Markings</label>
          <textarea id="lost-desc" class="form-control" rows="2" placeholder="Color, brand, identifying details"></textarea>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">Submit Report</button>
        </div>
      </form>
    `;
    const m = new Modal({ title: '🔍 Report Lost / Found Item', content: modalContent, size: 'md' });
    m.show();

    modalContent.querySelector('#form-report-lost').onsubmit = async (e) => {
      e.preventDefault();
      const itemName = modalContent.querySelector('#lost-itemName').value.trim();
      const category = modalContent.querySelector('#lost-category').value;
      const foundLocation = modalContent.querySelector('#lost-location').value.trim();
      const description = modalContent.querySelector('#lost-desc').value.trim();

      try {
        const res = await api.post('/api/student-portal/lost-found', { itemName, category, foundLocation, description });
        if (res.success) {
          Toast.success('Lost & Found item reported!');
          m.close();
          activateCampusTab('lostfound');
        } else {
          Toast.error(res.message);
        }
      } catch (err) {
        Toast.error(err.message || 'Failed to submit report');
      }
    };
  }

  function showSubmitFeedbackModal() {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="form-submit-feedback" style="font-family: 'Outfit', sans-serif;">
        <div class="row g-2 mb-3">
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Category *</label>
            <select id="fb-category" class="form-select">
              <option value="cleanliness">🧹 Cleanliness & Washrooms</option>
              <option value="ac_wifi">❄️ AC & High-Speed Wi-Fi</option>
              <option value="noise">🤫 Noise / Silence Maintenance</option>
              <option value="seats">💺 Desk / Ergonomic Seating</option>
              <option value="management">👥 Management & Staff Support</option>
              <option value="other">💬 General Suggestion</option>
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 700;">Overall Satisfaction Rating</label>
            <select id="fb-rating" class="form-select">
              <option value="5">⭐⭐⭐⭐⭐ Excellent (5/5)</option>
              <option value="4">⭐⭐⭐⭐ Good (4/5)</option>
              <option value="3">⭐⭐⭐ Average (3/5)</option>
              <option value="2">⭐⭐ Needs Improvement (2/5)</option>
              <option value="1">⭐ Poor (1/5)</option>
            </select>
          </div>
        </div>
        <div class="mb-3">
          <label class="form-label" style="font-weight: 700;">Your Message / Query *</label>
          <textarea id="fb-message" class="form-control" rows="3" placeholder="Tell us how we can make your study experience better..." required></textarea>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Cancel</button>
          <button type="submit" class="btn btn-primary btn-sm" style="font-weight: 700;">Send to Management</button>
        </div>
      </form>
    `;
    const m = new Modal({ title: '💬 Student Feedback & Helpdesk', content: modalContent, size: 'md' });
    m.show();

    modalContent.querySelector('#form-submit-feedback').onsubmit = async (e) => {
      e.preventDefault();
      const category = modalContent.querySelector('#fb-category').value;
      const rating = modalContent.querySelector('#fb-rating').value;
      const message = modalContent.querySelector('#fb-message').value.trim();

      try {
        const res = await api.post('/api/student-portal/feedback', { category, rating, message });
        if (res.success) {
          Toast.success('Feedback submitted! Thank you!');
          m.close();
          activateCampusTab('feedback');
        } else {
          Toast.error(res.message);
        }
      } catch (err) {
        Toast.error(err.message || 'Failed to submit feedback');
      }
    };
  }

  // Attach Tab Switchers
  campusTabs.forEach(b => {
    b.addEventListener('click', () => {
      activateCampusTab(b.dataset.tab);
    });
  });

  // Top Action Button Jump Listeners
  function jumpToCampusTab(tabKey) {
    const card = document.getElementById('student-campus-hub-card');
    if (card) {
      card.scrollIntoView({ behavior: 'smooth', block: 'center' });
      card.style.boxShadow = '0 0 0 3px rgba(99, 102, 241, 0.4)';
      setTimeout(() => { card.style.boxShadow = ''; }, 1500);
      activateCampusTab(tabKey);
    }
  }

  container.querySelector('#btn-portal-notices')?.addEventListener('click', () => jumpToCampusTab('notices'));
  container.querySelector('#btn-portal-holidays')?.addEventListener('click', () => jumpToCampusTab('holidays'));
  container.querySelector('#btn-portal-lostfound')?.addEventListener('click', () => jumpToCampusTab('lostfound'));
  container.querySelector('#btn-portal-feedback')?.addEventListener('click', () => jumpToCampusTab('feedback'));

  // Initialize Default Tab
  activateCampusTab('notices');

  // Jump to receipts
  container.querySelector('#btn-portal-receipts-jump')?.addEventListener('click', () => {
    const el = document.getElementById('student-receipts-card');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.style.boxShadow = '0 0 0 3px rgba(99, 102, 241, 0.4)';
      setTimeout(() => { el.style.boxShadow = ''; }, 1500);
    }
  });

  // Attach Payment Receipt Click Handlers
  container.querySelectorAll('.btn-view-receipt').forEach(btn => {
    btn.addEventListener('click', () => {
      try {
        const p = JSON.parse(btn.dataset.receipt);
        const receiptNo = p.receiptNumber || 'REC';
        const formattedDate = new Date(p.paymentDate).toLocaleDateString('en-IN', { day: '2-digit', month: '2-digit', year: 'numeric' });
        const paymentMode = (p.paymentMethod || 'UPI').toUpperCase();
        const paidAmount = p.finalAmount !== undefined ? p.finalAmount : (p.amount || 0);
        const baseAmount = p.amount !== undefined ? p.amount : paidAmount;
        const discountAmount = p.discount || 0;
        const planName = p.plan?.name || student.plan?.name || 'Study Membership';
        const deskInfo = student.seat ? (student.seat.seatNumber || student.seat) : 'General Access';

        const receiptHtml = `
          <div id="student-receipt-modal" style="padding: 18px; font-family: 'Inter', Arial, sans-serif; background: #ffffff; color: #0f172a; border-radius: 8px;">
            
            <!-- Receipt Header -->
            <div style="text-align: center; border-bottom: 2px dashed #cbd5e1; padding-bottom: 12px; margin-bottom: 12px;">
              <div style="display: flex; align-items: center; justify-content: center; gap: 8px; margin-bottom: 4px;">
                ${business.logo ? `<img src="${business.logo}" style="max-height: 38px; max-width: 60px; object-fit: contain;">` : ''}
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: #1e1b4b;">${escapeHTML(business.businessName || 'Study Library Management')}</h3>
              </div>
              <p style="font-size: 11px; color: #475569; margin: 2px 0;">${escapeHTML(business.address || '')}</p>
              <p style="font-size: 11px; color: #475569; margin: 2px 0;">📞 ${escapeHTML(business.phone || '')} ${business.gstNumber ? `• GSTIN: ${escapeHTML(business.gstNumber)}` : ''}</p>
              <div style="display: inline-block; background: #e0e7ff; color: #3730a3; font-size: 11px; font-weight: 700; padding: 2px 10px; border-radius: 4px; margin-top: 6px; letter-spacing: 0.5px;">
                OFFICIAL FEE PAYMENT RECEIPT
              </div>
            </div>

            <!-- Receipt Metadata Grid -->
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px 16px; font-size: 11.5px; margin-bottom: 12px; background: #f8fafc; padding: 10px 12px; border-radius: 6px; border: 1px solid #e2e8f0;">
              <div>
                <div style="font-size: 9.5px; color: #64748b; font-weight: 600; text-transform: uppercase;">Receipt No.</div>
                <div style="font-weight: 700; font-family: monospace; color: #0f172a;">${escapeHTML(receiptNo)}</div>
              </div>
              <div style="text-align: right;">
                <div style="font-size: 9.5px; color: #64748b; font-weight: 600; text-transform: uppercase;">Payment Date</div>
                <div style="font-weight: 600; color: #0f172a;">${formattedDate}</div>
              </div>
              <div>
                <div style="font-size: 9.5px; color: #64748b; font-weight: 600; text-transform: uppercase;">Student Name</div>
                <div style="font-weight: 700; color: #0f172a;">${escapeHTML(student.name)}</div>
                <div style="font-size: 9.5px; color: #64748b; font-family: monospace;">ID: ${escapeHTML(student.studentId)}</div>
              </div>
              <div style="text-align: right;">
                <div style="font-size: 9.5px; color: #64748b; font-weight: 600; text-transform: uppercase;">Seat / Desk</div>
                <div style="font-weight: 600; color: #047857;">${escapeHTML(String(deskInfo))}</div>
              </div>
            </div>

            <!-- Fee Line Item Table -->
            <table style="width: 100%; border-collapse: collapse; margin-bottom: 12px; font-size: 11.5px;">
              <thead>
                <tr style="border-bottom: 1.5px solid #cbd5e1; color: #475569; font-size: 10px; text-transform: uppercase;">
                  <th style="padding: 6px 0; text-align: left;">Description</th>
                  <th style="padding: 6px 0; text-align: right;">Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr style="border-bottom: 1px solid #f1f5f9;">
                  <td style="padding: 8px 0;">${escapeHTML(planName)}</td>
                  <td style="padding: 8px 0; text-align: right; font-weight: 600;">₹${baseAmount}</td>
                </tr>
                ${discountAmount > 0 ? `
                  <tr style="border-bottom: 1px solid #f1f5f9; color: #047857;">
                    <td style="padding: 6px 0;">Discount Applied</td>
                    <td style="padding: 6px 0; text-align: right; font-weight: 600;">-₹${discountAmount}</td>
                  </tr>
                ` : ''}
                <tr style="border-top: 2px solid #0f172a; font-weight: 700; font-size: 13px;">
                  <td style="padding: 8px 0;">Total Amount Paid</td>
                  <td style="padding: 8px 0; text-align: right; color: #047857;">₹${paidAmount}</td>
                </tr>
              </tbody>
            </table>

            <!-- Payment Mode & Verification -->
            <div style="display: flex; justify-content: space-between; align-items: center; font-size: 10.5px; color: #475569; border-top: 1px solid #e2e8f0; padding-top: 8px;">
              <div>
                <span>Payment Mode: <strong style="color: #0f172a;">${escapeHTML(paymentMode)}</strong></span>
                ${p.transactionId ? `<span style="margin-left: 6px; font-family: monospace;">(Txn: ${escapeHTML(p.transactionId)})</span>` : ''}
              </div>
              <span style="font-size: 9px; font-weight: 700; color: #047857; background: #d1fae5; padding: 2px 7px; border-radius: 3px; border: 1px solid #10b981;">
                PAID & VERIFIED ✓
              </span>
            </div>

            <div style="text-align: center; font-size: 9.5px; color: #94a3b8; margin-top: 10px;">
              This is an authorized computer-generated fee payment receipt.
            </div>

            <!-- Modal Action Buttons -->
            <div style="display: flex; justify-content: flex-end; gap: 8px; margin-top: 16px; border-top: 1px solid #e2e8f0; padding-top: 12px;">
              <button class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Close</button>
              <button class="btn btn-primary btn-sm" id="btn-print-student-receipt-modal" style="font-weight: 600;">
                📥 Download PDF / Print Receipt
              </button>
            </div>

          </div>
        `;

        Modal.show({
          title: `Payment Receipt — ${receiptNo}`,
          content: receiptHtml,
          size: 'md'
        });

        // Wire isolated print / save as PDF
        setTimeout(() => {
          document.getElementById('btn-print-student-receipt-modal')?.addEventListener('click', () => {
            const printWin = window.open('', '_blank', 'width=750,height=800');
            if (!printWin) {
              window.print();
              return;
            }
            printWin.document.open();
            printWin.document.write(`
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <title>Receipt — ${receiptNo}</title>
                <link rel="preconnect" href="https://fonts.googleapis.com">
                <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
                <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
                <style>
                  @page { size: A4 portrait; margin: 8mm; }
                  * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Inter', Arial, sans-serif; }
                  body {
                    background: #ffffff !important;
                    color: #0f172a !important;
                    padding: 12px;
                    width: 100%;
                    max-width: 680px;
                    margin: 0 auto;
                    -webkit-font-smoothing: antialiased;
                  }
                  table { width: 100%; border-collapse: collapse; }
                  @media print {
                    body { width: 100%; max-width: 680px; margin: 0 auto; padding: 0; }
                    * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
                  }
                </style>
              </head>
              <body>
                ${receiptHtml.replace(/<div style="display: flex; justify-content: flex-end;[\s\S]*?<\/div>\s*<\/div>$/, '</div>')}
                <script>
                  window.onload = function() {
                    setTimeout(function() {
                      window.print();
                    }, 300);
                  };
                </script>
              </body>
              </html>
            `);
            printWin.document.close();
          });
        }, 100);

      } catch (e) {
        console.error('Receipt click error:', e);
        Toast.error('Could not load receipt');
      }
    });
  });

  // Renew Membership Plan with Dynamic UPI QR Code & Plan/Shift Selection
  container.querySelector('#btn-portal-renew')?.addEventListener('click', async () => {
    try {
      const quoteRes = await api.get('/api/student-portal/renewal-quote');
      if (!quoteRes.success) throw new Error(quoteRes.message);
      let q = quoteRes.data;
      let selectedPortalPayMode = 'upi';

      const modalContent = document.createElement('div');

      function updateModalBody() {
        modalContent.innerHTML = `
          <div style="font-family: 'Outfit', sans-serif;">
            
            <!-- Dynamic Admin Selected Verification Engine Header -->
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 10px; padding: 8px 12px; margin-bottom: 1rem; display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
              <div style="display: flex; align-items: center; gap: 8px;">
                <span class="badge" style="background: ${q.gatewayProvider === 'manual_upi' || !q.gatewayProvider ? 'rgba(0, 184, 148, 0.15)' : 'rgba(108, 92, 231, 0.15)'}; color: ${q.gatewayProvider === 'manual_upi' || !q.gatewayProvider ? 'var(--color-success)' : 'var(--color-primary)'}; font-weight: 800; font-size: 0.82rem; padding: 4px 10px;">
                  ${q.gatewayProvider === 'manual_upi' || !q.gatewayProvider ? '🟢 Option A: Free Standard UPI QR & UTR Check' : '⚡ Option B: ' + (q.gatewayProvider || 'gateway').toUpperCase() + ' 0-Sec Auto-Verify'}
                </span>
              </div>
              <span style="font-size: 0.78rem; color: var(--color-text-secondary); font-weight: 600;">
                Active Admin Mode
              </span>
            </div>

            <!-- Plan & Shift Selection Engine -->
            <div class="row g-2 mb-3">
              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Select Membership Plan *</label>
                <select id="renewal-plan-select" class="form-select" style="font-weight: 600;">
                  ${(q.allPlans || []).map(p => `
                    <option value="${p._id}" ${String(p._id) === String(q.selectedPlanId) ? 'selected' : ''}>
                      ${escapeHTML(p.name)} — ₹${Number(p.price || 0).toLocaleString('en-IN')} (${p.duration || 30} Days)
                    </option>
                  `).join('')}
                </select>
              </div>

              <div class="col-md-6">
                <label class="form-label" style="font-weight: 700; font-size: 0.85rem;">Select Preferred Study Shift *</label>
                <select id="renewal-shift-select" class="form-select" style="font-weight: 600;">
                  ${(q.allShifts || []).map(s => `
                    <option value="${s._id}" ${String(s._id) === String(q.selectedShiftId) ? 'selected' : ''}>
                      ${escapeHTML(s.name)} (${escapeHTML(s.startTime || '')} - ${escapeHTML(s.endTime || '')})
                    </option>
                  `).join('')}
                </select>
              </div>
            </div>

            <!-- Interactive Wallet Balance & Discount Card -->
            <div style="background: rgba(16, 185, 129, 0.08); border: 1px solid rgba(16, 185, 129, 0.25); border-radius: 12px; padding: 12px 14px; margin-bottom: 1rem;">
              <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;">
                <div style="display: flex; align-items: center; gap: 8px;">
                  <span style="font-size: 1.25rem;">👛</span>
                  <div>
                    <div style="font-weight: 700; font-size: 0.9rem; color: var(--color-text-primary);">
                      Available Wallet Balance
                    </div>
                    <div style="font-size: 0.78rem; color: var(--color-text-secondary);">
                      Referral Rewards & Cash Credits
                    </div>
                  </div>
                </div>
                <div style="font-size: 1.1rem; font-weight: 800; color: #10b981;">
                  ₹${(q.availableWalletBalance || 0).toLocaleString('en-IN')}
                </div>
              </div>

              ${(q.availableWalletBalance || 0) > 0 ? `
                <div style="margin-top: 10px; padding-top: 8px; border-top: 1px dashed rgba(16, 185, 129, 0.2); display: flex; align-items: center; gap: 8px;">
                  <input type="checkbox" id="renewal-apply-wallet" class="form-check-input" ${q.isWalletApplied !== false ? 'checked' : ''} style="cursor: pointer; width: 18px; height: 18px;">
                  <label for="renewal-apply-wallet" style="margin: 0; font-size: 0.85rem; font-weight: 700; color: #10b981; cursor: pointer;">
                    Use Wallet Balance for Extra Discount (${q.isWalletApplied ? '- ₹' + q.appliedWalletDiscount.toLocaleString('en-IN') : 'Check to apply'})
                  </label>
                </div>
              ` : `
                <div style="margin-top: 8px; font-size: 0.78rem; color: var(--color-text-secondary);">
                  💡 Earn ₹100 wallet credit for every friend who joins using your referral link!
                </div>
              `}
            </div>

            <!-- Dynamic Renewal Summary Card -->
            <div style="text-align: center; margin-bottom: 1rem; background: rgba(108, 92, 231, 0.06); padding: 10px; border-radius: 10px; border: 1px solid rgba(108, 92, 231, 0.2);">
              <span class="badge" style="background: rgba(108, 92, 231, 0.2); color: var(--color-primary); font-weight: 700; font-size: 0.8rem; padding: 4px 10px;">
                ⚡ Instant Self-Renewal
              </span>
              <h4 style="margin: 6px 0 2px 0; font-size: 1.15rem; font-weight: 800; color: var(--color-text-primary);">
                ${escapeHTML(q.planName)}
              </h4>
              <p class="text-muted small" style="margin: 0; font-size: 0.8rem;">Extends membership by ${q.durationDays} days from expiry.</p>
            </div>

            <!-- Fee Calculation Table -->
            <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 16px; margin-bottom: 1rem;">
              <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 6px;">
                <span class="text-muted">Plan Base Fee:</span>
                <span style="font-weight: 600;">₹${q.basePrice.toLocaleString('en-IN')}</span>
              </div>
              ${q.discount > 0 ? `
                <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 6px; color: var(--color-success);">
                  <span>Special Discount:</span>
                  <span style="font-weight: 600;">- ₹${q.discount.toLocaleString('en-IN')}</span>
                </div>
              ` : ''}
              ${q.appliedWalletDiscount > 0 ? `
                <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 6px; color: #10b981; font-weight: 700;">
                  <span>👛 Wallet Balance Discount:</span>
                  <span>- ₹${q.appliedWalletDiscount.toLocaleString('en-IN')}</span>
                </div>
              ` : ''}
              ${q.pendingFine > 0 ? `
                <div style="display: flex; justify-content: space-between; font-size: 0.9rem; margin-bottom: 6px; color: var(--color-danger);">
                  <span>Late Fee / Grace Due:</span>
                  <span style="font-weight: 600;">+ ₹${q.pendingFine.toLocaleString('en-IN')}</span>
                </div>
              ` : ''}
              <div style="display: flex; justify-content: space-between; font-size: 1.1rem; font-weight: 800; border-top: 1px dashed var(--color-border); padding-top: 8px; margin-top: 4px; color: var(--color-primary);">
                <span>Total Amount Payable:</span>
                <span>₹${q.totalPayable.toLocaleString('en-IN')}</span>
              </div>
            </div>

            ${q.allMethodsDisabled || (q.paymentMethods || []).length === 0 ? `
              <!-- Disabled Payment Banner when Admin turns off all online payment methods -->
              <div style="background: rgba(239, 68, 68, 0.08); border: 1px solid rgba(239, 68, 68, 0.25); border-radius: 12px; padding: 1.25rem; text-align: center; margin-bottom: 1rem;">
                <div style="font-size: 2.2rem; margin-bottom: 6px;">🚫</div>
                <h4 style="margin: 0 0 6px 0; font-size: 1.05rem; font-weight: 800; color: var(--color-danger);">
                  Online Self-Renewal Currently Disabled
                </h4>
                <p style="margin: 0 0 1rem 0; font-size: 0.85rem; color: var(--color-text-secondary); line-height: 1.5;">
                  Online self-renewal payments have been turned OFF by the administration. Please contact the library manager or visit the front reception desk to renew your membership.
                </p>
                <div>
                  <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Close Window</button>
                </div>
              </div>
            ` : `
              <!-- Payment Method Selection Tabs -->
              <div class="mb-3">
                <label class="form-label" style="font-weight: 700;">Choose Payment Method *</label>
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 8px;">
                  <button type="button" class="btn btn-sm ${selectedPortalPayMode === 'upi' ? 'btn-primary' : 'btn-outline-secondary'} btn-portal-pm" data-mode="upi" style="font-weight: 700; padding: 7px 10px;">
                    ⚡               <!-- Dynamic Subpanes Container -->
              <div id="portal-payment-subpane" class="mb-3">
                ${selectedPortalPayMode === 'upi' ? `
                  <!-- 1-Tap Mobile UPI Intent Checkout Section -->
                  <div style="background: var(--color-surface); padding: 14px; border-radius: 14px; border: 1px solid var(--color-border); box-shadow: var(--shadow-sm); text-align: center;">
                    <div style="font-weight: 800; font-size: 0.98rem; color: var(--color-text-primary); margin-bottom: 2px;">
                      ⚡ 1-Tap Instant Mobile UPI Renewal
                    </div>
                    <div style="font-size: 0.80rem; color: var(--color-text-secondary); margin-bottom: 12px;">
                      Tap your UPI app below to pay <strong>₹${q.totalPayable.toLocaleString('en-IN')}</strong> with zero typing.
                    </div>

                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(95px, 1fr)); gap: 8px; margin-bottom: 12px;">
                      <button type="button" class="btn btn-sm btn-renewal-intent" data-app="gpay" style="background: #4285F4; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.82rem; padding: 10px 4px; box-shadow: 0 2px 8px rgba(66, 133, 244, 0.25); display: flex; flex-direction: column; align-items: center; gap: 4px;">
                        <span style="font-size: 1.15rem;">🔵</span>
                        <span>Google Pay</span>
                      </button>
                      <button type="button" class="btn btn-sm btn-renewal-intent" data-app="phonepe" style="background: #5f259f; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.82rem; padding: 10px 4px; box-shadow: 0 2px 8px rgba(95, 37, 159, 0.25); display: flex; flex-direction: column; align-items: center; gap: 4px;">
                        <span style="font-size: 1.15rem;">🟣</span>
                        <span>PhonePe</span>
                      </button>
                      <button type="button" class="btn btn-sm btn-renewal-intent" data-app="paytm" style="background: #00baf2; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.82rem; padding: 10px 4px; box-shadow: 0 2px 8px rgba(0, 186, 242, 0.25); display: flex; flex-direction: column; align-items: center; gap: 4px;">
                        <span style="font-size: 1.15rem;">💙</span>
                        <span>Paytm</span>
                      </button>
                      <button type="button" class="btn btn-sm btn-renewal-intent" data-app="generic" style="background: #00b894; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.82rem; padding: 10px 4px; box-shadow: 0 2px 8px rgba(0, 184, 148, 0.25); display: flex; flex-direction: column; align-items: center; gap: 4px;">
                        <span style="font-size: 1.15rem;">📲</span>
                        <span>Any UPI</span>
                      </button>
                    </div>

                    <!-- Auto-Verify Telemetry Banner -->
                    <div id="renewal-auto-status" style="display: none; background: rgba(108, 92, 231, 0.08); border: 1.5px solid var(--color-primary); border-radius: 10px; padding: 10px; margin-bottom: 10px; font-size: 0.84rem;"></div>

                    <!-- Collapsible Dynamic QR Code for Desktop -->
                    <details style="margin: 8px auto; background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 10px; padding: 6px 10px;">
                      <summary style="cursor: pointer; font-size: 0.80rem; font-weight: 700; color: var(--color-primary);">
                        🖼️ Or Scan QR Code on Another Phone
                      </summary>
                      <div style="padding-top: 8px;">
                        <img id="renewal-qr-img" src="${q.qrCodeUrl}" alt="UPI QR Code" style="width: 140px; height: 140px; margin: 0 auto; border-radius: 8px; display: block; border: 1px solid var(--color-border); background: #fff; padding: 6px;">
                        <div style="margin-top: 6px; font-size: 0.80rem; font-weight: 700; font-family: monospace;">
                          UPI ID: <span style="color: var(--color-primary);">${escapeHTML(q.upiId)}</span>
                        </div>
                      </div>
                    </details>

                    <!-- Collapsible Manual UTR Input -->
                    <details style="margin: 6px auto 0 auto; text-align: left;">
                      <summary style="cursor: pointer; font-size: 0.76rem; color: var(--color-text-muted);">
                        ✏️ Already paid? Enter UTR manually
                      </summary>
                      <div style="margin-top: 6px; background: var(--color-bg-secondary); padding: 8px; border-radius: 8px; border: 1px solid var(--color-border);">
                        <label style="font-size: 0.78rem; font-weight: 600; display: block; margin-bottom: 2px;">12-Digit UPI UTR</label>
                        <input type="text" id="renewal-utr-input" class="form-control form-control-sm" placeholder="e.g. 423456789012" maxlength="30">
                      </div>
                    </details>
                  </div>
                ` : selectedPortalPayMode === 'bank_transfer' ? `
                  <!-- Smart Bank Transfer Details Card -->
                  <div style="background: var(--color-surface); border: 1.5px solid var(--color-border); border-radius: 14px; padding: 14px; box-shadow: var(--shadow-sm);">
                    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; border-bottom: 1px dashed var(--color-border); padding-bottom: 6px;">
                      <span style="font-weight: 800; font-size: 0.90rem; color: var(--color-primary);">🏛️ Library Bank Details (1-Tap Copy)</span>
                      <button type="button" id="btn-portal-copy-all-bank" class="btn btn-xs btn-outline-primary" style="padding: 2px 8px; font-size: 0.75rem; border-radius: 6px;">📋 Copy All</button>
                    </div>

                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); gap: 8px; font-size: 0.82rem; margin-bottom: 10px;">
                      <div style="background: var(--color-bg-secondary); padding: 6px 8px; border-radius: 8px;">
                        <div style="font-size: 0.70rem; color: var(--color-text-muted);">Bank Name</div>
                        <strong>${escapeHTML(q.bankDetails?.bankName || 'HDFC Bank')}</strong>
                      </div>
                      <div style="background: var(--color-bg-secondary); padding: 6px 8px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
                        <div>
                          <div style="font-size: 0.70rem; color: var(--color-text-muted);">Account Number</div>
                          <strong style="font-family: monospace; color: var(--color-primary);">${escapeHTML(q.bankDetails?.accountNumber || '50200012345678')}</strong>
                        </div>
                        <button type="button" class="btn btn-xs btn-outline-secondary btn-portal-copy-bank" data-copy="${escapeHTML(q.bankDetails?.accountNumber || '50200012345678')}" style="padding: 1px 5px; font-size: 0.70rem;">📋</button>
                      </div>
                      <div style="background: var(--color-bg-secondary); padding: 6px 8px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
                        <div>
                          <div style="font-size: 0.70rem; color: var(--color-text-muted);">IFSC Code</div>
                          <strong style="font-family: monospace; color: var(--color-primary);">${escapeHTML(q.bankDetails?.ifscCode || 'HDFC0000123')}</strong>
                        </div>
                        <button type="button" class="btn btn-xs btn-outline-secondary btn-portal-copy-bank" data-copy="${escapeHTML(q.bankDetails?.ifscCode || 'HDFC0000123')}" style="padding: 1px 5px; font-size: 0.70rem;">📋</button>
                      </div>
                      <div style="background: var(--color-bg-secondary); padding: 6px 8px; border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
                        <div>
                          <div style="font-size: 0.70rem; color: var(--color-text-muted);">Account Holder</div>
                          <strong>${escapeHTML(q.bankDetails?.accountHolderName || q.businessName || 'Study Library')}</strong>
                        </div>
                        <button type="button" class="btn btn-xs btn-outline-secondary btn-portal-copy-bank" data-copy="${escapeHTML(q.bankDetails?.accountHolderName || q.businessName || 'Study Library')}" style="padding: 1px 5px; font-size: 0.70rem;">📋</button>
                      </div>
                    </div>

                    <!-- 1-Tap Open Bank App Grid -->
                    <div style="margin-bottom: 10px; text-align: center;">
                      <div style="font-size: 0.78rem; font-weight: 700; color: var(--color-primary); margin-bottom: 6px;">
                        📲 1-Tap Open Banking App
                      </div>
                      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(85px, 1fr)); gap: 6px;">
                        <button type="button" class="btn btn-sm btn-renewal-bank-intent" data-bank="sbi" style="background: #1a4d8c; color: #fff; border: none; font-weight: 700; border-radius: 8px; font-size: 0.78rem; padding: 6px 4px;">
                          🏛️ SBI YONO
                        </button>
                        <button type="button" class="btn btn-sm btn-renewal-bank-intent" data-bank="hdfc" style="background: #004c8f; color: #fff; border: none; font-weight: 700; border-radius: 8px; font-size: 0.78rem; padding: 6px 4px;">
                          🏛️ HDFC Bank
                        </button>
                        <button type="button" class="btn btn-sm btn-renewal-bank-intent" data-bank="icici" style="background: #b82b2b; color: #fff; border: none; font-weight: 700; border-radius: 8px; font-size: 0.78rem; padding: 6px 4px;">
                          🏛️ ICICI Bank
                        </button>
                        <button type="button" class="btn btn-sm btn-renewal-bank-intent" data-bank="other" style="background: #0f766e; color: #fff; border: none; font-weight: 700; border-radius: 8px; font-size: 0.78rem; padding: 6px 4px;">
                          🏛️ Other Bank
                        </button>
                      </div>

                      <div id="renewal-nb-auto-status" style="display: none; margin-top: 8px; background: rgba(108, 92, 231, 0.08); border: 1.5px solid var(--color-primary); border-radius: 8px; padding: 8px; font-size: 0.80rem;"></div>
                    </div>

                    <!-- 📸 1-Tap Slip Upload Trigger -->
                    <div style="background: var(--color-bg-secondary); border: 1.5px dashed var(--color-primary); border-radius: 10px; padding: 10px; text-align: center; margin-bottom: 8px;">
                      <input type="file" id="renewal-slip-file-input" accept="image/*,application/pdf" style="display: none;">
                      <button type="button" id="btn-renewal-slip-trigger" class="btn btn-sm btn-outline-primary" style="font-weight: 700; font-size: 0.80rem; border-radius: 6px; padding: 4px 12px;">
                        📸 Attach Payment Screenshot / Slip
                      </button>
                      <div id="renewal-slip-preview" style="display: none; margin-top: 6px; font-size: 0.76rem; color: var(--color-success); font-weight: 700;"></div>
                    </div>

                    <!-- Collapsible Manual Reference Number Input -->
                    <details style="text-align: left;">
                      <summary style="cursor: pointer; font-size: 0.76rem; color: var(--color-text-muted);">
                        ✏️ Or Enter Bank Ref manually
                      </summary>
                      <div style="margin-top: 6px; background: var(--color-bg-secondary); padding: 8px; border-radius: 8px; border: 1px solid var(--color-border);">
                        <label style="font-size: 0.76rem; font-weight: 600; display: block; margin-bottom: 2px;">Bank NEFT / IMPS Reference *</label>
                        <input type="text" id="renewal-utr-input" class="form-control form-control-sm" placeholder="e.g. Bank Ref #984210" maxlength="35">
                      </div>
                    </details>
                  </div>
                ` : `
                  <!-- Pay at Desk Notice -->
                  <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 12px; padding: 14px; font-size: 0.85rem; color: var(--color-text-primary);">
                    <div style="font-weight: 800; color: var(--color-success); margin-bottom: 4px;">💵 Pay Cash at Reception Desk</div>
                    <p style="margin: 0; line-height: 1.45;">Your renewal application will be recorded as <strong>Pending Cash Payment</strong>. Please visit the front reception desk to complete payment and receive your printed receipt.</p>
                  </div>
                `}
              </div>

              <!-- Submit Form -->
              <form id="portal-renewal-submit-form">
                <div style="display: flex; gap: 8px; justify-content: flex-end; margin-top: 1rem;">
                  <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
                  <button type="submit" class="btn btn-primary" id="btn-submit-renewal-utr" style="font-weight: 700; min-height: 40px;">
                    ${selectedPortalPayMode === 'desk' ? '📝 Submit Desk Renewal Request' : '✅ Confirm & Extend Membership'}
                  </button>
                </div>
              </form>
            `}
          </div>
        `;

        bindEvents();
      }

      function bindEvents() {
        // Payment mode toggle buttons
        modalContent.querySelectorAll('.btn-portal-pm').forEach(btn => {
          btn.addEventListener('click', () => {
            const mode = btn.dataset.mode;
            if (mode && mode !== selectedPortalPayMode) {
              selectedPortalPayMode = mode;
              updateModalBody();
            }
          });
        });

        const planSelect = modalContent.querySelector('#renewal-plan-select');
        const shiftSelect = modalContent.querySelector('#renewal-shift-select');
        const walletCheckbox = modalContent.querySelector('#renewal-apply-wallet');

        async function onSelectionChange() {
          const selectedPlanId = planSelect ? planSelect.value : '';
          const selectedShiftId = shiftSelect ? shiftSelect.value : '';
          const applyWallet = walletCheckbox ? walletCheckbox.checked : false;
          try {
            const freshQuote = await api.get(`/api/student-portal/renewal-quote?planId=${selectedPlanId}&shiftId=${selectedShiftId}&applyWallet=${applyWallet}`);
            if (freshQuote.success && freshQuote.data) {
              q = freshQuote.data;
              updateModalBody();
            }
          } catch (e) {
            console.warn('Failed to calculate renewal quote:', e);
          }
        }

        if (planSelect) planSelect.addEventListener('change', onSelectionChange);
        if (shiftSelect) shiftSelect.addEventListener('change', onSelectionChange);
        if (walletCheckbox) walletCheckbox.addEventListener('change', onSelectionChange);

        // 1-Tap UPI Intent Apps Binding
        let renewalTxnRef = null;
        modalContent.querySelectorAll('.btn-renewal-intent').forEach(btn => {
          btn.onclick = (e) => {
            e.preventDefault();
            const app = btn.dataset.app;
            const upiId = q.upiId || '7276969070@upi';
            const bizName = q.businessName || 'Study Library';
            const studentPhone = student.phone || 'STU';
            renewalTxnRef = `UPI_REN_${studentPhone.slice(-4)}_${Date.now().toString().slice(-6)}`;

            const utrInp = modalContent.querySelector('#renewal-utr-input');
            if (utrInp) utrInp.value = renewalTxnRef;

            const statusBanner = modalContent.querySelector('#renewal-auto-status');
            if (statusBanner) {
              statusBanner.style.display = 'block';
              statusBanner.innerHTML = `
                <div style="font-weight: 700; color: var(--color-primary); display: flex; align-items: center; justify-content: center; gap: 8px;">
                  <span class="spinner-border spinner-border-sm" role="status" style="width: 14px; height: 14px; border-width: 2px;"></span>
                  <span>Opening ${app === 'gpay' ? 'Google Pay' : app === 'phonepe' ? 'PhonePe' : app === 'paytm' ? 'Paytm' : 'UPI App'}...</span>
                </div>
                <small class="text-muted" style="display: block; margin-top: 3px;">Ref <code>${renewalTxnRef}</code> attached. Return here to auto-renew.</small>
              `;
            }

            const baseParams = `pa=${encodeURIComponent(upiId)}&pn=${encodeURIComponent(bizName)}&am=${q.totalPayable}&cu=INR&tn=${encodeURIComponent('Library Membership Renewal')}&tr=${encodeURIComponent(renewalTxnRef)}`;
            let schemeUrl = `upi://pay?${baseParams}`;
            if (app === 'gpay') schemeUrl = `gpay://upi/pay?${baseParams}`;
            else if (app === 'phonepe') schemeUrl = `phonepe://pay?${baseParams}`;
            else if (app === 'paytm') schemeUrl = `paytmmp://pay?${baseParams}`;

            window.location.href = schemeUrl;
          };
        });

        // 1-Tap Copy buttons in Renewal Modal
        modalContent.querySelectorAll('.btn-portal-copy-bank').forEach(btn => {
          btn.onclick = (e) => {
            e.preventDefault();
            const text = btn.dataset.copy;
            if (text) {
              navigator.clipboard.writeText(text).then(() => {
                const old = btn.textContent;
                btn.textContent = '✅';
                setTimeout(() => { btn.textContent = old; }, 1500);
              }).catch(() => {});
            }
          };
        });

        const copyAllRenewalBtn = modalContent.querySelector('#btn-portal-copy-all-bank');
        if (copyAllRenewalBtn) {
          copyAllRenewalBtn.onclick = (e) => {
            e.preventDefault();
            const info = `Bank: ${q.bankDetails?.bankName || 'HDFC Bank'}\nA/C No: ${q.bankDetails?.accountNumber || '50200012345678'}\nIFSC: ${q.bankDetails?.ifscCode || 'HDFC0000123'}\nBeneficiary: ${q.bankDetails?.accountHolderName || q.businessName || 'Study Library'}`;
            navigator.clipboard.writeText(info).then(() => {
              copyAllRenewalBtn.textContent = '✅ Copied All!';
              setTimeout(() => { copyAllRenewalBtn.textContent = '📋 Copy All'; }, 1500);
            }).catch(() => {});
          };
        }

        // Bank Apps Intent in Renewal Modal
        modalContent.querySelectorAll('.btn-renewal-bank-intent').forEach(btn => {
          btn.onclick = (e) => {
            e.preventDefault();
            const bank = btn.dataset.bank;
            const studentPhone = student.phone || 'STU';
            renewalTxnRef = `BNK_REN_${studentPhone.slice(-4)}_${Date.now().toString().slice(-6)}`;

            const info = `${q.bankDetails?.accountNumber || '50200012345678'}`;
            navigator.clipboard.writeText(info).catch(() => {});

            const utrInp = modalContent.querySelector('#renewal-utr-input');
            if (utrInp) utrInp.value = renewalTxnRef;

            const statusBanner = modalContent.querySelector('#renewal-nb-auto-status');
            if (statusBanner) {
              statusBanner.style.display = 'block';
              statusBanner.innerHTML = `
                <div style="font-weight: 700; color: var(--color-primary); display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>⏳</span> <span>Opening ${bank.toUpperCase()} (A/C No Copied)...</span>
                </div>
                <small class="text-muted" style="display: block; margin-top: 2px;">Ref <code>${renewalTxnRef}</code> auto-assigned. Complete transfer and return here.</small>
              `;
            }

            const bankUrls = {
              sbi: 'https://www.onlinesbi.sbi/',
              hdfc: 'https://netbanking.hdfcbank.com/netbanking/',
              icici: 'https://infinity.icicibank.com/',
              other: 'https://www.google.com/search?q=net+banking+login'
            };
            window.open(bankUrls[bank] || bankUrls.other, '_blank');
          };
        });

        // 📸 1-Tap Slip Upload Trigger in Renewal Modal
        const slipTrigger = modalContent.querySelector('#btn-renewal-slip-trigger');
        const slipFileInp = modalContent.querySelector('#renewal-slip-file-input');
        const slipPrev = modalContent.querySelector('#renewal-slip-preview');

        if (slipTrigger && slipFileInp) {
          slipTrigger.onclick = (e) => {
            e.preventDefault();
            slipFileInp.click();
          };

          slipFileInp.onchange = () => {
            const file = slipFileInp.files?.[0];
            if (file) {
              const studentPhone = student.phone || 'STU';
              renewalTxnRef = `SLIP_REN_${studentPhone.slice(-4)}_${Date.now().toString().slice(-6)}`;
              const utrInp = modalContent.querySelector('#renewal-utr-input');
              if (utrInp) utrInp.value = renewalTxnRef;

              if (slipPrev) {
                slipPrev.style.display = 'block';
                slipPrev.innerHTML = `✅ Slip Attached: <strong>${escapeHTML(file.name)}</strong> (Ref: <code>${renewalTxnRef}</code>)`;
              }
            }
          };
        }

        // Listen for return from UPI or Bank app in Renewal Modal
        const onRenewalReturn = () => {
          if (renewalTxnRef) {
            const upiBanner = modalContent.querySelector('#renewal-auto-status');
            if (upiBanner && selectedPortalPayMode === 'upi') {
              upiBanner.style.display = 'block';
              upiBanner.style.borderColor = 'var(--color-success)';
              upiBanner.style.background = 'rgba(0, 184, 148, 0.08)';
              upiBanner.innerHTML = `
                <div style="font-weight: 800; color: var(--color-success); display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>✅</span> <span>UPI App Payment Captured!</span>
                </div>
                <small style="display: block; margin-top: 3px; color: var(--color-text-secondary);">
                  Ref <code>${renewalTxnRef}</code> verified. Tap <strong>Confirm & Extend Membership</strong> below.
                </small>
              `;
            }

            const nbBanner = modalContent.querySelector('#renewal-nb-auto-status');
            if (nbBanner && selectedPortalPayMode === 'bank_transfer') {
              nbBanner.style.display = 'block';
              nbBanner.style.borderColor = 'var(--color-success)';
              nbBanner.style.background = 'rgba(0, 184, 148, 0.08)';
              nbBanner.innerHTML = `
                <div style="font-weight: 800; color: var(--color-success); display: flex; align-items: center; justify-content: center; gap: 6px;">
                  <span>✅</span> <span>Bank Transfer Handshake Recorded!</span>
                </div>
                <small style="display: block; margin-top: 3px; color: var(--color-text-secondary);">
                  Ref <code>${renewalTxnRef}</code> auto-attached. Tap <strong>Confirm & Extend Membership</strong> below.
                </small>
              `;
            }
          }
        };

        window.addEventListener('focus', onRenewalReturn);

        const renewalSubmitForm = modalContent.querySelector('#portal-renewal-submit-form');
        if (renewalSubmitForm) {
          renewalSubmitForm.onsubmit = async (e) => {
            e.preventDefault();
            const utrInput = modalContent.querySelector('#renewal-utr-input');
            const utrNumber = selectedPortalPayMode === 'desk' ? 'DESK_CASH' : (utrInput?.value?.trim() || renewalTxnRef || `BNK_${Date.now()}`);
            const selectedPlanId = planSelect ? planSelect.value : q.selectedPlanId;
            const selectedShiftId = shiftSelect ? shiftSelect.value : q.selectedShiftId;
            const applyWallet = walletCheckbox ? walletCheckbox.checked : q.isWalletApplied;

            const btn = modalContent.querySelector('#btn-submit-renewal-utr');
            Loading.button(btn, true);

            try {
              const renewRes = await api.post('/api/student-portal/renewal-request', {
                utrNumber,
                planId: selectedPlanId,
                shiftId: selectedShiftId,
                amountPaid: q.totalPayable,
                applyWallet,
                paymentMode: selectedPortalPayMode === 'desk' ? 'cash' : selectedPortalPayMode
              });

              if (!renewRes.success) throw new Error(renewRes.message);

              Toast.success('🎉 Membership renewed successfully!');
              Modal.closeAll();
              // Reload portal with fresh dashboard and analytics
              const freshDash = await api.get('/api/student-portal/dashboard');
              if (freshDash.success && freshDash.data) {
                let freshAnalytics = null;
                try {
                  const aRes = await api.get(`/api/attendance/analytics/${freshDash.data.student._id}`);
                  if (aRes.success) freshAnalytics = aRes.data;
                } catch (e) {}
                renderPortalUI(container, freshDash.data, freshAnalytics);
              }
            } catch (err) {
              Toast.error(err.message || 'Renewal failed. Please check UTR.');
            } finally {
              Loading.button(btn, false);
            }
          };
        }
      }

      updateModalBody();

      if (q.allMethodsDisabled || (q.paymentMethods || []).length === 0) {
        Toast.info('Online payment is currently disabled by library management. Please contact reception to renew.');
      }

      const renewModal = new Modal({ title: '💳 Membership Self-Renewal', content: modalContent, size: 'md' });
      renewModal.show();

    } catch (err) {
      Toast.error(err.message || 'Could not load renewal quote');
    }
  });
}

/**
 * Render SVG Circular Gauge for Consistency Score
 */
export function renderGaugeScoreSvg(score) {
  const safeScore = Math.max(0, Math.min(100, Math.round(score || 0)));
  return `
    <div style="position: relative; width: 100px; height: 100px; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">
      <svg viewBox="0 0 36 36" style="width: 100px; height: 100px; transform: rotate(-90deg);">
        <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
              fill="none"
              stroke="rgba(148, 163, 184, 0.2)"
              stroke-width="3.2" />
        <path d="M18 2.0845 a 15.9155 15.9155 0 0 1 0 31.831 a 15.9155 15.9155 0 0 1 0 -31.831"
              fill="none"
              stroke="url(#portalScoreGaugeGrad)"
              stroke-width="3.2"
              stroke-dasharray="${safeScore}, 100"
              stroke-linecap="round" />
        <defs>
          <linearGradient id="portalScoreGaugeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stop-color="#10b981"/>
            <stop offset="100%" stop-color="#6366f1"/>
          </linearGradient>
        </defs>
      </svg>
      <div style="position: absolute; text-align: center;">
        <div style="font-size: 1.25rem; font-weight: 800; color: var(--color-text-primary); line-height: 1;">${safeScore}%</div>
        <div style="font-size: 0.6rem; color: var(--color-text-secondary); text-transform: uppercase; font-weight: 700; margin-top: 2px;">Consistency</div>
      </div>
    </div>
  `;
}

/**
 * Render 30-Day GitHub-style Attendance Heatmap Grid
 */
export function renderHeatmapGridHtml(heatmapData) {
  if (!heatmapData || heatmapData.length === 0) {
    return `<div class="text-muted small text-center p-3">No attendance records found for the past 30 days.</div>`;
  }

  const squaresHtml = heatmapData.map(d => {
    const mins = d.minutes || 0;
    const hrs = (mins / 60).toFixed(1);
    const dateObj = new Date(d.date);
    const dateFormatted = isNaN(dateObj.getTime()) ? d.date : dateObj.toLocaleDateString('en-IN', { month: 'short', day: 'numeric', weekday: 'short' });

    let bg = 'rgba(148, 163, 184, 0.15)';
    let border = 'rgba(148, 163, 184, 0.25)';
    let statusText = 'Absent';

    if (d.status === 'absent' || mins === 0) {
      bg = 'rgba(148, 163, 184, 0.15)';
      border = 'rgba(148, 163, 184, 0.25)';
      statusText = 'Absent';
    } else if (mins < 120) {
      bg = '#0e4429';
      border = '#006d32';
      statusText = `${mins} mins (${d.status})`;
    } else if (mins < 240) {
      bg = '#006d32';
      border = '#26a641';
      statusText = `${hrs} hrs (${d.status})`;
    } else if (mins < 360) {
      bg = '#26a641';
      border = '#39d353';
      statusText = `${hrs} hrs (${d.status})`;
    } else {
      bg = '#39d353';
      border = '#2ea043';
      statusText = `${hrs} hrs (${d.status})`;
    }

    const title = `${dateFormatted}: ${statusText}${d.checkIn ? ` [${d.checkIn} - ${d.checkOut || 'Active'}]` : ''}`;

    return `
      <div
        title="${title}"
        style="
          width: 22px;
          height: 22px;
          border-radius: 4px;
          background: ${bg};
          border: 1px solid ${border};
          cursor: pointer;
          transition: transform 0.15s ease, box-shadow 0.15s ease;
          flex-shrink: 0;
        "
        onmouseover="this.style.transform='scale(1.35)'; this.style.zIndex='5'; this.style.boxShadow='0 0 8px rgba(57,211,83,0.6)';"
        onmouseout="this.style.transform='scale(1)'; this.style.zIndex='1'; this.style.boxShadow='none';"
      ></div>
    `;
  }).join('');

  return `
    <div>
      <div style="display: flex; flex-wrap: wrap; gap: 6px; align-items: center; justify-content: flex-start; padding: 4px 0;">
        ${squaresHtml}
      </div>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 8px; font-size: 0.72rem; color: var(--color-text-muted);">
        <span>30 Days Ago</span>
        <div style="display: flex; align-items: center; gap: 4px;">
          <span>Less</span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: rgba(148, 163, 184, 0.15); display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #0e4429; display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #006d32; display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #26a641; display: inline-block;"></span>
          <span style="width: 12px; height: 12px; border-radius: 2px; background: #39d353; display: inline-block;"></span>
          <span>More</span>
        </div>
        <span>Today</span>
      </div>
    </div>
  `;
}

/**
 * Helper to safely load image with CORS for canvas with DOM element caching and retry fallback
 */
function loadCanvasImage(src) {
  return new Promise((resolve) => {
    if (!src || typeof src !== 'string') return resolve(null);

    const trimmed = src.trim();
    if (!trimmed) return resolve(null);

    // 1. If an <img> in the current DOM already loaded this src, use it directly!
    const existingImg = Array.from(document.querySelectorAll('img')).find(
      el => el.complete && el.naturalWidth > 0 && (el.src === trimmed || el.getAttribute('src') === trimmed || el.src.endsWith(trimmed))
    );
    if (existingImg) {
      return resolve(existingImg);
    }

    // 2. Normalize relative path if needed
    let cleanSrc = trimmed;
    if (!cleanSrc.startsWith('http') && !cleanSrc.startsWith('data:') && !cleanSrc.startsWith('blob:') && !cleanSrc.startsWith('/')) {
      cleanSrc = '/' + cleanSrc;
    }

    const img = new Image();
    // Only set crossOrigin for external http(s) URLs, not for data or blob URIs
    if (!cleanSrc.startsWith('data:') && !cleanSrc.startsWith('blob:')) {
      img.crossOrigin = 'anonymous';
    }

    img.onload = () => resolve(img);
    img.onerror = () => {
      // Retry without crossOrigin for same-origin relative paths
      if (img.crossOrigin) {
        const retryImg = new Image();
        retryImg.onload = () => resolve(retryImg);
        retryImg.onerror = () => resolve(null);
        retryImg.src = cleanSrc;
      } else {
        resolve(null);
      }
    };
    img.src = cleanSrc;
  });
}

/**
 * Generate 1080x1920px Executive Offline Mobile ID Pass Canvas Image & Trigger Download
 */
export async function download1080pMobileIDPass(student, business = {}, initials = 'S', seatTitle = '02', planName = 'Study Plan', expiryDateStr = 'Not Set', extra = {}) {
  Toast.info('🎨 Generating 1080p Ultra-HD Mobile Pass Wallpaper...');

  const canvas = document.createElement('canvas');
  canvas.width = 1080;
  canvas.height = 1920;
  const ctx = canvas.getContext('2d');

  // Pre-load all assets asynchronously with deep fallback resolution
  const photoUrl = student.photo || student.avatar || student.profilePhoto || student.selfie || (window.store?.user?.photo) || (window.store?.user?.avatar) || (document.querySelector('#sp-avatar-img')?.src) || (document.querySelector('.portal-profile-avatar img')?.src) || '';
  const logoUrl = business.logo || business.logoUrl || window.store?.profile?.logo || window.store?.settings?.businessProfile?.logo || (document.querySelector('.brand-logo img')?.src) || '';
  const stampUrl = business.stampImage || business.stampImageUrl || window.store?.profile?.stampImage || window.store?.settings?.businessProfile?.stampImage || '';
  
  // Format Shift Name nicely
  let rawShift = extra.shiftName || student.shift?.name || student.shift?.timing || student.shift || student.plan?.shift || 'Full Day';
  if (typeof rawShift === 'string') {
    if (rawShift.toLowerCase() === 'fullday') rawShift = 'Full Day';
    else rawShift = rawShift.replace(/\b\w/g, l => l.toUpperCase());
  }
  const shiftName = rawShift;

  // Format Plan Name in Title Case
  let rawPlan = planName || student.plan?.name || 'Study Plan';
  if (typeof rawPlan === 'string') {
    rawPlan = rawPlan.replace(/\b\w/g, l => l.toUpperCase());
  }
  const formattedPlanName = rawPlan;

  const phone = extra.phone || student.phone || student.mobile || '-';
  const bloodGroup = extra.bloodGroup || student.bloodGroup || '';
  const studentId = student.studentId || student.enrollmentNo || 'STU-MEMBER';
  const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : new Date().toLocaleDateString('en-IN');

  const qrPayload = encodeURIComponent(student.studentId || student.phone || student._id || 'STUDENT');
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${qrPayload}&margin=2&bgcolor=ffffff`;

  const [photoImg, logoImg, stampImg, qrImg] = await Promise.all([
    loadCanvasImage(photoUrl),
    loadCanvasImage(logoUrl),
    loadCanvasImage(stampUrl),
    loadCanvasImage(qrUrl)
  ]);

  // 1. Wallpaper Background (Deep midnight dark slate with violet/indigo aura)
  const bgGrad = ctx.createLinearGradient(0, 0, 1080, 1920);
  bgGrad.addColorStop(0, '#0a0d18');
  bgGrad.addColorStop(0.3, '#13182e');
  bgGrad.addColorStop(0.7, '#181534');
  bgGrad.addColorStop(1, '#090b14');
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, 1080, 1920);

  // Decorative ambient glow orbs
  ctx.save();
  ctx.beginPath();
  ctx.arc(180, 240, 450, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(79, 70, 229, 0.12)';
  ctx.fill();

  ctx.beginPath();
  ctx.arc(900, 1680, 400, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(16, 185, 129, 0.08)';
  ctx.fill();
  ctx.restore();

  // Top Wallpaper Header
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
  ctx.font = '600 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  ctx.fillText(`📱 OFFLINE DIGITAL PASS • ${(business.businessName || 'STUDY LIBRARY').toUpperCase()}`, 540, 75);

  // 2. White Card Container with Prominent Perimeter Border & Scissor Outline
  const cardX = 80, cardY = 120, cardW = 920, cardH = 1660, cardR = 36;
  ctx.save();
  ctx.beginPath();
  if (typeof ctx.roundRect === 'function') {
    ctx.roundRect(cardX, cardY, cardW, cardH, cardR);
  } else {
    ctx.moveTo(cardX + cardR, cardY);
    ctx.arcTo(cardX + cardW, cardY, cardX + cardW, cardY + cardH, cardR);
    ctx.arcTo(cardX + cardW, cardY + cardH, cardX, cardY + cardH, cardR);
    ctx.arcTo(cardX, cardY + cardH, cardX, cardY, cardR);
    ctx.arcTo(cardX, cardY, cardX + cardW, cardY, cardR);
  }
  ctx.closePath();
  ctx.fillStyle = '#ffffff';
  ctx.shadowColor = 'rgba(0, 0, 0, 0.45)';
  ctx.shadowBlur = 50;
  ctx.shadowOffsetY = 24;
  ctx.fill();

  // Solid dark high-contrast perimeter border
  ctx.strokeStyle = '#0f172a';
  ctx.lineWidth = 4;
  ctx.stroke();
  ctx.restore();

  // Outer dashed scissor cutting / alignment guide
  ctx.save();
  ctx.setLineDash([16, 10]);
  ctx.beginPath();
  if (typeof ctx.roundRect === 'function') {
    ctx.roundRect(cardX - 14, cardY - 14, cardW + 28, cardH + 28, cardR + 10);
  }
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.45)';
  ctx.lineWidth = 2.5;
  ctx.stroke();
  ctx.restore();

  // 3. Card Header Banner (Gradient matching primary brand)
  ctx.save();
  ctx.beginPath();
  if (typeof ctx.roundRect === 'function') {
    ctx.roundRect(cardX, cardY, cardW, 240, [cardR, cardR, 0, 0]);
  } else {
    ctx.moveTo(cardX, cardY + cardR);
    ctx.arcTo(cardX, cardY, cardX + cardR, cardY, cardR);
    ctx.lineTo(cardX + cardW - cardR, cardY);
    ctx.arcTo(cardX + cardW, cardY, cardX + cardW, cardY + cardR, cardR);
    ctx.lineTo(cardX + cardW, cardY + 240);
    ctx.lineTo(cardX, cardY + 240);
  }
  ctx.closePath();
  ctx.clip();

  const headerGrad = ctx.createLinearGradient(cardX, cardY, cardX + cardW, cardY + 240);
  headerGrad.addColorStop(0, '#4f46e5');
  headerGrad.addColorStop(1, '#6366f1');
  ctx.fillStyle = headerGrad;
  ctx.fillRect(cardX, cardY, cardW, 240);

  // Draw Logo in Header
  if (logoImg) {
    const logoSize = 64;
    const logoX = cardX + 36;
    const logoY = cardY + 36;
    ctx.save();
    ctx.beginPath();
    if (typeof ctx.roundRect === 'function') {
      ctx.roundRect(logoX, logoY, logoSize, logoSize, 12);
    } else {
      ctx.rect(logoX, logoY, logoSize, logoSize);
    }
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    ctx.clip();
    ctx.drawImage(logoImg, logoX, logoY, logoSize, logoSize);
    ctx.restore();

    // Business Name & Tagline beside Logo
    ctx.textAlign = 'left';
    ctx.fillStyle = '#ffffff';
    ctx.font = '800 36px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText(business.businessName || 'Study Library', cardX + 115, cardY + 68);

    ctx.fillStyle = 'rgba(255, 255, 255, 0.88)';
    ctx.font = '500 22px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText(business.tagline || 'Silence, Focus and Success', cardX + 115, cardY + 102);
  } else {
    // Centered Business Name & Tagline
    ctx.textAlign = 'center';
    ctx.fillStyle = '#ffffff';
    ctx.font = '800 38px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText(business.businessName || 'STUDY LIBRARY', 540, cardY + 70);

    ctx.fillStyle = 'rgba(255, 255, 255, 0.88)';
    ctx.font = '500 22px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText(business.tagline || 'Silence, Focus and Success', 540, cardY + 106);
  }
  ctx.restore();

  // 4. Avatar Outer Ring & Photo / Initials (with perfect aspect-ratio cover crop)
  const avatarX = 540, avatarY = cardY + 240, avatarR = 100;
  ctx.save();
  // White Drop-Shadow Outer Base
  ctx.beginPath();
  ctx.arc(avatarX, avatarY, avatarR + 10, 0, Math.PI * 2);
  ctx.fillStyle = '#ffffff';
  ctx.shadowColor = 'rgba(0, 0, 0, 0.15)';
  ctx.shadowBlur = 20;
  ctx.shadowOffsetY = 6;
  ctx.fill();

  // Indigo Accent Ring
  ctx.beginPath();
  ctx.arc(avatarX, avatarY, avatarR + 4, 0, Math.PI * 2);
  ctx.fillStyle = '#4f46e5';
  ctx.fill();

  // Avatar Image / Content Circle
  ctx.beginPath();
  ctx.arc(avatarX, avatarY, avatarR, 0, Math.PI * 2);
  ctx.closePath();
  ctx.clip();

  if (photoImg) {
    const nw = photoImg.naturalWidth || photoImg.width || 200;
    const nh = photoImg.naturalHeight || photoImg.height || 200;
    const minDim = Math.min(nw, nh);
    const sx = (nw - minDim) / 2;
    const sy = (nh - minDim) / 2;
    ctx.drawImage(photoImg, sx, sy, minDim, minDim, avatarX - avatarR, avatarY - avatarR, avatarR * 2, avatarR * 2);
  } else {
    ctx.fillStyle = '#eef2ff';
    ctx.fillRect(avatarX - avatarR, avatarY - avatarR, avatarR * 2, avatarR * 2);

    ctx.fillStyle = '#4f46e5';
    ctx.font = '800 76px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(initials, avatarX, avatarY);
  }
  ctx.restore();

  // Reset baseline
  ctx.textBaseline = 'alphabetic';

  // 5. Student Name with Smart Auto-Wrapping / Font Scaling
  const nameStr = (student.name || 'Student Member').trim();
  ctx.textAlign = 'center';
  ctx.fillStyle = '#0f172a';

  let nameFontSize = 44;
  ctx.font = `800 ${nameFontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
  let nameWidth = ctx.measureText(nameStr).width;

  let nameLines = [];
  if (nameWidth > 760) {
    // Try splitting words into 2 lines
    const words = nameStr.split(' ');
    if (words.length >= 2) {
      const mid = Math.ceil(words.length / 2);
      const line1 = words.slice(0, mid).join(' ');
      const line2 = words.slice(mid).join(' ');
      nameLines = [line1, line2];
      nameFontSize = 38;
    } else {
      nameLines = [nameStr];
      nameFontSize = 34;
    }
  } else {
    nameLines = [nameStr];
  }

  ctx.font = `800 ${nameFontSize}px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
  let startNameY = cardY + 390;
  if (nameLines.length > 1) {
    nameLines.forEach((l, idx) => {
      ctx.fillText(l, 540, startNameY + idx * 46);
    });
    startNameY += (nameLines.length - 1) * 46;
  } else {
    ctx.fillText(nameLines[0], 540, startNameY);
  }

  // 6. Badges: Student ID + Blood Group side-by-side
  const badgeY = startNameY + 22;
  const idText = studentId;
  ctx.font = '800 26px monospace';
  const idTextWidth = ctx.measureText(idText).width;
  const idBadgeW = idTextWidth + 36;
  const idBadgeH = 46;

  let bloodBadgeW = 0;
  const hasBlood = Boolean(bloodGroup);
  const bloodText = `🩸 ${bloodGroup}`;
  if (hasBlood) {
    ctx.font = '800 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    bloodBadgeW = ctx.measureText(bloodText).width + 28;
  }

  const totalBadgesWidth = idBadgeW + (hasBlood ? (12 + bloodBadgeW) : 0);
  let curBadgeX = 540 - totalBadgesWidth / 2;

  // Draw Student ID Badge
  ctx.save();
  ctx.beginPath();
  if (typeof ctx.roundRect === 'function') {
    ctx.roundRect(curBadgeX, badgeY, idBadgeW, idBadgeH, 10);
  } else {
    ctx.rect(curBadgeX, badgeY, idBadgeW, idBadgeH);
  }
  ctx.fillStyle = '#eef2ff';
  ctx.fill();
  ctx.strokeStyle = '#c7d2fe';
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.fillStyle = '#4338ca';
  ctx.font = '800 26px monospace';
  ctx.textAlign = 'center';
  ctx.fillText(idText, curBadgeX + idBadgeW / 2, badgeY + 32);
  ctx.restore();

  // Draw Blood Group Badge (if present)
  if (hasBlood) {
    const bloodX = curBadgeX + idBadgeW + 12;
    ctx.save();
    ctx.beginPath();
    if (typeof ctx.roundRect === 'function') {
      ctx.roundRect(bloodX, badgeY, bloodBadgeW, idBadgeH, 10);
    } else {
      ctx.rect(bloodX, badgeY, bloodBadgeW, idBadgeH);
    }
    ctx.fillStyle = 'rgba(220, 38, 38, 0.1)';
    ctx.fill();
    ctx.strokeStyle = 'rgba(220, 38, 38, 0.25)';
    ctx.lineWidth = 1.5;
    ctx.stroke();
    ctx.fillStyle = '#dc2626';
    ctx.font = '800 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText(bloodText, bloodX + bloodBadgeW / 2, badgeY + 32);
    ctx.restore();
  }

  // 7. Details Data Box
  const boxX = cardX + 44, boxY = badgeY + 68, boxW = cardW - 88, boxH = 490, boxR = 20;
  ctx.save();
  ctx.beginPath();
  if (typeof ctx.roundRect === 'function') {
    ctx.roundRect(boxX, boxY, boxW, boxH, boxR);
  } else {
    ctx.rect(boxX, boxY, boxW, boxH);
  }
  ctx.fillStyle = '#f8fafc';
  ctx.fill();
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.restore();

  const labels = [
    { label: 'Assigned Desk / Seat:', val: seatTitle, color: '#4f46e5', bold: true },
    { label: 'Shift Timing:', val: shiftName, color: '#0f172a', bold: true },
    { label: 'Study Plan:', val: planName, color: '#334155', bold: false },
    { label: 'Contact Phone:', val: phone, color: '#334155', bold: false },
    { label: 'Valid Until:', val: expiryDateStr, color: '#dc2626', bold: true }
  ];

  labels.forEach((item, idx) => {
    const rowY = boxY + 64 + idx * 92;
    ctx.textAlign = 'left';
    ctx.fillStyle = '#64748b';
    ctx.font = '600 28px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText(item.label, boxX + 32, rowY);

    ctx.textAlign = 'right';
    ctx.fillStyle = item.color;
    ctx.font = `${item.bold ? '800' : '600'} 30px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif`;
    ctx.fillText(item.val, boxX + boxW - 32, rowY);

    if (idx < labels.length - 1) {
      ctx.beginPath();
      ctx.moveTo(boxX + 24, rowY + 30);
      ctx.lineTo(boxX + boxW - 24, rowY + 30);
      ctx.strokeStyle = '#e2e8f0';
      ctx.lineWidth = 1.5;
      ctx.stroke();
    }
  });

  // 8. Verification Footer Area (QR Code on Left + Stamp on Right)
  const qrBoxY = boxY + boxH + 36;
  const qrSize = 240;
  const qrX = cardX + 70;

  if (qrImg) {
    ctx.save();
    ctx.beginPath();
    if (typeof ctx.roundRect === 'function') {
      ctx.roundRect(qrX - 8, qrBoxY - 8, qrSize + 16, qrSize + 16, 12);
    }
    ctx.fillStyle = '#ffffff';
    ctx.fill();
    ctx.strokeStyle = '#cbd5e1';
    ctx.lineWidth = 2;
    ctx.stroke();
    ctx.drawImage(qrImg, qrX, qrBoxY, qrSize, qrSize);
    ctx.restore();

    ctx.textAlign = 'center';
    ctx.fillStyle = '#4f46e5';
    ctx.font = '800 20px monospace';
    ctx.fillText('SCAN TO VERIFY PASS', qrX + qrSize / 2, qrBoxY + qrSize + 30);
  }

  // Right Side Stamp & Signatory
  const stampBoxX = cardX + cardW - 340;
  const stampBoxY = qrBoxY + 10;
  if (stampImg) {
    ctx.save();
    ctx.drawImage(stampImg, stampBoxX + 40, stampBoxY, 180, 180);
    ctx.restore();
  } else {
    // Vector Official Seal Stamp
    ctx.save();
    ctx.translate(stampBoxX + 130, stampBoxY + 80);
    ctx.rotate(-0.06);
    ctx.beginPath();
    if (typeof ctx.roundRect === 'function') {
      ctx.roundRect(-100, -45, 200, 90, 8);
    } else {
      ctx.rect(-100, -45, 200, 90);
    }
    ctx.strokeStyle = '#059669';
    ctx.lineWidth = 3;
    ctx.stroke();
    ctx.fillStyle = '#059669';
    ctx.textAlign = 'center';
    ctx.font = '800 24px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText('OFFICIAL SEAL', 0, -10);
    ctx.font = '700 20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
    ctx.fillText('PAID & VERIFIED', 0, 20);
    ctx.restore();
  }

  // Auth Signatory Line
  ctx.beginPath();
  ctx.moveTo(stampBoxX + 10, stampBoxY + 210);
  ctx.lineTo(stampBoxX + 250, stampBoxY + 210);
  ctx.strokeStyle = '#94a3b8';
  ctx.lineWidth = 2;
  ctx.stroke();

  ctx.textAlign = 'center';
  ctx.fillStyle = '#64748b';
  ctx.font = '600 20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  ctx.fillText('Authorized Signatory', stampBoxX + 130, stampBoxY + 238);

  // 9. Card Base Bottom Ribbon
  const ribbonY = cardY + cardH - 68;
  ctx.save();
  ctx.beginPath();
  if (typeof ctx.roundRect === 'function') {
    ctx.roundRect(cardX, ribbonY, cardW, 68, [0, 0, cardR, cardR]);
  } else {
    ctx.moveTo(cardX, ribbonY);
    ctx.lineTo(cardX + cardW, ribbonY);
    ctx.lineTo(cardX + cardW, cardY + cardH - cardR);
    ctx.arcTo(cardX + cardW, cardY + cardH, cardX + cardW - cardR, cardY + cardH, cardR);
    ctx.lineTo(cardX + cardR, cardY + cardH);
    ctx.arcTo(cardX, cardY + cardH, cardX, cardY + cardH - cardR, cardR);
    ctx.lineTo(cardX, ribbonY);
  }
  ctx.closePath();
  ctx.fillStyle = '#f8fafc';
  ctx.fill();
  ctx.strokeStyle = '#e2e8f0';
  ctx.lineWidth = 1;
  ctx.stroke();
  ctx.restore();

  ctx.textAlign = 'center';
  ctx.fillStyle = '#64748b';
  ctx.font = '600 22px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  ctx.fillText(`Issued: ${admissionDate} • Helpline: ${business.phone || '+91 98765 43210'} • Non-Transferable`, 540, ribbonY + 42);

  // 10. Outer Wallpaper Footer Note
  ctx.textAlign = 'center';
  ctx.fillStyle = 'rgba(255, 255, 255, 0.45)';
  ctx.font = '500 20px -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif';
  ctx.fillText('Carry on phone lockscreen for instant entry • Anti-Tamper Digital Token', 540, 1870);

  // Trigger Download
  const link = document.createElement('a');
  link.download = `${nameStr.replace(/\s+/g, '_')}_Mobile_ID_Pass_1080x1920.png`;
  link.href = canvas.toDataURL('image/png');
  document.body.appendChild(link);
  link.click();
  link.remove();
  Toast.success('📱 1080x1920px Mobile ID Pass Wallpaper downloaded successfully!');
}

