import 'package:flutter/material.dart';
import 'fhir_service.dart';
import 'message_model.dart';
import 'chat_info_screen.dart';
import 'chat_model.dart';
import 'package:intl/intl.dart';
import 'user_selection_dialog.dart';
import 'impersonated_user_model.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String currentUserId;
  const ChatDetailScreen({super.key, required this.chatId, required this.currentUserId});

  @override
  ChatDetailScreenState createState() => ChatDetailScreenState();
}

class ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();
  List<Message> _messages = [];
  final FhirService _fhirService = FhirService();
  bool _isLoading = false;
  bool _isSending = false;

  List<ImpersonatedUser> _impersonatedUsers = [];
  late String _currentUserId;
  ImpersonatedUser? _currentUserDetails;

  @override
  void initState() {
    super.initState();
    _currentUserId = widget.currentUserId;
    print("ChatDetailScreenState.initState() chiamato - Utente: $_currentUserId");
    _loadImpersonatedUsersAndChat();
  }

  Future<void> _loadImpersonatedUsersAndChat() async {
    print("ChatDetailScreenState._loadImpersonatedUsersAndChat() iniziato - Utente: $_currentUserId");
    setState(() { _isLoading = true; });
    try {
      _impersonatedUsers = await _fhirService.fetchImpersonatedUsers();
      print("ChatDetailScreenState._loadImpersonatedUsersAndChat(): Utenti impersonabili caricati.");
      _currentUserDetails = _impersonatedUsers.firstWhere((user) => user.id == _currentUserId);
    } catch (e) {
      print("Errore in ChatDetailScreenState._loadImpersonatedUsersAndChat(): $e");
      _showErrorDialog('Errore iniziale nel caricamento dati: $e');
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
    print("ChatDetailScreenState._loadImpersonatedUsersAndChat() completato - Utente: $_currentUserId");
    await _loadChatMessages();
  }


  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool immediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (immediate) {
          _scrollController.jumpTo(max);
        } else {
          _scrollController.animateTo(max, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      }
    });
  }

  Future<void> _loadChatMessages() async {
    if (_isLoading) {
      print("ChatDetailScreenState._loadChatMessages() ignorato (isLoading=true) - Utente: $_currentUserId");
      return;
    }
    print("ChatDetailScreenState._loadChatMessages() iniziato per chatId: ${widget.chatId} - Utente: $_currentUserId");
    setState(() { _isLoading = true; });
    try {
      final fetchedMessages = await _fhirService.fetchMessagesForChat(widget.chatId);
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 50));
        print("ChatDetailScreenState._loadChatMessages(): Messaggi recuperati (${fetchedMessages.length}). Chiamando setState per aggiornare UI - Utente: $_currentUserId");
        setState(() {
          _messages = fetchedMessages;
          _isLoading = false;
        });
        _scrollToBottom(immediate: true);
      }
    } catch (e) {
      print("Errore in ChatDetailScreenState._loadChatMessages(): $e - Utente: $_currentUserId");
      if (mounted) {
        setState(() { _isLoading = false; });
        _showErrorDialog('Errore nel caricamento dei messaggi: $e');
      }
    }
    print("ChatDetailScreenState._loadChatMessages() completato - Utente: $_currentUserId");
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isNotEmpty && !_isSending) {
      setState(() { _isSending = true; });
      final String messageToSend = text;
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_inputFocusNode);
      });

      try {
        final List<String> recipientIds = ['2'];

        await _fhirService.sendChatMessage(
            messageToSend,
            chatId: widget.chatId,
            recipientIds: recipientIds,
            currentUserId: _currentUserId // Passa currentUserId a sendChatMessage
        );

        if (mounted) {
          print("ChatDetailScreenState._sendMessage: Invio riuscito, ricaricando i messaggi... - Utente: $_currentUserId");
          await _loadChatMessages();
        }

      } catch (e) {
        print("Errore in ChatDetailScreenState._sendMessage: Errore nell'invio del messaggio: $e - Utente: $_currentUserId");
        if (mounted) {
          _showErrorDialog('Errore nell\'invio del messaggio: $e');
          _messageController.text = messageToSend;
        }
      } finally {
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 100));
          setState(() { _isSending = false; });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            FocusScope.of(context).requestFocus(_inputFocusNode);
          });
        }
      }
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Errore'),
          content: SingleChildScrollView( child: ListBody(children: <Widget>[Text(message)]), ),
          actions: <Widget>[ TextButton( child: const Text('OK'), onPressed: () { Navigator.of(dialogContext).pop(); }, ), ],
        );
      },
    );
  }

  Chat _getCurrentChatObject() {
    // Miglioramento MOCK - Usa chatId per creare un nome più descrittivo
    String chatName = 'Chat ${widget.chatId}';
    // Potrebbe voler aggiungere logica per recuperare nomi partecipanti da qualche parte
    // (es. se li hai passati da ChatListScreen o li recuperi dal backend)
    // Per ora, mantieni placeholder partecipanti
    return Chat(
      chatId: widget.chatId,
      chatName: chatName, // Usa il nome chat dinamico (MOCK)
      participantNames: ['Utente 1', 'Utente 2'], // Placeholder partecipanti
      lastMessagePreview: _messages.isNotEmpty ? _messages.last.content : '',
    );
  }

  // --- NUOVA FUNZIONE: Ottieni nome e tipo utente da ID ---
  Map<String, dynamic> _getUsernameAndTypeFromId(String userId) {
    final user = _impersonatedUsers.firstWhere(
          (user) => user.id == userId,
      orElse: () => ImpersonatedUser(id: 'unknown', name: 'Sconosciuto', resourceType: 'Unknown'),
    );
    return {'name': user.name, 'resourceType': user.resourceType};
  }

  void _showUserSelectionDialog() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return UserSelectionDialog(
          users: _impersonatedUsers,
          currentUserId: _currentUserId,
          onUserSelected: (selectedUserId) {
            setState(() {
              _currentUserId = selectedUserId;
            });
            _loadChatMessages();
            print('Utente selezionato: $_currentUserId');
          },
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    String titleText = 'Chat: ${_getCurrentChatObject().chatName}';
    String subtitleText = '';
    if (_currentUserDetails != null) {
      subtitleText = 'Utente: ${_currentUserDetails!.name} - ${_currentUserDetails!.resourceType}';
    } else {
      subtitleText = 'Utente: $_currentUserId';
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titleText),
            if (subtitleText.isNotEmpty)
              Text(
                subtitleText,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_pin),
            tooltip: 'Seleziona Utente',
            onPressed: _isLoading || _isSending ? null : _showUserSelectionDialog,
          ),
          IconButton( icon: const Icon(Icons.info_outline), tooltip: 'Info Chat', onPressed: () { Navigator.push( context, MaterialPageRoute(builder: (context) => ChatInfoScreen(chat: _getCurrentChatObject())), ); }, ),
          IconButton( icon: const Icon(Icons.refresh), tooltip: 'Ricarica Messaggi', onPressed: _isLoading || _isSending ? null : _loadChatMessages, ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_isLoading && _messages.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (!_isLoading && _messages.isEmpty)
            const Expanded(child: Center(child: Text("Nessun messaggio in questa chat. Inizia tu!")))
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final bool isMe = message.sender == _currentUserId;
                  final Map<String, dynamic> senderInfo = _getUsernameAndTypeFromId(message.sender);
                  final String senderName = senderInfo['name'];
                  final String senderType = senderInfo['resourceType'];

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: ConstrainedBox( // **UTILIZZA ConstrainedBox INVECE DI Container DIRETTO**
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.75,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[100] : Colors.grey[300],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16.0),
                            topRight: const Radius.circular(16.0),
                            bottomLeft: Radius.circular(isMe ? 16.0 : 0),
                            bottomRight: Radius.circular(isMe ? 0 : 16.0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 2,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child:  Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row( // **RIGA per NOME e ICONA**
                              children: [
                                Text(
                                  senderName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54),
                                ),
                                const SizedBox(width: 5),
                                if (senderType == 'Practitioner')
                                  const Icon(Icons.medical_services, size: 16, color: Colors.blueGrey),
                                if (senderType == 'Patient')
                                  const Icon(Icons.person, size: 16, color: Colors.orangeAccent),
                              ],
                            ),
                            Text(
                              message.content,
                              style: const TextStyle(color: Colors.black87),
                            ),
                            if (message.deliveredTimestamp != null)
                              Text(
                                "Delivered: ${DateFormat('HH:mm:ss').format(message.deliveredTimestamp!)}",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            if (message.readTimestamp != null)
                              Text(
                                "Read: ${DateFormat('HH:mm:ss').format(message.readTimestamp!)}",
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (_isSending) const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: LinearProgressIndicator(minHeight: 2)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _inputFocusNode,
                    enabled: !_isSending,
                    decoration: const InputDecoration(
                      hintText: 'Scrivi un messaggio...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: _isSending ? null : (_) => _sendMessage(),
                    minLines: 1,
                    maxLines: 5,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isSending || _messageController.text.trim().isEmpty ? null : _sendMessage,
                  tooltip: 'Invia Messaggio',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} // FINE della classe ChatDetailScreenState