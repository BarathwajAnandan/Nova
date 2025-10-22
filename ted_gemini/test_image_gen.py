#!/usr/bin/env python3
"""Test image generation with Gemini API directly."""

import os
import sys

try:
    from google import genai
    from google.genai import types as gx
except ImportError:
    print("Error: google-genai package not installed")
    print("Install with: pip install google-genai")
    sys.exit(1)

# API key from environment variable
API_KEY = os.getenv("GOOGLE_API_KEY")
if not API_KEY:
    print("Error: GOOGLE_API_KEY environment variable not set")
    print("Please set it with: export GOOGLE_API_KEY='your-api-key'")
    sys.exit(1)

MODEL = "gemini-2.5-flash-image-preview"

def test_image_generation():
    """Test basic image generation."""
    try:
        print(f"Testing image generation with {MODEL}...")
        print(f"Prompt: car eating banana\n")
        
        # Create client
        client = genai.Client(api_key=API_KEY)
        
        # Generate image
        response = client.models.generate_content(
            model=MODEL,
            contents=["car eating banana"]
        )
        
        # Check response
        print(f"Response received!")
        print(f"Candidates: {len(response.candidates) if response.candidates else 0}")
        
        if response.candidates:
            candidate = response.candidates[0]
            if hasattr(candidate, 'content') and candidate.content:
                parts = candidate.content.parts if hasattr(candidate.content, 'parts') else []
                print(f"Parts: {len(parts)}")
                
                # Check for images
                image_count = 0
                for part in parts:
                    if hasattr(part, 'inline_data') and part.inline_data:
                        image_count += 1
                        print(f"  - Found image data: {len(part.inline_data.data)} bytes")
                
                if image_count == 0:
                    print("\n❌ No image data found in response")
                    print("Response structure:", response)
                else:
                    print(f"\n✅ Successfully generated {image_count} image(s)!")
            else:
                print("\n❌ No content in candidate")
                print("Candidate:", candidate)
        else:
            print("\n❌ No candidates in response")
            print("Response:", response)
            
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_image_generation()

