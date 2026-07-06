#!/bin/bash
# Configuration parser and defaults.

bh_config_file="${BH_CONFIG_FILE:-$HOME/.bughunter/config.sh}"

bh_load_config() {
  [[ -f "$bh_config_file" ]] || return 0
  # shellcheck disable=SC1090
  source "$bh_config_file"
}

bh_apply_defaults() {
  : "${THREADS:=30}"
  : "${TIMEOUT:=15}"
  : "${MAX_JOBS:=3}"
  : "${PERM_WORDLIST_LIMIT:=5000}"
  : "${PERM_TIMEOUT:=15}"
  : "${MAX_RESPONSE_SIZE:=1048576}"  # 1MB default response size limit
  : "${SMART_LIMIT:=0}"        # Smart rate limiting (0=disabled, 1=enabled)
  : "${BURST_LIMIT:=20}"       # Max requests per second
  : "${COMPLIANCE_MODE:=0}"    # Legal compliance mode
}
