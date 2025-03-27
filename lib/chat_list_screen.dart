import 'package:flutter/material.dart';
import 'fhir_service.dart';
import 'chat_model.dart';
import 'chat_detail_screen.dart';
import 'user_selection_dialog.dart';
import 'impersonated_user_model.dart';
import 'package:uuid/uuid.dart'; // Import UUID package

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  ChatListScreenState createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen> {
  List<Chat> _chats = [];
  final FhirService _fhirService = FhirService();
  bool _isLoading = false;
  String _currentUserId = "Practitioner/1"; // Inizializzato a Practitioner/1 DI DEFAULT
  List<ImpersonatedUser> _impersonatedUsers = [];
  String? _selectedRecipientIdForNewChat; // Track selected recipient for new chat

  @override
  void initState() {
    super.initState();
    _loadImpersonatedUsersAndChats();
  }

  Future<void> _loadImpersonatedUsersAndChats() async {
    setState(() { _isLoading = true; });
    try {
      _impersonatedUsers = await _fhirService.fetchImpersonatedUsers();
      await _loadChatList();
    } catch (e) {
      print("Errore nel caricamento utenti impersonabili o chat: $e");
      _showErrorDialog('Errore iniziale caricamento dati: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _loadChatList() async {
    if (_isLoading) return;
    setState(() { _isLoading = true; });
    try {
      _chats = await _fhirService.fetchChatList(currentUserId: _currentUserId);
    } catch (e) {
      print("Errore nel caricamento lista chat: $e");
      _showErrorDialog('Errore nel caricamento lista chat: $e');
      _chats = [];
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _showErrorDialog(String message) { /* ... (come prima) ... */ }
  void _showUserSelectionDialog() {
    print("_showUserSelectionDialog called!"); // Debug print to confirm function call
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return UserSelectionDialog(
          users: _impersonatedUsers,
          currentUserId: _currentUserId,
          onUserSelected: (selectedUserId) {
            setState(() {
              _currentUserId = selectedUserId;
            });
            _loadChatList(); // Reload chat list with the new user
          },
        );
      },
    );
  }


  // --- NUOVA FUNZIONE: Mostra Dialogo Nuova Chat ---
  void _showNewChatDialog() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Nuova Chat con...'),
          children: <Widget>[
            SizedBox(
              height: 300, // Altezza limitata per la lista
              width: 300,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _impersonatedUsers.length,
                itemBuilder: (context, index) {
                  final user = _impersonatedUsers[index];
                  return RadioListTile<String>(
                    title: Text('${user.name} (${user.resourceType})'),
                    value: user.id,
                    groupValue: _selectedRecipientIdForNewChat,
                    onChanged: (String? value) {
                      setState(() { _selectedRecipientIdForNewChat = value; });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () { Navigator.of(context).pop(); },
                    child: const Text('Annulla'),
                  ),
                  ElevatedButton(
                    onPressed: _selectedRecipientIdForNewChat == null ? null : () {
                      Navigator.of(context).pop(_selectedRecipientIdForNewChat); // Chiudi Dialogo E restituisci l'utente selezionato
                    },
                    child: const Text('Inizia Chat'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ).then((selectedRecipientId) { // Gestisci il risultato del Dialogo
      if (selectedRecipientId is String) {
        _startNewChat(selectedRecipientId); // Chiama funzione per INIZIARE la chat
      } else {
        print("Nuova chat cancellata o nessun destinatario selezionato.");
      }
    });
  }

  void _startNewChat(String recipientId) {
    // TODO: Implementa la logica per creare una nuova chat con recipientId
    final chatId = const Uuid().v4(); // Genera UUID per chatId
    final recipientUser = _impersonatedUsers.firstWhere((user) => user.id == recipientId);
    final chatName = 'Chat con ${recipientUser.name}';

    final newChat = Chat(
      chatId: chatId,
      chatName: chatName,
      participantNames: [_currentUserId, recipientId], // Partecipanti (demo)
      lastMessagePreview: 'Nuova chat iniziata', // Preview iniziale
    );

    setState(() {
      _chats = [..._chats, newChat]; // Aggiungi la nuova chat alla lista (DEMO - solo frontend)
    });

    Navigator.push( // Naviga direttamente alla ChatDetailScreen della nuova chat
      context,
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(chatId: chatId, currentUserId: _currentUserId), // **PASS _currentUserId HERE**
      ),
    );

    print("Inizia nuova chat con recipientId: $recipientId, chatId: $chatId");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Nuova chat iniziata con: ${recipientUser.name}')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista Chat (Utente: $_currentUserId)'),
        actions: [ /* ... (come prima - User Selection and Refresh buttons) ... */
          IconButton(
            icon: const Icon(Icons.person_pin),
            tooltip: 'Seleziona Utente',
            onPressed: _isLoading ? null : _showUserSelectionDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Chat List',
            onPressed: _isLoading ? null : _loadChatList,
          ),
        ],
      ),
      body: (_isLoading && _chats.isEmpty)
          ? const Center(child: CircularProgressIndicator())
          : (_chats.isEmpty)
          ? const Center(child: Text("Nessuna chat. Inizia una nuova!"))
          : ListView.builder( /* ... (come prima - ListView.builder for chat list) ... */
        itemCount: _chats.length,
        itemBuilder: (context, index) {
          final chat = _chats[index];
          return ListTile(
            title: Text(chat.chatName),
            subtitle: Text(chat.lastMessagePreview),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatDetailScreen(chatId: chat.chatId, currentUserId: _currentUserId), // **PASS _currentUserId HERE**
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _showNewChatDialog, // Mostra Dialogo Nuova Chat
        tooltip: 'Nuova Chat',
        child: const Icon(Icons.add),
      ),
    );
  }
} // FINE della classe ChatListScreenState