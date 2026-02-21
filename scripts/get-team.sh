#!/bin/bash
# 从 team_mapping.yml 获取当前 repo 对应的 team

set -e

# 参数
MAPPING_FILE="${1:-.team_mapping.yml}"
REPO_NAME="${2:-}"

if [ -z "$REPO_NAME" ]; then
  echo "Error: REPO_NAME not provided"
  echo "Usage: $0 <mapping_file> <repo_name>"
  exit 1
fi

if [ ! -f "$MAPPING_FILE" ]; then
  echo "Error: team_mapping.yml not found at $MAPPING_FILE"
  exit 1
fi
# 从 YAML 中提取当前 repo 对应的 team
TEAM=$(yq eval ".repositories[] | select(.repo == \"$REPO_NAME\") | .team" "$MAPPING_FILE")

if [ -z "$TEAM" ]; then
    echo "Error: Could not find team mapping for repository $REPO_NAME"
    exit 1
fi

echo "$TEAM"
