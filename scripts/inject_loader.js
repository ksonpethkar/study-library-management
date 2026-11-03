const fs = require('fs');
const path = require('path');

const files = [
  path.join(__dirname, '../public/app/index.html'),
  path.join(__dirname, '../web/index.html')
];

files.forEach(filePath => {
  if (!fs.existsSync(filePath)) return;
  let html = fs.readFileSync(filePath, 'utf8');
  if (html.includes('id="flutter-loader"')) {
    console.log('Already has loader:', filePath);
    return;
  }
  const loader = `<body style="margin:0;padding:0;background:#0F172A;overflow:hidden;">
  <!-- Instant Branded Splash Loader (Zero Blank Screen Guarantee) -->
  <div id="flutter-loader" style="position:fixed;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;background:#0F172A;font-family:'Plus Jakarta Sans',system-ui,-apple-system,sans-serif;color:white;z-index:999999;transition:opacity 0.4s ease;">
    <div style="width:68px;height:68px;border-radius:18px;background:#5D4037;display:flex;align-items:center;justify-content:center;box-shadow:0 12px 28px rgba(0,0,0,0.4);margin-bottom:18px;overflow:hidden;">
      <img src="/app/favicon.png" alt="Logo" style="width:100%;height:100%;object-fit:cover;" onerror="this.style.display='none';this.parentElement.innerText='📚';">
    </div>
    <div style="font-weight:800;font-size:17px;letter-spacing:-0.02em;margin-bottom:6px;color:#F8FAFC;">The Cozy Corner Study Centre</div>
    <div style="font-size:12.5px;color:#94A3B8;margin-bottom:22px;">Launching Smart Study Library...</div>
    <div style="width:140px;height:4px;background:rgba(255,255,255,0.08);border-radius:4px;overflow:hidden;position:relative;">
      <div style="position:absolute;left:0;top:0;height:100%;width:40%;background:#F59E0B;border-radius:4px;animation:cozyPulse 1.4s infinite ease-in-out;"></div>
    </div>
    <style>
      @keyframes cozyPulse {
        0% { left: -40%; width: 40%; }
        50% { left: 30%; width: 50%; }
        100% { left: 100%; width: 40%; }
      }
    </style>
    <script>
      window.addEventListener('flutter-first-frame', function () {
        var el = document.getElementById('flutter-loader');
        if (el) {
          el.style.opacity = '0';
          setTimeout(function() { el.remove(); }, 400);
        }
      });
      setTimeout(function() {
        var el = document.getElementById('flutter-loader');
        if (el) el.remove();
      }, 7000);
    </script>
  </div>`;

  html = html.replace(/<body[^>]*>/i, loader);
  fs.writeFileSync(filePath, html, 'utf8');
  console.log('Successfully injected loader into:', filePath);
});
