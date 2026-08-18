import { App } from '../app.js';
import { t } from '../i18n.js';
import { Toast, Modal, Loading, Confirm, escapeHTML } from '../ui.js';
import { SignatureStudio } from '../signatureStudio.js';
import { MediaStudio, MediaFieldPicker } from '../mediaStudio.js';
import api from '../api.js';
import { generateAdmissionFormPDF } from '../pdfGenerator.js';

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';
  
  // Standard Module Header
  const header = document.createElement('div');
  header.className = 'module-header';
  header.innerHTML = `
    <div class="module-title-area">
      <h2>👥 ${t('Students Directory')}</h2>
      <p>Manage student admissions, memberships, identity proofs, and academic records.</p>
    </div>
    <div class="module-actions">
      <button id="addStudentBtn" class="btn btn-primary d-flex align-items-center gap-2" style="font-weight: 700;">
        <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
        ${t('+ Add Student')}
      </button>
    </div>
  `;
  container.appendChild(header);

  // Standard KPI Stats Grid
  const statsContainer = document.createElement('div');
  statsContainer.className = 'kpi-grid';
  statsContainer.id = 'students-stats';
  container.appendChild(statsContainer);
  
  // Filters and Data Table Card
  const contentCard = document.createElement('div');
  contentCard.className = 'card';
  
  const filterRow = document.createElement('div');
  filterRow.className = 'card-header d-flex justify-content-between align-items-center flex-wrap gap-3';
  filterRow.innerHTML = `
    <div class="search-box" style="flex: 1; max-width: 360px;">
      <input type="text" id="studentSearch" class="form-control form-control-sm" placeholder="${t('Search by name, phone, student ID...')}" />
    </div>
    <div class="filter-box d-flex gap-2 align-items-center">
      <label class="form-label mb-0 text-xs" style="font-weight: 700; color: var(--color-text-secondary);">STATUS:</label>
      <select id="studentStatusFilter" class="form-select form-control form-control-sm" style="width: 160px; font-weight: 600;">
        <option value="all">${t('All Status')}</option>
        <option value="active">🟢 ${t('Active')}</option>
        <option value="inactive">⚪ ${t('Inactive')}</option>
        <option value="pending_payment">⏳ Pending Fee</option>
        <option value="suspended">🟡 ${t('Suspended')}</option>
        <option value="expired">🔴 ${t('Expired')}</option>
      </select>
    </div>
  `;
  contentCard.appendChild(filterRow);
  
  const tableContainer = document.createElement('div');
  tableContainer.className = 'card-body p-0';
  tableContainer.id = 'students-table-container';
  contentCard.appendChild(tableContainer);
  
  container.appendChild(contentCard);
  
  const state = {
    students: [],
    pagination: { page: 1, limit: 10, total: 0, pages: 1 }
  };

  async function loadStats() {
    try {
      const res = await api.get('/api/students/stats');
      if (res.success && res.data) {
        const stats = res.data;
        statsContainer.innerHTML = `
          <div class="kpi-card kpi-primary">
            <div class="kpi-label">${t('Total Students')} <span>👥</span></div>
            <div class="kpi-value">${stats.total || 0}</div>
            <div class="kpi-subtext">All registered members</div>
          </div>
          <div class="kpi-card kpi-success">
            <div class="kpi-label">${t('Active Members')} <span>🟢</span></div>
            <div class="kpi-value text-success">${stats.active || 0}</div>
            <div class="kpi-subtext">Currently studying</div>
          </div>
          <div class="kpi-card kpi-danger">
            <div class="kpi-label">${t('Expired / Due')} <span>🔴</span></div>
            <div class="kpi-value text-danger">${stats.expired || 0}</div>
            <div class="kpi-subtext">Needs membership renewal</div>
          </div>
          <div class="kpi-card kpi-info">
            <div class="kpi-label">${t('New This Month')} <span>✨</span></div>
            <div class="kpi-value" style="color: var(--color-info);">${stats.newThisMonth || 0}</div>
            <div class="kpi-subtext">Recent admissions</div>
          </div>
        `;
      }
    } catch (err) {
      console.error(err);
    }
  }

  async function loadStudents(page = 1) {
    const search = container.querySelector('#studentSearch')?.value || '';
    const status = container.querySelector('#studentStatusFilter')?.value || 'all';
    
    tableContainer.innerHTML = '<div class="text-center p-5 text-muted">Loading students...</div>';
    try {
      const res = await api.get('/api/students', { page, limit: 10, search, status });
      if (res.success && res.data) {
        state.students = res.data.students || [];
        state.pagination = res.data.pagination || { page: 1, limit: 10, total: 0, pages: 1 };
        renderTable();
      }
    } catch (err) {
      Toast.error(err.message || 'Failed to load students');
      tableContainer.innerHTML = '<div class="text-center p-5 text-muted">Error loading students list.</div>';
    }
  }

  function renderTable() {
    if (state.students.length === 0) {
      tableContainer.innerHTML = `<div class="empty-state p-5 text-center text-muted">No students found. Click "Add Student" to enroll the first member.</div>`;
      return;
    }

    let rowsHtml = state.students.map(s => {
      let statusStyle = 'background: rgba(255,255,255,0.08); color: #ccc;';
      if (s.status === 'active') statusStyle = 'background: rgba(0, 184, 148, 0.2); color: var(--color-success, #00b894);';
      else if (s.status === 'pending_payment' || s.status === 'pending') statusStyle = 'background: rgba(245, 158, 11, 0.2); color: var(--color-warning, #f59e0b);';
      else if (s.status === 'expired') statusStyle = 'background: rgba(214, 48, 49, 0.2); color: var(--color-danger, #d63031);';
      else if (s.status === 'suspended') statusStyle = 'background: rgba(253, 203, 110, 0.2); color: var(--color-warning, #fdcb6e);';

      const planName = s.plan?.name || '-';
      const seatNum = s.seat?.seatNumber || '-';
      const expiry = s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : '-';

      return `
        <tr>
          <td style="width: 38px; text-align: center;">
            <input type="checkbox" class="student-select-cb" data-id="${escapeHTML(s._id)}" style="cursor: pointer;">
          </td>
          <td><span style="font-family: monospace; font-weight: 700;">${escapeHTML(s.studentId || '-')}</span></td>
          <td><strong>${escapeHTML(s.name || '-')}</strong></td>
          <td>${escapeHTML(s.phone || '-')}</td>
          <td><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary, #6c5ce7); font-weight: 600;">${escapeHTML(planName)}</span></td>
          <td><span class="badge" style="background: rgba(0, 184, 148, 0.15); color: var(--color-success, #00b894); font-weight: 600;">${escapeHTML(seatNum)}</span></td>
          <td>${expiry}</td>
          <td><span class="badge" style="${statusStyle} padding: 4px 8px; border-radius: 4px; font-weight: 600; text-transform: uppercase; font-size: 0.75rem;">${escapeHTML(s.status || 'active')}</span></td>
          <td>
            <div class="d-flex gap-1">
              <button class="btn btn-sm btn-outline-secondary btn-view" data-id="${escapeHTML(s._id)}" title="View 360° Profile" style="padding: 3px 7px; font-size: 0.75rem;">👁️ View</button>
              <button class="btn btn-sm btn-outline-info btn-idcard" data-id="${escapeHTML(s._id)}" title="Print ID Card" style="padding: 3px 7px; font-size: 0.75rem;">🪪 ID</button>
              <button class="btn btn-sm btn-outline-success btn-pdfform" data-id="${escapeHTML(s._id)}" title="Download PDF Admission Form" style="padding: 3px 7px; font-size: 0.75rem;">📄 PDF</button>
              <button class="btn btn-sm btn-outline-primary btn-edit" data-id="${escapeHTML(s._id)}" style="padding: 3px 7px; font-size: 0.75rem;">✏️ Edit</button>
              <button class="btn btn-sm btn-outline-danger btn-delete" data-id="${escapeHTML(s._id)}" style="padding: 3px 7px; font-size: 0.75rem;">🗑️ Delete</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');

    tableContainer.innerHTML = `
      <!-- Floating Bulk Action Bar -->
      <div id="bulk-actions-bar" style="display: none; padding: 0.75rem 1.25rem; background: var(--color-surface); border-bottom: 2px solid var(--color-primary); justify-content: space-between; align-items: center; flex-wrap: wrap; gap: 0.75rem;">
        <div class="d-flex align-items-center gap-2">
          <span class="badge badge-primary" id="selected-count-badge">0 selected</span>
          <span class="text-muted small">Bulk Actions:</span>
        </div>
        <div class="d-flex gap-2 flex-wrap">
          <button class="btn btn-sm btn-outline-success" id="btn-bulk-whatsapp" style="font-size: 0.8rem; font-weight: 600;">
            📲 WhatsApp Reminders
          </button>
          <button class="btn btn-sm btn-outline-primary" id="btn-bulk-renew" style="font-size: 0.8rem; font-weight: 600;">
            🔄 Bulk Renew (+30d)
          </button>
          <button class="btn btn-sm btn-outline-secondary" id="btn-bulk-export" style="font-size: 0.8rem; font-weight: 600;">
            📄 Export Selected
          </button>
          <button class="btn btn-sm btn-outline-danger" id="btn-bulk-deactivate" style="font-size: 0.8rem; font-weight: 600;">
            🗑️ Deactivate Selected
          </button>
        </div>
      </div>

      <div class="table-responsive">
        <table class="table data-table mb-0">
          <thead>
            <tr>
              <th style="width: 38px; text-align: center;">
                <input type="checkbox" id="selectAllStudents" style="cursor: pointer;">
              </th>
              <th>Student ID</th>
              <th>Name</th>
              <th>Phone</th>
              <th>Plan</th>
              <th>Seat</th>
              <th>Expiry Date</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            ${rowsHtml}
          </tbody>
        </table>
      </div>
    `;

    // Bulk action bar logic
    const selectAll = tableContainer.querySelector('#selectAllStudents');
    const cbs = tableContainer.querySelectorAll('.student-select-cb');
    const bulkBar = tableContainer.querySelector('#bulk-actions-bar');
    const countBadge = tableContainer.querySelector('#selected-count-badge');

    function updateBulkBar() {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length > 0) {
        bulkBar.style.display = 'flex';
        countBadge.textContent = `${selected.length} student(s) selected`;
      } else {
        bulkBar.style.display = 'none';
      }
    }

    if (selectAll) {
      selectAll.addEventListener('change', () => {
        cbs.forEach(cb => cb.checked = selectAll.checked);
        updateBulkBar();
      });
    }

    cbs.forEach(cb => {
      cb.addEventListener('change', () => {
        if (!cb.checked && selectAll) selectAll.checked = false;
        updateBulkBar();
      });
    });

    // Bulk WhatsApp Reminders
    tableContainer.querySelector('#btn-bulk-whatsapp')?.addEventListener('click', async () => {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length === 0) return;
      try {
        const res = await api.post('/api/students/bulk-remind', { studentIds: selected });
        if (res.success && res.data) {
          const links = res.data;
          // Open the first WhatsApp link and toast the rest
          if (links[0]?.whatsappUrl) window.open(links[0].whatsappUrl, '_blank');
          Toast.success(`WhatsApp reminder opened for ${links[0]?.name}. (${links.length} total prepared)`);
        }
      } catch (err) {
        Toast.error('Failed to generate reminders');
      }
    });

    // Bulk Renew
    tableContainer.querySelector('#btn-bulk-renew')?.addEventListener('click', async () => {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length === 0) return;
      const ok = await Confirm.show({
        title: 'Bulk Renew Memberships',
        message: `Are you sure you want to extend validity by 30 days for ${selected.length} selected student(s)?`
      });
      if (ok) {
        try {
          const res = await api.post('/api/students/bulk-renew', { studentIds: selected, days: 30 });
          Toast.success(res.message);
          loadStudents(state.pagination.page);
          loadStats();
        } catch (err) {
          Toast.error(err.message || 'Bulk renew failed');
        }
      }
    });

    // Bulk Deactivate
    tableContainer.querySelector('#btn-bulk-deactivate')?.addEventListener('click', async () => {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length === 0) return;
      const ok = await Confirm.show({
        title: 'Bulk Deactivate',
        message: `Are you sure you want to mark ${selected.length} student(s) as inactive?`,
        danger: true
      });
      if (ok) {
        try {
          const res = await api.post('/api/students/bulk-deactivate', { studentIds: selected });
          Toast.success(res.message);
          loadStudents(state.pagination.page);
          loadStats();
        } catch (err) {
          Toast.error(err.message || 'Bulk deactivation failed');
        }
      }
    });

    // Bulk Export
    tableContainer.querySelector('#btn-bulk-export')?.addEventListener('click', () => {
      const selected = Array.from(cbs).filter(cb => cb.checked).map(cb => cb.dataset.id);
      if (selected.length === 0) return;
      const selectedStudents = state.students.filter(s => selected.includes(s._id));
      const headers = ['ID', 'Name', 'Phone', 'Email', 'Plan', 'Seat', 'Expiry', 'Status'];
      const rows = selectedStudents.map(s => [
        s.studentId,
        `"${s.name}"`,
        s.phone,
        s.email || '',
        s.plan?.name || '',
        s.seat?.seatNumber || '',
        s.expiryDate ? new Date(s.expiryDate).toLocaleDateString('en-IN') : '',
        s.status
      ]);
      const csv = 'data:text/csv;charset=utf-8,' + [headers.join(','), ...rows.map(r => r.join(','))].join('\n');
      const a = document.createElement('a');
      a.href = encodeURI(csv);
      a.download = `selected_students_${Date.now()}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      Toast.success(`Exported ${selected.length} students to CSV`);
    });

    // Pagination
    if (state.pagination.pages > 1) {
      const paginationDiv = document.createElement('div');
      paginationDiv.className = 'd-flex justify-content-between align-items-center p-3 border-top';
      
      const prevBtn = document.createElement('button');
      prevBtn.className = 'btn btn-sm btn-outline-secondary';
      prevBtn.textContent = 'Previous';
      prevBtn.disabled = state.pagination.page <= 1;
      prevBtn.onclick = () => loadStudents(state.pagination.page - 1);

      const nextBtn = document.createElement('button');
      nextBtn.className = 'btn btn-sm btn-outline-secondary';
      nextBtn.textContent = 'Next';
      nextBtn.disabled = state.pagination.page >= state.pagination.pages;
      nextBtn.onclick = () => loadStudents(state.pagination.page + 1);
      
      const pageInfo = document.createElement('span');
      pageInfo.className = 'text-muted small';
      pageInfo.textContent = `Page ${state.pagination.page} of ${state.pagination.pages} (${state.pagination.total} total)`;
      
      paginationDiv.appendChild(prevBtn);
      paginationDiv.appendChild(pageInfo);
      paginationDiv.appendChild(nextBtn);
      
      tableContainer.appendChild(paginationDiv);
    }
  }

  async function showStudentForm(student = null) {
    const isEdit = !!student;
    
    // Fetch available plans and seats
    let plansOptions = '<option value="">-- Select Plan (Optional) --</option>';
    let seatsOptions = '<option value="">-- Select Seat (Optional) --</option>';
    let customFields = [];
    
    try {
      const [plansRes, seatsRes, cfRes] = await Promise.all([
        api.get('/api/plans'),
        api.get('/api/seats?status=available'),
        api.get('/api/custom-fields')
      ]);
      
      if (plansRes.success && plansRes.data) {
        plansRes.data.forEach(p => {
          const selected = (student && student.plan && (student.plan._id === p._id || student.plan === p._id)) ? 'selected' : '';
          plansOptions += `<option value="${p._id}" ${selected}>${escapeHTML(p.name)} - ₹${p.price} (${p.duration} ${p.durationType})</option>`;
        });
      }
      
      if (seatsRes.success && seatsRes.data) {
        seatsRes.data.forEach(s => {
          const selected = (student && student.seat && (student.seat._id === s._id || student.seat === s._id)) ? 'selected' : '';
          seatsOptions += `<option value="${s._id}" ${selected}>${escapeHTML(s.seatNumber)} (${escapeHTML(s.zone)} - ${escapeHTML(s.type)})</option>`;
        });
      }
      // If editing and student already has a seat, add that seat to the options
      if (student && student.seat && typeof student.seat === 'object') {
        if (!seatsOptions.includes(student.seat._id)) {
          seatsOptions += `<option value="${student.seat._id}" selected>${escapeHTML(student.seat.seatNumber)} (Current)</option>`;
        }
      }

      if (cfRes?.success && cfRes?.data) {
        customFields = cfRes.data;
      }
    } catch (err) {
      console.error('Error fetching plans/seats/custom-fields for student form:', err);
    }

    let customFieldsHtml = '';
    if (customFields && customFields.length > 0) {
      const systemFields = ['name', 'phone', 'email', 'gender', 'dateOfBirth', 'bloodGroup', 'photo', 'targetExams', 'occupation', 'address', 'city', 'state', 'pincode', 'signature', 'emergencyContactName', 'emergencyContactPhone', 'emergencyContactRelation', 'idProofType', 'idProofNumber', 'idProofImage', 'rfidCardNumber', 'biometricId'];
      const filteredFields = customFields.filter(f => !systemFields.includes(f.fieldName));
      
      if (filteredFields.length > 0) {
        // Group by section
        const sections = {};
        filteredFields.forEach(f => {
          const sec = f.sectionLabel || 'Additional Information';
          if (!sections[sec]) sections[sec] = [];
          sections[sec].push(f);
        });
        
        for (const [secName, fields] of Object.entries(sections)) {
          customFieldsHtml += `
            <div class="col-12 mt-2">
              <h5 style="font-size: 0.95rem; font-weight: 600; margin-bottom: 8px; border-bottom: 1px solid var(--color-divider); padding-bottom: 4px;">📝 ${escapeHTML(secName)}</h5>
            </div>
          `;
          
          customFieldsHtml += fields.map(f => {
            const val = student?.customFields?.[f.fieldName] !== undefined ? student.customFields[f.fieldName] : '';
            if (f.type === 'textarea') {
              return `
                <div class="col-12">
                  <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)} ${f.required ? '*' : ''}</label>
                  <textarea class="form-control custom-field-input" data-field="${escapeHTML(f.fieldName)}" ${f.required ? 'required' : ''} placeholder="${escapeHTML(f.placeholder || '')}">${escapeHTML(val)}</textarea>
                </div>
              `;
            } else if (f.type === 'select') {
              return `
                <div class="col-md-6">
                  <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)} ${f.required ? '*' : ''}</label>
                  <select class="form-select form-control custom-field-input" data-field="${escapeHTML(f.fieldName)}" ${f.required ? 'required' : ''}>
                    <option value="">-- Select --</option>
                    ${(f.options || []).map(opt => `<option value="${escapeHTML(opt)}" ${val === opt ? 'selected' : ''}>${escapeHTML(opt)}</option>`).join('')}
                  </select>
                </div>
              `;
            } else if (f.type === 'photo_upload' || f.type === 'file') {
              return `
                <div class="col-md-6">
                  <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)} ${f.required ? '*' : ''}</label>
                  <div class="custom-field-media-mount" data-field="${escapeHTML(f.fieldName)}" data-label="${escapeHTML(f.label)}" data-preset="${f.type === 'photo_upload' ? 'passport' : 'document'}"></div>
                </div>
              `;
            } else if (f.type === 'checkbox') {
              return `
                <div class="col-md-6 d-flex align-items-center mt-2">
                  <label style="display: flex; align-items: center; gap: 0.5rem; cursor: pointer; font-weight: 500;">
                    <input type="checkbox" class="form-checkbox custom-field-input" data-field="${escapeHTML(f.fieldName)}" ${(val === true || val === 'true') ? 'checked' : ''}>
                    <span>${escapeHTML(f.label)}</span>
                  </label>
                </div>
              `;
            } else {
              return `
                <div class="col-md-6">
                  <label class="form-label" style="font-weight: 500;">${escapeHTML(f.label)} ${f.required ? '*' : ''}</label>
                  <input type="${escapeHTML(f.type || 'text')}" class="form-control custom-field-input" data-field="${escapeHTML(f.fieldName)}" value="${escapeHTML(val)}" ${f.required ? 'required' : ''} placeholder="${escapeHTML(f.placeholder || '')}">
                </div>
              `;
            }
          }).join('');
        }
      }
    }

    const formHtml = `
      <form id="studentForm">
        <div class="row" style="row-gap: 14px;">
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Full Name *</label>
            <input type="text" class="form-control" name="name" value="${student ? escapeHTML(student.name) : ''}" required placeholder="e.g. Rahul Sharma">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Phone Number *</label>
            <input type="tel" class="form-control" name="phone" value="${student ? escapeHTML(student.phone) : ''}" required placeholder="10 digit mobile">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Email Address</label>
            <input type="email" class="form-control" name="email" value="${student && student.email ? escapeHTML(student.email) : ''}" placeholder="name@domain.com">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Gender</label>
            <select class="form-select form-control" name="gender">
              <option value="male" ${student && student.gender === 'male' ? 'selected' : ''}>Male</option>
              <option value="female" ${student && student.gender === 'female' ? 'selected' : ''}>Female</option>
              <option value="other" ${student && student.gender === 'other' ? 'selected' : ''}>Other</option>
            </select>
          </div>
          
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Membership Plan</label>
            <select class="form-select form-control" name="plan">
              ${plansOptions}
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Assigned Seat</label>
            <select class="form-select form-control" name="seat">
              ${seatsOptions}
            </select>
          </div>

          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Date of Birth</label>
            <input type="date" class="form-control" name="dateOfBirth" value="${(() => {
              if (!student || !student.dateOfBirth) return '';
              const d = new Date(student.dateOfBirth);
              return isNaN(d.getTime()) ? '' : d.toISOString().split('T')[0];
            })()}">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Status</label>
            <select class="form-select form-control" name="status">
              <option value="active" ${!student || student.status === 'active' ? 'selected' : ''}>Active</option>
              <option value="inactive" ${student && student.status === 'inactive' ? 'selected' : ''}>Inactive</option>
              <option value="suspended" ${student && student.status === 'suspended' ? 'selected' : ''}>Suspended</option>
              <option value="expired" ${student && student.status === 'expired' ? 'selected' : ''}>Expired</option>
            </select>
          </div>

          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Blood Group</label>
            <select class="form-select form-control" name="bloodGroup">
              <option value="">-- Select Blood Group --</option>
              ${['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'].map(bg => `<option value="${bg}" ${student && student.bloodGroup === bg ? 'selected' : ''}>${bg}</option>`).join('')}
            </select>
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">Occupation / College</label>
            <input type="text" class="form-control" name="occupation" value="${student && student.occupation ? escapeHTML(student.occupation) : ''}" placeholder="e.g. Student / Software Engg">
          </div>

          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">🏷️ RFID Smart Card UID</label>
            <input type="text" class="form-control" name="rfidCardNumber" value="${student && student.rfidCardNumber ? escapeHTML(student.rfidCardNumber) : ''}" placeholder="Scan card or enter Hex/DEC UID">
          </div>
          <div class="col-md-6">
            <label class="form-label" style="font-weight: 500;">👤 Biometric / Machine ID</label>
            <input type="text" class="form-control" name="biometricId" value="${student && student.biometricId ? escapeHTML(student.biometricId) : ''}" placeholder="e.g. BIO-101 / Finger ID">
          </div>

          <!-- Target Exam Multi-Select Chips -->
          <div class="col-12 mt-2">
            <label class="form-label" style="font-weight: 600;">🎯 Target Competitive Exams</label>
            <div id="exam-chips-container" style="display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px;">
              ${['UPSC', 'MPSC', 'SSC CGL', 'Banking / IBPS', 'JEE', 'NEET', 'CA / CS', 'GATE', 'CAT / MBA', 'Law / CLAT', 'UGC NET', 'State PSC', 'Other'].map(ex => {
                const isSelected = student && Array.isArray(student.targetExams) && student.targetExams.includes(ex);
                return `
                  <button type="button" class="btn btn-sm exam-chip-btn ${isSelected ? 'btn-primary' : 'btn-outline-secondary'}" data-exam="${ex}" style="border-radius: 16px; font-size: 0.8rem; padding: 3px 10px;">
                    ${ex}
                  </button>
                `;
              }).join('')}
            </div>
            <input type="hidden" name="targetExams" id="selectedTargetExams" value="${student && Array.isArray(student.targetExams) ? escapeHTML(student.targetExams.join(',')) : ''}">
          </div>
          
          <div class="col-12 mt-2">
            <h5 style="font-size: 0.95rem; font-weight: 600; margin-bottom: 8px; border-bottom: 1px solid var(--color-divider); padding-bottom: 4px;">Address Details</h5>
          </div>
          <div class="col-12">
            <input type="text" class="form-control" name="address" value="${student && student.address ? escapeHTML(student.address) : ''}" placeholder="Street Address / Room No">
          </div>
          <div class="col-md-4">
            <input type="text" class="form-control" name="city" value="${student && student.city ? escapeHTML(student.city) : ''}" placeholder="City">
          </div>
          <div class="col-md-4">
            <input type="text" class="form-control" name="state" value="${student && student.state ? escapeHTML(student.state) : ''}" placeholder="State">
          </div>
          <div class="col-md-4">
            <input type="text" class="form-control" name="pincode" value="${student && student.pincode ? escapeHTML(student.pincode) : ''}" placeholder="Pincode">
          </div>
          
          <div class="col-12 mt-2">
            <h5 style="font-size: 0.95rem; font-weight: 600; margin-bottom: 8px; border-bottom: 1px solid var(--color-divider); padding-bottom: 4px;">Emergency Contact</h5>
          </div>
          <div class="col-md-4">
            <input type="text" class="form-control" name="emergencyContact.name" value="${student && student.emergencyContact && student.emergencyContact.name ? escapeHTML(student.emergencyContact.name) : ''}" placeholder="Contact Name">
          </div>
          <div class="col-md-4">
            <input type="tel" class="form-control" name="emergencyContact.phone" value="${student && student.emergencyContact && student.emergencyContact.phone ? escapeHTML(student.emergencyContact.phone) : ''}" placeholder="Contact Phone">
          </div>
          <div class="col-md-4">
            <input type="text" class="form-control" name="emergencyContact.relation" value="${student && student.emergencyContact && student.emergencyContact.relation ? escapeHTML(student.emergencyContact.relation) : ''}" placeholder="Relation (e.g. Father)">
          </div>

          <!-- Student Passport Photo (Live Camera & Smart Crop) -->
          <div class="col-12 mt-2">
            <h5 style="font-size: 0.95rem; font-weight: 600; margin-bottom: 8px; border-bottom: 1px solid var(--color-divider); padding-bottom: 4px;">📷 Student Passport Photo</h5>
            <div id="mount-student-photo"></div>
          </div>

          <!-- KYC Government ID Proof -->
          <div class="col-12 mt-2">
            <h5 style="font-size: 0.95rem; font-weight: 600; margin-bottom: 8px; border-bottom: 1px solid var(--color-divider); padding-bottom: 4px;">📑 KYC & Government ID Proof</h5>
            <div class="row g-2 mb-2" style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
              <div>
                <label class="form-label" style="font-weight: 500;">ID Proof Type</label>
                <select class="form-select form-control" name="idProof.type">
                  <option value="Aadhaar Card" ${student?.idProof?.type === 'Aadhaar Card' ? 'selected' : ''}>Aadhaar Card</option>
                  <option value="PAN Card" ${student?.idProof?.type === 'PAN Card' ? 'selected' : ''}>PAN Card</option>
                  <option value="Driving License" ${student?.idProof?.type === 'Driving License' ? 'selected' : ''}>Driving License</option>
                  <option value="Voter ID" ${student?.idProof?.type === 'Voter ID' ? 'selected' : ''}>Voter ID Card</option>
                  <option value="College ID" ${student?.idProof?.type === 'College ID' ? 'selected' : ''}>College Student ID</option>
                  <option value="Passport" ${student?.idProof?.type === 'Passport' ? 'selected' : ''}>Passport</option>
                </select>
              </div>
              <div>
                <label class="form-label" style="font-weight: 500;">ID Proof / Document Number</label>
                <input type="text" class="form-control" name="idProof.number" value="${escapeHTML(student?.idProof?.number || '')}" placeholder="e.g. 1234 5678 9012">
              </div>
            </div>
            <div id="mount-student-idproof"></div>
          </div>

          <!-- Smart Digital Signature Studio -->
          <div class="col-12 mt-2">
            <label class="form-label" style="font-weight: 600; margin-bottom: 6px; display: block;">✍️ Student / Guardian Signature</label>
            <div id="admission-signature-studio-mount"></div>
          </div>
          
          <!-- Custom Dynamic Fields -->
          ${customFieldsHtml}

          <div class="col-12 mt-2">
            <label class="form-label" style="font-weight: 500;">Internal Notes</label>
            <textarea class="form-control" name="notes" rows="2" placeholder="Any special notes or requirements...">${student && student.notes ? escapeHTML(student.notes) : ''}</textarea>
          </div>
        </div>
      </form>
    `;

    let sigStudio = null;

    const modal = new Modal({
      title: isEdit ? 'Edit Student Details' : 'Add New Student Admission',
      content: formHtml,
      size: 'lg',
      buttons: [
        {
          text: 'Cancel',
          className: 'btn-secondary',
          onClick: (m) => m.close()
        },
        {
          text: isEdit ? 'Update Student' : 'Save Admission',
          className: 'btn-primary',
          onClick: async (m) => {
            const form = m.element.querySelector('#studentForm');
            if (!form.checkValidity()) {
              form.reportValidity();
              return;
            }
            
            const formData = new FormData(form);
            const data = Object.fromEntries(formData.entries());
            
            // Handle target exams array
            const examsStr = data.targetExams || '';
            data.targetExams = examsStr ? examsStr.split(',').filter(Boolean) : [];

            // Capture Custom Fields values
            data.customFields = {};
            m.element.querySelectorAll('.custom-field-input').forEach(input => {
              const fName = input.dataset.field;
              if (fName) {
                if (input.type === 'checkbox') {
                  data.customFields[fName] = input.checked;
                } else {
                  data.customFields[fName] = input.value;
                }
              }
            });

            // Capture custom media fields
            modal.element.querySelectorAll('.custom-field-media-mount').forEach(mount => {
              const fName = mount.dataset.field;
              const val = mount.querySelector('.mfp-hidden-value')?.value || '';
              if (val) data.customFields[fName] = val;
            });

            // Capture Signature from SignatureStudio
            if (sigStudio) {
              const sigVal = sigStudio.getValue();
              if (sigVal) data.signature = sigVal;
            }

            // Handle optional references
            if (!data.plan) delete data.plan;
            if (!data.seat) delete data.seat;
            if (!data.dateOfBirth) delete data.dateOfBirth;

            // Reconstruct KYC idProof object
            data.idProof = {
              type: data['idProof.type'] || 'Aadhaar Card',
              number: data['idProof.number'] || '',
              image: data.idProofImage || ''
            };
            delete data['idProof.type'];
            delete data['idProof.number'];
            delete data.idProofImage;

            // Reconstruct emergency contact
            data.emergencyContact = {
              name: data['emergencyContact.name'] || '',
              phone: data['emergencyContact.phone'] || '',
              relation: data['emergencyContact.relation'] || ''
            };
            delete data['emergencyContact.name'];
            delete data['emergencyContact.phone'];
            delete data['emergencyContact.relation'];

            try {
              let res;
              if (isEdit) {
                res = await api.put(`/api/students/${student._id}`, data);
              } else {
                res = await api.post('/api/students', data);
              }
              
              if (res.success) {
                Toast.success(res.message);
                m.close();
                loadStats();
                loadStudents(state.pagination.page);
              } else {
                Toast.error(res.message);
              }
            } catch (err) {
              Toast.error(err.message || 'Error saving student');
            }
          }
        }
      ]
    });
    
    modal.open();

    // Initialize Smart Photo Picker
    const photoMount = modal.element.querySelector('#mount-student-photo');
    if (photoMount) {
      photoMount.appendChild(MediaFieldPicker.create({
        label: 'Student Passport Photo',
        preset: 'passport',
        name: 'photo',
        value: student?.photo || ''
      }));
    }

    // Initialize Smart KYC Document Picker
    const kycMount = modal.element.querySelector('#mount-student-idproof');
    if (kycMount) {
      kycMount.appendChild(MediaFieldPicker.create({
        label: 'ID Proof Document Scan / Photo',
        preset: 'document',
        name: 'idProofImage',
        value: student?.idProof?.image || ''
      }));
    }

    // Initialize Custom Dynamic Field Media Pickers
    modal.element.querySelectorAll('.custom-field-media-mount').forEach(mount => {
      const fName = mount.dataset.field;
      const fLabel = mount.dataset.label;
      const fPreset = mount.dataset.preset;
      const val = student?.customFields?.[fName] || '';
      mount.appendChild(MediaFieldPicker.create({
        label: fLabel,
        preset: fPreset,
        name: fName,
        value: val
      }));
    });

    // Initialize Smart Signature Studio
    const sigMount = modal.element.querySelector('#admission-signature-studio-mount');
    if (sigMount) {
      sigStudio = new SignatureStudio(sigMount, {
        value: student?.signature,
        studentName: student?.name,
        width: 500,
        height: 140
      });
    }

    // Setup Exam Chips Toggling
    const chipsContainer = modal.element.querySelector('#exam-chips-container');
    const selectedExamsInput = modal.element.querySelector('#selectedTargetExams');
    if (chipsContainer && selectedExamsInput) {
      let selectedSet = new Set(selectedExamsInput.value ? selectedExamsInput.value.split(',') : []);
      chipsContainer.querySelectorAll('.exam-chip-btn').forEach(chip => {
        chip.addEventListener('click', () => {
          const ex = chip.dataset.exam;
          if (selectedSet.has(ex)) {
            selectedSet.delete(ex);
            chip.classList.remove('btn-primary');
            chip.classList.add('btn-outline-secondary');
          } else {
            selectedSet.add(ex);
            chip.classList.remove('btn-outline-secondary');
            chip.classList.add('btn-primary');
          }
          selectedExamsInput.value = Array.from(selectedSet).join(',');
        });
      });
    }
  }

  function initSignatureCanvas(canvas, existingDataUrl) {
    const ctx = canvas.getContext('2d');
    ctx.strokeStyle = '#1e293b';
    ctx.lineWidth = 2.5;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';

    if (existingDataUrl) {
      const img = new Image();
      img.onload = () => ctx.drawImage(img, 0, 0);
      img.src = existingDataUrl;
    }

    let isDrawing = false;
    let lastX = 0, lastY = 0;

    function getPos(e) {
      const rect = canvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      const scaleX = canvas.width / rect.width;
      const scaleY = canvas.height / rect.height;
      return {
        x: (clientX - rect.left) * scaleX,
        y: (clientY - rect.top) * scaleY
      };
    }

    function startDraw(e) {
      e.preventDefault();
      isDrawing = true;
      const pos = getPos(e);
      lastX = pos.x;
      lastY = pos.y;
    }

    function draw(e) {
      if (!isDrawing) return;
      e.preventDefault();
      const pos = getPos(e);
      ctx.beginPath();
      ctx.moveTo(lastX, lastY);
      ctx.lineTo(pos.x, pos.y);
      ctx.stroke();
      lastX = pos.x;
      lastY = pos.y;
    }

    function stopDraw() {
      isDrawing = false;
    }

    canvas.addEventListener('mousedown', startDraw);
    canvas.addEventListener('mousemove', draw);
    canvas.addEventListener('mouseup', stopDraw);
    canvas.addEventListener('mouseleave', stopDraw);

    canvas.addEventListener('touchstart', startDraw, { passive: false });
    canvas.addEventListener('touchmove', draw, { passive: false });
    canvas.addEventListener('touchend', stopDraw);
  }

  function isCanvasBlank(canvas) {
    const ctx = canvas.getContext('2d');
    const pixelBuffer = new Uint32Array(
      ctx.getImageData(0, 0, canvas.width, canvas.height).data.buffer
    );
    return !pixelBuffer.some(color => color !== 0);
  }

  async function handleDelete(id) {
    Confirm.show({
      title: 'Delete Student',
      message: 'Are you sure you want to deactivate this student record? This action will set the student status to inactive and release any assigned seat.',
      danger: true,
      onConfirm: async () => {
        try {
          const res = await api.delete(`/api/students/${id}`);
          if (res.success) {
            Toast.success(res.message);
            loadStats();
            loadStudents(state.pagination.page);
          } else {
            Toast.error(res.message);
          }
        } catch (err) {
          Toast.error(err.message || 'Error deleting student');
        }
      }
    });
  }

  // Event Listeners
  container.addEventListener('click', (e) => {
    const addBtn = e.target.closest('#addStudentBtn');
    if (addBtn) {
      showStudentForm();
      return;
    }
    
    const viewBtn = e.target.closest('.btn-view');
    if (viewBtn) {
      const id = viewBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showStudentProfile(student);
      return;
    }

    const editBtn = e.target.closest('.btn-edit');
    if (editBtn) {
      const id = editBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showStudentForm(student);
      return;
    }

    const idCardBtn = e.target.closest('.btn-idcard');
    if (idCardBtn) {
      const id = idCardBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) showStudentIdCard(student);
      return;
    }

    const pdfBtn = e.target.closest('.btn-pdfform');
    if (pdfBtn) {
      const id = pdfBtn.getAttribute('data-id');
      const student = state.students.find(s => s._id === id);
      if (student) generateAdmissionFormPDF(student);
      return;
    }
    
    const deleteBtn = e.target.closest('.btn-delete');
    if (deleteBtn) {
      const id = deleteBtn.getAttribute('data-id');
      handleDelete(id);
      return;
    }
  });

  function showStudentProfile(student) {
    const planName = student.plan?.name || 'Standard Plan';
    const seatNumber = student.seat?.seatNumber || 'Floating / Not Assigned';
    const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : '-';
    const expiryDate = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : '-';
    const daysLeft = student.expiryDate ? Math.ceil((new Date(student.expiryDate) - new Date()) / (1000 * 60 * 60 * 24)) : null;

    let phone = (student.phone || '').replace(/[^0-9]/g, '');
    if (phone.length === 10) phone = '91' + phone;
    const waUrl = phone ? `https://api.whatsapp.com/send?phone=${phone}` : null;

    const modalContent = document.createElement('div');
    modalContent.innerHTML = `
      <div style="font-family: 'Outfit', sans-serif;">
        <!-- Student Header Card -->
        <div style="display: flex; align-items: center; gap: 16px; padding: 16px; background: var(--color-surface-hover); border-radius: 12px; margin-bottom: 20px; border: 1px solid var(--color-border);">
          <div style="width: 64px; height: 64px; border-radius: 50%; background: linear-gradient(135deg, #6366f1, #8b5cf6); display: flex; align-items: center; justify-content: center; font-size: 24px; color: #fff; font-weight: 700; overflow: hidden;">
            ${student.photo ? `<img src="${student.photo}" style="width: 100%; height: 100%; object-fit: cover;">` : (student.name || 'S').charAt(0)}
          </div>
          <div style="flex: 1;">
            <div class="d-flex align-items-center gap-2">
              <h3 style="margin: 0; font-size: 1.25rem; font-weight: 700;">${escapeHTML(student.name)}</h3>
              <span class="badge ${student.status === 'active' ? 'badge-success' : 'badge-danger'}" style="text-transform: uppercase;">${escapeHTML(student.status)}</span>
            </div>
            <div class="text-muted small mt-1">
              Student ID: <strong style="color: var(--color-primary); font-family: monospace;">${escapeHTML(student.studentId || '-')}</strong> • Phone: <strong>${escapeHTML(student.phone || '-')}</strong>
            </div>
          </div>
        </div>

        <!-- 360 Degree Info Grid -->
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px; margin-bottom: 20px;">
          <!-- Membership Info -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-primary);">💺 Membership & Seat</h5>
            <div class="small text-muted mb-1">Plan: <strong class="text-primary">${escapeHTML(planName)}</strong></div>
            <div class="small text-muted mb-1">Desk / Seat: <strong class="text-success">${escapeHTML(seatNumber)}</strong></div>
            <div class="small text-muted mb-1">Enrolled: <strong>${admissionDate}</strong></div>
            <div class="small text-muted">Valid Until: <strong class="text-danger">${expiryDate}</strong> (${daysLeft !== null ? (daysLeft <= 0 ? 'Expired' : `${daysLeft} days left`) : '-'})</div>
          </div>

          <!-- Academic & Exams -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-info);">🎯 Academic & Target Exams</h5>
            <div class="small text-muted mb-1">College/Coaching: <strong>${escapeHTML(student.occupation || 'N/A')}</strong></div>
            <div class="small text-muted mb-2">Blood Group: <strong>${escapeHTML(student.bloodGroup || 'N/A')}</strong></div>
            <div class="d-flex flex-wrap gap-1">
              ${(student.targetExams && student.targetExams.length > 0) ? student.targetExams.map(ex => `<span class="badge badge-primary" style="font-size: 0.7rem;">${escapeHTML(ex)}</span>`).join('') : '<span class="text-muted small">No target exams specified</span>'}
            </div>
          </div>

          <!-- Contact & Address -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-warning);">📍 Address & Emergency</h5>
            <div class="small text-muted mb-1">Email: <strong>${escapeHTML(student.email || 'N/A')}</strong></div>
            <div class="small text-muted mb-1">Address: <strong>${escapeHTML(student.address || 'N/A')}, ${escapeHTML(student.city || '')} ${escapeHTML(student.pincode || '')}</strong></div>
            <div class="small text-muted">Emergency Contact: <strong>${escapeHTML(student.emergencyContact?.name || 'N/A')} (${escapeHTML(student.emergencyContact?.relation || 'Parent')}) - ${escapeHTML(student.emergencyContact?.phone || '')}</strong></div>
          </div>

          <!-- Smart Access & KYC -->
          <div style="background: var(--color-bg-primary); padding: 14px; border-radius: 10px; border: 1px solid var(--color-border);">
            <h5 style="margin: 0 0 10px 0; font-size: 0.9rem; font-weight: 700; color: var(--color-success);">🔐 Access & KYC</h5>
            <div class="small text-muted mb-1">RFID Smart Card: <strong>${escapeHTML(student.rfidCardNumber || 'Not Linked')}</strong></div>
            <div class="small text-muted mb-1">Biometric ID: <strong>${escapeHTML(student.biometricId || 'Not Linked')}</strong></div>
            <div class="small text-muted mb-1">ID Proof: <strong>${escapeHTML(student.idProof?.type || 'Aadhaar')} (${escapeHTML(student.idProof?.number || 'N/A')})</strong></div>
            ${student.signature ? `
              <div class="mt-2">
                <div class="text-xs text-muted">Digital Signature:</div>
                <img src="${student.signature}" style="max-height: 40px; border: 1px solid var(--color-border); border-radius: 4px; background: #fff; padding: 2px;">
              </div>
            ` : ''}
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="d-flex justify-content-end gap-2 pt-3 border-top">
          ${waUrl ? `
            <a href="${waUrl}" target="_blank" class="btn btn-outline-success btn-sm" style="font-weight: 600;">
              📲 WhatsApp
            </a>
          ` : ''}
          <button type="button" class="btn btn-outline-info btn-sm btn-profile-idcard">
            🪪 Print ID Card
          </button>
          <button type="button" class="btn btn-outline-success btn-sm btn-profile-pdfform">
            📄 Download PDF Form
          </button>
          <button type="button" class="btn btn-primary btn-sm btn-profile-edit">
            ✏️ Edit Student
          </button>
          <button type="button" class="btn btn-secondary btn-sm" onclick="Modal.closeAll()">
            Close
          </button>
        </div>
      </div>
    `;

    const pModal = new Modal({
      title: `👤 Student Profile: ${student.name}`,
      content: modalContent,
      size: 'lg'
    });
    pModal.show();

    modalContent.querySelector('.btn-profile-idcard')?.addEventListener('click', () => {
      pModal.close();
      showStudentIdCard(student);
    });

    modalContent.querySelector('.btn-profile-pdfform')?.addEventListener('click', () => {
      generateAdmissionFormPDF(student);
    });

    modalContent.querySelector('.btn-profile-edit')?.addEventListener('click', () => {
      pModal.close();
      showStudentForm(student);
    });
  }

  async function showStudentIdCard(student) {
    let business = { businessName: 'Study Library', tagline: 'Self Study & Reading Room', phone: '', address: '' };
    try {
      const bRes = await api.get('/api/settings');
      if (bRes.success && bRes.data?.businessProfile) {
        business = bRes.data.businessProfile;
      }
    } catch (e) {}

    const initials = (student.name || 'S')
      .split(' ')
      .map(n => n[0])
      .join('')
      .toUpperCase()
      .slice(0, 2);

    const planName = student.plan?.name || 'Standard Access';
    const seatNumber = student.seat?.seatNumber || 'Floating / Any';
    const admissionDate = student.admissionDate ? new Date(student.admissionDate).toLocaleDateString('en-IN') : '-';
    const expiryDate = student.expiryDate ? new Date(student.expiryDate).toLocaleDateString('en-IN') : '-';

    const qrData = JSON.stringify({
      type: 'STUDENT_ID',
      id: student.studentId,
      name: student.name,
      phone: student.phone
    });
    const qrCodeURL = `https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${encodeURIComponent(qrData)}&margin=4`;

    const cardContent = document.createElement('div');
    cardContent.innerHTML = `
      <div class="id-card-modal-wrapper text-center">
        <!-- Printable Physical ID Card Box -->
        <div id="printable-id-card" style="
          width: 320px;
          margin: 0 auto;
          background: #ffffff;
          color: #1a1a2e;
          border-radius: 12px;
          border: 2px solid #6c5ce7;
          overflow: hidden;
          box-shadow: 0 10px 25px rgba(0,0,0,0.15);
          font-family: 'Outfit', sans-serif;
          position: relative;
          text-align: left;
        ">
          <!-- Card Header Banner -->
          <div style="background: linear-gradient(135deg, #6c5ce7, #a29bfe); color: white; padding: 14px 16px; text-align: center;">
            <div style="font-weight: 800; font-size: 1.15rem; letter-spacing: 0.5px; text-transform: uppercase;">
              ${escapeHTML(business.businessName || 'Study Library')}
            </div>
            <div style="font-size: 0.75rem; opacity: 0.9; margin-top: 2px;">
              ${escapeHTML(business.tagline || 'Student Membership Card')}
            </div>
          </div>

          <!-- Card Body -->
          <div style="padding: 16px;">
            <!-- Avatar & ID Badge -->
            <div style="display: flex; gap: 14px; align-items: center; margin-bottom: 14px;">
              <div style="
                width: 68px;
                height: 68px;
                border-radius: 50%;
                background: #f0f2f5;
                color: #6c5ce7;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 1.4rem;
                font-weight: 800;
                border: 3px solid #6c5ce7;
                flex-shrink: 0;
              ">
                ${initials}
              </div>
              <div>
                <h4 style="margin: 0 0 4px 0; font-size: 1.1rem; font-weight: 700; color: #2d3436;">
                  ${escapeHTML(student.name)}
                </h4>
                <div style="font-size: 0.8rem; background: #eef2ff; color: #4338ca; padding: 2px 8px; border-radius: 4px; display: inline-block; font-weight: 700; font-family: monospace;">
                  ${escapeHTML(student.studentId || 'STU-MEMBER')}
                </div>
              </div>
            </div>

            <!-- Details List -->
            <div style="font-size: 0.82rem; line-height: 1.6; border-top: 1px dashed #e2e8f0; padding-top: 10px; color: #4a5568;">
              <div style="display: flex; justify-content: space-between;">
                <strong>Assigned Seat:</strong>
                <span style="font-weight: 700; color: #6c5ce7;">${escapeHTML(seatNumber)}</span>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <strong>Plan:</strong>
                <span>${escapeHTML(planName)}</span>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <strong>Phone:</strong>
                <span>${escapeHTML(student.phone || '-')}</span>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <strong>Issued On:</strong>
                <span>${admissionDate}</span>
              </div>
              <div style="display: flex; justify-content: space-between;">
                <strong>Valid Till:</strong>
                <span style="font-weight: 700; color: #e53e3e;">${expiryDate}</span>
              </div>
            </div>

            <!-- QR Code -->
            <div style="text-align: center; margin: 8px 0;">
              <img src="${qrCodeURL}" alt="Student QR" style="width: 90px; height: 90px; border-radius: 4px;">
              <div style="font-size: 0.65rem; color: #718096; letter-spacing: 1px; margin-top: 2px;">
                ${escapeHTML(student.studentId || '')}
              </div>
            </div>
          </div>

          <!-- Card Footer Banner -->
          <div style="background: #f7fafc; border-top: 1px solid #edf2f7; padding: 6px 12px; font-size: 0.65rem; color: #718096; text-align: center;">
            ${escapeHTML(business.phone ? 'Helpdesk: ' + business.phone : 'Non-Transferable • Carry Daily')}
          </div>
        </div>

        <div style="margin-top: 16px; font-size: 0.85rem; color: var(--color-text-secondary); text-align: left; padding: 0 16px;" class="d-print-none">
          <div style="font-weight: 600; margin-bottom: 4px; color: var(--color-text-primary);">Smart ID Options</div>
          <ul style="margin: 0; padding-left: 20px; list-style-type: disc;">
            <li>QR Code (Active)</li>
            <li>RFID: ${student.rfidCardNumber ? `<span style="font-family: monospace;">${escapeHTML(student.rfidCardNumber)}</span>` : 'Not Assigned'}</li>
            <li>Biometric: ${student.biometricId ? `<span style="font-family: monospace;">${escapeHTML(student.biometricId)}</span>` : 'Not Assigned'}</li>
          </ul>
        </div>

        <!-- Action Controls -->
        <div class="d-flex justify-content-center gap-3 mt-4">
          <button class="btn btn-primary" id="btn-print-id-card">
            🖨️ Print Student ID Card
          </button>
          <button class="btn btn-secondary modal-close-btn" onclick="Modal.close()">
            Close
          </button>
        </div>
      </div>

      <style>
        @media print {
          body * { visibility: hidden; }
          #printable-id-card, #printable-id-card * { visibility: visible; }
          #printable-id-card {
            position: absolute;
            left: 50%;
            top: 20px;
            transform: translateX(-50%);
            box-shadow: none !important;
            border: 2px solid #000 !important;
          }
        }
      </style>
    `;

    const idModal = new Modal({
      title: `Student ID Card: ${escapeHTML(student.name)}`,
      content: cardContent,
      size: 'md'
    });
    idModal.show();

    cardContent.querySelector('#btn-print-id-card')?.addEventListener('click', () => {
      window.print();
    });
  }

  const searchInput = container.querySelector('#studentSearch');
  let searchTimeout;
  if (searchInput) {
    searchInput.addEventListener('input', () => {
      clearTimeout(searchTimeout);
      searchTimeout = setTimeout(() => loadStudents(1), 350);
    });
  }

  const statusFilter = container.querySelector('#studentStatusFilter');
  if (statusFilter) {
    statusFilter.addEventListener('change', () => loadStudents(1));
  }

  // Initial load
  setTimeout(() => {
    loadStats();
    loadStudents(1);
  }, 0);
  
  return container;
}
