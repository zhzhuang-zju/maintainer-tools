#!/usr/bin/env python3
"""
Script to fetch PR information from GitHub for changelog generation.
Only fetches and displays PR info, doesn't write to changelog.

Usage:
    python3 fetch_pr_info.py <base_tag> <head_branch> [repo_owner] [repo_name]
    
Examples:
    python3 fetch_pr_info.py v1.14.1 release-1.14
    python3 fetch_pr_info.py v1.15.0-alpha.2 master
    python3 fetch_pr_info.py v1.13.0 release-1.13 karmada-io karmada
"""

import requests
import re
import sys
import argparse
from datetime import datetime
import os

# GitHub API configuration
GITHUB_API_BASE = "https://api.github.com"

def get_github_token():
    """Get GitHub token from environment or prompt user"""
    token = os.getenv('GITHUB_TOKEN')
    if not token:
        print("GitHub token not found in environment.")
        print("You can set GITHUB_TOKEN environment variable to avoid rate limits.")
        token = input("Enter GitHub token (press Enter to skip): ").strip()
        if not token:
            token = None
    return token

def make_github_request(url, token=None):
    """Make authenticated GitHub API request"""
    headers = {
        'Accept': 'application/vnd.github.v3+json',
        'User-Agent': 'Karmada-Changelog-Generator'
    }
    if token:
        headers['Authorization'] = f'token {token}'
    
    try:
        response = requests.get(url, headers=headers)
        if response.status_code == 200:
            return response.json()
        elif response.status_code == 403:
            print(f"Rate limit exceeded. Consider using a GitHub token.")
            return None
        else:
            print(f"Error fetching {url}: {response.status_code}")
            return None
    except Exception as e:
        print(f"Request failed: {e}")
        return None

def get_commit_comparison(repo_owner, repo_name, base_tag, head_branch, token=None):
    """Get commit comparison between base tag and head branch"""
    url = f"{GITHUB_API_BASE}/repos/{repo_owner}/{repo_name}/compare/{base_tag}...{head_branch}"
    return make_github_request(url, token)

def get_pr_details_batch(repo_owner, repo_name, pr_numbers, token=None):
    """Fetch multiple PR details in a single GraphQL request"""
    if not pr_numbers:
        return {}

    query_fields = """
      number
      title
      body
      author {
        login
      }
    """

    query_parts = []
    for i, num in enumerate(pr_numbers):
        alias = f"pr{i}"
        query_parts.append(f"{alias}: pullRequest(number: {num}) {{ {query_fields} }}")

    full_query = f"""
    {{
      repository(owner: "{repo_owner}", name: "{repo_name}") {{
        {" ".join(query_parts)}
      }}
    }}
    """

    headers = {
        'Content-Type': 'application/json',
        'User-Agent': 'Karmada-Changelog-Generator'
    }
    if token:
        headers['Authorization'] = f'Bearer {token}'

    try:
        response = requests.post(
            'https://api.github.com/graphql',
            json={'query': full_query},
            headers=headers
        )
        if response.status_code == 200:
            data = response.json()
            if 'errors' in data:
                print(f"GraphQL errors: {data['errors']}")
                return {}
            repo_data = data.get('data', {}).get('repository', {})
            result = {}
            for i, num in enumerate(pr_numbers):
                pr_data = repo_data.get(f'pr{i}')
                if pr_data:
                    result[num] = {
                        'number': pr_data['number'],
                        'title': pr_data['title'],
                        'body': pr_data['body'],
                        'user': {'login': pr_data['author']['login']} if pr_data['author'] else {'login': 'unknown'}
                    }
            return result
        elif response.status_code == 401:
            print("GraphQL request unauthorized. Check your token permissions.")
        elif response.status_code == 403:
            print("GraphQL rate limit exceeded or insufficient permissions.")
        else:
            print(f"GraphQL request failed: {response.status_code} - {response.text}")
        return {}
    except Exception as e:
        print(f"GraphQL request error: {e}")
        return {}

def extract_user_facing_change(pr_body):
    """Extract user-facing change from PR description, supporting both release-note and fallback style."""
    if not pr_body:
        return None

    # Pattern 1: Standard ```release-note ... ```
    release_note_patterns = [
        r"```release-note\s*[\r\n]+([^`]+?)[\r\n]*```",
        r"```release-note\s*[\r\n]+([^\r\n]+(?:[\r\n]+[^\r\n`]+)*)",
    ]

    for pattern in release_note_patterns:
        match = re.search(pattern, pr_body, re.MULTILINE | re.DOTALL)
        if match:
            content = match.group(1).strip()
            if content.lower() not in {'none', 'no', 'n/a', 'na', '', 'nope', 'nothing', 'noop'} and len(content) > 3:
                return re.sub(r'\s+', ' ', content)

    # Pattern 2: Fallback — look after "**Does this PR introduce a user-facing change?**:" for a code block
    fallback_match = re.search(
        r"\*\*Does this PR introduce a user-facing change\?\*\*:\s*```(?:[a-z]*\s*)?([\s\S]*?)```",
        pr_body,
        re.IGNORECASE
    )
    if fallback_match:
        content = fallback_match.group(1).strip()
        if content.lower() not in {'none', 'no', 'n/a', 'na', '', 'nope', 'nothing', 'noop'} and len(content) > 3:
            return re.sub(r'\s+', ' ', content)

    return None

import re

def extract_pr_kind(pr_body):
    """
    Extract the PR kind(s) from the section between
    '**What type of PR is this?**' and '**What this PR does / why we need it**:'.
    Ignores any content inside HTML comments (<!-- ... -->).

    Returns:
        list[str] or None: List of kinds (e.g., ['feature']), or None if no valid /kind found.
    """
    if not pr_body:
        return None

    # Step 1: Extract the section between the two headers
    start_marker = r"\*\*What type of PR is this\?\*\*"
    end_marker = r"\*\*What this PR does / why we need it\*\*:"

    match_section = re.search(
        f"{start_marker}(.*?){end_marker}",
        pr_body,
        re.DOTALL | re.IGNORECASE
    )

    if not match_section:
        return None

    section_text = match_section.group(1)

    # Step 2: Remove all HTML comments (including multi-line)
    # This regex matches <!-- ... -->, even across newlines
    cleaned_text = re.sub(r"<!--.*?-->", "", section_text, flags=re.DOTALL)

    # Step 3: Find all /kind lines outside comments
    kind_pattern = r"^\s*/kind\s+([a-zA-Z0-9-]+)\s*$"
    kinds = re.findall(kind_pattern, cleaned_text, re.MULTILINE)

    return kinds if kinds else None

def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description="Fetch PR information from GitHub for changelog generation",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python3 fetch_pr_info.py v1.14.1 release-1.14
    python3 fetch_pr_info.py v1.15.0-alpha.2 master
    python3 fetch_pr_info.py v1.13.0 release-1.13 --repo karmada-io/karmada
        """
    )
    
    parser.add_argument('base_tag', help='Base tag/branch to compare from (e.g., v1.14.1)')
    parser.add_argument('head_branch', help='Head tag/branch to compare to (e.g., release-1.14)')
    parser.add_argument('--repo', default='karmada-io/karmada', 
                       help='Repository in format owner/name (default: karmada-io/karmada)')
    
    return parser.parse_args()

def main():
    args = parse_arguments()
    
    if '/' in args.repo:
        repo_owner, repo_name = args.repo.split('/', 1)
    else:
        print("Error: Repository must be in format 'owner/name'")
        return 1
    
    print(f"Fetching PR information for {args.repo}...")
    print(f"Comparing {args.base_tag}...{args.head_branch}")
    print("="*80)
    
    token = get_github_token()
    
    comparison = get_commit_comparison(repo_owner, repo_name, args.base_tag, args.head_branch, token)
    if not comparison:
        print("Failed to get commit comparison")
        return 1
    
    print(f"Found {len(comparison['commits'])} commits")
    
    pr_numbers = set()
    merge_pattern = r"Merge pull request #(\d+)"
    
    for commit in comparison['commits']:
        message = commit['commit']['message']
        match = re.search(merge_pattern, message)
        if match:
            pr_numbers.add(int(match.group(1)))
    
    print(f"Found {len(pr_numbers)} merged PRs")
    print("="*80)
    
    # Use GraphQL to fetch all PRs in one request
    sorted_pr_numbers = sorted(pr_numbers)
    print(f"\nFetching {len(sorted_pr_numbers)} PRs via GraphQL...")
    pr_details_map = get_pr_details_batch(repo_owner, repo_name, sorted_pr_numbers, token)

    pr_info_list = []
    for pr_number in sorted_pr_numbers:
        pr_details = pr_details_map.get(pr_number)
        if not pr_details:
            print(f"  PR #{pr_number} not found or skipped")
            continue
        
        pr_title = pr_details['title']
        pr_body = pr_details['body'] or ""
        author = pr_details['user']['login']
        
        print(f"\nPR #{pr_number}")
        print(f"  Title: {pr_title}")
        print(f"  Author: @{author}")
        
        user_facing_change = extract_user_facing_change(pr_body)
        kind = extract_pr_kind(pr_body)
        
        if user_facing_change:
            print(f"  User-facing change: {user_facing_change}")
            pr_info_list.append({
                'number': pr_number,
                'title': pr_title,
                'author': author,
                'kind': kind,
                'user_facing_change': user_facing_change
            })
        else:
            print(f"  No user-facing change found")
            if pr_number == 6524:
                print(f"  DEBUG PR #6524 - Full body length: {len(pr_body)}")
                if "release-note" in pr_body:
                    print(f"  DEBUG: Found 'release-note' in body")
                    pattern = r"```release-note\s*[\r\n]+([^`]+?)[\r\n]*```"
                    match = re.search(pattern, pr_body, re.MULTILINE | re.DOTALL)
                    if match:
                        print(f"  DEBUG: Regex MATCHED! Content: {repr(match.group(1)[:100])}")
                    else:
                        print(f"  DEBUG: Regex did NOT match")
                        lines = pr_body.split('\n')
                        for i, line in enumerate(lines):
                            if 'release-note' in line:
                                context_start = max(0, i-2)
                                context_end = min(len(lines), i+8)
                                context = '\n'.join(lines[context_start:context_end])
                                print(f"  DEBUG Context around release-note:\n{repr(context)}")
                                break
            
            if "user-facing" in pr_body.lower():
                lines = pr_body.split('\n')
                for i, line in enumerate(lines):
                    if 'user-facing' in line.lower():
                        context_start = max(0, i-1)
                        context_end = min(len(lines), i+4)
                        context = '\n'.join(lines[context_start:context_end])
                        print(f"  Context found:\n{context[:200]}...")
                        break
    
    print("\n" + "="*80)
    print("SUMMARY OF PRS WITH USER-FACING CHANGES")
    print("="*80)
    
    if pr_info_list:
        for pr_info in pr_info_list:
            print(f"\nPR #{pr_info['number']} by @{pr_info['author']}")
            print(f"Title: {pr_info['title']}")
            print(f"Kind: {pr_info['kind']}")
            print(f"Change: {pr_info['user_facing_change']}")
    else:
        print("No PRs with user-facing changes found.")
    
    print(f"\nTotal PRs with user-facing changes: {len(pr_info_list)}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
