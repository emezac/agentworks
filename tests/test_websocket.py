import asyncio
import websockets
import ssl

async def test_websocket():
    uri = "wss://localhost:8000/ws/test_agent"
    
    # Load SSL context for client
    ssl_context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
    ssl_context.load_cert_chain(certfile="scripts/agente_py-cert.pem", keyfile="scripts/agente_py-key.pem")
    ssl_context.load_verify_locations(cafile="scripts/ca-cert.pem")
    ssl_context.verify_mode = ssl.CERT_REQUIRED
    ssl_context.check_hostname = False  # Disable hostname verification for testing

    async with websockets.connect(uri, ssl=ssl_context) as websocket:
        message = "Hello, server!"
        await websocket.send(message)
        print(f"Sent: {message}")

        response = await websocket.recv()
        print(f"Received: {response}")

        assert response == f"Echo: {message}"

# Run the test
if __name__ == "__main__":
    asyncio.run(test_websocket()) 