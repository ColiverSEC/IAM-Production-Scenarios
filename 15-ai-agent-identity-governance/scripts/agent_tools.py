# =============================================================================
# agent_tools.py
# IDSentinel Solutions -- SCN-15 AI Agent Identity Governance
# Tool implementations using the governed bearer token.
# All three functions use only the four scoped permissions.
# =============================================================================

import requests
import config
from agent_token import get_token


def _headers():
    return {"Authorization": f"Bearer {get_token()}"}


def get_user_profile(user_id: str) -> dict:
    """
    Retrieves user profile attributes for a given user ID or UPN.
    Uses: User.Read.All
    """
    url = f"{config.GRAPH_BASE}/users/{user_id}"
    params = {"$select": "displayName,userPrincipalName,jobTitle,department,accountEnabled"}
    r = requests.get(url, headers=_headers(), params=params)
    r.raise_for_status()
    return r.json()


def get_group_members(group_id: str) -> list:
    """
    Returns the members of a group by group ID.
    Uses: Group.Read.All
    """
    url = f"{config.GRAPH_BASE}/groups/{group_id}/members"
    params = {"$select": "displayName,userPrincipalName,jobTitle"}
    r = requests.get(url, headers=_headers(), params=params)
    r.raise_for_status()
    return r.json().get("value", [])


def list_risky_users(top: int = 10) -> list:
    """
    Returns the top N risky users from Identity Protection.
    Uses: IdentityRiskyUser.Read.All
    """
    url = f"{config.GRAPH_BASE}/identityProtection/riskyUsers"
    params = {"$top": top, "$select": "userDisplayName,userPrincipalName,riskLevel,riskState"}
    r = requests.get(url, headers=_headers(), params=params)
    r.raise_for_status()
    return r.json().get("value", [])