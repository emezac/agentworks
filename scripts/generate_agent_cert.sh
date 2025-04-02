#!/bin/bash

# This script generates a private key, CSR, and signed certificate for an agent.

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <agent_name>"
    exit 1
fi

AGENT_NAME=$1
AGENT_KEY="${AGENT_NAME}-key.pem"
AGENT_CSR="${AGENT_NAME}-csr.pem"
AGENT_CERT="${AGENT_NAME}-cert.pem"
CA_KEY="ca-key.pem"
CA_CERT="ca-cert.pem"

# Check if CA files exist
if [ ! -f "$CA_KEY" ] || [ ! -f "$CA_CERT" ]; then
    echo "CA key or certificate not found. Please ensure $CA_KEY and $CA_CERT are in the current directory."
    exit 1
fi

# Generate the agent's private key
openssl genrsa -out $AGENT_KEY 2048

# Generate the CSR
openssl req -new -key $AGENT_KEY -out $AGENT_CSR -subj "/CN=$AGENT_NAME"

# Sign the CSR with the CA to create the agent's certificate
openssl x509 -req -in $AGENT_CSR -CA $CA_CERT -CAkey $CA_KEY -CAcreateserial -out $AGENT_CERT -days 365 -sha256

echo "Agent key, CSR, and certificate have been generated:"
echo "  Key: $AGENT_KEY"
echo "  CSR: $AGENT_CSR"
echo "  Certificate: $AGENT_CERT" 