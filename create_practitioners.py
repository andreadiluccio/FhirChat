import requests
import json
import uuid
import datetime
from dateutil.tz import tzlocal # Richiede 'pip install python-dateutil'

# --- Configurazione ---
FHIR_SERVER_BASE_URL = "http://127.0.0.1:8080/fhir" # URL base del tuo server HAPI FHIR
PRACTITIONER_ENDPOINT = FHIR_SERVER_BASE_URL + "/Practitioner"
COMMUNICATION_ENDPOINT = FHIR_SERVER_BASE_URL + "/Communication"

# Sistema URN per l'Identifier della Chat (deve corrispondere a quello usato in Flutter)
CHAT_IDENTIFIER_SYSTEM = 'urn:system:chat-id'

# --- Dati dei Practitioner da Creare (Mantieni o Adatta) ---
practitioners_to_create = [
    # Assicurati che gli ID qui corrispondano a quelli che vuoi usare
    {"id": "1", "resourceType": "Practitioner", "active": True, "name": [{"family": "Rossi", "given": ["Mario"]}]},
    {"id": "2", "resourceType": "Practitioner", "active": True, "name": [{"family": "Bianchi", "given": ["Giulia"]}]},
    {"id": "3", "resourceType": "Practitioner", "active": True, "name": [{"family": "Gialli", "given": ["Anna"]}]},
]

# --- Dati del Messaggio Iniziale per la Prima Chat (es. chat1) ---
# Usa gli ID dei Practitioner creati sopra
initial_chat_id = "chat1" # ID della chat che vogliamo inizializzare
initial_sender_id = "1"   # ID del mittente (es. Dr. Rossi)
initial_recipient_ids = ["1"] # ID dei destinatari (es. Dr. Rossi, messaggio a se stesso per iniziare)
initial_message_content = f"Chat '{initial_chat_id}' avviata."

initial_communication_resource = {
    "resourceType": "Communication",
    "identifier": [ # Aggiungi l'identifier per la chat
        {
            "system": CHAT_IDENTIFIER_SYSTEM,
            "value": initial_chat_id
        }
    ],
    "status": "completed", # Messaggio iniziale completato
    # Usa datetime con fuso orario locale e formato corretto
    "sent": datetime.datetime.now(tzlocal()).isoformat(timespec='seconds'),
    "sender": {"reference": f"Practitioner/{initial_sender_id}"},
    # Costruisci la lista dei recipient
    "recipient": [{"reference": f"Practitioner/{rec_id}"} for rec_id in initial_recipient_ids],
    "payload": [{"contentString": initial_message_content}],
    # Il topic può essere mantenuto o rimosso, dato che usiamo identifier per la query
    "topic": {"text": f"Chat ID: {initial_chat_id}"}
}

# --- Funzione per Creare Risorsa FHIR (Generica) ---
def create_fhir_resource(resource_endpoint, resource_data):
    """Invia una richiesta POST per creare una risorsa FHIR."""
    headers = {'Content-Type': 'application/fhir+json'}
    resource_type_to_create = resource_data.get('resourceType', 'Risorsa') # Ottieni il tipo per i log
    try:
        resource_json = json.dumps(resource_data)
        # Usa verify=False per potenziali problemi SSL con localhost
        response = requests.post(resource_endpoint, headers=headers, data=resource_json, verify=False)

        if response.status_code == 201: # 201 Created
            created_resource = response.json()
            resource_id = created_resource.get('id')
            print(f"✅ Successo! {resource_type_to_create} creato con ID: {resource_id}")
            return resource_id
        else:
            print(f"❌ Errore nella creazione di {resource_type_to_create}: Status Code {response.status_code}")
            print(f"   URL Richiesto: {resource_endpoint}")
            print(f"   Payload Inviato: {resource_json}") # Log payload per debug
            print(f"   Risposta: {response.text}")
            return None
    except requests.exceptions.RequestException as e:
        print(f"❌ Errore di connessione al server FHIR durante la creazione di {resource_type_to_create}: {e}")
        return None
    except Exception as e:
        print(f"❌ Errore generico durante la creazione di {resource_type_to_create}: {e}")
        return None

# --- Esecuzione dello Script ---
if __name__ == "__main__":
    print(f"Popolamento iniziale sul server FHIR: {FHIR_SERVER_BASE_URL}")

    # 1. Crea Practitioners
    print("\n--- Creazione Practitioners ---")
    created_practitioner_ids = {} # Dizionario per mappare ID logico a ID FHIR
    for practitioner_data in practitioners_to_create:
        logical_id = practitioner_data.get("id") # Ottieni ID logico (es. "1")
        if not logical_id:
            print("⚠️ Attenzione: Practitioner senza 'id' definito, impossibile associarlo ai messaggi.")
            continue

        print(f"Creazione Practitioner (ID logico: {logical_id}): {practitioner_data.get('name', [{'family': 'Sconosciuto'}])[0].get('family')}")
        # Crea la risorsa senza passare l'ID (lascia che HAPI lo assegni) o passalo se vuoi controllarlo
        # Per semplicità, lasciamo che HAPI assegni l'ID
        data_to_send = practitioner_data.copy()
        if "id" in data_to_send:
             del data_to_send["id"] # Rimuovi ID se vuoi che HAPI lo assegni

        fhir_id = create_fhir_resource(PRACTITIONER_ENDPOINT, data_to_send)
        if fhir_id:
            created_practitioner_ids[logical_id] = fhir_id # Mappa ID logico a ID FHIR

    if created_practitioner_ids:
        print("\nMapping ID Logico -> ID FHIR Practitioners creati:")
        for logical_id, fhir_id in created_practitioner_ids.items():
            print(f"- ID Logico '{logical_id}' -> ID FHIR '{fhir_id}'")
    else:
        print("\nNessun Practitioner creato o impossibile mappare gli ID.")
        # Esci se non ci sono practitioner, non possiamo creare messaggi
        exit()


    # 2. Crea Messaggio Iniziale (Communication) per la prima chat
    print("\n--- Creazione Messaggio Iniziale (Communication) ---")
    print(f"Creazione messaggio iniziale per Chat ID: {initial_chat_id}")

    # Sostituisci gli ID logici con gli ID FHIR reali nel messaggio iniziale
    try:
        initial_communication_resource["sender"]["reference"] = f"Practitioner/{created_practitioner_ids[initial_sender_id]}"
        initial_communication_resource["recipient"] = [
            {"reference": f"Practitioner/{created_practitioner_ids[rec_id]}"} for rec_id in initial_recipient_ids
        ]

        # Crea la risorsa Communication
        created_comm_id = create_fhir_resource(COMMUNICATION_ENDPOINT, initial_communication_resource)

        if created_comm_id:
            print(f"\nMessaggio Communication iniziale creato con ID FHIR: {created_comm_id}")
        else:
            print("\nErrore: Impossibile creare il messaggio Communication iniziale.")

    except KeyError as e:
        print(f"\n❌ Errore: ID Logico Practitioner '{e}' non trovato tra quelli creati. Impossibile creare messaggio iniziale.")
    except Exception as e:
        print(f"\n❌ Errore imprevisto durante la preparazione o creazione del messaggio iniziale: {e}")


    print("\n" + "=" * 40)
    print("Popolamento iniziale completato.")
    print("=" * 40)