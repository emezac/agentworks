# BUGS.md - Summary of Issues and Diagnostics for Ruby WebSocket mTLS

**Date:** 2024-04-04
**Objective:** To implement a WebSocket client and server in Ruby communicating securely using WebSockets Secure (WSS) with mandatory Mutual TLS (mTLS), where both client and server validate each other's certificates against a common private CA.

---

## 1. General Summary of Issues Encountered

During development and testing, multiple bugs, incompatibilities, or unexpected behaviors were encountered across various popular combinations of Ruby libraries for asynchronous networking and WebSockets when attempting to implement full mTLS. The primary stacks tested were:

1.  **`async` Stack:** (`async`, `async-http`, `async-websocket`, `async-io`)
    *   **Problems:** API incompatibilities between versions (`Async::IO::Stream` error), failure in integration/mixin mechanism to add necessary WebSocket methods (`.websocket?`, `.upgrade`) to the HTTP request object, and a critical bug where the middleware/server successfully handles the WS handshake over mTLS but fails to execute the provided application/handler code for the established connection.
2.  **Puma + Faye Stack:** (`puma`, `rack`, `faye-websocket-ruby`, `eventmachine`)
    *   **Problems:** Fundamental incompatibility between how Puma handles SSL sockets (`Puma::MiniSSL::Socket`) after a Rack hijack and how `faye-websocket-ruby`/`eventmachine` expect to receive and attach that socket to their reactor (`TypeError` on `EM.attach`). The Faye Puma adapter did not resolve this.
3.  **Puma/Faye (Server) + EM/Driver (Client) Stack:**
    *   **Problems:** An apparent bug was found in `EventMachine`'s client-side TLS implementation (`start_tls`) where server certificate verification fails when using a custom CA (`ca_file`, `verify_peer: true`), despite `openssl s_client` successfully verifying the same setup. Furthermore, when server verification was disabled on the client, `EventMachine#send_data` failed to correctly send the WebSocket handshake request data after the partial mTLS handshake completed.
4.  **Puma/Driver (Server) + EM/Driver (Client) Stack:**
    *   **Problems:** While conceptually viable, the server implementation required significant workarounds (manual hijack, dynamic `.write` method injection). It ultimately remained blocked by the client-side EventMachine issues related to sending data post-TLS.

**Overall Conclusion:** Implementing robust, bidirectional mTLS for WebSockets using the tested versions of popular Ruby libraries presented significant obstacles, pointing towards bugs or integration issues within the libraries themselves.

---

## 2. Detailed Log of Tests and Conclusions

### Attempt 1: Full `async` Stack (Server and Client)

*   **Configuration:**
    *   Server: `Async::HTTP::Server` with `Async::WebSocket::Server` middleware (and later with a manual `app` lambda), using `Async::HTTP::Endpoint` with `ssl_context` for mTLS.
    *   Client: `Async::WebSocket::Client` using `Async::HTTP::Endpoint` with `ssl_context` for mTLS.
    *   Gems (approx. versions): `async-http` (0.88.0, 0.87.0), `async-websocket` (0.30.0, 0.29.1), `async-io` (~1.43.2).
*   **Observations and Errors:**
    1.  `async-http 0.88.0`: Caused `NoMethodError: undefined method 'Stream' for module Async::IO`. Conclusion: Bug/incompatibility with the current `async-io` version. (Temporarily worked around with a monkey patch or by downgrading to 0.87.0).
    2.  `Async::WebSocket::Server` Middleware (v0.30.0/v0.29.1): Failed internally with `NameError: uninitialized constant Async::WebSocket::Adapters`. Conclusion: Internal bug in the middleware.
    3.  Manual `app` Lambda (`request.websocket?` approach): Failed with `NoMethodError: undefined method 'websocket?'`. Conclusion: The mixin/patching mechanism of `async-websocket` onto `async-http`'s request object did not function correctly in this mTLS context. Explicit `require` statements did not resolve this.
    4.  **Partial Success (Final Attempt with Manual Lambda + Hijack):** The `async` client connected successfully (mTLS OK, WS Handshake OK). However, the `async` server, after accepting the connection and sending the 101 Switching Protocols response, **never executed the `app` lambda code**. The main server loop terminated prematurely. Conclusion: Bug in `Async::HTTP::Server` or its integration with WebSocket hijacking over mTLS; it fails to delegate the hijacked connection/socket to the application code.
*   **Final Status (Async):** Abandoned due to multiple unresolved bugs and integration issues in the tested versions, primarily the failure to execute application code after a successful mTLS/WS handshake.

### Attempt 2: Puma/Faye Server, Faye/EM Client

*   **Configuration:**
    *   Server: `puma` with `config/puma.rb` configured for full mTLS (bind `ssl://`, `verify_mode=peer`, `fail_if_no_peer_cert=true`, `key`, `cert`, `ca`). `config.ru` using `require 'faye/websocket'`.
    *   Client: `faye-websocket-ruby` with `EventMachine`, passing `tls:` options including `private_key_file`, `cert_chain_file`, `ca_file`, `verify_peer: true`.
    *   Gems: `puma` (~6.6.0), `faye-websocket-ruby` (~0.11.3), `eventmachine` (~1.2.7).
*   **Observations and Errors:**
    1.  **Initial Client Error:** `Unable to verify the server certificate for 'localhost'`. Conclusion: The initially generated server certificate lacked necessary Subject Alternative Names (SANs).
    2.  **Correction:** Regenerated server certificate with `DNS:localhost,IP:127.0.0.1` SANs. Verified successful mTLS handshake and hostname verification using `openssl s_client`.
    3.  **Persistent Server Error:** After fixing the certificate, the server consistently failed with `TypeError: no implicit conversion of Puma::MiniSSL::Socket into Integer` when Faye attempted to attach Puma's SSL socket to the EventMachine reactor (`EM.attach`).
    4.  **Adapter Attempt:** Adding `Faye::WebSocket.load_adapter('puma')` in `config.ru` did **not** resolve the `TypeError`. Conclusion: The adapter is ineffective or buggy in this mTLS scenario.
    5.  **Manual Hijack Attempt:** Modified `config.ru` to manually perform the Rack hijack (`env['rack.hijack'].call`) and obtain the underlying IO object (`io = env['rack.hijack_io']`, which was `Puma::MiniSSL::Socket`).
    6.  **Error with Manual Hijack:** Attempting to initialize `Faye::WebSocket.new(env, nil, {socket: io})` failed with `WebSocket::Driver::ConfigurationError - Unrecognized option: :socket`. Conclusion: Faye does not support initialization with a pre-hijacked socket via this option.
*   **Final Status (Puma/Faye Server):** Unusable for mTLS due to the incompatibility between Puma's SSL socket handling post-hijack and Faye/EventMachine's expectations for `EM.attach`.

### Attempt 3: Puma/Faye Server, EM/websocket-driver Client

*   **Configuration:**
    *   Server: Puma/Faye as before.
    *   Client: Replaced `faye-websocket-ruby` client with `websocket-driver`, using `EM.connect` and `start_tls` with full mTLS options, plus manual hostname verification post-TLS handshake.
*   **Observations and Errors:**
    1.  **Client Error (Server Verification ON):** `certificate verify failed` occurred during `start_tls`. Conclusion: `EventMachine#start_tls` with `verify_peer: true` and a custom `ca_file` does not correctly verify the server certificate in this setup (unlike `openssl s_client`). Likely EventMachine bug.
    2.  **Client Test (Server Verification OFF):** Setting `verify_peer: false` in `start_tls`. The TLS handshake **succeeded**. The client initialized `websocket-driver` and attempted to send the upgrade request (`driver.start()` -> `write` -> `send_data`).
    3.  **Server Error:** The Puma/Faye server still failed with the same `TypeError: no implicit conversion of Puma::MiniSSL::Socket into Integer`. Conclusion: The server-side problem persists regardless of the client library used.
    4.  **Client Error (Write Failure):** With `verify_peer: false`, `EventMachine#send_data` only reported queuing 1 byte of the handshake request. Attempting direct `write_nonblock` failed due to inability to access the underlying IO object post-`start_tls`. Conclusion: Potential additional EventMachine bug related to sending data over TLS after a partial mTLS setup (`verify_peer: false` with client certs provided).
*   **Final Status (EM/Driver Client):** Blocked by the apparent server verification bug in `EventMachine#start_tls` or the subsequent data sending bug.

### Attempt 4: Puma/websocket-driver Server, EM/websocket-driver Client

*   **Configuration:**
    *   Server: `config.ru` modified to use `websocket-driver` directly, performing manual hijack and dynamically adding a `.write` method to the `Puma::MiniSSL::Socket`.
    *   Client: EM/websocket-driver (with `verify_peer: false` for testing).
*   **Observations and Errors:**
    1.  **Partial Server Success:** Hijack worked, `.write` method added, driver initialized.
    2.  **Deadlock:** Server blocked waiting for the initial client request (`read_nonblock` -> `IO::WaitReadable`). Client successfully completed TLS handshake, initialized its driver, and *sent* the handshake request (calling `send_data`).
    3.  **Final State:** The server never received the data sent by the client after the TLS handshake. The breakdown occurs in the transport layer after `start_tls` (client) or during the read from the `Puma::MiniSSL::Socket` (server).
*   **Final Status (Puma/Driver Server):** While conceptually closer, still blocked by underlying IO/TLS transport issues, likely originating from the EventMachine client's inability to reliably send data post-TLS in this configuration.

---

## 3. Final Library Conclusions

*   **`async-http` / `async-websocket` (Tested Versions):**
    *   Contains bugs (`Async::IO::Stream` in 0.88.0).
    *   Integration/mixin mechanism to add `.websocket?`/`.upgrade` to HTTP requests appears unreliable in mTLS contexts.
    *   Critical bug exists where `Async::WebSocket::Server` middleware or `Async::HTTP::Server` fails to delegate the connection to the application handler after a successful mTLS/WebSocket handshake.
*   **`faye-websocket-ruby` / `EventMachine` (Server on Puma/SSL):**
    *   Incompatible with Puma's `Puma::MiniSSL::Socket` handling after Rack hijack when using SSL. The Faye Puma adapter does not resolve the `TypeError` in `EM.attach`.
*   **`EventMachine` (Client mTLS):**
    *   Appears to have a bug in `start_tls` preventing successful server certificate verification with custom CAs (`ca_file`, `verify_peer: true`), contradicting `openssl s_client` results.
    *   Appears to have a bug preventing reliable data transmission (`send_data`) after a TLS handshake with client certificates provided but `verify_peer: false`.
*   **`websocket-driver`:** Functions correctly at the protocol level but is entirely dependent on the underlying transport/TLS layer (EventMachine or Async IO), inheriting its issues.
*   **Puma (Server mTLS):** Correctly configures and handles the server-side mTLS handshake, including client certificate verification. The problems arise when integrating with WebSocket libraries that struggle with its post-hijack SSL socket object or when the client itself fails during TLS.

---

## 4. Recommendations for Patches / Next Steps

To achieve a robust Ruby mTLS WebSocket solution with these libraries, fixes in the original gems are likely required:

1.  **For `async-http` / `async-websocket`:**
    *   **Fix `Async::IO::Stream` Bug:** Ensure `async-http` uses the correct `async-io` API (likely `Async::IO::Generic`). (May already be fixed in versions > 0.88.0, if they exist).
    *   **Investigate/Fix Integration/Mixin:** Determine why `.websocket?` and `.upgrade` are not reliably added to the `request` object in all contexts, especially mTLS. Ensure `require 'async/websocket'` correctly configures `async-http`.
    *   **Fix Post-Handshake Delegation:** **(Critical Bug)** `Async::HTTP::Server` or `Async::WebSocket::Server` must ensure that after a successful mTLS/WS handshake, the hijacked socket/connection is correctly passed to the provided application block/handler, and that the corresponding task remains active. Investigate the connection task lifecycle.

2.  **For `faye-websocket-ruby` / `EM` (Server usage with Puma/SSL):**
    *   **Improve/Fix Puma Adapter:** The adapter needs to correctly extract the underlying file descriptor from `Puma::MiniSSL::Socket` for use with `EM.attach`.
    *   **Alternative:** Faye could potentially be modified to directly use the IO object passed via hijack (e.g., via a `:socket` option, which currently fails) by handling `Puma::MiniSSL::Socket` internally without relying on `EM.attach`.

3.  **For `EventMachine` (Client):**
    *   **Investigate `start_tls` Verification Failure:** Determine why server verification fails with `verify_peer: true` and custom `ca_file` when `openssl s_client` succeeds. Is it an issue with `SSLContext` setup, hostname verification logic, or platform interaction?
    *   **Investigate `send_data` Failure Post-TLS (Partial mTLS):** Determine why `send_data` fails to transmit data correctly after `start_tls` completes with client certificates but `verify_peer: false`.

**Recommended Alternative Solution (Workaround):**

Given the complexity and number of issues encountered across multiple stacks, the most pragmatic and robust solution currently is to use a **Reverse Proxy (e.g., Nginx, HAProxy)** in front of the Ruby server:

1.  **Nginx/HAProxy:** Configure the proxy to handle **all** mTLS aspects: terminate the incoming WSS connection, present the server certificate (with correct SANs), require and verify the client certificate against the private CA.
2.  **Proxy Pass:** If mTLS succeeds, the proxy forwards the connection to the backend Ruby application as **plain WebSocket (`ws://`)** over a local/internal network connection (e.g., to `localhost:8081`).
3.  **Ruby Application:** The Ruby application (Puma + Faye, or potentially even Async now) becomes much simpler. It listens on a non-SSL `ws://` port and only needs to handle the WebSocket protocol logic, as security is managed by the proxy.

This approach decouples the complex mTLS handling from the WebSocket application logic, leveraging specialized and highly reliable tools (Nginx/HAProxy) for the security layer.