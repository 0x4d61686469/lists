#!/usr/bin/env bash
set -euo pipefail

# Default URLs file in the same folder as the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
URLS_FILE="$SCRIPT_DIR/urls.txt"

if [ ! -f "$URLS_FILE" ]; then
  echo "ERROR: file not found: $URLS_FILE"
  exit 2
fi

# Ensure wget exists
if ! command -v wget >/dev/null 2>&1; then
  echo "ERROR: wget not found in PATH"
  exit 3
fi

# Ensure tar and unzip exist
if ! command -v tar >/dev/null 2>&1; then
  echo "ERROR: tar not found in PATH"
  exit 4
fi
if ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: unzip not found in PATH"
  exit 5
fi

while IFS= read -r rawline || [ -n "$rawline" ]; do
  # Trim whitespace
  line=$(printf '%s' "$rawline" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # Skip blank or comment lines
  [ -z "$line" ] && continue
  case "$line" in
    \#*) continue ;;
  esac

  # Parse URL and destination
  url=$(printf '%s' "$line" | awk '{print $1}')
  dest_raw=$(printf '%s' "$line" | cut -d ' ' -f2-)
  dest=$(printf '%s' "$dest_raw")
  # Strip quotes if present
  if [[ "$dest" =~ ^\".*\"$ ]] || [[ "$dest" =~ ^\'.*\'$ ]]; then
    dest=${dest:1:-1}
  fi

  if [ -z "$url" ] || [ -z "$dest" ]; then
    echo "WARN: skipping malformed line: $rawline"
    continue
  fi

  # Create parent directory
  parent_dir=$(dirname -- "$dest")
  [ "$parent_dir" != "." ] && mkdir -p -- "$parent_dir"

  # Skip download if file exists and size matches remote
  skip=false
  if [ -f "$dest" ]; then
    remote_size=$(wget --spider --server-response "$url" 2>&1 | awk '/Content-Length/ {print $2}' | tail -n1 | tr -d '\r')
    local_size=$(stat -c%s "$dest")
    if [ "$remote_size" != "" ] && [ "$remote_size" -eq "$local_size" ]; then
      echo "Skipping $dest (already exists and matches remote size)"
      skip=true
    fi
  fi

  if [ "$skip" = false ]; then
    tmp="${dest}.part"
    echo
    echo "Downloading:"
    echo "  URL -> $url"
    echo "  DEST -> $dest"
    echo "  TMP  -> $tmp"

    if wget -c --show-progress -O "$tmp" "$url"; then
      mv -f -- "$tmp" "$dest"
      echo "Saved: $dest"
    else
      echo "ERROR: download failed for $url (partial saved at $tmp if any)"
      continue
    fi
  fi

  # Extract if .tar.gz or .zip
  case "$dest" in
    *.tar.gz)
      echo "Extracting $dest..."
      tar -xzf "$dest" -C "$parent_dir"
      ;;
    *.zip)
      echo "Extracting $dest..."
      unzip -o "$dest" -d "$parent_dir"
      ;;
  esac

done < "$URLS_FILE"

cat dns-lists/2m-subdomains.txt dns-lists/best-dns-wordlist.txt | sort -u | anew  dns-lists/assetnote-merged.txt

cat dns-lists/altdns-words.txt dns-lists/dnsgen-words.txt | sort -u | anew dns-lists/words.txt

crunch 1 4 abcdefghijklmnopqrstuvwxyz0123456789 | anew dns-lists/4-lower.txt

echo
echo "All done."
