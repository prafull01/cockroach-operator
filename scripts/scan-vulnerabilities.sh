#!/bin/bash

# Vulnerability scanning script for cockroach-operator images
# Usage: ./scripts/scan-vulnerabilities.sh [image-name]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_IMAGE="cockroachdb/cockroach-operator"
SCAN_OUTPUT_DIR="security-reports"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Configuration
TRIVY_SEVERITY="HIGH,CRITICAL"
GRYPE_SEVERITY="high,critical"

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -i, --image IMAGE     Docker image to scan (default: $DEFAULT_IMAGE)"
    echo "  -t, --tag TAG         Image tag to scan (default: latest)"
    echo "  -s, --severity LEVEL  Severity levels to report (default: $TRIVY_SEVERITY)"
    echo "  -o, --output DIR      Output directory for reports (default: $SCAN_OUTPUT_DIR)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -i cockroachdb/cockroach-operator -t v2.14.0"
    echo "  $0 --severity MEDIUM,HIGH,CRITICAL"
}

# Check if required tools are installed
check_requirements() {
    local missing_tools=""
    
    if ! command -v trivy &> /dev/null; then
        echo -e "${YELLOW}⚠️  Trivy not found. Install with:${NC}"
        echo "  macOS: brew install trivy"
        echo "  Ubuntu/Debian: apt-get install trivy"
        echo "  Or download from: https://github.com/aquasecurity/trivy/releases"
        missing_tools+="trivy "
    fi
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is required but not installed${NC}"
        missing_tools+="docker "
    fi
    
    if [ -n "$missing_tools" ]; then
        echo -e "${RED}❌ Missing required tools: $missing_tools${NC}"
        exit 1
    fi
}

# Create output directory
setup_output_dir() {
    mkdir -p "$SCAN_OUTPUT_DIR"
    echo -e "${BLUE}📁 Reports will be saved to: $SCAN_OUTPUT_DIR${NC}"
}

# Scan with Trivy
scan_with_trivy() {
    local image="$1"
    local output_file="$SCAN_OUTPUT_DIR/trivy-report-$TIMESTAMP"
    
    echo -e "${YELLOW}🔍 Scanning with Trivy...${NC}"
    
    # JSON report for automation
    trivy image \
        --severity "$TRIVY_SEVERITY" \
        --format json \
        --output "$output_file.json" \
        "$image"
    
    # Human-readable report
    trivy image \
        --severity "$TRIVY_SEVERITY" \
        --format table \
        --output "$output_file.txt" \
        "$image"
    
    # SARIF report for GitHub integration
    trivy image \
        --severity "$TRIVY_SEVERITY" \
        --format sarif \
        --output "$output_file.sarif" \
        "$image"
    
    echo -e "${GREEN}✅ Trivy scan completed${NC}"
    echo "  - JSON report: $output_file.json"
    echo "  - Text report: $output_file.txt"
    echo "  - SARIF report: $output_file.sarif"
    
    # Check for specific CVEs mentioned by user
    echo -e "${YELLOW}🚨 Checking for specific CVEs...${NC}"
    local specific_cves=("CVE-2024-52533" "CVE-2024-34397" "CVE-2025-4373")
    
    for cve in "${specific_cves[@]}"; do
        if jq -r '.Results[].Vulnerabilities[]?.VulnerabilityID' "$output_file.json" 2>/dev/null | grep -q "$cve"; then
            echo -e "${RED}❌ Found $cve in image${NC}"
        else
            echo -e "${GREEN}✅ $cve not found${NC}"
        fi
    done
}

# Scan with Grype (if available)
scan_with_grype() {
    local image="$1"
    local output_file="$SCAN_OUTPUT_DIR/grype-report-$TIMESTAMP"
    
    if command -v grype &> /dev/null; then
        echo -e "${YELLOW}🔍 Scanning with Grype...${NC}"
        
        grype "$image" \
            --scope all-layers \
            --output json \
            --file "$output_file.json"
        
        grype "$image" \
            --scope all-layers \
            --output table \
            --file "$output_file.txt"
        
        echo -e "${GREEN}✅ Grype scan completed${NC}"
        echo "  - JSON report: $output_file.json"
        echo "  - Text report: $output_file.txt"
    else
        echo -e "${BLUE}ℹ️  Grype not found, skipping. Install with:${NC}"
        echo "  curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin"
    fi
}

# Generate summary report
generate_summary() {
    local trivy_json="$SCAN_OUTPUT_DIR/trivy-report-$TIMESTAMP.json"
    local summary_file="$SCAN_OUTPUT_DIR/summary-$TIMESTAMP.txt"
    
    echo -e "${YELLOW}📊 Generating summary report...${NC}"
    
    {
        echo "Vulnerability Scan Summary"
        echo "=========================="
        echo "Timestamp: $(date)"
        echo "Image: $1"
        echo ""
        
        if [ -f "$trivy_json" ]; then
            echo "Trivy Results:"
            echo "-------------"
            local critical=$(jq -r '[.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length' "$trivy_json" 2>/dev/null || echo "0")
            local high=$(jq -r '[.Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length' "$trivy_json" 2>/dev/null || echo "0")
            local medium=$(jq -r '[.Results[].Vulnerabilities[]? | select(.Severity=="MEDIUM")] | length' "$trivy_json" 2>/dev/null || echo "0")
            
            echo "  Critical: $critical"
            echo "  High: $high"
            echo "  Medium: $medium"
            echo ""
            
            # List critical CVEs
            if [ "$critical" -gt 0 ]; then
                echo "Critical CVEs:"
                jq -r '.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID' "$trivy_json" 2>/dev/null | sort -u | head -10
                echo ""
            fi
        fi
        
        echo "Recommendations:"
        echo "---------------"
        echo "1. Update base image to latest secure version"
        echo "2. Review and apply security patches"
        echo "3. Consider using distroless or minimal base images"
        echo "4. Set up automated vulnerability scanning in CI/CD"
        echo "5. Monitor security advisories for your base image"
        
    } > "$summary_file"
    
    echo -e "${GREEN}✅ Summary report: $summary_file${NC}"
    cat "$summary_file"
}

# Main execution
main() {
    local image="$DEFAULT_IMAGE"
    local tag="latest"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--image)
                image="$2"
                shift 2
                ;;
            -t|--tag)
                tag="$2"
                shift 2
                ;;
            -s|--severity)
                TRIVY_SEVERITY="$2"
                shift 2
                ;;
            -o|--output)
                SCAN_OUTPUT_DIR="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    local full_image="$image:$tag"
    
    echo -e "${BLUE}🔐 Vulnerability Scanner for Cockroach Operator${NC}"
    echo "=============================================="
    echo "Image: $full_image"
    echo "Severity: $TRIVY_SEVERITY"
    echo ""
    
    check_requirements
    setup_output_dir
    
    # Check if image exists locally or pull it
    if ! docker image inspect "$full_image" >/dev/null 2>&1; then
        echo -e "${YELLOW}📥 Pulling image: $full_image${NC}"
        docker pull "$full_image"
    fi
    
    scan_with_trivy "$full_image"
    scan_with_grype "$full_image"
    generate_summary "$full_image"
    
    echo ""
    echo -e "${GREEN}🎉 Vulnerability scanning completed!${NC}"
    echo -e "${BLUE}📁 All reports saved to: $SCAN_OUTPUT_DIR${NC}"
}

main "$@" 