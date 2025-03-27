import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'chat_model.dart';
import 'message_model.dart';
import 'impersonated_user_model.dart'; // Import del modello ImpersonatedUser

class FhirService {
  final String backendBaseUrl = 'http://localhost:5000';
  final String fhirServerBaseUrl = 'http://127.0.0.1:8080/fhir';
  final String chatAppEndpointUrl = 'http://localhost:50112';
  final String recipientEndpointPlaceholder = 'urn:system:fhir-chat-app';
  final String chatIdentifierSystem = 'urn:system:chat-id';

  Future<List<Chat>> fetchChatList({required String currentUserId}) async { // Modifica: accetta currentUserId (non usato per ora)
    await Future.delayed(const Duration(seconds: 1)); // Simula latenza
    // Dati DEMO - Sostituisci con la logica di recupero reale
    return [
      Chat(chatId: 'chat1', chatName: 'Dr. Rossi (Privata)', lastMessagePreview: 'Urgent patient update', participantNames: ['Dr. Rossi']),
      Chat(chatId: 'chat2', chatName: 'Riunione Team Cura Paziente X', lastMessagePreview: 'Agenda for tomorrow\'s meeting', participantNames: ['Dr. Bianchi', 'Dr. Verdi', 'Me', 'Infermiera Gialli']),
      Chat(chatId: 'chat3', chatName: 'Discussione Risultati Lab Paziente Y', lastMessagePreview: 'New lab results are available', participantNames: ['Lab System', 'Me']),
      Chat(chatId: 'chat4', chatName: 'Gruppo Test Infermieri', participantNames: ['Infermiera 1', 'Infermiera 2', 'Infermiera 3', 'Me']),
    ]; // Assicura che ci sia un return
  }

  Future<List<Message>> fetchMessagesForChat(String chatId) async {
    print("FhirService.fetchMessagesForChat: Inizio fetch messaggi per chat: $chatId (Cache-Control: no-cache)"); // DEBUG PRINT
    final identifierParam = '$chatIdentifierSystem|$chatId';
    final encodedIdentifier = Uri.encodeComponent(identifierParam);
    final queryUrl = '$fhirServerBaseUrl/Communication?identifier=$encodedIdentifier&_sort=-sent';
    print("FhirService.fetchMessagesForChat: FHIR Query URL (identifier): $queryUrl"); // DEBUG PRINT

    try {
      final response = await http.get(
        Uri.parse(queryUrl),
        headers: {
          'Accept': 'application/fhir+json',
          'Cache-Control': 'no-cache',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        print("FhirService.fetchMessagesForChat: Risposta FHIR 200 OK ricevuta."); // DEBUG PRINT

        if (responseBody is Map<String, dynamic> && responseBody['resourceType'] == 'Bundle') {
          final List<Message> messages = [];
          if (responseBody['entry'] != null && responseBody['entry'] is List) {
            for (var entry in responseBody['entry']) {
              if (entry['resource'] != null && entry['resource']['resourceType'] == 'Communication') {
                final communication = entry['resource'];
                String senderName = "Sconosciuto";
                final String fhirResourceId = communication['id'] ?? 'unknown-resource-id'; // Estrai l'ID risorsa, fallback se nullo
                if (communication['sender'] != null && communication['sender']['reference'] != null) {
                  senderName = communication['sender']['reference'];
                }
                String content = "Contenuto non disponibile";
                if (communication['payload'] != null &&
                    communication['payload'] is List &&
                    communication['payload'].isNotEmpty &&
                    communication['payload'][0]['contentString'] != null) {
                  content = communication['payload'][0]['contentString'];
                }

                DateTime? deliveredTimestamp;
                DateTime? readTimestamp;

                if (communication['extension'] != null && communication['extension'] is List) {
                  for (var extension in communication['extension']) {
                    if (extension['url'] == "http://example.org/fhir/StructureDefinition/deliveredTimestamp") {
                      if (extension['valueDateTime'] != null) {
                        deliveredTimestamp = DateTime.tryParse(extension['valueDateTime']);
                      }
                    } else if (extension['url'] == "http://example.org/fhir/StructureDefinition/readTimestamp") {
                      if (extension['valueDateTime'] != null) {
                        readTimestamp = DateTime.tryParse(extension['valueDateTime']);
                      }
                    }
                  }
                }
                messages.add(Message(sender: senderName, content: content, deliveredTimestamp: deliveredTimestamp, readTimestamp: readTimestamp, fhirResourceId: fhirResourceId)); // Passa fhirResourceId
              }
            }
          }
          print("FhirService.fetchMessagesForChat: Recuperati ${messages.length} messaggi reali."); // DEBUG PRINT
          return messages.reversed.toList();
        } else {
          print('FhirService.fetchMessagesForChat: Errore: La risposta dal server FHIR non è un Bundle valido.'); // DEBUG PRINT
          throw Exception('Risposta non è un Bundle FHIR valido');
        }
      } else {
        print('FhirService.fetchMessagesForChat: Errore HTTP: Status code ${response.statusCode}'); // DEBUG PRINT
        print('FhirService.fetchMessagesForChat: Body Errore FHIR: ${response.body}'); // DEBUG PRINT
        throw Exception('Errore nel recuperare i messaggi FHIR: Status code ${response.statusCode}');
      }
    } catch (e) {
      print('FhirService.fetchMessagesForChat: Errore generico: $e'); // DEBUG PRINT
      throw Exception('Errore generico nel recuperare i messaggi: $e');
    }
  }

  Future<List<Message>> fetchNewMessagesForChat() async {
    await Future.delayed(const Duration(seconds: 1));
    print("Polling for new messages (DEMO - no actual fetch)");
    return [];
  }

  Future<void> sendChatMessage(String messageText, {required String chatId, required List<String> recipientIds, required String currentUserId}) async { // Passa currentUserId
    final messageBundle = _createFhirMessageBundle(messageText, chatId: chatId, recipientIds: recipientIds, currentUserId: currentUserId); // Passa currentUserId
    try {
      final response = await http.post(
        Uri.parse('$backendBaseUrl/fhir/process-chat-message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(messageBundle),
      );
      if (response.statusCode == 201) {
        print('FhirService.sendChatMessage: Messaggio FHIR inviato e registrato con successo sul backend. Status: ${response.statusCode}'); // DEBUG PRINT
        return;
      } else {
        print('FhirService.sendChatMessage: Errore nell\'invio del messaggio FHIR al backend. Status: ${response.statusCode}'); // DEBUG PRINT
        print('FhirService.sendChatMessage: Body Errore: ${response.body}'); // DEBUG PRINT
        throw Exception('Errore nell\'invio del messaggio FHIR: Status code ${response.statusCode}');
      }
    } catch (e) {
      print('FhirService.sendChatMessage: Errore generico durante l\'invio del messaggio FHIR: $e'); // DEBUG PRINT
      throw Exception('Errore generico nell\'invio del messaggio FHIR: $e');
    }
  }

  // --- NUOVA FUNZIONE: Marca i messaggi come letti (MOCK - DA IMPLEMENTARE CHIAMATA BACKEND) ---
  Future<void> markMessagesAsRead(List<String> messageResourceIds) async {
    if (messageResourceIds.isEmpty) {
      print("FhirService.markMessagesAsRead: Nessun messaggio da marcare come letto."); // DEBUG PRINT
      return; // Esci se la lista è vuota
    }
    print("FhirService.markMessagesAsRead: Tentativo di marcare come letti i seguenti resource IDs: $messageResourceIds"); // DEBUG PRINT

    // --- IMPLEMENTAZIONE MOCK - DA SOSTITUIRE CON CHIAMATA HTTP AL BACKEND ---
    await Future.delayed(const Duration(seconds: 1)); // Simula chiamata di rete
    print("FhirService.markMessagesAsRead: MOCK - Messaggi (resource IDs: $messageResourceIds) marcati come letti SUL CLIENT (backend non chiamato in questa versione MOCK)."); // DEBUG PRINT
    // --- FINE IMPLEMENTAZIONE MOCK ---

    // --- IMPLEMENTAZIONE REALE (DA FARE): ---
    // 1. Costruisci la URL per l'endpoint backend (es. '$backendBaseUrl/fhir/mark-messages-read')
    // 2. Prepara il body della richiesta (JSON con la lista di messageResourceIds)
    // 3. Esegui una chiamata POST o PUT al backend
    // 4. Gestisci la risposta (es. controlla status code 200 OK) e eventuali errori
  }

  // --- NUOVA FUNZIONE: Recupera lista di utenti Practitioner e Patient ---
  Future<List<ImpersonatedUser>> fetchImpersonatedUsers() async {
    List<ImpersonatedUser> users = [];

    // Recupera Practitioner
    try {
      final practitionerResponse = await http.get(Uri.parse('$fhirServerBaseUrl/Practitioner?_summary=true&_count=100')); // _summary=true per dati essenziali
      if (practitionerResponse.statusCode == 200) {
        final practitionerBody = jsonDecode(practitionerResponse.body);
        if (practitionerBody is Map<String, dynamic> && practitionerBody['resourceType'] == 'Bundle' && practitionerBody['entry'] is List) {
          for (var entry in practitionerBody['entry']) {
            if (entry['resource'] != null && entry['resource']['resourceType'] == 'Practitioner') {
              final practitioner = entry['resource'];
              final practitionerId = practitioner['id'];
              String practitionerName = 'Practitioner ID: $practitionerId'; // Fallback name
              if (practitioner['name'] != null && practitioner['name'] is List && practitioner['name'].isNotEmpty) {
                final name = practitioner['name'][0];
                final family = name['family'] ?? '';
                final given = (name['given'] as List<dynamic>?)?.join(' ') ?? ''; // Gestisci null e lista
                practitionerName = 'Dr. $given $family'.trim(); // Esempio formato nome
              }
              users.add(ImpersonatedUser(id: 'Practitioner/$practitionerId', name: practitionerName, resourceType: 'Practitioner'));
            }
          }
        }
      } else {
        print('FhirService.fetchImpersonatedUsers: Errore HTTP nel fetch Practitioner: Status code ${practitionerResponse.statusCode}');
      }
    } catch (e) {
      print('FhirService.fetchImpersonatedUsers: Errore generico nel fetch Practitioner: $e');
    }


    // Recupera Patient
    try {
      final patientResponse = await http.get(Uri.parse('$fhirServerBaseUrl/Patient?_count=100')); // RIMOSSO _summary=true
      print("FhirService.fetchImpersonatedUsers: Patient response status code: ${patientResponse.statusCode}");
      if (patientResponse.statusCode == 200) {
        final patientBody = jsonDecode(patientResponse.body);
        print("FhirService.fetchImpersonatedUsers: Patient response body (first 100 chars): ${patientResponse.body.substring(0, 100)}...");
        if (patientBody is Map<String, dynamic> && patientBody['resourceType'] == 'Bundle' && patientBody['entry'] is List) {
          print("FhirService.fetchImpersonatedUsers: Patient Bundle entries found: ${patientBody['entry'].length}");
          for (var entry in patientBody['entry']) {
            if (entry['resource'] != null && entry['resource']['resourceType'] == 'Patient') {
              final patient = entry['resource'];
              final patientId = patient['id']; // **CODICE CORRETTO - ASSUME CHE 'id' SIA DIRETTAMENTE IN 'patient' (entry['resource'])**
              String patientName = 'Patient ID: $patientId';
              if (patient['name'] != null && patient['name'] is List && patient['name'].isNotEmpty) {
                final name = patient['name'][0];
                final family = name['family'] ?? '';
                final given = (name['given'] as List<dynamic>?)?.join(' ') ?? '';
                patientName = '$given $family'.trim();
              }
              users.add(ImpersonatedUser(id: 'Patient/$patientId', name: patientName, resourceType: 'Patient'));
              print("FhirService.fetchImpersonatedUsers: Added Patient: ${patientId} - ${patientName}"); // Usa patientId qui
            }
          }
        } else {
          print('FhirService.fetchImpersonatedUsers: Warning - Patient response is not a valid Bundle or missing entries.');
        }
      } else {
        print('FhirService.fetchImpersonatedUsers: Errore HTTP nel fetch Patient: Status code ${patientResponse.statusCode}');
        print('FhirService.fetchImpersonatedUsers: Body Errore Patient: ${patientResponse.body}');
      }
    } catch (e) {
      print('FhirService.fetchImpersonatedUsers: Errore generico nel fetch Patient: $e');
    }

    print('fetchImpersonatedUsers: Trovati ${users.length} utenti (Practitioner e Patient)');
    return users;
  }


  Map<String, dynamic> _createFhirMessageBundle(String messageText, {required String chatId, required List<String> recipientIds, required String currentUserId}) { // Passa currentUserId
    final now = DateTime.now();
    final sentDateTimeString = DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(now);
    final timeZoneOffset = now.timeZoneOffset;
    final offsetHours = timeZoneOffset.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (timeZoneOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final offsetSign = timeZoneOffset.isNegative ? '-' : '+';
    final timeZoneString = timeZoneOffset.inSeconds == 0 ? 'Z' : '$offsetSign$offsetHours:$offsetMinutes';
    final formattedSentDateTime = '$sentDateTimeString$timeZoneString';

    return {
      "resourceType": "Bundle", "type": "message", "entry": [
        { "resource": { "resourceType": "MessageHeader", "eventUri": "urn:example:fhir-chat-message", "sender": { "reference": currentUserId }, "source": { "name": "FHIR Chat App (Flutter)", "endpoint": chatAppEndpointUrl }, "destination": _createFhirDestinations(recipientIds), } }, // Usa currentUserId PARAMETER
        { "resource": { "resourceType": "Communication", "identifier": [ { "system": chatIdentifierSystem, "value": chatId } ], "status": "in-progress", "sent": formattedSentDateTime, "sender": { "reference": currentUserId }, "recipient": _createFhirRecipients(recipientIds), "payload": [ { "contentString": messageText } ], "topic": { "text": "Chat ID: $chatId" }, } } // Usa currentUserId PARAMETER
      ]
    };
  }
  List<Map<String, dynamic>> _createFhirDestinations(List<String> recipientIds) { return recipientIds.map((recipientId) => { "name": "Recipient App", "endpoint": recipientEndpointPlaceholder, "target": { "reference": "Practitioner/$recipientId" } }).toList(); }
  List<Map<String, dynamic>> _createFhirRecipients(List<String> recipientIds) { return recipientIds.map((recipientId) => { "reference": "Practitioner/$recipientId" }).toList(); }

} // FINE della classe FhirService