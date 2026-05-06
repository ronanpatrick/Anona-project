class Article {
  const Article({
    required this.title,
    required this.sources,
    required this.urls,
    required this.summary,
    this.imageUrl,
  });

  final String title;
  final List<String> sources;
  final List<String> urls;
  final String summary;
  final String? imageUrl;

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      title: json['title'] as String? ?? '',
      sources: _parseStringList(json['sources'] ?? json['source']),
      urls: _parseStringList(json['urls'] ?? json['url']),
      summary: json['summary'] as String? ?? '',
      imageUrl: _parseOptionalString(json['image_url'] ?? json['imageUrl']),
    );
  }

  static String? _parseOptionalString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? <String>[] : <String>[trimmed];
    }

    if (value is Map<String, dynamic>) {
      final name = (value['name'] as String? ?? '').trim();
      return name.isEmpty ? <String>[] : <String>[name];
    }

    if (value is List) {
      final values = <String>[];
      for (final item in value) {
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) {
            values.add(trimmed);
          }
        } else if (item is Map<String, dynamic>) {
          final name = (item['name'] as String? ?? '').trim();
          if (name.isNotEmpty) {
            values.add(name);
          }
        }
      }
      return values;
    }

    return <String>[];
  }
}
