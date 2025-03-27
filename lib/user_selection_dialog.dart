import 'package:flutter/material.dart';
import 'impersonated_user_model.dart';

class UserSelectionDialog extends StatefulWidget {
  final List<ImpersonatedUser> users;
  final String currentUserId;
  final Function(String) onUserSelected;

  const UserSelectionDialog({
    super.key,
    required this.users,
    required this.currentUserId,
    required this.onUserSelected,
  });

  @override
  UserSelectionDialogState createState() => UserSelectionDialogState();
}

class UserSelectionDialogState extends State<UserSelectionDialog> {
  String? _selectedUserId;

  @override
  void initState() {
    super.initState();
    _selectedUserId = widget.currentUserId; // Inizializza con l'utente corrente
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleziona Utente'),
      content: SizedBox(
        width: double.maxFinite, // Larghezza massima per il contenuto del dialogo
        height: 300, // Altezza limitata per la lista
        child: ListView.builder(
          shrinkWrap: true, // Importante per ListView in un Dialog
          itemCount: widget.users.length,
          itemBuilder: (context, index) {
            final user = widget.users[index];
            return RadioListTile<String>(
              title: Text('${user.name} (${user.resourceType})'), // Mostra nome e tipo risorsa
              value: user.id,
              groupValue: _selectedUserId,
              onChanged: (String? value) {
                if (value != null) {
                  setState(() { _selectedUserId = value; });
                }
              },
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Annulla'),
          onPressed: () { Navigator.of(context).pop(); },
        ),
        TextButton(
          child: const Text('Seleziona'),
          onPressed: () {
            if (_selectedUserId != null) {
              widget.onUserSelected(_selectedUserId!); // Chiama callback con l'utente selezionato
              Navigator.of(context).pop();
            }
          },
        ),
      ],
    );
  }
}