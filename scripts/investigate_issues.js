const fs = require('fs');
const path = require('path');

const jsPages = fs.readdirSync('public/js/pages').map(f => 'public/js/pages/' + f);
const jsRoot = fs.readdirSync('public/js').filter(f => f.endsWith('.js')).map(f => 'public/js/' + f);
const htmlFiles = fs.readdirSync('public').filter(f => f.endsWith('.html')).map(f => 'public/' + f);

const allFiles = [...htmlFiles, ...jsRoot, ...jsPages];

console.log('--- 1. INLINE ONCLICK HANDLERS ---');
allFiles.forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  const regex = /onclick=["']([^"']+)["']/g;
  let m;
  while ((m = regex.exec(content)) !== null) {
    console.log(`${f} -> ${m[1]}`);
  }
});

console.log('\n--- 2. CHECK SPECIFIC BUTTONS IN PORTAL & SETTINGS ---');
const portalCode = fs.readFileSync('public/js/pages/portal.js', 'utf8');
['btn-submit-leave', 'btn-submit-sc', 'btn-submit-ref', 'btn-req-seat-change', 'btn-req-leave'].forEach(id => {
  const count = (portalCode.match(new RegExp(id, 'g')) || []).length;
  console.log(`portal.js: ${id} occurs ${count} times`);
});

const settingsCode = fs.readFileSync('public/js/pages/settings.js', 'utf8');
['btn-add-staff-member', 'btn-refresh-ai-insights', 'btn-master-save-all', 'btn-master-quick-backup'].forEach(id => {
  const count = (settingsCode.match(new RegExp(id, 'g')) || []).length;
  console.log(`settings.js: ${id} occurs ${count} times`);
});

console.log('\n--- 3. CHECK API ROUTES ---');
console.log('Auth users endpoint check:');
const authRoutes = fs.readFileSync('routes/auth.js', 'utf8');
console.log('routes/auth.js has /users?', authRoutes.includes("'/users'") || authRoutes.includes('"/users"'));
console.log('routes/users.js exists?', fs.existsSync('routes/users.js'));

const settingsRoutes = fs.readFileSync('routes/settings.js', 'utf8');
console.log('routes/settings.js has /sidebar-config?', settingsRoutes.includes('sidebar-config'));
