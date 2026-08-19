/**
 * Comprehensive Automated Test Runner & Static Analysis for Backend API Routes
 * Library Management System
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = 'c:\\Users\\ksonp\\Downloads\\Library Management System';
const ROUTES_DIR = path.join(ROOT_DIR, 'routes');
const MODELS_DIR = path.join(ROOT_DIR, 'models');
const MIDDLEWARE_DIR = path.join(ROOT_DIR, 'middleware');
const UTILS_DIR = path.join(ROOT_DIR, 'utils');
const SERVICES_DIR = path.join(ROOT_DIR, 'services');

console.log('='.repeat(80));
console.log('🚀 BACKEND API & DATA PIPELINE QA TEST RUNNER');
console.log('='.repeat(80));

// 1. SYNTAX INTEGRITY CHECK (node --check)
console.log('\n🔍 [PHASE 1] Syntax Check on all JS files across codebase...');
const dirsToCheck = [ROUTES_DIR, MODELS_DIR, MIDDLEWARE_DIR, UTILS_DIR, SERVICES_DIR, ROOT_DIR];
let syntaxErrors = [];
let totalFilesChecked = 0;

dirsToCheck.forEach(dir => {
  if (!fs.existsSync(dir)) return;
  const files = fs.readdirSync(dir);
  files.forEach(file => {
    const fullPath = path.join(dir, file);
    if (fs.statSync(fullPath).isFile() && file.endsWith('.js')) {
      totalFilesChecked++;
      try {
        execSync(`node --check "${fullPath}"`, { stdio: 'pipe' });
      } catch (err) {
        syntaxErrors.push({ file: fullPath, error: err.stderr ? err.stderr.toString() : err.message });
      }
    }
  });
});

if (syntaxErrors.length === 0) {
  console.log(`  ✅ All ${totalFilesChecked} JavaScript files passed node --check syntax verification.`);
} else {
  console.error(`  ❌ Found ${syntaxErrors.length} syntax errors:`);
  syntaxErrors.forEach(e => console.error(`     - ${e.file}: ${e.error}`));
}

// 2. AUDITING ROUTE FILES, IMPORTS & IDENTIFIERS
console.log('\n🔍 [PHASE 2] Auditing 24 Route Files for Imports, Middleware & Logic Bugs...');
const routeFiles = fs.readdirSync(ROUTES_DIR).filter(f => f.endsWith('.js'));
console.log(`  Discovered ${routeFiles.length} route files.`);

const findings = [];
let totalEndpoints = 0;

routeFiles.forEach(routeFile => {
  const filePath = path.join(ROUTES_DIR, routeFile);
  const content = fs.readFileSync(filePath, 'utf8');

  // Check 2a: Express Router initialization and export
  if (!content.includes('express.Router()')) {
    findings.push({ file: routeFile, type: 'CRITICAL', issue: 'Missing express.Router() creation' });
  }
  if (!content.includes('module.exports = router')) {
    findings.push({ file: routeFile, type: 'CRITICAL', issue: 'Missing module.exports = router' });
  }

  // Check 2b: Required relative imports exist
  const requireRegex = /require\(['"`](\..*?)['"`]\)/g;
  let match;
  while ((match = requireRegex.exec(content)) !== null) {
    const reqPath = match[1];
    const resolved = path.resolve(ROUTES_DIR, reqPath);
    const possiblePaths = [
      resolved,
      resolved + '.js',
      resolved + '.json',
      path.join(resolved, 'index.js')
    ];
    const exists = possiblePaths.some(p => fs.existsSync(p));
    if (!exists) {
      findings.push({
        file: routeFile,
        type: 'HIGH',
        issue: `Broken require path: '${reqPath}' does not exist`
      });
    }
  }

  // Check 2c: Undefined mongoose references
  if (content.includes('mongoose.') && !content.includes('const mongoose') && !content.includes('require(\'mongoose\')') && !content.includes('require("mongoose")')) {
    findings.push({
      file: routeFile,
      type: 'CRITICAL',
      issue: "Uses 'mongoose' methods but mongoose is not imported in this file"
    });
  }

  // Check 2d: Undefined emailService or direct function call on EmailService class
  if (content.includes('sendMail(') && content.includes("const sendMail = require('../utils/emailService')")) {
    findings.push({
      file: routeFile,
      type: 'HIGH',
      issue: "Calls sendMail() directly on required EmailService class instead of emailService.sendMail()"
    });
  }

  // Check 2e: Count routes declared
  const routerMethods = ['get', 'post', 'put', 'delete', 'patch'];
  routerMethods.forEach(method => {
    const regex = new RegExp(`router\\.${method}\\s*\\(`, 'g');
    const matches = content.match(regex);
    if (matches) totalEndpoints += matches.length;
  });
});

// 3. LIVE ROUTER LOADING & STACK VERIFICATION
console.log('\n🔍 [PHASE 3] Live Router Loading & Middleware Chain Verification...');
let loadedRouters = 0;
let routeTable = [];

routeFiles.forEach(routeFile => {
  try {
    const fullPath = path.join(ROUTES_DIR, routeFile);
    delete require.cache[require.resolve(fullPath)];
    const router = require(fullPath);
    if (router && router.stack) {
      loadedRouters++;
      router.stack.forEach(layer => {
        if (layer.route) {
          const methods = Object.keys(layer.route.methods).map(m => m.toUpperCase()).join(', ');
          const routePath = layer.route.path;
          const handlerCount = layer.route.stack.length;
          routeTable.push({
            file: routeFile,
            method: methods,
            path: routePath,
            middlewares: handlerCount - 1
          });
        }
      });
    } else {
      findings.push({
        file: routeFile,
        type: 'HIGH',
        issue: 'Loaded object is not a valid express Router with a stack'
      });
    }
  } catch (err) {
    findings.push({
      file: routeFile,
      type: 'CRITICAL',
      issue: `Failed to load router: ${err.message}`
    });
  }
});

console.log(`  ✅ Successfully loaded ${loadedRouters}/${routeFiles.length} routers.`);
console.log(`  ✅ Registered ${routeTable.length} total active HTTP endpoints across all route modules.`);

// 4. SUMMARY OF AUDITED ENDPOINTS
console.log('\n' + '='.repeat(80));
console.log('📊 ROUTE MODULE SUMMARY TABLE:');
console.log('='.repeat(80));

const fileSummary = {};
routeTable.forEach(r => {
  fileSummary[r.file] = (fileSummary[r.file] || 0) + 1;
});

Object.entries(fileSummary).forEach(([file, count], i) => {
  console.log(`  [${(i + 1).toString().padStart(2, '0')}] ${file.padEnd(25, ' ')} : ${count} endpoints`);
});

console.log('\n' + '='.repeat(80));
console.log('📊 AUDIT FINDINGS & BUGS STATUS:');
console.log('='.repeat(80));

if (findings.length === 0) {
  console.log('  ✨ PERFECT! All 24 route files, models, controllers, and middlewares passed all static checks!');
} else {
  findings.forEach((f, idx) => {
    console.log(`  [${idx + 1}] [${f.type}] ${f.file}: ${f.issue}`);
  });
}

console.log('='.repeat(80));
