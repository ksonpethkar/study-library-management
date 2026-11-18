import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Target directory can be public/app or build/web
const candidateDirs = [
  path.resolve(__dirname, '../public/app'),
  path.resolve(__dirname, '../../public/app'),
  path.resolve(__dirname, '../build/web')
];

let targetDir = candidateDirs.find(d => fs.existsSync(d));

if (!targetDir) {
  console.warn('⚠️ No built web directory found to evaluate. Tested:', candidateDirs);
  console.log('Skipping bundle budget check (run after flutter build web).');
  process.exit(0);
}

console.log('🔍 Checking Web Bundle Performance Budget in:', targetDir);

const MAX_MAIN_JS_RAW_MB = 12.0;
const MAX_MAIN_JS_GZIP_MB = 3.5;
const MAX_CANVASKIT_WASM_MB = 8.0;

function formatMB(bytes) {
  return (bytes / (1024 * 1024)).toFixed(2) + ' MB';
}

let violations = 0;

// 1. Check main.dart.js
const mainJsPath = path.join(targetDir, 'main.dart.js');
if (fs.existsSync(mainJsPath)) {
  const stat = fs.statSync(mainJsPath);
  const rawMB = stat.size / (1024 * 1024);
  const gzipped = zlib.gzipSync(fs.readFileSync(mainJsPath));
  const gzipMB = gzipped.length / (1024 * 1024);

  console.log(`📦 main.dart.js: Raw = ${formatMB(stat.size)}, Gzip = ${formatMB(gzipped.length)}`);

  if (rawMB > MAX_MAIN_JS_RAW_MB) {
    console.error(`❌ VIOLATION: main.dart.js raw size (${rawMB.toFixed(2)} MB) exceeds budget (${MAX_MAIN_JS_RAW_MB} MB)`);
    violations++;
  } else {
    console.log(`  ✅ Raw size within ${MAX_MAIN_JS_RAW_MB} MB budget`);
  }

  if (gzipMB > MAX_MAIN_JS_GZIP_MB) {
    console.error(`❌ VIOLATION: main.dart.js gzip size (${gzipMB.toFixed(2)} MB) exceeds budget (${MAX_MAIN_JS_GZIP_MB} MB)`);
    violations++;
  } else {
    console.log(`  ✅ Gzip size within ${MAX_MAIN_JS_GZIP_MB} MB budget`);
  }
} else {
  console.log('ℹ️ main.dart.js not found in target dir.');
}

// 2. Check canvaskit.wasm if present
const canvaskitWasmPath = path.join(targetDir, 'canvaskit/canvaskit.wasm');
if (fs.existsSync(canvaskitWasmPath)) {
  const stat = fs.statSync(canvaskitWasmPath);
  const wasmMB = stat.size / (1024 * 1024);
  console.log(`📦 canvaskit.wasm: ${formatMB(stat.size)}`);
  if (wasmMB > MAX_CANVASKIT_WASM_MB) {
    console.error(`❌ VIOLATION: canvaskit.wasm (${wasmMB.toFixed(2)} MB) exceeds budget (${MAX_CANVASKIT_WASM_MB} MB)`);
    violations++;
  } else {
    console.log(`  ✅ canvaskit.wasm within ${MAX_CANVASKIT_WASM_MB} MB budget`);
  }
}

if (violations > 0) {
  console.error(`\n🚨 FAILED: ${violations} bundle budget violation(s) detected.`);
  process.exit(1);
} else {
  console.log('\n🎉 ALL BUNDLE BUDGET CHECKS PASSED [OK]');
}
