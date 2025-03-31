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