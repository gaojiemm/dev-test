# GitHub Copilot 中文命令

## 如何使用

在 VS Code 中按 **`Ctrl+Shift+I`** (Windows/Linux) 或 **`Cmd+Shift+I`** (Mac) 打开 Copilot Chat，然后复制下面的命令粘贴即可。

---

## 1️⃣ 生成 action.yml

### 命令 1（简洁版）

```
生成一个 GitHub Actions 复合 action（action.yml），需要实现以下功能：

1. 读取 team_mapping.yml 文件，根据当前仓库名称获取对应的团队名称
2. 使用 gh api REST API 获取该团队拥有的所有仓库，过滤出拥有 write 权限及以上的仓库
3. 使用 actions/create-github-app-token@v1 官方 action 生成 GitHub App 的 installation token
4. 输出三个值：token（生成的 token）、team（团队名称）、repositories（JSON 数组格式的仓库列表）
5. 接收三个输入参数：app-id（GitHub App ID）、private-key（App 私钥）、team-mapping-path（映射文件路径，默认为 team_mapping.yml）
6. 调用 scripts/ 目录中的三个脚本来完成各个步骤

请按照 GitHub Actions 文档生成完整的 action.yml 文件。
```

### 命令 2（详细版）

```
请生成一个 GitHub Actions 复合 action 文件（action.yml），要求如下：

动作名称：Generate Installation Token for Team Repositories
功能描述：为 GitHub Actions 生成拥有 write 权限仓库访问权的 GitHub App installation token

输入参数（inputs）：
- app-id: GitHub App 的应用 ID，必需参数
- private-key: GitHub App 的私钥，必需参数
- team-mapping-path: team_mapping.yml 文件的路径，可选，默认值为 "team_mapping.yml"

输出值（outputs）：
- token: 生成的 installation token（来自 steps.generate-token.outputs.token）
- team: 当前仓库对应的团队名称（来自 steps.get-team.outputs.team）
- repositories: token 有权访问的仓库列表，JSON 数组格式（来自 steps.prepare-repos.outputs.repositories）

执行步骤（steps）：
Step 1 - 获取团队映射：
  - 步骤 ID: get-team
  - 调用 scripts/get-team.sh 脚本，传入 team_mapping.yml 路径和当前仓库名称
  - 输出结果到 GITHUB_OUTPUT

Step 2 - 获取团队仓库列表：
  - 步骤 ID: prepare-repos
  - 调用 scripts/get-repos.sh 脚本，传入组织名和团队名
  - 环境变量：GH_TOKEN 设为 github.token
  - 输出结果到 GITHUB_OUTPUT

Step 3 - 生成 token：
  - 步骤 ID: generate-token
  - 使用 actions/create-github-app-token@v1 action
  - 设置权限：contents: write
  - 指定可访问的仓库列表

Step 4 - 输出总结信息：
  - 调用 scripts/output-token.sh 脚本
  - 输出团队名、仓库列表和 token 长度等信息

使用 composite action 格式（using: composite）。
```

---

## 2️⃣ 生成 workflow.yml

### 命令 1（简洁版）

```
生成一个 GitHub Actions workflow 文件（.github/workflows/test-token-generation.yml），需要实现以下功能：

1. 触发条件：
   - push 到 main 和 develop 分支时自动运行
   - pull request 到 main 分支时自动运行
   - 支持手动触发（workflow_dispatch）

2. 第一个 job（generate-and-test-token）：
   - 检出仓库代码
   - 调用当前目录的自定义 action 来生成 token
   - 从前一个 action 获取生成的 token、团队名和仓库列表
   - 通过调用 GitHub API 验证 token 是否有效
   - 使用 token 进行 git clone операция
   - 测试 write 权限（创建一个测试 issue，然后关闭它）
   - 输出清晰的日志和成功总结

3. 第二个 job（git-operations，可选）：
   - 依赖第一个 job 成功完成
   - 配置 git 用户信息和 token
   - 演示如何使用 token 进行 git 操作

4. 需要的 secrets：
   - GITHUB_APP_ID
   - GITHUB_APP_PRIVATE_KEY

请使用最佳实践，包括完整的错误处理和详细的日志输出。
```

### 命令 2（详细版）

```
请生成一个完整的 GitHub Actions workflow 文件（test-token-generation.yml），要求如下：

工作流名称：Test Team Token Generation
文件位置：.github/workflows/test-token-generation.yml

触发条件（on）：
- push 触发：main 和 develop 分支
- pull_request 触发：main 分支
- workflow_dispatch：手动触发

权限（permissions）：
- contents: read（默认只读）

Job 1 - generate-and-test-token：
  运行环境：ubuntu-latest
  
  Step 1.1 - 检出代码：
    使用 actions/checkout@v4

  Step 1.2 - 显示仓库信息：
    输出当前仓库、所有者、分支等信息用于调试

  Step 1.3 - 生成 token：
    调用本目录的 action（使用 ./）
    输入：
      - app-id: secrets.GITHUB_APP_ID
      - private-key: secrets.GITHUB_APP_PRIVATE_KEY
      - team-mapping-path: team_mapping.yml
    获取输出：token、team、repositories

  Step 1.4 - 验证 token 有效性：
    使用 GitHub API 调用来检查 token 是否有效
    例如：获取当前用户信息或安装信息

  Step 1.5 - 列出可访问的仓库：
    显示 token 有权访问的所有仓库列表
    使用 jq 解析 JSON 并格式化输出

  Step 1.6 - 测试 clone 操作：
    使用 token clone 当前仓库
    验证 token 可用于 git 认证

  Step 1.7 - 测试 write 权限：
    使用 token 调用 GitHub API：
      - 创建一个测试 issue
      - 关闭这个 issue
    验证确实有 write 权限

  Step 1.8 - 输出总结：
    显示测试结果、访问的团队和仓库数量

Job 2 - git-operations（可选）：
  运行环境：ubuntu-latest
  依赖关系：needs: generate-and-test-token
  条件：if: success()
  
  Step 2.1 - 检出代码：
    使用 actions/checkout@v4

  Step 2.2 - 重新生成 token：
    再次调用 action 生成 token

  Step 2.3 - 配置 git：
    设置 git 用户邮箱和用户名（使用 GitHub App 账户）
    配置认证（使用生成的 token）

  Step 2.4 - 演示 git 操作：
    输出 git 已配置，可用于：
      - git push 到团队仓库
      - git pull 从团队仓库
      - git clone 使用 token 认证

需要的 secrets：
- GITHUB_APP_ID：GitHub App 的应用 ID
- GITHUB_APP_PRIVATE_KEY：GitHub App 的私钥

最佳实践：
- 清晰的步骤名称和说明
- 完整的错误处理和失败消息
- 详细的日志输出用于调试
- 使用 environment variables 传递敏感数据
- 遵循 GitHub Actions 官方文档
```

---

## 3️⃣ 组合命令（同时生成两个文件）

```
请为我的 GitHub Actions 项目生成两个文件：

【文件 1】action.yml - GitHub Actions 复合 action

功能：生成拥有团队仓库访问权的 GitHub App installation token

输入：
- app-id: GitHub App ID
- private-key: GitHub App 私钥
- team-mapping-path: team_mapping.yml 路径（默认 team_mapping.yml）

输出：
- token: 生成的 token
- team: 团队名称
- repositories: JSON 数组格式的仓库列表

步骤：
1. 使用 scripts/get-team.sh 从 team_mapping.yml 获取团队
2. 使用 scripts/get-repos.sh 通过 gh api 获取团队的 write 权限仓库
3. 使用 actions/create-github-app-token@v1 生成 token
4. 使用 scripts/output-token.sh 输出摘要信息

【文件 2】.github/workflows/test-token-generation.yml - 测试 workflow

触发：push (main/develop)、PR (main)、手动触发

Job 1：生成和测试 token
- 调用 action 生成 token
- 通过 API 验证 token
- 测试 git clone
- 测试 write 权限（创建/关闭 issue）

Job 2：演示 git 操作（可选）
- 配置 git 用户
- 演示 push/pull/clone 操作

Secrets：GITHUB_APP_ID, GITHUB_APP_PRIVATE_KEY

两个文件都要遵循 GitHub Actions 最佳实践，包括错误处理和详细日志。
```

---

## 使用技巧

### 💡 分步骤请求
如果 Copilot 的一个回答不够完整，可以继续追问：

```
前面的 action.yml 还需要添加：
1. 完整的错误处理
2. 参数验证
3. 更详细的注释说明每个步骤
```

### 💡 指定风格
```
请按照以下风格生成：
- 清晰的注释和说明
- 遵循 GitHub 官方文档
- 包含错误处理
- 适合生产环境使用
```

### 💡 查看现有文件获得上下文
在提示词中提及你现有的脚本：

```
我已经有以下脚本在 scripts/ 目录：
- get-team.sh: 从 team_mapping.yml 获取 team
- get-repos.sh: 用 gh api 获取 write 权限仓库
- output-token.sh: 输出 token 信息

请生成 action.yml 来调用这些脚本...
```

---

## 验证生成结果

生成后检查以下几点：

**action.yml 检查清单：**
- ✅ 定义了 inputs: app-id, private-key, team-mapping-path
- ✅ 定义了 outputs: token, team, repositories
- ✅ 使用 using: composite 格式
- ✅ 调用了 scripts/ 中的所有脚本
- ✅ 包含 actions/create-github-app-token@v1
- ✅ 有完整的注释说明

**workflow.yml 检查清单：**
- ✅ 定义了触发条件（push, pull_request, workflow_dispatch）
- ✅ 引用了正确的 secrets
- ✅ 包含多个测试步骤
- ✅ 有清晰的日志输出
- ✅ 错误处理逻辑完整
- ✅ 步骤名称清晰易理解

---

## 问题排查

| 问题 | 解决方案 |
|------|--------|
| Copilot 没有生成所需的内容 | 在 Chat 中追问补充具体需求 |
| 代码语法不对 | 要求 Copilot 修复并遵循 GitHub 官方文档 |
| 缺少错误处理 | 要求添加 error handling 和 validation |
| 步骤不够清晰 | 要求添加更详细的注释和日志 |

---

## 下一步

1. 复制上面的命令
2. 打开 Copilot Chat（`Ctrl+Shift+I`）
3. 粘贴命令
4. 检查生成的代码
5. 根据需要调整和优化
6. 提交到 GitHub

祝编码愉快！🚀
