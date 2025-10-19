#!/bin/bash

# Test with simple text first
curl -X POST "http://localhost:8000/run" \
  -H "Content-Type: application/json" \
  -d '{
    "app_name": "multi_tool_agent",
    "user_id": "user",
    "session_id": "test-session-'$(date +%s)'",
    "new_message": "List files in my Documents folder"
  }'
