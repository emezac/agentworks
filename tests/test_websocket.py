import asyncio
import websockets
import ssl

async def test_websocket():
    uri = "wss://localhost:8000/ws/test_agent"
    
    # Create an SSL context for the client
    ssl_context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile="scripts/ca-cert.pem")
    ssl_context.load_cert_chain(certfile="scripts/agente_py-cert.pem", keyfile="scripts/agente_py-key.pem")
    
    # Disable hostname verification (for testing purposes only)
    ssl_context.check_hostname = False

    try:
        async with websockets.connect(uri, ssl=ssl_context) as websocket:
            # Send a test message
            await websocket.send("Hello, server!")
            
            # Receive the response
            response = await websocket.recv()
            print(f"Received: {response}")
            
            # Assert the response is as expected
            assert response == "Echo: Hello, server!", "Unexpected response from server"
    
    except Exception as e:
        print(f"Test failed: {e}")

# Run the test
if __name__ == "__main__":
    asyncio.run(test_websocket()) 