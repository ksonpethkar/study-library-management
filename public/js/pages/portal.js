import api from '../api.js';
import { Toast, Modal, Confirm, Loading, escapeHTML } from '../ui.js';
import { t } from '../i18n.js';
import { generateAdmissionFormPDF, previewAdmissionFormPDF } from '../pdfGenerator.js';

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';
  container.style.cssText = 'max-width: 1100px; margin: 0 auto; padding-bottom: 3rem;';

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
            border: 2px solid var(--color-primary); flex-shrink: 0;
          ">
            ${initials}
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
        <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
          <button id="btn-portal-leave" class="btn btn-outline-secondary btn-sm" style="font-weight: 600;">
            🌴 Request Leave
          </button>
          <button id="btn-portal-seat-change" class="btn btn-outline-secondary btn-sm" style="font-weight: 600;">
            💺 Change Seat
          </button>
          <button id="btn-portal-referral" class="btn btn-outline-secondary btn-sm" style="font-weight: 600;">
            🎁 Refer Friend
          </button>
          <button id="btn-portal-idcard" class="btn btn-outline-primary btn-sm" style="font-weight: 600;">
            🪪 Digital ID
          </button>
          <button id="btn-portal-download-pdf" class="btn btn-outline-success btn-sm" style="font-weight: 600;">
            📄 Download PDF Form
          </button>
          <button id="btn-portal-renew" class="btn btn-primary btn-sm" style="font-weight: 600;">
            ⚡ Renew Plan
          </button>
        </div>
      </div>
    </div>

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
                  <td style="padding: 12px 16px; font-family: monospace; font-weight: 700;">${escapeHTML(p.receiptNumber || 'REC')}</td>
                  <td style="padding: 12px 16px;">${new Date(p.paymentDate).toLocaleDateString('en-IN')}</td>
                  <td style="padding: 12px 16px; text-transform: uppercase;">${escapeHTML(p.paymentMethod || 'UPI')}</td>
                  <td style="padding: 12px 16px; font-weight: 700; color: var(--color-success);">₹${p.finalAmount}</td>
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

  // Attach PDF Admission Form Download Handler
  container.querySelector('#btn-portal-download-pdf')?.addEventListener('click', () => {
    previewAdmissionFormPDF(student, { business });
  });

  // Attach ID Card Handler
  container.querySelector('#btn-portal-idcard')?.addEventListener('click', () => {
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
              <div style="display: flex; justify-content: space-between;"><strong>Assigned Seat:</strong> <span style="font-weight: 700; color: #6c5ce7;">${escapeHTML(seatNumber)}</span></div>
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

        <div class="d-flex justify-content-center gap-3 mt-4">
          <button class="btn btn-primary" onclick="window.print()">🖨️ Print ID Card</button>
          <button class="btn btn-secondary modal-close-btn" onclick="Modal.close()">Close</button>
        </div>
      </div>
    `;

    new Modal({ title: `Student ID Card`, content: modalContent, size: 'md' }).show();
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
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Preferred Seat Zone *</label>
          <select id="sc-zone" class="form-select" required>
            <option value="AC Zone">AC Zone (Quiet Cabin)</option>
            <option value="Non-AC Zone">Non-AC Zone</option>
            <option value="Private Cabins">Private Cabins</option>
            <option value="Open Hall">Open Hall</option>
            <option value="Ladies Reserved">Ladies Reserved Zone</option>
            <option value="Laptop Desks">Laptop Desk (Extra Power Plugs)</option>
          </select>
        </div>
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Reason for Seat Transfer *</label>
          <textarea id="sc-reason" class="form-control" rows="2" placeholder="e.g. Need AC cabin with direct charging port for laptop" required></textarea>
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="submit" class="btn btn-primary" id="btn-submit-sc">Submit Transfer Request</button>
        </div>
      </form>

      <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-border); padding-top: 12px; margin-bottom: 8px;">📋 Past Transfer Requests</h5>
      <div id="portal-sc-history" style="max-height: 200px; overflow-y: auto;">
        <div class="text-center p-3 text-muted">Loading requests...</div>
      </div>
    `;

    const scModal = new Modal({ title: '💺 Request Desk / Seat Transfer', content: modalContent, size: 'md' });
    scModal.show();

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
              <strong>Requested: ${escapeHTML(s.preferredZone)}</strong>
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
      const preferredZone = modalContent.querySelector('#sc-zone').value;
      const reason = modalContent.querySelector('#sc-reason').value.trim();

      try {
        await api.post('/api/student-portal/seat-change', { preferredZone, reason });
        Toast.success('Transfer request submitted to manager!');
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
      modalContent.querySelector('#btn-copy-ref-code')?.addEventListener('click', () => {
        navigator.clipboard.writeText(referralCode);
        Toast.success('Referral code copied to clipboard!');
      });

      // Copy Share Link
      modalContent.querySelector('#btn-copy-ref-link')?.addEventListener('click', () => {
        navigator.clipboard.writeText(shareUrl);
        Toast.success('Direct admission link copied to clipboard!');
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

  // Renew Membership Plan with Dynamic UPI QR Code
  container.querySelector('#btn-portal-renew')?.addEventListener('click', async () => {
    try {
      const quoteRes = await api.get('/api/student-portal/renewal-quote');
      if (!quoteRes.success) throw new Error(quoteRes.message);
      const q = quoteRes.data;

      const modalContent = document.createElement('div');
      modalContent.innerHTML = `
        <div style="font-family: 'Outfit', sans-serif;">
          <div style="text-align: center; margin-bottom: 1.25rem;">
            <span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-weight: 700; font-size: 0.85rem; padding: 4px 12px;">
              ⚡ Instant 1-Month Self-Renewal
            </span>
            <h3 style="margin: 8px 0 4px 0; font-size: 1.3rem; font-weight: 800; color: var(--color-text-primary);">
              ${escapeHTML(q.planName)}
            </h3>
            <p class="text-muted small" style="margin: 0;">Extends membership by ${q.durationDays} days from expiry.</p>
          </div>

          <!-- Fee Calculation Table -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: var(--radius-md); padding: 12px 16px; margin-bottom: 1.25rem;">
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

          <!-- Dynamic UPI QR Section -->
          <div style="text-align: center; margin-bottom: 1.25rem; background: #ffffff; padding: 14px; border-radius: 12px; border: 1px solid var(--color-border); box-shadow: var(--shadow-sm);">
            <div style="font-size: 0.8rem; font-weight: 700; color: #64748b; margin-bottom: 8px; text-transform: uppercase; letter-spacing: 0.5px;">
              Scan & Pay via GPay / PhonePe / Paytm / BHIM
            </div>
            <img src="${q.qrCodeUrl}" alt="UPI QR Code" style="width: 180px; height: 180px; margin: 0 auto; border-radius: 8px; display: block;">
            <div style="margin-top: 8px; font-size: 0.85rem; font-weight: 700; color: #1e293b;">
              UPI ID: <span style="font-family: monospace; color: #6c5ce7;">${escapeHTML(q.upiId)}</span>
            </div>
            <a href="${q.upiIntentUrl}" class="btn btn-sm btn-outline-primary mt-2" style="font-size: 0.8rem; display: inline-block;">
              📲 Click to Pay directly on Mobile App
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
              <button type="submit" class="btn btn-primary" id="btn-submit-renewal-utr">
                ✅ Submit Payment & Renew
              </button>
            </div>
          </form>
        </div>
      `;

      const renewModal = new Modal({ title: '💳 Membership Self-Renewal', content: modalContent, size: 'md' });
      renewModal.show();

      modalContent.querySelector('#portal-renewal-submit-form').onsubmit = async (e) => {
        e.preventDefault();
        const utrNumber = modalContent.querySelector('#renewal-utr-input').value.trim();
        const btn = modalContent.querySelector('#btn-submit-renewal-utr');
        Loading.button(btn, true);

        try {
          const renewRes = await api.post('/api/student-portal/renewal-request', {
            utrNumber,
            amountPaid: q.totalPayable,
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
