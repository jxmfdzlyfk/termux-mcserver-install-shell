#!/data/data/com.termux/files/usr/bin/bash
#============================================================
# Minecraft 服务端一键安装脚本 (Termux 专用)
# 版本: v1.3.1
# 更新日期: 2026-10-04
# 支持: Paper / Fabric / Vanilla / Nukkit
# 用法: bash install_mc.sh
#============================================================

set -euo pipefail
IFS=$'\n\t'

SCRIPT_VERSION="v1.3.1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

LOG_DIR="$HOME/.mcserver_installer"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true; }
info()  { echo -e "${GREEN}[信息]${NC} $1"; log "INFO: $1"; }
warn()  { echo -e "${YELLOW}[警告]${NC} $1"; log "WARN: $1"; }
error() { echo -e "${RED}[错误]${NC} $1"; log "ERROR: $1"; }
step()  { echo -e "${BLUE}==>${NC} $1"; log "STEP: $1"; }
title() { echo -e "${CYAN}$1${NC}"; }

check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        error "此脚本只能在 Termux 中运行！"
        exit 1
    fi
    info "Termux 环境检测通过"
    info "日志文件: $LOG_FILE"
}

install_deps() {
    step "检查并安装依赖..."
    local pkgs=("wget" "curl" "jq" "openjdk-17" "openjdk-21")
    local to_install=()
    for pkg in "${pkgs[@]}"; do
        if ! pkg list-installed 2>/dev/null | grep -q "^${pkg}/"; then
            to_install+=("$pkg")
        fi
    done
    if [ ${#to_install[@]} -gt 0 ]; then
        info "需要安装: ${to_install[*]}"
        pkg install -y "${to_install[@]}"
    else
        info "所有依赖已安装"
    fi
}

# ---------- 检测磁盘空间 ----------
check_disk_space() {
    local target_dir="${1:-$HOME}"
    local avail_mb
    avail_mb=$(df -m "$target_dir" 2>/dev/null | awk 'NR==2{print $4}')
    avail_mb=${avail_mb:-0}

    if [ "$avail_mb" -lt 1024 ]; then
        error "可用存储空间不足 1GB（当前 ${avail_mb}MB）"
        warn "请清理空间后重试"
        return 1
    elif [ "$avail_mb" -lt 2048 ]; then
        warn "可用存储空间较低（${avail_mb}MB），建议清理"
    else
        info "可用存储空间: ${avail_mb}MB"
    fi
    return 0
}

detect_memory() {
    local avail_mb
    if [ -r /proc/meminfo ] && grep -q '^MemAvailable:' /proc/meminfo; then
        avail_mb=$(($(awk '/^MemAvailable:/{print $2}' /proc/meminfo) / 1024))
        info "系统报告可用内存: ${avail_mb}MB"
    elif [ -r /proc/meminfo ]; then
        avail_mb=$(($(awk '/^MemTotal:/{print $2}' /proc/meminfo) / 1024))
        warn "无法读取可用内存，使用物理总量: ${avail_mb}MB"
    else
        avail_mb=2048
        warn "无法读取内存信息，默认按 2GB 处理"
    fi

    if [ "$avail_mb" -lt 1500 ]; then
        JAVA_XMS="256M"; JAVA_XMX="512M"
    elif [ "$avail_mb" -lt 3000 ]; then
        JAVA_XMS="256M"; JAVA_XMX="768M"
    elif [ "$avail_mb" -lt 5000 ]; then
        JAVA_XMS="512M"; JAVA_XMX="1024M"
    else
        JAVA_XMS="512M"; JAVA_XMX="1536M"
    fi
    info "分配 Java 堆内存: $JAVA_XMS ~ $JAVA_XMX"
}

detect_cpu() {
    CPU_CORES=$(nproc 2>/dev/null || echo 2)
    if [ "$CPU_CORES" -gt 4 ]; then
        GC_THREADS=4
    else
        GC_THREADS=$CPU_CORES
    fi
    CONC_GC_THREADS=$(( GC_THREADS / 2 ))
    [ "$CONC_GC_THREADS" -lt 1 ] && CONC_GC_THREADS=1
    info "CPU 核心: $CPU_CORES，GC 线程: $GC_THREADS，并发 GC: $CONC_GC_THREADS"
}

verify_jar() {
    local file="$1"
    if [ ! -f "$file" ]; then
        error "文件不存在: $file"; return 1
    fi
    if ! file "$file" 2>/dev/null | grep -qi "java archive\|zip archive"; then
        error "文件 $file 不是有效的 JAR"
        rm -f "$file"; return 1
    fi
    local size
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    if [ "$size" -lt 1048576 ]; then
        error "文件 $file 太小 (${size} 字节)"
        rm -f "$file"; return 1
    fi
    info "文件校验通过: $file ($(du -h "$file" 2>/dev/null | cut -f1))"
    return 0
}

show_menu() {
    clear
    title "=========================================="
    title "   Minecraft 服务端一键安装脚本 (Termux)"
    title "   ${SCRIPT_VERSION}"
    title "=========================================="
    echo ""
    echo "  [1] Paper    - 高性能插件服务端 (推荐)"
    echo "  [2] Fabric   - 模组服务端"
    echo "  [3] Vanilla  - Mojang 原版服务端"
    echo "  [4] Nukkit   - 基岩版服务端"
    echo "  [5] 更新现有服务器"
    echo "  [0] 退出"
    echo ""
    title "=========================================="
}

select_type() {
    while true; do
        show_menu
        set +e
        read -p "请选择服务端类型 [0-5]: " TYPE
        set -e
        case "${TYPE:-}" in
            1) SERVER_TYPE="paper";   SERVER_NAME="Paper";   break ;;
            2) SERVER_TYPE="fabric";  SERVER_NAME="Fabric";  break ;;
            3) SERVER_TYPE="vanilla"; SERVER_NAME="Vanilla"; break ;;
            4) SERVER_TYPE="nukkit";  SERVER_NAME="Nukkit";  break ;;
            5) update_server; exit 0 ;;
            0) info "已退出安装"; exit 0 ;;
            *) warn "无效选项" ; sleep 1 ;;
        esac
    done
    info "已选择: $SERVER_NAME"
}

select_version() {
    if [ "$SERVER_TYPE" = "nukkit" ]; then
        MC_VERSION="latest"; return
    fi
    while true; do
        echo ""
        echo "请输入 Minecraft 版本号 (例如 1.17.1、1.20.4、1.21.1)"
        echo -e "  ${YELLOW}注意：本脚本仅支持 1.17.1 及以上版本${NC}"
        set +e
        read -p "版本号: " MC_VERSION
        set -e

        if [ -z "${MC_VERSION:-}" ]; then
            error "版本号不能为空！"; continue
        fi
        if [[ ! "$MC_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            error "版本号格式无效！"; continue
        fi

        local major minor
        major=$(echo "$MC_VERSION" | cut -d. -f2)
        minor=$(echo "$MC_VERSION" | cut -d. -f3)
        minor=${minor:-0}

        if [ "$major" -lt 17 ] || { [ "$major" -eq 17 ] && [ "$minor" -lt 1 ]; }; then
            error "本脚本不支持 1.17.1 以下版本"
            warn "现代 Termux 安装 Java 8 极其困难，请使用 1.17.1+"
            continue
        fi
        break
    done
    info "目标版本: $MC_VERSION"
}

select_java() {
    if [ "$SERVER_TYPE" = "nukkit" ]; then
        JAVA_BIN="java"; return
    fi
    local major minor
    major=$(echo "$MC_VERSION" | cut -d. -f2)
    minor=$(echo "$MC_VERSION" | cut -d. -f3)
    minor=${minor:-0}

    if [ "$major" -ge 21 ] || { [ "$major" -eq 20 ] && [ "$minor" -ge 5 ]; }; then
        JAVA_BIN="$PREFIX/lib/jvm/java-21-openjdk/bin/java"
        info "该版本需要 Java 21"
    else
        JAVA_BIN="$PREFIX/lib/jvm/java-17-openjdk/bin/java"
        info "该版本使用 Java 17"
    fi

    if [ ! -f "$JAVA_BIN" ]; then
        error "未找到 Java: $JAVA_BIN"
        warn "请运行: pkg install openjdk-17 openjdk-21"
        exit 1
    fi
}

create_dir() {
    SERVER_DIR="$HOME/mcserver_${SERVER_TYPE}_${MC_VERSION}"
    if [ -d "$SERVER_DIR" ]; then
        warn "目录已存在: $SERVER_DIR"
        set +e
        read -p "是否覆盖安装？[y/N]: " OVERWRITE
        set -e
        if [[ ! "${OVERWRITE:-}" =~ ^[Yy]$ ]]; then
            error "已取消安装"; exit 1
        fi
        rm -rf "$SERVER_DIR"
    fi
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"
    info "服务器目录: $SERVER_DIR"
}

download_paper() {
    step "正在获取 Paper $MC_VERSION 最新构建..."
    local api="https://api.papermc.io/v2/projects/paper/versions/${MC_VERSION}/builds"
    local build
    build=$(curl -fsSL "$api" | jq -r '.builds[-1].build // empty')
    if [ -z "$build" ]; then
        error "无法获取 Paper 构建号"; return 1
    fi
    local url="https://api.papermc.io/v2/projects/paper/versions/${MC_VERSION}/builds/${build}/downloads/paper-${MC_VERSION}-${build}.jar"
    info "下载链接: $url"
    wget -O server.jar "$url" || { error "下载失败"; return 1; }
    verify_jar server.jar || return 1
}

download_fabric() {
    step "正在获取 Fabric 最新版本..."
    local loader installer
    loader=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/loader" | jq -r '.[0].version // empty')
    installer=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/installer" | jq -r '.[0].version // empty')
    if [ -z "$loader" ] || [ -z "$installer" ]; then
        error "无法获取 Fabric 版本信息"; return 1
    fi
    local url="https://meta.fabricmc.net/v2/versions/loader/${MC_VERSION}/${loader}/${installer}/server/jar"
    info "下载链接: $url"
    wget -O server.jar "$url" || { error "下载失败"; return 1; }
    verify_jar server.jar || return 1
}

download_vanilla() {
    step "正在从 Mojang 官方清单获取下载链接..."
    local manifest="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
    local meta_url
    meta_url=$(curl -fsSL "$manifest" | jq -r --arg v "$MC_VERSION" '.versions[] | select(.id==$v) | .url // empty')
    if [ -z "$meta_url" ]; then
        error "找不到版本 $MC_VERSION"; return 1
    fi
    local url
    url=$(curl -fsSL "$meta_url" | jq -r '.downloads.server.url // empty')
    if [ -z "$url" ]; then
        error "无法获取服务端下载链接"; return 1
    fi
    info "下载链接: $url"
    wget -O server.jar "$url" || { error "下载失败"; return 1; }
    verify_jar server.jar || return 1
}

download_nukkit() {
    step "正在下载 Nukkit (基岩版服务端)..."
    local url="https://repo.opencollab.dev/maven-snapshots/cn/nukkit/nukkit/1.0-SNAPSHOT/nukkit-1.0-20260821.003151-1245.jar"
    wget -O nukkit.jar "$url" || { error "下载失败"; return 1; }
    verify_jar nukkit.jar || return 1
}

generate_config() {
    step "生成配置文件..."
    if [ "$SERVER_TYPE" = "nukkit" ]; then
        echo "eula=true" > eula.txt
        info "已生成 eula.txt"
    else
        echo "eula=true" > eula.txt
        cat > server.properties <<'EOF'
# Minecraft 服务器配置（Termux 手机优化版）
max-players=5
online-mode=false
view-distance=4
simulation-distance=4
server-port=25565
motd=§a我的手机服务器
allow-flight=true
spawn-protection=0
sync-chunk-writes=false
network-compression-threshold=256
EOF
        info "已生成 eula.txt 和 server.properties"
    fi
}

# ---------- 创建启动脚本（内置自动备份） ----------
create_start_script() {
    step "创建启动脚本（含自动备份世界功能）..."

    if [ "$SERVER_TYPE" = "nukkit" ]; then
        cat > start.sh <<EOF
#!/data/data/com.termux/files/usr/bin/bash
cd "\$(dirname "\$0")"

# ---------- 自动备份世界 ----------
backup_world() {
    [ ! -d "worlds" ] && return 0
    local backup_dir="./backups"
    mkdir -p "\$backup_dir"
    local avail_mb
    avail_mb=\$(df -m . 2>/dev/null | awk 'NR==2{print \$4}')
    if [ "\${avail_mb:-0}" -lt 2048 ]; then
        echo "[备份] 剩余空间不足 2GB，跳过备份"
        return 0
    fi
    local ts=\$(date +%Y%m%d_%H%M%S)
    echo "[备份] 正在备份世界到 backups/worlds_\${ts}.tar.gz ..."
    if tar -czf "\$backup_dir/worlds_\${ts}.tar.gz" worlds 2>/dev/null; then
        echo "[备份] 完成"
        ls -1t "\$backup_dir"/worlds_*.tar.gz 2>/dev/null | tail -n +4 | xargs -r rm -f
    else
        echo "[备份] 失败，继续启动"
    fi
}
backup_world

termux-wake-lock 2>/dev/null || true
exec java -Xms${JAVA_XMS} -Xmx${JAVA_XMX} -jar nukkit.jar
EOF
    else
        cat > start.sh <<EOF
#!/data/data/com.termux/files/usr/bin/bash
cd "\$(dirname "\$0")"

# ---------- 自动备份世界 ----------
backup_world() {
    [ ! -d "world" ] && return 0
    local backup_dir="./backups"
    mkdir -p "\$backup_dir"
    local avail_mb
    avail_mb=\$(df -m . 2>/dev/null | awk 'NR==2{print \$4}')
    if [ "\${avail_mb:-0}" -lt 2048 ]; then
        echo "[备份] 剩余空间不足 2GB，跳过备份"
        return 0
    fi
    local ts=\$(date +%Y%m%d_%H%M%S)
    echo "[备份] 正在备份世界到 backups/world_\${ts}.tar.gz ..."
    if tar -czf "\$backup_dir/world_\${ts}.tar.gz" world 2>/dev/null; then
        echo "[备份] 完成，仅保留最近 3 份"
        ls -1t "\$backup_dir"/world_*.tar.gz 2>/dev/null | tail -n +4 | xargs -r rm -f
    else
        echo "[备份] 失败，继续启动"
    fi
}
backup_world

termux-wake-lock 2>/dev/null || true
exec "$JAVA_BIN" -Xms${JAVA_XMS} -Xmx${JAVA_XMX} \\
    -XX:+UseG1GC -XX:+ParallelRefProcEnabled \\
    -XX:MaxGCPauseMillis=200 \\
    -XX:ParallelGCThreads=${GC_THREADS} -XX:ConcGCThreads=${CONC_GC_THREADS} \\
    -XX:+UnlockExperimentalVMOptions -XX:G1NewSizePercent=30 \\
    -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M \\
    -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 \\
    -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 \\
    -XX:G1MixedGCLiveThresholdPercent=90 -XX:SurvivorRatio=32 \\
    -jar server.jar nogui
EOF
    fi

    chmod +x start.sh
    info "启动脚本已生成: ./start.sh"
}

# ---------- 一键更新现有服务器 ----------
update_server() {
    step "扫描已安装的服务器..."

    local servers
    servers=$(find "$HOME" -maxdepth 1 -type d -name "mcserver_*" 2>/dev/null | sort)

    if [ -z "$servers" ]; then
        error "没有找到已安装的服务器"
        return 1
    fi

    echo ""
    echo "已安装的服务器:"
    local i=1
    local dirs=()
    while IFS= read -r d; do
        local size
        size=$(du -sh "$d" 2>/dev/null | cut -f1)
        echo "  [$i] $(basename "$d")  (${size:-unknown})"
        dirs+=("$d")
        i=$((i+1))
    done <<< "$servers"

    echo ""
    set +e
    read -p "请选择要更新的服务器编号 [1-$((i-1))]: " choice
    set -e

    if ! [[ "${choice:-}" =~ ^[0-9]+$ ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#dirs[@]}" ]; then
        error "无效选择"; return 1
    fi

    # 用 pushd 保存原目录，方便最后 popd 回来
    pushd "${dirs[$((choice-1))]}" >/dev/null
    local target="$PWD"

    info "将更新: $target"
    echo ""
    echo -e "  ${GREEN}保留:${NC} world/ server.properties plugins/ mods/ config/"
    echo -e "  ${YELLOW}替换:${NC} server.jar (或 nukkit.jar) + start.sh"
    echo ""

    # 从目录名推断类型和旧版本: mcserver_paper_1.21.1
    local dir_name
    dir_name=$(basename "$target")
    SERVER_TYPE=$(echo "$dir_name" | cut -d_ -f2)
    local old_version
    old_version=$(echo "$dir_name" | cut -d_ -f3)

    if [ -z "$SERVER_TYPE" ] || [ -z "$old_version" ]; then
        error "无法从目录名识别服务器类型和版本"
        popd >/dev/null
        return 1
    fi

    info "识别到: 类型=$SERVER_TYPE, 当前版本=$old_version"

    # 让用户确认新版本（默认保持当前版本）
    echo ""
    echo "是否需要跨版本更新？"
    echo "  - 直接回车 = 保持版本 $old_version，只更新到最新构建"
    echo "  - 或输入新版本号（如 1.21.1）"
    set +e
    read -p "新版本 [${old_version}]: " new_version
    set -e
    MC_VERSION="${new_version:-$old_version}"

    if [ "$SERVER_TYPE" != "nukkit" ] && [[ ! "$MC_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
        error "版本号格式无效"
        popd >/dev/null
        return 1
    fi

    # 如果是跨版本更新，需要重新计算 Java 和 GC 参数
    if [ "$MC_VERSION" != "$old_version" ]; then
        info "跨版本更新：$old_version → $MC_VERSION"
        select_java
        detect_memory
        detect_cpu
    else
        # 同版本更新，仅重新检测内存和 CPU（用户手机可能变了）
        if [ "$SERVER_TYPE" = "nukkit" ]; then
            JAVA_BIN="java"
        else
            select_java
        fi
        detect_memory
        detect_cpu
    fi

    set +e
    read -p "确认更新？[y/N]: " confirm
    set -e
    if [[ ! "${confirm:-}" =~ ^[Yy]$ ]]; then
        info "已取消"
        popd >/dev/null
        return 0
    fi

    # 备份旧 jar
    local jar_file="server.jar"
    [ "$SERVER_TYPE" = "nukkit" ] && jar_file="nukkit.jar"

    if [ -f "$jar_file" ]; then
        local backup="${jar_file}.bak.$(date +%Y%m%d_%H%M%S)"
        mv "$jar_file" "$backup"
        info "旧版已备份: $backup"
    fi

    # 重新下载
    case "$SERVER_TYPE" in
        paper)   download_paper ;;
        fabric)  download_fabric ;;
        vanilla) download_vanilla ;;
        nukkit)  download_nukkit ;;
        *) error "未知类型: $SERVER_TYPE"; popd >/dev/null; return 1 ;;
    esac

    # 如果版本变了，目录名也跟着改
    if [ "$MC_VERSION" != "$old_version" ]; then
        local new_dir="$HOME/mcserver_${SERVER_TYPE}_${MC_VERSION}"
        if [ "$new_dir" != "$target" ]; then
            popd >/dev/null
            mv "$target" "$new_dir"
            pushd "$new_dir" >/dev/null
            SERVER_DIR="$new_dir"
            info "目录已重命名为: $new_dir"
        fi
    fi

    # 关键修复：重新生成 start.sh（因为 Java 版本、内存、GC 参数可能已变）
    create_start_script

    info "${GREEN}更新完成！世界数据已保留，start.sh 已同步更新${NC}"
    echo ""
    echo -e "  备份文件: ${backup:-无}"
    echo -e "  服务器目录: $PWD"
    echo -e "  启动命令: cd $PWD && ./start.sh"

    popd >/dev/null
}

# ---------- 完成提示 ----------
show_finish() {
    echo ""
    title "=========================================="
    title "   ${GREEN}安装完成！${NC}"
    title "=========================================="
    echo ""
    echo "  服务器类型: $SERVER_NAME"
    echo "  游戏版本:   $MC_VERSION"
    echo "  服务器目录: $SERVER_DIR"
    echo ""
    echo -e "  ${YELLOW}${BOLD}⚠️  重要提示：${NC}"
    echo "     1. 停止服务器请务必在控制台输入 ${GREEN}stop${NC}"
    echo "     2. ${RED}不要直接关闭 Termux 窗口${NC}，否则可能丢失存档"
    echo "     3. 手机请关闭省电模式，允许 Termux 后台运行"
    echo "     4. 每次启动会自动备份世界到 backups/（保留最近 3 份）"
    echo ""
    echo -e "  ${BLUE}🚀 启动服务器:${NC}"
    echo "     cd $SERVER_DIR && ./start.sh"
    echo ""
    echo -e "  ${BLUE}🛑 停止服务器:${NC}"
    echo "     在控制台输入 stop 并回车"
    echo ""
    echo -e "  ${BLUE}📱 客户端连接:${NC}"
    if [ "$SERVER_TYPE" = "nukkit" ]; then
        echo "     基岩版客户端 → IP:19132"
    else
        echo "     Java 版客户端 → IP:25565"
    fi
    echo ""
    echo -e "  ${BLUE}📄 安装日志:${NC} $LOG_FILE"
    echo ""
    title "=========================================="
}

# ---------- 主流程 ----------
main() {
    check_termux
    check_disk_space "$HOME" || exit 1
    install_deps
    select_type
    select_version
    select_java
    detect_memory
    detect_cpu
    create_dir
    check_disk_space "$SERVER_DIR" || exit 1

    case "$SERVER_TYPE" in
        paper)   download_paper ;;
        fabric)  download_fabric ;;
        vanilla) download_vanilla ;;
        nukkit)  download_nukkit ;;
    esac

    generate_config
    create_start_script
    show_finish
}

main "$@"