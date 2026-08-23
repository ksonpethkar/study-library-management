const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.join(__dirname, '..');

// Scan all js, html, and json files in public, routes, models, utils
const extensions = ['.js', '.html'];
const searchPatterns = [
  { label: 'Hardcoded Business Names', regex: /(?:Cozy Corner|thecozycorner|StudyLib Pro|Study Zone Main)/gi },
  { label: 'Hardcoded Demo Phone Numbers', regex: /(?:\+?91\s*9876543210|9876543210|9822012345|\+91\s*98220\s*12345|\+91\s*88888\s*99999)/gi },
  { label: 'Hardcoded Demo Email Addresses', regex: /(?:admin@studylibrary\.com|contact@cozycorner\.com|info@thecozycorner\.in|info@library\.com|test@studylib\.com)/gi },
  { label: 'Hardcoded Demo UPI IDs', regex: /(?:thecozycorner@okaxis|library@upi|studyzone@icici|admin@okhdfcbank)/gi },
  { label: 'Hardcoded Cities / Addresses', regex: /(?:FC Road,?\s*Pune|Pune,?\s*Maharashtra|Central City|Shivaji Nagar,?\s*Pune)/gi },
  { label: 'Hardcoded Competitive Exam Lists', regex: /(?:\[\s*['"]UPSC|data-exam="UPSC)/gi },
  { label: 'Hardcoded Currency Symbols', regex: /['"]₹['"]|['"]INR['"]/gi }
];

function scanDirectory(dir) {
  let results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules' && entry.name !== '.git' && entry.name !== 'dist') {
        results = results.concat(scanDirectory(fullPath));
      }
    } else if (entry.isFile() && extensions.some(ext => entry.name.endsWith(ext))) {
      results.push(fullPath);
    }
  }
  return results;
}

const files = scanDirectory(ROOT_DIR);
const findings = {};

searchPatterns.forEach(pat => {
  findings[pat.label] = [];
});

files.forEach(file => {
  const relPath = path.relative(ROOT_DIR, file);
  if (relPath.startsWith('scripts\\') || relPath.startsWith('scripts/')) return;
  
  const content = fs.readFileSync(file, 'utf8');
  const lines = content.split('\n');

  searchPatterns.forEach(pat => {
    lines.forEach((line, idx) => {
      pat.regex.lastIndex = 0;
      if (pat.regex.test(line)) {
        findings[pat.label].push({
          file: relPath,
          line: idx + 1,
          snippet: line.trim()
        });
      }
    });
  });
});

console.log('===========================================================');
console.log('        🔍 HARDCODED VALUES & STRINGS AUDIT REPORT         ');
console.log('===========================================================\n');

let totalCount = 0;
for (const [label, matches] of Object.entries(findings)) {
  console.log(`📌 ${label}: ${matches.length} occurrences found`);
  totalCount += matches.length;
  matches.slice(0, 10).forEach(m => {
    console.log(`   • [${m.file}:${m.line}] -> ${m.snippet.substring(0, 100)}`);
  });
  if (matches.length > 10) {
    console.log(`   ... and ${matches.length - 10} more occurrences.`);
  }
  console.log('');
}

console.log(`Total occurrences flagged: ${totalCount}`);
