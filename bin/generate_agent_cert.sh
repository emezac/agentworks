#!/bin/bash

# Script to generate an agent's private key and a certificate signed by the local CA.
# Usage: ./generate_agent_cert.sh <agent_id>
# Example: ./generate_agent_cert.sh agente_py
# Example: ./generate_agent_cert.sh agente_ruby

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# Certificate validity period in days
CERT_VALIDITY_DAYS=365
# Default Subject fields (Customize as needed)
COUNTRY="XX"
STATE="State"
LOCALITY="City"
ORG_NAME="MyOrg"
ORG_UNIT="Agents"
# --- End Configuration ---

# --- Check Input ---
if [ -z "$1" ]; then
  echo "Error: No agent ID provided."
  echo "Usage: $0 <agent_id>"
  exit 1
fi
AGENT_ID="$1"
echo "--- Generating certificate for Agent ID: ${AGENT_ID} ---"

# --- Define Filenames ---
AGENT_KEY="${AGENT_ID}-key.pem"
AGENT_CSR="${AGENT_ID}-csr.pem"
AGENT_CERT="${AGENT_ID}-cert.pem"
CA_KEY="ca-key.pem"
CA_CERT="ca-cert.pem"
CA_SERIAL="ca-cert.srl" # Serial number file

# --- Check Prerequisites ---
if [ ! -f "${CA_KEY}" ]; then
  echo "Error: CA private key '${CA_KEY}' not found."
  echo "Please generate the CA first using generate_ca.sh."
  exit 1
fi
if [ ! -f "${CA_CERT}" ]; then
  echo "Error: CA certificate '${CA_CERT}' not found."
  echo "Please generate the CA first using generate_ca.sh."
  exit 1
fi
echo "--> Found CA key and certificate."

# --- Step 1: Generate Agent Private Key ---
if [ -f "${AGENT_KEY}" ]; then
  echo "--> Warning: Agent key file '${AGENT_KEY}' already exists. Overwriting."
fi
echo "--> Generating private key for agent '${AGENT_ID}' (${AGENT_KEY})..."
openssl genpkey -algorithm RSA -out "${AGENT_KEY}"
if [ $? -ne 0 ]; then echo "Error generating agent key."; exit 1; fi
echo "    Private key generated."

# --- Step 2: Generate Certificate Signing Request (CSR) ---
if [ -f "${AGENT_CSR}" ]; then
  echo "--> Warning: Agent CSR file '${AGENT_CSR}' already exists. Overwriting."
fi
echo "--> Generating CSR for agent '${AGENT_ID}' (${AGENT_CSR})..."
# Construct the subject line. The Common Name (CN) MUST match the agent ID.
AGENT_SUBJ="/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORG_NAME}/OU=${ORG_UNIT}/CN=${AGENT_ID}"
openssl req -new -key "${AGENT_KEY}" -sha256 -out "${AGENT_CSR}" -subj "${AGENT_SUBJ}"
if [ $? -ne 0 ]; then echo "Error generating CSR."; exit 1; fi
echo "    CSR generated with subject: ${AGENT_SUBJ}"

# --- Step 3: Sign the CSR with the CA ---
# This step will prompt for the CA private key password.
if [ -f "${AGENT_CERT}" ]; then
  echo "--> Warning: Agent certificate file '${AGENT_CERT}' already exists. Overwriting."
fi
echo "--> Signing CSR with CA to create agent certificate (${AGENT_CERT})..."
echo "    (You will be prompted for the CA private key password)"
openssl x509 -req -days ${CERT_VALIDITY_DAYS} \
    -in "${AGENT_CSR}" \
    -CA "${CA_CERT}" \
    -CAkey "${CA_KEY}" \
    -CAserial "${CA_SERIAL}" \
    -CAcreateserial \
    -out "${AGENT_CERT}" -sha256
# Note: -CAcreateserial will create the .srl file if it doesn't exist.
# If it exists, -CAserial ${CA_SERIAL} will use and increment it.

if [ $? -ne 0 ]; then echo "Error signing CSR."; exit 1; fi
echo "    Certificate signed successfully."

# --- Step 4: Cleanup CSR (Optional) ---
echo "--> Cleaning up CSR file (${AGENT_CSR})..."
# rm "${AGENT_CSR}" # Uncomment this line if you want to automatically remove the CSR file

# --- Done ---
echo "---"
echo "Success! Generated files for agent '${AGENT_ID}':"
echo "  Private Key:  ${AGENT_KEY}"
echo "  Certificate:  ${AGENT_CERT}"
echo "---"
echo "IMPORTANT: Protect the private key file ('${AGENT_KEY}')!"
echo "           The agent will need access to '${AGENT_KEY}', '${AGENT_CERT}', and '${CA_CERT}' to authenticate."
echo "---"

exit 0