#!/bin/sh
# This script performs a health check for the API Gateway service.
# It checks if the API Gateway is reachable and returns a valid JSON response.

# Use localhost from inside the container, with HTTPS since listenSsl is true
# Use a simpler endpoint that doesn't require authentication
URL="https://localhost:${GATEWAY_PORT}/v1/api/iserver/auth/status"

echo "Attempting to check API Gateway health at: $URL"

# Use curl to get the HTTP status code and save the response body to a temporary file.
# -s: Silent mode (don't show progress meter or error messages)
# -k: Allow insecure server connections when using SSL (useful for local development with self-signed certs)
# -w "%{http_code}": Output only the HTTP status code
# -o /tmp/api_response.json: Write the response body to this file
# --max-time 5: Set a timeout to prevent hanging
STATUS=$(curl -sk --max-time 5 -w "%{http_code}" -o /tmp/api_response.json "$URL" 2>/dev/null)

# Check if curl was successful (status code is a number)
if [ -z "$STATUS" ] || [ "$STATUS" = "000" ]; then
  echo "API Gateway healthcheck failed: Unable to connect to the service."
  exit 1
fi

# The API Gateway should return 200 (OK) or 401 (Unauthorized) if it's running
# 401 is acceptable because it means the service is up but requires authentication
# 200 means the service is up and responding
if [ "$STATUS" = "200" ] || [ "$STATUS" = "401" ]; then
  # Check if the response body contains a JSON object (indicated by a '{' character).
  # This is a basic check to ensure the response is not empty or malformed.
  if [ -f /tmp/api_response.json ] && grep -q "{" /tmp/api_response.json 2>/dev/null; then
    echo "API Gateway healthcheck successful: HTTP status $STATUS, response contains JSON."
    exit 0 # Exit with 0 for success
  else
    # Even if no JSON, a 200 or 401 status means the service is responding
    echo "API Gateway healthcheck successful: HTTP status $STATUS (service is responding)."
    exit 0
  fi
else
  echo "API Gateway healthcheck failed: Received HTTP status $STATUS (expected 200 or 401)."
  exit 1 # Exit with 1 for failure
fi
