require('dotenv').config();
const connectDB = require('../config/db');
const LandingPage = require('../models/LandingPage');

async function main() {
  await connectDB();
  const config = await LandingPage.getPageConfig();
  console.log('Current quickLinks in DB:', JSON.stringify(config.footer?.quickLinks, null, 2));
  
  // If quickLinks has Gate Kiosk or Staff Login, clean it up to match user's custom settings
  if (config.footer && Array.isArray(config.footer.quickLinks)) {
    config.footer.quickLinks = config.footer.quickLinks.filter(l => 
      !l.label.includes('Gate Kiosk') && 
      !l.label.includes('Staff & Owner') &&
      !l.label.includes('Staff Login')
    );
    await config.save();
    console.log('Cleaned quickLinks in DB:', JSON.stringify(config.footer.quickLinks, null, 2));
  }
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
