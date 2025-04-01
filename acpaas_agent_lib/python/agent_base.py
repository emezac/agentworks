def create_message(tipo, origen, destino, id_mensaje=None, respuesta_a=None, id_sesion=None, numero_secuencia=None, requiere_ack=False, datos=None):
    import uuid
    from datetime import datetime

    if id_mensaje is None:
        id_mensaje = str(uuid.uuid4())
    
    message = {
        "tipo": tipo,
        "id_mensaje": id_mensaje,
        "origen": origen,
        "destino": destino,
        "respuesta_a": respuesta_a,
        "timestamp": datetime.utcnow().isoformat() + 'Z',
        "id_sesion": id_sesion,
        "numero_secuencia": numero_secuencia,
        "requiere_ack": requiere_ack,
        "datos": datos or {}
    }
    
    return message 

import json

def parse_message(json_str):
    """
    Parses a JSON string into a message dictionary and validates required fields.

    Args:
        json_str (str): The JSON string representing the message.

    Returns:
        dict: The parsed message as a dictionary.

    Raises:
        ValueError: If the JSON is invalid or required fields are missing.
    """
    try:
        # Parse the JSON string
        message = json.loads(json_str)
    except json.JSONDecodeError as e:
        raise ValueError(f"Invalid JSON: {e}")

    # Define required fields
    required_fields = ["tipo", "id_mensaje", "origen", "destino", "timestamp"]

    # Check for required fields
    missing_fields = [field for field in required_fields if field not in message]
    if missing_fields:
        raise ValueError(f"Missing required fields: {', '.join(missing_fields)}")

    return message 