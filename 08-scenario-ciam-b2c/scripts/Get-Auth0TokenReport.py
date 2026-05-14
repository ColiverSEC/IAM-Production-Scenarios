"""
Get-Auth0TokenReport.py
Scenario 08 — CIAM Login Platform with Auth0
IDSentinel Solutions

Decodes a JWT access token or ID token issued by Auth0 and validates
key claims for audit and troubleshooting purposes.

Usage:
    python Get-Auth0TokenReport.py

Requirements:
    pip install requests
"""

import json
import base64
import datetime


def decode_jwt_claims(token: str) -> dict:
    """Base64-decode JWT payload without verifying signature.
    For lab/audit use only — always verify signatures in production."""
    parts = token.split(".")
    if len(parts) < 2:
        return {}
    padding = 4 - len(parts[1]) % 4
    payload = parts[1] + ("=" * padding)
    decoded = base64.urlsafe_b64decode(payload)
    return json.loads(decoded)


def format_expiry(exp_timestamp: int) -> str:
    """Convert Unix timestamp to human-readable expiry string."""
    try:
        expiry = datetime.datetime.utcfromtimestamp(exp_timestamp)
        now = datetime.datetime.utcnow()
        delta = expiry - now
        if delta.total_seconds() > 0:
            minutes = int(delta.total_seconds() // 60)
            return f"{expiry.strftime('%Y-%m-%d %H:%M:%S')} UTC (expires in {minutes} min)"
        else:
            return f"{expiry.strftime('%Y-%m-%d %H:%M:%S')} UTC (EXPIRED)"
    except Exception:
        return str(exp_timestamp)


def main():
    print("\n" + "=" * 55)
    print("  Auth0 JWT Token Claims Validator")
    print("  Scenario 08 — IDSentinel CIAM Platform")
    print("=" * 55)

    print("\nPaste your Auth0 access token or ID token below.")
    print("(From Postman token response or browser redirect)\n")
    raw_token = input("Token: ").strip()

    if not raw_token:
        print("\n[-] No token provided. Exiting.")
        return

    # Strip 'Bearer ' prefix if pasted with it
    if raw_token.lower().startswith("bearer "):
        raw_token = raw_token[7:].strip()

    claims = decode_jwt_claims(raw_token)

    if not claims:
        print("\n[-] Could not decode token. Ensure it is a valid JWT.")
        return

    print("\n[+] All Decoded Claims:")
    print("-" * 55)
    for key, value in claims.items():
        if key == "exp":
            print(f"  {'exp':20s}: {format_expiry(value)}")
        else:
            print(f"  {key:20s}: {value}")

    # Key field validation
    print("\n[+] Key Field Validation:")
    print("-" * 55)

    key_fields = {
        "iss":   "Issuer — should be your Auth0 domain",
        "sub":   "Subject — unique customer identifier",
        "aud":   "Audience — should match your API identifier",
        "scope": "Scopes — should include read:data",
        "exp":   "Expiry — token must not be expired",
        "email": "Email — customer email address",
    }

    all_present = True
    for field, description in key_fields.items():
        value = claims.get(field)
        if value:
            if field == "exp":
                display = format_expiry(value)
            else:
                display = str(value)
            print(f"  [OK] {field:10s}: {display}")
            print(f"       {description}")
        else:
            print(f"  [--] {field:10s}: NOT PRESENT — {description}")
            all_present = False
        print()

    # Scope check
    scope_value = claims.get("scope", "")
    if "read:data" in scope_value:
        print("  [OK] API scope 'read:data' confirmed in token")
    else:
        print("  [--] API scope 'read:data' NOT found — check API permissions")

    print("\n" + "=" * 55)
    if all_present:
        print("  Result: Token validated — all key fields present")
    else:
        print("  Result: Token validated with warnings — review missing fields")
    print("=" * 55 + "\n")


if __name__ == "__main__":
    main()
