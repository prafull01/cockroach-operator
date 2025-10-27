#!/bin/bash

# Script to check Red Hat UBI minimal image for CVEs and find secure versions
# Usage: ./scripts/check-base-image-security.sh

set -e

echo "🔍 Checking Red Hat UBI9 minimal image security..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required tools are installed
check_requirements() {
    local missing_tools=""
    
    if ! command -v skopeo &> /dev/null; then
        missing_tools+="skopeo "
    fi
    
    if ! command -v curl &> /dev/null; then
        missing_tools+="curl "
    fi
    
    if [ -n "$missing_tools" ]; then
        echo -e "${RED}❌ Missing required tools: $missing_tools${NC}"
        echo "Please install them:"
        echo "  macOS: brew install skopeo curl"
        echo "  Ubuntu/Debian: apt-get install skopeo curl"
        echo "  RHEL/CentOS: dnf install skopeo curl"
        exit 1
    fi
}

# Get latest available tags for UBI9 minimal
get_available_tags() {
    echo -e "${YELLOW}🏷️  Fetching available UBI9 minimal tags...${NC}"
    
    # Use skopeo to list tags (requires authentication for Red Hat registry)
    skopeo list-tags docker://registry.access.redhat.com/ubi9/ubi-minimal | \
        jq -r '.Tags[]' | \
        grep -E '^9\.[0-9]+' | \
        sort -V | \
        tail -10
}

# Get digest for a specific tag
get_image_digest() {
    local tag="$1"
    echo -e "${YELLOW}🔍 Getting digest for tag: $tag${NC}"
    
    skopeo inspect docker://registry.access.redhat.com/ubi9/ubi-minimal:$tag | \
        jq -r '.Digest'
}

# Check Red Hat Security Advisories
check_security_advisories() {
    echo -e "${YELLOW}🛡️  Checking Red Hat Security Advisories...${NC}"
    echo "Please check manually at:"
    echo "  - https://access.redhat.com/security/security-updates/#/security-advisories"
    echo "  - https://access.redhat.com/containers/#/registry.access.redhat.com/ubi9/ubi-minimal"
}

# Generate WORKSPACE configuration
generate_workspace_config() {
    local tag="$1"
    local digest="$2"
    
    echo -e "${GREEN}📝 Recommended WORKSPACE configuration:${NC}"
    echo ""
    echo "oci_pull("
    echo "    name = \"redhat_ubi_minimal\","
    echo "    platforms = ["
    echo "        \"linux/amd64\","
    echo "        \"linux/arm64/v8\""
    echo "    ],"
    echo "    registry = \"registry.access.redhat.com\","
    echo "    repository = \"ubi8/ubi-minimal\","
    
    if [ -n "$digest" ]; then
        echo "    digest = \"$digest\",  # Most secure - immutable"
    else
        echo "    tag = \"$tag\",  # Update regularly"
    fi
    
    echo ")"
    echo ""
}

# Check specific CVEs mentioned by user
check_specific_cves() {
    echo -e "${YELLOW}🚨 Checking specific CVEs mentioned:${NC}"
    echo "  - CVE-2024-52533"
    echo "  - CVE-2024-34397" 
    echo "  - CVE-2025-4373"
    echo ""
    echo "To check if these affect your image:"
    echo "1. Use a vulnerability scanner like Trivy or Grype"
    echo "2. Check Red Hat's CVE database"
    echo "3. Review container security scanning results"
}

# Main execution
main() {
    echo "🔐 Red Hat UBI9 Minimal Security Checker"
    echo "========================================"
    echo ""
    
    check_requirements
    check_specific_cves
    check_security_advisories
    
    echo ""
    echo -e "${GREEN}✅ Recommendations:${NC}"
    echo "1. Use a specific tag or digest instead of 'latest'"
    echo "2. Regularly scan images for vulnerabilities"
    echo "3. Set up automated security scanning in CI/CD"
    echo "4. Monitor Red Hat Security Advisories"
    echo "5. Consider using distroless or minimal base images"
    
    echo ""
    echo -e "${YELLOW}📋 Next steps:${NC}"
    echo "1. Update WORKSPACE file with pinned version"
    echo "2. Rebuild and push your images" 
    echo "3. Run vulnerability scans on new images"
    echo "4. Update your deployment manifests if needed"
}

main "$@" 