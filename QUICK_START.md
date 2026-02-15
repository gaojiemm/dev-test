# 快速开始指南

## 1. 准备工作

### 创建GitHub App
如果还没有GitHub App，需要先创建一个：

1. 访问 GitHub Settings → Developer settings → GitHub Apps
2. 点击 "New GitHub App"
3. 填写应用信息：
   - App name: 例如 "Team Token Generator"
   - Homepage URL: 你的仓库URL
   - Webhook: 可以禁用
4. 设置权限：
   - Repository permissions:
     - Contents: Read & write
     - Metadata: Read
   - Organization permissions:
     - Members: Read
5. 保存App ID和生成私钥

### 配置仓库Secrets

1. 进入仓库 Settings → Secrets and variables → Actions
2. 创建新的Secret：
   - Name: `GITHUB_APP_ID`
   - Value: 粘贴App ID
3. 再创建一个Secret：
   - Name: `GITHUB_APP_PRIVATE_KEY`
   - Value: 粘贴私钥内容

## 2. 配置team_mapping.yml

编辑 `team_mapping.yml` 文件，添加你的repo到team的映射：

```yaml
- repo: your-repo-name
  team: your-team-slug

- repo: another-repo
  team: another-team
```

获取team-slug方法：
- 访问 GitHub Organization → Teams
- 选择team，URL中的`/teams/xxx/`部分就是team-slug

## 3. 测试Action

### 方法1：运行测试workflow

1. 提交代码到main分支或创建PR
2. 进入仓库 Actions 标签页
3. 选择 "Test Team Token Generation" workflow
4. 点击 "Run workflow"

查看日志输出，确认token生成成功。

### 方法2：本地测试

你也可以在本地运行bash脚本（需要设置GITHUB_TOKEN）：

```bash
# 获取拥有write权限的repo
export GITHUB_TOKEN="your_token_here"
./get_repo.sh

# 获取team的所有repo
./get-team-repos.sh organization-name team-name
```

## 4. 在你的workflow中使用

```yaml
name: Your Workflow

on: [push, pull_request]

jobs:
  do-something:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      # 生成token
      - name: Generate token
        id: token
        uses: ./
        with:
          app-id: ${{ secrets.GITHUB_APP_ID }}
          private-key: ${{ secrets.GITHUB_APP_PRIVATE_KEY }}
      
      # 使用token
      - name: Use token
        env:
          TOKEN: ${{ steps.token.outputs.token }}
        run: |
          # 例如：git push
          git push https://oauth2:${TOKEN}@github.com/owner/repo.git
```

## 5. 故障排除

### 错误：team_mapping.yml not found

- 确保文件在仓库根目录
- 检查拼写和路径

### 错误：Could not find team mapping for repository

- 检查 `team_mapping.yml` 中是否有该repo的映射
- 确保repo名称不包含owner部分

### 错误：Failed to fetch repositories for team

- 检查team名称是否正确（使用team-slug，不是display name）
- 确保GitHub App在organization中已安装
- 检查App权限是否正确设置

### Token claims insufficient permissions

- 进入组织 Settings → GitHub Apps
- 选择你的App → Organization permissions
- 确保有正确的权限

## 6. 进阶用法

### 访问多个team的repo

修改 `team_mapping.yml` 为多条目：

```yaml
- repo: frontend-repo
  team: frontend-team

- repo: backend-repo
  team: backend-team

- repo: devops-repo
  team: devops-team
```

### 限制token权限

编辑 `action.yml` 中的permissions部分：

```yaml
permissions: |-
  contents: write
  pull-requests: write
  issues: read
```

## 7. 日志和调试

### 查看详细日志

在workflow运行时，点击各个step可以看到详细的执行日志。

### 添加调试输出

在 GitHub Actions workflow中可以启用调试：

1. Settings → Secrets and variables → Actions
2. 添加新Secret：
   - Name: `ACTIONS_STEP_DEBUG`
   - Value: `true`

这样会输出额外的调试信息。
