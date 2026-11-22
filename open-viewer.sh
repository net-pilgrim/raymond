#!/usr/bin/env bash
# Raymond Knowledge Graph Viewer - Zero-Runtime Universal Browser Launcher
# Opens viewer/index.html directly in your default browser.
# Works on:
#   - Linux (xdg-open / sensible-browser)
#   - WSL (Windows Subsystem for Linux via cmd.exe / explorer.exe)
#   - macOS (open)
#   - Windows (Git Bash / Cygwin / MSYS via start)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIEWER_HTML="${SCRIPT_DIR}/packages/raymond-ui/index.html"

if [ ! -f "$VIEWER_HTML" ]; then
  VIEWER_HTML="${SCRIPT_DIR}/raymond-ui/index.html"
fi

if [ ! -f "$VIEWER_HTML" ]; then
  VIEWER_HTML="${SCRIPT_DIR}/viewer/index.html"
fi

if [ ! -f "$VIEWER_HTML" ]; then
  VIEWER_HTML="${SCRIPT_DIR}/index.html"
fi

if [ ! -f "$VIEWER_HTML" ]; then
  echo "❌ Error: Could not find index.html in packages/raymond-ui, raymond-ui, or viewer" >&2
  exit 1
fi

# Auto-detect optional Supabase credentials from .env or MCP config
SUPABASE_URL=""
SUPABASE_KEY=""

if [ -f "${SCRIPT_DIR}/.env" ]; then
  SUPABASE_URL=$(grep -E '^SUPABASE_URL=' "${SCRIPT_DIR}/.env" | cut -d '=' -f2- | tr -d '"'\'' ')
  SUPABASE_KEY=$(grep -E '^(SUPABASE_KEY|SUPABASE_SERVICE_ROLE_KEY|SUPABASE_ANON_KEY)=' "${SCRIPT_DIR}/.env" | head -n1 | cut -d '=' -f2- | tr -d '"'\'' ')
fi

if [ -z "$SUPABASE_URL" ] && [ -f "$HOME/.gemini/config/mcp_config.json" ]; then
  MCP_URL=$(grep -o '"url": *"[^"]*"' "$HOME/.gemini/config/mcp_config.json" | grep -E 'supabase\.co' | head -n1 | cut -d '"' -f4)
  if [ -n "$MCP_URL" ]; then
    SUPABASE_URL=$(echo "$MCP_URL" | sed -E 's|(https?://[^/]+).*|\1|')
  fi
  MCP_KEY=$(grep -E '"Authorization"' "$HOME/.gemini/config/mcp_config.json" | sed -E 's/.*"Bearer ([^"]+)".*/\1/' | head -n1)
  if [ -n "$MCP_KEY" ]; then
    SUPABASE_KEY="$MCP_KEY"
  fi
fi

PAGES_URL="https://net-pilgrim.github.io/raymond/"
DEFAULT_PROJECT_URL="https://zmocedvkqrcxwkthmwql.supabase.co"

USE_LOCAL=false
for arg in "$@"; do
  if [ "$arg" = "--local" ] || [ "$arg" = "-l" ]; then
    USE_LOCAL=true
  fi
done

QUERY=""
# The viewer has the default project credentials built-in.
# Only append hash parameters if targeting a different custom Supabase instance.
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ] && [ "$SUPABASE_URL" != "$DEFAULT_PROJECT_URL" ]; then
  QUERY="#url=${SUPABASE_URL}&key=${SUPABASE_KEY}"
  echo "✨ Auto-detected custom Supabase instance: ${SUPABASE_URL}"
fi

# Cache-buster timestamp for hosted pages to prevent browser disk cache staleness
CACHE_BUSTER="?v=$(date +%s)"

if [ "$USE_LOCAL" = true ]; then
  TARGET="file://${VIEWER_HTML}${QUERY}"
  echo "💻 Target: Local Browser File"
else
  TARGET="${PAGES_URL}${CACHE_BUSTER}${QUERY}"
  echo "🌐 Target: Hosted GitHub Pages Viewer"
fi
echo "🔗 ${TARGET}"

echo "🕸️ Opening Raymond Knowledge Graph Viewer in your default browser..."

# Detect environment and launch browser
if [[ -n "$WSL_DISTRO_NAME" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  # WSL environment
  WIN_USER=$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r\n')
  [ -z "$WIN_USER" ] && WIN_USER="danie"
  WIN_TEMP_DIR="/mnt/c/Users/${WIN_USER}/AppData/Local/Temp"

  if [ "$USE_LOCAL" = true ]; then
    # Copy to native Windows Temp to avoid WSL UNC path rejection ('link not supported')
    if [ -d "$WIN_TEMP_DIR" ]; then
      cp "$VIEWER_HTML" "${WIN_TEMP_DIR}/raymond_viewer.html"
      WIN_TARGET="C:\\Users\\${WIN_USER}\\AppData\\Local\\Temp\\raymond_viewer.html"
      (cd /mnt/c && cmd.exe /c start "" "$WIN_TARGET" >/dev/null 2>&1 &)
    else
      WIN_PATH=$(wslpath -w "$VIEWER_HTML")
      (cd /mnt/c && cmd.exe /c start "" "$WIN_PATH" >/dev/null 2>&1 &)
    fi
  else
    (cd /mnt/c && cmd.exe /c start "" "$TARGET" >/dev/null 2>&1 &)
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  (open "$TARGET" >/dev/null 2>&1 &)
elif [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]] || [[ "$OSTYPE" == "win32" ]]; then
  # Windows Git Bash / Cygwin
  start "" "$TARGET"
elif command -v xdg-open >/dev/null 2>&1; then
  # Linux desktop
  (xdg-open "$TARGET" >/dev/null 2>&1 &)
elif command -v sensible-browser >/dev/null 2>&1; then
  (sensible-browser "$TARGET" >/dev/null 2>&1 &)
else
  echo "⚠️ No desktop opener found. Open this URL in your browser:"
  echo "   ${TARGET}"
fi

echo "✅ Launched successfully!"
