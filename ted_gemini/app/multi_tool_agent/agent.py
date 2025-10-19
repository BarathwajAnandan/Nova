from google.adk.agents import LlmAgent
from google.adk.tools.mcp_tool.mcp_toolset import MCPToolset
from google.adk.tools.mcp_tool.mcp_session_manager import StdioConnectionParams
from mcp import StdioServerParameters
from google.genai import types

# Terminal MCP Server path
TERMINAL_MCP_PATH = "/Users/barathwajanandan/Documents/terminal-mcp-server/build/index.js"

# Google Calendar OAuth credentials path
GOOGLE_OAUTH_CREDENTIALS = "/Users/barathwajanandan/.cursor/gcp-oauth.keys.json"

root_agent = LlmAgent(
    model='gemini-2.5-flash',
    name='terminal_agent',
    instruction=(
        "You are a helpful agent who can execute terminal commands on macOS and analyze images. "
        "You have full access to the macOS terminal and can run any commands the user requests. "
        "Use macOS-specific commands and understand the macOS file system structure. "
        "You also have access to Google Calendar to manage events and schedules. "
        "You can also manage Apple Notes - create, read, update, delete, and organize notes and folders. "
        "You have access to Apple apps including Contacts, Messages, Mail, Reminders, Calendar, and Maps. "
        "IMPORTANT: Always prioritize the user's text prompt. If an image is provided, only analyze or reference it "
        "if the user's prompt explicitly requires image context (e.g., 'what's in this image?', 'describe this picture', ' what do you see'  "
        "'analyze this screenshot'). Otherwise, focus solely on answering the text prompt and ignore the image."
    ),
    tools=[
        # Terminal MCP Server
        MCPToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command='node',
                    args=[TERMINAL_MCP_PATH],
                ),
                timeout=30.0,  # Increase timeout to 30 seconds
            ),
        ),
        # Google Calendar MCP Server
        MCPToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command='npx',
                    args=[
                        '-y',  # Auto-confirm npx install
                        '@cocal/google-calendar-mcp'
                    ],
                    env={
                        'GOOGLE_OAUTH_CREDENTIALS': GOOGLE_OAUTH_CREDENTIALS
                    },
                ),
                timeout=30.0,  # Increase timeout to 30 seconds
            ),
        ),
        # Apple Notes MCP Server
        MCPToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command='uvx',
                    args=['mcp-apple-notes@latest'],
                ),
                timeout=30.0,  # Increase timeout to 30 seconds
            ),
        ),
        # Apple MCP Server (Contacts, Messages, Reminders) - Local version with improvements
        MCPToolset(
            connection_params=StdioConnectionParams(
                server_params=StdioServerParameters(
                    command='node',
                    args=['/Users/barathwajanandan/Documents/mcp_servers/apple-mcp/dist/index.js'],
                ),
                timeout=30.0,  # Increase timeout to 30 seconds
            ),
        )
    ],
)

def ask_with_image(prompt: str, image_path: str):
    """Send a question to the agent with an image as context."""
    with open(image_path, 'rb') as f:
        image_bytes = f.read()
    
    # Determine MIME type from file extension
    mime_type = 'image/jpeg'
    if image_path.lower().endswith('.png'):
        mime_type = 'image/png'
    elif image_path.lower().endswith('.gif'):
        mime_type = 'image/gif'
    elif image_path.lower().endswith('.webp'):
        mime_type = 'image/webp'
    
    return root_agent.send_message(
        content=[
            types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
            prompt
        ]
    )