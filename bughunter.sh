#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   BUGHUNTER PRO v3.1 — Ultimate Bug Hunting Framework           ║
# ║   All audit issues fixed | Memory-safe | Low FP | OOB support  ║
# ╚══════════════════════════════════════════════════════════════════╝

set -uo pipefail
umask 077

# ── Colors ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'
BOLD='\033[1m'; NC='\033[0m'

# ── Globals ─────────────────────────────────────────────────────────
DOMAIN=""; OUTPUT_DIR=""; THREADS=30; TIMEOUT=15; MAX_JOBS=3
PERM_WORDLIST_LIMIT=5000
PERM_TIMEOUT=15
DOMAIN_RE=""
START_TIME=$(date +%s); TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAST_MODE=0

# Optional API keys — set via env or -s/-g flags
SHODAN_API_KEY="${SHODAN_API_KEY:-}"
CENSYS_API_ID="${CENSYS_API_ID:-}"; CENSYS_API_SECRET="${CENSYS_API_SECRET:-}"
CHAOS_KEY="${CHAOS_KEY:-}"; GITHUB_TOKEN="${GITHUB_TOKEN:-}"
SECURITYTRAILS_KEY="${SECURITYTRAILS_KEY:-}"
FOFA_EMAIL="${FOFA_EMAIL:-}"; FOFA_KEY="${FOFA_KEY:-}"
ZOOMEYE_KEY="${ZOOMEYE_KEY:-}"; NETLAS_KEY="${NETLAS_KEY:-}"
FULLHUNT_KEY="${FULLHUNT_KEY:-}"
OPENAI_API_KEY="${OPENAI_API_KEY:-}"; GEMINI_API_KEY="${GEMINI_API_KEY:-}"
APK_FILE="${APK_FILE:-}"
RESUME=0; CHECKPOINT=0; CACHE=0
MEMORY_LIMIT="${MEMORY_LIMIT:-}"; CPU_LIMIT="${CPU_LIMIT:-}"
BH_LAST_STEP=""; BH_CURRENT_STEP=""
BH_STEP_ORDER=(recon sub extra github url js secrets takeover nuclei api web v4 sqli xxe smuggle modern waf cloud react fuzz cms apk ai exploit report)

CONTINUOUS=0; WATCH=0; DIFF=0; DAILY=0; WEEKLY=0; MONITOR=0
FULL_POWER=0; SMART_LIMIT=0; BURST_LIMIT=20; COMPLIANCE_MODE=0

TOTAL_FINDINGS=0

# ── Default Limits ──────────────────────────────────────────────────
MAX_RESPONSE_SIZE="${MAX_RESPONSE_SIZE:-1048576}"  # 1MB default response size limit

# ── Config Auto-Load ────────────────────────────────────────────────
# ~/.bughunter/config.sh থেকে API keys load করে
# -s/-g flag দিলে সেটা config এর উপর override করে
CONFIG_FILE="${HOME}/.bughunter/config.sh"
if [[ -f "$CONFIG_FILE" ]]; then
  source "$CONFIG_FILE"
fi



# Smart rate limiting with burst control
smart_curl() {
  local url="$1"
  local max_burst="${BH_BURST_LIMIT:-20}"
  local delay=$(( 1000000 / max_burst ))  # microseconds
  
  # Add random jitter to avoid detection
  local jitter=$(( RANDOM % 500000 ))
  local total_delay=$(( delay + jitter ))
  
  usleep "$total_delay"
  curl -s --max-time "${TIMEOUT:-15}" "$url"
}

# Compliance check for robots.txt and security.txt
compliance_check() {
  if [[ "${BH_COMPLIANCE_MODE:-0}" == "1" ]]; then
    # Check robots.txt for disallowed paths
    ROBOTS=$(curl -s --max-time 10 "https://$DOMAIN/robots.txt" 2>/dev/null)
    if [[ -n "$ROBOTS" ]]; then
      echo "$ROBOTS" > "$OUTPUT_DIR/recon/robots.txt"
      log_info "Compliance: robots.txt saved"
    fi
    
    # Check security.txt
    SECURITY=$(curl -s --max-time 10 "https://$DOMAIN/.well-known/security.txt" 2>/dev/null)
    if [[ -n "$SECURITY" ]]; then
      echo "$SECURITY" > "$OUTPUT_DIR/recon/security.txt"
      log_info "Compliance: security.txt saved"
    fi
  fi
}

# Real-time bug notification to Telegram
notify_bug_telegram() {
  local severity="$1"
  local bug_type="$2"
  local url="$3"
  local description="$4"
  
  # Only notify if Telegram is configured
  if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]] || [[ -z "${TELEGRAM_CHAT_ID:-}" ]]; then
    return 0
  fi
  
  # Set emoji based on severity
  local emoji=""
  case "$severity" in
    "CRITICAL") emoji="🔴" ;;
    "HIGH")     emoji="🟠" ;;
    "MEDIUM")   emoji="🟡" ;;
    "LOW")      emoji="🟢" ;;
    *)          emoji="🔵" ;;
  esac
  
  # Format message with URL encoding
  local msg="${emoji} *NEW BUG FOUND*\n"
  msg+="*Target:* \`$DOMAIN\`\n"
  msg+="*Severity:* ${severity}\n"
  msg+="*Type:* ${bug_type}\n"
  msg+="*URL:* ${url}\n"
  if [[ -n "$description" ]]; then
    msg+="*Details:* ${description}\n"
  fi
  msg+="*Time:* $(date '+%Y-%m-%d %H:%M:%S')\n"
  
  # Send to Telegram
  curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${TELEGRAM_CHAT_ID}&text=${msg}&parse_mode=Markdown&disable_web_page_preview=true" \
    > /dev/null 2>&1 || true
}

source "$SCRIPT_DIR/core/bootstrap.sh"
source "$SCRIPT_DIR/core/queue.sh"
source "$SCRIPT_DIR/core/config.sh"
source "$SCRIPT_DIR/core/deps.sh"
source "$SCRIPT_DIR/core/scoring.sh"
source "$SCRIPT_DIR/core/cache.sh"
source "$SCRIPT_DIR/core/db.sh"
source "$SCRIPT_DIR/core/plugins.sh"

# ── Banner ──────────────────────────────────────────────────────────
banner() {
  clear
  echo -e "${RED}${BOLD}"
  cat << 'BANNER'
  ██████╗ ██╗   ██╗ ██████╗ ██╗  ██╗██╗   ██╗███╗   ██╗████████╗███████╗██████╗
  ██╔══██╗██║   ██║██╔════╝ ██║  ██║██║   ██║████╗  ██║╚══██╔══╝██╔════╝██╔══██╗
  ██████╔╝██║   ██║██║  ███╗███████║██║   ██║██╔██╗ ██║   ██║   █████╗  ██████╔╝
  ██╔══██╗██║   ██║██║   ██║██╔══██║██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██╔══██╗
  ██████╔╝╚██████╔╝╚██████╔╝██║  ██║╚██████╔╝██║ ╚████║   ██║   ███████╗██║  ██║
  ╚═════╝  ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═╝
BANNER
  echo -e "${NC}"
  echo -e "${CYAN}${BOLD}              ULTIMATE FRAMEWORK v3.1 — ALL ISSUES FIXED${NC}"
  echo -e "${YELLOW}  Memory-safe | OOB XXE | Full JWT | All clouds | Low FP | Modern attacks${NC}"
  echo -e "${GREEN}  Created by: SmBugHunter404${NC}"
  echo ""
}

# ── Usage ───────────────────────────────────────────────────────────
usage() {
  cat << HELP
${BOLD}Usage:${NC} $0 -d <domain> [options]

${BOLD}Required:${NC}
  -d <domain>        Target domain (e.g. example.com)

${BOLD}Performance:${NC}
  -t <threads>       Threads per tool    (default: 30)
  -T <timeout>       Timeout seconds     (default: 15)
  -j <max_jobs>      Parallel jobs       (default: 3)  ← FIXED #5
  --parallel <n>     Alias for -j
  --memory-limit     Memory hint (512MB/1GB/2GB/4GB/8GB)
  --cpu-limit       CPU hint as count or percent
  --max-response-size Maximum response size in bytes (default: 1048576 = 1MB)
  --resume          Resume from checkpoint
  --checkpoint      Persist checkpoints after each module
  --cache           Enable disk cache
  --fast            FAST MODE: Skip slow sources (brute/permutations) → 10x speed!
  --full-power      FULL POWER: Enable all Nuclei templates + headless + network scans
  --smart-limit     Enable adaptive rate limiting (slows on 429/5xx, prevents blocks)
  --burst-limit     Max requests per second (default: 20)
  --compliance      Legal compliance mode (respects robots.txt, security.txt)
  --continuous      Continuous monitoring loop
  --watch           Short-interval watch mode
  --diff            Compare with previous snapshot
  --daily           Daily monitoring cadence
  --weekly          Weekly monitoring cadence
  --monitor         Refresh snapshot and diff once

${BOLD}Advanced tuning via environment:${NC}
  PERM_WORDLIST_LIMIT   Permutation wordlist cap (default: 5000)
  PERM_TIMEOUT          Timeout for dnsgen/gotator/altdns (default: 15)

${BOLD}Output:${NC}
  -o <dir>           Output directory

${BOLD}Modules (comma-separated, default: all):${NC}
  sub       Subdomain enumeration (20+ sources)
  url       URL + endpoint collection
  js        JavaScript deep analysis
  api       API security testing
  nuclei    Nuclei scanning (priority order)
  v4        Advanced v4 engines (JS/CSP/SSRF/GraphQL/Auth)
  web       Web vulnerabilities
  sqli      SQL/NoSQL injection
  xxe       XXE injection (OOB)
  smuggle   HTTP request smuggling (proper tools)
  secrets   Secret detection (entropy-checked)
  takeover  Subdomain takeover
  recon     DNS/infra recon
  modern    Modern attacks (OAuth/SAML/WS/race)
  github    GitHub recon (dedicated tools)
  extra     Extra recon sources
  waf       WAF detection
  cloud     Cloud asset discovery (AWS/Azure/GCP)
  react     React/Next.js framework analysis
  fuzz      Deep fuzzing with Wayback/gau and ffuf
  cms       CMS Scanner (WordPress/Drupal/Joomla)
  apk       APK/Mobile App Extractor
  ai        AI-Powered analysis (requires OPENAI/GEMINI key)
  exploit   Auto Exploiter (PoC generator)
  report    HTML/MD/TXT report

${BOLD}API Keys (optional, improve results):${NC}
  -s <key>           Shodan
  -g <token>         GitHub token
  -C <key>           Chaos (ProjectDiscovery)
  -c <id:secret>     Censys
  -O <key>           OpenAI API Key
  -G <key>           Gemini API Key
  --apk <file>       Path to APK file for APK module

${BOLD}Via environment variables:${NC}
  export SECURITYTRAILS_KEY=xxx
  export FOFA_EMAIL=x FOFA_KEY=x
  export ZOOMEYE_KEY=xxx
  export NETLAS_KEY=xxx
  export FULLHUNT_KEY=xxx

${BOLD}Examples:${NC}
  $0 -d example.com
  $0 -d example.com -t 50 -j 5 -s SHODAN_KEY -g GITHUB_TOKEN
  $0 -d example.com -m sub,nuclei,report
  $0 -d example.com -j 2    # low-RAM VPS (512MB)

${BOLD}Resource presets:${NC}
  Low RAM  (512MB):  -t 10 -j 2
  Mid RAM  (2GB):    -t 30 -j 3  (default)
  High RAM (8GB+):   -t 80 -j 8
HELP
  exit 1
}

# ── Parse Args ──────────────────────────────────────────────────────
parse_args() {
  local MODULES_ARG="all"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d|--domain) DOMAIN="${2,,}"; shift 2 ;;
      -o|--output) OUTPUT_DIR="$2"; shift 2 ;;
      -t|--threads) THREADS="$2"; shift 2 ;;
      -T|--timeout) TIMEOUT="$2"; shift 2 ;;
      -j|--jobs|--parallel) MAX_JOBS="$2"; shift 2 ;;
      --memory-limit) MEMORY_LIMIT="$2"; shift 2 ;;
      --cpu-limit) CPU_LIMIT="$2"; shift 2 ;;
      --max-response-size) MAX_RESPONSE_SIZE="$2"; shift 2 ;;
      --resume) RESUME=1; shift ;;
      --checkpoint) CHECKPOINT=1; shift ;;
      --cache) CACHE=1; shift ;;
      --fast) FAST_MODE=1; shift ;;
      --full-power) FULL_POWER=1; shift ;;
      --smart-limit) SMART_LIMIT=1; shift ;;
      --burst-limit) BURST_LIMIT="$2"; shift 2 ;;
      --compliance) COMPLIANCE_MODE=1; shift ;;
      --continuous) CONTINUOUS=1; shift ;;
      --watch) WATCH=1; shift ;;
      --diff) DIFF=1; shift ;;
      --daily) DAILY=1; shift ;;
      --weekly) WEEKLY=1; shift ;;
      --monitor) MONITOR=1; shift ;;
      -m|--modules) MODULES_ARG="$2"; shift 2 ;;
      -s|--shodan) SHODAN_API_KEY="$2"; shift 2 ;;
      -g|--github) GITHUB_TOKEN="$2"; shift 2 ;;
      -c|--censys) CENSYS_API_ID="${2%%:*}"; CENSYS_API_SECRET="${2##*:}"; shift 2 ;;
      -C|--chaos) CHAOS_KEY="$2"; shift 2 ;;
      -O|--openai) OPENAI_API_KEY="$2"; shift 2 ;;
      -G|--gemini) GEMINI_API_KEY="$2"; shift 2 ;;
      --apk) APK_FILE="$2"; shift 2 ;;
      -h|--help) usage ;;
      --) shift; break ;;
      *) log_error "Unknown option: $1"; usage ;;
    esac
  done
  [[ -z "$DOMAIN" ]] && { log_error "Domain required!"; usage; }
  OUTPUT_DIR="${OUTPUT_DIR:-results_${DOMAIN}_${TIMESTAMP}}"

  # Parse module list
  for m in SUB URL JS API NUCLEI V4 WEB SQLI XXE SMUGGLE SECRETS TAKEOVER \
            RECON MODERN GITHUB EXTRA WAF CLOUD REACT FUZZ CMS APK AI EXPLOIT REPORT; do
    eval "RUN_$m=0"
  done
  eval "RUN_REPORT=1"

  if [[ "$MODULES_ARG" == "all" ]]; then
    for m in SUB URL JS API NUCLEI V4 WEB SQLI XXE SMUGGLE SECRETS TAKEOVER \
          RECON MODERN GITHUB EXTRA WAF CLOUD REACT FUZZ CMS APK AI EXPLOIT REPORT; do
      eval "RUN_$m=1"
    done
  else
    IFS=',' read -ra MODS <<< "$MODULES_ARG"
    for m in "${MODS[@]}"; do
      eval "RUN_${m^^}=1" 2>/dev/null || true
    done
  fi

  : "${MAX_RESPONSE_SIZE:=1048576}"  # 1MB default response size limit
  export BH_MEMORY_LIMIT="$MEMORY_LIMIT"
  export BH_CPU_LIMIT="$CPU_LIMIT"
  export BH_MAX_RESPONSE_SIZE="$MAX_RESPONSE_SIZE"
  export BH_CACHE_ENABLED="$CACHE"
  export BH_CONTINUOUS="$CONTINUOUS"
  export BH_WATCH="$WATCH"
  export BH_DIFF="$DIFF"
  export BH_DAILY="$DAILY"
  export BH_WEEKLY="$WEEKLY"
  export BH_MONITOR="$MONITOR"
  export BH_FAST_MODE="$FAST_MODE"
  export BH_FULL_POWER="$FULL_POWER"
  export BH_SMART_LIMIT="$SMART_LIMIT"
  export BH_BURST_LIMIT="$BURST_LIMIT"
  export BH_COMPLIANCE_MODE="$COMPLIANCE_MODE"
  export MAX_JOBS
}

# ── Setup ───────────────────────────────────────────────────────────
setup() {
  mkdir -p "$OUTPUT_DIR"/{subdomains,urls,ports,screenshots,recon,takeover,reports}
  mkdir -p "$OUTPUT_DIR"/vulns/{nuclei,xss,sqli,idor,graphql,jwt,cors,headers,ssrf,lfi,ssti,xxe,smuggling,secrets,misc,api,js,waf,modern,cloud}
  export PATH="$HOME/go/bin:/usr/local/go/bin:$PATH"
  export GOPATH="$HOME/go"
  DOMAIN_RE="$(regex_escape "$DOMAIN")"
  bh_init_runtime
  bh_apply_defaults
  bh_detect_system_limits
  bh_install_traps
  bh_check_dependencies || true
  bh_db_init || true
  touch "$OUTPUT_DIR/findings.txt"

  # Compliance checks
  compliance_check

  log_info "Target    : ${CYAN}$DOMAIN${NC}"
  log_info "Output    : ${CYAN}$OUTPUT_DIR${NC}"
  log_info "Threads   : $THREADS | Timeout: ${TIMEOUT}s | Max jobs: $MAX_JOBS"
  log_info "Smart Limit: $([ "${BH_SMART_LIMIT:-0}" == "1" ] && echo "Enabled" || echo "Disabled") | Burst: ${BH_BURST_LIMIT:-20}/sec"
  log_warn "API keys  : $([ -n "$SHODAN_API_KEY" ] && echo "Shodan ✓" || echo "Shodan ✗") $([ -n "$GITHUB_TOKEN" ] && echo "GitHub ✓" || echo "GitHub ✗") $([ -n "$CHAOS_KEY" ] && echo "Chaos ✓" || echo "Chaos ✗")"
}

# ── Load Modules ────────────────────────────────────────────────────
load_modules() {
  for f in "$SCRIPT_DIR/modules/"[0-9]*.sh; do
    [[ -f "$f" ]] && source "$f"
  done
  bh_load_plugins
}

run_stage() {
  local step="$1"
  local func="$2"
  BH_CURRENT_STEP="$step"
  if ! bh_should_run_step "$step"; then
    log_warn "Skipping $step (resume checkpoint: ${BH_LAST_STEP:-none})"
    return 0
  fi
  if "$func"; then
    [[ "$CHECKPOINT" == "1" || "$RESUME" == "1" ]] && bh_checkpoint_save "$step" "ok"
    return 0
  fi
  bh_log_error "$step failed"
  [[ "$CHECKPOINT" == "1" || "$RESUME" == "1" ]] && bh_checkpoint_save "$step" "failed"
  return 1
}

# ── Screenshots ─────────────────────────────────────────────────────
run_screenshots() {
  log_section "Screenshots (gowitness)"
  local LIVE="$OUTPUT_DIR/subdomains/live.txt"
  [[ ! -f "$LIVE" ]] && return
  cmd_exists gowitness && \
    safe_run gowitness file -f "$LIVE" \
      --destination "$OUTPUT_DIR/screenshots" \
      --threads "$THREADS" || true
}

# ── Summary ─────────────────────────────────────────────────────────
print_summary() {
  echo ""
  echo -e "${GREEN}${BOLD}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║         SCAN COMPLETE ✓  v3.1            ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${NC}"
  cat "$OUTPUT_DIR/reports/summary.txt" 2>/dev/null || true
  echo ""
  echo -e "  ${CYAN}► HTML Report :${NC} $OUTPUT_DIR/reports/report.html"
  echo -e "  ${CYAN}► All Findings:${NC} $OUTPUT_DIR/findings.txt"
  echo -e "  ${CYAN}► Total vulns :${NC} $TOTAL_FINDINGS"
  echo ""

  # Telegram notification
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    END_T=$(date +%s)
    DUR=$(( (END_T - START_TIME) / 60 ))
    MSG="🔍 *BugHunter Pro v3.1*%0A"
    MSG+="✅ Scan complete: \`$DOMAIN\`%0A"
    MSG+="⏱ Duration: ${DUR}m%0A"
    MSG+="🚨 Findings: $TOTAL_FINDINGS%0A"
    MSG+="📁 Output: \`$OUTPUT_DIR\`"
    curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=${TELEGRAM_CHAT_ID}&text=${MSG}&parse_mode=Markdown" \
      > /dev/null 2>&1 || true
    echo -e "  ${GREEN}► Telegram notified ✓${NC}"
  fi
}

# ── MAIN ────────────────────────────────────────────────────────────
main() {
  banner
  parse_args "$@"
  load_modules
  setup
  bh_checkpoint_load || true

  # Recon first (needed by other modules)
  [[ "${RUN_RECON:-0}"    == "1" ]] && run_stage recon mod_recon

  # Subdomain enum
  [[ "${RUN_SUB:-0}"      == "1" ]] && run_stage sub mod_subdomain

  # Extra sources (merges into subdomain list)
  [[ "${RUN_EXTRA:-0}"    == "1" ]] && run_stage extra mod_extra_recon

  # GitHub recon
  [[ "${RUN_GITHUB:-0}"   == "1" ]] && run_stage github mod_github_recon

  # URL + JS collection
  [[ "${RUN_URL:-0}"      == "1" ]] && run_stage url mod_urls
  [[ "${RUN_JS:-0}"       == "1" ]] && run_stage js mod_js_analysis
  [[ "${RUN_JS:-0}"       == "1" ]] && run_stage js mod_js_deep   # FIXED #12

  # Vulnerability scanning
  [[ "${RUN_SECRETS:-0}"  == "1" ]] && run_stage secrets mod_secrets   # FIXED #11
  [[ "${RUN_TAKEOVER:-0}" == "1" ]] && run_stage takeover mod_takeover
  [[ "${RUN_NUCLEI:-0}"   == "1" ]] && run_stage nuclei mod_nuclei    # FIXED #9
  [[ "${RUN_V4:-0}"      == "1" ]] && run_stage v4 mod_v4_engines
  [[ "${RUN_API:-0}"      == "1" ]] && run_stage api mod_api       # FIXED #6
  [[ "${RUN_WEB:-0}"      == "1" ]] && run_stage web mod_web_vulns # FIXED #7 #8
  [[ "${RUN_SQLI:-0}"     == "1" ]] && run_stage sqli mod_sqli      # FIXED #2
  [[ "${RUN_XXE:-0}"      == "1" ]] && run_stage xxe mod_xxe       # FIXED #3
  [[ "${RUN_SMUGGLE:-0}"  == "1" ]] && run_stage smuggle mod_smuggling # FIXED #1
  [[ "${RUN_MODERN:-0}"   == "1" ]] && run_stage modern mod_modern_attacks # FIXED #14
  [[ "${RUN_WAF:-0}"      == "1" ]] && run_stage waf mod_waf
  [[ "${RUN_CLOUD:-0}"    == "1" ]] && run_stage cloud mod_cloud_discovery
  [[ "${RUN_REACT:-0}"    == "1" ]] && run_stage react mod_react_nextjs
  
  # Advanced Modules
  [[ "${RUN_FUZZ:-0}"     == "1" ]] && run_stage fuzz mod_deep_fuzzing
  [[ "${RUN_CMS:-0}"      == "1" ]] && run_stage cms mod_cms_scanner
  [[ "${RUN_APK:-0}"      == "1" ]] && run_stage apk mod_apk_extractor
  [[ "${RUN_AI:-0}"       == "1" ]] && run_stage ai mod_ai_analyzer
  [[ "${RUN_EXPLOIT:-0}"  == "1" ]] && run_stage exploit mod_auto_exploiter

  run_screenshots

  if [[ "${RUN_V4:-0}" == "1" || "${CONTINUOUS:-0}" == "1" || "${WATCH:-0}" == "1" || "${DIFF:-0}" == "1" || "${DAILY:-0}" == "1" || "${WEEKLY:-0}" == "1" || "${MONITOR:-0}" == "1" ]]; then
    run_stage v4_monitor mod_monitor
  fi

  bh_db_import_outputs || true
  [[ "${RUN_REPORT:-1}"   == "1" ]] && run_stage report mod_report

  print_summary
}

main "$@"
