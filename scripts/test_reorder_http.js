require('dotenv').config();
const connectDB = require('../config/db');
const { app } = require('../server');
const http = require('http');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const CustomField = require('../models/CustomField');
const mongoose = require('mongoose');

async function testHttpReorder() {
  await connectDB();
  console.log('Testing HTTP PUT /api/custom-fields/reorder...');

  // Get admin user for auth token
  const adminUser = await User.findOne({ role: 'owner' }).lean() || await User.findOne().lean();
  const token = jwt.sign(
    { id: adminUser._id, role: adminUser.role || 'owner', branch: adminUser.branch },
    process.env.JWT_SECRET || 'default_jwt_secret',
    { expiresIn: '1h' }
  );

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;

  const fields = await CustomField.find().limit(5).lean();
  const payload = JSON.stringify({
    orders: fields.map((f, idx) => ({
      id: f._id.toString(),
      fieldName: f.fieldName,
      order: idx + 1,
      section: f.section
    }))
  });

  const options = {
    hostname: '127.0.0.1',
    port: port,
    path: '/api/custom-fields/reorder',
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload),
      'Authorization': `Bearer ${token}`
    }
  };

  const response = await new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, data: JSON.parse(data) }));
    });
    req.on('error', reject);
    req.write(payload);
    req.end();
  });

  console.log('HTTP Status Code:', response.statusCode);
  console.log('Response Body:', response.data);

  server.close();
  await mongoose.disconnect();

  if (response.statusCode === 200 && response.data.success) {
    console.log('\n🎉 PUT /api/custom-fields/reorder HTTP ENDPOINT VERIFIED 100% WORKING WITHOUT CASTERROR!');
  } else {
    throw new Error(`Test failed with status ${response.statusCode}`);
  }
}

testHttpReorder().catch(err => {
  console.error('Test error:', err);
  process.exit(1);
});
