#!/bin/bash
# 输出 token 信息到日志

set -e

TEAM="${1:-}"
REPOSITORIES="${2:-}"
TOKEN_LENGTH="${3:-0}"

if [ -z "$TEAM" ]; then
  echo "Error: TEAM not provided"
  exit 1
fi

echo "========================================="
echo "✓ Installation token generated successfully"
echo "========================================="
echo "Team: $TEAM"

if [ -n "$REPOSITORIES" ]; then
  echo "Repositories:"
  echo "$REPOSITORIES" | jq -r '.[]' 2>/dev/null | while read -r repo; do
    echo "  - $repo"
  done
fi

if [ "$TOKEN_LENGTH" -gt 0 ]; then
  echo "Token Length: $TOKEN_LENGTH characters"
  echo "Token Prefix: $(echo $TOKEN | head -c 20)..."
fi

echo "========================================="
echo "Token available as step output: steps.generate-token.outputs.token"
echo "========================================="
