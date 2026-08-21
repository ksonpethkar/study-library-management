/**
 * ChartEngine — Wrapper around Chart.js v4 (loaded from CDN in index.html)
 * Falls back to raw Canvas 2D if Chart.js is not available.
 *
 * Phase 7: upgraded to use Chart.js for beautiful, interactive charts.
 */

// Chart.js instance registry — destroy before re-rendering same canvas
const _chartInstances = new Map();

function _getChartJS() {
  return window.Chart || null;
}

function _destroyExisting(canvasId) {
  if (_chartInstances.has(canvasId)) {
    try { _chartInstances.get(canvasId).destroy(); } catch (e) {}
    _chartInstances.delete(canvasId);
  }
}

// Shared dark-mode defaults for Chart.js
const CHART_DEFAULTS = {
  color: '#94a3b8',
  borderColor: 'rgba(255,255,255,0.08)',
  font: { family: "'Outfit', system-ui, sans-serif", size: 11 },
};

export class ChartEngine {
  /**
   * Revenue trend — gradient area line chart
   */
  static lineChart(canvasId, { labels, data, color = '#6c5ce7', fill = false, title } = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    _destroyExisting(canvasId);

    const CJS = _getChartJS();
    if (CJS) {
      const ctx = canvas.getContext('2d');
      const gradient = ctx.createLinearGradient(0, 0, 0, canvas.offsetHeight || 220);
      gradient.addColorStop(0, color + '55');
      gradient.addColorStop(1, color + '00');

      const instance = new CJS(ctx, {
        type: 'line',
        data: {
          labels,
          datasets: [{
            label: title || 'Value',
            data,
            borderColor: color,
            borderWidth: 2.5,
            backgroundColor: fill ? gradient : 'transparent',
            fill,
            tension: 0.45,
            pointBackgroundColor: color,
            pointRadius: 3,
            pointHoverRadius: 6,
          }]
        },
        options: {
          responsive: true, maintainAspectRatio: false,
          animation: { duration: 600, easing: 'easeOutQuart' },
          plugins: {
            legend: { display: false },
            tooltip: {
              backgroundColor: '#1e293b',
              borderColor: 'rgba(255,255,255,0.1)',
              borderWidth: 1,
              titleColor: '#e2e8f0',
              bodyColor: '#94a3b8',
              padding: 10,
              cornerRadius: 8,
            }
          },
          scales: {
            x: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#64748b', font: CHART_DEFAULTS.font } },
            y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#64748b', font: CHART_DEFAULTS.font } }
          }
        }
      });
      _chartInstances.set(canvasId, instance);
      return instance;
    }

    // Fallback raw canvas
    return this._rawLine(canvas, { labels, data, color, fill });
  }

  /**
   * Doughnut chart — payment method distribution or occupancy gauge
   */
  static doughnutChart(canvasId, { labels, data, colors, title } = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    _destroyExisting(canvasId);

    const CJS = _getChartJS();
    if (CJS) {
      const ctx = canvas.getContext('2d');
      const instance = new CJS(ctx, {
        type: 'doughnut',
        data: {
          labels,
          datasets: [{
            data,
            backgroundColor: colors || ['#6c5ce7','#00b894','#0984e3','#fd79a8','#fdcb6e'],
            borderWidth: 0,
            hoverOffset: 8,
          }]
        },
        options: {
          responsive: true, maintainAspectRatio: false,
          cutout: '72%',
          animation: { animateRotate: true, duration: 700 },
          plugins: {
            legend: {
              position: 'bottom',
              labels: { color: '#94a3b8', font: CHART_DEFAULTS.font, padding: 12, boxWidth: 10 }
            },
            tooltip: {
              backgroundColor: '#1e293b',
              borderColor: 'rgba(255,255,255,0.1)',
              borderWidth: 1,
              titleColor: '#e2e8f0',
              bodyColor: '#94a3b8',
              padding: 10,
              cornerRadius: 8,
            }
          }
        }
      });
      _chartInstances.set(canvasId, instance);
      return instance;
    }

    // Fallback raw canvas
    return this._rawDoughnut(canvas, { data, colors });
  }

  /**
   * Bar chart — monthly revenue or expense comparison
   */
  static barChart(canvasId, { labels, data, color = '#6c5ce7', title, datasets } = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    _destroyExisting(canvasId);

    const CJS = _getChartJS();
    if (CJS) {
      const ctx = canvas.getContext('2d');
      const chartDatasets = datasets || [{
        label: title || 'Amount',
        data,
        backgroundColor: color + 'cc',
        borderColor: color,
        borderWidth: 1.5,
        borderRadius: 6,
        hoverBackgroundColor: color,
      }];

      const instance = new CJS(ctx, {
        type: 'bar',
        data: { labels, datasets: chartDatasets },
        options: {
          responsive: true, maintainAspectRatio: false,
          animation: { duration: 500, easing: 'easeOutQuart' },
          plugins: {
            legend: { display: !!datasets, labels: { color: '#94a3b8', font: CHART_DEFAULTS.font, boxWidth: 12 } },
            tooltip: {
              backgroundColor: '#1e293b',
              borderColor: 'rgba(255,255,255,0.1)',
              borderWidth: 1,
              titleColor: '#e2e8f0',
              bodyColor: '#94a3b8',
              padding: 10,
              cornerRadius: 8,
            }
          },
          scales: {
            x: { grid: { display: false }, ticks: { color: '#64748b', font: CHART_DEFAULTS.font } },
            y: { grid: { color: 'rgba(255,255,255,0.05)' }, ticks: { color: '#64748b', font: CHART_DEFAULTS.font } }
          }
        }
      });
      _chartInstances.set(canvasId, instance);
      return instance;
    }

    return this._rawBar(canvas, { labels, data, color });
  }

  /** Alias */
  static areaChart(canvasId, options) {
    return this.lineChart(canvasId, { ...options, fill: true });
  }

  // ── Sparkline (tiny 7-day trend, no axes/labels) ──────────────────────────
  static sparkline(canvasId, { data, color = '#6c5ce7', width = 80, height = 32 } = {}) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    _destroyExisting(canvasId);

    const CJS = _getChartJS();
    if (CJS) {
      canvas.width = width; canvas.height = height;
      const ctx = canvas.getContext('2d');
      const gradient = ctx.createLinearGradient(0, 0, 0, height);
      gradient.addColorStop(0, color + '44');
      gradient.addColorStop(1, color + '00');
      const instance = new CJS(ctx, {
        type: 'line',
        data: {
          labels: data.map(() => ''),
          datasets: [{ data, borderColor: color, borderWidth: 1.5, backgroundColor: gradient, fill: true, tension: 0.4, pointRadius: 0 }]
        },
        options: {
          responsive: false, maintainAspectRatio: false,
          animation: false,
          plugins: { legend: { display: false }, tooltip: { enabled: false } },
          scales: { x: { display: false }, y: { display: false } }
        }
      });
      _chartInstances.set(canvasId, instance);
      return instance;
    }
  }

  // ── Destroy a specific chart ──────────────────────────────────────────────
  static destroy(canvasId) {
    _destroyExisting(canvasId);
  }

  // ── Raw Canvas fallbacks (when Chart.js CDN not loaded) ───────────────────
  static _rawLine(canvas, { data = [], color = '#6c5ce7' } = {}) {
    const ctx = canvas.getContext('2d');
    const w = canvas.offsetWidth || 300, h = canvas.offsetHeight || 150;
    canvas.width = w; canvas.height = h;
    const max = Math.max(...data, 1);
    const pad = 20;
    ctx.clearRect(0, 0, w, h);
    ctx.beginPath();
    data.forEach((v, i) => {
      const x = pad + i * ((w - pad * 2) / (data.length - 1 || 1));
      const y = h - pad - (v / max) * (h - pad * 2);
      i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
    });
    ctx.strokeStyle = color; ctx.lineWidth = 2; ctx.stroke();
  }

  static _rawDoughnut(canvas, { data = [], colors = [] } = {}) {
    const ctx = canvas.getContext('2d');
    const w = canvas.offsetWidth || 180, h = canvas.offsetHeight || 180;
    canvas.width = w; canvas.height = h;
    const total = data.reduce((a, b) => a + b, 0) || 1;
    let angle = -Math.PI / 2;
    const cx = w / 2, cy = h / 2, r = Math.min(cx, cy) - 15;
    data.forEach((v, i) => {
      const slice = (v / total) * Math.PI * 2;
      ctx.beginPath();
      ctx.arc(cx, cy, r, angle, angle + slice);
      ctx.lineWidth = 20; ctx.strokeStyle = (colors && colors[i]) || '#6c5ce7'; ctx.stroke();
      angle += slice;
    });
  }

  static _rawBar(canvas, { labels = [], data = [], color = '#6c5ce7' } = {}) {
    const ctx = canvas.getContext('2d');
    const w = canvas.offsetWidth || 300, h = canvas.offsetHeight || 150;
    canvas.width = w; canvas.height = h;
    const max = Math.max(...data, 1), pad = 30;
    const bw = (w - pad * 2) / data.length * 0.7;
    ctx.clearRect(0, 0, w, h);
    data.forEach((v, i) => {
      const bh = (v / max) * (h - pad * 2);
      const x = pad + i * ((w - pad * 2) / data.length);
      ctx.fillStyle = color + 'cc';
      ctx.fillRect(x, h - pad - bh, bw, bh);
      ctx.fillStyle = '#666'; ctx.font = '10px sans-serif'; ctx.textAlign = 'center';
      ctx.fillText(labels[i] || '', x + bw / 2, h - 10);
    });
  }
}
