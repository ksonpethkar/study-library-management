import { Modal, BottomSheet } from '../ui.js';

/**
 * KeyboardShortcuts Utility
 * Global keyboard shortcuts listener for system-wide user actions.
 */
export class KeyboardShortcuts {
  /**
   * Initializes global keydown event listener.
   */
  static init() {
    if (typeof window === 'undefined') return;
    if (window._keyboardShortcutsInit) return;
    window._keyboardShortcutsInit = true;

    document.addEventListener('keydown', (e) => {
      const isCtrlOrCmd = e.ctrlKey || e.metaKey;
      const key = e.key ? e.key.toLowerCase() : '';

      // 1. Ctrl+K / Cmd+K: Triggers global search command palette
      if (isCtrlOrCmd && key === 'k') {
        e.preventDefault();
        if (window.App && window.App.searchPalette) {
          window.App.searchPalette.toggle();
        } else {
          const globalSearchBtn = document.getElementById('global-search-btn');
          if (globalSearchBtn) {
            globalSearchBtn.click();
          }
        }
        return;
      }

      // 2. Ctrl+S / Cmd+S: Triggers primary form save button on current page
      if (isCtrlOrCmd && key === 's') {
        e.preventDefault();
        const primaryBtn = document.querySelector(
          'form button[type="submit"]:not([disabled]), form .btn-primary:not([disabled]), dialog[open] button.btn-primary:not([disabled]), dialog[open] button[type="submit"]:not([disabled]), .modal button.btn-primary:not([disabled]), #save-btn:not([disabled]), .btn-save:not([disabled])'
        );
        if (primaryBtn) {
          primaryBtn.click();
        }
        return;
      }

      // 3. Esc: Closes any open modal dialog or bottom sheet
      if (e.key === 'Escape' || e.key === 'Esc') {
        if (window.App && window.App.searchPalette && window.App.searchPalette.isOpen) {
          window.App.searchPalette.close();
        }
        Modal.closeAll();
        BottomSheet.close();
        return;
      }

      // 4. Ctrl+P / Cmd+P: Triggers print preview on receipts or admission slips
      if (isCtrlOrCmd && key === 'p') {
        e.preventDefault();
        const printBtn = document.querySelector(
          '#btn-pdf-modal-print, .btn-print-receipt, #btn-print-receipt, .btn-print, [data-action="print"], button.print-btn'
        );
        if (printBtn) {
          printBtn.click();
        } else {
          const receiptEl = document.querySelector('#receipt-modal-content, #receipt-content, .receipt-card, #admission-form-preview, .printable-receipt');
          if (receiptEl && window.PDFExport) {
            window.PDFExport.printElement(receiptEl.id || 'receipt-content', 'Receipt Print');
          } else {
            window.print();
          }
        }
        return;
      }
    });
  }
}

// Auto-initialize when loaded in browser environment
if (typeof window !== 'undefined') {
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => KeyboardShortcuts.init());
  } else {
    KeyboardShortcuts.init();
  }
}

export default KeyboardShortcuts;
