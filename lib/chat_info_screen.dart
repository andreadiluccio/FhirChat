import 'package:flutter/material.dart';
import 'chat_model.dart';

class ChatInfoScreen extends StatefulWidget {
  final Chat chat;
  const ChatInfoScreen({super.key, required this.chat});

  @override
  ChatInfoScreenState createState() => ChatInfoScreenState();
}

class ChatInfoScreenState extends State<ChatInfoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Info Chat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Titolo Chat',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            Text(
              widget.chat.chatName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24.0),
            Text(
              'Partecipanti',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.chat.participantNames.length,
              itemBuilder: (context, index) {
                final participantName = widget.chat.participantNames[index];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(participantName),
                );
              },
            ),
            const SizedBox(height: 24.0),
            Text(
              'Notifiche',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            ListTile(
              title: const Text('Notifiche Chat'),
              trailing: Switch(
                value: true,
                onChanged: (bool newValue) {
                  setState(() {});
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}