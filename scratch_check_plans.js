const dns = require('dns');
try {
  if (dns.setDefaultResultOrder) {
    dns.setDefaultResultOrder('ipv4first');
  }
  dns.setServers(['8.8.8.8', '8.8.4.4', '1.1.1.1']);
} catch (e) {}

const mongoose = require('mongoose');
require('dotenv').config({ path: 'c:/Users/ksonp/Downloads/Library Management System/.env' });

async function checkPlans() {
  await mongoose.connect(process.env.MONGODB_URI);
  const Plan = require('./models/Plan');
  const plans = await Plan.find({}).lean();
  console.log('All Plans in DB:', JSON.stringify(plans, null, 2));
  process.exit(0);
}

checkPlans();
