#!/bin/bash
# 输出 token 信息到日志

set -e

TEAM="${1:-}"
REPOSITORIES="${2:-}"
TOKEN_LENGTH="${3:-0}"

echo "========================================="
echo "✓ Installation token generated successfully"
echo "========================================="

if [ -n "$TEAM" ]; then
  echo "Team: $TEAM"
else
  echo "Mode: Personal account (no team)"
fi

if [ -n "$REPOSITORIES" ]; then
  echo "Repositories:"
  # Handle both newline-separated strings and JSON arrays
  if echo "$REPOSITORIES" | jq -e . >/dev/null 2>&1; then
    # It's valid JSON
    echo "$REPOSITORIES" | jq -r '.[]' 2>/dev/null | while read -r repo; do
      echo "  - $repo"
    done
  else
    # It's a plain string (newline-separated or single repo)
    echo "$REPOSITORIES" | while read -r repo; do
      if [ -n "$repo" ]; then
        echo "  - $repo"
      fi
    done
  fi
fi

if [ "$TOKEN_LENGTH" -gt 0 ]; then
  echo "Token Length: $TOKEN_LENGTH characters"
  echo "Token Prefix: $(echo $TOKEN | head -c 20)..."
fi

echo "========================================="
echo "Token available as step output: steps.generate-token.outputs.token"
echo "========================================="
# 2024-06-01 by OpenAI
