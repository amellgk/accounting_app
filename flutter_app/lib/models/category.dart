class Category {
  final String id;
  final String? userId;
  final String name;
  final String icon;
  final String type; // 'income' or 'expense'
  final int sortOrder;

  Category({
    required this.id,
    this.userId,
    required this.name,
    this.icon = '📦',
    required this.type,
    this.sortOrder = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? '',
      userId: json['userId'],
      name: json['name'] ?? '',
      icon: json['icon'] ?? '📦',
      type: json['type'] ?? 'expense',
      sortOrder: json['sortOrder'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'type': type,
      };
}
