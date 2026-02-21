#!/bin/bash
# 获取 team 的所有 repositories，过滤出拥有 write 及以上权限的 repos

set -e

# 参数
ORG="${1:-}"
TEAM="${2:-}"

if [ -z "$ORG" ] || [ -z "$TEAM" ]; then
  echo "Error: ORG or TEAM not provided"
  echo "Usage: $0 <org> <team>"
  exit 1
fi

# 使用 gh api 获取 team 的 repositories (分页处理)
REPOS_JSON="[]"
PAGE=1
PER_PAGE=100

while true; do
  # 使用 gh api 获取数据
  PAGE_RESPONSE=$(gh api \
    -H "Accept: application/vnd.github.v3+json" \
    "/orgs/$ORG/teams/$TEAM/repos?per_page=$PER_PAGE&page=$PAGE" \
    2>/dev/null || echo "")

  # 检查是否有错误
  if echo "$PAGE_RESPONSE" | grep -q '"message"'; then
    echo "Error: Failed to fetch repositories for team $TEAM" >&2
    echo "$PAGE_RESPONSE" >&2
    exit 1
  fi

  # 检查是否为空（使用 jq 检查）
  if [ -z "$PAGE_RESPONSE" ] || echo "$PAGE_RESPONSE" | jq -e 'length == 0' >/dev/null 2>&1; then
    break
  fi

  # 过滤具有 write 及以上权限的 repositories
  # permissions.admin == true (管理权限)
  # OR permissions.push == true (写入权限)
  PAGE_REPOS=$(echo "$PAGE_RESPONSE" | jq -c '[.[] | select(.permissions.admin == true or .permissions.push == true) | .name]')

  # 合并结果
  if [ "$REPOS_JSON" = "[]" ]; then
    REPOS_JSON=$PAGE_REPOS
  else
    REPOS_JSON=$(echo "$REPOS_JSON $PAGE_REPOS" | jq -s 'add | unique')
  fi

  PAGE=$((PAGE + 1))
done

# Convert JSON array to newline-separated list for actions/create-github-app-token
echo "$REPOS_JSON" | jq -r '.[]'
