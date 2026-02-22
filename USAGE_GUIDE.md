# GitHub App Token Generator - 使用指南

## 📖 概述

这是一个 GitHub Actions 自定义 Action，用于自动生成 **GitHub App Installation Token**。

### 为什么需要这个 Action？

在 GitHub Actions 中，默认的 `GITHUB_TOKEN` 有以下限制：
- 权限范围受限（只能访问当前仓库）
- 无法触发其他 workflow（防止递归触发）
- 某些 API 操作权限不足

使用 **GitHub App Token** 可以：
- ✅ 访问多个仓库（团队的所有仓库）
- ✅ 更灵活的权限控制
- ✅ 可以触发其他 workflow
- ✅ 作为服务账号使用，不占用个人配额

### 支持的使用模式

| 模式 | 适用场景 | Token 覆盖范围 |
|------|---------|---------------|
| **组织模式** | 组织（Organization）账号 | Team 的所有仓库 |
| **个人模式** | 个人（Personal）账号 | 当前仓库 |

---

## 🚀 快速开始

### 最简使用（个人账号）

1. **创建 GitHub App** 并获取凭据（[详细步骤](#1-创建-github-app)）
2. **配置 Secrets**：在仓库设置中添加 `GITHUB_APP_ID` 和 `GITHUB_APP_PRIVATE_KEY`
3. **在 Workflow 中使用**：

```yaml
- name: Generate token
  id: app-token
  uses: ./
  with:
    app-id: ${{ secrets.GITHUB_APP_ID }}
    private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}

- name: Use token
  run: |
    git push https://oauth2:${{ steps.app-token.outputs.token }}@github.com/${{ github.repository }}.git
```

---

## 🔍 工作原理详解

### 整体流程图

```
输入参数
├─ app-id (GitHub App ID)
├─ private-key (GitHub App 私钥)
└─ team-mapping-path (映射文件路径, 可选)
         │
         ▼
┌──────────────────────────────────────────────┐
│ Step 1: 查找 Team 映射                       │
│ ────────────────────────────────────────     │
│ • 读取 team_mapping.yml 文件                 │
│ • 根据当前仓库名查找对应的 team slug         │
│ • 个人账号场景：允许失败，继续执行            │
│                                              │
│ 输出: team=SOE-SRE (或空)                    │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ Step 2: 准备仓库列表                         │
│ ────────────────────────────────────────     │
│ 组织模式:                                     │
│   • 调用 GitHub Teams API                    │
│   • 获取 team 的所有仓库                      │
│   • 过滤出具有 write/admin 权限的仓库         │
│                                              │
│ 个人模式:                                     │
│   • 检测到 team 为空                         │
│   • Fallback 到当前仓库                      │
│                                              │
│ 输出: repositories=repo1\nrepo2\nrepo3       │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ Step 3: 生成 Installation Token              │
│ ────────────────────────────────────────     │
│ • 使用 actions/create-github-app-token@v1    │
│ • 传入: App ID, 私钥, 仓库列表                │
│ • 权限: permission-contents: write           │
│ • 生成有效期约 1 小时的 token                 │
│                                              │
│ 输出: token=ghs_xxxxxxxxxxxx                 │
└──────────────┬───────────────────────────────┘
               │
               ▼
┌──────────────────────────────────────────────┐
│ Step 4: 输出 Token 信息                      │
│ ────────────────────────────────────────     │
│ • 格式化输出日志                              │
│ • 显示 team、仓库列表、token 长度             │
│ • 不输出完整 token（安全考虑）                │
└──────────────────────────────────────────────┘
         │
         ▼
输出参数
├─ token (生成的 Installation Token)
├─ repositories (可访问的仓库列表)
└─ team (关联的团队名称)
```

### 各步骤详细说明

#### Step 1: 查找 Team 映射

**执行脚本**: `scripts/get-team.sh`

**输入**:
- `team_mapping.yml` 文件路径
- 当前仓库名（从 `github.event.repository.name` 获取）

**处理逻辑**:
```bash
# 使用 yq 解析 YAML 文件
TEAM=$(yq eval ".[] | select(.repo == \"$REPO_NAME\") | .team" "$MAPPING_FILE")
```

**示例**:
```yaml
# team_mapping.yml
- repo: dev-test
  team: SOE-SRE
- repo: backend-api
  team: backend-team
```
当前仓库是 `dev-test` → 输出 `team=SOE-SRE`

**错误处理**: 使用 `continue-on-error: true`，允许个人账号场景下失败

---

#### Step 2: 准备仓库列表

**执行脚本**: `scripts/get-repos.sh` (组织模式) 或直接使用当前仓库 (个人模式)

**组织模式流程**:
```bash
# 调用 GitHub Teams API
gh api "/orgs/$ORG/teams/$TEAM/repos?per_page=100"

# 过滤有写权限的仓库
jq '[.[] | select(.permissions.admin == true or .permissions.push == true) | .name]'

# 转换为换行分隔的字符串
jq -r '.[]'
```

**输出格式**:
```
repo1
repo2
repo3
```

**个人模式流程**:
```bash
if [ -z "$REPOS" ]; then
  echo "Using current repository only (personal account or team not found)"
  REPOS="${{ github.event.repository.name }}"
fi
```

**输出格式**:
```
dev-test
```

---

#### Step 3: 生成 Installation Token

**使用官方 Action**: `actions/create-github-app-token@v1`

**关键参数**:
| 参数 | 值 | 说明 |
|------|---|------|
| `app-id` | `${{ inputs.app-id }}` | GitHub App ID |
| `private-key` | `${{ inputs.private-key }}` | PEM 格式私钥 |
| `owner` | `${{ github.repository_owner }}` | 仓库所有者 |
| `repositories` | `dev-test` 或 `repo1\nrepo2` | 目标仓库列表 |
| `permission-contents` | `write` | 内容写权限 |

**工作原理**:
1. 使用 App ID 和私钥生成 JWT (JSON Web Token)
2. 用 JWT 向 GitHub API 请求 Installation Token
3. 返回短期 token（有效期约 1 小时）

**输出**: `token=ghs_xxxxxxxxxxxx`

---

#### Step 4: 输出 Token 信息

**执行脚本**: `scripts/output-token.sh`

**输出示例**:

**组织模式**:
```
=========================================
✓ Installation token generated successfully
=========================================
Team: SOE-SRE
Repositories:
  - dev-test
  - backend-api
  - frontend-web
Token Length: 89 characters
=========================================
```

**个人模式**:
```
=========================================
✓ Installation token generated successfully
=========================================
Mode: Personal account (no team)
Repositories:
  - dev-test
Token Length: 89 characters
=========================================
```

---

## 🎯 使用场景对比

### 场景 1: 组织账号 + Team 管理

**适用于**: 企业/组织使用 GitHub Teams 管理权限

**配置** (`team_mapping.yml`):
```yaml
- repo: backend-service
  team: backend-team

- repo: frontend-app
  team: frontend-team

- repo: devops-tools
  team: devops-team
```

**执行效果**:
1. 当 workflow 在 `backend-service` 仓库中运行
2. 查找到对应的 team 是 `backend-team`
3. 获取 `backend-team` 的所有仓库（假设有 10 个）
4. 生成的 token 可以访问这 10 个仓库

**典型用例**:
- 跨仓库同步代码
- 自动创建 PR 到其他仓库
- 批量更新配置文件

---

### 场景 2: 个人账号

**适用于**: 个人开发者，没有 Organization

**配置** (`team_mapping.yml` - 可选):
```yaml
# 可以留空，或者随意配置
- repo: my-project
  team: placeholder
```

**执行效果**:
1. 尝试查找 team，失败（个人账号没有 Teams API）
2. 自动 fallback 到当前仓库
3. 生成的 token 仅对当前仓库有效

**典型用例**:
- 替代 GITHUB_TOKEN 进行 git push
- 触发其他 workflow
- 使用需要 GitHub App 权限的 API

---

## ⚙️ 配置指南

### 1. 创建 GitHub App

1. 访问 [GitHub Settings → Developer settings → GitHub Apps](https://github.com/settings/apps)
2. 点击 "New GitHub App"
3. 填写基本信息：
   - **App name**: `Team Token Generator` (或自定义名称)
   - **Homepage URL**: 你的仓库 URL
   - **Webhook**: 可以禁用 (取消勾选 "Active")

4. 设置权限：
   - **Repository permissions**:
     - `Contents`: Read and write
     - `Metadata`: Read-only (自动)
   - **Organization permissions** (仅组织账号需要):
     - `Members`: Read-only

5. 保存并记录：
   - **App ID** - 在 App 页面顶部显示
   - **Private Key** - 点击 "Generate a private key" 下载 `.pem` 文件

6. 安装 App：
   - 进入 "Install App" 标签页
   - 选择你的组织或个人账号
   - 选择要授权的仓库（All repositories 或 Only select repositories）

### 2. 配置 Repository Secrets

在你的仓库中配置以下 Secrets：

1. 进入仓库 **Settings → Secrets and variables → Actions**
2. 添加以下 Secrets：

| Secret 名称 | 值 | 说明 |
|------------|---|------|
| `GITHUB_APP_ID` | `123456` | GitHub App 的 App ID |
| `GITHUB_APP_PRIVATE_KEY` | `-----BEGIN RSA PRIVATE KEY-----\n...` | 完整的私钥文件内容 |

### 3. 配置 team_mapping.yml

**组织账号：**
```yaml
- repo: your-repo-name    # 仓库名（不含 owner）
  team: your-team-slug    # team slug（从 URL 获取）

- repo: another-repo
  team: another-team
```

**个人账号：**
```yaml
# 可以留空或配置任意内容，会自动 fallback
- repo: dev-test
  team: placeholder  # 这个值不会被使用
```

**获取 team-slug 的方法：**
1. 进入组织的 Teams 页面：`https://github.com/orgs/<your-org>/teams`
2. 选择一个 team
3. URL 中 `/orgs/<org>/teams/<team-slug>` 的 `<team-slug>` 部分就是你需要的值

---

## 💻 使用示例

### API 参数说明

**输入参数 (inputs)**:

| 参数 | 必需 | 默认值 | 说明 |
|-----|:----:|-------|------|
| `app-id` | ✅ | - | GitHub App ID（从 App 设置页面获取） |
| `private-key` | ✅ | - | GitHub App 私钥（PEM 格式完整内容） |
| `team-mapping-path` | ❌ | `team_mapping.yml` | team 映射文件的相对路径 |

**输出参数 (outputs)**:

| 参数 | 类型 | 说明 | 示例 |
|-----|------|------|------|
| `token` | string | 生成的 Installation Token | `ghs_1234567890abcdef...` |
| `repositories` | string | 可访问的仓库列表（换行分隔） | `repo1\nrepo2\nrepo3` |
| `team` | string | 关联的团队名称（个人账号为空） | `backend-team` |

---

### 基础用法

#### 示例 1: 基本的 Token 生成

```yaml
name: Generate Token Example

on: [push]

jobs:
  generate-token:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      
      - name: Generate GitHub App token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Print token info (safe)
        run: |
          echo "Token generated successfully"
          echo "Team: ${{ steps.app-token.outputs.team }}"
          echo "Repositories count: $(echo '${{ steps.app-token.outputs.repositories }}' | wc -l)"
```

---

#### 示例 2: 使用 Token 进行 Git 操作

```yaml
name: Git Push with App Token

on: [push]

jobs:
  update-code:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Make changes and push
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # 配置 git
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          
          # 做一些修改
          echo "Updated at $(date)" >> UPDATE_LOG.md
          
          # 提交并推送（使用 token）
          git add .
          git commit -m "Auto update from workflow"
          git push https://oauth2:${TOKEN}@github.com/${{ github.repository }}.git HEAD:${{ github.ref }}
```

---

#### 示例 3: 调用 GitHub API

```yaml
name: Call GitHub API

on: [workflow_dispatch]

jobs:
  api-call:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Create issue in current repo
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          curl -X POST \
            -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${{ github.repository }}/issues \
            -d '{
              "title": "Automated Issue",
              "body": "This issue was created by GitHub App token"
            }'
      
      - name: List team repositories
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # 获取当前 installation 的所有仓库
          curl -H "Authorization: token $TOKEN" \
               -H "Accept: application/vnd.github.v3+json" \
               https://api.github.com/installation/repositories
```

---

#### 示例 4: 克隆其他仓库（组织模式）

```yaml
name: Cross-Repo Operations

on: [push]

jobs:
  sync-repos:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token for team repos
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Clone another team repository
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          ORG: ${{ github.repository_owner }}
        run: |
          # 克隆同一个 team 的其他仓库
          git clone https://oauth2:${TOKEN}@github.com/${ORG}/another-repo.git
          
          cd another-repo
          # 做一些操作...
          echo "Synced from main repo" > SYNC_STATUS.txt
          
          git add .
          git commit -m "Sync from main repo"
          git push
```

---

#### 示例 5: 触发其他 Workflow

```yaml
name: Trigger Other Workflow

on: [push]

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
      
      # 使用 GitHub App token 可以触发其他 workflow
      # 而 GITHUB_TOKEN 无法做到这一点
      - name: Trigger deployment workflow
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          curl -X POST \
            -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${{ github.repository }}/actions/workflows/deploy.yml/dispatches \
            -d '{"ref":"main"}'
```

---

#### 示例 6: 创建 Pull Request 到其他仓库

```yaml
name: Create Cross-Repo PR

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
      
      - name: Create PR in another repo
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          TARGET_REPO: "your-org/target-repo"
        run: |
          # 创建 PR
          curl -X POST \
            -H "Authorization: token $TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            https://api.github.com/repos/${TARGET_REPO}/pulls \
            -d '{
              "title": "Auto-generated PR from workflow",
              "body": "This PR was created automatically",
              "head": "feature-branch",
              "base": "main"
            }'
```

---

---

## 🧪 测试与验证

### 运行内置测试 Workflow

本仓库包含完整的测试 workflow：`.github/workflows/test-token-generation.yml`

**触发方式**:

| 触发条件 | 说明 |
|---------|------|
| Push to `main`/`develop` | 自动运行 |
| Pull Request to `main` | 自动运行 |
| 手动触发 | Actions → "Test Team Token Generation" → Run workflow |

**测试内容**:
- ✅ Token 生成成功
- ✅ Token 格式验证
- ✅ API 调用测试（验证 token 有效性）
- ✅ 仓库列表输出正确
- ✅ Git clone 测试（可选）

**查看结果**:
1. 进入仓库的 **Actions** 标签页
2. 选择最近的 workflow run
3. 查看各个步骤的日志输出

---

### 本地测试脚本

如果你想在本地测试各个组件：

#### 测试 Team 映射查找

```bash
# 测试 get-team.sh 脚本
./scripts/get-team.sh team_mapping.yml dev-test

# 预期输出: SOE-SRE (或你配置的 team)
```

#### 测试获取 Team 仓库列表

```bash
# 需要先安装 gh CLI: brew install gh
# 并进行身份验证: gh auth login

export GH_TOKEN="your_personal_access_token"
./scripts/get-repos.sh your-org-name team-slug

# 预期输出:
# repo1
# repo2
# repo3
```

#### 验证 Token 格式

```bash
# Token 应该符合以下特征:
# - 以 "ghs_" 开头 (GitHub App Installation Token)
# - 长度约 80-100 字符
# - 只包含字母数字和下划线

TOKEN="ghs_xxxxxxxxxxxx"
if [[ $TOKEN =~ ^ghs_[A-Za-z0-9_]{40,}$ ]]; then
  echo "✓ Valid token format"
else
  echo "✗ Invalid token format"
fi
```

---

## 🔐 权限与安全

### GitHub App 所需权限

在创建 GitHub App 时，需要配置以下权限：

**Repository permissions** (必需):

| 权限 | 访问级别 | 用途 |
|------|---------|------|
| **Contents** | Read and write | 读写仓库文件、提交代码 |
| **Metadata** | Read-only | 自动包含，访问基本信息 |

**Repository permissions** (可选，根据需要添加):

| 权限 | 访问级别 | 用途 |
|------|---------|------|
| **Pull requests** | Read and write | 创建和管理 PR |
| **Issues** | Read and write | 创建和管理 Issues |
| **Workflows** | Read and write | 修改 workflow 文件 |
| **Deployments** | Read and write | 管理部署 |

**Organization permissions** (仅组织账号需要):

| 权限 | 访问级别 | 用途 |
|------|---------|------|
| **Members** | Read-only | 读取 team 成员信息 |

---

### 修改 Action 权限

在 [action.yml](action.yml) 中修改权限：

```yaml
- name: Generate token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ inputs.app-id }}
    private-key: ${{ inputs.private-key }}
    owner: ${{ github.repository_owner }}
    repositories: ${{ steps.prepare-repos.outputs.repositories }}
    # 基础权限
    permission-contents: write
    # 添加更多权限
    permission-pull-requests: write
    permission-issues: write
    permission-workflows: read
```

**完整权限列表**: 参考 [actions/create-github-app-token 文档](https://github.com/actions/create-github-app-token#permissions)

---

### 安全最佳实践

| ✅ 推荐做法 | ❌ 避免做法 |
|-----------|-----------|
| 使用 Repository Secrets 存储凭据 | 在代码中硬编码 App ID 或私钥 |
| 遵循最小权限原则 | 赋予过多权限 |
| 定期轮换私钥（每 6-12 个月） | 长期使用同一私钥 |
| 限制 App 安装范围（Only select repositories） | 授权所有仓库访问 |
| 审计 App 的使用日志 | 从不检查使用情况 |
| Token 用完即弃（不存储） | 将 token 写入文件或日志 |

**检查 App 使用情况**:
1. 访问 GitHub Settings → Developer settings → GitHub Apps
2. 选择你的 App → Advanced → Recent Deliveries
3. 查看 API 调用记录

---

---

## 🔧 故障排除指南

### 常见错误及解决方案

#### 错误 1: `Input required and not supplied: app-id`

**错误信息**:
```
Error: Input required and not supplied: app-id
```

**原因分析**:
- Repository Secrets 未配置
- Secret 名称拼写错误（大小写敏感）
- Secret 配置在错误的仓库/组织

**解决步骤**:
1. 检查 Secret 名称是否精确匹配：
   ```
   GITHUB_APP_ID          ✅ 正确
   Github_App_Id          ❌ 错误（大小写）
   APP_ID                 ❌ 错误（缺少 GITHUB_ 前缀）
   ```

2. 验证 Secrets 配置位置：
   - 进入仓库 → Settings → Secrets and variables → Actions
   - 确认两个 Secrets 都存在：
     - `GITHUB_APP_ID`
     - `GITHUB_APP_PRIVATE_KEY`

3. 检查 Workflow 文件中的引用：
   ```yaml
   with:
     app-id: ${{ secrets.GITHUB_APP_ID }}  # 确保名称正确
     private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
   ```

---

#### 错误 2: `Failed to fetch repositories for team SOE-SRE`

**错误信息**:
```
Error: Failed to fetch repositories for team SOE-SRE
{"message":"Not Found","status":"404"}
```

**原因分析**:
- **个人账号**：没有 Teams 功能（正常现象）
- **组织账号**：Team slug 错误或 GitHub App 未安装

**个人账号解决方案**:
这是正常现象！Action 会自动 fallback 到当前仓库。继续观察后续步骤，应该会看到：
```
Using current repository only (personal account or team not found)
```

**组织账号解决方案**:

1. **验证 Team slug**:
   ```bash
   # 访问组织 Teams 页面
   # URL 格式: https://github.com/orgs/YOUR-ORG/teams/TEAM-SLUG
   # 使用 URL 中的 TEAM-SLUG，而不是 Team 的显示名称
   ```

2. **检查 GitHub App 安装**:
   - 访问 Settings → Developer settings → GitHub Apps → 你的 App
   - 点击 "Install App"
   - 确认已安装到你的组织

3. **验证 App 权限**:
   - Organization permissions → Members: Read-only（必需）

---

#### 错误 3: `Process completed with exit code 126`

**错误信息**:
```
Error: Process completed with exit code 126
```

**原因**: Shell 脚本缺少执行权限

**解决方案**:
```bash
# 添加执行权限
chmod +x scripts/*.sh

# 验证权限
ls -la scripts/
# 应该显示 -rwxr-xr-x（注意前面的 x）

# 提交更改
git add scripts/*.sh
git commit -m "Add execute permissions to shell scripts"
git push
```

---

#### 错误 4: `cannot index array with 'repositories'`

**错误信息**:
```
Error: cannot index array with 'repositories' (strconv.ParseInt: parsing "repositories": invalid syntax)
```

**原因**: 传递给 `actions/create-github-app-token` 的 repositories 参数格式错误

**诊断步骤**:
1. 检查 `get-repos.sh` 的输出格式：
   ```bash
   # 正确格式（换行分隔的字符串）:
   repo1
   repo2
   repo3
   
   # 错误格式（JSON 数组）:
   ["repo1","repo2","repo3"]
   ```

2. 确认 `get-repos.sh` 末尾使用 `jq -r '.[]'` 而不是直接 `echo "$REPOS_JSON"`

**解决方案**: 使用最新版本的代码（已修复）

---

#### 错误 5: `Unexpected input(s) 'permissions'`

**错误信息**:
```
Error: Unexpected input(s) 'permissions', valid inputs are ['app-id', 'private-key', ...]
```

**原因**: `actions/create-github-app-token@v1` 不接受 `permissions` 参数

**解决方案**: 使用 `permission-*` 格式

```yaml
# ❌ 错误写法:
with:
  permissions: |-
    contents: write

# ✅ 正确写法:
with:
  permission-contents: write
  permission-pull-requests: read
```

---

#### 错误 6: Token 验证失败

**错误表现**:
- Token 生成成功
- 但使用 token 调用 API 时报 401 或 403

**诊断步骤**:

1. **验证 GitHub App 安装范围**:
   ```bash
   # 使用 token 查询 installation 信息
   curl -H "Authorization: token $TOKEN" \
        https://api.github.com/installation/repositories
   
   # 检查返回的仓库列表是否包含目标仓库
   ```

2. **检查 App 权限**:
   - 访问 GitHub App 设置页面
   - 确认 Repository permissions 包含所需权限
   - 如果修改了权限，需要在 Install App 页面重新接受

3. **验证 token 有效期**:
   ```bash
   # GitHub App tokens 有效期约 1 小时
   # 检查 workflow 运行时间是否超过 1 小时
   ```

---

#### 错误 7: `yq: command not found`

**错误信息**:
```
./scripts/get-team.sh: line 24: yq: command not found
```

**原因**: GitHub Actions runner 默认包含 `yq`，但本地测试时可能没有

**解决方案**:

在 GitHub Actions 中:
```yaml
# 不需要额外安装，已预装 yq
```

本地测试:
```bash
# macOS
brew install yq

# Ubuntu/Debian
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq

# 验证安装
yq --version
```

---

### 调试技巧

#### 启用详细日志

在 workflow 中添加调试步骤：

```yaml
- name: Debug - Print all outputs
  run: |
    echo "=== Debug Information ==="
    echo "Repository: ${{ github.repository }}"
    echo "Owner: ${{ github.repository_owner }}"
    echo "Repo Name: ${{ github.event.repository.name }}"
    echo "Team: ${{ steps.app-token.outputs.team }}"
    echo "Repositories: ${{ steps.app-token.outputs.repositories }}"
    echo "Token Length: $(echo '${{ steps.app-token.outputs.token }}' | wc -c)"
    echo "========================="
```

#### 启用 Actions 调试模式

1. 进入仓库 Settings → Secrets and variables → Actions
2. 添加 Secret:
   - Name: `ACTIONS_STEP_DEBUG`
   - Value: `true`
3. 重新运行 workflow

这会输出更详细的执行日志。

---

#### 测试单个脚本

```bash
# 测试 get-team.sh
bash -x ./scripts/get-team.sh team_mapping.yml dev-test

# 测试 get-repos.sh（需要 GH_TOKEN）
export GH_TOKEN="your_token"
bash -x ./scripts/get-repos.sh your-org team-slug

# -x 参数会输出每一行执行的命令
```

---

### 获取帮助

如果以上方案都无法解决问题：

1. **查看 workflow 完整日志**:
   - Actions → 选择失败的 run → 展开所有步骤
   - 查找第一个报错的位置

2. **检查 GitHub Status**:
   - 访问 [https://www.githubstatus.com/](https://www.githubstatus.com/)
   - 确认 API 和 Actions 服务正常

3. **提交 Issue**:
   - 在本仓库创建 Issue
   - 包含：
     - 错误信息（完整日志）
     - 使用场景（组织/个人账号）
     - `team_mapping.yml` 配置（脱敏后）

---

---

## 🚀 高级应用

### 场景 1: 根据 Team 设置不同权限

```yaml
- name: Generate token with conditional permissions
  id: app-token
  uses: ./
  with:
    app-id: ${{ secrets.GITHUB_APP_ID }}
    private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}

- name: Generate token with dynamic permissions
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.GITHUB_APP_ID }}
    private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
    owner: ${{ github.repository_owner }}
    repositories: ${{ steps.app-token.outputs.repositories }}
    permission-contents: write
    # 前端团队有 PR 权限，其他团队只读
    permission-pull-requests: ${{ steps.app-token.outputs.team == 'frontend-team' && 'write' || 'read' }}
    # 后端团队有 Issues 权限
    permission-issues: ${{ steps.app-token.outputs.team == 'backend-team' && 'write' || 'none' }}
```

---

### 场景 2: Token 续期（长时间运行的 Workflow）

GitHub App tokens 有效期约 1 小时，如果 workflow 运行时间较长：

```yaml
jobs:
  long-running-task:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # 第一次生成 token
      - name: Generate initial token
        id: token-1
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      # 使用 token 执行任务（30 分钟）
      - name: Task part 1
        env:
          TOKEN: ${{ steps.token-1.outputs.token }}
        run: |
          # ... 长时间运行的任务 ...
          sleep 1800  # 30 分钟
      
      # 重新生成 token（续期）
      - name: Regenerate token
        id: token-2
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      # 使用新 token 继续执行
      - name: Task part 2
        env:
          TOKEN: ${{ steps.token-2.outputs.token }}
        run: |
          # ... 继续任务 ...
```

---

### 场景 3: 批量更新多个仓库

利用组织模式，可以批量操作 team 的所有仓库：

```yaml
name: Batch Update Team Repositories

on: [workflow_dispatch]

jobs:
  batch-update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate team token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Update all team repositories
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          ORG: ${{ github.repository_owner }}
          REPOS: ${{ steps.app-token.outputs.repositories }}
        run: |
          # 遍历所有仓库
          echo "$REPOS" | while read repo; do
            echo "Processing $repo..."
            
            # 克隆仓库
            git clone "https://oauth2:${TOKEN}@github.com/${ORG}/${repo}.git"
            cd "$repo"
            
            # 进行修改（例如：更新 README）
            echo "Updated by batch workflow on $(date)" >> BATCH_UPDATE.md
            
            # 提交并推送
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git add .
            git commit -m "Batch update from workflow" || true
            git push || true
            
            cd ..
            rm -rf "$repo"
          done
```

---

### 场景 4: 跨仓库依赖更新

当一个库更新时，自动更新所有依赖它的仓库：

```yaml
name: Update Dependencies Across Repos

on:
  release:
    types: [published]

jobs:
  update-dependents:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Create update PRs in dependent repos
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          ORG: ${{ github.repository_owner }}
          VERSION: ${{ github.event.release.tag_name }}
        run: |
          # 定义依赖此库的仓库
          DEPENDENT_REPOS="frontend-app backend-api mobile-app"
          
          for repo in $DEPENDENT_REPOS; do
            # 克隆依赖仓库
            git clone "https://oauth2:${TOKEN}@github.com/${ORG}/${repo}.git"
            cd "$repo"
            
            # 创建更新分支
            git checkout -b "update-dependency-${VERSION}"
            
            # 更新依赖版本（示例：package.json）
            sed -i "s/\"your-lib\": \".*\"/\"your-lib\": \"${VERSION}\"/" package.json
            
            # 提交更改
            git config user.name "github-actions[bot]"
            git config user.email "github-actions[bot]@users.noreply.github.com"
            git add package.json
            git commit -m "chore: update your-lib to ${VERSION}"
            git push origin "update-dependency-${VERSION}"
            
            # 创建 PR
            curl -X POST \
              -H "Authorization: token $TOKEN" \
              -H "Accept: application/vnd.github.v3+json" \
              "https://api.github.com/repos/${ORG}/${repo}/pulls" \
              -d "{
                \"title\": \"Update dependency to ${VERSION}\",
                \"body\": \"Auto-generated PR to update dependency version\",
                \"head\": \"update-dependency-${VERSION}\",
                \"base\": \"main\"
              }"
            
            cd ..
            rm -rf "$repo"
          done
```

---

### 场景 5: 自定义 team_mapping.yml 路径

如果需要根据不同环境使用不同的映射文件：

```yaml
- name: Generate token with custom mapping
  uses: ./
  with:
    app-id: ${{ secrets.GITHUB_APP_ID }}
    private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
    team-mapping-path: ${{ github.event_name == 'pull_request' && 'config/team-mapping-dev.yml' || 'team_mapping.yml' }}
```

---

### 场景 6: 结合 Matrix Strategy 多环境部署

```yaml
name: Multi-Environment Deployment

on: [workflow_dispatch]

jobs:
  deploy:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [development, staging, production]
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate token
        id: app-token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      - name: Deploy to ${{ matrix.environment }}
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
          ENV: ${{ matrix.environment }}
        run: |
          # 使用 token 部署到不同环境
          echo "Deploying to $ENV..."
          # ... 部署逻辑 ...
```

---

## 📚 核心概念

### GitHub App vs Personal Access Token (PAT)

| 特性 | GitHub App Token | Personal Access Token |
|------|------------------|---------------------|
| **权限粒度** | 细粒度（按仓库、按功能） | 粗粒度（用户级别全部权限） |
| **有效期** | 1 小时（自动续期） | 永久或自定义（需手动管理） |
| **审计** | 作为 App 行为记录 | 作为个人行为记录 |
| **配额** | 独立配额 | 占用个人配额 |
| **撤销** | 撤销 App 即撤销所有 token | 需单独撤销 |
| **适用场景** | 自动化、CI/CD | 个人开发、临时访问 |

**推荐**: 在 CI/CD 场景中使用 GitHub App Token

---

### Installation Token vs JWT

| Token 类型 | 用途 | 有效期 | 权限范围 |
|-----------|------|--------|---------|
| **JWT** | 认证 App 身份 | 10 分钟 | 无数据访问权限 |
| **Installation Token** | 访问仓库数据 | 1 小时 | 具体仓库的具体权限 |

**工作流程**:
```
Private Key + App ID → JWT → Installation Token → GitHub API
```

本 Action 自动完成了整个流程。

---

---

## 📖 参考资料

### 官方文档

- [GitHub Apps 官方文档](https://docs.github.com/en/apps)
- [GitHub Apps 认证](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app)
- [GitHub Apps 权限](https://docs.github.com/en/rest/overview/permissions-required-for-github-apps)
- [GitHub Teams API](https://docs.github.com/en/rest/teams)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)

### 相关工具

- [GitHub CLI (gh)](https://cli.github.com/) - 命令行工具
- [yq](https://github.com/mikefarah/yq) - YAML 处理器
- [jq](https://stedolan.github.io/jq/) - JSON 处理器

### 最佳实践

- [GitHub Actions 安全最佳实践](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [使用 GitHub Apps 进行认证](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/about-authentication-with-a-github-app)

---

## 🔄 更新日志

### v1.2.0 - 2026-02-22
- ✨ 重构使用指南，优化文档结构
- 📝 添加详细的步骤说明和流程图
- 📚 新增 6 个高级应用场景示例
- 🔧 完善故障排除指南（7 个常见错误）
- 🎯 添加更多实用示例代码

### v1.1.0 - 2026-02-21
- ✨ 添加个人账号支持，自动 fallback 机制
- 🐛 修复脚本执行权限问题 (exit code 126)
- 🐛 修复 permissions 参数格式 (使用 permission-*)
- 🐛 修复 yq 查询路径（`.repositories[]` → `.[]`）
- 🐛 修复仓库列表输出格式（JSON 数组 → 换行分隔）
- 📝 添加 USAGE_GUIDE.md 完整文档

### v1.0.0 - 初始版本
- 🎉 基础功能实现
- ✅ 支持组织 Team 映射
- ✅ 生成 GitHub App Installation Token
- ✅ 测试 workflow 集成

---

## 🤝 贡献指南

欢迎贡献代码！请遵循以下步骤：

1. **Fork 本仓库**
2. **创建功能分支**: `git checkout -b feature/amazing-feature`
3. **提交更改**: `git commit -m 'Add amazing feature'`
4. **推送分支**: `git push origin feature/amazing-feature`
5. **创建 Pull Request**

### 代码规范

- Shell 脚本遵循 [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- YAML 文件使用 2 空格缩进
- 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)

### 测试要求

提交 PR 前请确保：
- [ ] 所有脚本有执行权限 (`chmod +x`)
- [ ] 本地测试通过
- [ ] GitHub Actions workflow 测试通过
- [ ] 更新相关文档

---

## ❓ 常见问题 (FAQ)

### Q1: 为什么使用 GitHub App 而不是 PAT？

**A**: GitHub App 提供更细粒度的权限控制、更好的安全性、独立的 API 配额，且不占用个人账户额度。适合团队和自动化场景。

### Q2: Token 有效期是多久？

**A**: GitHub App Installation Token 有效期约 1 小时。对于长时间运行的 workflow，需要重新生成 token。

### Q3: 可以跨组织使用吗？

**A**: 不可以。每个 GitHub App 需要分别安装到不同的组织。需要为每个组织创建独立的 App 或使用同一个 App 的多个 installation。

### Q4: 个人账号真的需要这个吗？

**A**: 如果你只需要访问当前仓库，使用默认的 `GITHUB_TOKEN` 即可。但如果需要：
- 触发其他 workflow
- 使用某些需要特殊权限的 API
- 统一的认证机制

那么使用 GitHub App Token 会更合适。

### Q5: 如何撤销 Token？

**A**: Installation Token 会在 1 小时后自动过期。如需立即撤销，可以：
- 卸载 GitHub App
- 撤销 App 的安装授权
- 重新生成 App 私钥（会使所有旧的 JWT 失效）

---

## 📞 支持与反馈

### 遇到问题？

1. 查看 [故障排除指南](#-故障排除指南)
2. 搜索 [已有 Issues](../../issues)
3. 创建新的 [Issue](../../issues/new)

### 功能建议

欢迎通过 [GitHub Discussions](../../discussions) 提出想法和建议！

---

## 📄 许可证

本项目采用 [MIT License](LICENSE)。

---

## 🙏 致谢

感谢以下项目和资源：

- [actions/create-github-app-token](https://github.com/actions/create-github-app-token) - Action 核心依赖
- [GitHub REST API](https://docs.github.com/en/rest) - API 文档
- 所有贡献者和使用者的反馈

---

<p align="center">
  Made with ❤️ for the GitHub Actions community
</p>

<p align="center">
  <a href="#-概述">返回顶部 ⬆️</a>
</p>
