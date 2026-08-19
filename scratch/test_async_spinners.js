const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const PUBLIC_JS = path.join(PROJECT_ROOT, 'public', 'js');

function getAllFiles(dir, ext = '.js') {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat && stat.isDirectory()) {
      results = results.concat(getAllFiles(fullPath, ext));
    } else if (file.endsWith(ext)) {
      results.push(fullPath);
    }
  });
  return results;
}

const files = getAllFiles(PUBLIC_JS);
console.log(`Checking ${files.length} files for Loading spinner safety...\n`);

files.forEach(file => {
  const code = fs.readFileSync(file, 'utf8');
  const rel = path.relative(PROJECT_ROOT, file);

  // Check Loading.button(btn, true) calls
  const buttonLoadMatches = [...code.matchAll(/Loading\.button\(\s*([^,]+),\s*true\s*\)/g)];
  if (buttonLoadMatches.length > 0) {
    // Check if there is a matching Loading.button(..., false)
    const buttonUnloadMatches = [...code.matchAll(/Loading\.button\(\s*([^,]+),\s*false\s*\)/g)];
    if (buttonUnloadMatches.length === 0) {
      console.log(`⚠️ [${rel}] Calls Loading.button(..., true) ${buttonLoadMatches.length} times but never calls Loading.button(..., false)!`);
    } else if (buttonLoadMatches.length !== buttonUnloadMatches.length) {
      console.log(`ℹ️ [${rel}] Loading.button counts: ${buttonLoadMatches.length} true vs ${buttonUnloadMatches.length} false`);
    }
  }

  // Check Loading.show(target) calls
  const showMatches = [...code.matchAll(/Loading\.show\(\s*([^)]+)\s*\)/g)];
  if (showMatches.length > 0) {
    const hideMatches = [...code.matchAll(/Loading\.hide\(\s*([^)]+)\s*\)/g)];
    if (hideMatches.length === 0) {
      console.log(`⚠️ [${rel}] Calls Loading.show() ${showMatches.length} times but never calls Loading.hide()!`);
    }
  }
});
console.log('\nSpinner check complete.');
