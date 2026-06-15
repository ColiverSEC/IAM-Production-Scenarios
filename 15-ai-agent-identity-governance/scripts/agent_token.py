# =============================================================================
# agent_token.py
# IDSentinel Solutions -- SCN-15 AI Agent Identity Governance
# Client credentials flow -- acquires a scoped JWT for Graph API access.
# Implements token caching and re-acquisition on expiry.
# =============================================================================

import msal
import time
import config

_token_cache = {"token": None, "expires_at": 0}

def get_token():
    """
    Returns a valid bearer token. Re-acquires if expired.
    Token lifetime is 3600 seconds (1 hour) by default.
    """
    now = time.time()

    if _token_cache["token"] and now < _token_cache["expires_at"] - 60:
        return _token_cache["token"]

    app = msal.ConfidentialClientApplication(
        client_id=config.CLIENT_ID,
        client_credential=config.CLIENT_SECRET,
        authority=f"https://login.microsoftonline.com/{config.TENANT_ID}"
    )

    result = app.acquire_token_for_client(scopes=[config.GRAPH_SCOPE])

    if "access_token" not in result:
        raise Exception(f"Token acquisition failed: {result.get('error_description')}")

    _token_cache["token"]      = result["access_token"]
    _token_cache["expires_at"] = now + result.get("expires_in", 3600)

    return _token_cache["token"]


if __name__ == "__main__":
    import base64, json

    token = get_token()
    print("[+] Token acquired successfully\n")

    # Decode and print the JWT payload (middle segment)
    payload_b64 = token.split(".")[1]
    # Pad base64 string to a multiple of 4
    payload_b64 += "=" * (4 - len(payload_b64) % 4)
    payload = json.loads(base64.urlsafe_b64decode(payload_b64))

    print("── JWT Claims ────────────────────────────────")
    print(f"  appid  : {payload.get('appid')}")
    print(f"  tid    : {payload.get('tid')}")
    print(f"  roles  : {payload.get('roles')}")
    print(f"  exp    : {payload.get('exp')}")
    print("──────────────────────────────────────────────\n")
    print("[i] Confirm appid matches your CLIENT_ID")
    print("[i] Confirm roles contains only the 4 expected permissions")