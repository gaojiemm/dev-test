#!/usr/bin/env python3
"""
获取当前repo所有者及其所有拥有write权限的repo，输出到CSV文件
"""

import os
import json
import csv
import subprocess
import requests
from urllib.parse import urlparse
from datetime import datetime

def get_repo_owner():
    """获取当前repo的所有者和repo名称"""
    try:
        # 获取remote URL
        result = subprocess.run(
            ['git', 'config', '--get', 'remote.origin.url'],
            capture_output=True,
            text=True,
            check=True
        )
        remote_url = result.stdout.strip()
        
        # 解析URL获取owner和repo
        if 'github.com' in remote_url:
            # 支持 https://github.com/owner/repo.git 和 git@github.com:owner/repo.git 格式
            if remote_url.startswith('git@'):
                # git@github.com:owner/repo.git
                parts = remote_url.split(':')[1].split('/')
            else:
                # https://github.com/owner/repo.git
                parts = urlparse(remote_url).path.strip('/').split('/')
            
            owner = parts[0]
            repo = parts[1].replace('.git', '')
            return owner, repo
        else:
            raise Exception("Not a GitHub repository")
    except subprocess.CalledProcessError as e:
        print(f"Error getting git remote: {e}")
        return None, None

def get_github_token():
    """从环境变量或git config获取GitHub token"""
    # 首先尝试从环境变量获取
    token = os.environ.get('GITHUB_TOKEN')
    if token:
        return token
    
    # 尝试从git config获取
    try:
        result = subprocess.run(
            ['git', 'config', '--get', 'github.token'],
            capture_output=True,
            text=True
        )
        token = result.stdout.strip()
        if token:
            return token
    except:
        pass
    
    print("Warning: GITHUB_TOKEN environment variable not set")
    print("Please set GITHUB_TOKEN or use: git config github.token <your_token>")
    return None

def get_repos_with_write_access(owner, token):
    """获取指定owner所有拥有write权限的repo"""
    repos = []
    headers = {}
    
    if token:
        headers['Authorization'] = f'token {token}'
    
    headers['Accept'] = 'application/vnd.github.v3+json'
    
    page = 1
    per_page = 100
    
    while True:
        url = f'https://api.github.com/users/{owner}/repos'
        params = {
            'page': page,
            'per_page': per_page,
            'sort': 'updated',
            'direction': 'desc'
        }
        
        try:
            response = requests.get(url, headers=headers, params=params, timeout=10)
            response.raise_for_status()
        except requests.exceptions.RequestException as e:
            print(f"Error fetching repos: {e}")
            break
        
        data = response.json()
        
        if not data:
            break
        
        for repo in data:
            # 检查权限：用户是owner或有push权限
            if repo['owner']['login'] == owner or repo.get('permissions', {}).get('push', False):
                repos.append({
                    'name': repo['name'],
                    'full_name': repo['full_name'],
                    'description': repo.get('description', ''),
                    'url': repo['html_url'],
                    'private': repo['private'],
                    'language': repo.get('language', ''),
                    'stars': repo['stargazers_count'],
                    'updated_at': repo['updated_at'],
                    'permissions': 'admin' if repo['owner']['login'] == owner else 'write'
                })
        
        page += 1
    
    return repos

def write_to_csv(repos, filename='repos_with_write_access.csv'):
    """将结果写入CSV文件"""
    if not repos:
        print("No repositories found")
        return
    
    try:
        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            fieldnames = ['name', 'full_name', 'description', 'url', 'private', 'language', 'stars', 'updated_at', 'permissions']
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            
            writer.writeheader()
            writer.writerows(repos)
        
        print(f"Successfully wrote {len(repos)} repositories to {filename}")
    except IOError as e:
        print(f"Error writing to CSV file: {e}")

def main():
    print("Getting current repository owner...")
    owner, repo = get_repo_owner()
    
    if not owner:
        print("Error: Could not determine repository owner")
        return
    
    print(f"Current repository: {owner}/{repo}")
    
    token = get_github_token()
    
    print(f"Fetching repositories for user: {owner}")
    repos = get_repos_with_write_access(owner, token)
    
    if repos:
        print(f"Found {len(repos)} repositories with write access")
        write_to_csv(repos)
        print("\nTop 10 repositories:")
        for i, repo_info in enumerate(repos[:10], 1):
            print(f"  {i}. {repo_info['full_name']} ({repo_info['permissions']})")
    else:
        print("No repositories found")

if __name__ == '__main__':
    main()
