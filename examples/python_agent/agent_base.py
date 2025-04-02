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

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import ssl
import uvicorn

app = FastAPI()

# SSL context setup
def create_ssl_context():
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    # Update these paths to the correct locations of your certificate and key files
    context.load_cert_chain(certfile="scripts/agente_py-cert.pem", keyfile="scripts/agente_py-key.pem")
    context.load_verify_locations(cafile="scripts/ca-cert.pem")
    context.verify_mode = ssl.CERT_REQUIRED
    return context

ssl_context = create_ssl_context()

@app.websocket("/ws/{agent_id}")
async def websocket_endpoint(websocket: WebSocket, agent_id: str):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            print(f"Received from {agent_id}: {data}")
            await websocket.send_text(f"Echo: {data}")
    except WebSocketDisconnect:
        print(f"Client {agent_id} disconnected")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 