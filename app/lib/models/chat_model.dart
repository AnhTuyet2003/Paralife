class ChatMessage {
  final String id;
  final String role; // 'user' hoặc 'ai'
  final String content;
  final DateTime createdAt;
  final List<dynamic>? citations; // Thêm trường trích dẫn

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.citations,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'].toString(),
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : DateTime.now(),
      citations: json['citations'], 
    );
  }
}