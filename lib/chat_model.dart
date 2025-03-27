class Chat {
  final String chatId;
  final String chatName;
  final String lastMessagePreview;
  final List<String> participantNames;

  Chat({
    required this.chatId,
    required this.chatName,
    this.lastMessagePreview = '',
    this.participantNames = const [],
  });
}