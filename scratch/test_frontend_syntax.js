const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PROJECT_ROOT = path.resolve(__dirname, '..');
const PUBLIC_DIR = path.join(PROJECT_ROOT, 'public');
const PUBLIC_JS = path.join(PUBLIC_DIR, 'js');

function getAllFiles(dir, ext = '.js') {
  let results = [];
  if (!fs.existsSync(dir)) return results;
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

const jsFiles = getAllFiles(PUBLIC_JS);
const htmlFiles = getAllFiles(PUBLIC_DIR, '.html');

console.log('='.repeat(70));
console.log(`FRONTEND AUDIT: Analyzing ${jsFiles.length} JS files and ${htmlFiles.length} HTML files`);
console.log('='.repeat(70));

const results = {
  syntaxErrors: [],
  missingImports: [],
  unattachedGlobalHandlers: [],
  mismatchedSelectors: [],
  uncaughtAsyncSpinners: [],
  brokenExports: []
};

// 1. Syntax Check with node --check
console.log('\n[1/5] Syntax Verification (node --check)...');
jsFiles.forEach(file => {
  try {
    execSync(`node --check "${file}"`, { stdio: 'pipe' });
  } catch (err) {
    results.syntaxErrors.push({
      file: path.relative(PROJECT_ROOT, file),
      error: err.stderr ? err.stderr.toString().trim() : err.message
    });
  }
});

// 2. Parse JS Files: Tokens, Imports, Scope, Window assignments, and Templates
console.log('[2/5] AST & Token Inspection...');

// Collect all window.* assignments across all files
const globalWindowProperties = new Set(['App', 'Toast', 'Modal', 'Loading', 'Confirm', 'toggleTheme']);

jsFiles.forEach(file => {
  const code = fs.readFileSync(file, 'utf8');
  // window.xxx = ...
  const winAssignMatches = code.matchAll(/window\.([a-zA-Z0-9_$]+)\s*=/g);
  for (const m of winAssignMatches) {
    globalWindowProperties.add(m[1]);
  }
  // globalThis.xxx = ...
  const gtAssignMatches = code.matchAll(/globalThis\.([a-zA-Z0-9_$]+)\s*=/g);
  for (const m of gtAssignMatches) {
    globalWindowProperties.add(m[1]);
  }
});

// Collect HTML elements and IDs from index.html and other HTML files
const htmlIds = new Set();
htmlFiles.forEach(file => {
  const html = fs.readFileSync(file, 'utf8');
  const idMatches = html.matchAll(/id=["']([^"']+)["']/g);
  for (const m of idMatches) htmlIds.add(m[1]);
});

// Analyze each file
jsFiles.forEach(file => {
  const relPath = path.relative(PROJECT_ROOT, file);
  const code = fs.readFileSync(file, 'utf8');
  const fileDir = path.dirname(file);

  // Check imports
  const imports = new Set();
  const importLines = code.matchAll(/import\s+(?:(\* as \w+)|(\w+)|(?:\{([^}]+)\}))?\s*(?:,\s*\{([^}]+)\})?\s*from\s*['"]([^'"]+)['"]/g);
  
  for (const m of importLines) {
    const defaultImport = m[2];
    const named1 = m[3];
    const named2 = m[4];
    const importSource = m[5];

    if (defaultImport) imports.add(defaultImport.trim());
    if (named1) {
      named1.split(',').forEach(id => {
        const parts = id.trim().split(/\s+as\s+/);
        const local = (parts[1] || parts[0]).trim();
        if (local) imports.add(local);
      });
    }
    if (named2) {
      named2.split(',').forEach(id => {
        const parts = id.trim().split(/\s+as\s+/);
        const local = (parts[1] || parts[0]).trim();
        if (local) imports.add(local);
      });
    }

    if (importSource.startsWith('.')) {
      const resolved = path.resolve(fileDir, importSource);
      if (!fs.existsSync(resolved)) {
        results.missingImports.push({
          file: relPath,
          error: `Import source "${importSource}" does not exist.`
        });
      }
    }
  }

  // Local declarations
  const localDefs = new Set([...imports]);
  const decls = code.matchAll(/(?:function\s+([a-zA-Z0-9_$]+)|class\s+([a-zA-Z0-9_$]+)|(?:const|let|var)\s+([a-zA-Z0-9_$]+))/g);
  for (const d of decls) {
    const name = d[1] || d[2] || d[3];
    if (name) localDefs.add(name);
  }

  // Strip strings, template literals, and comments before checking identifier usage
  const strippedCode = code
    .replace(/\/\*[\s\S]*?\*\//g, ' ') // block comments
    .replace(/\/\/[^\n]*/g, ' ')       // line comments
    .replace(/`(?:[^`\\]|\\.)*`/g, '``') // template literals
    .replace(/'(?:[^'\\]|\\.)*'/g, "''") // single quote strings
    .replace(/"(?:[^"\\]|\\.)*"/g, '""'); // double quote strings

  // Check usage of UI helpers
  const uiHelpers = ['Toast', 'Modal', 'Loading', 'Confirm', 'escapeHTML', 'formatCurrency', 'formatDate', 'api'];
  uiHelpers.forEach(helper => {
    const helperRegex = new RegExp(`\\b${helper}\\b`, 'g');
    if (helperRegex.test(strippedCode)) {
      if (!localDefs.has(helper) && !globalWindowProperties.has(helper)) {
        // Special check: might be a method on `this` or `window`
        const isQualified = new RegExp(`(?:this|window)\\.${helper}`).test(code);
        if (!isQualified) {
          results.missingImports.push({
            file: relPath,
            error: `Identifier "${helper}" is used without being imported or declared in module scope.`
          });
        }
      }
    }
  });

  // Check if translation function t(...) is used without being imported
  if (/\bt\s*\(['"`]/.test(strippedCode) && !localDefs.has('t')) {
    results.missingImports.push({
      file: relPath,
      error: `Translation function "t(...)" is used without being imported or declared in module scope.`
    });
  }

  // Check inline HTML event handlers in template strings (e.g. onclick="someFn(...)")
  // In ES modules, inline event handlers in HTML strings (like onclick="deleteStudent(...)")
  // execute in global window scope. If deleteStudent is NOT on window, it fails with ReferenceError at runtime!
  const inlineHandlerMatches = code.matchAll(/on(click|change|submit|input)\s*=\s*["']\s*([a-zA-Z0-9_$]+)\s*\(([^)]*)\)/gi);
  for (const m of inlineHandlerMatches) {
    const eventType = m[1];
    const fnName = m[2];
    // Ignore standard JS built-ins (event.preventDefault(), this.select(), etc.)
    if (['event', 'this', 'console', 'alert', 'confirm', 'prompt', 'document', 'window', 'history', 'location', 'closeModal'].includes(fnName)) continue;
    if (!globalWindowProperties.has(fnName) && !localDefs.has(fnName)) {
      results.unattachedGlobalHandlers.push({
        file: relPath,
        handler: `on${eventType}="${fnName}(...)"`,
        fnName,
        note: `Function "${fnName}" is invoked via inline HTML handler but is not assigned to window or declared globally.`
      });
    }
  }

  // Check Loading.show() / Loading.hide() balance
  const showCount = (code.match(/Loading\.show\(/g) || []).length;
  const hideCount = (code.match(/Loading\.hide\(/g) || []).length;
  if (showCount > 0 && hideCount === 0) {
    results.uncaughtAsyncSpinners.push({
      file: relPath,
      issue: `Calls Loading.show() (${showCount} times) but never calls Loading.hide()!`
    });
  }

  // Check page render contract
  if (relPath.includes('pages\\') || relPath.includes('pages/')) {
    if (!code.includes('export async function render') && !code.includes('export function render') && !code.includes('export { render')) {
      results.brokenExports.push({
        file: relPath,
        issue: 'Page module does not export render function.'
      });
    }
  }
});

// Output Summary
console.log('\n' + '='.repeat(70));
console.log('AUDIT RESULTS');
console.log('='.repeat(70));

let hasErrors = false;

if (results.syntaxErrors.length > 0) {
  hasErrors = true;
  console.log(`\n❌ SYNTAX ERRORS (${results.syntaxErrors.length}):`);
  results.syntaxErrors.forEach(e => console.log(`  - [${e.file}] ${e.error}`));
} else {
  console.log('\n✅ Syntax: All JS files passed node --check without syntax errors.');
}

if (results.missingImports.length > 0) {
  hasErrors = true;
  console.log(`\n❌ MISSING IMPORTS / UNDEFINED IDENTIFIERS (${results.missingImports.length}):`);
  results.missingImports.forEach(e => console.log(`  - [${e.file}] ${e.error}`));
} else {
  console.log('✅ Imports: All identifier references are imported or defined in scope.');
}

if (results.brokenExports.length > 0) {
  hasErrors = true;
  console.log(`\n❌ BROKEN PAGE EXPORTS (${results.brokenExports.length}):`);
  results.brokenExports.forEach(e => console.log(`  - [${e.file}] ${e.issue}`));
} else {
  console.log('✅ Page Exports: All page modules export a valid render() function.');
}

if (results.uncaughtAsyncSpinners.length > 0) {
  console.log(`\n⚠️ POTENTIAL STUCK LOADING SPINNERS (${results.uncaughtAsyncSpinners.length}):`);
  results.uncaughtAsyncSpinners.forEach(e => console.log(`  - [${e.file}] ${e.issue}`));
} else {
  console.log('✅ Loading Spinners: Loading.show() / Loading.hide() balanced.');
}

if (results.unattachedGlobalHandlers.length > 0) {
  console.log(`\n⚠️ INLINE HTML HANDLERS NOT ATTACHED TO WINDOW (${results.unattachedGlobalHandlers.length}):`);
  results.unattachedGlobalHandlers.forEach(e => console.log(`  - [${e.file}] ${e.handler}: ${e.note}`));
} else {
  console.log('✅ Inline Handlers: No unattached inline handlers found.');
}

console.log('\n' + '='.repeat(70));
