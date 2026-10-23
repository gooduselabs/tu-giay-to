import 'dart:convert';

/// Loại giấy tờ được hỗ trợ.
enum DocType {
  cccd,
  driverLicense,
  vehicleReg,
  inspection,
  vehicleInsurance,
  passport,
  warranty,
  bhyt,
  other,
}

enum ProfileKind { person, car, motorbike, house, device, other }

enum AttachmentKind { image, pdf }

class Profile {
  final String id;
  String name;
  ProfileKind kind;
  String subtitle; // quan hệ / biển số / địa chỉ / model
  DateTime? birthDate; // chỉ dùng cho người (mốc đổi CCCD)
  int colorIndex;
  bool isSample;

  Profile({
    required this.id,
    required this.name,
    this.kind = ProfileKind.person,
    this.subtitle = '',
    this.birthDate,
    this.colorIndex = 0,
    this.isSample = false,
  });

  bool get isPerson => kind == ProfileKind.person;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'subtitle': subtitle,
        'birthDate': birthDate?.toIso8601String(),
        'colorIndex': colorIndex,
        'isSample': isSample,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'],
        name: j['name'] ?? '',
        kind: ProfileKind.values.firstWhere((k) => k.name == j['kind'],
            orElse: () => ProfileKind.other),
        subtitle: j['subtitle'] ?? '',
        birthDate: _d(j['birthDate']),
        colorIndex: j['colorIndex'] ?? 0,
        isSample: j['isSample'] ?? false,
      );
}

class Attachment {
  final String id;
  AttachmentKind kind;
  String label; // "Mặt trước", "Mặt sau", tên file PDF...
  String fileName; // tên file đã mã hoá trong thư mục vault

  Attachment(
      {required this.id,
      required this.kind,
      required this.label,
      required this.fileName});

  Map<String, dynamic> toJson() =>
      {'id': id, 'kind': kind.name, 'label': label, 'fileName': fileName};

  factory Attachment.fromJson(Map<String, dynamic> j) => Attachment(
        id: j['id'],
        kind: j['kind'] == 'pdf' ? AttachmentKind.pdf : AttachmentKind.image,
        label: j['label'] ?? '',
        fileName: j['fileName'],
      );
}

class Document {
  final String id;
  String profileId;
  DocType type;
  String title;
  String number;
  String holderName;
  DateTime? issueDate;
  DateTime? expiryDate;
  List<int> reminderDays;
  String notes;
  List<Attachment> attachments;
  bool isSample;
  DateTime createdAt;

  Document({
    required this.id,
    required this.profileId,
    required this.type,
    this.title = '',
    this.number = '',
    this.holderName = '',
    this.issueDate,
    this.expiryDate,
    List<int>? reminderDays,
    this.notes = '',
    List<Attachment>? attachments,
    this.isSample = false,
    DateTime? createdAt,
  })  : reminderDays = reminderDays ?? List.of(type.defaultReminderDays),
        attachments = attachments ?? [],
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'type': type.name,
        'title': title,
        'number': number,
        'holderName': holderName,
        'issueDate': issueDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'reminderDays': reminderDays,
        'notes': notes,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'isSample': isSample,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Document.fromJson(Map<String, dynamic> j) {
    final type = DocType.values.firstWhere((t) => t.name == j['type'],
        orElse: () => DocType.other);
    return Document(
      id: j['id'],
      profileId: j['profileId'] ?? '',
      type: type,
      title: j['title'] ?? '',
      number: j['number'] ?? '',
      holderName: j['holderName'] ?? '',
      issueDate: _d(j['issueDate']),
      expiryDate: _d(j['expiryDate']),
      reminderDays: (j['reminderDays'] as List?)?.cast<int>(),
      notes: j['notes'] ?? '',
      attachments: ((j['attachments'] as List?) ?? [])
          .map((a) => Attachment.fromJson(Map<String, dynamic>.from(a)))
          .toList(),
      isSample: j['isSample'] ?? false,
      createdAt: _d(j['createdAt']),
    );
  }

  String encode() => jsonEncode(toJson());
}

DateTime? _d(dynamic v) =>
    v == null || v == '' ? null : DateTime.tryParse(v.toString());

extension DocTypeX on DocType {
  /// Số ngày nhắc trước mặc định theo loại.
  List<int> get defaultReminderDays => switch (this) {
        DocType.inspection => [30, 7],
        DocType.passport => [180, 30],
        DocType.cccd => [90, 30],
        DocType.driverLicense => [60, 14],
        DocType.vehicleInsurance => [30, 7],
        DocType.warranty => [30, 7],
        DocType.bhyt => [30, 7],
        DocType.vehicleReg => [30],
        DocType.other => [30, 7],
      };

  /// Loại tài sản/hồ sơ phù hợp nhất.
  bool get belongsToVehicle => const {
        DocType.vehicleReg,
        DocType.inspection,
        DocType.vehicleInsurance
      }.contains(this);
}
