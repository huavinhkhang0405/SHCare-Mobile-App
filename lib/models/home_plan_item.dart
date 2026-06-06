class HomePlanItem {
  final String id;
  final String time;
  final String title;
  final String subtitle;
  final String gifAssetPath;
  final String iconName;
  final String iconColorHex;
  final bool isCompleted;

  HomePlanItem({
    required this.id,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.gifAssetPath,
    required this.iconName,
    required this.iconColorHex,
    this.isCompleted = false,
  });

  factory HomePlanItem.fromJson(Map<String, dynamic> json) {
    return HomePlanItem(
      id: json['id'] as String,
      time: json['time'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      gifAssetPath: json['gifAssetPath'] as String,
      iconName: json['iconName'] as String,
      iconColorHex: json['iconColorHex'] as String,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time,
      'title': title,
      'subtitle': subtitle,
      'gifAssetPath': gifAssetPath,
      'iconName': iconName,
      'iconColorHex': iconColorHex,
      'isCompleted': isCompleted,
    };
  }

  HomePlanItem copyWith({
    bool? isCompleted,
    String? subtitle,
  }) {
    return HomePlanItem(
      id: id,
      time: time,
      title: title,
      subtitle: subtitle ?? this.subtitle,
      gifAssetPath: gifAssetPath,
      iconName: iconName,
      iconColorHex: iconColorHex,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
