/**
 * FormDrafts Utility
 * Automatically saves, restores, and clears form input drafts in localStorage.
 */
export class FormDrafts {
  /**
   * Get storage key for a formKey
   * @param {string} formKey
   * @returns {string}
   */
  static getStorageKey(formKey) {
    return `form_draft_${formKey}`;
  }

  /**
   * Extract current input values from a form element
   * @param {HTMLFormElement|HTMLElement} form
   * @returns {Object}
   */
  static getFormData(form) {
    if (!form) return {};
    const data = {};
    const elements = form.querySelectorAll('input, select, textarea');

    elements.forEach(el => {
      const key = el.name || el.id;
      if (!key) return;
      if (el.type === 'password' || el.type === 'file' || el.type === 'submit' || el.type === 'button' || el.type === 'reset') {
        return;
      }

      if (el.type === 'checkbox') {
        data[key] = el.checked;
      } else if (el.type === 'radio') {
        if (el.checked) {
          data[key] = el.value;
        }
      } else {
        data[key] = el.value;
      }
    });

    return data;
  }

  /**
   * Automatically saves form inputs to localStorage on input changes.
   * @param {HTMLFormElement|HTMLElement|string} formEl - Form DOM element or CSS selector
   * @param {string} formKey - Unique identifier for the form draft
   */
  static autoSave(formEl, formKey) {
    if (typeof window === 'undefined' || !formKey) return;
    const form = typeof formEl === 'string' ? document.querySelector(formEl) : formEl;
    if (!form) return;

    const storageKey = this.getStorageKey(formKey);

    const save = () => {
      try {
        const data = this.getFormData(form);
        localStorage.setItem(storageKey, JSON.stringify(data));
      } catch (err) {
        console.warn('[FormDrafts] AutoSave error:', err);
      }
    };

    let timer = null;
    const handleInput = () => {
      clearTimeout(timer);
      timer = setTimeout(save, 300);
    };

    form.addEventListener('input', handleInput);
    form.addEventListener('change', save);
  }

  /**
   * Restores draft inputs if user re-opens form.
   * @param {HTMLFormElement|HTMLElement|string} formEl - Form DOM element or CSS selector
   * @param {string} formKey - Unique identifier for the form draft
   * @returns {boolean} true if draft was restored, false otherwise
   */
  static restore(formEl, formKey) {
    if (typeof window === 'undefined' || !formKey) return false;
    const form = typeof formEl === 'string' ? document.querySelector(formEl) : formEl;
    if (!form) return false;

    const storageKey = this.getStorageKey(formKey);
    try {
      const raw = localStorage.getItem(storageKey);
      if (!raw) return false;

      const data = JSON.parse(raw);
      if (!data || typeof data !== 'object') return false;

      let restoredCount = 0;
      Object.keys(data).forEach(key => {
        const val = data[key];
        const safeKey = String(key).replace(/([#;?&,.+*~':"!^$[\]()=>|\/\\])/g, '\\$1');
        const elements = form.querySelectorAll(`[name="${safeKey}"], #${safeKey}`);

        elements.forEach(el => {
          if (el.type === 'password' || el.type === 'file') return;

          if (el.type === 'checkbox') {
            el.checked = Boolean(val);
          } else if (el.type === 'radio') {
            el.checked = (el.value === val);
          } else {
            el.value = val !== null && val !== undefined ? val : '';
          }

          el.dispatchEvent(new Event('input', { bubbles: true }));
          el.dispatchEvent(new Event('change', { bubbles: true }));
          restoredCount++;
        });
      });

      return restoredCount > 0;
    } catch (err) {
      console.warn('[FormDrafts] Restore error:', err);
      return false;
    }
  }

  /**
   * Clears draft upon successful submission.
   * @param {string} formKey - Unique identifier for the form draft
   */
  static clear(formKey) {
    if (typeof window === 'undefined' || !formKey) return;
    const storageKey = this.getStorageKey(formKey);
    try {
      localStorage.removeItem(storageKey);
    } catch (err) {
      console.warn('[FormDrafts] Clear error:', err);
    }
  }
}

if (typeof window !== 'undefined') {
  window.FormDrafts = FormDrafts;
}

export default FormDrafts;
