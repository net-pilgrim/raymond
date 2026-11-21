#!/usr/bin/env bash
# Raymond Knowledge Graph Viewer - Zero-Runtime Universal Browser Launcher
# Supports:
#   - Linux (xdg-open / sensible-browser)
#   - WSL (Windows Subsystem for Linux via cmd.exe / explorer.exe)
#   - macOS (open)
#   - Windows Git Bash / Cygwin / MSYS (start)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VIEWER_HTML="${SCRIPT_DIR}/viewer/index.html"

USE_LOCAL=false
for arg in "$@"; do
  if [ "$arg" = "--local" ] || [ "$arg" = "-l" ]; then
    USE_LOCAL=true
  fi
done

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

# Determine target URL: prefer Live Serverless Edge Function viewer if available
if [ "$USE_LOCAL" = false ] && [ -n "$SUPABASE_URL" ]; then
  TARGET="${SUPABASE_URL}/functions/v1/mcp/viewer"
  echo "🌐 Target: Live Serverless Edge Function Viewer"
  echo "🔗 ${TARGET}"
else
  if [ ! -f "$VIEWER_HTML" ]; then
    VIEWER_HTML="${SCRIPT_DIR}/index.html"
  fi
  QUERY=""
  if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_KEY" ]; then
    QUERY="?url=${SUPABASE_URL}&key=${SUPABASE_KEY}"
  fi
  TARGET="file://${VIEWER_HTML}${QUERY}"
  echo "💻 Target: Local Client File Viewer"
  echo "🔗 ${TARGET}"
fi

echo "🕸️ Opening Raymond Knowledge Graph Viewer in your default browser..."

# Detect environment and launch browser
if [[ -n "$WSL_DISTRO_NAME" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  # WSL environment
  if [[ "$TARGET" =~ ^https?:// ]]; then
    (cmd.exe /c start "" "$TARGET" >/dev/null 2>&1 &)
  elif command -v wslpath >/dev/null 2>&1 && command -v cmd.exe >/dev/null 2>&1; then
    WIN_PATH=$(wslpath -m "$VIEWER_HTML")
    (cmd.exe /c start "" "file:${WIN_PATH}${QUERY}" >/dev/null 2>&1 &)
  elif command -v wslpath >/dev/null 2>&1 && command -v explorer.exe >/dev/null 2>&1; then
    WIN_PATH=$(wslpath -w "$VIEWER_HTML")
    (explorer.exe "$WIN_PATH" >/dev/null 2>&1 &)
  else
    (xdg-open "$TARGET" >/dev/null 2>&1 &)
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
  echo "⚠️ No desktop opener found. Open this link in your browser:"
  echo "   ${TARGET}"
fi

echo "✅ Launched successfully!"
