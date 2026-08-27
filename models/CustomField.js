const mongoose = require('mongoose');

const customFieldSchema = new mongoose.Schema({
  fieldName: {
    type: String,
    required: [true, 'Field slug/identifier is required'],
    trim: true,
    unique: true,
    lowercase: true
  },
  label: {
    type: String,
    required: [true, 'Field display label is required'],
    trim: true
  },
  type: {
    type: String,
    required: [true, 'Field input type is required'],
    enum: [
      'text',
      'textarea',
      'number',
      'phone',
      'email',
      'date',
      'time',
      'select',
      'multiselect',
      'radio',
      'checkbox',
      'file',
      'photo_upload',
      'signature_pad',
      'exam_badge',
      'blood_group',
      'url',
      'color',
      'address_autocomplete',
      'aadhaar_pan',
      'terms_checkbox',
      'star_rating'
    ],
    default: 'text'
  },
  placeholder: {
    type: String,
    default: ''
  },
  options: [{
    type: String,
    trim: true
  }],
  required: {
    type: Boolean,
    default: false
  },
  order: {
    type: Number,
    default: 0
  },
  section: {
    type: String,
    default: 'personal'
  },
  sectionLabel: {
    type: String,
    default: 'Personal Details'
  },
  isActive: {
    type: Boolean,
    default: true
  },
  isSystemField: {
    type: Boolean,
    default: false
  },
  isDeletable: {
    type: Boolean,
    default: true
  },
  helpText: {
    type: String,
    default: ''
  },
  defaultValue: {
    type: mongoose.Schema.Types.Mixed,
    default: null
  },
  
  // Validation rules
  validation: {
    minLength: { type: Number, default: null },
    maxLength: { type: Number, default: null },
    pattern: { type: String, default: '' },
    patternMessage: { type: String, default: '' }
  },
  
  // Conditional visibility
  conditional: {
    enabled: { type: Boolean, default: false },
    dependsOn: { type: String, default: '' },  // fieldName of parent field
    showWhen: { type: String, default: '' },     // value that triggers visibility
    operator: { type: String, enum: ['equals', 'not_equals', 'contains', 'not_empty'], default: 'equals' }
  },
  
  // Section configuration (stored on first field of each section)
  sectionIcon: { type: String, default: '' },
  sectionDescription: { type: String, default: '' },
  sectionInstructions: { type: String, default: '' },
  sectionCollapsible: { type: Boolean, default: true },
  
  // Field behavior
  isReadOnly: { type: Boolean, default: false },
  colSpan: { type: Number, default: 12, min: 1, max: 12 }  // 6 = half width, 12 = full width (also supports 1, 2)
}, {
  timestamps: true
});

customFieldSchema.statics.getActiveFields = function() {
  return this.find({ isActive: true }).sort({ order: 1, createdAt: 1 });
};

// Seed all 18 standard admission questions if database is empty
customFieldSchema.statics.seedDefaultFields = async function(force = false) {
  const count = await this.countDocuments();
  if (count === 0 || force) {
    if (force) await this.deleteMany({});

    const standardFields = [
      // 1. Personal Information Section
      {
        fieldName: 'branch',
        label: 'Preferred Study Centre / Branch',
        type: 'select',
        placeholder: 'Select preferred study centre',
        required: true,
        order: 0,
        section: 'personal',
        sectionLabel: 'Study Centre & Personal Info',
        sectionIcon: '🏢',
        sectionDescription: 'Study centre branch and basic identification',
        isSystemField: true,
        isDeletable: false,
        helpText: 'Select your preferred study centre / reading hall branch'
      },
      {
        fieldName: 'name',
        label: 'Full Name',
        type: 'text',
        placeholder: 'e.g. Rahul Sharma',
        required: true,
        order: 1,
        section: 'personal',
        sectionLabel: 'Study Centre & Personal Info',
        sectionIcon: '👤',
        sectionDescription: 'Basic identification details',
        isSystemField: true,
        isDeletable: false,
        helpText: 'Student legal full name'
      },
      {
        fieldName: 'phone',
        label: 'Mobile / WhatsApp Number',
        type: 'phone',
        placeholder: '10-digit mobile number (e.g. 9876543210)',
        required: true,
        order: 2,
        section: 'personal',
        sectionLabel: 'Personal Information',
        isSystemField: true,
        isDeletable: false,
        helpText: 'Used for admission confirmation and WhatsApp reminders'
      },
      {
        fieldName: 'email',
        label: 'Email Address',
        type: 'email',
        placeholder: 'student@example.com',
        required: false,
        order: 3,
        section: 'personal',
        sectionLabel: 'Personal Information',
        isSystemField: true,
        isDeletable: true,
        helpText: 'For student portal access and receipts'
      },
      {
        fieldName: 'gender',
        label: 'Gender',
        type: 'radio',
        options: ['Male', 'Female', 'Other'],
        required: false,
        order: 4,
        section: 'personal',
        sectionLabel: 'Personal Information',
        isSystemField: true,
        isDeletable: true,
        defaultValue: ''
      },
      {
        fieldName: 'dateOfBirth',
        label: 'Date of Birth',
        type: 'date',
        required: false,
        order: 5,
        section: 'personal',
        sectionLabel: 'Personal Information',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'bloodGroup',
        label: 'Blood Group',
        type: 'blood_group',
        options: ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
        required: false,
        order: 6,
        section: 'personal',
        sectionLabel: 'Personal Information',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'photo',
        label: 'Student Passport Photo',
        type: 'photo_upload',
        placeholder: 'Upload photo or take webcam selfie',
        required: false,
        order: 7,
        section: 'personal',
        sectionLabel: 'Personal Information',
        isSystemField: true,
        isDeletable: true,
        helpText: 'Printed on library ID card'
      },

      // 2. Academic / Exam Details Section
      {
        fieldName: 'targetExams',
        label: 'Target Competitive Exams',
        type: 'exam_badge',
        options: ['UPSC', 'MPSC', 'Banking / IBPS', 'SSC CGL', 'JEE / NEET', 'CA / CS', 'GATE', 'UGC NET', 'State PSC', 'Law / CLAT', 'Defence / NDA', 'Other'],
        required: false,
        order: 8,
        section: 'academic',
        sectionLabel: 'Academic & Preparation',
        sectionIcon: '📚',
        sectionDescription: 'Educational background and exam goals',
        isSystemField: true,
        isDeletable: true,
        helpText: 'Select all exams student is preparing for'
      },
      {
        fieldName: 'occupation',
        label: 'College / Coaching Institute / Company',
        type: 'text',
        placeholder: 'e.g. Pune University / Chanakya Academy',
        required: false,
        order: 9,
        section: 'academic',
        sectionLabel: 'Academic & Preparation',
        isSystemField: true,
        isDeletable: true
      },

      // 3. Contact & Address Section
      {
        fieldName: 'address',
        label: 'Residential Address / Hostel Room No.',
        type: 'textarea',
        placeholder: 'Flat/Room No., Building, Area/Street',
        required: false,
        order: 10,
        section: 'contact',
        sectionLabel: 'Address & Emergency Contact',
        sectionIcon: '📍',
        sectionDescription: 'Address and emergency contact information',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'city',
        label: 'City',
        type: 'text',
        placeholder: 'e.g. Pune',
        required: false,
        order: 11,
        section: 'contact',
        sectionLabel: 'Address & Emergency Contact',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'state',
        label: 'State',
        type: 'text',
        placeholder: 'e.g. Maharashtra',
        required: false,
        order: 12,
        section: 'contact',
        sectionLabel: 'Address & Emergency Contact',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'pincode',
        label: 'Pincode',
        type: 'number',
        placeholder: '411001',
        required: false,
        order: 13,
        section: 'contact',
        sectionLabel: 'Address & Emergency Contact',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'emergencyContact',
        label: 'Emergency Contact (Parent / Guardian Phone)',
        type: 'phone',
        placeholder: 'Parent mobile number',
        required: false,
        order: 14,
        section: 'contact',
        sectionLabel: 'Address & Emergency Contact',
        isSystemField: true,
        isDeletable: true
      },

      // 4. KYC & Verification Section
      {
        fieldName: 'idProofType',
        label: 'Government ID Proof Type',
        type: 'select',
        options: ['Aadhaar Card', 'PAN Card', 'Voter ID', 'Driving License', 'College Student ID', 'Passport'],
        required: false,
        order: 15,
        section: 'kyc',
        sectionLabel: 'KYC & Verification',
        sectionIcon: '🪪',
        sectionDescription: 'Identity verification and digital signature',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'idProofNumber',
        label: 'ID Proof Document Number',
        type: 'text',
        placeholder: 'e.g. Last 4 digits of Aadhaar or ID number',
        required: false,
        order: 16,
        section: 'kyc',
        sectionLabel: 'KYC & Verification',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'idProofImage',
        label: 'ID Proof Photo / Document Upload',
        type: 'file',
        placeholder: 'Upload Aadhaar or ID document copy',
        required: false,
        order: 17,
        section: 'kyc',
        sectionLabel: 'KYC & Verification',
        isSystemField: true,
        isDeletable: true
      },
      {
        fieldName: 'signature',
        label: 'Digital Signature (Draw or Touch)',
        type: 'signature_pad',
        placeholder: 'Sign using touch or mouse',
        required: false,
        order: 18,
        section: 'kyc',
        sectionLabel: 'KYC & Verification',
        isSystemField: true,
        isDeletable: true,
        helpText: 'Applicant acceptance of library rules and terms'
      },
      {
        fieldName: 'notes',
        label: 'Special Remarks / Admin Notes',
        type: 'textarea',
        placeholder: 'Any health conditions, locker preference, discount notes, etc.',
        required: false,
        order: 19,
        section: 'other',
        sectionLabel: 'Additional Information',
        sectionIcon: '📝',
        sectionDescription: 'Additional notes and preferences',
        isSystemField: true,
        isDeletable: true
      }
    ];

    await this.insertMany(standardFields);
  }
};

// Ensure all standard system fields exist without overwriting custom reordering
customFieldSchema.statics.ensureStandardFields = async function() {
  try {
    const existing = await this.find().select('fieldName').lean();
    const existingNames = new Set(existing.map(f => f.fieldName.toLowerCase()));
    
    // Check if branch field is present
    if (!existingNames.has('branch')) {
      await this.create({
        fieldName: 'branch',
        label: 'Preferred Study Centre / Branch',
        type: 'select',
        placeholder: 'Select preferred study centre',
        required: true,
        order: 0,
        section: 'personal',
        sectionLabel: 'Study Centre & Personal Info',
        sectionIcon: '🏢',
        sectionDescription: 'Study centre branch and basic identification',
        isSystemField: true,
        isDeletable: false,
        helpText: 'Select your preferred study centre / reading hall branch'
      });
    }
  } catch (err) {
    console.error('Error ensuring standard custom fields:', err);
  }
};

module.exports = mongoose.model('CustomField', customFieldSchema);
