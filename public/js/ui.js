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
  info(message) { this.show(message, 'info'); }
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
  const modal = document.getElementById('modal-container');
  if (modal && modal.open) modal.close();
};

Modal.closeAll = function() {
  Modal.close();
};

Modal.hide = function() {
  Modal.close();
};

// Global fallback for any inline HTML onclick handlers
if (typeof window !== 'undefined') {
  window.Modal = Modal;
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
  }
};
