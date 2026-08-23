const fs = require('fs');
const path = require('path');

console.log('====================================================');
console.log('  🔍 STARTING DEEP FORENSIC SCAN OF SYSTEM ACTIONS  ');
console.log('====================================================\n');

const publicDir = path.join(__dirname, '..', 'public');
const routesDir = path.join(__dirname, '..', 'routes');

// 1. Collect all Express routes from backend
const routeFiles = fs.readdirSync(routesDir).filter(f => f.endsWith('.js'));
const registeredBackendRoutes = [];

// Read server.js to see base route prefixes
const serverCode = fs.readFileSync(path.join(__dirname, '..', 'server.js'), 'utf8');
const routePrefixMap = {};
const routeMountMatches = [...serverCode.matchAll(/app\.use\(\s*['"`]([^'"`]+)['"`]\s*,\s*require\(\s*['"`]\.\/routes\/([^'"`]+)['"`]\s*\)/g)];
routeMountMatches.forEach(m => {
  const prefix = m[1];
  const file = m[2] + (m[2].endsWith('.js') ? '' : '.js');
  routePrefixMap[file] = prefix;
});

routeFiles.forEach(file => {
  const code = fs.readFileSync(path.join(routesDir, file), 'utf8');
  const prefix = routePrefixMap[file] || `/api/${file.replace('.js', '')}`;
  
  const routeRegex = /router\.(get|post|put|delete|patch)\(\s*['"`]([^'"`]+)['"`]/g;
  let match;
  while ((match = routeRegex.exec(code)) !== null) {
    const method = match[1].toUpperCase();
    let subPath = match[2];
    if (subPath === '/') subPath = '';
    const fullPath = (prefix + subPath).replace(/\/+/g, '/');
    registeredBackendRoutes.push({ method, fullPath, file });
  }
});

console.log(`📡 Registered Backend API Endpoints found: ${registeredBackendRoutes.length}`);

// 2. Scan all JS page files and HTML files in public/
function scanDir(dir, extFilter) {
  let files = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory() && e.name !== 'node_modules' && e.name !== '.git') {
      files = files.concat(scanDir(full, extFilter));
    } else if (e.isFile() && extFilter.some(ext => e.name.endsWith(ext))) {
      files.push(full);
    }
  }
  return files;
}

const jsFiles = scanDir(path.join(publicDir, 'js'), ['.js']);
const htmlFiles = scanDir(publicDir, ['.html']);

const issuesFound = [];

// A. Check for onclick functions that might be undefined
const onclickUsages = [];
[...htmlFiles, ...jsFiles].forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  const onclickRegex = /onclick=["']([a-zA-Z0-9_$]+)\s*\(/g;
  let m;
  while ((m = onclickRegex.exec(content)) !== null) {
    onclickUsages.push({ fnName: m[1], file: path.relative(publicDir, f) });
  }
});

// Find which onclick functions are defined on window or in global scope
const allCode = [...htmlFiles, ...jsFiles].map(f => fs.readFileSync(f, 'utf8')).join('\n');
onclickUsages.forEach(u => {
  const isDefined = allCode.includes(`window.${u.fnName}`) || 
                    allCode.includes(`function ${u.fnName}`) || 
                    allCode.includes(`const ${u.fnName} =`) ||
                    allCode.includes(`let ${u.fnName} =`) ||
                    allCode.includes(`Modal.${u.fnName}`) ||
                    u.fnName === 'alert' || u.fnName === 'confirm' || u.fnName === 'prompt';
  if (!isDefined) {
    issuesFound.push({
      type: 'DEAD_ONCLICK_FUNCTION',
      severity: 'HIGH',
      description: `onclick calls "${u.fnName}()" in ${u.file} but function is NOT defined anywhere on window or script scope.`
    });
  }
});

// B. Check all HTML and rendered buttons for missing click listeners
const deadButtonChecks = [];
jsFiles.forEach(f => {
  const code = fs.readFileSync(f, 'utf8');
  const relFile = path.relative(publicDir, f);
  
  // Find all id="..." inside HTML strings like `<button id="btn-xxx"...>`
  const btnIdRegex = /<button[^>]+id=["']([^"']+)["']/g;
  let m;
  while ((m = btnIdRegex.exec(code)) !== null) {
    const btnId = m[1];
    // Check if this id is referenced anywhere in this file or other js files
    const occurrences = (code.match(new RegExp(btnId, 'g')) || []).length;
    // If it only occurs once (the HTML definition itself), it might be dead!
    if (occurrences <= 1) {
      deadButtonChecks.push({ btnId, file: relFile });
    }
  }
});

deadButtonChecks.forEach(d => {
  issuesFound.push({
    type: 'DEAD_BUTTON_ID',
    severity: 'MEDIUM',
    description: `Button with id="${d.btnId}" in ${d.file} is rendered in HTML template but has NO event listener attached (only appears 1 time in file).`
  });
});

// C. Check API calls from frontend to backend
const apiCalls = [];
jsFiles.forEach(f => {
  const code = fs.readFileSync(f, 'utf8');
  const relFile = path.relative(publicDir, f);
  
  const apiCallRegex = /(?:api\.(get|post|put|delete|patch)|fetch)\(\s*['"`]([^'"`]+)['"`]/g;
  let m;
  while ((m = apiCallRegex.exec(code)) !== null) {
    let method = m[1] ? m[1].toUpperCase() : 'GET';
    let url = m[2];
    if (url.startsWith('/api/')) {
      const cleanUrl = url.split('?')[0];
      apiCalls.push({ method, url: cleanUrl, rawUrl: url, file: relFile });
    }
  }
});

console.log(`🔍 Total Frontend API Calls scanned: ${apiCalls.length}`);

// Match each API call against registeredBackendRoutes
apiCalls.forEach(call => {
  const isDynamic = call.url.includes('${');
  if (isDynamic) return;

  const matched = registeredBackendRoutes.some(r => {
    const pattern = '^' + r.fullPath.replace(/:[a-zA-Z0-9_]+/g, '[^/]+') + '$';
    const regex = new RegExp(pattern);
    const methodMatch = (call.method === 'FETCH') || (r.method === call.method);
    return regex.test(call.url) && methodMatch;
  });

  if (!matched) {
    issuesFound.push({
      type: 'POTENTIAL_BROKEN_API_CALL',
      severity: 'HIGH',
      description: `Frontend in ${call.file} calls ${call.method} ${call.rawUrl}, but no exact matching Express route was found on backend!`
    });
  }
});

console.log('\n====================================================');
console.log(`  📊 AUDIT COMPLETE: ${issuesFound.length} POTENTIAL ISSUES FOUND `);
console.log('====================================================\n');

issuesFound.forEach((iss, idx) => {
  console.log(`[#${idx + 1}] [${iss.severity}] ${iss.type}:`);
  console.log(`    ${iss.description}\n`);
});
