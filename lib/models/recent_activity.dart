class RecentActivity {
  final String id;
  final String title;
  final String subtitle;
  final String trailing;
  final String gifAssetPath;
  final String iconName;
  final DateTime timestamp;

  RecentActivity({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.gifAssetPath,
    required this.iconName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      trailing: json['trailing'] as String,
      gifAssetPath: json['gifAssetPath'] as String,
      iconName: json['iconName'] as String,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'trailing': trailing,
      'gifAssetPath': gifAssetPath,
      'iconName': iconName,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
