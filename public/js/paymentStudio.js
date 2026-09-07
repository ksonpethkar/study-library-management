import{escapeHTML as i,Toast as p}from"./ui.js";const g={getProfile(){let t={};try{t=window.store?.settings?.businessProfile||window.store?.profile||JSON.parse(localStorage.getItem("sl_public_profile_cache")||"{}")||{}}catch{}return{businessName:t.businessName||"Study Library",upiId:t.upiId||"thecozycorner@okaxis",customQrImage:t.upiQrCode||t.upiQrImage||"",bankDetails:t.bankDetails||{bankName:"State Bank of India",accountNumber:"41238902145",ifscCode:"SBIN0001234",accountHolder:t.businessName||"The Cozy Corner Centre",accountType:"Current"},paymentInstructions:t.paymentInstructions||""}},generateUpiUri({upiId:t,businessName:e,amount:o,note:n="Library Fee Payment",txnRef:r=""}={}){const a=this.getProfile(),s=t||a.upiId,l=e||a.businessName,c=parseFloat(o)||0,d=(n||"Library Fee Payment").substring(0,50),u=r||`SL${Date.now().toString().slice(-8)}`;return`upi://pay?${[`pa=${encodeURIComponent(s)}`,`pn=${encodeURIComponent(l)}`,`am=${c}`,"cu=INR",`tn=${encodeURIComponent(d)}`,`tr=${encodeURIComponent(u)}`].join("&")}`},getQrCodeImageUrl(t,e=""){return e?e.startsWith("data:image")||e.startsWith("/")?e:"/"+e:`https://api.qrserver.com/v1/create-qr-code/?size=220x220&data=${encodeURIComponent(t)}&margin=2&bgcolor=ffffff`},renderUPIWidget({amount:t=0,note:e="Library Fee Payment",txnRef:o="",upiId:n="",businessName:r="",customQrImage:a="",showUtrInput:s=!0,utrInputId:l="pay-utr-number",mountId:c="ps-upi-qr-mount"}={}){const d=this.getProfile(),u=n||d.upiId,b=r||d.businessName,f=a||d.customQrImage,y=parseFloat(t)||0,m=this.generateUpiUri({upiId:u,businessName:b,amount:y,note:e,txnRef:o}),x=this.getQrCodeImageUrl(m,f);return`
      <div class="payment-studio-upi-card" style="background: var(--color-surface); border: 1.5px solid var(--color-border); border-radius: 16px; padding: 16px; text-align: center; box-shadow: var(--shadow-sm); margin-bottom: 1rem;">
        
        <!-- Header Banner -->
        <div style="font-weight: 800; font-size: 1rem; color: var(--color-text-primary); margin-bottom: 4px; display: flex; align-items: center; justify-content: center; gap: 8px;">
          <span>\u26A1</span> <span>1-Tap Instant UPI Payment</span>
        </div>
        <div style="font-size: 0.8rem; color: var(--color-text-secondary); margin-bottom: 12px;">
          Scan QR code or use installed UPI apps below to complete payment.
        </div>

        <!-- QR Code Display Frame -->
        <div style="margin-bottom: 12px;">
          <div id="${c}" style="background: #ffffff; padding: 10px; border-radius: 14px; display: inline-block; margin: 0 auto 6px auto; border: 1.5px solid var(--color-border); box-shadow: var(--shadow-sm);">
            <img src="${x}" alt="Scan UPI QR" style="width: 170px; height: 170px; border-radius: 8px; object-fit: contain; display: block; margin: 0 auto;" onerror="this.onerror=null; this.src='https://chart.googleapis.com/chart?chs=200x200&cht=qr&chl=${encodeURIComponent(m)}';">
            <div style="margin-top: 6px;">
              <span class="badge" style="background: var(--color-primary); color: #fff; font-size: 0.8rem; font-weight: 700; padding: 4px 10px; border-radius: 20px;">
                Pay \u20B9${y.toLocaleString("en-IN")}
              </span>
            </div>
          </div>

          <!-- Official UPI ID & Copy Bar -->
          <div style="background: var(--color-bg-secondary); border: 1px solid var(--color-border); border-radius: 10px; padding: 8px 12px; display: flex; justify-content: space-between; align-items: center; gap: 8px; flex-wrap: wrap; margin-top: 8px; max-width: 420px; margin-left: auto; margin-right: auto;">
            <div style="text-align: left;">
              <div style="font-size: 0.7rem; color: var(--color-text-muted); font-weight: 600;">Official UPI ID</div>
              <span style="font-family: monospace; font-size: 0.92rem; font-weight: 700; color: var(--color-primary);" class="ps-display-upi-id">${i(u)}</span>
            </div>
            <button type="button" class="btn btn-sm btn-outline-primary btn-ps-copy-upi" data-upi="${i(u)}" style="padding: 4px 12px; font-size: 0.8rem; font-weight: 700; border-radius: 8px;">
              \u{1F4CB} Copy UPI ID
            </button>
          </div>
        </div>

        <!-- 1-Tap UPI Intent Mobile Shortcuts -->
        <div style="margin-top: 12px; border-top: 1px dashed var(--color-border); padding-top: 10px; max-width: 420px; margin-left: auto; margin-right: auto;">
          <div style="font-size: 0.76rem; font-weight: 700; color: var(--color-text-secondary); margin-bottom: 8px;">
            Or Open Directly in Your UPI App:
          </div>
          <div style="display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px;">
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="gpay" data-uri="${i(m)}" style="background: #4285F4; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">\u{1F535}</span>
              <span>GPay</span>
            </button>
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="phonepe" data-uri="${i(m)}" style="background: #5f259f; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">\u{1F7E3}</span>
              <span>PhonePe</span>
            </button>
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="paytm" data-uri="${i(m)}" style="background: #00baf2; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">\u{1F499}</span>
              <span>Paytm</span>
            </button>
            <button type="button" class="btn btn-sm btn-ps-intent" data-app="generic" data-uri="${i(m)}" style="background: #00b894; color: #fff; border: none; font-weight: 700; border-radius: 10px; font-size: 0.78rem; padding: 8px 2px; display: flex; flex-direction: column; align-items: center; gap: 2px;">
              <span style="font-size: 1.1rem;">\u{1F4F2}</span>
              <span>BHIM / App</span>
            </button>
          </div>
        </div>

        <!-- NPCI Anti-Failure Guidance Alert -->
        <div style="margin-top: 10px; background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.3); border-radius: 10px; padding: 8px 10px; text-align: left; font-size: 0.75rem; color: var(--color-text-secondary); line-height: 1.35; max-width: 420px; margin-left: auto; margin-right: auto;">
          <strong style="color: #d97706;">\u{1F4A1} Payment Tip:</strong> If your UPI app shows a security notice on intent links, simply <strong>Scan the QR Code</strong> or tap <strong>\u{1F4CB} Copy UPI ID</strong> and pay directly in your app.
        </div>

        ${s?`
          <!-- 12-Digit Bank UTR / Reference No Input Field -->
          <div style="margin-top: 12px; text-align: left; max-width: 420px; margin-left: auto; margin-right: auto;">
            <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 4px;">
              <label class="form-label mb-0" style="font-weight: 700; font-size: 0.85rem; color: var(--color-text-primary);">
                <span>\u{1F4B3}</span> 12-Digit Bank UTR / Ref No.
              </label>
              <span class="badge" style="background: rgba(108, 92, 231, 0.12); color: var(--color-primary); font-size: 0.7rem; font-weight: 700;">Required</span>
            </div>
            <div style="display: flex; gap: 6px;">
              <input type="text" id="${l}" class="form-control ps-utr-input" placeholder="e.g. 423819203912 (12 digits)" maxlength="25" style="font-family: monospace; font-size: 0.92rem; font-weight: 600; letter-spacing: 0.5px;">
              <button type="button" class="btn btn-outline-primary btn-ps-paste-utr" data-target="${l}" style="font-size: 0.8rem; padding: 6px 12px; white-space: nowrap; border-radius: 8px; font-weight: 700;">\u{1F4CB} Paste</button>
            </div>
            <small class="text-muted" style="font-size: 0.72rem; display: block; margin-top: 4px;">
              \u{1F4A1} Find your 12-digit UTR in Google Pay / PhonePe / Paytm payment receipt and paste above.
            </small>
          </div>
        `:""}
      </div>
    `},renderBankDetailsWidget(){const t=this.getProfile(),e=t.bankDetails||{},o=e.bankName||"State Bank of India",n=e.accountNumber||"41238902145",r=e.ifscCode||"SBIN0001234",a=e.accountHolder||t.businessName||"The Cozy Corner Centre",s=e.accountType||"Current Account",l=`Bank: ${o}
Account Name: ${a}
Account No: ${n}
IFSC: ${r}
Type: ${s}`;return`
      <div class="payment-studio-bank-card" style="background: var(--color-surface); border: 1.5px solid var(--color-border); border-radius: 14px; padding: 1rem; margin-bottom: 1rem; box-shadow: var(--shadow-sm);">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; border-bottom: 1px dashed var(--color-border); padding-bottom: 6px;">
          <span style="font-weight: 700; font-size: 0.88rem; color: var(--color-primary);">\u{1F3DB}\uFE0F Official Beneficiary Account</span>
          <button type="button" class="btn btn-xs btn-outline-primary btn-ps-copy-bank" data-details="${i(l)}" style="padding: 2px 8px; font-size: 0.75rem; border-radius: 6px; font-weight: 700;">
            \u{1F4CB} Copy All
          </button>
        </div>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 8px; font-size: 0.82rem;">
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">Account Holder</span>
            <strong style="color: var(--color-text-primary);">${i(a)}</strong>
          </div>
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">Bank Name</span>
            <strong style="color: var(--color-text-primary);">${i(o)}</strong>
          </div>
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">Account Number</span>
            <strong style="font-family: monospace; color: var(--color-primary); font-size: 0.9rem;">${i(n)}</strong>
          </div>
          <div>
            <span class="text-muted" style="font-size: 0.72rem; display: block;">IFSC Code</span>
            <strong style="font-family: monospace; color: var(--color-primary); font-size: 0.9rem;">${i(r)}</strong>
          </div>
        </div>
      </div>
    `},attachEventListeners(t){t&&(t.querySelectorAll(".btn-ps-copy-upi").forEach(e=>{e.addEventListener("click",async()=>{const o=e.dataset.upi;if(o)try{await navigator.clipboard.writeText(o);const n=e.innerHTML;e.innerHTML="\u2713 Copied!",e.classList.replace("btn-outline-primary","btn-success"),p?.success&&p.success(`UPI ID "${o}" copied to clipboard!`),setTimeout(()=>{e.innerHTML=n,e.classList.replace("btn-success","btn-outline-primary")},2e3)}catch{p?.error&&p.error("Could not copy automatically. Please copy manually.")}})}),t.querySelectorAll(".btn-ps-copy-bank").forEach(e=>{e.addEventListener("click",async()=>{const o=e.dataset.details;if(o)try{await navigator.clipboard.writeText(o);const n=e.innerHTML;e.innerHTML="\u2713 Copied!",p?.success&&p.success("Bank details copied to clipboard!"),setTimeout(()=>{e.innerHTML=n},2e3)}catch{p?.error&&p.error("Could not copy bank details.")}})}),t.querySelectorAll(".btn-ps-paste-utr").forEach(e=>{e.addEventListener("click",async()=>{const o=e.dataset.target,n=o?t.querySelector(`#${o}`):t.querySelector(".ps-utr-input");if(n)try{const r=(await navigator.clipboard.readText()).replace(/[^a-zA-Z0-9]/g,"").trim();r?(n.value=r,n.dispatchEvent(new Event("input",{bubbles:!0})),p?.success&&p.success("Pasted from clipboard!")):p?.warning&&p.warning("Clipboard is empty or contains invalid characters.")}catch{p?.info&&p.info("Please paste your UTR manually into the input box.")}})}),t.querySelectorAll(".btn-ps-intent").forEach(e=>{e.addEventListener("click",()=>{const o=e.dataset.app,n=e.dataset.uri;if(!n)return;let r=n;o==="gpay"?r=n.replace("upi://pay?","gpay://upi/pay?"):o==="phonepe"?r=n.replace("upi://pay?","phonepe://pay?"):o==="paytm"&&(r=n.replace("upi://pay?","paytmmp://pay?")),window.location.href=r})}))},generateWhatsAppPaymentLink({phone:t="",studentName:e="",amount:o=0,dueDate:n="",planName:r="",paymentType:a="Fee Renewal"}={}){const s=this.getProfile(),l=String(t||"").replace(/[^0-9]/g,""),c=parseFloat(o)||0,d=this.generateUpiUri({amount:c,note:`${a} - ${e}`}),u=`Hello *${e||"Student"}*,

This is a gentle payment reminder from *${s.businessName}*.

\u{1F4CB} *Payment Details:*
\u2022 *Type:* ${a} ${r?`(${r})`:""}
\u2022 *Payable Amount:* \u20B9${c.toLocaleString("en-IN")}
`+(n?`\u2022 *Due Date:* ${n}
`:"")+`\u2022 *Official UPI ID:* \`${s.upiId}\`

\u26A1 *1-Tap Pay via UPI Link:*
${d}

After payment, please reply with your 12-digit UTR number or screenshot to confirm.

Thank you! \u{1F64F}`;return`https://wa.me/${l?l.startsWith("91")?l:"91"+l:""}?text=${encodeURIComponent(u)}`},renderDebitTrayIcon(t=32){return`
      <div class="tx-tray-icon" style="display: inline-flex; align-items: center; justify-content: center; width: ${t}px; height: ${t}px; min-width: ${t}px; flex-shrink: 0;">
        <svg width="${t}" height="${t}" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
          <!-- 3D Metallic Isometric Drawer / Tray Base -->
          <path d="M4 17L18 23L32 17V26L18 32L4 26V17Z" fill="#1e293b" stroke="#475569" stroke-width="1.2"/>
          <path d="M4 17L18 23L32 17L18 11L4 17Z" fill="#334155" stroke="#64748b" stroke-width="1.2"/>
          <!-- Front Lip Highlight -->
          <path d="M4 26L18 32L32 26" stroke="#94a3b8" stroke-width="1.5"/>
          <!-- Neon Green Downward Arrow -->
          <path d="M18 4V20" stroke="#10b981" stroke-width="3" stroke-linecap="round"/>
          <path d="M12 15L18 21L24 15" stroke="#10b981" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
          <!-- Arrow Tip Accent Glow -->
          <circle cx="18" cy="21" r="2" fill="#34d399"/>
        </svg>
      </div>
    `},renderCreditTrayIcon(t=32){return`
      <div class="tx-tray-icon" style="display: inline-flex; align-items: center; justify-content: center; width: ${t}px; height: ${t}px; min-width: ${t}px; flex-shrink: 0;">
        <svg width="${t}" height="${t}" viewBox="0 0 36 36" fill="none" xmlns="http://www.w3.org/2000/svg">
          <!-- 3D Metallic Isometric Drawer / Tray Base -->
          <path d="M4 17L18 23L32 17V26L18 32L4 26V17Z" fill="#1e293b" stroke="#475569" stroke-width="1.2"/>
          <path d="M4 17L18 23L32 17L18 11L4 17Z" fill="#334155" stroke="#64748b" stroke-width="1.2"/>
          <!-- Front Lip Highlight -->
          <path d="M4 26L18 32L32 26" stroke="#94a3b8" stroke-width="1.5"/>
          <!-- Neon Red Upward Arrow -->
          <path d="M18 22V6" stroke="#ef4444" stroke-width="3" stroke-linecap="round"/>
          <path d="M12 11L18 5L24 11" stroke="#ef4444" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>
          <!-- Arrow Tip Accent Glow -->
          <circle cx="18" cy="5" r="2" fill="#f87171"/>
        </svg>
      </div>
    `},renderActionCapsule({id:t="",copyText:e="",shareText:o="",showEdit:n=!0,showDelete:r=!0,showShare:a=!0,showCopy:s=!0}={}){return`
      <div class="tx-action-capsule" data-id="${i(t)}">
        ${s?`
          <button type="button" class="btn-tx-action action-copy btn-copy-tx" data-id="${i(t)}" data-copy="${i(e)}" title="Copy Receipt / Reference">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
          </button>
        `:""}
        ${n?`
          <button type="button" class="btn-tx-action action-edit btn-edit-tx" data-id="${i(t)}" title="Edit / Update Details">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></svg>
          </button>
        `:""}
        ${r?`
          <button type="button" class="btn-tx-action action-delete btn-delete-tx" data-id="${i(t)}" title="Delete Record">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
          </button>
        `:""}
        ${a?`
          <button type="button" class="btn-tx-action action-share btn-share-tx" data-id="${i(t)}" data-share="${i(o)}" title="Share on WhatsApp / Link">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"><circle cx="18" cy="5" r="3"></circle><circle cx="6" cy="12" r="3"></circle><circle cx="18" cy="19" r="3"></circle><line x1="8.59" y1="13.51" x2="15.42" y2="17.49"></line><line x1="15.41" y1="6.51" x2="8.59" y2="10.49"></line></svg>
          </button>
        `:""}
      </div>
    `},renderTransactionCard(t,{type:e="debit",showStem:o=!0}={}){const n=e==="debit",r=Number(t.amount||t.finalAmount||0),a=t.title||t.student?.name||t.studentName||t.paymentMethod?.toUpperCase()||"Transaction",s=t.paymentDate||t.date||t.createdAt||new Date,l=new Date(s).toLocaleString("en-IN",{day:"numeric",month:"short",year:"numeric",hour:"numeric",minute:"2-digit",hour12:!0}),c=t.balanceDue!==void 0?t.balanceDue:t.balance||0,d=t.receiptNumber||t.reference||t.transactionId||t._id;return`
      <div class="tx-feed-card" data-id="${i(t._id||"")}">
        <!-- Left Column: 3D Tray Icon & Timeline Stem -->
        <div class="tx-icon-col">
          ${n?this.renderDebitTrayIcon(38):this.renderCreditTrayIcon(38)}
          ${o?'<div class="tx-timeline-stem"></div>':""}
        </div>

        <!-- Middle Column: Title, Timestamp, Badges -->
        <div class="tx-info-col">
          <h4 class="tx-title" title="${i(a)}">${i(a)}</h4>
          <div class="tx-timestamp">${i(l)}</div>

          <div class="tx-badge-row">
            ${n?`
              <span class="tx-badge-pill tx-badge-debit">
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="5" x2="12" y2="19"></line><polyline points="19 12 12 19 5 12"></polyline></svg>
                DEBIT
              </span>
            `:`
              <span class="tx-badge-pill tx-badge-credit">
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="19" x2="12" y2="5"></line><polyline points="5 12 12 5 19 12"></polyline></svg>
                CREDIT
              </span>
            `}

            ${t.status==="paid"||n?`
              <span class="tx-badge-pill tx-badge-paid">
                <svg width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>
                Paid
              </span>
            `:t.status==="pending_verification"?`
              <span class="tx-badge-pill tx-badge-pending">\u23F3 Verification</span>
            `:""}
          </div>
        </div>

        <!-- Right Column: Amount, Balance, Action Capsule -->
        <div class="tx-meta-col">
          <div class="tx-amount ${n?"tx-amount-green":"tx-amount-red"}">
            ${n?"":"-"}\u20B9${r.toLocaleString("en-IN")}
          </div>
          <div class="tx-balance">Bal: \u20B9${Number(c).toLocaleString("en-IN")}</div>
          ${this.renderActionCapsule({id:t._id,copyText:d||String(r),shareText:`${a}: \u20B9${r} (${d})`})}
        </div>
      </div>
    `},attachTransactionActionListeners(t,{onCopy:e,onEdit:o,onDelete:n,onShare:r}={}){t&&(t.querySelectorAll(".btn-copy-tx").forEach(a=>{a.addEventListener("click",s=>{s.stopPropagation();const l=a.dataset.copy;l&&navigator.clipboard.writeText(l).then(()=>{p?.success&&p.success(`Copied: ${l}`)}),typeof e=="function"&&e(a.dataset.id,a)})}),t.querySelectorAll(".btn-edit-tx").forEach(a=>{a.addEventListener("click",s=>{s.stopPropagation(),typeof o=="function"&&o(a.dataset.id,a)})}),t.querySelectorAll(".btn-delete-tx").forEach(a=>{a.addEventListener("click",s=>{s.stopPropagation(),typeof n=="function"&&n(a.dataset.id,a)})}),t.querySelectorAll(".btn-share-tx").forEach(a=>{a.addEventListener("click",s=>{s.stopPropagation(),typeof r=="function"&&r(a.dataset.id,a)})}))}};var h=g;export{g as PaymentStudio,h as default};
