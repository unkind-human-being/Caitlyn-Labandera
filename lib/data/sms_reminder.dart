/// Local history of reminder sending. Backward compatible with the V2 manual
/// SMS composer records; Android radio status is a separate source of truth.
class SmsReminder {
  final String orderId;
  final DateTime preparedAt;
  final DateTime? confirmedSentAt;
  final String lastMessage;
  final String? nativeStatus;
  final String nativeDetail;
  final DateTime? nativeUpdatedAt;

  const SmsReminder({
    required this.orderId,
    required this.preparedAt,
    required this.confirmedSentAt,
    required this.lastMessage,
    this.nativeStatus,
    this.nativeDetail = '',
    this.nativeUpdatedAt,
  });

  bool get wasSent => confirmedSentAt != null ||
      nativeStatus == 'sent' || nativeStatus == 'delivered';

  bool get attempted => wasSent || nativeStatus == 'queued' ||
      nativeStatus == 'failed';

  String get status {
    switch (nativeStatus) {
      case 'scheduled': return 'Scheduled (Android)';
      case 'queued': return 'Sending - awaiting network result';
      case 'sent': return 'Sent to mobile network';
      case 'delivered': return 'Delivery reported by carrier';
      case 'failed': return 'SMS failed';
      case 'cancelled': return 'Schedule cancelled';
    }
    return confirmedSentAt != null
        ? 'Marked sent (manual - older version)'
        : 'Prepared in SMS app (older version)';
  }

  SmsReminder withNative(Map<String, dynamic> raw) => SmsReminder(
        orderId: orderId,
        preparedAt: preparedAt,
        confirmedSentAt: confirmedSentAt,
        lastMessage: lastMessage,
        nativeStatus: raw['status']?.toString(),
        nativeDetail: raw['detail']?.toString() ?? '',
        nativeUpdatedAt: DateTime.fromMillisecondsSinceEpoch(
          (raw['whenMs'] as num?)?.toInt() ?? 0,
        ),
      );

  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'preparedAt': preparedAt.toIso8601String(),
        'confirmedSentAt': confirmedSentAt?.toIso8601String(),
        'lastMessage': lastMessage,
        'nativeStatus': nativeStatus,
        'nativeDetail': nativeDetail,
        'nativeUpdatedAt': nativeUpdatedAt?.toIso8601String(),
      };

  factory SmsReminder.fromMap(Map<dynamic, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    return SmsReminder(
      orderId: map['orderId'] as String,
      preparedAt: DateTime.parse(map['preparedAt'] as String),
      confirmedSentAt: map['confirmedSentAt'] == null
          ? null : DateTime.parse(map['confirmedSentAt'] as String),
      lastMessage: (map['lastMessage'] as String?) ?? '',
      nativeStatus: map['nativeStatus'] as String?,
      nativeDetail: (map['nativeDetail'] as String?) ?? '',
      nativeUpdatedAt: map['nativeUpdatedAt'] == null
          ? null : DateTime.tryParse(map['nativeUpdatedAt'] as String),
    );
  }
}
