#!/bin/bash
# ══════════════════════════════════════════════════════
#  MOD 09: React/Next.js Specific Bug Hunting
#  Finds framework-specific vulnerabilities and leaks
# ══════════════════════════════════════════════════════

mod_react_nextjs() {
  [[ "${RUN_REACT:-0}" == "1" ]] || return 0
  
  log_section "MOD 09: React/Next.js Framework Analysis"
  local R="$OUTPUT_DIR/vulns/react"
  mkdir -p "$R"
  local LIVE="$OUTPUT_DIR/subdomains/live.txt"
  [[ ! -f "$LIVE" ]] && return

  # Detect React/Next.js applications
  log_info "Detecting React/Next.js applications..."
  head -50 "$LIVE" | while IFS= read -r url; do
    RESP=$(curl -sk --max-time "$TIMEOUT" "$url" 2>/dev/null)
    
    # Next.js detection
    if echo "$RESP" | grep -qi "_next/static\|__NEXT_DATA__\|next/router"; then
      log_finding "Next.js application detected: $url"
      echo "[INFO] Next.js: $url" >> "$R/frameworks.txt"
      
      # Next.js source map hunting
      log_info "Hunting Next.js source maps for: $url"
      NEXT_CHUNKS=$(echo "$RESP" | grep -oP '_next/static/chunks/[a-zA-Z0-9._-]+\.js' | sort -u)
      for chunk in $NEXT_CHUNKS; do
        MAP_URL="${url}/${chunk}.map"
        MAP_RESP=$(curl -sk --max-time "$TIMEOUT" "$MAP_URL" 2>/dev/null)
        if [[ -n "$MAP_RESP" ]]; then
          log_finding "Next.js source map exposed: $MAP_URL"
          echo "[CRITICAL] Next.js source map: $MAP_URL" >> "$R/nextjs_source_maps.txt"
          
          # Extract sensitive data from source maps
          if echo "$MAP_RESP" | grep -qiE "SECRET|API_KEY|PASSWORD|JWT|DATABASE"; then
            log_finding "Sensitive data in Next.js source map: $MAP_URL"
            echo "[CRITICAL] Secrets in source map: $MAP_URL" >> "$R/nextjs_secrets.txt"
          fi
        fi
      done
      
      # Next.js API routes enumeration
      NEXT_API_ROUTES=(
        "/api/hello" "/api/user" "/api/users" "/api/auth" "/api/login"
        "/api/admin" "/api/config" "/api/debug" "/api/health" "/api/status"
        "/_next/data/" "/_next/static/" "/_next/webpack/"
      )
      
      for route in "${NEXT_API_ROUTES[@]}"; do
        API_URL="${url}${route}"
        API_RESP=$(curl -sk --max-time "$TIMEOUT" "$API_URL" 2>/dev/null)
        API_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$API_URL" 2>/dev/null)
        
        if [[ "$API_STATUS" =~ ^(200|201|401|403) ]]; then
          log_finding "Next.js API route found: $API_URL [$API_STATUS]"
          echo "[$API_STATUS] Next.js API: $API_URL" >> "$R/nextjs_api_routes.txt"
          
          # Check for sensitive data in API responses
          if echo "$API_RESP" | grep -qiE '"email"|"password"|"token"|"secret"|"key"'; then
            log_finding "Sensitive data in Next.js API: $API_URL"
            echo "[HIGH] Sensitive data in API: $API_URL" >> "$R/nextjs_api_secrets.txt"
          fi
        fi
      done
    fi
    
    # React detection
    if echo "$RESP" | grep -qi "react-dom\|react.production.min.js\|createElement"; then
      log_finding "React application detected: $url"
      echo "[INFO] React: $url" >> "$R/frameworks.txt"
      
      # React DevTools check
      DEVTOOLS_RESP=$(curl -sk -H "React-DevTools" --max-time "$TIMEOUT" "$url" 2>/dev/null)
      if echo "$DEVTOOLS_RESP" | grep -qi "hasOwnProperty\|component"; then
        log_finding "React DevTools enabled in production: $url"
        echo "[MEDIUM] React DevTools: $url" >> "$R/react_devtools.txt"
      fi
      
      # Client-side routing analysis
      ROUTES=$(echo "$RESP" | grep -oP '"/[a-zA-Z0-9/_-]+"' | sort -u | head -20)
      for route in $ROUTES; do
        CLEAN_ROUTE=$(echo "$route" | tr -d '"')
        if [[ "$CLEAN_ROUTE" != "/" ]] && [[ "$CLEAN_ROUTE" != "//" ]]; then
          ROUTE_URL="${url}${CLEAN_ROUTE}"
          ROUTE_RESP=$(curl -sk --max-time "$TIMEOUT" "$ROUTE_URL" 2>/dev/null)
          ROUTE_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$ROUTE_URL" 2>/dev/null)
          
          # Check if route bypasses authentication
          if [[ "$ROUTE_STATUS" == "200" ]] && echo "$ROUTE_RESP" | grep -qiE "(admin|dashboard|settings|profile)"; then
            log_finding "Potential client-side routing bypass: $ROUTE_URL"
            echo "[HIGH] Routing bypass: $ROUTE_URL" >> "$R/react_routing_bypass.txt"
          fi
        fi
      done
    fi
  done
  
  # Summary
  REACT_FINDINGS=$(wc -l < "$R/frameworks.txt" 2>/dev/null || echo 0)
  NEXTJS_MAPS=$(wc -l < "$R/nextjs_source_maps.txt" 2>/dev/null || echo 0)
  NEXTJS_APIS=$(wc -l < "$R/nextjs_api_routes.txt" 2>/dev/null || echo 0)
  REACT_BYPASS=$(wc -l < "$R/react_routing_bypass.txt" 2>/dev/null || echo 0)
  
  log_info "React/Next.js findings:"
  log_info "  Frameworks detected: ${CYAN}$REACT_FINDINGS${NC}"
  log_info "  Source maps exposed: ${RED}$NEXTJS_MAPS${NC}"
  log_info "  API routes found: ${YELLOW}$NEXTJS_APIS${NC}"
  log_info "  Routing bypasses: ${YELLOW}$REACT_BYPASS${NC}"
  
  TOTAL_FINDINGS=$((TOTAL_FINDINGS + REACT_FINDINGS + NEXTJS_MAPS + NEXTJS_APIS + REACT_BYPASS))
}