# Security Policy

This document outlines security practices and procedures for the CockroachDB Operator project.

## Reporting Security Issues

If you discover a security vulnerability, please report it to:
- Email: [security@cockroachlabs.com](mailto:security@cockroachlabs.com)
- Include "Security Issue" in the subject line
- Provide detailed information about the vulnerability

Please do not report security vulnerabilities through public GitHub issues.

## Container Image Security

### Base Image Vulnerabilities

The CockroachDB Operator uses Red Hat Universal Base Image (UBI) 9 minimal as its base image. UBI9 provides better security, more recent packages, and improved performance compared to UBI8.

**Current Configuration:**
```
Base Image: registry.access.redhat.com/ubi9/ubi-minimal:latest
```

### Known CVE Issues

The following CVEs have been reported in container images:
- CVE-2024-52533
- CVE-2024-34397
- CVE-2025-4373

**Status:** Fixed by pinning to secure base image version 8.10-1018

### Vulnerability Management Process

1. **Automated Scanning**: 
   - GitHub Actions workflow runs weekly vulnerability scans
   - Trivy scanner checks for HIGH and CRITICAL severity CVEs
   - Results are uploaded to GitHub Security tab

2. **Manual Scanning**:
   ```bash
   # Check base image security
   make security/check-base-image
   
   # Scan built operator image
   make security/scan
   
   # Full security check
   make security/full-check
   ```

3. **Security Tools**:
   - [Trivy](https://github.com/aquasecurity/trivy) - Container vulnerability scanner
   - [Grype](https://github.com/anchore/grype) - Alternative vulnerability scanner
   - [Govulncheck](https://golang.org/x/vuln/cmd/govulncheck) - Go vulnerability scanner

## Base Image Updates

### Finding Secure Versions

To find secure base image versions:

1. Check Red Hat Security Advisories:
   - https://access.redhat.com/security/security-updates/#/security-advisories
   - https://access.redhat.com/containers/#/registry.access.redhat.com/ubi9/ubi-minimal

2. Use the security checker script:
   ```bash
   ./scripts/check-base-image-security.sh
   ```

3. Test new versions with vulnerability scanning:
   ```bash
   # Update WORKSPACE file with new tag/digest
   # Then run security scan
   make security/scan
   ```

### Update Process

1. **Pin to Specific Version**: Always use specific tags or digests instead of `latest`
   ```
   # WORKSPACE file
   oci_pull(
       name = "redhat_ubi_minimal",
       registry = "registry.access.redhat.com",
       repository = "ubi9/ubi-minimal",
       tag = "9.4",  # Specific secure version
   )
   ```

2. **Use Digest for Maximum Security**:
   ```
   oci_pull(
       name = "redhat_ubi_minimal",
       registry = "registry.access.redhat.com",
       repository = "ubi9/ubi-minimal",
       digest = "sha256:...",  # Immutable reference
   )
   ```

3. **Test and Validate**:
   - Build images with new base
   - Run vulnerability scans
   - Test functionality
   - Update in production

## CI/CD Security

### Automated Security Checks

The project includes automated security scanning in CI/CD:

- **On every PR/push**: Basic vulnerability scan
- **Weekly**: Comprehensive security scan to catch new CVEs
- **Manual trigger**: Available for on-demand scanning

### GitHub Security Features

- **Security Advisories**: SARIF reports uploaded to GitHub Security tab
- **Dependabot**: Automated dependency updates
- **Secret Scanning**: Detects accidentally committed secrets
- **Code Scanning**: Static analysis for security issues

## Dependencies Security

### Go Dependencies

Monitor Go dependencies for vulnerabilities:

```bash
# Check Go vulnerabilities
go install golang.org/x/vuln/cmd/govulncheck@latest
govulncheck ./...

# Update dependencies
go mod tidy
go mod update
```

### Bazel Dependencies

Keep Bazel rules and dependencies updated:
- rules_oci: Container image building
- aspect_bazel_lib: Build utilities
- Go toolchain: Latest stable version

## Runtime Security

### Container Security

The operator container runs with:
- Non-root user (UID: 1000581000)
- Read-only filesystem where possible
- Minimal attack surface (UBI minimal)
- No shell or unnecessary binaries

### Kubernetes Security

- RBAC: Minimal required permissions
- Security Context: Non-root, read-only filesystem
- Network Policies: Restrict network access
- Pod Security Standards: Enforce security policies

## Security Monitoring

### Regular Tasks

1. **Weekly**: Review vulnerability scan results
2. **Monthly**: Check for base image updates
3. **Quarterly**: Review and update security documentation
4. **On CVE alerts**: Immediate assessment and response

### Key Resources

- [Red Hat Security Advisories](https://access.redhat.com/security/)
- [NIST National Vulnerability Database](https://nvd.nist.gov/)
- [Go Security Advisories](https://go.dev/security/)
- [Kubernetes Security](https://kubernetes.io/docs/concepts/security/)

## Emergency Response

### Critical CVE Response

1. **Assessment**: Determine if CVE affects our images
2. **Mitigation**: Apply temporary mitigations if available
3. **Patching**: Update base image or dependencies
4. **Testing**: Validate fixes don't break functionality
5. **Communication**: Notify users of security updates

### Incident Response

For security incidents:
1. Contain the issue
2. Assess the impact
3. Implement fixes
4. Document lessons learned
5. Update security practices

## Best Practices

### For Developers

- Always pin base image versions
- Regularly update dependencies
- Run security scans before merging
- Follow secure coding practices
- Review security documentation

### For Users

- Use official container images
- Keep operator updated
- Monitor security advisories
- Implement defense in depth
- Follow Kubernetes security best practices

## Tools and Scripts

The project provides several security tools:

- `scripts/check-base-image-security.sh` - Check base image security
- `scripts/scan-vulnerabilities.sh` - Comprehensive vulnerability scanning
- `.trivyignore` - Manage false positives
- GitHub Actions - Automated security scanning

## Contact

For security questions or concerns:
- Security Team: security@cockroachlabs.com
- General Issues: cockroach-operator@cockroachlabs.com
- Documentation: Update this file via pull request 