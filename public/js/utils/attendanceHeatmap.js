/**
 * attendanceHeatmap.js
 * Renders a GitHub-style attendance heatmap calendar for any student.
 *
 * Usage:
 *   import { renderHeatmap } from '../utils/attendanceHeatmap.js';
 *   renderHeatmap(containerEl, studentId, year);
 */

/**
 * Fetch attendance records for a student for a given year from the API.
 * Returns a Map of 'YYYY-MM-DD' => 'present' | 'absent' | 'holiday'
 */
async function fetchAttendanceData(studentId, year) {
  const map = new Map();
  try {
    const token = localStorage.getItem('sl_token') || '';
    const res = await fetch(`/api/attendance?studentId=${encodeURIComponent(studentId)}&year=${year}&limit=400`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    if (!res.ok) return map;
    const data = await res.json();
    const records = data.data || data.records || data || [];
    (Array.isArray(records) ? records : []).forEach(rec => {
      const d = new Date(rec.date || rec.checkInTime || rec.createdAt);
      if (!isNaN(d)) {
        const key = d.toISOString().slice(0, 10);
        const status = rec.status || (rec.checkInTime ? 'present' : 'absent');
        map.set(key, status.toLowerCase().includes('present') || status === 'in' ? 'present' : 'absent');
      }
    });
  } catch (e) {
    console.warn('Heatmap fetch error:', e);
  }
  return map;
}

/**
 * Calculate color for a cell based on status
 */
function getColor(status, theme = 'dark') {
  if (!status) return theme === 'dark' ? '#1e293b' : '#ebedf0';
  if (status === 'present') return '#22c55e';
  if (status === 'absent') return '#ef4444';
  if (status === 'holiday') return '#f59e0b';
  return theme === 'dark' ? '#1e293b' : '#ebedf0';
}

/**
 * Get all dates of a year as array of 'YYYY-MM-DD' strings
 */
function getDatesOfYear(year) {
  const dates = [];
  const d = new Date(year, 0, 1);
  while (d.getFullYear() === year) {
    dates.push(d.toISOString().slice(0, 10));
    d.setDate(d.getDate() + 1);
  }
  return dates;
}

/**
 * Main render function.
 * @param {HTMLElement} container - Where to render the heatmap
 * @param {string} studentId - Student _id or studentId
 * @param {number} year - Year (default current year)
 * @param {object} opts - Optional config { theme: 'dark'|'light', compact: false }
 */
export async function renderHeatmap(container, studentId, year = new Date().getFullYear(), opts = {}) {
  const { theme = document.documentElement.getAttribute('data-theme') || 'dark', compact = false } = opts;
  if (!container) return;

  // Show skeleton loading state
  container.innerHTML = `
    <div class="heatmap-loading" style="display:flex;align-items:center;gap:8px;color:var(--color-text-muted,#64748b);font-size:0.85rem;">
      <div style="width:16px;height:16px;border:2px solid #6c5ce7;border-top-color:transparent;border-radius:50%;animation:heatmap-spin 0.7s linear infinite;flex-shrink:0;"></div>
      Loading attendance calendar...
    </div>
    <style>@keyframes heatmap-spin{to{transform:rotate(360deg)}}</style>
  `;

  const attendanceMap = await fetchAttendanceData(studentId, year);
  const dates = getDatesOfYear(year);
  const today = new Date().toISOString().slice(0, 10);

  // Stats
  let presentCount = 0;
  let absentCount = 0;
  let totalTracked = 0;
  attendanceMap.forEach(v => {
    if (v === 'present') presentCount++;
    else if (v === 'absent') absentCount++;
    totalTracked++;
  });
  const attendancePct = totalTracked > 0 ? Math.round((presentCount / totalTracked) * 100) : 0;

  // Month labels
  const MONTHS = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  const DAYS = compact ? ['','M','','W','','F',''] : ['S','M','T','W','T','F','S'];

  // Build week columns
  // Find the day of week for Jan 1
  const jan1 = new Date(year, 0, 1);
  const startDow = jan1.getDay(); // 0=Sun

  // Pad dates array so it starts on Sunday
  const paddedDates = Array(startDow).fill(null).concat(dates);
  // Chunk into weeks
  const weeks = [];
  for (let i = 0; i < paddedDates.length; i += 7) {
    weeks.push(paddedDates.slice(i, i + 7));
  }

  // Determine cell size
  const cellSize = compact ? 10 : 13;
  const cellGap = 2;
  const totalW = weeks.length * (cellSize + cellGap);

  // Month label positions
  const monthPositions = [];
  let currentMonth = -1;
  weeks.forEach((week, wIdx) => {
    week.forEach(d => {
      if (!d) return;
      const m = new Date(d).getMonth();
      if (m !== currentMonth) {
        currentMonth = m;
        monthPositions.push({ month: m, weekIdx: wIdx });
      }
    });
  });

  // Build SVG heatmap
  const svgNS = 'http://www.w3.org/2000/svg';
  const topPad = 20;
  const leftPad = compact ? 0 : 24;
  const svgW = leftPad + totalW + 4;
  const svgH = topPad + 7 * (cellSize + cellGap) + 4;

  let rects = '';
  weeks.forEach((week, wIdx) => {
    week.forEach((d, dow) => {
      if (!d) return;
      const isFuture = d > today;
      const status = attendanceMap.get(d) || null;
      const color = isFuture ? 'transparent' : getColor(status, theme);
      const x = leftPad + wIdx * (cellSize + cellGap);
      const y = topPad + dow * (cellSize + cellGap);
      const label = `${d}: ${status || 'No record'}`;
      rects += `<rect x="${x}" y="${y}" width="${cellSize}" height="${cellSize}" rx="2" fill="${color}" style="cursor:default;opacity:${isFuture ? 0 : 1}"><title>${label}</title></rect>`;
    });
  });

  // Month labels
  let monthLabels = '';
  if (!compact) {
    monthPositions.forEach(({ month, weekIdx }) => {
      const x = leftPad + weekIdx * (cellSize + cellGap);
      monthLabels += `<text x="${x}" y="${topPad - 5}" font-size="9" fill="var(--color-text-muted,#64748b)" font-family="sans-serif">${MONTHS[month]}</text>`;
    });
  }

  // Day labels
  let dayLabels = '';
  if (!compact) {
    DAYS.forEach((d, i) => {
      if (!d) return;
      const y = topPad + i * (cellSize + cellGap) + cellSize - 2;
      dayLabels += `<text x="${leftPad - 4}" y="${y}" font-size="9" fill="var(--color-text-muted,#64748b)" text-anchor="end" font-family="sans-serif">${d}</text>`;
    });
  }

  const svgEl = `
    <svg width="${svgW}" height="${svgH}" xmlns="${svgNS}" style="max-width:100%;overflow:visible;">
      ${monthLabels}
      ${dayLabels}
      ${rects}
    </svg>
  `;

  // Score badge
  const scoreBadgeColor = attendancePct >= 75 ? '#22c55e' : attendancePct >= 50 ? '#f59e0b' : '#ef4444';
  const scoreBadgeLabel = attendancePct >= 75 ? 'Good' : attendancePct >= 50 ? 'Average' : 'Low';

  container.innerHTML = `
    <div class="attendance-heatmap-wrap" style="overflow-x:auto;-webkit-overflow-scrolling:touch;">
      <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;flex-wrap:wrap;gap:8px;">
        <div style="font-size:0.82rem;font-weight:700;color:var(--color-text-secondary,#94a3b8);letter-spacing:0.04em;text-transform:uppercase;">
          ${year} Attendance Calendar
        </div>
        <div style="display:flex;align-items:center;gap:10px;flex-wrap:wrap;">
          <span style="font-size:0.78rem;color:var(--color-text-muted,#64748b);">${presentCount} present / ${absentCount} absent</span>
          <span style="background:${scoreBadgeColor}22;color:${scoreBadgeColor};font-weight:700;font-size:0.78rem;padding:2px 10px;border-radius:20px;border:1px solid ${scoreBadgeColor}55;">
            ${attendancePct}% — ${scoreBadgeLabel}
          </span>
        </div>
      </div>
      <div class="heatmap-svg-container" style="min-width:${svgW}px;">
        ${svgEl}
      </div>
      <div style="display:flex;align-items:center;gap:8px;margin-top:8px;font-size:0.75rem;color:var(--color-text-muted,#64748b);">
        <span>Less</span>
        <span style="display:inline-flex;gap:3px;">
          ${[getColor(null,theme), '#22c55e88', '#22c55e', '#ef4444', '#f59e0b'].map(c => `<span style="width:11px;height:11px;border-radius:2px;background:${c};display:inline-block;"></span>`).join('')}
        </span>
        <span>More/Present</span>
        <span style="margin-left:auto;display:flex;gap:8px;">
          <span style="display:flex;align-items:center;gap:3px;"><span style="width:11px;height:11px;border-radius:2px;background:#22c55e;display:inline-block;"></span>Present</span>
          <span style="display:flex;align-items:center;gap:3px;"><span style="width:11px;height:11px;border-radius:2px;background:#ef4444;display:inline-block;"></span>Absent</span>
        </span>
      </div>
    </div>
    <style>
      .attendance-heatmap-wrap { user-select: none; }
    </style>
  `;

  // Year switcher — add prev/next year buttons
  const yearRow = document.createElement('div');
  yearRow.style.cssText = 'display:flex;align-items:center;gap:8px;margin-bottom:8px;';
  const prevBtn = document.createElement('button');
  prevBtn.textContent = '‹';
  prevBtn.className = 'btn btn-sm btn-ghost';
  prevBtn.style.cssText = 'padding:2px 8px;font-size:1rem;';
  const yearLabel = document.createElement('span');
  yearLabel.textContent = String(year);
  yearLabel.style.cssText = 'font-weight:700;font-size:0.9rem;min-width:40px;text-align:center;';
  const nextBtn = document.createElement('button');
  nextBtn.textContent = '›';
  nextBtn.className = 'btn btn-sm btn-ghost';
  nextBtn.style.cssText = 'padding:2px 8px;font-size:1rem;';
  nextBtn.disabled = year >= new Date().getFullYear();
  yearRow.appendChild(prevBtn);
  yearRow.appendChild(yearLabel);
  yearRow.appendChild(nextBtn);
  container.insertBefore(yearRow, container.firstChild);

  prevBtn.onclick = () => renderHeatmap(container, studentId, year - 1, opts);
  nextBtn.onclick = () => { if (year < new Date().getFullYear()) renderHeatmap(container, studentId, year + 1, opts); };
}

/**
 * Calculate local behavior score from attendance records
 * @param {number} attendancePct - 0-100
 * @param {number} paymentPct - 0-100 (on-time payments %)
 * @param {number} streakDays - current study streak
 * @returns {{ score: number, grade: string, color: string, label: string }}
 */
export function calculateBehaviorScore(attendancePct = 0, paymentPct = 100, streakDays = 0) {
  const streakScore = Math.min(streakDays / 30 * 100, 100); // max 30 days = 100%
  const score = Math.round((attendancePct * 0.4) + (paymentPct * 0.4) + (streakScore * 0.2));
  let grade, color, label;
  if (score >= 80) { grade = 'A+'; color = '#22c55e'; label = 'Excellent'; }
  else if (score >= 65) { grade = 'B'; color = '#f59e0b'; label = 'Good'; }
  else if (score >= 45) { grade = 'C'; color = '#f97316'; label = 'Average'; }
  else { grade = 'D'; color = '#ef4444'; label = 'At Risk'; }
  return { score, grade, color, label };
}

/**
 * Render behavior score badge HTML
 */
export function renderBehaviorBadge(attendancePct, paymentPct, streakDays) {
  const { score, grade, color, label } = calculateBehaviorScore(attendancePct, paymentPct, streakDays);
  return `<span class="behavior-badge" title="Behavior Score: ${score}/100 (Attendance ${attendancePct}% + Payment ${paymentPct}% + Streak ${streakDays}d)" style="background:${color}22;color:${color};border:1px solid ${color}55;border-radius:20px;padding:2px 10px;font-size:0.75rem;font-weight:700;display:inline-flex;align-items:center;gap:4px;cursor:help;">
  <span style="font-size:0.85rem;">${score >= 80 ? '🟢' : score >= 65 ? '🟡' : score >= 45 ? '🟠' : '🔴'}</span>
  ${grade} · ${label}
</span>`;
}

if (typeof window !== 'undefined') {
  window.AttendanceHeatmap = { renderHeatmap, calculateBehaviorScore, renderBehaviorBadge };
}
