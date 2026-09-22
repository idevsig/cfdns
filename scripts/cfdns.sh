#!/usr/bin/env bash

#============================================================
# File: cfdns.sh
# Description: Cloudflare DNS Management Tool
# URL: https://fx4.cn/cfdns
# Author: Jetsung Chan <i@jetsung.com>
# Version: 0.2.0
# CreatedAt: 2025-08-16
# UpdatedAt: 2026-09-23
#============================================================

set -euo pipefail

#
# https://developers.cloudflare.com/api/resources/dns/
#

API_URL="https://api.cloudflare.com/client/v4"

# 默认变量
API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

ZONE_ID=""
ZONE_NAME=""
ZONE_TYPE=""
RECORD_ID=""
RECORD_NAME=""
CONTENT=""
PROXIED=""
ACTION=""

# 输出错误信息并退出
error_exit() {
    echo -e "\033[31merror: $1\033[0m" >&2
    exit 1
}

# 通用请求函数
do_request() {
    local method="${METHOD:-GET}"
    local update_data="${UPDATE_DATA:-{}}"
    local headers=()

    if [ -z "$API_TOKEN" ]; then
        error_exit "CLOUDFLARE_API_TOKEN must be set."
    fi
    headers+=("-H" "Authorization: Bearer $API_TOKEN")

    # DEBUG 调试模式：仅输出请求方法与 URL，不输出 Token
    if [ -n "${DEBUG:-}" ]; then
        printf 'DEBUG: %s %s\n' "$method" "$API_REQ" >&2
    fi

    curl -s -X "$method" "$API_REQ" \
        "${headers[@]}" \
        -H "Content-Type: application/json" \
        -d "$update_data"
}

# 处理API响应
generate_result() {
    local response
    response=$(do_request)

    if [ "$ACTION" = 'export_record' ]; then
        echo "$response"
        return
    fi

    if [ -z "$response" ]; then
        error_exit "Empty response from API."
    fi

    local success
    success=$(echo "$response" | jq -r '.success')
    if [ "$success" != "true" ]; then
        echo "$response" | jq -r '.errors' >&2
        exit 1
    fi

    echo "$response" | jq -r '.result'
}

# 用户令牌验证
user_token_verify() {
    API_REQ="$API_URL/user/tokens/verify"
    generate_result
}

# 获取账户列表
accounts() {
    API_REQ="$API_URL/accounts"
    generate_result | jq -r '.[] | "\(.id) \(.name)"'
}

# 获取区域列表
zones() {
    API_REQ="$API_URL/zones"
    generate_result | jq -r '.[] | "\(.id) \(.name)"'
}

# 获取区域记录
zones_records() {
    [ -z "$ZONE_ID" ] && error_exit "Please specify the correct zone id."

    API_REQ="$API_URL/zones/$ZONE_ID/dns_records?type=${ZONE_TYPE}"
    generate_result | jq -r '.[] | "\(.id) \(.zone_name) \(.type) \(.name) \(.content)"'
}

# 创建记录
create_record() {
    [ -z "$ZONE_ID" ] && error_exit "Please specify the correct zone id."
    [ -z "$CONTENT" ] && error_exit "Please specify the correct content."
    [ -z "$ZONE_TYPE" ] && error_exit "Please specify the correct zone type."
    [ -z "$RECORD_NAME" ] && error_exit "Please specify the correct record name."

    API_REQ="$API_URL/zones/$ZONE_ID/dns_records"
    METHOD="POST"
    UPDATE_DATA=$(jq -n \
        --arg name "$RECORD_NAME" \
        --arg content "$CONTENT" \
        --arg type "$ZONE_TYPE" \
        --argjson proxied "${PROXIED:-false}" \
        '{
            name: $name,
            content: $content,
            type: $type,
            proxied: $proxied
        }')

    generate_result | jq -r
}

# 删除记录
delete_record() {
    [ -z "$ZONE_ID" ] && error_exit "Please specify the correct zone id."
    [ -z "$RECORD_ID" ] && error_exit "Please specify the correct record id."

    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID"
    METHOD="DELETE"
    generate_result | jq -r
}

# 更新记录
update_record() {
    [ -z "$RECORD_ID" ] && error_exit "Please specify the correct record id."
    [ -z "$ZONE_ID" ] && error_exit "Please specify the correct zone id."
    [ -z "$CONTENT" ] && error_exit "Please specify the correct content."

    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID"
    METHOD="PATCH"
    UPDATE_DATA=$(jq -n --arg content "$CONTENT" '{content: $content}')

    generate_result | jq -r
}

# 获取记录
get_record() {
    [ -z "$ZONE_ID" ] && error_exit "Please specify the correct zone id."
    [ -z "$RECORD_ID" ] && error_exit "Please specify the correct record id."

    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID"
    generate_result | jq -r
}

# 导出记录
export_record() {
    [ -z "$ZONE_ID" ] && error_exit "Please specify the correct zone id."

    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/export"
    generate_result
}

# 若存在则更新，若不存在则创建
upsert_record() {
    [ -z "$ZONE_ID" ] && error_exit "Please specify the correct zone id."
    [ -z "$CONTENT" ] && error_exit "Please specify the correct content."
    [ -z "$ZONE_TYPE" ] && error_exit "Please specify the correct zone type."
    [ -z "$RECORD_NAME" ] && error_exit "Please specify the correct record name."

    # 查找记录是否存在
    API_REQ="$API_URL/zones/$ZONE_ID/dns_records?type=${ZONE_TYPE}&name=${RECORD_NAME}"
    local existing_record
    existing_record=$(generate_result | jq -r '.[0]')

    if [ -n "$existing_record" ] && [ "$existing_record" != "null" ]; then
        # 如果记录存在，则更新
        RECORD_ID=$(echo "$existing_record" | jq -r '.id')
        echo "Record exists, updating..."
        update_record
    else
        # 如果记录不存在，则创建
        echo "Record does not exist, creating..."
        create_record
    fi
}

# 设置记录：通过主机名、域名、记录类型、记录值
set_record() {
    [ -z "$ZONE_NAME" ] && error_exit "Please specify the correct zone name."
    [ -z "$CONTENT" ] && error_exit "Please specify the correct content."
    [ -z "$ZONE_TYPE" ] && error_exit "Please specify the correct zone type."
    [ -z "$RECORD_NAME" ] && error_exit "Please specify the correct record name."

    # 通过域名查询 ZONE_ID
    while read -r zone_id zone_name; do
        if [ "$ZONE_NAME" = "$zone_name" ]; then
            ZONE_ID=$zone_id
            break
        fi
    done < <(zones)

    [ -z "$ZONE_ID" ] && error_exit "Zone not found for $ZONE_NAME."

    # 查找 record_id
    local full_record_name="${ZONE_TYPE} ${RECORD_NAME}.${ZONE_NAME}"
    while read -r record_id zone_name zone_type record_name _; do
        if [[ "$full_record_name" = "$zone_type $record_name" ]]; then
            RECORD_ID="$record_id"
            break
        fi
    done < <(zones_records)

    if [ -z "$RECORD_ID" ]; then
        echo "Record does not exist, creating..."
        create_record
    else
        echo "Record exists, updating..."
        update_record
    fi
}

# 处理参数信息
judgment_parameters() {
    while [[ "$#" -gt '0' ]]; do
        case "$1" in
            '-t' | '--token')
                shift
                API_TOKEN="${1:?"error: Please specify the correct api token."}"
                ;;
            '-zi' | '--zone_id')
                shift
                ZONE_ID="${1:?"error: Please specify the correct zone id."}"
                ;;
            '-zn' | '--zone_name')
                shift
                ZONE_NAME="${1:?"error: Please specify the correct zone name."}"
                ;;
            '-ri' | '--record_id')
                shift
                RECORD_ID="${1:?"error: Please specify the correct record id."}"
                ;;
            '-zy' | '--zone_type')
                shift
                ZONE_TYPE="${1:?"error: Please specify the correct zone type."}"
                ;;
            '-ct' | '--content')
                shift
                CONTENT="${1:?"error: Please specify the correct content."}"
                ;;
            '-rn' | '--record_name')
                shift
                RECORD_NAME="${1:?"error: Please specify the correct record name."}"
                ;;
            '-pr' | '--proxied')
                PROXIED="true"
                ;;
            '-ac' | '--action')
                shift
                ACTION="${1:?"error: Please specify the correct action."}"
                ;;
            '-h' | '--help')
                show_help
                ;;
            *)
                echo "$0: unknown option -- $1" >&2
                exit 1
                ;;
        esac
        shift
    done
}

# 显示帮助信息
show_help() {
    cat <<EOF
usage: $0 [ options ]
  -h, --help                           print help
  -t, --token <token>                  set API token
  -zi, --zone_id <zone_id>             set zone ID
  -ri, --record_id <record_id>         set record ID
  -zy, --zone_type <zone_type>         set zone type
  -ct, --content <content>             set content
  -rn, --record_name <record_name>     set record name
  -pr, --proxied                       enable proxied
  -ac, --action <action>               set action (e.g., create_record, delete_record, upsert_record, etc.)
EOF
    exit 0
}

# 动作白名单校验
validate_action() {
    case "$ACTION" in
        user_token_verify|accounts|zones|zones_records|create_record|delete_record|update_record|get_record|export_record|upsert_record|set_record)
            ;;
        *)
            error_exit "Please specify the correct action."
            ;;
    esac
}

main() {
    judgment_parameters "$@"
    validate_action

    "$ACTION"
}

main "$@"
