#!/bin/bash
# ══════════════════════════════════════════════════════
#  MOD 12: CMS Scanner (WordPress/Drupal/Joomla)
# ══════════════════════════════════════════════════════

mod_cms_scanner() {
  log_section "MOD 12: CMS Specific Scanning"
  local CMS="$OUTPUT_DIR/vulns/cms"
  mkdir -p "$CMS"
  
  local LIVE="$OUTPUT_DIR/subdomains/live.txt"
  [[ ! -f "$LIVE" ]] && return
  
  log_info "Detecting CMS (WordPress, Drupal, Joomla)..."
  
  > "$CMS/wordpress_sites.txt"
  > "$CMS/drupal_sites.txt"
  > "$CMS/joomla_sites.txt"
  
  head -50 "$LIVE" | while read -r url; do
    RESP=$(curl -sk --max-time "$TIMEOUT" "$url" 2>/dev/null)
    
    if echo "$RESP" | grep -qi "wp-content\|wp-includes\|wordpress"; then
      echo "$url" >> "$CMS/wordpress_sites.txt"
    elif echo "$RESP" | grep -qi "Drupal\|sites/all/\|sites/default/"; then
      echo "$url" >> "$CMS/drupal_sites.txt"
    elif echo "$RESP" | grep -qi "Joomla\|/components/com_"; then
      echo "$url" >> "$CMS/joomla_sites.txt"
    fi
  done
  
  local WP_COUNT=$(wc -l < "$CMS/wordpress_sites.txt" 2>/dev/null || echo 0)
  log_info "Found WordPress sites: $WP_COUNT"
  
  if [[ "$WP_COUNT" -gt 0 ]]; then
    if cmd_exists wpscan; then
      log_info "Running wpscan on top WordPress sites..."
      head -3 "$CMS/wordpress_sites.txt" | while read -r wp_url; do
        log_info "Scanning $wp_url..."
        safe_run wpscan --url "$wp_url" --enumerate p,t,u --random-user-agent --format cli-no-color \
          > "$CMS/wpscan_$(md5sum <<< "$wp_url" | cut -c1-8).txt" 2>/dev/null || true
      done
    else
      log_warn "wpscan not found. Install via: gem install wpscan"
    fi
  fi
}
