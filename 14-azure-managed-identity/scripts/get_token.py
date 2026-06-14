import requests

VAULT_NAME = "kv-idsentinel-azureuser"
SECRET_NAME = "TestSecret"

print("\nSCN-14 -- Managed Identity Token Acquisition")
print("=" * 45)

print("\n[1] Requesting token from IMDS endpoint...")
imds_url = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://vault.azure.net"

try:
    r = requests.get(imds_url, headers={"Metadata": "true"}, timeout=5)
    r.raise_for_status()
    token = r.json()["access_token"]
    print("    Token acquired successfully")
except Exception as e:
    print(f"    FAILED: {e}")
    exit(1)

print(f"\n[2] Retrieving secret from Key Vault...")
kv_url = f"https://{VAULT_NAME}.vault.azure.net/secrets/{SECRET_NAME}?api-version=7.4"

try:
    kv = requests.get(kv_url, headers={"Authorization": f"Bearer {token}"}, timeout=10)
    print(f"    HTTP Status: {kv.status_code}")
    if kv.status_code == 403:
        print("    EXPECTED: 403 Forbidden -- no role assignment exists yet")
    elif kv.status_code == 200:
        value = kv.json()["value"]
        print(f"    SUCCESS -- Secret retrieved")
        print(f"    Value (masked): {value[:4]}****")
    else:
        print(f"    Response: {kv.text}")
except Exception as e:
    print(f"    FAILED: {e}")