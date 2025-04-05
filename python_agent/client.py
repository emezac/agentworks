# client_py.py
import asyncio
import websockets
import ssl
import pathlib
import logging

# Configuración de Logging
logging.basicConfig(level=logging.INFO, format='[%(levelname)s Client] %(message)s')

# --- Configuración de Rutas y SSL ---
SERVER_URL = "wss://localhost:8080/" # URL del servidor (usa localhost)
SCRIPT_DIR = pathlib.Path(__file__).parent

CERT_DIR = SCRIPT_DIR / "../scripts" # Asume que los certs están en 'scripts' relativo a este archivo

CLIENT_CERT = CERT_DIR / "agente_py-cert.pem"
CLIENT_KEY= CERT_DIR / "agente_py-key.pem"
CA_CERT = CERT_DIR / "ca-cert.pem"       

# Verificar existencia de archivos
for f in [CLIENT_CERT, CLIENT_KEY, CA_CERT]:
    if not f.is_file():
        logging.error(f"FATAL: Certificate file not found: {f}")
        exit(1)

logging.info("Setting up SSL context for mTLS...")
ssl_client_context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
try:
    # 1. Cargar el certificado y la clave del PROPIO cliente
    ssl_client_context.load_cert_chain(CLIENT_CERT, CLIENT_KEY)

    # 2. Cargar la CA que se usará para verificar el certificado del SERVIDOR
    ssl_client_context.load_verify_locations(cafile=CA_CERT)

    # 3. Requerir que el servidor sea verificado con nuestra CA
    ssl_client_context.verify_mode = ssl.CERT_REQUIRED

    # 4. ¡Importante! Habilitar la verificación del hostname
    ssl_client_context.check_hostname = True

    # Opcional: restringir versión TLS
    ssl_client_context.minimum_version = ssl.TLSVersion.TLSv1_2

    logging.info("SSL context configured successfully.")

except FileNotFoundError:
    logging.error("FATAL: One or more certificate/key files were not found during context setup.")
    exit(1)
except ssl.SSLError as e:
    logging.error(f"FATAL: SSL Error setting up context: {e}")
    exit(1)
except Exception as e:
    logging.error(f"FATAL: Unexpected error setting up context: {e}")
    exit(1)


# --- Función Principal del Cliente ---
async def connect_and_run():
    logging.info(f"Attempting to connect to {SERVER_URL}")
    try:
        # Usar 'async with' para conectar y asegurar el cierre
        # Pasamos la URL y el contexto SSL configurado
        async with websockets.connect(SERVER_URL, ssl=ssl_client_context) as websocket:
            logging.info("WebSocket connection OPENED successfully!")

            # Enviar mensaje
            message = f"Hello from Python client agente_py!"
            logging.info(f"Sending: {message}")
            await websocket.send(message)

            # Esperar y recibir eco
            logging.info("Waiting for echo...")
            response = await websocket.recv()
            logging.info(f"Received echo: {response}")

            if response == message:
                logging.info("Echo received successfully.")
            else:
                logging.warning("WARN: Echo mismatch!")

            logging.info("Test finished. Closing connection.")
            # El 'async with' cierra la conexión al salir del bloque

    except websockets.exceptions.InvalidStatusCode as e:
        # Ej: si el servidor responde 404 en lugar de 101
        logging.error(f"Handshake failed! Server returned HTTP status {e.status_code}")
    except websockets.exceptions.ConnectionClosed as e:
        logging.error(f"Connection closed unexpectedly: Code={e.code}, Reason='{e.reason}'")
    except ssl.SSLCertVerificationError as e:
        logging.error(f"SSL Certificate Verification Error: {e.reason} (Code: {e.verify_code}) - Check CA, cert SANs, and hostname!")
    except ConnectionRefusedError:
        logging.error("Connection refused. Is the server running and listening?")
    except ssl.SSLError as e:
        # Otros errores SSL durante la conexión/handshake
        logging.error(f"SSL Error during connection: {e}")
    except Exception as e:
        logging.error(f"An unexpected error occurred: {type(e).__name__} - {e}")


# --- Ejecutar el Cliente ---
if __name__ == "__main__":
    try:
        asyncio.run(connect_and_run())
    except KeyboardInterrupt:
        logging.info("Client stopped by user.")
