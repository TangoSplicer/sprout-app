// flutter/lib/models/project.dart
class SproutProject {
  final String name;
  final String path;
  final DateTime createdAt;
  final DateTime lastModified;
  final List<String> files;

  SproutProject({
    required this.name,
    required this.path,
    DateTime? createdAt,
    DateTime? lastModified,
    List<String>? files,
  })  : createdAt = createdAt ?? DateTime.now(),
        lastModified = lastModified ?? DateTime.now(),
        files = files ?? ['main.sprout'];

  factory SproutProject.blank(String name) {
    final now = DateTime.now();
    return SproutProject(
      name: name,
      path: '/data/sprout/$name-${now.millisecondsSinceEpoch}',
      createdAt: now,
      lastModified: now,
    );
  }

  @override
  String toString() => 'SproutProject($name)';
}