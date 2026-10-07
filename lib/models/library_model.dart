enum WaitingListMode { waitingList, noSeatsMessage, contactAdmin }

class LibraryModel {
  final String id;
  final String name;
  final String address;
  final String logoUrl;
  final String contact;
  final String email;
  final String ownerId;

  String get phone => contact;
  final int accentColor;
  final String welcomeMessage;
  final String operatingHours;
  final Map<String, String> socialLinks;
  final String rulesText;
  final String adminPhotoUrl;
  final String helplineNumber;
  final WaitingListMode waitingListMode;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Branding & membership fields (added — were in Firestore but missing from model)
  final String whatsappNumber;
  final String membershipPrefix;
  final String tagline;
  final String whatsappWelcomeTemplate;
  final String receiptFooterText;
  final String renewalReminderDays;

  LibraryModel({
    required this.id,
    required this.name,
    required this.address,
    required this.logoUrl,
    required this.contact,
    this.email = '',
    required this.ownerId,
    required this.accentColor,
    required this.welcomeMessage,
    required this.operatingHours,
    required this.socialLinks,
    required this.rulesText,
    required this.adminPhotoUrl,
    required this.helplineNumber,
    required this.waitingListMode,
    required this.createdAt,
    required this.updatedAt,
    this.whatsappNumber = '',
    this.membershipPrefix = 'CC',
    this.tagline = '',
    this.whatsappWelcomeTemplate = '',
    this.receiptFooterText = '',
    this.renewalReminderDays = '7',
  });

  factory LibraryModel.fromJson(Map<String, dynamic> json) {
    return LibraryModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      contact: json['contact'] as String? ?? json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      ownerId: json['ownerId'] as String? ?? '',
      accentColor: json['accentColor'] as int? ?? 0xFF5D4037,
      welcomeMessage: json['welcomeMessage'] as String? ?? '',
      operatingHours: json['operatingHours'] as String? ?? '',
      socialLinks: (json['socialLinks'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ?? {},
      rulesText: json['rulesText'] as String? ?? '',
      adminPhotoUrl: json['adminPhotoUrl'] as String? ?? '',
      helplineNumber: json['helplineNumber'] as String? ?? '',
      waitingListMode: _parseWaitingListMode(json['waitingListMode'] as String?),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      whatsappNumber: json['whatsappNumber'] as String? ?? '',
      membershipPrefix: json['membershipPrefix'] as String? ?? 'CC',
      tagline: json['tagline'] as String? ?? '',
      whatsappWelcomeTemplate: json['whatsappWelcomeTemplate'] as String? ?? '',
      receiptFooterText: json['receiptFooterText'] as String? ?? '',
      renewalReminderDays: json['renewalReminderDays'] as String? ?? '7',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'logoUrl': logoUrl,
      'contact': contact,
      'phone': contact,
      'email': email,
      'ownerId': ownerId,
      'accentColor': accentColor,
      'welcomeMessage': welcomeMessage,
      'operatingHours': operatingHours,
      'socialLinks': socialLinks,
      'rulesText': rulesText,
      'adminPhotoUrl': adminPhotoUrl,
      'helplineNumber': helplineNumber,
      'waitingListMode': waitingListMode.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'whatsappNumber': whatsappNumber,
      'membershipPrefix': membershipPrefix,
      'tagline': tagline,
      'whatsappWelcomeTemplate': whatsappWelcomeTemplate,
      'receiptFooterText': receiptFooterText,
      'renewalReminderDays': renewalReminderDays,
    };
  }

  LibraryModel copyWith({
    String? id,
    String? name,
    String? address,
    String? logoUrl,
    String? contact,
    String? email,
    String? ownerId,
    int? accentColor,
    String? welcomeMessage,
    String? operatingHours,
    Map<String, String>? socialLinks,
    String? rulesText,
    String? adminPhotoUrl,
    String? helplineNumber,
    WaitingListMode? waitingListMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? whatsappNumber,
    String? membershipPrefix,
    String? tagline,
    String? whatsappWelcomeTemplate,
    String? receiptFooterText,
    String? renewalReminderDays,
  }) {
    return LibraryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      logoUrl: logoUrl ?? this.logoUrl,
      contact: contact ?? this.contact,
      email: email ?? this.email,
      ownerId: ownerId ?? this.ownerId,
      accentColor: accentColor ?? this.accentColor,
      welcomeMessage: welcomeMessage ?? this.welcomeMessage,
      operatingHours: operatingHours ?? this.operatingHours,
      socialLinks: socialLinks ?? this.socialLinks,
      rulesText: rulesText ?? this.rulesText,
      adminPhotoUrl: adminPhotoUrl ?? this.adminPhotoUrl,
      helplineNumber: helplineNumber ?? this.helplineNumber,
      waitingListMode: waitingListMode ?? this.waitingListMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      membershipPrefix: membershipPrefix ?? this.membershipPrefix,
      tagline: tagline ?? this.tagline,
      whatsappWelcomeTemplate: whatsappWelcomeTemplate ?? this.whatsappWelcomeTemplate,
      receiptFooterText: receiptFooterText ?? this.receiptFooterText,
      renewalReminderDays: renewalReminderDays ?? this.renewalReminderDays,
    );
  }

  static WaitingListMode _parseWaitingListMode(String? mode) {
    switch (mode) {
      case 'noSeatsMessage':
        return WaitingListMode.noSeatsMessage;
      case 'waitingList':
        return WaitingListMode.waitingList;
      case 'contactAdmin':
      default:
        return WaitingListMode.contactAdmin;
    }
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
    // Support for Firestore Timestamp if it arrives as an object
    if (date.runtimeType.toString() == 'Timestamp') {
      try {
        return date.toDate();
      } catch (_) {}
    }
    return DateTime.now();
  }
}
