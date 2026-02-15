#!/bin/bash

# 获取当前repo的所有者及其所有拥有write权限的repo，输出到CSV文件

set -e

# 获取当前repo的所有者
get_repo_owner() {
    local remote_url
    remote_url=$(git config --get remote.origin.url)
    
    if [[ -z "$remote_url" ]]; then
        echo "Error: Could not get git remote URL"
        return 1
    fi
    
    # 解析URL获取owner和repo
    # 支持格式: git@github.com:owner/repo.git 和 https://github.com/owner/repo.git
    if [[ $remote_url =~ git@github.com:([^/]+)/(.+?)(\.git)?$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    elif [[ $remote_url =~ https://github.com/([^/]+)/(.+?)(\.git)?$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]}"
    else
        echo "Error: Not a GitHub repository"
        return 1
    fi
    
    echo "$owner" "$repo"
}

# 获取GitHub token
get_github_token() {
    local token
    
    # 从环境变量获取
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "$GITHUB_TOKEN"
        return
    fi
    
    # 尝试从git config获取
    token=$(git config --get github.token 2>/dev/null || echo "")
    if [[ -n "$token" ]]; then
        echo "$token"
        return
    fi
    
    echo "Warning: GITHUB_TOKEN not set. Please set GITHUB_TOKEN or use: git config github.token <your_token>" >&2
}

# 获取指定owner所有拥有write权限的repo
get_repos_with_write_access() {
    local owner="$1"
    local token="$2"
    local headers=""
    local auth_header=""
    
    if [[ -n "$token" ]]; then
        auth_header="-H \"Authorization: token $token\""
    fi
    
    local page=1
    local per_page=100
    local temp_file="/tmp/repos_temp_$$.json"
    
    > "$temp_file"  # 清空临时文件
    
    echo "Fetching repositories for: $owner" >&2
    
    while true; do
        local url="https://api.github.com/users/$owner/repos?page=$page&per_page=$per_page&sort=updated&direction=desc"
        
        local response
        if [[ -n "$token" ]]; then
            response=$(curl -s -H "Authorization: token $token" \
                           -H "Accept: application/vnd.github.v3+json" \
                           "$url")
        else
            response=$(curl -s -H "Accept: application/vnd.github.v3+json" "$url")
        fi
        
        # 检查是否有结果
        if [[ "$response" == "[]" ]]; then
            break
        fi
        
        # 检查错误响应
        if echo "$response" | grep -q "\"message\""; then
            echo "Error: $(echo "$response" | grep -o '\"message\"[^}]*')" >&2
            break
        fi
        
        echo "$response" >> "$temp_file"
        
        page=$((page + 1))
    done
    
    # 处理JSON并输出
    if command -v jq &> /dev/null; then
        # 使用jq处理JSON
        cat "$temp_file" | jq -r '.[] | [.name, .full_name, .description // "", .html_url, .private, .language // "", .stargazers_count, .updated_at, (if .owner.login == "'$owner'" then "admin" else "write" end)] | @csv'
    else
        # 不使用jq的方案（使用grep和sed）
        cat "$temp_file" | grep -o '"name":"[^"]*"' | sed 's/"name":"\([^"]*\)"/\1/' | while read name; do
            local full_name=$(echo "$response" | grep -o '"full_name":"[^"]*"' | head -1 | sed 's/"full_name":"\([^"]*\)"/\1/')
            local description=$(echo "$response" | grep -o '"description":"[^"]*"' | head -1 | sed 's/"description":"\([^"]*\)"/\1/')
            local url=$(echo "$response" | grep -o '"html_url":"[^"]*"' | head -1 | sed 's/"html_url":"\([^"]*\)"/\1/')
            local private=$(echo "$response" | grep -o '"private":[^,}]*' | head -1 | sed 's/"private":\([^,}]*\)/\1/')
            local language=$(echo "$response" | grep -o '"language":"[^"]*"' | head -1 | sed 's/"language":"\([^"]*\)"/\1/')
            local stars=$(echo "$response" | grep -o '"stargazers_count":[^,}]*' | head -1 | sed 's/"stargazers_count":\([^,}]*\)/\1/')
            local updated=$(echo "$response" | grep -o '"updated_at":"[^"]*"' | head -1 | sed 's/"updated_at":"\([^"]*\)"/\1/')
            
            echo "\"$name\",\"$full_name\",\"$description\",\"$url\",$private,\"$language\",$stars,\"$updated\",\"admin\""
        done
    fi
    
    rm -f "$temp_file"
}

# 将结果写入CSV文件
write_to_csv() {
    local owner="$1"
    local token="$2"
    local filename="${3:-repos_with_write_access.csv}"
    
    {
        echo "name,full_name,description,url,private,language,stars,updated_at,permissions"
        get_repos_with_write_access "$owner" "$token"
    } > "$filename"
    
    local count=$(tail -n +2 "$filename" | wc -l)
    echo "Successfully wrote $count repositories to $filename" >&2
}

# 主函数
main() {
    echo "Getting current repository owner..." >&2
    
    read -r owner repo <<< "$(get_repo_owner)"
    
    if [[ -z "$owner" ]]; then
        echo "Error: Could not determine repository owner"
        return 1
    fi
    
    echo "Current repository: $owner/$repo" >&2
    
    local token
    token=$(get_github_token)
    
    write_to_csv "$owner" "$token"
    
    echo "Done!" >&2
}

main "$@"
