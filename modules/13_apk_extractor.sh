#!/bin/bash
# ══════════════════════════════════════════════════════
#  MOD 13: APK Extractor
# ══════════════════════════════════════════════════════

mod_apk_extractor() {
  [[ -z "${APK_FILE:-}" ]] && return 0
  
  log_section "MOD 13: APK / Mobile App Extraction"
  local APK_DIR="$OUTPUT_DIR/apk_analysis"
  mkdir -p "$APK_DIR"
  
  if [[ ! -f "$APK_FILE" ]]; then
    log_error "APK file not found: $APK_FILE"
    return 0
  fi
  
  if cmd_exists apktool; then
    log_info "Decompiling $APK_FILE using apktool..."
    safe_run apktool d -f "$APK_FILE" -o "$APK_DIR/decompiled" 2>/dev/null
    
    if [[ -d "$APK_DIR/decompiled" ]]; then
      log_info "Extraction successful. Hunting for endpoints and secrets..."
      
      # Extract URLs
      grep -hRoP "https?://[a-zA-Z0-9./?=_-]+" "$APK_DIR/decompiled" | sort -u > "$APK_DIR/apk_urls.txt"
      local URL_COUNT=$(wc -l < "$APK_DIR/apk_urls.txt" 2>/dev/null || echo 0)
      log_info "Found $URL_COUNT URLs in the APK."
      
      # Merge into main URLs file if domain matches
      if [[ -n "$DOMAIN" ]]; then
        grep -i "$DOMAIN" "$APK_DIR/apk_urls.txt" >> "$OUTPUT_DIR/urls/all_urls.txt" 2>/dev/null || true
      fi
      
      # Find Firebase DBs
      grep -hRoP "https://[a-zA-Z0-9-]+\.firebaseio\.com" "$APK_DIR/decompiled" | sort -u > "$APK_DIR/firebase_dbs.txt"
      if [[ -s "$APK_DIR/firebase_dbs.txt" ]]; then
        log_warn "Firebase databases found in APK! Check $APK_DIR/firebase_dbs.txt"
        cat "$APK_DIR/firebase_dbs.txt" | while read -r fb; do
          local RESP=$(curl -s -m 5 "${fb}/.json")
          if [[ "$RESP" != *"Permission denied"* ]] && [[ -n "$RESP" ]]; then
            log_finding "Public Firebase DB found from APK: $fb"
            echo "[CRITICAL] Public Firebase: $fb" >> "$APK_DIR/vuln_firebase.txt"
          fi
        done
      fi
      
      # Find basic secrets (strings.xml is a goldmine)
      local STRINGS="$APK_DIR/decompiled/res/values/strings.xml"
      if [[ -f "$STRINGS" ]]; then
        grep -iE "key|secret|token|password|auth" "$STRINGS" > "$APK_DIR/potential_secrets.txt"
      fi
      
      # Extract using trufflehog if available
      if cmd_exists trufflehog; then
        log_info "Running trufflehog on decompiled APK..."
        safe_run trufflehog filesystem --directory "$APK_DIR/decompiled" --json 2>/dev/null > "$APK_DIR/trufflehog_apk.json" || true
        local HITS=$(grep -c "Raw" "$APK_DIR/trufflehog_apk.json" 2>/dev/null || echo 0)
        log_info "Trufflehog found $HITS potential secrets in the APK."
      fi
    fi
  else
    log_warn "apktool not found! Install: sudo apt install apktool or download from bitbucket."
  fi
}
