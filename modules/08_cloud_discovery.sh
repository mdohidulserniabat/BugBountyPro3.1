#!/bin/bash
# ══════════════════════════════════════════════════════
#  MOD 08: Cloud Asset Discovery (AWS/Azure/GCP)
#  Finds misconfigured cloud storage and services
# ══════════════════════════════════════════════════════

mod_cloud_discovery() {
  [[ "${RUN_CLOUD:-0}" == "1" ]] || return 0
  
  log_section "MOD 08: Cloud Asset Discovery"
  local D="$OUTPUT_DIR/cloud"
  mkdir -p "$D"
  
  # AWS S3 Bucket Discovery
  log_info "Searching for AWS S3 buckets..."
  echo "$DOMAIN" > "$D/domain.txt"
  
  # Generate common bucket names
  cat << EOF > "$D/bucket_patterns.txt"
$DOMAIN
www.$DOMAIN
assets.$DOMAIN
static.$DOMAIN
media.$DOMAIN
cdn.$DOMAIN
backup.$DOMAIN
dev.$DOMAIN
staging.$DOMAIN
test.$DOMAIN
EOF
  
  # Check S3 buckets
  while read -r bucket; do
    if [[ -n "$bucket" ]]; then
      # Check if bucket exists and is public
      response=$(curl -s -o /dev/null -w "%{http_code}" "https://$bucket.s3.amazonaws.com/" --max-time 10)
      if [[ "$response" == "200" ]]; then
        log_warn "PUBLIC S3 BUCKET FOUND: $bucket.s3.amazonaws.com"
        echo "S3_PUBLIC:$bucket.s3.amazonaws.com" >> "$D/findings.txt"
        echo "https://$bucket.s3.amazonaws.com/" >> "$OUTPUT_DIR/findings.txt"
        # Notify via Telegram
        notify_bug_telegram "CRITICAL" "Public AWS S3 Bucket" "https://$bucket.s3.amazonaws.com/" "Contains sensitive data accessible to public"
      elif [[ "$response" == "403" ]]; then
        log_info "PRIVATE S3 BUCKET: $bucket.s3.amazonaws.com"
        echo "S3_PRIVATE:$bucket.s3.amazonaws.com" >> "$D/findings.txt"
      fi
    fi
  done < "$D/bucket_patterns.txt"
  
  # Azure Blob Storage
  log_info "Searching for Azure blob storage..."
  while read -r container; do
    if [[ -n "$container" ]]; then
      account_name=$(echo "$container" | cut -d'.' -f1)
      response=$(curl -s -o /dev/null -w "%{http_code}" "https://$account_name.blob.core.windows.net/$container/" --max-time 10)
      if [[ "$response" == "200" ]]; then
        log_warn "PUBLIC AZURE BLOB: $account_name.blob.core.windows.net/$container"
        echo "AZURE_PUBLIC:$account_name.blob.core.windows.net/$container" >> "$D/findings.txt"
        echo "https://$account_name.blob.core.windows.net/$container/" >> "$OUTPUT_DIR/findings.txt"
        # Notify via Telegram
        notify_bug_telegram "CRITICAL" "Public Azure Blob Storage" "https://$account_name.blob.core.windows.net/$container/" "Publicly accessible cloud storage"
      fi
    fi
  done < "$D/bucket_patterns.txt"
  
  # GCP Storage
  log_info "Searching for GCP storage..."
  while read -r bucket; do
    if [[ -n "$bucket" ]]; then
      response=$(curl -s -o /dev/null -w "%{http_code}" "https://storage.googleapis.com/$bucket/" --max-time 10)
      if [[ "$response" == "200" ]]; then
        log_warn "PUBLIC GCP STORAGE: storage.googleapis.com/$bucket"
        echo "GCP_PUBLIC:storage.googleapis.com/$bucket" >> "$D/findings.txt"
        echo "https://storage.googleapis.com/$bucket/" >> "$OUTPUT_DIR/findings.txt"
        # Notify via Telegram
        notify_bug_telegram "CRITICAL" "Public GCP Storage" "https://storage.googleapis.com/$bucket/" "Publicly accessible Google Cloud storage"
      fi
    fi
  done < "$D/bucket_patterns.txt"
  
  # Extract cloud endpoints from JS files
  if [[ -f "$OUTPUT_DIR/urls/js_urls.txt" ]]; then
    log_info "Extracting cloud endpoints from JavaScript..."
    grep -E 's3\.amazonaws\.com\|blob\.core\.windows\.net\|storage\.googleapis\.com' \
      "$OUTPUT_DIR/urls/js_urls.txt" 2>/dev/null | \
      sort -u > "$D/js_cloud_endpoints.txt" || true
    
    # Test extracted endpoints
    while read -r endpoint; do
      if [[ -n "$endpoint" ]]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint" --max-time 10)
        if [[ "$response" == "200" ]]; then
          log_warn "PUBLIC CLOUD ENDPOINT FROM JS: $endpoint"
          echo "CLOUD_JS:$endpoint" >> "$D/findings.txt"
          echo "$endpoint" >> "$OUTPUT_DIR/findings.txt"
          # Notify via Telegram
          notify_bug_telegram "HIGH" "Public Cloud Endpoint" "$endpoint" "Found in JavaScript files"
        fi
      fi
    done < "$D/js_cloud_endpoints.txt"
  fi
  
  # Summary
  if [[ -f "$D/findings.txt" ]]; then
    CLOUD_FINDINGS=$(wc -l < "$D/findings.txt")
    log_info "Cloud findings: ${CYAN}$CLOUD_FINDINGS${NC}"
    TOTAL_FINDINGS=$((TOTAL_FINDINGS + CLOUD_FINDINGS))
  else
    log_info "No cloud assets found"
  fi
}

