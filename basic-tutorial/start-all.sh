#!/usr/bin/env bash

###################################
# 0. A trap to catch Ctrl+C (SIGINT)
###################################
cleanup() {
  echo
  echo "Stopping all background processes..."
  # This kills the entire process group (the script plus its children)
  kill 0
}

# When script receives Ctrl+C (SIGINT), call cleanup()
trap cleanup INT

########################################
# 1. Start AEM in the background
########################################
echo "Starting AEM Author..."
cd ~/aem-sdk/author

# Start in background (no nohup). Output goes to console, or redirect if you like.
java -jar aem-author-p4502.jar &  
AEM_PID=$!

echo "Waiting for AEM to start..."

while true; do
  STATUS=$(curl -s -u admin:admin -o /dev/null -w "%{http_code}" http://localhost:4502/)
  echo "HTTP code: $STATUS"
  
  if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
    echo "AEM responded with $STATUS; continuing..."
    break
  fi
  sleep 5
done

# Optional extra time to let bundles fully start
sleep 5
echo "AEM (PID $AEM_PID) is up and running!"

########################################
# 2. Start Universal Editor Service
########################################
echo "Starting Universal Editor Service (UES)..."
cd ~/aem-guides-wknd-graphql/basic-tutorial/universal-editor-service

node universal-editor-service.cjs &  
UES_PID=$!

echo "UES (PID $UES_PID) started."

########################################
# 3. Start SSL Proxies
########################################
echo "Starting SSL proxies..."
local-ssl-proxy --source 8443 --target 4502 &  
SSL_1_PID=$!

local-ssl-proxy --source 8001 --target 8000 &  
SSL_2_PID=$!

echo "SSL proxies started with PIDs $SSL_1_PID and $SSL_2_PID."

########################################
# 4. Start local React app
########################################
echo "Starting local React app..."
cd ~/aem-guides-wknd-graphql/basic-tutorial

npm start &  
REACT_PID=$!

echo "React (PID $REACT_PID) started."

########################################
# 4a. Open UES cloud in default browser
########################################
sleep 10

TARGET_URL="https://experience.adobe.com/#/@deloitteemeasouthpartnersdbx/aem/editor/canvas/localhost:3000/"
echo "Opening new tab in default browser to: $TARGET_URL"

case "$OSTYPE" in
  darwin*) 
    # macOS
    open "$TARGET_URL"
    ;;
  linux*)
    # Linux
    xdg-open "$TARGET_URL"
    ;;
  *)
    # Other (e.g. Windows/Cygwin)
    echo "Please open the following URL manually:"
    echo "$TARGET_URL"
    ;;
esac

########################################
# 5. Keep the script running
########################################
echo
echo "All services started in the background."
echo "Press Ctrl+C to stop everything..."
echo

wait