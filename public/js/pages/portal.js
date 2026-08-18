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

    renderPortalUI(container, res.data);
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

function renderPortalUI(container, data) {
  const { student, business, daysRemaining, totalHours, todayAttendance, payments } = data;

  const initials = (student.name || 'S')
    .split(' ')
    .map(n => n[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);

  const seatNumber = student.seat?.seatNumber || 'Floating / Not Assigned';
  const seatZone = student.seat?.zone || 'General';
  const planName = student.plan?.name || 'Standard Reading Room Plan';
  const planPrice = student.plan?.price || 0;
  const expiryDateStr = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : 'Not Set';

  const examTags = (student.targetExams && student.targetExams.length > 0)
    ? student.targetExams.map(ex => `<span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary); font-size: 0.75rem;">${escapeHTML(ex)}</span>`).join('')
    : '<span class="text-muted small">General Self-Study</span>';

  const isCheckedIn = todayAttendance && todayAttendance.checkIn && !todayAttendance.checkOut;
  const punchStatusText = isCheckedIn
    ? `🟢 Currently Checked In since ${todayAttendance.checkIn}`
    : todayAttendance && todayAttendance.checkOut
    ? `✅ Completed study session today (${todayAttendance.checkIn} - ${todayAttendance.checkOut})`
    : `⚪ Not checked in today`;

  container.innerHTML = `
    <!-- Top Welcome Banner -->
    <div class="card mb-4" style="
      background: linear-gradient(135deg, rgba(108, 92, 231, 0.15), rgba(162, 155, 254, 0.05)), var(--color-surface);
      border: 1px solid var(--color-border);
      border-radius: var(--radius-lg);
      padding: 1.75rem;
    ">
      <div style="display: flex; align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 1.25rem;">
        <div style="display: flex; align-items: center; gap: 1.25rem;">
          <div style="
            width: 72px; height: 72px; border-radius: 50%;
            background: var(--color-primary-bg); color: var(--color-primary);
            font-size: 1.6rem; font-weight: 800; display: flex; align-items: center; justify-content: center;
            border: 2px solid var(--color-primary); flex-shrink: 0;
          ">
            ${initials}
          </div>
          <div>
            <h2 style="margin: 0 0 4px 0; font-size: 1.45rem; font-weight: 700; color: var(--color-text-primary);">
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

        <div style="display: flex; gap: 0.5rem; flex-wrap: wrap;">
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

    <!-- 3 Stat Widgets Grid -->
    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.25rem; margin-bottom: 1.5rem;">
      
      <!-- Seat Card -->
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="text-muted small mb-1">💺 Assigned Study Desk</div>
        <div style="display: flex; align-items: baseline; gap: 8px;">
          <span style="font-size: 1.8rem; font-weight: 800; color: var(--color-primary);">${escapeHTML(seatNumber)}</span>
          <span class="text-muted small">(${escapeHTML(seatZone)})</span>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-top: 6px;">
          Dedicated quiet cabin seat with power socket & lamp.
        </div>
      </div>

      <!-- Plan Expiry Card -->
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="text-muted small mb-1">⏳ Membership Validity</div>
        <div style="display: flex; align-items: baseline; gap: 8px;">
          <span style="font-size: 1.8rem; font-weight: 800; color: ${daysRemaining <= 3 ? 'var(--color-danger)' : 'var(--color-success)'};">
            ${daysRemaining} Days
          </span>
          <span class="text-muted small">left</span>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-top: 6px;">
          Plan: <strong>${escapeHTML(planName)}</strong> (Valid till ${expiryDateStr})
        </div>
      </div>

      <!-- Study Hours Card -->
      <div class="card p-4" style="background: var(--color-surface); border: 1px solid var(--color-border); border-radius: var(--radius-lg);">
        <div class="text-muted small mb-1">📈 Total Study Time</div>
        <div style="display: flex; align-items: baseline; gap: 8px;">
          <span style="font-size: 1.8rem; font-weight: 800; color: var(--color-info);">${totalHours} hrs</span>
          <span class="text-muted small">logged</span>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-top: 6px;">
          Consistency score: <strong>94% Present</strong> this month.
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
          ${isCheckedIn ? '🔴 Punch-Out Now' : '🟢 Punch-In (Check In)'}
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
    import('./students.js').then(m => {
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

  // Attach Referral Modal
  container.querySelector('#btn-portal-referral')?.addEventListener('click', async () => {
    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <div class="card p-3 mb-3" style="background: rgba(108, 92, 231, 0.1); border: 1px dashed var(--color-primary); border-radius: 8px;">
        <div class="d-flex align-items-center gap-2">
          <div style="font-size: 1.8rem;">🎁</div>
          <div>
            <strong style="color: var(--color-primary); font-size: 0.95rem;">Refer a Friend & Earn ₹100 Discount!</strong>
            <p style="margin: 0; font-size: 0.8rem; color: var(--color-text-secondary);">When your friend joins the study hall, you both receive a ₹100 discount on your next renewal.</p>
          </div>
        </div>
      </div>

      <form id="portal-ref-form" class="p-1 mb-4">
        <div class="row g-2 mb-3" style="display: grid; grid-template-columns: 1fr 1fr; gap: 0.75rem;">
          <div>
            <label class="form-label" style="font-weight: 600;">Friend's Full Name *</label>
            <input type="text" id="ref-name" class="form-control" placeholder="Friend Name" required>
          </div>
          <div>
            <label class="form-label" style="font-weight: 600;">Friend's Mobile No. *</label>
            <input type="tel" id="ref-phone" class="form-control" placeholder="10 digit number" required>
          </div>
        </div>
        <div class="form-group mb-3">
          <label class="form-label" style="font-weight: 600;">Target Exam / Course</label>
          <input type="text" id="ref-notes" class="form-control" placeholder="e.g. UPSC, MPSC, CA Inter">
        </div>
        <div class="d-flex justify-content-end gap-2">
          <button type="submit" class="btn btn-primary" id="btn-submit-ref">Submit Referral</button>
        </div>
      </form>

      <h5 style="font-size: 0.95rem; font-weight: 700; border-top: 1px solid var(--color-border); padding-top: 12px; margin-bottom: 8px;">🎉 My Referral Rewards</h5>
      <div id="portal-ref-history" style="max-height: 200px; overflow-y: auto;">
        <div class="text-center p-3 text-muted">Loading referrals...</div>
      </div>
    `;

    const refModal = new Modal({ title: '🎁 Refer a Friend Program', content: modalContent, size: 'md' });
    refModal.show();

    async function loadRefHistory() {
      const histContainer = modalContent.querySelector('#portal-ref-history');
      try {
        const res = await api.get('/api/student-portal/referrals');
        const list = res.data || [];
        if (list.length === 0) {
          histContainer.innerHTML = `<p class="text-muted small text-center p-2">No friend referrals submitted yet. Start inviting friends!</p>`;
          return;
        }
        histContainer.innerHTML = list.map(r => `
          <div class="p-2 mb-2" style="background: var(--color-bg-primary); border-radius: 6px; border: 1px solid var(--color-border); font-size: 0.85rem;">
            <div class="d-flex justify-content-between align-items-center mb-1">
              <strong>${escapeHTML(r.refereeName)} (${escapeHTML(r.refereePhone)})</strong>
              <span class="badge ${r.status === 'converted' || r.status === 'rewarded' ? 'badge-success' : 'badge-warning'}" style="text-transform: uppercase; font-size: 0.7rem;">
                ${r.status}
              </span>
            </div>
            <div class="text-muted small">Reward: <strong>${escapeHTML(r.reward || '₹100 Discount')}</strong></div>
          </div>
        `).join('');
      } catch (e) {
        histContainer.innerHTML = `<p class="text-danger small text-center">Failed to load history</p>`;
      }
    }

    modalContent.querySelector('#portal-ref-form').onsubmit = async (e) => {
      e.preventDefault();
      const refereeName = modalContent.querySelector('#ref-name').value.trim();
      const refereePhone = modalContent.querySelector('#ref-phone').value.trim();
      const notes = modalContent.querySelector('#ref-notes').value.trim();

      try {
        await api.post('/api/student-portal/referral', { refereeName, refereePhone, notes });
        Toast.success('Referral logged! We will contact your friend.');
        modalContent.querySelector('#ref-name').value = '';
        modalContent.querySelector('#ref-phone').value = '';
        loadRefHistory();
      } catch (err) {
        Toast.error(err.message || 'Failed to submit referral');
      }
    };

    loadRefHistory();
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
          // Reload portal
          renderPortalUI(container, (await api.get('/api/student-portal/dashboard')).data);
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
