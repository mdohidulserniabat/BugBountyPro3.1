#!/bin/bash
# Shared runtime bootstrap for BugHunter Pro.

bh_set_strict_mode() {
  set -Eeuo pipefail
  shopt -s nullglob 2>/dev/null || true
}

bh_timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

bh_init_paths() {
  : "${BH_LOG_DIR:=$OUTPUT_DIR/logs}"
  : "${BH_STATE_DIR:=$OUTPUT_DIR/state}"
  : "${BH_CACHE_DIR:=$OUTPUT_DIR/cache}"
  : "${BH_DB_DIR:=$OUTPUT_DIR/db}"
  mkdir -p "$BH_LOG_DIR" "$BH_STATE_DIR" "$BH_CACHE_DIR" "$BH_DB_DIR"
  : "${BH_LOG_FILE:=$BH_LOG_DIR/framework.log}"
  : "${BH_CHECKPOINT_FILE:=$BH_STATE_DIR/checkpoint.json}"
  : "${BH_DB_FILE:=$BH_DB_DIR/assets.db}"
}

bh_log_line() {
  local level="$1"
  shift
  local message="$*"
  printf '[%s] [%s] %s\n' "$(bh_timestamp)" "$level" "$message" >> "$BH_LOG_FILE"
}

bh_log_info() {
  printf '%s[+]%s %s\n' "${GREEN:-}" "${NC:-}" "$*"
  bh_log_line INFO "$*"
}

bh_log_warn() {
  printf '%s[!]%s %s\n' "${YELLOW:-}" "${NC:-}" "$*"
  bh_log_line WARN "$*"
}

bh_log_error() {
  printf '%s[-]%s %s\n' "${RED:-}" "${NC:-}" "$*"
  bh_log_line ERROR "$*"
}

bh_log_section() {
  printf '\n%s%s╔══════════════════════════════════════════════╗%s\n' "${BLUE:-}" "${BOLD:-}" "${NC:-}"
  printf '%s%s║  %s%s\n' "${BLUE:-}" "${BOLD:-}" "$*" "${NC:-}"
  printf '%s%s╚══════════════════════════════════════════════╝%s\n\n' "${BLUE:-}" "${BOLD:-}" "${NC:-}"
  bh_log_line SECTION "$*"
}

bh_log_finding() {
  TOTAL_FINDINGS=$((TOTAL_FINDINGS + 1))
  printf '%s%s[VULN]%s %s%s\n' "${RED:-}" "${BOLD:-}" "${NC:-}" "${RED:-}" "$*${NC:-}"
  printf '[%s] %s\n' "$(date +%T)" "$*" >> "$OUTPUT_DIR/findings.txt" 2>/dev/null || true
  bh_log_line FINDING "$*"
  if command -v bh_record_finding >/dev/null 2>&1; then
    bh_record_finding "info" "$*" "50" "$*" "manual review" "bootstrap"
  fi
  
  # Auto Telegram notification for all findings
  if [[ -n "${TELEGRAM_BOT_TOKEN:-}" ]] && [[ -n "${TELEGRAM_CHAT_ID:-}" ]]; then
    # Extract severity from finding message
    local severity="MEDIUM"
    local message="$*"
    
    # Detect severity from message content
    if [[ "$message" == *"[CRITICAL]"* ]] || [[ "$message" == *"critical"* ]] || [[ "$message" == *"CRITICAL"* ]]; then
      severity="CRITICAL"
    elif [[ "$message" == *"[HIGH]"* ]] || [[ "$message" == *"high"* ]] || [[ "$message" == *"HIGH"* ]]; then
      severity="HIGH"
    elif [[ "$message" == *"[MEDIUM]"* ]] || [[ "$message" == *"medium"* ]] || [[ "$message" == *"MEDIUM"* ]]; then
      severity="MEDIUM"
    elif [[ "$message" == *"[LOW]"* ]] || [[ "$message" == *"low"* ]] || [[ "$message" == *"LOW"* ]]; then
      severity="LOW"
    elif [[ "$message" == *"[INFO]"* ]] || [[ "$message" == *"info"* ]] || [[ "$message" == *"INFO"* ]]; then
      severity="LOW"
    fi
    
    # Extract URL if present (look for http/https)
    local url=""
    if [[ "$message" =~ (https?://[^\ ]+) ]]; then
      url="${BASH_REMATCH[1]}"
    elif [[ "$message" =~ ([a-zA-Z0-9._-]+\.[a-zA-Z]{2,}) ]]; then
      # Try to extract domain
      local domain="${BASH_REMATCH[1]}"
      if [[ "$domain" != "$DOMAIN" ]]; then
        url="https://$domain"
      fi
    fi
    
    # Extract bug type from message
    local bug_type="Vulnerability"
    if [[ "$message" == *"SSRF"* ]]; then
      bug_type="Server-Side Request Forgery (SSRF)"
    elif [[ "$message" == *"XSS"* ]]; then
      bug_type="Cross-Site Scripting (XSS)"
    elif [[ "$message" == *"SQLi"* ]]; then
      bug_type="SQL Injection"
    elif [[ "$message" == *"JWT"* ]]; then
      bug_type="JWT Vulnerability"
    elif [[ "$message" == *"CORS"* ]]; then
      bug_type="CORS Misconfiguration"
    elif [[ "$message" == *"takeover"* ]] || [[ "$message" == *"TAKEOVER"* ]]; then
      bug_type="Subdomain Takeover"
    elif [[ "$message" == *"secret"* ]] || [[ "$message" == *"SECRET"* ]]; then
      bug_type="Secret Exposure"
    elif [[ "$message" == *"S3"* ]] || [[ "$message" == *"cloud"* ]]; then
      bug_type="Cloud Misconfiguration"
    fi
    
    # Send Telegram notification
    notify_bug_telegram "$severity" "$bug_type" "$url" "$message"
  fi
}

log_info() { bh_log_info "$@"; }
log_warn() { bh_log_warn "$@"; }
log_error() { bh_log_error "$@"; }
log_section() { bh_log_section "$@"; }
log_finding() { bh_log_finding "$@"; }

cmd_exists() { command -v "$1" &>/dev/null; }
safe_run() { "$@" 2>/dev/null || true; }
regex_escape() { printf '%s' "$1" | sed 's/[.[\*^$()+?{|\\]/\\&/g'; }

safe_run_timeout() {
  local seconds="$1"
  shift
  if cmd_exists timeout; then
    timeout "$seconds" "$@" 2>/dev/null || true
  else
    "$@" 2>/dev/null || true
  fi
}

bh_hash8() {
  printf '%s' "$1" | md5sum | cut -c1-8
}

bh_init_runtime() {
  bh_set_strict_mode
  bh_init_paths
  bh_log_line INFO "runtime initialized"
}

bh_checkpoint_save() {
  local step="$1"
  local status="${2:-ok}"
  cat > "$BH_CHECKPOINT_FILE" <<EOF
{"domain":"$DOMAIN","output_dir":"$OUTPUT_DIR","last_step":"$step","status":"$status","updated_at":"$(bh_timestamp)"}
EOF
}

bh_checkpoint_load() {
  [[ -f "$BH_CHECKPOINT_FILE" ]] || return 1
  BH_LAST_STEP="$(grep -o '"last_step":"[^"]*"' "$BH_CHECKPOINT_FILE" 2>/dev/null | cut -d'"' -f4)"
  [[ -n "${BH_LAST_STEP:-}" ]]
}

bh_should_run_step() {
  local step="$1"
  [[ "${RESUME:-0}" == "1" ]] || return 0
  [[ -z "${BH_LAST_STEP:-}" ]] && return 0
  [[ "$BH_LAST_STEP" == "$step" ]] && return 0

  local seen=0
  local item
  for item in "${BH_STEP_ORDER[@]}"; do
    [[ "$item" == "$BH_LAST_STEP" ]] && seen=1 && continue
    [[ "$item" == "$step" ]] && [[ "$seen" == "1" ]] && return 0
    [[ "$item" == "$step" ]] && [[ "$seen" == "0" ]] && return 1
  done
  return 0
}

bh_handle_crash() {
  local exit_code=$?
  local line=${1:-0}
  bh_log_error "crash detected at line $line (exit=$exit_code)"
  [[ -n "${BH_CURRENT_STEP:-}" ]] && bh_checkpoint_save "$BH_CURRENT_STEP" "crash"
  exit "$exit_code"
}

bh_install_traps() {
  trap 'bh_handle_crash $LINENO' ERR
  trap 'bh_checkpoint_save "${BH_CURRENT_STEP:-unknown}" "interrupted"; bh_log_warn "interrupted"' INT TERM
  trap 'bh_checkpoint_save "${BH_CURRENT_STEP:-unknown}" "exit"' EXIT
}

bh_setup_job_env() {
  : "${BH_MEMORY_LIMIT:=}"
  : "${BH_CPU_LIMIT:=}"
  : "${MAX_JOBS:=3}"
  : "${THREADS:=30}"
}



bh_check_dependencies() {
  local missing_deps=()
  
  # Essential tools
  for tool in curl jq grep sort uniq head tail wc; do
    if ! cmd_exists "$tool"; then
      missing_deps+=("$tool")
    fi
  done
  
  # Go tools (framework will work without them but with reduced functionality)
  for tool in subfinder httpx nuclei dnsx; do
    if ! cmd_exists "$tool"; then
      bh_log_warn "Optional tool missing: $tool (install via ./install.sh)"
    fi
  done
  
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    bh_log_error "Missing essential dependencies: ${missing_deps[*]}"
    return 1
  fi
  
  return 0
}

bh_is_valid_target_content() {
  local url="$1"
  local expected_types="${2:-html,json,xml,text}"
  
  # Get content type without downloading full content
  local content_type=$(curl -s -I --max-time 5 "$url" 2>/dev/null | grep -i "content-type" | head -1 | cut -d':' -f2- | tr -d ' ' | tr '[:upper:]' '[:lower:]')
  
  if [[ -z "$content_type" ]]; then
    return 0  # Assume valid if no content-type header
  fi
  
  local valid=0
  IFS=',' read -ra TYPES <<< "$expected_types"
  for type in "${TYPES[@]}"; do
    if [[ "$content_type" == *"$type"* ]]; then
      valid=1
      break
    fi
  done
  
  return $((1 - valid))
}

bh_curl_limited() {
  local url="$1"
  local max_size="${2:-1048576}"  # Default 1MB
  local timeout="${3:-${TIMEOUT:-15}}"
  
  # Use curl with size and time limits
  curl -s --max-time "$timeout" --max-filesize "$max_size" "$url"
}
