import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:study_library/services/message_template_service.dart';

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
  String get effectiveContact => contact.isNotEmpty ? contact : phone;
  String get effectiveHelpline => effectiveContact;
  final int accentColor;
  final String welcomeMessage;
  final String operatingHours;
  final Map<String, String> socialLinks;
  final String rulesText;
  final String adminPhotoUrl;
  final String helplineNumber;
  final WaitingListMode waitingListMode;
  final int waitingListHoldingHours;
  final bool waitingListAutoNotify;
  final String waitingListNotificationTemplate;
  final DateTime createdAt;
  final DateTime updatedAt;
  // Branding & membership fields (added — were in Firestore but missing from model)
  final String whatsappNumber;
  final String membershipPrefix;
  final String tagline;
  final String whatsappWelcomeTemplate;
  final String whatsappReceiptTemplate;
  final String whatsappDueReminderTemplate;
  final String whatsappExpiryReminderTemplate;
  final String templateLanguage;
  final String receiptFooterText;
  final int renewalReminderDays;
  final String upiId;
  final String adminName;
  final List<String> facilities;
  final String ownerName;
  final String ownerContact;
  final String managerName;
  final String managerContact;
  final String adminContact;
  final String googleMapsUrl;
  final String wifiSsid;
  final String wifiPassword;

  String get effectiveWifiSsid =>
      wifiSsid.trim().isNotEmpty ? wifiSsid.trim() : '${name.trim().isNotEmpty ? name.trim() : "Cozy Corner"} 5G';
  String get effectiveWifiPassword =>
      wifiPassword.trim().isNotEmpty ? wifiPassword.trim() : 'Study@Cozy2026';

  String get effectiveWelcomeTemplate =>
      whatsappWelcomeTemplate.trim().isNotEmpty
          ? whatsappWelcomeTemplate.trim()
          : MessageTemplateService.getTemplate(type: 'welcome', language: templateLanguage);

  String get effectiveReceiptTemplate =>
      whatsappReceiptTemplate.trim().isNotEmpty
          ? whatsappReceiptTemplate.trim()
          : MessageTemplateService.getTemplate(type: 'receipt', language: templateLanguage);

  String get effectiveDueReminderTemplate =>
      whatsappDueReminderTemplate.trim().isNotEmpty
          ? whatsappDueReminderTemplate.trim()
          : MessageTemplateService.getTemplate(type: 'dueReminder', language: templateLanguage);

  String get effectiveExpiryReminderTemplate =>
      whatsappExpiryReminderTemplate.trim().isNotEmpty
          ? whatsappExpiryReminderTemplate.trim()
          : MessageTemplateService.getTemplate(type: 'expiryReminder', language: templateLanguage);

  String get effectiveWaitlistTemplate =>
      waitingListNotificationTemplate.trim().isNotEmpty
          ? waitingListNotificationTemplate.trim()
          : MessageTemplateService.getTemplate(type: 'waitlistOffer', language: templateLanguage);

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
    this.waitingListHoldingHours = 24,
    this.waitingListAutoNotify = true,
    this.waitingListNotificationTemplate = '',
    required this.createdAt,
    required this.updatedAt,
    this.whatsappNumber = '',
    this.membershipPrefix = 'CC',
    this.tagline = '',
    this.whatsappWelcomeTemplate = '',
    this.whatsappReceiptTemplate = '',
    this.whatsappDueReminderTemplate = '',
    this.whatsappExpiryReminderTemplate = '',
    this.templateLanguage = 'en',
    this.receiptFooterText = '',
    this.renewalReminderDays = 7,
    this.upiId = '',
    this.adminName = '',
    this.facilities = const [
      'High-Speed Wi-Fi',
      'Power Sockets at Desk',
      'Purified RO Water',
      'Silent Study Zone',
      'CCTV Surveillance',
      'Ergonomic Chairs',
    ],
    this.ownerName = '',
    this.ownerContact = '',
    this.managerName = '',
    this.managerContact = '',
    this.adminContact = '',
    this.googleMapsUrl = '',
    this.wifiSsid = '',
    this.wifiPassword = '',
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
      waitingListHoldingHours: json['waitingListHoldingHours'] as int? ?? 24,
      waitingListAutoNotify: json['waitingListAutoNotify'] as bool? ?? true,
      waitingListNotificationTemplate: json['waitingListNotificationTemplate'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      whatsappNumber: json['whatsappNumber'] as String? ?? '',
      membershipPrefix: json['membershipPrefix'] as String? ?? 'CC',
      tagline: json['tagline'] as String? ?? '',
      whatsappWelcomeTemplate: json['whatsappWelcomeTemplate'] as String? ?? '',
      receiptFooterText: json['receiptFooterText'] as String? ?? '',
      renewalReminderDays: (json['renewalReminderDays'] is int
          ? json['renewalReminderDays'] as int
          : int.tryParse(json['renewalReminderDays']?.toString() ?? '7') ?? 7),
      upiId: json['upiId'] as String? ?? '',
      adminName: json['adminName'] as String? ?? json['ownerName'] as String? ?? json['contactPerson'] as String? ?? '',
      facilities: (json['facilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          const [
            'High-Speed Wi-Fi',
            'Power Sockets at Desk',
            'Purified RO Water',
            'Silent Study Zone',
            'CCTV Surveillance',
            'Ergonomic Chairs',
          ],
      ownerName: json['ownerName'] as String? ?? '',
      ownerContact: json['ownerContact'] as String? ?? '',
      managerName: json['managerName'] as String? ?? '',
      managerContact: json['managerContact'] as String? ?? '',
      adminContact: json['adminContact'] as String? ?? '',
      googleMapsUrl: json['googleMapsUrl'] as String? ?? json['mapsUrl'] as String? ?? (json['socialLinks'] is Map ? (json['socialLinks']['maps'] as String? ?? '') : ''),
      wifiSsid: json['wifiSsid'] as String? ?? json['wifiName'] as String? ?? '',
      wifiPassword: json['wifiPassword'] as String? ?? json['wifiPass'] as String? ?? '',
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
      'waitingListHoldingHours': waitingListHoldingHours,
      'waitingListAutoNotify': waitingListAutoNotify,
      'waitingListNotificationTemplate': waitingListNotificationTemplate,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'whatsappNumber': whatsappNumber,
      'membershipPrefix': membershipPrefix,
      'tagline': tagline,
      'whatsappWelcomeTemplate': whatsappWelcomeTemplate,
      'receiptFooterText': receiptFooterText,
      'renewalReminderDays': renewalReminderDays,
      'upiId': upiId,
      'adminName': adminName,
      'facilities': facilities,
      'ownerName': ownerName,
      'ownerContact': ownerContact,
      'managerName': managerName,
      'managerContact': managerContact,
      'adminContact': adminContact,
      'googleMapsUrl': googleMapsUrl,
      'wifiSsid': wifiSsid,
      'wifiPassword': wifiPassword,
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
    int? waitingListHoldingHours,
    bool? waitingListAutoNotify,
    String? waitingListNotificationTemplate,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? whatsappNumber,
    String? membershipPrefix,
    String? tagline,
    String? whatsappWelcomeTemplate,
    String? receiptFooterText,
    int? renewalReminderDays,
    String? upiId,
    String? adminName,
    List<String>? facilities,
    String? ownerName,
    String? ownerContact,
    String? managerName,
    String? managerContact,
    String? adminContact,
    String? googleMapsUrl,
    String? wifiSsid,
    String? wifiPassword,
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
      waitingListHoldingHours: waitingListHoldingHours ?? this.waitingListHoldingHours,
      waitingListAutoNotify: waitingListAutoNotify ?? this.waitingListAutoNotify,
      waitingListNotificationTemplate: waitingListNotificationTemplate ?? this.waitingListNotificationTemplate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      membershipPrefix: membershipPrefix ?? this.membershipPrefix,
      tagline: tagline ?? this.tagline,
      whatsappWelcomeTemplate: whatsappWelcomeTemplate ?? this.whatsappWelcomeTemplate,
      receiptFooterText: receiptFooterText ?? this.receiptFooterText,
      renewalReminderDays: renewalReminderDays ?? this.renewalReminderDays,
      upiId: upiId ?? this.upiId,
      adminName: adminName ?? this.adminName,
      facilities: facilities ?? this.facilities,
      ownerName: ownerName ?? this.ownerName,
      ownerContact: ownerContact ?? this.ownerContact,
      managerName: managerName ?? this.managerName,
      managerContact: managerContact ?? this.managerContact,
      adminContact: adminContact ?? this.adminContact,
      googleMapsUrl: googleMapsUrl ?? this.googleMapsUrl,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
    );
  }

  /// Whether the library is configured with Air Conditioning (AC).
  bool get hasAirConditioning =>
      facilities.any((f) => f.toLowerCase() == 'ac' || f.toLowerCase().contains('air condition') || f.toLowerCase().contains('ac •'));

  /// Returns structured list of all populated key personnel with role, name and phone.
  List<Map<String, String>> get populatedPersonnel {
    final list = <Map<String, String>>[];
    final fallbackPhone = contact.isNotEmpty ? contact : phone;

    final hasSeparateFields = ownerName.trim().isNotEmpty || managerName.trim().isNotEmpty;
    if (hasSeparateFields) {
      if (ownerName.trim().isNotEmpty) {
        list.add({
          'role': 'Owner',
          'name': ownerName.trim(),
          'contact': ownerContact.trim().isNotEmpty ? ownerContact.trim() : fallbackPhone,
        });
      }
      if (adminName.trim().isNotEmpty) {
        final isSameAsOwner = list.isNotEmpty && list.first['name'] == adminName.trim();
        if (!isSameAsOwner) {
          list.add({
            'role': 'Admin',
            'name': adminName.trim(),
            'contact': adminContact.trim().isNotEmpty ? adminContact.trim() : fallbackPhone,
          });
        }
      }
      if (managerName.trim().isNotEmpty) {
        final isSameAsExisting = list.any((p) => p['name'] == managerName.trim());
        if (!isSameAsExisting) {
          list.add({
            'role': 'Manager',
            'name': managerName.trim(),
            'contact': managerContact.trim().isNotEmpty ? managerContact.trim() : fallbackPhone,
          });
        }
      }
    } else if (adminName.trim().isNotEmpty) {
      // Backwards compatibility: Single field in Library Profile ("Admin / Owner / Manager Name")
      list.add({
        'role': 'Admin / Owner / Manager',
        'name': adminName.trim(),
        'contact': adminContact.trim().isNotEmpty ? adminContact.trim() : fallbackPhone,
      });
    }

    return list;
  }

  static WaitingListMode _parseWaitingListMode(String? mode) {
    switch (mode) {
      case 'noSeatsMessage':
      case 'no_seats':
        return WaitingListMode.noSeatsMessage;
      case 'waitingList':
      case 'waiting_list':
        return WaitingListMode.waitingList;
      case 'contactAdmin':
      case 'contact_admin':
      default:
        return WaitingListMode.contactAdmin;
    }
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    if (date is DateTime) return date;
    if (date is Timestamp) return date.toDate();
    if (date is int) return DateTime.fromMillisecondsSinceEpoch(date);
    if (date is String) return DateTime.tryParse(date) ?? DateTime.now();
    try {
      return (date as dynamic).toDate();
    } catch (_) { /* intentionally silent */ }
    return DateTime.now();
  }
}
