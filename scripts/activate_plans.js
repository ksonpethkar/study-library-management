require('dotenv').config();
const connectDB = require('../config/db');
const Plan = require('../models/Plan');

async function main() {
  await connectDB();
  const res = await Plan.updateMany({ isDeleted: { $ne: true } }, { $set: { isActive: true } });
  console.log('Updated active plans:', res);
  const all = await Plan.find().lean();
  console.log('All plans:', all.map(p => ({ id: p._id, name: p.name, price: p.price, isActive: p.isActive })));
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
