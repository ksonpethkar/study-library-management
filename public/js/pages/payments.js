import"../app.js";import"../i18n.js";import{Toast as c,Modal as U,Loading as P,Confirm as G,escapeHTML as b,copyToClipboard as Y,UI as H}from"../ui.js";import{SmartFormatters as q}from"../utils/smartFormatters.js";import k from"../api.js";import{IDBStorage as B}from"../utils/idbStorage.js";import{OptimisticUI as te}from"../utils/optimisticUI.js";import{buildReceiptHTML as de,printReceiptDocument as ce}from"../pdfGenerator.js";import{PaymentStudio as A}from"../paymentStudio.js";import{initSwipeCards as ae}from"../utils/mobileGestures.js";const N=p=>q.currency(p),j=p=>p?new Date(p).toLocaleDateString("en-IN"):"-";async function pe(p){p||(p=document.createElement("div"),p.className="page-container"),p.innerHTML=`
        <!-- Standard Module Header -->
        <div class="module-header">
            <div class="module-title-area">
                <h2>\u{1F4B0} Payment Management</h2>
                <p>Track student fee collections, generate GST/standard receipts, and manage pending dues.</p>
            </div>
            <div class="module-actions d-flex gap-2 align-items-center flex-wrap">
                <button class="btn btn-outline-secondary d-flex align-items-center gap-2" id="btnCashRegister" style="font-weight: 700;">
                    <span>\u{1F4B5}</span> Cash Register Handover
                </button>
                <button class="btn btn-primary d-flex align-items-center gap-2" id="btnCollectPayment" style="font-weight: 700;">
                    <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></svg>
                    Collect Fee Payment
                </button>
            </div>
        </div>
        
        <!-- Contextual Guidance Tip Banner -->
        <div style="background: rgba(108, 92, 231, 0.06); border: 1px solid rgba(108, 92, 231, 0.2); border-radius: 10px; padding: 10px 14px; font-size: 0.85rem; display: flex; align-items: center; gap: 10px; margin-bottom: 1rem;">
            <span style="font-size: 1.1rem;">\u{1F4A1}</span>
            <span><strong>Tip:</strong> 1-Tap WhatsApp buttons send instant payment receipts and partial fee balance reminders with pre-filled UPI deep links.</span>
        </div>

        <!-- Standard KPI Stats Grid -->
        <div class="kpi-grid" id="paymentsStatsContainer">
            <div class="kpi-card kpi-success">
                <div class="kpi-label">Today's Collection <span>\u{1F4B5}</span></div>
                <div class="kpi-value text-success" id="statToday">\u20B90</div>
                <div class="kpi-subtext">Received today</div>
            </div>
            <div class="kpi-card kpi-primary">
                <div class="kpi-label">This Month Collection <span>\u{1F4C5}</span></div>
                <div class="kpi-value" id="statMonth" style="color: var(--color-primary);">\u20B90</div>
                <div class="kpi-subtext">Current billing cycle</div>
            </div>
            <div class="kpi-card kpi-danger">
                <div class="kpi-label">Pending Dues <span>\u26A0\uFE0F</span></div>
                <div class="kpi-value text-danger" id="statPending">\u20B90</div>
                <div class="kpi-subtext">Overdue fees</div>
            </div>
            <div class="kpi-card kpi-info">
                <div class="kpi-label">Total Invoices <span>\u{1F9FE}</span></div>
                <div class="kpi-value" id="statTotalCount" style="color: var(--color-info);">0</div>
                <div class="kpi-subtext">Issued receipts</div>
            </div>
        </div>
        
        <!-- \u2500\u2500 Phase 5: Payments Bulk Operations Bar \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500 -->
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
              \u2705 Mark Paid
            </button>
            <button type="button" id="payments-bulk-mark-pending" class="btn btn-sm btn-outline-warning" style="font-weight: 600; border-radius: 8px;">
              \u23F3 Mark Pending
            </button>
            <button type="button" id="payments-bulk-wa-remind" class="btn btn-sm" style="font-weight: 600; border-radius: 8px; background: #25D366; color: #fff; border: none;">
              \u{1F4F2} WA Reminders
            </button>
            <button type="button" id="payments-bulk-export-csv" class="btn btn-sm btn-outline-info" style="font-weight: 600; border-radius: 8px;">
              \u{1F4E5} Export Selected
            </button>
            <button type="button" id="payments-bulk-delete" class="btn btn-sm btn-danger" style="font-weight: 600; border-radius: 8px;">
              \u{1F5D1}\uFE0F Delete
            </button>
            <button type="button" id="payments-bulk-cancel" class="btn btn-sm" style="font-weight: 600; border-radius: 8px; background: rgba(255,255,255,0.08); color: #94a3b8; border: 1px solid rgba(255,255,255,0.12);">
              \u2715 Cancel
            </button>
          </div>
        </div>

        <!-- Recent Payments Table Card -->
        <div class="card mb-4">
            <div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-3">
                <div style="display: flex; align-items: center; gap: 10px;">
                  <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700;">Recent Fee Payments</h3>
                  <button type="button" id="payments-toggle-select-all" class="btn btn-xs btn-outline-secondary" style="font-size: 0.75rem; padding: 3px 10px; border-radius: 12px; font-weight: 600;" title="Toggle select all rows">
                    \u2611\uFE0F Select All
                  </button>
                </div>
                <div class="filters d-flex gap-2 align-items-center flex-wrap w-100 w-md-auto">
                    <select id="filterMethod" class="form-select form-control form-control-sm w-100 w-md-auto" style="font-weight: 600;">
                        <option value="">All Methods</option>
                        <option value="cash">\u{1F4B5} Cash</option>
                        <option value="upi">\u{1F4F1} UPI / QR</option>
                        <option value="bank_transfer">\u{1F3E6} Bank Transfer</option>
                        <option value="card">\u{1F4B3} Card</option>
                    </select>
                    <select id="filterStatus" class="form-select form-control form-control-sm w-100 w-md-auto" style="font-weight: 600;">
                        <option value="">All Statuses</option>
                        <option value="pending_verification">\u23F3 Pending UTR Verification</option>
                        <option value="paid">\u{1F7E2} Paid</option>
                        <option value="pending">\u{1F7E1} Pending</option>
                        <option value="partial">\u{1F7E0} Partial</option>
                        <option value="refunded">\u{1F534} Refunded</option>
                    </select>
                    <button id="btnFilterPendingVerification" class="btn btn-sm w-100 w-md-auto" style="font-weight: 700; border: 1.5px solid #f39c12; color: #b78103; background: rgba(243, 156, 18, 0.12);">\u26A1 Verification Queue</button>
                    <button id="btnPendingInstallments" class="btn btn-sm btn-outline-warning w-100 w-md-auto" style="font-weight: 600;">\u23F3 Balances</button>
                    <button id="btnExportPaymentsCSV" class="btn btn-sm btn-outline-success w-100 w-md-auto" style="font-weight: 600;">\u{1F4E5} Export CSV</button>
                    <button type="button" id="btnTogglePayFeed" class="btn btn-sm btn-outline-primary w-100 w-md-auto" style="font-weight: 700; border-radius: 999px;" title="Switch between Card Feed and Table View">\u{1F4F1} Feed View</button>
                </div>
            </div>
            <div class="card-body p-0">
                <!-- Sleek Transaction Feed View (Matches User Shared Image) -->
                <div id="paymentsFeedContainer" class="p-3" style="display: none;"></div>

                <!-- Standard Data Table View (Desktop) -->
                <div class="table-responsive desktop-table-view" id="paymentsTableWrapper">
                    <table class="table data-table mb-0">
                        <thead>
                            <tr>
                                <th style="width: 36px; padding: 8px 10px;">
                                  <input type="checkbox" id="payments-check-all" title="Select all" style="cursor: pointer; width: 16px; height: 16px;">
                                </th>
                                <th>Receipt / Transaction</th>
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

                <!-- Mobile Card List View (Mobile <= 768px) -->
                <div class="mobile-card-list p-2" id="paymentsMobileCardList">
                    <div class="text-center p-4 text-muted">Loading payments...</div>
                </div>
            </div>
        </div>
        
        <!-- Pending Dues Card -->
        <div class="card">
            <div class="card-header">
                <h5 style="margin: 0; font-size: 1.1rem; font-weight: 600; color: var(--color-danger, #d63031);">\u26A0\uFE0F Expired Memberships & Pending Dues</h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive desktop-table-view">
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

                <!-- Mobile Dues Card List -->
                <div class="mobile-card-list p-2" id="duesMobileCardList">
                    <div class="text-center p-4 text-muted">Loading dues...</div>
                </div>
            </div>
        </div>
    `,setTimeout(()=>{R(),L(),K();const a=p.querySelector("#btnCollectPayment");a&&a.addEventListener("click",()=>W());const i=p.querySelector("#filterMethod");i&&i.addEventListener("change",L);const o=p.querySelector("#filterStatus");o&&o.addEventListener("change",L);const e=p.querySelector("#btnFilterPendingVerification");e&&e.addEventListener("click",()=>{o&&(o.value="pending_verification"),L(),c.info("Showing online payments awaiting UTR verification")});const t=p.querySelector("#btnPendingInstallments");t&&t.addEventListener("click",()=>{o&&(o.value="partial"),L()});const r=p.querySelector("#btnExportPaymentsCSV");r&&r.addEventListener("click",Q);const n=p.querySelector("#btnTogglePayFeed");n&&n.addEventListener("click",()=>{const s=p.querySelector("#paymentsTableWrapper"),l=p.querySelector("#paymentsFeedContainer");l?.style.display!=="none"?(l&&(l.style.display="none"),s&&(s.style.display="block"),n.textContent="\u{1F4F1} Feed View",n.className="btn btn-sm btn-outline-primary w-100 w-md-auto"):(l&&(l.style.display="block"),s&&(s.style.display="none"),n.textContent="\u{1F4D1} Table View",n.className="btn btn-sm btn-primary w-100 w-md-auto")})},0);async function Q(){try{P.show("Preparing CSV export...");const a=document.getElementById("filterMethod")?.value||"",i=document.getElementById("filterStatus")?.value||"";let o="/api/payments?limit=1000";a&&(o+=`&method=${a}`),i&&(o+=`&status=${i}`);const e=await k.get(o);if(P.hide(),!e.success||!e.data||e.data.length===0){c.error("No payment records to export");return}const t=e.data;let r=`Receipt No,Student Name,Student Phone,Amount (INR),Payment Method,Transaction UTR,Date,Status
`;t.forEach(d=>{const m=d.receiptNumber||d._id,y=(d.student?.name||d.studentName||"Student").replace(/,/g,""),F=d.student?.phone||d.phone||"",E=d.finalAmount||d.amount||0,h=d.paymentMethod||"cash",g=d.transactionId||"N/A",C=d.createdAt?new Date(d.createdAt).toLocaleDateString("en-IN"):"",x=d.status||"paid";r+=`"${m}","${y}","${F}",${E},"${h}","${g}","${C}","${x}"
`});const n=new Blob([r],{type:"text/csv;charset=utf-8;"}),s=URL.createObjectURL(n),l=document.createElement("a");l.href=s,l.setAttribute("download",`Payments_Ledger_${new Date().toISOString().split("T")[0]}.csv`),document.body.appendChild(l),l.click(),document.body.removeChild(l),c.success("Payments CSV downloaded successfully!")}catch(a){P.hide(),c.error("Failed to export CSV: "+a.message)}}async function R(){try{const a=await B.get("payments","stats");if(a){const i=document.getElementById("statToday"),o=document.getElementById("statMonth"),e=document.getElementById("statPending");i&&(i.textContent=N(a.todayRevenue)),o&&(o.textContent=N(a.monthRevenue)),e&&(e.textContent=N(a.totalPending))}}catch(a){console.warn("IDB read payments stats warning:",a)}try{const a=await k.get("/api/payments/stats");if(a.success&&a.data){await B.set("payments","stats",a.data);const i=document.getElementById("statToday"),o=document.getElementById("statMonth"),e=document.getElementById("statPending");i&&(i.textContent=N(a.data.todayRevenue)),o&&(o.textContent=N(a.data.monthRevenue)),e&&(e.textContent=N(a.data.totalPending))}}catch(a){console.error("Error loading stats",a)}}async function Z(a,i,o){if(await G.show({title:"Verify UPI Payment",message:`Confirm that UTR / Reference "${i||"N/A"}" (Invoice ${o||a}) matches your bank statement and mark as Paid?`,confirmText:"\u2705 Yes, Verify & Activate Student",cancelText:"Cancel"}))try{const e=await k.put(`/api/payments/${a}/verify-utr`);e.success?(c.success(e.message||"Payment verified successfully!"),await B.clear("payments"),L(),R()):c.error(e.message||"Failed to verify payment")}catch(e){c.error(e.message||"Verification failed")}}async function J(a,i){const o=prompt(`Enter rejection reason for payment ${i||""}:`,"UTR not found in bank statement / Invalid amount");if(!(!o||!o.trim()))try{const e=await k.put(`/api/payments/${a}/reject-utr`,{reason:o.trim()});e.success?(c.warning(e.message||"Payment marked as rejected"),await B.clear("payments"),L(),R()):c.error(e.message||"Failed to reject payment")}catch(e){c.error(e.message||"Rejection failed")}}function V(a,i){if(!i)return;if(!a||a.length===0){H.emptyState(i,{icon:"\u{1F4B3}",title:"No Payments Found",description:"No fee collection transactions recorded matching your filter. Click below to collect fee.",actionText:"+ Collect Fee Payment",onAction:()=>{const e=document.getElementById("btnCollectPayment");e&&e.click()}});return}i.innerHTML=a.map(e=>`
            <tr class="payment-row" data-id="${e._id}" data-status="${e.status}" data-amount="${e.finalAmount}" data-student-name="${b(e.student?.name||"")}" data-student-phone="${b(e.student?.phone||"")}" data-receipt="${b(e.receiptNumber||"")}">
                <td style="width: 36px; padding: 8px 10px; text-align: center;">
                  <input type="checkbox" class="payment-row-check" data-id="${e._id}" style="cursor: pointer; width: 16px; height: 16px; accent-color: #6c5ce7;">
                </td>
                <td>
                    <div style="display: flex; align-items: center; gap: 10px;">
                        ${A.renderDebitTrayIcon(32)}
                        <div>
                            <a href="#" class="receipt-link" data-id="${e._id}" style="font-family: monospace; font-weight: 700; color: var(--color-primary, #6c5ce7); display: block;">${b(e.receiptNumber||"N/A")}</a>
                            <span class="tx-badge-pill tx-badge-paid" style="font-size: 0.65rem; padding: 1px 6px;">\u2193 RECEIVED</span>
                        </div>
                    </div>
                </td>
                <td>
                    <div style="font-weight: 600;">${b(e.student?.name||e.studentName||(e.notes&&!e.notes.startsWith("{")?e.notes:"Registered Student"))}</div>
                    <small class="text-muted">${b(q.phone(e.student?.phone)||"")}</small>
                </td>
                <td><strong class="tx-amount tx-amount-green" style="font-size: 1.05rem; color: #10b981;">\u20B9${Number(e.finalAmount||0).toLocaleString("en-IN")}</strong></td>
                <td><span class="badge" style="background: rgba(255,255,255,0.08); padding: 4px 8px; border-radius: 4px; text-transform: uppercase;">${b(e.paymentMethod)}</span></td>
                <td>${j(e.paymentDate)} <small class="text-muted">(${q.timeAgo(e.paymentDate)})</small></td>
                <td>
                    ${e.status==="paid"?`
                        <span class="tx-badge-pill tx-badge-paid">\u2713 Paid</span>
                    `:e.status==="pending_verification"?`
                        <span class="tx-badge-pill tx-badge-pending" title="Submitted UTR: ${b(e.transactionId||"N/A")}">\u23F3 Verification</span>
                    `:e.status==="partial"||e.status==="partially_paid"?`
                        <span class="badge" style="background: rgba(9, 132, 227, 0.18); color: #0984e3; padding: 4px 8px; border-radius: 4px; font-weight: 700;">\u{1F4B3} Due: \u20B9${e.balanceDue||0}</span>
                    `:e.status==="failed"?`
                        <span class="badge" style="background: rgba(214, 48, 49, 0.18); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 700;">\u274C Rejected</span>
                    `:`
                        <span class="badge" style="background: rgba(214, 48, 49, 0.18); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 700;">\u26A0\uFE0F Pending Fee</span>
                    `}
                </td>
                <td style="white-space: nowrap;">
                    <div class="btn-icon-group" style="display: inline-flex; align-items: center; gap: 4px;">
                        ${e.status==="pending_verification"?`
                            <button type="button" class="btn-icon-action action-verify btn-verify-utr" data-id="${e._id}" data-utr="${b(e.transactionId||"")}" data-receipt="${b(e.receiptNumber||"")}" data-tooltip="Verify UTR (1-Click)" aria-label="Verify UTR">\u2705</button>
                            <button type="button" class="btn-icon-action action-reject btn-reject-utr" data-id="${e._id}" data-receipt="${b(e.receiptNumber||"")}" data-tooltip="Reject UTR" aria-label="Reject UTR">\u274C</button>
                        `:""}
                        <button type="button" class="btn-icon-action action-receipt btn-view" data-id="${e._id}" data-tooltip="View / Print Receipt" aria-label="View Receipt">\u{1F9FE}</button>
                        <button type="button" class="btn-icon-action action-whatsapp btn-wa-bill" data-id="${e._id}" data-tooltip="WhatsApp Bill" aria-label="WhatsApp Bill">\u{1F4AC}</button>
                        <button type="button" class="btn-icon-action action-edit btn-copy-text" data-copy="${b(e.receiptNumber||"")}" data-tooltip="Copy Receipt #" aria-label="Copy">\u{1F4CB}</button>
                        ${e.status==="partial"&&e.balanceDue>0?`
                            <button type="button" class="btn-icon-action action-verify btn-pay-balance" data-id="${e._id}" data-balance="${e.balanceDue}" data-tooltip="Pay Due \u20B9${e.balanceDue}" aria-label="Pay Balance">\u{1F4B0}</button>
                        `:""}
                        ${typeof ActionMenu<"u"?ActionMenu.renderHtml([{header:"Level 1: Verification & Receipts"},{id:"view-receipt",icon:"\u{1F9FE}",label:"View / Print POS Receipt",bold:!0},{id:"wa-receipt",icon:"\u{1F4F2}",label:"WhatsApp Receipt Alert"},...e.status==="pending_verification"?[{id:"quick-verify",icon:"\u2705",label:"Approve & Verify UTR",bold:!0},{id:"quick-reject",icon:"\u274C",label:"Reject UTR Submission",danger:!0}]:[],{divider:!0},{header:"Level 2: Financial Governance"},{id:"toggle-status",icon:e.status==="paid"?"\u23F3":"\u2705",label:e.status==="paid"?"Mark as Pending":"Mark as Paid"},{divider:!0},{header:"Level 3: Danger Zone"},{id:"delete",icon:"\u{1F5D1}\uFE0F",label:"Delete Payment Record",danger:!0}],e._id):""}
                    </div>
                </td>
            </tr>
        `).join("");const o=document.getElementById("paymentsMobileCardList");o&&(!a||a.length===0?o.innerHTML='<div class="text-center p-4 text-muted">No transactions recorded yet. Click "+ Collect Fee Payment" to record one.</div>':(o.innerHTML=a.map(e=>{let t='<span class="mobile-card-badge badge-active">\u2713 Paid</span>';return e.status==="pending_verification"?t=`<span class="mobile-card-badge badge-pending" title="Submitted UTR: ${b(e.transactionId||"N/A")}">\u23F3 Verification</span>`:e.status==="partial"||e.status==="partially_paid"?t=`<span class="mobile-card-badge badge-pending">Due: \u20B9${e.balanceDue||0}</span>`:e.status==="failed"&&(t='<span class="mobile-card-badge badge-expired">\u274C Rejected</span>'),`
                        <div class="swipe-item-container">
                            <div class="swipe-actions-revealed">
                                <button type="button" class="swipe-btn swipe-btn-whatsapp btn-wa-bill" data-id="${e._id}" title="WhatsApp Receipt" onclick="event.stopPropagation()">
                                    <span style="font-size: 1.25rem;">\u{1F4AC}</span>
                                    <span>Receipt</span>
                                </button>
                                <button type="button" class="swipe-btn swipe-btn-edit btn-view" data-id="${e._id}" title="View Receipt" onclick="event.stopPropagation()">
                                    <span style="font-size: 1.25rem;">\u{1F9FE}</span>
                                    <span>View</span>
                                </button>
                            </div>
                            <div class="swipe-card-content mobile-data-card" data-id="${e._id}">
                                <div class="mobile-card-header">
                                    <div style="min-width: 0; flex: 1;">
                                        <div class="mobile-card-title">${b(e.student?.name||e.studentName||(e.notes&&!e.notes.startsWith("{")?e.notes:"Registered Student"))}</div>
                                        <div class="mobile-card-subtitle" style="display: flex; align-items: center; gap: 6px; flex-wrap: wrap; margin-top: 4px;">
                                            <a href="#" class="receipt-link" data-id="${e._id}" style="font-family: monospace; font-weight: 700; color: var(--color-primary);">${b(e.receiptNumber||"Receipt")}</a>
                                            <span>\u2022</span>
                                            <span>${b(q.phone(e.student?.phone)||"")}</span>
                                        </div>
                                    </div>
                                    ${t}
                                </div>

                                <div class="mobile-card-details">
                                    <div class="mobile-card-detail">
                                        <div class="mobile-card-detail-label">Amount</div>
                                        <div class="mobile-card-detail-value mobile-card-amount" style="color: #10b981; font-weight: 800;">\u20B9${Number(e.finalAmount||0).toLocaleString("en-IN")}</div>
                                    </div>
                                    <div class="mobile-card-detail">
                                        <div class="mobile-card-detail-label">Method</div>
                                        <div class="mobile-card-detail-value" style="text-transform: uppercase;">${b(e.paymentMethod||"-")}</div>
                                    </div>
                                    <div class="mobile-card-detail">
                                        <div class="mobile-card-detail-label">Date</div>
                                        <div class="mobile-card-detail-value">${j(e.paymentDate)}</div>
                                    </div>
                                    ${e.balanceDue>0?`
                                    <div class="mobile-card-detail">
                                        <div class="mobile-card-detail-label">Balance Due</div>
                                        <div class="mobile-card-detail-value" style="color: var(--color-danger); font-weight: 700;">\u20B9${e.balanceDue}</div>
                                    </div>`:`
                                    <div class="mobile-card-detail">
                                        <div class="mobile-card-detail-label">Ref / UTR</div>
                                        <div class="mobile-card-detail-value" style="font-family: monospace; font-size: 0.8rem;">${b(e.transactionId||"-")}</div>
                                    </div>`}
                                </div>

                                <div class="mobile-card-actions" style="display: flex; gap: 6px; align-items: center;">
                                    <button type="button" class="btn btn-sm btn-outline-primary btn-view" data-id="${e._id}" style="min-height: 42px; flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: 4px; font-weight: 700;">
                                        \u{1F9FE} Receipt
                                    </button>
                                    <button type="button" class="btn btn-sm btn-outline-success btn-wa-bill" data-id="${e._id}" style="min-height: 42px; flex: 1; display: inline-flex; align-items: center; justify-content: center; gap: 4px; font-weight: 700;">
                                        \u{1F4AC} WhatsApp
                                    </button>
                                    ${e.status==="pending_verification"?`
                                    <button type="button" class="btn btn-sm btn-success btn-verify-utr" data-id="${e._id}" data-utr="${b(e.transactionId||"")}" data-receipt="${b(e.receiptNumber||"")}" style="min-height: 42px; flex: 1; font-weight: 700;">
                                        \u2705 Verify
                                    </button>
                                    `:""}
                                    ${typeof ActionMenu<"u"?ActionMenu.renderHtml([{header:"Level 1: Verification & Receipts"},{id:"view-receipt",icon:"\u{1F9FE}",label:"View / Print POS Receipt",bold:!0},{id:"wa-receipt",icon:"\u{1F4F2}",label:"WhatsApp Receipt Alert"},...e.status==="pending_verification"?[{id:"quick-verify",icon:"\u2705",label:"Approve & Verify UTR",bold:!0},{id:"quick-reject",icon:"\u274C",label:"Reject UTR Submission",danger:!0}]:[],{divider:!0},{header:"Level 2: Financial Governance"},{id:"toggle-status",icon:e.status==="paid"?"\u23F3":"\u2705",label:e.status==="paid"?"Mark as Pending":"Mark as Paid"},{divider:!0},{header:"Level 3: Danger Zone"},{id:"delete",icon:"\u{1F5D1}\uFE0F",label:"Delete Payment Record",danger:!0}],e._id):""}
                                </div>
                            </div>
                        </div>
                    `}).join(""),ae(o))),[i,o].filter(Boolean).forEach(e=>{e.querySelectorAll(".btn-copy-tx").forEach(t=>{t.addEventListener("click",r=>{r.stopPropagation();const n=t.dataset.copy;n&&Y(n,t)})}),e.querySelectorAll(".btn-edit-tx").forEach(t=>{t.addEventListener("click",r=>{r.stopPropagation();const n=t.dataset.id,s=e.querySelector(`.receipt-link[data-id="${n}"]`);s&&s.click()})}),e.querySelectorAll(".btn-share-tx").forEach(t=>{t.addEventListener("click",r=>{r.stopPropagation();const n=t.dataset.id,s=a.find(l=>l._id===n);s&&sendWhatsAppBill(s)})}),e.querySelectorAll(".btn-delete-tx").forEach(t=>{t.addEventListener("click",r=>{r.stopPropagation();const n=t.dataset.id;deleteSinglePayment(n)})}),e.querySelectorAll(".action-menu-item").forEach(t=>{t.addEventListener("click",async r=>{r.preventDefault(),r.stopPropagation();const n=t.dataset.action,s=t.dataset.id,l=a.find(d=>d._id===s);if(l){if(n==="view-receipt")z(s);else if(n==="wa-receipt"){const d=(l.student?.phone||l.phone||"").replace(/\D/g,"");if(!d){c.error("No student phone number linked");return}const m=d.length===10?"91"+d:d,y=`Dear ${l.student?.name||"Student"}, your payment of \u20B9${l.finalAmount||l.amount} (Receipt: ${l.receiptNumber||"N/A"}) has been successfully received. Thank you!`;window.open(`https://wa.me/${m}?text=${encodeURIComponent(y)}`,"_blank")}else if(n==="quick-verify")await Z(s,l.transactionId,l.receiptNumber);else if(n==="quick-reject")await J(s,l.receiptNumber);else if(n==="delete"){if(await G.show({title:"Delete Payment Record",message:`Permanently delete invoice ${l.receiptNumber||s}?`,danger:!0}))try{await k.delete(`/api/payments/${s}`),c.success("Payment record deleted"),await B.clear("payments"),L(),R()}catch(d){c.error(d.message||"Delete failed")}}else if(n==="toggle-status"){const d=l.status==="paid"?"pending":"paid";try{await k.put(`/api/payments/${s}`,{status:d}),c.success(`Payment marked as ${d}`),await B.clear("payments"),L(),R()}catch(m){c.error(m.message||"Status update failed")}}}})}),e.querySelectorAll(".btn-verify-utr").forEach(t=>{t.addEventListener("click",async r=>{r.preventDefault(),r.stopPropagation();const n=t.dataset.id,s=t.dataset.utr,l=t.dataset.receipt;await Z(n,s,l)})}),e.querySelectorAll(".btn-reject-utr").forEach(t=>{t.addEventListener("click",async r=>{r.preventDefault(),r.stopPropagation();const n=t.dataset.id,s=t.dataset.receipt;await J(n,s)})}),e.querySelectorAll(".btn-copy-text").forEach(t=>{t.addEventListener("click",r=>{r.preventDefault(),r.stopPropagation();const n=t.getAttribute("data-copy");n&&Y(n,t)})}),e.querySelectorAll(".receipt-link, .btn-view").forEach(t=>{t.addEventListener("click",r=>{r.preventDefault(),z(t.dataset.id)})}),e.querySelectorAll(".btn-wa-bill").forEach(t=>{t.addEventListener("click",r=>{r.preventDefault(),r.stopPropagation();const n=a.find(m=>m._id===t.dataset.id);if(!n)return;const s=(n.student?.phone||n.phone||"").replace(/\D/g,"");if(!s){c.error("No student phone number linked");return}const l=s.length===10?"91"+s:s,d=`Dear ${n.student?.name||"Student"}, your payment of \u20B9${n.finalAmount||n.amount} (Receipt: ${n.receiptNumber||"N/A"}) has been recorded. Thank you!`;window.open(`https://wa.me/${l}?text=${encodeURIComponent(d)}`,"_blank")})}),e.querySelectorAll(".btn-toggle-payment-status").forEach(t=>{t.addEventListener("click",r=>{r.preventDefault();const n=t.dataset.id,s=t.dataset.status||"paid",l=s==="paid"?"pending":"paid";te.execute({applyState:()=>{t.dataset.status=l,t.textContent=l,t.style.cssText=l==="paid"?"background: rgba(0, 184, 148, 0.2); color: var(--color-success); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;":"background: rgba(214, 48, 49, 0.2); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;"},rollbackState:()=>{t.dataset.status=s,t.textContent=s,t.style.cssText=s==="paid"?"background: rgba(0, 184, 148, 0.2); color: var(--color-success); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;":"background: rgba(214, 48, 49, 0.2); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;"},apiCall:()=>k.put(`/api/payments/${n}`,{status:l}),onSuccess:async d=>{c.success(d?.message||`Payment status changed to ${l}`),await B.clear("payments"),R()}})})}),e.querySelectorAll(".btn-pay-balance").forEach(t=>{t.addEventListener("click",r=>{r.preventDefault(),se(t.dataset.id,t.dataset.balance)})})}),i.querySelectorAll(".btn-remind-balance").forEach(e=>{e.addEventListener("click",async t=>{t.preventDefault();const r=e.dataset.id,n=e.dataset.studentId,s=e.dataset.name,l=e.dataset.balance;try{P.show("Preparing WhatsApp balance reminder & UPI link...");const d=await k.post("/api/messages/send-reminder",{studentId:n,paymentId:r,reminderType:"balance_due"});if(P.hide(),d.success&&d.data){const m=d.data.whatsappUrl||d.data.waUrl;m&&(/Android|iPhone|iPad|iPod/i.test(navigator.userAgent)?window.location.href=m:window.open(m,"_blank")||(window.location.href=m)),c.success(`WhatsApp reminder opened for ${s}!`)}else c.error(d.message||"Failed to send WhatsApp reminder")}catch(d){P.hide(),c.error(d.message||"Error sending WhatsApp reminder")}})})}async function L(){const a=document.getElementById("filterMethod")?.value||"",i=document.getElementById("filterStatus")?.value||"";let o="/api/payments?limit=20";a&&(o+=`&method=${a}`),i&&(o+=`&status=${i}`);const e=`list_${a}_${i}`,t=document.getElementById("paymentsTableBody");if(!t)return;let r=!1;try{const n=await B.get("payments",e);n&&Array.isArray(n)&&(V(n,t),r=!0)}catch(n){console.warn("IDB read payments list warning:",n)}r||P.skeleton(t,"table");try{const n=await k.get(o);if(!n.success||!n.data.payments){r||(t.innerHTML='<tr><td colspan="7" class="text-center empty-state p-4 text-muted">No payments found. Click "Collect Fee Payment" to record one.</td></tr>');return}await B.set("payments",e,n.data.payments),V(n.data.payments,t)}catch(n){console.error("Error loading payments",n),r||(t.innerHTML='<tr><td colspan="7" class="text-center empty-state p-4 text-muted">Error loading payments list.</td></tr>')}}async function K(){const a=document.getElementById("duesTableBody");a&&P.skeleton(a,"table");try{const i=await k.get("/api/payments/dues");if(!a)return;const o=document.getElementById("duesMobileCardList");if(!i.success||!i.data||i.data.length===0){H.emptyState(a,{icon:"\u{1F389}",title:"All Memberships Up To Date",description:"Great news! There are currently no expired memberships or overdue fee balances."}),o&&(o.innerHTML='<div class="text-center p-4 text-muted">\u{1F389} All memberships are up to date!</div>');return}a.innerHTML=i.data.map(e=>`
                <tr>
                    <td><strong>${b(e.name)}</strong></td>
                    <td>${b(q.phone(e.phone))} <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${b(e.phone||"")}" style="padding: 1px 4px; font-size: 0.7rem;" title="Copy Phone">\u{1F4CB}</button></td>
                    <td><span class="badge" style="background: rgba(108, 92, 231, 0.15); color: var(--color-primary);">${b(e.plan?.name||"-")}</span></td>
                    <td><span style="color: var(--color-danger); font-weight: 600;">${j(e.expiryDate)} <small class="text-muted">(${q.timeAgo(e.expiryDate)})</small></span></td>
                    <td>
                        <button class="btn btn-sm btn-success btn-collect-due" data-id="${e._id}" style="padding: 3px 8px; font-size: 0.8rem;">Collect Fee</button>
                        <button class="btn btn-sm btn-outline-success btn-remind-due" data-id="${e._id}" data-name="${b(e.name)}" style="padding: 3px 8px; font-size: 0.8rem; margin-left: 4px; white-space: nowrap;" title="Send WhatsApp Renewal Reminder with 1-Tap UPI Link">\u{1F4F2} WhatsApp Reminder</button>
                    </td>
                </tr>
            `).join(""),o&&(o.innerHTML=i.data.map(e=>`
                    <div class="swipe-item-container">
                        <div class="swipe-actions-revealed">
                            <button type="button" class="swipe-btn swipe-btn-whatsapp btn-remind-due" data-id="${e._id}" data-name="${b(e.name)}" title="WhatsApp" onclick="event.stopPropagation()">
                                <span style="font-size: 1.25rem;">\u{1F4AC}</span>
                                <span>Remind</span>
                            </button>
                            <button type="button" class="swipe-btn swipe-btn-edit btn-collect-due" data-id="${e._id}" title="Collect Fee" onclick="event.stopPropagation()">
                                <span style="font-size: 1.25rem;">\u{1F4B0}</span>
                                <span>Collect</span>
                            </button>
                        </div>
                        <div class="swipe-card-content mobile-data-card" data-id="${e._id}">
                            <div class="mobile-card-header">
                                <div style="min-width: 0; flex: 1;">
                                    <div class="mobile-card-title">${b(e.name)}</div>
                                    <div class="mobile-card-subtitle" style="display: flex; align-items: center; gap: 6px; margin-top: 4px;">
                                        <span>${b(q.phone(e.phone))}</span>
                                        <button type="button" class="btn btn-xs btn-outline-secondary btn-copy-text" data-copy="${b(e.phone||"")}" style="padding: 2px 6px;" title="Copy Phone">\u{1F4CB}</button>
                                    </div>
                                </div>
                                <span class="mobile-card-badge badge-expired">Expired</span>
                            </div>
                            <div class="mobile-card-details">
                                <div class="mobile-card-detail">
                                    <div class="mobile-card-detail-label">Plan</div>
                                    <div class="mobile-card-detail-value" style="color: var(--color-primary);">${b(e.plan?.name||"-")}</div>
                                </div>
                                <div class="mobile-card-detail">
                                    <div class="mobile-card-detail-label">Expired On</div>
                                    <div class="mobile-card-detail-value" style="color: var(--color-danger); font-weight: 700;">${j(e.expiryDate)}</div>
                                </div>
                            </div>
                            <div class="mobile-card-actions">
                                <button class="btn btn-sm btn-success btn-collect-due" data-id="${e._id}" style="min-height: 42px; flex: 1; font-weight: 700;">Collect Fee</button>
                                <button class="btn btn-sm btn-outline-success btn-remind-due" data-id="${e._id}" data-name="${b(e.name)}" style="min-height: 42px; flex: 1; font-weight: 700;">\u{1F4F2} WhatsApp</button>
                            </div>
                        </div>
                    </div>
                `).join(""),ae(o)),[a,o].filter(Boolean).forEach(e=>{e.querySelectorAll(".btn-copy-text").forEach(t=>{t.addEventListener("click",r=>{r.preventDefault(),r.stopPropagation();const n=t.getAttribute("data-copy");n&&Y(n,t)})}),e.querySelectorAll(".btn-collect-due").forEach(t=>{t.addEventListener("click",()=>{W(t.dataset.id)})}),e.querySelectorAll(".btn-remind-due").forEach(t=>{t.addEventListener("click",async r=>{r.preventDefault();const n=t.dataset.id,s=t.dataset.name;try{P.show("Preparing WhatsApp reminder & UPI link...");const l=await k.post("/api/messages/send-reminder",{studentId:n,reminderType:"renewal_reminder"});if(P.hide(),l.success&&l.data){const d=l.data.whatsappUrl||l.data.waUrl;d&&(/Android|iPhone|iPad|iPod/i.test(navigator.userAgent)?window.location.href=d:window.open(d,"_blank")||(window.location.href=d)),c.success(`WhatsApp reminder opened for ${s||l.data.studentName}!`)}else c.error(l.message||"Failed to dispatch reminder")}catch(l){P.hide(),c.error(l.message||"WhatsApp dispatch error")}})})})}catch(i){console.error("Error loading dues",i)}}async function ue(){try{P.show("Calculating daily cash register summary...");const a=await k.get("/api/payments/cash-register/summary");if(P.hide(),!a.success){c.error(a.message||"Failed to fetch cash register summary");return}const i=a.data||{},o=i.openingCash||0,e=i.totalCashCollected||0,t=i.totalCashExpenses||0,r=i.expectedClosingCash||0,n=`
                <div style="padding: 6px 0;">
                    <!-- Financial Overview Cards -->
                    <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(140px, 1fr)); gap: 10px; margin-bottom: 14px;">
                        <div class="p-2 border rounded text-center" style="background: var(--color-bg-secondary);">
                            <small class="text-muted d-block" style="font-size: 0.75rem; font-weight: 700;">\u{1F4E6} Opening Cash</small>
                            <strong style="font-size: 1.1rem; color: var(--color-text-primary);">\u20B9${o}</strong>
                        </div>
                        <div class="p-2 border rounded text-center" style="background: rgba(0, 184, 148, 0.08); border-color: rgba(0, 184, 148, 0.2) !important;">
                            <small class="text-success d-block" style="font-size: 0.75rem; font-weight: 700;">\u{1F4E5} Today's Cash Fees</small>
                            <strong style="font-size: 1.1rem; color: var(--color-success);">+\u20B9${e}</strong>
                            <small class="text-muted d-block" style="font-size: 0.7rem;">(${i.cashTransactionsCount||0} collections)</small>
                        </div>
                        <div class="p-2 border rounded text-center" style="background: rgba(214, 48, 49, 0.08); border-color: rgba(214, 48, 49, 0.2) !important;">
                            <small class="text-danger d-block" style="font-size: 0.75rem; font-weight: 700;">\u{1F4E4} Cash Expenses</small>
                            <strong style="font-size: 1.1rem; color: var(--color-danger);">-\u20B9${t}</strong>
                        </div>
                    </div>

                    <!-- Expected Closing Cash Banner -->
                    <div style="background: linear-gradient(135deg, rgba(108,92,231,0.12), rgba(0,184,148,0.12)); border: 1.5px solid var(--color-primary); border-radius: 8px; padding: 12px 16px; margin-bottom: 16px; display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <span style="font-weight: 800; font-size: 0.95rem; color: var(--color-primary);">Expected Cash in Drawer:</span>
                            <small class="text-muted d-block" style="font-size: 0.75rem;">(Opening \u20B9${o} + Cash In \u20B9${e} - Cash Out \u20B9${t})</small>
                        </div>
                        <span style="font-size: 1.4rem; font-weight: 800; color: var(--color-primary);" id="cr-expected-amount">\u20B9${r}</span>
                    </div>

                    <!-- Denominations Calculator -->
                    <div class="mb-3">
                        <label class="form-label" style="font-weight: 700; font-size: 0.85rem; display: flex; justify-content: space-between;">
                            <span>\u{1F9EE} Physical Cash Count & Denominations</span>
                            <span class="text-muted" style="font-size: 0.75rem;">Enter note quantities</span>
                        </label>
                        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 8px;">
                            ${[{val:500,id:"cr-d500"},{val:200,id:"cr-d200"},{val:100,id:"cr-d100"},{val:50,id:"cr-d50"},{val:20,id:"cr-d20"},{val:10,id:"cr-d10"}].map(l=>`
                                <div class="input-group input-group-sm">
                                    <span class="input-group-text font-monospace" style="width: 70px; font-weight: 700;">\u20B9${l.val} \xD7</span>
                                    <input type="number" min="0" class="form-control cr-denom-input text-center" id="${l.id}" data-val="${l.val}" placeholder="0">
                                </div>
                            `).join("")}
                        </div>
                        <div class="input-group input-group-sm mt-2">
                            <span class="input-group-text font-monospace" style="width: 140px; font-weight: 700;">\u{1FA99} Coins / Loose (\u20B9)</span>
                            <input type="number" min="0" class="form-control cr-denom-input" id="cr-coins" data-val="1" placeholder="0">
                        </div>
                    </div>

                    <!-- Counted Total vs Variance Result -->
                    <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 8px; padding: 12px; margin-bottom: 14px;">
                        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 6px;">
                            <span style="font-weight: 700; font-size: 0.9rem;">Total Physical Cash Counted:</span>
                            <strong style="font-size: 1.15rem;" id="cr-total-counted">\u20B90</strong>
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
            `;U.show({title:"\u{1F4B5} Daily Cash Register Handover & Day-End Settlement",content:n,confirmText:"\u2705 Settle & Close Shift Register",onConfirm:async()=>{const l=Number(document.getElementById("cr-d500")?.value)||0,d=Number(document.getElementById("cr-d200")?.value)||0,m=Number(document.getElementById("cr-d100")?.value)||0,y=Number(document.getElementById("cr-d50")?.value)||0,F=Number(document.getElementById("cr-d20")?.value)||0,E=Number(document.getElementById("cr-d10")?.value)||0,h=Number(document.getElementById("cr-coins")?.value)||0,g=l*500+d*200+m*100+y*50+F*20+E*10+h,C=document.getElementById("cr-handover-to")?.value?.trim(),x=document.getElementById("cr-notes")?.value?.trim();try{P.show("Saving shift handover settlement...");const v=await k.post("/api/payments/cash-register/settle",{openingCash:o,cashCollected:e,cashExpenses:t,expectedClosingCash:r,actualPhysicalCash:g,denominations:{d500:l,d200:d,d100:m,d50:y,d20:F,d10:E,coins:h},handoverTo:C,notes:x});P.hide(),v.success?(c.success(v.message||"Cash register settled successfully"),U.close(),R()):c.error(v.message||"Settlement failed")}catch(v){P.hide(),c.error(v.message||"Error settling cash register")}}});const s=()=>{const l=Number(document.getElementById("cr-d500")?.value)||0,d=Number(document.getElementById("cr-d200")?.value)||0,m=Number(document.getElementById("cr-d100")?.value)||0,y=Number(document.getElementById("cr-d50")?.value)||0,F=Number(document.getElementById("cr-d20")?.value)||0,E=Number(document.getElementById("cr-d10")?.value)||0,h=Number(document.getElementById("cr-coins")?.value)||0,g=l*500+d*200+m*100+y*50+F*20+E*10+h,C=g-r,x=document.getElementById("cr-total-counted");x&&(x.textContent=`\u20B9${g}`);const v=document.getElementById("cr-variance-badge");v&&(g===0?(v.textContent="Enter Count",v.style.background="rgba(255,255,255,0.08)",v.style.color="var(--color-text-secondary)"):C===0?(v.textContent="\u2705 Reconciled (\u20B90 Variance)",v.style.background="rgba(0,184,148,0.2)",v.style.color="var(--color-success)"):C>0?(v.textContent=`\u2728 Surplus (+\u20B9${C})`,v.style.background="rgba(59,130,246,0.2)",v.style.color="var(--color-primary)"):(v.textContent=`\u26A0\uFE0F Deficit / Short (-\u20B9${Math.abs(C)})`,v.style.background="rgba(214,48,49,0.2)",v.style.color="var(--color-danger)"))};document.querySelectorAll(".cr-denom-input").forEach(l=>{l.addEventListener("input",s)})}catch(a){P.hide(),c.error(a.message||"Error opening cash register handover")}}let _=null;async function ne(){if(_)return Promise.all([k.get("/api/plans").catch(()=>null),k.get("/api/students?limit=100&status=active").catch(()=>null)]).then(([a,i])=>{a?.data&&(_.plans=a.data),i?.data?.students&&(_.students=i.data.students)}).catch(()=>{}),_;try{const[a,i]=await Promise.all([k.get("/api/plans").catch(()=>({data:[]})),k.get("/api/students?limit=100&status=active").catch(()=>({data:{students:[]}}))]);return _={plans:a?.data||[],students:i?.data?.students||[]},_}catch{return{plans:[],students:[]}}}async function W(a=null){const i=await ne(),o=Array.isArray(i.plans)?i.plans:[],e=Array.isArray(i.students)?i.students:[];let t='<option value="">-- Select Plan --</option>';o.forEach(u=>{const w=Number(u.price)||0,T=Number(u.discount)||0,S=Math.round(w*(T/100)),D=Math.round(u.effectivePrice!==void 0?u.effectivePrice:w-S),le=T>0?` [${T}% OFF, was \u20B9${w.toLocaleString("en-IN")}]`:"";t+=`<option value="${u._id}" data-price="${w}" data-discount-pct="${T}" data-discount-amt="${S}" data-effective="${D}">${b(u.name)} - \u20B9${D.toLocaleString("en-IN")} (${u.duration} ${u.durationType})${le}</option>`});let r='<option value="">-- Select Student --</option>',n=null;e.forEach(u=>{const w=a&&u._id===a;w&&(n=u),r+=`<option value="${u._id}" ${w?"selected":""}>${b(u.name)} (${b(u.studentId||"")} - ${b(u.phone||"")})</option>`});const s=document.createElement("div");s.innerHTML=`
            <form id="paymentForm">
                <div class="row" style="row-gap: 14px;">
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Select Student *</label>
                        <select id="studentSelect" name="student" class="form-select form-control" required>
                            ${r}
                        </select>
                    </div>
                    
                    <div class="col-md-6">
                        <label class="form-label" style="font-weight: 500;">Membership Plan</label>
                        <select name="plan" id="planSelect" class="form-select form-control">
                            ${t}
                        </select>
                    </div>
                    <div class="col-md-6">
                        <label class="form-label" style="font-weight: 500;">Payment Method *</label>
                        <select name="paymentMethod" id="payMethodSelect" class="form-select form-control" required>
                            <option value="cash">\u{1F4B5} Cash at Reception Desk</option>
                            <option value="upi" selected>\u26A1 UPI (GPay / PhonePe / Paytm / BHIM)</option>
                            <option value="bank_transfer">\u{1F3DB}\uFE0F Bank Transfer (NEFT / IMPS / RTGS)</option>
                            <option value="card">\u{1F4B3} Debit / Credit Card (POS Terminal)</option>
                            <option value="desk">\u{1F4B5} Pay Later at Front Desk</option>
                            <option value="netbanking">\u{1F3E6} NetBanking / Online Transfer</option>
                        </select>
                    </div>

                    <div class="col-12" id="payMethodContext"></div>
                    
                    <div class="col-md-4">
                        <label class="form-label" style="font-weight: 500;">Amount (\u20B9) *</label>
                        <input type="number" name="amount" id="payAmount" class="form-control calc-field" required min="0" value="0">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label" style="font-weight: 500;">Discount (\u20B9)</label>
                        <input type="number" name="discount" id="payDiscount" class="form-control calc-field" value="0" min="0">
                    </div>
                    <div class="col-md-4">
                        <label class="form-label" style="font-weight: 500;">Late Fee (\u20B9)</label>
                        <input type="number" name="lateFee" id="payLateFee" class="form-control calc-field" value="0" min="0">
                    </div>
                    
                    <div class="col-12 p-3" style="background: var(--color-bg-secondary, rgba(255,255,255,0.05)); border-radius: 8px; display: flex; justify-content: space-between; align-items: center;">
                        <span style="font-weight: 600;">Net Payable Amount:</span>
                        <h4 id="finalAmountDisplay" style="margin: 0; color: var(--color-success, #00b894); font-size: 1.4rem; font-weight: 700;">\u20B90</h4>
                    </div>
                    
                    <div class="col-md-6" id="payTxnWrapper">
                        <label class="form-label" id="payTxnLabel" style="font-weight: 500;">\u26A1 UPI / 12-Digit UTR Transaction ID</label>
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
        `;const l=new U({title:"Collect Fee Payment",content:s,size:"md"});l.show();const d=s.querySelector("#paymentForm"),m=s.querySelector("#planSelect"),y=s.querySelector("#payAmount"),F=s.querySelector("#payDiscount"),E=s.querySelector("#payLateFee"),h=s.querySelector("#finalAmountDisplay"),g=s.querySelector("#studentSelect"),C=s.querySelector("#payMethodSelect"),x=s.querySelector("#payMethodContext"),v=s.querySelector("#payTxnLabel"),I=s.querySelector("#payTransactionId"),$=s.querySelector("#utrWarnMsg"),ee=()=>{const u=C?.value||"upi",w=parseFloat(y?.value)||0,T=parseFloat(F?.value)||0,S=parseFloat(E?.value)||0,D=Math.max(0,w-T+S);u==="cash"||u==="desk"?(v&&(v.innerHTML="\u{1F4B5} Cash / Front Desk Note (Optional)"),I&&(I.placeholder="e.g. Received at reception desk"),x&&(x.innerHTML=`
                        <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>\u{1F4B5}</span>
                            <span><strong>Desk / Cash Payment:</strong> Official receipt generation. No online reference ID required.</span>
                        </div>
                    `),$&&($.style.display="none")):u==="bank_transfer"||u==="netbanking"?(v&&(v.innerHTML="\u{1F3DB}\uFE0F Bank NEFT / IMPS / RTGS UTR Number *"),I&&(I.placeholder="e.g. Bank Ref # / IMPS Transaction Reference"),x&&(x.innerHTML=A.renderBankDetailsWidget(),A.attachEventListeners(x)),$&&($.style.display="none")):u==="card"?(v&&(v.innerHTML="\u{1F4B3} POS Slip Code / Card Last 4 Digits"),I&&(I.placeholder="e.g. POS Auth Code #8492 or Card Ending 4321"),x&&(x.innerHTML=`
                        <div style="background: rgba(225, 112, 85, 0.1); border: 1px solid #e17055; border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>\u{1F4B3}</span>
                            <span><strong>Card Swipe / Terminal:</strong> Credit or Debit card processed on POS machine.</span>
                        </div>
                    `),$&&($.style.display="none")):(v&&(v.innerHTML="\u26A1 UPI / 12-Digit UTR Transaction ID *"),I&&(I.placeholder="e.g. 12-digit UTR (e.g. 423456789012)"),x&&(x.innerHTML=A.renderUPIWidget({amount:D,note:"Library Fee Payment",showUtrInput:!1,mountId:"collect-pay-upi-qr-mount"}),A.attachEventListeners(x)))};C&&(C.addEventListener("change",ee),ee());const O=()=>{const u=parseFloat(y.value)||0,w=parseFloat(F.value)||0,T=parseFloat(E.value)||0,S=Math.max(0,u-w+T);h.textContent=N(S),C?.value==="upi"&&x&&(x.innerHTML=A.renderUPIWidget({amount:S,note:"Library Fee Payment",showUtrInput:!1,mountId:"collect-pay-upi-qr-mount"}),A.attachEventListeners(x))};if([y,F,E].forEach(u=>{u.addEventListener("input",O)}),m.addEventListener("change",()=>{const u=m.options[m.selectedIndex];u&&u.dataset.price&&(y.value=u.dataset.price,F.value=u.dataset.discountAmt||0,O())}),n&&n.plan){const u=n.plan._id||n.plan;m.value=u;const w=m.options[m.selectedIndex];w&&w.dataset.price&&(y.value=w.dataset.price,F.value=w.dataset.discountAmt||0,O())}const re=async()=>{if((C?.value||"upi")!=="upi")return $&&($.style.display="none"),!0;const u=I?.value?.trim()||"";if(!u||!$)return $&&($.style.display="none"),!0;/^\d+$/.test(u)&&u.length!==12?($.textContent=`\u2139\uFE0F UPI UTR is usually 12 digits (currently ${u.length} digits)`,$.style.color="var(--color-warning, #f59e0b)",$.style.display="block"):$.style.display="none";try{const w=await B.get("payments","list__")||[];if(Array.isArray(w)&&w.some(T=>T.transactionId&&T.transactionId.trim().toLowerCase()===u.toLowerCase()))return $.textContent=`\u26A0\uFE0F Warning: Transaction Ref ID "${u}" has already been recorded!`,$.style.color="var(--color-danger, #d63031)",$.style.display="block",!1}catch{}return!0};I&&["input","blur","change"].forEach(u=>I.addEventListener(u,re)),d.addEventListener("submit",async u=>{u.preventDefault();const w=d.querySelector('button[type="submit"]'),T=new FormData(d),S=Object.fromEntries(T.entries());if(!S.student){c.error("Please select a student");return}if(S.plan||delete S.plan,S.amount=parseFloat(S.amount)||0,S.discount=parseFloat(S.discount)||0,S.lateFee=parseFloat(S.lateFee)||0,S.amount<=0){c.error("Payment amount must be greater than 0");return}if(S.discount>S.amount){c.error("Discount amount cannot exceed the payment amount");return}w&&H.buttonLoading(w,!0,"Processing...");try{const D=await k.post("/api/payments",S);D.success?(l.hide(),c.success("Payment collected successfully!"),typeof window.confettiCelebrate=="function"&&window.confettiCelebrate({duration:1800,colors:["#00b894","#00cec9","#55efc4","#6c5ce7","#fdcb6e"]}),typeof window.refreshNotifications=="function"&&window.refreshNotifications(),await B.clear("payments"),R(),L(),K(),D.data?._id&&z(D.data._id)):c.error(D.message||"Failed to collect payment")}catch(D){c.error(D.message||"An error occurred while saving payment")}finally{w&&H.buttonLoading(w,!1)}})}async function se(a,i){const o=document.createElement("div");o.innerHTML=`
            <form id="payBalanceForm">
                <div class="row" style="row-gap: 14px;">
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Balance Due (\u20B9)</label>
                        <input type="number" class="form-control" value="${i}" readonly>
                    </div>
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Amount to Pay (\u20B9) *</label>
                        <input type="number" name="amount" class="form-control" max="${i}" min="1" required value="${i}">
                    </div>
                    <div class="col-12">
                        <label class="form-label" style="font-weight: 500;">Payment Method *</label>
                        <select name="method" id="balancePayMethodSelect" class="form-select form-control" required>
                            <option value="cash">\u{1F4B5} Cash at Reception Desk</option>
                            <option value="upi" selected>\u26A1 UPI (GPay / PhonePe / Paytm / BHIM)</option>
                            <option value="bank_transfer">\u{1F3DB}\uFE0F Bank Transfer (NEFT / IMPS / RTGS)</option>
                            <option value="card">\u{1F4B3} Debit / Credit Card (POS Terminal)</option>
                        </select>
                    </div>
                    <div class="col-12" id="balancePayMethodContext"></div>
                    <div class="col-12">
                        <label class="form-label" id="balancePayTxnLabel" style="font-weight: 500;">\u26A1 UPI / 12-Digit UTR Transaction ID</label>
                        <input type="text" name="transactionId" id="balancePayTxnInput" class="form-control" placeholder="e.g. 12-digit UTR (e.g. 423456789012)">
                    </div>
                    <div class="col-12 text-end mt-3 d-flex justify-content-end gap-2">
                        <button type="button" class="btn btn-secondary modal-close-btn" onclick="Modal.close()">Cancel</button>
                        <button type="submit" class="btn btn-primary">Pay Installment</button>
                    </div>
                </div>
            </form>
        `;const e=new U({title:"Pay Balance Installment",content:o,size:"md"});e.show();const t=o.querySelector("#balancePayMethodSelect"),r=o.querySelector("#balancePayMethodContext"),n=o.querySelector("#balancePayTxnLabel"),s=o.querySelector("#balancePayTxnInput"),l=o.querySelector('input[name="amount"]'),d=()=>{const y=t?.value||"upi",F=parseFloat(l?.value)||parseFloat(i)||0;y==="cash"?(n&&(n.innerHTML="\u{1F4B5} Cash Collector Note (Optional)"),s&&(s.placeholder="e.g. Cash received at reception desk"),r&&(r.innerHTML=`
                        <div style="background: rgba(0, 184, 148, 0.1); border: 1px solid var(--color-success, #00b894); border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>\u{1F4B5}</span>
                            <span><strong>Cash Payment:</strong> Instant installment receipt generated.</span>
                        </div>
                    `)):y==="bank_transfer"?(n&&(n.innerHTML="\u{1F3DB}\uFE0F Bank NEFT / IMPS Reference Number"),s&&(s.placeholder="e.g. Bank Ref # / IMPS Transaction Reference"),r&&(r.innerHTML=A.renderBankDetailsWidget(),A.attachEventListeners(r))):y==="card"?(n&&(n.innerHTML="\u{1F4B3} POS Slip Code / Card Last 4 Digits"),s&&(s.placeholder="e.g. POS Auth Code #8492 or Card Ending 4321"),r&&(r.innerHTML=`
                        <div style="background: rgba(225, 112, 85, 0.1); border: 1px solid #e17055; border-radius: 8px; padding: 10px 14px; font-size: 0.82rem; color: var(--color-text-primary); display: flex; align-items: center; gap: 8px;">
                            <span>\u{1F4B3}</span>
                            <span><strong>Card Swipe:</strong> Processed on POS terminal.</span>
                        </div>
                    `)):(n&&(n.innerHTML="\u26A1 UPI / 12-Digit UTR Transaction ID *"),s&&(s.placeholder="e.g. 12-digit UTR (e.g. 423456789012)"),r&&(r.innerHTML=A.renderUPIWidget({amount:F,note:"Balance Due Payment",showUtrInput:!1,mountId:"balance-pay-upi-qr-mount"}),A.attachEventListeners(r)))};t&&(t.addEventListener("change",d),d()),l?.addEventListener("input",()=>{if(t?.value==="upi"&&r){const y=parseFloat(l.value)||0;r.innerHTML=A.renderUPIWidget({amount:y,note:"Balance Due Payment",showUtrInput:!1,mountId:"balance-pay-upi-qr-mount"}),A.attachEventListeners(r)}});const m=o.querySelector("#payBalanceForm");m.addEventListener("submit",async y=>{y.preventDefault();const F=new FormData(m),E=Object.fromEntries(F.entries());E.amount=parseFloat(E.amount)||0;try{await te.execute({applyState:()=>{e.hide();const h=document.querySelector(`.receipt-link[data-id="${a}"]`)?.closest("tr");if(h){const g=h.querySelector(".badge.btn-toggle-payment-status");g&&(g.textContent="paid",g.style.cssText="background: rgba(0, 184, 148, 0.2); color: var(--color-success); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;")}},rollbackState:()=>{const h=document.querySelector(`.receipt-link[data-id="${a}"]`)?.closest("tr");if(h){const g=h.querySelector(".badge.btn-toggle-payment-status");g&&(g.textContent="partial",g.style.cssText="background: rgba(214, 48, 49, 0.2); color: var(--color-danger); padding: 4px 8px; border-radius: 4px; font-weight: 600; cursor: pointer;")}},apiCall:()=>k.post(`/api/payments/${a}/pay-balance`,E),onSuccess:async h=>{c.success("Installment paid successfully!"),await B.clear("payments"),R(),L(),z(a)}})}catch{}})}async function z(a){const i=document.createElement("div");i.innerHTML=`
            <div class="text-center p-4 text-muted">
                <div class="loading-spinner mb-2" style="margin: 0 auto; width: 32px; height: 32px;"></div>
                <div style="font-weight: 600; font-size: 0.95rem;">Preparing digital fee receipt...</div>
            </div>
        `;const o=U.show({title:"Fee Payment Receipt",content:i,size:"md"});try{const e=window.store?.settings?.receipt||{header:{},body:{},gst:{},footer:{}},t=window.store?.settings?.businessProfile||JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")||{},r=await k.get(`/api/payments/${a}`);if(!r||!r.data)throw new Error("Payment data not found");const n=r.data;let s=e.activeTemplate||"thermal80";const l=document.createElement("div");l.innerHTML=`
                <div class="d-flex justify-content-between align-items-center mb-3 flex-wrap gap-2">
                    <div class="d-flex align-items-center gap-2">
                        <label class="form-label mb-0 small" style="font-weight: 600;">Format:</label>
                        <select id="receipt-paper-format" class="form-select form-select-sm" style="width: 170px; padding: 4px 8px; font-size: 0.85rem;">
                            <option value="thermal80" ${s==="thermal80"||s==="thermal_80"?"selected":""}>\u{1F9FE} 80mm POS Thermal</option>
                            <option value="thermal58" ${s==="thermal58"||s==="thermal_58"?"selected":""}>\u{1F9FE} 58mm Mini POS</option>
                            <option value="standardA4" ${s==="standardA4"||s==="standard_a4"||s==="gst_invoice"?"selected":""}>\u{1F4C4} Standard A4 Invoice</option>
                            <option value="modern_minimal" ${s==="modern_minimal"?"selected":""}>\u2728 Modern Digital Pass</option>
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
                        \u{1F4F2} WhatsApp
                    </button>
                    <button class="btn btn-primary" id="btn-print-receipt-action">\u{1F5A8}\uFE0F Print Receipt</button>
                    <button class="btn btn-secondary modal-close-btn" onclick="Modal.close()">Close</button>
                </div>
            `;const d=l.querySelector("#receipt-container-box"),m=h=>{s=h;const g=de(n,{receiptConfig:e,businessProfile:t,template:h});d.innerHTML=g};i.innerHTML="",i.appendChild(l),m(s);const y=l.querySelector("#receipt-paper-format");y?.addEventListener("change",()=>{const h=y.value;m(h),l.querySelectorAll("[data-template]").forEach(g=>{g.dataset.template===h?(g.classList.remove("btn-outline-primary"),g.classList.add("active","btn-primary")):(g.classList.remove("active","btn-primary"),g.classList.add("btn-outline-primary"))})});const F=l.querySelectorAll("[data-template]");F.forEach(h=>{h.addEventListener("click",g=>{const C=g.target.dataset.template;F.forEach(x=>x.classList.remove("active","btn-primary")),F.forEach(x=>x.classList.add("btn-outline-primary")),g.target.classList.remove("btn-outline-primary"),g.target.classList.add("active","btn-primary"),y&&(y.value=C),m(C)})});const E=l.querySelector(`[data-template="${s}"]`);E&&(E.classList.remove("btn-outline-primary"),E.classList.add("active","btn-primary")),l.querySelector("#btn-print-receipt-action")?.addEventListener("click",()=>{ce(n,{receiptConfig:e,businessProfile:t,template:s})}),l.querySelector("#btn-share-whatsapp-receipt")?.addEventListener("click",async()=>{try{const h=await k.post("/api/notifications/receipt-whatsapp-link",{paymentId:a});h.success&&h.data?.url?(window.open(h.data.url,"_blank"),c.success("Opening WhatsApp with formatted receipt...")):c.error("Could not generate WhatsApp link")}catch{c.error("Could not generate WhatsApp link")}})}catch(e){console.error("Error fetching receipt",e),c.error("An error occurred while loading receipt")}}const f=new Set;function M(){const a=p.querySelector("#payments-bulk-bar"),i=p.querySelector("#payments-bulk-count"),o=p.querySelector("#payments-check-all");if(!a)return;const e=f.size;if(e>0?a.style.display="flex":a.style.display="none",i&&(i.textContent=`${e} Selected`),p.querySelectorAll(".payment-row").forEach(t=>{const r=f.has(t.dataset.id);t.style.background=r?"rgba(108,92,231,0.1)":"",t.style.transition="background 0.15s ease";const n=t.querySelector(".payment-row-check");n&&(n.checked=r)}),o){const t=p.querySelectorAll(".payment-row-check").length;o.checked=e>0&&e===t,o.indeterminate=e>0&&e<t}}function ie(){p.querySelectorAll(".payment-row-check").forEach(a=>{a.addEventListener("change",()=>{const i=a.dataset.id;a.checked?f.add(i):f.delete(i),M()})}),p.querySelectorAll(".payment-row").forEach(a=>{a.addEventListener("click",i=>{if(i.target.closest("button, a, input, select"))return;const o=a.dataset.id;f.has(o)?f.delete(o):f.add(o),M()})})}const me=V,oe=new MutationObserver(()=>{ie()}),X=p.querySelector("#paymentsTableBody");return X&&oe.observe(X,{childList:!0}),p.querySelector("#payments-check-all")?.addEventListener("change",a=>{const i=a.target.checked;p.querySelectorAll(".payment-row-check").forEach(o=>{const e=o.dataset.id;i?f.add(e):f.delete(e)}),M()}),p.querySelector("#payments-toggle-select-all")?.addEventListener("click",()=>{const a=p.querySelectorAll(".payment-row-check"),i=a.length>0&&a.length===f.size;a.forEach(o=>{i?f.delete(o.dataset.id):f.add(o.dataset.id)}),M()}),p.querySelector("#payments-bulk-cancel")?.addEventListener("click",()=>{f.clear(),M()}),p.querySelector("#payments-bulk-mark-paid")?.addEventListener("click",async()=>{if(!f.size)return;const a=p.querySelector("#payments-bulk-mark-paid");a.disabled=!0,a.textContent="\u23F3 Updating\u2026";let i=0;for(const o of f)try{if((await k.put(`/api/payments/${o}/status`,{status:"paid"})).success){i++;const e=p.querySelector(`.payment-row[data-id="${o}"]`);if(e){const t=e.querySelector(".btn-toggle-payment-status");t&&(t.textContent="paid",t.dataset.status="paid",t.style.background="rgba(0,184,148,0.2)",t.style.color="var(--color-success)")}}}catch{}a.disabled=!1,a.textContent="\u2705 Mark Paid",c.success(`\u2705 ${i} payment(s) marked as Paid`),f.clear(),M()}),p.querySelector("#payments-bulk-mark-pending")?.addEventListener("click",async()=>{if(!f.size)return;const a=p.querySelector("#payments-bulk-mark-pending");a.disabled=!0,a.textContent="\u23F3 Updating\u2026";let i=0;for(const o of f)try{if((await k.put(`/api/payments/${o}/status`,{status:"pending"})).success){i++;const e=p.querySelector(`.payment-row[data-id="${o}"]`);if(e){const t=e.querySelector(".btn-toggle-payment-status");t&&(t.textContent="pending",t.dataset.status="pending",t.style.background="rgba(214,48,49,0.2)",t.style.color="var(--color-danger)")}}}catch{}a.disabled=!1,a.textContent="\u23F3 Mark Pending",c.success(`\u23F3 ${i} payment(s) marked as Pending`),f.clear(),M()}),p.querySelector("#payments-bulk-wa-remind")?.addEventListener("click",()=>{if(!f.size){c.warning("Select payments first");return}const a=Array.from(f).map(e=>p.querySelector(`.payment-row[data-id="${e}"]`)).filter(Boolean);if(!a.length)return;const i=window.store?.settings?.businessName||"The Cozy Corner Centre";let o=0;a.forEach((e,t)=>{const r=e.dataset.studentPhone,n=e.dataset.studentName||"Student",s=e.dataset.amount,l=e.dataset.receipt,d=e.dataset.status;if(!r)return;const m=r.replace(/[^0-9]/g,""),y=m.startsWith("91")?m:`91${m}`,F=d==="pending"||d==="partial"?`Hi ${n}! \u{1F64F} Your fee payment of \u20B9${s} (Receipt: ${l}) at *${i}* is pending. Please pay at your earliest. Thank you!`:`Hi ${n}! \u2705 Your payment of \u20B9${s} (Receipt: ${l}) at *${i}* has been received. Thank you for studying with us! \u{1F4DA}`;setTimeout(()=>{window.open(`https://wa.me/${y}?text=${encodeURIComponent(F)}`,"_blank"),o++},t*800)}),c.success(`\u{1F4F2} Opening WhatsApp for ${a.length} student(s)\u2026`)}),p.querySelector("#payments-bulk-export-csv")?.addEventListener("click",()=>{if(!f.size){c.warning("Select payments first");return}const a=Array.from(f).map(s=>p.querySelector(`.payment-row[data-id="${s}"]`)).filter(Boolean),i=["Receipt No","Student Name","Phone","Amount","Status"],o=a.map(s=>[`"${s.dataset.receipt}"`,`"${s.dataset.studentName}"`,`"${s.dataset.studentPhone}"`,`"${s.dataset.amount}"`,`"${s.dataset.status}"`].join(",")),e=[i.join(","),...o].join(`
`),t=new Blob([e],{type:"text/csv;charset=utf-8;"}),r=URL.createObjectURL(t),n=document.createElement("a");n.href=r,n.download=`payments_selected_${Date.now()}.csv`,n.click(),URL.revokeObjectURL(r),c.success(`\u{1F4E5} Exported ${a.length} payment(s) to CSV`)}),p.querySelector("#payments-bulk-delete")?.addEventListener("click",async()=>{if(!f.size)return;const a=f.size;if(!await G.show({title:`\u{1F5D1}\uFE0F Delete ${a} Payment(s)?`,message:`This will permanently delete ${a} selected payment record(s). This action cannot be undone.`,confirmText:`Delete ${a} Payments`,danger:!0}))return;const i=p.querySelector("#payments-bulk-delete");i.disabled=!0,i.textContent="\u23F3 Deleting\u2026";let o=0;for(const e of f)try{(await k.delete(`/api/payments/${e}`)).success&&(o++,p.querySelector(`.payment-row[data-id="${e}"]`)?.remove())}catch{}i.disabled=!1,i.textContent="\u{1F5D1}\uFE0F Delete",c.success(`\u{1F5D1}\uFE0F ${o} payment(s) deleted`),f.clear(),M()}),typeof window<"u"&&window.FAB&&window.FAB.mount({icon:"\u{1F4B3}",label:"Payment Actions",color:"#00b894",actions:[{icon:"\u2795",label:"Collect Fee",onClick:()=>{W()}},{icon:"\u{1F4E5}",label:"Export CSV",onClick:()=>{Q()}},{icon:"\u{1F4CA}",label:"Revenue Report",onClick:()=>{window.location.hash="#/reports"}}]}),p}export{pe as render};
