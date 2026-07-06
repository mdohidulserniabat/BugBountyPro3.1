# BugHunter Pro v4.0 — সম্পূর্ণ গাইড

## ফাইল Structure

```
bughunter_pro/
├── bughunter.sh
├── install.sh
├── setup_keys.sh
├── config.sh
├── core/
│   ├── bootstrap.sh
│   ├── cache.sh
│   ├── config.sh
│   ├── deps.sh
│   ├── queue.sh
│   ├── db.sh
│   ├── scoring.sh
│   └── plugins.sh
├── db/
│   ├── assets_schema.sql
│   └── migrations/
├── plugins/
│   └── README.md
├── modules/
│   ├── 01_subdomain.sh
│   ├── 02_urls_js.sh
│   ├── 03_api_nuclei_web.sh
│   ├── 04_sqli_secrets_recon.sh
│   ├── 05_report.sh
│   ├── 06_fixes.sh
│   └── 07_v4_engines.sh
└── reports/
```

---

## STEP 1 — ফাইল নামান ও Extract করুন

```bash
# ZIP নামানোর পর extract করুন
unzip bughunter_pro_v3.1.zip

# ফোল্ডারে ঢুকুন
cd bughunter_pro
```

---

## STEP 2 — Install (একবারই)

### Linux/macOS/WSL Installation

```bash
# Permission দিন
chmod +x install.sh

# Install চালান (ইন্টারনেট লাগবে, ১৫-৩০ মিনিট সময় লাগবে)
./install.sh
```

### Ubuntu/Linux Installation (Recommended)

**For Ubuntu/Debian-based systems:**

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required base dependencies
sudo apt install -y git curl wget python3 python3-pip sqlite3 jq nmap nikto build-essential

# Make scripts executable
chmod +x install.sh setup_keys.sh bughunter.sh

# Run the installer (this will auto-detect Ubuntu and use apt)
./install.sh
```

**For other Linux distributions:**

- **CentOS/RHEL/Fedora**: Uses `yum`/`dnf` automatically
- **Arch Linux**: Uses `pacman` automatically
- **Alpine**: Uses `apk` automatically

The `install.sh` script automatically detects your Linux distribution and uses
the appropriate package manager!

**install.sh যা করে:**

- **Automatic OS Detection**: Linux (apt/yum/apk), macOS (brew), Windows
  (choco/scoop/WSL)
- Go 1.22+ install করে (auto-detects latest stable version)
- ৩০+ Go tool install করে (subfinder, httpx, nuclei, dalfox ইত্যাদি)
- Python tool install করে (sqlmap, jwt_tool, trufflehog ইত্যাদি)
- sqlite3 install করে যাতে SQLite asset DB চালু থাকে
- Wordlist download করে
- Nuclei template update করে

**Optional deep-analysis tools:**

- nodejs/npm
- esprima
- tree-sitter
- tree-sitter-javascript
- semgrep

এগুলো না থাকলেও core scan চলবে, কিন্তু v4 JS analysis কম গভীর হবে।

**Install শেষে shell reload করুন:**

```bash
source ~/.bashrc
```

---

## STEP 3 — API Keys সেভ করুন (একবারই)

```bash
chmod +x setup_keys.sh
./setup_keys.sh
```

এটা চালালে প্রতিটা key এর জন্য prompt আসবে। **Blank রাখলে skip হবে** — সব key না
থাকলেও চলবে।

```
SHODAN_API_KEY: [আপনার key দিন অথবা Enter চাপুন]
GITHUB_TOKEN: [আপনার key দিন অথবা Enter চাপুন]
...
```

Key গুলো `~/.bughunter/config.sh` এ সেভ হয়। **পরের scan থেকে আর key দিতে হবে
না।**

Key আপডেট করতে চাইলে:

```bash
./setup_keys.sh          # আবার চালান
# অথবা সরাসরি edit করুন:
nano ~/.bughunter/config.sh
```

---

## STEP 4 — Scan চালান

```bash
chmod +x bughunter.sh

# Basic scan (2-6 hours for medium target)
./bughunter.sh -d example.com

# FAST MODE — 10x faster, skips brute/permutations (30-90 minutes)
./bughunter.sh -d example.com --fast

# FULL POWER MODE — All Nuclei templates + headless + network scans (6-24+ hours)
./bughunter.sh -d example.com --full-power

# Low RAM VPS এ (512MB) — Prevents OOM kills
./bughunter.sh -d example.com -t 10 -j 2

# Normal VPS (2GB) — Default balanced settings
./bughunter.sh -d example.com -t 30 -j 3

# High-end VPS (8GB+) — Maximum performance
./bughunter.sh -d example.com -t 80 -j 8

# Advanced v4 engines + checkpoint/cache (resume if interrupted)
./bughunter.sh -d example.com -m sub,url,js,api,nuclei,v4,report --checkpoint --cache

# v4 deep engine focus (JS/GraphQL/CSP analysis)
./bughunter.sh -d example.com -m sub,url,js,api,v4,report --checkpoint --cache

# Monitor mode (continuous scanning)
./bughunter.sh -d example.com --monitor --diff

# Background এ চালাতে চাইলে
nohup ./bughunter.sh -d example.com > scan.log 2>&1 &

# Log দেখতে
tail -f scan.log

# Windows PowerShell background
Start-Process -NoNewWindow -FilePath "bash" -ArgumentList "./bughunter.sh -d example.com"
```

---

## STEP 5 — Report দেখুন

Scan শেষ হলে একটা folder তৈরি হবে:

```
results_example.com_20240101_120000/
```

**Report খুলুন:**

```bash
# HTML report (browser এ)
firefox results_example.com_*/reports/report.html
# অথবা
xdg-open results_example.com_*/reports/report.html

# Windows
start results_example.com_*/reports/report.html

# Quick summary terminal এ
cat results_example.com_*/reports/summary.txt

# সব vulnerability দেখুন
cat results_example.com_*/findings.txt
```

---

## সব Options

```
./bughunter.sh -d <domain> [options]

  -d  Domain (required)        example.com
  -t  Threads (default 30)     -t 50
  -T  Timeout seconds (15)     -T 20
  -j  Parallel jobs (3)        -j 5      ← RAM control
  --resume                     Resume from checkpoint
  --checkpoint                 Save checkpoints after each module
  --cache                      Enable disk cache
  --fast                       FAST MODE: Skip slow sources (brute/permutations) → 10x speed!
  --full-power                 FULL POWER: Enable all Nuclei templates + headless + network scans
  --smart-limit                Enable intelligent rate limiting (prevents blocks)
  --burst-limit <n>            Max requests per second (default: 20)
  --parallel <n>               Alias for -j
  --memory-limit <profile>     512MB | 1GB | 2GB | 4GB | 8GB
  --cpu-limit <n|pct>          CPU cap (e.g. 2 or 75%)
  --continuous / --watch / --diff / --daily / --weekly / --monitor
  -o  Output folder            -o /tmp/results
  -m  Specific modules         -m sub,nuclei,report

  API keys (optional, config থেকে auto-load হয়):
  -s  Shodan key
  -g  GitHub token
  -C  Chaos key
  -c  Censys (id:secret)
```

---

## Specific Module চালানো

```bash
# শুধু subdomain বের করতে
./bughunter.sh -d example.com -m sub,report

# শুধু nuclei scan
./bughunter.sh -d example.com -m nuclei,report

# Subdomain + JS analysis + Nuclei
./bughunter.sh -d example.com -m sub,url,js,nuclei,report

# v4 deep engine run
./bughunter.sh -d example.com -m sub,url,js,api,v4,report

# Available modules:
# sub, url, js, api, nuclei, v4, web, sqli, xxe,
# smuggle, secrets, takeover, recon, modern,
# github, extra, waf, report

```

## v4 Engine Notes

- JS engine এখন AST/heuristic hybrid mode এ কাজ করে
- CSP engine trusted asset, nonce, blob/data, and gadget risk দেখে
- SSRF engine metadata, IMDS, OOB, and header bypass patterns ধরে
- GraphQL engine introspection, batching, and schema artifacts write করে
- API auth engine verb tampering, parameter pollution, এবং IDOR/BOLA ধরার চেষ্টা
  করে
- SQLite DB তে asset history, relationships, scores, and findings history রাখা
  হয়

---

## Output Folder Structure

```

results_example.com_TIMESTAMP/ ├── findings.txt ← সব vulnerability (timestamp
সহ) ├── subdomains/ │ ├── all_subdomains.txt ← সব subdomain │ ├── live.txt ←
Live HTTP hosts │ └── technologies.txt ← কোন host এ কোন technology ├── urls/ │
├── all_urls.txt ← সব URL │ ├── js_files.txt ← JavaScript files │ ├──
unique_params.txt ← সব parameter │ └── gf_xss.txt ← XSS candidate URLs ├──
vulns/ │ ├── nuclei/ ← Nuclei results (15 ক্যাটাগরি) │ ├── xss/ ← XSS findings │
├── sqli/ ← SQL injection │ ├── graphql/ ← GraphQL issues │ ├── jwt/ ← JWT
vulnerabilities │ ├── cors/ ← CORS misconfigs │ ├── secrets/ ← API keys,
passwords │ ├── modern/ ← OAuth, WebSocket, Race condition │ ├── js/ ← DOM XSS,
prototype pollution │ └── v4/ ← AST, CSP, SSRF, GraphQL, API auth ├── db/ │ └──
bughunter.db ← SQLite asset intelligence DB ├── takeover/ ← Subdomain takeover
├── recon/ ← DNS, WHOIS, ports ├── screenshots/ ← Website screenshots └──
reports/ ├── report.html ← Full interactive HTML report ├── report.md ← Markdown
report ├── report.json ← JSON report ├── report.csv ← CSV report └── summary.txt
← Quick text summary

```

---

## API Key কোথায় পাবেন (সব Free)

| Key            | Link                                 | কী পাবেন          |
| -------------- | ------------------------------------ | ----------------- |
| Shodan         | https://account.shodan.io/           | Free tier আছে     |
| GitHub Token   | https://github.com/settings/tokens   | Completely free   |
| Chaos          | https://chaos.projectdiscovery.io/   | Free registration |
| SecurityTrails | https://securitytrails.com/          | Free 50 req/month |
| Censys         | https://search.censys.io/account/api | Free tier         |

---

## Telegram Notification Setup

Scan শেষ হলে phone এ message পাবেন:

**1. Bot বানান:**

- Telegram এ `@BotFather` তে যান
- `/newbot` টাইপ করুন
- Bot name দিন
- Token copy করুন

**2. Chat ID বের করুন:**

- `@userinfobot` এ `/start` পাঠান
- আপনার ID দেখাবে

**3. setup_keys.sh এ দিন:**

```bash
./setup_keys.sh
# Telegram Bot Token: [token]
# Telegram Chat ID: [id]
```

এখন প্রতিটা scan শেষে এরকম message আসবে:

```
  🔍 BugHunter Pro v4.0
✅ Scan complete: example.com
⏱ Duration: 47m
🚨 Findings: 12
```

---

## Common Errors & Fix

**Error: `go: command not found`**

```bash
source ~/.bashrc
# অথবা
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
```

**Error: `nuclei: command not found`**

```bash
export PATH=$PATH:$HOME/go/bin
# অথবা install আবার চালান
./install.sh
```

**Error: `sqlite3: command not found`**

```bash
# install আবার চালান যাতে sqlite3 base package আসে
./install.sh
```

**Error: `Permission denied`**

```bash
chmod +x bughunter.sh install.sh setup_keys.sh
chmod +x modules/*.sh
```

**Scan অনেক slow:**

```bash
# Use FAST mode for 10x speed improvement
./bughunter.sh -d example.com --fast

# Or reduce threads/jobs
./bughunter.sh -d example.com -t 10 -j 2
```

**Out of memory (VPS killed):**

```bash
# Use FAST mode + reduce jobs
./bughunter.sh -d example.com --fast -t 10 -j 1

# Or use memory profile
./bughunter.sh -d example.com --memory-limit 512MB
```

**Subdomain enumeration taking 2+ days:**

```bash
# This is normal for large targets with brute force enabled
# Use FAST mode to skip brute force and permutations:
./bughunter.sh -d example.com --fast -m sub,url,report

# Then run deeper scans only on live hosts:
./bughunter.sh -d example.com -m nuclei,v4,api,web,report
```

**Linux: Command not found errors**

```bash
# Make sure you're in the correct directory
cd /path/to/bughunter_pro

# Ensure scripts are executable
chmod +x *.sh modules/*.sh

# Add Go binaries to PATH if needed
export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
source ~/.bashrc
```

---

## ⚠️ Important

```
শুধুমাত্র authorized target এ ব্যবহার করুন।
Bug bounty program: HackerOne, Bugcrowd, Intigriti
নিজের domain বা written permission আছে এমন target।
```

# Performance Optimization & Realistic Expectations

## ⚡ Speed vs Coverage Trade-offs

**Subdomain Enumeration Time:**

- **FAST MODE** (`--fast`): 5-15 minutes (top 5 sources only)
- **Normal Mode**: 1-3 hours (20+ sources, permutations, brute force)
- **Large Targets** (10k+ subdomains): Can take 6-12+ hours

**Nuclei Scanning Time:**

- **Normal Mode**: 2-8 hours (priority templates only)
- **FULL POWER MODE** (`--full-power`): 8-48+ hours (all templates + headless)

## 🎯 Recommended Approach for Large Targets

**Don't run everything at once!** Use this phased approach:

```bash
# PHASE 1: Quick reconnaissance (30-60 minutes)
./bughunter.sh -d example.com --fast -m sub,url,js,report

# PHASE 2: Deep analysis on live hosts only (2-6 hours)
./bughunter.sh -d example.com -m nuclei,v4,api,web,report

# PHASE 3: Full power scan if needed (8-24+ hours)
./bughunter.sh -d example.com --full-power -m nuclei,report

# FULL POWER + RATE LIMITING (recommended for large targets to avoid blocks)
./bughunter.sh -d example.com --full-power --smart-limit --burst-limit 10
```

## 💡 Pro Tips to Avoid 2-Day Scans

1. **Use `--fast` flag** for initial reconnaissance
2. **Limit modules** to what you need: `-m sub,url,nuclei,report`
3. **Reduce threads/jobs** on shared/VPS environments: `-t 20 -j 2`
4. **Use checkpointing** to resume interrupted scans: `--checkpoint --resume`
5. **Start with critical modules only**: subdomain → URL → Nuclei → v4 engines

## 🔧 Resource Management

| VPS Size          | Threads | Jobs | Expected Time |
| ----------------- | ------- | ---- | ------------- |
| 512MB RAM         | 10      | 2    | 8-24 hours    |
| 2GB RAM (default) | 30      | 3    | 4-12 hours    |
| 8GB+ RAM          | 80      | 8    | 2-8 hours     |

**Memory Usage Warning:**

- Subdomain brute force and permutations are memory-intensive
- Nuclei headless mode requires 2GB+ RAM per job
- Use `--fast` mode on low-RAM systems to avoid crashes

## 🚦 Rate Limiting Best Practices

**Avoid getting blocked by targets:**

- **Enable smart limiting**: `--smart-limit` adds random jitter and intelligent
  delays
- **Control burst requests**: `--burst-limit 10` limits to 10 requests/second
  (default: 20)
- **Use for large targets**: Always combine with `--full-power` for extended
  scans
- **Legal compliance**: Consider `--compliance` mode to respect robots.txt and
  security.txt

**NEW: Adaptive Rate Limiting**

- Automatically slows down when target returns 429 (Too Many Requests) or 5xx
  errors
- Speeds back up when target responds normally
- Prevents accidental DoS while maintaining efficiency

**Example for safe full power scanning:**

```bash
./bughunter.sh -d example.com --full-power --smart-limit --burst-limit 15
```

## 🛡️ Enhanced Safety Features (v3.1)

Your tool now includes **advanced safety mechanisms** to prevent DoS/DDoS:

### ✅ **Automatic Content-Type Filtering**

- Skips non-relevant content types (images, videos, binaries)
- Reduces unnecessary requests by 30-60%
- Focuses only on HTML, JSON, XML, and text responses

### ✅ **Response Size Limits**

- Maximum response size: 1MB per request (configurable)
- Prevents memory exhaustion from large file downloads
- Avoids triggering anti-bot protections

### ✅ **Adaptive Request Throttling**

- Monitors target response codes in real-time
- Automatically reduces speed on rate limit errors
- Gradually increases speed when target is responsive

### ✅ **Compliance Mode**

- Respects `robots.txt` disallow rules
- Checks `security.txt` for authorized testing guidelines
- Follows legal and ethical scanning practices

## 🔬 Accuracy Improvements

### **Reduced False Positives**

- Content-type validation before deep analysis
- Response size filtering to avoid binary false positives
- Smart timeout handling for slow/unresponsive endpoints

### **Intelligent Target Selection**

- Prioritizes live, responsive hosts
- Skips known CDN/WAF endpoints for certain tests
- Focuses resources on high-value targets

## ⚠️ **Critical Safety Guidelines**

**NEVER use without these settings on production targets:**

```bash
# Minimum safe configuration
./bughunter.sh -d example.com --smart-limit --burst-limit 10 --timeout 20

# For sensitive/production environments
./bughunter.sh -d example.com --fast --smart-limit --burst-limit 5 --compliance
```

**Always verify you have written authorization before scanning!**

## 📊 What "Full Power" Actually Does

The `--full-power` flag enables:

- ✅ All Nuclei templates (including low severity)
- ✅ Headless browser testing (requires Chrome/Chromium)
- ✅ Network protocol scanning (DNS, SSL/TLS)
- ✅ Fuzzing templates
- ✅ Workflow templates
- ✅ Custom template execution

**Use `--full-power` only when:**

- You have 8GB+ RAM and dedicated resources
- Target is critical/high-value
- You can afford 24+ hour scan times
- You need comprehensive coverage for compliance

For most bug bounty work, **normal mode with priority templates is sufficient**
and finds 95% of critical issues in 1/4 the time.
