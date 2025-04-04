from fastapi import FastAPI, WebSocket, WebSocketDisconnect
import ssl
import os

app = FastAPI()

# Load SSL context for WSS
ssl_context = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
ssl_context.load_cert_chain(certfile="scripts/agente_py-cert.pem", keyfile="scripts/agente_py-key.pem")
ssl_context.load_verify_locations(cafile="scripts/ca-cert.pem")
ssl_context.verify_mode = ssl.CERT_REQUIRED

@app.get("/")
async def read_root():
    return {"Hello": "World"}

@app.websocket("/ws/{agent_id}")
async def websocket_endpoint(websocket: WebSocket, agent_id: str):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            print(f"Received message from {agent_id}: {data}")
            await websocket.send_text(f"Echo: {data}")
    except WebSocketDisconnect:
        print(f"Client {agent_id} disconnected") 