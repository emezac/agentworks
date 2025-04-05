#!/usr/bin/env python
# -*- coding: utf-8 -*-

# server_py.py - WebSocket Secure (WSS) Server with mTLS using asyncio and websockets

import asyncio
import websockets
import ssl
import pathlib
import logging
import sys # Para verificar la ruta

# --- 1. Configuración de Logging ---
log_format = '[%(asctime)s %(levelname)s %(filename)s:%(lineno)d Server] %(message)s'
logging.basicConfig(level=logging.INFO, format=log_format, datefmt='%Y-%m-%d %H:%M:%S')

# --- 2. Configuración de Rutas y SSL ---
SERVER_HOST = "0.0.0.0" # Escuchar en todas las interfaces
SERVER_PORT = 8080

try:
    SCRIPT_DIR = pathlib.Path(__file__).parent.resolve()
    CERT_DIR = SCRIPT_DIR / "../scripts"
    if not CERT_DIR.is_dir():
        CERT_DIR = pathlib.Path("../scripts").resolve() # Ajusta si server.py está en raíz
        if not CERT_DIR.is_dir():
            raise FileNotFoundError(f"Certificate directory 'scripts' not found relative to {SCRIPT_DIR} or current directory.")

    logging.info(f"Using certificate directory: {CERT_DIR}")

    # --- Nombres de archivo para el SERVIDOR ---
    SERVER_CERT_FILENAME = "acpaas_server-cert.pem" # <<< CORREGIDO
    SERVER_KEY_FILENAME = "acpaas_server-key.pem"   # <<< CORREGIDO
    CA_CERT_FILENAME = "ca-cert.pem"
    # -------------------------------------------

    SERVER_CERT = CERT_DIR / SERVER_CERT_FILENAME
    SERVER_KEY = CERT_DIR / SERVER_KEY_FILENAME
    CA_CERT = CERT_DIR / CA_CERT_FILENAME

    required_files = { "Server Cert": SERVER_CERT, "Server Key": SERVER_KEY, "CA Cert": CA_CERT }
    for name, f_path in required_files.items():
        if not f_path.is_file():
            raise FileNotFoundError(f"{name} file not found at: {f_path}")

    logging.info("All required certificate files found.")

except FileNotFoundError as e:
    logging.error(f"FATAL: Configuration error - {e}")
    sys.exit(1)
except Exception as e:
    logging.error(f"FATAL: Unexpected error during path configuration: {e}")
    sys.exit(1)


# --- 3. Configuración del Contexto SSL ---
logging.info("Setting up SSL context for mTLS...")
ssl_server_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
try:
    ssl_server_context.load_cert_chain(SERVER_CERT, SERVER_KEY)
    logging.info(f"Loaded server certificate: {SERVER_CERT}")
    logging.info(f"Loaded server key: {SERVER_KEY}")
    ssl_server_context.load_verify_locations(cafile=CA_CERT)
    logging.info(f"Loaded CA certificate for client verification: {CA_CERT}")
    ssl_server_context.verify_mode = ssl.CERT_REQUIRED
    logging.info("SSL verify_mode set to CERT_REQUIRED (mTLS enabled).")
    ssl_server_context.minimum_version = ssl.TLSVersion.TLSv1_2
    logging.info("SSL context configured successfully.")
except ssl.SSLError as e:
    logging.error(f"FATAL: SSL Error setting up context: {e}")
    sys.exit(1)
except Exception as e:
    logging.error(f"FATAL: Unexpected error setting up SSL context: {e}")
    sys.exit(1)


# --- 4. Handler para Conexiones WebSocket (Función Simple) ---
# Acepta websocket y path, como requiere la librería
async def connection_handler(websocket):
    """Maneja una conexión WebSocket entrante."""
    # Obtener el path desde la información de la conexión si está disponible
    path = getattr(websocket, 'path', '/')
    
    # Resto del código igual, usando la variable 'path' que acabamos de definir
    remote_addr = websocket.remote_address
    client_cn = "Unknown CN"
    handler_id = f"{remote_addr[0]}:{remote_addr[1]}"
   
    try:
        logging.info(f"[{handler_id}] Connection received for path: '{path}'") # Mostrar path
        # Obtener info del certificado de cliente
        try:
            ssl_object = websocket.transport.get_extra_info('ssl_object')
            if ssl_object:
                client_cert = ssl_object.getpeercert()
                if client_cert and 'subject' in client_cert:
                     subject_tuples = client_cert.get('subject', ())
                     cn_tuple = next((item for item in subject_tuples if item[0][0] == 'commonName'), None)
                     if cn_tuple:
                         client_cn = cn_tuple[0][1]
            else:
                logging.warning(f"[{handler_id}] Could not get ssl_object from transport.")
        except Exception as cert_e:
            logging.warning(f"[{handler_id}] Error getting client certificate details: {cert_e}")

        logging.info(f"[{handler_id}] WebSocket Connection opened. Client CN: '{client_cn}'")

        # Bucle de eco
        async for message in websocket:
            logging.info(f"[{handler_id}] Received from CN '{client_cn}': {message}")
            try:
                await websocket.send(message)
                logging.info(f"[{handler_id}] Echoed back to CN '{client_cn}'")
            except websockets.exceptions.ConnectionClosed:
                logging.warning(f"[{handler_id}] Tried to echo but connection closing for CN '{client_cn}'.")
                break
            except Exception as e:
                logging.error(f"[{handler_id}] Error sending echo to CN '{client_cn}': {e}")
                break

    except websockets.exceptions.ConnectionClosedOK:
        logging.info(f"[{handler_id}] Connection closed normally by CN '{client_cn}'.")
    except websockets.exceptions.ConnectionClosedError as e:
        logging.warning(f"[{handler_id}] Connection closed with error for CN '{client_cn}': Code={e.code}, Reason='{e.reason}'")
    except Exception as e:
        logging.error(f"[{handler_id}] Unexpected error in handler for CN '{client_cn}': {type(e).__name__} - {e}")
        logging.exception("Traceback for unexpected handler error:")
    finally:
        logging.info(f"[{handler_id}] Handler finished for CN '{client_cn}'.")


# --- 5. Iniciar el Servidor ---
async def main():
    logging.info(f"Starting WebSocket server on wss://{SERVER_HOST}:{SERVER_PORT}")
    stop_event = asyncio.Future()

    try:
        # Usar async with y pasar la función handler
        async with websockets.serve(
            connection_handler,
            SERVER_HOST,
            SERVER_PORT,
            ssl=ssl_server_context
        ) as server:
            # Mostrar la dirección real en la que está escuchando
            actual_addr = server.sockets[0].getsockname() if server.sockets else 'unknown socket'
            logging.info(f"Server listening on {actual_addr}")
            logging.info("Server is running. Press Ctrl+C to stop.")
            await stop_event

    except OSError as e:
        if "Address already in use" in str(e):
            logging.error(f"FATAL: Port {SERVER_PORT} is already in use.")
        else:
            logging.error(f"FATAL: OS Error starting server: {e}")
        sys.exit(1)
    except Exception as e:
        logging.error(f"FATAL: Unexpected error starting server: {type(e).__name__} - {e}")
        logging.exception("Traceback for server startup error:")
        sys.exit(1)
    # No hay 'finally' aquí porque el shutdown se maneja con KeyboardInterrupt

if __name__ == "__main__":
    logging.info(f"Executing script: {pathlib.Path(__file__).resolve()}")
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logging.info("\nCtrl+C received. Stopping server...")
    except Exception as e:
        logging.error(f"Application level error: {type(e).__name__} - {e}")
        logging.exception("Traceback for application error:")
    finally:
        logging.info("Server process finished.")