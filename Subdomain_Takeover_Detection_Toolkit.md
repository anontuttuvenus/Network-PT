# Subdomain Takeover Detection Toolkit

A comprehensive toolkit for identifying and mitigating subdomain takeover vulnerabilities. This toolkit automates the process of subdomain enumeration, live host detection, and vulnerability identification.

## Table of Contents

- [Overview](#overview)
- [What is Subdomain Takeover?](#what-is-subdomain-takeover)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Tools Included](#tools-included)
- [Usage Guide](#usage-guide)
- [Vulnerable Services](#vulnerable-services)
- [Remediation](#remediation)
- [References](#references)

## Overview

This toolkit provides an end-to-end solution for:

1. **Subdomain Enumeration** - Discover all subdomains using multiple sources
2. **Live Host Detection** - Identify which subdomains are active
3. **Takeover Detection** - Find subdomains vulnerable to takeover
4. **Reporting** - Generate comprehensive reports for your security team

## What is Subdomain Takeover?

A subdomain takeover occurs when:

1. A subdomain (e.g., `blog.example.com`) has a DNS record pointing to a third-party service
2. The service is no longer in use or has been deleted
3. An attacker can claim the subdomain by creating an account on that service

**Impact:** An attacker controlling your subdomain can:
- Host phishing pages that appear legitimate
- Steal cookies set on the parent domain
- Bypass Content Security Policy (CSP)
- Damage your organization's reputation

## Installation

### Prerequisites

- Ubuntu/Debian Linux (or compatible)
- sudo privileges
- Internet connection

### Automated Installation

```bash
chmod +x install_tools.sh
./install_tools.sh
```

### Manual Installation

```bash
# Install Go
wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

# Install tools
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/PentestPad/subzy@latest
sudo pip3 install sublist3r
sudo apt-get install -y jq
```

## Quick Start

### Option 1: Bash Script (Recommended)

```bash
./subdomain_takeover.sh example.com
```

This will:
1. Enumerate subdomains from multiple sources
2. Probe for live hosts
3. Check for takeover vulnerabilities
4. Generate a report in `./results_example.com_TIMESTAMP/`

### Option 2: Python Script

```bash
# Check a list of subdomains
python3 takeover_checker.py -i subdomains.txt -o results.json

# Check a single domain
python3 takeover_checker.py -d blog.example.com
```

### Option 3: Manual Step-by-Step

```bash
# Step 1: Enumerate subdomains
curl -s "https://crt.sh/?q=%25.example.com&output=json" | jq -r '.[].name_value' | sed 's/\*\.//g' | sort -u > crtsh.txt
subfinder -d example.com -o subfinder.txt
sublist3r -d example.com -o sublist3r.txt

# Step 2: Combine results
cat crtsh.txt subfinder.txt sublist3r.txt | sort -u > all_subdomains.txt

# Step 3: Probe live hosts
cat all_subdomains.txt | httpx -silent -status-code -ip -o live.txt

# Step 4: Check for takeovers
subzy run --targets all_subdomains.txt --output vulnerable.json
```

## Tools Included

| Tool | Purpose | Source |
|------|---------|--------|
| **subfinder** | Passive subdomain enumeration | [ProjectDiscovery](https://github.com/projectdiscovery/subfinder) |
| **httpx** | HTTP probing with status codes | [ProjectDiscovery](https://github.com/projectdiscovery/httpx) |
| **sublist3r** | OSINT subdomain enumeration | [aboul3la](https://github.com/aboul3la/Sublist3r) |
| **subzy** | Subdomain takeover detection | [PentestPad](https://github.com/PentestPad/subzy) |
| **jq** | JSON processing | System package |

## Usage Guide

### subdomain_takeover.sh

```bash
Usage: ./subdomain_takeover.sh <domain> [output_directory]

Arguments:
  domain           Target domain (e.g., example.com)
  output_directory Optional output directory (default: ./results_<domain>_<timestamp>)

Example:
  ./subdomain_takeover.sh example.com
  ./subdomain_takeover.sh example.com ./my_results
```

### takeover_checker.py

```bash
Usage: python3 takeover_checker.py [options]

Options:
  -i, --input FILE      Input file with subdomains (one per line)
  -d, --domain DOMAIN   Single domain to check
  -o, --output FILE     Output JSON file (default: takeover_results.json)
  -t, --threads N       Number of concurrent threads (default: 10)
  --timeout N           Request timeout in seconds (default: 10)
  --vulnerable-only     Only output vulnerable subdomains

Examples:
  python3 takeover_checker.py -i subdomains.txt
  python3 takeover_checker.py -d blog.example.com
  python3 takeover_checker.py -i subs.txt -t 20 --vulnerable-only
```

## Vulnerable Services

The following services are known to be vulnerable to subdomain takeover:

| Service | Fingerprint | Status |
|---------|-------------|--------|
| AWS S3 | "The specified bucket does not exist" | Vulnerable |
| AWS Elastic Beanstalk | NXDOMAIN | Vulnerable |
| GitHub Pages | "There isn't a GitHub Pages site here" | Edge Case |
| Heroku | "No such app" | Edge Case |
| Shopify | "Sorry, this shop is currently unavailable" | Edge Case |
| Surge.sh | "project not found" | Vulnerable |
| Ghost | "Site unavailable" | Vulnerable |
| Pantheon | "404 error unknown site!" | Vulnerable |
| Microsoft Azure | NXDOMAIN | Vulnerable |
| Bitbucket | "Repository not found" | Vulnerable |
| WordPress.com | "Do you want to register" | Vulnerable |
| Netlify | "Not Found - Request ID:" | Edge Case |
| Vercel | "DEPLOYMENT_NOT_FOUND" | Edge Case |

For a complete list, see [can-i-take-over-xyz](https://github.com/EdOverflow/can-i-take-over-xyz).

## Remediation

When a vulnerable subdomain is identified:

1. **Immediate Action:** Remove the dangling DNS record from your DNS zone
2. **Verification:** Confirm the subdomain no longer resolves
3. **Documentation:** Document the finding and remediation for audit purposes

### Prevention Best Practices

- **Regular Audits:** Schedule periodic DNS record audits
- **Decommissioning Process:** Include DNS cleanup in service decommissioning procedures
- **Monitoring:** Implement continuous monitoring for subdomain changes
- **Inventory:** Maintain an up-to-date inventory of all subdomains and their purposes

## Output Files

After running the toolkit, you'll find these files in the output directory:

| File | Description |
|------|-------------|
| `all_subdomains.txt` | Complete list of discovered subdomains |
| `live_subdomains.txt` | Live subdomains with status codes and IPs |
| `interesting_status.txt` | Subdomains with 502/503/404 errors |
| `nxdomain_subdomains.txt` | Subdomains with dangling CNAME records |
| `vulnerable_subdomains.json` | Potential takeover vulnerabilities |
| `report.md` | Summary report |

## References

- [OWASP Testing Guide - Subdomain Takeover](https://owasp.org/www-project-web-security-testing-guide/latest/4-Web_Application_Security_Testing/02-Configuration_and_Deployment_Management_Testing/10-Test-for-Subdomain-Takeover)
- [can-i-take-over-xyz](https://github.com/EdOverflow/can-i-take-over-xyz)
- [HackerOne - Guide to Subdomain Takeovers](https://www.hackerone.com/blog/guide-subdomain-takeovers)
- [Microsoft - Prevent Dangling DNS Entries](https://learn.microsoft.com/en-us/azure/security/fundamentals/subdomain-takeover)

## License

This toolkit is provided for educational and authorized security testing purposes only. Always ensure you have proper authorization before testing any systems.

---

**Author:** Manus AI  
**Date:** January 2026
