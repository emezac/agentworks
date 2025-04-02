# ACPaaS Authentication Setup: Mutual TLS (mTLS)

**Version:** 1.0
**Date:** 2023-11-16

---

## 1. Overview

All communication within the Agent Coordination Protocol SaaS (ACPaaS) environment **MUST** be secured using **Mutual TLS (mTLS)**. This ensures that:

1. **Confidentiality:** Communication is encrypted over the WSS connection.
2. **Server Authentication:** Agents verify the identity of the server or peer they are connecting to.
3. **Client Authentication:** The server or peer verifies the identity of the connecting agent.

This bidirectional authentication provides a strong security foundation, preventing unauthorized agents from connecting or intercepting communication.

## 2. Core Concepts

* **Certificate Authority (CA):** A central trusted entity that issues and signs digital certificates. For ACPaaS, you will create your own **private CA**. This CA will be the root of trust for all agents within your environment.
* **Agent Certificates:** Each individual agent instance requires its own unique **X.509 certificate** and corresponding **private key**. This certificate acts as the agent's digital identity and MUST be signed by your private CA.
* **Certificate Chain:** When an agent presents its certificate, the receiving party verifies it by checking if it was signed by a trusted CA (in this case, your private CA).

## 3. Prerequisites

* **OpenSSL:** You need the OpenSSL command-line tool installed on the machine where you will generate the certificates. You can typically check your installation by running:

    ```bash
    openssl version
    ```

## 4. Certificate Generation Steps

The following steps use the provided helper scripts (`scripts/generate_ca.sh` and `scripts/generate_agent_cert.sh`) to simplify the process.

### Step 1: Generate CA Key and Certificate

Use the `generate_ca.sh` script to create a CA key and certificate. This CA will be used to sign agent certificates.

```bash
# Navigate to the scripts directory
cd scripts

# Run the script to generate CA key and certificate
./generate_ca.sh
```

Follow the prompts to enter the necessary details for the CA certificate. The generated files will be `ca-key.pem` and `ca-cert.pem`.

### Step 2: Generate Agent Certificates

Use the `generate_agent_cert.sh` script in the `scripts` directory to generate individual agent certificates. This script will require the CA key and certificate generated in Step 1.

```bash
# Example: Generate certs for 'agente_py'
./generate_agent_cert.sh agente_py
# Enter CA password when prompted
```

Ensure the generated `ca-cert.pem` and the specific `<agent_id>-key.pem` & `<agent_id>-cert.pem` files are accessible to the agents/backend at runtime.

## 5. File Placement and Usage

For an agent (e.g., `agente_py`) to successfully connect using mTLS, it needs access to the following files at runtime:

1. **Its own private key:** `agente_py-key.pem`
2. **Its own public certificate:** `agente_py-cert.pem`
3. **The CA's public certificate:** `ca-cert.pem` (Needed to verify certificates presented by *other* agents or the server).

These file paths will typically be provided to the agent's configuration (e.g., via command-line arguments, environment variables, or a configuration file) so the WSS client/server library can load them to set up the SSL/TLS context.

## 6. Security Considerations

* **CA Private Key (`ca-key.pem`):** This is the most critical file. Store it offline or in a highly secured location (like a hardware security module or managed secrets service if available). Limit access strictly to personnel authorized to issue new agent certificates. **Compromise of this key invalidates the entire system's trust.**
* **Agent Private Keys (`<agent_name>-key.pem`):** These keys must be protected on the systems where the agents run. Use appropriate file permissions (readable only by the user/service running the agent). Do not commit these keys to version control. Consider using environment variables or secrets management tools to inject key paths or content at runtime.
* **Certificate Validity:** The generated certificates have a default validity period (e.g., 365 days). Plan for certificate rotation before they expire.

## 7. Verification (Optional)

You can verify that an agent certificate was correctly signed by your CA using OpenSSL:

```bash
# Example: Verify agente_py's certificate against the CA
openssl verify -CAfile ca-cert.pem agente_py-cert.pem

# Expected output if successful:
# agente_py-cert.pem: OK
Use code with caution.
Markdown
You can also inspect the contents of a certificate:

# Example: View details of agente_py's certificate
openssl x509 -in agente_py-cert.pem -noout -text
Hyper Icon
