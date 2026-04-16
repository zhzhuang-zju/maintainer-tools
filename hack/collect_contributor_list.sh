#!/bin/bash

REPO_OWNER="karmada-io"
REPO_NAME="dashboard"
# 定义起始日期和结束日期
START_DATE=$1
END_DATE=$2
TOKEN=$3

# 用于存储所有作者登录名的内部变量
all_authors_str=""

# 初始化日期变量
current_date=$START_DATE

# 循环遍历每一天
while [[ $current_date < $END_DATE ]]; do
    next_date=$(date -I -d "$current_date + 1 day")
    # 构建 API 请求 URL
    URL="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/commits?since=${current_date}T00:00:00Z&until=${next_date}T00:00:00Z&per_page=100"

    echo "Fetching data for date: $current_date"
    daily_authors=$(curl -s -H "Authorization: Bearer $TOKEN" "$URL" | jq '.[] | {author_login: .author.login}' | sort | uniq)
    if [ -n "$daily_authors" ]; then
        # 将当天的作者信息添加到总的作者信息字符串中
        all_authors_str="${all_authors_str}\n${daily_authors}"
        echo "$daily_authors"
    else
        echo "No authors found for $current_date."
    fi
    # 更新当前日期
    current_date=$next_date
done

# 对所有数据进行去重
final_authors=$(echo -e "$all_authors_str" | sort -u)
echo "Final unique authors:"
echo "$final_authors"
