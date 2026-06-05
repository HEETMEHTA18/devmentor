class RoadmapMilestone {
  final String title;
  final String description;
  final bool isCompleted;

  RoadmapMilestone({
    required this.title,
    required this.description,
    this.isCompleted = false,
  });
}

class CareerRoadmap {
  final String title;
  final String level;
  final List<RoadmapMilestone> milestones;

  CareerRoadmap({
    required this.title,
    required this.level,
    required this.milestones,
  });
}
