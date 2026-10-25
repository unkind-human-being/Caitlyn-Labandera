class LaundryOrder {
  final String id;
  final String fullName;
  final String phoneNumber;
  final String category;
  final double weightKg;
  final double pricePerKg;
  final DateTime registeredAt;
  final DateTime claimDate;
  final Map<String, int> itemQuantities;
  final String notes;
  final bool smsOptIn;
  final bool claimed;

  const LaundryOrder({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.category,
    required this.weightKg,
    required this.pricePerKg,
    required this.registeredAt,
    required this.claimDate,
    required this.itemQuantities,
    required this.notes,
    this.smsOptIn = false,
    this.claimed = false,
  });

  LaundryOrder copyWith({bool? smsOptIn, bool? claimed}) => LaundryOrder(
    id: id, fullName: fullName, phoneNumber: phoneNumber,
    category: category, weightKg: weightKg, pricePerKg: pricePerKg,
    registeredAt: registeredAt, claimDate: claimDate,
    itemQuantities: Map<String, int>.from(itemQuantities),
    notes: notes, smsOptIn: smsOptIn ?? this.smsOptIn,
    claimed: claimed ?? this.claimed,
  );

  /// Order total is kept to centavo precision. Stored rate is a snapshot of
  /// the price when this order was registered.
  double get total => (weightKg * pricePerKg * 100).round() / 100;

  String get receiptId => '#${id.length > 8 ? id.substring(id.length - 8) : id}';

  String get itemSummary {
    final parts = itemQuantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => '${entry.key} ×${entry.value}')
        .toList();
    return parts.isEmpty ? 'Not specified' : parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'category': category,
        'weightKg': weightKg,
        'pricePerKg': pricePerKg,
        'registeredAt': registeredAt.toIso8601String(),
        'claimDate': claimDate.toIso8601String(),
        'itemQuantities': itemQuantities,
        'notes': notes,
        'smsOptIn': smsOptIn,
        'claimed': claimed,
      };

  factory LaundryOrder.fromMap(Map<dynamic, dynamic> source) {
    final map = Map<String, dynamic>.from(source);
    final quantities = <String, int>{};
    final rawItems = map['itemQuantities'];
    if (rawItems is Map) {
      for (final entry in rawItems.entries) {
        quantities[entry.key.toString()] =
            (entry.value as num?)?.toInt() ?? 0;
      }
    }
    return LaundryOrder(
      id: map['id'] as String,
      fullName: map['fullName'] as String,
      phoneNumber: map['phoneNumber'] as String,
      category: map['category'] as String,
      weightKg: (map['weightKg'] as num).toDouble(),
      pricePerKg: (map['pricePerKg'] as num).toDouble(),
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      claimDate: DateTime.parse(map['claimDate'] as String),
      itemQuantities: quantities,
      notes: (map['notes'] as String?) ?? '',
      smsOptIn: map['smsOptIn'] == true,
      claimed: map['claimed'] == true,
    );
  }
}
