/// A child profile record.
class Child {
  const Child({
    required this.id,
    required this.nickname,
    required this.ageBand,
    this.birthMonthYear,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String nickname;
  final String ageBand;
  final String? birthMonthYear;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Child.fromJson(Map<String, dynamic> json) {
    return Child(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      ageBand: json['ageBand'] as String,
      birthMonthYear: json['birthMonthYear'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'ageBand': ageBand,
      if (birthMonthYear != null) 'birthMonthYear': birthMonthYear,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
