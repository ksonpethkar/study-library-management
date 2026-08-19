import { AudioFeedback } from './utils/audioFeedback.js';

export function escapeHTML(str) {
  if (str === null || str === undefined) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export const Toast = {
  show(message, type = 'info', duration = 4000) {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'toast-container';
      document.body.appendChild(container);
    }

    // Play synthesized sound feedback
    if (type === 'success') {
      AudioFeedback.play('success');
    } else if (type === 'warning' || type === 'error') {
      AudioFeedback.play('warning');
    }

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;
    
    let iconSvg = '';
    if (type === 'success') {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    } else if (type === 'error') {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>';
    } else if (type === 'warning') {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>';
    } else {
      iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>';
    }

    toast.innerHTML = `
      <div class="toast-content" style="display: flex; align-items: center; gap: 10px;">
        <span class="toast-icon">${iconSvg}</span>
        <span class="toast-msg">${escapeHTML(message)}</span>
      </div>
      <button class="toast-close" style="background:none; border:none; color:inherit; cursor:pointer; font-size:16px; margin-left:12px;">&times;</button>
    `;

    container.appendChild(toast);

    const closeBtn = toast.querySelector('.toast-close');
    const dismiss = () => {
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(20px)';
      setTimeout(() => toast.remove(), 250);
    };

    closeBtn.onclick = dismiss;
    if (duration > 0) {
      setTimeout(dismiss, duration);
    }
  },
  success(message) { this.show(message, 'success'); },
  error(message) { this.show(message, 'error'); },
  warning(message) { this.show(message, 'warning'); },
  info(message) { this.show(message, 'info'); },
  undo(message, onUndoFn) {
    let container = document.getElementById('toast-container');
    if (!container) {
      container = document.createElement('div');
      container.id = 'toast-container';
      container.className = 'toast-container';
      document.body.appendChild(container);
    }

    AudioFeedback.play('info');

    const toast = document.createElement('div');
    toast.className = 'toast toast-info toast-undo';

    const iconSvg = '<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="16" x2="12" y2="12"></line><line x1="12" y1="8" x2="12.01" y2="8"></line></svg>';

    toast.innerHTML = `
      <div class="toast-content" style="display: flex; align-items: center; gap: 10px; flex: 1;">
        <span class="toast-icon">${iconSvg}</span>
        <span class="toast-msg">${escapeHTML(message)}</span>
      </div>
      <button class="toast-undo-btn" style="background: rgba(255,255,255,0.2); border: 1px solid rgba(255,255,255,0.4); color: inherit; cursor: pointer; font-weight: 700; font-size: 0.85rem; padding: 4px 10px; border-radius: 6px; margin-left: 10px; display: inline-flex; align-items: center; gap: 4px;">↩️ Undo</button>
      <button class="toast-close" style="background:none; border:none; color:inherit; cursor:pointer; font-size:16px; margin-left:8px;">&times;</button>
    `;

    container.appendChild(toast);

    let dismissed = false;
    let timer = null;

    const dismiss = () => {
      if (dismissed) return;
      dismissed = true;
      if (timer) clearTimeout(timer);
      toast.style.opacity = '0';
      toast.style.transform = 'translateX(20px)';
      setTimeout(() => toast.remove(), 250);
    };

    const undoBtn = toast.querySelector('.toast-undo-btn');
    if (undoBtn) {
      undoBtn.onclick = () => {
        if (!dismissed) {
          dismiss();
          if (typeof onUndoFn === 'function') {
            onUndoFn();
          }
        }
      };
    }

    const closeBtn = toast.querySelector('.toast-close');
    if (closeBtn) closeBtn.onclick = dismiss;

    timer = setTimeout(dismiss, 5000);
  }
};

/**
 * Universal Modal supporting both Modal.show(...) and new Modal(...)
 */
export class ModalClass {
  constructor(titleOrOptions, content, size = 'md') {
    if (typeof titleOrOptions === 'object' && titleOrOptions !== null) {
      this.options = titleOrOptions;
    } else {
      this.options = { title: titleOrOptions, content, size };
    }
    this.element = null;
  }

  show() {
    this.element = Modal.show(this.options);
    return this.element;
  }

  open() {
    return this.show();
  }

  hide() {
    Modal.close();
  }

  close() {
    Modal.close();
  }
}

export const Modal = function(titleOrOptions, content, size) {
  if (new.target || this instanceof Modal) {
    if (typeof titleOrOptions === 'object' && titleOrOptions !== null) {
      this.options = titleOrOptions;
    } else {
      this.options = { title: titleOrOptions, content, size };
    }
    this.element = null;
    return this;
  }
  return new ModalClass(titleOrOptions, content, size);
};

Modal.show = function(opts) {
  let title = '';
  let content = '';
  let size = 'md';
  let actions = '';
  let buttons = null;
  let onClose = null;

  if (typeof opts === 'string') {
    title = opts;
  } else if (typeof opts === 'object' && opts !== null) {
    title = opts.title || '';
    content = opts.content || '';
    size = opts.size || 'md';
    actions = opts.actions || '';
    buttons = opts.buttons || null;
    onClose = opts.onClose || null;
  }

  let modal = document.getElementById('modal-container');
  if (!modal) {
    modal = document.createElement('dialog');
    modal.id = 'modal-container';
    document.body.appendChild(modal);
  }
  
  modal.style.cssText = `
    padding: 0;
    border: 1px solid var(--color-border, #333);
    border-radius: var(--radius-lg, 12px);
    background: var(--color-surface, #1e2230);
    color: var(--color-text-primary, #fff);
    box-shadow: var(--shadow-xl, 0 16px 48px rgba(0,0,0,0.5));
    max-width: 90vw;
    margin: auto;
  `;

  const widthMap = { sm: '420px', md: '640px', lg: '850px', xl: '1050px' };
  modal.style.width = widthMap[size] || widthMap.md;

  modal.innerHTML = `
    <div class="modal-header" style="padding: 16px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center;">
      <h3 style="margin: 0; font-size: 1.2rem; font-weight: 600; color: var(--color-text-primary, #fff);">${escapeHTML(title)}</h3>
      <button class="modal-close modal-close-btn" style="background: none; border: none; font-size: 1.5rem; color: var(--color-text-muted, #aaa); cursor: pointer; line-height: 1; padding: 4px;">&times;</button>
    </div>
    <div class="modal-body-container" style="padding: 20px; max-height: 75vh; overflow-y: auto;">
    </div>
    <div class="modal-footer-container" style="padding: 14px 20px; border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: none; justify-content: flex-end; gap: 10px;"></div>
  `;

  const bodyContainer = modal.querySelector('.modal-body-container');
  if (content instanceof HTMLElement) {
    bodyContainer.appendChild(content);
  } else if (typeof content === 'string') {
    bodyContainer.innerHTML = content;
  }

  const footerContainer = modal.querySelector('.modal-footer-container');
  const modalWrapper = {
    element: modal,
    close: () => {
      if (modal.open) modal.close();
      if (onClose) onClose();
    },
    hide: () => {
      if (modal.open) modal.close();
      if (onClose) onClose();
    }
  };

  if (buttons && Array.isArray(buttons) && buttons.length > 0) {
    footerContainer.style.display = 'flex';
    buttons.forEach(btn => {
      const b = document.createElement('button');
      b.className = `btn ${btn.className || 'btn-secondary'}`;
      b.textContent = btn.text || 'Button';
      b.onclick = () => {
        if (typeof btn.onClick === 'function') {
          btn.onClick(modalWrapper);
        } else {
          modalWrapper.close();
        }
      };
      footerContainer.appendChild(b);
    });
  } else if (actions) {
    footerContainer.style.display = 'flex';
    footerContainer.innerHTML = actions;
  }

  const closeBtn = modal.querySelector('.modal-close');
  const closeHandler = () => {
    modalWrapper.close();
  };
  
  if (closeBtn) closeBtn.onclick = closeHandler;
  
  modal.oncancel = (e) => {
    e.preventDefault();
    closeHandler();
  };
  
  modal.onclick = (e) => {
    const rect = modal.getBoundingClientRect();
    const isInDialog = (rect.top <= e.clientY && e.clientY <= rect.top + rect.height &&
      rect.left <= e.clientX && e.clientX <= rect.left + rect.width);
    if (!isInDialog) {
      closeHandler();
    }
  };

  if (!modal.open) {
    modal.showModal();
  }
  return modal;
};

Modal.close = function() {
  const dialogs = document.querySelectorAll('dialog, #modal-container, .modal-container, .modal');
  dialogs.forEach(d => {
    try {
      if (typeof d.close === 'function' && d.open) {
        d.close();
      }
      d.removeAttribute('open');
      d.style.display = 'none';
    } catch (e) {}
  });
};

Modal.closeAll = function() {
  Modal.close();
};

Modal.hide = function() {
  Modal.close();
};

// Global fallback for any inline HTML onclick handlers and window object
if (typeof window !== 'undefined') {
  window.Toast = Toast;
  window.Modal = Modal;
  window.Modal.closeAll = Modal.closeAll;
  window.Modal.close = Modal.close;
  window.Modal.hide = Modal.hide;

  // Global capture click listener for all Cancel / Close buttons inside any modal
  document.addEventListener('click', (e) => {
    const trigger = e.target.closest('[data-modal-close], [data-close-modal], .modal-close, .modal-close-btn, .modal-cancel, .btn-modal-close, .fb-cancel-modal-btn');
    if (trigger) {
      e.preventDefault();
      e.stopPropagation();
      Modal.closeAll();
      return;
    }

    // Auto-detect any Cancel or Close button inside a dialog/modal container
    if (e.target.tagName === 'BUTTON' && (e.target.type === 'button' || !e.target.type)) {
      const txt = e.target.textContent.trim().toLowerCase();
      if (['cancel', 'close', '✖ cancel', '❌ cancel', 'dismiss', 'back'].includes(txt)) {
        if (e.target.closest('dialog, #modal-container, .modal, .modal-container')) {
          e.preventDefault();
          e.stopPropagation();
          Modal.closeAll();
        }
      }
    }
  }, true);
}

/**
 * Universal Print & PDF Export Utility
 */
export const PDFExport = {
  printElement(elementId, customTitle = 'Document') {
    const el = document.getElementById(elementId);
    if (!el) {
      Toast.error('Element not found for export');
      return;
    }

    const printWin = window.open('', '_blank', 'width=800,height=900');
    if (!printWin) {
      window.print();
      return;
    }

    printWin.document.write(`
      <!DOCTYPE html>
      <html>
      <head>
        <title>${escapeHTML(customTitle)}</title>
        <link rel="stylesheet" href="/css/variables.css">
        <link rel="stylesheet" href="/css/base.css">
        <link rel="stylesheet" href="/css/components.css">
        <link rel="stylesheet" href="/css/print.css">
        <style>
          body { background: #fff !important; color: #000 !important; padding: 20px; font-family: 'Outfit', sans-serif; }
          .no-print, button, .modal-close { display: none !important; }
        </style>
      </head>
      <body>
        ${el.outerHTML}
        <script>
          setTimeout(() => {
            window.print();
            window.close();
          }, 300);
        </script>
      </body>
      </html>
    `);
    printWin.document.close();
  }
};

Modal.prototype.show = function() {
  this.element = Modal.show(this.options);
  return this.element;
};

Modal.prototype.open = function() {
  return this.show();
};

Modal.prototype.hide = function() {
  Modal.close();
};

Modal.prototype.close = function() {
  Modal.close();
};

/**
 * Universal Confirm supporting Confirm(msg, onConfirm) and Confirm.show({ ... })
 */
export const Confirm = function(messageOrOptions, callback) {
  if (typeof messageOrOptions === 'string') {
    return Confirm.show({
      title: 'Confirmation',
      message: messageOrOptions,
      onConfirm: callback
    });
  }
  return Confirm.show(messageOrOptions);
};

Confirm.show = async function(opts) {
  let title = 'Confirm Action';
  let message = 'Are you sure?';
  let confirmText = 'Confirm';
  let cancelText = 'Cancel';
  let danger = false;
  let onConfirm = null;

  if (typeof opts === 'string') {
    message = opts;
  } else if (typeof opts === 'object' && opts !== null) {
    title = opts.title || title;
    message = opts.message || message;
    confirmText = opts.confirmText || confirmText;
    cancelText = opts.cancelText || cancelText;
    danger = opts.danger || false;
    onConfirm = opts.onConfirm || null;
  }

  return new Promise(resolve => {
    const confirmBtnClass = danger ? 'btn btn-danger' : 'btn btn-primary';
    
    const content = `<p style="margin: 0; color: var(--color-text-secondary, #ccc); font-size: 1rem;">${escapeHTML(message)}</p>`;
    const actions = `
      <button id="confirm-cancel" class="btn btn-secondary">${escapeHTML(cancelText)}</button>
      <button id="confirm-ok" class="${confirmBtnClass}">${escapeHTML(confirmText)}</button>
    `;
    
    const modal = Modal.show({
      title,
      content,
      size: 'sm',
      actions,
      onClose: () => resolve(false)
    });
    
    const cancelBtn = modal.querySelector('#confirm-cancel');
    if (cancelBtn) {
      cancelBtn.onclick = () => {
        Modal.close();
        resolve(false);
      };
    }
    
    const okBtn = modal.querySelector('#confirm-ok');
    if (okBtn) {
      okBtn.onclick = async () => {
        Modal.close();
        if (typeof onConfirm === 'function') {
          await onConfirm();
        }
        resolve(true);
      };
    }
  });
};

export const Loading = {
  show(target) {
    if (!target) {
      let overlay = document.getElementById('global-loading-overlay');
      if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'global-loading-overlay';
        overlay.className = 'global-loading-overlay';
        overlay.style.cssText = 'position:fixed; top:0; left:0; width:100vw; height:100vh; background:rgba(0,0,0,0.4); backdrop-filter:blur(3px); z-index:99999; display:flex; align-items:center; justify-content:center; flex-direction:column; gap:12px;';
        overlay.innerHTML = '<div class="loading-spinner"></div><div id="global-loading-text" style="color:#fff; font-weight:600; font-size:0.95rem;">Loading...</div>';
        document.body.appendChild(overlay);
      }
      return;
    }

    if (target instanceof HTMLElement) {
      target.classList.add('loading-skeleton');
      target.setAttribute('aria-busy', 'true');
      return;
    }

    if (typeof target === 'string') {
      try {
        const el = document.querySelector(target);
        if (el) {
          el.classList.add('loading-skeleton');
          el.setAttribute('aria-busy', 'true');
          return;
        }
      } catch (e) {
        // Not a valid CSS selector - treat target as a display message
      }

      let overlay = document.getElementById('global-loading-overlay');
      if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'global-loading-overlay';
        overlay.className = 'global-loading-overlay';
        overlay.style.cssText = 'position:fixed; top:0; left:0; width:100vw; height:100vh; background:rgba(0,0,0,0.4); backdrop-filter:blur(3px); z-index:99999; display:flex; align-items:center; justify-content:center; flex-direction:column; gap:12px;';
        overlay.innerHTML = `<div class="loading-spinner"></div><div id="global-loading-text" style="color:#fff; font-weight:600; font-size:0.95rem;">${escapeHTML(target)}</div>`;
        document.body.appendChild(overlay);
      } else {
        const textEl = document.getElementById('global-loading-text');
        if (textEl) textEl.textContent = target;
        overlay.style.display = 'flex';
      }
    }
  },
  hide(target) {
    if (!target) {
      const overlay = document.getElementById('global-loading-overlay');
      if (overlay) overlay.remove();
      return;
    }

    if (target instanceof HTMLElement) {
      target.classList.remove('loading-skeleton');
      target.removeAttribute('aria-busy');
      return;
    }

    if (typeof target === 'string') {
      try {
        const el = document.querySelector(target);
        if (el) {
          el.classList.remove('loading-skeleton');
          el.removeAttribute('aria-busy');
        }
      } catch (e) {}
    }

    const overlay = document.getElementById('global-loading-overlay');
    if (overlay) overlay.remove();
  },
  button(btn, isLoading) {
    if (typeof btn === 'string') btn = document.querySelector(btn);
    if (!btn) return;
    if (isLoading) {
      btn.dataset.originalText = btn.innerHTML;
      btn.innerHTML = '<span class="spinner" style="display:inline-block; width:1em; height:1em; border:2px solid currentColor; border-right-color:transparent; border-radius:50%; animation:spin 0.75s linear infinite;"></span>';
      btn.disabled = true;
    } else {
      btn.innerHTML = btn.dataset.originalText || btn.innerHTML;
      btn.disabled = false;
    }
  },
  skeleton(container, type = 'table') {
    let targetEl = container;
    if (typeof container === 'string') {
      targetEl = document.querySelector(container);
    }
    if (!targetEl) return;

    let html = '';
    if (type === 'table') {
      html = `
        <div class="skeleton-table p-3">
          ${Array(5).fill(0).map(() => `
            <div class="skeleton-row">
              <div class="skeleton skeleton-avatar" style="width: 28px; height: 28px;"></div>
              <div class="skeleton skeleton-text" style="flex: 1; margin-bottom: 0;"></div>
              <div class="skeleton skeleton-text" style="flex: 2; margin-bottom: 0;"></div>
              <div class="skeleton skeleton-text" style="flex: 1; margin-bottom: 0;"></div>
              <div class="skeleton skeleton-button" style="width: 60px; height: 28px;"></div>
            </div>
          `).join('')}
        </div>
      `;
    } else if (type === 'cards') {
      html = `
        <div class="grid-auto-fit gap-3 p-3">
          ${Array(4).fill(0).map(() => `
            <div class="skeleton-card">
              <div class="d-flex align-items-center gap-3">
                <div class="skeleton skeleton-avatar"></div>
                <div style="flex: 1;">
                  <div class="skeleton skeleton-title" style="width: 60%; margin-bottom: 4px;"></div>
                  <div class="skeleton skeleton-text short" style="margin-bottom: 0;"></div>
                </div>
              </div>
              <div class="skeleton skeleton-text" style="margin-top: 8px;"></div>
              <div class="skeleton skeleton-text short"></div>
            </div>
          `).join('')}
        </div>
      `;
    } else if (type === 'kpi') {
      html = `
        <div class="kpi-grid">
          ${Array(4).fill(0).map(() => `
            <div class="kpi-card skeleton-card" style="min-height: 96px; justify-content: center;">
              <div class="skeleton skeleton-text short" style="width: 50%; margin-bottom: 8px;"></div>
              <div class="skeleton skeleton-title" style="width: 40%; height: 1.8rem; margin-bottom: 4px;"></div>
              <div class="skeleton skeleton-text short" style="width: 70%; margin-bottom: 0;"></div>
            </div>
          `).join('')}
        </div>
      `;
    } else if (type === 'profile') {
      html = `
        <div class="skeleton-card p-4">
          <div class="d-flex align-items-center gap-4 mb-4">
            <div class="skeleton skeleton-avatar" style="width: 72px; height: 72px;"></div>
            <div style="flex: 1;">
              <div class="skeleton skeleton-title" style="width: 40%;"></div>
              <div class="skeleton skeleton-text short mb-2"></div>
              <div class="skeleton skeleton-text" style="width: 60%;"></div>
            </div>
          </div>
          <div class="skeleton skeleton-text mb-3"></div>
          <div class="skeleton skeleton-text mb-3"></div>
          <div class="skeleton skeleton-text short"></div>
        </div>
      `;
    } else {
      html = `
        <div class="p-3">
          <div class="skeleton skeleton-title"></div>
          <div class="skeleton skeleton-text"></div>
          <div class="skeleton skeleton-text short"></div>
        </div>
      `;
    }

    targetEl.innerHTML = html;
  }
};

/**
 * Soft Empty State & Button Loading Spinner Helpers
 */
export function emptyState(container, options = {}) {
  let targetEl = typeof container === 'string' ? document.querySelector(container) : container;
  if (!targetEl) return null;

  const {
    icon = '<svg viewBox="0 0 24 24" width="48" height="48" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" style="color: var(--color-text-muted, #888);"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>',
    title = 'No Data Available',
    description = 'There are no items to display at this time.',
    actionText = null,
    onAction = null
  } = options;

  const emptyCard = document.createElement('div');
  emptyCard.className = 'empty-state-card';
  emptyCard.style.cssText = `
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 24px;
    text-align: center;
    background: var(--color-surface, #1e2230);
    border: 1px dashed var(--color-border, rgba(255,255,255,0.12));
    border-radius: var(--radius-lg, 12px);
    margin: 16px 0;
    width: 100%;
    box-sizing: border-box;
  `;

  let iconHtml = '';
  if (typeof icon === 'string' && !icon.includes('<')) {
    iconHtml = `<div style="font-size: 2.8rem; margin-bottom: 12px; line-height: 1;">${icon}</div>`;
  } else if (typeof icon === 'string') {
    iconHtml = `<div style="margin-bottom: 14px; opacity: 0.85; display: inline-flex; align-items: center; justify-content: center;">${icon}</div>`;
  }

  let buttonHtml = '';
  if (actionText) {
    buttonHtml = `<button type="button" class="btn btn-primary empty-state-action-btn" style="margin-top: 16px; font-weight: 600;">${escapeHTML(actionText)}</button>`;
  }

  emptyCard.innerHTML = `
    ${iconHtml}
    <h4 style="margin: 0 0 8px 0; font-size: 1.1rem; font-weight: 700; color: var(--color-text-primary, #fff);">${escapeHTML(title)}</h4>
    <p style="margin: 0; font-size: 0.875rem; color: var(--color-text-muted, #a0aec0); max-width: 420px; line-height: 1.5;">${escapeHTML(description)}</p>
    ${buttonHtml}
  `;

  if (actionText && typeof onAction === 'function') {
    const btn = emptyCard.querySelector('.empty-state-action-btn');
    if (btn) {
      btn.onclick = (e) => onAction(e);
    }
  }

  if (targetEl.tagName === 'TBODY') {
    targetEl.innerHTML = '';
    const tr = document.createElement('tr');
    const td = document.createElement('td');
    td.colSpan = 100;
    td.style.padding = '12px';
    td.appendChild(emptyCard);
    tr.appendChild(td);
    targetEl.appendChild(tr);
    return emptyCard;
  }

  targetEl.innerHTML = '';
  targetEl.appendChild(emptyCard);
  return emptyCard;
}

export function buttonLoading(buttonEl, isLoading, loadingText) {
  let btn = typeof buttonEl === 'string' ? document.querySelector(buttonEl) : buttonEl;
  if (!btn) return;

  if (isLoading) {
    if (btn.dataset.isLoading === 'true') return;
    btn.dataset.isLoading = 'true';
    btn.dataset.originalHtml = btn.innerHTML;
    btn.disabled = true;

    const spinnerHtml = `<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true" style="display: inline-block; width: 0.9em; height: 0.9em; border: 2px solid currentColor; border-right-color: transparent; border-radius: 50%; animation: spin 0.75s linear infinite; vertical-align: text-bottom;"></span>`;
    const textHtml = loadingText ? `<span class="btn-loading-text" style="margin-left: 6px;">${escapeHTML(loadingText)}</span>` : (btn.innerText ? `<span class="btn-loading-text" style="margin-left: 6px;">${escapeHTML(btn.innerText.trim())}</span>` : '');

    btn.innerHTML = `${spinnerHtml}${textHtml}`;
  } else {
    if (btn.dataset.originalHtml !== undefined) {
      btn.innerHTML = btn.dataset.originalHtml;
      delete btn.dataset.originalHtml;
    }
    btn.dataset.isLoading = 'false';
    btn.disabled = false;
  }
}

export const UI = {
  emptyState,
  buttonLoading
};

if (typeof window !== 'undefined') {
  window.UI = UI;
}

export function debounce(fn, delay = 250) {
  let timer = null;
  return function (...args) {
    const context = this;
    if (timer) clearTimeout(timer);
    timer = setTimeout(() => {
      fn.apply(context, args);
    }, delay);
  };
}

if (typeof window !== 'undefined') {
  window.debounce = debounce;
}

/**
 * Native Web Share & Clipboard Fallback Helper
 */
export const NativeShare = {
  async share(options = {}) {
    let title, text, url;
    if (typeof options === 'string') {
      url = options;
    } else {
      ({ title, text, url } = options || {});
    }

    const shareData = {};
    if (title) shareData.title = title;
    if (text) shareData.text = text;
    if (url) shareData.url = url;

    if (navigator.share) {
      try {
        if (navigator.canShare && !navigator.canShare(shareData)) {
          // If canShare returns false, fallback to clipboard
        } else {
          await navigator.share(shareData);
          return true;
        }
      } catch (err) {
        if (err.name === 'AbortError') return false;
      }
    }

    // Fallback: Copy link to clipboard with Toast confirmation
    const textToCopy = url || text || title || (typeof window !== 'undefined' ? window.location.href : '');
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(textToCopy);
      } else if (typeof document !== 'undefined') {
        const textarea = document.createElement('textarea');
        textarea.value = textToCopy;
        textarea.style.position = 'fixed';
        textarea.style.opacity = '0';
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        textarea.remove();
      }
      Toast.success('Link copied to clipboard!');
      return true;
    } catch (err) {
      Toast.error('Failed to copy link');
      return false;
    }
  }
};

if (typeof window !== 'undefined') {
  window.NativeShare = NativeShare;
}

/**
 * Copy text to clipboard with button green badge feedback for 2 seconds
 * @param {string} text 
 * @param {HTMLElement} [btnElement] 
 * @returns {Promise<boolean>}
 */
export async function copyToClipboard(text, btnElement) {
  if (!text) return false;
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
    } else if (typeof document !== 'undefined') {
      const textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.style.position = 'fixed';
      textarea.style.opacity = '0';
      document.body.appendChild(textarea);
      textarea.select();
      document.execCommand('copy');
      textarea.remove();
    }

    if (btnElement) {
      const originalHTML = btnElement.innerHTML;
      const originalBg = btnElement.style.backgroundColor;
      const originalColor = btnElement.style.color;
      const originalBorderColor = btnElement.style.borderColor;

      btnElement.innerHTML = '✓ Copied!';
      btnElement.classList.add('badge', 'bg-success', 'text-white');
      btnElement.style.backgroundColor = 'var(--color-success, #2ed573)';
      btnElement.style.color = '#ffffff';
      btnElement.style.borderColor = 'var(--color-success, #2ed573)';

      if (btnElement._copyTimeout) {
        clearTimeout(btnElement._copyTimeout);
      }

      btnElement._copyTimeout = setTimeout(() => {
        btnElement.innerHTML = originalHTML;
        btnElement.classList.remove('badge', 'bg-success', 'text-white');
        btnElement.style.backgroundColor = originalBg;
        btnElement.style.color = originalColor;
        btnElement.style.borderColor = originalBorderColor;
        delete btnElement._copyTimeout;
      }, 2000);
    }

    Toast.success('Copied to clipboard!');
    return true;
  } catch (err) {
    console.error('Failed to copy to clipboard:', err);
    Toast.error('Failed to copy to clipboard');
    return false;
  }
}

if (typeof window !== 'undefined') {
  window.copyToClipboard = copyToClipboard;
}

/**
 * Slide-Up Bottom Sheet Modal Component
 * Renders as a slide-up bottom sheet on mobile screens (<= 768px) with swipe-down gesture support.
 * Degrades gracefully into a centered modal on desktop screens.
 */
export class BottomSheet {
  constructor(options = {}) {
    if (typeof options === 'string') {
      options = { title: options };
    }
    this.options = options;
    this.sheet = null;
    this.overlay = null;
    this.onClose = options.onClose || null;
  }

  static show(options) {
    const isMobile = typeof window !== 'undefined' && window.innerWidth <= 768;
    if (!isMobile) {
      return Modal.show(options);
    }
    const bs = new BottomSheet(options);
    return bs.open();
  }

  static close() {
    if (typeof document === 'undefined') return;
    const sheets = document.querySelectorAll('.bottom-sheet');
    sheets.forEach(sheet => {
      sheet.classList.remove('open');
      sheet.style.transform = 'translateY(100%)';
    });
    const overlays = document.querySelectorAll('.bottom-sheet-overlay');
    overlays.forEach(overlay => {
      overlay.classList.remove('open');
      overlay.style.opacity = '0';
    });
    setTimeout(() => {
      sheets.forEach(s => s.remove());
      overlays.forEach(o => o.remove());
    }, 300);
  }

  open() {
    const isMobile = typeof window !== 'undefined' && window.innerWidth <= 768;
    if (!isMobile) {
      return Modal.show(this.options);
    }

    const opts = typeof this.options === 'string' ? { title: this.options } : (this.options || {});
    const title = opts.title || '';
    const content = opts.content || '';

    // Create backdrop overlay
    let overlay = document.querySelector('.bottom-sheet-overlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.className = 'bottom-sheet-overlay';
      document.body.appendChild(overlay);
    }
    this.overlay = overlay;

    // Create bottom sheet element
    const sheet = document.createElement('div');
    sheet.className = 'bottom-sheet';
    this.sheet = sheet;

    let headerHTML = '';
    if (title) {
      headerHTML = `
        <div class="bottom-sheet-header" style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08));">
          <h3 style="margin: 0; font-size: 1.15rem; font-weight: 600; color: var(--color-text-primary);">${escapeHTML(title)}</h3>
          <button class="bottom-sheet-close" style="background: none; border: none; font-size: 1.4rem; color: var(--color-text-muted); cursor: pointer; padding: 4px; line-height: 1;">&times;</button>
        </div>
      `;
    }

    let footerHTML = '';
    if (opts.buttons && Array.isArray(opts.buttons) && opts.buttons.length > 0) {
      footerHTML = `<div class="bottom-sheet-footer" style="margin-top: 16px; display: flex; gap: 8px; justify-content: flex-end;"></div>`;
    } else if (opts.actions) {
      footerHTML = `<div class="bottom-sheet-footer" style="margin-top: 16px; display: flex; gap: 8px; justify-content: flex-end;">${opts.actions}</div>`;
    }

    sheet.innerHTML = `
      <div class="bottom-sheet-handle"></div>
      ${headerHTML}
      <div class="bottom-sheet-body"></div>
      ${footerHTML}
    `;

    const bodyEl = sheet.querySelector('.bottom-sheet-body');
    if (content instanceof HTMLElement) {
      bodyEl.appendChild(content);
    } else if (typeof content === 'string') {
      bodyEl.innerHTML = content;
    }

    if (opts.buttons && Array.isArray(opts.buttons) && opts.buttons.length > 0) {
      const footerEl = sheet.querySelector('.bottom-sheet-footer');
      opts.buttons.forEach(btn => {
        const b = document.createElement('button');
        b.className = `btn ${btn.className || 'btn-secondary'}`;
        b.textContent = btn.text || 'Button';
        b.onclick = () => {
          if (typeof btn.onClick === 'function') {
            btn.onClick(this);
          } else {
            this.close();
          }
        };
        footerEl.appendChild(b);
      });
    }

    document.body.appendChild(sheet);

    // Setup close listeners
    const closeBtn = sheet.querySelector('.bottom-sheet-close');
    if (closeBtn) {
      closeBtn.onclick = () => this.close();
    }
    overlay.onclick = () => this.close();

    // Attach swipe down gesture support
    this._initSwipeGesture();

    // Trigger animation
    requestAnimationFrame(() => {
      overlay.classList.add('open');
      sheet.classList.add('open');
    });

    return sheet;
  }

  close() {
    if (this.sheet) {
      this.sheet.classList.remove('open');
      this.sheet.style.transform = 'translateY(100%)';
    }
    if (this.overlay) {
      this.overlay.classList.remove('open');
    }
    setTimeout(() => {
      if (this.sheet) this.sheet.remove();
      if (this.overlay) this.overlay.remove();
      if (typeof this.onClose === 'function') {
        this.onClose();
      }
    }, 300);
  }

  _initSwipeGesture() {
    if (!this.sheet) return;
    const handle = this.sheet.querySelector('.bottom-sheet-handle') || this.sheet;

    let startY = 0;
    let currentY = 0;
    let isDragging = false;

    const onTouchStart = (e) => {
      if (this.sheet.scrollTop > 0 && e.target !== handle) return;
      startY = e.touches[0].clientY;
      isDragging = true;
      this.sheet.style.transition = 'none';
    };

    const onTouchMove = (e) => {
      if (!isDragging) return;
      currentY = e.touches[0].clientY;
      const deltaY = currentY - startY;
      if (deltaY > 0) {
        this.sheet.style.transform = `translateY(${deltaY}px)`;
      }
    };

    const onTouchEnd = () => {
      if (!isDragging) return;
      isDragging = false;
      this.sheet.style.transition = 'transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)';
      const deltaY = currentY - startY;
      if (deltaY > 80) {
        this.close();
      } else {
        this.sheet.style.transform = '';
        this.sheet.classList.add('open');
      }
    };

    handle.addEventListener('touchstart', onTouchStart, { passive: true });
    this.sheet.addEventListener('touchstart', onTouchStart, { passive: true });
    window.addEventListener('touchmove', onTouchMove, { passive: true });
    window.addEventListener('touchend', onTouchEnd, { passive: true });
  }
}

/**
 * Pull-To-Refresh Gesture Listener
 * Tracks touchstart/touchmove at top of window (window.scrollY === 0).
 * Shows top spinner indicator when pulled down 70px+.
 * Triggers active page route refresh (window.dispatchEvent(new HashChangeEvent('hashchange'))).
 */
export function initPullToRefresh() {
  if (typeof window === 'undefined') return;

  let spinner = document.getElementById('pull-to-refresh-spinner');
  if (!spinner) {
    spinner = document.createElement('div');
    spinner.id = 'pull-to-refresh-spinner';
    spinner.className = 'pull-to-refresh-spinner';
    spinner.innerHTML = `
      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" style="color: var(--color-primary, #6366f1); animation: spin 0.8s linear infinite;">
        <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67"/>
      </svg>
    `;
    document.body.appendChild(spinner);
  }

  let startY = 0;
  let pullDistance = 0;
  let isPulling = false;
  let isRefreshing = false;

  window.addEventListener('touchstart', (e) => {
    if (window.scrollY === 0 && e.touches && e.touches.length === 1) {
      startY = e.touches[0].clientY;
      isPulling = true;
      pullDistance = 0;
    }
  }, { passive: true });

  window.addEventListener('touchmove', (e) => {
    if (!isPulling || isRefreshing) return;
    if (window.scrollY > 0) {
      isPulling = false;
      return;
    }
    if (!e.touches || e.touches.length === 0) return;
    const currentY = e.touches[0].clientY;
    const deltaY = currentY - startY;

    if (deltaY > 0 && window.scrollY === 0) {
      pullDistance = deltaY;
      if (pullDistance >= 70) {
        spinner.classList.add('visible');
      } else {
        spinner.classList.remove('visible');
      }
    }
  }, { passive: true });

  window.addEventListener('touchend', () => {
    if (!isPulling) return;
    isPulling = false;

    if (pullDistance >= 70 && !isRefreshing) {
      isRefreshing = true;
      spinner.classList.add('visible');

      // Trigger active page route refresh
      window.dispatchEvent(new HashChangeEvent('hashchange'));

      setTimeout(() => {
        spinner.classList.remove('visible');
        isRefreshing = false;
        pullDistance = 0;
      }, 600);
    } else {
      spinner.classList.remove('visible');
      pullDistance = 0;
    }
  }, { passive: true });
}

if (typeof window !== 'undefined') {
  window.BottomSheet = BottomSheet;
  window.initPullToRefresh = initPullToRefresh;

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => initPullToRefresh());
  } else {
    initPullToRefresh();
  }
}

/**
 * Render responsive mobile bottom navigation bar based on user role
 * @param {string} role - 'admin' | 'staff' | 'student'
 */
export function renderMobileBottomNav(role = 'admin') {
  let nav = document.querySelector('.mobile-bottom-nav') || document.getElementById('mobile-nav');
  if (!nav) {
    nav = document.createElement('nav');
    nav.id = 'mobile-nav';
    nav.className = 'mobile-bottom-nav mobile-nav';
    const appContainer = document.getElementById('app') || document.body;
    appContainer.appendChild(nav);
  } else {
    if (!nav.classList.contains('mobile-bottom-nav')) {
      nav.classList.add('mobile-bottom-nav');
    }
  }

  const isStudent = role === 'student';

  const adminTabs = [
    { label: 'Dashboard', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7"></rect><rect x="14" y="3" width="7" height="7"></rect><rect x="14" y="14" width="7" height="7"></rect><rect x="3" y="14" width="7" height="7"></rect></svg>', emoji: '🏠', href: '#/dashboard' },
    { label: 'Students', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></svg>', emoji: '🎓', href: '#/students' },
    { label: 'Seats', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="2" width="16" height="20" rx="2" ry="2"></rect><path d="M9 22v-4h6v4"></path><path d="M5 16V4a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v12"></path></svg>', emoji: '🪑', href: '#/seats' },
    { label: 'Payments', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>', emoji: '💳', href: '#/payments' },
    { label: 'Menu', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="3" y1="12" x2="21" y2="12"></line><line x1="3" y1="6" x2="21" y2="6"></line><line x1="3" y1="18" x2="21" y2="18"></line></svg>', emoji: '☰', href: 'action:menu' }
  ];

  const studentTabs = [
    { label: 'Portal', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"></path><polyline points="9 22 9 12 15 12 15 22"></polyline></svg>', emoji: '🏠', href: '#/portal' },
    { label: 'Attendance', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect><path d="M9 14l2 2 4-4"></path></svg>', emoji: '📊', href: '#/attendance' },
    { label: 'Pay Renewal', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>', emoji: '💳', href: '#/payments' },
    { label: 'ID Pass', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"></rect><circle cx="9" cy="10" r="2"></circle><line x1="15" y1="8" x2="17" y2="8"></line><line x1="15" y1="12" x2="17" y2="12"></line><line x1="7" y1="16" x2="17" y2="16"></line></svg>', emoji: '🪪', href: '#/portal' },
    { label: 'Profile', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"></path><circle cx="12" cy="7" r="4"></circle></svg>', emoji: '👤', href: '#/profile' }
  ];

  const tabs = isStudent ? studentTabs : adminTabs;
  const currentHash = (window.location.hash || (isStudent ? '#/portal' : '#/dashboard')).split('?')[0];

  nav.innerHTML = tabs.map(tab => {
    const isMenuAction = tab.href === 'action:menu';
    const isActive = !isMenuAction && currentHash === tab.href;
    const linkHref = isMenuAction ? 'javascript:void(0);' : tab.href;

    return `
      <a href="${linkHref}" class="mobile-tab-item mobile-nav-item ${isActive ? 'active' : ''}" data-href="${tab.href}">
        <span class="tab-icon">${tab.icon || tab.emoji}</span>
        <span class="tab-label">${tab.label}</span>
      </a>
    `;
  }).join('');

  // Attach tab click events for haptic feedback and Menu toggle
  nav.querySelectorAll('.mobile-tab-item, .mobile-nav-item').forEach(item => {
    item.addEventListener('click', (e) => {
      // Subtle haptic vibration pulse
      if (navigator.vibrate) {
        try { navigator.vibrate(25); } catch (err) {}
      }

      const href = item.getAttribute('data-href');
      if (href === 'action:menu') {
        e.preventDefault();
        document.getElementById('sidebar')?.classList.toggle('mobile-open');
        document.getElementById('sidebar-overlay')?.classList.toggle('visible');
      }
    });
  });
}

if (typeof window !== 'undefined') {
  window.renderMobileBottomNav = renderMobileBottomNav;
}

/**
 * VoiceSearch Module using Web Speech API
 */
export const VoiceSearch = {
  recognition: null,
  isListening: false,
  indicator: null,

  showIndicator() {
    this.hideIndicator();

    if (!document.getElementById('voice-search-style')) {
      const style = document.createElement('style');
      style.id = 'voice-search-style';
      style.textContent = `
        @keyframes voice-pulse-ring {
          0% { box-shadow: 0 0 0 0 rgba(108, 92, 231, 0.7); }
          70% { box-shadow: 0 0 0 16px rgba(108, 92, 231, 0); }
          100% { box-shadow: 0 0 0 0 rgba(108, 92, 231, 0); }
        }
        @keyframes voice-mic-bounce {
          0%, 100% { transform: scale(1); }
          50% { transform: scale(1.25); }
        }
      `;
      document.head.appendChild(style);
    }

    this.indicator = document.createElement('div');
    this.indicator.id = 'voice-search-indicator';
    this.indicator.style.cssText = `
      position: fixed;
      bottom: 36px;
      left: 50%;
      transform: translateX(-50%);
      background: linear-gradient(135deg, #6c5ce7, #a29bfe);
      color: #ffffff;
      padding: 12px 24px;
      border-radius: 50px;
      box-shadow: 0 8px 24px rgba(108, 92, 231, 0.4);
      display: flex;
      align-items: center;
      gap: 12px;
      font-weight: 600;
      font-size: 0.95rem;
      font-family: 'Outfit', sans-serif;
      z-index: 999999;
      animation: voice-pulse-ring 1.5s infinite;
      cursor: pointer;
    `;

    this.indicator.innerHTML = `
      <span style="font-size: 1.3rem; display: inline-block; animation: voice-mic-bounce 1s infinite;">🎙️</span>
      <span>Listening... Speak now</span>
      <button style="background: rgba(255,255,255,0.2); border: none; color: #fff; border-radius: 50%; width: 22px; height: 22px; font-size: 12px; cursor: pointer; display: flex; align-items: center; justify-content: justify; margin-left: 6px;" title="Cancel">&times;</button>
    `;

    const cancelBtn = this.indicator.querySelector('button');
    if (cancelBtn) {
      cancelBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        this.stop();
      });
    }

    document.body.appendChild(this.indicator);
  },

  hideIndicator() {
    if (this.indicator) {
      this.indicator.remove();
      this.indicator = null;
    }
  },

  start(onResult, onError) {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      Toast.error('Voice search is not supported in this browser.');
      if (onError) onError('Speech recognition not supported');
      return;
    }

    try {
      if (this.isListening && this.recognition) {
        this.recognition.abort();
      }

      const rec = new SpeechRecognition();
      this.recognition = rec;
      rec.continuous = false;
      rec.interimResults = false;
      rec.lang = 'en-US';

      rec.onstart = () => {
        this.isListening = true;
        this.showIndicator();
      };

      rec.onresult = (event) => {
        this.isListening = false;
        this.hideIndicator();
        if (event.results && event.results[0] && event.results[0][0]) {
          const transcript = event.results[0][0].transcript;
          if (onResult) onResult(transcript);
        }
      };

      rec.onerror = (event) => {
        this.isListening = false;
        this.hideIndicator();
        console.error('Voice recognition error:', event.error);
        if (event.error !== 'aborted') {
          Toast.error(`Voice search error: ${event.error}`);
        }
        if (onError) onError(event.error);
      };

      rec.onend = () => {
        this.isListening = false;
        this.hideIndicator();
      };

      rec.start();
    } catch (err) {
      this.isListening = false;
      this.hideIndicator();
      console.error('Failed to start voice search:', err);
      Toast.error('Failed to start voice search');
      if (onError) onError(err);
    }
  },

  stop() {
    if (this.recognition && this.isListening) {
      try {
        this.recognition.stop();
      } catch (err) {}
      this.isListening = false;
      this.hideIndicator();
    }
  }
};

if (typeof window !== 'undefined') {
  window.VoiceSearch = VoiceSearch;
}





