# BUGS.md - Resumen de Problemas y Diagnóstico de WebSockets mTLS en Ruby

**Fecha:** 2024-04-04
**Objetivo:** Implementar un cliente y servidor WebSocket en Ruby que se comuniquen de forma segura usando WebSockets Secure (WSS) con Autenticación Mutua TLS (mTLS) obligatoria, donde tanto cliente como servidor validan los certificados del otro contra una CA privada común.

---

## 1. Resumen General de Problemas Encontrados

Durante el desarrollo y las pruebas, se encontraron múltiples bugs, incompatibilidades o comportamientos inesperados en varias combinaciones populares de librerías Ruby para redes asíncronas y WebSockets al intentar implementar mTLS completo. Los principales stacks probados fueron:

1.  **Stack `async`:** (`async`, `async-http`, `async-websocket`, `async-io`)
    *   **Problemas:** Incompatibilidades de API entre versiones (`Async::IO::Stream`), fallo en la integración/mixin para añadir métodos WebSocket (`.websocket?`, `.upgrade`) al request HTTP, y un bug donde el middleware/servidor maneja exitosamente el handshake WS sobre mTLS pero no ejecuta el código de la aplicación/handler proporcionado.
2.  **Stack Puma + Faye:** (`puma`, `rack`, `faye-websocket-ruby`, `eventmachine`)
    *   **Problemas:** Incompatibilidad fundamental entre cómo Puma maneja los sockets SSL (`Puma::MiniSSL::Socket`) después de un hijack de Rack y cómo `faye-websocket-ruby`/`eventmachine` esperan recibir y adjuntar ese socket a su reactor. El adaptador `puma` de Faye no resolvió el problema.
3.  **Stack Puma/Faye (Server) + EM/Driver (Client):**
    *   **Problemas:** Se encontró un bug aparente en `EventMachine` donde la verificación del certificado del servidor con una CA personalizada (`ca_file`, `verify_peer: true`) falla, aunque `openssl s_client` verifica el mismo certificado correctamente. Además, al desactivar la verificación del servidor en el cliente, `EventMachine#send_data` fallaba al enviar la solicitud de handshake WebSocket después de un handshake TLS parcial.
4.  **Stack Puma/Driver (Server) + EM/Driver (Client):**
    *   **Problemas:** Aunque conceptualmente viable, la implementación del servidor con `websocket-driver` sobre Puma requirió workarounds (hijack manual, añadir método `write` dinámico) y se encontró con los mismos problemas del lado del cliente EventMachine al intentar enviar datos post-TLS.

**Conclusión General:** Implementar mTLS bidireccional robusto para WebSockets usando las versiones probadas de las librerías Ruby populares presentó obstáculos significativos, apuntando a bugs o problemas de integración en las propias librerías.

---

## 2. Registro Detallado de Pruebas y Conclusiones

### Intento 1: Stack `async` Completo (Server y Client)

*   **Configuración:**
    *   Server: `Async::HTTP::Server` con middleware `Async::WebSocket::Server` (y luego con lambda `app` manual), usando `Async::HTTP::Endpoint` con `ssl_context` para mTLS.
    *   Client: `Async::WebSocket::Client` usando `Async::HTTP::Endpoint` con `ssl_context` para mTLS.
    *   Gemas (versiones aproximadas): `async-http` (0.88.0, 0.87.0), `async-websocket` (0.30.0, 0.29.1), `async-io` (~1.43.2).
*   **Observaciones y Errores:**
    1.  `async-http 0.88.0`: Causó `NoMethodError: undefined method 'Stream' for module Async::IO`. Conclusión: Bug/incompatibilidad con `async-io`. (Solucionado temporalmente con monkey patch o degradando a 0.87.0).
    2.  Middleware `Async::WebSocket::Server` (v0.30.0/v0.29.1): Falló internamente con `NameError: uninitialized constant Async::WebSocket::Adapters`. Conclusión: Bug interno en el middleware.
    3.  Lambda `app` Manual (`request.websocket?`): Falló con `NoMethodError: undefined method 'websocket?'`. Conclusión: El mixin/parcheo de `async-websocket` sobre `async-http` para añadir métodos WS no funcionó en este contexto mTLS. `require` explícitos no ayudaron.
    4.  **Éxito Parcial (Último Intento con Lambda Manual + Hijack):** El cliente `async` conectó (mTLS OK, WS Handshake OK), pero el servidor `async`, después de aceptar la conexión y enviar la respuesta 101, **nunca ejecutó el código de la aplicación `app` lambda**. El bucle del servidor terminó prematuramente. Conclusión: Bug en `Async::HTTP::Server` o su integración con el hijack de WebSocket sobre mTLS; no delega la conexión secuestrada a la aplicación.
*   **Estado Final (Async):** Abandonado debido a múltiples bugs y problemas de integración irresolubles en las versiones probadas, principalmente el fallo en ejecutar el código de la aplicación después de un handshake mTLS/WS exitoso.

### Intento 2: Servidor Puma/Faye, Cliente Faye/EM

*   **Configuración:**
    *   Server: `puma` con `config/puma.rb` configurado para mTLS completo (bind `ssl://`, `verify_mode=peer`, `fail_if_no_peer_cert=true`, `key`, `cert`, `ca`). `config.ru` usando `require 'faye/websocket'`.
    *   Client: `faye-websocket-ruby` con `EventMachine`, pasando opciones `tls:` con `private_key_file`, `cert_chain_file`, `ca_file`, `verify_peer: true`.
    *   Gemas: `puma` (~6.6.0), `faye-websocket-ruby` (~0.11.3), `eventmachine` (~1.2.7).
*   **Observaciones y Errores:**
    1.  **Error Inicial Cliente:** `Unable to verify the server certificate for 'localhost'`. Conclusión: El certificado del servidor generado inicialmente carecía de SANs.
    2.  **Corrección:** Regenerado certificado del servidor con SANs `DNS:localhost,IP:127.0.0.1`. Verificado con `openssl s_client` que el handshake mTLS y la verificación de hostname funcionaban correctamente a nivel OpenSSL.
    3.  **Error Servidor Persistente:** Después de corregir el certificado, el servidor fallaba consistentemente con `TypeError: no implicit conversion of Puma::MiniSSL::Socket into Integer` al intentar adjuntar el socket SSL de Puma a EventMachine (`EM.attach`) dentro de Faye.
    4.  **Intento de Adaptador:** Añadir `Faye::WebSocket.load_adapter('puma')` en `config.ru` **no** resolvió el `TypeError`. Conclusión: El adaptador es ineficaz o tiene bugs en este escenario mTLS.
    5.  **Intento de Hijack Manual:** Modificar `config.ru` para hacer hijack manual (`env['rack.hijack'].call`) y obtener el `io = env['rack.hijack_io']` (que era `Puma::MiniSSL::Socket`).
    6.  **Error con Hijack Manual:** Intentar inicializar `Faye::WebSocket.new(env, nil, {socket: io})` falló con `WebSocket::Driver::ConfigurationError - Unrecognized option: :socket`. Conclusión: Faye no acepta un socket pre-secuestrado de esta manera.
*   **Estado Final (Puma/Faye Server):** Inutilizable para mTLS debido a la incompatibilidad entre el socket SSL de Puma y la expectativa de Faye/EventMachine para `EM.attach`.

### Intento 3: Servidor Puma/Faye, Cliente EM/websocket-driver

*   **Configuración:**
    *   Server: Puma/Faye como antes.
    *   Client: Reemplazado `faye-websocket-ruby` con `websocket-driver`, usando `EM.connect` y `start_tls` con opciones mTLS completas, más verificación manual de hostname.
*   **Observaciones y Errores:**
    1.  **Error Cliente (Verificación Servidor ON):** `certificate verify failed` durante `start_tls`. Conclusión: `EventMachine#start_tls` con `verify_peer: true` y `ca_file` personalizado no verifica correctamente el certificado del servidor (a diferencia de `openssl s_client`). Posible bug en EM.
    2.  **Prueba Cliente (Verificación Servidor OFF):** `verify_peer: false` en `start_tls`. El handshake TLS **tiene éxito**. El cliente inicializa `websocket-driver` y envía la solicitud de upgrade (`driver.start()` -> `write` -> `send_data`).
    3.  **Error Servidor:** El servidor (Puma/Faye) recibe la conexión TLS pero falla con el mismo `TypeError: no implicit conversion of Puma::MiniSSL::Socket into Integer` de antes. Conclusión: El problema del servidor persiste independientemente del cliente.
    4.  **Error Cliente (Escritura):** Se observó que con `verify_peer: false`, `EventMachine#send_data` solo lograba encolar 1 byte de la solicitud de handshake. Intentar con `write_nonblock` directamente falló porque no se pudo obtener el IO subyacente de la conexión EM/TLS. Conclusión: Posible bug adicional en EM al enviar datos sobre TLS con configuración mTLS parcial.
*   **Estado Final (EM/Driver Client):** Bloqueado por el bug de verificación del servidor en `EventMachine#start_tls` o por el bug de envío de datos post-TLS.

### Intento 4: Servidor Puma/websocket-driver, Cliente EM/websocket-driver

*   **Configuración:**
    *   Server: `config.ru` modificado para usar `websocket-driver` directamente, con hijack manual y añadiendo método `.write` al `Puma::MiniSSL::Socket`.
    *   Client: EM/websocket-driver (con `verify_peer: false` para la prueba).
*   **Observaciones y Errores:**
    1.  **Éxito Parcial Servidor:** El hijack funciona, se añade `.write` dinámicamente. El servidor inicializa el driver.
    2.  **Bloqueo:** El servidor se queda esperando (`read_nonblock` -> `IO::WaitReadable`) la solicitud inicial del cliente.
    3.  **Cliente:** Envía la solicitud de handshake.
    4.  **Estado Final:** El servidor nunca recibe los datos que el cliente envía. El problema parece estar en la capa de transporte/TLS de EventMachine (cliente) que no envía los datos después del TLS parcial, o en la capa de lectura del servidor que no los recibe del socket SSL de Puma.
*   **Estado Final (Puma/Driver Server):** Demasiado complejo y aún bloqueado por problemas de IO/TLS subyacentes, probablemente en el cliente EM.

---

## 3. Conclusiones Finales sobre las Librerías

*   **`async-http` / `async-websocket` (Versiones probadas):**
    *   Contiene bugs (`Async::IO::Stream` en 0.88.0).
    *   La integración para añadir automáticamente `.websocket?`/`.upgrade` al request HTTP no funciona de forma fiable en contexto mTLS.
    *   El middleware `Async::WebSocket::Server` o el servidor `Async::HTTP::Server` fallan al delegar/ejecutar el código de la aplicación después de un handshake mTLS/WebSocket exitoso. **(Bug Crítico)**
*   **`faye-websocket-ruby` / `EventMachine` (Servidor sobre Puma/SSL):**
    *   Incompatible con el manejo de sockets SSL de Puma (`Puma::MiniSSL::Socket`) después del hijack de Rack. El adaptador `puma` no resuelve el `TypeError` en `EM.attach`.
*   **`EventMachine` (Cliente mTLS):**
    *   `start_tls` parece tener un bug al verificar certificados de servidor con CAs personalizadas (`ca_file`, `verify_peer: true`), fallando donde `openssl s_client` tiene éxito.
    *   Parece tener un bug al enviar datos (`send_data`) después de un handshake TLS con opciones mTLS parciales (`verify_peer: false`, pero con cert/key de cliente).
*   **`websocket-driver`:** Funciona bien para el *protocolo*, pero depende completamente de la capa de transporte/TLS subyacente (EM o Async IO), heredando sus problemas.
*   **Puma (Servidor mTLS):** Configura y maneja mTLS correctamente a nivel de aceptación de conexión y verificación de cliente. El problema surge al interactuar con librerías WebSocket que usan EM o tienen problemas con su manejo de IO SSL.

---

## 4. Recomendaciones para Parches / Próximos Pasos

Para lograr una solución robusta de mTLS WebSocket en Ruby con estas librerías, se requerirían correcciones en las gemas originales:

1.  **En `async-http` / `async-websocket`:**
    *   **Corregir el Bug `Async::IO::Stream`:** Asegurarse de que `async-http` use la API correcta de `async-io` (probablemente `Async::IO::Generic`). (Puede que ya esté arreglado en > 0.88.0 si existe).
    *   **Investigar y Corregir la Integración/Mixin:** ¿Por qué `.websocket?` y `.upgrade` no se añaden fiablemente al objeto `request` en todos los contextos, especialmente mTLS? Asegurar que el `require 'async/websocket'` configure `async-http` correctamente.
    *   **Corregir la Delegación Post-Handshake:** El problema más crítico. `Async::HTTP::Server` o `Async::WebSocket::Server` debe asegurar que después de un handshake mTLS/WS exitoso, el socket/conexión secuestrado se pase correctamente al bloque de aplicación/handler proporcionado y que esa tarea se mantenga viva. Investigar el ciclo de vida de la tarea de conexión.

2.  **En `faye-websocket-ruby` / `EM` (para uso con Puma/SSL):**
    *   **Mejorar/Corregir el Adaptador Puma:** El adaptador necesita extraer correctamente el descriptor de archivo numérico del `Puma::MiniSSL::Socket` para poder usar `EM.attach`.
    *   **Alternativa:** Faye podría intentar usar el `io` directamente si se pasa vía hijack (como intentamos con `:socket`), pero necesitaría manejar `Puma::MiniSSL::Socket` internamente sin depender de `EM.attach` si el adaptador no funciona.

3.  **En `EventMachine` (Cliente):**
    *   **Investigar `start_tls` con `verify_peer: true` y `ca_file`:** ¿Por qué falla la verificación donde `openssl s_client` tiene éxito? ¿Es un problema de cómo se configura el `SSLContext` subyacente o de la lógica de verificación de hostname?
    *   **Investigar `send_data` post-TLS (mTLS parcial):** ¿Por qué `send_data` parece fallar o bloquearse después de enviar 1 byte cuando `verify_peer: false` pero se proporcionan certificados de cliente?

**Solución Alternativa Recomendada (Workaround):**

Dada la complejidad y el número de problemas encontrados, la solución más pragmática y robusta actualmente es usar un **Proxy Inverso (Nginx)** delante del servidor Ruby:

1.  **Nginx:** Configurado para manejar todo el mTLS (terminar SSL, presentar certificado de servidor con SANs, requerir y verificar certificado de cliente con la CA).
2.  **Proxy Pass:** Nginx reenvía la conexión validada como **WebSocket plano (`ws://`)** a la aplicación Ruby.
3.  **Aplicación Ruby:** Se simplifica enormemente. Puede usar Puma + Faye (o incluso Async) escuchando en `ws://` en un puerto interno, sin necesidad de manejar TLS/mTLS directamente.

Este enfoque desacopla la complejidad de mTLS de la aplicación WebSocket, usando herramientas especializadas (Nginx) para la seguridad.

---