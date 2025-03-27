from flask import Flask, request, jsonify
from flask_sockets import Sockets
import fhirclient.models.bundle as bdl
import fhirclient.models.messageheader as mh
import fhirclient.models.communication as comm
import datetime
import json
from fhirclient import client
import requests
from flask_cors import CORS
import traceback # Importa traceback per il debug

app = Flask(__name__)
CORS(app)
sockets = Sockets(app)

FHIR_SERVER_URL = "http://127.0.0.1:8080/fhir"
FHIR_CLIENT_ID = "[your-client-id]"
FHIR_CLIENT_SECRET = "[your-client-secret]"

fhir_conf = { 'app_id': 'intra-hospital-chat-fhir-driven', 'api_base': FHIR_SERVER_URL }
if FHIR_CLIENT_ID and FHIR_CLIENT_SECRET:
    fhir_conf['client_id'] = FHIR_CLIENT_ID
    fhir_conf['client_secret'] = FHIR_CLIENT_SECRET

fhir_server = client.FHIRClient(fhir_conf)

connected_clients = []

@app.route('/fhir/process-chat-message', methods=['POST'])
def process_chat_message():
    bundle_json = request.get_json()
    try:
        fhir_bundle = bdl.Bundle(bundle_json)

        if not isinstance(fhir_bundle, bdl.Bundle) or fhir_bundle.type != "message":
            return jsonify({"error": "Bundle non valido: tipo errato. Deve essere 'message'."}), 400

        message_header = None
        communication_resource = None
        communication_resource_json = None # Memorizza il JSON originale per POST

        if fhir_bundle.entry:
            for entry in fhir_bundle.entry:
                # 'resource' POTREBBE essere già un oggetto FHIR in fhirclient 4.3.1
                resource_object_or_dict = entry.resource
                if resource_object_or_dict:
                    resource_type = None
                    resource_data_dict = None # Dizionario per creare istanze (se necessario)

                    # **CORREZIONE: Controlla se è già un oggetto o un dizionario**
                    if hasattr(resource_object_or_dict, 'resource_type'):
                        # Se ha l'attributo 'resource_type', è probabile sia già un oggetto FHIR
                        resource_type = resource_object_or_dict.resource_type
                        # Tentiamo di ottenere il JSON dall'oggetto per coerenza
                        try:
                            resource_data_dict = resource_object_or_dict.as_json()
                        except AttributeError:
                             # Se .as_json() non esiste, l'oggetto potrebbe essere problematico
                             print(f"Attenzione: Oggetto risorsa ({resource_type}) non ha .as_json()")
                             # In questo caso, potremmo dover saltare o gestire l'errore
                             continue # Salta questa entry se non possiamo ottenere il JSON
                    elif isinstance(resource_object_or_dict, dict) and 'resourceType' in resource_object_or_dict:
                        # Se è un dizionario e ha 'resourceType', usiamo quello
                        resource_type = resource_object_or_dict.get('resourceType')
                        resource_data_dict = resource_object_or_dict # È già un dizionario
                    else:
                        # Tipo di risorsa sconosciuto o inatteso
                        print(f"Attenzione: Trovata entry risorsa con tipo inatteso o mancante: {type(resource_object_or_dict)}")
                        continue # Salta questa entry

                    # Crea istanze se necessario (o usa quelle già create se disponibili)
                    if resource_type == 'MessageHeader':
                        try:
                            # Se non è già un oggetto MessageHeader, crealo dal dizionario
                            if not isinstance(resource_object_or_dict, mh.MessageHeader):
                                message_header = mh.MessageHeader(resource_data_dict)
                            else:
                                message_header = resource_object_or_dict # È già un oggetto
                        except Exception as e_mh:
                            print(f"Errore nella creazione di MessageHeader: {e_mh}")
                            # Considera di restituire errore 400
                            continue
                    elif resource_type == 'Communication':
                        try:
                            # Se non è già un oggetto Communication, crealo dal dizionario
                            if not isinstance(resource_object_or_dict, comm.Communication):
                                communication_resource = comm.Communication(resource_data_dict)
                            else:
                                communication_resource = resource_object_or_dict # È già un oggetto
                            communication_resource_json = resource_data_dict # Memorizza il dizionario per POST
                        except Exception as e_comm:
                            print(f"Errore nella creazione di Communication: {e_comm}")
                            # Considera di restituire errore 400
                            continue


        if not message_header or not communication_resource:
            return jsonify({"error": "Bundle incompleto: MessageHeader e Communication richiesti validi."}), 400

        sender_id = message_header.sender.reference if hasattr(message_header, 'sender') and message_header.sender else "Sender non specificato"
        print(f"Messaggio ricevuto dal sender: {sender_id}")

        try:
            fhir_resource_url = FHIR_SERVER_URL + '/Communication'
            headers = {'Content-Type': 'application/fhir+json'}

            # Usa il dizionario JSON memorizzato per il payload
            if not communication_resource_json:
                return jsonify({"error": "Dati JSON della risorsa Communication non disponibili."}), 500
            communication_json_payload = json.dumps(communication_resource_json)

            response = requests.post(fhir_resource_url, headers=headers, data=communication_json_payload, verify=False)

            if response.status_code == 201:
                saved_communication_data = response.json()
                saved_communication_id = saved_communication_data.get('id')
                print(f"Risorsa Communication FHIR creata con ID (HTTP POST): {saved_communication_id}")
            else:
                print(f"Errore HTTP nel salvare Communication (HTTP POST):")
                print(f"  URL Richiesto: {fhir_resource_url}")
                print(f"  Status Code: {response.status_code}")
                print(f"  Response Text: {response.text}")
                return jsonify({"error": "Errore HTTP nel salvare Communication (HTTP POST)", "status_code": response.status_code, "details": response.text}), response.status_code

            recipients = message_header.destination if hasattr(message_header, 'destination') else []
            recipient_refs = [dest.target.reference for dest in recipients if hasattr(dest, 'target') and dest.target and hasattr(dest.target, 'reference')]
            print(f"Messaggio diretto a destinatari: {recipient_refs}")

            return jsonify({"status": "Messaggio FHIR processato e registrato con successo (HTTP POST WORKAROUND)", "communication_id": saved_communication_id}), 201

        except requests.exceptions.RequestException as e_requests:
             print(f"Errore durante la richiesta HTTP al server FHIR: {e_requests}")
             return jsonify({"error": f"Errore di connessione al server FHIR: {e_requests}"}), 503
        except Exception as e_fhir_save:
            print(f"Errore nel salvare risorse FHIR o nel routing (HTTP POST WORKAROUND): {e_fhir_save}")
            traceback.print_exc() # Stampa traceback per debug
            return jsonify({"error": f"Errore nel processare il messaggio FHIR durante il salvataggio (HTTP POST WORKAROUND): {e_fhir_save}"}), 500

    except Exception as e_generic:
        print(f"Errore generico nel processare la richiesta (probabilmente nel parsing Bundle): {e_generic}")
        traceback.print_exc() # Stampa traceback completo per debug
        return jsonify({"error": f"Errore generico durante l'elaborazione della richiesta: {e_generic}"}), 500

@app.route('/')
def hello():
    return "Backend Chat FHIR-Driven attivo (WORKAROUND - fhirclient 4.3.1)!"

if __name__ == "__main__":
    app.run(debug=True, port=5000)