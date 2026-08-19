const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const PAGES_DIR = path.join(PROJECT_ROOT, 'public', 'js', 'pages');

const pageFiles = fs.readdirSync(PAGES_DIR).filter(f => f.endsWith('.js'));

console.log('Auditing page selector consistency across', pageFiles.length, 'pages...\n');

pageFiles.forEach(file => {
  const filePath = path.join(PAGES_DIR, file);
  const code = fs.readFileSync(filePath, 'utf8');

  console.log(`Checking ${file}...`);

  // Extract all getElementById and querySelector calls
  const getByIdMatches = [...code.matchAll(/(?:document|container|page|content|modalContent|modal|panel|form)\.getElementById\(['"]([^'"]+)['"]\)/g)].map(m => m[1]);
  const querySelMatches = [...code.matchAll(/(?:document|container|page|content|modalContent|modal|panel|form)\.querySelector\(['"]#([^'"]+)['"]\)/g)].map(m => m[1]);
  const allQueriedIds = [...new Set([...getByIdMatches, ...querySelMatches])];

  // Extract all IDs defined in template literals / strings in this file
  const definedIds = new Set();
  const idMatches = [...code.matchAll(/id=["']([^"'${}]+)["']/g)].map(m => m[1]);
  idMatches.forEach(id => definedIds.add(id));

  // Also check if ID is in index.html
  const indexHtml = fs.readFileSync(path.join(PROJECT_ROOT, 'public', 'index.html'), 'utf8');
  const indexMatches = [...indexHtml.matchAll(/id=["']([^"']+)["']/g)].map(m => m[1]);
  indexMatches.forEach(id => definedIds.add(id));

  // Find any queried IDs that are NEVER created anywhere in this page or index.html
  const missingIds = allQueriedIds.filter(id => !definedIds.has(id));
  if (missingIds.length > 0) {
    console.log(`  ⚠️ Queried IDs not found in templates or index.html:`, missingIds);
  }

  // Check event listener attachments without null check
  const lines = code.split('\n');
  lines.forEach((line, idx) => {
    // pattern: getElementById('xxx').addEventListener without optional chaining or if guard
    if (/(?:document|container|page)\.(?:getElementById|querySelector)\(['"][^'"]+['"]\)\.addEventListener/.test(line)) {
      console.log(`  ⚠️ Direct .addEventListener on line ${idx + 1}: ${line.trim()}`);
    }
  });

  console.log('');
});
