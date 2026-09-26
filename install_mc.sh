#!/data/data/com.termux/files/usr/bin/bash
#============================================================
# Minecraft 服务端一键安装脚本 (Termux 专用)
# 版本: v1.1.0
# 更新日期: 2026-09-25
# 支持: Paper / Fabric / Vanilla / Nukkit
# 用法: bash install_mc.sh
#============================================================

set -euo pipefail
IFS=$'\n\t'

# ---------- 颜色定义 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ---------- 日志 ----------
LOG_DIR="$HOME/.mcserver_installer"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# ---------- 输出函数 ----------
info()  { echo -e "${GREEN}[信息]${NC} $1"; log "INFO: $1"; }
warn()  { echo -e "${YELLOW}[警告]${NC} $1"; log "WARN: $1"; }
error() { echo -e "${RED}[错误]${NC} $1"; log "ERROR: $1"; }
step()  { echo -e "${BLUE}==>${NC} $1"; log "STEP: $1"; }
title() { echo -e "${CYAN}$1${NC}"; }

# ---------- 检查 Termux 环境 ----------
check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        error "此脚本只能在 Termux 中运行！"
        exit 1
    fi
    info "Termux 环境检测通过"
    info "日志文件: $LOG_FILE"
}


# ---------- 检测手机内存 ----------
detect_memory() {
    local total_mem
    total_mem=$(free -m | awk '/^Mem:/{print $2}')
    total_mem=${total_mem:-2048}

    if [ "$total_mem" -lt 3500 ]; then
        JAVA_XMS="256M"
        JAVA_XMX="768M"
    elif [ "$total_mem" -lt 6000 ]; then
        JAVA_XMS="512M"
        JAVA_XMX="1024M"
    else
        JAVA_XMS="512M"
        JAVA_XMX="1536M"
    fi

    info "检测到手机内存: ${total_mem}MB"
    info "分配 Java 堆内存: $JAVA_XMS ~ $JAVA_XMX"
}

# ---------- 校验下载的 JAR 文件 ----------
verify_jar() {
    local file="$1"

    # 检查是否是 JAR/ZIP 格式
    if ! file "$file" 2>/dev/null | grep -qi "java archive\|zip archive"; then
        error "文件 $file 不是有效的 JAR，可能是网络问题"
        rm -f "$file"
        return 1
    fi

    # 检查文件大小（至少 1MB）
    local size
    size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    if [ "$size" -lt 1048576 ]; then
        error "文件 $file 太小 (${size} 字节)，可能下载不完整"
        rm -f "$file"
        return 1
    fi

    info "文件校验通过: $file ($(du -h "$file" | cut -f1))"
    return 0
}

# ---------- 安装基础依赖（不升级） ----------
install_deps() {
    step "检查并安装依赖..."
    local pkgs=("wget" "curl" "jq" "openjdk-17" "openjdk-21")
    local to_install=()

    for pkg in "${pkgs[@]}"; do
        if ! command -v "$pkg" >/dev/null 2>&1 && ! pkg list-installed 2>/dev/null | grep -q "^${pkg}/"; then
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

# ---------- 显示主菜单 ----------
show_menu() {
    clear
    title "=========================================="
    title "   Minecraft 服务端一键安装脚本 (Termux)"
    title "   v1.1.0"
    title "=========================================="
    echo ""
    echo "  [1] Paper    - 高性能插件服务端 (推荐)"
    echo "  [2] Fabric   - 模组服务端"
    echo "  [3] Vanilla  - Mojang 原版服务端"
    echo "  [4] Nukkit   - 基岩版服务端"
    echo "  [0] 退出"
    echo ""
    title "=========================================="
}

# ---------- 选择服务器类型 ----------
select_type() {
    while true; do
        show_menu
        set +e
        read -p "请选择服务端类型 [0-4]: " TYPE
        set -e
        case "${TYPE:-}" in
            1) SERVER_TYPE="paper";   SERVER_NAME="Paper";   break ;;
            2) SERVER_TYPE="fabric";  SERVER_NAME="Fabric";  break ;;
            3) SERVER_TYPE="vanilla"; SERVER_NAME="Vanilla"; break ;;
            4) SERVER_TYPE="nukkit";  SERVER_NAME="Nukkit";  break ;;
            0) info "已退出安装"; exit 0 ;;
            *) warn "无效选项，请重新选择" ; sleep 1 ;;
        esac
    done
    info "已选择: $SERVER_NAME"
}

# ---------- 输入 MC 版本（带校验） ----------
select_version() {
    if [ "$SERVER_TYPE" = "nukkit" ]; then
        MC_VERSION="latest"
        return
    fi

    while true; do
        echo ""
        echo "请输入 Minecraft 版本号 (例如 1.20.4、1.21.1)"
        echo "  Java 版常用: 1.12.2 / 1.16.5 / 1.17.1 / 1.18.2 / 1.20.4 / 1.21.1"
        set +e
        read -p "版本号: " MC_VERSION
        set -e

        if [ -z "${MC_VERSION:-}" ]; then
            error "版本号不能为空！"
            continue
        fi

        # 正则校验: 允许 X.Y 或 X.Y.Z
        if [[ ! "$MC_VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            error "版本号格式无效！只允许数字和点（如 1.21.1）"
            continue
        fi

        break
    done
    info "目标版本: $MC_VERSION"
}

# ---------- 根据版本自动选择 Java ----------
select_java() {
    if [ "$SERVER_TYPE" = "nukkit" ]; then
        JAVA_BIN="java"
        return
    fi

    local major minor
    major=$(echo "$MC_VERSION" | cut -d. -f2)
    minor=$(echo "$MC_VERSION" | cut -d. -f3)
    minor=${minor:-0}

    # 严格映射
    if [ "$major" -le 16 ]; then
        error "Minecraft $MC_VERSION 需要 Java 8 或 11"
        warn "Termux 官方源不提供这两个版本"
        warn "建议使用 1.17.1 或更高版本，或自行安装 Java 8"
        exit 1
    elif [ "$major" -eq 17 ]; then
        # 1.17.x 需要 Java 16+
        JAVA_BIN="$PREFIX/lib/jvm/java-17-openjdk/bin/java"
        info "1.17.x 使用 Java 17"
    elif [ "$major" -eq 18 ] || [ "$major" -eq 19 ]; then
        JAVA_BIN="$PREFIX/lib/jvm/java-17-openjdk/bin/java"
        info "该版本使用 Java 17"
    elif [ "$major" -eq 20 ] && [ "$minor" -le 4 ]; then
        JAVA_BIN="$PREFIX/lib/jvm/java-17-openjdk/bin/java"
        info "1.20.4 及以下使用 Java 17"
    else
        # 1.20.5+ 和 1.21+
        JAVA_BIN="$PREFIX/lib/jvm/java-21-openjdk/bin/java"
        info "该版本需要 Java 21"
    fi

    if [ ! -f "$JAVA_BIN" ]; then
        error "未找到 Java: $JAVA_BIN"
        warn "请运行: pkg install openjdk-17 openjdk-21"
        exit 1
    fi
}
# ---------- 下载 Paper ----------
download_paper() {
    step "正在获取 Paper $MC_VERSION 最新构建..."
    local api="https://api.papermc.io/v2/projects/paper/versions/${MC_VERSION}/builds"
    local build
    build=$(curl -fsSL "$api" | jq -r '.builds[-1].build // empty')

    if [ -z "$build" ]; then
        error "无法获取 Paper 构建号，请确认版本号是否正确"
        exit 1
    fi

    local url="https://api.papermc.io/v2/projects/paper/versions/${MC_VERSION}/builds/${build}/downloads/paper-${MC_VERSION}-${build}.jar"
    info "下载链接: $url"
    wget -O server.jar "$url" || { error "下载失败"; exit 1; }
    verify_jar server.jar || exit 1
}

# ---------- 下载 Fabric ----------
download_fabric() {
    step "正在获取 Fabric 最新版本..."
    local loader installer
    loader=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/loader" | jq -r '.[0].version // empty')
    installer=$(curl -fsSL "https://meta.fabricmc.net/v2/versions/installer" | jq -r '.[0].version // empty')

    if [ -z "$loader" ] || [ -z "$installer" ]; then
        error "无法获取 Fabric 版本信息"
        exit 1
    fi

    local url="https://meta.fabricmc.net/v2/versions/loader/${MC_VERSION}/${loader}/${installer}/server/jar"
    info "下载链接: $url"
    wget -O server.jar "$url" || { error "下载失败"; exit 1; }
    verify_jar server.jar || exit 1
}

# ---------- 下载 Vanilla（从官方清单获取） ----------
download_vanilla() {
    step "正在从 Mojang 官方清单获取下载链接..."

    local manifest="https://piston-meta.mojang.com/mc/game/version_manifest_v2.json"
    local meta_url
    meta_url=$(curl -fsSL "$manifest" | jq -r --arg v "$MC_VERSION" '.versions[] | select(.id==$v) | .url // empty')

    if [ -z "$meta_url" ]; then
        error "找不到版本 $MC_VERSION 的元数据，请确认版本号是否正确"
        exit 1
    fi

    local url
    url=$(curl -fsSL "$meta_url" | jq -r '.downloads.server.url // empty')
    if [ -z "$url" ]; then
        error "无法获取服务端下载链接"
        exit 1
    fi

    info "下载链接: $url"
    wget -O server.jar "$url" || { error "下载失败"; exit 1; }
    verify_jar server.jar || exit 1
}

# ---------- 下载 Nukkit ----------
download_nukkit() {
    step "正在下载 Nukkit (基岩版服务端)..."
    local url="https://repo.opencollab.dev/api/maven/latest/file/maven-snapshots/cn/nukkit/nukkit/1.0-SNAPSHOT?extension=jar"
    wget -O nukkit.jar "$url" || { error "下载失败"; exit 1; }
    verify_jar server.jar || exit 1
}

# ---------- 生成配置文件 ----------
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

# ---------- 创建启动脚本 ----------
create_start_script() {
    step "创建启动脚本..."

    if [ "$SERVER_TYPE" = "nukkit" ]; then
        cat > start.sh <<EOF
#!/data/data/com.termux/files/usr/bin/bash
cd "\$(dirname "\$0")"
exec java -Xms${JAVA_XMS} -Xmx${JAVA_XMX} -jar nukkit.jar
EOF
    else
        cat > start.sh <<EOF
#!/data/data/com.termux/files/usr/bin/bash
cd "\$(dirname "\$0")"
termux-wake-lock 2>/dev/null || true
exec "$JAVA_BIN" -Xms${JAVA_XMS} -Xmx${JAVA_XMX} \\
    -XX:+UseG1GC -XX:+ParallelRefProcEnabled \\
    -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=2 -XX:ConcGCThreads=1 \\
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

# ---------- 完成提示 ----------
show_finish() {
    echo ""
    title "=========================================="
    title "   安装完成！"
    title "=========================================="
    echo ""
    echo "  服务器类型: $SERVER_NAME"
    echo "  游戏版本:   $MC_VERSION"
    echo "  服务器目录: $SERVER_DIR"
    echo ""
    echo "  🚀 启动服务器:"
    echo "     cd $SERVER_DIR && ./start.sh"
    echo ""
    echo "  🛑 停止服务器:"
    echo "     在控制台输入 stop"
    echo ""
    echo "  📱 客户端连接:"
    if [ "$SERVER_TYPE" = "nukkit" ]; then
        echo "     基岩版客户端 → IP:19132"
    else
        echo "     Java 版客户端 → IP:25565"
    fi
    echo ""
    echo "  📄 日志文件: $LOG_FILE"
    echo ""
    title "=========================================="
}

# ---------- 错误捕获 ----------
trap 'error "安装过程中断，请查看日志: $LOG_FILE"' ERR

# ---------- 主流程 ----------
main() {
    check_termux
    install_deps
    select_type
    select_version
    select_java
    detect_memory
    create_dir

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