How to Use:

Save the script: Save the code above into a file named generate_agent_cert.sh inside a scripts directory in your project.

Make it executable:

chmod +x scripts/generate_agent_cert.sh
Use code with caution.
Bash
Generate the CA first: Make sure you have run scripts/generate_ca.sh (or have your ca-key.pem, ca-cert.pem available) in the directory where you run this script.

Run for each agent: Execute the script from the directory containing the CA files, passing the desired agent ID as the argument:

# In the directory containing ca-key.pem and ca-cert.pem
./scripts/generate_agent_cert.sh agente_py
# Enter CA password when prompted
Use code with caution.
Bash
This will create agente_py-key.pem and agente_py-cert.pem.

./scripts/generate_agent_cert.sh agente_ruby
# Enter CA password when prompted
Use code with caution.
Bash
This will create agente_ruby-key.pem and agente_ruby-cert.pem.

Now you have the necessary unique credentials for each agent to participate in the mTLS authentication process.