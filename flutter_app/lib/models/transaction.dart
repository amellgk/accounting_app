class Transaction {
  final String id;
  final String userId;
  final String categoryId;
  final String type; // 'income' or 'expense'
  final double amount;
  final String note;
  final DateTime transactionDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int syncVersion;
  // 关联数据
  String? categoryName;
  String? categoryIcon;

  Transaction({
    required this.id,
    required this.userId,
    required this.categoryId,
    required this.type,
    required this.amount,
    this.note = '',
    required this.transactionDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncVersion = 1,
    this.categoryName,
    this.categoryIcon,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      categoryId: json['categoryId'] ?? '',
      type: json['type'] ?? 'expense',
      amount: (json['amount'] ?? 0).toDouble(),
      note: json['note'] ?? '',
      transactionDate: DateTime.parse(json['transactionDate'] ?? DateTime.now().toIso8601String()),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      syncVersion: json['syncVersion'] ?? 1,
      categoryName: json['category']?['name'],
      categoryIcon: json['category']?['icon'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'categoryId': categoryId,
        'type': type,
        'amount': amount,
        'note': note,
        'transactionDate': transactionDate.toIso8601String(),
        'syncVersion': syncVersion,
      };

  String get typeLabel => type == 'income' ? '收入' : '支出';

  String get formattedAmount {
    final prefix = type == 'income' ? '+' : '-';
    return '$prefix¥${amount.toStringAsFixed(2)}';
  }
}
