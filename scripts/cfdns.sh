#!/usr/bin/env bash

#============================================================
# File: cfdns.sh
# Description: Cloudflare DNS Management Tool
# URL: https://fx4.cn/cfdns
# Author: Jetsung Chan <i@jetsung.com>
# Version: 0.1.0
# CreatedAt: 2025-08-16
# UpdatedAt: 2025-08-16
#============================================================

if [[ -n "${DEBUG:-}" ]]; then
    set -eux
else
    set -euo pipefail
fi

#
# https://developers.cloudflare.com/api/resources/dns/
#

do_request() {
    local _response=""
    METHOD="${METHOD:-GET}"
    UPDATE_DATE="${UPDATE_DATE:-{}}"
    if [ -n "$API_TOKEN" ]; then
        _response=$(curl -s -X "$METHOD" "$API_REQ" \
            -H "Authorization: Bearer $API_TOKEN" \
            -H "Content-Type:application/json" \
            -d "$UPDATE_DATE" \
        )
    elif [ -n "$API_KEY" ] && [ -n "$CF_ACCOUNT" ]; then
        _response=$(curl -s -X "$METHOD" "$API_REQ" \
            -H "X-Auth-Email: $CF_ACCOUNT" \
            -H "X-Auth-Key: $API_KEY" \
            -H "Content-Type:application/json" \
            -d "$UPDATE_DATE" \
        )
    fi
    echo "$_response"
}

generate_result() {
    local _response
    _response=$(do_request)

    if [ "$ACTION" = 'export_record' ]; then
        echo "$_response"
        return
    fi

    if [ -n "$_response" ]; then
        local success
        success=$(echo "$_response" | jq -r '.success')
        if [ "$success" != "true" ]; then
            echo "$_response" | jq -r '.errors' >&2
            exit 1
        fi
        echo "$_response" | jq -r '.result'
    else
        echo "error: Empty response from API." >&2
        exit 1
    fi
}

user_token_verify() {
    local _response=""
    API_REQ="$API_URL/user/tokens/verify"
    generate_result
}

accounts() {
    local _response

    API_REQ="$API_URL/accounts"    
    generate_result | jq -r '.[] | "\(.id) \(.name)"'
}

zones() {
    local _response

    API_REQ="$API_URL/zones"    
    generate_result | jq -r '.[] | "\(.id) \(.name)"'
}

zones_records() {
    local _response
    if [ -z "$ZONE_ID" ]; then
        printf "\033[31merror: Please specify the correct zone id.\033[0m\n"
        exit 1
    fi

    API_REQ="$API_URL/zones/$ZONE_ID/dns_records?type=${ZONE_TYPE}"
    # echo "API_REQ: $API_REQ"
    # generate_result
    generate_result | jq -r '.[] | "\(.id) \(.zone_name) \(.type) \(.name) \(.content)"'
}

create_record() {
    local _response
    if [ -z "$ZONE_ID" ] || [ -z "$CONTENT" ] || [ -z "$ZONE_TYPE" ] || [ -z "$RECORD_NAME" ]; then
        printf "\033[31merror: Please specify the correct zone id, content, zone type, record name.\033[0m\n"
        exit 1
    fi
    API_REQ="$API_URL/zones/$ZONE_ID/dns_records"
    METHOD="POST"

    if [ -z "$PROXIED" ]; then
        PROXIED="false"
    else
        PROXIED="true"
    fi

    UPDATE_DATE=$(printf '{
        "name": "%s",
        "proxied": %s,
        "content": "%s",
        "type": "%s"
    }' "$RECORD_NAME" "$PROXIED" "$CONTENT" "$ZONE_TYPE")

    # echo "$UPDATE_DATE"

    generate_result | jq -r '"Type: " + .type + " , Name: " + .name + " , Record: " + .content'
}

delete_record() {
    local _response
    if [ -z "$ZONE_ID" ] || [ -z "$RECORD_ID" ]; then
        printf "\033[31merror: Please specify the correct zone id, record id.\033[0m\n"
        exit 1
    fi
    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID"
    METHOD="DELETE"
    generate_result | jq -r
}

update_record() {
    local _response
    if [ -z "$RECORD_ID" ] || [ -z "$ZONE_ID" ] || [ -z "$CONTENT" ]; then
        printf "\033[31merror: Please specify the correct record id, zone id, content.\033[0m\n"
        exit 1
    fi
    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID"
    METHOD="PATCH"

    # UPDATE_DATE=$(printf '{
    #   "comment": "",
    #   "content": "198.51.100.4",
    #   "name": "test",
    #   "proxied": false,
    #   "ttl": 3600,
    #   "type": "%s"
    # }' "$ZONE_TYPE")

    UPDATE_DATE=$(printf '{
      "content": "%s"
    }' "$CONTENT")

    generate_result | jq -r '"Type: " + .type + " , Name: " + .name + " , Record: " + .content'
}

get_record() {
    local _response
    if [ -z "$ZONE_ID" ] || [ -z "$RECORD_ID" ]; then
        printf "\033[31merror: Please specify the correct zone id, record id.\033[0m\n"
        exit 1
    fi
    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID"
    generate_result | jq -r
}    

export_record() {
    local _response
    if [ -z "$ZONE_ID" ]; then
        printf "\033[31merror: Please specify the correct zone id.\033[0m\n"
        exit 1
    fi
    API_REQ="$API_URL/zones/$ZONE_ID/dns_records/export"
    generate_result
}


# 若存在则更新，若不存在则创建
upsert_record() {
    if [ -z "$ZONE_ID" ] || [ -z "$CONTENT" ] || [ -z "$ZONE_TYPE" ] || [ -z "$RECORD_NAME" ]; then
        echo -e "\033[31merror: Please specify the correct zone id, content, zone type, record name.\033[0m" >&2
        exit 1
    fi

    # 查找记录是否存在
    API_REQ="$API_URL/zones/$ZONE_ID/dns_records?type=${ZONE_TYPE}&name=${RECORD_NAME}"
    local existing_record
    existing_record=$(generate_result | jq -r '.[0]')
    echo "existing_record:>${existing_record}<"
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

# 设置记录：通过 主机名、域名、记录类型、记录值 
set_record() {
    if [ -z "$ZONE_NAME" ] || [ -z "$CONTENT" ] || [ -z "$ZONE_TYPE" ] || [ -z "$RECORD_NAME" ]; then
        echo -e "\033[31merror: Please specify the correct zone name, content, zone type, record name.\033[0m" >&2
        exit 1
    fi

    # 通过域名查询 ZONE_ID
    while read -r zone_id zone_name; do
        # echo "zone_id zone_name: $zone_id $zone_name"
        if [ "$ZONE_NAME" = "$zone_name" ]; then
            ZONE_ID=$zone_id
            break
        fi
    done < <(zones)

    # echo -e "ZONE_ID: $ZONE_ID"

    # 查找 record_id
    full_record_name="${ZONE_TYPE} ${RECORD_NAME}.${ZONE_NAME}"
    while read -r record_id zone_name zone_type record_name content; do
        if [[ "$full_record_name" = "$zone_type $record_name" ]]; then
            echo "Record: $record_id $zone_name $zone_type $record_name $content"
            RECORD_ID="$record_id"
            # delete_record
            # create_record
        fi
        # echo "record_id zone_name zone_type record_name content: $record_id $zone_name $zone_type $record_name $content"
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
    local HELP=""
    while [[ "$#" -gt '0' ]]; do
        case "$1" in

        '-a' | '--account')
            shift
            if [[ -z "${1:-}" ]]; then
                echo "?error: Please specify the correct account."
                exit 1
            fi
            CF_ACCOUNT="${1}"
            API_TOKEN=""
            ;;

        '-t' | '--token')
            shift
            if [[ -z "${1:-}" ]]; then
				echo "?error: Please specify the correct api token."
                exit 1
            fi
            API_TOKEN="${1}"
            ;;

        '-k' | '--key')
            shift
            if [[ -z "${1:-}" ]]; then
				echo "error: Please specify the correct api key."
                exit 1
            fi
            API_KEY="${1}"
            API_TOKEN=""
            ;;

        '-zi' | '--zone_id')
            shift
            if [[ -z "${1:-}" ]]; then
                echo "?error: Please specify the correct zone id."
                exit 1
            fi
            ZONE_ID="${1}"
            ;;

        '-zn' | '--zone_name')
            shift
            if [[ -z "${1:-}" ]]; then
                echo "?error: Please specify the correct zone name."
                exit 1
            fi
            ZONE_NAME="${1,,}"
            ;;

        '-ri' | '--record_id')
            shift
            if [[ -z "${1:-}" ]]; then 
                echo "?error: Please specify the correct record id."
                exit 1
            fi
            RECORD_ID="${1}"
            ;;

        '-zy' | '--zone_type')
            shift
            if [[ -z "${1:-}" ]]; then
                echo "?error: Please specify the correct zone type."
                exit 1
            fi
            ZONE_TYPE="${1^^}"
            ;;

        '-ct' | '--content')
            shift
            if [[ -z "${1:-}" ]]; then
                echo "?error: Please specify the correct content."
                exit 1
            fi
            CONTENT="${1}"
            ;;

        '-rn' | '--record_name')
            shift
            if [[ -z "${1:-}" ]]; then
                echo "?error: Please specify the correct record name."
                exit 1
            fi
            RECORD_NAME="${1,,}"
            ;;      

        '-pr' | '--proxied')
            PROXIED=1
            ;;
        
        '-ac' | '--action')
            shift
            if [[ -z "${1:-}" ]]; then
                echo "?error: Please specify the correct action."
                exit 1
            fi
            ACTION="${1}"
            ;;

        '-h' | '--help')
            HELP='1'
            break
            ;;

        *)
            echo "$0: unknown option -- $1"
            exit 1
            ;;

        esac
        shift
    done

    if [ -n "${HELP}" ]; then
        show_help
    fi
}

# 显示帮助信息
show_help() {
    cat <<EOF
usage: $0 [ options ]
  -h, --help                           print help
  -a, --account <account>              set Cloudflare account
  -t, --token <token>                  set API token
  -k, --key <key>                      set API key
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

main() {
    API_URL="https://api.cloudflare.com/client/v4"

    API_TOKEN="${CLOUDFLARE_API_TOKEN:-}" # CLOUDFLARE_API_TOKEN
    API_KEY="${CLOUDFLARE_API_KEY:-}"     # CLOUDFLARE_API_KEY
    CF_ACCOUNT="${CLOUDFLARE_EMAIL:-}"      # CLOUDFLARE_EMAIL

    ZONE_ID=""   # 域名ID
    ZONE_NAME="" # 域名

    ZONE_TYPE="" # 主机类型
    RECORD_ID="" # 记录ID

    METHOD=''      # 请求方法
    UPDATE_DATE='' # 更新内容

    RECORD_NAME='' # 主机名
    CONTENT='' # 值
    PROXIED='' # 代理

    ACTION='' # 动作

    judgment_parameters "$@"

    # echo "API_TOKEN: ${API_TOKEN}"
    # echo "API_KEY: ${API_KEY}"
    # echo "CF_ACCOUNT: ${CF_ACCOUNT}"
    # echo

    if command -v "$ACTION" >/dev/null 2>&1; then
        # user_token_verify
        # accounts

        # zones
        # zones_records

        # create_record
        # delete_record
        # update_record
        # get_record
        # export_record    
        "$ACTION"
    else
        printf "\033[31merror: Please specify the correct action.\033[0m\n"
        exit 1
    fi    
}

main "$@"
