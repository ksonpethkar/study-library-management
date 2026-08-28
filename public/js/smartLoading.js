/**
 * Smart Loading System
 * Provides skeleton screens, progress bar, and stagger animations
 */

const SmartLoading = {
  _progressBar: null,
  _activeCount: 0,

  init() {
    // Create top progress bar
    if (!document.querySelector('.loading-progress-bar')) {
      this._progressBar = document.createElement('div');
      this._progressBar.className = 'loading-progress-bar';
      document.body.prepend(this._progressBar);
    } else {
      this._progressBar = document.querySelector('.loading-progress-bar');
    }
    console.log('[SmartLoading] Initialized');
  },

  // Show top progress bar
  startProgress() {
    this._activeCount++;
    if (this._progressBar) {
      this._progressBar.classList.add('active');
    }
  },

  // Hide top progress bar  
  stopProgress() {
    this._activeCount = Math.max(0, this._activeCount - 1);
    if (this._activeCount === 0 && this._progressBar) {
      this._progressBar.classList.remove('active');
    }
  },

  // Generate skeleton rows for a table
  skeletonTableRows(count = 5, columns = 4) {
    let html = '';
    for (let i = 0; i < count; i++) {
      html += '<div class="skeleton-table-row stagger-enter">';
      for (let j = 0; j < columns; j++) {
        html += '<div class="skeleton skeleton-cell"></div>';
      }
      html += '</div>';
    }
    return html;
  },

  // Generate skeleton stat cards
  skeletonStatCards(count = 4) {
    let html = '<div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 20px;">';
    for (let i = 0; i < count; i++) {
      html += `
        <div class="skeleton-stat-card stagger-enter">
          <div class="skeleton skeleton-text short" style="margin-bottom: 12px;"></div>
          <div class="skeleton skeleton-text" style="height: 28px; width: 50%; margin-bottom: 8px;"></div>
          <div class="skeleton skeleton-text medium"></div>
        </div>`;
    }
    html += '</div>';
    return html;
  },

  // Apply stagger animation to existing child elements
  staggerChildren(parentEl, className = 'stagger-enter') {
    if (!parentEl) return;
    const children = parentEl.children;
    for (let i = 0; i < children.length; i++) {
      children[i].classList.add(className);
    }
  },

  // Animate stat number count-up
  animateStatNumber(el, targetNumber, duration = 600) {
    if (!el) return;
    const start = 0;
    const startTime = performance.now();
    const format = (n) => {
      if (n >= 10000) return (n / 1000).toFixed(1) + 'K';
      return n.toLocaleString();
    };
    
    const step = (currentTime) => {
      const elapsed = currentTime - startTime;
      const progress = Math.min(elapsed / duration, 1);
      // Ease out cubic
      const eased = 1 - Math.pow(1 - progress, 3);
      const current = Math.round(start + (targetNumber - start) * eased);
      el.textContent = format(current);
      if (progress < 1) {
        requestAnimationFrame(step);
      }
    };
    el.classList.add('stat-count-enter');
    requestAnimationFrame(step);
  }
};

export { SmartLoading };
export default SmartLoading;
window.SmartLoading = SmartLoading;
