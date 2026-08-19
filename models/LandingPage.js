const mongoose = require('mongoose');

const landingPageSchema = new mongoose.Schema({
  // Hero / Banner Section
  hero: {
    title: { type: String, default: 'Premier Air-Conditioned Study Library & Reading Hall' },
    subtitle: { type: String, default: 'Peaceful, Disciplined & Distraction-Free Study Environment for Competitive Exam Aspirants.' },
    bannerImage: { type: String, default: '' },
    ctaPrimaryText: { type: String, default: 'Book Your Seat / Register Now' },
    ctaPrimaryLink: { type: String, default: '/register' },
    ctaSecondaryText: { type: String, default: 'Send Quick Enquiry' },
    ctaSecondaryLink: { type: String, default: '#enquiry-section' },
    badges: [{ type: String }],
    enableTicker: { type: Boolean, default: true },
    tickerText: { type: String, default: '⚡ Limited Seats Available for Morning & Full Day Shifts! Reserve Yours Today.' },
    liveSeatBadge: {
      enabled: { type: Boolean, default: true },
      text: { type: String, default: 'Only 12 Seats Left' }
    }
  },

  // About Section
  about: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'About Our Study Library' },
    subtitle: { type: String, default: 'Why Choose Our Reading Hall?' },
    description: { type: String, default: 'Designed specifically for UPSC, MPSC, Banking, SSC, NEET/JEE, CA, and other exam aspirants. We provide ergonomic seating, high-speed Wi-Fi, pin-drop silence, and premium amenities to supercharge your study focus.' },
    highlightPoints: [{ type: String }],
    stats: [{
      number: { type: String },
      label: { type: String }
    }]
  },

  // Facilities / Amenities Section
  facilities: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'World-Class Amenities & Facilities' },
    subtitle: { type: String, default: 'Everything you need for uninterrupted, comfortable 14+ hours study sessions.' },
    items: [{
      icon: { type: String, default: '❄️' },
      title: { type: String, required: true },
      description: { type: String, default: '' }
    }]
  },

  // Shifts Guide Section
  shifts: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'Flexible Study Shifts' },
    subtitle: { type: String, default: 'Choose a timing that fits your schedule.' },
    items: [{
      name: { type: String, required: true },
      timing: { type: String, default: '' },
      description: { type: String, default: '' },
      icon: { type: String, default: '🕒' }
    }]
  },

  // Rules & Discipline Section
  rules: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'Library Rules & Code of Conduct' },
    subtitle: { type: String, default: 'To maintain a peaceful and productive atmosphere for everyone, all members must adhere to these rules.' },
    items: [{ type: String }]
  },

  // Gallery & Achievement Posters Section
  gallery: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'Library Hall & Facilities Gallery' },
    subtitle: { type: String, default: 'A glimpse into our state-of-the-art reading halls and study infrastructure.' },
    images: [{
      url: { type: String, required: true },
      caption: { type: String, default: '' },
      category: { type: String, default: 'Hall' }
    }]
  },

  // FAQs Section
  faqs: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'Frequently Asked Questions' },
    subtitle: { type: String, default: 'Find answers to common queries.' },
    items: [{
      question: { type: String, required: true },
      answer: { type: String, required: true }
    }]
  },

  // Testimonials / Reviews Section
  testimonials: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'What Our Students Say' },
    googleRating: { type: String, default: '4.9' },
    googleReviewsCount: { type: String, default: '250+ Reviews' },
    items: [{
      name: { type: String, required: true },
      exam: { type: String, default: 'UPSC Aspirant' },
      feedback: { type: String, required: true },
      rating: { type: Number, default: 5 },
      avatar: { type: String, default: '' }
    }]
  },

  // Contact & Location Details
  contact: {
    enabled: { type: Boolean, default: true },
    phone: { type: String, default: '+91 9876543210' },
    whatsapp: { type: String, default: '+91 9876543210' },
    email: { type: String, default: 'info@studylibrary.com' },
    address: { type: String, default: '2nd Floor, Sai Complex, Near Metro Station, Pune, Maharashtra 411001' },
    googleMapEmbedUrl: { type: String, default: '' },
    openingHours: { type: String, default: 'Open Daily: 06:00 AM – 11:00 PM (365 Days)' }
  },

  // Public Enquiry Form Settings
  enquiry: {
    enabled: { type: Boolean, default: true },
    title: { type: String, default: 'Have Questions? Send Us an Enquiry' },
    subtitle: { type: String, default: 'Fill out the quick form below and our team will get in touch with you via WhatsApp or Call.' },
    successMessage: { type: String, default: 'Thank you! Your enquiry has been received. Our manager will contact you shortly.' }
  },

  // Footer & Quick Links Customization
  footer: {
    enabled: { type: Boolean, default: true },
    orgName: { type: String, default: '' },
    tagline: { type: String, default: 'Premier Air-Conditioned Reading Hall & Self-Study Space.' },
    quickLinks: [{
      label: { type: String, required: true },
      url: { type: String, required: true },
      openInNewTab: { type: Boolean, default: false },
      isSystem: { type: Boolean, default: false }
    }],
    copyrightText: { type: String, default: 'Study Library Management System. All Rights Reserved.' },
    showMap: { type: Boolean, default: true },
    mapEmbedUrl: { type: String, default: '' },
    mapDirectLink: { type: String, default: '' }
  },

  // Navbar & Header Configuration
  navbar: {
    brandName: { type: String, default: '' },
    brandLogo: { type: String, default: '' },
    ctaPrimaryText: { type: String, default: 'Register Now' },
    ctaPrimaryLink: { type: String, default: '/register' },
    ctaSecondaryText: { type: String, default: 'Student Portal' },
    ctaSecondaryLink: { type: String, default: '/student-login' },
    showDarkModeToggle: { type: Boolean, default: true },
    customNavLinks: [{
      label: { type: String, required: true },
      url: { type: String, required: true }
    }]
  },

  // Floating Quick Actions Bar
  floatingActions: {
    enabled: { type: Boolean, default: true },
    whatsappNumber: { type: String, default: '' },
    whatsappMessage: { type: String, default: 'Hello! I am interested in library admission.' },
    callNumber: { type: String, default: '' }
  },

  // SEO & Social Share Metadata
  seo: {
    metaTitle: { type: String, default: 'Study Library & Reading Hall' },
    metaDescription: { type: String, default: 'Peaceful, air-conditioned study library with high-speed Wi-Fi, ergonomic seating, and 24x7 power backup.' },
    metaKeywords: { type: String, default: 'study library, reading hall, silent library, UPSC library' },
    ogImage: { type: String, default: '' }
  },

  // Theme & Branding Configuration
  theme: {
    preset: { type: String, default: 'default' },
    primaryColor: { type: String, default: '#6c5ce7' },
    accentColor: { type: String, default: '#00b894' },
    fontFamily: { type: String, default: 'Outfit, sans-serif' }
  }
}, { timestamps: true });

// Singleton Pattern
landingPageSchema.statics.getPageConfig = async function() {
  let config = await this.findOne();
  if (!config) {
    config = await this.create(this.getDefaults());
  }
  return config;
};

landingPageSchema.statics.getDefaults = function() {
  return {
    hero: {
      title: 'Premier Air-Conditioned Study Library & Reading Hall',
      subtitle: 'Peaceful, Disciplined & Distraction-Free Study Environment for UPSC, MPSC, Banking, SSC, NEET, JEE & CA Aspirants.',
      ctaPrimaryText: 'Apply for Admission / Register Now',
      ctaPrimaryLink: '/register',
      ctaSecondaryText: 'Send Quick Enquiry',
      ctaSecondaryLink: '#enquiry',
      badges: ['🔒 24x7 CCTV Surveillance', '❄️ Dual AC Reading Halls', '📶 300 Mbps High-Speed Wi-Fi', '🔋 100% Power Backup'],
      enableTicker: true,
      tickerText: '⚡ Special Discount on 3-Month & 6-Month Membership Plans! Book Your Reserved Seat Today.',
      liveSeatBadge: {
        enabled: true,
        text: 'Only 12 Seats Left'
      }
    },
    about: {
      enabled: true,
      title: 'About Our Study Library',
      subtitle: 'Why Choose Our Reading Hall?',
      description: 'We understand the discipline, intense focus, and peace required for cracking India’s toughest competitive examinations. Our study space is engineered to eliminate all distractions so you can study 12 to 16 hours every day with maximum productivity.',
      highlightPoints: [
        'Ergonomic cushioned chairs with personal reading lamps & charging sockets on every seat',
        'Individual study cubicles / cabins for complete privacy and isolation from noise',
        'Strict pin-drop silence policy enforced with round-the-clock hall supervision',
        'Separate dining and discussion area with hot water kettle, microwave & RO water'
      ],
      stats: [
        { number: '100%', label: 'Silence' },
        { number: '300 Mbps', label: 'Wi-Fi Speed' },
        { number: '180+', label: 'Selections' },
        { number: '365 Days', label: 'Open' }
      ]
    },
    facilities: {
      enabled: true,
      title: 'Premium Facilities & Amenities',
      subtitle: 'Designed with obsession for student comfort and maximum study stamina.',
      items: [
        { icon: '❄️', title: 'Central Air Conditioning', description: 'Dual inverter ACs maintaining optimal 23°C temperature all year round.' },
        { icon: '📶', title: 'Ultra High-Speed Wi-Fi', description: 'Dual fiber broadband connections (300 Mbps) with zero downtime.' },
        { icon: '💺', title: 'Ergonomic Seating', description: 'Orthopedic lumbar-support chairs with spacious individual wooden desks.' },
        { icon: '🔋', title: '100% Power Backup', description: 'Heavy-duty silent online UPS + generator backup ensures no blackout pauses.' }
      ]
    },
    shifts: {
      enabled: true,
      title: 'Flexible Study Shifts',
      subtitle: 'Choose a timing that fits your schedule.',
      items: [
        { name: 'Morning Shift', timing: '06:00 AM to 02:00 PM', description: 'Start your day early.', icon: '🌅' },
        { name: 'Evening Shift', timing: '02:00 PM to 10:00 PM', description: 'Perfect for late risers.', icon: '🌇' },
        { name: 'Full Day Shift', timing: '06:00 AM to 10:00 PM', description: 'For dedicated aspirants.', icon: '☀️' }
      ]
    },
    rules: {
      enabled: true,
      title: 'Library Code of Conduct & Rules',
      subtitle: 'Every member must respect and follow these rules to maintain high productivity standards.',
      items: [
        'Strict pin-drop silence must be maintained in the reading hall at all times.',
        'Mobile phones MUST be kept on Silent/Vibrate mode. Phone calls must only be attended outside the hall.',
        'Seats are strictly reserved for allotted members during their designated shift hours.',
        'Eating snacks or meals inside the study hall is prohibited. Please use the designated cafeteria area.',
        'Please keep your study desk clean and tidy before leaving for the day.',
        'Library management reserves the right to cancel admission in case of indiscipline or misbehavior.'
      ]
    },
    gallery: {
      enabled: true,
      title: 'Our Study Space & Ambience',
      subtitle: 'Take a virtual tour of our modern reading rooms and student facilities.',
      images: [
        { url: 'https://images.unsplash.com/photo-1521587760476-6c12a4b040da?w=800&auto=format&fit=crop&q=80', caption: 'Quiet Individual Study Cubicles', category: 'Cabins' },
        { url: 'https://images.unsplash.com/photo-1497633762265-9d179a990aa6?w=800&auto=format&fit=crop&q=80', caption: 'Reference Book Section & Clean Hall', category: 'Hall' }
      ]
    },
    faqs: {
      enabled: true,
      title: 'Frequently Asked Questions',
      subtitle: 'Find answers to common queries.',
      items: [
        { question: 'What are the library timings?', answer: 'We are open from 06:00 AM to 11:00 PM daily.' },
        { question: 'Is Wi-Fi provided?', answer: 'Yes, we provide 300 Mbps high-speed Wi-Fi.' }
      ]
    },
    testimonials: {
      enabled: true,
      title: 'Proven Track Record of Success',
      googleRating: '4.9',
      googleReviewsCount: '250+ Reviews',
      items: [
        { name: 'Aditya Deshmukh', exam: 'Cleared MPSC Rajyaseva', feedback: 'Studied here for 1.5 years. The strict silence and comfortable seating helped me maintain 14 hours of daily study stamina without back pain!', rating: 5 },
        { name: 'Priya Kulkarni', exam: 'Cleared IBPS PO Exam', feedback: 'High-speed Wi-Fi and the peaceful vibe made all the difference for my mock tests and online preparation. Highly recommended for serious aspirants.', rating: 5 }
      ]
    },
    contact: {
      enabled: true,
      phone: '+91 9876543210',
      whatsapp: '+91 9876543210',
      email: 'contact@studylibrary.com',
      address: '2nd Floor, Sai Complex, Near Metro Station, Pune, Maharashtra 411001',
      googleMapEmbedUrl: '',
      openingHours: 'Open Daily: 06:00 AM – 11:00 PM (365 Days)'
    },
    footer: {
      enabled: true,
      orgName: 'Study Library',
      tagline: 'Premier Air-Conditioned Reading Hall & Self-Study Space.',
      quickLinks: [
        { label: 'Online Admission', url: '/register', openInNewTab: false, isSystem: true },
        { label: 'Student Portal', url: '/student-login', openInNewTab: false, isSystem: true },
        { label: 'Gate Kiosk', url: '/kiosk', openInNewTab: false, isSystem: true },
        { label: 'Staff & Owner Login', url: '/#/', openInNewTab: false, isSystem: true }
      ],
      copyrightText: 'Study Library Management System. All Rights Reserved.',
      showMap: true,
      mapEmbedUrl: '',
      mapDirectLink: ''
    },
    navbar: {
      brandName: 'Study Library',
      brandLogo: '',
      ctaPrimaryText: 'Register Now',
      ctaPrimaryLink: '/register',
      ctaSecondaryText: 'Student Portal',
      ctaSecondaryLink: '/student-login',
      showDarkModeToggle: true,
      customNavLinks: []
    },
    floatingActions: {
      enabled: true,
      whatsappNumber: '+91 9876543210',
      whatsappMessage: 'Hello! I am interested in joining the study library.',
      callNumber: '+91 9876543210'
    },
    seo: {
      metaTitle: 'Study Library & Premium Reading Hall',
      metaDescription: 'Peaceful, air-conditioned study library with 300 Mbps Wi-Fi, ergonomic seating, and 24x7 power backup.',
      metaKeywords: 'study library, reading hall, silent library, UPSC study room, Pune library',
      ogImage: ''
    },
    enquiry: {
      enabled: true,
      title: 'Have Questions? Send Us a Quick Enquiry',
      subtitle: 'Leave your contact number and query below. Our manager will assist you with seat availability and fee details.',
      successMessage: 'Enquiry submitted successfully! We will call or WhatsApp you within a few minutes.'
    },
    theme: {
      preset: 'default',
      primaryColor: '#6c5ce7',
      accentColor: '#00b894',
      fontFamily: 'Outfit, sans-serif'
    }
  };
};

module.exports = mongoose.model('LandingPage', landingPageSchema);
