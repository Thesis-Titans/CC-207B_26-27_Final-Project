/// An activity in the learning catalog.
class Activity {
  const Activity({
    required this.id,
    required this.title,
    required this.type,
    required this.language,
    required this.domain,
    required this.ageBand,
    required this.durationMinutes,
    required this.durationEstimate,
    required this.setting,
    required this.materials,
    required this.instructions,
    required this.limitations,
    required this.status,
    required this.provenanceSource,
  });

  final String id;
  final String title;
  final String type;

  /// One of `en`, `fil` or `hil`.
  final String language;
  final String domain;
  final String ageBand;
  final int durationMinutes;
  final String durationEstimate;
  final String setting;
  final List<String> materials;
  final List<String> instructions;
  final String limitations;

  /// Review status: `reviewed_approved`, `synthetic_fixture` or `draft`.
  final String status;
  final String provenanceSource;

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      title: json['title'] as String,
      type: json['type'] as String,
      language: json['language'] as String,
      domain: json['domain'] as String,
      ageBand: json['ageBand'] as String,
      durationMinutes: json['durationMinutes'] as int,
      durationEstimate: json['durationEstimate'] as String,
      setting: json['setting'] as String,
      materials: (json['materials'] as List<dynamic>).cast<String>(),
      instructions: (json['instructions'] as List<dynamic>).cast<String>(),
      limitations: json['limitations'] as String,
      status: json['status'] as String,
      provenanceSource: json['provenanceSource'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'language': language,
      'domain': domain,
      'ageBand': ageBand,
      'durationMinutes': durationMinutes,
      'durationEstimate': durationEstimate,
      'setting': setting,
      'materials': materials,
      'instructions': instructions,
      'limitations': limitations,
      'status': status,
      'provenanceSource': provenanceSource,
    };
  }
}
