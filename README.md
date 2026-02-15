# GitHub Repository Owner Analysis

获取当前repo的所有者及其所有拥有write权限的repo，并输出到CSV文件。

## 功能

- 自动识别当前Git repo的所有者
- 使用GitHub API获取该所有者所有的repo
- 过滤出拥有write权限的repo
- 输出结果到CSV文件（包含repo名称、描述、URL、权限等信息）

## 前置要求

- bash shell
- `curl` 命令
- `jq` (可选，用于JSON解析；如果没有会使用简单的grep/sed)
- GitHub token（可选，但建议设置以提高API限制）

## 设置GitHub Token

### 方法1：环境变量（推荐）
```bash
export GITHUB_TOKEN="your_github_token_here"
```

### 方法2：Git配置
```bash
git config github.token "your_github_token_here"
```

获取GitHub Token：
1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token"
3. 选择 `public_repo` 和 `repo` scopes
4. 复制生成的token

## 使用方法

```bash
chmod +x get_repo.sh
./get_repo.sh
```

脚本会：
1. 自动检测当前Git repo的所有者
2. 使用GitHub API获取该用户的所有repo
3. 生成 `repos_with_write_access.csv` 文件

## 输出示例

CSV文件包含以下列：
- **name**: 仓库名称
- **full_name**: 完整仓库名称 (owner/repo)
- **description**: 仓库描述
- **url**: 仓库链接
- **private**: 是否为私有仓库
- **language**: 主要编程语言
- **stars**: Stars数量
- **updated_at**: 最后更新时间
- **permissions**: 权限级别 (admin/write)
