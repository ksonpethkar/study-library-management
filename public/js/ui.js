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
    Modal.close(this.element);
  }

  close() {
    Modal.close(this.element);
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

Modal._stack = [];

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

  // Calculate stack depth and layered z-index
  const stackLevel = Modal._stack.length;
  const zIndex = 1000 + (stackLevel * 10);

  // If previous modals exist in stack, deactivate their pointer events while top modal is active
  if (stackLevel > 0) {
    const prevModal = Modal._stack[stackLevel - 1];
    if (prevModal && prevModal.element) {
      prevModal.element.setAttribute('aria-hidden', 'true');
      prevModal.element.style.pointerEvents = 'none';
    }
  }

  const modal = document.createElement('dialog');
  modal.className = 'modal-container-dialog app-modal modal';
  modal.id = stackLevel === 0 ? 'modal-container' : `modal-container-${Date.now()}-${stackLevel}`;
  modal.setAttribute('data-stack-level', String(stackLevel));

  const widthMap = { sm: '420px', md: '640px', lg: '850px', xl: '1050px' };
  // Clamp to viewport — prevents modal overflow on mobile phones
  const rawW = widthMap[size] || widthMap.md;
  
  modal.style.cssText = `
    padding: 0;
    border: 1px solid var(--color-border, rgba(255,255,255,0.12));
    border-radius: var(--radius-lg, 14px);
    background: var(--color-surface, #1e2230);
    color: var(--color-text-primary, #fff);
    box-shadow: var(--shadow-xl, 0 16px 48px rgba(0,0,0,0.5));
    width: min(${rawW}, 95vw);
    max-width: 95vw;
    height: fit-content !important;
    min-height: 0 !important;
    max-height: 85vh;
    margin: auto;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
    z-index: ${zIndex};
  `;

  modal.innerHTML = `
    <div class="modal-header" style="padding: 14px 20px; border-bottom: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: flex; justify-content: space-between; align-items: center; flex-shrink: 0;">
      <h3 style="margin: 0; font-size: 1.15rem; font-weight: 700; color: var(--color-text-primary, #fff);">${escapeHTML(title)}</h3>
      <button class="modal-close modal-close-btn" style="background: none; border: none; font-size: 1.4rem; color: var(--color-text-muted, #aaa); cursor: pointer; line-height: 1; padding: 4px;">&times;</button>
    </div>
    <div class="modal-body-container" style="padding: 18px 20px; max-height: calc(85vh - 120px); overflow-y: auto; flex: 1 1 auto;">
    </div>
    <div class="modal-footer-container" style="padding: 12px 20px; border-top: 1px solid var(--color-divider, rgba(255,255,255,0.08)); display: none; justify-content: flex-end; gap: 10px; flex-shrink: 0; background: var(--color-bg-secondary, rgba(255,255,255,0.02));"></div>
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
      Modal.close(modal);
    },
    hide: () => {
      Modal.close(modal);
    }
  };

  if (buttons && Array.isArray(buttons) && buttons.length > 0) {
    footerContainer.style.display = 'flex';
    buttons.forEach(btn => {
      const b = document.createElement('button');
      b.type = 'button';
      b.className = `btn ${btn.className || 'btn-secondary'}`;
      b.textContent = btn.text || 'Button';
      b.onclick = (e) => {
        e.preventDefault();
        e.stopPropagation();
        if (typeof btn.onClick === 'function') {
          btn.onClick(modalWrapper);
        } else {
          Modal.close(modal);
        }
      };
      footerContainer.appendChild(b);
    });
  } else if (opts && (opts.onConfirm || opts.confirmText)) {
    footerContainer.style.display = 'flex';
    const cancelBtn = document.createElement('button');
    cancelBtn.type = 'button';
    cancelBtn.className = 'btn btn-secondary modal-cancel-btn';
    cancelBtn.textContent = opts.cancelText || 'Cancel';
    cancelBtn.onclick = (e) => {
      e.preventDefault();
      e.stopPropagation();
      Modal.close(modal);
    };

    const confirmBtn = document.createElement('button');
    confirmBtn.type = 'button';
    confirmBtn.className = `btn ${opts.confirmClass || 'btn-primary'} modal-confirm-btn`;
    confirmBtn.textContent = opts.confirmText || 'Save & Confirm';
    confirmBtn.onclick = async (e) => {
      e.preventDefault();
      e.stopPropagation();
      if (typeof opts.onConfirm === 'function') {
        confirmBtn.disabled = true;
        confirmBtn.textContent = 'Processing...';
        try {
          const res = await opts.onConfirm(modalWrapper);
          if (res !== false) {
            Modal.close(modal);
          } else {
            confirmBtn.disabled = false;
            confirmBtn.textContent = opts.confirmText || 'Save & Confirm';
          }
        } catch (err) {
          console.error(err);
          Modal.close(modal);
        }
      } else {
        Modal.close(modal);
      }
    };

    footerContainer.appendChild(cancelBtn);
    footerContainer.appendChild(confirmBtn);
  } else if (actions) {
    footerContainer.style.display = 'flex';
    footerContainer.innerHTML = actions;
  }

  const closeBtn = modal.querySelector('.modal-close');
  const closeHandler = (e) => {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }
    Modal.close(modal);
  };
  
  if (closeBtn) closeBtn.onclick = closeHandler;
  
  // Prevent native dialog auto-cancellation (which browsers fire when OS file pickers or camera permissions close)
  modal.oncancel = (e) => {
    e.preventDefault();
    e.stopPropagation();
  };
  modal.addEventListener('cancel', (e) => {
    e.preventDefault();
    e.stopPropagation();
  });
  
  // Guard against accidental backdrop clicks closing data forms
  if (opts && opts.backdropClose === true) {
    let isMouseDownOnBackdrop = false;
    modal.addEventListener('mousedown', (e) => {
      isMouseDownOnBackdrop = (e.target === modal);
    });
    modal.addEventListener('mouseup', (e) => {
      if (isMouseDownOnBackdrop && e.target === modal) {
        Modal.close(modal);
      }
      isMouseDownOnBackdrop = false;
    });
  }

  // Push record to stack
  Modal._stack.push({
    element: modal,
    onClose,
    options: opts,
    wrapper: modalWrapper
  });

  document.body.appendChild(modal);

  if (typeof document !== 'undefined' && document.body) {
    document.body.classList.add('modal-open');
    document.body.style.overflow = 'hidden';
  }

  if (typeof modal.showModal === 'function') {
    if (!modal.open) {
      try {
        modal.showModal();
      } catch (err) {
        modal.setAttribute('open', '');
        modal.style.display = 'flex';
      }
    }
  } else {
    modal.setAttribute('open', '');
    modal.style.display = 'flex';
  }

  return modal;
};

Modal.close = function(target) {
  if (!Modal._stack || Modal._stack.length === 0) {
    const dialogs = document.querySelectorAll('dialog, #modal-container, .modal-container, .modal, .modal-backdrop');
    dialogs.forEach(d => {
      try {
        if (typeof d.close === 'function' && d.open) d.close();
        d.removeAttribute('open');
        d.style.display = 'none';
        d.remove();
      } catch (e) {}
    });
    if (typeof document !== 'undefined' && document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.overflow = '';
    }
    return;
  }

  let itemToClose = null;
  if (target) {
    const targetEl = target instanceof HTMLElement ? target : (target && target.element ? target.element : null);
    const idx = Modal._stack.findIndex(item => item.element === targetEl || (targetEl && item.element && item.element.contains(targetEl)));
    if (idx !== -1) {
      itemToClose = Modal._stack.splice(idx, 1)[0];
    }
  }

  if (!itemToClose) {
    // Pop the topmost modal
    itemToClose = Modal._stack.pop();
  }

  if (itemToClose && itemToClose.element) {
    try {
      if (typeof itemToClose.element.close === 'function' && itemToClose.element.open) {
        itemToClose.element.close();
      }
    } catch (e) {}
    try {
      itemToClose.element.removeAttribute('open');
      itemToClose.element.style.display = 'none';
      itemToClose.element.remove();
    } catch (e) {}

    if (typeof itemToClose.onClose === 'function') {
      try {
        itemToClose.onClose();
      } catch (err) {
        console.error('Error in Modal onClose handler:', err);
      }
    }
  }

  // If stack still has items, reactivate the previous top-most modal
  if (Modal._stack.length > 0) {
    const topItem = Modal._stack[Modal._stack.length - 1];
    if (topItem && topItem.element) {
      topItem.element.removeAttribute('aria-hidden');
      topItem.element.style.pointerEvents = '';
      try {
        const focusable = topItem.element.querySelector('input:not([disabled]), select:not([disabled]), textarea:not([disabled]), button:not([disabled]), [tabindex]:not([tabindex="-1"])');
        if (focusable) focusable.focus();
        else topItem.element.focus();
      } catch (e) {}
    }
  } else {
    // Stack is empty -> restore body scroll and remove backdrop
    if (typeof document !== 'undefined' && document.body) {
      document.body.classList.remove('modal-open');
      document.body.style.overflow = '';
    }
    document.querySelectorAll('.modal-backdrop').forEach(el => {
      try { el.remove(); } catch (e) {}
    });
  }
};

Modal.closeAll = function() {
  if (Modal._stack && Modal._stack.length > 0) {
    while (Modal._stack.length > 0) {
      Modal.close();
    }
  }
  const dialogs = document.querySelectorAll('dialog, #modal-container, .modal-container, .modal, .modal-backdrop');
  dialogs.forEach(d => {
    try {
      if (typeof d.close === 'function' && d.open) d.close();
      d.removeAttribute('open');
      d.style.display = 'none';
      d.remove();
    } catch (e) {}
  });
  if (typeof document !== 'undefined' && document.body) {
    document.body.classList.remove('modal-open');
    document.body.style.overflow = '';
  }
};

Modal.hide = function(target) {
  Modal.close(target);
};

// Scoped click listener for Cancel / Close buttons inside modals
if (typeof document !== 'undefined') {
  document.addEventListener('click', (e) => {
    const trigger = e.target.closest('[data-modal-close], [data-close-modal], .modal-close, .modal-close-btn, .modal-cancel, .btn-modal-close, .fb-cancel-modal-btn');
    if (trigger) {
      e.preventDefault();
      e.stopPropagation();
      const parentDialog = trigger.closest('dialog, .modal-container, .modal');
      if (parentDialog) {
        Modal.close(parentDialog);
        return;
      }
      Modal.close();
      return;
    }

    // Handle explicit modal cancel buttons
    const cancelBtn = e.target.closest('.modal-cancel-btn');
    if (cancelBtn) {
      e.preventDefault();
      e.stopPropagation();
      const parentDialog = cancelBtn.closest('dialog, .modal-container, .modal');
      if (parentDialog) {
        Modal.close(parentDialog);
        return;
      }
      Modal.close();
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
  Modal.close(this.element);
};

Modal.prototype.close = function() {
  Modal.close(this.element);
};

/**
 * Universal Modal.confirm supporting Modal.confirm(title, msg, opts) and Modal.confirm(msg, opts)
 */
Modal.confirm = async function(titleOrMsg, msgOrOpts, opts) {
  if (typeof titleOrMsg === 'string' && typeof msgOrOpts === 'string') {
    return await Confirm.show({
      title: titleOrMsg,
      message: msgOrOpts,
      confirmText: opts?.confirmLabel || opts?.confirmText || 'Confirm',
      danger: opts?.confirmClass?.includes('danger') || opts?.danger || false
    });
  } else if (typeof titleOrMsg === 'string') {
    return await Confirm.show({
      message: titleOrMsg,
      confirmText: msgOrOpts?.confirmLabel || msgOrOpts?.confirmText || 'Confirm',
      danger: msgOrOpts?.confirmClass?.includes('danger') || msgOrOpts?.danger || false
    });
  }
  return await Confirm.show(titleOrMsg);
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

  const icon = danger ? '⚠️' : '❓';

  return new Promise(resolve => {
    let resolved = false;
    const finish = (value) => {
      if (!resolved) {
        resolved = true;
        Modal.close();
        resolve(value);
      }
    };

    const confirmBtnClass = danger ? 'btn-danger' : 'btn-primary';
    
    const content = `
      <div style="display: flex; gap: 14px; align-items: flex-start; padding: 4px 0;">
        <div style="font-size: 1.6rem; line-height: 1; flex-shrink: 0; padding-top: 2px;">${icon}</div>
        <div style="flex: 1; color: var(--color-text-secondary, rgba(255,255,255,0.75)); font-size: 0.95rem; line-height: 1.55; font-weight: 500;">
          ${escapeHTML(message)}
        </div>
      </div>
    `;
    
    Modal.show({
      title,
      content,
      size: 'sm',
      buttons: [
        {
          text: cancelText,
          className: 'btn-secondary modal-cancel-btn',
          onClick: () => {
            finish(false);
          }
        },
        {
          text: confirmText,
          className: `${confirmBtnClass} modal-confirm-btn`,
          onClick: async () => {
            finish(true);
            if (typeof onConfirm === 'function') {
              try {
                await onConfirm();
              } catch (e) {
                console.error('onConfirm error:', e);
              }
            }
          }
        }
      ],
      onClose: () => finish(false)
    });
  });
};

export const Loading = {
  _progressInterval: null,
  _progressValue: 0,

  // 1. Top Slim Glowing Progress Bar
  startProgress() {
    let bar = document.getElementById('global-top-progress');
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'global-top-progress';
      bar.className = 'global-top-progress-bar';
      document.body.appendChild(bar);
    }
    clearInterval(this._progressInterval);
    this._progressValue = 15;
    bar.style.width = '15%';
    bar.style.opacity = '1';
    bar.style.display = 'block';

    this._progressInterval = setInterval(() => {
      if (this._progressValue < 85) {
        this._progressValue += Math.random() * 12;
        if (this._progressValue > 85) this._progressValue = 85;
        bar.style.width = `${this._progressValue}%`;
      }
    }, 100);
  },

  doneProgress() {
    clearInterval(this._progressInterval);
    const bar = document.getElementById('global-top-progress');
    if (bar) {
      bar.style.width = '100%';
      setTimeout(() => {
        bar.style.opacity = '0';
        setTimeout(() => {
          bar.style.display = 'none';
          bar.style.width = '0%';
        }, 250);
      }, 150);
    }
  },

  // 2. Standard Central Glassmorphic Page Loader
  showPage(pageName = 'Loading...', subtitle = 'Preparing your workspace...', icon = '⚡') {
    this.startProgress();

    // Check if initial system-preloader exists
    const sysPreloader = document.getElementById('system-preloader');
    if (sysPreloader && sysPreloader.style.display !== 'none') {
      const iconEl = document.getElementById('sys-preloader-icon');
      const titleEl = document.getElementById('sys-preloader-name');
      const subEl = document.getElementById('sys-preloader-sub');
      if (iconEl) iconEl.textContent = icon;
      if (titleEl) titleEl.textContent = pageName;
      if (subEl) subEl.textContent = subtitle;
      return;
    }

    let overlay = document.getElementById('global-page-loader');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'global-page-loader';
      overlay.className = 'global-page-loader-overlay';
      document.body.appendChild(overlay);
    }
    overlay.innerHTML = `
      <div class="page-loader-card">
        <div class="page-loader-ring">
          <span class="page-loader-icon">${icon}</span>
        </div>
        <h3 class="page-loader-title">${escapeHTML(pageName)}</h3>
        <p class="page-loader-subtitle">${escapeHTML(subtitle)}</p>
        <div class="page-loader-bar">
          <div class="page-loader-progress"></div>
        </div>
      </div>
    `;
    overlay.style.opacity = '1';
    overlay.style.visibility = 'visible';
    overlay.style.display = 'flex';
  },

  hidePage() {
    this.doneProgress();

    const sysPreloader = document.getElementById('system-preloader');
    if (sysPreloader) {
      sysPreloader.style.opacity = '0';
      sysPreloader.style.pointerEvents = 'none';
      setTimeout(() => {
        sysPreloader.style.display = 'none';
        try { sysPreloader.remove(); } catch(e) {}
      }, 250);
    }

    const overlay = document.getElementById('global-page-loader');
    if (overlay) {
      overlay.style.opacity = '0';
      overlay.style.pointerEvents = 'none';
      setTimeout(() => {
        overlay.style.display = 'none';
        try { overlay.remove(); } catch(e) {}
      }, 250);
    }
  },

  // 3. Instant Shimmer Skeletons for 0ms Perceived Response
  renderSkeleton(container, type = 'table') {
    if (!container) return;
    if (typeof container === 'string') container = document.querySelector(container);
    if (!container) return;

    if (type === 'dashboard') {
      container.innerHTML = `
        <div class="skeleton-shimmer-container">
          <div class="skeleton-stats-grid">
            <div class="skeleton-card skeleton-stat-box"></div>
            <div class="skeleton-card skeleton-stat-box"></div>
            <div class="skeleton-card skeleton-stat-box"></div>
            <div class="skeleton-card skeleton-stat-box"></div>
          </div>
          <div class="skeleton-main-grid">
            <div class="skeleton-card skeleton-chart-box"></div>
            <div class="skeleton-card skeleton-side-box"></div>
          </div>
        </div>
      `;
    } else if (type === 'seats') {
      container.innerHTML = `
        <div class="skeleton-shimmer-container">
          <div class="skeleton-card skeleton-toolbar"></div>
          <div class="skeleton-seat-grid">
            ${Array.from({ length: 48 }).map(() => '<div class="skeleton-seat-circle"></div>').join('')}
          </div>
        </div>
      `;
    } else {
      // Table / List default
      container.innerHTML = `
        <div class="skeleton-shimmer-container">
          <div class="skeleton-card skeleton-toolbar"></div>
          <div class="skeleton-card skeleton-table-box">
            <div class="skeleton-row skeleton-header-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
            <div class="skeleton-row"></div>
          </div>
        </div>
      `;
    }
  },

  // 4. Modal / Button / Target Loading
  show(target) {
    if (!target) {
      this.showPage('Processing Request...', 'Please wait a moment...', '⚡');
      return;
    }

    if (target instanceof HTMLElement) {
      if (target.tagName === 'BUTTON' || target.classList.contains('btn')) {
        target.classList.add('btn-loading');
        target.disabled = true;
        return;
      }
      target.classList.add('loading-skeleton');
      target.setAttribute('aria-busy', 'true');
      return;
    }

    if (typeof target === 'string') {
      this.showPage('Processing...', target, '⚡');
    }
  },

  hide(target) {
    this.hidePage();
    if (target instanceof HTMLElement) {
      if (target.tagName === 'BUTTON' || target.classList.contains('btn')) {
        target.classList.remove('btn-loading');
        target.disabled = false;
        return;
      }
      target.classList.remove('loading-skeleton');
      target.removeAttribute('aria-busy');
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
      btn.classList.add('btn-loading');
      btn.disabled = true;
    } else {
      btn.classList.remove('btn-loading');
      if (btn.dataset.originalText) btn.innerHTML = btn.dataset.originalText;
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
    { label: 'Attendance', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"></path><rect x="8" y="2" width="8" height="4" rx="1" ry="1"></rect><path d="M9 14l2 2 4-4"></path></svg>', emoji: '📊', href: '#/portal?tab=attendance' },
    { label: 'Renewal', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"></rect><line x1="1" y1="10" x2="23" y2="10"></line></svg>', emoji: '💳', href: '#/portal?tab=renewal' },
    { label: 'ID Pass', icon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"></rect><circle cx="9" cy="10" r="2"></circle><line x1="15" y1="8" x2="17" y2="8"></line><line x1="15" y1="12" x2="17" y2="12"></line><line x1="7" y1="16" x2="17" y2="16"></line></svg>', emoji: '🪪', href: '#/portal?tab=idpass' },
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







// =============================================================================
// FAB - Floating Action Button with speed-dial (context-aware per page)
// =============================================================================
export const FAB = {
  _el: null,
  _scrollHandler: null,
  _outsideClickHandler: null,
  _lastScrollY: 0,
  _isOpen: false,

  /**
   * Mount FAB to page
   * @param {object} config
   *   icon {string}    - Main button emoji/text
   *   label {string}   - Accessibility label
   *   color {string}   - CSS color for main button bg
   *   actions {Array}  - [{ icon, label, onClick }]
   */
  mount(config = {}) {
    this.unmount();
    const { icon = '+', label = 'Quick Actions', color = 'var(--color-primary, #6c5ce7)', actions = [] } = config;

    const fab = document.createElement('div');
    fab.id = 'global-fab';
    fab.className = 'fab-container';
    fab.setAttribute('aria-label', label);

    // Speed-dial menu (appears above main button)
    const speedDial = document.createElement('div');
    speedDial.className = 'fab-speed-dial';
    speedDial.setAttribute('aria-hidden', 'true');

    actions.forEach((action, idx) => {
      const item = document.createElement('button');
      item.className = 'fab-speed-item';
      item.type = 'button';
      item.setAttribute('aria-label', action.label || '');
      item.style.transitionDelay = `${idx * 45}ms`;
      item.innerHTML = `
        <span class="fab-speed-label">${escapeHTML(action.label || '')}</span>
        <span class="fab-speed-icon">${action.icon || '⚡'}</span>
      `;
      
      const fireAction = (e) => {
        if (e) {
          e.preventDefault();
          e.stopPropagation();
        }
        this._closeSpeedDial();
        if (typeof action.onClick === 'function') {
          setTimeout(() => {
            try {
              action.onClick();
            } catch (err) {
              console.error('Error executing FAB action:', err);
            }
          }, 50);
        }
        if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(12);
      };

      item.addEventListener('click', fireAction);
      speedDial.appendChild(item);
    });

    // Main FAB button
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'fab-main-btn';
    btn.setAttribute('aria-expanded', 'false');
    btn.setAttribute('aria-label', label);
    btn.style.background = color;
    btn.innerHTML = `<span class="fab-main-icon">${icon}</span>`;
    btn.onclick = (e) => {
      e.stopPropagation();
      if (this._isOpen) this._closeSpeedDial();
      else this._openSpeedDial();
      if (typeof navigator !== 'undefined' && navigator.vibrate) navigator.vibrate(10);
    };

    fab.appendChild(speedDial);
    fab.appendChild(btn);
    document.body.appendChild(fab);
    this._el = fab;
    this._lastScrollY = window.scrollY;

    // Auto-hide on scroll down, show on scroll up
    let ticking = false;
    this._scrollHandler = () => {
      if (!ticking) {
        requestAnimationFrame(() => {
          const currentY = window.scrollY;
          const diff = currentY - this._lastScrollY;
          if (diff > 60 && currentY > 150) {
            fab.classList.add('fab-hidden');
            this._closeSpeedDial();
          } else if (diff < -20) {
            fab.classList.remove('fab-hidden');
          }
          this._lastScrollY = currentY;
          ticking = false;
        });
        ticking = true;
      }
    };
    window.addEventListener('scroll', this._scrollHandler, { passive: true });

    // Close speed-dial on outside click
    this._outsideClickHandler = (e) => {
      if (this._isOpen && this._el && !this._el.contains(e.target)) {
        this._closeSpeedDial();
      }
    };
    document.addEventListener('click', this._outsideClickHandler);
  },

  _openSpeedDial() {
    if (!this._el) return;
    this._isOpen = true;
    this._el.classList.add('fab-open');
    const mainBtn = this._el.querySelector('.fab-main-btn');
    if (mainBtn) mainBtn.setAttribute('aria-expanded', 'true');
    const speedDial = this._el.querySelector('.fab-speed-dial');
    if (speedDial) speedDial.removeAttribute('aria-hidden');
    const items = this._el.querySelectorAll('.fab-speed-item');
    items.forEach((item, i) => {
      setTimeout(() => item.classList.add('visible'), i * 35);
    });
  },

  _closeSpeedDial() {
    if (!this._el) return;
    this._isOpen = false;
    this._el.classList.remove('fab-open');
    const mainBtn = this._el.querySelector('.fab-main-btn');
    if (mainBtn) mainBtn.setAttribute('aria-expanded', 'false');
    const speedDial = this._el.querySelector('.fab-speed-dial');
    if (speedDial) speedDial.setAttribute('aria-hidden', 'true');
    this._el.querySelectorAll('.fab-speed-item').forEach(item => item.classList.remove('visible'));
  },

  unmount() {
    if (this._el && this._el.parentNode) this._el.remove();
    document.querySelectorAll('#global-fab, .fab-container, .speed-dial-fab').forEach(el => el.remove());
    this._el = null;
    this._isOpen = false;
    if (this._scrollHandler) {
      window.removeEventListener('scroll', this._scrollHandler);
      this._scrollHandler = null;
    }
    if (this._outsideClickHandler) {
      document.removeEventListener('click', this._outsideClickHandler);
      this._outsideClickHandler = null;
    }
  },

  update(config) { this.unmount(); this.mount(config); },
  hide() { if (this._el) this._el.classList.add('fab-hidden'); },
  show() { if (this._el) this._el.classList.remove('fab-hidden'); }
};

// ── Universal 5-Level Action Architecture Menu Helper ──────────
export const ActionMenu = {
  _activeFloatingMenu: null,
  _activeTrigger: null,

  closeAll() {
    if (this._activeFloatingMenu) {
      this._activeFloatingMenu.remove();
      this._activeFloatingMenu = null;
    }
    this._activeTrigger = null;
    document.querySelectorAll('.dropdown.active, .dropdown.open, .dropdown-menu.show').forEach(d => {
      d.classList.remove('active', 'open', 'show');
    });
  },

  /**
   * Renders standardized 5-Level Action dropdown menu button HTML
   */
  renderHtml(actions = [], entityId = '') {
    const encodedActions = encodeURIComponent(JSON.stringify(actions));
    return `
      <div class="dropdown action-menu-wrapper d-inline-block" data-entity-id="${escapeHTML(entityId)}">
        <button type="button" class="btn btn-sm btn-outline-secondary btn-action-menu-trigger dropdown-toggle" data-actions="${encodedActions}" data-entity-id="${escapeHTML(entityId)}" aria-expanded="false" style="padding: 3px 8px; font-size: 0.8rem; font-weight: 700; border-radius: 6px;" title="Universal Actions">
          ⋮ Actions
        </button>
        <ul class="dropdown-menu dropdown-menu-end shadow" style="display: none; min-width: 210px; font-size: 0.84rem; padding: 6px 0; border-radius: 8px; z-index: 1050; background: var(--color-surface); border: 1px solid var(--color-border);">
          ${actions.map(act => {
            if (act.divider) return `<li><hr class="dropdown-divider" style="margin: 4px 0; border-color: var(--color-border);"></li>`;
            if (act.header) return `<li class="dropdown-header text-muted text-uppercase" style="font-size: 0.68rem; font-weight: 800; padding: 4px 14px; letter-spacing: 0.5px; color: var(--color-text-secondary);">${escapeHTML(act.header)}</li>`;
            const icon = act.icon || '⚡';
            const label = act.label || '';
            const actionKey = act.action || act.id || '';
            const isDanger = act.danger ? 'text-danger' : '';
            return `
              <li>
                <a class="dropdown-item d-flex align-items-center gap-2 ${isDanger} action-menu-item" href="#" data-action="${escapeHTML(actionKey)}" data-id="${escapeHTML(entityId)}" style="padding: 6px 14px; cursor: pointer; color: var(--color-text-primary);">
                  <span style="font-size: 1rem; width: 20px; text-align: center;">${icon}</span>
                  <span style="flex-grow: 1; font-weight: ${act.bold ? '700' : '500'};">${escapeHTML(label)}</span>
                  ${act.badge ? `<span class="badge badge-sm" style="font-size: 0.65rem; background: rgba(108,92,231,0.15); color: var(--color-primary);">${escapeHTML(act.badge)}</span>` : ''}
                </a>
              </li>
            `;
          }).join('')}
        </ul>
      </div>
    `;
  },

  /**
   * Displays a floating menu portal attached to document.body to prevent table overflow clipping
   */
  showFloatingMenu(triggerBtn, actions, entityId) {
    this.closeAll();
    if (!actions || !actions.length) return;

    const executeAction = (action, id) => {
      // 1. Direct search inside dropdown menu
      const directCandidates = [
        triggerBtn.parentElement?.querySelector(`.action-menu-item[data-action="${action}"]`),
        triggerBtn.closest('.dropdown, .action-menu-wrapper, tr, td')?.querySelector(`.action-menu-item[data-action="${action}"]`),
        document.querySelector(`.dropdown[data-entity-id="${id}"] .action-menu-item[data-action="${action}"]`),
        document.querySelector(`.action-menu-item[data-id="${id}"][data-action="${action}"]`)
      ];

      for (const targetEl of directCandidates) {
        if (targetEl) {
          try {
            targetEl.click();
            return;
          } catch (_) {}
        }
      }

      // 2. Dispatch custom action event on triggerBtn & document
      const detail = { action, id, entityId: id, trigger: triggerBtn };
      const customEvt = new CustomEvent('action-menu-select', { bubbles: true, cancelable: true, detail });
      triggerBtn.dispatchEvent(customEvt);
      document.dispatchEvent(new CustomEvent('action-menu-select', { bubbles: true, cancelable: true, detail }));

      // 3. Fallback: Dispatch synthetic click on parent row or container
      const rowOrCard = triggerBtn.closest('tr, .card, .portal-card, #page-content');
      if (rowOrCard) {
        const dummy = document.createElement('span');
        dummy.className = 'action-menu-item';
        dummy.dataset.action = action;
        dummy.dataset.id = id;
        dummy.style.display = 'none';
        rowOrCard.appendChild(dummy);
        try {
          dummy.click();
        } finally {
          setTimeout(() => dummy.remove(), 100);
        }
      }
    };

    // Mobile fallback: On screens <= 768px, display bottom sheet
    if (window.innerWidth <= 768 && typeof BottomSheet !== 'undefined' && BottomSheet.show) {
      const sheetContent = `
        <div style="padding: 0.5rem 0;">
          <div style="font-weight: 800; font-size: 0.95rem; margin-bottom: 10px; padding: 0 16px; color: var(--color-primary); display: flex; align-items: center; justify-content: space-between;">
            <span>⚡ Quick Actions</span>
            ${entityId ? `<span class="badge badge-secondary" style="font-size: 0.7rem; font-family: monospace;">${escapeHTML(entityId.slice(-6))}</span>` : ''}
          </div>
          <div style="display: flex; flex-direction: column;">
            ${actions.map(act => {
              if (act.divider) return `<hr style="margin: 4px 0; border-color: var(--color-border);">`;
              if (act.header) return `<div style="font-size: 0.7rem; font-weight: 800; text-transform: uppercase; color: var(--color-text-muted); padding: 8px 16px 2px;">${escapeHTML(act.header)}</div>`;
              const icon = act.icon || '⚡';
              const label = act.label || '';
              const actionKey = act.action || act.id || '';
              const isDanger = act.danger ? 'color: var(--color-danger, #ef4444);' : 'color: var(--color-text-primary);';
              return `
                <button type="button" class="btn-mobile-sheet-action action-menu-item" data-action="${escapeHTML(actionKey)}" data-id="${escapeHTML(entityId)}" style="display: flex; align-items: center; gap: 12px; width: 100%; text-align: left; padding: 14px 18px; border: none; background: transparent; ${isDanger} font-size: 0.96rem; font-weight: 600; cursor: pointer; touch-action: manipulation; -webkit-tap-highlight-color: transparent; border-bottom: 1px solid var(--color-divider, #f1f5f9);">
                  <span style="font-size: 1.25rem; width: 26px; text-align: center; flex-shrink: 0;">${icon}</span>
                  <span style="flex-grow: 1; font-weight: ${act.bold ? '700' : '600'};">${escapeHTML(label)}</span>
                  ${act.badge ? `<span class="badge badge-sm" style="font-size: 0.7rem; background: rgba(108,92,231,0.15); color: var(--color-primary);">${escapeHTML(act.badge)}</span>` : ''}
                </button>
              `;
            }).join('')}
          </div>
        </div>
      `;
      const sheet = BottomSheet.show({
        title: 'Select Action',
        content: sheetContent,
        height: 'auto'
      });

      const sheetEl = document.getElementById('bottom-sheet');
      if (sheetEl) {
        sheetEl.addEventListener('click', (e) => {
          const item = e.target.closest('.action-menu-item, .btn-mobile-sheet-action');
          if (!item) return;
          e.preventDefault();
          e.stopPropagation();
          const action = item.dataset.action;
          const id = item.dataset.id || entityId;
          if (sheet && sheet.close) sheet.close();
          executeAction(action, id);
        });
      }
      return;
    }

    // Desktop & Tablet Floating Portal Menu
    const floating = document.createElement('div');
    floating.id = 'floating-action-menu-portal';
    floating.className = 'floating-action-menu-portal shadow-lg';
    floating.style.cssText = `
      position: fixed;
      z-index: 999999;
      background: var(--color-surface, #ffffff);
      border: 1px solid var(--color-border, #e2e8f0);
      border-radius: 8px;
      box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.35), 0 8px 10px -6px rgba(0, 0, 0, 0.2);
      min-width: 210px;
      max-width: 280px;
      padding: 6px 0;
      font-size: 0.84rem;
      user-select: none;
      animation: fadeIn 0.12s ease-out;
    `;

    floating.innerHTML = `
      <ul style="list-style: none; margin: 0; padding: 0;">
        ${actions.map(act => {
          if (act.divider) return `<li style="margin: 4px 0; border-top: 1px solid var(--color-border, #e2e8f0);"></li>`;
          if (act.header) return `<li style="font-size: 0.66rem; font-weight: 800; padding: 4px 14px; text-transform: uppercase; letter-spacing: 0.5px; color: var(--color-text-secondary, #64748b);">${escapeHTML(act.header)}</li>`;
          const icon = act.icon || '⚡';
          const label = act.label || '';
          const actionKey = act.action || act.id || '';
          const isDanger = act.danger ? 'color: var(--color-danger, #ef4444);' : 'color: var(--color-text-primary, #1e293b);';
          return `
            <li>
              <a href="#" class="floating-action-item action-menu-item" data-action="${escapeHTML(actionKey)}" data-id="${escapeHTML(entityId)}" style="display: flex; align-items: center; gap: 8px; padding: 8px 14px; text-decoration: none; ${isDanger} transition: background 0.12s; cursor: pointer;">
                <span style="font-size: 0.95rem; width: 18px; text-align: center;">${icon}</span>
                <span style="flex-grow: 1; font-weight: ${act.bold ? '700' : '500'}; white-space: nowrap;">${escapeHTML(label)}</span>
                ${act.badge ? `<span class="badge badge-sm" style="font-size: 0.65rem; background: rgba(108,92,231,0.15); color: var(--color-primary);">${escapeHTML(act.badge)}</span>` : ''}
              </a>
            </li>
          `;
        }).join('')}
      </ul>
    `;

    document.body.appendChild(floating);
    this._activeFloatingMenu = floating;
    this._activeTrigger = triggerBtn;

    // Hover styling on menu items
    floating.querySelectorAll('.floating-action-item').forEach(item => {
      item.addEventListener('mouseenter', () => {
        item.style.backgroundColor = 'var(--color-bg-secondary, rgba(108,92,231,0.08))';
      });
      item.addEventListener('mouseleave', () => {
        item.style.backgroundColor = 'transparent';
      });
    });

    // Calculate position
    const rect = triggerBtn.getBoundingClientRect();
    const floatingRect = floating.getBoundingClientRect();
    
    let left = rect.right - floatingRect.width;
    if (left < 10) left = 10;
    if (left + floatingRect.width > window.innerWidth - 10) {
      left = window.innerWidth - floatingRect.width - 10;
    }

    let top = rect.bottom + 4;
    if (top + floatingRect.height > window.innerHeight - 10) {
      top = rect.top - floatingRect.height - 4;
    }

    floating.style.left = `${Math.max(0, left)}px`;
    floating.style.top = `${Math.max(0, top)}px`;

    // Click handler for floating action items
    floating.addEventListener('click', (e) => {
      const item = e.target.closest('.action-menu-item');
      if (!item) return;
      e.preventDefault();
      e.stopPropagation();

      const action = item.dataset.action;
      const id = item.dataset.id || entityId;
      ActionMenu.closeAll();
      executeAction(action, id);
    });
  },

  /**
   * Bind event delegation on a container for action menu clicks
   */
  bind(container, handler) {
    if (!container || typeof handler !== 'function') return;
    container.addEventListener('click', (e) => {
      const item = e.target.closest('.action-menu-item');
      if (!item) return;
      e.preventDefault();
      e.stopPropagation();
      const action = item.dataset.action;
      const id = item.dataset.id;
      handler(action, id, item);
    });
    container.addEventListener('action-menu-select', (e) => {
      if (e.detail && e.detail.action) {
        handler(e.detail.action, e.detail.id, e.detail.trigger);
      }
    });
  }
};

// Global Event Listeners for ActionMenu triggers
if (typeof document !== 'undefined') {
  document.addEventListener('click', (e) => {
    const trigger = e.target.closest('.btn-action-menu-trigger, [data-bs-toggle="dropdown"]');
    if (trigger) {
      e.preventDefault();
      e.stopPropagation();

      // If clicking the currently open trigger, toggle it off
      if (ActionMenu._activeTrigger === trigger) {
        ActionMenu.closeAll();
        return;
      }

      let actions = [];
      const actionsData = trigger.getAttribute('data-actions');
      if (actionsData) {
        try { actions = JSON.parse(decodeURIComponent(actionsData)); } catch(err) {}
      }

      if (!actions || !actions.length) {
        const menu = trigger.parentElement?.querySelector('.dropdown-menu');
        if (menu) {
          menu.querySelectorAll('.action-menu-item').forEach(el => {
            actions.push({
              action: el.dataset.action,
              id: el.dataset.id,
              label: el.textContent.trim(),
              danger: el.classList.contains('text-danger')
            });
          });
        }
      }

      const entityId = trigger.getAttribute('data-entity-id') || trigger.closest('[data-entity-id]')?.dataset.entityId || '';
      ActionMenu.showFloatingMenu(trigger, actions, entityId);
      return;
    }

    // Outside click closes active floating menu
    if (!e.target.closest('#floating-action-menu-portal, #bottom-sheet')) {
      ActionMenu.closeAll();
    }
  });

  window.addEventListener('resize', () => ActionMenu.closeAll());
  window.addEventListener('scroll', () => ActionMenu.closeAll(), { passive: true });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') ActionMenu.closeAll();
  });
}

/**
 * Virtual Keyboard Viewport Responsiveness Listener
 * Detects mobile on-screen virtual keyboard toggle and adapts the layout.
 */
export function initVisualViewportKeyboardListener() {
  if (typeof window === 'undefined') return;

  const updateKeyboardState = () => {
    if (window.visualViewport) {
      // If visual viewport height is < 75% of window.innerHeight, virtual keyboard is open
      const isKeyboardOpen = window.visualViewport.height < (window.innerHeight * 0.75);
      if (isKeyboardOpen) {
        document.body.classList.add('virtual-keyboard-open');
      } else {
        document.body.classList.remove('virtual-keyboard-open');
      }
    }
  };

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', updateKeyboardState);
    window.visualViewport.addEventListener('scroll', updateKeyboardState);
  }

  // Fallback focus listeners for mobile browsers
  window.addEventListener('focusin', (e) => {
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT')) {
      if (window.innerWidth <= 768) {
        setTimeout(updateKeyboardState, 150);
      }
    }
  });

  window.addEventListener('focusout', () => {
    if (window.innerWidth <= 768) {
      setTimeout(updateKeyboardState, 150);
    }
  });

  // Initial check
  updateKeyboardState();
}

if (typeof window !== 'undefined') {
  window.Toast = Toast;
  window.Modal = Modal;
  window.Modal.closeAll = Modal.closeAll;
  window.Modal.close = Modal.close;
  window.Modal.hide = Modal.hide;
  window.Modal.confirm = Modal.confirm;
  window.Confirm = Confirm;
  window.Loading = Loading;
  window.BottomSheet = BottomSheet;
  window.FAB = FAB;
  window.ActionMenu = ActionMenu;
  window.initPullToRefresh = initPullToRefresh;
  window.initVisualViewportKeyboardListener = initVisualViewportKeyboardListener;
  window.PDFExport = PDFExport;
  window.VoiceSearch = VoiceSearch;
  window.renderMobileBottomNav = renderMobileBottomNav;

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => initVisualViewportKeyboardListener());
  } else {
    initVisualViewportKeyboardListener();
  }
}
