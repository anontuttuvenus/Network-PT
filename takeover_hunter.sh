#!/bin/bash
# Subdomain Takeover Hunter - Automated Workflow

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 <domain>"
    echo "Example: $0 example.com"
    exit 1
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Subdomain Takeover Hunter                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}[*] Target: $DOMAIN${NC}"
echo ""

OUTPUT="takeover_${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT"
cd "$OUTPUT"

# PHASE 1: ENUMERATION
echo -e "${GREEN}[+] Phase 1: Subdomain Enumeration${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null | \
  jq -r '.[].name_value' 2>/dev/null | \
  sed 's/\*\.//g' | sort -u > crtsh.txt

if command -v subfinder &> /dev/null; then
    subfinder -d "$DOMAIN" -all -silent -o subfinder.txt 2>/dev/null
else
    touch subfinder.txt
fi

cat crtsh.txt subfinder.txt 2>/dev/null | sort -u > all_subdomains.txt
echo -e "${GREEN}[✓] Found $(wc -l < all_subdomains.txt) subdomains${NC}"
echo ""

# PHASE 2: PROBING
echo -e "${GREEN}[+] Phase 2: HTTP Probing${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v httpx &> /dev/null; then
    cat all_subdomains.txt | httpx -silent -status-code -threads 50 -o httpx_results.txt 2>/dev/null
    echo -e "${GREEN}[✓] Live: $(wc -l < httpx_results.txt 2>/dev/null || echo 0)${NC}"
fi
echo ""

# PHASE 3: DNS CNAME
echo -e "${GREEN}[+] Phase 3: CNAME Analysis${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cat all_subdomains.txt | while read sub; do
    cname=$(dig +short CNAME "$sub" 2>/dev/null | tail -1)
    [ ! -z "$cname" ] && echo "$sub → $cname" >> cnames.txt
done

if [ -f cnames.txt ]; then
    grep -E "amazonaws|herokuapp|github\.io|azurewebsites|shopify" cnames.txt > vulnerable_cnames.txt 2>/dev/null
    [ -s vulnerable_cnames.txt ] && echo -e "${YELLOW}[!] Vulnerable patterns: $(wc -l < vulnerable_cnames.txt)${NC}"
fi
echo ""

# PHASE 4: DETECTION
echo -e "${GREEN}[+] Phase 4: Takeover Detection${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v subjack &> /dev/null; then
    subjack -w all_subdomains.txt -t 100 -timeout 30 -o subjack.txt -ssl 2>/dev/null
fi

if command -v nuclei &> /dev/null; then
    cat all_subdomains.txt | nuclei -t ~/nuclei-templates/takeovers/ -silent -o nuclei.txt 2>/dev/null
fi

echo -e "${GREEN}[✓] Automated scans complete${NC}"
echo ""

# SUMMARY
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
cat > summary.txt << EOF
Subdomain Takeover Hunt - $DOMAIN
Date: $(date)

Subdomains: $(wc -l < all_subdomains.txt)
Live: $(wc -l < httpx_results.txt 2>/dev/null || echo 0)
CNAMEs: $(wc -l < cnames.txt 2>/dev/null || echo 0)
Vulnerable: $(wc -l < vulnerable_cnames.txt 2>/dev/null || echo 0)

Review: vulnerable_cnames.txt
EOF

cat summary.txt
echo ""
echo -e "${YELLOW}Results in: $(pwd)${NC}"
