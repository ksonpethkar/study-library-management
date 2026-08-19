const mongoose = require('mongoose');

const expenseCategorySchema = new mongoose.Schema({
  name: {
    type: String,
    required: [true, 'Category name is required'],
    unique: true,
    trim: true
  },
  icon: {
    type: String,
    default: '💸'
  },
  color: {
    type: String,
    default: '#e74c3c'
  },
  description: {
    type: String,
    trim: true,
    default: ''
  },
  isSystem: {
    type: Boolean,
    default: false
  }
}, {
  timestamps: true
});

expenseCategorySchema.statics.seedDefaultCategories = async function() {
  const count = await this.countDocuments();
  if (count === 0) {
    const defaultCategories = [
      { name: 'Rent', icon: '🏢', color: '#3498db', isSystem: true },
      { name: 'Electricity & Utilities', icon: '⚡', color: '#f1c40f', isSystem: true },
      { name: 'High-Speed Wi-Fi', icon: '📶', color: '#9b59b6', isSystem: true },
      { name: 'Staff Salary', icon: '👥', color: '#2ecc71', isSystem: true },
      { name: 'Cleaning & Supplies', icon: '🧹', color: '#1abc9c', isSystem: true },
      { name: 'Tea & Refreshments', icon: '☕', color: '#e67e22', isSystem: true },
      { name: 'Maintenance & Repair', icon: '🔧', color: '#7f8c8d', isSystem: true },
      { name: 'Marketing & Ads', icon: '📢', color: '#e74c3c', isSystem: true }
    ];
    await this.insertMany(defaultCategories);
  }
};

module.exports = mongoose.model('ExpenseCategory', expenseCategorySchema);
