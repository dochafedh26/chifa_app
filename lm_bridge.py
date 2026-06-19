from fastmcp import FastMCP
import openai
import sys

mcp = FastMCP("LMStudio")

try:
    client = openai.OpenAI(base_url="http://localhost:1234/v1", api_key="lm-studio")
except Exception as e:
    print(f"Error connecting to LM Studio: {e}", file=sys.stderr)

@mcp.tool()
def ask_local_llm(prompt: str) -> str:
    """Sends a coding question to the local LM Studio model."""
    response = client.chat.completions.create(
        model="local-model",
        messages=[{"role": "user", "content": prompt}]
    )
    return response.choices[0].message.content

if __name__ == "__main__":
    mcp.run()