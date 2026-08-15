export class ChartEngine {
  static setupCanvas(canvasId) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return null;
    const ctx = canvas.getContext('2d');
    const dpr = window.devicePixelRatio || 1;
    const rect = canvas.getBoundingClientRect();
    canvas.width = rect.width * dpr;
    canvas.height = rect.height * dpr;
    ctx.scale(dpr, dpr);
    return { canvas, ctx, width: rect.width, height: rect.height };
  }

  static barChart(canvasId, { labels, data, color = '#2196f3', title }) {
    const setup = this.setupCanvas(canvasId);
    if (!setup) return;
    const { ctx, width, height } = setup;
    
    const max = Math.max(...data, 1);
    const padding = 40;
    const barWidth = (width - padding * 2) / data.length * 0.8;
    const spacing = (width - padding * 2) / data.length * 0.2;
    
    ctx.clearRect(0, 0, width, height);
    
    ctx.fillStyle = '#666';
    ctx.font = '12px sans-serif';
    if (title) {
      ctx.fillText(title, padding, 20);
    }

    data.forEach((val, i) => {
      const h = (val / max) * (height - padding * 2);
      const x = padding + i * (barWidth + spacing);
      const y = height - padding - h;
      
      ctx.fillStyle = color;
      ctx.fillRect(x, y, barWidth, h);
      
      ctx.fillStyle = '#666';
      ctx.textAlign = 'center';
      ctx.fillText(labels[i], x + barWidth/2, height - padding + 15);
    });
  }

  static lineChart(canvasId, { labels, data, color = '#2196f3', fill = false, title }) {
    const setup = this.setupCanvas(canvasId);
    if (!setup) return;
    const { ctx, width, height } = setup;
    
    const max = Math.max(...data, 1);
    const padding = 40;
    const stepX = (width - padding * 2) / (data.length - 1 || 1);
    
    ctx.clearRect(0, 0, width, height);

    ctx.beginPath();
    data.forEach((val, i) => {
      const x = padding + i * stepX;
      const y = height - padding - (val / max) * (height - padding * 2);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    });
    
    ctx.strokeStyle = color;
    ctx.lineWidth = 2;
    ctx.stroke();

    if (fill) {
      ctx.lineTo(padding + (data.length - 1) * stepX, height - padding);
      ctx.lineTo(padding, height - padding);
      ctx.closePath();
      ctx.fillStyle = color + '33'; // 20% opacity
      ctx.fill();
    }
  }

  static doughnutChart(canvasId, { labels, data, colors, title }) {
    const setup = this.setupCanvas(canvasId);
    if (!setup) return;
    const { ctx, width, height } = setup;
    
    const total = data.reduce((a, b) => a + b, 0) || 1;
    const cx = width / 2;
    const cy = height / 2;
    const radius = Math.min(cx, cy) - 20;
    
    let currentAngle = -0.5 * Math.PI;
    
    ctx.clearRect(0, 0, width, height);

    data.forEach((val, i) => {
      const sliceAngle = (val / total) * 2 * Math.PI;
      ctx.beginPath();
      ctx.arc(cx, cy, radius, currentAngle, currentAngle + sliceAngle);
      ctx.lineWidth = 20;
      ctx.strokeStyle = colors[i % colors.length];
      ctx.stroke();
      currentAngle += sliceAngle;
    });
  }

  static areaChart(canvasId, options) {
    return this.lineChart(canvasId, { ...options, fill: true });
  }
}
