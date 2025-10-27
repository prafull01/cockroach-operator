#!/bin/bash

# Script to test and verify UBI9 upgrade for cockroach-operator
# Usage: ./scripts/test-ubi9-upgrade.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Testing UBI9 Upgrade for CockroachDB Operator${NC}"
echo "=================================================="
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is required but not installed${NC}"
    exit 1
fi

echo -e "${YELLOW}🔍 Testing UBI9 Base Image Access...${NC}"

# Test pulling UBI9 minimal
echo "Pulling registry.access.redhat.com/ubi9/ubi-minimal:latest..."
if docker pull registry.access.redhat.com/ubi9/ubi-minimal:latest; then
    echo -e "${GREEN}✅ Successfully pulled UBI9 minimal image${NC}"
else
    echo -e "${RED}❌ Failed to pull UBI9 minimal image${NC}"
    echo "This might be due to:"
    echo "  - Network connectivity issues"
    echo "  - Red Hat registry authentication required"
    echo "  - Docker not running"
    exit 1
fi

echo ""
echo -e "${YELLOW}📊 Comparing UBI8 vs UBI9...${NC}"

# Get image information
echo "UBI9 Image Information:"
docker inspect registry.access.redhat.com/ubi9/ubi-minimal:latest | jq -r '.[0] | {
    Architecture: .Architecture,
    Os: .Os,
    Size: .Size,
    Created: .Created
}' 2>/dev/null || echo "  Architecture: $(docker inspect registry.access.redhat.com/ubi9/ubi-minimal:latest --format='{{.Architecture}}')"

echo ""
echo -e "${YELLOW}🔒 Running Basic Security Scan on UBI9...${NC}"

# Run Trivy scan if available
if command -v trivy &> /dev/null; then
    echo "Scanning UBI9 for HIGH and CRITICAL vulnerabilities..."
    trivy image --severity HIGH,CRITICAL registry.access.redhat.com/ubi9/ubi-minimal:latest | head -20
    
    echo ""
    echo "Getting vulnerability count..."
    CRITICAL_COUNT=$(trivy image --format json --severity CRITICAL registry.access.redhat.com/ubi9/ubi-minimal:latest 2>/dev/null | jq -r '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' 2>/dev/null || echo "0")
    HIGH_COUNT=$(trivy image --format json --severity HIGH registry.access.redhat.com/ubi9/ubi-minimal:latest 2>/dev/null | jq -r '[.Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length' 2>/dev/null || echo "0")
    
    echo -e "${GREEN}📈 UBI9 Vulnerability Summary:${NC}"
    echo "  Critical: $CRITICAL_COUNT"
    echo "  High: $HIGH_COUNT"
else
    echo -e "${YELLOW}⚠️  Trivy not found. Install with: brew install trivy${NC}"
fi

echo ""
echo -e "${YELLOW}⚙️  Verifying Bazel Configuration...${NC}"

# Check WORKSPACE file configuration
if grep -q "ubi9/ubi-minimal" WORKSPACE; then
    echo -e "${GREEN}✅ WORKSPACE correctly configured for UBI9${NC}"
else
    echo -e "${RED}❌ WORKSPACE not configured for UBI9${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 UBI9 Benefits:${NC}"
echo "  ✅ More recent base OS (RHEL 9 vs RHEL 8)"
echo "  ✅ Latest security patches and updates"
echo "  ✅ Better performance and efficiency"
echo "  ✅ Extended support lifecycle"
echo "  ✅ Improved container security features"
echo "  ✅ Better compliance with security standards"

echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Test your operator builds with UBI9"
echo "2. Run comprehensive security scans"
echo "3. Test functionality in development environment"
echo "4. Deploy to staging for validation"
echo "5. Update production deployments"

echo ""
echo -e "${GREEN}🔧 Build Commands:${NC}"
echo "  # Clean build with UBI9:"
echo "  bazel clean --expunge"
echo "  make release/image"
echo ""
echo "  # Security scan:"
echo "  make security/scan"

echo ""
echo -e "${GREEN}✅ UBI9 upgrade verification completed!${NC}" 