/**
 * Automated Mobile App Manager for Cozy Corner Library
 * Generates and synchronizes Dual Native Android / iOS Applications:
 *   1. Student Mobile App (com.cozycorner.studentapp)
 *   2. Admin & Staff Mobile App (com.cozycorner.adminapp)
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const ROOT_DIR = path.resolve(__dirname, '..');
const targetApp = process.argv[2] || 'student'; // 'student' | 'admin' | 'all'
const action = process.argv[3] || 'sync';       // 'init' | 'sync' | 'open' | 'build'

const APPS = {
  student: {
    name: 'Student Portal App',
    configSrc: path.join(ROOT_DIR, 'capacitor.student.json'),
    appId: 'com.cozycorner.studentapp',
    appName: 'Cozy Corner Student Portal',
    androidDir: path.join(ROOT_DIR, 'android-student'),
    serverUrl: 'https://study-library-management.onrender.com/student-login'
  },
  admin: {
    name: 'Admin & Staff Portal App',
    configSrc: path.join(ROOT_DIR, 'capacitor.admin.json'),
    appId: 'com.cozycorner.adminapp',
    appName: 'Cozy Corner Admin Hub',
    androidDir: path.join(ROOT_DIR, 'android-admin'),
    serverUrl: 'https://study-library-management.onrender.com'
  }
};

function run(cmd, cwd = ROOT_DIR) {
  console.log(`\x1b[36m> ${cmd}\x1b[0m`);
  execSync(cmd, { cwd, stdio: 'inherit' });
}

function configureActiveCapacitorConfig(appKey) {
  const app = APPS[appKey];
  const activeConfigPath = path.join(ROOT_DIR, 'capacitor.config.json');
  fs.copyFileSync(app.configSrc, activeConfigPath);
  console.log(`\x1b[32m✔ Switched active configuration to: ${app.name}\x1b[0m`);
}

function enhanceAndroidManifest(androidProjectDir, appKey) {
  const manifestPath = path.join(androidProjectDir, 'app', 'src', 'main', 'AndroidManifest.xml');
  if (!fs.existsSync(manifestPath)) return;

  let manifest = fs.readFileSync(manifestPath, 'utf8');

  const permissions = [
    '<uses-permission android:name="android.permission.INTERNET" />',
    '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />',
    '<uses-permission android:name="android.permission.CAMERA" />',
    '<uses-permission android:name="android.permission.VIBRATE" />',
    '<uses-permission android:name="android.permission.USE_BIOMETRIC" />',
    '<uses-permission android:name="android.permission.USE_FINGERPRINT" />'
  ];

  if (appKey === 'admin') {
    permissions.push(
      '<uses-permission android:name="android.permission.BLUETOOTH" />',
      '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />',
      '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />'
    );
  }

  permissions.forEach(p => {
    if (!manifest.includes(p)) {
      manifest = manifest.replace('<application', `    ${p}\n    <application`);
    }
  });

  // Enable hardware acceleration and cleartext traffic
  if (!manifest.includes('android:usesCleartextTraffic')) {
    manifest = manifest.replace('<application', '<application android:usesCleartextTraffic="true"');
  }

  fs.writeFileSync(manifestPath, manifest, 'utf8');
  console.log(`\x1b[32m✔ Enhanced AndroidManifest.xml with hardware permissions for ${appKey}\x1b[0m`);
}

function processApp(appKey) {
  const app = APPS[appKey];
  console.log(`\n======================================================`);
  console.log(`  📱 Processing: ${app.name} (${app.appId})`);
  console.log(`  🔗 Target URL: ${app.serverUrl}`);
  console.log(`======================================================\n`);

  configureActiveCapacitorConfig(appKey);

  const defaultAndroidDir = path.join(ROOT_DIR, 'android');

  if (action === 'init' || !fs.existsSync(app.androidDir)) {
    console.log(`Initializing Android native container...`);
    if (fs.existsSync(defaultAndroidDir)) {
      fs.rmSync(defaultAndroidDir, { recursive: true, force: true });
    }
    run('npx cap add android');
    if (fs.existsSync(defaultAndroidDir)) {
      if (fs.existsSync(app.androidDir)) {
        fs.rmSync(app.androidDir, { recursive: true, force: true });
      }
      fs.renameSync(defaultAndroidDir, app.androidDir);
    }
  }

  // Restore active android directory for sync/open
  if (fs.existsSync(app.androidDir)) {
    if (fs.existsSync(defaultAndroidDir)) {
      fs.rmSync(defaultAndroidDir, { recursive: true, force: true });
    }
    // Copy or point
    fs.cpSync(app.androidDir, defaultAndroidDir, { recursive: true });
  }

  run('npx cap sync android');
  enhanceAndroidManifest(defaultAndroidDir, appKey);

  // Sync back enhanced files to specific app directory
  fs.cpSync(defaultAndroidDir, app.androidDir, { recursive: true });

  if (action === 'open') {
    console.log(`\n🚀 Launching Android Studio for ${app.name}...`);
    run('npx cap open android');
  }

  console.log(`\n\x1b[32m✨ ${app.name} is ready at: ${app.androidDir}\x1b[0m\n`);
}

async function main() {
  if (targetApp === 'all') {
    processApp('student');
    processApp('admin');
  } else if (APPS[targetApp]) {
    processApp(targetApp);
  } else {
    console.error(`Invalid app target: ${targetApp}. Use 'student', 'admin', or 'all'.`);
    process.exit(1);
  }
}

main().catch(err => {
  console.error('\x1b[31mError building mobile apps:\x1b[0m', err.message);
  process.exit(1);
});
