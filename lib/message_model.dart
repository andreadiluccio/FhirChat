class Message {
  final String sender;
  final String content;
  final DateTime? deliveredTimestamp;
  final DateTime? readTimestamp;
  final String fhirResourceId; // Nuovo campo: ID risorsa FHIR

  Message({
    required this.sender,
    required this.content,
    this.deliveredTimestamp,
    this.readTimestamp,
    required this.fhirResourceId, // Campo obbligatorio
  });
}