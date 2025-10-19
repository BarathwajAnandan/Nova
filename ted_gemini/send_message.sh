#!/bin/bash

# Use SSE endpoint which handles sessions automatically
curl -N -X POST "http://localhost:8000/run_sse" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{
    "app_name": "multi_tool_agent",
    "user_id": "user",
    "session_id": "test-'$(uuidgen)'",
    "new_message": {
      "role": "user",
      "parts": [
        {
          "text": "List files in my Documents folder"
        }
      ]
    }
  }'
