#!/bin/bash
# ══════════════════════════════════════════════════════
#  MOD 10: AI Analyzer (Optional)
#  Uses Gemini or OpenAI to find logical bugs
# ══════════════════════════════════════════════════════

mod_ai_analyzer() {
  log_section "MOD 10: AI-Powered Analysis"
  local AI_DIR="$OUTPUT_DIR/vulns/ai_analysis"
  
  if [[ -z "${GEMINI_API_KEY:-}" ]] && [[ -z "${OPENAI_API_KEY:-}" ]]; then
    log_warn "AI API keys (GEMINI_API_KEY or OPENAI_API_KEY) not set. Skipping AI module."
    return 0
  fi
  
  mkdir -p "$AI_DIR"
  local JS_FILES="$OUTPUT_DIR/urls/js_files.txt"
  local API_URLS="$OUTPUT_DIR/vulns/api/api_found.txt"
  
  # Analyze a few interesting JS files
  if [[ -f "$JS_FILES" ]]; then
    log_info "Sending sample JS to AI for logical flaw analysis..."
    head -3 "$JS_FILES" | while read -r jsurl; do
      [[ -z "$jsurl" ]] && continue
      CONTENT=$(curl -sk --max-time "$TIMEOUT" "$jsurl" | head -n 150)
      if [[ -n "$CONTENT" ]]; then
        local PROMPT="Analyze this JavaScript snippet for security vulnerabilities, API keys, or logical flaws. Output concisely in Markdown:\n\n$CONTENT"
        
        if [[ -n "${GEMINI_API_KEY:-}" ]]; then
          local PAYLOAD=$(jq -n --arg text "$PROMPT" '{"contents":[{"parts":[{"text":$text}]}]}')
          local RESP=$(curl -s -H "Content-Type: application/json" -d "$PAYLOAD" \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY" || true)
          echo "$RESP" | jq -r '.candidates[0].content.parts[0].text // "No response"' > "$AI_DIR/js_analysis_$(md5sum <<< "$jsurl" | cut -c1-8).md"
        fi
      fi
    done
    log_info "AI analysis for JS complete."
  fi
  
  # Analyze interesting error messages if they exist
  local ERRORS="$OUTPUT_DIR/vulns/sqli/error_based.txt"
  if [[ -f "$ERRORS" ]]; then
    log_info "Analyzing database errors with AI..."
    local ERR_CONTENT=$(head -5 "$ERRORS")
    if [[ -n "$ERR_CONTENT" ]]; then
        local PROMPT="I found these SQL errors during a pentest. How can I exploit them? What database type is this? Be concise:\n\n$ERR_CONTENT"
        if [[ -n "${GEMINI_API_KEY:-}" ]]; then
          local PAYLOAD=$(jq -n --arg text "$PROMPT" '{"contents":[{"parts":[{"text":$text}]}]}')
          local RESP=$(curl -s -H "Content-Type: application/json" -d "$PAYLOAD" \
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$GEMINI_API_KEY" || true)
          echo "$RESP" | jq -r '.candidates[0].content.parts[0].text // "No response"' > "$AI_DIR/sql_error_analysis.md"
        fi
    fi
  fi
  
  log_info "AI analysis module finished. Check $AI_DIR for insights."
}
