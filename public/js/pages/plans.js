import { App } from '../app.js';
import { t } from '../i18n.js';
import { Toast, Modal, Loading, Confirm, escapeHTML } from '../ui.js';
import api from '../api.js';

let plans = [];
let coupons = [];

export async function render() {
  const container = document.createElement('div');
  container.className = 'page-container';
  
  container.innerHTML = `
    <!-- Standard Module Header -->
    <div class="module-header">
      <div class="module-title-area">
        <h2>💳 ${t('Plans & Pricing')}</h2>
        <p>Define study room membership tiers, durations, fee discounts, and pricing structures.</p>
      </div>
      <div class="module-actions">
        <button id="btn-create-plan" class="btn btn-primary d-flex align-items-center gap-2" style="font-weight: 700;">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
          ${t('+ Create Plan')}
        </button>
      </div>
    </div>
    
    <!-- Toolbar Card -->
    <div class="toolbar-card d-flex justify-content-between align-items-center flex-wrap gap-2">
      <div class="d-flex align-items-center gap-2">
        <input type="checkbox" id="show-inactive-plans" style="cursor: pointer; width: 16px; height: 16px;">
        <label for="show-inactive-plans" style="cursor: pointer; margin: 0; font-size: 0.88rem; font-weight: 600; color: var(--color-text-secondary);">${t('Show Inactive / Archived Plans')}</label>
      </div>
      <span class="text-muted text-xs">Manage seat access permissions per plan</span>
    </div>
    
    <div id="plans-grid" style="display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 1.25rem;">
      <!-- Plans will be rendered here -->
    </div>
    
    
    <hr style="margin: 3rem 0; border-color: var(--color-divider);">
    <div class="module-header mt-4">
      <div class="module-title-area">
        <h2>🎟️ Promo Coupons & Discount Manager</h2>
        <p>Create and manage discount codes for student admissions.</p>
      </div>
      <div class="module-actions">
        <button id="btn-create-coupon" class="btn btn-primary d-flex align-items-center gap-2" style="font-weight: 700;">
          <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
          ${t('Add Coupon')}
        </button>
      </div>
    </div>
    
    <div class="card p-0 mb-5" style="overflow-x: auto;">
      <table class="table" style="width: 100%; border-collapse: collapse;">
        <thead style="background: var(--color-surface); border-bottom: 2px solid var(--color-border);">
          <tr>
            <th style="padding: 12px 16px; text-align: left;">Code</th>
            <th style="padding: 12px 16px; text-align: left;">Discount</th>
            <th style="padding: 12px 16px; text-align: left;">Min Amount</th>
            <th style="padding: 12px 16px; text-align: left;">Usage</th>
            <th style="padding: 12px 16px; text-align: left;">Status</th>
            <th style="padding: 12px 16px; text-align: left;">Actions</th>
          </tr>
        </thead>
        <tbody id="coupons-tbody">
          <tr><td colspan="6" class="text-center text-muted p-4">Loading coupons...</td></tr>
        </tbody>
      </table>
    </div>

    <!-- Coupon Modal -->
    <div id="couponModal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.6); z-index:10000; justify-content:center; align-items:center; padding:1.5rem;">
      <div style="background:var(--color-surface, #1e2230); color: var(--color-text-primary, #fff); border: 1px solid var(--color-border, #333); border-radius:var(--radius-lg, 12px); width:100%; max-width:500px; box-shadow:var(--shadow-xl);">
        <div style="padding: 16px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center;">
          <h4 id="couponModalTitle" style="margin: 0; font-size: 1.2rem; font-weight: 600;">${t('Add Coupon')}</h4>
          <button type="button" id="couponModalClose" style="background:none; border:none; color:var(--color-text-muted, #aaa); font-size: 1.5rem; cursor:pointer; line-height: 1;">&times;</button>
        </div>
        <div style="padding: 20px;">
          <form id="coupon-form">
            <input type="hidden" id="coupon-id">
            
            <div class="mb-3">
              <label class="form-label">Code *</label>
              <input type="text" class="form-control" id="coupon-code" required placeholder="e.g. SUMMER50" style="text-transform: uppercase;">
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Type</label>
                <select class="form-control form-select" id="coupon-discountType">
                  <option value="percentage">Percentage (%)</option>
                  <option value="flat">Flat Amount (₹)</option>
                </select>
              </div>
              <div class="col-md-6">
                <label class="form-label">Value *</label>
                <input type="number" class="form-control" id="coupon-discountValue" required min="0" placeholder="e.g. 10">
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Min Plan Amount</label>
                <input type="number" class="form-control" id="coupon-minPlanAmount" min="0" value="0">
              </div>
              <div class="col-md-6">
                <label class="form-label">Max Discount (₹)</label>
                <input type="number" class="form-control" id="coupon-maxDiscount" min="0" placeholder="Optional">
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label class="form-label">Valid Until</label>
                <input type="date" class="form-control" id="coupon-validUntil">
              </div>
              <div class="col-md-6">
                <label class="form-label">Usage Limit</label>
                <input type="number" class="form-control" id="coupon-usageLimit" min="1" value="100">
              </div>
            </div>
            
            <div class="d-flex align-items-center gap-2 mb-3">
              <input type="checkbox" id="coupon-isActive" checked style="cursor: pointer; width: 18px; height: 18px;">
              <label for="coupon-isActive" style="cursor: pointer; margin: 0;">Active</label>
            </div>

            <div style="padding-top: 14px; border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: flex-end; gap: 10px;">
              <button type="button" class="btn btn-secondary" id="couponModalCancel">${t('Cancel')}</button>
              <button type="button" class="btn btn-primary" id="btn-save-coupon">${t('Save Coupon')}</button>
            </div>
          </form>
        </div>
      </div>
    </div>

    <!-- Plan Modal -->
    <div id="planModal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.6); z-index:10000; justify-content:center; align-items:center; padding:1.5rem;">
      <div style="background:var(--color-surface, #1e2230); color: var(--color-text-primary, #fff); border: 1px solid var(--color-border, #333); border-radius:var(--radius-lg, 12px); width:100%; max-width:600px; max-height:90vh; overflow-y:auto; box-shadow:var(--shadow-xl);">
        <div style="padding: 16px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center;">
          <h4 id="planModalTitle" style="margin: 0; font-size: 1.2rem; font-weight: 600;">${t('Create Plan')}</h4>
          <button type="button" id="planModalClose" style="background:none; border:none; color:var(--color-text-muted, #aaa); font-size: 1.5rem; cursor:pointer; line-height: 1;">&times;</button>
        </div>
        <div style="padding: 20px;">
          <form id="plan-form">
            <input type="hidden" id="plan-id">
            
            <div class="mb-3">
              <label for="plan-name" class="form-label" style="font-weight: 500;">${t('Plan Name')} *</label>
              <input type="text" class="form-control" id="plan-name" required placeholder="e.g. Monthly Standard, Quarterly Full Day">
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label for="plan-price" class="form-label" style="font-weight: 500;">${t('Price')} (₹) *</label>
                <input type="number" class="form-control" id="plan-price" required min="0" placeholder="e.g. 1500">
              </div>
              <div class="col-md-6">
                <label for="plan-discount" class="form-label" style="font-weight: 500;">${t('Discount')} (%)</label>
                <input type="number" class="form-control" id="plan-discount" min="0" max="100" value="0">
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label for="plan-duration" class="form-label" style="font-weight: 500;">${t('Duration')} *</label>
                <input type="number" class="form-control" id="plan-duration" required min="1" value="30">
              </div>
              <div class="col-md-6">
                <label for="plan-durationType" class="form-label" style="font-weight: 500;">${t('Duration Type')}</label>
                <select class="form-select form-control" id="plan-durationType">
                  <option value="days">${t('Days')}</option>
                  <option value="months">${t('Months')}</option>
                  <option value="years">${t('Years')}</option>
                </select>
              </div>
            </div>
            
            <div class="row mb-3">
              <div class="col-md-6">
                <label for="plan-seatType" class="form-label" style="font-weight: 500;">${t('Seat Type')}</label>
                <select class="form-select form-control" id="plan-seatType">
                  <option value="any">${t('Any / All Seats')}</option>
                  <option value="regular">${t('Regular')}</option>
                  <option value="premium">${t('Premium / AC')}</option>
                  <option value="cabin">${t('Private Cabin')}</option>
                </select>
              </div>
              <div class="col-md-6">
                <label for="plan-shift" class="form-label" style="font-weight: 500;">${t('Shift / Timing')}</label>
                <select class="form-select form-control" id="plan-shift">
                  <option value="any">${t('Any Shift (Full Access)')}</option>
                  <option value="morning">${t('Morning Shift')}</option>
                  <option value="evening">${t('Evening Shift')}</option>
                  <option value="fullday">${t('Full Day')}</option>
                  <option value="night">${t('Night Shift')}</option>
                </select>
              </div>
            </div>
            
            <div class="mb-3">
              <label for="plan-description" class="form-label" style="font-weight: 500;">${t('Description')}</label>
              <textarea class="form-control" id="plan-description" rows="2" placeholder="Brief info about this membership..."></textarea>
            </div>
            
            <div class="mb-3">
              <label for="plan-features" class="form-label" style="font-weight: 500;">${t('Features')} (Comma separated)</label>
              <textarea class="form-control" id="plan-features" rows="2" placeholder="High Speed WiFi, RO Water, Dedicated Locker, Power Socket"></textarea>
            </div>
            
            <div class="d-flex align-items-center gap-2 mb-3">
              <input type="checkbox" id="plan-isActive" checked style="cursor: pointer; width: 18px; height: 18px;">
              <label for="plan-isActive" style="cursor: pointer; margin: 0;">${t('Plan is Active (Available for selection)')}</label>
            </div>

            <div style="padding-top: 14px; border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: flex-end; gap: 10px;">
              <button type="button" class="btn btn-secondary" id="planModalCancel">${t('Cancel')}</button>
              <button type="button" class="btn btn-primary" id="btn-save-plan">${t('Save Plan')}</button>
            </div>
          </form>
        </div>
      </div>
    </div>
  `;

  setTimeout(() => {
    loadPlans();

    loadCoupons();
    
    const createCouponBtn = container.querySelector('#btn-create-coupon');
    if (createCouponBtn) {
      createCouponBtn.addEventListener('click', () => {
        const form = container.querySelector('#coupon-form');
        if (form) form.reset();
        container.querySelector('#coupon-id').value = '';
        container.querySelector('#coupon-isActive').checked = true;
        container.querySelector('#couponModalTitle').textContent = t('Add Coupon');
        document.getElementById('couponModal').style.display = 'flex';
      });
    }
    
    const saveCouponBtn = container.querySelector('#btn-save-coupon');
    if (saveCouponBtn) saveCouponBtn.addEventListener('click', saveCoupon);
    
    const couponsTbody = container.querySelector('#coupons-tbody');
    if (couponsTbody) {
      couponsTbody.addEventListener('click', (e) => {
        const editBtn = e.target.closest('.btn-edit-coupon');
        if (editBtn) {
          const id = editBtn.dataset.id;
          openEditCouponModal(id);
        }
        
        const deleteBtn = e.target.closest('.btn-delete-coupon');
        if (deleteBtn) {
          const id = deleteBtn.dataset.id;
          deleteCoupon(id);
        }
      });

      couponsTbody.addEventListener('change', (e) => {
        if (e.target.classList.contains('coupon-active-toggle')) {
          const id = e.target.dataset.id;
          const isActive = e.target.checked;
          toggleCouponStatus(id, isActive);
        }
      });
    }

    const closeCouponBtn = container.querySelector('#couponModalClose');
    if (closeCouponBtn) closeCouponBtn.addEventListener('click', () => document.getElementById('couponModal').style.display = 'none');

    const cancelCouponBtn = container.querySelector('#couponModalCancel');
    if (cancelCouponBtn) cancelCouponBtn.addEventListener('click', () => document.getElementById('couponModal').style.display = 'none');

    
    const inactiveCheck = container.querySelector('#show-inactive-plans');
    if (inactiveCheck) inactiveCheck.addEventListener('change', loadPlans);
    
    const createBtn = container.querySelector('#btn-create-plan');
    if (createBtn) {
      createBtn.addEventListener('click', () => {
        const form = container.querySelector('#plan-form');
        if (form) form.reset();
        container.querySelector('#plan-id').value = '';
        container.querySelector('#plan-isActive').checked = true;
        container.querySelector('#planModalTitle').textContent = t('Create New Plan');
        showPlanModal();
      });
    }
    
    const saveBtn = container.querySelector('#btn-save-plan');
    if (saveBtn) saveBtn.addEventListener('click', savePlan);
    
    const grid = container.querySelector('#plans-grid');
    if (grid) {
      grid.addEventListener('click', (e) => {
        const editBtn = e.target.closest('.btn-edit');
        if (editBtn) {
          const id = editBtn.dataset.id;
          openEditModal(id);
        }
        
        const deleteBtn = e.target.closest('.btn-delete');
        if (deleteBtn) {
          const id = deleteBtn.dataset.id;
          deletePlan(id);
        }
      });

      grid.addEventListener('change', (e) => {
        if (e.target.classList.contains('plan-active-toggle')) {
          const id = e.target.dataset.id;
          const isActive = e.target.checked;
          togglePlanStatus(id, isActive);
        }
      });
    }

    const closeBtn = container.querySelector('#planModalClose');
    if (closeBtn) closeBtn.addEventListener('click', hidePlanModal);

    const cancelBtn = container.querySelector('#planModalCancel');
    if (cancelBtn) cancelBtn.addEventListener('click', hidePlanModal);
  }, 0);

  return container;
}

function showPlanModal() {
  const modal = document.getElementById('planModal');
  if (modal) modal.style.display = 'flex';
}

function hidePlanModal() {
  const modal = document.getElementById('planModal');
  if (modal) modal.style.display = 'none';
}

async function loadPlans() {
  const grid = document.getElementById('plans-grid');
  if (!grid) return;
  
  grid.innerHTML = '<div class="text-center p-5 text-muted" style="grid-column: 1 / -1;">Loading plans...</div>';
  
  const showInactive = document.getElementById('show-inactive-plans')?.checked;
  const endpoint = showInactive ? '/api/plans/all' : '/api/plans';
  
  try {
    const res = await api.get(endpoint);
    if (res.success && res.data) {
      plans = res.data;
      renderPlansGrid(plans);
    } else {
      Toast.error(res.message);
    }
  } catch (error) {
    Toast.error('Failed to load plans');
  }
}

function renderPlansGrid(plansList) {
  const grid = document.getElementById('plans-grid');
  if (!grid) return;
  
  if (!plansList || plansList.length === 0) {
    grid.innerHTML = `<div class="empty-state p-5 text-center text-muted" style="grid-column: 1 / -1;">No plans found. Click "Create Plan" to add your first membership package.</div>`;
    return;
  }
  
  const currencyFormatter = new Intl.NumberFormat('en-IN', {
    style: 'currency',
    currency: 'INR',
    maximumFractionDigits: 0
  });

  let html = '';
  plansList.forEach(plan => {
    const effectivePrice = plan.effectivePrice || (plan.price * (1 - (plan.discount || 0)/100));
    
    let featuresHtml = '';
    if (plan.features && plan.features.length > 0) {
      featuresHtml = '<ul style="list-style: none; padding: 0; margin: 16px 0; display: flex; flex-direction: column; gap: 6px;">';
      plan.features.forEach(f => {
        featuresHtml += `<li style="font-size: 0.88rem; display: flex; align-items: center; gap: 8px;"><span style="color: var(--color-success, #00b894);">✓</span> ${escapeHTML(f)}</li>`;
      });
      featuresHtml += '</ul>';
    }

    const durationText = `${plan.duration} ${plan.durationType || 'days'}`;
    const badge = plan.discount > 0 ? `<span class="badge" style="position: absolute; top: 12px; right: 12px; background: var(--color-danger, #d63031); color: white; font-weight: 700;">${plan.discount}% OFF</span>` : '';
    const opacityStyle = plan.isActive ? '' : 'opacity: 0.6;';

    html += `
      <div class="card p-4 position-relative d-flex flex-column" style="${opacityStyle} border: 1px solid var(--color-border); border-radius: var(--radius-lg, 12px); box-shadow: var(--shadow-sm); min-height: 320px; justify-content: space-between;">
        ${badge}
        <div>
          <div class="mb-2">
            <h3 style="margin: 0; font-size: 1.3rem; font-weight: 700; color: var(--color-text-primary);">${escapeHTML(plan.name)}</h3>
            <span class="badge" style="background: rgba(99, 102, 241, 0.15); color: var(--color-primary); font-size: 0.75rem; font-weight: 700; margin-top: 4px;">${escapeHTML(plan.seatType || 'any')} &bull; ${escapeHTML(plan.shift || 'any')}</span>
          </div>

          <div class="mb-3">
            <h2 style="margin: 0; font-size: 2rem; font-weight: 800; color: var(--color-primary);">
              ${currencyFormatter.format(effectivePrice)}
              <small style="font-size: 0.9rem; font-weight: 600; color: var(--color-text-secondary);">/ ${durationText}</small>
            </h2>
            ${plan.discount > 0 ? `<div style="text-decoration: line-through; color: var(--color-text-muted); font-size: 0.85rem; font-weight: 600;">${currencyFormatter.format(plan.price)}</div>` : ''}
          </div>

          ${plan.description ? `<p class="text-muted small mb-2">${escapeHTML(plan.description)}</p>` : ''}
        </div>
        
        <div style="flex-grow: 1; margin: 12px 0;">
          ${featuresHtml || '<p class="text-muted small mb-0">Standard study room amenities included.</p>'}
        </div>

        <div style="border-top: 1px solid var(--color-divider); padding-top: 14px; margin-top: 8px;" class="d-flex justify-content-between align-items-center">
          <div class="d-flex align-items-center gap-2">
            <input type="checkbox" class="plan-active-toggle" data-id="${plan._id}" ${plan.isActive ? 'checked' : ''} style="cursor: pointer;">
            <label class="small text-muted" style="margin: 0; font-weight: 600;">Active</label>
          </div>
          <div class="d-flex gap-2">
            <button class="btn btn-sm btn-outline-primary btn-edit" data-id="${plan._id}" style="font-weight: 600;">✏️ Edit</button>
            <button class="btn btn-sm btn-outline-danger btn-delete" data-id="${plan._id}" style="font-weight: 600;">🗑️ Delete</button>
          </div>
        </div>
      </div>
    `;
  });
  
  grid.innerHTML = html;
}

function openEditModal(id) {
  const plan = plans.find(p => p._id === id);
  if (!plan) return;
  
  document.getElementById('plan-id').value = plan._id;
  document.getElementById('plan-name').value = plan.name;
  document.getElementById('plan-price').value = plan.price;
  document.getElementById('plan-discount').value = plan.discount || 0;
  document.getElementById('plan-duration').value = plan.duration;
  document.getElementById('plan-durationType').value = plan.durationType || 'days';
  document.getElementById('plan-seatType').value = plan.seatType || 'any';
  document.getElementById('plan-shift').value = plan.shift || 'any';
  document.getElementById('plan-description').value = plan.description || '';
  document.getElementById('plan-features').value = plan.features ? plan.features.join(', ') : '';
  document.getElementById('plan-isActive').checked = plan.isActive;
  
  document.getElementById('planModalTitle').textContent = t('Edit Plan');
  showPlanModal();
}

async function savePlan() {
  const form = document.getElementById('plan-form');
  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }
  
  const id = document.getElementById('plan-id').value;
  const featuresRaw = document.getElementById('plan-features').value;
  const featuresArray = featuresRaw ? featuresRaw.split(',').map(f => f.trim()).filter(Boolean) : [];

  const payload = {
    name: document.getElementById('plan-name').value,
    price: parseFloat(document.getElementById('plan-price').value) || 0,
    discount: parseFloat(document.getElementById('plan-discount').value) || 0,
    duration: parseInt(document.getElementById('plan-duration').value, 10) || 30,
    durationType: document.getElementById('plan-durationType').value,
    seatType: document.getElementById('plan-seatType').value,
    shift: document.getElementById('plan-shift').value,
    description: document.getElementById('plan-description').value,
    features: featuresArray,
    isActive: document.getElementById('plan-isActive').checked
  };
  
  const btn = document.getElementById('btn-save-plan');
  const originalText = btn.innerHTML;
  btn.innerHTML = 'Saving...';
  btn.disabled = true;
  
  try {
    const endpoint = id ? `/api/plans/${id}` : '/api/plans';
    const method = id ? 'put' : 'post';
    
    const res = await api[method](endpoint, payload);
    
    if (res.success) {
      Toast.success(res.message);
      hidePlanModal();
      loadPlans();
    } else {
      Toast.error(res.message);
    }
  } catch (error) {
    Toast.error(error.message || 'Failed to save plan');
  } finally {
    btn.innerHTML = originalText;
    btn.disabled = false;
  }
}

async function deletePlan(id) {
  Confirm.show({
    title: 'Delete Plan',
    message: 'Are you sure you want to deactivate this membership plan?',
    danger: true,
    onConfirm: async () => {
      try {
        const res = await api.delete(`/api/plans/${id}`);
        if (res.success) {
          Toast.success(res.message);
          loadPlans();
        } else {
          Toast.error(res.message);
        }
      } catch (error) {
        Toast.error(error.message || 'Failed to delete plan');
      }
    }
  });
}

async function togglePlanStatus(id, isActive) {
  try {
    const res = await api.put(`/api/plans/${id}`, { isActive });
    if (res.success) {
      Toast.success('Plan status updated');
    } else {
      Toast.error(res.message);
      loadPlans();
    }
  } catch (error) {
    Toast.error('Failed to update plan status');
    loadPlans();
  }
}


async function loadCoupons() {
  const tbody = document.getElementById('coupons-tbody');
  if (!tbody) return;
  try {
    const res = await api.get('/api/coupons');
    if (res.success) {
      coupons = res.coupons;
      renderCouponsGrid();
    }
  } catch (error) {
    console.error(error);
  }
}

function renderCouponsGrid() {
  const tbody = document.getElementById('coupons-tbody');
  if (!tbody) return;
  
  if (!coupons || coupons.length === 0) {
    tbody.innerHTML = '<tr><td colspan="6" class="text-center text-muted p-4">No coupons found.</td></tr>';
    return;
  }
  
  let html = '';
  coupons.forEach(c => {
    const discountStr = c.discountType === 'percentage' ? `${c.discountValue}%` : `₹${c.discountValue}`;
    const validStr = c.validUntil ? new Date(c.validUntil).toLocaleDateString() : 'Never';
    
    html += `
      <tr style="border-bottom: 1px solid var(--color-border);">
        <td style="padding: 12px 16px; font-weight: 700; color: var(--color-primary);">${escapeHTML(c.code)}</td>
        <td style="padding: 12px 16px;">${discountStr}</td>
        <td style="padding: 12px 16px;">₹${c.minPlanAmount}</td>
        <td style="padding: 12px 16px;">${c.usedCount} / ${c.usageLimit}</td>
        <td style="padding: 12px 16px;">
          <input type="checkbox" class="coupon-active-toggle" data-id="${c._id}" ${c.isActive ? 'checked' : ''} style="cursor: pointer;">
        </td>
        <td style="padding: 12px 16px;">
          <button class="btn btn-sm btn-outline-primary btn-edit-coupon" data-id="${c._id}">Edit</button>
          <button class="btn btn-sm btn-outline-danger btn-delete-coupon" data-id="${c._id}">Delete</button>
        </td>
      </tr>
    `;
  });
  tbody.innerHTML = html;
}

function openEditCouponModal(id) {
  const coupon = coupons.find(c => c._id === id);
  if (!coupon) return;
  
  document.getElementById('coupon-id').value = coupon._id;
  document.getElementById('coupon-code').value = coupon.code;
  document.getElementById('coupon-discountType').value = coupon.discountType;
  document.getElementById('coupon-discountValue').value = coupon.discountValue;
  document.getElementById('coupon-minPlanAmount').value = coupon.minPlanAmount || 0;
  document.getElementById('coupon-maxDiscount').value = coupon.maxDiscount || '';
  if (coupon.validUntil) {
    document.getElementById('coupon-validUntil').value = new Date(coupon.validUntil).toISOString().split('T')[0];
  } else {
    document.getElementById('coupon-validUntil').value = '';
  }
  document.getElementById('coupon-usageLimit').value = coupon.usageLimit || 100;
  document.getElementById('coupon-isActive').checked = coupon.isActive;
  
  document.getElementById('couponModalTitle').textContent = t('Edit Coupon');
  document.getElementById('couponModal').style.display = 'flex';
}

async function saveCoupon() {
  const form = document.getElementById('coupon-form');
  if (!form.checkValidity()) {
    form.reportValidity();
    return;
  }
  
  const id = document.getElementById('coupon-id').value;
  const payload = {
    code: document.getElementById('coupon-code').value.toUpperCase(),
    discountType: document.getElementById('coupon-discountType').value,
    discountValue: parseFloat(document.getElementById('coupon-discountValue').value),
    minPlanAmount: parseFloat(document.getElementById('coupon-minPlanAmount').value) || 0,
    maxDiscount: document.getElementById('coupon-maxDiscount').value ? parseFloat(document.getElementById('coupon-maxDiscount').value) : null,
    validUntil: document.getElementById('coupon-validUntil').value || null,
    usageLimit: parseInt(document.getElementById('coupon-usageLimit').value) || 100,
    isActive: document.getElementById('coupon-isActive').checked
  };
  
  const btn = document.getElementById('btn-save-coupon');
  const origText = btn.innerHTML;
  btn.innerHTML = 'Saving...';
  btn.disabled = true;
  
  try {
    const endpoint = id ? `/api/coupons/${id}` : '/api/coupons';
    const method = id ? 'put' : 'post';
    const res = await api[method](endpoint, payload);
    if (res.success) {
      Toast.success('Coupon saved successfully');
      document.getElementById('couponModal').style.display = 'none';
      loadCoupons();
    } else {
      Toast.error(res.message);
    }
  } catch (err) {
    Toast.error('Failed to save coupon');
  } finally {
    btn.innerHTML = origText;
    btn.disabled = false;
  }
}

async function deleteCoupon(id) {
  Confirm.show({
    title: 'Delete Coupon',
    message: 'Are you sure you want to delete this coupon?',
    danger: true,
    onConfirm: async () => {
      try {
        const res = await api.delete(`/api/coupons/${id}`);
        if (res.success) {
          Toast.success('Coupon deleted');
          loadCoupons();
        } else {
          Toast.error(res.message);
        }
      } catch (err) {
        Toast.error('Failed to delete coupon');
      }
    }
  });
}

async function toggleCouponStatus(id, isActive) {
  try {
    const res = await api.put(`/api/coupons/${id}`, { isActive });
    if (!res.success) {
      Toast.error(res.message);
      loadCoupons();
    }
  } catch (err) {
    Toast.error('Failed to update status');
    loadCoupons();
  }
}
