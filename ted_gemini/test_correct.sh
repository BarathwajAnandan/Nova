#!/bin/bash

# Correct format for ADK API
curl -X POST "http://localhost:8000/run" \
  -H "Content-Type: application/json" \
  -d '{
    "app_name": "multi_tool_agent",
    "user_id": "user",
    "session_id": "test-'$(date +%s)'",
    "new_message": {
      "role": "user",
      "parts": [
        {
          "text": "List files in my Documents folder"
        }
      ]
    }
  }'
