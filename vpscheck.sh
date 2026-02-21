#!/usr/bin/env bash
#=================================================================
#  VPS 全能检测脚本  vpscheck  v3.2.0
#
#  作者:   静水流深
#  网站:   中国站长
#  网址:   https://cnwebmasters.com
#  协议:   本脚本版权归作者所有，转载请注明出处
#
#  流媒体: Netflix / Disney+ / HotStar / DAZN / Spotify
#          YouTube / TikTok / HBO Max / Hulu / Prime Video
#          Apple TV+ / Paramount+ / Peacock / BBC iPlayer
#          Bahamut / AbemaTV / NicoNico / TVBAnywhere+ / F1 TV
#
#  AI服务: ChatGPT / OpenAI API / Gemini / Claude / Copilot
#          Grok / Perplexity / Mistral / Character.AI / Poe / Sora
#
#  IP分析: 类型识别(家宽/机房/移动/VPN) / 风险评分 / 黑名单检测
#
#  性能:   系统信息 / 磁盘I/O / 三网测速 / UnixBench / 延迟
#
#  路由:   回程路由检测 / 绕路识别 / 直连判定
#          电信 / 联通 / 移动 / 教育网 / 广电
#
#  支持地区: 新加坡/香港/台湾/北美/日本/澳洲/欧洲
#=================================================================

VER='3.2.0'
SCRIPT_NAME="VPS 全能检测"

# Bash 版本检测（declare -A 关联数组需要 Bash 4.0+）
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "错误：此脚本需要 Bash 4.0 或更高版本（当前: ${BASH_VERSION}）"
    echo "CentOS 6 用户请先升级 Bash：yum install -y bash"
    exit 1
fi
HISTORY_FILE="/tmp/.mediacheck_history"
REPORT_FILE=""

# ─────────────────────────────────────────────
#  颜色 & 样式
# ─────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
WHITE='\033[0;37m'
PLAIN='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# ─────────────────────────────────────────────
#  User-Agent
# ─────────────────────────────────────────────
UA_BROWSER="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"
UA_ANDROID="Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36"

# ─────────────────────────────────────────────
#  全局状态变量
# ─────────────────────────────────────────────
CURL_OPTS="--max-time 10 --retry 1 -sL"
PROXY_OPTS=""
USE_INTERFACE=""
SHOW_ONLY_UNLOCKED=0
SAVE_REPORT=0
TOTAL_CHECKS=0
UNLOCKED_COUNT=0
FAILED_COUNT=0
BLOCKED_COUNT=0
REPORT_BUFFER=""

# IP 分析结果
LOCAL_IP=""
LOCAL_IP_MASKED=""
LOCAL_COUNTRY=""
LOCAL_COUNTRY_CODE=""
LOCAL_CITY=""
LOCAL_ORG=""
LOCAL_ASN=""
IP_TYPE=""
IP_TYPE_ICON=""
IP_RISK_SCORE=0
IP_IS_PROXY="否"
IP_IS_HOSTING="否"
IP_ABUSE_SCORE=0
IP_BLACKLIST_STATUS="未检测"
IP_STREAM_SCORE=0
SCAM_SCORE="N/A"

# 历史记录
HISTORY_UNLOCKED=0
HISTORY_BLOCKED=0
HISTORY_TOTAL=0
HISTORY_DATE=""
HISTORY_IP_MASKED=""

# 测速 & 跑分
SPEEDTEST_BIN=""
SPEEDTEST_LOG="/tmp/.speedtest_tmp.log"
BENCH_WORKDIR="/tmp/.mediacheck_bench"

# ─────────────────────────────────────────────
#  工具函数
# ─────────────────────────────────────────────
command_exists() { command -v "$1" >/dev/null 2>&1; }

print_line() {
    echo -e "${DIM}$(printf '%.0s─' {1..68})${PLAIN}"
}

print_thin_line() {
    echo -e "${DIM}$(printf '%.0s·' {1..68})${PLAIN}"
}

# 输出并同步写入 report buffer（去色后）
recho() {
    echo -e "$1"
    if [[ "$SAVE_REPORT" -eq 1 ]]; then
        REPORT_BUFFER+="$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')\n"
    fi
}

print_result() {
    local service="$1"
    local status="$2"
    local info="$3"
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    local padded
    padded=$(printf "%-34s" "$service")
    case "$status" in
        ok)
            UNLOCKED_COUNT=$((UNLOCKED_COUNT + 1))
            recho " ${GREEN}✓${PLAIN} ${WHITE}${padded}${PLAIN} ${GREEN}${info}${PLAIN}"
            ;;
        no)
            BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
            [[ "$SHOW_ONLY_UNLOCKED" -eq 1 ]] && return
            recho " ${RED}✗${PLAIN} ${DIM}${padded}${PLAIN} ${RED}${info}${PLAIN}"
            ;;
        warn)
            UNLOCKED_COUNT=$((UNLOCKED_COUNT + 1))
            recho " ${YELLOW}~${PLAIN} ${WHITE}${padded}${PLAIN} ${YELLOW}${info}${PLAIN}"
            ;;
        err)
            FAILED_COUNT=$((FAILED_COUNT + 1))
            [[ "$SHOW_ONLY_UNLOCKED" -eq 1 ]] && return
            recho " ${YELLOW}?${PLAIN} ${DIM}${padded}${PLAIN} ${YELLOW}${info}${PLAIN}"
            ;;
    esac
}

section_header() {
    recho ""
    recho " ${BLUE}${BOLD}▶  $1${PLAIN}"
    print_line
}

# ─────────────────────────────────────────────
#  IP 基础信息获取
# ─────────────────────────────────────────────
get_ip_info() {
    echo -ne " ${BLUE}正在获取 IP 基础信息...${PLAIN}\r"
    local ip_info
    ip_info=$(curl $CURL_OPTS -s "https://api.ip.sb/geoip" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)

    LOCAL_IP=$(echo "$ip_info"           | grep -oP '"ip"\s*:\s*"\K[^"]+')
    LOCAL_COUNTRY=$(echo "$ip_info"      | grep -oP '"country"\s*:\s*"\K[^"]+')
    LOCAL_COUNTRY_CODE=$(echo "$ip_info" | grep -oP '"country_code"\s*:\s*"\K[^"]+')
    LOCAL_CITY=$(echo "$ip_info"         | grep -oP '"city"\s*:\s*"\K[^"]+')
    LOCAL_ORG=$(echo "$ip_info"          | grep -oP '"organization"\s*:\s*"\K[^"]+')
    LOCAL_ASN=$(echo "$ip_info"          | grep -oP '"asn"\s*:\s*\K[0-9]+')

    if [[ "$LOCAL_IP" =~ ^[0-9]+\.[0-9]+\. ]]; then
        LOCAL_IP_MASKED=$(echo "$LOCAL_IP" | sed 's/\([0-9]*\.[0-9]*\)\.[0-9]*\.[0-9]*/\1.*.*/')
    elif [[ -n "$LOCAL_IP" ]]; then
        LOCAL_IP_MASKED=$(echo "$LOCAL_IP" | sed 's/\(.*:\).*:\(.*\)/\1*:\2/')
    else
        LOCAL_IP_MASKED="获取失败"
    fi
}

# ─────────────────────────────────────────────
#  IP 类型识别
# ─────────────────────────────────────────────
detect_ip_type() {
    echo -ne " ${BLUE}正在分析 IP 类型...${PLAIN}          \r"

    local ipapi_res
    ipapi_res=$(curl $CURL_OPTS -s \
        "http://ip-api.com/json/${LOCAL_IP}?fields=status,proxy,hosting,mobile,isp,org,as" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)

    # 处理 ip-api.com 限速（免费版 45次/分钟）
    if echo "$ipapi_res" | grep -qi '"message"\s*:\s*"you have exceeded'; then
        echo -e " ${YELLOW}ip-api.com 触发限速，等待 10 秒后重试...${PLAIN}"
        sleep 10
        ipapi_res=$(curl $CURL_OPTS -s \
            "http://ip-api.com/json/${LOCAL_IP}?fields=status,proxy,hosting,mobile,isp,org,as" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    fi

    local is_proxy
    is_proxy=$(echo "$ipapi_res" | grep -oP '"proxy"\s*:\s*\K(true|false)')
    local is_hosting
    is_hosting=$(echo "$ipapi_res" | grep -oP '"hosting"\s*:\s*\K(true|false)')
    local is_mobile
    is_mobile=$(echo "$ipapi_res" | grep -oP '"mobile"\s*:\s*\K(true|false)')
    local isp
    isp=$(echo "$ipapi_res" | grep -oP '"isp"\s*:\s*"\K[^"]+')
    [[ -z "$LOCAL_ORG" ]] && LOCAL_ORG="$isp"

    local ipinfo_res
    ipinfo_res=$(curl $CURL_OPTS -s \
        "https://ipinfo.io/${LOCAL_IP}/json" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local ipinfo_org
    ipinfo_org=$(echo "$ipinfo_res" | grep -oP '"org"\s*:\s*"\K[^"]+')
    local ipinfo_hostname
    ipinfo_hostname=$(echo "$ipinfo_res" | grep -oP '"hostname"\s*:\s*"\K[^"]+')

    local org_lower
    org_lower=$(echo "${LOCAL_ORG}${ipinfo_org}${isp}${ipinfo_hostname}" | tr '[:upper:]' '[:lower:]')

    local dc_kw="amazon|aws|google|microsoft|azure|alibaba|tencent|cloudflare|linode|digitalocean|vultr|hetzner|ovh|choopa|zenlayer|leaseweb|serverius|quadranet|colocrossing|psychz|coresite|navisite|ntt|cogent|lumen|centurylink|hosting|server|cloud|vps|dedicated|datacenter|data center|cdn|coloc|idc"
    local mob_kw="mobile|cellular|t-mobile|verizon wireless|at&t wireless|sprint|china mobile|china unicom|docomo|softbank|kddi|singtel|starhub|telkomsel|airtel|jio|vodafone|orange"
    local vpn_kw="vpn|proxy|tor |nordvpn|expressvpn|surfshark|protonvpn|mullvad| pia |purevpn|cyberghost|ipvanish|windscribe|hideip|privatevpn"

    if [[ "$is_proxy" == "true" ]] || echo "$org_lower" | grep -qiE "$vpn_kw"; then
        IP_TYPE="VPN / 代理"
        IP_TYPE_ICON="🔒"
        IP_IS_PROXY="是"
        IP_RISK_SCORE=$((IP_RISK_SCORE + 40))
    elif [[ "$is_hosting" == "true" ]] || echo "$org_lower" | grep -qiE "$dc_kw"; then
        IP_TYPE="机房 IP (Datacenter/IDC)"
        IP_TYPE_ICON="🏢"
        IP_IS_HOSTING="是"
        IP_RISK_SCORE=$((IP_RISK_SCORE + 20))
    elif [[ "$is_mobile" == "true" ]] || echo "$org_lower" | grep -qiE "$mob_kw"; then
        IP_TYPE="移动网络 IP (Mobile)"
        IP_TYPE_ICON="📱"
        IP_RISK_SCORE=$((IP_RISK_SCORE + 5))
    else
        IP_TYPE="家庭宽带 IP (Residential)"
        IP_TYPE_ICON="🏠"
    fi
}

# ─────────────────────────────────────────────
#  IP 风险评估
# ─────────────────────────────────────────────
assess_ip_risk() {
    echo -ne " ${BLUE}正在进行风险评估...${PLAIN}          \r"

    # AbuseIPDB（不需要 key 也能访问公开页面获取部分信息）
    local abuse_res
    abuse_res=$(curl $CURL_OPTS -s \
        "https://www.abuseipdb.com/check/${LOCAL_IP}" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)

    local abuse_confidence
    abuse_confidence=$(echo "$abuse_res" | grep -oP 'Confidence of Abuse.*?(\d+)%' | grep -oP '\d+' | head -1)
    local abuse_reports
    abuse_reports=$(echo "$abuse_res" | grep -oP 'reported \K[0-9,]+(?= time)' | tr -d ',' | head -1)

    [[ -z "$abuse_confidence" ]] && abuse_confidence=0
    [[ -z "$abuse_reports" ]]    && abuse_reports=0
    IP_ABUSE_SCORE="$abuse_confidence"

    if [[ "$abuse_confidence" -gt 0 ]]; then
        IP_BLACKLIST_STATUS="已被举报 ${abuse_reports} 次 (置信度: ${abuse_confidence}%)"
        IP_RISK_SCORE=$((IP_RISK_SCORE + abuse_confidence / 3))
    else
        IP_BLACKLIST_STATUS="✓ 未在举报数据库中"
    fi

    # Scamalytics（公开页面爬取）
    local scam_res
    scam_res=$(curl $CURL_OPTS -s \
        "https://scamalytics.com/ip/${LOCAL_IP}" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)

    local scam_score
    scam_score=$(echo "$scam_res" | grep -oP '"score"\s*:\s*"\K[0-9]+' | head -1)
    [[ -z "$scam_score" ]] && scam_score=$(echo "$scam_res" | grep -oP 'Fraud Score:\s*\K[0-9]+' | head -1)

    if [[ -n "$scam_score" && "$scam_score" -gt 0 ]]; then
        SCAM_SCORE="$scam_score"
        IP_RISK_SCORE=$((IP_RISK_SCORE + scam_score * 30 / 100))
    fi

    [[ "$IP_RISK_SCORE" -gt 100 ]] && IP_RISK_SCORE=100
    [[ "$IP_RISK_SCORE" -lt 0 ]]   && IP_RISK_SCORE=0
}

# ─────────────────────────────────────────────
#  流媒体友好度计算
# ─────────────────────────────────────────────
calc_stream_score() {
    if [[ $TOTAL_CHECKS -gt 0 ]]; then
        IP_STREAM_SCORE=$(( UNLOCKED_COUNT * 10 / TOTAL_CHECKS ))
    fi
    [[ "$IP_STREAM_SCORE" -gt 10 ]] && IP_STREAM_SCORE=10
}

# ─────────────────────────────────────────────
#  进度条绘制
# ─────────────────────────────────────────────
draw_bar() {
    # 风险条：高分=红色
    local val="${1:-0}"
    local width=20
    local filled=$(( val * width / 100 ))
    local empty=$(( width - filled ))
    local bar=""
    local color
    if   [[ "$val" -le 30 ]]; then color="$GREEN"
    elif [[ "$val" -le 60 ]]; then color="$YELLOW"
    else                           color="$RED"
    fi
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done
    echo -e "${color}${bar}${PLAIN} ${val}/100"
}

draw_score_bar() {
    # 流媒体友好度：高分=绿色
    local val="${1:-0}"
    local width=20
    local filled=$(( val * width / 10 ))
    local empty=$(( width - filled ))
    local bar=""
    local color
    if   [[ "$val" -ge 7 ]]; then color="$GREEN"
    elif [[ "$val" -ge 4 ]]; then color="$YELLOW"
    else                          color="$RED"
    fi
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty;  i++)); do bar+="░"; done
    echo -e "${color}${bar}${PLAIN} ${val}/10"
}

# ─────────────────────────────────────────────
#  延迟测试
# ─────────────────────────────────────────────
latency_test() {
    section_header "网络延迟  Latency Test"

    local targets=(
        "Google:www.google.com"
        "Cloudflare:1.1.1.1"
        "Netflix CDN:nflxvideo.net"
        "YouTube CDN:googlevideo.com"
        "Spotify CDN:scdn.co"
        "OpenAI:api.openai.com"
        "Disney+ CDN:disney-plus.net"
        "Amazon CloudFront:cloudfront.net"
    )

    for item in "${targets[@]}"; do
        local name="${item%%:*}"
        local host="${item#*:}"
        local padded
        padded=$(printf "%-28s" "$name")

        local latency
        latency=$(curl -o /dev/null -s -w "%{time_connect}" \
            $PROXY_OPTS $USE_INTERFACE \
            --connect-timeout 5 --max-time 8 \
            "https://${host}" 2>/dev/null)

        if [[ -z "$latency" || "$latency" == "0.000000" ]]; then
            recho "  ${padded} ${RED}超时 / 不可达${PLAIN}"
            continue
        fi

        local ms
        ms=$(awk "BEGIN{printf \"%.0f\", ${latency}*1000}" 2>/dev/null)
        [[ -z "$ms" || "$ms" == "0" ]] && { recho "  ${padded} ${RED}超时${PLAIN}"; continue; }

        local color
        if   [[ "$ms" -lt 80  ]]; then color="$GREEN"
        elif [[ "$ms" -lt 180 ]]; then color="$YELLOW"
        else                           color="$RED"
        fi
        recho "  ${WHITE}${padded}${PLAIN} ${color}${ms} ms${PLAIN}"
    done
}

# ─────────────────────────────────────────────
#  IPv6 检测
# ─────────────────────────────────────────────
check_ipv6() {
    section_header "IPv6 支持  IPv6 Connectivity"

    local ipv6_addr
    ipv6_addr=$(curl -6 --max-time 8 -s "https://api6.ipify.org" 2>/dev/null)

    if [[ -z "$ipv6_addr" ]]; then
        recho " ${RED}✗${PLAIN} ${DIM}$(printf "%-34s" "IPv6 地址")${PLAIN} ${RED}不支持 / 无 IPv6 出口${PLAIN}"
        return
    fi

    recho " ${GREEN}✓${PLAIN} ${WHITE}$(printf "%-34s" "IPv6 地址")${PLAIN} ${GREEN}${ipv6_addr}${PLAIN}"

    local v6_netflix
    v6_netflix=$(curl -6 --max-time 8 -s \
        -o /dev/null -w "%{http_code}" \
        "https://www.netflix.com/title/70143836" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)

    if [[ "$v6_netflix" == "200" ]]; then
        recho " ${GREEN}✓${PLAIN} ${WHITE}$(printf "%-34s" "Netflix (IPv6)")${PLAIN} ${GREEN}解锁${PLAIN}"
    elif [[ "$v6_netflix" == "403" ]]; then
        recho " ${RED}✗${PLAIN} ${DIM}$(printf "%-34s" "Netflix (IPv6)")${PLAIN} ${RED}已屏蔽${PLAIN}"
    else
        recho " ${YELLOW}?${PLAIN} ${DIM}$(printf "%-34s" "Netflix (IPv6)")${PLAIN} ${YELLOW}未知 (HTTP ${v6_netflix})${PLAIN}"
    fi

    local v6_yt
    v6_yt=$(curl -6 --max-time 8 -s \
        -o /dev/null -w "%{http_code}" \
        "https://www.youtube.com/" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)

    if [[ "$v6_yt" == "200" ]]; then
        recho " ${GREEN}✓${PLAIN} ${WHITE}$(printf "%-34s" "YouTube (IPv6)")${PLAIN} ${GREEN}可访问${PLAIN}"
    else
        recho " ${RED}✗${PLAIN} ${DIM}$(printf "%-34s" "YouTube (IPv6)")${PLAIN} ${RED}不可达 (HTTP ${v6_yt})${PLAIN}"
    fi

    local v6_openai
    v6_openai=$(curl -6 --max-time 8 -s \
        -o /dev/null -w "%{http_code}" \
        "https://chat.openai.com/" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)

    if [[ "$v6_openai" == "200" || "$v6_openai" == "307" ]]; then
        recho " ${GREEN}✓${PLAIN} ${WHITE}$(printf "%-34s" "ChatGPT (IPv6)")${PLAIN} ${GREEN}可访问${PLAIN}"
    else
        recho " ${RED}✗${PLAIN} ${DIM}$(printf "%-34s" "ChatGPT (IPv6)")${PLAIN} ${RED}不可达 (HTTP ${v6_openai})${PLAIN}"
    fi
}

# ─────────────────────────────────────────────
#  历史记录
# ─────────────────────────────────────────────
load_history() {
    [[ -f "$HISTORY_FILE" ]] || return
    HISTORY_UNLOCKED=$(grep "^UNLOCKED=" "$HISTORY_FILE" | cut -d= -f2)
    HISTORY_BLOCKED=$(grep "^BLOCKED=" "$HISTORY_FILE"   | cut -d= -f2)
    HISTORY_TOTAL=$(grep "^TOTAL=" "$HISTORY_FILE"       | cut -d= -f2)
    HISTORY_DATE=$(grep "^DATE=" "$HISTORY_FILE"         | cut -d= -f2)
    HISTORY_IP_MASKED=$(grep "^IP=" "$HISTORY_FILE"      | cut -d= -f2)
}

save_history() {
    cat > "$HISTORY_FILE" <<EOF
DATE=$(date '+%Y-%m-%d %H:%M')
IP=${LOCAL_IP_MASKED}
UNLOCKED=${UNLOCKED_COUNT}
BLOCKED=${BLOCKED_COUNT}
TOTAL=${TOTAL_CHECKS}
EOF
}

show_history_diff() {
    [[ -z "$HISTORY_DATE" ]] && return
    echo ""
    echo -e " ${DIM}上次检测: ${HISTORY_DATE}  (IP: ${HISTORY_IP_MASKED})${PLAIN}"
    local diff=$(( UNLOCKED_COUNT - ${HISTORY_UNLOCKED:-0} ))
    if [[ "$diff" -gt 0 ]]; then
        echo -e " ${GREEN}▲ 比上次多解锁 ${diff} 个服务${PLAIN}"
    elif [[ "$diff" -lt 0 ]]; then
        echo -e " ${RED}▼ 比上次少解锁 ${diff#-} 个服务${PLAIN}"
    else
        echo -e " ${DIM}= 与上次结果相同${PLAIN}"
    fi
}

# ═══════════════════════════════════════════
#  流媒体检测函数
# ═══════════════════════════════════════════

check_netflix() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://www.netflix.com/title/70143836" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Netflix" "err" "网络连接失败"; return; }
    local res_orig
    res_orig=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}" \
        "https://www.netflix.com/title/80057281" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    if [[ "$http_code" == "200" ]]; then
        local region
        region=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            "https://www.netflix.com/title/80018499" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null | \
            grep -oP '"requestCountry"\s*:\s*"\K[^"]+' | head -1)
        [[ -z "$region" ]] && region="$LOCAL_COUNTRY_CODE"
        print_result "Netflix" "ok" "完全解锁 (${region:-已解锁})"
    elif [[ "$http_code" == "403" ]]; then
        print_result "Netflix" "no" "已屏蔽"
    elif echo "$final_url" | grep -qi "not-available\|unavailable" && [[ "$res_orig" == "200" ]]; then
        print_result "Netflix" "warn" "仅自制内容 (Originals Only)"
    elif [[ "$http_code" == "404" && "$res_orig" == "200" ]]; then
        print_result "Netflix" "warn" "仅自制内容 (Originals Only)"
    else
        print_result "Netflix" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_disney_plus() {
    local token_res
    token_res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://disney.api.edge.bamgrid.com/devices" \
        -X POST \
        -H "Content-Type: application/json; charset=UTF-8" \
        -H "User-Agent: ${UA_BROWSER}" \
        -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" \
        -d '{"deviceFamily":"browser","applicationRuntime":"chrome","deviceProfile":"windows","attributes":{}}' \
        2>/dev/null)
    [[ -z "$token_res" ]] && { print_result "Disney+" "err" "网络连接失败"; return; }
    if echo "$token_res" | grep -qi '"assertion"'; then
        local assert
        assert=$(echo "$token_res" | grep -oP '"assertion"\s*:\s*"\K[^"]+')
        local token_res2
        token_res2=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            "https://disney.api.edge.bamgrid.com/token" \
            -X POST \
            -H "User-Agent: ${UA_BROWSER}" \
            -H "authorization: ZGlzbmV5JmJyb3dzZXImMS4wLjA.Cu56AgSfBTDag5NiRA81oLHkDZfu5L3CKadnefEAY84" \
            -d "grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&latitude=0&longitude=0&platform=browser&subject_token=${assert}&subject_token_type=urn%3Abamtech%3Aparams%3Aoauth%3Atoken-type%3Adevice" \
            2>/dev/null)
        if echo "$token_res2" | grep -qi '"forbidden"\|"FORBIDDEN"'; then
            print_result "Disney+" "no" "地区不支持"; return
        fi
        local location
        location=$(echo "$token_res2" | grep -oP '"country_code"\s*:\s*"\K[^"]+' | head -1)
        [[ -z "$location" ]] && location="$LOCAL_COUNTRY_CODE"
        print_result "Disney+" "ok" "解锁 (${location:-已解锁})"
    elif echo "$token_res" | grep -qi 'ip-country-blocked\|GEO_BLOCKED'; then
        print_result "Disney+" "no" "地区已屏蔽"
    else
        local page_code
        page_code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" "https://www.disneyplus.com/" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        [[ "$page_code" == "200" ]] && print_result "Disney+" "warn" "可能可用" || print_result "Disney+" "no" "不可用"
    fi
}

check_youtube_premium() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://www.youtube.com/premium" \
        -H "User-Agent: ${UA_BROWSER}" -H "Accept-Language: en-US,en;q=0.9" 2>/dev/null)
    [[ -z "$res" ]] && { print_result "YouTube Premium" "err" "网络连接失败"; return; }
    if echo "$res" | grep -qi 'NotAvailable\|not available in your country'; then
        print_result "YouTube Premium" "no" "地区不支持"
    elif echo "$res" | grep -qi 'Premium\|youtubepremium'; then
        local region
        region=$(echo "$res" | grep -oP '"locationCountryCode"\s*:\s*"\K[^"]+' | head -1)
        [[ -z "$region" ]] && region="$LOCAL_COUNTRY_CODE"
        print_result "YouTube Premium" "ok" "解锁 (${region:-已解锁})"
    else
        print_result "YouTube Premium" "err" "检测失败"
    fi
}

check_youtube_cdn() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://redirector.googlevideo.com/report_mapping?di=no" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ -z "$res" ]] && { print_result "YouTube CDN 节点" "err" "网络连接失败"; return; }
    local server
    server=$(echo "$res" | grep -oP 'http://[\w.]+\.googlevideo\.com' | head -1 | grep -oP '(?<=http://)[\w]+(?=\.)')
    [[ -n "$server" ]] && print_result "YouTube CDN 节点" "ok" "节点: ${server}" || print_result "YouTube CDN 节点" "warn" "节点未知"
}

check_spotify() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://spclient.wg.spotify.com/signup/public/v1/account" \
        -H "User-Agent: ${UA_BROWSER}" -H "app-platform: WebPlayer" \
        -d "birth_month=1&birth_year=1990&collectioncountry=US&creation_point=client_mobile&gender=male&iagree=1&key=a1e486e2729f46d6bb368d6b2bcea9b0&password=SpotifyPassword0420&password_repeat=SpotifyPassword0420&platform=Android-ARM&referrer&send_email=0&username=testaaajdd6kl" \
        2>/dev/null)
    [[ -z "$res" ]] && { print_result "Spotify" "err" "网络连接失败"; return; }
    local status
    status=$(echo "$res" | grep -oP '"status"\s*:\s*\K[0-9]+')
    case "$status" in
        320)
            local country
            country=$(echo "$res" | grep -oP '"country"\s*:\s*"\K[^"]+')
            print_result "Spotify" "ok" "解锁 (${country:-已解锁})" ;;
        301|303) print_result "Spotify" "no" "地区不支持" ;;
        *)       print_result "Spotify" "err" "检测失败" ;;
    esac
}

check_tiktok() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://www.tiktok.com/" \
        -H "User-Agent: ${UA_BROWSER}" -H "Accept-Language: en-US,en;q=0.9" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "TikTok" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'us-unavailable\|ban\|block\|restricted'; then
        print_result "TikTok" "no" "地区屏蔽"; return
    fi
    if [[ "$http_code" == "200" || "$http_code" == "301" ]]; then
        local res2
        res2=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            "https://www.tiktok.com/api/recommend/item_list/?count=1&id=1&type=5" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        local err_code
        err_code=$(echo "$res2" | grep -oP '"statusCode"\s*:\s*\K[0-9]+' | head -1)
        [[ "$err_code" == "10204" || "$err_code" == "7180" ]] && \
            print_result "TikTok" "no" "地区屏蔽 (API ${err_code})" || \
            print_result "TikTok" "ok" "解锁"
    else
        print_result "TikTok" "no" "不可用 (HTTP ${http_code})"
    fi
}

check_dazn() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://startup.core.indazn.com/misl/v5/Startup" \
        -X POST -H "Content-Type: application/json" -H "User-Agent: ${UA_BROWSER}" \
        -d '{"LandingPageKey":"generic","Languages":"en-US,en","Platform":"web","PlatformAttributes":{},"Manufacturer":"","PromoCode":"","Version":"2"}' \
        2>/dev/null)
    [[ -z "$res" ]] && { print_result "DAZN" "err" "网络连接失败"; return; }
    if echo "$res" | grep -qi '"Region"'; then
        local region allowed
        region=$(echo "$res"  | grep -oP '"Region"\s*:\s*"\K[^"]+' | head -1)
        allowed=$(echo "$res" | grep -oP '"isAllowed"\s*:\s*\K(true|false)' | head -1)
        [[ "$allowed" == "true" ]] && print_result "DAZN" "ok" "解锁 (${region:-已解锁})" || print_result "DAZN" "no" "地区不支持 (${region})"
    else
        print_result "DAZN" "no" "地区不支持"
    fi
}

check_hotstar() {
    local code
    code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}" "https://www.hotstar.com/in/" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    if [[ "$code" == "200" || "$code" == "302" ]]; then
        print_result "HotStar" "ok" "解锁 (IN)"; return
    fi
    for cc in sg my th us; do
        local c
        c=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" "https://www.hotstar.com/${cc}/" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$c" == "200" || "$c" == "301" || "$c" == "302" ]]; then
            print_result "HotStar" "ok" "解锁 (${cc^^})"; return
        fi
    done
    print_result "HotStar" "no" "地区不支持"
}

check_hbo_max() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" "https://www.max.com/" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "HBO Max / Max" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'blocked\|not-available\|geo' || [[ "$http_code" == "403" ]]; then
        print_result "HBO Max / Max" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "301" ]]; then
        local api_res
        api_res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            "https://default.any-any.prd.api.discomax.com/cms/routes/home?page=1&version=v1.1" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if echo "$api_res" | grep -qi '"id"\|"title"'; then
            print_result "HBO Max / Max" "ok" "解锁 (美区)"
        else
            print_result "HBO Max / Max" "warn" "可能可用 (HTTP ${http_code})"
        fi
    else
        print_result "HBO Max / Max" "no" "不可用 (HTTP ${http_code})"
    fi
}

check_hulu() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}" "https://www.hulu.com/welcome" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ -z "$res" || "$res" == "000" ]] && { print_result "Hulu" "err" "网络连接失败"; return; }
    [[ "$res" == "200" ]] && print_result "Hulu" "ok" "解锁 (美区)" && return
    [[ "$res" == "403" ]] && print_result "Hulu" "no" "地区不支持" && return
    print_result "Hulu" "err" "检测失败 (HTTP ${res})"
}

check_amazon_prime() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://www.primevideo.com/region/na/ref=atv_nav_reg" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ -z "$res" ]] && { print_result "Amazon Prime Video" "err" "网络连接失败"; return; }
    local region
    region=$(echo "$res" | grep -oP '"currentTerritory"\s*:\s*"\K[^"]+' | head -1)
    if [[ -n "$region" ]]; then
        print_result "Amazon Prime Video" "ok" "解锁 (${region})"
    elif echo "$res" | grep -qi 'GeoBlocked\|not available in your region'; then
        print_result "Amazon Prime Video" "no" "地区不支持"
    else
        local code
        code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" "https://www.primevideo.com/" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        [[ "$code" == "200" ]] && print_result "Amazon Prime Video" "ok" "解锁" || print_result "Amazon Prime Video" "err" "检测失败"
    fi
}

check_apple_tv() {
    local code
    code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}" "https://tv.apple.com/" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ "$code" == "200" ]] && print_result "Apple TV+" "ok" "解锁" && return
    [[ "$code" == "403" ]] && print_result "Apple TV+" "no" "地区不支持" && return
    print_result "Apple TV+" "err" "检测失败 (HTTP ${code})"
}

check_paramount_plus() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" "https://www.paramountplus.com/" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Paramount+" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'geo\|blocked\|unavailable' || [[ "$http_code" == "403" ]]; then
        print_result "Paramount+" "no" "地区不支持"
    elif [[ "$http_code" == "200" ]]; then
        print_result "Paramount+" "ok" "解锁"
    else
        print_result "Paramount+" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_peacock() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" "https://www.peacocktv.com/" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Peacock TV" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'geo\|blocked' || [[ "$http_code" == "403" ]]; then
        print_result "Peacock TV" "no" "地区不支持 (仅限美国)"
    elif [[ "$http_code" == "200" ]]; then
        print_result "Peacock TV" "ok" "解锁 (美区)"
    else
        print_result "Peacock TV" "no" "不可用 (HTTP ${http_code})"
    fi
}

check_bbc_iplayer() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://open.live.bbc.co.uk/mediaselector/6/select/version/2.0/mediaset/iptv-all/vpid/b0507b57/format/json/jsfunc/JS_callbacks0" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ -z "$res" ]] && { print_result "BBC iPlayer" "err" "网络连接失败"; return; }
    if echo "$res" | grep -qi '"geolocation"'; then
        print_result "BBC iPlayer" "no" "地区不支持 (仅限英国)"
    elif echo "$res" | grep -qi '"connection"\|"media"'; then
        print_result "BBC iPlayer" "ok" "解锁 (英国)"
    else
        print_result "BBC iPlayer" "err" "检测失败"
    fi
}

check_bahamut() {
    local bahamut_ck="/tmp/bahamut_ck_$$.txt"
    local device_res
    device_res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://ani.gamer.com.tw/ajax/getdeviceid.php" \
        -c "$bahamut_ck" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    if [[ -z "$device_res" ]]; then
        rm -f "$bahamut_ck"; print_result "Bahamut Anime (動畫瘋)" "err" "网络连接失败"; return
    fi
    local deviceid
    deviceid=$(echo "$device_res" | grep -oP '"deviceid"\s*:\s*"\K[^"]+')
    if [[ -z "$deviceid" ]]; then
        rm -f "$bahamut_ck"; print_result "Bahamut Anime (動畫瘋)" "err" "获取设备ID失败"; return
    fi
    local token_res
    token_res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://ani.gamer.com.tw/ajax/token.php?adID=89422&sn=37783&device=${deviceid}" \
        -b "$bahamut_ck" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    rm -f "$bahamut_ck"
    if echo "$token_res" | grep -qi '"animeSn"'; then
        print_result "Bahamut Anime (動畫瘋)" "ok" "解锁 (台灣)"
    elif echo "$token_res" | grep -qi 'out of service area\|overseas\|非台灣'; then
        print_result "Bahamut Anime (動畫瘋)" "no" "地区不支持 (仅限台湾)"
    else
        print_result "Bahamut Anime (動畫瘋)" "err" "检测失败"
    fi
}

check_abema() {
    local uuid
    uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "12345678-1234-1234-1234-123456789012")
    local user_token
    user_token=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -X POST "https://api.abema.io/v1/users" \
        -H "Content-Type: application/json" -H "User-Agent: ${UA_ANDROID}" \
        -d "{\"deviceId\":\"${uuid}\",\"applicationKeySecret\":\"hd74014f7\",\"deviceType\":\"android\"}" \
        2>/dev/null | grep -oP '"token"\s*:\s*"\K[^"]+')
    [[ -z "$user_token" ]] && { print_result "AbemaTV" "err" "获取 Token 失败"; return; }
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://api.abema.io/v1/ip/check?device=android" \
        -H "User-Agent: ${UA_ANDROID}" -H "Authorization: Bearer ${user_token}" 2>/dev/null)
    [[ -z "$res" ]] && { print_result "AbemaTV" "err" "网络连接失败"; return; }
    if echo "$res" | grep -qi '"country"\s*:\s*"JP"'; then
        print_result "AbemaTV" "ok" "解锁 (日本)"
    elif echo "$res" | grep -qi '"country"'; then
        local country
        country=$(echo "$res" | grep -oP '"country"\s*:\s*"\K[^"]+')
        print_result "AbemaTV" "no" "地区不支持 (当前: ${country})"
    else
        print_result "AbemaTV" "err" "检测失败"
    fi
}

check_niconico() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}" "https://www.nicovideo.jp/watch/sm9" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ -z "$res" || "$res" == "000" ]] && { print_result "NicoNico" "err" "网络连接失败"; return; }
    [[ "$res" == "200" ]] && print_result "NicoNico" "ok" "解锁 (日本)" && return
    [[ "$res" == "403" ]] && print_result "NicoNico" "no" "地区不支持" && return
    print_result "NicoNico" "err" "检测失败 (HTTP ${res})"
}

check_tvbanywhere() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://www.tvbanywhere.com/api/apps/v2/getInfo" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    if echo "$res" | grep -qi '"isGeoBlocked"\s*:\s*true'; then
        print_result "TVBAnywhere+" "no" "地区不支持"
    elif echo "$res" | grep -qi '"success"\s*:\s*true\|"appId"'; then
        print_result "TVBAnywhere+" "ok" "解锁"
    else
        print_result "TVBAnywhere+" "err" "检测失败"
    fi
}

check_f1tv() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://f1tv.formula1.com/1.0/R/ENG/BIG_SCREEN_HLS/ALL/PAGE/395/F1_TV_Pro_Annual/14" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ -z "$res" ]] && { print_result "F1 TV" "err" "网络连接失败"; return; }
    if echo "$res" | grep -qi '"resultCode"\s*:\s*"GeoBlocked"'; then
        print_result "F1 TV" "no" "地区不支持"
    elif echo "$res" | grep -qi '"resultCode"\s*:\s*"Ok"'; then
        print_result "F1 TV" "ok" "解锁"
    else
        print_result "F1 TV" "err" "检测失败"
    fi
}

check_steam() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://store.steampowered.com/app/761830" \
        -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    [[ -z "$res" ]] && { print_result "Steam 货币区" "err" "网络连接失败"; return; }
    local currency
    currency=$(echo "$res" | grep -oP '"priceCurrency"\s*:\s*"\K[^"]+' | head -1)
    [[ -n "$currency" ]] && print_result "Steam 货币区" "ok" "${currency}" || print_result "Steam 货币区" "err" "检测失败"
}

# ═══════════════════════════════════════════
#  AI 服务检测函数
# ═══════════════════════════════════════════

check_openai() {
    # ChatGPT Web
    local res_chat
    res_chat=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://chat.openai.com/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local code_chat="${res_chat%%:*}"
    local url_chat="${res_chat#*:}"
    local trace_loc trace_colo
    local res_trace
    res_trace=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://chat.openai.com/cdn-cgi/trace" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    trace_loc=$(echo  "$res_trace" | grep -oP '^loc=\K.+')
    trace_colo=$(echo "$res_trace" | grep -oP '^colo=\K.+')

    if echo "$url_chat" | grep -qi 'sorry\|blocked\|unsupported_country' || [[ "$code_chat" == "403" ]]; then
        print_result "ChatGPT (Web)" "no" "地区不支持"
    elif [[ "$code_chat" == "200" || "$code_chat" == "307" ]]; then
        local info="解锁"
        [[ -n "$trace_loc" ]] && info="解锁 (出口: ${trace_loc}${trace_colo:+/${trace_colo}})"
        print_result "ChatGPT (Web)" "ok" "$info"
    elif [[ "$code_chat" == "000" || -z "$code_chat" ]]; then
        print_result "ChatGPT (Web)" "err" "网络连接失败"
    else
        print_result "ChatGPT (Web)" "err" "检测失败 (HTTP ${code_chat})"
    fi

    # OpenAI API
    local res_api
    res_api=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        "https://api.openai.com/v1/models" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    if echo "$res_api" | grep -qi 'unsupported_country\|country_not_supported'; then
        print_result "OpenAI API" "no" "地区不支持"
    elif echo "$res_api" | grep -qi '"data"\s*:\s*\['; then
        print_result "OpenAI API" "ok" "可访问"
    elif echo "$res_api" | grep -qi 'invalid_api_key'; then
        print_result "OpenAI API" "ok" "可访问 (需要 API Key)"
    else
        print_result "OpenAI API" "err" "检测失败"
    fi
}

check_gemini() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://gemini.google.com/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Google Gemini" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'sorry\|geo\|blocked' || [[ "$http_code" == "403" ]]; then
        print_result "Google Gemini" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "302" ]]; then
        print_result "Google Gemini" "ok" "可访问"
    else
        print_result "Google Gemini" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_claude() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://claude.ai/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Claude (Anthropic)" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'blocked\|geo\|unavailable' || [[ "$http_code" == "403" ]]; then
        print_result "Claude (Anthropic)" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "307" ]]; then
        print_result "Claude (Anthropic)" "ok" "可访问"
    else
        print_result "Claude (Anthropic)" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_copilot() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://copilot.microsoft.com/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Microsoft Copilot" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'cn\.bing\|blocked\|sorry' || [[ "$http_code" == "403" ]]; then
        print_result "Microsoft Copilot" "no" "地区不支持 (重定向至国内版)"
        return
    fi
    if [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "302" ]]; then
        local api_code
        api_code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" \
            "https://copilot.microsoft.com/c/api/user" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$api_code" == "200" || "$api_code" == "401" ]]; then
            print_result "Microsoft Copilot" "ok" "可访问"
        elif [[ "$api_code" == "403" ]]; then
            print_result "Microsoft Copilot" "no" "API 拒绝访问"
        else
            print_result "Microsoft Copilot" "warn" "主页可达 (API: ${api_code})"
        fi
    else
        print_result "Microsoft Copilot" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_grok() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://grok.com/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Grok (xAI)" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'blocked\|geo\|unavailable\|sorry' || [[ "$http_code" == "403" ]]; then
        print_result "Grok (xAI)" "no" "地区不支持"; return
    fi
    if [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "302" ]]; then
        local api_res
        api_res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" "https://api.x.ai/v1/models" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$api_res" == "401" ]]; then
            print_result "Grok (xAI)" "ok" "可访问 (API 需认证)"
        elif [[ "$api_res" == "403" ]]; then
            print_result "Grok (xAI)" "no" "API 地区受限"
        else
            print_result "Grok (xAI)" "ok" "可访问"
        fi
    else
        print_result "Grok (xAI)" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_perplexity() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://www.perplexity.ai/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Perplexity AI" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'blocked\|geo\|unavailable' || [[ "$http_code" == "403" ]]; then
        print_result "Perplexity AI" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "307" ]]; then
        print_result "Perplexity AI" "ok" "可访问"
    else
        print_result "Perplexity AI" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_mistral() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://chat.mistral.ai/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Mistral AI" "err" "网络连接失败"; return; }
    if [[ "$http_code" == "403" ]]; then
        print_result "Mistral AI" "no" "地区不支持"; return
    fi
    if [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "302" ]]; then
        local api_code
        api_code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" "https://api.mistral.ai/v1/models" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$api_code" == "401" || "$api_code" == "200" ]]; then
            print_result "Mistral AI" "ok" "可访问 (API 需认证)"
        else
            print_result "Mistral AI" "ok" "主页可访问"
        fi
    else
        print_result "Mistral AI" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_character_ai() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://character.ai/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Character.AI" "err" "网络连接失败"; return; }
    if [[ "$http_code" == "403" ]]; then
        print_result "Character.AI" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "307" ]]; then
        local neo_code
        neo_code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" "https://neo.character.ai/turns/" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$neo_code" == "400" || "$neo_code" == "401" || "$neo_code" == "405" ]]; then
            print_result "Character.AI" "ok" "可访问"
        elif [[ "$neo_code" == "403" ]]; then
            print_result "Character.AI" "warn" "主页可达 (API 受限)"
        else
            print_result "Character.AI" "ok" "可访问"
        fi
    else
        print_result "Character.AI" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_poe() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://poe.com/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Poe (Quora)" "err" "网络连接失败"; return; }
    if [[ "$http_code" == "403" ]]; then
        print_result "Poe (Quora)" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "307" || "$http_code" == "302" ]]; then
        local api_code
        api_code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" "https://poe.com/api/settings" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$api_code" == "200" || "$api_code" == "401" || "$api_code" == "405" ]]; then
            print_result "Poe (Quora)" "ok" "可访问"
        else
            print_result "Poe (Quora)" "warn" "主页可达 (API: ${api_code})"
        fi
    else
        print_result "Poe (Quora)" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_sora() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://sora.com/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "OpenAI Sora" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'blocked\|geo\|not-supported\|sorry' || [[ "$http_code" == "403" ]]; then
        print_result "OpenAI Sora" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "307" ]]; then
        print_result "OpenAI Sora" "ok" "可访问 (需要 ChatGPT Plus)"
    else
        print_result "OpenAI Sora" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_deepseek() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://chat.deepseek.com/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "DeepSeek" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'blocked\|geo\|unavailable' || [[ "$http_code" == "403" ]]; then
        print_result "DeepSeek" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "302" ]]; then
        # 进一步验证 API 可达性
        local api_code
        api_code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" \
            "https://api.deepseek.com/v1/models" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$api_code" == "401" || "$api_code" == "200" ]]; then
            print_result "DeepSeek" "ok" "可访问 (API 需认证)"
        else
            print_result "DeepSeek" "ok" "主页可访问"
        fi
    else
        print_result "DeepSeek" "err" "检测失败 (HTTP ${http_code})"
    fi
}

check_kimi() {
    local res
    res=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
        -o /dev/null -w "%{http_code}:%{url_effective}" \
        "https://kimi.moonshot.cn/" -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
    local http_code="${res%%:*}"
    local final_url="${res#*:}"
    [[ -z "$http_code" || "$http_code" == "000" ]] && { print_result "Kimi (月之暗面)" "err" "网络连接失败"; return; }
    if echo "$final_url" | grep -qi 'blocked\|geo\|unavailable' || [[ "$http_code" == "403" ]]; then
        print_result "Kimi (月之暗面)" "no" "地区不支持"
    elif [[ "$http_code" == "200" || "$http_code" == "301" || "$http_code" == "302" ]]; then
        local api_code
        api_code=$(curl $CURL_OPTS $PROXY_OPTS $USE_INTERFACE \
            -o /dev/null -w "%{http_code}" \
            "https://api.moonshot.cn/v1/models" \
            -H "User-Agent: ${UA_BROWSER}" 2>/dev/null)
        if [[ "$api_code" == "401" || "$api_code" == "200" ]]; then
            print_result "Kimi (月之暗面)" "ok" "可访问 (API 需认证)"
        else
            print_result "Kimi (月之暗面)" "ok" "主页可访问"
        fi
    else
        print_result "Kimi (月之暗面)" "err" "检测失败 (HTTP ${http_code})"
    fi
}

# ─────────────────────────────────────────────
#  分组运行
# ─────────────────────────────────────────────
run_global_streaming() {
    section_header "全球流媒体  Global Streaming"
    check_netflix
    check_disney_plus
    check_amazon_prime
    check_apple_tv
    check_hbo_max
    check_hulu
    check_paramount_plus
    check_peacock
}

run_asia_pacific() {
    section_header "亚太流媒体  Asia Pacific"
    check_hotstar
    check_bahamut
    check_abema
    check_niconico
    check_tvbanywhere
}

run_music_video() {
    section_header "音乐 & 短视频  Music & Short Video"
    check_spotify
    check_youtube_premium
    check_youtube_cdn
    check_tiktok
}

run_ai_services() {
    section_header "AI 服务  AI Services"
    check_openai
    check_gemini
    check_claude
    check_copilot
    check_grok
    check_perplexity
    check_mistral
    check_character_ai
    check_poe
    check_sora
    check_deepseek
    check_kimi
}

run_sports_uk() {
    section_header "体育 & 英国  Sports & UK"
    check_dazn
    check_f1tv
    check_bbc_iplayer
}

run_tools() {
    section_header "工具类  Utilities"
    check_steam
}

# ═══════════════════════════════════════════
#  系统信息
# ═══════════════════════════════════════════
get_system_info() {
    # OS
    if [[ -f /etc/os-release ]]; then
        SYS_OS=$(grep -oP '(?<=PRETTY_NAME=")[^"]+' /etc/os-release)
    elif [[ -f /etc/redhat-release ]]; then
        SYS_OS=$(cat /etc/redhat-release)
    else
        SYS_OS=$(uname -s)
    fi
    SYS_KERNEL=$(uname -r)
    SYS_ARCH=$(uname -m)

    # CPU
    SYS_CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ //')
    SYS_CPU_CORES=$(nproc 2>/dev/null || grep -c 'processor' /proc/cpuinfo)
    SYS_CPU_FREQ=$(grep -m1 'cpu MHz' /proc/cpuinfo | awk '{printf "%.0f MHz", $4}')
    # 尝试获取实际频率
    local cpu_max
    cpu_max=$(cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq 2>/dev/null)
    [[ -n "$cpu_max" ]] && SYS_CPU_FREQ=$(awk "BEGIN{printf \"%.0f MHz\", ${cpu_max}/1000}")

    # RAM
    local mem_total mem_used mem_free mem_avail
    mem_total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
    mem_avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
    mem_used=$((mem_total - mem_avail))
    SYS_RAM_TOTAL=$(awk "BEGIN{printf \"%.1f GB\", ${mem_total}/1024/1024}")
    SYS_RAM_USED=$(awk "BEGIN{printf \"%.1f GB\", ${mem_used}/1024/1024}")

    # Swap
    local swap_total swap_free
    swap_total=$(awk '/SwapTotal/{print $2}' /proc/meminfo)
    swap_free=$(awk '/SwapFree/{print $2}' /proc/meminfo)
    local swap_used=$((swap_total - swap_free))
    if [[ "$swap_total" -gt 0 ]]; then
        SYS_SWAP=$(awk "BEGIN{printf \"%.1f / %.1f GB\", ${swap_used}/1024/1024, ${swap_total}/1024/1024}")
    else
        SYS_SWAP="未启用"
    fi

    # 磁盘
    SYS_DISK=$(df -h / | tail -1 | awk '{print $3 " / " $2 " (" $5 " used)"}')

    # 负载
    SYS_LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

    # 运行时间
    local uptime_sec
    uptime_sec=$(awk '{print int($1)}' /proc/uptime)
    local up_d=$((uptime_sec/86400))
    local up_h=$(((uptime_sec%86400)/3600))
    local up_m=$(((uptime_sec%3600)/60))
    SYS_UPTIME="${up_d}天 ${up_h}时 ${up_m}分"

    # 虚拟化类型
    SYS_VIRT="物理机 / 未知"
    if [[ -f /proc/1/cgroup ]] && grep -qa docker /proc/1/cgroup 2>/dev/null; then
        SYS_VIRT="Docker"
    elif [[ -f /proc/1/cgroup ]] && grep -qa lxc /proc/1/cgroup 2>/dev/null; then
        SYS_VIRT="LXC"
    elif [[ -f /proc/user_beancounters ]]; then
        SYS_VIRT="OpenVZ"
    elif grep -qa "QEMU\|KVM\|kvm-clock" /proc/cpuinfo 2>/dev/null || \
         grep -qa "kvm\|QEMU" /sys/class/dmi/id/product_name 2>/dev/null; then
        SYS_VIRT="KVM"
    elif grep -qa "VMware" /sys/class/dmi/id/product_name 2>/dev/null; then
        SYS_VIRT="VMware"
    elif grep -qa "Microsoft Corporation" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
        SYS_VIRT="Hyper-V"
    elif [[ -d /proc/xen ]]; then
        SYS_VIRT="Xen"
    elif command_exists systemd-detect-virt; then
        local sv
        sv=$(systemd-detect-virt 2>/dev/null)
        [[ "$sv" != "none" && -n "$sv" ]] && SYS_VIRT="$sv"
    fi

    # TCP 拥塞控制
    SYS_TCP_CC=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "未知")
    SYS_TCP_QDISC=$(sysctl -n net.core.default_qdisc 2>/dev/null || echo "未知")
}

show_system_info() {
    get_system_info
    section_header "系统信息  System Information"
    echo ""
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "操作系统:"       "$SYS_OS"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "内核版本:"       "$SYS_KERNEL"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "系统架构:"       "$SYS_ARCH"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "虚拟化:"         "$SYS_VIRT"
    echo ""
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "CPU 型号:"       "$SYS_CPU_MODEL"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s  @  %s${PLAIN}\n" "CPU 核心数:" "$SYS_CPU_CORES 核" "$SYS_CPU_FREQ"
    echo ""
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s / %s${PLAIN}\n" "内存 (已用/总):" "$SYS_RAM_USED" "$SYS_RAM_TOTAL"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "交换空间:"       "$SYS_SWAP"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "根磁盘:"         "$SYS_DISK"
    echo ""
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "系统运行时间:"   "$SYS_UPTIME"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n"  "系统负载:"       "$SYS_LOAD"
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s / %s${PLAIN}\n" "TCP 优化:" "$SYS_TCP_CC" "$SYS_TCP_QDISC"
    echo ""
}

# ═══════════════════════════════════════════
#  磁盘 I/O 测试
# ═══════════════════════════════════════════
disk_io_test() {
    section_header "磁盘 I/O 测试  Disk I/O Test"
    echo ""

    local test_dir="/tmp"
    local test_file="${test_dir}/.io_test_$$"

    # 检测磁盘类型
    local disk_type="未知"
    local root_dev
    root_dev=$(df / | tail -1 | awk '{print $1}' | sed 's/[0-9]*$//' | sed 's|/dev/||')
    if [[ -f "/sys/block/${root_dev}/queue/rotational" ]]; then
        local rot
        rot=$(cat "/sys/block/${root_dev}/queue/rotational")
        [[ "$rot" == "0" ]] && disk_type="SSD / NVMe" || disk_type="HDD (机械)"
    fi
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n" "磁盘类型:" "$disk_type"
    echo ""

    # dd 写测试（三次取平均）
    echo -e "  ${BLUE}正在执行写入测试...${PLAIN}"
    local write1 write2 write3
    write1=$(LANG=C dd if=/dev/zero of="${test_file}_1" bs=512K count=256 conv=fdatasync 2>&1 | awk -F, '{io=$NF} END{print io}' | sed 's/^ *//')
    write2=$(LANG=C dd if=/dev/zero of="${test_file}_2" bs=512K count=256 conv=fdatasync 2>&1 | awk -F, '{io=$NF} END{print io}' | sed 's/^ *//')
    write3=$(LANG=C dd if=/dev/zero of="${test_file}_3" bs=512K count=256 conv=fdatasync 2>&1 | awk -F, '{io=$NF} END{print io}' | sed 's/^ *//')

    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s  %s  %s${PLAIN}\n" "顺序写入 (3次):" "$write1" "$write2" "$write3"

    # 清缓存后读测试
    echo -e "  ${BLUE}正在执行读取测试...${PLAIN}"
    sync
    echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true
    local read1
    read1=$(LANG=C dd if="${test_file}_1" of=/dev/null bs=512K 2>&1 | awk -F, '{io=$NF} END{print io}' | sed 's/^ *//')

    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n" "顺序读取:" "$read1"

    # 4K 随机写（模拟）
    echo -e "  ${BLUE}正在执行 4K 随机写测试...${PLAIN}"
    local rand_write
    rand_write=$(LANG=C dd if=/dev/urandom of="${test_file}_r" bs=4K count=4096 conv=fdatasync 2>&1 | awk -F, '{io=$NF} END{print io}' | sed 's/^ *//')
    printf "  ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n" "4K 随机写入:" "$rand_write"

    rm -f "${test_file}_1" "${test_file}_2" "${test_file}_3" "${test_file}_r" 2>/dev/null
    echo ""
}

# ═══════════════════════════════════════════
#  Speedtest-cli 安装
# ═══════════════════════════════════════════
install_speedtest() {
    mkdir -p "$BENCH_WORKDIR"
    SPEEDTEST_BIN="${BENCH_WORKDIR}/speedtest"

    if [[ -x "$SPEEDTEST_BIN" ]]; then
        return 0
    fi

    echo -e " ${BLUE}正在安装 speedtest-cli...${PLAIN}"

    local arch
    arch=$(uname -m)
    local tgz_name="ookla-speedtest-1.2.0-linux-${arch}.tgz"
    local download_url="https://install.speedtest.net/app/cli/${tgz_name}"

    # 备用镜像（优先国内可用地址）
    local mirrors=(
        "https://install.speedtest.net/app/cli/${tgz_name}"
        "https://dl.lamp.sh/speedtest/${tgz_name}"
        "https://gh.api.99988866.xyz/https://github.com/nicholasgkong/nicholasgkong.github.io/releases/download/speedtest/ookla-speedtest-1.2.0-linux-${arch}.tgz"
    )

    local downloaded=0
    for url in "${mirrors[@]}"; do
        if curl -sL --connect-timeout 15 --max-time 60 -o "${BENCH_WORKDIR}/speedtest.tgz" "$url" 2>/dev/null; then
            if tar -tzf "${BENCH_WORKDIR}/speedtest.tgz" >/dev/null 2>&1; then
                downloaded=1
                break
            fi
        fi
    done

    if [[ "$downloaded" -eq 0 ]]; then
        echo -e " ${RED}speedtest-cli 下载失败，跳过测速${PLAIN}"
        return 1
    fi

    tar -zxf "${BENCH_WORKDIR}/speedtest.tgz" -C "$BENCH_WORKDIR" >/dev/null 2>&1
    chmod +x "$SPEEDTEST_BIN"
    rm -f "${BENCH_WORKDIR}/speedtest.tgz"
    echo -e " ${GREEN}speedtest-cli 安装完成${PLAIN}"
    return 0
}

# 单节点测速并格式化输出
run_speed_node() {
    local node_id="$1"
    local node_name="$2"
    local isp_color="$3"    # 颜色代码

    true > "$SPEEDTEST_LOG"

    if [[ -z "$node_id" ]]; then
        "$SPEEDTEST_BIN" -p no --accept-license --accept-gdpr > "$SPEEDTEST_LOG" 2>&1
    else
        "$SPEEDTEST_BIN" -p no -s "$node_id" --accept-license --accept-gdpr > "$SPEEDTEST_LOG" 2>&1
    fi

    local upload download latency
    upload=$(awk '/Upload/{print $3}' "$SPEEDTEST_LOG")
    download=$(awk '/Download/{print $3}' "$SPEEDTEST_LOG")
    latency=$(awk '/Latency/{print $2}' "$SPEEDTEST_LOG")
    local result_url
    result_url=$(awk '/Result/{print $3}' "$SPEEDTEST_LOG")

    if [[ -z "$upload" || -z "$download" ]]; then
        printf "  ${DIM}%-30s${PLAIN} ${RED}%-16s${PLAIN} ${RED}%-16s${PLAIN} ${RED}%s${PLAIN}\n" \
            "$node_name" "ERROR" "ERROR" "—"
        return
    fi

    # 延迟染色
    local lat_color="$GREEN"
    local lat_int
    lat_int=$(echo "$latency" | grep -oP '^\d+' 2>/dev/null || echo 999)
    [[ "$lat_int" -gt 100 ]] && lat_color="$YELLOW"
    [[ "$lat_int" -gt 200 ]] && lat_color="$RED"

    printf "  ${isp_color}%-30s${PLAIN} ${GREEN}↑ %-14s${PLAIN} ${BLUE}↓ %-14s${PLAIN} ${lat_color}%-8s ms${PLAIN}\n" \
        "$node_name" "${upload} Mbps" "${download} Mbps" "$latency"
}

# ═══════════════════════════════════════════
#  三网测速
# ═══════════════════════════════════════════
china_speed_test() {
    section_header "三网测速  China Triband Speed Test"

    if ! install_speedtest; then
        recho " ${RED}speedtest-cli 不可用，无法执行测速${PLAIN}"
        return 1
    fi

    echo ""
    echo -e "  ${BOLD}${WHITE}$(printf '%-30s' '节点')  $(printf '%-16s' '上传')  $(printf '%-16s' '下载')  延迟${PLAIN}"
    print_thin_line

    # ── 国际基准 ──
    echo -e "\n  ${PURPLE}▸ 国际基准${PLAIN}"
    run_speed_node '' 'Speedtest.net (最近节点)' "$WHITE"

    # ── 电信 CT ──
    echo -e "\n  ${RED}▸ 中国电信 China Telecom${PLAIN}"
    run_speed_node '27377' '北京 5G        电信' "$RED"
    run_speed_node '5396'  '江苏苏州 5G    电信' "$RED"
    run_speed_node '17145' '安徽合肥 5G    电信' "$RED"
    run_speed_node '27594' '广东广州 5G    电信' "$RED"
    run_speed_node '23844' '湖北武汉       电信' "$RED"
    run_speed_node '29026' '四川成都       电信' "$RED"
    run_speed_node '3633'  '上海           电信' "$RED"
    run_speed_node '28225' '湖南长沙 5G    电信' "$RED"
    run_speed_node '27575' '新疆乌鲁木齐   电信' "$RED"

    # ── 联通 CU ──
    echo -e "\n  ${YELLOW}▸ 中国联通 China Unicom${PLAIN}"
    run_speed_node '24447' '上海 5G        联通' "$YELLOW"
    run_speed_node '5145'  '北京           联通' "$YELLOW"
    run_speed_node '26180' '山东济南 5G    联通' "$YELLOW"
    run_speed_node '26678' '广东广州 5G    联通' "$YELLOW"
    run_speed_node '27154' '天津 5G        联通' "$YELLOW"
    run_speed_node '13704' '江苏南京       联通' "$YELLOW"
    run_speed_node '5485'  '湖北武汉       联通' "$YELLOW"
    run_speed_node '2461'  '四川成都       联通' "$YELLOW"
    run_speed_node '4863'  '陕西西安       联通' "$YELLOW"

    # ── 移动 CM ──
    echo -e "\n  ${GREEN}▸ 中国移动 China Mobile${PLAIN}"
    run_speed_node '25858' '北京           移动' "$GREEN"
    run_speed_node '30232' '内蒙呼和浩特 5G 移动' "$GREEN"
    run_speed_node '17184' '天津 5G        移动' "$GREEN"
    run_speed_node '27151' '山东临沂 5G    移动' "$GREEN"
    run_speed_node '31520' '广东中山       移动' "$GREEN"
    run_speed_node '25883' '江西南昌 5G    移动' "$GREEN"
    run_speed_node '16171' '福建福州       移动' "$GREEN"
    run_speed_node '26938' '新疆乌鲁木齐 5G 移动' "$GREEN"
    run_speed_node '25728' '辽宁大连       移动' "$GREEN"
    run_speed_node '16398' '贵州贵阳       移动' "$GREEN"
    run_speed_node '16375' '吉林长春       移动' "$GREEN"

    rm -f "$SPEEDTEST_LOG"
    echo ""
}

# 快速三网（每运营商只测2个节点）
china_speed_test_fast() {
    section_header "三网快速测速  Quick Triband Speed Test"

    if ! install_speedtest; then
        recho " ${RED}speedtest-cli 不可用，无法执行测速${PLAIN}"
        return 1
    fi

    echo ""
    echo -e "  ${BOLD}${WHITE}$(printf '%-30s' '节点')  $(printf '%-16s' '上传')  $(printf '%-16s' '下载')  延迟${PLAIN}"
    print_thin_line
    echo ""

    run_speed_node '' 'Speedtest.net (最近节点)' "$WHITE"
    echo ""
    run_speed_node '27377' '北京 5G        电信' "$RED"
    run_speed_node '27594' '广东广州 5G    电信' "$RED"
    echo ""
    run_speed_node '24447' '上海 5G        联通' "$YELLOW"
    run_speed_node '26678' '广东广州 5G    联通' "$YELLOW"
    echo ""
    run_speed_node '25858' '北京           移动' "$GREEN"
    run_speed_node '31520' '广东中山       移动' "$GREEN"

    rm -f "$SPEEDTEST_LOG"
    echo ""
}

# ═══════════════════════════════════════════
#  UnixBench CPU 跑分
# ═══════════════════════════════════════════
run_unixbench() {
    section_header "UnixBench CPU 性能跑分  UnixBench Benchmark"
    echo ""
    echo -e " ${YELLOW}⚠  UnixBench 需要编译并运行多项测试，耗时约 10-30 分钟。${PLAIN}"
    echo -e " ${YELLOW}   运行期间 CPU 将满载，请确认服务器资源充足。${PLAIN}"
    echo ""
    read -rp " 确认开始跑分? [y/N]: " confirm
    [[ ! "$confirm" =~ ^[Yy]$ ]] && echo -e " ${DIM}已取消${PLAIN}" && return

    mkdir -p "$BENCH_WORKDIR"
    local ub_dir="${BENCH_WORKDIR}/unixbench"
    mkdir -p "$ub_dir"

    # 安装依赖
    echo -e " ${BLUE}正在安装编译依赖...${PLAIN}"
    if command_exists apt-get; then
        apt-get install -y -q make automake gcc autoconf time perl 2>/dev/null
    elif command_exists yum; then
        yum install -y -q make automake gcc autoconf gcc-c++ time perl-Time-HiRes 2>/dev/null
    elif command_exists dnf; then
        dnf install -y -q make automake gcc autoconf gcc-c++ time perl 2>/dev/null
    fi

    # 下载 UnixBench
    local ub_tgz="${ub_dir}/UnixBench5.1.3.tgz"
    if [[ ! -f "$ub_tgz" ]]; then
        echo -e " ${BLUE}正在下载 UnixBench 5.1.3...${PLAIN}"
        local ub_urls=(
            "https://dl.lamp.sh/files/UnixBench5.1.3.tgz"
            "https://github.com/nicholasgkong/nicholasgkong.github.io/releases/download/unixbench/UnixBench5.1.3.tgz"
        )
        local got=0
        for url in "${ub_urls[@]}"; do
            if curl -sL --connect-timeout 20 --max-time 120 -o "$ub_tgz" "$url" 2>/dev/null; then
                tar -tzf "$ub_tgz" >/dev/null 2>&1 && got=1 && break
            fi
        done
        if [[ "$got" -eq 0 ]]; then
            echo -e " ${RED}UnixBench 下载失败，请检查网络${PLAIN}"
            return 1
        fi
    fi

    echo -e " ${BLUE}正在解压并编译...${PLAIN}"
    tar -zxf "$ub_tgz" -C "$ub_dir" >/dev/null 2>&1
    local ub_src="${ub_dir}/UnixBench"
    [[ ! -d "$ub_src" ]] && echo -e " ${RED}解压失败${PLAIN}" && return 1

    cd "$ub_src" || return 1

    # 编译
    make -s 2>/dev/null
    if [[ ! -x "./Run" ]]; then
        echo -e " ${RED}编译失败，请检查依赖${PLAIN}"
        cd - >/dev/null
        return 1
    fi

    echo ""
    echo -e " ${GREEN}开始运行 UnixBench...${PLAIN}"
    echo -e " ${DIM}(结果将实时显示，请耐心等待)${PLAIN}"
    print_line
    echo ""

    # 运行并实时输出
    ./Run 2>&1 | tee /tmp/.unixbench_result.log

    echo ""
    print_line
    echo -e " ${GREEN}✓ UnixBench 跑分完成！结果已保存至: /tmp/.unixbench_result.log${PLAIN}"

    # 提取最终得分
    local final_score
    final_score=$(grep -oP 'System Benchmarks Index Score\s+\K[\d.]+' /tmp/.unixbench_result.log | tail -1)
    if [[ -n "$final_score" ]]; then
        echo ""
        echo -e " ${BOLD}${GREEN}综合得分: ${final_score}${PLAIN}"
        echo -e " ${DIM}参考: 普通 VPS ~500-1500  高性能服务器 ~3000+${PLAIN}"
    fi

    cd - >/dev/null
    echo ""
}

# ═══════════════════════════════════════════
#  综合服务器基准测试（系统信息 + 磁盘 + 快速测速）
# ═══════════════════════════════════════════
run_bench_full() {
    show_system_info
    disk_io_test
    china_speed_test_fast
}

# ═══════════════════════════════════════════
#  回程路由检测  China Route Test
# ═══════════════════════════════════════════

# 判断是否为私有/保留 IP
is_private_ip() {
    local ip="$1"
    [[ -z "$ip" ]] && return 0
    echo "$ip" | grep -qE \
        '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|0\.0\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|169\.254\.|::1|fe80:|fc[0-9a-f]{2}:|fd)'
}

# 国家代码 → 可读标签（含简单地区旗帜文字）
country_label() {
    local cc="${1^^}"
    case "$cc" in
        CN) echo "🇨🇳 中国" ;;
        HK) echo "🇭🇰 香港" ;;
        TW) echo "🇹🇼 台湾" ;;
        MO) echo "🇲🇴 澳门" ;;
        JP) echo "🇯🇵 日本" ;;
        SG) echo "🇸🇬 新加坡" ;;
        US) echo "🇺🇸 美国" ;;
        GB) echo "🇬🇧 英国" ;;
        DE) echo "🇩🇪 德国" ;;
        FR) echo "🇫🇷 法国" ;;
        NL) echo "🇳🇱 荷兰" ;;
        RU) echo "🇷🇺 俄罗斯" ;;
        KR) echo "🇰🇷 韩国" ;;
        AU) echo "🇦🇺 澳大利亚" ;;
        CA) echo "🇨🇦 加拿大" ;;
        IN) echo "🇮🇳 印度" ;;
        BR) echo "🇧🇷 巴西" ;;
        "??"|"") echo "❓ 未知" ;;
        *) echo "🌐 ${cc}" ;;
    esac
}

# 单跳 IP 地理位置查询（ip-api.com，免费无需 key）
geoip_hop() {
    local ip="$1"
    local res
    res=$(curl -s --connect-timeout 3 --max-time 5 \
        "http://ip-api.com/json/${ip}?fields=status,countryCode,country,city,isp" \
        2>/dev/null)

    if echo "$res" | grep -q '"status":"success"'; then
        local cc country city isp
        cc=$(echo      "$res" | grep -oP '"countryCode"\s*:\s*"\K[^"]+')
        country=$(echo "$res" | grep -oP '"country"\s*:\s*"\K[^"]+')
        city=$(echo    "$res" | grep -oP '"city"\s*:\s*"\K[^"]+')
        isp=$(echo     "$res" | grep -oP '"isp"\s*:\s*"\K[^"]+')
        echo "${cc}|${country}|${city}|${isp}"
    else
        echo "??|Unknown||"
    fi
}

# 检查 traceroute 工具是否可用，尝试自动安装
ensure_traceroute() {
    if command_exists traceroute; then
        TRACE_CMD="traceroute"
        return 0
    fi
    if command_exists tracepath; then
        TRACE_CMD="tracepath"
        return 0
    fi

    echo -e " ${BLUE}正在安装 traceroute...${PLAIN}"
    if command_exists apt-get; then
        apt-get install -y -q traceroute 2>/dev/null
    elif command_exists yum; then
        yum install -y -q traceroute 2>/dev/null
    elif command_exists dnf; then
        dnf install -y -q traceroute 2>/dev/null
    fi

    if command_exists traceroute; then
        TRACE_CMD="traceroute"
        return 0
    fi
    TRACE_CMD=""
    return 1
}

# 对单个目标执行 traceroute，输出逐跳结果 + 路由质量摘要
# 参数: $1=目标IP  $2=显示名称  $3=ISP代码(CT/CU/CM/EDU/CBN)  $4=颜色变量名
trace_one_target() {
    local target_ip="$1"
    local target_name="$2"
    local isp_code="$3"
    local isp_color_var="$4"

    echo ""
    echo -e " ${!isp_color_var}${BOLD}▸ ${target_name}  (${target_ip})${PLAIN}"
    printf "  %-5s %-18s %-10s %-30s %s\n" "跳数" "IP 地址" "延迟" "归属地" "运营商"
    print_thin_line

    local trace_out
    if [[ "$TRACE_CMD" == "traceroute" ]]; then
        trace_out=$(traceroute -n -m 20 -q 1 -w 3 "$target_ip" 2>/dev/null)
    elif [[ "$TRACE_CMD" == "tracepath" ]]; then
        trace_out=$(tracepath -n -m 20 "$target_ip" 2>/dev/null)
    else
        echo -e "  ${RED}traceroute 工具不可用${PLAIN}"
        return 1
    fi

    [[ -z "$trace_out" ]] && { echo -e "  ${RED}执行失败或目标不可达${PLAIN}"; return 1; }

    local path_countries=()
    local path_labels=()
    local path_asns=()
    local prev_cc=""
    local reached_china=0
    local detour_flags=()
    local last_foreign_cc=""
    local entry_point=""

    while IFS= read -r line; do
        local hop_num
        hop_num=$(echo "$line" | grep -oP '^\s*\K[0-9]+' | head -1)
        [[ -z "$hop_num" ]] && continue

        local hop_ip
        hop_ip=$(echo "$line" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | grep -v '^0\.' | head -1)

        local hop_lat
        hop_lat=$(echo "$line" | grep -oP '[0-9]+\.[0-9]+\s*ms' | head -1)
        [[ -z "$hop_lat" ]] && hop_lat=$(echo "$line" | grep -oP '[0-9]+\s*ms' | head -1)

        # 无响应跳
        if [[ -z "$hop_ip" ]] || echo "$line" | grep -q '\* \* \*\|\*$'; then
            printf "  ${DIM}%-5s %-18s %-10s %-30s %s${PLAIN}\n" \
                "${hop_num}" "*" "*" "无响应" ""
            continue
        fi

        # 私有地址
        if is_private_ip "$hop_ip"; then
            printf "  %-5s ${DIM}%-18s${PLAIN} ${GREEN}%-10s${PLAIN} ${DIM}%-30s %s${PLAIN}\n" \
                "${hop_num}" "$hop_ip" "${hop_lat:-—}" "[内网/私有地址]" ""
            continue
        fi

        # 地理信息查询
        local geo
        geo=$(geoip_hop "$hop_ip")
        local cc="${geo%%|*}"
        local rest="${geo#*|}"
        local country="${rest%%|*}"
        rest="${rest#*|}"
        local city="${rest%%|*}"
        local isp_name="${rest#*|}"

        # 从 ip-api 获取 ASN
        local hop_asn
        hop_asn=$(curl -s --connect-timeout 2 --max-time 3 \
            "http://ip-api.com/json/${hop_ip}?fields=as" 2>/dev/null | \
            grep -oP '"as"\s*:\s*"AS\K[0-9]+')
        [[ -n "$hop_asn" ]] && path_asns+=("$hop_asn")

        local location_str
        location_str=$(country_label "$cc")
        [[ -n "$city" ]] && location_str="${location_str} ${city}"

        # 延迟染色
        local lat_color="$GREEN"
        local lat_ms
        lat_ms=$(echo "$hop_lat" | grep -oP '^[0-9]+' | head -1)
        [[ -n "$lat_ms" && "$lat_ms" -gt 150 ]] && lat_color="$YELLOW"
        [[ -n "$lat_ms" && "$lat_ms" -gt 300 ]] && lat_color="$RED"

        # 绕路检测
        local detour_mark=""
        if [[ "$cc" != "CN" && "$cc" != "HK" && "$cc" != "TW" && "$cc" != "MO" && "$reached_china" -eq 0 ]]; then
            last_foreign_cc="$cc"
            local asia_src="SG JP KR HK TW ID MY TH PH VN"
            if echo "$asia_src" | grep -qw "$LOCAL_COUNTRY_CODE"; then
                if echo "US CA" | grep -qw "$cc"; then
                    detour_mark="  ${RED}◄ 绕路美国！${PLAIN}"
                    # 只记录一次
                    echo "${detour_flags[@]}" | grep -qw "美国" || detour_flags+=("美国")
                elif echo "GB DE FR NL SE IT ES PL CH" | grep -qw "$cc"; then
                    detour_mark="  ${RED}◄ 绕路欧洲！${PLAIN}"
                    echo "${detour_flags[@]}" | grep -qw "欧洲" || detour_flags+=("欧洲·${country}")
                fi
            fi
        fi

        # 记录入境点
        if [[ ( "$cc" == "CN" || "$cc" == "HK" || "$cc" == "TW" || "$cc" == "MO" ) && "$reached_china" -eq 0 ]]; then
            reached_china=1
            entry_point="${location_str}"
        fi

        if [[ "$cc" != "$prev_cc" && "$cc" != "??" ]]; then
            path_countries+=("$cc")
            path_labels+=("$(country_label "$cc")")
            prev_cc="$cc"
        fi

        printf "  %-5s ${BLUE}%-18s${PLAIN} ${lat_color}%-10s${PLAIN} %-30s ${DIM}%s${PLAIN}%b\n" \
            "${hop_num}" "$hop_ip" "${hop_lat:-—}" \
            "${location_str:0:30}" "${isp_name:0:32}" "${detour_mark}"

    done <<< "$trace_out"

    # ── 路径摘要 ──
    echo ""
    if [[ ${#path_labels[@]} -gt 0 ]]; then
        local path_str
        path_str=$(IFS=' → '; echo "${path_labels[*]}")
        echo -e "  ${WHITE}路由路径:${PLAIN} ${path_str}"
    fi

    # ── ASN 线路质量识别 ──
    local asn_str="${path_asns[*]:-}"
    local quality_label quality_color
    case "$isp_code" in
    CT)
        if echo "$asn_str" | grep -qw "4809"; then
            quality_label="CN2 GIA (AS4809) — 精品线路，延迟极低"
            quality_color="$GREEN"
        elif echo "$asn_str" | grep -qw "4134"; then
            quality_label="163 骨干 (AS4134) — 普通电信，高峰期可能拥堵"
            quality_color="$YELLOW"
        else
            quality_label="电信线路 — ASN 未能识别"
            quality_color="$DIM"
        fi ;;
    CU)
        if echo "$asn_str" | grep -qw "9929"; then
            quality_label="精品网 (AS9929) — 联通高端线路，延迟低"
            quality_color="$GREEN"
        elif echo "$asn_str" | grep -qw "10099"; then
            quality_label="联通国际 (AS10099) — 优质国际路由"
            quality_color="$GREEN"
        elif echo "$asn_str" | grep -qw "4837"; then
            quality_label="169 骨干 (AS4837) — 普通联通，高峰期可能拥堵"
            quality_color="$YELLOW"
        else
            quality_label="联通线路 — ASN 未能识别"
            quality_color="$DIM"
        fi ;;
    CM)
        if echo "$asn_str" | grep -qw "58453"; then
            quality_label="CMI (AS58453) — 移动国际精品线路"
            quality_color="$GREEN"
        elif echo "$asn_str" | grep -qw "9808" || echo "$asn_str" | grep -qw "56040"; then
            quality_label="移动骨干 (AS9808/AS56040) — 普通移动线路"
            quality_color="$YELLOW"
        else
            quality_label="移动线路 — ASN 未能识别"
            quality_color="$DIM"
        fi ;;
    EDU)
        if echo "$asn_str" | grep -qw "24206"; then
            quality_label="CERNET2 (AS24206) — 下一代教育网"
            quality_color="$GREEN"
        elif echo "$asn_str" | grep -qw "4538"; then
            quality_label="CERNET (AS4538) — 教育网直连"
            quality_color="$GREEN"
        else
            quality_label="教育网 — ASN 未能识别"
            quality_color="$DIM"
        fi ;;
    CBN)
        if echo "$asn_str" | grep -qw "56048"; then
            quality_label="广电骨干 (AS56048) — 广电直连"
            quality_color="$GREEN"
        else
            quality_label="广电线路 — ASN 未能识别 (广电路由仍在完善)"
            quality_color="$DIM"
        fi ;;
    esac
    echo -e "  ${WHITE}线路质量:${PLAIN} ${quality_color}${quality_label}${PLAIN}"

    # ── 直连 / 绕路 判定 ──
    if [[ ${#detour_flags[@]} -gt 0 ]]; then
        local detour_str
        detour_str=$(IFS=' / '; echo "${detour_flags[*]}")
        echo -e "  ${RED}⚠  绕路: 流量经过 [ ${detour_str} ] 中转！延迟偏高${PLAIN}"
        echo -e "  ${YELLOW}   建议联系机房优化回程路由${PLAIN}"
    elif [[ "$reached_china" -eq 1 ]]; then
        if [[ -n "$last_foreign_cc" ]]; then
            local via_label
            via_label=$(country_label "$last_foreign_cc")
            echo -e "  ${GREEN}✓  直连 (经 ${via_label} → ${entry_point} 入境，路由正常)${PLAIN}"
        else
            echo -e "  ${GREEN}✓  直连 (${entry_point:-中国境内} 直接入境)${PLAIN}"
        fi
    else
        echo -e "  ${YELLOW}?  未追踪到目标 (目标可能屏蔽 ICMP 或网络不通)${PLAIN}"
    fi
    echo ""
}

# ── 主入口：五网回程路由检测 ──
check_china_routing() {
    section_header "回程路由检测  China Route Trace (五网)"

    if ! ensure_traceroute; then
        recho " ${RED}无法安装 traceroute，请手动安装后重试${PLAIN}"
        recho " ${DIM}  Debian/Ubuntu: apt install traceroute${PLAIN}"
        recho " ${DIM}  CentOS/RHEL:   yum install traceroute${PLAIN}"
        return 1
    fi

    echo ""
    echo -e " ${WHITE}出发节点: ${GREEN}${LOCAL_IP_MASKED}${PLAIN} ${WHITE}/ ${GREEN}${LOCAL_COUNTRY:-未知} (${LOCAL_COUNTRY_CODE:-??})${PLAIN}"
    echo -e " ${WHITE}检测目标: 电信 · 联通 · 移动 · 教育网 · 广电 — 各 2 个骨干节点，共 10 条路径${PLAIN}"
    echo -e " ${DIM}每条路径最多 20 跳，每跳超时 3s，预计耗时 5-15 分钟，请耐心等待...${PLAIN}"

    # ══════════════════════════════════════
    #  🔴 中国电信  China Telecom
    #  普通: 163 骨干 AS4134
    #  精品: CN2 GT/GIA AS4809
    # ══════════════════════════════════════
    echo ""
    echo -e " ${RED}${BOLD}━━━━━━━━━━━━  🔴 中国电信 China Telecom  ━━━━━━━━━━━━━${PLAIN}"
    echo -e " ${DIM}   精品 CN2 GIA (AS4809) > CN2 GT > 163骨干 (AS4134)${PLAIN}"
    trace_one_target "202.96.128.86"    "上海电信   AS4134/AS4809" "CT" "RED"
    trace_one_target "61.139.2.69"      "成都电信   AS4134/AS4809" "CT" "RED"

    # ══════════════════════════════════════
    #  🟡 中国联通  China Unicom
    #  普通: 169 骨干 AS4837
    #  精品: 联通精品网 AS9929
    # ══════════════════════════════════════
    echo ""
    echo -e " ${YELLOW}${BOLD}━━━━━━━━━━━━  🟡 中国联通 China Unicom  ━━━━━━━━━━━━━${PLAIN}"
    echo -e " ${DIM}   精品网 AS9929 > 联通国际 AS10099 > 169骨干 (AS4837)${PLAIN}"
    trace_one_target "210.22.97.1"      "上海联通   AS4837/AS9929" "CU" "YELLOW"
    trace_one_target "202.106.196.115"  "北京联通   AS4837/AS9929" "CU" "YELLOW"

    # ══════════════════════════════════════
    #  🟢 中国移动  China Mobile
    #  普通: 骨干 AS9808 / AS56040
    #  精品: CMI AS58453
    # ══════════════════════════════════════
    echo ""
    echo -e " ${GREEN}${BOLD}━━━━━━━━━━━━  🟢 中国移动 China Mobile  ━━━━━━━━━━━━━${PLAIN}"
    echo -e " ${DIM}   CMI (AS58453) > 移动骨干 (AS9808/AS56040)${PLAIN}"
    trace_one_target "211.136.112.200"  "上海移动   AS9808/AS58453" "CM" "GREEN"
    trace_one_target "183.232.105.65"   "广州移动   AS9808/AS58453" "CM" "GREEN"

    # ══════════════════════════════════════
    #  🔵 中国教育网  CERNET
    #  AS4538 CERNET / AS24206 CERNET2
    # ══════════════════════════════════════
    echo ""
    echo -e " ${BLUE}${BOLD}━━━━━━━━━━━━  🔵 中国教育网 CERNET  ━━━━━━━━━━━━━━━━${PLAIN}"
    echo -e " ${DIM}   CERNET2 (AS24206) ≈ CERNET (AS4538) — 高校/科研专用${PLAIN}"
    trace_one_target "202.112.0.36"     "北京 CERNET    AS4538" "EDU" "BLUE"
    trace_one_target "101.6.6.6"        "清华 TUNA      AS4538" "EDU" "BLUE"

    # ══════════════════════════════════════
    #  🟣 中国广电  CBBN
    #  AS56048 广电骨干（5G 新兴网络）
    # ══════════════════════════════════════
    echo ""
    echo -e " ${PURPLE}${BOLD}━━━━━━━━━━━━  🟣 中国广电 CBBN (AS56048)  ━━━━━━━━━━━━${PLAIN}"
    echo -e " ${DIM}   广电骨干 AS56048 — 5G 新兴运营商，部分地区路由仍在完善中${PLAIN}"
    trace_one_target "39.134.68.1"      "广电骨干 (北)  AS56048" "CBN" "PURPLE"
    trace_one_target "39.135.0.1"       "广电骨干 (南)  AS56048" "CBN" "PURPLE"

    # ── 全局参考 ──
    echo ""
    print_thin_line
    echo -e " ${WHITE}${BOLD}线路质量参考 (各运营商由优到劣):${PLAIN}"
    echo -e "  ${RED}电信:${PLAIN}  CN2 GIA (AS4809) ${DIM}>>>${PLAIN} CN2 GT ${DIM}>>${PLAIN} 163骨干 (AS4134)"
    echo -e "  ${YELLOW}联通:${PLAIN}  AS9929精品 ${DIM}>>>${PLAIN} AS10099国际 ${DIM}>>${PLAIN} 169骨干 (AS4837)"
    echo -e "  ${GREEN}移动:${PLAIN}  CMI (AS58453) ${DIM}>>>${PLAIN} 移动骨干 (AS9808)"
    echo -e "  ${BLUE}教育网:${PLAIN} CERNET2 (AS24206) ${DIM}≈${PLAIN} CERNET (AS4538)"
    echo -e "  ${PURPLE}广电:${PLAIN}  AS56048 (5G新网，持续建设中)"
    echo ""
    echo -e " ${DIM}⚑ 绕路: 从亚洲节点出发却经过美国/欧洲中转，会增加 100ms+ 延迟${PLAIN}"
    echo ""
}

run_all() {
    run_global_streaming
    run_asia_pacific
    run_music_video
    run_ai_services
    run_sports_uk
    run_tools
}

# ─────────────────────────────────────────────
#  IP 分析面板（显示）
# ─────────────────────────────────────────────
show_ip_analysis() {
    echo ""
    echo -e " ${BOLD}${BLUE}╔══════════════════════════════════════════════════════════════╗${PLAIN}"
    echo -e " ${BOLD}${BLUE}║                     IP 节点分析报告                         ║${PLAIN}"
    echo -e " ${BOLD}${BLUE}╚══════════════════════════════════════════════════════════════╝${PLAIN}"
    echo ""
    printf " ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n" "IP 地址:"     "${LOCAL_IP_MASKED:-获取失败}"
    printf " ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n" "国家/地区:"   "${LOCAL_COUNTRY:-未知} (${LOCAL_COUNTRY_CODE:-??})"
    printf " ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n" "城市:"        "${LOCAL_CITY:-未知}"
    printf " ${WHITE}%-22s${PLAIN} ${GREEN}%s${PLAIN}\n" "运营商/ASN:"  "${LOCAL_ORG:-未知}${LOCAL_ASN:+ (AS${LOCAL_ASN})}"
    echo ""
    print_thin_line
    echo ""

    printf " ${WHITE}%-22s${PLAIN} ${BOLD}%s %s${PLAIN}\n" "IP 类型:" "$IP_TYPE_ICON" "$IP_TYPE"
    printf " ${WHITE}%-22s${PLAIN} %s\n" "代理/VPN 标记:" \
        "$([[ "$IP_IS_PROXY" == "是" ]] && echo -e "${RED}是${PLAIN}" || echo -e "${GREEN}否${PLAIN}")"
    printf " ${WHITE}%-22s${PLAIN} %s\n" "机房/托管标记:" \
        "$([[ "$IP_IS_HOSTING" == "是" ]] && echo -e "${YELLOW}是${PLAIN}" || echo -e "${GREEN}否${PLAIN}")"
    echo ""
    print_thin_line
    echo ""

    local risk_level risk_color
    if   [[ "$IP_RISK_SCORE" -le 25 ]]; then risk_level="低风险  ✓"; risk_color="$GREEN"
    elif [[ "$IP_RISK_SCORE" -le 55 ]]; then risk_level="中风险  !"; risk_color="$YELLOW"
    else                                      risk_level="高风险  ✗"; risk_color="$RED"
    fi

    printf " ${WHITE}%-22s${PLAIN} " "欺诈风险分:"
    draw_bar "$IP_RISK_SCORE"
    printf " ${WHITE}%-22s${PLAIN} ${risk_color}%s${PLAIN}\n" "风险等级:" "$risk_level"
    printf " ${WHITE}%-22s${PLAIN} ${WHITE}%s${PLAIN}\n" "Scamalytics:" "${SCAM_SCORE:-N/A}/100"
    printf " ${WHITE}%-22s${PLAIN} ${WHITE}%s${PLAIN}\n" "AbuseIPDB 举报:" "${IP_BLACKLIST_STATUS}"
    echo ""
    print_thin_line
    echo ""

    printf " ${WHITE}%-22s${PLAIN} " "流媒体友好度:"
    draw_score_bar "$IP_STREAM_SCORE"

    # ── 回程路由摘要（仅展示，不参与评分）──
    if [[ ${#ROUTE_SUMMARY[@]} -gt 0 ]]; then
        echo ""
        print_thin_line
        echo ""
        echo -e " ${WHITE}${BOLD}回程路由摘要  (仅供参考，不计入评分)${PLAIN}"
        echo ""

        _show_route_line() {
            local icon="$1" label="$2" isp_code="$3"
            local status="${ROUTE_STATUS[$isp_code]:-unknown}"
            local summary="${ROUTE_SUMMARY[$isp_code]:-检测中...}"
            local padded
            padded=$(printf "%-14s" "${icon} ${label}")
            case "$status" in
                ok)      echo -e "  ${GREEN}✓${PLAIN} ${WHITE}${padded}${PLAIN} ${GREEN}${summary}${PLAIN}" ;;
                warn)    echo -e "  ${RED}⚠${PLAIN} ${WHITE}${padded}${PLAIN} ${RED}${summary}${PLAIN}" ;;
                unknown) echo -e "  ${YELLOW}?${PLAIN} ${DIM}${padded}${PLAIN} ${YELLOW}${summary}${PLAIN}" ;;
                *)       echo -e "  ${DIM}-${PLAIN} ${DIM}${padded}  ${summary}${PLAIN}" ;;
            esac
        }

        _show_route_line "🔴" "电信"   "CT"
        _show_route_line "🟡" "联通"   "CU"
        _show_route_line "🟢" "移动"   "CM"
        _show_route_line "🔵" "教育网" "EDU"
        _show_route_line "🟣" "广电"   "CBN"

        echo ""
        echo -e "  ${DIM}选项 16 可查看各运营商完整逐跳路由详情${PLAIN}"
    fi

    # ── 综合评级（仅基于 IP 类型 + 欺诈风险，不含路由）──
    local grade grade_color grade_desc
    local safety_score=$(( (100 - IP_RISK_SCORE) / 10 ))
    local avg=$(( (safety_score + IP_STREAM_SCORE) / 2 ))

    if   [[ "$avg" -ge 8 ]]; then grade="S"; grade_color="$GREEN";  grade_desc="极佳 — 家宽/原生IP，解锁能力强"
    elif [[ "$avg" -ge 6 ]]; then grade="A"; grade_color="$GREEN";  grade_desc="良好 — 大部分平台可解锁"
    elif [[ "$avg" -ge 4 ]]; then grade="B"; grade_color="$YELLOW"; grade_desc="中等 — 部分平台可解锁"
    elif [[ "$avg" -ge 2 ]]; then grade="C"; grade_color="$ORANGE"; grade_desc="较差 — 仅少数平台可解锁"
    else                          grade="D"; grade_color="$RED";    grade_desc="极差 — 大部分平台屏蔽"
    fi

    echo ""
    echo -e "  ${DIM}综合评级基于: IP类型 + 欺诈风险分，不含路由与延迟${PLAIN}"
    printf " ${WHITE}%-22s${PLAIN} ${BOLD}${grade_color}[ %s ]  %s${PLAIN}\n" "综合评级:" "$grade" "$grade_desc"
    echo ""
}

# ─────────────────────────────────────────────
#  Header & Summary
# ─────────────────────────────────────────────
show_header() {
    clear
    echo ""
    echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════════════════════════╗${PLAIN}"
    echo -e "${BLUE}${BOLD}║              VPS 全能检测脚本  vpscheck  v3.2.0             ║${PLAIN}"
    echo -e "${BLUE}${BOLD}║  流媒体解锁 / AI服务 / IP分析 / 三网测速 / 回程路由        ║${PLAIN}"
    echo -e "${BLUE}${BOLD}║  系统信息 / 磁盘IO / UnixBench / IPv6 / 延迟测试           ║${PLAIN}"
    echo -e "${BLUE}${BOLD}╠══════════════════════════════════════════════════════════════╣${PLAIN}"
    echo -e "${BLUE}${BOLD}║  作者: 静水流深   网站: 中国站长   https://cnwebmasters.com ║${PLAIN}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════════════════════╝${PLAIN}"
    echo ""
}

show_summary() {
    calc_stream_score
    echo ""
    print_line
    echo ""
    printf " ${WHITE}%-22s${PLAIN} " "流媒体友好度:"
    draw_score_bar "$IP_STREAM_SCORE"
    echo ""
    printf " ${BOLD}检测汇总:${PLAIN}   "
    printf "${GREEN}解锁 %-3s${PLAIN}   " "$UNLOCKED_COUNT"
    printf "${RED}屏蔽 %-3s${PLAIN}   " "$BLOCKED_COUNT"
    printf "${YELLOW}失败 %-3s${PLAIN}   " "$FAILED_COUNT"
    printf "${DIM}共 %s 项${PLAIN}\n"  "$TOTAL_CHECKS"

    show_history_diff
    save_history

    echo ""
    echo -e " ${DIM}图例: ${GREEN}✓ 解锁${PLAIN}${DIM}  ${YELLOW}~ 部分支持${PLAIN}${DIM}  ${RED}✗ 屏蔽${PLAIN}${DIM}  ${YELLOW}? 检测失败${PLAIN}"

    if [[ "$SAVE_REPORT" -eq 1 && -n "$REPORT_FILE" ]]; then
        {
            echo "========================================"
            echo "  流媒体 & AI 服务解锁检测报告 v${VER}"
            echo "  检测时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "========================================"
            echo ""
            echo "IP 地址:     ${LOCAL_IP_MASKED}"
            echo "国家/地区:   ${LOCAL_COUNTRY} (${LOCAL_COUNTRY_CODE})"
            echo "城市:        ${LOCAL_CITY}"
            echo "运营商/ASN:  ${LOCAL_ORG} (AS${LOCAL_ASN})"
            echo "IP 类型:     ${IP_TYPE_ICON} ${IP_TYPE}"
            echo "风险评分:    ${IP_RISK_SCORE}/100"
            echo "AbuseIPDB:   ${IP_BLACKLIST_STATUS}"
            echo ""
            echo "解锁: ${UNLOCKED_COUNT}  屏蔽: ${BLOCKED_COUNT}  失败: ${FAILED_COUNT}  共: ${TOTAL_CHECKS} 项"
            echo ""
            echo -e "$REPORT_BUFFER" | sed 's/\x1b\[[0-9;]*m//g'
        } > "$REPORT_FILE"
        echo ""
        echo -e " ${GREEN}✓ 报告已保存至: ${BOLD}${REPORT_FILE}${PLAIN}"
    fi
    echo ""
}

# ─────────────────────────────────────────────
#  菜单
# ─────────────────────────────────────────────
show_menu() {
    show_header
    show_ip_analysis

    echo -e " ${BOLD}请选择检测项目：${PLAIN}"
    echo ""
    echo -e "  ${GREEN}1.${PLAIN} 全部检测 ${DIM}(推荐)${PLAIN}"
    echo -e "  ${GREEN}2.${PLAIN} 全球流媒体  ${DIM}Netflix / Disney+ / HBO / Hulu / Prime ...${PLAIN}"
    echo -e "  ${GREEN}3.${PLAIN} 亚太流媒体  ${DIM}HotStar / 動畫瘋 / AbemaTV / NicoNico ...${PLAIN}"
    echo -e "  ${GREEN}4.${PLAIN} 音乐 & 短视频  ${DIM}Spotify / YouTube / TikTok${PLAIN}"
    echo -e "  ${GREEN}5.${PLAIN} AI 服务  ${DIM}ChatGPT / Gemini / Claude / Copilot / Grok / DeepSeek / Kimi ...${PLAIN}"
    echo -e "  ${GREEN}6.${PLAIN} 体育 & 英国  ${DIM}DAZN / F1 TV / BBC iPlayer${PLAIN}"
    echo -e "  ${GREEN}7.${PLAIN} 工具类  ${DIM}Steam 货币区${PLAIN}"
    echo -e "  ${GREEN}8.${PLAIN} 延迟测试  ${DIM}各大 CDN 节点延迟${PLAIN}"
    echo -e "  ${GREEN}9.${PLAIN} IPv6 检测  ${DIM}IPv6 可用性 & 流媒体${PLAIN}"
    echo ""
    echo -e "  ${BLUE}${BOLD}── 服务器性能 ────────────────────────────────────${PLAIN}"
    echo -e "  ${GREEN}10.${PLAIN} 系统信息  ${DIM}CPU / 内存 / 磁盘 / 虚拟化 / 负载${PLAIN}"
    echo -e "  ${GREEN}11.${PLAIN} 磁盘 I/O 测试  ${DIM}顺序读写 + 4K 随机写${PLAIN}"
    echo -e "  ${GREEN}12.${PLAIN} 三网测速  ${DIM}电信 / 联通 / 移动 全节点${PLAIN}"
    echo -e "  ${GREEN}13.${PLAIN} 三网快速测速  ${DIM}每运营商 2 个节点，速度快${PLAIN}"
    echo -e "  ${GREEN}14.${PLAIN} 综合基准  ${DIM}系统信息 + 磁盘 I/O + 快速三网测速${PLAIN}"
    echo -e "  ${GREEN}15.${PLAIN} ${YELLOW}UnixBench CPU 跑分${PLAIN}  ${DIM}耗时约 10-30 分钟，慎重选择${PLAIN}"
    echo -e "  ${GREEN}16.${PLAIN} ${PURPLE}回程路由检测${PLAIN}  ${DIM}检测到中国三网是否直连或绕路${PLAIN}"
    echo ""
    echo -e "  ${DIM}u. 仅显示已解锁项目    0. 退出${PLAIN}"
    echo ""
    read -rp " 请输入选项 [0-16/u]: " choice

    local RUN_FN=""
    case "$choice" in
        1) RUN_FN="run_all" ;;
        2) RUN_FN="run_global_streaming" ;;
        3) RUN_FN="run_asia_pacific" ;;
        4) RUN_FN="run_music_video" ;;
        5) RUN_FN="run_ai_services" ;;
        6) RUN_FN="run_sports_uk" ;;
        7) RUN_FN="run_tools" ;;
        8) RUN_FN="latency_test" ;;
        9) RUN_FN="check_ipv6" ;;
        10) RUN_FN="show_system_info" ;;
        11) RUN_FN="disk_io_test" ;;
        12) RUN_FN="china_speed_test" ;;
        13) RUN_FN="china_speed_test_fast" ;;
        14) RUN_FN="run_bench_full" ;;
        15) RUN_FN="run_unixbench" ;;
        16) RUN_FN="check_china_routing" ;;
        u|U) SHOW_ONLY_UNLOCKED=1; RUN_FN="run_all" ;;
        0) echo -e "\n${GREEN} 感谢使用！${PLAIN}\n"; exit 0 ;;
        *) echo -e "${RED} 无效选项${PLAIN}"; sleep 1; show_menu; return ;;
    esac

    show_header
    show_ip_analysis
    [[ "$SHOW_ONLY_UNLOCKED" -eq 1 ]] && echo -e " ${DIM}(仅显示已解锁项目)${PLAIN}"
    $RUN_FN
    show_summary

    echo ""
    read -rp " 按回车键返回菜单..." _
    TOTAL_CHECKS=0; UNLOCKED_COUNT=0; FAILED_COUNT=0; BLOCKED_COUNT=0
    SHOW_ONLY_UNLOCKED=0; REPORT_BUFFER=""
    show_menu
}

# ─────────────────────────────────────────────
#  依赖检测与自动安装
# ─────────────────────────────────────────────
check_deps() {
    # 检测系统包管理器
    local pkg_mgr=""
    if   command_exists apt-get; then pkg_mgr="apt"
    elif command_exists yum;     then pkg_mgr="yum"
    elif command_exists dnf;     then pkg_mgr="dnf"
    elif command_exists apk;     then pkg_mgr="apk"
    fi

    _pkg_install() {
        local pkg="$1"
        echo -e " ${BLUE}  → 正在安装 ${pkg}...${PLAIN}"
        case "$pkg_mgr" in
            apt) apt-get install -y -q "$pkg" 2>/dev/null ;;
            yum) yum install -y -q "$pkg" 2>/dev/null ;;
            dnf) dnf install -y -q "$pkg" 2>/dev/null ;;
            apk) apk add -q "$pkg" 2>/dev/null ;;
            *)
                echo -e " ${RED}  未知包管理器，请手动安装 ${pkg}${PLAIN}"
                return 1
                ;;
        esac
    }

    local missing=()

    # ── 必要依赖 ──
    if ! command_exists curl; then
        missing+=("curl")
    fi
    if ! command_exists wget; then
        missing+=("wget")
    fi
    if ! command_exists awk; then
        missing+=("gawk")
    fi

    # ── traceroute（路由检测必须）──
    if ! command_exists traceroute && ! command_exists tracepath; then
        missing+=("traceroute")
    fi

    # ── bc（延迟计算，部分系统没有）──
    if ! command_exists bc && ! command_exists awk; then
        missing+=("bc")
    fi

    # ── gawk（确保使用 GNU awk，mawk 不完全兼容）──
    if command_exists awk && ! (awk --version 2>&1 | grep -qi 'GNU') && ! command_exists gawk; then
        missing+=("gawk")
    fi

    # 若有缺失，先更新索引再批量安装
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        echo -e " ${YELLOW}⚙  检测到缺失依赖: ${missing[*]}${PLAIN}"
        echo -e " ${BLUE}   正在自动安装，请稍候...${PLAIN}"

        # 更新包索引（只更新一次）
        if [[ -n "$pkg_mgr" ]]; then
            case "$pkg_mgr" in
                apt) apt-get update -qq 2>/dev/null ;;
                yum) : ;; dnf) : ;; apk) apk update -q 2>/dev/null ;;
            esac
        fi

        local failed=()
        for dep in "${missing[@]}"; do
            if ! _pkg_install "$dep"; then
                failed+=("$dep")
            fi
        done

        if [[ ${#failed[@]} -gt 0 ]]; then
            echo -e " ${RED}  以下依赖安装失败: ${failed[*]}${PLAIN}"
            echo -e " ${YELLOW}  部分功能可能受限，但脚本将继续运行${PLAIN}"
        else
            echo -e " ${GREEN}  ✓ 所有依赖安装完成${PLAIN}"
        fi
        echo ""
    fi
}

# ─────────────────────────────────────────────
#  快速回程路由摘要（启动时自动运行）
#  每个运营商只追踪一条路径，最多 15 跳，2s 超时
#  只输出摘要行，不做详细逐跳展示
# ─────────────────────────────────────────────

# 全局存储各 ISP 路由摘要（供 show_ip_analysis 展示）
declare -A ROUTE_SUMMARY   # ISP代码 → 摘要文字
declare -A ROUTE_STATUS    # ISP代码 → ok / warn / err / unknown

_quick_trace_one() {
    local target_ip="$1"
    local isp_code="$2"

    # 确认 traceroute 可用
    local trace_cmd=""
    command_exists traceroute && trace_cmd="traceroute"
    command_exists tracepath  && [[ -z "$trace_cmd" ]] && trace_cmd="tracepath"
    [[ -z "$trace_cmd" ]] && {
        ROUTE_STATUS[$isp_code]="unknown"
        ROUTE_SUMMARY[$isp_code]="traceroute 不可用"
        return
    }

    local trace_out
    if [[ "$trace_cmd" == "traceroute" ]]; then
        trace_out=$(traceroute -n -m 15 -q 1 -w 2 "$target_ip" 2>/dev/null)
    else
        trace_out=$(tracepath -n -m 15 "$target_ip" 2>/dev/null)
    fi

    [[ -z "$trace_out" ]] && {
        ROUTE_STATUS[$isp_code]="unknown"
        ROUTE_SUMMARY[$isp_code]="目标不可达"
        return
    }

    local path_asns=()
    local path_ccs=()
    local prev_cc=""
    local reached_china=0
    local detour_countries=()
    local entry_label=""
    local last_foreign_cc=""

    while IFS= read -r line; do
        local hop_ip
        hop_ip=$(echo "$line" | grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' | grep -v '^0\.' | head -1)
        [[ -z "$hop_ip" ]] && continue
        is_private_ip "$hop_ip" && continue

        # 地理信息
        local geo
        geo=$(geoip_hop "$hop_ip")
        local cc="${geo%%|*}"
        [[ "$cc" == "??" ]] && continue

        # 快速 ASN 查询
        local asn
        asn=$(curl -s --connect-timeout 1 --max-time 2 \
            "http://ip-api.com/json/${hop_ip}?fields=as" 2>/dev/null | \
            grep -oP '"as"\s*:\s*"AS\K[0-9]+')
        [[ -n "$asn" ]] && path_asns+=("$asn")

        # 绕路检测（从亚洲出发，经过美国/欧洲）
        if [[ "$cc" != "CN" && "$cc" != "HK" && "$cc" != "TW" && "$cc" != "MO" && "$reached_china" -eq 0 ]]; then
            last_foreign_cc="$cc"
            local asia_src="SG JP KR HK TW ID MY TH PH VN"
            if echo "$asia_src" | grep -qw "$LOCAL_COUNTRY_CODE"; then
                if echo "US CA" | grep -qw "$cc"; then
                    echo "${detour_countries[@]}" | grep -qw "美国" || detour_countries+=("美国")
                elif echo "GB DE FR NL SE IT ES PL CH" | grep -qw "$cc"; then
                    local c_name="${geo#*|}"; c_name="${c_name%%|*}"
                    echo "${detour_countries[@]}" | grep -qw "欧洲" || detour_countries+=("欧洲·${c_name}")
                fi
            fi
        fi

        # 记录入境
        if [[ ( "$cc" == "CN" || "$cc" == "HK" || "$cc" == "TW" || "$cc" == "MO" ) && "$reached_china" -eq 0 ]]; then
            reached_china=1
            entry_label=$(country_label "$cc")
        fi

        if [[ "$cc" != "$prev_cc" ]]; then
            path_ccs+=("$cc")
            prev_cc="$cc"
        fi
    done <<< "$trace_out"

    # ── 线路质量识别 ──
    local asn_str="${path_asns[*]:-}"
    local quality=""
    case "$isp_code" in
        CT)
            if   echo "$asn_str" | grep -qw "4809"; then quality="CN2 GIA (AS4809)"
            elif echo "$asn_str" | grep -qw "4134"; then quality="163骨干 (AS4134)"
            fi ;;
        CU)
            if   echo "$asn_str" | grep -qw "9929";  then quality="精品网 (AS9929)"
            elif echo "$asn_str" | grep -qw "10099"; then quality="国际 (AS10099)"
            elif echo "$asn_str" | grep -qw "4837";  then quality="169骨干 (AS4837)"
            fi ;;
        CM)
            if   echo "$asn_str" | grep -qw "58453"; then quality="CMI (AS58453)"
            elif echo "$asn_str" | grep -qw "9808";  then quality="移动骨干 (AS9808)"
            elif echo "$asn_str" | grep -qw "56040"; then quality="移动骨干 (AS56040)"
            fi ;;
        EDU)
            if   echo "$asn_str" | grep -qw "24206"; then quality="CERNET2 (AS24206)"
            elif echo "$asn_str" | grep -qw "4538";  then quality="CERNET (AS4538)"
            fi ;;
        CBN)
            echo "$asn_str" | grep -qw "56048" && quality="广电骨干 (AS56048)"
            ;;
    esac

    # ── 构建摘要 ──
    local summary=""
    if [[ ${#detour_countries[@]} -gt 0 ]]; then
        local d_str
        d_str=$(IFS='/'; echo "${detour_countries[*]}")
        ROUTE_STATUS[$isp_code]="warn"
        summary="绕路 [ ${d_str} ]"
        [[ -n "$quality" ]] && summary+="  ${quality}"
    elif [[ "$reached_china" -eq 1 ]]; then
        ROUTE_STATUS[$isp_code]="ok"
        summary="直连"
        [[ -n "$last_foreign_cc" ]] && summary+=" (经 $(country_label "$last_foreign_cc") → ${entry_label} 入境)"
        [[ -n "$quality" ]] && summary+="  ${quality}"
    else
        ROUTE_STATUS[$isp_code]="unknown"
        summary="未追踪到目标 (可能屏蔽 ICMP)"
    fi
    ROUTE_SUMMARY[$isp_code]="$summary"
}

run_quick_routing() {
    echo -e " ${BLUE}正在检测回程路由...${PLAIN}  ${DIM}(电信/联通/移动/教育网/广电)${PLAIN}"

    # 五网各取一个代表性骨干 IP，并行后台运行
    _quick_trace_one "202.96.128.86"    "CT"  &
    local pid_ct=$!
    _quick_trace_one "210.22.97.1"      "CU"  &
    local pid_cu=$!
    _quick_trace_one "211.136.112.200"  "CM"  &
    local pid_cm=$!
    _quick_trace_one "202.112.0.36"     "EDU" &
    local pid_edu=$!
    _quick_trace_one "39.134.68.1"      "CBN" &
    local pid_cbn=$!

    # 等待所有后台任务完成
    wait "$pid_ct" "$pid_cu" "$pid_cm" "$pid_edu" "$pid_cbn" 2>/dev/null
}

# ─────────────────────────────────────────────
#  命令行参数
# ─────────────────────────────────────────────
usage() {
    cat <<EOF

${BOLD}用法:${PLAIN} $0 [选项]

  ${GREEN}-I <网卡>${PLAIN}       指定出口网卡 (如: eth0)
  ${GREEN}-P <代理>${PLAIN}       使用代理 (格式: socks5://host:port 或 http://host:port)
  ${GREEN}-r <编号>${PLAIN}       直接运行指定项目:
                    1=全部  2=全球流媒体  3=亚太  4=音乐短视频
                    5=AI服务  6=体育英国  7=工具  8=延迟  9=IPv6
                    10=系统信息  11=磁盘IO  12=三网测速  13=快速测速
                    14=综合基准  15=UnixBench跑分  16=回程路由检测
  ${GREEN}-u${PLAIN}             仅显示已解锁服务
  ${GREEN}-o <文件>${PLAIN}       保存纯文本报告到指定文件
  ${GREEN}-h${PLAIN}             显示帮助

${BOLD}示例:${PLAIN}
  $0                                  # 交互式菜单
  $0 -r 1                             # 全部检测
  $0 -r 5                             # 只检测 AI 服务
  $0 -r 1 -o /tmp/report.txt          # 全部检测并保存报告
  $0 -P socks5://127.0.0.1:1080 -r 1
  $0 -I eth0 -u -r 2

EOF
}

parse_args() {
    local direct_run=""
    while getopts "I:P:r:uo:h" opt; do
        case $opt in
            I) USE_INTERFACE="--interface $OPTARG" ;;
            P) PROXY_OPTS="-x $OPTARG" ;;
            r) direct_run="$OPTARG" ;;
            u) SHOW_ONLY_UNLOCKED=1 ;;
            o) SAVE_REPORT=1; REPORT_FILE="$OPTARG" ;;
            h) usage; exit 0 ;;
            *) usage; exit 1 ;;
        esac
    done
    echo "$direct_run"
}

# ─────────────────────────────────────────────
#  主入口
# ─────────────────────────────────────────────
main() {
    # ── Step 1: 依赖检测与自动安装 ──
    check_deps

    local direct_run
    direct_run=$(parse_args "$@")

    show_header

    # ── Step 2: 并行获取 IP 信息 + 回程路由 ──
    echo -e " ${BLUE}正在分析节点信息，请稍候...${PLAIN}"
    load_history
    get_ip_info
    detect_ip_type
    assess_ip_risk

    # 回程路由并行检测（后台跑，与后续菜单渲染不冲突）
    # 用 subshell 包裹，结果写入全局关联数组
    run_quick_routing

    if [[ -n "$direct_run" ]]; then
        show_header
        show_ip_analysis
        case "$direct_run" in
            1) run_all ;;
            2) run_global_streaming ;;
            3) run_asia_pacific ;;
            4) run_music_video ;;
            5) run_ai_services ;;
            6) run_sports_uk ;;
            7) run_tools ;;
            8) latency_test ;;
            9) check_ipv6 ;;
            10) show_system_info ;;
            11) disk_io_test ;;
            12) china_speed_test ;;
            13) china_speed_test_fast ;;
            14) run_bench_full ;;
            15) run_unixbench ;;
            16) check_china_routing ;;
            *) echo -e "${RED}无效的 -r 参数 (1-16)${PLAIN}"; exit 1 ;;
        esac
        show_summary
    else
        show_menu
    fi
}

main "$@"
