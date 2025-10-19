#!/bin/bash

API_URL="http://localhost:8000"
APP_NAME="multi_tool_agent"
USER_ID="u"
SESSION_ID="s"
IMAGE_PATH="/Users/barathwajanandan/Documents/ted_gemini/test.png"

echo "Encoding image..."
IMAGE_BASE64=$(base64 -i "$IMAGE_PATH" | tr -d '\n')

echo "Sending request..."
curl -X POST "$API_URL/run_sse" \
  -H "Content-Type: application/json" \
  -d @- << EOF2
{
  "appName": "$APP_NAME",
  "userId": "$USER_ID",
  "sessionId": "$SESSION_ID",
  "newMessage": {
    "role": "user",
    "parts": [
      {
        "text": "list files in my documents folder"
      },
      {
        "inlineData": {
          "mimeType": "image/png",
          "data": "$IMAGE_BASE64"
        }
      }
    ]
  },
  "streaming": false
}
EOF2
