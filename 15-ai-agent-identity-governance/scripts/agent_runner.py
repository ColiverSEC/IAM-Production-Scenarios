# =============================================================================
# agent_runner.py
# IDSentinel Solutions -- SCN-15 AI Agent Identity Governance
# LLM agent runner -- receives a prompt, selects a tool via Anthropic API,
# executes with the governed bearer token, logs the result to Splunk HEC.
# =============================================================================

import os, json, requests, datetime
import anthropic
import urllib3
import config
from agent_tools import get_user_profile, get_group_members, list_risky_users

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

# ── Tool definitions sent to the LLM ─────────────────────────────────────────

TOOLS = [
    {
        "name": "get_user_profile",
        "description": "Retrieves identity attributes for a user by ID or UPN.",
        "input_schema": {
            "type": "object",
            "properties": {
                "user_id": {"type": "string", "description": "User ID or UPN"}
            },
            "required": ["user_id"]
        }
    },
    {
        "name": "get_group_members",
        "description": "Returns the members of a group by group object ID.",
        "input_schema": {
            "type": "object",
            "properties": {
                "group_id": {"type": "string", "description": "Entra group object ID"}
            },
            "required": ["group_id"]
        }
    },
    {
        "name": "list_risky_users",
        "description": "Returns a list of risky users from Entra Identity Protection.",
        "input_schema": {
            "type": "object",
            "properties": {
                "top": {"type": "integer", "description": "Number of results to return (default 10)"}
            },
            "required": []
        }
    }
]

# ── Tool executor ─────────────────────────────────────────────────────────────

def execute_tool(name: str, inputs: dict) -> dict:
    if name == "get_user_profile":
        return get_user_profile(inputs["user_id"])
    elif name == "get_group_members":
        return get_group_members(inputs["group_id"])
    elif name == "list_risky_users":
        return list_risky_users(inputs.get("top", 10))
    else:
        raise ValueError(f"Unknown tool: {name}")

# ── Splunk HEC logger ─────────────────────────────────────────────────────────

def log_to_splunk(tool_name: str, inputs: dict, status_code: int):
    payload = {
        "sourcetype": "ai_agent:graph_api",
        "index": "identity_events",
        "event": {
            "app_id":      config.CLIENT_ID,
            "operation":   tool_name,
            "inputs":      str(inputs),
            "http_status": status_code,
            "scenario":    "SCN-15"
        }
    }
    try:
        r = requests.post(
            config.SPLUNK_HEC_URL,
            headers={
                "Authorization": f"Splunk {config.SPLUNK_HEC_TOKEN}",
                "Content-Type": "application/json"
            },
            data=json.dumps(payload),
            verify=False
        )
        if r.status_code == 200:
            print(f"[+] Logged to Splunk: {tool_name}")
        else:
            print(f"[!] Splunk log failed: {r.status_code} {r.text}")
    except Exception as e:
        print(f"[!] Splunk HEC error: {e}")

# ── Agent runner ──────────────────────────────────────────────────────────────

def run_agent(prompt: str):
    print(f"\n[>] Prompt: {prompt}")

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        tools=TOOLS,
        messages=[{"role": "user", "content": prompt}]
    )

    for block in response.content:
        if block.type == "tool_use":
            tool_name = block.name
            tool_inputs = block.input
            print(f"[*] Tool selected: {tool_name}")
            print(f"[*] Inputs: {json.dumps(tool_inputs, indent=2)}")

            try:
                result = execute_tool(tool_name, tool_inputs)
                log_to_splunk(tool_name, tool_inputs, 200)
                print(f"\n[+] Result:\n{json.dumps(result, indent=2)}")
            except Exception as e:
                log_to_splunk(tool_name, tool_inputs, 500)
                print(f"[!] Tool execution error: {e}")

        elif block.type == "text":
            print(f"\n[Agent]: {block.text}")


# ── Test prompts ──────────────────────────────────────────────────────────────

if __name__ == "__main__":
    run_agent("Get the profile for the user coliver@idsentinelsolutions.com")
    run_agent("Show me the current risky users in the environment")