/**
 * Performance Monitor — Client-side APM for Study Library Management System
 * Tracks page loads, API calls, memory, errors, and renders a health widget
 */

const PerformanceMonitor = {
  _metrics: {
    pageLoads: [],      // { page, duration, timestamp }
    apiCalls: [],       // { endpoint, method, duration, status, timestamp }
    errors: 0,
    sessionStart: Date.now(),
    navigationCount: 0
  },
  _maxEntries: 100,

  init() {
    // Track Navigation Timing API on page load
    if (window.performance && window.performance.timing) {
      window.addEventListener('load', () => {
        setTimeout(() => {
          const timing = performance.timing;
          const pageLoad = timing.loadEventEnd - timing.navigationStart;
          const domReady = timing.domContentLoadedEventEnd - timing.navigationStart;
          const ttfb = timing.responseStart - timing.navigationStart;
          this._metrics.initialLoad = { pageLoad, domReady, ttfb };
          console.log(`[PerfMon] Initial load: ${pageLoad}ms (DOM ready: ${domReady}ms, TTFB: ${ttfb}ms)`);
        }, 100);
      });
    }

    // Intercept fetch to auto-track API response times
    this._patchFetch();

    console.log('[PerformanceMonitor] Initialized');
  },

  _patchFetch() {
    const originalFetch = window.fetch;
    const self = this;
    window.fetch = async function(...args) {
      const url = typeof args[0] === 'string' ? args[0] : args[0]?.url || '';
      const method = args[1]?.method || 'GET';
      
      // Only track API calls (not CDN/external)
      const isApi = url.startsWith('/api/') || url.startsWith('api/');
      if (!isApi) return originalFetch.apply(this, args);

      const start = performance.now();
      try {
        const response = await originalFetch.apply(this, args);
        const duration = Math.round(performance.now() - start);
        self._trackApiCall(url, method, duration, response.status);
        return response;
      } catch (error) {
        const duration = Math.round(performance.now() - start);
        self._trackApiCall(url, method, duration, 0);
        throw error;
      }
    };
  },

  _trackApiCall(endpoint, method, duration, status) {
    const entry = {
      endpoint: endpoint.split('?')[0], // strip query params
      method: method.toUpperCase(),
      duration,
      status,
      timestamp: Date.now()
    };
    this._metrics.apiCalls.push(entry);
    if (this._metrics.apiCalls.length > this._maxEntries) {
      this._metrics.apiCalls.shift();
    }
    // Warn on slow API calls
    if (duration > 3000) {
      console.warn(`[PerfMon] Slow API: ${method} ${endpoint} took ${duration}ms`);
    }
  },

  trackPageLoad(pageName, duration) {
    this._metrics.navigationCount++;
    this._metrics.pageLoads.push({
      page: pageName,
      duration: Math.round(duration),
      timestamp: Date.now()
    });
    if (this._metrics.pageLoads.length > this._maxEntries) {
      this._metrics.pageLoads.shift();
    }
  },

  // Get summary stats
  getStats() {
    const apiCalls = this._metrics.apiCalls;
    const pageLoads = this._metrics.pageLoads;
    const now = Date.now();
    const sessionDuration = Math.round((now - this._metrics.sessionStart) / 1000);

    // API stats (last 5 minutes)
    const recentApi = apiCalls.filter(a => now - a.timestamp < 300000);
    const avgApiTime = recentApi.length > 0 
      ? Math.round(recentApi.reduce((sum, a) => sum + a.duration, 0) / recentApi.length)
      : 0;
    const slowApis = recentApi.filter(a => a.duration > 2000).length;
    const failedApis = recentApi.filter(a => a.status === 0 || a.status >= 500).length;

    // Page load stats
    const avgPageLoad = pageLoads.length > 0
      ? Math.round(pageLoads.reduce((sum, p) => sum + p.duration, 0) / pageLoads.length)
      : 0;

    // Memory (if available)
    let memoryMB = null;
    if (performance.memory) {
      memoryMB = Math.round(performance.memory.usedJSHeapSize / 1048576);
    }

    // Error count from ErrorBoundary
    const errorCount = window.ErrorBoundary?.getErrorCount?.() || 0;

    return {
      sessionDuration,
      navigationCount: this._metrics.navigationCount,
      totalApiCalls: apiCalls.length,
      avgApiTime,
      slowApis,
      failedApis,
      avgPageLoad,
      memoryMB,
      errorCount,
      initialLoad: this._metrics.initialLoad || null
    };
  },

  // Get health score (0-100)
  getHealthScore() {
    const stats = this.getStats();
    let score = 100;

    // Deduct for slow API average
    if (stats.avgApiTime > 2000) score -= 20;
    else if (stats.avgApiTime > 1000) score -= 10;
    else if (stats.avgApiTime > 500) score -= 5;

    // Deduct for failed APIs
    score -= Math.min(30, stats.failedApis * 10);

    // Deduct for errors
    score -= Math.min(20, stats.errorCount * 5);

    // Deduct for high memory
    if (stats.memoryMB && stats.memoryMB > 200) score -= 10;
    if (stats.memoryMB && stats.memoryMB > 500) score -= 20;

    return Math.max(0, Math.min(100, score));
  },

  // Render system health widget HTML (for dashboard)
  renderHealthWidget() {
    const stats = this.getStats();
    const score = this.getHealthScore();
    const scoreColor = score >= 80 ? 'var(--color-success)' : score >= 50 ? 'var(--color-warning)' : 'var(--color-danger)';
    const scoreLabel = score >= 80 ? 'Healthy' : score >= 50 ? 'Fair' : 'Degraded';

    const formatDuration = (s) => {
      if (s < 60) return `${s}s`;
      if (s < 3600) return `${Math.floor(s / 60)}m ${s % 60}s`;
      return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
    };

    return `
      <div class="card fade-in-up" style="padding: 20px;">
        <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 16px;">
          <h4 style="margin: 0; font-size: 0.95rem; font-weight: 700; color: var(--color-text-primary);">⚡ System Health</h4>
          <span style="font-size: 0.78rem; font-weight: 700; color: ${scoreColor}; background: ${scoreColor}15; padding: 3px 10px; border-radius: 20px;">${score}/100 ${scoreLabel}</span>
        </div>
        <div style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px;">
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: var(--color-text-primary);">${stats.avgApiTime}<span style="font-size: 0.7rem; font-weight: 500;">ms</span></div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">Avg API Response</div>
          </div>
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: var(--color-text-primary);">${stats.totalApiCalls}</div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">API Calls</div>
          </div>
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: ${stats.errorCount > 0 ? 'var(--color-danger)' : 'var(--color-success)'};">${stats.errorCount}</div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">JS Errors</div>
          </div>
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary);">
            <div style="font-size: 1.2rem; font-weight: 800; color: var(--color-text-primary);">${formatDuration(stats.sessionDuration)}</div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">Session</div>
          </div>
          ${stats.memoryMB !== null ? `
          <div style="text-align: center; padding: 10px; border-radius: 10px; background: var(--color-bg-secondary); grid-column: span 2;">
            <div style="font-size: 1.2rem; font-weight: 800; color: ${stats.memoryMB > 200 ? 'var(--color-warning)' : 'var(--color-text-primary)'};">${stats.memoryMB}<span style="font-size: 0.7rem; font-weight: 500;">MB</span></div>
            <div style="font-size: 0.72rem; color: var(--color-text-muted); margin-top: 2px;">Memory Usage</div>
          </div>` : ''}
        </div>
        ${stats.slowApis > 0 || stats.failedApis > 0 ? `
        <div style="margin-top: 12px; padding: 8px 12px; border-radius: 8px; background: var(--color-warning-bg); font-size: 0.78rem; color: var(--color-warning-dark);">
          ⚠️ ${stats.slowApis} slow + ${stats.failedApis} failed API calls in last 5 min
        </div>` : ''}
      </div>
    `;
  }
};

export { PerformanceMonitor };
export default PerformanceMonitor;
window.PerformanceMonitor = PerformanceMonitor;
