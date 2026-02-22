# GitHub App Token Generator - 完整配置流程

本文档提供从零开始配置和使用 GitHub App Token Generator 的**完整步骤**。

---

## 📋 目录

1. [前置要求](#1️⃣-前置要求)
2. [创建 GitHub App](#2️⃣-创建-github-app)
3. [配置仓库 Secrets](#3️⃣-配置仓库-secrets)
4. [配置文件设置](#4️⃣-配置文件设置)
5. [运行测试](#5️⃣-运行测试)
6. [验证结果](#6️⃣-验证结果)
7. [常见问题](#7️⃣-常见问题)

---

## 1️⃣ 前置要求

### 环境准备

- ✅ GitHub 账号（个人或组织）
- ✅ 一个仓库（本例：`gaojiemm/dev-test`）
- ✅ 仓库管理员权限（能够配置 Settings）

### 工具准备（可选）

```bash
# GitHub CLI（用于命令行操作）
brew install gh  # macOS
# 或访问 https://cli.github.com/

# yq（YAML 处理工具，Actions runner 已预装）
brew install yq  # 本地测试用

# jq（JSON 处理工具，Actions runner 已预装）
brew install jq  # 本地测试用
```

---

## 2️⃣ 创建 GitHub App

### 步骤 2.1: 访问 GitHub Apps 页面

🔗 直接访问：https://github.com/settings/apps/new

或手动导航：
```
个人头像 → Settings → Developer settings → GitHub Apps → New GitHub App
```

### 步骤 2.2: 填写基本信息

| 字段 | 值 | 说明 |
|------|---|------|
| **GitHub App name** | `dev-test-token-generator` | 全局唯一名称 |
| **Homepage URL** | `https://github.com/gaojiemm/dev-test` | 你的仓库 URL |
| **Webhook** | 取消勾选 "Active" | 我们不需要 webhook |

### 步骤 2.3: 设置权限

**Repository permissions**（必需）：

| 权限 | 访问级别 | 用途 |
|------|---------|------|
| **Contents** | Read and write | 读写仓库文件、提交代码、推送更改 |
| **Metadata** | Read-only | 自动包含，访问基本仓库信息 |

**可选权限**（根据需要添加）：

| 权限 | 访问级别 | 用途 |
|------|---------|------|
| Pull requests | Read and write | 创建和管理 PR |
| Issues | Read and write | 创建和管理 Issues |
| Workflows | Read and write | 修改 workflow 文件 |

**Organization permissions**（仅组织账号需要）：

| 权限 | 访问级别 | 用途 |
|------|---------|------|
| Members | Read-only | 读取 team 信息（个人账号忽略） |

### 步骤 2.4: 创建 App

1. 滚动到页面底部
2. 点击 **Create GitHub App**
3. 会跳转到 App 设置页面

### 步骤 2.5: 记录 App ID

在 App 设置页面顶部，你会看到：

```
App ID: 123456  ← 记下这个数字
```

📝 **记录 App ID**：`123456`（示例，替换为你的实际 ID）

### 步骤 2.6: 生成私钥

1. 滚动到 **Private keys** 部分
2. 点击 **Generate a private key**
3. 浏览器会自动下载一个 `.pem` 文件到你的下载目录

📁 **文件名示例**：`dev-test-token-generator.2026-02-22.private-key.pem`

**重要**：
- ⚠️ 保管好这个文件，它无法重新下载
- ⚠️ 不要提交到 Git 仓库
- ⚠️ 不要分享给其他人

### 步骤 2.7: 安装 App 到仓库

1. 在 App 设置页面左侧，点击 **Install App**
2. 选择你的账号（`gaojiemm`）
3. 选择安装范围：
   - **All repositories**（所有仓库，不推荐）
   - **Only select repositories**（推荐）✅
4. 选择 `dev-test` 仓库
5. 点击 **Install**

✅ **完成！GitHub App 已创建并安装。**

---

## 3️⃣ 配置仓库 Secrets

### 为什么需要 Secrets？

Secrets 是 GitHub 提供的**加密存储机制**，用于安全地存储敏感信息（如 API 密钥、Token 等）。

**特点**：
- 🔒 加密存储
- 🚫 配置后无法查看
- 🔐 只在 workflow 运行时解密
- 📝 日志中自动显示为 `***`

### 步骤 3.1: 访问 Secrets 页面

🔗 直接访问：https://github.com/gaojiemm/dev-test/settings/secrets/actions

或手动导航：
```
仓库页面 → Settings → Secrets and variables → Actions
```

### 步骤 3.2: 添加 GITHUB_APP_ID

1. 点击 **New repository secret**
2. 填写：
   - **Name**: `GITHUB_APP_ID`
     - ⚠️ 必须**完全一致**，区分大小写
     - ❌ `Github_App_Id` 是错误的
     - ❌ `APP_ID` 是错误的
   - **Value**: `123456`（你在步骤 2.5 记录的 App ID）
3. 点击 **Add secret**

### 步骤 3.3: 添加 GITHUB_APP_PRIVATE_KEY

1. 点击 **New repository secret**
2. 填写：
   - **Name**: `GITHUB_APP_PRIVATE_KEY`
     - ⚠️ 必须**完全一致**，区分大小写
   - **Value**: 打开下载的 `.pem` 文件，复制**完整内容**
3. 点击 **Add secret**

**私钥内容示例**：
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN
OPQRSTUVWXYZ1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQR
... (很多行)
1234567890abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234
-----END RSA PRIVATE KEY-----
```

**重要提示**：
- ✅ 复制**完整内容**，包括 `-----BEGIN...` 和 `-----END...` 行
- ✅ 保留所有换行符
- ❌ 不要添加额外的空格或注释

### 步骤 3.4: 验证 Secrets

刷新页面，应该看到：

```
Repository secrets
├─ GITHUB_APP_ID           Updated just now
└─ GITHUB_APP_PRIVATE_KEY  Updated just now
```

✅ **Secrets 配置完成！**

---

## 4️⃣ 配置文件设置

### 步骤 4.1: 检查 action.yml

确认 [action.yml](action.yml) 文件存在且配置正确（已包含在仓库中，无需修改）。

### 步骤 4.2: 配置 team_mapping.yml

根据你的账号类型配置：

#### 个人账号配置（如 gaojiemm）

```yaml
# team_mapping.yml
# 个人账号配置（team 值会被忽略，自动 fallback）

- repo: dev-test
  team: ""  # 空值或任意值都可以
```

或者保持现有配置：
```yaml
- repo: dev-test
  team: SOE-SRE  # 会尝试查找，失败后自动 fallback
```

**说明**：个人账号没有 Teams，所以无论配置什么都会自动使用当前仓库。

#### 组织账号配置

```yaml
# team_mapping.yml
# 组织账号配置（需要真实的 team slug）

- repo: backend-service
  team: backend-team  # ← 真实的 Team slug

- repo: frontend-app
  team: frontend-team

- repo: dev-test
  team: devops-team
```

**获取 Team slug**：
1. 访问组织 Teams 页面：`https://github.com/orgs/YOUR-ORG/teams`
2. 点击一个 Team
3. URL 中的最后部分就是 slug：`/teams/backend-team` → `backend-team`

### 步骤 4.3: 检查脚本权限

确保脚本有执行权限：

```bash
# 检查权限
ls -la scripts/

# 应该显示：
# -rwxr-xr-x  get-repos.sh
# -rwxr-xr-x  get-team.sh
# -rwxr-xr-x  output-token.sh

# 如果没有 x 权限，添加：
chmod +x scripts/*.sh

# 提交更改
git add scripts/*.sh
git commit -m "Add execute permissions to scripts"
git push
```

### 步骤 4.4: 检查 Workflow 文件

确认 [.github/workflows/test-token-generation.yml](.github/workflows/test-token-generation.yml) 文件存在。

关键配置：
```yaml
- name: Generate installation token for team
  id: token
  uses: ./
  with:
    app-id: ${{ secrets.GITHUB_APP_ID }}          # ← 从 Secrets 读取
    private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}  # ← 从 Secrets 读取
    team-mapping-path: 'team_mapping.yml'
```

✅ **配置文件准备完成！**

---

## 5️⃣ 运行测试

### 方式 1: 自动触发（推荐）

推送代码到 `main` 或 `develop` 分支会自动触发：

```bash
# 确保所有更改已提交
git add .
git commit -m "Setup GitHub App Token Generator"
git push origin main
```

### 方式 2: 手动触发

1. 访问仓库 **Actions** 标签页：https://github.com/gaojiemm/dev-test/actions
2. 左侧选择 **Test Team Token Generation**
3. 点击 **Run workflow** 下拉菜单
4. 选择分支（通常是 `main`）
5. 点击绿色的 **Run workflow** 按钮

### 方式 3: 通过 GitHub CLI

```bash
gh workflow run test-token-generation.yml

# 查看运行状态
gh run list --limit 5

# 查看最新运行的详细日志
gh run view --log
```

---

## 6️⃣ 验证结果

### 步骤 6.1: 查看 Workflow 运行状态

访问：https://github.com/gaojiemm/dev-test/actions

应该看到：
- ✅ 绿色对勾 = 成功
- ❌ 红色叉号 = 失败
- 🟡 黄色点 = 正在运行

### 步骤 6.2: 查看详细日志

点击 workflow run → 点击 job 名称 → 展开各个步骤

**预期成功的日志**：

#### Step 1: Get team from mapping
```bash
REPO_NAME="dev-test"
TEAM="SOE-SRE"  # 或空值
```

#### Step 2: Prepare repositories list
```bash
ORG="gaojiemm"
TEAM="SOE-SRE"  # 或空值

# 个人账号会看到：
Using current repository only (personal account or team not found)

# repositories=$REPOS
repositories=dev-test
```

#### Step 3: Generate token
```yaml
Run actions/create-github-app-token@v1
  with:
    app-id: ***                    ✅ 已传递
    private-key: ***               ✅ 已传递
    owner: gaojiemm
    repositories: dev-test
    permission-contents: write

# 成功输出：
✓ Installation token generated successfully
```

#### Step 4: Output token information
```bash
=========================================
✓ Installation token generated successfully
=========================================
Mode: Personal account (no team)  # 个人账号
# 或
Team: backend-team                # 组织账号

Repositories:
  - dev-test

Token Length: 89 characters
=========================================
```

### 步骤 6.3: 验证 Token 输出

在后续步骤中应该看到：

```bash
# Display token information
Team: SOE-SRE
Repositories: dev-test
Token Length: 89 characters
Token Prefix: ghs_abcdefghijklmnop...

# Verify token - Get user info
✓ Token verification successful!

# Verify token - List accessible repositories
Repositories accessible by token:
  1  dev-test
```

✅ **如果看到这些输出，说明配置成功！**

---

## 7️⃣ 常见问题

### Q1: 错误 "Input required and not supplied: app-id"

**原因**：Secrets 未配置或名称错误

**解决方法**：
1. 检查 Secrets 名称是否完全匹配：`GITHUB_APP_ID` 和 `GITHUB_APP_PRIVATE_KEY`
2. 访问 https://github.com/gaojiemm/dev-test/settings/secrets/actions 确认已配置
3. 重新运行 workflow

---

### Q2: 错误 "Failed to fetch repositories for team XXX"

**原因**：
- 个人账号没有 Teams 功能（正常现象）
- 或组织账号的 team slug 错误

**解决方法**：

**个人账号**（如 gaojiemm）：
- ✅ 这是正常的！会自动 fallback
- 后续应该看到：`Using current repository only (personal account or team not found)`

**组织账号**：
1. 检查 team slug 是否正确
2. 确认 GitHub App 已安装到组织
3. 检查 App 的 Organization permissions → Members: Read-only

---

### Q3: 错误 "Process completed with exit code 126"

**原因**：脚本缺少执行权限

**解决方法**：
```bash
chmod +x scripts/*.sh
git add scripts/*.sh
git commit -m "Add execute permissions to shell scripts"
git push
```

---

### Q4: Token 生成成功但无法使用

**原因**：
- GitHub App 未安装到目标仓库
- 权限配置不足

**解决方法**：
1. 访问 https://github.com/settings/installations
2. 找到你的 App → Configure
3. 确认已安装到 `dev-test` 仓库
4. 检查 Repository permissions → Contents: Write

---

### Q5: 私钥格式错误

**症状**：Token 生成失败，提示私钥无效

**解决方法**：
1. 重新打开 `.pem` 文件
2. 复制**完整内容**，包括：
   ```
   -----BEGIN RSA PRIVATE KEY-----
   (所有内容)
   -----END RSA PRIVATE KEY-----
   ```
3. 不要添加额外的空格、换行或注释
4. 重新配置 `GITHUB_APP_PRIVATE_KEY` Secret

---

### Q6: 如何重新生成私钥？

如果私钥丢失或泄露：

1. 访问 https://github.com/settings/apps
2. 选择你的 App
3. 滚动到 **Private keys** 部分
4. 点击 **Generate a private key**
5. 下载新的 `.pem` 文件
6. 更新仓库的 `GITHUB_APP_PRIVATE_KEY` Secret

**注意**：旧私钥会立即失效。

---

### Q7: 个人账号 vs 组织账号的区别

| 特性 | 个人账号 | 组织账号 |
|------|---------|---------|
| **有 Teams 功能** | ❌ | ✅ |
| **Token 覆盖范围** | 当前仓库 | Team 的所有仓库 |
| **日志输出** | "Personal account (no team)" | "Team: xxx" |
| **team_mapping.yml** | 任意配置都会 fallback | 需要真实的 team slug |
| **适用场景** | 个人项目、单仓库 | 团队协作、多仓库 |

---

## 📚 下一步

配置完成后，你可以：

1. **阅读使用指南**：[USAGE_GUIDE.md](USAGE_GUIDE.md) - 了解概念和高级用法
2. **查看代码示例**：[CODE_SNIPPETS.md](CODE_SNIPPETS.md) - 复制可用的代码片段
3. **快速参考**：[QUICK_START.md](QUICK_START.md) - 5 分钟快速上手

---

## 🎯 完整流程总结

```
1. 创建 GitHub App
   ├─ 设置权限（Contents: Write）
   ├─ 记录 App ID
   ├─ 生成并下载私钥
   └─ 安装到仓库

2. 配置 Secrets
   ├─ GITHUB_APP_ID
   └─ GITHUB_APP_PRIVATE_KEY

3. 配置文件
   ├─ team_mapping.yml（个人账号可随意配置）
   └─ 检查脚本权限

4. 运行测试
   └─ Push 代码或手动触发 workflow

5. 验证结果
   ├─ 查看 Actions 日志
   ├─ 确认 Token 生成成功
   └─ 验证 Token 可用

6. 开始使用
   └─ 在你的 workflow 中使用生成的 Token
```

---

## 💡 提示

- 📝 保存好 App ID 和私钥文件
- 🔐 不要将私钥提交到 Git 仓库
- ✅ 个人账号看到 "team not found" 是正常的
- 🔄 Token 有效期约 1 小时，会自动续期
- 📖 遇到问题先查看[故障排除指南](USAGE_GUIDE.md#-故障排除指南)

---

<p align="center">
  <strong>现在你已经完成了所有配置，可以开始使用 GitHub App Token Generator 了！🎉</strong>
</p>

<p align="center">
  <a href="USAGE_GUIDE.md">📖 使用指南</a> •
  <a href="CODE_SNIPPETS.md">💻 代码示例</a> •
  <a href="README.md">🏠 返回主页</a>
</p>
