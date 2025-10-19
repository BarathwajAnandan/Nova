#!/bin/bash

API_URL="http://localhost:8000"
APP_NAME="multi_tool_agent"
USER_ID="u_123"
SESSION_ID="s_123"
IMAGE_PATH="/Users/barathwajanandan/Documents/ted_gemini/test.png"

echo "Encoding image..."
IMAGE_BASE64=$(base64 -i "$IMAGE_PATH" | tr -d '\n')

echo "Sending request..."
curl -N -X POST "$API_URL/apps/$APP_NAME/users/$USER_ID/sessions/$SESSION_ID/run" \
  -H "Content-Type: application/json" \
  -d @- << EOF
{
  "new_message": {
    "role": "user",
    "parts": [
      {
        "text": "Describe this image"
      },
      {
        "inline_data": {
          "mime_type": "image/png",
          "data": "$IMAGE_BASE64"
        }
      }
    ]
  }
}
EOF

