# Diagrams — Scenario 10

## pipeline-architecture.png

Create this diagram in draw.io (diagrams.net) showing the end-to-end pipeline:

**Left column — Data Sources**
- Entra ID Sign-in Logs (Graph API endpoint)
- Entra ID Audit Logs (Graph API endpoint, includes PIM events)

**Center — Ingestion Layer (two paths)**
- Method A: Splunk Add-on for Microsoft Security
  → Polls Graph API on schedule → Writes to idsentinel_identity index
- Method B: Python HEC Ingestor (Invoke-EntraLogIngestor.py)
  → OAuth2 client credentials auth → Splunk HEC (port 8088) → idsentinel_identity index

**Right column — Detection Layer**
- D-01: MFA Fatigue (15min schedule)
- D-02: Impossible Travel (30min schedule)
- D-03: After-Hours PIM (60min schedule)
- D-04: Legacy Auth Spike (15min schedule)

**Bottom — Output**
- Triggered Alerts → SOC analyst review → INC-TYPE-001 Runbook

**Style:** Match the dark theme and blue accent colors from other scenario diagrams.
Use dashed arrows for the data flow, solid borders for the detection boxes.
