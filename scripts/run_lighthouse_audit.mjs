import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const targetUrl = process.argv[2] || 'https://study-lib-mgmt-2026.web.app/app/';
const budgetPath = path.resolve(__dirname, '../budget.json');
const outputDir = path.resolve(__dirname, '../build/reports');

if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

console.log(`🚀 Starting Lighthouse Audit for: ${targetUrl}`);
console.log(`📋 Performance budget: ${budgetPath}`);

const reportHtml = path.join(outputDir, 'lighthouse-report.html');
const reportJson = path.join(outputDir, 'lighthouse-report.json');

const cmd = `npx lighthouse ${targetUrl} ` +
  `--output=html,json ` +
  `--output-path=${path.join(outputDir, 'lighthouse-report')} ` +
  `--budget-path="${budgetPath}" ` +
  `--chrome-flags="--headless --no-sandbox --disable-gpu" ` +
  `--only-categories=performance,accessibility,best-practices,seo ` +
  `--quiet`;

console.log(`Executing: ${cmd}`);

try {
  execSync(cmd, { stdio: 'inherit' });
  console.log(`\n✅ Lighthouse audit complete!`);
  console.log(`📄 HTML Report: ${reportHtml}`);
  console.log(`📊 JSON Report: ${reportJson}`);

  if (fs.existsSync(reportJson)) {
    const raw = fs.readFileSync(reportJson, 'utf8');
    const data = JSON.parse(raw);
    const scores = {
      performance: Math.round(data.categories.performance.score * 100),
      accessibility: Math.round(data.categories.accessibility.score * 100),
      bestPractices: Math.round(data.categories['best-practices'].score * 100),
      seo: Math.round(data.categories.seo.score * 100)
    };
    console.log('\n📊 Audit Scores Summary:');
    console.log(`  Performance:    ${scores.performance}/100`);
    console.log(`  Accessibility:  ${scores.accessibility}/100`);
    console.log(`  Best Practices: ${scores.bestPractices}/100`);
    console.log(`  SEO:            ${scores.seo}/100`);
  }
} catch (e) {
  console.warn('⚠️ Note: To run local Lighthouse, ensure Google Chrome is installed.');
  console.log(`Command to run manually when connected:`);
  console.log(`  npx lighthouse ${targetUrl} --budget-path=budget.json --view`);
}
