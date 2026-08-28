#!/usr/bin/env node
/**
 * Production Build Script — CSS & JS Minification
 * Uses esbuild for ultra-fast minification (no bundling, files stay separate)
 * 
 * Usage:
 *   node scripts/minify.js          # Minify all JS & CSS in public/
 *   node scripts/minify.js --dry    # Show what would be minified (dry run)
 *
 * This does NOT bundle files — it minifies each file individually in-place.
 * The service worker and dynamic imports continue to work as before.
 */

const fs = require('fs');
const path = require('path');

// Check if esbuild is available
let esbuild;
try {
  esbuild = require('esbuild');
} catch {
  console.error('❌ esbuild not installed. Run: npm install --save-dev esbuild');
  process.exit(1);
}

const PUBLIC_DIR = path.join(__dirname, '..', 'public');
const isDryRun = process.argv.includes('--dry');

// Files/patterns to SKIP (should not be minified)
const SKIP_PATTERNS = [
  'sw.js',           // Service worker — keep readable for debugging
  '.min.js',         // Already minified
  '.min.css',        // Already minified
  'node_modules',
];

function shouldSkip(filePath) {
  return SKIP_PATTERNS.some(pattern => filePath.includes(pattern));
}

function getAllFiles(dir, extensions) {
  const results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      results.push(...getAllFiles(fullPath, extensions));
    } else if (extensions.some(ext => entry.name.endsWith(ext))) {
      if (!shouldSkip(fullPath)) {
        results.push(fullPath);
      }
    }
  }
  return results;
}

async function minify() {
  const jsFiles = getAllFiles(PUBLIC_DIR, ['.js']);
  const cssFiles = getAllFiles(PUBLIC_DIR, ['.css']);
  const allFiles = [...jsFiles, ...cssFiles];

  console.log(`\n🔧 Study Library Minification Script`);
  console.log(`   Found: ${jsFiles.length} JS files, ${cssFiles.length} CSS files`);
  if (isDryRun) console.log(`   Mode: DRY RUN (no changes)\n`);
  else console.log(`   Mode: MINIFY IN-PLACE\n`);

  let totalOriginal = 0;
  let totalMinified = 0;
  let fileCount = 0;

  for (const filePath of allFiles) {
    const original = fs.readFileSync(filePath, 'utf8');
    const originalSize = Buffer.byteLength(original, 'utf8');
    totalOriginal += originalSize;

    const isJS = filePath.endsWith('.js');
    const loader = isJS ? 'js' : 'css';

    try {
      const result = await esbuild.transform(original, {
        loader,
        minify: true,
        ...(isJS ? { target: 'es2020', format: 'esm' } : {}),
      });

      const minifiedSize = Buffer.byteLength(result.code, 'utf8');
      totalMinified += minifiedSize;
      const savings = ((1 - minifiedSize / originalSize) * 100).toFixed(1);
      const relativePath = path.relative(PUBLIC_DIR, filePath);

      if (!isDryRun) {
        fs.writeFileSync(filePath, result.code, 'utf8');
      }

      const sizeStr = `${(originalSize / 1024).toFixed(1)}KB -> ${(minifiedSize / 1024).toFixed(1)}KB`;
      console.log(`  ${isDryRun ? '📋' : '✅'} ${relativePath.padEnd(45)} ${sizeStr.padEnd(22)} -${savings}%`);
      fileCount++;
    } catch (err) {
      console.error(`  ❌ ${path.relative(PUBLIC_DIR, filePath)}: ${err.message}`);
      totalMinified += originalSize;
    }
  }

  const totalSavingsKB = ((totalOriginal - totalMinified) / 1024).toFixed(1);
  const totalSavingsPct = ((1 - totalMinified / totalOriginal) * 100).toFixed(1);

  console.log(`\n${'─'.repeat(80)}`);
  console.log(`  📊 Total: ${fileCount} files`);
  console.log(`     Original: ${(totalOriginal / 1024).toFixed(1)}KB`);
  console.log(`     Minified: ${(totalMinified / 1024).toFixed(1)}KB`);
  console.log(`     Savings:  ${totalSavingsKB}KB (${totalSavingsPct}%)`);
  if (isDryRun) {
    console.log(`\n  💡 Run without --dry to apply minification`);
  } else {
    console.log(`\n  ✅ All files minified in-place!`);
  }
  console.log('');
}

minify().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
