import api from '../api.js';
import { Toast, Modal, Confirm, Loading, escapeHTML, copyToClipboard } from '../ui.js';
import { SmartFormatters } from '../utils/smartFormatters.js';
import { t } from '../i18n.js';
import { generateAdmissionFormPDF, previewAdmissionFormPDF } from '../pdfGenerator.js';
import { PushNotifications } from '../utils/pushNotifications.js';
import { renderHeatmap, renderBehaviorBadge, calculateBehaviorScore } from '../utils/attendanceHeatmap.js';

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
  const expiryDateStr = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : 'Not Set';

  const examTags = (student.targetExams && student.targetExams.length > 0)
    ? student.targetExams.map(ex => `<span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-size: 0.75rem;">${escapeHTML(ex)}</span>`).join('')
    : '<span class="text-muted small">General Self-Study</span>';

  const isCheckedIn = todayAttendance && todayAttendance.checkIn && !todayAttendance.checkOut;
  const punchStatusText = isCheckedIn
    ? `🟢 Currently Checked In since <strong>${formatPunchTime(todayAttendance.checkIn)}</strong>`
    : (todayAttendance && todayAttendance.checkOut)
    ? `✅ Completed study session today (<strong>${formatPunchTime(todayAttendance.checkIn)}</strong> – <strong>${formatPunchTime(todayAttendance.checkOut)}</strong>)`
    : `⚪ Not checked in today`;

  container.innerHTML = `
    <!-- Admin Preview Banner -->
    ${data.isAdmin ? `
      <div class="card p-3 mb-4" style="background: linear-gradient(135deg, rgba(108, 92, 231, 0.12), rgba(0, 184, 148, 0.08)); border: 1px solid var(--color-primary); border-radius: var(--radius-lg); display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 12px;">
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

    <!-- Contextual Guidance Tip Banner -->
    <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
      <span style="font-size: 1.1rem;">💡</span>
      <span><strong>Tip:</strong> Check your study consistency gauge, download digital ID card, or request seat transfers directly from your portal.</span>
    </div>

    <!-- Top Welcome Banner -->
    <div class="card mb-4" style="
      background: linear-gradient(135deg, rgba(108, 92, 231, 0.15), rgba(162, 155, 254, 0.05)), var(--color-surface);
      border: 1px solid var(--color-border);
      border-radius: var(--radius-lg);
      padding: 1.5rem;
    ">
      <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 1.25rem;">
        <div style="display: flex; align-items: center; gap: 1.25rem;">
          <div style="
            width: 68px; height: 68px; border-radius: 50%;
            background: var(--color-primary-bg); color: var(--color-primary);
            font-size: 1.5rem; font-weight: 800; display: flex; align-items: center; justify-content: center;
            border: 2px solid var(--color-primary); flex-shrink: 0; overflow: hidden;
          ">
            ${(student.photo || user?.avatar) ? `<img src="${escapeHTML(student.photo || user.avatar)}" alt="${escapeHTML(student.name)}" style="width: 100%; height: 100%; object-fit: cover;">` : initials}
          </div>
          <div>
            <h2 style="margin: 0 0 4px 0; font-size: 1.4rem; font-weight: 700; color: var(--color-text-primary);">
              Welcome back, ${escapeHTML(student.name)}!
            </h2>
            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap; margin-bottom: 6px;">
              <span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success); font-family: monospace; font-weight: 700; font-size: 0.85rem;">
                ${escapeHTML(student.studentId || 'STU-MEMBER')}
              </span>
              <span style="color: var(--color-text-secondary); font-size: 0.85rem;">• ${escapeHTML(business.businessName || 'Study Library')}</span>
            </div>
            <div style="display: flex; gap: 4px; flex-wrap: wrap;">
              ${examTags}
            </div>
          </div>
        </div>

        <!-- Quick Action Buttons Grid -->
        <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center; justify-content: flex-start;">
          <button id="btn-portal-profile" class="btn btn-outline-primary btn-sm" style="font-weight: 600; font-size: 0.8rem; padding: 6px 10px;">
            👤 Profile
          </button>
          <button id="btn-portal-leave" class="btn btn-outline-secondary btn-sm" style="font-weight: 600; font-size: 0.8rem; padding: 6px 10px;">
            🌴 Leave
          </button>
          <button id="btn-portal-seat-change" class="btn btn-outline-secondary btn-sm" style="font-weight: 600; font-size: 0.8rem; padding: 6px 10px;">
            💺 Change Seat
          </button>
          <button id="btn-portal-referral" class="btn btn-outline-secondary btn-sm" style="font-weight: 600; font-size: 0.8rem; padding: 6px 10px;">
            🎁 Refer
          </button>
          <button id="btn-portal-idcard" class="btn btn-outline-primary btn-sm" style="font-weight: 600; font-size: 0.8rem; padding: 6px 10px;">
            🪪 Digital ID
          </button>
          <button id="btn-portal-renew" class="btn btn-primary btn-sm" style="font-weight: 600; font-size: 0.8rem; padding: 6px 12px;">
            ⚡ Renew Plan
          </button>
        </div>
      </div>
    </div>

    <!-- ⚠️ Mandatory Profile & KYC Completion Card (Rendered when profile < 100%) -->
    ${(student.profileCompletion < 100 || !student.isProfileComplete) ? `
      <div class="card mb-4 p-4" style="background: rgba(245, 158, 11, 0.08); border: 1.5px solid rgba(245, 158, 11, 0.35); border-radius: var(--radius-lg);">
        <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
          <div style="display: flex; align-items: center; gap: 12px; max-width: 650px;">
            <div style="font-size: 2.2rem;">⚠️</div>
            <div>
              <h4 style="margin: 0 0 4px 0; font-size: 1.05rem; font-weight: 800; color: #f59e0b;">
                Action Required: Complete Your Student Profile & KYC Upload (${student.profileCompletion || 60}% Complete)
              </h4>
              <p style="margin: 0; font-size: 0.82rem; color: var(--color-text-secondary); line-height: 1.4;">
                Your walk-in admission is pre-active! Please upload your Profile Photo Selfie and Aadhaar KYC proof to unlock your official Digital Offline ID Card Pass.
              </p>
              <div style="margin-top: 8px; width: 100%; max-width: 380px; height: 6px; background: rgba(255,255,255,0.15); border-radius: 4px; overflow: hidden;">
                <div style="height: 100%; width: ${student.profileCompletion || 60}%; background: linear-gradient(90deg, #f59e0b, #00b894); border-radius: 4px;"></div>
              </div>
            </div>
          </div>
          <button id="btn-portal-complete-kyc" class="btn btn-warning" style="font-weight: 700; font-size: 0.85rem; padding: 8px 16px;">
            ✏️ Upload Photo & Complete KYC Now
          </button>
        </div>
      </div>
    ` : ''}

    <!-- 3 Stat Widgets Grid (Auto-Fit & Responsive) -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1rem; margin-bottom: 1.5rem;">
      
      <!-- Seat Card -->
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; flex-direction: column; justify-content: space-between;">
        <div>
          <div class="text-muted small mb-1" style="font-weight: 600;">💺 Assigned Study Desk</div>
          <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
            <span style="font-size: 1.55rem; font-weight: 800; color: var(--color-primary);">${seatTitle}</span>
            <span class="badge ${hasSeat ? 'badge-primary' : 'badge-secondary'}" style="font-size: 0.75rem;">${seatBadge}</span>
          </div>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-top: 8px;">
          ${hasSeat ? 'Dedicated reserved cabin desk with personal power socket & reading light.' : 'Flexible open reading hall access with ergonomic seating.'}
        </div>
      </div>

      <!-- Plan Expiry Card -->
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; flex-direction: column; justify-content: space-between;">
        <div>
          <div class="text-muted small mb-1" style="font-weight: 600;">⏳ Membership Validity</div>
          <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
            <span style="font-size: 1.55rem; font-weight: 800; color: ${daysRemaining <= 3 ? 'var(--color-danger)' : 'var(--color-success)'};">
              ${daysRemaining} ${daysRemaining === 1 ? 'Day' : 'Days'}
            </span>
            <span class="badge ${daysRemaining <= 0 ? 'badge-danger' : 'badge-success'}" style="font-size: 0.75rem;">
              ${daysRemaining <= 0 ? 'Expired / Due' : 'Active Plan'}
            </span>
          </div>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-top: 8px;">
          Plan: <strong>${escapeHTML(planName)}</strong> (Valid till ${expiryDateStr})
        </div>
      </div>

      <!-- Study Hours Card -->
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); display: flex; flex-direction: column; justify-content: space-between;">
        <div>
          <div class="text-muted small mb-1" style="font-weight: 600;">📈 Total Study Time</div>
          <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
            <span style="font-size: 1.55rem; font-weight: 800; color: var(--color-info);">${totalHours} hrs</span>
            <span class="badge badge-info" style="font-size: 0.75rem;">Logged</span>
          </div>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-top: 8px;">
          Consistency: <strong>${analytics ? analytics.consistencyScore + '%' : '94%'}</strong> (${analytics ? (analytics.totalDaysPresent + (analytics.totalDaysPresent === 1 ? ' day' : ' days')) : 'Active'} this month)
        </div>
      </div>

    </div>

    <!-- 🧠 AI Study Analytics & Consistency Score Card -->
    <div class="card mb-4 p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); position: relative;">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 1.25rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
        <div style="display: flex; align-items: center; gap: 10px;">
          <span style="font-size: 1.5rem;">🧠</span>
          <div>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary);">
              AI Study Analytics & Consistency Score
            </h3>
            <p style="margin: 0; font-size: 0.8rem; color: var(--color-text-secondary);">
              90-day learning habits, peak study hours & attendance discipline
            </p>
          </div>
        </div>

        <div style="display: flex; gap: 6px; flex-wrap: wrap; align-items: center;">
          <span class="badge" style="background: rgba(16, 185, 129, 0.15); color: var(--color-success); font-weight: 700; font-size: 0.8rem; padding: 5px 10px; border-radius: 6px;">
            ${escapeHTML(analytics?.peakStudyHours?.badge || '🌅 Peak Time: 08:00 AM – 02:00 PM')}
          </span>
          <span class="badge" style="background: rgba(245, 158, 11, 0.15); color: var(--color-warning); font-weight: 700; font-size: 0.8rem; padding: 5px 10px; border-radius: 6px;">
            🔥 ${analytics?.currentStreak || 0} ${analytics?.currentStreak === 1 ? 'Day' : 'Days'} Streak
          </span>
          <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: var(--color-primary); font-weight: 700; font-size: 0.8rem; padding: 5px 10px; border-radius: 6px;">
            🏆 Best: ${analytics?.longestStreak || 0} ${analytics?.longestStreak === 1 ? 'Day' : 'Days'}
          </span>
        </div>
      </div>

      <!-- Main Layout: Score Gauge + Heatmap + AI Recommendation -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(260px, 1fr)); gap: 1.5rem; align-items: center;">
        <!-- Circular / Gauge Consistency Score -->
        <div style="display: flex; flex-direction: column; align-items: center; text-align: center; gap: 6px; padding: 12px 14px; background: var(--color-bg-secondary); border-radius: var(--radius-md); border: 1px solid var(--color-border);">
          ${renderGaugeScoreSvg(analytics?.consistencyScore || 0)}
          <div style="font-size: 0.82rem; color: var(--color-text-secondary); margin-top: 4px;">
            Avg: <strong>${escapeHTML(analytics?.averageDailyDuration?.formatted || '0m')}</strong> / day
          </div>
          <div style="font-size: 0.75rem; color: var(--color-text-muted);">
            ${analytics?.totalDaysPresent || 0} / 30 days present
          </div>
        </div>

        <!-- 30-Day Heatmap & AI Tip -->
        <div>
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
            <span style="font-size: 0.85rem; font-weight: 700; color: var(--color-text-primary);">
              📅 30-Day Attendance Heatmap
            </span>
            <span style="font-size: 0.75rem; color: var(--color-text-muted);">
              Hover squares to inspect daily duration
            </span>
          </div>

          ${renderHeatmapGridHtml(analytics?.heatmap || [])}

          <!-- Dynamic AI Recommendation Note / Tip Pill -->
          <div style="
            margin-top: 12px;
            padding: 10px 14px;
            background: linear-gradient(135deg, rgba(99, 102, 241, 0.08), rgba(16, 185, 129, 0.08));
            border: 1px solid rgba(99, 102, 241, 0.2);
            border-radius: var(--radius-md);
            display: flex;
            align-items: center;
            gap: 10px;
          ">
            <span style="font-size: 1.25rem; flex-shrink: 0;">💡</span>
            <div style="font-size: 0.85rem; color: var(--color-text-primary); line-height: 1.4;">
              <strong>AI Study Tip:</strong> ${escapeHTML(analytics?.aiRecommendation || analytics?.aiStudyTip || 'Consistency is the key to cracking competitive exams. Try regular study blocks every morning!')}
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 🏆 Achievements & Badges Studio Card -->
    <div class="card mb-4 p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem; margin-bottom: 1.25rem; border-bottom: 1px solid var(--color-divider); padding-bottom: 0.75rem;">
        <div style="display: flex; align-items: center; gap: 10px;">
          <span style="font-size: 1.6rem;">🏆</span>
          <div>
            <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary);">
              Achievements & Badges Studio
            </h3>
            <p style="margin: 0; font-size: 0.8rem; color: var(--color-text-secondary);">
              Track your learning milestones, study streaks, and unlock special library honors
            </p>
          </div>
        </div>

        <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
          <span class="badge" style="background: linear-gradient(135deg, rgba(245, 158, 11, 0.2), rgba(239, 68, 68, 0.15)); color: #d97706; font-weight: 800; font-size: 0.85rem; padding: 6px 12px; border-radius: 20px; border: 1px solid rgba(245, 158, 11, 0.4);">
            🔥 ${student.studyStreakDays || 0} Day Streak
          </span>
          <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: var(--color-primary); font-weight: 700; font-size: 0.85rem; padding: 6px 12px; border-radius: 20px;">
            🎖️ ${(student.badges || []).length} / 4 Badges Unlocked
          </span>
        </div>
      </div>

      <!-- Active / Earned Badges Showcase Row -->
      ${(student.badges && student.badges.length > 0) ? `
        <div class="mb-4" style="background: linear-gradient(135deg, rgba(99, 102, 241, 0.08), rgba(16, 185, 129, 0.06)); border: 1px solid rgba(99, 102, 241, 0.2); border-radius: var(--radius-md); padding: 12px 16px;">
          <div style="font-size: 0.82rem; font-weight: 700; color: var(--color-primary); text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 8px;">
            🌟 Active Earned Badges
          </div>
          <div style="display: flex; gap: 10px; flex-wrap: wrap;">
            ${student.badges.map(b => `
              <div style="display: flex; align-items: center; gap: 8px; background: var(--color-surface); padding: 6px 12px; border-radius: 8px; border: 1px solid var(--color-border); box-shadow: var(--shadow-sm);">
                <span style="font-size: 1.3rem;">${escapeHTML(b.icon || '🏅')}</span>
                <div>
                  <div style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">${escapeHTML(b.title)}</div>
                  <div style="font-size: 0.7rem; color: var(--color-success); font-weight: 600;">Earned ${new Date(b.earnedAt || Date.now()).toLocaleDateString('en-IN')}</div>
                </div>
              </div>
            `).join('')}
          </div>
        </div>
      ` : ''}

      <!-- 4 Badges & Progress Bars Grid -->
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1rem;">
        ${(() => {
          const badgeProgress = data?.badgeProgress || analytics?.badgeProgress || [];
          return [
            { badgeId: 'early_bird', title: '🌅 Early Bird', icon: '🌅', description: 'Checked in before 07:00 AM 5+ times', target: 5, unit: 'check-ins' },
            { badgeId: 'study_warrior', title: '⚔️ 100-Hour Study Warrior', icon: '⚔️', description: 'Total study hours >= 100', target: 100, unit: 'hrs' },
            { badgeId: 'night_owl', title: '🦉 Night Owl', icon: '🦉', description: 'Checked in after 08:00 PM 5+ times', target: 5, unit: 'check-ins' },
            { badgeId: 'streak_champion', title: '🏆 30-Day Streak Champion', icon: '🏆', description: 'Consecutive attendance streak >= 30 days', target: 30, unit: 'days' }
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
              <div style="background: var(--color-bg-secondary); border: 1px solid ${isEarned ? 'var(--color-primary)' : 'var(--color-border)'}; border-radius: var(--radius-md); padding: 14px; display: flex; flex-direction: column; justify-content: space-between; position: relative; overflow: hidden;">
                ${isEarned ? `
                  <div style="position: absolute; top: 8px; right: 8px; background: var(--color-success); color: white; font-size: 0.65rem; font-weight: 800; padding: 2px 8px; border-radius: 10px; text-transform: uppercase;">
                    Unlocked
                  </div>
                ` : ''}
                <div>
                  <div style="display: flex; align-items: center; gap: 10px; margin-bottom: 6px;">
                    <span style="font-size: 1.8rem; opacity: ${isEarned ? '1' : '0.6'};">${b.icon}</span>
                    <div>
                      <div style="font-weight: 700; font-size: 0.95rem; color: ${isEarned ? 'var(--color-primary)' : 'var(--color-text-primary)'};">
                        ${escapeHTML(b.title)}
                      </div>
                      <div style="font-size: 0.75rem; color: var(--color-text-secondary);">
                        ${escapeHTML(b.description)}
                      </div>
                    </div>
                  </div>
                </div>

                <div style="margin-top: 12px;">
                  <div style="display: flex; justify-content: space-between; align-items: center; font-size: 0.75rem; margin-bottom: 4px; font-weight: 600;">
                    <span style="color: var(--color-text-muted);">Progress</span>
                    <span style="color: ${isEarned ? 'var(--color-success)' : 'var(--color-primary)'};">${progVal} / ${b.target} ${b.unit} (${percent}%)</span>
                  </div>
                  <div style="height: 6px; background: var(--color-surface); border-radius: 4px; overflow: hidden;">
                    <div style="width: ${percent}%; height: 100%; background: ${isEarned ? 'var(--color-success)' : 'var(--color-primary)'}; border-radius: 4px; transition: width 0.4s ease;"></div>
                  </div>
                </div>
              </div>
            `;
          }).join('');
        })()}
      </div>
    </div>

    <!-- Attendance Self-Puncher Card -->
    <div class="card mb-4 p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
        <div>
          <h3 style="margin: 0 0 4px 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary);">
            ⏱️ Self Attendance Punch
          </h3>
          <p style="margin: 0; font-size: 0.85rem; color: var(--color-text-secondary);">
            ${punchStatusText}
          </p>
        </div>

        <button id="btn-self-punch" class="btn ${isCheckedIn ? 'btn-danger' : 'btn-success'}" style="font-weight: 700; padding: 0.65rem 1.5rem;">
          ${isCheckedIn ? '🔴 Punch-Out Now' : (todayAttendance && todayAttendance.checkOut ? '🟢 Check In Again' : '🟢 Punch-In (Check In)')}
        </button>
      </div>
    </div>

    <!-- Native Mobile Push Notifications Card -->
    <div class="card mb-4 p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
      <div style="display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 1rem;">
        <div style="display: flex; align-items: center; gap: 1rem;">
          <div style="font-size: 2rem;">🔔</div>
          <div>
            <div style="font-weight: 700; font-size: 1.05rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 0.5rem; flex-wrap: wrap;">
              <span>🔔 Enable Native Mobile Push Notifications</span>
              <span id="portal-push-badge" class="badge" style="font-size: 0.75rem; padding: 2px 8px; border-radius: 12px; border: 1px solid currentColor;">
                Checking...
              </span>
            </div>
            <p style="margin: 2px 0 0 0; font-size: 0.85rem; color: var(--color-text-secondary);">
              Get instant OS lock screen alerts for seat renewals, fee receipts, and library announcements.
            </p>
          </div>
        </div>

        <label class="switch-label" style="margin: 0;">
          <input type="checkbox" id="portal-push-toggle">
          <span class="switch-slider"></span>
        </label>
      </div>
    </div>

    <!-- Payment Receipts History Table -->
    <div class="card" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg); overflow: hidden;">
      <div class="card-header p-3" style="border-bottom: 1px solid var(--color-divider); background: var(--color-surface-hover);">
        <h4 style="margin: 0; font-size: 1.05rem; font-weight: 600; color: var(--color-text-primary);">
          💳 My Payment Receipts & Invoices
        </h4>
      </div>
      <div class="card-body p-0">
        <div style="overflow-x: auto;">
          <table class="table data-table mb-0" style="width: 100%; border-collapse: collapse;">
            <thead>
              <tr style="border-bottom: 1px solid var(--color-divider); text-align: left; font-size: 0.85rem; color: var(--color-text-muted);">
                <th style="padding: 12px 16px;">Receipt #</th>
                <th style="padding: 12px 16px;">Date</th>
                <th style="padding: 12px 16px;">Method</th>
                <th style="padding: 12px 16px;">Amount</th>
                <th style="padding: 12px 16px;">Status</th>
                <th style="padding: 12px 16px;">Action</th>
              </tr>
            </thead>
            <tbody>
              ${payments && payments.length > 0 ? payments.map(p => `
                <tr style="border-bottom: 1px solid var(--color-divider); font-size: 0.9rem;">
                  <td style="padding: 12px 16px; font-family: monospace; font-weight: 700;">
                    ${escapeHTML(p.receiptNumber || 'REC')}
                    <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(p.receiptNumber || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Receipt #">📋</button>
                  </td>
                  <td style="padding: 12px 16px;">${new Date(p.paymentDate).toLocaleDateString('en-IN')} <small class="text-muted">(${SmartFormatters.timeAgo(p.paymentDate)})</small></td>
                  <td style="padding: 12px 16px; text-transform: uppercase;">${escapeHTML(p.paymentMethod || 'UPI')}</td>
                  <td style="padding: 12px 16px; font-weight: 700; color: var(--color-success);">${SmartFormatters.currency(p.finalAmount)}</td>
                  <td style="padding: 12px 16px;"><span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success);">Paid</span></td>
                  <td style="padding: 12px 16px;">
                    <button class="btn btn-sm btn-outline-primary btn-view-receipt" data-receipt='${JSON.stringify(p)}' style="font-size: 0.75rem; padding: 2px 8px;">
                      🖨️ Receipt
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
  `;

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

    const qrData = JSON.stringify({
      type: 'STUDENT_ID',
      id: student.studentId,
      name: student.name,
      phone: student.phone
    });
    const qrCodeURL = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(qrData)}&margin=4`;

    // Create ID card
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <div class="id-card-modal-wrapper text-center">
        <div id="printable-id-card" style="
          width: 320px; margin: 0 auto; background: #ffffff; color: #1a1a2e;
          border-radius: 12px; border: 2px solid #6c5ce7; overflow: hidden;
          box-shadow: 0 10px 25px rgba(0,0,0,0.15); font-family: 'Outfit', sans-serif; text-align: left;
        ">
          <div style="background: linear-gradient(135deg, #6c5ce7, #a29bfe); color: white; padding: 14px 16px; text-align: center;">
            <div style="font-weight: 800; font-size: 1.15rem; letter-spacing: 0.5px; text-transform: uppercase;">
              ${escapeHTML(business.businessName || 'Study Library')}
            </div>
            <div style="font-size: 0.75rem; opacity: 0.9; margin-top: 2px;">Student Membership Card</div>
          </div>

          <div style="padding: 16px;">
            <div style="display: flex; gap: 14px; align-items: center; margin-bottom: 14px;">
              <div style="
                width: 68px; height: 68px; border-radius: 50%; background: #f0f2f5; color: #6c5ce7;
                display: flex; align-items: center; justify-content: center; font-size: 1.4rem; font-weight: 800;
                border: 3px solid #6c5ce7; flex-shrink: 0;
              ">
                ${initials}
              </div>
              <div>
                <h4 style="margin: 0 0 4px 0; font-size: 1.1rem; font-weight: 700; color: #2d3436;">${escapeHTML(student.name)}</h4>
                <div style="font-size: 0.8rem; background: #eef2ff; color: #4338ca; padding: 2px 8px; border-radius: 4px; display: inline-block; font-weight: 700; font-family: monospace;">
                  ${escapeHTML(student.studentId || 'STU-MEMBER')}
                </div>
              </div>
            </div>

            <div style="font-size: 0.82rem; line-height: 1.6; border-top: 1px dashed #e2e8f0; padding-top: 10px; color: #4a5568;">
              <div style="display: flex; justify-content: space-between;"><strong>Assigned Seat:</strong> <span style="font-weight: 700; color: #6c5ce7;">${escapeHTML(seatTitle)}</span></div>
              <div style="display: flex; justify-content: space-between;"><strong>Plan:</strong> <span>${escapeHTML(planName)}</span></div>
              <div style="display: flex; justify-content: space-between;"><strong>Phone:</strong> <span>${escapeHTML(student.phone || '-')}</span></div>
              <div style="display: flex; justify-content: space-between;"><strong>Valid Till:</strong> <span style="font-weight: 700; color: #e53e3e;">${expiryDateStr}</span></div>
            </div>

            <!-- QR Code -->
            <div style="text-align: center; margin: 8px 0;">
              <img src="${qrCodeURL}" alt="Student QR" style="width: 90px; height: 90px; border-radius: 4px;">
              <div style="font-size: 0.65rem; color: #718096; letter-spacing: 1px; margin-top: 2px;">
                ${escapeHTML(student.studentId || '')}
              </div>
            </div>
          </div>
          <div style="background: #f7fafc; border-top: 1px solid #edf2f7; padding: 6px 12px; font-size: 0.65rem; color: #718096; text-align: center;">
            Carry Daily • Library Helpdesk: ${escapeHTML(business.phone || '')}
          </div>
        </div>

        <div class="d-flex justify-content-center gap-2 mt-4 flex-wrap">
          <button class="btn btn-outline-primary btn-sm" id="btn-download-1080p-idpass">📱 Download Mobile ID Pass (1080x1920)</button>
          <button class="btn btn-primary btn-sm" onclick="window.print()">🖨️ Print ID Card</button>
          <button class="btn btn-secondary btn-sm modal-close-btn" onclick="Modal.close()">Close</button>
        </div>
      </div>
    `;

    new Modal({ title: `Student ID Card`, content: modalContent, size: 'md' }).show();

    modalContent.querySelector('#btn-download-1080p-idpass')?.addEventListener('click', () => {
      download1080pMobileIDPass(student, business, initials, seatTitle, planName, expiryDateStr);
    });
  });



  container.querySelector('#btn-portal-complete-kyc')?.addEventListener('click', () => {
    container.querySelector('#btn-portal-profile')?.click();
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
      const [fieldsRes, cfgRes] = await Promise.all([
        api.get('/api/custom-fields').catch(() => ({ data: [] })),
        api.get('/api/system/public-config').catch(() => ({ data: null }))
      ]);

      const customFieldsList = Array.isArray(fieldsRes.data) ? fieldsRes.data : [];
      const cfMap = (student.customFields && typeof student.customFields === 'object') ? student.customFields : {};

      // Standard / Core fields helper
      const getStudentVal = (key) => {
        if (student[key] !== undefined && student[key] !== null) return student[key];
        if (cfMap[key] !== undefined && cfMap[key] !== null) return cfMap[key];
        return '';
      };

      // Custom fields grouping by section
      const sections = [
        { key: 'personal', label: 'Personal & Contact Information', icon: '👤', fields: [] },
        { key: 'academic', label: 'Academic Goals & Preparation', icon: '🎯', fields: [] },
        { key: 'contact', label: 'Address & Emergency Contacts', icon: '📍', fields: [] },
        { key: 'kyc', label: 'KYC & Identity Verification', icon: '🪪', fields: [] },
        { key: 'other', label: 'Additional Information & Preferences', icon: '📋', fields: [] }
      ];

      const coreKeys = new Set(['name', 'phone', 'email', 'gender', 'dob', 'dateOfBirth', 'photo', 'signature', 'plan', 'seat', 'status']);
      
      customFieldsList.forEach(f => {
        const fKey = (f.fieldName || '').trim();
        if (coreKeys.has(fKey.toLowerCase())) return;
        const val = cfMap[fKey] !== undefined ? cfMap[fKey] : (student[fKey] !== undefined ? student[fKey] : '');
        const sec = (f.section || 'other').toLowerCase();
        let targetSec = sections.find(s => s.key === sec);
        if (!targetSec) targetSec = sections[sections.length - 1];
        targetSec.fields.push({ ...f, value: val });
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

      // Build section HTML
      let sectionsHtml = '';

      // Standard Personal & Contact Section
      sectionsHtml += `
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
            <span>👤</span> Personal & Identification Details
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; font-size: 0.88rem;">
            <div><span class="text-muted d-block small">Full Name</span><strong>${escapeHTML(student.name)}</strong></div>
            <div><span class="text-muted d-block small">Mobile Phone (WhatsApp)</span><strong>${escapeHTML(SmartFormatters.phone(student.phone))}</strong> <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(student.phone || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">📋</button></div>
            <div><span class="text-muted d-block small">Email Address</span><strong>${escapeHTML(student.email || 'N/A')}</strong></div>
            <div><span class="text-muted d-block small">Gender</span><strong style="text-transform: capitalize;">${escapeHTML(student.gender || 'N/A')}</strong></div>
            <div><span class="text-muted d-block small">Date of Birth</span><strong>${student.dob ? new Date(student.dob).toLocaleDateString('en-IN') : (student.dateOfBirth ? new Date(student.dateOfBirth).toLocaleDateString('en-IN') : 'N/A')}</strong></div>
            <div><span class="text-muted d-block small">Blood Group</span>${student.bloodGroup ? `<span class="badge" style="background: rgba(239, 68, 68, 0.12); color: var(--color-danger); font-weight: 700;">🩸 ${escapeHTML(student.bloodGroup)}</span>` : '<span class="text-muted small">Not specified</span>'}</div>
            <div><span class="text-muted d-block small">Pincode</span><strong>${escapeHTML(student.pincode || 'N/A')}</strong></div>
            <div><span class="text-muted d-block small">City & State</span><strong>${escapeHTML(student.city || '')}${student.state ? ', ' + escapeHTML(student.state) : ''}</strong></div>
          </div>
        </div>
      `;

      // Standard Academic & KYC Section
      const examsList = Array.isArray(student.targetExams) ? student.targetExams : [];
      sectionsHtml += `
        <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
          <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
            <span>🎯</span> Academic Goals & Identity Verification
          </div>
          <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 12px; font-size: 0.88rem;">
            <div>
              <span class="text-muted d-block small">Target Exams</span>
              <div>${examsList.length > 0 ? examsList.map(e => `<span class="badge badge-primary me-1 mb-1">${escapeHTML(e)}</span>`).join('') : '<span class="text-muted small">None selected</span>'}</div>
            </div>
            <div>
              <span class="text-muted d-block small">ID Proof Type</span>
              <strong>${escapeHTML(student.idProof?.type || 'Aadhaar Card')}</strong>
            </div>
            <div>
              <span class="text-muted d-block small">ID Proof Number</span>
              <strong style="font-family: monospace;">${escapeHTML((student.idProof?.type === 'Aadhaar Card' || student.idProof?.type === 'Aadhaar' || !student.idProof?.type) ? SmartFormatters.aadhaar(student.idProof?.number) : (student.idProof?.number || 'Verified'))}</strong>
              ${student.idProof?.number ? `<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(student.idProof.number)}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy ID Proof Number">📋</button>` : ''}
            </div>
            ${student.idProof?.image ? `
              <div>
                <span class="text-muted d-block small">ID Proof Scan</span>
                <a href="${student.idProof.image.startsWith('/') ? student.idProof.image : '/' + student.idProof.image}" target="_blank" class="btn btn-xs btn-outline-primary mt-1">
                  🔍 View Document Scan
                </a>
              </div>
            ` : ''}
          </div>
        </div>
      `;

      // Custom Field Groupings
      sections.forEach(sec => {
        if (sec.fields.length === 0) return;
        sectionsHtml += `
          <div class="mb-4" style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-lg); padding: 1.25rem;">
            <div style="font-weight: 700; font-size: 1rem; color: var(--color-primary); margin-bottom: 12px; display: flex; align-items: center; gap: 8px;">
              <span>${sec.icon || '📝'}</span> ${escapeHTML(sec.label)}
            </div>
            <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; font-size: 0.88rem;">
              ${sec.fields.map(f => `
                <div style="${(f.colSpan === 12 || f.colSpan === 2 || f.type === 'textarea') ? 'grid-column: 1 / -1;' : ''}">
                  <span class="text-muted d-block small" style="margin-bottom: 2px;">${escapeHTML(f.label)}</span>
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

      btnSpUpload?.addEventListener('click', () => inputSpPhoto.click());
      inputSpPhoto?.addEventListener('change', async (e) => {
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

      btnSpSelfie?.addEventListener('click', async () => {
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
            idProofNumber: modalContent.querySelector('#kyc-idProofNumber')?.value?.trim()
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
        previewAdmissionFormPDF(student, { business });
      });
      modalContent.querySelector('#btn-modal-print-pdf')?.addEventListener('click', () => {
        previewAdmissionFormPDF(student, { business });
      });

    } catch (err) {
      modalContent.innerHTML = `<div class="text-danger p-3 text-center">Failed to load profile details: ${escapeHTML(err.message)}</div>`;
    }
  });

  // Attach Leave Request Modal
  container.querySelector('#btn-portal-leave')?.addEventListener('click', async () => {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <form id="portal-leave-form" class="p-1 mb-4">
        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
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

    async function loadLeaveHistory() {
      const histContainer = modalContent.querySelector('#portal-leave-history');
      try {
        const res = await api.get('/api/student-portal/leave-requests');
        const list = res.data || [];
        if (list.length === 0) {
          histContainer.innerHTML = `<p class="text-muted small text-center p-2">No leave applications submitted yet.</p>`;
          return;
        }
        histContainer.innerHTML = list.map(l => `
          <div class="p-2 mb-2" style="background: var(--color-bg-primary); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem;">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <strong>${new Date(l.startDate).toLocaleDateString('en-IN')} - ${new Date(l.endDate).toLocaleDateString('en-IN')}</strong>
              <span class="badge ${l.status === 'approved' ? 'badge-success' : l.status === 'rejected' ? 'badge-danger' : 'badge-warning'}" style="text-transform: uppercase; font-size: 0.7rem;">
                ${l.status}
              </span>
            </div>
            <div class="text-muted small">${escapeHTML(l.reason)}</div>
            ${l.adminReply ? `<div style="color: var(--color-primary); font-size: 0.75rem; margin-top: 4px;">Admin: ${escapeHTML(l.adminReply)}</div>` : ''}
          </div>
        `).join('');
      } catch (e) {
        histContainer.innerHTML = `<p class="text-danger small text-center">Failed to load history</p>`;
      }
    }

    modalContent.querySelector('#portal-leave-form').onsubmit = async (e) => {
      e.preventDefault();
      const startDate = modalContent.querySelector('#leave-start').value;
      const endDate = modalContent.querySelector('#leave-end').value;
      const reason = modalContent.querySelector('#leave-reason').value.trim();

      try {
        await api.post('/api/student-portal/leave-request', { startDate, endDate, reason });
        Toast.success('Leave application submitted!');
        modalContent.querySelector('#leave-reason').value = '';
        loadLeaveHistory();
      } catch (err) {
        Toast.error(err.message || 'Failed to submit leave');
      }
    };

    loadLeaveHistory();
  });

  // Attach Seat Change Modal
  container.querySelector('#btn-portal-seat-change')?.addEventListener('click', async () => {
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

    // Load Branches & Vacant Desks
    try {
      const [bRes, sRes] = await Promise.all([
        api.get('/api/branches').catch(() => ({ data: [] })),
        api.get('/api/seats').catch(() => ({ data: [] }))
      ]);

      allBranches = Array.isArray(bRes.data) ? bRes.data : (bRes.data?.branches || []);
      allSeats = Array.isArray(sRes.data) ? sRes.data : (sRes.data?.seats || []);

      if (allBranches.length > 0) {
        branchSelect.innerHTML = allBranches.map(b => `
          <option value="${b._id}" ${String(b._id) === String(student.branch?._id || student.branch) ? 'selected' : ''}>
            ${escapeHTML(b.name)} ${b.city ? '(' + b.city + ')' : ''}
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
        if (s.status !== 'vacant') return false;
        if (!selectedBranchId) return true;
        const bId = s.branch?._id || s.branch;
        return String(bId) === String(selectedBranchId);
      });

      if (vacantBadge) {
        vacantBadge.style.display = 'inline-block';
        vacantBadge.textContent = `🟢 ${vacant.length} Desks Vacant`;
      }

      if (vacant.length > 0) {
        seatSelect.innerHTML = `<option value="">-- Any Available Vacant Desk --</option>` +
          vacant.map(s => `
            <option value="${s._id}" data-num="${escapeHTML(s.seatNumber)}">
              Desk ${escapeHTML(s.seatNumber)} — ${escapeHTML(s.zone || 'General')} (Vacant)
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
  });

  // Attach Smart Referral Studio Modal
  container.querySelector('#btn-portal-referral')?.addEventListener('click', async () => {
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
              <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; margin-bottom: 8px;">
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
  });

  // Attach Payment Receipt Click Handlers
  container.querySelectorAll('.btn-view-receipt').forEach(btn => {
    btn.addEventListener('click', () => {
      try {
        const p = JSON.parse(btn.dataset.receipt);
        const receiptHtml = `
          <div id="student-receipt-modal" style="padding: 20px; font-family: 'Outfit', sans-serif; background: #fff; color: #1a1a2e; border-radius: 8px;">
            <div style="text-align: center; border-bottom: 2px dashed #ccc; padding-bottom: 12px; margin-bottom: 12px;">
              <h3 style="margin: 0; color: #1e1b4b;">${escapeHTML(business.businessName || 'Study Library')}</h3>
              <p style="font-size: 12px; color: #666; margin: 4px 0;">${escapeHTML(business.address || '')}</p>
              <p style="font-size: 12px; color: #666;">Phone: ${escapeHTML(business.phone || '')}</p>
              <div style="font-size: 14px; font-weight: 700; color: #6366f1; margin-top: 6px;">FEE PAYMENT RECEIPT</div>
            </div>
            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 13px; margin-bottom: 14px;">
              <div><strong>Receipt #:</strong> ${escapeHTML(p.receiptNumber || 'REC')}</div>
              <div style="text-align: right;"><strong>Date:</strong> ${new Date(p.paymentDate).toLocaleDateString('en-IN')}</div>
              <div><strong>Student:</strong> ${escapeHTML(student.name)} (${student.studentId})</div>
              <div style="text-align: right;"><strong>Payment Method:</strong> ${escapeHTML(p.paymentMethod || 'UPI').toUpperCase()}</div>
            </div>
            <div style="border-top: 1px solid #eee; border-bottom: 1px solid #eee; padding: 10px 0; margin-bottom: 14px; display: flex; justify-content: space-between; font-size: 15px; font-weight: 700;">
              <span>Amount Paid:</span>
              <span style="color: #059669;">₹${p.finalAmount || p.amount}</span>
            </div>
            <div style="text-align: center; font-size: 11px; color: #888; margin-top: 12px;">
              Thank you for learning with us! This is a computer generated receipt.
            </div>
            <div class="d-flex justify-content-center gap-2 mt-4 no-print">
              <button class="btn btn-primary btn-sm" onclick="window.print()">🖨️ Print Receipt</button>
              <button class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">Close</button>
            </div>
          </div>
        `;
        new Modal({ title: `Receipt ${p.receiptNumber || ''}`, content: receiptHtml, size: 'sm' }).show();
      } catch (e) {
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
              <!-- Dynamic UPI QR Section -->
              <div style="text-align: center; margin-bottom: 1rem; background: #ffffff; padding: 14px; border-radius: 12px; border: 1px solid var(--color-border); box-shadow: var(--shadow-sm);">
                <div style="font-size: 0.78rem; font-weight: 700; color: #64748b; margin-bottom: 6px; text-transform: uppercase; letter-spacing: 0.5px;">
                  Scan & Pay via GPay / PhonePe / Paytm / BHIM
                </div>
                <img id="renewal-qr-img" src="${q.qrCodeUrl}" alt="UPI QR Code" style="width: 170px; height: 170px; margin: 0 auto; border-radius: 8px; display: block;">
                <div style="margin-top: 6px; font-size: 0.85rem; font-weight: 700; color: #1e293b;">
                  UPI ID: <span style="font-family: monospace; color: #6c5ce7;">${escapeHTML(q.upiId)}</span>
                </div>
                <a id="renewal-upi-link" href="${q.upiIntentUrl}" class="btn btn-sm btn-outline-primary mt-2" style="font-size: 0.8rem; display: inline-block;">
                  📲 Click to Pay directly on Mobile App (₹${q.totalPayable.toLocaleString('en-IN')})
                </a>
              </div>

              <!-- Submit UTR Form -->
              <form id="portal-renewal-submit-form">
                <div class="form-group mb-3">
                  <label class="form-label" style="font-weight: 700;">Enter UPI UTR / Transaction Reference No. *</label>
                  <input type="text" id="renewal-utr-input" class="form-control" placeholder="12-digit UTR No. (e.g. 423456789012)" required style="letter-spacing: 1px; font-weight: 600;">
                  <small class="text-muted" style="display: block; font-size: 0.75rem; margin-top: 4px;">Found in your payment app receipt under 'UPI Ref No / Transaction ID'.</small>
                </div>
                <div style="display: flex; gap: 8px; justify-content: flex-end;">
                  <button type="button" class="btn btn-secondary" onclick="Modal.closeAll()">Cancel</button>
                  <button type="submit" class="btn btn-primary" id="btn-submit-renewal-utr" style="font-weight: 700;">
                    ✅ Submit Payment & Renew
                  </button>
                </div>
              </form>
            `}
          </div>
        `;

        bindEvents();
      }

      function bindEvents() {
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

        const renewalSubmitForm = modalContent.querySelector('#portal-renewal-submit-form');
        if (renewalSubmitForm) {
          renewalSubmitForm.onsubmit = async (e) => {
            e.preventDefault();
            const utrInput = modalContent.querySelector('#renewal-utr-input');
            const utrNumber = utrInput ? utrInput.value.trim() : '';
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
                paymentMode: 'upi'
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
 * Generate 1080x1920px Offline Mobile ID Pass Canvas Image & Trigger Download
 */
export function download1080pMobileIDPass(student, business, initials, seatTitle, planName, expiryDateStr) {
  const canvas = document.createElement('canvas');
  canvas.width = 1080;
  canvas.height = 1920;
  const ctx = canvas.getContext('2d');

  // Background gradient (Vertical mobile wallpaper)
  const bgGrad = ctx.createLinearGradient(0, 0, 0, 1920);
  bgGrad.addColorStop(0, '#0f172a');
  bgGrad.addColorStop(0.5, '#1e1b4b');
  bgGrad.addColorStop(1, '#0f172a');
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, 1080, 1920);

  // Outer decorative accent circle
  ctx.beginPath();
  ctx.arc(540, -100, 600, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(108, 92, 231, 0.15)';
  ctx.fill();

  // Card Container (rounded rectangle)
  const cardX = 90, cardY = 160, cardW = 900, cardH = 1600, cardR = 40;
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(cardX + cardR, cardY);
  ctx.arcTo(cardX + cardW, cardY, cardX + cardW, cardY + cardH, cardR);
  ctx.arcTo(cardX + cardW, cardY + cardH, cardX, cardY + cardH, cardR);
  ctx.arcTo(cardX, cardY + cardH, cardX, cardY, cardR);
  ctx.arcTo(cardX, cardY, cardX + cardW, cardY, cardR);
  ctx.closePath();
  ctx.fillStyle = '#ffffff';
  ctx.shadowColor = 'rgba(0, 0, 0, 0.4)';
  ctx.shadowBlur = 40;
  ctx.shadowOffsetY = 20;
  ctx.fill();
  ctx.restore();

  // Card Header Banner (Gradient)
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(cardX + cardR, cardY);
  ctx.arcTo(cardX + cardW, cardY, cardX + cardW, cardY + 360, cardR);
  ctx.lineTo(cardX + cardW, cardY + 360);
  ctx.lineTo(cardX, cardY + 360);
  ctx.arcTo(cardX, cardY, cardX + cardR, cardY, cardR);
  ctx.closePath();
  const headerGrad = ctx.createLinearGradient(cardX, cardY, cardX + cardW, cardY + 360);
  headerGrad.addColorStop(0, '#6c5ce7');
  headerGrad.addColorStop(1, '#00b894');
  ctx.fillStyle = headerGrad;
  ctx.fill();
  ctx.restore();

  // Library Business Name
  ctx.fillStyle = '#ffffff';
  ctx.font = '800 48px Outfit, sans-serif';
  ctx.textAlign = 'center';
  ctx.fillText((business.businessName || 'STUDY LIBRARY').toUpperCase(), 540, cardY + 120);

  // Subtitle
  ctx.font = '600 28px Outfit, sans-serif';
  ctx.fillStyle = 'rgba(255, 255, 255, 0.9)';
  ctx.fillText('OFFLINE DIGITAL PASS', 540, cardY + 175);

  // Avatar Outer Circle
  const avatarX = 540, avatarY = cardY + 360, avatarR = 120;
  ctx.beginPath();
  ctx.arc(avatarX, avatarY, avatarR + 10, 0, Math.PI * 2);
  ctx.fillStyle = '#ffffff';
  ctx.fill();

  ctx.beginPath();
  ctx.arc(avatarX, avatarY, avatarR, 0, Math.PI * 2);
  ctx.fillStyle = '#f0f2f5';
  ctx.fill();

  // Initials inside circle
  ctx.fillStyle = '#6c5ce7';
  ctx.font = '800 84px Outfit, sans-serif';
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText(initials, avatarX, avatarY);

  // Reset text baseline
  ctx.textBaseline = 'alphabetic';

  // Student Name
  ctx.fillStyle = '#1e293b';
  ctx.font = '800 56px Outfit, sans-serif';
  ctx.fillText(student.name || 'Student Member', 540, cardY + 570);

  // Student ID Badge Pill
  const pillW = 420, pillH = 64, pillX = 540 - pillW / 2, pillY = cardY + 610, pillR = 16;
  ctx.save();
  ctx.beginPath();
  if (typeof ctx.roundRect === 'function') {
    ctx.roundRect(pillX, pillY, pillW, pillH, pillR);
  } else {
    ctx.rect(pillX, pillY, pillW, pillH);
  }
  ctx.fillStyle = '#eef2ff';
  ctx.fill();
  ctx.strokeStyle = '#6c5ce7';
  ctx.lineWidth = 2;
  ctx.stroke();
  ctx.restore();

  ctx.fillStyle = '#4338ca';
  ctx.font = '800 32px monospace';
  ctx.fillText(student.studentId || 'STU-MEMBER', 540, pillY + 44);

  // Details Data Box
  const boxX = cardX + 60, boxY = cardY + 720, boxW = cardW - 120, boxH = 500, boxR = 24;
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

  // Details Rows
  const labels = [
    { label: 'Assigned Desk:', val: seatTitle, color: '#6c5ce7' },
    { label: 'Study Plan:', val: planName, color: '#1e293b' },
    { label: 'Phone Number:', val: student.phone || '-', color: '#1e293b' },
    { label: 'Valid Till:', val: expiryDateStr, color: '#e53e3e' }
  ];

  labels.forEach((item, idx) => {
    const rowY = boxY + 80 + idx * 105;
    ctx.textAlign = 'left';
    ctx.fillStyle = '#64748b';
    ctx.font = '600 32px Outfit, sans-serif';
    ctx.fillText(item.label, boxX + 40, rowY);

    ctx.textAlign = 'right';
    ctx.fillStyle = item.color;
    ctx.font = '800 34px Outfit, sans-serif';
    ctx.fillText(item.val, boxX + boxW - 40, rowY);

    if (idx < labels.length - 1) {
      ctx.beginPath();
      ctx.moveTo(boxX + 30, rowY + 35);
      ctx.lineTo(boxX + boxW - 30, rowY + 35);
      ctx.strokeStyle = '#e2e8f0';
      ctx.lineWidth = 1;
      ctx.stroke();
    }
  });

  // QR Code Generation onto Canvas
  const qrData = JSON.stringify({
    type: 'STUDENT_ID',
    id: student.studentId,
    name: student.name,
    phone: student.phone
  });

  const triggerDownload = () => {
    const link = document.createElement('a');
    link.download = `${(student.name || 'Student').replace(/\s+/g, '_')}_Mobile_ID_Pass_1080x1920.png`;
    link.href = canvas.toDataURL('image/png');
    document.body.appendChild(link);
    link.click();
    link.remove();
    Toast.success('📱 1080x1920px Mobile ID Pass image generated & downloaded!');
  };

  const qrImg = new Image();
  qrImg.crossOrigin = 'anonymous';
  qrImg.onload = () => {
    const qrSize = 240;
    const qrX = 540 - qrSize / 2;
    const qrY = cardY + 1260;
    ctx.drawImage(qrImg, qrX, qrY, qrSize, qrSize);

    ctx.textAlign = 'center';
    ctx.fillStyle = '#64748b';
    ctx.font = '600 24px Outfit, sans-serif';
    ctx.fillText(`Carry Daily on Mobile • Helpdesk: ${business.phone || ''}`, 540, cardY + 1540);

    triggerDownload();
  };
  qrImg.onerror = () => {
    ctx.textAlign = 'center';
    ctx.fillStyle = '#64748b';
    ctx.font = '600 24px Outfit, sans-serif';
    ctx.fillText(`Carry Daily on Mobile • Helpdesk: ${business.phone || ''}`, 540, cardY + 1540);

    triggerDownload();
  };
  qrImg.src = `https://api.qrserver.com/v1/create-qr-code/?size=240x240&data=${encodeURIComponent(qrData)}&margin=4`;
}

