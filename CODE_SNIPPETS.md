# GitHub App Token Generator - 代码速查手册

本文档包含使用 GitHub App Token Generator 过程中可能用到的所有代码片段和命令。

---

## 📋 目录

- [初始配置](#-初始配置)
- [Workflow 模板](#-workflow-模板)
- [脚本测试](#-脚本测试)
- [Git 操作](#-git-操作)
- [GitHub API 调用](#-github-api-调用)
- [调试命令](#-调试命令)
- [权限配置](#-权限配置)
- [故障排除](#-故障排除)

---

## 🔧 初始配置

### 1. 创建 team_mapping.yml

```yaml
# 组织账号配置
- repo: backend-service
  team: backend-team

- repo: frontend-app
  team: frontend-team

- repo: devops-tools
  team: devops-team

# 个人账号配置
- repo: my-project
  team: placeholder  # 会自动 fallback 到当前仓库
```

### 2. 设置脚本执行权限

```bash
# 给所有 shell 脚本添加执行权限
chmod +x scripts/*.sh

# 验证权限
ls -la scripts/
# 应该看到: -rwxr-xr-x

# 提交权限更改
git add scripts/*.sh
git commit -m "Add execute permissions to shell scripts"
git push
```

### 3. 配置 Repository Secrets (通过 Web UI)

```
仓库 Settings → Secrets and variables → Actions → New repository secret

Secret 1:
  Name: GITHUB_APP_ID
  Value: 123456  # 你的 GitHub App ID

Secret 2:
  Name: GITHUB_APP_PRIVATE_KEY
  Value: -----BEGIN RSA PRIVATE KEY-----
         (完整的私钥内容，包括头尾标记)
         -----END RSA PRIVATE KEY-----
```

### 4. 配置 Repository Secrets (通过 GitHub CLI)

```bash
# 安装 GitHub CLI
brew install gh  # macOS
# 或访问 https://cli.github.com/

# 登录
gh auth login

# 设置 GITHUB_APP_ID
gh secret set GITHUB_APP_ID --body "123456"

# 设置 GITHUB_APP_PRIVATE_KEY（从文件读取）
gh secret set GITHUB_APP_PRIVATE_KEY < path/to/private-key.pem

# 验证 Secrets
gh secret list
```

---

## 📝 Workflow 模板

### 模板 1: 基础 Token 生成

```yaml
name: Basic Token Generation

on: [push]

jobs:
  generate-token:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Generate GitHub App token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Use token
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          echo "Token generated successfully"
          echo "Team: ${{ steps.app-token.outputs.team }}"
```

### 模板 2: Git Push 操作

```yaml
name: Auto Update and Push

on:
  schedule:
    - cron: '0 0 * * *'  # 每天运行
  workflow_dispatch:

jobs:
  update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Update and push
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # 配置 Git
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          # 做一些修改
          date >> UPDATE_LOG.md
          echo "Last updated: $(date)" > LAST_UPDATE.txt
          
          # 提交
          git add .
          git commit -m "chore: auto update $(date +%Y-%m-%d)" || exit 0
          
          # 推送（使用 token）
          git push https://oauth2:${TOKEN}@github.com/${{ github.repository }}.git HEAD:main
```

### 模板 3: 创建 Pull Request

```yaml
name: Create Auto PR

on: [workflow_dispatch]

jobs:
  create-pr:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Create feature branch and PR
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          REPO: ${{ github.repository }}
        run: |
          # 配置 Git
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          # 创建新分支
          BRANCH_NAME="feature/auto-update-$(date +%s)"
          git checkout -b "$BRANCH_NAME"
          
          # 做一些修改
          echo "# Auto-generated changes" > CHANGES.md
          date >> CHANGES.md
          
          # 提交
          git add .
          git commit -m "feat: auto-generated changes"
          
          # 推送分支
          git push https://oauth2:${TOKEN}@github.com/${REPO}.git "$BRANCH_NAME"
          
          # 创建 PR
          curl -X POST \
            -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${REPO}/pulls \
            -d "{
              \"title\": \"Auto-generated PR\",
              \"body\": \"This PR was created automatically by GitHub Actions\",
              \"head\": \"$BRANCH_NAME\",
              \"base\": \"main\"
            }"
```

### 模板 4: 跨仓库操作（组织模式）

```yaml
name: Cross-Repo Sync

on: [push]

jobs:
  sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate team token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Clone and update other repos
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          ORG: ${{ github.repository_owner }}
        run: |
          # 目标仓库列表（同一个 team）
          TARGET_REPOS=("backend-api" "frontend-web" "mobile-app")
          
          for repo in "${TARGET_REPOS[@]}"; do
            echo "Processing $repo..."
            
            # 克隆仓库
            git clone https://oauth2:${TOKEN}@github.com/${ORG}/${repo}.git
            cd "$repo"
            
            # 同步文件
            cp ../shared-config.yml .
            
            # 提交更改
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git add .
            git commit -m "sync: update shared config" || true
            git push || true
            
            cd ..
            rm -rf "$repo"
          done
```

### 模板 5: 触发其他 Workflow

```yaml
name: Trigger Deployment

on:
  release:
    types: [published]

jobs:
  trigger:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Trigger deployment workflow
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          REPO: ${{ github.repository }}
          VERSION: ${{ github.event.release.tag_name }}
        run: |
          curl -X POST \
            -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${REPO}/actions/workflows/deploy.yml/dispatches \
            -d "{\"ref\":\"main\",\"inputs\":{\"version\":\"${VERSION}\"}}"
```

### 模板 6: 批量创建 Issues

```yaml
name: Batch Create Issues

on: [workflow_dispatch]

jobs:
  create-issues:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Create issues
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          REPO: ${{ github.repository }}
        run: |
          # 从文件读取 issue 列表
          cat << 'EOF' > issues.json
          [
            {"title": "Task 1", "body": "Description 1"},
            {"title": "Task 2", "body": "Description 2"},
            {"title": "Task 3", "body": "Description 3"}
          ]
          EOF
          
          # 批量创建
          jq -c '.[]' issues.json | while read issue; do
            curl -X POST \
              -H "Authorization: token $TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              https://api.github.com/repos/${REPO}/issues \
              -d "$issue"
            sleep 1  # 避免触发 rate limit
          done
```

---

## 🧪 脚本测试

### 测试 get-team.sh

```bash
# 基本测试
./scripts/get-team.sh team_mapping.yml dev-test

# 预期输出: SOE-SRE (或你配置的 team)

# 测试不存在的仓库
./scripts/get-team.sh team_mapping.yml non-existent-repo
# 应该报错: Could not find team mapping

# 调试模式
bash -x ./scripts/get-team.sh team_mapping.yml dev-test
# 会显示每一步执行的命令
```

### 测试 get-repos.sh

```bash
# 需要先设置 GH_TOKEN
export GH_TOKEN="ghp_xxxxxxxxxxxx"  # 或使用 gh auth login

# 测试获取 team 仓库
./scripts/get-repos.sh your-org-name team-slug

# 预期输出（换行分隔的仓库名）:
# repo1
# repo2
# repo3

# 调试模式
bash -x ./scripts/get-repos.sh your-org team-slug
```

### 测试 output-token.sh

```bash
# 模拟运行
./scripts/output-token.sh "backend-team" "repo1
repo2
repo3" 89

# 预期输出:
# =========================================
# ✓ Installation token generated successfully
# =========================================
# Team: backend-team
# Repositories:
#   - repo1
#   - repo2
#   - repo3
# Token Length: 89 characters
# =========================================
```

### 验证 YAML 文件格式

```bash
# 使用 yq 验证语法
yq eval '.' team_mapping.yml

# 预期：正确输出 YAML 内容

# 提取所有 repo 名称
yq eval '.[].repo' team_mapping.yml

# 提取所有 team 名称
yq eval '.[].team' team_mapping.yml
```

---

## 📦 Git 操作

### 使用 Token 克隆仓库

```bash
# 设置 token
TOKEN="ghs_xxxxxxxxxxxx"
ORG="your-org"
REPO="your-repo"

# 克隆
git clone https://oauth2:${TOKEN}@github.com/${ORG}/${REPO}.git

# 或使用环境变量（更安全）
export GIT_ASKPASS_TOKEN=$TOKEN
git clone https://github.com/${ORG}/${REPO}.git
```

### 使用 Token 推送更改

```bash
# 方式 1: 在 URL 中包含 token
git push https://oauth2:${TOKEN}@github.com/${ORG}/${REPO}.git main

# 方式 2: 使用 credential.helper
git config credential.helper '!f() { echo "username=oauth2"; echo "password=${TOKEN}"; }; f'
git push origin main

# 方式 3: 临时设置 remote
git remote set-url origin https://oauth2:${TOKEN}@github.com/${ORG}/${REPO}.git
git push origin main
```

### 批量克隆多个仓库

```bash
# 从 team 仓库列表克隆
REPOS="repo1
repo2
repo3"

echo "$REPOS" | while read repo; do
  if [ -n "$repo" ]; then
    echo "Cloning $repo..."
    git clone https://oauth2:${TOKEN}@github.com/${ORG}/${repo}.git
  fi
done
```

### 同步文件到多个仓库

```bash
#!/bin/bash
TOKEN="ghs_xxxxxxxxxxxx"
ORG="your-org"
REPOS=("repo1" "repo2" "repo3")
SOURCE_FILE="shared-config.yml"

for repo in "${REPOS[@]}"; do
  echo "Syncing to $repo..."
  
  # 克隆
  git clone https://oauth2:${TOKEN}@github.com/${ORG}/${repo}.git
  cd "$repo"
  
  # 复制文件
  cp "../${SOURCE_FILE}" .
  
  # 提交
  git config user.name "github-actions[bot]"
  git config user.email "github-actions[bot]@users.noreply.github.com"
  git add "$SOURCE_FILE"
  git commit -m "sync: update ${SOURCE_FILE}" || true
  git push || true
  
  cd ..
  rm -rf "$repo"
done
```

---

## 🌐 GitHub API 调用

### 获取仓库信息

```bash
TOKEN="ghs_xxxxxxxxxxxx"
REPO="owner/repo"

# 获取仓库基本信息
curl -H "Authorization: token $TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     https://api.github.com/repos/${REPO}

# 只获取特定字段
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/repos/${REPO} | jq '{name, full_name, private, permissions}'
```

### 创建 Issue

```bash
TOKEN="ghs_xxxxxxxxxxxx"
REPO="owner/repo"

curl -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${REPO}/issues \
  -d '{
    "title": "Found a bug",
    "body": "I am experiencing an issue with...",
    "labels": ["bug"],
    "assignees": ["username"]
  }'
```

### 创建 Pull Request

```bash
curl -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${REPO}/pulls \
  -d '{
    "title": "Amazing new feature",
    "body": "Please review this PR",
    "head": "feature-branch",
    "base": "main"
  }'
```

### 获取 Pull Request 列表

```bash
# 获取所有开放的 PR
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/repos/${REPO}/pulls?state=open

# 过滤并格式化
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/repos/${REPO}/pulls?state=open | \
  jq '.[] | {number, title, user: .user.login, url: .html_url}'
```

### 合并 Pull Request

```bash
PR_NUMBER=123

curl -X PUT \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${REPO}/pulls/${PR_NUMBER}/merge \
  -d '{
    "commit_title": "Merge PR #123",
    "commit_message": "Merged via API",
    "merge_method": "squash"
  }'
```

### 触发 Workflow

```bash
# 触发指定 workflow
curl -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/${REPO}/actions/workflows/deploy.yml/dispatches \
  -d '{
    "ref": "main",
    "inputs": {
      "environment": "production",
      "version": "v1.2.3"
    }
  }'
```

### 获取 Workflow 运行状态

```bash
# 获取最近的 workflow runs
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/repos/${REPO}/actions/runs | \
  jq '.workflow_runs[:5] | .[] | {id, name, status, conclusion}'

# 获取特定 run 的详情
RUN_ID=123456789
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/repos/${REPO}/actions/runs/${RUN_ID}
```

### 列出 Team 仓库

```bash
ORG="your-org"
TEAM_SLUG="team-name"

# 获取 team 的所有仓库
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/orgs/${ORG}/teams/${TEAM_SLUG}/repos

# 过滤出有写权限的仓库
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/orgs/${ORG}/teams/${TEAM_SLUG}/repos | \
  jq '.[] | select(.permissions.push == true or .permissions.admin == true) | .name'
```

### 查询 Installation 信息

```bash
# 获取 token 关联的 installations
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/installation/repositories

# 查看可访问的仓库列表
curl -H "Authorization: token $TOKEN" \
     https://api.github.com/installation/repositories | \
  jq '.repositories[].full_name'
```

---

## 🔍 调试命令

### 检查 Secrets 配置

```bash
# 使用 GitHub CLI 列出所有 secrets
gh secret list

# 检查特定 secret 是否存在（无法查看值）
gh secret list | grep GITHUB_APP_ID
gh secret list | grep GITHUB_APP_PRIVATE_KEY
```

### 验证 Token 格式

```bash
TOKEN="ghs_xxxxxxxxxxxx"

# 检查 token 格式
if [[ $TOKEN =~ ^ghs_[A-Za-z0-9_]{40,}$ ]]; then
  echo "✓ Valid GitHub App Installation Token format"
else
  echo "✗ Invalid token format"
fi

# 检查 token 长度
echo "Token length: ${#TOKEN} characters"
```

### 测试 Token 有效性

```bash
# 方式 1: 调用简单 API
curl -s -H "Authorization: token $TOKEN" \
     https://api.github.com/user | jq '.message // "Token is valid"'

# 方式 2: 检查 installation
curl -s -H "Authorization: token $TOKEN" \
     https://api.github.com/installation/repositories | \
  jq 'if .repositories then "✓ Token valid" else "✗ Token invalid" end'

# 方式 3: 检查 rate limit
curl -s -H "Authorization: token $TOKEN" \
     https://api.github.com/rate_limit | jq '.resources.core'
```

### 检查脚本权限

```bash
# 查看脚本权限
ls -la scripts/

# 查找所有没有执行权限的 .sh 文件
find scripts/ -name "*.sh" ! -perm -111

# 批量添加执行权限
find scripts/ -name "*.sh" -exec chmod +x {} \;
```

### 查看 Workflow 日志

```bash
# 使用 GitHub CLI 查看最近的 runs
gh run list --limit 5

# 查看特定 run 的日志
gh run view <run-id> --log

# 查看失败的 runs
gh run list --status failure

# 监控正在运行的 workflow
gh run watch
```

### 检查 YAML 语法

```bash
# 检查 workflow 文件语法
yamllint .github/workflows/test-token-generation.yml

# 检查 team_mapping.yml
yamllint team_mapping.yml

# 使用 yq 验证
yq eval '.' team_mapping.yml > /dev/null && echo "✓ Valid YAML" || echo "✗ Invalid YAML"
```

### 启用 Actions 调试模式

```bash
# 在仓库中设置调试 secret
gh secret set ACTIONS_STEP_DEBUG --body "true"

# 查看是否设置成功
gh secret list | grep ACTIONS_STEP_DEBUG

# 之后运行 workflow 会输出详细调试信息
```

### 本地模拟 GitHub Actions 环境

```bash
# 设置环境变量模拟 GitHub Actions
export GITHUB_REPOSITORY="owner/repo"
export GITHUB_REPOSITORY_OWNER="owner"
export GITHUB_EVENT_NAME="push"
export GITHUB_REF="refs/heads/main"

# 模拟运行脚本
./scripts/get-team.sh team_mapping.yml "$(basename $GITHUB_REPOSITORY)"
```

---

## ⚙️ 权限配置

### 基础权限配置

```yaml
# action.yml 中的配置
- name: Generate token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ inputs.app-id }}
    private-key: ${{ inputs.private-key }}
    owner: ${{ github.repository_owner }}
    repositories: ${{ steps.prepare-repos.outputs.repositories }}
    # 基础权限
    permission-contents: write
    permission-metadata: read
```

### 完整权限配置示例

```yaml
- name: Generate token with full permissions
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ inputs.app-id }}
    private-key: ${{ inputs.private-key }}
    owner: ${{ github.repository_owner }}
    repositories: ${{ steps.prepare-repos.outputs.repositories }}
    # Repository permissions
    permission-contents: write
    permission-pull-requests: write
    permission-issues: write
    permission-deployments: write
    permission-workflows: write
    permission-checks: write
    permission-statuses: write
    # Organization permissions
    permission-members: read
    permission-organization-administration: read
```

### 条件权限配置

```yaml
- name: Generate token with conditional permissions
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ inputs.app-id }}
    private-key: ${{ inputs.private-key }}
    owner: ${{ github.repository_owner }}
    repositories: ${{ steps.prepare-repos.outputs.repositories }}
    permission-contents: write
    # 只在 main 分支给予 deployment 权限
    permission-deployments: ${{ github.ref == 'refs/heads/main' && 'write' || 'none' }}
    # PR 权限根据 team 设置
    permission-pull-requests: ${{ steps.get-team.outputs.team == 'frontend-team' && 'write' || 'read' }}
```

---

## 🔧 故障排除

### 修复权限问题

```bash
# 添加执行权限
chmod +x scripts/*.sh

# 验证权限
ls -la scripts/

# 提交权限更改
git add scripts/*.sh
git commit -m "fix: add execute permissions to scripts"
git push
```

### 重新生成 GitHub App 私钥

```bash
# 1. 访问 GitHub App 设置页面
# https://github.com/settings/apps/<your-app>

# 2. 滚动到 "Private keys" 部分
# 3. 点击 "Generate a private key"
# 4. 下载 .pem 文件

# 5. 更新 Secret
gh secret set GITHUB_APP_PRIVATE_KEY < path/to/new-private-key.pem

# 或通过 Web UI 更新
```

### 清理和重试

```bash
# 清理 Git 缓存
git rm -r --cached .
git add .
git commit -m "fix: refresh git cache"

# 强制刷新 Actions
gh run list --limit 1 --json databaseId --jq '.[0].databaseId' | \
  xargs -I {} gh run rerun {}

# 清理本地分支
git fetch --prune
git branch -vv | grep ': gone]' | awk '{print $1}' | xargs git branch -D
```

### 验证 GitHub App 安装

```bash
# 使用 GitHub CLI 检查 App 安装
gh api /user/installations

# 检查特定组织的 installations
gh api /orgs/YOUR-ORG/installations

# 检查 App 的权限
gh api /app -H "Authorization: Bearer YOUR_JWT" | jq '.permissions'
```

---

## 📚 参考命令

### GitHub CLI 常用命令

```bash
# 认证
gh auth login

# 查看当前用户
gh auth status

# 仓库操作
gh repo view
gh repo clone owner/repo

# PR 操作
gh pr list
gh pr create --title "Title" --body "Body"
gh pr view 123
gh pr merge 123

# Issue 操作
gh issue list
gh issue create --title "Bug" --body "Description"
gh issue close 456

# Workflow 操作
gh workflow list
gh workflow run workflow.yml
gh run list
gh run view <run-id>
```

### jq 常用过滤

```bash
# 提取字段
echo '{"name":"test","value":123}' | jq '.name'

# 数组过滤
echo '[{"id":1},{"id":2}]' | jq '.[].id'

# 条件过滤
echo '[{"name":"a","active":true},{"name":"b","active":false}]' | \
  jq '.[] | select(.active == true)'

# 格式化输出
jq -r '.[] | "\(.name): \(.value)"'

# 从数组中提取
jq '.repositories[].name'
```

### yq 常用操作

```bash
# 读取值
yq eval '.[] | select(.repo == "dev-test") | .team' team_mapping.yml

# 修改值
yq eval '.[] | select(.repo == "dev-test").team = "new-team"' -i team_mapping.yml

# 添加新项
yq eval '. += [{"repo": "new-repo", "team": "new-team"}]' -i team_mapping.yml

# 删除项
yq eval 'del(.[] | select(.repo == "old-repo"))' -i team_mapping.yml
```

---

## 💡 最佳实践

### Workflow 最佳实践

```yaml
# 使用合适的触发条件
on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - '.github/workflows/**'

# 设置超时
jobs:
  build:
    timeout-minutes: 10

# 使用矩阵策略
strategy:
  matrix:
    environment: [dev, staging, prod]

# 添加条件执行
if: github.ref == 'refs/heads/main'

# 使用 secrets 而不是环境变量
env:
  TOKEN: ${{ secrets.GITHUB_APP_TOKEN }}  # ❌
  
# 应该直接在需要的地方使用
run: |
  gh api ... -H "Authorization: token ${{ secrets.TOKEN }}"  # ✅
```

### 安全最佳实践

```bash
# ✅ 使用环境变量传递 token
env:
  TOKEN: ${{ steps.app-token.outputs.token }}

# ❌ 不要在命令中直接暴露 token
run: git push https://oauth2:${{ steps.app-token.outputs.token }}@github.com/...

# ✅ 使用 credential helper
run: |
  git config credential.helper '!f() { echo "username=oauth2"; echo "password=${TOKEN}"; }; f'
  git push origin main
```

---

<p align="center">
  <a href="USAGE_GUIDE.md">📖 返回使用指南</a> •
  <a href="README.md">🏠 返回主页</a>
</p>
