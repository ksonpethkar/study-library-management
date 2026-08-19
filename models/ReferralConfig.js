const mongoose = require('mongoose');

const referralConfigSchema = new mongoose.Schema({
  isEnabled: { type: Boolean, default: true },
  referrerRewardType: { type: String, enum: ['flat', 'percentage'], default: 'flat' },
  referrerRewardAmount: { type: Number, default: 100 },
  refereeRewardType: { type: String, enum: ['flat', 'percentage'], default: 'flat' },
  refereeRewardAmount: { type: Number, default: 100 },
  minPlanAmount: { type: Number, default: 500 },
  autoApplyToNextRenewal: { type: Boolean, default: true },
  maxReferralsPerStudent: { type: Number, default: 50 },
  customInviteMessage: {
    type: String,
    default: 'Hey! Join our study library with my referral code {CODE} to get an instant discount on your admission! Register here: {LINK}'
  }
}, { timestamps: true });

referralConfigSchema.statics.getConfig = async function() {
  let config = await this.findOne();
  if (!config) {
    config = await this.create({
      isEnabled: true,
      referrerRewardType: 'flat',
      referrerRewardAmount: 100,
      refereeRewardType: 'flat',
      refereeRewardAmount: 100,
      minPlanAmount: 500,
      autoApplyToNextRenewal: true
    });
  }
  return config;
};

module.exports = mongoose.model('ReferralConfig', referralConfigSchema);
