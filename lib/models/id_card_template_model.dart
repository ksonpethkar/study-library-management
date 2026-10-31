class IdCardTemplateSettings {
  final bool showPhoto;
  final bool showQrCode;
  final bool showSeat;
  final bool showPlan;
  final bool showValidTill;
  final bool showFatherName;
  final bool showEmergencyContact;
  final bool showBloodGroup;
  final bool showAddress;
  final bool showHelpline;
  final bool showRules;
  final bool showBarcode;
  final String customRulesText;
  final String cardTheme; // 'amberClassic', 'royalNavy', 'emeraldAcademic', 'crimsonExecutive', 'darkSlate', 'amethystPurple', 'customBrand'
  final String? customColorHex; // Hex string e.g. '#881337' or '881337'
  final String templateStyle; // 'modernExecutive', 'minimalAcademic', 'classicInstitutional', 'techShield'
  final bool showStamp;
  final bool showSignature;
  final String signatureTitle;
  final String? stampUrl;
  final String? signatureUrl;
  final String backgroundStyle; // 'gradientMesh', 'cleanWhite'

  const IdCardTemplateSettings({
    this.showPhoto = true,
    this.showQrCode = true,
    this.showSeat = true,
    this.showPlan = true,
    this.showValidTill = true,
    this.showFatherName = true,
    this.showEmergencyContact = true,
    this.showBloodGroup = true,
    this.showAddress = true,
    this.showHelpline = true,
    this.showRules = true,
    this.showBarcode = false,
    this.customRulesText = '',
    this.cardTheme = 'royalNavy',
    this.customColorHex,
    this.templateStyle = 'modernExecutive',
    this.showStamp = true,
    this.showSignature = true,
    this.signatureTitle = 'Authorized Signatory',
    this.stampUrl,
    this.signatureUrl,
    this.backgroundStyle = 'gradientMesh',
  });

  factory IdCardTemplateSettings.fromJson(Map<String, dynamic> json) {
    return IdCardTemplateSettings(
      showPhoto: json['showPhoto'] as bool? ?? true,
      showQrCode: json['showQrCode'] as bool? ?? true,
      showSeat: json['showSeat'] as bool? ?? true,
      showPlan: json['showPlan'] as bool? ?? true,
      showValidTill: json['showValidTill'] as bool? ?? true,
      showFatherName: json['showFatherName'] as bool? ?? true,
      showEmergencyContact: json['showEmergencyContact'] as bool? ?? true,
      showBloodGroup: json['showBloodGroup'] as bool? ?? true,
      showAddress: json['showAddress'] as bool? ?? true,
      showHelpline: json['showHelpline'] as bool? ?? true,
      showRules: json['showRules'] as bool? ?? true,
      showBarcode: json['showBarcode'] as bool? ?? false,
      customRulesText: json['customRulesText'] as String? ?? '',
      cardTheme: json['cardTheme'] as String? ?? 'royalNavy',
      customColorHex: json['customColorHex'] as String?,
      templateStyle: json['templateStyle'] as String? ?? 'modernExecutive',
      showStamp: json['showStamp'] as bool? ?? true,
      showSignature: json['showSignature'] as bool? ?? true,
      signatureTitle: json['signatureTitle'] as String? ?? 'Authorized Signatory',
      stampUrl: json['stampUrl'] as String?,
      signatureUrl: json['signatureUrl'] as String?,
      backgroundStyle: json['backgroundStyle'] as String? ?? 'gradientMesh',
    );
  }

  Map<String, dynamic> toJson() => {
        'showPhoto': showPhoto,
        'showQrCode': showQrCode,
        'showSeat': showSeat,
        'showPlan': showPlan,
        'showValidTill': showValidTill,
        'showFatherName': showFatherName,
        'showEmergencyContact': showEmergencyContact,
        'showBloodGroup': showBloodGroup,
        'showAddress': showAddress,
        'showHelpline': showHelpline,
        'showRules': showRules,
        'showBarcode': showBarcode,
        'customRulesText': customRulesText,
        'cardTheme': cardTheme,
        if (customColorHex != null) 'customColorHex': customColorHex,
        'templateStyle': templateStyle,
        'showStamp': showStamp,
        'showSignature': showSignature,
        'signatureTitle': signatureTitle,
        if (stampUrl != null) 'stampUrl': stampUrl,
        if (signatureUrl != null) 'signatureUrl': signatureUrl,
        'backgroundStyle': backgroundStyle,
      };

  IdCardTemplateSettings copyWith({
    bool? showPhoto,
    bool? showQrCode,
    bool? showSeat,
    bool? showPlan,
    bool? showValidTill,
    bool? showFatherName,
    bool? showEmergencyContact,
    bool? showBloodGroup,
    bool? showAddress,
    bool? showHelpline,
    bool? showRules,
    bool? showBarcode,
    String? customRulesText,
    String? cardTheme,
    String? customColorHex,
    String? templateStyle,
    bool? showStamp,
    bool? showSignature,
    String? signatureTitle,
    String? stampUrl,
    String? signatureUrl,
    String? backgroundStyle,
  }) {
    return IdCardTemplateSettings(
      showPhoto: showPhoto ?? this.showPhoto,
      showQrCode: showQrCode ?? this.showQrCode,
      showSeat: showSeat ?? this.showSeat,
      showPlan: showPlan ?? this.showPlan,
      showValidTill: showValidTill ?? this.showValidTill,
      showFatherName: showFatherName ?? this.showFatherName,
      showEmergencyContact: showEmergencyContact ?? this.showEmergencyContact,
      showBloodGroup: showBloodGroup ?? this.showBloodGroup,
      showAddress: showAddress ?? this.showAddress,
      showHelpline: showHelpline ?? this.showHelpline,
      showRules: showRules ?? this.showRules,
      showBarcode: showBarcode ?? this.showBarcode,
      customRulesText: customRulesText ?? this.customRulesText,
      cardTheme: cardTheme ?? this.cardTheme,
      customColorHex: customColorHex ?? this.customColorHex,
      templateStyle: templateStyle ?? this.templateStyle,
      showStamp: showStamp ?? this.showStamp,
      showSignature: showSignature ?? this.showSignature,
      signatureTitle: signatureTitle ?? this.signatureTitle,
      stampUrl: stampUrl ?? this.stampUrl,
      signatureUrl: signatureUrl ?? this.signatureUrl,
      backgroundStyle: backgroundStyle ?? this.backgroundStyle,
    );
  }
}
