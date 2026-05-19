# Screenshots - Stage 6: Break/Fix Lab (SSO Troubleshooting)

## Break 1 - Wrong ACS URL
1. break1-wrong-acs-url-error.png        - SAML error in browser after wrong ACS URL
2. break1-saml-tracer-capture.png        - SAML Tracer showing destination mismatch
3. break1-fix-applied.png                - Correct ACS URL restored in Entra

## Break 2 - Attribute Mismatch
4. break2-attribute-error-aws.png        - AWS login failure due to missing Role attribute
5. break2-saml-tracer-missing-attr.png   - SAML Tracer showing no Role claim in assertion
6. break2-fix-attribute-mapping.png      - Correct attribute mapping restored in Entra

## Break 3 - Expired Certificate
7. break3-cert-expired-error.png         - Signature validation failure
8. break3-new-cert-generated.png         - New signing certificate created in Entra
9. break3-aws-metadata-updated.png       - AWS IdP metadata re-uploaded with new cert
