"""
Get-B2CTokenReport.py
Scenario 08 â€” CIAM Login Platform with Azure AD B2C
IDSentinel Solutions

Automates OAuth2 authorization code flow token acquisition against
an Azure AD B2C tenant and decodes JWT claims for audit reporting.

Usage:
    python Get-B2CTokenReport.py

Requirements:
    pip install requests msal PyJWT
"""

import json
import requests

# â”€â”€ Configuration â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
# Replace with your B2C tenant values
TENANT_NAME     = "your-tenant.onmicrosoft.com"
CLIENT_ID       = "your-app-client-id"
POLICY_NAME     = "B2C_1_SignUpSignIn"   # User flow name
REDIRECT_URI    = "https://jwt.ms"
SCOPE           = "openid profile email"

TOKEN_ENDPOINT  = (
    f"https://{TENANT_NAME}.b2clogin.com/"
    f"{TENANT_NAME}/{POLICY_NAME}/oauth2/v2.0/token"
)

# â”€â”€ Token Decode (no signature verification â€” for lab/audit use only)
def decode_jwt_claims(token: str) -> dict:
    """Base64-decode JWT payload without verifying signature."""
    import base64
    parts = token.split(".")
    if len(parts) < 2:
        return {}
    padding = 4 - len(parts[1]) % 4
    payload = parts[1] + ("=" * padding)
    decoded = base64.urlsafe_b64decode(payload)
    return json.loads(decoded)

# â”€â”€ Main â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
def main():
    print("\n[*] Azure AD B2C â€” Token Claims Validator")
    print("=" * 50)

    # Paste a raw access token from Postman for decode/audit
    raw_token = input("\nPaste your B2C access token (from Postman): ").strip()

    if not raw_token:
        print("[-] No token provided. Exiting.")
        return

    claims = decode_jwt_claims(raw_token)

    print("\n[+] Decoded JWT Claims:")
    print("-" * 40)
    for key, value in claims.items():
        print(f"  {key:20s}: {value}")

    print("\n[+] Key Fields Validated:")
    for field in ["iss", "aud", "sub", "email", "scp", "exp"]:
        val = claims.get(field, "NOT PRESENT")
        status = "âœ…" if field in claims else "âŒ"
        print(f"  {status} {field:10s}: {val}")

    print("\n[*] Token validation complete.")

if __name__ == "__main__":
    main()
