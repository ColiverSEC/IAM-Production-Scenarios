# SOC 2 Evidence Log - Scenario 12

## Control Mapping

| Evidence Item                        | SOC 2 Control | Description                                            |
|--------------------------------------|--------------|--------------------------------------------------------|
| Federation trust policy (SAML cond.) | CC6.1        | Access restricted to Entra-issued SAML assertions only |
| Role with ReadOnlyAccess only        | CC6.3        | Least privilege enforced - no write permissions        |
| SAML Tracer assertion capture        | CC6.1        | Attribute-based access control validated               |
| Break/Fix lab documentation          | CC7.2        | Incident detection and response procedures tested      |
| Certificate rotation evidence        | CC9.1        | Credential lifecycle managed and documented            |

## Evidence Files to Attach

- [ ] Screenshot: AWS IAM role trust policy (SAML condition visible)
- [ ] Screenshot: ReadOnlyAccess policy attached
- [ ] Screenshot: Successful federated login (assumed role visible)
- [ ] Screenshot: Write action denied
- [ ] SAML Tracer export: clean assertion (JSON or screenshot)
- [ ] Break/Fix lab screenshots (3 breaks, 3 fixes)
