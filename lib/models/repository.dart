class Repository {
  final String name;
  final String owner;
  final String description;
  final String difficulty;
  final int impactScore;
  final List<String> tags;
  final String whyRecommended;

  Repository({
    required this.name,
    required this.owner,
    required this.description,
    required this.difficulty,
    required this.impactScore,
    required this.tags,
    required this.whyRecommended,
  });
}
