#!/bin/bash

# Configuration
API_URL="http://localhost:8000"
APP_NAME="multi_tool_agent"
USER_ID="user"
SESSION_ID=$(uuidgen)  # Generate a new session ID
IMAGE_PATH="/Users/barathwajanandan/Documents/ted_gemini/test.png"

# Base64 encode the image
IMAGE_BASE64=$(base64 -i "$IMAGE_PATH")

# Send message with image
curl -X POST "$API_URL/run" \
  -H "Content-Type: application/json" \
  -d @- << REQUEST
{
  "app_name": "$APP_NAME",
  "user_id": "$USER_ID",
  "session_id": "$SESSION_ID",
  "user_content": {
    "parts": [
      {
        "text": "What do you see in this image?"
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
REQUEST
