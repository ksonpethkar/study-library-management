import { App } from '../app.js';
import { t } from '../i18n.js';
import { Toast, Modal, Loading, Confirm, escapeHTML, debounce, copyToClipboard, UI } from '../ui.js';
import { SmartFormatters } from '../utils/smartFormatters.js';
import api from '../api.js';
import { IDBStorage } from '../utils/idbStorage.js';
import { OptimisticUI } from '../utils/optimisticUI.js';

const formatCurrency = (amount) => SmartFormatters.currency(amount);

const formatDate = (dateString) => {
    if (!dateString) return '-';
    return new Date(dateString).toLocaleDateString('en-IN');
};

export async function render(container) {
    if (!container) {
        container = document.createElement('div');
        container.className = 'page-container';
    }
    
    container.innerHTML = `
        <!-- Standard Module Header -->
        <div class="module-header">
            <div class="module-title-area">
                <h2>💰 Payment Management</h2>
                <p>Track student fee collections, generate GST/standard receipts, and manage pending dues.</p>
            </div>
            <div class="module-actions">
                <button class="btn btn-primary d-flex align-items-center gap-2" id="btnCollectPayment" style="font-weight: 700;">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                    + Collect Fee Payment
                </button>
            </div>
        </div>
        
        <!-- Contextual Guidance Tip Banner -->
        <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
            <span style="font-size: 1.1rem;">💡</span>
            <span><strong>Tip:</strong> 1-Tap WhatsApp buttons send instant payment receipts and partial fee balance reminders with pre-filled UPI deep links.</span>
        </div>

        <!-- Standard KPI Stats Grid -->
        <div class="kpi-grid" id="paymentsStatsContainer">
            <div class="kpi-card kpi-success">
                <div class="kpi-label">Today's Collection <span>💵</span></div>
                <div class="kpi-value text-success" id="statToday">₹0</div>
                <div class="kpi-subtext">Received today</div>
            </div>
            <div class="kpi-card kpi-primary">
                <div class="kpi-label">This Month Collection <span>📅</span></div>
                <div class="kpi-value" id="statMonth" style="color: var(--color-primary);">₹0</div>
                <div class="kpi-subtext">Current billing cycle</div>
            </div>
            <div class="kpi-card kpi-danger">
                <div class="kpi-label">Pending Dues <span>⚠️</span></div>
                <div class="kpi-value text-danger" id="statPending">₹0</div>
                <div class="kpi-subtext">Overdue fees</div>
            </div>
            <div class="kpi-card kpi-info">
                <div class="kpi-label">Total Invoices <span>🧾</span></div>
                <div class="kpi-value" id="statTotalCount" style="color: var(--color-info);">0</div>
                <div class="kpi-subtext">Issued receipts</div>
            </div>
        </div>
        
        <!-- Recent Payments Table Card -->
        <div class="card mb-4">
            <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-3">
                <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700;">Recent Fee Payments</h3>
                <div class="filters d-flex gap-2 align-items-center flex-wrap w-100 w-md-auto">
                    <select id="filterMethod" class="form-select form-control form-control-sm w-100 w-md-auto" style="font-weight: 600;">
                        <option value="">All Methods</option>
                        <option value="cash">💵 Cash</option>
                        <option value="upi">📱 UPI / QR</option>
                        <option value="bank_transfer">🏦 Bank Transfer</option>
                        <option value="card">💳 Card</option>
                    </select>
                    <select id="filterStatus" class="form-select form-control form-control-sm w-100 w-md-auto" style="font-weight: 600;">
                        <option value="">All Statuses</option>
                        <option value="paid">🟢 Paid</option>
                        <option value="pending">🟡 Pending</option>
                        <option value="partial">🟠 Partial</option>
                        <option value="refunded">🔴 Refunded</option>
                    </select>
                    <button id="btnPendingInstallments" class="btn btn-sm btn-outline-warning w-100 w-md-auto" style="font-weight: 600;">⏳ Pending Balances</button>
                    <button id="btnExportPaymentsCSV" class="btn btn-sm btn-outline-success w-100 w-md-auto" style="font-weight: 600;">📥 Export CSV</button>
                </div>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table data-table mb-0">
                        <thead>
                            <tr>
                                <th>Receipt #</th>
                                <th>Student</th>
                                <th>Amount</th>
                                <th>Method</th>
                                <th>Date</th>
                                <th>Status</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody id="paymentsTableBody">
                            <tr><td colspan="7" class="text-center p-4">Loading payments...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
        
        <!-- Pending Dues Card -->
        <div class="card">
            <div class="card-header">
                <h5 style="margin: 0; font-size: 1.1rem; font-weight: 600; color: var(--color-danger, #d63031);">⚠️ Expired Memberships & Pending Dues</h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table mb-0">
                        <thead>
                            <tr>
                                <th>Student</th>
                                <th>Phone</th>
                                <th>Plan</th>
                                <th>Expired On</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody id="duesTableBody">
                            <tr><td colspan="5" class="text-center p-4">Loading dues...</td></tr>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    `;

    setTimeout(() => {
        loadStats();
        loadPayments();
        loadDues();
        
        const collectBtn = container.querySelector('#btnCollectPayment');
        if (collectBtn) collectBtn.addEventListener('click', () => showCollectModal());
        
        const methodSelect = container.querySelector('#filterMethod');
        if (methodSelect) methodSelect.addEventListener('change', loadPayments);
        
        const statusSelect = container.querySelector('#filterStatus');
        if (statusSelect) statusSelect.addEventListener('change', loadPayments);
        
        const btnPending = container.querySelector('#btnPendingInstallments');
        if (btnPending) btnPending.addEventListener('click', () => {
            if (statusSelect) statusSelect.value = 'partial';
            loadPayments();
        });

        const btnExport = container.querySelector('#btnExportPaymentsCSV');
        if (btnExport) btnExport.addEventListener('click', exportPaymentsCSV);
    }, 0);

    async function exportPaymentsCSV() {
        try {
            Loading.show('Preparing CSV export...');
            const method = document.getElementById('filterMethod')?.value || '';
            const status = document.getElementById('filterStatus')?.value || '';
            let url = '/api/payments?limit=1000';
            if (method) url += `&method=${method}`;
            if (status) url += `&status=${status}`;

            const res = await api.get(url);
            Loading.hide();

            if (!res.success || !res.data || res.data.length === 0) {
                Toast.error('No payment records to export');
                return;
            }

            const payments = res.data;
            let csvContent = 'Receipt No,Student Name,Student Phone,Amount (INR),Payment Method,Transaction UTR,Date,Status\n';

            payments.forEach(p => {
                const receiptNo = p.receiptNumber || p._id;
                const studentName = (p.student?.name || p.studentName || 'Student').replace(/,/g, '');
                const phone = p.student?.phone || p.phone || '';
                const amount = p.finalAmount || p.amount || 0;
                const pMethod = p.paymentMethod || 'cash';
                const utr = p.transactionId || 'N/A';
                const date = p.createdAt ? new Date(p.createdAt).toLocaleDateString('en-IN') : '';
                const pStatus = p.status || 'paid';

                csvContent += `"${receiptNo}","${studentName}","${phone}",${amount},"${pMethod}","${utr}","${date}","${pStatus}"\n`;
            });

            const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
            const urlBlob = URL.createObjectURL(blob);
            const link = document.createElement('a');
            link.href = urlBlob;
            link.setAttribute('download', `Payments_Ledger_${new Date().toISOString().split('T')[0]}.csv`);
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
            Toast.success('Payments CSV downloaded successfully!');
        } catch (err) {
            Loading.hide();
            Toast.error('Failed to export CSV: ' + err.message);
        }
    }

    async function loadStats() {
        try {
            const cachedStats = await IDBStorage.get('payments', 'stats');
            if (cachedStats) {
                const elToday = document.getElementById('statToday');
                const elMonth = document.getElementById('statMonth');
                const elPending = document.getElementById('statPending');
                if (elToday) elToday.textContent = formatCurrency(cachedStats.todayRevenue);
                if (elMonth) elMonth.textContent = formatCurrency(cachedStats.monthRevenue);
                if (elPending) elPending.textContent = formatCurrency(cachedStats.totalPending);
            }
        } catch (e) {
            console.warn('IDB read payments stats warning:', e);
        }

        try {
            const res = await api.get('/api/payments/stats');
            if (res.success && res.data) {
                await IDBStorage.set('payments', 'stats', res.data);
                const elToday = document.getElementById('statToday');
                const elMonth = document.getElementById('statMonth');
                const elPending = document.getElementById('statPending');
                if (elToday) elToday.textContent = formatCurrency(res.data.todayRevenue);
                if (elMonth) elMonth.textContent = formatCurrency(res.data.monthRevenue);
                if (elPending) elPending.textContent = formatCurrency(res.data.totalPending);
            }
        } catch (e) {
            console.error('Error loading stats', e);
        }
    }

    function renderPaymentsTableRows(payments, tbody) {
        if (!tbody) return;
        if (!payments || payments.length === 0) {
            UI.emptyState(tbody, {
                icon: '💳',
                title: 'No Payments Found',
                description: 'No fee collection transactions recorded matching your filter. Click below to collect fee.',
                actionText: '+ Collect Fee Payment',
                onAction: () => {
                    const btnCollect = document.getElementById('btnCollectPayment');
                    if (btnCollect) btnCollect.click();
                }
            });
            return;
        }

        tbody.innerHTML = payments.map(p => `
            <tr>
                <td>
                    <a href="#" class="receipt-link" data-id="${p._id}" style="font-family: monospace; font-weight: 700; color: var(--color-primary, #6c5ce7);">${escapeHTML(p.receiptNumber || 'N/A')}</a>
                    <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(p.receiptNumber || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Receipt Number">📋</button>
                </td>
                <td>
                    <div style="font-weight: 600;">${escapeHTML(p.student?.name || 'Unknown')}</div>
                    <small class="text-muted">${escapeHTML(SmartFormatters.phone(p.student?.phone) || '')}</small>
                    ${p.student?.phone ? `<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(p.student.phone)}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">📋</button>` : ''}
                </td>
                <td><strong style="font-size: 1.05rem;">${formatCurrency(p.finalAmount)}</strong></td>
                <td><span class="badge" style="background: rgba(255,255,255,0.08); padding: 4px 8px; border-radius: 4px; text-transform: uppercase;">${escapeHTML(p.paymentMethod)}</span></td>
                <td>${formatDate(p.paymentDate)} <small class="text-muted">(${SmartFormatters.timeAgo(p.paymentDate)})</small></td>
                <td>
                    <span class="badge btn-toggle-payment-status" data-id="${p._id}" data-status="${escapeHTML(p.status)}" style="${p.status === 'paid' ? 'background: rgba(0, 184, 148, 0.2); color: var(--color-success);' : 'background: rgba(214, 48, 49, 0.2); color: var(--color-danger);'} padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;" title="Click to toggle status">
                        ${escapeHTML(p.status)}
                    </span>
                </td>
                <td>
                    <button class="btn btn-sm btn-outline-primary btn-view" data-id="${p._id}" style="padding: 3px 8px; font-size: 0.8rem;">View Receipt</button>
                    ${p.status === 'partial' && p.balanceDue > 0 ? `
                        <button class="btn btn-sm btn-warning btn-pay-balance" data-id="${p._id}" data-balance="${p.balanceDue}" style="padding: 3px 8px; font-size: 0.8rem; margin-left: 4px;">💰 Pay Balance</button>
                        <button class="btn btn-sm btn-outline-success btn-remind-balance" data-id="${p._id}" data-student-id="${p.student?._id || p.student}" data-name="${escapeHTML(p.student?.name || 'Student')}" data-balance="${p.balanceDue}" style="padding: 3px 8px; font-size: 0.8rem; margin-left: 4px; white-space: nowrap;" title="Send WhatsApp Balance Reminder with 1-Tap UPI Link">📲 WhatsApp Reminder</button>
                    ` : ''}
                </td>
            </tr>
        `).join('');

        tbody.querySelectorAll('.btn-copy-text').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                const copyText = btn.getAttribute('data-copy');
                if (copyText) copyToClipboard(copyText, btn);
            });
        });

        tbody.querySelectorAll('.receipt-link, .btn-view').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                showReceiptModal(btn.dataset.id);
            });
        });
        tbody.querySelectorAll('.btn-toggle-payment-status').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                const id = btn.dataset.id;
                const currentStatus = btn.dataset.status || 'paid';
                const newStatus = currentStatus === 'paid' ? 'pending' : 'paid';

                OptimisticUI.execute({
                    applyState: () => {
                        btn.dataset.status = newStatus;
                        btn.textContent = newStatus;
                        btn.style.cssText = newStatus === 'paid'
                            ? 'background: rgba(0, 184, 148, 0.2); color: var(--color-success); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;'
                            : 'background: rgba(214, 48, 49, 0.2); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;';
                    },
                    rollbackState: () => {
                        btn.dataset.status = currentStatus;
                        btn.textContent = currentStatus;
                        btn.style.cssText = currentStatus === 'paid'
                            ? 'background: rgba(0, 184, 148, 0.2); color: var(--color-success); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;'
                            : 'background: rgba(214, 48, 49, 0.2); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;';
                    },
                    apiCall: () => api.put(`/api/payments/${id}`, { status: newStatus }),
                    onSuccess: async (res) => {
                        Toast.success(res?.message || `Payment status changed to ${newStatus}`);
                        await IDBStorage.clear('payments');
                        loadStats();
                    }
                });
            });
        });
        tbody.querySelectorAll('.btn-pay-balance').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                showPayBalanceModal(btn.dataset.id, btn.dataset.balance);
            });
        });
        tbody.querySelectorAll('.btn-remind-balance').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.preventDefault();
                const paymentId = btn.dataset.id;
                const studentId = btn.dataset.studentId;
                const studentName = btn.dataset.name;
                const balanceDue = btn.dataset.balance;
                
                try {
                    const res = await api.post('/api/messages/send-reminder', {
                        studentId,
                        paymentId,
                        message: `Hello ${studentName}, this is a gentle reminder that your partial fee balance of ₹${balanceDue} is pending. Please complete your payment using this link: {{upi_link}}`
                    });
                    if (res.success) {
                        Toast.success('WhatsApp reminder sent successfully!');
                        if (res.data?.waUrl) {
                            window.open(res.data.waUrl, '_blank');
                        }
                    } else {
                        Toast.error(res.message || 'Failed to send WhatsApp reminder');
                    }
                } catch (err) {
                    Toast.error(err.message || 'Error sending WhatsApp reminder');
                }
            });
        });
    }

    async function loadPayments() {
        const method = document.getElementById('filterMethod')?.value || '';
        const status = document.getElementById('filterStatus')?.value || '';
        let url = '/api/payments?limit=20';
        if (method) url += `&method=${method}`;
        if (status) url += `&status=${status}`;
        const cacheKey = `list_${method}_${status}`;
        
        const tbody = document.getElementById('paymentsTableBody');
        if (!tbody) return;

        let hasRenderedCache = false;
        try {
            const cachedPayments = await IDBStorage.get('payments', cacheKey);
            if (cachedPayments && Array.isArray(cachedPayments)) {
                renderPaymentsTableRows(cachedPayments, tbody);
                hasRenderedCache = true;
            }
        } catch (e) {
            console.warn('IDB read payments list warning:', e);
        }

        if (!hasRenderedCache) {
            Loading.skeleton(tbody, 'table');
        }

        try {
            const res = await api.get(url);
            if (!res.success || !res.data.payments) {
                if (!hasRenderedCache) {
                    tbody.innerHTML = '<tr><td colspan="7" class="text-center empty-state p-4 text-muted">No payments found. Click "Collect Fee Payment" to record one.</td></tr>';
                }
                return;
            }

            await IDBStorage.set('payments', cacheKey, res.data.payments);
            renderPaymentsTableRows(res.data.payments, tbody);
        } catch (e) {
            console.error('Error loading payments', e);
            if (!hasRenderedCache) {
                tbody.innerHTML = '<tr><td colspan="7" class="text-center empty-state p-4 text-muted">Error loading payments list.</td></tr>';
            }
        }
    }

    async function loadDues() {
        const tbody = document.getElementById('duesTableBody');
        if (tbody) Loading.skeleton(tbody, 'table');
        try {
            const res = await api.get('/api/payments/dues');
            if (!tbody) return;

            if (!res.success || !res.data || res.data.length === 0) {
                UI.emptyState(tbody, {
                    icon: '🎉',
                    title: 'All Memberships Up To Date',
                    description: 'Great news! There are currently no expired memberships or overdue fee balances.'
                });
                return;
            }
            
            tbody.innerHTML = res.data.map(d => `
                <tr>
                    <td><strong>${escapeHTML(d.name)}</strong></td>
                    <td>${escapeHTML(SmartFormatters.phone(d.phone))} <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(d.phone || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">📋</button></td>
                    <td><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary);">${escapeHTML(d.plan?.name || '-')}</span></td>
                    <td><span style="color: var(--color-danger); font-weight: 600;">${formatDate(d.expiryDate)} <small class="text-muted">(${SmartFormatters.timeAgo(d.expiryDate)})</small></span></td>
                    <td>
                        <button class="btn btn-sm btn-success btn-collect-due" data-id="${d._id}" style="padding: 3px 8px; font-size: 0.8rem;">Collect Fee</button>
                        <button class="btn btn-sm btn-outline-success btn-remind-due" data-id="${d._id}" data-name="${escapeHTML(d.name)}" style="padding: 3px 8px; font-size: 0.8rem; margin-left: 4px; white-space: nowrap;" title="Send WhatsApp Renewal Reminder with 1-Tap UPI Link">📲 WhatsApp Reminder</button>
                    </td>
                </tr>
            `).join('');
            
            tbody.querySelectorAll('.btn-copy-text').forEach(btn => {
                btn.addEventListener('click', (e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    const copyText = btn.getAttribute('data-copy');
                    if (copyText) copyToClipboard(copyText, btn);
                });
            });
            
            tbody.querySelectorAll('.btn-collect-due').forEach(btn => {
                btn.addEventListener('click', () => {
                    showCollectModal(btn.dataset.id);
                });
            });
            tbody.querySelectorAll('.btn-remind-due').forEach(btn => {
                btn.addEventListener('click', async (e) => {
                    e.preventDefault();
                    const studentId = btn.dataset.id;
                    const studentName = btn.dataset.name;
                    try {
                        Loading.show('Preparing WhatsApp reminder & UPI link...');
                        const res = await api.post('/api/messages/send-reminder', {
                            studentId,
                            reminderType: 'renewal_reminder'
                        });
                        Loading.hide();
                        if (res.success && res.data) {
                            if (res.data.whatsappUrl) {
                                window.open(res.data.whatsappUrl, '_blank');
                            }
                            Toast.success(`WhatsApp reminder prepared for ${studentName || res.data.studentName}!`);
                        } else {
                            Toast.error(res.message || 'Failed to dispatch reminder');
                        }
                    } catch (err) {
                        Loading.hide();
                        Toast.error(err.message || 'Failed to dispatch reminder');
                    }
                });
            });
        } catch (e) {
            console.error('Error loading dues', e);
        }
    }

    async function showCollectModal(studentId = null) {
        // Fetch active plans and students for easy selection
        let plansOptions = '<option value="">-- Select Plan --</option>';
        let studentsOptions = '<option value="">-- Select Student --</option>';
        let preloadedStudent = null;

        try {
            const [plansRes, studentsRes] = await Promise.all([
                api.get('/api/plans'),
                api.get('/api/students?limit=100&status=active')
            ]);
            
            if (plansRes.success && plansRes.data) {
                plansRes.data.forEach(p => {
                    plansOptions += `<option value="${p._id}" data-price="${p.price}">${escapeHTML(p.name)} - ₹${p.price} (${p.duration} ${p.durationType})</option>`;
                });
            }

            if (studentsRes.success && studentsRes.data?.students) {
                studentsRes.data.students.forEach(s => {
                    const isSelected = studentId && s._id === studentId;
                    if (isSelected) preloadedStudent = s;
                    studentsOptions += `<option value="${s._id}" ${isSelected ? 'selected' : ''}>${escapeHTML(s.name)} (${escapeHTML(s.studentId || '')} - ${escapeHTML(s.phone || '')})</option>`;
                });
            }
        } catch (e) {
            console.error('Error preloading data for payment modal', e);
        }

        const content = document.createElement('div');
        content.innerHTML = `
            <form id="paymentForm">
                <div class="row" style="row-gap: 14px;">
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Select Student *</label>
                        <select id="studentSelect" name="student" class="form-select form-control" required>
                            ${studentsOptions}
                        </select>
                    </div>
                    
                    <div class="col-md-6">
                        <label class="form-label" style="font-weight: 500;">Membership Plan</label>
                        <select name="plan" id="planSelect" class="form-select form-control">
                            ${plansOptions}
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" style="font-weight: 500;">Payment Method *</label>
                        <select name="paymentMethod" class="form-select form-control" required>
                            <option value="cash">Cash</option>
                            <option value="upi" selected>UPI (GPay / PhonePe / Paytm)</option>
                            <option value="bank_transfer">Bank Transfer (NEFT/IMPS)</option>
                            <option value="card">Debit / Credit Card</option>
                        </select>
                    </div>
                    
                    <div class="col-md-4">
                        <label class="form-label" style="font-weight: 500;">Amount (₹) *</label>
                        <input type="number" name="amount" id="payAmount" class="form-control calc-field" required min="0" value="0">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label" style="font-weight: 500;">Discount (₹)</label>
                        <input type="number" name="discount" id="payDiscount" class="form-control calc-field" value="0" min="0">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label" style="font-weight: 500;">Late Fee (₹)</label>
                        <input type="number" name="lateFee" id="payLateFee" class="form-control calc-field" value="0" min="0">
                    </div>
                    
                    <div class="col-12 p-3" style="background: var(--color-bg-secondary, rgba(255,255,255,0.05)); border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
                        <span style="font-weight: 600;">Net Payable Amount:</span>
                        <h4 id="finalAmountDisplay" style="margin: 0; color: var(--color-success, #00b894); font-size: 1.4rem; font-weight: 700;">₹0</h4>
                    </div>
                    
                    <div class="col-md-6">
                        <label class="form-label" style="font-weight: 500;">UPI / 12-Digit UTR Transaction ID</label>
                        <input type="text" name="transactionId" id="payTransactionId" class="form-control" placeholder="e.g. 12-digit UTR (e.g. 423456789012)" maxlength="30">
                        <small id="utrWarnMsg" class="text-danger" style="display: none; font-size: 0.75rem; margin-top: 3px; font-weight: 600;"></small>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" style="font-weight: 500;">Remarks / Notes</label>
                        <input type="text" name="notes" class="form-control" placeholder="Optional notes...">
                    </div>
                    
                    <div class="col-12 text-end mt-3 d-flex justify-content-end gap-2">
                        <button type="button" class="btn btn-secondary modal-close-btn" onclick="Modal.close()">Cancel</button>
                        <button type="submit" class="btn btn-primary">Record Payment & Generate Receipt</button>
                    </div>
                </div>
            </form>
        `;
        
        const modal = new Modal({
            title: 'Collect Fee Payment',
            content: content,
            size: 'md'
        });
        modal.show();
        
        const form = content.querySelector('#paymentForm');
        const planSelect = content.querySelector('#planSelect');
        const payAmount = content.querySelector('#payAmount');
        const payDiscount = content.querySelector('#payDiscount');
        const payLateFee = content.querySelector('#payLateFee');
        const finalDisplay = content.querySelector('#finalAmountDisplay');
        const studentSelect = content.querySelector('#studentSelect');

        const calculateFinal = () => {
            const amount = parseFloat(payAmount.value) || 0;
            const discount = parseFloat(payDiscount.value) || 0;
            const late = parseFloat(payLateFee.value) || 0;
            const final = Math.max(0, amount - discount + late);
            finalDisplay.textContent = formatCurrency(final);
        };

        [payAmount, payDiscount, payLateFee].forEach(input => {
            input.addEventListener('input', calculateFinal);
        });

        planSelect.addEventListener('change', () => {
            const opt = planSelect.options[planSelect.selectedIndex];
            if (opt && opt.dataset.price) {
                payAmount.value = opt.dataset.price;
                calculateFinal();
            }
        });

        // Auto-select student's plan if available
        if (preloadedStudent && preloadedStudent.plan) {
            const planId = preloadedStudent.plan._id || preloadedStudent.plan;
            planSelect.value = planId;
            const opt = planSelect.options[planSelect.selectedIndex];
            if (opt && opt.dataset.price) {
                payAmount.value = opt.dataset.price;
                calculateFinal();
            }
        }
        
        const payTxnInput = content.querySelector('#payTransactionId');
        const utrWarnMsg = content.querySelector('#utrWarnMsg');

        const validateUTR = async () => {
            const txnVal = payTxnInput?.value?.trim() || '';
            if (!txnVal || !utrWarnMsg) {
                if (utrWarnMsg) utrWarnMsg.style.display = 'none';
                return true;
            }

            if (/^\d+$/.test(txnVal) && txnVal.length !== 12) {
                utrWarnMsg.textContent = `ℹ️ UPI UTR is usually 12 digits (currently ${txnVal.length} digits)`;
                utrWarnMsg.style.color = 'var(--color-warning, #f59e0b)';
                utrWarnMsg.style.display = 'block';
            } else {
                utrWarnMsg.style.display = 'none';
            }

            try {
                const cachedPayments = await IDBStorage.get('payments', 'list__') || [];
                const isDup = Array.isArray(cachedPayments) && cachedPayments.some(p => p.transactionId && p.transactionId.trim().toLowerCase() === txnVal.toLowerCase());
                if (isDup) {
                    utrWarnMsg.textContent = `⚠️ Warning: Transaction Ref ID "${txnVal}" has already been recorded!`;
                    utrWarnMsg.style.color = 'var(--color-danger, #d63031)';
                    utrWarnMsg.style.display = 'block';
                    return false;
                }
            } catch (e) {}
            return true;
        };

        if (payTxnInput) {
            ['input', 'blur', 'change'].forEach(evt => payTxnInput.addEventListener(evt, validateUTR));
        }

        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const submitBtn = form.querySelector('button[type="submit"]');
            const formData = new FormData(form);
            const data = Object.fromEntries(formData.entries());
            
            if (!data.student) {
                Toast.error('Please select a student');
                return;
            }
            if (!data.plan) delete data.plan;

            data.amount = parseFloat(data.amount) || 0;
            data.discount = parseFloat(data.discount) || 0;
            data.lateFee = parseFloat(data.lateFee) || 0;
            
            if (submitBtn) UI.buttonLoading(submitBtn, true, 'Processing...');
            try {
                const res = await api.post('/api/payments', data);
                if (res.success) {
                    modal.hide();
                    Toast.success('Payment collected successfully!');
                    await IDBStorage.clear('payments');
                    loadStats();
                    loadPayments();
                    loadDues();
                    if (res.data?._id) {
                        showReceiptModal(res.data._id);
                    }
                } else {
                    Toast.error(res.message || 'Failed to collect payment');
                }
            } catch (err) {
                Toast.error(err.message || 'An error occurred while saving payment');
            } finally {
                if (submitBtn) UI.buttonLoading(submitBtn, false);
            }
        });
    }

    async function showPayBalanceModal(paymentId, balanceDue) {
        const content = document.createElement('div');
        content.innerHTML = `
            <form id="payBalanceForm">
                <div class="row" style="row-gap: 14px;">
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Balance Due (₹)</label>
                        <input type="number" class="form-control" value="${balanceDue}" readonly>
                    </div>
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Amount to Pay (₹) *</label>
                        <input type="number" name="amount" class="form-control" max="${balanceDue}" min="1" required value="${balanceDue}">
                    </div>
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Payment Method *</label>
                        <select name="method" class="form-select form-control" required>
                            <option value="cash">Cash</option>
                            <option value="upi" selected>UPI (GPay / PhonePe / Paytm)</option>
                            <option value="bank_transfer">Bank Transfer (NEFT/IMPS)</option>
                            <option value="card">Debit / Credit Card</option>
                        </select>
                    </div>
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Transaction ID (Optional)</label>
                        <input type="text" name="transactionId" class="form-control">
                    </div>
                    <div class="col-12 text-end mt-3 d-flex justify-content-end gap-2">
                        <button type="button" class="btn btn-secondary modal-close-btn" onclick="Modal.close()">Cancel</button>
                        <button type="submit" class="btn btn-primary">Pay Installment</button>
                    </div>
                </div>
            </form>
        `;
        
        const modal = new Modal({
            title: 'Pay Balance Installment',
            content: content,
            size: 'md'
        });
        modal.show();
        
        const form = content.querySelector('#payBalanceForm');
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            const formData = new FormData(form);
            const data = Object.fromEntries(formData.entries());
            data.amount = parseFloat(data.amount) || 0;
            
            try {
                await OptimisticUI.execute({
                    applyState: () => {
                        modal.hide();
                        const row = document.querySelector(`.receipt-link[data-id="${paymentId}"]`)?.closest('tr');
                        if (row) {
                            const badge = row.querySelector('.badge.btn-toggle-payment-status');
                            if (badge) {
                                badge.textContent = 'paid';
                                badge.style.cssText = 'background: rgba(0, 184, 148, 0.2); color: var(--color-success); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;';
                            }
                        }
                    },
                    rollbackState: () => {
                        const row = document.querySelector(`.receipt-link[data-id="${paymentId}"]`)?.closest('tr');
                        if (row) {
                            const badge = row.querySelector('.badge.btn-toggle-payment-status');
                            if (badge) {
                                badge.textContent = 'partial';
                                badge.style.cssText = 'background: rgba(214, 48, 49, 0.2); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;';
                            }
                        }
                    },
                    apiCall: () => api.post(`/api/payments/${paymentId}/pay-balance`, data),
                    onSuccess: async (res) => {
                        Toast.success('Installment paid successfully!');
                        await IDBStorage.clear('payments');
                        loadStats();
                        loadPayments();
                        showReceiptModal(paymentId);
                    }
                });
            } catch (err) {
                // Handled by OptimisticUI
            }
        });
    }

    async function showReceiptModal(paymentId) {
        try {
            const [res, configRes, settingsRes] = await Promise.all([
                api.get(`/api/payments/${paymentId}/receipt`),
                api.get('/api/settings/receipt-config'),
                api.get('/api/settings')
            ]);
            
            if (!res.success || !res.data) {
                Toast.error('Failed to load receipt details');
                return;
            }
            
            const r = res.data;
            const config = configRes.success && configRes.data ? configRes.data : { header: {}, body: {}, gst: {}, footer: {} };
            const bp = settingsRes.success && settingsRes.data && settingsRes.data.businessProfile ? settingsRes.data.businessProfile : {};
            const activeTemplate = config.activeTemplate || 'standard_a4';

            const receiptDiv = document.createElement('div');
            receiptDiv.innerHTML = `
                <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
                    <div class="d-flex align-items-center gap-2">
                        <label class="form-label mb-0 small" style="font-weight: 600;">Paper Format:</label>
                        <select id="receipt-paper-format" class="form-select form-select-sm" style="width: 170px; padding: 4px 8px; font-size: 0.85rem;">
                            <option value="standard" ${activeTemplate === 'standard_a4' || activeTemplate === 'modern_minimal' || activeTemplate === 'gst_invoice' ? 'selected' : ''}>📄 Standard A4 / A5</option>
                            <option value="thermal-80" ${activeTemplate === 'thermal_80' ? 'selected' : ''}>🧾 80mm Thermal (POS)</option>
                            <option value="thermal-58" ${activeTemplate === 'thermal_58' ? 'selected' : ''}>🧾 58mm Thermal (Mini)</option>
                        </select>
                    </div>
                    <div class="d-flex align-items-center gap-2">
                        <button class="btn btn-sm btn-outline-primary" data-template="standard_a4">Standard</button>
                        <button class="btn btn-sm btn-outline-primary" data-template="thermal_80">80mm</button>
                        <button class="btn btn-sm btn-outline-primary" data-template="thermal_58">58mm</button>
                        <button class="btn btn-sm btn-outline-primary" data-template="modern_minimal">Modern</button>
                        <button class="btn btn-sm btn-outline-primary" data-template="gst_invoice">GST</button>
                    </div>
                </div>

                <div id="receipt-container-box" class="receipt-print-area" style="background: var(--color-surface, #fff); border-radius: 8px; transition: max-width 0.3s ease; margin: 0 auto; overflow: hidden; color: #000;">
                    <!-- Content rendered here -->
                </div>
                
                <div class="text-center mt-3 d-flex justify-content-center flex-wrap gap-2">
                    <button class="btn btn-success" id="btn-share-whatsapp-receipt" style="background: #25D366; border-color: #25D366; font-weight: 600;">
                        📲 WhatsApp
                    </button>
                    <button class="btn btn-primary" id="btn-print-receipt-action">🖨️ Print</button>
                    <button class="btn btn-secondary modal-close-btn" onclick="Modal.close()">Close</button>
                </div>
            `;
            
            const receiptBox = receiptDiv.querySelector('#receipt-container-box');
            
            const renderTemplate = (templateId) => {
                const head = config.header || {};
                const bdy = config.body || {};
                const gst = config.gst || {};
                const ftr = config.footer || {};
                const logoImg = head.logoUrl || bp.logo || '';
                const stampImg = ftr.stampImage || bp.stampImage || '';
                const sigImg = ftr.signatureImage || '';
                const gstNo = head.gstNumber || bp.gstNumber || '';
                const taxNo = head.taxNumber || bp.registrationNumber || '';
                
                let html = '';
                
                if (templateId === 'standard_a4') {
                    receiptBox.style.maxWidth = '100%';
                    receiptBox.style.padding = '30px';
                    receiptBox.style.border = '1px solid #ddd';
                    receiptBox.style.fontFamily = 'inherit';
                    
                    html = `
                        <div style="text-align: ${head.logoPosition || 'center'}; border-bottom: 2px solid ${head.headerColor || '#4f46e5'}; padding-bottom: 15px; margin-bottom: 20px;">
                            ${head.showLogo && logoImg ? `<img src="${logoImg}" style="max-height: 60px; margin-bottom: 10px;">` : ''}
                            ${head.showBusinessName ? `<h2 style="margin: 0; color: ${head.headerColor || '#4f46e5'};">${escapeHTML(bp.businessName || r.businessName || 'Library')}</h2>` : ''}
                            <p style="margin: 5px 0 0; color: #555;">${escapeHTML(head.subtitle || 'Official Fee Receipt')}</p>
                            ${head.showAddress && bp.address ? `<p style="margin: 5px 0 0; font-size: 0.9em; color: #666;">${escapeHTML(bp.address)}</p>` : ''}
                            <div style="font-size: 0.85em; color: #666; margin-top: 5px;">
                                ${head.showPhone && bp.phone ? `<span>📞 ${escapeHTML(bp.phone)}</span> ` : ''}
                                ${head.showEmail && bp.email ? `<span>✉️ ${escapeHTML(bp.email)}</span>` : ''}
                                ${head.showGst && gstNo ? `<br><span>GSTIN: ${escapeHTML(gstNo)}</span>` : ''}
                                ${taxNo ? `<span style="margin-left: 8px;">Tax ID: ${escapeHTML(taxNo)}</span>` : ''}
                            </div>
                        </div>
                        
                        <div style="display: flex; justify-content: space-between; margin-bottom: 20px; flex-wrap: wrap; gap: 10px;">
                            <div style="flex: 1; min-width: 220px; padding: 10px; border: 1px solid #eee; border-radius: 5px;">
                                <h4 style="margin: 0 0 10px; font-size: 1em; color: #333;">Student Details</h4>
                                <p style="margin: 0 0 5px; color: #000;"><strong>Name:</strong> ${escapeHTML(r.student?.name || 'N/A')}</p>
                                ${bdy.showStudentId ? `<p style="margin: 0 0 5px; color: #000;"><strong>ID:</strong> ${escapeHTML(r.student?.studentId || 'N/A')}</p>` : ''}
                                ${bdy.showStudentPhone ? `<p style="margin: 0 0 5px; color: #000;"><strong>Phone:</strong> ${escapeHTML(r.student?.phone || 'N/A')}</p>` : ''}
                                ${bdy.showSeatNumber && (r.student?.seat?.seatNumber || r.student?.seatNumber) ? `<p style="margin: 0 0 5px; color: #000;"><strong>Seat:</strong> ${escapeHTML(r.student?.seat?.seatNumber || r.student?.seatNumber)}</p>` : ''}
                                ${bdy.showShift && (r.student?.shift?.name || r.plan?.shift) ? `<p style="margin: 0 0 5px; color: #000;"><strong>Shift:</strong> ${escapeHTML(r.student?.shift?.name || r.plan?.shift)}</p>` : ''}
                            </div>
                            <div style="flex: 1; min-width: 220px; padding: 10px; border: 1px solid #eee; border-radius: 5px;">
                                <h4 style="margin: 0 0 10px; font-size: 1em; color: #333;">Receipt Details</h4>
                                <p style="margin: 0 0 5px; color: #000;"><strong>Receipt No:</strong> ${escapeHTML(r.receiptNumber)}</p>
                                <p style="margin: 0 0 5px; color: #000;"><strong>Date:</strong> ${formatDate(r.date)}</p>
                                ${bdy.showPaymentMethod ? `<p style="margin: 0 0 5px; color: #000;"><strong>Payment Mode:</strong> ${escapeHTML(r.paymentDetails?.method || 'CASH').toUpperCase()}</p>` : ''}
                                ${bdy.showTransactionId && r.paymentDetails?.transactionId ? `<p style="margin: 0 0 5px; color: #000;"><strong>Ref / Txn ID:</strong> ${escapeHTML(r.paymentDetails.transactionId)}</p>` : ''}
                            </div>
                        </div>
                        
                        <div class="table-responsive">
                            <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px;">
                                <thead>
                                    <tr style="background-color: #f8f9fa;">
                                        <th style="padding: 10px; border: 1px solid #ddd; text-align: left; color: #333;">Description</th>
                                        <th style="padding: 10px; border: 1px solid #ddd; text-align: right; color: #333;">Amount</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td style="padding: 10px; border: 1px solid #ddd; color: #000;">
                                            Fee Collection ${bdy.showPlanDetails && r.plan ? ` - ${escapeHTML(r.plan.name)}` : ''}
                                            ${bdy.showPeriod && (r.billingPeriod?.startDate || r.billingPeriod?.endDate) ? `<br><small style="color: #666;">Period: ${formatDate(r.billingPeriod.startDate)} to ${formatDate(r.billingPeriod.endDate)}</small>` : ''}
                                        </td>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; color: #000;">${formatCurrency(r.paymentDetails.amount)}</td>
                                    </tr>
                                    ${bdy.showDiscount && r.paymentDetails.discount > 0 ? `
                                    <tr>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; color: #000;">Discount</td>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; color: #d32f2f;">- ${formatCurrency(r.paymentDetails.discount)}</td>
                                    </tr>` : ''}
                                    ${bdy.showLateFee && r.paymentDetails.lateFee > 0 ? `
                                    <tr>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; color: #000;">Late Fee</td>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; color: #000;">+ ${formatCurrency(r.paymentDetails.lateFee)}</td>
                                    </tr>` : ''}
                                </tbody>
                                <tfoot>
                                    <tr>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; font-weight: bold; color: #000;">Total Amount</td>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; font-weight: bold; font-size: 1.1em; color: #000;">${formatCurrency(r.paymentDetails.finalAmount)}</td>
                                    </tr>
                                    ${r.balanceDue > 0 || r.installments?.length > 0 ? `
                                    <tr>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; font-weight: bold; color: #000;">Paid Amount</td>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; font-weight: bold; font-size: 1.1em; color: #000;">${formatCurrency(r.paymentDetails.finalAmount - (r.balanceDue || 0))}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; font-weight: bold; color: #d32f2f;">Balance Due</td>
                                        <td style="padding: 10px; border: 1px solid #ddd; text-align: right; font-weight: bold; font-size: 1.1em; color: #d32f2f;">${formatCurrency(r.balanceDue || 0)}</td>
                                    </tr>` : ''}
                                </tfoot>
                            </table>
                        </div>
                        
                        <div style="display: flex; justify-content: space-between; align-items: flex-end; margin-top: 30px;">
                            <div style="flex: 1; font-size: 0.85em; color: #666; padding-right: 15px;">
                                ${ftr.customNote ? `<p style="margin: 0 0 5px; font-weight: 600; color: #333;">${escapeHTML(ftr.customNote)}</p>` : ''}
                                ${ftr.termsText ? `<p style="margin: 0; font-style: italic; color: #777;">${escapeHTML(ftr.termsText)}</p>` : ''}
                                ${ftr.showTimestamp ? `<p style="margin: 5px 0 0; font-size: 0.8em; color: #999;">Generated on: ${new Date().toLocaleString()}</p>` : ''}
                            </div>
                            <div style="text-align: center; min-width: 150px;">
                                <div style="display: flex; justify-content: center; align-items: center; gap: 8px; min-height: 50px;">
                                    ${ftr.showStamp && stampImg ? `<img src="${stampImg}" style="max-height: 55px; opacity: 0.85;">` : ''}
                                    ${ftr.showSignature && sigImg ? `<img src="${sigImg}" style="max-height: 45px;">` : ''}
                                </div>
                                ${ftr.showSignature ? `<div style="border-top: 1px solid #333; padding-top: 5px; font-size: 0.85em; font-weight: bold; color: #000;">${escapeHTML(ftr.signatureLabel || 'Authorized Signatory')}</div>` : ''}
                            </div>
                        </div>
                    `;
                } else if (templateId === 'thermal_80' || templateId === 'thermal_58') {
                    receiptBox.style.maxWidth = templateId === 'thermal_80' ? '302px' : '219px';
                    receiptBox.style.padding = '15px';
                    receiptBox.style.border = '1px solid #ddd';
                    receiptBox.style.fontFamily = 'monospace';
                    
                    html = `
                        <div style="text-align: center; margin-bottom: 10px;">
                            ${head.showLogo && logoImg ? `<img src="${logoImg}" style="max-height: 40px; margin-bottom: 5px;">` : ''}
                            ${head.showBusinessName ? `<h3 style="margin: 0; font-size: 1.2em; color: #000;">${escapeHTML(bp.businessName || r.businessName || 'Library')}</h3>` : ''}
                            <p style="margin: 2px 0; font-size: 0.9em; color: #000;">${escapeHTML(head.subtitle || 'Receipt')}</p>
                            ${head.showPhone && bp.phone ? `<p style="margin: 2px 0; font-size: 0.8em; color: #000;">Ph: ${escapeHTML(bp.phone)}</p>` : ''}
                            ${head.showGst && gstNo ? `<p style="margin: 2px 0; font-size: 0.75em; color: #000;">GST: ${escapeHTML(gstNo)}</p>` : ''}
                        </div>
                        <div style="border-top: 1px dashed #000; border-bottom: 1px dashed #000; padding: 5px 0; margin-bottom: 10px; font-size: 0.85em; color: #000;">
                            <p style="margin: 2px 0;">No: ${escapeHTML(r.receiptNumber)}</p>
                            <p style="margin: 2px 0;">Dt: ${formatDate(r.date)}</p>
                            <p style="margin: 2px 0;">Name: ${escapeHTML(r.student?.name || 'N/A')}</p>
                            ${bdy.showSeatNumber && (r.student?.seat?.seatNumber || r.student?.seatNumber) ? `<p style="margin: 2px 0;">Seat: ${escapeHTML(r.student?.seat?.seatNumber || r.student?.seatNumber)}</p>` : ''}
                        </div>
                        <div class="table-responsive">
                            <table style="width: 100%; font-size: 0.85em; margin-bottom: 10px; color: #000;">
                                <tr><td style="padding-bottom: 5px;">Fee</td><td style="text-align: right; padding-bottom: 5px;">${formatCurrency(r.paymentDetails.amount)}</td></tr>
                                ${bdy.showDiscount && r.paymentDetails.discount > 0 ? `<tr><td style="padding-bottom: 5px;">Disc</td><td style="text-align: right; padding-bottom: 5px;">-${formatCurrency(r.paymentDetails.discount)}</td></tr>` : ''}
                                ${bdy.showLateFee && r.paymentDetails.lateFee > 0 ? `<tr><td style="padding-bottom: 5px;">Late</td><td style="text-align: right; padding-bottom: 5px;">+${formatCurrency(r.paymentDetails.lateFee)}</td></tr>` : ''}
                            </table>
                        </div>
                        <div style="border-top: 1px dashed #000; padding: 5px 0; text-align: right; font-size: 1.1em; font-weight: bold; margin-bottom: 10px; color: #000;">
                            Total: ${formatCurrency(r.paymentDetails.finalAmount)}
                            ${r.balanceDue > 0 || r.installments?.length > 0 ? `<br>Paid: ${formatCurrency(r.paymentDetails.finalAmount - (r.balanceDue || 0))}<br><span style="color:red;">Due: ${formatCurrency(r.balanceDue || 0)}</span>` : ''}
                        </div>
                        <div style="text-align: center; font-size: 0.75em; color: #000;">
                            <p style="margin: 2px 0;">Paid via: ${escapeHTML(r.paymentDetails?.method || 'CASH')}</p>
                            ${ftr.customNote ? `<p style="margin: 5px 0 0;">${escapeHTML(ftr.customNote)}</p>` : ''}
                            ${ftr.termsText ? `<p style="margin: 3px 0 0; font-size: 0.7em;">${escapeHTML(ftr.termsText)}</p>` : ''}
                        </div>
                    `;
                } else if (templateId === 'modern_minimal') {
                    receiptBox.style.maxWidth = '100%';
                    receiptBox.style.padding = '30px';
                    receiptBox.style.border = 'none';
                    receiptBox.style.boxShadow = '0 4px 15px rgba(0,0,0,0.05)';
                    receiptBox.style.borderTop = `5px solid ${head.headerColor || '#4f46e5'}`;
                    receiptBox.style.borderRadius = '12px';
                    receiptBox.style.fontFamily = '"Inter", sans-serif';
                    
                    html = `
                        <div style="display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 30px;">
                            <div>
                                ${head.showLogo && logoImg ? `<img src="${logoImg}" style="max-height: 48px; margin-bottom: 8px;"><br>` : ''}
                                ${head.showBusinessName ? `<h2 style="margin: 0 0 5px; font-weight: 800; color: #111;">${escapeHTML(bp.businessName || r.businessName || 'Library')}</h2>` : ''}
                                <span style="display: inline-block; padding: 4px 10px; background: #f0f0f0; border-radius: 4px; font-size: 0.8em; font-weight: 600; color: #555;">${escapeHTML(head.subtitle || 'RECEIPT')}</span>
                            </div>
                            <div style="text-align: right;">
                                <div style="font-size: 1.5em; font-weight: 800; color: ${head.headerColor || '#4f46e5'};">${formatCurrency(r.paymentDetails.finalAmount)}</div>
                                <div style="font-size: 0.85em; color: #777;">Paid on ${formatDate(r.date)}</div>
                            </div>
                        </div>
                        
                        <div style="display: flex; flex-wrap: wrap; gap: 20px; margin-bottom: 30px; background: #fafafa; padding: 20px; border-radius: 8px;">
                            <div style="flex: 1; min-width: 200px;">
                                <div style="font-size: 0.8em; color: #777; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px;">Billed To</div>
                                <div style="font-weight: 600; color: #222; font-size: 1.1em;">${escapeHTML(r.student?.name || 'N/A')}</div>
                                <div style="color: #555; font-size: 0.9em; margin-top: 3px;">${escapeHTML(r.student?.phone || '')}</div>
                                ${bdy.showSeatNumber && (r.student?.seat?.seatNumber || r.student?.seatNumber) ? `<div style="color: #666; font-size: 0.85em;">Seat: ${escapeHTML(r.student?.seat?.seatNumber || r.student?.seatNumber)}</div>` : ''}
                            </div>
                            <div style="flex: 1; min-width: 200px;">
                                <div style="font-size: 0.8em; color: #777; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 5px;">Payment Info</div>
                                <div style="color: #444; font-size: 0.9em;">
                                    <div style="margin-bottom: 3px;"><strong>Ref:</strong> ${escapeHTML(r.receiptNumber)}</div>
                                    <div style="margin-bottom: 3px;"><strong>Method:</strong> ${escapeHTML(r.paymentDetails?.method || 'CASH').toUpperCase()}</div>
                                    ${bdy.showTransactionId && r.paymentDetails?.transactionId ? `<div><strong>Txn ID:</strong> ${escapeHTML(r.paymentDetails.transactionId)}</div>` : ''}
                                </div>
                            </div>
                        </div>
                        
                        <div style="margin-bottom: 30px;">
                            <div style="display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #eee; font-weight: 600; color: #444;">
                                <div>Description</div>
                                <div>Amount</div>
                            </div>
                            <div style="display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #eee; color: #333;">
                                <div>Fee Collection ${bdy.showPlanDetails && r.plan ? `(${escapeHTML(r.plan.name)})` : ''}</div>
                                <div>${formatCurrency(r.paymentDetails.amount)}</div>
                            </div>
                            ${bdy.showDiscount && r.paymentDetails.discount > 0 ? `
                            <div style="display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #eee; color: #e53935;">
                                <div>Discount Applied</div>
                                <div>-${formatCurrency(r.paymentDetails.discount)}</div>
                            </div>` : ''}
                            ${bdy.showLateFee && r.paymentDetails.lateFee > 0 ? `
                            <div style="display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #eee; color: #333;">
                                <div>Late Fee</div>
                                <div>+${formatCurrency(r.paymentDetails.lateFee)}</div>
                            </div>` : ''}
                            ${r.balanceDue > 0 || r.installments?.length > 0 ? `
                            <div style="display: flex; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #eee; font-weight: bold; color: #333;">
                                <div>Paid Amount</div>
                                <div>${formatCurrency(r.paymentDetails.finalAmount - (r.balanceDue || 0))}</div>
                            </div>
                            <div style="display: flex; justify-content: space-between; padding: 12px 0; font-weight: bold; color: #d32f2f;">
                                <div>Balance Due</div>
                                <div>${formatCurrency(r.balanceDue || 0)}</div>
                            </div>` : ''}
                        </div>
                        
                        <div style="text-align: center; color: #888; font-size: 0.85em; margin-top: 30px;">
                            ${ftr.customNote ? `<div>${escapeHTML(ftr.customNote)}</div>` : ''}
                            ${ftr.termsText ? `<div style="margin-top: 5px; font-size: 0.9em; opacity: 0.8;">${escapeHTML(ftr.termsText)}</div>` : ''}
                            ${ftr.showSignature && (stampImg || sigImg) ? `
                                <div style="display: flex; justify-content: center; gap: 10px; margin-top: 15px;">
                                    ${stampImg ? `<img src="${stampImg}" style="max-height: 45px; opacity: 0.8;">` : ''}
                                    ${sigImg ? `<img src="${sigImg}" style="max-height: 40px;">` : ''}
                                </div>
                            ` : ''}
                        </div>
                    `;
                } else if (templateId === 'gst_invoice') {
                    receiptBox.style.maxWidth = '100%';
                    receiptBox.style.padding = '30px';
                    receiptBox.style.border = '1px solid #ccc';
                    receiptBox.style.fontFamily = 'Arial, sans-serif';
                    
                    const amt = r.paymentDetails.finalAmount;
                    const taxRate = gst.gstRate || 18;
                    const baseAmt = amt / (1 + (taxRate/100));
                    const taxAmt = amt - baseAmt;
                    const cgst = taxAmt / 2;
                    const sgst = taxAmt / 2;
                    
                    html = `
                        <div style="text-align: center; border-bottom: 2px solid #000; padding-bottom: 10px; margin-bottom: 20px;">
                            ${head.showLogo && logoImg ? `<img src="${logoImg}" style="max-height: 50px; margin-bottom: 6px;"><br>` : ''}
                            <h2 style="margin: 0; text-transform: uppercase; color: #000;">TAX INVOICE</h2>
                            <h3 style="margin: 5px 0 0; color: #000;">${escapeHTML(bp.businessName || 'Library')}</h3>
                            <p style="margin: 3px 0 0; font-size: 0.9em; color: #000;">${escapeHTML(bp.address || '')}</p>
                            <p style="margin: 3px 0 0; font-size: 0.9em; color: #000;">GSTIN: ${escapeHTML(gstNo || 'N/A')}</p>
                        </div>
                        
                        <div style="display: flex; justify-content: space-between; margin-bottom: 20px; font-size: 0.9em; color: #000;">
                            <div>
                                <p style="margin: 2px 0;"><strong>Invoice No:</strong> ${escapeHTML(r.receiptNumber)}</p>
                                <p style="margin: 2px 0;"><strong>Date:</strong> ${formatDate(r.date)}</p>
                                <p style="margin: 2px 0;"><strong>Place of Supply:</strong> ${escapeHTML(gst.placeOfSupply || bp.state || '')}</p>
                            </div>
                            <div style="text-align: right;">
                                <p style="margin: 2px 0;"><strong>Billed To:</strong> ${escapeHTML(r.student?.name || '')}</p>
                                <p style="margin: 2px 0;"><strong>Phone:</strong> ${escapeHTML(r.student?.phone || '')}</p>
                                ${bdy.showStudentId ? `<p style="margin: 2px 0;"><strong>Student ID:</strong> ${escapeHTML(r.student?.studentId || '')}</p>` : ''}
                            </div>
                        </div>
                        
                        <div class="table-responsive">
                            <table style="width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 0.9em; color: #000;">
                                <thead>
                                    <tr>
                                        <th style="border: 1px solid #000; padding: 5px; text-align: left;">Description of Services</th>
                                        <th style="border: 1px solid #000; padding: 5px; text-align: center;">HSN/SAC</th>
                                        <th style="border: 1px solid #000; padding: 5px; text-align: right;">Taxable Value</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr>
                                        <td style="border: 1px solid #000; padding: 10px 5px;">Library Membership Services ${r.plan ? `(${escapeHTML(r.plan.name)})` : ''}</td>
                                        <td style="border: 1px solid #000; padding: 10px 5px; text-align: center;">${escapeHTML(gst.hsnCode || '9992')}</td>
                                        <td style="border: 1px solid #000; padding: 10px 5px; text-align: right;">${formatCurrency(baseAmt)}</td>
                                    </tr>
                                </tbody>
                            </table>
                        </div>
                        
                        <div style="display: flex; justify-content: flex-end; margin-bottom: 30px; font-size: 0.9em; color: #000;">
                            <div class="table-responsive" style="width: 50%;">
                                <table style="width: 100%; border-collapse: collapse;">
                                    <tr>
                                        <td style="padding: 3px 5px; text-align: right;">Total Taxable Value:</td>
                                        <td style="padding: 3px 5px; text-align: right; border-bottom: 1px solid #000;">${formatCurrency(baseAmt)}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 3px 5px; text-align: right;">CGST @ ${taxRate/2}%:</td>
                                        <td style="padding: 3px 5px; text-align: right;">${formatCurrency(cgst)}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 3px 5px; text-align: right;">SGST @ ${taxRate/2}%:</td>
                                        <td style="padding: 3px 5px; text-align: right; border-bottom: 1px solid #000;">${formatCurrency(sgst)}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 5px; text-align: right; font-weight: bold;">Grand Total:</td>
                                        <td style="padding: 5px; text-align: right; font-weight: bold; border-bottom: 2px solid #000;">${formatCurrency(amt)}</td>
                                    </tr>
                                    ${r.balanceDue > 0 || r.installments?.length > 0 ? `
                                    <tr>
                                        <td style="padding: 5px; text-align: right; font-weight: bold;">Paid Amount:</td>
                                        <td style="padding: 5px; text-align: right; font-weight: bold;">${formatCurrency(amt - (r.balanceDue || 0))}</td>
                                    </tr>
                                    <tr>
                                        <td style="padding: 5px; text-align: right; font-weight: bold; color: #d32f2f;">Balance Due:</td>
                                        <td style="padding: 5px; text-align: right; font-weight: bold; color: #d32f2f; border-bottom: 2px solid #000;">${formatCurrency(r.balanceDue || 0)}</td>
                                    </tr>` : ''}
                                </table>
                            </div>
                        </div>
                        
                        <div style="display: flex; justify-content: space-between; align-items: flex-end; font-size: 0.85em; color: #000;">
                            <div>
                                <p style="margin: 0; font-style: italic;">${escapeHTML(ftr.termsText || 'Computer generated invoice, no physical signature required.')}</p>
                                ${ftr.customNote ? `<p style="margin: 4px 0 0;">${escapeHTML(ftr.customNote)}</p>` : ''}
                            </div>
                            <div style="text-align: center; border-top: 1px solid #000; padding-top: 5px; min-width: 140px;">
                                ${stampImg ? `<img src="${stampImg}" style="max-height: 40px; margin-bottom: 4px;"><br>` : ''}
                                For ${escapeHTML(bp.businessName || 'Library')}<br>
                                ${escapeHTML(ftr.signatureLabel || 'Authorized Signatory')}
                            </div>
                        </div>
                    `;
                }
                
                receiptBox.innerHTML = html;
            };

            Modal.show({
                title: 'Fee Payment Receipt',
                content: receiptDiv,
                size: 'md'
            });

            // Initial render
            renderTemplate(activeTemplate);

            // Handle Format/Template Switcher
            const formatSelect = receiptDiv.querySelector('#receipt-paper-format');
            formatSelect?.addEventListener('change', () => {
                const fmt = formatSelect.value;
                if (fmt === 'standard') renderTemplate('standard_a4');
                else if (fmt === 'thermal-80') renderTemplate('thermal_80');
                else if (fmt === 'thermal-58') renderTemplate('thermal_58');
                
                // Update active button
                const templateBtns = receiptDiv.querySelectorAll('[data-template]');
                templateBtns.forEach(b => b.classList.remove('active', 'btn-primary'));
                templateBtns.forEach(b => b.classList.add('btn-outline-primary'));
                
                let tgtBtn = null;
                if (fmt === 'standard') tgtBtn = receiptDiv.querySelector('[data-template="standard_a4"]');
                else if (fmt === 'thermal-80') tgtBtn = receiptDiv.querySelector('[data-template="thermal_80"]');
                else if (fmt === 'thermal-58') tgtBtn = receiptDiv.querySelector('[data-template="thermal_58"]');
                
                if (tgtBtn) {
                    tgtBtn.classList.remove('btn-outline-primary');
                    tgtBtn.classList.add('active', 'btn-primary');
                }
            });

            const templateBtns = receiptDiv.querySelectorAll('[data-template]');
            templateBtns.forEach(btn => {
                btn.addEventListener('click', (e) => {
                    templateBtns.forEach(b => b.classList.remove('active', 'btn-primary'));
                    templateBtns.forEach(b => b.classList.add('btn-outline-primary'));
                    e.target.classList.remove('btn-outline-primary');
                    e.target.classList.add('active', 'btn-primary');
                    
                    const tpl = e.target.dataset.template;
                    renderTemplate(tpl);
                    
                    if (tpl === 'thermal_80') formatSelect.value = 'thermal-80';
                    else if (tpl === 'thermal_58') formatSelect.value = 'thermal-58';
                    else formatSelect.value = 'standard';
                });
            });

            // Set initial active button
            const activeBtn = receiptDiv.querySelector(`[data-template="${activeTemplate}"]`) || receiptDiv.querySelector('[data-template="standard_a4"]');
            if (activeBtn) {
                activeBtn.classList.remove('btn-outline-primary');
                activeBtn.classList.add('active', 'btn-primary');
            }

            // Handle Print Button
            receiptDiv.querySelector('#btn-print-receipt-action')?.addEventListener('click', () => {
                window.print();
            });

            receiptDiv.querySelector('#btn-share-whatsapp-receipt')?.addEventListener('click', async () => {
                try {
                    const waRes = await api.post('/api/notifications/receipt-whatsapp-link', { paymentId });
                    if (waRes.success && waRes.data?.url) {
                        window.open(waRes.data.url, '_blank');
                        Toast.success('Opening WhatsApp with formatted receipt...');
                    } else {
                        Toast.error('Could not generate WhatsApp link');
                    }
                } catch (e) {
                    Toast.error('Could not generate WhatsApp link');
                }
            });
            
        } catch (err) {
            console.error('Error fetching receipt', err);
            Toast.error('An error occurred while loading receipt');
        }
    }

    return container;
}
