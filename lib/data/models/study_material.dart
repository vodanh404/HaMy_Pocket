class StudyMaterial {
  const StudyMaterial({
    required this.id,
    required this.title,
    required this.fileName,
    required this.type,
    required this.category,
    required this.level,
    this.source,
    this.localPath,
  });

  final String id;
  final String title;
  final String fileName;
  final String type;
  final String category;
  final int? level;
  final String? source;
  final String? localPath;

  bool get isDownloaded => id.startsWith('downloaded:');
  bool get isImported => localPath != null && !isDownloaded;
  bool get isBundledAudio => type == 'audio' && source != null;
  bool get isBundledPdf => type == 'pdf' && source != null;
  bool get isAvailable =>
      isDownloaded || isImported || isBundledAudio || isBundledPdf;

  factory StudyMaterial.fromJson(Map<String, dynamic> json) {
    final levelValue = json['level'];
    return StudyMaterial(
      id: json['id'] as String,
      title: json['title'] as String,
      fileName: json['file_name'] as String,
      type: json['type'] as String,
      category: json['category'] as String,
      level: levelValue is int ? levelValue : null,
      source: json['source'] as String?,
      localPath: json['local_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'file_name': fileName,
    'type': type,
    'category': category,
    'level': level,
    if (source != null) 'source': source,
    if (localPath != null) 'local_path': localPath,
  };

  StudyMaterial copyWith({String? localPath}) => StudyMaterial(
    id: id,
    title: title,
    fileName: fileName,
    type: type,
    category: category,
    level: level,
    source: source,
    localPath: localPath ?? this.localPath,
  );
}
