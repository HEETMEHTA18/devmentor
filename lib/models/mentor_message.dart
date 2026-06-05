enum MessageRole { user, assistant }

class MentorMessage {
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  MentorMessage({
    required this.content,
    required this.role,
    required this.timestamp,
  });
}
