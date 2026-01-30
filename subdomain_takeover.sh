#!/bin/bash

#===============================================================================
# Subdomain Takeover Detection Script
# 
# This script automates the end-to-end process of:
# 1. Subdomain enumeration using multiple sources (crt.sh, subfinder, sublist3r)
# 2. Probing live subdomains with httpx
# 3. Detecting potential subdomain takeover vulnerabilities with subzy
#
# Usage: ./subdomain_takeover.sh <domain> [output_directory]
#
# Author: Manus AI
# Date: January 2026
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║          SUBDOMAIN TAKEOVER DETECTION SCRIPT                 ║"
echo "║                                                               ║"
echo "║  Enumerate subdomains and detect takeover vulnerabilities    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check for required argument
if [ -z "$1" ]; then
    echo -e "${RED}[ERROR]${NC} Usage: $0 <domain> [output_directory]"
    echo "Example: $0 example.com ./results"
    exit 1
fi

DOMAIN=$1
OUTPUT_DIR=${2:-"./results_${DOMAIN}_$(date +%Y%m%d_%H%M%S)"}
FINGERPRINTS_URL="https://raw.githubusercontent.com/EdOverflow/can-i-take-over-xyz/master/fingerprints.json"

# Create output directory
mkdir -p "$OUTPUT_DIR"
cd "$OUTPUT_DIR"

echo -e "${GREEN}[+]${NC} Target domain: ${YELLOW}${DOMAIN}${NC}"
echo -e "${GREEN}[+]${NC} Output directory: ${YELLOW}${OUTPUT_DIR}${NC}"
echo ""

#===============================================================================
# PHASE 1: SUBDOMAIN ENUMERATION
#===============================================================================
echo -e "${BLUE}[PHASE 1]${NC} Subdomain Enumeration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1.1 crt.sh - Certificate Transparency Logs
echo -e "${GREEN}[+]${NC} Querying crt.sh (Certificate Transparency)..."
curl -s "https://crt.sh/?q=%25.${DOMAIN}&output=json" 2>/dev/null | \
    jq -r '.[].name_value' 2>/dev/null | \
    sed 's/\*\.//g' | \
    grep -v "^$" | \
    sort -u > crtsh_subdomains.txt 2>/dev/null || touch crtsh_subdomains.txt
CRTSH_COUNT=$(wc -l < crtsh_subdomains.txt)
echo -e "    └── Found ${YELLOW}${CRTSH_COUNT}${NC} subdomains from crt.sh"

# 1.2 Subfinder
echo -e "${GREEN}[+]${NC} Running subfinder..."
if command -v subfinder &> /dev/null; then
    subfinder -d "${DOMAIN}" -o subfinder_subdomains.txt -silent 2>/dev/null || touch subfinder_subdomains.txt
    SUBFINDER_COUNT=$(wc -l < subfinder_subdomains.txt)
    echo -e "    └── Found ${YELLOW}${SUBFINDER_COUNT}${NC} subdomains from subfinder"
else
    echo -e "    └── ${RED}subfinder not installed, skipping...${NC}"
    touch subfinder_subdomains.txt
fi

# 1.3 Sublist3r
echo -e "${GREEN}[+]${NC} Running sublist3r..."
if command -v sublist3r &> /dev/null; then
    sublist3r -d "${DOMAIN}" -o sublist3r_subdomains.txt 2>/dev/null || touch sublist3r_subdomains.txt
    SUBLIST3R_COUNT=$(wc -l < sublist3r_subdomains.txt 2>/dev/null || echo 0)
    echo -e "    └── Found ${YELLOW}${SUBLIST3R_COUNT}${NC} subdomains from sublist3r"
else
    echo -e "    └── ${RED}sublist3r not installed, skipping...${NC}"
    touch sublist3r_subdomains.txt
fi

# 1.4 Combine and deduplicate
echo -e "${GREEN}[+]${NC} Combining and deduplicating results..."
cat crtsh_subdomains.txt subfinder_subdomains.txt sublist3r_subdomains.txt 2>/dev/null | \
    grep -v "^$" | \
    sort -u > all_subdomains.txt
TOTAL_COUNT=$(wc -l < all_subdomains.txt)
echo -e "    └── Total unique subdomains: ${YELLOW}${TOTAL_COUNT}${NC}"
echo ""

#===============================================================================
# PHASE 2: PROBING LIVE SUBDOMAINS
#===============================================================================
echo -e "${BLUE}[PHASE 2]${NC} Probing Live Subdomains"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v httpx &> /dev/null; then
    echo -e "${GREEN}[+]${NC} Probing subdomains with httpx..."
    cat all_subdomains.txt | httpx -silent -status-code -ip -title -tech-detect -o live_subdomains.txt 2>/dev/null || touch live_subdomains.txt
    LIVE_COUNT=$(wc -l < live_subdomains.txt)
    echo -e "    └── Live subdomains: ${YELLOW}${LIVE_COUNT}${NC}"
    
    # Extract subdomains with interesting status codes
    echo -e "${GREEN}[+]${NC} Filtering for interesting status codes (502, 503, 404, etc.)..."
    grep -E "\[502\]|\[503\]|\[404\]|\[410\]" live_subdomains.txt > interesting_status.txt 2>/dev/null || touch interesting_status.txt
    INTERESTING_COUNT=$(wc -l < interesting_status.txt)
    echo -e "    └── Subdomains with interesting status codes: ${YELLOW}${INTERESTING_COUNT}${NC}"
else
    echo -e "${RED}[!]${NC} httpx not installed. Skipping live subdomain probing."
    touch live_subdomains.txt
    touch interesting_status.txt
fi
echo ""

#===============================================================================
# PHASE 3: SUBDOMAIN TAKEOVER DETECTION
#===============================================================================
echo -e "${BLUE}[PHASE 3]${NC} Subdomain Takeover Detection"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Download latest fingerprints
echo -e "${GREEN}[+]${NC} Downloading latest fingerprints from can-i-take-over-xyz..."
curl -s "${FINGERPRINTS_URL}" -o fingerprints.json 2>/dev/null || echo "[]" > fingerprints.json

if command -v subzy &> /dev/null; then
    echo -e "${GREEN}[+]${NC} Running subzy for takeover detection..."
    subzy run --targets all_subdomains.txt --output vulnerable_subdomains.json 2>/dev/null || touch vulnerable_subdomains.json
    
    # Check if any vulnerabilities were found
    if [ -s vulnerable_subdomains.json ]; then
        VULN_COUNT=$(cat vulnerable_subdomains.json | grep -c "vulnerable" 2>/dev/null || echo 0)
        echo -e "    └── ${RED}Potentially vulnerable subdomains: ${VULN_COUNT}${NC}"
    else
        echo -e "    └── ${GREEN}No obvious takeover vulnerabilities detected${NC}"
    fi
else
    echo -e "${RED}[!]${NC} subzy not installed. Skipping automated takeover detection."
    touch vulnerable_subdomains.json
fi

#===============================================================================
# PHASE 4: DNS ANALYSIS FOR DANGLING RECORDS
#===============================================================================
echo ""
echo -e "${BLUE}[PHASE 4]${NC} DNS Analysis for Dangling Records"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "${GREEN}[+]${NC} Checking for NXDOMAIN responses (dangling DNS)..."
> nxdomain_subdomains.txt
while read -r subdomain; do
    # Check if subdomain returns NXDOMAIN
    result=$(dig +short "$subdomain" 2>/dev/null)
    if [ -z "$result" ]; then
        # Double check with CNAME
        cname=$(dig CNAME +short "$subdomain" 2>/dev/null)
        if [ -n "$cname" ]; then
            echo "$subdomain -> CNAME: $cname (POTENTIAL TAKEOVER)" >> nxdomain_subdomains.txt
        fi
    fi
done < all_subdomains.txt

NXDOMAIN_COUNT=$(wc -l < nxdomain_subdomains.txt)
echo -e "    └── Subdomains with dangling CNAME records: ${YELLOW}${NXDOMAIN_COUNT}${NC}"
echo ""

#===============================================================================
# GENERATE REPORT
#===============================================================================
echo -e "${BLUE}[REPORT]${NC} Generating Summary Report"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat > report.md << EOF
# Subdomain Takeover Assessment Report

**Target Domain:** ${DOMAIN}  
**Scan Date:** $(date)  
**Output Directory:** ${OUTPUT_DIR}

## Summary Statistics

| Metric | Count |
|--------|-------|
| Total Unique Subdomains | ${TOTAL_COUNT} |
| Live Subdomains | ${LIVE_COUNT:-0} |
| Interesting Status Codes (502/503/404) | ${INTERESTING_COUNT:-0} |
| Dangling CNAME Records | ${NXDOMAIN_COUNT:-0} |

## Files Generated

- \`all_subdomains.txt\` - Complete list of discovered subdomains
- \`live_subdomains.txt\` - Live subdomains with status codes and IPs
- \`interesting_status.txt\` - Subdomains returning 502/503/404 errors
- \`nxdomain_subdomains.txt\` - Subdomains with dangling CNAME records
- \`vulnerable_subdomains.json\` - Potential takeover vulnerabilities (from subzy)
- \`fingerprints.json\` - Service fingerprints for takeover detection

## Recommended Actions

1. **Review \`nxdomain_subdomains.txt\`** - These are the highest priority. If a subdomain has a CNAME pointing to a service that no longer exists, it may be vulnerable to takeover.

2. **Review \`interesting_status.txt\`** - Subdomains returning 502/503 errors may indicate backend services that are down or misconfigured. These should be investigated.

3. **Review \`vulnerable_subdomains.json\`** - This file contains results from automated takeover detection. Manually verify each finding.

4. **For each potential vulnerability:**
   - Visit the subdomain in a browser
   - Check the error message against the [can-i-take-over-xyz](https://github.com/EdOverflow/can-i-take-over-xyz) repository
   - If vulnerable, remove the DNS record immediately

## References

- [OWASP Subdomain Takeover Testing Guide](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/02-Configuration_and_Deployment_Management_Testing/10-Test-for-Subdomain-Takeover)
- [can-i-take-over-xyz Repository](https://github.com/EdOverflow/can-i-take-over-xyz)
EOF

echo -e "${GREEN}[+]${NC} Report generated: ${YELLOW}report.md${NC}"
echo ""

#===============================================================================
# FINAL SUMMARY
#===============================================================================
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                      SCAN COMPLETE                            ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Results saved to: ${YELLOW}${OUTPUT_DIR}${NC}"
echo ""
echo -e "${GREEN}Key files to review:${NC}"
echo -e "  1. ${YELLOW}nxdomain_subdomains.txt${NC} - Dangling DNS records (HIGH PRIORITY)"
echo -e "  2. ${YELLOW}interesting_status.txt${NC} - 502/503/404 responses"
echo -e "  3. ${YELLOW}vulnerable_subdomains.json${NC} - Automated takeover detection results"
echo -e "  4. ${YELLOW}report.md${NC} - Full assessment report"
echo ""
