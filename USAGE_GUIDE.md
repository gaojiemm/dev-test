# GitHub App Token Generator - 使用指南

## 概述

这是一个 GitHub Actions 自定义 Action，用于为仓库生成 GitHub App Installation Token。它支持两种模式：

- **组织模式**：基于 Team 映射，为团队的所有仓库生成具有写权限的 token
- **个人模式**：自动 fallback 到当前仓库，为个人账号仓库生成 token

## 工作原理

### 执行流程

```
┌─────────────────────────────────────────────┐
│ 1. 读取 team_mapping.yml                    │
│    根据当前仓库名查找对应的 team             │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 2. 获取仓库列表                              │
│    - 组织模式: 从 Team API 获取所有仓库      │
│    - 个人模式: 使用当前仓库                  │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 3. 生成 Installation Token                  │
│    使用 GitHub App 凭据生成 token            │
│    权限: contents: write                     │
└──────────────┬──────────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────────┐
│ 4. 输出 Token 信息                           │
│    供后续步骤使用                            │
└─────────────────────────────────────────────┘
```

### 核心组件

1. **action.yml** - Action 主文件，定义输入输出和执行步骤
2. **scripts/get-team.sh** - 从 team_mapping.yml 读取 team 配置
3. **scripts/get-repos.sh** - 通过 GitHub API 获取 team 的所有仓库
4. **scripts/output-token.sh** - 格式化输出 token 信息
5. **team_mapping.yml** - 仓库到团队的映射配置

## 支持的场景

### 场景 1: 组织账号 + Team

适用于组织（Organization）账号，使用 Team 管理仓库权限。

**配置示例：**
```yaml
# team_mapping.yml
- repo: backend-service
  team: backend-team

- repo: frontend-app
  team: frontend-team

- repo: devops-tools
  team: devops-team
```

**行为：**
- 从 team_mapping.yml 获取当前仓库对应的 team
- 查询该 team 的所有具有 write/admin 权限的仓库
- 为这些仓库生成 GitHub App token

### 场景 2: 个人账号

适用于个人（Personal）账号，没有 Team 功能。

**行为：**
- 自动检测到无法获取 team 信息
- Fallback 到当前仓库
- 仅为当前仓库生成 GitHub App token

**输出示例：**
```
Using current repository only (personal account or team not found)
Mode: Personal account (no team)
```

## 前置要求

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
1. 进入组织的 Teams 页面
2. 选择一个 team
3. URL 中 `/orgs/<org>/teams/<team-slug>` 的 `<team-slug>` 部分

## 使用方法

### 在 Workflow 中使用

```yaml
name: Your Workflow

on: [push, pull_request]

jobs:
  example-job:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      # 生成 token
      - name: Generate GitHub App token
        id: app-token
        uses: ./  # 使用仓库中的 action
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
          team-mapping-path: 'team_mapping.yml'  # 可选，默认值
      
      # 使用 token - 示例 1: Git 操作
      - name: Push changes with token
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          # ... 做一些修改 ...
          git push https://oauth2:${TOKEN}@github.com/${{ github.repository }}.git
      
      # 使用 token - 示例 2: API 调用
      - name: Call GitHub API with token
        env:
          TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          curl -H "Authorization: token $TOKEN" \
               -H "Accept: application/vnd.github.v3+json" \
               https://api.github.com/repos/${{ github.repository }}/issues
```

### 输入参数

| 参数 | 必需 | 默认值 | 说明 |
|-----|------|-------|------|
| `app-id` | ✅ | - | GitHub App ID |
| `private-key` | ✅ | - | GitHub App 私钥（PEM 格式） |
| `team-mapping-path` | ❌ | `team_mapping.yml` | team 映射文件路径 |

### 输出参数

| 输出 | 说明 | 示例 |
|-----|------|------|
| `token` | 生成的 GitHub App Installation Token | `ghs_xxx...` |
| `repositories` | Token 可访问的仓库列表 | `repo1\nrepo2\nrepo3` |
| `team` | 当前仓库对应的 team | `backend-team` |

## 测试 Action

### 运行测试 Workflow

仓库中已包含测试 workflow：`.github/workflows/test-token-generation.yml`

**触发方式：**

1. **自动触发**：推送到 `main` 或 `develop` 分支
2. **手动触发**：
   - 进入仓库 **Actions** 标签页
   - 选择 "Test Team Token Generation"
   - 点击 **Run workflow**

**测试验证内容：**
- ✅ Token 生成成功
- ✅ Token 格式正确
- ✅ 可以调用 GitHub API
- ✅ 仓库列表正确

### 本地测试脚本

```bash
# 测试 get-team.sh
./scripts/get-team.sh team_mapping.yml dev-test

# 测试 get-repos.sh (需要 gh CLI 和认证)
export GH_TOKEN="your_token"
./scripts/get-repos.sh your-org team-slug
```

## 权限说明

### GitHub App 权限

当前配置的权限：
- **Contents**: Write - 允许读写仓库内容
- **Metadata**: Read - 自动包含的基础权限

### 如何修改权限

修改 [action.yml](action.yml#L69)：

```yaml
- name: Generate token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ inputs.app-id }}
    private-key: ${{ inputs.private-key }}
    owner: ${{ github.repository_owner }}
    repositories: ${{ steps.prepare-repos.outputs.repositories }}
    permission-contents: write        # Contents 权限
    permission-pull-requests: write   # 添加 PR 权限
    permission-issues: write          # 添加 Issues 权限
```

**可用权限列表：**参考 [actions/create-github-app-token 文档](https://github.com/actions/create-github-app-token#permissions)

## 故障排除

### 错误: `Input required and not supplied: app-id`

**原因：**Secrets 未配置或名称错误

**解决方法：**
1. 检查 Secrets 名称是否完全匹配：`GITHUB_APP_ID` 和 `GITHUB_APP_PRIVATE_KEY`
2. 确保 Secrets 在正确的仓库中配置
3. 注意大小写敏感

### 错误: `Failed to fetch repositories for team SOE-SRE`

**原因：**
- 个人账号没有 Teams 功能
- Team 名称错误
- GitHub App 未安装到组织

**解决方法：**
- **个人账号**：正常现象，会自动 fallback 到当前仓库
- **组织账号**：检查 team slug 是否正确，确保 GitHub App 已安装

### 错误: `Process completed with exit code 126`

**原因：**脚本缺少执行权限

**解决方法：**
```bash
chmod +x scripts/*.sh
git add scripts/*.sh
git commit -m "Add execute permissions"
git push
```

### 错误: `cannot index array with 'repositories'`

**原因：**仓库列表格式不正确

**解决方法：**已修复，确保使用最新版本的代码

### 错误: `Unexpected input(s) 'permissions'`

**原因：**`actions/create-github-app-token@v1` 不支持 `permissions` 参数

**解决方法：**使用单独的 `permission-*` 参数（已修复）

### Token 验证失败

**原因：**
- GitHub App 未安装到仓库
- 权限配置不足
- Token 已过期（tokens 有效期通常 1 小时）

**检查步骤：**
1. 确认 GitHub App 已安装到目标仓库
2. 检查 App 权限配置是否正确
3. 查看 workflow 执行日志的详细错误信息

## 高级用法

### 为多个 Team 配置不同权限

```yaml
# action.yml 中添加条件判断
- name: Generate token
  uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ inputs.app-id }}
    private-key: ${{ inputs.private-key }}
    owner: ${{ github.repository_owner }}
    repositories: ${{ steps.prepare-repos.outputs.repositories }}
    permission-contents: write
    permission-pull-requests: ${{ steps.get-team.outputs.team == 'frontend-team' && 'write' || 'read' }}
```

### Token 续期

GitHub App tokens 默认有效期 1 小时。如果 workflow 运行时间超过 1 小时，需要重新生成：

```yaml
- name: Regenerate token if needed
  if: steps.long-running-task.outcome == 'success'
  uses: ./
  with:
    app-id: ${{ secrets.GITHUB_APP_ID }}
    private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
```

### 使用 Token 访问其他仓库

```yaml
- name: Clone another team repository
  env:
    TOKEN: ${{ steps.app-token.outputs.token }}
  run: |
    git clone https://oauth2:${TOKEN}@github.com/org/other-repo.git
```

## 安全建议

1. ✅ **使用 Secrets 存储敏感信息**：永远不要在代码中硬编码 App ID 或私钥
2. ✅ **最小权限原则**：只赋予 GitHub App 必需的权限
3. ✅ **限制仓库访问**：在安装 App 时选择 "Only select repositories"
4. ✅ **定期轮换私钥**：定期重新生成 GitHub App 私钥
5. ✅ **审计日志**：定期检查 GitHub App 的使用日志

## 参考资料

- [GitHub Apps 文档](https://docs.github.com/en/apps)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [GitHub Teams API](https://docs.github.com/en/rest/teams)
- [GitHub App Permissions](https://docs.github.com/en/rest/overview/permissions-required-for-github-apps)

## 更新日志

- **2026-02-21**: 添加个人账号支持，自动 fallback 机制
- **2026-02-21**: 修复脚本执行权限问题
- **2026-02-21**: 修复 permissions 参数格式
- **2026-02-21**: 修复 yq 查询路径和输出格式

## 贡献

欢迎提交 Issue 和 Pull Request！

## License

MIT
