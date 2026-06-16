# config.py
# IDSentinel Solutions -- SCN-15
# Store credentials here. This file is excluded from version control.
# Add config.py to .gitignore before committing anything.

TENANT_ID     = "791eadd1-7519-44e0-8445-751a43c7bfff"
CLIENT_ID     = "e03fa879-93d7-4cac-b59e-b07a089d3cf9"
CLIENT_SECRET = "YOUR_CLIENT_SECRET_HERE"  # Store in Bitwarden, never commit

GRAPH_SCOPE   = "https://graph.microsoft.com/.default"
GRAPH_BASE    = "https://graph.microsoft.com/v1.0"

# Splunk HEC
SPLUNK_HEC_URL   = "https://localhost:8088/services/collector/event"
SPLUNK_HEC_TOKEN = "PASTE_YOUR_HEC_TOKEN_HERE"
SPLUNK_INDEX     = "identity_events"