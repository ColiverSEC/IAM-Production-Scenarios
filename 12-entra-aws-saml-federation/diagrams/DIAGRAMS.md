# Diagrams - Scenario 12

## saml-federation-architecture.png

Create in draw.io (diagrams.net). Dark theme with blue accents.

Layout (left to right):

LEFT - Identity Provider (Entra ID)
- Box: Entra ID Tenant (IDSentinelSolutions.com)
- Sub-box: Enterprise App - AWS SAML Federation
- Sub-box: User (Cleveland@IDSentinelSolutions.com)

CENTER - SAML Flow (numbered arrows)
1. User accesses AWS app tile (MyApps or direct)
2. Entra issues SAML assertion (signed, with Role + SessionName attributes)
3. SAML assertion POST to AWS ACS endpoint

RIGHT - Service Provider (AWS)
- Box: AWS Account
- Sub-box: IAM Identity Provider (Entra metadata)
- Sub-box: IAM Role - IDSentinel-EntraFed-ReadOnly
- Sub-box: AWS Console / IAM STS

BOTTOM - Break/Fix Callout box
- B1: Wrong ACS URL -> Destination mismatch error
- B2: Missing Role attribute -> No valid role to assume
- B3: Expired signing cert -> Signature validation failure
