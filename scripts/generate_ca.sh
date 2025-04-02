#!/bin/bash

# This script generates a Certificate Authority (CA) key and certificate.

# Set default values for the key and certificate filenames
CA_KEY="ca-key.pem"
CA_CERT="ca-cert.pem"

# Prompt for the CA's distinguished name details
echo "Generating CA key and certificate..."
echo "Please enter the following details for the CA certificate:"
read -p "Country Name (2 letter code) [US]: " COUNTRY
read -p "State or Province Name (full name) [California]: " STATE
read -p "Locality Name (eg, city) [San Francisco]: " LOCALITY
read -p "Organization Name (eg, company) [My Company]: " ORGANIZATION
read -p "Organizational Unit Name (eg, section) [IT]: " ORG_UNIT
read -p "Common Name (e.g. server FQDN or YOUR name) [My CA]: " COMMON_NAME
read -p "Email Address [admin@example.com]: " EMAIL

# Generate the CA key
openssl genrsa -out $CA_KEY 2048

# Generate the CA certificate
openssl req -x509 -new -nodes -key $CA_KEY -sha256 -days 3650 -out $CA_CERT \
  -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

echo "CA key and certificate have been generated:"
echo "  Key: $CA_KEY"
echo "  Certificate: $CA_CERT" 