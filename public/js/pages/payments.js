import { App } from '../app.js';
import { t } from '../i18n.js';
import { Toast, Modal, Loading, Confirm, escapeHTML, debounce, copyToClipboard, UI } from '../ui.js';
import { SmartFormatters } from '../utils/smartFormatters.js';
import api from '../api.js';
import { IDBStorage } from '../utils/idbStorage.js';
import { OptimisticUI } from '../utils/optimisticUI.js';
import { buildReceiptHTML, printReceiptDocument } from '../pdfGenerator.js';
import { PaymentStudio } from '../paymentStudio.js';

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
            <div class="module-actions d-flex gap-2 align-items-center flex-wrap">
                <button class="btn btn-outline-secondary d-flex align-items-center gap-2" id="btnCashRegister" style="font-weight: 700;">
                    <span>💵</span> Cash Register Handover
                </button>
                <button class="btn btn-primary d-flex align-items-center gap-2" id="btnCollectPayment" style="font-weight: 700;">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                    Collect Fee Payment
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
        
        <!-- ── Phase 5: Payments Bulk Operations Bar ─────────────────── -->
        <div id="payments-bulk-bar" style="
          display: none; position: sticky; top: 64px; z-index: 98;
          margin-bottom: 1rem;
          background: linear-gradient(135deg, #1e293b, var(--color-text-primary));
          color: #fff; padding: 10px 16px; border-radius: 12px;
          box-shadow: 0 4px 24px rgba(0,0,0,0.4);
          align-items: center; justify-content: space-between; flex-wrap: wrap; gap: 8px;
          border: 1px solid rgba(108,92,231,0.35);
          animation: bulkBarSlideIn 0.2s ease;
        ">
          <div style="display: flex; align-items: center; gap: 10px;">
            <span id="payments-bulk-count" style="
              background: rgba(108,92,231,0.25); color: #a29bfe;
              font-weight: 700; font-size: 0.85rem; padding: 4px 10px;
              border-radius: 20px; border: 1px solid rgba(108,92,231,0.4);
            ">0 Selected</span>
            <span style="font-size: 0.8rem; opacity: 0.7;">Actions on selected payments:</span>
          </div>
          <div style="display: flex; gap: 8px; flex-wrap: wrap; align-items: center;">
            <button type="button" id="payments-bulk-mark-paid" class="btn btn-sm btn-outline-success" style="font-weight: 600; border-radius: 8px;">
              ✅ Mark Paid
            </button>
            <button type="button" id="payments-bulk-mark-pending" class="btn btn-sm btn-outline-warning" style="font-weight: 600; border-radius: 8px;">
              ⏳ Mark Pending
            </button>
            <button type="button" id="payments-bulk-wa-remind" class="btn btn-sm" style="font-weight: 600; border-radius: 8px; background: #25D366; color: #fff; border: none;">
              📲 WA Reminders
            </button>
            <button type="button" id="payments-bulk-export-csv" class="btn btn-sm btn-outline-info" style="font-weight: 600; border-radius: 8px;">
              📥 Export Selected
            </button>
            <button type="button" id="payments-bulk-delete" class="btn btn-sm btn-danger" style="font-weight: 600; border-radius: 8px;">
              🗑️ Delete
            </button>
            <button type="button" id="payments-bulk-cancel" class="btn btn-sm" style="font-weight: 600; border-radius: 8px; background: rgba(255,255,255,0.08); color: #94a3b8; border: 1px solid rgba(255,255,255,0.12);">
              ✕ Cancel
            </button>
          </div>
        </div>

        <!-- Recent Payments Table Card -->
        <div class="card mb-4">
            <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-3">
                <div style="display: flex; align-items: center; gap: 10px;">
                  <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700;">Recent Fee Payments</h3>
                  <button type="button" id="payments-toggle-select-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.75rem; padding: 3px 10px; border-radius: 12px; font-weight: 600;" title="Toggle select all rows">
                    ☑️ Select All
                  </button>
                </div>
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
                        <option value="pending_verification">⏳ Pending UTR Verification</option>
                        <option value="paid">🟢 Paid</option>
                        <option value="pending">🟡 Pending</option>
                        <option value="partial">🟠 Partial</option>
                        <option value="refunded">🔴 Refunded</option>
                    </select>
                    <button id="btnFilterPendingVerification" class="btn btn-sm w-100 w-md-auto" style="font-weight: 700; border: 1.5px solid #f39c12; color: #b78103; background: rgba(243, 156, 18, 0.12);">⚡ Verification Queue</button>
                    <button id="btnPendingInstallments" class="btn btn-sm btn-outline-warning w-100 w-md-auto" style="font-weight: 600;">⏳ Balances</button>
                    <button id="btnExportPaymentsCSV" class="btn btn-sm btn-outline-success w-100 w-md-auto" style="font-weight: 600;">📥 Export CSV</button>
                </div>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table data-table mb-0">
                        <thead>
                            <tr>
                                <th style="width: 36px; padding: 8px 10px;">
                                  <input type="checkbox" id="payments-check-all" title="Select all" style="cursor: pointer; width: 16px; height: 16px;">
                                </th>
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
                            <tr><td colspan="8" class="text-center p-4">Loading payments...</td></tr>
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
        
        const btnVerificationQueue = container.querySelector('#btnFilterPendingVerification');
        if (btnVerificationQueue) btnVerificationQueue.addEventListener('click', () => {
            if (statusSelect) statusSelect.value = 'pending_verification';
            loadPayments();
            Toast.info('Showing online payments awaiting UTR verification');
        });

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

    async function verifyPaymentUtr(paymentId, utrNumber, receiptNumber) {
        const ok = await Confirm.show({
            title: 'Verify UPI Payment',
            message: `Confirm that UTR / Reference "${utrNumber || 'N/A'}" (Invoice ${receiptNumber || paymentId}) matches your bank statement and mark as Paid?`,
            confirmText: '✅ Yes, Verify & Activate Student',
            cancelText: 'Cancel'
        });
        if (!ok) return;

        try {
            const res = await api.put(`/api/payments/${paymentId}/verify-utr`);
            if (res.success) {
                Toast.success(res.message || 'Payment verified successfully!');
                await IDBStorage.clear('payments');
                loadPayments();
                loadStats();
            } else {
                Toast.error(res.message || 'Failed to verify payment');
            }
        } catch (err) {
            Toast.error(err.message || 'Verification failed');
        }
    }

    async function rejectPaymentUtr(paymentId, receiptNumber) {
        const reason = prompt(`Enter rejection reason for payment ${receiptNumber || ''}:`, 'UTR not found in bank statement / Invalid amount');
        if (!reason || !reason.trim()) return;

        try {
            const res = await api.put(`/api/payments/${paymentId}/reject-utr`, { reason: reason.trim() });
            if (res.success) {
                Toast.warning(res.message || 'Payment marked as rejected');
                await IDBStorage.clear('payments');
                loadPayments();
                loadStats();
            } else {
                Toast.error(res.message || 'Failed to reject payment');
            }
        } catch (err) {
            Toast.error(err.message || 'Rejection failed');
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
            <tr class="payment-row" data-id="${p._id}" data-status="${p.status}" data-amount="${p.finalAmount}" data-student-name="${escapeHTML(p.student?.name || '')}" data-student-phone="${escapeHTML(p.student?.phone || '')}" data-receipt="${escapeHTML(p.receiptNumber || '')}">
                <td style="width: 36px; padding: 8px 10px; text-align: center;">
                  <input type="checkbox" class="payment-row-check" data-id="${p._id}" style="cursor: pointer; width: 16px; height: 16px; accent-color: #6c5ce7;">
                </td>
                <td>
                    <a href="#" class="receipt-link" data-id="${p._id}" style="font-family: monospace; font-weight: 700; color: var(--color-primary, #6c5ce7);">${escapeHTML(p.receiptNumber || 'N/A')}</a>
                    <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(p.receiptNumber || '')}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Receipt Number">📋</button>
                </td>
                <td>
                    <div style="font-weight: 600;">${escapeHTML(p.student?.name || p.studentName || (p.notes && !p.notes.startsWith('{') ? p.notes : 'Registered Student'))}</div>
                    <small class="text-muted">${escapeHTML(SmartFormatters.phone(p.student?.phone) || '')}</small>
                    ${p.student?.phone ? `<button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${escapeHTML(p.student.phone)}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">📋</button>` : ''}
                </td>
                <td><strong style="font-size: 1.05rem;">${formatCurrency(p.finalAmount)}</strong></td>
                <td><span class="badge" style="background: rgba(255,255,255,0.08); padding: 4px 8px; border-radius: 4px; text-transform: uppercase;">${escapeHTML(p.paymentMethod)}</span></td>
                <td>${formatDate(p.paymentDate)} <small class="text-muted">(${SmartFormatters.timeAgo(p.paymentDate)})</small></td>
                <td>
                    ${p.status === 'paid' ? `
                        <span class="badge" style="background: rgba(0, 184, 148, 0.18); color: var(--color-success); padding: 4px 8px; border-radius: 4px; font-weight: 700;">✅ Paid</span>
                    ` : p.status === 'pending_verification' ? `
                        <span class="badge" style="background: rgba(255, 179, 0, 0.2); color: #e67e22; padding: 4px 8px; border-radius: 4px; font-weight: 700; border: 1px solid #f39c12;" title="Submitted UTR: ${escapeHTML(p.transactionId || 'N/A')}">⏳ Pending Verification</span>
                    ` : p.status === 'partial' || p.status === 'partially_paid' ? `
                        <span class="badge" style="background: rgba(9, 132, 227, 0.18); color: #0984e3; padding: 4px 8px; border-radius: 4px; font-weight: 700;">💳 Due: ₹${p.balanceDue || 0}</span>
                    ` : p.status === 'failed' ? `
                        <span class="badge" style="background: rgba(214, 48, 49, 0.18); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 700;">❌ Rejected</span>
                    ` : `
                        <span class="badge" style="background: rgba(214, 48, 49, 0.18); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 700;">⚠️ Pending Fee</span>
                    `}
                </td>
                <td>
                    <div class="btn-icon-group">
                        ${p.status === 'pending_verification' ? `
                            <button type="button" class="btn-icon-action action-verify btn-verify-utr" data-id="${p._id}" data-utr="${escapeHTML(p.transactionId || '')}" data-receipt="${escapeHTML(p.receiptNumber || '')}" data-tooltip="Verify UTR (1-Click)" aria-label="Verify UTR">✅</button>
                            <button type="button" class="btn-icon-action action-reject btn-reject-utr" data-id="${p._id}" data-receipt="${escapeHTML(p.receiptNumber || '')}" data-tooltip="Reject UTR" aria-label="Reject UTR">❌</button>
                        ` : ''}
                        <button type="button" class="btn-icon-action action-receipt btn-view" data-id="${p._id}" data-tooltip="View Receipt" aria-label="View Receipt">🧾</button>
                        <button type="button" class="btn-icon-action action-whatsapp btn-wa-bill" data-id="${p._id}" data-tooltip="WhatsApp Bill" aria-label="WhatsApp Bill">💬</button>
                        ${p.status === 'partial' && p.balanceDue > 0 ? `
                            <button type="button" class="btn-icon-action action-verify btn-pay-balance" data-id="${p._id}" data-balance="${p.balanceDue}" data-tooltip="Pay Due ₹${p.balanceDue}" aria-label="Pay Balance">💰</button>
                        ` : ''}
                        ${typeof ActionMenu !== 'undefined' ? ActionMenu.renderHtml([
                            { header: 'Level 1: Verification & Receipts' },
                            { id: 'view-receipt', icon: '🧾', label: 'View / Print POS Receipt', bold: true },
                            { id: 'wa-receipt', icon: '📲', label: 'WhatsApp Receipt Alert' },
                            ...(p.status === 'pending_verification' ? [
                                { id: 'quick-verify', icon: '✅', label: 'Approve & Verify UTR', bold: true },
                                { id: 'quick-reject', icon: '❌', label: 'Reject UTR Submission', danger: true }
                            ] : []),
                            { divider: true },
                            { header: 'Level 2: Financial Governance' },
                            { id: 'toggle-status', icon: p.status === 'paid' ? '⏳' : '✅', label: p.status === 'paid' ? 'Mark as Pending' : 'Mark as Paid' },
                            { divider: true },
                            { header: 'Level 3: Danger Zone' },
                            { id: 'delete', icon: '🗑️', label: 'Delete Payment Record', danger: true }
                        ], p._id) : ''}
                    </div>
                </td>
            </tr>
        `).join('');

        // ActionMenu click handling on tbody
        tbody.querySelectorAll('.action-menu-item').forEach(item => {
            item.addEventListener('click', async (e) => {
                e.preventDefault();
                e.stopPropagation();
                const act = item.dataset.action;
                const id = item.dataset.id;
                const payment = payments.find(p => p._id === id);
                if (!payment) return;

                if (act === 'view-receipt') {
                    showReceiptModal(id);
                } else if (act === 'wa-receipt') {
                    const phone = (payment.student?.phone || payment.phone || '').replace(/\D/g, '');
                    if (!phone) {
                        Toast.error('No student phone number linked');
                        return;
                    }
                    const cleanPhone = phone.length === 10 ? '91' + phone : phone;
                    const text = `Dear ${payment.student?.name || 'Student'}, your payment of ₹${payment.finalAmount || payment.amount} (Receipt: ${payment.receiptNumber || 'N/A'}) has been successfully received. Thank you!`;
                    window.open(`https://wa.me/${cleanPhone}?text=${encodeURIComponent(text)}`, '_blank');
                } else if (act === 'quick-verify') {
                    await verifyPaymentUtr(id, payment.transactionId, payment.receiptNumber);
                } else if (act === 'quick-reject') {
                    await rejectPaymentUtr(id, payment.receiptNumber);
                } else if (act === 'delete') {
                    const ok = await Confirm.show({
                        title: 'Delete Payment Record',
                        message: `Permanently delete invoice ${payment.receiptNumber || id}?`,
                        danger: true
                    });
                    if (ok) {
                        try {
                            await api.delete(`/api/payments/${id}`);
                            Toast.success('Payment record deleted');
                            await IDBStorage.clear('payments');
                            loadPayments();
                            loadStats();
                        } catch (err) {
                            Toast.error(err.message || 'Delete failed');
                        }
                    }
                } else if (act === 'toggle-status') {
                    const newStatus = payment.status === 'paid' ? 'pending' : 'paid';
                    try {
                        await api.put(`/api/payments/${id}`, { status: newStatus });
                        Toast.success(`Payment marked as ${newStatus}`);
                        await IDBStorage.clear('payments');
                        loadPayments();
                        loadStats();
                    } catch (err) {
                        Toast.error(err.message || 'Status update failed');
                    }
                }
            });
        });

        // 1-Click UTR Verification Quick Buttons
        tbody.querySelectorAll('.btn-verify-utr').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.preventDefault();
                e.stopPropagation();
                const id = btn.dataset.id;
                const utr = btn.dataset.utr;
                const receipt = btn.dataset.receipt;
                await verifyPaymentUtr(id, utr, receipt);
            });
        });

        tbody.querySelectorAll('.btn-reject-utr').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.preventDefault();
                e.stopPropagation();
                const id = btn.dataset.id;
                const receipt = btn.dataset.receipt;
                await rejectPaymentUtr(id, receipt);
            });
        });

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

        tbody.querySelectorAll('.btn-wa-bill').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                const payment = payments.find(p => p._id === btn.dataset.id);
                if (!payment) return;
                const phone = (payment.student?.phone || payment.phone || '').replace(/\D/g, '');
                if (!phone) {
                    Toast.error('No student phone number linked');
                    return;
                }
                const cleanPhone = phone.length === 10 ? '91' + phone : phone;
                const text = `Dear ${payment.student?.name || 'Student'}, your payment of ₹${payment.finalAmount || payment.amount} (Receipt: ${payment.receiptNumber || 'N/A'}) has been recorded. Thank you!`;
                window.open(`https://wa.me/${cleanPhone}?text=${encodeURIComponent(text)}`, '_blank');
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
                    Loading.show('Preparing WhatsApp balance reminder & UPI link...');
                    const res = await api.post('/api/messages/send-reminder', {
                        studentId,
                        paymentId,
                        reminderType: 'balance_due'
                    });
                    Loading.hide();
                    if (res.success && res.data) {
                        const targetUrl = res.data.whatsappUrl || res.data.waUrl;
                        if (targetUrl) {
                            const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
                            if (isMobile) {
                                window.location.href = targetUrl;
                            } else {
                                const w = window.open(targetUrl, '_blank');
                                if (!w) window.location.href = targetUrl;
                            }
                        }
                        Toast.success(`WhatsApp reminder opened for ${studentName}!`);
                    } else {
                        Toast.error(res.message || 'Failed to send WhatsApp reminder');
                    }
                } catch (err) {
                    Loading.hide();
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
                            const targetUrl = res.data.whatsappUrl || res.data.waUrl;
                            if (targetUrl) {
                                const isMobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent);
                                if (isMobile) {
                                    window.location.href = targetUrl;
                                } else {
                                    const w = window.open(targetUrl, '_blank');
                                    if (!w) window.location.href = targetUrl;
                                }
                            }
                            Toast.success(`WhatsApp reminder opened for ${studentName || res.data.studentName}!`);
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

    async function showCashRegisterModal() {
        try {
            Loading.show('Calculating daily cash register summary...');
            const res = await api.get('/api/payments/cash-register/summary');
            Loading.hide();

            if (!res.success) {
                Toast.error(res.message || 'Failed to fetch cash register summary');
                return;
            }

            const data = res.data || {};
            const opening = data.openingCash || 0;
            const collected = data.totalCashCollected || 0;
            const expenses = data.totalCashExpenses || 0;
            const expected = data.expectedClosingCash || 0;

            const modalContent = `
                <div style="padding: 6px 0;">
                    <!-- Financial Overview Cards -->
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; margin-bottom: 14px;">
                        <div class="p-2 border rounded text-center" style="background: var(--color-bg-secondary);">
                            <small class="text-muted d-block" style="font-size: 0.75rem; font-weight: 700;">📦 Opening Cash</small>
                            <strong style="font-size: 1.1rem; color: var(--color-text-primary);">₹${opening}</strong>
                        </div>
                        <div class="p-2 border rounded text-center" style="background: rgba(0, 184, 148, 0.08); border-color: rgba(0, 184, 148, 0.2) !important;">
                            <small class="text-success d-block" style="font-size: 0.75rem; font-weight: 700;">📥 Today's Cash Fees</small>
                            <strong style="font-size: 1.1rem; color: var(--color-success);">+₹${collected}</strong>
                            <small class="text-muted d-block" style="font-size: 0.7rem;">(${data.cashTransactionsCount || 0} collections)</small>
                        </div>
                        <div class="p-2 border rounded text-center" style="background: rgba(214, 48, 49, 0.08); border-color: rgba(214, 48, 49, 0.2) !important;">
                            <small class="text-danger d-block" style="font-size: 0.75rem; font-weight: 700;">📤 Cash Expenses</small>
                            <strong style="font-size: 1.1rem; color: var(--color-danger);">-₹${expenses}</strong>
                        </div>
                    </div>

                    <!-- Expected Closing Cash Banner -->
                    <div style="background: linear-gradient(135deg, rgba(108,92,231,0.12), rgba(0,184,148,0.12)); border: 1.5px solid var(--color-primary); border-radius: 8px; padding: 12px 16px; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <span style="font-weight: 800; font-size: 0.95rem; color: var(--color-primary);">Expected Cash in Drawer:</span>
                            <small class="text-muted d-block" style="font-size: 0.75rem;">(Opening ₹${opening} + Cash In ₹${collected} - Cash Out ₹${expenses})</small>
                        </div>
                        <span style="font-size: 1.4rem; font-weight: 800; color: var(--color-primary);" id="cr-expected-amount">₹${expected}</span>
                    </div>

                    <!-- Denominations Calculator -->
                    <div class="mb-3">
                        <label class="form-label" style="font-weight: 700; font-size: 0.85rem; display: flex; justify-content: space-between;">
                            <span>🧮 Physical Cash Count & Denominations</span>
                            <span class="text-muted" style="font-size: 0.75rem;">Enter note quantities</span>
                        </label>
                        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px;">
                            ${[
                                { val: 500, id: 'cr-d500' },
                                { val: 200, id: 'cr-d200' },
                                { val: 100, id: 'cr-d100' },
                                { val: 50,  id: 'cr-d50'  },
                                { val: 20,  id: 'cr-d20'  },
                                { val: 10,  id: 'cr-d10'  }
                            ].map(d => `
                                <div class="input-group input-group-sm">
                                    <span class="input-group-text font-monospace" style="width: 70px; font-weight: 700;">₹${d.val} ×</span>
                                    <input type="number" min="0" class="form-control cr-denom-input text-center" id="${d.id}" data-val="${d.val}" placeholder="0">
                                </div>
                            `).join('')}
                        </div>
                        <div class="input-group input-group-sm mt-2">
                            <span class="input-group-text font-monospace" style="width: 140px; font-weight: 700;">🪙 Coins / Loose (₹)</span>
                            <input type="number" min="0" class="form-control cr-denom-input" id="cr-coins" data-val="1" placeholder="0">
                        </div>
                    </div>

                    <!-- Counted Total vs Variance Result -->
                    <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; margin-bottom: 14px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                            <span style="font-weight: 700; font-size: 0.9rem;">Total Physical Cash Counted:</span>
                            <strong style="font-size: 1.15rem;" id="cr-total-counted">₹0</strong>
                        </div>
                        <div style="display: flex; justify-content: space-between; align-items: center; padding-top: 6px; border-top: 1px dashed var(--color-border);">
                            <span style="font-weight: 700; font-size: 0.85rem;">Day-End Settlement Variance:</span>
                            <span class="badge" id="cr-variance-badge" style="font-size: 0.85rem; font-weight: 800; background: rgba(0,0,0,0.1);">Enter Count</span>
                        </div>
                    </div>

                    <!-- Handover Recipient & Notes -->
                    <div class="row g-2 mb-3">
                        <div class="col-6">
                            <label class="form-label small" style="font-weight: 700;">Handover To / Recipient</label>
                            <input type="text" id="cr-handover-to" class="form-control form-control-sm" placeholder="e.g. Evening Shift / Bank Deposit" value="Next Shift / Owner Handover">
                        </div>
                        <div class="col-6">
                            <label class="form-label small" style="font-weight: 700;">Settlement Notes</label>
                            <input type="text" id="cr-notes" class="form-control form-control-sm" placeholder="Optional notes / discrepancy reasons">
                        </div>
                    </div>
                </div>
            `;

            Modal.show({
                title: '💵 Daily Cash Register Handover & Day-End Settlement',
                content: modalContent,
                confirmText: '✅ Settle & Close Shift Register',
                onConfirm: async () => {
                    const d500 = Number(document.getElementById('cr-d500')?.value) || 0;
                    const d200 = Number(document.getElementById('cr-d200')?.value) || 0;
                    const d100 = Number(document.getElementById('cr-d100')?.value) || 0;
                    const d50  = Number(document.getElementById('cr-d50')?.value)  || 0;
                    const d20  = Number(document.getElementById('cr-d20')?.value)  || 0;
                    const d10  = Number(document.getElementById('cr-d10')?.value)  || 0;
                    const coins= Number(document.getElementById('cr-coins')?.value)|| 0;

                    const actualPhysicalCash = (d500 * 500) + (d200 * 200) + (d100 * 100) + (d50 * 50) + (d20 * 20) + (d10 * 10) + coins;
                    const handoverTo = document.getElementById('cr-handover-to')?.value?.trim();
                    const notes = document.getElementById('cr-notes')?.value?.trim();

                    try {
                        Loading.show('Saving shift handover settlement...');
                        const settleRes = await api.post('/api/payments/cash-register/settle', {
                            openingCash: opening,
                            cashCollected: collected,
                            cashExpenses: expenses,
                            expectedClosingCash: expected,
                            actualPhysicalCash,
                            denominations: { d500, d200, d100, d50, d20, d10, coins },
                            handoverTo,
                            notes
                        });
                        Loading.hide();

                        if (settleRes.success) {
                            Toast.success(settleRes.message || 'Cash register settled successfully');
                            Modal.close();
                            loadStats();
                        } else {
                            Toast.error(settleRes.message || 'Settlement failed');
                        }
                    } catch (e) {
                        Loading.hide();
                        Toast.error(e.message || 'Error settling cash register');
                    }
                }
            });

            // Attach real-time math listeners to denomination inputs
            const updateMath = () => {
                const d500 = Number(document.getElementById('cr-d500')?.value) || 0;
                const d200 = Number(document.getElementById('cr-d200')?.value) || 0;
                const d100 = Number(document.getElementById('cr-d100')?.value) || 0;
                const d50  = Number(document.getElementById('cr-d50')?.value)  || 0;
                const d20  = Number(document.getElementById('cr-d20')?.value)  || 0;
                const d10  = Number(document.getElementById('cr-d10')?.value)  || 0;
                const coins= Number(document.getElementById('cr-coins')?.value)|| 0;

                const total = (d500 * 500) + (d200 * 200) + (d100 * 100) + (d50 * 50) + (d20 * 20) + (d10 * 10) + coins;
                const diff = total - expected;

                const countedEl = document.getElementById('cr-total-counted');
                if (countedEl) countedEl.textContent = `₹${total}`;

                const badge = document.getElementById('cr-variance-badge');
                if (badge) {
                    if (total === 0) {
                        badge.textContent = 'Enter Count';
                        badge.style.background = 'rgba(255,255,255,0.08)';
                        badge.style.color = 'var(--color-text-secondary)';
                    } else if (diff === 0) {
                        badge.textContent = '✅ Reconciled (₹0 Variance)';
                        badge.style.background = 'rgba(0,184,148,0.2)';
                        badge.style.color = 'var(--color-success)';
                    } else if (diff > 0) {
                        badge.textContent = `✨ Surplus (+₹${diff})`;
                        badge.style.background = 'rgba(59,130,246,0.2)';
                        badge.style.color = 'var(--color-primary)';
                    } else {
                        badge.textContent = `⚠️ Deficit / Short (-₹${Math.abs(diff)})`;
                        badge.style.background = 'rgba(214,48,49,0.2)';
                        badge.style.color = 'var(--color-danger)';
                    }
                }
            };

            document.querySelectorAll('.cr-denom-input').forEach(inp => {
                inp.addEventListener('input', updateMath);
            });

        } catch (err) {
            Loading.hide();
            Toast.error(err.message || 'Error opening cash register handover');
        }
    }

    let _cachedPaymentModalDeps = null;
    async function fetchPaymentModalDeps() {
        if (_cachedPaymentModalDeps) {
            Promise.all([
                api.get('/api/plans').catch(() => null),
                api.get('/api/students?limit=100&status=active').catch(() => null)
            ]).then(([pRes, sRes]) => {
                if (pRes?.data) _cachedPaymentModalDeps.plans = pRes.data;
                if (sRes?.data?.students) _cachedPaymentModalDeps.students = sRes.data.students;
            }).catch(() => {});
            return _cachedPaymentModalDeps;
        }

        try {
            const [plansRes, studentsRes] = await Promise.all([
                api.get('/api/plans').catch(() => ({ data: [] })),
                api.get('/api/students?limit=100&status=active').catch(() => ({ data: { students: [] } }))
            ]);
            _cachedPaymentModalDeps = {
                plans: plansRes?.data || [],
                students: studentsRes?.data?.students || []
            };
            return _cachedPaymentModalDeps;
        } catch (_) {
            return { plans: [], students: [] };
        }
    }

    async function showCollectModal(studentId = null) {
        const deps = await fetchPaymentModalDeps();
        const plansList = Array.isArray(deps.plans) ? deps.plans : [];
        const studentsList = Array.isArray(deps.students) ? deps.students : [];

        let plansOptions = '<option value="">-- Select Plan --</option>';
        plansList.forEach(p => {
            plansOptions += `<option value="${p._id}" data-price="${p.price}">${escapeHTML(p.name)} - ₹${p.price} (${p.duration} ${p.durationType})</option>`;
        });

        let studentsOptions = '<option value="">-- Select Student --</option>';
        let preloadedStudent = null;
        studentsList.forEach(s => {
            const isSelected = studentId && s._id === studentId;
            if (isSelected) preloadedStudent = s;
            studentsOptions += `<option value="${s._id}" ${isSelected ? 'selected' : ''}>${escapeHTML(s.name)} (${escapeHTML(s.studentId || '')} - ${escapeHTML(s.phone || '')})</option>`;
        });

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
                        <select name="paymentMethod" id="payMethodSelect" class="form-select form-control" required>
                            <option value="cash">💵 Cash at Reception Desk</option>
                            <option value="upi" selected>⚡ UPI (GPay / PhonePe / Paytm / BHIM)</option>
                            <option value="bank_transfer">🏛️ Bank Transfer (NEFT / IMPS / RTGS)</option>
                            <option value="card">💳 Debit / Credit Card (POS Terminal)</option>
                        </select>
                    </div>

                    <div class="col-12" id="payMethodContext"></div>
                    
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
                    
                    <div class="col-md-6" id="payTxnWrapper">
                        <label class="form-label" id="payTxnLabel" style="font-weight: 500;">⚡ UPI / 12-Digit UTR Transaction ID</label>
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
        const payMethodSelect = content.querySelector('#payMethodSelect');
        const payMethodContext = content.querySelector('#payMethodContext');
        const payTxnLabel = content.querySelector('#payTxnLabel');
        const payTxnInput = content.querySelector('#payTransactionId');
        const utrWarnMsg = content.querySelector('#utrWarnMsg');

        // Dynamic Payment Method UI Adapter with PaymentStudio
        const updatePaymentMethodUI = () => {
            const method = payMethodSelect?.value || 'upi';
            const amount = parseFloat(payAmount?.value) || 0;
            const discount = parseFloat(payDiscount?.value) || 0;
            const late = parseFloat(payLateFee?.value) || 0;
            const final = Math.max(0, amount - discount + late);

            if (method === 'cash') {
                if (payTxnLabel) payTxnLabel.innerHTML = '💵 Cash Collector Note / Register Slip (Optional)';
                if (payTxnInput) payTxnInput.placeholder = 'e.g. Cash received at reception desk';
                if (payMethodContext) {
                    payMethodContext.innerHTML = `
                        <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>💵</span>
                            <span><strong>Cash Payment:</strong> Instant official receipt generation. No transaction ID required.</span>
                        </div>
                    `;
                }
                if (utrWarnMsg) utrWarnMsg.style.display = 'none';
            } else if (method === 'bank_transfer') {
                if (payTxnLabel) payTxnLabel.innerHTML = '🏛️ Bank NEFT / IMPS / RTGS UTR Number *';
                if (payTxnInput) payTxnInput.placeholder = 'e.g. Bank Ref # / IMPS Transaction Reference';
                if (payMethodContext) {
                    payMethodContext.innerHTML = PaymentStudio.renderBankDetailsWidget();
                    PaymentStudio.attachEventListeners(payMethodContext);
                }
                if (utrWarnMsg) utrWarnMsg.style.display = 'none';
            } else if (method === 'card') {
                if (payTxnLabel) payTxnLabel.innerHTML = '💳 POS Slip Code / Card Last 4 Digits';
                if (payTxnInput) payTxnInput.placeholder = 'e.g. POS Auth Code #8492 or Card Ending 4321';
                if (payMethodContext) {
                    payMethodContext.innerHTML = `
                        <div style="background: rgba(225, 112, 85, 0.1); border: 1px solid #e17055; border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>💳</span>
                            <span><strong>Card Swipe / Terminal:</strong> Credit or Debit card processed on POS machine.</span>
                        </div>
                    `;
                }
                if (utrWarnMsg) utrWarnMsg.style.display = 'none';
            } else {
                // Default: High-Conversion UPI Studio
                if (payTxnLabel) payTxnLabel.innerHTML = '⚡ UPI / 12-Digit UTR Transaction ID *';
                if (payTxnInput) payTxnInput.placeholder = 'e.g. 12-digit UTR (e.g. 423456789012)';
                if (payMethodContext) {
                    payMethodContext.innerHTML = PaymentStudio.renderUPIWidget({
                        amount: final,
                        note: 'Library Fee Payment',
                        showUtrInput: false,
                        mountId: 'collect-pay-upi-qr-mount'
                    });
                    PaymentStudio.attachEventListeners(payMethodContext);
                }
            }
        };

        if (payMethodSelect) {
            payMethodSelect.addEventListener('change', updatePaymentMethodUI);
            updatePaymentMethodUI();
        }

        const calculateFinal = () => {
            const amount = parseFloat(payAmount.value) || 0;
            const discount = parseFloat(payDiscount.value) || 0;
            const late = parseFloat(payLateFee.value) || 0;
            const final = Math.max(0, amount - discount + late);
            finalDisplay.textContent = formatCurrency(final);

            // Dynamically refresh UPI QR if UPI is active
            if (payMethodSelect?.value === 'upi' && payMethodContext) {
                payMethodContext.innerHTML = PaymentStudio.renderUPIWidget({
                    amount: final,
                    note: 'Library Fee Payment',
                    showUtrInput: false,
                    mountId: 'collect-pay-upi-qr-mount'
                });
                PaymentStudio.attachEventListeners(payMethodContext);
            }
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
        
        const validateUTR = async () => {
            const method = payMethodSelect?.value || 'upi';
            if (method !== 'upi') {
                if (utrWarnMsg) utrWarnMsg.style.display = 'none';
                return true;
            }

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
            
            if (data.amount <= 0) {
                Toast.error('Payment amount must be greater than 0');
                return;
            }
            if (data.discount > data.amount) {
                Toast.error('Discount amount cannot exceed the payment amount');
                return;
            }
            
            if (submitBtn) UI.buttonLoading(submitBtn, true, 'Processing...');
            try {
                const res = await api.post('/api/payments', data);
                if (res.success) {
                    modal.hide();
                    Toast.success('Payment collected successfully!');
                    // 🎉 Phase 7: Confetti on payment success (green/teal theme)
                    if (typeof window.confettiCelebrate === 'function') {
                      window.confettiCelebrate({ duration: 1800, colors: ['#00b894','#00cec9','#55efc4','#6c5ce7','#fdcb6e'] });
                    }
                    if (typeof window.refreshNotifications === 'function') window.refreshNotifications();
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
                        <select name="method" id="balancePayMethodSelect" class="form-select form-control" required>
                            <option value="cash">💵 Cash at Reception Desk</option>
                            <option value="upi" selected>⚡ UPI (GPay / PhonePe / Paytm / BHIM)</option>
                            <option value="bank_transfer">🏛️ Bank Transfer (NEFT / IMPS / RTGS)</option>
                            <option value="card">💳 Debit / Credit Card (POS Terminal)</option>
                        </select>
                    </div>
                    <div class="col-12" id="balancePayMethodContext"></div>
                    <div class="col-12">
                        <label class="form-label" id="balancePayTxnLabel" style="font-weight: 500;">⚡ UPI / 12-Digit UTR Transaction ID</label>
                        <input type="text" name="transactionId" id="balancePayTxnInput" class="form-control" placeholder="e.g. 12-digit UTR (e.g. 423456789012)">
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

        const balanceMethodSelect = content.querySelector('#balancePayMethodSelect');
        const balanceMethodContext = content.querySelector('#balancePayMethodContext');
        const balanceTxnLabel = content.querySelector('#balancePayTxnLabel');
        const balanceTxnInput = content.querySelector('#balancePayTxnInput');

        const balanceAmountInput = content.querySelector('input[name="amount"]');

        const updateBalanceMethodUI = () => {
            const m = balanceMethodSelect?.value || 'upi';
            const curAmt = parseFloat(balanceAmountInput?.value) || parseFloat(balanceDue) || 0;
            if (m === 'cash') {
                if (balanceTxnLabel) balanceTxnLabel.innerHTML = '💵 Cash Collector Note (Optional)';
                if (balanceTxnInput) balanceTxnInput.placeholder = 'e.g. Cash received at reception desk';
                if (balanceMethodContext) {
                    balanceMethodContext.innerHTML = `
                        <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>💵</span>
                            <span><strong>Cash Payment:</strong> Instant installment receipt generated.</span>
                        </div>
                    `;
                }
            } else if (m === 'bank_transfer') {
                if (balanceTxnLabel) balanceTxnLabel.innerHTML = '🏛️ Bank NEFT / IMPS Reference Number';
                if (balanceTxnInput) balanceTxnInput.placeholder = 'e.g. Bank Ref # / IMPS Transaction Reference';
                if (balanceMethodContext) {
                    balanceMethodContext.innerHTML = PaymentStudio.renderBankDetailsWidget();
                    PaymentStudio.attachEventListeners(balanceMethodContext);
                }
            } else if (m === 'card') {
                if (balanceTxnLabel) balanceTxnLabel.innerHTML = '💳 POS Slip Code / Card Last 4 Digits';
                if (balanceTxnInput) balanceTxnInput.placeholder = 'e.g. POS Auth Code #8492 or Card Ending 4321';
                if (balanceMethodContext) {
                    balanceMethodContext.innerHTML = `
                        <div style="background: rgba(225, 112, 85, 0.1); border: 1px solid #e17055; border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>💳</span>
                            <span><strong>Card Swipe:</strong> Processed on POS terminal.</span>
                        </div>
                    `;
                }
            } else {
                if (balanceTxnLabel) balanceTxnLabel.innerHTML = '⚡ UPI / 12-Digit UTR Transaction ID *';
                if (balanceTxnInput) balanceTxnInput.placeholder = 'e.g. 12-digit UTR (e.g. 423456789012)';
                if (balanceMethodContext) {
                    balanceMethodContext.innerHTML = PaymentStudio.renderUPIWidget({
                        amount: curAmt,
                        note: 'Balance Due Payment',
                        showUtrInput: false,
                        mountId: 'balance-pay-upi-qr-mount'
                    });
                    PaymentStudio.attachEventListeners(balanceMethodContext);
                }
            }
        };

        if (balanceMethodSelect) {
            balanceMethodSelect.addEventListener('change', updateBalanceMethodUI);
            updateBalanceMethodUI();
        }

        balanceAmountInput?.addEventListener('input', () => {
            if (balanceMethodSelect?.value === 'upi' && balanceMethodContext) {
                const curAmt = parseFloat(balanceAmountInput.value) || 0;
                balanceMethodContext.innerHTML = PaymentStudio.renderUPIWidget({
                    amount: curAmt,
                    note: 'Balance Due Payment',
                    showUtrInput: false,
                    mountId: 'balance-pay-upi-qr-mount'
                });
                PaymentStudio.attachEventListeners(balanceMethodContext);
            }
        });
        
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
        const modalContainer = document.createElement('div');
        modalContainer.innerHTML = `
            <div class="text-center p-4 text-muted">
                <div class="loading-spinner mb-2" style="margin: 0 auto; width: 32px; height: 32px;"></div>
                <div style="font-weight: 600; font-size: 0.95rem;">Preparing digital fee receipt...</div>
            </div>
        `;

        const receiptModal = Modal.show({
            title: 'Fee Payment Receipt',
            content: modalContainer,
            size: 'md'
        });

        try {
            const config = window.store?.settings?.receipt || { header: {}, body: {}, gst: {}, footer: {} };
            const bp = window.store?.settings?.businessProfile || JSON.parse(localStorage.getItem('sl_public_profile_cache') || '{}') || {};

            const res = await api.get(`/api/payments/${paymentId}`);
            if (!res || !res.data) throw new Error('Payment data not found');
            const r = res.data;
            let currentTemplate = config.activeTemplate || 'thermal80';

            const receiptDiv = document.createElement('div');
            receiptDiv.innerHTML = `
                <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
                    <div class="d-flex align-items-center gap-2">
                        <label class="form-label mb-0 small" style="font-weight: 600;">Format:</label>
                        <select id="receipt-paper-format" class="form-select form-select-sm" style="width: 170px; padding: 4px 8px; font-size: 0.85rem;">
                            <option value="thermal80" ${currentTemplate === 'thermal80' || currentTemplate === 'thermal_80' ? 'selected' : ''}>🧾 80mm POS Thermal</option>
                            <option value="thermal58" ${currentTemplate === 'thermal58' || currentTemplate === 'thermal_58' ? 'selected' : ''}>🧾 58mm Mini POS</option>
                            <option value="standardA4" ${currentTemplate === 'standardA4' || currentTemplate === 'standard_a4' || currentTemplate === 'gst_invoice' ? 'selected' : ''}>📄 Standard A4 Invoice</option>
                            <option value="modern_minimal" ${currentTemplate === 'modern_minimal' ? 'selected' : ''}>✨ Modern Digital Pass</option>
                        </select>
                    </div>
                    <div class="d-flex align-items-center gap-1 flex-wrap">
                        <button class="btn btn-xs btn-outline-primary" data-template="thermal80">80mm</button>
                        <button class="btn btn-xs btn-outline-primary" data-template="thermal58">58mm</button>
                        <button class="btn btn-xs btn-outline-primary" data-template="standardA4">A4</button>
                        <button class="btn btn-xs btn-outline-primary" data-template="modern_minimal">Modern</button>
                    </div>
                </div>

                <div id="receipt-container-box" class="receipt-print-area" style="background: #ffffff; border-radius: 8px; transition: all 0.3s ease; margin: 0 auto; overflow: hidden; color: #000; display: flex; justify-content: center; padding: 10px;">
                    <!-- Content rendered here -->
                </div>
                
                <div class="text-center mt-3 d-flex justify-content-center flex-wrap gap-2">
                    <button class="btn btn-success" id="btn-share-whatsapp-receipt" style="background: #25D366; border-color: #25D366; font-weight: 600;">
                        📲 WhatsApp
                    </button>
                    <button class="btn btn-primary" id="btn-print-receipt-action">🖨️ Print Receipt</button>
                    <button class="btn btn-secondary modal-close-btn" onclick="Modal.close()">Close</button>
                </div>
            `;
            
            const receiptBox = receiptDiv.querySelector('#receipt-container-box');
            
            const renderTemplate = (templateId) => {
                currentTemplate = templateId;
                const html = buildReceiptHTML(r, {
                    receiptConfig: config,
                    businessProfile: bp,
                    template: templateId
                });
                receiptBox.innerHTML = html;
            };

            modalContainer.innerHTML = '';
            modalContainer.appendChild(receiptDiv);

            // Initial render
            renderTemplate(currentTemplate);

            // Handle Format/Template Switcher
            const formatSelect = receiptDiv.querySelector('#receipt-paper-format');
            formatSelect?.addEventListener('change', () => {
                const fmt = formatSelect.value;
                renderTemplate(fmt);
                
                const templateBtns = receiptDiv.querySelectorAll('[data-template]');
                templateBtns.forEach(b => {
                    if (b.dataset.template === fmt) {
                        b.classList.remove('btn-outline-primary');
                        b.classList.add('active', 'btn-primary');
                    } else {
                        b.classList.remove('active', 'btn-primary');
                        b.classList.add('btn-outline-primary');
                    }
                });
            });

            const templateBtns = receiptDiv.querySelectorAll('[data-template]');
            templateBtns.forEach(btn => {
                btn.addEventListener('click', (e) => {
                    const tpl = e.target.dataset.template;
                    templateBtns.forEach(b => b.classList.remove('active', 'btn-primary'));
                    templateBtns.forEach(b => b.classList.add('btn-outline-primary'));
                    e.target.classList.remove('btn-outline-primary');
                    e.target.classList.add('active', 'btn-primary');
                    
                    if (formatSelect) formatSelect.value = tpl;
                    renderTemplate(tpl);
                });
            });

            // Set initial active button
            const activeBtn = receiptDiv.querySelector(`[data-template="${currentTemplate}"]`);
            if (activeBtn) {
                activeBtn.classList.remove('btn-outline-primary');
                activeBtn.classList.add('active', 'btn-primary');
            }

            // Handle Print Button
            receiptDiv.querySelector('#btn-print-receipt-action')?.addEventListener('click', () => {
                printReceiptDocument(r, {
                    receiptConfig: config,
                    businessProfile: bp,
                    template: currentTemplate
                });
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

    // ── Phase 5: Payments Bulk Operations Engine ───────────────────────────
    const selectedPaymentIds = new Set();

    function updatePaymentsBulkBar() {
      const bar = container.querySelector('#payments-bulk-bar');
      const countEl = container.querySelector('#payments-bulk-count');
      const checkAll = container.querySelector('#payments-check-all');
      if (!bar) return;
      const count = selectedPaymentIds.size;
      if (count > 0) {
        bar.style.display = 'flex';
      } else {
        bar.style.display = 'none';
      }
      if (countEl) countEl.textContent = `${count} Selected`;
      // Highlight selected rows
      container.querySelectorAll('.payment-row').forEach(row => {
        const isSelected = selectedPaymentIds.has(row.dataset.id);
        row.style.background = isSelected ? 'rgba(108,92,231,0.1)' : '';
        row.style.transition = 'background 0.15s ease';
        const cb = row.querySelector('.payment-row-check');
        if (cb) cb.checked = isSelected;
      });
      // Header checkbox indeterminate state
      if (checkAll) {
        const total = container.querySelectorAll('.payment-row-check').length;
        checkAll.checked = count > 0 && count === total;
        checkAll.indeterminate = count > 0 && count < total;
      }
    }

    // Wire row checkboxes — runs after each renderPaymentsTableRows call
    function wirePaymentRowCheckboxes() {
      container.querySelectorAll('.payment-row-check').forEach(cb => {
        cb.addEventListener('change', () => {
          const id = cb.dataset.id;
          if (cb.checked) selectedPaymentIds.add(id);
          else selectedPaymentIds.delete(id);
          updatePaymentsBulkBar();
        });
      });
      // Also allow clicking the row itself (but not buttons inside) to toggle
      container.querySelectorAll('.payment-row').forEach(row => {
        row.addEventListener('click', (e) => {
          if (e.target.closest('button, a, input, select')) return;
          const id = row.dataset.id;
          if (selectedPaymentIds.has(id)) { selectedPaymentIds.delete(id); }
          else { selectedPaymentIds.add(id); }
          updatePaymentsBulkBar();
        });
      });
    }

    // Patch renderPaymentsTableRows to wire checkboxes after render
    const _origRender = renderPaymentsTableRows;
    // Re-wire checkboxes whenever tbody changes via MutationObserver
    const paymentsObserver = new MutationObserver(() => {
      wirePaymentRowCheckboxes();
    });
    const paymentsTableBody = container.querySelector('#paymentsTableBody');
    if (paymentsTableBody) paymentsObserver.observe(paymentsTableBody, { childList: true });

    // Check-all header checkbox
    container.querySelector('#payments-check-all')?.addEventListener('change', (e) => {
      const checked = e.target.checked;
      container.querySelectorAll('.payment-row-check').forEach(cb => {
        const id = cb.dataset.id;
        if (checked) selectedPaymentIds.add(id);
        else selectedPaymentIds.delete(id);
      });
      updatePaymentsBulkBar();
    });

    // Select All button (header)
    container.querySelector('#payments-toggle-select-all')?.addEventListener('click', () => {
      const allChecks = container.querySelectorAll('.payment-row-check');
      const allSelected = allChecks.length > 0 && allChecks.length === selectedPaymentIds.size;
      allChecks.forEach(cb => {
        if (allSelected) selectedPaymentIds.delete(cb.dataset.id);
        else selectedPaymentIds.add(cb.dataset.id);
      });
      updatePaymentsBulkBar();
    });

    // ── Cancel ─────────────────────────────────────────────────────────────
    container.querySelector('#payments-bulk-cancel')?.addEventListener('click', () => {
      selectedPaymentIds.clear();
      updatePaymentsBulkBar();
    });

    // ── Bulk Mark Paid ──────────────────────────────────────────────────────
    container.querySelector('#payments-bulk-mark-paid')?.addEventListener('click', async () => {
      if (!selectedPaymentIds.size) return;
      const btn = container.querySelector('#payments-bulk-mark-paid');
      btn.disabled = true; btn.textContent = '⏳ Updating…';
      let updated = 0;
      for (const id of selectedPaymentIds) {
        try {
          const r = await api.put(`/api/payments/${id}/status`, { status: 'paid' });
          if (r.success) {
            updated++;
            const row = container.querySelector(`.payment-row[data-id="${id}"]`);
            if (row) {
              const badge = row.querySelector('.btn-toggle-payment-status');
              if (badge) { badge.textContent = 'paid'; badge.dataset.status = 'paid'; badge.style.background = 'rgba(0,184,148,0.2)'; badge.style.color = 'var(--color-success)'; }
            }
          }
        } catch (e) {}
      }
      btn.disabled = false; btn.textContent = '✅ Mark Paid';
      Toast.success(`✅ ${updated} payment(s) marked as Paid`);
      selectedPaymentIds.clear();
      updatePaymentsBulkBar();
    });

    // ── Bulk Mark Pending ────────────────────────────────────────────────────
    container.querySelector('#payments-bulk-mark-pending')?.addEventListener('click', async () => {
      if (!selectedPaymentIds.size) return;
      const btn = container.querySelector('#payments-bulk-mark-pending');
      btn.disabled = true; btn.textContent = '⏳ Updating…';
      let updated = 0;
      for (const id of selectedPaymentIds) {
        try {
          const r = await api.put(`/api/payments/${id}/status`, { status: 'pending' });
          if (r.success) {
            updated++;
            const row = container.querySelector(`.payment-row[data-id="${id}"]`);
            if (row) {
              const badge = row.querySelector('.btn-toggle-payment-status');
              if (badge) { badge.textContent = 'pending'; badge.dataset.status = 'pending'; badge.style.background = 'rgba(214,48,49,0.2)'; badge.style.color = 'var(--color-danger)'; }
            }
          }
        } catch (e) {}
      }
      btn.disabled = false; btn.textContent = '⏳ Mark Pending';
      Toast.success(`⏳ ${updated} payment(s) marked as Pending`);
      selectedPaymentIds.clear();
      updatePaymentsBulkBar();
    });

    // ── Bulk WhatsApp Reminders ──────────────────────────────────────────────
    container.querySelector('#payments-bulk-wa-remind')?.addEventListener('click', () => {
      if (!selectedPaymentIds.size) { Toast.warning('Select payments first'); return; }
      const rows = Array.from(selectedPaymentIds).map(id =>
        container.querySelector(`.payment-row[data-id="${id}"]`)
      ).filter(Boolean);
      if (!rows.length) return;

      const libName = window.store?.settings?.businessName || 'The Cozy Corner Centre';
      let sentCount = 0;
      rows.forEach((row, i) => {
        const phone = row.dataset.studentPhone;
        const name  = row.dataset.studentName || 'Student';
        const amt   = row.dataset.amount;
        const receipt = row.dataset.receipt;
        const status  = row.dataset.status;
        if (!phone) return;
        const cleanPhone = phone.replace(/[^0-9]/g, '');
        const waPhone = cleanPhone.startsWith('91') ? cleanPhone : `91${cleanPhone}`;
        const msg = status === 'pending' || status === 'partial'
          ? `Hi ${name}! 🙏 Your fee payment of ₹${amt} (Receipt: ${receipt}) at *${libName}* is pending. Please pay at your earliest. Thank you!`
          : `Hi ${name}! ✅ Your payment of ₹${amt} (Receipt: ${receipt}) at *${libName}* has been received. Thank you for studying with us! 📚`;
        setTimeout(() => {
          window.open(`https://wa.me/${waPhone}?text=${encodeURIComponent(msg)}`, '_blank');
          sentCount++;
        }, i * 800);
      });
      Toast.success(`📲 Opening WhatsApp for ${rows.length} student(s)…`);
    });

    // ── Bulk Export CSV ─────────────────────────────────────────────────────
    container.querySelector('#payments-bulk-export-csv')?.addEventListener('click', () => {
      if (!selectedPaymentIds.size) { Toast.warning('Select payments first'); return; }
      const rows = Array.from(selectedPaymentIds).map(id =>
        container.querySelector(`.payment-row[data-id="${id}"]`)
      ).filter(Boolean);

      const headers = ['Receipt No','Student Name','Phone','Amount','Status'];
      const csvData = rows.map(row => [
        `"${row.dataset.receipt}"`,
        `"${row.dataset.studentName}"`,
        `"${row.dataset.studentPhone}"`,
        `"${row.dataset.amount}"`,
        `"${row.dataset.status}"`
      ].join(','));

      const csv = [headers.join(','), ...csvData].join('\n');
      const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url; a.download = `payments_selected_${Date.now()}.csv`; a.click();
      URL.revokeObjectURL(url);
      Toast.success(`📥 Exported ${rows.length} payment(s) to CSV`);
    });

    // ── Bulk Delete ──────────────────────────────────────────────────────────
    container.querySelector('#payments-bulk-delete')?.addEventListener('click', async () => {
      if (!selectedPaymentIds.size) return;
      const count = selectedPaymentIds.size;
      const confirmed = await Confirm.show({
        title: `🗑️ Delete ${count} Payment(s)?`,
        message: `This will permanently delete ${count} selected payment record(s). This action cannot be undone.`,
        confirmText: `Delete ${count} Payments`,
        danger: true
      });
      if (!confirmed) return;

      const btn = container.querySelector('#payments-bulk-delete');
      btn.disabled = true; btn.textContent = '⏳ Deleting…';
      let deleted = 0;
      for (const id of selectedPaymentIds) {
        try {
          const r = await api.delete(`/api/payments/${id}`);
          if (r.success) {
            deleted++;
            container.querySelector(`.payment-row[data-id="${id}"]`)?.remove();
          }
        } catch (e) {}
      }
      btn.disabled = false; btn.textContent = '🗑️ Delete';
      Toast.success(`🗑️ ${deleted} payment(s) deleted`);
      selectedPaymentIds.clear();
      updatePaymentsBulkBar();
    });

    // Mount context-aware FAB for Payments page
    if (typeof window !== 'undefined' && window.FAB) {
      window.FAB.mount({
        icon: '💳',
        label: 'Payment Actions',
        color: '#00b894',
        actions: [
          {
            icon: '➕',
            label: 'Collect Fee',
            onClick: () => {
              showCollectModal();
            }
          },
          {
            icon: '📥',
            label: 'Export CSV',
            onClick: () => {
              exportPaymentsCSV();
            }
          },
          {
            icon: '📊',
            label: 'Revenue Report',
            onClick: () => {
              window.location.hash = '#/reports';
            }
          }
        ]
      });
    }

    return container;
}
