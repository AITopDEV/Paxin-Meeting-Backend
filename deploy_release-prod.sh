#!/bin/sh

SERVICE_PATH="~/workspace/paxintrade/mainsite/backend"
SERVICE_NAME="paxintrade-api"

# Abort on errors
set -e

# Prepare the private key from an environment variable
PRIVATE_KEY_PATH="$(mktemp)"
# Extract the header
HEADER=$(echo "$SSH_PRIVATE_KEY" | grep -o -e "-----BEGIN [^-]* PRIVATE KEY-----")
# Extract the footer
FOOTER=$(echo "$SSH_PRIVATE_KEY" | grep -o -e "-----END [^-]* PRIVATE KEY-----")
# Remove the header and footer to isolate the body
BODY=$(echo "$SSH_PRIVATE_KEY" | sed -e "s/$HEADER//" | sed -e "s/$FOOTER//")
# Format the body of the key: Insert a newline every 64 characters
FORMATTED_BODY=$(echo "$BODY" | fold -w 64)
# Combine the formatted parts into one key, adding newlines after header and before footer
FORMATTED_KEY="$HEADER\n$FORMATTED_BODY\n$FOOTER"
# Print the key to key file
echo -e "$FORMATTED_KEY" > "$PRIVATE_KEY_PATH"
# Set 600 permission to private key file
chmod 600 "$PRIVATE_KEY_PATH"

# SSH into the EC2 instance
ssh -t -o StrictHostKeyChecking=no -i "$PRIVATE_KEY_PATH" "$HOST_ADDRESS" << EOF
  SERVICE_PATH='${SERVICE_PATH}'
  SERVICE_NAME='${SERVICE_NAME}'
  source ~/.bashrc
  ecr_login.sh
  cd \$SERVICE_PATH
  git restore .
  git pull
  docker compose stop \$SERVICE_NAME || { echo "Failed to stop \$SERVICE_NAME"; exit 1; }
  docker compose pull \$SERVICE_NAME || { echo "Failed to pull \$SERVICE_NAME"; exit 1; }
  docker compose up -d || { echo "Failed to start services with Docker Compose."; exit 1; }

  echo "Docker Compose started successfully. Checking if the \$SERVICE_NAME service is running..."
  sleep 5

  if ! docker compose top \$SERVICE_NAME; then
    echo "Failed to confirm that \$SERVICE_NAME service is running. Please check logs."
    exit 1
  else
    echo "\$SERVICE_NAME service is up and running."
  fi
EOF

# Clean up the private key
rm "$PRIVATE_KEY_PATH"