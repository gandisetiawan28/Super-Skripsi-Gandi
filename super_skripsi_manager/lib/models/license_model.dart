class LicenseModel {
  final String userName;
  final String deviceId;
  final String key;
  final String status;
  final DateTime expiryDate;
  final DateTime? lastValidated;

  LicenseModel({
    required this.userName,
    required this.deviceId,
    required this.key,
    required this.status,
    required this.expiryDate,
    this.lastValidated,
  });

  bool get isActive =>
      status.toLowerCase() == 'aktif' &&
      expiryDate.isAfter(DateTime.now());

  Map<String, dynamic> toJson() => {
        'userName': userName,
        'deviceId': deviceId,
        'key': key,
        'status': status,
        'expiryDate': expiryDate.toIso8601String(),
        'lastValidated': lastValidated?.toIso8601String(),
      };

  factory LicenseModel.fromJson(Map<String, dynamic> json) => LicenseModel(
        userName: json['userName'] as String,
        deviceId: json['deviceId'] as String,
        key: json['key'] as String,
        status: json['status'] as String,
        expiryDate: DateTime.parse(json['expiryDate'] as String),
        lastValidated: json['lastValidated'] != null
            ? DateTime.parse(json['lastValidated'] as String)
            : null,
      );
}
